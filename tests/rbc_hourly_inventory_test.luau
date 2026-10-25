local rbcHourly = {
	materials={"Smooth Dice","Field Dice","Purple Potion","Stinger"},
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
	if seconds<60 then return {{name="RBC summary",value="Tracking started. Hourly estimates appear after 1 minute.",inline=false}} end
	local hours=seconds/3600
	local function total(name,key) local t=self.totals[name];return t and t[key] or 0 end
	local glitched=total("Glitched Drive","gain")
	local colored=total("Red Drive","gain")+total("Blue Drive","gain")+total("White Drive","gain")
	local spent=total("Ticket","used")
	local tickets=self.previous and self.previous.Ticket or 0
	local summary=string.format("Glitched drives: **%.1f/hour**\nColored drives: **%.1f/hour**\nTickets spent: **%.1f/hour**\nTickets gained: **%.1f/hour**",glitched/hours,colored/hours,spent/hours,total("Ticket","gain")/hours)
	local budget=string.format("Tickets left: **%.0f**",tickets)
	if glitched>0 and spent>0 then
		local cost=spent/glitched
		budget..=string.format("\nAverage cost: **%.1f tickets per glitched drive**\nYour tickets could fund about **%.0f more glitched drives**",cost,math.floor(tickets/cost))
	else budget..="\nDrive estimate: waiting for both ticket spending and a glitched drive gain." end
	local materials={}
	for _,name in ipairs(self.materials) do
		table.insert(materials,string.format("%s: **%.1f used/hour** · %.1f gained/hour",name,total(name,"used")/hours,total(name,"gain")/hours))
	end
	return {
		{name="RBC per hour",value=summary,inline=false},
		{name="Ticket budget estimate",value=budget,inline=false},
		{name="Materials per hour",value=table.concat(materials,"\n"),inline=false},
		{name="Tracking",value=string.format("%.0f minutes this run. Colored = red + blue + white. Estimates use observed inventory changes and assume the same ticket cost; rewards and costs vary. Resets on rejoin.",seconds/60),inline=false},
	}
end

rbcHourly:Sample({["Glitched Drive"]=10,Ticket=100,["Smooth Dice"]=10,["Field Dice"]=5,["Purple Potion"]=2,Stinger=20},0)
assert(#rbcHourly:Fields(20)==1)
rbcHourly:Sample({["Glitched Drive"]=12,Ticket=80,["Red Drive"]=1,["Blue Drive"]=2,["White Drive"]=3,["Smooth Dice"]=8,["Field Dice"]=4,["Purple Potion"]=1,Stinger=10},3600)
local fields=rbcHourly:Fields(3600)
assert(string.find(fields[1].value,"Glitched drives: **2.0/hour**",1,true))
assert(string.find(fields[1].value,"Colored drives: **6.0/hour**",1,true))
assert(string.find(fields[2].value,"10.0 tickets per glitched drive",1,true))
assert(string.find(fields[2].value,"8 more glitched drives",1,true))
assert(string.find(fields[3].value,"Smooth Dice: **2.0 used/hour**",1,true))
assert(not string.find(fields[3].value,"Oil",1,true))
for _,field in ipairs(fields)do assert(#field.value<=1024)end
rbcHourly.totals["Glitched Drive"].gain=0
assert(string.find(rbcHourly:Fields(3600)[2].value,"waiting",1,true))
rbcHourly.totals.Ticket.used=0;rbcHourly.totals["Glitched Drive"].gain=2
assert(string.find(rbcHourly:Fields(3600)[2].value,"waiting",1,true))
for i=1,10000 do rbcHourly:Sample({},3600+i)end
local n=0;for _ in pairs(rbcHourly.previous)do n+=1 end;assert(n==9)
print("PASS: simple rates, four materials, combined colored drives, ticket budget, insufficient samples, Discord size and bounded state")
