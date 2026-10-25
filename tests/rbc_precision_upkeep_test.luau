local cfg={rbc={enabled=true,precise=true,precisemin=5}}
local state={};local currentField={}
local challenge={Round=5}
local gameApi={Cache=function()return challenge end}
local buffs={Precision={Text={Text="x10"},Percent={Size={Y={Scale=.6}}}}}
local touchedMarks={}
local tracked={precise={},precise2={}}
local function getFieldAt(p)return p.field end
local function distanceTo(p)return p.distance end
local function isPathClear(p)return p.hazard end

		local precisionRefresh=false
		local function pickRbcPrecision(opts)
			if not (opts.rbc or opts.rbcprecision) or not cfg.rbc.enabled or not cfg.rbc.precise or state.precise then precisionRefresh=false;return end
			local challenge=gameApi:Cache({"RoboChallenges","ActiveChallenge"})
			if (tonumber(cfg.rbc.precisemin) or 1)>1 and (not challenge or (tonumber(challenge.Round) or 0)<cfg.rbc.precisemin) then precisionRefresh=false;return end
			local precision=buffs.Precision
			local remaining=precision and precision.Percent.Size.Y.Scale or 0
			if not precision or precision.Text.Text~="x10" or remaining<.85 then precisionRefresh=true
			elseif remaining>=.97 then precisionRefresh=false end
			if not precisionRefresh then return end
			local best,kind,bestDistance=nil,nil,math.huge
			local function consider(object,targetKind)
				if touchedMarks[object] then return end
				local point=object.Position
				if getFieldAt(point)~=currentField then return end
				if opts.origin and opts.range and (point-opts.origin).Magnitude>=opts.range then return end
				if opts.avoid and isPathClear(point,opts.avoid) then return end
				local distance=distanceTo(point,true)
				if distance<bestDistance then best,kind,bestDistance=object,targetKind,distance end
			end
			for object in pairs(tracked.precise) do
				if object.Parent and object.BrickColor.Name~="Flint" and object.BrickColor.Name~="Alder" then consider(object,"Precise") end
			end
			for _,object in pairs(tracked.precise2) do
				if not object.Mark and not object.Touched then consider(object,"Precise2") end
			end
			return kind,best
		end

local target={Position={field=currentField,distance=5},Mark=false,Touched=false}
tracked.precise2[1]=target
local kind,obj=pickRbcPrecision({rbc=true});assert(kind=="Precise2" and obj==target)
buffs.Precision.Percent.Size.Y.Scale=.8;assert(select(2,pickRbcPrecision({rbc=true}))==target,"refresh must continue")
buffs.Precision.Percent.Size.Y.Scale=.99;assert(not pickRbcPrecision({rbc=true}))
buffs.Precision.Text.Text="x9";assert(select(2,pickRbcPrecision({rbc=true}))==target)
target.Position.hazard=true;assert(not pickRbcPrecision({rbc=true,avoid={}}))
target.Position.hazard=nil;target.Mark=true;assert(not pickRbcPrecision({rbc=true}))
target.Mark=false;challenge.Round=4;assert(not pickRbcPrecision({rbc=true}))
challenge.Round=5;cfg.rbc.precise=false;assert(not pickRbcPrecision({rbc=true}))
print("PASS: proactive RBC precision, refresh hysteresis, lost stacks, hazards, purple marks, minimum round and disabled setting")
