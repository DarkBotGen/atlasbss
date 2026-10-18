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
cfg.coconutteam={enabled=false,fast=true,main="OtherMain",alt1="Tester",alt2="AltTwo",catcher1="OutsideOne",catcher2="None",catcher3="None",field="Pepper Patch",maxspeed=120,url="https://example.test",key=string.rep("x",32)}
state.activityStatus=1
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
local comboController = {records={}, byKey={}, jobs={}, seq=0, generation=0, active=false, status="Disabled"}
smoothMovement.comboController = comboController

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

function comboController:Observe(effectName, data)
	if not self:Managed() or effectName ~= "FallingCoconut" or not data.Combo or not data.Friendly then return end
	if typeof(data.Pos) ~= "Vector3" then return end
	local dur = tonumber(data.Dur)
	if not dur or dur ~= dur or dur <= 0 or dur > 12 then return end
	local owner = self:Owner(data.Owner) or self:Owner(data.Player) or self:Owner(data.PID) or self:Owner(data.Target)
	local now = os.clock()
	local field = getFieldAt(data.Pos)
	-- Positions and expiry are available in the existing FX stream even with Hide Particles off.
	-- Ownership is retained only when an actual player identifier is exposed by that stream.
	local key = string.format("%s:%.1f:%.1f:%.1f:%s",string.lower(owner or "unknown"),data.Pos.X,data.Pos.Y,data.Pos.Z,tostring(data.ID or data.FEID or data.Points or 0))
	local old = self.byKey[key]
	if old and old.deadline > now then return end
	if #self.records >= 32 then return end
	local record = {key=key, owner=owner, position=data.Pos, deadline=now+dur, points=tonumber(data.Points) or 0,
		field=field and field.Name or "", seen=now}
	self.byKey[key]=record
	self.records[#self.records+1]=record
	self.lastOwner = owner or "Unknown (team catches paused for this coconut)"
end

function comboController:MainOwned(owner)
	return type(owner)=="string" and cfg.coconutteam.main~="None" and cfg.coconutteam.main~=""
		and string.lower(owner)==string.lower(cfg.coconutteam.main)
end

function comboController:OwnLanding()
	if not cfg.coconutteam.enabled or self:Role()~="main" then return end
	local now, best=os.clock(),nil
	for _,r in ipairs(self.records)do
		if self:MainOwned(r.owner) and r.deadline+0.12>now and (not best or r.deadline<best.deadline) then best=r end
	end
	return best
end

function comboController:Available()
	if self.closed or state.stop or (showerController.active and not self.ownPriority) then return false end
	local char = localPlayer.Character
	local h = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not h or not root or h.Health <= 0 then return false end
	if not self.ownPriority and cfg.autofarm.enabled and (state.activityStatus ~= 1 or state.fasttween) then return false end
	if cfg.coconutteam.enabled then
		local role = self:Role()
		if not role or (role == "catcher" and not cfg.coconutteam.fast) then return false end
		if not self.ownPriority and role ~= "catcher" and not cfg.autofarm.enabled then return false end
	end
	return true, h, root
end

function comboController:IsMovementJob(id)
	return showerController:IsMovementJob(id)
end

function comboController:Finish(reason)
	local session = self.session
	if not session then return end
	self.session, self.active = nil, false
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
	if self.session and self.session.key == job.key then return self.session end
	self:Finish("Changing combo landing")
	if showerController.active or self.closed then return end
	local env = type(getgenv)=="function" and getgenv() or _G
	local key = "AtlasTemporaryPMS_" .. localPlayer.UserId
	local s = {key=job.key,h=h,root=root,originalSpeed=h.WalkSpeed,leaseKey=key,lease={},previousLease=env[key],direction=Vector3.zero,speed=0}
	pcall(function()
		local module=localPlayer.PlayerScripts:FindFirstChild("PlayerModule")
		if module then s.controls=require(module):GetControls();s.restoreControls=s.controls.controlsEnabled~=false;s.controls:Disable() end
	end)
	self.session,self.active=s,true
	showerController:PauseOthers()
	RunService:BindToRenderStep("AtlasComboMovement",Enum.RenderPriority.Character.Value+1,function()
		if self.session~=s then return end
		if not self:Available() or not s.root.Parent then self:Finish("Combo movement interrupted");return end
		s.lease.speed,s.lease.expires=s.speed,os.clock()+0.3
		env[key]=s.lease
		s.h.WalkSpeed=s.speed
		s.h:Move(s.direction,false)
	end)
	return s
end

function comboController:Tick()
	local now=os.clock()
	for i=#self.records,1,-1 do
		local r=self.records[i]
		if now>r.deadline+0.25 then
			if self.byKey[r.key]==r then self.byKey[r.key]=nil end
			table.remove(self.records,i)
		end
	end
	if not self:Managed() then self.ownPriority=false;self:Finish("Disabled");return end
	local own=self:OwnLanding()
	self.ownPriority=own~=nil
	if own and showerController.active and showerController.cancel then showerController.cancel("Main catching its own combo") end
	local available,h,root=self:Available()
	if not available then self:Finish("Busy with another activity");return end
	if self.session and (self.session.root~=root or self.session.h~=h) then self:Finish("Character changed") end
	local job=own
	if not job and cfg.coconutteam.enabled then
		for _, candidate in ipairs(self.jobs) do
			if not self:MainOwned(candidate.owner) and candidate.deadline+0.12>now and candidate.leaseUntil>now then job=candidate;break end
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
	if not job then self:Finish(cfg.coconutteam.enabled and "Waiting for assignment" or "Waiting for outside-field combo");return end
	local s=self:Begin(job,h,root)
	if not s then return end
	local delta=Vector3.new(job.position.X-root.Position.X,0,job.position.Z-root.Position.Z)
	local d=delta.Magnitude
	local lead=0.15
	local ok,ping=pcall(function()return getService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue()end)
	if ok and type(ping)=="number" and ping>=0 and ping<1000 then lead=math.clamp(ping*0.002,0.1,0.4) end
	-- Shower-style continuous Move + dynamic WalkSpeed, using the coconut's own expiry.
	-- No tween, CFrame teleport, density change, or invented fixed shower lifetime.
	local travelTime=math.max(0.05,job.deadline-now-lead)
	local cap=self.ownPriority and math.max(180,cfg.coconutteam.maxspeed) or cfg.coconutteam.maxspeed
	if self.ownPriority then
		-- Depart immediately; brake near the center instead of spending the fall time walking slowly.
		s.speed=d>0.5 and math.min(cap,math.max(20,d/0.05)) or 0
	else
		s.speed=d>0.5 and math.clamp(d/travelTime*1.15,math.min(s.originalSpeed,cap),cap) or 0
	end
	s.direction=d>0.5 and delta.Unit or Vector3.zero
	if d<=0.5 then
		local v=root.AssemblyLinearVelocity
		root.AssemblyLinearVelocity=Vector3.new(0,v.Y,0)
	end
	self.status=string.format("Catching %s combo | %.0f PMS",job.owner or "outside",s.speed)
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
		pos={root.Position.X,root.Position.Y,root.Position.Z},speed=speed,busy=not available or self.ownPriority,
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
				jobs[#jobs+1]={key=j.key,owner=j.owner,position=target,deadline=deadline,leaseUntil=os.clock()+lease}
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
		if self.debugLabel then self.debugLabel.Text=string.format("Detected: %d | Assigned: %d | RTT: %.0f ms | Activity: %s",#self.records,#self.jobs,(self.roundTrip or 0)*1000,tostring(state.activityStatus)) end
	end))
	self:Configure()
end

function comboController:Shutdown()
	self.closed=true
	self.generation+=1
	threads:Cancel("comboTeamSync")
	connections:Cancel("comboTeamTick")
	connections:Cancel("comboTeamFX")
	self:Finish("Unloaded")
	table.clear(self.records);table.clear(self.byKey);table.clear(self.jobs)
end

function comboController:BuildMenu(tab)
	local folder=tab.AddFolder("Coconut Team")
	folder.AddSwitch("Coordinate Coconut Team",function()self:Configure()end,"coconutteam","enabled")
	folder.AddSwitch("Fast Combo Catching",function()self:Configure()end,"coconutteam","fast")
	folder.AddLabel("Main always catches its own combo locally, ahead of showers; other accounts leave it alone.")
	folder.AddLabel("Team controls override Farm Combo Coconuts; that regular switch is not required.")
	folder.AddLabel("Fast mode works with autofarm off. Outside catchers need this enabled.")
	folder.AddLabel("Solo fast mode catches outside the selected team field without alternating.")
	local names={"None"}
	for _,p in ipairs(getService("Players"):GetPlayers())do names[#names+1]=p.Name end
	local selectors={}
	for _,entry in ipairs({{"Main Account","main"},{"Spawning Alt 1","alt1"},{"Spawning Alt 2","alt2"},{"Outside Catcher 1","catcher1"},{"Outside Catcher 2","catcher2"},{"Outside Catcher 3","catcher3"}})do
		selectors[entry[2]]=folder.AddDropdown(entry[1],names,nil,function()self:Configure()end,"coconutteam",entry[2])
	end
	local fieldSelector=folder.AddDropdown("Team Field",availableFields,true,function()self:Configure()end,"coconutteam","field",{Field=true})
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
		if type(code.field)=="string" and availableFields[code.field] then cfg.coconutteam.field=code.field;fieldSelector.SetValue(code.field) end
		saveConfig();self:Configure();ui.Notify("Coconut Team","Connection and account settings saved")
	end)
	folder.AddButton("Copy Team Code",function()
		local c=cfg.coconutteam
		local copy=setclipboard or toclipboard
		if not copy then ui.Notify("Coconut Team","Clipboard unavailable");return end
		copy(HttpService:JSONEncode({url=c.url,key=c.key,main=c.main,alt1=c.alt1,alt2=c.alt2,catcher1=c.catcher1,catcher2=c.catcher2,catcher3=c.catcher3,field=c.field}))
		ui.Notify("Coconut Team","Paste this code into each team account")
	end)
	folder.AddButton("Reconnect Coordinator",function()self:Configure()end)
	self.statusLabel=folder.AddLabel("Team: Disabled")
	self.ownerLabel=folder.AddLabel("Last combo owner: waiting for a new combo")
	self.debugLabel=folder.AddLabel("Detected: 0 | Assigned: 0 | RTT: waiting")
	folder.AddLabel("One launcher for all computers. All accounts must be in the same Roblox server.")
	folder.Toggle(true,true)
end


threads:Add("Autofarm",worker);threads:Add("walkspeed",worker);threads:Add("Stats",worker)
local stats=threads:Get("Stats")
comboController:Start()
local startConnections=liveConnections
assert(comboController.observesRemote)
local function observe(x,id,owner)
 fx.OnClientEvent:Fire("FallingCoconut",{Friendly=true,Combo=true,Pos=vector(x,3,0),Dur=2,ID=id,Target=owner or player,Points=1})
end
observe(5,"inside");comboController:Tick();assert(not comboController.active,"solo fast stole in-field combo")
observe(35,"outside");comboController:Tick()
assert(comboController.active and not controls.controlsEnabled)
assert(not threads:Get("Autofarm") and threads:Get("Stats")==stats)
threads:Add("Autofarm",worker);assert(not threads:Get("Autofarm"),"watchdog stole combo movement")
for i=1,25 do step(0.03)end
assert(root.Position.X>25,"continuous movement did not approach coconut")
showerController.active=true;comboController:Tick()
assert(not comboController.active and h.WalkSpeed==40 and controls.controlsEnabled,"shower interruption did not restore")
showerController.active=false
cfg.coconutteam.enabled=true;cfg.coconutteam.fast=false
comboController.jobs={{key="assigned",owner="Tester",position=vector(40,3,0),deadline=now+1,leaseUntil=now+.4}}
comboController:Tick();assert(comboController.active)
now+=.5;comboController:Tick();assert(not comboController.active,"expired network lease still moving")
assert(comboController:Sync());assert(sent.server==game.JobId and sent.roster.main=="OtherMain")
assert(#sent.targets==2,"visible combo observations missing")
reply.jobs={{key="remote",owner="Tester",pos={40,3,0},ttl=1,lease=.65}}
comboController:Sync();assert(#comboController.jobs==1)
assert(comboController.jobs[1].leaseUntil<=now+.551,"round trip not deducted")
networkFail=true;assert(not comboController:Sync() and #comboController.jobs==0)
networkFail=false;changeSettings=true
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
-- Main-owned landings are immediate, local and preempt showers/conversion.
cfg.coconutteam.main="Tester";cfg.coconutteam.alt1="AltOne"
cfg.autofarm.enabled=false;state.activityStatus=2
comboController.records={};comboController.byKey={};comboController.jobs={}
root.Position=vector(0,3,0)
observe(80,"main-priority")
local cancelled=0
showerController.active=true
showerController.cancel=function()cancelled+=1;showerController.active=false end
comboController:Tick()
assert(comboController.active and comboController.ownPriority and cancelled==1,"own combo did not preempt shower/conversion")
for _,fn in pairs(RunService.bound)do fn()end
assert(h.WalkSpeed>=180,"main-owned approach was not accelerated")
networkFail=true
assert(not comboController:Sync())
assert(comboController.active and sent.busy==true and #sent.targets==0,"own combo depends on relay or main is available to other assignments")
networkFail=false
comboController:Finish("test")
-- An alt rejects coordinator assignments for the main, including stale server jobs.
cfg.coconutteam.main="OtherMain";cfg.coconutteam.alt1="Tester"
cfg.autofarm.enabled=true;state.activityStatus=1
comboController.records={};comboController.byKey={}
reply.jobs={{key="main-only",owner="OtherMain",pos={5,3,0},ttl=2,lease=2}}
assert(comboController:Sync() and #comboController.jobs==0,"alt accepted main-owned assignment")
comboController.jobs={{key="stale-main",owner="OtherMain",position=vector(5,3,0),deadline=now+2,leaseUntil=now+2}}
comboController:Tick();assert(not comboController.active,"alt chased stale main-owned job")
cfg.coconutteam.enabled=false;cfg.coconutteam.fast=true
for i=1,1000 do
 now+=.1
 observe(50,"transient"..i)
 comboController:Tick()
 assert(#comboController.records<=24 and liveConnections==startConnections,"transient coconut retention")
end
state.stop=true;comboController:Tick();assert(not comboController.active and h.WalkSpeed==40)
state.stop=false
cfg.autofarm.enabled=false
observe(50,"outside-autofarm-off");comboController:Tick();assert(comboController.active,"fast mode requires autofarm")
showerController.shuttingDown=true
comboController:Shutdown()
assert(not comboController.active and next(comboController.records)==nil and next(comboController.byKey)==nil)
assert(not RunService.bound.AtlasComboMovement and h.WalkSpeed==40 and controls.controlsEnabled)
assert(not connections.list.comboTeamTick and not connections.list.comboTeamFX)
assert(not threads:Get("Autofarm"),"unload resumed farming")
print("PASS: outside-only standalone catching, smooth travel, exclusive movement, shower preemption, expiring leases, RTT, failed/late requests, 1000 coconut lifetimes, autofarm-off, unload restoration")
