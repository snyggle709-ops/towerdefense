local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AntiCheatService = require(script.Parent:WaitForChild("AntiCheatService"))

local ResourceService = {}

local MAX_RESOURCE = 50
local RESOURCE_TYPES = {
	"stone",
	"crystal",
	"metal",
}

local resourceTypeLookup = {}
for _, resourceType in ipairs(RESOURCE_TYPES) do
	resourceTypeLookup[resourceType] = true
end

local syncRemote = ReplicatedStorage:FindFirstChild("ResourceSyncRemote")
if not syncRemote then
	syncRemote = Instance.new("RemoteEvent")
	syncRemote.Name = "ResourceSyncRemote"
	syncRemote.Parent = ReplicatedStorage
end

local function isValidResourceType(resourceType)
	return resourceTypeLookup[resourceType] == true
end

local function clampResourceAmount(amount)
	if typeof(amount) ~= "number" then
		return 0
	end

	return math.clamp(math.floor(amount + 0.5), 0, MAX_RESOURCE)
end

local function getResourceValue(player, resourceType)
	if not isValidResourceType(resourceType) then
		return 0
	end

	return clampResourceAmount(player:GetAttribute(resourceType))
end

local function setResourceValue(player, resourceType, amount)
	if not isValidResourceType(resourceType) then
		return
	end

	local value = clampResourceAmount(amount)
	player:SetAttribute(resourceType, value)
	AntiCheatService:SetTrustedAttribute(player, resourceType, value)
end

local function getDevResourceValue(player, resourceType)
	if not isValidResourceType(resourceType) then
		return 0
	end

	local amount = player:GetAttribute(resourceType)
	if typeof(amount) ~= "number" then
		return 0
	end

	return math.floor(amount + 0.5)
end

local function getDevSnapshot(player)
	local snapshot = {}

	for _, resourceType in ipairs(RESOURCE_TYPES) do
		snapshot[resourceType] = getDevResourceValue(player, resourceType)
	end

	return snapshot
end

function ResourceService:GetSnapshot(player)
	local snapshot = {}

	for _, resourceType in ipairs(RESOURCE_TYPES) do
		snapshot[resourceType] = getResourceValue(player, resourceType)
	end

	return snapshot
end

function ResourceService:Sync(player)
	if not player or player.Parent ~= Players then
		return
	end

	syncRemote:FireClient(player, self:GetSnapshot(player))
end

function ResourceService:InitPlayer(player)
	for _, resourceType in ipairs(RESOURCE_TYPES) do
		setResourceValue(player, resourceType, player:GetAttribute(resourceType))
	end

	self:Sync(player)
end

function ResourceService:Get(player, resourceType)
	if not player or player.Parent ~= Players then
		return 0
	end

	return getResourceValue(player, resourceType)
end

function ResourceService:Add(player, resourceType, amount)
	if not player or player.Parent ~= Players then
		return 0
	end

	if not isValidResourceType(resourceType) or typeof(amount) ~= "number" then
		self:Sync(player)
		return 0
	end

	local current = getResourceValue(player, resourceType)
	local nextValue = clampResourceAmount(current + amount)
	local delta = nextValue - current

	if delta ~= 0 then
		setResourceValue(player, resourceType, nextValue)
	end

	self:Sync(player)

	return delta
end

function ResourceService:AddDev(player, resourceType, amount)
	if not player or player.Parent ~= Players then
		return 0
	end

	if not isValidResourceType(resourceType) or typeof(amount) ~= "number" then
		syncRemote:FireClient(player, getDevSnapshot(player))
		return 0
	end

	local current = getDevResourceValue(player, resourceType)
	local nextValue = math.floor(current + amount + 0.5)
	local delta = nextValue - current

	if delta ~= 0 then
		player:SetAttribute(resourceType, nextValue)
		AntiCheatService:SetTrustedAttribute(player, resourceType, nextValue)
	end

	syncRemote:FireClient(player, getDevSnapshot(player))

	return delta
end

function ResourceService:CanAfford(player, costs)
	if not player or player.Parent ~= Players then
		return false
	end

	for _, resourceType in ipairs(RESOURCE_TYPES) do
		local cost = 0

		if typeof(costs) == "table" and typeof(costs[resourceType]) == "number" then
			cost = math.max(0, math.floor(costs[resourceType] + 0.5))
		end

		if getResourceValue(player, resourceType) < cost then
			return false
		end
	end

	return true
end

function ResourceService:Spend(player, costs)
	if not self:CanAfford(player, costs) then
		self:Sync(player)
		return false
	end

	for _, resourceType in ipairs(RESOURCE_TYPES) do
		local cost = 0

		if typeof(costs) == "table" and typeof(costs[resourceType]) == "number" then
			cost = math.max(0, math.floor(costs[resourceType] + 0.5))
		end

		if cost > 0 then
			setResourceValue(player, resourceType, getResourceValue(player, resourceType) - cost)
		end
	end

	self:Sync(player)

	return true
end

return ResourceService
