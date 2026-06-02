local Players = game:GetService("Players")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local rewardRemote = ReplicatedStorage:WaitForChild("RoundRewardBurstRemote")

local IMAGE_ID = "rbxassetid://88187690052452"
local COLLECT_SOUND_ID = "rbxassetid://112577669532629"
local BURST_RADIUS = 9
local START_HEIGHT_MIN = 3
local START_HEIGHT_MAX = 9
local COIN_SIZE = Vector3.new(0.18, 0.18, 0.18)
local BILLBOARD_SIZE = UDim2.fromOffset(54, 54)
local MIN_COINS = 16
local MAX_COINS = 46
local FLY_TIME_MIN = 0.58
local FLY_TIME_MAX = 1.05

local activeParts = {}

local function getRoot()
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") or nil
end

local function getCoinCount(cashAmount)
	local amount = tonumber(cashAmount) or 0
	return math.clamp(MIN_COINS + math.floor(amount / 140), MIN_COINS, MAX_COINS)
end

local function makeRewardPart(startPosition)
	local part = Instance.new("Part")
	part.Name = "RoundRewardCashBurst"
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Transparency = 1
	part.Size = COIN_SIZE
	part.CFrame = CFrame.new(startPosition)
	part.Parent = workspace

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "RewardBillboard"
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.MaxDistance = 100000
	billboard.Size = BILLBOARD_SIZE
	billboard.Parent = part

	local image = Instance.new("ImageLabel")
	image.Name = "CashIcon"
	image.BackgroundTransparency = 1
	image.Image = IMAGE_ID
	image.ImageTransparency = 0
	image.ScaleType = Enum.ScaleType.Fit
	image.Size = UDim2.fromScale(1, 1)
	image.Parent = billboard

	table.insert(activeParts, part)
	return part, image
end

local function cleanupPart(part)
	for i = #activeParts, 1, -1 do
		if activeParts[i] == part then
			table.remove(activeParts, i)
			break
		end
	end

	if part and part.Parent then
		part:Destroy()
	end
end

local function playCollectSound(position)
	local soundPart = Instance.new("Part")
	soundPart.Name = "RoundRewardCollectSound"
	soundPart.Anchored = true
	soundPart.CanCollide = false
	soundPart.CanTouch = false
	soundPart.CanQuery = false
	soundPart.Transparency = 1
	soundPart.Size = Vector3.new(0.1, 0.1, 0.1)
	soundPart.Position = position
	soundPart.Parent = workspace

	local sound = Instance.new("Sound")
	sound.SoundId = COLLECT_SOUND_ID
	sound.Volume = 0.22
	sound.PlaybackSpeed = 0.94 + (math.random() * 0.16)
	sound.RollOffMaxDistance = 55
	sound.Parent = soundPart
	sound:Play()

	Debris:AddItem(soundPart, 3)
end

local function spawnOne(root, index, count)
	local angle = (math.pi * 2 * index / count) + math.random() * 0.45
	local radius = math.random() * BURST_RADIUS
	local startPosition = root.Position
		+ Vector3.new(math.cos(angle) * radius, math.random(START_HEIGHT_MIN * 100, START_HEIGHT_MAX * 100) / 100, math.sin(angle) * radius)

	local part, image = makeRewardPart(startPosition)
	local startTime = os.clock()
	local flyTime = FLY_TIME_MIN + (math.random() * (FLY_TIME_MAX - FLY_TIME_MIN))
	local swirl = (math.random() * 2 - 1) * 5
	local lift = Vector3.new(0, math.random(3, 7), 0)
	local start = startPosition
	local connection

	connection = RunService.RenderStepped:Connect(function()
		if not part.Parent then
			connection:Disconnect()
			return
		end

		local currentRoot = getRoot()
		if not currentRoot then
			connection:Disconnect()
			cleanupPart(part)
			return
		end

		local alpha = math.clamp((os.clock() - startTime) / flyTime, 0, 1)
		local eased = 1 - ((1 - alpha) ^ 3)
		local target = currentRoot.Position + Vector3.new(0, 1.6, 0)
		local arc = math.sin(alpha * math.pi) * lift
		local tangent = Vector3.new(-math.sin(angle), 0, math.cos(angle)) * swirl * math.sin(alpha * math.pi)
		part.Position = start:Lerp(target, eased) + arc + tangent
		part.CFrame *= CFrame.Angles(0, math.rad(10 + (alpha * 28)), 0)

		local billboard = part:FindFirstChildOfClass("BillboardGui")
		if billboard then
			local scale = 0.55 + (math.sin(alpha * math.pi) * 0.65)
			billboard.Size = UDim2.fromOffset(BILLBOARD_SIZE.X.Offset * scale, BILLBOARD_SIZE.Y.Offset * scale)
		end

		if alpha > 0.72 then
			image.ImageTransparency = math.clamp((alpha - 0.72) / 0.28, 0, 1)
		end

		if alpha >= 1 then
			connection:Disconnect()
			playCollectSound(part.Position)
			cleanupPart(part)
		end
	end)
end

local function spawnRewardBurst(cashAmount)
	local root = getRoot()
	if not root then
		return
	end

	local count = getCoinCount(cashAmount)
	for i = 1, count do
		task.delay((i - 1) * 0.018, function()
			local currentRoot = getRoot()
			if currentRoot then
				spawnOne(currentRoot, i, count)
			end
		end)
	end
end

rewardRemote.OnClientEvent:Connect(spawnRewardBurst)

player.CharacterRemoving:Connect(function()
	for i = #activeParts, 1, -1 do
		cleanupPart(activeParts[i])
	end
end)
