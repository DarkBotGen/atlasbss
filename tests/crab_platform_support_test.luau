local function part()
 local p={Parent=true,CanCollide=false,Anchored=false,Size={X=40,Z=30}}
 p.CFrame={PointToObjectSpace=function(_,point)return point end}
 function p:Destroy()self.Parent=nil end
 return p
end
local h={Health=100};local root=part()
local char={FindFirstChildOfClass=function()return h end,FindFirstChild=function()return root end}
local localPlayer={Character=char};local state={}
local listener
local connections={Cancel=function()listener=nil end,Add=function(_,id,c)listener=c end}
local RunService={PreSimulation={Connect=function(_,fn)return {fn=fn}end}}
local crabPlatformSupport = {saved={}}
function crabPlatformSupport:Release()
	connections:Cancel("crabPlatformSupport")
	for part, value in pairs(self.saved) do
		if part.Parent then part.CanCollide=value end
	end
	table.clear(self.saved)
	local platform=self.platform
	self.platform=nil
	if platform then platform:Destroy() end
end
function crabPlatformSupport:Start(platform)
	self:Release()
	self.platform=platform
	local character=localPlayer.Character
	connections:Add("crabPlatformSupport",RunService.PreSimulation:Connect(function()
		if not platform.Parent or localPlayer.Character~=character or not state or state.stop then self:Release();return end
		local h=character:FindFirstChildOfClass("Humanoid")
		local root=character:FindFirstChild("HumanoidRootPart")
		if not h or h.Health<=0 or not root then self:Release();return end
		platform.Anchored=true;platform.CanCollide=true
		-- Travel owns noclip until it finishes. Keep a collidable body on the support afterwards.
		if not state.tweennoclip then
			if self.saved[root]==nil then self.saved[root]=root.CanCollide end
			root.CanCollide=true
		end
	end))
end
function crabPlatformSupport:Inside(point, margin)
	local platform=self.platform
	if not platform or not platform.Parent then return false end
	local p=platform.CFrame:PointToObjectSpace(point)
	return math.abs(p.X)<=platform.Size.X/2-margin and math.abs(p.Z)<=platform.Size.Z/2-margin
end

local p=part();crabPlatformSupport:Start(p)
listener.fn();assert(p.CanCollide and p.Anchored and root.CanCollide)
assert(crabPlatformSupport:Inside({X=15,Z=10},4))
assert(not crabPlatformSupport:Inside({X=18,Z=0},4),"side departure missed")
root.CanCollide=false;state.tweennoclip=true;listener.fn();assert(not root.CanCollide,"guard fought travel noclip")
state.tweennoclip=nil;listener.fn();assert(root.CanCollide)
crabPlatformSupport:Release();assert(not root.CanCollide and not p.Parent and not listener)
for i=1,1000 do local platform=part();crabPlatformSupport:Start(platform);listener.fn();crabPlatformSupport:Release();assert(not platform.Parent and not next(crabPlatformSupport.saved))end
p=part();crabPlatformSupport:Start(p);listener.fn();h.Health=0;listener.fn()
assert(not p.Parent and not listener and not root.CanCollide)
h.Health=100;p=part();crabPlatformSupport:Start(p);listener.fn();localPlayer.Character={};listener.fn()
assert(not p.Parent and not listener)
print("PASS: crab support collision, edge detection, noclip ownership, death/respawn cleanup and 1,000 fight lifecycles")
