local now=0
local os={time=function()return now end}
local state={}
local cfg={webhook={graph=false,dashboard=false}}
local discord={hourstart=0,graph={status_changes={},field={}}}
local reportStatus
reportStatus = function(laststatus, lastfield)
		if laststatus then state.activityStatus = laststatus end
		if not (not cfg.webhook.graph and not cfg.webhook.dashboard or not discord.hourstart) then
			if not (not laststatus or discord.laststatus == laststatus) then
				local hourstart = discord.hourstart
				discord.graph.status_changes[tostring(math.clamp(os.time() - hourstart,0,3600))] = laststatus
				discord.laststatus = laststatus
			end

			if not (not lastfield or discord.lastfield == lastfield) then
				local hourstart = discord.hourstart
				discord.graph.field[tostring(math.clamp(os.time() - hourstart,0,3600))] = lastfield
				discord.lastfield = lastfield
			end
		end
	end
reportStatus(1);assert(state.activityStatus==1)
reportStatus(nil);assert(state.activityStatus==1)
reportStatus(2);assert(state.activityStatus==2)
cfg.webhook.graph=true
for i=1,36000 do now=i;reportStatus(i%3+1,"field"..i%2)end
for _,list in pairs(discord.graph)do local n=0;for _ in pairs(list)do n+=1 end;assert(n<=3601)end
print("PASS: gathering status and bounded ten-hour stalled graph histories")
