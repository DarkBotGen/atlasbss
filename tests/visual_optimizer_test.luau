
local Enum={Material={SmoothPlastic="Plastic"},QualityLevel={Level01=1}}
local renders={QualityLevel=5}
local function settings() return {Rendering=renders} end
local task={wait=function()end}
local localPlayer={}
local function getService() return {GetPlayerFromCharacter=function() return nil end} end
local function object(class,name,parent)
 local o={ClassName=class,Name=name,Parent=parent,children={},Texture="icon",TextureID="mesh",TextureId="mesh",Enabled=true,
  CastShadow=true,Reflectance=0.5,Material="Grass",LocalTransparencyModifier=0,Transparency=0,CanCollide=true}
 if parent then table.insert(parent.children,o) end
 function o:IsA(c)
  return self.ClassName==c or c=="BasePart" and (self.ClassName=="Part" or self.ClassName=="MeshPart")
   or c=="Light" and self.ClassName=="PointLight" or c=="PostEffect" and self.ClassName=="BloomEffect"
 end
 function o:IsDescendantOf(root) local n=self.Parent;while n do if n==root then return true end;n=n.Parent end;return false end
 function o:FindFirstAncestorOfClass() return nil end
 function o:Clear() self.cleared=true end
 function o:Destroy() error("game object destroyed") end
 function o:GetDescendants()
  local all={}
  local function visit(n) for _,child in ipairs(n.children) do table.insert(all,child);visit(child) end end
  visit(self);return all
 end
 o.DescendantAdded={Connect=function(_,fn)return {Connected=true,fn=fn,Disconnect=function(self)self.Connected=false end}end}
 o.DescendantRemoving=o.DescendantAdded
 return o
end
local workspace=object("Workspace","Workspace",nil)
workspace.Terrain={WaterWaveSize=1,WaterWaveSpeed=1,WaterReflectance=1}
local Lighting=object("Lighting","Lighting",nil)
Lighting.GlobalShadows=true
local threads={list={}}
function threads:Cancel(id) self.list[id]=nil end
function threads:Add(id,fn)self.list[id]=fn;fn();self.list[id]=nil end
local connections={list={}}
function connections:Cancel(id)if self.list[id] then self.list[id]:Disconnect();self.list[id]=nil end end
function connections:Add(id,c)self:Cancel(id);self.list[id]=c end
-- Visual-only optimization. Never destroy or reparent game-owned objects.
local visualOptimizer = {
	modes = {}, originals = {},
	decorative = {Map=true,Decorations=true,FieldDecos=true,Amulets=true,["Shell Amulets"]=true,
		["Stickbug Amulets"]=true,Campsite=true,Leaderboards=true,HiveDeco=true,
		TheGames_WideBanners=true},
	protected = {Collectibles=true,DupedTokens=true,Particles=true,Stations=true,
		PoppablePlants=true,Monsters=true,MonsterSpawners=true,Toys=true,NPCs=true,
		Honeycombs=true,FlowerZones=true,PlayerFlames=true,Clouds=true,Balloons=true},
}

function visualOptimizer:Remember(object, property, value)
	local ok, previous = pcall(function() return object[property] end)
	if not ok or previous == value then return end
	local saved = self.originals[object]
	if not saved then saved={};self.originals[object]=saved end
	if saved[property] == nil then saved[property]=previous end
	pcall(function() object[property]=value end)
end

function visualOptimizer:Restore()
	for object, properties in pairs(self.originals) do
		for property, value in pairs(properties) do pcall(function() object[property]=value end) end
	end
	table.clear(self.originals)
end

-- Explicit lifetime: weak Instance keys can disappear before restoration, and
-- removed objects must not leave saved-property records behind.
function visualOptimizer:Release(object)
	local properties = self.originals[object]
	if not properties then return end
	self.originals[object] = nil
	for property, value in pairs(properties) do pcall(function() object[property]=value end) end
end

function visualOptimizer:Apply(object)
	if not object.Parent then return end
	local cosmetic, protected, bees, flowers, balloons, otherPlayer = false,false,false,false,false,false
	local ancestor = object
	while ancestor and ancestor ~= workspace do
		if self.decorative[ancestor.Name] then cosmetic=true end
		if self.protected[ancestor.Name] then protected=true end
		if string.find(ancestor.Name,"Sign",1,true) then protected=true end
		if ancestor.Name == "Bees" then bees=true end
		if ancestor.Name == "Flowers" then flowers=true end
		if ancestor.Name == "FieldBalloons" then balloons=true end
		ancestor=ancestor.Parent
	end
	if self.modes.players then
		local model=object:FindFirstAncestorOfClass("Model")
		local player=model and getService("Players"):GetPlayerFromCharacter(model)
		otherPlayer=player ~= nil and player ~= localPlayer
	end
	local aggressive=self.modes.aggressive
	local effects=aggressive or self.modes.effects
	local textures=aggressive or self.modes.textures
	local hide=((self.modes.decorations or aggressive) and cosmetic) or (self.modes.bees and bees) or
		(self.modes.flowers and flowers) or (self.modes.balloons and balloons) or otherPlayer
	if object:IsA("BasePart") then
		if textures or self.modes.main then
			self:Remember(object,"CastShadow",false)
			self:Remember(object,"Reflectance",0)
			self:Remember(object,"Material",Enum.Material.SmoothPlastic)
		end
		if hide then self:Remember(object,"LocalTransparencyModifier",1) end
		if textures and cosmetic and not protected and object:IsA("MeshPart") then self:Remember(object,"TextureID","") end
	elseif object:IsA("Decal") or object:IsA("Texture") then
		-- Token icons, NPC/shop signs, hive and field identifiers must remain readable by scripts.
		if textures and cosmetic and not protected then self:Remember(object,"Texture","") end
		if hide and not protected then self:Remember(object,"Transparency",1) end
	elseif object:IsA("SpecialMesh") then
		if textures and cosmetic and not protected then self:Remember(object,"TextureId","") end
	elseif object:IsA("SurfaceAppearance") then
		if textures and cosmetic and not protected then
			for _, property in ipairs({"ColorMap","MetalnessMap","NormalMap","RoughnessMap"}) do self:Remember(object,property,"") end
		end
	elseif object:IsA("ParticleEmitter") or object:IsA("Trail") or object:IsA("Beam") then
		if effects or hide then
			self:Remember(object,"Enabled",false)
			if object:IsA("ParticleEmitter") or object:IsA("Trail") then pcall(function()object:Clear()end) end
		end
	elseif object:IsA("Light") or object:IsA("PostEffect") then
		if effects or self.modes.main then self:Remember(object,"Enabled",false) end
	elseif object:IsA("BillboardGui") or object:IsA("SurfaceGui") then
		if hide and cosmetic and not protected then self:Remember(object,"Enabled",false) end
	end
end

function visualOptimizer:Set(mode, enabled)
	enabled=enabled==true
	if (self.modes[mode]==true)==enabled then return end
	self.modes[mode]=enabled
	threads:Cancel("visualOptimizerScan")
	connections:Cancel("visualOptimizerWorkspace")
	connections:Cancel("visualOptimizerLighting")
	connections:Cancel("visualOptimizerWorkspaceRemoving")
	connections:Cancel("visualOptimizerLightingRemoving")
	self:Restore()
	local active=false
	for _, on in pairs(self.modes) do if on then active=true;break end end
	if not active then return end
	if self.modes.main or self.modes.aggressive then
		self:Remember(Lighting,"GlobalShadows",false)
		pcall(function()self:Remember(settings().Rendering,"QualityLevel",Enum.QualityLevel.Level01)end)
		self:Remember(workspace.Terrain,"WaterWaveSize",0)
		self:Remember(workspace.Terrain,"WaterWaveSpeed",0)
		self:Remember(workspace.Terrain,"WaterReflectance",0)
	end
	connections:Add("visualOptimizerWorkspace",workspace.DescendantAdded:Connect(function(object) self:Apply(object) end))
	connections:Add("visualOptimizerLighting",Lighting.DescendantAdded:Connect(function(object) self:Apply(object) end))
	connections:Add("visualOptimizerWorkspaceRemoving",workspace.DescendantRemoving:Connect(function(object) self:Release(object) end))
	connections:Add("visualOptimizerLightingRemoving",Lighting.DescendantRemoving:Connect(function(object) self:Release(object) end))
	threads:Add("visualOptimizerScan",function()
		for _, root in ipairs({workspace,Lighting}) do
			local objects=root:GetDescendants()
			for i = 1, #objects do
				local object = objects[i]
				if object:IsDescendantOf(root) then self:Apply(object) end
				objects[i] = nil -- Release processed references before yielding.
				if i%150==0 then task.wait() end
			end
		end
	end)
end

function visualOptimizer:Shutdown()
	threads:Cancel("visualOptimizerScan")
	connections:Cancel("visualOptimizerWorkspace")
	connections:Cancel("visualOptimizerLighting")
	connections:Cancel("visualOptimizerWorkspaceRemoving")
	connections:Cancel("visualOptimizerLightingRemoving")
	self:Restore()
	table.clear(self.modes)
end

local amulets=object("Folder","Amulets",workspace)
local part=object("MeshPart","Visual",amulets)
local decorative=object("Decal","Decal",part)
local collectibles=object("Folder","Collectibles",workspace)
local token=object("Part","Token",collectibles)
local icon=object("Decal","FrontDecal",token)
local particles=object("Folder","GlitchParticlesFolder",workspace)
local trail=object("Trail","GlitchTrail",particles)
local stations=object("Folder","Stations",workspace)
local mark=object("Part","Base",stations)
local markIcon=object("Decal","FrontDecal",mark)
visualOptimizer:Set("aggressive",true)
assert(amulets.Parent==workspace and trail.Parent==particles,"game containers modified")
assert(not trail.Enabled and trail.cleared,"trail not visually disabled")
assert(decorative.Texture=="" and part.TextureID=="" and part.LocalTransparencyModifier==1)
assert(icon.Texture=="icon" and markIcon.Texture=="icon","functional identifiers stripped")
assert(token.CanCollide and mark.CanCollide and part.CanCollide,"collision modified")
local fresh=object("ParticleEmitter","NewFX",workspace)
connections.list.visualOptimizerWorkspace.fn(fresh)
assert(not fresh.Enabled,"new effect missed")
local count=0;for _ in pairs(connections.list)do count+=1 end
assert(count==4 and next(threads.list)==nil,"extra listeners/tasks retained")
connections.list.visualOptimizerWorkspaceRemoving.fn(fresh)
fresh.Parent=nil
assert(fresh.Enabled and not visualOptimizer.originals[fresh],"removed effect retained")
visualOptimizer:Set("aggressive",false)
assert(trail.Enabled and decorative.Texture=="icon" and part.TextureID=="mesh")
assert(part.Material=="Grass" and part.LocalTransparencyModifier==0 and part.CanCollide)
assert(Lighting.GlobalShadows and renders.QualityLevel==5)
assert(next(connections.list)==nil and next(visualOptimizer.originals)==nil)
visualOptimizer:Set("aggressive",true)
local function countSaved()local n=0;for _ in pairs(visualOptimizer.originals)do n+=1 end;return n end
local baseline=countSaved()
for i=1,10000 do
 local transient=object("Trail","Transient",workspace)
 connections.list.visualOptimizerWorkspace.fn(transient)
 assert(countSaved()==baseline+1)
 connections.list.visualOptimizerWorkspaceRemoving.fn(transient)
 transient.Parent=nil
 table.remove(workspace.children)
 assert(countSaved()==baseline and transient.Enabled,"transient visual retained")
end
visualOptimizer:Shutdown()
assert(next(connections.list)==nil and next(visualOptimizer.originals)==nil)
print("PASS: folders/trails retained, functional textures and collision preserved, decorative stripping, new effects, four listeners, disable/unload restoration")
