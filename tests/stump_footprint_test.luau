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
 mt.__unm=function(a)return vector(-a.X,-a.Y,-a.Z)end
 mt.__div=function(a,b)return vector(a.X/b,a.Y/b,a.Z and a.Z/b or nil)end
 mt.__index=function(a,k)
  local z=rawget(a,"Z")
  local mag=math.sqrt(a.X*a.X+a.Y*a.Y+(z or 0)^2)
  if k=="Magnitude"or k=="magnitude"then return mag end
  if k=="Dot"then return function(a,b)return a.X*b.X+a.Y*b.Y+a.Z*b.Z end end
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

local localPlayer=player
local function getHumanoid()return h end
CFrame.lookAt=function(pos,target)return {X=pos.X,Y=pos.Y,Z=pos.Z,target=target}end
local PhysicalProperties={new=function(d,f,e,fw,ew)return {Density=d,Friction=f,Elasticity=e,FrictionWeight=fw,ElasticityWeight=ew}end}
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
-- Rounded perimeter route, scaled to the active field or selected quadrant.
function fieldPositionPolicy:ReleaseIdle()
	local drive=self.idleDrive
	if drive then
		RunService:UnbindFromRenderStep("AtlasIdleLoopMovement")
		local char=localPlayer.Character
		local h=char and char:FindFirstChildOfClass("Humanoid")
		if drive.speedHumanoid and drive.speedHumanoid.Parent and drive.speedHumanoid.WalkSpeed==drive.assignedSpeed then drive.speedHumanoid.WalkSpeed=drive.originalSpeed end
		if h then h:Move(Vector3.zero,false) end
		if drive.controls and drive.restoreControls then pcall(function()drive.controls:Enable()end) end
	end
	self.idleDrive=nil
	local mass=self.idleMass
	self.idleMass=nil
	if mass and mass.root.Parent then
		if mass.root.CustomPhysicalProperties==mass.assigned then mass.root.CustomPhysicalProperties=mass.original end
		if mass.root.Massless==false then mass.root.Massless=mass.massless end
	end
end
function fieldPositionPolicy:StartIdle(makeGoal,allowed)
	local drive=self.idleDrive
	if drive and (drive.field~=currentField or drive.character~=localPlayer.Character) then self:ReleaseIdle();drive=nil end
	if not drive then
		drive={field=currentField,character=localPlayer.Character}
		-- Default controls can overwrite Humanoid:Move with zero every frame.
		-- Own them for the idle session, just as shower/combo movement does.
		pcall(function()
			local module=localPlayer.PlayerScripts:FindFirstChild("PlayerModule")
			if module then
				drive.controls=require(module):GetControls()
				drive.restoreControls=drive.controls.controlsEnabled~=false
				drive.controls:Disable()
			end
		end)
		self.idleDrive=drive
		smoothMovement.roam=nil
		RunService:BindToRenderStep("AtlasIdleLoopMovement",Enum.RenderPriority.Character.Value+1,function()self:DriveIdle()end)
	end
	drive.makeGoal,drive.allowed=makeGoal,allowed
	self:DriveIdle()
end
function fieldPositionPolicy:ApplyIdlePhysics(drive,h,root)
	if cfg.autofarm.idlepatternmass and not self.idleMass then
		local base=root.CurrentPhysicalProperties
		if base then
			local assigned=PhysicalProperties.new(math.clamp(base.Density*10,0.01,100),base.Friction,base.Elasticity,base.FrictionWeight,base.ElasticityWeight)
			self.idleMass={root=root,original=root.CustomPhysicalProperties,massless=root.Massless,assigned=assigned}
			root.Massless=false;root.CustomPhysicalProperties=assigned
		end
	end
	if cfg.autofarm.idlepattern140 then
		if not drive.speedHumanoid then drive.speedHumanoid=h;drive.originalSpeed=h.WalkSpeed end
		if drive.assignedSpeed and h.WalkSpeed~=drive.assignedSpeed then drive.originalSpeed=h.WalkSpeed end
		h.WalkSpeed=140;drive.assignedSpeed=140
	end
end
function fieldPositionPolicy:DriveIdle()
	local drive=self.idleDrive
	if not drive or state.stop or not cfg.autofarm.enabled or not cfg.autofarm.idlefieldloop or state.activityStatus~=1 then return end
	local goal=drive.makeGoal()
	local h=getHumanoid()
	if not goal or not drive.allowed(goal) then h:Move(Vector3.zero,false);return end
	local root=getRootPart()
	self:ApplyIdlePhysics(drive,h,root)
	local delta=goal-root.Position
	local direction=Vector3.new(delta.X,0,delta.Z)
	h:Move(direction.Magnitude>0.05 and direction.Unit or Vector3.zero,false)
end
function fieldPositionPolicy:SmileyOnly()
	return cfg.autofarm.enabled and cfg.autofarm.idlefieldloop and cfg.autofarm.stumpsmileyonly and currentField and currentField.Name=="Stump Field"
end
function fieldPositionPolicy:StumpPolygon(field,area)
	if not field or field.Name~="Stump Field" or not cfg.autofarm.idlefieldloop then return end
	if not area then
		if not cfg.autofarm.farmposenabled or not self:IsQuadrant(cfg.autofarm.farmposition) then return end
		local _,a=self:Region(cfg.autofarm.farmposition,field.Position,self:QuadrantSize(field),field.Position.Y)
		area=a
	end
	local key=string.format("%s:%s:%s:%s",area.minX,area.maxX,area.minZ,area.maxZ)
	if self.stumpShapes and self.stumpShapes[key] then return self.stumpShapes[key] end
	local cx,cz=(area.minX+area.maxX)/2,(area.minZ+area.maxZ)/2
	local sx,sz=cx>=field.Position.X and 1 or -1,cz>=field.Position.Z and 1 or -1
	local inset=math.min(2,(area.maxX-area.minX)/8,(area.maxZ-area.minZ)/8)
	local ox=sx>0 and area.minX+inset or area.maxX-inset
	local oz=sz>0 and area.minZ+inset or area.maxZ-inset
	local rx,rz=(area.maxX-area.minX-2*inset)*0.9,(area.maxZ-area.minZ-2*inset)*0.9
	-- The crossing has normalized x+z=1; the outer quarter-ellipse reaches
	-- sqrt(2). Mirror that perpendicular extent across the crossing.
	local inner=2-math.sqrt(2)
	local points={Vector3.new(ox+sx*rx*inner,0,oz),Vector3.new(ox+sx*rx,0,oz)}
	for i=1,16 do
		local angle=i*math.pi/32
		points[#points+1]=Vector3.new(ox+sx*rx*math.cos(angle),0,oz+sz*rz*math.sin(angle))
	end
	points[#points+1]=Vector3.new(ox,0,oz+sz*rz*inner)
	self.stumpShape={key=key,points=points}
	self.stumpShapes=self.stumpShapes or {};self.stumpShapeCount=self.stumpShapeCount or 0
	if self.stumpShapeCount>=4 then self.stumpShapes={};self.stumpShapeCount=0 end
	self.stumpShapes[key]=points;self.stumpShapeCount+=1
	return points
end
function fieldPositionPolicy:InsidePolygon(point,points)
	local sign
	for i,a in ipairs(points) do
		local b=points[i%#points+1]
		local cross=(b.X-a.X)*(point.Z-a.Z)-(b.Z-a.Z)*(point.X-a.X)
		if math.abs(cross)>0.001 then
			local side=cross>0
			if sign~=nil and side~=sign then return false end
			sign=side
		end
	end
	return true
end
function fieldPositionPolicy:StumpCrossing(polygon)
	local cached=self.stumpCrossing
	if cached and cached.polygon==polygon then return cached.a,cached.b end
	local a,b,best=1,2,-1
	for i=1,#polygon-1 do
		for j=i+1,#polygon do
			local dx,dz=polygon[i].X-polygon[j].X,polygon[i].Z-polygon[j].Z
			local distance=dx*dx+dz*dz
			if distance>best then a,b,best=i,j,distance end
		end
	end
	self.stumpCrossing={polygon=polygon,a=a,b=b}
	return a,b
end
function fieldPositionPolicy:StumpRoute(polygon)
	local a,b=self:StumpCrossing(polygon)
	local points,sections={},{}
	local function edge(p,q)
		local count=math.max(1,math.ceil((q-p).Magnitude/6))
		for j=0,count-1 do points[#points+1]=p+(q-p)*(j/count) end
	end
	local function arc(from,to,step,name)
		sections[#sections+1]={name=name,first=#points+1}
		local index=from
		while index~=to do
			local nextIndex=(index-1+step)%#polygon+1
			edge(polygon[index],polygon[nextIndex]);index=nextIndex
		end
	end
	-- Two alternating infinity repetitions join into one continuous cycle.
	-- Each repetition visits both sides and the middle once; adjacent
	-- repetitions start on a different section instead of reversing the last.
	for repetition=1,2 do
		local from,to,step=a,b,1
		if repetition==2 then from,to,step=b,a,-1 end
		arc(from,to,step,"curved")
		sections[#sections+1]={name="middle",first=#points+1}
		edge(polygon[to],polygon[from])
		arc(from,to,-step,"straight")
	end
	return points,sections
end
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
	local key=string.format("%s:%s:%s:%s:%s:%s:%s",minX,maxX,minZ,maxZ,tostring(stump),tostring(stump and options.area~=nil),"perimeter-middle-once")
	local root=getRootPart().Position
	local route=self.idleLoop
	if not route or route.key~=key then
		route={key=key,index=1,points={}}
		if stump and options.area then
			local polygon=self:StumpPolygon(currentField,{minX=minX,maxX=maxX,minZ=minZ,maxZ=maxZ})
			route.points,route.sections=self:StumpRoute(polygon)
			route.infinity=true
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
	-- Turn before reaching the exact corner, with a small speed-based lead.
	local lead=math.clamp(getHumanoid().WalkSpeed*0.04,2,4)
	if route.pingpong then lead=math.min(lead,math.max(2,route.spacing*0.45)) end
	for _=1,#route.points do
		local p=route.points[route.index]
		local goal=Vector3.new(p.X,root.Y,p.Z)
		local passed=false
		if (route.pingpong or route.infinity) and route.previous then
			local delta=p-route.previous
			passed=(root.X-p.X)*delta.X+(root.Z-p.Z)*delta.Z>=0
		end
		if not passed and (p.X-root.X)^2+(p.Z-root.Z)^2>lead*lead and not blocked(goal) then return goal end
		if route.infinity then
			route.previous=p
			route.index=route.index%#route.points+1
		elseif route.pingpong then
			route.previous=p
			if route.index==#route.points then route.direction=-1 elseif route.index==1 then route.direction=1 end
			route.index+=route.direction
		else route.index=route.index%#route.points+1 end
	end
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
function fieldPositionPolicy:StrictArea()
	if not cfg.autofarm.enabled or not cfg.autofarm.strictquadrant or not cfg.autofarm.farmposenabled or not self:IsQuadrant(cfg.autofarm.farmposition) then return end
	local zones=workspace:FindFirstChild("FlowerZones")
	local field=zones and zones:FindFirstChild(cfg.autofarm.field1)
	if not field then return end
	local _,area=self:Region(cfg.autofarm.farmposition,field.Position,self:QuadrantSize(field),field.Position.Y)
	return area
end
function fieldPositionPolicy:StrictAllowed(goal)
	local a=self:StrictArea()
	return not a or (goal and goal.X>=a.minX and goal.X<=a.maxX and goal.Z>=a.minZ and goal.Z<=a.maxZ) or false
end
function fieldPositionPolicy:Allowed(goal,opts)
	if not self:StrictAllowed(goal) then return false end
	local area=opts and opts.area
	local polygon=area and self:StumpPolygon(currentField,area)
	if polygon and not self:InsidePolygon(goal,polygon) then return false end
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
-- Four reusable local walls outside the flower footprint, only during gathering.
function fieldPositionPolicy:RemoveGuards()
	if self.guards then self.guards:Destroy();self.guards=nil;self.guardField=nil;self.guardKey=nil end
end
function fieldPositionPolicy:UpdateGuards(allowed)
	local field=currentField
	local char=localPlayer.Character
	local root=char and char:FindFirstChild("HumanoidRootPart")
	local humanoid=char and char:FindFirstChildOfClass("Humanoid")
	if not allowed or not cfg.autofarm.fieldedgeguards or not field or not root or not humanoid or humanoid.Health<=0 then self:RemoveGuards();return end
	local center,size=field.Position,field.Size
	if math.abs(root.Position.X-center.X)>size.X/2+3 or math.abs(root.Position.Z-center.Z)>size.Z/2+3
		or math.abs(root.Position.Y-(center.Y+size.Y/2))>12 then self:RemoveGuards();return end
	local quadrant=cfg.autofarm.idlefieldloop and cfg.autofarm.farmposenabled and self:IsQuadrant(cfg.autofarm.farmposition) and cfg.autofarm.farmposition or "field"
	local key=field.Name..":"..quadrant
	-- Do not close a collision perimeter around a player approaching from outside.
	-- Re-arm only after reaching the actual footprint, not merely the same field.
	if cfg.autofarm.idlefieldloop and not self.idleDrive then self:RemoveGuards();return end
	if self.guardField~=field or self.guardKey~=key or not self.guards or not self.guards.Parent then
		local polygon=quadrant~="field" and self:StumpPolygon(field)
		local inside
		if polygon then inside=self:InsidePolygon(root.Position,polygon)
		elseif quadrant~="field" then
			local _,area=self:Region(quadrant,center,self:QuadrantSize(field),root.Position.Y)
			inside=root.Position.X>=area.minX and root.Position.X<=area.maxX and root.Position.Z>=area.minZ and root.Position.Z<=area.maxZ
		else inside=math.abs(root.Position.X-center.X)<=size.X/2 and math.abs(root.Position.Z-center.Z)<=size.Z/2 end
		if not inside then self:RemoveGuards();return end
	end
	if self.guardField==field and self.guardKey==key and self.guards and self.guards.Parent then return end
	self:RemoveGuards()
	local folder=Instance.new("Folder");folder.Name="AtlasFieldEdgeGuards"
	self.guards,self.guardField,self.guardKey=folder,field,key
	local minX,maxX=center.X-size.X/2,center.X+size.X/2
	local minZ,maxZ=center.Z-size.Z/2,center.Z+size.Z/2
	if quadrant~="field" then
		local _,area=self:Region(quadrant,center,self:QuadrantSize(field),center.Y)
		-- Keep outer walls at the existing full-field clearance; add the inner
		-- quadrant edges so every turn has an uninterrupted collision boundary.
		minX=area.minX<center.X and minX or area.minX
		maxX=area.maxX>center.X and maxX or area.maxX
		minZ=area.minZ<center.Z and minZ or area.minZ
		maxZ=area.maxZ>center.Z and maxZ or area.maxZ
	end
	local midX,midZ=(minX+maxX)/2,(minZ+maxZ)/2
	local y=center.Y+size.Y/2+4
	local function wall(name,x,z,width,depth)
		local part=Instance.new("Part");part.Name=name
		part.Anchored=true;part.CanCollide=true;part.CanTouch=false;part.CanQuery=false
		part.CastShadow=false;part.Transparency=1
		part.Size=Vector3.new(width,10,depth);part.CFrame=CFrame.new(x,y,z);part.Parent=folder
	end
	-- Leave three studs between the zone edge and each wall's inner face,
	-- so the character can reach the entire outer flower row.
	local clearance,thickness=3,2
	local offset=clearance+thickness/2
	local span=2*(clearance+thickness)
	local polygon=quadrant~="field" and self:StumpPolygon(field)
	if polygon then
		local centroid=Vector3.zero
		for _,p in ipairs(polygon) do centroid+=p end
		centroid/=#polygon
		for i,a in ipairs(polygon) do
			local b=polygon[i%#polygon+1]
			local delta=b-a
			local mid=(a+b)/2
			local normal=Vector3.new(-delta.Z,0,delta.X).Unit
			if normal:Dot(mid-centroid)<0 then normal=-normal end
			local centerPoint=Vector3.new(mid.X,y,mid.Z)+normal*offset
			local p=Instance.new("Part");p.Name="StumpEdge"..i;p.Anchored=true;p.CanCollide=true;p.CanTouch=false;p.CanQuery=false;p.CastShadow=false;p.Transparency=1
			p.Size=Vector3.new(thickness,10,delta.Magnitude+span)
			p.CFrame=CFrame.lookAt(centerPoint,centerPoint+delta);p.Parent=folder
		end
		folder.Parent=workspace
		return
	end
	wall("Left",minX-offset,midZ,thickness,maxZ-minZ+span)
	wall("Right",maxX+offset,midZ,thickness,maxZ-minZ+span)
	wall("Upper",midX,minZ-offset,maxX-minX+span,thickness)
	wall("Lower",midX,maxZ+offset,maxX-minX+span,thickness)
	folder.Parent=workspace
end
function fieldPositionPolicy:StopPreview()
	connections:Cancel("fieldAreaPreview")
	if self.preview then self.preview:Destroy();self.preview=nil end
	self.parts=nil;self.previewMode=nil;self.allStumpViews=nil
end
function fieldPositionPolicy:DrawStumpPreview(field,polygon,view)
	view=view or self
	if view.previewMode~="stump" then
		if view.preview then view.preview:Destroy() end
		view.preview,view.parts=nil,nil
	end
	view.previewMode="stump"
	if not view.preview or not view.preview.Parent then
		view.preview=Instance.new("Folder");view.preview.Name=view.name or "AtlasFieldAreaPreview";view.preview.Parent=view.parent or workspace;view.parts={}
	end
	local y=field.Position.Y+field.Size.Y/2+0.15
	local color=view.color or Color3.fromRGB(65,230,130)
	local index=0
	local function part(size,cf,transparency)
		index+=1
		local p=view.parts[index]
		if not p then
			p=Instance.new("Part");p.Name="StumpArea"..index;p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.CastShadow=false
			p.Parent=view.preview;view.parts[index]=p
		end
		p.Size=size;p.CFrame=cf;p.Color=color;p.Material=Enum.Material.Neon;p.Transparency=transparency
		return p
	end
	local minZ,maxZ=math.huge,-math.huge
	for _,p in ipairs(polygon) do minZ=math.min(minZ,p.Z);maxZ=math.max(maxZ,p.Z) end
	local function span(z)
		local left,right=math.huge,-math.huge
		for i,a in ipairs(polygon) do
			local b=polygon[i%#polygon+1]
			if math.abs(b.Z-a.Z)>0.000001 and z>=math.min(a.Z,b.Z) and z<=math.max(a.Z,b.Z) then
				local x=a.X+(b.X-a.X)*(z-a.Z)/(b.Z-a.Z)
				left,right=math.min(left,x),math.max(right,x)
			end
		end
		return left,right
	end
	-- Conservative slices stay inside the polygon, including both trimmed corners.
	for i=0,31 do
		local z0=minZ+(maxZ-minZ)*i/32
		local z1=minZ+(maxZ-minZ)*(i+1)/32
		local l0,r0=span(z0+0.00001);local l1,r1=span(z1-0.00001)
		local left,right=math.max(l0,l1),math.min(r0,r1)
		part(Vector3.new(math.max(.01,right-left),.12,z1-z0),CFrame.new((left+right)/2,y,(z0+z1)/2),right-left>=.02 and .82 or 1)
	end
	for i,a in ipairs(polygon) do
		local b=polygon[i%#polygon+1]
		local start,finish=Vector3.new(a.X,y+.03,a.Z),Vector3.new(b.X,y+.03,b.Z)
		part(Vector3.new(.3,.12,(finish-start).Magnitude),CFrame.lookAt((start+finish)/2,finish),.05)
	end
	local function line(a,b)
		local start,finish=Vector3.new(a.X,y+.05,a.Z),Vector3.new(b.X,y+.05,b.Z)
		part(Vector3.new(.22,.12,(finish-start).Magnitude),CFrame.lookAt((start+finish)/2,finish),.25)
	end
	local a,b=self:StumpCrossing(polygon);line(polygon[a],polygon[b])
	if view.label then
		local center=Vector3.zero
		for _,p in ipairs(polygon) do center+=p end
		center/=#polygon
		local anchor=part(Vector3.new(.1,.1,.1),CFrame.new(center.X,y,center.Z),1)
		local gui=anchor:FindFirstChild("CoverageLabel")
		if not gui then
			gui=Instance.new("BillboardGui");gui.Name="CoverageLabel";gui.Size=UDim2.fromOffset(240,52);gui.StudsOffset=Vector3.new(0,5,0);gui.AlwaysOnTop=true;gui.MaxDistance=300;gui.Parent=anchor
			local label=Instance.new("TextLabel");label.Name="Text";label.Size=UDim2.fromScale(1,1);label.BackgroundTransparency=1;label.TextScaled=true;label.Font=Enum.Font.GothamSemibold;label.TextStrokeTransparency=.3;label.Parent=gui
		end
		local label=gui:FindFirstChild("Text");label.Text=view.label;label.TextColor3=color
	end
	for i=#view.parts,index+1,-1 do view.parts[i]:Destroy();view.parts[i]=nil end
end
function fieldPositionPolicy:StumpOccupants(field,polygon)
	local names={}
	local top=field.Position.Y+field.Size.Y/2
	for _,player in ipairs(getService("Players"):GetPlayers()) do
		local char=player.Character
		local root=char and char:FindFirstChild("HumanoidRootPart")
		local h=char and char:FindFirstChildOfClass("Humanoid")
		if root and h and h.Health>0 and math.abs(root.Position.Y-top)<=12 and self:InsidePolygon(root.Position,polygon) then names[#names+1]=player.Name end
	end
	table.sort(names)
	return names
end
function fieldPositionPolicy:DrawAllStump(field)
	if self.previewMode~="stumpAll" then
		if self.preview then self.preview:Destroy() end
		self.preview,self.parts,self.allStumpViews=nil,nil,{}
	end
	self.previewMode="stumpAll"
	if not self.preview or not self.preview.Parent then
		self.preview=Instance.new("Folder");self.preview.Name="AtlasAllStumpCoverage";self.preview.Parent=workspace
		self.allStumpViews={}
	end
	for _,name in ipairs({"Upper Left","Upper Right","Lower Left","Lower Right"}) do
		local _,area=self:Region(name,field.Position,self:QuadrantSize(field),field.Position.Y)
		local polygon=self:StumpPolygon(field,area)
		local occupants=self:StumpOccupants(field,polygon)
		local view=self.allStumpViews[name] or {name=name,parent=self.preview}
		view.color=#occupants>0 and Color3.fromRGB(65,230,130) or Color3.fromRGB(240,65,65)
		view.label=name.."\n"..(#occupants>0 and table.concat(occupants,", ") or "Unoccupied")
		self.allStumpViews[name]=view
		self:DrawStumpPreview(field,polygon,view)
	end
end
function fieldPositionPolicy:DrawPreview()
	if not cfg.autofarm.showfieldarea then self:StopPreview();return end
	local zones=workspace:FindFirstChild("FlowerZones")
	local selected=zones and zones:FindFirstChild(cfg.autofarm.field1)
	local field=(cfg.autofarm.enabled and currentField) or selected or currentField
	if field and field.Name=="Stump Field" and cfg.autofarm.idlefieldloop and cfg.autofarm.showallstump then self:DrawAllStump(field);return end
	if self.previewMode=="stumpAll" then
		if self.preview then self.preview:Destroy() end
		self.preview,self.parts,self.previewMode,self.allStumpViews=nil,nil,nil,nil
	end
	if not field or not self:IsQuadrant(cfg.autofarm.farmposition) then
		if self.preview then self.preview:Destroy();self.preview=nil;self.parts=nil end
		return
	end
	local polygon=self:StumpPolygon(field)
	if polygon then self:DrawStumpPreview(field,polygon);return end
	if self.previewMode=="stump" then
		if self.preview then self.preview:Destroy() end
		self.preview,self.parts=nil,nil
	end
	self.previewMode=nil
	local center=field.Position
	local size=self:QuadrantSize(field)
	if not size then return end
	local y=field.Position.Y+field.Size.Y/2+0.15
	local _,area=self:Region(cfg.autofarm.farmposition,center,size,y)
	if not self.preview or not self.preview.Parent then
		self.preview=Instance.new("Folder");self.preview.Name="AtlasFieldAreaPreview";self.preview.Parent=workspace;self.parts={}
	end
	local function part(index,x,z,width,depth,color,transparency)
		local object=self.parts[index]
		if not object or not object.Parent then
			object=Instance.new("Part");object.Name="AtlasArea"..index;object.Anchored=true
			object.CanCollide=false;object.CanTouch=false;object.CanQuery=false;object.CastShadow=false
			object.Parent=self.preview;self.parts[index]=object
		end
		object.Size=Vector3.new(math.max(.1,width),.12,math.max(.1,depth))
		object.CFrame=CFrame.new(x,y+((index>=2 and index<=5) and .03 or 0),z);object.Color=color;object.Material=Enum.Material.Neon;object.Transparency=transparency
		return object
	end
	local selected=Color3.fromRGB(65,230,130)
	local grid=Color3.fromRGB(245,245,245)
	local width,depth=area.maxX-area.minX,area.maxZ-area.minZ
	part(1,(area.minX+area.maxX)/2,(area.minZ+area.maxZ)/2,width,depth,selected,.82)
	part(2,area.minX,(area.minZ+area.maxZ)/2,.4,depth,selected,.05)
	part(3,area.maxX,(area.minZ+area.maxZ)/2,.4,depth,selected,.05)
	part(4,(area.minX+area.maxX)/2,area.minZ,width,.4,selected,.05)
	part(5,(area.minX+area.maxX)/2,area.maxZ,width,.4,selected,.05)
	part(6,center.X,center.Z,size.X,.18,grid,.2)
	part(7,center.X,center.Z,.18,size.Z,grid,.2)
	part(8,center.X-size.X/2,center.Z,.18,size.Z,grid,.2)
	part(9,center.X+size.X/2,center.Z,.18,size.Z,grid,.2)
	part(10,center.X,center.Z-size.Z/2,size.X,.18,grid,.2)
	part(11,center.X,center.Z+size.Z/2,size.X,.18,grid,.2)
	for index,name in ipairs({"Upper Left","Upper Right","Lower Left","Lower Right"})do
		local anchorPoint=self:Region(name,center,size,y)
		local anchor=part(11+index,anchorPoint.X,anchorPoint.Z,.1,.1,grid,1)
		local label=anchor:FindFirstChild("QuadrantLabel")
		if not label then
			label=Instance.new("BillboardGui");label.Name="QuadrantLabel";label.Size=UDim2.fromOffset(160,28)
			label.StudsOffset=Vector3.new(0,4,0);label.AlwaysOnTop=true;label.MaxDistance=250;label.Parent=anchor
			local text=Instance.new("TextLabel");text.Name="Name";text.Size=UDim2.fromScale(1,1);text.BackgroundTransparency=1
			text.TextScaled=true;text.Font=Enum.Font.GothamSemibold;text.TextStrokeTransparency=.25;text.Parent=label
		end
		label.Enabled=true
		local text=label:FindFirstChild("Name");text.Text=name;text.TextColor3=name==cfg.autofarm.farmposition and selected or grid
	end
end
function fieldPositionPolicy:PreviewChanged()
	self:DrawPreview()
	if not cfg.autofarm.showfieldarea then return end
	if connections:Get("fieldAreaPreview") then return end
	local elapsed=0
	connections:Add("fieldAreaPreview",RunService.Heartbeat:Connect(function(dt)
		elapsed+=dt;if elapsed<.2 then return end;elapsed=0;self:DrawPreview()
	end))
end


field.Name="Stump Field";cfg.autofarm.field1=field.Name;currentField=field
cfg.autofarm.enabled=true;cfg.autofarm.idlefieldloop=true;cfg.autofarm.farmposenabled=true;cfg.autofarm.fieldedgeguards=true;cfg.autofarm.showfieldarea=true
root.Position=Vector3.new(100,24,200)
for _,name in ipairs({"Upper Left","Upper Right","Lower Left","Lower Right"})do
 cfg.autofarm.farmposition=name
 local points=assert(fieldPositionPolicy:StumpPolygon(field))
 assert(#points==19)
 local ia,ib=fieldPositionPolicy:StumpCrossing(points)
 local inner=points[1]-points[#points]
 local crossing=points[ia]-points[ib]
 assert(math.abs(inner.X*crossing.Z-inner.Z*crossing.X)<.0001,"inner side must be parallel to crossing")
 local positive,negative=0,0
 for _,p in ipairs(points)do
  local d=(crossing.X*(p.Z-points[ia].Z)-crossing.Z*(p.X-points[ia].X))/crossing.Magnitude
  positive=math.max(positive,d);negative=math.max(negative,-d)
 end
 assert(math.abs(positive-negative)<.0001,"straight edge and furthest curve must be equally far from crossing")

 local perimeter=0
 for i,p in ipairs(points)do perimeter+=(points[i%#points+1]-p).Magnitude end
 local route,sections=fieldPositionPolicy:StumpRoute(points)
 local length=0;local interior=0
 for i,p in ipairs(route)do
  length+=(route[i%#route+1]-p).Magnitude
  assert(fieldPositionPolicy:InsidePolygon(p,points),"middle crossing must stay inside barriers")
  local boundary=false
  for j,q in ipairs(points)do
   local r=points[j%#points+1]
   if math.abs((r.X-q.X)*(p.Z-q.Z)-(r.Z-q.Z)*(p.X-q.X))<.001 then boundary=true end
  end
  if not boundary then interior+=1 end
 end
 assert(math.abs(length-2*perimeter-2*(points[ib]-points[ia]).Magnitude)<.001,"two infinity repetitions must each cover both sides and middle once")
 assert(interior>2,"route must walk through the interior")
 assert(#sections==6)
 for i,section in ipairs(sections)do
  assert(section.name==({"curved","middle","straight"})[(i-1)%3+1])
  assert(section.name~=sections[i%#sections+1].name,"never immediately repeat the finished section")
 end


 local centroid=Vector3.zero
 for _,p in ipairs(points)do centroid+=p end
 centroid/=#points
 assert(fieldPositionPolicy:InsidePolygon(centroid,points))
 root.Position=Vector3.new(centroid.X,24,centroid.Z)
 local _,routeArea=fieldPositionPolicy:Region(name,field.Position,fieldPositionPolicy:QuadrantSize(field),24)
 for i=1,90 do
  local goal=assert(fieldPositionPolicy:IdleLoopGoal({area=routeArea},function()return false end))
  assert(fieldPositionPolicy:InsidePolygon(goal,points),"idle route must remain in preview footprint")
  root.Position=goal
 end
 root.Position=Vector3.new(100,24,200)

 assert(not fieldPositionPolicy:InsidePolygon(field.Position,points),"inner pointed corner must be cut out")
 local _,area=fieldPositionPolicy:Region(name,field.Position,fieldPositionPolicy:QuadrantSize(field),24)
 local outside=Vector3.new((area.minX+area.maxX)/2<field.Position.X and area.minX or area.maxX,24,(area.minZ+area.maxZ)/2<field.Position.Z and area.minZ or area.maxZ)
 assert(not fieldPositionPolicy:Allowed(outside,{area=area}),"empty outer corner must be excluded")
 fieldPositionPolicy:DrawPreview()
 local folder=assert(fieldPositionPolicy.preview)
 assert(fieldPositionPolicy.previewMode=="stump" and #folder:GetChildren()==33+#points)
 for _,p in ipairs(folder:GetChildren())do
  assert(not p.CanCollide and not p.CanTouch and not p.CanQuery)
  if p.Transparency==0.82 then
   for _,sx in ipairs({-1,1})do for _,sz in ipairs({-1,1})do
    assert(fieldPositionPolicy:InsidePolygon(Vector3.new(p.CFrame.X+sx*p.Size.X/2,24,p.CFrame.Z+sz*p.Size.Z/2),points),"fill outside: "..name.." "..p.Name.." at "..tostring(p.CFrame.X+sx*p.Size.X/2)..","..tostring(p.CFrame.Z+sz*p.Size.Z/2))
   end end
  end
 end
 for i=1,100 do fieldPositionPolicy:DrawPreview();assert(fieldPositionPolicy.preview==folder and #folder:GetChildren()==33+#points)end
 root.Position=Vector3.new(centroid.X,24,centroid.Z)
 fieldPositionPolicy.idleDrive={field=field}
 fieldPositionPolicy:UpdateGuards(true)
 local guards=assert(fieldPositionPolicy.guards)
 assert(#guards:GetChildren()==#points,"barriers must follow every polygon edge")
 fieldPositionPolicy:UpdateGuards(false);assert(not fieldPositionPolicy.guards and not guards.Parent)
 fieldPositionPolicy:StopPreview();assert(not fieldPositionPolicy.preview)
end
cfg.autofarm.stumpsmileyonly=true
assert(fieldPositionPolicy:SmileyOnly())
cfg.autofarm.stumpsmileyonly=false;assert(not fieldPositionPolicy:SmileyOnly())
field.Name="Pepper Patch";cfg.autofarm.stumpsmileyonly=true
assert(not fieldPositionPolicy:StumpPolygon(field) and not fieldPositionPolicy:SmileyOnly(),"other fields must retain old behavior")
print("PASS: four mirrored trimmed Stump shapes, contained preview fill, part reuse, polygon guards, cleanup and Stump-only smiley toggle")

local gatheringPriorities={}
function gatheringPriorities:Enabled(category, opts)
	if fieldPositionPolicy:SmileyOnly() then return category=="Duped Smiley" or category=="Combo Coconuts" end
	if opts.mondotokens and category ~= "Tokens" and category ~= "Priority Tokens" and category ~= "Token Links" and category ~= "Duped Tokens" and category ~= "Duped Smiley" and category ~= "Duped Bear" then return false end
	local farm = cfg.autofarm
	if category == "Blooms" then return not opts.loot and opts.blooms and farm.farmblooms end
	if category == "Petals" then return farm.farmblooms or farm.farmpetals or opts.petals end
	if category == "Precise Targets" then return farm.farmprecise or farm.farmprecisemark or cfg.convert.standInPrecise end
	if category == "Bubbles" then return not opts.loot and (farm.farmbubbles or (farm.autopopstar and (buffs["Pop Star Aura"] or buffs["Tidal Surge"]))) end
	if category == "Flames" then return not opts.loot and (farm.farmfires or (farm.autoscorchingstar and buffs["Scorching Star Aura"])) end
	if category == "Priority Tokens" then return not opts.ignoreprio end
	if category == "Token Links" then return not opts.combo end
	if category == "Tokens" then return true end
	if opts.loot then return false end
	if (category == "Showers" or category == "Coconuts") and opts.nowait then return false end
	if category == "Duped Bear" and not bearCombat:Ready() then return false end
	if category == "Puppy Ball" then
		local buff = buffs.ReindeerFetch
		if buff and buff.Text.Text == "x10" and buff.Percent.Size.Y.Scale >= 0.5 then return false end
	end
	if category == "Clouds" and buffs.Cloud and buffs.Cloud.Size.Y.Scale >= 0.25 then return false end
	if category == "Duped Tokens" or category == "Duped Smiley" or category == "Duped Bear" then
		return farm.farmdupedtokens or opts.dupedtokensquest
	end
	local flag = self.flags[category]
	return flag and farm[flag] == true
end


field.Name="Stump Field";cfg.autofarm.stumpsmileyonly=true
assert(gatheringPriorities:Enabled("Duped Smiley",{}))
assert(gatheringPriorities:Enabled("Combo Coconuts",{}))
for _,category in ipairs({"Petals","Blooms","Tokens","Token Links","Precise Targets","Showers"})do
 assert(not gatheringPriorities:Enabled(category,{}),"non-smiley category interrupted Stump idle")
end
print("PASS: only combos and smileys eligible to interrupt exclusive Stump idle mode")

local PhysicalProperties={new=function(d,f,e,fw,ew)return {Density=d,Friction=f,Elasticity=e,FrictionWeight=fw,ElasticityWeight=ew}end}

field.Name="Stump Field";cfg.autofarm.field1=field.Name
cfg.autofarm.stumpsmileyonly=false;cfg.autofarm.idlepatternmass=true;cfg.autofarm.idlepattern140=true
state.activityStatus=1;h.WalkSpeed=30
root.CurrentPhysicalProperties=PhysicalProperties.new(.7,.5,.2,1,1)
root.CustomPhysicalProperties=nil;root.Massless=true
local polygon=fieldPositionPolicy:StumpPolygon(field)
local inside=Vector3.zero
for _,p in ipairs(polygon)do inside+=p end
inside/=#polygon
root.Position=Vector3.new(field.Position.X,24,field.Position.Z)
fieldPositionPolicy.idleDrive=nil
fieldPositionPolicy:StartIdle(function()return Vector3.new(inside.X,24,inside.Z)end,function()return true end)
assert(h.WalkSpeed==140 and math.abs(root.CustomPhysicalProperties.Density-7)<.00001 and not root.Massless)
local physics=root.CustomPhysicalProperties
fieldPositionPolicy:DriveIdle();assert(root.CustomPhysicalProperties==physics,"reuse density across frames")
fieldPositionPolicy:UpdateGuards(true)
assert(not fieldPositionPolicy.guards,"barriers must not block approach from cut-off corner")
root.Position=Vector3.new(inside.X,24,inside.Z)
fieldPositionPolicy:UpdateGuards(true);assert(fieldPositionPolicy.guards)
fieldPositionPolicy:ReleaseIdle();fieldPositionPolicy:UpdateGuards(true)
assert(not fieldPositionPolicy.guards and h.WalkSpeed==30 and root.CustomPhysicalProperties==nil and root.Massless)
print("PASS: entry before barriers, active-loop guards, 140 PMS, 10x density reuse and exact restoration")

field.Name="Pepper Patch";cfg.autofarm.field1=field.Name
local origin=fieldPositionPolicy:Region(cfg.autofarm.farmposition,field.Position,fieldPositionPolicy:QuadrantSize(field),24)
fieldPositionPolicy.idleDrive={field=field}
root.Position=Vector3.new(200,24,200)
fieldPositionPolicy:UpdateGuards(true);assert(not fieldPositionPolicy.guards)
root.Position=origin
fieldPositionPolicy:UpdateGuards(true);assert(fieldPositionPolicy.guards and #fieldPositionPolicy.guards:GetChildren()==4)
fieldPositionPolicy:ReleaseIdle();fieldPositionPolicy:UpdateGuards(true);assert(not fieldPositionPolicy.guards)
cfg.autofarm.idlepattern140=false;cfg.autofarm.idlepatternmass=false
fieldPositionPolicy:StartIdle(function()return origin+Vector3.new(10,0,0)end,function()return true end)
assert(h.WalkSpeed==30 and root.CustomPhysicalProperties==nil and root.Massless)
fieldPositionPolicy:ReleaseIdle()
print("PASS: rectangular quadrant entry gating and independent disabled physics/speed toggles")


field.Name="Stump Field";currentField=field;cfg.autofarm.field1=field.Name
cfg.autofarm.stumpcoverage=true -- obsolete saved flag must not restore strip mode
h.WalkSpeed=30
for _,name in ipairs({"Upper Left","Upper Right","Lower Left","Lower Right"})do
 cfg.autofarm.farmposition=name
 local polygon=fieldPositionPolicy:StumpPolygon(field)
 local points=fieldPositionPolicy:StumpRoute(polygon)
 local _,area=fieldPositionPolicy:Region(name,field.Position,fieldPositionPolicy:QuadrantSize(field),24)
 fieldPositionPolicy.idleLoop=nil
 root.Position=Vector3.new(points[1].X,24,points[1].Z)
 local wrapped=false
 for i=1,#points*3 do
  local goal=assert(fieldPositionPolicy:IdleLoopGoal({area=area},function()return false end))
  assert(fieldPositionPolicy.idleLoop.infinity and not fieldPositionPolicy.idleLoop.lanes)
  if fieldPositionPolicy.idleLoop.index>1 then wrapped=true end
  assert(fieldPositionPolicy:InsidePolygon(goal,polygon))
  root.Position=goal
 end
 assert(wrapped)
 fieldPositionPolicy:DrawPreview()
 assert(#fieldPositionPolicy.preview:GetChildren()==33+#polygon,"preview must have only one middle line, no strips")
 fieldPositionPolicy:StopPreview()
end
print("PASS: continuous infinity, each side and middle once per repetition, no strip mode")


field.Name="Stump Field";currentField=field;cfg.autofarm.field1=field.Name
cfg.autofarm.showfieldarea=true;cfg.autofarm.showallstump=true
local function quadrantCenter(name)
 local _,area=fieldPositionPolicy:Region(name,field.Position,fieldPositionPolicy:QuadrantSize(field),24)
 local polygon=fieldPositionPolicy:StumpPolygon(field,area)
 local center=Vector3.zero;for _,p in ipairs(polygon)do center+=p end
 center/=#polygon;return Vector3.new(center.X,24,center.Z)
end
root.Position=quadrantCenter("Upper Left")
Players.list={player}
fieldPositionPolicy:DrawPreview()
local all=assert(fieldPositionPolicy.preview)
assert(#all:GetChildren()==4 and fieldPositionPolicy.previewMode=="stumpAll")
for name,view in pairs(fieldPositionPolicy.allStumpViews)do
 local occupied=name=="Upper Left"
 assert((view.color.G>view.color.R)==occupied,"occupancy colors must match physical presence")
 assert(string.find(view.label,occupied and player.Name or "Unoccupied",1,true))
 for _,p in ipairs(view.preview:GetChildren())do assert(not p.CanCollide and not p.CanTouch and not p.CanQuery)end
end
for _,name in ipairs({"Upper Right","Lower Left","Lower Right"})do
 local alt={Name=name.."Alt"};alt.Character=Instance.new("Model",workspace)
 local ah=Instance.new("Humanoid",alt.Character);ah.Health=100
 local ar=Instance.new("Part",alt.Character);ar.Name="HumanoidRootPart";ar.Position=quadrantCenter(name)
 Players.list[#Players.list+1]=alt
end
fieldPositionPolicy:DrawPreview()
for _,view in pairs(fieldPositionPolicy.allStumpViews)do assert(view.color.G>view.color.R)end
local count=0;for _,view in pairs(fieldPositionPolicy.allStumpViews)do count+=#view.parts end
for i=1,100 do
 fieldPositionPolicy:DrawPreview();assert(fieldPositionPolicy.preview==all)
 local nextCount=0;for _,view in pairs(fieldPositionPolicy.allStumpViews)do nextCount+=#view.parts end
 assert(nextCount==count,"all-quadrant preview must reuse parts")
end
Players.list={player};fieldPositionPolicy:DrawPreview()
assert(fieldPositionPolicy.allStumpViews["Upper Right"].color.R>fieldPositionPolicy.allStumpViews["Upper Right"].color.G)
fieldPositionPolicy:PreviewChanged();local ticker=assert(connections:Get("fieldAreaPreview"))
fieldPositionPolicy:PreviewChanged();assert(connections:Get("fieldAreaPreview")==ticker)
cfg.autofarm.showallstump=false;fieldPositionPolicy:DrawPreview()
assert(not all.Parent and fieldPositionPolicy.previewMode=="stump" and not fieldPositionPolicy.allStumpViews)
fieldPositionPolicy:StopPreview();assert(not fieldPositionPolicy.preview and not connections:Get("fieldAreaPreview"))
print("PASS: all four previews, red empty/green occupied labels, live updates, bounded part reuse and cleanup")
