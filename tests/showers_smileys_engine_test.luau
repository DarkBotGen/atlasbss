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

local currentField={}
local function getHumanoid()return h end
local function getFieldAt()return currentField end
state.activityStatus=1
cfg.autofarm.enabled=true
threads.Add = function(manager, threadId, callback, delaySeconds, ...)
	if manager.closed then return end
	local exclusive = smoothMovement.showerController
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
function showerController:Start()
 if self.started or self.shuttingDown then return end
 self.started=true
 local bridge=self
 bridge.allowed=function()
  return not bridge.shuttingDown and cfg and state and not state.stop
   and cfg.autofarm.enabled and cfg.autofarm.farmshowers and state.activityStatus == 1
   and currentField ~= nil and getHumanoid().Health > 0 and getFieldAt(getRootPart().Position) == currentField
 end
 bridge.realPMS=function(h)
  local value=h and h.WalkSpeed
  if type(value)=="number" and value==value and value>0 and value<math.huge then return value end
 end
 bridge.catchLead=function()
  local ok,value=pcall(function()return getService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue()end)
  if ok and type(value)=="number" and value==value and value>=0 and value<math.huge then return value*0.002 end
  return 0
 end
 bridge.pauseOtherMovement=function()bridge:PauseOthers()end
 bridge.resumeOtherMovement=function()bridge:ResumeOthers()end
local function startSafeshower()
-- Star Shower x10 test chaser. WalkSpeed + Humanoid:Move only; no teleporting.
-- Pause Pepper Shower Rot/other movement scripts before using this standalone test.
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local player=Players.LocalPlayer
local env=type(getgenv)=="function" and getgenv() or _G
local leaseKey="AtlasTemporaryPMS_" .. player.UserId
local POPUP="5101364168"
-- Aim for light 1 at its estimated expiry minus 500ms using real WalkSpeed.
local LIFETIME,LEAD,SAFE_RADIUS=2,0.135,2.7
-- Later transitions use live 2x Data Ping, with a 180 PMS movement cap.
local WALK_DELAY=0 -- No fixed spawn interval: target changes only after observed disappearance
local lastUpdateAt=os.clock()
local appearanceSerial=0
local appearanceOrder=setmetatable({}, {__mode="k"})
local lastClientStallAt=-math.huge
local stallCounter=0
local closed,maxSpeed=false,210
local movementBind="StarShowerX10Movement_" .. player.UserId
local session,controls=nil,nil
local triggers,lights,guides,connections={},{},{},{}
local seen=setmetatable({}, {__mode="k"})
local images={} -- explicit per-popup connection lifetime
local ownerLast={}
-- Invisible lifetime owner only; the visible UI is the numbered world labels.
local old=player.PlayerGui:FindFirstChild("SafeshowerStandalone")
if old then old:Destroy() end
local gui=Instance.new("Folder")
gui.Name="AtlasShowerVisuals"
bridge.close=function()gui:Destroy()end
local sequenceTags={}
local function clearSequenceTags()
 for part,tag in pairs(sequenceTags) do
  if tag then pcall(function() tag:Destroy() end) end
  sequenceTags[part]=nil
 end
end
local function showSequenceTag(r)
 if not r or not r.object or not r.object:IsA("BasePart") or sequenceTags[r.object] then return end
 local tag=Instance.new("BillboardGui")
 tag.Name="StarShowerSequenceDiagnostic"
 tag.Adornee=r.object
 tag.AlwaysOnTop=true
 tag.Size=UDim2.fromOffset(90,42)
 tag.StudsOffsetWorldSpace=Vector3.new(0,3.5,0)
 tag.MaxDistance=250
 local txt=Instance.new("TextLabel")
 txt.Name="Number"
 txt.Size=UDim2.fromScale(1,1)
 txt.BackgroundColor3=Color3.fromRGB(23,23,40)
 txt.BackgroundTransparency=0.15
 txt.TextColor3=Color3.fromRGB(255,255,255)
 txt.Font=Enum.Font.GothamBold
 txt.TextScaled=true
 txt.Text="#"..r.order
 txt.Parent=tag
 Instance.new("UICorner",txt).CornerRadius=UDim.new(0,8)
 tag.Parent=player.PlayerGui
 sequenceTags[r.object]=tag
 r.diagnosticTag=tag
end
local function renderSequence(s)
 for i=1,10 do
  local r=s and s.records[i]
  if r and r.diagnosticTag and r.diagnosticTag.Parent then
   local label=r.diagnosticTag:FindFirstChild("Number")
   if label then
    label.Text=string.format("#%d%s",i,s.target==r and " TARGET" or "")
    label.TextColor3=s.target==r and Color3.fromRGB(120,255,150) or Color3.fromRGB(255,255,255)
   end
  end
 end
end
local function connect(signal,fn) local c=signal:Connect(fn);connections[c]=true;return c end
bridge.abortStartup=function()
 closed=true
 RunService:UnbindFromRenderStep(movementBind)
 for c in pairs(connections) do c:Disconnect() end
 table.clear(connections)
 gui:Destroy()
end
local function xy(v) return Vector2.new(v.X,v.Z) end
local function atRoot() local c=player.Character;return c,c and c:FindFirstChildOfClass("Humanoid"),c and c:FindFirstChild("HumanoidRootPart") end
local function log(text) bridge.lastEvent=text end
local inputLock = "ArmageddonFirstLightLock_" .. player.UserId
local actionService = game:GetService("ContextActionService")
local function lockInput(s)
 if s.inputLocked then return end
 s.inputLocked = true
 if controls then controls:Disable() end
 actionService:BindActionAtPriority(inputLock, function(_, _, input)
  if input.KeyCode == Enum.KeyCode.F8 or input.KeyCode == Enum.KeyCode.RightShift then
   return Enum.ContextActionResult.Pass
  end
  return Enum.ContextActionResult.Sink
 end, false, 10000, Enum.UserInputType.Keyboard, Enum.UserInputType.MouseButton1,
  Enum.UserInputType.MouseButton2, Enum.UserInputType.MouseMovement,
  Enum.UserInputType.MouseWheel, Enum.UserInputType.Touch, Enum.UserInputType.Gamepad1)
 local camera = workspace.CurrentCamera
 if camera then
  s.lockedCamera, s.cameraType = camera, camera.CameraType
  camera.CameraType = Enum.CameraType.Scriptable
 end
 s.h.Jump = false
end
local function unlockInput(s)
 actionService:UnbindAction(inputLock)
 if s.lockedCamera then pcall(function() s.lockedCamera.CameraType = s.cameraType end) end
 if bridge.resumeRotationControls then bridge.resumeRotationControls() end
end
local function finish(reason)
 local s=session;if not s then return end;session=nil
 unlockInput(s)
 bridge.active=false
 bridge.lastStatus=reason
 s.direction=Vector3.zero
 pcall(function() s.root.AssemblyLinearVelocity=Vector3.zero;s.root.AssemblyAngularVelocity=Vector3.zero end)
 renderSequence(s)
 clearSequenceTags()
 pcall(function() s.h:Move(Vector3.zero,false);s.h.WalkSpeed=s.originalSpeed end)
 if env[leaseKey]==s.lease then env[leaseKey]=s.previousLease end
 RunService:UnbindFromRenderStep(movementBind)
 if controls and s.restoreControls then pcall(function() controls:Enable() end) end
 local text=string.format("%s | inside at collection time: %d / 10; seen: %d",reason,s.caught,s.count)
 log(text);bridge.lastStatus=text
 if bridge.resumeOtherMovement then bridge.resumeOtherMovement() end
end
local function setSpeed(s,value)
  local cap = s.firstRealTravel and s.firstRealPMS or maxSpeed
 value=math.clamp(value,0,cap)
 s.lease.speed,s.lease.expires=value,os.clock()+0.3
 env[leaseKey]=s.lease
 if s.h.WalkSpeed~=value then s.h.WalkSpeed=value end
 s.speed=value
end
local function bindMovement(s)
 RunService:BindToRenderStep(movementBind,Enum.RenderPriority.Character.Value+1,function()
  if closed or not bridge.allowed() or session~=s or not s.root.Parent or s.h.Health<=0 then return end
  if s.waitingDeparture then return end
  if s.inputLocked then s.h.Jump=false end
  local cap = s.firstRealTravel and s.firstRealPMS or maxSpeed
  local speed=math.clamp(s.speed or 0,0,cap)
  s.lease.speed,s.lease.expires=speed,os.clock()+0.3
  env[leaseKey]=s.lease
  if s.h.WalkSpeed~=speed then s.h.WalkSpeed=speed end
  s.h:Move(s.direction or Vector3.zero,false)
 end)
end
local function brake(s,full)
 local velocity=s.root.AssemblyLinearVelocity
 s.root.AssemblyLinearVelocity=full and Vector3.zero or Vector3.new(0,velocity.Y,0)
 s.root.AssemblyAngularVelocity=Vector3.zero
end
-- Terminate the previous movement immediately, without a timed hold.
local function stopMovementImmediately(s)
 s.direction=Vector3.zero
 s.speed=0
 s.lease.speed,s.lease.expires=0,os.clock()+0.3
 env[leaseKey]=s.lease
 if s.h and s.h.Parent then
  s.h:Move(Vector3.zero,false)
  s.h.WalkSpeed=0
 end
 if s.root and s.root.Parent then
  brake(s,true)
 end
end
local function inCircle(s)
 return s.target and not s.target.ended and (xy(s.root.Position)-xy(s.target.position)).Magnitude<=3.8
  and math.abs(s.root.Position.Y-s.target.position.Y)<=4
end
local function hold(s)
 s.direction=Vector3.zero
 setSpeed(s,inCircle(s) and 50 or 0)
 s.h:Move(Vector3.zero,false)
 brake(s,false)
end
local function lightType(o)
 if o.Name~="WarningDisk" or not o:IsA("Part") or o.Material~=Enum.Material.Neon then return false end
 local z,c=o.Size,o.Color
 return o:FindFirstChildOfClass("CylinderMesh")~=nil and math.abs(z.X-8)<0.15 and math.abs(z.Y-0.4)<0.1 and math.abs(z.Z-8)<0.15
  and math.abs(c.R*255-50)<=2 and math.abs(c.G*255-255)<=2 and math.abs(c.B*255-50)<=2
end
local function popupOwner(o)
 local b=o:FindFirstAncestorWhichIsA("BillboardGui")
 if not b or not b.Enabled then return nil end
 local a=b.Adornee or b.Parent;if not a then return nil end
 for _,p in ipairs(Players:GetPlayers()) do
  if p.Character and (a==p.Character or a:IsDescendantOf(p.Character) or b:IsDescendantOf(p.Character)) then return p end
 end
end
local function observeImage(o,initial)
 if images[o] or not (o:IsA("ImageLabel") or o:IsA("ImageButton")) or not o:FindFirstAncestorWhichIsA("BillboardGui") then return end
 local initialId=o.Image:match("rbxassetid://(%d+)") or o.Image:match("[?&]id=(%d+)")
 local state={on=initial==true and initialId==POPUP and o.Visible and o.ImageTransparency<0.95,connections={}};images[o]=state
 local function check()
  if closed or not o.Parent then return end
  local id=o.Image:match("rbxassetid://(%d+)") or o.Image:match("[?&]id=(%d+)")
  local on=id==POPUP and o.Visible and o.ImageTransparency<0.95
  if not on then state.on=false;return end
  local owner=popupOwner(o);if not owner then return end
  if not state.on then
   state.on=true
   local now=os.clock()
   if now-(ownerLast[owner.UserId] or -math.huge)<2.5 then return end
   ownerLast[owner.UserId]=now
   triggers[#triggers+1]={time=now,owner=owner}
   log("Passive popup: " .. owner.Name)
   if session and owner~=player then finish("Stopped: overlapping player trigger") end
  end
 end
 state.check=check
 for _,p in ipairs({"Image","Visible","ImageTransparency"}) do local c=connect(o:GetPropertyChangedSignal(p),check);state.connections[c]=true end
 check()
end
local function releaseImage(o)
 local state=images[o];if not state then return end
 images[o]=nil
 for c in pairs(state.connections) do c:Disconnect();connections[c]=nil end
 table.clear(state.connections)
end
connect(player.PlayerGui.DescendantRemoving,releaseImage)
local function inspect(o,initial)
 if closed or seen[o] then return end
 local folder=workspace:FindFirstChild("Particles")
 if not folder or not o:IsDescendantOf(folder) then return end
 if o.Name=="Star Shower Guide" and o:IsA("BasePart") then
  seen[o]=true
  if not initial then guides[#guides+1]={object=o,time=os.clock(),position=o.Position,origin=o.Position,lagged=(os.clock()-lastUpdateAt>0.12 or os.clock()-lastClientStallAt<0.5),stallCounter=stallCounter} end
 elseif lightType(o) then
  seen[o]=true
  if not initial then
   lights[#lights+1]={object=o,time=(appearanceOrder[o] and appearanceOrder[o].time or os.clock()),arrivalOrder=(appearanceOrder[o] and appearanceOrder[o].serial or math.huge),deadline=os.clock()+LIFETIME,position=o.Position,ended=false,spawnStallCounter=stallCounter,spawnLagged=(os.clock()-lastClientStallAt<0.3 or os.clock()-lastUpdateAt>0.12)}
   log("Small light detected: " .. tostring(o.Position))
  end
 end
end
local function releasePassive() end
local function begin(g)
 if session or not bridge.allowed() then return end
 releasePassive()
 local char,h,root=atRoot();if not h or not root or h.Health<=0 then return end
 if not controls then
  pcall(function() local m=player.PlayerScripts:FindFirstChild("PlayerModule");if m then controls=require(m):GetControls() end end)
 end
 if closed or session then return end
 local s={guide=g,character=char,h=h,root=root,originalSpeed=h.WalkSpeed,restoreControls=controls and controls.controlsEnabled~=false,
  previousLease=env[leaseKey],lease={},motionAt=os.clock(),motionPosition=root.Position,records={},count=0,caught=0,target=nil,point=nil,locked=false,nextPlan=0}
 session=s
 s.waitingDeparture=true
 bridge.active=true
 if bridge.pauseOtherMovement then bridge.pauseOtherMovement() end
 if bridge.allowManualWaiting then bridge.allowManualWaiting() end
 clearSequenceTags()
 renderSequence(s)
 log("Guide recognized; tracking each disk in observed spawn order, no 0.3s schedule")
 s.leg=0;s.predictedCaught=0
 s.direction=Vector3.zero
 bindMovement(s)
 log("Own guide accepted; x10 route armed")
 bridge.lastStatus="Your Star Shower detected. Planning disappearance deadlines…"
end
-- The light's observed spawn time and actual disappearance determine movement.
-- No 0.3s assumption is used for target selection or arrival timing.
local function nearest(from,center,r)
 local d=from-center
 return d.Magnitude<=r and from or center+d.Unit*r
end
local function contactPoint(s,r,now)
 local center=xy(r.position)
 local nextRecord=s.records[r.order+1]
 local from=nextRecord and xy(nextRecord.position) or xy(s.root.Position)
 local direction=from-center
 if direction.Magnitude<0.001 then return center end
 -- Hold near the boundary on the side closest to the next known light.
 local point=center+direction.Unit*SAFE_RADIUS
 return point
end
connect(workspace.DescendantAdded,function(o)
 local candidate=o.Name=="WarningDisk" or o.Name=="Star Shower Guide"
 local image=o:IsA("ImageLabel") or o:IsA("ImageButton")
 if not candidate and not image then return end
 if candidate then
  appearanceSerial=appearanceSerial+1
  appearanceOrder[o]={time=os.clock(),serial=appearanceSerial}
 end
 task.defer(function() if not closed then if image then observeImage(o) end;if candidate then inspect(o,false) end end end)
end)
connect(player.PlayerGui.DescendantAdded,function(o) task.defer(function() if not closed then observeImage(o) end end) end)
-- Advance by actual visual removal, never by a predicted 0.3-second slot.
local function advanceOnDisappearance(s,now)
 if s.target and not s.target.ended then return end
 if s.target then
  -- Cancel any residual velocity and previous Move direction before switching.
  stopMovementImmediately(s)
  log(string.format("Light %d disappeared; previous movement cancelled and velocity zeroed",s.target.order))
  s.target=nil;s.point=nil;s.locked=false
 end
 local nextOrder=(s.leg or 0)+1
 while nextOrder<=s.count and s.records[nextOrder] and s.records[nextOrder].ended do
  s.leg=nextOrder
  nextOrder=nextOrder+1
 end
 local r=s.records[nextOrder]
 if r and not r.ended then
  if nextOrder>1 then s.firstRealTravel=false end
  s.leg=nextOrder;s.target=r;s.point=contactPoint(s,r,now);s.locked=false
  s.edgeOptimizedFor=nil
  log(string.format("Target light %d selected immediately after prior disappearance (appearance serial %s)",nextOrder,tostring(r.arrivalOrder)))
 end
end
local function completeLight(r,reason)
 if r.ended then return end
 r.ended=true
 local s=session
 if s and r.session==s then
  local inside=(xy(s.root.Position)-xy(r.position)).Magnitude<=3.5 and math.abs(s.root.Position.Y-r.position.Y)<=4
  if inside then s.caught=s.caught+1 end
  local now=os.clock()
  r.removedAt=now
  if r.diagnosticTag then r.diagnosticTag:Destroy();sequenceTags[r.object]=nil;r.diagnosticTag=nil end
  r.removeStallCounter=stallCounter
  r.removeLagged=(now-lastClientStallAt<0.3 or now-lastUpdateAt>0.12)
  s.lastRemoval={time=now,order=r.order}
  log(string.format("Light %d actually disappeared; inside=%s; observed lifetime=%.3fs; reason=%s",r.order,tostring(inside),now-r.time,reason))
  if s.target==r then advanceOnDisappearance(s,now) end
 end
end
connect(workspace.DescendantRemoving,function(o)
 releaseImage(o)
 for _,r in ipairs(lights) do
  if r.object==o then
   log(string.format("Light visual removed at age %.3fs",os.clock()-r.time))
   completeLight(r,"actual visual removal")
   break
  end
 end
end)
local scanElapsed=0
local function updateChase(dt)
 if closed then return end
 if not bridge.allowed() then
  finish("Safeshower inactive");releasePassive()
  table.clear(guides);table.clear(lights);table.clear(triggers)
  lastUpdateAt=os.clock()
  return
 end
 local now=os.clock()
 if now-lastUpdateAt>0.12 then
  lastClientStallAt=now
  stallCounter=stallCounter+1
  log(string.format("Client update gap %.3fs; removal timestamps near this gap are low-confidence",now-lastUpdateAt))
 end
 lastUpdateAt=now
 scanElapsed=scanElapsed+dt
 if scanElapsed>=0.1 then
  scanElapsed=0
  local f=workspace:FindFirstChild("Particles")
  if f then for _,o in ipairs(f:GetDescendants()) do inspect(o,false) end end
  for _,p in ipairs(Players:GetPlayers()) do
   local head=p.Character and p.Character:FindFirstChild("Head")
   if head then for _,o in ipairs(head:GetDescendants()) do observeImage(o) end end
  end
  for o,state in pairs(images) do if o.Parent then state.check() end end
  for i=#triggers,1,-1 do if now-triggers[i].time>12 then table.remove(triggers,i) end end
  for _,g in ipairs(guides) do
   if not g.resolved then
    local owners={}
    for _,trigger in ipairs(triggers) do if math.abs(trigger.time-g.time)<=0.75 then owners[trigger.owner]=true end end
    local count,owner=0,nil;for p in pairs(owners) do count=count+1;owner=p end
    if count==1 and owner==player then
     g.resolved=true;log("Matched own popup to guide");begin(g)
    elseif count>1 then
     g.resolved=true;bridge.lastStatus="Overlapping guide owners: not guessing ownership.";log("Guide rejected: overlapping popup owners")
    elseif now-g.time>1.25 then
     g.resolved=true
     local reason=count==0 and "Guide detected, but your passive popup was not detected." or "Guide belongs to another player's popup."
     bridge.lastStatus=reason;log(reason)
    end
   end
  end
  for i=#lights,1,-1 do if now-lights[i].time>15 then table.remove(lights,i) end end
  for i=#guides,1,-1 do if now-guides[i].time>15 then table.remove(guides,i) end end
 end
 local s=session;if not s then
  releasePassive() -- Atlas retains control outside an owned shower.
  return
 end
 if player.Character~=s.character or not s.root.Parent or s.h.Health<=0 then finish("Character changed");return end
 local g=s.guide
 -- Current guide position converges on the final center before the normal lights arrive.
 if g.object.Parent then g.position=g.object.Position end
 -- Process new observations by original DescendantAdded event order rather than
 -- deferred-inspection completion order. Assigned numbers never change afterward.
 local orderedLights={}
 for _,r in ipairs(lights) do
  if not r.session and not r.ended then orderedLights[#orderedLights+1]=r end
 end
 table.sort(orderedLights,function(a,b)
  if a.arrivalOrder~=b.arrivalOrder then return a.arrivalOrder<b.arrivalOrder end
  return a.time<b.time
 end)
 for _,r in ipairs(orderedLights) do
  if not r.session and not r.ended and s.count<10 and r.time>=g.time-0.1 and r.time<=g.time+7 then
   -- The animated guide rises above the ground; its height is not a light filter.
   -- Its final center is unavailable until removal, so use a broad initial region live.
   local origin=g.origin or g.position
   local distance=(xy(r.position)-xy(origin)).Magnitude
   if distance<=120 and math.abs(r.position.Y-s.root.Position.Y)<=12 then
    s.count=s.count+1;r.order=s.count;r.session=s;s.records[#s.records+1]=r
    showSequenceTag(r)
    log(string.format("Assigned light %d at guide+%.3fs",r.order,r.time-g.time))
   end
  end
 end
 if s.target and s.target.ended then advanceOnDisappearance(s,now) end
 -- Calculate first departure continuously from the character's current position.
 if s.waitingDeparture then
  if now-g.time>11 then finish("Shower window ended");return end
  local first
  for _,r in ipairs(s.records) do if not r.ended then first=r;break end end
  if not first then bridge.lastStatus="Waiting for first light; manual input available";return end
  if first.ended then finish("First light expired before departure");return end
  if first.object and first.object.Parent then first.position=first.object.Position end
  local point=contactPoint(s,first,now)
  local realPMS=bridge.realPMS(s.h)
  if not realPMS then bridge.lastStatus="Waiting for valid real in-game PMS";return end
  s.firstRealPMS=math.min(maxSpeed,realPMS*1.2)
  local travel=(point-xy(s.root.Position)).Magnitude/realPMS
  local lead=0.5 -- Aim to reach light 1 half a second before its estimated expiry.
  local departAt=first.time+LIFETIME-lead-travel
  bridge.lastStatus=string.format("Departure in %.2fs | real PMS %.1f | travel %.3fs | arrive 500ms early",math.max(0,departAt-now),realPMS,travel)
  if now<departAt then return end
  s.waitingDeparture=false
  s.firstRealTravel=true
  lockInput(s)
  stopMovementImmediately(s)
  s.target,s.point,s.leg,s.locked=first,point,first.order,false
  log(string.format("Timed first departure; travel %.3fs, lead %.0fms; input locked for all ten lights",travel,lead*1000))
 end
 -- Leave twice the latest reported ping before estimated disappearance.
 -- No unknown destination is invented, and each numbered target advances once.
 local catchLead = bridge.catchLead()
 if catchLead > 0 and s.target and not s.target.ended then
  local current = s.target
  local nextRecord = s.records[current.order + 1]
  if nextRecord and not nextRecord.ended and now >= current.time + LIFETIME - catchLead then
   stopMovementImmediately(s)
   s.firstRealTravel=false
   s.leg = nextRecord.order
   s.target = nextRecord
   s.point = contactPoint(s, nextRecord, now)
   s.locked, s.edgeOptimizedFor = false, nil
   log(string.format("Ping departure: light %d to %d; ping %.1fms, lead %.1fms", current.order, nextRecord.order, catchLead * 500, catchLead * 1000))
  end
 end
 if now-g.time>11 then finish("Shower window ended");return end
 local last=s.records[10]
 if last and last.ended then
  log(string.format("Actual visual removals inside: %d/10",s.caught))
  finish("Ten-light visual sequence complete");return
 end
 advanceOnDisappearance(s,now)
 renderSequence(s)
 if not s.target or not s.point then
  if s.direction and s.direction.Magnitude>0 then stopMovementImmediately(s) end
  hold(s)
  bridge.lastStatus=string.format("Waiting for next light %d to appear | %d positions known | Star Shower has absolute priority",math.max(1,s.leg+1),s.count)
  return
 end
 local centerDistance=(xy(s.root.Position)-xy(s.target.position)).Magnitude
 local inside=centerDistance<=3.8 and math.abs(s.root.Position.Y-s.target.position.Y)<=4
 if inside and not s.target.entryBraked then
  s.firstRealTravel=false
  stopMovementImmediately(s)
  s.target.entryBraked=true
 end
 if centerDistance<=SAFE_RADIUS+0.05 then s.locked=true end
 if s.locked then
  -- Update the edge at most once when the next numbered light first becomes known.
  -- Avoid oscillating between edge destinations every frame.
  local nextRecord=s.records[s.target.order+1]
  if nextRecord and s.edgeOptimizedFor~=s.target then
   s.point=contactPoint(s,s.target,now)
   s.edgeOptimizedFor=s.target
  end
  -- Walk a 0.6-stud-radius circle near the edge facing the next known light.
  -- The 2.05-stud anchor offset keeps the whole path within 2.65 studs.
  local center=xy(s.target.position)
  local nextLight=s.records[s.target.order+1]
  local toward=nextLight and (xy(nextLight.position)-center) or (s.point-center)
  if toward.Magnitude<0.001 then toward=Vector2.new(1,0) end
  local anchor=center+toward.Unit*2.05
  local r=s.target
  -- Reorient once when the next destination becomes known, without teleporting.
  if not r.circleStart or r.circleNext~=nextLight then
   r.circleStart=now
   r.circleNext=nextLight
   local initial=xy(s.root.Position)-anchor
   r.circlePhase=math.atan2(initial.Y,initial.X)
  end
  local phase=r.circlePhase+(now-r.circleStart)*math.pi*2
  local circlePoint=anchor+Vector2.new(math.cos(phase),math.sin(phase))*0.6
  local offset=circlePoint-xy(s.root.Position)
  if centerDistance>3.05 then offset=center-xy(s.root.Position) end
  if offset.Magnitude>0.015 then
   s.direction=Vector3.new(offset.X,0,offset.Y).Unit
   setSpeed(s,math.min(12,offset.Magnitude/math.max(dt,1/120)))
   s.h:Move(s.direction,false)
  else
   s.direction=Vector3.zero
   setSpeed(s,0)
   s.h:Move(Vector3.zero,false)
  end
  bridge.lastStatus=string.format("Circling near next-light edge of light %d | actual removals inside %d/10",s.target.order,s.caught)
  return
 end
 local delta=s.point-xy(s.root.Position)
 local distance=delta.Magnitude
 local available=(s.target.time+LIFETIME)-now-LEAD
 -- Add a travel margin, then shorten the final step to avoid overshooting the safe edge.
 local speed=s.target.order==1 and s.firstRealPMS or (available>0 and math.max(s.originalSpeed*1.15,distance/available*1.2) or maxSpeed)
 speed=math.min(math.clamp(speed,0,s.firstRealTravel and s.firstRealPMS or maxSpeed),distance/math.max(dt,1/120))
 if distance<=0.06 then speed=0 end
 setSpeed(s,speed)
 if distance>0.05 then s.direction=Vector3.new(delta.X,0,delta.Y).Unit;s.h:Move(s.direction,false) else hold(s) end
 bridge.lastStatus=string.format("Chasing light %d | PMS %.1f | lead = 2x ping | positions %d/10",s.target.order,s.speed or 0,s.count)
 if now-s.motionAt>=0.45 then
  local moved=(xy(s.root.Position)-xy(s.motionPosition)).Magnitude
  if moved<0.3 and (s.speed or 0)>10 and s.direction and s.direction.Magnitude>0 then
   log(string.format("Movement stalled: requestedPMS=%.1f actualWalkSpeed=%.1f anchored=%s",s.speed,s.h.WalkSpeed,tostring(s.root.Anchored)))
  end
  s.motionAt,s.motionPosition=now,s.root.Position
 end
end
connect(RunService.Heartbeat,function(dt)
 local ok,err=pcall(updateChase,dt)
 if not ok then
  log("CHASER ERROR: " .. tostring(err))
  finish("Movement stopped by script error");releasePassive()
  bridge.lastStatus="Chaser error: " .. tostring(err) .. ""
  warn("Star Shower chaser: " .. tostring(err))
 end
end)
gui.Destroying:Connect(function() clearSequenceTags();closed=true;for o in pairs(images)do releaseImage(o)end;finish("Closed");releasePassive();RunService:UnbindFromRenderStep(movementBind);for c in pairs(connections) do c:Disconnect() end;table.clear(connections) end)
gui.Parent=player:WaitForChild("PlayerGui")
bridge.cancel=function(reason) finish(reason or "Cancelled");releasePassive() end
bridge.close=function() gui:Destroy() end
renderSequence(nil)
-- Ignore effects already active when launched. Watch future popup activations.
for _,p in ipairs(Players:GetPlayers()) do if p.Character then for _,o in ipairs(p.Character:GetDescendants()) do observeImage(o,true) end end end
for _,o in ipairs(player.PlayerGui:GetDescendants()) do observeImage(o,true) end
local particles=workspace:FindFirstChild("Particles")
if particles then for _,o in ipairs(particles:GetDescendants()) do inspect(o,true) end end

end
 local ok,err=xpcall(startSafeshower,debug.traceback)
 if not ok then
  if bridge.abortStartup then bridge.abortStartup()elseif bridge.close then bridge.close()end
  bridge.active=false
  bridge:ResumeOthers()
  warn("Atlas Safeshower startup: "..tostring(err))
 end
end

threads:Add("Autofarm",worker)
threads:Add("face",worker)
threads:Add("walkspeed",worker)
threads:Add("Stats",worker)
local originalMain=threads:Get("Autofarm")
local stats=threads:Get("Stats")
showerController:Start()
assert(not showerController.active)
local visualOwner=player.PlayerGui:FindFirstChild("AtlasShowerVisuals")
assert(visualOwner and visualOwner:IsA("Folder") and #visualOwner:GetDescendants()==0,"standalone panel still created")
for _,o in ipairs(player.PlayerGui:GetDescendants())do
 assert(not o:IsA("ScreenGui") and not o:IsA("Frame") and not o:IsA("TextButton") and not o:IsA("ScrollingFrame"),"extra shower GUI exists")
end
cfg.autofarm.enabled=false
assert(not showerController.allowed(),"separate shower build must only take over while gathering")
cfg.autofarm.enabled=true
assert(threads:Get("Autofarm")==originalMain,"engine took over without shower")
local other={Name="Other",UserId=456,Character=Instance.new("Model",world)}
local otherHead=Instance.new("Part",other.Character);otherHead.Name="Head"
Players.list[#Players.list+1]=other
local otherBillboard=Instance.new("BillboardGui",otherHead);otherBillboard.Adornee=otherHead
local otherPopup=Instance.new("ImageLabel",otherBillboard)
step(0.02);otherPopup.Image="rbxassetid://5101364168"
makePart("Star Shower Guide",vector(0,0,0))
for i=1,75 do step(0.02)end
assert(not showerController.active and threads:Get("Autofarm")==originalMain,"another player's shower stole control")
local billboard=Instance.new("BillboardGui",head);billboard.Adornee=head
local popup=Instance.new("ImageLabel",billboard)
local oldTween={Cancel=function(self)self.cancelled=true;state.movementTween=nil end,Destroy=function(self)self.destroyed=true end}
state.movementTween=oldTween
step(0.02)
popup.Image="rbxassetid://5101364168"
local guide=makePart("Star Shower Guide",vector(0,0,0))
for i=1,6 do step(0.02)end
assert(showerController.active,"own popup/guide not recognized")
assert(oldTween.cancelled and oldTween.destroyed and not state.movementTween,"existing movement tween survived takeover")
assert(not threads:Get("Autofarm") and not threads:Get("face") and not threads:Get("walkspeed"),"movement workers not suspended")
assert(threads:Get("Stats")==stats,"unrelated stats stopped")
assert(coroutine.status(originalMain)=="dead")
threads:Add("Autofarm",worker)
assert(showerController.active and not threads:Get("Autofarm"),"worker restart stole shower control")
smoothMovement:Reset()
assert(showerController.active,"ordinary movement reset interrupted absolute shower priority")
local lights={}
for i=1,10 do lights[i]={at=now+0.25+(i-1)*0.3,x=i*7}end
local start=now
local activeObserved=false
local numberSeen,targetSeen=false,false
while now-start<6 do
 for _,entry in ipairs(lights)do
  if not entry.object and now>=entry.at then entry.object=makePart("WarningDisk",vector(entry.x,0,0))end
  if entry.object and entry.object.Parent and now>=entry.at+2 then entry.object.Parent=nil end
 end
 step(0.02)
 for _,tag in ipairs(player.PlayerGui:GetChildren())do
  if tag.Name=="StarShowerSequenceDiagnostic"then
   local label=tag:FindFirstChild("Number")
   if label and label.Text:find("#1",1,true)then numberSeen=true end
   if label and label.Text:find("TARGET",1,true)then targetSeen=true end
  end
 end
 if showerController.active and h.WalkSpeed>0 then activeObserved=true;assert(h.WalkSpeed<=180)end
end
assert(activeObserved and not showerController.active,"ten-light sequence did not finish")
assert(numberSeen and targetSeen,"numbered first-star labels or target highlight lost")
assert(threads:Get("Autofarm") and threads:Get("face") and threads:Get("walkspeed"),"normal jobs not resumed")
assert(h.WalkSpeed==40 and controls.controlsEnabled and workspace.CurrentCamera.CameraType=="Custom","speed/input/camera not restored")
assert(next(RunService.bound)==nil and next(actionService.bound)==nil,"render/input binding retained")
assert(#warns==0,"engine error: "..tostring(warns[1]))
-- Repeated popup lifecycles must not leave three listeners per destroyed image.
local before=liveConnections
for i=1,500 do
 local image=Instance.new("ImageLabel",billboard)
 step(0.002)
 image:Destroy()
end
assert(liveConnections==before,"destroyed popup connections accumulated")
-- Start another owned shower, then unload during it.
popup.Visible=false;step(0.02);popup.Visible=true
makePart("Star Shower Guide",vector(0,0,0))
for i=1,6 do step(0.02)end
assert(showerController.active)
state.stop=true;step(0.02)
assert(not showerController.active and not threads:Get("Autofarm"),"Stop Everything failed or resumed farming")
assert(h.WalkSpeed==40 and controls.controlsEnabled and next(RunService.bound)==nil)
state.stop=false;threads:Add("Autofarm",worker)
for i=1,130 do step(0.02)end
popup.Visible=false;step(0.02);popup.Visible=true
makePart("Star Shower Guide",vector(0,0,0))
for i=1,6 do step(0.02)end
assert(showerController.active)
showerController:Shutdown()
assert(not showerController.active and not threads:Get("Autofarm"),"unload restarted suspended farming")
assert(h.WalkSpeed==40 and controls.controlsEnabled and next(RunService.bound)==nil)
assert(next(showerController.paused)==nil)
threads:CancelAll();connections:CancelAll()
print("PASS: supplied engine startup, other-player rejection, own popup/guide detection, exclusive movement, restart suppression, ten observed light removals, normal-task resumption, speed/input/camera restoration, 500 popup lifecycles, mid-shower unload")
