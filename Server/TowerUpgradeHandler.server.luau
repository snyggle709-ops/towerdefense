local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local CashService = require(script.Parent:WaitForChild("CashService"))
local DevSettings = require(ReplicatedStorage:WaitForChild("DevSettings"))
local BalanceLogger = require(script.Parent:WaitForChild("BalanceLogger"))
local RunStats = require(script.Parent:WaitForChild("RunStats"))
local AntiCheatService = require(script.Parent:WaitForChild("AntiCheatService"))
local TowerUpgradesData = require(ReplicatedStorage:WaitForChild("TowerUpgrades"))

local remote = ReplicatedStorage:FindFirstChild("TowerUpgradeRemote")
if remote and not remote:IsA("RemoteEvent") then
	remote:Destroy()
	remote = nil
end

if not remote then
	remote = Instance.new("RemoteEvent")
	remote.Name = "TowerUpgradeRemote"
	remote.Parent = ReplicatedStorage
end

local resultRemote = ReplicatedStorage:FindFirstChild("TowerUpgradeResultRemote")
if resultRemote and not resultRemote:IsA("RemoteEvent") then
	resultRemote:Destroy()
	resultRemote = nil
end

if not resultRemote then
	resultRemote = Instance.new("RemoteEvent")
	resultRemote.Name = "TowerUpgradeResultRemote"
	resultRemote.Parent = ReplicatedStorage
end

local function rejectUpgrade(player, tower, pathIndex, reason)
	if reason ~= "maxed" and reason ~= "path locked" and reason ~= "not enough cash" then
		AntiCheatService:Flag(player, "tower upgrade rejected: " .. tostring(reason), "rejected")
	end
	CashService:Sync(player)
	resultRemote:FireClient(player, false, tower, pathIndex, nil, reason)
end

local function getTowerLevel(tower, pathIndex)
	return math.max(0, tower:GetAttribute("UpgradePath" .. pathIndex .. "Level") or 0)
end

local function buildTowerState(tower, upgradeData)
	local levels = {}
	local chosenCount = 0
	local maxedPath = nil

	for i = 1, 3 do
		local level = getTowerLevel(tower, i)
		local maxLevel = upgradeData and upgradeData.paths and upgradeData.paths[i] and #upgradeData.paths[i].upgrades or 5
		levels[i] = level
		if level > 0 then
			chosenCount += 1
		end
		if level >= maxLevel and not maxedPath then
			maxedPath = i
		end
	end

	return levels, chosenCount, maxedPath
end

local function getTowerType(tower)
	local typeTag = tower and tower:FindFirstChild("TowerType")
	if typeTag and typeTag:IsA("StringValue") then
		return typeTag.Value
	end

	return nil
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

local function ownerHasTierThreePathOfType(player, towerType, pathIndex, ignoredTower)
	local searchRoot = Workspace:FindFirstChild("PlacedTowers") or Workspace
	local upgradeData = TowerUpgradesData[towerType]
	local path = upgradeData and upgradeData.paths and upgradeData.paths[pathIndex] or nil
	local maxLevel = path and #path.upgrades or 5

	for _, otherTower in ipairs(searchRoot:GetChildren()) do
		if otherTower ~= ignoredTower and isTower(otherTower) and ownsTower(player, otherTower) then
			if getTowerType(otherTower) == towerType then
				if getTowerLevel(otherTower, pathIndex) >= maxLevel then
					return true
				end
			end
		end
	end

	return false
end

remote.OnServerEvent:Connect(function(player, tower, pathIndex)
	if typeof(pathIndex) ~= "number" then
		rejectUpgrade(player, tower, nil, "bad path")
		return
	end

	pathIndex = math.floor(pathIndex)
	if pathIndex < 1 or pathIndex > 3 then
		rejectUpgrade(player, tower, pathIndex, "bad path")
		return
	end

	if not isTower(tower) or not ownsTower(player, tower) then
		rejectUpgrade(player, tower, pathIndex, "invalid tower")
		return
	end

	local towerType = getTowerType(tower)
	local upgradeData = towerType and TowerUpgradesData[towerType] or nil
	if not upgradeData then
		rejectUpgrade(player, tower, pathIndex, "missing upgrade data")
		return
	end

	local path = upgradeData.paths[pathIndex]
	if not path then
		rejectUpgrade(player, tower, pathIndex, "missing path")
		return
	end

	local levels, chosenCount, maxedPath = buildTowerState(tower, upgradeData)
	local currentLevel = levels[pathIndex]
	local nextLevel = currentLevel + 1
	local maxLevel = #path.upgrades

	if nextLevel > maxLevel then
		rejectUpgrade(player, tower, pathIndex, "maxed")
		return
	end

	local isChosen = currentLevel > 0
	if chosenCount >= 2 and not isChosen then
		rejectUpgrade(player, tower, pathIndex, "path locked")
		return
	end

	if maxedPath ~= nil and maxedPath ~= pathIndex and nextLevel > maxLevel - 1 then
		rejectUpgrade(player, tower, pathIndex, "path locked")
		return
	end

	if nextLevel >= maxLevel and ownerHasTierThreePathOfType(player, towerType, pathIndex, tower) then
		rejectUpgrade(player, tower, pathIndex, "final tier already owned")
		return
	end

	local upgradeEntry = path.upgrades[nextLevel]
	if not upgradeEntry then
		rejectUpgrade(player, tower, pathIndex, "not enough cash")
		return
	end

	local freeMode = DevSettings:IsFreeMode()
	if not freeMode and not CashService:Spend(player, upgradeEntry.cost) then
		rejectUpgrade(player, tower, pathIndex, "not enough cash")
		return
	end

	if freeMode then
		CashService:Sync(player)
	end

	upgradeEntry.apply(tower)
	tower:SetAttribute("UpgradePath" .. pathIndex .. "Level", nextLevel)
	tower:SetAttribute("TrustedUpgradePath" .. pathIndex .. "Level", nextLevel)
	local spentCash = freeMode and 0 or math.max(0, upgradeEntry.cost or 0)
	tower:SetAttribute("SpentCash", math.max(0, tower:GetAttribute("SpentCash") or 0) + spentCash)
	tower:SetAttribute("TrustedSpentCash", math.max(0, tower:GetAttribute("TrustedSpentCash") or 0) + spentCash)
	BalanceLogger:RecordUpgradePurchase(
		player,
		towerType,
		path.name,
		nextLevel,
		upgradeEntry.description,
		spentCash
	)
	RunStats:RecordUpgradePurchased(player, spentCash)
	resultRemote:FireClient(player, true, tower, pathIndex, nextLevel)
end)
