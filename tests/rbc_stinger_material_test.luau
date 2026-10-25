local now,uses,saves=0,0,0
local os={time=function()return now end}
local cache={Materials={}}
local inventory={Use=function()uses+=1;return true end}
local logger={log=function()end}
local function saveConfig()saves+=1 end
local function run(rbcMaterial,useOptions)
 local materialName="Stinger"
 for _=1,1 do
					if materialName=="Stinger" and rbcMaterial and rbcMaterial[1]
						and (not rbcMaterial[3] or not rbcMaterial[3][useOptions.Round]) then
						-- Mob selections are stored as exclusions by the materials UI.
						local excluded=rbcMaterial[4]
						local shouldUse=type(excluded)~="table" or next(excluded)==nil
						if not shouldUse then
							for mob, active in pairs(useOptions.Mobs or {}) do
								if active and not excluded[mob] then shouldUse=true;break end
							end
						end
						local interval=rbcMaterial[5] and 10 or math.max(10,tonumber(rbcMaterial[2]) or 29)
						local lastUsed=cache.Materials[materialName]
						if shouldUse and (not lastUsed or os.time()-lastUsed>=interval) then
							if inventory:Use(materialName,true) then
								logger.log("Using material:",materialName)
								cache.Materials[materialName]=os.time()
								saveConfig(true)
							end
						end
					end

 end
end
local config={true,15,false,false,false}
run(config,{Round="Round 1"});assert(uses==1)
now=14;run(config,{});assert(uses==1)
now=15;run(config,{});assert(uses==2 and saves==2)
now=30;config[3]={["Round 2"]=true};run(config,{Round="Round 2"});assert(uses==2)
config[3]=false;config[4]={Cogturrets=true}
run(config,{Mobs={Cogturrets=true}});assert(uses==2)
run(config,{Mobs={["Field Cogmowers"]=true}});assert(uses==3)
now=40;config[5]=true;run(config,{Mobs={["Field Cogmowers"]=true}});assert(uses==4)
config[1]=false;now=100;run(config,{});assert(uses==4)
print("PASS: RBC stingers without filters, configured interval, round/mob exclusions, Star Saw cadence and disabled option")
