
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
function TweenService:Create(part,duration,goal)
 local t={part=part,goal=goal.CFrame.Position,speed=(goal.CFrame.Position-part.Position).Magnitude/duration}
 liveTweens+=1
 function t:Play()activeTween=self end
 function t:Cancel()if activeTween==self then activeTween=nil end end
 function t:Destroy()assert(not self.destroyed);self.destroyed=true;liveTweens-=1 end
 return t
end
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
-- Shared tween controller: earliest reachable impact first, through the last star.
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

function showerController:Speed()
	return 400
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
	return math.max(0, distance - 1.5) / self:Speed(distance, remaining) <= math.max(0, remaining - 0.04)
end

function showerController:Select(opts, rootPosition)
	if not cfg.autofarm.farmshowers or opts.nowait or opts.loot or opts.mondotokens then return end
	local now = os.clock()
	self:Prune(now)
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
	if self.tween then
		self.tween:Cancel()
		self.tween:Destroy()
		self.tween = nil
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
	local nextUpdate, nextOrderCheck, lastGoal = 0, 0, nil
	humanoid:MoveTo(root.Position)
	smoothMovement.goal = nil
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
			if now >= nextOrderCheck then
				nextOrderCheck = now + 0.05
				local first = self:Select(opts, root.Position)
				if first and first ~= object then return true end
			end
			local dx, dz = position.X - root.Position.X, position.Z - root.Position.Z
			local distance = math.sqrt(dx * dx + dz * dz)
			arrived = distance <= 1.5
			-- Release immediately after impact rather than waiting the old 5s timeout.
			if remaining <= -0.08 or (remaining <= 0 and not arrived) then break end
			if now >= nextUpdate and not arrived then
				nextUpdate = now + 0.05
				local goal = Vector3.new(position.X, root.Position.Y, position.Z)
				if not lastGoal or (goal-lastGoal).Magnitude > 0.5 then
					if self.tween then self.tween:Cancel(); self.tween:Destroy() end
					self.tween = TweenService:Create(root,
						TweenInfo.new(math.max(0.025, distance/self:Speed()), Enum.EasingStyle.Linear, Enum.EasingDirection.Out),
						{CFrame=CFrame.new(goal)*root.CFrame.Rotation})
					self.tween:Play()
					lastGoal = goal
				end
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

local function add(x,duration)
 local o={Name=true,Position=vec(x,0,0)}
 tracked.showers[o]=true;showerController:Observe(o,duration)
 return o
end
local function clear()
 showerController:Reset();table.clear(tracked.showers)
 now=0;state={};humanoid.Health=100;root.Position=vec(0,0,0);walkGoal=nil;tickHook=nil
 cfg.autofarm.enabled=false
end
local first=add(60,1.1);local near=add(5,1.5)
assert(showerController:Select({},root.Position)==first,"nearest selected ahead of earliest impact")
local earlier=add(20,0.9)
assert(showerController:Select({},root.Position)==earlier,"new earlier landing ignored")
clear()
local impossible=add(200,0.1);local reachable=add(10,1.1)
assert(showerController:Select({},root.Position)==reachable)
clear()
local stars={}
for i=1,10 do stars[i]=add(i*20,0.7+i*0.3)end
for i=1,10 do
 local target=showerController:Select({},root.Position)
 assert(target==stars[i],"incorrect landing order")
 showerController:Collect(target,{})
 assert((root.Position-target.Position).Magnitude<=1.5,"impact missed")
 assert(liveTweens==0 and humanoid.WalkSpeed==40,"movement or speed leaked")
end
assert(now<4 and not showerController:Select({},root.Position))
clear()
local target=add(200,1.5);local urgent
tickHook=function()if not urgent then urgent=add(40,0.2)end end
showerController:Collect(target,{})
assert(liveTweens==0 and showerController:Select({},root.Position)==urgent,"earlier landing did not interrupt later tween")
clear()
target=add(100,1.9);tickHook=function()state.stop=true end
showerController:Collect(target,{});assert(liveTweens==0)
clear()
target=add(100,1.9);tickHook=function()state.preempt=true end
showerController:Collect(target,{});assert(liveTweens==0)
clear()
target=add(100,1.9);tickHook=function()showerController:CancelMovement()end
showerController:Collect(target,{});assert(liveTweens==0)
clear()
target=add(100,1.9);tickHook=function()error("expected")end
assert(not pcall(function()showerController:Collect(target,{})end));assert(liveTweens==0)
clear()
state.preempt=true;target=add(30,1.9)
showerController:Collect(target,{standalone=true,ignorefield=true,showerfield="field"})
assert((root.Position-target.Position).Magnitude<=1.5 and liveTweens==0)
clear()
target=add(100,1.9);tickHook=function()cfg.autofarm.enabled=true end
showerController:Collect(target,{standalone=true});assert(liveTweens==0)
clear()
for i=1,10000 do add(i,0.1)end
now=1;showerController:Prune(now)
assert(next(showerController.entries)==nil and liveTweens==0)
assert(humanoid.WalkSpeed==40)
print("PASS: earliest impact before nearest, new earlier star rerouting, ten-star landing order, impossible skips, centered tween arrival, stop/preemption/cancel/error cleanup, standalone/handoff, 10,000 expiries; WalkSpeed unchanged")
