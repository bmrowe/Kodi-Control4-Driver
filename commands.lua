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

function Commands.createHandlers(context)
  local state = assert(context.state, "state is required")
  local kodiRpc = assert(context.kodiRpc, "kodiRpc is required")
  local getSkipIntervalSeconds = assert(context.getSkipIntervalSeconds, "getSkipIntervalSeconds is required")
  local shouldUseKodiPlaybackDirectionals = assert(context.shouldUseKodiPlaybackDirectionals, "shouldUseKodiPlaybackDirectionals is required")
  local autoRoom = assert(context.autoRoom, "autoRoom is required")

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

  local function isAnyPlayback()
    return state.isInPlayback == true
  end

  local handlers = {}

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
    -- Only treat ENTER as playback-control when in VIDEO playback.
    -- (Audio-only playback, like PM4K theme music, should not break tile selection.)
    if isVideoPlayback() then
      if state.directionalsMode == "PM4K" then
        kodiRpc:executeAction("playpause")
      else
        kodiRpc:executeAction("osd")
      end
    else
      kodiRpc:sendInput("Select")
    end
  end

  handlers.CANCEL = function() kodiRpc:sendInput("Back") end
  handlers.MENU = function() kodiRpc:sendInput("ContextMenu") end

  handlers.INFO = function()
    -- Codec info is only meaningful for video playback; otherwise show regular info.
    if isVideoPlayback() then
      kodiRpc:executeAction("codecinfo")
    else
      kodiRpc:sendInput("Info")
    end
  end

  handlers.ON = function()
    autoRoom.sendOn()
    kodiRpc:sendInput("Home")
  end

  handlers.PLAY = function()
    autoRoom.sendOn()

    -- If *anything* is already playing (audio or video), PLAY should control the player.
    -- If nothing is playing, treat PLAY like Select to start the highlighted tile.
    if isAnyPlayback() then
      kodiRpc:executeAction("playpause")
    else
      kodiRpc:sendInput("Select")
    end
  end

  handlers.PAUSE = function()
    -- Pause should only act when there is an active player; otherwise it’s harmless.
    if isAnyPlayback() then
      kodiRpc:executeAction("pause")
    end
  end

  handlers.STOP = function()
    if isAnyPlayback() then
      kodiRpc:executeAction("stop")
    end
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

  handlers.SCAN_FWD = function() kodiRpc:executeAction("fastforward") end
  handlers.SCAN_REV = function() kodiRpc:executeAction("rewind") end

  handlers.PROGRAM_A = function() executeProgramButton("Program A Button (Red)") end
  handlers.PROGRAM_B = function() executeProgramButton("Program B Button (Green)") end
  handlers.PROGRAM_C = function() executeProgramButton("Program C Button (Yellow)") end
  handlers.PROGRAM_D = function() executeProgramButton("Program D Button (Blue)") end

  return handlers
end

return Commands
