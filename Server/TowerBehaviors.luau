local TowerBehaviors = {}
local started = false

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local GameSpeed = require(ReplicatedStorage:WaitForChild("GameSpeed"))
local EnemyBehaviors = require(script.Parent:WaitForChild("EnemyBehaviors"))
local ResourceMiningService = require(script.Parent:WaitForChild("ResourceMiningService"))
local TowerSpatialIndex = require(script.Parent:WaitForChild("TowerSpatialIndex"))
local RunStats = require(script.Parent:WaitForChild("RunStats"))
local WarningRemote = ReplicatedStorage:WaitForChild("WarningRemote")
local placedTowersFolder = workspace:FindFirstChild("PlacedTowers")

if not placedTowersFolder then
	placedTowersFolder = Instance.new("Folder")
	placedTowersFolder.Name = "PlacedTowers"
	placedTowersFolder.Parent = workspace
end

burningEnemies = {}
local LIGHTNING_STRIKE_SOUND_ID = "rbxassetid://112988499630602"
local LIGHTNING_STRIKE_SOUND_VOLUME = 2
local activeTowers = {}
local activeEnemies = {}
local enemySpatial
local serverTiming = {
	conductivityCleanupInterval = 0.2,
	conductivityCleanupElapsed = 0,
}
local BOMB_TEMPLATE = ReplicatedStorage:WaitForChild("Bomb")
local LIGHTNING_BOLT_TEMPLATE = ReplicatedStorage:WaitForChild("LightningBolt")
local MINEFIELD_EXPLOSION_SOUND_ID = "rbxassetid://140605317844579"
local MINEFIELD_EXPLOSION_SOUND_VOLUME = 2
local MINEFIELD_EXPLOSION_SOUND_MIN_DISTANCE = 10
local MINEFIELD_EXPLOSION_SOUND_MAX_DISTANCE = 90
local BOMB_UPRIGHT_ROTATION = CFrame.Angles(math.rad(-90), math.rad(180), 0)
enemySlowStates = {}
local CORE_TEMPLATE = ReplicatedStorage:WaitForChild("Core")
local DISTORTION_ZONE_TEMPLATE = ReplicatedStorage:WaitForChild("DistortionZone")
magnetFieldVisuals = {}
staticFieldAffectedEnemies = {}
local SPARKS_EMITTER_TEMPLATE = ReplicatedStorage:WaitForChild("Sparks")
teslaBombs = {}
teslaBombLastSpawn = {}
spikeStormLastCast = {}
spikeAttackCounts = {}
spikeOverdriveStacks = {}
spikeLastActiveAt = {}
spikeBarbStates = setmetatable({}, { __mode = "k" })
spikeBleedStates = setmetatable({}, { __mode = "k" })
lastAttackTime = {}
currentTargets = {}
targetingModes = {}
oilSprayFollowers = {}
oilPuddleCooldownUntil = {}
oilPuddles = {}
oilCoatedEnemies = setmetatable({}, { __mode = "k" })
oilAttackCounts = setmetatable({}, { __mode = "k" })
oilRefineryBoostUntil = setmetatable({}, { __mode = "k" })
firePuddleTickAt = setmetatable({}, { __mode = "k" })
firePuddleBurnUntil = setmetatable({}, { __mode = "k" })
firePuddleBurnDamage = setmetatable({}, { __mode = "k" })
normalFireTickAt = setmetatable({}, { __mode = "k" })
normalFireUntil = setmetatable({}, { __mode = "k" })
towerAnimators = {}
activePoisonedEnemies = {}
local METALLIC_TAG_TEMPLATE = ReplicatedStorage:WaitForChild("Metallic")
conductiveEnemies = {}
animCooldown = {}
towerStateCache = {}
staticFieldUpdateElapsed = 0
supportHealingUpdateElapsed = 0
magnetFieldVisualUpdateElapsed = 0
distortionAppliedEnemies = {}
electromagneticStormLastPulse = {}
poisonedEnemies = {}
slowedEnemies = {}
tankKnockbackUntil = {}
tankSlowImmuneUntil = {}
disturbanceHitUntil = {}
local knockbackLastApplied = setmetatable({}, { __mode = "k" })
burningEnemyCounts = {}
acidRainLastCast = {}
extractorRuntime = {
	lastMine = {},
	runStartedAt = {},
	startingHeat = {},
	shutdownUntil = {},
	lastRestartRequest = {},
	restartUntil = {},
	restartCooldownUntil = {},
	overheatWarned = {},
}
local EXTRACTOR_OVERHEAT_HEAT = 100
magnetAttackCounts = {}
local ACID_RAIN_CLOUD_TEMPLATE = ReplicatedStorage:WaitForChild("AcidRainCloud")
local ACID_RAIN_BASE_PART = workspace:WaitForChild("Waypoint")
local FIRE_EMITTER_TEMPLATE = ReplicatedStorage:WaitForChild("Fire")
local CANNON_ANIM_ID = "rbxassetid://111449585721986"
local MUSHROOM_ANIM_ID = "rbxassetid://140697529177861"
local MAGNET_ANIM_ID = "rbxassetid://120049389348105"
local OIL_LAUNCHER_ANIM_ID = "rbxassetid://95023831521966"
local BALL_LIGHTNING_TEMPLATE = ReplicatedStorage:WaitForChild("BallLightning")
local BALL_LIGHTNING_PATHS_FOLDER = workspace:WaitForChild("BallLightningPaths")

teslaOrbitBalls = {}
teslaSeekerBalls = {}
teslaMarkedEnemies = {}
teslaStormBalls = {}
local ANIM_DURATION = 0.6
local BALL_DEPLOY_TIME = 0.2
local BALL_TRAVEL_TIME = 0.35
local CANNON_PIERCE_HIT_RADIUS = 4
local SPIKE_INITIAL_SPEED = 58
local SPIKE_MIN_INITIAL_SPEED = 34
local SPIKE_MAX_INITIAL_SPEED = 92
local SPIKE_GRAVITY = 52
local SPIKE_MAX_TRAVEL_TIME = 2.4
local SPIKE_HIT_RADIUS = 4
local SPIKE_RELOAD_DISTANCE = 2.6
local SPIKE_RELOAD_TIME = 0.28
local SPIKE_STORM_FALL_HEIGHT = 28
local SPIKE_STORM_FALL_TIME = 0.42
local OIL_SPLASH_RADIUS = 9
local OIL_PARTICLE_START_TIME = 1.75
local OIL_PARTICLE_END_TIME = 2
local OIL_PUDDLE_FADE_DELAY = 0.2
local OIL_PUDDLE_FADE_TIME = 0.25
local OIL_PUDDLE_ACTIVE_TIME = 5
local OIL_PUDDLE_POST_COOLDOWN = 5
local OIL_PROJECTILE_TIME = OIL_PUDDLE_FADE_DELAY
OIL_COAT_COLOR = Color3.fromRGB(18, 14, 8)
FIRE_PUDDLE_DAMAGE_PER_SECOND = 50
FIRE_PUDDLE_BURN_DURATION = 4
NORMAL_FIRE_DAMAGE_PER_SECOND = 10
NORMAL_FIRE_DURATION = 5
OIL_PUDDLE_CHECK_INTERVAL = 0.15
OIL_PUDDLE_DELETE_DELAY_AFTER_FIRE_OUT = 7
oilPuddleCheckElapsed = 0

local CANNON_SHOT_SOUND_ID = "rbxassetid://98284966008566"
local CANNON_SHOT_VOLUME = 1.4
local CANNON_SHOT_MIN_DISTANCE = 12
local CANNON_SHOT_MAX_DISTANCE = 90

local MUSHROOM_ATTACK_SOUND_ID = "rbxassetid://86773745820123"
local MUSHROOM_ATTACK_VOLUME = 1.2
local MUSHROOM_ATTACK_MIN_DISTANCE = 10
local MUSHROOM_ATTACK_MAX_DISTANCE = 70

local MAGNET_ATTACK_SOUND_ID = "rbxassetid://98311103128742"
local MAGNET_ATTACK_VOLUME = 1.15
local MAGNET_ATTACK_MIN_DISTANCE = 10
local MAGNET_ATTACK_MAX_DISTANCE = 75
local MAGNET_ATTACK_FADE_TIME = 0.25

local TESLA_ATTACK_SOUND_ID = "rbxassetid://136212174420922"
local TESLA_ATTACK_VOLUME = 1.15
local TESLA_ATTACK_MIN_DISTANCE = 10
local TESLA_ATTACK_MAX_DISTANCE = 80
local TESLA_ATTACK_FADE_TIME = 0.25
local MIN_DEBUFFED_SPEED = 10
local DISTORTION_SPEED_MULTIPLIER = 0.9
local DISTURBANCE_HIT_LOCKOUT = 2.9
local TANK_ENEMY_NAMES = {
	stonething = true,
}
local TANK_KNOCKBACK_MULTIPLIER = 0.2
local TANK_KNOCKBACK_COOLDOWN = 1.4
local GENERAL_KNOCKBACK_COOLDOWN = 0.5
local TANK_MAGNET_SLOW_DIVISOR_MULTIPLIER = 0.35
local TANK_MAX_MAGNET_SLOW_DURATION = 0.8
local TANK_MAGNET_SLOW_REAPPLY_COOLDOWN = 1.2
local TANK_MAX_IMMOBILIZE_DURATION = 0

local function isTankEnemy(enemy)
	return enemy and TANK_ENEMY_NAMES[enemy.Name] == true
end

local function isEnemy(model)
	if not model:IsA("Model") then
		return false
	end

	if not model:FindFirstChildOfClass("Humanoid") then
		return false
	end

	if Players:GetPlayerFromCharacter(model) then
		return false
	end

	return true
end

local function isEnemyAlive(enemy)
	if not enemy or not enemy.Parent then
		return false
	end

	local hrp = enemy:FindFirstChild("HumanoidRootPart")
	local healthVal = enemy:FindFirstChild("Health")
	return hrp ~= nil and healthVal ~= nil and healthVal.Value > 0
end

local function isTower(obj)
	return obj:FindFirstChild("TowerType")
		or obj:FindFirstChild("ExtractorEnabled")
		or obj.Name == "Extractor"
		or (obj:FindFirstChild("Radius")
		and obj:FindFirstChild("Damage")
		and obj:FindFirstChild("AttackSpeed"))
end

local function getTowerType(tower)
	local tag = tower:FindFirstChild("TowerType")
	return tag and tag.Value or nil
end

local function getAnimIdForType(towerType)
	if towerType == "Cannon" then
		return CANNON_ANIM_ID
	end

	if towerType == "Mushroom" then
		return MUSHROOM_ANIM_ID
	end

	if towerType == "Magnet" then
		return MAGNET_ANIM_ID
	end

	if towerType == "Oil Launcher" then
		return OIL_LAUNCHER_ANIM_ID
	end

	return nil
end
local function buildTowerState(tower)
	return {
		staticFieldSpeedMultiplierVal = tower:FindFirstChild("StaticFieldSpeedMultiplier"),
		conductivityEnabledVal = tower:FindFirstChild("ConductivityEnabled"),
		conductivityDurationVal = tower:FindFirstChild("ConductivityDuration"),
		rewiredEnabledVal = tower:FindFirstChild("RewiredEnabled"),
		hivemindEnabledVal = tower:FindFirstChild("HivemindEnabled"),
		minefieldEnabledVal = tower:FindFirstChild("MinefieldEnabled"),
		minefieldSpawnIntervalVal = tower:FindFirstChild("MinefieldSpawnInterval"),
		minefieldFuseTimeVal = tower:FindFirstChild("MinefieldFuseTime"),
		minefieldBombRadiusVal = tower:FindFirstChild("MinefieldBombRadius"),
		minefieldBombDamagePercentVal = tower:FindFirstChild("MinefieldBombDamagePercent"),
		minefieldBombCountVal = tower:FindFirstChild("MinefieldBombCount"),
		minefieldInstantExplodeVal = tower:FindFirstChild("MinefieldInstantExplode"),
		minefieldBounceEnabledVal = tower:FindFirstChild("MinefieldBounceEnabled"),
		minefieldBounceChanceVal = tower:FindFirstChild("MinefieldBounceChance"),
		minefieldBounceDamagePercentVal = tower:FindFirstChild("MinefieldBounceDamagePercent"),
		ballLightningOrbitEnabledVal = tower:FindFirstChild("BallLightningOrbitEnabled"),
		ballLightningRadiusVal = tower:FindFirstChild("BallLightningRadius"),
		ballLightningPulseCooldownVal = tower:FindFirstChild("BallLightningPulseCooldown"),
		ballLightningOrbitDamagePercentVal = tower:FindFirstChild("BallLightningOrbitDamagePercent"),
		ballLightningOrbitSpeedVal = tower:FindFirstChild("BallLightningOrbitSpeed"),
		lightningMarkEnabledVal = tower:FindFirstChild("LightningMarkEnabled"),
		lightningMarkSpawnIntervalVal = tower:FindFirstChild("LightningMarkSpawnInterval"),
		lightningMarkSeekerSpeedVal = tower:FindFirstChild("LightningMarkSeekerSpeed"),
		lightningMarkImpactMultiplierVal = tower:FindFirstChild("LightningMarkImpactMultiplier"),
		lightningStormEnabledVal = tower:FindFirstChild("LightningStormEnabled"),
		lightningStormDamagePercentVal = tower:FindFirstChild("LightningStormDamagePercent"),
		lightningStormPathSpeedVal = tower:FindFirstChild("LightningStormPathSpeed"),
		distortionZoneEnabledVal = tower:FindFirstChild("DistortionZoneEnabled"),
		electromagneticStormEnabledVal = tower:FindFirstChild("ElectromagneticStormEnabled"),
		electromagneticStormIntervalVal = tower:FindFirstChild("ElectromagneticStormInterval"),
		electromagneticStormKnockbackVal = tower:FindFirstChild("ElectromagneticStormKnockback"),
		towerType = getTowerType(tower),
		radiusVal = tower:FindFirstChild("Radius"),
		damageVal = tower:FindFirstChild("Damage"),
		attackSpeedVal = tower:FindFirstChild("AttackSpeed"),
		poisonousVal = tower:FindFirstChild("Poisonous"),
		poisonAttackSpeedVal = tower:FindFirstChild("PoisonAttackSpeed"),
		poisonDurationVal = tower:FindFirstChild("PoisonDuration"),
		fireDamageVal = tower:FindFirstChild("FireDamage"),
		rockBonusDamageVal = tower:FindFirstChild("RockBonusDamage"),
		knockbackStudsVal = tower:FindFirstChild("KnockbackStuds"),
		shotsPerAttackVal = tower:FindFirstChild("ShotsPerAttack"),
		explosionChanceVal = tower:FindFirstChild("ExplosionChance"),
		explosionRadiusVal = tower:FindFirstChild("ExplosionRadius"),
		explosionMaxTargetsVal = tower:FindFirstChild("ExplosionMaxTargets"),
		explosionDamageVal = tower:FindFirstChild("ExplosionDamage"),
		poisonTargetsVal = tower:FindFirstChild("PoisonTargets"),
		acidRainEnabledVal = tower:FindFirstChild("AcidRainEnabled"),
		acidRainIntervalVal = tower:FindFirstChild("AcidRainInterval"),
		acidRainDurationVal = tower:FindFirstChild("AcidRainDuration"),
		acidRainDamageVal = tower:FindFirstChild("AcidRainDamage"),
		acidRainTickRateVal = tower:FindFirstChild("AcidRainTickRate"),
		slowDurationVal = tower:FindFirstChild("SlowDuration"),
		spikeStoneDamageMultiplierVal = tower:FindFirstChild("SpikeStoneDamageMultiplier"),
		spikeShatterTargetsVal = tower:FindFirstChild("SpikeShatterTargets"),
		spikeShatterDamageMultiplierVal = tower:FindFirstChild("SpikeShatterDamageMultiplier"),
		spikePierceCountVal = tower:FindFirstChild("SpikePierceCount"),
		spikePierceRangeVal = tower:FindFirstChild("SpikePierceRange"),
		spikePierceDamageFalloffVal = tower:FindFirstChild("SpikePierceDamageFalloff"),
		spikeShotsPerAttackVal = tower:FindFirstChild("SpikeShotsPerAttack"),
		spikeEveryNthAttackVal = tower:FindFirstChild("SpikeEveryNthAttack"),
		spikeExtraRandomShotsVal = tower:FindFirstChild("SpikeExtraRandomShots"),
		spikeOverdriveStepVal = tower:FindFirstChild("SpikeOverdriveStep"),
		spikeOverdriveMaxVal = tower:FindFirstChild("SpikeOverdriveMax"),
		spikeOverdriveIdleResetVal = tower:FindFirstChild("SpikeOverdriveIdleReset"),
		spikeStormEnabledVal = tower:FindFirstChild("SpikeStormEnabled"),
		spikeStormIntervalVal = tower:FindFirstChild("SpikeStormInterval"),
		spikeStormArrowsPerEnemyVal = tower:FindFirstChild("SpikeStormArrowsPerEnemy"),
		spikeBleedEnabledVal = tower:FindFirstChild("SpikeBleedEnabled"),
		spikeBleedDamageMultiplierVal = tower:FindFirstChild("SpikeBleedDamageMultiplier"),
		spikeBleedDurationVal = tower:FindFirstChild("SpikeBleedDuration"),
		spikeBleedTickRateVal = tower:FindFirstChild("SpikeBleedTickRate"),
		spikeSlowDivisorVal = tower:FindFirstChild("SpikeSlowDivisor"),
		spikeSlowDurationVal = tower:FindFirstChild("SpikeSlowDuration"),
		spikePinEveryHitsVal = tower:FindFirstChild("SpikePinEveryHits"),
		spikePinDurationVal = tower:FindFirstChild("SpikePinDuration"),
		spikeBossPinSlowDivisorVal = tower:FindFirstChild("SpikeBossPinSlowDivisor"),
		spikeBarbDamageBonusVal = tower:FindFirstChild("SpikeBarbDamageBonus"),
		spikeBarbDamageBonusMaxVal = tower:FindFirstChild("SpikeBarbDamageBonusMax"),
		spikeImprisonBarbCountVal = tower:FindFirstChild("SpikeImprisonBarbCount"),
		spikeImprisonDurationVal = tower:FindFirstChild("SpikeImprisonDuration"),
		spikeImprisonBurstMultiplierVal = tower:FindFirstChild("SpikeImprisonBurstMultiplier"),
		spikeImprisonSlowDivisorVal = tower:FindFirstChild("SpikeImprisonSlowDivisor"),
		spikeImprisonTickDamageVal = tower:FindFirstChild("SpikeImprisonTickDamage"),
		spikeImprisonTickRateVal = tower:FindFirstChild("SpikeImprisonTickRate"),
		magnetStrengthMultiplierVal = tower:FindFirstChild("MagnetStrengthMultiplier"),
		magnetImmobilizeDurationVal = tower:FindFirstChild("MagnetImmobilizeDuration"),
		buffsTeslaCoilsInRangeVal = tower:FindFirstChild("BuffsTeslaCoilsInRange"),
		teslaBuffMultiplierVal = tower:FindFirstChild("TeslaBuffMultiplier"),
		chargedBlastEnabledVal = tower:FindFirstChild("ChargedBlastEnabled"),
		chargedEveryHitsVal = tower:FindFirstChild("ChargedEveryHits"),
		chargedBonusMultiplierVal = tower:FindFirstChild("ChargedBonusMultiplier"),
		highVoltageEnabledVal = tower:FindFirstChild("HighVoltageEnabled"),
		highVoltageMaxMultiplierVal = tower:FindFirstChild("HighVoltageMaxMultiplier"),
		disturbanceEnabledVal = tower:FindFirstChild("DisturbanceEnabled"),
		disturbanceDamageMultiplierVal = tower:FindFirstChild("DisturbanceDamageMultiplier"),
		oilCoatingEnabledVal = tower:FindFirstChild("OilCoatingEnabled"),
		oilCoatDurationVal = tower:FindFirstChild("OilCoatDuration"),
		oilCoatSpeedPercentVal = tower:FindFirstChild("OilCoatSpeedPercent"),
		oilInitialSpeedPercentVal = tower:FindFirstChild("OilInitialSpeedPercent"),
		oilInitialSlowDurationVal = tower:FindFirstChild("OilInitialSlowDuration"),
		oilFireDamageMultiplierVal = tower:FindFirstChild("OilFireDamageMultiplier"),
		oilFireReactionEnabledVal = tower:FindFirstChild("OilFireReactionEnabled"),
		oilFirePuddleDamageVal = tower:FindFirstChild("OilFirePuddleDamage"),
		oilFirePuddleBurnDurationVal = tower:FindFirstChild("OilFirePuddleBurnDuration"),
		oilHotFlashEnabledVal = tower:FindFirstChild("OilHotFlashEnabled"),
		oilFireBurstRadiusVal = tower:FindFirstChild("OilFireBurstRadius"),
		oilFireBurstDamageVal = tower:FindFirstChild("OilFireBurstDamage"),
		oilFireLingeringNormalDurationVal = tower:FindFirstChild("OilFireLingeringNormalDuration"),
		oilChainSpillEnabledVal = tower:FindFirstChild("OilChainSpillEnabled"),
		oilFireDeathZoneDurationVal = tower:FindFirstChild("OilFireDeathZoneDuration"),
		oilPostCooldownVal = tower:FindFirstChild("OilPostCooldown"),
		oilBetterAimEnabledVal = tower:FindFirstChild("OilBetterAimEnabled"),
		oilAimAheadStudsVal = tower:FindFirstChild("OilAimAheadStuds"),
		oilDoubleTossEveryVal = tower:FindFirstChild("OilDoubleTossEvery"),
		oilTowerComboEnabledVal = tower:FindFirstChild("OilTowerComboEnabled"),
		oilTowerDamageMultiplierVal = tower:FindFirstChild("OilTowerDamageMultiplier"),
		oilRefineryBoostMultiplierVal = tower:FindFirstChild("OilRefineryBoostMultiplier"),
		oilRefineryBoostDurationVal = tower:FindFirstChild("OilRefineryBoostDuration"),
		extractorEnabledVal = tower:FindFirstChild("ExtractorEnabled"),
		extractorHeatVal = tower:FindFirstChild("ExtractorHeat"),
		extractorSafeTimeVal = tower:FindFirstChild("ExtractorSafeTime"),
		extractorHeatRateVal = tower:FindFirstChild("ExtractorHeatRate"),
		extractorShutdownDurationVal = tower:FindFirstChild("ExtractorShutdownDuration"),
		extractorTickIntervalVal = tower:FindFirstChild("ExtractorTickInterval"),
		extractorRestartRequestVal = tower:FindFirstChild("ExtractorRestartRequest"),
		extractorRestartDurationVal = tower:FindFirstChild("ExtractorRestartDuration"),
		extractorRestartCooldownVal = tower:FindFirstChild("ExtractorRestartCooldown"),
		extractorRestartReadyAtVal = tower:FindFirstChild("ExtractorRestartReadyAt"),
		extractorRestartUntilVal = tower:FindFirstChild("ExtractorRestartUntil"),
		extractorStateVal = tower:FindFirstChild("ExtractorState"),
	}
end

local function setupTowerAnim(tower, animId)
	if towerAnimators[tower] then
		return
	end

	local animationParent
	local towerType = getTowerType(tower)

	if towerType == "Oil Launcher" then
		animationParent = tower
	elseif towerType == "Mushroom" or towerType == "Magnet" then
		animationParent = tower:FindFirstChild("RootPart")
	elseif tower:IsA("Model") then
		animationParent = tower:FindFirstChildOfClass("MeshPart") or tower:FindFirstChildOfClass("BasePart")
	else
		animationParent = tower
	end

	if not animationParent then
		return
	end

	local controller = animationParent:FindFirstChildOfClass("AnimationController")
	if not controller then
		controller = Instance.new("AnimationController")
		controller.Parent = animationParent
	end

	local animator = controller:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = controller
	end

	local animObj = Instance.new("Animation")
	animObj.AnimationId = animId
	animObj.Parent = controller

	local track = animator:LoadAnimation(animObj)
	track.Priority = Enum.AnimationPriority.Action
	towerAnimators[tower] = track
	animCooldown[tower] = false
end

function findDeepestOilBone(tower)
	local rootPart = tower:FindFirstChild("RootPart")
	if not rootPart then
		return nil
	end

	local preferred = rootPart:FindFirstChild("Bone.001", true)
	if preferred and preferred:IsA("Bone") then
		return preferred
	end

	local deepestBone = nil
	local deepestDepth = -1
	for _, obj in ipairs(rootPart:GetDescendants()) do
		if obj:IsA("Bone") then
			local depth = 0
			local current = obj
			while current and current ~= rootPart do
				depth += 1
				current = current.Parent
			end

			if depth > deepestDepth then
				deepestDepth = depth
				deepestBone = obj
			end
		end
	end

	return deepestBone
end

function setupOilSprayFollower(tower)
	if oilSprayFollowers[tower] then
		return
	end

	local sprayPart = tower:FindFirstChild("C - STRONG WATER SPRAY", true)
	if not sprayPart or not sprayPart:IsA("BasePart") then
		return
	end

	local followBone = findDeepestOilBone(tower)
	if not followBone then
		return
	end

	local offset = followBone.WorldCFrame:ToObjectSpace(sprayPart.CFrame)
	sprayPart.Anchored = true
	sprayPart.CanCollide = false
	sprayPart.CanTouch = false
	sprayPart.CanQuery = false
	sprayPart.Transparency = 1

	local deadConstraint = sprayPart:FindFirstChildOfClass("RigidConstraint")
	if deadConstraint then
		deadConstraint.Enabled = false
	end

	for _, obj in ipairs(sprayPart:GetDescendants()) do
		if obj:IsA("ParticleEmitter") then
			obj.Enabled = false
		end
	end

	local connection
	connection = RunService.Heartbeat:Connect(function()
		if not tower.Parent or not sprayPart.Parent or not followBone.Parent then
			if connection then
				connection:Disconnect()
			end
			oilSprayFollowers[tower] = nil
			return
		end

		sprayPart.CFrame = followBone.WorldCFrame * offset
	end)

	oilSprayFollowers[tower] = connection
end

local function registerTower(tower)
	if not tower or activeTowers[tower] or not isTower(tower) then
		return
	end

	activeTowers[tower] = true
	towerStateCache[tower] = buildTowerState(tower)
	extractorRuntime.runStartedAt[tower] = extractorRuntime.runStartedAt[tower] or tick()

	local animId = getAnimIdForType(towerStateCache[tower].towerType)
	if animId then
		setupTowerAnim(tower, animId)
	end

	if towerStateCache[tower].towerType == "Oil Launcher" then
		setupOilSprayFollower(tower)
	end
end
function getEnemyFirePart(enemy)
	return enemy:FindFirstChild("HumanoidRootPart")
		or enemy:FindFirstChild("Head")
		or enemy:FindFirstChildWhichIsA("BasePart", true)
end
local function unregisterTower(tower)
	if not activeTowers[tower] then
		return
	end
	teslaBombLastSpawn[tower] = nil

	local bombList = teslaBombs[tower]
	if bombList then
		for _, bombData in ipairs(bombList) do
			if bombData.model and bombData.model.Parent then
				bombData.model:Destroy()
			end
		end
	end
	local fieldVisual = magnetFieldVisuals[tower]
	if fieldVisual and fieldVisual.Parent then
		fieldVisual:Destroy()
	end
	magnetFieldVisuals[tower] = nil
	teslaBombs[tower] = nil
	electromagneticStormLastPulse[tower] = nil
	magnetAttackCounts[tower] = nil
	spikeStormLastCast[tower] = nil
	spikeAttackCounts[tower] = nil
	spikeOverdriveStacks[tower] = nil
	spikeLastActiveAt[tower] = nil
	acidRainLastCast[tower] = nil
	extractorRuntime.lastMine[tower] = nil
	extractorRuntime.runStartedAt[tower] = nil
	extractorRuntime.startingHeat[tower] = nil
	extractorRuntime.shutdownUntil[tower] = nil
	extractorRuntime.lastRestartRequest[tower] = nil
	extractorRuntime.restartUntil[tower] = nil
	extractorRuntime.restartCooldownUntil[tower] = nil
	extractorRuntime.overheatWarned[tower] = nil
	local heatingGui = tower:FindFirstChild("ExtractorHeatingBillboard", true)
	if heatingGui then
		heatingGui.Enabled = false
	end
	activeTowers[tower] = nil
	lastAttackTime[tower] = nil
	animCooldown[tower] = nil
	towerStateCache[tower] = nil
	currentTargets[tower] = nil
	targetingModes[tower] = nil
	poisonedEnemies[tower] = nil
	local orbitData = teslaOrbitBalls[tower]
	if orbitData and orbitData.part and orbitData.part.Parent then
		orbitData.part:Destroy()
	end
	teslaOrbitBalls[tower] = nil

	local seekerList = teslaSeekerBalls[tower]
	if seekerList then
		for _, seeker in ipairs(seekerList) do
			if seeker.part and seeker.part.Parent then
				seeker.part:Destroy()
			end
		end
	end
	teslaSeekerBalls[tower] = nil

	local stormList = teslaStormBalls[tower]
	if stormList then
		for _, stormBall in ipairs(stormList) do
			if stormBall.part and stormBall.part.Parent then
				stormBall.part:Destroy()
			end
		end
	end
	teslaStormBalls[tower] = nil
	teslaMarkedEnemies[tower] = nil
	local oilFollower = oilSprayFollowers[tower]
	if oilFollower then
		oilFollower:Disconnect()
	end
	oilSprayFollowers[tower] = nil
	oilPuddleCooldownUntil[tower] = nil
	local track = towerAnimators[tower]
	if track then
		track:Stop(0)
	end

	towerAnimators[tower] = nil
end
local function getEnemyBaseSpeed(enemy)
	local speedVal = enemy:FindFirstChild("Speed")
	if not speedVal then
		return nil, nil
	end

	local baseSpeed = enemy:GetAttribute("BaseSpeed")
	if typeof(baseSpeed) ~= "number" or baseSpeed <= 0 then
		baseSpeed = speedVal.Value
		enemy:SetAttribute("BaseSpeed", baseSpeed)
	end

	return speedVal, baseSpeed
end
local function registerEnemy(enemy)
	if not enemy or activeEnemies[enemy] or not isEnemy(enemy) then
		return
	end

	activeEnemies[enemy] = true
	enemySpatial:markDirty()
end

local function unregisterEnemy(enemy)
	if not activeEnemies[enemy] then
		return
	end
	for _, marks in pairs(teslaMarkedEnemies) do
		marks[enemy] = nil
	end
	EnemyBehaviors.cleanupEnemy(enemy)
	staticFieldAffectedEnemies[enemy] = nil
	disturbanceHitUntil[enemy] = nil
	conductiveEnemies[enemy] = nil
	distortionAppliedEnemies[enemy] = nil
	burningEnemies[enemy] = nil
	activeEnemies[enemy] = nil
	slowedEnemies[enemy] = nil
	oilCoatedEnemies[enemy] = nil
	firePuddleTickAt[enemy] = nil
	firePuddleBurnUntil[enemy] = nil
	firePuddleBurnDamage[enemy] = nil
	normalFireTickAt[enemy] = nil
	normalFireUntil[enemy] = nil
	tankKnockbackUntil[enemy] = nil
	tankSlowImmuneUntil[enemy] = nil
	burningEnemyCounts[enemy] = nil
	activePoisonedEnemies[enemy] = nil
	enemySlowStates[enemy] = nil
	enemy:SetAttribute("EnemySlowedEffect", false)
	enemy:SetAttribute("EnemyBleedingEffect", false)
	enemySpatial:remove(enemy)

	local burningFire = enemy:FindFirstChild("BurningFire", true)
	if burningFire and burningFire:IsA("ParticleEmitter") then
		burningFire:Destroy()
	end

	for _, towerPoisonState in pairs(poisonedEnemies) do
		towerPoisonState[enemy] = nil
	end
end

enemySpatial = TowerSpatialIndex.new(activeEnemies, unregisterEnemy)

local function inspectTowerInstance(obj)
	if isTower(obj) then
		registerTower(obj)
		return
	end

	local current = obj.Parent
	while current and current ~= placedTowersFolder and current ~= workspace do
		if isTower(current) then
			registerTower(current)
			return
		end

		current = current.Parent
	end
end

local function inspectEnemyInstance(obj)
	if obj:IsA("Model") and isEnemy(obj) then
		registerEnemy(obj)
		return
	end

	local current = obj.Parent
	while current and current ~= workspace do
		if current:IsA("Model") and isEnemy(current) then
			registerEnemy(current)
			return
		end

		current = current.Parent
	end
end

local function doRecoil(part)
	-- Server recoil was replicating CFrame changes every shot. Keep tower combat authoritative here,
	-- but leave cosmetic weapon kick to a client-side effect later.
end

local function playCannonShotSound(tower)
	local soundParent = tower:FindFirstChild("Deploy", true)

	if not soundParent or not soundParent:IsA("BasePart") then
		if tower:IsA("Model") then
			soundParent = tower:FindFirstChildOfClass("BasePart")
		elseif tower:IsA("BasePart") then
			soundParent = tower
		end
	end

	if not soundParent then
		return
	end

	local shotSound = Instance.new("Sound")
	shotSound.SoundId = CANNON_SHOT_SOUND_ID
	shotSound.Volume = CANNON_SHOT_VOLUME
	shotSound.RollOffMode = Enum.RollOffMode.Inverse
	shotSound.RollOffMinDistance = CANNON_SHOT_MIN_DISTANCE
	shotSound.RollOffMaxDistance = CANNON_SHOT_MAX_DISTANCE
	shotSound.Parent = soundParent
	shotSound:Play()

	shotSound.Ended:Connect(function()
		shotSound:Destroy()
	end)
end

local function playMushroomAttackSound(tower)
	local soundParent = tower:FindFirstChild("RootPart", true)

	if not soundParent or not soundParent:IsA("BasePart") then
		local spray = tower:FindFirstChild("Spray", true)
		local middle = spray and spray:FindFirstChild("Middle")
		if middle and middle:IsA("BasePart") then
			soundParent = middle
		end
	end

	if not soundParent or not soundParent:IsA("BasePart") then
		if tower:IsA("Model") then
			soundParent = tower:FindFirstChildOfClass("BasePart")
		elseif tower:IsA("BasePart") then
			soundParent = tower
		end
	end

	if not soundParent then
		return
	end

	local attackSound = Instance.new("Sound")
	attackSound.SoundId = MUSHROOM_ATTACK_SOUND_ID
	attackSound.Volume = MUSHROOM_ATTACK_VOLUME
	attackSound.RollOffMode = Enum.RollOffMode.Inverse
	attackSound.RollOffMinDistance = MUSHROOM_ATTACK_MIN_DISTANCE
	attackSound.RollOffMaxDistance = MUSHROOM_ATTACK_MAX_DISTANCE
	attackSound.Parent = soundParent
	attackSound:Play()

	attackSound.Ended:Connect(function()
		attackSound:Destroy()
	end)
end
function addEnemyFireEffect(enemy)
	burningEnemyCounts[enemy] = (burningEnemyCounts[enemy] or 0) + 1

	if enemy:FindFirstChild("BurningFire", true) or enemy:FindFirstChild("Fire", true) then
		return
	end

	local firePart = getEnemyFirePart(enemy)
	if not firePart then
		return
	end

	local fire = FIRE_EMITTER_TEMPLATE:Clone()
	fire.Name = "BurningFire"
	fire.Enabled = true
	fire.Parent = firePart
end
local function playLoopedFadingTowerSound(soundParent, soundId, volume, minDistance, maxDistance, activeDuration, fadeTime)
	if not soundParent or not soundParent:IsA("BasePart") then
		return
	end

	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Volume = volume
	sound.RollOffMode = Enum.RollOffMode.Inverse
	sound.RollOffMinDistance = minDistance
	sound.RollOffMaxDistance = maxDistance
	sound.Looped = true
	sound.Parent = soundParent
	sound:Play()

	task.delay(activeDuration, function()
		if not sound or not sound.Parent then
			return
		end

		local fadeTween = TweenService:Create(
			sound,
			TweenInfo.new(fadeTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{Volume = 0}
		)

		fadeTween:Play()
		fadeTween.Completed:Once(function()
			if sound then
				sound:Stop()
				sound:Destroy()
			end
		end)
	end)
end

local function playMagnetAttackSound(tower, activeDuration)
	local soundParent = tower:FindFirstChild("RootPart", true)

	if not soundParent or not soundParent:IsA("BasePart") then
		if tower:IsA("Model") then
			soundParent = tower:FindFirstChildOfClass("BasePart")
		elseif tower:IsA("BasePart") then
			soundParent = tower
		end
	end

	playLoopedFadingTowerSound(
		soundParent,
		MAGNET_ATTACK_SOUND_ID,
		MAGNET_ATTACK_VOLUME,
		MAGNET_ATTACK_MIN_DISTANCE,
		MAGNET_ATTACK_MAX_DISTANCE,
		activeDuration,
		MAGNET_ATTACK_FADE_TIME
	)
end

local function playTeslaAttackSound(tower, activeDuration)
	local auraPart = tower:FindFirstChild("Aura")
	local soundParent = auraPart

	if not soundParent or not soundParent:IsA("BasePart") then
		if tower:IsA("Model") then
			soundParent = tower:FindFirstChildOfClass("BasePart")
		elseif tower:IsA("BasePart") then
			soundParent = tower
		end
	end

	playLoopedFadingTowerSound(
		soundParent,
		TESLA_ATTACK_SOUND_ID,
		TESLA_ATTACK_VOLUME,
		TESLA_ATTACK_MIN_DISTANCE,
		TESLA_ATTACK_MAX_DISTANCE,
		activeDuration,
		TESLA_ATTACK_FADE_TIME
	)
end
local applyKnockback
local applyDirectDamage
local recomputeEnemySpeed
local getEnemiesInRadius
local getTowerPosition
local function shouldTriggerExplosion(towerState)
	local chance = towerState.explosionChanceVal and towerState.explosionChanceVal.Value or 0

	if chance <= 0 then
		return false
	end

	if chance >= 100 then
		return true
	end

	return math.random(1, 100) <= chance
end
function removeEnemyFireEffect(enemy)
	local remaining = (burningEnemyCounts[enemy] or 0) - 1

	if remaining > 0 then
		burningEnemyCounts[enemy] = remaining
		return
	end

	burningEnemyCounts[enemy] = nil

	local fire = enemy:FindFirstChild("BurningFire", true)
	if fire and fire:IsA("ParticleEmitter") then
		fire:Destroy()
	end
end
function isEnemyOnFire(enemy)
	return burningEnemyCounts[enemy] ~= nil
		or (enemy and enemy:FindFirstChild("BurningFire", true) ~= nil)
		or (enemy and enemy:FindFirstChild("Fire", true) ~= nil)
end

function applyNormalFire(enemy, durationOverride)
	if not enemy or not enemy.Parent then
		return
	end

	local duration = durationOverride or NORMAL_FIRE_DURATION
	normalFireUntil[enemy] = ReplicatedStorage:GetAttribute("DevInfiniteFire") and math.huge or (tick() + duration)
	if not isEnemyOnFire(enemy) then
		addEnemyFireEffect(enemy)
	end

	local oilState = oilCoatedEnemies[enemy]
	if oilState and oilState.chainSpillEnabled then
		local hrp = enemy:FindFirstChild("HumanoidRootPart")
		if hrp then
			for _, puddleData in ipairs(oilPuddles) do
				if puddleData.functional and not puddleData.isFire and puddleData.fireReactionEnabled then
					local offset = hrp.Position - puddleData.position
					local distance = Vector2.new(offset.X, offset.Z).Magnitude
					if distance <= (puddleData.radius or OIL_SPLASH_RADIUS) + 6 then
						replaceOilPuddleWithFire(puddleData, enemy)
						break
					end
				end
			end
		end
	end
end

function updateNormalFireEffects(now)
	for enemy, expiresAt in pairs(normalFireUntil) do
		if not enemy.Parent then
			normalFireUntil[enemy] = nil
		elseif now >= expiresAt and not ReplicatedStorage:GetAttribute("DevInfiniteFire") then
			normalFireUntil[enemy] = nil
			normalFireTickAt[enemy] = nil
			removeEnemyFireEffect(enemy)
		else
			local nextTick = normalFireTickAt[enemy] or 0
			if now >= nextTick then
				normalFireTickAt[enemy] = now + GameSpeed:ScaleDuration(1)
				local oilState = oilCoatedEnemies[enemy]
				local multiplier = oilState and oilState.fireDamageMultiplier or 1
				applyDirectDamage(enemy, NORMAL_FIRE_DAMAGE_PER_SECOND * multiplier)
			end
		end
	end
end

function applyFirePuddleBurn(enemy, puddleData)
	if not enemy or not enemy.Parent then
		return
	end

	if not firePuddleBurnUntil[enemy] and not isEnemyOnFire(enemy) then
		addEnemyFireEffect(enemy)
	end

	local duration = (puddleData and puddleData.fireBurnDuration) or FIRE_PUDDLE_BURN_DURATION
	firePuddleBurnUntil[enemy] = ReplicatedStorage:GetAttribute("DevInfiniteFire") and math.huge or (tick() + duration)
	firePuddleBurnDamage[enemy] = (puddleData and puddleData.fireDamage) or FIRE_PUDDLE_DAMAGE_PER_SECOND
end

function updateFirePuddleBurns(now)
	for enemy, expiresAt in pairs(firePuddleBurnUntil) do
		if not enemy.Parent then
			firePuddleBurnUntil[enemy] = nil
			firePuddleTickAt[enemy] = nil
			firePuddleBurnDamage[enemy] = nil
		elseif now >= expiresAt and not ReplicatedStorage:GetAttribute("DevInfiniteFire") then
			firePuddleBurnUntil[enemy] = nil
			firePuddleTickAt[enemy] = nil
			firePuddleBurnDamage[enemy] = nil
			removeEnemyFireEffect(enemy)
		else
			local nextTick = firePuddleTickAt[enemy] or 0
			if now >= nextTick then
				firePuddleTickAt[enemy] = now + GameSpeed:ScaleDuration(1)
				local oilState = oilCoatedEnemies[enemy]
				local multiplier = oilState and oilState.fireDamageMultiplier or 1
				applyDirectDamage(enemy, (firePuddleBurnDamage[enemy] or FIRE_PUDDLE_DAMAGE_PER_SECOND) * multiplier)
			end
		end
	end
end
local function applyConductivity(tower, towerState, enemy, canSpread)
	if not enemy or not enemy.Parent then
		return
	end

	local duration = towerState.conductivityDurationVal and towerState.conductivityDurationVal.Value or 3
	local conductiveTag = enemy:FindFirstChild("Conductive")

	if not conductiveTag then
		conductiveTag = Instance.new("IntValue")
		conductiveTag.Name = "Conductive"
		conductiveTag.Value = 1
		conductiveTag.Parent = enemy
	end

	conductiveEnemies[enemy] = {
		sourceTower = tower,
		canSpread = canSpread ~= false,
		expiresAt = tick() + duration,
	}

	if towerState.rewiredEnabledVal and towerState.rewiredEnabledVal.Value > 0 then
		local metallicClone = enemy:FindFirstChild("ConductiveMetallic")
		if not metallicClone then
			metallicClone = METALLIC_TAG_TEMPLATE:Clone()
			metallicClone.Name = "ConductiveMetallic"
			metallicClone.Parent = enemy
		end

		local sparks = enemy:FindFirstChild("ConductiveSparks", true)
		if not sparks then
			local attachPart = enemy:FindFirstChild("HumanoidRootPart")
				or enemy:FindFirstChild("Head")
				or enemy:FindFirstChildWhichIsA("BasePart", true)

			if attachPart then
				sparks = SPARKS_EMITTER_TEMPLATE:Clone()
				sparks.Name = "ConductiveSparks"
				sparks.Parent = attachPart
			end
		end
	end
end
local function spreadConductivityOnDeath(deadEnemy)
	local state = conductiveEnemies[deadEnemy]
	if not state or not state.canSpread then
		return
	end

	local sourceTower = state.sourceTower
	if not sourceTower or not sourceTower.Parent then
		return
	end

	local towerState = towerStateCache[sourceTower] or buildTowerState(sourceTower)
	towerStateCache[sourceTower] = towerState

	if not (towerState.hivemindEnabledVal and towerState.hivemindEnabledVal.Value > 0) then
		return
	end

	local deadHrp = deadEnemy:FindFirstChild("HumanoidRootPart")
	if not deadHrp then
		return
	end

	local candidates = {}

	for enemy in pairs(activeEnemies) do
		if enemy ~= deadEnemy and enemy.Parent then
			local hrp = enemy:FindFirstChild("HumanoidRootPart")
			local healthVal = enemy:FindFirstChild("Health")

			if hrp and healthVal and healthVal.Value > 0 then
				table.insert(candidates, {
					enemy = enemy,
					distance = (hrp.Position - deadHrp.Position).Magnitude,
				})
			end
		end
	end

	table.sort(candidates, function(a, b)
		return a.distance < b.distance
	end)

	for i = 1, math.min(2, #candidates) do
		applyConductivity(sourceTower, towerState, candidates[i].enemy, false)
	end
end
local function applyPoison(tower, towerState, enemy)
	if activePoisonedEnemies[enemy] then
		return
	end

	if not poisonedEnemies[tower] then
		poisonedEnemies[tower] = {}
	end

	if poisonedEnemies[tower][enemy] then
		return
	end

	local healthVal = enemy:FindFirstChild("Health")
	if not healthVal or healthVal.Value <= 0 then
		return
	end

	local damage = towerState.fireDamageVal and towerState.fireDamageVal.Value
		or towerState.damageVal and towerState.damageVal.Value
		or 10

	local tickInterval = math.max(0.1, towerState.poisonAttackSpeedVal and towerState.poisonAttackSpeedVal.Value or 1)
	local duration = towerState.poisonDurationVal and towerState.poisonDurationVal.Value or 5
	local usesFireVisual = towerState.towerType == "Cannon"

	activePoisonedEnemies[enemy] = true
	poisonedEnemies[tower][enemy] = true

	if usesFireVisual then
		addEnemyFireEffect(enemy)
	end

	task.spawn(function()
		local elapsed = 0

		while elapsed < duration do
			task.wait(GameSpeed:ScaleDuration(tickInterval))
			elapsed += tickInterval

			if not enemy.Parent or not tower.Parent then
				break
			end

			applyDirectDamage(enemy, damage)

			local enemyHealth = enemy:FindFirstChild("Health")
			if not enemyHealth or enemyHealth.Value <= 0 then
				break
			end
		end

		if usesFireVisual then
			removeEnemyFireEffect(enemy)
		end

		activePoisonedEnemies[enemy] = nil

		if poisonedEnemies[tower] then
			poisonedEnemies[tower][enemy] = nil
		end
	end)
end
local function playImpactExplosion(position)
	local explosionTemplate = game.ReplicatedStorage:FindFirstChild("Explosion")
	if not explosionTemplate or not explosionTemplate:IsA("ParticleEmitter") then
		return
	end

	local anchor = Instance.new("Part")
	anchor.Name = "ImpactExplosionAnchor"
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.Transparency = 1
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.CFrame = CFrame.new(position)
	anchor.Parent = workspace

	local explosionSound = Instance.new("Sound")
	explosionSound.SoundId = "rbxassetid://76431322771524"
	explosionSound.Volume = 2.3
	explosionSound.RollOffMode = Enum.RollOffMode.Inverse
	explosionSound.RollOffMinDistance = 10
	explosionSound.RollOffMaxDistance = 80
	explosionSound.Parent = anchor
	explosionSound:Play()

	local emitter = explosionTemplate:Clone()
	emitter.Enabled = false
	emitter.Parent = anchor
	emitter.Enabled = true

	task.delay(0.1, function()
		if emitter and emitter.Parent then
			emitter.Enabled = false
		end
	end)

	task.delay(1.2, function()
		if anchor and anchor.Parent then
			anchor:Destroy()
		end
	end)
end

local function applyExplosionDamage(centerPosition, primaryEnemy, damage, radius, maxTargets)
	local candidates = {}

	for _, enemy in ipairs(enemySpatial:getCandidatesNear(centerPosition, radius)) do
		if enemy ~= primaryEnemy and enemy.Parent then
			local hrp = enemy:FindFirstChild("HumanoidRootPart")
			local healthVal = enemy:FindFirstChild("Health")

			if hrp and healthVal and healthVal.Value > 0 then
				if enemySpatial:isWithinTargetRadius(enemy, centerPosition, radius) then
					local distance = enemySpatial:getTargetDistance(enemy, centerPosition)
					table.insert(candidates, {
						enemy = enemy,
						distance = distance,
					})
				end
			end
		end
	end

	table.sort(candidates, function(a, b)
		return a.distance < b.distance
	end)

	local affected = 0
	for _, entry in ipairs(candidates) do
		if affected >= maxTargets then
			break
		end

		applyDirectDamage(entry.enemy, damage)
		affected += 1
	end
end




local function fireCannonBall(tower, towerState, target)
	local deployPart = tower:FindFirstChild("Deploy", true)
	if not deployPart then
		return
	end

	local ballTemplate = game.ReplicatedStorage:FindFirstChild("CannonBall")
	if not ballTemplate then
		return
	end

	local ball = ballTemplate:Clone()

	local scaleVal = tower:FindFirstChild("CannonBallScale")
	local scaleMultiplier = 1
	if scaleVal and scaleVal:IsA("NumberValue") then
		scaleMultiplier = scaleVal.Value
	end

	ball.Size = ball.Size * scaleMultiplier

	local poisonousVal = tower:FindFirstChild("Poisonous")
	local isFireCannon = getTowerType(tower) == "Cannon" and poisonousVal and poisonousVal:IsA("IntValue")

	if isFireCannon then
		local fire = FIRE_EMITTER_TEMPLATE:Clone()
		fire.Name = "Fire"
		fire.Enabled = true
		fire.Parent = ball
	end

	ball.CFrame = CFrame.new(deployPart.Position)
	ball.Anchored = true
	ball.CanCollide = false
	ball.Parent = workspace

	local startPos = deployPart.Position
	if typeof(startPos) ~= "Vector3" then
		ball:Destroy()
		return
	end

	local arcHeight = 8
	local elapsed = 0
	local finished = false

	local baseDamage = towerState.damageVal and towerState.damageVal.Value or 10
	local knockbackStuds = towerState.knockbackStudsVal and towerState.knockbackStudsVal.Value or 0
	local isPoisonous = towerState.poisonousVal and towerState.poisonousVal:IsA("IntValue")
	local damagedByShot = {}
	local didDamage = false

	local function findReplacementTarget(originPosition)
		local radius = towerState.radiusVal and towerState.radiusVal.Value or 20
		local bestEnemy = nil
		local bestDistance = math.huge

		for _, enemy in ipairs(enemySpatial:getCandidatesNear(startPos, radius)) do
			if enemy ~= target and not damagedByShot[enemy] and isEnemyAlive(enemy) then
				if enemySpatial:isWithinTargetRadius(enemy, startPos, radius) then
					local enemyHrp = enemy:FindFirstChild("HumanoidRootPart")
					local distance = enemyHrp and (enemyHrp.Position - originPosition).Magnitude or math.huge
					if distance < bestDistance then
						bestDistance = distance
						bestEnemy = enemy
					end
				end
			end
		end

		return bestEnemy
	end

	if not isEnemyAlive(target) then
		target = findReplacementTarget(startPos)
		if not target then
			lastAttackTime[tower] = 0
			ball:Destroy()
			return
		end
	end

	local function damageCannonEnemy(hitEnemy, hitPosition, isPrimary)
		if not hitEnemy or not hitEnemy.Parent or damagedByShot[hitEnemy] then
			return
		end

		local hitHealth = hitEnemy:FindFirstChild("Health")
		if not hitHealth or hitHealth.Value <= 0 then
			return
		end

		damagedByShot[hitEnemy] = true
		didDamage = true

		local oilState = oilCoatedEnemies[hitEnemy]
		local hitDamage = baseDamage
		if oilState then
			applyNormalFire(hitEnemy)
			if oilState.towerComboEnabled then
				hitDamage *= oilState.towerDamageMultiplier or 1
			end
		end

		applyDirectDamage(hitEnemy, hitDamage)

		if isPrimary and knockbackStuds > 0 then
			applyKnockback(hitEnemy, knockbackStuds, startPos)
		end

		if isPoisonous then
			applyPoison(tower, towerState, hitEnemy)
		end

		if isPrimary and hitPosition and shouldTriggerExplosion(towerState) then
			local explosionRadius = towerState.explosionRadiusVal and towerState.explosionRadiusVal.Value or 6
			local explosionMaxTargets = towerState.explosionMaxTargetsVal and towerState.explosionMaxTargetsVal.Value or 3
			local explosionDamage = towerState.explosionDamageVal and towerState.explosionDamageVal.Value or baseDamage

			playImpactExplosion(hitPosition)
			applyExplosionDamage(hitPosition, hitEnemy, explosionDamage, explosionRadius, explosionMaxTargets)
		end
	end

	local function finishAt(hitEnemy, hitPosition)
		if finished then
			return
		end
		finished = true

		if hitEnemy and hitEnemy.Parent then
			damageCannonEnemy(hitEnemy, hitPosition, true)
		end

		if ball and ball.Parent then
			ball:Destroy()
		end

		if not didDamage then
			lastAttackTime[tower] = 0
		end
	end

	local connection
	connection = RunService.Heartbeat:Connect(function(dt)
		if finished or not ball.Parent then
			if connection then
				connection:Disconnect()
			end
			return
		end

		if not target or not target.Parent then
			target = findReplacementTarget(ball.Position)
		end

		local liveHrp = target and target:FindFirstChild("HumanoidRootPart")
		local liveHealth = target and target:FindFirstChild("Health")
		if not liveHrp or not liveHealth or liveHealth.Value <= 0 then
			target = findReplacementTarget(ball.Position)
			if not target then
				finishAt(nil, nil)
				if connection then
					connection:Disconnect()
				end
				return
			end

			liveHrp = target:FindFirstChild("HumanoidRootPart")
			liveHealth = target:FindFirstChild("Health")
			if not liveHrp or not liveHealth or liveHealth.Value <= 0 then
				finishAt(nil, nil)
				if connection then
					connection:Disconnect()
				end
				return
			end
		end

		elapsed += GameSpeed:ScaleDelta(dt)
		local t = math.clamp(elapsed / BALL_TRAVEL_TIME, 0, 1)

		local targetPos = liveHrp.Position
		if typeof(targetPos) ~= "Vector3" then
			finishAt(nil, nil)
			if connection then
				connection:Disconnect()
			end
			return
		end

		local flatPos = startPos:Lerp(targetPos, t)
		local arcOffset = arcHeight * (4 * t * (1 - t))
		local ballPos = Vector3.new(flatPos.X, flatPos.Y + arcOffset, flatPos.Z)

		ball.CFrame = CFrame.new(ballPos)

		local pierceRadius = math.max(CANNON_PIERCE_HIT_RADIUS, ball.Size.Magnitude * 0.35)
		for _, enemy in ipairs(enemySpatial:getCandidatesNear(ballPos, pierceRadius)) do
			if enemy ~= target and enemy.Parent and not damagedByShot[enemy] then
				local enemyHrp = enemy:FindFirstChild("HumanoidRootPart")
				local enemyHealth = enemy:FindFirstChild("Health")
				if enemyHrp and enemyHealth and enemyHealth.Value > 0 then
					if enemySpatial.getFlatDistanceSquared(enemyHrp.Position, ballPos) <= pierceRadius * pierceRadius then
						damageCannonEnemy(enemy, enemyHrp.Position, false)
					end
				end
			end
		end

		if (ballPos - targetPos).Magnitude <= math.max(1.5, ball.Size.Magnitude * 0.35) or t >= 1 then
			finishAt(target, targetPos)
			if connection then
				connection:Disconnect()
			end
		end
	end)

	task.delay(GameSpeed:ScaleDuration(BALL_TRAVEL_TIME + 1), function()
		if connection then
			connection:Disconnect()
		end
		if not finished then
			finishAt(nil, nil)
		end
	end)
end

function isStoneEnemy(enemy)
	if not enemy then
		return false
	end

	if enemy:FindFirstChild("Rock") then
		return true
	end

	local name = string.lower(enemy.Name)
	return name == "stonething" or name == "rockman" or string.find(name, "stone", 1, true) ~= nil or string.find(name, "rock", 1, true) ~= nil
end

function getSpikeDamage(towerState, enemy, baseDamage)
	local damage = baseDamage
	if isStoneEnemy(enemy) then
		damage *= towerState.spikeStoneDamageMultiplierVal and towerState.spikeStoneDamageMultiplierVal.Value or 1
	end

	local barbState = spikeBarbStates[enemy]
	if barbState and towerState.spikeBarbDamageBonusVal then
		local bonusPerBarb = towerState.spikeBarbDamageBonusVal.Value
		local maxBonus = towerState.spikeBarbDamageBonusMaxVal and towerState.spikeBarbDamageBonusMaxVal.Value or 0.4
		damage *= 1 + math.min(maxBonus, (barbState.count or 0) * bonusPerBarb)
	end

	return math.max(1, math.floor(damage + 0.5))
end

function getLiveEnemyHrp(enemy)
	if not isEnemyAlive(enemy) then
		return nil
	end

	return enemy:FindFirstChild("HumanoidRootPart")
end

function applySpikeSlow(enemy, duration, divisor, immobilizeDuration)
	if not enemy or not enemy.Parent then
		return
	end

	local now = tick()
	local isBoss = isTankEnemy(enemy)
	local isStone = isStoneEnemy(enemy)
	local actualImmobilize = (isBoss or isStone) and 0 or (immobilizeDuration or 0)
	local actualDivisor = isBoss and math.max(divisor or 1, 5) or (divisor or 1)
	if isStone then
		actualDivisor = math.min(actualDivisor, 2)
	end
	local actualDuration = math.max(0, duration or 0)

	if actualDuration <= 0 or actualDivisor <= 1 then
		return
	end

	local newState = {
		expiresAt = now + actualDuration,
		immobilizeUntil = now + math.min(actualImmobilize, actualDuration),
		divisor = actualDivisor,
	}

	local oldState = enemySlowStates[enemy]
	if oldState then
		newState.expiresAt = math.max(oldState.expiresAt, newState.expiresAt)
		newState.immobilizeUntil = math.max(oldState.immobilizeUntil, newState.immobilizeUntil)
		newState.divisor = math.max(oldState.divisor, newState.divisor)
	end

	enemySlowStates[enemy] = newState
	slowedEnemies[enemy] = true
	recomputeEnemySpeed(enemy, staticFieldAffectedEnemies[enemy] and 1 or nil, EnemyBehaviors.hasSupportAura(enemy), now)

	task.delay(actualDuration + 0.05, function()
		local state = enemySlowStates[enemy]
		if state and tick() >= state.expiresAt then
			enemySlowStates[enemy] = nil
			slowedEnemies[enemy] = nil
			if enemy and enemy.Parent then
				recomputeEnemySpeed(enemy, nil, EnemyBehaviors.hasSupportAura(enemy), tick())
			end
		end
	end)
end

function applyOilPercentSlow(enemy, duration, speedPercent)
	if not enemy or not enemy.Parent then
		return
	end

	local actualDuration = math.max(0, duration or 0)
	local actualPercent = math.clamp(speedPercent or 1, 0.05, 1)
	if actualDuration <= 0 or actualPercent >= 1 then
		return
	end

	local now = tick()
	local newState = {
		expiresAt = now + actualDuration,
		immobilizeUntil = 0,
		divisor = 1 / actualPercent,
	}

	local oldState = enemySlowStates[enemy]
	if oldState then
		newState.expiresAt = math.max(oldState.expiresAt, newState.expiresAt)
		newState.immobilizeUntil = math.max(oldState.immobilizeUntil, newState.immobilizeUntil)
		newState.divisor = math.max(oldState.divisor, newState.divisor)
	end

	enemySlowStates[enemy] = newState
	slowedEnemies[enemy] = true
	recomputeEnemySpeed(enemy, staticFieldAffectedEnemies[enemy] and 1 or nil, EnemyBehaviors.hasSupportAura(enemy), now)

	task.delay(actualDuration + 0.05, function()
		local state = enemySlowStates[enemy]
		if state and tick() >= state.expiresAt then
			enemySlowStates[enemy] = nil
			slowedEnemies[enemy] = nil
			if enemy and enemy.Parent then
				recomputeEnemySpeed(enemy, nil, EnemyBehaviors.hasSupportAura(enemy), tick())
			end
		end
	end)
end

function applySpikeBleed(towerState, enemy, baseDamage)
	if not towerState.spikeBleedEnabledVal or towerState.spikeBleedEnabledVal.Value <= 0 then
		return
	end

	if not spikeBleedStates[enemy] then
		spikeBleedStates[enemy] = {}
	end

	local damage = math.max(1, math.floor(baseDamage * (towerState.spikeBleedDamageMultiplierVal and towerState.spikeBleedDamageMultiplierVal.Value or 0.25) + 0.5))
	local duration = towerState.spikeBleedDurationVal and towerState.spikeBleedDurationVal.Value or 3
	local tickRate = math.max(0.1, towerState.spikeBleedTickRateVal and towerState.spikeBleedTickRateVal.Value or 1)
	local expiresAt = tick() + duration
	spikeBleedStates[enemy].expiresAt = math.max(spikeBleedStates[enemy].expiresAt or 0, expiresAt)
	enemy:SetAttribute("EnemyBleedingEffect", true)

	if spikeBleedStates[enemy].running then
		return
	end

	spikeBleedStates[enemy].running = true
	task.spawn(function()
		while enemy.Parent and spikeBleedStates[enemy] and tick() < spikeBleedStates[enemy].expiresAt do
			task.wait(GameSpeed:ScaleDuration(tickRate))
			if isEnemyAlive(enemy) then
				applyDirectDamage(enemy, damage)
			end
		end
		if spikeBleedStates[enemy] then
			spikeBleedStates[enemy].running = false
		end
		if enemy and enemy.Parent then
			enemy:SetAttribute("EnemyBleedingEffect", false)
		end
	end)
end

function createSpikeSnapVisual(tower, enemy, count)
	local hrp = getLiveEnemyHrp(enemy)
	local arrowTemplate = tower and tower:FindFirstChild("Arrow", true)
	if not hrp or not arrowTemplate or not arrowTemplate:IsA("BasePart") then
		return
	end

	for i = 1, count do
		local angle = (math.pi * 2 / count) * i
		local startPos = hrp.Position + Vector3.new(math.cos(angle) * 5, 3, math.sin(angle) * 5)
		local endPos = hrp.Position + Vector3.new(math.cos(angle) * 1.8, 1.2, math.sin(angle) * 1.8)
		local spike = arrowTemplate:Clone()
		spike.Name = "SpikeCageShard"
		spike.Anchored = true
		spike.CanCollide = false
		spike.CanTouch = false
		spike.CanQuery = false
		spike.Transparency = arrowTemplate.Transparency
		spike.CFrame = CFrame.lookAt(startPos, endPos) * CFrame.Angles(0, math.rad(90), 0)
		spike.Parent = workspace
		TweenService:Create(spike, TweenInfo.new(GameSpeed:ScaleDuration(0.18), Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			CFrame = CFrame.lookAt(endPos, hrp.Position) * CFrame.Angles(0, math.rad(90), 0),
		}):Play()
		Debris:AddItem(spike, GameSpeed:ScaleDuration(0.75))
	end
end

function applySpikeBarb(tower, towerState, enemy, baseDamage)
	if not towerState.spikeBleedEnabledVal and not towerState.spikeBarbDamageBonusVal and not towerState.spikeImprisonBarbCountVal then
		return
	end

	local state = spikeBarbStates[enemy]
	if not state then
		state = {
			count = 0,
			lastImprisonAt = 0,
		}
		spikeBarbStates[enemy] = state
	end

	state.count += 1
	state.updatedAt = tick()
	applySpikeBleed(towerState, enemy, baseDamage)

	local required = towerState.spikeImprisonBarbCountVal and towerState.spikeImprisonBarbCountVal.Value or 0
	if required > 0 and state.count >= required and not state.imprisonRunning then
		state.imprisonRunning = true
		applySpikeSlow(
			enemy,
			towerState.spikeImprisonDurationVal and towerState.spikeImprisonDurationVal.Value or 2,
			towerState.spikeImprisonSlowDivisorVal and towerState.spikeImprisonSlowDivisorVal.Value or 8,
			towerState.spikeImprisonDurationVal and towerState.spikeImprisonDurationVal.Value or 2
		)
		createSpikeSnapVisual(tower, enemy, required)

		task.spawn(function()
			while enemy.Parent and isEnemyAlive(enemy) and spikeBarbStates[enemy] == state and (state.count or 0) >= required do
				applyDirectDamage(enemy, towerState.spikeImprisonTickDamageVal and towerState.spikeImprisonTickDamageVal.Value or 200)
				task.wait(GameSpeed:ScaleDuration(towerState.spikeImprisonTickRateVal and towerState.spikeImprisonTickRateVal.Value or 3))
			end

			if state then
				state.imprisonRunning = false
			end
		end)
	end
end

function findSpikeLineTarget(origin, direction, sign, excluded, maxRange, maxPerpendicular)
	local bestEnemy = nil
	local bestProjection = sign > 0 and math.huge or -math.huge
	local range = maxRange or math.huge
	local perpendicular = maxPerpendicular or 18

	for enemy in pairs(activeEnemies) do
		if not excluded[enemy] and isEnemyAlive(enemy) then
			local hrp = enemy:FindFirstChild("HumanoidRootPart")
			if hrp then
				local offset = hrp.Position - origin
				local projection = offset:Dot(direction)
				if projection * sign > 0 and math.abs(projection) <= range then
					local closestPoint = origin + direction * projection
					if (hrp.Position - closestPoint).Magnitude <= perpendicular then
						if sign > 0 then
							if projection < bestProjection then
								bestProjection = projection
								bestEnemy = enemy
							end
						elseif projection > bestProjection then
							bestProjection = projection
							bestEnemy = enemy
						end
					end
				end
			end
		end
	end

	return bestEnemy
end

function cframeWithLocalXAxis(position, xDirection)
	xDirection = xDirection.Unit
	local upHint = math.abs(xDirection:Dot(Vector3.yAxis)) > 0.92 and Vector3.zAxis or Vector3.yAxis
	local zAxis = xDirection:Cross(upHint).Unit
	local yAxis = zAxis:Cross(xDirection).Unit
	return CFrame.fromMatrix(position, xDirection, yAxis, zAxis)
end

function fireSpikeVisualBetween(tower, fromPosition, toPosition, duration)
	local arrowTemplate = tower and tower:FindFirstChild("Arrow", true)
	if not arrowTemplate or not arrowTemplate:IsA("BasePart") then
		return
	end

	local direction = toPosition - fromPosition
	if direction.Magnitude < 0.001 then
		return
	end

	local arrow = arrowTemplate:Clone()
	arrow.Name = "SpikePierceVisual"
	arrow.Anchored = true
	arrow.CanCollide = false
	arrow.CanTouch = false
	arrow.CanQuery = false
	arrow.Transparency = arrowTemplate.Transparency
	arrow.CFrame = cframeWithLocalXAxis(fromPosition, direction.Unit)
	arrow.Parent = workspace
	TweenService:Create(arrow, TweenInfo.new(GameSpeed:ScaleDuration(duration or 0.08), Enum.EasingStyle.Linear, Enum.EasingDirection.Out), {
		CFrame = cframeWithLocalXAxis(toPosition, direction.Unit),
	}):Play()
	Debris:AddItem(arrow, GameSpeed:ScaleDuration((duration or 0.08) + 0.08))
end

function stickSpikeVisual(arrow, enemy, impactPosition, impactDirection)
	local hrp = getLiveEnemyHrp(enemy)
	if not arrow or not arrow.Parent or not hrp then
		if arrow and arrow.Parent then
			arrow:Destroy()
		end
		return
	end

	if impactDirection and impactDirection.Magnitude > 0.001 then
		arrow.CFrame = cframeWithLocalXAxis(impactPosition or hrp.Position, impactDirection.Unit)
	end

	arrow.Anchored = false
	arrow.Massless = true
	arrow.CanCollide = false
	arrow.CanTouch = false
	arrow.CanQuery = false
	arrow.Parent = workspace

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = arrow
	weld.Part1 = hrp
	weld.Parent = arrow

	Debris:AddItem(arrow, GameSpeed:ScaleDuration(1.15))
end

function shouldStickSpike(towerState)
	return towerState.spikeBleedEnabledVal and towerState.spikeBleedEnabledVal.Value > 0
end

function damageSpikeEnemy(tower, towerState, enemy, baseDamage, origin, direction, damaged)
	if not isEnemyAlive(enemy) or damaged[enemy] then
		return false
	end

	local damage = getSpikeDamage(towerState, enemy, baseDamage)
	applyDirectDamage(enemy, damage)
	damaged[enemy] = true
	applySpikeBarb(tower, towerState, enemy, baseDamage)

	if towerState.spikeSlowDivisorVal and towerState.spikeSlowDivisorVal.Value > 1 then
		applySpikeSlow(enemy, towerState.spikeSlowDurationVal and towerState.spikeSlowDurationVal.Value or 2, towerState.spikeSlowDivisorVal.Value, 0)
	end

	local everyPin = towerState.spikePinEveryHitsVal and towerState.spikePinEveryHitsVal.Value or 0
	if everyPin > 0 then
		local count = (spikeAttackCounts[tower] or 0)
		if count % everyPin == 0 then
			local divisor = isTankEnemy(enemy)
				and (towerState.spikeBossPinSlowDivisorVal and towerState.spikeBossPinSlowDivisorVal.Value or 5)
				or 999
			applySpikeSlow(enemy, towerState.spikePinDurationVal and towerState.spikePinDurationVal.Value or 0.7, divisor, towerState.spikePinDurationVal and towerState.spikePinDurationVal.Value or 0.7)
		end
	end

	local shatterTargets = towerState.spikeShatterTargetsVal and towerState.spikeShatterTargetsVal.Value or 0
	if shatterTargets > 0 then
		local multiplier = towerState.spikeShatterDamageMultiplierVal and towerState.spikeShatterDamageMultiplierVal.Value or 0.5
		local shatterDamage = math.max(1, math.floor(baseDamage * multiplier + 0.5))
		local hitHrp = getLiveEnemyHrp(enemy)
		if hitHrp then
			for _, sign in ipairs({1, -1}) do
				local shardTarget = findSpikeLineTarget(hitHrp.Position, direction, sign, damaged, nil, 18)
				if shardTarget then
					local shardHrp = getLiveEnemyHrp(shardTarget)
					if shardHrp then
						fireSpikeVisualBetween(tower, hitHrp.Position, shardHrp.Position, 0.09)
					end
					applyDirectDamage(shardTarget, shatterDamage)
					damaged[shardTarget] = true
				end
			end
		end
	end

	return true
end

function fireSpikeArrow(tower, towerState, target, options)
	options = options or {}
	local arrowTemplate = tower:FindFirstChild("Arrow", true)
	if not arrowTemplate or not arrowTemplate:IsA("BasePart") then
		return false
	end

	local arrowHomeCFrame = arrowTemplate.CFrame
	local startPos = arrowHomeCFrame.Position
	if typeof(startPos) ~= "Vector3" then
		return false
	end

	local baseDamage = options.damage or (towerState.damageVal and towerState.damageVal.Value or 7)
	local radius = towerState.radiusVal and towerState.radiusVal.Value or 34
	local damaged = options.damaged or {}
	local finished = false
	local elapsed = 0

	local function getTargetHrp(enemy)
		return enemy and enemy:FindFirstChild("HumanoidRootPart")
	end

	local function findReplacementTarget(originPosition)
		local bestEnemy = nil
		local bestDistance = math.huge

		for _, enemy in ipairs(enemySpatial:getCandidatesNear(startPos, radius)) do
			if enemy ~= target and isEnemyAlive(enemy) then
				if enemySpatial:isWithinTargetRadius(enemy, startPos, radius) then
					local enemyHrp = enemy:FindFirstChild("HumanoidRootPart")
					local distance = enemyHrp and (enemyHrp.Position - originPosition).Magnitude or math.huge
					if distance < bestDistance then
						bestDistance = distance
						bestEnemy = enemy
					end
				end
			end
		end

		return bestEnemy
	end

	if not isEnemyAlive(target) then
		target = findReplacementTarget(startPos)
		if not target then
			lastAttackTime[tower] = 0
			return false
		end
	end

	local targetHrp = getTargetHrp(target)
	if not targetHrp then
		lastAttackTime[tower] = 0
		return false
	end

	local function getFlatDistance(a, b)
		return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
	end

	local function getPredictedAimPosition(travelTime)
		local targetPosition = targetHrp.Position
		local targetVelocity = targetHrp.AssemblyLinearVelocity
		local flatVelocity = Vector3.new(targetVelocity.X, 0, targetVelocity.Z)

		return targetPosition + (flatVelocity * travelTime * 0.75)
	end

	local initialTargetPosition = targetHrp.Position
	local flatTargetDistance = getFlatDistance(startPos, initialTargetPosition)
	local travelTime = math.clamp(flatTargetDistance / SPIKE_INITIAL_SPEED, 0.35, SPIKE_MAX_TRAVEL_TIME - 0.1)
	local aimPosition = getPredictedAimPosition(travelTime)

	local rawLoftDirection = -arrowHomeCFrame.RightVector
	if rawLoftDirection.Magnitude < 0.001 then
		lastAttackTime[tower] = 0
		return false
	end
	rawLoftDirection = rawLoftDirection.Unit

	local flatAimOffset = Vector3.new(aimPosition.X - startPos.X, 0, aimPosition.Z - startPos.Z)
	local rawFlatDirection = Vector3.new(rawLoftDirection.X, 0, rawLoftDirection.Z)
	local flatAimDirection = Vector3.zAxis
	if flatAimOffset.Magnitude > 0.001 then
		flatAimDirection = flatAimOffset.Unit
	elseif rawFlatDirection.Magnitude > 0.001 then
		flatAimDirection = rawFlatDirection.Unit
	end
	local rawVertical = rawLoftDirection.Y
	local rawHorizontalMagnitude = math.sqrt(math.max(1 - (rawVertical * rawVertical), 0.001))
	local loftDirection = ((flatAimDirection * rawHorizontalMagnitude) + (Vector3.yAxis * rawVertical)).Unit

	loftDirection = loftDirection.Unit
	local currentDirection = loftDirection
	local arcControlDistance = math.clamp(flatTargetDistance * 0.45, 10, 48)
	local arcLandingPullback = math.clamp(flatTargetDistance * 0.18, 5, 24)
	local arcLift = math.clamp(flatTargetDistance * 0.08, 1.5, 12)

	local function cubicBezier(p0, p1, p2, p3, t)
		local inverse = 1 - t
		return (p0 * inverse * inverse * inverse)
			+ (p1 * 3 * inverse * inverse * t)
			+ (p2 * 3 * inverse * t * t)
			+ (p3 * t * t * t)
	end

	local function cubicBezierTangent(p0, p1, p2, p3, t)
		local inverse = 1 - t
		return ((p1 - p0) * 3 * inverse * inverse)
			+ ((p2 - p1) * 6 * inverse * t)
			+ ((p3 - p2) * 3 * t * t)
	end

	local function getArcTargetPosition()
		if isEnemyAlive(target) then
			local currentTargetHrp = getTargetHrp(target)
			if currentTargetHrp then
				local remaining = math.max(travelTime - elapsed, 0)
				local velocity = currentTargetHrp.AssemblyLinearVelocity
				local flatVelocity = Vector3.new(velocity.X, 0, velocity.Z)
				return currentTargetHrp.Position + (flatVelocity * remaining * 0.35)
			end
		end

		return aimPosition
	end

	local function getArcPoint(alpha)
		local targetPosition = getArcTargetPosition()
		local flatOffset = Vector3.new(targetPosition.X - startPos.X, 0, targetPosition.Z - startPos.Z)
		local landingDirection = flatAimDirection
		if flatOffset.Magnitude > 0.001 then
			landingDirection = flatOffset.Unit
		end

		local p0 = startPos
		local p1 = startPos + (loftDirection * arcControlDistance)
		local p3 = targetPosition
		local p2 = p3 - (landingDirection * arcLandingPullback) + (Vector3.yAxis * arcLift)
		local position = cubicBezier(p0, p1, p2, p3, alpha)
		local tangent = cubicBezierTangent(p0, p1, p2, p3, alpha)
		if tangent.Magnitude <= 0.001 then
			tangent = currentDirection
		end

		return position, tangent.Unit
	end

	local function getClosestPointOnSegment(point, segmentStart, segmentEnd)
		local segment = segmentEnd - segmentStart
		local segmentLengthSquared = segment:Dot(segment)
		if segmentLengthSquared <= 0.0001 then
			return segmentStart
		end

		local t = math.clamp((point - segmentStart):Dot(segment) / segmentLengthSquared, 0, 1)
		return segmentStart + (segment * t)
	end

	local originalTransparency = arrowTemplate:GetAttribute("SpikeOriginalTransparency")
	if typeof(originalTransparency) ~= "number" then
		originalTransparency = arrowTemplate.Transparency
		arrowTemplate:SetAttribute("SpikeOriginalTransparency", originalTransparency)
	end
	arrowTemplate.Transparency = 1

	local arrow = arrowTemplate:Clone()
	arrow.Name = "SpikeProjectile"
	arrow.Anchored = true
	arrow.CanCollide = false
	arrow.CanQuery = false
	arrow.CanTouch = false
	arrow.Transparency = originalTransparency
	arrow.CFrame = arrowHomeCFrame
	arrow.Parent = workspace

	local function playReloadAnimation()
		if not tower.Parent or not arrowTemplate.Parent then
			return
		end

		local reloadArrow = arrowTemplate:Clone()
		reloadArrow.Name = "SpikeReloadArrow"
		reloadArrow.Anchored = true
		reloadArrow.CanCollide = false
		reloadArrow.CanQuery = false
		reloadArrow.CanTouch = false
		reloadArrow.Transparency = originalTransparency
		reloadArrow.CFrame = arrowHomeCFrame + (arrowHomeCFrame.RightVector * SPIKE_RELOAD_DISTANCE)
		reloadArrow.Parent = tower

		TweenService:Create(reloadArrow, TweenInfo.new(GameSpeed:ScaleDuration(SPIKE_RELOAD_TIME), Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			CFrame = arrowHomeCFrame,
		}):Play()

		task.delay(GameSpeed:ScaleDuration(SPIKE_RELOAD_TIME), function()
			if reloadArrow and reloadArrow.Parent then
				reloadArrow:Destroy()
			end
			if arrowTemplate and arrowTemplate.Parent then
				arrowTemplate.Transparency = originalTransparency
			end
		end)
	end

	local function finish(hitEnemy, impactPosition, impactDirection)
		if finished then
			return
		end
		finished = true

		local finalDirection = impactDirection
		if not finalDirection or finalDirection.Magnitude <= 0.001 then
			finalDirection = currentDirection
		end
		finalDirection = finalDirection.Unit

		if hitEnemy and isEnemyAlive(hitEnemy) then
			damageSpikeEnemy(tower, towerState, hitEnemy, baseDamage, impactPosition or targetHrp.Position, finalDirection, damaged)

			local pierceCount = towerState.spikePierceCountVal and towerState.spikePierceCountVal.Value or 0
			local pierceFalloff = towerState.spikePierceDamageFalloffVal and towerState.spikePierceDamageFalloffVal.Value or 0
			local pierceOrigin = impactPosition
			if not pierceOrigin then
				local hitHrp = getLiveEnemyHrp(hitEnemy)
				pierceOrigin = hitHrp and hitHrp.Position or targetHrp.Position
			end

			local pierceDamage = baseDamage
			for pierceIndex = 1, pierceCount do
				local nextEnemy = findSpikeLineTarget(pierceOrigin, finalDirection, 1, damaged, math.huge, math.huge)
				if not nextEnemy then
					break
				end

				local nextHrp = getLiveEnemyHrp(nextEnemy)
				if not nextHrp then
					break
				end

				if pierceIndex > 1 or pierceFalloff > 0 then
					pierceDamage = math.max(1, pierceDamage - pierceFalloff)
				end

				fireSpikeVisualBetween(tower, pierceOrigin, nextHrp.Position, 0.08)
				damageSpikeEnemy(tower, towerState, nextEnemy, pierceDamage, nextHrp.Position, finalDirection, damaged)
				pierceOrigin = nextHrp.Position
			end
		end

		if arrow and arrow.Parent then
			if impactPosition and finalDirection and finalDirection.Magnitude > 0.001 then
				arrow.CFrame = cframeWithLocalXAxis(impactPosition, finalDirection)
			end

			if hitEnemy then
				if shouldStickSpike(towerState) then
					stickSpikeVisual(arrow, hitEnemy, impactPosition, finalDirection)
				else
					task.delay(GameSpeed:ScaleDuration(0.04), function()
						if arrow and arrow.Parent then
							arrow:Destroy()
						end
					end)
				end
			else
				arrow:Destroy()
			end
		end

		if not options.skipReload then
			playReloadAnimation()
		elseif arrowTemplate and arrowTemplate.Parent then
			task.delay(GameSpeed:ScaleDuration(0.03), function()
				if arrowTemplate and arrowTemplate.Parent then
					arrowTemplate.Transparency = originalTransparency
				end
			end)
		end
	end

	local connection
	connection = RunService.Heartbeat:Connect(function(dt)
		if finished or not arrow.Parent then
			if connection then
				connection:Disconnect()
			end
			return
		end

		local scaledDt = GameSpeed:ScaleDelta(dt)
		local currentPosition = arrow.Position
		elapsed += scaledDt
		local alpha = math.clamp(elapsed / travelTime, 0, 1)
		local nextPosition, tangentDirection = getArcPoint(alpha)
		currentDirection = tangentDirection
		local segment = nextPosition - currentPosition
		local segmentLength = segment.Magnitude
		local segmentSearchRadius = (segmentLength * 0.5) + SPIKE_HIT_RADIUS
		local segmentMidpoint = currentPosition:Lerp(nextPosition, 0.5)

		if isEnemyAlive(target) then
			local currentTargetHrp = getTargetHrp(target)
			if currentTargetHrp then
				local closestPoint = getClosestPointOnSegment(currentTargetHrp.Position, currentPosition, nextPosition)
				if (currentTargetHrp.Position - closestPoint).Magnitude <= SPIKE_HIT_RADIUS then
					finish(target, currentTargetHrp.Position, currentDirection)
					if connection then
						connection:Disconnect()
					end
					return
				end
			end
		end

		for _, enemy in ipairs(enemySpatial:getCandidatesNear(segmentMidpoint, segmentSearchRadius)) do
			if isEnemyAlive(enemy) then
				local hrp = getTargetHrp(enemy)
				if hrp then
					local closestPoint = getClosestPointOnSegment(hrp.Position, currentPosition, nextPosition)
					local flatDistanceSquared = enemySpatial.getFlatDistanceSquared(hrp.Position, closestPoint)
					local verticalDistance = math.abs(hrp.Position.Y - closestPoint.Y)
					if flatDistanceSquared <= SPIKE_HIT_RADIUS * SPIKE_HIT_RADIUS and verticalDistance <= SPIKE_HIT_RADIUS then
						finish(enemy, hrp.Position, currentDirection)
						if connection then
							connection:Disconnect()
						end
						return
					end
				end
			end
		end

		if elapsed >= travelTime then
			if isEnemyAlive(target) then
				local currentTargetHrp = getTargetHrp(target)
				if currentTargetHrp then
					local impactDirection = currentDirection
					if segment.Magnitude > 0.001 then
						impactDirection = segment.Unit
					end
					finish(target, currentTargetHrp.Position, impactDirection)
					if connection then
						connection:Disconnect()
					end
					return
				end
			end

			finish(nil)
			if connection then
				connection:Disconnect()
			end
			return
		end

		if elapsed >= SPIKE_MAX_TRAVEL_TIME then
			finish(nil)
			if connection then
				connection:Disconnect()
			end
			return
		end

		arrow.CFrame = cframeWithLocalXAxis(nextPosition, currentDirection)
	end)

	task.delay(GameSpeed:ScaleDuration(SPIKE_MAX_TRAVEL_TIME + 0.5), function()
		if connection then
			connection:Disconnect()
		end
		if not finished then
			finish(nil)
		end
	end)

	return true
end

function getRandomSpikeTarget(towerPosition, radius)
	local candidates = {}
	for _, entry in ipairs(getEnemiesInRadius(towerPosition, radius, false)) do
		if isEnemyAlive(entry.enemy) then
			table.insert(candidates, entry.enemy)
		end
	end

	if #candidates == 0 then
		return nil
	end

	return candidates[math.random(1, #candidates)]
end

function fireSpikeStormArrow(tower, towerState, enemy, index)
	local arrowTemplate = tower:FindFirstChild("Arrow", true)
	local hrp = getLiveEnemyHrp(enemy)
	if not arrowTemplate or not arrowTemplate:IsA("BasePart") or not hrp then
		return
	end

	local offsetAngle = ((index or 1) - 1) * math.pi
	local offset = Vector3.new(math.cos(offsetAngle) * 1.4, 0, math.sin(offsetAngle) * 1.4)
	local startPosition = hrp.Position + offset + Vector3.new(0, SPIKE_STORM_FALL_HEIGHT, 0)
	local arrow = arrowTemplate:Clone()
	arrow.Name = "SpikeStormArrow"
	arrow.Anchored = true
	arrow.CanCollide = false
	arrow.CanTouch = false
	arrow.CanQuery = false
	arrow.Transparency = arrowTemplate.Transparency
	arrow.CFrame = cframeWithLocalXAxis(startPosition, Vector3.new(0, 1, 0))
	arrow.Parent = workspace

	local elapsed = 0
	local finished = false
	local baseDamage = towerState.damageVal and towerState.damageVal.Value or 7
	local connection
	connection = RunService.Heartbeat:Connect(function(dt)
		if finished or not arrow.Parent then
			if connection then
				connection:Disconnect()
			end
			return
		end

		local currentHrp = getLiveEnemyHrp(enemy)
		if not currentHrp then
			finished = true
			arrow:Destroy()
			if connection then
				connection:Disconnect()
			end
			return
		end

		elapsed += GameSpeed:ScaleDelta(dt)
		local alpha = math.clamp(elapsed / SPIKE_STORM_FALL_TIME, 0, 1)
		local targetPosition = currentHrp.Position + offset + Vector3.new(0, 1, 0)
		local position = startPosition:Lerp(targetPosition, alpha)
		arrow.CFrame = cframeWithLocalXAxis(position, Vector3.new(0, 1, 0))

		if alpha >= 1 then
			finished = true
			damageSpikeEnemy(tower, towerState, enemy, baseDamage, currentHrp.Position, Vector3.new(0, -1, 0), {})
			if shouldStickSpike(towerState) then
				stickSpikeVisual(arrow, enemy, currentHrp.Position + Vector3.new(0, 1, 0), Vector3.new(0, 1, 0))
			else
				arrow:Destroy()
			end
			if connection then
				connection:Disconnect()
			end
		end
	end)

	task.delay(GameSpeed:ScaleDuration(SPIKE_STORM_FALL_TIME + 0.35), function()
		if not finished then
			finished = true
			if arrow and arrow.Parent then
				arrow:Destroy()
			end
			if connection then
				connection:Disconnect()
			end
		end
	end)
end

function updateSpikeStorm(tower, towerState, now)
	if not towerState.spikeStormEnabledVal or towerState.spikeStormEnabledVal.Value <= 0 then
		return
	end

	local interval = towerState.spikeStormIntervalVal and towerState.spikeStormIntervalVal.Value or 5
	local lastCast = spikeStormLastCast[tower] or 0
	if now - lastCast < GameSpeed:ScaleDuration(interval) then
		return
	end

	spikeStormLastCast[tower] = now
	local arrowsPerEnemy = math.max(1, towerState.spikeStormArrowsPerEnemyVal and towerState.spikeStormArrowsPerEnemyVal.Value or 2)
	for enemy in pairs(activeEnemies) do
		if isEnemyAlive(enemy) then
			for i = 1, arrowsPerEnemy do
				task.delay(GameSpeed:ScaleDuration((i - 1) * 0.08), function()
					if tower.Parent then
						fireSpikeStormArrow(tower, towerState, enemy, i)
					end
				end)
			end
		end
	end
end

function fireSpikeAttack(tower, towerState, target)
	if not isEnemyAlive(target) then
		return false
	end

	local towerPosition = getTowerPosition(tower)
	if not towerPosition then
		return false
	end

	local radius = towerState.radiusVal and towerState.radiusVal.Value or 34
	local attackCount = (spikeAttackCounts[tower] or 0) + 1
	spikeAttackCounts[tower] = attackCount
	spikeLastActiveAt[tower] = tick()

	local overdriveStep = towerState.spikeOverdriveStepVal and towerState.spikeOverdriveStepVal.Value or 0
	local overdriveMax = towerState.spikeOverdriveMaxVal and towerState.spikeOverdriveMaxVal.Value or 0
	if overdriveStep > 0 and overdriveMax > 0 then
		local maxStacks = math.max(1, math.floor(overdriveMax / overdriveStep + 0.5))
		spikeOverdriveStacks[tower] = math.min(maxStacks, (spikeOverdriveStacks[tower] or 0) + 1)
	end

	local fired = false
	local shots = math.max(1, towerState.spikeShotsPerAttackVal and towerState.spikeShotsPerAttackVal.Value or 1)
	for shotIndex = 1, shots do
		task.delay(GameSpeed:ScaleDuration((shotIndex - 1) * 0.08), function()
			if tower.Parent then
				fireSpikeArrow(tower, towerState, target, { skipReload = shotIndex ~= shots })
			end
		end)
		fired = true
	end

	local nthAttack = towerState.spikeEveryNthAttackVal and towerState.spikeEveryNthAttackVal.Value or 0
	local randomExtras = towerState.spikeExtraRandomShotsVal and towerState.spikeExtraRandomShotsVal.Value or 0
	if nthAttack > 0 and randomExtras > 0 and attackCount % nthAttack == 0 then
		for extraIndex = 1, randomExtras do
			task.delay(GameSpeed:ScaleDuration((shots + extraIndex - 1) * 0.08), function()
				if not tower.Parent then
					return
				end
				local randomTarget = getRandomSpikeTarget(towerPosition, radius)
				if randomTarget then
					fireSpikeArrow(tower, towerState, randomTarget, { skipReload = true })
				end
			end)
			fired = true
		end
	end

	return fired
end

local function isEnemyPoisoned(tower, enemy)
	return activePoisonedEnemies[enemy] == true
end

applyDirectDamage = function(enemy, damage)
	if not enemy or not enemy.Parent then
		return
	end

	if ReplicatedStorage:GetAttribute("DevOpenEnemies") then
		return
	end

	local healthVal = enemy:FindFirstChild("Health")
	if not healthVal or healthVal.Value <= 0 then
		return
	end

	damage = math.max(0, damage or 0)
	local actualDamage = math.min(healthVal.Value, damage)
	healthVal.Value -= damage
	RunStats:RecordDamageDealt(actualDamage)

	if healthVal.Value <= 0 then
		spreadConductivityOnDeath(enemy)

		local humanoid = enemy:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.Health = 0
		end
	end
end



local function isMetallic(enemy)
	return enemy:FindFirstChild("Metallic") ~= nil
		or enemy:FindFirstChild("ConductiveMetallic") ~= nil
end
local function removeConductivity(enemy)
	local state = conductiveEnemies[enemy]
	if not state then
		return
	end

	local conductiveTag = enemy:FindFirstChild("Conductive")
	if conductiveTag then
		conductiveTag:Destroy()
	end

	local metallicClone = enemy:FindFirstChild("ConductiveMetallic")
	if metallicClone then
		metallicClone:Destroy()
	end

	local sparks = enemy:FindFirstChild("ConductiveSparks", true)
	if sparks then
		sparks:Destroy()
	end

	conductiveEnemies[enemy] = nil
end



local function applySlowEffect(enemy, towerState)
	if not enemy or not enemy.Parent then
		return
	end

	local speedVal, baseSpeed = getEnemyBaseSpeed(enemy)
	if not speedVal or not baseSpeed then
		return
	end

	local slowDuration = towerState.slowDurationVal and towerState.slowDurationVal.Value or 2
	local strengthMultiplier = towerState.magnetStrengthMultiplierVal and towerState.magnetStrengthMultiplierVal.Value or 1
	local immobilizeDuration = towerState.magnetImmobilizeDurationVal and towerState.magnetImmobilizeDurationVal.Value or 0
	local divisorMultiplier = 1
	local now = tick()

	if isTankEnemy(enemy) then
		if tankSlowImmuneUntil[enemy] and now < tankSlowImmuneUntil[enemy] then
			return
		end

		slowDuration = math.min(slowDuration, TANK_MAX_MAGNET_SLOW_DURATION)
		immobilizeDuration = math.min(immobilizeDuration, TANK_MAX_IMMOBILIZE_DURATION)
		divisorMultiplier = TANK_MAGNET_SLOW_DIVISOR_MULTIPLIER
	end

	local newState = {
		expiresAt = now + slowDuration,
		immobilizeUntil = now + math.min(immobilizeDuration, slowDuration),
		divisor = math.max(1, strengthMultiplier * 2 * divisorMultiplier),
	}

	local oldState = enemySlowStates[enemy]
	if oldState and not isTankEnemy(enemy) then
		newState.expiresAt = math.max(oldState.expiresAt, newState.expiresAt)
		newState.immobilizeUntil = math.max(oldState.immobilizeUntil, newState.immobilizeUntil)
		newState.divisor = math.max(oldState.divisor, newState.divisor)
	end

	enemySlowStates[enemy] = newState
	slowedEnemies[enemy] = true
	if isTankEnemy(enemy) then
		tankSlowImmuneUntil[enemy] = newState.expiresAt + TANK_MAGNET_SLOW_REAPPLY_COOLDOWN
	end

	recomputeEnemySpeed(
		enemy,
		staticFieldAffectedEnemies[enemy] and 1 or nil,
		EnemyBehaviors.hasSupportAura(enemy),
		now
	)

	task.delay(slowDuration + 0.05, function()
		local state = enemySlowStates[enemy]
		if state and tick() >= state.expiresAt then
			enemySlowStates[enemy] = nil
			slowedEnemies[enemy] = nil

			if enemy and enemy.Parent then
				recomputeEnemySpeed(
					enemy,
					nil,
					EnemyBehaviors.hasSupportAura(enemy),
					tick()
				)
			end
		end
	end)
end
applyKnockback = function(enemy, studs, sourcePosition)
	if not enemy or not enemy.Parent or studs <= 0 then
		return
	end

	local hrp = enemy:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return
	end

	local knockbackDirection
	if isTankEnemy(enemy) then
		local now = tick()
		if tankKnockbackUntil[enemy] and now < tankKnockbackUntil[enemy] then
			return
		end

		tankKnockbackUntil[enemy] = now + TANK_KNOCKBACK_COOLDOWN
		knockbackDirection = hrp.CFrame.RightVector
		studs *= TANK_KNOCKBACK_MULTIPLIER
	elseif typeof(sourcePosition) == "Vector3" then
		local now = tick()
		local lastKnockback = knockbackLastApplied[enemy]
		if lastKnockback and now - lastKnockback < GENERAL_KNOCKBACK_COOLDOWN then
			return
		end
		knockbackLastApplied[enemy] = now

		local awayFromSource = Vector3.new(
			hrp.Position.X - sourcePosition.X,
			0,
			hrp.Position.Z - sourcePosition.Z
		)

		if awayFromSource.Magnitude > 0.001 then
			knockbackDirection = awayFromSource.Unit
		end
	end

	knockbackDirection = knockbackDirection or -hrp.CFrame.LookVector
	local knockbackOffset = knockbackDirection * studs

	if enemy:IsA("Model") then
		enemy:PivotTo(enemy:GetPivot() + knockbackOffset)
	else
		hrp.CFrame = hrp.CFrame + knockbackOffset
	end
end

local function getTargetCandidate(tower, enemy, towerPosition, radius, requireUnpoisoned)
	if not enemy.Parent then
		unregisterEnemy(enemy)
		return nil
	end

	local hrp = enemy:FindFirstChild("HumanoidRootPart")
	local healthVal = enemy:FindFirstChild("Health")
	if not hrp or not healthVal or healthVal.Value <= 0 then
		return nil
	end

	if requireUnpoisoned and isEnemyPoisoned(tower, enemy) then
		return nil
	end

	if enemySpatial:isWithinTargetRadius(enemy, towerPosition, radius) then
		return {
			enemy = enemy,
			hrp = hrp,
			health = healthVal.Value,
			distance = enemySpatial:getTargetDistance(enemy, towerPosition),
		}
	end

	return nil
end

local function insertNearestCandidate(candidates, candidate, maxTargets)
	local insertIndex = #candidates + 1
	while insertIndex > 1 and candidate.distance < candidates[insertIndex - 1].distance do
		insertIndex -= 1
	end

	if insertIndex > maxTargets then
		return
	end

	table.insert(candidates, insertIndex, candidate)
	if #candidates > maxTargets then
		table.remove(candidates)
	end
end

local function findTargetEnemies(tower, towerPosition, radius, requireUnpoisoned, maxTargets)
	maxTargets = math.max(1, maxTargets or 1)

	local candidates = {}

	for _, enemy in ipairs(enemySpatial:getCandidatesNear(towerPosition, radius)) do
		local candidate = getTargetCandidate(tower, enemy, towerPosition, radius, requireUnpoisoned)
		if candidate then
			insertNearestCandidate(candidates, candidate, maxTargets)
		end
	end

	local results = {}
	for i = 1, math.min(maxTargets, #candidates) do
		table.insert(results, candidates[i].enemy)
	end

	return results
end
local function getTargetingMode(tower)
	local modeVal = tower:FindFirstChild("TargetingMode")
	if modeVal and modeVal:IsA("StringValue") then
		local mode = string.lower(modeVal.Value)
		if mode == "closest" or mode == "furthest" or mode == "strongest" or mode == "weakest" then
			return mode
		end
		if mode == "first" then
			return "closest"
		end
		if mode == "last" then
			return "furthest"
		end
	end

	return "closest"
end

local function isBetterTargetPriority(priority, bestPriority, mode)
	if not bestPriority then
		return true
	end

	if mode == "furthest" then
		if priority.distanceToTower ~= bestPriority.distanceToTower then
			return priority.distanceToTower > bestPriority.distanceToTower
		end
		return priority.distanceToGoal < bestPriority.distanceToGoal
	elseif mode == "strongest" then
		if priority.health ~= bestPriority.health then
			return priority.health > bestPriority.health
		end
		return priority.distanceToTower < bestPriority.distanceToTower
	elseif mode == "weakest" then
		if priority.health ~= bestPriority.health then
			return priority.health < bestPriority.health
		end
		return priority.distanceToTower < bestPriority.distanceToTower
	end

	if priority.distanceToTower ~= bestPriority.distanceToTower then
		return priority.distanceToTower < bestPriority.distanceToTower
	end
	return priority.distanceToGoal < bestPriority.distanceToGoal
end

local function findBestTargetByMode(tower, towerPosition, radius, requireUnpoisoned, mode)
	local finalWaypointPosition = ACID_RAIN_BASE_PART.Position
	local bestPriority = nil

	for _, enemy in ipairs(enemySpatial:getCandidatesNear(towerPosition, radius)) do
		local candidate = getTargetCandidate(tower, enemy, towerPosition, radius, requireUnpoisoned)
		if candidate then
			local priority = {
				enemy = candidate.enemy,
				distanceToTower = candidate.distance,
				distanceToGoal = (candidate.hrp.Position - finalWaypointPosition).Magnitude,
				health = candidate.health,
			}

			if isBetterTargetPriority(priority, bestPriority, mode) then
				bestPriority = priority
			end
		end
	end

	return bestPriority and bestPriority.enemy or nil
end

local function isTargetStillValid(tower, target, towerPosition, radius, requireUnpoisoned)
	if not target or not target.Parent then
		return false
	end

	local hrp = target:FindFirstChild("HumanoidRootPart")
	local healthVal = target:FindFirstChild("Health")
	if not hrp or not healthVal or healthVal.Value <= 0 then
		return false
	end

	if requireUnpoisoned and isEnemyPoisoned(tower, target) then
		return false
	end

	return enemySpatial:getTargetDistance(target, towerPosition) <= radius
end

local function getOrAcquireTarget(tower, towerPosition, radius, requireUnpoisoned)
	local mode = getTargetingMode(tower)
	if targetingModes[tower] ~= mode then
		targetingModes[tower] = mode
		currentTargets[tower] = nil
	end

	local current = currentTargets[tower]
	if isTargetStillValid(tower, current, towerPosition, radius, requireUnpoisoned) then
		return current
	end

	local newTarget = findBestTargetByMode(tower, towerPosition, radius, requireUnpoisoned, mode)
	currentTargets[tower] = newTarget

	return newTarget
end
local faceTarget
local function updateCannonTracking(tower, towerState, towerPosition)
	if towerState.towerType ~= "Cannon" and towerState.towerType ~= "Spike Thrower" and towerState.towerType ~= "Oil Launcher" then
		return
	end

	local radius = towerState.radiusVal and towerState.radiusVal.Value or 20
	local requireUnpoisoned = towerState.poisonousVal and towerState.poisonousVal:IsA("IntValue")
	local target = getOrAcquireTarget(tower, towerPosition, radius, requireUnpoisoned)

	if target and target.Parent then
		local hrp = target:FindFirstChild("HumanoidRootPart")
		local healthVal = target:FindFirstChild("Health")

		if hrp and healthVal and healthVal.Value > 0 then
			faceTarget(tower, hrp.Position, towerState.towerType)
			return
		end
	end

	currentTargets[tower] = nil
end
local function playAcidRainCloud(duration)
	local cloud = ACID_RAIN_CLOUD_TEMPLATE:Clone()
	cloud.Parent = workspace
	cloud.Anchored = true
	cloud.CanCollide = false
	cloud.CanQuery = false
	cloud.CastShadow = false

	local rainEffect = cloud:FindFirstChild("RainEffect")
	if rainEffect and rainEffect:IsA("BasePart") then
		rainEffect.Anchored = true
		rainEffect.CanCollide = false
		rainEffect.CanQuery = false
	end

	local cloudOriginalSize = cloud.Size
	local rainOriginalSize = rainEffect and rainEffect.Size or nil

	cloud.Size = cloudOriginalSize * 0.2
	if rainEffect and rainOriginalSize then
		rainEffect.Size = rainOriginalSize * 0.2
	end

	local growCloud = TweenService:Create(
		cloud,
		TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{Size = cloudOriginalSize * 1.08}
	)

	local settleCloud = TweenService:Create(
		cloud,
		TweenInfo.new(0.10, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
		{Size = cloudOriginalSize}
	)

	local growRain
	local settleRain

	if rainEffect and rainOriginalSize then
		growRain = TweenService:Create(
			rainEffect,
			TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{Size = rainOriginalSize * 1.08}
		)

		settleRain = TweenService:Create(
			rainEffect,
			TweenInfo.new(0.10, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
			{Size = rainOriginalSize}
		)
	end

	growCloud:Play()
	if growRain then
		growRain:Play()
	end

	growCloud.Completed:Once(function()
		if cloud and cloud.Parent then
			settleCloud:Play()
		end
	end)

	if growRain and settleRain then
		growRain.Completed:Once(function()
			if rainEffect and rainEffect.Parent then
				settleRain:Play()
			end
		end)
	end

	task.delay(duration, function()
		if not cloud or not cloud.Parent then
			return
		end

		local puffCloud = TweenService:Create(
			cloud,
			TweenInfo.new(0.06, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
			{Size = cloudOriginalSize * 1.04}
		)

		local closeCloud = TweenService:Create(
			cloud,
			TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.In),
			{Size = cloudOriginalSize * 0.12}
		)

		local puffRain
		local closeRain

		if rainEffect and rainEffect.Parent and rainOriginalSize then
			puffRain = TweenService:Create(
				rainEffect,
				TweenInfo.new(0.06, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
				{Size = rainOriginalSize * 1.04}
			)

			closeRain = TweenService:Create(
				rainEffect,
				TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.In),
				{Size = rainOriginalSize * 0.12}
			)
		end

		puffCloud:Play()
		if puffRain then
			puffRain:Play()
		end

		puffCloud.Completed:Once(function()
			if cloud and cloud.Parent then
				closeCloud:Play()
			end
		end)

		if puffRain and closeRain then
			puffRain.Completed:Once(function()
				if rainEffect and rainEffect.Parent then
					closeRain:Play()
				end
			end)
		end

		task.delay(0.2, function()
			if cloud and cloud.Parent then
				cloud:Destroy()
			end
		end)
	end)

	return cloud, rainEffect
end
getEnemiesInRadius = function(centerPosition, radius, metallicOnly)
	local results = {}

	for _, enemy in ipairs(enemySpatial:getCandidatesNear(centerPosition, radius)) do
		if enemy.Parent then
			local hrp = enemy:FindFirstChild("HumanoidRootPart")
			local healthVal = enemy:FindFirstChild("Health")

			if hrp and healthVal and healthVal.Value > 0 then
				if not metallicOnly or isMetallic(enemy) then
					if enemySpatial:isWithinTargetRadius(enemy, centerPosition, radius) then
						local distance = enemySpatial:getTargetDistance(enemy, centerPosition)
						table.insert(results, {
							enemy = enemy,
							distance = distance,
						})
					end
				end
			end
		end
	end

	table.sort(results, function(a, b)
		return a.distance < b.distance
	end)

	return results
end
local function startAcidRain(towerState)
	local duration = towerState.acidRainDurationVal and towerState.acidRainDurationVal.Value or 3
	local tickRate = towerState.acidRainTickRateVal and towerState.acidRainTickRateVal.Value or 0.5
	local damage = towerState.acidRainDamageVal and towerState.acidRainDamageVal.Value or 5

	local cloud, rainEffect = playAcidRainCloud(duration)

	task.spawn(function()
		local elapsed = 0

		while elapsed < duration do
			local centerPart = rainEffect and rainEffect.Parent and rainEffect or cloud
			if not centerPart or not centerPart.Parent then
				break
			end

			local centerPosition = centerPart.Position
			local radius = 12

			if rainEffect and rainEffect.Parent then
				radius = math.max(rainEffect.Size.X, rainEffect.Size.Z) * 0.5
			end

			for _, enemy in ipairs(enemySpatial:getCandidatesNear(centerPosition, radius)) do
				if enemy.Parent then
					local hrp = enemy:FindFirstChild("HumanoidRootPart")
					local healthVal = enemy:FindFirstChild("Health")

					if hrp and healthVal and healthVal.Value > 0 then
						if enemySpatial:isWithinTargetRadius(enemy, centerPosition, radius) then
							applyDirectDamage(enemy, damage)
						end
					end
				end
			end

			task.wait(GameSpeed:ScaleDuration(tickRate))
			elapsed += tickRate
		end
	end)
end
local function playTowerAnim(tower, target, towerType)
	local track = towerAnimators[tower]
	if track then
		if animCooldown[tower] then
			return
		end

		animCooldown[tower] = true
		track:Stop(0)
		track:Play()
		track:AdjustSpeed(GameSpeed:Get())
	end

	if towerType == "Cannon" then
		local recoilPart = tower
		if tower:IsA("Model") then
			recoilPart = tower:FindFirstChild("Deploy", true) or tower:FindFirstChildOfClass("BasePart")
		end

		doRecoil(recoilPart)

		local shotsPerAttack = 1
		local shotsVal = tower:FindFirstChild("ShotsPerAttack")
		if shotsVal and shotsVal:IsA("IntValue") then
			shotsPerAttack = math.max(1, shotsVal.Value)
		end

		task.delay(GameSpeed:ScaleDuration(BALL_DEPLOY_TIME), function()
			local explosionObj = tower:FindFirstChild("Explosion", true)
			local enabledEmitters = {}

			for shotIndex = 1, shotsPerAttack do
				task.delay(GameSpeed:ScaleDuration((shotIndex - 1) * 0.08), function()
					if not tower or not tower.Parent then
						return
					end

					playCannonShotSound(tower)

					if explosionObj then
						if explosionObj:IsA("ParticleEmitter") then
							explosionObj.Enabled = true
							table.insert(enabledEmitters, explosionObj)
						end

						for _, obj in ipairs(explosionObj:GetDescendants()) do
							if obj:IsA("ParticleEmitter") then
								obj.Enabled = true
								table.insert(enabledEmitters, obj)
							end
						end
					end

					local liveTowerState = towerStateCache[tower] or buildTowerState(tower)
					towerStateCache[tower] = liveTowerState
					fireCannonBall(tower, liveTowerState, target)
				end)
			end

			task.delay(GameSpeed:ScaleDuration(0.5 + ((shotsPerAttack - 1) * 0.08)), function()
				for _, emitter in ipairs(enabledEmitters) do
					if emitter and emitter.Parent then
						emitter.Enabled = false
					end
				end
			end)
		end)
	end

	if towerType == "Mushroom" then
		task.delay(GameSpeed:ScaleDuration(0.3), function()
			playMushroomAttackSound(tower)

			local spray = tower:FindFirstChild("Spray", true)
			if spray then
				local middle = spray:FindFirstChild("Middle")
				local splash = middle and middle:FindFirstChild("Splash")
				if splash then
					splash.Enabled = true
					task.delay(GameSpeed:ScaleDuration(0.5), function()
						if splash and splash.Parent then
							splash.Enabled = false
						end
					end)
				end
			end
		end)
	end

	if towerType == "Tesla Coil" then
		local auraPart = tower:FindFirstChild("Aura")
		local attachment = auraPart and auraPart:FindFirstChild("Attachment")
		local auraEmitter = attachment and attachment:FindFirstChild("Aura")
		if auraEmitter then
			auraEmitter.Enabled = true
			playTeslaAttackSound(tower, 0.5)

			task.delay(GameSpeed:ScaleDuration(0.5), function()
				if auraEmitter and auraEmitter.Parent then
					auraEmitter.Enabled = false
				end
			end)
		end
	end

	if towerType == "Magnet" then
		task.delay(GameSpeed:ScaleDuration(0.3), function()
			local emitters = {}
			local staticFieldModel = tower:FindFirstChild("StaticField")
			local distortionZoneModel = tower:FindFirstChild("DistortionZone")

			for _, obj in tower:GetDescendants() do
				if obj:IsA("ParticleEmitter") then
					local insideStaticField = staticFieldModel and obj:IsDescendantOf(staticFieldModel)
					local insideDistortionZone = distortionZoneModel and obj:IsDescendantOf(distortionZoneModel)

					if not insideStaticField and not insideDistortionZone then
						table.insert(emitters, obj)
						obj.Enabled = true
					end
				end
			end

			playMagnetAttackSound(tower, 1.2)

			task.delay(GameSpeed:ScaleDuration(0.6), function()
				for _, emitter in ipairs(emitters) do
					if emitter and emitter.Parent then
						emitter.Enabled = false
					end
				end
			end)
		end)
	end

	if towerType == "Oil Launcher" then
		task.delay(GameSpeed:ScaleDuration(OIL_PARTICLE_START_TIME), function()
			if not tower or not tower.Parent then
				return
			end

			setupOilSprayFollower(tower)
			local sprayPart = tower:FindFirstChild("C - STRONG WATER SPRAY", true)
			if not sprayPart then
				return
			end

			local emitters = {}
			for _, obj in ipairs(sprayPart:GetDescendants()) do
				if obj:IsA("ParticleEmitter") then
					table.insert(emitters, obj)
					obj.Enabled = true
				end
			end

			task.delay(GameSpeed:ScaleDuration(OIL_PARTICLE_END_TIME - OIL_PARTICLE_START_TIME), function()
				for _, emitter in ipairs(emitters) do
					if emitter and emitter.Parent then
						emitter.Enabled = false
					end
				end
			end)
		end)
	end

	if track then
		local cooldownDuration = towerType == "Oil Launcher" and OIL_PARTICLE_END_TIME or ANIM_DURATION
		task.delay(GameSpeed:ScaleDuration(cooldownDuration), function()
			animCooldown[tower] = false
		end)
	end
end
faceTarget = function(tower, targetPosition, towerType)
	local towerPos
	if tower:IsA("Model") then
		towerPos = tower:GetPivot().Position
	elseif tower:IsA("BasePart") then
		towerPos = tower.Position
	else
		return
	end

	local direction = Vector3.new(targetPosition.X - towerPos.X, 0, targetPosition.Z - towerPos.Z)
	if direction.Magnitude < 0.001 then
		return
	end

	local facingCFrame = CFrame.lookAt(towerPos, towerPos + direction)
	local yOffset = math.rad(-90)
	local rotatedCFrame = facingCFrame * CFrame.Angles(0, yOffset, 0)

	if tower:IsA("Model") then
		if towerType == "Oil Launcher" then
			tower:PivotTo(tower:GetPivot():Lerp(rotatedCFrame, 0.18))
		else
			tower:PivotTo(rotatedCFrame)
		end
	else
		tower.CFrame = rotatedCFrame
	end
end

getTowerPosition = function(tower)
	if tower:IsA("BasePart") then
		return tower.Position
	end

	if tower:IsA("Model") then
		local rootPart = tower.PrimaryPart or tower:FindFirstChild("HumanoidRootPart") or tower:FindFirstChildOfClass("BasePart")
		return rootPart and rootPart.Position or tower:GetPivot().Position
	end
end

local function getTowerOwner(tower)
	local ownerUserId = tower:GetAttribute("OwnerUserId")
	if typeof(ownerUserId) == "number" then
		return Players:GetPlayerByUserId(ownerUserId)
	end

	local players = Players:GetPlayers()
	if #players == 1 then
		return players[1]
	end

	return nil
end

local function ensureNumberValue(parent, name, value)
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA("NumberValue") then
		return existing
	end

	if existing then
		existing:Destroy()
	end

	local newValue = Instance.new("NumberValue")
	newValue.Name = name
	newValue.Value = value
	newValue.Parent = parent
	return newValue
end

local function ensureStringValue(parent, name, value)
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA("StringValue") then
		return existing
	end

	if existing then
		existing:Destroy()
	end

	local newValue = Instance.new("StringValue")
	newValue.Name = name
	newValue.Value = value
	newValue.Parent = parent
	return newValue
end

local function getTowerAdornee(tower)
	if tower:IsA("BasePart") then
		return tower
	end

	if tower:IsA("Model") then
		return tower:FindFirstChild("HumanoidRootPart", true) or tower:FindFirstChildWhichIsA("BasePart", true)
	end

	return nil
end

local function setExtractorHeatingBillboard(tower, visible)
	local existing = tower:FindFirstChild("ExtractorHeatingBillboard", true)
	if existing then
		existing.Enabled = visible
		return
	end

	if not visible then
		return
	end

	if existing then
		return
	end

	local adornee = getTowerAdornee(tower)
	if not adornee then
		return
	end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ExtractorHeatingBillboard"
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.MaxDistance = 100000
	billboard.Size = UDim2.new(0, 70, 0, 70)
	billboard.StudsOffset = Vector3.new(0, 5, 0)
	billboard.Parent = adornee

	local icon = Instance.new("ImageLabel")
	icon.Name = "Icon"
	icon.BackgroundTransparency = 1
	icon.Image = "rbxassetid://129960581618789"
	icon.ImageTransparency = 0
	icon.Size = UDim2.new(1, 0, 1, 0)
	icon.Parent = billboard
end

local function updateExtractor(tower, towerState, now)
	if towerState.towerType ~= "Extractor" then
		return
	end

	local owner = getTowerOwner(tower)
	if not owner then
		return
	end

	local heatVal = towerState.extractorHeatVal or ensureNumberValue(tower, "ExtractorHeat", 0)
	local stateVal = towerState.extractorStateVal or ensureStringValue(tower, "ExtractorState", "Running")
	ensureNumberValue(tower, "ExtractorTickInterval", towerState.extractorTickIntervalVal and towerState.extractorTickIntervalVal.Value or 5)
	ensureNumberValue(tower, "ExtractorSafeTime", towerState.extractorSafeTimeVal and towerState.extractorSafeTimeVal.Value or 45)
	ensureNumberValue(tower, "ExtractorHeatRate", towerState.extractorHeatRateVal and towerState.extractorHeatRateVal.Value or 2.25)
	ensureNumberValue(tower, "ExtractorShutdownDuration", towerState.extractorShutdownDurationVal and towerState.extractorShutdownDurationVal.Value or 30)
	local restartDurationVal = towerState.extractorRestartDurationVal or ensureNumberValue(tower, "ExtractorRestartDuration", 3)
	local restartCooldownVal = towerState.extractorRestartCooldownVal or ensureNumberValue(tower, "ExtractorRestartCooldown", 8)
	local restartReadyAtVal = towerState.extractorRestartReadyAtVal or ensureNumberValue(tower, "ExtractorRestartReadyAt", 0)
	local restartUntilVal = towerState.extractorRestartUntilVal or ensureNumberValue(tower, "ExtractorRestartUntil", 0)
	local restartRequestVal = towerState.extractorRestartRequestVal or ensureNumberValue(tower, "ExtractorRestartRequest", 0)

	local lastRestartRequest = extractorRuntime.lastRestartRequest[tower]
	if lastRestartRequest == nil then
		extractorRuntime.lastRestartRequest[tower] = restartRequestVal.Value
	elseif restartRequestVal.Value ~= lastRestartRequest then
		extractorRuntime.lastRestartRequest[tower] = restartRequestVal.Value
		local cooldownUntil = extractorRuntime.restartCooldownUntil[tower] or 0
		local alreadyRestartingUntil = extractorRuntime.restartUntil[tower] or 0
		local currentlyOverheated = extractorRuntime.shutdownUntil[tower] and now < extractorRuntime.shutdownUntil[tower]
		if now >= cooldownUntil and now >= alreadyRestartingUntil and not currentlyOverheated then
			local restartDuration = restartDurationVal.Value
			extractorRuntime.restartUntil[tower] = now + GameSpeed:ScaleDuration(restartDuration)
			extractorRuntime.restartCooldownUntil[tower] = extractorRuntime.restartUntil[tower] + GameSpeed:ScaleDuration(restartCooldownVal.Value)
			restartUntilVal.Value = extractorRuntime.restartUntil[tower]
			restartReadyAtVal.Value = extractorRuntime.restartCooldownUntil[tower]
		end
	end

	local enabled = not towerState.extractorEnabledVal or towerState.extractorEnabledVal.Value > 0
	if not enabled then
		setExtractorHeatingBillboard(tower, false)
		stateVal.Value = "Disabled"
		return
	end

	local restartingUntil = extractorRuntime.restartUntil[tower]
	if restartingUntil and now < restartingUntil then
		local remaining = math.max(0, math.ceil(restartingUntil - now))
		stateVal.Value = "Restarting - " .. tostring(remaining) .. "s"
		setExtractorHeatingBillboard(tower, true)
		return
	end

	if restartingUntil and now >= restartingUntil then
		extractorRuntime.restartUntil[tower] = nil
		restartUntilVal.Value = 0
		extractorRuntime.shutdownUntil[tower] = nil
		extractorRuntime.runStartedAt[tower] = now
		extractorRuntime.startingHeat[tower] = nil
		heatVal.Value = 0
		stateVal.Value = "Running"
		setExtractorHeatingBillboard(tower, false)
	end

	local shutdownUntil = extractorRuntime.shutdownUntil[tower]
	if shutdownUntil and now < shutdownUntil then
		local remaining = math.max(0, math.ceil(shutdownUntil - now))
		stateVal.Value = "Overheated - " .. tostring(remaining) .. "s"
		setExtractorHeatingBillboard(tower, true)
		return
	end

	if shutdownUntil and now >= shutdownUntil then
		extractorRuntime.shutdownUntil[tower] = nil
		extractorRuntime.runStartedAt[tower] = now
		extractorRuntime.startingHeat[tower] = nil
		heatVal.Value = 0
		stateVal.Value = "Running"
		setExtractorHeatingBillboard(tower, false)
	end

	stateVal.Value = "Running"
	local runStartedAt = extractorRuntime.runStartedAt[tower] or now
	extractorRuntime.runStartedAt[tower] = runStartedAt

	local safeTime = towerState.extractorSafeTimeVal and towerState.extractorSafeTimeVal.Value or 45
	local heatRate = towerState.extractorHeatRateVal and towerState.extractorHeatRateVal.Value or 2.25
	local hotTime = math.max(0, (now - runStartedAt - GameSpeed:ScaleDuration(safeTime)) * GameSpeed:Get())
	local startingHeat = extractorRuntime.startingHeat[tower] or 0
	heatVal.Value = math.clamp(startingHeat + (hotTime * heatRate), 0, EXTRACTOR_OVERHEAT_HEAT)
	setExtractorHeatingBillboard(tower, heatVal.Value > 0)

	if heatVal.Value >= EXTRACTOR_OVERHEAT_HEAT then
		local shutdownDuration = towerState.extractorShutdownDurationVal and towerState.extractorShutdownDurationVal.Value or 30
		extractorRuntime.shutdownUntil[tower] = now + GameSpeed:ScaleDuration(shutdownDuration)
		extractorRuntime.startingHeat[tower] = nil
		stateVal.Value = "Overheated - " .. tostring(math.ceil(shutdownDuration)) .. "s"
		setExtractorHeatingBillboard(tower, true)
		if not extractorRuntime.overheatWarned[tower] then
			extractorRuntime.overheatWarned[tower] = true
			WarningRemote:FireClient(owner, "ExtractorOverheated")
		end
		return
	end

	local tickInterval = towerState.extractorTickIntervalVal and towerState.extractorTickIntervalVal.Value or 5
	local lastMine = extractorRuntime.lastMine[tower] or 0
	if now - lastMine < GameSpeed:ScaleDuration(math.max(1, tickInterval)) then
		return
	end

	local towerPosition = getTowerPosition(tower)
	if not towerPosition then
		return
	end

	local radius = towerState.radiusVal and towerState.radiusVal.Value or 20
	local targetResources = ResourceMiningService:GetResourcesInRadius(towerPosition, radius)
	if #targetResources > 0 then
		extractorRuntime.lastMine[tower] = now
		for _, resource in targetResources do
			ResourceMiningService:Mine(resource, owner, 1, { manual = false })
		end
	end
end

local function getTeslaDamageMultiplier(teslaTower)
	local teslaPosition = getTowerPosition(teslaTower)
	if not teslaPosition then
		return 1
	end

	local bestMultiplier = 1

	for tower in pairs(activeTowers) do
		if tower ~= teslaTower and tower.Parent and getTowerType(tower) == "Magnet" then
			local buffFlag = tower:FindFirstChild("BuffsTeslaCoilsInRange")
			if buffFlag and buffFlag:IsA("IntValue") and buffFlag.Value > 0 then
				local magnetPosition = getTowerPosition(tower)
				local magnetRadius = tower:FindFirstChild("Radius")
				local buffMultiplier = tower:FindFirstChild("TeslaBuffMultiplier")

				if magnetPosition and magnetRadius then
					if (teslaPosition - magnetPosition).Magnitude <= magnetRadius.Value then
						bestMultiplier = math.max(bestMultiplier, buffMultiplier and buffMultiplier.Value or 2)
					end
				end
			end
		end
	end

	return bestMultiplier
end
local function roundDamage(value)
	return math.max(1, math.floor(value + 0.5))
end

local function createBallLightningPart(name)
	local part = BALL_LIGHTNING_TEMPLATE:Clone()
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Parent = workspace
	return part
end

local function getTeslaBaseDamage(towerState)
	return towerState.damageVal and towerState.damageVal.Value or 10
end

local function getTeslaTopOrbitInfo(tower)
	if tower:IsA("Model") then
		local cf, size = tower:GetBoundingBox()
		local center = cf.Position + Vector3.new(0, (size.Y * 0.52), 0)
		local orbitRadius = math.max(3, math.max(size.X, size.Z) * 0.45)
		return center, orbitRadius
	elseif tower:IsA("BasePart") then
		local center = tower.Position + Vector3.new(0, tower.Size.Y * 0.52, 0)
		local orbitRadius = math.max(3, math.max(tower.Size.X, tower.Size.Z) * 0.45)
		return center, orbitRadius
	end

	return nil, 3
end
local function setModelVisualState(instance, anchored, canCollide)
	if instance:IsA("BasePart") then
		instance.Anchored = anchored
		instance.CanCollide = canCollide
		instance.CanTouch = false
		instance.CanQuery = false
		return
	end

	for _, obj in ipairs(instance:GetDescendants()) do
		if obj:IsA("BasePart") then
			obj.Anchored = anchored
			obj.CanCollide = canCollide
			obj.CanTouch = false
			obj.CanQuery = false
		end
	end
end

local function getInstancePosition(instance)
	if instance:IsA("BasePart") then
		return instance.Position
	elseif instance:IsA("Model") then
		return instance:GetPivot().Position
	end
	return nil
end

local function setInstancePosition(instance, position)
	if instance:IsA("BasePart") then
		instance.CFrame = CFrame.new(position)
	elseif instance:IsA("Model") then
		instance:PivotTo(CFrame.new(position))
	end
end
local function getTowerCenterCFrame(tower)
	if tower:IsA("Model") then
		local cf = tower:GetBoundingBox()
		return cf
	elseif tower:IsA("BasePart") then
		return tower.CFrame
	end

	return nil
end

local function setVisualCFrame(instance, cf)
	if not instance or not cf then
		return
	end

	if instance:IsA("BasePart") then
		instance.CFrame = cf
	elseif instance:IsA("Model") then
		instance:PivotTo(cf)
	end
end

local function setEmitterSizeToRadius(emitter, radius)
	if not emitter or not emitter:IsA("ParticleEmitter") then
		return
	end

	emitter.Size = NumberSequence.new(radius)
	emitter.Enabled = true
end

local function updateMagnetAttachmentEmitters(container, radius)
	if not container then
		return
	end

	local attachment = container:FindFirstChild("Attachment", true)
	if not attachment then
		return
	end

	for _, obj in ipairs(attachment:GetDescendants()) do
		if obj:IsA("ParticleEmitter") then
			setEmitterSizeToRadius(obj, radius)
		end
	end
end

local function updateDistortionZoneRange(container, radius)
	if not container then
		return
	end

	local rangePart = container:FindFirstChild("Range", true)
	if not rangePart or not rangePart:IsA("BasePart") then
		return
	end

	rangePart.Size = Vector3.new(radius * 2, rangePart.Size.Y, radius * 2)

	for _, obj in ipairs(rangePart:GetDescendants()) do
		if obj:IsA("ParticleEmitter") then
			obj.Enabled = true
		end
	end
end

local function ensureMagnetFieldVisual(tower, towerState)
	if towerState.towerType ~= "Magnet" then
		local old = magnetFieldVisuals[tower]
		if old and old.Parent then
			old:Destroy()
		end
		magnetFieldVisuals[tower] = nil
		return nil
	end

	local wantsDistortionZone = towerState.distortionZoneEnabledVal and towerState.distortionZoneEnabledVal.Value > 0
	local wantedName = wantsDistortionZone and "DistortionZone" or "StaticField"

	local current = magnetFieldVisuals[tower]
	if current and (not current.Parent or current.Name ~= wantedName) then
		current:Destroy()
		current = nil
		magnetFieldVisuals[tower] = nil
	end

	if not current then
		local template = wantsDistortionZone and DISTORTION_ZONE_TEMPLATE or CORE_TEMPLATE
		current = template:Clone()
		current.Name = wantedName
		current.Parent = tower
		setModelVisualState(current, true, false)
		magnetFieldVisuals[tower] = current
	end

	return current
end

local function updateMagnetFieldVisuals()
	for tower in pairs(activeTowers) do
		if not tower.Parent then
			local old = magnetFieldVisuals[tower]
			if old and old.Parent then
				old:Destroy()
			end
			magnetFieldVisuals[tower] = nil
			continue
		end

		local towerState = towerStateCache[tower] or buildTowerState(tower)
		towerStateCache[tower] = towerState

		if towerState.towerType ~= "Magnet" then
			local old = magnetFieldVisuals[tower]
			if old and old.Parent then
				old:Destroy()
			end
			magnetFieldVisuals[tower] = nil
			continue
		end

		local hasStaticField = towerState.staticFieldSpeedMultiplierVal ~= nil
		local hasDistortionZone = towerState.distortionZoneEnabledVal and towerState.distortionZoneEnabledVal.Value > 0

		if not hasStaticField and not hasDistortionZone then
			local old = magnetFieldVisuals[tower]
			if old and old.Parent then
				old:Destroy()
			end
			magnetFieldVisuals[tower] = nil
			continue
		end

		local visual = ensureMagnetFieldVisual(tower, towerState)
		if visual then
			local centerCF = getTowerCenterCFrame(tower)
			local radius = towerState.radiusVal and towerState.radiusVal.Value or 20

			setVisualCFrame(visual, centerCF)
			updateMagnetAttachmentEmitters(visual, radius)

			if visual.Name == "DistortionZone" then
				updateDistortionZoneRange(visual, radius)
			end
		end
	end
end
local function setBombPosition(instance, position)
	if instance:IsA("BasePart") then
		instance.CFrame = CFrame.new(position) * BOMB_UPRIGHT_ROTATION
	elseif instance:IsA("Model") then
		instance:PivotTo(CFrame.new(position) * BOMB_UPRIGHT_ROTATION)
	end
end
local function getInstanceHalfHeight(instance)
	if instance:IsA("BasePart") then
		return instance.Size.Y * 0.5
	elseif instance:IsA("Model") then
		local _, size = instance:GetBoundingBox()
		return size.Y * 0.5
	end

	return 1
end

local function shouldIgnoreBombGroundHit(hitInstance, bombModel)
	if not hitInstance or not hitInstance.Parent then
		return true
	end

	if bombModel and hitInstance:IsDescendantOf(bombModel) then
		return true
	end

	if hitInstance.Transparency >= 1 then
		return true
	end

	if hitInstance.CanCollide == false then
		return true
	end

	if hitInstance.Name == "Waypoint" or hitInstance.Name:match("Spawn") then
		return true
	end

	return false
end

local function getBombGroundY(bombData)
	if not bombData or not bombData.model or not bombData.model.Parent then
		return nil
	end

	local origin = bombData.position + Vector3.new(0, 20, 0)
	local remainingDistance = 300
	local ignored = {bombData.model}

	while remainingDistance > 0 do
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = ignored

		local result = workspace:Raycast(origin, Vector3.new(0, -remainingDistance, 0), params)
		if not result then
			return nil
		end

		local hit = result.Instance
		if not shouldIgnoreBombGroundHit(hit, bombData.model) then
			return result.Position.Y
		end

		table.insert(ignored, hit)

		local travelled = (origin - result.Position).Magnitude
		remainingDistance -= travelled + 0.05
		origin = result.Position - Vector3.new(0, 0.05, 0)
	end

	return nil
end

local function playTeslaBombExplosion(position)
	local explosionTemplate = ReplicatedStorage:FindFirstChild("Explosion")
	if not explosionTemplate or not explosionTemplate:IsA("ParticleEmitter") then
		return
	end

	local anchor = Instance.new("Part")
	anchor.Name = "TeslaBombExplosionAnchor"
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.Transparency = 1
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanTouch = false
	anchor.CanQuery = false
	anchor.CFrame = CFrame.new(position)
	anchor.Parent = workspace

	local explosionSound = Instance.new("Sound")
	explosionSound.SoundId = MINEFIELD_EXPLOSION_SOUND_ID
	explosionSound.Volume = MINEFIELD_EXPLOSION_SOUND_VOLUME
	explosionSound.RollOffMode = Enum.RollOffMode.Inverse
	explosionSound.RollOffMinDistance = MINEFIELD_EXPLOSION_SOUND_MIN_DISTANCE
	explosionSound.RollOffMaxDistance = MINEFIELD_EXPLOSION_SOUND_MAX_DISTANCE
	explosionSound.Parent = anchor
	explosionSound:Play()

	local emitter = explosionTemplate:Clone()
	emitter.Enabled = false
	emitter.Parent = anchor
	emitter.Enabled = true

	task.delay(0.1, function()
		if emitter and emitter.Parent then
			emitter.Enabled = false
		end
	end)

	task.delay(1.2, function()
		if anchor and anchor.Parent then
			anchor:Destroy()
		end
	end)
end
local function getBombRoot(instance)
	if instance:IsA("BasePart") then
		return instance
	elseif instance:IsA("Model") then
		local root = instance.PrimaryPart or instance:FindFirstChildWhichIsA("BasePart", true)
		if root and not instance.PrimaryPart then
			instance.PrimaryPart = root
		end
		return root
	end

	return nil
end


local function getEnemyTopPosition(enemy)
	if enemy:IsA("Model") then
		local cf, size = enemy:GetBoundingBox()
		return cf.Position + Vector3.new(0, size.Y * 0.5, 0)
	elseif enemy:IsA("BasePart") then
		return enemy.Position + Vector3.new(0, enemy.Size.Y * 0.5, 0)
	end

	local hrp = enemy:FindFirstChild("HumanoidRootPart")
	return hrp and hrp.Position or nil
end

local function spawnLightningBoltAtEnemy(enemy)
	local head = enemy:FindFirstChild("Head")
	local hrp = enemy:FindFirstChild("HumanoidRootPart")

	local spawnPos
	if head and head:IsA("BasePart") then
		spawnPos = head.Position
	elseif hrp and hrp:IsA("BasePart") then
		spawnPos = hrp.Position
	else
		return
	end

	local bolt = LIGHTNING_BOLT_TEMPLATE:Clone()
	setModelVisualState(bolt, true, false)

	local boltCFrame = CFrame.new(spawnPos) * CFrame.Angles(0, 0, math.rad(-90))

	if bolt:IsA("BasePart") then
		bolt.CFrame = boltCFrame
	elseif bolt:IsA("Model") then
		bolt:PivotTo(boltCFrame)
	end

	bolt.Parent = workspace

	local soundAnchor = Instance.new("Part")
	soundAnchor.Name = "LightningStrikeSoundAnchor"
	soundAnchor.Size = Vector3.new(0.2, 0.2, 0.2)
	soundAnchor.Transparency = 1
	soundAnchor.Anchored = true
	soundAnchor.CanCollide = false
	soundAnchor.CanTouch = false
	soundAnchor.CanQuery = false
	soundAnchor.CFrame = CFrame.new(spawnPos)
	soundAnchor.Parent = workspace

	local strikeSound = Instance.new("Sound")
	strikeSound.SoundId = LIGHTNING_STRIKE_SOUND_ID
	strikeSound.Volume = LIGHTNING_STRIKE_SOUND_VOLUME
	strikeSound.RollOffMode = Enum.RollOffMode.Inverse
	strikeSound.RollOffMinDistance = 10
	strikeSound.RollOffMaxDistance = 90
	strikeSound.Parent = soundAnchor
	strikeSound:Play()

	local fadeTargets = {}

	local function registerFadeTarget(obj)
		if obj:IsA("BasePart") then
			fadeTargets[obj] = obj.Transparency
			obj.Transparency = 1
		elseif obj:IsA("Decal") or obj:IsA("Texture") then
			fadeTargets[obj] = obj.Transparency
			obj.Transparency = 1
		end
	end

	if bolt:IsA("BasePart") or bolt:IsA("Decal") or bolt:IsA("Texture") then
		registerFadeTarget(bolt)
	end

	for _, obj in ipairs(bolt:GetDescendants()) do
		registerFadeTarget(obj)
	end

	local fadeInTweens = {}
	for obj, originalTransparency in pairs(fadeTargets) do
		table.insert(fadeInTweens, TweenService:Create(
			obj,
			TweenInfo.new(0.05, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
			{Transparency = originalTransparency}
			))
	end

	for _, tween in ipairs(fadeInTweens) do
		tween:Play()
	end

	task.delay(0.05, function()
		if not bolt or not bolt.Parent then
			return
		end

		local fadeOutTweens = {}
		for obj in pairs(fadeTargets) do
			if obj and obj.Parent then
				table.insert(fadeOutTweens, TweenService:Create(
					obj,
					TweenInfo.new(0.12, Enum.EasingStyle.Sine, Enum.EasingDirection.In),
					{Transparency = 1}
					))
			end
		end

		for _, tween in ipairs(fadeOutTweens) do
			tween:Play()
		end

		task.delay(0.13, function()
			if bolt and bolt.Parent then
				bolt:Destroy()
			end
		end)
	end)

	task.delay(2, function()
		if soundAnchor and soundAnchor.Parent then
			soundAnchor:Destroy()
		end
	end)
end

local function getRandomStrongestEnemy()
	local bestHealth = -math.huge
	local ties = {}

	for enemy in pairs(activeEnemies) do
		if enemy.Parent then
			local healthVal = enemy:FindFirstChild("Health")
			if healthVal and healthVal.Value > 0 then
				if healthVal.Value > bestHealth then
					bestHealth = healthVal.Value
					ties = {enemy}
				elseif healthVal.Value == bestHealth then
					table.insert(ties, enemy)
				end
			end
		end
	end

	if #ties == 0 then
		return nil
	end

	return ties[math.random(1, #ties)]
end

local function createTeslaBombAt(position)
	local bomb = BOMB_TEMPLATE:Clone()
	setModelVisualState(bomb, true, false)
	setBombPosition(bomb, position)
	bomb.Parent = workspace

	return bomb, getInstanceHalfHeight(bomb)
end
local function explodeTeslaBomb(tower, towerState, bombData)
	if not bombData or bombData.exploded then
		return
	end

	bombData.exploded = true

	local bombPos = bombData.position
	if bombData.model and bombData.model.Parent then
		bombPos = getInstancePosition(bombData.model) or bombPos
	end

	playTeslaBombExplosion(bombPos)

	local radius = towerState.minefieldBombRadiusVal and towerState.minefieldBombRadiusVal.Value or 10
	local baseDamage = getTeslaBaseDamage(towerState)
	local bombDamage = roundDamage(baseDamage * (towerState.minefieldBombDamagePercentVal and towerState.minefieldBombDamagePercentVal.Value or 1))

	local bounceEnabled = towerState.minefieldBounceEnabledVal and towerState.minefieldBounceEnabledVal.Value > 0
	local bounceChance = towerState.minefieldBounceChanceVal and towerState.minefieldBounceChanceVal.Value or 0.3
	local bounceDamage = roundDamage(baseDamage * (towerState.minefieldBounceDamagePercentVal and towerState.minefieldBounceDamagePercentVal.Value or 0.25))

	for _, enemy in ipairs(enemySpatial:getCandidatesNear(bombPos, radius)) do
		if enemy.Parent then
			local hrp = enemy:FindFirstChild("HumanoidRootPart")
			local healthVal = enemy:FindFirstChild("Health")

			if hrp and healthVal and healthVal.Value > 0 then
			if enemySpatial.getFlatDistanceSquared(hrp.Position, bombPos) <= radius * radius then
					applyDirectDamage(enemy, bombDamage)

					if bounceEnabled and math.random() < bounceChance then
						local strongest = getRandomStrongestEnemy()
						if strongest then
							spawnLightningBoltAtEnemy(strongest)
							applyDirectDamage(strongest, bounceDamage)
						end
					end
				end
			end
		end
	end

	if bombData.model and bombData.model.Parent then
		bombData.model:Destroy()
	end
end

local function spawnTeslaBombs(tower, towerState, now)
	local towerPosition = getTowerPosition(tower)
	if not towerPosition then
		return
	end

	local radius = towerState.radiusVal and towerState.radiusVal.Value or 20
	local bombCount = towerState.minefieldBombCountVal and towerState.minefieldBombCountVal.Value or 2
	local fuse = towerState.minefieldFuseTimeVal and towerState.minefieldFuseTimeVal.Value or 2
	local instantExplode = towerState.minefieldInstantExplodeVal and towerState.minefieldInstantExplodeVal.Value > 0

	local list = teslaBombs[tower]
	if not list then
		list = {}
		teslaBombs[tower] = list
	end

	for _ = 1, bombCount do
		local angle = math.random() * math.pi * 2
		local dist = math.sqrt(math.random()) * radius

		local spawnPos = Vector3.new(
			towerPosition.X + math.cos(angle) * dist,
			towerPosition.Y + 12,
			towerPosition.Z + math.sin(angle) * dist
		)

		local bombModel, halfHeight = createTeslaBombAt(spawnPos)

		local bombData = {
			model = bombModel,
			position = spawnPos,
			explodeAt = instantExplode and now or (now + GameSpeed:ScaleDuration(fuse)),
			exploded = false,
			velocityY = 0,
			halfHeight = halfHeight or 1,
			bounceCount = 0,
			settled = false,
		}

		if instantExplode then
			local groundY = getBombGroundY(bombData)
			if groundY then
				local landedPos = Vector3.new(
					spawnPos.X,
					groundY + bombData.halfHeight,
					spawnPos.Z
				)

				bombData.position = landedPos
				bombData.velocityY = 0
				bombData.bounceCount = 1
				bombData.settled = true

				setBombPosition(bombData.model, landedPos)
			else
				setBombPosition(bombData.model, spawnPos)
			end
		end

		table.insert(list, bombData)

		if instantExplode then
			explodeTeslaBomb(tower, towerState, bombData)
		end
	end
end

local function updateTeslaBombs(tower, towerState, now, dt)
	if not (towerState.minefieldEnabledVal and towerState.minefieldEnabledVal.Value > 0) then
		local old = teslaBombs[tower]
		if old then
			for _, bombData in ipairs(old) do
				if bombData.model and bombData.model.Parent then
					bombData.model:Destroy()
				end
			end
		end
		teslaBombs[tower] = nil
		teslaBombLastSpawn[tower] = nil
		return
	end

	local spawnInterval = towerState.minefieldSpawnIntervalVal and towerState.minefieldSpawnIntervalVal.Value or 3
	local lastSpawn = teslaBombLastSpawn[tower] or 0

	if now - lastSpawn >= GameSpeed:ScaleDuration(spawnInterval) then
		spawnTeslaBombs(tower, towerState, now)
		teslaBombLastSpawn[tower] = now
	end

	local list = teslaBombs[tower]
	if not list then
		return
	end

	local gravity = -70
	local bounceDamping = 0.35

	for i = #list, 1, -1 do
		local bombData = list[i]

		if bombData.exploded then
			table.remove(list, i)
		elseif not bombData.model or not bombData.model.Parent then
			table.remove(list, i)
		else
			if not bombData.settled then
				bombData.velocityY += gravity * dt

				local nextPosition = bombData.position + Vector3.new(0, bombData.velocityY * dt, 0)
				local groundY = getBombGroundY(bombData)

				if groundY then
					local floorY = groundY + bombData.halfHeight

					if nextPosition.Y <= floorY then
						nextPosition = Vector3.new(nextPosition.X, floorY, nextPosition.Z)

						if bombData.bounceCount == 0 and math.abs(bombData.velocityY) > 4 then
							bombData.velocityY = math.abs(bombData.velocityY) * bounceDamping
							bombData.bounceCount = 1
						else
							bombData.velocityY = 0
							bombData.settled = true
						end
					end
				end

				bombData.position = nextPosition
				setBombPosition(bombData.model, bombData.position)
			end

			if now >= bombData.explodeAt then
				explodeTeslaBomb(tower, towerState, bombData)
				table.remove(list, i)
			end
		end
	end

	if #list == 0 then
		teslaBombs[tower] = nil
	end
end
local function pulseBallLightning(position, radius, damage)
	for _, enemy in ipairs(enemySpatial:getCandidatesNear(position, radius)) do
		if enemy.Parent then
			local hrp = enemy:FindFirstChild("HumanoidRootPart")
			local healthVal = enemy:FindFirstChild("Health")

			if hrp and healthVal and healthVal.Value > 0 then
			if enemySpatial.getFlatDistanceSquared(hrp.Position, position) <= radius * radius then
					applyDirectDamage(enemy, damage)
				end
			end
		end
	end
end

local function getClosestMarkedEnemy(tower, towerPosition)
	local marks = teslaMarkedEnemies[tower]
	if not marks then
		return nil
	end

	local bestEnemy = nil
	local bestDistance = math.huge

	for enemy in pairs(marks) do
		if enemy.Parent then
			local hrp = enemy:FindFirstChild("HumanoidRootPart")
			local healthVal = enemy:FindFirstChild("Health")

			if hrp and healthVal and healthVal.Value > 0 then
				local distance = enemySpatial:getTargetDistance(enemy, towerPosition)
				if distance < bestDistance then
					bestDistance = distance
					bestEnemy = enemy
				end
			else
				marks[enemy] = nil
			end
		else
			marks[enemy] = nil
		end
	end

	return bestEnemy
end

local function getPathAxisData(pathPart)
	if pathPart.Size.X >= pathPart.Size.Z then
		return "X", pathPart.Size.X * 0.5
	end

	return "Z", pathPart.Size.Z * 0.5
end

local function ensureTeslaOrbitBall(tower)
	local data = teslaOrbitBalls[tower]
	if data and data.part and data.part.Parent then
		return data
	end

	data = {
		part = createBallLightningPart("TeslaOrbitBall"),
		angle = 0,
		lastPulse = 0,
		lastSeekerSpawn = 0,
	}
	teslaOrbitBalls[tower] = data
	return data
end

local function ensureTeslaStormBalls(tower)
	local existing = teslaStormBalls[tower]
	if existing then
		local valid = true
		for _, ballData in ipairs(existing) do
			if not ballData.part or not ballData.part.Parent or not ballData.path or not ballData.path.Parent then
				valid = false
				break
			end
		end
		if valid then
			return existing
		end

		for _, ballData in ipairs(existing) do
			if ballData.part and ballData.part.Parent then
				ballData.part:Destroy()
			end
		end
	end

	local list = {}
	for _, pathPart in ipairs(BALL_LIGHTNING_PATHS_FOLDER:GetChildren()) do
		if pathPart:IsA("BasePart") then
			local axis, halfLength = getPathAxisData(pathPart)

			table.insert(list, {
				part = createBallLightningPart("TeslaStormBall"),
				path = pathPart,
				axis = axis,
				offset = -halfLength,
				direction = 1,
				lastPulse = 0,
			})
		end
	end

	teslaStormBalls[tower] = list
	return list
end

local function spawnTeslaSeekerBall(tower, towerState, startPosition)
	local towerPosition = getTowerPosition(tower)
	if not towerPosition then
		return false
	end

	local target = getClosestMarkedEnemy(tower, towerPosition)
	if not target then
		return false
	end

	local list = teslaSeekerBalls[tower]
	if not list then
		list = {}
		teslaSeekerBalls[tower] = list
	end

	local part = createBallLightningPart("TeslaMarkedBall")
	part.CFrame = CFrame.new(startPosition)

	table.insert(list, {
		part = part,
		target = target,
		lastPulse = 0,
		life = 0,
	})

	return true
end

local function updateTeslaOrbitBall(tower, towerState, now, dt)
	if not (towerState.ballLightningOrbitEnabledVal and towerState.ballLightningOrbitEnabledVal.Value > 0) then
		local old = teslaOrbitBalls[tower]
		if old and old.part and old.part.Parent then
			old.part:Destroy()
		end
		teslaOrbitBalls[tower] = nil
		return
	end

	local data = ensureTeslaOrbitBall(tower)
	local center, orbitRadius = getTeslaTopOrbitInfo(tower)
	if not center then
		return
	end

	local orbitSpeed = towerState.ballLightningOrbitSpeedVal and towerState.ballLightningOrbitSpeedVal.Value or 2.5
	data.angle += dt * orbitSpeed
	data.waveTime = (data.waveTime or 0) + dt

	local rawPosition = center + Vector3.new(
		math.cos(data.angle) * orbitRadius,
		0.8 + math.sin(data.waveTime * 5) * 1.2,
		math.sin(data.angle) * orbitRadius
	)

	data.currentPosition = data.currentPosition and data.currentPosition:Lerp(rawPosition, math.clamp(dt * 9, 0, 1)) or rawPosition
	data.part.CFrame = CFrame.new(data.currentPosition)

	local pulseCooldown = towerState.ballLightningPulseCooldownVal and towerState.ballLightningPulseCooldownVal.Value or 1
	local damageRadius = towerState.ballLightningRadiusVal and towerState.ballLightningRadiusVal.Value or 10
	local pulseDamage = roundDamage(getTeslaBaseDamage(towerState) * (towerState.ballLightningOrbitDamagePercentVal and towerState.ballLightningOrbitDamagePercentVal.Value or 0.15))

	if now - data.lastPulse >= GameSpeed:ScaleDuration(pulseCooldown) then
		pulseBallLightning(data.currentPosition, damageRadius, pulseDamage)
		data.lastPulse = now
	end

	if towerState.lightningMarkEnabledVal and towerState.lightningMarkEnabledVal.Value > 0 then
		local seekerInterval = towerState.lightningMarkSpawnIntervalVal and towerState.lightningMarkSpawnIntervalVal.Value or 2
		if now - data.lastSeekerSpawn >= GameSpeed:ScaleDuration(seekerInterval) then
			if spawnTeslaSeekerBall(tower, towerState, data.currentPosition) then
				data.lastSeekerSpawn = now
			end
		end
	end
end

local function updateTeslaSeekerBalls(tower, towerState, now, dt)
	local list = teslaSeekerBalls[tower]
	if not list then
		return
	end

	local pulseCooldown = towerState.ballLightningPulseCooldownVal and towerState.ballLightningPulseCooldownVal.Value or 1
	local damageRadius = towerState.ballLightningRadiusVal and towerState.ballLightningRadiusVal.Value or 10
	local pulseDamage = roundDamage(getTeslaBaseDamage(towerState) * (towerState.ballLightningOrbitDamagePercentVal and towerState.ballLightningOrbitDamagePercentVal.Value or 0.15))
	local maxSeekerSpeed = towerState.lightningMarkSeekerSpeedVal and towerState.lightningMarkSeekerSpeedVal.Value or 55
	local impactDamage = roundDamage(getTeslaBaseDamage(towerState) * (towerState.lightningMarkImpactMultiplierVal and towerState.lightningMarkImpactMultiplierVal.Value or 1))

	for i = #list, 1, -1 do
		local seeker = list[i]

		if not seeker.part or not seeker.part.Parent then
			table.remove(list, i)
			continue
		end

		local target = seeker.target
		if not target or not target.Parent then
			seeker.part:Destroy()
			table.remove(list, i)
			continue
		end

		local hrp = target:FindFirstChild("HumanoidRootPart")
		local healthVal = target:FindFirstChild("Health")
		local speedVal = target:FindFirstChild("Speed")

		if not hrp or not healthVal or healthVal.Value <= 0 then
			seeker.part:Destroy()
			table.remove(list, i)
			continue
		end

		seeker.life += dt
		seeker.waveTime = (seeker.waveTime or 0) + dt

		local currentPos = seeker.part.Position
		local targetVelocity = Vector3.zero

		if speedVal and speedVal.Value > 0 then
			targetVelocity = hrp.CFrame.LookVector * speedVal.Value
		end

		local predictedTargetPos = hrp.Position + (targetVelocity * 0.35)
		local offset = predictedTargetPos - currentPos
		local flatOffset = Vector3.new(offset.X, 0, offset.Z)
		local distance = offset.Magnitude
		local flatDistance = flatOffset.Magnitude

		local accelDuration = 2
		local startSpeed = 6
		local accelAlpha = math.clamp(seeker.life / accelDuration, 0, 1)
		local curvedAlpha = accelAlpha * accelAlpha
		local currentSpeed = startSpeed + ((maxSeekerSpeed - startSpeed) * curvedAlpha)
		local step = currentSpeed * dt

		local catchRadius = math.max(3, step * 1.4)

		if flatDistance <= catchRadius or distance <= catchRadius then
			pulseBallLightning(hrp.Position, damageRadius, pulseDamage)
			applyDirectDamage(target, impactDamage)

			local marks = teslaMarkedEnemies[tower]
			if marks then
				marks[target] = nil
			end

			seeker.part:Destroy()
			table.remove(list, i)
			continue
		end

		local moveDir = distance > 0.001 and offset.Unit or Vector3.zero
		local nextPos = currentPos + (moveDir * step)

		local side = Vector3.new(-moveDir.Z, 0, moveDir.X)
		if side.Magnitude > 0.001 then
			side = side.Unit
		end

		local waveOffset = side * math.sin(seeker.waveTime * 8) * 0.8
		local bobOffset = Vector3.new(0, math.sin(seeker.waveTime * 10) * 0.35, 0)
		local displayPos = nextPos + waveOffset + bobOffset

		seeker.part.CFrame = CFrame.new(displayPos)

		if now - seeker.lastPulse >= GameSpeed:ScaleDuration(pulseCooldown) then
			pulseBallLightning(displayPos, damageRadius, pulseDamage)
			seeker.lastPulse = now
		end

		if seeker.life >= 10 then
			seeker.part:Destroy()
			table.remove(list, i)
		end
	end

	if #list == 0 then
		teslaSeekerBalls[tower] = nil
	end
end

local function updateTeslaStormBalls(tower, towerState, now, dt)
	if not (towerState.lightningStormEnabledVal and towerState.lightningStormEnabledVal.Value > 0) then
		local old = teslaStormBalls[tower]
		if old then
			for _, ballData in ipairs(old) do
				if ballData.part and ballData.part.Parent then
					ballData.part:Destroy()
				end
			end
		end
		teslaStormBalls[tower] = nil
		return
	end

	local list = ensureTeslaStormBalls(tower)
	local pulseCooldown = towerState.ballLightningPulseCooldownVal and towerState.ballLightningPulseCooldownVal.Value or 1
	local damageRadius = towerState.ballLightningRadiusVal and towerState.ballLightningRadiusVal.Value or 10
	local pulseDamage = roundDamage(getTeslaBaseDamage(towerState) * (towerState.lightningStormDamagePercentVal and towerState.lightningStormDamagePercentVal.Value or 0.25))
	local speed = towerState.lightningStormPathSpeedVal and towerState.lightningStormPathSpeedVal.Value or 35

	for _, ballData in ipairs(list) do
		local pathPart = ballData.path
		if pathPart and pathPart.Parent and ballData.part and ballData.part.Parent then
			local axis, halfLength = getPathAxisData(pathPart)
			ballData.axis = axis
			ballData.waveTime = (ballData.waveTime or 0) + dt

			if ballData.phase == nil then
				ballData.phase = -math.pi / 2
			end

			local phaseSpeed = speed / math.max(halfLength, 0.001)
			ballData.phase += dt * phaseSpeed

			local smoothOffset = math.sin(ballData.phase) * halfLength
			local localPos

			if axis == "X" then
				localPos = Vector3.new(smoothOffset, 0, 0)
			else
				localPos = Vector3.new(0, 0, smoothOffset)
			end

			local worldPos = pathPart.CFrame:PointToWorldSpace(localPos)
			local bobbedWorldPos = worldPos + Vector3.new(0, math.sin(ballData.waveTime * 6) * 0.6, 0)

			ballData.currentPosition = ballData.currentPosition and ballData.currentPosition:Lerp(bobbedWorldPos, math.clamp(dt * 10, 0, 1)) or bobbedWorldPos
			ballData.part.CFrame = CFrame.new(ballData.currentPosition)

			if now - ballData.lastPulse >= GameSpeed:ScaleDuration(pulseCooldown) then
				pulseBallLightning(ballData.currentPosition, damageRadius, pulseDamage)
				ballData.lastPulse = now
			end
		end
	end
end
local function findTargetEnemy(tower, towerPosition, radius, requireUnpoisoned)
	local closestEnemy
	local closestDistance = math.huge

	for _, enemy in ipairs(enemySpatial:getCandidatesNear(towerPosition, radius)) do
		if not enemy.Parent then
			unregisterEnemy(enemy)
			continue
		end

		local hrp = enemy:FindFirstChild("HumanoidRootPart")
		local healthVal = enemy:FindFirstChild("Health")
		if not hrp or not healthVal or healthVal.Value <= 0 then
			continue
		end

		if requireUnpoisoned and isEnemyPoisoned(tower, enemy) then
			continue
		end

		if enemySpatial:isWithinTargetRadius(enemy, towerPosition, radius) then
			local distance = enemySpatial:getTargetDistance(enemy, towerPosition)
			if distance >= closestDistance then
				continue
			end
			closestDistance = distance
			closestEnemy = enemy
		end
	end

	return closestEnemy
end
local function getEnemyMaxHealth(enemy)
	local humanoid = enemy:FindFirstChildOfClass("Humanoid")
	local healthVal = enemy:FindFirstChild("Health")

	local maxHealth = enemy:GetAttribute("BaseMaxHealth")
	if typeof(maxHealth) ~= "number" or maxHealth <= 0 then
		if humanoid then
			maxHealth = humanoid.MaxHealth
		elseif healthVal then
			maxHealth = healthVal.Value
		else
			maxHealth = 0
		end

		if maxHealth > 0 then
			enemy:SetAttribute("BaseMaxHealth", maxHealth)
		end
	end

	return healthVal, humanoid, maxHealth
end

recomputeEnemySpeed = function(enemy, desiredStaticMultiplier, hasSupportAura, now)
	if not enemy or not enemy.Parent then
		return
	end

	local speedVal, baseSpeed = getEnemyBaseSpeed(enemy)
	if not speedVal or not baseSpeed then
		return
	end

	local flatBonus = hasSupportAura and EnemyBehaviors.getSupportSpeedBonus() or 0
	local unslowedSpeed = baseSpeed + flatBonus

	local finalMultiplier = 1
	if desiredStaticMultiplier then
		finalMultiplier *= desiredStaticMultiplier
	end
	if distortionAppliedEnemies[enemy] then
		finalMultiplier *= DISTORTION_SPEED_MULTIPLIER
	end

	local targetSpeed = (baseSpeed + flatBonus) * finalMultiplier

	local slowState = enemySlowStates[enemy]
	if slowState then
		if now >= slowState.expiresAt then
			enemySlowStates[enemy] = nil
			slowedEnemies[enemy] = nil
		else
			local minimumSpeed = isTankEnemy(enemy) and 0 or math.min(targetSpeed, MIN_DEBUFFED_SPEED)

			if now < slowState.immobilizeUntil then
				targetSpeed = minimumSpeed
			else
				targetSpeed = math.max(minimumSpeed, targetSpeed / slowState.divisor)
			end
		end
	end

	speedVal.Value = math.max(0, targetSpeed)
	enemy:SetAttribute("EnemySlowedEffect", targetSpeed < unslowedSpeed - 0.01)
end
local function updateStaticFieldEffects()
	local now = tick()
	local desiredStaticMultipliers = {}

	for tower in pairs(activeTowers) do
		if tower.Parent then
			local towerState = towerStateCache[tower] or buildTowerState(tower)
			towerStateCache[tower] = towerState

			if towerState.towerType == "Magnet"
				and towerState.staticFieldSpeedMultiplierVal
				and towerState.staticFieldSpeedMultiplierVal.Value < 1 then

				local towerPosition = getTowerPosition(tower)
				local radius = towerState.radiusVal and towerState.radiusVal.Value or 20
				local multiplier = towerState.staticFieldSpeedMultiplierVal.Value

				if towerPosition then
					for _, entry in ipairs(getEnemiesInRadius(towerPosition, radius, true)) do
						local enemy = entry.enemy
						desiredStaticMultipliers[enemy] = math.min(desiredStaticMultipliers[enemy] or 1, multiplier)
					end
				end
			end
		end
	end

	EnemyBehaviors.refreshSupportAuras(activeEnemies, getEnemiesInRadius)

	for enemy in pairs(activeEnemies) do
		if enemy.Parent then
			local hasStatic = desiredStaticMultipliers[enemy] ~= nil
			local hasSupport = EnemyBehaviors.hasSupportAura(enemy)

			if hasStatic then
				staticFieldAffectedEnemies[enemy] = {
					originalSpeed = enemy:GetAttribute("BaseSpeed"),
				}
			else
				staticFieldAffectedEnemies[enemy] = nil
			end

			recomputeEnemySpeed(enemy, desiredStaticMultipliers[enemy], hasSupport, now)
		else
			staticFieldAffectedEnemies[enemy] = nil
			enemySlowStates[enemy] = nil
			slowedEnemies[enemy] = nil
			enemy:SetAttribute("EnemySlowedEffect", false)
		end
	end
end
local function updateSupportHealing(now)
	EnemyBehaviors.updateSupportHealing(now, activeEnemies, getEnemiesInRadius, getEnemyMaxHealth)
end
local function applyDistortionZone(enemy)
	if distortionAppliedEnemies[enemy] then
		return
	end

	distortionAppliedEnemies[enemy] = true
end

local function applyElectromagneticStorm(tower, towerState)
	local towerPosition = getTowerPosition(tower)
	if not towerPosition then
		return
	end

	local radius = towerState.radiusVal and towerState.radiusVal.Value or 20
	local knockback = towerState.electromagneticStormKnockbackVal and towerState.electromagneticStormKnockbackVal.Value or 1

	for _, entry in ipairs(getEnemiesInRadius(towerPosition, radius, true)) do
		applyKnockback(entry.enemy, knockback, towerPosition)
	end
end

function getOilLaunchPosition(tower)
	local launchPart = tower:FindFirstChild("Muzzle", true)
		or tower:FindFirstChild("Nozzle", true)
		or tower:FindFirstChild("Barrel", true)
		or tower:FindFirstChild("RootPart", true)
		or tower:FindFirstChildWhichIsA("BasePart", true)

	if launchPart and launchPart:IsA("BasePart") then
		return launchPart.Position
	end

	return getTowerPosition(tower)
end

function getOilGroundCFrame(position, useCylinderOrientation)
	local filter = { placedTowersFolder }
	for enemy in pairs(activeEnemies) do
		if enemy.Parent then
			table.insert(filter, enemy)
		end
	end

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = filter
	rayParams.IgnoreWater = true

	local result = workspace:Raycast(position + Vector3.new(0, 30, 0), Vector3.new(0, -100, 0), rayParams)
	local groundPosition = result and result.Position or position
	local normal = result and result.Normal or Vector3.yAxis
	local forward = Vector3.zAxis

	if math.abs(normal:Dot(forward)) > 0.95 then
		forward = Vector3.xAxis
	end

	local right = forward:Cross(normal)
	if right.Magnitude < 0.001 then
		right = Vector3.xAxis
	else
		right = right.Unit
	end

	local flatForward = normal:Cross(right)
	if flatForward.Magnitude < 0.001 then
		flatForward = Vector3.zAxis
	else
		flatForward = flatForward.Unit
	end

	local cframe = CFrame.fromMatrix(groundPosition + normal * 0.035, right, normal, flatForward)
	if useCylinderOrientation then
		return cframe
	end

	return cframe
end

function getOilPuddleVisuals(puddle)
	local visuals = {}
	if puddle:IsA("BasePart") then
		table.insert(visuals, puddle)
	end

	for _, obj in ipairs(puddle:GetDescendants()) do
		if obj:IsA("BasePart") or obj:IsA("Decal") or obj:IsA("Texture") then
			table.insert(visuals, obj)
		end
	end

	return visuals
end

function tweenOilPuddleTransparency(puddle, targetAlpha, duration, onComplete)
	local visuals = getOilPuddleVisuals(puddle)
	local remaining = 0

	for _, visual in ipairs(visuals) do
		if visual.Parent then
			remaining += 1
			local tween = TweenService:Create(visual, TweenInfo.new(GameSpeed:ScaleDuration(duration), Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Transparency = targetAlpha,
			})
			tween:Play()
			tween.Completed:Once(function()
				remaining -= 1
				if remaining <= 0 and onComplete then
					onComplete()
				end
			end)
		end
	end

	if remaining == 0 and onComplete then
		onComplete()
	end
end

function setOilPuddleFunctional(puddleData, functional)
	puddleData.functional = functional
	if not puddleData.instance or not puddleData.instance.Parent then
		return
	end

	for _, obj in ipairs(puddleData.instance:GetDescendants()) do
		if obj:IsA("BasePart") then
			obj.CanTouch = false
			obj.CanQuery = false
			obj.CanCollide = false
		end
	end

	if puddleData.instance:IsA("BasePart") then
		puddleData.instance.CanTouch = false
		puddleData.instance.CanQuery = false
		puddleData.instance.CanCollide = false
	end
end

function disablePuddleParticles(puddle)
	for _, obj in ipairs(puddle:GetDescendants()) do
		if obj:IsA("ParticleEmitter") then
			obj.Enabled = false
		end
	end
end

function enablePuddleParticles(puddle)
	for _, obj in ipairs(puddle:GetDescendants()) do
		if obj:IsA("ParticleEmitter") then
			obj.Enabled = true
		end
	end
end

function applyOilFireBurst(puddleData, triggerEnemy)
	if not puddleData then
		return
	end

	local radius = puddleData.fireBurstRadius or 0
	local damage = puddleData.fireBurstDamage or 0
	if radius <= 0 or damage <= 0 then
		return
	end

	local center = triggerEnemy and triggerEnemy:FindFirstChild("HumanoidRootPart")
	local burstPosition = (center and center.Position) or puddleData.position
	for _, entry in ipairs(getEnemiesInRadius(burstPosition, radius, true)) do
		applyDirectDamage(entry.enemy, damage)
		if puddleData.fireLingeringNormalDuration and puddleData.fireLingeringNormalDuration > 0 then
			applyNormalFire(entry.enemy, puddleData.fireLingeringNormalDuration)
		end
	end

	local sourceTower = puddleData.sourceTower
	if sourceTower and sourceTower.Parent and (puddleData.refineryBoostMultiplier or 1) < 1 then
		oilRefineryBoostUntil[sourceTower] = tick() + (puddleData.refineryBoostDuration or 0)
	end
end

function coatEnemyInOil(enemy, puddleData)
	if not enemy or not enemy.Parent or not puddleData or not puddleData.coatingEnabled then
		return
	end

	local now = tick()
	local expiresAt = now + (puddleData.coatDuration or 4)
	local existingState = oilCoatedEnemies[enemy]
	if existingState and existingState.expiresAt and existingState.expiresAt >= expiresAt then
		return
	end

	oilCoatedEnemies[enemy] = {
		expiresAt = expiresAt,
		sourceTower = puddleData.sourceTower,
		fireDamageMultiplier = puddleData.fireDamageMultiplier or 1,
		towerComboEnabled = puddleData.towerComboEnabled == true,
		towerDamageMultiplier = puddleData.towerDamageMultiplier or 1,
		chainSpillEnabled = puddleData.chainSpillEnabled == true,
	}

	local coatSpeedPercent = math.clamp(puddleData.coatSpeedPercent or 0.85, 0.05, 1)
	local initialSpeedPercent = math.clamp(puddleData.initialSpeedPercent or coatSpeedPercent, 0.05, 1)
	local initialDuration = math.max(0, puddleData.initialSlowDuration or 0)
	local coatDuration = math.max(0, puddleData.coatDuration or 0)
	if initialDuration > 0 then
		applyOilPercentSlow(enemy, initialDuration, initialSpeedPercent)
	end
	if coatDuration > 0 then
		applyOilPercentSlow(enemy, coatDuration, coatSpeedPercent)
	end

	for _, obj in ipairs(enemy:GetDescendants()) do
		if obj:IsA("BasePart") then
			obj.Color = OIL_COAT_COLOR
			pcall(function()
				obj.TextureID = ""
			end)
			pcall(function()
				obj.TextureId = ""
			end)
		elseif obj:IsA("SpecialMesh") then
			pcall(function()
				obj.TextureId = ""
			end)
		elseif obj:IsA("Decal") or obj:IsA("Texture") or obj:IsA("SurfaceAppearance") then
			obj:Destroy()
		end
	end

	task.delay(GameSpeed:ScaleDuration(puddleData.coatDuration or 4), function()
		local state = oilCoatedEnemies[enemy]
		if state and tick() >= (state.expiresAt or 0) then
			oilCoatedEnemies[enemy] = nil
		end
	end)
end

function fadeOutOilPuddle(puddleData)
	if puddleData.fading then
		return
	end

	puddleData.fading = true
	setOilPuddleFunctional(puddleData, false)

	local puddle = puddleData.instance
	if not puddle or not puddle.Parent then
		return
	end

	if puddleData.isFire then
		disablePuddleParticles(puddle)
	end

	tweenOilPuddleTransparency(puddle, 1, OIL_PUDDLE_FADE_TIME)

	local destroyDelay = puddleData.isFire and OIL_PUDDLE_DELETE_DELAY_AFTER_FIRE_OUT or (OIL_PUDDLE_FADE_TIME + 0.1)
	task.delay(GameSpeed:ScaleDuration(destroyDelay), function()
		if puddle and puddle.Parent then
			puddle:Destroy()
		end
	end)
end

function replaceOilPuddleWithFire(puddleData, triggerEnemy)
	if puddleData.isFire or puddleData.fading then
		return
	end

	local fireTemplate = ReplicatedStorage:FindFirstChild("FirePuddle")
	if not fireTemplate then
		return
	end

	local oldPuddle = puddleData.instance
	if not oldPuddle or not oldPuddle.Parent then
		return
	end

	local firePuddle = fireTemplate:Clone()
	firePuddle.Name = "FirePuddleVisual"
	firePuddle.Parent = workspace

	if firePuddle:IsA("Model") then
		for _, obj in ipairs(firePuddle:GetDescendants()) do
			if obj:IsA("BasePart") then
				obj.Anchored = true
				obj.CanCollide = false
				obj.CanTouch = false
				obj.CanQuery = false
			end
		end

		firePuddle:PivotTo(puddleData.cframe)
	elseif firePuddle:IsA("BasePart") then
		firePuddle.Anchored = true
		firePuddle.CanCollide = false
		firePuddle.CanTouch = false
		firePuddle.CanQuery = false
		firePuddle.CFrame = puddleData.cframe
	end

	enablePuddleParticles(firePuddle)
	oldPuddle:Destroy()

	puddleData.instance = firePuddle
	puddleData.isFire = true
	puddleData.functional = true
	puddleData.expiresAt = tick() + GameSpeed:ScaleDuration(math.max(0.1, puddleData.fireDeathZoneDuration or (OIL_PUDDLE_ACTIVE_TIME * 0.6)))
	applyOilFireBurst(puddleData, triggerEnemy)
end

function spawnOilPuddle(position, tower, towerState)
	local template = ReplicatedStorage:FindFirstChild("Puddle")
	local puddle = template and template:Clone() or nil
	local isFallback = false

	if not puddle then
		isFallback = true
		puddle = Instance.new("Part")
		puddle.Name = "OilPuddleVisual"
		puddle.Shape = Enum.PartType.Cylinder
		puddle.Material = Enum.Material.SmoothPlastic
		puddle.Color = Color3.fromRGB(12, 10, 8)
		puddle.Size = Vector3.new(0.1, 0.08, 0.1)
	end

	puddle.Name = "OilPuddleVisual"
	puddle.Parent = workspace
	local groundCFrame = getOilGroundCFrame(position, isFallback)
	local fireReactionEnabled = true
	local coatingEnabled = true
	local puddleData = {
		instance = puddle,
		position = groundCFrame.Position,
		cframe = groundCFrame,
		radius = OIL_SPLASH_RADIUS,
		sourceTower = tower,
		functional = true,
		isFire = false,
		fading = false,
		insideEnemies = setmetatable({}, { __mode = "k" }),
		coatingEnabled = coatingEnabled,
		coatDuration = towerState and towerState.oilCoatDurationVal and towerState.oilCoatDurationVal.Value or 5,
		coatSpeedPercent = towerState and towerState.oilCoatSpeedPercentVal and towerState.oilCoatSpeedPercentVal.Value or 1,
		initialSpeedPercent = towerState and towerState.oilInitialSpeedPercentVal and towerState.oilInitialSpeedPercentVal.Value or 1,
		initialSlowDuration = towerState and towerState.oilInitialSlowDurationVal and towerState.oilInitialSlowDurationVal.Value or 0,
		fireDamageMultiplier = towerState and towerState.oilFireDamageMultiplierVal and towerState.oilFireDamageMultiplierVal.Value or 1,
		fireReactionEnabled = fireReactionEnabled,
		fireDamage = towerState and towerState.oilFirePuddleDamageVal and towerState.oilFirePuddleDamageVal.Value or FIRE_PUDDLE_DAMAGE_PER_SECOND,
		fireBurnDuration = towerState and towerState.oilFirePuddleBurnDurationVal and towerState.oilFirePuddleBurnDurationVal.Value or FIRE_PUDDLE_BURN_DURATION,
		fireBurstRadius = towerState and towerState.oilFireBurstRadiusVal and towerState.oilFireBurstRadiusVal.Value or 0,
		fireBurstDamage = towerState and towerState.oilFireBurstDamageVal and towerState.oilFireBurstDamageVal.Value or 0,
		fireLingeringNormalDuration = towerState and towerState.oilFireLingeringNormalDurationVal and towerState.oilFireLingeringNormalDurationVal.Value or 0,
		fireDeathZoneDuration = towerState and towerState.oilFireDeathZoneDurationVal and towerState.oilFireDeathZoneDurationVal.Value or 0,
		chainSpillEnabled = towerState and towerState.oilChainSpillEnabledVal and towerState.oilChainSpillEnabledVal.Value > 0,
		towerComboEnabled = towerState and towerState.oilTowerComboEnabledVal and towerState.oilTowerComboEnabledVal.Value > 0,
		towerDamageMultiplier = towerState and towerState.oilTowerDamageMultiplierVal and towerState.oilTowerDamageMultiplierVal.Value or 1,
		refineryBoostMultiplier = towerState and towerState.oilRefineryBoostMultiplierVal and towerState.oilRefineryBoostMultiplierVal.Value or 1,
		refineryBoostDuration = towerState and towerState.oilRefineryBoostDurationVal and towerState.oilRefineryBoostDurationVal.Value or 0,
		expiresAt = tick() + GameSpeed:ScaleDuration(OIL_PUDDLE_ACTIVE_TIME),
	}
	table.insert(oilPuddles, puddleData)

	if puddle:IsA("Model") then
		for _, obj in ipairs(puddle:GetDescendants()) do
			if obj:IsA("BasePart") then
				obj.Anchored = true
				obj.CanCollide = false
				obj.CanTouch = false
				obj.CanQuery = false
			end
		end

		puddle:PivotTo(groundCFrame)
	elseif puddle:IsA("BasePart") then
		puddle.Anchored = true
		puddle.CanCollide = false
		puddle.CanTouch = false
		puddle.CanQuery = false
		puddle.CastShadow = false
		puddle.CFrame = groundCFrame
	end

	local originalTransparency = {}
	for _, visual in ipairs(getOilPuddleVisuals(puddle)) do
		originalTransparency[visual] = visual.Transparency
		visual.Transparency = 1
	end

	if isFallback and puddle:IsA("BasePart") then
		TweenService:Create(puddle, TweenInfo.new(GameSpeed:ScaleDuration(OIL_PUDDLE_FADE_TIME), Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Size = Vector3.new(OIL_SPLASH_RADIUS * 1.4, 0.08, OIL_SPLASH_RADIUS * 1.4),
		}):Play()
	end

	for visual, transparency in pairs(originalTransparency) do
		if visual.Parent then
			local tween = TweenService:Create(visual, TweenInfo.new(GameSpeed:ScaleDuration(OIL_PUDDLE_FADE_TIME), Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Transparency = transparency,
			})
			tween:Play()
		end
	end

	task.delay(GameSpeed:ScaleDuration(OIL_PUDDLE_ACTIVE_TIME), function()
		if not puddleData.instance or not puddleData.instance.Parent then
			return
		end

		if isFallback and not puddleData.isFire and puddle:IsA("BasePart") then
			TweenService:Create(puddle, TweenInfo.new(GameSpeed:ScaleDuration(OIL_PUDDLE_FADE_TIME), Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Size = Vector3.new(0.1, 0.08, 0.1),
			}):Play()
		end

		fadeOutOilPuddle(puddleData)
	end)

	Debris:AddItem(puddle, GameSpeed:ScaleDuration(OIL_PUDDLE_ACTIVE_TIME + OIL_PUDDLE_FADE_TIME + 1))
end

function fireOilProjectile(tower, target, fallbackTargetPosition, onImpact)
	local startPosition = getOilLaunchPosition(tower)
	local hrp = getLiveEnemyHrp(target)
	local targetPosition = (hrp and hrp.Position) or fallbackTargetPosition
	if not startPosition or not targetPosition then
		return
	end

	local projectile = Instance.new("Part")
	projectile.Name = "OilGlobProjectile"
	projectile.Shape = Enum.PartType.Ball
	projectile.Anchored = true
	projectile.CanCollide = false
	projectile.CanTouch = false
	projectile.CanQuery = false
	projectile.CastShadow = false
	projectile.Material = Enum.Material.SmoothPlastic
	projectile.Color = Color3.fromRGB(18, 14, 8)
	projectile.Size = Vector3.new(0.75, 0.75, 0.75)
	projectile.CFrame = CFrame.new(startPosition)
	projectile.Parent = workspace

	local midpoint = startPosition:Lerp(targetPosition, 0.5) + Vector3.new(0, 3, 0)
	local halfTime = OIL_PROJECTILE_TIME * 0.5
	local upTween = TweenService:Create(projectile, TweenInfo.new(GameSpeed:ScaleDuration(halfTime), Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		CFrame = CFrame.new(midpoint),
	})
	upTween:Play()
	upTween.Completed:Once(function()
		if not projectile.Parent then
			return
		end

		local currentTargetPosition = (hrp and hrp.Parent and hrp.Position) or targetPosition
		local downTween = TweenService:Create(projectile, TweenInfo.new(GameSpeed:ScaleDuration(halfTime), Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			CFrame = CFrame.new(currentTargetPosition),
			Size = Vector3.new(1.1, 1.1, 1.1),
		})
		downTween:Play()
		downTween.Completed:Once(function()
			if projectile.Parent then
				projectile:Destroy()
			end

			if onImpact then
				onImpact(currentTargetPosition)
			end
		end)
	end)

	Debris:AddItem(projectile, GameSpeed:ScaleDuration(1))
end

function applyOilSplashAt(primaryEnemy, impactPosition, damage)
	local splashDamage = math.max(1, math.floor(damage * 0.55 + 0.5))
	for _, entry in ipairs(getEnemiesInRadius(impactPosition, OIL_SPLASH_RADIUS, true)) do
		local hitEnemy = entry.enemy
		if hitEnemy == primaryEnemy then
			applyDirectDamage(hitEnemy, damage)
		else
			applyDirectDamage(hitEnemy, splashDamage)
		end

	end
end

function getOilImpactPosition(tower, towerState, enemy)
	local hrp = getLiveEnemyHrp(enemy)
	if not hrp then
		return nil
	end

	local impactPosition = hrp.Position
	if towerState.oilBetterAimEnabledVal and towerState.oilBetterAimEnabledVal.Value > 0 then
		local aheadStuds = towerState.oilAimAheadStudsVal and towerState.oilAimAheadStudsVal.Value or 10
		local velocity = hrp.AssemblyLinearVelocity
		local flatVelocity = Vector3.new(velocity.X, 0, velocity.Z)
		if flatVelocity.Magnitude > 0.5 then
			impactPosition += flatVelocity.Unit * aheadStuds
		end
	end

	return impactPosition
end

function findSecondaryOilTarget(tower, primaryEnemy)
	local towerPosition = getTowerPosition(tower)
	local bestEnemy = nil
	local bestDistance = math.huge
	for enemy in pairs(activeEnemies) do
		if enemy ~= primaryEnemy and isEnemyAlive(enemy) then
			local hrp = enemy:FindFirstChild("HumanoidRootPart")
			if hrp then
				local distance = (hrp.Position - towerPosition).Magnitude
				if distance < bestDistance then
					bestDistance = distance
					bestEnemy = enemy
				end
			end
		end
	end
	return bestEnemy
end

function getEnemiesOverlappingOilPuddle(puddleData)
	local enemies = {}
	local radius = puddleData.radius or OIL_SPLASH_RADIUS
	local center = puddleData.position

	for enemy in pairs(activeEnemies) do
		if enemy.Parent then
			local hrp = enemy:FindFirstChild("HumanoidRootPart")
			local healthVal = enemy:FindFirstChild("Health")

			if hrp and healthVal and healthVal.Value > 0 then
				local enemyPosition = hrp.Position
				local enemyRadius = 2
				if enemy:IsA("Model") then
					local boxCFrame, boxSize = enemy:GetBoundingBox()
					enemyPosition = boxCFrame.Position
					enemyRadius = math.max(enemyRadius, math.max(boxSize.X, boxSize.Z) * 0.5)
				elseif enemy:IsA("BasePart") then
					enemyRadius = math.max(enemyRadius, math.max(enemy.Size.X, enemy.Size.Z) * 0.5)
				end

				local offset = enemyPosition - center
				local horizontalDistance = Vector2.new(offset.X, offset.Z).Magnitude
				if horizontalDistance <= radius + enemyRadius + 1 then
					table.insert(enemies, enemy)
				end
			end
		end
	end

	return enemies
end

function updateOilPuddles(now)
	for index = #oilPuddles, 1, -1 do
		local puddleData = oilPuddles[index]
		local puddle = puddleData.instance

		if not puddle or not puddle.Parent then
			table.remove(oilPuddles, index)
			continue
		end

		if not puddleData.functional then
			continue
		end

		if now >= puddleData.expiresAt then
			fadeOutOilPuddle(puddleData)
			continue
		end

		local overlapping = getEnemiesOverlappingOilPuddle(puddleData)
		local currentlyInside = setmetatable({}, { __mode = "k" })

		for _, enemy in ipairs(overlapping) do
			currentlyInside[enemy] = true
			if puddleData.isFire then
				applyFirePuddleBurn(enemy, puddleData)
			else
				local justEntered = not puddleData.insideEnemies[enemy]
				puddleData.insideEnemies[enemy] = true
				coatEnemyInOil(enemy, puddleData)

				if justEntered and puddleData.fireReactionEnabled and isEnemyOnFire(enemy) then
					replaceOilPuddleWithFire(puddleData, enemy)
					break
				end
			end
		end

		for enemy in pairs(puddleData.insideEnemies) do
			if not currentlyInside[enemy] then
				puddleData.insideEnemies[enemy] = nil
			end
		end
	end
end

function attackWithOilLauncher(tower, towerState, enemy, damage)
	local hrp = getLiveEnemyHrp(enemy)
	if not hrp then
		return false
	end

	local lockedImpactPosition = getOilImpactPosition(tower, towerState, enemy) or hrp.Position
	local attackCount = (oilAttackCounts[tower] or 0) + 1
	oilAttackCounts[tower] = attackCount
	local doubleEvery = towerState.oilDoubleTossEveryVal and towerState.oilDoubleTossEveryVal.Value or 0
	local shouldDoubleToss = doubleEvery > 0 and attackCount % math.max(1, doubleEvery) == 0
	local postCooldown = towerState.oilPostCooldownVal and towerState.oilPostCooldownVal.Value or OIL_PUDDLE_POST_COOLDOWN
	local boostMultiplier = 1
	if oilRefineryBoostUntil[tower] and tick() < oilRefineryBoostUntil[tower] then
		boostMultiplier = towerState.oilRefineryBoostMultiplierVal and towerState.oilRefineryBoostMultiplierVal.Value or 1
	end

	local cooldownDuration = OIL_PARTICLE_START_TIME
		+ OIL_PUDDLE_FADE_DELAY
		+ OIL_PUDDLE_ACTIVE_TIME
		+ OIL_PUDDLE_FADE_TIME
		+ postCooldown
	oilPuddleCooldownUntil[tower] = tick() + GameSpeed:ScaleDuration(cooldownDuration * boostMultiplier)

	task.delay(GameSpeed:ScaleDuration(OIL_PARTICLE_START_TIME), function()
		if not tower.Parent then
			return
		end

		fireOilProjectile(tower, enemy, lockedImpactPosition, function(impactPosition)
			spawnOilPuddle(impactPosition, tower, towerState)
			applyOilSplashAt(enemy, impactPosition, damage)
		end)

		if shouldDoubleToss then
			local secondaryEnemy = findSecondaryOilTarget(tower, enemy)
			if secondaryEnemy then
				local secondaryImpactPosition = getOilImpactPosition(tower, towerState, secondaryEnemy)
				if secondaryImpactPosition then
					task.delay(GameSpeed:ScaleDuration(0.18), function()
						if tower.Parent then
							fireOilProjectile(tower, secondaryEnemy, secondaryImpactPosition, function(impactPosition)
								spawnOilPuddle(impactPosition, tower, towerState)
								applyOilSplashAt(secondaryEnemy, impactPosition, damage * 0.8)
							end)
						end
					end)
				end
			end
		end
	end)

	return true
end
local function attackEnemy(tower, towerState, enemy)
	if not isEnemyAlive(enemy) then
		return false
	end

	local towerType = towerState.towerType
	local damage = 10
	if towerState.damageVal and typeof(towerState.damageVal.Value) == "number" then
		damage = towerState.damageVal.Value
	end

	local rockTag = enemy:FindFirstChild("Rock")
	if rockTag and rockTag:IsA("IntValue") then
		local rockBonus = 0
		if towerState.rockBonusDamageVal and typeof(towerState.rockBonusDamageVal.Value) == "number" then
			rockBonus = towerState.rockBonusDamageVal.Value
		end
		damage = damage + rockBonus
	end

	local isPoisonous = towerState.poisonousVal and towerState.poisonousVal:IsA("IntValue")

	local hrp = enemy:FindFirstChild("HumanoidRootPart")

	if towerType == "Tesla Coil" then
		damage *= getTeslaDamageMultiplier(tower)
		if towerState.conductivityEnabledVal and towerState.conductivityEnabledVal.Value > 0 then
			applyConductivity(tower, towerState, enemy, true)
		end
		if isMetallic(enemy) then
			damage *= 2
		end

		if towerState.lightningMarkEnabledVal and towerState.lightningMarkEnabledVal.Value > 0 then
			if not teslaMarkedEnemies[tower] then
				teslaMarkedEnemies[tower] = {}
			end
			teslaMarkedEnemies[tower][enemy] = true
		end
	end

	playTowerAnim(tower, enemy, towerType)

	local oilState = oilCoatedEnemies[enemy]
	if oilState and (towerType == "Tesla Coil" or towerType == "Magnet") then
		applyNormalFire(enemy)
		if oilState.towerComboEnabled then
			damage *= oilState.towerDamageMultiplier or 1
		end
	end

	if towerType == "Magnet" then
		local towerPosition = getTowerPosition(tower)
		local radius = towerState.radiusVal and towerState.radiusVal.Value or 20

		local attackCount = (magnetAttackCounts[tower] or 0) + 1
		magnetAttackCounts[tower] = attackCount

		local chargedEveryHits = towerState.chargedEveryHitsVal and towerState.chargedEveryHitsVal.Value or 3
		local chargedEnabled = towerState.chargedBlastEnabledVal and towerState.chargedBlastEnabledVal.Value > 0
		local isChargedBlast = chargedEnabled and (attackCount % math.max(1, chargedEveryHits) == 0)

		local chargedBonusMultiplier = towerState.chargedBonusMultiplierVal and towerState.chargedBonusMultiplierVal.Value or 0
		local chargedBonusDamage = isChargedBlast and (damage * chargedBonusMultiplier) or 0

		if towerState.disturbanceEnabledVal and towerState.disturbanceEnabledVal.Value > 0 then
			local disturbanceMultiplier = towerState.disturbanceDamageMultiplierVal and towerState.disturbanceDamageMultiplierVal.Value or 1.75
			local disturbanceBonusDamage = damage * chargedBonusMultiplier
			local waveDamage = roundDamage((damage + disturbanceBonusDamage) * disturbanceMultiplier)
			local disturbanceNow = tick()

			for _, entry in ipairs(getEnemiesInRadius(towerPosition, radius, false)) do
				if (disturbanceHitUntil[entry.enemy] or 0) <= disturbanceNow then
					disturbanceHitUntil[entry.enemy] = disturbanceNow + DISTURBANCE_HIT_LOCKOUT
					applyDirectDamage(entry.enemy, waveDamage)
				end
			end

			return true
		end

		if isMetallic(enemy) then
			applySlowEffect(enemy, towerState)
		end

		if towerState.highVoltageEnabledVal and towerState.highVoltageEnabledVal.Value > 0 and isChargedBlast and isMetallic(enemy) then
			local maxMultiplier = towerState.highVoltageMaxMultiplierVal and towerState.highVoltageMaxMultiplierVal.Value or 1.25
			local fullDamageRadius = radius * 0.25
			local falloffPower = 3 -- bigger = gentler falloff
			local baseChargedDamage = damage + chargedBonusDamage

			for _, entry in ipairs(getEnemiesInRadius(towerPosition, radius, true)) do
				local proximityMultiplier

				if entry.distance <= fullDamageRadius then
					proximityMultiplier = maxMultiplier
				else
					local falloffAlpha = math.clamp(
						(entry.distance - fullDamageRadius) / math.max(radius - fullDamageRadius, 0.001),
						0,
						1
					)

					local curvedFalloff = falloffAlpha ^ falloffPower
					proximityMultiplier = maxMultiplier + ((1 - maxMultiplier) * curvedFalloff)
				end

				local arcDamage = roundDamage(baseChargedDamage * proximityMultiplier)
				applyDirectDamage(entry.enemy, arcDamage)
			end

			return true
		end

		local totalDamage = roundDamage(damage + chargedBonusDamage)
		applyDirectDamage(enemy, totalDamage)
		return true
	end

	if towerType == "Cannon" then
		return true
	end

	if towerType == "Spike Thrower" then
		return fireSpikeAttack(tower, towerState, enemy)
	end

	if towerType == "Oil Launcher" then
		return attackWithOilLauncher(tower, towerState, enemy, damage)
	end

	if isPoisonous then
		applyPoison(tower, towerState, enemy)
		return true
	end

	applyDirectDamage(enemy, damage)
	return true
end

function TowerBehaviors.start()
	if started then
		return
	end

	started = true

	for _, obj in ipairs(placedTowersFolder:GetChildren()) do
		inspectTowerInstance(obj)
	end

	for _, obj in ipairs(workspace:GetChildren()) do
		inspectEnemyInstance(obj)
	end

	placedTowersFolder.ChildAdded:Connect(inspectTowerInstance)
	placedTowersFolder.ChildRemoved:Connect(function(obj)
		unregisterTower(obj)
	end)

	workspace.ChildAdded:Connect(inspectEnemyInstance)
	workspace.ChildRemoved:Connect(function(obj)
		unregisterEnemy(obj)
	end)

	RunService.Heartbeat:Connect(function(dt)
		local now = tick()
		local scaledDt = GameSpeed:ScaleDelta(dt)
		enemySpatial:update(scaledDt)

		staticFieldUpdateElapsed += scaledDt
		if staticFieldUpdateElapsed >= 0.1 then
			staticFieldUpdateElapsed = 0
			updateStaticFieldEffects()
		end

		supportHealingUpdateElapsed += scaledDt
		if supportHealingUpdateElapsed >= 0.2 then
			supportHealingUpdateElapsed = 0
			updateSupportHealing(now)
		end

		magnetFieldVisualUpdateElapsed += scaledDt
		if magnetFieldVisualUpdateElapsed >= 0.2 then
			magnetFieldVisualUpdateElapsed = 0
			updateMagnetFieldVisuals()
		end

		updateNormalFireEffects(now)
		updateFirePuddleBurns(now)

		oilPuddleCheckElapsed += scaledDt
		if oilPuddleCheckElapsed >= OIL_PUDDLE_CHECK_INTERVAL then
			oilPuddleCheckElapsed = 0
			updateOilPuddles(now)
		end

		for tower in pairs(activeTowers) do
			if not tower.Parent then
				unregisterTower(tower)
				continue
			end

			local towerState = buildTowerState(tower)
			towerStateCache[tower] = towerState

			local radius = towerState.radiusVal and towerState.radiusVal.Value or 20
			local attackSpeed = towerState.attackSpeedVal and towerState.attackSpeedVal.Value or 1
			local lastAttack = lastAttackTime[tower] or 0

			local position = getTowerPosition(tower)
			if not position then
				continue
			end

			if towerState.towerType == "Extractor" then
				updateExtractor(tower, towerState, now)
				continue
			end

			if towerState.towerType == "Control Panel" then
				continue
			end

			if towerState.towerType == "Oil Launcher" and (oilPuddleCooldownUntil[tower] or 0) > now then
				continue
			end

			if towerState.towerType == "Spike Thrower" then
				updateSpikeStorm(tower, towerState, now)

				local overdriveStep = towerState.spikeOverdriveStepVal and towerState.spikeOverdriveStepVal.Value or 0
				local overdriveMax = towerState.spikeOverdriveMaxVal and towerState.spikeOverdriveMaxVal.Value or 0
				local idleReset = towerState.spikeOverdriveIdleResetVal and towerState.spikeOverdriveIdleResetVal.Value or 3
				if overdriveStep > 0 and overdriveMax > 0 then
					if now - (spikeLastActiveAt[tower] or 0) > idleReset then
						spikeOverdriveStacks[tower] = 0
					end

					local speedup = math.min(overdriveMax, (spikeOverdriveStacks[tower] or 0) * overdriveStep)
					attackSpeed *= math.max(0.15, 1 - speedup)
				end
			end

			updateCannonTracking(tower, towerState, position)

			if now - lastAttack < GameSpeed:ScaleDuration(attackSpeed) then
				continue
			end

			if towerState.towerType == "Magnet" then
				if towerState.distortionZoneEnabledVal and towerState.distortionZoneEnabledVal.Value > 0 then
					for _, entry in ipairs(getEnemiesInRadius(position, radius, true)) do
						applyDistortionZone(entry.enemy)
					end
				end

				if towerState.electromagneticStormEnabledVal and towerState.electromagneticStormEnabledVal.Value > 0 then
					local stormInterval = towerState.electromagneticStormIntervalVal and towerState.electromagneticStormIntervalVal.Value or 1
					local lastStorm = electromagneticStormLastPulse[tower] or 0

					if now - lastStorm >= GameSpeed:ScaleDuration(stormInterval) then
						applyElectromagneticStorm(tower, towerState)
						electromagneticStormLastPulse[tower] = now
					end
				end
			end

			if towerState.acidRainEnabledVal and towerState.acidRainEnabledVal.Value > 0 then
				local acidRainInterval = towerState.acidRainIntervalVal and towerState.acidRainIntervalVal.Value or 10
				local lastAcidRain = acidRainLastCast[tower] or 0

				if now - lastAcidRain >= GameSpeed:ScaleDuration(acidRainInterval) then
					startAcidRain(towerState)
					acidRainLastCast[tower] = now
				end
			end

			local requireUnpoisoned = towerState.poisonousVal and towerState.poisonousVal:IsA("IntValue")

			if towerState.towerType == "Mushroom" then
				local poisonTargets = towerState.poisonTargetsVal and towerState.poisonTargetsVal.Value or 1
				local targets = findTargetEnemies(tower, position, radius, requireUnpoisoned, poisonTargets)

				if #targets > 0 then
					local attacked = false
					for _, target in ipairs(targets) do
						attacked = attackEnemy(tower, towerState, target) or attacked
					end
					if attacked then
						lastAttackTime[tower] = now
					end
				end
			else
				local target = getOrAcquireTarget(tower, position, radius, requireUnpoisoned)
				if target then
					if attackEnemy(tower, towerState, target) then
						lastAttackTime[tower] = now
					else
						currentTargets[tower] = nil
					end
				else
					currentTargets[tower] = nil
				end
			end
		end
	end)

	RunService.Heartbeat:Connect(function(dt)
		local now = tick()
		local scaledDt = GameSpeed:ScaleDelta(dt)

		serverTiming.conductivityCleanupElapsed += scaledDt
		if serverTiming.conductivityCleanupElapsed >= serverTiming.conductivityCleanupInterval then
			serverTiming.conductivityCleanupElapsed = 0
			for enemy, state in pairs(conductiveEnemies) do
				if not enemy.Parent or now >= state.expiresAt then
					removeConductivity(enemy)
				end
			end
		end

		for tower in pairs(activeTowers) do
			if tower.Parent and getTowerType(tower) == "Tesla Coil" then
				local towerState = towerStateCache[tower] or buildTowerState(tower)
				towerStateCache[tower] = towerState

				updateTeslaOrbitBall(tower, towerState, now, scaledDt)
				updateTeslaSeekerBalls(tower, towerState, now, scaledDt)
				updateTeslaStormBalls(tower, towerState, now, scaledDt)
				updateTeslaBombs(tower, towerState, now, scaledDt)
			end
		end
	end)
end

return TowerBehaviors
