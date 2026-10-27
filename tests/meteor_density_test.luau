local now=0
local os={clock=function()return now end}
local cfg={autofarm={dynamicmeteors=true}}
local fieldPositionPolicy={ReleaseIdle=function()end}
local PhysicalProperties={new=function(d,f,e,fw,ew)return {Density=d,Friction=f,Elasticity=e,FrictionWeight=fw,ElasticityWeight=ew}end}
local function part()return {Parent=true,Massless=true,CurrentPhysicalProperties={Density=.7,Friction=.3,Elasticity=.5,FrictionWeight=1,ElasticityWeight=1},IsA=function()return true end,FindFirstAncestorOfClass=function()return nil end}end
local root=part();root.Position={}
local target={}
local mt={__sub=function()return {X=10,Z=0}end};setmetatable(target,mt)
local torso=part()
local localPlayer={Character={GetDescendants=function()return {root,torso}end}}
local h={Parent=true,WalkSpeed=100}
local function getRootPart()return root end
local function getHumanoid()return h end
local smoothMovement={MoveTo=function()end}
local meteorMovement={}
function meteorMovement:Release()
	for part, saved in pairs(self.densityParts or {}) do
		if part.Parent then
			if part.CustomPhysicalProperties==saved.assigned then part.CustomPhysicalProperties=saved.original end
			if part.Massless==false then part.Massless=saved.massless end
		end
	end
	self.densityParts=nil
	local h=self.humanoid
	if h and h.Parent and h.WalkSpeed==self.assigned then h.WalkSpeed=self.original end
	if self.root and self.root.Parent then
		if self.root.CustomPhysicalProperties==self.massAssigned then self.root.CustomPhysicalProperties=self.massOriginal end
		if self.root.Massless==false then self.root.Massless=self.masslessOriginal end
	end
	self.root,self.massOriginal,self.massAssigned,self.masslessOriginal,self.massBase,self.massFactor=nil,nil,nil,nil,nil,nil
	self.humanoid,self.original,self.assigned,self.pulse=nil,nil,nil,nil
end
function meteorMovement:Chase(object,deadline)
	fieldPositionPolicy:ReleaseIdle()
	local h=getHumanoid()
	if not cfg.autofarm.dynamicmeteors then self:Release()
	else
		if self.humanoid~=h or self.root and self.root~=getRootPart() then self:Release();self.humanoid=h;self.original=h.WalkSpeed end
		if self.assigned and h.WalkSpeed~=self.assigned then self.original=h.WalkSpeed end
		local delta=object.Position-getRootPart().Position
		local distance=math.sqrt(delta.X*delta.X+delta.Z*delta.Z)
		local expires=deadline and deadline<math.huge and deadline or (type(object)=="table" and object.ExpiresAt)
		local remaining=expires and math.max(0.05,expires-os.clock()-0.15) or 0.4
		local speed=math.max(self.original,math.min(210,math.max(80,distance/remaining)))
		h.WalkSpeed=speed;self.assigned=speed;self.pulse=os.clock()
		local root=getRootPart()
		if not self.root then
			self.root=root;self.massOriginal=root.CustomPhysicalProperties
			self.masslessOriginal=root.Massless;self.massBase=root.CurrentPhysicalProperties
		end
		-- Full 10x density during the actual chase, independent of the speed multiplier.
		-- Include character body parts so a light root does not leave the assembly unchanged.
		self.densityParts=self.densityParts or {}
		for _,part in ipairs(localPlayer.Character:GetDescendants()) do
			if part:IsA("BasePart") and not part:FindFirstAncestorOfClass("Accessory") then
				local saved=self.densityParts[part]
				if not saved then
					local base=part.CurrentPhysicalProperties
					saved={original=part.CustomPhysicalProperties,massless=part.Massless,
						assigned=PhysicalProperties.new(math.clamp(base.Density*10,.01,100),base.Friction,base.Elasticity,base.FrictionWeight,base.ElasticityWeight)}
					self.densityParts[part]=saved
				end
				part.Massless=false
				part.CustomPhysicalProperties=saved.assigned
			end
		end
	end
	smoothMovement:MoveTo(object.Position)
end

meteorMovement:Chase({Position=target},1)
assert(root.CustomPhysicalProperties.Density==7 and torso.CustomPhysicalProperties.Density==7)
assert(not root.Massless and not torso.Massless)
meteorMovement:Release()
assert(root.CustomPhysicalProperties==nil and torso.CustomPhysicalProperties==nil)
assert(root.Massless and torso.Massless and h.WalkSpeed==100)
for i=1,1000 do meteorMovement:Chase({Position=target},1);meteorMovement:Release()end
assert(not meteorMovement.densityParts)
print("PASS: fixed 10x meteor body density, speed/massless/property restoration and 1,000 chase lifecycles")
