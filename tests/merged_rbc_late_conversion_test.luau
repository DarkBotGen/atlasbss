
	local function lateHiveConversion(round,tasks)
		if round<14 then return false end
		for _,taskText in ipairs(tasks) do
			local text=string.lower(taskText)
			if string.find(text,"convert",1,true) and (string.find(text,"hive",1,true) or string.find(text,"pollen",1,true)) then return true end
		end
		return false
	end

assert(not lateHiveConversion(13,{"Convert 100 Pollen at Hive"}))
assert(lateHiveConversion(14,{"Convert 100 Pollen at Hive"}))
assert(lateHiveConversion(20,{"Collect Red Pollen","Convert Pollen"}))
assert(not lateHiveConversion(14,{"Collect 100 Red Pollen","Make 100 Honey"}))
print("PASS: round-14 boundary, hive conversion recognition, safe pollen/honey quests")
