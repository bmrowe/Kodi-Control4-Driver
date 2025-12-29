local pollTimer = nil

function OnDriverInit(driverInitType)
  print("Kodi driver initialized: " .. tostring(driverInitType))
  
  if Properties["Enable Polling"] == "ON" then
    StartPolling()
  end
end

function OnDriverDestroyed()
  StopPolling()
end

function StartPolling()
  StopPolling()
  local interval = tonumber(Properties["Poll Interval (seconds)"]) or 5
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

function PollKodiStatus()
  -- Get active players
  SendKodiCommand("Player.GetActivePlayers", {}, function(response)
    if Properties["Debug Mode"] == "ON" then
      print("Kodi: GetActivePlayers response: " .. C4:JsonEncode(response or {}))
    end
    
    if response and response.result and #response.result > 0 then
      local playerid = response.result[1].playerid
      local playertype = response.result[1].type
      
      if Properties["Debug Mode"] == "ON" then
        print("Kodi: Active player found - ID: " .. playerid .. ", Type: " .. playertype)
      end
      
      C4:UpdateProperty("Media Type", playertype or "-")
      
      -- Get player properties including video stream info
      SendKodiCommandRaw('{"jsonrpc":"2.0","method":"Player.GetProperties","params":{"playerid":' .. playerid .. ',"properties":["speed","percentage","time","totaltime","videostreams","audiostreams"]},"id":1}', function(playerProps)
        if Properties["Debug Mode"] == "ON" then
          print("Kodi: GetProperties response: " .. C4:JsonEncode(playerProps or {}))
        end
        
        if playerProps and playerProps.result then
          local speed = playerProps.result.speed
          if speed == 0 then
            C4:UpdateProperty("Player State", "Paused")
          elseif speed == 1 then
            C4:UpdateProperty("Player State", "Playing")
          else
            C4:UpdateProperty("Player State", "Fast Forward/Rewind")
          end
          
          -- Get video resolution from active stream
          if playerProps.result.videostreams and #playerProps.result.videostreams > 0 then
            local video = playerProps.result.videostreams[1]
            if video.width and video.height then
              C4:UpdateProperty("Video Resolution", video.width .. "x" .. video.height)
              -- Calculate aspect ratio from width/height
              local aspect = video.width / video.height
              C4:UpdateProperty("Video Aspect Ratio", string.format("%.2f", aspect))
            end
          end
        end
      end)
    else
      if Properties["Debug Mode"] == "ON" then
        print("Kodi: No active players found")
      end
      C4:UpdateProperty("Player State", "Stopped")
      C4:UpdateProperty("Media Type", "-")
      C4:UpdateProperty("Video Resolution", "-")
      C4:UpdateProperty("Video Aspect Ratio", "-")
    end
  end)
  
  -- Get system info using InfoLabels - use raw JSON string
  SendKodiCommandRaw('{"jsonrpc":"2.0","method":"XBMC.GetInfoLabels","params":{"labels":["System.ScreenSaverActive","System.CpuUsage","System.FreeMemory","System.CPUTemperature","System.Uptime(hh:mm)","System.BuildVersion"]},"id":1}', function(infoResponse)
    if Properties["Debug Mode"] == "ON" then
      print("Kodi: GetInfoLabels response: " .. C4:JsonEncode(infoResponse or {}))
    end
    
    if infoResponse and infoResponse.result then
      local labels = infoResponse.result
      
      -- Screen saver status
      if labels["System.ScreenSaverActive"] then
        C4:UpdateProperty("Screen Saver", labels["System.ScreenSaverActive"] == "true" and "Active" or "Inactive")
      end
      
      -- CPU Usage
      if labels["System.CpuUsage"] then
        C4:UpdateProperty("CPU Usage", labels["System.CpuUsage"])
      end
      
      -- Memory Usage
      if labels["System.FreeMemory"] then
        C4:UpdateProperty("Memory Usage", labels["System.FreeMemory"])
      end
      
      -- Temperature
      if labels["System.CPUTemperature"] then
        C4:UpdateProperty("System Temperature", labels["System.CPUTemperature"])
      end
      
      -- Uptime
      if labels["System.Uptime(hh:mm)"] and labels["System.Uptime(hh:mm)"] ~= "Busy" then
        C4:UpdateProperty("System Uptime", labels["System.Uptime(hh:mm)"])
      else
        C4:UpdateProperty("System Uptime", "-")
      end
      
      -- Kodi Version
      if labels["System.BuildVersion"] then
        C4:UpdateProperty("Kodi Version", labels["System.BuildVersion"])
      end
    end
  end)
end

function SendKodiCommand(method, params, callback)
  local ip = Properties["IP Address"]
  local port = Properties["Port"] or "8080"
  
  if not ip or ip == "" then
    print("Kodi: No IP address configured")
    return
  end
  
  params = params or {}
  
  local jsonRequest = {
    jsonrpc = "2.0",
    method = method,
    params = params,
    id = 1
  }
  
  local jsonString = C4:JsonEncode(jsonRequest)
  
  if Properties["Debug Mode"] == "ON" then
    print("Kodi: " .. method)
  end
  
  local headers = {
    ["Content-Type"] = "application/json"
  }
  
  C4:url()
    :OnDone(function(transfer, responses, errCode, errMsg)
      if errCode ~= 0 then
        if Properties["Debug Mode"] == "ON" then
          print("Kodi: Error " .. tostring(errCode) .. ": " .. tostring(errMsg))
        end
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
    :Post("http://" .. ip .. ":" .. port .. "/jsonrpc", jsonString, headers)
end

function SendKodiCommandRaw(jsonString, callback)
  local ip = Properties["IP Address"]
  local port = Properties["Port"] or "8080"
  
  if not ip or ip == "" then
    print("Kodi: No IP address configured")
    return
  end
  
  local headers = {
    ["Content-Type"] = "application/json"
  }
  
  C4:url()
    :OnDone(function(transfer, responses, errCode, errMsg)
      if errCode ~= 0 then
        if Properties["Debug Mode"] == "ON" then
          print("Kodi: Error " .. tostring(errCode) .. ": " .. tostring(errMsg))
        end
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
    :Post("http://" .. ip .. ":" .. port .. "/jsonrpc", jsonString, headers)
end

function ExecuteProgramButton(action)
  if action == "None" then
    return
  elseif action == "Show Codec Info" then
    SendKodiCommand("Input.ExecuteAction", {action = "codecinfo"})
  elseif action == "Show OSD" then
    SendKodiCommand("Input.ExecuteAction", {action = "osd"})
  elseif action == "Show Player Process Info" then
    SendKodiCommand("Input.ExecuteAction", {action = "playerprocessinfo"})
  elseif action == "Toggle Subtitles" then
    SendKodiCommand("Player.SetSubtitle", {playerid = 0, subtitle = "toggle"})
    SendKodiCommand("Player.SetSubtitle", {playerid = 1, subtitle = "toggle"})
  elseif action == "Next Subtitle" then
    SendKodiCommand("Player.SetSubtitle", {playerid = 0, subtitle = "next"})
    SendKodiCommand("Player.SetSubtitle", {playerid = 1, subtitle = "next"})
  elseif action == "Next Audio Track" then
    SendKodiCommand("Player.SetAudioStream", {playerid = 0, stream = "next"})
    SendKodiCommand("Player.SetAudioStream", {playerid = 1, stream = "next"})
  elseif action == "Screenshot" then
    SendKodiCommand("Input.ExecuteAction", {action = "screenshot"})
  end
end

function ReceivedFromProxy(BindingID, strCommand, tParams)
  if Properties["Debug Mode"] == "ON" then
    print("ReceivedFromProxy (" .. BindingID .. "): " .. strCommand)
  end
  
  if BindingID == 5001 then
    if strCommand == "ON" then
      SendKodiCommand("Input.Home", {})
      
    elseif strCommand == "OFF" then
      SendKodiCommand("System.Hibernate", {})
      
    elseif strCommand == "PLAY" then
      C4:SendToProxy(5001, "ON", {})
      SendKodiCommand("Player.PlayPause", {playerid = 0, play = true})
      SendKodiCommand("Player.PlayPause", {playerid = 1, play = true})
      
    elseif strCommand == "PAUSE" then
      SendKodiCommand("Player.PlayPause", {playerid = 0, play = false})
      SendKodiCommand("Player.PlayPause", {playerid = 1, play = false})
      
    elseif strCommand == "STOP" then
      SendKodiCommand("Player.Stop", {playerid = 0})
      SendKodiCommand("Player.Stop", {playerid = 1})
      
    elseif strCommand == "SKIP_FWD" then
      local skipSeconds = tonumber(Properties["Skip Interval (seconds)"]) or 30
      SendKodiCommand("Player.Seek", {playerid = 0, value = {seconds = skipSeconds}})
      SendKodiCommand("Player.Seek", {playerid = 1, value = {seconds = skipSeconds}})
      
    elseif strCommand == "SKIP_REV" then
      local skipSeconds = tonumber(Properties["Skip Interval (seconds)"]) or 30
      SendKodiCommand("Player.Seek", {playerid = 0, value = {seconds = -skipSeconds}})
      SendKodiCommand("Player.Seek", {playerid = 1, value = {seconds = -skipSeconds}})
      
    elseif strCommand == "SCAN_FWD" then
      SendKodiCommand("Player.SetSpeed", {playerid = 0, speed = 2})
      SendKodiCommand("Player.SetSpeed", {playerid = 1, speed = 2})
      
    elseif strCommand == "SCAN_REV" then
      SendKodiCommand("Player.SetSpeed", {playerid = 0, speed = -2})
      SendKodiCommand("Player.SetSpeed", {playerid = 1, speed = -2})
      
    elseif strCommand == "PROGRAM_A" then
      ExecuteProgramButton(Properties["Program A Button (Red)"])
      
    elseif strCommand == "PROGRAM_B" then
      ExecuteProgramButton(Properties["Program B Button (Green)"])
      
    elseif strCommand == "PROGRAM_C" then
      ExecuteProgramButton(Properties["Program C Button (Yellow)"])
      
    elseif strCommand == "PROGRAM_D" then
      ExecuteProgramButton(Properties["Program D Button (Blue)"])
      
    elseif strCommand == "UP" then
      SendKodiCommand("Input.Up", {})
      
    elseif strCommand == "DOWN" then
      SendKodiCommand("Input.Down", {})
      
    elseif strCommand == "LEFT" then
      SendKodiCommand("Input.Left", {})
      
    elseif strCommand == "RIGHT" then
      SendKodiCommand("Input.Right", {})
      
    elseif strCommand == "ENTER" then
      SendKodiCommand("Input.Select", {})
      
    elseif strCommand == "CANCEL" then
      SendKodiCommand("Input.Back", {})
      
    elseif strCommand == "MENU" then
      SendKodiCommand("Input.ContextMenu", {})
      
    elseif strCommand == "INFO" then
      SendKodiCommand("Input.Info", {})
    end
  end
end

function OnPropertyChanged(strProperty)
  if Properties["Debug Mode"] == "ON" then
    print("Property changed: " .. strProperty)
  end
  
  if strProperty == "Enable Polling" then
    if Properties["Enable Polling"] == "ON" then
      StartPolling()
    else
      StopPolling()
    end
  elseif strProperty == "Poll Interval (seconds)" then
    if Properties["Enable Polling"] == "ON" then
      StartPolling() -- Restart with new interval
    end
  end
end
