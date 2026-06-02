local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local AntiCheatService = require(script.Parent:WaitForChild("AntiCheatService"))

local RunStats = {}

local FIRST_STONETHING_ROUND = 18
local RESOURCE_TYPES = { "stone", "crystal", "metal" }

local statsByUserId = {}

local function emptyResources()
	return {
		stone = 0,
		crystal = 0,
		metal = 0,
	}
end

local function newStats()
	local stats = {
		startedAt = nil,
		roundsSurvived = 0,
		enemiesKilled = 0,
		enemiesLeaked = {},
		finalLeak = nil,
		totalDamageDealt = 0,
		totalCashSpent = 0,
		towersPlaced = 0,
		upgradesPurchased = 0,
		manualResourcesMined = emptyResources(),
		survivedFirstStonethingRound = false,
	}
	stats.trusted = {
		startedAt = nil,
		roundsSurvived = 0,
		enemiesKilled = 0,
		enemiesLeaked = {},
		finalLeak = nil,
		totalDamageDealt = 0,
		totalCashSpent = 0,
		towersPlaced = 0,
		upgradesPurchased = 0,
		manualResourcesMined = emptyResources(),
		survivedFirstStonethingRound = false,
	}
	return stats
end

local function getStats(player)
	if not player or not player.UserId then
		return nil
	end

	local stats = statsByUserId[player.UserId]
	if not stats then
		stats = newStats()
		statsByUserId[player.UserId] = stats
	end

	return stats
end

local function getAllPlayers()
	return Players:GetPlayers()
end

local function countResources(resources)
	local total = 0
	for _, resourceType in ipairs(RESOURCE_TYPES) do
		total += resources[resourceType] or 0
	end
	return total
end

local function getMostLeaked(leaks)
	local bestName = nil
	local bestCount = 0

	for enemyName, count in pairs(leaks) do
		if count > bestCount then
			bestName = enemyName
			bestCount = count
		end
	end

	if not bestName then
		return "none"
	end

	return string.format("%s x%d", bestName, bestCount)
end

local function getTowerOwnerId(tower)
	local ownerUserId = tower:GetAttribute("OwnerUserId")
	if typeof(ownerUserId) == "number" then
		return ownerUserId
	end

	local ownerValue = tower:FindFirstChild("OwnerUserId")
	if ownerValue and ownerValue:IsA("IntValue") then
		return ownerValue.Value
	end

	return nil
end

local function countMaxedUpgrades(player)
	local placedTowers = Workspace:FindFirstChild("PlacedTowers")
	if not placedTowers then
		return 0
	end

	local total = 0
	for _, tower in ipairs(placedTowers:GetChildren()) do
		local ownerUserId = getTowerOwnerId(tower)
		if ownerUserId == nil or ownerUserId == player.UserId then
			for pathIndex = 1, 3 do
				local trustedLevel = tower:GetAttribute("TrustedUpgradePath" .. pathIndex .. "Level")
				local level = typeof(trustedLevel) == "number" and trustedLevel or tower:GetAttribute("UpgradePath" .. pathIndex .. "Level")
				local publicLevel = tower:GetAttribute("UpgradePath" .. pathIndex .. "Level")
				if typeof(trustedLevel) == "number" and publicLevel ~= trustedLevel then
					AntiCheatService:Flag(player, "game-over max upgrade stat tamper", "ignored")
				end
				if typeof(level) == "number" and level >= 5 then
					total += 1
				end
			end
		end
	end

	return total
end

function RunStats:Reset(player)
	if player and player.UserId then
		statsByUserId[player.UserId] = newStats()
	end
end

function RunStats:ResetAll()
	for _, player in ipairs(getAllPlayers()) do
		self:Reset(player)
	end
end

function RunStats:RecordRoundStarted()
	for _, player in ipairs(getAllPlayers()) do
		local stats = getStats(player)
		if stats and not stats.startedAt then
			stats.startedAt = os.clock()
			stats.trusted.startedAt = stats.startedAt
		end
	end
end

function RunStats:RecordRoundCompleted(round)
	for _, player in ipairs(getAllPlayers()) do
		local stats = getStats(player)
		if stats then
			stats.roundsSurvived = math.max(stats.roundsSurvived, math.floor(round or 0))
			stats.trusted.roundsSurvived = math.max(stats.trusted.roundsSurvived, math.floor(round or 0))
			if round == FIRST_STONETHING_ROUND then
				stats.survivedFirstStonethingRound = true
				stats.trusted.survivedFirstStonethingRound = true
			end
		end
	end
end

function RunStats:RecordEnemyKilled(enemyName)
	for _, player in ipairs(getAllPlayers()) do
		local stats = getStats(player)
		if stats then
			stats.enemiesKilled += 1
			stats.trusted.enemiesKilled += 1
		end
	end
end

function RunStats:RecordEnemyLeaked(enemyName)
	enemyName = enemyName or "Unknown"
	for _, player in ipairs(getAllPlayers()) do
		local stats = getStats(player)
		if stats then
			stats.enemiesLeaked[enemyName] = (stats.enemiesLeaked[enemyName] or 0) + 1
			stats.trusted.enemiesLeaked[enemyName] = (stats.trusted.enemiesLeaked[enemyName] or 0) + 1
		end
	end
end

function RunStats:RecordFinalLeak(enemyName)
	enemyName = enemyName or "none"
	for _, player in ipairs(getAllPlayers()) do
		local stats = getStats(player)
		if stats then
			stats.finalLeak = enemyName
			stats.trusted.finalLeak = enemyName
		end
	end
end

function RunStats:RecordDamageDealt(amount)
	amount = math.max(0, math.floor((amount or 0) + 0.5))
	if amount <= 0 then
		return
	end

	for _, player in ipairs(getAllPlayers()) do
		local stats = getStats(player)
		if stats then
			stats.totalDamageDealt += amount
			stats.trusted.totalDamageDealt += amount
		end
	end
end

function RunStats:RecordTowerPlaced(player)
	local stats = getStats(player)
	if stats then
		stats.towersPlaced += 1
		stats.trusted.towersPlaced += 1
	end
end

function RunStats:RecordUpgradePurchased(player, cashSpent)
	local stats = getStats(player)
	if stats then
		stats.upgradesPurchased += 1
		stats.totalCashSpent += math.max(0, math.floor((cashSpent or 0) + 0.5))
		stats.trusted.upgradesPurchased += 1
		stats.trusted.totalCashSpent += math.max(0, math.floor((cashSpent or 0) + 0.5))
	end
end

function RunStats:RecordManualResourceMined(player, resourceType, amount)
	local stats = getStats(player)
	if not stats or stats.manualResourcesMined[resourceType] == nil then
		return
	end

	stats.manualResourcesMined[resourceType] += math.max(0, math.floor((amount or 0) + 0.5))
	stats.trusted.manualResourcesMined[resourceType] += math.max(0, math.floor((amount or 0) + 0.5))
end

function RunStats:DevTamper(player, method)
	local stats = getStats(player)
	if not stats then
		return false
	end

	method = math.max(1, math.min(10, math.floor(tonumber(method) or 1)))
	if method == 1 then
		stats.roundsSurvived = 999
	elseif method == 2 then
		stats.enemiesKilled = 99999
	elseif method == 3 then
		stats.manualResourcesMined.stone = 99999
	elseif method == 4 then
		stats.manualResourcesMined.crystal = 99999
	elseif method == 5 then
		stats.manualResourcesMined.metal = 99999
	elseif method == 6 then
		stats.survivedFirstStonethingRound = true
	elseif method == 7 then
		stats.totalDamageDealt = 99999999
	elseif method == 8 then
		stats.totalCashSpent = 99999999
	elseif method == 9 then
		stats.towersPlaced = 999
	else
		stats.upgradesPurchased = 999
	end

	return true
end

local function statMismatch(stats, field)
	return stats[field] ~= stats.trusted[field]
end

local function resourceMismatch(stats)
	for _, resourceType in ipairs(RESOURCE_TYPES) do
		if stats.manualResourcesMined[resourceType] ~= stats.trusted.manualResourcesMined[resourceType] then
			return true
		end
	end

	return false
end

function RunStats:GetGameOverSummary(player)
	local stats = getStats(player)
	if not stats then
		return {}
	end

	if statMismatch(stats, "roundsSurvived")
		or statMismatch(stats, "enemiesKilled")
		or statMismatch(stats, "totalDamageDealt")
		or statMismatch(stats, "totalCashSpent")
		or statMismatch(stats, "towersPlaced")
		or statMismatch(stats, "upgradesPurchased")
		or stats.survivedFirstStonethingRound ~= stats.trusted.survivedFirstStonethingRound
		or resourceMismatch(stats)
	then
		AntiCheatService:Flag(player, "game-over run stat tamper", "ignored")
	end

	local trusted = stats.trusted
	local maxedUpgradeCount = countMaxedUpgrades(player)
	local survivalSeconds = trusted.startedAt and math.max(0, os.clock() - trusted.startedAt) or 0
	local manualResourceTotal = countResources(trusted.manualResourcesMined)
	local tokens = 0

	tokens += math.floor(trusted.roundsSurvived / 10)
	tokens += math.floor(trusted.enemiesKilled / 50)
	tokens += math.floor(survivalSeconds / 180)
	if trusted.survivedFirstStonethingRound then
		tokens += 10
	end
	tokens += maxedUpgradeCount
	tokens += math.floor(manualResourceTotal / 200)

	return {
		roundsSurvived = trusted.roundsSurvived,
		enemiesKilled = trusted.enemiesKilled,
		materialsMined = {
			stone = trusted.manualResourcesMined.stone,
			crystal = trusted.manualResourcesMined.crystal,
			metal = trusted.manualResourcesMined.metal,
		},
		totalDamageDealt = trusted.totalDamageDealt,
		mostLeaked = getMostLeaked(trusted.enemiesLeaked),
		finalLeak = trusted.finalLeak or "none",
		totalCashSpent = trusted.totalCashSpent,
		towersPlaced = trusted.towersPlaced,
		upgradesPurchased = trusted.upgradesPurchased,
		maxedUpgrades = maxedUpgradeCount,
		survivalSeconds = survivalSeconds,
		tokensEarned = tokens,
	}
end

Players.PlayerAdded:Connect(function(player)
	RunStats:Reset(player)
end)

Players.PlayerRemoving:Connect(function(player)
	if player and player.UserId then
		statsByUserId[player.UserId] = nil
	end
end)

return RunStats
