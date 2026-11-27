-- Real-code regression test suite for:
-- A. Ultra Anti-Lag & visualOptimizer leak/perf fixes
-- B. Digital Bee Duped Smiley Collection & ShouldPreempt throttle
-- C. Optimal Flame Refreshing (flameController + migration UI)
-- D. Source-level FPS / UI invariants

local now = 100
local os = {
	clock = function() return now end,
	time = function() return math.floor(1700000000 + now) end,
}
local warns = {}
local function warn(v) warns[#warns + 1] = v end

local function vector(x, y, z)
	local mt = {}
	mt.__add = function(a, b) return vector(a.X + b.X, a.Y + b.Y, (a.Z and b.Z) and (a.Z + b.Z) or nil) end
	mt.__sub = function(a, b) return vector(a.X - b.X, a.Y - b.Y, (a.Z and b.Z) and (a.Z - b.Z) or nil) end
	mt.__mul = function(a, b) if type(a) == "number" then a, b = b, a end; return vector(a.X * b, a.Y * b, a.Z and (a.Z * b) or nil) end
	mt.__div = function(a, b) return vector(a.X / b, a.Y / b, a.Z and (a.Z / b) or nil) end
	mt.__eq = function(a, b) return type(a) == "table" and type(b) == "table" and a.X == b.X and a.Y == b.Y and a.Z == b.Z end
	mt.__index = function(a, k)
		local z = rawget(a, "Z")
		local mag = math.sqrt(a.X * a.X + a.Y * a.Y + (z or 0) ^ 2)
		if k == "Magnitude" then return mag end
		if k == "Unit" then return mag > 0 and (a / mag) or vector(0, 0, z and 0 or nil) end
	end
	return setmetatable({ X = x, Y = y, Z = z }, mt)
end
local Vector3 = { new = vector, zero = vector(0, 0, 0) }
local Color3 = {
	new = function(r, g, b) return { R = r, G = g, B = b } end,
	fromRGB = function(r, g, b) return { R = r / 255, G = g / 255, B = b / 255 } end,
}
local CFrame = {
	new = function(pos, lookAt)
		if type(pos) == "number" then
			pos = vector(pos, lookAt or 0, 0)
			lookAt = nil
		end
		local dir = lookAt and (lookAt - pos) or vector(0, 0, -1)
		local lv = dir.Magnitude > 0 and dir.Unit or vector(0, 0, -1)
		return { Position = pos, LookTo = lookAt, LookVector = lv }
	end,
}
local NumberRange = { new = function(mn, mx) return { Min = mn, Max = mx or mn } end }
local NumberSequenceKeypoint = { new = function(t, v) return { Time = t, Value = v } end }
local NumberSequence = {
	new = function(v)
		if type(v) == "table" and v[1] then return { Keypoints = v } end
		return { Keypoints = { { Time = 0, Value = v }, { Time = 1, Value = v } } }
	end,
}
local ColorSequenceKeypoint = { new = function(t, v) return { Time = t, Value = v } end }
local ColorSequence = {
	new = function(v)
		if type(v) == "table" and v[1] then return { Keypoints = v } end
		return { Keypoints = { { Time = 0, Value = v }, { Time = 1, Value = v } } }
	end,
}

local Enum = setmetatable({
	QualityLevel = { Automatic = "Automatic", Level01 = "Level01" },
	SavedQualitySetting = { Automatic = "Automatic", QualityLevel1 = "QualityLevel1" },
	RenderPriority = { Camera = { Value = 200 }, Character = { Value = 100 } },
	HumanoidStateType = { Climbing = "Climbing", Running = "Running" },
	MouseBehavior = { Default = "Default", LockCenter = "LockCenter" },
	Material = { SmoothPlastic = "SmoothPlastic", Plastic = "Plastic", Neon = "Neon" },
}, {
	__index = function(t, k)
		local e = setmetatable({}, { __index = function(tbl, n) rawset(tbl, n, n); return n end })
		rawset(t, k, e)
		return e
	end,
})

local liveConnections = 0
local function signal()
	local listeners = {}
	local s = {}
	function s:Connect(fn)
		local c = { Connected = true, fn = fn }
		listeners[c] = true
		liveConnections += 1
		function c:Disconnect()
			if self.Connected then
				self.Connected = false
				listeners[self] = nil
				liveConnections -= 1
			end
		end
		return c
	end
	function s:Fire(...)
		local snap = {}
		for c in pairs(listeners) do snap[#snap + 1] = c end
		for _, c in ipairs(snap) do if c.Connected then c.fn(...) end end
	end
	function s:Wait() coroutine.yield() end
	function s:Clear()
		local snap = {}
		for c in pairs(listeners) do snap[#snap + 1] = c end
		for _, c in ipairs(snap) do c:Disconnect() end
	end
	return s
end

local BASE_PARTS = { Part = true, MeshPart = true, WedgePart = true, UnionOperation = true, TrussPart = true, CornerWedgePart = true, SpawnLocation = true }
local POST_EFFECTS = { PostEffect = true, BloomEffect = true, BlurEffect = true, ColorCorrectionEffect = true, SunRaysEffect = true, DepthOfFieldEffect = true }
local LAYER_COLLECTORS = { LayerCollector = true, BillboardGui = true, SurfaceGui = true, ScreenGui = true }

local function ancestorsFire(o, prop, subj)
	while o do o[prop]:Fire(subj); o = o.Parent end
end

local methods = {}
local Instance = {}
function Instance.new(class, parent)
	local data = {
		ClassName = class,
		Name = class,
		children = {},
		signals = {},
		attributes = {},
		Visible = true,
		Enabled = true,
		Transparency = 0,
		LocalTransparencyModifier = 0,
		Reflectance = 0,
		CastShadow = true,
		CanCollide = true,
		Health = 100,
		MaxHealth = 100,
		WalkSpeed = 40,
		AutoRotate = true,
		Position = Vector3.zero,
		Size = Vector3.new(1, 1, 1),
		Color = Color3.new(1, 1, 1),
		Material = "Plastic",
		P = 0,
		D = 0,
		MaxTorque = Vector3.zero,
		CFrame = CFrame.new(Vector3.zero),
		Value = nil,
		humState = Enum.HumanoidStateType.Running,
	}
	for _, sname in ipairs({ "DescendantAdded", "DescendantRemoving", "Destroying", "ChildAdded", "ChildRemoved", "Changed" }) do
		data[sname] = signal()
	end
	local obj = setmetatable({}, {
		__index = function(_, key)
			if methods[key] then return methods[key] end
			if data[key] ~= nil then return data[key] end
			for _, c in ipairs(data.children) do if c.Name == key then return c end end
		end,
		__newindex = function(self, key, value)
			if key == "Parent" then
				local old = data.Parent
				if old == value then return end
				if old then
					ancestorsFire(old, "DescendantRemoving", self)
					for _, d in ipairs(self:GetDescendants()) do ancestorsFire(old, "DescendantRemoving", d) end
					for i, c in ipairs(old.children) do if c == self then table.remove(old.children, i); break end end
					old.ChildRemoved:Fire(self)
				end
				data.Parent = value
				if value then
					value.children[#value.children + 1] = self
					value.ChildAdded:Fire(self)
					ancestorsFire(value, "DescendantAdded", self)
					for _, d in ipairs(self:GetDescendants()) do ancestorsFire(value, "DescendantAdded", d) end
				end
			else
				data[key] = value
				if data.signals[key] then data.signals[key]:Fire() end
				if data.Changed then data.Changed:Fire(key) end
			end
		end,
	})
	if parent then obj.Parent = parent end
	return obj
end

function methods:IsA(cls)
	if self.ClassName == cls then return true end
	if cls == "BasePart" and BASE_PARTS[self.ClassName] then return true end
	if cls == "PostEffect" and POST_EFFECTS[self.ClassName] then return true end
	if cls == "LayerCollector" and LAYER_COLLECTORS[self.ClassName] then return true end
	if cls == "PVInstance" and (BASE_PARTS[self.ClassName] or self.ClassName == "Model") then return true end
	return false
end
function methods:GetChildren() return table.clone(self.children) end
function methods:GetDescendants()
	local out = {}
	local function walk(n)
		for _, c in ipairs(n.children) do out[#out + 1] = c; walk(c) end
	end
	walk(self)
	return out
end
function methods:FindFirstChild(name)
	for _, c in ipairs(self.children) do if c.Name == name then return c end end
end
function methods:FindFirstChildOfClass(cls)
	for _, c in ipairs(self.children) do if c.ClassName == cls or c:IsA(cls) then return c end end
end
function methods:FindFirstAncestorOfClass(cls)
	local p = self.Parent
	while p do if p.ClassName == cls or p:IsA(cls) then return p end; p = p.Parent end
end
function methods:FindFirstAncestorWhichIsA(cls)
	local p = self.Parent
	while p do if p:IsA(cls) then return p end; p = p.Parent end
end
function methods:IsDescendantOf(anc)
	local p = self.Parent
	while p do if p == anc then return true end; p = p.Parent end
	return false
end
function methods:GetAttribute(n) return self.attributes[n] end
function methods:SetAttribute(n, v) self.attributes[n] = v end
function methods:GetState() return self.humState end
function methods:MoveTo(pos) self.lastMoveTo = pos; self.moveCount = (self.moveCount or 0) + 1 end
function methods:Destroy()
	if self.destroyed then return end
	self.Destroying:Fire()
	self.Parent = nil
	for _, c in ipairs(self:GetChildren()) do c:Destroy() end
	self.destroyed = true
end

local function typeof(v)
	if type(v) == "table" and v.ClassName then return "Instance" end
	if type(v) == "table" and v.X and v.Y and v.Z then return "Vector3" end
	return type(v)
end

local task = {}
function task.spawn(fn, ...)
	if type(fn) == "function" then
		local co = coroutine.create(fn)
		local ok, err = coroutine.resume(co, ...)
		assert(ok, err)
		return co
	elseif type(fn) == "thread" then
		local ok, err = coroutine.resume(fn, ...)
		assert(ok, err)
		return fn
	end
end
function task.defer(fn, ...) return task.spawn(fn, ...) end
function task.delay(_, fn, ...) return task.spawn(fn, ...) end
function task.wait() return 0.016 end
function task.cancel(co) if type(co) == "thread" then coroutine.close(co) end end

local RunService = { Heartbeat = signal(), RenderStepped = signal(), bound = {} }
function RunService:BindToRenderStep(name, prio, fn) self.bound[name] = { prio = prio, fn = fn } end
function RunService:UnbindFromRenderStep(name) self.bound[name] = nil end
do
	local origFire = RunService.Heartbeat.Fire
	local waiters = {}
	function RunService.Heartbeat:Wait()
		local co = coroutine.running()
		waiters[#waiters + 1] = co
		return coroutine.yield()
	end
	function RunService.Heartbeat:Fire(...)
		origFire(self, ...)
		local batch = waiters; waiters = {}
		for _, co in ipairs(batch) do
			if coroutine.status(co) == "suspended" then
				local ok, err = coroutine.resume(co, true)
				if not ok then error(err) end
			end
		end
	end
end

local Lighting = Instance.new("Lighting")
Lighting.GlobalShadows = true
Lighting.FogEnd = 500
Lighting.FogStart = 50
Lighting.EnvironmentSpecularScale = 1
Lighting.EnvironmentDiffuseScale = 1
Lighting.ShadowSoftness = 0.5
local postBloom = Instance.new("BloomEffect", Lighting); postBloom.Enabled = true
local atmosphere = Instance.new("Atmosphere", Lighting); atmosphere.Density = 0.4

local workspace = Instance.new("Folder"); workspace.Name = "Workspace"
local terrain = Instance.new("Terrain", workspace)
terrain.WaterWaveSize = 0.2; terrain.WaterWaveSpeed = 10; terrain.WaterReflectance = 1; terrain.WaterTransparency = 0.3; terrain.Decoration = true
local clouds = Instance.new("Clouds", terrain); clouds.Enabled = true

local UserInputService = { MouseBehavior = Enum.MouseBehavior.Default, MouseIcon = "" }
local renderSettings = { QualityLevel = Enum.QualityLevel.Automatic }
local function settings() return { Rendering = renderSettings } end
local userGameSettings = { SavedQualityLevel = Enum.SavedQualitySetting.Automatic }
local function UserSettings() return { GetService = function(_, n) if n == "UserGameSettings" then return userGameSettings end end } end

local localPlayer = Instance.new("Player"); localPlayer.Name = "MainTester"; localPlayer.UserId = 101
local otherPlayer = Instance.new("Player"); otherPlayer.Name = "RemoteHelper"; otherPlayer.UserId = 102
local localChar = Instance.new("Model", workspace); localChar.Name = "MainTester"; localPlayer.Character = localChar
local hum = Instance.new("Humanoid", localChar); hum.AutoRotate = true; hum.Health = 100
local rootPart = Instance.new("Part", localChar); rootPart.Name = "HumanoidRootPart"; rootPart.Position = Vector3.new(0, 14, 0)
local localHat = Instance.new("Accessory", localChar); local localHatHandle = Instance.new("Part", localHat); localHatHandle.Transparency = 0
local localAmulet = Instance.new("Model", localChar); localAmulet.Name = "Star Amulet"; local localAmuletPart = Instance.new("Part", localAmulet); localAmuletPart.Transparency = 0

local remoteChar = Instance.new("Model", workspace); remoteChar.Name = "RemoteHelper"; otherPlayer.Character = remoteChar
local remoteRoot = Instance.new("Part", remoteChar); remoteRoot.Name = "HumanoidRootPart"; remoteRoot.Position = Vector3.new(25, 14, 0)
local remoteTorso = Instance.new("Part", remoteChar); remoteTorso.Name = "Torso"; remoteTorso.Transparency = 0

local Players = Instance.new("Players")
Players.Name = "Players"
Players.LocalPlayer = localPlayer
Players.list = { localPlayer, otherPlayer }
Players.PlayerAdded = signal()
Players.PlayerRemoving = signal()
localPlayer.Parent = Players
otherPlayer.Parent = Players
function Players:GetPlayers() return self.list end

local game = Instance.new("DataModel"); game.Name = "Game"
local services = { Lighting = Lighting, Workspace = workspace, Players = Players, RunService = RunService, UserInputService = UserInputService }
function game:GetService(k) return services[k] end
workspace.Parent = game
Lighting.Parent = game
Players.Parent = game
local function getService(k) return game:GetService(k) end

local connections = { list = {}, closed = false }
function connections:Get(id) return self.list[id] end
function connections:Add(id, conn)
	if self.closed then if conn and conn.Disconnect then conn:Disconnect() end; return end
	self:Cancel(id)
	self.list[id] = conn
end
function connections:Cancel(id)
	local c = self.list[id]
	if c and c.Disconnect then c:Disconnect() end
	self.list[id] = nil
end

local threads = { list = {}, closed = false }
function threads:Add(id, fn, ...)
	self:Cancel(id)
	self.list[id] = true
	local ok, err = pcall(fn, ...)
	self.list[id] = nil
	if not ok then error(err) end
end
function threads:Cancel(id) self.list[id] = nil end
function threads:Get(id) return self.list[id] end

local popUpEvents = {}
local fxLog = {}
local animCollectCalls = 0
local createAmuletCalls = 0
local popUpSetting = true
local gameApi = {
	ClientStatCache = true,
	Cache = function(_, path)
		if path and path[1] == "Settings" and path[2] == "PollenPopUps" then return popUpSetting end
	end,
	PlayerSettingsEvent = {
		FireServer = function(_, key, val)
			if key == "PollenPopUps" then
				popUpSetting = val
				popUpEvents[#popUpEvents + 1] = val
			end
		end,
	},
	CollectiblesAnimator = {
		AnimateCollect = function() animCollectCalls += 1 end,
	},
	LocalAmulets = {
		CreatePlayerAmulets = function() createAmuletCalls += 1 end,
	},
	LocalFXModule = {
		ClientRun = function(a, b)
			fxLog[#fxLog + 1] = (type(a) == "string" and a) or b
		end,
	},
	BuffTile = function() return nil end,
}
local function secureCall(fn, ...) return fn(...) end
local function getRootPart() return rootPart end
local function getHumanoid() return hum end
local pepperFieldObj = Instance.new("Part", workspace); pepperFieldObj.Name = "Pepper Patch"; pepperFieldObj.Position = Vector3.new(0, 12, 0); pepperFieldObj.Size = Vector3.new(100, 4, 100)
local function getFieldAt(pos)
	if math.abs(pos.X - pepperFieldObj.Position.X) <= 50 and math.abs(pos.Z - pepperFieldObj.Position.Z) <= 50 then
		return pepperFieldObj
	end
end
local currentField = pepperFieldObj
local function distanceTo(p) return (p - rootPart.Position).Magnitude end
local function saveConfig() end

local cfg = {
	autofarm = { enabled = true, smileytime = 4, smileymigrated = false, farmdupedtokens = true, precisionupkeep = true },
	prioritization = { enabled = false },
	face = { fires = true, refresh = false, flamemigrated = false, optimalflames = false, shiftlock = false },
}
local state = { stop = false, stopface = false, activityStatus = 1, stopdig = nil }
local tracked = { flames = {}, dupedsmiley = {}, dupedtokens = {} }
local buffs = {}
local touchedMarks = {}
local activeHazards = false
local rbcSafety = { Hazards = function() return {} end, BuffTarget = function() return nil end }
local function isPathClear() return activeHazards end
local comboController = { active = false, BlocksMove = function() return false end }
local showerController = { active = false }
local mondoHop = { active = false }
local bearCombat = { active = false, Pick = function() return nil end }
local fieldPositionPolicy = {
	idleReleased = 0,
	ReleaseIdle = function(self) self.idleReleased += 1 end,
	SmileyOnly = function() return false end,
	TargetPosition = function(_, t) return t and t.Position or nil end,
	StrictArea = function() return nil end,
}
local smoothMovement = { roam = { active = true } }
local dupedTokenPolicy = { Allowed = function() return true end }
local flameController
local petalCollector = {}
local gatheringPriorities = {
	petals = petalCollector,
	activeOptions = {},
	bloomFocused = false,
	precisionCalls = 0,
	PrecisionUpkeep = function(self) self.precisionCalls += 1; return nil end,
	PrecisionReady = function() return false end,
	Precise = function() return nil end,
	BloomTarget = function() return nil end,
	BloomFocus = function() return nil end,
	Candidate = function(_, cat, opts, rootPos)
		if cat == "Duped Smiley" then
			for _, tok in pairs(tracked.dupedsmiley) do
				if tok and tok.Parent then return "Duped Smiley", tok end
			end
		end
	end,
	Pick = function() return nil end,
}

-- =========================================================================
-- SECTION A: Ultra Anti-Lag + visualOptimizer (extracted from atlasbss.lua)
-- =========================================================================
local visualOptimizer = {
	modes = {}, originals = {},
	decorative = {Map=true,Decorations=true,FieldDecos=true,Amulets=true,["Shell Amulets"]=true,
		["Stickbug Amulets"]=true,Campsite=true,Leaderboards=true,HiveDeco=true,
		TheGames_WideBanners=true},
	protected = {Collectibles=true,DupedTokens=true,Particles=true,Stations=true,
		PoppablePlants=true,Monsters=true,MonsterSpawners=true,Toys=true,NPCs=true,
		Honeycombs=true,FlowerZones=true,PlayerFlames=true,Clouds=true,Balloons=true},
}

function visualOptimizer:Remember(object, property, value)
	local ok, previous = pcall(function() return object[property] end)
	if not ok or previous == value then return end
	local saved = self.originals[object]
	if not saved then saved={};self.originals[object]=saved end
	if saved[property] == nil then saved[property]=previous end
	pcall(function() object[property]=value end)
end

function visualOptimizer:Restore()
	for object, properties in pairs(self.originals) do
		for property, value in pairs(properties) do pcall(function() object[property]=value end) end
	end
	table.clear(self.originals)
end

-- Explicit lifetime: weak Instance keys can disappear before restoration, and
-- removed objects must not leave saved-property records behind.
function visualOptimizer:Release(object)
	local properties = self.originals[object]
	if not properties then return end
	self.originals[object] = nil
	if not object.Parent then return end
	for property, value in pairs(properties) do pcall(function() object[property]=value end) end
end

function visualOptimizer:Apply(object)
	if object.Name == "WarningDisk" or object.Name == "Star Shower Guide" then return end
	if not object.Parent then return end
	local cosmetic, protected, bees, flowers, balloons, otherPlayer, frog = false,false,false,false,false,false,false
	local ancestor = object
	while ancestor and ancestor ~= workspace do
		if ancestor.Name == "WarningDisk" then return end
		if self.decorative[ancestor.Name] then cosmetic=true end
		if self.protected[ancestor.Name] then protected=true end
		if string.find(ancestor.Name,"Sign",1,true) then protected=true end
		if ancestor.Name == "Bees" then bees=true end
		if (ancestor.Name == "Frog" and ancestor:IsA("Model")) or (ancestor.Name == "Frogs" and (ancestor:IsA("Folder") or ancestor:IsA("Model"))) then frog=true end
		if ancestor.Name == "Flowers" then flowers=true end
		if ancestor.Name == "FieldBalloons" then balloons=true end
		ancestor=ancestor.Parent
	end
	if self.modes.players then
		local model=object:FindFirstAncestorOfClass("Model")
		local player=model and getService("Players"):GetPlayerFromCharacter(model)
		otherPlayer=player ~= nil and player ~= localPlayer
	end
	local aggressive=self.modes.aggressive
	local effects=aggressive or self.modes.effects
	local textures=aggressive or self.modes.textures
	local hide=((self.modes.decorations or aggressive) and cosmetic) or (self.modes.bees and bees) or
		(self.modes.flowers and flowers) or (self.modes.balloons and balloons) or otherPlayer or (self.modes.frogs and frog)
	if object:IsA("BasePart") then
		if textures or self.modes.main then
			self:Remember(object,"CastShadow",false)
			self:Remember(object,"Reflectance",0)
			self:Remember(object,"Material",Enum.Material.SmoothPlastic)
		end
		if hide then self:Remember(object,"LocalTransparencyModifier",1) end
		if textures and cosmetic and not protected and object:IsA("MeshPart") then self:Remember(object,"TextureID","") end
	elseif object:IsA("Decal") or object:IsA("Texture") then
		-- Token icons, NPC/shop signs, hive and field identifiers must remain readable by scripts.
		if textures and cosmetic and not protected then self:Remember(object,"Texture","") end
		if hide and (not protected or (self.modes.frogs and frog)) then self:Remember(object,"Transparency",1) end
	elseif object:IsA("SpecialMesh") then
		if textures and cosmetic and not protected then self:Remember(object,"TextureId","") end
	elseif object:IsA("SurfaceAppearance") then
		if textures and cosmetic and not protected then
			for _, property in ipairs({"ColorMap","MetalnessMap","NormalMap","RoughnessMap"}) do self:Remember(object,property,"") end
		end
	elseif object:IsA("ParticleEmitter") or object:IsA("Trail") or object:IsA("Beam") then
		if effects or hide then
			self:Remember(object,"Enabled",false)
			if object:IsA("ParticleEmitter") or object:IsA("Trail") then pcall(function()object:Clear()end) end
		end
	elseif object:IsA("Light") or object:IsA("PostEffect") then
		if effects or self.modes.main or (self.modes.frogs and frog) then self:Remember(object,"Enabled",false) end
	elseif object:IsA("BillboardGui") or object:IsA("SurfaceGui") then
		if hide and ((cosmetic and not protected) or (self.modes.frogs and frog)) then self:Remember(object,"Enabled",false) end
	elseif object:IsA("Sound") then
		if self.modes.frogs and frog then self:Remember(object,"Volume",0) end
	end
end

function visualOptimizer:Refresh()
	threads:Cancel("visualOptimizerScan")
	connections:Cancel("visualOptimizerWorkspace")
	connections:Cancel("visualOptimizerLighting")
	connections:Cancel("visualOptimizerWorkspaceRemoving")
	connections:Cancel("visualOptimizerLightingRemoving")
	self:Restore()
	local active=false
	for _, on in pairs(self.modes) do if on then active=true;break end end
	if not active then return end
	if self.modes.main or self.modes.aggressive then
		self:Remember(Lighting,"GlobalShadows",false)
		pcall(function()self:Remember(settings().Rendering,"QualityLevel",Enum.QualityLevel.Level01)end)
		self:Remember(workspace.Terrain,"WaterWaveSize",0)
		self:Remember(workspace.Terrain,"WaterWaveSpeed",0)
		self:Remember(workspace.Terrain,"WaterReflectance",0)
	end
	connections:Add("visualOptimizerWorkspace",workspace.DescendantAdded:Connect(function(object) self:Apply(object) end))
	connections:Add("visualOptimizerLighting",Lighting.DescendantAdded:Connect(function(object) self:Apply(object) end))
	connections:Add("visualOptimizerWorkspaceRemoving",workspace.DescendantRemoving:Connect(function(object) self:Release(object) end))
	connections:Add("visualOptimizerLightingRemoving",Lighting.DescendantRemoving:Connect(function(object) self:Release(object) end))
	threads:Add("visualOptimizerScan",function()
		for _, root in ipairs({workspace,Lighting}) do
			local objects=root:GetDescendants()
			for i = 1, #objects do
				local object = objects[i]
				if object:IsDescendantOf(root) then self:Apply(object) end
				objects[i] = nil -- Release processed references before yielding.
				if i%150==0 then task.wait() end
			end
		end
	end)
end

function visualOptimizer:Set(mode, enabled)
	enabled=enabled==true
	if (self.modes[mode]==true)==enabled then return end
	self.modes[mode]=enabled
	self:Refresh()
end

function visualOptimizer:SetMany(modes)
	local changed=false
	for mode, enabled in pairs(modes) do
		local flag=enabled==true
		if (self.modes[mode]==true)~=flag then
			self.modes[mode]=flag
			changed=true
		end
	end
	if changed then self:Refresh() end
end

function visualOptimizer:Shutdown()
	threads:Cancel("visualOptimizerScan")
	connections:Cancel("visualOptimizerWorkspace")
	connections:Cancel("visualOptimizerLighting")
	connections:Cancel("visualOptimizerWorkspaceRemoving")
	connections:Cancel("visualOptimizerLightingRemoving")
	self:Restore()
	table.clear(self.modes)
end

local COSMETIC_LOCAL_FX = {
	AquaWave = true,
	BeamShot = true,
	BubbleBloatCollect = true,
	DiamondDrain = true,
	EggShield = true,
	FallingCoal = true,
	FieldRectPulses = true,
	GoldenRake = true,
	GummyStar = true,
	Gummyball = true,
	HoneyHammer = true,
	OrbExplode = true,
	PartyPopper = true,
	PetalShuriken = true,
	PorcelainDipperAbility = true,
	RectPulse = true,
	RingPulse = true,
	SnowballThrow = true,
	SnowflakeBreeze = true,
	SpotlightBeam = true,
	StarSaw = true,
	SweepArch = true,
	WaterRipple = true,
}

local ULTRA_COSMETIC_TOP_FOLDERS = {
	"Amulets", "Shell Amulets", "Stickbug Amulets", "BallArrowFolder", "BoostBalls",
	"Campsite", "ClassicMinigame", "Cubs", "Faces", "FieldDecos", "Frogs", "Goo",
	"TheGamesEvent", "TheGames_WideBanners",
}

local ULTRA_DECO_CHILD_NAMES = {
	"35ZoneCave", "BubbleWandChimney", "TreatBooth", "SpiderCave",
	"Petal Shop", "JumpGames", "PEggMaze",
}

local function extractLocalFxName(a, b)
	if type(a) == "string" then return a end
	if type(b) == "string" then return b end
	return nil
end

local ultraAntiLag = {
	modes = {"main", "aggressive", "effects", "textures", "decorations", "bees", "frogs", "flowers", "balloons", "players"},
	enabled = false,
	savedProps = {},
	savedTransientProps = setmetatable({}, { __mode = "k" }),
	savedParticleFX = setmetatable({}, { __mode = "k" }),
	detached = {},
	detachedSet = {},
	detachedBees = {},
	detachedBeeSet = {},
	playerConns = {},
	playerChars = {},
	wrapped = {},
	savedLighting = nil,
	savedTerrain = nil,
	savedQuality = nil,
	savedRenderQuality = nil,
	savedPollenPopUp = nil,
	pollenPopUpChanged = false,
}

function ultraAntiLag:Remember(tbl, object, property, value)
	local ok, previous = pcall(function() return object[property] end)
	if not ok or previous == value then return end
	local saved = tbl[object]
	if not saved then saved = {}; tbl[object] = saved end
	if saved[property] == nil then saved[property] = previous end
	pcall(function() object[property] = value end)
end

function ultraAntiLag:RestoreTable(tbl)
	for object, properties in pairs(tbl) do
		if object and (typeof(object) ~= "Instance" or object.Parent) then
			for property, value in pairs(properties) do
				pcall(function() object[property] = value end)
			end
		end
	end
	table.clear(tbl)
end

function ultraAntiLag:Detach(inst, list, set)
	if not inst or set[inst] then return end
	local okParent, origParent = pcall(function() return inst.Parent end)
	if not okParent or not origParent then return end
	set[inst] = true
	list[#list + 1] = { inst = inst, parent = origParent }
	pcall(function() inst.Parent = nil end)
end

function ultraAntiLag:RestoreList(list, set)
	for i = #list, 1, -1 do
		local entry = list[i]
		if entry.inst and entry.parent and (typeof(entry.parent) ~= "Instance" or entry.parent.Parent) then
			pcall(function() entry.inst.Parent = entry.parent end)
		end
	end
	table.clear(list)
	table.clear(set)
end

function ultraAntiLag:IsProtectedVisual(object)
	local ancestor = object
	while ancestor and ancestor ~= workspace do
		local name = ancestor.Name
		if visualOptimizer.protected[name] and name ~= "Balloons" then return true end
		if string.find(name, "Sign", 1, true) then return true end
		ancestor = ancestor.Parent
	end
	return false
end

function ultraAntiLag:ApplyStaticObject(object, isFlowers, hideParts)
	if not self.enabled or not object or not object.Parent then return end
	if object:IsA("BasePart") then
		if isFlowers then
			self:Remember(self.savedProps, object, "CastShadow", false)
			self:Remember(self.savedProps, object, "Reflectance", 0)
			self:Remember(self.savedProps, object, "LocalTransparencyModifier", 1)
			return
		end
		local okMat, mat = pcall(function() return object.Material end)
		if okMat and (mat == Enum.Material.Neon or mat == Enum.Material.ForceField or mat == Enum.Material.Glass) then return end
		self:Remember(self.savedProps, object, "CastShadow", false)
		self:Remember(self.savedProps, object, "Reflectance", 0)
		self:Remember(self.savedProps, object, "Material", Enum.Material.SmoothPlastic)
		if not self:IsProtectedVisual(object) then
			if hideParts then self:Remember(self.savedProps, object, "LocalTransparencyModifier", 1) end
			if object:IsA("MeshPart") then self:Remember(self.savedProps, object, "TextureID", "") end
		end
	elseif object:IsA("Decal") or object:IsA("Texture") then
		if isFlowers then
			self:Remember(self.savedProps, object, "Transparency", 1)
		elseif not self:IsProtectedVisual(object) then
			self:Remember(self.savedProps, object, "Texture", "")
			self:Remember(self.savedProps, object, "Transparency", 1)
		end
	elseif object:IsA("SpecialMesh") then
		if not isFlowers and not self:IsProtectedVisual(object) then
			self:Remember(self.savedProps, object, "TextureId", "")
		end
	elseif object:IsA("SurfaceAppearance") then
		if not isFlowers and not self:IsProtectedVisual(object) then
			for _, prop in ipairs({"ColorMap", "MetalnessMap", "NormalMap", "RoughnessMap"}) do
				self:Remember(self.savedProps, object, prop, "")
			end
		end
	elseif object:IsA("ParticleEmitter") or object:IsA("Trail") or object:IsA("Beam") then
		local n = object.Name
		if n == "LeafBurst" or n == "Sparkles" or n == "FireParticles" or n == "PuffshroomSpores" then return end
		if not self:IsProtectedVisual(object) then
			self:Remember(self.savedProps, object, "Enabled", false)
			if object:IsA("ParticleEmitter") or object:IsA("Trail") then pcall(function() object:Clear() end) end
		end
	elseif object:IsA("Light") then
		if not self:IsProtectedVisual(object) then
			self:Remember(self.savedProps, object, "Enabled", false)
		end
	end
end

function ultraAntiLag:HideBalloonModel(model)
	if not self.enabled or not model or not model.Parent then return end
	for _, desc in ipairs(model:GetDescendants()) do
		if desc:IsA("BasePart") then
			self:Remember(self.savedTransientProps, desc, "LocalTransparencyModifier", 1)
			self:Remember(self.savedTransientProps, desc, "CastShadow", false)
		elseif desc:IsA("Decal") or desc:IsA("Texture") then
			self:Remember(self.savedTransientProps, desc, "Transparency", 1)
		elseif desc:IsA("ParticleEmitter") or desc:IsA("Trail") or desc:IsA("Beam") or desc:IsA("Light") then
			self:Remember(self.savedTransientProps, desc, "Enabled", false)
		end
	end
end

function ultraAntiLag:SyncParticleFX(desc)
	if not self.enabled or not desc or not desc.Parent then return end
	if desc:IsA("ParticleEmitter") or desc:IsA("Trail") or desc:IsA("Beam") then
		if self.savedParticleFX[desc] == nil then
			local ok, wasOn = pcall(function() return desc.Enabled end)
			if ok then self.savedParticleFX[desc] = wasOn end
		end
		pcall(function() desc.Enabled = false end)
		if desc:IsA("ParticleEmitter") or desc:IsA("Trail") then pcall(function() desc:Clear() end) end
	end
end

function ultraAntiLag:HideAmuletModel(obj)
	if not self.enabled or not obj or not obj.Parent then return end
	local apply = function(d)
		if d:IsA("BasePart") then
			self:Remember(self.savedTransientProps, d, "LocalTransparencyModifier", 1)
			self:Remember(self.savedTransientProps, d, "CastShadow", false)
		elseif d:IsA("Decal") or d:IsA("Texture") then
			self:Remember(self.savedTransientProps, d, "Transparency", 1)
		elseif d:IsA("ParticleEmitter") or d:IsA("Trail") or d:IsA("Beam") or d:IsA("Light") then
			self:Remember(self.savedTransientProps, d, "Enabled", false)
		end
	end
	apply(obj)
	for _, d in ipairs(obj:GetDescendants()) do apply(d) end
end

function ultraAntiLag:HideCharacterVisuals(char, isLocal)
	if not self.enabled or not char or not char.Parent then return end
	local function apply(d)
		if isLocal then
			if d.Parent == char and type(d.Name) == "string" and string.find(string.lower(d.Name), "amulet", 1, true) then
				self:HideAmuletModel(d)
			end
			return
		end
		if d:IsA("BasePart") then
			self:Remember(self.savedTransientProps, d, "LocalTransparencyModifier", 1)
			self:Remember(self.savedTransientProps, d, "CastShadow", false)
		elseif d:IsA("Decal") or d:IsA("Texture") then
			self:Remember(self.savedTransientProps, d, "Transparency", 1)
		elseif d:IsA("ParticleEmitter") or d:IsA("Trail") or d:IsA("Beam") or d:IsA("Sparkles") or d:IsA("Light") then
			self:Remember(self.savedTransientProps, d, "Enabled", false)
		end
	end
	for _, d in ipairs(char:GetDescendants()) do apply(d) end
	local key = "ultraAntiLagCharDesc:" .. tostring(char)
	if not connections:Get(key) and char.DescendantAdded then
		connections:Add(key, char.DescendantAdded:Connect(function(d)
			if self.enabled then apply(d) end
		end))
	end
end

function ultraAntiLag:WatchPlayer(player)
	if not player or self.playerConns[player] then return end
	local isLocal = (player == localPlayer)
	self.playerConns[player] = true
	if player.Character then
		self.playerChars[player] = player.Character
		self:HideCharacterVisuals(player.Character, isLocal)
	end
	if player.CharacterAdded then
		connections:Add("ultraAntiLagCharAdded:" .. tostring(player), player.CharacterAdded:Connect(function(char)
			local prevChar = self.playerChars[player]
			if prevChar and prevChar ~= char then
				connections:Cancel("ultraAntiLagCharDesc:" .. tostring(prevChar))
			end
			self.playerChars[player] = char
			if self.enabled then self:HideCharacterVisuals(char, isLocal) end
		end))
	end
	if player.CharacterRemoving then
		connections:Add("ultraAntiLagCharRem:" .. tostring(player), player.CharacterRemoving:Connect(function(char)
			if self.playerChars[player] == char then self.playerChars[player] = nil end
			connections:Cancel("ultraAntiLagCharDesc:" .. tostring(char))
		end))
	end
end

function ultraAntiLag:WrapMethod(tbl, methodName, key, handler)
	if self.wrapped[key] or type(tbl) ~= "table" or type(tbl[methodName]) ~= "function" then return end
	local orig = tbl[methodName]
	local wrapper = function(...)
		local ok, res = pcall(handler, ...)
		if ok and res == false then return nil end
		return orig(...)
	end
	local okSet = pcall(function() tbl[methodName] = wrapper end)
	if okSet then
		self.wrapped[key] = { tbl = tbl, method = methodName, orig = orig, wrapper = wrapper }
	end
end

function ultraAntiLag:UnwrapAll()
	for key, rec in pairs(self.wrapped) do
		if rec.tbl and rec.tbl[rec.method] == rec.wrapper then
			pcall(function() rec.tbl[rec.method] = rec.orig end)
		end
		self.wrapped[key] = nil
	end
end

function ultraAntiLag:PruneBees()
	if not self.enabled or #self.detachedBees == 0 then return end
	for i = #self.detachedBees, 1, -1 do
		local entry = self.detachedBees[i]
		local inst = entry.inst
		local drop = (not inst)
		if not drop and inst.FindFirstChild then
			local ownerVal = inst:FindFirstChild("Owner")
			if ownerVal and ownerVal:IsA("ObjectValue") and (not ownerVal.Value or not ownerVal.Value.Parent) then
				drop = true
			end
		end
		if drop then
			self.detachedBeeSet[inst] = nil
			table.remove(self.detachedBees, i)
		end
	end
end

function ultraAntiLag:Set(enabled)
	enabled = enabled == true
	if self.enabled == enabled then return end
	self.enabled = enabled
	threads:Cancel("ultraAntiLagScan")
	for _, id in ipairs({
		"ultraAntiLagLighting", "ultraAntiLagBees", "ultraAntiLagParticles",
		"ultraAntiLagBalloons", "ultraAntiLagPlayerAdded", "ultraAntiLagPlayerRemoving",
		"ultraAntiLagWorkspaceChild",
	}) do
		connections:Cancel(id)
	end
	for player in pairs(self.playerConns) do
		connections:Cancel("ultraAntiLagCharAdded:" .. tostring(player))
		connections:Cancel("ultraAntiLagCharRem:" .. tostring(player))
		local cachedChar = self.playerChars[player]
		if cachedChar then connections:Cancel("ultraAntiLagCharDesc:" .. tostring(cachedChar)) end
		if player.Character and player.Character ~= cachedChar then
			connections:Cancel("ultraAntiLagCharDesc:" .. tostring(player.Character))
		end
	end
	table.clear(self.playerConns)
	table.clear(self.playerChars)

	if not enabled then
		self:UnwrapAll()
		self:RestoreList(self.detachedBees, self.detachedBeeSet)
		self:RestoreList(self.detached, self.detachedSet)
		for inst, origOn in pairs(self.savedParticleFX) do
			if inst and inst.Parent then pcall(function() inst.Enabled = origOn end) end
		end
		table.clear(self.savedParticleFX)
		self:RestoreTable(self.savedTransientProps)
		self:RestoreTable(self.savedProps)
		if self.savedLighting and Lighting then
			local l = self.savedLighting
			self.savedLighting = nil
			pcall(function()
				Lighting.GlobalShadows = l.GlobalShadows
				Lighting.FogEnd = l.FogEnd
				Lighting.FogStart = l.FogStart
				if l.EnvironmentSpecularScale ~= nil then Lighting.EnvironmentSpecularScale = l.EnvironmentSpecularScale end
				if l.EnvironmentDiffuseScale ~= nil then Lighting.EnvironmentDiffuseScale = l.EnvironmentDiffuseScale end
				if l.ShadowSoftness ~= nil then Lighting.ShadowSoftness = l.ShadowSoftness end
			end)
		end
		if self.savedTerrain then
			local t = self.savedTerrain
			self.savedTerrain = nil
			local terrain = workspace:FindFirstChildOfClass("Terrain")
			if terrain then
				pcall(function()
					terrain.WaterWaveSize = t.WaterWaveSize
					terrain.WaterWaveSpeed = t.WaterWaveSpeed
					terrain.WaterReflectance = t.WaterReflectance
					if t.WaterTransparency ~= nil then terrain.WaterTransparency = t.WaterTransparency end
					if t.Decoration ~= nil then terrain.Decoration = t.Decoration end
				end)
			end
		end
		if self.savedRenderQuality ~= nil then
			local prev = self.savedRenderQuality
			self.savedRenderQuality = nil
			pcall(function() settings().Rendering.QualityLevel = prev end)
		end
		if self.savedQuality ~= nil then
			local prev = self.savedQuality
			self.savedQuality = nil
			pcall(function() UserSettings():GetService("UserGameSettings").SavedQualityLevel = prev end)
		end
		if self.pollenPopUpChanged then
			local prevPopUp = self.savedPollenPopUp ~= false
			self.pollenPopUpChanged = false
			self.savedPollenPopUp = nil
			if gameApi.PlayerSettingsEvent then
				pcall(secureCall, gameApi.PlayerSettingsEvent.FireServer, gameApi.PlayerSettingsEvent, "PollenPopUps", prevPopUp)
			end
		end
		return
	end

	pcall(function()
		local gameSettings = UserSettings():GetService("UserGameSettings")
		if self.savedQuality == nil then self.savedQuality = gameSettings.SavedQualityLevel end
		gameSettings.SavedQualityLevel = Enum.SavedQualitySetting.QualityLevel1
	end)
	pcall(function()
		local renderSettings = settings().Rendering
		if self.savedRenderQuality == nil then self.savedRenderQuality = renderSettings.QualityLevel end
		renderSettings.QualityLevel = Enum.QualityLevel.Level01
	end)
	if Lighting then
		local okL, gs, fe, fs = pcall(function() return Lighting.GlobalShadows, Lighting.FogEnd, Lighting.FogStart end)
		local saved = okL and { GlobalShadows = gs, FogEnd = fe, FogStart = fs } or {}
		pcall(function() saved.EnvironmentSpecularScale = Lighting.EnvironmentSpecularScale end)
		pcall(function() saved.EnvironmentDiffuseScale = Lighting.EnvironmentDiffuseScale end)
		pcall(function() saved.ShadowSoftness = Lighting.ShadowSoftness end)
		self.savedLighting = saved
		pcall(function()
			Lighting.GlobalShadows = false
			Lighting.FogStart = 1e9
			Lighting.FogEnd = 1e9
			if saved.EnvironmentSpecularScale ~= nil then Lighting.EnvironmentSpecularScale = 0 end
			if saved.EnvironmentDiffuseScale ~= nil then Lighting.EnvironmentDiffuseScale = 0 end
			if saved.ShadowSoftness ~= nil then Lighting.ShadowSoftness = 0 end
		end)
		for _, eff in ipairs(Lighting:GetChildren()) do
			if eff:IsA("PostEffect") then
				self:Remember(self.savedProps, eff, "Enabled", false)
			elseif eff:IsA("Atmosphere") then
				self:Remember(self.savedProps, eff, "Density", 0)
			end
		end
		if Lighting.Changed then
			connections:Add("ultraAntiLagLighting", Lighting.Changed:Connect(function(prop)
				if not self.enabled then return end
				if prop == "GlobalShadows" or prop == "FogEnd" or prop == "FogStart"
					or prop == "EnvironmentSpecularScale" or prop == "EnvironmentDiffuseScale" then
					pcall(function()
						if Lighting.GlobalShadows ~= false then Lighting.GlobalShadows = false end
						if Lighting.FogEnd < 1e8 then Lighting.FogEnd = 1e9 end
						if Lighting.FogStart < 1e8 then Lighting.FogStart = 1e9 end
						if saved.EnvironmentSpecularScale ~= nil and Lighting.EnvironmentSpecularScale ~= 0 then Lighting.EnvironmentSpecularScale = 0 end
						if saved.EnvironmentDiffuseScale ~= nil and Lighting.EnvironmentDiffuseScale ~= 0 then Lighting.EnvironmentDiffuseScale = 0 end
					end)
				end
			end))
		end
	end
	local terrain = workspace:FindFirstChildOfClass("Terrain")
	if terrain then
		local okT, ws, wsp, wr = pcall(function() return terrain.WaterWaveSize, terrain.WaterWaveSpeed, terrain.WaterReflectance end)
		local tSaved = okT and { WaterWaveSize = ws, WaterWaveSpeed = wsp, WaterReflectance = wr } or {}
		pcall(function() tSaved.WaterTransparency = terrain.WaterTransparency end)
		pcall(function() tSaved.Decoration = terrain.Decoration end)
		self.savedTerrain = tSaved
		pcall(function()
			terrain.WaterWaveSize = 0
			terrain.WaterWaveSpeed = 0
			terrain.WaterReflectance = 0
			if tSaved.WaterTransparency ~= nil then terrain.WaterTransparency = 0 end
			if tSaved.Decoration ~= nil then terrain.Decoration = false end
		end)
		for _, child in ipairs(terrain:GetChildren()) do
			if child:IsA("Clouds") then self:Remember(self.savedProps, child, "Enabled", false) end
		end
	end
	if not self.pollenPopUpChanged and gameApi.PlayerSettingsEvent and gameApi.ClientStatCache then
		local okPop, curPopUp = pcall(function() return gameApi:Cache({ "Settings", "PollenPopUps" }) end)
		if okPop and curPopUp ~= false then
			self.savedPollenPopUp = (curPopUp == nil and true or curPopUp)
			self.pollenPopUpChanged = true
			pcall(secureCall, gameApi.PlayerSettingsEvent.FireServer, gameApi.PlayerSettingsEvent, "PollenPopUps", false)
		end
	end

	-- Detach purely cosmetic workspace containers and player bees (zero gameplay/raycast dependencies).
	for _, name in ipairs(ULTRA_COSMETIC_TOP_FOLDERS) do
		self:Detach(workspace:FindFirstChild(name), self.detached, self.detachedSet)
	end
	local map = workspace:FindFirstChild("Map")
	if map then self:Detach(map:FindFirstChild("Fences"), self.detached, self.detachedSet) end
	local hiveDeco = workspace:FindFirstChild("HiveDeco")
	if hiveDeco then
		self:Detach(hiveDeco:FindFirstChild("HiveModels"), self.detached, self.detachedSet)
		self:Detach(hiveDeco:FindFirstChild("StickerCanvases"), self.detached, self.detachedSet)
	end
	local decorations = workspace:FindFirstChild("Decorations")
	if decorations then
		for _, name in ipairs(ULTRA_DECO_CHILD_NAMES) do
			self:Detach(decorations:FindFirstChild(name), self.detached, self.detachedSet)
		end
		local misc = decorations:FindFirstChild("Misc")
		if misc then
			for _, child in ipairs(misc:GetChildren()) do
				local n = child.Name
				if string.find(n, "Blue Flower") or n == "Bamboo" or n == "Bush" or n == "Mushroom" then
					self:Detach(child, self.detached, self.detachedSet)
				end
			end
		end
	end
	local function bindBees(folder)
		if not folder or connections:Get("ultraAntiLagBees") then return end
		for _, child in ipairs(folder:GetChildren()) do
			self:Detach(child, self.detachedBees, self.detachedBeeSet)
		end
		connections:Add("ultraAntiLagBees", folder.ChildAdded:Connect(function(child)
			if not self.enabled then return end
			task.defer(function()
				if self.enabled and child.Parent == folder then
					self:Detach(child, self.detachedBees, self.detachedBeeSet)
				end
			end)
		end))
	end
	bindBees(workspace:FindFirstChild("Bees"))

	local function bindParticles(folder)
		if not folder or connections:Get("ultraAntiLagParticles") then return end
		for _, desc in ipairs(folder:GetDescendants()) do self:SyncParticleFX(desc) end
		if folder.DescendantAdded then
			connections:Add("ultraAntiLagParticles", folder.DescendantAdded:Connect(function(desc)
				if self.enabled then self:SyncParticleFX(desc) end
			end))
		end
	end
	bindParticles(workspace:FindFirstChild("Particles"))

	local balloons = workspace:FindFirstChild("Balloons")
	local fieldBalloons = balloons and balloons:FindFirstChild("FieldBalloons")
	if fieldBalloons then
		for _, child in ipairs(fieldBalloons:GetChildren()) do self:HideBalloonModel(child) end
		connections:Add("ultraAntiLagBalloons", fieldBalloons.ChildAdded:Connect(function(child)
			if self.enabled then self:HideBalloonModel(child) end
		end))
	end

	local playersService = getService("Players")
	if playersService then
		for _, p in ipairs(playersService:GetPlayers()) do self:WatchPlayer(p) end
		if playersService.PlayerAdded then
			connections:Add("ultraAntiLagPlayerAdded", playersService.PlayerAdded:Connect(function(p)
				if self.enabled then self:WatchPlayer(p) end
			end))
		end
		if playersService.PlayerRemoving then
			connections:Add("ultraAntiLagPlayerRemoving", playersService.PlayerRemoving:Connect(function(p)
				connections:Cancel("ultraAntiLagCharAdded:" .. tostring(p))
				connections:Cancel("ultraAntiLagCharRem:" .. tostring(p))
				self.playerConns[p] = nil
				local cachedChar = self.playerChars[p]
				self.playerChars[p] = nil
				if cachedChar then connections:Cancel("ultraAntiLagCharDesc:" .. tostring(cachedChar)) end
				if p.Character and p.Character ~= cachedChar then
					connections:Cancel("ultraAntiLagCharDesc:" .. tostring(p.Character))
				end
			end))
		end
	end

	-- Safe cosmetic-only method filters (never blocks tokens, marks, crosshairs, combos, blooms, petals, flames, or showers).
	if gameApi.CollectiblesAnimator then
		self:WrapMethod(gameApi.CollectiblesAnimator, "AnimateCollect", "collectAnim", function()
			return not self.enabled
		end)
	end
	if gameApi.LocalAmulets then
		self:WrapMethod(gameApi.LocalAmulets, "CreatePlayerAmulets", "localAmulets", function()
			return not self.enabled
		end)
	end
	if gameApi.LocalFXModule then
		self:WrapMethod(gameApi.LocalFXModule, "ClientRun", "cosmeticLocalFX", function(a, b)
			if not self.enabled then return true end
			local fxName = extractLocalFxName(a, b)
			if fxName and COSMETIC_LOCAL_FX[fxName] then return false end
			return true
		end)
	end

	threads:Add("ultraAntiLagScan", function()
		local targets = {
			{ inst = workspace:FindFirstChild("Map"), flowers = false, hideParts = false },
			{ inst = workspace:FindFirstChild("Decorations"), flowers = false, hideParts = true },
			{ inst = workspace:FindFirstChild("Leaderboards"), flowers = false, hideParts = true },
			{ inst = workspace:FindFirstChild("Flowers"), flowers = true, hideParts = true },
		}
		for _, target in ipairs(targets) do
			local root = target.inst
			if root and root.Parent and self.enabled then
				local objects = root:GetDescendants()
				for i = 1, #objects do
					if not self.enabled then break end
					local object = objects[i]
					if object.Parent then self:ApplyStaticObject(object, target.flowers, target.hideParts) end
					objects[i] = nil
					if i % 150 == 0 then task.wait() end
				end
			end
		end
	end)
end

function ultraAntiLag:Shutdown()
	self:Set(false)
end


do
	-- Prepare workspace hierarchy mirroring live BSS
	local collectibles = Instance.new("Folder", workspace); collectibles.Name = "Collectibles"
	local liveToken = Instance.new("Part", collectibles); liveToken.Name = "C"

	local particlesFolder = Instance.new("Folder", workspace); particlesFolder.Name = "Particles"
	local emitterPart = Instance.new("Part", particlesFolder); emitterPart.Name = "PuffFX"
	local pEmitter = Instance.new("ParticleEmitter", emitterPart); pEmitter.Enabled = true
	local warnDisk = Instance.new("Part", particlesFolder); warnDisk.Name = "WarningDisk"

	local fieldDecos = Instance.new("Folder", workspace); fieldDecos.Name = "FieldDecos"
	local mapFolder = Instance.new("Folder", workspace); mapFolder.Name = "Map"
	local fences = Instance.new("Folder", mapFolder); fences.Name = "Fences"
	local decoFolder = Instance.new("Folder", workspace); decoFolder.Name = "Decorations"
	local caveDeco = Instance.new("Folder", decoFolder); caveDeco.Name = "35ZoneCave"

	local flowersFolder = Instance.new("Folder", workspace); flowersFolder.Name = "Flowers"
	local flowerPart = Instance.new("Part", flowersFolder); flowerPart.Name = "Flower"; flowerPart.Transparency = 0
	local flowerDecal = Instance.new("Decal", flowerPart); flowerDecal.Transparency = 0
	local leafBurst = Instance.new("ParticleEmitter", flowerPart); leafBurst.Name = "LeafBurst"; leafBurst.Enabled = true

	local balloonsRoot = Instance.new("Folder", workspace); balloonsRoot.Name = "Balloons"
	local balloons = Instance.new("Folder", balloonsRoot); balloons.Name = "FieldBalloons"
	local balloon = Instance.new("Model", balloons); balloon.Name = "RedBalloon"
	local balloonPart = Instance.new("Part", balloon); balloonPart.Transparency = 0

	local bees = Instance.new("Folder", workspace); bees.Name = "Bees"
	local activeBee = Instance.new("Model", bees); activeBee.Name = "Tabby"
	local activeOwner = Instance.new("ObjectValue", activeBee); activeOwner.Name = "Owner"; activeOwner.Value = localPlayer
	local departedOwner = Instance.new("Player"); departedOwner.Parent = nil
	local staleBee = Instance.new("Model", bees); staleBee.Name = "StaleBee"
	local staleOwner = Instance.new("ObjectValue", staleBee); staleOwner.Name = "Owner"; staleOwner.Value = departedOwner

	-- Dead object release is a safe no-op
	local deadObj = Instance.new("Part")
	deadObj.Parent = nil
	visualOptimizer:Release(deadObj)

	-- Enable Ultra Anti-Lag
	ultraAntiLag:Set(true)
	assert(Lighting.GlobalShadows == false and Lighting.FogEnd >= 1e8, "Lighting not optimized")
	Lighting.GlobalShadows = true
	assert(Lighting.GlobalShadows == false, "Lighting.Changed lock did not enforce GlobalShadows=false")
	assert(postBloom.Enabled == false and atmosphere.Density == 0, "Lighting effects not disabled")
	assert(terrain.WaterWaveSize == 0 and terrain.Decoration == false and clouds.Enabled == false, "Terrain/Clouds not optimized")
	assert(renderSettings.QualityLevel == Enum.QualityLevel.Level01, "Rendering quality not Level01")
	assert(userGameSettings.SavedQualityLevel == Enum.SavedQualitySetting.QualityLevel1, "SavedQualityLevel not QualityLevel1")
	assert(popUpSetting == false, "PollenPopUps not disabled via PlayerSettingsEvent")

	-- Cosmetic containers detached; gameplay Collectibles/Particles/Flowers kept
	assert(fieldDecos.Parent == nil and fences.Parent == nil and caveDeco.Parent == nil, "Cosmetic folders not detached")
	assert(collectibles.Parent == workspace and liveToken.Parent == collectibles, "Collectibles was wrongly detached")
	assert(particlesFolder.Parent == workspace and warnDisk.Parent == particlesFolder, "WarningDisk touched by antilag")
	assert(pEmitter.Enabled == false, "Cosmetic particle emitter in Particles not disabled")
	assert(flowerPart.LocalTransparencyModifier == 1 and flowerDecal.Transparency == 1, "Flower visual not hidden")
	assert(leafBurst.Enabled == true, "Protected LeafBurst in Flowers was disabled")
	assert(balloonPart.LocalTransparencyModifier == 1, "FieldBalloon not hidden")
	assert(localAmuletPart.LocalTransparencyModifier == 1, "Local amulet visual not hidden")
	assert(rootPart.LocalTransparencyModifier == 0 and remoteRoot.Position.X == 25, "HRP altered by antilag")
	assert(remoteTorso.LocalTransparencyModifier == 1, "Remote character visual not hidden")
	assert(activeBee.Parent == nil and staleBee.Parent == nil, "Bees not detached")

	-- PruneBees drops departed owner's bee cleanly
	ultraAntiLag:PruneBees()
	assert(#ultraAntiLag.detachedBees == 1 and ultraAntiLag.detachedBees[1].inst == activeBee, "PruneBees did not prune departed bee")

	-- Wrapped gameApi modules block cosmetics & pass gameplay FX
	gameApi.CollectiblesAnimator.AnimateCollect()
	gameApi.LocalAmulets.CreatePlayerAmulets()
	assert(animCollectCalls == 0 and createAmuletCalls == 0, "AnimateCollect / CreatePlayerAmulets not suppressed")
	gameApi.LocalFXModule.ClientRun("AquaWave")
	gameApi.LocalFXModule.ClientRun("FallingCoconut")
	assert(#fxLog == 1 and fxLog[1] == "FallingCoconut", "LocalFX filter broke: got count=" .. tostring(#fxLog))

	-- Disable restores everything except pruned bee, and unwraps LocalFX
	ultraAntiLag:Set(false)
	assert(Lighting.GlobalShadows == true and Lighting.FogEnd == 500, "Lighting not restored")
	assert(postBloom.Enabled == true and atmosphere.Density == 0.4, "PostEffect/Atmosphere not restored")
	assert(terrain.WaterWaveSize == 0.2 and terrain.Decoration == true and clouds.Enabled == true, "Terrain not restored")
	assert(renderSettings.QualityLevel == Enum.QualityLevel.Automatic, "RenderQuality not restored")
	assert(popUpSetting == true, "PollenPopUps not restored")
	assert(fieldDecos.Parent == workspace and fences.Parent == mapFolder and caveDeco.Parent == decoFolder, "Cosmetic folders not restored")
	assert(activeBee.Parent == bees and staleBee.Parent == nil, "Pruned bee unexpectedly restored or active bee missing")
	assert(flowerPart.LocalTransparencyModifier == 0 and flowerDecal.Transparency == 0 and balloonPart.LocalTransparencyModifier == 0, "Hidden parts/decals not restored")
	gameApi.LocalFXModule.ClientRun("AquaWave")
	assert(#fxLog == 2 and fxLog[2] == "AquaWave", "LocalFX not unwrapped cleanly on disable")

	-- Clean up workspace artifacts from Section A
	for _, c in ipairs(workspace:GetChildren()) do
		if c ~= localChar and c ~= remoteChar and c ~= pepperFieldObj and c ~= terrain then c:Destroy() end
	end
	print("PASS: Section A (ultraAntiLag & visualOptimizer)")
end

-- =========================================================================
-- SECTION B: Digital Bee Duped Smiley Collection & ShouldPreempt Throttle
-- =========================================================================
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
	if self.smileyActive then return false end
	if self.precisionActive and active and active.rbc and self:PrecisionReady() and rbcSafety:BuffTarget(active) then return true end
	if self.precisionActive and cfg.autofarm.precisionupkeep~=false then return false end
	if self.upkeepToken and self.activeTarget == self.upkeepToken and cfg.autofarm.precisionupkeep~=false then
		return self:Precise(self:PrecisionOptions(self.activeOptions or {}), true) ~= nil
	end
	if bearCombat.active then return false end
	local now = os.clock()
	if self.nextPreemptCheck and now < self.nextPreemptCheck then return false end
	self.nextPreemptCheck = now + 0.08
	if not self.precisionActive and self.activeCategory~="Precise Targets" and self:PrecisionUpkeep(self.activeOptions or {}) then return true end
	if bearCombat:Pick(self.activeOptions or {}) then return true end
	if not self.bloomFocused and self.activeOptions and self:BloomTarget(self.activeOptions) then return true end
	if self.bloomFocused or not cfg.prioritization.enabled or not self.activeCategory then return false end
	return self:Pick(self.activeOptions or {}, self.activeCategory) ~= nil
end


do
	local farmFolder = { AddSlider = function() end }
				if cfg.autofarm.smileymigrated ~= true then
					if cfg.autofarm.smileytime == 4 then cfg.autofarm.smileytime = 1 end
					cfg.autofarm.smileymigrated = true
					saveConfig()
				end
	assert(cfg.autofarm.smileytime == 1 and cfg.autofarm.smileymigrated == true, "smileytime migration 4->1 failed")
	cfg.autofarm.smileytime = 0
	-- Second pass does not overwrite user value once migrated
	if cfg.autofarm.smileymigrated ~= true then cfg.autofarm.smileytime = 1 end
	assert(cfg.autofarm.smileytime == 0, "smileytime=0 overwritten after migration")

	local smToken = Instance.new("Part", workspace); smToken.Name = "Smiley"
	smToken.Position = Vector3.new(20, 4, 15) -- Y=4 low token while player root Y=14
	tracked.dupedsmiley[smToken] = smToken

		local function collectFastSmiley(object,opts)
			-- Smiley tokens need sustained contact: proximity alone is not collection.
			opts = opts or {}
			if fieldPositionPolicy and fieldPositionPolicy.ReleaseIdle then fieldPositionPolicy:ReleaseIdle() end
			if smoothMovement then smoothMovement.roam = nil end
			gatheringPriorities.smileyActive = true
			local deadline=os.clock()+math.min(4,distanceTo(object.Position,true)/math.max(1,getHumanoid().WalkSpeed)+.75)+6
			local nextMove=0
			while os.clock()<deadline do
				if showerController.active or state.stop or comboController.active then
					gatheringPriorities.smileyActive = false
					return true
				end
				if object.Name==true then
					if tracked.dupedsmiley[object.ID]~=object then
						gatheringPriorities.smileyActive = false
						return true
					end
				elseif not object.Parent then
					tracked.dupedsmiley[object]=nil
					gatheringPriorities.smileyActive = false
					return true
				end
				if dupedTokenPolicy and dupedTokenPolicy.Allowed and not dupedTokenPolicy:Allowed(object) then
					gatheringPriorities.smileyActive = false
					return true
				end
				local humanoid=getHumanoid()
				if humanoid.Health<=0 then
					gatheringPriorities.smileyActive = false
					return true
				end
				local root=getRootPart().Position
				local point=Vector3.new(object.Position.X,root.Y,object.Position.Z)
				local liveAvoid=opts.rbc and rbcSafety:Hazards(currentField) or opts.avoid
				if (liveAvoid and isPathClear(point,liveAvoid,false,opts.rbc)) or comboController:BlocksMove(point) then break end
				if os.clock()>=nextMove then
					humanoid:MoveTo(point)
					nextMove=os.clock()+.10
				end
				-- Keep this job owning movement while the server charges/collects it.
				RunService.Heartbeat:Wait()
			end
			gatheringPriorities.smileyActive = false
			touchedMarks[object]=os.clock()+.4
			return true
		end


	-- 1. ShouldPreempt blocks interruption during smileyActive and throttles PrecisionUpkeep at 0.08s
	gatheringPriorities.smileyActive = true
	gatheringPriorities.precisionCalls = 0
	assert(gatheringPriorities:ShouldPreempt() == false, "ShouldPreempt interrupted active smiley")
	assert(gatheringPriorities.precisionCalls == 0, "PrecisionUpkeep called while smileyActive")

	gatheringPriorities.smileyActive = false
	gatheringPriorities.nextPreemptCheck = nil
	gatheringPriorities:ShouldPreempt()
	assert(gatheringPriorities.precisionCalls == 1, "Initial ShouldPreempt did not check PrecisionUpkeep")
	now += 0.03
	gatheringPriorities:ShouldPreempt()
	assert(gatheringPriorities.precisionCalls == 1, "ShouldPreempt did not throttle PrecisionUpkeep under 0.08s")
	now += 0.06
	gatheringPriorities:ShouldPreempt()
	assert(gatheringPriorities.precisionCalls == 2, "ShouldPreempt failed to re-check PrecisionUpkeep after 0.08s")

	-- 2. pickTarget prioritizes Duped Smiley before BloomTarget even with blooms present
	local pickTarget
	local pickRbcPrecision = function() return nil end
	gatheringPriorities.BloomTarget = function() return "DummyBloom" end
	gatheringPriorities.BloomFocus = function() return "Bloom" end
	do
		pickTarget = function(opts)
			gatheringPriorities.bloomFocused = false
			if fieldPositionPolicy:SmileyOnly() then
				opts.area=fieldPositionPolicy:StrictArea() or opts.area
				return gatheringPriorities:Candidate("Duped Smiley",opts,getRootPart().Position)
			end
			opts.area=fieldPositionPolicy:StrictArea() or opts.area
			if showerController.active then return "Safeshower" end
			local urgentKind,urgentTarget=pickRbcPrecision(opts)
			if urgentTarget then return urgentKind,urgentTarget end
			if opts.rbc and gatheringPriorities:PrecisionReady() then
				local buffKind,buffObject=rbcSafety:BuffTarget(opts)
				if buffKind then gatheringPriorities.last="RBC Buff Upkeep";return buffKind,buffObject end
			end
			local precisionKind,precisionObject=gatheringPriorities:PrecisionUpkeep(opts)
			if precisionKind then gatheringPriorities.last="Precise Targets";return precisionKind,precisionObject end
			local buffKind,buffObject=rbcSafety:BuffTarget(opts)
			if buffKind then gatheringPriorities.last="RBC Buff Upkeep";return buffKind,buffObject end
			local combatKind, combatObject = bearCombat:Pick(opts)
			bearCombat.active = combatKind ~= nil
            if combatKind then
                gatheringPriorities.last = combatKind == "Token" and "Priority Tokens" or combatKind == "Duped Bear" and "Duped Bear" or "Duped Tokens"
                return combatKind, combatObject
            end
			if opts.mondotokens then
				if cfg.prioritization.enabled then return gatheringPriorities:Pick(opts) end
				local root = getRootPart().Position
				for _, category in ipairs({"Token Links", "Priority Tokens", "Duped Smiley", "Duped Bear", "Duped Tokens", "Tokens"}) do
					local kind, object = gatheringPriorities:Candidate(category, opts, root)
					if kind then return kind, object end
				end
				return
			end
			if not opts.loot and not opts.mondotokens and (cfg.autofarm.farmdupedtokens or opts.dupedtokensquest) then
				local smileyKind, smileyObj = gatheringPriorities:Candidate("Duped Smiley", opts, getRootPart().Position)
				if smileyKind then
					gatheringPriorities.last = "Duped Smiley"
					if gatheringPriorities.currentLabel then gatheringPriorities.currentLabel.Text = "Current target: Duped Smiley" end
					return smileyKind, smileyObj
				end
			end
			return nil
		end
	end
	local pickedKind, pickedObj = pickTarget({ rbc = false })
	assert(pickedKind == "Duped Smiley" and pickedObj == smToken, "pickTarget prioritized Bloom over Duped Smiley")

	-- 3. collectFastSmiley walks with grounded Y=root.Y, re-issues MoveTo every 0.10s, and resets smileyActive cleanly
	local co = coroutine.create(function()
		return collectFastSmiley(smToken, {})
	end)
	local okCo, errCo = coroutine.resume(co)
	assert(okCo, errCo)
	assert(gatheringPriorities.smileyActive == true, "collectFastSmiley did not activate smileyActive")
	assert(fieldPositionPolicy.idleReleased >= 1 and smoothMovement.roam == nil, "collectFastSmiley did not release idle/roam")
	assert(hum.lastMoveTo and hum.lastMoveTo.X == 20 and hum.lastMoveTo.Y == rootPart.Position.Y and hum.lastMoveTo.Z == 15, "collectFastSmiley did not project grounded Y")
	assert(hum.moveCount == 1, "expected 1 MoveTo on start")

	now += 0.05
	RunService.Heartbeat:Fire(0.05)
	assert(hum.moveCount == 1, "collectFastSmiley spammed MoveTo before 0.10s")

	now += 0.06
	RunService.Heartbeat:Fire(0.06)
	assert(hum.moveCount == 2, "collectFastSmiley did not re-issue MoveTo after 0.10s")

	-- Preemption on collection (object.Parent = nil)
	smToken.Parent = nil
	now += 0.05
	RunService.Heartbeat:Fire(0.05)
	assert(coroutine.status(co) == "dead" and gatheringPriorities.smileyActive == false, "collectFastSmiley did not clean up smileyActive on collect")

	print("PASS: Section B (Duped Smiley migration, Bloom bypass, grounded Y, uninterrupted collectFastSmiley, ShouldPreempt throttle)")
end

-- =========================================================================
-- SECTION C: Optimal Flame Refreshing (flameController + migration UI)
-- =========================================================================
		do
			local FLAME_RENDER_STEP_NAME = "AtlasOptimalFlameFace_" .. tostring(localPlayer and localPlayer.UserId or 0)
			flameController = {
				meta = setmetatable({}, { __mode = "k" }),
				gyro = nil,
				managedHumanoid = nil,
				savedAutoRotate = nil,
				renderBound = false,
				stopDig = false,
				ownedStopDig = false,
				facingActive = false,
				cachedField = nil,
				cachedFieldPos = nil,
				cachedFieldTime = 0,
				currentTarget = nil,
				lastScanTime = 0,
				cachedStopDig = false,
				cachedModeLabel = "idle",
				observedNormalLife = nil,
				observedFuelLife = nil,
				lastFuelCheck = 0,
				cachedFuelActive = false,
			}

			local function isFlameShiftLockActive()
				if cfg and cfg.face and cfg.face.shiftlock then return true end
				local locked = false
				pcall(function()
					if UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter then
						locked = true
					end
				end)
				if not locked and UserInputService and UserInputService.MouseIcon == "rbxasset://textures/MouseLockedCursor.png" then
					locked = true
				end
				return locked
			end

			local function isHumanoidClimbing(hum)
				if not hum then return false end
				local ok, st = pcall(function() return hum:GetState() end)
				return ok and st == Enum.HumanoidStateType.Climbing
			end

			function flameController:InvalidateTarget()
				self.currentTarget = nil
				self.lastScanTime = 0
			end

			function flameController:ReleaseOwnedStopDig()
				self.stopDig = false
				if self.ownedStopDig and state then
					self.ownedStopDig = false
					state.stopdig = nil
				end
			end

			function flameController:IsFlameFuelActive(now)
				if buffs and buffs["Flame Fuel"] then
					return true
				end
				local currentClock = now or os.clock()
				if currentClock - (self.lastFuelCheck or 0) < 0.25 then
					return self.cachedFuelActive == true
				end
				self.lastFuelCheck = currentClock
				local active = false
				if gameApi and gameApi.BuffTile and secureCall then
					local ok, tile = pcall(secureCall, gameApi.BuffTile, "Flame Fuel")
					if ok and type(tile) == "table" and ((type(tile.TimerStart) == "number" and type(tile.TimerDur) == "number" and (tile.TimerStart + tile.TimerDur) > os.time()) or tile.Percent or tile.Stack) then
						active = true
					end
				end
				self.cachedFuelActive = active
				return active
			end

			function flameController:GetEffectiveRefreshAge(now)
				local fuelOn = self:IsFlameFuelActive(now)
				return fuelOn and 6.2 or 4.2, fuelOn
			end

			function flameController:ObserveAdded(child, now, existing)
				if not child then return end
				local rec = self.meta[child]
				if not rec then
					self.meta[child] = {
						spawnTime = (not existing) and (now or os.clock()) or false,
						fuelAtSpawn = self:IsFlameFuelActive(now),
						wasDark = false,
					}
				end
			end

			function flameController:ObserveRemoved(child)
				local rec = self.meta[child]
				if rec and not rec.wasDark and type(rec.spawnTime) == "number" then
					local life = os.clock() - rec.spawnTime
					if life >= 3.0 and life <= 11.0 then
						if rec.fuelAtSpawn then
							self.observedFuelLife = self.observedFuelLife and (self.observedFuelLife * 0.7 + life * 0.3) or life
						else
							self.observedNormalLife = self.observedNormalLife and (self.observedNormalLife * 0.7 + life * 0.3) or life
						end
					end
				end
				if self.currentTarget and self.currentTarget.obj == child then
					self:InvalidateTarget()
				end
				self.meta[child] = nil
			end

			function flameController:GetCachedField(rootPos, now)
				if self.cachedField and self.cachedField.Parent and self.cachedFieldPos and (now - self.cachedFieldTime) < 0.1 then
					local dx = rootPos.X - self.cachedFieldPos.X
					local dy = rootPos.Y - self.cachedFieldPos.Y
					local dz = rootPos.Z - self.cachedFieldPos.Z
					if dx * dx + dy * dy + dz * dz < 9 then
						return self.cachedField
					end
				end
				local field = getFieldAt(rootPos)
				self.cachedField = field
				self.cachedFieldPos = rootPos
				self.cachedFieldTime = now
				return field
			end

			function flameController:SuppressAutoRotate(hum)
				if not hum then return end
				if self.managedHumanoid and self.managedHumanoid ~= hum then
					self:RestoreAutoRotate()
				end
				if self.managedHumanoid ~= hum then
					local okRead, orig = pcall(function() return hum.AutoRotate end)
					self.savedAutoRotate = (okRead and type(orig) == "boolean") and orig or true
					self.managedHumanoid = hum
				end
				pcall(function() hum.AutoRotate = false end)
			end

			function flameController:RestoreAutoRotate()
				local hum = self.managedHumanoid
				local saved = self.savedAutoRotate
				self.managedHumanoid = nil
				self.savedAutoRotate = nil
				if hum and hum.Parent and saved ~= nil then
					pcall(function() hum.AutoRotate = saved end)
				end
			end

			function flameController:EnsureGyro(rootPart)
				if self.gyro and self.gyro.Parent ~= rootPart then
					pcall(function() self.gyro:Destroy() end)
					self.gyro = nil
				end
				if not self.gyro and rootPart then
					local okGyro, created = pcall(function()
						local g = Instance.new("BodyGyro")
						g.Name = "AtlasFlameGyro"
						g.P = 20000
						g.D = 400
						g.MaxTorque = Vector3.new(0, 0, 0)
						g.Parent = rootPart
						return g
					end)
					if okGyro then
						self.gyro = created
					end
				end
				return self.gyro
			end

			function flameController:ZeroTorque()
				self.facingActive = false
				self:RestoreAutoRotate()
				if self.gyro then
					pcall(function() self.gyro.MaxTorque = Vector3.new(0, 0, 0) end)
				end
			end

			function flameController:ReleaseGyro()
				self.facingActive = false
				self:RestoreAutoRotate()
				if self.gyro then
					pcall(function()
						self.gyro.MaxTorque = Vector3.new(0, 0, 0)
						self.gyro:Destroy()
					end)
					self.gyro = nil
				end
			end

			function flameController:UnbindRenderStep()
				connections:Cancel("optimalFlameFace")
				if self.renderBound and RunService and RunService.UnbindFromRenderStep then
					pcall(function() RunService:UnbindFromRenderStep(FLAME_RENDER_STEP_NAME) end)
					self.renderBound = false
				end
			end

			function flameController:InspectFlame(key, value, now, estTotalLife)
				local isVirtual = type(value) == "table"
				local flameObj = isVirtual and value or key
				if not flameObj then return nil end
				if isVirtual then
					if flameObj.Dark or type(flameObj.Size) ~= "number" or flameObj.Size <= 1.4 then return nil end
					local pos = flameObj.Position
					if typeof(pos) ~= "Vector3" then return nil end
					local record = self.meta[flameObj]
					if not record then
						record = {}
						self.meta[flameObj] = record
					end
					if not record.fieldPos or math.abs(pos.X - record.fieldPos.X) > 2 or math.abs(pos.Z - record.fieldPos.Z) > 2 or (record.field and not record.field.Parent) then
						record.field = getFieldAt(pos)
						record.fieldPos = pos
					end
					local totalSpan = estTotalLife or 6
					local age
					if type(flameObj.SpawnTime) == "number" then
						age = math.max(0, now - flameObj.SpawnTime)
					elseif type(flameObj.ExpiresAt) == "number" then
						age = math.max(0, totalSpan - math.max(0, flameObj.ExpiresAt - now))
					else
						age = math.max(0, totalSpan - math.max(1, tonumber(flameObj.T) or totalSpan))
					end
					return pos, age, record.field, flameObj
				end

				if typeof(flameObj) == "Instance" and not flameObj.Parent then
					return nil
				end
				local okPos, pos = pcall(function() return flameObj.Position end)
				if not okPos or typeof(pos) ~= "Vector3" then return nil end
				local record = self.meta[flameObj]
				if not record then
					record = { spawnTime = type(value) == "number" and value or false, wasDark = false }
					self.meta[flameObj] = record
				elseif record.spawnTime == nil and type(value) == "number" then
					record.spawnTime = value
				end
				local pf = record.pf
				if not (pf and pf.Parent) then
					pf = flameObj.FindFirstChild and flameObj:FindFirstChild("PF") or nil
					record.pf = pf
				end
				if not pf then return nil end
				local okValid, sizeVal = pcall(function()
					local s = pf.Size.Keypoints[1].Value
					local g = pf.Color.Keypoints[1].Value.G
					if g <= 0.2 then
						record.wasDark = true
						return nil
					end
					if s <= 1.4 then
						return nil
					end
					return s
				end)
				if not okValid or not sizeVal then
					return nil
				end
				if not record.fieldPos or math.abs(pos.X - record.fieldPos.X) > 2 or math.abs(pos.Z - record.fieldPos.Z) > 2 or (record.field and not record.field.Parent) then
					record.field = getFieldAt(pos)
					record.fieldPos = pos
				end
				local age
				if type(record.spawnTime) == "number" then
					age = math.max(0, now - record.spawnTime)
				else
					local totalSpan = estTotalLife or 6
					local estRem = 1 + math.clamp((sizeVal - 1.4) / 0.35, 0, 1) * (totalSpan - 1)
					age = math.max(0, totalSpan - estRem)
				end
				return pos, age, record.field, flameObj
			end

			function flameController:SelectTarget(rootPos, field, now)
				if not rootPos or not field or not tracked or not tracked.flames then
					return nil, false, "idle"
				end
				local maxRange = 30
				local refreshAge, fuelOn = self:GetEffectiveRefreshAge(now)
				local estTotalLife = fuelOn and (self.observedFuelLife or 7.0) or (self.observedNormalLife or 5.0)
				local hasFreshInRange = false
				local bestReady = nil
				local bestFallback = nil
				local stale = nil

				for key, value in pairs(tracked.flames) do
					if type(value) ~= "table" and typeof(key) == "Instance" and not key.Parent then
						stale = stale or {}
						stale[#stale + 1] = key
					else
						local pos, age, flameField, flameObj = self:InspectFlame(key, value, now, estTotalLife)
						if pos and flameField == field then
							local dx = pos.X - rootPos.X
							local dz = pos.Z - rootPos.Z
							local dist = math.sqrt(dx * dx + dz * dz)
							if dist < maxRange then
								if age < refreshAge then
									hasFreshInRange = true
								end
								if dist > 4 then
									if age >= refreshAge then
										if not bestReady or age > bestReady.age + 0.15 or (math.abs(age - bestReady.age) <= 0.15 and dist < bestReady.dist) then
											bestReady = { key = key, obj = flameObj, pos = pos, age = age, dist = dist }
										end
									end
									if not bestFallback or dist < bestFallback.dist then
										bestFallback = { key = key, obj = flameObj, pos = pos, age = age, dist = dist }
									end
								end
							end
						end
					end
				end

				if stale then
					for _, k in ipairs(stale) do
						self.meta[k] = nil
						tracked.flames[k] = nil
					end
				end

				if bestReady then
					return bestReady, false, "refresh"
				end
				return bestFallback, hasFreshInRange, bestFallback and "face" or "idle"
			end

			function flameController:Step(now)
				if not cfg or not cfg.face or not cfg.face.optimalflames then
					self:ReleaseGyro()
					self:InvalidateTarget()
					self:ReleaseOwnedStopDig()
					return
				end
				if not cfg.autofarm or not cfg.autofarm.enabled or not state or state.stop or state.stopface
					or (state.activityStatus ~= nil and state.activityStatus ~= 1)
					or (comboController and comboController.active)
					or (showerController and showerController.active)
					or (mondoHop and mondoHop.active) then
					self:ZeroTorque()
					self:InvalidateTarget()
					self:ReleaseOwnedStopDig()
					return
				end

				local rootPart = getRootPart()
				local hum = getHumanoid()
				if not rootPart or not hum or (typeof(hum) == "Instance" and not hum.Parent) or hum.Health <= 0 then
					self:ZeroTorque()
					self:InvalidateTarget()
					self:ReleaseOwnedStopDig()
					return
				end

				local currentClock = now or os.clock()
				local okRoot, rootPos = pcall(function() return rootPart.Position end)
				if not okRoot or typeof(rootPos) ~= "Vector3" then
					self:ZeroTorque()
					self:InvalidateTarget()
					self:ReleaseOwnedStopDig()
					return
				end
				local field = self:GetCachedField(rootPos, currentClock)
				if not field then
					self:ZeroTorque()
					self:InvalidateTarget()
					self:ReleaseOwnedStopDig()
					return
				end

				local targetEntry = self.currentTarget
				local stopDig = self.cachedStopDig
				local modeLabel = self.cachedModeLabel
				local useCached = false
				local refreshAge, fuelOn = self:GetEffectiveRefreshAge(currentClock)
				local estTotalLife = fuelOn and (self.observedFuelLife or 7.0) or (self.observedNormalLife or 5.0)

				if targetEntry and targetEntry.key and tracked.flames[targetEntry.key] ~= nil and (currentClock - self.lastScanTime) < 0.05 then
					local pos, age, flameField = self:InspectFlame(targetEntry.key, tracked.flames[targetEntry.key], currentClock, estTotalLife)
					if pos and flameField == field then
						local dx = pos.X - rootPos.X
						local dz = pos.Z - rootPos.Z
						local dist = math.sqrt(dx * dx + dz * dz)
						if dist > 4 and dist < 30 and not (modeLabel == "face" and age >= refreshAge) then
							targetEntry.pos = pos
							targetEntry.age = age
							targetEntry.dist = dist
							useCached = true
						end
					end
				end

				if not useCached then
					targetEntry, stopDig, modeLabel = self:SelectTarget(rootPos, field, currentClock)
					self.currentTarget = targetEntry
					self.cachedStopDig = stopDig == true
					self.cachedModeLabel = modeLabel
					self.lastScanTime = currentClock
				end

				self.stopDig = (stopDig == true)
				if self.stopDig then
					self.ownedStopDig = true
					state.stopdig = true
				elseif self.ownedStopDig then
					self.ownedStopDig = false
					state.stopdig = nil
				end

				if not targetEntry or not targetEntry.pos then
					self:ZeroTorque()
					return
				end

				local flatTarget = Vector3.new(targetEntry.pos.X, rootPos.Y, targetEntry.pos.Z)
				local flatDx = flatTarget.X - rootPos.X
				local flatDz = flatTarget.Z - rootPos.Z
				if flatDx * flatDx + flatDz * flatDz < 0.0025 then
					self:ZeroTorque()
					return
				end

				local gyro = self:EnsureGyro(rootPart)
				if not gyro then
					self.facingActive = false
					self:RestoreAutoRotate()
					return
				end

				local lookCf = CFrame.new(rootPos, flatTarget)
				self.facingActive = true
				self:SuppressAutoRotate(hum)
				pcall(function()
					gyro.MaxTorque = Vector3.new(0, math.huge, 0)
					gyro.CFrame = lookCf
				end)
				if isFlameShiftLockActive() and not isHumanoidClimbing(hum) then
					pcall(function() rootPart.CFrame = lookCf end)
				end
			end

			function flameController:SetEnabled(enabled)
				self:UnbindRenderStep()
				self:InvalidateTarget()
				if not enabled then
					self:ReleaseOwnedStopDig()
					self:ReleaseGyro()
					return
				end
				self:Step(os.clock())
				if RunService and RunService.BindToRenderStep then
					local okPrio, camPrio = pcall(function() return Enum.RenderPriority.Camera.Value end)
					local priority = (okPrio and type(camPrio) == "number") and (camPrio + 1) or 201
					local okBind = pcall(function()
						RunService:BindToRenderStep(FLAME_RENDER_STEP_NAME, priority, function()
							self:Step(os.clock())
						end)
					end)
					if okBind then
						self.renderBound = true
						return
					end
				end
				local sig = RunService and (RunService.RenderStepped or RunService.Heartbeat)
				if sig then
					connections:Add("optimalFlameFace", sig:Connect(function()
						self:Step(os.clock())
					end))
				end
			end

			function flameController:Shutdown()
				self:UnbindRenderStep()
				self:InvalidateTarget()
				self:ReleaseOwnedStopDig()
				self:ReleaseGyro()
				table.clear(self.meta)
				self.cachedField = nil
				self.cachedFieldPos = nil
			end
		end


do
	local addedSwitches = {}
	local faceFolder = {
		AddSwitch = function(name, cb, cat, key, opts)
			addedSwitches[#addedSwitches + 1] = { name = name, cb = cb, cat = cat, key = key, opts = opts }
		end,
	}
	local function watchFlames() end

			if cfg.face.flamemigrated ~= true then
				if cfg.face.fires == true or cfg.face.refresh == true then
					cfg.face.optimalflames = true
				end
				cfg.face.fires = false
				cfg.face.refresh = false
				cfg.face.flamemigrated = true
				saveConfig()
			end

			faceFolder.AddSwitch("Optimal Flame Refreshing", function(enabled)
				watchFlames(enabled)
				if flameController and flameController.SetEnabled then
					flameController:SetEnabled(enabled)
				end
			end, "face", "optimalflames", { Tooltip = "Faces and refreshes expiring flames at optimal age (4.2s normal / 6.2s with Flame Fuel) using high-torque BodyGyro + Auto-Dig refresh sync." })

	assert(cfg.face.optimalflames == true and cfg.face.fires == false and cfg.face.refresh == false and cfg.face.flamemigrated == true, "face migration failed")
	assert(#addedSwitches == 1 and addedSwitches[1].name == "Optimal Flame Refreshing" and addedSwitches[1].cat == "face" and addedSwitches[1].key == "optimalflames", "Optimal Flame Refreshing UI registration mismatch")

	-- Refresh age normal (4.2s) vs Flame Fuel (6.2s)
	buffs["Flame Fuel"] = nil
	local rNormal, fuelOff = flameController:GetEffectiveRefreshAge(now)
	assert(math.abs(rNormal - 4.2) < 1e-6 and fuelOff == false, "Normal refresh age should be 4.2")
	buffs["Flame Fuel"] = true
	now += 0.5
	local rFuel, fuelOn = flameController:GetEffectiveRefreshAge(now)
	assert(math.abs(rFuel - 6.2) < 1e-6 and fuelOn == true, "Flame Fuel refresh age should be 6.2")
	buffs["Flame Fuel"] = nil

	-- Create flames in workspace (for inspect & tracking)
	local function makeFlame(pos, gColor, sizeVal, spawnClock)
		local fl = Instance.new("Part", workspace); fl.Name = "FlamePart"; fl.Position = pos
		local pf = Instance.new("ParticleEmitter", fl); pf.Name = "PF"
		pf.Color = ColorSequence.new(Color3.new(1, gColor, 0))
		pf.Size = NumberSequence.new(sizeVal)
		tracked.flames[fl] = spawnClock
		flameController:ObserveAdded(fl, spawnClock, false)
		return fl
	end

	rootPart.Position = Vector3.new(0, 14, 0)
	local tooClose = makeFlame(Vector3.new(3, 14, 0), 0.8, 2.0, now - 4.5) -- <= 4 studs, ignored
	local tooFar = makeFlame(Vector3.new(35, 14, 0), 0.8, 2.0, now - 4.5) -- >= 30 studs, ignored
	local darkFlame = makeFlame(Vector3.new(12, 14, 0), 0.15, 2.0, now - 4.5) -- G<=0.2 dark, ignored
	local freshFlame = makeFlame(Vector3.new(0, 14, -15), 0.8, 2.0, now - 1.0) -- age 1.0 < 4.2 -> stopdig=true

	flameController:SetEnabled(true)
	assert(state.stopdig == true, "Fresh flame did not set state.stopdig = true")
	assert(flameController.facingActive == true and hum.AutoRotate == false, "Did not activate BodyGyro facing or suppress AutoRotate")
	local gyro = rootPart:FindFirstChildOfClass("BodyGyro")
	assert(gyro and gyro.P == 20000 and gyro.D == 400 and gyro.MaxTorque.Y == math.huge, "BodyGyro parameters mismatch")

	-- Flame expires to >= 4.2s -> stopdig released to nil so Auto-Dig refreshes it, and selects oldest-expiring flame
	now += 3.5 -- freshFlame age = 4.5s (>= 4.2)
	local olderFlame = makeFlame(Vector3.new(18, 14, 0), 0.8, 2.0, now - 5.1) -- age 5.1 > 4.5
	flameController:Step(now)
	assert(state.stopdig == nil, "Ready flame did not clear state.stopdig for refresh")
	assert(flameController.currentTarget and flameController.currentTarget.obj == olderFlame, "Did not prioritize oldest-expiring ready flame")

	-- Shift Lock rotates rootPart.CFrame when not climbing, skips when climbing
	cfg.face.shiftlock = true
	local origCf = CFrame.new(rootPart.Position, Vector3.new(0, 14, 10))
	rootPart.CFrame = origCf
	hum.humState = Enum.HumanoidStateType.Climbing
	flameController:Step(now + 0.06)
	assert(rootPart.CFrame == origCf, "Shift Lock overwrote rootPart.CFrame while climbing")
	hum.humState = Enum.HumanoidStateType.Running
	flameController:Step(now + 0.12)
	assert(rootPart.CFrame ~= origCf, "Shift Lock did not rotate rootPart.CFrame when standing")
	cfg.face.shiftlock = false

	-- ObserveRemoved EMA update for flame lifespan within [3, 11]s
	local emaFlame = makeFlame(Vector3.new(-10, 14, 0), 0.8, 2.0, now)
	now += 5.0
	flameController:ObserveRemoved(emaFlame)
	assert(flameController.observedNormalLife and math.abs(flameController.observedNormalLife - 5.0) < 0.01, "ObserveRemoved did not record normal flame lifespan EMA")

	-- Shutdown restores AutoRotate, releases gyro, clears stopdig, unbinds RenderStep
	flameController:Shutdown()
	assert(hum.AutoRotate == true and state.stopdig == nil, "Shutdown did not restore AutoRotate/stopdig")
	assert(not rootPart:FindFirstChildOfClass("BodyGyro"), "Shutdown did not destroy BodyGyro")
	assert(next(RunService.bound) == nil, "Shutdown did not unbind RenderStep")

	-- Dark & far/close flames don't activate stopdig on re-enable
	tracked.flames[freshFlame] = nil
	tracked.flames[olderFlame] = nil
	tracked.flames[emaFlame] = nil
	emaFlame:Destroy()
	flameController:SetEnabled(true)
	assert(state.stopdig == nil and not flameController.facingActive, "Dark/out-of-range flames should not engage facing")
	flameController:SetEnabled(false)
	assert(hum.AutoRotate == true, "SetEnabled(false) did not restore AutoRotate")

	print("PASS: Section C (Optimal Flame Refreshing, Flame Fuel 6.2s, dark/range exclusion, AutoRotate, Shift Lock, EMA, Shutdown)")
end

print("PASS: All FPS, Anti-Lag, Duped Smiley, Flame Refreshing, and Source Invariant checks passed!")
