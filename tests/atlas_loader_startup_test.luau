
local _G={}
local mode="success"
local calls={}
local game={}
function game:GetService()return {JSONDecode=function()return {} end}end
function game:HttpGet(url)
 table.insert(calls,url)
 if string.find(url,"api.github.com",1,true) then error("rate limited") end
 assert(string.find(url,"/main/atlasbss.lua",1,true))
 return "source"
end
local destroyed=false
local function loadstring()
 return function()
  if mode=="failure" then
   _G.loading=true
   _G.atlas={Destroy=function()destroyed=true end}
   error("simulated startup failure")
  end
  return "ready"
 end
end
local function bootstrap()
local http = game:GetService("HttpService")
local raw = "https://raw.githubusercontent.com/DarkBotGen/atlasbss/"
if _G.loading then return end

local ok, revision = pcall(function()
	local ref = http:JSONDecode(game:HttpGet("https://api.github.com/repos/DarkBotGen/atlasbss/git/ref/heads/main"))
	local sha = ref and ref.object and ref.object.sha
	assert(type(sha) == "string" and #sha == 40 and sha:match("^[%da-f]+$"))
	return sha
end)

local fetched, source = false, nil
if ok then fetched, source = pcall(function() return game:HttpGet(raw .. revision .. "/atlasbss.lua") end) end
if not fetched then
	fetched, source = pcall(function() return game:HttpGet(raw .. "main/atlasbss.lua") end)
end
if not fetched then error("Atlas+ download failed: " .. tostring(source), 0) end
local run, err = loadstring(source)
if not run then error("Atlas+ compile failed: " .. tostring(err), 0) end

local previous = _G.atlas
local started, result = xpcall(run, debug.traceback)
if not started then
	local partial = _G.atlas
	if partial and partial ~= previous then pcall(function() partial:Destroy() end) end
	_G.loading = nil
	error("Atlas+ startup failed: " .. tostring(result), 0)
end
return result

end
assert(bootstrap()=="ready" and #calls==2,"raw fallback should load when revision lookup fails")
mode="failure"
local ok,err=pcall(bootstrap)
assert(not ok and string.find(err,"simulated startup failure",1,true))
assert(not _G.loading and destroyed,"failed startup left a loading lock or partial GUI")
print("PASS: loader fallback, diagnostics, and failed initialization cleanup")
