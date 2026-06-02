local TESTING = false
local SPAWN_CHANCE = TESTING and 1 or 0.25
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

local crystalsFolder = game.ReplicatedStorage:WaitForChild("Crystals")
local spawnFolder = workspace:WaitForChild("CrystalSpawnParts")
local ResourceMiningService = require(script.Parent:WaitForChild("ResourceMiningService"))

local template = crystalsFolder:FindFirstChildOfClass("Model")
local healthVal = crystalsFolder:FindFirstChild("RockHealth")
local amountVal = crystalsFolder:FindFirstChild("AmountGained")
local baseHealth = healthVal and healthVal.Value or 3
local baseAmount = amountVal and amountVal.Value or 1

local occupiedSpawns = {}

local function getDamage(player)
	local strength = player:GetAttribute("PickaxeStrength") or 0
	return 1 + (strength * 0.5)
end

local function shakeParts(model)
	local originals = {}
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			originals[part] = part.CFrame
		end
	end
	task.spawn(function()
		for i = 1, 6 do
			local offset = Vector3.new(math.random(-1,1) * 0.15, 0, math.random(-1,1) * 0.15)
			for part, original in originals do
				part.CFrame = original + offset
			end
			task.wait(0.04)
		end
		for part, original in originals do
			part.CFrame = original
		end
	end)
end

local function popIn(model)
	local originalSizes = {}
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			originalSizes[part] = part.Size
			part.Size = Vector3.new(0.01, 0.01, 0.01)
		end
	end

	local steps = 20
	task.spawn(function()
		for i = 1, steps do
			local t = i / steps
			for part, originalSize in originalSizes do
				local overshoot = originalSize * 1.15
				part.Size = Vector3.new(0.01, 0.01, 0.01):Lerp(overshoot, t)
			end
			task.wait(0.3 / steps)
		end
		for i = 1, steps do
			local t = i / steps
			for part, originalSize in originalSizes do
				local overshoot = originalSize * 1.15
				part.Size = overshoot:Lerp(originalSize, t)
			end
			task.wait(0.15 / steps)
		end
		for part, originalSize in originalSizes do
			part.Size = originalSize
		end
	end)
end

local function popOut(model, spawnPart)
	local originalSizes = {}
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			originalSizes[part] = part.Size
		end
	end

	local steps = 20
	task.spawn(function()
		for i = 1, steps do
			local t = i / steps
			for part, originalSize in originalSizes do
				part.Size = originalSize:Lerp(originalSize * 1.2, t)
			end
			task.wait(0.1 / steps)
		end
		for i = 1, steps do
			local t = i / steps
			for part, originalSize in originalSizes do
				part.Size = (originalSize * 1.2):Lerp(Vector3.new(0.01, 0.01, 0.01), t)
			end
			task.wait(0.15 / steps)
		end
		occupiedSpawns[spawnPart] = nil
		model:Destroy()
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

local function spawnCrystal(spawnPart)
	local crystal = template:Clone()
	local maxHealth = baseHealth
	local health = maxHealth
	crystal:PivotTo(spawnPart.CFrame)
	crystal.Parent = workspace
	occupiedSpawns[spawnPart] = crystal

	local primaryPart = crystal.PrimaryPart or crystal:FindFirstChildOfClass("BasePart")
	local clickDetector = Instance.new("ClickDetector")
	clickDetector.MaxActivationDistance = 15
	clickDetector.Parent = primaryPart

	for _, part in crystal:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
		end
	end

	local hitsLabel = createHitsLabel(primaryPart, health, maxHealth)
	local hasBeenMined = false
	local playersInRange = {}

	popIn(crystal)

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

	ResourceMiningService:Register(crystal, {
		resourceType = "crystal",
		amount = baseAmount,
		maxHealth = maxHealth,
		primaryPart = primaryPart,
		playAnimationOnMine = true,
		onFirstMined = function(currentHealth, resourceMaxHealth)
			if not hasBeenMined then
				hasBeenMined = true
				hitsLabel.Text = math.ceil(currentHealth) .. "/" .. resourceMaxHealth
				fadeLabel(hitsLabel, 0, 0.2)
			end
		end,
		onHit = function()
			playClickSound(primaryPart)
		end,
		onHealthChanged = function(currentHealth, resourceMaxHealth)
			hitsLabel.Text = math.ceil(currentHealth) .. "/" .. resourceMaxHealth
			shakeParts(crystal)
		end,
		onDepleted = function()
			local billboard = hitsLabel.Parent
			if billboard then billboard:Destroy() end
			if clickDetector.Parent then
				clickDetector:Destroy()
			end
			popOut(crystal, spawnPart)
		end,
	})

	clickDetector.MouseClick:Connect(function(player)
		if animating then return end
		if not ResourceMiningService:PlayerHasPickaxeEquipped(player) then
			return
		end
		animating = true

		local damage = getDamage(player)
		ResourceMiningService:Mine(crystal, player, damage, { manual = true })
		if crystal.Parent then
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
					spawnCrystal(spawnPart)
				end
			end
		end
	end
end)
