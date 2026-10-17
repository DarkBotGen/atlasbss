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
threads.Add = function(manager, threadId, callback, delaySeconds, ...)
	if manager.closed then return end
	local exclusive = smoothMovement.showerController
	if exclusive and exclusive.active and exclusive:IsMovementJob(threadId) then
		exclusive.paused[threadId] = {callback=callback,args=table.pack(...),delaySeconds=delaySeconds}
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
  return not bridge.shuttingDown and cfg and state and not state.stop and cfg.autofarm.farmshowers
   and (cfg.autofarm.enabled or cfg.detected.background)
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
local Input=game:GetService("UserInputService")
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
local lastRun=nil
-- Session-local history survives re-running this LocalScript through the executor.
local historyKey="StarShower100Intervals_" .. player.UserId
if type(env[historyKey])~="table" then env[historyKey]={} end
local runHistory=env[historyKey]
while #runHistory>10 do table.remove(runHistory,1) end
local runSerialKey=historyKey.."_counter"
env[runSerialKey]=tonumber(env[runSerialKey]) or 0
local armed,closed,maxSpeed=true,false,180
local movementBind="StarShowerX10Movement_" .. player.UserId
local session,controls=nil,nil
local passive=nil
local tokenCooldown=setmetatable({}, {__mode="k"})
local tokenArt=setmetatable({}, {__mode="k"})
local triggers,lights,guides,connections,history={},{},{},{},{}
local seen=setmetatable({}, {__mode="k"})
local images={} -- explicit per-popup connection lifetime
local ownerLast={}
local old=player.PlayerGui:FindFirstChild("SafeshowerStandalone")
if old then old:Destroy() end
local gui=Instance.new("ScreenGui")
bridge.close=function()gui:Destroy()end
gui.Name,gui.ResetOnSpawn="StarShowerX10",false
local frame=Instance.new("Frame")
frame.Size,frame.Position,frame.BackgroundColor3=UDim2.fromOffset(510,550),UDim2.fromOffset(20,90),Color3.fromRGB(31,29,56)
frame.BorderSizePixel,frame.Parent=0,gui
Instance.new("UICorner",frame).CornerRadius=UDim.new(0,8)
local function ui(text,x,y,w,h)
 local b=Instance.new("TextButton")
 b.Text,b.Position,b.Size=text,UDim2.fromOffset(x,y),UDim2.fromOffset(w,h)
 b.BackgroundColor3,b.TextColor3,b.BorderSizePixel=Color3.fromRGB(47,40,70),Color3.fromRGB(238,226,250),0
 b.Font,b.TextSize,b.Parent=Enum.Font.Gotham,12,frame
 return b
end
local title=ui("Atlas+ Safeshower — real PMS / 180 cap",10,8,450,28)
local close=ui("X",470,8,30,28)
local arm=ui("Armed: ON",10,44,150,28)
local limit=ui("Maximum PMS: 180 (fixed)",170,44,170,28)
local copy=ui("Copy run report",350,44,150,28)
local status=ui("Waiting for your Star Shower passive…",10,82,490,82)
status.TextWrapped=true;status.AutoButtonColor=false
local intervalDisplay=ui("Runs: 0/10 | Points: 0/100",10,173,490,42)
intervalDisplay.TextWrapped=true;intervalDisplay.AutoButtonColor=false
local help=ui("Passive token collection at live real PMS. First light: aim 500ms early. Lights 2–10: up to 180 PMS, live 2x ping. Manual input locks at departure. Right Shift cancels. Timings are estimates.",10,219,490,52)
help.TextWrapped=true;help.AutoButtonColor=false
local function makeLabel(parent,text,x,y,w,h,size)
 local l=Instance.new("TextLabel")
 l.BackgroundTransparency=1
 l.TextColor3=Color3.fromRGB(238,226,250)
 l.Font=Enum.Font.Gotham
 l.TextSize=size or 12
 l.TextXAlignment=Enum.TextXAlignment.Left
 l.Text=text
 l.Position=UDim2.fromOffset(x,y)
 l.Size=UDim2.fromOffset(w,h)
 l.Parent=parent
 return l
end
local graphPanel=Instance.new("ScrollingFrame")
graphPanel.Position=UDim2.fromOffset(10,280)
graphPanel.Size=UDim2.fromOffset(490,258)
graphPanel.BackgroundColor3=Color3.fromRGB(24,22,42)
graphPanel.BorderSizePixel=0
graphPanel.ScrollBarThickness=6
graphPanel.CanvasSize=UDim2.fromOffset(0,530)
graphPanel.ScrollingDirection=Enum.ScrollingDirection.Y
graphPanel.Parent=frame
Instance.new("UICorner",graphPanel).CornerRadius=UDim.new(0,8)
makeLabel(graphPanel,"Guide→1 | 1→2 | 2→3 | ... | 9→10    (seconds)",48,7,420,17,11)
local graphRows={}
for r=1,10 do
 local y=30+(r-1)*49
 local name=makeLabel(graphPanel,string.format("%02d",r),8,y+11,32,20,13)
 local slots={}
 for c=1,10 do
  local x=44+(c-1)*43
  local bg=Instance.new("Frame")
  bg.Position=UDim2.fromOffset(x,y)
  bg.Size=UDim2.fromOffset(41,42)
  bg.BackgroundColor3=Color3.fromRGB(37,34,60)
  bg.BorderSizePixel=0
  bg.Parent=graphPanel
  local value=makeLabel(bg,"--",0,0,41,16,10)
  value.TextXAlignment=Enum.TextXAlignment.Center
  local bar=Instance.new("Frame")
  bar.AnchorPoint=Vector2.new(0,1)
  bar.Position=UDim2.new(0.08,0,1,-2)
  bar.Size=UDim2.new(0.84,0,0,0)
  bar.BackgroundColor3=Color3.fromRGB(90,170,255)
  bar.BorderSizePixel=0
  bar.Parent=bg
  slots[c]={value=value,bar=bar}
 end
 graphRows[r]={name=name,slots=slots}
end
local graphFoot=makeLabel(graphPanel,"Bars scale to the largest interval shown. No points are excluded.",8,521,467,14,11)
graphPanel.CanvasSize=UDim2.fromOffset(0,542)
-- Local-only diagnostics: every disk is tagged with its detected sequence number.
local sequenceGui=Instance.new("Frame")
sequenceGui.Name="SequenceDiagnostics"
sequenceGui.Position=UDim2.fromOffset(520,0)
sequenceGui.Size=UDim2.fromOffset(188,308)
sequenceGui.BackgroundColor3=Color3.fromRGB(31,29,56)
sequenceGui.BorderSizePixel=0
sequenceGui.Parent=frame
Instance.new("UICorner",sequenceGui).CornerRadius=UDim.new(0,8)
makeLabel(sequenceGui,"LIGHT SEQUENCE",9,8,173,20,13)
local sequenceRows={}
for i=1,10 do
 sequenceRows[i]=makeLabel(sequenceGui,string.format("#%02d   Waiting",i),10,25+(i-1)*26,170,23,12)
end
makeLabel(sequenceGui,"Labels appear above each disk",8,286,175,18,10)
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
 tag.Parent=gui
 sequenceTags[r.object]=tag
 r.diagnosticTag=tag
end
local function renderSequence(s)
 for i=1,10 do
  local r=s and s.records[i]
  local state=not r and "Waiting" or (r.ended and "Removed" or (s.target==r and "TARGET" or "Spawned"))
  sequenceRows[i].Text=string.format("#%02d   %s",i,state)
  sequenceRows[i].TextColor3=(r and r.ended) and Color3.fromRGB(165,165,180)
   or (r and s.target==r) and Color3.fromRGB(120,255,150)
   or r and Color3.fromRGB(120,195,255) or Color3.fromRGB(238,226,250)
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
local function log(text) history[#history+1]=string.format("%.3f %s",os.clock(),text);if #history>400 then table.remove(history,1) end end
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
 lastRun=s
 if s.tracked then
  s.tracked.complete=true
  for i=1,10 do
   local r=s.records[i]
   local previous=i==1 and s.guide.time or (s.records[i-1] and s.records[i-1].time)
   if r and r.time and previous then
    local lagged=r.spawnLagged or (i==1 and s.guide.lagged)
    if i>1 and s.records[i-1] then
     lagged=lagged or s.records[i-1].spawnLagged or (r.spawnStallCounter~=s.records[i-1].spawnStallCounter)
    end
    s.tracked.points[i]={seconds=r.time-previous,flagged=not not lagged}
   end
  end
 end
 pcall(function() s.h:Move(Vector3.zero,false);s.h.WalkSpeed=s.originalSpeed end)
 if env[leaseKey]==s.lease then env[leaseKey]=s.previousLease end
 RunService:UnbindFromRenderStep(movementBind)
 if controls and s.restoreControls then pcall(function() controls:Enable() end) end
 local text=string.format("%s | inside at collection time: %d / 10; seen: %d",reason,s.caught,s.count)
 log(text);status.Text=text
 if bridge.resumeOtherMovement then bridge.resumeOtherMovement() end
end
local function setSpeed(s,value)
 if s.isPassive then s.speed=s.h.WalkSpeed;return end
 local cap = s.firstRealTravel and s.firstRealPMS or maxSpeed
 value=math.clamp(value,0,cap)
 s.lease.speed,s.lease.expires=value,os.clock()+0.3
 env[leaseKey]=s.lease
 if s.h.WalkSpeed~=value then s.h.WalkSpeed=value end
 s.speed=value
end
local function bindMovement(s)
 RunService:BindToRenderStep(movementBind,Enum.RenderPriority.Character.Value+1,function()
  if closed or not bridge.allowed() or (session~=s and passive~=s) or not s.root.Parent or s.h.Health<=0 then return end
  if s.waitingDeparture then return end
  if s.isPassive then
   s.h:Move(s.direction or Vector3.zero,false)
   return
  end
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
local function defaultPMS(s)
 -- Read the live game speed, never Armageddon's saved slider or a fixed value.
 local value=s.h and s.h.WalkSpeed
 if type(value)=="number" and value==value and value>=0 and value<math.huge then return value end
 return 0
end
local function jellybean(token)
 local ids=tokenArt[token]
 if not ids then
  ids={}
  local function inspectArtwork(o)
   local texture
   if o:IsA("Decal") or o:IsA("Texture") then texture=o.Texture
   elseif o:IsA("SpecialMesh") then texture=o.TextureId
   elseif o:IsA("MeshPart") then texture=o.TextureID end
   if texture then
    local id=texture:match("rbxassetid://(%d+)") or texture:match("[?&]id=(%d+)")
    if id then ids[#ids+1]=id end
   end
  end
  inspectArtwork(token)
  for _,o in ipairs(token:GetDescendants()) do inspectArtwork(o) end
  if #ids>0 then tokenArt[token]=ids end
 end
 local blocked=env.ArmageddonJellybeanArt
 for _,id in ipairs(ids) do if id=="3080529618" or (type(blocked)=="table" and blocked[id]) then return true end end
 return false
end
local function tokenPosition(token)
 if token:IsA("BasePart") then return token.Position end
 if token:IsA("Model") then return token:GetPivot().Position end
end
local function collectTokens(s,dt)
 local now=os.clock()
 if not s.nextTokenScan or now>=s.nextTokenScan or (s.token and not s.token.Parent) then
  s.nextTokenScan=now+0.15;s.token=nil
  local folder=workspace:FindFirstChild("Collectibles")
  local best=80
  if folder then
   for _,token in ipairs(folder:GetChildren()) do
    if token.Name=="C" and (tokenCooldown[token] or 0)<=now and not jellybean(token) then
     local p=tokenPosition(token)
     if p and math.abs(p.Y-s.root.Position.Y)<=8 then
      local distance=(xy(p)-xy(s.root.Position)).Magnitude
      if distance<best then best=distance;s.token=token end
     end
    end
   end
  end
 end
 local speed=defaultPMS(s)
 setSpeed(s,speed)
 if s.token and s.token.Parent then
  local p=tokenPosition(s.token)
  if p then
   local delta=xy(p)-xy(s.root.Position)
   if delta.Magnitude>1 then
    s.direction=Vector3.new(delta.X,0,delta.Y).Unit;s.h:Move(s.direction,false)
    status.Text=string.format("Passive tokens | default PMS %.1f%s",speed,session and " | Star Shower lights take priority" or " | watching for your shower")
    return true
   end
   tokenCooldown[s.token]=now+1;s.token=nil;s.nextTokenScan=0
  end
 end
 s.direction=Vector3.zero;s.h:Move(Vector3.zero,false)
 return false
end
local function releasePassive()
 local p=passive;if not p then return end;passive=nil
 RunService:UnbindFromRenderStep(movementBind)
 pcall(function() p.h:Move(Vector3.zero,false) end)
 if env[leaseKey]==p.lease then env[leaseKey]=p.previousLease end
 if controls and p.restoreControls then pcall(function() controls:Enable() end) end
end
local function updatePassive(dt)
 local character,h,root=atRoot()
 if passive and (passive.character~=character or not passive.root.Parent or passive.h.Health<=0) then releasePassive() end
 if not h or not root or h.Health<=0 then return end
 if not passive then
  if not controls then pcall(function() local m=player.PlayerScripts:FindFirstChild("PlayerModule");if m then controls=require(m):GetControls() end end) end
  passive={isPassive=true,character=character,h=h,root=root,originalSpeed=h.WalkSpeed,previousLease=env[leaseKey],lease={},restoreControls=controls and controls.controlsEnabled~=false,direction=Vector3.zero}
  if controls then controls:Disable() end
  bindMovement(passive)
 end
 if not collectTokens(passive,dt) then status.Text="No nearby eligible tokens | watching for your Star Shower" end
end
local function begin(g)
 if session or not armed or not bridge.allowed() then return end
 releasePassive()
 local char,h,root=atRoot();if not h or not root or h.Health<=0 then return end
 if not controls then
  pcall(function() local m=player.PlayerScripts:FindFirstChild("PlayerModule");if m then controls=require(m):GetControls() end end)
 end
 if closed or not armed or session then return end
 local s={guide=g,character=char,h=h,root=root,originalSpeed=h.WalkSpeed,restoreControls=controls and controls.controlsEnabled~=false,
  previousLease=env[leaseKey],lease={},motionAt=os.clock(),motionPosition=root.Position,records={},count=0,caught=0,target=nil,point=nil,locked=false,nextPlan=0}
 session=s
 s.waitingDeparture=true
 bridge.active=true
 if bridge.pauseOtherMovement then bridge.pauseOtherMovement() end
 if bridge.allowManualWaiting then bridge.allowManualWaiting() end
 clearSequenceTags()
 renderSequence(s)
 env[runSerialKey]=env[runSerialKey]+1
 local tracked={number=env[runSerialKey],guideTime=g.time,points={},complete=false}
 runHistory[#runHistory+1]=tracked
 if #runHistory>10 then table.remove(runHistory,1) end
 s.tracked=tracked
 log("Guide recognized; tracking each disk in observed spawn order, no 0.3s schedule")
 s.leg=0;s.predictedCaught=0
 s.direction=Vector3.zero
 bindMovement(s)
 log("Own guide accepted; x10 route armed")
 status.Text="Your Star Shower detected. Planning disappearance deadlines…"
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
 return center+direction.Unit*SAFE_RADIUS
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
     g.resolved=true;status.Text="Overlapping guide owners: not guessing ownership.";log("Guide rejected: overlapping popup owners")
    elseif now-g.time>1.25 then
     g.resolved=true
     local reason=count==0 and "Guide detected, but your passive popup was not detected." or "Guide belongs to another player's popup."
     status.Text=reason;log(reason)
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
 -- Calculate first departure continuously from the character's current position.
 if s.waitingDeparture then
  if now-g.time>11 then finish("Shower window ended");return end
  local first=s.records[1]
  if not first then status.Text="Waiting for first light; manual input available";return end
  if first.ended then finish("First light expired before departure");return end
  if first.object and first.object.Parent then first.position=first.object.Position end
  local point=contactPoint(s,first,now)
  local realPMS=bridge.realPMS(s.h)
  if not realPMS then status.Text="Waiting for valid real in-game PMS";return end
  s.firstRealPMS=realPMS
  local travel=(point-xy(s.root.Position)).Magnitude/realPMS
  local lead=0.5 -- Aim to reach light 1 half a second before its estimated expiry.
  local departAt=first.time+LIFETIME-lead-travel
  status.Text=string.format("Departure in %.2fs | real PMS %.1f | travel %.3fs | arrive 500ms early",math.max(0,departAt-now),realPMS,travel)
  if now<departAt then return end
  s.waitingDeparture=false
  s.firstRealTravel=true
  lockInput(s)
  stopMovementImmediately(s)
  s.target,s.point,s.leg,s.locked=first,point,1,false
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
  status.Text=string.format("Waiting for next light %d to appear | %d positions known | Star Shower has absolute priority",math.max(1,s.leg+1),s.count)
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
  status.Text=string.format("Circling near next-light edge of light %d | actual removals inside %d/10",s.target.order,s.caught)
  return
 end
 local delta=s.point-xy(s.root.Position)
 local distance=delta.Magnitude
 local available=(s.target.time+LIFETIME)-now-LEAD
 -- Only request the speed estimated to reach the safe edge before disappearance.
 -- Zero is allowed; do not force a 36.8 or 50 PMS minimum.
 local speed=s.target.order==1 and s.firstRealPMS or (available>0 and distance/available or maxSpeed)
 speed=math.clamp(speed,0,s.firstRealTravel and s.firstRealPMS or maxSpeed)
 if distance<=0.06 then speed=0 end
 setSpeed(s,speed)
 if distance>0.05 then s.direction=Vector3.new(delta.X,0,delta.Y).Unit;s.h:Move(s.direction,false) else hold(s) end
 status.Text=string.format("Chasing light %d | PMS %.1f | lead = 2x ping | positions %d/10",s.target.order,s.speed or 0,s.count)
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
  status.Text="Chaser error: " .. tostring(err) .. " — Copy last run"
  warn("Star Shower chaser: " .. tostring(err))
 end
end)
connect(arm.Activated,function() armed=not armed;arm.Text=armed and "Armed: ON" or "Armed: OFF";if not armed then finish("Disarmed");releasePassive() end end)
limit.Active,limit.AutoButtonColor,limit.Selectable=false,false,false
-- Record ten time differences per Guide; keep the last ten guides (100 points).
-- Every valid observation is INCLUDED. Stall markers are descriptive only.
local function captureCurrent(s)
 if not s or not s.tracked then return end
 local tracked=s.tracked
 tracked.guideTime=s.guide.time
 local records=s.records
 for i=1,10 do
  local current=records[i]
  if current and current.time then
   local before=(i==1) and s.guide.time or (records[i-1] and records[i-1].time)
   if before then
    local flagged=current.spawnLagged or (i==1 and s.guide.lagged)
    if i>1 and records[i-1] then
     flagged=flagged or records[i-1].spawnLagged or current.spawnStallCounter~=records[i-1].spawnStallCounter
    elseif i==1 then
     flagged=flagged or current.spawnStallCounter~=(s.guide.stallCounter or 0)
    end
    tracked.points[i]={seconds=current.time-before, flagged=not not flagged}
   end
  end
 end
end
local function allIntervalsReport()
 local lines={"Star Shower - last 10 guides, every observed interval (NO outlier removal)",
 "Column 1 = Guide to light 1; columns 2-10 = successive light spawn gaps.",
 "[STALL] means a possible client stall, but this value IS INCLUDED."}
 local total,n=0,0
 for r,run in ipairs(runHistory) do
  local sum,count=0,0
  lines[#lines+1]=string.format("\nGuide %d (run #%d): %s",r,run.number,run.complete and "completed" or "in progress")
  for i=1,10 do
   local point=run.points[i]
   if point and type(point.seconds)=="number" then
    sum=sum+point.seconds;count=count+1;total=total+point.seconds;n=n+1
    lines[#lines+1]=string.format("  %s: %.5fs%s",i==1 and "Guide→1" or string.format("%d→%d",i-1,i),point.seconds,point.flagged and " [STALL]" or "")
   else
    lines[#lines+1]=string.format("  %s: NOT OBSERVED",i==1 and "Guide→1" or string.format("%d→%d",i-1,i))
   end
  end
  lines[#lines+1]=string.format("  Raw mean: %s | %d/10 points",count>0 and string.format("%.5fs",sum/count) or "N/A",count)
 end
 lines[#lines+1]=string.format("\nALL GUIDES raw average: %s (%d/100 points)",n>0 and string.format("%.5fs",total/n) or "N/A",n)
 return table.concat(lines,"\n")
end
local function drawHistory()
 local maxValue=0.4
 local sum,count,flagCount=0,0,0
 for _,run in ipairs(runHistory) do
  for i=1,10 do
   local point=run.points[i]
   if point and type(point.seconds)=="number" then
    maxValue=math.max(maxValue,point.seconds)
    sum=sum+point.seconds;count=count+1
    if point.flagged then flagCount=flagCount+1 end
   end
  end
 end
 for r=1,10 do
  local run=runHistory[r]
  local row=graphRows[r]
  row.name.Text=run and string.format("%02d",run.number) or "--"
  for c=1,10 do
   local item=run and run.points[c]
   local target=row.slots[c]
   if item and type(item.seconds)=="number" then
    target.value.Text=string.format("%.3f",item.seconds)
    target.bar.Size=UDim2.new(0.84,0,0,math.max(2,math.floor(23*math.max(0,item.seconds)/maxValue)))
    target.bar.BackgroundColor3=item.flagged and Color3.fromRGB(214,137,16) or Color3.fromRGB(90,170,255)
   else
    target.value.Text="--"
    target.bar.Size=UDim2.new(0.84,0,0,0)
   end
  end
 end
 local mean=count>0 and string.format("%.4fs (%.1fms)",sum/count,sum/count*1000) or "waiting"
 intervalDisplay.Text=string.format("Guides: %d/10 | Points: %d/100 | Raw mean: %s | Flagged: %d (included)",#runHistory,count,mean,flagCount)
end
local statsElapsed=0
connect(RunService.Heartbeat,function(dt)
 if closed then return end
 statsElapsed=statsElapsed+dt
 if statsElapsed<0.25 then return end
 statsElapsed=0
 captureCurrent(session)
 drawHistory()
end)
connect(copy.Activated,function()
 if bridge.copy then bridge.copy() end
end)
connect(Input.InputBegan,function(input)
 if input.KeyCode==Enum.KeyCode.RightShift then
  armed=false;arm.Text="Armed: OFF";finish("Cancelled");releasePassive()
 end
end)
connect(close.Activated,function() gui:Destroy() end)
gui.Destroying:Connect(function() clearSequenceTags();closed=true;for o in pairs(images)do releaseImage(o)end;finish("Closed");releasePassive();RunService:UnbindFromRenderStep(movementBind);for c in pairs(connections) do c:Disconnect() end;table.clear(connections) end)
do
 local dragging,touch,origin,original
 title.Active=true
 connect(title.InputBegan,function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then dragging=true;touch=i.UserInputType==Enum.UserInputType.Touch and i or nil;origin=i.Position;original=frame.Position end end)
 connect(Input.InputChanged,function(i) if dragging and ((touch and i==touch) or (not touch and i.UserInputType==Enum.UserInputType.MouseMovement)) then local d=i.Position-origin;frame.Position=UDim2.new(original.X.Scale,original.X.Offset+d.X,original.Y.Scale,original.Y.Offset+d.Y) end end)
 connect(Input.InputEnded,function(i) if i==touch or i.UserInputType==Enum.UserInputType.MouseButton1 then dragging=false;touch=nil end end)
end
gui.Name="SafeshowerStandalone"
gui:SetAttribute("ArmageddonGui",true)
gui.Enabled=true
gui.Parent=player:WaitForChild("PlayerGui")
bridge.cancel=function(reason) finish(reason or "Cancelled");releasePassive() end
bridge.close=function() gui:Destroy() end
bridge.copy=function()
 captureCurrent(session)
 local report=allIntervalsReport() .. "\n\nEvent history:\n" .. table.concat(history,"\n")
 local current=session or lastRun
 if current then
  for _,field in ipairs({"time","removedAt"}) do
   local sum,count=0,0
   report=report .. "\n" .. (field=="time" and "Successive observed spawn intervals:" or "Successive observed removal intervals:")
   for i=2,10 do
    local before,after=current.records[i-1],current.records[i]
    if before and after and before[field] and after[field] then
     local gap=after[field]-before[field]
     sum=sum+gap;count=count+1
     report=report .. string.format("\n%d→%d: %.5fs",i-1,i,gap)
    else report=report .. string.format("\n%d→%d: NOT OBSERVED",i-1,i) end
   end
   report=report .. "\nAverage: " .. (count>0 and string.format("%.5fs (%d intervals)",sum/count,count) or "N/A")
  end
 end
 print(report)
 local clipboard=setclipboard or toclipboard
 if type(clipboard)=="function" then pcall(clipboard,report) end
 if type(writefile)=="function" then pcall(writefile,"SafeshowerReport.txt",report) end
 return report
end
connect(status:GetPropertyChangedSignal("Text"),function() bridge.lastStatus=status.Text end)
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

local before=liveConnections
function player:WaitForChild()error("expected startup failure")end
showerController:Start()
assert(#warns==1 and not showerController.active)
assert(liveConnections==before,"partial startup retained listeners")
assert(next(RunService.bound)==nil and next(actionService.bound)==nil)
print("PASS: partial startup failure releases engine listeners, GUI and render bindings")
