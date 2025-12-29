local pollTimer = nil

-- Constants
local BINDING_ID = 5001
local VIDEO_PLAYER_ID = 1
local DEFAULT_SKIP_SECONDS = 30
local DEFAULT_POLL_INTERVAL = 5

-- Utility Functions
local function isDebugMode()
  return Properties["Debug Mode"] == "ON"
end

local function debugLog(message)
  if isDebugMode() then
    print("Kodi: " .. message)
  end
end

local function updateProperty(name, value)
  C4:UpdateProperty(name, value)
end

local function clearPlayerProperties()
  updateProperty("Player State", "Stopped")
  updateProperty("Media Type", "-")
  updateProperty("Video Resolution", "-")
  updateProperty("Video Aspect Ratio", "-")
end

-- HTTP Request Functions
local function sendHttpRequest(url, jsonData, callback)
  local headers = {["Content-Type"] = "application/json"}
  
  C4:url()
    :OnDone(function(transfer, responses, errCode, errMsg)
      if errCode ~= 0 then
        debugLog("Error " .. tostring(errCode) .. ": " .. tostring(errMsg))
        if callback then callback(nil) end
      else
        if callback and responses[1] and responses[1].body then
          local response = C4:JsonDecode(responses[1].body)
          callback(response)
        elseif callback then
          callback(nil)
        end
      end
    end)
    :Post(url, jsonData, headers)
end

local function buildKodiUrl()
  local ip = Properties["IP Address"]
  local port = Properties["Port"] or "8080"
  
  if not ip or ip == "" then
    print("Kodi: No IP address configured")
    return nil
  end
  
  return "http://" .. ip .. ":" .. port .. "/jsonrpc"
end

function SendKodiCommand(method, params, callback)
  local url = buildKodiUrl()
  if not url then return end
  
  local jsonRequest = {
    jsonrpc = "2.0",
    method = method,
    params = params or {},
    id = 1
  }
  
  debugLog(method)
  sendHttpRequest(url, C4:JsonEncode(jsonRequest), callback)
end

function SendKodiCommandRaw(jsonString, callback)
  local url = buildKodiUrl()
  if not url then return end
  
  sendHttpRequest(url, jsonString, callback)
end

-- Polling Functions
local function processPlayerState(speed)
  if speed == 0 then
    updateProperty("Player State", "Paused")
  elseif speed == 1 then
    updateProperty("Player State", "Playing")
  else
    updateProperty("Player State", "Fast Forward/Rewind")
  end
end

local function processVideoStreams(videostreams)
  if videostreams and #videostreams > 0 then
    local video = videostreams[1]
    if video.width and video.height then
      updateProperty("Video Resolution", video.width .. "x" .. video.height)
      local aspect = video.width / video.height
      updateProperty("Video Aspect Ratio", string.format("%.2f", aspect))
    end
  end
end

local function pollPlayerProperties(playerid)
  local query = string.format(
    '{"jsonrpc":"2.0","method":"Player.GetProperties","params":{"playerid":%d,"properties":["speed","percentage","time","totaltime","videostreams","audiostreams"]},"id":1}',
    playerid
  )
  
  SendKodiCommandRaw(query, function(response)
    debugLog("GetProperties response: " .. C4:JsonEncode(response or {}))
    
    if response and response.result then
      processPlayerState(response.result.speed)
      processVideoStreams(response.result.videostreams)
    end
  end)
end

local function processSystemLabels(labels)
  if labels["System.ScreenSaverActive"] then
    updateProperty("Screen Saver", labels["System.ScreenSaverActive"] == "true" and "Active" or "Inactive")
  end
  
  if labels["System.CpuUsage"] then
    updateProperty("CPU Usage", labels["System.CpuUsage"])
  end
  
  if labels["System.FreeMemory"] then
    updateProperty("Memory Usage", labels["System.FreeMemory"])
  end
  
  if labels["System.CPUTemperature"] then
    updateProperty("System Temperature", labels["System.CPUTemperature"])
  end
  
  if labels["System.Uptime(hh:mm)"] and labels["System.Uptime(hh:mm)"] ~= "Busy" then
    updateProperty("System Uptime", labels["System.Uptime(hh:mm)"])
  else
    updateProperty("System Uptime", "-")
  end
  
  if labels["System.BuildVersion"] then
    updateProperty("Kodi Version", labels["System.BuildVersion"])
  end
end

local function pollSystemInfo()
  local query = '{"jsonrpc":"2.0","method":"XBMC.GetInfoLabels","params":{"labels":["System.ScreenSaverActive","System.CpuUsage","System.FreeMemory","System.CPUTemperature","System.Uptime(hh:mm)","System.BuildVersion"]},"id":1}'
  
  SendKodiCommandRaw(query, function(response)
    debugLog("GetInfoLabels response: " .. C4:JsonEncode(response or {}))
    
    if response and response.result then
      processSystemLabels(response.result)
    end
  end)
end

local function pollActivePlayers()
  SendKodiCommand("Player.GetActivePlayers", {}, function(response)
    debugLog("GetActivePlayers response: " .. C4:JsonEncode(response or {}))
    
    if response and response.result and #response.result > 0 then
      local playerid = response.result[1].playerid
      local playertype = response.result[1].type
      
      debugLog("Active player found - ID: " .. playerid .. ", Type: " .. playertype)
      
      updateProperty("Media Type", playertype or "-")
      pollPlayerProperties(playerid)
    else
      debugLog("No active players found")
      clearPlayerProperties()
    end
  end)
end

function PollKodiStatus()
  pollActivePlayers()
  pollSystemInfo()
end

function StartPolling()
  StopPolling()
  local interval = tonumber(Properties["Poll Interval (seconds)"]) or DEFAULT_POLL_INTERVAL
  pollTimer = C4:SetTimer(interval * 1000, function()
    PollKodiStatus()
  end, true)
  print("Kodi: Polling started (every " .. interval .. " seconds)")
end

function StopPolling()
  if pollTimer then
    pollTimer:Cancel()
    pollTimer = nil
    print("Kodi: Polling stopped")
  end
end

-- Program Button Functions
local function executeAction(action)
  SendKodiCommand("Input.ExecuteAction", {action = action})
end

local function setPlayerSubtitle(mode)
  SendKodiCommand("Player.SetSubtitle", {playerid = VIDEO_PLAYER_ID, subtitle = mode})
end

local function setPlayerAudioStream(stream)
  SendKodiCommand("Player.SetAudioStream", {playerid = VIDEO_PLAYER_ID, stream = stream})
end

function ExecuteProgramButton(action)
  local actions = {
    ["Show Codec Info"] = function() executeAction("codecinfo") end,
    ["Show OSD"] = function() executeAction("osd") end,
    ["Show Player Process Info"] = function() executeAction("playerprocessinfo") end,
    ["Toggle Subtitles"] = function() setPlayerSubtitle("toggle") end,
    ["Next Subtitle"] = function() setPlayerSubtitle("next") end,
    ["Next Audio Track"] = function() setPlayerAudioStream("next") end,
    ["Screenshot"] = function() executeAction("screenshot") end
  }
  
  local actionFunc = actions[action]
  if actionFunc then
    actionFunc()
  end
end

-- Player Control Functions
local function playPause(play)
  SendKodiCommand("Player.PlayPause", {playerid = VIDEO_PLAYER_ID, play = play})
end

local function stopPlayer()
  SendKodiCommand("Player.Stop", {playerid = VIDEO_PLAYER_ID})
end

local function seekPlayer(seconds)
  SendKodiCommand("Player.Seek", {playerid = VIDEO_PLAYER_ID, value = {seconds = seconds}})
end

local function setPlayerSpeed(speed)
  SendKodiCommand("Player.SetSpeed", {playerid = VIDEO_PLAYER_ID, speed = speed})
end

local function getSkipInterval()
  return tonumber(Properties["Skip Interval (seconds)"]) or DEFAULT_SKIP_SECONDS
end

-- Navigation Functions
local function sendInput(command)
  SendKodiCommand("Input." .. command, {})
end

-- Command Dispatcher
local commandHandlers = {
  ON = function() sendInput("Home") end,
  OFF = function() SendKodiCommand("System.Hibernate", {}) end,
  PLAY = function()
    C4:SendToProxy(BINDING_ID, "ON", {})
    playPause(true)
  end,
  PAUSE = function() playPause(false) end,
  STOP = function() stopPlayer() end,
  SKIP_FWD = function() seekPlayer(getSkipInterval()) end,
  SKIP_REV = function() seekPlayer(-getSkipInterval()) end,
  SCAN_FWD = function() setPlayerSpeed(2) end,
  SCAN_REV = function() setPlayerSpeed(-2) end,
  PROGRAM_A = function() ExecuteProgramButton(Properties["Program A Button (Red)"]) end,
  PROGRAM_B = function() ExecuteProgramButton(Properties["Program B Button (Green)"]) end,
  PROGRAM_C = function() ExecuteProgramButton(Properties["Program C Button (Yellow)"]) end,
  PROGRAM_D = function() ExecuteProgramButton(Properties["Program D Button (Blue)"]) end,
  UP = function() sendInput("Up") end,
  DOWN = function() sendInput("Down") end,
  LEFT = function() sendInput("Left") end,
  RIGHT = function() sendInput("Right") end,
  ENTER = function() sendInput("Select") end,
  CANCEL = function() sendInput("Back") end,
  MENU = function() sendInput("ContextMenu") end,
  INFO = function() sendInput("Info") end
}

function ReceivedFromProxy(bindingID, command, params)
  debugLog("ReceivedFromProxy (" .. bindingID .. "): " .. command)
  
  if bindingID == BINDING_ID then
    local handler = commandHandlers[command]
    if handler then
      handler()
    end
  end
end

-- Lifecycle Functions
function OnDriverInit(driverInitType)
  print("Kodi driver initialized: " .. tostring(driverInitType))
  
  if Properties["Enable Polling"] == "ON" then
    StartPolling()
  end
end

function OnDriverDestroyed()
  StopPolling()
end

function OnPropertyChanged(property)
  debugLog("Property changed: " .. property)
  
  if property == "Enable Polling" then
    if Properties["Enable Polling"] == "ON" then
      StartPolling()
    else
      StopPolling()
    end
  elseif property == "Poll Interval (seconds)" then
    if Properties["Enable Polling"] == "ON" then
      StartPolling()
    end
  end
end
