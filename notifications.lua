local Notifications = {}

function Notifications.createHandlers(context)
  local state = assert(context.state, "state is required")
  local kodiRpc = assert(context.kodiRpc, "kodiRpc is required")
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


  local function refreshPlaybackState(afterFn)
    kodiRpc:sendRequest("Player.GetActivePlayers", {}, function(players)
      local any = false
      local pType = nil

      if type(players) == "table" then
        for _, p in ipairs(players) do
          any = true
          if p.type == "video" then
            pType = "video"
            break
          elseif p.type == "audio" then
            pType = pType or "audio"
          end
        end
      end

      state.isInPlayback = any
      state.playbackType = pType

      if afterFn then afterFn(any, pType) end
    end)
  end

  handlers["Player.OnPlay"] = function(data)
    logDebug("Player.OnPlay notification")

    local wasInVideo = (state.playbackType == "video")

    refreshPlaybackState(function(_, pType)
      -- Only treat VIDEO as "playback mode" for UI + auto room + AV details.
      if pType ~= "video" then
        return
      end

      updateProperty("Player State", "Playing")

      if data and data.item and data.item.type then
        updateProperty("Media Type", data.item.type)
      end

      if (not wasInVideo) and autoRoom.isOnEnabled() then
        logDebug("Auto Room On: sending ON to proxy")
        autoRoom.sendOn()
      end
    end)
  end

  handlers["Player.OnPause"] = function(_)
    logDebug("Player.OnPause notification")

    refreshPlaybackState(function(_, pType)
      if pType == "video" then
        updateProperty("Player State", "Paused")
      end
    end)
  end

  handlers["Player.OnResume"] = function(_)
    logDebug("Player.OnResume notification")

    refreshPlaybackState(function(_, pType)
      if pType == "video" then
        updateProperty("Player State", "Playing")
      end
    end)
  end

  handlers["Player.OnStop"] = function(_)
    logDebug("Player.OnStop notification")

    local wasInVideo = (state.playbackType == "video")

    refreshPlaybackState(function(_, pType)
      -- Only consider "stop" as end-of-session when VIDEO playback ended.
      if wasInVideo and pType ~= "video" then
        avDetails:clear()
        setStoppedProperties()

        if autoRoom.isOffEnabled() then
          logDebug("Auto Room Off: sending OFF to proxy")
          autoRoom.sendOff()
        end
      end
    end)
  end

  handlers["Player.OnSpeedChanged"] = function(data)
    logDebug("Player.OnSpeedChanged notification")

    -- Only update video transport UI when in video playback.
    if state.playbackType ~= "video" then return end

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
