function OnDriverInit(driverInitType)
  print("Kodi driver initialized: " .. tostring(driverInitType))
end

function SendKodiCommand(method, params)
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
      if errCode ~= 0 and Properties["Debug Mode"] == "ON" then
        print("Kodi: Error " .. tostring(errCode) .. ": " .. tostring(errMsg))
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
end
