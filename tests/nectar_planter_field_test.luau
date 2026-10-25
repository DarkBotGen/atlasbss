local cfg={planters={enabled=true,method="Nectar",nectar={farmfield=true}}}
local tracked={planters={}}
local selected
local workspace={FlowerZones={FindFirstChild=function(_,name)return name=="Pine Tree Forest" end}}
local function setField(field)selected=field end
local function step()
				if not (not cfg.planters.enabled or cfg.planters.method ~= "Nectar" or not cfg.planters.nectar.farmfield) then
					for _, planter in ipairs(tracked.planters or {}) do
						if planter.field and workspace.FlowerZones:FindFirstChild(planter.field) then
							setField(planter.field)
							break
						end
					end
				end
end
step();assert(not selected)
tracked.planters=nil;step();assert(not selected)
tracked.planters={{field="Removed Field"},{field="Pine Tree Forest"},{field="Rose Field"}}
step();assert(selected=="Pine Tree Forest")
selected=nil;cfg.planters.nectar.farmfield=false;step();assert(not selected)
print("PASS: Nectar planter field selection handles empty/missing lists and selects first valid live field")
