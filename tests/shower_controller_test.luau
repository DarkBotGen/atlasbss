
local now=0
local os={clock=function()return now end}
local function typeof(v)return type(v)=="table" and v.instance and "Instance" or type(v)end
local mt={}
local function vec(x,y,z)return setmetatable({X=x,Y=y,Z=z},mt)end
mt.__sub=function(a,b)return vec(a.X-b.X,a.Y-b.Y,a.Z-b.Z)end
mt.__index=function(v,k)if k=="Magnitude" then return math.sqrt(v.X*v.X+v.Y*v.Y+v.Z*v.Z)end end
local peakSpeed=0
local Vector3={new=vec}
local CFrame={new=function(goal)return setmetatable({Position=goal},{__mul=function(a)return a end})end}
local TweenInfo={new=function(duration)return duration end}
local Enum={EasingStyle={Linear=1},EasingDirection={Out=1}}
local root={Position=vec(0,0,0),CFrame={Rotation={}}}
local humanoid={WalkSpeed=40,Health=100}
local function getRootPart()return root end
local function getHumanoid()return humanoid end
local function getFieldAt(p)return p.X<500 and "field" or "other"end
local state={}
local cfg={autofarm={farmshowers=true,dynamicshowerspeed=true,showerspeedcap=200},detected={fastshowertween=true}}
local tracked={showers={}}
local gatheringPriorities={Allowed=function(_,p,opts)return (not opts.range or p.X<=opts.range) and p.X~=99 end,ShouldPreempt=function()return state.preempt end}
local walkGoal,activeTween,liveTweens=nil,nil,0
local TweenService={Create=function(_,part,duration,_,goal)
 error("wrong create signature")
end}
function TweenService:Create()error("shower attempted tween")end
function humanoid:MoveTo(goal)walkGoal=goal end
local smoothMovement={MoveTo=function(_,goal)walkGoal=goal end}
local tickHook
local RunService={Heartbeat={Wait=function()
 now+=0.02
 peakSpeed=math.max(peakSpeed,humanoid.WalkSpeed)
 local goal=activeTween and activeTween.goal or walkGoal
 if goal then
  local distance=(goal-root.Position).Magnitude
  local speed=activeTween and activeTween.speed or humanoid.WalkSpeed
  local f=distance>0 and math.min(1,speed*0.02/distance)or 1
  root.Position=vec(root.Position.X+(goal.X-root.Position.X)*f,0,root.Position.Z+(goal.Z-root.Position.Z)*f)
 end
 if tickHook then tickHook() end
 return 0.02
end}}
-- Shared walking controller for gathering and showers without autofarm.
local showerController = {entries = {}, sequence = 0}

function showerController:Observe(object, duration)
	if self.entries[object] then return self.entries[object] end
	self.sequence += 1
	local now = os.clock()
	local entry = {started = now, deadline = now + math.max(0.1, tonumber(duration) or 1.9), order = self.sequence}
	self.entries[object] = entry
	return entry
end

function showerController:Forget(object)
	self.entries[object] = nil
	if self.target == object then self.target = nil end
end

function showerController:Prune(now)
	for object, entry in pairs(self.entries) do
		if tracked and now > entry.deadline + 0.15 then tracked.showers[object] = nil end
		if not tracked or not tracked.showers[object] or now > entry.deadline + 0.15 or
			(typeof(object) == "Instance" and not object.Parent) then self:Forget(object) end
	end
end

function showerController:Speed(distance, remaining)
	local walking = self:BaseSpeed(getHumanoid())
	if cfg.autofarm.dynamicshowerspeed == false then return walking end
	local cap = math.clamp(tonumber(cfg.autofarm.showerspeedcap) or 120, 40, 200)
	-- Aim to arrive before impact; distant/late stars request more speed.
	local required = distance / math.max(remaining - 0.15, 0.04) * 1.15
	return math.max(walking, math.min(cap, math.max(walking * 1.15, required)))
end

function showerController:BaseSpeed(humanoid)
	local current = math.max(1, humanoid.WalkSpeed)
	local lease = self.speedLease
	if lease and lease.humanoid == humanoid then
		-- Respect speed changes from buffs or other systems while approaching.
		if math.abs(current - lease.applied) > 0.01 then lease.base = current end
		return lease.base
	end
	return current
end

function showerController:ReleaseSpeed()
	local lease = self.speedLease
	self.speedLease = nil
	if not lease then return end
	pcall(function()
		-- Restore only a value we still own; never overwrite a newer game update.
		if math.abs(lease.humanoid.WalkSpeed - lease.applied) <= 0.01 then
			lease.humanoid.WalkSpeed = lease.base
		end
	end)
end

function showerController:ApplySpeed(humanoid, speed)
	local base = self:BaseSpeed(humanoid)
	local lease = self.speedLease
	if lease and lease.humanoid ~= humanoid then self:ReleaseSpeed(); lease = nil end
	if not lease then lease = {humanoid=humanoid, base=base}; self.speedLease = lease end
	lease.applied = speed
	humanoid.WalkSpeed = speed
end

function showerController:ReleaseDensity()
	local lease = self.densityLease
	self.densityLease = nil
	if not lease then return end
	for part, saved in pairs(lease.parts) do
		pcall(function()
			if part.CustomPhysicalProperties == saved.applied then
				part.CustomPhysicalProperties = saved.original
			end
		end)
	end
	table.clear(lease.parts)
end

function showerController:ApplyDensity(root)
	local character = root.Parent
	if not character then return end
	if self.densityLease and self.densityLease.character == character then return end
	self:ReleaseDensity()
	local lease = {character=character, parts={}}
	self.densityLease = lease
	-- One snapshot per active star, not a character scan on every heartbeat.
	for _, part in ipairs(character:GetDescendants()) do
		if not part:IsA("BasePart") then continue end
		local original = part.CustomPhysicalProperties
		local current = part.CurrentPhysicalProperties
		local density = math.min(100, current.Density * 10)
		local ok, boosted = pcall(function()
			return PhysicalProperties.new(density, current.Friction, current.Elasticity,
				current.FrictionWeight, current.ElasticityWeight, current.AcousticAbsorption)
		end)
		if not ok then
			boosted = PhysicalProperties.new(density, current.Friction, current.Elasticity,
				current.FrictionWeight, current.ElasticityWeight)
		end
		lease.parts[part] = {original=original, applied=boosted}
		part.CustomPhysicalProperties = boosted
	end
end

function showerController:Eligible(object, entry, opts, rootPosition, now)
	if entry.done or not tracked.showers[object] or now >= entry.deadline then return false end
	if typeof(object) == "Instance" and not object.Parent then return false end
	local position = object.Position
	if opts.showerfield and getFieldAt(position) ~= opts.showerfield then return false end
	if not gatheringPriorities:Allowed(position, opts, rootPosition) then return false end
	local dx, dz = position.X - rootPosition.X, position.Z - rootPosition.Z
	local distance = math.sqrt(dx * dx + dz * dz)
	local remaining = entry.deadline - now
	return math.max(0, distance - 3) / self:Speed(distance, remaining) <= math.max(0, remaining - 0.04)
end

function showerController:Select(opts, rootPosition)
	if not cfg.autofarm.farmshowers or opts.nowait or opts.loot or opts.mondotokens then return end
	local now = os.clock()
	self:Prune(now)
	if self.target then
		local entry = self.entries[self.target]
		if entry and self:Eligible(self.target, entry, opts, rootPosition, now) then return self.target end
		self.target = nil
	end
	local best, bestEntry
	for object in pairs(tracked.showers) do
		-- New observations normally happen in the spawn handler, before selection.
		local entry = self.entries[object] or self:Observe(object, 1.9)
		if self:Eligible(object, entry, opts, rootPosition, now) and
			(not bestEntry or entry.deadline < bestEntry.deadline or
				(entry.deadline == bestEntry.deadline and entry.order < bestEntry.order)) then
			best, bestEntry = object, entry
		end
	end
	self.target = best
	return best
end

function showerController:CancelMovement()
	self.generation = (self.generation or 0) + 1
	self:ReleaseSpeed()
	self:ReleaseDensity()
	local humanoid, root = self.walkHumanoid, self.walkRoot
	self.walkHumanoid, self.walkRoot = nil, nil
	if humanoid and root then
		pcall(function() humanoid:MoveTo(root.Position) end)
		smoothMovement.goal = nil
	end
end

function showerController:Reset()
	self:CancelMovement()
	self.target = nil
	table.clear(self.entries)
end

function showerController:Collect(object, opts)
	local entry = self.entries[object]
	if not entry then return end
	self:CancelMovement()
	local generation = self.generation
	self.target = object
	local root, humanoid = getRootPart(), getHumanoid()
	local nextUpdate = 0
	local arrived = false
	local ok, result = xpcall(function()
		while self.generation == generation and tracked and tracked.showers[object] and cfg.autofarm.farmshowers and not state.stop and humanoid.Health > 0 do
			if opts.standalone and cfg.autofarm.enabled then return true end
			if getRootPart() ~= root or not object.Position or
				(typeof(object) == "Instance" and not object.Parent) then break end
			local now = os.clock()
			local remaining = entry.deadline - now
			local position = object.Position
			if opts.showerfield and getFieldAt(position) ~= opts.showerfield then break end
			if not gatheringPriorities:Allowed(position, opts, root.Position) then break end
			if not opts.standalone and gatheringPriorities:ShouldPreempt() then return true end
			self:ApplyDensity(root)
			local dx, dz = position.X - root.Position.X, position.Z - root.Position.Z
			local distance = math.sqrt(dx * dx + dz * dz)
			arrived = distance <= 3
			if arrived then self:ReleaseSpeed() end
			-- Release immediately after impact rather than waiting the old 5s timeout.
			if remaining <= -0.08 or (remaining <= 0 and not arrived) then break end
			if now >= nextUpdate and not arrived then
				nextUpdate = now + 0.1
				local speed = self:Speed(distance, remaining)
				if cfg.autofarm.dynamicshowerspeed ~= false then self:ApplySpeed(humanoid, speed)
				else self:ReleaseSpeed() end
				self.walkHumanoid, self.walkRoot = humanoid, root
				smoothMovement:MoveTo(position)
			end
			if not RunService.Heartbeat:Wait() then break end
		end
		entry.done = true
		return true
	end, debug.traceback)
	self:CancelMovement()
	if entry.done then self.target = nil end
	if not ok then self.target = nil; error(result,0) end
	return result
end

smoothMovement.showerController = showerController

local function add(x,duration,physical)
 local object={Name=true,Position=vec(x,0,0)}
 if physical then object.instance=true;object.Parent=true end
 tracked.showers[object]=true;showerController:Observe(object,duration)
 return object
end
local function clear()
 showerController:Reset();table.clear(tracked.showers)
 now=0;state={};root.Position=vec(0,0,0);humanoid.Health=100;humanoid.WalkSpeed=40;cfg.autofarm.enabled=false;walkGoal=nil;tickHook=nil
end
local first=add(30,1.9);now=0.05;local nearest=add(3,1.9)
assert(showerController:Select({},root.Position)==first,"nearest displaced first falling star")
root.Position=vec(2,0,0);assert(showerController:Select({},root.Position)==first,"lock oscillated")
tracked.showers[first]=nil;assert(showerController:Select({},root.Position)==nearest)
clear()
local impossible=add(200,0.1);local reachable=add(10,1.9)
assert(showerController:Select({},root.Position)==reachable,"unreachable first blocked queue")
clear()
local outside=add(600,1.9);local hazard=add(99,1.9);local good=add(20,1.9)
assert(showerController:Select({showerfield="field",range=50},root.Position)==good)
local slow=showerController:Speed(20,1.8);local fast=showerController:Speed(100,0.4)
assert(fast>slow and fast<=200)
cfg.detected.fastshowertween=false;assert(showerController:Speed(100,0.1)>40)
cfg.detected.fastshowertween=true;cfg.autofarm.dynamicshowerspeed=false
assert(showerController:Speed(100,0.1)==40)
cfg.autofarm.dynamicshowerspeed=true
clear()
local stars={}
for i=1,10 do stars[i]=add(i*12,0.8+i*0.3)end
for i=1,10 do
 local target=showerController:Select({},root.Position)
 assert(target==stars[i],"falling order skipped")
 assert(showerController:Collect(target,{}))
 assert((root.Position-target.Position).Magnitude<=3,"missed deadline")
 assert(liveTweens==0,"completed movement leaked tween")
end
assert(now<4 and not showerController:Select({},root.Position),"old 5s wait or repeat target")
assert(peakSpeed>40 and humanoid.WalkSpeed==40,"walking boost missing or not restored")
now+=1;showerController:Prune(now);assert(next(showerController.entries)==nil)
clear()
local target=add(100,1.9);tickHook=function()state.preempt=true end
showerController:Collect(target,{})
assert(liveTweens==0 and not showerController.entries[target].done,"preemption lost/released target")
state.preempt=nil;tickHook=function()state.stop=true end
showerController:Collect(target,{})
assert(liveTweens==0)
clear()
cfg.detected.fastshowertween=false
target=add(30,1.9);showerController:Collect(target,{})
assert(humanoid.WalkSpeed==40 and (root.Position-target.Position).Magnitude<=3)
clear()
-- Restore on cancellation while preserving an external buff update.
showerController:ApplySpeed(humanoid,100);assert(humanoid.WalkSpeed==100)
showerController:CancelMovement();assert(humanoid.WalkSpeed==40)
showerController:ApplySpeed(humanoid,100);humanoid.WalkSpeed=32
assert(showerController:BaseSpeed(humanoid)==32)
showerController:ApplySpeed(humanoid,80);showerController:CancelMovement()
assert(humanoid.WalkSpeed==32)
showerController:ApplySpeed(humanoid,80);humanoid.WalkSpeed=28
showerController:CancelMovement();assert(humanoid.WalkSpeed==28)
clear()
state.preempt=true;target=add(30,1.9)
showerController:Collect(target,{standalone=true,ignorefield=true,showerfield="field"})
assert(showerController.entries[target].done and humanoid.WalkSpeed==40)
clear()
target=add(100,1.9);tickHook=function()cfg.autofarm.enabled=true end
showerController:Collect(target,{standalone=true})
assert(humanoid.WalkSpeed==40 and not showerController.entries[target].done)
clear()
target=add(100,1.9);tickHook=function()showerController:CancelMovement()end
showerController:Collect(target,{})
assert(humanoid.WalkSpeed==40 and not showerController.speedLease)
clear()
for i=1,10000 do add(i,0.1)end
now=1;showerController:Prune(now)
assert(next(showerController.entries)==nil and not showerController.target)
assert(liveTweens==0)
print("PASS: first-falling selection, stable lock, unreachable skips, field/range/hazards, deadline-based speed and cap, 10-star sequence, walking speed preserved, preemption/stop/restore cleanup, external buff changes, standalone collection/handoff, 10,000 expired records")
