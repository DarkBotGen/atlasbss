local now=10
local os={clock=function()return now end}
local mt={}
local Vector3={new=function(x,y,z)return setmetatable({X=x,Y=y,Z=z},mt)end}
mt.__index=function(v,k) if k=="Magnitude" then return math.sqrt(v.X*v.X+v.Y*v.Y+v.Z*v.Z) end; if k=="Dot" then return function(a,b)return a.X*b.X+a.Y*b.Y+a.Z*b.Z end end end
mt.__sub=function(a,b)return Vector3.new(a.X-b.X,a.Y-b.Y,a.Z-b.Z)end
local root={Position=Vector3.new(0,0,0)}
local moves=0
local humanoid={Health=100,WalkSpeed=40,MoveTo=function(_,p)moves+=1;root.Position=p end}
local function getRootPart()return root end
local function getHumanoid()return humanoid end
local function distanceTo(p)return (p-root.Position).Magnitude end
local currentField={}
local function getFieldAt()return currentField end
local function isPathClear()return false end
local cfg={autofarm={farmdupedtokens=true,smileytime=4}}
local tracked={dupedsmiley={}}
local touchedMarks={}
local showerController={active=false}
local state={}
local onHeartbeat
local RunService={Heartbeat={Wait=function()now+=.05;if onHeartbeat then onHeartbeat() end end}}
		local function pickFastSmiley(opts)
			if not (cfg.autofarm.farmdupedtokens or opts.dupedtokensquest) then return end
			local now,root,best,bestDistance=os.clock(),getRootPart().Position,nil,math.huge
			for key,value in pairs(tracked.dupedsmiley) do
				local object=type(key)=="number" and value or key
				local virtual=type(object)=="table" and object.Name==true
				if not virtual and not object.Parent then tracked.dupedsmiley[key]=nil;continue end
				if touchedMarks[object] then continue end
				local start=virtual and object.Start or value
				if type(start)~="number" or now-start<(tonumber(cfg.autofarm.smileytime) or 4) then continue end

				local point=object.Position-Vector3.new(0,10,0)
				if not opts.ignorefield and getFieldAt(point)~=currentField then continue end
				if opts.range and opts.origin and (opts.origin-point).Magnitude>=opts.range then continue end
				if opts.avoid and isPathClear(point,opts.avoid) then continue end
				local delta=Vector3.new(point.X-root.X,0,point.Z-root.Z)
				local distance=delta:Dot(delta)
				if distance<bestDistance then best,bestDistance=object,distance end
			end
			return best
		end
		local function collectFastSmiley(object,opts)
			-- Smiley tokens need sustained contact: proximity alone is not collection.
			local deadline=os.clock()+math.min(4,distanceTo(object.Position,true)/math.max(1,getHumanoid().WalkSpeed)+.75)+6
			local nextMove=0
			while os.clock()<deadline do
				if showerController.active or state.stop then return true end
				if object.Name==true then
					if tracked.dupedsmiley[object.ID]~=object then return true end
				elseif not object.Parent then
					tracked.dupedsmiley[object]=nil
					return true
				end
				local humanoid=getHumanoid()
				if humanoid.Health<=0 then return true end
				local root=getRootPart().Position
				local point=Vector3.new(object.Position.X,root.Y,object.Position.Z)
				if opts.avoid and isPathClear(point,opts.avoid) then break end
				if os.clock()>=nextMove then
					humanoid:MoveTo(point)
					nextMove=os.clock()+.15
				end
				-- Keep this job owning movement while the server charges/collects it.
				RunService.Heartbeat:Wait()
			end
			touchedMarks[object]=os.clock()+.4
			return true
		end

local near={Name=true,ID=1,Start=0,Position=Vector3.new(8,10,0)}
tracked.dupedsmiley[1]=near
assert(pickFastSmiley({})==near)
local arrivalAt
onHeartbeat=function()
 if root.Position.X==8 then
  arrivalAt=arrivalAt or now
  near.ChargeStart=arrivalAt
  if now-arrivalAt>=1.2 then tracked.dupedsmiley[1]=nil end
 end
end
collectFastSmiley(near,{})
assert(arrivalAt and now-arrivalAt>=1.2,"left before sustained contact completed")
assert(not tracked.dupedsmiley[1] and not touchedMarks[near],"confirmed collection must not retry")
assert(moves>1,"must maintain contact while charging")
local circle={Rotation=45}
local obj={Name="Token",Parent=true,Position=Vector3.new(1,10,0)}
function obj:FindFirstChild()return {FindFirstChild=function()return {FindFirstChild=function()return circle end}end}end
tracked.dupedsmiley={[obj]=0}
assert(pickFastSmiley({})==obj,"uncharged smiley must be approached to charge it")
arrivalAt=nil
onHeartbeat=function()arrivalAt=arrivalAt or now;if now-arrivalAt>1.3 then obj.Parent=nil end end
collectFastSmiley(obj,{})
assert(not tracked.dupedsmiley[obj],"removed smiley retained")
local before=moves;showerController.active=true;collectFastSmiley(near,{})
assert(moves==before,"shower must interrupt")
showerController.active=false;onHeartbeat=nil;tracked.dupedsmiley[1]=near
local start=now;collectFastSmiley(near,{})
assert(now-start<11 and touchedMarks[near],"missing server confirmation needs bounded retry")
cfg.autofarm.farmdupedtokens=false;assert(not pickFastSmiley({}))
print("PASS: sustained smiley contact until server removal, uncharged approach, physical removal, shower interrupt, bounded timeout and toggle")
