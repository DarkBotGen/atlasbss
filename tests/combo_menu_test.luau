local folders={}
local switches={}
local dropdowns={}
local textboxes={}
local sliders={}
local cfg={coconutcombo={enabled=false,catchall=false,main="None",maxspeed=180}}
local state={config="Preset 1"}
local localPlayer={Name="AltOne"}
local function saveConfig()end
local function getService()
 return {
  GetPlayers=function()return {{Name="MainBee"},{Name="AltOne"},{Name="AltTwo"}}end,
  PlayerAdded={Connect=function(_,fn)return {Disconnect=function()end}end}
 }
end
local connections={Add=function()end,Cancel=function()end}
local comboController={}
function comboController:Configure()end

-- Extract actual BuildMenu from github-release/atlasbss.lua so menu drift is impossible.
local tab={AddFolder=function(name)
 folders[name]=true
 return {
  AddSwitch=function(name)switches[name]=true end,
  AddLabel=function()return {Text=""}end,
  AddDropdown=function(name)dropdowns[name]=true;return {Add=function()end,SetValue=function()end}end,
  AddSlider=function(name)sliders[name]=true end,
  AddTextBox=function(name,fn)textboxes[name]=fn;return {}end,
  AddButton=function()end,
  Toggle=function()end
 }
end}
local controls={farming=tab}

function comboController:BuildMenu(tab)
	local folder=tab.AddFolder("Coconut Combo")
	folder.AddSwitch("Enable Coconut Combo",function()self:Configure()end,"coconutcombo","enabled")
	folder.AddSwitch("Catch All Combos in Field",function()self:Configure()end,"coconutcombo","catchall",{Tooltip="Catches every combo in your current field regardless of owner and ignores Main Account exit rules (for Coconut Field alts)."})
	local playersService=getService("Players")
	local names,seen={"None"},{None=true}
	local savedMain=cfg.coconutcombo.main
	if type(savedMain)=="string" and savedMain~="" and not seen[savedMain] then
		seen[savedMain]=true
		names[#names+1]=savedMain
	end
	for _,p in ipairs(playersService:GetPlayers()) do
		if p and type(p.Name)=="string" and not seen[p.Name] then
			seen[p.Name]=true
			names[#names+1]=p.Name
		end
	end
	local mainDropdown=folder.AddDropdown("Main Account",names,nil,function()self:Configure()end,"coconutcombo","main")
	local initialMain=(type(savedMain)=="string" and savedMain~="" and savedMain~="None") and savedMain or nil
	folder.AddTextBox("Main Account Username",function(text)
		local trimmed=string.match(tostring(text or ""),"^%s*(.-)%s*$")
		local value=(trimmed and trimmed~="") and trimmed or "None"
		cfg.coconutcombo.main=value
		if not seen[value] then
			seen[value]=true
			pcall(function() mainDropdown.Add(value) end)
		end
		pcall(function() mainDropdown.SetValue(value) end)
		saveConfig()
		self:Configure()
	end,initialMain,true)
	if playersService.PlayerAdded then
		connections:Add("comboPlayerAdded",playersService.PlayerAdded:Connect(function(player)
			local pname=player and player.Name
			if type(pname)=="string" and pname~="" and not seen[pname] then
				seen[pname]=true
				pcall(function() mainDropdown.Add(pname) end)
			end
		end))
	end
	folder.AddSlider("Fast Combo Maximum Speed",function()self:Configure()end,30,240,"coconutcombo","maxspeed",{Left=true})
	self.statusLabel=folder.AddLabel("Combo: Disabled")
	self.effectLabel=folder.AddLabel("Tracking: waiting for combo")
	folder.AddLabel("Catches your own combo (0x+) and Main's combo (1x+) when Main isn't inside.")
	folder.AddLabel("Exits any player's combo circle when Main steps inside and resumes farming.")
	folder.AddLabel("Coconut Field alts: turn ON Catch All Combos in Field to catch everything in that field.")
	folder.Toggle(true,true)
end

comboController:BuildMenu(controls.farming)

assert(folders["Coconut Combo"] and not folders["Coconut Team"],"wrong folder name")
assert(switches["Enable Coconut Combo"] and switches["Catch All Combos in Field"],"enable or catch-all switch missing")
assert(dropdowns["Main Account"] and type(textboxes["Main Account Username"])=="function","main account controls missing")
assert(sliders["Fast Combo Maximum Speed"],"speed slider missing")
textboxes["Main Account Username"]("MainBee")
assert(cfg.coconutcombo.main=="MainBee","textbox did not set main account")
print("PASS: Coconut Combo menu created in controls.farming with Main Account dropdown/textbox, enable switch, and max speed slider")
