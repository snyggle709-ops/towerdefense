local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContentProvider = game:GetService("ContentProvider")
local Debris = game:GetService("Debris")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local remote = ReplicatedStorage:WaitForChild("MiningParticleRemote")
local completeSoundRemote = ReplicatedStorage:WaitForChild("MiningCompleteSoundRemote")
local rng = Random.new()

local PARTICLES_PER_HIT = 4
local MIN_SIZE = 0.25
local MAX_SIZE = 0.56
local SETTLE_TIME = 0.75
local GROUND_WAIT_TIME = 0.005
local SHRINK_TIME = 0.28
local COMPLETE_CHUNKS = 14
local LANDING_SOUNDS = {
	rock = "rbxassetid://90758965952873",
	stone = "rbxassetid://90758965952873",
	crystal = "rbxassetid://115558954454810",
	metal = "rbxassetid://71433098401419",
}
local COMPLETE_SOUNDS = {
	rock = "rbxassetid://137779155487969",
	stone = "rbxassetid://137779155487969",
	crystal = "rbxassetid://86353658195966",
	metal = "rbxassetid://93690466892687",
}
local MINING_CLICK_SOUNDS = {
	"rbxassetid://72797694681662",
	"rbxassetid://105231614307736",
	"rbxassetid://85927631205029",
	"rbxassetid://118334524990603",
	"rbxassetid://72245862311564",
}
local COMPLETE_COLORS = {
	rock = Color3.fromRGB(105, 105, 105),
	stone = Color3.fromRGB(105, 105, 105),
	crystal = Color3.fromRGB(205, 80, 255),
	metal = Color3.fromRGB(58, 58, 94),
}
local preloadSounds = {}

for resourceType, soundId in pairs(LANDING_SOUNDS) do
	local sound = Instance.new("Sound")
	sound.Name = "Preload" .. resourceType .. "ShardLanding"
	sound.SoundId = soundId
	sound.Volume = 0
	sound.Parent = SoundService
	table.insert(preloadSounds, sound)
end
for resourceType, soundId in pairs(COMPLETE_SOUNDS) do
	local sound = Instance.new("Sound")
	sound.Name = "Preload" .. resourceType .. "MiningComplete"
	sound.SoundId = soundId
	sound.Volume = 0
	sound.Parent = SoundService
	table.insert(preloadSounds, sound)
end
for index, soundId in ipairs(MINING_CLICK_SOUNDS) do
	local sound = Instance.new("Sound")
	sound.Name = "PreloadMiningClick" .. tostring(index)
	sound.SoundId = soundId
	sound.Volume = 0
	sound.Parent = SoundService
	table.insert(preloadSounds, sound)
end

task.spawn(function()
	pcall(function()
		ContentProvider:PreloadAsync(preloadSounds)
	end)
end)

local function randomUnitHorizontal()
	local angle = rng:NextNumber(0, math.pi * 2)
	return Vector3.new(math.cos(angle), 0, math.sin(angle))
end

local function getResourceColor(resourceType)
	return COMPLETE_COLORS[resourceType] or Color3.fromRGB(105, 105, 105)
end

local function getResourceMaterial(resourceType)
	if resourceType == "crystal" then
		return Enum.Material.Neon
	end

	if resourceType == "metal" then
		return Enum.Material.Metal
	end

	return Enum.Material.SmoothPlastic
end

local function playLandingSound(position, resourceType)
	local soundId = LANDING_SOUNDS[resourceType]
	if not soundId then
		return
	end

	local attachment = Instance.new("Attachment")
	attachment.Name = "MiningShardLandingSound"
	attachment.WorldPosition = position
	attachment.Parent = workspace.Terrain

	local sound = Instance.new("Sound")
	sound.Name = "MiningShardLanding"
	sound.SoundId = soundId
	sound.Volume = rng:NextNumber(1.58, 2.58)
	sound.PlaybackSpeed = rng:NextNumber(0.88, 1.12)
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = 4
	sound.RollOffMaxDistance = 38
	sound.Parent = attachment
	sound:Play()
	sound.Ended:Once(function()
		if attachment.Parent then
			attachment:Destroy()
		end
	end)
	Debris:AddItem(attachment, 5)
end

local function playCompleteSound(position, resourceType)
	local soundId = COMPLETE_SOUNDS[resourceType]
	if not soundId then
		return
	end

	local attachment = Instance.new("Attachment")
	attachment.Name = "MiningCompleteSound"
	attachment.WorldPosition = position
	attachment.Parent = workspace.Terrain

	local sound = Instance.new("Sound")
	sound.Name = "MiningComplete"
	sound.SoundId = soundId
	sound.Volume = 1.8
	sound.PlaybackSpeed = rng:NextNumber(0.96, 1.04)
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = 6
	sound.RollOffMaxDistance = 70
	sound.Parent = attachment
	sound:Play()
	sound.Ended:Once(function()
		if attachment.Parent then
			attachment:Destroy()
		end
	end)
	Debris:AddItem(attachment, 8)
end

local function spawnCompletionFlash(origin, color, resourceType)
	local flash = Instance.new("Part")
	flash.Name = "MiningCompleteFlash"
	flash.Shape = Enum.PartType.Ball
	flash.Size = Vector3.new(0.35, 0.35, 0.35)
	flash.Color = color
	flash.Material = resourceType == "crystal" and Enum.Material.Neon or Enum.Material.SmoothPlastic
	flash.Transparency = resourceType == "crystal" and 0.1 or 0.35
	flash.Anchored = true
	flash.CanCollide = false
	flash.CanQuery = false
	flash.CanTouch = false
	flash.CastShadow = false
	flash.CFrame = CFrame.new(origin)
	flash.Parent = workspace

	local scale = resourceType == "crystal" and 7 or 5
	local tween = TweenService:Create(
		flash,
		TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{
			Size = Vector3.new(scale, scale, scale),
			Transparency = 1,
		}
	)
	tween:Play()
	tween.Completed:Once(function()
		if flash.Parent then
			flash:Destroy()
		end
	end)
	Debris:AddItem(flash, 1)
end

local function createCompletionChunk(resourceType)
	local roll = rng:NextNumber()
	local chunk
	if roll < 0.2 then
		chunk = Instance.new("WedgePart")
	elseif roll < 0.42 then
		chunk = Instance.new("Part")
		chunk.Shape = Enum.PartType.Ball
	else
		chunk = Instance.new("Part")
	end

	chunk.Name = "MiningCompleteChunk"
	chunk.Material = getResourceMaterial(resourceType)
	chunk.TopSurface = Enum.SurfaceType.Smooth
	chunk.BottomSurface = Enum.SurfaceType.Smooth
	chunk.CanQuery = false
	chunk.CanTouch = false
	chunk.CanCollide = false
	chunk.CastShadow = false
	return chunk
end

local function spawnCompletionChunk(origin, color, resourceType)
	local chunk = createCompletionChunk(resourceType)
	local size = rng:NextNumber(0.5, 1.15)
	local flatness = rng:NextNumber(0.55, 1.35)
	local direction = randomUnitHorizontal()
	local launchOrigin = origin + (direction * rng:NextNumber(0.2, 1.0)) + Vector3.new(0, rng:NextNumber(0.15, 1.1), 0)

	chunk.Size = Vector3.new(size * rng:NextNumber(0.65, 1.25), size * flatness, size * rng:NextNumber(0.65, 1.25))
	chunk.Color = color:Lerp(Color3.new(1, 1, 1), rng:NextNumber(0, resourceType == "crystal" and 0.25 or 0.08))
	chunk.Anchored = true
	chunk.CFrame = CFrame.new(launchOrigin)
		* CFrame.Angles(rng:NextNumber(-math.pi, math.pi), rng:NextNumber(-math.pi, math.pi), rng:NextNumber(-math.pi, math.pi))
	chunk.Parent = workspace

	local travel = (direction * rng:NextNumber(4, 9)) + Vector3.new(0, rng:NextNumber(2.5, 6.5), 0)
	local peak = chunk.CFrame + travel
	local settle = peak + Vector3.new(rng:NextNumber(-1.2, 1.2), -rng:NextNumber(1.5, 4.5), rng:NextNumber(-1.2, 1.2))
	local peakTime = rng:NextNumber(0.13, 0.2)
	local settleTime = rng:NextNumber(0.24, 0.38)

	local peakTween = TweenService:Create(
		chunk,
		TweenInfo.new(peakTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{
			CFrame = peak * CFrame.Angles(rng:NextNumber(-2, 2), rng:NextNumber(-2, 2), rng:NextNumber(-2, 2)),
		}
	)
	peakTween:Play()
	peakTween.Completed:Once(function()
		if not chunk.Parent then
			return
		end

		local settleTween = TweenService:Create(
			chunk,
			TweenInfo.new(settleTime, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{
				CFrame = settle * CFrame.Angles(rng:NextNumber(-3, 3), rng:NextNumber(-3, 3), rng:NextNumber(-3, 3)),
			}
		)
		settleTween:Play()
		settleTween.Completed:Once(function()
			if not chunk.Parent then
				return
			end

			local shrinkTween = TweenService:Create(
				chunk,
				TweenInfo.new(rng:NextNumber(0.18, 0.32), Enum.EasingStyle.Back, Enum.EasingDirection.In),
				{
					Size = Vector3.new(0.01, 0.01, 0.01),
					Transparency = 1,
				}
			)
			shrinkTween:Play()
			shrinkTween.Completed:Once(function()
				if chunk.Parent then
					chunk:Destroy()
				end
			end)
		end)
	end)

	Debris:AddItem(chunk, 2)
end

local function playCompletionVisual(position, resourceType)
	local color = getResourceColor(resourceType)
	spawnCompletionFlash(position + Vector3.new(0, 0.75, 0), color, resourceType)

	for _ = 1, COMPLETE_CHUNKS do
		spawnCompletionChunk(position, color, resourceType)
	end
end

local function spawnMiningCube(origin, color, resourceType)
	local size = rng:NextNumber(MIN_SIZE, MAX_SIZE)
	local burstDirection = randomUnitHorizontal()
	local startHeightOffset = rng:NextNumber(0.25, 0.9)
	local upwardSpeed = rng:NextNumber(10, 18)
	local cube = Instance.new("Part")
	cube.Name = "MiningCubeParticle"
	cube.Size = Vector3.new(size, size, size)
	cube.Color = color
	cube.Material = resourceType == "crystal" and Enum.Material.Neon or Enum.Material.SmoothPlastic
	cube.TopSurface = Enum.SurfaceType.Smooth
	cube.BottomSurface = Enum.SurfaceType.Smooth
	cube.CanQuery = false
	cube.CanTouch = true
	cube.CanCollide = true
	cube.Anchored = true
	cube.CFrame = CFrame.new(origin + (burstDirection * rng:NextNumber(0.2, 0.65)) + Vector3.new(0, startHeightOffset, 0))
		* CFrame.Angles(rng:NextNumber(-math.pi, math.pi), rng:NextNumber(-math.pi, math.pi), rng:NextNumber(-math.pi, math.pi))
	cube.Parent = workspace

	cube.Anchored = false
	cube:ApplyImpulse(((burstDirection * rng:NextNumber(16, 28)) + Vector3.new(0, upwardSpeed, 0)) * cube.AssemblyMass)
	cube.AssemblyAngularVelocity = Vector3.new(rng:NextNumber(-8, 8), rng:NextNumber(-8, 8), rng:NextNumber(-8, 8))

	task.delay(SETTLE_TIME, function()
		if not cube.Parent then
			return
		end

		cube.Anchored = true
		cube.CanCollide = false

		task.delay(GROUND_WAIT_TIME + rng:NextNumber(0, 0.35), function()
			if not cube.Parent then
				return
			end

			playLandingSound(cube.Position, resourceType)
			local tween = TweenService:Create(
				cube,
				TweenInfo.new(SHRINK_TIME, Enum.EasingStyle.Back, Enum.EasingDirection.In),
				{
					Size = Vector3.new(0.01, 0.01, 0.01),
					Transparency = 1,
				}
			)
			tween:Play()
			tween.Completed:Once(function()
				if cube.Parent then
					cube:Destroy()
				end
			end)
		end)
	end)
end

remote.OnClientEvent:Connect(function(origin, color, resourceType)
	if typeof(origin) ~= "Vector3" or typeof(color) ~= "Color3" then
		return
	end

	for _ = 1, PARTICLES_PER_HIT do
		spawnMiningCube(origin, color, resourceType)
	end
end)

completeSoundRemote.OnClientEvent:Connect(function(position, resourceType)
	if typeof(position) ~= "Vector3" then
		return
	end

	playCompletionVisual(position, resourceType)
	playCompleteSound(position, resourceType)
end)
