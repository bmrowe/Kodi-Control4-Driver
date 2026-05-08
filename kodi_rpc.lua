local KodiRpc = {}
KodiRpc.__index = KodiRpc

local function cancelTimerHandle(t)
  if not t then return end
  if type(t) == "number" then
    pcall(function() C4:KillTimer(t) end)
  elseif type(t) == "userdata" and t.Cancel then
    pcall(function() t:Cancel() end)
  end
end


function KodiRpc:new(options)
  local instance = setmetatable({}, KodiRpc)
  instance.jsonEncode = assert(options.jsonEncode, "jsonEncode is required")
  instance.setTimer = assert(options.setTimer, "setTimer is required")
  instance.callbackTimeoutMs = options.callbackTimeoutMs or 10000
  instance.logDebug = options.logDebug or function(_) end
  instance.logInfo = options.logInfo or function(_) end
  instance.isConnectedFn = options.isConnectedFn
  instance.onTransportError = options.onTransportError
  instance.webSocket = nil
  instance.nextRequestId = 0
  instance.pendingCallbacks = {}

  return instance
end

function KodiRpc:setWebSocket(webSocket)
  self.webSocket = webSocket
end

function KodiRpc:isConnected()
  if self.isConnectedFn then
    return self.isConnectedFn()
  end
  return self.webSocket and self.webSocket.running
end

function KodiRpc:clearPendingCallbacks()
  for _, entry in pairs(self.pendingCallbacks) do
    if type(entry) == "table" and entry.timerId then
      cancelTimerHandle(entry.timerId)
    end
    self:_completeCallback(entry, nil, "cancelled")
  end
  self.pendingCallbacks = {}
end

function KodiRpc:_completeCallback(entry, result, err)
  if type(entry) ~= "table" or type(entry.callback) ~= "function" then
    return
  end

  local ok, callbackErr = pcall(function()
    entry.callback(result, err)
  end)
  if not ok then
    self.logInfo("JSON-RPC callback error: " .. tostring(callbackErr))
  end
end

function KodiRpc:_allocateRequestId()
  self.nextRequestId = self.nextRequestId + 1
  if self.nextRequestId > 9999 then self.nextRequestId = 1 end
  return self.nextRequestId
end

function KodiRpc:_registerCallback(requestId, requestNameForLog, callback)
  if not callback then return end
  
  local requestIdKey = tostring(requestId)
  local timerId = self.setTimer(self.callbackTimeoutMs, function()
    local entry = self.pendingCallbacks[requestIdKey]
    if entry then
      self.logDebug("Callback timeout for " .. requestNameForLog .. " (id=" .. requestId .. ")")
      self.pendingCallbacks[requestIdKey] = nil
      self:_completeCallback(entry, nil, "timeout")
    end
  end)
  
  self.pendingCallbacks[requestIdKey] = {
    callback = callback,
    timerId = timerId
  }
end

function KodiRpc:_failTransport(why)
  self.logInfo("Transport failure: " .. tostring(why))
  if self.onTransportError then
    pcall(function() self.onTransportError(why) end)
  end
end

function KodiRpc:_safeSend(payload, context)
  if not self.webSocket then
    self:_failTransport("no_websocket")
    return false
  end

  local ok, retOrErr = pcall(function()
    return self.webSocket:Send(payload)
  end)

  if not ok then
    self:_failTransport("send_exception:" .. tostring(retOrErr))
    return false
  end

  -- Some libs return nil/false on failure; treat that as failure too.
  if retOrErr == nil or retOrErr == false then
    self:_failTransport("send_failed:" .. tostring(context))
    return false
  end

  return true
end

function KodiRpc:sendRequest(method, params, callback)
  if not self:isConnected() then
    self.logDebug("Cannot send " .. method .. " - WebSocket not connected")
    self:_failTransport("not_connected")
    return false
  end

  local requestId = self:_allocateRequestId()

  local request = {
    jsonrpc = "2.0",
    id = requestId,
    method = method,
    params = params or {}
  }

  self:_registerCallback(requestId, method, callback)
  self.logDebug("Sending: " .. method .. " (id=" .. requestId .. ")")
  local ok = self:_safeSend(self.jsonEncode(request), method)
  if not ok then
    local key = tostring(requestId)
    local entry = self.pendingCallbacks[key]
    if type(entry) == "table" and entry.timerId then
      cancelTimerHandle(entry.timerId)
    end
    self.pendingCallbacks[key] = nil
    self:_completeCallback(entry, nil, "send_failed")
    return false
  end

  return true
end


function KodiRpc:_buildGetInfoLabelsJson(requestId, labels)
  -- Manual JSON array construction since C4:JsonEncode may not treat Lua arrays as JSON arrays.
  local labelList = {}
  for _, label in ipairs(labels) do
    table.insert(labelList, '"' .. label .. '"')
  end
  local labelsJson = "[" .. table.concat(labelList, ",") .. "]"

  return string.format(
    '{"jsonrpc":"2.0","id":%d,"method":"XBMC.GetInfoLabels","params":{"labels":%s}}',
    requestId,
    labelsJson
  )
end

function KodiRpc:sendInfoLabelsRequest(labels, callback)
  if not self:isConnected() then
    self.logDebug("Cannot send GetInfoLabels - WebSocket not connected")
    self:_failTransport("not_connected")
    return false
  end

  local requestId = self:_allocateRequestId()
  self:_registerCallback(requestId, "GetInfoLabels", callback)

  local json = self:_buildGetInfoLabelsJson(requestId, labels)
  self.logDebug("Sending: XBMC.GetInfoLabels (id=" .. requestId .. ")")

  local ok = self:_safeSend(json, "GetInfoLabels")
  if not ok then
    local key = tostring(requestId)
    local entry = self.pendingCallbacks[key]
    if type(entry) == "table" and entry.timerId then
      cancelTimerHandle(entry.timerId)
    end
    self.pendingCallbacks[key] = nil
    self:_completeCallback(entry, nil, "send_failed")
    return false
  end

  return true
end

function KodiRpc:executeAction(actionName)
  return self:sendRequest("Input.ExecuteAction", { action = actionName })
end

function KodiRpc:sendInput(inputMethodSuffix)
  return self:sendRequest("Input." .. inputMethodSuffix, {})
end

function KodiRpc:handleResponse(response)
  local responseIdKey = tostring(response.id)
  self.logDebug("Response ID: " .. responseIdKey)
  
  local entry = self.pendingCallbacks[responseIdKey]
  if not entry then return end
  
  self.pendingCallbacks[responseIdKey] = nil
  
  if type(entry) == "table" then
    if entry.timerId then cancelTimerHandle(entry.timerId) end
    if not response.error then
      self:_completeCallback(entry, response.result, nil)
    else
      self.logInfo("JSON-RPC error: " .. self.jsonEncode(response.error))
      self:_completeCallback(entry, nil, response.error)
    end
  end
end

return KodiRpc
