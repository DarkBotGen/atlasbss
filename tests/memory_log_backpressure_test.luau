
local clock=0
local os={clock=function()return clock end,date=function()return "time"end}
local state={}
local cfg={webhook={dashboard=true,key="test",enabled=true,console=true,url="test"}}
local threadCount=0
local logger={}
local tasks={}
local threads={Get=function(_,id)return tasks[id]end,Add=function(_,id,fn)assert(not tasks[id]);tasks[id]=fn end}
local labelsAlive=0
local Instance={new=function()labelsAlive+=1;return {Destroy=function()labelsAlive-=1 end}end}
local Enum={Font={Ubuntu=1},TextXAlignment={Left=1}}
local Vector2={new=function(x,y)return {X=x,Y=y}end}
local UDim2={new=function()return {}end}
local TextService={GetTextSize=function()return {X=10}end}
local DateTime={now=function()return {ToIsoDate=function()return "date"end}end}
local ScrollingFrame={CanvasPosition={Y=0},AbsoluteCanvasSize={Y=0},AbsoluteWindowSize={Y=0}}
		local now = os.clock()
		local pendingLogs = {}
		local consoleLines = {}
		local consoleLabels = {}

		logger.print = function(level, textColor3, ...)
			local args = { ... }
			local message

			if level ~= "Table" then
				for i = 1, #args do
					args[i] = tostring(args[i])
				end

				message = table.concat(args, " ")
			else
				local formattedArgs = table.create(#args)

				for i = 1, #args do
					local argValue = args[i]

					if type(argValue) ~= "table" then
						argValue = { argValue }
					end

					formattedArgs[i] = serializeTable(argValue)
				end

				message = table.concat(formattedArgs, "\n")
			end

			local prefix = "[" .. os.date("%X") .. "] [" .. level .. "] "
			local atBottom = ScrollingFrame.CanvasPosition.Y >= ScrollingFrame.AbsoluteCanvasSize.Y - ScrollingFrame.AbsoluteWindowSize.Y - 5

			for match in string.gmatch(message, "([^\n]+)") do
				local text = prefix .. match
				local textSize = TextService:GetTextSize(text, 14, Enum.Font.Ubuntu, Vector2.new(math.huge, 0))
				prefix = ""
				local TextLabel3 = Instance.new("TextLabel")
				TextLabel3.BackgroundTransparency = 1
				TextLabel3.Font = Enum.Font.Ubuntu
				TextLabel3.Text = text
				TextLabel3.TextSize = 14
				TextLabel3.TextColor3 = textColor3
				TextLabel3.TextXAlignment = Enum.TextXAlignment.Left
				TextLabel3.Size = UDim2.new(0, textSize.X, 0, 15)
				TextLabel3.Parent = ScrollingFrame
				table.insert(consoleLabels, TextLabel3)

				if not state.disconnect and not (not cfg.webhook.dashboard or cfg.webhook.key == "") then
					local insert = table.insert
					local v77 = pendingLogs
					local logEntry = {}
					local timestamp = DateTime.now()

					do
						local values = table.pack(match, level, timestamp:ToIsoDate())
						table.move(values, 1, values.n, 1, logEntry)
					end

					if #v77 >= 200 then table.remove(v77, 1) end
					insert(v77, logEntry)

					if (not now or os.clock() - now >= 40) and not threads:Get("dashboardLogSend") then
						local batch = table.clone(pendingLogs)
						table.clear(pendingLogs)
						now = os.clock()
						local payloadLogs = {}

						for _, batchEntry in ipairs(batch) do
							table.insert(payloadLogs, {
								timestamp = batchEntry[3],
								log_level = batchEntry[2] == "Warn" and "warning" or batchEntry[2] == "Error" and "error" or "info",
								content = batchEntry[1],
							})
						end

						threadCount += 1

						threads:Add("dashboardLogSend", function()
							httprequest({
								Headers = { ["Content-Type"] = "application/json", ["X-API-Key"] = cfg.webhook.key },
								Method = "POST",
								Url = "https://api.gumtune.net/logs/batch_new",
								Body = HttpService:JSONEncode({ roblox_account_id = tostring(localPlayer.UserId), logs = payloadLogs }),
							}, "Failed to send logs to dashboard:")
						end)
					end
				end

				if #consoleLabels > 30 then
					local oldestLabel = table.remove(consoleLabels, 1)

					if not state.disconnect and not (not cfg.webhook.enabled or not cfg.webhook.console or cfg.webhook.url == "") then
						if #consoleLines >= 20 then table.remove(consoleLines, 1) end
						table.insert(consoleLines, oldestLabel.Text)

						if #consoleLines >= 20 and not threads:Get("consoleLogSend") then
							local linesCopy = table.clone(consoleLines)
							table.clear(consoleLines)
							threadCount += 1

							threads:Add("consoleLogSend", function()
								discord.Send("Atlas Console", "```" .. table.concat(linesCopy, "\n") .. "```", true)
							end)
						end
					end

					oldestLabel:Destroy()
				end
			end

			if atBottom then
				ScrollingFrame.CanvasPosition = Vector2.new(0, ScrollingFrame.AbsoluteCanvasSize.Y)
			end
		end
for i=1,10000 do
 clock+=1
 logger.print("Info",{},"record "..i)
end
local count=0;for _ in pairs(tasks)do count+=1 end
assert(count==2,"stalled transport accumulated workers")
assert(#pendingLogs==200 and #consoleLines==20,"log queue grew beyond bound")
assert(#consoleLabels==30 and labelsAlive==30,"GUI labels leaked")
-- Simulate request completion: a later message may start the next bounded batch.
tasks.dashboardLogSend=nil;tasks.consoleLogSend=nil;clock+=41
logger.print("Info",{},"network recovered")
assert(tasks.dashboardLogSend and tasks.consoleLogSend)
assert(#pendingLogs==0 and #consoleLines==0 and labelsAlive==30)
print("PASS: 10,000 logs with stalled requests retain two workers, 220 queued lines, 30 labels; recovery flushes")
