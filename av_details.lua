local AvDetails = {}
AvDetails.__index = AvDetails

local AV_DETAILS_LABELS = {
  "Player.Process(videowidth)",
  "Player.Process(videoheight)",
  "VideoPlayer.VideoAspect",
  "VideoPlayer.VideoCodec",
  "VideoPlayer.HdrType",
  "VideoPlayer.AudioCodec",
  "VideoPlayer.AudioChannels",
  "VideoPlayer.AudioLanguage"
}

function AvDetails:new(options)
  local instance = setmetatable({}, AvDetails)

  instance.kodiRpc = assert(options.kodiRpc, "kodiRpc is required")
  instance.updateProperty = assert(options.updateProperty, "updateProperty is required")
  instance.setTimer = assert(options.setTimer, "setTimer is required")
  instance.cancelTimer = assert(options.cancelTimer, "cancelTimer is required")

  instance.logDebug = options.logDebug or function(_) end
  instance.debounceMs = options.debounceMs or 500

  instance.timerId = nil
  instance.inFlight = false
  instance.gen = 0
  instance.needsRefresh = false
  return instance
end

local function buildAvDetails(infoLabels)
  if not infoLabels or type(infoLabels) ~= "table" then
    return nil, nil
  end

  local function stripCommas(value)
    if not value or value == "" then return nil end
    return (tostring(value):gsub(",", ""))
  end

  local videoWidth = stripCommas(infoLabels["Player.Process(videowidth)"])
  local videoHeight = stripCommas(infoLabels["Player.Process(videoheight)"])
  local resolution = (videoWidth and videoHeight) and (videoWidth .. "x" .. videoHeight) or "N/A"

  local aspect = infoLabels["VideoPlayer.VideoAspect"] or "N/A"

  local videoCodec = (infoLabels["VideoPlayer.VideoCodec"] and infoLabels["VideoPlayer.VideoCodec"] ~= "")
    and infoLabels["VideoPlayer.VideoCodec"] or "N/A"

  local hdrType = (infoLabels["VideoPlayer.HdrType"] and infoLabels["VideoPlayer.HdrType"] ~= "")
    and infoLabels["VideoPlayer.HdrType"] or "SDR"

  local audioCodec = (infoLabels["VideoPlayer.AudioCodec"] and infoLabels["VideoPlayer.AudioCodec"] ~= "")
    and infoLabels["VideoPlayer.AudioCodec"] or "N/A"

  local audioChannels = (infoLabels["VideoPlayer.AudioChannels"] and infoLabels["VideoPlayer.AudioChannels"] ~= "")
    and infoLabels["VideoPlayer.AudioChannels"] or ""

  local audioLanguage = (infoLabels["VideoPlayer.AudioLanguage"] and infoLabels["VideoPlayer.AudioLanguage"] ~= "")
    and infoLabels["VideoPlayer.AudioLanguage"] or ""

  local videoDetails = resolution .. " | " .. aspect .. " | " .. videoCodec .. " " .. hdrType

  local audioDetails = audioCodec
  if audioChannels ~= "" then audioDetails = audioDetails .. " " .. audioChannels .. "ch" end
  if audioLanguage ~= "" then audioDetails = audioDetails .. " " .. audioLanguage end

  return videoDetails, audioDetails
end

function AvDetails:requestNow()
  if self.inFlight then
    self.needsRefresh = true
    return
  end

  local myGen = self.gen
  self.inFlight = true
  self.needsRefresh = false
  self.logDebug("Requesting AV details")

  self.kodiRpc:sendInfoLabelsRequest(AV_DETAILS_LABELS, function(result)
    self.inFlight = false
    if myGen ~= self.gen then return end
    local videoDetails, audioDetails = buildAvDetails(result)
    if not videoDetails or not audioDetails then
      self.logDebug("GetInfoLabels returned invalid data")
      if self.needsRefresh then
        self:scheduleUpdate()
      end
      return
    end

    self.updateProperty("Video Details", videoDetails)
    self.updateProperty("Audio Details", audioDetails)

    if self.needsRefresh then
      self:scheduleUpdate()
    end

    self.logDebug("Video Details: " .. videoDetails)
    self.logDebug("Audio Details: " .. audioDetails)
  end)
end

function AvDetails:scheduleUpdate()
  self.gen = self.gen + 1
  local myGen = self.gen

  self.cancelTimer(self.timerId)
  self.timerId = self.setTimer(self.debounceMs, function()
    self.timerId = nil
    if myGen ~= self.gen then return end  -- stale callback, ignore
    self:requestNow()
  end)
end


function AvDetails:clear()
  self.cancelTimer(self.timerId)
  self.timerId = nil
  self.gen = self.gen + 1  -- invalidate any queued callbacks
  self.inFlight = false
  self.needsRefresh = false
end



function AvDetails:resetProperties()
  self.updateProperty("Video Details", "N/A")
  self.updateProperty("Audio Details", "N/A")
end

return AvDetails
