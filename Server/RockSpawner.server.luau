local TESTING = false
local SPAWN_CHANCE = TESTING and 1 or 0.45
local SPAWN_INTERVAL = 5
local CLICK_SOUNDS = {
	"rbxassetid://72797694681662",
	"rbxassetid://105231614307736",
	"rbxassetid://85927631205029",
	"rbxassetid://118334524990603",
	"rbxassetid://72245862311564"
}

local function playClickSound(part)
	local sound = Instance.new("Sound")
	sound.SoundId = CLICK_SOUNDS[math.random(1, #CLICK_SOUNDS)]
	sound.Volume = 1
	sound.Parent = part
	sound:Play()
	game:GetService("Debris"):AddItem(sound, 3)
end

local rocksFolder = game.ReplicatedStorage:WaitForChild("Rocks")
local spawnFolder = workspace:WaitForChild("RockSpawnParts")
local ResourceMiningService = require(script.Parent:WaitForChild("ResourceMiningService"))

local rockTemplates = {}
for _, v in rocksFolder:GetChildren() do
	if v:IsA("BasePart") then table.insert(rockTemplates, v) end
end

local amountGained = rocksFolder:FindFirstChild("AmountGained")
local baseAmount = amountGained and amountGained.Value or 1

local occupiedSpawns = {}

local function getDamage(player)
	local strength = player:GetAttribute("PickaxeStrength") or 0
	return 1 + (strength * 0.5)
end

local function shakeModel(part)
	local original = part.CFrame
	task.spawn(function()
		for i = 1, 6 do
			local offset = Vector3.new(math.random(-1,1) * 0.15, 0, math.random(-1,1) * 0.15)
			part.CFrame = original + offset
			task.wait(0.04)
		end
		part.CFrame = original
	end)
end

local function popIn(part)
	local originalSize = part.Size
	part.Size = Vector3.new(0.01, 0.01, 0.01)
	local overshoot = originalSize * 1.15
	local steps = 20

	task.spawn(function()
		for i = 1, steps do
			local t = i / steps
			part.Size = Vector3.new(0.01, 0.01, 0.01):Lerp(overshoot, t)
			task.wait(0.3 / steps)
		end
		for i = 1, steps do
			local t = i / steps
			part.Size = overshoot:Lerp(originalSize, t)
			task.wait(0.15 / steps)
		end
		part.Size = originalSize
	end)
end

local function popOut(part, spawnPart)
	local originalSize = part.Size
	local overshoot = originalSize * 1.2
	local steps = 20

	task.spawn(function()
		for i = 1, steps do
			local t = i / steps
			part.Size = originalSize:Lerp(overshoot, t)
			task.wait(0.1 / steps)
		end
		for i = 1, steps do
			local t = i / steps
			part.Size = overshoot:Lerp(Vector3.new(0.01, 0.01, 0.01), t)
			task.wait(0.15 / steps)
		end
		occupiedSpawns[spawnPart] = nil
		part:Destroy()
	end)
end

local function createHitsLabel(part, currentHealth, maxHealth)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "HitsLabel"
	billboard.Size = UDim2.new(0, 100, 0, 40)
	billboard.StudsOffset = Vector3.new(0, 3, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 25
	billboard.Parent = part

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = currentHealth .. "/" .. maxHealth
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextScaled = true
	label.FontFace = Font.new("rbxassetid://12187371840")
	label.TextTransparency = 1
	label.Parent = billboard

	return label
end

local function fadeLabel(label, targetTransparency, duration)
	task.spawn(function()
		local steps = 20
		local startTransparency = label.TextTransparency
		for i = 1, steps do
			if not label or not label.Parent then return end
			local t = i / steps
			label.TextTransparency = startTransparency + (targetTransparency - startTransparency) * t
			task.wait(duration / steps)
		end
		if label and label.Parent then
			label.TextTransparency = targetTransparency
		end
	end)
end

local function spawnRock(spawnPart)
	local template = rockTemplates[math.random(1, #rockTemplates)]
	local rock = template:Clone()
	local healthVal = rocksFolder:FindFirstChild("RockHealth")
	local maxHealth = healthVal and healthVal.Value or 3
	local health = maxHealth
	rock.Anchored = true
	rock.CFrame = spawnPart.CFrame
	rock.Parent = workspace
	occupiedSpawns[spawnPart] = rock

	local clickDetector = Instance.new("ClickDetector")
	clickDetector.MaxActivationDistance = 15
	clickDetector.Parent = rock

	local hitsLabel = createHitsLabel(rock, health, maxHealth)
	local hasBeenMined = false
	local playersInRange = {}

	popIn(rock)

	clickDetector.MouseHoverEnter:Connect(function(player)
		playersInRange[player] = true
		if hasBeenMined then
			fadeLabel(hitsLabel, 0, 0.3)
		end
	end)

	clickDetector.MouseHoverLeave:Connect(function(player)
		playersInRange[player] = nil
		local anyInRange = next(playersInRange) ~= nil
		if not anyInRange then
			fadeLabel(hitsLabel, 1, 0.3)
		end
	end)

	local animating = false

	ResourceMiningService:Register(rock, {
		resourceType = "stone",
		amount = baseAmount,
		maxHealth = maxHealth,
		primaryPart = rock,
		playAnimationOnMine = true,
		onFirstMined = function(currentHealth, resourceMaxHealth)
			if not hasBeenMined then
				hasBeenMined = true
				hitsLabel.Text = math.ceil(currentHealth) .. "/" .. resourceMaxHealth
				fadeLabel(hitsLabel, 0, 0.2)
			end
		end,
		onHit = function()
			playClickSound(rock)
		end,
		onHealthChanged = function(currentHealth, resourceMaxHealth)
			hitsLabel.Text = math.ceil(currentHealth) .. "/" .. resourceMaxHealth
			shakeModel(rock)
		end,
		onDepleted = function()
			local billboard = hitsLabel.Parent
			if billboard then billboard:Destroy() end
			if clickDetector.Parent then
				clickDetector:Destroy()
			end
			popOut(rock, spawnPart)
		end,
	})

	clickDetector.MouseClick:Connect(function(player)
		if animating then return end
		if not ResourceMiningService:PlayerHasPickaxeEquipped(player) then
			return
		end
		animating = true

		local damage = getDamage(player)
		ResourceMiningService:Mine(rock, player, damage, { manual = true })
		if rock.Parent then
			task.wait(0.04 * 6)
		end

		animating = false
	end)
end

task.spawn(function()
	while true do
		task.wait(SPAWN_INTERVAL)
		for _, spawnPart in spawnFolder:GetChildren() do
			if not occupiedSpawns[spawnPart] then
				if math.random() <= SPAWN_CHANCE then
					spawnRock(spawnPart)
				end
			end
		end
	end
end)
