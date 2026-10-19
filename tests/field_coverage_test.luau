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
local fieldPositionPolicy={}
function fieldPositionPolicy:IsQuadrant(name)
	return name=="Upper Left" or name=="Upper Right" or name=="Lower Left" or name=="Lower Right"
end
function fieldPositionPolicy:UsableSize(field)
			local fieldName=field.Name
			local x = field.Size.X
			local z = field.Size.Z

			if fieldName == "Bamboo Field" then
				x -= 6
				z -= 8
			elseif fieldName == "Clover Field" then
				x -= 5
				z -= 5
			elseif fieldName == "Coconut Field" then
				x -= 5
				z -= 5
			elseif fieldName == "Dandelion Field" then
				x -= 5
				z -= 5
			elseif fieldName == "Mountain Top Field" then
				x -= 5
				z -= 5
			elseif fieldName == "Mushroom Field" then
				x -= 5
				z -= 5
			elseif fieldName == "Pine Tree Forest" then
				x -= 5
				z -= 5
			elseif fieldName == "Pineapple Patch" then
				x -= 5
				z -= 5
			elseif fieldName == "Pumpkin Patch" then
				x -= 5
				z -= 5
			elseif fieldName == "Rose Field" then
				x -= 5
				z -= 5
			elseif fieldName == "Spider Field" then
				x -= 5
				z -= 5
			elseif fieldName == "Strawberry Field" then
				x -= 5
				z -= 5
			elseif fieldName ~= "Stump Field" then
				if fieldName == "Sunflower Field" then
					x -= 5
					z -= 5
				end
			else
				x -= 20
				z -= 20
			end

	return Vector3.new(x-5,0,z-5)
end
-- Quadrants include outer flower rows; legacy position margins remain unchanged.
function fieldPositionPolicy:QuadrantSize(field)
	return Vector3.new(math.max(1,field.Size.X-1),0,math.max(1,field.Size.Z-1))
end
-- The guard's outer strip is valid gathering space, even if the zone ray misses.
function fieldPositionPolicy:InsideGuardedField(field,point)
	if not cfg.autofarm.fieldedgeguards or self.guardField~=field or not self.guards or not self.guards.Parent then return false end
	local center,size=field.Position,field.Size
	return math.abs(point.X-center.X)<=size.X/2+3
		and math.abs(point.Z-center.Z)<=size.Z/2+3
		and math.abs(point.Y-(center.Y+size.Y/2))<=12
end
function fieldPositionPolicy:CoverageGoal(options,blocked)
	local a=options.area
	local key=string.format("%s:%s:%s:%s",a.minX,a.maxX,a.minZ,a.maxZ)
	local route=self.coverage
	if not route or route.key~=key then
		route={key=key,index=0,nx=math.max(1,math.ceil((a.maxX-a.minX)/3)),nz=math.max(1,math.ceil((a.maxZ-a.minZ)/3))}
		self.coverage=route
	end
	local root=getRootPart().Position
	local count=(route.nx+1)*(route.nz+1)
	for _=1,count do
		local row=math.floor(route.index/(route.nx+1))
		local col=route.index%(route.nx+1)
		if row%2==1 then col=route.nx-col end
		local goal=Vector3.new(a.minX+(a.maxX-a.minX)*col/route.nx,root.Y,a.minZ+(a.maxZ-a.minZ)*row/route.nz)
		local dx,dz=goal.X-root.X,goal.Z-root.Z
		if dx*dx+dz*dz>4 and not blocked(goal) then return goal end
		-- Only advance on arrival or a current hazard, never just on target selection.
		route.index=(route.index+1)%count
	end
end
function fieldPositionPolicy:Region(name,center,size,y)
	local x,z=size.X,size.Z
	local longX=x>z
	if not self:IsQuadrant(name) then
		local side=name=="Left" and -1 or name=="Right" and 1 or 0
		return Vector3.new(center.X+(longX and side*x/2 or 0),y,center.Z+(not longX and side*z/2 or 0))
	end
	local side=string.find(name,"Left",1,true) and -1 or 1
	local depth=string.find(name,"Upper",1,true) and -1 or 1
	local sx,sz=longX and side or depth,longX and depth or side
	local minX,maxX=center.X+(sx<0 and -x/2 or 0),center.X+(sx<0 and 0 or x/2)
	local minZ,maxZ=center.Z+(sz<0 and -z/2 or 0),center.Z+(sz<0 and 0 or z/2)
	local area={minX=minX,maxX=maxX,minZ=minZ,maxZ=maxZ}
	return Vector3.new((minX+maxX)/2,y,(minZ+maxZ)/2),area
end
assert(fieldPositionPolicy:QuadrantSize({Size=Vector3.new(100,2,80)}).X==99)
local options={area={minX=0,maxX=49.5,minZ=0,maxZ=39.5}}
root.Position=Vector3.new(-10,3,-10)
local seen={}
local count=0
local function clear()return false end
for i=1,400 do
 local goal=fieldPositionPolicy:CoverageGoal(options,clear)
 assert(goal and goal.X>=0 and goal.X<=49.5 and goal.Z>=0 and goal.Z<=39.5)
 local again=fieldPositionPolicy:CoverageGoal(options,clear)
 assert(goal.X==again.X and goal.Z==again.Z,"interruption skipped target")
 local key=tostring(goal.X)..":"..tostring(goal.Z)
 if not seen[key]then count+=1;seen[key]=true end
 root.Position=goal
end
assert(count==18*15,"incomplete sweep: "..count)
for _,x in ipairs({0,49.5})do for _,z in ipairs({0,39.5})do
 assert(seen[tostring(x)..":"..tostring(z)],"missing corner")
end end
assert(fieldPositionPolicy:CoverageGoal(options,function()return true end)==nil)
options.area={minX=100,maxX=110,minZ=100,maxZ=110}
local goal=fieldPositionPolicy:CoverageGoal(options,clear)
assert(goal.X>=100 and goal.Z>=100)
print("PASS: full sweep, corners, interruption resume, hazards, field changes")

cfg.autofarm.fieldedgeguards=true
local field={Position=Vector3.new(0,0,0),Size=Vector3.new(100,2,80)}
fieldPositionPolicy.guardField=field
fieldPositionPolicy.guards={Parent=workspace}
assert(fieldPositionPolicy:InsideGuardedField(field,Vector3.new(-52.9,4,-42.9)))
assert(not fieldPositionPolicy:InsideGuardedField(field,Vector3.new(-60,4,-50)))
assert(not fieldPositionPolicy:InsideGuardedField(field,Vector3.new(-50,40,-40)))
fieldPositionPolicy.guards=nil
assert(not fieldPositionPolicy:InsideGuardedField(field,Vector3.new(-51,4,-41)))
print("PASS: guarded strip accepted without recovery; remote, airborne and unguarded positions excluded")
