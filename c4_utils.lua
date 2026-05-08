local C4Utils = {}

function C4Utils.createLogger(prefix)
  prefix = prefix or ""

  local function logInfo(message)
    print(prefix .. tostring(message))
  end

  local function logDebug(message)
    if Properties and Properties["Debug Mode"] == "ON" then
      print(prefix .. tostring(message))
    end
  end

  return {
    info = logInfo,
    debug = logDebug,
  }
end

function C4Utils.updateProperty(propertyName, value)
  C4:UpdateProperty(propertyName, value)
end

function C4Utils.cancelTimer(timerId)
  if type(timerId) == "number" and timerId ~= 0 then
    pcall(function() C4:KillTimer(timerId) end)
  elseif type(timerId) == "userdata" and timerId.Cancel then
    pcall(function() timerId:Cancel() end)
  end
  return nil
end

return C4Utils
