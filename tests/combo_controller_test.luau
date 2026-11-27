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

local fieldPositionPolicy={StrictAllowed=function()return true end,RemoveGuards=function()end,ReleaseIdle=function()end,SmileyOnly=function()return false end,Allowed=function()return true end}
local meteorMovement={Release=function()end}
local localPlayer=player
player.ClassName="Player"
function player:IsA(class)return class=="Player"end
local function typeof(v)
 if type(v)=="table" and v.ClassName then return "Instance" end
 if type(v)=="table" and v.X and v.Y and v.Z then return "Vector3" end
 return type(v)
end
local home={Name="Pepper Patch",Position=vector(0,0,0),Size=vector(100,2,100)}
local outside={Name="Coconut Field",Position=vector(120,0,0),Size=vector(100,2,100)}
local function inBox(p,f)return math.abs(p.X-f.Position.X)<=f.Size.X/2 and math.abs(p.Z-f.Position.Z)<=f.Size.Z/2 end
local function getFieldAt(p) if inBox(p,home) then return home elseif inBox(p,outside) then return outside end end
local currentField=home
local function getHumanoid()return h end
local function distanceTo(position)return (position-root.Position).Magnitude end
local moveToCalls=0
rawset(h,"MoveTo",function(self,goal)
 moveToCalls+=1
 local d=vector(goal.X-root.Position.X,0,goal.Z-root.Position.Z)
 self.direction=d.Magnitude>.05 and d.Unit or Vector3.zero
end)
function smoothMovement:MoveTo(goal)h:MoveTo(goal)end
do
 local origFire=RunService.Heartbeat.Fire
 local waiters={}
 function RunService.Heartbeat:Wait()
  local co=coroutine.running()
  waiters[#waiters+1]=co
  return coroutine.yield()
 end
 function RunService.Heartbeat:Fire(...)
  origFire(self,...)
  local list=waiters;waiters={}
  for _,co in ipairs(list)do
   if coroutine.status(co)=="suspended" then
    local ok,err=coroutine.resume(co,true)
    if not ok then warn(err) end
   end
  end
 end
end
local gatheringPriorities={activeOptions={},ShouldPreempt=function()return false end}
local touchedMarks={}
local tracked={combococonuts={},coconuts={}}
local buffs={}
local function saveConfig()end
local availableFields={["Pepper Patch"]=true,["Coconut Field"]=true}
cfg.autofarm.field1="Pepper Patch"
cfg.coconutcombo={enabled=false,catchall=false,main="None",maxspeed=180}
state.activityStatus=1
local PhysicalProperties={new=function(d,f,e,fw,ew)return {Density=d,Friction=f,Elasticity=e,FrictionWeight=fw,ElasticityWeight=ew}end}
root.CurrentPhysicalProperties=PhysicalProperties.new(.7,.5,.2,1,1)
root.Massless=false
local TweenService={Create=function(_,inst,info,props)return {Play=function()end,Cancel=function()end,Destroy=function()end,Completed=signal()}end}
local gameApi={Events=Instance.new("Folder")}
local fx=Instance.new("RemoteEvent",gameApi.Events);fx.Name="LocalFX";fx.OnClientEvent=signal()
local collectObject
threads.Add = function(manager, threadId, callback, delaySeconds, ...)
	if manager.closed then return end
	local exclusive = (mondoHop and mondoHop.active and mondoHop) or (smoothMovement.comboController and smoothMovement.comboController.active and smoothMovement.comboController) or smoothMovement.showerController
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
	movementJobs={Autofarm=true,HiveClaimRetry=true,fasttween=true,face=true,walkspeed=true,autodig=true,
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

-- Atlas+ Coconut Combo controller: catches own combo from drop 1 (0x) onward and auto-exits when Main enters any combo.
local comboController = {records={}, byKey={}, chains={}, chainCount=0, disks={}, mainZones={}, skipZones={}, serial=0, active=false, comboPriority=false, ownPriority=false, privatePriority=false, status="Disabled", mainDebug="Main: Disabled"}
smoothMovement.comboController = comboController
fieldPositionPolicy.comboController = comboController

function comboController:FieldAt(position)
	local field=getFieldAt(position)
	if field then return field end
	if self.fieldFallback then return self.fieldFallback(position) end
end

function comboController:IsCatchAll()
	return cfg.coconutcombo and cfg.coconutcombo.catchall==true
end

function comboController:Managed()
	return cfg.coconutcombo and (cfg.coconutcombo.enabled==true or cfg.coconutcombo.catchall==true)
end

function comboController:MainChimeInterval()
	local n=tonumber(cfg.coconutcombo and cfg.coconutcombo.mainevery)
	if n==nil or n~=n then return 3 end
	return math.clamp(math.floor(n),0,10)
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

function comboController:IsMainAccount()
	local main=cfg.coconutcombo and cfg.coconutcombo.main
	return type(main)=="string" and main~="" and main~="None" and string.lower(localPlayer.Name)==string.lower(main)
end

function comboController:MainOwned(owner)
	local main=cfg.coconutcombo and cfg.coconutcombo.main
	return type(owner)=="string" and type(main)=="string" and main~="" and main~="None"
		and string.lower(owner)==string.lower(main)
end

function comboController:GetMainRoot()
	if self:IsMainAccount() then return nil end
	local main=cfg.coconutcombo and cfg.coconutcombo.main
	if type(main)~="string" or main=="" or main=="None" then return nil end
	local mainLower=string.lower(main)
	local matched
	for _,p in ipairs(getService("Players"):GetPlayers()) do
		if string.lower(p.Name)==mainLower then matched=p;break end
	end
	if not matched then
		for _,p in ipairs(getService("Players"):GetPlayers()) do
			if type(p.DisplayName)=="string" and string.lower(p.DisplayName)==mainLower then matched=p;break end
		end
	end
	if matched then
		local char=matched.Character
		local root=char and char:FindFirstChild("HumanoidRootPart")
		local h=char and char:FindFirstChildOfClass("Humanoid")
		if root and h and h.Health>0 then return root end
	end
	return nil
end

function comboController:Observe(effectName, data)
	if not self:Managed() or type(data)~="table" then return end
	local kicked=(effectName=="KickedComboCoconut")
	if effectName~="FallingCoconut" and not kicked then return end
	local now=os.clock()
	if kicked and typeof(data.Pos1)=="Vector3" then
		for _,r in ipairs(self.records) do
			if now-r.seen>0.05 and (r.position-data.Pos1).Magnitude<6 then
				r.deadline=math.min(r.deadline,now-0.26)
			end
		end
		for _,entry in pairs(self.disks or {}) do
			if entry.fallback and now-entry.fallback.seen>0.05 and (entry.fallback.position-data.Pos1).Magnitude<6 then
				entry.fallback.deadline=math.min(entry.fallback.deadline,now-0.26)
			end
		end
	end
	if (not kicked and not data.Combo) or data.Friendly==false then return end
	local goal=kicked and (data.GoalPos or data.EndPos or data.Pos2 or data.Pos) or data.Pos
	local dur=tonumber(data.FallDuration or data.Dur or data.Duration)
	if typeof(goal)~="Vector3" or not dur or dur~=dur or dur<=0 or dur>12 then
		self.effectStatus=kicked and "Combo kicked" or "Landing FX missing position or duration"
		return
	end
	local radius=math.clamp(tonumber(data.Radius or data.Rad) or 13,8,25)
	local id=data.ComboID or data.ChainID or data.FEID or data.ID
	local chainKey=(type(id)=="number" or type(id)=="string") and tostring(id) or nil
	local chain=chainKey and self.chains[chainKey]
	if chain and chain.expires<=now then chain=nil end
	local stack=type(data.Combo)=="number" and data.Combo or nil
	if stack and (stack~=stack or stack<0 or stack==math.huge) then stack=nil end
	local explicit=self:Owner(data.ComboOwner) or self:Owner(data.Owner)
	local private=(not kicked) and (stack==0)
	local owner=explicit or (not private and chain and chain.owner) or self:Owner(data.Player) or self:Owner(data.PID) or self:Owner(data.Target)
	if private and not owner then owner=localPlayer.Name end
	local runKey=owner and ("owner:"..string.lower(owner))
	local run=runKey and self.chains[runKey]
	local previous=(chain and chain.record) or (run and run.expires>now and run.record)
	if previous and previous.stack==stack and now-previous.seen<0.075 and (previous.position-goal).Magnitude<0.1 then return end
	if #self.records>=32 then return end
	if previous then
		previous.deadline=math.min(previous.deadline,now-0.26)
	end
	local field=self:FieldAt(goal)
	self.serial+=1
	local fieldName=field and field.Name or ""
	local key=string.format("%s:%.1f:%.1f:%.1f:%s:%d",string.lower(owner or "unknown"),goal.X,goal.Y,goal.Z,tostring(id or data.Points or 0),self.serial)
	local record={
		key=key,
		owner=owner,
		ownerLower=owner and string.lower(owner) or nil,
		position=goal,
		radius=radius,
		deadline=now+dur,
		private=private,
		stack=stack,
		field=fieldName,
		seen=now,
		chain=chainKey,
		mainInside=false,
	}
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
	self.lastOwner=owner or "Unknown"
	self.effectStatus=string.format("%s: %s | %s | %s",effectName,owner or "unknown",stack~=nil and (tostring(stack).."x") or "?x",fieldName)
end

function comboController:TrackDisk(disk)
	if not self:Managed() then return end
	self.disks=self.disks or {}
	if not self.disks[disk] then self.disks[disk]={seen=os.clock()} end
end

function comboController:ReadDiskStack(disk)
	if disk.Name==true then
		return type(disk.Combo)=="number" and disk.Combo or nil
	end
	local ok,text=pcall(function()
		local attach=disk:FindFirstChild("GuiAttach")
		local gui=attach and attach:FindFirstChild("Gui")
		local label=gui and gui:FindFirstChild("TextLabel")
		return label and label.Text
	end)
	if ok and type(text)=="string" then
		return tonumber(string.match(text,"%d+"))
	end
end

function comboController:SyncDisks(now)
	for target in pairs(self.atlasTargets and self:atlasTargets() or {}) do self:TrackDisk(target) end
	for disk,entry in pairs(self.disks or {}) do
		local virtual=(disk.Name==true)
		if (virtual and now>=(disk.ExpiresAt or entry.seen+12)) or (not virtual and not disk.Parent) or now-entry.seen>12 then
			if entry.record and not virtual then entry.record.deadline=math.min(entry.record.deadline,now-0.26) end
			if entry.fallback then entry.fallback.deadline=math.min(entry.fallback.deadline,now-0.26) end
			self.disks[disk]=nil
		elseif virtual or disk:FindFirstChild("GuiAttach") then
			local position=disk.Position
			local diskRadius=(not virtual and typeof(disk.Size)=="Vector3" and disk.Size.X>20) and math.clamp(disk.Size.X/2,13,20) or 13
			local match
			for _,r in ipairs(self.records) do
				if r.deadline+0.12>now and math.abs(r.seen-entry.seen)<2
					and (r.position-position).Magnitude<14
					and (not match or (r.position-position).Magnitude<(match.position-position).Magnitude) then match=r end
			end
			if match then
				match.position=position
				match.radius=diskRadius
				entry.record=match
				entry.fallback=nil
			elseif not entry.record then
				if not entry.fallback then
					local labelStack=self:ReadDiskStack(disk)
					local isPrivateZero=(labelStack==0)
					local field=self:FieldAt(position)
					local fieldName=field and field.Name or ""
					entry.fallback={
						key="disk:"..tostring(disk),
						owner=isPrivateZero and localPlayer.Name or nil,
						ownerLower=isPrivateZero and string.lower(localPlayer.Name) or nil,
						private=isPrivateZero,
						stack=labelStack,
						position=position,
						radius=diskRadius,
						field=fieldName,
						deadline=virtual and (disk.ExpiresAt or entry.seen+4) or (entry.seen+4),
						seen=entry.seen,
						mainInside=false,
					}
					self.effectStatus=isPrivateZero and ("Combo disk (0x) | "..fieldName) or ("Combo disk ("..tostring(labelStack or "?").."x) | "..fieldName)
				else
					entry.fallback.position=position
					entry.fallback.radius=diskRadius
					if entry.fallback.stack==nil then
						local labelStack=self:ReadDiskStack(disk)
						if labelStack~=nil then
							entry.fallback.stack=labelStack
							if labelStack==0 then
								entry.fallback.private=true
								entry.fallback.owner=localPlayer.Name
								entry.fallback.ownerLower=string.lower(localPlayer.Name)
								self.effectStatus="Combo disk (0x) | "..(entry.fallback.field or "")
							end
						end
					end
				end
			end
		end
	end
end

function comboController:ActiveCombos(now)
	local list={}
	for _,r in ipairs(self.records) do
		if r.deadline+0.12>now then list[#list+1]=r end
	end
	for _,entry in pairs(self.disks or {}) do
		if not entry.record and entry.fallback and entry.fallback.deadline+0.12>now then
			list[#list+1]=entry.fallback
		end
	end
	return list
end

function comboController:UpdateMainPresence(combos)
	table.clear(self.mainZones)
	if self:IsCatchAll() then
		for _,r in ipairs(combos) do r.mainInside=false end
		self.mainDebug="Catch All ON: Main rules ignored"
		return
	end
	if self:IsMainAccount() then
		for _,r in ipairs(combos) do r.mainInside=false end
		self.mainDebug=string.format("Main: this account (chime-in every %d)",self:MainChimeInterval())
		return
	end
	local main=cfg.coconutcombo and cfg.coconutcombo.main
	if type(main)~="string" or main=="" or main=="None" then
		for _,r in ipairs(combos) do r.mainInside=false end
		self.mainDebug="Main: NOT SET (set Main Account!)"
		return
	end
	local mainRoot=self:GetMainRoot()
	if not mainRoot then
		for _,r in ipairs(combos) do r.mainInside=false end
		self.mainDebug="Main: "..main.." not in server/dead"
		return
	end
	local vel=Vector3.zero
	pcall(function()
		local v=mainRoot.AssemblyLinearVelocity
		if typeof(v)=="Vector3" then vel=v end
	end)
	local lead=Vector3.new(vel.X,0,vel.Z)*0.25
	if lead.Magnitude>12 then lead=lead.Unit*12 end
	local leadPos=mainRoot.Position+lead
	local nearest,anyInside
	for _,r in ipairs(combos) do
		if r.private then
			r.mainInside=false
		elseif math.abs(mainRoot.Position.Y-r.position.Y)<=14 then
			local dx1,dz1=mainRoot.Position.X-r.position.X,mainRoot.Position.Z-r.position.Z
			local dx2,dz2=leadPos.X-r.position.X,leadPos.Z-r.position.Z
			local dist=math.min(math.sqrt(dx1*dx1+dz1*dz1),math.sqrt(dx2*dx2+dz2*dz2))
			if not nearest or dist<nearest then nearest=dist end
			local rad=r.radius or 13
			if dist<=rad+2.0 then
				r.mainInside=true
			elseif dist>rad+4.0 then
				r.mainInside=false
			end
		else
			r.mainInside=false
		end
		if r.mainInside then
			anyInside=true
			self.mainZones[#self.mainZones+1]=r
		end
	end
	if anyInside then
		self.mainDebug="Main: "..main.." INSIDE combo"
	elseif nearest then
		self.mainDebug=string.format("Main: %s | nearest combo %d studs",main,math.floor(nearest+0.5))
	else
		self.mainDebug="Main: "..main.." (no active combo)"
	end
end

function comboController:HelperNear(r)
	local playersService=getService("Players")
	if not playersService then return false end
	local rField=type(r.field)=="string" and r.field or ""
	for _,p in ipairs(playersService:GetPlayers()) do
		if p~=localPlayer then
			local char=p.Character
			local pRoot=char and char:FindFirstChild("HumanoidRootPart")
			local h=char and char:FindFirstChildOfClass("Humanoid")
			if pRoot and h and h.Health>0 then
				if rField~="" then
					local pf=self:FieldAt(pRoot.Position)
					if pf and pf.Name==rField then return true end
				elseif math.abs(pRoot.Position.Y-r.position.Y)<=25 then
					local dx,dz=pRoot.Position.X-r.position.X,pRoot.Position.Z-r.position.Z
					if dx*dx+dz*dz<=120*120 then return true end
				end
			end
		end
	end
	return false
end

function comboController:AnyOtherInside(r)
	local playersService=getService("Players")
	if not playersService then return false end
	local limit=(r.radius or 13)+1.0
	local limitSq=limit*limit
	for _,p in ipairs(playersService:GetPlayers()) do
		if p~=localPlayer then
			local char=p.Character
			local pRoot=char and char:FindFirstChild("HumanoidRootPart")
			local h=char and char:FindFirstChildOfClass("Humanoid")
			if pRoot and h and h.Health>0 and math.abs(pRoot.Position.Y-r.position.Y)<=14 then
				local dx,dz=pRoot.Position.X-r.position.X,pRoot.Position.Z-r.position.Z
				if dx*dx+dz*dz<=limitSq then return true end
			end
		end
	end
	return false
end

function comboController:MainShouldCatch(r,now)
	local every=self:MainChimeInterval()
	if every<=0 or r.private or r.stack==nil then return true end
	if r.stack%(every+1)==0 then return true end
	if not self:HelperNear(r) then return true end
	if r.deadline-now<=0.35 and not self:AnyOtherInside(r) then return true end
	return false
end

function comboController:UpdateSkipZones(combos,now)
	table.clear(self.skipZones)
	if not self:IsMainAccount() or self:IsCatchAll() then
		for _,r in ipairs(combos) do r.skipped=false end
		return
	end
	local localLower=string.lower(localPlayer.Name)
	for _,r in ipairs(combos) do
		if r.ownerLower==localLower and not r.private and r.deadline+0.12>now then
			r.skipped=not self:MainShouldCatch(r,now)
			if r.skipped then
				self.skipZones[#self.skipZones+1]=r
			end
		else
			r.skipped=false
		end
	end
end

function comboController:RestrictedZones()
	return self:IsMainAccount() and self.skipZones or self.mainZones
end

function comboController:IsRestrictedZone(position)
	if not self:Managed() or self:IsCatchAll() or typeof(position)~="Vector3" then return false end
	local now=os.clock()
	for _,z in ipairs(self:RestrictedZones()) do
		if z.deadline+0.12>now and math.abs(position.Y-z.position.Y)<=14 then
			local dx,dz=position.X-z.position.X,position.Z-z.position.Z
			local limit=(z.radius or 13)+3.0
			if dx*dx+dz*dz<limit*limit then return true end
		end
	end
	return false
end

function comboController:PathCrossesRestrictedZone(fromPos, toPos)
	if not self:Managed() or self:IsCatchAll() or typeof(fromPos)~="Vector3" or typeof(toPos)~="Vector3" then return false end
	local now=os.clock()
	local vx,vz=toPos.X-fromPos.X,toPos.Z-fromPos.Z
	local lenSq=vx*vx+vz*vz
	for _,z in ipairs(self:RestrictedZones()) do
		if z.deadline+0.12>now and math.abs(toPos.Y-z.position.Y)<=14 then
			local wx,wz=z.position.X-fromPos.X,z.position.Z-fromPos.Z
			local t=lenSq>1e-6 and math.clamp((wx*vx+wz*vz)/lenSq,0,1) or 0
			local cx,cz=fromPos.X+vx*t-z.position.X,fromPos.Z+vz*t-z.position.Z
			local limit=(z.radius or 13)+2.0
			if cx*cx+cz*cz<limit*limit then return true end
		end
	end
	return false
end

function comboController:BlocksMove(goal)
	if self.active or not self:Managed() or typeof(goal)~="Vector3" then return false end
	if self:IsRestrictedZone(goal) then return true end
	local char=localPlayer and localPlayer.Character
	local root=char and char:FindFirstChild("HumanoidRootPart")
	return root and self:PathCrossesRestrictedZone(root.Position,goal) or false
end

function comboController:PointInField(position, field)
	if field and field.Position and field.Size then
		local margin=2
		return math.abs(position.X-field.Position.X)<=math.max(1,field.Size.X/2-margin)
			and math.abs(position.Z-field.Position.Z)<=math.max(1,field.Size.Z/2-margin)
	end
	local f=self:FieldAt(position)
	return f~=nil and (not field or f.Name==field.Name)
end

function comboController:ComputeExitPosition(root, record, zones)
	local center=Vector3.new(record.position.X,root.Position.Y,record.position.Z)
	local delta=Vector3.new(root.Position.X-record.position.X,0,root.Position.Z-record.position.Z)
	local baseAngle
	if delta.Magnitude>0.1 then
		baseAngle=math.atan2(delta.Z,delta.X)
	else
		local mainRoot=self:GetMainRoot()
		local away=mainRoot and Vector3.new(root.Position.X-mainRoot.Position.X,0,root.Position.Z-mainRoot.Position.Z)
		baseAngle=(away and away.Magnitude>0.1) and math.atan2(away.Z,away.X) or 0
	end
	local myField=self:FieldAt(root.Position) or self:FieldAt(record.position)
	local rad=record.radius or 13
	local function clearOfAll(pt)
		for _,z in ipairs(zones) do
			if math.abs(pt.Y-z.position.Y)<=14 then
				local dx,dz=pt.X-z.position.X,pt.Z-z.position.Z
				local limit=(z.radius or 13)+3.0
				if dx*dx+dz*dz<limit*limit then return false end
			end
		end
		return true
	end
	local bestAny,bestAnyDist
	for _,exitRadius in ipairs({rad+6,rad+10}) do
		local bestInField,bestInFieldDist
		for i=0,11 do
			local angle=baseAngle+i*(math.pi/6)
			local pt=center+Vector3.new(math.cos(angle)*exitRadius,0,math.sin(angle)*exitRadius)
			if clearOfAll(pt) then
				local moveDist=(pt-root.Position).Magnitude
				if self:PointInField(pt,myField) and (not bestInField or moveDist<bestInFieldDist) then
					bestInField,bestInFieldDist=pt,moveDist
				end
				if not bestAny or moveDist<bestAnyDist then
					bestAny,bestAnyDist=pt,moveDist
				end
			end
		end
		if bestInField then return bestInField end
	end
	if bestAny then return bestAny end
	return center+Vector3.new(math.cos(baseAngle)*(rad+6),0,math.sin(baseAngle)*(rad+6))
end

function comboController:OwnComboLanding(root, combos, now)
	local localLower=string.lower(localPlayer.Name)
	local myField=self:FieldAt(root.Position)
	local myFieldName=myField and myField.Name or ""
	local best
	for _,r in ipairs(combos) do
		if r.ownerLower==localLower and not r.mainInside and r.deadline+0.12>now and not self:IsRestrictedZone(r.position) then
			local dx,dz=r.position.X-root.Position.X,r.position.Z-root.Position.Z
			local dist=math.sqrt(dx*dx+dz*dz)
			local sameField=(myFieldName~="" and r.field==myFieldName)
			local nearPrivate=r.private and math.abs(r.position.Y-root.Position.Y)<=20 and dist<=160
			local nearSameElevation=(myFieldName=="" or r.field=="") and math.abs(r.position.Y-root.Position.Y)<=12 and dist<=150
			if sameField or nearPrivate or nearSameElevation then
				if not best or r.deadline<best.deadline or (r.deadline==best.deadline and r.private and not best.private) then
					best=r
				end
			end
		end
	end
	return best
end

function comboController:MainComboLanding(root, combos, now)
	if self:IsMainAccount() then return nil end
	local myField=self:FieldAt(root.Position)
	local myFieldName=myField and myField.Name or ""
	local best
	for _,r in ipairs(combos) do
		if not r.private and self:MainOwned(r.owner) and not r.mainInside and r.deadline+0.12>now and not self:IsRestrictedZone(r.position) then
			local dx,dz=r.position.X-root.Position.X,r.position.Z-root.Position.Z
			local dist=math.sqrt(dx*dx+dz*dz)
			local sameField=(myFieldName~="" and r.field==myFieldName)
			local nearSameElevation=(myFieldName=="" or r.field=="") and math.abs(r.position.Y-root.Position.Y)<=12 and dist<=150
			if sameField or nearSameElevation then
				if not best or r.deadline<best.deadline then best=r end
			end
		end
	end
	return best
end

function comboController:AnyFieldComboLanding(root, combos, now)
	local myField=self:FieldAt(root.Position)
	local myFieldName=myField and myField.Name or ""
	local best
	for _,r in ipairs(combos) do
		if r.deadline+0.12>now then
			local dx,dz=r.position.X-root.Position.X,r.position.Z-root.Position.Z
			local dist=math.sqrt(dx*dx+dz*dz)
			local sameField=(myFieldName~="" and r.field==myFieldName)
			local airborneInMyField=(myFieldName~="" and r.field=="" and math.abs(r.position.Y-root.Position.Y)<=12 and dist<=150)
			local unmappedBoth=(myFieldName=="" and r.field=="" and math.abs(r.position.Y-root.Position.Y)<=12 and dist<=150)
			local nearPrivate=r.private and math.abs(r.position.Y-root.Position.Y)<=20 and dist<=160
			if sameField or airborneInMyField or unmappedBoth or nearPrivate then
				if not best or r.deadline<best.deadline or (r.deadline==best.deadline and r.private and not best.private) then
					best=r
				end
			end
		end
	end
	return best
end

function comboController:YieldLanding(root, now, ownCandidate)
	if self:IsCatchAll() then return nil end
	local zones=self:RestrictedZones()
	local breached
	for _,z in ipairs(zones) do
		if z.deadline+0.12>now and math.abs(root.Position.Y-z.position.Y)<=14 then
			local dx,dz=root.Position.X-z.position.X,root.Position.Z-z.position.Z
			if math.sqrt(dx*dx+dz*dz)<(z.radius or 13)+3.0 then
				if not breached or z.deadline<breached.deadline then breached=z end
			end
		end
	end
	if breached then
		local held=self.session and self.session.yieldJob
		if held and held.source==breached and not self:IsRestrictedZone(held.position) then
			return held
		end
		local exitPos=self:ComputeExitPosition(root,breached,zones)
		return {
			key="yield:"..breached.key,
			owner=breached.owner,
			position=exitPos,
			deadline=breached.deadline,
			field=breached.field or "",
			yielding=true,
			source=breached,
		}
	end
	if not ownCandidate then
		local held=self.session and self.session.yieldJob
		if held and held.source and held.source.deadline+0.12>now and (held.source.mainInside or held.source.skipped) then
			local dx,dz=root.Position.X-held.source.position.X,root.Position.Z-held.source.position.Z
			local clearDist=(held.source.radius or 13)+5.0
			if dx*dx+dz*dz<clearDist*clearDist then
				return held
			end
		end
	end
end

function comboController:TravelBlocked()
	if mondoHop and mondoHop.active then return true end
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
	if not state.stop and self.awaitLanding and localPlayer.Character==lock.character then pcall(self.awaitLanding) end
	if self.taskTravel==lock then self.taskTravel=nil end
	if not result[1] then error(result[2],0) end
	return table.unpack(result,2,result.n)
end

function comboController:Available(bypassActivity)
	if self:TravelBlocked() then return false end
	local bypass=(bypassActivity==true) or (self.session~=nil and (self.session.yieldJob~=nil or self.session.catchAll==true))
	local focused=bypass or self.comboPriority or self.ownPriority
	if self.closed or state.stop or (showerController.active and not focused) then return false end
	local char = localPlayer.Character
	local h = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not h or not root or h.Health <= 0 then return false end
	if not bypass and cfg.autofarm.enabled and (state.activityStatus ~= 1 or state.fasttween) then return false end
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
	threads:Cancel("comboAtlasCatch")
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
	if smoothMovement then smoothMovement.goal=nil end
	self.status=reason or "Waiting for combo"
	showerController:ResumeOthers()
end

function comboController:Begin(job, h, root)
	fieldPositionPolicy:ReleaseIdle()
	meteorMovement:Release()
	if self.session and self.session.key == job.key then return self.session end
	self:Finish("Changing combo landing")
	if showerController.active or self.closed or self:TravelBlocked() then return end
	local env = type(getgenv)=="function" and getgenv() or _G
	local key = "AtlasTemporaryPMS_" .. localPlayer.UserId
	local s = {key=job.key,h=h,root=root,originalSpeed=h.WalkSpeed,leaseKey=key,lease={},previousLease=env[key],direction=Vector3.zero,speed=0,yieldJob=job.yielding and job or nil,catchAll=job.catchAll==true}
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
	if not self.atlasCatch or s.speed==0 or s.yieldJob then s.h:Move(s.direction,false) end
end

function comboController:Tick()
	if mondoHop and mondoHop.active then self:Finish("Mondo Hop priority");return end
	local now=os.clock()
	for key,chain in pairs(self.chains) do
		if chain.expires<=now then self.chains[key]=nil;self.chainCount-=1 end
	end
	for i=#self.records,1,-1 do
		local r=self.records[i]
		if now>r.deadline+0.25 then
			if self.byKey[r.key]==r then self.byKey[r.key]=nil end
			table.remove(self.records,i)
		end
	end
	if not self:Managed() then
		table.clear(self.mainZones)
		table.clear(self.skipZones)
		self.mainDebug="Main: Disabled"
		self.ownPriority,self.comboPriority,self.privatePriority=false,false,false
		self:Finish("Disabled")
		return
	end
	if self:TravelBlocked() then
		table.clear(self.mainZones)
		table.clear(self.skipZones)
		self.ownPriority,self.comboPriority,self.privatePriority=false,false,false
		self:Finish("Task travel protected; combo movement deferred")
		return
	end
	local character=localPlayer.Character
	local root=character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		table.clear(self.mainZones)
		table.clear(self.skipZones)
		self.ownPriority,self.comboPriority,self.privatePriority=false,false,false
		self:Finish("No character")
		return
	end
	self:SyncDisks(now)
	local combos=self:ActiveCombos(now)
	self:UpdateMainPresence(combos)
	self:UpdateSkipZones(combos,now)
	local catchAll=self:IsCatchAll()
	local catchJob=catchAll and self:AnyFieldComboLanding(root,combos,now) or (self:OwnComboLanding(root,combos,now) or self:MainComboLanding(root,combos,now))
	local yieldJob=catchAll and nil or self:YieldLanding(root,now,catchJob)
	local job=yieldJob or catchJob
	if job and catchAll and not job.yielding then job.catchAll=true end
	self.privatePriority=(job~=nil and job==catchJob and catchJob.private==true)
	self.ownPriority=(job~=nil)
	self.comboPriority=(job~=nil)
	if job and showerController.active and showerController.cancel then showerController.cancel("Coconut Combo has priority") end
	local available,h,activeRoot=self:Available((job and job.yielding==true) or (catchAll and job~=nil))
	if not available then self:Finish("Busy with another activity");return end
	if self.session and (self.session.root~=activeRoot or self.session.h~=h) then self:Finish("Character changed") end
	if not job then
		local reason
		if #self.skipZones>0 then
			local firstSkip
			for _,z in ipairs(self.skipZones) do
				if not firstSkip or z.deadline<firstSkip.deadline then firstSkip=z end
			end
			local sText=firstSkip and firstSkip.stack~=nil and tostring(firstSkip.stack) or "?"
			reason=string.format("Letting alts catch own combo (%sx) | chime-in every %d",sText,self:MainChimeInterval())
		else
			reason=(#self.mainZones>0) and "Clear of Main's combo" or "Waiting for combo"
		end
		self:Finish(reason)
		return
	end
	local s=self:Begin(job,h,activeRoot)
	if not s then return end
	local delta=Vector3.new(job.position.X-activeRoot.Position.X,0,job.position.Z-activeRoot.Position.Z)
	local d=delta.Magnitude
	local cap=math.max(180,tonumber(cfg.coconutcombo.maxspeed) or 180)
	local elapsed=now-(s.lastUpdate or (now-1/30))
	s.lastUpdate=now
	s.speed=d>0.5 and math.min(cap,d/math.max(0.05,elapsed+1/60)) or 0
	s.direction=d>0.5 and delta.Unit or Vector3.zero
	if d<=0.5 then
		local v=activeRoot.AssemblyLinearVelocity
		activeRoot.AssemblyLinearVelocity=Vector3.new(0,v.Y,0)
		activeRoot.AssemblyAngularVelocity=Vector3.zero
	end
	s.yieldJob=job.yielding and job or nil
	s.target=s.target or {Name=true}
	s.target.Position,s.target.ExpiresAt=job.position,job.deadline
	self:Drive(s)
	if self.atlasCatch and not job.yielding and not threads:Get("comboAtlasCatch") then
		threads:Add("comboAtlasCatch",function()self.atlasCatch(s.target,s)end)
	end
	if job.yielding then
		if self:IsMainAccount() or (job.source and job.source.skipped) then
			self.status=string.format("Leaving own combo for alts | %.0f PMS",s.speed)
		else
			self.status=string.format("Exiting combo for %s | %.0f PMS",tostring(cfg.coconutcombo.main),s.speed)
		end
	else
		local stackText=job.stack~=nil and (tostring(job.stack).."x") or "?"
		local isOwn=job.ownerLower==string.lower(localPlayer.Name)
		local label=isOwn and "own" or tostring(job.owner or (catchAll and "field" or cfg.coconutcombo.main))
		self.status=string.format("Catching %s combo (%s) | %.0f PMS",label,stackText,s.speed)
	end
end

function comboController:Configure()
	self:Finish("Settings changed")
	table.clear(self.mainZones)
	table.clear(self.skipZones)
	if not self:Managed() then self.mainDebug="Main: Disabled" end
	if self:Managed() and self.installObserver then self:installObserver() end
end

function comboController:Start()
	if self.started then return end
	self.started=true
	local fx=gameApi.Events and gameApi.Events:FindFirstChild("LocalFX")
	if fx and fx:IsA("RemoteEvent") then
		connections:Add("comboComboFX",fx.OnClientEvent:Connect(function(name,data)
			if type(data)=="table" then pcall(function()self:Observe(name,data)end) end
		end))
		self.observesRemote=true
	end
	local elapsed,uiElapsed=0,0
	connections:Add("comboComboTick",RunService.Heartbeat:Connect(function(dt)
		local hasActivity=self.active or #self.records>0 or (self.disks and next(self.disks)~=nil)
		elapsed+=dt
		if not hasActivity and elapsed<0.03 then return end
		elapsed=0
		local ok,err=pcall(function()self:Tick()end)
		if not ok then self:Finish("Combo movement stopped by error");self.status=tostring(err) end
		uiElapsed+=dt
		if uiElapsed>=0.1 then
			uiElapsed=0
			if self.statusLabel then self.statusLabel.Text="Combo: "..self.status end
			if self.mainLabel then self.mainLabel.Text=self.mainDebug end
			if self.effectLabel then self.effectLabel.Text="Tracking: "..(self.effectStatus or "waiting for combo") end
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
	connections:Cancel("comboComboTick")
	connections:Cancel("comboComboFX")
	connections:Cancel("comboPlayerAdded")
	self:Finish("Unloaded")
	if self.disks then table.clear(self.disks) end
	self.atlasTargets=nil
	self.taskTravel=nil
	table.clear(self.records);table.clear(self.byKey);table.clear(self.chains);table.clear(self.mainZones);table.clear(self.skipZones);self.chainCount=0
	self.mainDebug="Main: Disabled"
end

function comboController:BuildMenu(tab)
	local folder=tab.AddFolder("Coconut Combo")
	folder.AddSwitch("Enable Coconut Combo",function()self:Configure()end,"coconutcombo","enabled")
	folder.AddSwitch("Catch All Combos in Field",function()self:Configure()end,"coconutcombo","catchall",{Tooltip="Catches every combo in your current field regardless of owner and ignores Main Account exit rules (for Coconut Field alts)."})
	local playersService=getService("Players")
	local names,seen={"None"},{None=true}
	local savedMain=cfg.coconutcombo.main
	if type(savedMain)=="string" and savedMain~="" and not seen[savedMain] then
		seen[savedMain]=true
		names[#names+1]=savedMain
	end
	for _,p in ipairs(playersService:GetPlayers()) do
		if p and type(p.Name)=="string" and not seen[p.Name] then
			seen[p.Name]=true
			names[#names+1]=p.Name
		end
	end
	local mainDropdown=folder.AddDropdown("Main Account",names,nil,function()self:Configure()end,"coconutcombo","main")
	local initialMain=(type(savedMain)=="string" and savedMain~="" and savedMain~="None") and savedMain or nil
	folder.AddTextBox("Main Account Username",function(text)
		local trimmed=string.match(tostring(text or ""),"^%s*(.-)%s*$")
		local value=(trimmed and trimmed~="") and trimmed or "None"
		cfg.coconutcombo.main=value
		if not seen[value] then
			seen[value]=true
			pcall(function() mainDropdown.Add(value) end)
		end
		pcall(function() mainDropdown.SetValue(value) end)
		saveConfig()
		self:Configure()
	end,initialMain,true)
	if playersService.PlayerAdded then
		connections:Add("comboPlayerAdded",playersService.PlayerAdded:Connect(function(player)
			local pname=player and player.Name
			if type(pname)=="string" and pname~="" and not seen[pname] then
				seen[pname]=true
				pcall(function() mainDropdown.Add(pname) end)
			end
		end))
	end
	folder.AddSlider("Fast Combo Maximum Speed",function()self:Configure()end,30,240,"coconutcombo","maxspeed",{Left=true})
	folder.AddSlider("Main: Alt Catches Between Chime-Ins",function()self:Configure()end,0,10,"coconutcombo","mainevery",{Left=true})
	self.statusLabel=folder.AddLabel("Combo: Disabled")
	self.mainLabel=folder.AddLabel(self.mainDebug or "Main: Disabled")
	self.effectLabel=folder.AddLabel("Tracking: waiting for combo")
	folder.AddLabel("Catches your own combo (0x+) and Main's combo (1x+) when Main isn't inside.")
	folder.AddLabel("Main: catches 0x + every (N+1)th drop (lets alts catch N drops in between).")
	folder.AddLabel("Exits any player's combo circle when Main steps inside and resumes farming.")
	folder.AddLabel("Coconut Field alts: turn ON Catch All Combos in Field to catch everything in that field.")
	folder.Toggle(true,true)
end

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
				if not comboSession and not fieldPositionPolicy:StrictAllowed(object.Position) then return true end
				if not comboSession and (comboController:IsRestrictedZone(object.Position) or comboController:PathCrossesRestrictedZone(getRootPart().Position, object.Position)) then return true end
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
comboController.atlasCatch=function(object,session)return collectObject(object,nil,.5,true,true,false,nil,nil,session)end
comboController:Start()
local startConnections=liveConnections
assert(comboController.observesRemote,"LocalFX remote observer not attached")

local function observe(x,z,id,owner,comboVal,dur)
 fx.OnClientEvent:Fire("FallingCoconut",{Friendly=true,Combo=comboVal~=nil and comboVal or 1,Pos=vector(x,3,z or 0),Dur=dur or 2,ID=id,ComboOwner=owner,Points=100,Radius=13})
end

-- Disabled controller ignores FX and does not move or block zones.
observe(20,0,"disabled",player,0)
comboController:Tick()
assert(not comboController.active and not comboController:IsRestrictedZone(vector(20,3,0)))

-- Test BuildMenu directly from atlasbss.lua.
Players.PlayerAdded=signal()
local folders,switches,dropdowns,textboxes,sliders={},{},{},{},{}
local addedToDropdown={}
local menuTab={AddFolder=function(name)
 folders[name]=true
 return {
  AddSwitch=function(name,cb,tbl,key)switches[name]={cb=cb,tbl=tbl,key=key}end,
  AddDropdown=function(name,items,_,cb,tbl,key)
   dropdowns[name]={items=table.clone(items),cb=cb,tbl=tbl,key=key,
    Add=function(v)addedToDropdown[#addedToDropdown+1]=v end,
    SetValue=function(v)dropdowns[name].value=v end}
   return dropdowns[name]
  end,
  AddTextBox=function(name,cb)textboxes[name]=cb;return {}end,
  AddSlider=function(name,cb,mn,mx,tbl,key)sliders[name]={min=mn,max=mx,tbl=tbl,key=key}end,
  AddLabel=function()return {Text=""}end,
  Toggle=function()end,
 }
end}
comboController:BuildMenu(menuTab)
assert(folders["Coconut Combo"] and not folders["Coconut Team"])
assert(switches["Enable Coconut Combo"] and switches["Catch All Combos in Field"] and dropdowns["Main Account"] and textboxes["Main Account Username"] and sliders["Fast Combo Maximum Speed"] and sliders["Main: Alt Catches Between Chime-Ins"])
assert(comboController.mainLabel~=nil,"main debug label missing")
textboxes["Main Account Username"]("  MainAccount  ")
assert(cfg.coconutcombo.main=="MainAccount" and dropdowns["Main Account"].value=="MainAccount")
Players.PlayerAdded:Fire({Name="JoinedLate"})
assert(table.find(addedToDropdown,"JoinedLate"))

-- Create MainAccount and AltTwo players in workspace.
local mainChar=Instance.new("Model",world)
local mainHumanoid=Instance.new("Humanoid",mainChar)
local mainRoot=Instance.new("Part",mainChar);mainRoot.Name="HumanoidRootPart";mainRoot.Position=vector(-45,3,0)
local mainPlayer={Name="MainAccount",Character=mainChar,UserId=900,ClassName="Player",IsA=function(_,c)return c=="Player"end}
local alt2Char=Instance.new("Model",world)
local alt2Humanoid=Instance.new("Humanoid",alt2Char)
local alt2Root=Instance.new("Part",alt2Char);alt2Root.Name="HumanoidRootPart";alt2Root.Position=vector(40,3,0)
local alt2Player={Name="AltTwo",Character=alt2Char,UserId=901,ClassName="Player",IsA=function(_,c)return c=="Player"end}
Players.list={player,mainPlayer,alt2Player}

-- Configure this client as AltOne.
player.Name="AltOne"
cfg.coconutcombo={enabled=true,main="MainAccount",maxspeed=180}
comboController:Configure()
root.Position=vector(0,3,0)

-- 1. Catch own combo from drop 1 (0x private) onward (1x, 2x, 3x) with exact fast movement.
fx.OnClientEvent:Fire("FallingCoconut",{Friendly=true,Combo=0,Pos=vector(25,3,0),Dur=2,ID="own-chain",Points=100,Radius=13})
comboController:Tick()
assert(comboController.active and comboController.privatePriority,"alt missed private 0x own drop")
assert(root.CustomPhysicalProperties.Density==7 and root.Massless==false,"exact 10x root density was not applied")
assert(not controls.controlsEnabled,"controls were not disabled during combo catch")
assert(not threads:Get("Autofarm") and threads:Get("Stats")==stats,"autofarm not paused or stats touched")
for _,fn in pairs(RunService.bound)do fn()end
assert(h.WalkSpeed>=180,"exact fast combo speed not applied")
for _=1,12 do step(0.03) end
assert(root.Position.X>20,"fast movement did not approach own 0x drop")

-- Even if Main stands near Alt's private 0x drop, Alt still catches its own 0x (Main cannot see 0x in BSS).
mainRoot.Position=vector(26,3,0)
comboController:Tick()
assert(comboController.active and comboController.privatePriority,"private 0x should not yield to Main")
mainRoot.Position=vector(-45,3,0)

-- Kick 0x -> 1x -> 2x -> 3x owned by AltOne (sequential catches + braking at center).
now+=0.1
fx.OnClientEvent:Fire("KickedComboCoconut",{Pos1=vector(25,3,0)})
observe(30,0,"own-chain",player,1,2)
comboController:Tick()
assert(comboController.active and not comboController.privatePriority,"alt did not catch own 1x drop")
root.Position=vector(30,3,0)
comboController:Tick()
for _,fn in pairs(RunService.bound)do fn()end
assert(h.WalkSpeed==0,"did not brake to 0 when centered under own coconut")

now+=0.1
fx.OnClientEvent:Fire("KickedComboCoconut",{Combo=2,Pos2=vector(15,3,0),Duration=1.8,ID="own-chain",Points=100})
comboController:Tick()
assert(comboController.active and math.abs(comboController.session.target.Position.X-15)<0.1,"alt missed own 2x drop via chain ownership")

-- 2. Main steps into AltOne's own active combo (2x) -> AltOne leaves it immediately using fast movement and resumes farming once clear!
root.Position=vector(16,3,0)
mainRoot.Position=vector(14,3,0) -- 1 stud from (15,3,0), well inside radius 13
comboController:Tick()
assert(comboController.active and comboController.session.yieldJob,"alt did not immediately switch to yield exit when Main stepped into alt's own combo")
assert(comboController:IsRestrictedZone(vector(15,3,0)),"Main-occupied combo center not marked restricted")
for _,fn in pairs(RunService.bound)do fn()end
assert(h.WalkSpeed>=180 and root.CustomPhysicalProperties.Density==7,"yield exit did not use exact fast movement + 10x density")
local exitTarget=comboController.session.yieldJob.position
assert((vector(exitTarget.X,0,exitTarget.Z)-vector(15,0,0)).Magnitude>=18,"exit target too close to combo circle")
for _=1,12 do step(0.03) end
assert((vector(root.Position.X,0,root.Position.Z)-vector(15,0,0)).Magnitude>=17,"alt did not exit outside Main-occupied combo circle")
assert(not comboController.active,"alt stayed frozen instead of releasing movement once clear")
assert(threads:Get("Autofarm")~=nil,"autofarm did not resume immediately after exiting Main's combo")
assert(h.WalkSpeed==40 and controls.controlsEnabled and root.CustomPhysicalProperties==nil,"movement/density not restored on resume")

-- While Main stays in/near the 2x circle (hysteresis <= 16), alt keeps farming safely without re-entering or crossing the circle.
mainRoot.Position=vector(15+15,3,0)
comboController:Tick()
assert(not comboController.active,"alt re-entered its 2x combo while Main stayed inside hysteresis")
assert(comboController:PathCrossesRestrictedZone(root.Position,vector(-10,3,0)),"path crossing through Main's combo was not blocked")
assert(not comboController:PathCrossesRestrictedZone(root.Position,root.Position+vector(10,0,5)),"safe same-side farm path was blocked")
local crossAborted=false
local crossTarget={Name=true,Position=vector(-10,3,0),Parent=workspace}
local crossCo=coroutine.create(function()crossAborted=collectObject(crossTarget,nil,5,false,true,false)end)
assert(coroutine.resume(crossCo) and crossAborted,"non-combo collectObject cut straight across Main-occupied combo circle")

-- Next drop (3x) lands elsewhere with Main NOT inside -> alt automatically continues catching its own combo!
now+=0.1
fx.OnClientEvent:Fire("KickedComboCoconut",{Pos1=vector(15,3,0)})
fx.OnClientEvent:Fire("KickedComboCoconut",{Combo=3,Pos2=vector(-10,3,0),Duration=1.8,ID="own-chain",Points=100})
comboController:Tick()
assert(comboController.active and not comboController.session.yieldJob and math.abs(comboController.session.target.Position.X-(-10))<0.1,"alt did not continue catching own 3x drop when Main stayed outside")
now+=0.1
fx.OnClientEvent:Fire("KickedComboCoconut",{Pos1=vector(-10,3,0)})
now+=0.3
comboController:Tick()
assert(not comboController.active,"kicked record remained active")
assert(h.WalkSpeed==40 and controls.controlsEnabled and root.CustomPhysicalProperties==nil and root.Massless==false,"Finish did not restore WalkSpeed/controls/density")
threads:Add("Autofarm",worker)

-- 2b. Yield uses h:Move directly without spawning comboAtlasCatch, velocity-lead triggers yield, BlocksMove guards non-combo moves, and mainDebug reports unset Main.
comboController:Finish("yield-behavior")
comboController.records={};comboController.byKey={};comboController.chains={};comboController.chainCount=0
cfg.coconutcombo={enabled=true,main="None",maxspeed=180}
comboController:Tick()
assert(comboController.mainDebug=="Main: NOT SET (set Main Account!)","unset mainDebug mismatch: "..tostring(comboController.mainDebug))
cfg.coconutcombo={enabled=true,main="MainAccount",maxspeed=180}
root.Position=vector(15,3,0)
mainRoot.Position=vector(37,3,0) -- 22 studs away from center (15,3,0), outside static rad+2=15
mainRoot.AssemblyLinearVelocity=vector(-48,0,0) -- 0.25s lead capped at 12 -> leadPos=(25,3,0) at 10 studs <= 15
observe(15,0,"lead-chain",player,2,2)
comboController:Tick()
assert(comboController.active and comboController.session.yieldJob,"velocity lead did not trigger Main-occupied yield")
assert(not threads:Get("comboAtlasCatch"),"yield exit must not spawn comboAtlasCatch")
assert(h.direction.Magnitude>0.9,"yield Drive did not call h:Move directly with atlasCatch set")
mainRoot.AssemblyLinearVelocity=Vector3.zero
assert(not comboController:BlocksMove(vector(15,3,0)),"BlocksMove must be false while comboController.active")
local savedYieldZone=comboController.mainZones[1]
comboController.active=false
comboController.mainZones={savedYieldZone}
root.Position=vector(-20,3,0) -- clear outside circle centered at 15 (limit 16 -> [-1..31])
assert(comboController:BlocksMove(vector(15,3,0)),"BlocksMove did not block point inside Main zone")
assert(comboController:BlocksMove(vector(40,3,0)),"BlocksMove did not block path crossing Main zone")
assert(comboController:BlocksMove(vector(-30,3,0))==false,"BlocksMove blocked safe outside move")
comboController:Finish("yield-behavior-end")
comboController.records={};comboController.byKey={};comboController.chains={};comboController.chainCount=0
mainRoot.Position=vector(-45,3,0)
root.Position=vector(0,3,0)

-- 3. Ignores other alts' combos; catches Main's combo (1x+) when Main isn't inside, and exits ANY player's combo when Main enters.
mainRoot.Position=vector(40,3,0)
root.Position=vector(0,3,0)
observe(10,0,"alt2-chain",alt2Player,1,2)
comboController:Tick()
assert(not comboController.active and not comboController:IsRestrictedZone(vector(10,3,0)),"alt chased another alt's combo")

-- Alt is standing inside AltTwo's combo circle when Main steps into AltTwo's combo.
root.Position=vector(12,3,0)
mainRoot.Position=vector(8,3,0)
comboController:Tick()
assert(comboController.active and comboController.session.yieldJob,"alt did not exit AltTwo's combo when Main entered")
-- Normal non-combo collectObject aborts immediately on restricted target inside Main's occupied circle.
local aborted=false
local nonComboTarget={Name=true,Position=vector(10,3,0),Parent=workspace}
local t=coroutine.create(function()aborted=collectObject(nonComboTarget,nil,5,false,true,false)end)
assert(coroutine.resume(t))
assert(aborted,"normal collectObject walked into Main-occupied combo zone")

-- Expire AltTwo's combo and test Main's combo when Main is NOT doing its own combo.
now+=0.1
fx.OnClientEvent:Fire("KickedComboCoconut",{Pos1=vector(10,3,0)})
mainRoot.Position=vector(40,3,0)
root.Position=vector(0,3,0)
observe(-20,0,"main-chain",mainPlayer,1,2)
comboController:Tick()
assert(comboController.active and not comboController.session.yieldJob and math.abs(comboController.session.target.Position.X-(-20))<0.1,"alt did not catch Main's 1x combo when Main was not inside")
for _,fn in pairs(RunService.bound)do fn()end
assert(h.WalkSpeed>=180 and root.CustomPhysicalProperties.Density==7,"catching Main's combo did not use exact fast movement + 10x density")

-- Main steps into Main's 1x combo -> alt exits and resumes farming once clear.
threads:Add("Autofarm",worker)
root.Position=vector(-19,3,0)
mainRoot.Position=vector(-18,3,0)
comboController:Tick()
assert(comboController.active and comboController.session.yieldJob and comboController.session.yieldJob.owner=="MainAccount","alt did not exit Main's combo when Main stood inside")
for _=1,12 do step(0.03) end
assert(not comboController.active and threads:Get("Autofarm")~=nil,"alt did not resume farming after exiting Main's combo")

-- Next drops (2x and 3x) of Main's combo with Main NOT inside -> alt continues catching them!
now+=0.1
fx.OnClientEvent:Fire("KickedComboCoconut",{Pos1=vector(-20,3,0)})
mainRoot.Position=vector(-40,3,0)
fx.OnClientEvent:Fire("KickedComboCoconut",{Combo=2,Pos2=vector(20,3,0),Duration=1.8,ID="main-chain",Points=100})
comboController:Tick()
assert(comboController.active and not comboController.session.yieldJob and math.abs(comboController.session.target.Position.X-20)<0.1,"alt did not continue catching Main's 2x drop")
now+=0.1
fx.OnClientEvent:Fire("KickedComboCoconut",{Pos1=vector(20,3,0)})
fx.OnClientEvent:Fire("KickedComboCoconut",{Combo=3,Pos2=vector(5,3,0),Duration=1.8,ID="main-chain",Points=100})
comboController:Tick()
assert(comboController.active and not comboController.session.yieldJob and math.abs(comboController.session.target.Position.X-5)<0.1,"alt did not continue catching Main's 3x drop")

-- Own combo still takes priority over Main's combo if both fall in the field at once.
observe(25,0,"alt1-prio",player,1,2)
comboController:Tick()
assert(comboController.active and math.abs(comboController.session.target.Position.X-25)<0.1,"own combo did not take priority over Main's combo")
now+=0.1
fx.OnClientEvent:Fire("KickedComboCoconut",{Pos1=vector(25,3,0)})
fx.OnClientEvent:Fire("KickedComboCoconut",{Pos1=vector(5,3,0)})

-- 4. Unowned WarningDisk fallback (with GuiAttach): catches 0x, ignores >= 1x, exits when Main enters.
comboController:Finish("disk fallback test")
comboController.records={};comboController.byKey={};comboController.chains={};comboController.chainCount=0;comboController.disks={}
mainRoot.Position=vector(-45,3,0)
root.Position=vector(0,3,0)
local disk=Instance.new("Part",workspace);disk.Name="WarningDisk";disk.Position=vector(5,3,0);disk.Size=vector(26,0.5,26)
local attach=Instance.new("Attachment",disk);attach.Name="GuiAttach"
local gui=Instance.new("BillboardGui",attach);gui.Name="Gui"
local textLabel=Instance.new("TextLabel",gui);textLabel.Name="TextLabel";textLabel.Text="3"
comboController:TrackDisk(disk)
comboController:Tick()
assert(not comboController.active,"alt chased unowned 3x WarningDisk")
root.Position=vector(6,3,0);mainRoot.Position=vector(4,3,0)
comboController:Tick()
assert(comboController.active and comboController.session.yieldJob,"alt did not exit unowned WarningDisk when Main stepped inside")
disk.Parent=nil;now+=0.3;comboController:Tick()
assert(not comboController.active,"removed WarningDisk stayed active")

-- 0x unowned disk triggers private self-catch.
local zeroDisk=Instance.new("Part",workspace);zeroDisk.Name="WarningDisk";zeroDisk.Position=vector(5,3,0);zeroDisk.Size=vector(26,0.5,26)
local zAttach=Instance.new("Attachment",zeroDisk);zAttach.Name="GuiAttach"
local zGui=Instance.new("BillboardGui",zAttach);zGui.Name="Gui"
local zLabel=Instance.new("TextLabel",zGui);zLabel.Name="TextLabel";zLabel.Text="0"
comboController:TrackDisk(zeroDisk)
mainRoot.Position=vector(-45,3,0);root.Position=vector(0,3,0)
comboController:Tick()
assert(comboController.active and comboController.privatePriority,"0x WarningDisk fallback was not caught")
zeroDisk.Parent=nil;comboController:Finish("reset");comboController.disks={}

-- 5. Field-edge safe exit & overlapping Main-occupied combos.
comboController.records={};comboController.byKey={};comboController.chains={};comboController.chainCount=0
root.Position=vector(44,3,0) -- Pepper Patch is [-50, 50] on X and Z
mainRoot.Position=vector(42,3,0)
observe(42,0,"edge-combo",alt2Player,2,2)
comboController:Tick()
assert(comboController.active and comboController.session.yieldJob)
local edgeExit=comboController.session.yieldJob.position
assert(comboController:PointInField(edgeExit,home),"exit went off Pepper Patch boundary: X="..tostring(edgeExit.X))

comboController.records={};comboController.byKey={};comboController.chains={};comboController.chainCount=0
observe(0,0,"overlap-1",alt2Player,1,2)
observe(20,0,"overlap-2",mainPlayer,1,2)
root.Position=vector(10,3,0)
mainRoot.Position=vector(10,3,0) -- inside BOTH circles!
comboController:Tick()
local overlapExit=comboController.session.yieldJob.position
assert(not comboController:IsRestrictedZone(overlapExit),"exit landed inside second Main-occupied combo")

-- 6. Main Account self-immunity (when mainevery=0): Main catches its own combo from 0x onward and NEVER exits for itself.
comboController:Finish("main account test")
comboController.records={};comboController.byKey={};comboController.chains={};comboController.chainCount=0
player.Name="MainAccount"
mainRoot.Position=vector(-100,3,0) -- move stale mainRoot stub out of field since player IS MainAccount here
cfg.coconutcombo={enabled=true,main="MainAccount",mainevery=0,maxspeed=180}
root.Position=vector(0,3,0)
fx.OnClientEvent:Fire("FallingCoconut",{Friendly=true,Combo=0,Pos=vector(20,3,0),Dur=2,ID="main-self",ComboOwner=player,Points=100,Radius=13})
comboController:Tick()
assert(comboController.active and comboController.privatePriority and not comboController.session.yieldJob,"Main missed own 0x")
root.Position=vector(25,3,0)
observe(25,0,"main-self",player,1,2)
comboController:Tick()
assert(comboController.active and not comboController.session.yieldJob and not comboController:IsRestrictedZone(vector(25,3,0)),"Main yielded to itself with mainevery=0")

-- 6a. Main own-combo cadence (default mainevery=3): catches 0x and 4x, skips 1..3 for nearby helpers (and yields out if inside), catches solo, and rescues at deadline.
comboController:Finish("main cadence test")
comboController.records={};comboController.byKey={};comboController.chains={};comboController.chainCount=0
cfg.coconutcombo={enabled=true,main="MainAccount",mainevery=3,maxspeed=180}
alt2Root.Position=vector(40,3,0) -- inside Pepper Patch helper zone
root.Position=vector(0,3,0)
fx.OnClientEvent:Fire("FallingCoconut",{Friendly=true,Combo=0,Pos=vector(10,3,0),Dur=2,ID="cadence",ComboOwner=player,Points=100,Radius=13})
comboController:Tick()
assert(comboController.active and comboController.privatePriority,"Main missed own 0x under cadence")
-- Stacks 1, 2, 3 skipped while alt2 is in Pepper Patch; if Main is standing inside skipped 1x, Main yields out!
now+=0.1
fx.OnClientEvent:Fire("KickedComboCoconut",{Pos1=vector(10,3,0)})
root.Position=vector(15,3,0) -- inside 1x circle
observe(15,0,"cadence",player,1,2)
comboController:Tick()
assert(comboController.active and comboController.session.yieldJob,"Main did not yield out of skipped 1x combo")
assert(comboController:IsRestrictedZone(vector(15,3,0)),"Main's skipped 1x zone was not marked restricted")
for _=1,12 do step(0.03) end
assert(not comboController.active and string.find(comboController.status,"Letting alts catch",1,true),"Main did not report letting alts catch after yielding")
root.Position=vector(0,3,0)
for _,sk in ipairs({2,3}) do
 now+=0.1
 fx.OnClientEvent:Fire("KickedComboCoconut",{Pos1=vector(15,3,0)})
 observe(20,0,"cadence",player,sk,2)
 comboController:Tick()
 assert(not comboController.active,"Main caught skipped stack "..tostring(sk))
end
-- Stack 4 (4 % 4 == 0) -> Main chimes in!
now+=0.1
fx.OnClientEvent:Fire("KickedComboCoconut",{Pos1=vector(20,3,0)})
observe(20,0,"cadence",player,4,2)
comboController:Tick()
assert(comboController.active and not comboController.session.yieldJob,"Main did not chime in on stack 4")
-- Solo fallback: no helper in field -> Main catches stack 1!
comboController:Finish("solo cadence")
comboController.records={};comboController.byKey={};comboController.chains={};comboController.chainCount=0
alt2Root.Position=vector(135,3,0) -- moved to Coconut Field (no helper in Pepper Patch)
root.Position=vector(0,3,0)
observe(15,0,"solo-chain",player,1,2)
comboController:Tick()
assert(comboController.active and not comboController.session.yieldJob,"Main skipped 1x when solo in field")
-- Rescue at deadline-0.3s when helper is in field but nobody inside circle:
comboController:Finish("rescue cadence")
comboController.records={};comboController.byKey={};comboController.chains={};comboController.chainCount=0
alt2Root.Position=vector(40,3,0) -- back in Pepper Patch, outside circle (15,0)
root.Position=vector(0,3,0)
observe(15,0,"rescue-chain",player,1,0.3)
comboController:Tick()
assert(comboController.active and not comboController.session.yieldJob,"Main did not rescue stack 1 at deadline<=0.35 with nobody inside")

-- 6b. Catch All Combos in Field (Coconut Field alts): catches everything in current field regardless of owner/Main/activity.
comboController:Finish("catchall setup")
comboController.records={};comboController.byKey={};comboController.chains={};comboController.chainCount=0;comboController.disks={}
player.Name="CoconutAlt1"
cfg.coconutcombo={enabled=false,catchall=true,main="MainAccount",maxspeed=180}
cfg.autofarm.enabled=true
state.activityStatus=3 -- works regardless of activityStatus (only stops for TravelBlocked / state.stop / mondoHop)
root.Position=vector(100,3,0) -- inside Coconut Field [70, 170]
mainRoot.Position=vector(135,3,0)

-- Catches AltTwo's combo in Coconut Field with exact fast movement + 10x density.
observe(130,0,"coco-alt2",alt2Player,2,2)
comboController:Tick()
assert(comboController.active and not comboController.session.yieldJob,"catchall missed AltTwo's combo in Coconut Field")
for _,fn in pairs(RunService.bound)do fn()end
assert(h.WalkSpeed>=180 and root.CustomPhysicalProperties.Density==7,"catchall did not use exact fast movement + 10x density")

-- Catches MainAccount's combo in Coconut Field EVEN with MainAccount standing inside it (ignores Main exit/restricted rules).
now+=0.1
fx.OnClientEvent:Fire("KickedComboCoconut",{Pos1=vector(130,3,0)})
observe(135,0,"coco-main",mainPlayer,3,2)
comboController:Tick()
assert(comboController.active and not comboController.session.yieldJob,"catchall yielded or skipped Main's combo in Coconut Field")
assert(not comboController:IsRestrictedZone(vector(135,3,0)) and not comboController:PathCrossesRestrictedZone(vector(100,3,0),vector(150,3,0)),"catchall applied restricted zones")

-- Catches own 0x combo and unowned 3x WarningDisk in Coconut Field.
now+=0.1
fx.OnClientEvent:Fire("KickedComboCoconut",{Pos1=vector(135,3,0)})
fx.OnClientEvent:Fire("FallingCoconut",{Friendly=true,Combo=0,Pos=vector(115,3,0),Dur=2,ID="coco-own0",Points=100,Radius=13})
comboController:Tick()
assert(comboController.active and comboController.privatePriority,"catchall missed own 0x in Coconut Field")

now+=0.1
fx.OnClientEvent:Fire("KickedComboCoconut",{Pos1=vector(115,3,0)})
local cocoDisk=Instance.new("Part",workspace);cocoDisk.Name="WarningDisk";cocoDisk.Position=vector(125,3,0);cocoDisk.Size=vector(26,0.5,26)
local cAttach=Instance.new("Attachment",cocoDisk);cAttach.Name="GuiAttach"
local cGui=Instance.new("BillboardGui",cAttach);cGui.Name="Gui"
local cLabel=Instance.new("TextLabel",cGui);cLabel.Name="TextLabel";cLabel.Text="3"
comboController:TrackDisk(cocoDisk)
comboController:Tick()
assert(comboController.active and not comboController.session.yieldJob,"catchall missed unowned 3x WarningDisk in Coconut Field")
cocoDisk.Parent=nil;now+=0.3;comboController:Tick()

-- Ignores Pepper Patch combo while standing in Coconut Field, and ignores Coconut Field combo while at hive (no field).
comboController.records={};comboController.byKey={};comboController.chains={};comboController.chainCount=0;comboController.disks={}
observe(10,0,"pepper-drop",alt2Player,1,2)
comboController:Tick()
assert(not comboController.active,"Coconut Field alt left Coconut Field for Pepper Patch combo")
observe(125,0,"coco-only",alt2Player,1,2)
root.Position=vector(-100,3,0) -- outside any field (e.g. at hive)
comboController:Tick()
assert(not comboController.active,"alt at hive pulled into Coconut Field combo")
state.activityStatus=1

-- 7. Live FX fixture replay (combo_live_trace.json).

comboController:Finish("live replay")
comboController.records={};comboController.byKey={};comboController.chains={};comboController.chainCount=0;comboController.disks={}
local liveOwner={ClassName="Player",Name="MainAccount",IsA=function(_,c)return c=="Player"end}
local realEvents={{time=3474.996,effect="KickedComboCoconut",data={Pos1=vector(-490.0,123.2,546.0),Points=100,Rad=13}},{time=3474.996,effect="FallingCoconut",data={Combo=31,Radius=13,Dur=0.9149405464557394,Friendly=true,Points=100,ComboOwner=liveOwner,Pos=vector(-458.0,123.2,554.0)}},{time=3475.927,effect="KickedComboCoconut",data={Pos1=vector(-458.0,123.2,554.0),Points=100,Rad=13}},{time=3475.927,effect="FallingCoconut",data={Combo=32,Radius=13,Dur=0.8835641933074436,Friendly=true,Points=100,ComboOwner=liveOwner,Pos=vector(-498.0,123.2,570.0)}},{time=3476.827,effect="KickedComboCoconut",data={Pos1=vector(-498.0,123.2,570.0),Points=100,Rad=13}},{time=3476.827,effect="FallingCoconut",data={Combo=33,Radius=13,Dur=0.8527900328486191,Friendly=true,Points=100,ComboOwner=liveOwner,Pos=vector(-518.0,123.2,538.0)}},{time=3477.694,effect="KickedComboCoconut",data={Pos1=vector(-518.0,123.2,538.0),Points=100,Rad=13}},{time=3477.694,effect="FallingCoconut",data={Combo=34,Radius=13,Dur=0.8225887698553866,Friendly=true,Points=100,ComboOwner=liveOwner,Pos=vector(-466.0,123.2,534.0)}},{time=3478.51,effect="KickedComboCoconut",data={Pos1=vector(-466.0,123.2,534.0),Points=100,Rad=13}},{time=3478.51,effect="FallingCoconut",data={Combo=35,Radius=13,Dur=0.7929333469863082,Friendly=true,Points=100,ComboOwner=liveOwner,Pos=vector(-490.0,123.2,546.0)}},{time=3479.327,effect="KickedComboCoconut",data={Pos1=vector(-490.0,123.2,546.0),Points=100,Rad=13}},{time=3479.327,effect="FallingCoconut",data={Combo=36,Radius=13,Dur=0.7637987152502324,Friendly=true,Points=100,ComboOwner=liveOwner,Pos=vector(-482.0,123.2,570.0)}},{time=3480.095,effect="KickedComboCoconut",data={Pos1=vector(-482.0,123.2,570.0),Points=100,Rad=13}},{time=3480.095,effect="FallingCoconut",data={Combo=37,Radius=13,Dur=0.7351616336946107,Friendly=true,Points=100,ComboOwner=liveOwner,Pos=vector(-514.0,123.2,554.0)}},{time=3480.844,effect="KickedComboCoconut",data={Pos1=vector(-514.0,123.2,554.0),Points=100,Rad=13}},{time=3480.844,effect="FallingCoconut",data={Combo=38,Radius=13,Dur=0.7070004939101886,Friendly=true,Points=100,ComboOwner=liveOwner,Pos=vector(-470.0,123.2,542.0)}},{time=3481.614,effect="KickedComboCoconut",data={Pos1=vector(-470.0,123.2,542.0),Points=100,Rad=13}},{time=3481.614,effect="FallingCoconut",data={Combo=39,Radius=13,Dur=0.6792951657095281,Friendly=true,Points=100,ComboOwner=liveOwner,Pos=vector(-494.0,123.2,526.0)}}}
player.Name="MainAccount";cfg.coconutcombo={enabled=true,main="MainAccount",mainevery=0,maxspeed=180}
root.Position=vector(-490,123.2,546)
local lastTime=realEvents[1].time
local caughtLive=0
for _,event in ipairs(realEvents)do
 now+=event.time-lastTime;lastTime=event.time
 fx.OnClientEvent:Fire(event.effect,event.data)
 comboController:Tick()
 if event.effect=="FallingCoconut" then
  assert(comboController.active and not comboController.session.yieldJob,"Main failed to catch own live fixture drop "..tostring(event.data.Combo))
  caughtLive+=1
 end
end
assert(caughtLive>=8,"fixture too short")

-- Replay fixture as Main with default mainevery=3 and helper nearby -> chimes in on multiples of 4 (32, 36).
comboController:Finish("live replay cadence")
comboController.records={};comboController.byKey={};comboController.chains={};comboController.chainCount=0;comboController.disks={}
cfg.coconutcombo.mainevery=3
alt2Root.Position=vector(-490,123.2,546)
lastTime=realEvents[1].time
local cadenceCaught={}
for _,event in ipairs(realEvents)do
 now+=event.time-lastTime;lastTime=event.time
 fx.OnClientEvent:Fire(event.effect,event.data)
 comboController:Tick()
 if event.effect=="FallingCoconut" and comboController.active and not comboController.session.yieldJob then
  cadenceCaught[event.data.Combo]=true
 end
end
assert(cadenceCaught[32] and cadenceCaught[36] and not cadenceCaught[31] and not cadenceCaught[33] and not cadenceCaught[34],"live Main cadence (32,36) mismatch")

-- Replay fixture as AltOne owning the combo while Main steps inside on Combo 33.
comboController:Finish("alt live replay")
comboController.records={};comboController.byKey={};comboController.chains={};comboController.chainCount=0;comboController.disks={}
player.Name="AltOne";liveOwner.Name="AltOne"
lastTime=realEvents[1].time
for _,event in ipairs(realEvents)do
 now+=event.time-lastTime;lastTime=event.time
 fx.OnClientEvent:Fire(event.effect,event.data)
 if event.effect=="FallingCoconut" and event.data.Combo==33 then
  root.Position=event.data.Pos+vector(2,0,0)
  mainRoot.Position=event.data.Pos+vector(1,0,0)
 else
  mainRoot.Position=vector(0,3,0)
 end
 comboController:Tick()
 if event.effect=="FallingCoconut" then
  if event.data.Combo==33 then
   assert(comboController.active and comboController.session.yieldJob,"Alt did not exit own live combo when Main stepped in on Combo 33")
  else
   assert(comboController.active and not comboController.session.yieldJob,"Alt did not catch own live combo on Combo "..tostring(event.data.Combo))
  end
 end
end

-- Replay fixture as AltOne watching Main's combo where Main only steps into Combo 33 -> Alt catches 31, 32, exits 33, continues 34..39.
comboController:Finish("alt watching main live replay")
comboController.records={};comboController.byKey={};comboController.chains={};comboController.chainCount=0;comboController.disks={}
player.Name="AltOne";liveOwner.Name="MainAccount"
root.Position=vector(-490,123.2,546)
lastTime=realEvents[1].time
for _,event in ipairs(realEvents)do
 now+=event.time-lastTime;lastTime=event.time
 fx.OnClientEvent:Fire(event.effect,event.data)
 if event.effect=="FallingCoconut" and event.data.Combo==33 then
  root.Position=event.data.Pos+vector(2,0,0)
  mainRoot.Position=event.data.Pos+vector(1,0,0)
 else
  mainRoot.Position=vector(0,3,0)
 end
 comboController:Tick()
 if event.effect=="FallingCoconut" then
  if event.data.Combo==33 then
   assert(comboController.active and comboController.session.yieldJob,"Alt did not exit Main's live combo when Main stepped in on Combo 33")
  else
   assert(comboController.active and not comboController.session.yieldJob,"Alt did not catch Main's live combo on Combo "..tostring(event.data.Combo))
  end
 end
end

-- 8. Task travel lock, Shower preemption, Mondo priority, autofarm-off, renderless Heartbeat, 1000-coconut bound, Shutdown.
comboController:Finish("safety checks")
comboController.records={};comboController.byKey={};comboController.chains={};comboController.chainCount=0
root.Position=vector(0,3,0);mainRoot.Position=vector(-45,3,0)
observe(20,0,"safety",player,1,2)
showerController.active=true;local showerCancelled=false
showerController.cancel=function()showerCancelled=true;showerController.active=false end
comboController:Tick()
assert(comboController.active and showerCancelled,"combo did not preempt shower")

local align=Instance.new("AlignPosition")
local landed=false
comboController.awaitLanding=function()assert(comboController.taskTravel);landed=true end
local taskThread=coroutine.create(function()
 return comboController:WithTaskTravel(function()
  assert(not comboController.active and root.CustomPhysicalProperties==nil)
  align.Parent=root;state.tweennoclip={Connected=true}
  coroutine.yield("flying")
  assert(align.Parent==root)
  state.tweennoclip=nil;align:Destroy()
  return "arrived"
 end)
end)
local ok1,p1=coroutine.resume(taskThread);assert(ok1 and p1=="flying")
comboController:Tick();assert(not comboController.active and align.Parent==root,"combo interrupted task travel")
local ok2,p2=coroutine.resume(taskThread);assert(ok2 and p2=="arrived" and landed and not comboController.taskTravel)
comboController.awaitLanding=nil

-- Finish resumes queued work synchronously; Begin must recheck TravelBlocked.
local resumedAlign=Instance.new("AlignPosition")
local resumedTask=coroutine.create(function()
 comboController:WithTaskTravel(function()
  resumedAlign.Parent=root;state.tweennoclip={Connected=true}
  coroutine.yield()
  resumedAlign:Destroy();state.tweennoclip=nil
 end)
end)
local s1=comboController:Begin({key="pre",position=vector(5,3,0)},h,root);assert(s1)
local origResume=showerController.ResumeOthers
local armed=true
showerController.ResumeOthers=function(self)
 origResume(self)
 if armed then armed=false;assert(coroutine.resume(resumedTask)) end
end
local s2=comboController:Begin({key="post",position=vector(8,3,0)},h,root)
assert(not s2 and not comboController.active and resumedAlign.Parent==root,"Begin stole movement after synchronous Finish->ResumeOthers")
assert(coroutine.resume(resumedTask))
showerController.ResumeOthers=origResume

-- Renderless Heartbeat + autofarm=false + production collector integration.
cfg.autofarm.enabled=false;state.activityStatus=2
comboController.records={};comboController.byKey={};comboController.chains={};comboController.chainCount=0
root.Position=vector(0,3,0)
local startMoveCalls=moveToCalls
observe(12,0,"heartbeat-only",player,0,2)
comboController:Tick()
RunService.bound.AtlasComboMovement=nil
for _=1,3 do step(0.03) end
assert(comboController.active and moveToCalls>startMoveCalls and root.Position.X>0,"render-disabled / autofarm-off own 0x catch stalled")

-- 1000 transient coconuts stay bounded & leak-free.
local leakBaseline=liveConnections
for i=1,1000 do
 now+=0.1
 observe(20,0,"leak"..i,alt2Player,i%5,2)
 comboController:Tick()
 assert(#comboController.records<=32 and comboController.chainCount<=64 and liveConnections==leakBaseline,"retention bound exceeded")
end

-- Shutdown restores everything cleanly.
showerController.shuttingDown=true
comboController:Shutdown()
assert(liveConnections==0,"shutdown leaked connections: "..tostring(liveConnections))
assert(not comboController.active and next(comboController.records)==nil and next(comboController.mainZones)==nil and next(comboController.chains)==nil and comboController.chainCount==0)
assert(root.CustomPhysicalProperties==nil and root.Massless==false and h.WalkSpeed==40 and controls.controlsEnabled)
assert(not RunService.bound.AtlasComboMovement and not connections.list.comboComboTick and not connections.list.comboComboFX and not connections.list.comboPlayerAdded)
assert(not threads:Get("Autofarm"),"shutdown resumed autofarm incorrectly")
print("PASS: own combo 0x+ catching, exact fast movement & 10x density, Main auto-exit for any player combo, field-safe exit, overlap avoidance, Main immunity, live trace, travel lock, bounded memory, and clean shutdown")
