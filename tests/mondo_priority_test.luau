local now=0
local os={clock=function()return now end}
local mondoHop
local cfg={autofarm={enabled=true},combat={mondohop=true}}
local state={config="Preset 1"}
local localPlayer={UserId=1,Name="Player",Character={}}
local decoded
local HttpService={JSONEncode=function(_,v)return v end,JSONDecode=function(_,v)return v end,UrlEncode=function(_,v)return v end}
local files={}
local function writefile(path,value)files[path]=value end
local function readfile(path)return files[path] end
local function isfile(path)return files[path]~=nil end
local function saveConfig()end
local game={PlaceId=1,JobId="home",PrivateServerId="private",HttpGet=function()return decoded end}
local teleports={}
local TeleportService={TeleportToPlaceInstance=function(_,place,job,player)table.insert(teleports,job)end}
local threads={jobs={},list={},closed=false}
function threads:Cancel(id)self.list[id]=nil;self.jobs[id]=nil end
function threads:Get(id)return self.list[id]end
function threads:Add(id,cb,delay,...)self.list[id]=cb;self.jobs[id]={callback=cb,delaySeconds=delay,args=table.pack(...)}end
local showerController={Reset=function()end,IsMovementJob=function(_,id)return id=="Autofarm" or id=="fasttween" end}
local comboController={Finish=function()end}
local crabPlatformSupport={Release=function()end}
local meteorMovement={Release=function()end}
local fieldPositionPolicy={ReleaseIdle=function()end,RemoveGuards=function()end}
local function stopMovement()end
local ui={Notify=function()end}
local function warn()end
mondoHop={paused={},visited={},active=false,teleporting=false}
function mondoHop:IsMovementJob(id) return showerController:IsMovementJob(id) end
function mondoHop:Window(now)
	local hour=math.floor(now/3600)
	return hour,now-hour*3600<870,hour*3600+870
end
function mondoHop:Save()
	writefile("atlas-mondohop-"..localPlayer.UserId..".json",HttpService:JSONEncode(self.session or {}))
end
function mondoHop:Load()
	local path="atlas-mondohop-"..localPlayer.UserId..".json"
	if not isfile(path) then return end
	local ok,value=pcall(function()return HttpService:JSONDecode(readfile(path))end)
	if ok and type(value)=="table" and value.place==game.PlaceId and type(value.homeJob)=="string" and type(value.hour)=="number" and type(value.deadline)=="number" then
		self.session=value
		self.visited=type(value.visited)=="table" and value.visited or {}
	end
end
function mondoHop:TakeMovement()
	if self.active then return end
	self.active=true
	self.previousStopFast=state.stopfasttween
	state.stopfasttween=true
	showerController:Reset()
	comboController:Finish("Mondo priority")
	crabPlatformSupport:Release()
	meteorMovement:Release()
	fieldPositionPolicy:ReleaseIdle();fieldPositionPolicy:RemoveGuards()
	for id,job in pairs(threads.jobs or {}) do
		if showerController:IsMovementJob(id) then self.paused[id]=job end
	end
	for id in pairs(self.paused) do threads:Cancel(id) end
	if state.movementTween then
		local tween=state.movementTween
		state.movementTween=nil
		tween:Cancel()
		tween:Destroy()
	end
	state.fasttween=nil
	stopMovement()
end
function mondoHop:Resume()
	if not self.active then return end
	self.active=false
	if state then state.mondoHopActive=nil;state.stopfasttween=self.previousStopFast end
	local paused=self.paused;self.paused={}
	if threads.closed or not state or state.stop then return end
	for id,job in pairs(paused) do
		if id~="Autofarm" or cfg.autofarm.enabled or cfg.rbc.enabled then
			if not threads:Get(id) then threads:Add(id,job.callback,job.delaySeconds,table.unpack(job.args,1,job.args.n)) end
		end
	end
end
function mondoHop:PublicServer()
	local cursor=""
	for page=1,3 do
		local url="https://games.roblox.com/v1/games/"..game.PlaceId.."/servers/Public?sortOrder=Asc&limit=100"
		if cursor~="" then url..="&cursor="..HttpService:UrlEncode(cursor) end
		local payload=HttpService:JSONDecode(game:HttpGet(url))
		local choices={}
		for _,server in ipairs(payload.data or {}) do
			if type(server.id)=="string" and server.id~=game.JobId and server.playing<server.maxPlayers and not self.visited[server.id] then table.insert(choices,server.id) end
		end
		if #choices>0 then return choices[math.random(1,#choices)] end
		cursor=payload.nextPageCursor or ""
		if cursor=="" then break end
	end
end
function mondoHop:Teleport(home)
	if self.teleporting or self.returnNotice or os.clock()<(self.retryAt or 0) then return end
	local session=self.session
	local destination=home and session.homeJob or self:PublicServer()
	if not destination then self.retryAt=os.clock()+10;return end
	saveConfig()
	writefile("atlas-"..localPlayer.Name..".json",state.config..".json")
	self.teleporting=true;self.sentAt=os.clock();self.returning=home
	session.returning=home or nil
	if not home then
		self.visited[game.JobId]=true
		local count=0;for _ in pairs(self.visited)do count+=1 end
		if count>100 then self.visited={[game.JobId]=true} end
		session.visited=self.visited
	end
	self:Save()
	local ok,err=pcall(function()TeleportService:TeleportToPlaceInstance(game.PlaceId,destination,localPlayer)end)
	if not ok then self:Failed(tostring(err)) end
end
function mondoHop:Failed(reason)
	self.teleporting=false;self.retryAt=os.clock()+15
	if self.returning and not self.returnNotice then
		self.returnNotice=true
		ui.Notify("Mondo Hop return failed","Roblox rejected private-server return. Use your saved invite link; hopping is paused.",15)
		warn("Mondo Hop: private-server return failed; the original instance may have closed. "..tostring(reason))
	end
end

local tracked={mondo={Parent=true}}
localPlayer.Character.FindFirstChildOfClass=function()return {Health=100} end
local fights=0
local fail=false
local function killMondo(_,_,hop,priority)
 assert(not hop and priority,"priority must not enter hop mode")
 assert(not threads:Get("Autofarm") and mondoHop.active,"farming job still owns movement")
 assert(not state.movementTween and not state.fasttween,"old travel still active")
 fights+=1
 if fail then error("simulated fight failure") end
end
function mondoHop:RunPriority()
	if self.active or self.teleporting or state.stop or not cfg.combat.mondopriority then return end
	local mondo=tracked.mondo
	if not mondo or not mondo.Parent then return end
	local character=localPlayer.Character
	local humanoid=character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health<=0 then return end
	local ok,err=pcall(function()
		self:TakeMovement()
		killMondo(nil,nil,nil,true)
	end)
	pcall(stopMovement)
	self:Resume()
	if not ok and err~="return" then warn("Mondo priority: "..tostring(err)) end
end

threads:Add("Autofarm",function()end)
mondoHop:RunPriority();assert(fights==0)
cfg.combat.mondopriority=true
local destroyed=false
state.movementTween={Cancel=function()end,Destroy=function()destroyed=true end}
state.fasttween=true
mondoHop:RunPriority()
assert(fights==1 and destroyed and threads:Get("Autofarm") and not mondoHop.active)
fail=true
mondoHop:RunPriority()
assert(fights==2 and threads:Get("Autofarm") and not mondoHop.active)
assert(#teleports==0)
tracked.mondo=nil
mondoHop:RunPriority();assert(fights==2)
print("PASS: priority preempts movement, resumes after completion or error, and never teleports")
