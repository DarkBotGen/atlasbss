local cfg={rbc={boostedfields=true}}
local buffs={Fields={}}
local workspace={FlowerZones={FindFirstChild=function()return true end}}
local function boost(stacks,time)return {Text={Text="x"..stacks},Percent={Size={Y={Scale=time}}}}end

	local function rbcBoostedField(color,fallback)
		if not cfg.rbc.boostedfields then return fallback end
		local candidates={White={"Dandelion Field","Sunflower Field"},Blue={"Blue Flower Field"},Red={"Pepper Patch","Mushroom Field"}}
		local best,bestStacks,bestTime=nil,0,-1
		for _,name in ipairs(candidates[color] or {}) do
			local boost=buffs.Fields and buffs.Fields[name]
			if boost and workspace.FlowerZones:FindFirstChild(name) then
				local stacks=tonumber(string.match(boost.Text.Text,"[%d%.]+")) or 1
				local remaining=boost.Percent and boost.Percent.Size.Y.Scale or 1
				if remaining>0 and (stacks>bestStacks or stacks==bestStacks and remaining>bestTime) then
					best,bestStacks,bestTime=name,stacks,remaining
				end
			end
		end
		return best or fallback
	end

assert(rbcBoostedField("Red","Rose Field")=="Rose Field")
buffs.Fields["Mushroom Field"]=boost(1,.8)
assert(rbcBoostedField("Red","Rose Field")=="Mushroom Field")
buffs.Fields["Pepper Patch"]=boost(2,.5)
assert(rbcBoostedField("Red","Rose Field")=="Pepper Patch")
buffs.Fields["Sunflower Field"]=boost(1,.7)
assert(rbcBoostedField("White","Spider Field")=="Sunflower Field")
buffs.Fields["Blue Flower Field"]=boost(1,.5)
assert(rbcBoostedField("Blue","Pine Tree Forest")=="Blue Flower Field")
buffs.Fields["Pepper Patch"]=nil;buffs.Fields["Mushroom Field"]=nil
assert(rbcBoostedField("Red","Rose Field")=="Rose Field")
cfg.rbc.boostedfields=false;assert(rbcBoostedField("Blue","Pine Tree Forest")=="Pine Tree Forest")
print("PASS: boosted RBC defaults by color, strongest boost, expiry fallback and disabled toggle")
