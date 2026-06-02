local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local rng = Random.new()
local trackedEnemies = {}
local scanElapsed = 0

local SPAWN_INTERVAL = 0.2
local RESCAN_INTERVAL = 0.75
local MIN_MOVE_DISTANCE = 0.08
local MARK_LIFETIME = 0.9
local FADE_TIME = 0.42

local EFFECTS = {
	slow = {
		attribute = "EnemySlowedEffect",
		name = "FrostGroundMark",
		baseColor = Color3.fromRGB(145, 225, 255),
		colorJitter = 18,
		transparency = 0.2,
		lengthMin = 1.25,
		lengthMax = 2.45,
		widthMin = 0.75,
		widthMax = 1.35,
		heightMin = 0.075,
		heightMax = 0.14,
		backMin = 0.9,
		backMax = 1.7,
		sideSpread = 0.85,
		countMin = 2,
		countMax = 3,
	},
	bleed = {
		attribute = "EnemyBleedingEffect",
		name = "BleedGroundMark",
		baseColor = Color3.fromRGB(175, 12, 18),
		colorJitter = 20,
		transparency = 0.18,
		lengthMin = 0.75,
		lengthMax = 1.45,
		widthMin = 0.65,
		widthMax = 1.15,
		heightMin = 0.065,
		heightMax = 0.12,
		backMin = 0.8,
		backMax = 1.45,
		sideSpread = 0.65,
		countMin = 1,
		countMax = 3,
	},
}

local function jitterColor(color, amount)
	local function channel(value)
		return math.clamp(value + rng:NextInteger(-amount, amount), 0, 255)
	end

	return Color3.fromRGB(
		channel(math.floor(color.R * 255)),
		channel(math.floor(color.G * 255)),
		channel(math.floor(color.B * 255))
	)
end

local function getEnemyRoot(model)
	return model:FindFirstChild("HumanoidRootPart")
end

local function isEnemyModel(model)
	return model:IsA("Model")
		and getEnemyRoot(model) ~= nil
		and (model:FindFirstChild("Health") ~= nil or model:FindFirstChild("Speed") ~= nil)
end

local function findEnemyModel(instance)
	local current = instance
	while current and current ~= workspace do
		if current:IsA("Model") and isEnemyModel(current) then
			return current
		end
		current = current.Parent
	end

	return nil
end

local function groundCFrame(position, direction)
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = {}

	local result = workspace:Raycast(position + Vector3.new(0, 2, 0), Vector3.new(0, -14, 0), rayParams)
	local groundPosition = result and result.Position or position - Vector3.new(0, 2.3, 0)
	local normal = result and result.Normal or Vector3.yAxis
	local forward = direction - normal * direction:Dot(normal)
	if forward.Magnitude < 0.01 then
		forward = Vector3.zAxis
	else
		forward = forward.Unit
	end
	local right = forward:Cross(normal).Unit

	return CFrame.fromMatrix(groundPosition + normal * 0.035, right, normal, -forward)
end

local function spawnGroundMark(position, moveDirection, effect)
	local side = moveDirection:Cross(Vector3.yAxis)
	if side.Magnitude < 0.01 then
		side = Vector3.xAxis
	else
		side = side.Unit
	end

	local length = rng:NextNumber(effect.lengthMin, effect.lengthMax)
	local width = rng:NextNumber(effect.widthMin, effect.widthMax)
	local height = rng:NextNumber(effect.heightMin, effect.heightMax)
	local shapeRoll = rng:NextNumber()
	local shape = Enum.PartType.Block
	if shapeRoll < 0.25 then
		shape = Enum.PartType.Cylinder
	elseif shapeRoll < 0.45 then
		shape = Enum.PartType.Ball
	end

	local markPosition = position
		- (moveDirection * rng:NextNumber(effect.backMin, effect.backMax))
		+ (side * rng:NextNumber(-effect.sideSpread, effect.sideSpread))

	local mark = Instance.new("Part")
	mark.Name = effect.name
	mark.Shape = shape
	if shape == Enum.PartType.Ball then
		mark.Size = Vector3.new(width * rng:NextNumber(0.9, 1.25), height, length * rng:NextNumber(0.75, 1.15))
	elseif shape == Enum.PartType.Cylinder then
		mark.Size = Vector3.new(width * rng:NextNumber(0.8, 1.15), height, length * rng:NextNumber(0.8, 1.25))
	else
		mark.Size = Vector3.new(width, height, length)
	end
	mark.Color = jitterColor(effect.baseColor, effect.colorJitter)
	mark.Material = Enum.Material.SmoothPlastic
	mark.Transparency = effect.transparency + rng:NextNumber(-0.04, 0.08)
	mark.Anchored = true
	mark.CanCollide = false
	mark.CanTouch = false
	mark.CanQuery = false
	mark.TopSurface = Enum.SurfaceType.Smooth
	mark.BottomSurface = Enum.SurfaceType.Smooth
	mark.CFrame = groundCFrame(markPosition, moveDirection) * CFrame.Angles(0, rng:NextNumber(-0.45, 0.45), 0)
	mark.Parent = workspace

	task.delay(MARK_LIFETIME + rng:NextNumber(0, 0.25), function()
		if not mark.Parent then
			return
		end

		local tween = TweenService:Create(
			mark,
			TweenInfo.new(FADE_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{
				Size = Vector3.new(mark.Size.X * 0.28, 0.01, mark.Size.Z * 0.28),
				Transparency = 1,
			}
		)
		tween:Play()
		tween.Completed:Once(function()
			if mark.Parent then
				mark:Destroy()
			end
		end)
	end)
end

local function trackEnemy(model)
	if trackedEnemies[model] or not isEnemyModel(model) then
		return
	end

	local root = getEnemyRoot(model)
	trackedEnemies[model] = {
		lastPosition = root.Position,
		elapsed = rng:NextNumber(0, SPAWN_INTERVAL),
	}
end

for _, descendant in ipairs(workspace:GetDescendants()) do
	if descendant:IsA("Model") then
		trackEnemy(descendant)
	end
end

workspace.DescendantAdded:Connect(function(descendant)
	if descendant:IsA("Model") then
		task.defer(trackEnemy, descendant)
	elseif descendant.Name == "HumanoidRootPart" or descendant.Name == "Health" or descendant.Name == "Speed" then
		task.defer(function()
			local enemy = findEnemyModel(descendant)
			if enemy then
				trackEnemy(enemy)
			end
		end)
	end
end)

RunService.Heartbeat:Connect(function(dt)
	scanElapsed += dt
	if scanElapsed >= RESCAN_INTERVAL then
		scanElapsed = 0
		for _, descendant in ipairs(workspace:GetDescendants()) do
			if descendant:IsA("Model") then
				trackEnemy(descendant)
			end
		end
	end

	for enemy, state in pairs(trackedEnemies) do
		local root = enemy.Parent and getEnemyRoot(enemy)
		if not root then
			trackedEnemies[enemy] = nil
			continue
		end

		local currentPosition = root.Position
		local delta = currentPosition - state.lastPosition
		local horizontalDelta = Vector3.new(delta.X, 0, delta.Z)
		state.lastPosition = currentPosition
		state.elapsed += dt

		if state.elapsed < SPAWN_INTERVAL then
			continue
		end

		local hasActiveEffect = false
		for _, effect in pairs(EFFECTS) do
			if enemy:GetAttribute(effect.attribute) == true then
				hasActiveEffect = true
				break
			end
		end

		if not hasActiveEffect then
			continue
		end

		state.elapsed = 0
		local moveDirection = horizontalDelta.Magnitude >= MIN_MOVE_DISTANCE and horizontalDelta.Unit or root.CFrame.LookVector
		moveDirection = Vector3.new(moveDirection.X, 0, moveDirection.Z)
		if moveDirection.Magnitude < 0.01 then
			moveDirection = Vector3.zAxis
		else
			moveDirection = moveDirection.Unit
		end

		for _, effect in pairs(EFFECTS) do
			if enemy:GetAttribute(effect.attribute) == true then
				for _ = 1, rng:NextInteger(effect.countMin, effect.countMax) do
					spawnGroundMark(currentPosition, moveDirection, effect)
				end
			end
		end
	end
end)
