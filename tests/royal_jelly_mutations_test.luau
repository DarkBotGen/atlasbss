local cfg={hive={feedtype="Royal Jelly",bee="1,1",beetypes={BuoyantBee=true},mutas3={Movespeed={true,6}},neonberry=false}}
local rolls,waits,warnings=0,0,0
local responses={}
local initial={Type="BuoyantBee",Radiation=true}
local gameApi={BeeMutations={Description=function(_,v)return "+"..v.." Movespeed" end}}
function gameApi:Cache()return {x1={y1=initial}} end
function gameApi:CacheSet()end
function gameApi:Event(name,...)
 if name=="PlayerSettingsEvent" then return end
 rolls+=1;assert(rolls<=#responses,"rolled past requested mutation")
 local bee=responses[rolls]
 if bee=="rejected" then return 99,false end
 return 99,true,bee and {x1={y1=bee}} or {},{},0
end
local RunService={Heartbeat={Wait=function()return true end}}
local inventory={time={},Has=function()return true end}
local localPlayer={SpawnPos={Value={Position={}}}}
local function distanceTo()return 0 end
local function goTo()error("unexpected travel")end
local function secureCall(fn,...)return fn(...)end
local task={wait=function()waits+=1 end}
local controls={["Auto Mutations"]={Set=function()end}}
local ui={Notify=function()end}
local logger={warn=function()warnings+=1 end}
local autoMutations
	autoMutations = function()
		local finished = nil
		local rollDelay, rejectedRolls = 0, 0

		while not finished do
			if not RunService.Heartbeat:Wait() then
				break
			end

			local ok, result = pcall(function()
				local selectedMutaCount = 0

				if cfg.hive.mutas3 then
					for _, mutaEntry in pairs(cfg.hive.mutas3) do
						if not (not mutaEntry[1] or not mutaEntry[2]) then
							selectedMutaCount += 1
						end
					end
				end

				if selectedMutaCount == 0 then
					controls["Auto Mutations"].Set(false)
					ui.Notify("Auto Mutations", "No mutations selected")
					finished = true
					return
				end

				if cfg.hive.feedtype == "Royal Jelly" then
					gameApi:Event("PlayerSettingsEvent", "RollToMutation", true)
				end

				if cfg.hive.feedtype == "Royal Jelly" then
					local beeTypeCount = 0

					if cfg.hive.beetypes then
						for k in pairs(cfg.hive.beetypes) do
							beeTypeCount += 1
						end
					end

					if beeTypeCount == 0 then
						controls["Auto Mutations"].Set(false)
						ui.Notify("Auto Mutations", "No bees selected")
						finished = true
						return
					end
				end

				local cellX = tonumber(string.match(cfg.hive.bee, "(%d+),"))
				local cellY = tonumber(string.match(cfg.hive.bee, ",(%d+)"))
				local Honeycomb = gameApi:Cache("Honeycomb")

				if not cellX or not cellY then
					controls["Auto Mutations"].Set(false)
					ui.Notify("Auto Mutations", "No bee selected")
					cfg.hive.bee = false
					finished = true
					return
				end

				if Honeycomb["x" .. cellX] then
					if Honeycomb["x" .. cellX]["y" .. cellY] then
						inventory.time.Neonberry = nil
						inventory.time.Bitterberry = nil
						inventory.time["Royal Jelly"] = nil
						local beeData = Honeycomb["x" .. cellX]["y" .. cellY]
						local inventoryRef = inventory
						local has = inventory.Has
						local requiredItems = {}
						requiredItems[cfg.hive.feedtype] = cfg.hive.feedtype == "Bitterberry" and cfg.hive.amount or 10

						if not has(inventoryRef, requiredItems) then
							controls["Auto Mutations"].Set(false)
							ui.Notify("Auto Mutations", "Not enough " .. cfg.hive.feedtype)
							finished = true
							return
						end

						if not (not beeData.Mutas or not (cfg.hive.feedtype == "Bitterberry" or cfg.hive.beetypes[beeData.Type])) then
							for k, muta in pairs(beeData.Mutas) do
								local mutaCfg = cfg.hive.mutas3[k]
								if not mutaCfg or not mutaCfg[1] then
									continue
								end
								local mutaDescription = secureCall(gameApi.BeeMutations.Description, k, muta)
								local isPercent = string.find(mutaDescription, "%", 1, true) ~= nil
								local effectiveValue = muta

								if not isPercent or not string.find(mutaDescription, "%-%d") then
									if not (not isPercent or not (effectiveValue > 1)) then
										effectiveValue -= 1
									end
								elseif effectiveValue < 1 then
									effectiveValue = 1 - effectiveValue
								end

								if mutaCfg[2] <= effectiveValue then
									finished = true
									return
								end
							end
						end

						if not beeData.Radiation then
							if not cfg.hive.neonberry then
								controls["Auto Mutations"].Set(false)
								ui.Notify("Auto Mutations", "Bee is not radioactive")
								finished = true
								return
							end

							if not inventory:Has({ Neonberry = 1 }) then
								controls["Auto Mutations"].Set(false)
								ui.Notify("Auto Mutations", "Bee is not radioactive and no neonberries")
								finished = true
								return
							end

							if distanceTo(localPlayer.SpawnPos.Value.Position, true) > 9 then
								goTo(localPlayer.SpawnPos.Value.Position, "Hive")
								task.wait(0.5)
							end

							local ConstructHiveCellFromEgg, neonSuccess, neonHoneycomb, neonDiscovered, neonEggUses = gameApi:Event("ConstructHiveCellFromEgg", cellX, cellY, "Neonberry", 1, false)

							if not neonSuccess then
								logger.warn("Failed to feed bee")
								finished = true
								return
							end

							gameApi:CacheSet({ "Eggs", "Neonberry" }, ConstructHiveCellFromEgg)
							gameApi:CacheSet("Honeycomb", neonHoneycomb)
							gameApi:CacheSet("DiscoveredBees", neonDiscovered)
							gameApi:CacheSet({ "Totals", "EggUses" }, neonEggUses)
							task.wait(0.3)
							return
						end

						while true do
							local inventoryRef2 = inventory
							local has2 = inventory.Has
							local requiredItems2 = {}
							requiredItems2[cfg.hive.feedtype] = cfg.hive.feedtype == "Bitterberry" and cfg.hive.amount or 1

							if not has2(inventoryRef2, requiredItems2) then
								ui.Notify("Auto Mutations", "Not enough " .. cfg.hive.feedtype)
								finished = true
								return
							end

							if distanceTo(localPlayer.SpawnPos.Value.Position, true) > 9 then
								goTo(localPlayer.SpawnPos.Value.Position, "Hive")
								task.wait(0.5)
							end

							if not (not beeData.Mutas or not (cfg.hive.feedtype == "Bitterberry" or cfg.hive.beetypes[beeData.Type])) then
								for k, muta in pairs(beeData.Mutas) do
									local mutaCfg2 = cfg.hive.mutas3[k]
									if not mutaCfg2 then
										continue
									end

									if not mutaCfg2[1] then
										continue
									end
									local mutaDescription2 = secureCall(gameApi.BeeMutations.Description, k, muta)
									local isPercent2 = string.find(mutaDescription2, "%", 1, true) ~= nil
									local effectiveValue2 = muta

									if not isPercent2 or not string.find(mutaDescription2, "%-%d") then
										if not (not isPercent2 or not (effectiveValue2 > 1)) then
											effectiveValue2 -= 1
										end
									elseif effectiveValue2 < 1 then
										effectiveValue2 = 1 - effectiveValue2
									end

									if mutaCfg2[2] <= effectiveValue2 then
										finished = true
										return
									end
								end
							end

							if not beeData.Radiation then
								if not cfg.hive.neonberry or not inventory:Has({ Neonberry = 1 }) then
									finished = true
									return
								end
								local ConstructHiveCellFromEgg, neonSuccess, neonHoneycomb, neonDiscovered, neonEggUses = gameApi:Event("ConstructHiveCellFromEgg", cellX, cellY, "Neonberry", 1, false)

								if not neonSuccess then
									logger.warn("Failed to feed bee")
									finished = true
									return
								end

								gameApi:CacheSet({ "Eggs", "Neonberry" }, ConstructHiveCellFromEgg)
								gameApi:CacheSet("Honeycomb", neonHoneycomb)
								gameApi:CacheSet("DiscoveredBees", neonDiscovered)
								gameApi:CacheSet({ "Totals", "EggUses" }, neonEggUses)
								task.wait(0.3)
								return
							end

							local feedItem = string.gsub(cfg.hive.feedtype, " ", "")
							local ConstructHiveCellFromEgg, feedSuccess, feedHoneycomb, feedDiscovered, feedEggUses = gameApi:Event("ConstructHiveCellFromEgg", cellX, cellY, feedItem, cfg.hive.feedtype == "Bitterberry" and cfg.hive.amount or 1, false)

							if not feedSuccess then
								-- A fast follow-up can be rejected while the server is cooling down.
								-- Retry only an explicitly rejected roll, never an uncertain success.
								if feedItem == "RoyalJelly" and rejectedRolls < 3 then
									rejectedRolls += 1
									rollDelay = math.min(1, math.max(.35, rollDelay + .15))
									task.wait(rollDelay)
									continue
								end
								logger.warn("Failed to feed bee after bounded retries")
								finished = true
								return
							end
							rejectedRolls = 0

							-- Never issue another roll without authoritative data for this cell.
							local nextColumn = type(feedHoneycomb)=="table" and feedHoneycomb["x" .. cellX]
							local nextBee = type(nextColumn)=="table" and nextColumn["y" .. cellY]
							if type(nextBee)~="table" or not nextBee.Type then
								finished = true
								controls["Auto Mutations"].Set(false)
								logger.warn("Mutation rolling stopped: server returned no bee data")
								return
							end

							gameApi:CacheSet({ "Eggs", feedItem }, ConstructHiveCellFromEgg)
							gameApi:CacheSet("Honeycomb", feedHoneycomb)
							gameApi:CacheSet("DiscoveredBees", feedDiscovered)
							gameApi:CacheSet({ "Totals", "EggUses" }, feedEggUses)
							beeData = nextBee
							if feedItem == "RoyalJelly" then
								-- One request at a time; the next iteration checks this returned bee.
								if rollDelay > 0 then task.wait(rollDelay) else RunService.Heartbeat:Wait() end
							else
								task.wait(0.3)
							end
						end
					end
				end

				controls["Auto Mutations"].Set(false)
				logger.warn("Hive data is nil")
				finished = true
			end)

			if not ok and result ~= "return" then
				task.wait()
				logger.warn(result)
				task.wait(1)
			end
		end
	end

responses={{Type="BuoyantBee",Radiation=true,Mutas={Movespeed=5}},{Type="BuoyantBee",Radiation=true,Mutas={Movespeed=6}}}
autoMutations();assert(rolls==2 and waits==0 and warnings==0)
rolls=0;responses={{Type="PreciseBee",Radiation=true,Mutas={Movespeed=6}},{Type="BuoyantBee",Radiation=true,Mutas={Movespeed=6}}}
autoMutations();assert(rolls==2 and waits==0 and warnings==0)
rolls=0;responses={false};autoMutations();assert(rolls==1 and warnings==1)
print("PASS: stops on selected +6 Movespeed bee, skips wrong bee types, no fixed jelly delay, stops on missing server data")

rolls=0;waits=0;warnings=0
responses={{Type="BuoyantBee",Radiation=true,Mutas={Movespeed=5}},"rejected",{Type="BuoyantBee",Radiation=true,Mutas={Movespeed=6}}}
autoMutations();assert(rolls==3 and waits==2 and warnings==0,"transient rejection must back off then stop at selected bee")
rolls=0;waits=0;warnings=0;responses={"rejected","rejected","rejected","rejected"}
autoMutations();assert(rolls==4 and waits==3 and warnings==1,"persistent failures must stop after bounded retries")
print("PASS: transient server rejection resumes with cooldown; persistent rejections stop after three retries")
