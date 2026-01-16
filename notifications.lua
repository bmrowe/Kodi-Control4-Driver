local Notifications = {}

function Notifications.createHandlers(context)
  local state = assert(context.state, "state is required")
  local updateProperty = assert(context.updateProperty, "updateProperty is required")
  local logDebug = assert(context.logDebug, "logDebug is required")
  local autoRoom = assert(context.autoRoom, "autoRoom is required")
  local avDetails = assert(context.avDetails, "avDetails is required")
  local handlers = {}

  local function setStoppedProperties()
    updateProperty("Player State", "Stopped")
    updateProperty("Media Type", "-")
    avDetails:resetProperties()
  end

  local function setPausedState()
    state.isInPlayback = true
    updateProperty("Player State", "Paused")
  end

  local function setPlayingState()
    state.isInPlayback = true
    updateProperty("Player State", "Playing")
  end

  handlers["Player.OnPlay"] = function(data)
    logDebug("Player.OnPlay notification")

    local wasInPlayback = state.isInPlayback
    state.isInPlayback = true

    updateProperty("Player State", "Playing")

    if data and data.item and data.item.type then
      updateProperty("Media Type", data.item.type)
    end

    if (not wasInPlayback) and autoRoom.isOnEnabled() then
      logDebug("Auto Room On: sending ON to proxy")
      autoRoom.sendOn()
    end
  end

  handlers["Player.OnPause"] = function(_)
    logDebug("Player.OnPause notification")
    setPausedState()
  end

  handlers["Player.OnResume"] = function(_)
    logDebug("Player.OnResume notification")
    setPlayingState()
  end

  handlers["Player.OnStop"] = function(_)
    logDebug("Player.OnStop notification")

    local wasInPlayback = state.isInPlayback
    state.isInPlayback = false

    avDetails:clear()
    setStoppedProperties()

    if wasInPlayback and autoRoom.isOffEnabled() then
      logDebug("Auto Room Off: sending OFF to proxy")
      autoRoom.sendOff()
    end
  end

  handlers["Player.OnSpeedChanged"] = function(data)
    logDebug("Player.OnSpeedChanged notification")

    if data and data.player and data.player.speed ~= nil then
      if data.player.speed == 0 then
        updateProperty("Player State", "Paused")
      elseif data.player.speed == 1 then
        updateProperty("Player State", "Playing")
      else
        updateProperty("Player State", "Fast Forward/Rewind")
      end
    end
  end

  handlers["Player.OnAVChange"] = function(_)
    logDebug("Player.OnAVChange notification")
    avDetails:scheduleUpdate()
  end

  handlers["Player.OnAVStart"] = function(_)
    logDebug("Player.OnAVStart notification")
    avDetails:scheduleUpdate()
  end

  return handlers
end

return Notifications
