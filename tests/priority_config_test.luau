
local cfg
local gatheringPriorities={}
local savedConfig,saves
local function copy(value)
 if type(value)~="table"then return value end
 local result={};for k,v in pairs(value)do result[k]=copy(v)end;return result
end
local function saveConfig()savedConfig=copy(cfg);saves=(saves or 0)+1 end
local function defaults()return {prioritization={enabled=true,order={}},autofarm={farmshowers=true},known=5}end
cfg=defaults()
local mergeTable

mergeTable = function(target, source)
	for k, value in pairs(target) do
		if target == cfg.prioritization and k == "order" and type(source[k]) == "table" then
			-- Ordered lists must replace the default, including an empty default.
			-- Recursing over target's keys silently drops saved array entries.
			target[k] = table.clone(source[k])
		elseif type(value) ~= "table" or type(source[k]) ~= "table" then
			if source[k] ~= nil then
				target[k] = source[k]
			end
		elseif next(source[k]) ~= nil then
			mergeTable(value, source[k])
		end
	end
end
gatheringPriorities.defaults = {
	"Petals", "Showers", "Precise Targets", "Duped Smiley", "Duped Bear",
	"Duped Tokens", "Puppy Ball", "Coconuts", "Combo Coconuts", "Token Links",
	"Priority Tokens", "Clouds", "Fuzz Bombs", "Bubbles", "Flames", "Triangulate", "Tokens", "Leaves", "Blooms",
}
gatheringPriorities.flags = {
	["Showers"] = "farmshowers", ["Duped Smiley"] = "farmdupedtokens", ["Duped Bear"] = "farmdupedtokens",
	["Duped Tokens"] = "farmdupedtokens", ["Puppy Ball"] = "farmpuppyball", ["Coconuts"] = "farmcoconuts",
	["Combo Coconuts"] = "farmcombococonuts", ["Clouds"] = "farmclouds", ["Fuzz Bombs"] = "farmfuzzbombs",
	["Flames"] = "farmfires", ["Triangulate"] = "farmtriangulate", ["Leaves"] = "farmleaves",
}
gatheringPriorities.catalog = {
	["Showers"] = {key="showers", kind="Shower"}, ["Duped Smiley"] = {key="dupedsmiley", kind="Duped Smiley"},
	["Duped Bear"] = {key="dupedbear", kind="Duped Bear"}, ["Duped Tokens"] = {key="dupedtokens", kind="Duped"},
	["Puppy Ball"] = {key="puppyball", kind="Puppy Ball"}, ["Coconuts"] = {key="coconuts", kind="Coconut"},
	["Combo Coconuts"] = {key="combococonuts", kind="Combo Coconut"}, ["Token Links"] = {key="tokenlink", kind="Token"},
	["Priority Tokens"] = {key="tokens", kind="Token"}, ["Tokens"] = {key="tokens", kind="Token"},
	["Clouds"] = {key="clouds", kind="Cloud", plane=true}, ["Fuzz Bombs"] = {key="fuzzbombs", kind="Fuzz", plane=true},
	["Bubbles"] = {key="bubbles", kind="Bubble"}, ["Flames"] = {key="flames", kind="Flame"},
	["Leaves"] = {key="leaves", kind="Leaf"},
}
gatheringPriorities.kindCategories = {Petal="Petals", Shower="Showers", Coconut="Coconuts", ["Combo Coconut"]="Combo Coconuts",
	["Duped Smiley"]="Duped Smiley", ["Duped Bear"]="Duped Bear", Duped="Duped Tokens", ["Puppy Ball"]="Puppy Ball",
	Cloud="Clouds", Fuzz="Fuzz Bombs", Bubble="Bubbles", Flame="Flames", Triangulate="Triangulate", Leaf="Leaves", Token="Tokens"}

function gatheringPriorities:Rebuild()
	local settings = cfg.prioritization
	if self.orderSource == settings.order and self.rank then return end
	local known, seen, order = {}, {}, {}
	for _, name in ipairs(self.defaults) do known[name] = true end
	for _, name in ipairs(type(settings.order) == "table" and settings.order or {}) do
		if known[name] and not seen[name] then order[#order + 1], seen[name] = name, true end
	end
	for _, name in ipairs(self.defaults) do if not seen[name] then order[#order + 1] = name end end
	settings.order = order
	self.orderSource = order
	self.rank = {}
	for index, name in ipairs(order) do self.rank[name] = index end
end

function gatheringPriorities:RefreshMenu()
	self.orderSource = nil
	self:Rebuild()
	if self.orderLabels then
		for index, label in ipairs(self.orderLabels) do label.Text = tostring(index) .. ". " .. cfg.prioritization.order[index] end
	end
end

function gatheringPriorities:Move(category, targetIndex)
	self:Rebuild()
	local index = self.rank[category]
	if not index then return end
	table.remove(cfg.prioritization.order, index)
	table.insert(cfg.prioritization.order, math.clamp(targetIndex, 1, #self.defaults), category)
	cfg.prioritization.enabled = true
	if self.enabledSwitch then self.enabledSwitch.Set(true) end
	self:RefreshMenu()
	saveConfig()
end

function gatheringPriorities:BuildMenu(tab)
	self:Rebuild()
	local edit = tab.AddFolder("Prioritization")
	self.enabledSwitch = edit.AddSwitch("Use Custom Order", function()
		self:RefreshMenu()
	end, "prioritization", "enabled")
	edit.AddLabel("1 = highest priority")
	edit.AddLabel("Unavailable targets are skipped")
	edit.AddLabel("Enabled features + field / hazard checks apply")
	local chosen = cfg.prioritization.order[1]
	local chooser = edit.AddDropdown("Target", self.defaults, nil, function(value) chosen = value end)
	chooser.SetValue(chosen)
	edit.AddButton("Make #1", function() self:Move(chosen, 1) end)
	edit.AddButton("Move Up", function() self:Move(chosen, (self.rank[chosen] or 1) - 1) end)
	edit.AddButton("Move Down", function() self:Move(chosen, (self.rank[chosen] or 1) + 1) end)
	edit.AddButton("Reset: Petals First", function()
		cfg.prioritization.order = table.clone(self.defaults)
		self.enabledSwitch.Set(true)
		self:RefreshMenu()
		saveConfig()
	end, 180)
	edit.Toggle(true, true)
	local list = tab.AddFolder("Gathering Order", true)
	self.currentLabel = list.AddLabel("Current target: " .. (self.last or "waiting"))
	self.orderLabels = {}
	for index, category in ipairs(cfg.prioritization.order) do self.orderLabels[index] = list.AddLabel(tostring(index) .. ". " .. category) end
	list.AddLabel("Custom off = petals first, then script order")
	list.Toggle(true, true)
end

-- Initial load from a persisted JSON-shaped object into the empty default.
local persisted={prioritization={enabled=false,order={"Showers","Tokens","Petals"}},autofarm={farmshowers=false},unknown=99}
mergeTable(cfg,persisted)
assert(cfg.prioritization.order[1]=="Showers" and cfg.prioritization.order[2]=="Tokens","saved order dropped")
assert(not cfg.prioritization.enabled and not cfg.autofarm.farmshowers and cfg.known==5 and cfg.unknown==nil)
assert(cfg.prioritization.order~=persisted.prioritization.order,"saved table aliased")
gatheringPriorities:Rebuild()
assert(#cfg.prioritization.order==19 and cfg.prioritization.order[1]=="Showers")
gatheringPriorities:Move("Duped Smiley",1)
assert(savedConfig.prioritization.enabled and savedConfig.prioritization.order[1]=="Duped Smiley")
local expected=table.clone(cfg.prioritization.order)
for reload=1,10 do
 cfg=defaults()
 mergeTable(cfg,savedConfig)
 gatheringPriorities:Rebuild()
 for i,name in ipairs(expected)do assert(cfg.prioritization.order[i]==name,"order changed on reload")end
 assert(cfg.prioritization.enabled)
 saveConfig()
end
-- Old, partial and malformed lists remain normalized by the existing menu.
cfg=defaults();mergeTable(cfg,{prioritization={order={"Tokens","Unknown","Tokens","Petals"}}})
gatheringPriorities:Rebuild()
assert(#cfg.prioritization.order==19 and cfg.prioritization.order[1]=="Tokens" and cfg.prioritization.order[2]=="Petals")
mergeTable(cfg,{prioritization={order={},enabled=false}});gatheringPriorities:Rebuild()
assert(cfg.prioritization.order[1]=="Petals" and not cfg.prioritization.enabled)
cfg=defaults();mergeTable(cfg,{autofarm={farmshowers=false}});gatheringPriorities:Rebuild()
assert(cfg.prioritization.order[1]=="Petals" and cfg.prioritization.enabled)
-- A different preset must replace a previously populated order as well.
mergeTable(cfg,{prioritization={enabled=false,order={"Blooms","Showers"}}});gatheringPriorities:Rebuild()
assert(cfg.prioritization.order[1]=="Blooms" and not cfg.prioritization.enabled)
print("PASS: saved priority order and enabled flag, empty/default/populated merges, save-after-reorder, ten reloads, old/partial configs, duplicate filtering, preset replacement")
