local now=10
local os={clock=function()return now end}
local mt={}
local Vector3={new=function(x,y,z)return setmetatable({X=x,Y=y,Z=z},mt)end}
mt.__index=function(v,k) if k=="Magnitude" then return math.sqrt(v.X*v.X+v.Y*v.Y+v.Z*v.Z) end; if k=="Dot" then return function(a,b)return a.X*b.X+a.Y*b.Y+a.Z*b.Z end end end
mt.__sub=function(a,b)return Vector3.new(a.X-b.X,a.Y-b.Y,a.Z-b.Z)end
local root={Position=Vector3.new(0,0,0)}
local moves=0
local humanoid={WalkSpeed=40,MoveTo=function(_,p)moves+=1;root.Position=p end}
local function getRootPart()return root end
local function getHumanoid()return humanoid end
local function distanceTo(p)return (p-root.Position).Magnitude end
local currentField={}
local function getFieldAt()return currentField end
local function isPathClear()return false end
local cfg={autofarm={farmsmileys=true,smileytime=4}}
local tracked={dupedsmiley={}}
local touchedMarks={}
local showerController={active=false}
local state={}
local RunService={Heartbeat={Wait=function()now+=.05 end}}
		local function pickFastSmiley(opts)
			if not cfg.autofarm.farmsmileys then return end
			local now,root,best,bestDistance=os.clock(),getRootPart().Position,nil,math.huge
			for key,value in pairs(tracked.dupedsmiley) do
				local object=type(key)=="number" and value or key
				local virtual=type(object)=="table" and object.Name==true
				if not virtual and not object.Parent then tracked.dupedsmiley[key]=nil;continue end
				if touchedMarks[object] then continue end
				local start=virtual and object.Start or value
				if type(start)~="number" or now-start<(tonumber(cfg.autofarm.smileytime) or 4) then continue end
				if not virtual then
					local attachment=object:FindFirstChild("Attachment")
					local gui=attachment and attachment:FindFirstChild("BillboardGuiBack")
					local circle=gui and gui:FindFirstChild("FrontCircle1")
					if circle and circle.Rotation<90 then continue end
				end
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
			local now=os.clock()
			local deadline=now+math.min(4,distanceTo(object.Position,true)/math.max(1,getHumanoid().WalkSpeed)+.75)
			while os.clock()<deadline do
				if showerController.active or state.stop then return true end
				if object.Name==true then
					if tracked.dupedsmiley[object.ID]~=object then return true end
				elseif not object.Parent then return true end
				local root=getRootPart().Position
				local point=Vector3.new(object.Position.X,root.Y,object.Position.Z)
				if opts.avoid and isPathClear(point,opts.avoid) then break end
				if distanceTo(point,true)<=4 then break end
				getHumanoid():MoveTo(point)
				RunService.Heartbeat:Wait()
			end
			touchedMarks[object]=os.clock()+.4
			return true
		end

local far={Name=true,ID=1,Start=0,Position=Vector3.new(20,10,0)}
local near={Name=true,ID=2,Start=0,Position=Vector3.new(8,10,0)}
tracked.dupedsmiley[1]=far;tracked.dupedsmiley[2]=near
assert(pickFastSmiley({})==near,"nearest smiley")
collectFastSmiley(near,{})
assert(moves==1 and now<10.1,"must approach continuously without charge wait")
assert(tracked.dupedsmiley[2]==near,"must not delete unconfirmed smiley")
assert(pickFastSmiley({})==far,"arrival cooldown")
now=touchedMarks[near]+.01;touchedMarks[near]=nil
assert(pickFastSmiley({})==near,"uncaught smiley must be retried")
showerController.active=true;local before=moves;collectFastSmiley(far,{})
assert(moves==before,"shower must preempt smiley")
showerController.active=false
local circle={Rotation=45}
local obj={Name="Token",Parent=true,Position=Vector3.new(1,10,0)}
function obj:FindFirstChild()return {FindFirstChild=function()return {FindFirstChild=function()return circle end}end}end
tracked.dupedsmiley={[obj]=0}
assert(not pickFastSmiley({}),"uncharged token must not stall farming")
circle.Rotation=90;assert(pickFastSmiley({})==obj)
obj.Parent=nil;assert(not pickFastSmiley({}) and not tracked.dupedsmiley[obj])
cfg.autofarm.farmsmileys=false;assert(not pickFastSmiley({}))
print("PASS: nearest ready smiley, continuous approach, bounded retry, shower takeover, charge gating, removal and toggle")
