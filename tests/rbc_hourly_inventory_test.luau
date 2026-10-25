-- Bounded inventory-rate counters; no retained per-sample history.
local rbcHourly = {
	materials={"Gumdrops","Stinger","Enzymes","Glue","Oil","Snowflake","Blue Extract","Red Extract","Jelly Beans","Tropical Drink","Purple Potion","Super Smoothie"},
	previous=nil, totals={}, started=nil,
}
function rbcHourly:Sample(snapshot,now)
	if type(snapshot)~="table" then return end
	if not self.started then self.started=now end
	local names={"Glitched Drive","Red Drive","Blue Drive","White Drive","Ticket"}
	for _,name in ipairs(self.materials) do table.insert(names,name) end
	local previous=self.previous
	local nextSnapshot={}
	for _,name in ipairs(names) do
		local amount=tonumber(snapshot[name]) or 0
		nextSnapshot[name]=amount
		local total=self.totals[name]
		if not total then total={gain=0,used=0};self.totals[name]=total end
		if previous then
			local delta=amount-(previous[name] or 0)
			if delta>0 then total.gain+=delta else total.used-=delta end
		end
	end
	self.previous=nextSnapshot
end
function rbcHourly:Fields(now)
	local seconds=self.started and now-self.started or 0
	if seconds<60 then return {{name="RBC hourly estimates",value="Collecting inventory samples (at least 1 minute needed).",inline=false}} end
	local hours=seconds/3600
	local function rate(names)
		local gain,used=0,0
		for _,name in ipairs(names) do local t=self.totals[name] or {};gain+=t.gain or 0;used+=t.used or 0 end
		return string.format("+%.1f gained / -%.1f used / %+.1f net",gain/hours,used/hours,(gain-used)/hours)
	end
	local lines={}
	for _,name in ipairs(self.materials) do table.insert(lines,name..": "..rate({name})) end
	return {
		{name="Drives & tickets / hour (estimated)",value="Glitched: "..rate({"Glitched Drive"}).."\nColored (R+B+W): "..rate({"Red Drive","Blue Drive","White Drive"}).."\nTickets: "..rate({"Ticket"})..string.format("\nAverage over %.1f minutes this run.",seconds/60),inline=false},
		{name="RBC materials / hour (estimated)",value=table.concat(lines,"\n").."\nObserved inventory changes; simultaneous gains/use may cancel.",inline=false},
	}
end


rbcHourly:Sample({["Glitched Drive"]=10,["Red Drive"]=4,["Blue Drive"]=5,["White Drive"]=6,Ticket=100,Oil=5},0)
rbcHourly:Sample({["Glitched Drive"]=12,["Red Drive"]=5,["Blue Drive"]=7,["White Drive"]=9,Ticket=110,Oil=3},1800)
rbcHourly:Sample({["Glitched Drive"]=11,["Red Drive"]=5,["Blue Drive"]=7,["White Drive"]=9,Ticket=107,Oil=4},3600)
local fields=rbcHourly:Fields(3600)
assert(string.find(fields[1].value,"Glitched: +2.0 gained / -1.0 used / +1.0 net",1,true))
assert(string.find(fields[1].value,"Colored (R+B+W): +6.0 gained",1,true))
assert(string.find(fields[1].value,"Tickets: +10.0 gained / -3.0 used / +7.0 net",1,true))
assert(string.find(fields[2].value,"Oil: +1.0 gained / -2.0 used / -1.0 net",1,true))
assert(#fields[1].value<=1024 and #fields[2].value<=1024)
for i=1,10000 do rbcHourly:Sample({},3600+i)end
local n=0;for _ in pairs(rbcHourly.previous)do n+=1 end;assert(n==17)
print("PASS: glitched/combined colored drives, ticket and material gain/use/net averages, Discord field sizes and bounded sample state")
