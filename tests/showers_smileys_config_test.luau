local mergeTable
local cfg={autofarm={farmdupedtokens=true,smileytime=4},farmshowers=false}
local original={autofarm={farmdupedtokens=false,smileytime=7,quadrant="Upper Left"},coconutTeam={main="Main"},farmshowers=true}
local savedValue
local HttpService={JSONDecode=function(_,text)return original end,JSONEncode=function(_,value)savedValue=value;return "encoded" end}
local state={config="Normal Preset"}
local localPlayer={Name="Player"}
local cache={}
local function isfile(path)return path=="atlas/Normal Preset.json" end
local function readfile()return "json" end
local function writefile(path,text)assert(path=="atlas/Normal Preset.json" and text=="encoded")end
mergeTable = function(target, source)
	if type(source) ~= "table" then return end
	for k, value in pairs(target) do
		local incoming = source[k]
		if type(value) == "table" and type(incoming) == "table" then
			if next(incoming) ~= nil then mergeTable(value, incoming) end
		elseif type(incoming) == type(value) then
			target[k] = incoming
		end
	end
end

-- Preserve Atlas+ options that this original-based build does not expose.
local function overlaySupportedConfig(saved, supported)
	for key, value in pairs(supported) do
		if type(value) == "table" then
			if type(saved[key]) ~= "table" then saved[key] = {} end
			overlaySupportedConfig(saved[key], value)
		else
			saved[key] = value
		end
	end
	return saved
end

local function saveConfig(cacheOnly)
	if not cacheOnly then
		local path = "atlas/" .. state.config .. ".json"
		local saved = {}
		if isfile(path) then
			local ok, result = pcall(function() return HttpService:JSONDecode(readfile(path)) end)
			if ok and type(result) == "table" then saved = result end
		end
		writefile(path, HttpService:JSONEncode(overlaySupportedConfig(saved, cfg)))
	else
		writefile("atlascache-" .. localPlayer.Name .. ".json", HttpService:JSONEncode(cache))
	end
end

mergeTable(cfg,original)
assert(not cfg.autofarm.farmdupedtokens and cfg.autofarm.smileytime==7 and cfg.farmshowers)
assert(not cfg.coconutTeam and not cfg.autofarm.quadrant,"unsupported options entered active config")
mergeTable(cfg,{autofarm=false,farmshowers={}})
assert(type(cfg.autofarm)=="table" and cfg.farmshowers==true,"wrong types replaced supported config")
cfg.autofarm.smileytime=5
saveConfig(false)
assert(savedValue.autofarm.smileytime==5 and savedValue.autofarm.quadrant=="Upper Left")
assert(savedValue.coconutTeam.main=="Main","Atlas+ options erased while saving")
print("PASS: normal config load, unknown options ignored, type validation and unsupported settings preserved on save")
