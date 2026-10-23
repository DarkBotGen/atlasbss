local saved=0
local cfg={rbc={enabled=true}}
local state={config="RBC"}
local Enum={TeleportState={Started=1,InProgress=2,Failed=3}}
local connections={Add=function(_,id,c)assert(id=="saveBeforeTeleport")end}
local callback
local localPlayer={OnTeleport={Connect=function(_,fn)callback=fn;return {} end}}
local function saveConfig()assert(cfg.rbc.enabled and state.config=="RBC");saved+=1 end
	connections:Add("saveBeforeTeleport", localPlayer.OnTeleport:Connect(function(teleportState)
		if teleportState == Enum.TeleportState.Started or teleportState == Enum.TeleportState.InProgress then
			if cfg and state and state.config then
				local ok, err = pcall(saveConfig)
				if not ok then warn("Atlas+ RBC Edition: failed to save before teleport: " .. tostring(err)) end
			end
		end
	end))
callback(Enum.TeleportState.Started);callback(Enum.TeleportState.InProgress)
assert(saved==2,"teleport failed to flush enabled RBC")
callback(Enum.TeleportState.Failed);assert(saved==2)
state=nil;callback(Enum.TeleportState.Started);assert(saved==2,"unloaded script attempted save")
print("PASS: teleport saves active RBC config, ignores failures, and tolerates unloaded state")
