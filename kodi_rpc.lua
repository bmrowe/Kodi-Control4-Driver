local KodiRpc = {}
KodiRpc.__index = KodiRpc

function KodiRpc:new(options)
  local instance = setmetatable({}, KodiRpc)
  instance.jsonEncode = assert(options.jsonEncode, "jsonEncode is required")
  instance.setTimer = assert(options.setTimer, "setTimer is required")
  instance.callbackTimeoutMs = options.callbackTimeoutMs or 10000
  instance.logDebug = options.logDebug or function(_) end
  instance.logInfo = options.logInfo or function(_) end

  -- Optional hooks (so the driver can own connection truth + reconnect)
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
  self.pendingCallbacks = {}
end

function KodiRpc:_allocateRequestId()
  self.nextRequestId = self.nextRequestId + 1
  if self.nextRequestId > 9999 then self.nextRequestId = 1 end
  return self.nextRequestId
end

function KodiRpc:_registerCallback(requestId, requestNameForLog, callback)
  if not callback then return end

  local requestIdKey = tostring(requestId)
  self.pendingCallbacks[requestIdKey] = callback

  self.setTimer(self.callbackTimeoutMs, function()
    if self.pendingCallbacks[requestIdKey] then
      self.logDebug("Callback timeout for " .. requestNameForLog .. " (id=" .. requestId .. ")")
      self.pendingCallbacks[requestIdKey] = nil
    end
  end)
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
    self.pendingCallbacks[tostring(requestId)] = nil
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
    self.pendingCallbacks[tostring(requestId)] = nil
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

  local callback = self.pendingCallbacks[responseIdKey]
  if not callback then return end

  self.pendingCallbacks[responseIdKey] = nil

  if not response.error then
    callback(response.result)
  else
    self.logInfo("JSON-RPC error: " .. self.jsonEncode(response.error))
  end
end

return KodiRpc
