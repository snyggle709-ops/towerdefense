local Comm = require(game.ReplicatedStorage:WaitForChild("Comm"))
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TimerRemote = game.ReplicatedStorage:WaitForChild("TimerRemote")
local WarningRemote = game.ReplicatedStorage:WaitForChild("WarningRemote")
local BossAnimRemote = game.ReplicatedStorage:WaitForChild("BossAnimRemote")
local DialogueService = require(script.Parent:WaitForChild("DialogueService"))
local TutorialService = require(script.Parent:WaitForChild("TutorialService"))
local CustomChatRemote = game.ReplicatedStorage:WaitForChild("CustomChatRemote")
local RoundRewardBurstRemote = game.ReplicatedStorage:FindFirstChild("RoundRewardBurstRemote")
if not RoundRewardBurstRemote then
	RoundRewardBurstRemote = Instance.new("RemoteEvent")
	RoundRewardBurstRemote.Name = "RoundRewardBurstRemote"
	RoundRewardBurstRemote.Parent = game.ReplicatedStorage
end
local PerformanceRequestRemote = game.ReplicatedStorage:FindFirstChild("PerformanceRequestRemote")
if not PerformanceRequestRemote then
	PerformanceRequestRemote = Instance.new("RemoteEvent")
	PerformanceRequestRemote.Name = "PerformanceRequestRemote"
	PerformanceRequestRemote.Parent = game.ReplicatedStorage
end
local PerformanceResponseRemote = game.ReplicatedStorage:FindFirstChild("PerformanceResponseRemote")
if not PerformanceResponseRemote then
	PerformanceResponseRemote = Instance.new("RemoteEvent")
	PerformanceResponseRemote.Name = "PerformanceResponseRemote"
	PerformanceResponseRemote.Parent = game.ReplicatedStorage
end
local ResourceService = require(script.Parent:WaitForChild("ResourceService"))
local ResourceMiningService = require(script.Parent:WaitForChild("ResourceMiningService"))
local CashService = require(script.Parent:WaitForChild("CashService"))
local BalanceLogger = require(script.Parent:WaitForChild("BalanceLogger"))
local RunStats = require(script.Parent:WaitForChild("RunStats"))
local GameSpeed = require(game.ReplicatedStorage:WaitForChild("GameSpeed"))
local DevSettings = require(game.ReplicatedStorage:WaitForChild("DevSettings"))
local TowerData = require(game.ReplicatedStorage:WaitForChild("TowerData"))
local TowerUpgradesData = require(game.ReplicatedStorage:WaitForChild("TowerUpgrades"))
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local towersFolder = ReplicatedStorage:WaitForChild("Towers")

local roundsFolder = workspace:WaitForChild("Rounds")
local waypoint = workspace:WaitForChild("Waypoint")
local placedTowersFolder = workspace:FindFirstChild("PlacedTowers")

if not placedTowersFolder then
	placedTowersFolder = Instance.new("Folder")
	placedTowersFolder.Name = "PlacedTowers"
	placedTowersFolder.Parent = workspace
end

local currentRound = 0
local TIMER_DURATION = 90
local TESTING = false
if TESTING then TIMER_DURATION = 5 end
local gameOver = false
local roundLeaks = 0
local roundEnding = false
local roundOverrideInProgress = false
local manualRoundStarted = false
local skipRequested = false
local canSkipCountdown = false
ReplicatedStorage:SetAttribute("CountdownActive", false)
ReplicatedStorage:SetAttribute("RoundActive", false)
ReplicatedStorage:SetAttribute("IntermissionActive", false)
local FIRST_TANK_ROUND = 18
local bossIntroPlayed = false
local ROUND_ONE_DIALOGUE_LOCK_TIME = 8.1
local ROUND_ONE_DIALOGUE_TEXT = "You made it through the first test. Don't get too comfortable."
local FIRST_BOSS_DIALOGUE_TEXT = "Ah... Here it comes. Your first real battle. Try not to embarrass yourself."
local FIRST_STONETHING_WIN_DIALOGUE_TEXT = "Maybe you're not completely hopeless."
local FIRST_STONETHING_WIN_DIALOGUE_SOUND_ID = "rbxassetid://122735084302229"
local PRE_FIRST_TANK_ROUND = FIRST_TANK_ROUND - 1
local PRE_FIRST_TANK_REWARD_MULTIPLIER = 2.5
local POST_FIRST_TANK_REWARD_ROUND = FIRST_TANK_ROUND + 1
local POST_FIRST_TANK_CASH_MULTIPLIER = 1.5
local POST_FIRST_TANK_RESOURCE_MULTIPLIER = 2.5
local BEGINNER_SINGLE_SPAWN_LAST_ROUND = 4
local BEGINNER_SPAWN_ICON = "rbxassetid://111283208192902"
local SILKSCREEN_FONT = "rbxassetid://12187371840"
local BEGINNER_SPAWN_INDICATOR_NAME = "BeginnerSpawnIndicator"
local BOSS_SPAWN_INDICATOR_NAME = "BossSpawnIndicator"
local spawns = {}
local serverFrameSamples = {}
local pendingPerformanceRequests = {}

RunService.Heartbeat:Connect(function(dt)
	local now = os.clock()
	table.insert(serverFrameSamples, {
		time = now,
		dt = dt,
	})

	while #serverFrameSamples > 0 and now - serverFrameSamples[1].time > 15 do
		table.remove(serverFrameSamples, 1)
	end
end)

local function getServerPerformanceSummary()
	local sampleCount = #serverFrameSamples
	if sampleCount == 0 then
		return {
			samples = 0,
			avgMs = 0,
			worstMs = 0,
			avgFps = 0,
			worstFps = 0,
			diagnosis = "warming up",
		}
	end

	local totalDt = 0
	local worstDt = 0
	for _, sample in ipairs(serverFrameSamples) do
		totalDt += sample.dt
		if sample.dt > worstDt then
			worstDt = sample.dt
		end
	end

	local avgDt = totalDt / sampleCount
	local avgFps = avgDt > 0 and (1 / avgDt) or 0
	local worstFps = worstDt > 0 and (1 / worstDt) or 0
	local diagnosis = "healthy"
	if avgDt > 0.05 or worstDt > 0.12 then
		diagnosis = "bad spikes"
	elseif avgDt > 0.028 or worstDt > 0.07 then
		diagnosis = "strained"
	end

	return {
		samples = sampleCount,
		avgMs = avgDt * 1000,
		worstMs = worstDt * 1000,
		avgFps = avgFps,
		worstFps = worstFps,
		diagnosis = diagnosis,
	}
end

local function refreshSpawns()
	table.clear(spawns)

	for _, child in ipairs(roundsFolder:GetChildren()) do
		if child:IsA("BasePart") then
			table.insert(spawns, child)
		end
	end

	table.sort(spawns, function(a, b)
		return a.Name < b.Name
	end)
end

local function getBeginnerSpawnForRound(round)
	if round < 1 or round > BEGINNER_SINGLE_SPAWN_LAST_ROUND or #spawns == 0 then
		return nil
	end

	return spawns[((round - 1) % #spawns) + 1]
end

local function getBeginnerSpawnsForRound(round)
	if round < 1 or round > BEGINNER_SINGLE_SPAWN_LAST_ROUND or #spawns == 0 then
		return nil
	end

	local activeCount = math.min(round, #spawns)
	local activeSpawns = {}
	for index = 1, activeCount do
		table.insert(activeSpawns, spawns[index])
	end

	return activeSpawns
end

local function clearBeginnerSpawnIndicators()
	for _, spawnPart in ipairs(spawns) do
		local indicator = spawnPart:FindFirstChild(BEGINNER_SPAWN_INDICATOR_NAME)
		if indicator then
			indicator:Destroy()
		end
	end
end

local function clearBossSpawnIndicator()
	for _, spawnPart in ipairs(spawns) do
		local indicator = spawnPart:FindFirstChild(BOSS_SPAWN_INDICATOR_NAME)
		if indicator then
			indicator:Destroy()
		end
	end
end

local function ensureSpawnIndicator(spawnPart, indicatorName, imageColor, text, textColor, strokeColor)
	local existing = spawnPart:FindFirstChild(indicatorName)
	if existing then
		existing:Destroy()
	end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = indicatorName
	billboard.Adornee = spawnPart
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.MaxDistance = 250
	billboard.Size = UDim2.fromOffset(96, 116)
	billboard.SizeOffset = Vector2.new(0, 0)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 5, 0)
	billboard.Parent = spawnPart

	local icon = Instance.new("ImageLabel")
	icon.Name = "Icon"
	icon.BackgroundTransparency = 1
	icon.BorderSizePixel = 0
	icon.Position = UDim2.fromOffset(16, 0)
	icon.Size = UDim2.fromOffset(64, 64)
	icon.Image = BEGINNER_SPAWN_ICON
	icon.ImageColor3 = imageColor
	icon.ScaleType = Enum.ScaleType.Fit
	icon.Parent = billboard

	local label = Instance.new("TextLabel")
	label.Name = "WarningText"
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.Position = UDim2.fromOffset(0, 68)
	label.Size = UDim2.fromOffset(96, 44)
	label.FontFace = Font.new(SILKSCREEN_FONT, Enum.FontWeight.Bold)
	label.Text = text
	label.TextColor3 = textColor
	label.TextStrokeColor3 = strokeColor
	label.TextStrokeTransparency = 0.15
	label.TextScaled = true
	label.TextWrapped = true
	label.Parent = billboard

	return billboard
end

local function showBeginnerSpawnIndicatorForRound(round)
	if round > BEGINNER_SINGLE_SPAWN_LAST_ROUND then
		clearBeginnerSpawnIndicators()
		return
	end

	local activeSpawns = getBeginnerSpawnsForRound(round)
	if not activeSpawns then
		return
	end

	for _, spawnPart in ipairs(activeSpawns) do
		ensureSpawnIndicator(
			spawnPart,
			BEGINNER_SPAWN_INDICATOR_NAME,
			Color3.new(1, 1, 1),
			"DEFEND THIS PATH!",
			Color3.fromRGB(255, 44, 36),
			Color3.fromRGB(54, 0, 0)
		)
	end
end

local function showBossSpawnIndicator()
	local spawnPart = spawns[1]
	if not spawnPart then
		return
	end

	ensureSpawnIndicator(
		spawnPart,
		BOSS_SPAWN_INDICATOR_NAME,
		Color3.fromRGB(255, 30, 30),
		"BOSS SPAWNING HERE",
		Color3.fromRGB(255, 34, 26),
		Color3.fromRGB(45, 0, 0)
	)
end

refreshSpawns()

local ROUND_REWARD = {
	stone = 12,
	metal = 2,
	crystal = 3,
}

local function getRoundResourceReward(amount, round)
	if round == PRE_FIRST_TANK_ROUND then
		return math.ceil(amount * PRE_FIRST_TANK_REWARD_MULTIPLIER)
	end

	if round == POST_FIRST_TANK_REWARD_ROUND then
		return math.ceil(amount * POST_FIRST_TANK_RESOURCE_MULTIPLIER)
	end

	return amount
end

local function getRoundCashReward(round)
	local amount = 500 + (round * 100)

	if round == PRE_FIRST_TANK_ROUND then
		return math.ceil(amount * PRE_FIRST_TANK_REWARD_MULTIPLIER)
	end

	if round == POST_FIRST_TANK_REWARD_ROUND then
		return math.ceil(amount * POST_FIRST_TANK_CASH_MULTIPLIER)
	end

	return amount
end

local ROUND_WARNINGS = {
	[4] = "Fast enemies are entering the cave.",
	[9] = "Support enemies are joining the wave.",
}

local skipIntermissionRemote = ReplicatedStorage:FindFirstChild("SkipIntermissionRemote")
if skipIntermissionRemote and not skipIntermissionRemote:IsA("RemoteEvent") then
	skipIntermissionRemote:Destroy()
	skipIntermissionRemote = nil
end

if not skipIntermissionRemote then
	skipIntermissionRemote = Instance.new("RemoteEvent")
	skipIntermissionRemote.Name = "SkipIntermissionRemote"
	skipIntermissionRemote.Parent = ReplicatedStorage
end

skipIntermissionRemote.OnServerEvent:Connect(function()
	if gameOver or not canSkipCountdown then
		return
	end

	skipRequested = true
end)

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

local function getTowerUpgradeCount(tower)
	local upgrades = 0

	for attributeName, value in pairs(tower:GetAttributes()) do
		if typeof(value) == "number" and string.match(attributeName, "^UpgradePath%d+Level$") then
			upgrades += math.max(0, math.floor(value))
		end
	end

	return upgrades
end

local function getTowerTypeName(tower)
	local typeTag = tower:FindFirstChild("TowerType")
	if typeTag and typeTag:IsA("StringValue") then
		return typeTag.Value
	end

	return tower.Name
end

local function getPlayerTowerSnapshot(player)
	local towerCount = 0
	local upgradeCount = 0
	local towerTypes = {}

	for _, tower in ipairs(placedTowersFolder:GetChildren()) do
		local typeTag = tower:FindFirstChild("TowerType")
		if typeTag and typeTag:IsA("StringValue") then
			local ownerUserId = getTowerOwnerId(tower)
			if ownerUserId == nil or ownerUserId == player.UserId then
				towerCount += 1
				upgradeCount += getTowerUpgradeCount(tower)

				local towerType = getTowerTypeName(tower)
				towerTypes[towerType] = (towerTypes[towerType] or 0) + 1
			end
		end
	end

	local towerParts = {}
	for towerType, count in pairs(towerTypes) do
		table.insert(towerParts, string.format("%s x%d", towerType, count))
	end
	table.sort(towerParts)

	return towerCount, upgradeCount, table.concat(towerParts, ", ")
end

local function printFairnessDebug()
	print(string.format("[Balance] Round %d debug", currentRound))

	for _, player in ipairs(Players:GetPlayers()) do
		local towerCount, upgradeCount, towerSummary = getPlayerTowerSnapshot(player)
		if towerSummary == "" then
			towerSummary = "none"
		end

		print(string.format(
			"[Balance] Player=%s Round=%d Towers=%d (%s) Upgrades=%d Cash=%d Resources stone=%d crystal=%d metal=%d Leaks=%d Feel=fill manually: easy/fair/but",
			player.Name,
			currentRound,
			towerCount,
			towerSummary,
			upgradeCount,
			CashService:Get(player),
			ResourceService:Get(player, "stone"),
			ResourceService:Get(player, "crystal"),
			ResourceService:Get(player, "metal"),
			roundLeaks
		))

		for _, line in ipairs(BalanceLogger:GetSummaryLines(player)) do
			print(line)
		end
	end
end

local function giveRoundRewards()
	for _, player in ipairs(Players:GetPlayers()) do
		local rewardParts = {}
		local rewardResources = {
			stone = 0,
			crystal = 0,
			metal = 0,
		}

		for resourceType, amount in pairs(ROUND_REWARD) do
			local granted = ResourceService:Add(player, resourceType, getRoundResourceReward(amount, currentRound))
			rewardResources[resourceType] = granted
			table.insert(rewardParts, string.format("%s=+%d", resourceType, granted))
		end

		local cashGranted = CashService:Add(player, getRoundCashReward(currentRound))
		BalanceLogger:RecordRoundReward(player, cashGranted, rewardResources)

		print(string.format(
			"[Economy] Round %d reward for %s: cash=+%d %s",
			currentRound,
			player.Name,
			cashGranted,
			table.concat(rewardParts, " ")
		))
	end
end

local function countdown()
	skipRequested = false
	canSkipCountdown = true
	ReplicatedStorage:SetAttribute("CountdownActive", true)
	ReplicatedStorage:SetAttribute("RoundActive", false)
	ReplicatedStorage:SetAttribute("IntermissionActive", false)
	TimerRemote:FireAllClients("ShowTimer")
	TimerRemote:FireAllClients("ShowSkip")
	for i = TIMER_DURATION, 0, -1 do
		if gameOver then return end
		if skipRequested then break end
		TimerRemote:FireAllClients("Tick", i, TIMER_DURATION)
		task.wait(GameSpeed:ScaleDuration(1))
	end
	canSkipCountdown = false
	skipRequested = false
	ReplicatedStorage:SetAttribute("CountdownActive", false)
	ReplicatedStorage:SetAttribute("RoundActive", true)
	ReplicatedStorage:SetAttribute("IntermissionActive", false)
	TimerRemote:FireAllClients("RoundStartClose")
	task.wait(GameSpeed:ScaleDuration(0.48))
end

local function intermission()
	if gameOver then return end
	ReplicatedStorage:SetAttribute("CountdownActive", false)
	ReplicatedStorage:SetAttribute("RoundActive", false)
	ReplicatedStorage:SetAttribute("IntermissionActive", true)
	local nextRound = currentRound + 1
	refreshSpawns()
	showBeginnerSpawnIndicatorForRound(nextRound)

	if nextRound >= PRE_FIRST_TANK_ROUND and nextRound <= FIRST_TANK_ROUND then
		showBossSpawnIndicator()
	end

	TimerRemote:FireAllClients("ShowPanel1")
	TimerRemote:FireAllClients("ShowPanel2")
	TimerRemote:FireAllClients("ShowInfo")
	TimerRemote:FireAllClients("ShowTime")
	TimerRemote:FireAllClients("Tick", TIMER_DURATION, TIMER_DURATION)
	if nextRound == FIRST_TANK_ROUND then
		DialogueService:FireAllClients(FIRST_BOSS_DIALOGUE_TEXT)
		task.wait(ROUND_ONE_DIALOGUE_LOCK_TIME)
	end
	if ROUND_WARNINGS[nextRound] then
		WarningRemote:FireAllClients("Show", ROUND_WARNINGS[nextRound], "Round")
	end
	task.wait(GameSpeed:ScaleDuration(0.5))
end

local function startRound()
	if gameOver then return end
	ReplicatedStorage:SetAttribute("CountdownActive", false)
	ReplicatedStorage:SetAttribute("RoundActive", true)
	ReplicatedStorage:SetAttribute("IntermissionActive", false)
	currentRound += 1
	refreshSpawns()
	roundLeaks = 0
	roundEnding = false
	WarningRemote:FireAllClients("Hide")

	local roundSpawns = spawns
	local beginnerSpawns = getBeginnerSpawnsForRound(currentRound)
	if beginnerSpawns then
		roundSpawns = beginnerSpawns
	elseif currentRound > BEGINNER_SINGLE_SPAWN_LAST_ROUND then
		clearBeginnerSpawnIndicators()
	end

	if currentRound > FIRST_TANK_ROUND then
		clearBossSpawnIndicator()
	end

	if currentRound == FIRST_TANK_ROUND and not bossIntroPlayed then
		bossIntroPlayed = true
		BossAnimRemote:FireAllClients()
	end

	Comm:Fire("RoundStart", {
		round = currentRound,
		spawns = roundSpawns,
		waypoint = waypoint,
	})
	RunStats:RecordRoundStarted()
end

local function sendSystemMessage(player, text)
	if not player or player.Parent ~= Players then
		return
	end

	CustomChatRemote:FireClient(player, {
		kind = "system",
		text = text,
	})
end

local function findClosestPlayer(query)
	if typeof(query) ~= "string" or query == "" then
		return nil
	end

	local needle = string.lower(query)
	local bestPlayer = nil
	local bestScore = math.huge

	for _, candidate in ipairs(Players:GetPlayers()) do
		local names = {
			string.lower(candidate.Name),
			string.lower(candidate.DisplayName),
		}

		for _, name in ipairs(names) do
			local score = math.huge
			if name == needle then
				score = 0
			elseif string.sub(name, 1, #needle) == needle then
				score = 1 + (#name - #needle) * 0.01
			elseif string.find(name, needle, 1, true) then
				score = 2 + (#name - #needle) * 0.01
			end

			if score < bestScore then
				bestScore = score
				bestPlayer = candidate
			end
		end
	end

	return bestPlayer
end

local function getCharacterRoot(player)
	local character = player and player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function getCharacterHumanoid(player)
	local character = player and player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

local function flingPlayer(target, power)
	local root = getCharacterRoot(target)
	if not root then
		return false
	end

	local strength = tonumber(power) or 180
	root.AssemblyLinearVelocity = Vector3.new(
		math.random(-strength, strength),
		strength * 1.35,
		math.random(-strength, strength)
	)
	return true
end

local function spinPlayer(target, seconds)
	local root = getCharacterRoot(target)
	if not root then
		return false
	end

	root.AssemblyAngularVelocity = Vector3.new(0, 80, 0)
	task.delay(tonumber(seconds) or 3, function()
		if root and root.Parent then
			root.AssemblyAngularVelocity = Vector3.zero
		end
	end)
	return true
end

local function sitPlayer(target)
	local humanoid = getCharacterHumanoid(target)
	if not humanoid then
		return false
	end

	humanoid.Sit = true
	return true
end

local function popPlayer(target)
	local root = getCharacterRoot(target)
	if not root then
		return false
	end

	local explosion = Instance.new("Explosion")
	explosion.BlastPressure = 0
	explosion.BlastRadius = 0
	explosion.DestroyJointRadiusPercent = 0
	explosion.Position = root.Position
	explosion.Parent = workspace
	return true
end

local function parseToggle(text, currentValue)
	if text == "on" or text == "true" or text == "1" then
		return true
	end

	if text == "off" or text == "false" or text == "0" then
		return false
	end

	return not currentValue
end

local function normalizeCheatMethod(methodText)
	local method = math.floor(tonumber(methodText) or 1)
	if method < 1 or method > 10 then
		return 1
	end

	return method
end

local function parseCheatMethodAndValue(methodText, valueText, defaultValue)
	local firstNumber = tonumber(methodText)
	if firstNumber and firstNumber > 10 and (not valueText or valueText == "") then
		return 1, firstNumber
	end

	return normalizeCheatMethod(methodText), tonumber(valueText) or defaultValue
end

local function getRootAndHumanoid(player)
	local root = getCharacterRoot(player)
	local humanoid = getCharacterHumanoid(player)
	return root, humanoid
end

local function repeatCheat(duration, interval, callback)
	task.spawn(function()
		local startedAt = os.clock()
		while os.clock() - startedAt < duration do
			if callback() == false then
				return
			end
			task.wait(interval)
		end
	end)
end

local function addAttachmentMover(root, className, vector)
	local attachment = Instance.new("Attachment")
	attachment.Name = "CheatTestAttachment"
	attachment.Parent = root
	game:GetService("Debris"):AddItem(attachment, 4)

	if className == "LinearVelocity" then
		local mover = Instance.new("LinearVelocity")
		mover.Name = "CheatTestLinearVelocity"
		mover.Attachment0 = attachment
		mover.MaxForce = math.huge
		mover.VectorVelocity = vector
		mover.Parent = root
		game:GetService("Debris"):AddItem(mover, 4)
	elseif className == "VectorForce" then
		local mover = Instance.new("VectorForce")
		mover.Name = "CheatTestVectorForce"
		mover.Attachment0 = attachment
		mover.Force = vector
		mover.RelativeTo = Enum.ActuatorRelativeTo.World
		mover.Parent = root
		game:GetService("Debris"):AddItem(mover, 4)
	elseif className == "AlignPosition" then
		local mover = Instance.new("AlignPosition")
		mover.Name = "CheatTestAlignPosition"
		mover.Attachment0 = attachment
		mover.MaxForce = math.huge
		mover.Responsiveness = 200
		mover.Position = root.Position + vector
		mover.Parent = root
		game:GetService("Debris"):AddItem(mover, 4)
	end
end

local function setCharacterCollision(character, value)
	for _, descendant in ipairs(character:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.CanCollide = value
		end
	end
end

local function teleportForward(root, distance)
	root.CFrame += root.CFrame.LookVector * distance
end

local function getForwardVector(root, speed, y)
	local forward = root.CFrame.LookVector
	return Vector3.new(forward.X * speed, y or 0, forward.Z * speed)
end

local function mineNearestResourceCheat(player, damage, repeatCount)
	local root = getCharacterRoot(player)
	if not root then
		return false
	end

	local resource = ResourceMiningService:GetNearestResource(root.Position, 80)
	if not resource then
		return false
	end

	for _ = 1, repeatCount or 1 do
		ResourceMiningService:Mine(resource, player, damage, { manual = true })
	end

	return true
end

local function testFly(player, method)
	local root, humanoid = getRootAndHumanoid(player)
	if not root then
		return false
	end

	method = normalizeCheatMethod(method)
	if method == 1 then
		repeatCheat(2.5, 0.08, function()
			local currentRoot = getCharacterRoot(player)
			if not currentRoot then return false end
			local velocity = currentRoot.AssemblyLinearVelocity
			currentRoot.AssemblyLinearVelocity = Vector3.new(velocity.X, 115, velocity.Z)
		end)
	elseif method == 2 then
		repeatCheat(1.2, 0.05, function()
			local currentRoot = getCharacterRoot(player)
			if not currentRoot then return false end
			currentRoot.CFrame += Vector3.new(0, 5, 0)
		end)
	elseif method == 3 then
		root.CFrame += Vector3.new(0, 35, 0)
		repeatCheat(2.2, 0.08, function()
			local currentRoot = getCharacterRoot(player)
			if not currentRoot then return false end
			currentRoot.AssemblyLinearVelocity = Vector3.zero
		end)
	elseif method == 4 then
		repeatCheat(1.5, 0.06, function()
			local currentRoot = getCharacterRoot(player)
			if not currentRoot then return false end
			currentRoot.AssemblyLinearVelocity = getForwardVector(currentRoot, 35, 105)
		end)
	elseif method == 5 then
		repeatCheat(1.4, 0.04, function()
			local currentRoot = getCharacterRoot(player)
			if not currentRoot then return false end
			currentRoot.CFrame += Vector3.new(0, 2.8, 0) + (currentRoot.CFrame.LookVector * 1.4)
		end)
	elseif method == 6 then
		local mover = Instance.new("BodyVelocity")
		mover.Name = "CheatTestBodyVelocity"
		mover.MaxForce = Vector3.new(100000, 100000, 100000)
		mover.Velocity = Vector3.new(0, 95, 0)
		mover.Parent = root
		game:GetService("Debris"):AddItem(mover, 4)
	elseif method == 7 then
		addAttachmentMover(root, "LinearVelocity", Vector3.new(0, 95, 0))
	elseif method == 8 then
		addAttachmentMover(root, "VectorForce", Vector3.new(0, root.AssemblyMass * workspace.Gravity * 4, 0))
	elseif method == 9 then
		addAttachmentMover(root, "AlignPosition", Vector3.new(0, 80, 0))
	elseif method == 10 then
		if humanoid then
			humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
		end
		root.CFrame += Vector3.new(0, 90, 0)
	end

	return true
end

local function testNoclip(player, method)
	local character = player.Character
	local root = getCharacterRoot(player)
	if not character or not root then
		return false
	end

	method = normalizeCheatMethod(method)
	if method == 1 then
		setCharacterCollision(character, false)
		teleportForward(root, 28)
	elseif method == 2 then
		teleportForward(root, 42)
	elseif method == 3 then
		setCharacterCollision(character, false)
		repeatCheat(1.1, 0.05, function()
			local currentRoot = getCharacterRoot(player)
			if not currentRoot then return false end
			teleportForward(currentRoot, 3.5)
		end)
	elseif method == 4 then
		character:PivotTo(root.CFrame + (root.CFrame.LookVector * 35))
	elseif method == 5 then
		setCharacterCollision(character, false)
		root.AssemblyLinearVelocity = getForwardVector(root, 140, 0)
	elseif method == 6 then
		root.CanCollide = false
		teleportForward(root, 25)
	elseif method == 7 then
		setCharacterCollision(character, false)
		root.CFrame += (root.CFrame.RightVector * 30)
	elseif method == 8 then
		setCharacterCollision(character, false)
		if getCharacterHumanoid(player) then
			getCharacterHumanoid(player):ChangeState(Enum.HumanoidStateType.Physics)
		end
		teleportForward(root, 35)
	elseif method == 9 then
		root.CFrame += getForwardVector(root, 22, 0)
	elseif method == 10 then
		local result = workspace:Raycast(root.Position, root.CFrame.LookVector * 120)
		if result then
			root.CFrame = CFrame.new(result.Position + (root.CFrame.LookVector * 8), result.Position + (root.CFrame.LookVector * 18))
		else
			teleportForward(root, 50)
		end
	end

	return true
end

local function testWalkspeed(player, method, speed)
	local root, humanoid = getRootAndHumanoid(player)
	if not root or not humanoid then
		return false
	end

	method = normalizeCheatMethod(method)
	local amount = tonumber(speed) or 80
	if method == 1 then
		humanoid.WalkSpeed = amount
	elseif method == 2 then
		repeatCheat(2, 0.1, function()
			local currentHumanoid = getCharacterHumanoid(player)
			if not currentHumanoid then return false end
			currentHumanoid.WalkSpeed = amount
		end)
	elseif method == 3 then
		root.AssemblyLinearVelocity = getForwardVector(root, amount * 2, root.AssemblyLinearVelocity.Y)
	elseif method == 4 then
		repeatCheat(1.1, 0.05, function()
			local currentRoot = getCharacterRoot(player)
			if not currentRoot then return false end
			teleportForward(currentRoot, 3.8)
		end)
	elseif method == 5 then
		local mover = Instance.new("BodyVelocity")
		mover.Name = "CheatTestRunBodyVelocity"
		mover.MaxForce = Vector3.new(100000, 0, 100000)
		mover.Velocity = getForwardVector(root, amount * 1.8, 0)
		mover.Parent = root
		game:GetService("Debris"):AddItem(mover, 4)
	elseif method == 6 then
		addAttachmentMover(root, "LinearVelocity", getForwardVector(root, amount * 1.8, 0))
	elseif method == 7 then
		addAttachmentMover(root, "VectorForce", getForwardVector(root, root.AssemblyMass * 650, 0))
	elseif method == 8 then
		humanoid.WalkSpeed = amount
		humanoid:Move(root.CFrame.LookVector, false)
	elseif method == 9 then
		root.AssemblyLinearVelocity = getForwardVector(root, amount * 1.4, 55)
	elseif method == 10 then
		repeatCheat(0.8, 0.08, function()
			local currentRoot = getCharacterRoot(player)
			if not currentRoot then return false end
			teleportForward(currentRoot, 8)
		end)
	end

	return true
end

local function testJumpBoost(player, method, power)
	local root, humanoid = getRootAndHumanoid(player)
	if not root or not humanoid then
		return false
	end

	method = normalizeCheatMethod(method)
	local amount = tonumber(power) or 140
	if method == 1 and humanoid.UseJumpPower then
		humanoid.JumpPower = amount
	elseif method == 1 then
		humanoid.JumpHeight = math.max(7.2, amount / 10)
	elseif method == 2 then
		humanoid.JumpHeight = math.max(7.2, amount / 10)
	elseif method == 3 then
		root.AssemblyLinearVelocity = Vector3.new(root.AssemblyLinearVelocity.X, amount, root.AssemblyLinearVelocity.Z)
	elseif method == 4 then
		root.CFrame += Vector3.new(0, amount / 3, 0)
	elseif method == 5 then
		humanoid.Jump = true
		humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
		root.AssemblyLinearVelocity = Vector3.new(0, amount, 0)
	elseif method == 6 then
		local mover = Instance.new("BodyVelocity")
		mover.Name = "CheatTestJumpBodyVelocity"
		mover.MaxForce = Vector3.new(0, 100000, 0)
		mover.Velocity = Vector3.new(0, amount, 0)
		mover.Parent = root
		game:GetService("Debris"):AddItem(mover, 4)
	elseif method == 7 then
		addAttachmentMover(root, "LinearVelocity", Vector3.new(0, amount, 0))
	elseif method == 8 then
		addAttachmentMover(root, "VectorForce", Vector3.new(0, root.AssemblyMass * workspace.Gravity * 5, 0))
	elseif method == 9 then
		repeatCheat(1.4, 0.08, function()
			local currentRoot = getCharacterRoot(player)
			if not currentRoot then return false end
			currentRoot.AssemblyLinearVelocity = Vector3.new(0, amount * 0.8, 0)
		end)
	elseif method == 10 then
		humanoid.PlatformStand = true
		root.AssemblyLinearVelocity = Vector3.new(0, amount, 0)
	end

	return true
end

local function testPhase(player, method, studs)
	local root = getCharacterRoot(player)
	if not root then
		return false
	end

	method = normalizeCheatMethod(method)
	local distance = tonumber(studs) or 30
	if method == 1 then
		teleportForward(root, distance)
	elseif method == 2 then
		root.CFrame += root.CFrame.RightVector * distance
	elseif method == 3 then
		root.CFrame += Vector3.new(0, distance, 0)
	elseif method == 4 then
		repeatCheat(1, 0.05, function()
			local currentRoot = getCharacterRoot(player)
			if not currentRoot then return false end
			teleportForward(currentRoot, distance / 10)
		end)
	elseif method == 5 then
		root.CFrame += root.CFrame.LookVector * distance + Vector3.new(0, 10, 0)
	elseif method == 6 then
		root.AssemblyLinearVelocity = getForwardVector(root, distance * 5, 0)
	elseif method == 7 then
		local character = player.Character
		if character then
			character:PivotTo(root.CFrame + (root.CFrame.LookVector * distance))
		end
	elseif method == 8 then
		addAttachmentMover(root, "AlignPosition", root.CFrame.LookVector * distance)
	elseif method == 9 then
		root.CFrame = CFrame.new(root.Position + Vector3.new(distance, 0, distance), root.Position + Vector3.new(distance + 1, 0, distance))
	elseif method == 10 then
		root.CFrame += root.CFrame.LookVector * distance * 2
	end

	return true
end

local function testInstamine(player, method)
	method = normalizeCheatMethod(method)
	if method == 1 then
		player:SetAttribute("PickaxeStrength", 999)
	elseif method == 2 then
		repeatCheat(2, 0.08, function()
			if player.Parent ~= Players then return false end
			player:SetAttribute("PickaxeStrength", 999)
		end)
	elseif method == 3 then
		return mineNearestResourceCheat(player, 999, 1)
	elseif method == 4 then
		return mineNearestResourceCheat(player, 999, 8)
	elseif method == 5 then
		player:SetAttribute("PickaxeStrength", 999)
		return mineNearestResourceCheat(player, 999, 1)
	elseif method == 6 then
		player:SetAttribute("ResourceMultiplier", 999)
		player:SetAttribute("PickaxeStrength", 999)
	elseif method == 7 then
		task.delay(0.25, function()
			if player.Parent == Players then
				player:SetAttribute("PickaxeStrength", 999)
			end
		end)
	elseif method == 8 then
		player:SetAttribute("PickaxeStrength", 1000000000)
	elseif method == 9 then
		player:SetAttribute("PickaxeStrength", 250)
		repeatCheat(1, 0.1, function()
			return mineNearestResourceCheat(player, 250, 1)
		end)
	elseif method == 10 then
		player:SetAttribute("PickaxeStrength", 999)
		player:SetAttribute("ResourceMultiplier", 999)
		return mineNearestResourceCheat(player, 999, 3)
	end

	return true
end

local function testResourceBoost(player, method, multiplier)
	method = normalizeCheatMethod(method)
	local amount = tonumber(multiplier) or 999
	if method == 1 then
		player:SetAttribute("ResourceMultiplier", amount)
	elseif method == 2 then
		repeatCheat(2, 0.08, function()
			if player.Parent ~= Players then return false end
			player:SetAttribute("ResourceMultiplier", amount)
		end)
	elseif method == 3 then
		player:SetAttribute("ResourceMultiplier", 1000000000)
	elseif method == 4 then
		player:SetAttribute("ResourceMultiplier", 100)
		return mineNearestResourceCheat(player, 20, 1)
	elseif method == 5 then
		player:SetAttribute("PickaxeStrength", 999)
		player:SetAttribute("ResourceMultiplier", amount)
	elseif method == 6 then
		task.delay(0.25, function()
			if player.Parent == Players then
				player:SetAttribute("ResourceMultiplier", amount)
			end
		end)
	elseif method == 7 then
		player:SetAttribute("ResourceMultiplier", amount)
		return mineNearestResourceCheat(player, 999, 1)
	elseif method == 8 then
		repeatCheat(1.5, 0.12, function()
			if player.Parent ~= Players then return false end
			player:SetAttribute("PickaxeStrength", 999)
			player:SetAttribute("ResourceMultiplier", amount)
		end)
	elseif method == 9 then
		player:SetAttribute("ResourceMultiplier", amount * 10)
	elseif method == 10 then
		player:SetAttribute("ResourceMultiplier", amount)
		return mineNearestResourceCheat(player, 999, 5)
	end

	return true
end

local function getOwnedTower(player)
	local folder = workspace:FindFirstChild("PlacedTowers")
	if not folder then
		return nil
	end

	for _, tower in ipairs(folder:GetChildren()) do
		if tower:GetAttribute("OwnerUserId") == player.UserId then
			return tower
		end
	end

	return nil
end

local function getTowerInfo(towerName)
	local fallback = TowerData[1]
	for _, towerInfo in ipairs(TowerData) do
		if string.lower(towerInfo.name) == string.lower(towerName or "") then
			return towerInfo
		end
	end

	return fallback
end

local function spawnUntrustedTower(player, towerName, method)
	local root = getCharacterRoot(player)
	local towerInfo = getTowerInfo(towerName)
	local template = towerInfo and towersFolder:FindFirstChild(towerInfo.name)
	if not root or not template then
		return false
	end

	method = normalizeCheatMethod(method)
	local clone = template:Clone()
	local tag = clone:FindFirstChild("TowerType")
	if not tag then
		tag = Instance.new("StringValue")
		tag.Name = "TowerType"
		tag.Parent = clone
	end
	tag.Value = towerInfo.name

	clone:SetAttribute("OwnerUserId", player.UserId)
	if method == 2 then
		clone:SetAttribute("SpentStone", 0)
		clone:SetAttribute("SpentCrystal", 0)
		clone:SetAttribute("SpentMetal", 0)
	elseif method == 3 then
		clone:SetAttribute("OwnerUserId", -1)
	elseif method == 4 then
		clone.Name = towerInfo.name .. "_Injected"
	elseif method == 5 then
		clone:SetAttribute("UpgradePath1Level", 5)
	elseif method >= 6 then
		clone:SetAttribute("SpentCash", 999999)
	end

	local position = root.Position + root.CFrame.LookVector * (8 + method)
	if clone:IsA("Model") then
		clone:PivotTo(CFrame.new(position))
	elseif clone:IsA("BasePart") then
		clone.CFrame = CFrame.new(position)
	end
	clone.Parent = placedTowersFolder
	return true
end

local function testForceUpgrade(player, method)
	local tower = getOwnedTower(player)
	if not tower then
		return false
	end

	method = normalizeCheatMethod(method)
	local pathIndex = ((method - 1) % 3) + 1
	if method <= 3 then
		tower:SetAttribute("UpgradePath" .. pathIndex .. "Level", 5)
	elseif method <= 6 then
		tower:SetAttribute("UpgradePath" .. pathIndex .. "Level", 999)
	else
		for i = 1, 3 do
			tower:SetAttribute("UpgradePath" .. i .. "Level", 5)
		end
	end

	return true
end

local function testCashCheat(player, method, amount)
	method = normalizeCheatMethod(method)
	amount = tonumber(amount) or 999999
	if method == 1 then
		player:SetAttribute("cash", amount)
	elseif method == 2 then
		player:SetAttribute("cash", 1000000000)
	elseif method == 3 then
		repeatCheat(1.5, 0.08, function()
			if player.Parent ~= Players then return false end
			player:SetAttribute("cash", amount)
		end)
	elseif method == 4 then
		player:SetAttribute("cash", -100)
	else
		player:SetAttribute("cash", amount * method)
	end
	return true
end

local function testResourceCheat(player, method, amount)
	method = normalizeCheatMethod(method)
	amount = tonumber(amount) or 9999
	local resourceTypes = { "stone", "crystal", "metal" }
	if method <= 3 then
		player:SetAttribute(resourceTypes[method], amount)
	elseif method <= 6 then
		for _, resourceType in ipairs(resourceTypes) do
			player:SetAttribute(resourceType, amount)
		end
	elseif method <= 8 then
		repeatCheat(1.5, 0.08, function()
			if player.Parent ~= Players then return false end
			for _, resourceType in ipairs(resourceTypes) do
				player:SetAttribute(resourceType, amount)
			end
		end)
	else
		for _, resourceType in ipairs(resourceTypes) do
			player:SetAttribute(resourceType, 1000000000)
		end
	end
	return true
end

local function testRefundCheat(player, method)
	local tower = getOwnedTower(player)
	if not tower then
		return false
	end

	method = normalizeCheatMethod(method)
	if method <= 3 then
		tower:SetAttribute("SpentCash", 999999)
	elseif method <= 6 then
		tower:SetAttribute("SpentStone", 9999)
		tower:SetAttribute("SpentCrystal", 9999)
		tower:SetAttribute("SpentMetal", 9999)
	else
		tower:SetAttribute("SpentCash", 999999)
		tower:SetAttribute("SpentStone", 9999)
		tower:SetAttribute("SpentCrystal", 9999)
		tower:SetAttribute("SpentMetal", 9999)
	end
	return true
end

local function testOwnerCheat(player, method)
	local tower = getOwnedTower(player)
	if not tower then
		return false
	end

	method = normalizeCheatMethod(method)
	if method == 1 then
		tower:SetAttribute("OwnerUserId", -1)
	elseif method == 2 then
		tower:SetAttribute("OwnerUserId", 0)
	elseif method == 3 then
		tower:SetAttribute("OwnerUserId", player.UserId + 1)
	elseif method <= 6 then
		local ownerValue = tower:FindFirstChild("OwnerUserId")
		if ownerValue and ownerValue:IsA("IntValue") then
			ownerValue.Value = -1
		else
			ownerValue = Instance.new("IntValue")
			ownerValue.Name = "OwnerUserId"
			ownerValue.Value = -1
			ownerValue.Parent = tower
		end
	else
		tower:SetAttribute("OwnerUserId", 1000000000)
	end
	return true
end

local function testStatBoost(player, method)
	if not RunStats:DevTamper(player, method) then
		return false
	end

	local summary = RunStats:GetGameOverSummary(player)
	return summary ~= nil
end

local function trim(text)
	return string.gsub(text or "", "^%s*(.-)%s*$", "%1")
end

local function parseOptionalPlayerAndAmount(rest, defaultPlayer, defaultAmount)
	rest = trim(rest)
	if rest == "" then
		return defaultPlayer, defaultAmount
	end

	local first, second = string.match(rest, "^(%S+)%s*([%-]?%d*%.?%d*)$")
	if not first then
		return defaultPlayer, defaultAmount
	end

	local firstNumber = tonumber(first)
	if firstNumber then
		return defaultPlayer, firstNumber
	end

	local targetPlayer = findClosestPlayer(first)
	if not targetPlayer then
		return nil, defaultAmount
	end

	return targetPlayer, tonumber(second) or defaultAmount
end

local function addAllResources(player, amount)
	ResourceService:AddDev(player, "stone", amount)
	ResourceService:AddDev(player, "crystal", amount)
	ResourceService:AddDev(player, "metal", amount)
end

local function normalizeTowerName(text)
	return string.lower(string.gsub(trim(text), "%s+", " "))
end

local function findTowerTypeByQuery(query)
	local normalizedQuery = normalizeTowerName(query)
	if normalizedQuery == "" then
		return nil
	end

	local bestName = nil
	local bestScore = math.huge
	for _, towerInfo in ipairs(TowerData) do
		local towerName = towerInfo.name
		local normalizedName = normalizeTowerName(towerName)
		local startsAt = string.find(normalizedName, normalizedQuery, 1, true)
		if startsAt then
			local score = startsAt + (math.abs(#normalizedName - #normalizedQuery) * 0.05)
			if score < bestScore then
				bestScore = score
				bestName = towerName
			end
		end
	end

	return bestName
end

local function massUpgradeTowers(towerNameQuery, pathIndex)
	local towerType = findTowerTypeByQuery(towerNameQuery)
	if not towerType then
		return 0, "No tower type matched '" .. tostring(towerNameQuery) .. "'."
	end

	local upgradeData = TowerUpgradesData[towerType]
	local path = upgradeData and upgradeData.paths and upgradeData.paths[pathIndex] or nil
	if not path then
		return 0, towerType .. " has no path " .. tostring(pathIndex) .. "."
	end

	local upgraded = 0
	local skippedMaxed = 0
	for _, tower in ipairs(placedTowersFolder:GetChildren()) do
		if getTowerTypeName(tower) == towerType then
			local currentLevel = math.max(0, math.floor(tower:GetAttribute("UpgradePath" .. pathIndex .. "Level") or 0))
			local nextLevel = currentLevel + 1
			local upgradeEntry = path.upgrades[nextLevel]
			if upgradeEntry then
				upgradeEntry.apply(tower)
				tower:SetAttribute("UpgradePath" .. pathIndex .. "Level", nextLevel)
				tower:SetAttribute("TrustedUpgradePath" .. pathIndex .. "Level", nextLevel)
				tower:SetAttribute("TowerStateVersion", (tower:GetAttribute("TowerStateVersion") or 0) + 1)
				upgraded += 1
			else
				skippedMaxed += 1
			end
		end
	end

	return upgraded, string.format(
		"Mass upgraded %d %s tower(s) on path %d%s.",
		upgraded,
		towerType,
		pathIndex,
		skippedMaxed > 0 and (" (" .. tostring(skippedMaxed) .. " maxed/skipped)") or ""
	)
end

local function setTemporarySpeed(multiplier, seconds)
	GameSpeed:Set(multiplier)
	task.delay(seconds, function()
		GameSpeed:Set(1)
	end)
end

local function formatServerPerformance()
	local summary = getServerPerformanceSummary()
	return string.format(
		"Server 15s: avg %.1fms (%.0f fps), worst %.1fms (%.0f fps), samples %d, %s.",
		summary.avgMs,
		summary.avgFps,
		summary.worstMs,
		summary.worstFps,
		summary.samples,
		summary.diagnosis
	)
end

local function getPlayerPingMs(player)
	local ok, pingSeconds = pcall(function()
		return player:GetNetworkPing()
	end)
	if ok and typeof(pingSeconds) == "number" then
		return math.max(0, math.floor((pingSeconds * 1000) + 0.5))
	end

	return nil
end

local function requestClientPerformance(player)
	local requestId = tostring(player.UserId) .. ":" .. tostring(os.clock())
	pendingPerformanceRequests[requestId] = {
		player = player,
		startedAt = os.clock(),
	}
	PerformanceRequestRemote:FireClient(player, requestId)

	task.delay(3, function()
		local request = pendingPerformanceRequests[requestId]
		if not request then
			return
		end

		pendingPerformanceRequests[requestId] = nil
		if player.Parent == Players then
			sendSystemMessage(player, "Client performance timed out.")
		end
	end)
end

PerformanceResponseRemote.OnServerEvent:Connect(function(player, requestId, data)
	if typeof(requestId) ~= "string" or typeof(data) ~= "table" then
		return
	end

	local request = pendingPerformanceRequests[requestId]
	if not request or request.player ~= player then
		return
	end

	pendingPerformanceRequests[requestId] = nil
	local fps = tonumber(data.fps) or 0
	local memoryMb = tonumber(data.memoryMb) or 0
	local renderMs = fps > 0 and (1000 / fps) or 0
	local pingMs = getPlayerPingMs(player)
	local pingText = pingMs and (tostring(pingMs) .. "ms") or "unknown"

	sendSystemMessage(
		player,
		string.format(
			"Client: fps %.0f (%.1fms), memory %.1f MB, network ping %s.",
			fps,
			renderMs,
			memoryMb,
			pingText
		)
	)
end)

local function skipToRound(round)
	if gameOver or roundOverrideInProgress then
		return
	end

	round = math.max(1, math.floor(round))
	roundOverrideInProgress = true
	roundEnding = false
	roundLeaks = 0
	skipRequested = true
	canSkipCountdown = false
	currentRound = round - 1
	if round <= FIRST_TANK_ROUND then
		bossIntroPlayed = false
	end
	BalanceLogger:ResetAll()
	RunStats:ResetAll()
	clearBeginnerSpawnIndicators()
	clearBossSpawnIndicator()
	WarningRemote:FireAllClients("Hide")
	if round == FIRST_TANK_ROUND then
		DialogueService:FireAllClients(FIRST_BOSS_DIALOGUE_TEXT)
		task.wait(ROUND_ONE_DIALOGUE_LOCK_TIME)
	end
	TimerRemote:FireAllClients("RoundStartClose")
	Comm:Fire("RoundEnd", currentRound)

	task.defer(function()
		task.wait(GameSpeed:ScaleDuration(0.48))
		manualRoundStarted = true
		startRound()
		roundOverrideInProgress = false
	end)
end

Comm:On("AllEnemiesDead", function()
	if gameOver then return end
	if roundOverrideInProgress then return end
	if roundEnding then return end
	roundEnding = true

	giveRoundRewards()
	RunStats:RecordRoundCompleted(currentRound)
	if currentRound == 1 then
		print("[Dialogue] Firing round one dialogue")
		DialogueService:FireAllClients(ROUND_ONE_DIALOGUE_TEXT)
		task.wait(ROUND_ONE_DIALOGUE_LOCK_TIME)
	elseif currentRound == FIRST_TANK_ROUND then
		DialogueService:FireAllClients(FIRST_STONETHING_WIN_DIALOGUE_TEXT, {
			soundId = FIRST_STONETHING_WIN_DIALOGUE_SOUND_ID,
		})
		task.wait(ROUND_ONE_DIALOGUE_LOCK_TIME)
	end
	Comm:Fire("RoundEnd", currentRound)
	printFairnessDebug()
	BalanceLogger:ResetAll()
	intermission()
	countdown()
	startRound()
end)

Comm:On("EnemyReached", function()
	if gameOver then return end
	roundLeaks += 1
end)

Comm:On("FirstBossSpawned", function()
	clearBossSpawnIndicator()
end)

Comm:On("GameOver", function()
	gameOver = true
end)

local function handleChatCommand(player, message)
	local lowerMessage = string.lower(message)
	if lowerMessage == "/cmds" then
		local freeState = DevSettings:IsFreeMode() and "on" or "off"
		sendSystemMessage(player, "/skiptoround n - jump straight to a round.")
		sendSystemMessage(player, "/roundend - force current wave to end and pay rewards.")
		sendSystemMessage(player, "/sethealth n - set core health to n.")
		sendSystemMessage(player, "/setenemyhealth n - set current and future enemy health to n.")
		sendSystemMessage(player, "/speed n - set game speed multiplier.")
		sendSystemMessage(player, "/add [player] stone/crystal/metal/cash n - add resources or cash. Player name can be partial.")
		sendSystemMessage(player, "/infplace [on/off] - keep placing the same selected tower until cancelled.")
		sendSystemMessage(player, "/massupgrade towername 1/2/3 - upgrade all matching placed towers one tier on that path.")
		sendSystemMessage(player, "/ping - show your network ping and the server frame time.")
		sendSystemMessage(player, "/performance - show a 15s server performance diagnosis.")
		sendSystemMessage(player, "/indepth - show server diagnosis plus your FPS and memory.")
		sendSystemMessage(player, "/anticheatbypass [on/off] - toggle anti-cheat bypass for yourself.")
		sendSystemMessage(player, "/fly [1-10], /noclip [1-10], /phase [1-10] [studs] - anti-cheat movement tests.")
		sendSystemMessage(player, "/walkspeed [1-10] [speed], /jumpboost [1-10] [power], /instamine [1-10], /resourceboost [1-10] [n] - anti-cheat stat/mining tests.")
		sendSystemMessage(player, "/statboost, /forceplace, /forceupgrade, /cashcheat, /resourcecheat, /refundcheat, /ownercheat [1-10] - progression anti-cheat tests.")
		sendSystemMessage(player, "/free [on/off] - toggle free towers and upgrades. Current: " .. freeState .. ".")
		sendSystemMessage(player, "/openemies [on/off] - toggle unkillable enemies.")
		sendSystemMessage(player, "/inffire [on/off] - toggle infinite enemy fire duration.")
		sendSystemMessage(player, "/kick player reason - kick a player. Partial names work.")
		sendSystemMessage(player, "/payday [player] [n], /orestorm [player] [n], /fullsend [player] - economy boosts.")
		sendSystemMessage(player, "/bankrupt [player], /tax [player] [n], /lootgoblin [player] - economy chaos.")
		sendSystemMessage(player, "/coreheal n, /corebonk n, /warning text, /clearwarning - core and warning toys.")
		sendSystemMessage(player, "/slowmo [seconds], /turbo [seconds], /bossui, /spook - game-themed fun commands.")
		sendSystemMessage(player, "/play rockshard - test the rock shard landing sound locally.")
		sendSystemMessage(player, "/trigger bossanim - play the boss intro test animation.")
		return
	end

	if lowerMessage == "/ping" then
		local pingMs = getPlayerPingMs(player)
		local summary = getServerPerformanceSummary()
		sendSystemMessage(
			player,
			string.format(
				"Ping: user %s, server frame avg %.1fms (%.0f fps).",
				pingMs and (tostring(pingMs) .. "ms") or "unknown",
				summary.avgMs,
				summary.avgFps
			)
		)
		return
	end

	if lowerMessage == "/performance" then
		sendSystemMessage(player, formatServerPerformance())
		return
	end

	if lowerMessage == "/indepth" then
		sendSystemMessage(player, formatServerPerformance())
		requestClientPerformance(player)
		return
	end

	local infPlaceText = string.match(lowerMessage, "^/infplace%s*([%w]*)$")
	if infPlaceText ~= nil and string.sub(lowerMessage, 1, 9) == "/infplace" then
		local enabled = parseToggle(infPlaceText, player:GetAttribute("DevInfinitePlacement") == true)
		player:SetAttribute("DevInfinitePlacement", enabled)
		sendSystemMessage(player, "Infinite placement: " .. (enabled and "ON" or "OFF") .. ".")
		return
	end

	local massTowerName, massPathText = string.match(message, "^/massupgrade%s+(.+)%s+([123])$")
	if massTowerName and massPathText then
		local _, resultText = massUpgradeTowers(massTowerName, tonumber(massPathText))
		sendSystemMessage(player, resultText)
		return
	end

	local antiCheatText = string.match(lowerMessage, "^/anticheatbypass%s*([%w]*)$")
	if antiCheatText ~= nil and string.sub(lowerMessage, 1, 16) == "/anticheatbypass" then
		local enabled = parseToggle(antiCheatText, player:GetAttribute("AntiCheatBypass") == true)
		player:SetAttribute("AntiCheatBypass", enabled)
		sendSystemMessage(player, "Anti-cheat bypass: " .. (enabled and "ON" or "OFF") .. ".")
		return
	end

	local flyMethod = string.match(lowerMessage, "^/fly%s*([%d]*)$")
	if flyMethod ~= nil and string.sub(lowerMessage, 1, 4) == "/fly" then
		local method = normalizeCheatMethod(flyMethod)
		sendSystemMessage(player, testFly(player, method) and ("Fly cheat test " .. method .. " applied.") or "Could not apply fly cheat test.")
		return
	end

	local noclipMethod = string.match(lowerMessage, "^/noclip%s*([%d]*)$")
	if noclipMethod ~= nil and string.sub(lowerMessage, 1, 7) == "/noclip" then
		local method = normalizeCheatMethod(noclipMethod)
		sendSystemMessage(player, testNoclip(player, method) and ("Noclip cheat test " .. method .. " applied.") or "Could not apply noclip cheat test.")
		return
	end

	local phaseMethodText, phaseDistanceText = string.match(lowerMessage, "^/phase%s*([%d]*)%s*([%d%.]*)$")
	if phaseMethodText ~= nil and string.sub(lowerMessage, 1, 6) == "/phase" then
		local method, distance = parseCheatMethodAndValue(phaseMethodText, phaseDistanceText, 30)
		sendSystemMessage(player, testPhase(player, method, distance) and ("Phase cheat test " .. method .. " applied.") or "Could not apply phase cheat test.")
		return
	end

	local walkMethodText, walkSpeedText = string.match(lowerMessage, "^/walkspeed%s*([%d]*)%s*([%d%.]*)$")
	if walkMethodText ~= nil and string.sub(lowerMessage, 1, 10) == "/walkspeed" then
		local method, speed = parseCheatMethodAndValue(walkMethodText, walkSpeedText, 80)
		sendSystemMessage(player, testWalkspeed(player, method, speed) and ("Walkspeed cheat test " .. method .. " applied.") or "Could not apply walkspeed cheat test.")
		return
	end

	local jumpMethodText, jumpBoostText = string.match(lowerMessage, "^/jumpboost%s*([%d]*)%s*([%d%.]*)$")
	if jumpMethodText ~= nil and string.sub(lowerMessage, 1, 10) == "/jumpboost" then
		local method, power = parseCheatMethodAndValue(jumpMethodText, jumpBoostText, 140)
		sendSystemMessage(player, testJumpBoost(player, method, power) and ("Jump cheat test " .. method .. " applied.") or "Could not apply jump cheat test.")
		return
	end

	local instamineMethod = string.match(lowerMessage, "^/instamine%s*([%d]*)$")
	if instamineMethod ~= nil and string.sub(lowerMessage, 1, 10) == "/instamine" then
		local method = normalizeCheatMethod(instamineMethod)
		sendSystemMessage(player, testInstamine(player, method) and ("Instamine cheat test " .. method .. " applied.") or "Could not apply instamine cheat test.")
		return
	end

	local resourceBoostMethodText, resourceBoostText = string.match(lowerMessage, "^/resourceboost%s*([%d]*)%s*([%d%.]*)$")
	if resourceBoostMethodText ~= nil and string.sub(lowerMessage, 1, 14) == "/resourceboost" then
		local method, multiplier = parseCheatMethodAndValue(resourceBoostMethodText, resourceBoostText, 999)
		sendSystemMessage(player, testResourceBoost(player, method, multiplier) and ("Resource boost cheat test " .. method .. " applied.") or "Could not apply resource boost cheat test.")
		return
	end

	local statBoostMethod = string.match(lowerMessage, "^/statboost%s*([%d]*)$")
	if statBoostMethod ~= nil and string.sub(lowerMessage, 1, 10) == "/statboost" then
		local method = normalizeCheatMethod(statBoostMethod)
		sendSystemMessage(player, testStatBoost(player, method) and ("Stat boost cheat test " .. method .. " applied.") or "Could not apply stat boost cheat test.")
		return
	end

	local forcePlaceMethodText, forcePlaceTowerName = string.match(message, "^/forceplace%s*([%d]*)%s*(%S*)$")
	if forcePlaceMethodText ~= nil and string.sub(lowerMessage, 1, 11) == "/forceplace" then
		local method = normalizeCheatMethod(forcePlaceMethodText)
		sendSystemMessage(player, spawnUntrustedTower(player, forcePlaceTowerName, method) and ("Force place cheat test " .. method .. " applied.") or "Could not apply force place cheat test.")
		return
	end

	local forceUpgradeMethod = string.match(lowerMessage, "^/forceupgrade%s*([%d]*)$")
	if forceUpgradeMethod ~= nil and string.sub(lowerMessage, 1, 13) == "/forceupgrade" then
		local method = normalizeCheatMethod(forceUpgradeMethod)
		sendSystemMessage(player, testForceUpgrade(player, method) and ("Force upgrade cheat test " .. method .. " applied.") or "Could not apply force upgrade cheat test.")
		return
	end

	local cashCheatMethodText, cashCheatAmountText = string.match(lowerMessage, "^/cashcheat%s*([%d]*)%s*([%d%.]*)$")
	if cashCheatMethodText ~= nil and string.sub(lowerMessage, 1, 10) == "/cashcheat" then
		local method, amount = parseCheatMethodAndValue(cashCheatMethodText, cashCheatAmountText, 999999)
		sendSystemMessage(player, testCashCheat(player, method, amount) and ("Cash cheat test " .. method .. " applied.") or "Could not apply cash cheat test.")
		return
	end

	local resourceCheatMethodText, resourceCheatAmountText = string.match(lowerMessage, "^/resourcecheat%s*([%d]*)%s*([%d%.]*)$")
	if resourceCheatMethodText ~= nil and string.sub(lowerMessage, 1, 14) == "/resourcecheat" then
		local method, amount = parseCheatMethodAndValue(resourceCheatMethodText, resourceCheatAmountText, 9999)
		sendSystemMessage(player, testResourceCheat(player, method, amount) and ("Resource cheat test " .. method .. " applied.") or "Could not apply resource cheat test.")
		return
	end

	local refundCheatMethod = string.match(lowerMessage, "^/refundcheat%s*([%d]*)$")
	if refundCheatMethod ~= nil and string.sub(lowerMessage, 1, 12) == "/refundcheat" then
		local method = normalizeCheatMethod(refundCheatMethod)
		sendSystemMessage(player, testRefundCheat(player, method) and ("Refund cheat test " .. method .. " applied.") or "Could not apply refund cheat test.")
		return
	end

	local ownerCheatMethod = string.match(lowerMessage, "^/ownercheat%s*([%d]*)$")
	if ownerCheatMethod ~= nil and string.sub(lowerMessage, 1, 11) == "/ownercheat" then
		local method = normalizeCheatMethod(ownerCheatMethod)
		sendSystemMessage(player, testOwnerCheat(player, method) and ("Owner cheat test " .. method .. " applied.") or "Could not apply owner cheat test.")
		return
	end

	local roundText = string.match(lowerMessage, "^/skiptoround%s+(%d+)$")
	if roundText then
		skipToRound(tonumber(roundText))
		sendSystemMessage(player, "Skipping to round " .. roundText .. ".")
		return
	end

	if lowerMessage == "/roundend" then
		Comm:Fire("AllEnemiesDead")
		sendSystemMessage(player, "Round forced to end.")
		return
	end

	local healthText = string.match(lowerMessage, "^/sethealth%s+([%-]?%d+%.?%d*)$")
	if healthText then
		Comm:Fire("SetCoreHealth", tonumber(healthText))
		sendSystemMessage(player, "Core health set to " .. healthText .. ".")
		return
	end

	local enemyHealthText = string.match(lowerMessage, "^/setenemyhealth%s+([%-]?%d+%.?%d*)$")
	if enemyHealthText then
		local enemyHealth = tonumber(enemyHealthText)
		if not enemyHealth or enemyHealth <= 0 then
			sendSystemMessage(player, "Enemy health must be greater than 0.")
			return
		end

		ReplicatedStorage:SetAttribute("DevEnemyHealthOverride", enemyHealth)
		for _, enemy in ipairs(workspace:GetChildren()) do
			local healthVal = enemy:FindFirstChild("Health")
			local humanoid = enemy:FindFirstChildOfClass("Humanoid")
			if (healthVal and (healthVal:IsA("NumberValue") or healthVal:IsA("IntValue"))) and not Players:GetPlayerFromCharacter(enemy) then
				healthVal.Value = enemyHealth
				enemy:SetAttribute("BaseMaxHealth", enemyHealth)
				if humanoid then
					humanoid.MaxHealth = enemyHealth
					humanoid.Health = enemyHealth
				end
			end
		end

		sendSystemMessage(player, "Current and future enemy health set to " .. enemyHealthText .. ".")
		return
	end

	local speedText = string.match(lowerMessage, "^/speed%s+([%d%.]+)$")
	if speedText then
		local newSpeed = GameSpeed:Set(tonumber(speedText))
		print(string.format("[Dev] Game speed set to %.2fx", newSpeed))
		sendSystemMessage(player, "Game speed set to " .. tostring(newSpeed) .. "x.")
		return
	end

	local targetText, resourceType, amountText = string.match(lowerMessage, "^/add%s+(%S+)%s+(%a+)%s+([%-]?%d+%.?%d*)$")
	if targetText and not (resourceType == "cash" or resourceType == "stone" or resourceType == "crystal" or resourceType == "metal") then
		targetText = nil
		resourceType, amountText = string.match(lowerMessage, "^/add%s+(%a+)%s+([%-]?%d+%.?%d*)$")
	else
		resourceType, amountText = resourceType, amountText
	end

	if not resourceType or not amountText then
		resourceType, amountText = string.match(lowerMessage, "^/add%s+(%a+)%s+([%-]?%d+%.?%d*)$")
	end

	if resourceType and amountText then
		local amount = tonumber(amountText)
		local targetPlayer = targetText and findClosestPlayer(targetText) or player
		if not targetPlayer or targetPlayer.Parent ~= Players or not amount then
			sendSystemMessage(player, "No matching player for /add.")
			return
		end

		if resourceType == "cash" then
			CashService:Add(targetPlayer, amount)
		elseif resourceType == "stone" or resourceType == "crystal" or resourceType == "metal" then
			ResourceService:AddDev(targetPlayer, resourceType, amount)
		else
			warn("[Dev] Unknown /add type:", resourceType)
			sendSystemMessage(player, "Unknown /add type: " .. resourceType .. ".")
		end
		sendSystemMessage(player, "Added " .. amountText .. " " .. resourceType .. " to " .. targetPlayer.Name .. ".")
		if targetPlayer ~= player then
			sendSystemMessage(targetPlayer, player.Name .. " gave you " .. amountText .. " " .. resourceType .. ".")
		end
		return
	end

	local freeText = string.match(lowerMessage, "^/free%s*(%a*)$")
	if freeText ~= nil and string.sub(lowerMessage, 1, 5) == "/free" then
		local enabled
		if freeText == "on" or freeText == "true" or freeText == "1" then
			enabled = true
		elseif freeText == "off" or freeText == "false" or freeText == "0" then
			enabled = false
		else
			enabled = not DevSettings:IsFreeMode()
		end

		DevSettings:SetFreeMode(enabled)
		sendSystemMessage(player, "Free towers/upgrades: " .. (enabled and "ON" or "OFF") .. ".")
		return
	end

	local opEnemiesText = string.match(lowerMessage, "^/openemies%s*(%a*)$")
	if opEnemiesText ~= nil and string.sub(lowerMessage, 1, 10) == "/openemies" then
		local enabled
		if opEnemiesText == "on" or opEnemiesText == "true" or opEnemiesText == "1" then
			enabled = true
		elseif opEnemiesText == "off" or opEnemiesText == "false" or opEnemiesText == "0" then
			enabled = false
		else
			enabled = not ReplicatedStorage:GetAttribute("DevOpenEnemies")
		end

		ReplicatedStorage:SetAttribute("DevOpenEnemies", enabled)
		sendSystemMessage(player, "Unkillable enemies: " .. (enabled and "ON" or "OFF") .. ".")
		return
	end

	local infFireText = string.match(lowerMessage, "^/inffire%s*(%a*)$")
	if infFireText ~= nil and string.sub(lowerMessage, 1, 8) == "/inffire" then
		local enabled
		if infFireText == "on" or infFireText == "true" or infFireText == "1" then
			enabled = true
		elseif infFireText == "off" or infFireText == "false" or infFireText == "0" then
			enabled = false
		else
			enabled = not ReplicatedStorage:GetAttribute("DevInfiniteFire")
		end

		ReplicatedStorage:SetAttribute("DevInfiniteFire", enabled)
		sendSystemMessage(player, "Infinite enemy fire: " .. (enabled and "ON" or "OFF") .. ".")
		return
	end

	local paydayRest = string.match(message, "^/payday%s*(.*)$")
	if paydayRest then
		local targetPlayer, amount = parseOptionalPlayerAndAmount(paydayRest, player, 5000)
		if not targetPlayer then
			sendSystemMessage(player, "No matching player for /payday.")
			return
		end
		CashService:Add(targetPlayer, amount)
		sendSystemMessage(player, "Payday: +" .. tostring(amount) .. " cash to " .. targetPlayer.Name .. ".")
		return
	end

	local orestormRest = string.match(message, "^/orestorm%s*(.*)$")
	if orestormRest then
		local targetPlayer, amount = parseOptionalPlayerAndAmount(orestormRest, player, 25)
		if not targetPlayer then
			sendSystemMessage(player, "No matching player for /orestorm.")
			return
		end
		addAllResources(targetPlayer, amount)
		sendSystemMessage(player, "Orestorm: +" .. tostring(amount) .. " of each resource to " .. targetPlayer.Name .. ".")
		return
	end

	local fullsendRest = string.match(message, "^/fullsend%s*(.*)$")
	if fullsendRest then
		local targetPlayer = trim(fullsendRest) ~= "" and findClosestPlayer(trim(fullsendRest)) or player
		if not targetPlayer then
			sendSystemMessage(player, "No matching player for /fullsend.")
			return
		end
		CashService:Add(targetPlayer, 50000)
		addAllResources(targetPlayer, 500)
		sendSystemMessage(player, "Full send loaded " .. targetPlayer.Name .. " with cash and resources.")
		return
	end

	local bankruptRest = string.match(message, "^/bankrupt%s*(.*)$")
	if bankruptRest then
		local targetPlayer = trim(bankruptRest) ~= "" and findClosestPlayer(trim(bankruptRest)) or player
		if not targetPlayer then
			sendSystemMessage(player, "No matching player for /bankrupt.")
			return
		end
		CashService:Add(targetPlayer, -1000000000)
		sendSystemMessage(player, targetPlayer.Name .. " got financially obliterated.")
		return
	end

	local taxRest = string.match(message, "^/tax%s*(.*)$")
	if taxRest then
		local targetPlayer, amount = parseOptionalPlayerAndAmount(taxRest, player, 1000)
		if not targetPlayer then
			sendSystemMessage(player, "No matching player for /tax.")
			return
		end
		CashService:Add(targetPlayer, -math.abs(amount))
		sendSystemMessage(player, "Taxed " .. targetPlayer.Name .. " for " .. tostring(math.abs(amount)) .. " cash.")
		return
	end

	local lootgoblinRest = string.match(message, "^/lootgoblin%s*(.*)$")
	if lootgoblinRest then
		local targetPlayer = trim(lootgoblinRest) ~= "" and findClosestPlayer(trim(lootgoblinRest)) or player
		if not targetPlayer then
			sendSystemMessage(player, "No matching player for /lootgoblin.")
			return
		end
		local cash = math.random(777, 7777)
		local ore = math.random(7, 77)
		CashService:Add(targetPlayer, cash)
		addAllResources(targetPlayer, ore)
		sendSystemMessage(player, "Loot goblin dropped +" .. cash .. " cash and +" .. ore .. " resources for " .. targetPlayer.Name .. ".")
		return
	end

	local coreHealText = string.match(lowerMessage, "^/coreheal%s+([%-]?%d+%.?%d*)$")
	if coreHealText then
		Comm:Fire("ModifyCoreHealth", math.abs(tonumber(coreHealText)))
		sendSystemMessage(player, "Core healed by " .. coreHealText .. ".")
		return
	end

	local coreBonkText = string.match(lowerMessage, "^/corebonk%s+([%-]?%d+%.?%d*)$")
	if coreBonkText then
		Comm:Fire("ModifyCoreHealth", -math.abs(tonumber(coreBonkText)))
		sendSystemMessage(player, "Core bonked for " .. coreBonkText .. ".")
		return
	end

	local warningText = string.match(message, "^/warning%s+(.+)$")
	if warningText then
		WarningRemote:FireAllClients("Show", warningText, "Dev")
		sendSystemMessage(player, "Warning sent.")
		return
	end

	if lowerMessage == "/clearwarning" then
		WarningRemote:FireAllClients("Hide")
		sendSystemMessage(player, "Warning cleared.")
		return
	end

	local slowmoSeconds = tonumber(string.match(lowerMessage, "^/slowmo%s*([%d%.]*)$")) or 8
	if string.sub(lowerMessage, 1, 7) == "/slowmo" then
		setTemporarySpeed(0.25, slowmoSeconds)
		sendSystemMessage(player, "Slow motion for " .. tostring(slowmoSeconds) .. "s.")
		return
	end

	local turboSeconds = tonumber(string.match(lowerMessage, "^/turbo%s*([%d%.]*)$")) or 8
	if string.sub(lowerMessage, 1, 6) == "/turbo" then
		setTemporarySpeed(5, turboSeconds)
		sendSystemMessage(player, "Turbo mode for " .. tostring(turboSeconds) .. "s.")
		return
	end

	if lowerMessage == "/bossui" then
		BossAnimRemote:FireAllClients()
		sendSystemMessage(player, "Boss UI fired.")
		return
	end

	if lowerMessage == "/spook" then
		WarningRemote:FireAllClients("Show", "The cave is getting angry.", "Dev")
		BossAnimRemote:FireAllClients()
		sendSystemMessage(player, "Spook sequence fired.")
		return
	end

	if lowerMessage == "/play rockshard" then
		CustomChatRemote:FireClient(player, {
			kind = "playSound",
			soundId = "rbxassetid://90758965952873",
			volume = 1,
			playbackSpeed = 1,
		})
		sendSystemMessage(player, "Playing rock shard sound locally.")
		return
	end

	local kickTargetText, kickReason = string.match(message, "^/kick%s+(%S+)%s*(.*)$")
	if kickTargetText then
		local targetPlayer = findClosestPlayer(kickTargetText)
		if not targetPlayer then
			sendSystemMessage(player, "No matching player for /kick.")
			return
		end

		local reason = kickReason ~= "" and kickReason or "Kicked by dev command."
		targetPlayer:Kick(reason)
		sendSystemMessage(player, "Kicked " .. targetPlayer.Name .. ".")
		return
	end

	local mischiefCommand, mischiefTarget, mischiefArg = string.match(lowerMessage, "^/(fling|spin|sit|pop)%s+(%S+)%s*([%-]?%d*%.?%d*)$")
	if mischiefCommand and mischiefTarget then
		local targetPlayer = findClosestPlayer(mischiefTarget)
		if not targetPlayer then
			sendSystemMessage(player, "No matching player for /" .. mischiefCommand .. ".")
			return
		end

		local ok = false
		if mischiefCommand == "fling" then
			ok = flingPlayer(targetPlayer, tonumber(mischiefArg))
		elseif mischiefCommand == "spin" then
			ok = spinPlayer(targetPlayer, tonumber(mischiefArg))
		elseif mischiefCommand == "sit" then
			ok = sitPlayer(targetPlayer)
		elseif mischiefCommand == "pop" then
			ok = popPlayer(targetPlayer)
		end

		sendSystemMessage(player, ok and ("Used /" .. mischiefCommand .. " on " .. targetPlayer.Name .. ".") or ("Could not use /" .. mischiefCommand .. " on " .. targetPlayer.Name .. "."))
		return
	end

	if lowerMessage == "/trigger bossanim" then
		DialogueService:FireAllClients(FIRST_BOSS_DIALOGUE_TEXT)
		task.wait(ROUND_ONE_DIALOGUE_LOCK_TIME)
		BossAnimRemote:FireAllClients()
		sendSystemMessage(player, "Boss animation triggered.")
		return
	end

	if lowerMessage == "/dialogue" then
		DialogueService:FireAllClients(ROUND_ONE_DIALOGUE_TEXT)
		sendSystemMessage(player, "Dialogue triggered.")
		return
	end

	if string.sub(message, 1, 1) == "/" then
		sendSystemMessage(player, "Unknown command. Type /cmds.")
	end
end

local function bindChatCommands(player)
	player.Chatted:Connect(function(message)
		handleChatCommand(player, message)
	end)
end

CustomChatRemote.OnServerEvent:Connect(function(player, message)
	if typeof(message) == "string" then
		handleChatCommand(player, message)
	end
end)

Players.PlayerAdded:Connect(bindChatCommands)

for _, player in ipairs(Players:GetPlayers()) do
	bindChatCommands(player)
end

task.wait(GameSpeed:ScaleDuration(2))
refreshSpawns()
showBeginnerSpawnIndicatorForRound(1)
TutorialService:WaitForAllCurrentPlayersComplete()
countdown()
if not manualRoundStarted then
	startRound()
end
