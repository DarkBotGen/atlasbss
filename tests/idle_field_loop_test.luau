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

local fieldPositionPolicy={UsableSize=function(_,f)return f.Size end}
function fieldPositionPolicy:IdleLoopGoal(options,blocked)
	local a=options.area
	if not a then
		if not currentField then return end
		local size=self:UsableSize(currentField)
		local center=currentField.Position
		a={minX=center.X-size.X/2,maxX=center.X+size.X/2,minZ=center.Z-size.Z/2,maxZ=center.Z+size.Z/2}
	end
	local minX,maxX,minZ,maxZ=a.minX,a.maxX,a.minZ,a.maxZ
	if options.range and options.origin then
		local r=options.range*0.7
		minX,maxX=math.max(minX,options.origin.X-r),math.min(maxX,options.origin.X+r)
		minZ,maxZ=math.max(minZ,options.origin.Z-r),math.min(maxZ,options.origin.Z+r)
	end
	if minX>=maxX or minZ>=maxZ then return end
	local cx,cz=(minX+maxX)/2,(minZ+maxZ)/2
	local hx,hz=(maxX-minX)/2,(maxZ-minZ)/2
	local inset=math.min(2,hx/4,hz/4)
	hx,hz=hx-inset,hz-inset
	local stump=currentField and currentField.Name=="Stump Field"
	local key=string.format("%s:%s:%s:%s:%s:%s",minX,maxX,minZ,maxZ,tostring(stump),tostring(stump and options.area~=nil))
	local root=getRootPart().Position
	local route=self.idleLoop
	if not route or route.key~=key then
		route={key=key,index=1,points={}}
		if stump and options.area then
			-- Green reference: two inner sides and a quarter-ellipse across the
			-- outer corner. Mirror from the field center for all four quadrants.
			local sx=cx>=currentField.Position.X and 1 or -1
			local sz=cz>=currentField.Position.Z and 1 or -1
			local ox=sx>0 and minX+inset or maxX-inset
			local oz=sz>0 and minZ+inset or maxZ-inset
			local rx,rz=hx*2,hz*2
			local function add(x,z)route.points[#route.points+1]=Vector3.new(x,0,z)end
			local nx,nz=math.max(1,math.ceil(rx/6)),math.max(1,math.ceil(rz/6))
			for i=0,nx-1 do add(ox+sx*rx*i/nx,oz) end
			local arcs=math.clamp(math.ceil(math.pi*(rx+rz)/4/5),8,48)
			for i=0,arcs do
				local angle=i*math.pi/2/arcs
				add(ox+sx*rx*math.cos(angle),oz+sz*rz*math.sin(angle))
			end
			for i=1,nz-1 do add(ox,oz+sz*rz*(1-i/nz)) end
		else
			local count=math.clamp(math.ceil(4*(hx+hz)/6),16,96)
			for i=1,count do
				local angle=(i-1)*2*math.pi/count
				local x,z=math.cos(angle),math.sin(angle)
				-- The whole Stump Field uses an ellipse rather than square corners.
				if not stump then x=math.sign(x)*math.sqrt(math.abs(x));z=math.sign(z)*math.sqrt(math.abs(z)) end
				route.points[i]=Vector3.new(cx+hx*x,0,cz+hz*z)
			end
		end
		local nearest
		for i,point in ipairs(route.points) do
			local d=(point.X-root.X)^2+(point.Z-root.Z)^2
			if not nearest or d<nearest then nearest=d;route.index=i end
		end
		self.idleLoop=route
	end
	for _=1,#route.points do
		local p=route.points[route.index]
		local goal=Vector3.new(p.X,root.Y,p.Z)
		if (p.X-root.X)^2+(p.Z-root.Z)^2>4 and not blocked(goal) then return goal end
		route.index=route.index%#route.points+1
	end
end

local function clear()return false end
for _,area in ipairs({{minX=0,maxX=50,minZ=0,maxZ=40},{minX=-20,maxX=10,minZ=100,maxZ=180}})do
 root.Position=Vector3.new(area.minX,3,area.minZ)
 local options={area=area}
 local first=assert(fieldPositionPolicy:IdleLoopGoal(options,clear))
 local count=#fieldPositionPolicy.idleLoop.points
 local seen={}
 for i=1,count+1 do
  local goal=assert(fieldPositionPolicy:IdleLoopGoal(options,clear))
  assert(goal.X>area.minX and goal.X<area.maxX and goal.Z>area.minZ and goal.Z<area.maxZ)
  local again=fieldPositionPolicy:IdleLoopGoal(options,clear)
  assert(goal.X==again.X and goal.Z==again.Z,"collection interruption must preserve loop target")
  seen[fieldPositionPolicy.idleLoop.index]=true
  root.Position=goal
 end
 local visited=0;for _ in pairs(seen)do visited+=1 end
 assert(visited==count,"must complete the loop")
 assert(fieldPositionPolicy:IdleLoopGoal(options,function()return true end)==nil)
end
currentField={Position=Vector3.new(100,20,200),Size=Vector3.new(100,2,80)}
root.Position=Vector3.new(100,24,200)
local options={range=20,origin=root.Position}
for i=1,100 do
 local goal=assert(fieldPositionPolicy:IdleLoopGoal(options,clear))
 assert((goal-options.origin).Magnitude<20,"legacy range must remain respected")
 root.Position=goal
end
print("PASS: rounded loops, field scaling, quadrant bounds, full laps, interruption resume, hazards and range")

currentField={Name="Stump Field",Position=Vector3.new(0,0,0),Size=Vector3.new(100,2,80)}
for _,sx in ipairs({-1,1})do for _,sz in ipairs({-1,1})do
 local area={minX=sx<0 and -50 or 0,maxX=sx<0 and 0 or 50,minZ=sz<0 and -40 or 0,maxZ=sz<0 and 0 or 40}
 root.Position=Vector3.new(sx*10,3,sz*10)
 fieldPositionPolicy:IdleLoopGoal({area=area},clear)
 local points=fieldPositionPolicy.idleLoop.points
 local curved=0
 for i,p in ipairs(points)do
  assert(p.X>=area.minX and p.X<=area.maxX and p.Z>=area.minZ and p.Z<=area.maxZ)
  local x=(sx*p.X-2)/46;local z=(sz*p.Z-2)/36
  assert(x*x+z*z<=1.00001,"Stump route must cut the outer corner")
  if x>0.1 and z>0.1 then curved+=1;assert(math.abs(x*x+z*z-1)<0.00001)end
  local nextPoint=points[i%#points+1]
  assert((p-nextPoint).Magnitude<=6.1,"route must remain connected")
 end
 assert(curved>=3,"missing broad outer arc")
end end
print("PASS: Stump green contour mirrored in all four quadrants, connected sides and curved outer edge")

local function getHumanoid()return h end
local localPlayer=player
function fieldPositionPolicy:ReleaseIdle()
	if self.idleDrive then
		RunService:UnbindFromRenderStep("AtlasIdleLoopMovement")
		local char=localPlayer.Character
		local h=char and char:FindFirstChildOfClass("Humanoid")
		if h then h:Move(Vector3.zero,false) end
	end
	self.idleDrive=nil
	local mass=self.idleMass
	self.idleMass=nil
	if mass and mass.root.Parent then
		if mass.root.CustomPhysicalProperties==mass.assigned then mass.root.CustomPhysicalProperties=mass.original end
		if mass.root.Massless==false then mass.root.Massless=mass.massless end
	end
end
function fieldPositionPolicy:DriveIdle()
	local drive=self.idleDrive
	if not drive or state.stop or not cfg.autofarm.enabled or not cfg.autofarm.idlefieldloop or state.activityStatus~=1 then return end
	local goal=drive.makeGoal()
	local h=getHumanoid()
	if not goal or not drive.allowed(goal) then h:Move(Vector3.zero,false);return end
	local delta=goal-getRootPart().Position
	local direction=Vector3.new(delta.X,0,delta.Z)
	h:Move(direction.Magnitude>0.05 and direction.Unit or Vector3.zero,false)
end

local function getHumanoid()return h end

cfg.autofarm.enabled=true;cfg.autofarm.idlefieldloop=true;state.activityStatus=1
root.Position=Vector3.new(0,3,0)
local goal=Vector3.new(10,3,0)
fieldPositionPolicy.idleDrive={makeGoal=function()return goal end,allowed=function()return true end}
for i=1,60 do fieldPositionPolicy:DriveIdle();assert(h.direction and h.direction.X>0.99)end
local original={Density=1};local temporary={Density=10}
root.CustomPhysicalProperties=temporary;root.Massless=false
fieldPositionPolicy.idleMass={root=root,original=original,massless=true,assigned=temporary}
fieldPositionPolicy:ReleaseIdle()
assert(not fieldPositionPolicy.idleDrive and root.CustomPhysicalProperties==original and root.Massless)
print("PASS: continuous directional commands and cleanup/restoration of previous density")
