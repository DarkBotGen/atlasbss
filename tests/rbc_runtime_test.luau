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
local rbcSafety={}
cfg.rbc={}

os.time=function()return 100+now end
cfg.rbc={enabled=true,trackmobs=true,precise=true,buffupkeep=true}
cfg.beesmas={roboparty=false};cfg.vars={movement="Tween"};cfg.convert={standInPrecise=false}
cfg.autofarm.enabled=true;cfg.autofarm.precisionupkeep=true
local tracked={};for _,key in ipairs({"cogs","goldcogs","cogturrets","mech","megamech","mobs","cogsaws","partycog","partymech","partycogturret","partymegamech","precise","precise2","precisemark","precisegroup","tokenlink","tokens","dupedbear","dupedtokens"})do tracked[key]={}end
local getFieldAt,isPathClear,setField,watchRbcMobs
local position,currentFieldName
local availableFields={["Pepper Patch"]=true,["Pine Tree Forest"]=true,["Spider Field"]=true}
local ReplicatedStorage=Instance.new("Folder")
local flyingModule=Instance.new("ModuleScript",ReplicatedStorage);flyingModule.Name="LocalFlyingEntity"
local registry={};local failRegistry=false
require=function()return {Destroy=function()end}end
local function getupvalue()if failRegistry then error("internals unavailable")end;return registry end
local gameApi={Events=Instance.new("Folder"),BuffTile=function()return nil end}
local fx=Instance.new("RemoteEvent",gameApi.Events);fx.Name="LocalFX";fx.OnClientEvent=signal()
local casts,paramsCreated=0,0
local RaycastParams={new=function()paramsCreated+=1;return {}end}
function workspace:Raycast(origin,direction,params)
 casts+=1;assert(direction.Y<0 and params.FilterDescendantsInstances[1]==zones)
 for _,f in ipairs(zones:GetChildren())do
  if math.abs(origin.X-f.Position.X)<=f.Size.X/2 and math.abs(origin.Z-f.Position.Z)<=f.Size.Z/2 and origin.Y>=f.Position.Y and origin.Y+direction.Y<=f.Position.Y then return {Instance=f}end
 end
end
local fieldPositionPolicy={UsableSize=function(_,f)return f.Size end,InsideGuardedField=function()return false end}
local logger={warn=function()end}
local UserInputService={MouseIcon=""};local input={}
local moves=0
local function tweenTo(p)moves+=1;root.Position=p end
local function travelTo(p)moves+=1;root.Position=p end
RunService.Heartbeat.Wait=function()now+=.05;return true end
task.wait=function(d)now+=d or .01 end
local buffs={Graph={},Bear=true}
local bearCombat={icons={["1472425802"]=true},Remaining=function()return 100 end,Icon=function(_,o)return tostring(o.Icon)end}
local dupedTokenPolicy={Allowed=function()return false end}
local gatheringPriorities={}
local touchedMarks={}
local comboController={active=false,TravelBlocked=function()return false end}
local showerController={active=false}
local function distanceTo(p)return (p-root.Position).Magnitude end
local function secureCall(fn,...)return fn(...)end
local rbcSafety={}
function rbcSafety:Reset()
	self.hazards,self.hazardField,self.hazardAt,self.flying,self.nextFlyingCheck=nil,nil,nil,nil,nil
	self.buffNeeds,self.buffCheck,self.fieldRaycastParams,self.fieldRaycastFolder=nil,nil,nil,nil
	self.lastSawKey,self.lastSawAt,self.roundActive=nil,nil,nil
	self.pathParams,self.pathMap,self.pathGates,self.pathDecorations,self.pathBoards=nil,nil,nil,nil,nil
end
function rbcSafety:PathParams()
	local map,gates,decorations,boards=workspace:FindFirstChild("Map"),workspace:FindFirstChild("Gates"),workspace:FindFirstChild("Decorations"),workspace:FindFirstChild("Leaderboards")
	if self.pathParams and self.pathMap==map and self.pathGates==gates and self.pathDecorations==decorations and self.pathBoards==boards then return self.pathParams end
	local filter={}
	for _,name in ipairs({"Map","Gates","Decorations","Leaderboards"}) do
		local object=workspace:FindFirstChild(name)
		if object then filter[#filter+1]=object end
	end
	local params=RaycastParams.new()
	params.FilterDescendantsInstances=filter;params.FilterType=Enum.RaycastFilterType.Include
	self.pathParams,self.pathMap,self.pathGates,self.pathDecorations,self.pathBoards=params,map,gates,decorations,boards
	return params
end
function rbcSafety:ResolveField(name,pollen)
	local zones=workspace:FindFirstChild("FlowerZones")
	if not zones then return end
	local defaults={Red="Pepper Patch",Blue="Pine Tree Forest",White="Spider Field"}
	for _,candidate in ipairs({type(name)=="string" and name or "",defaults[pollen] or "",cfg.autofarm.field1 or ""}) do
		local field=candidate~="" and zones:FindFirstChild(candidate)
		if field and field:IsA("BasePart") and (not availableFields or availableFields[candidate]) then return field.Name end
	end
	if availableFields then
		for candidate,enabled in pairs(availableFields) do
			local field=zones:FindFirstChild(candidate)
			if enabled and field and field:IsA("BasePart") then return candidate end
		end
	end
end
function rbcSafety:FlyingRegistry()
	local now=os.clock()
	if self.nextFlyingCheck and now<self.nextFlyingCheck then return self.flying end
	self.nextFlyingCheck=now+2
	local ok,registry=pcall(function()
		local module=ReplicatedStorage:FindFirstChild("LocalFlyingEntity")
		if not module or type(getupvalue)~="function" then return end
		local destroy=require(module).Destroy
		local first,second=getupvalue(destroy,3)
		local result=type(first)=="table" and first or second
		if type(result)=="table" then return result end
	end)
	self.flying=ok and registry or nil
	return self.flying
end
function rbcSafety:Segment(map,a,b,radius,admit)
	if typeof(a)~="Vector3" or typeof(b)~="Vector3" then return end
	local delta=b-a
	local steps=math.clamp(math.ceil(delta.Magnitude/8),1,16)
	for i=0,steps do admit(a+delta*(i/steps),radius) end
end
function rbcSafety:Hazards(field)
	local now=os.clock()
	if self.hazardField==field and self.hazardAt and now-self.hazardAt<.1 then return self.hazards end
	local map,count={},0
	self.hazards,self.hazardField,self.hazardAt=map,field,now
	if not field or not tracked then return map end
	local center,size=field.Position,field.Size
	local char=localPlayer.Character
	local root=char and char:FindFirstChild("HumanoidRootPart")
	local y=root and root.Position.Y or center.Y
	local function admit(pos,radius)
		if count>=256 or typeof(pos)~="Vector3" then return end
		if math.abs(pos.X-center.X)>size.X/2+20 or math.abs(pos.Z-center.Z)>size.Z/2+20 or math.abs(pos.Y-center.Y)>60 then return end
		local point=Vector3.new(pos.X,y,pos.Z)
		if not map[point] then count+=1 end
		map[point]=math.max(map[point] or 0,radius)
	end
	for _,entry in ipairs({{"cogs",20},{"goldcogs",20},{"cogturrets",18},{"mech",12},{"megamech",18},{"mobs",12}}) do
		local list=tracked[entry[1]] or {}
		for model in pairs(list) do
			if typeof(model)~="Instance" or not model.Parent then list[model]=nil;continue end
			local body=model:FindFirstChild("Body") or model:FindFirstChild("HumanoidRootPart")
			if body and body:IsA("BasePart") then
				admit(body.Position,entry[2])
				local velocity=body.AssemblyLinearVelocity
				if velocity.Magnitude>1 then self:Segment(map,body.Position,body.Position+velocity*.35,entry[2],admit) end
			end
		end
	end
	if cfg.rbc.trackmobs then
		for kind,group in pairs(self:FlyingRegistry() or {}) do
			if type(kind)=="string" and (string.find(kind,"Cog",1,true) or string.find(kind,"Mech",1,true)) and type(group)=="table" then
				for entity in pairs(group) do
					if type(entity)=="table" and entity.Alive and typeof(entity.Pos)=="Vector3" then
						admit(entity.Pos,kind=="Mechsquito" and 12 or 20)
						if entity.Moving and typeof(entity.PosNext)=="Vector3" then
							local delta=entity.PosNext-entity.Pos
							local finish=delta.Magnitude>35 and entity.Pos+delta.Unit*35 or entity.PosNext
							self:Segment(map,entity.Pos,finish,15,admit)
						end
					end
				end
			end
		end
	end
	for saw in pairs(tracked.cogsaws or {}) do
		if type(saw)=="table" and saw.ExpiresAt and saw.ExpiresAt<=now then tracked.cogsaws[saw]=nil
		elseif type(saw)=="table" then self:Segment(map,saw.Start,saw.End,15,admit) end
	end
	return map
end
function rbcSafety:ObserveFX(name,data)
	if name~="CogSawProjectile" or type(data)~="table" or not tracked then return end
	if typeof(data.Pos1)~="Vector3" or typeof(data.Pos2)~="Vector3" then return end
	local now=os.clock()
	local key=tostring(data.Pos1)..":"..tostring(data.Pos2)..":"..tostring(data.EndTime)
	if self.lastSawKey==key and now-(self.lastSawAt or 0)<.1 then return end
	self.lastSawKey,self.lastSawAt=key,now
	local count=0
	for entry in pairs(tracked.cogsaws) do
		if entry.ExpiresAt and entry.ExpiresAt<=now then tracked.cogsaws[entry]=nil else count+=1 end
	end
	if count>=64 then return end
	local serverTime=workspace:FindFirstChild("ServerTime")
	local duration=tonumber(data.Dur) or 2
	if type(data.EndTime)=="number" and serverTime then duration=data.EndTime-serverTime.Value end
	local entry={Start=data.Pos1,End=data.Pos2,ExpiresAt=now+math.clamp(duration,0,12)}
	tracked.cogsaws[entry]=true
end
function rbcSafety:Escape(field,options)
	if not field then return end
	local root=getRootPart().Position
	local hazards=options.avoid or {}
	local function clearance(point)
		local closest=math.huge
		for position,radius in pairs(hazards) do
			if typeof(position)=="Vector3" then
				local delta=Vector3.new(point.X-position.X,0,point.Z-position.Z)
				closest=math.min(closest,delta.Magnitude-radius)
			end
		end
		return closest
	end
	local current=clearance(root)
	if current>=2 then return end
	local best,bestScore=nil,current
	for i=0,15 do
		local angle=i*math.pi/8
		for _,distance in ipairs({12,24,36}) do
			local p=root+Vector3.new(math.cos(angle)*distance,0,math.sin(angle)*distance)
			local c,size=field.Position,field.Size
			if math.abs(p.X-c.X)>size.X/2-2 or math.abs(p.Z-c.Z)>size.Z/2-2 then continue end
			local safe=clearance(p)
			local score=safe-distance*.02
			if score>bestScore+1 and not isPathClear(p,hazards,true,true) then best,bestScore=p,score end
		end
	end
	return best
end
function rbcSafety:Options(field,extra)
	local options=table.clone(extra or {})
	options.rbc,options.avoid,options.skipoverlap=true,self:Hazards(field),true
	return options
end

	setField = function(fieldName)
		local zones=workspace:FindFirstChild("FlowerZones")
		local field=type(fieldName)=="string" and zones and zones:FindFirstChild(fieldName)
		if not field or not field:IsA("BasePart") then return false end
		if currentField~=field or not position or not vector then
			currentField,position,currentFieldName=field,field.Position,field.Name
			vector=fieldPositionPolicy:UsableSize(field)
		end
		return true
	end

	getFieldAt = function(point)
		if typeof(point)~="Vector3" then return end
		local zones=workspace:FindFirstChild("FlowerZones")
		if not zones then return end
		if not rbcSafety.fieldRaycastParams or rbcSafety.fieldRaycastFolder~=zones then
			local params=RaycastParams.new()
			params.FilterDescendantsInstances={zones}
			params.FilterType=Enum.RaycastFilterType.Include
			rbcSafety.fieldRaycastParams,rbcSafety.fieldRaycastFolder=params,zones
		end
		local hit=workspace:Raycast(point+Vector3.new(0,8,0),Vector3.new(0,-128,0),rbcSafety.fieldRaycastParams)
		return hit and hit.Instance.Parent==zones and hit.Instance or nil
	end

	isPathClear = function(target,avoid,allowEscape,rbc,overlap)
		-- Historical name: true means the path is BLOCKED by an avoidance zone.
		if typeof(target)~="Vector3" then return true end
		local root=getRootPart()
		local start=root.Position
		local delta=target-start
		local lengthSquared=delta:Dot(delta)
		for object,value in pairs(avoid or {}) do
			if type(value)~="number" then continue end
			local radius,timestamp=value,nil
			if radius>100 then timestamp=radius;radius=24 end
			local point
			if typeof(object)=="Vector3" then point=object
			elseif type(object)=="table" then point=object.Position
			elseif typeof(object)=="Instance" and object.Parent then
				local plane=object:FindFirstChild("Plane")
				if plane and plane:IsA("BasePart") then point=plane.Position
				elseif object:IsA("BasePart") then point=object.Position end
			end
			if typeof(point)~="Vector3" then continue end
			if (target-point).Magnitude<radius then return true end
			if timestamp and not rbc and 2.2-(os.time()-timestamp)<math.sqrt(lengthSquared)/math.max(1,getHumanoid().WalkSpeed) then return true end
			local startDistance=(start-point).Magnitude
			if allowEscape and startDistance<=(overlap and radius-6 or radius) then continue end
			if lengthSquared>.000001 then
				local t=math.clamp((point-start):Dot(delta)/lengthSquared,0,1)
				if (point-(start+delta*t)).Magnitude<radius then return true end
			end
		end
		return false
	end

local goToField
	goToField = function()
		local field=currentField
		if not field or not field.Parent or not position then error("return",0) end
		local function arrived()
			local char=localPlayer.Character
			local root=char and char:FindFirstChild("HumanoidRootPart")
			local h=char and char:FindFirstChildOfClass("Humanoid")
			if not root or not h or h.Health<=0 then return false end
			local p,c,size=root.Position,field.Position,field.Size
			return p.Y>=c.Y+size.Y/2-3 and p.Y<=c.Y+size.Y/2+18 and (getFieldAt(p)==field or fieldPositionPolicy:InsideGuardedField(field,p))
		end
		if arrived() then return true end
		if state.fasttween or state.stop then error("return",0) end
		state.stopface=true
		if UserInputService.MouseIcon=="rbxasset://textures/MouseLockedCursor.png" then
			input.prepareInput();input.pressKey(Enum.KeyCode.LeftShift)
		end
		if cfg.vars.movement~="Tween" then
			travelTo(field.Position+Vector3.new(0,0,field.Name=="Coconut Field" and -10 or 0),field.Name)
		else
			tweenTo(field.Position+Vector3.new(0,(field.Name=="Coconut Field" or field.Name=="Stump Field") and 16 or 9,field.Name=="Coconut Field" and -10 or 0))
		end
		local deadline=os.clock()+1.25
		while not arrived() and os.clock()<deadline and not state.stop do RunService.Heartbeat:Wait() end
		state.stopface=nil
		if arrived() then return true end
		-- Caller retries on its next managed pass; never dereference a nil player field.
		task.wait(.25)
		error("return",0)
	end
	watchRbcMobs = function(enable)
		if not enable or connections:Get("rbcmobs") then
			if not enable and not cfg.rbc.enabled and not cfg.beesmas.roboparty then
				connections:Cancel("rbcmobs")
				connections:Cancel("rbcmobs2")
				connections:Cancel("rbcMobFX")
				for _,key in ipairs({"goldcogs","cogturrets","partymech","partycog","partycogturret","partymegamech","megamech","mech","cogs","cogsaws"}) do table.clear(tracked[key]) end
				rbcSafety:Reset()
			end
		else
			local fx=gameApi.Events and gameApi.Events:FindFirstChild("LocalFX")
			if fx then connections:Add("rbcMobFX",fx.OnClientEvent:Connect(function(name,data)rbcSafety:ObserveFX(name,data)end)) end
			local mobKeys = {
				["Gold Cogmower"] = "goldcogs",
				Cogturret = "cogturrets",
				["Party Mechsquito"] = "partymech",
				["Party Cogmower"] = "partycog",
				["Party Cogturret"] = "partycogturret",
				["Party Mega Mechsquito"] = "partymegamech",
				["Mega Mechsquito"] = "megamech",
				Mechsquito = "mech",
				Cogmower = "cogs",
			}

			connections:Add("rbcmobs", workspace.ChildAdded:Connect(function(n)
				local l = mobKeys[n.Name]

				if l then
					tracked[l][n] = true
				end
			end))

			connections:Add("rbcmobs2", workspace.ChildRemoved:Connect(function(n)
				local l = mobKeys[n.Name]

				if l then
					tracked[l][n] = nil
				end
			end))

			for _, child in ipairs(workspace:GetChildren()) do
				local mobKey = mobKeys[child.Name]

				if mobKey then
					tracked[mobKey][child] = true
				end
			end
		end
	end
function rbcSafety:BuffTarget(options)
	if not options.rbc or cfg.rbc.buffupkeep==false or options.loot then return end
	local now=os.clock()
	if not self.buffCheck or now-self.buffCheck>=.5 then
		self.buffCheck=now
		local needs={}
		for _,entry in ipairs({
			{"Haste","haste","65867881",10},{"Focus","focus","1629649299",10},
			{"Melody","melody","253828517",1},{"Baby Love","babylove","1472256444",1},
			{"Blue Boost","blueboost","1442863423",10},{"Red Boost","redboost","1442859163",10},
			{"Inspire","inspire","2000457501",1}}) do
			local label=buffs.Graph and buffs.Graph[entry[2]]
			local count=label and tonumber(string.match(label.Text,"%d+")) or (label and 1 or 0)
			local needed=count<entry[4]
			if not needed then
				local ok,tile=pcall(secureCall,gameApi.BuffTile,entry[1])
				if ok and type(tile)=="table" and type(tile.TimerDur)=="number" and type(tile.TimerStart)=="number" then
					needed=tile.TimerDur-(os.time()-tile.TimerStart)<=math.max(3,tile.TimerDur*.3)
				end
			end
			if needed then needs[entry[3]]=true end
		end
		local remaining=bearCombat:Remaining()
		if not buffs.Bear or remaining and remaining<=10 then for icon in pairs(bearCombat.icons) do needs[icon]=true end end
		self.buffNeeds=needs
	end
	local root=getRootPart().Position
	local best,bestDistance,kind
	for _,key in ipairs({"tokenlink","tokens","dupedbear","dupedtokens"}) do
		local duped=key=="dupedbear" or key=="dupedtokens"
		if duped and not cfg.autofarm.farmdupedtokens then continue end
		for object,value in pairs(tracked[key] or {}) do
			if type(object)=="number" then object=value end
			if typeof(object)=="Instance" and not object.Parent then continue end
			local icon=bearCombat:Icon(object)
			if not icon or (key~="tokenlink" and not self.buffNeeds[icon]) then continue end
			if duped and not dupedTokenPolicy:Allowed(object) then continue end
			local position=object.Position
			if typeof(position)~="Vector3" then continue end
			if duped then position-=Vector3.new(0,10,0) end
			local distance=(position-root).Magnitude
			if distance>(key=="tokenlink" and 20 or 45) or not gatheringPriorities:Allowed(position,options,root) then continue end
			local score=distance*(key=="tokenlink" and .5 or 1)
			if not best or score<bestDistance then best,bestDistance,kind=object,score,duped and (bearCombat.icons[icon] and "Duped Bear" or "Duped") or "Token" end
		end
	end
	return kind,best
end
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
	local rbcUpkeep=opts.rbc and cfg.rbc.precise
	if (not rbcUpkeep and (farm.precisionupkeep==false or not farm.enabled or state.activityStatus~=1))
		or opts.loot or opts.mondotokens then return end
	if comboController.active or showerController.active or comboController:TravelBlocked() then return end
	local copy=self:PrecisionOptions(opts)
	if not self:PrecisionReady() then
		for target in pairs(tracked.precise)do copy.avoid[target]=nil end
		for _,target in pairs(tracked.precise2)do copy.avoid[target]=nil end
	end
	return self:Precise(copy,true)
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
							if opts.area and not fieldPositionPolicy:TrackedAllowed(k,nil,opts) then continue end
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
									if not ((not opts.ignorefield or getFieldAt(k.Position)) and not (not opts.ignorefield and getFieldAt(k.Position) == currentField) or (not (upkeep and not opts.rbc and preciseKind=="Precise Purple") and not (not opts.avoid or not isPathClear(k.Position, opts.avoid)))) then
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
							if opts.area and not fieldPositionPolicy:TrackedAllowed(k,preciseMark,opts) then continue end
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
									if not ((not opts.ignorefield or getFieldAt(preciseMark.Position)) and not (not opts.ignorefield and getFieldAt(preciseMark.Position) == currentField) or (not (upkeep and not opts.rbc and precise2Kind=="Precise2Purple") and not (not opts.avoid or not isPathClear(preciseMark.Position, opts.avoid)))) then
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

local blue=Instance.new("Part",zones);blue.Name="Pine Tree Forest";blue.Position=makeVector(400,20,200);blue.Size=field.Size
local white=Instance.new("Part",zones);white.Name="Spider Field";white.Position=makeVector(700,20,200);white.Size=field.Size
assert(rbcSafety:ResolveField(false,"Blue")==blue.Name)
assert(rbcSafety:ResolveField("deleted","White")==white.Name)
assert(setField(field.Name) and currentField==field)
assert(not setField(nil) and currentField==field)
root.Position=makeVector(100,21,200)
assert(getFieldAt(root.Position)==field)
assert(getFieldAt(root.Position+makeVector(0,70,0))==field)
assert(getFieldAt(nil)==nil and paramsCreated==1,"reuse spatial query parameters")
local hazard=makeVector(110,21,200)
assert(isPathClear(makeVector(120,21,200),{[hazard]=4}))
assert(not isPathClear(makeVector(100,21,220),{[hazard]=4}))
assert(not isPathClear(root.Position,{}),"zero length path must be safe and finite")
assert(not isPathClear(makeVector(130,21,200),{[root.Position]=10},true,true),"allow escape from existing danger")
local removed=Instance.new("Part");removed:Destroy()
assert(not isPathClear(root.Position,{[removed]=12}),"removed hazard must not error")
local model=Instance.new("Model",workspace);model.Name="Cogmower"
local body=Instance.new("Part",model);body.Name="Body";body.Position=root.Position
tracked.cogs[model]=true
failRegistry=true
local map=rbcSafety:Hazards(field);assert(next(map),"live fallback must survive broken internal registry")
local cached=rbcSafety:Hazards(field);assert(cached==map)
local escape=rbcSafety:Escape(field,{avoid=map});assert(escape and (escape-root.Position).Magnitude>=12)
assert(not isPathClear(escape,map,true,true),"escape must lead out of danger")
model:Destroy();now+=.2
map=rbcSafety:Hazards(field);assert(not tracked.cogs[model] and not next(map),"removed model references must be pruned")
failRegistry=false;now+=3
registry={Cogmower={}}
local entity={Alive=true,Pos=root.Position,Moving=true,PosNext=root.Position+makeVector(24,0,0)}
registry.Cogmower[entity]=true
assert(next(rbcSafety:Hazards(field)),"live registry prediction must work")
registry.Cogmower={};now+=.2
rbcSafety:ObserveFX("CogSawProjectile",{Pos1=root.Position,Pos2=root.Position+makeVector(1,0,0),Dur=.1})
map=rbcSafety:Hazards(field);assert(next(map),"short saw path must include endpoints")
now+=.2;map=rbcSafety:Hazards(field);assert(not next(map) and not next(tracked.cogsaws))
for i=1,1000 do
 rbcSafety:ObserveFX("CogSawProjectile",{Pos1=root.Position+makeVector(i%10,0,0),Pos2=root.Position+makeVector(i%10+1,0,0),Dur=.1})
 now+=.2;rbcSafety:Hazards(field)
end
assert(not next(tracked.cogsaws),"expired projectiles must not accumulate")
registry.Cogmower={}
for i=1,400 do registry.Cogmower[{Alive=true,Pos=root.Position+makeVector(i%40,0,i%20)}]=true end
now+=3;map=rbcSafety:Hazards(field);local count=0;for _ in pairs(map)do count+=1 end
assert(count<=256,"hazard snapshot must stay bounded")
registry.Cogmower={};now+=.2
watchRbcMobs(true)
local a,b,c=connections:Get("rbcmobs"),connections:Get("rbcmobs2"),connections:Get("rbcMobFX")
assert(a and b and c)
for i=1,100 do watchRbcMobs(true)end
assert(connections:Get("rbcmobs")==a and connections:Get("rbcmobs2")==b and connections:Get("rbcMobFX")==c,"repeated toggles must not add listeners")
fx.OnClientEvent:Fire("CogSawProjectile",{Pos1=root.Position,Pos2=root.Position,Dur=.1})
assert(next(tracked.cogsaws))
cfg.rbc.enabled=false;watchRbcMobs(false)
assert(not connections:Get("rbcmobs") and not connections:Get("rbcMobFX") and not next(tracked.cogsaws))
assert(not rbcSafety.hazards and not rbcSafety.flying)
cfg.rbc.enabled=true
setField(field.Name);root.Position=makeVector(400,21,200);assert(goToField() and moves==1)
assert(getFieldAt(root.Position)==field and state.stopface==nil)
local previous=currentField;currentField=nil
local ok,err=pcall(goToField);assert(not ok and err=="return","missing destination must fail without nil indexing")
currentField=previous;root.Position=makeVector(100,21,200)
function gatheringPriorities:Allowed(p,options)return not isPathClear(p,options.avoid,true,true) end
tracked.tokens={}
local token={Name=true,Icon="65867881",Position=root.Position+makeVector(5,0,0)}
tracked.tokens[token]=true
local kind,object=rbcSafety:BuffTarget({rbc=true,avoid={}})
assert(kind=="Token" and object==token,"missing Haste should be collected")
local blocked=rbcSafety:BuffTarget({rbc=true,avoid={[token.Position]=12}})
assert(not blocked,"buff collection must not walk into a hazard")
cfg.rbc.buffupkeep=false;assert(not rbcSafety:BuffTarget({rbc=true,avoid={}}));cfg.rbc.buffupkeep=true
local mark=Instance.new("Part",particles);mark.Position=root.Position+makeVector(12,0,0);mark.BrickColor={Name="Alder"}
tracked.precise[mark]=true
buffs.Precision={Text={Text="x10"},Percent={Size={Y={Scale=.9}}}}
local unsafe={avoid={[mark.Position]=15},rbc=true}
assert(not gatheringPriorities:Precise(unsafe,true),"RBC purple Precision must honor mob hazards")
local precise=gatheringPriorities:Precise({avoid={},rbc=true},true)
assert(precise=="Precise Purple","safe purple Precision should remain eligible")
cfg.autofarm.enabled=false;state.activityStatus=3
local saved=gatheringPriorities.Precise
local called=false;gatheringPriorities.Precise=function()called=true end
gatheringPriorities:PrecisionUpkeep({rbc=true,avoid={}});assert(called,"RBC upkeep must work without ordinary autofarm")
gatheringPriorities.Precise=saved
rbcSafety:Reset();assert(not rbcSafety.hazards and not rbcSafety.flying and not rbcSafety.buffNeeds and not rbcSafety.fieldRaycastParams)
print("PASS: field validation, cached queries, vector/zero-length hazards, prediction fallback, escape, bounded projectile lifetimes, watcher cleanup, safe buffs and Precision")

local rbcAmuletCheck
local iterations=0
local function rbcAmuletStep()iterations+=1;return iterations<10000 end
	rbcAmuletCheck = function()
		while cfg.rbc.enabled and not state.stop do
			local ok,again=pcall(rbcAmuletStep)
			if not ok then rbcSafety.roundActive=nil;error(again,0) end
			if not again then rbcSafety.roundActive=nil;return end
			RunService.Heartbeat:Wait()
		end
		rbcSafety.roundActive=nil
	end

rbcAmuletCheck();assert(iterations==10000 and not rbcSafety.roundActive)
rbcAmuletStep=function()error("test step error")end
local ok=pcall(rbcAmuletCheck);assert(not ok and not rbcSafety.roundActive)
print("PASS: 10,000 iterative RBC transitions with error cleanup and no recursive round retention")
		local function buildAvoidGridOriginal(v128,area)
			local nodePositions = {}
			local nodeEdges = {}
			local nextNodeId = 1

			local function addNode(point)
				local nodeId = nextNodeId
				nextNodeId += 1
				local z = point.Z
				nodePositions[nodeId] = Vector3.new(math.floor(point.X), math.floor(point.Y), math.floor(z))
				nodeEdges[nodeId] = {}
				return nodeId
			end

			local function removeNode(nodeToRemove)
				nodePositions[nodeToRemove] = nil

				for k in pairs(nodeEdges[nodeToRemove]) do
					nodeEdges[nodeToRemove][k] = nil
					nodeEdges[k][nodeToRemove] = nil
				end

				nodeEdges[nodeToRemove] = nil
			end

			local function addLink(fromId, toId, bidirectional)
				nodeEdges[fromId][toId] = { bidirectional = bidirectional, label = "" }

				if bidirectional then
					nodeEdges[toId][fromId] = { bidirectional = true, label = "" }
				end
			end

			local edgeNodes = {}
			local edgeSet = {}
			local minX

			if vector.X > 3 then
				minX = position.X - vector.X / 2 + 1.5
			else
				minX = position.X - vector.X / 2
			end

			local maxX

			if vector.X > 3 then
				maxX = position.X + vector.X / 2 - 1.5
			else
				maxX = position.X + vector.X / 2
			end

			local minZ

			if vector.Z > 3 then
				minZ = position.Z - vector.Z / 2 + 1.5
			else
				minZ = position.Z - vector.Z / 2
			end

			local maxZ

			if vector.Z > 3 then
				maxZ = position.Z + vector.Z / 2 - 1.5
			else
				maxZ = position.Z + vector.Z / 2
			end

			local gridY = position.Y - vector.Y / 2 + 1
			local gridColumns = {}
			local countX = math.floor((maxX - minX) / 3)
			local countZ = math.floor((maxZ - minZ) / 3)
			local startX = position.X - countX * 3 / 2
			local startZ = position.Z - countZ * 3 / 2

			for i = 0, countX do
				local cellX = startX + 3 * i
				local column = {}

				for i2 = 0, countZ do
					local newNodeId = addNode(Vector3.new(cellX, gridY, startZ + 3 * i2))

					if i == 0 or not (i ~= countX and not (i2 == 0 or i2 == countZ)) then
						edgeSet[newNodeId] = 1
						table.insert(edgeNodes, newNodeId)
					end

					table.insert(column, newNodeId)
				end

				table.insert(gridColumns, column)
			end

			for k, gridColumn in pairs(gridColumns) do
				for k2, cellNode in pairs(gridColumn) do
					local nextColumnNode

					if not gridColumns[k + 1] then
						nextColumnNode = nil
					else
						nextColumnNode = gridColumns[k + 1][k2]
					end

					local nextRowNode = gridColumns[k][k2 + 1]
					local nextDiagNode

					if not gridColumns[k + 1] then
						nextDiagNode = nil
					else
						nextDiagNode = gridColumns[k + 1][k2 + 1]
					end

					local prevDiagNode

					if not gridColumns[k - 1] then
						prevDiagNode = nil
					else
						prevDiagNode = gridColumns[k - 1][k2 + 1]
					end

					if nextColumnNode then
						addLink(cellNode, nextColumnNode, true)
					end

					if nextRowNode then
						addLink(cellNode, nextRowNode, true)
					end

					if nextDiagNode then
						addLink(cellNode, nextDiagNode, true)
					end

					if prevDiagNode then
						addLink(cellNode, prevDiagNode, true)
					end
				end
			end

			for _, gridColumn in pairs(gridColumns) do
				for _, cellNode in pairs(gridColumn) do
					local hasLinks = false
					local v150, v151, v152 = pairs(nodeEdges[cellNode])
					local v153 = table.pack(v150(v151, v152))

					if v153[1] then
						hasLinks = true
					end

					if not hasLinks then
						removeNode(cellNode)
						local edgeIndex = table.find(edgeNodes, cellNode)

						if edgeIndex then
							edgeSet[cellNode] = nil
							table.remove(edgeNodes, edgeIndex)
						end
					end
				end
			end

			for _, edgeId in ipairs(edgeNodes) do
				local edgePosition = nodePositions[edgeId]

				for _, otherEdgeId in ipairs(edgeNodes) do
					if otherEdgeId ~= edgeId and not nodeEdges[edgeId][otherEdgeId] and (nodePositions[otherEdgeId] - edgePosition).magnitude < 6 then
						addLink(edgeId, otherEdgeId, true)
					end
				end
			end

			for k, nodePosition in pairs(nodePositions) do
				for k2, avoidRadius in pairs(v128) do
					if (type(k2) == "vector" and k2 or k2.Name ~= true and k2:FindFirstChild("Plane") and k2.Plane.Position or k2.Position - nodePosition).magnitude < avoidRadius then
						removeNode(k)
						break
					end
				end
			end

			if area then
				local outside={}
				for id,point in pairs(nodePositions)do if not fieldPositionPolicy:Allowed(point,{area=area}) then outside[#outside+1]=id end end
				for _,id in ipairs(outside)do removeNode(id) end
			end
			return nodePositions, nodeEdges
		end
		local function buildAvoidGrid(v128,area)
			local nodePositions = {}
			local nodeEdges = {}
			local nextNodeId = 1

			local function addNode(point)
				local nodeId = nextNodeId
				nextNodeId += 1
				local z = point.Z
				nodePositions[nodeId] = Vector3.new(math.floor(point.X), math.floor(point.Y), math.floor(z))
				nodeEdges[nodeId] = {}
				return nodeId
			end

			local function removeNode(nodeToRemove)
				nodePositions[nodeToRemove] = nil

				for k in pairs(nodeEdges[nodeToRemove]) do
					nodeEdges[nodeToRemove][k] = nil
					nodeEdges[k][nodeToRemove] = nil
				end

				nodeEdges[nodeToRemove] = nil
			end

			local gridLink={bidirectional=true,label=""}
			local function addLink(fromId, toId, bidirectional)
				nodeEdges[fromId][toId] = gridLink

				if bidirectional then
					nodeEdges[toId][fromId] = gridLink
				end
			end

			local edgeNodes = {}
			local edgeSet = {}
			local minX

			if vector.X > 3 then
				minX = position.X - vector.X / 2 + 1.5
			else
				minX = position.X - vector.X / 2
			end

			local maxX

			if vector.X > 3 then
				maxX = position.X + vector.X / 2 - 1.5
			else
				maxX = position.X + vector.X / 2
			end

			local minZ

			if vector.Z > 3 then
				minZ = position.Z - vector.Z / 2 + 1.5
			else
				minZ = position.Z - vector.Z / 2
			end

			local maxZ

			if vector.Z > 3 then
				maxZ = position.Z + vector.Z / 2 - 1.5
			else
				maxZ = position.Z + vector.Z / 2
			end

			local gridY = position.Y - vector.Y / 2 + 1
			local gridColumns = {}
			local countX = math.floor((maxX - minX) / 3)
			local countZ = math.floor((maxZ - minZ) / 3)
			local startX = position.X - countX * 3 / 2
			local startZ = position.Z - countZ * 3 / 2

			for i = 0, countX do
				local cellX = startX + 3 * i
				local column = {}

				for i2 = 0, countZ do
					local newNodeId = addNode(Vector3.new(cellX, gridY, startZ + 3 * i2))

					if i == 0 or not (i ~= countX and not (i2 == 0 or i2 == countZ)) then
						edgeSet[newNodeId] = 1
						table.insert(edgeNodes, newNodeId)
					end

					table.insert(column, newNodeId)
				end

				table.insert(gridColumns, column)
			end

			for k, gridColumn in pairs(gridColumns) do
				for k2, cellNode in pairs(gridColumn) do
					local nextColumnNode

					if not gridColumns[k + 1] then
						nextColumnNode = nil
					else
						nextColumnNode = gridColumns[k + 1][k2]
					end

					local nextRowNode = gridColumns[k][k2 + 1]
					local nextDiagNode

					if not gridColumns[k + 1] then
						nextDiagNode = nil
					else
						nextDiagNode = gridColumns[k + 1][k2 + 1]
					end

					local prevDiagNode

					if not gridColumns[k - 1] then
						prevDiagNode = nil
					else
						prevDiagNode = gridColumns[k - 1][k2 + 1]
					end

					if nextColumnNode then
						addLink(cellNode, nextColumnNode, true)
					end

					if nextRowNode then
						addLink(cellNode, nextRowNode, true)
					end

					if nextDiagNode then
						addLink(cellNode, nextDiagNode, true)
					end

					if prevDiagNode then
						addLink(cellNode, prevDiagNode, true)
					end
				end
			end

			for _, gridColumn in pairs(gridColumns) do
				for _, cellNode in pairs(gridColumn) do
					local hasLinks = false
					local v150, v151, v152 = pairs(nodeEdges[cellNode])
					local v153 = table.pack(v150(v151, v152))

					if v153[1] then
						hasLinks = true
					end

					if not hasLinks then
						removeNode(cellNode)
						local edgeIndex = table.find(edgeNodes, cellNode)

						if edgeIndex then
							edgeSet[cellNode] = nil
							table.remove(edgeNodes, edgeIndex)
						end
					end
				end
			end

			local obstacles={}
			for object,radius in pairs(v128 or {}) do
				local point=fieldPositionPolicy:TargetPosition(object)
				if typeof(point)=="Vector3" and type(radius)=="number" then obstacles[#obstacles+1]={point,radius>100 and 24 or radius} end
			end
			for id,nodePosition in pairs(nodePositions) do
				for _,obstacle in ipairs(obstacles) do
					if (obstacle[1]-nodePosition).Magnitude<obstacle[2] then removeNode(id);break end
				end
			end

			if area then
				local outside={}
				for id,point in pairs(nodePositions)do if not fieldPositionPolicy:Allowed(point,{area=area}) then outside[#outside+1]=id end end
				for _,id in ipairs(outside)do removeNode(id) end
			end
			return nodePositions, nodeEdges
		end

function fieldPositionPolicy:TargetPosition(value)
 if typeof(value)=="Vector3" then return value end
 return value.Position
end
setField(field.Name)
local originalNodes,originalLinks=buildAvoidGridOriginal({})
local nodes,links=buildAvoidGrid({})
local linkRecord
for id,p in pairs(nodes)do
 assert(originalNodes[id] and (originalNodes[id]-p).Magnitude<.00001)
 for to,link in pairs(links[id])do
  assert(originalLinks[id][to],"optimized grid must preserve original links")
  linkRecord=linkRecord or link;assert(linkRecord==link,"edge metadata must be shared")
 end
 for to in pairs(originalLinks[id])do assert(links[id][to])end
end
local obstacle=makeVector(field.Position.X,21,field.Position.Z)
local blockedNodes,blockedLinks=buildAvoidGrid({[obstacle]=12})
local removed=0
for id in pairs(originalNodes)do if not blockedNodes[id]then removed+=1 end end
assert(removed>0)
for id,p in pairs(blockedNodes)do
 assert((p-obstacle).Magnitude>=12,"grid exclusion must measure node-relative distance")
 for to in pairs(blockedLinks[id])do assert(blockedNodes[to],"no dangling edges after pruning")end
end
local first=rbcSafety:PathParams();assert(first==rbcSafety:PathParams())
rbcSafety:Reset();assert(not rbcSafety.pathParams)
print("PASS: identical grid connectivity, shared edge records, correct vector hazard pruning and cached path filters")

RunService.PreSimulation=signal()
function methods:MoveTo(p)self.goal=p end
function methods:ChangeState(v)self.lastState=v end
local scans=0
local descendants=methods.GetDescendants
function methods:GetDescendants()if self==character then scans+=1 end;return descendants(self)end
cfg.vars.tweenspeed=12;cfg.vars.movement="Walk"
root.CanCollide=true;head.CanCollide=false
state.bees=nil;state.stop=false
local frame=0
RunService.Heartbeat.Wait=function()
 now+=.02;frame+=1;RunService.PreSimulation:Fire()
 if frame%3==0 and state.travelAlignPosition then root.Position=state.travelAlignPosition.Position end
 return true
end
stopMovement = function()
	smoothMovement:Reset()
	local wasTween=state.tweennoclip~=nil or state.travelAlignPosition~=nil
	if state.tweennoclip then state.tweennoclip:Disconnect();state.tweennoclip=nil end
	if state.tweenPartsAdded then state.tweenPartsAdded:Disconnect();state.tweenPartsAdded=nil end
	for part,collidable in pairs(state.tweenParts or {}) do
		if part.Parent then part.CanCollide=collidable end
	end
	state.tweenParts=nil
	for _,key in ipairs({"travelAlignPosition","travelAlignOrientation","gyro"}) do
		local object=state[key]
		if object then object:Destroy();state[key]=nil end
	end
	local char=localPlayer.Character
	local humanoid=char and char:FindFirstChildOfClass("Humanoid")
	local root=char and char:FindFirstChild("HumanoidRootPart")
	if root and cfg.vars.movement=="Tween" then
		for _,child in ipairs(root:GetChildren()) do
			if child:IsA("AlignPosition") or child:IsA("AlignOrientation") then child:Destroy() end
		end
	end
	if humanoid and root and humanoid.Health>0 then
		humanoid:MoveTo(root.Position)
		if cfg.vars.movement~="Tween" then state.break1=true end
		if wasTween then humanoid:ChangeState(Enum.HumanoidStateType.Freefall) end
	end
end
	tweenTo = function(position2, gentle, skipCaveCheck)
		if showerController.active then error("return",0) end
		if getHumanoid().Health == 0 then
			error("return", 0)
		end

		local character = localPlayer.Character
		local rootPart = getRootPart()
		local humanoid = getHumanoid()

		if not state.bees or not (not not (state.bees >= 15) and distanceTo(locations.GummyBearShop) < 500) then
			if not skipCaveCheck and state.bees then
				local raycastParams = RaycastParams.new()
				raycastParams.FilterDescendantsInstances = { workspace.Cave }
				raycastParams.FilterType = Enum.RaycastFilterType.Include
				local toTarget = position2 - rootPart.Position

				if workspace:Raycast(rootPart.Position, toTarget.unit * toTarget.magnitude, raycastParams) then
					tweenTo(workspace.FlowerZones[state.bees >= 25 and "Mountain Top Field" or "Spider Field"].Position + Vector3.new(0, state.bees >= 25 and -20 or 60, 0), nil, true)
				end
			end
		else
			getHumanoid().Health = 0
			localPlayer.CharacterAdded:Wait()
			task.wait(1)
			error("return", 0)
		end

		if cfg.vars.tweenspeed > 12 and _G.unlocktween ~= true then
			cfg.vars.tweenspeed = 12
		elseif cfg.vars.tweenspeed < 1 then
			cfg.vars.tweenspeed = 1
		end

		stopMovement()
		local maxVelocity = cfg.vars.tweenspeed * 10
		local travelTime = distanceTo(position2) / maxVelocity
		local AlignPosition = Instance.new("AlignPosition")
		AlignPosition.Mode = Enum.PositionAlignmentMode.OneAttachment
		AlignPosition.Attachment0 = rootPart.RootAttachment
		AlignPosition.Responsiveness = gentle and 10 or 20
		AlignPosition.MaxForce = math.huge
		AlignPosition.MaxVelocity = maxVelocity
		AlignPosition.Position = position2
		AlignPosition.Parent = rootPart
		state.travelAlignPosition=AlignPosition
		local AlignOrientation = Instance.new("AlignOrientation")
		AlignOrientation.Attachment0 = rootPart.RootAttachment
		AlignOrientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
		AlignOrientation.RigidityEnabled = true
		AlignOrientation.CFrame = rootPart.CFrame
		AlignOrientation.Parent = rootPart
		state.travelAlignOrientation=AlignOrientation
		humanoid:ChangeState(Enum.HumanoidStateType.Physics)

		local parts={}
		state.tweenParts=parts
		local function rememberPart(part)
			if part:IsA("BasePart") then
				if parts[part]==nil then parts[part]=part.CanCollide end
				part.CanCollide=false
			end
		end
		for _,part in ipairs(character:GetDescendants()) do rememberPart(part) end
		state.tweenPartsAdded=character.DescendantAdded:Connect(rememberPart)
		local ownerThread=coroutine.running()
		state.tweennoclip=RunService.PreSimulation:Connect(function()
			if localPlayer.Character~=character or humanoid.Health<=0 or not rootPart.Parent or coroutine.status(ownerThread)=="dead" then stopMovement();return end
			for part in pairs(parts) do
				if part.Parent and part.CanCollide then part.CanCollide=false end
			end
		end)

		local tweennoclip = state.tweennoclip
		local now = os.clock()

		while not (tweennoclip ~= state.tweennoclip or not (os.clock() - now < travelTime + 2) or not (os.clock() - now < 30) or not (not not (getHumanoid().Health > 0) and not not (distanceTo(position2) > 4))) do
			RunService.Heartbeat:Wait()
		end

		if tweennoclip == state.tweennoclip then
			stopMovement()
		end
	end

local base=liveConnections
for i=1,100 do
 tweenTo(root.Position+makeVector(30,0,0))
 assert(not state.tweennoclip and not state.tweenPartsAdded and not state.tweenParts)
 assert(not state.travelAlignPosition and not state.travelAlignOrientation)
 assert(root.CanCollide==true and head.CanCollide==false,"restore exact collision properties")
 assert(liveConnections==base,"tween listeners must not accumulate")
end
assert(scans==100,"scan character once per tween rather than every simulation step")
RunService.Heartbeat.Wait=function()coroutine.yield();return true end
local thread=coroutine.create(function()tweenTo(root.Position+makeVector(30,0,0))end)
assert(coroutine.resume(thread));assert(state.tweennoclip and state.tweenPartsAdded)
coroutine.close(thread);RunService.PreSimulation:Fire()
assert(not state.tweennoclip and not state.tweenParts and liveConnections==base)
assert(root.CanCollide==true and head.CanCollide==false)
local deadThread=coroutine.create(function()tweenTo(root.Position+makeVector(30,0,0))end)
assert(coroutine.resume(deadThread));h.Health=0;RunService.PreSimulation:Fire()
assert(not state.tweennoclip and not state.tweenPartsAdded and liveConnections==base)
assert(root.CanCollide==true and head.CanCollide==false)
coroutine.close(deadThread);h.Health=100
print("PASS: 100 tweens scan once, restore collisions and free movers/listeners; cancellation and death clean up in Walk mode too")
local function waitForLanding()
	local deadline=os.clock()+4
	while os.clock()<deadline do
		local character=localPlayer.Character
		local humanoid=character and character:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health<=0 then return false end
		local movement=humanoid:GetState()
		if not humanoid.Jump and not character:FindFirstChild("Glider") and movement~=Enum.HumanoidStateType.Freefall
			and movement~=Enum.HumanoidStateType.Jumping and humanoid.FloorMaterial~=Enum.Material.Air then return true end
		RunService.Heartbeat:Wait()
	end
	return false
end

local landFrames=0
h.FloorMaterial="Ground";h.Jump=false
function methods:GetState()return self.movementState or "Landed" end
RunService.Heartbeat.Wait=function()landFrames+=1;now+=.02;h.FloorMaterial="Ground";h.movementState="Landed";return true end
assert(waitForLanding() and landFrames==0,"grounded Landed state must not wait")
h.FloorMaterial="Air";h.movementState="Freefall"
assert(waitForLanding() and landFrames==1,"wait only until actual landing")
h.Health=0;assert(not waitForLanding() and landFrames==1);h.Health=100
print("PASS: grounded travel starts immediately, airborne travel waits for landing, death exits without waiting")
