-- Atlas+ Puffshroom Assistant
-- Standalone Bee Swarm Simulator utility using the Atlas+ GUI.

if _G.puffshroomAssistantLoading then
	return
end
_G.puffshroomAssistantLoading = true

local isTestHarness = _G.__PUFF_ASSISTANT_TEST__ == true

if not isTestHarness and (not getthreadidentity or getthreadidentity() < 8) then
	local starterGui = cloneref and cloneref(game:GetService("StarterGui")) or game:GetService("StarterGui")
	pcall(function()
		starterGui:SetCore("SendNotification", {
			Title = "Warning",
			Text = "Your executor is not supported.",
			Duration = 10,
		})
	end)
	_G.puffshroomAssistantLoading = nil
	return
end

local function getService(serviceName)
	local service = game:GetService(serviceName)
	return cloneref and cloneref(service) or service
end

if not game:IsLoaded() then
	game.Loaded:Wait()
end

local Players = getService("Players")
local ReplicatedStorage = getService("ReplicatedStorage")
local RunService = getService("RunService")
local TweenService = getService("TweenService")
local UserInputService = getService("UserInputService")
local HttpService = getService("HttpService")
local StarterGui = getService("StarterGui")
local TextService = getService("TextService")

if not isTestHarness and game.PlaceId ~= 1537690962 then
	pcall(function()
		StarterGui:SetCore("SendNotification", {
			Title = "Warning",
			Text = "You're not in Bee Swarm Simulator.",
			Duration = 5,
		})
	end)
	_G.puffshroomAssistantLoading = nil
	return
end

local localPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()

if not isTestHarness and localPlayer then
	local playerGui = localPlayer:FindFirstChildOfClass("PlayerGui") or localPlayer:WaitForChild("PlayerGui", 10)
	if playerGui then
		local lsg = playerGui:FindFirstChild("LoadingScreenGui")
		while lsg and lsg.Parent and lsg:FindFirstChild("LoadingMessage") and lsg.LoadingMessage.Visible do
			RunService.Heartbeat:Wait()
		end
	end
end

if _G.puffshroomAssistant and type(_G.puffshroomAssistant.Destroy) == "function" then
	pcall(_G.puffshroomAssistant.Destroy)
end

local CONFIG_DIR = "atlas"
local CONFIG_PATH = "atlas/puffshroom-assistant.json"

local defaultCfg = {
	movement = {
		walkspeedenabled = false,
		walkdynamic = false,
		walkspeed = 90,
		walkspeed2 = 1.5,
	},
	tokens = {
		hideHoney = false,
		hideSoftWax = false,
		hideBitterberry = false,
	},
	puffshrooms = {
		transparencyEnabled = true,
		commonTransparency = 0,
		rareTransparency = 0,
		epicTransparency = 0,
		fadeGui = false,
	},
	monitor = {
		enabled = true,
		notifyOnMythic = true,
	},
	misc = {
		mobiletoggle = false,
	},
}

local function deepCopy(source)
	local copy = {}
	for k, v in pairs(source) do
		copy[k] = type(v) == "table" and deepCopy(v) or v
	end
	return copy
end

local function mergeConfig(target, source)
	if type(source) ~= "table" then
		return
	end
	for k, v in pairs(target) do
		if type(v) == "table" and type(source[k]) == "table" then
			mergeConfig(v, source[k])
		elseif type(v) ~= "table" and type(source[k]) == type(v) then
			target[k] = source[k]
		end
	end
end

local cfg = deepCopy(defaultCfg)

local function loadConfig()
	if not (isfolder and isfile and readfile) then
		return
	end
	pcall(function()
		if isfile(CONFIG_PATH) then
			local decoded = HttpService:JSONDecode(readfile(CONFIG_PATH))
			mergeConfig(cfg, decoded)
		end
	end)
	cfg.movement.walkspeed = math.clamp(cfg.movement.walkspeed, 30, 90)
	cfg.movement.walkspeed2 = math.clamp(math.round(cfg.movement.walkspeed2 * 10) / 10, 1, 2)
	cfg.puffshrooms.commonTransparency = math.clamp(cfg.puffshrooms.commonTransparency, 0, 1)
	cfg.puffshrooms.rareTransparency = math.clamp(cfg.puffshrooms.rareTransparency, 0, 1)
	cfg.puffshrooms.epicTransparency = math.clamp(cfg.puffshrooms.epicTransparency, 0, 1)
end

local function saveConfig()
	if not (writefile and HttpService) then
		return
	end
	pcall(function()
		if isfolder and makefolder and not isfolder(CONFIG_DIR) then
			makefolder(CONFIG_DIR)
		end
		writefile(CONFIG_PATH, HttpService:JSONEncode(cfg))
	end)
end

loadConfig()

-- Thread and connection lifecycle managers
local threads = { list = {}, closed = false }
local connections = { list = {} }

function threads:Add(id, callback)
	if self.closed then
		return nil
	end
	self:Cancel(id)
	local thread
	thread = coroutine.create(function()
		local ok, err = xpcall(callback, debug.traceback)
		if self.list[id] == thread then
			self.list[id] = nil
		end
		if not ok and err and not string.find(tostring(err), "thread cancelled", 1, true) then
			warn("[Puffshroom Assistant] " .. tostring(err))
		end
	end)
	self.list[id] = thread
	task.spawn(thread)
	return thread
end

function threads:Get(id)
	return self.list[id]
end

function threads:Cancel(id)
	local thread = self.list[id]
	if thread then
		self.list[id] = nil
		pcall(function()
			task.cancel(thread)
		end)
	end
end

function threads:CancelAll()
	self.closed = true
	for id in pairs(self.list) do
		self:Cancel(id)
	end
end

function connections:Add(id, conn)
	self:Cancel(id)
	self.list[id] = conn
	return conn
end

function connections:Get(id)
	return self.list[id]
end

function connections:Cancel(id)
	local conn = self.list[id]
	if conn then
		self.list[id] = nil
		pcall(function()
			conn:Disconnect()
		end)
	end
end

function connections:CancelAll()
	for id in pairs(self.list) do
		self:Cancel(id)
	end
end

-- Secure call helper (matches Atlas+ identity handling for ClientStatCache & EggTypes)
local secureCall
do
	local function callWithIdentity(fn, ...)
		if setthreadidentity and getthreadidentity then
			local prev = getthreadidentity()
			setthreadidentity(5)
			local packed = table.pack(pcall(fn, ...))
			setthreadidentity(prev)
			if not packed[1] then
				error(packed[2], 0)
			end
			return table.unpack(packed, 2, packed.n)
		end
		return fn(...)
	end

	if newcclosure then
		secureCall = newcclosure(callWithIdentity)
	else
		secureCall = callWithIdentity
	end
end

local gameApi = {}
do
	local statMod = ReplicatedStorage:FindFirstChild("ClientStatCache")
	if statMod then
		local ok, mod = pcall(require, statMod)
		if ok and type(mod) == "table" and type(mod.Get) == "function" then
			gameApi.ClientStatCache = mod
		end
	end

	local eggMod = ReplicatedStorage:FindFirstChild("EggTypes")
	if eggMod then
		local ok, mod = pcall(require, eggMod)
		if ok and type(mod) == "table" and type(mod.GetTypes) == "function" then
			gameApi.EggTypes = mod.GetTypes
		end
	end
end

function gameApi:Cache(...)
	if not self.ClientStatCache then
		return nil
	end
	local args = table.pack(...)
	local ok, result = pcall(function()
		return secureCall(self.ClientStatCache.Get, nil, table.unpack(args, 1, args.n))
	end)
	return ok and result or nil
end

-- Helper to get character Humanoid safely
local function getHumanoid()
	local char = localPlayer and localPlayer.Character
	return char and char:FindFirstChildOfClass("Humanoid") or nil
end

-- Field resolver for puffshrooms
local fieldRaycastParams, fieldRaycastFolder
local function getFieldAt(point)
	if typeof(point) ~= "Vector3" then
		return nil
	end
	local zones = workspace:FindFirstChild("FlowerZones")
	if not zones then
		return nil
	end
	if not fieldRaycastParams or fieldRaycastFolder ~= zones then
		local params = RaycastParams.new()
		params.FilterDescendantsInstances = { zones }
		params.FilterType = Enum.RaycastFilterType.Include
		fieldRaycastParams = params
		fieldRaycastFolder = zones
	end
	local ok, hit = pcall(function()
		return workspace:Raycast(point + Vector3.new(0, 8, 0), Vector3.new(0, -128, 0), fieldRaycastParams)
	end)
	if ok and hit and hit.Instance and hit.Instance.Parent == zones then
		return hit.Instance
	end
	for _, field in ipairs(zones:GetChildren()) do
		if field:IsA("BasePart") and field.CFrame then
			local offset = field.CFrame:PointToObjectSpace(point)
			if math.abs(offset.X) <= field.Size.X / 2 + 2 and math.abs(offset.Z) <= field.Size.Z / 2 + 2 then
				return field
			end
		end
	end
	return nil
end

-- Atlas+ WalkSpeed controller (capped at 90)
local walkSpeedController = {
	lastAppliedSpeed = nil,
	originalSpeed = nil,
	trackedHumanoid = nil,
}

function walkSpeedController:Step()
	if not cfg.movement.walkspeedenabled then
		return
	end
	local h = getHumanoid()
	if not h or not h.Parent or h.Health <= 0 then
		return
	end
	if self.trackedHumanoid ~= h then
		self.trackedHumanoid = h
		self.originalSpeed = h.WalkSpeed
		self.lastAppliedSpeed = nil
	end

	local maxCap = math.clamp(tonumber(cfg.movement.walkspeed) or 90, 30, 90)
	local targetSpeed = nil

	if not cfg.movement.walkdynamic then
		targetSpeed = maxCap
	else
		local modifiers = gameApi:Cache({ "ModifierCaches", "Value" })
		if type(modifiers) == "table" and type(modifiers.PlayerMovespeed) == "table" and type(modifiers.PlayerMovespeed._) == "number" then
			targetSpeed = math.min(maxCap, modifiers.PlayerMovespeed._ * (tonumber(cfg.movement.walkspeed2) or 1.5))
		end
	end

	if not targetSpeed then
		return
	end

	local currentSpeed = h.WalkSpeed
	local wasSetByUs = self.lastAppliedSpeed ~= nil and math.abs(currentSpeed - self.lastAppliedSpeed) < 0.05
	if currentSpeed < targetSpeed or (wasSetByUs and currentSpeed > targetSpeed) then
		h.WalkSpeed = targetSpeed
		self.lastAppliedSpeed = targetSpeed
	end
end

function walkSpeedController:Restore()
	local h = self.trackedHumanoid or getHumanoid()
	if h and h.Parent and self.lastAppliedSpeed ~= nil then
		local restoreTo = self.originalSpeed
		local modifiers = gameApi:Cache({ "ModifierCaches", "Value" })
		if type(modifiers) == "table" and type(modifiers.PlayerMovespeed) == "table" and type(modifiers.PlayerMovespeed._) == "number" then
			restoreTo = modifiers.PlayerMovespeed._
		end
		if type(restoreTo) == "number" and math.abs(h.WalkSpeed - self.lastAppliedSpeed) < 0.05 then
			h.WalkSpeed = restoreTo
		end
	end
	self.lastAppliedSpeed = nil
	self.originalSpeed = nil
	self.trackedHumanoid = nil
end

function walkSpeedController:SetEnabled(enabled)
	threads:Cancel("walkspeed")
	if not enabled then
		self:Restore()
		return
	end
	self:Step()
	threads:Add("walkspeed", function()
		while cfg.movement.walkspeedenabled and not threads.closed do
			self:Step()
			task.wait(0.1)
		end
	end)
end

-- Token Hider (Honey Tokens, Soft Waxes, Bitterberries)
local tokenIds = {
	honey = {
		["1472135114"] = true, -- Honey Token
		["1952683491"] = true, -- Honey Icon
	},
	softWax = {
		["8277778300"] = true, -- Soft Wax
	},
	bitterberry = {
		["4483236276"] = true, -- Bitterberry
		["6087985073"] = true, -- Bitterberry alt
	},
}

-- Enrich token IDs directly from EggTypes if available in game
do
	local function addIconFromInfo(bucket, info)
		if type(info) ~= "table" then
			return
		end
		for _, field in ipairs({ "Icon", "IconImage", "Texture", "DecalID", "Picture" }) do
			local val = info[field]
			if val ~= nil then
				local id = string.match(tostring(val), "%d+")
				if id and #id >= 6 then
					bucket[id] = true
				end
			end
		end
	end

	if gameApi.EggTypes then
		local ok, types = pcall(function()
			return secureCall(gameApi.EggTypes)
		end)
		if ok and type(types) == "table" then
			for key, info in pairs(types) do
				local normKey = string.lower(tostring(key))
				local disp = type(info) == "table" and info.DisplayName and string.lower(tostring(info.DisplayName)) or ""
				if normKey == "softwax" or disp == "soft wax" then
					addIconFromInfo(tokenIds.softWax, info)
				elseif normKey == "bitterberry" or disp == "bitterberry" then
					addIconFromInfo(tokenIds.bitterberry, info)
				elseif normKey == "honey" or disp == "honey" then
					addIconFromInfo(tokenIds.honey, info)
				end
			end
		end
	end
end

local tokenHider = {
	ids = tokenIds,
	saved = {},
	watchers = {},
}

local function extractTokenIconId(token)
	if not token then
		return nil
	end
	local front = token:FindFirstChild("FrontDecal")
	if front and front.Texture then
		local id = string.match(tostring(front.Texture), "%d+")
		if id then
			return id
		end
	end
	local back = token:FindFirstChild("BackDecal")
	if back and back.Texture then
		local id = string.match(tostring(back.Texture), "%d+")
		if id then
			return id
		end
	end
	for _, child in ipairs(token:GetChildren()) do
		if child:IsA("Decal") and child.Texture then
			local id = string.match(tostring(child.Texture), "%d+")
			if id then
				return id
			end
		end
	end
	return nil
end

function tokenHider:ShouldHide(token)
	local iconId = extractTokenIconId(token)
	if not iconId then
		return false
	end
	if cfg.tokens.hideHoney and self.ids.honey[iconId] then
		return true
	end
	if cfg.tokens.hideSoftWax and self.ids.softWax[iconId] then
		return true
	end
	if cfg.tokens.hideBitterberry and self.ids.bitterberry[iconId] then
		return true
	end
	return false
end

local function saveAndSet(record, inst, prop, newVal)
	local ok, current = pcall(function()
		return inst[prop]
	end)
	if not ok then
		return
	end
	local props = record[inst]
	if not props then
		props = {}
		record[inst] = props
	end
	if props[prop] == nil then
		props[prop] = current
	end
	pcall(function()
		inst[prop] = newVal
	end)
end

function tokenHider:Hide(token)
	if not token or not token.Parent then
		return
	end
	local record = self.saved[token]
	if not record then
		record = {}
		self.saved[token] = record
	end
	if token:IsA("BasePart") then
		saveAndSet(record, token, "LocalTransparencyModifier", 1)
		saveAndSet(record, token, "Transparency", 1)
	end
	for _, desc in ipairs(token:GetDescendants()) do
		if desc:IsA("BasePart") then
			saveAndSet(record, desc, "LocalTransparencyModifier", 1)
			saveAndSet(record, desc, "Transparency", 1)
		elseif desc:IsA("Decal") or desc:IsA("Texture") then
			saveAndSet(record, desc, "Transparency", 1)
		elseif desc:IsA("ParticleEmitter") or desc:IsA("Sparkles") or desc:IsA("Light") or desc:IsA("Trail") or desc:IsA("Beam") or desc:IsA("BillboardGui") or desc:IsA("SurfaceGui") then
			saveAndSet(record, desc, "Enabled", false)
		end
	end
end

function tokenHider:Restore(token)
	local record = self.saved[token]
	if not record then
		return
	end
	self.saved[token] = nil
	for inst, props in pairs(record) do
		if inst and inst.Parent then
			for prop, origVal in pairs(props) do
				pcall(function()
					inst[prop] = origVal
				end)
			end
		end
	end
end

function tokenHider:Evaluate(token)
	if not token or not token.Parent then
		return
	end
	if self:ShouldHide(token) then
		self:Hide(token)
	else
		self:Restore(token)
	end
end

function tokenHider:Unwatch(token)
	local conns = self.watchers[token]
	if conns then
		self.watchers[token] = nil
		for _, conn in ipairs(conns) do
			pcall(function()
				conn:Disconnect()
			end)
		end
	end
	self.saved[token] = nil
end

function tokenHider:Watch(token)
	if not token or self.watchers[token] then
		return
	end
	local conns = {}
	self.watchers[token] = conns

	local function bindDecal(obj)
		if (obj:IsA("Decal") or obj:IsA("Texture")) and obj.GetPropertyChangedSignal then
			table.insert(conns, obj:GetPropertyChangedSignal("Texture"):Connect(function()
				self:Evaluate(token)
			end))
		end
	end

	for _, desc in ipairs(token:GetDescendants()) do
		bindDecal(desc)
	end

	if token.DescendantAdded then
		table.insert(conns, token.DescendantAdded:Connect(function(desc)
			bindDecal(desc)
			if self:ShouldHide(token) then
				self:Hide(token)
			end
		end))
	end

	self:Evaluate(token)
end

function tokenHider:RefreshAll()
	local folder = workspace:FindFirstChild("Collectibles")
	if not folder then
		for token in pairs(self.saved) do
			self:Restore(token)
		end
		return
	end
	for _, token in ipairs(folder:GetChildren()) do
		self:Watch(token)
		self:Evaluate(token)
	end
end

function tokenHider:Maintain()
	for token in pairs(self.saved) do
		if not token.Parent or not self:ShouldHide(token) then
			if token.Parent then
				self:Restore(token)
			else
				self:Unwatch(token)
			end
		else
			if token:IsA("BasePart") then
				pcall(function()
					token.LocalTransparencyModifier = 1
					token.Transparency = 1
				end)
			end
			for _, desc in ipairs(token:GetDescendants()) do
				if desc:IsA("Decal") or desc:IsA("Texture") then
					pcall(function()
						desc.Transparency = 1
					end)
				elseif desc:IsA("BasePart") then
					pcall(function()
						desc.LocalTransparencyModifier = 1
						desc.Transparency = 1
					end)
				end
			end
		end
	end
end

function tokenHider:RestoreAll()
	for token in pairs(self.saved) do
		self:Restore(token)
	end
	for token in pairs(self.watchers) do
		self:Unwatch(token)
	end
end

-- Puffshroom parsing & transparency manager
local function parsePuffshroom(puff)
	if not puff or not puff.Parent then
		return nil
	end
	local top = puff:FindFirstChild("Puffball Top")
	if not top then
		return nil
	end
	local attachment = top:FindFirstChild("Attachment")
	local gui = attachment and attachment:FindFirstChild("Gui")
	local nameRow = gui and gui:FindFirstChild("NameRow")
	local textLabel = nameRow and nameRow:FindFirstChild("TextLabel")
	local titleText = textLabel and tostring(textLabel.Text or "") or ""

	local rawRarity = string.match(titleText, "(%a*)%s+Puffshroom")
	local rarity = (rawRarity and rawRarity ~= "") and rawRarity or "Common"
	local level = tonumber(string.match(titleText, "Lvl (%d+)")) or 1

	local remainingSeconds = 0
	local timeText = "?"
	if gui then
		for _, child in ipairs(gui:GetChildren()) do
			if child.Name == "BarRow" then
				local bar = child:FindFirstChild("Bar")
				local numLabel = bar and bar:FindFirstChild("NumberLabel")
				if numLabel and numLabel.Text then
					local rawTime = tostring(numLabel.Text)
					timeText = rawTime
					local _, colonCount = string.gsub(rawTime, ":", "")
					if colonCount > 0 or string.find(rawTime, "s") then
						local minutesPart, secondsPart
						if colonCount == 1 then
							minutesPart, secondsPart = string.match(rawTime, "(%d+):(%d+)")
						else
							secondsPart = string.match(rawTime, "%d+")
						end
						if minutesPart then
							remainingSeconds += (tonumber(minutesPart) or 0) * 60
						end
						if secondsPart then
							remainingSeconds += tonumber(secondsPart) or 0
						end
					end
					break
				end
			end
		end
	end

	local stem = puff:FindFirstChild("Puffball Stem")
	local pos = (stem and stem.Position) or top.Position
	local field = pos and getFieldAt(pos) or nil
	local fieldName = field and field.Name or "Unknown Field"

	return {
		instance = puff,
		rarity = rarity,
		level = level,
		timeText = timeText,
		remainingSeconds = remainingSeconds,
		fieldName = fieldName,
	}
end

local puffVisuals = {
	saved = {},
	appliedAlpha = {},
	appliedFadeGui = {},
}

local function getTargetTransparency(rarity)
	if not cfg.puffshrooms.transparencyEnabled then
		return 0
	end
	if rarity == "Common" then
		return math.clamp(tonumber(cfg.puffshrooms.commonTransparency) or 0, 0, 1)
	elseif rarity == "Rare" then
		return math.clamp(tonumber(cfg.puffshrooms.rareTransparency) or 0, 0, 1)
	elseif rarity == "Epic" then
		return math.clamp(tonumber(cfg.puffshrooms.epicTransparency) or 0, 0, 1)
	end
	-- Legendary and Mythic puffshrooms always remain 100% visible
	return 0
end

local function restoreGuiRecord(record)
	for inst, props in pairs(record) do
		local isGuiBillboard = inst and inst:IsA("BillboardGui")
		for _, prop in ipairs({ "TextTransparency", "BackgroundTransparency", "ImageTransparency" }) do
			local origVal = props[prop]
			if origVal ~= nil then
				props[prop] = nil
				if inst and inst.Parent then
					pcall(function()
						inst[prop] = origVal
					end)
				end
			end
		end
		if isGuiBillboard and props.Enabled ~= nil then
			local origEnabled = props.Enabled
			props.Enabled = nil
			if inst and inst.Parent then
				pcall(function()
					inst.Enabled = origEnabled
				end)
			end
		end
	end
end

function puffVisuals:Restore(puff)
	local record = self.saved[puff]
	self.appliedAlpha[puff] = nil
	self.appliedFadeGui[puff] = nil
	if not record then
		return
	end
	self.saved[puff] = nil
	for inst, props in pairs(record) do
		if inst and inst.Parent then
			for prop, origVal in pairs(props) do
				pcall(function()
					inst[prop] = origVal
				end)
			end
		end
	end
end

function puffVisuals:Apply(puff, rarity)
	if not puff or not puff.Parent then
		self.saved[puff] = nil
		self.appliedAlpha[puff] = nil
		self.appliedFadeGui[puff] = nil
		return
	end
	local alpha = getTargetTransparency(rarity)
	if alpha <= 0 then
		self:Restore(puff)
		return
	end

	local fadeGui = cfg.puffshrooms.fadeGui == true
	local record = self.saved[puff]
	if not record then
		record = {}
		self.saved[puff] = record
	elseif self.appliedFadeGui[puff] and not fadeGui then
		restoreGuiRecord(record)
	end

	self.appliedAlpha[puff] = alpha
	self.appliedFadeGui[puff] = fadeGui

	local targets = puff:GetDescendants()
	table.insert(targets, puff)

	for _, inst in ipairs(targets) do
		if inst:IsA("BasePart") then
			local origMod = record[inst] and record[inst].LocalTransparencyModifier
			if origMod == nil then
				local ok, val = pcall(function() return inst.LocalTransparencyModifier end)
				origMod = ok and val or 0
				record[inst] = record[inst] or {}
				record[inst].LocalTransparencyModifier = origMod
			end
			pcall(function()
				inst.LocalTransparencyModifier = math.clamp(origMod + alpha * (1 - origMod), 0, 1)
			end)
		elseif inst:IsA("Decal") or inst:IsA("Texture") then
			local orig = record[inst] and record[inst].Transparency
			if orig == nil then
				local ok, val = pcall(function() return inst.Transparency end)
				orig = ok and val or 0
				record[inst] = record[inst] or {}
				record[inst].Transparency = orig
			end
			pcall(function()
				inst.Transparency = math.clamp(orig + alpha * (1 - orig), 0, 1)
			end)
		elseif inst:IsA("ParticleEmitter") or inst:IsA("Trail") or inst:IsA("Beam") then
			local orig = record[inst] and record[inst].Enabled
			if orig == nil then
				local ok, val = pcall(function() return inst.Enabled end)
				orig = ok and val or true
				record[inst] = record[inst] or {}
				record[inst].Enabled = orig
			end
			pcall(function()
				inst.Enabled = alpha < 0.95 and orig or false
			end)
		elseif fadeGui then
			if inst:IsA("BillboardGui") then
				local orig = record[inst] and record[inst].Enabled
				if orig == nil then
					local ok, val = pcall(function() return inst.Enabled end)
					orig = ok and val or true
					record[inst] = record[inst] or {}
					record[inst].Enabled = orig
				end
				pcall(function()
					inst.Enabled = alpha < 1 and orig or false
				end)
			elseif inst:IsA("TextLabel") or inst:IsA("TextButton") then
				local orig = record[inst] and record[inst].TextTransparency
				if orig == nil then
					local ok, val = pcall(function() return inst.TextTransparency end)
					orig = ok and val or 0
					record[inst] = record[inst] or {}
					record[inst].TextTransparency = orig
				end
				pcall(function()
					inst.TextTransparency = math.clamp(orig + alpha * (1 - orig), 0, 1)
				end)
			elseif inst:IsA("ImageLabel") then
				local origImg = record[inst] and record[inst].ImageTransparency
				if origImg == nil then
					local ok, val = pcall(function() return inst.ImageTransparency end)
					origImg = ok and val or 0
					record[inst] = record[inst] or {}
					record[inst].ImageTransparency = origImg
				end
				pcall(function()
					inst.ImageTransparency = math.clamp(origImg + alpha * (1 - origImg), 0, 1)
				end)
			elseif inst:IsA("Frame") then
				local origBg = record[inst] and record[inst].BackgroundTransparency
				if origBg == nil then
					local ok, val = pcall(function() return inst.BackgroundTransparency end)
					origBg = ok and val or 1
					record[inst] = record[inst] or {}
					record[inst].BackgroundTransparency = origBg
				end
				if origBg < 1 then
					pcall(function()
						inst.BackgroundTransparency = math.clamp(origBg + alpha * (1 - origBg), 0, 1)
					end)
				end
			end
		end
	end
end

function puffVisuals:RestoreAll()
	for puff in pairs(self.saved) do
		self:Restore(puff)
	end
end

-- Atlas+ GUI Construction
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "AtlasPuffshroomAssistant"
ScreenGui.ScreenInsets = Enum.ScreenInsets.None
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = gethui and gethui() or getService("CoreGui")

local ui = {}
local uiParts = {}
local controls = {}
local monitorState = {
	counts = { Common = 0, Rare = 0, Epic = 0, Legendary = 0, Mythic = 0 },
	total = 0,
	mythics = {},
	notified = {},
}

local color_ = Color3.fromRGB(21, 22, 23)
local color_2 = Color3.fromRGB(30, 30, 30)
local color_3 = Color3.fromRGB(42, 42, 42)
local color_4 = Color3.fromRGB(52, 53, 56)
local color_5 = Color3.fromRGB(65, 67, 71)
local uicolor = _G.uicolor or Color3.fromRGB(41, 74, 122)
local mythicPurple = Color3.fromRGB(168, 85, 247)
local mythicTextColor = Color3.fromRGB(233, 213, 255)
local mythicDotColor = Color3.fromRGB(192, 132, 252)

local viewportSize = Vector2.new(1280, 720)
pcall(function()
	if ScreenGui.AbsoluteSize and ScreenGui.AbsoluteSize.X > 0 then
		viewportSize = ScreenGui.AbsoluteSize
	elseif workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize.X > 0 then
		viewportSize = workspace.CurrentCamera.ViewportSize
	end
end)
local isDesktop = _G.desktop ~= nil and _G.desktop or (viewportSize.X >= 850 and viewportSize.Y >= 500)

local minWindowSize = isDesktop and Vector2.new(620, 360) or Vector2.new(440, 280)
local windowSize = minWindowSize
local dragState = nil

connections:Add("drag", UserInputService.InputChanged:Connect(function(inputObj)
	if dragState and (inputObj.UserInputType == Enum.UserInputType.MouseMovement or inputObj.UserInputType == Enum.UserInputType.Touch) then
		for target, stateVal in pairs(dragState) do
			if stateVal == "resize" then
				local w = math.max(minWindowSize.X, inputObj.Position.X - target.AbsolutePosition.X)
				local h = math.max(minWindowSize.Y, inputObj.Position.Y - target.AbsolutePosition.Y)
				target.Size = UDim2.new(0, w, 0, h)
				windowSize = Vector2.new(w, h)
			elseif stateVal == "slider" then
				target(inputObj)
			else
				local startPos = stateVal[2]
				local delta = inputObj.Position - stateVal[1]
				target.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
			end
		end
	end
end))

connections:Add("stopdrag", UserInputService.InputEnded:Connect(function(inputObj)
	if inputObj.UserInputType == Enum.UserInputType.MouseButton1 or inputObj.UserInputType == Enum.UserInputType.Touch then
		dragState = nil
	end
end))

-- Main Atlas+ Window
local window = _G.background and Instance.new("ImageLabel") or Instance.new("Frame")
window.Name = "Window"
window.Active = true
window.BackgroundColor3 = color_
window.BorderSizePixel = 0
window.ClipsDescendants = true
window.Position = UDim2.new(0, 20, 0, 95)
window.Size = UDim2.new(0, windowSize.X, 0, windowSize.Y)
if _G.background then
	window.Image = _G.background
end
window.Parent = ScreenGui

local windowCorner = Instance.new("UICorner")
windowCorner.CornerRadius = UDim.new(0, 5)
windowCorner.Parent = window

-- Shared Atlas+ UI Templates
do
	local bar = Instance.new("Frame")
	bar.Name = "Bar"
	bar.BackgroundColor3 = uicolor
	bar.BorderSizePixel = 0
	bar.Size = UDim2.new(1, 0, 0, 25)
	uiParts.bar = bar

	local barCorner = Instance.new("UICorner")
	barCorner.CornerRadius = UDim.new(0, 5)
	barCorner.Parent = bar

	local barTitle = Instance.new("TextLabel")
	barTitle.Name = "Title"
	barTitle.BackgroundTransparency = 1
	barTitle.Font = Enum.Font.GothamBold
	barTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
	barTitle.TextSize = 14
	barTitle.TextXAlignment = Enum.TextXAlignment.Left
	barTitle.Position = UDim2.new(0, 10, 0, 0)
	barTitle.Size = UDim2.new(0.8, -10, 0, 25)
	barTitle.Parent = bar

	local barIndicator = Instance.new("ImageButton")
	barIndicator.Name = "Indicator"
	barIndicator.BackgroundTransparency = 1
	barIndicator.Image = "https://www.roblox.com/Thumbs/Asset.ashx?width=420&height=420&assetId=4731371541"
	barIndicator.Position = UDim2.new(1, -25, 0, 2.5)
	barIndicator.Rotation = 90
	barIndicator.Size = UDim2.new(0, 20, 0, 20)
	barIndicator.Parent = bar

	local barBottom = Instance.new("Frame")
	barBottom.Name = "Frame"
	barBottom.BackgroundColor3 = uicolor
	barBottom.BorderSizePixel = 0
	barBottom.Position = UDim2.new(0, 0, 0.85, 0)
	barBottom.Size = UDim2.new(1, 0, 0, 4)
	barBottom.Parent = bar

	local tabBtn = Instance.new("TextButton")
	tabBtn.AutoButtonColor = false
	tabBtn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	tabBtn.BackgroundTransparency = 0.96
	tabBtn.Font = Enum.Font.GothamBold
	tabBtn.TextColor3 = Color3.fromRGB(237, 237, 237)
	tabBtn.TextSize = 11.5
	tabBtn.TextXAlignment = Enum.TextXAlignment.Left
	tabBtn.Size = UDim2.new(1, 0, 0, 23)
	uiParts.tabbutton = tabBtn

	local tabCorner = Instance.new("UICorner")
	tabCorner.CornerRadius = UDim.new(0, 4)
	tabCorner.Parent = tabBtn

	local tabIcon = Instance.new("ImageLabel")
	tabIcon.Name = "TabIcon"
	tabIcon.BackgroundTransparency = 1
	tabIcon.Position = UDim2.new(0, 5, 0, 5)
	tabIcon.Size = UDim2.new(0, 12, 0, 12)
	tabIcon.Parent = tabBtn

	local tabContainer = Instance.new("Frame")
	tabContainer.BackgroundTransparency = 1
	tabContainer.BorderSizePixel = 0
	tabContainer.Size = UDim2.new(1, -5, 1, 0)
	uiParts.tab = tabContainer

	local tabLayout = Instance.new("UIListLayout")
	tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
	tabLayout.Padding = UDim.new(0, 5)
	tabLayout.Parent = tabContainer

	local folder = Instance.new("Frame")
	folder.Name = "Folder"
	folder.BackgroundTransparency = 1
	folder.BorderSizePixel = 0
	folder.Size = UDim2.new(1, 0, 0, 23)
	uiParts.folder = folder

	local folderBtn = Instance.new("TextButton")
	folderBtn.Name = "TextButton"
	folderBtn.AutoButtonColor = false
	folderBtn.BackgroundColor3 = color_3
	folderBtn.BorderSizePixel = 0
	folderBtn.Font = Enum.Font.GothamBold
	folderBtn.TextColor3 = Color3.new(0.784314, 0.784314, 0.784314)
	folderBtn.TextSize = 13
	folderBtn.TextXAlignment = Enum.TextXAlignment.Left
	folderBtn.Size = UDim2.new(1, 0, 0, 23)
	folderBtn.Parent = folder

	local folderCorner = Instance.new("UICorner")
	folderCorner.Name = "UICorner"
	folderCorner.CornerRadius = UDim.new(0, 4)
	folderCorner.Parent = folderBtn

	local folderIndicator = Instance.new("ImageLabel")
	folderIndicator.Name = "Indicator"
	folderIndicator.BackgroundTransparency = 1
	folderIndicator.Image = "https://www.roblox.com/Thumbs/Asset.ashx?width=420&height=420&assetId=4731371541"
	folderIndicator.Position = UDim2.new(1, -25, 0, 1)
	folderIndicator.Rotation = 180
	folderIndicator.Size = UDim2.new(0, 20, 0, 20)
	folderIndicator.Parent = folderBtn

	local folderBox = Instance.new("Frame")
	folderBox.Name = "Box"
	folderBox.BackgroundTransparency = 1
	folderBox.BorderSizePixel = 0
	folderBox.ClipsDescendants = true
	folderBox.Position = UDim2.new(0, 0, 0, 21)
	folderBox.Size = UDim2.new(1, 0, 1, -21)
	folderBox.Parent = folder

	local boxCorner = Instance.new("UICorner")
	boxCorner.Name = "UICorner"
	boxCorner.CornerRadius = UDim.new(0, 4)
	boxCorner.Parent = folderBox

	local boxLayout = Instance.new("UIListLayout")
	boxLayout.SortOrder = Enum.SortOrder.LayoutOrder
	boxLayout.Padding = UDim.new(0, 4)
	boxLayout.Parent = folderBox

	local boxPadding = Instance.new("UIPadding")
	boxPadding.Name = "UIPadding"
	boxPadding.PaddingTop = UDim.new(0, 12)
	boxPadding.PaddingLeft = UDim.new(0, 10)
	boxPadding.Parent = folderBox

	local folderBridge = Instance.new("Frame")
	folderBridge.Name = "Frame"
	folderBridge.BackgroundColor3 = color_3
	folderBridge.BorderSizePixel = 0
	folderBridge.Position = UDim2.new(0, 0, 0, 18)
	folderBridge.Size = UDim2.new(1, 0, 0, 5)
	folderBridge.Visible = false
	folderBridge.Parent = folder

	local btnTemplate = Instance.new("TextButton")
	btnTemplate.Name = "Button"
	btnTemplate.AutoButtonColor = false
	btnTemplate.BackgroundColor3 = uicolor
	btnTemplate.BorderSizePixel = 0
	btnTemplate.ClipsDescendants = true
	btnTemplate.Font = Enum.Font.GothamBold
	btnTemplate.TextColor3 = Color3.new(1, 1, 1)
	btnTemplate.TextSize = 13
	btnTemplate.Size = UDim2.new(0, 130, 0, 20)
	uiParts.button = btnTemplate

	local btnCorner = Instance.new("UICorner")
	btnCorner.Name = "UICorner"
	btnCorner.CornerRadius = UDim.new(0, 4)
	btnCorner.Parent = btnTemplate

	local labelTemplate = Instance.new("TextLabel")
	labelTemplate.Name = "Label"
	labelTemplate.BackgroundTransparency = 1
	labelTemplate.Font = Enum.Font.GothamSemibold
	labelTemplate.TextColor3 = Color3.new(1, 1, 1)
	labelTemplate.TextSize = 12
	labelTemplate.TextXAlignment = Enum.TextXAlignment.Left
	labelTemplate.TextTruncate = Enum.TextTruncate.AtEnd
	uiParts.label = labelTemplate

	local switchTemplate = Instance.new("Frame")
	switchTemplate.Name = "Switch"
	switchTemplate.BackgroundTransparency = 1
	switchTemplate.BorderSizePixel = 0
	switchTemplate.Size = UDim2.new(1, -20, 0, 20)
	uiParts.switch = switchTemplate

	local switchBtn = Instance.new("TextButton")
	switchBtn.Name = "Switch"
	switchBtn.AutoButtonColor = false
	switchBtn.BackgroundColor3 = uicolor
	switchBtn.BackgroundTransparency = 0.4
	switchBtn.BorderSizePixel = 0
	switchBtn.Font = Enum.Font.SourceSans
	switchBtn.Text = ""
	switchBtn.TextColor3 = Color3.new(1, 1, 1)
	switchBtn.TextSize = 18
	switchBtn.Size = UDim2.new(0, 20, 0, 20)
	switchBtn.Parent = switchTemplate

	local switchCorner = Instance.new("UICorner")
	switchCorner.Name = "UICorner"
	switchCorner.CornerRadius = UDim.new(0, 4)
	switchCorner.Parent = switchBtn

	local switchTitle = Instance.new("TextLabel")
	switchTitle.Name = "Title"
	switchTitle.BackgroundTransparency = 1
	switchTitle.Position = UDim2.new(1.2, 0, 0, 0)
	switchTitle.Size = UDim2.new(0, 180, 0, 20)
	switchTitle.Font = Enum.Font.GothamSemibold
	switchTitle.TextColor3 = Color3.new(0.784314, 0.784314, 0.784314)
	switchTitle.TextSize = 13
	switchTitle.TextXAlignment = Enum.TextXAlignment.Left
	switchTitle.Parent = switchBtn

	local sliderTemplate = Instance.new("Frame")
	sliderTemplate.Name = "Slider"
	sliderTemplate.BackgroundColor3 = color_4
	sliderTemplate.BorderSizePixel = 0
	sliderTemplate.Size = UDim2.new(1, -15, 0, 20)
	uiParts.slider = sliderTemplate

	local sliderCorner = Instance.new("UICorner")
	sliderCorner.Name = "UICorner"
	sliderCorner.CornerRadius = UDim.new(0, 4)
	sliderCorner.Parent = sliderTemplate

	local sliderHitbox = Instance.new("TextButton")
	sliderHitbox.Name = "Button"
	sliderHitbox.BackgroundTransparency = 1
	sliderHitbox.Text = ""
	sliderHitbox.Size = UDim2.new(1, 0, 1, 0)
	sliderHitbox.ZIndex = 2
	sliderHitbox.Parent = sliderTemplate

	local sliderIndicator = Instance.new("Frame")
	sliderIndicator.Name = "Indicator"
	sliderIndicator.BackgroundColor3 = color_5
	sliderIndicator.BorderSizePixel = 0
	sliderIndicator.Size = UDim2.new(0, 0, 0, 20)
	sliderIndicator.Parent = sliderTemplate

	local indicatorCorner = Instance.new("UICorner")
	indicatorCorner.Name = "UICorner"
	indicatorCorner.CornerRadius = UDim.new(0, 4)
	indicatorCorner.Parent = sliderIndicator

	local sliderTitle = Instance.new("TextLabel")
	sliderTitle.Name = "Title"
	sliderTitle.BackgroundTransparency = 1
	sliderTitle.Font = Enum.Font.GothamBold
	sliderTitle.TextColor3 = Color3.new(0.784314, 0.784314, 0.784314)
	sliderTitle.TextSize = 13
	sliderTitle.TextXAlignment = Enum.TextXAlignment.Center
	sliderTitle.Position = UDim2.new(0.5, 0, 0.5, -10)
	sliderTitle.Size = UDim2.new(0, 0, 0, 20)
	sliderTitle.ZIndex = 3
	sliderTitle.Parent = sliderTemplate

	local sliderValue = Instance.new("TextLabel")
	sliderValue.Name = "Value"
	sliderValue.BackgroundTransparency = 1
	sliderValue.Font = Enum.Font.GothamBold
	sliderValue.Text = "0"
	sliderValue.TextColor3 = Color3.new(0.784314, 0.784314, 0.784314)
	sliderValue.TextSize = 13
	sliderValue.Position = UDim2.new(1, -45, 0.5, -10)
	sliderValue.Size = UDim2.new(0, 40, 0, 20)
	sliderValue.TextXAlignment = Enum.TextXAlignment.Right
	sliderValue.ZIndex = 3
	sliderValue.Parent = sliderTemplate
end

-- Top bar for main window
local windowVisible = true
do
	local bar = uiParts.bar:Clone()
	local indicator = bar.Indicator
	bar.Title.Text = "Atlas+ Puffshroom Assistant"
	bar.Parent = window

	bar.InputBegan:Connect(function(inputObj)
		if inputObj.UserInputType == Enum.UserInputType.MouseButton1 or inputObj.UserInputType == Enum.UserInputType.Touch then
			if not dragState then
				dragState = {}
			end
			dragState[window] = { inputObj.Position, window.Position }
		end
	end)

	indicator.MouseButton1Click:Connect(function()
		windowVisible = not windowVisible
		bar.Frame.Visible = windowVisible
		TweenService:Create(window, TweenInfo.new(0.1, Enum.EasingStyle.Linear, Enum.EasingDirection.In), {
			Size = windowVisible and UDim2.new(0, windowSize.X, 0, windowSize.Y) or UDim2.new(0, windowSize.X, 0, 25),
		}):Play()
		TweenService:Create(indicator, TweenInfo.new(0.1, Enum.EasingStyle.Linear, Enum.EasingDirection.In), {
			Rotation = windowVisible and 90 or 180,
		}):Play()
	end)
end

-- Mobile Toggle Button
local mobileBtn = Instance.new("ImageButton")
mobileBtn.Name = "Button"
mobileBtn.BackgroundTransparency = 1
mobileBtn.Image = "rbxasset://textures/ui/TopBar/iconBase.png"
mobileBtn.Position = UDim2.new(0.5, -22, 0, 56)
mobileBtn.Size = UDim2.new(0, 44, 0, 44)
mobileBtn.Visible = cfg.misc.mobiletoggle
mobileBtn.Parent = ScreenGui

local mobileCorner = Instance.new("UICorner")
mobileCorner.CornerRadius = UDim.new(0, 6)
mobileCorner.Parent = mobileBtn

local mobileIcon = Instance.new("ImageLabel")
mobileIcon.Name = "Image"
mobileIcon.BackgroundTransparency = 1
mobileIcon.Image = "rbxassetid://120901539385431"
mobileIcon.Position = UDim2.new(0, 8, 0, 8)
mobileIcon.Size = UDim2.new(0, 28, 0, 28)
mobileIcon.Parent = mobileBtn

mobileBtn.InputBegan:Connect(function(inputObj)
	if inputObj.UserInputType == Enum.UserInputType.MouseButton1 or inputObj.UserInputType == Enum.UserInputType.Touch then
		if not dragState then
			dragState = {}
		end
		dragState[mobileBtn] = { inputObj.Position, mobileBtn.Position }
	end
end)

mobileBtn.MouseButton1Click:Connect(function()
	window.Visible = not window.Visible
end)

-- Sidebar & Tab Area
local tabButtonsHolder = Instance.new("Frame")
tabButtonsHolder.Name = "TabButtons"
tabButtonsHolder.BackgroundColor3 = color_2
tabButtonsHolder.BackgroundTransparency = isDesktop and 0 or 1
tabButtonsHolder.BorderSizePixel = 0
tabButtonsHolder.Position = UDim2.new(0, 0, 0, 25)
tabButtonsHolder.Size = UDim2.new(0, 90, 1, -25)
tabButtonsHolder.Parent = window

if isDesktop then
	local sideCorner = Instance.new("UICorner")
	sideCorner.CornerRadius = UDim.new(0, 5)
	sideCorner.Parent = tabButtonsHolder
end
if _G.background then
	tabButtonsHolder.BackgroundTransparency = 0.5
end

local tabListScroll = Instance.new("ScrollingFrame")
tabListScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
tabListScroll.BackgroundTransparency = 1
tabListScroll.BorderSizePixel = 0
tabListScroll.CanvasSize = UDim2.new()
tabListScroll.ScrollBarThickness = 0
tabListScroll.ScrollingDirection = Enum.ScrollingDirection.Y
tabListScroll.Position = UDim2.new(0, 5, 0, 5)
tabListScroll.Size = UDim2.new(1, -10, 1, -10)
tabListScroll.Parent = tabButtonsHolder

local tabListLayout = Instance.new("UIListLayout")
tabListLayout.SortOrder = Enum.SortOrder.LayoutOrder
tabListLayout.Padding = UDim.new(0, 4)
tabListLayout.Parent = tabListScroll

local resizeHandle = Instance.new("Frame")
resizeHandle.Name = "Resize"
resizeHandle.BackgroundTransparency = 1
resizeHandle.BorderSizePixel = 0
resizeHandle.Position = UDim2.new(1, -20, 1, -20)
resizeHandle.Size = UDim2.new(0, 20, 0, 20)
resizeHandle.ZIndex = 2
resizeHandle.Parent = window

resizeHandle.InputBegan:Connect(function(inputObj)
	if inputObj.UserInputType == Enum.UserInputType.MouseButton1 or inputObj.UserInputType == Enum.UserInputType.Touch then
		if not dragState then
			dragState = {}
		end
		dragState[window] = "resize"
	end
end)

local searchBoxFrame = Instance.new("Frame")
searchBoxFrame.Name = "SearchBox"
searchBoxFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
searchBoxFrame.BackgroundTransparency = 0.96
searchBoxFrame.BorderSizePixel = 0
searchBoxFrame.Size = UDim2.new(1, 0, 0, 23)
searchBoxFrame.Parent = tabListScroll

local searchCorner = Instance.new("UICorner")
searchCorner.CornerRadius = UDim.new(0, 4)
searchCorner.Parent = searchBoxFrame

local searchBox = Instance.new("TextBox")
searchBox.BackgroundTransparency = 1
searchBox.Font = Enum.Font.GothamBold
searchBox.PlaceholderText = "Search"
searchBox.PlaceholderColor3 = Color3.fromRGB(237, 237, 237)
searchBox.Text = ""
searchBox.TextColor3 = Color3.fromRGB(237, 237, 237)
searchBox.TextSize = 11.5
searchBox.Position = UDim2.new(0, 18, 0, 0)
searchBox.Size = UDim2.new(1, -18, 0, 23)
searchBox.TextXAlignment = Enum.TextXAlignment.Left
searchBox.Parent = searchBoxFrame

local searchIcon = Instance.new("ImageLabel")
searchIcon.Name = "SearchIcon"
searchIcon.BackgroundTransparency = 1
searchIcon.Image = "rbxassetid://10734943674"
searchIcon.Position = UDim2.new(0, 5, 0, 5)
searchIcon.Size = UDim2.new(0, 12, 0, 12)
searchIcon.Parent = searchBoxFrame

local divider = Instance.new("Frame")
divider.Name = "Divider"
divider.BackgroundColor3 = Color3.fromRGB(56, 56, 56)
divider.BorderSizePixel = 0
divider.Size = UDim2.new(1, 0, 0, 2)
divider.Parent = tabListScroll

local activeTabFrame = nil
local activeTabFrame2 = nil
local activeTabButton = nil
local searchableItems = {}

searchBox.Changed:Connect(function()
	local q = string.lower(searchBox.Text)
	if #q > 0 then
		for _, child in ipairs(tabListScroll:GetChildren()) do
			if child:IsA("TextButton") then
				child.Visible = string.find(string.lower(child.Text), q, 1, true) ~= nil
			end
		end
		for _, entry in ipairs(searchableItems) do
			if string.find(string.lower(entry[1]), q, 1, true) then
				entry[2].Visible = true
			end
		end
	else
		for _, child in ipairs(tabListScroll:GetChildren()) do
			if child:IsA("TextButton") then
				child.Visible = true
			end
		end
	end
end)

ui.Notify = function(title, description)
	local existing = ScreenGui:FindFirstChild("Tooltip")
	if existing then
		existing:Destroy()
	end
	local _, newlineCount = string.gsub(tostring(description), "\n", " ")
	local toast = Instance.new("ImageLabel")
	toast.Name = "Tooltip"
	toast.BackgroundTransparency = 1
	toast.Image = "rbxassetid://11942813307"
	toast.ImageColor3 = Color3.fromRGB(1, 1, 1)
	toast.ImageTransparency = 0.25
	toast.ScaleType = Enum.ScaleType.Slice
	toast.SliceCenter = Rect.new(512, 512, 512, 512)
	toast.AnchorPoint = Vector2.new(1, 1)
	toast.Position = UDim2.new(1, -8, 1, -8)
	toast.Size = UDim2.new(0, newlineCount == 2 and 270 or 260, 0, newlineCount == 2 and 80 or 60)
	toast.Parent = ScreenGui

	local tTitle = Instance.new("TextLabel")
	tTitle.Name = "Title"
	tTitle.BackgroundTransparency = 1
	tTitle.Font = Enum.Font.GothamBold
	tTitle.Text = tostring(title)
	tTitle.TextColor3 = Color3.new(1, 1, 1)
	tTitle.TextSize = 14
	tTitle.TextXAlignment = Enum.TextXAlignment.Left
	tTitle.Position = UDim2.new(0, 14, 0, newlineCount > 0 and 8 or 10)
	tTitle.Size = UDim2.new(1, -24, 0, 20)
	tTitle.Parent = toast

	local tDesc = Instance.new("TextLabel")
	tDesc.Name = "Description"
	tDesc.BackgroundTransparency = 1
	tDesc.Font = Enum.Font.GothamSemibold
	tDesc.Text = tostring(description)
	tDesc.TextColor3 = Color3.fromRGB(220, 220, 225)
	tDesc.TextSize = 13
	tDesc.TextXAlignment = Enum.TextXAlignment.Left
	tDesc.TextTruncate = Enum.TextTruncate.AtEnd
	tDesc.Position = UDim2.new(0, 14, 0, newlineCount == 2 and 38 or 30)
	tDesc.Size = UDim2.new(1, -24, 0, 20)
	tDesc.Parent = toast

	threads:Add("Tooltip", function()
		task.wait(4)
		if toast and toast.Parent then
			toast:Destroy()
		end
	end)
end

ui.AddTab = function(tabName, image, twoColumn, startActive)
	local tabBtn = uiParts.tabbutton:Clone()
	tabBtn.Name = "TabButton_" .. tabName
	tabBtn.Text = "        " .. tabName
	tabBtn.TabIcon.Image = image
	tabBtn.Parent = tabListScroll

	local scrollLeft = Instance.new("ScrollingFrame")
	scrollLeft.Name = "Tab"
	scrollLeft.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scrollLeft.BackgroundTransparency = 1
	scrollLeft.BorderSizePixel = 0
	scrollLeft.CanvasSize = UDim2.new()
	scrollLeft.ScrollBarThickness = 5
	scrollLeft.ScrollBarImageTransparency = 1
	scrollLeft.ScrollingDirection = Enum.ScrollingDirection.Y
	scrollLeft.VerticalScrollBarInset = Enum.ScrollBarInset.None
	scrollLeft.Position = UDim2.new(0, 95, 0, 30)
	scrollLeft.Size = UDim2.new(1, -95, 1, -30)

	local padLeft = Instance.new("UIPadding")
	padLeft.PaddingBottom = UDim.new(0, 5)
	padLeft.Parent = scrollLeft

	local colLeft = uiParts.tab:Clone()
	colLeft.Parent = scrollLeft

	local scrollRight, colRight
	if isDesktop and twoColumn then
		scrollRight = Instance.new("ScrollingFrame")
		scrollRight.Name = "Tab2"
		scrollRight.AutomaticCanvasSize = Enum.AutomaticSize.Y
		scrollRight.BackgroundTransparency = 1
		scrollRight.BorderSizePixel = 0
		scrollRight.CanvasSize = UDim2.new()
		scrollRight.ScrollBarThickness = 5
		scrollRight.ScrollBarImageTransparency = 1
		scrollRight.ScrollingDirection = Enum.ScrollingDirection.Y
		scrollRight.VerticalScrollBarInset = Enum.ScrollBarInset.None
		scrollRight.Position = UDim2.new(0.5, 47.5, 0, 30)
		scrollLeft.Size = UDim2.new(0.5, -47.5, 1, -30)
		scrollRight.Size = scrollLeft.Size

		local padRight = Instance.new("UIPadding")
		padRight.PaddingBottom = UDim.new(0, 5)
		padRight.Parent = scrollRight

		colRight = uiParts.tab:Clone()
		colRight.Parent = scrollRight
	end

	tabBtn.MouseEnter:Connect(function()
		if activeTabButton ~= tabBtn then
			TweenService:Create(tabBtn, TweenInfo.new(0.15, Enum.EasingStyle.Linear, Enum.EasingDirection.In), { BackgroundTransparency = 0.93 }):Play()
		end
	end)

	tabBtn.MouseLeave:Connect(function()
		if activeTabButton ~= tabBtn then
			TweenService:Create(tabBtn, TweenInfo.new(0.15, Enum.EasingStyle.Linear, Enum.EasingDirection.In), { BackgroundTransparency = 0.96 }):Play()
		end
	end)

	tabBtn.MouseButton1Click:Connect(function()
		if activeTabFrame and activeTabButton ~= tabBtn then
			activeTabFrame.Parent = nil
			if activeTabFrame2 then
				activeTabFrame2.Parent = nil
			end
			TweenService:Create(activeTabButton, TweenInfo.new(0.15, Enum.EasingStyle.Linear, Enum.EasingDirection.In), { BackgroundTransparency = 0.96 }):Play()
			TweenService:Create(tabBtn, TweenInfo.new(0.15, Enum.EasingStyle.Linear, Enum.EasingDirection.In), { BackgroundTransparency = 0.85 }):Play()
			scrollLeft.Parent = window
			activeTabButton = tabBtn
			activeTabFrame = scrollLeft
			activeTabFrame2 = scrollRight
			if scrollRight then
				scrollRight.Parent = window
			end
		end
	end)

	if startActive then
		TweenService:Create(tabBtn, TweenInfo.new(0.15, Enum.EasingStyle.Linear, Enum.EasingDirection.In), { BackgroundTransparency = 0.85 }):Play()
		scrollLeft.Parent = window
		activeTabButton = tabBtn
		activeTabFrame = scrollLeft
		if scrollRight then
			scrollRight.Parent = window
			activeTabFrame2 = scrollRight
		end
	end

	local tabApi = {}
	tabApi.AddFolder = function(folderName, useRightColumn)
		local folderApi = {}
		local isOpen = false
		local measuredOnce = nil
		local folderFrame = uiParts.folder:Clone()
		local headerBtn = folderFrame.TextButton
		local box = folderFrame.Box

		if _G.background then
			folderFrame.BackgroundColor3 = color_2
			folderFrame.BackgroundTransparency = 0.4
			if _G.uicolor then
				folderFrame.Frame.BackgroundColor3 = _G.uicolor
				headerBtn.BackgroundColor3 = _G.uicolor
			end
		end

		headerBtn.Text = "   " .. folderName
		folderFrame.Parent = (isDesktop and useRightColumn and colRight) or colLeft

		folderApi.AddLabel = function(text)
			local lbl = uiParts.label:Clone()
			lbl.Text = text
			lbl.Size = UDim2.new(1, -10, 0, 17)
			lbl.Parent = box
			table.insert(searchableItems, { text, tabBtn })
			return lbl
		end

		folderApi.AddButton = function(text, callback, width)
			table.insert(searchableItems, { text, tabBtn })
			local btn = uiParts.button:Clone()
			if width then
				btn.Size = UDim2.new(0, width, 0, 20)
			end
			btn.Text = text
			btn.Parent = box
			btn.MouseButton1Click:Connect(function()
				if callback then
					callback()
				end
			end)
			return btn
		end

		folderApi.AddSwitch = function(text, callback, configSource, configKey)
			local switchApi = {}
			local row = uiParts.switch:Clone()
			local switch = row.Switch
			local titleLabel = switch.Title
			titleLabel.Text = text
			row.Parent = box

			local isOn = false
			local configTable = (configSource and type(configSource) == "string" and cfg[configSource]) or configSource
			if configTable and configTable[configKey] then
				isOn = true
				switch.Text = utf8.char(10003)
				if callback then
					callback(true)
				end
			end

			switch.MouseButton1Click:Connect(function()
				isOn = not isOn
				switch.Text = isOn and utf8.char(10003) or ""
				if configTable then
					configTable[configKey] = isOn
					saveConfig()
				end
				if callback then
					callback(isOn)
				end
			end)

			switchApi.Set = function(newState, skipCallback)
				isOn = newState == true
				switch.Text = isOn and utf8.char(10003) or ""
				if configTable then
					configTable[configKey] = isOn
					saveConfig()
				end
				if callback and not skipCallback then
					callback(isOn)
				end
			end

			switchApi.SetVisible = function(v)
				row.Visible = v
			end

			table.insert(searchableItems, { text, tabBtn })
			return switchApi
		end

		folderApi.AddSlider = function(sliderTitle, callback, minValue, maxValue, configSource, configKey, options)
			table.insert(searchableItems, { sliderTitle, tabBtn })
			local sliderApi = {}
			local sliderRow = uiParts.slider:Clone()
			sliderRow.Parent = box
			local hitbox = sliderRow.Button
			local indicator = sliderRow.Indicator
			local valueLabel = sliderRow.Value
			local left = options and options.Left
			local decimal = options and options.Decimal
			local configTable = (configSource and type(configSource) == "string" and cfg[configSource]) or configSource
			local titleLabel = sliderRow.Title
			titleLabel.Text = left and ("   " .. sliderTitle) or sliderTitle
			if left then
				titleLabel.TextXAlignment = Enum.TextXAlignment.Left
				titleLabel.Position = UDim2.new(0, 0, 0.5, -10)
			end

			local lastValue = nil
			local function formatSliderVal(raw)
				local clamped = math.clamp(raw, minValue, maxValue)
				return decimal and (math.round(clamped * 10) / 10) or math.floor(clamped)
			end

			local function updateFromInput(inputObj)
				local width = sliderRow.AbsoluteSize.X
				if width <= 0 then
					return
				end
				local px = math.clamp(inputObj.Position.X - sliderRow.AbsolutePosition.X, 0, width)
				local ratio = px / width
				local val = formatSliderVal(minValue + ratio * (maxValue - minValue))
				TweenService:Create(indicator, TweenInfo.new(0.08, Enum.EasingStyle.Linear, Enum.EasingDirection.In), {
					Size = UDim2.new(0, px, 0, 20),
				}):Play()
				valueLabel.Text = tostring(val)
				if configTable then
					configTable[configKey] = val
					saveConfig()
				end
				local prev = lastValue
				lastValue = val
				if callback and prev ~= val then
					callback(val)
				end
			end

			hitbox.InputBegan:Connect(function(inputObj)
				if inputObj.UserInputType == Enum.UserInputType.MouseButton1 or inputObj.UserInputType == Enum.UserInputType.Touch then
					if not dragState then
						dragState = {}
					end
					dragState[updateFromInput] = "slider"
					updateFromInput(inputObj)
				end
			end)

			sliderApi.Set = function(newValue, skipCallback)
				local colWidth = (isDesktop and twoColumn and (windowSize.X * 0.5 - 47 - 5 - 10 - 15)) or (windowSize.X - 95 - 5 - 10 - 15)
				colWidth = math.max(1, colWidth)
				local val = formatSliderVal(tonumber(newValue) or minValue)
				local fillRatio = (maxValue > minValue) and ((val - minValue) / (maxValue - minValue)) or 0
				TweenService:Create(indicator, TweenInfo.new(0.08, Enum.EasingStyle.Linear, Enum.EasingDirection.In), {
					Size = UDim2.new(0, fillRatio * colWidth, 0, 20),
				}):Play()
				valueLabel.Text = tostring(val)
				if configTable then
					configTable[configKey] = val
					saveConfig()
				end
				local prev = lastValue
				lastValue = val
				if callback and not skipCallback and prev ~= nil and prev ~= val then
					callback(val)
				end
			end

			sliderApi.SetVisible = function(v)
				sliderRow.Visible = v
			end

			sliderApi.SetTitle = function(newTitle)
				titleLabel.Text = left and ("   " .. newTitle) or newTitle
			end

			if configTable and configTable[configKey] ~= nil then
				sliderApi.Set(configTable[configKey], true)
			else
				sliderApi.Set(minValue, true)
			end

			return sliderApi
		end

		folderApi.Toggle = function(openState, desktopOnly)
			if desktopOnly and not isDesktop then
				return
			end
			local measuredHeight = 37
			for _, child in ipairs(box:GetChildren()) do
				if child.ClassName ~= "UIPadding" and child.ClassName ~= "UIListLayout" and child.ClassName ~= "UICorner" and child.Visible then
					measuredHeight += child.Size.Y.Offset + 4
				end
			end
			if not measuredOnce then
				measuredOnce = measuredHeight
			end
			folderFrame.Frame.Visible = openState
			box.BackgroundTransparency = openState and 0.96 or 1
			box.ClipsDescendants = not openState
			isOpen = openState
			TweenService:Create(folderFrame, TweenInfo.new(0.08, Enum.EasingStyle.Linear, Enum.EasingDirection.In), {
				Size = openState and UDim2.new(1, 0, 0, measuredHeight) or UDim2.new(1, 0, 0, 23),
			}):Play()
			TweenService:Create(headerBtn.Indicator, TweenInfo.new(0.08, Enum.EasingStyle.Linear, Enum.EasingDirection.In), {
				Rotation = openState and 90 or 180,
			}):Play()
		end

		folderApi.Refresh = function()
			if measuredOnce then
				local measuredHeight = 37
				for _, child in ipairs(box:GetChildren()) do
					if child.ClassName ~= "UIPadding" and child.ClassName ~= "UIListLayout" and child.ClassName ~= "UICorner" and child.Visible then
						measuredHeight += child.Size.Y.Offset + 4
					end
				end
				measuredOnce = measuredHeight
				TweenService:Create(folderFrame, TweenInfo.new(0, Enum.EasingStyle.Linear, Enum.EasingDirection.In), {
					Size = isOpen and UDim2.new(1, 0, 0, measuredHeight) or UDim2.new(1, 0, 0, 23),
				}):Play()
			end
		end

		headerBtn.MouseButton1Click:Connect(function()
			folderApi.Toggle(not isOpen)
		end)

		table.insert(searchableItems, { folderName, tabBtn })
		return folderApi
	end

	return tabApi
end

-- Top-of-Screen Mythic Puffshroom Monitor HUD
local monitorFrame = Instance.new("Frame")
monitorFrame.Name = "MythicMonitor"
monitorFrame.Active = true
monitorFrame.AnchorPoint = Vector2.new(0.5, 0)
monitorFrame.BackgroundColor3 = color_
monitorFrame.BackgroundTransparency = 0.06
monitorFrame.BorderSizePixel = 0
monitorFrame.ClipsDescendants = true
monitorFrame.Position = UDim2.new(0.5, 0, 0, 10)
monitorFrame.Size = UDim2.new(0, 440, 0, 38)
monitorFrame.ZIndex = 10
monitorFrame.Visible = cfg.monitor.enabled
monitorFrame.Parent = ScreenGui

local monitorCorner = Instance.new("UICorner")
monitorCorner.CornerRadius = UDim.new(0, 6)
monitorCorner.Parent = monitorFrame

local monitorStroke = Instance.new("UIStroke")
monitorStroke.Thickness = 1.5
monitorStroke.Color = uicolor
monitorStroke.Parent = monitorFrame

local monitorAccent = Instance.new("Frame")
monitorAccent.Name = "Accent"
monitorAccent.BackgroundColor3 = uicolor
monitorAccent.BorderSizePixel = 0
monitorAccent.Size = UDim2.new(1, 0, 0, 3)
monitorAccent.ZIndex = 11
monitorAccent.Parent = monitorFrame

local monitorDot = Instance.new("Frame")
monitorDot.Name = "Dot"
monitorDot.BackgroundColor3 = Color3.fromRGB(115, 130, 155)
monitorDot.BorderSizePixel = 0
monitorDot.Position = UDim2.new(0, 12, 0.5, -4)
monitorDot.Size = UDim2.new(0, 10, 0, 10)
monitorDot.ZIndex = 11
monitorDot.Parent = monitorFrame

local monitorDotCorner = Instance.new("UICorner")
monitorDotCorner.CornerRadius = UDim.new(1, 0)
monitorDotCorner.Parent = monitorDot

local monitorMainText = Instance.new("TextLabel")
monitorMainText.Name = "StatusText"
monitorMainText.BackgroundTransparency = 1
monitorMainText.Font = Enum.Font.GothamBold
monitorMainText.Text = "MYTHIC MONITOR  |  None on map"
monitorMainText.TextColor3 = Color3.fromRGB(215, 220, 230)
monitorMainText.TextSize = 13
monitorMainText.TextXAlignment = Enum.TextXAlignment.Left
monitorMainText.TextTruncate = Enum.TextTruncate.AtEnd
monitorMainText.Position = UDim2.new(0, 30, 0, 3)
monitorMainText.Size = UDim2.new(1, -120, 1, -3)
monitorMainText.ZIndex = 11
monitorMainText.Parent = monitorFrame

local monitorBadge = Instance.new("TextLabel")
monitorBadge.Name = "Badge"
monitorBadge.BackgroundColor3 = color_4
monitorBadge.BorderSizePixel = 0
monitorBadge.Font = Enum.Font.GothamBold
monitorBadge.Text = "Puffs: 0"
monitorBadge.TextColor3 = Color3.fromRGB(220, 225, 235)
monitorBadge.TextSize = 11
monitorBadge.AnchorPoint = Vector2.new(1, 0.5)
monitorBadge.Position = UDim2.new(1, -10, 0.5, 1)
monitorBadge.Size = UDim2.new(0, 74, 0, 22)
monitorBadge.ZIndex = 11
monitorBadge.Parent = monitorFrame

local monitorBadgeCorner = Instance.new("UICorner")
monitorBadgeCorner.CornerRadius = UDim.new(0, 4)
monitorBadgeCorner.Parent = monitorBadge

monitorFrame.InputBegan:Connect(function(inputObj)
	if inputObj.UserInputType == Enum.UserInputType.MouseButton1 or inputObj.UserInputType == Enum.UserInputType.Touch then
		if not dragState then
			dragState = {}
		end
		dragState[monitorFrame] = { inputObj.Position, monitorFrame.Position }
	end
end)

-- Tabs & Controls
local assistantTab = ui.AddTab("Assistant", "rbxassetid://10723415903", true, true)
local settingsTab = ui.AddTab("Settings", "rbxassetid://10734950309", false, false)

-- Left Column: Mythic Monitor + Movement
local monitorFolder = assistantTab.AddFolder("Mythic Monitor")
local monitorStatusLabel = monitorFolder.AddLabel("Status: No Mythic on map")
local puffCountsLabel = monitorFolder.AddLabel("Active Puffs: 0 (0C / 0R / 0E / 0L / 0M)")

controls.showMonitor = monitorFolder.AddSwitch("Show Top Mythic Monitor", function(enabled)
	monitorFrame.Visible = enabled
end, "monitor", "enabled")

controls.notifyMythic = monitorFolder.AddSwitch("Notify On Mythic Spawn", nil, "monitor", "notifyOnMythic")

monitorFolder.AddButton("Reset Monitor Position", function()
	monitorFrame.Position = UDim2.new(0.5, 0, 0, 10)
end, 165)

monitorFolder.Toggle(true, true)

local movementFolder = assistantTab.AddFolder("Movement")
local walkSpeedSlider, multiplierSlider

controls.walkspeedenabled = movementFolder.AddSwitch("Enable Walk Speed", function(enabled)
	walkSpeedController:SetEnabled(enabled)
end, "movement", "walkspeedenabled")

controls.walkdynamic = movementFolder.AddSwitch("Dynamic Walk Speed", function(enabled)
	if walkSpeedSlider then
		walkSpeedSlider.SetTitle(enabled and "Maximum Walk Speed" or "Walk Speed")
	end
	if multiplierSlider then
		multiplierSlider.SetVisible(enabled)
	end
	movementFolder.Refresh()
	walkSpeedController:Step()
end, "movement", "walkdynamic")

walkSpeedSlider = movementFolder.AddSlider("Walk Speed", function()
	walkSpeedController:Step()
end, 30, 90, "movement", "walkspeed", { Left = true })

multiplierSlider = movementFolder.AddSlider("Walk Speed Multiplier", function()
	walkSpeedController:Step()
end, 1, 2, "movement", "walkspeed2", { Left = true, Decimal = true })

controls.walkspeed = walkSpeedSlider
controls.walkspeed2 = multiplierSlider

if walkSpeedSlider then
	walkSpeedSlider.SetTitle(cfg.movement.walkdynamic and "Maximum Walk Speed" or "Walk Speed")
end
if multiplierSlider then
	multiplierSlider.SetVisible(cfg.movement.walkdynamic)
end

movementFolder.Toggle(true, true)

-- Right Column: Hide Tokens + Puffshroom Transparency
local tokensFolder = assistantTab.AddFolder("Hide Tokens", true)

local function onTokenToggleChanged()
	tokenHider:RefreshAll()
end

controls.hideHoney = tokensFolder.AddSwitch("Hide Honey Tokens", onTokenToggleChanged, "tokens", "hideHoney")
controls.hideSoftWax = tokensFolder.AddSwitch("Hide Soft Waxes", onTokenToggleChanged, "tokens", "hideSoftWax")
controls.hideBitterberry = tokensFolder.AddSwitch("Hide Bitterberries", onTokenToggleChanged, "tokens", "hideBitterberry")

tokensFolder.Toggle(true, true)

local puffFolder = assistantTab.AddFolder("Puffshroom Transparency", true)

local stepMonitor -- forward declared

local function onPuffVisualsChanged()
	if stepMonitor then
		stepMonitor(true)
	end
end

controls.transparencyEnabled = puffFolder.AddSwitch("Enable Transparency", onPuffVisualsChanged, "puffshrooms", "transparencyEnabled")
controls.commonTransparency = puffFolder.AddSlider("Common Transparency", onPuffVisualsChanged, 0, 1, "puffshrooms", "commonTransparency", { Left = true, Decimal = true })
controls.rareTransparency = puffFolder.AddSlider("Rare Transparency", onPuffVisualsChanged, 0, 1, "puffshrooms", "rareTransparency", { Left = true, Decimal = true })
controls.epicTransparency = puffFolder.AddSlider("Epic Transparency", onPuffVisualsChanged, 0, 1, "puffshrooms", "epicTransparency", { Left = true, Decimal = true })
controls.fadeGui = puffFolder.AddSwitch("Fade Overhead Labels", onPuffVisualsChanged, "puffshrooms", "fadeGui")
puffFolder.AddLabel("Legendary & Mythic always stay 100% visible")

puffFolder.Toggle(true, true)

-- Settings Tab
local settingsFolder = settingsTab.AddFolder("Assistant")

controls.mobiletoggle = settingsFolder.AddSwitch("Mobile Toggle Button", function(enabled)
	mobileBtn.Visible = enabled
end, "misc", "mobiletoggle")

local cleanup -- forward declared

settingsFolder.AddButton("Reset All Settings", function()
	mergeConfig(cfg, deepCopy(defaultCfg))
	saveConfig()
	controls.showMonitor.Set(cfg.monitor.enabled)
	controls.notifyMythic.Set(cfg.monitor.notifyOnMythic)
	controls.walkspeedenabled.Set(cfg.movement.walkspeedenabled)
	controls.walkdynamic.Set(cfg.movement.walkdynamic)
	controls.walkspeed.Set(cfg.movement.walkspeed)
	controls.walkspeed2.Set(cfg.movement.walkspeed2)
	controls.hideHoney.Set(cfg.tokens.hideHoney)
	controls.hideSoftWax.Set(cfg.tokens.hideSoftWax)
	controls.hideBitterberry.Set(cfg.tokens.hideBitterberry)
	controls.transparencyEnabled.Set(cfg.puffshrooms.transparencyEnabled)
	controls.commonTransparency.Set(cfg.puffshrooms.commonTransparency)
	controls.rareTransparency.Set(cfg.puffshrooms.rareTransparency)
	controls.epicTransparency.Set(cfg.puffshrooms.epicTransparency)
	controls.fadeGui.Set(cfg.puffshrooms.fadeGui)
	controls.mobiletoggle.Set(cfg.misc.mobiletoggle)
	ui.Notify("Puffshroom Assistant", "Settings reset to defaults")
end, 145)

settingsFolder.AddButton("Unload Assistant", function()
	if cleanup then
		cleanup()
	end
end, 145)

settingsFolder.Toggle(true, true)

-- Runtime Watchers & Monitor Step
local function bindCollectiblesFolder(folder)
	connections:Cancel("collectiblesAdded")
	connections:Cancel("collectiblesRemoved")
	if not folder then
		return
	end
	connections:Add("collectiblesAdded", folder.ChildAdded:Connect(function(token)
		tokenHider:Watch(token)
		tokenHider:Evaluate(token)
	end))
	connections:Add("collectiblesRemoved", folder.ChildRemoved:Connect(function(token)
		tokenHider:Unwatch(token)
	end))
	for _, token in ipairs(folder:GetChildren()) do
		tokenHider:Watch(token)
		tokenHider:Evaluate(token)
	end
end

bindCollectiblesFolder(workspace:FindFirstChild("Collectibles"))

local function bindPuffFolder(folder)
	connections:Cancel("puffAdded")
	connections:Cancel("puffRemoved")
	if not folder then
		return
	end
	connections:Add("puffAdded", folder.ChildAdded:Connect(function(puff)
		if stepMonitor then
			stepMonitor(true)
		end
	end))
	connections:Add("puffRemoved", folder.ChildRemoved:Connect(function(puff)
		puffVisuals:Restore(puff)
		monitorState.notified[puff] = nil
		if stepMonitor then
			stepMonitor(true)
		end
	end))
end

local happenings = workspace:FindFirstChild("Happenings")
if happenings then
	bindPuffFolder(happenings:FindFirstChild("Puffshrooms"))
	connections:Add("happeningsAdded", happenings.ChildAdded:Connect(function(child)
		if child.Name == "Puffshrooms" then
			bindPuffFolder(child)
			if stepMonitor then
				stepMonitor(true)
			end
		end
	end))
end

connections:Add("workspaceChildren", workspace.ChildAdded:Connect(function(child)
	if child.Name == "Collectibles" then
		bindCollectiblesFolder(child)
	elseif child.Name == "Happenings" then
		bindPuffFolder(child:FindFirstChild("Puffshrooms"))
		connections:Add("happeningsAdded", child.ChildAdded:Connect(function(sub)
			if sub.Name == "Puffshrooms" then
				bindPuffFolder(sub)
				if stepMonitor then
					stepMonitor(true)
				end
			end
		end))
	end
end))

stepMonitor = function(skipMaintain)
	local counts = { Common = 0, Rare = 0, Epic = 0, Legendary = 0, Mythic = 0 }
	local mythics = {}
	local total = 0
	local livePuffs = {}

	local hap = workspace:FindFirstChild("Happenings")
	local puffFolderObj = hap and hap:FindFirstChild("Puffshrooms")
	if puffFolderObj then
		for _, puff in ipairs(puffFolderObj:GetChildren()) do
			local info = parsePuffshroom(puff)
			if info then
				livePuffs[puff] = true
				total += 1
				counts[info.rarity] = (counts[info.rarity] or 0) + 1
				puffVisuals:Apply(puff, info.rarity)
				if info.rarity == "Mythic" then
					table.insert(mythics, info)
					if cfg.monitor.notifyOnMythic and not monitorState.notified[puff] then
						monitorState.notified[puff] = true
						ui.Notify("Mythic Puffshroom!", info.fieldName .. " (Lvl " .. info.level .. ")")
					end
				end
			end
		end
	end

	-- Prune stale references for despawned puffshrooms
	for puff in pairs(puffVisuals.saved) do
		if not livePuffs[puff] then
			puffVisuals.saved[puff] = nil
			puffVisuals.appliedAlpha[puff] = nil
			puffVisuals.appliedFadeGui[puff] = nil
		end
	end
	for puff in pairs(monitorState.notified) do
		if not livePuffs[puff] then
			monitorState.notified[puff] = nil
		end
	end

	monitorState.counts = counts
	monitorState.total = total
	monitorState.mythics = mythics

	local countSummary = string.format(
		"Active Puffs: %d (%dC / %dR / %dE / %dL / %dM)",
		total,
		counts.Common,
		counts.Rare,
		counts.Epic,
		counts.Legendary,
		counts.Mythic
	)
	puffCountsLabel.Text = countSummary

	local hudText
	if #mythics > 0 then
		monitorStroke.Color = mythicPurple
		monitorAccent.BackgroundColor3 = mythicPurple
		monitorDot.BackgroundColor3 = mythicDotColor
		monitorMainText.TextColor3 = mythicTextColor
		monitorBadge.BackgroundColor3 = mythicPurple
		monitorBadge.TextColor3 = Color3.new(1, 1, 1)
		monitorBadge.Text = #mythics == 1 and "MYTHIC!" or ("MYTHIC x" .. #mythics)

		if #mythics == 1 then
			local m = mythics[1]
			hudText = string.format("MYTHIC PUFFSHROOM: %s (Lvl %d, %s)", m.fieldName, m.level, m.timeText)
			monitorStatusLabel.Text = string.format("Status: MYTHIC in %s (Lvl %d)", m.fieldName, m.level)
		else
			local parts = {}
			for _, m in ipairs(mythics) do
				table.insert(parts, string.format("%s L%d", m.fieldName, m.level))
			end
			local joined = table.concat(parts, ", ")
			hudText = string.format("MYTHIC PUFFSHROOMS (%d): %s", #mythics, joined)
			monitorStatusLabel.Text = string.format("Status: %d MYTHICS (%s)", #mythics, joined)
		end
		monitorStatusLabel.TextColor3 = mythicTextColor
	else
		monitorStroke.Color = uicolor
		monitorAccent.BackgroundColor3 = uicolor
		monitorDot.BackgroundColor3 = Color3.fromRGB(115, 130, 155)
		monitorMainText.TextColor3 = Color3.fromRGB(215, 220, 230)
		monitorBadge.BackgroundColor3 = color_4
		monitorBadge.TextColor3 = Color3.fromRGB(220, 225, 235)
		monitorBadge.Text = "Puffs: " .. total
		hudText = "MYTHIC MONITOR  |  None on map"
		monitorStatusLabel.Text = "Status: No Mythic on map"
		monitorStatusLabel.TextColor3 = Color3.new(1, 1, 1)
	end

	monitorMainText.Text = hudText
	local targetWidth = 440
	local okSize, measured = pcall(function()
		return TextService:GetTextSize(hudText, 13, Enum.Font.GothamBold, Vector2.new(1000, 38))
	end)
	if okSize and measured then
		targetWidth = math.clamp(measured.X + 135, 440, 680)
	end
	monitorFrame.Size = UDim2.new(0, targetWidth, 0, 38)

	if not skipMaintain then
		tokenHider:Maintain()
	end
end

threads:Add("monitor", function()
	while not threads.closed do
		stepMonitor(false)
		task.wait(0.25)
	end
end)

local api
cleanup = function()
	threads:CancelAll()
	connections:CancelAll()
	walkSpeedController:Restore()
	tokenHider:RestoreAll()
	puffVisuals:RestoreAll()
	if ScreenGui and ScreenGui.Parent then
		ScreenGui:Destroy()
	end
	if _G.puffshroomAssistant == api then
		_G.puffshroomAssistant = nil
	end
	if _G.puffshroomAssistantLoading then
		_G.puffshroomAssistantLoading = nil
	end
end

api = {
	gui = ScreenGui,
	cfg = cfg,
	controls = controls,
	Destroy = cleanup,
}

if isTestHarness then
	api.parsePuffshroom = parsePuffshroom
	api.tokenHider = tokenHider
	api.puffVisuals = puffVisuals
	api.walkSpeedController = walkSpeedController
	api.monitorState = monitorState
	api.monitorFrame = monitorFrame
	api.monitorMainText = monitorMainText
	api.monitorBadge = monitorBadge
	api.stepMonitor = stepMonitor
end

_G.puffshroomAssistant = api
_G.puffshroomAssistantLoading = nil

return api
