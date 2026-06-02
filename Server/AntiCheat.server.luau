local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local AntiCheatService = require(script.Parent:WaitForChild("AntiCheatService"))
local TowerData = require(game.ReplicatedStorage:WaitForChild("TowerData"))

local DEFAULT_WALKSPEED = 16
local MAX_WALKSPEED = 20
local DEFAULT_JUMP_POWER = 50
local MAX_JUMP_POWER = 60
local DEFAULT_JUMP_HEIGHT = 7.2
local MAX_JUMP_HEIGHT = 8.5
local MAX_PICKAXE_STRENGTH = 0
local MAX_RESOURCE_MULTIPLIER = 1
local MAX_HORIZONTAL_SPEED = 52
local MAX_UPWARD_DISPLACEMENT = 18
local MAX_UPWARD_SPEED = 88
local SPEED_GRACE_TIME = 0.22
local AIR_HOVER_GRACE_TIME = 1.2
local SPAWN_MOVEMENT_GRACE_TIME = 4
local WALL_PHASE_MIN_DISTANCE = 5

local FORBIDDEN_CHARACTER_CLASSES = {
	AlignOrientation = true,
	AlignPosition = true,
	AngularVelocity = true,
	BodyForce = true,
	BodyGyro = true,
	BodyPosition = true,
	BodyVelocity = true,
	LinearVelocity = true,
	VectorForce = true,
}

local BODY_PART_NAMES = {
	Head = true,
	HumanoidRootPart = true,
	LeftFoot = true,
	LeftHand = true,
	LeftLowerArm = true,
	LeftLowerLeg = true,
	LeftUpperArm = true,
	LeftUpperLeg = true,
	LowerTorso = true,
	RightFoot = true,
	RightHand = true,
	RightLowerArm = true,
	RightLowerLeg = true,
	RightUpperArm = true,
	RightUpperLeg = true,
	Torso = true,
	UpperTorso = true,
	["Left Arm"] = true,
	["Left Leg"] = true,
	["Right Arm"] = true,
	["Right Leg"] = true,
}

local playerState = {}
local resourceAttributes = { "cash", "stone", "crystal", "metal" }
local towerCostLookup = {}

for _, towerInfo in ipairs(TowerData) do
	towerCostLookup[towerInfo.name] = {
		stone = towerInfo.stone or 0,
		crystal = towerInfo.crystal or 0,
		metal = towerInfo.metal or 0,
	}
end

local function isBypassed(player)
	return AntiCheatService:IsBypassed(player)
end

local function flag(player, reason, action)
	AntiCheatService:Flag(player, reason, action)
end

local function resetMiningAttributes(player)
	local strength = tonumber(player:GetAttribute("PickaxeStrength")) or 0
	if strength > MAX_PICKAXE_STRENGTH then
		player:SetAttribute("PickaxeStrength", MAX_PICKAXE_STRENGTH)
		flag(player, "pickaxe strength above server limit", "reset")
	end

	local multiplier = tonumber(player:GetAttribute("ResourceMultiplier")) or 1
	if multiplier > MAX_RESOURCE_MULTIPLIER then
		player:SetAttribute("ResourceMultiplier", MAX_RESOURCE_MULTIPLIER)
		flag(player, "resource multiplier above server limit", "reset")
	end
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

local function findPlayerByUserId(userId)
	for _, player in ipairs(Players:GetPlayers()) do
		if player.UserId == userId then
			return player
		end
	end

	return nil
end

local function getTowerType(tower)
	local tag = tower and tower:FindFirstChild("TowerType")
	if tag and tag:IsA("StringValue") then
		return tag.Value
	end

	return tower and tower.Name or nil
end

local function getTrustedSpentAttribute(resourceType)
	return "TrustedSpent" .. resourceType:sub(1, 1):upper() .. resourceType:sub(2)
end

local function scanPlacedTowers()
	local placedTowers = workspace:FindFirstChild("PlacedTowers")
	if not placedTowers then
		return
	end

	for _, tower in ipairs(placedTowers:GetChildren()) do
		local ownerUserId = getTowerOwnerId(tower)
		local owner = ownerUserId and findPlayerByUserId(ownerUserId) or nil

		if tower:GetAttribute("TrustedTowerPlacement") ~= true then
			if owner then
				flag(owner, "untrusted tower appeared in PlacedTowers", "destroyed")
			else
				warn("[AntiCheat] Untrusted tower appeared in PlacedTowers; destroyed.")
			end
			tower:Destroy()
			continue
		end

		local trustedOwnerUserId = tower:GetAttribute("TrustedOwnerUserId")
		if typeof(trustedOwnerUserId) == "number" and ownerUserId ~= trustedOwnerUserId then
			tower:SetAttribute("OwnerUserId", trustedOwnerUserId)
			local trustedOwner = findPlayerByUserId(trustedOwnerUserId)
			if trustedOwner then
				flag(trustedOwner, "tower owner tamper", "restored")
			end
		end

		local towerType = getTowerType(tower)
		local costs = towerType and towerCostLookup[towerType] or nil
		for _, resourceType in ipairs({ "stone", "crystal", "metal" }) do
			local trustedAttr = getTrustedSpentAttribute(resourceType)
			local trustedSpent = tower:GetAttribute(trustedAttr)
			local publicAttr = "Spent" .. resourceType:sub(1, 1):upper() .. resourceType:sub(2)
			local publicSpent = tower:GetAttribute(publicAttr)
			if typeof(trustedSpent) ~= "number" then
				trustedSpent = costs and math.max(0, costs[resourceType] or 0) or 0
				tower:SetAttribute(trustedAttr, trustedSpent)
			end
			if publicSpent ~= trustedSpent then
				tower:SetAttribute(publicAttr, trustedSpent)
				if owner then
					flag(owner, "tower refund spend tamper", "restored")
				end
			end
		end

		local trustedCash = tower:GetAttribute("TrustedSpentCash")
		if typeof(trustedCash) ~= "number" then
			trustedCash = math.max(0, tower:GetAttribute("SpentCash") or 0)
			tower:SetAttribute("TrustedSpentCash", trustedCash)
		end
		if tower:GetAttribute("SpentCash") ~= trustedCash then
			tower:SetAttribute("SpentCash", trustedCash)
			if owner then
				flag(owner, "tower cash refund tamper", "restored")
			end
		end

		for pathIndex = 1, 3 do
			local publicLevelName = "UpgradePath" .. pathIndex .. "Level"
			local trustedLevelName = "TrustedUpgradePath" .. pathIndex .. "Level"
			local trustedLevel = tower:GetAttribute(trustedLevelName)
			local publicLevel = tower:GetAttribute(publicLevelName)
			if typeof(trustedLevel) ~= "number" then
				trustedLevel = math.max(0, publicLevel or 0)
				tower:SetAttribute(trustedLevelName, trustedLevel)
			end
			if publicLevel ~= trustedLevel then
				tower:SetAttribute(publicLevelName, trustedLevel)
				if owner then
					flag(owner, "tower upgrade level tamper", "restored")
				end
			end
		end
	end
end

local function trustExistingTowersAtStartup()
	local placedTowers = workspace:FindFirstChild("PlacedTowers")
	if not placedTowers then
		return
	end

	for _, tower in ipairs(placedTowers:GetChildren()) do
		if tower:GetAttribute("TrustedTowerPlacement") ~= true then
			tower:SetAttribute("TrustedTowerPlacement", true)
		end

		local ownerUserId = getTowerOwnerId(tower)
		if typeof(ownerUserId) == "number" then
			tower:SetAttribute("TrustedOwnerUserId", ownerUserId)
		end

		for _, resourceType in ipairs({ "stone", "crystal", "metal" }) do
			local publicAttr = "Spent" .. resourceType:sub(1, 1):upper() .. resourceType:sub(2)
			local trustedAttr = getTrustedSpentAttribute(resourceType)
			tower:SetAttribute(trustedAttr, math.max(0, tower:GetAttribute(publicAttr) or 0))
		end

		tower:SetAttribute("TrustedSpentCash", math.max(0, tower:GetAttribute("SpentCash") or 0))

		for pathIndex = 1, 3 do
			tower:SetAttribute(
				"TrustedUpgradePath" .. pathIndex .. "Level",
				math.max(0, tower:GetAttribute("UpgradePath" .. pathIndex .. "Level") or 0)
			)
		end
	end
end

local function resetHumanoidStats(player, humanoid)
	if humanoid.WalkSpeed > MAX_WALKSPEED then
		humanoid.WalkSpeed = DEFAULT_WALKSPEED
		flag(player, "walkspeed above server limit", "reset")
	end

	if humanoid.UseJumpPower and humanoid.JumpPower > MAX_JUMP_POWER then
		humanoid.JumpPower = DEFAULT_JUMP_POWER
		flag(player, "jump power above server limit", "reset")
	elseif not humanoid.UseJumpPower and humanoid.JumpHeight > MAX_JUMP_HEIGHT then
		humanoid.JumpHeight = DEFAULT_JUMP_HEIGHT
		flag(player, "jump height above server limit", "reset")
	end
end

local function hasToolOrAccessoryAncestor(instance)
	local current = instance.Parent
	while current do
		if current:IsA("Tool") or current:IsA("Accessory") then
			return true
		end
		current = current.Parent
	end

	return false
end

local function stripFlightObjects(player, character)
	for _, descendant in ipairs(character:GetDescendants()) do
		local parent = descendant.Parent
		if FORBIDDEN_CHARACTER_CLASSES[descendant.ClassName]
			and parent
			and parent:IsA("BasePart")
			and BODY_PART_NAMES[parent.Name]
			and not hasToolOrAccessoryAncestor(descendant)
		then
			descendant:Destroy()
			flag(player, "unauthorized character mover", "destroyed")
		end
	end
end

local function getRaycastParams(character)
	local excludes = { character }
	local placedTowers = workspace:FindFirstChild("PlacedTowers")
	if placedTowers then
		table.insert(excludes, placedTowers)
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = excludes
	params.IgnoreWater = true
	return params
end

local function getGroundDistance(character, root)
	local result = workspace:Raycast(root.Position, Vector3.new(0, -32, 0), getRaycastParams(character))
	return result and (root.Position - result.Position).Magnitude or math.huge
end

local function snapBack(player, root, state, reason)
	if not state.lastSafeCFrame then
		return
	end

	root.CFrame = state.lastSafeCFrame
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	flag(player, reason, "snapped back")
end

local function checkMovement(player, character, humanoid, root, dt)
	local state = playerState[player]
	if not state then
		return
	end

	local currentPosition = root.Position
	if not state.lastPosition then
		state.lastPosition = currentPosition
		state.lastSafeCFrame = root.CFrame
		return
	end

	if os.clock() - (state.spawnedAt or 0) < SPAWN_MOVEMENT_GRACE_TIME then
		state.lastPosition = currentPosition
		state.lastSafeCFrame = root.CFrame
		state.speedSuspicionTime = 0
		state.upwardSuspicionTime = 0
		state.hoverSuspicionTime = 0
		return
	end

	if root.Anchored or humanoid.Health <= 0 then
		state.lastPosition = currentPosition
		state.lastSafeCFrame = root.CFrame
		state.speedSuspicionTime = 0
		state.upwardSuspicionTime = 0
		state.hoverSuspicionTime = 0
		return
	end

	local displacement = currentPosition - state.lastPosition
	local horizontalDistance = Vector3.new(displacement.X, 0, displacement.Z).Magnitude
	local horizontalSpeed = horizontalDistance / math.max(dt, 1 / 240)
	local upwardSpeed = root.AssemblyLinearVelocity.Y
	local groundDistance = getGroundDistance(character, root)
	local hasNearbyGround = humanoid.FloorMaterial ~= Enum.Material.Air or groundDistance <= 8

	if displacement.Y > MAX_UPWARD_DISPLACEMENT and not hasNearbyGround then
		snapBack(player, root, state, "impossible upward displacement")
		state.lastPosition = root.Position
		return
	end

	if horizontalSpeed > MAX_HORIZONTAL_SPEED then
		state.speedSuspicionTime += dt
		if state.speedSuspicionTime >= SPEED_GRACE_TIME then
			snapBack(player, root, state, "sustained horizontal speed")
			state.lastPosition = root.Position
			state.speedSuspicionTime = 0
			return
		end
	else
		state.speedSuspicionTime = 0
	end

	if upwardSpeed > MAX_UPWARD_SPEED and humanoid.FloorMaterial == Enum.Material.Air then
		state.upwardSuspicionTime += dt
		if state.upwardSuspicionTime >= SPEED_GRACE_TIME then
			snapBack(player, root, state, "sustained upward flight")
			state.lastPosition = root.Position
			state.upwardSuspicionTime = 0
			return
		end
	else
		state.upwardSuspicionTime = 0
	end

	if not hasNearbyGround and upwardSpeed > -2 then
		state.hoverSuspicionTime += dt
		if state.hoverSuspicionTime >= AIR_HOVER_GRACE_TIME then
			snapBack(player, root, state, "sustained airborne hover")
			state.lastPosition = root.Position
			state.hoverSuspicionTime = 0
			return
		end
	else
		state.hoverSuspicionTime = 0
	end

	if displacement.Magnitude >= WALL_PHASE_MIN_DISTANCE then
		local result = workspace:Raycast(state.lastPosition, displacement, getRaycastParams(character))
		if result and result.Instance and result.Instance.CanCollide then
			snapBack(player, root, state, "through-wall movement")
			state.lastPosition = root.Position
			return
		end
	end

	state.lastPosition = currentPosition
	if hasNearbyGround then
		state.lastSafeCFrame = root.CFrame
	end
end

local function checkPlayer(player, dt)
	if isBypassed(player) then
		local state = playerState[player]
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if state and root then
			state.lastPosition = root.Position
			state.lastSafeCFrame = root.CFrame
		end
		return
	end

	resetMiningAttributes(player)
	AntiCheatService:CheckTrustedAttributes(player, resourceAttributes)

	local character = player.Character
	if not character or not character.Parent then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root then
		return
	end

	resetHumanoidStats(player, humanoid)
	stripFlightObjects(player, character)
	checkMovement(player, character, humanoid, root, dt)
end

local function trackPlayer(player)
	playerState[player] = {
		lastPosition = nil,
		lastSafeCFrame = nil,
		lastWarnedAt = 0,
		spawnedAt = os.clock(),
		hoverSuspicionTime = 0,
		speedSuspicionTime = 0,
		upwardSuspicionTime = 0,
		violations = 0,
	}

	AntiCheatService:TrackPlayer(player)
	player:SetAttribute("AntiCheatBypass", player:GetAttribute("AntiCheatBypass") == true)

	player.CharacterAdded:Connect(function(character)
		local state = playerState[player]
		if not state then
			return
		end

		state.lastPosition = nil
		state.lastSafeCFrame = nil
		state.spawnedAt = os.clock()
		state.hoverSuspicionTime = 0
		state.speedSuspicionTime = 0
		state.upwardSuspicionTime = 0
		character:WaitForChild("HumanoidRootPart", 5)
	end)
end

Players.PlayerAdded:Connect(trackPlayer)
Players.PlayerRemoving:Connect(function(player)
	playerState[player] = nil
end)

for _, player in ipairs(Players:GetPlayers()) do
	trackPlayer(player)
end

trustExistingTowersAtStartup()

local towerScanAccumulator = 0

RunService.Heartbeat:Connect(function(dt)
	for _, player in ipairs(Players:GetPlayers()) do
		checkPlayer(player, dt)
	end

	towerScanAccumulator += dt
	if towerScanAccumulator >= 0.25 then
		towerScanAccumulator = 0
		scanPlacedTowers()
	end
end)
