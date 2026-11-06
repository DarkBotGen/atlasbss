
local cfg,state={},{}
local claimed,hives
local localPlayer={FindFirstChild=function(_,key)if key=="Honeycomb" then return claimed end end}
local workspace={FindFirstChild=function(_,key)if key=="Honeycombs" then return hives end end}
local _G={}
local claimHive
local moves=0
local function goTo()moves+=1 end
local input={pressActivateButton=function(_,press)
 if press then claimed={Value={}} else return "Claim Hive" end
end}
local RunService={Heartbeat={Wait=function()end}}
	local function claimHiveSlot(slotIndex)
		local hives=workspace:FindFirstChild("Honeycombs")
		local hive=hives and hives:FindFirstChild("Hive"..slotIndex)
		local owner=hive and hive:FindFirstChild("Owner")
		local arrow=hive and hive:FindFirstChild("patharrow")
		local base=arrow and arrow:FindFirstChild("Base")
		if not owner or owner.Value or not base then return end
		local ok=pcall(goTo,base.Position,"Hive")
		if not ok or owner.Value then return end
		if input:pressActivateButton()~="Claim Hive" then return end
		input:pressActivateButton(true)
		local deadline=os.clock()+2
		repeat
			local claimed=localPlayer:FindFirstChild("Honeycomb")
			if claimed and claimed.Value then return end
			RunService.Heartbeat:Wait()
		until os.clock()>=deadline or not cfg
	end

	claimHive = function(refreshOnly)
		if _G.disablehive then
			state.bees=35
			return true
		end

		local claimed=localPlayer:FindFirstChild("Honeycomb")
		if not refreshOnly and not (claimed and claimed.Value) then
			local preferred=tonumber(_G.hive)
			if preferred and preferred%1==0 and preferred>=1 and preferred<=6 then
				claimHiveSlot(preferred)
			end
			for i=6,1,-1 do
				if not cfg or state.stop then break end
				claimed=localPlayer:FindFirstChild("Honeycomb")
				if claimed and claimed.Value then break end
				if i~=preferred then claimHiveSlot(i) end
			end
			claimed=localPlayer:FindFirstChild("Honeycomb")
		end

		if not cfg then return false end
		state.hive=claimed and claimed.Value or nil
		local gates = workspace:FindFirstChild("Gates")
		if not gates then state.bees=state.bees or 0;return state.hive~=nil end
		local gate35 = gates:FindFirstChild("35 Bee Gate")
		local gate30 = gates:FindFirstChild("30 Bee Gate")
		local gate25 = gates:FindFirstChild("25 Bee Gate")
		local gate20 = gates:FindFirstChild("20 Bee Gate")
		local gate15 = gates:FindFirstChild("15 Bee Gate")
		local gate10 = gates:FindFirstChild("10 Bee Gate")
		local gate5 = gates:FindFirstChild("5 Bee Gate")
		local DapperShop = gates:FindFirstChild("Dapper Shop")
		local BlueHQGate = gates:FindFirstChild("Blue HQ Gate")
		local RedHQGate = gates:FindFirstChild("Red HQ Gate")

		if not (not DapperShop or (not DapperShop:FindFirstChild("Door") or DapperShop.Door.CanCollide)) then
			state.dapper = true
		end

		if not (not BlueHQGate or (not BlueHQGate:FindFirstChild("Door") or BlueHQGate.Door.CanCollide)) then
			state.bluehq = true
		end

		if not (not RedHQGate or (not RedHQGate:FindFirstChild("Door") or RedHQGate.Door.CanCollide)) then
			state.redhq = true
		end

		if not (not gate35 or (not gate35:FindFirstChild("Door") or gate35.Door.CanCollide)) then
			state.bees = 35
		elseif not (not gate30 or (not gate30:FindFirstChild("Door") or gate30.Door.CanCollide)) then
			state.bees = 30
		elseif not (not gate25 or (not gate25:FindFirstChild("Door") or gate25.Door.CanCollide)) then
			state.bees = 25
		elseif not (not gate20 or (not gate20:FindFirstChild("Door") or gate20.Door.CanCollide)) then
			state.bees = 20
		elseif not (not gate15 or (not gate15:FindFirstChild("Door") or gate15.Door.CanCollide)) then
			state.bees = 15
		elseif not gate10 or (not gate10:FindFirstChild("Door") or gate10.Door.CanCollide) then
			if not gate5 or (not gate5:FindFirstChild("Door") or gate5.Door.CanCollide) then
				state.bees = 0
			else
				state.bees = 5
			end
		else
			state.bees = 10
		end
		return state.hive~=nil
	end

assert(not claimHive(true) and state.bees==0 and moves==0)
assert(not claimHive() and moves==0)
claimed={Value=nil}
local base={Position={}}
local arrow={FindFirstChild=function(_,k)if k=="Base" then return base end end}
local hive={FindFirstChild=function(_,k)if k=="Owner" then return {} elseif k=="patharrow" then return arrow end end}
hives={FindFirstChild=function(_,k)if k=="Hive6" then return hive end end}
assert(claimHive() and state.hive and moves==1,"claim succeeds once data is available")
assert(claimHive() and moves==1,"existing hive is not claimed again")
print("PASS: missing hive data does not block initialization; retry claims once the slot becomes available")
