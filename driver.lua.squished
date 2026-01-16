--------------------------------------------------------------------------------
-- CONSTANTS
--------------------------------------------------------------------------------
local BINDING_ID = 5001
local WS_PORT = 9090
local DEFAULT_SKIP_SECONDS = 30
local RECONNECT_DELAY_MS = 5000
local INIT_DELAY_MS = 1000
local CALLBACK_TIMEOUT_MS = 10000

--------------------------------------------------------------------------------
-- STATE
--------------------------------------------------------------------------------
local state = {
  ws = nil,
  currentPlayerId = 0,
  reconnectTimer = nil,
}

--------------------------------------------------------------------------------
-- UTILITIES
--------------------------------------------------------------------------------
local function debugLog(message)
  if Properties["Debug Mode"] == "ON" then
    print("Kodi: " .. message)
  end
end

local function log(message)
  print("Kodi: " .. message)
end

local function updateProperty(name, value)
  C4:UpdateProperty(name, value)
end

local function clearPlayerProperties()
  updateProperty("Player State", "Stopped")
  updateProperty("Media Type", "-")
  updateProperty("Video Resolution", "-")
  updateProperty("Video Aspect Ratio", "-")
  state.currentPlayerId = 0
end

local function getSkipInterval()
  return tonumber(Properties["Skip Interval (seconds)"]) or DEFAULT_SKIP_SECONDS
end

local function getPlayerId()
  return state.currentPlayerId > 0 and state.currentPlayerId or 0
end

--------------------------------------------------------------------------------
-- WEBSOCKET CLASS
--------------------------------------------------------------------------------
local WebSocket = require("drivers-common-public.module.websocket")

local KodiWebSocket = (function(baseClass)
  local class = {}
  class.__index = class
  
  function class:OnMessage(message)
    local success, response = pcall(function() return C4:JsonDecode(message) end)
    
    if not (success and response and type(response) == "table") then
      return
    end
    
    debugLog("Received: " .. message)
    
    -- Handle RPC responses
    if response.id and self.callbacks[response.id] then
      local callback = self.callbacks[response.id]
      self.callbacks[response.id] = nil
      if callback and response.result then
        callback(response.result)
      end
    end
    
    -- Handle notifications
    if response.method and response.params then
      self:handleNotification(response.method, response.params.data)
    end
  end
  
  function class:handleNotification(method, data)
    local handlers = {
      ["Player.OnPlay"] = function()
        log("Player.OnPlay")
        if data and data.player and data.player.playerid then
          state.currentPlayerId = data.player.playerid
        end
        if data and data.item and data.item.type then
          updateProperty("Media Type", data.item.type)
        end
        updateProperty("Player State", "Playing")
      end,
      
      ["Player.OnPause"] = function()
        log("Player.OnPause")
        if data and data.player and data.player.playerid then
          state.currentPlayerId = data.player.playerid
        end
        updateProperty("Player State", "Paused")
      end,
      
      ["Player.OnResume"] = function()
        log("Player.OnResume")
        updateProperty("Player State", "Playing")
      end,
      
      ["Player.OnStop"] = function()
        log("Player.OnStop")
        clearPlayerProperties()
      end,
      
      ["Player.OnSpeedChanged"] = function()
        if not (data and data.player and data.player.speed) then
          return
        end
        
        local stateMap = {
          [0] = "Paused",
          [1] = "Playing",
        }
        
        local playerState = stateMap[data.player.speed] or "Fast Forward/Rewind"
        updateProperty("Player State", playerState)
      end,
    }
    
    local handler = handlers[method]
    if handler then
      handler()
    end
  end
  
  function class:sendCommand(method, params, callback)
    -- #3: Command Validation - check if connected
    if not self.running then
      log("Cannot send " .. method .. " - not connected")
      return false
    end
    
    self.rpcId = (self.rpcId % 25) + 1
    
    local request = {
      jsonrpc = "2.0",
      method = method,
      params = params or {},
      id = self.rpcId
    }
    
    if callback then
      self.callbacks[self.rpcId] = callback
      
      -- #4: Callback Timeout - auto-clean after 10 seconds
      local callbackId = self.rpcId
      C4:SetTimer(CALLBACK_TIMEOUT_MS, function()
        if self.callbacks[callbackId] then
          debugLog("Callback timeout for " .. method)
          self.callbacks[callbackId] = nil
        end
      end)
    end
    
    debugLog("Sending: " .. method)
    self:Send(C4:JsonEncode(request))
    return true
  end
  
  local mt = {
    __call = function(self, url)
      local instance = baseClass:new(url)
      instance.rpcId = 0
      instance.callbacks = {}
      
      setmetatable(instance, class)
      return instance
    end,
    
    __index = baseClass
  }
  
  setmetatable(class, mt)
  return class
end)(WebSocket)

--------------------------------------------------------------------------------
-- CONNECTION MANAGEMENT
--------------------------------------------------------------------------------
local function cancelReconnect()
  if state.reconnectTimer then
    C4:KillTimer(state.reconnectTimer)
    state.reconnectTimer = nil
  end
end

local function scheduleReconnect()
  cancelReconnect()
  
  -- #2: Automatic Reconnection
  state.reconnectTimer = C4:SetTimer(RECONNECT_DELAY_MS, function()
    log("Attempting reconnect...")
    connectWebSocket()
  end)
end

function connectWebSocket()
  local ip = Properties["IP Address"]
  if not ip or ip == "" then
    log("No IP address configured")
    return
  end
  
  local url = "ws://" .. ip .. ":" .. WS_PORT .. "/jsonrpc"
  log("Connecting to: " .. url)
  
  state.ws = KodiWebSocket(url)
  
  state.ws.OnOpen = function(self)
    log("WebSocket connected")
    cancelReconnect()
    
    self:sendCommand("Player.GetActivePlayers", {}, function(result)
      if result and #result > 0 then
        state.currentPlayerId = result[1].playerid
        log("Active player ID: " .. state.currentPlayerId)
        updateProperty("Media Type", result[1].type or "-")
        updateProperty("Player State", "Playing")
      else
        log("No active players")
      end
    end)
  end
  
  state.ws.OnClose = function(self)
    log("WebSocket closed")
    
    -- #1: Memory Leak Prevention - clean up all callbacks
    self.callbacks = {}
    
    clearPlayerProperties()
    scheduleReconnect()
  end
  
  state.ws.OnError = function(self, err)
    log("WebSocket error: " .. tostring(err))
  end
  
  state.ws:Start()
end

local function disconnectWebSocket()
  cancelReconnect()
  
  if state.ws then
    state.ws:Close()
    state.ws = nil
  end
end

local function reconnectWebSocket()
  disconnectWebSocket()
  C4:SetTimer(INIT_DELAY_MS, function()
    connectWebSocket()
  end)
end

--------------------------------------------------------------------------------
-- COMMAND HANDLERS
--------------------------------------------------------------------------------
local function sendInput(input)
  return state.ws:sendCommand("Input." .. input, {})
end

local function sendAction(action)
  return state.ws:sendCommand("Input.ExecuteAction", {action = action})
end

local function executeProgramButton(propertyName)
  local action = Properties[propertyName]
  if not action then return end
  
  local actionMap = {
    ["Show Codec Info"] = function() sendAction("codecinfo") end,
    ["Show OSD"] = function() sendAction("osd") end,
    ["Show Player Process Info"] = function() sendAction("playerprocessinfo") end,
    ["Toggle Subtitles"] = function()
      state.ws:sendCommand("Player.SetSubtitle", {playerid = getPlayerId(), subtitle = "toggle"})
    end,
    ["Next Subtitle"] = function()
      state.ws:sendCommand("Player.SetSubtitle", {playerid = getPlayerId(), subtitle = "next"})
    end,
    ["Next Audio Track"] = function()
      state.ws:sendCommand("Player.SetAudioStream", {playerid = getPlayerId(), stream = "next"})
    end,
    ["Screenshot"] = function() sendAction("screenshot") end,
  }
  
  local handler = actionMap[action]
  if handler then
    handler()
  end
end

local commandHandlers = {
  -- Navigation
  UP = function() sendInput("Up") end,
  DOWN = function() sendInput("Down") end,
  LEFT = function() sendInput("Left") end,
  RIGHT = function() sendInput("Right") end,
  ENTER = function() sendInput("Select") end,
  CANCEL = function() sendInput("Back") end,
  MENU = function() sendInput("ContextMenu") end,
  INFO = function() sendInput("Info") end,
  
  -- Playback Control
  ON = function()
    C4:SendToProxy(BINDING_ID, "ON", {})
    sendInput("Home")
  end,
  
  PLAY = function()
    C4:SendToProxy(BINDING_ID, "ON", {})
    state.ws:sendCommand("Player.PlayPause", {playerid = getPlayerId(), play = true})
  end,
  
  PAUSE = function()
    state.ws:sendCommand("Player.PlayPause", {playerid = getPlayerId(), play = false})
  end,
  
  STOP = function()
    state.ws:sendCommand("Player.Stop", {playerid = getPlayerId()})
  end,
  
  -- Skip/Scan
  SKIP_FWD = function()
    state.ws:sendCommand("Player.Seek", {playerid = getPlayerId(), value = {seconds = getSkipInterval()}})
  end,
  
  SKIP_REV = function()
    state.ws:sendCommand("Player.Seek", {playerid = getPlayerId(), value = {seconds = -getSkipInterval()}})
  end,
  
  SCAN_FWD = function()
    state.ws:sendCommand("Player.SetSpeed", {playerid = getPlayerId(), speed = 2})
  end,
  
  SCAN_REV = function()
    state.ws:sendCommand("Player.SetSpeed", {playerid = getPlayerId(), speed = -2})
  end,
  
  -- Program Buttons
  PROGRAM_A = function() executeProgramButton("Program A Button (Red)") end,
  PROGRAM_B = function() executeProgramButton("Program B Button (Green)") end,
  PROGRAM_C = function() executeProgramButton("Program C Button (Yellow)") end,
  PROGRAM_D = function() executeProgramButton("Program D Button (Blue)") end,
}

--------------------------------------------------------------------------------
-- CONTROL4 DRIVER CALLBACKS
--------------------------------------------------------------------------------
function ReceivedFromProxy(bindingID, command, params)
  debugLog("Command: " .. command)
  
  if bindingID ~= BINDING_ID or not state.ws then
    return
  end
  
  local handler = commandHandlers[command]
  if handler then
    handler()
  end
end

function OnDriverInit()
  log("Driver initialized")
  C4:SetTimer(INIT_DELAY_MS, function()
    connectWebSocket()
  end)
end

function OnDriverDestroyed()
  disconnectWebSocket()
end

function OnPropertyChanged(property)
  log("Property changed: " .. property)
  
  if property == "IP Address" then
    reconnectWebSocket()
  end
end
