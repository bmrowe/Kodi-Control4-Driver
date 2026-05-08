local Commands = {}

local PROGRAM_ACTION_MAP = {
  ["Show Codec Info"] = "codecinfo",
  ["Show OSD"] = "osd",
  ["Show Player Process Info"] = "playerprocessinfo",
  ["Toggle Subtitles"] = "showsubtitles",
  ["Next Subtitle"] = "nextsubtitle",
  ["Next Audio Track"] = "audionextlanguage",
  ["Screenshot"] = "screenshot",
}
local PM4K_PLUGIN_URL = "plugin://script.plexmod/"
local DIRECTIONAL_REPEAT_INTERVAL_MS = 200

function Commands.createHandlers(context)
  local state = assert(context.state, "state is required")
  local kodiRpc = assert(context.kodiRpc, "kodiRpc is required")
  local getSkipIntervalSeconds = assert(context.getSkipIntervalSeconds, "getSkipIntervalSeconds is required")
  local shouldUseKodiPlaybackDirectionals = assert(context.shouldUseKodiPlaybackDirectionals, "shouldUseKodiPlaybackDirectionals is required")
  local autoRoom = assert(context.autoRoom, "autoRoom is required")
  local setTimer = assert(context.setTimer, "setTimer is required")
  local cancelTimer = assert(context.cancelTimer, "cancelTimer is required")
  local logInfo = context.logInfo or function(_) end

  local function executeProgramButton(propertyName)
    if not Properties then return end

    local configuredAction = Properties[propertyName]
    if not configuredAction or configuredAction == "" or configuredAction == "No Operation" then
      return
    end

    local kodiAction = PROGRAM_ACTION_MAP[configuredAction]
    if kodiAction then
      kodiRpc:executeAction(kodiAction)
    end
  end

  local function isVideoPlayback()
    return state.playbackType == "video"
  end

  local handlers = {}
  local repeatTimerId = nil
  local repeatCommand = nil
  local repeatGeneration = 0

  local function stopRepeat()
    repeatGeneration = repeatGeneration + 1
    repeatCommand = nil
    repeatTimerId = cancelTimer(repeatTimerId)
  end

  local function scheduleRepeat(commandName)
    local myGeneration = repeatGeneration
    repeatTimerId = setTimer(DIRECTIONAL_REPEAT_INTERVAL_MS, function()
      repeatTimerId = nil
      if repeatCommand ~= commandName or repeatGeneration ~= myGeneration then
        return
      end

      local handler = handlers[commandName]
      if type(handler) == "function" then
        local ok, err = pcall(handler)
        if not ok then
          logInfo("Repeat command error (" .. tostring(commandName) .. "): " .. tostring(err))
          stopRepeat()
          return
        end
      end

      if repeatCommand == commandName and repeatGeneration == myGeneration then
        scheduleRepeat(commandName)
      end
    end)
  end

  local function startRepeat(commandName)
    stopRepeat()
    repeatCommand = commandName
    repeatGeneration = repeatGeneration + 1
    local handler = handlers[commandName]
    if type(handler) == "function" then
      local ok, err = pcall(handler)
      if not ok then
        logInfo("Repeat command error (" .. tostring(commandName) .. "): " .. tostring(err))
        stopRepeat()
        return
      end
    end
    if repeatCommand == commandName then
      scheduleRepeat(commandName)
    end
  end

  local function setPlayerSpeed(speed)
    kodiRpc:sendRequest("Player.SetSpeed", { playerid = 0, speed = speed })
    kodiRpc:sendRequest("Player.SetSpeed", { playerid = 1, speed = speed })
  end

  handlers.UP = function()
    if shouldUseKodiPlaybackDirectionals() then
      kodiRpc:executeAction("bigstepforward")
    else
      kodiRpc:sendInput("Up")
    end
  end

  handlers.DOWN = function()
    if shouldUseKodiPlaybackDirectionals() then
      kodiRpc:executeAction("bigstepback")
    else
      kodiRpc:sendInput("Down")
    end
  end

  handlers.LEFT = function()
    if shouldUseKodiPlaybackDirectionals() then
      kodiRpc:executeAction("stepback")
    else
      kodiRpc:sendInput("Left")
    end
  end

  handlers.RIGHT = function()
    if shouldUseKodiPlaybackDirectionals() then
      kodiRpc:executeAction("stepforward")
    else
      kodiRpc:sendInput("Right")
    end
  end

  handlers.ENTER = function()
    if shouldUseKodiPlaybackDirectionals() then
      kodiRpc:executeAction("osd")
    else
      kodiRpc:sendInput("Select")
    end
  end

  handlers.INFO = function()
    if isVideoPlayback() then
      kodiRpc:executeAction("codecinfo")
    else
      kodiRpc:sendInput("Info")
    end
  end

  handlers.ON = function()
    if autoRoom.isOnEnabled() then
      autoRoom.sendOn()
    end
    if Properties and Properties["Startup Action on ON"] == "Launch PM4K (script.plexmod)" then
      kodiRpc:sendRequest("Player.Open", { item = { file = PM4K_PLUGIN_URL } })
    else
      kodiRpc:sendInput("Home")
    end
  end

  handlers.PLAY = function()
    if autoRoom.isOnEnabled() then
      autoRoom.sendOn()
    end
    kodiRpc:executeAction("playpause")
  end

  handlers.SKIP_FWD = function()
    local skipSeconds = getSkipIntervalSeconds()
    local action = (skipSeconds >= 600) and "bigstepforward"
      or (skipSeconds >= 30) and "stepforward"
      or "smallstepforward"
    kodiRpc:executeAction(action)
  end

  handlers.SKIP_REV = function()
    local skipSeconds = getSkipIntervalSeconds()
    local action = (skipSeconds >= 600) and "bigstepback"
      or (skipSeconds >= 30) and "stepback"
      or "smallstepback"
    kodiRpc:executeAction(action)
  end

  handlers.CANCEL = function() kodiRpc:sendInput("Back") end
  handlers.MENU = function() kodiRpc:sendInput("ContextMenu") end
  handlers.PAUSE = function() kodiRpc:executeAction("pause") end
  handlers.STOP = function() kodiRpc:executeAction("stop") end
  handlers.SCAN_FWD = function() kodiRpc:executeAction("fastforward") end
  handlers.SCAN_REV = function() kodiRpc:executeAction("rewind") end
  handlers.START_UP = function() startRepeat("UP") end
  handlers.STOP_UP = stopRepeat
  handlers.START_DOWN = function() startRepeat("DOWN") end
  handlers.STOP_DOWN = stopRepeat
  handlers.START_LEFT = function() startRepeat("LEFT") end
  handlers.STOP_LEFT = stopRepeat
  handlers.START_RIGHT = function() startRepeat("RIGHT") end
  handlers.STOP_RIGHT = stopRepeat
  handlers.START_SCAN_FWD = function() setPlayerSpeed(8) end
  handlers.STOP_SCAN_FWD = function() setPlayerSpeed(1) end
  handlers.START_SCAN_REV = function() setPlayerSpeed(-8) end
  handlers.STOP_SCAN_REV = function() setPlayerSpeed(1) end
  handlers.STOP_REPEAT = stopRepeat
  handlers.PROGRAM_A = function() executeProgramButton("Program A Button (Red)") end
  handlers.PROGRAM_B = function() executeProgramButton("Program B Button (Green)") end
  handlers.PROGRAM_C = function() executeProgramButton("Program C Button (Yellow)") end
  handlers.PROGRAM_D = function() executeProgramButton("Program D Button (Blue)") end

  return handlers
end

return Commands
