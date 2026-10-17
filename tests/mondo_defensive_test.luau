local now=100
local os={clock=function() return now end,time=function() return now end}
local cfg={combat={mondodefensive=false,mondoseekhit=true}}
local mondoPositioning={encounters=setmetatable({}, {__mode="k"})}
local function getHumanoid() return {Health=100} end
local tile=nil
local calls=0
local gameApi={BuffTile=function() calls+=1;return tile end}
local function secureCall(fn,...) return fn(...) end
local mondo={}
function mondoPositioning:Defensive(mondo)
	if not cfg.combat.mondodefensive then return false end
	local encounter = self.encounters[mondo]
	if not encounter then
		encounter = {health=getHumanoid().Health, started=os.clock(), status=cfg.combat.mondoseekhit and "seeking" or "timeout"}
		self.encounters[mondo] = encounter
	end
	local now = os.clock()
	if not encounter.shieldChecked or now - encounter.shieldChecked >= 0.2 then
		encounter.shieldChecked = now
		encounter.shieldActive = false
		for _, name in ipairs({"Emergency Coconut Shield", "Coconut Shield"}) do
			local ok, tile = pcall(secureCall, gameApi.BuffTile, name)
			if ok and type(tile) == "table" and type(tile.TimerStart) == "number" and type(tile.TimerDur) == "number"
				and tile.TimerDur > 0 and tile.TimerDur <= 15 and os.time() < tile.TimerStart + tile.TimerDur then
				encounter.shieldActive = true
				break
			end
		end
	end
	return encounter.status ~= "seeking" and not encounter.shieldActive
end

assert(not mondoPositioning:Defensive(mondo))
assert(next(mondoPositioning.encounters)==nil)
cfg.combat.mondodefensive=true
assert(not mondoPositioning:Defensive(mondo),"must permit initial hit attempt")
mondoPositioning.encounters[mondo].status="hit"
now+=1;tile={TimerStart=now,TimerDur=10}
assert(not mondoPositioning:Defensive(mondo),"shielded farming")
local before=calls
assert(not mondoPositioning:Defensive(mondo) and calls==before,"rate limited query")
now+=11
assert(mondoPositioning:Defensive(mondo),"expired shield must retreat")
now+=1;tile=nil
assert(mondoPositioning:Defensive(mondo),"missing shield must retreat")
now+=1;tile={TimerStart=now,TimerDur=300}
assert(mondoPositioning:Defensive(mondo),"cooldown is not protection")
local other={};cfg.combat.mondoseekhit=false
assert(mondoPositioning:Defensive(other),"no hit attempt must still defend")
cfg.combat.mondodefensive=false
assert(not mondoPositioning:Defensive(mondo))
print("PASS: Mondo toggle, first hit, active/expired/missing shield, cooldown rejection, query throttle, disabled hit seeking")
