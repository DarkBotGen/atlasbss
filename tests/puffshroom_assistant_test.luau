-- Offline Luau tests for Puffshroom Assistant (Atlas+ WalkSpeed 90, Token Hider,
-- Puffshroom Transparency for Common/Rare/Epic, and Top Mythic Monitor).

local function createSignal()
	local listeners = {}
	return {
		Connect = function(_, fn)
			local entry = { fn = fn, connected = true }
			table.insert(listeners, entry)
			return {
				Disconnect = function()
					entry.connected = false
				end,
			}
		end,
		Fire = function(_, ...)
			for _, entry in ipairs(listeners) do
				if entry.connected then
					entry.fn(...)
				end
			end
		end,
		ActiveCount = function()
			local n = 0
			for _, entry in ipairs(listeners) do
				if entry.connected then
					n += 1
				end
			end
			return n
		end,
	}
end

local function makeMockInstance(className, name)
	local children = {}
	local inst
	inst = {
		ClassName = className,
		Name = name or className,
		Parent = nil,
		Transparency = 0,
		LocalTransparencyModifier = 0,
		TextTransparency = 0,
		BackgroundTransparency = 0,
		ImageTransparency = 0,
		Enabled = true,
		Text = "",
		Texture = "",
		Position = { X = 0, Y = 0, Z = 0 },
		Size = { X = 100, Y = 20, Z = 100 },
		DescendantAdded = createSignal(),
		ChildAdded = createSignal(),
		ChildRemoved = createSignal(),
		_propSignals = {},
	}
	function inst:IsA(target)
		if target == className then
			return true
		end
		if target == "BasePart" and (className == "Part" or className == "MeshPart" or className == "BasePart") then
			return true
		end
		return false
	end
	function inst:FindFirstChild(childName)
		for _, c in ipairs(children) do
			if c.Name == childName then
				return c
			end
		end
		return nil
	end
	function inst:FindFirstChildOfClass(cls)
		for _, c in ipairs(children) do
			if c:IsA(cls) then
				return c
			end
		end
		return nil
	end
	function inst:GetChildren()
		return table.clone(children)
	end
	function inst:GetDescendants()
		local out = {}
		local function walk(node)
			for _, c in ipairs(node:GetChildren()) do
				table.insert(out, c)
				walk(c)
			end
		end
		walk(self)
		return out
	end
	function inst:GetPropertyChangedSignal(prop)
		if not self._propSignals[prop] then
			self._propSignals[prop] = createSignal()
		end
		return self._propSignals[prop]
	end
	function inst:AddChild(child)
		child.Parent = self
		table.insert(children, child)
		self.ChildAdded:Fire(child)
		self.DescendantAdded:Fire(child)
		return child
	end
	function inst:RemoveChild(child)
		for i, c in ipairs(children) do
			if c == child then
				table.remove(children, i)
				child.Parent = nil
				self.ChildRemoved:Fire(child)
				break
			end
		end
	end
	function inst:SetTexture(tex)
		self.Texture = tex
		if self._propSignals.Texture then
			self._propSignals.Texture:Fire()
		end
	end
	function inst:Destroy()
		self.Parent = nil
	end
	return inst
end

local function makePuffshroom(rarity, level, timeStr, fieldPart)
	local puff = makeMockInstance("Model", "Puffshroom")
	local top = puff:AddChild(makeMockInstance("MeshPart", "Puffball Top"))
	local stem = puff:AddChild(makeMockInstance("Part", "Puffball Stem"))
	local decal = stem:AddChild(makeMockInstance("Decal", "StemDecal"))
	local emitter = top:AddChild(makeMockInstance("ParticleEmitter", "Glow"))
	local attachment = top:AddChild(makeMockInstance("Attachment", "Attachment"))
	local gui = attachment:AddChild(makeMockInstance("BillboardGui", "Gui"))
	local nameRow = gui:AddChild(makeMockInstance("Frame", "NameRow"))
	local nameLbl = nameRow:AddChild(makeMockInstance("TextLabel", "TextLabel"))
	nameLbl.Text = (rarity == "Common" and "Puffshroom" or (rarity .. " Puffshroom")) .. " (Lvl " .. level .. ")"
	local barRow = gui:AddChild(makeMockInstance("Frame", "BarRow"))
	local bar = barRow:AddChild(makeMockInstance("Frame", "Bar"))
	local numLbl = bar:AddChild(makeMockInstance("TextLabel", "NumberLabel"))
	numLbl.Text = timeStr
	stem.Position = fieldPart.Position
	top.Position = fieldPart.Position
	return puff, top, stem, decal, emitter, gui, nameLbl
end

local function makeToken(iconId)
	local token = makeMockInstance("Part", "C")
	local front = token:AddChild(makeMockInstance("Decal", "FrontDecal"))
	front.Texture = "rbxassetid://" .. iconId
	local back = token:AddChild(makeMockInstance("Decal", "BackDecal"))
	back.Texture = "rbxassetid://" .. iconId
	local glow = token:AddChild(makeMockInstance("ParticleEmitter", "Glow"))
	return token, front, back, glow
end

-- Minimal mirror of Puffshroom Assistant logic under test
local cfg = {
	movement = { walkspeedenabled = false, walkdynamic = false, walkspeed = 90, walkspeed2 = 1.5 },
	tokens = { hideHoney = false, hideSoftWax = false, hideBitterberry = false },
	puffshrooms = { transparencyEnabled = true, commonTransparency = 0, rareTransparency = 0, epicTransparency = 0, fadeGui = false },
	monitor = { enabled = true, notifyOnMythic = true },
}

local playerMovespeedStat = 32
local humanoid = { WalkSpeed = 32, Health = 100, Parent = true }

local walkSpeedController = { lastAppliedSpeed = nil, originalSpeed = nil, trackedHumanoid = nil }
function walkSpeedController:Step()
	if not cfg.movement.walkspeedenabled then
		return
	end
	local h = humanoid
	if not h or not h.Parent or h.Health <= 0 then
		return
	end
	if self.trackedHumanoid ~= h then
		self.trackedHumanoid = h
		self.originalSpeed = h.WalkSpeed
		self.lastAppliedSpeed = nil
	end
	local maxCap = math.clamp(tonumber(cfg.movement.walkspeed) or 90, 30, 90)
	local targetSpeed = not cfg.movement.walkdynamic and maxCap or math.min(maxCap, playerMovespeedStat * cfg.movement.walkspeed2)
	local currentSpeed = h.WalkSpeed
	local wasSetByUs = self.lastAppliedSpeed ~= nil and math.abs(currentSpeed - self.lastAppliedSpeed) < 0.05
	if currentSpeed < targetSpeed or (wasSetByUs and currentSpeed > targetSpeed) then
		h.WalkSpeed = targetSpeed
		self.lastAppliedSpeed = targetSpeed
	end
end
function walkSpeedController:Restore()
	local h = self.trackedHumanoid
	if h and h.Parent and self.lastAppliedSpeed ~= nil then
		if math.abs(h.WalkSpeed - self.lastAppliedSpeed) < 0.05 then
			h.WalkSpeed = playerMovespeedStat
		end
	end
	self.lastAppliedSpeed = nil
	self.originalSpeed = nil
	self.trackedHumanoid = nil
end

-- 1. WalkSpeed tests (fixed 90, decrease slider, higher boost preserved, dynamic mode, restore)
cfg.movement.walkspeedenabled = true
walkSpeedController:Step()
assert(humanoid.WalkSpeed == 90, "expected fixed walkspeed 90, got " .. tostring(humanoid.WalkSpeed))

cfg.movement.walkspeed = 65
walkSpeedController:Step()
assert(humanoid.WalkSpeed == 65, "lowering walkspeed slider should lower speed to 65")

humanoid.WalkSpeed = 110
walkSpeedController:Step()
assert(humanoid.WalkSpeed == 110, "external boost > targetSpeed must not be nerfed")

humanoid.WalkSpeed = 65
cfg.movement.walkspeed = 90
cfg.movement.walkdynamic = true
cfg.movement.walkspeed2 = 1.5
walkSpeedController:Step()
assert(humanoid.WalkSpeed == 48, "dynamic mode should compute 32 * 1.5 = 48")

playerMovespeedStat = 70
walkSpeedController:Step()
assert(humanoid.WalkSpeed == 90, "dynamic mode must cap at max walkspeed 90")

walkSpeedController:Restore()
assert(humanoid.WalkSpeed == 70, "restoring walkspeed should return to PlayerMovespeed")

-- 2. Token Hider tests (Honey 1472135114, Soft Wax 8277778300 + EggTypes, Bitterberry 4483236276/6087985073)
local tokenIds = {
	honey = { ["1472135114"] = true, ["1952683491"] = true },
	softWax = { ["8277778300"] = true },
	bitterberry = { ["4483236276"] = true, ["6087985073"] = true },
}
local tokenHider = { ids = tokenIds, saved = {}, watchers = {} }
local function extractTokenIconId(token)
	local front = token:FindFirstChild("FrontDecal")
	return front and string.match(tostring(front.Texture), "%d+") or nil
end
function tokenHider:ShouldHide(token)
	local id = extractTokenIconId(token)
	if not id then return false end
	return (cfg.tokens.hideHoney and self.ids.honey[id])
		or (cfg.tokens.hideSoftWax and self.ids.softWax[id])
		or (cfg.tokens.hideBitterberry and self.ids.bitterberry[id])
		or false
end
function tokenHider:Hide(token)
	local record = self.saved[token] or {}
	self.saved[token] = record
	local function setProp(inst, prop, val)
		record[inst] = record[inst] or {}
		if record[inst][prop] == nil then record[inst][prop] = inst[prop] end
		inst[prop] = val
	end
	setProp(token, "LocalTransparencyModifier", 1)
	setProp(token, "Transparency", 1)
	for _, d in ipairs(token:GetDescendants()) do
		if d:IsA("Decal") then setProp(d, "Transparency", 1)
		elseif d:IsA("ParticleEmitter") then setProp(d, "Enabled", false) end
	end
end
function tokenHider:Restore(token)
	local record = self.saved[token]
	if not record then return end
	self.saved[token] = nil
	for inst, props in pairs(record) do
		for prop, val in pairs(props) do inst[prop] = val end
	end
end
function tokenHider:Evaluate(token)
	if self:ShouldHide(token) then self:Hide(token) else self:Restore(token) end
end

local honeyTok, honeyFront = makeToken("1472135114")
local waxTok, waxFront = makeToken("8277778300")
local bitterTok, bitterFront = makeToken("4483236276")
local linkTok, linkFront = makeToken("1629547638")
honeyTok.Parent, waxTok.Parent, bitterTok.Parent, linkTok.Parent = true, true, true, true

cfg.tokens.hideHoney = true
cfg.tokens.hideSoftWax = true
cfg.tokens.hideBitterberry = true
for _, tok in ipairs({ honeyTok, waxTok, bitterTok, linkTok }) do
	tokenHider:Evaluate(tok)
end
assert(honeyTok.LocalTransparencyModifier == 1 and honeyFront.Transparency == 1, "honey token should be hidden")
assert(waxTok.LocalTransparencyModifier == 1 and waxFront.Transparency == 1, "soft wax token should be hidden")
assert(bitterTok.LocalTransparencyModifier == 1 and bitterFront.Transparency == 1, "bitterberry token should be hidden")
assert(linkTok.LocalTransparencyModifier == 0 and linkFront.Transparency == 0, "token link must stay visible")

cfg.tokens.hideSoftWax = false
tokenHider:Evaluate(waxTok)
assert(waxTok.LocalTransparencyModifier == 0 and waxFront.Transparency == 0, "soft wax should restore when untoggled")

-- 3. Puffshroom Transparency & Mythic Monitor tests
local fieldRose = makeMockInstance("Part", "Rose Field")
fieldRose.Position = { X = -300, Y = 20, Z = 120 }
local fieldPepper = makeMockInstance("Part", "Pepper Patch")
fieldPepper.Position = { X = -480, Y = 120, Z = 530 }

local function getFieldAt(pos)
	if pos.X == fieldRose.Position.X then return fieldRose end
	if pos.X == fieldPepper.Position.X then return fieldPepper end
	return nil
end

local function parsePuff(puff)
	local top = puff:FindFirstChild("Puffball Top")
	local gui = top:FindFirstChild("Attachment"):FindFirstChild("Gui")
	local text = gui:FindFirstChild("NameRow"):FindFirstChild("TextLabel").Text
	local rawRarity = string.match(text, "(%a*)%s+Puffshroom")
	local rarity = (rawRarity and rawRarity ~= "") and rawRarity or "Common"
	local level = tonumber(string.match(text, "Lvl (%d+)")) or 1
	local timeText = gui:FindFirstChild("BarRow"):FindFirstChild("Bar"):FindFirstChild("NumberLabel").Text
	local stem = puff:FindFirstChild("Puffball Stem")
	local field = getFieldAt(stem.Position)
	return { instance = puff, rarity = rarity, level = level, timeText = timeText, fieldName = field and field.Name or "Unknown Field" }
end

local puffCommon, cTop, cStem, cDecal, cEmit, cGui, cLbl = makePuffshroom("Common", 4, "2:30", fieldRose)
local puffRare, rTop, rStem = makePuffshroom("Rare", 8, "3:15", fieldRose)
local puffEpic, eTop, eStem = makePuffshroom("Epic", 12, "4:00", fieldPepper)
local puffMythic, mTop, mStem, mDecal, mEmit = makePuffshroom("Mythic", 16, "4:45", fieldPepper)

assert(parsePuff(puffCommon).rarity == "Common" and parsePuff(puffCommon).level == 4 and parsePuff(puffCommon).fieldName == "Rose Field")
assert(parsePuff(puffRare).rarity == "Rare" and parsePuff(puffRare).level == 8)
assert(parsePuff(puffEpic).rarity == "Epic" and parsePuff(puffEpic).level == 12)
assert(parsePuff(puffMythic).rarity == "Mythic" and parsePuff(puffMythic).level == 16 and parsePuff(puffMythic).fieldName == "Pepper Patch")

local function applyPuffAlpha(puff, alpha, fadeGui)
	for _, inst in ipairs(puff:GetDescendants()) do
		if inst:IsA("BasePart") then
			inst.LocalTransparencyModifier = alpha
		elseif inst:IsA("Decal") then
			inst.Transparency = alpha
		elseif inst:IsA("ParticleEmitter") then
			inst.Enabled = alpha < 0.95
		elseif fadeGui and inst:IsA("BillboardGui") then
			inst.Enabled = alpha < 1
		elseif fadeGui and inst:IsA("TextLabel") then
			inst.TextTransparency = alpha
		end
	end
end

cfg.puffshrooms.commonTransparency = 0.8
cfg.puffshrooms.rareTransparency = 0.5
cfg.puffshrooms.epicTransparency = 0.3
applyPuffAlpha(puffCommon, cfg.puffshrooms.commonTransparency, true)
applyPuffAlpha(puffRare, cfg.puffshrooms.rareTransparency, false)
applyPuffAlpha(puffEpic, cfg.puffshrooms.epicTransparency, false)
applyPuffAlpha(puffMythic, 0, true)

assert(math.abs(cTop.LocalTransparencyModifier - 0.8) < 1e-6 and math.abs(cDecal.Transparency - 0.8) < 1e-6 and math.abs(cLbl.TextTransparency - 0.8) < 1e-6)
assert(math.abs(rTop.LocalTransparencyModifier - 0.5) < 1e-6)
assert(math.abs(eTop.LocalTransparencyModifier - 0.3) < 1e-6)
assert(mTop.LocalTransparencyModifier == 0 and mDecal.Transparency == 0 and mEmit.Enabled == true, "Mythic puffshrooms must stay 100% visible")

print("PASS: Puffshroom Assistant walkspeed, token hiding, puffshroom transparency, and mythic parsing verified")
