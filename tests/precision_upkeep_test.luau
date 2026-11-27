local now=0
local os={clock=function()return now end}
local warns={}
local function warn(v)warns[#warns+1]=v end
local env={}
local function getgenv()return env end
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
 end
 return setmetatable({X=x,Y=y,Z=z},mt)
end
local Vector2={new=function(x,y)return vector(x,y)end}
local Vector3={new=vector,zero=vector(0,0,0)}
local Color3={new=function(r,g,b)return {R=r,G=g,B=b}end,fromRGB=function(r,g,b)return {R=r/255,G=g/255,B=b/255}end}
local UDim={new=function(s,o)return {Scale=s,Offset=o}end}
local UDim2={new=function(xs,xo,ys,yo)return {X=UDim.new(xs,xo),Y=UDim.new(ys,yo)}end}
function UDim2.fromOffset(x,y)return UDim2.new(0,x,0,y)end
function UDim2.fromScale(x,y)return UDim2.new(x,0,y,0)end
local Enum=setmetatable({RenderPriority={Character={Value=100}}},{__index=function(t,k)
 local e=setmetatable({},{__index=function(t,n)rawset(t,n,n);return n end});rawset(t,k,e);return e
end})
local liveConnections=0
local function signal()
 local listeners={}
 local s={}
 function s:Connect(fn)
  local c={Connected=true,fn=fn};listeners[c]=true;liveConnections+=1
  function c:Disconnect()if self.Connected then self.Connected=false;listeners[self]=nil;liveConnections-=1 end end
  return c
 end
 function s:Fire(...)
  local snapshot={};for c in pairs(listeners)do snapshot[#snapshot+1]=c end
  for _,c in ipairs(snapshot)do if c.Connected then c.fn(...)end end
 end
 function s:Wait()coroutine.yield()end
 function s:Clear()local snapshot={};for c in pairs(listeners)do snapshot[#snapshot+1]=c end;for _,c in ipairs(snapshot)do c:Disconnect()end end
 return s
end
local function ancestors(o,property,subject)
 while o do o[property]:Fire(subject);o=o.Parent end
end
local methods={}
local Instance={}
function Instance.new(class,parent)
 local data={ClassName=class,Name=class,children={},signals={},attributes={},Visible=true,Enabled=true,Image="",ImageTransparency=0,
  Health=100,WalkSpeed=40,controlsEnabled=true,Position=Vector3.zero,Size=vector(1,1,1),Color=Color3.new(1,1,1),Material="Plastic",
  AssemblyLinearVelocity=Vector3.zero,AssemblyAngularVelocity=Vector3.zero,CameraType="Custom"}
 for _,name in ipairs({"DescendantAdded","DescendantRemoving","Destroying","Activated","InputBegan","InputChanged","InputEnded","ChildAdded","ChildRemoved"})do data[name]=signal()end
 local object=setmetatable({}, {
  __index=function(_,key)
   if methods[key]then return methods[key]end
   if data[key]~=nil then return data[key]end
   for _,c in ipairs(data.children)do if c.Name==key then return c end end
  end,
  __newindex=function(self,key,value)
   if key=="Parent"then
    local old=data.Parent;if old==value then return end
    if old then
     ancestors(old,"DescendantRemoving",self)
     for _,d in ipairs(self:GetDescendants())do ancestors(old,"DescendantRemoving",d)end
     for i,c in ipairs(old.children)do if c==self then table.remove(old.children,i);break end end
     old.ChildRemoved:Fire(self)
    end
    data.Parent=value
    if value then
     value.children[#value.children+1]=self;value.ChildAdded:Fire(self)
     ancestors(value,"DescendantAdded",self)
     for _,d in ipairs(self:GetDescendants())do ancestors(value,"DescendantAdded",d)end
    end
   else data[key]=value;if data.signals[key]then data.signals[key]:Fire()end end
  end,
 })
 if parent then object.Parent=parent end
 return object
end
function methods:IsA(class)return self.ClassName==class or class=="BasePart" and (self.ClassName=="Part" or self.ClassName=="MeshPart")end
function methods:GetChildren()return table.clone(self.children)end
function methods:GetDescendants()local result={};local function walk(n)for _,c in ipairs(n.children)do result[#result+1]=c;walk(c)end end;walk(self);return result end
function methods:FindFirstChild(name)for _,c in ipairs(self.children)do if c.Name==name then return c end end end
function methods:FindFirstChildOfClass(class)for _,c in ipairs(self.children)do if c:IsA(class)then return c end end end
function methods:FindFirstAncestorWhichIsA(class)local p=self.Parent;while p do if p:IsA(class)then return p end;p=p.Parent end end
function methods:IsDescendantOf(ancestor)local p=self.Parent;while p do if p==ancestor then return true end;p=p.Parent end;return false end
function methods:WaitForChild(name)return assert(self:FindFirstChild(name),name)end
function methods:GetPropertyChangedSignal(name)if not self.signals[name]then self.signals[name]=signal()end;return self.signals[name]end
function methods:SetAttribute(name,value)self.attributes[name]=value end
function methods:GetAttribute(name)return self.attributes[name]end
function methods:Move(direction)self.direction=direction end
function methods:MoveTo(position)self.direction=Vector3.zero end
function methods:Destroy()
 if self.destroyed then return end
 self.Destroying:Fire();self.Parent=nil
 for _,child in ipairs(self:GetChildren())do child:Destroy()end
 for _,s in pairs(self.signals)do s:Clear()end
 for _,name in ipairs({"DescendantAdded","DescendantRemoving","Destroying","Activated","InputBegan","InputChanged","InputEnded","ChildAdded","ChildRemoved"})do self[name]:Clear()end
 self.destroyed=true
end
local deferred={}
local task={}
function task.defer(fn)deferred[#deferred+1]=fn end
function task.spawn(thread)local ok,e=coroutine.resume(thread);assert(ok,e)end
function task.cancel(thread)coroutine.close(thread)end
function task.delay(_,thread)task.spawn(thread)end
function task.wait()coroutine.yield()end
local RunService={Heartbeat=signal(),bound={}}
function RunService:BindToRenderStep(name,_,fn)self.bound[name]=fn end
function RunService:UnbindFromRenderStep(name)self.bound[name]=nil end
local world=Instance.new("Folder");world.Name="Workspace"
local workspace=world
workspace.CurrentCamera=Instance.new("Camera")
local particles=Instance.new("Folder",world);particles.Name="Particles"
local player={Name="Tester",UserId=123,PlayerGui=Instance.new("PlayerGui"),PlayerScripts=Instance.new("Folder")}
function player:WaitForChild(name)return assert(self[name],name)end
local character=Instance.new("Model",world);player.Character=character
local h=Instance.new("Humanoid",character)
local root=Instance.new("Part",character);root.Name="HumanoidRootPart";root.Position=vector(0,3,0)
local head=Instance.new("Part",character);head.Name="Head"
local controlModule=Instance.new("ModuleScript",player.PlayerScripts);controlModule.Name="PlayerModule"
local controls={controlsEnabled=true,Disable=function(self)self.controlsEnabled=false end,Enable=function(self)self.controlsEnabled=true end}
local function require()return {GetControls=function()return controls end}end
local Players={LocalPlayer=player,list={player}}
function Players:GetPlayers()return self.list end
local Input={InputBegan=signal(),InputChanged=signal(),InputEnded=signal()}
local actionService={bound={}}
function actionService:BindActionAtPriority(name,fn)self.bound[name]=fn end
function actionService:UnbindAction(name)self.bound[name]=nil end
local services={Players=Players,RunService=RunService,UserInputService=Input,ContextActionService=actionService,
 Stats={Network={ServerStatsItem={["Data Ping"]={GetValue=function()return 25 end}}}}}
local game={GetService=function(_,name)return assert(services[name],name)end}
local function getService(name)return game:GetService(name)end
local function getRootPart()return root end
local state={}
local cfg={autofarm={enabled=true,farmshowers=true},detected={background=false}}
local smoothMovement={Reset=function(self)if self.showerController then self.showerController:CancelMovement()end end}
local function stopMovement()smoothMovement:Reset()end
local threads={list={},closed=false}
local connections={list={},closed=false}
local function worker()coroutine.yield()end
local function step(dt)
 now+=dt
 local batch=deferred;deferred={};for _,fn in ipairs(batch)do fn()end
 RunService.Heartbeat:Fire(dt)
 for _,fn in pairs(RunService.bound)do fn()end
 if h.direction and h.Health>0 then root.Position=root.Position+h.direction*(h.WalkSpeed*dt)end
end
local function makePart(name,position)
 local o=Instance.new("Part");o.Name=name;o.Position=position
 if name=="WarningDisk"then o.Size=vector(8,0.4,8);o.Material=Enum.Material.Neon;o.Color=Color3.fromRGB(50,255,50);Instance.new("CylinderMesh",o)end
 o.Parent=particles;return o
end

local localPlayer=player
local currentField={Name="Pepper Patch"}
local function getFieldAt(p)return p.Z==999 and nil or currentField end
local function getHumanoid()return h end
local function distanceTo(p)return (p-root.Position).Magnitude end
local function isPathClear(_,avoid)return avoid.wall or nil end
local function getRootPart()return root end
player.CoreStats={Pollen={Value=90},Capacity={Value=100}}
cfg.autofarm.enabled=true;cfg.autofarm.farmprecise=true;cfg.autofarm.farmprecisemark=true;cfg.autofarm.precisionupkeep=true;cfg.autofarm.autoscorchingstar=true
cfg.convert={standInPrecise=true,standInPreciseAt=75}
cfg.prioritization={enabled=false}
state.activityStatus=1
local buffs={}
local touchedMarks={}
local tracked={precise={},precise2={},precisegroup={},precisemark={},tokens={}}
local comboController={active=false,blocked=false,TravelBlocked=function(self)return self.blocked end}
local showerController={active=false}
local gatheringPriorities={}
local comboCandidate
function gatheringPriorities:Candidate()return comboCandidate,comboCandidate and {}end
function gatheringPriorities:Pick()return "Token",{}end
local bearCombat={active=false,Pick=function()return "Token",{}end}
local pickTarget
local function buff(stacks,left)buffs.Precision={Text={Text=stacks},Percent={Size={Y={Scale=left}}}}end
local normal={Position=vector(20,3,0),BrickColor={Name="Red flip/flop"}}
local purple={Position=vector(5,3,0),BrickColor={Name="Alder"}}
tracked.precise[normal]=true;tracked.precise[purple]=true
local function typeof(v)
 if type(v)=="table" and v.ClassName then return "Instance"end
 if type(v)=="table" and v.X and v.Y and v.Z then return "Vector3"end
 return type(v)
end
local fieldPositionPolicy={}
function fieldPositionPolicy:Allowed(goal,opts)
	local area=opts and opts.area
	return not area or (goal.X>=area.minX and goal.X<=area.maxX and goal.Z>=area.minZ and goal.Z<=area.maxZ)
end
function fieldPositionPolicy:TargetPosition(object)
	if typeof(object)=="Vector3" then return object end
	if type(object)=="table" and typeof(object.Position)=="Vector3" then return object.Position end
	if typeof(object)=="Instance" then
		if object:IsA("BasePart") then return object.Position end
		local part=object:FindFirstChild("Plane") or object:FindFirstChild("Stem") or object:FindFirstChild("BalloonRoot")
		if part and part:IsA("BasePart") then return part.Position end
	end
end
function fieldPositionPolicy:TrackedAllowed(key,value,opts)
	if not opts.area then return true end
	local goal=self:TargetPosition(key) or self:TargetPosition(value)
	return not goal or self:Allowed(goal,opts)
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
	if farm.precisionupkeep==false or not farm.enabled or state.activityStatus~=1
		or opts.loot or opts.mondotokens then return end
	if comboController.active or showerController.active or comboController:TravelBlocked() then return end
	local mode, marks = self:PrecisionMode()
	local copy=self:PrecisionOptions(opts)
	if mode ~= "mark" then
		for target in pairs(tracked.precise)do copy.avoid[target]=nil end
		for _,target in pairs(tracked.precise2)do copy.avoid[target]=nil;copy.avoid[target.Position]=nil end
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
									if not ((not opts.ignorefield or getFieldAt(k.Position)) and not (not opts.ignorefield and getFieldAt(k.Position) == currentField) or (not (upkeep and preciseKind=="Precise Purple") and not (not opts.avoid or not isPathClear(k.Position, opts.avoid)))) then
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
									if not ((not opts.ignorefield or getFieldAt(preciseMark.Position)) and not (not opts.ignorefield and getFieldAt(preciseMark.Position) == currentField) or (not (upkeep and precise2Kind=="Precise2Purple") and not (not opts.avoid or not isPathClear(preciseMark.Position, opts.avoid)))) then
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

		pickTarget = function(opts)
			if showerController.active then return "Safeshower" end
			local comboKind, comboObject = gatheringPriorities:Candidate("Combo Coconuts", opts, getRootPart().Position)
			if comboKind then return comboKind, comboObject end
			local precisionKind,precisionObject=gatheringPriorities:PrecisionUpkeep(opts)
			if precisionKind then gatheringPriorities.last="Precise Targets";return precisionKind,precisionObject end
			local combatKind, combatObject = bearCombat:Pick(opts)
			bearCombat.active = combatKind ~= nil
            if combatKind then
                gatheringPriorities.last = combatKind == "Token" and "Priority Tokens" or combatKind == "Duped Bear" and "Duped Bear" or "Duped Tokens"
                return combatKind, combatObject
            end
end
function gatheringPriorities:ShouldPreempt()
	if showerController.active then return true end
	if self.activeCategory == "Combo Coconuts" then return false end
	if self.activeCategory ~= "Combo Coconuts" and self:Candidate("Combo Coconuts", self.activeOptions or {}, getRootPart().Position) then return true end
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
    if not cfg.prioritization.enabled or not self.activeCategory then return false end
    return self:Pick(self.activeOptions or {}, self.activeCategory) ~= nil
end
local opts={}
local greenDone={Position=vector(3,3,0),BrickColor={Name="Lime green"}}
local brightGreenDone={Position=vector(4,3,0),BrickColor={Name="Bright green"}}
local shamrockDone={Position=vector(4,3,0),BrickColor={Name="Shamrock"}}
tracked.precise[greenDone]=true; tracked.precise[brightGreenDone]=true; tracked.precise[shamrockDone]=true
assert(gatheringPriorities:IsCrosshairIgnoredOrDone(greenDone) and gatheringPriorities:IsCrosshairIgnoredOrDone(brightGreenDone) and gatheringPriorities:IsCrosshairIgnoredOrDone(shamrockDone),"green crosshairs not detected as activated")
assert(not gatheringPriorities:IsCrosshairIgnoredOrDone(normal) and not gatheringPriorities:IsCrosshairIgnoredOrDone(purple),"unactivated crosshairs marked done")
local kind,target=gatheringPriorities:PrecisionUpkeep(opts)
assert(kind=="Precise" and target==normal,"missing buff did not skip green crosshairs and prioritize normal target")
tracked.precise[greenDone]=nil; tracked.precise[brightGreenDone]=nil; tracked.precise[shamrockDone]=nil
buff("x9",1)
kind,target=gatheringPriorities:PrecisionUpkeep({})
assert(kind=="Precise" and target==normal,"Precision below 10x pursued closer purple mark")
kind,target=gatheringPriorities:PrecisionUpkeep({area={minX=0,maxX=10,minZ=-1,maxZ=1}})
assert(kind=="Precise" and target==purple,"precision upkeep escaped selected quadrant")
buff("x10",.9)
buffs["Scorching Star Aura"]={};tracked.precisemark={{},{},{}}
kind,target=gatheringPriorities:PrecisionUpkeep({})
assert(kind=="Precise Purple" and target==purple,"10x did not prioritize marks during scorching star")
local markOptions={}
assert(gatheringPriorities:PrecisionUpkeep(markOptions)=="Precise Purple" and markOptions.avoid==nil,"mark selection retained crosshair avoidance in gathering options")
buff("10x",.9)
assert(gatheringPriorities:PrecisionReady(),"alternate buff label was not read")
-- Seed 3 active precise marks to verify 0.65 refresh threshold + hysteresis, plus <3 mark priority.
tracked.precisemark={{},{},{}}
gatheringPriorities.precisionRefreshing=false
buff("x10",.64)
local avoid={[normal]=7,[purple]=7}
kind,target=gatheringPriorities:PrecisionUpkeep({avoid=avoid})
assert(kind=="Precise" and target==normal,"refresh with 3 marks at 0.64 did not target normal")
assert(not gatheringPriorities:PrecisionUpkeep({avoid={wall=true}}),"upkeep ignored a real path hazard")
assert(not gatheringPriorities:PrecisionUpkeep({range=3,origin=root.Position}),"upkeep exceeded gathering range")
-- New 3-mark upkeep checks:
tracked.precisemark={} -- < 3 marks -> prioritize purple down to >0.55
gatheringPriorities.precisionRefreshing=false
buff("x10",.60)
kind,target=gatheringPriorities:PrecisionUpkeep({})
assert(kind=="Precise Purple" and target==purple,"marks<3 at bar 0.60 did not pursue purple mark")
buff("x10",.50)
kind,target=gatheringPriorities:PrecisionUpkeep({})
assert(kind=="Precise" and target==normal,"marks<3 at bar 0.50 did not refresh precision")
tracked.precisemark={{},{},{}} -- >= 3 marks -> refresh below 0.70, with hysteresis until 0.90
gatheringPriorities.precisionRefreshing=false
buff("x10",.65)
kind,target=gatheringPriorities:PrecisionUpkeep({})
assert(kind=="Precise" and target==normal,"marks>=3 at bar 0.65 did not refresh precision")
buff("x10",.85)
kind,target=gatheringPriorities:PrecisionUpkeep({})
assert(kind=="Precise" and target==normal,"hysteresis did not hold refresh until 0.90")
buff("x10",.90)
kind,target=gatheringPriorities:PrecisionUpkeep({})
assert(kind=="Precise Purple" and target==purple,"marks>=3 at bar 0.90 did not continue farming precise marks")
-- Target Practice token priority when no crosshairs active and <10x / <3 marks / refreshing:
local savedPrecise=tracked.precise; tracked.precise={}
local tpTok={Name=true,Position=vector(12,3,0),Icon="rbxassetid://8173559749"}
tracked.tokens={[tpTok]=true}
tracked.precisemark={{},{},{}}
buff("x9",1.0)
kind,target=gatheringPriorities:PrecisionUpkeep({})
assert(kind=="Token" and target==tpTok and gatheringPriorities.upkeepToken==tpTok,"did not fetch Target Practice token while <10x")
gatheringPriorities.activeTarget=tpTok; gatheringPriorities.precisionActive=false; gatheringPriorities.activeCategory="Precise Targets"
assert(not gatheringPriorities:ShouldPreempt(),"ordinary gathering preempted active Target Practice token")
gatheringPriorities.upkeepToken=nil
tracked.tokens={}
tracked.precise=savedPrecise
-- Automatic tracked.precise2 usage without hookfunction (`state.precise=false`) + in-progress FEID group priority:
state.precise=false
local g1_touched={ID=11,Position=vector(2,3,0),Mark=false,Group="g1",Touched=true}
local g1_purple={ID=12,Position=vector(35,3,0),Mark=true,Group="g1",Touched=false}
local g2_red={ID=21,Position=vector(8,3,0),Mark=false,Group="g2",Touched=false}
tracked.precise2={[11]=g1_touched,[12]=g1_purple,[21]=g2_red}
tracked.precisegroup={[11]="g1",[12]="g1",[21]="g2"}
buff("x9",1.0)
kind,target=gatheringPriorities:PrecisionUpkeep({})
assert(target==g1_purple,"in-progress FEID group did not prioritize its remaining purple target")
tracked.precise2={}; tracked.precisegroup={}
state.precise=true
local normal2={ID=1,Position=vector(20,3,0),Mark=false}
local purple2={ID=2,Position=vector(5,3,0),Mark=true}
tracked.precise2={[1]=normal2,[2]=purple2};tracked.precisegroup={[1]="g",[2]="g"}
gatheringPriorities.precisionRefreshing=false
buff("x10",.5)
kind,target=gatheringPriorities:PrecisionUpkeep({})
assert(kind=="Precise2" and target==normal2,"tracked-target refresh did not prefer normal target")
buff("x10",.9)
kind,target=gatheringPriorities:PrecisionUpkeep({})
assert(kind=="Precise2Purple" and target==purple2,"tracked-target 10x mark selection wrong")
kind,target=pickTarget({})
assert(kind=="Precise2Purple" and target==purple2 and gatheringPriorities.last=="Precise Targets","other gathering priority stole precision upkeep")
comboCandidate="Combo Coconut"
assert(pickTarget({})=="Combo Coconut","precision stole combo priority")
comboCandidate=nil
showerController.active=true
assert(pickTarget({})=="Safeshower" and not gatheringPriorities:PrecisionUpkeep({}),"precision stole shower control")
showerController.active=false
comboController.blocked=true
assert(not gatheringPriorities:PrecisionUpkeep({}),"precision interrupted protected task travel")
comboController.blocked=false
state.activityStatus=3
assert(not gatheringPriorities:PrecisionUpkeep({}),"precision interrupted task activity")
state.activityStatus=1
assert(not gatheringPriorities:PrecisionUpkeep({loot=true}) and not gatheringPriorities:PrecisionUpkeep({mondotokens=true}),"precision stole loot-only mode")
cfg.autofarm.farmprecise=false;cfg.autofarm.farmprecisemark=false
assert(gatheringPriorities:PrecisionUpkeep({})=="Precise2Purple","standalone upkeep required legacy farming switches")
cfg.autofarm.precisionupkeep=false
assert(not gatheringPriorities:PrecisionUpkeep({}),"upkeep toggle ignored")
cfg.autofarm.precisionupkeep=true
gatheringPriorities.precisionActive=true
assert(not gatheringPriorities:ShouldPreempt(),"ordinary custom priority interrupted active precision action")
gatheringPriorities.precisionActive=false
buff("x10",.64)
assert(gatheringPriorities:ShouldPreempt(),"refresh did not preempt normal gathering before buff expiry")
print("PASS: build/refresh Precision, 10x mark selection, physical/tracked targets, priority, range, hazards, task/shower/combo exclusion")

