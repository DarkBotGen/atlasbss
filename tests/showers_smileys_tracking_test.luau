
local now = 0
local dupedTokenPolicy = {Observe=function() end}
local os = {clock=function() return now end}
local function signal()
 local listeners = {}
 return {Connect=function(_, fn)
  local c = {Connected=true, fn=fn}
  function c:Disconnect() self.Connected=false end
  table.insert(listeners,c)
  return c
 end, Fire=function(_, ...)
  for _, c in ipairs(listeners) do if c.Connected then c.fn(...) end end
 end}
end
local connections = {list={}}
function connections:Get(id) return self.list[id] end
function connections:Cancel(id) if self.list[id] then self.list[id]:Disconnect(); self.list[id]=nil end end
function connections:Add(id,c) self:Cancel(id); self.list[id]=c end
local cfg = {autoquest={dupedtokens=false},autofarm={farmdupedtokens=false}}
local tracked = {dupedbear={},dupedsmiley={},dupedtokens={}}
local folder = {ChildAdded=signal(),ChildRemoved=signal(), children={}}
function folder:GetChildren() return self.children end
local workspace={Camera={FindFirstChild=function() return folder end}}
local RunService={Heartbeat=signal()}
local function token(texture)
 local child={Parent=folder,decal=texture and {Texture=texture}}
 function child:IsA() return true end
 function child:FindFirstChild() return self.decal end
 return child
end
local existing=token("rbxassetid://5877939956")
table.insert(folder.children,existing)
local watchDupedTokens
	watchDupedTokens = function(enable)
		if not enable then
			if cfg.autoquest.dupedtokens or cfg.autofarm.farmdupedtokens then return end
			connections:Cancel("dupedtokens")
			connections:Cancel("dupedtokens2")
			connections:Cancel("dupedPending")
			table.clear(tracked.dupedbear)
			table.clear(tracked.dupedsmiley)
			table.clear(tracked.dupedtokens)
			return
		end
		if connections:Get("dupedtokens") then return end
		local folder = workspace.Camera:FindFirstChild("DupedTokens")
		if not folder then return end
		local pending = {}
		local bears = { ["1472425802"]=true, ["1472580249"]=true, ["1472532912"]=true,
			["2032949183"]=true, ["1472491940"]=true, ["1489734171"]=true, ["1837410537"]=true }
		local function classify(child, started)
			if child.Parent ~= folder or not child:IsA("BasePart") then return true end
			local decal = child:FindFirstChild("FrontDecal")
			local id = decal and string.match(decal.Texture, "%d+")
			if not id then return false end
			if id == "5877939956" then tracked.dupedsmiley[child] = started
			elseif bears[id] then tracked.dupedbear[child] = started
			else tracked.dupedtokens[child] = {decal=decal, time=started} end
			return true
		end
		local function added(child)
			local started = os.clock()
			if not classify(child, started) then pending[child] = started end
		end
		connections:Add("dupedtokens", folder.ChildAdded:Connect(added))
		connections:Add("dupedtokens2", folder.ChildRemoved:Connect(function(child)
			pending[child] = nil
			tracked.dupedbear[child] = nil
			tracked.dupedsmiley[child] = nil
			tracked.dupedtokens[child] = nil
		end))
		connections:Add("dupedPending", RunService.Heartbeat:Connect(function()
			for child, started in pairs(pending) do
				if classify(child, started) or os.clock() - started > 30 then pending[child] = nil end
			end
		end))
		for _, child in ipairs(folder:GetChildren()) do added(child) end
	end

watchDupedTokens(true)
assert(tracked.dupedsmiley[existing] == 0, "startup token missed")
local late=token(nil)
folder.ChildAdded:Fire(late)
now=2
late.decal={Texture="https://www.roblox.com/asset/?id=5877939956"}
RunService.Heartbeat:Fire()
assert(tracked.dupedsmiley[late] == 0, "late decal missed or timestamp reset")
assert(tracked.dupedtokens[late] == nil, "smiley misclassified")
late.Parent=nil
folder.ChildRemoved:Fire(late)
assert(tracked.dupedsmiley[late] == nil, "removed token retained")
local before=connections:Get("dupedtokens")
watchDupedTokens(true)
assert(connections:Get("dupedtokens") == before, "duplicate watcher")
watchDupedTokens(false)
assert(next(connections.list)==nil and next(tracked.dupedsmiley)==nil, "disable leaked state")
print("PASS: smiley startup, late decal, URL formats, removal, idempotence, disable cleanup")
