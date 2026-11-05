local cfg={prioritization={order={"Petals"}},rbc={enabled=false,beepriorities={},bestredfield=false,loadeddice=false}}
local mergeTable

mergeTable = function(target, source)
	for k, value in pairs(target) do
		if target == cfg.rbc and k == "beepriorities" and type(source[k]) == "table" then
			target[k] = table.clone(source[k])
		elseif target == cfg.prioritization and k == "order" and type(source[k]) == "table" then
			-- Ordered lists must replace the default, including an empty default.
			-- Recursing over target's keys silently drops saved array entries.
			target[k] = table.clone(source[k])
		elseif type(value) ~= "table" or type(source[k]) ~= "table" then
			if source[k] ~= nil then
				target[k] = source[k]
			end
		elseif next(source[k]) ~= nil then
			mergeTable(value, source[k])
		end
	end
end

mergeTable(cfg,{prioritization={order={"Tokens","Petals"}},rbc={enabled=true,beepriorities={Red={Precise=2}},bestredfield="Pepper Patch",loadeddice=true}})
assert(cfg.rbc.enabled and cfg.rbc.loadeddice and cfg.rbc.bestredfield=="Pepper Patch")
assert(cfg.rbc.beepriorities.Red.Precise==2 and cfg.prioritization.order[1]=="Tokens")
print("PASS: merged main restores RBC flags, field selection, saved bee priorities and gathering order")
