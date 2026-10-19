local discord={stats={}}
local function deepCopy(value)
 if type(value)~="table"then return value end
 local copy={};for k,v in pairs(value)do copy[k]=deepCopy(v)end;return copy
end
local cfg={webhook={dashboard=true,key="test-key"}}
local localPlayer={UserId=123}
local graph={honey_12h={["174"]=45229609549236,["172"]=45224351960555,["166"]=45219308139059,["170"]=45222391954526,["169"]=45221303761582,["179"]=45238398624737,["167"]=45219861120570,["180"]=45238398868616,["173"]=45225939307557,["165"]=45218800751239,["171"]=45223625116184,["177"]=45234891904345,["178"]=45236087667896,["168"]=45220393033014,["175"]=45230732911292,["176"]=45232879080526},field={},buff_values2={}}
local payload={honey_12h=graph.honey_12h,buff_values={}}
local encoded
local HttpService={JSONEncode=function(_,body)
 for key in pairs(body.honey_12h)do assert(type(key)=="number"and key>=1 and key<=#body.honey_12h,"JSON object instead of array")end
 encoded=body;return body
end}
local sent
local function httprequest(request)sent=request;return true end
local logger={warn=function(err)error(err)end}
local task={wait=function()end}
	discord.Honey12hList = function(history)
		local values={}
		for bucket=0,180 do
			local value=history[tostring(bucket)]
			if value==nil then value=history[bucket] end
			if type(value)=="number" and value==value and math.abs(value)<math.huge then
				values[#values+1]=value
			end
		end
		return values
	end
		if not (not cfg.webhook.dashboard or cfg.webhook.key == "") then
			local ok, result = pcall(function()
				local copy = deepCopy(payload)
				copy.honey_12h=discord.Honey12hList(graph.honey_12h)
				copy.roblox_account_id = tostring(localPlayer.UserId)
				copy.hidebranding = nil

				if not copy.statsold then
					copy.statsold = discord.stats
				end

				local hasField

				for k in pairs(graph.field) do
					hasField = true
					break
				end

				if hasField then
					copy.field = graph.field
				end

				for _, buffName in ipairs({ "balloonpollen", "fieldcorruption", "flameheat", "precision", "precisemark" }) do
					copy.buff_values[buffName] = graph.buff_values2[buffName]
				end

				for k, buffValue in pairs(copy.buff_values) do
					local hasValue = nil

					for k2, sampleValue in pairs(buffValue) do
						if sampleValue ~= 0 then
							hasValue = true
						else
							buffValue[k2] = nil
						end
					end

					if not hasValue then
						copy.buff_values[k] = nil
					end
				end

				httprequest({
					Headers = { ["Content-Type"] = "application/json", ["X-API-Key"] = cfg.webhook.key },
					Method = "POST",
					Url = "https://api.gumtune.net/graph",
					Body = HttpService:JSONEncode(copy),
				}, "Failed to send graph to dashboard:")
			end)

			if not ok then
				task.wait()
				logger.warn(result)
			end
		end

assert(sent and sent.Url=="https://api.gumtune.net/graph","dashboard graph not sent")
assert(#encoded.honey_12h==16 and encoded.honey_12h[1]==45218800751239 and encoded.honey_12h[16]==45238398868616,"sparse history not sent in numeric bucket order")
assert(graph.honey_12h["165"]==45218800751239 and graph.honey_12h[1]==nil and payload.honey_12h==graph.honey_12h,"conversion mutated stored/other graph payload")
local indexed=discord.Honey12hList({[0]=1,[1]=2,[180]=3})
assert(#indexed==3 and indexed[1]==1 and indexed[3]==3,"numeric buckets not supported")
assert(#discord.Honey12hList({})==0,"empty history fabricated samples")
local filtered=discord.Honey12hList({["0"]=0,["1"]=0/0,["2"]=math.huge,["3"]="bad",["181"]=5})
assert(#filtered==1 and filtered[1]==0,"invalid or out-of-window samples retained")
print("PASS: exact 422 payload converted to chronological dense array; dashboard integration, unchanged history, numeric keys, empty/invalid samples")
