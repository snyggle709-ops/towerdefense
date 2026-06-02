-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local VRService = game:GetService("VRService")

-- Player Setup
local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local rootPart = character:WaitForChild("HumanoidRootPart")
local animator = humanoid:WaitForChild("Animator")

-- Remove default animation script
local defaultAnimate = character:FindFirstChild("Animate")
if VRService.VREnabled then
	if defaultAnimate then
		defaultAnimate.Enabled = true
	end
	return
end

if defaultAnimate then defaultAnimate.Enabled = false end

humanoid.WalkSpeed = 16

-- Config
local CONFIG = {
	MAX_SPEED = 16,
	ACCELERATION = 20,
	DECELERATION = 12,
	ANIM_BLEND_SPEED = 8,
	MIN_WALK_ANIM_SPEED = 0.4,
	MAX_WALK_ANIM_SPEED = 1.8,
	ROTATION_SPEED = 12,
}

-- Animation IDs
local ANIM_IDS = {
	walk = "rbxassetid://128327433396502",
	idle = "rbxassetid://128501161758483",
	jump = "rbxassetid://107133390709086",
	fall = "rbxassetid://105444495892090",
}

-- Load Animations
local animations = {}
local tracks = {}

local function loadAnimations()
	for name, id in pairs(ANIM_IDS) do
		local anim = Instance.new("Animation")
		anim.AnimationId = id
		animations[name] = anim
		tracks[name] = animator:LoadAnimation(anim)
	end

	tracks.idle.Priority = Enum.AnimationPriority.Idle
	tracks.walk.Priority = Enum.AnimationPriority.Movement
	tracks.jump.Priority = Enum.AnimationPriority.Action
	tracks.fall.Priority = Enum.AnimationPriority.Action
end

loadAnimations()

-- State
local currentSpeed = 0
local lastMoveDir = Vector3.new(0, 0, -1)
local isJumping = false
local isFalling = false

-- Animation weights
local animWeights = { idle = 1, walk = 0, jump = 0, fall = 0 }

local isMobile = UserInputService.TouchEnabled

local camera = workspace.CurrentCamera

-- Gets movement direction from either keyboard (desktop) or humanoid.MoveDirection (mobile)
-- humanoid.MoveDirection is set by Roblox's default thumbstick and works on both platforms
-- so we just always use it - it reads keyboard input too when on desktop via default controls
local function getWorldMoveDirection()
	-- humanoid.MoveDirection is already world-space and camera-relative
	-- Roblox's control scripts set this automatically from both keyboard and thumbstick
	local md = humanoid.MoveDirection
	if md.Magnitude > 0.1 then
		return Vector3.new(md.X, 0, md.Z).Unit
	end

	-- Fallback for desktop: read keyboard manually in case AutoRotate or controls are off
	if not isMobile then
		local dir = Vector3.new()
		if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir += Vector3.new(0, 0, -1) end
		if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir += Vector3.new(0, 0, 1) end
		if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir += Vector3.new(-1, 0, 0) end
		if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir += Vector3.new(1, 0, 0) end

		if dir.Magnitude > 0 then
			local camCF = camera.CFrame
			local flatForward = Vector3.new(camCF.LookVector.X, 0, camCF.LookVector.Z).Unit
			local flatRight = Vector3.new(camCF.RightVector.X, 0, camCF.RightVector.Z).Unit
			local worldDir = (flatForward * -dir.Z) + (flatRight * dir.X)
			if worldDir.Magnitude > 0 then
				return worldDir.Unit
			end
		end
	end

	return Vector3.new()
end

-- Jump detection
local function setupJump()
	humanoid.Jumping:Connect(function(active)
		if active then
			isJumping = true
			isFalling = false
		end
	end)

	humanoid.StateChanged:Connect(function(_, newState)
		if newState == Enum.HumanoidStateType.Freefall then
			isFalling = true
			isJumping = false
		elseif
			newState == Enum.HumanoidStateType.Landed
			or newState == Enum.HumanoidStateType.Running
			or newState == Enum.HumanoidStateType.RunningNoPhysics
		then
			isJumping = false
			isFalling = false
		end
	end)
end

setupJump()

-- Animations
local function updateAnimations(dt, speedRatio, state)
	local targetWeights = { idle = 0, walk = 0, jump = 0, fall = 0 }

	if state == "jump" then
		targetWeights.jump = 1
	elseif state == "fall" then
		targetWeights.fall = 1
	elseif state == "walk" then
		targetWeights.walk = speedRatio
		targetWeights.idle = 1 - speedRatio
	else
		targetWeights.idle = 1
	end

	local blend = math.min(1, dt * CONFIG.ANIM_BLEND_SPEED)

	for name, target in pairs(targetWeights) do
		animWeights[name] = animWeights[name] + (target - animWeights[name]) * blend

		local track = tracks[name]
		if animWeights[name] > 0.01 then
			if not track.IsPlaying then track:Play(0.1) end
			track:AdjustWeight(animWeights[name], 0.05)

			if name == "walk" then
				local animSpeed = CONFIG.MIN_WALK_ANIM_SPEED
					+ (speedRatio * (CONFIG.MAX_WALK_ANIM_SPEED - CONFIG.MIN_WALK_ANIM_SPEED))
				track:AdjustSpeed(animSpeed)
			end
		else
			if track.IsPlaying then track:Stop(0.15) end
		end
	end
end

-- Main loop
RunService.Heartbeat:Connect(function(dt)
	if VRService.VREnabled then
		local activeDefaultAnimate = character and character:FindFirstChild("Animate")
		if activeDefaultAnimate then
			activeDefaultAnimate.Enabled = true
		end
		humanoid.WalkSpeed = 16
		for _, track in pairs(tracks) do
			if track.IsPlaying then
				track:Stop(0.1)
			end
		end
		return
	end

	local worldDir = getWorldMoveDirection()
	local isMoving = worldDir.Magnitude > 0.1
	local miningMovementLocked = player:GetAttribute("MiningMovementLocked") == true
	if miningMovementLocked then
		worldDir = Vector3.new()
		isMoving = false
	end

	if isMoving then
		lastMoveDir = worldDir
	end

	-- Smooth speed
	if isMoving then
		currentSpeed = math.min(CONFIG.MAX_SPEED, currentSpeed + CONFIG.ACCELERATION * dt)
	else
		currentSpeed = math.max(0, currentSpeed - CONFIG.DECELERATION * dt)
	end

	local speedRatio = currentSpeed / CONFIG.MAX_SPEED

	humanoid.WalkSpeed = miningMovementLocked and 0 or currentSpeed

	-- Override velocity for smooth deceleration
	local yVel = rootPart.AssemblyLinearVelocity.Y
	if miningMovementLocked then
		rootPart.AssemblyLinearVelocity = Vector3.new(0, yVel, 0)
	else
		rootPart.AssemblyLinearVelocity = Vector3.new(
			lastMoveDir.X * currentSpeed,
			yVel,
			lastMoveDir.Z * currentSpeed
		)
	end

	-- Smooth rotation toward move direction
	if isMoving and not miningMovementLocked then
		local angle = math.atan2(worldDir.X, worldDir.Z)
		local targetCF = CFrame.new(rootPart.Position) * CFrame.Angles(0, angle, 0)
		rootPart.CFrame = rootPart.CFrame:Lerp(targetCF, math.min(1, dt * CONFIG.ROTATION_SPEED))
	end

	-- Animation state
	local state = "idle"
	if isJumping then
		state = "jump"
	elseif isFalling then
		state = "fall"
	elseif currentSpeed > 0.5 then
		state = "walk"
	end

	updateAnimations(dt, speedRatio, state)
end)

-- Respawn
player.CharacterAdded:Connect(function(newChar)
	character = newChar
	humanoid = newChar:WaitForChild("Humanoid")
	rootPart = newChar:WaitForChild("HumanoidRootPart")
	animator = humanoid:WaitForChild("Animator")

	local newAnimate = newChar:FindFirstChild("Animate")
	if VRService.VREnabled then
		if newAnimate then
			newAnimate.Enabled = true
		end
		humanoid.WalkSpeed = 16
		return
	end

	if newAnimate then newAnimate.Enabled = false end

	humanoid.WalkSpeed = 16
	currentSpeed = 0
	isJumping = false
	isFalling = false
	animWeights = { idle = 1, walk = 0, jump = 0, fall = 0 }

	loadAnimations()
	setupJump()
end)
