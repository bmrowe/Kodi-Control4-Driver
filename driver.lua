local C4Utils = require("c4_utils")
local KodiRpc = require("kodi_rpc")
local AvDetails = require("av_details")
local Notifications = require("notifications")
local Commands = require("commands")
local WebSocket = require("drivers-common-public.module.websocket")

local MEDIA_PLAYER_BINDING_ID = 5001
local KODI_WEBSOCKET_PORT = 9090
local DEFAULT_SKIP_INTERVAL_SECONDS = 30

local RECONNECT_DELAY_MS = 5000
local JSONRPC_CALLBACK_TIMEOUT_MS = 10000
local AV_DETAILS_DEBOUNCE_MS = 500

local logger = C4Utils.createLogger("Kodi: ")
local logInfo = logger.info
local logDebug = logger.debug

local state = {
  webSocket = nil,

  directionalsMode = "PM4K", -- "PM4K" or "Kodi"
  isInPlayback = false,

  isShuttingDown = false,

  wsConnecting = false,
  wsConnected = false,
  lastDisconnectReason = nil,

  reconnectTimerId = nil,
  playbackType = nil, -- "video" | "audio" | nil

}

-- Forward declarations (avoid Lua scoping issues)
local connectKodiWebSocket
local kodiRpc

local function updateProperty(name, value)
  C4Utils.updateProperty(name, value)
end

local function cancelTimer(timerId)
  return C4Utils.cancelTimer(timerId)
end

local function isAutoRoomOnEnabled()
  return Properties and Properties["Auto Room On"] == "ON"
end

local function isAutoRoomOffEnabled()
  return Properties and Properties["Auto Room Off"] == "ON"
end

local function loadDirectionalsModeFromProperties()
  if not Properties then return end

  local directionalsSetting = Properties["Playback Directionals"]
  if directionalsSetting == "Kodi" then
    state.directionalsMode = "Kodi"
  else
    state.directionalsMode = "PM4K"
  end

  logDebug("Playback Directionals mode set to: " .. state.directionalsMode)
end

local function shouldUseKodiPlaybackDirectionals()
  return state.playbackType == "video" and state.directionalsMode == "Kodi"
end

local function getSkipIntervalSeconds()
  if not Properties then return DEFAULT_SKIP_INTERVAL_SECONDS end
  return tonumber(Properties["Skip Interval (seconds)"]) or DEFAULT_SKIP_INTERVAL_SECONDS
end

local autoRoom = {
  isOnEnabled = isAutoRoomOnEnabled,
  isOffEnabled = isAutoRoomOffEnabled,
  sendOn = function() C4:SendToProxy(MEDIA_PLAYER_BINDING_ID, "ON", {}) end,
  sendOff = function() C4:SendToProxy(MEDIA_PLAYER_BINDING_ID, "OFF", {}) end,
}

local function setWsStatus(connected, connecting, reason)
  state.wsConnected = connected and true or false
  state.wsConnecting = connecting and true or false
  state.lastDisconnectReason = reason or state.lastDisconnectReason
  updateProperty(
    "WebSocket Status",
    state.wsConnected and "Connected" or (state.wsConnecting and "Connecting" or "Disconnected")
  )
end

local function disconnectWebSocket(reason)
  if reason then
    logInfo("Disconnecting WebSocket (" .. tostring(reason) .. ")")
  else
    logInfo("Disconnecting WebSocket")
  end

  setWsStatus(false, false, reason)
  state.reconnectTimerId = cancelTimer(state.reconnectTimerId)

  if state.webSocket then
    -- delete() is important with this library because it caches sockets by URL
    pcall(function() state.webSocket:delete() end)
    state.webSocket = nil
  end

  if kodiRpc then
    kodiRpc:setWebSocket(nil)
    kodiRpc:clearPendingCallbacks()
  end
end

local function scheduleWebSocketReconnect()
  if state.isShuttingDown then return end

  state.reconnectTimerId = cancelTimer(state.reconnectTimerId)
  state.reconnectTimerId = C4:SetTimer(RECONNECT_DELAY_MS, function()
    state.reconnectTimerId = nil
    if state.isShuttingDown then return end
    logInfo("Attempting to reconnect...")
    connectKodiWebSocket()
  end)
end

kodiRpc = KodiRpc:new({
  jsonEncode = function(value) return C4:JsonEncode(value) end,
  setTimer = function(ms, callback) return C4:SetTimer(ms, callback) end,
  callbackTimeoutMs = JSONRPC_CALLBACK_TIMEOUT_MS,
  logDebug = logDebug,
  logInfo = logInfo,

  isConnectedFn = function()
    return state.wsConnected
  end,

  onTransportError = function(why)
    if state.isShuttingDown then return end
    logInfo("Transport error: " .. tostring(why))
    disconnectWebSocket(why)
    scheduleWebSocketReconnect()
  end,
})

local avDetails = AvDetails:new({
  kodiRpc = kodiRpc,
  updateProperty = updateProperty,
  setTimer = function(ms, callback) return C4:SetTimer(ms, callback) end,
  cancelTimer = cancelTimer,
  debounceMs = AV_DETAILS_DEBOUNCE_MS,
  logDebug = logDebug,
})

local notificationHandlers = Notifications.createHandlers({
  state = state,
  kodiRpc = kodiRpc, -- ADD
  updateProperty = updateProperty,
  logDebug = logDebug,
  autoRoom = autoRoom,
  avDetails = avDetails,
})


local commandHandlers = Commands.createHandlers({
  state = state,
  kodiRpc = kodiRpc,
  getSkipIntervalSeconds = getSkipIntervalSeconds,
  shouldUseKodiPlaybackDirectionals = shouldUseKodiPlaybackDirectionals,
  autoRoom = autoRoom,
})

local function handleKodiNotification(method, data)
  local handler = notificationHandlers[method]
  if handler then
    handler(data)
  else
    logDebug("Unhandled notification: " .. tostring(method))
  end
end

local function processWebSocketMessage(_, rawData)
  logDebug("Message received")

  local ok, response = pcall(function() return C4:JsonDecode(rawData) end)
  if not ok or type(response) ~= "table" then
    logInfo("Failed to decode JSON message")
    return
  end

  if response.id then
    kodiRpc:handleResponse(response)
  elseif response.method then
    logDebug("Notification: " .. response.method)
    handleKodiNotification(response.method, response.params and response.params.data)
  end
end

connectKodiWebSocket = function()
  if state.isShuttingDown then return end

  if not Properties then
    logInfo("Properties not available")
    return
  end

  local ipAddress = Properties["IP Address"]
  if not ipAddress or ipAddress == "" then
    logInfo("No IP address configured")
    return
  end

  if state.wsConnected or state.wsConnecting then
    logDebug("WebSocket already connected/connecting")
    return
  end

  disconnectWebSocket("connect_start")

  local url = "ws://" .. ipAddress .. ":" .. KODI_WEBSOCKET_PORT .. "/jsonrpc"
  logInfo("Connecting to " .. url)
  setWsStatus(false, true, "connecting")

  local ws = WebSocket:new(url)
  if not ws then
    logInfo("Failed to create WebSocket")
    setWsStatus(false, false, "create_failed")
    scheduleWebSocketReconnect()
    return
  end

  state.webSocket = ws
  kodiRpc:setWebSocket(ws)

  ws:SetProcessMessageFunction(processWebSocketMessage)

  ws:SetEstablishedFunction(function(_)
    logInfo("WebSocket connected")
    setWsStatus(true, false, "connected")
    state.reconnectTimerId = cancelTimer(state.reconnectTimerId)
    kodiRpc:sendRequest("Player.GetActivePlayers", {}, function(players)
    local any = false
    local pType = nil

    if type(players) == "table" then
      for _, p in ipairs(players) do
        any = true
        if p.type == "video" then pType = "video" break end
        if p.type == "audio" then pType = pType or "audio" end
      end
    end

    state.isInPlayback = any
    state.playbackType = pType
  end)
  end)

  ws:SetOfflineFunction(function(_)
    logInfo("WebSocket offline")
    if state.isShuttingDown then return end
    disconnectWebSocket("offline")
    scheduleWebSocketReconnect()
  end)

  ws:SetClosedByRemoteFunction(function(_)
    logInfo("WebSocket closed by remote")
    if state.isShuttingDown then return end
    disconnectWebSocket("closed_by_remote")
    scheduleWebSocketReconnect()
  end)

  ws:Start()
end

function ReceivedFromProxy(bindingID, command, params)
  if bindingID == MEDIA_PLAYER_BINDING_ID and commandHandlers[command] then
    logDebug("Command: " .. command)
    commandHandlers[command]()
  end
end

function OnDriverInit()
  logInfo("Driver initialized")
  state.isShuttingDown = false
  loadDirectionalsModeFromProperties()
  connectKodiWebSocket()
end

function OnDriverDestroyed()
  logInfo("Driver shutting down")
  state.isShuttingDown = true
  state.reconnectTimerId = cancelTimer(state.reconnectTimerId)
  avDetails:clear()
  disconnectWebSocket("driver_destroyed")
end

function OnPropertyChanged(propertyName)
  logDebug("Property changed: " .. propertyName)

  if propertyName == "Playback Directionals" then
    loadDirectionalsModeFromProperties()

  elseif propertyName == "IP Address" then
    logInfo("IP address changed, reconnecting")
    if state.isShuttingDown then return end

    disconnectWebSocket("ip_changed")
    C4:SetTimer(250, function()
      connectKodiWebSocket()
    end)
  end
end

-- Action command handlers (match driver.xml <actions>/<command>)
EX_CMD = EX_CMD or {}

function EX_CMD.ACTION_ReconnectWebSocket(_)
  logInfo("Driver Action: ACTION_ReconnectWebSocket")
  if state.isShuttingDown then state.isShuttingDown = false end
  disconnectWebSocket("action_reconnect")
  connectKodiWebSocket()
end

function EX_CMD.ACTION_DisconnectWebSocket(_)
  logInfo("Driver Action: ACTION_DisconnectWebSocket")
  disconnectWebSocket("action_disconnect")
end

function ExecuteCommand(strCommand, tParams)
  local fn = EX_CMD and EX_CMD[strCommand]
  if type(fn) == "function" then
    local ok, err = pcall(function() return fn(tParams) end)
    if not ok then
      logInfo("ExecuteCommand error (" .. tostring(strCommand) .. "): " .. tostring(err))
    end
    return
  end

  logDebug("ExecuteCommand: Unhandled command = " .. tostring(strCommand))
end
