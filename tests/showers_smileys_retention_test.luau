
local now=0
local os={clock=function()return now end,time=function()return math.floor(now)end}
local function count(t)local n=0;for _ in pairs(t)do n+=1 end;return n end
local function typeof(v)return type(v)=="table" and v.instanceMock and "Instance" or type(v)end
local Vector2={new=function(x,y)return {X=x,Y=y}end}
local function signal()return {Connect=function(_,fn)return {fn=fn}end}end
local RunService={Heartbeat=signal()}
local connections={list={},Add=function(self,id,c)self.list[id]=c end}
local threads={Add=function()error("unexpected worker")end,Delay=function()error("per-event timer retained")end}
local workspace={ServerTime={Value=0},Planters={ChildRemoved=signal()}}
local cfg={detected={fastraretween=false},antilag={particles=true,precise=true},autofarm={farmcombococonuts=true}}
local state={}
local localPlayer={UserId=123}
local tracked={}
for _,name in ipairs({"tokens","tokenlink","dupedbear","dupedsmiley","dupedtokens","precise2","precisegroup","bubbles","flames","cogsaws","showers","meteors","petals","coconuts","crabcoconuts","combococonuts","planters"})do tracked[name]={}end
local tokenFilter

local showerController={active=false}
	tokenFilter = {
		ignored = {
			AquaWave = true,
			BeamShot = true,
			BeesmasLightsFallingStar = true,
			Bubble = true,
			BubbleBloatCollect = true,
			CCRocket = true,
			CCRocketCrosshairs = true,
			CCRocketCrosshairsOld = true,
			DiamondDrain = true,
			EggShield = true,
			FallingCoal = true,
			FallingCoconut = true,
			FallingSnowflake = true,
			FallingStar = true,
			FieldRectPulses = true,
			FieldStar = true,
			GoldenRake = true,
			GummyStar = true,
			Gummyball = true,
			HoneyHammer = true,
			InspireStar = true,
			JellyBeanToss = true,
			KickableCoconut = true,
			KickedComboCoconut = true,
			LocalFlames = true,
			MechsquitoShot = true,
			MythicMeteor = true,
			OrbExplode = true,
			PartyPopper = true,
			PetalShuriken = true,
			PluckedPetal = true,
			PopStar = true,
			PorcelainDipperAbility = true,
			PuffshroomSporeThrow = true,
			RectPulse = true,
			RingPulse = true,
			ScorchingStar = true,
			SnowballThrow = true,
			SnowflakeBreeze = true,
			SpotlightBeam = true,
			StarSaw = true,
			StarShowerGuide = true,
			StickerTokenBeam = true,
			SweepArch = true,
			Triangulate = true,
			WaterRipple = true,
		},
		dupedmap = {
			["rbxassetid://1472425802"] = "dupedbear",
			["rbxassetid://1472580249"] = "dupedbear",
			["rbxassetid://1472532912"] = "dupedbear",
			["rbxassetid://2032949183"] = "dupedbear",
			["rbxassetid://1472491940"] = "dupedbear",
			["rbxassetid://1489734171"] = "dupedbear",
			["rbxassetid://1837410537"] = "dupedbear",
			["http://www.roblox.com/asset/?id=5877939956"] = "dupedsmiley",
		},
		list = {},
		LocalFX = function(owner, effectName, effectData)
			if effectName=="StarShowerGuide" or effectName=="FallingStar" or effectName=="BeesmasLightsFallingStar" then return true end
			if effectName ~= "LocalTargetPracticeBeam" or effectData.Action ~= "Make" or effectData.Player ~= localPlayer then
				if effectName ~= "LocalTargetPracticeBeam" or effectData.Action ~= "Touch" then
					if not ((effectName ~= "LocalTargetPracticeBeam" or effectData.Action ~= "TurnPurple") and (effectName ~= "PrecisionPopUp" or effectData.Player ~= localPlayer) or cfg.antilag.precise) then
						return true
					end

					if effectName == "CogSawProjectile" then
						local sawEntry = { Start = effectData.Pos1, End = effectData.Pos2 }
						tracked.cogsaws[sawEntry] = true

						sawEntry.ExpiresAt = os.clock() + math.max(0, tonumber(effectData.EndTime - workspace.ServerTime.Value) or 0)

						return true
					end

					if not (effectName == "LocalTargetPracticeBeam" or effectName == "Precise Shot" or effectName == "PrecisionPopUp") then
						if not cfg.antilag.particles then
							return true
						end

						if not (effectName ~= "Bubble" or effectData.Action ~= "Spawn") then
							local bubbleEntry = { Name = true, ID = effectData.ID, Position = effectData.Pos, Gold = effectData.Gold }
							tracked.bubbles[effectData.ID] = bubbleEntry

							bubbleEntry.ExpiresAt = os.clock() + math.max(0, tonumber(effectData.Dur) or 0)
						elseif not (effectName ~= "Bubble" or effectData.Action ~= "Pop") then
							tracked.bubbles[effectData.ID] = nil
						elseif effectName ~= "FallingCoconut" or effectData.Target ~= localPlayer and not effectData.Combo then
							if (effectName == "FallingStar" or effectName == "BeesmasLightsFallingStar") and effectData.Target == localPlayer then
								local showerEntry = { Name = true, Position = effectData.Pos, Start = os.time() }
								tracked.showers[showerEntry] = true

								showerEntry.ExpiresAt = os.clock() + math.max(0, tonumber(2) or 0)
							elseif not (effectName ~= "LocalFlames" or effectData.A ~= "N" or effectData.PID ~= localPlayer.UserId) then
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
							elseif effectName == "MythicMeteor" then
								local meteorEntry = { Name = true, Position = effectData.Pos, Size = Vector2.new(effectData.Radius, 0) }
								tracked.meteors[meteorEntry] = true

								meteorEntry.ExpiresAt = os.clock() + math.max(0, tonumber(effectData.FallDuration) or 0)
							elseif not (effectName ~= "FieldStar" or not ((effectData.Action == "Make" or effectData.Action == "Destroy") and effectData.Type == "Guiding Star")) then
								tracked.guiding[effectData.Zone] = effectData.Action == "Make" and 1 or nil
							elseif effectName ~= "PluckedPetal" then
								if not owner.ignored[effectName] then
									return true
								end
							else
								local petalEntry = { Name = true, ZoneName = effectData.ZoneName, Position = effectData.GoalPos }
								tracked.petals[petalEntry] = true

								petalEntry.ExpiresAt = os.clock() + math.max(0, tonumber(effectData.Duration) or 0)
							end
						elseif effectData.Radius == 20 then
							local trackedEntry = { Name = true, Position = effectData.Pos }

							if state.coconuts then
								state.coconuts = state.coconuts + 1
							end

							tracked.crabcoconuts[trackedEntry] = os.time()

							trackedEntry.ExpiresAt = os.clock() + math.max(0, tonumber(2.6) or 0)
						elseif effectData.Radius ~= 13 or not effectData.Friendly or not effectData.Combo or not cfg.autofarm.farmcombococonuts then
							if not (effectData.Radius ~= 13 or not effectData.Friendly) then
								local coconutEntry = { Name = true, Position = effectData.Pos, Start = os.time() }
								tracked.coconuts[coconutEntry] = true

								coconutEntry.ExpiresAt = os.clock() + math.max(0, tonumber(effectData.Dur) or 0)
							end
						else
							local comboCoconutEntry = { Name = true, Position = effectData.Pos, Points = effectData.Points }
							tracked.combococonuts[comboCoconutEntry] = true

							comboCoconutEntry.ExpiresAt = os.clock() + math.max(0, tonumber(effectData.Dur) or 0)
						end
					end
				else
					local preciseEntry = tracked.precise2[effectData.ID]

					if preciseEntry then
						preciseEntry.Touched = true
					end

					if not cfg.antilag.precise then
						return true
					end
				end
			else
				tracked.precise2[effectData.ID] = { Name = true, ID = effectData.ID, Position = effectData.Pos, Mark = effectData.Mark }
				tracked.precisegroup[effectData.ID] = effectData.FEID

				tracked.precise2[effectData.ID].ExpiresAt = os.clock() + 2.5

				if not cfg.antilag.precise then
					return true
				end
			end
		end,
		ClientCall = function(callName, callArg)
			if callName == "CompleteQuest" or callName == "CompleteQuestFromPool" then
				setthreadidentity(8)
				local stats = discord.stats
				stats["Quests Done"] = stats["Quests Done"] + 1
				local questInfo = callName == "CompleteQuest" and secureCall(gameApi.Quests.Get, nil, callArg)
				local displayName = callName == "CompleteQuest" and questInfo and questInfo.DisplayName or callArg
				local npc = callName == "CompleteQuest" and questInfo and questInfo.NPC or callArg
				local v122 = callName == "CompleteQuestFromPool" and gameApi:Cache({ "Totals", "QuestPoolCounts", npc }) or npc == "Black Bear" and table.find(questData.blackbear, displayName) or npc == "Mother Bear" and table.find(questData.motherbear, displayName) or npc == "Panda Bear" and table.find(questData.pandabear, displayName) or npc == "Science Bear" and table.find(questData.sciencebear, displayName) or npc == "Dapper Bear" and table.find(questData.dapperbear, displayName) or npc == "Spirit Bear" and table.find(questData.spiritbear, displayName) or 0

				if callName == "CompleteQuestFromPool" then
					local lastQuestName = gameApi:Cache({ "Quests", "PoolLastQuests", npc })
					local lastQuest = secureCall(gameApi.Quests.Get, nil, lastQuestName)
					displayName = lastQuest.DisplayName or lastQuest.Name
				end

				discord.Send(string.gsub(string.gsub(displayName, npc .. ": ", ""), "Bear 2", "Bear"), (npc == "Polar Bear" and "Polar Power: " .. string.gsub(buffs.PolarBear.Text, "x", "") .. " <:PolarPower:1290695100439072798>" or "Total " .. string.gsub(npc, "Bear 2", "Bear") .. " Quests: " .. v122) .. "\nTimestamp: <t:" .. os.time() .. ":R>")
			end
		end,
		StationSpawn = function(stationData)
			tracked.marks[stationData.Id] = { Position = stationData.Model.Base.Position, Size = Vector2.new(stationData.Radius, 0) }
			local now = os.clock()

			while not stationData.Model:FindFirstChild("Sign") and os.clock() - now < 1 do
				RunService.Heartbeat:Wait()
			end

			local sign = stationData.Model:FindFirstChild("Sign")
			local decal = sign and sign:FindFirstChild("FrontDecal")
			if tracked and decal and string.match(decal.Texture, "%d+") == "8173559749" then
				tracked.precisemark[stationData.Id] = true
			end
		end,
		TokenSpawn = function(tokenData)
			if showerController.active or not cfg.detected.fastraretween or not (not state.stop and not state.fasttween and not state.stopfasttween and not (not state.rares[string.match(tokenData.Icon, "%d+")] and (not state.rares.Sticker or not tokenData.Rainbow))) then
				if tokenData.Icon ~= "rbxassetid://1629547638" then
					local tokenEntry = { Name = true, Position = tokenData.Pos, Rainbow = tokenData.Rainbow, Icon = tokenData.Icon }
					tracked.tokens[tokenEntry] = true

					tokenEntry.ExpiresAt = os.clock() + math.max(0, tonumber(tokenData.Dur) or 0)
				else
					local tokenEntry = { Name = true, Position = tokenData.Pos, Rainbow = tokenData.Rainbow, Icon = tokenData.Icon }
					tracked.tokenlink[tokenEntry] = true

					tokenEntry.ExpiresAt = os.clock() + math.max(0, tonumber(tokenData.Dur) or 0)
				end
			else
				local distance = distanceTo(tokenData.Pos)
				local tween = showerController:CreateMovementTween(getRootPart(), TweenInfo.new(distance / 200, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), { CFrame = CFrame.new(tokenData.Pos) })
				stopMovement()
				state.fasttween = true
				tween:Play()
				threadCount += 1

				threads:Add(threadCount, function()
					tween.Completed:Wait()
					task.wait(distance > 200 and 0.3 or 0.1)
					state.fasttween = nil
				end)
			end
		end,
		DupedTokenSpawn = function(owner, tokenData)
			local tokenEntry = { Name = true, ID = tokenData.ID, Position = tokenData.Pos, Icon = tokenData.Icon, Start = os.clock() }
			local listName = string.match(tostring(tokenData.Icon), "%d+") == "5877939956" and "dupedsmiley" or owner.dupedmap[tokenData.Icon] or "dupedtokens"
			tracked[listName][tokenData.ID] = tokenEntry

			tokenEntry.ExpiresAt = os.clock() + math.max(0, tokenData.EndTime - workspace.ServerTime.Value)
		end,
		DupedTokenDestroy = function(tokenId)
			tracked.dupedbear[tokenId] = nil
			tracked.dupedsmiley[tokenId] = nil
			tracked.dupedtokens[tokenId] = nil
		end,
		DupedTokenCharge = function(tokenId)
			local tokenEntry = tracked.dupedbear[tokenId] or tracked.dupedsmiley[tokenId] or tracked.dupedtokens[tokenId]

			if tokenEntry then
				tokenEntry.ChargeStart = os.clock()
			end
		end,
		DupedTokenUncharge = function(tokenId)
			local tokenEntry = tracked.dupedbear[tokenId] or tracked.dupedsmiley[tokenId] or tracked.dupedtokens[tokenId]

			if tokenEntry then
				tokenEntry.ChargeStart = nil
			end
		end,
	}
	connections:Add("runtimeCacheMaintenance", RunService.Heartbeat:Connect((function()
		local elapsed, pruneElapsed = 0, 0
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
			for name, list in pairs(tracked) do
				if type(list) == "table" and name ~= "flames" then
					for key, value in pairs(list) do
						local entry = type(key) == "table" and key or type(value) == "table" and value
						if entry and entry.ExpiresAt and now >= entry.ExpiresAt then
							list[key] = nil
							if name == "precise2" then tracked.precisegroup[key] = nil end
						end
					end
				end
			end
			for key in pairs(tracked.precisegroup) do
				if not tracked.precise2[key] then tracked.precisegroup[key] = nil end
			end
			for _, name in ipairs({"corruptedfield", "gummybeacon"}) do
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
		local touchedMarks = {}
		connections:Add("touchedMarkExpiry", RunService.Heartbeat:Connect((function()
			local elapsed = 0
			return function(dt)
				elapsed += dt
				if elapsed < 0.25 then return end
				elapsed = 0
				local now = os.clock()
				for mark, expires in pairs(touchedMarks) do
					if now >= expires then touchedMarks[mark] = nil end
				end
			end
		end)()))

	connections:Add("planters2", workspace.Planters.ChildRemoved:Connect(function(child)
		for i = #tracked.planters, 1, -1 do
			if tracked.planters[i].instance == child then table.remove(tracked.planters, i) end
		end
	end))

local function tick(dt)
 now+=dt
 connections.list.runtimeCacheMaintenance.fn(dt)
 connections.list.touchedMarkExpiry.fn(dt)
end
-- High churn: early collection must not leave one timer per token behind.
for cycle=1,100 do
 for i=1,1000 do
  tokenFilter.TokenSpawn({Icon="rbxassetid://2000457501",Pos=i,Dur=10})
  tokenFilter:DupedTokenSpawn({ID=i,Icon="rbxassetid://5877939956",Pos=i,EndTime=10})
  tokenFilter.DupedTokenDestroy(i)
 end
 assert(count(tracked.tokens)==1000 and count(tracked.dupedsmiley)==0)
 table.clear(tracked.tokens)
 tick(11)
 assert(count(tracked.tokens)==0 and count(tracked.dupedsmiley)==0)
end
-- ID reuse updates expiry instead of letting an old timer clear the replacement.
tokenFilter:DupedTokenSpawn({ID=1,Icon="rbxassetid://5877939956",Pos=1,EndTime=1})
tick(0.5)
tokenFilter:DupedTokenSpawn({ID=1,Icon="rbxassetid://5877939956",Pos=2,EndTime=5})
tick(1)
assert(tracked.dupedsmiley[1].Position==2)
tick(5);assert(not tracked.dupedsmiley[1])
tokenFilter:LocalFX("Bubble",{Action="Spawn",ID=3,Pos=1,Dur=1})
tick(0.5)
tokenFilter:LocalFX("Bubble",{Action="Spawn",ID=3,Pos=2,Dur=5})
tick(1);assert(tracked.bubbles[3].Position==2)
tick(5);assert(not tracked.bubbles[3])
tokenFilter:LocalFX("LocalTargetPracticeBeam",{Action="Make",Player=localPlayer,ID=4,Pos=1,FEID=9})
assert(tracked.precise2[4] and tracked.precisegroup[4]==9)
tick(3);assert(not tracked.precise2[4] and not tracked.precisegroup[4])
tokenFilter:LocalFX("LocalTargetPracticeBeam",{Action="Make",Player=localPlayer,ID=5,Pos=1,FEID=10})
tracked.precise2[5]=nil -- collected before its expiry
tick(0.25);assert(not tracked.precisegroup[5],"collected target retained group")
for _,event in ipairs({
 {"CogSawProjectile",{Pos1=1,Pos2=2,EndTime=1}},
 {"FallingStar",{Target=localPlayer,Pos=1}},
 {"MythicMeteor",{Pos=1,Radius=5,FallDuration=1}},
 {"PluckedPetal",{Pos=1,GoalPos=2,Duration=1}},
 {"FallingCoconut",{Target=localPlayer,Radius=20,Pos=1}},
 {"FallingCoconut",{Target=localPlayer,Radius=13,Friendly=true,Pos=1,Dur=1}},
 {"FallingCoconut",{Target=localPlayer,Radius=13,Friendly=true,Combo=true,Pos=1,Dur=1}},
})do tokenFilter:LocalFX(event[1],event[2])end
tokenFilter.TokenSpawn({Icon="rbxassetid://1629547638",Pos=1,Dur=1})
tick(4)
for name,list in pairs(tracked)do assert(next(list)==nil,"retained expired "..name)end
-- No-path entries now share the same bounded lifetime as successful visits.
for cycle=1,100 do
 for i=1,1000 do touchedMarks[{}]=os.clock()+3 end
 tick(4);assert(next(touchedMarks)==nil)
end
-- Removing an already-dismantled planter cannot depend on its GUI/name.
local removed={};local live={Parent=true}
tracked.planters={{instance=removed},{instance=live},{instance=removed}}
connections.list.planters2.fn(removed)
assert(#tracked.planters==1 and tracked.planters[1].instance==live)
live.Parent=nil;tick(5);assert(#tracked.planters==0)
-- A refreshed field corruption must survive the former expiry.
tracked.corruptedfield="Pine";tracked.corruptedfieldExpiresAt=now+240
tick(200);tracked.corruptedfield="Rose";tracked.corruptedfieldExpiresAt=now+240
tick(41);assert(tracked.corruptedfield=="Rose")
tick(200);assert(not tracked.corruptedfield and not tracked.corruptedfieldExpiresAt)
print("PASS: 100,000 ordinary + 100,000 duped lifecycles; reused IDs; all synthetic expiry branches; 100,000 touched marks; dismantled planters; refreshed alerts")
