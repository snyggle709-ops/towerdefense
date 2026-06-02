local Players = game:GetService("Players")
local ContentProvider = game:GetService("ContentProvider")
local SoundService = game:GetService("SoundService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local EQUIP_ANIMATION_ID = "rbxassetid://89286834567423"
local PANEL_IMAGE_ID = "rbxassetid://107910849622465"
local PICKAXE_ICON_ID = "rbxassetid://127187330242421"
local EQUIP_SOUND_IDS = {
	"rbxassetid://121922597372332",
	"rbxassetid://91841354857551",
}
local SLOT_KEY_TEXT = "Q"
local BASE_VIEWPORT_HEIGHT = 720
local BASE_SLOT_SIZE = 125
local BASE_KEY_BADGE_SIZE = 23
local MIN_VIEWPORT_SCALE = 0.85
local MAX_VIEWPORT_SCALE = 1.75
local activeEquipTrack = nil
local toggleBusy = false
local visualEquipped = false
local slotGui = nil
local slotButton = nil
local slotScale = nil
local icon = nil
local keyBadge = nil
local keyText = nil
local selectedGlow = nil
local selectedGlowTween = nil
local selectedStrokeTween = nil
local idleBobTween = nil
local equipSoundPool = {}
local togglePickaxe
local updateHotbarState
local applyResponsiveLayout

local function ensureEquipSounds()
	if #equipSoundPool > 0 then
		return
	end

	for index, soundId in ipairs(EQUIP_SOUND_IDS) do
		local sound = Instance.new("Sound")
		sound.Name = "PickaxeEquipSound" .. tostring(index)
		sound.SoundId = soundId
		sound.Volume = 0.65
		sound.Parent = SoundService
		equipSoundPool[index] = sound
	end

	task.spawn(function()
		pcall(function()
			ContentProvider:PreloadAsync(equipSoundPool)
		end)
	end)
end

local function playEquipSounds(lowerPitch)
	ensureEquipSounds()

	for _, sound in ipairs(equipSoundPool) do
		sound:Stop()
		sound.TimePosition = 0
		sound.PlaybackSpeed = lowerPitch and 0.72 or 1
		sound:Play()
	end
end

local function setSelectedGlowVisible(visible, duration)
	if not selectedGlow then
		return
	end

	if selectedGlowTween then
		selectedGlowTween:Cancel()
		selectedGlowTween = nil
	end
	if selectedStrokeTween then
		selectedStrokeTween:Cancel()
		selectedStrokeTween = nil
	end

	local tweenInfo = TweenInfo.new(duration or 0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	selectedGlowTween = TweenService:Create(selectedGlow, tweenInfo, {
		BackgroundTransparency = visible and 0.72 or 1,
	})
	selectedGlowTween:Play()

	local stroke = selectedGlow:FindFirstChildOfClass("UIStroke")
	if stroke then
		selectedStrokeTween = TweenService:Create(stroke, tweenInfo, {
			Transparency = visible and 0.05 or 1,
		})
		selectedStrokeTween:Play()
	end
end

local function disableDefaultBackpack()
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	end)
end

local function getCharacter()
	return player.Character or player.CharacterAdded:Wait()
end

local function getPickaxe()
	local character = getCharacter()
	local equipped = character:FindFirstChild("Pickaxe")
	if equipped and equipped:IsA("Tool") then
		return equipped, true
	end

	local backpack = player:FindFirstChildOfClass("Backpack")
	local stored = backpack and backpack:FindFirstChild("Pickaxe")
	if stored and stored:IsA("Tool") then
		return stored, false
	end

	return nil, false
end

local function createCorner(parent, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = parent
	return corner
end

local function createStroke(parent, color, thickness, transparency)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = thickness
	stroke.Transparency = transparency
	stroke.Parent = parent
	return stroke
end

local function getViewportScale()
	local camera = workspace.CurrentCamera
	local viewportHeight = camera and camera.ViewportSize.Y or BASE_VIEWPORT_HEIGHT
	return math.clamp(viewportHeight / BASE_VIEWPORT_HEIGHT, MIN_VIEWPORT_SCALE, MAX_VIEWPORT_SCALE)
end

applyResponsiveLayout = function()
	if not slotButton then
		return
	end

	local viewportScale = getViewportScale()
	local slotSize = math.floor(BASE_SLOT_SIZE * viewportScale + 0.5)
	local badgeSize = math.floor(BASE_KEY_BADGE_SIZE * viewportScale + 0.5)

	slotButton.Size = UDim2.fromOffset(slotSize, slotSize)

	if keyBadge then
		keyBadge.Size = UDim2.fromOffset(badgeSize, badgeSize)
		local stroke = keyBadge:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Thickness = math.max(1, 1.5 * viewportScale)
		end
	end

	if selectedGlow then
		local stroke = selectedGlow:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Thickness = math.max(1, 2 * viewportScale)
		end
	end
end

local function ensureHotbarGui()
	if slotGui and slotGui.Parent then
		return
	end

	slotGui = Instance.new("ScreenGui")
	slotGui.Name = "CustomInventory"
	slotGui.ResetOnSpawn = false
	slotGui.IgnoreGuiInset = true
	slotGui.DisplayOrder = 70
	slotGui.Parent = player:WaitForChild("PlayerGui")

	slotButton = Instance.new("ImageButton")
	slotButton.Name = "PickaxeSlot"
	slotButton.AnchorPoint = Vector2.new(0.5, 1)
	slotButton.Position = UDim2.fromScale(0.5, 1.018)
	slotButton.Size = UDim2.fromOffset(83, 83)
	slotButton.BackgroundTransparency = 1
	slotButton.Image = PANEL_IMAGE_ID
	slotButton.AutoButtonColor = false
	slotButton.Parent = slotGui

	slotScale = Instance.new("UIScale")
	slotScale.Scale = 1
	slotScale.Parent = slotButton

	selectedGlow = Instance.new("Frame")
	selectedGlow.Name = "SelectedGlow"
	selectedGlow.AnchorPoint = Vector2.new(0.5, 0.5)
	selectedGlow.Position = UDim2.fromScale(0.5, 0.5)
	selectedGlow.Size = UDim2.fromScale(0.794, 0.794)
	selectedGlow.BackgroundColor3 = Color3.fromRGB(130, 220, 255)
	selectedGlow.BackgroundTransparency = 1
	selectedGlow.ZIndex = slotButton.ZIndex - 1
	selectedGlow.Parent = slotButton
	createCorner(selectedGlow, 18)
	createStroke(selectedGlow, Color3.fromRGB(215, 250, 255), 2, 1)

	icon = Instance.new("ImageLabel")
	icon.Name = "PickaxeIcon"
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Position = UDim2.fromScale(0.5, 0.505)
	icon.Size = UDim2.fromScale(0.5, 0.5)
	icon.BackgroundTransparency = 1
	icon.Image = PICKAXE_ICON_ID
	icon.Parent = slotButton

	keyBadge = Instance.new("Frame")
	keyBadge.Name = "KeyBadge"
	keyBadge.AnchorPoint = Vector2.new(1, 0)
	keyBadge.Position = UDim2.fromScale(0.95, 0.03)
	keyBadge.Size = UDim2.fromOffset(15, 15)
	keyBadge.BackgroundColor3 = Color3.fromRGB(16, 18, 26)
	keyBadge.BackgroundTransparency = 0.08
	keyBadge.Parent = slotButton
	createCorner(keyBadge, 100)
	createStroke(keyBadge, Color3.fromRGB(225, 245, 255), 1.5, 0.15)

	keyText = Instance.new("TextLabel")
	keyText.Name = "KeyText"
	keyText.Size = UDim2.fromScale(1, 1)
	keyText.BackgroundTransparency = 1
	keyText.Text = SLOT_KEY_TEXT
	keyText.TextColor3 = Color3.fromRGB(255, 255, 255)
	keyText.TextScaled = true
	keyText.FontFace = Font.new("rbxassetid://12187371840")
	keyText.Parent = keyBadge

	slotButton.MouseEnter:Connect(function()
		TweenService:Create(slotScale, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1.05 }):Play()
	end)

	slotButton.MouseLeave:Connect(function()
		local _, equipped = getPickaxe()
		TweenService:Create(slotScale, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = equipped and 1.12 or 1 }):Play()
	end)

	slotButton.MouseButton1Click:Connect(function()
		togglePickaxe()
	end)

	applyResponsiveLayout()

	local camera = workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(applyResponsiveLayout)
	end
end

local function stopActiveEquipTrack()
	if activeEquipTrack then
		activeEquipTrack:Stop(0.05)
		activeEquipTrack:Destroy()
		activeEquipTrack = nil
	end
end

local function loadEquipTrack(humanoid)
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		return nil
	end

	local animation = Instance.new("Animation")
	animation.AnimationId = EQUIP_ANIMATION_ID
	local track = animator:LoadAnimation(animation)
	animation:Destroy()
	track.Priority = Enum.AnimationPriority.Action
	track.Looped = false
	return track
end

local function playEquipAnimation(humanoid, reversed)
	stopActiveEquipTrack()

	local track = loadEquipTrack(humanoid)
	if not track then
		return 0
	end

	activeEquipTrack = track
	local length = track.Length > 0 and track.Length or 0.65

	if reversed then
		track:Play(0.05, 1, 1)
		track.TimePosition = length
		track:AdjustSpeed(-1)
	else
		track:Play(0.05, 1, 1)
	end

	task.delay(length + 0.08, function()
		if activeEquipTrack == track then
			stopActiveEquipTrack()
		end
	end)

	return length
end

updateHotbarState = function()
	ensureHotbarGui()

	local _, actualEquipped = getPickaxe()
	local equipped = actualEquipped
	if toggleBusy then
		equipped = visualEquipped
	end
	if idleBobTween then
		idleBobTween:Cancel()
		idleBobTween = nil
	end

	if equipped then
		TweenService:Create(slotScale, TweenInfo.new(0.26, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1.12 }):Play()
		TweenService:Create(slotButton, TweenInfo.new(0.26, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Position = UDim2.fromScale(0.5, 0.994),
			Rotation = -3,
		}):Play()
		TweenService:Create(icon, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Size = UDim2.fromScale(0.56, 0.56),
			Rotation = -10,
		}):Play()
		setSelectedGlowVisible(true, 0.16)
		idleBobTween = TweenService:Create(
			slotButton,
			TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ Position = UDim2.fromScale(0.5, 0.988) }
		)
		idleBobTween:Play()
	else
		TweenService:Create(slotScale, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		TweenService:Create(slotButton, TweenInfo.new(0.24, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Position = UDim2.fromScale(0.5, 1.018),
			Rotation = 0,
		}):Play()
		TweenService:Create(icon, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = UDim2.fromScale(0.5, 0.5),
			Rotation = 0,
		}):Play()
		setSelectedGlowVisible(false, 0.12)
	end
end

togglePickaxe = function()
	if toggleBusy then
		return
	end

	local tool, equipped = getPickaxe()
	if not tool then
		return
	end

	local character = getCharacter()
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	if equipped then
		toggleBusy = true
		visualEquipped = false
		setSelectedGlowVisible(false, 0.1)
		updateHotbarState()
		playEquipSounds(true)
		local length = playEquipAnimation(humanoid, true)
		task.delay(math.max(0.05, length * 0.85), function()
			if humanoid.Parent then
				humanoid:UnequipTools()
			end
			updateHotbarState()
			toggleBusy = false
		end)
	else
		toggleBusy = true
		visualEquipped = true
		playEquipSounds(false)
		humanoid:EquipTool(tool)
		updateHotbarState()
		local length = playEquipAnimation(humanoid, false)
		task.delay(math.max(0.05, length * 0.45), function()
			toggleBusy = false
		end)
	end
end

disableDefaultBackpack()
ensureEquipSounds()
ensureHotbarGui()
updateHotbarState()
task.delay(1, disableDefaultBackpack)

player.CharacterAdded:Connect(function()
	stopActiveEquipTrack()
	toggleBusy = false
	task.delay(0.2, disableDefaultBackpack)
	task.delay(0.25, updateHotbarState)
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed or input.KeyCode ~= Enum.KeyCode.Q then
		return
	end

	togglePickaxe()
end)
