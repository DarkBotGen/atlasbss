local folders={}
local textboxes={}
local switches={}
local dropdowns={}
local comboController={}
local availableFields={["Pepper Patch"]=true}
local function getService()return {GetPlayers=function()return {{Name="MainBee"},{Name="AltOne"},{Name="AltTwo"}}end}end
local tab={AddFolder=function(name)
 folders[name]=true
 return {AddSwitch=function(name) switches[name]=true end,AddLabel=function()return {}end,
 AddDropdown=function(name)dropdowns[name]=true;return {Add=function()end,SetValue=function()end}end,
 AddSlider=function()end,AddTextBox=function(name,fn)textboxes[name]=fn end,
 AddButton=function()end,Toggle=function()end}
end}
local controls={farming=tab}
function comboController:BuildMenu(tab)
	local folder=tab.AddFolder("Coconut Team")
	folder.AddSwitch("Coordinate Coconut Team",function()self:Configure()end,"coconutteam","enabled")
	folder.AddSwitch("Fast Combo Catching",function()self:Configure()end,"coconutteam","fast")
	folder.AddLabel("Fast mode works with autofarm off. Outside catchers need this enabled.")
	folder.AddLabel("Solo fast mode catches outside the selected team field without alternating.")
	local names={"None"}
	for _,p in ipairs(getService("Players"):GetPlayers())do names[#names+1]=p.Name end
	local selectors={}
	for _,entry in ipairs({{"Main Account","main"},{"Spawning Alt 1","alt1"},{"Spawning Alt 2","alt2"},{"Outside Catcher 1","catcher1"},{"Outside Catcher 2","catcher2"},{"Outside Catcher 3","catcher3"}})do
		selectors[entry[2]]=folder.AddDropdown(entry[1],names,nil,function()self:Configure()end,"coconutteam",entry[2])
	end
	local fieldSelector=folder.AddDropdown("Team Field",availableFields,true,function()self:Configure()end,"coconutteam","field",{Field=true})
	folder.AddSlider("Fast Combo Maximum Speed",function()self:Configure()end,30,180,"coconutteam","maxspeed",{Left=true})
	folder.AddTextBox("Paste Connection / Team Code",function(text)
		local ok,code=pcall(HttpService.JSONDecode,HttpService,text)
		if not ok or type(code)~="table" or type(code.url)~="string" or type(code.key)~="string"
			or #code.key<32 or #code.key>128 or not (string.match(code.url,"^https://[%w%.%-]+:?%d*$") or string.match(code.url,"^http://127%.0%.0%.1:%d+$")) then
			ui.Notify("Coconut Team","Invalid connection code");return
		end
		cfg.coconutteam.url,cfg.coconutteam.key=code.url,code.key
		for _,key in ipairs({"main","alt1","alt2","catcher1","catcher2","catcher3"})do
			if type(code[key])=="string" and #code[key]<=20 then
				cfg.coconutteam[key]=code[key]
				selectors[key].Add(code[key]);selectors[key].SetValue(code[key])
			end
		end
		if type(code.field)=="string" and availableFields[code.field] then cfg.coconutteam.field=code.field;fieldSelector.SetValue(code.field) end
		saveConfig();self:Configure();ui.Notify("Coconut Team","Connection and account settings saved")
	end)
	folder.AddButton("Copy Team Code",function()
		local c=cfg.coconutteam
		local copy=setclipboard or toclipboard
		if not copy then ui.Notify("Coconut Team","Clipboard unavailable");return end
		copy(HttpService:JSONEncode({url=c.url,key=c.key,main=c.main,alt1=c.alt1,alt2=c.alt2,catcher1=c.catcher1,catcher2=c.catcher2,catcher3=c.catcher3,field=c.field}))
		ui.Notify("Coconut Team","Paste this code into each team account")
	end)
	folder.AddButton("Reconnect Coordinator",function()self:Configure()end)
	self.statusLabel=folder.AddLabel("Team: Disabled")
	self.ownerLabel=folder.AddLabel("Last combo owner: waiting for a new combo")
	folder.AddLabel("One launcher for all computers. All accounts must be in the same Roblox server.")
	folder.Toggle(true,true)
end

comboController:BuildMenu(controls.farming)

assert(folders["Coconut Team"],"team folder missing")
assert(type(textboxes["Paste Connection / Team Code"])=="function","code entry missing")
assert(switches["Coordinate Coconut Team"] and switches["Fast Combo Catching"])
assert(dropdowns["Main Account"] and dropdowns["Spawning Alt 1"] and dropdowns["Outside Catcher 3"])
print("PASS: actual startup menu call uses controls.farming; team folder, code box, account selectors and switches created")
