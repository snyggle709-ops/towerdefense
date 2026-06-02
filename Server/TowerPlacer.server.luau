local Players = game:GetService("Players")

local ResourceService = require(script.Parent:WaitForChild("ResourceService"))
local BalanceLogger = require(script.Parent:WaitForChild("BalanceLogger"))
local RunStats = require(script.Parent:WaitForChild("RunStats"))
local AntiCheatService = require(script.Parent:WaitForChild("AntiCheatService"))
local TutorialService = require(script.Parent:WaitForChild("TutorialService"))
local DevSettings = require(game.ReplicatedStorage:WaitForChild("DevSettings"))
local TowerData = require(game.ReplicatedStorage:WaitForChild("TowerData"))
local TowerPlaceRemote = game.ReplicatedStorage:WaitForChild("TowerPlaceRemote")
local towersFolder = game.ReplicatedStorage:WaitForChild("Towers")
local placedTowersFolder = workspace:FindFirstChild("PlacedTowers")

if not placedTowersFolder then
	placedTowersFolder = Instance.new("Folder")
	placedTowersFolder.Name = "PlacedTowers"
	placedTowersFolder.Parent = workspace
end

local MAX_ABS_COORDINATE = 100000

local towerCostsByName = {}
for _, towerInfo in ipairs(TowerData) do
	towerCostsByName[towerInfo.name] = {
		stone = towerInfo.stone or 0,
		crystal = towerInfo.crystal or 0,
		metal = towerInfo.metal or 0,
	}
end

local placementBlockersFolder = workspace:FindFirstChild("PlacementBlockers")
local lastPlaceRequestAt = {}
local PLACE_REQUEST_COOLDOWN = 0.08

local function isZoomLimitObject(obj)
	if not obj then
		return false
	end

	local current = obj
	while current and current ~= workspace do
		if string.lower(current.Name) == "zoomlimit" then
			return true
		end
		current = current.Parent
	end

	return false
end

local function isPlacementIgnoredEffectPart(obj)
	if not obj or not obj:IsA("BasePart") then
		return false
	end

	if isZoomLimitObject(obj) then
		return true
	end

	if obj:FindFirstChildOfClass("ParticleEmitter") then
		return true
	end

	if obj.Transparency >= 0.95 and math.max(obj.Size.X, obj.Size.Y, obj.Size.Z) >= 128 then
		return true
	end

	return false
end

local placementIgnoredEffectParts = {}
local placementIgnoredEffectList = {}
local placementFootprintCache = setmetatable({}, { __mode = "k" })

local function addIgnoredEffectPart(part)
	if placementIgnoredEffectParts[part] then
		return
	end

	placementIgnoredEffectParts[part] = true
	table.insert(placementIgnoredEffectList, part)
	part.CanQuery = false
	part.CanCollide = false
end

local function removeIgnoredEffectPart(part)
	if not placementIgnoredEffectParts[part] then
		return
	end

	placementIgnoredEffectParts[part] = nil
	for i = #placementIgnoredEffectList, 1, -1 do
		if placementIgnoredEffectList[i] == part then
			table.remove(placementIgnoredEffectList, i)
			break
		end
	end
end

local function trackPlacementObject(obj)
	if obj:IsA("BasePart") then
		if isPlacementIgnoredEffectPart(obj) then
			addIgnoredEffectPart(obj)
		end
	elseif obj:IsA("ParticleEmitter") and obj.Parent and obj.Parent:IsA("BasePart") then
		if isPlacementIgnoredEffectPart(obj.Parent) then
			addIgnoredEffectPart(obj.Parent)
		end
	end
end

for _, obj in ipairs(workspace:GetDescendants()) do
	trackPlacementObject(obj)
end

workspace.DescendantAdded:Connect(trackPlacementObject)
workspace.DescendantRemoving:Connect(function(obj)
	if obj:IsA("BasePart") then
		removeIgnoredEffectPart(obj)
	end
end)

local function forceZoomLimitNonQueryable()
	for _, obj in ipairs(placementIgnoredEffectList) do
		if obj.Parent then
			obj.CanQuery = false
			obj.CanCollide = false
		end
	end
end

local function isFiniteNumber(value)
	return typeof(value) == "number"
		and value == value
		and value > -math.huge
		and value < math.huge
		and math.abs(value) <= MAX_ABS_COORDINATE
end

local function isValidPosition(position)
	return typeof(position) == "Vector3"
		and isFiniteNumber(position.X)
		and isFiniteNumber(position.Y)
		and isFiniteNumber(position.Z)
end

local function getPlacementSize(instance)
	if instance:IsA("BasePart") then
		return instance.Size
	end

	local _, size = instance:GetBoundingBox()
	return size
end

local function getPlacementBounds(template, placementCFrame, yRotation)
	if template:IsA("BasePart") then
		return placementCFrame, getPlacementSize(template) * 0.9
	end

	if not template:IsA("Model") then
		return placementCFrame, getPlacementSize(template) * 0.9
	end

	local yawKey = math.floor((yRotation % 360) * 100 + 0.5) / 100
	local templateCache = placementFootprintCache[template]
	if not templateCache then
		templateCache = {}
		placementFootprintCache[template] = templateCache
	end

	local cached = templateCache[yawKey]
	if not cached then
		local rotation = CFrame.Angles(0, math.rad(yawKey), 0)
		local validationClone = template:Clone()
		validationClone:PivotTo(rotation)
		local boundsCFrame, boundsSize = validationClone:GetBoundingBox()
		validationClone:Destroy()

		cached = {
			offset = rotation:ToObjectSpace(boundsCFrame),
			size = boundsSize * 0.9,
		}
		templateCache[yawKey] = cached
	end

	return placementCFrame * cached.offset, cached.size
end

local function isBlockingPart(part)
	if not part or not part.Parent then
		return false
	end

	if isZoomLimitObject(part) then
		return false
	end

	if isPlacementIgnoredEffectPart(part) then
		return false
	end

	if part.CanQuery == false then
		return false
	end

	if placementBlockersFolder and part:IsDescendantOf(placementBlockersFolder) then
		return true
	end

	local ancestorModel = part:FindFirstAncestorOfClass("Model")
	if ancestorModel and ancestorModel:FindFirstChildOfClass("Humanoid") then
		return false
	end

	if part.Name:match("Rock") or part.Name:match("Crystal") or part.Name:match("Metal") then
		return false
	end

	if part.Name:match("Spawn") or part.Name:match("Waypoint") then
		return false
	end

	return true
end

local function canPlaceTower(player, template, position, yRotation)
	if not isValidPosition(position) or not isFiniteNumber(yRotation) then
		return false
	end

	forceZoomLimitNonQueryable()

	local playerCharacter = player.Character
	local rotation = CFrame.Angles(0, math.rad(yRotation % 360), 0)
	local placementCFrame = CFrame.new(position) * rotation
	local overlapCFrame, overlapSize = getPlacementBounds(template, placementCFrame, yRotation)

	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Exclude
	local filterList = {workspace.Terrain}
	if playerCharacter then
		table.insert(filterList, playerCharacter)
	end
	for _, obj in ipairs(placementIgnoredEffectList) do
		if obj.Parent then
			table.insert(filterList, obj)
		end
	end
	overlapParams.FilterDescendantsInstances = filterList

	for _, part in ipairs(workspace:GetPartBoundsInBox(overlapCFrame, overlapSize, overlapParams)) do
		local objectiveName = player:GetAttribute("TutorialPlacementObjective")
		if player:GetAttribute("TutorialPlacementActive") == true and objectiveName and part.Name == objectiveName then
			continue
		end

		if isBlockingPart(part) then
			return false
		end
	end

	return true
end

local function isInsideTutorialObjective(player, towerName, position)
	if player:GetAttribute("TutorialPlacementActive") ~= true then
		return true
	end

	if towerName ~= (player:GetAttribute("TutorialRequiredTower") or "Cannon") then
		return false
	end

	local objectiveName = player:GetAttribute("TutorialPlacementObjective") or "Objective1"
	local objective = workspace:FindFirstChild(objectiveName)
	if not objective or not objective:IsA("BasePart") then
		return false
	end

	local localPosition = objective.CFrame:PointToObjectSpace(position)
	local padding = 8
	return math.abs(localPosition.X) <= objective.Size.X * 0.5 + padding
		and math.abs(localPosition.Z) <= objective.Size.Z * 0.5 + padding
end

local function getOrCreateValue(parent, className, name, value)
	local existing = parent:FindFirstChild(name)
	if existing and existing.ClassName == className then
		existing.Value = value
		return existing
	end

	if existing then
		existing:Destroy()
	end

	local newValue = Instance.new(className)
	newValue.Name = name
	newValue.Value = value
	newValue.Parent = parent
	return newValue
end

local function initializeExtractor(placed)
	getOrCreateValue(placed, "NumberValue", "ExtractorTickInterval", 5)
	getOrCreateValue(placed, "NumberValue", "ExtractorHeat", 0)
	getOrCreateValue(placed, "NumberValue", "ExtractorSafeTime", 45)
	getOrCreateValue(placed, "NumberValue", "ExtractorHeatRate", 2.25)
	getOrCreateValue(placed, "NumberValue", "ExtractorShutdownDuration", 30)
	getOrCreateValue(placed, "NumberValue", "ExtractorRestartDuration", 3)
	getOrCreateValue(placed, "NumberValue", "ExtractorRestartCooldown", 8)
	getOrCreateValue(placed, "NumberValue", "ExtractorRestartReadyAt", 0)
	getOrCreateValue(placed, "NumberValue", "ExtractorRestartUntil", 0)
	getOrCreateValue(placed, "IntValue", "ExtractorEnabled", 1)
	getOrCreateValue(placed, "StringValue", "ExtractorState", "Running")
	getOrCreateValue(placed, "IntValue", "ExtractorRestartRequest", 0)
end

local function placeTower(template, towerName, position, yRotation, ownerUserId, spentCosts)
	local placed = template:Clone()
	local rotation = CFrame.Angles(0, math.rad(yRotation % 360), 0)

	local tag = placed:FindFirstChild("TowerType")
	if not tag then
		tag = Instance.new("StringValue")
		tag.Name = "TowerType"
		tag.Parent = placed
	end

	if tag:IsA("StringValue") then
		tag.Value = towerName
	end

	if typeof(ownerUserId) == "number" then
		placed:SetAttribute("OwnerUserId", ownerUserId)
		placed:SetAttribute("TrustedOwnerUserId", ownerUserId)
	end

	local costs = spentCosts or towerCostsByName[towerName] or {}
	placed:SetAttribute("TrustedTowerPlacement", true)
	placed:SetAttribute("SpentStone", costs.stone or 0)
	placed:SetAttribute("SpentCrystal", costs.crystal or 0)
	placed:SetAttribute("SpentMetal", costs.metal or 0)
	placed:SetAttribute("SpentCash", 0)
	placed:SetAttribute("TrustedSpentStone", costs.stone or 0)
	placed:SetAttribute("TrustedSpentCrystal", costs.crystal or 0)
	placed:SetAttribute("TrustedSpentMetal", costs.metal or 0)
	placed:SetAttribute("TrustedSpentCash", 0)

	for i = 1, 3 do
		placed:SetAttribute("UpgradePath" .. i .. "Level", 0)
		placed:SetAttribute("TrustedUpgradePath" .. i .. "Level", 0)
	end

	getOrCreateValue(placed, "StringValue", "TargetingMode", "closest")

	if towerName == "Extractor" then
		initializeExtractor(placed)
	end

	local transparentParts = {}
	if placed:IsA("BasePart") then
		if placed.Transparency == 1 then
			transparentParts[placed] = true
		end
	elseif placed:IsA("Model") then
		for _, part in placed:GetDescendants() do
			if part:IsA("BasePart") and part.Transparency == 1 then
				transparentParts[part] = true
			end
		end
	end

	if placed:IsA("BasePart") then
		placed.Anchored = true
		placed.CanCollide = true
		placed.CFrame = CFrame.new(position) * rotation
		placed.Parent = placedTowersFolder

		if not transparentParts[placed] then
			placed.Transparency = 0
		end
	elseif placed:IsA("Model") then
		for _, part in placed:GetDescendants() do
			if part:IsA("BasePart") then
				part.Anchored = true
				part.CanCollide = true

				if not transparentParts[part] then
					part.Transparency = 0
				end
			end
		end

		placed:PivotTo(CFrame.new(position) * rotation)
		placed.Parent = placedTowersFolder
	end

	-- Tower placement feedback is client-side. Do not run replicated size animation on the server.
	return placed
end

TowerPlaceRemote.OnServerEvent:Connect(function(player, towerName, position, yRotation)
	local now = os.clock()
	if lastPlaceRequestAt[player] and now - lastPlaceRequestAt[player] < PLACE_REQUEST_COOLDOWN and not AntiCheatService:IsBypassed(player) then
		AntiCheatService:Flag(player, "tower placement remote spam", "rejected")
		ResourceService:Sync(player)
		return
	end
	lastPlaceRequestAt[player] = now

	if typeof(towerName) ~= "string" then
		AntiCheatService:Flag(player, "invalid tower placement payload", "rejected")
		ResourceService:Sync(player)
		return
	end

	local template = towersFolder:FindFirstChild(towerName)
	local costs = towerCostsByName[towerName]
	local freeMode = DevSettings:IsFreeMode()
	if not template or not costs then
		AntiCheatService:Flag(player, "unknown tower placement request", "rejected")
		ResourceService:Sync(player)
		return
	end

	if not freeMode and not ResourceService:CanAfford(player, costs) then
		AntiCheatService:Flag(player, "unaffordable tower placement request", "rejected")
		ResourceService:Sync(player)
		return
	end

	local tutorialPlacementActive = player:GetAttribute("TutorialPlacementActive") == true
	if tutorialPlacementActive and not isInsideTutorialObjective(player, towerName, position) then
		AntiCheatService:Flag(player, "tutorial tower placement outside objective", "rejected")
		ResourceService:Sync(player)
		return
	end

	if not tutorialPlacementActive and not canPlaceTower(player, template, position, yRotation) then
		AntiCheatService:Flag(player, "invalid tower placement position", "rejected")
		ResourceService:Sync(player)
		return
	end

	local spentCosts = {
		stone = 0,
		crystal = 0,
		metal = 0,
	}

	if not freeMode then
		if not ResourceService:Spend(player, costs) then
			return
		end

		spentCosts = costs
	else
		ResourceService:Sync(player)
	end

	local placed = placeTower(template, towerName, position, yRotation, player.UserId, spentCosts)
	BalanceLogger:RecordTowerPurchase(player, towerName, spentCosts)
	RunStats:RecordTowerPlaced(player)

	if player:GetAttribute("TutorialPlacementActive") == true and towerName == (player:GetAttribute("TutorialRequiredTower") or "Cannon") then
		TutorialService:CompleteFirstPlacement(player)
	end
end)
