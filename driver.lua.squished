----------------------------------------
-- CONSTANTS
----------------------------------------
local BINDING_ID = 5001
local WS_PORT = 9090
local DEFAULT_SKIP_SECONDS = 30
local RECONNECT_DELAY_MS = 5000
local CALLBACK_TIMEOUT_MS = 10000
local MEDIA_INFO_DEBOUNCE_MS = 500

----------------------------------------
-- STATE
----------------------------------------
local state = {
  ws = nil,
  currentId = 0,
  callbacks = {},
  playbackDirectionalMode = "PM4K",
  inPlayback = false,
  shuttingDown = false,
  reconnectTimer = nil,
  mediaInfoTimer = nil,
}

----------------------------------------
-- LOGGING
----------------------------------------
local function log(msg)
  print("Kodi: " .. msg)
end

local function dlog(msg)
  if Properties and Properties["Debug Mode"] == "ON" then
    print("Kodi: " .. msg)
  end
end

----------------------------------------
-- HELPER FUNCTIONS
----------------------------------------
local function updateProperty(name, value)
  C4:UpdateProperty(name, value)
end

local function loadPlaybackDirectionalMode()
  if not Properties then return end
  
  local v = Properties["Playback Directionals"]
  if v == "Kodi" then
    state.playbackDirectionalMode = "Kodi"
  else
    state.playbackDirectionalMode = "PM4K"
  end
  dlog("Playback Directionals mode set to: " .. state.playbackDirectionalMode)
end

local function shouldUsePlaybackDirectionals()
  return state.inPlayback and state.playbackDirectionalMode == "Kodi"
end

local function getSkipInterval()
  if not Properties then return DEFAULT_SKIP_SECONDS end
  return tonumber(Properties["Skip Interval (seconds)"]) or DEFAULT_SKIP_SECONDS
end

local function cancelTimer(timerRef)
  if timerRef then
    C4:KillTimer(timerRef)
  end
  return nil
end

----------------------------------------
-- JSON-RPC
----------------------------------------
local function sendCommand(method, params, callback)
  if not state.ws or not state.ws.running then
    dlog("Cannot send " .. method .. " - WebSocket not connected")
    return false
  end

  state.currentId = state.currentId + 1
  if state.currentId > 9999 then state.currentId = 1 end

  local id = state.currentId
  local idKey = tostring(id)
  
  local request = {
    jsonrpc = "2.0",
    id = id,
    method = method,
    params = params or {}
  }

  if callback then
    state.callbacks[idKey] = callback
    
    -- Timeout cleanup to prevent memory leak
    C4:SetTimer(CALLBACK_TIMEOUT_MS, function()
      if state.callbacks[idKey] then
        dlog("Callback timeout for " .. method .. " (id=" .. id .. ")")
        state.callbacks[idKey] = nil
      end
    end)
  end

  dlog("Sending: " .. method .. " (id=" .. id .. ")")
  state.ws:Send(C4:JsonEncode(request))
  return true
end

local function sendGetInfoLabels(labels, callback)
  if not state.ws or not state.ws.running then
    dlog("Cannot send GetInfoLabels - WebSocket not connected")
    return false
  end

  state.currentId = state.currentId + 1
  if state.currentId > 9999 then state.currentId = 1 end

  local id = state.currentId
  local idKey = tostring(id)
  
  if callback then
    state.callbacks[idKey] = callback
    
    C4:SetTimer(CALLBACK_TIMEOUT_MS, function()
      if state.callbacks[idKey] then
        dlog("Callback timeout for GetInfoLabels (id=" .. id .. ")")
        state.callbacks[idKey] = nil
      end
    end)
  end

  -- Manually construct JSON array (C4:JsonEncode doesn't handle Lua arrays properly)
  local labelList = {}
  for _, label in ipairs(labels) do
    table.insert(labelList, '"' .. label .. '"')
  end
  local labelsJson = '[' .. table.concat(labelList, ',') .. ']'
  
  local json = string.format('{"jsonrpc":"2.0","id":%d,"method":"XBMC.GetInfoLabels","params":{"labels":%s}}', 
                              id, labelsJson)
  
  dlog("Sending: XBMC.GetInfoLabels (id=" .. id .. ")")
  state.ws:Send(json)
  return true
end

local function execAction(action)
  sendCommand("Input.ExecuteAction", {action = action})
end

local function sendInput(inputSuffix)
  sendCommand("Input." .. inputSuffix, {})
end

----------------------------------------
-- MEDIA INFO
----------------------------------------
local MEDIA_INFO_LABELS = {
  "Player.Process(videowidth)",
  "Player.Process(videoheight)",
  "VideoPlayer.VideoAspect",
  "VideoPlayer.VideoCodec",
  "VideoPlayer.HdrType",
  "VideoPlayer.AudioCodec",
  "VideoPlayer.AudioChannels",
  "VideoPlayer.AudioLanguage"
}

local function requestMediaInfo()
  dlog("Requesting media info")
  
  sendGetInfoLabels(MEDIA_INFO_LABELS, function(result)
    if result and type(result) == "table" then
      local function stripCommas(s)
        if not s or s == "" then return nil end
        return (tostring(s):gsub(",", ""))
      end
      
      local w = stripCommas(result["Player.Process(videowidth)"])
      local h = stripCommas(result["Player.Process(videoheight)"])
      local resolution = (w and h) and (w .. "x" .. h) or "N/A"
      
      local aspect = result["VideoPlayer.VideoAspect"] or "N/A"
      local vcodec = (result["VideoPlayer.VideoCodec"] and result["VideoPlayer.VideoCodec"] ~= "") 
                     and result["VideoPlayer.VideoCodec"] or "N/A"
      local hdr = (result["VideoPlayer.HdrType"] and result["VideoPlayer.HdrType"] ~= "") 
                  and result["VideoPlayer.HdrType"] or "SDR"
      
      local acodec = (result["VideoPlayer.AudioCodec"] and result["VideoPlayer.AudioCodec"] ~= "") 
                     and result["VideoPlayer.AudioCodec"] or "N/A"
      local ach = (result["VideoPlayer.AudioChannels"] and result["VideoPlayer.AudioChannels"] ~= "") 
                  and result["VideoPlayer.AudioChannels"] or ""
      local alang = (result["VideoPlayer.AudioLanguage"] and result["VideoPlayer.AudioLanguage"] ~= "") 
                    and result["VideoPlayer.AudioLanguage"] or ""
      
      local audio = acodec
      if ach ~= "" then audio = audio .. " " .. ach .. "ch" end
      if alang ~= "" then audio = audio .. " " .. alang end
      
      local info = resolution .. " | " .. aspect .. " | " .. vcodec .. " " .. hdr .. " | " .. audio
      updateProperty("Media Info", info)
      dlog("Media Info: " .. info)
    else
      dlog("GetInfoLabels returned invalid data")
    end
  end)
end

-- Debounced version to prevent spam from multiple OnAVChange events
local function scheduleMediaInfoUpdate()
  state.mediaInfoTimer = cancelTimer(state.mediaInfoTimer)
  state.mediaInfoTimer = C4:SetTimer(MEDIA_INFO_DEBOUNCE_MS, function()
    state.mediaInfoTimer = nil
    requestMediaInfo()
  end)
end

----------------------------------------
-- MESSAGE HANDLERS
----------------------------------------
local function handleNotification(method, data)
  if method == "Player.OnPlay" then
    dlog("Player.OnPlay notification")
    state.inPlayback = true
    updateProperty("Player State", "Playing")
    if data and data.item and data.item.type then
      updateProperty("Media Type", data.item.type)
    end

  elseif method == "Player.OnPause" then
    dlog("Player.OnPause notification")
    state.inPlayback = true
    updateProperty("Player State", "Paused")

  elseif method == "Player.OnResume" then
    dlog("Player.OnResume notification")
    state.inPlayback = true
    updateProperty("Player State", "Playing")

  elseif method == "Player.OnStop" then
    dlog("Player.OnStop notification")
    state.inPlayback = false
    state.mediaInfoTimer = cancelTimer(state.mediaInfoTimer)
    updateProperty("Player State", "Stopped")
    updateProperty("Media Type", "-")
    updateProperty("Media Info", "N/A")

  elseif method == "Player.OnSpeedChanged" then
    dlog("Player.OnSpeedChanged notification")
    if data and data.player and data.player.speed ~= nil then
      if data.player.speed == 0 then
        updateProperty("Player State", "Paused")
      elseif data.player.speed == 1 then
        updateProperty("Player State", "Playing")
      else
        updateProperty("Player State", "Fast Forward/Rewind")
      end
    end

  elseif method == "Player.OnAVChange" or method == "Player.OnAVStart" then
    dlog(method .. " notification")
    scheduleMediaInfoUpdate()
  end
end

local function processMessage(websocket, data)
  dlog("Message received")
  
  local ok, response = pcall(function() return C4:JsonDecode(data) end)
  
  if ok and type(response) == "table" then
    if response.id then
      local idKey = tostring(response.id)
      dlog("Response ID: " .. idKey)
      
      local cb = state.callbacks[idKey]
      if cb then
        state.callbacks[idKey] = nil
        
        if not response.error then
          cb(response.result)
        else
          log("JSON-RPC error: " .. C4:JsonEncode(response.error))
        end
      end
      
    elseif response.method then
      dlog("Notification: " .. response.method)
      handleNotification(response.method, response.params and response.params.data)
    end
  else
    log("Failed to decode JSON message")
  end
end

----------------------------------------
-- WEBSOCKET CONNECTION
----------------------------------------
local WebSocket = require("drivers-common-public.module.websocket")

local function scheduleReconnect()
  if state.shuttingDown then return end
  
  state.reconnectTimer = cancelTimer(state.reconnectTimer)
  state.reconnectTimer = C4:SetTimer(RECONNECT_DELAY_MS, function()
    state.reconnectTimer = nil
    log("Attempting to reconnect...")
    connectWebSocket()
  end)
end

function connectWebSocket()
  if not Properties then
    log("Properties not available")
    return
  end
  
  local ip = Properties["IP Address"]
  if not ip or ip == "" then
    log("No IP address configured")
    return
  end

  if state.ws and state.ws.running then
    dlog("WebSocket already connected")
    return
  end

  local url = "ws://" .. ip .. ":" .. WS_PORT .. "/jsonrpc"
  log("Connecting to " .. url)

  state.ws = WebSocket:new(url)
  
  if not state.ws then
    log("Failed to create WebSocket")
    scheduleReconnect()
    return
  end

  state.ws:SetProcessMessageFunction(processMessage)
  
  state.ws:SetEstablishedFunction(function(websocket)
    log("WebSocket connected")
    state.reconnectTimer = cancelTimer(state.reconnectTimer)
  end)
  
  state.ws:SetOfflineFunction(function(websocket)
    log("WebSocket offline")
    if not state.shuttingDown then
      scheduleReconnect()
    end
  end)
  
  state.ws:SetClosedByRemoteFunction(function(websocket)
    log("WebSocket closed by remote")
    if not state.shuttingDown then
      scheduleReconnect()
    end
  end)

  state.ws:Start()
end

----------------------------------------
-- PROGRAM BUTTONS
----------------------------------------
local function executeProgramButton(propertyName)
  if not Properties then return end
  
  local action = Properties[propertyName]
  if not action or action == "" then return end

  local actionMap = {
    ["Show Codec Info"] = "codecinfo",
    ["Show OSD"] = "osd",
    ["Show Player Process Info"] = "playerprocessinfo",
    ["Toggle Subtitles"] = "showsubtitles",
    ["Next Subtitle"] = "nextsubtitle",
    ["Next Audio Track"] = "audionextlanguage",
    ["Screenshot"] = "screenshot",
  }

  local mappedAction = actionMap[action]
  if mappedAction then
    execAction(mappedAction)
  end
end

----------------------------------------
-- COMMAND HANDLERS
----------------------------------------
local commands = {}

commands.UP = function()
  if shouldUsePlaybackDirectionals() then 
    execAction("bigstepforward") 
  else 
    sendInput("Up") 
  end
end

commands.DOWN = function()
  if shouldUsePlaybackDirectionals() then 
    execAction("bigstepback") 
  else 
    sendInput("Down") 
  end
end

commands.LEFT = function()
  if shouldUsePlaybackDirectionals() then 
    execAction("stepback") 
  else 
    sendInput("Left") 
  end
end

commands.RIGHT = function()
  if shouldUsePlaybackDirectionals() then 
    execAction("stepforward") 
  else 
    sendInput("Right") 
  end
end

commands.ENTER = function()
  if shouldUsePlaybackDirectionals() then 
    execAction("playpause") 
  else 
    sendInput("Select") 
  end
end

commands.CANCEL = function() sendInput("Back") end
commands.MENU = function() sendInput("ContextMenu") end
commands.INFO = function() sendInput("Info") end

commands.ON = function()
  C4:SendToProxy(BINDING_ID, "ON", {})
  sendInput("Home")
end

commands.PLAY = function()
  C4:SendToProxy(BINDING_ID, "ON", {})
  execAction("play")
end

commands.PAUSE = function() execAction("pause") end
commands.STOP = function() execAction("stop") end

commands.SKIP_FWD = function()
  local skipSecs = getSkipInterval()
  local action = (skipSecs >= 600) and "bigstepforward" 
              or (skipSecs >= 30) and "stepforward" 
              or "smallstepforward"
  execAction(action)
end

commands.SKIP_REV = function()
  local skipSecs = getSkipInterval()
  local action = (skipSecs >= 600) and "bigstepback" 
              or (skipSecs >= 30) and "stepback" 
              or "smallstepback"
  execAction(action)
end

commands.SCAN_FWD = function() execAction("fastforward") end
commands.SCAN_REV = function() execAction("rewind") end

commands.PROGRAM_A = function() executeProgramButton("Program A Button (Red)") end
commands.PROGRAM_B = function() executeProgramButton("Program B Button (Green)") end
commands.PROGRAM_C = function() executeProgramButton("Program C Button (Yellow)") end
commands.PROGRAM_D = function() executeProgramButton("Program D Button (Blue)") end

----------------------------------------
-- CONTROL4 CALLBACKS
----------------------------------------
function ReceivedFromProxy(bindingID, command, params)
  if bindingID == BINDING_ID and commands[command] then
    dlog("Command: " .. command)
    commands[command]()
  end
end

function OnDriverInit()
  log("Driver initialized")
  state.shuttingDown = false
  loadPlaybackDirectionalMode()
  connectWebSocket()
end

function OnDriverDestroyed()
  log("Driver shutting down")
  state.shuttingDown = true
  
  state.reconnectTimer = cancelTimer(state.reconnectTimer)
  state.mediaInfoTimer = cancelTimer(state.mediaInfoTimer)
  
  if state.ws then
    state.ws:Close()
    state.ws = nil
  end
end

function OnPropertyChanged(property)
  dlog("Property changed: " .. property)
  
  if property == "Playback Directionals" then
    loadPlaybackDirectionalMode()
    
  elseif property == "IP Address" then
    log("IP address changed, reconnecting")
    OnDriverDestroyed()
    state.shuttingDown = false
    C4:SetTimer(1000, OnDriverInit)
  end
end
