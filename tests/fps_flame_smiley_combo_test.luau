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
local LIGHT_CLASSES = { Light = true, PointLight = true, SpotLight = true, SurfaceLight = true }

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
	if cls == "Light" and LIGHT_CLASSES[self.ClassName] then return true end
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
local remoteHum = Instance.new("Humanoid", remoteChar); remoteHum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
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

local StarterGui = { states = { PlayerList = true, Chat = true, EmotesMenu = true } }
function StarterGui:GetCoreGuiEnabled(t) return self.states[t] end
function StarterGui:SetCoreGuiEnabled(t, v) self.states[t] = v end

local game = Instance.new("DataModel"); game.Name = "Game"
local services = { Lighting = Lighting, Workspace = workspace, Players = Players, RunService = RunService, UserInputService = UserInputService, StarterGui = StarterGui }
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
	maxAlt = false,
	savedProps = {},
	savedEnvProps = {},
	savedTransientProps = setmetatable({}, { __mode = "k" }),
	savedParticleFX = setmetatable({}, { __mode = "k" }),
	detached = {},
	detachedSet = {},
	detachedBees = {},
	detachedBeeSet = {},
	playerConns = {},
	playerChars = {},
	wrapped = {},
	maxAltHooks = {},
	maxAltPlayerConns = {},
	maxAltPlayerChars = {},
	savedLighting = nil,
	savedTerrain = nil,
	savedQuality = nil,
	savedRenderQuality = nil,
	savedPollenPopUp = nil,
	pollenPopUpChanged = false,
	savedCoreGui = nil,
	savedChatCoreGui = nil,
}

do
	local function readProp(o, p) return o[p] end
	local function writeProp(o, p, v) o[p] = v end
	local function setParent(o, p) o.Parent = p end
	local function clearFX(o) o:Clear() end
	local function rawDestroy(o) o:Destroy() end
	local function destroyInst(o)
		if o and pcall(readProp, o, "Parent") and o.Parent then
			pcall(rawDestroy, o)
		end
	end
	local function isBloomParticle(desc)
		local cur = desc
		while cur and cur ~= workspace do
			local n = cur.Name
			if n == "PetalPart" or n == "PoppablePlants" or (type(n) == "string" and string.find(n, "Bloom", 1, true) ~= nil) then
				return true
			end
			cur = cur.Parent
		end
		return false
	end

	local MAX_ALT_DESTROY_TOP = {
		"Amulets", "Shell Amulets", "Stickbug Amulets", "BallArrowFolder", "BoostBalls",
		"Campsite", "ClassicMinigame", "Cubs", "Faces", "FieldDecos", "Frame", "Frogs",
		"Goo", "Paths", "Invisible Walls", "Leaderboards", "Territories", "TheGamesEvent",
		"TheGames_WideBanners", "Bee Bear Hive", "Noob Bear", "OnettNPC", "Pro Bear",
		"Top Bear", "BuckoAtHQ", "RileyAtHQ", "Honey", "Lion",
	}
	local MAX_ALT_DESTROY_TOP_SET = {}
	for _, n in ipairs(MAX_ALT_DESTROY_TOP) do MAX_ALT_DESTROY_TOP_SET[n] = true end

	function ultraAntiLag:Remember(tbl, object, property, value)
		local ok, previous = pcall(readProp, object, property)
		if not ok or previous == value then return end
		local saved = tbl[object]
		if not saved then saved = {}; tbl[object] = saved end
		if saved[property] == nil then saved[property] = previous end
		pcall(writeProp, object, property, value)
	end

	function ultraAntiLag:RestoreTable(tbl)
		for object, properties in pairs(tbl) do
			if object and (typeof(object) ~= "Instance" or object.Parent) then
				for property, value in pairs(properties) do
					pcall(writeProp, object, property, value)
				end
			end
		end
		table.clear(tbl)
	end

	function ultraAntiLag:Detach(inst, list, set)
		if not inst or set[inst] then return end
		local okParent, origParent = pcall(readProp, inst, "Parent")
		if not okParent or not origParent then return end
		set[inst] = true
		list[#list + 1] = { inst = inst, parent = origParent }
		pcall(setParent, inst, nil)
	end

	function ultraAntiLag:RestoreList(list, set)
		for i = #list, 1, -1 do
			local entry = list[i]
			if entry.inst and entry.parent and (typeof(entry.parent) ~= "Instance" or entry.parent.Parent) then
				pcall(setParent, entry.inst, entry.parent)
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
			local okMat, mat = pcall(readProp, object, "Material")
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
				if object:IsA("ParticleEmitter") or object:IsA("Trail") then pcall(clearFX, object) end
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
		if not self.enabled or not desc or not desc.Parent or isBloomParticle(desc) then return end
		if desc:IsA("ParticleEmitter") or desc:IsA("Trail") or desc:IsA("Beam") or desc:IsA("Light") or desc:IsA("Fire") or desc:IsA("Smoke") then
			if self.savedParticleFX[desc] == nil then
				local ok, wasOn = pcall(readProp, desc, "Enabled")
				if ok then self.savedParticleFX[desc] = wasOn end
			end
			pcall(writeProp, desc, "Enabled", false)
			if desc:IsA("ParticleEmitter") or desc:IsA("Trail") then pcall(clearFX, desc) end
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
			elseif d:IsA("Humanoid") then
				self:Remember(self.savedTransientProps, d, "DisplayDistanceType", Enum.HumanoidDisplayDistanceType.None)
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
		local okSet = pcall(writeProp, tbl, methodName, wrapper)
		if okSet then
			self.wrapped[key] = { tbl = tbl, method = methodName, orig = orig, wrapper = wrapper }
		end
	end

	function ultraAntiLag:UnwrapAll()
		for key, rec in pairs(self.wrapped) do
			if rec.tbl and rec.tbl[rec.method] == rec.wrapper then
				pcall(writeProp, rec.tbl, rec.method, rec.orig)
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

	function ultraAntiLag:PruneTransient()
		for inst in pairs(self.savedTransientProps) do
			if typeof(inst) == "Instance" and not inst.Parent then
				self.savedTransientProps[inst] = nil
			end
		end
		for inst in pairs(self.savedParticleFX) do
			if typeof(inst) == "Instance" and not inst.Parent then
				self.savedParticleFX[inst] = nil
			end
		end
	end

	function ultraAntiLag:ApplyEnv()
		if not self.savedQuality then
			pcall(function()
				local gameSettings = UserSettings():GetService("UserGameSettings")
				self.savedQuality = gameSettings.SavedQualityLevel
				gameSettings.SavedQualityLevel = Enum.SavedQualitySetting.QualityLevel1
			end)
		end
		if not self.savedRenderQuality then
			pcall(function()
				local renderSettings = settings().Rendering
				self.savedRenderQuality = renderSettings.QualityLevel
				renderSettings.QualityLevel = Enum.QualityLevel.Level01
			end)
		end
		if Lighting and not self.savedLighting then
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
					self:Remember(self.savedEnvProps, eff, "Enabled", false)
				elseif eff:IsA("Atmosphere") then
					self:Remember(self.savedEnvProps, eff, "Density", 0)
				end
			end
			if Lighting.Changed and not connections:Get("ultraAntiLagLighting") then
				connections:Add("ultraAntiLagLighting", Lighting.Changed:Connect(function(prop)
					if not self.enabled and not self.maxAlt then return end
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
		if not self.savedTerrain then
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
					if child:IsA("Clouds") then self:Remember(self.savedEnvProps, child, "Enabled", false) end
				end
			end
		end
		if StarterGui and not self.savedCoreGui then
			local savedCore = {}
			for _, name in ipairs({ "PlayerList", "EmotesMenu" }) do
				local coreType = Enum.CoreGuiType[name]
				local okGet, wasOn = pcall(function() return StarterGui:GetCoreGuiEnabled(coreType) end)
				if okGet and wasOn then
					savedCore[name] = true
					pcall(function() StarterGui:SetCoreGuiEnabled(coreType, false) end)
				end
			end
			self.savedCoreGui = savedCore
		end
		if not self.pollenPopUpChanged and gameApi.PlayerSettingsEvent and gameApi.ClientStatCache then
			local okPop, curPopUp = pcall(function() return gameApi:Cache({ "Settings", "PollenPopUps" }) end)
			if okPop and curPopUp ~= false then
				self.savedPollenPopUp = (curPopUp == nil and true or curPopUp)
				self.pollenPopUpChanged = true
				pcall(secureCall, gameApi.PlayerSettingsEvent.FireServer, gameApi.PlayerSettingsEvent, "PollenPopUps", false)
			end
		end
	end

	function ultraAntiLag:RestoreEnv()
		if self.enabled or self.maxAlt then return end
		connections:Cancel("ultraAntiLagLighting")
		self:RestoreTable(self.savedEnvProps)
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
		if self.savedCoreGui and StarterGui then
			for name in pairs(self.savedCoreGui) do
				pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType[name], true) end)
			end
		end
		self.savedCoreGui = nil
		if self.pollenPopUpChanged then
			local prevPopUp = self.savedPollenPopUp ~= false
			self.pollenPopUpChanged = false
			self.savedPollenPopUp = nil
			if gameApi.PlayerSettingsEvent then
				pcall(secureCall, gameApi.PlayerSettingsEvent.FireServer, gameApi.PlayerSettingsEvent, "PollenPopUps", prevPopUp)
			end
		end
	end

	function ultraAntiLag:Set(enabled)
		enabled = enabled == true
		if self.enabled == enabled then return end
		self.enabled = enabled
		threads:Cancel("ultraAntiLagScan")
		for _, id in ipairs({
			"ultraAntiLagBees", "ultraAntiLagParticles", "ultraAntiLagFlames",
			"ultraAntiLagBalloons", "ultraAntiLagBalloonsRoot", "ultraAntiLagPlayerAdded", "ultraAntiLagPlayerRemoving",
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
				if inst and inst.Parent then pcall(writeProp, inst, "Enabled", origOn) end
			end
			table.clear(self.savedParticleFX)
			self:RestoreTable(self.savedTransientProps)
			self:RestoreTable(self.savedProps)
			self:RestoreEnv()
			return
		end

		self:ApplyEnv()
		if self.maxAlt then return end

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
		local function bindFlames(folder)
			if not folder or connections:Get("ultraAntiLagFlames") then return end
			for _, desc in ipairs(folder:GetDescendants()) do self:SyncParticleFX(desc) end
			if folder.DescendantAdded then
				connections:Add("ultraAntiLagFlames", folder.DescendantAdded:Connect(function(desc)
					if self.enabled then self:SyncParticleFX(desc) end
				end))
			end
		end
		bindFlames(workspace:FindFirstChild("PlayerFlames"))

		local function bindFieldBalloons(fieldBalloons)
			if not fieldBalloons or connections:Get("ultraAntiLagBalloons") then return end
			for _, child in ipairs(fieldBalloons:GetChildren()) do self:HideBalloonModel(child) end
			connections:Add("ultraAntiLagBalloons", fieldBalloons.ChildAdded:Connect(function(child)
				if self.enabled then self:HideBalloonModel(child) end
			end))
		end
		local function bindBalloons(balloons)
			if not balloons then return end
			bindFieldBalloons(balloons:FindFirstChild("FieldBalloons"))
			if not connections:Get("ultraAntiLagBalloons") and not connections:Get("ultraAntiLagBalloonsRoot") and balloons.ChildAdded then
				connections:Add("ultraAntiLagBalloonsRoot", balloons.ChildAdded:Connect(function(child)
					if self.enabled and child.Name == "FieldBalloons" then
						connections:Cancel("ultraAntiLagBalloonsRoot")
						bindFieldBalloons(child)
					end
				end))
			end
		end
		bindBalloons(workspace:FindFirstChild("Balloons"))

		if workspace.ChildAdded then
			connections:Add("ultraAntiLagWorkspaceChild", workspace.ChildAdded:Connect(function(child)
				if not self.enabled then return end
				local name = child.Name
				if name == "Bees" then bindBees(child)
				elseif name == "Particles" then bindParticles(child)
				elseif name == "PlayerFlames" then bindFlames(child)
				elseif name == "Balloons" then bindBalloons(child)
				else
					for _, cosmeticName in ipairs(ULTRA_COSMETIC_TOP_FOLDERS) do
						if name == cosmeticName then self:Detach(child, self.detached, self.detachedSet); break end
					end
				end
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

	local function disableFXFast(desc)
		if not desc or not desc.Parent or isBloomParticle(desc) then return end
		if desc:IsA("ParticleEmitter") or desc:IsA("Trail") or desc:IsA("Beam") or desc:IsA("Light") or desc:IsA("Fire") or desc:IsA("Smoke") then
			pcall(writeProp, desc, "Enabled", false)
			if desc:IsA("ParticleEmitter") or desc:IsA("Trail") then pcall(clearFX, desc) end
		end
	end

	local function hideCharFast(char, isLocal)
		if not char or not char.Parent then return end
		local function applyFast(d)
			if isLocal then
				if d.Parent == char and type(d.Name) == "string" and string.find(string.lower(d.Name), "amulet", 1, true) then
					for _, sub in ipairs(d:GetDescendants()) do
						if sub:IsA("BasePart") then
							pcall(writeProp, sub, "LocalTransparencyModifier", 1)
							pcall(writeProp, sub, "CastShadow", false)
						elseif sub:IsA("Decal") or sub:IsA("Texture") then
							pcall(writeProp, sub, "Transparency", 1)
						elseif sub:IsA("ParticleEmitter") or sub:IsA("Trail") or sub:IsA("Beam") or sub:IsA("Light") then
							pcall(writeProp, sub, "Enabled", false)
						end
					end
				end
				return
			end
			if d:IsA("BasePart") then
				pcall(writeProp, d, "LocalTransparencyModifier", 1)
				pcall(writeProp, d, "CastShadow", false)
			elseif d:IsA("Decal") or d:IsA("Texture") then
				pcall(writeProp, d, "Transparency", 1)
			elseif d:IsA("ParticleEmitter") or d:IsA("Trail") or d:IsA("Beam") or d:IsA("Sparkles") or d:IsA("Light") then
				pcall(writeProp, d, "Enabled", false)
			elseif d:IsA("Humanoid") then
				pcall(writeProp, d, "DisplayDistanceType", Enum.HumanoidDisplayDistanceType.None)
			end
		end
		for _, d in ipairs(char:GetDescendants()) do applyFast(d) end
		local key = "maxAltCharDesc:" .. tostring(char)
		if not connections:Get(key) and char.DescendantAdded then
			connections:Add(key, char.DescendantAdded:Connect(function(d)
				if ultraAntiLag.maxAlt then applyFast(d) end
			end))
		end
	end

	function ultraAntiLag:SetMaxAlt(enabled)
		enabled = enabled == true
		if self.maxAlt == enabled then return end
		self.maxAlt = enabled
		for _, id in ipairs({
			"maxAltBees", "maxAltParticles", "maxAltFlames",
			"maxAltWorkspaceChild", "maxAltPlayerAdded", "maxAltPlayerRemoving",
		}) do
			connections:Cancel(id)
		end
		for player in pairs(self.maxAltPlayerConns) do
			connections:Cancel("maxAltCharAdded:" .. tostring(player))
			connections:Cancel("maxAltCharRem:" .. tostring(player))
			local cachedChar = self.maxAltPlayerChars[player]
			if cachedChar then connections:Cancel("maxAltCharDesc:" .. tostring(cachedChar)) end
			if player.Character and player.Character ~= cachedChar then
				connections:Cancel("maxAltCharDesc:" .. tostring(player.Character))
			end
		end
		table.clear(self.maxAltPlayerConns)
		table.clear(self.maxAltPlayerChars)

		local tf = self.tokenFilter
		local t = self.tracked
		if not enabled then
			state.precise = nil
			for fn in pairs(self.maxAltHooks) do
				if restorefunction then pcall(restorefunction, fn) end
				if tf and tf.list then tf.list[fn] = nil end
			end
			table.clear(self.maxAltHooks)
			self:RestoreEnv()
			return
		end

		-- Clear heavy reversible tables when Max Alt Mode takes over.
		if self.enabled then self:Set(false) end
		self:ApplyEnv()

		-- 1. Virtual hooks matching old Atlas+ (stops CollectiblesAnimator.Update & physical instance churn).
		if hookfunction and isfunctionhooked and tf and t then
			local function trackHook(fn)
				self.maxAltHooks[fn] = true
				if tf.list then tf.list[fn] = true end
			end
			local function tryHook(fn, makeReplacement)
				if type(fn) ~= "function" then return false end
				local okHooked, already = pcall(isfunctionhooked, fn)
				if not okHooked then return false end
				if already then return true end
				local orig
				local ok, errOrOrig = pcall(hookfunction, fn, makeReplacement(function(...)
					return orig(...)
				end))
				if not ok then return false end
				orig = errOrOrig
				trackHook(fn)
				return true
			end

			local ca = gameApi.CollectiblesAnimator
			if not ca and ReplicatedStorage then
				local ok, mod = pcall(function() return require(ReplicatedStorage:FindFirstChild("CollectiblesAnimator")) end)
				if ok and type(mod) == "table" then ca = mod end
			end
			if type(ca) == "table" then
				local caSpawnHooked = tryHook(ca.Spawn, function(orig)
					return function(...)
						if not self.maxAlt or not t or not ... then
							return orig(...)
						end
						return tf.TokenSpawn(...)
					end
				end)
				for _, mname in ipairs({ "AnimateCollect", "Destroy", "Update" }) do
					tryHook(ca[mname], function(orig)
						return function(...)
							if not self.maxAlt then return orig(...) end
						end
					end)
				end
				if caSpawnHooked then
					destroyInst(workspace:FindFirstChild("Collectibles"))
					t.tokenlink = {}
					t.tokens = {}
				end
			end

			local amuletsMod = gameApi.LocalAmulets
			if not amuletsMod and ReplicatedStorage then
				local ok, mod = pcall(function() return require(ReplicatedStorage:FindFirstChild("LocalAmulets")) end)
				if ok and type(mod) == "table" then amuletsMod = mod end
			end
			if type(amuletsMod) == "table" then
				tryHook(amuletsMod.CreatePlayerAmulets, function(orig)
					return function(...)
						if not self.maxAlt then return orig(...) end
					end
				end)
			end

			local fxMod = gameApi.LocalFXModule
			if not fxMod and ReplicatedStorage then
				local ok, mod = pcall(function() return require(ReplicatedStorage:FindFirstChild("LocalFX")) end)
				if ok and type(mod) == "table" then fxMod = mod end
			end
			if type(fxMod) == "table" then
				if tryHook(fxMod.ClientRun, function(orig)
					return function(...)
						local u, y = ...
						if not self.maxAlt or not u or not y or not t or tf:LocalFX(u, y) then
							return orig(...)
						end
					end
				end) then
					state.precise = true
				end
			end

			local dupMod = gameApi.DupedTokensAnimator
			if not dupMod and ReplicatedStorage then
				local ok, mod = pcall(function() return require(ReplicatedStorage:FindFirstChild("DupedTokensAnimator")) end)
				if ok and type(mod) == "table" then dupMod = mod end
			end
			if type(dupMod) == "table" then
				local dupSpawnHooked = tryHook(dupMod.Spawn, function(orig)
					return function(H, ...)
						if not self.maxAlt or not H or not t then return orig(H, ...) end
						tf:DupedTokenSpawn(H)
					end
				end)
				tryHook(dupMod.Destroy, function(orig)
					return function(H, Z, ...)
						if not self.maxAlt or not H or not t then return orig(H, Z, ...) end
						tf.DupedTokenDestroy(H)
					end
				end)
				tryHook(dupMod.Charge, function(orig)
					return function(H, ...)
						if not self.maxAlt or not H or not t then return orig(H, ...) end
						tf.DupedTokenCharge(H)
					end
				end)
				tryHook(dupMod.Uncharge, function(orig)
					return function(O, ...)
						if not self.maxAlt or not O or not t then return orig(O, ...) end
						tf.DupedTokenUncharge(O)
					end
				end)
				if dupSpawnHooked then
					local cam = workspace.CurrentCamera
					destroyInst(cam and cam:FindFirstChild("DupedTokens"))
					t.dupedbear = {}
					t.dupedsmiley = {}
					t.dupedtokens = {}
				end
			end

			local slMod = gameApi.StationsListener
			if not slMod and ReplicatedStorage then
				local ok, mod = pcall(function()
					return require(ReplicatedStorage:FindFirstChild("ClientScripts"):FindFirstChild("Listeners"):FindFirstChild("StationsListener"))
				end)
				if ok and type(mod) == "table" then slMod = mod end
			end
			local acts = type(slMod) == "table" and slMod.Actions
			if type(acts) == "table" then
				local stSpawnHooked = tryHook(acts.Spawn, function(orig)
					return function(u, ...)
						if not self.maxAlt or not t then return orig(u, ...) end
						tf.StationSpawn(u)
					end
				end)
				tryHook(acts.AnimDestroy, function(orig)
					return function(u, ...)
						if not self.maxAlt or not t then return orig(u, ...) end
						if type(u) == "table" and u.Id ~= nil then
							t.precisemark[u.Id] = nil
							t.marks[u.Id] = nil
						end
					end
				end)
				if stSpawnHooked then
					destroyInst(workspace:FindFirstChild("Stations"))
					t.precisemark = {}
					t.marks = {}
					if self.watchPreciseFX then self.watchPreciseFX(true) end
				end
			end
		end

		-- 2. Destructive zero-retention cleanup for Bees, Flowers, Decorations, Balloons, Particles, Flames.
		local function bindAltBees(folder)
			if not folder or connections:Get("maxAltBees") then return end
			for _, child in ipairs(folder:GetChildren()) do destroyInst(child) end
			connections:Add("maxAltBees", folder.ChildAdded:Connect(function(child)
				if self.maxAlt then task.defer(destroyInst, child) end
			end))
		end
		bindAltBees(workspace:FindFirstChild("Bees"))

		if not cfg.autofarm.farmleaves and not cfg.autoquest.ants then
			destroyInst(workspace:FindFirstChild("Flowers"))
		end

		for _, name in ipairs(MAX_ALT_DESTROY_TOP) do
			destroyInst(workspace:FindFirstChild(name))
		end
		local map = workspace:FindFirstChild("Map")
		if map then destroyInst(map:FindFirstChild("Fences")) end
		local hiveDeco = workspace:FindFirstChild("HiveDeco")
		if hiveDeco then
			destroyInst(hiveDeco:FindFirstChild("HiveModels"))
			destroyInst(hiveDeco:FindFirstChild("StickerCanvases"))
		end
		local hivePlatforms = workspace:FindFirstChild("HivePlatforms")
		if hivePlatforms then
			for _, plat in ipairs(hivePlatforms:GetChildren()) do
				for _, child in ipairs(plat:GetChildren()) do
					if child.Name == "Platform" then
						pcall(writeProp, child, "CanCollide", false)
					elseif child.Name ~= "Hive" and child.Name ~= "PlayerRef" then
						destroyInst(child)
					end
				end
			end
		end
		local decorations = workspace:FindFirstChild("Decorations")
		if decorations then
			local misc = decorations:FindFirstChild("Misc")
			if misc then
				for _, child in ipairs(misc:GetChildren()) do
					local n = child.Name
					if string.find(n, "Blue Flower") or n == "Bamboo" or n == "Bush" or n == "Mushroom" then
						destroyInst(child)
					end
				end
			end
			for _, name in ipairs({
				"35ZoneCave", "BubbleWandChimney", "TreatBooth", "Coconut Field",
				"Pepper Patch", "Pine Tree", "SpiderCave", "Petal Shop", "JumpGames", "PEggMaze",
			}) do
				destroyInst(decorations:FindFirstChild(name))
			end
			for _, child in ipairs(decorations:GetChildren()) do
				local n = child.Name
				if string.find(n, "Dandelion") or string.find(n, "Clover") or string.find(n, "Rose")
					or string.find(n, "Sign") or string.find(n, "Glider") or n == "ShopWord" then
					destroyInst(child)
				end
			end
		end
		for _, child in ipairs(workspace:GetChildren()) do
			local okCg, cg = pcall(readProp, child, "CollisionGroup")
			if okCg and cg == "BoostBallBarrier" and child:IsA("BasePart") then
				destroyInst(child)
			end
		end

		if not cfg.autofarm.farmballoons and not cfg.autofarm.farmballoons2 and not cfg.face.balloons and not cfg.face.gballoons then
			local balloons = workspace:FindFirstChild("Balloons")
			if balloons then
				destroyInst(balloons:FindFirstChild("FieldBalloons"))
				if t then t.balloons = {} end
			end
		end

		local function bindAltParticles(folder)
			if not folder or connections:Get("maxAltParticles") then return end
			for _, desc in ipairs(folder:GetDescendants()) do disableFXFast(desc) end
			if folder.DescendantAdded then
				connections:Add("maxAltParticles", folder.DescendantAdded:Connect(function(desc)
					if self.maxAlt then disableFXFast(desc) end
				end))
			end
		end
		bindAltParticles(workspace:FindFirstChild("Particles"))

		local function bindAltFlames(folder)
			if not folder or connections:Get("maxAltFlames") then return end
			for _, desc in ipairs(folder:GetDescendants()) do disableFXFast(desc) end
			if folder.DescendantAdded then
				connections:Add("maxAltFlames", folder.DescendantAdded:Connect(function(desc)
					if self.maxAlt then disableFXFast(desc) end
				end))
			end
		end
		bindAltFlames(workspace:FindFirstChild("PlayerFlames"))

		if workspace.ChildAdded then
			connections:Add("maxAltWorkspaceChild", workspace.ChildAdded:Connect(function(child)
				if not self.maxAlt then return end
				local name = child.Name
				if name == "Bees" then bindAltBees(child)
				elseif name == "Particles" then bindAltParticles(child)
				elseif name == "PlayerFlames" then bindAltFlames(child)
				elseif MAX_ALT_DESTROY_TOP_SET[name] then task.defer(destroyInst, child) end
			end))
		end

		-- Hide remote characters (zero restore tables, keeping HRPs & BillboardGuis for combo & Safeshower).
		local playersService = getService("Players")
		if playersService then
			local function watchAltPlayer(p)
				if not p or self.maxAltPlayerConns[p] then return end
				local isLocal = (p == localPlayer)
				self.maxAltPlayerConns[p] = true
				if p.Character then
					self.maxAltPlayerChars[p] = p.Character
					hideCharFast(p.Character, isLocal)
				end
				if p.CharacterAdded then
					connections:Add("maxAltCharAdded:" .. tostring(p), p.CharacterAdded:Connect(function(char)
						local prevChar = self.maxAltPlayerChars[p]
						if prevChar and prevChar ~= char then
							connections:Cancel("maxAltCharDesc:" .. tostring(prevChar))
						end
						self.maxAltPlayerChars[p] = char
						if self.maxAlt then hideCharFast(char, isLocal) end
					end))
				end
				if p.CharacterRemoving then
					connections:Add("maxAltCharRem:" .. tostring(p), p.CharacterRemoving:Connect(function(char)
						if self.maxAltPlayerChars[p] == char then self.maxAltPlayerChars[p] = nil end
						connections:Cancel("maxAltCharDesc:" .. tostring(char))
					end))
				end
			end
			for _, p in ipairs(playersService:GetPlayers()) do watchAltPlayer(p) end
			if playersService.PlayerAdded then
				connections:Add("maxAltPlayerAdded", playersService.PlayerAdded:Connect(function(p)
					if self.maxAlt then watchAltPlayer(p) end
				end))
			end
			if playersService.PlayerRemoving then
				connections:Add("maxAltPlayerRemoving", playersService.PlayerRemoving:Connect(function(p)
					connections:Cancel("maxAltCharAdded:" .. tostring(p))
					connections:Cancel("maxAltCharRem:" .. tostring(p))
					self.maxAltPlayerConns[p] = nil
					local cachedChar = self.maxAltPlayerChars[p]
					self.maxAltPlayerChars[p] = nil
					if cachedChar then connections:Cancel("maxAltCharDesc:" .. tostring(cachedChar)) end
					if p.Character and p.Character ~= cachedChar then
						connections:Cancel("maxAltCharDesc:" .. tostring(p.Character))
					end
				end))
			end
		end
	end

	function ultraAntiLag:SetNoRenderChat(hidden)
		if not StarterGui then return end
		local coreType = Enum.CoreGuiType.Chat
		if hidden then
			if self.savedChatCoreGui == nil then
				local okGet, wasOn = pcall(function() return StarterGui:GetCoreGuiEnabled(coreType) end)
				self.savedChatCoreGui = (okGet and wasOn == true) and true or false
			end
			if self.savedChatCoreGui then
				pcall(function() StarterGui:SetCoreGuiEnabled(coreType, false) end)
			end
		else
			if self.savedChatCoreGui then
				pcall(function() StarterGui:SetCoreGuiEnabled(coreType, true) end)
			end
			self.savedChatCoreGui = nil
		end
	end

	function ultraAntiLag:Shutdown()
		self:SetNoRenderChat(false)
		self:SetMaxAlt(false)
		self:Set(false)
	end
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

	local playerFlames = Instance.new("Folder", workspace); playerFlames.Name = "PlayerFlames"
	local flame1 = Instance.new("Part", playerFlames); flame1.Name = "Flame1"
	local flamePF = Instance.new("ParticleEmitter", flame1); flamePF.Name = "PF"; flamePF.Enabled = true; flamePF.Size = NumberSequence.new(2)
	local flameLight = Instance.new("PointLight", flame1); flameLight.Enabled = true
	local remoteTag = Instance.new("BillboardGui", remoteTorso); remoteTag.Name = "Tag"; remoteTag.Enabled = true

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
	assert(remoteHum.DisplayDistanceType == Enum.HumanoidDisplayDistanceType.None, "Remote Humanoid DisplayDistanceType not set to None")
	assert(remoteTag.Enabled == true, "Remote BillboardGui (Safeshower passive popup) must NOT be disabled")
	assert(flamePF.Enabled == false and flamePF.Size.Keypoints[1].Value == 2, "Flame PF emitter not disabled cleanly or Size altered")
	assert(flameLight.Enabled == false, "Flame PointLight not disabled by SyncParticleFX")
	local flame2 = Instance.new("Part"); flame2.Name = "Flame2"
	local flame2PF = Instance.new("ParticleEmitter", flame2); flame2PF.Name = "PF"; flame2PF.Enabled = true; flame2PF.Size = NumberSequence.new(2)
	flame2.Parent = playerFlames
	assert(flame2PF.Enabled == false, "New flame PF added while ultraAntiLag active was not disabled")
	assert(StarterGui.states.PlayerList == false and StarterGui.states.EmotesMenu == false and StarterGui.states.Chat == true, "CoreGui mismatch under Ultra Anti-Lag (Chat should remain true)")
	ultraAntiLag:SetNoRenderChat(true)
	assert(StarterGui.states.Chat == false, "SetNoRenderChat(true) did not hide Chat")
	ultraAntiLag:SetNoRenderChat(false)
	assert(StarterGui.states.Chat == true, "SetNoRenderChat(false) did not restore Chat")
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
	assert(flamePF.Enabled == true and flameLight.Enabled == true, "Flame PF/PointLight emitter not restored on disable")
	assert(remoteHum.DisplayDistanceType == Enum.HumanoidDisplayDistanceType.Viewer and remoteTag.Enabled == true, "Remote Humanoid DisplayDistanceType or BillboardGui state mismatch on disable")
	assert(StarterGui.states.PlayerList == true and StarterGui.states.Chat == true and StarterGui.states.EmotesMenu == true, "CoreGui not restored on disable")

	-- Lazy ultraAntiLagWorkspaceChild test when PlayerFlames spawns after Ultra Anti-Lag is enabled
	playerFlames:Destroy()
	ultraAntiLag:Set(true)
	local lateFlames = Instance.new("Folder"); lateFlames.Name = "PlayerFlames"
	local lateFlame = Instance.new("Part", lateFlames); lateFlame.Name = "FlameLate"
	local latePF = Instance.new("ParticleEmitter", lateFlame); latePF.Name = "PF"; latePF.Enabled = true
	lateFlames.Parent = workspace
	assert(latePF.Enabled == false, "Lazy PlayerFlames added after Set(true) did not disable PF")
	ultraAntiLag:Set(false)

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
				if currentClock - (self.lastFuelCheck or 0) < 1.0 then
					return self.cachedFuelActive == true
				end
				self.lastFuelCheck = currentClock
				local active = false
				if gameApi and gameApi.BuffTile and secureCall then
					local ok, tile
					if gameApi.CachedBuffTile then
						ok, tile = pcall(gameApi.CachedBuffTile, gameApi, "Flame Fuel")
					else
						ok, tile = pcall(secureCall, gameApi.BuffTile, "Flame Fuel")
					end
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

				local char = localPlayer and localPlayer.Character
				local rootPart = char and char:FindFirstChild("HumanoidRootPart")
				local hum = char and char:FindFirstChildOfClass("Humanoid")
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
	-- Respawn safety: Character == nil during BindToRenderStep Step must not yield or error
	localPlayer.Character = nil
	flameController:Step(now + 0.2)
	assert(not flameController.facingActive and state.stopdig == nil, "flameController:Step did not clean up safely when Character == nil")
	localPlayer.Character = localChar
	flameController:SetEnabled(false)
	assert(hum.AutoRotate == true, "SetEnabled(false) did not restore AutoRotate")

	print("PASS: Section C (Optimal Flame Refreshing, Flame Fuel 6.2s, dark/range exclusion, AutoRotate, Shift Lock, EMA, Shutdown)")
end

-- =========================================================================
-- SECTION E: gameApi:CachedBuffTile 0.25s TTL Cache (including nil)
-- =========================================================================
gameApi.CachedBuffTile = function(api, name)
	local cache = api._buffTileCache
	if not cache then cache = {}; api._buffTileCache = cache end
	local now = os.clock()
	local entry = cache[name]
	if entry and now - entry.t < 0.25 then
		return entry.v or nil
	end
	local value = secureCall(api.BuffTile, name)
	if entry then entry.t, entry.v = now, (value or false)
	else cache[name] = { t = now, v = value or false } end
	return value
end


do
	local buffCalls = 0
	local buffResult = { Stack = 3 }
	gameApi.BuffTile = function(name)
		buffCalls += 1
		return buffResult
	end
	gameApi._buffTileCache = nil

	local r1 = gameApi:CachedBuffTile("Blue Boost")
	assert(buffCalls == 1 and r1 == buffResult, "Initial CachedBuffTile call failed")

	now += 0.1
	local r2 = gameApi:CachedBuffTile("Blue Boost")
	assert(buffCalls == 1 and r2 == buffResult, "CachedBuffTile did not return cached table within 0.25s")

	now += 0.3
	local r3 = gameApi:CachedBuffTile("Blue Boost")
	assert(buffCalls == 2 and r3 == buffResult, "CachedBuffTile did not refresh after 0.25s")

	buffResult = nil
	now += 0.3
	local r4 = gameApi:CachedBuffTile("Red Boost")
	assert(buffCalls == 3 and r4 == nil, "CachedBuffTile nil call mismatch")

	now += 0.1
	local r5 = gameApi:CachedBuffTile("Red Boost")
	assert(buffCalls == 3 and r5 == nil, "CachedBuffTile did not cache nil result within 0.25s")

	-- PruneTransient clears unparented instances from savedTransientProps & savedParticleFX
	do
		local livePart = Instance.new("Part", workspace)
		local deadPart = Instance.new("Part")
		local liveFX = Instance.new("ParticleEmitter", livePart)
		local deadFX = Instance.new("ParticleEmitter")
		ultraAntiLag.savedTransientProps[livePart] = { Transparency = 0 }
		ultraAntiLag.savedTransientProps[deadPart] = { Transparency = 0 }
		ultraAntiLag.savedParticleFX[liveFX] = true
		ultraAntiLag.savedParticleFX[deadFX] = true
		ultraAntiLag:PruneTransient()
		assert(ultraAntiLag.savedTransientProps[livePart] ~= nil and ultraAntiLag.savedTransientProps[deadPart] == nil, "PruneTransient did not prune unparented transient prop")
		assert(ultraAntiLag.savedParticleFX[liveFX] ~= nil and ultraAntiLag.savedParticleFX[deadFX] == nil, "PruneTransient did not prune unparented particle FX")
		ultraAntiLag.savedTransientProps[livePart] = nil
		ultraAntiLag.savedParticleFX[liveFX] = nil
		livePart:Destroy()
	end

	print("PASS: Section E (CachedBuffTile 0.25s TTL + nil caching + PruneTransient)")
end

-- =========================================================================
-- SECTION F: gameApi.SetupSecureCall Inline Identity Switching + Fallback
-- =========================================================================
do
	local curIdent = 8
	local identHistory = {}
	getthreadidentity = function() return curIdent end
	setthreadidentity = function(id)
		curIdent = id
		identHistory[#identHistory + 1] = id
	end
	newcclosure = function(fn) return fn end
	threadCount = 0

	local origThreadsAdd = threads.Add
	local threadAdds = 0
	threads.Add = function(mgr, id, fn, _delaySec, ...)
		threadAdds += 1
		return origThreadsAdd(mgr, id, fn, ...)
	end

	local savedSecureCall = secureCall
	secureCall = nil

	gameApi.SetupSecureCall = function()
	if not secureCall then
		if getthreadidentity and setthreadidentity then
			local function finish(prev, ok, ...)
				setthreadidentity(prev)
				if not ok then error((...), 2) end
				return ...
			end
			secureCall = function(n, ...)
				local prev = getthreadidentity()
				setthreadidentity(5)
				return finish(prev, pcall(n, ...))
			end
		else
			secureCall = newcclosure(function(n, ...)
				local Z, p
				local q
				threadCount += 1

				threads:Add(threadCount, function(...)
					setthreadidentity(5)

					Z, p = pcall(function(...)
						return table.pack(n(...))
					end, ...)

					q = true
				end, nil, ...)

				while not q do
					task.wait()
				end

				if not Z then
					error(p)
				end

				return table.unpack(p, 1, p.n)
			end)
		end
	end
end


	gameApi.SetupSecureCall()

	-- 1. Inline multi-return preserving mid nil, switches identity 8 -> 5 -> 8, zero threads:Add
	local r1, r2, r3 = secureCall(function(a, b)
		assert(curIdent == 5, "identity was not switched to 5 inside secureCall")
		return a, nil, b + 1
	end, "ok", 41)
	assert(r1 == "ok" and r2 == nil and r3 == 42, "secureCall lost multi-return or nil hole")
	assert(curIdent == 8, "secureCall did not restore identity 8 on normal return")
	assert(threadAdds == 0, "inline secureCall spawned a coroutine thread unnecessarily")

	-- 2. Error propagation STILL restores previous identity
	local okErr, errMsg = pcall(secureCall, function()
		assert(curIdent == 5)
		error("boom_secure")
	end)
	assert(not okErr and string.find(tostring(errMsg), "boom_secure", 1, true), "secureCall swallowed error")
	assert(curIdent == 8, "secureCall did not restore identity after error")

	-- 3. Nested re-entrancy restores cleanly step-by-step
	local innerSeen = nil
	local nestedOut = secureCall(function()
		assert(curIdent == 5)
		local v = secureCall(function()
			innerSeen = curIdent
			return "nested"
		end)
		assert(curIdent == 5, "nested secureCall clobbered outer identity 5")
		return v
	end)
	assert(innerSeen == 5 and nestedOut == "nested" and curIdent == 8, "nested secureCall identity mismatch")

	-- 4. Fallback path when getthreadidentity == nil uses coroutine threads:Add
	getthreadidentity = nil
	secureCall = nil
	gameApi.SetupSecureCall()
	local f1, f2, f3 = secureCall(function(x)
		assert(curIdent == 5, "fallback secureCall did not set identity 5")
		return x, nil, 99
	end, "fb")
	assert(f1 == "fb" and f2 == nil and f3 == 99 and threadAdds == 1, "fallback secureCall mismatch")
	local okFbErr = pcall(secureCall, function() error("fb_err") end)
	assert(not okFbErr, "fallback secureCall did not propagate error")

	threads.Add = origThreadsAdd
	secureCall = savedSecureCall
	getthreadidentity = nil
	setthreadidentity = nil
	newcclosure = nil
	print("PASS: Section F (SetupSecureCall inline identity switch, re-entrancy, error restoration, fallback)")
end

-- =========================================================================
-- SECTION G: ultraAntiLag:SetMaxAlt + tokenFilter + tryHook hardening
-- =========================================================================
do
	cfg.antilag = cfg.antilag or {}
	cfg.antilag.ultra = false
	cfg.antilag.maxalt = false
	cfg.antilag.particles = false
	cfg.antilag.precise = false
	cfg.detected = cfg.detected or {}
	cfg.detected.fastraretween = false
	cfg.autoquest = cfg.autoquest or {}
	state.rares = {}
	state.coconuts = 0

	tracked.precise2 = {}
	tracked.precisegroup = {}
	tracked.bubbles = {}
	tracked.flames = {}
	tracked.meteors = {}
	tracked.guiding = {}
	tracked.petals = {}
	tracked.crabcoconuts = {}
	tracked.coconuts = {}
	tracked.combococonuts = {}
	tracked.marks = {}
	tracked.precisemark = {}
	tracked.tokens = {}
	tracked.tokenlink = {}
	tracked.dupedbear = {}
	tracked.dupedsmiley = {}
	tracked.dupedtokens = {}
	tracked.balloons = {}

	comboController.observesRemote = true
	comboController.Observe = function() end
	comboController.Managed = function() return true end

	local stopMovement = function() end
	local showerController = {
		active = false,
		CreateMovementTween = function() return { Play = function() end, Completed = signal() } end,
	}
	local Vector2 = { new = function(x, y) return vector(x, y) end }
	local threadCount = 0
	local tokenFilter
	local preciseWatched = false
	ultraAntiLag.tracked = tracked
	ultraAntiLag.watchPreciseFX = function(v) preciseWatched = v end

		tokenFilter = {
		ignored = {
			AquaWave = true,
			BeamShot = true,
			BeesmasLightsFallingStar = true,
			Bubble = true,
			BubbleBloatCollect = true,
			CCRocket = true,
			CCRocketCrosshairs = true,
			CCRocketCrosshairsOld = true,
			DiamondDrain = true,
			EggShield = true,
			FallingCoal = true,
			FallingCoconut = true,
			FallingSnowflake = true,
			FallingStar = true,
			FieldRectPulses = true,
			FieldStar = true,
			GoldenRake = true,
			GummyStar = true,
			Gummyball = true,
			HoneyHammer = true,
			InspireStar = true,
			JellyBeanToss = true,
			KickableCoconut = true,
			KickedComboCoconut = true,
			LocalFlames = true,
			MechsquitoShot = true,
			MythicMeteor = true,
			OrbExplode = true,
			PartyPopper = true,
			PetalShuriken = true,
			PluckedPetal = true,
			PopStar = true,
			PorcelainDipperAbility = true,
			PuffshroomSporeThrow = true,
			RectPulse = true,
			RingPulse = true,
			ScorchingStar = true,
			SnowballThrow = true,
			SnowflakeBreeze = true,
			SpotlightBeam = true,
			StarSaw = true,
			StarShowerGuide = true,
			StickerTokenBeam = true,
			SweepArch = true,
			Triangulate = true,
			WaterRipple = true,
		},
		dupedmap = {
			["rbxassetid://1472425802"] = "dupedbear",
			["rbxassetid://1472580249"] = "dupedbear",
			["rbxassetid://1472532912"] = "dupedbear",
			["rbxassetid://2032949183"] = "dupedbear",
			["rbxassetid://1472491940"] = "dupedbear",
			["rbxassetid://1489734171"] = "dupedbear",
			["rbxassetid://1837410537"] = "dupedbear",
			["http://www.roblox.com/asset/?id=5877939956"] = "dupedsmiley",
		},
		dupedids = {
			["1472425802"] = "dupedbear",
			["1472580249"] = "dupedbear",
			["1472532912"] = "dupedbear",
			["2032949183"] = "dupedbear",
			["1472491940"] = "dupedbear",
			["1489734171"] = "dupedbear",
			["1837410537"] = "dupedbear",
			["5877939956"] = "dupedsmiley",
		},
		list = {},
		LocalFX = function(owner, effectName, effectData)
			if not comboController.observesRemote then comboController:Observe(effectName, effectData) end
			if type(effectData) ~= "table" then return true end
			-- Keep the original landing markers for the disk-based trackers.
			if effectName == "WarningDisk" or effectName == "FallingCoconut" or effectName == "MythicMeteor" then return true end
			if effectName == "StarShowerGuide" or effectName == "FallingStar" or effectName == "BeesmasLightsFallingStar" then return true end
			if effectName == "LocalTargetPracticeBeam" and effectData.ID ~= nil then
				local act = effectData.Action
				if act == "TurnPurple" then
					local entry = tracked.precise2[effectData.ID]
					if entry then entry.Mark = true end
				elseif act == "Destroy" or act == "Remove" or act == "Shoot" then
					tracked.precise2[effectData.ID] = nil
					tracked.precisegroup[effectData.ID] = nil
					if not (cfg.antilag.precise or cfg.antilag.maxalt) then return true end
					return false
				end
			end
			if effectName ~= "LocalTargetPracticeBeam" or effectData.Action ~= "Make" or effectData.Player ~= localPlayer then
				if effectName ~= "LocalTargetPracticeBeam" or effectData.Action ~= "Touch" then
					if not ((effectName ~= "LocalTargetPracticeBeam" or effectData.Action ~= "TurnPurple") and (effectName ~= "PrecisionPopUp" or effectData.Player ~= localPlayer) or (cfg.antilag.precise or cfg.antilag.maxalt)) then
						return true
					end

					if effectName == "CogSawProjectile" then
						rbcSafety:ObserveFX(effectName,effectData)
						return true
					end

					if not (effectName == "LocalTargetPracticeBeam" or effectName == "Precise Shot" or effectName == "PrecisionPopUp") then
						if not (cfg.antilag.particles or cfg.antilag.maxalt) then
							return true
						end

						if not (effectName ~= "Bubble" or effectData.Action ~= "Spawn") then
							local bubbleEntry = { Name = true, ID = effectData.ID, Position = effectData.Pos, Gold = effectData.Gold }
							tracked.bubbles[effectData.ID] = bubbleEntry

							bubbleEntry.ExpiresAt = os.clock() + math.max(0, tonumber(effectData.Dur) or 0)
						elseif not (effectName ~= "Bubble" or effectData.Action ~= "Pop") then
							tracked.bubbles[effectData.ID] = nil
						elseif effectName ~= "FallingCoconut" or effectData.Target ~= localPlayer and not effectData.Combo then
							if (effectName == "FallingStar" or effectName == "BeesmasLightsFallingStar") and effectData.Target == localPlayer then
								return true -- Safeshower requires the actual game light visuals.
							elseif not (effectName ~= "LocalFlames" or effectData.A ~= "N" or effectData.PID ~= localPlayer.UserId) then
								local lifetime = math.max(0, tonumber(effectData.T) or 0)
								local flame = tracked.flames[effectData.P]
								local nowClock = os.clock()
								if type(flame) ~= "table" then
									flame = {Name=true, Position=effectData.P}
									tracked.flames[effectData.P] = flame
								end
								flame.SpawnTime = nowClock
								flame.ExpiresAt = nowClock + lifetime
								flame.T = math.min(lifetime, 6)
								flame.Size = 1.4 + 0.35 * (flame.T - 1) / 5
								flame.Dark = effectData.D
							elseif effectName == "MythicMeteor" then
								local meteorEntry = { Name = true, Position = effectData.Pos, Size = Vector2.new(effectData.Radius, 0) }
								tracked.meteors[meteorEntry] = {seen=os.clock()}

								meteorEntry.ExpiresAt = os.clock() + math.max(0, tonumber(effectData.FallDuration) or 0)
							elseif not (effectName ~= "FieldStar" or not ((effectData.Action == "Make" or effectData.Action == "Destroy") and effectData.Type == "Guiding Star")) then
								tracked.guiding[effectData.Zone] = effectData.Action == "Make" and 1 or nil
							elseif effectName ~= "PluckedPetal" then
								if not owner.ignored[effectName] then
									return true
								end
							else
								local petalEntry = { Name = true, ZoneName = effectData.ZoneName, Position = effectData.GoalPos }
								tracked.petals[petalEntry] = true

								petalEntry.ExpiresAt = os.clock() + math.max(0, tonumber(effectData.Duration) or 0)
							end
						elseif effectData.Radius == 20 then
							local trackedEntry = { Name = true, Position = effectData.Pos }

							if state.coconuts then
								state.coconuts = state.coconuts + 1
							end

							tracked.crabcoconuts[trackedEntry] = os.time()

							trackedEntry.ExpiresAt = os.clock() + 2.6
						elseif effectData.Radius ~= 13 or not effectData.Friendly or not effectData.Combo or not comboController:Managed() then
							if not (effectData.Radius ~= 13 or not effectData.Friendly) then
								local coconutEntry = { Name = true, Position = effectData.Pos, Start = os.time() }
								tracked.coconuts[coconutEntry] = true

								coconutEntry.ExpiresAt = os.clock() + math.max(0, tonumber(effectData.Dur) or 0)
							end
						else
							local comboCoconutEntry = { Name = true, Position = effectData.Pos, Points = effectData.Points }
							tracked.combococonuts[comboCoconutEntry] = true

							comboCoconutEntry.ExpiresAt = os.clock() + math.max(0, tonumber(effectData.Dur) or 0)
						end
					end
				else
					local preciseEntry = tracked.precise2[effectData.ID]

					if preciseEntry then
						preciseEntry.Touched = true
					end

					if not (cfg.antilag.precise or cfg.antilag.maxalt) then
						return true
					end
				end
			else
				tracked.precise2[effectData.ID] = { Name = true, ID = effectData.ID, Position = effectData.Pos, Mark = effectData.Mark == true, Group = effectData.FEID, Touched = false }
				tracked.precisegroup[effectData.ID] = effectData.FEID

				tracked.precise2[effectData.ID].ExpiresAt = os.clock() + 5.0

				if not (cfg.antilag.precise or cfg.antilag.maxalt) then
					return true
				end
			end
		end,
		ClientCall = function(callName, callArg)
			if callName == "CompleteQuest" or callName == "CompleteQuestFromPool" then
				setthreadidentity(8)
				local stats = discord.stats
				stats["Quests Done"] = stats["Quests Done"] + 1
				local questInfo = callName == "CompleteQuest" and secureCall(gameApi.Quests.Get, nil, callArg)
				local displayName = callName == "CompleteQuest" and questInfo and questInfo.DisplayName or callArg
				local npc = callName == "CompleteQuest" and questInfo and questInfo.NPC or callArg
				local v122 = callName == "CompleteQuestFromPool" and gameApi:Cache({ "Totals", "QuestPoolCounts", npc }) or npc == "Black Bear" and table.find(questData.blackbear, displayName) or npc == "Mother Bear" and table.find(questData.motherbear, displayName) or npc == "Panda Bear" and table.find(questData.pandabear, displayName) or npc == "Science Bear" and table.find(questData.sciencebear, displayName) or npc == "Dapper Bear" and table.find(questData.dapperbear, displayName) or npc == "Spirit Bear" and table.find(questData.spiritbear, displayName) or 0

				if callName == "CompleteQuestFromPool" then
					local lastQuestName = gameApi:Cache({ "Quests", "PoolLastQuests", npc })
					local lastQuest = secureCall(gameApi.Quests.Get, nil, lastQuestName)
					displayName = lastQuest.DisplayName or lastQuest.Name
				end

				discord.Send(string.gsub(string.gsub(displayName, npc .. ": ", ""), "Bear 2", "Bear"), (npc == "Polar Bear" and "Polar Power: " .. string.gsub(buffs.PolarBear.Text, "x", "") .. " <:PolarPower:1290695100439072798>" or "Total " .. string.gsub(npc, "Bear 2", "Bear") .. " Quests: " .. v122) .. "\nTimestamp: <t:" .. os.time() .. ":R>")
			end
		end,
		StationSpawn = function(stationData)
			if type(stationData) ~= "table" or not stationData.Model or stationData.Id == nil then return end
			local base = stationData.Model:FindFirstChild("Base")
			if not base then return end
			tracked.marks[stationData.Id] = { Position = base.Position, Size = Vector2.new(stationData.Radius or 10, 0) }
			local now = os.clock()

			while not stationData.Model:FindFirstChild("Sign") and os.clock() - now < 1 do
				RunService.Heartbeat:Wait()
			end

			local sign = stationData.Model:FindFirstChild("Sign")
			local decal = sign and sign:FindFirstChild("FrontDecal")
			if tracked and decal and string.match(decal.Texture, "%d+") == "8173559749" then
				tracked.precisemark[stationData.Id] = true
			end
		end,
		TokenSpawn = function(tokenData)
			if type(tokenData) ~= "table" or typeof(tokenData.Pos) ~= "Vector3" then return end
			if showerController.active or not cfg.detected.fastraretween or not (not state.stop and not state.fasttween and not state.stopfasttween and not (not state.rares[string.match(tostring(tokenData.Icon or ""), "%d+")] and (not state.rares.Sticker or not tokenData.Rainbow))) then
				if tokenData.Icon ~= "rbxassetid://1629547638" then
					local tokenEntry = { Name = true, Position = tokenData.Pos, Rainbow = tokenData.Rainbow, Icon = tokenData.Icon }
					tracked.tokens[tokenEntry] = true

					tokenEntry.ExpiresAt = os.clock() + math.max(0, tonumber(tokenData.Dur) or 0)
				else
					local tokenEntry = { Name = true, Position = tokenData.Pos, Rainbow = tokenData.Rainbow, Icon = tokenData.Icon }
					tracked.tokenlink[tokenEntry] = true

					tokenEntry.ExpiresAt = os.clock() + math.max(0, tonumber(tokenData.Dur) or 0)
				end
			else
				local distance = distanceTo(tokenData.Pos)
				local tween = showerController:CreateMovementTween(getRootPart(), TweenInfo.new(distance / 200, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), { CFrame = CFrame.new(tokenData.Pos) })
				stopMovement()
				state.fasttween = true
				tween:Play()
				threadCount += 1

				threads:Add(threadCount, function()
					tween.Completed:Wait()
					task.wait(distance > 200 and 0.3 or 0.1)
					state.fasttween = nil
				end)
			end
		end,
		DupedTokenSpawn = function(owner, tokenData)
			if type(tokenData) ~= "table" or tokenData.ID == nil or typeof(tokenData.Pos) ~= "Vector3" then return end
			local tokenEntry = { Name = true, ID = tokenData.ID, Position = tokenData.Pos, Icon = tokenData.Icon, Start = os.clock() }
			local iconId = string.match(tostring(tokenData.Icon or ""), "%d+")
			local listName = (iconId and owner.dupedids and owner.dupedids[iconId]) or owner.dupedmap[tokenData.Icon] or "dupedtokens"
			tracked[listName][tokenData.ID] = tokenEntry

			local serverTime = workspace:FindFirstChild("ServerTime")
			local dur = (type(tokenData.EndTime) == "number" and serverTime and type(serverTime.Value) == "number")
				and math.max(0, tokenData.EndTime - serverTime.Value) or 30
			tokenEntry.ExpiresAt = os.clock() + dur
		end,
		DupedTokenDestroy = function(tokenId)
			tracked.dupedbear[tokenId] = nil
			tracked.dupedsmiley[tokenId] = nil
			tracked.dupedtokens[tokenId] = nil
		end,
		DupedTokenCharge = function(tokenId)
			local tokenEntry = tracked.dupedbear[tokenId] or tracked.dupedsmiley[tokenId] or tracked.dupedtokens[tokenId]

			if tokenEntry then
				tokenEntry.ChargeStart = os.clock()
			end
		end,
		DupedTokenUncharge = function(tokenId)
			local tokenEntry = tracked.dupedbear[tokenId] or tracked.dupedsmiley[tokenId] or tracked.dupedtokens[tokenId]

			if tokenEntry then
				tokenEntry.ChargeStart = nil
			end
		end,
	}
	ultraAntiLag.tokenFilter = tokenFilter


	-- Populate mock Services / Modules / Workspace folders
	workspace.CurrentCamera = Instance.new("Camera")
	local collectiblesFolder = Instance.new("Folder", workspace); collectiblesFolder.Name = "Collectibles"
	local dupedFolder = Instance.new("Folder", workspace.CurrentCamera); dupedFolder.Name = "DupedTokens"
	local stationsFolder = Instance.new("Folder", workspace); stationsFolder.Name = "Stations"
	local beesFolder = Instance.new("Folder", workspace); beesFolder.Name = "Bees"
	local sampleBee = Instance.new("Model", beesFolder); sampleBee.Name = "BasicBee"
	local flowersFolder = Instance.new("Folder", workspace); flowersFolder.Name = "Flowers"
	local decoFolder = Instance.new("Folder", workspace); decoFolder.Name = "Decorations"
	local pepDeco = Instance.new("Model", decoFolder); pepDeco.Name = "Pepper Patch"
	local balloonsFolder = Instance.new("Folder", workspace); balloonsFolder.Name = "Balloons"
	local fieldBalloons = Instance.new("Folder", balloonsFolder); fieldBalloons.Name = "FieldBalloons"
	local serverTimeVal = Instance.new("NumberValue", workspace); serverTimeVal.Name = "ServerTime"; serverTimeVal.Value = 500
	local remoteGui = Instance.new("BillboardGui", remoteRoot); remoteGui.Name = "NameTag"

	local origCallCounts = { caSpawn = 0, caUpdate = 0, fxRun = 0, dupSpawn = 0, stSpawn = 0 }
	local function makeCA()
		return {
			Spawn = function() origCallCounts.caSpawn += 1 end,
			AnimateCollect = function() end,
			Destroy = function() end,
			Update = function() origCallCounts.caUpdate += 1 end,
		}
	end
	local function makeDup()
		return {
			Spawn = function() origCallCounts.dupSpawn += 1 end,
			Destroy = function() end,
			Charge = function() end,
			Uncharge = function() end,
		}
	end
	local function makeSL()
		return {
			Actions = {
				Spawn = function() origCallCounts.stSpawn += 1 end,
				AnimDestroy = function() end,
			},
		}
	end
	gameApi.CollectiblesAnimator = makeCA()
	gameApi.DupedTokensAnimator = makeDup()
	gameApi.StationsListener = makeSL()
	gameApi.LocalAmulets = { CreatePlayerAmulets = function() end }
	gameApi.LocalFXModule = { ClientRun = function() origCallCounts.fxRun += 1 end }

	local hookRegistry = {}
	local failHookTarget = nil
	local function resolveHolder(fn)
		for _, tbl in ipairs({
			gameApi.CollectiblesAnimator,
			gameApi.LocalAmulets,
			gameApi.LocalFXModule,
			gameApi.DupedTokensAnimator,
			gameApi.StationsListener.Actions,
		}) do
			for k, v in pairs(tbl) do
				if v == fn then return tbl, k end
			end
		end
	end
	isfunctionhooked = function(fn)
		return hookRegistry[fn] ~= nil
	end
	hookfunction = function(fn, rep)
		if fn == failHookTarget then error("hook rejected") end
		local tbl, key = resolveHolder(fn)
		assert(tbl and key, "unrecognized function passed to hookfunction")
		local orig = fn
		tbl[key] = rep
		hookRegistry[fn] = { tbl = tbl, key = key, orig = orig, rep = rep }
		hookRegistry[rep] = hookRegistry[fn]
		return orig
	end
	restorefunction = function(fn)
		local rec = hookRegistry[fn]
		if not rec then return end
		rec.tbl[rec.key] = rec.orig
		hookRegistry[rec.orig] = nil
		hookRegistry[rec.rep] = nil
	end

	-- 1. Enable SetMaxAlt(true): hooks installed, cosmetic containers destroyed, HRP & BillboardGui preserved
	cfg.antilag.maxalt = true
	ultraAntiLag:SetMaxAlt(true)
	assert(ultraAntiLag.maxAlt == true, "SetMaxAlt(true) did not enable")
	assert(preciseWatched == true, "SetMaxAlt(true) did not enable watchPreciseFX")
	assert(collectiblesFolder.destroyed, "Collectibles was not destroyed")
	assert(dupedFolder.destroyed, "DupedTokens was not destroyed")
	assert(stationsFolder.destroyed, "Stations was not destroyed")
	assert(sampleBee.destroyed, "existing Bee was not destroyed")
	assert(flowersFolder.destroyed, "Flowers was not destroyed")
	assert(pepDeco.destroyed, "Pepper Patch decoration was not destroyed")
	assert(fieldBalloons.destroyed, "FieldBalloons was not destroyed")
	assert(not remoteRoot.destroyed and not remoteGui.destroyed, "remote HRP or BillboardGui was destroyed")

	local lateBee = Instance.new("Model", beesFolder); lateBee.Name = "LateBee"
	assert(lateBee.destroyed, "new bee added to Bees was not destroyed")

	-- 2. Virtual hooks route cleanly without invoking original CollectiblesAnimator/Duped/Stations
	gameApi.CollectiblesAnimator.Spawn({ Pos = Vector3.new(10, 12, 0), Dur = 4, Icon = "rbxassetid://999" })
	gameApi.CollectiblesAnimator.Spawn({ Pos = Vector3.new(12, 12, 0), Dur = 4, Icon = "rbxassetid://1629547638" })
	gameApi.CollectiblesAnimator.Update()
	gameApi.CollectiblesAnimator.AnimateCollect()
	gameApi.CollectiblesAnimator.Destroy()
	assert(origCallCounts.caSpawn == 0 and origCallCounts.caUpdate == 0, "original CollectiblesAnimator was called under MaxAlt")
	local tokCount, linkCount = 0, 0
	for _ in pairs(tracked.tokens) do tokCount += 1 end
	for _ in pairs(tracked.tokenlink) do linkCount += 1 end
	assert(tokCount == 1 and linkCount == 1, "virtual TokenSpawn did not populate tokens/tokenlink")

	-- Duped tokens: both legacy URL & numeric rbxassetid classify smiley & bear cleanly
	gameApi.DupedTokensAnimator.Spawn({ ID = "d-smiley-url", Pos = Vector3.new(1, 12, 0), Icon = "http://www.roblox.com/asset/?id=5877939956", EndTime = 515 })
	gameApi.DupedTokensAnimator.Spawn({ ID = "d-smiley-num", Pos = Vector3.new(2, 12, 0), Icon = "rbxassetid://5877939956", EndTime = 515 })
	gameApi.DupedTokensAnimator.Spawn({ ID = "d-bear-num", Pos = Vector3.new(3, 12, 0), Icon = "rbxassetid://1472425802", EndTime = 515 })
	assert(tracked.dupedsmiley["d-smiley-url"] and tracked.dupedsmiley["d-smiley-num"], "dupedsmiley numeric/url classification failed")
	assert(tracked.dupedbear["d-bear-num"], "dupedbear classification failed")
	gameApi.DupedTokensAnimator.Charge("d-smiley-num")
	assert(tracked.dupedsmiley["d-smiley-num"].ChargeStart ~= nil, "DupedTokenCharge missing")
	gameApi.DupedTokensAnimator.Uncharge("d-smiley-num")
	assert(tracked.dupedsmiley["d-smiley-num"].ChargeStart == nil, "DupedTokenUncharge failed")
	gameApi.DupedTokensAnimator.Destroy("d-bear-num")
	assert(tracked.dupedbear["d-bear-num"] == nil, "DupedTokenDestroy failed")

	-- LocalFX virtual handling: LocalFlames sets SpawnTime; LocalTargetPracticeBeam cleans Destroy/Remove/Shoot
	gameApi.LocalFXModule.ClientRun("LocalFlames", { A = "N", PID = localPlayer.UserId, P = Vector3.new(5, 12, 0), T = 4 })
	local fEntry = tracked.flames[Vector3.new(5, 12, 0)]
	assert(fEntry == nil or fEntry.SpawnTime == now) -- lookup by key or value
	local foundFlame = nil
	for _, fl in pairs(tracked.flames) do foundFlame = fl end
	assert(foundFlame and foundFlame.SpawnTime == now, "virtual LocalFlames did not set SpawnTime")

	gameApi.LocalFXModule.ClientRun("LocalTargetPracticeBeam", { Action = "Make", Player = localPlayer, ID = "tp1", Pos = Vector3.new(1, 12, 0), FEID = 9 })
	assert(tracked.precise2["tp1"] and tracked.precisegroup["tp1"] == 9, "precise2 Make failed under MaxAlt")
	gameApi.LocalFXModule.ClientRun("LocalTargetPracticeBeam", { Action = "TurnPurple", ID = "tp1" })
	assert(tracked.precise2["tp1"].Mark == true, "precise2 TurnPurple failed")
	for _, clrAct in ipairs({ "Destroy", "Remove", "Shoot" }) do
		gameApi.LocalFXModule.ClientRun("LocalTargetPracticeBeam", { Action = "Make", Player = localPlayer, ID = "tp-" .. clrAct, Pos = Vector3.new(2, 12, 0), FEID = 10 })
		assert(tracked.precise2["tp-" .. clrAct] ~= nil)
		gameApi.LocalFXModule.ClientRun("LocalTargetPracticeBeam", { Action = clrAct, ID = "tp-" .. clrAct })
		assert(tracked.precise2["tp-" .. clrAct] == nil and tracked.precisegroup["tp-" .. clrAct] == nil, "precise2 not cleared on " .. clrAct)
	end

	-- StationSpawn guards nil Model cleanly, and AnimDestroy removes mark
	gameApi.StationsListener.Actions.Spawn({ Id = "st-nil", Model = nil })
	local stModel = Instance.new("Model"); local stBase = Instance.new("Part", stModel); stBase.Name = "Base"; stBase.Position = Vector3.new(8, 12, 0)
	local stSign = Instance.new("Part", stModel); stSign.Name = "Sign"; local stDecal = Instance.new("Decal", stSign); stDecal.Name = "FrontDecal"; stDecal.Texture = "rbxassetid://8173559749"
	gameApi.StationsListener.Actions.Spawn({ Id = "st-ok", Model = stModel, Radius = 12 })
	assert(tracked.marks["st-ok"] and tracked.precisemark["st-ok"], "virtual StationSpawn failed")
	gameApi.StationsListener.Actions.AnimDestroy({ Id = "st-ok" })
	assert(tracked.marks["st-ok"] == nil and tracked.precisemark["st-ok"] == nil, "virtual Station AnimDestroy failed")

	-- 3. Disable SetMaxAlt(false): hooks restored cleanly
	local origSpawnFn = nil
	for fn in pairs(ultraAntiLag.maxAltHooks) do origSpawnFn = fn; break end
	assert(origSpawnFn ~= nil, "maxAltHooks empty while active")
	cfg.antilag.maxalt = false
	ultraAntiLag:SetMaxAlt(false)
	assert(ultraAntiLag.maxAlt == false and next(ultraAntiLag.maxAltHooks) == nil, "SetMaxAlt(false) did not restore/clear maxAltHooks")
	assert(next(tokenFilter.list) == nil, "SetMaxAlt(false) did not clear tokenFilter.list")
	gameApi.CollectiblesAnimator.Spawn()
	assert(origCallCounts.caSpawn == 1, "CollectiblesAnimator.Spawn original was not restored")

	-- Bloom / PetalPart particle preservation under both Ultra Anti-Lag & Max Alt Anti-Lag
	do
		local pFolder = workspace:FindFirstChild("Particles") or Instance.new("Folder", workspace)
		pFolder.Name = "Particles"
		local petalPart = Instance.new("Part", pFolder); petalPart.Name = "PetalPart"
		local petalFX = Instance.new("ParticleEmitter", petalPart); petalFX.Name = "Sparkles"; petalFX.Enabled = true
		local nonBloomPart = Instance.new("Part", pFolder); nonBloomPart.Name = "CosmeticBurst"
		local nonBloomFX = Instance.new("ParticleEmitter", nonBloomPart); nonBloomFX.Name = "Burst"; nonBloomFX.Enabled = true
		local popFolder = Instance.new("Folder", workspace); popFolder.Name = "PoppablePlants"
		local bModel = Instance.new("Model", popFolder); bModel.Name = "RoseBloom"
		local bloomFX = Instance.new("ParticleEmitter", bModel); bloomFX.Name = "BloomSpores"; bloomFX.Enabled = true

		ultraAntiLag:Set(true)
		ultraAntiLag:SyncParticleFX(petalFX)
		ultraAntiLag:SyncParticleFX(bloomFX)
		ultraAntiLag:SyncParticleFX(nonBloomFX)
		assert(petalFX.Enabled == true and bloomFX.Enabled == true, "Ultra Anti-Lag disabled Bloom/PetalPart particle")
		assert(nonBloomFX.Enabled == false, "Ultra Anti-Lag did not disable regular particle")
		ultraAntiLag:Set(false)
		assert(nonBloomFX.Enabled == true, "Set(false) did not restore regular particle")

		ultraAntiLag:SetMaxAlt(true)
		assert(petalFX.Enabled == true and bloomFX.Enabled == true, "Max Alt Anti-Lag disabled Bloom/PetalPart particle")
		assert(nonBloomFX.Enabled == false, "Max Alt Anti-Lag did not disable regular particle")
		ultraAntiLag:SetMaxAlt(false)
		popFolder:Destroy()
		petalPart:Destroy()
		nonBloomPart:Destroy()
	end

	-- 4. tryHook hardening: if CollectiblesAnimator.Spawn hook fails, Collectibles must NOT be destroyed
	local safeCollectibles = Instance.new("Folder", workspace); safeCollectibles.Name = "Collectibles"
	failHookTarget = gameApi.CollectiblesAnimator.Spawn
	ultraAntiLag:SetMaxAlt(true)
	assert(not safeCollectibles.destroyed, "Collectibles was destroyed even though hookfunction failed")
	assert(ultraAntiLag.maxAltHooks[failHookTarget] == nil, "failed hook was added to maxAltHooks")
	failHookTarget = nil
	ultraAntiLag:SetMaxAlt(false)
	safeCollectibles:Destroy()

	hookfunction = nil
	isfunctionhooked = nil
	restorefunction = nil
	print("PASS: Section G (SetMaxAlt virtual hooks, destructive cleanup, tokenFilter, tryHook safety)")
end

print("PASS: All FPS, Anti-Lag, Duped Smiley, Flame Refreshing, SecureCall, MaxAlt, and Source Invariant checks passed!")
