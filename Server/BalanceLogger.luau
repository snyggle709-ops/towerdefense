local BalanceLogger = {}

local RESOURCE_TYPES = {
	"stone",
	"crystal",
	"metal",
}

local ledgers = {}

local function emptyResources()
	return {
		stone = 0,
		crystal = 0,
		metal = 0,
	}
end

local function getLedger(player)
	local userId = player and player.UserId
	if not userId then
		return nil
	end

	local ledger = ledgers[userId]
	if ledger then
		return ledger
	end

	ledger = {
		cashEarned = 0,
		cashSpent = 0,
		killCash = 0,
		roundRewardCash = 0,
		resourceSaleCash = 0,
		towerRefundCash = 0,
		resourcesEarned = emptyResources(),
		resourcesSpent = emptyResources(),
		resourcesMined = emptyResources(),
		roundRewardResources = emptyResources(),
		towerRefundResources = emptyResources(),
		resourcesSold = emptyResources(),
		towerPurchases = {},
		upgradePurchases = {},
		towerSales = {},
		enemiesKilled = {},
		enemiesLeaked = {},
		killedEnemyDistanceStats = {},
	}
	ledgers[userId] = ledger
	return ledger
end

local function addResource(resources, resourceType, amount)
	if resources[resourceType] == nil then
		return
	end

	resources[resourceType] += math.max(0, math.floor((amount or 0) + 0.5))
end

local function formatResources(resources)
	return string.format(
		"stone=%d crystal=%d metal=%d",
		resources.stone or 0,
		resources.crystal or 0,
		resources.metal or 0
	)
end

local function formatList(entries, emptyText)
	if #entries == 0 then
		return emptyText
	end

	return table.concat(entries, "; ")
end

local function formatCounts(counts)
	local parts = {}

	for name, count in pairs(counts) do
		table.insert(parts, string.format("%s x%d", name, count))
	end

	table.sort(parts)
	return formatList(parts, "none")
end

function BalanceLogger:RecordTowerPurchase(player, towerName, costs)
	local ledger = getLedger(player)
	if not ledger then
		return
	end

	local parts = {}
	for _, resourceType in ipairs(RESOURCE_TYPES) do
		local amount = math.max(0, math.floor(((costs and costs[resourceType]) or 0) + 0.5))
		if amount > 0 then
			addResource(ledger.resourcesSpent, resourceType, amount)
			table.insert(parts, resourceType .. "=" .. amount)
		end
	end

	table.insert(ledger.towerPurchases, string.format("%s (%s)", towerName or "Unknown", table.concat(parts, " ")))
end

function BalanceLogger:RecordUpgradePurchase(player, towerType, pathName, level, description, cost)
	local ledger = getLedger(player)
	if not ledger then
		return
	end

	local amount = math.max(0, math.floor((cost or 0) + 0.5))
	ledger.cashSpent += amount

	table.insert(ledger.upgradePurchases, string.format(
		"%s %s L%d $%d - %s",
		towerType or "Unknown",
		pathName or "Path",
		level or 0,
		amount,
		description or "no description"
	))
end

function BalanceLogger:RecordResourceSale(player, resourceType, cashAmount)
	local ledger = getLedger(player)
	if not ledger then
		return
	end

	local amount = math.max(0, math.floor((cashAmount or 0) + 0.5))
	addResource(ledger.resourcesSold, resourceType, 1)
	addResource(ledger.resourcesSpent, resourceType, 1)
	ledger.cashEarned += amount
	ledger.resourceSaleCash += amount
end

function BalanceLogger:RecordKillCash(player, amount)
	local ledger = getLedger(player)
	if not ledger then
		return
	end

	amount = math.max(0, math.floor((amount or 0) + 0.5))
	ledger.cashEarned += amount
	ledger.killCash += amount
end

function BalanceLogger:RecordRoundReward(player, cashAmount, resources)
	local ledger = getLedger(player)
	if not ledger then
		return
	end

	cashAmount = math.max(0, math.floor((cashAmount or 0) + 0.5))
	ledger.cashEarned += cashAmount
	ledger.roundRewardCash += cashAmount

	for _, resourceType in ipairs(RESOURCE_TYPES) do
		local amount = math.max(0, math.floor(((resources and resources[resourceType]) or 0) + 0.5))
		addResource(ledger.resourcesEarned, resourceType, amount)
		addResource(ledger.roundRewardResources, resourceType, amount)
	end
end

function BalanceLogger:RecordResourceMined(player, resourceType, amount)
	local ledger = getLedger(player)
	if not ledger then
		return
	end

	addResource(ledger.resourcesEarned, resourceType, amount)
	addResource(ledger.resourcesMined, resourceType, amount)
end

function BalanceLogger:RecordTowerSale(player, towerType, cashRefund, resourceRefunds)
	local ledger = getLedger(player)
	if not ledger then
		return
	end

	cashRefund = math.max(0, math.floor((cashRefund or 0) + 0.5))
	ledger.cashEarned += cashRefund
	ledger.towerRefundCash += cashRefund

	for _, resourceType in ipairs(RESOURCE_TYPES) do
		local amount = math.max(0, math.floor(((resourceRefunds and resourceRefunds[resourceType]) or 0) + 0.5))
		addResource(ledger.resourcesEarned, resourceType, amount)
		addResource(ledger.towerRefundResources, resourceType, amount)
	end

	table.insert(ledger.towerSales, string.format(
		"%s refund cash=%d %s",
		towerType or "Unknown",
		cashRefund,
		formatResources(resourceRefunds or emptyResources())
	))
end

function BalanceLogger:RecordEnemyKilled(player, enemyName, closestWaypointDistance)
	local ledger = getLedger(player)
	if not ledger then
		return
	end

	enemyName = enemyName or "Unknown"
	ledger.enemiesKilled[enemyName] = (ledger.enemiesKilled[enemyName] or 0) + 1

	if typeof(closestWaypointDistance) == "number" then
		local distance = math.max(0, closestWaypointDistance)
		local stats = ledger.killedEnemyDistanceStats[enemyName]
		if not stats then
			stats = {
				count = 0,
				total = 0,
				closest = distance,
			}
			ledger.killedEnemyDistanceStats[enemyName] = stats
		end

		stats.count += 1
		stats.total += distance
		stats.closest = math.min(stats.closest, distance)
	end
end

function BalanceLogger:RecordEnemyLeaked(player, enemyName)
	local ledger = getLedger(player)
	if not ledger then
		return
	end

	enemyName = enemyName or "Unknown"
	ledger.enemiesLeaked[enemyName] = (ledger.enemiesLeaked[enemyName] or 0) + 1
end

function BalanceLogger:GetSummaryLines(player)
	local ledger = getLedger(player)
	if not ledger then
		return {}
	end

	local distanceParts = {}
	for enemyName, stats in pairs(ledger.killedEnemyDistanceStats) do
		local average = stats.count > 0 and (stats.total / stats.count) or 0
		table.insert(distanceParts, string.format(
			"%s count=%d avg=%.1f closest=%.1f studs",
			enemyName,
			stats.count,
			average,
			stats.closest
		))
	end
	table.sort(distanceParts)

	return {
		string.format(
			"[BalanceDetail] Cash earned=%d (kills=%d rewards=%d resourceSales=%d towerRefunds=%d) spent=%d",
			ledger.cashEarned,
			ledger.killCash,
			ledger.roundRewardCash,
			ledger.resourceSaleCash,
			ledger.towerRefundCash,
			ledger.cashSpent
		),
		string.format(
			"[BalanceDetail] Resources earned %s (mined %s rewards %s towerRefunds %s)",
			formatResources(ledger.resourcesEarned),
			formatResources(ledger.resourcesMined),
			formatResources(ledger.roundRewardResources),
			formatResources(ledger.towerRefundResources)
		),
		string.format(
			"[BalanceDetail] Resources spent %s sold %s",
			formatResources(ledger.resourcesSpent),
			formatResources(ledger.resourcesSold)
		),
		"[BalanceDetail] Towers bought: " .. formatList(ledger.towerPurchases, "none"),
		"[BalanceDetail] Upgrades bought: " .. formatList(ledger.upgradePurchases, "none"),
		"[BalanceDetail] Towers sold: " .. formatList(ledger.towerSales, "none"),
		"[BalanceDetail] Enemies killed: " .. formatCounts(ledger.enemiesKilled),
		"[BalanceDetail] Enemies leaked: " .. formatCounts(ledger.enemiesLeaked),
		"[BalanceDetail] Killed enemy closest-to-waypoint: "
			.. formatList(distanceParts, "none"),
	}
end

function BalanceLogger:ResetAll()
	table.clear(ledgers)
end

return BalanceLogger
