
local now=0
local os={clock=function()return now end}
local tracked={flames={},tokens={}}
local function typeof(v)return type(v)=="table" and v.instance and "Instance" or type(v)end
local tick
local RunService={Heartbeat={Connect=function(_,fn)tick=fn;return {}end}}
local connections={Add=function()end}
local function count(t)local n=0;for _ in pairs(t)do n+=1 end;return n end
local function spawnFlame(effectData)
								local lifetime = math.max(0, tonumber(effectData.T) or 0)
								local flame = tracked.flames[effectData.P]
								if type(flame) ~= "table" then
									flame = {Name=true, Position=effectData.P}
									tracked.flames[effectData.P] = flame
								end
								flame.ExpiresAt = os.clock() + lifetime
								flame.T = math.min(lifetime, 6)
								flame.Size = 1.4 + 0.35 * (flame.T - 1) / 5
								flame.Dark = effectData.D
							
end
	connections:Add("runtimeCacheMaintenance", RunService.Heartbeat:Connect((function()
		local elapsed, pruneElapsed = 0, 0
		local expiryGroups = {"tokens", "tokenlink", "dupedbear", "dupedsmiley", "dupedtokens",
			"precise2", "bubbles", "cogsaws", "showers", "meteors", "petals", "coconuts", "crabcoconuts", "combococonuts"}
		local alertGroups = {"corruptedfield", "gummybeacon"}
		return function(dt)
			elapsed += dt
			pruneElapsed += dt
			if elapsed < 0.25 or not tracked then return end
			elapsed = 0
			local now = os.clock()
			for key, flame in pairs(tracked.flames) do
				if type(flame) == "table" and flame.ExpiresAt then
					local remaining = flame.ExpiresAt - now
					if remaining <= 0 then tracked.flames[key] = nil
					else
						flame.T = math.min(remaining, 6)
						flame.Size = 1.4 + 0.35 * (flame.T - 1) / 5
					end
				end
			end
			-- Synthetic entries may be keys (tokens) or values (dupes/bubbles).
			for _, name in ipairs(expiryGroups) do
				local list = tracked[name]
				if list then
					for key, value in pairs(list) do
						local entry = type(key) == "table" and key or type(value) == "table" and value
						if entry and entry.ExpiresAt and now >= entry.ExpiresAt then
							list[key] = nil
							if name == "precise2" then tracked.precisegroup[key] = nil end
						end
					end
				end
			end
			-- Collection can remove a target before expiry; its group must go too.
			for id in pairs(tracked.precisegroup or {}) do
				if not tracked.precise2[id] then tracked.precisegroup[id] = nil end
			end
			for _, name in ipairs(alertGroups) do
				local expires = tracked[name .. "ExpiresAt"]
				if expires and now >= expires then
					tracked[name], tracked[name .. "ExpiresAt"] = nil, nil
				end
			end
			if pruneElapsed < 5 then return end
			pruneElapsed = 0
			for i = #(tracked.planters or {}), 1, -1 do
				local planter = tracked.planters[i]
				if planter.instance and not planter.instance.Parent then table.remove(tracked.planters, i) end
			end
			for _, list in pairs(tracked) do
				if type(list) == "table" then
					for key in pairs(list) do
						if typeof(key) == "Instance" and not key.Parent then list[key] = nil end
					end
				end
			end
		end
	end)()))

for cycle=1,20 do
 for i=1,500 do spawnFlame({P=i,T=6,D=true}) end
 assert(count(tracked.flames)==500)
 now+=7;tick(7)
 assert(count(tracked.flames)==0,"dark flames retained after lifetime")
end
spawnFlame({P=1,T=6,D=false})
now+=4;tick(4)
spawnFlame({P=1,T=6,D=true})
now+=3;tick(3)
assert(tracked.flames[1],"old lifetime deleted refreshed flame")
now+=4;tick(4)
assert(not tracked.flames[1])
for i=1,500 do tracked.tokens[{instance=true,Parent=nil}]=true end
local live={instance=true,Parent=true};tracked.tokens[live]=true
now+=5;tick(5)
assert(count(tracked.tokens)==1 and tracked.tokens[live],"stale instances retained or live ones removed")
print("PASS: 10,000 dark-flame lifecycles with no retained workers, refreshed lifetime, destroyed-instance pruning")
