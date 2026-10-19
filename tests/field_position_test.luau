local now=0
local os={clock=function()return now end}
local warns={}
local function warn(v)warns[#warns+1]=v end
local env={}
local function getgenv()return env end
local function vector(x,y,z)
 local mt={}
 mt.__add=function(a,b)return vector(a.X+b.X,a.Y+b.Y,a.Z and a.Z+b.Z or nil)end
 mt.__sub=function(a,b)return vector(a.X-b.X,a.Y-b.Y,a.Z and a.Z-b.Z or nil)end
 mt.__mul=function(a,b)if type(a)=="number"then a,b=b,a end;return vector(a.X*b,a.Y*b,a.Z and a.Z*b or nil)end
 mt.__div=function(a,b)return vector(a.X/b,a.Y/b,a.Z and a.Z/b or nil)end
 mt.__index=function(a,k)
  local z=rawget(a,"Z")
  local mag=math.sqrt(a.X*a.X+a.Y*a.Y+(z or 0)^2)
  if k=="Magnitude"or k=="magnitude"then return mag end
  if k=="Unit"then return mag>0 and a/mag or vector(0,0,z and 0 or nil)end
 end
 return setmetatable({X=x,Y=y,Z=z},mt)
end
local Vector2={new=function(x,y)return vector(x,y)end}
local Vector3={new=vector,zero=vector(0,0,0)}
local Color3={new=function(r,g,b)return {R=r,G=g,B=b}end,fromRGB=function(r,g,b)return {R=r/255,G=g/255,B=b/255}end}
local UDim={new=function(s,o)return {Scale=s,Offset=o}end}
local UDim2={new=function(xs,xo,ys,yo)return {X=UDim.new(xs,xo),Y=UDim.new(ys,yo)}end}
function UDim2.fromOffset(x,y)return UDim2.new(0,x,0,y)end
function UDim2.fromScale(x,y)return UDim2.new(x,0,y,0)end
local Enum=setmetatable({RenderPriority={Character={Value=100}}},{__index=function(t,k)
 local e=setmetatable({},{__index=function(t,n)rawset(t,n,n);return n end});rawset(t,k,e);return e
end})
local liveConnections=0
local function signal()
 local listeners={}
 local s={}
 function s:Connect(fn)
  local c={Connected=true,fn=fn};listeners[c]=true;liveConnections+=1
  function c:Disconnect()if self.Connected then self.Connected=false;listeners[self]=nil;liveConnections-=1 end end
  return c
 end
 function s:Fire(...)
  local snapshot={};for c in pairs(listeners)do snapshot[#snapshot+1]=c end
  for _,c in ipairs(snapshot)do if c.Connected then c.fn(...)end end
 end
 function s:Wait()coroutine.yield()end
 function s:Clear()local snapshot={};for c in pairs(listeners)do snapshot[#snapshot+1]=c end;for _,c in ipairs(snapshot)do c:Disconnect()end end
 return s
end
local function ancestors(o,property,subject)
 while o do o[property]:Fire(subject);o=o.Parent end
end
local methods={}
local Instance={}
function Instance.new(class,parent)
 local data={ClassName=class,Name=class,children={},signals={},attributes={},Visible=true,Enabled=true,Image="",ImageTransparency=0,
  Health=100,WalkSpeed=40,controlsEnabled=true,Position=Vector3.zero,Size=vector(1,1,1),Color=Color3.new(1,1,1),Material="Plastic",
  AssemblyLinearVelocity=Vector3.zero,AssemblyAngularVelocity=Vector3.zero,CameraType="Custom"}
 for _,name in ipairs({"DescendantAdded","DescendantRemoving","Destroying","Activated","InputBegan","InputChanged","InputEnded","ChildAdded","ChildRemoved"})do data[name]=signal()end
 local object=setmetatable({}, {
  __index=function(_,key)
   if methods[key]then return methods[key]end
   if data[key]~=nil then return data[key]end
   for _,c in ipairs(data.children)do if c.Name==key then return c end end
  end,
  __newindex=function(self,key,value)
   if key=="Parent"then
    local old=data.Parent;if old==value then return end
    if old then
     ancestors(old,"DescendantRemoving",self)
     for _,d in ipairs(self:GetDescendants())do ancestors(old,"DescendantRemoving",d)end
     for i,c in ipairs(old.children)do if c==self then table.remove(old.children,i);break end end
     old.ChildRemoved:Fire(self)
    end
    data.Parent=value
    if value then
     value.children[#value.children+1]=self;value.ChildAdded:Fire(self)
     ancestors(value,"DescendantAdded",self)
     for _,d in ipairs(self:GetDescendants())do ancestors(value,"DescendantAdded",d)end
    end
   else data[key]=value;if data.signals[key]then data.signals[key]:Fire()end end
  end,
 })
 if parent then object.Parent=parent end
 return object
end
function methods:IsA(class)return self.ClassName==class or class=="BasePart" and (self.ClassName=="Part" or self.ClassName=="MeshPart")end
function methods:GetChildren()return table.clone(self.children)end
function methods:GetDescendants()local result={};local function walk(n)for _,c in ipairs(n.children)do result[#result+1]=c;walk(c)end end;walk(self);return result end
function methods:FindFirstChild(name)for _,c in ipairs(self.children)do if c.Name==name then return c end end end
function methods:FindFirstChildOfClass(class)for _,c in ipairs(self.children)do if c:IsA(class)then return c end end end
function methods:FindFirstAncestorWhichIsA(class)local p=self.Parent;while p do if p:IsA(class)then return p end;p=p.Parent end end
function methods:IsDescendantOf(ancestor)local p=self.Parent;while p do if p==ancestor then return true end;p=p.Parent end;return false end
function methods:WaitForChild(name)return assert(self:FindFirstChild(name),name)end
function methods:GetPropertyChangedSignal(name)if not self.signals[name]then self.signals[name]=signal()end;return self.signals[name]end
function methods:SetAttribute(name,value)self.attributes[name]=value end
function methods:GetAttribute(name)return self.attributes[name]end
function methods:Move(direction)self.direction=direction end
function methods:MoveTo(position)self.direction=Vector3.zero end
function methods:Destroy()
 if self.destroyed then return end
 self.Destroying:Fire();self.Parent=nil
 for _,child in ipairs(self:GetChildren())do child:Destroy()end
 for _,s in pairs(self.signals)do s:Clear()end
 for _,name in ipairs({"DescendantAdded","DescendantRemoving","Destroying","Activated","InputBegan","InputChanged","InputEnded","ChildAdded","ChildRemoved"})do self[name]:Clear()end
 self.destroyed=true
end
local deferred={}
local task={}
function task.defer(fn)deferred[#deferred+1]=fn end
function task.spawn(thread)local ok,e=coroutine.resume(thread);assert(ok,e)end
function task.cancel(thread)coroutine.close(thread)end
function task.delay(_,thread)task.spawn(thread)end
function task.wait()coroutine.yield()end
local RunService={Heartbeat=signal(),bound={}}
function RunService:BindToRenderStep(name,_,fn)self.bound[name]=fn end
function RunService:UnbindFromRenderStep(name)self.bound[name]=nil end
local world=Instance.new("Folder");world.Name="Workspace"
local workspace=world
workspace.CurrentCamera=Instance.new("Camera")
local particles=Instance.new("Folder",world);particles.Name="Particles"
local player={Name="Tester",UserId=123,PlayerGui=Instance.new("PlayerGui"),PlayerScripts=Instance.new("Folder")}
function player:WaitForChild(name)return assert(self[name],name)end
local character=Instance.new("Model",world);player.Character=character
local h=Instance.new("Humanoid",character)
local root=Instance.new("Part",character);root.Name="HumanoidRootPart";root.Position=vector(0,3,0)
local head=Instance.new("Part",character);head.Name="Head"
local controlModule=Instance.new("ModuleScript",player.PlayerScripts);controlModule.Name="PlayerModule"
local controls={controlsEnabled=true,Disable=function(self)self.controlsEnabled=false end,Enable=function(self)self.controlsEnabled=true end}
local function require()return {GetControls=function()return controls end}end
local Players={LocalPlayer=player,list={player}}
function Players:GetPlayers()return self.list end
local Input={InputBegan=signal(),InputChanged=signal(),InputEnded=signal()}
local actionService={bound={}}
function actionService:BindActionAtPriority(name,fn)self.bound[name]=fn end
function actionService:UnbindAction(name)self.bound[name]=nil end
local services={Players=Players,RunService=RunService,UserInputService=Input,ContextActionService=actionService,
 Stats={Network={ServerStatsItem={["Data Ping"]={GetValue=function()return 25 end}}}}}
local game={GetService=function(_,name)return assert(services[name],name)end}
local function getService(name)return game:GetService(name)end
local function getRootPart()return root end
local state={}
local cfg={autofarm={enabled=true,farmshowers=true},detected={background=false}}
local smoothMovement={Reset=function(self)if self.showerController then self.showerController:CancelMovement()end end}
local function stopMovement()smoothMovement:Reset()end
local threads={list={},closed=false}
local connections={list={},closed=false}
local function worker()coroutine.yield()end
local function step(dt)
 now+=dt
 local batch=deferred;deferred={};for _,fn in ipairs(batch)do fn()end
 RunService.Heartbeat:Fire(dt)
 for _,fn in pairs(RunService.bound)do fn()end
 if h.direction and h.Health>0 then root.Position=root.Position+h.direction*(h.WalkSpeed*dt)end
end
local function makePart(name,position)
 local o=Instance.new("Part");o.Name=name;o.Position=position
 if name=="WarningDisk"then o.Size=vector(8,0.4,8);o.Material=Enum.Material.Neon;o.Color=Color3.fromRGB(50,255,50);Instance.new("CylinderMesh",o)end
 o.Parent=particles;return o
end

local CFrame={new=function(x,y,z)return {X=x,Y=y,Z=z}end}
local makeVector=vector
local currentField,vector
local function typeof(value)
 if type(value)=="table" and value.ClassName then return "Instance"end
 if type(value)=="table" and value.X and value.Y and value.Z then return "Vector3"end
 return type(value)
end
function connections:Get(key)return self.list[key]end
function connections:Cancel(key)local c=self.list[key];if c then c:Disconnect();self.list[key]=nil end end
function connections:Add(key,c)self:Cancel(key);self.list[key]=c end
local zones=Instance.new("Folder",workspace);zones.Name="FlowerZones"
local field=Instance.new("Part",zones);field.Name="Pepper Patch";field.Position=makeVector(100,20,200);field.Size=makeVector(100,2,80)
cfg.autofarm.field1="Pepper Patch";cfg.autofarm.farmposition="Upper Left";cfg.autofarm.enabled=false;cfg.autofarm.showfieldarea=false
local fieldPositionPolicy={}
function fieldPositionPolicy:IsQuadrant(name)
	return name=="Upper Left" or name=="Upper Right" or name=="Lower Left" or name=="Lower Right"
end
function fieldPositionPolicy:UsableSize(field)
			local fieldName=field.Name
			local x = field.Size.X
			local z = field.Size.Z

			if fieldName == "Bamboo Field" then
				x -= 6
				z -= 8
			elseif fieldName == "Clover Field" then
				x -= 5
				z -= 5
			elseif fieldName == "Coconut Field" then
				x -= 5
				z -= 5
			elseif fieldName == "Dandelion Field" then
				x -= 5
				z -= 5
			elseif fieldName == "Mountain Top Field" then
				x -= 5
				z -= 5
			elseif fieldName == "Mushroom Field" then
				x -= 5
				z -= 5
			elseif fieldName == "Pine Tree Forest" then
				x -= 5
				z -= 5
			elseif fieldName == "Pineapple Patch" then
				x -= 5
				z -= 5
			elseif fieldName == "Pumpkin Patch" then
				x -= 5
				z -= 5
			elseif fieldName == "Rose Field" then
				x -= 5
				z -= 5
			elseif fieldName == "Spider Field" then
				x -= 5
				z -= 5
			elseif fieldName == "Strawberry Field" then
				x -= 5
				z -= 5
			elseif fieldName ~= "Stump Field" then
				if fieldName == "Sunflower Field" then
					x -= 5
					z -= 5
				end
			else
				x -= 20
				z -= 20
			end

	return Vector3.new(x-5,0,z-5)
end
function fieldPositionPolicy:Region(name,center,size,y)
	local x,z=size.X,size.Z
	local longX=x>z
	if not self:IsQuadrant(name) then
		local side=name=="Left" and -1 or name=="Right" and 1 or 0
		return Vector3.new(center.X+(longX and side*x/2 or 0),y,center.Z+(not longX and side*z/2 or 0))
	end
	local side=string.find(name,"Left",1,true) and -1 or 1
	local depth=string.find(name,"Upper",1,true) and -1 or 1
	local sx,sz=longX and side or depth,longX and depth or side
	local minX,maxX=center.X+(sx<0 and -x/2 or 0),center.X+(sx<0 and 0 or x/2)
	local minZ,maxZ=center.Z+(sz<0 and -z/2 or 0),center.Z+(sz<0 and 0 or z/2)
	local area={minX=minX,maxX=maxX,minZ=minZ,maxZ=maxZ}
	return Vector3.new((minX+maxX)/2,y,(minZ+maxZ)/2),area
end
function fieldPositionPolicy:Allowed(goal,opts)
	local area=opts and opts.area
	return not area or (goal.X>=area.minX and goal.X<=area.maxX and goal.Z>=area.minZ and goal.Z<=area.maxZ)
end
function fieldPositionPolicy:TargetPosition(object)
	if typeof(object)=="Vector3" then return object end
	if type(object)=="table" and typeof(object.Position)=="Vector3" then return object.Position end
	if typeof(object)=="Instance" then
		if object:IsA("BasePart") then return object.Position end
		local part=object:FindFirstChild("Plane") or object:FindFirstChild("Stem") or object:FindFirstChild("BalloonRoot")
		if part and part:IsA("BasePart") then return part.Position end
	end
end
function fieldPositionPolicy:TrackedAllowed(key,value,opts)
	if not opts.area then return true end
	local goal=self:TargetPosition(key) or self:TargetPosition(value)
	return not goal or self:Allowed(goal,opts)
end
function fieldPositionPolicy:StopPreview()
	connections:Cancel("fieldAreaPreview")
	if self.preview then self.preview:Destroy();self.preview=nil end
	self.parts=nil
end
function fieldPositionPolicy:DrawPreview()
	if not cfg.autofarm.showfieldarea then self:StopPreview();return end
	local zones=workspace:FindFirstChild("FlowerZones")
	local selected=zones and zones:FindFirstChild(cfg.autofarm.field1)
	local field=(cfg.autofarm.enabled and currentField) or selected or currentField
	if not field or not self:IsQuadrant(cfg.autofarm.farmposition) then
		if self.preview then self.preview:Destroy();self.preview=nil;self.parts=nil end
		return
	end
	local center=field.Position
	local size=self:UsableSize(field)
	if not size then return end
	local y=field.Position.Y+field.Size.Y/2+0.15
	local _,area=self:Region(cfg.autofarm.farmposition,center,size,y)
	if not self.preview or not self.preview.Parent then
		self.preview=Instance.new("Folder");self.preview.Name="AtlasFieldAreaPreview";self.preview.Parent=workspace;self.parts={}
	end
	local function part(index,x,z,width,depth,color,transparency)
		local object=self.parts[index]
		if not object or not object.Parent then
			object=Instance.new("Part");object.Name="AtlasArea"..index;object.Anchored=true
			object.CanCollide=false;object.CanTouch=false;object.CanQuery=false;object.CastShadow=false
			object.Parent=self.preview;self.parts[index]=object
		end
		object.Size=Vector3.new(math.max(.1,width),.12,math.max(.1,depth))
		object.CFrame=CFrame.new(x,y+((index>=2 and index<=5) and .03 or 0),z);object.Color=color;object.Material=Enum.Material.Neon;object.Transparency=transparency
		return object
	end
	local selected=Color3.fromRGB(65,230,130)
	local grid=Color3.fromRGB(245,245,245)
	local width,depth=area.maxX-area.minX,area.maxZ-area.minZ
	part(1,(area.minX+area.maxX)/2,(area.minZ+area.maxZ)/2,width,depth,selected,.82)
	part(2,area.minX,(area.minZ+area.maxZ)/2,.4,depth,selected,.05)
	part(3,area.maxX,(area.minZ+area.maxZ)/2,.4,depth,selected,.05)
	part(4,(area.minX+area.maxX)/2,area.minZ,width,.4,selected,.05)
	part(5,(area.minX+area.maxX)/2,area.maxZ,width,.4,selected,.05)
	part(6,center.X,center.Z,size.X,.18,grid,.2)
	part(7,center.X,center.Z,.18,size.Z,grid,.2)
	part(8,center.X-size.X/2,center.Z,.18,size.Z,grid,.2)
	part(9,center.X+size.X/2,center.Z,.18,size.Z,grid,.2)
	part(10,center.X,center.Z-size.Z/2,size.X,.18,grid,.2)
	part(11,center.X,center.Z+size.Z/2,size.X,.18,grid,.2)
	for index,name in ipairs({"Upper Left","Upper Right","Lower Left","Lower Right"})do
		local anchorPoint=self:Region(name,center,size,y)
		local anchor=part(11+index,anchorPoint.X,anchorPoint.Z,.1,.1,grid,1)
		local label=anchor:FindFirstChild("QuadrantLabel")
		if not label then
			label=Instance.new("BillboardGui");label.Name="QuadrantLabel";label.Size=UDim2.fromOffset(160,28)
			label.StudsOffset=Vector3.new(0,4,0);label.AlwaysOnTop=true;label.MaxDistance=250;label.Parent=anchor
			local text=Instance.new("TextLabel");text.Name="Name";text.Size=UDim2.fromScale(1,1);text.BackgroundTransparency=1
			text.TextScaled=true;text.Font=Enum.Font.GothamSemibold;text.TextStrokeTransparency=.25;text.Parent=label
		end
		label.Enabled=true
		local text=label:FindFirstChild("Name");text.Text=name;text.TextColor3=name==cfg.autofarm.farmposition and selected or grid
	end
end
function fieldPositionPolicy:PreviewChanged()
	self:DrawPreview()
	if not cfg.autofarm.showfieldarea then return end
	if connections:Get("fieldAreaPreview") then return end
	local elapsed=0
	connections:Add("fieldAreaPreview",RunService.Heartbeat:Connect(function(dt)
		elapsed+=dt;if elapsed<.2 then return end;elapsed=0;self:DrawPreview()
	end))
end

local function getRootPart()return root end
local function isPathClear(_,avoid)return avoid.blocked end
local randomFieldPosition=function()return makeVector(999,3,999)end
	local randomWholeFieldPosition=randomFieldPosition
	randomFieldPosition=function(options,...)
		if not options.area then return randomWholeFieldPosition(options,...) end
		local area=options.area
		for _=1,40 do
			local goal=Vector3.new(area.minX+math.random()*(area.maxX-area.minX),getRootPart().Position.Y,area.minZ+math.random()*(area.maxZ-area.minZ))
			if (not options.range or not options.origin or (goal-options.origin).Magnitude<options.range)
				and (not options.avoid or not isPathClear(goal,options.avoid,true,options.rbc)) then return goal end
		end
	end

local gatheringPriorities={}
local function getFieldAt()return currentField end
function gatheringPriorities:Allowed(position, opts, rootPosition)
	if opts.area and not fieldPositionPolicy:Allowed(position,opts) then return false end
	if opts.checkheight and math.abs(position.Y - rootPosition.Y) >= 6 then return false end
	if opts.range and opts.origin then
		local offset = position - opts.origin
		if offset:Dot(offset) >= opts.range * opts.range then return false end
	end
	local field = getFieldAt(position)
	if (not opts.ignorefield or field) and not (not opts.ignorefield and field == currentField) then return false end
	return not opts.avoid or not isPathClear(position, opts.avoid)
end

local position=field.Position
		local function buildAvoidGrid(v128,area)
			local nodePositions = {}
			local nodeEdges = {}
			local nextNodeId = 1

			local function addNode(point)
				local nodeId = nextNodeId
				nextNodeId += 1
				local z = point.Z
				nodePositions[nodeId] = Vector3.new(math.floor(point.X), math.floor(point.Y), math.floor(z))
				nodeEdges[nodeId] = {}
				return nodeId
			end

			local function removeNode(nodeToRemove)
				nodePositions[nodeToRemove] = nil

				for k in pairs(nodeEdges[nodeToRemove]) do
					nodeEdges[nodeToRemove][k] = nil
					nodeEdges[k][nodeToRemove] = nil
				end

				nodeEdges[nodeToRemove] = nil
			end

			local function addLink(fromId, toId, bidirectional)
				nodeEdges[fromId][toId] = { bidirectional = bidirectional, label = "" }

				if bidirectional then
					nodeEdges[toId][fromId] = { bidirectional = true, label = "" }
				end
			end

			local edgeNodes = {}
			local edgeSet = {}
			local minX

			if vector.X > 3 then
				minX = position.X - vector.X / 2 + 1.5
			else
				minX = position.X - vector.X / 2
			end

			local maxX

			if vector.X > 3 then
				maxX = position.X + vector.X / 2 - 1.5
			else
				maxX = position.X + vector.X / 2
			end

			local minZ

			if vector.Z > 3 then
				minZ = position.Z - vector.Z / 2 + 1.5
			else
				minZ = position.Z - vector.Z / 2
			end

			local maxZ

			if vector.Z > 3 then
				maxZ = position.Z + vector.Z / 2 - 1.5
			else
				maxZ = position.Z + vector.Z / 2
			end

			local gridY = position.Y - vector.Y / 2 + 1
			local gridColumns = {}
			local countX = math.floor((maxX - minX) / 3)
			local countZ = math.floor((maxZ - minZ) / 3)
			local startX = position.X - countX * 3 / 2
			local startZ = position.Z - countZ * 3 / 2

			for i = 0, countX do
				local cellX = startX + 3 * i
				local column = {}

				for i2 = 0, countZ do
					local newNodeId = addNode(Vector3.new(cellX, gridY, startZ + 3 * i2))

					if i == 0 or not (i ~= countX and not (i2 == 0 or i2 == countZ)) then
						edgeSet[newNodeId] = 1
						table.insert(edgeNodes, newNodeId)
					end

					table.insert(column, newNodeId)
				end

				table.insert(gridColumns, column)
			end

			for k, gridColumn in pairs(gridColumns) do
				for k2, cellNode in pairs(gridColumn) do
					local nextColumnNode

					if not gridColumns[k + 1] then
						nextColumnNode = nil
					else
						nextColumnNode = gridColumns[k + 1][k2]
					end

					local nextRowNode = gridColumns[k][k2 + 1]
					local nextDiagNode

					if not gridColumns[k + 1] then
						nextDiagNode = nil
					else
						nextDiagNode = gridColumns[k + 1][k2 + 1]
					end

					local prevDiagNode

					if not gridColumns[k - 1] then
						prevDiagNode = nil
					else
						prevDiagNode = gridColumns[k - 1][k2 + 1]
					end

					if nextColumnNode then
						addLink(cellNode, nextColumnNode, true)
					end

					if nextRowNode then
						addLink(cellNode, nextRowNode, true)
					end

					if nextDiagNode then
						addLink(cellNode, nextDiagNode, true)
					end

					if prevDiagNode then
						addLink(cellNode, prevDiagNode, true)
					end
				end
			end

			for _, gridColumn in pairs(gridColumns) do
				for _, cellNode in pairs(gridColumn) do
					local hasLinks = false
					local v150, v151, v152 = pairs(nodeEdges[cellNode])
					local v153 = table.pack(v150(v151, v152))

					if v153[1] then
						hasLinks = true
					end

					if not hasLinks then
						removeNode(cellNode)
						local edgeIndex = table.find(edgeNodes, cellNode)

						if edgeIndex then
							edgeSet[cellNode] = nil
							table.remove(edgeNodes, edgeIndex)
						end
					end
				end
			end

			for _, edgeId in ipairs(edgeNodes) do
				local edgePosition = nodePositions[edgeId]

				for _, otherEdgeId in ipairs(edgeNodes) do
					if otherEdgeId ~= edgeId and not nodeEdges[edgeId][otherEdgeId] and (nodePositions[otherEdgeId] - edgePosition).magnitude < 6 then
						addLink(edgeId, otherEdgeId, true)
					end
				end
			end

			for k, nodePosition in pairs(nodePositions) do
				for k2, avoidRadius in pairs(v128) do
					if (type(k2) == "vector" and k2 or k2.Name ~= true and k2:FindFirstChild("Plane") and k2.Plane.Position or k2.Position - nodePosition).magnitude < avoidRadius then
						removeNode(k)
						break
					end
				end
			end

			if area then
				local outside={}
				for id,point in pairs(nodePositions)do if not fieldPositionPolicy:Allowed(point,{area=area}) then outside[#outside+1]=id end end
				for _,id in ipairs(outside)do removeNode(id) end
			end
			return nodePositions, nodeEdges
		end

local size=fieldPositionPolicy:UsableSize(field)
assert(size.X==95 and size.Z==75,"preview uses different field insets")
local names={"Upper Left","Upper Right","Lower Left","Lower Right"}
local areas={}
for _,name in ipairs(names)do
 local origin,area=fieldPositionPolicy:Region(name,field.Position,size,23)
 assert(origin.Y==23 and fieldPositionPolicy:Allowed(origin,{area=area}))
 assert((area.maxX-area.minX)*(area.maxZ-area.minZ)==size.X*size.Z/4,"not an exact quarter")
 areas[#areas+1]=area
end
for x=53,147,3 do for z=163,237,3 do
 local total=0
 for _,area in ipairs(areas)do if fieldPositionPolicy:Allowed(makeVector(x,23,z),{area=area})then total+=1 end end
 assert(total>=1,"quadrants left an unassigned field area")
end end
local left=fieldPositionPolicy:Region("Left",field.Position,size,23)
assert(left.X==52.5 and left.Z==200,"legacy Left changed")
local longZ=makeVector(60,0,100)
left=fieldPositionPolicy:Region("Left",field.Position,longZ,23)
assert(left.X==100 and left.Z==150,"legacy Z-axis Left changed")
local origin,area=fieldPositionPolicy:Region("Upper Right",field.Position,longZ,23)
assert(origin.X<100 and origin.Z>200,"Z-axis quadrant orientation inconsistent")
local inside={Position=origin};local outside={Position=makeVector(120,23,180)}
assert(fieldPositionPolicy:TrackedAllowed(inside,true,{area=area}) and not fieldPositionPolicy:TrackedAllowed(outside,true,{area=area}))
assert(fieldPositionPolicy:TrackedAllowed(outside,true,{}),"legacy selection restricted without quadrant")
currentField=field
assert(gatheringPriorities:Allowed(inside.Position,{area=area},root.Position),"normal priority selector rejected allowed area")
assert(not gatheringPriorities:Allowed(outside.Position,{area=area},root.Position),"normal priority selector escaped area")
assert(gatheringPriorities:Allowed(outside.Position,{},root.Position),"normal priority behavior changed without quadrant")
currentField=nil
for _=1,1000 do
 local goal=randomFieldPosition({area=area})
 assert(goal and fieldPositionPolicy:Allowed(goal,{area=area}),"roaming sampled outside selected quadrant")
end
assert(not randomFieldPosition({area=area,avoid={blocked=true}}),"blocked area fell back to roaming outside quadrant")
assert(randomFieldPosition({}).X==999,"legacy sampler changed")
position=field.Position;vector=size
local nodes,links=buildAvoidGrid({},area)
local count=0
for id,goal in pairs(nodes)do
 count+=1;assert(fieldPositionPolicy:Allowed(goal,{area=area}),"precise avoidance route escaped quadrant")
 for neighbor in pairs(links[id])do assert(nodes[neighbor],"clipped grid retained dangling link")end
end
assert(count>0,"quadrant clipped all navigation nodes")
local before=liveConnections
cfg.autofarm.showfieldarea=true
fieldPositionPolicy:PreviewChanged()
assert(fieldPositionPolicy.preview and #fieldPositionPolicy.preview:GetChildren()==15,"preview geometry missing")
assert(liveConnections==before+1,"preview added excess listeners")
local folder=fieldPositionPolicy.preview
for i=1,100 do fieldPositionPolicy:PreviewChanged()end
assert(fieldPositionPolicy.preview==folder and #folder:GetChildren()==15 and liveConnections==before+1,"preview leaked parts/listeners")
local _,expected=fieldPositionPolicy:Region("Upper Left",field.Position,size,21.15)
local fill=fieldPositionPolicy.parts[1]
assert(fill.Size.X==expected.maxX-expected.minX and fill.Size.Z==expected.maxZ-expected.minZ,"visual area differs from allowed area")
assert(fill.CFrame.X==(expected.minX+expected.maxX)/2 and fill.CFrame.Z==(expected.minZ+expected.maxZ)/2)
for _,part in ipairs(folder:GetChildren())do assert(part.Anchored and not part.CanCollide and not part.CanTouch and not part.CanQuery,"preview affects physics/queries")end
cfg.autofarm.farmposition="Lower Right";fieldPositionPolicy:DrawPreview()
local _,nextArea=fieldPositionPolicy:Region("Lower Right",field.Position,size,21.15)
assert(fill.CFrame.X==(nextArea.minX+nextArea.maxX)/2,"selection did not update visual")
local bamboo=Instance.new("Part",zones);bamboo.Name="Bamboo Field";bamboo.Position=makeVector(500,20,600);bamboo.Size=makeVector(100,2,80)
currentField=field;cfg.autofarm.field1="Bamboo Field";cfg.autofarm.enabled=false
fieldPositionPolicy:DrawPreview()
local bambooSize=fieldPositionPolicy:UsableSize(bamboo)
assert(bambooSize.X==89 and bambooSize.Z==67 and fill.Size.X==44.5,"stopped preview used stale field or wrong inset")
cfg.autofarm.enabled=true;fieldPositionPolicy:DrawPreview()
assert(fill.Size.X==47.5,"active preview did not follow actual farming field")
cfg.autofarm.showfieldarea=false;fieldPositionPolicy:PreviewChanged()
assert(not folder.Parent and not fieldPositionPolicy.preview and liveConnections==before,"disable leaked preview")
for _=1,25 do
 cfg.autofarm.showfieldarea=true;fieldPositionPolicy:PreviewChanged()
 cfg.autofarm.showfieldarea=false;fieldPositionPolicy:PreviewChanged()
 assert(not fieldPositionPolicy.preview and liveConnections==before,"repeated enable/disable leaked preview")
end
print("PASS: four quadrants, legacy orientation, exact inset geometry, target bounds, visual match, 100 toggles/updates, physics isolation and cleanup")
