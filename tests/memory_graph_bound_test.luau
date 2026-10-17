local now=0
local os={time=function()return now end}
local cfg={webhook={graph=true,dashboard=false}}
local discord={hourstart=0,graph={status_changes={},field={}}}
local reportStatus
	reportStatus = function(laststatus, lastfield)
		if not (not cfg.webhook.graph and not cfg.webhook.dashboard or not discord.hourstart) then
			if not (not laststatus or discord.laststatus == laststatus) then
				local hourstart = discord.hourstart
				-- Bound history even when the graph sender stalls before hourly reset.
				discord.graph.status_changes[tostring(math.clamp(os.time() - hourstart, 0, 3600))] = laststatus
				discord.laststatus = laststatus
			end

			if not (not lastfield or discord.lastfield == lastfield) then
				local hourstart = discord.hourstart
				discord.graph.field[tostring(math.clamp(os.time() - hourstart, 0, 3600))] = lastfield
				discord.lastfield = lastfield
			end
		end
	end

for i=1,36000 do now=i;reportStatus(i%3+1,"field"..i%2)end
local n=0;for _ in pairs(discord.graph.status_changes)do n+=1 end
assert(n==3600)
n=0;for _ in pairs(discord.graph.field)do n+=1 end;assert(n==3600)
assert(discord.graph.status_changes["3600"]==1)
print("PASS: 10-hour stalled graph consumer retains at most 3,601 time buckets per history")
