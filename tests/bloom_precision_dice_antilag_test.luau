
local function vector(x,y,z)
 local mt={}
 mt.__add=function(a,b)return vector(a.X+b.X,a.Y+b.Y,a.Z and a.Z+b.Z or nil)end
 mt.__sub=function(a,b)return vector(a.X-b.X,a.Y-b.Y,a.Z and a.Z-b.Z or nil)end
 mt.__mul=function(a,b)if type(a)=="number"then a,b=b,a end;return vector(a.X*b,a.Y*b,a.Z and a.Z*b or nil)end
 mt.__div=function(a,b)return vector(a.X/b,a.Y/b,a.Z and a.Z/b or nil)end
 mt.__index=function(a,k)
  local z=rawget(a,"Z")
  local mag=math.sqrt(a.X*a.X+a.Y*a.Y+(z or 0)^2)
  if k=="Magnitude"then return mag end
  if k=="Unit"then return mag>0 and a/mag or vector(0,0,z and 0 or nil)end
  if k=="Dot"then return function(s,b)return s.X*b.X+s.Y*b.Y+(rawget(s,"Z") or 0)*(rawget(b,"Z") or 0) end end
 end
 return setmetatable({X=x,Y=y,Z=z},mt)
end
local Vector2={new=function(x,y)return vector(x,y)end}
local Vector3={new=vector,zero=vector(0,0,0)}
local function typeof(v)
 if type(v)=="table" and v.ClassName then return "Instance" end
 if type(v)=="table" and v.X and v.Y and v.Z and not v.Position then return "Vector3" end
 return type(v)
end

local currentField={Name="Pepper Patch"}
local rootPos=vector(0,3,0)
local function getRootPart()return {Position=rootPos}end
local function getHumanoid()return {WalkSpeed=60,Health=100}end
local function getFieldAt()return currentField end
local function distanceTo(p)return (p-rootPos).Magnitude end
local function isPathClear()return false end
local fieldPositionPolicy={
 StrictAllowed=function()return true end,
 Allowed=function()return true end,
 SmileyOnly=function()return false end,
 TrackedAllowed=function()return true end,
 TargetPosition=function(_,o)return type(o)=="table" and o.Position or nil end,
}
local comboController={active=false,TravelBlocked=function()return false end,IsRestrictedZone=function()return false end,PathCrossesRestrictedZone=function()return false end,BlocksMove=function()return false end}
local showerController={active=false}
local rbcSafety={Hazards=function()return {}end,BuffTarget=function()return nil end}
local bearCombat={active=false,Pick=function()return nil end,IconEligible=function()return true end,Icon=function()return "1"end,Ready=function()return true end}
local dupedTokenPolicy={Allowed=function()return true end}
local tokenPriority={autofarm={},sprout={}}
local touchedMarks={}
local buffs={}
local tracked={tokens={},tokenlink={},petals={},blooms={},precise={},precise2={},precisegroup={},precisemark={},coconuts={},bubbles={},flames={},clouds={},fuzzbombs={},triangulate={},leaves={},puppyball={},dupedsmiley={},dupedbear={},dupedtokens={}}
local state={activityStatus=1,precise=false}
local cfg={autofarm={enabled=true,farmblooms=true,farmpetals=true,farmprecise=true,farmprecisemark=true,precisionupkeep=true},prioritization={enabled=true,order={}},convert={standInPrecise=false,standInPreciseAt=75}}
local localPlayer={CoreStats={Pollen={Value=0},Capacity={Value=100}}}
local selectedBloom=nil
local bloomController={Select=function()return selectedBloom end}
local selectedPetal=nil
local petalCollector={Enabled=function(_,opts)return cfg.autofarm.farmblooms or cfg.autofarm.farmpetals or (opts and opts.petals)end,Select=function(_,opts,root,clusterOrigin)return selectedPetal end}
local gatheringPriorities={}
local function saveConfig()end

gatheringPriorities.petals = petalCollector
gatheringPriorities.bloomRange = 25
gatheringPriorities.bloomFocusCategories = {
	"Token Links", "Priority Tokens", "Duped Smiley", "Duped Bear",
	"Duped Tokens", "Puppy Ball", "Coconuts", "Bubbles", "Flames",
	"Clouds", "Fuzz Bombs", "Tokens", "Leaves",
}
gatheringPriorities.bloomSkip = {
	Blooms = true, Petals = true, Showers = true, ["Precise Targets"] = true, Triangulate = true,
}
gatheringPriorities.defaults = {
	"Petals", "Blooms", "Showers", "Precise Targets", "Duped Smiley", "Duped Bear",
	"Duped Tokens", "Puppy Ball", "Coconuts", "Token Links",
	"Priority Tokens", "Clouds", "Fuzz Bombs", "Bubbles", "Flames", "Triangulate", "Tokens", "Leaves",
}
gatheringPriorities.flags = {
	["Showers"] = "farmshowers", ["Duped Smiley"] = "farmdupedtokens", ["Duped Bear"] = "farmdupedtokens",
	["Duped Tokens"] = "farmdupedtokens", ["Puppy Ball"] = "farmpuppyball", ["Coconuts"] = "farmcoconuts",
	["Clouds"] = "farmclouds", ["Fuzz Bombs"] = "farmfuzzbombs",
	["Flames"] = "farmfires", ["Triangulate"] = "farmtriangulate", ["Leaves"] = "farmleaves",
}
gatheringPriorities.catalog = {
	["Showers"] = {key="showers", kind="Shower"}, ["Duped Smiley"] = {key="dupedsmiley", kind="Duped Smiley"},
	["Duped Bear"] = {key="dupedbear", kind="Duped Bear"}, ["Duped Tokens"] = {key="dupedtokens", kind="Duped"},
	["Puppy Ball"] = {key="puppyball", kind="Puppy Ball"}, ["Coconuts"] = {key="coconuts", kind="Coconut"},
	["Token Links"] = {key="tokenlink", kind="Token"},
	["Priority Tokens"] = {key="tokens", kind="Token"}, ["Tokens"] = {key="tokens", kind="Token"},
	["Clouds"] = {key="clouds", kind="Cloud", plane=true}, ["Fuzz Bombs"] = {key="fuzzbombs", kind="Fuzz", plane=true},
	["Bubbles"] = {key="bubbles", kind="Bubble"}, ["Flames"] = {key="flames", kind="Flame"},
	["Leaves"] = {key="leaves", kind="Leaf"},
}
gatheringPriorities.kindCategories = {Petal="Petals", Bloom="Blooms", Shower="Showers", Coconut="Coconuts",
	["Duped Smiley"]="Duped Smiley", ["Duped Bear"]="Duped Bear", Duped="Duped Tokens", ["Puppy Ball"]="Puppy Ball",
	Cloud="Clouds", Fuzz="Fuzz Bombs", Bubble="Bubbles", Flame="Flames", Triangulate="Triangulate", Leaf="Leaves", Token="Tokens"}

function gatheringPriorities:BloomTarget(opts)
	if not opts or opts.loot or opts.mondotokens or opts.ignoreflower or not opts.blooms or not cfg.autofarm.farmblooms or fieldPositionPolicy:SmileyOnly() then
		return nil
	end
	local bloom = bloomController:Select(opts)
	return bloom and bloom.v or nil
end

function gatheringPriorities:BloomFocus(opts, stem)
	local root = getRootPart().Position
	if self.petals and self.petals:Enabled(opts) then
		local petal = self.petals:Select(opts, root, stem.Position)
		if petal then
			self.last = "Petals"
			self.bloomFocused = true
			if self.currentLabel then self.currentLabel.Text = "Current target: Petals (Bloom)" end
			return "Petal", petal
		end
	end
	local focus = table.clone(opts)
	focus.origin = stem.Position
	focus.range = self.bloomRange
	local order
	if cfg.prioritization.enabled then
		self:Rebuild()
		order = cfg.prioritization.order
	else
		order = self.bloomFocusCategories
	end
	for _, category in ipairs(order) do
		if not self.bloomSkip[category] then
			local kind, object = self:Candidate(category, focus, root)
			if kind then
				self.last = category
				self.bloomFocused = true
				if self.currentLabel then self.currentLabel.Text = "Current target: " .. category .. " (Bloom)" end
				return kind, object
			end
		end
	end
	self.last = "Blooms"
	self.bloomFocused = true
	if self.currentLabel then self.currentLabel.Text = "Current target: Blooms" end
	return "Bloom", stem
end

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

function gatheringPriorities:Allowed(position, opts, rootPosition)
	if not fieldPositionPolicy:StrictAllowed(position) then return false end
	if comboController:IsRestrictedZone(position) or comboController:PathCrossesRestrictedZone(rootPosition, position) then return false end
	if opts.area and not fieldPositionPolicy:Allowed(position,opts) then return false end
	if opts.checkheight and math.abs(position.Y - rootPosition.Y) >= 6 then return false end
	if opts.range and opts.origin then
		local offset = position - opts.origin
		if offset:Dot(offset) >= opts.range * opts.range then return false end
	end
	local field = getFieldAt(position)
	if (not opts.ignorefield or field) and not (not opts.ignorefield and field == currentField) then return false end
	return not opts.avoid or not isPathClear(position, opts.avoid)
end

function gatheringPriorities:Enabled(category, opts)
	if fieldPositionPolicy:SmileyOnly() then return category=="Duped Smiley" end
	if opts.mondotokens and category ~= "Tokens" and category ~= "Priority Tokens" and category ~= "Token Links" and category ~= "Duped Tokens" and category ~= "Duped Smiley" and category ~= "Duped Bear" then return false end
	local farm = cfg.autofarm
	if category == "Blooms" then return not opts.loot and opts.blooms and farm.farmblooms end
	if category == "Petals" then return farm.farmblooms or farm.farmpetals or opts.petals end
	if category == "Precise Targets" then return farm.farmprecise or farm.farmprecisemark or cfg.convert.standInPrecise end
	if category == "Bubbles" then return not opts.loot and (farm.farmbubbles or (farm.autopopstar and (buffs["Pop Star Aura"] or buffs["Tidal Surge"]))) end
	if category == "Flames" then return not opts.loot and (farm.farmfires or (farm.autoscorchingstar and buffs["Scorching Star Aura"])) end
	if category == "Priority Tokens" then return not opts.ignoreprio end
	if category == "Token Links" then return not opts.combo end
	if category == "Tokens" then return true end
	if opts.loot then return false end
	if (category == "Showers" or category == "Coconuts") and opts.nowait then return false end
	if category == "Duped Bear" and not bearCombat:Ready() then return false end
	if category == "Puppy Ball" then
		local buff = buffs.ReindeerFetch
		if buff and buff.Text.Text == "x10" and buff.Percent.Size.Y.Scale >= 0.5 then return false end
	end
	if category == "Clouds" and buffs.Cloud and buffs.Cloud.Size.Y.Scale >= 0.25 then return false end
	if category == "Duped Tokens" or category == "Duped Smiley" or category == "Duped Bear" then
		return farm.farmdupedtokens or opts.dupedtokensquest
	end
	local flag = self.flags[category]
	return flag and farm[flag] == true
end

function gatheringPriorities:Candidate(category, opts, rootPosition)
	if not self:Enabled(category, opts) then return end
	if category == "Petals" then
		local petal = self.petals:Select(opts, rootPosition)
		if petal then return "Petal", petal end
		return
	end
	if category == "Blooms" then
		local bloom = bloomController:Select(opts)
		if bloom then return "Bloom", bloom.v end
		return
	end
	if category == "Showers" then return end
	if category == "Precise Targets" then return self:Precise(opts) end
	if category == "Triangulate" then
		for _ in pairs(tracked.triangulate) do return "Triangulate" end
		return
	end
	local descriptor = self.catalog[category]
	if not descriptor then return end
	local best, bestSquared = nil, math.huge
	for key, value in pairs(tracked[descriptor.key]) do
		local object = type(key) == "number" and value or key
		if category == "Flames" and type(value) ~= "number" then object = value end
		if type(object) ~= "table" and typeof(object) ~= "Instance" then continue end
		if (category == "Duped Tokens" or category == "Duped Smiley" or category == "Duped Bear") and not dupedTokenPolicy:Allowed(object) then continue end
		local virtual = type(object) == "table"
		if not virtual and not object.Parent then continue end
		if not bearCombat:IconEligible(bearCombat:Icon(object)) then continue end
		if touchedMarks[object] then continue end
		if descriptor.plane then object = object:FindFirstChild("Plane"); if not object then continue end end
		local position = object.Position
		if category == "Duped Smiley" or category == "Duped Bear" then position -= Vector3.new(0, 10, 0) end
		local dx, dz = position.X - rootPosition.X, position.Z - rootPosition.Z
		local squared = dx * dx + dz * dz
		if squared >= bestSquared or not self:Allowed(position, opts, rootPosition) then continue end
		if category == "Tokens" or category == "Priority Tokens" then
			if tracked.tokenlink[object] then continue end
			local decal = not virtual and object:FindFirstChild("FrontDecal")
			local icon = virtual and object.Icon or (decal and decal.Texture)
			if not icon then continue end
			local honey = icon == "rbxassetid://1472135114" or icon == "rbxassetid://2028574353"
			if honey and not opts.loot2 and (cfg.autofarm.ignorehoneytokens or opts.loot) then continue end
			local important = (virtual and object.Rainbow) or (not virtual and object:FindFirstChild("Spots"))
				or (opts.loot and tokenPriority.sprout[string.match(icon, "%d+")])
				or (not opts.loot and tokenPriority.autofarm[string.match(icon, "%d+")])
			if (category == "Priority Tokens") ~= not not important then continue end
			if category == "Tokens" and not opts.loot and not opts.skipoverlap and
				(cfg.autofarm.farmballoons2 or cfg.autofarm.farmmarks) and not questTasks:check(position) then continue end
		elseif category == "Showers" or category == "Coconuts" then
			local fast = category == "Showers" and cfg.detected.fastshowertween or category == "Coconuts" and cfg.detected.fastcoconuttween
			if not fast then
				local start = virtual and object.Start or value
				local lifetime = category == "Showers" and 1.9 or 2.4
				if type(start) ~= "number" or os.time() + math.sqrt(squared) / math.max(getHumanoid().WalkSpeed, 1) >= start + lifetime then continue end
			end
		elseif category == "Duped Smiley" then
			local start = virtual and object.Start or value
			if type(start) ~= "number" or os.clock() - start <= cfg.autofarm.smileytime then continue end
		elseif category == "Duped Tokens" then
			local start = virtual and object.Start or (type(value) == "table" and value.time)
			if type(start) ~= "number" or os.clock() - start <= 2 then continue end
		elseif category == "Duped Bear" then
			local start = virtual and object.Start or value
			if not bearCombat:Ready() then continue end
		elseif category == "Flames" then
			local emitter = not virtual and object:FindFirstChild("PF")
			local size = virtual and object.Size or (emitter and emitter.Size.Keypoints[1].Value or 0)
			if type(size) ~= "number" or size <= 1.4 then continue end
		end
		best, bestSquared = object, squared
	end
	if best then return descriptor.kind, best end
end

function gatheringPriorities:Pick(opts, stopBefore)
	if not cfg.prioritization.enabled then return end
	self:Rebuild()
	if not stopBefore then self.last = nil end
	local position = getRootPart().Position
	for _, category in ipairs(cfg.prioritization.order) do
		if category == stopBefore then return end
		local kind, object = self:Candidate(category, opts, position)
		if kind then
			if not stopBefore then
				self.last = category
				if self.currentLabel then self.currentLabel.Text = "Current target: " .. category end
			end
			return kind, object
		end
	end
end

function gatheringPriorities:ShouldPreempt()
	local active=self.activeOptions
	if active and active.rbc and not comboController.active then
		active.avoid=rbcSafety:Hazards(currentField)
		local point=fieldPositionPolicy:TargetPosition(self.activeWaypoint or self.activeTarget)
		if point and isPathClear(point,active.avoid,true,true) then return true end
	end
	local targetPoint=fieldPositionPolicy:TargetPosition(self.activeWaypoint or self.activeTarget)
	if targetPoint and comboController:BlocksMove(targetPoint) then return true end
	if fieldPositionPolicy:SmileyOnly() and self.activeCategory~="Duped Smiley" then return true end
	if showerController.active then return true end
	if self.precisionActive and active and active.rbc and self:PrecisionReady() and rbcSafety:BuffTarget(active) then return true end
	if self.precisionActive and cfg.autofarm.precisionupkeep~=false then return false end
	if self.upkeepToken and self.activeTarget == self.upkeepToken and cfg.autofarm.precisionupkeep~=false then
		return self:Precise(self:PrecisionOptions(self.activeOptions or {}), true) ~= nil
	end
	if not self.precisionActive and self.activeCategory~="Precise Targets" and self:PrecisionUpkeep(self.activeOptions or {}) then return true end
    if bearCombat.active then return false end
    local now = os.clock()
    if self.nextPreemptCheck and now < self.nextPreemptCheck then return false end
    self.nextPreemptCheck = now + 0.08
    if bearCombat:Pick(self.activeOptions or {}) then return true end
    if not self.bloomFocused and self.activeOptions and self:BloomTarget(self.activeOptions) then return true end
    if self.bloomFocused or not cfg.prioritization.enabled or not self.activeCategory then return false end
    return self:Pick(self.activeOptions or {}, self.activeCategory) ~= nil
end

function gatheringPriorities:HigherThanPetals(opts)
	if self:PrecisionUpkeep(opts) then return true end
	if bearCombat:Pick(opts) then return true end
	if not cfg.prioritization.enabled then return false end
	return self:Pick(opts, "Petals") ~= nil
end

function gatheringPriorities:Record(kind, object)
	self.precisionActive=kind and string.sub(kind,1,7)=="Precise" or false
	local category = cfg.prioritization.enabled and self.last or nil
	if not category then
		category = self.kindCategories[kind] or (kind and string.sub(kind, 1, 7) == "Precise" and "Precise Targets")
		if kind == "Token" and object and tracked.tokenlink[object] then category = "Token Links" end
	end
	self.activeCategory = cfg.prioritization.enabled and category or nil
	if self.currentLabel then self.currentLabel.Text = "Current target: " .. (category or "waiting") end
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
	self.precisionLabel = list.AddLabel("Precision: waiting")
	self.orderLabels = {}
	for index, category in ipairs(cfg.prioritization.order) do self.orderLabels[index] = list.AddLabel(tostring(index) .. ". " .. category) end
	list.AddLabel("Custom off = petals first, then script order")
	list.Toggle(true, true)
end

function gatheringPriorities:PrecisionReady()
	return self:PrecisionMode() == "mark"
end

function gatheringPriorities:IsCrosshairIgnoredOrDone(part)
	if not part or (typeof(part) == "Instance" and not part.Parent) then return true end
	local name = part.BrickColor and part.BrickColor.Name or ""
	if name == "Flint" then return true end
	if name == "Red flip/flop" or name == "Alder" then return false end
	if string.find(string.lower(name), "green", 1, true) or name == "Shamrock" or name == "Mint" or name == "Camo" then
		return true
	end
	local col = part.Color
	if col and type(col.G) == "number" and type(col.R) == "number" and col.G > col.R + 0.15 and col.G > 0.45 then
		return true
	end
	return false
end

function gatheringPriorities:HasActivePrecisionTargets()
	if not cfg or not cfg.autofarm or cfg.autofarm.precisionupkeep == false or not currentField then return false end
	local nowClock = os.clock()
	for id, entry in pairs(tracked.precise2) do
		if type(entry) ~= "table" or (type(entry.ExpiresAt) == "number" and nowClock > entry.ExpiresAt) then
			tracked.precise2[id] = nil
			tracked.precisegroup[id] = nil
		elseif not entry.Touched and not (touchedMarks and touchedMarks[entry]) and entry.Position then
			if (not getFieldAt or getFieldAt(entry.Position) == currentField)
				and not (comboController and comboController.BlocksMove and comboController:BlocksMove(entry.Position)) then
				return true
			end
		end
	end
	for k in pairs(tracked.precise) do
		if not self:IsCrosshairIgnoredOrDone(k) and not (touchedMarks and touchedMarks[k]) and k.Position then
			if (not getFieldAt or getFieldAt(k.Position) == currentField)
				and not (comboController and comboController.BlocksMove and comboController:BlocksMove(k.Position)) then
				return true
			end
		end
	end
	return false
end

function gatheringPriorities:PrecisionState()
	local precision = buffs.Precision
	if not precision then return 0, 0 end
	local stacks = tonumber(string.match(precision.Text.Text, "%d+")) or 0
	local bar = precision.Percent and precision.Percent.Size and precision.Percent.Size.Y and precision.Percent.Size.Y.Scale or 0
	return stacks, bar
end

function gatheringPriorities:PreciseMarkCount()
	if type(watchStations) == "function" and connections and connections.Get and not connections:Get("stations") then
		pcall(watchStations, true)
	end
	local count = 0
	for key in pairs(tracked.precisemark) do
		if typeof(key) == "Instance" then
			if not key.Parent then
				tracked.precisemark[key] = nil
			else
				local base = key:FindFirstChild("Base") or key:FindFirstChild("Plane")
				if base and (not currentField or not getFieldAt or getFieldAt(base.Position) == currentField) then
					count += 1
				end
			end
		else
			local mark = tracked.marks and tracked.marks[key]
			if type(mark) == "table" and typeof(mark.Position) == "Vector3" then
				if not currentField or not getFieldAt or getFieldAt(mark.Position) == currentField then
					count += 1
				end
			elseif not tracked.marks then
				count += 1
			end
		end
	end
	return count
end

function gatheringPriorities:PrecisionMode()
	local stacks, bar = self:PrecisionState()
	local marks = self:PreciseMarkCount()
	if stacks < 10 then
		self.precisionRefreshing = false
		return "build", marks, stacks, bar
	end
	local refreshAt = marks < 3 and 0.55 or 0.70
	if self.precisionRefreshing then
		if bar >= 0.90 then
			self.precisionRefreshing = false
		end
	elseif bar <= refreshAt then
		self.precisionRefreshing = true
	end
	return self.precisionRefreshing and "refresh" or "mark", marks, stacks, bar
end

function gatheringPriorities:FindTargetPracticeToken(opts)
	if not (tracked and tracked.tokens) then return nil end
	local rootPos = getRootPart().Position
	local best, bestSq = nil, math.huge
	for key, value in pairs(tracked.tokens) do
		local token = type(key) == "number" and value or key
		if type(token) ~= "table" and typeof(token) ~= "Instance" then continue end
		local virtual = type(token) == "table"
		if not virtual and not token.Parent then continue end
		if touchedMarks and touchedMarks[token] then continue end
		local icon = virtual and token.Icon or (token:FindFirstChild("FrontDecal") and token.FrontDecal.Texture)
		if not icon or not string.find(tostring(icon), "8173559749", 1, true) then continue end
		local pos = token.Position
		if not pos then continue end
		if opts.area and fieldPositionPolicy and fieldPositionPolicy.Allowed and not fieldPositionPolicy:Allowed(pos, opts) then continue end
		local field = getFieldAt and getFieldAt(pos)
		if not (opts.ignorefield and field or not opts.ignorefield and field == currentField) then continue end
		if opts.range and opts.origin then
			local off = pos - opts.origin
			if off.X * off.X + off.Z * off.Z >= opts.range * opts.range then continue end
		end
		if comboController and comboController.BlocksMove and comboController:BlocksMove(pos) then continue end
		if opts.avoid and isPathClear and isPathClear(pos, opts.avoid) then continue end
		local dx, dz = pos.X - rootPos.X, pos.Z - rootPos.Z
		local sq = dx * dx + dz * dz
		if sq < bestSq then
			best, bestSq = token, sq
		end
	end
	return best
end

function gatheringPriorities:PrecisionOptions(opts)
	local copy=table.clone(opts)
	copy.avoid=table.clone(opts.avoid or {})
	return copy
end

function gatheringPriorities:PrecisionUpkeep(opts)
	self.upkeepToken = nil
	local farm=cfg.autofarm
	local rbcUpkeep=opts.rbc and cfg.rbc.precise
	if (not rbcUpkeep and (farm.precisionupkeep==false or not farm.enabled or state.activityStatus~=1))
		or opts.loot or opts.mondotokens then return end
	if comboController.active or showerController.active or comboController:TravelBlocked() then return end
	local mode, marks, stacks, bar = self:PrecisionMode()
	local now = os.clock()
	if self.precisionLabel and (not self.nextPrecisionUi or now >= self.nextPrecisionUi) then
		self.nextPrecisionUi = now + 0.25
		self.precisionLabel.Text = string.format("Precision: %dx %d%% | Marks %d/3 | %s", stacks, math.floor(bar * 100 + 0.5), marks, mode)
	end
	local copy=self:PrecisionOptions(opts)
	if mode ~= "mark" then
		for target in pairs(tracked.precise)do copy.avoid[target]=nil end
		for _,target in pairs(tracked.precise2)do copy.avoid[target]=nil; copy.avoid[target.Position]=nil end
	elseif marks >= 3 and self.BloomTarget then
		local stem = self:BloomTarget(opts)
		if stem then
			copy.origin = stem.Position
			copy.range = self.bloomRange
		end
	end
	local kind, target = self:Precise(copy, true)
	if kind then return kind, target end
	if (mode ~= "mark" or marks < 3) and not opts.rbc then
		local tpToken = self:FindTargetPracticeToken(copy)
		if tpToken then
			self.upkeepToken = tpToken
			return "Token", tpToken
		end
	end
end

function gatheringPriorities:Precise(opts,upkeep)
	local autofarm = cfg.autofarm
	local preciseCount, bestPrecise = 0, nil
	local scorchingStarAura = not upkeep and autofarm.autoscorchingstar and buffs["Scorching Star Aura"]
	local standInPrecise = not upkeep and cfg.convert.standInPrecise and localPlayer.CoreStats.Pollen.Value / localPlayer.CoreStats.Capacity.Value * 100 >= cfg.convert.standInPreciseAt
	local precision, preciseMarkActive, preciseMarkCount, name, isPurpleMark, preciseKind, preciseDistance, precise2Kind, ownGroup, otherMark, sameGroupMark, precise2Distance
				if upkeep or not (not standInPrecise and not autofarm.farmprecise and not autofarm.farmprecisemark) then
					precision = buffs.Precision
					if upkeep then preciseMarkActive=self:PrecisionReady()
					else preciseMarkActive = autofarm.farmprecisemark and self:PrecisionReady() end
					preciseMarkCount = 0

					if scorchingStarAura then
						preciseMarkCount = self:PreciseMarkCount()

						if preciseMarkCount < 3 then
							scorchingStarAura = false
						end
					end

					local nowClock = os.clock()
					for id, entry in pairs(tracked.precise2) do
						if type(entry) ~= "table" or (type(entry.ExpiresAt) == "number" and nowClock > entry.ExpiresAt) then
							tracked.precise2[id] = nil
							tracked.precisegroup[id] = nil
						end
					end
					local useTracked = state.precise or next(tracked.precise2) ~= nil

					if not useTracked then
						for k in pairs(tracked.precise) do
							if opts.area and not fieldPositionPolicy:TrackedAllowed(k,nil,opts) then continue end
							if comboController and comboController.BlocksMove and comboController:BlocksMove(k.Position) then continue end
							preciseCount += 1
							if upkeep and opts.range and opts.origin and (opts.origin-k.Position).Magnitude>=opts.range then continue end
							name = k.BrickColor.Name

							if not (self:IsCrosshairIgnoredOrDone(k) or touchedMarks[k]) then
								isPurpleMark = name == "Alder"
								preciseKind = standInPrecise and "Precise Convert" or isPurpleMark and preciseMarkActive and not scorchingStarAura and "Precise Purple" or (not preciseMarkActive or scorchingStarAura) and "Precise"

								if (not preciseKind or preciseKind == "Precise") and not isPurpleMark and not (not preciseMarkActive or scorchingStarAura) then
									if not opts.avoid then
										opts.avoid = {}
									end

									opts.avoid[k] = 7
								end

								if preciseKind then
									if not ((not opts.ignorefield or getFieldAt(k.Position)) and not (not opts.ignorefield and getFieldAt(k.Position) == currentField) or (not (upkeep and not opts.rbc and preciseKind=="Precise Purple") and not (not opts.avoid or not isPathClear(k.Position, opts.avoid)))) then
										preciseDistance = distanceTo(k.Position, true)

										local rank=upkeep and not preciseMarkActive and isPurpleMark and 1 or 0
										if not bestPrecise or rank<(bestPrecise.rank or 0) or (rank==(bestPrecise.rank or 0) and preciseDistance < bestPrecise.d) then
											bestPrecise = { name = preciseKind, d = preciseDistance, v = k,rank=rank }
										end
									end
								end
							end
						end
					else
						local groupTouched = {}
						for k, pm in pairs(tracked.precise2) do
							local gid = pm.Group or tracked.precisegroup[k]
							if gid ~= nil and pm.Touched then
								groupTouched[gid] = (groupTouched[gid] or 0) + 1
							end
						end
						for k, preciseMark in pairs(tracked.precise2) do
							if opts.area and not fieldPositionPolicy:TrackedAllowed(k,preciseMark,opts) then continue end
							if comboController and comboController.BlocksMove and comboController:BlocksMove(preciseMark.Position) then continue end
							preciseCount += 1
							if upkeep and opts.range and opts.origin and (opts.origin-preciseMark.Position).Magnitude>=opts.range then continue end

							if not preciseMark.Touched and not touchedMarks[preciseMark] then
								precise2Kind = standInPrecise and "Precise2Convert" or preciseMark.Mark and preciseMarkActive and not scorchingStarAura and "Precise2Purple" or (not preciseMarkActive or scorchingStarAura) and "Precise2"

								if precise2Kind ~= "Precise2Convert" then
									ownGroup = preciseMark.Group or tracked.precisegroup[k]

									for k2, groupValue in pairs(tracked.precisegroup) do
										if ownGroup ~= groupValue then
											if not (not preciseMarkActive or scorchingStarAura) then
												otherMark = tracked.precise2[k2]

												if not (not otherMark or not (not otherMark.Mark and not otherMark.Touched and not touchedMarks[otherMark])) then
													if not opts.avoid then
														opts.avoid = {}
													end

													opts.avoid[otherMark] = 7
												end
											end
										else
											sameGroupMark = tracked.precise2[k2]

											if not (not sameGroupMark or not (not sameGroupMark.Mark and sameGroupMark.Touched)) then
												precise2Kind = "Precise2All"
											end
										end
									end
								end

								if (not precise2Kind or precise2Kind == "Precise2") and not preciseMark.Mark and not (not preciseMarkActive or scorchingStarAura) then
									if not opts.avoid then
										opts.avoid = {}
									end

									opts.avoid[preciseMark] = 7
								end

								if precise2Kind then
									if not ((not opts.ignorefield or getFieldAt(preciseMark.Position)) and not (not opts.ignorefield and getFieldAt(preciseMark.Position) == currentField) or (not (upkeep and not opts.rbc and precise2Kind=="Precise2Purple") and not (not opts.avoid or not isPathClear(preciseMark.Position, opts.avoid)))) then
										precise2Distance = distanceTo(preciseMark.Position, true)

										local gid = preciseMark.Group or tracked.precisegroup[k]
										local inProgress = gid ~= nil and (groupTouched[gid] or 0) > 0
										local rank = 0
										if upkeep and not preciseMarkActive then
											rank = inProgress and -1 or (preciseMark.Mark and 1 or 0)
										end
										if not bestPrecise or rank<(bestPrecise.rank or 0) or (rank==(bestPrecise.rank or 0) and precise2Distance < bestPrecise.d) then
											bestPrecise = { name = precise2Kind, d = precise2Distance, v = preciseMark,rank=rank }
										end
									end
								end
							end
						end
					end
				end

	if bestPrecise then return bestPrecise.name, bestPrecise.v end
end
		

-- 1. Check Blooms priority & BloomFocus scoping
assert(gatheringPriorities.defaults[1]=="Petals" and gatheringPriorities.defaults[2]=="Blooms","Blooms not #2 after Petals")
assert(gatheringPriorities.kindCategories.Bloom=="Blooms","kindCategories.Bloom missing")

local farToken={Name=true,Position=vector(-45,3,0),Icon="rbxassetid://65867881"}
local nearToken={Name=true,Position=vector(35,3,0),Icon="rbxassetid://65867881"}
tracked.tokens[farToken]=true; tracked.tokens[nearToken]=true
local stem={Position=vector(30,3,0)}
selectedBloom={v=stem,d=30}
local opts={blooms=true}
assert(gatheringPriorities:BloomTarget(opts)==stem,"BloomTarget failed")
local fk,fo=gatheringPriorities:BloomFocus(opts,stem)
assert(fk=="Token" and fo==nearToken and gatheringPriorities.bloomFocused,"BloomFocus did not prioritize near-bloom token over far token")
tracked.tokens[nearToken]=nil
fk,fo=gatheringPriorities:BloomFocus(opts,stem)
assert(fk=="Bloom" and fo==stem,"BloomFocus did not fall back to Bloom stem")
selectedPetal={Name=true,Position=vector(28,3,0)}
fk,fo=gatheringPriorities:BloomFocus(opts,stem)
assert(fk=="Petal" and fo==selectedPetal,"BloomFocus did not prefer petal first")
selectedPetal=nil
gatheringPriorities.bloomFocused=false
gatheringPriorities.activeOptions=opts
gatheringPriorities.activeCategory="Tokens"
gatheringPriorities.activeTarget=farToken
assert(gatheringPriorities:ShouldPreempt(),"ShouldPreempt did not preempt distant token for Bloom")

-- 2. Check 3-Mark Precision + Bloom scoping cooperation
buffs.Precision={Text={Text="x10"},Percent={Size={Y={Scale=0.9}}}}
local nearPurple={Position=vector(35,3,0),BrickColor={Name="Alder"}}
local farPurple={Position=vector(-45,3,0),BrickColor={Name="Alder"}}
tracked.precise[farPurple]=true
tracked.precisemark={{},{},{}}
assert(not gatheringPriorities:PrecisionUpkeep(opts),"PrecisionUpkeep left bloom for distant purple when 3 marks already up")
tracked.precisemark={{}}
local pk,pt=gatheringPriorities:PrecisionUpkeep(opts)
assert(pk=="Precise Purple" and pt==farPurple,"PrecisionUpkeep did not pursue distant purple when marks < 3")
tracked.precisemark={{},{},{}}
tracked.precise[nearPurple]=true
pk,pt=gatheringPriorities:PrecisionUpkeep(opts)
assert(pk=="Precise Purple" and pt==nearPurple,"PrecisionUpkeep missed purple near bloom when marks >= 3")

-- 3. Check Smooth Dice booster + Field Dice overwrite guard
local boostCalls={}
local cache={Materials={}}
local inventory={
 has={["Smooth Dice"]=true,["Field Dice"]=true},
 Has=function(self,req)for k in pairs(req) do if not self.has[k] then return false end end; return true end,
 Use=function(self,name)boostCalls[#boostCalls+1]=name;return true end,
}
local nowTime=10000
local os={time=function()return nowTime end,clock=os.clock}
local logger={log=function()end}
local task={wait=function()end}
local topBoostField, remainingBoost = {field="Pepper Patch",percent=0.5,amount=1}, 1
local function getBoostedFields()return topBoostField, 0 end
cfg.boosters={allowed={["Smooth Dice"]=true,["Field Dice"]=true},wanted=2,required=false}
local loadedDice=false

do
				if type(cfg.boosters.allowed) == "table" and cfg.boosters.allowed["Smooth Dice"] and remainingBoost > 0
					and (not cfg.boosters.required or remainingBoost < cfg.boosters.wanted) then
					local hasStrongerLoaded = loadedDice and inventory:Has({ ["Loaded Dice"] = 1 }, true, true)
					local lastDiceUse = math.max(cache.Materials.smoothdice or 0, cache.Materials.usedice or 0, cache.Materials.loaded or 0)
					local smoothActive = cache.Materials.smoothdice and os.time() - cache.Materials.smoothdice < 900
					local fieldDiceActive = cache.Materials.dice1field and os.time() - cache.Materials.dice1field.time < 720
					if not hasStrongerLoaded and os.time() - lastDiceUse > 2 and not smoothActive and not fieldDiceActive then
						if inventory:Has({ ["Smooth Dice"] = 1 }, true, true) then
							logger.log("Using item:", "Smooth Dice")
							if inventory:Use("Smooth Dice") then
								local now = os.time()
								cache.Materials.usedice = now
								cache.Materials.smoothdice = now
								saveConfig(true)
								task.wait(1)
								topBoostField, remainingBoost = getBoostedFields()
							end
						end
					end
				end


end
assert(#boostCalls==1 and boostCalls[1]=="Smooth Dice" and cache.Materials.smoothdice==nowTime,"Smooth Dice was not used")
do
 local chosenBooster="Field Dice"
					if chosenBooster == "Field Dice" and cache.Materials.smoothdice and os.time() - cache.Materials.smoothdice < 720 then
						chosenBooster = nil
					end


 assert(chosenBooster==nil,"Field Dice overwrote active Smooth Dice")
end
boostCalls={};cache.Materials={};remainingBoost=1;loadedDice=true;inventory.has["Loaded Dice"]=true
do
				if type(cfg.boosters.allowed) == "table" and cfg.boosters.allowed["Smooth Dice"] and remainingBoost > 0
					and (not cfg.boosters.required or remainingBoost < cfg.boosters.wanted) then
					local hasStrongerLoaded = loadedDice and inventory:Has({ ["Loaded Dice"] = 1 }, true, true)
					local lastDiceUse = math.max(cache.Materials.smoothdice or 0, cache.Materials.usedice or 0, cache.Materials.loaded or 0)
					local smoothActive = cache.Materials.smoothdice and os.time() - cache.Materials.smoothdice < 900
					local fieldDiceActive = cache.Materials.dice1field and os.time() - cache.Materials.dice1field.time < 720
					if not hasStrongerLoaded and os.time() - lastDiceUse > 2 and not smoothActive and not fieldDiceActive then
						if inventory:Has({ ["Smooth Dice"] = 1 }, true, true) then
							logger.log("Using item:", "Smooth Dice")
							if inventory:Use("Smooth Dice") then
								local now = os.time()
								cache.Materials.usedice = now
								cache.Materials.smoothdice = now
								saveConfig(true)
								task.wait(1)
								topBoostField, remainingBoost = getBoostedFields()
							end
						end
					end
				end


end
assert(#boostCalls==0,"Smooth Dice ran despite Loaded Dice available")

-- 4. Check Ultra Anti-Lag config migration & UI
cfg.antilag={ultra=false,migrated=false,main=true,tokens=true,particles=true,bees=true,norender=false}
local uiSwitches, uiLabels = {}, {}
local antiLagFolder={
 AddSwitch=function(title,cb,t,k)uiSwitches[title]={cb=cb,t=t,k=k}end,
 AddLabel=function(txt)uiLabels[#uiLabels+1]=txt end,
}
local ultraCalls={}
local ultraAntiLag={Set=function(_,v)ultraCalls[#ultraCalls+1]=v end}
local RunService={Set3dRenderingEnabled=function()end}
local ScreenGui={FindFirstChild=function()return nil end}
local Instance={new=function()return {}end}
local UDim2={new=function()return {}end}
local Color3={new=function()return {}end}
local Debug={Toggle=function()end}
do
				if not cfg.antilag.migrated then
					local legacyVisual = cfg.antilag.main or cfg.antilag.aggressivevisuals or cfg.antilag.visualeffects
						or cfg.antilag.textures or cfg.antilag.decorations or cfg.antilag.bees or cfg.antilag.frogs
						or cfg.antilag.flowers or cfg.antilag.balloons or cfg.antilag.players
					if legacyVisual then cfg.antilag.ultra = true end
					for _, k in ipairs({
						"tokens", "particles", "precise", "dupedtokens", "stations", "bssui", "main",
						"aggressivevisuals", "visualeffects", "textures", "decorations", "bees", "frogs",
						"flowers", "balloons", "players",
					}) do
						cfg.antilag[k] = false
					end
					cfg.antilag.migrated = true
					saveConfig()
				end

				antiLagFolder.AddSwitch("Ultra Anti-Lag", function(enabled)
					ultraAntiLag:Set(enabled)
				end, "antilag", "ultra", { Tooltip = "One-click maximum visual anti-lag. Never hides or hooks tokens, marks, crosshairs, combos, blooms, petals, or player positions." })

				antiLagFolder.AddSwitch("Disable 3D Rendering (AFK black screen)", function(n)
					RunService:Set3dRenderingEnabled(not n)

					if n then
						local n = Instance.new("Frame")
						n.Size = UDim2.new(1, 0, 1, 0)
						n.BackgroundColor3 = Color3.new(0, 0, 0)
						n.BorderSizePixel = 0
						n.ZIndex = 0
						n.Parent = ScreenGui
					else
						local n = ScreenGui:FindFirstChild("Frame")

						if n then
							n:Destroy()
						end
					end
				end, "antilag", "norender")

				antiLagFolder.AddLabel("Visual-only: never hides/hooks tokens, marks, crosshairs, combos, blooms, petals or players' positions")


end
assert(cfg.antilag.migrated and cfg.antilag.ultra==true,"migration did not enable ultra from legacy main/bees")
assert(not cfg.antilag.tokens and not cfg.antilag.particles and not cfg.antilag.bees,"migration did not clear legacy switches")
assert(uiSwitches["Ultra Anti-Lag"] and uiSwitches["Disable 3D Rendering (AFK black screen)"] and not uiSwitches["Hide Tokens"],"UI switches mismatch")

-- 5. Check passive watchPreciseFX + atomic 3-target collectPreciseSet sweep
do
 local listeners={}
 local fxSignal={
  Connect=function(_,fn)local c={Connected=true,fn=fn,Disconnect=function(s)s.Connected=false end};listeners[#listeners+1]=c;return c end,
  Fire=function(_,...)for _,c in ipairs(listeners)do if c.Connected then c.fn(...) end end end,
 }
 local fxObj={ClassName="RemoteEvent",Name="LocalFX",IsA=function(_,c)return c=="RemoteEvent"end,OnClientEvent=fxSignal}
 local gameApi={Events={FindFirstChild=function(_,n)return n=="LocalFX" and fxObj or nil end}}
 local connections={
  list={},
  Get=function(s,k)return s.list[k] end,
  Add=function(s,k,c)s.list[k]=c end,
  Cancel=function(s,k)if s.list[k] then s.list[k]:Disconnect();s.list[k]=nil end end,
 }
 local watchPreciseFX
 local pChar={}
 local localPlayer={Name="Me"}
 tracked.precise2={}; tracked.precisegroup={}; touchedMarks={}
 cfg.autofarm.precisionupkeep=true
 cfg.convert.standInPrecise=false
 cfg.rbc={precise=false}
 do
  	watchPreciseFX = function(enable)
		if not enable then
			if cfg.autofarm.precisionupkeep ~= false or cfg.convert.standInPrecise or cfg.rbc.precise then return end
			connections:Cancel("preciseFX")
			return
		end
		if connections:Get("preciseFX") then return end
		local fx = gameApi.Events and gameApi.Events:FindFirstChild("LocalFX")
		if not (fx and fx:IsA("RemoteEvent")) then return end
		connections:Add("preciseFX", fx.OnClientEvent:Connect(function(effectName, effectData)
			if effectName ~= "LocalTargetPracticeBeam" or type(effectData) ~= "table" then return end
			local action = effectData.Action
			local id = effectData.ID
			if action == "Make" and effectData.Player == localPlayer and id ~= nil and typeof(effectData.Pos) == "Vector3" then
				tracked.precise2[id] = {
					Name = true,
					ID = id,
					Position = effectData.Pos,
					Mark = effectData.Mark == true,
					Group = effectData.FEID,
					Touched = false,
					ExpiresAt = os.clock() + 5.0,
				}
				tracked.precisegroup[id] = effectData.FEID
			elseif action == "Touch" and id ~= nil then
				local entry = tracked.precise2[id]
				if entry then entry.Touched = true end
			elseif action == "TurnPurple" and id ~= nil then
				local entry = tracked.precise2[id]
				if entry then entry.Mark = true end
			elseif (action == "Destroy" or action == "Remove" or action == "Shoot") and id ~= nil then
				tracked.precise2[id] = nil
				tracked.precisegroup[id] = nil
			end
		end))
	end


 end
 watchPreciseFX(true)
 assert(connections:Get("preciseFX")~=nil,"watchPreciseFX did not connect")
 fxSignal:Fire("LocalTargetPracticeBeam",{Action="Make",Player=localPlayer,ID=101,Pos=vector(10,3,0),Mark=false,FEID="setA"})
 fxSignal:Fire("LocalTargetPracticeBeam",{Action="Make",Player=localPlayer,ID=102,Pos=vector(20,3,0),Mark=false,FEID="setA"})
 fxSignal:Fire("LocalTargetPracticeBeam",{Action="Make",Player=localPlayer,ID=103,Pos=vector(30,3,0),Mark=false,FEID="setA"})
 -- Another group setB slightly closer than 103 should NOT steal before setA finishes:
 fxSignal:Fire("LocalTargetPracticeBeam",{Action="Make",Player=localPlayer,ID=201,Pos=vector(22,3,0),Mark=false,FEID="setB"})
 fxSignal:Fire("LocalTargetPracticeBeam",{Action="TurnPurple",ID=103})
 assert(tracked.precise2[101] and tracked.precise2[103].Mark==true and tracked.precisegroup[101]=="setA","watchPreciseFX did not record FEID & TurnPurple")

 -- Now test collectPreciseSet sweeps all 3 targets of setA completely (requires reaching <= 2.5 studs, NOT 6 studs!)
 local stepPos=vector(0,3,0)
 rootPos=stepPos
 local smoothMovement={}
 local currentGoal
 local moveCmds=0
 local humanoid={
  Health=100, WalkSpeed=80,
  MoveTo=function(_,g)
   moveCmds+=1
   currentGoal=g
  end,
 }
 getRootPart=function()return {Position=rootPos}end
 getHumanoid=function()return humanoid end
 local RunService={Heartbeat={
  Wait=function()
   if currentGoal then
    local d=vector(currentGoal.X-rootPos.X,0,currentGoal.Z-rootPos.Z)
    if d.Magnitude>1.5 then
     rootPos=rootPos+d.Unit*1.5
    else
     rootPos=vector(currentGoal.X,3,currentGoal.Z)
    end
    for _,id in ipairs({101,102,103,201}) do
     local e=tracked.precise2[id]
     if e and not e.Touched then
      local ed=vector(e.Position.X-rootPos.X,0,e.Position.Z-rootPos.Z).Magnitude
      -- Trigger ONLY inside 2.5 studs (simulates actual small crosshair hitbox, fails if bot stops at 6 studs!)
      if ed<=2.5 then fxSignal:Fire("LocalTargetPracticeBeam",{Action="Touch",ID=id}) end
     end
    end
   end
   return true
  end,
 }}
 buff=nil
 buffs.Precision={Text={Text="x9"},Percent={Size={Y={Scale=0.8}}}}
 		local function collectPreciseSet(firstTarget, options, isTracked)
			options = options or {}
			if fieldPositionPolicy and fieldPositionPolicy.ReleaseIdle then fieldPositionPolicy:ReleaseIdle() end
			if smoothMovement then smoothMovement.roam = nil end
			local sweepDeadline = os.clock() + 6.0
			local activeGroup = isTracked and (firstTarget.Group or tracked.precisegroup[firstTarget.ID]) or nil
			local sweepAvoid = nil
			if options.avoid then
				sweepAvoid = table.clone(options.avoid)
				for t in pairs(tracked.precise) do sweepAvoid[t] = nil end
				for _, t in pairs(tracked.precise2) do
					sweepAvoid[t] = nil
					if t.Position then sweepAvoid[t.Position] = nil end
				end
				if next(sweepAvoid) == nil then sweepAvoid = nil end
			end
			local function physicalCrosshairDoneAt(pos)
				if not pos or not tracked.precise then return false end
				for part in pairs(tracked.precise) do
					if part and part.Parent and part.Position then
						local dx, dz = part.Position.X - pos.X, part.Position.Z - pos.Z
						if dx * dx + dz * dz <= 12.25 then
							local bc = part.BrickColor and part.BrickColor.Name or ""
							if bc ~= "Flint" and gatheringPriorities:IsCrosshairIgnoredOrDone(part) then
								return true
							end
						end
					end
				end
				return false
			end
			local function isDone(target, startColor)
				if isTracked then
					return tracked.precise2[target.ID] ~= target or target.Touched == true
						or (type(target.ExpiresAt) == "number" and os.clock() > target.ExpiresAt)
						or physicalCrosshairDoneAt(target.Position)
				end
				if gatheringPriorities:IsCrosshairIgnoredOrDone(target) then return true end
				local name = target.BrickColor and target.BrickColor.Name or ""
				if startColor == "Red flip/flop" and name ~= "Red flip/flop" and name ~= "Alder" then return true end
				if startColor == "Alder" and name ~= "Alder" then return true end
				return false
			end
			local function pickNext(groupId, completedCount)
				local mode = gatheringPriorities:PrecisionMode()
				local best, bestRank, bestDist = nil, math.huge, math.huge
				if isTracked then
					local hasSameGroup = false
					if groupId ~= nil then
						for id, entry in pairs(tracked.precise2) do
							local gid = entry.Group or tracked.precisegroup[id]
							if gid == groupId and not isDone(entry) and not touchedMarks[entry] then
								hasSameGroup = true
								break
							end
						end
					end
					if not hasSameGroup and not options.rbc and mode == "mark" then
						return nil
					end
					for id, entry in pairs(tracked.precise2) do
						if not isDone(entry) and not touchedMarks[entry] then
							if fieldPositionPolicy and fieldPositionPolicy.StrictAllowed and not fieldPositionPolicy:StrictAllowed(entry.Position) then continue end
							if options.area and not fieldPositionPolicy:TrackedAllowed(id, entry, options) then continue end
							local pos = entry.Position
							if not pos then continue end
							if not (options.ignorefield and getFieldAt(pos) or not options.ignorefield and getFieldAt(pos) == currentField) then continue end
							if comboController and comboController.BlocksMove and comboController:BlocksMove(pos) then continue end
							if sweepAvoid and isPathClear(pos, sweepAvoid) then continue end
							local gid = entry.Group or tracked.precisegroup[id]
							local rank = (groupId ~= nil and gid == groupId) and 0 or (entry.Mark and 2 or 1)
							local dist = distanceTo(pos, true)
							if rank < bestRank or (rank == bestRank and dist < bestDist) then
								best, bestRank, bestDist = entry, rank, dist
							end
						end
					end
				else
					if completedCount >= 3 and not options.rbc and mode == "mark" then
						return nil
					end
					for entry in pairs(tracked.precise) do
						if not isDone(entry) and not touchedMarks[entry] then
							if fieldPositionPolicy and fieldPositionPolicy.StrictAllowed and not fieldPositionPolicy:StrictAllowed(entry.Position) then continue end
							if options.area and not fieldPositionPolicy:TrackedAllowed(entry, nil, options) then continue end
							local pos = entry.Position
							if not pos then continue end
							if not (options.ignorefield and getFieldAt(pos) or not options.ignorefield and getFieldAt(pos) == currentField) then continue end
							if comboController and comboController.BlocksMove and comboController:BlocksMove(pos) then continue end
							if sweepAvoid and isPathClear(pos, sweepAvoid) then continue end
							local rank = (entry.BrickColor and entry.BrickColor.Name == "Alder") and 1 or 0
							local dist = distanceTo(pos, true)
							if rank < bestRank or (rank == bestRank and dist < bestDist) then
								best, bestRank, bestDist = entry, rank, dist
							end
						end
					end
				end
				return best
			end

			local current = firstTarget
			local steps, completedCount = 0, 0
			while current and steps < 6 and os.clock() < sweepDeadline do
				steps += 1
				gatheringPriorities.activeTarget = current
				local currentGroup = isTracked and (current.Group or tracked.precisegroup[current.ID]) or nil
				if currentGroup ~= nil then activeGroup = currentGroup end
				local startColor = (not isTracked and current.BrickColor and current.BrickColor.Name) or nil
				local targetDeadline = os.clock() + 2.2
				local nextMove = 0
				local arrivedAt = nil
				local aborted = false
				while os.clock() < targetDeadline and os.clock() < sweepDeadline do
					if state.stop or comboController.active or showerController.active or getHumanoid().Health <= 0 then
						smoothMovement.goal = nil
						return true
					end
					if isDone(current, startColor) then break end
					local root = getRootPart().Position
					local point = Vector3.new(current.Position.X, root.Y, current.Position.Z)
					if comboController:BlocksMove(point) or (options.rbc and isPathClear(point, rbcSafety:Hazards(currentField), true, true)) then
						aborted = true
						break
					end
					local d = distanceTo(point, true)
					if d <= 3.0 then
						if not arrivedAt then arrivedAt = os.clock() end
						if os.clock() - arrivedAt >= 0.30 then
							if isTracked then current.Touched = true end
							break
						end
					else
						arrivedAt = nil
					end
					if os.clock() >= nextMove then
						getHumanoid():MoveTo(point)
						nextMove = os.clock() + 0.08
					end
					if not RunService.Heartbeat:Wait() then break end
				end
				local doneNow = (not aborted) and (isDone(current, startColor) or arrivedAt ~= nil)
				if doneNow then
					completedCount += 1
					touchedMarks[current] = os.clock() + 5.5
				else
					touchedMarks[current] = os.clock() + 0.5
				end
				current = pickNext(activeGroup, completedCount)
				if not current and completedCount < 3 and os.clock() < sweepDeadline then
					local staggerDeadline = math.min(sweepDeadline, os.clock() + 0.55)
					while not current and os.clock() < staggerDeadline do
						if state.stop or comboController.active or showerController.active or getHumanoid().Health <= 0 then
							smoothMovement.goal = nil
							return true
						end
						if not RunService.Heartbeat:Wait() then break end
						current = pickNext(activeGroup, completedCount)
					end
				end
			end
			smoothMovement.goal = nil
			return true
		end


 collectPreciseSet(tracked.precise2[101],{},true)
 assert(tracked.precise2[101].Touched and tracked.precise2[102].Touched and tracked.precise2[103].Touched,"collectPreciseSet abandoned part of the 3-target FEID group")

 -- 5b. Physical collectPreciseSet turns "Lime green" on touch, ignores stale crosshair avoid & opts.range=40, and waits through spawn stagger!
 state.precise=false
 tracked.precise2={}; tracked.precisegroup={}; touchedMarks={}
 local phys1={ClassName="Part",Parent={},Position=vector(10,3,0),BrickColor={Name="Red flip/flop"}}
 local phys2={ClassName="Part",Parent={},Position=vector(22,3,0),BrickColor={Name="Red flip/flop"}}
 local phys3={ClassName="Part",Parent={},Position=vector(60,3,0),BrickColor={Name="Red flip/flop"}} -- outside range=40!
 tracked.precise={[phys1]=true,[phys2]=true}
 rootPos=vector(0,3,0); stepPos=rootPos; currentGoal=nil
 local spawned3=false
 local stepCount=0
 local clockVal=100
 local origClock=os.clock
 os.clock=function()return clockVal end
 RunService.Heartbeat.Wait=function()
  stepCount+=1
  clockVal+=0.03
  if currentGoal then
   local d=vector(currentGoal.X-rootPos.X,0,currentGoal.Z-rootPos.Z)
   if d.Magnitude>1.5 then rootPos=rootPos+d.Unit*1.5 else rootPos=vector(currentGoal.X,3,currentGoal.Z) end
  end
  -- Stagger phys3 spawn 3 ticks (~0.09s) after phys2 gets activated:
  if phys2.BrickColor.Name=="Lime green" and not spawned3 then
   if not phys2.delayTicks then phys2.delayTicks=0 end
   phys2.delayTicks+=1
   if phys2.delayTicks>=3 then
    tracked.precise[phys3]=true
    spawned3=true
   end
  end
  for p in pairs(tracked.precise) do
   if p.BrickColor.Name=="Red flip/flop" then
    local ed=vector(p.Position.X-rootPos.X,0,p.Position.Z-rootPos.Z).Magnitude
    if ed<=2.5 then p.BrickColor={Name="Lime green"} end
   end
  end
  return true
 end
 collectPreciseSet(phys1,{range=40,origin=vector(0,3,0),avoid={[phys2]=7,[phys3]=7}},false)
 assert(phys1.BrickColor.Name=="Lime green" and phys2.BrickColor.Name=="Lime green" and phys3.BrickColor.Name=="Lime green","physical collectPreciseSet failed on green transition / range=40 / avoid / spawn stagger")

 -- 5c. Tracked collectPreciseSet where Touch NEVER fires completes all 3 via center-dwell fallback!
 tracked.precise={}; touchedMarks={}
 local noTouch1={ID=301,Position=vector(8,3,0),Mark=false,Group="dwellSet",Touched=false}
 local noTouch2={ID=302,Position=vector(16,3,0),Mark=false,Group="dwellSet",Touched=false}
 local noTouch3={ID=303,Position=vector(24,3,0),Mark=false,Group="dwellSet",Touched=false}
 tracked.precise2={[301]=noTouch1,[302]=noTouch2,[303]=noTouch3}
 tracked.precisegroup={[301]="dwellSet",[302]="dwellSet",[303]="dwellSet"}
 rootPos=vector(0,3,0); currentGoal=nil
 RunService.Heartbeat.Wait=function()
  clockVal+=0.05
  if currentGoal then
   local d=vector(currentGoal.X-rootPos.X,0,currentGoal.Z-rootPos.Z)
   if d.Magnitude>2.0 then rootPos=rootPos+d.Unit*2.0 else rootPos=vector(currentGoal.X,3,currentGoal.Z) end
  end
  return true
 end
 collectPreciseSet(noTouch1,{},true)
 os.clock=origClock
 assert(noTouch1.Touched and noTouch2.Touched and noTouch3.Touched,"center-dwell fallback did not complete all 3 targets")
end

print("PASS: ultra bloom focus, 3-mark precision cooperation, Smooth Dice booster, and Ultra Anti-Lag migration")
