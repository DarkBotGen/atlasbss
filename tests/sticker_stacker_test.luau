local now=1000
local os={clock=function()return now end}
local cfg={toys={stackall=true,stackmethod="Tickets",stackselect=false}}
local toyUse={time={}}
local inventory={Has=function()return false end}
local files={}
local function file(name)return {GetTypeName=function()return name end}end
local secureCall=function(fn,...)return fn(...)end
local sent={}
local gameApi={StickerStack={GetDonatableStickerFiles=function()return files end}}
function gameApi:Cache()return {}end
function gameApi:Event(name,value)assert(name=="StickerStackActivate");sent[#sent+1]=value end
local workspace={Toys={["Sticker Stack"]={Platform={Position={}}}}}
local reportStatus=function()end
local logger={log=function()end}
local goTo=function()end
local disabled=false
local controls={["Auto Sticker Stacker"]={Set=function()disabled=true end}}
local ui={Notify=function()end}
local useToyTimed
		useToyTimed = function(label)
			local ok = not toyUse.time[label]

			if not ok then
				local lastUse = toyUse.time[label]
				ok = not (os.clock() - lastUse < 300)
			end

			if ok then
				local stackMethod=cfg.toys.stackall~=false and "Stickers" or cfg.toys.stackmethod
				if stackMethod ~= "Tickets" or inventory:Has({ Ticket = 25 }) then
					if stackMethod ~= "Stickers" then
						reportStatus(3)
						logger.log("Doing Sticker Stacker")
						goTo(workspace.Toys[label].Platform.Position, label)
						toyUse.time[label] = os.clock()
						gameApi:Event("StickerStackActivate", "Tickets")
					else
						local selectedCount = 0

						if cfg.toys.stackselect then
							for k in pairs(cfg.toys.stackselect) do
								selectedCount += 1
							end
						end

						if cfg.toys.stackall==false and selectedCount == 0 then
							controls["Auto Sticker Stacker"].Set(false)
							ui.Notify("Auto Sticker Stacker", "No stickers selected")
							return
						end

						local stickerFile = nil
						local stickerName = nil
						local donatableFiles = secureCall(gameApi.StickerStack.GetDonatableStickerFiles, gameApi:Cache())
						if not donatableFiles then
							toyUse.time[label] = os.clock()
							return
						end

						for _, file in ipairs(donatableFiles) do
							local typeName = secureCall(file.GetTypeName, file)

							if typeName and (cfg.toys.stackall~=false or (cfg.toys.stackselect and cfg.toys.stackselect[typeName])) then
								stickerName = typeName
								stickerFile = file
								break
							end
						end

						if not stickerFile then
							toyUse.time[label] = os.clock()
							return
						end
						reportStatus(3)
						logger.log("Doing Sticker Stacker (" .. stickerName .. ")")
						goTo(workspace.Toys[label].Platform.Position, label)
						toyUse.time[label] = os.clock()
						gameApi:Event("StickerStackActivate", stickerFile)
					end

					return
				end
			end
		end

for _,name in ipairs({"Aries Star Sign","Rare Cub Skin","Simple Sun"})do
 files={file(name)}
 useToyTimed("Sticker Stack")
 assert(sent[#sent]==files[1],"eligible sticker skipped: "..name)
 now+=301
end
assert(#sent==3 and not disabled,"all-inventory mode required a selected list")
files=nil
useToyTimed("Sticker Stack")
assert(#sent==3 and not disabled,"empty inventory should remain enabled")
now+=301
cfg.toys.stackall=false;cfg.toys.stackmethod="Stickers";cfg.toys.stackselect={["Aries Star Sign"]=true}
files={file("Simple Sun"),file("Aries Star Sign")}
useToyTimed("Sticker Stack")
assert(sent[#sent]==files[2],"manual rare selection failed")
now+=301;cfg.toys.stackmethod="Tickets"
useToyTimed("Sticker Stack")
assert(#sent==4,"spent tickets without inventory")
print("PASS: all eligible stickers, rare types, fresh inventory, nil inventory, manual selection, ticket fallback")
