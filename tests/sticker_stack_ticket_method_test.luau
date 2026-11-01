local now=1000
local os={clock=function()return now end}
local cfg={toys={stackall=true,stackmethod="Tickets"}}
local toyUse={time={}}
local tickets=25
local inventory={Has=function(_,required)return tickets>=required.Ticket end}
local workspace={Toys={["Sticker Stack"]={Platform={Position={}}}}}
local calls=0
local gameApi={Event=function(_,name,arg)assert(name=="StickerStackActivate" and arg=="Tickets");calls+=1 end}
local function reportStatus()end
local logger={log=function()end}
local function goTo()end
local useToyTimed
		useToyTimed = function(label)
			local ok = not toyUse.time[label]

			if not ok then
				local lastUse = toyUse.time[label]
				ok = not (os.clock() - lastUse < 300)
			end

			if ok then
				local stackMethod=cfg.toys.stackmethod
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

useToyTimed("Sticker Stack");assert(calls==1,"Stack All must not override ticket method")
useToyTimed("Sticker Stack");assert(calls==1,"cooldown bypassed")
now=1301;tickets=24;useToyTimed("Sticker Stack");assert(calls==1,"insufficient tickets")
tickets=25;useToyTimed("Sticker Stack");assert(calls==2)
print("PASS: ticket method wins over Stack All, 25-ticket requirement and repeat cooldown")
