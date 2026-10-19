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
local tracked={precise={},precise2={},precisegroup={},precisemark={}}
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
function gatheringPriorities:PrecisionReady()
	local precision=buffs.Precision
	if not precision then return false end
	local stacks=tonumber(string.match(precision.Text.Text,"%d+")) or 0
	return stacks>=10 and precision.Percent.Size.Y.Scale>0.65
end

function gatheringPriorities:PrecisionOptions(opts)
	local copy=table.clone(opts)
	copy.avoid=table.clone(opts.avoid or {})
	return copy
end

function gatheringPriorities:PrecisionUpkeep(opts)
	local farm=cfg.autofarm
	if farm.precisionupkeep==false or not farm.enabled or state.activityStatus~=1
		or opts.loot or opts.mondotokens then return end
	if comboController.active or showerController.active or comboController:TravelBlocked() then return end
	if not self:PrecisionReady() and opts.avoid then
		for target in pairs(tracked.precise)do opts.avoid[target]=nil end
		for _,target in pairs(tracked.precise2)do opts.avoid[target]=nil;opts.avoid[target.Position]=nil end
	end
	return self:Precise(self:PrecisionOptions(opts),true)
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
					else preciseMarkActive = autofarm.farmprecisemark and precision and precision.Text.Text == "x10" and precision.Percent.Size.Y.Scale > 0.5 end
					preciseMarkCount = 0

					if scorchingStarAura then
						for k in pairs(tracked.precisemark) do
							preciseMarkCount += 1
						end

						if preciseMarkCount < 3 then
							scorchingStarAura = false
						end
					end

					if not state.precise then
						for k in pairs(tracked.precise) do
							preciseCount += 1
							if upkeep and opts.range and opts.origin and (opts.origin-k.Position).Magnitude>=opts.range then continue end
							name = k.BrickColor.Name

							if not (name == "Flint" or touchedMarks[k]) then
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
						for k, preciseMark in pairs(tracked.precise2) do
							preciseCount += 1
							if upkeep and opts.range and opts.origin and (opts.origin-preciseMark.Position).Magnitude>=opts.range then continue end

							if not preciseMark.Touched and not touchedMarks[preciseMark] then
								precise2Kind = standInPrecise and "Precise2Convert" or preciseMark.Mark and preciseMarkActive and not scorchingStarAura and "Precise2Purple" or (not preciseMarkActive or scorchingStarAura) and "Precise2"

								if precise2Kind ~= "Precise2Convert" then
									ownGroup = tracked.precisegroup[k]

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

										local rank=upkeep and not preciseMarkActive and preciseMark.Mark and 1 or 0
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
local kind,target=gatheringPriorities:PrecisionUpkeep(opts)
assert(kind=="Precise" and target==normal,"missing buff did not prioritize normal precision target")
buff("x9",1)
kind,target=gatheringPriorities:PrecisionUpkeep({})
assert(kind=="Precise" and target==normal,"Precision below 10x pursued closer purple mark")
buff("x10",.9)
buffs["Scorching Star Aura"]={};tracked.precisemark={{},{},{}}
kind,target=gatheringPriorities:PrecisionUpkeep({})
assert(kind=="Precise Purple" and target==purple,"10x did not prioritize marks during scorching star")
local markOptions={}
assert(gatheringPriorities:PrecisionUpkeep(markOptions)=="Precise Purple" and markOptions.avoid==nil,"mark selection retained crosshair avoidance in gathering options")
buff("10x",.9)
assert(gatheringPriorities:PrecisionReady(),"alternate buff label was not read")
buff("x10",.64)
local avoid={[normal]=7,[purple]=7}
kind,target=gatheringPriorities:PrecisionUpkeep({avoid=avoid})
assert(kind=="Precise" and target==normal and avoid[normal]==nil,"refresh was blocked by old mark avoidance")
assert(not gatheringPriorities:PrecisionUpkeep({avoid={wall=true}}),"upkeep ignored a real path hazard")
assert(not gatheringPriorities:PrecisionUpkeep({range=3,origin=root.Position}),"upkeep exceeded gathering range")
state.precise=true
local normal2={ID=1,Position=vector(20,3,0),Mark=false}
local purple2={ID=2,Position=vector(5,3,0),Mark=true}
tracked.precise2={[1]=normal2,[2]=purple2};tracked.precisegroup={[1]="g",[2]="g"}
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

