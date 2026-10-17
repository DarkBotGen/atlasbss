local bridge={}
local cfg={autofarm={enabled=true,farmshowers=true},prioritization={enabled=false}}
local state={activityStatus=1}
local currentField={}
local field=currentField
local health=100
local function getHumanoid() return {Health=health} end
local function getRootPart() return {Position=0} end
local function getFieldAt() return field end
local showerController={active=false}
local bearCombat={active=true}
local gatheringPriorities={Candidate=function(self, category) if self.combo then return "Combo Coconut",{} end end}
 bridge.allowed=function()
  return not bridge.shuttingDown and cfg and state and not state.stop
   and cfg.autofarm.enabled and cfg.autofarm.farmshowers and state.activityStatus == 1
   and currentField ~= nil and getHumanoid().Health > 0 and getFieldAt(getRootPart().Position) == currentField
 end
function gatheringPriorities:ShouldPreempt()
	if showerController.active then return true end
	if self.activeCategory == "Combo Coconuts" then return false end
	if self.activeCategory ~= "Combo Coconuts" and self:Candidate("Combo Coconuts", self.activeOptions or {}, getRootPart().Position) then return true end
    if bearCombat.active then return false end
    local now = os.clock()
    if self.nextPreemptCheck and now < self.nextPreemptCheck then return false end
    self.nextPreemptCheck = now + 0.08
    if bearCombat:Pick(self.activeOptions or {}) then return true end
    if not cfg.prioritization.enabled or not self.activeCategory then return false end
    return self:Pick(self.activeOptions or {}, self.activeCategory) ~= nil
end
assert(bridge.allowed())
state.activityStatus=3;assert(not bridge.allowed())
state.activityStatus=2;assert(not bridge.allowed())
state.activityStatus=1;field={};assert(not bridge.allowed())
field=currentField;cfg.autofarm.enabled=false;assert(not bridge.allowed())
cfg.autofarm.enabled=true;state.stop=true;assert(not bridge.allowed())
state.stop=false;health=0;assert(not bridge.allowed())
health=100;currentField=nil;field=nil;assert(not bridge.allowed())
gatheringPriorities.combo=true;gatheringPriorities.activeCategory="Petals";assert(gatheringPriorities:ShouldPreempt())
gatheringPriorities.activeCategory="Combo Coconuts";assert(not gatheringPriorities:ShouldPreempt())
showerController.active=true;assert(gatheringPriorities:ShouldPreempt())
print("PASS: gathering-only shower gate, travel/conversion/stop/death disabled, combo interrupts and remains locked")
