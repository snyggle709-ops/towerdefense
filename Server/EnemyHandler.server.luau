local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local Comm = require(game.ReplicatedStorage:WaitForChild("Comm"))
local GameSpeed = require(game.ReplicatedStorage:WaitForChild("GameSpeed"))
local EnemyBehaviors = require(script.Parent:WaitForChild("EnemyBehaviors"))
local CashService = require(script.Parent:WaitForChild("CashService"))
local BalanceLogger = require(script.Parent:WaitForChild("BalanceLogger"))
local RunStats = require(script.Parent:WaitForChild("RunStats"))
local enemiesFolder = game.ReplicatedStorage:WaitForChild("Enemies")
local DevSpawnEnemiesRemote = game.ReplicatedStorage:WaitForChild("DevSpawnEnemiesRemote")
local PhysicsService = game:GetService("PhysicsService")
local activeEnemies = {}
local enemyMoveConnections = {}
local enemyClosestWaypointDistances = {}
local enemyOutcomeLogged = {}
local updateEnemyClosestWaypointDistance
local recordEnemyKilled
local recordEnemyLeaked
local waypartRef = workspace:WaitForChild("Waypoint")
local WALK_ANIM = "rbxassetid://180426354"
local enemiesKilled = 0
local gameOver = false
local devSpawnBusy = false
local roundSpawnToken = 0
local roundSpawning = false
local roundClearFired = true
local ENEMY_COLLISION_GROUP = "Enemies"
local PLAYER_COLLISION_GROUP = "PlayerCharacters"
local FIRST_TANK_ROUND = 18
local PRE_FIRST_TANK_ROUND = FIRST_TANK_ROUND - 1
local FIRST_BOSS_NAME = "stonething"
local FIRST_ROCKMAN_ROUND = 25
local ROCKMAN_FIRST_SPAWN_MAX_HEALTH = 110
local ROCKMAN_HEALTH_SCALING_MULTIPLIER = 1 / 3
local ROCKMAN_START_SPEED = 7
local ROCKMAN_MAX_SPEED = 13
local ROCKMAN_SPEED_RAMP_TIME = 8
local DEBUG_ENEMY_FACING = false
local DEBUG_ENEMY_NAMES = {
	stonething = true,
	wormy = true,
}

local function getScaledEnemySpeed(speed)
	return math.max(0, (tonumber(speed) or 0) * GameSpeed:Get())
end

local function applyCurrentGameSpeedToEnemy(enemy)
	if not enemy or not enemy.Parent then
		return
	end

	local humanoid = enemy:FindFirstChildOfClass("Humanoid")
	local speedVal = enemy:FindFirstChild("Speed")
	if humanoid and speedVal and humanoid.Health > 0 then
		humanoid.WalkSpeed = getScaledEnemySpeed(speedVal.Value)
		local animator = humanoid:FindFirstChildOfClass("Animator")
		if animator then
			for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
				track:AdjustSpeed(GameSpeed:Get())
			end
		end
	end
end

local SPAWN_POP_TIME = 0.16
local DEATH_POP_TIME = 0.14
local MIN_POP_SCALE_MULT = 0.001
local cleanupInProgress = {}
local roleSpawnCursors = {}

local ROLE_FOLDER_NAMES = {
	basic = "Basic",
	advanced = "Advanced",
	runner = "Runner",
	support = "Support",
	tank = "Tank",
}

local ROLE_SPAWN_ORDER = {
	"basic",
	"runner",
	"advanced",
	"support",
	"tank",
}

local function maybeFireAllEnemiesDead()
	if gameOver or roundSpawning or roundClearFired or next(activeEnemies) then
		return
	end

	roundClearFired = true
	Comm:Fire("AllEnemiesDead")
end

local ENEMY_NAME_ROLE_FALLBACK = {
	enemy = "basic",
	MetalEnemy = "basic",
	RockMan = "advanced",
	egg = "advanced",
	wormy = "runner",
	buggy = "support",
	stonething = "tank",
}

local ROUND_ROLE_BUDGET_ANCHORS = {
	{ round = 1, budget = { basic = 5 } },
	{ round = 3, budget = { basic = 7 } },
	{ round = 5, budget = { basic = 8, runner = 1 } },
	{ round = 7, budget = { basic = 10, runner = 2 } },
	{ round = 9, budget = { basic = 9, runner = 2, support = 1 } },
	{ round = 11, budget = { basic = 8, runner = 3, advanced = 2 } },
	{ round = 13, budget = { basic = 7, runner = 4, advanced = 2, tank = 1 } },
	{ round = 15, budget = { basic = 5, runner = 3, advanced = 2, support = 2, tank = 1 } },
	{ round = 18, budget = { basic = 6, runner = 4, advanced = 3, support = 2, tank = 2 } },
	{ round = 22, budget = { basic = 7, runner = 5, advanced = 4, support = 3, tank = 2 } },
}

local HANDCRAFTED_ROUNDS = {
	[1] = {
		{"enemy", 4},
	},
	[2] = {
		{"enemy", 6},
	},
	[3] = {
		{"enemy", 8},
	},
	[4] = {
		{"wormy", 2},
	},
	[5] = {
		{"enemy", 6},
		{"wormy", 2},
	},
	[6] = {
		{"enemy", 8},
		{"wormy", 3},
	},
	[7] = {
		{"enemy", 6},
		{"MetalEnemy", 2},
		{"wormy", 2},
	},
	[8] = {
		{"enemy", 4},
		{"MetalEnemy", 4},
	},
	[9] = {
		{"buggy", 1},
		{"enemy", 4},
		{"MetalEnemy", 4},
	},
	[10] = {
		{"buggy", 1},
		{"MetalEnemy", 6},
		{"wormy", 3},
	},
	[11] = {
		{"egg", 2},
	},
	[12] = {
		{"egg", 2},
		{"wormy", 6},
	},
	[13] = {
		{"egg", 3},
		{"MetalEnemy", 6},
	},
	[14] = {
		{"buggy", 1},
		{"egg", 3},
		{"MetalEnemy", 6},
	},
	[15] = {
		{"buggy", 1},
		{"egg", 3},
		{"wormy", 8},
	},
	[16] = {
		{"MetalEnemy", 8},
		{"buggy", 2},
	},
	[17] = {
		{"egg", 3},
		{"MetalEnemy", 6},
		{"wormy", 6},
	},
	[18] = {
		{"stonething", 1},
		{"MetalEnemy", 4},
	},
	[19] = {
		{"MetalEnemy", 10},
		{"egg", 4},
	},
	[20] = {
		{"stonething", 2},
		{"buggy", 2},
		{"wormy", 10},
	},
	[21] = {
		{"egg", 5},
		{"MetalEnemy", 10},
	},
	[22] = {
		{"stonething", 2},
		{"egg", 3},
		{"buggy", 2},
	},
	[23] = {
		{"wormy", 16},
		{"MetalEnemy", 12},
	},
	[24] = {
		{"stonething", 3},
		{"MetalEnemy", 12},
	},
	[25] = {
		{"RockMan", 1},
		{"MetalEnemy", 12},
	},
	[26] = {
		{"RockMan", 1},
		{"wormy", 10},
		{"egg", 3},
	},
	[27] = {
		{"RockMan", 2},
		{"buggy", 2},
		{"MetalEnemy", 12},
	},
	[28] = {
		{"stonething", 3},
		{"RockMan", 1},
		{"MetalEnemy", 14},
	},
	[29] = {
		{"RockMan", 2},
		{"egg", 4},
		{"wormy", 12},
	},
	[30] = {
		{"stonething", 2},
		{"RockMan", 2},
		{"buggy", 3},
		{"wormy", 12},
	},
}

pcall(function()
	PhysicsService:RegisterCollisionGroup(ENEMY_COLLISION_GROUP)
end)

pcall(function()
	PhysicsService:RegisterCollisionGroup(PLAYER_COLLISION_GROUP)
end)

PhysicsService:CollisionGroupSetCollidable(ENEMY_COLLISION_GROUP, ENEMY_COLLISION_GROUP, false)
PhysicsService:CollisionGroupSetCollidable(ENEMY_COLLISION_GROUP, PLAYER_COLLISION_GROUP, false)

local function setCharacterCollisionGroup(character)
	local function apply(part)
		if part:IsA("BasePart") then
			part.CollisionGroup = PLAYER_COLLISION_GROUP
		end
	end

	for _, obj in ipairs(character:GetDescendants()) do
		apply(obj)
	end

	character.DescendantAdded:Connect(apply)
end

for _, player in ipairs(game:GetService("Players"):GetPlayers()) do
	if player.Character then
		setCharacterCollisionGroup(player.Character)
	end

	player.CharacterAdded:Connect(setCharacterCollisionGroup)
end

game:GetService("Players").PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(setCharacterCollisionGroup)
end)

-- ============================================================
-- DAMAGE POPUP
-- ============================================================
local SILKSCREEN_FONT = Font.new("rbxassetid://12187371840")
local POPUP_RISE = 2.5
local POPUP_DURATION = 0.9
local POPUP_SIDE_DRIFT = 1.2
local HIT_SOUND_ID = "rbxassetid://131104862552317"
local HIT_SOUND_VOLUME = 2.2
local HIT_SOUND_MIN_DISTANCE = 10
local HIT_SOUND_MAX_DISTANCE = 75
local DAMAGE_HIGHLIGHT_FADE_IN = 0.2
local DAMAGE_HIGHLIGHT_HOLD = 0.3
local DAMAGE_HIGHLIGHT_FADE_OUT = 0.2
local HEALTH_POPUP_RADIUS = 20
local HEALTH_POPUP_TEXT_SIZE = 16
local HEALTH_POPUP_MAX_DISTANCE = 120
local HEALTH_POPUP_SHOW_OFFSET_Y = 3.6
local HEALTH_POPUP_SCAN_INTERVAL = 0.2
local HEALTH_POPUP_FADE_TIME = 0.12
local HEALTH_POPUP_GROW_TIME = 0.16
local HEALTH_POPUP_SHRINK_TIME = 0.12
local HEALTH_POPUP_GREEN = Color3.fromRGB(110, 255, 130)
local HEALTH_POPUP_STROKE = Color3.fromRGB(20, 90, 25)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local healthPopupStates = {}

local function yawDegrees(cf)
	local _, y, _ = cf:ToOrientation()
	return math.deg(y)
end

local function shouldDebugEnemy(enemy)
	return DEBUG_ENEMY_FACING and enemy and DEBUG_ENEMY_NAMES[enemy.Name] == true
end

local function logEnemyFacing(stage, enemy, extra)
	if not shouldDebugEnemy(enemy) then
		return
	end

	local hrp = enemy:FindFirstChild("HumanoidRootPart")
	local mesh = enemy:FindFirstChild("Mesh_0", true) or enemy:FindFirstChildWhichIsA("MeshPart", true)
	local pivot = enemy:GetPivot()
	local basePartCount = 0
	local meshPartCount = 0

	for _, descendant in ipairs(enemy:GetDescendants()) do
		if descendant:IsA("BasePart") then
			basePartCount += 1
		end
		if descendant:IsA("MeshPart") then
			meshPartCount += 1
		end
	end

	print(string.format("[FacingDebug][%s] %s", stage, enemy:GetFullName()))
	print(string.format(
		"  ModelYaw=%.3f PrimaryPart=%s BaseParts=%d MeshParts=%d",
		yawDegrees(pivot),
		enemy.PrimaryPart and enemy.PrimaryPart.Name or "nil",
		basePartCount,
		meshPartCount
		))

	if hrp then
		print(string.format(
			"  HRPYaw=%.3f HRPPivotYaw=%.3f Pos=%s CanCollide=%s Anchored=%s",
			yawDegrees(hrp.CFrame),
			yawDegrees(hrp.PivotOffset),
			tostring(hrp.Position),
			tostring(hrp.CanCollide),
			tostring(hrp.Anchored)
			))
	end

	if mesh then
		print(string.format(
			"  MeshYaw=%.3f MeshPivotYaw=%.3f Pos=%s CanCollide=%s Anchored=%s",
			yawDegrees(mesh.CFrame),
			yawDegrees(mesh.PivotOffset),
			tostring(mesh.Position),
			tostring(mesh.CanCollide),
			tostring(mesh.Anchored)
			))
	end

	if hrp and mesh then
		print(string.format("  MeshRelativeToHRPYaw=%.3f", yawDegrees(hrp.CFrame:ToObjectSpace(mesh.CFrame))))
	end

	if extra then
		print("  Extra:", extra)
	end
end

local function getEnemyFacingOffsetRadians(enemy)
	if not enemy then
		return 0
	end

	local offsetAttr = enemy:GetAttribute("FacingOffsetDegrees")
	if typeof(offsetAttr) == "number" then
		return math.rad(offsetAttr)
	end

	local offsetVal = enemy:FindFirstChild("FacingOffsetDegrees")
	if offsetVal and offsetVal:IsA("NumberValue") then
		return math.rad(offsetVal.Value)
	end

	if enemy.Name == "stonething" then
		return math.rad(-90)
	end

	return 0
end

local function orientEnemyTowards(enemy, targetPosition)
	local offsetRadians = getEnemyFacingOffsetRadians(enemy)
	if offsetRadians == 0 or not enemy or not enemy.Parent then
		return
	end

	local pivot = enemy:GetPivot()
	local flatDirection = Vector3.new(
		targetPosition.X - pivot.Position.X,
		0,
		targetPosition.Z - pivot.Position.Z
	)

	if flatDirection.Magnitude <= 0.001 then
		return
	end

	local lookCf = CFrame.lookAt(pivot.Position, pivot.Position + flatDirection.Unit)
	enemy:PivotTo(lookCf * CFrame.Angles(0, offsetRadians, 0))
end

local function normalizeEnemyPrimaryPart(enemy)
	if not enemy or not enemy:IsA("Model") then
		return nil
	end

	local hrp = enemy:FindFirstChild("HumanoidRootPart")
	if hrp and hrp:IsA("BasePart") then
		enemy.PrimaryPart = hrp
	end

	return hrp
end

local function scaleEnemyAtCurrentPivot(enemy, scale)
	if not enemy or not enemy.Parent then
		return
	end

	local pivot = enemy:GetPivot()
	enemy:ScaleTo(scale)
	enemy:PivotTo(pivot)
end

local function shouldUseScalePop(enemy)
	if not enemy then
		return true
	end

	return enemy.Name ~= "stonething" and enemy.Name ~= "wormy"
end

local function showDamagePopup(enemy, damage)
	local hrp = enemy:FindFirstChild("HumanoidRootPart") or enemy:FindFirstChild("Head")
	if not hrp then return end

	local anchor = Instance.new("Part")
	anchor.Name = "DmgAnchor"
	anchor.Size = Vector3.new(0.05, 0.05, 0.05)
	anchor.Transparency = 1
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.CFrame = hrp.CFrame
	anchor.Parent = workspace

	local sideX = (math.random() - 0.5) * 2 * POPUP_SIDE_DRIFT
	local sideZ = (math.random() - 0.5) * 2 * POPUP_SIDE_DRIFT
	local startY = 2.5

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "DmgPopup"
	billboard.Adornee = anchor
	billboard.Size = UDim2.fromOffset(100, 28)
	billboard.StudsOffset = Vector3.new(sideX * 0.2, startY, sideZ * 0.2)
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.MaxDistance = 120
	billboard.Parent = anchor

	local label = Instance.new("TextLabel")
	label.Name = "DmgText"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "-" .. tostring(math.floor(damage))
	label.FontFace = SILKSCREEN_FONT
	label.TextColor3 = Color3.fromRGB(255, 55, 55)
	label.TextScaled = false
	label.TextSize = 16
	label.TextTransparency = 0
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.Parent = billboard

	local uiStroke = Instance.new("UIStroke")
	uiStroke.Color = Color3.fromRGB(100, 10, 10)
	uiStroke.Thickness = 1.5
	uiStroke.Transparency = 0
	uiStroke.Parent = label

	local targetOffset = Vector3.new(sideX, startY + POPUP_RISE, sideZ)

	TweenService:Create(billboard, TweenInfo.new(POPUP_DURATION, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
		StudsOffset = targetOffset,
	}):Play()

	task.delay(POPUP_DURATION * 0.35, function()
		if not label or not label.Parent then return end
		local fadeDur = POPUP_DURATION * 0.65
		TweenService:Create(label, TweenInfo.new(fadeDur, Enum.EasingStyle.Sine, Enum.EasingDirection.In), {
			TextTransparency = 1,
		}):Play()
		TweenService:Create(uiStroke, TweenInfo.new(fadeDur, Enum.EasingStyle.Sine, Enum.EasingDirection.In), {
			Transparency = 1,
		}):Play()
	end)

	Debris:AddItem(anchor, POPUP_DURATION + 0.15)
end

local function playEnemyHitSound(enemy)
	local soundParent =
		enemy:FindFirstChild("HumanoidRootPart")
		or enemy:FindFirstChild("Head")
		or enemy:FindFirstChildWhichIsA("BasePart", true)

	if not soundParent then
		return
	end

	local hitSound = Instance.new("Sound")
	hitSound.SoundId = HIT_SOUND_ID
	hitSound.Volume = HIT_SOUND_VOLUME
	hitSound.RollOffMode = Enum.RollOffMode.Inverse
	hitSound.RollOffMinDistance = HIT_SOUND_MIN_DISTANCE
	hitSound.RollOffMaxDistance = HIT_SOUND_MAX_DISTANCE
	hitSound.Parent = soundParent
	hitSound:Play()

	Debris:AddItem(hitSound, 2)
end

local function playEnemyDamageHighlight(enemy)
	local existing = enemy:FindFirstChild("DamageFlashHighlight")
	if existing then
		existing:Destroy()
	end

	local highlight = Instance.new("Highlight")
	highlight.Name = "DamageFlashHighlight"
	highlight.Adornee = enemy
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.FillColor = Color3.fromRGB(255, 60, 60)
	highlight.OutlineColor = Color3.fromRGB(170, 25, 25)
	highlight.FillTransparency = 1
	highlight.OutlineTransparency = 1
	highlight.Parent = enemy

	local fadeIn = TweenService:Create(
		highlight,
		TweenInfo.new(DAMAGE_HIGHLIGHT_FADE_IN, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
		{
			FillTransparency = 0.6,
			OutlineTransparency = 0.25,
		}
	)

	local fadeOut = TweenService:Create(
		highlight,
		TweenInfo.new(DAMAGE_HIGHLIGHT_FADE_OUT, Enum.EasingStyle.Sine, Enum.EasingDirection.In),
		{
			FillTransparency = 1,
			OutlineTransparency = 1,
		}
	)

	fadeIn:Play()

	task.delay(DAMAGE_HIGHLIGHT_FADE_IN + DAMAGE_HIGHLIGHT_HOLD, function()
		if not highlight or not highlight.Parent then
			return
		end

		fadeOut:Play()
		fadeOut.Completed:Once(function()
			if highlight and highlight.Parent then
				highlight:Destroy()
			end
		end)
	end)
end

local function getEnemyMaxHealth(enemy)
	local humanoid = enemy:FindFirstChildOfClass("Humanoid")
	local healthVal = enemy:FindFirstChild("Health")

	if humanoid and humanoid.MaxHealth > 0 then
		return humanoid.MaxHealth
	end

	if healthVal then
		return healthVal.Value
	end

	return 0
end

local function formatHealthText(currentHealth, maxHealth)
	return string.format("%d/%d", math.floor(currentHealth + 0.5), math.floor(maxHealth + 0.5))
end

local function destroyHealthPopup(enemy)
	local state = healthPopupStates[enemy]
	if not state then
		return
	end

	if state.renderConn then
		state.renderConn:Disconnect()
		state.renderConn = nil
	end

	if state.countConn then
		state.countConn:Disconnect()
		state.countConn = nil
	end

	if state.billboard and state.billboard.Parent then
		state.billboard:Destroy()
	end

	healthPopupStates[enemy] = nil
end

local function animateHealthPopupText(state, targetCurrent, targetMax)
	if not state or not state.label or not state.label.Parent then
		return
	end

	targetCurrent = math.max(0, targetCurrent or 0)
	targetMax = math.max(targetCurrent, targetMax or targetCurrent)

	state.targetCurrent = targetCurrent
	state.targetMax = targetMax
	state.displayCurrent = targetCurrent
	state.displayMax = targetMax

	if state.countConn then
		state.countConn:Disconnect()
		state.countConn = nil
	end

	state.label.Text = formatHealthText(targetCurrent, targetMax)
end

local function showHealthPopup(enemy)
	local hrp = enemy:FindFirstChild("HumanoidRootPart") or enemy:FindFirstChild("Head")
	local healthVal = enemy:FindFirstChild("Health")
	if not hrp or not healthVal then
		return
	end

	local currentHealth = healthVal.Value
	local maxHealth = getEnemyMaxHealth(enemy)

	local state = healthPopupStates[enemy]
	if state and state.billboard and state.billboard.Parent then
		state.visible = true
		animateHealthPopupText(state, currentHealth, maxHealth)
		return
	end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "HealthPopup"
	billboard.Adornee = hrp
	billboard.Size = UDim2.fromOffset(120, 30)
	billboard.StudsOffset = Vector3.new(0, HEALTH_POPUP_SHOW_OFFSET_Y - 0.45, 0)
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.MaxDistance = HEALTH_POPUP_MAX_DISTANCE
	billboard.Parent = hrp

	local label = Instance.new("TextLabel")
	label.Name = "HealthText"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = formatHealthText(currentHealth, maxHealth)
	label.FontFace = SILKSCREEN_FONT
	label.TextColor3 = HEALTH_POPUP_GREEN
	label.TextScaled = false
	label.TextSize = HEALTH_POPUP_TEXT_SIZE
	label.TextTransparency = 1
	label.TextStrokeTransparency = 1
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.Parent = billboard

	local uiStroke = Instance.new("UIStroke")
	uiStroke.Color = HEALTH_POPUP_STROKE
	uiStroke.Thickness = 1.5
	uiStroke.Transparency = 1
	uiStroke.Parent = label

	local scale = Instance.new("UIScale")
	scale.Scale = 0.6
	scale.Parent = label

	state = {
		enemy = enemy,
		billboard = billboard,
		label = label,
		uiStroke = uiStroke,
		scale = scale,
		displayCurrent = currentHealth,
		displayMax = maxHealth,
		targetCurrent = currentHealth,
		targetMax = maxHealth,
		visible = true,
	}
	healthPopupStates[enemy] = state

	TweenService:Create(
		billboard,
		TweenInfo.new(HEALTH_POPUP_GROW_TIME, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{StudsOffset = Vector3.new(0, HEALTH_POPUP_SHOW_OFFSET_Y, 0)}
	):Play()

	TweenService:Create(
		label,
		TweenInfo.new(HEALTH_POPUP_GROW_TIME * 0.85, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
		{
			TextTransparency = 0,
		}
	):Play()

	TweenService:Create(
		uiStroke,
		TweenInfo.new(HEALTH_POPUP_GROW_TIME * 0.85, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
		{
			Transparency = 0,
		}
	):Play()

	TweenService:Create(
		scale,
		TweenInfo.new(HEALTH_POPUP_GROW_TIME, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{Scale = 1}
	):Play()

	animateHealthPopupText(state, currentHealth, maxHealth)
end

local function hideHealthPopup(enemy)
	local state = healthPopupStates[enemy]
	if not state or not state.visible then
		return
	end

	state.visible = false

	if state.renderConn then
		state.renderConn:Disconnect()
		state.renderConn = nil
	end

	if state.countConn then
		state.countConn:Disconnect()
		state.countConn = nil
	end

	local fade1 = TweenService:Create(
		state.label,
		TweenInfo.new(HEALTH_POPUP_FADE_TIME, Enum.EasingStyle.Sine, Enum.EasingDirection.In),
		{TextTransparency = 1}
	)

	local fade2 = TweenService:Create(
		state.uiStroke,
		TweenInfo.new(HEALTH_POPUP_FADE_TIME, Enum.EasingStyle.Sine, Enum.EasingDirection.In),
		{Transparency = 1}
	)

	local shrink = TweenService:Create(
		state.scale,
		TweenInfo.new(HEALTH_POPUP_SHRINK_TIME, Enum.EasingStyle.Back, Enum.EasingDirection.In),
		{Scale = 0.82}
	)

	local drop = TweenService:Create(
		state.billboard,
		TweenInfo.new(HEALTH_POPUP_SHRINK_TIME, Enum.EasingStyle.Sine, Enum.EasingDirection.In),
		{StudsOffset = Vector3.new(0, HEALTH_POPUP_SHOW_OFFSET_Y - 0.3, 0)}
	)

	fade1:Play()
	fade2:Play()
	shrink:Play()
	drop:Play()

	task.delay(math.max(HEALTH_POPUP_FADE_TIME, HEALTH_POPUP_SHRINK_TIME) + 0.02, function()
		destroyHealthPopup(enemy)
	end)
end

local function updateNearbyHealthPopups()
	local playerRoots = {}

	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root then
			table.insert(playerRoots, root)
		end
	end

	if #playerRoots == 0 then
		for enemy in pairs(healthPopupStates) do
			hideHealthPopup(enemy)
		end
		return
	end

	for enemy in pairs(activeEnemies) do
		if enemy.Parent then
			updateEnemyClosestWaypointDistance(enemy)

			local hrp = enemy:FindFirstChild("HumanoidRootPart") or enemy:FindFirstChild("Head")
			local healthVal = enemy:FindFirstChild("Health")

			if hrp and healthVal and healthVal.Value > 0 then
				local isNearAnyPlayer = false

				for _, root in ipairs(playerRoots) do
					if (hrp.Position - root.Position).Magnitude <= HEALTH_POPUP_RADIUS then
						isNearAnyPlayer = true
						break
					end
				end

				if isNearAnyPlayer then
					showHealthPopup(enemy)
				else
					hideHealthPopup(enemy)
				end
			else
				hideHealthPopup(enemy)
			end
		else
			hideHealthPopup(enemy)
		end
	end
end

-- ============================================================
-- ENEMY SETUP
-- ============================================================
local function setEnemyCollision(enemy)
	local function apply(part)
		if not part:IsA("BasePart") then
			return
		end

		part.CollisionGroup = ENEMY_COLLISION_GROUP
		part.CanTouch = true
		part.CanQuery = true

		if part.Name == "HumanoidRootPart" then
			part.CanCollide = true
		else
			part.CanCollide = false
		end
	end

	for _, part in ipairs(enemy:GetDescendants()) do
		apply(part)
	end

	enemy.DescendantAdded:Connect(apply)
end

local function tweenEnemyScale(enemy, startScale, endScale, duration, easingStyle, easingDirection)
	if not enemy or not enemy.Parent then
		return nil
	end

	local scaleDriver = Instance.new("NumberValue")
	scaleDriver.Value = startScale

	local conn
	conn = scaleDriver.Changed:Connect(function(value)
		if enemy and enemy.Parent then
			scaleEnemyAtCurrentPivot(enemy, value)
		end
	end)

	scaleEnemyAtCurrentPivot(enemy, startScale)

	local tween = TweenService:Create(
		scaleDriver,
		TweenInfo.new(GameSpeed:ScaleDuration(duration), easingStyle, easingDirection),
		{Value = endScale}
	)

	tween.Completed:Once(function()
		if conn then
			conn:Disconnect()
		end
		if enemy and enemy.Parent then
			scaleEnemyAtCurrentPivot(enemy, endScale)
		end
		scaleDriver:Destroy()
	end)

	tween:Play()
	return tween
end

local function cleanup(enemy)
	if not enemy or not enemy.Parent then
		return
	end

	if cleanupInProgress[enemy] then
		return
	end

	if not activeEnemies[enemy] then
		return
	end

	cleanupInProgress[enemy] = true

	if enemyMoveConnections[enemy] then
		enemyMoveConnections[enemy]:Disconnect()
		enemyMoveConnections[enemy] = nil
	end

	hideHealthPopup(enemy)
	healthPopupStates[enemy] = nil
	EnemyBehaviors.cleanupEnemy(enemy)
	activeEnemies[enemy] = nil
	enemyClosestWaypointDistances[enemy] = nil
	enemyOutcomeLogged[enemy] = nil

	for _, obj in ipairs(enemy:GetDescendants()) do
		if obj:IsA("BasePart") then
			obj.Anchored = true
			obj.CanCollide = false
			obj.CanTouch = false
			obj.CanQuery = false
		end
	end

	local originalScale = enemy:GetAttribute("OriginalVisualScale")
	if typeof(originalScale) ~= "number" or originalScale <= 0 then
		originalScale = enemy:GetScale()
	end

	local endScale = math.max(originalScale * MIN_POP_SCALE_MULT, 0.001)

	if not shouldUseScalePop(enemy) then
		cleanupInProgress[enemy] = nil
		enemy:Destroy()

		maybeFireAllEnemiesDead()

		return
	end

	local tween = tweenEnemyScale(
		enemy,
		enemy:GetScale(),
		endScale,
		DEATH_POP_TIME,
		Enum.EasingStyle.Back,
		Enum.EasingDirection.In
	)

	if tween then
		tween.Completed:Once(function()
			cleanupInProgress[enemy] = nil
			if enemy and enemy.Parent then
				enemy:Destroy()
			end

			maybeFireAllEnemiesDead()
		end)
	else
		cleanupInProgress[enemy] = nil
		if enemy and enemy.Parent then
			enemy:Destroy()
		end

		maybeFireAllEnemiesDead()
	end
end

local function startEnemyMovement(enemy, humanoid, waypoint, debugMove)
	if not enemy or not enemy.Parent or not humanoid or humanoid.Health <= 0 or not waypoint or gameOver then
		return
	end

	if enemyMoveConnections[enemy] then
		enemyMoveConnections[enemy]:Disconnect()
		enemyMoveConnections[enemy] = nil
	end

	local function moveToWaypoint()
		if enemy.Parent and humanoid.Health > 0 and not gameOver then
			humanoid:MoveTo(waypoint.Position)
		end
	end

	enemyMoveConnections[enemy] = humanoid.MoveToFinished:Connect(function(reached)
		if not enemy.Parent or humanoid.Health <= 0 or gameOver then
			if enemyMoveConnections[enemy] then
				enemyMoveConnections[enemy]:Disconnect()
				enemyMoveConnections[enemy] = nil
			end
			return
		end

		if reached then
			recordEnemyLeaked(enemy)
			Comm:Fire("EnemyReached", enemy)
			cleanup(enemy)
		else
			moveToWaypoint()
		end
	end)

	moveToWaypoint()

	if debugMove and shouldDebugEnemy(enemy) and not enemy:GetAttribute("FacingMoveLogged") then
		enemy:SetAttribute("FacingMoveLogged", true)
		task.delay(0.05, function()
			if enemy and enemy.Parent then
				logEnemyFacing("after_first_moveto", enemy, "target=" .. tostring(waypoint.Position))
			end
		end)
	end
end

local function isEnemyTemplate(instance)
	return instance
		and instance:IsA("Model")
		and (
			instance:FindFirstChildOfClass("Humanoid") ~= nil
			or instance:FindFirstChild("Health") ~= nil
			or instance:FindFirstChild("HumanoidRootPart") ~= nil
		)
end

local function isEnemyTemplateValidForRound(enemy, round, ignoreStopAfter)
	local spawnAfter = enemy:FindFirstChild("SpawnAfterRound")
	local stopAfter = enemy:FindFirstChild("StopSpawningAfterRound")

	local minRound = spawnAfter and spawnAfter.Value or 1
	local maxRound = (not ignoreStopAfter and stopAfter) and stopAfter.Value or 0

	return round >= minRound and (maxRound == 0 or round <= maxRound)
end

local function getRoleForDirectEnemy(enemy)
	if ENEMY_NAME_ROLE_FALLBACK[enemy.Name] then
		return ENEMY_NAME_ROLE_FALLBACK[enemy.Name]
	end

	if enemy:FindFirstChild("Runner") then
		return "runner"
	end
	if enemy:FindFirstChild("Support") then
		return "support"
	end
	if enemy.Name == "stonething" then
		return "tank"
	end
	if enemy:FindFirstChild("Splitter") then
		return "advanced"
	end

	return "basic"
end

local function collectEnemyTemplatesForRole(role, round)
	local templates = {}
	local roleFolderName = ROLE_FOLDER_NAMES[role]
	local roleFolder = roleFolderName and enemiesFolder:FindFirstChild(roleFolderName)

	local function collect(ignoreStopAfter)
		local collected = {}

		if roleFolder and not isEnemyTemplate(roleFolder) then
			for _, child in ipairs(roleFolder:GetChildren()) do
				if isEnemyTemplate(child) and isEnemyTemplateValidForRound(child, round, ignoreStopAfter) then
					table.insert(collected, child)
				end
			end
		else
			for _, child in ipairs(enemiesFolder:GetChildren()) do
				if isEnemyTemplate(child)
					and getRoleForDirectEnemy(child) == role
					and isEnemyTemplateValidForRound(child, round, ignoreStopAfter) then
					table.insert(collected, child)
				end
			end
		end

		return collected
	end

	templates = collect(false)

	if #templates == 0 and round > 30 then
		templates = collect(true)
	end

	table.sort(templates, function(a, b)
		return a.Name < b.Name
	end)

	return templates
end

local function findEnemyTemplateByName(enemyName)
	for _, child in ipairs(enemiesFolder:GetChildren()) do
		if child.Name == enemyName and isEnemyTemplate(child) then
			return child
		end

		if not isEnemyTemplate(child) then
			local nested = child:FindFirstChild(enemyName)
			if nested and isEnemyTemplate(nested) then
				return nested
			end
		end
	end

	return nil
end

local function buildHandcraftedSpawnQueue(round)
	local roundPlan = HANDCRAFTED_ROUNDS[round]
	if not roundPlan then
		return nil
	end

	local queue = {}

	for _, entry in ipairs(roundPlan) do
		local enemyName = entry[1]
		local count = entry[2] or 0
		local template = findEnemyTemplateByName(enemyName)

		if template then
			for _ = 1, count do
				table.insert(queue, template)
			end
		else
			warn("Handcrafted round enemy template not found:", enemyName, "round", round)
		end
	end

	return queue
end

local function getRoundRoleBudget(round)
	local clampedRound = math.max(round, 1)
	local firstAnchor = ROUND_ROLE_BUDGET_ANCHORS[1]
	local budget

	if clampedRound <= firstAnchor.round then
		budget = table.clone(firstAnchor.budget)
		return budget
	end

	for i = 2, #ROUND_ROLE_BUDGET_ANCHORS do
		local previous = ROUND_ROLE_BUDGET_ANCHORS[i - 1]
		local nextAnchor = ROUND_ROLE_BUDGET_ANCHORS[i]

		if clampedRound <= nextAnchor.round then
			local alpha = (clampedRound - previous.round) / (nextAnchor.round - previous.round)
			budget = {}

			for _, role in ipairs(ROLE_SPAWN_ORDER) do
				local startValue = previous.budget[role] or 0
				local endValue = nextAnchor.budget[role] or 0
				budget[role] = math.floor(startValue + ((endValue - startValue) * alpha) + 0.5)
			end

			break
		end
	end

	if not budget then
		local lastAnchor = ROUND_ROLE_BUDGET_ANCHORS[#ROUND_ROLE_BUDGET_ANCHORS]
		local extraRounds = clampedRound - lastAnchor.round
		budget = table.clone(lastAnchor.budget)

		budget.basic = (budget.basic or 0) + math.floor(extraRounds / 2)
		budget.runner = (budget.runner or 0) + math.floor(extraRounds / 3)
		budget.advanced = (budget.advanced or 0) + math.floor(extraRounds / 4)
		budget.support = (budget.support or 0) + math.floor(extraRounds / 6)
		budget.tank = (budget.tank or 0) + math.floor(extraRounds / 8)
	end

	if clampedRound == 5 then
		budget.runner = 1
	elseif clampedRound == 10 then
		budget.advanced = 1
		budget.support = 1
	elseif clampedRound == 15 then
		budget = { tank = 1 }
	end

	return budget
end

local function pickEnemyTemplateForRole(role, round)
	local templates = collectEnemyTemplatesForRole(role, round)
	if #templates == 0 then
		return nil
	end

	local cursor = (roleSpawnCursors[role] or 0) + 1
	if cursor > #templates then
		cursor = 1
	end

	roleSpawnCursors[role] = cursor
	return templates[cursor]
end

local function buildSpawnQueueForRound(round)
	local handcraftedQueue = buildHandcraftedSpawnQueue(round)
	if handcraftedQueue then
		return handcraftedQueue
	end

	local budget = getRoundRoleBudget(round)
	local queue = {}
	local hasRemaining = true

	while hasRemaining do
		hasRemaining = false

		for _, role in ipairs(ROLE_SPAWN_ORDER) do
			local count = budget[role] or 0
			if count > 0 then
				hasRemaining = true
				budget[role] = count - 1

				local template = pickEnemyTemplateForRole(role, round)
				if template then
					table.insert(queue, template)
				end
			end
		end
	end

	return queue
end

local function getSpawnDelayForRound(round)
	return math.max(0.35, 1 - ((math.max(round, 1) - 1) * 0.025))
end

local function summarizeSpawnQueue(spawnQueue)
	local counts = {}

	for _, template in ipairs(spawnQueue) do
		counts[template.Name] = (counts[template.Name] or 0) + 1
	end

	local parts = {}
	for enemyName, count in pairs(counts) do
		table.insert(parts, string.format("%s x%d", enemyName, count))
	end
	table.sort(parts)

	return table.concat(parts, ", ")
end

-- ============================================================
-- HEALTH SCALING
-- ============================================================

local LATE_HEALTH_SCALING_START_ROUND = 30
local LATE_HEALTH_LINEAR_PER_ROUND = 0.015
local LATE_HEALTH_EXPONENT_PER_ROUND = 0.002

local function getLateRoundHealthPressure(round)
	local extraRounds = math.max((tonumber(round) or 1) - LATE_HEALTH_SCALING_START_ROUND, 0)
	if extraRounds <= 0 then
		return 1
	end

	return 1 + (extraRounds * LATE_HEALTH_LINEAR_PER_ROUND) + ((1 + LATE_HEALTH_EXPONENT_PER_ROUND) ^ extraRounds - 1)
end

local function getScaledHealth(baseHealth, round)
	local r = math.max(round - 1, 0)
	local multiplier = (1 + ((0.06 * r) / (1 + 0.025 * r))) * getLateRoundHealthPressure(round)
	return math.floor(baseHealth * multiplier + 0.5)
end

local function getScaledHealthWithMultiplier(baseHealth, round, scalingMultiplier)
	local r = math.max(round - 1, 0)
	local multiplier = (1 + (((0.06 * r) / (1 + 0.025 * r)) * scalingMultiplier)) * getLateRoundHealthPressure(round)
	return math.floor(baseHealth * multiplier + 0.5)
end

local function isTankEnemy(enemy)
	return enemy and ENEMY_NAME_ROLE_FALLBACK[enemy.Name] == "tank"
end

local function getScaledHealthForEnemy(baseHealth, round, enemy)
	if isTankEnemy(enemy) then
		local tankScalingRound = math.max(1, round - FIRST_TANK_ROUND + 1)
		return getScaledHealth(baseHealth, tankScalingRound)
	end

	if enemy and enemy.Name == "RockMan" then
		local rockmanScalingRound = math.max(1, round - FIRST_ROCKMAN_ROUND + 1)
		local rockmanBaseHealth = math.min(baseHealth, ROCKMAN_FIRST_SPAWN_MAX_HEALTH)
		return getScaledHealthWithMultiplier(
			rockmanBaseHealth,
			rockmanScalingRound,
			ROCKMAN_HEALTH_SCALING_MULTIPLIER
		)
	end

	return getScaledHealth(baseHealth, round)
end

local function awardEnemyKillCash(round)
	local reward = 1
	if round >= 45 then
		reward = 3
	elseif round >= 15 then
		reward = 2
	end

	for _, player in ipairs(Players:GetPlayers()) do
		local gained = CashService:Add(player, reward, { suppressBurst = true })
		BalanceLogger:RecordKillCash(player, gained)
	end
end

local function getEnemyName(enemy)
	return enemy and enemy.Name or "Unknown"
end

local function getEnemyPosition(enemy)
	if not enemy or not enemy.Parent then
		return nil
	end

	local hrp = enemy:FindFirstChild("HumanoidRootPart") or enemy:FindFirstChild("Head")
	if hrp and hrp:IsA("BasePart") then
		return hrp.Position
	end

	return enemy:GetPivot().Position
end

function updateEnemyClosestWaypointDistance(enemy)
	local position = getEnemyPosition(enemy)
	if not position then
		return
	end

	local distance = (position - waypartRef.Position).Magnitude
	local previous = enemyClosestWaypointDistances[enemy]
	if previous == nil or distance < previous then
		enemyClosestWaypointDistances[enemy] = distance
	end
end

function recordEnemyKilled(enemy)
	if enemyOutcomeLogged[enemy] then
		return
	end

	enemyOutcomeLogged[enemy] = true
	updateEnemyClosestWaypointDistance(enemy)

	local closestDistance = enemyClosestWaypointDistances[enemy]
	for _, player in ipairs(Players:GetPlayers()) do
		BalanceLogger:RecordEnemyKilled(player, getEnemyName(enemy), closestDistance)
	end
	RunStats:RecordEnemyKilled(getEnemyName(enemy))
end

function recordEnemyLeaked(enemy)
	if enemyOutcomeLogged[enemy] then
		return
	end

	enemyOutcomeLogged[enemy] = true

	for _, player in ipairs(Players:GetPlayers()) do
		BalanceLogger:RecordEnemyLeaked(player, getEnemyName(enemy))
	end
	RunStats:RecordEnemyLeaked(getEnemyName(enemy))
end

local function configureRockManSpeed(enemy, speedVal)
	if not enemy or enemy.Name ~= "RockMan" or not speedVal then
		return false
	end

	speedVal.Value = ROCKMAN_START_SPEED
	enemy:SetAttribute("BaseSpeed", ROCKMAN_MAX_SPEED)
	enemy:SetAttribute("RockManSpeedRampActive", true)

	task.spawn(function()
		local startedAt = tick()

		while enemy.Parent and speedVal.Parent and enemy:GetAttribute("RockManSpeedRampActive") do
			local alpha = math.clamp(((tick() - startedAt) * GameSpeed:Get()) / ROCKMAN_SPEED_RAMP_TIME, 0, 1)
			speedVal.Value = ROCKMAN_START_SPEED + ((ROCKMAN_MAX_SPEED - ROCKMAN_START_SPEED) * alpha)

			if alpha >= 1 then
				break
			end

			task.wait(GameSpeed:ScaleDuration(0.2))
		end

		if enemy.Parent and speedVal.Parent then
			speedVal.Value = ROCKMAN_MAX_SPEED
			enemy:SetAttribute("RockManSpeedRampActive", false)
		end
	end)

	return true
end

local function spawnSplitterEnemy(enemyName, position, waypoint, round)
	if gameOver then
		return
	end

	local template = findEnemyTemplateByName(enemyName)
	if not template then
		warn("Splitter enemy template not found:", enemyName)
		return
	end

	local enemy = template:Clone()
	logEnemyFacing("split_template_clone", enemy)
	local hrp = normalizeEnemyPrimaryPart(enemy)
	if not hrp then
		enemy:Destroy()
		return
	end

	local humanoid = enemy:FindFirstChildOfClass("Humanoid")
	local healthVal = enemy:FindFirstChild("Health")

	if healthVal then
		local scaledHealth = getScaledHealthForEnemy(healthVal.Value, round, enemy)
		local devHealthOverride = game.ReplicatedStorage:GetAttribute("DevEnemyHealthOverride")
		if typeof(devHealthOverride) == "number" and devHealthOverride > 0 then
			scaledHealth = devHealthOverride
		end
		healthVal.Value = scaledHealth

		if humanoid then
			humanoid.MaxHealth = scaledHealth
			humanoid.Health = scaledHealth
		end

		enemy:SetAttribute("BaseMaxHealth", scaledHealth)
	end

	enemy.Parent = workspace
	logEnemyFacing("split_parented", enemy)

	local originalScale = enemy:GetScale()
	if typeof(originalScale) ~= "number" or originalScale <= 0 then
		originalScale = 1
	end
	enemy:SetAttribute("OriginalVisualScale", originalScale)

	for _, obj in ipairs(enemy:GetDescendants()) do
		if obj:IsA("BasePart") then
			obj.Anchored = true
		end
	end

	enemy:PivotTo(CFrame.new(position))
	orientEnemyTowards(enemy, waypoint.Position)
	logEnemyFacing("split_after_pivot", enemy)

	if shouldUseScalePop(enemy) then
		local startScale = math.max(originalScale * MIN_POP_SCALE_MULT, 0.001)
		tweenEnemyScale(
			enemy,
			startScale,
			originalScale,
			SPAWN_POP_TIME,
			Enum.EasingStyle.Back,
			Enum.EasingDirection.Out
		)
	end

	task.defer(function()
		if not enemy or not enemy.Parent then
			return
		end

		for _, obj in ipairs(enemy:GetDescendants()) do
			if obj:IsA("BasePart") then
				obj.Anchored = false
			end
		end

		if hrp and hrp.Parent then
			hrp.CanCollide = false
		end

		if humanoid then
			humanoid:ChangeState(Enum.HumanoidStateType.Running)
			humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
			humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
			humanoid:SetStateEnabled(Enum.HumanoidStateType.Physics, false)
		end
		logEnemyFacing("split_after_unanchor", enemy)
	end)

	setEnemyCollision(enemy)
	logEnemyFacing("split_after_set_collision", enemy)
	activeEnemies[enemy] = true
	updateEnemyClosestWaypointDistance(enemy)

	local speedVal = enemy:FindFirstChild("Speed")
	if not speedVal then
		speedVal = Instance.new("IntValue")
		speedVal.Name = "Speed"
		speedVal.Value = 16
		speedVal.Parent = enemy
	end

	EnemyBehaviors.initEnemy(enemy)
	local hasCustomSpeedRamp = configureRockManSpeed(enemy, speedVal)

	if not hasCustomSpeedRamp and typeof(enemy:GetAttribute("BaseSpeed")) ~= "number" then
		enemy:SetAttribute("BaseSpeed", speedVal.Value)
	end

	if humanoid and typeof(enemy:GetAttribute("BaseMaxHealth")) ~= "number" then
		enemy:SetAttribute("BaseMaxHealth", humanoid.MaxHealth)
	end

	if humanoid then
		humanoid.WalkSpeed = 0
		if getEnemyFacingOffsetRadians(enemy) ~= 0 then
			humanoid.AutoRotate = false
		end
	end

	speedVal.Changed:Connect(function(newSpeed)
		if humanoid and humanoid.Parent and humanoid.Health > 0 then
			humanoid.WalkSpeed = getScaledEnemySpeed(newSpeed)
		end
	end)

	if humanoid then
		local anim = Instance.new("Animation")
		anim.AnimationId = WALK_ANIM
		local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid)
		local track = animator:LoadAnimation(anim)
		track:Play()
		track:AdjustSpeed(GameSpeed:Get())
	end

	if healthVal then
		local prevHealth = healthVal.Value
		healthVal.Changed:Connect(function(newHealth)
			local damage = prevHealth - newHealth
			if damage > 0 then
				showDamagePopup(enemy, damage)
				playEnemyHitSound(enemy)
				playEnemyDamageHighlight(enemy)
			end

			local state = healthPopupStates[enemy]
			if state then
				animateHealthPopupText(state, newHealth, getEnemyMaxHealth(enemy))
			end

			prevHealth = newHealth
		end)
	end

	if humanoid then
		humanoid.Died:Connect(function()
			enemiesKilled += 1
			recordEnemyKilled(enemy)
			awardEnemyKillCash(round)
			task.wait(GameSpeed:ScaleDuration(0.5))
			cleanup(enemy)
		end)

		task.spawn(function()
			task.wait(GameSpeed:ScaleDuration(SPAWN_POP_TIME))

			if not enemy.Parent or humanoid.Health <= 0 or gameOver then
				return
			end

			local speedValNow = enemy:FindFirstChild("Speed")
			if speedValNow then
				humanoid.WalkSpeed = getScaledEnemySpeed(speedValNow.Value)
			end

			startEnemyMovement(enemy, humanoid, waypoint, false)
		end)
	end
end

local function spawnEnemy(spawnPart, waypoint, enemyList, round)
	if gameOver then return end
	if #enemyList == 0 then return end

	local template = enemyList[math.random(1, #enemyList)]
	local enemy = template:Clone()
	logEnemyFacing("template_clone", enemy)
	local hrp = normalizeEnemyPrimaryPart(enemy)
	if not hrp then
		enemy:Destroy()
		return
	end

	local humanoid = enemy:FindFirstChildOfClass("Humanoid")
	local healthVal = enemy:FindFirstChild("Health")

	if healthVal then
		local scaledHealth = getScaledHealthForEnemy(healthVal.Value, round, enemy)
		local devHealthOverride = game.ReplicatedStorage:GetAttribute("DevEnemyHealthOverride")
		if typeof(devHealthOverride) == "number" and devHealthOverride > 0 then
			scaledHealth = devHealthOverride
		end
		healthVal.Value = scaledHealth

		if humanoid then
			humanoid.MaxHealth = scaledHealth
			humanoid.Health = scaledHealth
		end

		enemy:SetAttribute("BaseMaxHealth", scaledHealth)
	end

	enemy.Parent = workspace
	logEnemyFacing("parented", enemy)

	local originalScale = enemy:GetScale()
	if typeof(originalScale) ~= "number" or originalScale <= 0 then
		originalScale = 1
	end
	enemy:SetAttribute("OriginalVisualScale", originalScale)

	for _, obj in ipairs(enemy:GetDescendants()) do
		if obj:IsA("BasePart") then
			obj.Anchored = true
		end
	end

	enemy:PivotTo(spawnPart.CFrame + Vector3.new(0, 8, 0))
	orientEnemyTowards(enemy, waypoint.Position)
	logEnemyFacing("after_pivot", enemy, "spawnPart=" .. spawnPart:GetFullName())

	if shouldUseScalePop(enemy) then
		local startScale = math.max(originalScale * MIN_POP_SCALE_MULT, 0.001)
		tweenEnemyScale(
			enemy,
			startScale,
			originalScale,
			SPAWN_POP_TIME,
			Enum.EasingStyle.Back,
			Enum.EasingDirection.Out
		)
	end

	task.defer(function()
		if not enemy or not enemy.Parent then
			return
		end

		for _, obj in ipairs(enemy:GetDescendants()) do
			if obj:IsA("BasePart") then
				obj.Anchored = false
			end
		end

		if hrp and hrp.Parent then
			hrp.CanCollide = false
		end

		if humanoid then
			humanoid:ChangeState(Enum.HumanoidStateType.Running)
			humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
			humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
			humanoid:SetStateEnabled(Enum.HumanoidStateType.Physics, false)
		end

		logEnemyFacing("after_unanchor", enemy)
	end)

	setEnemyCollision(enemy)
	logEnemyFacing("after_set_collision", enemy)
	activeEnemies[enemy] = true
	updateEnemyClosestWaypointDistance(enemy)

	local speedVal = enemy:FindFirstChild("Speed")
	if not speedVal then
		speedVal = Instance.new("IntValue")
		speedVal.Name = "Speed"
		speedVal.Value = 16
		speedVal.Parent = enemy
	end

	EnemyBehaviors.initEnemy(enemy)
	local hasCustomSpeedRamp = configureRockManSpeed(enemy, speedVal)

	if not hasCustomSpeedRamp and typeof(enemy:GetAttribute("BaseSpeed")) ~= "number" then
		enemy:SetAttribute("BaseSpeed", speedVal.Value)
	end

	if humanoid and typeof(enemy:GetAttribute("BaseMaxHealth")) ~= "number" then
		enemy:SetAttribute("BaseMaxHealth", humanoid.MaxHealth)
	end

	if humanoid then
		humanoid.WalkSpeed = 0
		if getEnemyFacingOffsetRadians(enemy) ~= 0 then
			humanoid.AutoRotate = false
		end
	end

	speedVal.Changed:Connect(function(newSpeed)
		if humanoid and humanoid.Parent then
			humanoid.WalkSpeed = getScaledEnemySpeed(newSpeed)
		end
	end)

	if humanoid then
		local anim = Instance.new("Animation")
		anim.AnimationId = WALK_ANIM
		local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid)
		local track = animator:LoadAnimation(anim)
		track:Play()
		track:AdjustSpeed(GameSpeed:Get())
	end

	if healthVal then
		local prevHealth = healthVal.Value
		healthVal.Changed:Connect(function(newHealth)
			local damage = prevHealth - newHealth
			if damage > 0 then
				showDamagePopup(enemy, damage)
				playEnemyHitSound(enemy)
				playEnemyDamageHighlight(enemy)
			end

			local state = healthPopupStates[enemy]
			if state then
				animateHealthPopupText(state, newHealth, getEnemyMaxHealth(enemy))
			end

			prevHealth = newHealth
		end)
	end

	if humanoid then
		humanoid.Died:Connect(function()
			enemiesKilled += 1
			recordEnemyKilled(enemy)
			awardEnemyKillCash(round)

			local splitter = enemy:FindFirstChild("Splitter")
			if splitter and splitter:IsA("StringValue") and splitter.Value ~= "" then
				local deathPos = hrp and hrp.Position or enemy:GetPivot().Position
				spawnSplitterEnemy(splitter.Value, deathPos, waypoint, round)
			end

			task.wait(GameSpeed:ScaleDuration(0.5))
			cleanup(enemy)
		end)

		task.spawn(function()
			task.wait(GameSpeed:ScaleDuration(SPAWN_POP_TIME))

			if not enemy.Parent or humanoid.Health <= 0 or gameOver then
				return
			end

			local speedValNow = enemy:FindFirstChild("Speed")
			if speedValNow then
				humanoid.WalkSpeed = getScaledEnemySpeed(speedValNow.Value)
			end
			orientEnemyTowards(enemy, waypoint.Position)
			logEnemyFacing("before_first_moveto", enemy, "waypoint=" .. waypoint:GetFullName())

			startEnemyMovement(enemy, humanoid, waypoint, true)
		end)
	end
end

GameSpeed:GetValueObject().Changed:Connect(function()
	for enemy in pairs(activeEnemies) do
		applyCurrentGameSpeedToEnemy(enemy)
	end
end)

waypartRef.Touched:Connect(function(hit)
	if gameOver then return end
	local model = hit:FindFirstAncestorOfClass("Model")
	if model and activeEnemies[model] then
		recordEnemyLeaked(model)
		Comm:Fire("EnemyReached", model)
		cleanup(model)
	end
end)

local healthPopupScanElapsed = 0
RunService.Heartbeat:Connect(function(dt)
	healthPopupScanElapsed += dt
	if healthPopupScanElapsed < HEALTH_POPUP_SCAN_INTERVAL then
		return
	end

	healthPopupScanElapsed = 0
	updateNearbyHealthPopups()
end)

Comm:On("RoundStart", function(data)
	if gameOver then return end
	roundSpawnToken += 1
	local spawnToken = roundSpawnToken
	roundSpawning = true
	roundClearFired = false

	local round = data.round
	local spawns = data.spawns
	local waypoint = data.waypoint
	local spawnQueue = buildSpawnQueueForRound(round)
	local spawnDelay = getSpawnDelayForRound(round)

	if not spawns or #spawns == 0 or not waypoint then
		warn("Round enemy spawn failed: missing spawns or waypoint")
		roundSpawning = false
		maybeFireAllEnemiesDead()
		return
	end

	if #spawnQueue == 0 then
		warn("Round enemy spawn failed: no valid enemies for round", round)
		roundSpawning = false
		maybeFireAllEnemiesDead()
		return
	end

	print(string.format(
		"[Balance] Round %d spawn queue: %s",
		round,
		summarizeSpawnQueue(spawnQueue)
	))

	for i, template in ipairs(spawnQueue) do
		if gameOver or spawnToken ~= roundSpawnToken then return end
		local sp = spawns[((i - 1) % #spawns) + 1]
		spawnEnemy(sp, waypoint, { template }, round)
		if round == FIRST_TANK_ROUND and template.Name == FIRST_BOSS_NAME then
			Comm:Fire("FirstBossSpawned")
		end
		if i < #spawnQueue then
			task.wait(GameSpeed:ScaleDuration(spawnDelay))
		end
	end

	if spawnToken == roundSpawnToken then
		roundSpawning = false
		maybeFireAllEnemiesDead()
	end
end)

DevSpawnEnemiesRemote.OnServerEvent:Connect(function()
	if gameOver or devSpawnBusy then
		return
	end

	local roundsFolder = workspace:FindFirstChild("Rounds")
	local spawnPart = roundsFolder and roundsFolder:FindFirstChild("SpawnPart")
	local waypoint = workspace:FindFirstChild("Waypoint")
	if not spawnPart or not waypoint then
		warn("Dev enemy spawn failed: missing Workspace.Rounds.SpawnPart or Workspace.Waypoint")
		return
	end

	local spawnQueue = buildSpawnQueueForRound(1)
	if #spawnQueue == 0 then
		warn("Dev enemy spawn failed: no valid enemies for round 1")
		return
	end

	devSpawnBusy = true
	task.spawn(function()
		for i = 1, 5 do
			if gameOver then
				break
			end

			local template = spawnQueue[((i - 1) % math.max(#spawnQueue, 1)) + 1]
			if template then
				spawnEnemy(spawnPart, waypoint, { template }, 1)
			end
			task.wait(GameSpeed:ScaleDuration(0.5))
		end

		devSpawnBusy = false
	end)
end)

Comm:On("RoundEnd", function()
	roundSpawnToken += 1
	roundSpawning = false
	roundClearFired = true

	for enemy in pairs(activeEnemies) do
		cleanup(enemy)
	end
	table.clear(healthPopupStates)
end)

Comm:On("GameOver", function()
	gameOver = true
	roundSpawnToken += 1
	roundSpawning = false
	roundClearFired = true

	for enemy in pairs(activeEnemies) do
		cleanup(enemy)
	end
	table.clear(healthPopupStates)
end)

Comm:On("GetEnemiesKilled", function(callback)
	callback(enemiesKilled)
end)
