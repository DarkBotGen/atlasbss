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

local fieldPositionPolicy={StrictAllowed=function()return true end,RemoveGuards=function()end,ReleaseIdle=function()end,SmileyOnly=function()return false end}
local meteorMovement={Release=function()end}
local localPlayer=player
player.ClassName="Player"
function player:IsA(class)return class=="Player"end
game.JobId="mock-server"
local function typeof(v)
 if type(v)=="table" and v.ClassName then return "Instance" end
 if type(v)=="table" and v.X and v.Y and v.Z then return "Vector3" end
 return type(v)
end
local home={Name="Pepper Patch"}
local outside={Name="Mountain Top Field"}
local currentField=home
local function getFieldAt(p) return p.X>10 and outside or home end
local function getHumanoid()return h end
cfg.autofarm.field1="Pepper Patch"
cfg.coconutteam={enabled=false,fast=true,main="OtherMain",alt1="Tester",alt2="AltTwo",catcher1="OutsideOne",catcher2="None",catcher3="None",field="Pepper Patch",outsidefield="Mountain Top Field",maxspeed=120,url="https://example.test",key=string.rep("x",32)}
state.activityStatus=1
local PhysicalProperties={new=function(d,f,e,fw,ew)return {Density=d,Friction=f,Elasticity=e,FrictionWeight=fw,ElasticityWeight=ew}end}
root.CurrentPhysicalProperties=PhysicalProperties.new(.7,.5,.2,1,1)
root.Massless=false
local gameApi={Events=Instance.new("Folder")}
local fx=Instance.new("RemoteEvent",gameApi.Events);fx.Name="LocalFX";fx.OnClientEvent=signal()
local HttpService={GenerateGUID=function()return "session-id"end,JSONEncode=function(_,v)return v end,JSONDecode=function(_,v)return v end}
local reply={ok=true,protocol=2,jobs={},message="Connected"}
local sent,networkFail,changeSettings,requestDuration=nil,false,false,0.1
local function http_request(options)
 sent=options.Body
 now+=requestDuration
 if changeSettings then smoothMovement.comboController.generation+=1 end
 if networkFail then error("connection lost") end
 return {StatusCode=200,Body=reply}
end
threads.Add = function(manager, threadId, callback, delaySeconds, ...)
	if manager.closed then return end
	local exclusive = (smoothMovement.comboController and smoothMovement.comboController.active and smoothMovement.comboController) or smoothMovement.showerController
	if exclusive and exclusive.active and exclusive:IsMovementJob(threadId) then
		local pending = exclusive.paused or smoothMovement.showerController.paused
		pending[threadId] = {callback=callback,args=table.pack(...),delaySeconds=delaySeconds}
		return
	end
	manager:Cancel(threadId)
	local args = table.pack(...)
	local controller = smoothMovement.showerController
	if controller and controller:IsMovementJob(threadId) then
		local job = {callback=callback,args=args,delaySeconds=delaySeconds}
		if controller.active then controller.paused[threadId]=job;return end
		manager.jobs = manager.jobs or {}
		manager.jobs[threadId] = job
	end
	local thread
	thread = coroutine.create(function()
		local ok, err = xpcall(function() callback(table.unpack(args, 1, args.n)) end, debug.traceback)
		if manager.list[threadId] == thread then
			manager.list[threadId] = nil
			if manager.jobs then manager.jobs[threadId] = nil end
		end
		if not ok then warn(err) end
	end)
	manager.list[threadId] = thread
	if delaySeconds then task.delay(math.max(0, delaySeconds), thread) else task.spawn(thread) end
	return thread
end

threads.Delay = function(manager, threadId, seconds, callback)
	return manager:Add(threadId, callback, seconds)
end

threads.Get = function(manager, threadId)
	return manager.list[threadId]
end

threads.Cancel = function(manager, threadId)
	if manager.jobs then manager.jobs[threadId]=nil end
	local controller = smoothMovement.showerController
	if controller and not controller.suspending then controller.paused[threadId]=nil end
	if (threadId == "Autofarm" or threadId == "fasttween") and smoothMovement and smoothMovement.showerController then
		smoothMovement.showerController:CancelMovement()
	end
	local thread = manager.list[threadId]

	if thread then
		pcall(function()
			task.cancel(thread)
		end)

		manager.list[threadId] = nil
	end
end

threads.CancelAll = function(manager)
	manager.closed = true
	if manager.jobs then table.clear(manager.jobs) end
	for k, thread in pairs(manager.list) do
		pcall(function()
			task.cancel(thread)
		end)

		manager.list[k] = nil
	end
end

connections.Add = function(manager, connectionId, connection)
	if manager.closed then connection:Disconnect(); return end
	if manager.list[connectionId] == connection then return end
	manager:Cancel(connectionId)
	manager.list[connectionId] = connection
end

connections.Get = function(manager, connectionId)
	return manager.list[connectionId]
end

connections.Cancel = function(manager, connectionId)
	local connection = manager.list[connectionId]

	if connection then
		pcall(function()
			connection:Disconnect()
		end)

		manager.list[connectionId] = nil
	end
end

connections.CancelAll = function(manager)
	manager.closed = true
	for k, connection in pairs(manager.list) do
		pcall(function()
			connection:Disconnect()
		end)

		manager.list[k] = nil
	end
end

-- Atlas integration for the supplied Safeshower engine.
local showerController = {
	active=false, paused={},
	movementJobs={Autofarm=true,fasttween=true,face=true,walkspeed=true,autodig=true,
		Lawnmower=true,stickbugfield=true,windyfield=true,
		["Auto Moon Amulet"]=true,["Auto Star Amulet"]=true,["Auto Royal Jelly"]=true,
		["Auto Gifted Basic"]=true,["Auto Mutations"]=true},
}

function showerController:IsMovementJob(id) return self.movementJobs[id] == true end

function showerController:CancelMovement()
	if self.suspending then return end
	if self.active and not self.shuttingDown and state and not state.stop and cfg and cfg.autofarm.farmshowers
		and (not self.allowed or self.allowed()) then return end
	if self.cancel then self.cancel("Atlas movement stopped") end
end

function showerController:PauseOthers()
	if self.shuttingDown then return end
	self.suspending = true
	for id, job in pairs(threads.jobs or {}) do
		if self:IsMovementJob(id) then
			self.paused[id] = job
			threads:Cancel(id)
		end
	end
	if state.movementTween then
		local tween = state.movementTween
		state.movementTween = nil
		pcall(function() tween:Cancel(); tween:Destroy() end)
	end
	pcall(stopMovement)
	-- Clear travel constraints independently of the selected movement setting.
	local root = getRootPart()
	for _, child in ipairs(root:GetChildren()) do
		if child:IsA("AlignPosition") or child:IsA("AlignOrientation") then child:Destroy() end
	end
	if state.tweennoclip then state.tweennoclip:Disconnect(); state.tweennoclip=nil end
	state.fasttween = nil
	self.previousStopface = state.stopface
	state.stopface = true
	self.suspending = false
end

function showerController:ResumeOthers()
	self.suspending = false
	if state then state.stopface = self.previousStopface end
	local paused = self.paused
	self.paused = {}
	if self.shuttingDown or threads.closed or not state or state.stop then return end
	for id, job in pairs(paused) do
		if id == "Autofarm" and not cfg.autofarm.enabled then continue end
		if id == "fasttween" and not cfg.detected.background then continue end
		if not threads:Get(id) then
			threads:Add(id, job.callback, job.delaySeconds, table.unpack(job.args,1,job.args.n))
		end
	end
end

function showerController:Reset()
	if self.cancel then self.cancel("Farm Showers disabled") end
end

function showerController:Shutdown()
	self.shuttingDown = true
	if self.close then self.close() elseif self.cancel then self.cancel("Atlas unloaded") end
	table.clear(self.paused)
end

function showerController:CreateMovementTween(root, info, properties)
	if self.active then error("return",0) end
	if state.movementTween then
		local previous = state.movementTween
		state.movementTween = nil
		pcall(function()previous:Cancel();previous:Destroy()end)
	end
	local tween = TweenService:Create(root,info,properties)
	state.movementTween = tween
	connections:Add("movementTweenCleanup",tween.Completed:Connect(function()
		if state and state.movementTween == tween then state.movementTween=nil end
		connections:Cancel("movementTweenCleanup")
	end))
	return tween
end

smoothMovement.showerController = showerController

-- Atlas+ combo movement and team client. One bounded observation set and one HTTP worker.
local comboController = {records={}, byKey={}, jobs={}, chains={}, chainCount=0, serial=0, seq=0, generation=0, active=false, status="Disabled"}
smoothMovement.comboController = comboController

function comboController:FieldAt(position)
	local field=getFieldAt(position)
	if field then return field end
	if self.fieldFallback then return self.fieldFallback(position) end
end

function comboController:Managed()
	return cfg.coconutteam.enabled or cfg.coconutteam.fast
end

function comboController:Role()
	local c, name = cfg.coconutteam, string.lower(localPlayer.Name)
	if name == string.lower(c.main) then return "main" end
	if name == string.lower(c.alt1) or name == string.lower(c.alt2) then return "alt" end
	for _, key in ipairs({"catcher1","catcher2","catcher3"}) do
		if name == string.lower(c[key]) then return "catcher" end
	end
end

function comboController:Owner(value)
	if typeof(value) == "Instance" and value:IsA("Player") then return value.Name end
	if type(value) == "string" and not tonumber(value) then return value end
	local id = tonumber(value)
	if id then
		for _, player in ipairs(getService("Players"):GetPlayers()) do
			if player.UserId == id then return player.Name end
		end
	end
end

-- Bounded scalar-only trace for verifying the live FX schema and turn decisions.
function comboController:Trace(kind,fields)
	self.trace=self.trace or {}
	if #self.trace>=40 then table.remove(self.trace,1) end
	local entry={time=math.floor(os.clock()*1000)/1000,kind=kind,fields=fields}
	self.trace[#self.trace+1]=entry
end

function comboController:TraceFX(name,data)
	local fields={effect=name}
	local count=0
	for key,value in pairs(data)do
		if type(key)=="string" and count<40 then
			local kind=typeof(value)
			if kind=="Instance" then fields[key]="Instance:"..value.ClassName..":"..value.Name
			elseif kind=="Vector3" then fields[key]=string.format("%.1f,%.1f,%.1f",value.X,value.Y,value.Z)
			elseif type(value)=="string" then fields[key]=string.sub(value,1,160)
			elseif type(value)=="number" then fields[key]=value==value and math.abs(value)<1e100 and value or "non-finite"
			elseif type(value)=="boolean" then fields[key]=value
			else fields[key]=kind end
			count+=1
		end
	end
	self:Trace("fx",fields)
end

function comboController:Diagnostics()
	local c=cfg.coconutteam
	return {version="combo-trace-v2",account=localPlayer.Name,role=self:Role() or "unassigned",status=self.status,
		tracking=self.effectStatus,enabled=c.enabled,fast=c.fast,main=c.main,alt1=c.alt1,alt2=c.alt2,
		catcher1=c.catcher1,catcher2=c.catcher2,catcher3=c.catcher3,teamField=self:TeamField(),outsideField=c.outsidefield,
		mainHelp=c.mainassist or 3,events=self.trace or {}}
end

function comboController:Observe(effectName, data)
	local kicked=effectName=="KickedComboCoconut"
	if not self:Managed() or (effectName~="FallingCoconut" and not kicked) then return end
	if type(data)~="table" then return end
	if kicked or data.Combo then self:TraceFX(effectName,data) end
	if (not kicked and not data.Combo) or data.Friendly==false then return end
	local goal=kicked and (data.GoalPos or data.EndPos or data.Pos2 or data.Pos) or data.Pos
	local dur=tonumber(data.FallDuration or data.Dur or data.Duration)
	self.lastEffect=effectName
	if typeof(goal)~="Vector3" or not dur or dur~=dur or dur<=0 or dur>12 then
		self.effectStatus=kicked and "Kick notification; waiting for next landing FX" or "Landing FX missing position or duration";return
	end
	local now=os.clock()
	local id=data.ComboID or data.ChainID or data.FEID or data.ID
	local chainKey=(type(id)=="number" or type(id)=="string") and tostring(id) or nil
	local chain=chainKey and self.chains[chainKey]
	if chain and chain.expires<=now then chain=nil end
	local stack=type(data.Combo)=="number" and data.Combo or nil
	if stack and (stack~=stack or stack<0 or stack==math.huge) then stack=nil end
	local explicit=self:Owner(data.ComboOwner) or self:Owner(data.Owner)
	local private=not kicked and stack==0
	local owner=explicit or (not private and chain and chain.owner) or self:Owner(data.Player) or self:Owner(data.PID) or self:Owner(data.Target)
	if private and not owner then owner=localPlayer.Name end
	-- Deduplicate only the same immediate FX delivery, not every drop reusing a chain ID.
	local runKey=owner and ("owner:"..string.lower(owner))
	local run=runKey and self.chains[runKey]
	local previous=(chain and chain.record) or (run and run.expires>now and run.record)
	if previous and previous.stack==stack and now-previous.seen<0.075 and (previous.position-goal).Magnitude<0.1 then return end
	if #self.records>=32 then return end
	local field=self:FieldAt(goal)
	self.serial+=1
	local key=string.format("%s:%.1f:%.1f:%.1f:%s:%d",string.lower(owner or "unknown"),goal.X,goal.Y,goal.Z,tostring(id or data.Points or 0),self.serial)
	local fieldName=field and field.Name or ""
	local fieldDrops=run and run.expires>now and run.record.field==fieldName and (run.record.fieldDrops or 1)+1 or 1
	local sharedDrops=private and 0 or (run and run.expires>now and run.record.field==fieldName and (run.record.sharedDrops or 0)+1 or 1)
	local record={key=key,owner=owner,position=goal,deadline=now+dur,fieldDrops=fieldDrops,sharedDrops=sharedDrops,private=private,stack=stack,stackKnown=stack~=nil,points=tonumber(data.Points) or 0,
		field=field and field.Name or "",seen=now,chain=chainKey,effect=effectName}
	if previous then
		-- The bounce is a new destination; do not continue holding the previous drop.
		previous.deadline=math.min(previous.deadline,now-0.26)
	end
	if chainKey and owner then
		if self.chains[chainKey] or self.chainCount<64 then
			if not self.chains[chainKey] then self.chainCount+=1 end
			self.chains[chainKey]={owner=owner,record=record,expires=now+30}
		end
	end
	if runKey and (self.chains[runKey] or self.chainCount<64) then
		if not self.chains[runKey] then self.chainCount+=1 end
		self.chains[runKey]={owner=owner,record=record,expires=now+30}
	end
	self.byKey[key]=record
	self.records[#self.records+1]=record
	self:Trace("parsed",{key=key,owner=owner or "unknown",private=private,stack=stack,points=record.points,stackKnown=record.stackKnown,sharedDrops=sharedDrops,field=record.field,help=self:MainHelp(record)})
	self.lastOwner=owner or "Unknown"
	self.effectStatus=string.format("%s: %s | stack %s | field %s",effectName,owner or "unknown",stack~=nil and tostring(stack) or "unknown",record.field)
end

-- Use the original Atlas WarningDisk/GuiAttach detector as the landing source.
function comboController:TrackDisk(disk)
	if not self:Managed() then return end
	self.disks=self.disks or {}
	if not self.disks[disk] then self.disks[disk]={seen=os.clock()} end
end

function comboController:DiskLanding()
	local now,best=os.clock(),nil
	local role=self:Role()
	for target in pairs(self.atlasTargets and self:atlasTargets() or {}) do self:TrackDisk(target) end
	for disk,entry in pairs(self.disks or {}) do
		local virtual=disk.Name==true
		if (virtual and now>=(disk.ExpiresAt or entry.seen+12)) or (not virtual and not disk.Parent) or now-entry.seen>12 then
			if entry.record and not virtual then entry.record.deadline=math.min(entry.record.deadline,now-0.26) end
			self.disks[disk]=nil
		elseif virtual or disk:FindFirstChild("GuiAttach") then
			local position=disk.Position
			local match
			for _,r in ipairs(self.records) do
				if r.deadline+0.12>now and math.abs(r.seen-entry.seen)<2
					and (r.position-position).Magnitude<14
					and (not match or (r.position-position).Magnitude<(match.position-position).Magnitude) then match=r end
			end
			if match then match.position=position end
			if match and match.owner then
				entry.record=match
				match.position=position
			elseif not entry.record then
				local field=self:FieldAt(position)
				local fieldName=field and field.Name or ""
				-- An unlabelled first landing is caught locally; never invent its owner
				-- or submit it to the coordinator as another account's combo.
				local eligible=cfg.coconutteam.enabled and ((role=="main" or role=="alt") and fieldName==self:TeamField()
					or role=="catcher" and cfg.coconutteam.fast and fieldName==cfg.coconutteam.outsidefield)
				if not cfg.coconutteam.enabled and cfg.coconutteam.fast then
					eligible=fieldName~=self:TeamField()
				end
				if eligible then
					entry.fallback=entry.fallback or {key="disk:"..tostring(disk),deadline=entry.seen+12,field=fieldName,seen=entry.seen}
					entry.fallback.position=position
					if not best or entry.seen<best.seen then best=entry.fallback end
					self.effectStatus="Atlas landing disk (owner pending)"
				end
			end
		end
	end
	return best
end

function comboController:MainOwned(owner)
	return type(owner)=="string" and cfg.coconutteam.main~="None" and cfg.coconutteam.main~=""
		and string.lower(owner)==string.lower(cfg.coconutteam.main)
end

function comboController:PrivateLanding()
	if not cfg.coconutteam.enabled then return end
	local best,now=nil,os.clock()
	for _,r in ipairs(self.records)do
		if r.private and r.owner and string.lower(r.owner)==string.lower(localPlayer.Name)
			and r.deadline+0.12>now and (not best or r.deadline<best.deadline) then best=r end
	end
	return best
end

function comboController:MainReady(record)
	local main
	for _,candidate in ipairs(getService("Players"):GetPlayers())do
		if string.lower(candidate.Name)==string.lower(cfg.coconutteam.main) then main=candidate;break end
	end
	local character=main and main.Character
	local root=character and character:FindFirstChild("HumanoidRootPart")
	local humanoid=character and character:FindFirstChildOfClass("Humanoid")
	local field=root and self:FieldAt(root.Position)
	if not root or not humanoid or humanoid.Health<=0 or not field or field.Name~=record.field
		or math.abs(root.Position.Y-record.position.Y)>12 then record.mainReserved=nil;return false end
	if main==localPlayer and self:TravelBlocked() then record.mainReserved=nil;return false end
	local delta=Vector3.new(root.Position.X-record.position.X,0,root.Position.Z-record.position.Z)
	local cap=math.max(180,cfg.coconutteam.maxspeed)
	local remaining=record.deadline-os.clock()
	if record.mainReserved then
		if delta.Magnitude<=9 or math.max(0,delta.Magnitude-9)/cap<remaining+0.05 then return true end
		record.mainReserved=nil
	end
	local ready=delta.Magnitude<=9 or math.max(0,delta.Magnitude-5)/cap+0.2<remaining
	if ready then record.mainReserved=true end
	return ready
end

function comboController:MainHelp(record)
	local interval=math.floor(math.clamp(tonumber(cfg.coconutteam.mainassist) or 3,2,10))
	return record.private or ((record.sharedDrops or 0)>0 and record.sharedDrops%interval==0 and self:MainReady(record))
end

function comboController:OwnLanding()
	if not cfg.coconutteam.enabled or self:Role()~="main" then return end
	local now, best=os.clock(),nil
	for _,r in ipairs(self.records)do
		if self:MainOwned(r.owner) and self:MainHelp(r)
			and r.deadline+0.12>now and (not best or r.deadline<best.deadline) then best=r end
	end
	return best
end

function comboController:MobileTeam()
	local role=self:Role()
	return cfg.coconutteam.enabled and cfg.coconutteam.followmain==true and (role=="main" or role=="alt")
end
function comboController:FollowingMain()
	return self:MobileTeam() and self:Role()=="alt"
end
function comboController:MainField()
	local now=os.clock()
	if self.mainFieldSample and now-self.mainFieldSample<.25 then return self.mainField end
	self.mainFieldSample=now
	local main
	for _,p in ipairs(getService("Players"):GetPlayers()) do
		if string.lower(p.Name)==string.lower(cfg.coconutteam.main) then main=p;break end
	end
	local char=main and main.Character
	local root=char and char:FindFirstChild("HumanoidRootPart")
	local h=char and char:FindFirstChildOfClass("Humanoid")
	if not root or not h or h.Health<=0 then
		self.mainField,self.mainFieldCandidate=nil,nil
		return
	end
	local field=self:FieldAt(root.Position)
	if field and field.Position and field.Size and math.abs(root.Position.Y-(field.Position.Y+field.Size.Y/2))<=12 then
		self.mainFieldSeen=now
		if self.mainFieldCandidate~=field then
			self.mainFieldCandidate,self.mainFieldSince=field,now
		elseif now-self.mainFieldSince>=.75 then self.mainField=field end
	else
		self.mainFieldCandidate=nil
		-- Brief hub visits do not send the followers back to their old farm field.
		if now-(self.mainFieldSeen or 0)>4 then self.mainField=nil end
	end
	return self.mainField
end
function comboController:TeamField()
	if cfg.coconutteam.enabled and cfg.coconutteam.followmain==true then
		local field=self:MainField()
		if field then return field.Name end
	end
	return cfg.coconutteam.field~="" and cfg.coconutteam.field or cfg.autofarm.field1
end

function comboController:OutsideMainLanding()
	if not cfg.coconutteam.enabled then return end
	local role=self:Role()
	if role~="alt" and role~="catcher" then return end
	if role=="catcher" and not cfg.coconutteam.fast then return end
	local field=role=="alt" and self:TeamField() or cfg.coconutteam.outsidefield
	local now,best=os.clock(),nil
	for _,r in ipairs(self.records)do
		if not r.private and self:MainOwned(r.owner) and not self:MainHelp(r) and r.field==field and r.deadline+0.12>now
			and (not best or r.deadline<best.deadline) then best=r end
	end
	return best
end

-- Reserve odd alt-combo drops only when the main can reach this field in time.
function comboController:IsAltOwner(owner)
	return type(owner)=="string" and (string.lower(owner)==string.lower(cfg.coconutteam.alt1)
		or string.lower(owner)==string.lower(cfg.coconutteam.alt2))
end

function comboController:AltDropAllowed(record)
	if not self:IsAltOwner(record.owner) or not record.stackKnown then return true end
	if record.private or record.stack%2==0 or not self:MainReady(record) then
		return string.lower(record.owner)==string.lower(localPlayer.Name)
			or (not record.private and self:Role()=="catcher" and cfg.coconutteam.fast and record.field==cfg.coconutteam.outsidefield)
	end
	return self:Role()=="main"
end

function comboController:LocalAltTurn()
	if not cfg.coconutteam.enabled or (self:Role()~="main" and self:Role()~="alt") then return end
	local best,now=nil,os.clock()
	for _,r in ipairs(self.records)do
		if self:IsAltOwner(r.owner) and r.stackKnown and r.deadline+0.12>now and self:AltDropAllowed(r)
			and self:Role()~="catcher" and (not best or r.deadline<best.deadline) then best=r end
	end
	return best
end

function comboController:YieldLanding(root)
	if not cfg.coconutteam.enabled or not self:Role() or self:Role()=="main" then return end
	local best,now=nil,os.clock()
	local held=self.session and self.session.yieldJob
	if held and held.source.deadline>now and self:MainReady(held.source) then return held end
	for _,r in ipairs(self.records)do
		if not r.private and r.deadline>now and ((self:IsAltOwner(r.owner) and r.stackKnown and r.stack%2==1 and self:MainReady(r))
			or (self:MainOwned(r.owner) and self:MainHelp(r))) then
			local delta=Vector3.new(root.Position.X-r.position.X,0,root.Position.Z-r.position.Z)
			if delta.Magnitude<14 and math.abs(root.Position.Y-r.position.Y)<12 and (not best or r.deadline<best.deadline) then
				local direction=delta.Magnitude>.1 and delta.Unit or Vector3.new(1,0,0)
				best={key="yield:"..r.key,owner=r.owner,position=Vector3.new(r.position.X,root.Position.Y,r.position.Z)+direction*18,
					deadline=r.deadline,field="",yielding=true,source=r}
			end
		end
	end
	return best
end

function comboController:OutsideAltLanding()
	if not cfg.coconutteam.enabled then return end
	local role,now,best=self:Role(),os.clock(),nil
	for _,r in ipairs(self.records)do
		local owner=type(r.owner)=="string" and string.lower(r.owner)
		local alt=owner and (owner==string.lower(cfg.coconutteam.alt1) or owner==string.lower(cfg.coconutteam.alt2))
		if alt and not r.private and self:AltDropAllowed(r) and r.deadline+0.12>now then
			local catch=role=="catcher" and cfg.coconutteam.fast and r.field==cfg.coconutteam.outsidefield
			if catch and (not best or r.deadline<best.deadline) then best=r end
		end
	end
	return best
end

function comboController:WantsTeamCombo()
	if not cfg.coconutteam.enabled then return false end
	local role=self:Role()
	if not role or (role=="catcher" and not cfg.coconutteam.fast) then return false end
	local now=os.clock()
	for _,r in ipairs(self.records)do
		if not self:MainOwned(r.owner) and r.owner and r.deadline+0.12>now then
			local owner=string.lower(r.owner)
			if (owner==string.lower(cfg.coconutteam.alt1) or owner==string.lower(cfg.coconutteam.alt2))
				and (role~="alt" or owner==string.lower(localPlayer.Name)) then return true end
		end
	end
	return false
end

function comboController:AcceptTeamJob(job)
	if self:MainOwned(job.owner) then return false end -- handled locally by main/outside catchers
	for _,r in ipairs(self.records)do
		if r.owner and type(job.owner)=="string" and string.lower(r.owner)==string.lower(job.owner)
			and r.deadline+0.12>os.clock() and (r.position-job.position).Magnitude<2
			and not self:AltDropAllowed(r) then return false end
	end
	local role=self:Role()
	if role=="alt" then return type(job.owner)=="string" and string.lower(job.owner)==string.lower(localPlayer.Name) end
	if role=="catcher" then
		local field=self:FieldAt(job.position)
		return cfg.coconutteam.fast and (field and field.Name or "")==cfg.coconutteam.outsidefield
	end
	return role=="main"
end

function comboController:TravelBlocked()
	local lock=self.taskTravel
	if lock and (coroutine.status(lock.thread)=="dead" or localPlayer.Character~=lock.character) then self.taskTravel=nil;lock=nil end
	return lock~=nil or state.tweennoclip~=nil or state.fasttween==true or state.movementTween~=nil
end

function comboController:WithTaskTravel(callback,...)
	fieldPositionPolicy:RemoveGuards()
	fieldPositionPolicy:ReleaseIdle()
	meteorMovement:Release()
	local running=coroutine.running()
	if self.taskTravel and self.taskTravel.thread==running then return callback(...) end
	while self:TravelBlocked() do
		if state.stop then error("return",0) end
		RunService.Heartbeat:Wait()
	end
	local lock={thread=running,character=localPlayer.Character}
	self.taskTravel=lock
	self.comboPriority,self.ownPriority,self.privatePriority=false,false,false
	self:Finish("Task travel has movement priority")
	local result=table.pack(pcall(callback,...))
	if not result[1] then pcall(stopMovement) end
	-- Keep the lock while the normal tween's final short fall settles.
	if not state.stop and self.awaitLanding and localPlayer.Character==lock.character then pcall(self.awaitLanding) end
	if self.taskTravel==lock then self.taskTravel=nil end
	if not result[1] then error(result[2],0) end
	return table.unpack(result,2,result.n)
end

function comboController:Available()
	if self:TravelBlocked() then return false end
	local focused=self.comboPriority or self.ownPriority or self:WantsTeamCombo()
	if self.closed or state.stop or (showerController.active and not focused) then return false end
	local char = localPlayer.Character
	local h = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not h or not root or h.Health <= 0 then return false end
	if not focused and cfg.autofarm.enabled and (state.activityStatus ~= 1 or state.fasttween) then return false end
	if cfg.coconutteam.enabled then
		local role = self:Role()
		if not role or (role == "catcher" and not cfg.coconutteam.fast) then return false end
		if not focused and role ~= "catcher" and not cfg.autofarm.enabled then return false end
	end
	return true, h, root
end

function comboController:IsMovementJob(id)
	return showerController:IsMovementJob(id)
end

function comboController:ApplyDensity(session)
	meteorMovement:Release()
	pcall(function()
		local root=session.root
		local physical=root.CurrentPhysicalProperties
		if not physical then return end
		session.originalPhysical=root.CustomPhysicalProperties
		session.originalMassless=root.Massless
		session.densityChanged=true
		root.Massless=false
		root.CustomPhysicalProperties=PhysicalProperties.new(math.clamp(physical.Density*10,0.01,100),physical.Friction,physical.Elasticity,physical.FrictionWeight,physical.ElasticityWeight)
	end)
end

function comboController:Finish(reason)
	local session = self.session
	if not session then self.status=reason or "Waiting for combo";return end
	self.session, self.active = nil, false
	threads:Cancel("comboFieldTravel")
	threads:Cancel("comboAtlasCatch")
	if session.travelling then pcall(stopMovement) end
	if session.densityChanged then
		pcall(function()session.root.CustomPhysicalProperties=session.originalPhysical end)
		pcall(function()session.root.Massless=session.originalMassless end)
	end
	RunService:UnbindFromRenderStep("AtlasComboMovement")
	local env = type(getgenv)=="function" and getgenv() or _G
	if env[session.leaseKey] == session.lease then env[session.leaseKey] = session.previousLease end
	pcall(function()
		session.h:Move(Vector3.zero,false)
		session.h.WalkSpeed=session.originalSpeed
		session.root.AssemblyLinearVelocity=Vector3.zero
	end)
	if session.controls and session.restoreControls then pcall(function()session.controls:Enable()end) end
	self.status=reason or "Waiting for combo"
	showerController:ResumeOthers()
end

function comboController:Begin(job, h, root)
	fieldPositionPolicy:ReleaseIdle()
	if not self:MobileTeam() and not fieldPositionPolicy:SmileyOnly() and not fieldPositionPolicy:StrictAllowed(job.position) then self:Finish("Outside strict quadrant");return end
	meteorMovement:Release()
	if self.session and self.session.key == job.key then return self.session end
	self:Finish("Changing combo landing")
	if showerController.active or self.closed or self:TravelBlocked() then return end
	local env = type(getgenv)=="function" and getgenv() or _G
	local key = "AtlasTemporaryPMS_" .. localPlayer.UserId
	local s = {key=job.key,h=h,root=root,originalSpeed=h.WalkSpeed,leaseKey=key,lease={},previousLease=env[key],direction=Vector3.zero,speed=0}
	pcall(function()
		local module=localPlayer.PlayerScripts:FindFirstChild("PlayerModule")
		if module then s.controls=require(module):GetControls();s.restoreControls=s.controls.controlsEnabled~=false;s.controls:Disable() end
	end)
	self.session,self.active=s,true
	showerController:PauseOthers()
	self:ApplyDensity(s)
	RunService:BindToRenderStep("AtlasComboMovement",Enum.RenderPriority.Character.Value+1,function()
		self:Drive(s)
	end)
	return s
end

-- Heartbeat also drives movement, since rendering can be disabled or throttled.
function comboController:Drive(s)
	if self.session~=s then return end
	if not self:Available() or not s.root.Parent then self:Finish("Combo movement interrupted");return end
	local env=type(getgenv)=="function" and getgenv() or _G
	s.lease.speed,s.lease.expires=s.speed,os.clock()+0.3
	env[s.leaseKey]=s.lease
	s.h.WalkSpeed=s.speed
	if not s.travelling and (not self.atlasCatch or s.speed==0) then s.h:Move(s.direction,false) end
end

function comboController:TravelToField(job, session)
	if not cfg.coconutteam.enabled or not self.travel or not job.field or job.field=="" then return false end
	local here=self:FieldAt(session.root.Position)
	if here and here.Name==job.field then
		if session.travelling then threads:Cancel("comboFieldTravel");session.travelling=false;pcall(stopMovement) end
		return false
	end
	if session.routeTried then return session.travelling end
	session.routeTried=true
	session.travelling=true
	session.speed=math.max(180,cfg.coconutteam.maxspeed)
	threads:Add("comboFieldTravel",function()
		local ok,reached=pcall(self.travel,job.position,job.field,job.deadline)
		if self.session==session then
			session.travelling=false
			if not ok or reached==false then pcall(stopMovement);self.status="Field travel interrupted; adjusting to landing" end
		end
	end)
	return session.travelling
end

function comboController:Tick()
	local now=os.clock()
	for key,chain in pairs(self.chains)do
		if chain.expires<=now then self.chains[key]=nil;self.chainCount-=1 end
	end
	for i=#self.records,1,-1 do
		local r=self.records[i]
		if now>r.deadline+0.25 then
			if self.byKey[r.key]==r then self.byKey[r.key]=nil end
			table.remove(self.records,i)
		end
	end
	if not self:Managed() then self.ownPriority=false;self.comboPriority=false;self:Finish("Disabled");return end
	if self:TravelBlocked() then
		self.ownPriority,self.comboPriority,self.privatePriority=false,false,false
		self:Finish("Task travel protected; combo walking deferred");return
	end
	local character=localPlayer.Character
	local root=character and character:FindFirstChild("HumanoidRootPart")
	if not root then self:Finish("No character");return end
	local diskLanding=self:DiskLanding()
	local private=self:PrivateLanding()
	local own=private or self:LocalAltTurn() or self:OwnLanding() or self:OutsideMainLanding() or self:OutsideAltLanding() or diskLanding
	local job=own
	if not job and cfg.coconutteam.enabled then
		for _, candidate in ipairs(self.jobs) do
			if self:AcceptTeamJob(candidate) and candidate.deadline+0.12>now and candidate.leaseUntil>now then job=candidate;break end
		end
	elseif not job then
		-- Independent outside-field mode has no ownership rotation and needs no coordinator.
		local home=cfg.coconutteam.field~="" and cfg.coconutteam.field or cfg.autofarm.field1
		for _, r in ipairs(self.records) do
			if not self:MainOwned(r.owner) and r.field~=home and r.deadline>now and math.abs(r.position.Y-root.Position.Y)<=12 then
				local d=(Vector3.new(r.position.X,root.Position.Y,r.position.Z)-root.Position).Magnitude
				if math.max(0,d-5)/cfg.coconutteam.maxspeed+0.12<r.deadline-now then
					if not job or r.deadline<job.deadline then job=r end
				end
			end
		end
	end
	if not job then job=self:YieldLanding(root) end
	if job and not self:MobileTeam() and not fieldPositionPolicy:SmileyOnly() and not fieldPositionPolicy:StrictAllowed(job.position) then job=nil;own=nil;private=nil end
	if job and job.yielding then own=job end
	self.privatePriority=private~=nil
	self.ownPriority=own~=nil
	self.comboPriority=job~=nil
	local decision=(job and job.key or "none")..":"..tostring(job and job.yielding or false)
	if self.traceDecision~=decision then
		self.traceDecision=decision
		self:Trace("decision",{key=job and job.key or "none",owner=job and job.owner or "unknown",role=self:Role() or "unassigned",
			action=job and (job.yielding and "yield" or "catch") or "skip",private=self.privatePriority,
			managed=self:Managed(),stop=state.stop==true,activity=tostring(state.activityStatus)})
	end
	if job and showerController.active and showerController.cancel then showerController.cancel("Combo catching has priority") end
	local available,h,root=self:Available()
	if not available then self:Finish("Busy with another activity");return end
	if self.session and (self.session.root~=root or self.session.h~=h) then self:Finish("Character changed") end
	if not job then
		local reason=cfg.coconutteam.enabled and "Waiting for assignment" or "Waiting for outside-field combo"
		if cfg.coconutteam.enabled and not self:Role() then reason="This account is not selected in Coconut Team"
		elseif #self.records==0 and not next(self.disks or {}) then reason="No combo target detected" end
		self:Finish(reason);return
	end
	local s=self:Begin(job,h,root)
	if not s then return end
	if self:TravelToField(job,s) then self:Drive(s);self.status="Following combo to "..job.field;return end
	local delta=Vector3.new(job.position.X-root.Position.X,0,job.position.Z-root.Position.Z)
	local d=delta.Magnitude
	-- Full-speed approach with a short final step; the observed deadline controls holding.
	local cap=math.max(180,cfg.coconutteam.maxspeed)
	-- Commit immediately and shorten the final step; do not wait for the fall timer.
	local elapsed=now-(s.lastUpdate or (now-1/30))
	s.lastUpdate=now
	s.speed=d>0.5 and math.min(cap,d/math.max(0.05,elapsed+1/60)) or 0
	s.direction=d>0.5 and delta.Unit or Vector3.zero
	if d<=0.5 then
		local v=root.AssemblyLinearVelocity
		root.AssemblyLinearVelocity=Vector3.new(0,v.Y,0)
		root.AssemblyAngularVelocity=Vector3.zero
	end
	s.yieldJob=job.yielding and job or nil
	s.target=s.target or {Name=true}
	s.target.Position,s.target.ExpiresAt=job.position,job.deadline
	self:Drive(s)
	if self.atlasCatch and not s.travelling and not threads:Get("comboAtlasCatch") then
		threads:Add("comboAtlasCatch",function()self.atlasCatch(s.target,s)end)
	end
	self.status=job.yielding and "Moving clear for main solo catch" or string.format("Catching %s combo | %.0f PMS",job.owner or "outside",s.speed)
end

function comboController:Roster()
	local c=cfg.coconutteam
	local catchers={}
	for _,key in ipairs({"catcher1","catcher2","catcher3"}) do if c[key]~="" and c[key]~="None" then catchers[#catchers+1]=c[key] end end
	return {main=c.main,alts={c.alt1,c.alt2},catchers=catchers,field=c.field~="" and c.field or cfg.autofarm.field1}
end

function comboController:KeepLanding()
	local now=os.clock()
	local kept={}
	local available,_,root=self:Available()
	if available and root then
		for _,j in ipairs(self.jobs)do
			if not self:MainOwned(j.owner) and j.leaseUntil>now and j.deadline+0.12>now then
				local delta=Vector3.new(j.position.X-root.Position.X,0,j.position.Z-root.Position.Z)
				if delta.Magnitude<=9 and math.abs(j.position.Y-root.Position.Y)<=7 then kept[1]=j;break end
			end
		end
	end
	self.jobs=kept
	return kept
end

function comboController:Sync()
	local c=cfg.coconutteam
	if c.url=="" or c.key=="" then self.status="Paste the launcher's connection code";return false end
	local available,h,root=self:Available()
	local char=localPlayer.Character
	root=root or (char and char:FindFirstChild("HumanoidRootPart"))
	h=h or (char and char:FindFirstChildOfClass("Humanoid"))
	if not root or not h then return false end
	local started=os.clock()
	local list={}
	for _,r in ipairs(self.records) do
		if r.owner and not self:MainOwned(r.owner) and r.deadline>started then
			list[#list+1]={key=r.key,owner=r.owner,pos={r.position.X,r.position.Y,r.position.Z},ttl=r.deadline-started-math.min((self.roundTrip or 0.2)/2,1),points=r.points,field=r.field}
		end
	end
	self.seq+=1
	local speed=self.session and c.maxspeed or math.max(h.WalkSpeed,c.maxspeed)
	local payload={protocol=2,active_key=self.session and self.session.key or "",username=localPlayer.Name,server=game.JobId,session=self.sessionId,seq=self.seq,sample_age=math.min((self.roundTrip or 0.2)/2,1),
		pos={root.Position.X,root.Position.Y,root.Position.Z},speed=speed,busy=not available or (self.ownPriority and not self.privatePriority),
		roster=self:Roster(),targets=list}
	if not available then self:Finish("Busy with another activity");payload.active_key="" end
	local generation=self.generation
	local ok,response=pcall(http_request,{Url=c.url.."/v1/sync",Method="POST",Headers={["Content-Type"]="application/json",Authorization="Bearer "..c.key},Body=HttpService:JSONEncode(payload),Timeout=3})
	if generation~=self.generation or self.closed or not c.enabled then return false end
	local elapsed=os.clock()-started
	if not ok or not response or response.StatusCode~=200 then
		self:KeepLanding();self.status="Coordinator unavailable; no new catches assigned"
		if ok and response and response.StatusCode==400 then
			local parsed,problem=pcall(HttpService.JSONDecode,HttpService,response.Body)
			if parsed and type(problem)=="table" and type(problem.error)=="string" then self.status=problem.error end
		elseif ok and response and response.StatusCode==401 then self.status="Connection code rejected; paste the current launcher code" end
		return false
	end
	local decoded,data=pcall(HttpService.JSONDecode,HttpService,response.Body)
	if not decoded or type(data)~="table" or not data.ok or type(data.jobs)~="table" then
		self.jobs={};self.status=type(data)=="table" and (data.message or "Coordinator rejected settings") or "Invalid coordinator reply";return false
	end
	if data.protocol~=2 then self.jobs={};self.status="Update coordinator PC to catch-timing v2, then reconnect";return false end
	local jobs={}
	for _,j in ipairs(data.jobs) do
		if #jobs>=1 then break end
		if self:MainOwned(j.owner) then continue end
		if type(j.pos)=="table" and #j.pos==3 and type(j.ttl)=="number" and type(j.lease)=="number"
			and type(j.pos[1])=="number" and type(j.pos[2])=="number" and type(j.pos[3])=="number" then
			local deadline=os.clock()+math.min(j.ttl,12)-elapsed
			local target=Vector3.new(table.unpack(j.pos))
			-- The local FX observation is more precise than an HTTP round trip.
			-- Do not walk away before impact just because a conservative TTL ended early.
			for _,r in ipairs(self.records)do
				if r.deadline+0.12>os.clock() and r.owner and type(j.owner)=="string"
					and string.lower(r.owner)==string.lower(j.owner) and (r.position-target).Magnitude<2 then
					deadline=r.deadline;break
				end
			end
			local lease=math.min(j.lease,12.5)-elapsed
			if deadline+0.12>os.clock() and lease>0 then
				local targetField=self:FieldAt(target)
				local candidate={key=j.key,owner=j.owner,position=target,field=targetField and targetField.Name or "",deadline=deadline,leaseUntil=os.clock()+lease}
				if self:AcceptTeamJob(candidate) then jobs[#jobs+1]=candidate end
			end
		end
	end
	if #jobs==0 then jobs=self:KeepLanding() end
	self.jobs=jobs
	self.status=data.message or "Connected"
	self.roundTrip=elapsed
	return true
end

function comboController:Configure()
	self.mainField,self.mainFieldCandidate,self.mainFieldSample,self.mainFieldSeen=nil,nil,nil,nil
	self.generation+=1
	self:Finish("Settings changed")
	table.clear(self.jobs)
	threads:Cancel("comboTeamSync")
	if self:Managed() and self.installObserver then self:installObserver() end
	if not cfg.coconutteam.enabled or self.closed then return end
	threads:Add("comboTeamSync",function()
		local failures=0
		while not self.closed and cfg.coconutteam.enabled do
			local ok,result=pcall(function()return self:Sync()end)
			if ok and result then failures=0 else failures=math.min(failures+1,4);self:KeepLanding() end
			task.wait(failures==0 and 0.15 or math.min(4,0.5*2^(failures-1)))
		end
	end)
end

function comboController:Start()
	if self.started then return end
	self.started=true
	self.sessionId=HttpService:GenerateGUID(false)
	local fx=gameApi.Events and gameApi.Events:FindFirstChild("LocalFX")
	if fx and fx:IsA("RemoteEvent") then
		connections:Add("comboTeamFX",fx.OnClientEvent:Connect(function(name,data)
			if type(data)=="table" then pcall(function()self:Observe(name,data)end) end
		end))
		self.observesRemote=true
	end
	local elapsed=0
	connections:Add("comboTeamTick",RunService.Heartbeat:Connect(function(dt)
		elapsed+=dt
		if elapsed<0.03 then return end
		elapsed=0
		local ok,err=pcall(function()self:Tick()end)
		if not ok then self:Finish("Combo movement stopped by error");self.status=tostring(err) end
		if self.statusLabel then self.statusLabel.Text="Team: "..self.status end
		if self.ownerLabel then self.ownerLabel.Text="Last combo owner: "..(self.lastOwner or "waiting for a new combo") end
		if self.effectLabel then self.effectLabel.Text="Tracking: "..(self.effectStatus or "waiting for combo FX") end
		if self.debugLabel then
			local disks=0;for _ in pairs(self.disks or {})do disks+=1 end
			self.debugLabel.Text=string.format("FX: %d | Atlas: %d | Assigned: %d | Role: %s | RTT: %.0f ms",#self.records,disks,#self.jobs,self:Role() or "unassigned",(self.roundTrip or 0)*1000)
		end
	end))
	local particles=workspace:FindFirstChild("Particles")
	if particles then
		for _,disk in ipairs(particles:GetChildren()) do
			if disk.Name=="WarningDisk" and disk:IsA("BasePart") and disk.Size.X>20 and disk.Size.X<=38 then self:TrackDisk(disk) end
		end
	end
	self:Configure()
end

function comboController:Shutdown()
	self.closed=true
	self.generation+=1
	threads:Cancel("comboTeamSync")
	connections:Cancel("comboTeamTick")
	connections:Cancel("comboTeamFX")
	self:Finish("Unloaded")
	if self.disks then table.clear(self.disks) end
	self.atlasTargets=nil
	self.taskTravel=nil
	if self.trace then table.clear(self.trace) end
	table.clear(self.records);table.clear(self.byKey);table.clear(self.jobs);table.clear(self.chains);self.chainCount=0
end

function comboController:BuildMenu(tab)
	local folder=tab.AddFolder("Coconut Team")
	folder.AddSwitch("Coordinate Coconut Team",function()self:Configure()end,"coconutteam","enabled")
	folder.AddSwitch("Fast Combo Catching",function()self:Configure()end,"coconutteam","fast")
	local followSelector=folder.AddSwitch("Follow Main Between Fields",function()self:Configure()end,"coconutteam","followmain",{Tooltip="Spawning alts follow the main into each settled field and farm there, including during RBC. Enable Auto Farm on the alts. Outside catchers retain their selected field."})
	folder.AddLabel("Mobile team follows the main field; turn follow off to use the fixed Team Field.")
	folder.AddLabel("Main combo: spawning alts in the main/team field; outside catchers in Outside Catch Field.")
	folder.AddLabel("Main catches 0x, then helps every N shared drops in the same field. Spawners catch their own 0x locally.")
	folder.AddLabel("Keep the help interval identical on every client; Copy Team Code includes it.")
	folder.AddLabel("Alt combo: 0x owner; odd stacks main solo when reachable; helpers keep unreachable drops alive.")
	folder.AddLabel("Temporary 10x root density during combo movement; original properties restore afterward.")
	folder.AddLabel("Team controls override Farm Combo Coconuts; that regular switch is not required.")
	folder.AddLabel("Fast mode works with autofarm off. Outside catchers need this enabled.")
	folder.AddLabel("Solo fast mode catches outside the selected team field without alternating.")
	local names={"None"}
	for _,p in ipairs(getService("Players"):GetPlayers())do names[#names+1]=p.Name end
	local selectors={}
	for _,entry in ipairs({{"Main Account","main"},{"Spawning Alt 1","alt1"},{"Spawning Alt 2","alt2"},{"Outside Catcher 1","catcher1"},{"Outside Catcher 2","catcher2"},{"Outside Catcher 3","catcher3"}})do
		selectors[entry[2]]=folder.AddDropdown(entry[1],names,nil,function()self:Configure()end,"coconutteam",entry[2])
	end
	local assistSelector=folder.AddSlider("Main Help Every N Shared Drops",function()self:Configure()end,2,10,"coconutteam","mainassist",{Left=true})
	local fieldSelector=folder.AddDropdown("Team Field",availableFields,true,function()self:Configure()end,"coconutteam","field",{Field=true})
	local outsideSelector=folder.AddDropdown("Outside Catch Field",availableFields,true,function()self:Configure()end,"coconutteam","outsidefield",{Field=true})
	folder.AddSlider("Fast Combo Maximum Speed",function()self:Configure()end,30,180,"coconutteam","maxspeed",{Left=true})
	folder.AddTextBox("Paste Connection / Team Code",function(text)
		local ok,code=pcall(HttpService.JSONDecode,HttpService,text)
		if not ok or type(code)~="table" or type(code.url)~="string" or type(code.key)~="string"
			or #code.key<32 or #code.key>128 or not (string.match(code.url,"^https://[%w%.%-]+:?%d*$") or string.match(code.url,"^http://127%.0%.0%.1:%d+$")) then
			ui.Notify("Coconut Team","Invalid connection code");return
		end
		cfg.coconutteam.url,cfg.coconutteam.key=code.url,code.key
		for _,key in ipairs({"main","alt1","alt2","catcher1","catcher2","catcher3"})do
			if type(code[key])=="string" and #code[key]<=20 then
				cfg.coconutteam[key]=code[key]
				selectors[key].Add(code[key]);selectors[key].SetValue(code[key])
			end
		end
		if type(code.mainassist)=="number" and code.mainassist>=2 and code.mainassist<=10 then
			cfg.coconutteam.mainassist=math.floor(code.mainassist)
			if assistSelector then assistSelector.Set(cfg.coconutteam.mainassist) end
		end
		if type(code.followmain)=="boolean" then cfg.coconutteam.followmain=code.followmain;followSelector.Set(code.followmain) end
		if type(code.field)=="string" and availableFields[code.field] then cfg.coconutteam.field=code.field;fieldSelector.SetValue(code.field) end
		if type(code.outsidefield)=="string" and availableFields[code.outsidefield] then cfg.coconutteam.outsidefield=code.outsidefield;outsideSelector.SetValue(code.outsidefield) end
		saveConfig();self:Configure();ui.Notify("Coconut Team","Connection and account settings saved")
	end)
	folder.AddButton("Copy Team Code",function()
		local c=cfg.coconutteam
		local copy=setclipboard or toclipboard
		if not copy then ui.Notify("Coconut Team","Clipboard unavailable");return end
		copy(HttpService:JSONEncode({url=c.url,key=c.key,main=c.main,alt1=c.alt1,alt2=c.alt2,catcher1=c.catcher1,catcher2=c.catcher2,catcher3=c.catcher3,field=c.field,outsidefield=c.outsidefield,mainassist=c.mainassist or 3,followmain=c.followmain==true}))
		ui.Notify("Coconut Team","Paste this code into each team account")
	end)
	folder.AddButton("Copy Combo Diagnostics",function()
		local copy=setclipboard or toclipboard
		if not copy then ui.Notify("Coconut Team","Clipboard unavailable");return end
		local ok,result=pcall(HttpService.JSONEncode,HttpService,self:Diagnostics())
		if not ok then ui.Notify("Coconut Team","Could not encode diagnostics");return end
		copy(result);ui.Notify("Coconut Team","Combo diagnostics copied")
	end)
	folder.AddButton("Reconnect Coordinator",function()self:Configure()end)
	self.statusLabel=folder.AddLabel("Team: Disabled")
	self.ownerLabel=folder.AddLabel("Last combo owner: waiting for a new combo")
	self.debugLabel=folder.AddLabel("Detected: 0 | Assigned: 0 | RTT: waiting")
	self.effectLabel=folder.AddLabel("Tracking: waiting for combo FX")
	folder.AddLabel("One launcher for all computers. All accounts must be in the same Roblox server.")
	folder.Toggle(true,true)
end


local function distanceTo(position)return (position-root.Position).Magnitude end
local gatheringPriorities={ShouldPreempt=function()error("combo must bypass ordinary gather preemption")end}
local collectObject
		collectObject = function(object, trackedKey, reachDistance, longTimeout, keepMoving, useTween, cloudMode, hasId, comboSession)
			if not useTween then
				if (reachDistance or 5) < distanceTo(object.Position, true) then
					smoothMovement:MoveTo(object.Position)
				end
			end

			local now = os.clock()

			if useTween then
				local linear = Enum.EasingStyle.Linear
				local out = Enum.EasingDirection.Out
				showerController:CreateMovementTween(getRootPart(), TweenInfo.new(distanceTo(object.Position) / 400, linear, out), { CFrame = CFrame.new(object.Position) }):Play()
			end

			while true do
				local options=gatheringPriorities.activeOptions
				if not (comboSession and (comboController:MobileTeam() or fieldPositionPolicy:SmileyOnly())) and not fieldPositionPolicy:StrictAllowed(object.Position) then return true end
				if not comboSession and options and options.area and not fieldPositionPolicy:Allowed(object.Position,options) then return true end
				if comboSession then
					if comboController.session~=comboSession or state.stop or os.clock()>object.ExpiresAt+0.12 then return true end
				elseif gatheringPriorities:ShouldPreempt() then return true end
				if cloudMode then
					if not ((buffs.Cloud and buffs.Cloud.Size.Y.Scale or 0) < 0.8) then
						return
					end
				end

				if not RunService.Heartbeat:Wait() then
					return
				end

				if not ((object.Name == true or object.Parent) and (object.Name ~= true or not trackedKey or not (not hasId and not tracked[trackedKey][object] or not (not hasId or tracked[trackedKey][object.ID])))) then
					break
				end

				if (longTimeout and 5 or 3) < os.clock() - now then
					break
				end

				if not longTimeout then
					if distanceTo(object.Position, true) < (reachDistance or 5) then
						break
					end
				end

				if not useTween and not (not keepMoving or not (not cloudMode or not not (distanceTo(object.Position, true) > 6))) then
					smoothMovement:MoveTo(object.Position)
				end
			end

			if comboSession then return true end
			if not trackedKey then
				touchedMarks[object] = os.clock() + 3
			elseif trackedKey ~= "flames" then
				tracked[trackedKey][object.Name == true and hasId and object.ID or object] = nil
			end

			return true
		end

threads:Add("Autofarm",worker);threads:Add("walkspeed",worker);threads:Add("Stats",worker)
local stats=threads:Get("Stats")
local actualMainReady=comboController.MainReady
comboController.MainReady=function()return true end
comboController:Start()
local startConnections=liveConnections
assert(comboController.observesRemote)
local function observe(x,id,owner,points)
 fx.OnClientEvent:Fire("FallingCoconut",{Friendly=true,Combo=points~=nil and points or true,Pos=vector(x,3,0),Dur=2,ID=id,ComboOwner=owner or player,Points=100})
end
observe(5,"inside");comboController:Tick();assert(not comboController.active,"solo fast stole in-field combo")
observe(35,"outside");comboController:Tick()
assert(comboController.active and not controls.controlsEnabled)
assert(root.CustomPhysicalProperties.Density==7 and root.Massless==false,"combo density was not applied")
assert(not threads:Get("Autofarm") and threads:Get("Stats")==stats)
threads:Add("Autofarm",worker);assert(not threads:Get("Autofarm"),"watchdog stole combo movement")
for i=1,25 do step(0.03)end
assert(root.Position.X>25,"continuous movement did not approach coconut")
showerController.active=true
showerController.cancel=function()showerController.active=false end
comboController:Tick()
assert(comboController.active and not showerController.active,"combo did not override shower")
state.stop=true;comboController:Tick()
assert(not comboController.active and h.WalkSpeed==40 and controls.controlsEnabled and root.CustomPhysicalProperties==nil and root.Massless==false,"stop did not restore density and movement")
state.stop=false
showerController.active=false
cfg.coconutteam.enabled=true;cfg.coconutteam.fast=false
comboController.jobs={{key="assigned",owner="Tester",position=vector(40,3,0),deadline=now+1,leaseUntil=now+.4}}
state.activityStatus=3;showerController.active=true
comboController:Tick();assert(comboController.active and not showerController.active and comboController.comboPriority,"assigned alt catch did not preempt other work")
state.activityStatus=1
now+=.5;comboController:Tick();assert(not comboController.active,"expired network lease still moving")
assert(comboController:Sync());assert(sent.server==game.JobId and sent.roster.main=="OtherMain")
assert(#sent.targets==1,"latest visible combo observation missing or old landing retained")
reply.jobs={{key="remote",owner="Tester",pos={40,3,0},ttl=1,lease=.65}}
comboController:Sync();assert(#comboController.jobs==1)
assert(comboController.jobs[1].leaseUntil<=now+.551,"round trip not deducted")
networkFail=true;assert(not comboController:Sync() and #comboController.jobs==1,"brief failure discarded an already-reached leased landing")
networkFail=false;comboController.jobs={};changeSettings=true
assert(not comboController:Sync() and #comboController.jobs==0,"late reply applied after settings changed")
changeSettings=false;requestDuration=1
comboController:Sync();assert(#comboController.jobs==0,"slow reply granted expired lease")
-- Reach the landing and keep ownership through the true local impact time.
requestDuration=.1
root.Position=vector(40,3,0)
observe(40,"impact")
local impact=now+2
reply.jobs={{key="impact",owner="Tester",pos={40,3,0},ttl=1.65,lease=2.35}}
assert(comboController:Sync())
assert(math.abs(comboController.jobs[1].deadline-impact)<.001,"HTTP TTL replaced local impact time")
comboController:Tick();assert(comboController.active)
now=impact-.3;networkFail=true
assert(not comboController:Sync() and #comboController.jobs==1,"brief HTTP failure discarded committed landing")
comboController:Tick();assert(comboController.active)
networkFail=false
now=impact-.05
reply.jobs={}
assert(comboController:Sync())
comboController:Tick()
assert(now>impact and comboController.active,"walked away before/at impact")
for _,fn in pairs(RunService.bound)do fn()end
assert(h.WalkSpeed==0,"did not hold still beneath coconut")
now=impact+.13
comboController:Tick();assert(not comboController.active,"held beyond impact window")
-- Old server must give an actionable update message rather than silently miss.
reply.protocol=nil
assert(not comboController:Sync() and string.find(comboController.status,"Update coordinator PC",1,true))
reply.protocol=2
-- A spawning alt catches its private zero-stack drop with no coordinator job.
comboController:Finish("private test")
comboController.records={};comboController.byKey={};comboController.jobs={};comboController.chains={};comboController.chainCount=0
cfg.coconutteam.enabled=true;cfg.coconutteam.alt1="Tester";cfg.coconutteam.main="OtherMain"
fx.OnClientEvent:Fire("FallingCoconut",{Combo=0,Friendly=true,Pos=vector(5,3,0),Dur=2,Points=100,ID="private-alt"})
comboController:Tick()
assert(comboController.active and comboController.privatePriority and comboController.session.key==comboController:PrivateLanding().key,"private alt 0x drop waited for assignment")
assert(comboController:PrivateLanding().owner=="Tester","private 0x owner not resolved")
assert(comboController:Sync() and sent.busy==false,"private touch hidden from relay availability")
comboController:Finish("private test complete")
comboController.records={};comboController.byKey={};comboController.jobs={};comboController.chains={};comboController.chainCount=0
-- Main catches private 0x, then every third shared drop in the same field.
cfg.coconutteam.main="Tester";cfg.coconutteam.alt1="AltOne";cfg.coconutteam.mainassist=3
cfg.autofarm.enabled=false;state.activityStatus=2
comboController.records={};comboController.byKey={};comboController.jobs={};comboController.chains={};comboController.chainCount=0
root.Position=vector(0,3,0)
local cancelled=0
showerController.active=true
showerController.cancel=function()cancelled+=1;showerController.active=false end
fx.OnClientEvent:Fire("FallingCoconut",{Friendly=true,Combo=0,Pos=vector(80,3,0),Dur=2,ID="main-chain",Target=player,Points=100})
comboController:Tick()
assert(comboController.active and comboController.privatePriority and cancelled==1,"main ignored private 0x")
for count=1,6 do
 now+=.2
 fx.OnClientEvent:Fire("KickedComboCoconut",{Combo=count,Pos2=vector(80,3,0),Duration=1.5,ID="main-chain",Target="SomeoneElse",Points=100})
 comboController:Tick()
 if count%3==0 then
  assert(comboController.active and comboController:OwnLanding().owner=="Tester","main missed scheduled help")
  local savedPosition=root.Position;local record=comboController:OwnLanding()
  player.Name="OutsideOne";root.Position=record.position
  assert(not comboController:OutsideMainLanding() and comboController:YieldLanding(root),"helper stole main's occasional own-combo catch")
  player.Name="Tester";root.Position=savedPosition
 else
  assert(not comboController.active and not comboController:OwnLanding(),"main stole an alt's shared drop")
 end
end
for _,fn in pairs(RunService.bound)do fn()end
assert(h.WalkSpeed>=180,"scheduled help was not accelerated")
local deliveries=#comboController.records
fx.OnClientEvent:Fire("KickedComboCoconut",{Combo=6,Pos2=vector(80,3,0),Duration=1.5,ID="main-chain",Points=100})
assert(#comboController.records==deliveries,"duplicate delivery advanced help counter")
networkFail=true
assert(not comboController:Sync())
assert(comboController.active and sent.busy==true and #sent.targets==0,"scheduled own help depends on relay")
networkFail=false
for count=1,3 do
 now+=.2
 fx.OnClientEvent:Fire("KickedComboCoconut",{Combo=6+count,Pos2=vector(5,3,0),Duration=1.5,ID="main-chain",Points=100})
 comboController:Tick()
 assert(comboController.active==(count==3),"field change did not reset help interval")
end
comboController:Finish("test")
-- Main's assigned turn on an alt combo is hyperfocused, but has no local ownership override.
comboController.records={};comboController.byKey={};comboController.chains={};comboController.chainCount=0
observe(50,"alt-main-turn","AltOne",1)
comboController.jobs={{key="main-turn",owner="AltOne",position=vector(50,3,0),deadline=now+2,leaseUntil=now+1}}
state.activityStatus=3;showerController.active=true
comboController:Tick()
assert(comboController.active and comboController.comboPriority and comboController.ownPriority and not showerController.active,"main's alt-combo turn was not hyperfocused")
comboController:Finish("test")
-- Reserved alt drops are immediate local main turns; everyone else stays off.
comboController:Finish("solo turn test")
comboController.records={};comboController.byKey={};comboController.jobs={};comboController.chains={};comboController.chainCount=0
cfg.coconutteam.main="Tester";cfg.coconutteam.alt1="AltOne";cfg.coconutteam.alt2="AltTwo";cfg.coconutteam.catcher1="OutsideOne"
cfg.coconutteam.fast=true;cfg.autofarm.enabled=true;state.activityStatus=1
for points=0,6 do
 now+=.2
 fx.OnClientEvent:Fire("FallingCoconut",{Friendly=true,Combo=points,Pos=vector(40,3,0),Dur=2,ID="solo-chain",Owner="AltOne",Points=100})
 local record=comboController.records[#comboController.records]
 local stale={key="stale",owner="AltOne",position=record.position,deadline=record.deadline,leaseUntil=now+2}
 player.Name="Tester"
 assert(comboController:AltDropAllowed(record)==(points%2==1),"main reserved parity wrong")
 if points%2==1 then
  comboController.jobs={};state.activityStatus=3
  comboController:Tick()
  assert(comboController.active and comboController.session.key==record.key,"main did not chase reserved solo drop without relay")
  comboController:Finish("role checks");state.activityStatus=1
 end
 player.Name="AltOne"
 assert(comboController:AltDropAllowed(record)==(points%2==0),"spawner did not leave main's reserved drop")
 if points%2==1 then
  local savedPosition=root.Position;root.Position=record.position
  comboController.jobs={};comboController:Tick()
  assert(comboController.active and comboController.session.yieldJob,"spawner remained under reserved landing")
  local clear=comboController.session.yieldJob.position
  assert((clear-record.position).Magnitude>=18,"solo clearance too small")
  root.Position=clear;comboController:Tick()
  assert(comboController.active and comboController.session.yieldJob,"spawner resumed farming into reserved circle")
  comboController:Finish("yield test complete");root.Position=savedPosition
 end
 if points%2==0 then assert(comboController:LocalAltTurn()==record,"spawner's even turn waited for relay") end
 player.Name="AltTwo"
 assert(not comboController:AltDropAllowed(record) and not comboController:AcceptTeamJob(stale),"other on-field alt stole reserved combo")
 player.Name="OutsideOne"
 assert(comboController:AltDropAllowed(record)==(points>0 and points%2==0),"outside catcher did not honor solo turn")
 if points%2==1 then assert(not comboController:OutsideAltLanding() and not comboController:AcceptTeamJob(stale),"catcher chased reserved main turn") end
end
player.Name="Tester"
comboController:Finish("solo test complete")
-- A remote main must actually be in position before helpers reserve a solo turn.
comboController:Finish("readiness setup")
local savedPlayers=Players.list
local oldRoleName=player.Name
local savedMain,savedAlt,savedOutside=cfg.coconutteam.main,cfg.coconutteam.alt1,cfg.coconutteam.outsidefield
local remoteCharacter=Instance.new("Model",workspace)
local remoteRoot=Instance.new("Part",remoteCharacter);remoteRoot.Name="HumanoidRootPart";remoteRoot.Position=vector(0,3,0)
local remoteHumanoid=Instance.new("Humanoid",remoteCharacter)
local remoteMain={Name="RemoteMain",Character=remoteCharacter}
Players.list={player,remoteMain}
cfg.coconutteam.main="RemoteMain";cfg.coconutteam.alt1="Tester";cfg.coconutteam.outsidefield="Pepper Patch"
player.Name="Tester"
local reserved={key="reachability",owner="Tester",stackKnown=true,stack=3,points=100,position=vector(5,3,0),field="Pepper Patch",deadline=now+1}
comboController.MainReady=actualMainReady
assert(comboController:MainReady(reserved) and not comboController:AltDropAllowed(reserved),"reachable main did not reserve solo drop")
remoteRoot.Position=vector(35,3,0)
assert(not comboController:MainReady(reserved) and comboController:AltDropAllowed(reserved),"alt waited for main in another field and dropped combo")
remoteRoot.Position=vector(0,3,0);assert(comboController:MainReady(reserved))
remoteRoot.Position=vector(-200,3,0)
assert(not comboController:MainReady(reserved) and comboController:AltDropAllowed(reserved),"stale reservation retained main too far away in the same field")
local savedRecords=comboController.records;comboController.records={reserved}
player.Name="OutsideOne";cfg.coconutteam.catcher1="OutsideOne"
assert(comboController:AltDropAllowed(reserved) and not comboController:YieldLanding(root),"outside helpers yielded to unreachable main")
remoteRoot.Position=vector(0,100,0)
assert(not comboController:MainReady(reserved),"airborne main was treated as ready")
remoteRoot.Position=vector(0,3,0);remoteHumanoid.Health=0
assert(not comboController:MainReady(reserved),"dead main reserved a drop")
remoteHumanoid.Health=100
assert(comboController:MainReady(reserved),"main did not regain solo reservation after returning")
comboController.records=savedRecords;Players.list=savedPlayers;remoteCharacter:Destroy()
player.Name=oldRoleName;cfg.coconutteam.main=savedMain;cfg.coconutteam.alt1=savedAlt;cfg.coconutteam.outsidefield=savedOutside
comboController.MainReady=function()return true end
-- An alt rejects coordinator assignments for the main, including stale server jobs.
cfg.coconutteam.main="OtherMain";cfg.coconutteam.alt1="Tester"
cfg.autofarm.enabled=true;state.activityStatus=1
comboController.records={};comboController.byKey={}
reply.jobs={{key="main-only",owner="OtherMain",pos={5,3,0},ttl=2,lease=2}}
assert(comboController:Sync() and #comboController.jobs==0,"alt accepted main-owned assignment")
comboController.jobs={{key="stale-main",owner="OtherMain",position=vector(5,3,0),deadline=now+2,leaseUntil=now+2}}
comboController:Tick();assert(not comboController.active,"alt chased stale main-owned job")
-- Spawning alt ownership survives the main's catch and next bounced drop.
comboController.records={};comboController.byKey={};comboController.chains={};comboController.chainCount=0
fx.OnClientEvent:Fire("FallingCoconut",{Friendly=true,Combo=true,Pos=vector(50,3,0),Dur=2,ID="alt-chain",Target=player})
now+=.2
fx.OnClientEvent:Fire("KickedComboCoconut",{GoalPos=vector(60,3,0),Dur=2,ID="alt-chain",Target="OtherMain"})
local last=comboController.records[#comboController.records]
assert(last.owner=="Tester" and last.position.X==60 and comboController:AcceptTeamJob(last),"alt's second turn lost ownership to main")
-- Outside helper preempts everything for a main-owned landing in its field.
cfg.coconutteam.alt1="AltOne";cfg.coconutteam.catcher1="Tester"
cfg.coconutteam.catcher2="HelperB";cfg.coconutteam.catcher3="HelperC"
cfg.coconutteam.fast=true
local helperB={Name="HelperB",Character=Instance.new("Model",world)}
local bh=Instance.new("Humanoid",helperB.Character)
local br=Instance.new("Part",helperB.Character);br.Name="HumanoidRootPart";br.Position=vector(80,3,0)
local helperC={Name="HelperC",Character=Instance.new("Model",world)}
local ch=Instance.new("Humanoid",helperC.Character)
local cr=Instance.new("Part",helperC.Character);cr.Name="HumanoidRootPart";cr.Position=vector(90,3,0)
Players.list={player,helperB,helperC}
root.Position=vector(30,3,0)
comboController.records={};comboController.byKey={};comboController.jobs={}
observe(50,"outside-main", "OtherMain")
state.activityStatus=3;showerController.active=true
comboController:Tick()
assert(comboController.active and comboController.ownPriority and not showerController.active,"outside helper did not prioritize main combo over combat/shower")
now+=.2
fx.OnClientEvent:Fire("KickedComboCoconut",{Combo=2,EndPos=vector(45,3,0),Dur=2,ID="outside-main",Target="HelperB",Points=100})
comboController:Tick()
assert(comboController.active and comboController:OutsideMainLanding().position.X==45 and comboController.lastOwner=="OtherMain","outside catcher ignored next bounce or changed spawning owner")
comboController:Finish("test")
-- Every configured outside helper focuses its assigned outside field.
br.Position=vector(49,3,0)
assert(comboController:OutsideMainLanding()~=nil,"all configured outside catchers should focus their field")
for _,name in ipairs({"Tester","HelperB","HelperC"})do
 player.Name=name
 assert(comboController:OutsideMainLanding()~=nil,"outside helper was excluded from its field")
end
player.Name="Tester"
-- Outside helpers may take alt-owned jobs only outside the home field.
assert(comboController:AcceptTeamJob({owner="AltOne",position=vector(50,3,0)}))
assert(not comboController:AcceptTeamJob({owner="AltOne",position=vector(5,3,0)}))
-- Spawning alts take their own jobs, never the main's or another spawning alt's.
cfg.coconutteam.catcher1="OutsideOne";cfg.coconutteam.alt1="Tester"
assert(comboController:AcceptTeamJob({owner="Tester",position=vector(50,3,0)}))
assert(not comboController:AcceptTeamJob({owner="AltTwo",position=vector(50,3,0)}))
assert(not comboController:AcceptTeamJob({owner="OtherMain",position=vector(50,3,0)}))
assert(comboController:OutsideMainLanding()==nil)
-- Both on-field alts now focus main-owned Pepper drops, even on the first drop.
now+=.2
fx.OnClientEvent:Fire("FallingCoconut",{Friendly=true,Combo=true,Pos=vector(5,3,0),Dur=2,ID="pepper-support",Target="OtherMain"})
comboController:Tick()
assert(comboController.active and comboController.ownPriority,"on-field alt ignored main's Pepper drop")
assert(root.CustomPhysicalProperties.Density==7)
comboController:Finish("test")
player.Name="AltTwo";assert(comboController:OutsideMainLanding()~=nil,"second on-field alt did not focus Pepper")
player.Name="Tester"
state.activityStatus=1
-- Cross-field travel uses the normal navigation helper and restores custom density exactly.
local savedPhysical=PhysicalProperties.new(1.2,.4,.1,2,3)
root.CurrentPhysicalProperties=savedPhysical;root.CustomPhysicalProperties=savedPhysical;root.Massless=true
root.Position=vector(50,3,0)
local routeCalls=0
comboController.travel=function(goal,field)routeCalls+=1;assert(field=="Pepper Patch");coroutine.yield()end
local routeJob={key="route-test",owner="Tester",position=vector(5,3,0),field="Pepper Patch"}
local routeSession=comboController:Begin(routeJob,h,root)
assert(routeSession and root.CustomPhysicalProperties.Density==12 and root.Massless==false)
assert(comboController:TravelToField(routeJob,routeSession) and routeCalls==1 and threads:Get("comboFieldTravel"))
comboController:Finish("route cancelled")
assert(not threads:Get("comboFieldTravel") and root.CustomPhysicalProperties==savedPhysical and root.Massless==true,"route cancellation failed density restoration")
comboController.travel=nil
root.CurrentPhysicalProperties=PhysicalProperties.new(.7,.5,.2,1,1);root.CustomPhysicalProperties=nil;root.Massless=false
cfg.coconutteam.enabled=false;cfg.coconutteam.fast=true
comboController.records={};comboController.byKey={};comboController.chains={};comboController.chainCount=0
root.Position=vector(0,3,0)
observe(35,"low-fps")
for i=1,10 do step(.1)end
assert(math.abs(root.Position.X-35)<.6 and root.CustomPhysicalProperties.Density==7,"low-FPS combo approach drifted/oscillated past target")
for i=1,1000 do
 now+=.1
 observe(50,"transient"..i)
 comboController:Tick()
 assert(#comboController.records<=24 and comboController.chainCount<=64 and liveConnections==startConnections,"transient coconut retention")
end
assert(#comboController.trace<=40,"combo trace grew without bound")
local diagnostics=comboController:Diagnostics()
assert(diagnostics.key==nil and diagnostics.url==nil,"diagnostics exposed coordinator credentials")
state.stop=true;comboController:Tick();assert(not comboController.active and h.WalkSpeed==40)
state.stop=false
cfg.autofarm.enabled=false
observe(50,"outside-autofarm-off");comboController:Tick();assert(comboController.active,"fast mode requires autofarm")
-- Atlas physical marker fallback catches the first drop without FX or the Farm Combo toggle.
comboController:Finish("disk test")
comboController.records={};comboController.jobs={};comboController.byKey={}
cfg.coconutteam.enabled=true;cfg.coconutteam.main="Tester";cfg.coconutteam.field="Pepper Patch"
cfg.autofarm.enabled=true
local hasGui=false
local disk={Parent={},Position=vector(5,3,0)}
function disk:FindFirstChild(name)return hasGui and name=="GuiAttach" and {} or nil end
comboController:TrackDisk(disk)
assert(not comboController:DiskLanding(),"ordinary coconut classified as combo")
hasGui=true
comboController:Tick()
assert(comboController.active,"first physical combo missed")
assert(#comboController.records==0,"unknown owner sent as an FX observation")
local landing=comboController:DiskLanding()
assert(landing and landing.position==disk.Position,"physical landing not tracked")
comboController:Observe("FallingCoconut",{Combo=true,Pos=disk.Position,Dur=2})
assert(comboController:DiskLanding(),"ownerless FX suppressed first disk catch")
disk.Position=vector(6,3,0)
assert(comboController:DiskLanding().position==disk.Position,"marker movement ignored")
disk.Parent=nil
comboController:Tick()
assert(not comboController.active and next(comboController.disks)==nil,"removed marker retained")
-- The original anti-lag tracker uses virtual targets, with the regular toggle off.
comboController.records={};comboController.byKey={};comboController.jobs={}
cfg.autofarm.farmcombococonuts=false
local virtual={Name=true,Position=vector(5,3,0),Points=1,ExpiresAt=now+2}
local atlasTargets={[virtual]=true}
comboController.atlasTargets=function()return atlasTargets end
local originalFieldAt=getFieldAt
getFieldAt=function()return nil end
comboController.fieldFallback=function()return home end
assert(comboController:FieldAt(vector(5,100,0))==home,"airborne field fallback ignored")
getFieldAt=originalFieldAt
comboController.fieldFallback=nil
comboController:Tick()
assert(comboController.active,"Atlas virtual combo ignored with Farm Combo off")
assert(h.WalkSpeed>0,"Heartbeat did not apply combo speed without render callbacks")
local renderDrive=RunService.bound.AtlasComboMovement
RunService.bound.AtlasComboMovement=nil
root.Position=vector(0,3,0)
h.WalkSpeed=0;h.direction=Vector3.zero
step(.04)
assert(root.Position.X>0 and h.WalkSpeed>0,"render-disabled combo movement stalled")
RunService.bound.AtlasComboMovement=renderDrive

now+=2.1;atlasTargets[virtual]=nil
comboController:Tick()
assert(not comboController.active and next(comboController.disks)==nil,"expired virtual combo retained")
-- Exercise the production Atlas collectObject path, not the fallback Humanoid:Move path.
comboController:Finish("collector integration")
now+=1
local target={Name=true,Position=vector(5,3,0),ExpiresAt=now+2,Points=1}
atlasTargets[target]=true
root.Position=vector(0,3,0)
local moveToCalls=0
function RunService.Heartbeat:Wait()return coroutine.yield()end
rawset(h,"MoveTo",function(self,goal)
 moveToCalls+=1
 local delta=vector(goal.X-root.Position.X,0,goal.Z-root.Position.Z)
 self.direction=delta.Magnitude>.01 and delta.Unit or Vector3.zero
end)
function smoothMovement:MoveTo(goal)h:MoveTo(goal)end
comboController.atlasCatch=function(object,session)return collectObject(object,nil,.5,true,true,false,nil,nil,session)end
comboController:Tick()
step(.03)
assert(comboController.active and threads:Get("comboAtlasCatch") and moveToCalls>0,"production Atlas collector not started")
local collectorTask=threads:Get("comboAtlasCatch")
RunService.bound.AtlasComboMovement=nil
for i=1,3 do
 step(.03)
 if coroutine.status(collectorTask)=="suspended" then assert(coroutine.resume(collectorTask,true)) end
end
assert(root.Position.X>0,"production Atlas collector never moved")
local calls=moveToCalls
comboController.session.target.Position=vector(8,3,0)
assert(coroutine.resume(collectorTask,true))
assert(moveToCalls>calls,"production collector failed to follow updated landing")
comboController:Finish("collector cancellation")
assert(not threads:Get("comboAtlasCatch") and h.WalkSpeed==40 and root.CustomPhysicalProperties==nil,"collector cancellation leaked movement")
atlasTargets[target]=nil
comboController.records={};comboController.byKey={};comboController.jobs={};comboController.chains={};comboController.chainCount=0
local priorCalls=moveToCalls
root.Position=vector(0,3,0)
cfg.coconutteam.main="Tester";cfg.coconutteam.alt1="AltOne"
state.activityStatus=3
fx.OnClientEvent:Fire("FallingCoconut",{Friendly=true,Combo=1,Pos=vector(5,3,0),Dur=2,ID="reserved-production",Owner="AltOne",Points=100})
comboController:Tick()
assert(comboController.active and comboController.comboPriority and threads:Get("comboAtlasCatch") and moveToCalls>priorCalls,"main reserved turn never reached production collector")
comboController:Finish("reserved production complete")
-- A task tween takes ownership safely and retains it until its final landing.
comboController:Finish("travel test setup")
comboController.records={};comboController.byKey={};comboController.chains={};comboController.chainCount=0;comboController.jobs={}
root.Position=vector(0,3,0)
fx.OnClientEvent:Fire("FallingCoconut",{Friendly=true,Combo=0,ComboOwner=player,Pos=vector(5,3,0),Dur=2,Points=100})
comboController:Tick();assert(comboController.active,"travel test lacked active combo")
local align=Instance.new("AlignPosition")
local landed=false
comboController.awaitLanding=function()
 assert(comboController.taskTravel,"lock released before landing")
 coroutine.yield("landing")
 landed=true
end
local taskThread=coroutine.create(function()
 return comboController:WithTaskTravel(function()
  assert(not comboController.active and root.CustomPhysicalProperties==nil,"task began before combo cleanup")
  align.Parent=root
  state.tweennoclip={Connected=true}
  coroutine.yield("in flight")
  assert(align.Parent==root,"combo removed tween constraint midair")
  state.tweennoclip=nil
  align:Destroy()
  return "arrived"
 end)
end)
local ok,phase=coroutine.resume(taskThread)
assert(ok and phase=="in flight")
comboController:Tick()
assert(not comboController.active and align.Parent==root and not comboController.comboPriority,"combo interrupted task tween")
ok,phase=coroutine.resume(taskThread)
assert(ok and phase=="landing")
comboController:Tick();assert(not comboController.active and not landed,"combo resumed during final fall")
ok,phase=coroutine.resume(taskThread)
assert(ok and phase=="arrived" and landed and not comboController.taskTravel,"travel lock not released on success")
comboController.awaitLanding=nil
comboController:Tick();assert(comboController.active,"combo did not resume after safe landing")
comboController:Finish("travel error test")
local errorOk=pcall(function()comboController:WithTaskTravel(function()error("task travel failed")end)end)
assert(not errorOk and not comboController.taskTravel,"travel error retained movement lock")
local cancelledTravel=coroutine.create(function()comboController:WithTaskTravel(function()coroutine.yield()end)end)
assert(coroutine.resume(cancelledTravel));coroutine.close(cancelledTravel)
assert(not comboController:TravelBlocked() and not comboController.taskTravel,"cancelled task retained movement lock")
-- Finish resumes queued task work synchronously; Begin must recheck ownership.
local resumedAlign=Instance.new("AlignPosition")
local resumedTask=coroutine.create(function()
 comboController:WithTaskTravel(function()
  resumedAlign.Parent=root;state.tweennoclip={Connected=true}
  coroutine.yield()
  assert(resumedAlign.Parent==root,"new combo destroyed synchronously resumed task tween")
  resumedAlign:Destroy();state.tweennoclip=nil
 end)
end)
local firstSession=comboController:Begin({key="before-task",position=vector(5,3,0)},h,root)
assert(firstSession)
local resumeOthers=showerController.ResumeOthers
local armed=true
showerController.ResumeOthers=function(self)
 resumeOthers(self)
 if armed then armed=false;assert(coroutine.resume(resumedTask)) end
end
local replacement=comboController:Begin({key="after-task",position=vector(8,3,0)},h,root)
assert(not replacement and not comboController.active and resumedAlign.Parent==root,"Begin stole movement after Finish resumed task travel")
assert(coroutine.resume(resumedTask))
showerController.ResumeOthers=resumeOthers
assert(not comboController.taskTravel,"resumed travel did not release ownership")

-- Replay the real FX schema, with account names sanitized.
comboController:Finish("live replay setup")
comboController.records={};comboController.byKey={};comboController.jobs={};comboController.chains={};comboController.chainCount=0;comboController.disks={}
player.Name="MainAccount";cfg.coconutteam.main="MainAccount";cfg.coconutteam.alt1="AltOne";cfg.coconutteam.mainassist=5
cfg.autofarm.enabled=true;state.activityStatus=1
root.Position=vector(-490,123.2,546)
comboController.MainReady=actualMainReady
local liveOwner={ClassName="Player",Name="MainAccount",IsA=function(_,class)return class=="Player"end}
local realEvents={{time=3474.996,effect="KickedComboCoconut",data={Pos1=vector(-490.0,123.2,546.0),Points=100,Rad=13}},{time=3474.996,effect="FallingCoconut",data={Combo=31,Radius=13,Dur=0.9149405464557394,Friendly=true,Points=100,ComboOwner=liveOwner,Pos=vector(-458.0,123.2,554.0)}},{time=3475.927,effect="KickedComboCoconut",data={Pos1=vector(-458.0,123.2,554.0),Points=100,Rad=13}},{time=3475.927,effect="FallingCoconut",data={Combo=32,Radius=13,Dur=0.8835641933074436,Friendly=true,Points=100,ComboOwner=liveOwner,Pos=vector(-498.0,123.2,570.0)}},{time=3476.827,effect="KickedComboCoconut",data={Pos1=vector(-498.0,123.2,570.0),Points=100,Rad=13}},{time=3476.827,effect="FallingCoconut",data={Combo=33,Radius=13,Dur=0.8527900328486191,Friendly=true,Points=100,ComboOwner=liveOwner,Pos=vector(-518.0,123.2,538.0)}},{time=3477.694,effect="KickedComboCoconut",data={Pos1=vector(-518.0,123.2,538.0),Points=100,Rad=13}},{time=3477.694,effect="FallingCoconut",data={Combo=34,Radius=13,Dur=0.8225887698553866,Friendly=true,Points=100,ComboOwner=liveOwner,Pos=vector(-466.0,123.2,534.0)}},{time=3478.51,effect="KickedComboCoconut",data={Pos1=vector(-466.0,123.2,534.0),Points=100,Rad=13}},{time=3478.51,effect="FallingCoconut",data={Combo=35,Radius=13,Dur=0.7929333469863082,Friendly=true,Points=100,ComboOwner=liveOwner,Pos=vector(-490.0,123.2,546.0)}},{time=3479.327,effect="KickedComboCoconut",data={Pos1=vector(-490.0,123.2,546.0),Points=100,Rad=13}},{time=3479.327,effect="FallingCoconut",data={Combo=36,Radius=13,Dur=0.7637987152502324,Friendly=true,Points=100,ComboOwner=liveOwner,Pos=vector(-482.0,123.2,570.0)}},{time=3480.095,effect="KickedComboCoconut",data={Pos1=vector(-482.0,123.2,570.0),Points=100,Rad=13}},{time=3480.095,effect="FallingCoconut",data={Combo=37,Radius=13,Dur=0.7351616336946107,Friendly=true,Points=100,ComboOwner=liveOwner,Pos=vector(-514.0,123.2,554.0)}},{time=3480.844,effect="KickedComboCoconut",data={Pos1=vector(-514.0,123.2,554.0),Points=100,Rad=13}},{time=3480.844,effect="FallingCoconut",data={Combo=38,Radius=13,Dur=0.7070004939101886,Friendly=true,Points=100,ComboOwner=liveOwner,Pos=vector(-470.0,123.2,542.0)}},{time=3481.614,effect="KickedComboCoconut",data={Pos1=vector(-470.0,123.2,542.0),Points=100,Rad=13}},{time=3481.614,effect="FallingCoconut",data={Combo=39,Radius=13,Dur=0.6792951657095281,Friendly=true,Points=100,ComboOwner=liveOwner,Pos=vector(-494.0,123.2,526.0)}}}
local observed=0
local lastTime=realEvents[1].time
for _,event in ipairs(realEvents)do
 now+=event.time-lastTime;lastTime=event.time
 fx.OnClientEvent:Fire(event.effect,event.data)
 comboController:Tick()
 if event.effect=="FallingCoconut" then
  observed+=1
  local record=comboController.records[#comboController.records]
  assert(record.owner=="MainAccount" and record.stack==event.data.Combo and record.points==100 and not record.private,"live FX owner/stack parsing wrong")
  assert(record.sharedDrops==observed,"ownerless live events reset field counter")
  assert(comboController.active==(observed%5==0),"main caught every live drop instead of interval")
 end
end
assert(observed>=8,"live replay fixture too short")
comboController:Finish("main live replay complete")
comboController.records={};comboController.byKey={};comboController.jobs={};comboController.chains={};comboController.chainCount=0;comboController.disks={}
liveOwner.Name="AltOne"
lastTime=realEvents[1].time
for _,event in ipairs(realEvents)do
 now+=event.time-lastTime;lastTime=event.time
 fx.OnClientEvent:Fire(event.effect,event.data)
 comboController:Tick()
 if event.effect=="FallingCoconut" then
  local record=comboController.records[#comboController.records]
  assert(record.owner=="AltOne" and record.points==100 and record.stack==event.data.Combo,"live alt owner/count wrong")
  assert(comboController.active==(event.data.Combo%2==1),"main failed to take actual-schema reserved alt drop")
 end
end
comboController:Finish("live replay complete")

comboController:Finish("mobile team setup")
cfg.coconutteam.enabled=true;cfg.coconutteam.followmain=true
cfg.coconutteam.main="MobileMain";cfg.coconutteam.alt1="Tester";cfg.coconutteam.catcher1="OutsideOne"
cfg.coconutteam.field="Pepper Patch";cfg.coconutteam.outsidefield="Mountain Top Field"
player.Name="Tester"
home.Position=vector(0,0,0);home.Size=vector(100,2,100)
outside.Position=vector(40,0,0);outside.Size=vector(100,2,100)
local mobileChar=Instance.new("Model",workspace)
local mobileRoot=Instance.new("Part",mobileChar);mobileRoot.Name="HumanoidRootPart";mobileRoot.Position=vector(0,3,0)
local mobileHumanoid=Instance.new("Humanoid",mobileChar)
local mobileMain={Name="MobileMain",Character=mobileChar}
Players.list={player,mobileMain}
comboController.mainField=nil;comboController.mainFieldSample=nil;comboController.mainFieldCandidate=nil
assert(comboController:FollowingMain() and comboController:MobileTeam())
assert(not comboController:MainField(),"must wait for main to settle")
now+=.8;assert(comboController:MainField()==home)
mobileRoot.Position=vector(35,3,0)
now+=.3;assert(comboController:MainField()==home,"transit must not immediately change team field")
now+=.8;assert(comboController:TeamField()==outside.Name,"team must leave fixed Pepper field")
comboController.records={{key="mobile-main",owner="MobileMain",field=outside.Name,position=vector(36,3,0),deadline=now+2,sharedDrops=1}}
assert(comboController:OutsideMainLanding(),"spawning alt must catch main combo in new field")
assert(comboController:Roster().field=="Pepper Patch","dynamic movement must not change shared coordinator roster")
player.Name="OutsideOne";assert(not comboController:FollowingMain() and not comboController:MobileTeam(),"outside catchers must retain their own role")
player.Name="Tester";cfg.coconutteam.followmain=false
assert(not comboController:FollowingMain() and comboController:TeamField()=="Pepper Patch")
cfg.coconutteam.followmain=true;Players.list={player};now+=1
assert(not comboController:MainField(),"missing main must stop followers")
mobileChar:Destroy();comboController.records={};cfg.coconutteam.followmain=false
print("PASS: stable live main-field following, combo support outside Pepper, fixed outside catchers, unchanged coordinator roster and missing-main cleanup")
showerController.shuttingDown=true
comboController:Shutdown()
assert(not comboController.active and next(comboController.records)==nil and next(comboController.byKey)==nil and next(comboController.chains)==nil and comboController.chainCount==0 and root.CustomPhysicalProperties==nil and root.Massless==false)
assert(not RunService.bound.AtlasComboMovement and h.WalkSpeed==40 and controls.controlsEnabled)
assert(not connections.list.comboTeamTick and not connections.list.comboTeamFX)
assert(not threads:Get("Autofarm"),"unload resumed farming")
print("PASS: outside-only standalone catching, smooth travel, exclusive movement, shower preemption, expiring leases, RTT, failed/late requests, 1000 coconut lifetimes, autofarm-off, unload restoration")
