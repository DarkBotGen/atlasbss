local cfg={rbc={bestbluefield=false,bestredfield=false,bestwhitefield=false,upgrades=false,cogupgrades=true,upgradesenabled=false},autofarm={smileytime=4}}
local disk={rbc={bestbluefield="Pine Tree Forest",bestredfield="Pepper Patch",bestwhitefield="Coconut Field",upgrades={RAM=true,Botnet=true},cogupgrades=false,upgradesenabled=true,unknown="keep"},team={main="Main"}}
local HttpService={JSONDecode=function()return disk end,JSONEncode=function(_,v)return v end}
local state={config="Preset 1"};local localPlayer={Name="Player"};local cache={}
local function isfile()return true end
local function readfile()return disk end
local function writefile(_,v)disk=v end
local function copyConfig(value)
	if type(value) ~= "table" then return value end
	local result = {}
	for key, item in pairs(value) do result[key] = copyConfig(item) end
	return result
end
local configSchema = copyConfig(cfg)
local mergeTable
mergeTable = function(target, source, schema)
	if type(source) ~= "table" then return end
	schema = schema or configSchema
	for key, default in pairs(schema) do
		local incoming = source[key]
		if incoming == nil then continue end
		-- Original Atlas uses false as the unset value for dropdowns and modals.
		if default == false then
			if type(incoming)=="boolean" or type(incoming)=="string" or type(incoming)=="number" or type(incoming)=="table" then
				target[key] = copyConfig(incoming)
			end
		elseif type(default)=="table" and type(incoming)=="table" then
			if type(target[key])~="table" then target[key]=copyConfig(default) end
			mergeTable(target[key], incoming, default)
		elseif type(incoming)==type(default) then target[key]=incoming end
	end
end

-- Preserve unsupported Atlas+ settings, but replace selections so deselections persist.
local function overlaySupportedConfig(saved, supported, schema)
	schema = schema or configSchema
	for key, value in pairs(supported) do
		if type(value)=="table" and type(schema[key])=="table" then
			if type(saved[key])~="table" then saved[key]={} end
			overlaySupportedConfig(saved[key],value,schema[key])
		else saved[key]=copyConfig(value) end
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

mergeTable(cfg,disk)
assert(cfg.rbc.bestbluefield=="Pine Tree Forest" and cfg.rbc.bestredfield=="Pepper Patch" and cfg.rbc.bestwhitefield=="Coconut Field")
assert(cfg.rbc.upgrades.RAM and cfg.rbc.upgrades.Botnet and cfg.rbc.upgradesenabled and not cfg.rbc.cogupgrades)
assert(not cfg.team and not cfg.rbc.unknown)
cfg.rbc.upgrades.Botnet=nil;cfg.rbc.cogupgrades=true
saveConfig(false)
assert(not disk.rbc.upgrades.Botnet and disk.rbc.upgrades.RAM,"deselected upgrades resurrected")
assert(disk.team.main=="Main" and disk.rbc.unknown=="keep","unsupported settings erased")
cfg.rbc.bestbluefield=false;cfg.rbc.upgrades=false;cfg.rbc.cogupgrades=false;cfg.rbc.upgradesenabled=false
mergeTable(cfg,disk)
assert(cfg.rbc.bestbluefield=="Pine Tree Forest" and cfg.rbc.upgrades.RAM and cfg.rbc.cogupgrades and cfg.rbc.upgradesenabled,"relaunch lost RBC options")
print("PASS: RBC field selections, upgrade modal, auto-buy toggles, deselections and unknown settings round-trip")
