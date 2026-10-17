local files={}
local state={config="My Preset"}
local localPlayer={Name="TestPlayer"}
local cfg={prioritization={enabled=true,order={"Petals","Tokens"}}}
local cache={}
local HttpService={JSONEncode=function(_,v) return v end}
local function writefile(path,value) files[path]=value end
local function saveConfig(cacheOnly)
	if not cacheOnly then
		writefile("atlas/" .. state.config .. ".json", HttpService:JSONEncode(cfg))
		writefile("atlas-" .. localPlayer.Name .. ".json", state.config .. ".json")
	else
		writefile("atlascache-" .. localPlayer.Name .. ".json", HttpService:JSONEncode(cache))
	end
end

saveConfig()
assert(files["atlas/My Preset.json"].prioritization.order[1]=="Petals")
assert(files["atlas-TestPlayer.json"]=="My Preset.json")
state.config="Other Preset"
saveConfig(true)
assert(files["atlas-TestPlayer.json"]=="My Preset.json","cache save changed selected preset")
assert(files["atlascache-TestPlayer.json"]==cache)
print("PASS: config writes priority data and reload selection; cache saves preserve selection")
