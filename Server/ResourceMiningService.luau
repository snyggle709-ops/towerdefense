local ResourceMiningService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ResourceService = require(script.Parent:WaitForChild("ResourceService"))
local BalanceLogger = require(script.Parent:WaitForChild("BalanceLogger"))
local RunStats = require(script.Parent:WaitForChild("RunStats"))
local AntiCheatService = require(script.Parent:WaitForChild("AntiCheatService"))

local registeredResources = {}
local RESOURCE_INDEX_CELL_SIZE = 32
local resourceGrid = {}
local resourceIndexEntries = {}
local lastMiningAnimationAt = {}
local lastToolMineAt = {}
local lastManualMineAt = {}
local miningParticleRemote = ReplicatedStorage:FindFirstChild("MiningParticleRemote")
if not miningParticleRemote then
	miningParticleRemote = Instance.new("RemoteEvent")
	miningParticleRemote.Name = "MiningParticleRemote"
	miningParticleRemote.Parent = ReplicatedStorage
end
local miningCompleteSoundRemote = ReplicatedStorage:FindFirstChild("MiningCompleteSoundRemote")
if not miningCompleteSoundRemote then
	miningCompleteSoundRemote = Instance.new("RemoteEvent")
	miningCompleteSoundRemote.Name = "MiningCompleteSoundRemote"
	miningCompleteSoundRemote.Parent = ReplicatedStorage
end
local manualMiningPickupRemote = ReplicatedStorage:FindFirstChild("ManualMiningPickupRemote")
if not manualMiningPickupRemote then
	manualMiningPickupRemote = Instance.new("RemoteEvent")
	manualMiningPickupRemote.Name = "ManualMiningPickupRemote"
	manualMiningPickupRemote.Parent = ReplicatedStorage
end
local requestMineRemote = ReplicatedStorage:FindFirstChild("RequestMineResourceRemote")
if not requestMineRemote then
	requestMineRemote = Instance.new("RemoteEvent")
	requestMineRemote.Name = "RequestMineResourceRemote"
	requestMineRemote.Parent = ReplicatedStorage
end
local miningAnimationRemote = ReplicatedStorage:FindFirstChild("MiningAnimationRemote")
if not miningAnimationRemote then
	miningAnimationRemote = Instance.new("RemoteEvent")
	miningAnimationRemote.Name = "MiningAnimationRemote"
	miningAnimationRemote.Parent = ReplicatedStorage
end

local MINING_ANIMATION_COOLDOWN = 0.22
local MANUAL_MINE_COOLDOWN = 0.3
local TOOL_MINE_COOLDOWN = MANUAL_MINE_COOLDOWN
local TOOL_MINE_RANGE = 17
local MAX_PICKAXE_STRENGTH = 0
local MAX_RESOURCE_MULTIPLIER = 1
local MANUAL_DOUBLE_CHANCES = {
	stone = 0.35,
	crystal = 0.1,
	metal = 0.03,
}

local function isAntiCheatBypassed(player)
	return AntiCheatService:IsBypassed(player)
end

local function getResourcePosition(resource, data)
	local part = data.primaryPart
	if part and part.Parent and part:IsA("BasePart") then
		return part.Position
	end

	if resource:IsA("BasePart") then
		return resource.Position
	end

	if resource:IsA("Model") then
		return resource:GetPivot().Position
	end

	return nil
end

local function getResourcePart(resource, data)
	local part = data.primaryPart
	if part and part.Parent and part:IsA("BasePart") then
		return part
	end

	if resource:IsA("BasePart") then
		return resource
	end

	if resource:IsA("Model") then
		return resource.PrimaryPart or resource:FindFirstChildWhichIsA("BasePart")
	end

	return nil
end

local function getResourceCellCoord(value)
	return math.floor(value / RESOURCE_INDEX_CELL_SIZE)
end

local function getResourceCellKey(cellX, cellZ)
	return tostring(cellX) .. ":" .. tostring(cellZ)
end

local function getResourceCellKeyForPosition(position)
	return getResourceCellKey(getResourceCellCoord(position.X), getResourceCellCoord(position.Z))
end

local function removeResourceFromIndex(resource)
	local entry = resourceIndexEntries[resource]
	if not entry then
		return
	end

	local bucket = resourceGrid[entry.key]
	if bucket then
		bucket[resource] = nil
		if not next(bucket) then
			resourceGrid[entry.key] = nil
		end
	end
	resourceIndexEntries[resource] = nil
end

local function indexResource(resource, data)
	local position = getResourcePosition(resource, data)
	if not position then
		removeResourceFromIndex(resource)
		return nil
	end

	local key = getResourceCellKeyForPosition(position)
	local entry = resourceIndexEntries[resource]
	if entry and entry.key == key then
		entry.position = position
		return position
	end

	removeResourceFromIndex(resource)
	local bucket = resourceGrid[key]
	if not bucket then
		bucket = {}
		resourceGrid[key] = bucket
	end

	bucket[resource] = true
	resourceIndexEntries[resource] = {
		key = key,
		position = position,
	}

	return position
end

local function getIndexedResourcePosition(resource, data)
	local entry = resourceIndexEntries[resource]
	local position = getResourcePosition(resource, data)
	if not position then
		removeResourceFromIndex(resource)
		return nil
	end

	local key = getResourceCellKeyForPosition(position)
	if entry and entry.key == key then
		entry.position = position
		return position
	end

	return indexResource(resource, data)
end

local function removeStaleResource(resource)
	registeredResources[resource] = nil
	removeResourceFromIndex(resource)
end

local function forResourcesInRadius(position, radius, callback)
	local radiusSq = radius * radius
	local minCellX = getResourceCellCoord(position.X - radius)
	local maxCellX = getResourceCellCoord(position.X + radius)
	local minCellZ = getResourceCellCoord(position.Z - radius)
	local maxCellZ = getResourceCellCoord(position.Z + radius)

	for cellX = minCellX, maxCellX do
		for cellZ = minCellZ, maxCellZ do
			local bucket = resourceGrid[getResourceCellKey(cellX, cellZ)]
			if bucket then
				for resource in pairs(bucket) do
					local data = registeredResources[resource]
					if data and resource.Parent and not data.depleted then
						local resourcePosition = getIndexedResourcePosition(resource, data)
						if resourcePosition then
							local offset = resourcePosition - position
							local distanceSq = (offset.X * offset.X) + (offset.Z * offset.Z)
							if distanceSq <= radiusSq then
								callback(resource, data, resourcePosition, distanceSq)
							end
						end
					else
						removeStaleResource(resource)
					end
				end
			end
		end
	end
end

local function getParticleColor(resourceType, part)
	if resourceType == "crystal" then
		return Color3.fromRGB(205, 80, 255)
	end

	if resourceType == "metal" then
		return Color3.fromRGB(58, 58, 94)
	end

	return part and part.Color or Color3.fromRGB(105, 105, 105)
end

local function getDamage(player)
	local strength = player and player:GetAttribute("PickaxeStrength") or 0
	if not isAntiCheatBypassed(player) then
		strength = math.clamp(tonumber(strength) or 0, 0, MAX_PICKAXE_STRENGTH)
	end

	return 1 + (strength * 0.5)
end

local function findRegisteredResourceFromInstance(instance)
	local current = instance
	while current do
		if registeredResources[current] then
			return current
		end
		current = current.Parent
	end

	return nil
end

local function playMiningAnimation(player)
	if not player or not player.Character then
		return
	end

	local now = tick()
	if lastMiningAnimationAt[player] and now - lastMiningAnimationAt[player] < MINING_ANIMATION_COOLDOWN then
		return
	end
	lastMiningAnimationAt[player] = now
	miningAnimationRemote:FireClient(player)
end

local function getManualMiningRewardAmount(resourceType, baseAmount)
	local amount = tonumber(baseAmount) or 0
	local doubleChance = MANUAL_DOUBLE_CHANCES[resourceType]
	if doubleChance and math.random() < doubleChance then
		return amount * 2
	end

	return amount
end

function ResourceMiningService:Register(resource, data)
	if not resource or not resource.Parent then
		return
	end

	data.health = data.maxHealth
	data.depleted = false
	registeredResources[resource] = data
	indexResource(resource, data)

	resource:SetAttribute("ResourceType", data.resourceType)
	resource:SetAttribute("ResourceHealth", data.health)
	resource:SetAttribute("ResourceMaxHealth", data.maxHealth)
	resource:SetAttribute("ResourceAmount", data.amount)

	resource.Destroying:Connect(function()
		removeStaleResource(resource)
	end)
end

function ResourceMiningService:Unregister(resource)
	removeStaleResource(resource)
end

function ResourceMiningService:PlayerHasPickaxeEquipped(player)
	local character = player and player.Character
	local tool = character and character:FindFirstChild("Pickaxe")
	return tool ~= nil and tool:IsA("Tool")
end

function ResourceMiningService:Mine(resource, player, damage, options)
	local data = registeredResources[resource]
	if not data or data.depleted or not resource.Parent then
		return false
	end

	options = options or {}
	damage = damage or 1
	if options.manual == true and player and not isAntiCheatBypassed(player) then
		local now = os.clock()
		if lastManualMineAt[player] and now - lastManualMineAt[player] < MANUAL_MINE_COOLDOWN then
			return false
		end
		lastManualMineAt[player] = now

		local requestedDamage = tonumber(damage) or 1
		local allowedDamage = getDamage(player)
		if requestedDamage > allowedDamage + 0.001 then
			AntiCheatService:Flag(player, "manual mining damage exceeded", "clamped")
		end
		damage = math.min(requestedDamage, allowedDamage)
	end

	data.health -= damage
	resource:SetAttribute("ResourceHealth", data.health)

	if data.playAnimationOnMine and options.manual == true then
		playMiningAnimation(player)
	end

	local resourcePart = getResourcePart(resource, data)
	if resourcePart then
		miningParticleRemote:FireAllClients(resourcePart.Position, getParticleColor(data.resourceType, resourcePart), data.resourceType)
	end

	if data.onFirstMined then
		data.onFirstMined(data.health, data.maxHealth)
	end

	if data.onHit then
		data.onHit()
	end

	if data.health <= 0 then
		data.depleted = true
		removeStaleResource(resource)
		local completionPosition = resourcePart and resourcePart.Position or getResourcePosition(resource, data)
		if completionPosition then
			miningCompleteSoundRemote:FireAllClients(completionPosition, data.resourceType)
		end

		if player then
			local multiplier = player:GetAttribute("ResourceMultiplier") or 1
			if not isAntiCheatBypassed(player) then
				multiplier = math.clamp(tonumber(multiplier) or 1, 1, MAX_RESOURCE_MULTIPLIER)
			end

			local rewardAmount = data.amount
			if options.manual == true then
				rewardAmount = getManualMiningRewardAmount(data.resourceType, rewardAmount)
			end

			local gained = ResourceService:Add(player, data.resourceType, rewardAmount * multiplier)
			BalanceLogger:RecordResourceMined(player, data.resourceType, gained)
			if options.manual == true then
				RunStats:RecordManualResourceMined(player, data.resourceType, gained)
				if completionPosition then
					manualMiningPickupRemote:FireClient(player, data.resourceType, gained, completionPosition)
				end
			end
		end

		if data.onDepleted then
			data.onDepleted()
		end

		return true
	end

	if data.onHealthChanged then
		data.onHealthChanged(data.health, data.maxHealth)
	end

	return true
end

function ResourceMiningService:MineFromTool(player, hitInstance)
	if not player or not player.Character or not hitInstance then
		return false
	end

	if not self:PlayerHasPickaxeEquipped(player) then
		return false
	end

	local now = tick()
	if lastToolMineAt[player] and now - lastToolMineAt[player] < TOOL_MINE_COOLDOWN then
		return false
	end

	local resource = findRegisteredResourceFromInstance(hitInstance)
	local data = resource and registeredResources[resource]
	if not data or data.depleted then
		return false
	end

	local root = player.Character:FindFirstChild("HumanoidRootPart")
	local resourcePosition = getResourcePosition(resource, data)
	if not root or not resourcePosition then
		return false
	end

	if (root.Position - resourcePosition).Magnitude > TOOL_MINE_RANGE then
		return false
	end

	lastToolMineAt[player] = now
	return self:Mine(resource, player, getDamage(player), { manual = true })
end

function ResourceMiningService:GetNearestResource(position, radius)
	local nearestResource = nil
	local nearestDistanceSq = radius * radius

	forResourcesInRadius(position, radius, function(resource, _data, _resourcePosition, distanceSq)
		if distanceSq <= nearestDistanceSq then
			nearestDistanceSq = distanceSq
			nearestResource = resource
		end
	end)

	return nearestResource
end

function ResourceMiningService:GetResourcesInRadius(position, radius)
	local resources = {}

	forResourcesInRadius(position, radius, function(resource)
		table.insert(resources, resource)
	end)

	return resources
end

requestMineRemote.OnServerEvent:Connect(function(player, hitInstance)
	ResourceMiningService:MineFromTool(player, hitInstance)
end)

return ResourceMiningService
