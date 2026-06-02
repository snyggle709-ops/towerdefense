local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local CashService = require(script.Parent:WaitForChild("CashService"))
local ResourceService = require(script.Parent:WaitForChild("ResourceService"))
local BalanceLogger = require(script.Parent:WaitForChild("BalanceLogger"))
local AntiCheatService = require(script.Parent:WaitForChild("AntiCheatService"))
local TowerData = require(ReplicatedStorage:WaitForChild("TowerData"))
local DialogueService = require(script.Parent:WaitForChild("DialogueService"))

local FIRST_TOWER_SELL_DIALOGUE_TEXT = "Aww... Selling it already? Not even a second chance?"
local FIRST_TOWER_SELL_DIALOGUE_SOUND_ID = "rbxassetid://97956221537533"
local firstTowerSellDialogueByUserId = {}

local sellRemote = ReplicatedStorage:FindFirstChild("TowerSellRemote")
if sellRemote and not sellRemote:IsA("RemoteEvent") then
	sellRemote:Destroy()
	sellRemote = nil
end

if not sellRemote then
	sellRemote = Instance.new("RemoteEvent")
	sellRemote.Name = "TowerSellRemote"
	sellRemote.Parent = ReplicatedStorage
end

local towerCostsByName = {}
for _, towerInfo in ipairs(TowerData) do
	towerCostsByName[towerInfo.name] = {
		stone = towerInfo.stone or 0,
		crystal = towerInfo.crystal or 0,
		metal = towerInfo.metal or 0,
	}
end

local function ownsTower(player, tower)
	local ownerUserId = tower:GetAttribute("OwnerUserId")
	if typeof(ownerUserId) ~= "number" then
		if #Players:GetPlayers() == 1 then
			tower:SetAttribute("OwnerUserId", player.UserId)
			return true
		end
		return false
	end

	return ownerUserId == player.UserId
end

local function isTower(instance)
	return instance
		and instance.Parent
		and instance:IsDescendantOf(Workspace)
		and (instance:FindFirstChild("TowerType")
			or instance:FindFirstChild("ExtractorEnabled")
			or (instance:FindFirstChild("Radius")
				and instance:FindFirstChild("Damage")
				and instance:FindFirstChild("AttackSpeed")))
end

local function getSpentResource(tower, towerType, resourceType)
	local trustedAttrName = "TrustedSpent" .. resourceType:sub(1, 1):upper() .. resourceType:sub(2)
	local trustedSpent = tower:GetAttribute(trustedAttrName)
	if typeof(trustedSpent) == "number" then
		return math.max(0, trustedSpent)
	end

	local attrName = "Spent" .. resourceType:sub(1, 1):upper() .. resourceType:sub(2)
	local spent = tower:GetAttribute(attrName)
	if typeof(spent) == "number" then
		return math.max(0, spent)
	end

	local costs = towerCostsByName[towerType]
	return costs and math.max(0, costs[resourceType] or 0) or 0
end

local function refundAmount(amount, multiplier)
	return math.max(0, math.floor((amount * multiplier) + 0.5))
end

local function triggerFirstTowerSellDialogue(player)
	if not player or firstTowerSellDialogueByUserId[player.UserId] then
		return
	end

	firstTowerSellDialogueByUserId[player.UserId] = true
	DialogueService:FireClient(player, FIRST_TOWER_SELL_DIALOGUE_TEXT, {
		soundId = FIRST_TOWER_SELL_DIALOGUE_SOUND_ID,
	})
end

sellRemote.OnServerEvent:Connect(function(player, tower)
	if not isTower(tower) or not ownsTower(player, tower) then
		AntiCheatService:Flag(player, "invalid tower sell request", "rejected")
		CashService:Sync(player)
		ResourceService:Sync(player)
		return
	end

	local typeTag = tower:FindFirstChild("TowerType")
	local towerType = typeTag and typeTag.Value or tower.Name
	local resourceRefunds = {
		stone = 0,
		crystal = 0,
		metal = 0,
	}

	for _, resourceType in ipairs({"stone", "crystal", "metal"}) do
		local refund = refundAmount(getSpentResource(tower, towerType, resourceType), 0.7)
		if refund > 0 then
			resourceRefunds[resourceType] = ResourceService:Add(player, resourceType, refund)
		end
	end

	local cashRefund = 0
	local spentCash = tower:GetAttribute("TrustedSpentCash")
	if typeof(spentCash) ~= "number" then
		spentCash = tower:GetAttribute("SpentCash")
	end
	if typeof(spentCash) == "number" and spentCash > 0 then
		cashRefund = CashService:Add(player, refundAmount(spentCash, 0.5))
	else
		CashService:Sync(player)
	end

	BalanceLogger:RecordTowerSale(player, towerType, cashRefund, resourceRefunds)
	triggerFirstTowerSellDialogue(player)

	if tower and tower.Parent then
		tower:Destroy()
	end
end)

Players.PlayerRemoving:Connect(function(player)
	firstTowerSellDialogueByUserId[player.UserId] = nil
end)
