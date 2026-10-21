local cfg={rbc={preset="Blue",beepriorities={}}}
local saves=0
local function saveConfig()saves+=1 end
local rbcBeePriorities = {
	names={"Basic","Bomber","Brave","Bumble","Cool","Hasty","Looker","Rad","Rascal","Stubborn","Bubble","Bucko","Commander","Demo","Exhausted","Fire","Frosty","Honey","Rage","Riley","Shocked","Baby","Carpenter","Demon","Diamond","Lion","Music","Ninja","Shy","Buoyant","Fuzzy","Precise","Spicy","Tadpole","Vector","Bear","Cobalt","Crimson","Digital","Festive","Gummy","Photon","Puppy","Tabby","Vicious","Windy"}
}
function rbcBeePriorities:Get(preset,bee)
	local saved=cfg.rbc.beepriorities
	local priorities=type(saved)=="table" and saved[preset]
	local value=type(priorities)=="table" and priorities[bee]
	if type(value)=="number" and value==value and value>=1 and value<=100 then return math.floor(value) end
	return self.defaults and self.defaults[preset] and self.defaults[preset][bee] or 51
end
function rbcBeePriorities:Set(preset,bee,value)
	if not self.defaults[preset] or not table.find(self.names,bee) then return end
	cfg.rbc.beepriorities=type(cfg.rbc.beepriorities)=="table" and cfg.rbc.beepriorities or {}
	cfg.rbc.beepriorities[preset]=type(cfg.rbc.beepriorities[preset])=="table" and cfg.rbc.beepriorities[preset] or {}
	cfg.rbc.beepriorities[preset][bee]=math.clamp(math.floor(value),1,100)
	saveConfig()
end
function rbcBeePriorities:BuildMenu(tab)
	local folder=tab.AddFolder("Bee Pick Priorities",true)
	folder.AddLabel("Lower number = picked first. Equal numbers use existing tie-breaks.")
	folder.AddLabel("Edits affect the chosen preset only. 51 is the original unranked fallback.")
	local preset=cfg.rbc.preset or "Blue"
	local bee="Digital"
	local value=self:Get(preset,bee)
	local slider,labels
	local function refresh()
		value=self:Get(preset,bee)
		if slider then slider.Set(value) end
		if labels then
			local ordered=table.clone(self.names)
			table.sort(ordered,function(a,b)
				local ra,rb=self:Get(preset,a),self:Get(preset,b)
				return ra==rb and a<b or ra<rb
			end)
			for i,name in ipairs(ordered) do labels[i].Text=tostring(self:Get(preset,name))..". "..name.." Bee" end
		end
	end
	local chooser=folder.AddDropdown("Edit Preset",{"Blue","Red","White"},nil,function(v)preset=v;refresh()end)
	chooser.SetValue(preset)
	local beeChooser=folder.AddDropdown("Bee",self.names,nil,function(v)bee=v;refresh()end)
	beeChooser.SetValue(bee)
	local editState={priority=value}
	slider=folder.AddSlider("Pick Priority",function(v)value=v end,1,100,editState,"priority",{Left=true})
	folder.AddButton("Save Bee Priority",function()self:Set(preset,bee,value);refresh()end)
	folder.AddButton("Reset This Preset",function()
		if type(cfg.rbc.beepriorities)=="table" then cfg.rbc.beepriorities[preset]=nil end
		saveConfig();refresh()
	end)
	labels={}
	for i=1,#self.names do labels[i]=folder.AddLabel("") end
	refresh()
end


rbcBeePriorities.defaults={Blue={
			Digital = 1,
			Windy = 2,
			Bear = 3,
			Tabby = 4,
			Vicious = 5,
			Cobalt = 6,
			Basic = 7,
			Cool = 8,
			Fuzzy = 9,
			Music = 10,
			Rage = 11,
			Commander = 12,
			Frosty = 13,
			Bubble = 14,
			Tadpole = 15,
			Looker = 16,
			Ninja = 17,
			Bomber = 18,
			Buoyant = 19,
			Bucko = 20,
			Bumble = 21,
			Shocked = 22,
			Gummy = 23,
			Puppy = 24,
		},Red={
			Digital = 1,
			Vicious = 2,
			Bear = 3,
			Tabby = 4,
			Photon = 5,
			Festive = 6,
			Crimson = 7,
			Basic = 8,
			Riley = 9,
			Rad = 10,
			Brave = 11,
			Commander = 12,
			Carpenter = 13,
			Precise = 14,
			Spicy = 15,
			Vector = 16,
			Fuzzy = 17,
		},White={ Digital = 1, Tabby = 2, Bear = 3, Photon = 4, Gummy = 5, Vector = 6 }}
assert(rbcBeePriorities:Get("Blue","Digital")==1)
assert(rbcBeePriorities:Get("Red","Vicious")==2)
assert(rbcBeePriorities:Get("White","Vector")==6)
assert(rbcBeePriorities:Get("White","Buoyant")==51)
rbcBeePriorities:Set("Blue","Buoyant",1)
assert(rbcBeePriorities:Get("Blue","Buoyant")==1 and rbcBeePriorities:Get("Red","Buoyant")==51)
assert(cfg.rbc.beepriorities.Blue.Buoyant==1 and saves==1)
local callbacks,buttons,labels={},{},{}
local slider
local folder={}
function folder.AddLabel(text)local label={Text=text};table.insert(labels,label);return label end
function folder.AddDropdown(name,options,_,callback)callbacks[name]=callback;return {SetValue=function()end}end
function folder.AddSlider(name,callback,min,max,source,key)
 assert(type(source)=="table" and key)
 slider={Set=function(value)source[key]=value;callback(value)end}
 return slider
end
function folder.AddButton(name,callback)buttons[name]=callback end
rbcBeePriorities:BuildMenu({AddFolder=function()return folder end})
callbacks["Edit Preset"]("White");callbacks.Bee("Vector");slider.Set(2);buttons["Save Bee Priority"]()
assert(rbcBeePriorities:Get("White","Vector")==2 and rbcBeePriorities:Get("Blue","Buoyant")==1)
buttons["Reset This Preset"]()
assert(rbcBeePriorities:Get("White","Vector")==6 and rbcBeePriorities:Get("Blue","Buoyant")==1)
cfg.rbc.beepriorities.Blue.Buoyant="bad"
assert(rbcBeePriorities:Get("Blue","Buoyant")==19)
print("PASS: preset defaults, independent saved overrides, unranked bees, editor selection/save/reset and invalid-value fallback")
