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
  if k=="Magnitude"or k=="magnitude"then return mag end
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

local CFrame={new=function(x,y,z)return {X=x,Y=y,Z=z}end}
local makeVector=vector
local currentField,vector
local function typeof(value)
 if type(value)=="table" and value.ClassName then return "Instance"end
 if type(value)=="table" and value.X and value.Y and value.Z then return "Vector3"end
 return type(value)
end
function connections:Get(key)return self.list[key]end
function connections:Cancel(key)local c=self.list[key];if c then c:Disconnect();self.list[key]=nil end end
function connections:Add(key,c)self:Cancel(key);self.list[key]=c end
local zones=Instance.new("Folder",workspace);zones.Name="FlowerZones"
local field=Instance.new("Part",zones);field.Name="Pepper Patch";field.Position=makeVector(100,20,200);field.Size=makeVector(100,2,80)
cfg.autofarm.field1="Pepper Patch";cfg.autofarm.farmposition="Upper Left";cfg.autofarm.enabled=false;cfg.autofarm.showfieldarea=false

local rawType=type
local function type(v)if rawType(v)=="table" and v.ClassName then return "userdata" end;return rawType(v)end
local function getHumanoid()return h end
local commands={}
function smoothMovement:MoveTo(goal)commands[#commands+1]=goal end
local tracked={meteors={},tokenlink={}}
local availableFields={[field.Name]=true}
currentField=field
local function getFieldAt(p)return p.X<500 and field or nil end
local findMeteor
local PhysicalProperties={new=function(d,f,e,fw,ew)return {Density=d,Friction=f,Elasticity=e,FrictionWeight=fw,ElasticityWeight=ew}end}
root.CurrentPhysicalProperties=PhysicalProperties.new(1,0.5,0.5,1,1)
root.Massless=true
local meteorMovement={}
function meteorMovement:Release()
	local h=self.humanoid
	if h and h.Parent and h.WalkSpeed==self.assigned then h.WalkSpeed=self.original end
	if self.root and self.root.Parent then
		if self.root.CustomPhysicalProperties==self.massAssigned then self.root.CustomPhysicalProperties=self.massOriginal end
		if self.root.Massless==false then self.root.Massless=self.masslessOriginal end
	end
	self.root,self.massOriginal,self.massAssigned,self.masslessOriginal,self.massBase,self.massFactor=nil,nil,nil,nil,nil,nil
	self.humanoid,self.original,self.assigned,self.pulse=nil,nil,nil,nil
end
function meteorMovement:Chase(object,deadline)
	local h=getHumanoid()
	if not cfg.autofarm.dynamicmeteors then self:Release()
	else
		if self.humanoid~=h then self:Release();self.humanoid=h;self.original=h.WalkSpeed end
		if self.assigned and h.WalkSpeed~=self.assigned then self.original=h.WalkSpeed end
		local delta=object.Position-getRootPart().Position
		local distance=math.sqrt(delta.X*delta.X+delta.Z*delta.Z)
		local expires=deadline and deadline<math.huge and deadline or (type(object)=="table" and object.ExpiresAt)
		local remaining=expires and math.max(0.05,expires-os.clock()-0.15) or 0.4
		local speed=math.max(self.original,math.min(210,math.max(80,distance/remaining)))
		h.WalkSpeed=speed;self.assigned=speed;self.pulse=os.clock()
		local root=getRootPart()
		if not self.root then
			self.root=root;self.massOriginal=root.CustomPhysicalProperties
			self.masslessOriginal=root.Massless;self.massBase=root.CurrentPhysicalProperties
		end
		local factor=math.clamp(speed/math.max(self.original,1),1,10)
		if self.massBase and (not self.massFactor or math.abs(factor-self.massFactor)>=0.25) then
			local base=self.massBase
			self.massAssigned=PhysicalProperties.new(math.clamp(base.Density*factor,0.01,100),base.Friction,base.Elasticity,base.FrictionWeight,base.ElasticityWeight)
			root.Massless=false;root.CustomPhysicalProperties=self.massAssigned;self.massFactor=factor
		end
	end
	smoothMovement:MoveTo(object.Position)
end
function meteorMovement:PickLink(meteor,deadline)
	local root=getRootPart().Position
	local now=os.clock()
	local best,bestDistance
	self.linkVisits=self.linkVisits or setmetatable({},{__mode="k"})
	for object in pairs(tracked.tokenlink) do
		if (type(object)=="table" and object.ExpiresAt and object.ExpiresAt<=now) or (type(object)~="table" and not object.Parent) then continue end
		local pos=object.Position
		if getFieldAt(pos)~=currentField or math.abs(pos.Y-root.Y)>8 then continue end
		local distance=(pos-root).Magnitude
		if distance<=3 then self.linkVisits[object]=now+0.5;continue end
		if (self.linkVisits[object] or 0)>now then continue end
		if meteor then
			-- Only detour when both the link and the landing spot are reachable in time.
			if not deadline or deadline==math.huge then continue end
			local speed=cfg.autofarm.dynamicmeteors and math.max(80,math.min(210,getHumanoid().WalkSpeed)) or math.max(1,getHumanoid().WalkSpeed)
			if (distance+(meteor.Position-pos).Magnitude)/speed+0.3>=deadline-now then continue end
		end
		if not bestDistance or distance<bestDistance then best,bestDistance=object,distance end
	end
	return best
end
	findMeteor = function(anyField)
		local best, bestField, bestDeadline, bestSeen
		local now=os.clock()
		for object,meta in pairs(tracked.meteors) do
			local virtual=type(object)=="table"
			local expires=virtual and object.ExpiresAt
			if (virtual and expires and expires<=now) or (not virtual and not object.Parent) then
				tracked.meteors[object]=nil
				continue
			end
			local field=getFieldAt(object.Position)
			if not field or not availableFields[field.Name] or (not anyField and field~=currentField) then continue end
			local seen=type(meta)=="table" and meta.seen or now
			local deadline=expires or math.huge
			-- Physical warning disks can share the FX entry's authoritative deadline.
			if not virtual then
				for other in pairs(tracked.meteors) do
					if type(other)=="table" and other.ExpiresAt and other.ExpiresAt>now
						and (other.Position-object.Position).Magnitude<2 then deadline=other.ExpiresAt;break end
				end
			end
			if not best or deadline<bestDeadline or (deadline==bestDeadline and seen<bestSeen) then
				best,bestField,bestDeadline,bestSeen=object,field,deadline,seen
			end
		end
		return best,bestField,bestDeadline
	end

now=10
local first={Position=Vector3.new(110,24,200),Size=Vector2.new(20,0),ExpiresAt=11}
local last={Position=Vector3.new(120,24,200),Size=Vector2.new(1,0),ExpiresAt=13}
tracked.meteors[first]={seen=10};tracked.meteors[last]={seen=9}
assert(findMeteor()==first,"deadline must outrank size and observation order")
now=11.01
assert(findMeteor()==last and not tracked.meteors[first],"expired entries must be removed")
cfg.autofarm.dynamicmeteors=true
root.Position=Vector3.new(50,24,200);h.WalkSpeed=30
meteorMovement:Chase(last,11.1)
assert(h.WalkSpeed==210 and commands[#commands]==last.Position)
assert(root.CustomPhysicalProperties.Density==7 and root.Massless==false,"density must scale with chase speed")
meteorMovement:Release();assert(h.WalkSpeed==30)
assert(root.CustomPhysicalProperties==nil and root.Massless==true,"restore exact original physics")
meteorMovement:Chase(last,13)
h.WalkSpeed=42
meteorMovement:Release();assert(h.WalkSpeed==42,"do not overwrite an external speed change")
cfg.autofarm.dynamicmeteors=false
meteorMovement:Chase(last,13);assert(h.WalkSpeed==42 and not meteorMovement.humanoid)
print("PASS: chronological landing priority, expiry cleanup, dynamic cap, speed restoration and toggle")

local disk=Instance.new("Part",workspace);disk.Position=last.Position;disk.Size=Vector3.new(40,1,40)
tracked.meteors[disk]={seen=8}
local picked,_,deadline=findMeteor()
assert(picked==disk and deadline==last.ExpiresAt,"physical disk must inherit matching FX deadline")
disk.Parent=nil
assert(findMeteor()==last and not tracked.meteors[disk])
tracked.meteors[last]=nil
local early=Instance.new("Part",workspace);early.Position=Vector3.new(100,24,200)
local late=Instance.new("Part",workspace);late.Position=Vector3.new(110,24,200)
tracked.meteors[early]={seen=1};tracked.meteors[late]={seen=2}
assert(findMeteor()==early,"without FX timing use observed first-to-last order")
print("PASS: physical/FX deadline matching, destroyed disk pruning, observation fallback")

now=20
root.Position=Vector3.new(100,24,200)
local link={Position=Vector3.new(105,24,200),ExpiresAt=30}
tracked.tokenlink[link]=true
local meteor={Position=Vector3.new(110,24,200)}
cfg.autofarm.dynamicmeteors=true
assert(meteorMovement:PickLink(meteor,22)==link,"reachable links must take priority")
assert(meteorMovement:PickLink(meteor,20.1)==nil,"do not miss imminent meteor for link")
assert(meteorMovement:PickLink(nil)==link,"links before ordinary loot")
root.Position=link.Position
assert(meteorMovement:PickLink(nil)==nil,"do not wait on already touched link")
print("PASS: dynamic mass restoration and deadline-aware Token Link priority")
