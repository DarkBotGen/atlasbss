local now=0
local os={clock=function()return now end}
local cfg={rbc={enabled=true,precise=true}}
local state={};local showerController={active=false}
local tracked={precise2={}}
local root={Position={Y=0}}
local Vector3={new=function(x,y,z)return {X=x,Y=y,Z=z}end}
local moves=0
local h={Health=100,MoveTo=function(_,point)moves+=1;assert(point.X==5)end}
local function getRootPart()return root end
local function getHumanoid()return h end
local function isPathClear()return false end
local onTick
local RunService={Heartbeat={Wait=function()now+=.05;if onTick then onTick()end end}}

		local function collectRbcPrecision(object,opts)
			local deadline=os.clock()+3
			local nextMove=0
			while os.clock()<deadline do
				if state.stop or showerController.active or not cfg.rbc.enabled or not cfg.rbc.precise then return true end
				if object.Name==true then
					if tracked.precise2[object.ID]~=object or object.Touched or object.Mark then return true end
				elseif not object.Parent or object.BrickColor.Name=="Flint" or object.BrickColor.Name=="Alder" then return true end
				if getHumanoid().Health<=0 then return true end
				local root=getRootPart().Position
				local point=Vector3.new(object.Position.X,root.Y,object.Position.Z)
				if opts.avoid and isPathClear(point,opts.avoid) then return true end
				if os.clock()>=nextMove then getHumanoid():MoveTo(point);nextMove=os.clock()+.1 end
				RunService.Heartbeat:Wait()
			end
			-- Unconfirmed targets remain eligible rather than being removed at six studs.
			return true
		end

local mark={Name=true,ID=1,Position={X=5,Y=0,Z=0}}
tracked.precise2[1]=mark
onTick=function()if now>=.4 then mark.Touched=true end end
collectRbcPrecision(mark,{rbc=true})
assert(now>=.4 and moves>1 and tracked.precise2[1]==mark,"must wait for touch without deleting target")
mark.Touched=false;now=0;onTick=nil
collectRbcPrecision(mark,{rbc=true});assert(now<3.1 and tracked.precise2[1]==mark)
print("PASS: precision movement continues through proximity until touch; timeout preserves unconfirmed target")
