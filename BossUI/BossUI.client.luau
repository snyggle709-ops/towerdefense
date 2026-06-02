local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local BossAnimRemote = ReplicatedStorage:WaitForChild("BossAnimRemote")
local gui = script.Parent
local frame = gui:WaitForChild("Frame")
local text1 = gui:FindFirstChild("Text1")
local text2 = gui:FindFirstChild("Text2")
local skull = gui:FindFirstChild("Skull")

local FRAME_IDS = {
	"rbxassetid://123653068564400",
	"rbxassetid://108569478502468",
	"rbxassetid://106469160594916",
	"rbxassetid://126820135945323",
	"rbxassetid://82146877080338",
	"rbxassetid://113906943909434",
	"rbxassetid://85279237717367",
	"rbxassetid://101878053150181",
	"rbxassetid://100250709639367",
	"rbxassetid://110023838331440",
}

local BOSS_ANIM_SOUND_ID = "rbxassetid://75323729017129"
local BOSS_LOOP_SOUND_ID = "rbxassetid://77842117883797"
local BOSS_START_LAYER_SOUND_ID = "rbxassetid://71043668165317"
local SKULL_FALL_SOUND_ID = "rbxassetid://115517415956225"
local SKULL_SHAKE_SOUND_ID = "rbxassetid://122500094351040"
local UI_FADE_TIME = 0.42
local FRAME_TIME = 1 / 16.67
local HOLD_TIME = 3
local TEXT_POP_DURATION = FRAME_TIME * 1.35
local TEXT_POP_OUT_DURATION = FRAME_TIME * 1.35
local SKULL_FALL_DURATION = FRAME_TIME * 4.75
local SKULL_END_SIZE = UDim2.new(0.107, 0, 0.213, 0)
local SKULL_START_SCALE_MULTIPLIER = 2.25
local EFFECT_RAMP_END_FRAME = 7
local EFFECT_CENTER = UDim2.fromScale(0.5, 0.5)
local EFFECT_RAMP_TIME = FRAME_TIME * (EFFECT_RAMP_END_FRAME - 1)
local EFFECT_SLOWDOWN_TIME = 0.55
local playToken = 0
local textDefaults = {}
local skullDefaults = nil
local rng = Random.new()
local effectSlowdownToken = 0
local effectSlowdownStartedAt = 0
local framePreloadLabels = {}
local bossPlaying = false

frame.Visible = false
frame.BackgroundTransparency = 1
frame.Image = FRAME_IDS[1]

local function getStroke(guiObject)
	return guiObject:FindFirstChildOfClass("UIStroke")
end

local function captureTransparency(guiObject)
	local stroke = getStroke(guiObject)
	return {
		backgroundTransparency = guiObject.BackgroundTransparency,
		imageTransparency = (guiObject:IsA("ImageLabel") or guiObject:IsA("ImageButton")) and guiObject.ImageTransparency or nil,
		textTransparency = (guiObject:IsA("TextLabel") or guiObject:IsA("TextButton") or guiObject:IsA("TextBox")) and guiObject.TextTransparency or nil,
		strokeTransparency = stroke and stroke.Transparency or nil,
	}
end

local function applyTransparency(guiObject, values)
	guiObject.BackgroundTransparency = values.backgroundTransparency

	if values.imageTransparency ~= nil and (guiObject:IsA("ImageLabel") or guiObject:IsA("ImageButton")) then
		guiObject.ImageTransparency = values.imageTransparency
	end

	if values.textTransparency ~= nil and (guiObject:IsA("TextLabel") or guiObject:IsA("TextButton") or guiObject:IsA("TextBox")) then
		guiObject.TextTransparency = values.textTransparency
	end

	local stroke = getStroke(guiObject)
	if stroke and values.strokeTransparency ~= nil then
		stroke.Transparency = values.strokeTransparency
	end
end

local function transparentValues(guiObject)
	local values = {
		backgroundTransparency = 1,
		imageTransparency = nil,
		textTransparency = nil,
		strokeTransparency = nil,
	}

	if guiObject:IsA("ImageLabel") or guiObject:IsA("ImageButton") then
		values.imageTransparency = 1
	end

	if guiObject:IsA("TextLabel") or guiObject:IsA("TextButton") or guiObject:IsA("TextBox") then
		values.textTransparency = 1
	end

	if getStroke(guiObject) then
		values.strokeTransparency = 1
	end

	return values
end

local function tweenTransparency(guiObject, values, info)
	local props = {
		BackgroundTransparency = values.backgroundTransparency,
	}

	if values.imageTransparency ~= nil and (guiObject:IsA("ImageLabel") or guiObject:IsA("ImageButton")) then
		props.ImageTransparency = values.imageTransparency
	end

	if values.textTransparency ~= nil and (guiObject:IsA("TextLabel") or guiObject:IsA("TextButton") or guiObject:IsA("TextBox")) then
		props.TextTransparency = values.textTransparency
	end

	TweenService:Create(guiObject, info, props):Play()

	local stroke = getStroke(guiObject)
	if stroke and values.strokeTransparency ~= nil then
		TweenService:Create(stroke, info, {Transparency = values.strokeTransparency}):Play()
	end
end

local function getViewportHeight()
	local camera = workspace.CurrentCamera
	return camera and camera.ViewportSize.Y or 720
end

local function captureVisibleUi()
	local snapshots = {}

	for _, screenGui in ipairs(playerGui:GetChildren()) do
		if screenGui ~= gui and screenGui:IsA("ScreenGui") and screenGui.Enabled then
			local guiSnapshot = {
				gui = screenGui,
				enabled = screenGui.Enabled,
				objects = {},
				roots = {},
			}

			for _, child in ipairs(screenGui:GetChildren()) do
				if child:IsA("GuiObject") and child.Visible then
					local direction = child.AbsolutePosition.Y + child.AbsoluteSize.Y * 0.5 < getViewportHeight() * 0.5 and -1 or 1
					table.insert(guiSnapshot.roots, {
						object = child,
						position = child.Position,
						offscreen = child.Position + UDim2.fromScale(0, direction * 0.28),
					})
				end
			end

			for _, descendant in ipairs(screenGui:GetDescendants()) do
				if descendant:IsA("GuiObject") then
					guiSnapshot.objects[descendant] = {
						visible = descendant.Visible,
						transparency = captureTransparency(descendant),
					}
				end
			end

			table.insert(snapshots, guiSnapshot)
		end
	end

	return snapshots
end

local function fadeUiOut(snapshots)
	local info = TweenInfo.new(UI_FADE_TIME, Enum.EasingStyle.Quart, Enum.EasingDirection.InOut)

	for _, guiSnapshot in ipairs(snapshots) do
		for _, root in ipairs(guiSnapshot.roots) do
			if root.object.Parent then
				TweenService:Create(root.object, info, {Position = root.offscreen}):Play()
			end
		end

		for guiObject, state in pairs(guiSnapshot.objects) do
			if guiObject.Parent and state.visible then
				tweenTransparency(guiObject, transparentValues(guiObject), info)
			end
		end
	end

	task.wait(UI_FADE_TIME)

	for _, guiSnapshot in ipairs(snapshots) do
		if guiSnapshot.gui.Parent then
			guiSnapshot.gui.Enabled = false
		end
	end
end

local function fadeUiIn(snapshots)
	local info = TweenInfo.new(UI_FADE_TIME, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

	for _, guiSnapshot in ipairs(snapshots) do
		if guiSnapshot.gui.Parent then
			guiSnapshot.gui.Enabled = guiSnapshot.enabled
		end

		for guiObject, state in pairs(guiSnapshot.objects) do
			if guiObject.Parent then
				guiObject.Visible = state.visible
				if state.visible then
					applyTransparency(guiObject, transparentValues(guiObject))
				else
					applyTransparency(guiObject, state.transparency)
				end
			end
		end

		for _, root in ipairs(guiSnapshot.roots) do
			if root.object.Parent then
				root.object.Position = root.offscreen
				TweenService:Create(root.object, info, {Position = root.position}):Play()
			end
		end

		for guiObject, state in pairs(guiSnapshot.objects) do
			if guiObject.Parent and state.visible then
				tweenTransparency(guiObject, state.transparency, info)
			end
		end
	end
end

local bossAnimSound = Instance.new("Sound")
bossAnimSound.Name = "BossAnimSound"
bossAnimSound.SoundId = BOSS_ANIM_SOUND_ID
bossAnimSound.Volume = 0.5
bossAnimSound.Parent = gui

local bossLoopSound = Instance.new("Sound")
bossLoopSound.Name = "BossLoopSound"
bossLoopSound.SoundId = BOSS_LOOP_SOUND_ID
bossLoopSound.Volume = 1
bossLoopSound.Looped = false
bossLoopSound.Parent = gui

local bossStartLayerSound = Instance.new("Sound")
bossStartLayerSound.Name = "BossStartLayerSound"
bossStartLayerSound.SoundId = BOSS_START_LAYER_SOUND_ID
bossStartLayerSound.Volume = 1
bossStartLayerSound.Parent = gui

local skullFallSound = Instance.new("Sound")
skullFallSound.Name = "SkullFallSound"
skullFallSound.SoundId = SKULL_FALL_SOUND_ID
skullFallSound.Volume = 1
skullFallSound.Parent = gui

local skullShakeSound = Instance.new("Sound")
skullShakeSound.Name = "SkullShakeSound"
skullShakeSound.SoundId = SKULL_SHAKE_SOUND_ID
skullShakeSound.Volume = 1
skullShakeSound.Parent = gui

local preloadLayer = Instance.new("Frame")
preloadLayer.Name = "BossFramePreloadLayer"
preloadLayer.AnchorPoint = Vector2.new(0, 0)
preloadLayer.Position = UDim2.fromOffset(0, 0)
preloadLayer.Size = UDim2.fromOffset(1, 1)
preloadLayer.BackgroundTransparency = 1
preloadLayer.BorderSizePixel = 0
preloadLayer.Visible = true
preloadLayer.Parent = gui

for index, imageId in ipairs(FRAME_IDS) do
	local preloadImage = Instance.new("ImageLabel")
	preloadImage.Name = "BossFramePreload" .. index
	preloadImage.BackgroundTransparency = 1
	preloadImage.BorderSizePixel = 0
	preloadImage.ImageTransparency = 0.99
	preloadImage.Image = imageId
	preloadImage.Size = UDim2.fromOffset(1, 1)
	preloadImage.Parent = preloadLayer
	framePreloadLabels[index] = preloadImage
end

local effectsLayer = Instance.new("Frame")
effectsLayer.Name = "BossEffectsLayer"
effectsLayer.AnchorPoint = Vector2.new(0.5, 0.5)
effectsLayer.Position = UDim2.fromScale(0.5, 0.5)
effectsLayer.Size = UDim2.fromScale(1, 1)
effectsLayer.BackgroundTransparency = 1
effectsLayer.BorderSizePixel = 0
effectsLayer.ClipsDescendants = false
effectsLayer.Visible = false
effectsLayer.ZIndex = 90
effectsLayer.Parent = gui

local whiteHoleCore = Instance.new("Frame")
whiteHoleCore.Name = "WhiteHoleCore"
whiteHoleCore.AnchorPoint = Vector2.new(0.5, 0.5)
whiteHoleCore.Position = EFFECT_CENTER
whiteHoleCore.Size = UDim2.fromScale(0.02, 0.02)
whiteHoleCore.BackgroundColor3 = Color3.fromRGB(255, 250, 240)
whiteHoleCore.BackgroundTransparency = 1
whiteHoleCore.BorderSizePixel = 0
whiteHoleCore.ZIndex = 95
whiteHoleCore.Parent = effectsLayer

local whiteHoleCorner = Instance.new("UICorner")
whiteHoleCorner.CornerRadius = UDim.new(1, 0)
whiteHoleCorner.Parent = whiteHoleCore

local whiteHoleStroke = Instance.new("UIStroke")
whiteHoleStroke.Color = Color3.fromRGB(255, 46, 46)
whiteHoleStroke.Thickness = 2
whiteHoleStroke.Transparency = 1
whiteHoleStroke.Parent = whiteHoleCore

local function getOrCreateScale(guiObject, scaleName)
	scaleName = scaleName or "BossPopScale"
	local scale = guiObject:FindFirstChild(scaleName)
	if not scale then
		scale = Instance.new("UIScale")
		scale.Name = scaleName
		scale.Parent = guiObject
	end
	return scale
end

local function captureTextDefaults(guiObject)
	if not guiObject then
		return
	end
	if textDefaults[guiObject] then
		return
	end

	local stroke = guiObject:FindFirstChildOfClass("UIStroke")
	textDefaults[guiObject] = {
		textTransparency = guiObject:IsA("TextLabel") and guiObject.TextTransparency or 0,
		backgroundTransparency = guiObject.BackgroundTransparency,
		strokeTransparency = stroke and stroke.Transparency or nil,
		scale = getOrCreateScale(guiObject),
	}
end

local function setTextHidden(guiObject)
	local defaults = guiObject and textDefaults[guiObject]
	if not defaults then
		return
	end

	guiObject.Visible = false
	if guiObject:IsA("TextLabel") then
		guiObject.TextTransparency = 1
	end
	guiObject.BackgroundTransparency = 1
	defaults.scale.Scale = 0.25

	local stroke = guiObject:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Transparency = 1
	end
end

local function resetText(guiObject)
	local defaults = guiObject and textDefaults[guiObject]
	if not defaults then
		return
	end

	guiObject.Visible = true
	if guiObject:IsA("TextLabel") then
		guiObject.TextTransparency = defaults.textTransparency
	end
	guiObject.BackgroundTransparency = defaults.backgroundTransparency
	defaults.scale.Scale = 1

	local stroke = guiObject:FindFirstChildOfClass("UIStroke")
	if stroke and defaults.strokeTransparency then
		stroke.Transparency = defaults.strokeTransparency
	end
end

local function hideBossText()
	setTextHidden(text1)
	setTextHidden(text2)
end

local function offsetPosition(position, offset)
	return UDim2.new(
		position.X.Scale,
		position.X.Offset + offset.X,
		position.Y.Scale,
		position.Y.Offset + offset.Y
	)
end

local function getParentBounds(guiObject)
	local parent = guiObject.Parent
	if parent and parent:IsA("GuiObject") then
		return parent.AbsolutePosition, parent.AbsoluteSize
	end

	local camera = workspace.CurrentCamera
	return Vector2.new(0, 0), camera and camera.ViewportSize or Vector2.new(1, 1)
end

local function centerScaleOrigin(guiObject)
	if guiObject.AnchorPoint == Vector2.new(0.5, 0.5) then
		return
	end

	local parentPosition, parentSize = getParentBounds(guiObject)
	if parentSize.X <= 0 or parentSize.Y <= 0 then
		return
	end

	local center = guiObject.AbsolutePosition + guiObject.AbsoluteSize * 0.5 - parentPosition
	guiObject.AnchorPoint = Vector2.new(0.5, 0.5)
	guiObject.Position = UDim2.fromScale(center.X / parentSize.X, center.Y / parentSize.Y)
end

local function captureSkullDefaults(guiObject)
	if not guiObject or skullDefaults then
		return
	end

	centerScaleOrigin(guiObject)
	guiObject.Size = SKULL_END_SIZE

	local scale = getOrCreateScale(guiObject, "BossSkullScale")
	skullDefaults = {
		imageTransparency = (guiObject:IsA("ImageLabel") or guiObject:IsA("ImageButton")) and guiObject.ImageTransparency or nil,
		backgroundTransparency = guiObject.BackgroundTransparency,
		position = guiObject.Position,
		rotation = guiObject.Rotation,
		size = SKULL_END_SIZE,
		scale = scale,
		scaleValue = scale.Scale,
	}
end

local function hideSkull()
	if not skull or not skullDefaults then
		return
	end

	skull.Visible = false
	skull.Position = skullDefaults.position
	skull.Size = skullDefaults.size
	skull.Rotation = skullDefaults.rotation
	skull.BackgroundTransparency = 1
	skullDefaults.scale.Scale = skullDefaults.scaleValue * SKULL_START_SCALE_MULTIPLIER

	if skullDefaults.imageTransparency then
		skull.ImageTransparency = 1
	end
end

local function refreshTextObjects()
	text1 = text1 or gui:FindFirstChild("Text1")
	text2 = text2 or gui:FindFirstChild("Text2")
	captureTextDefaults(text1)
	captureTextDefaults(text2)
end

local function refreshSkullObject()
	skull = skull or gui:FindFirstChild("Skull")
	captureSkullDefaults(skull)
end

local function refreshBossObjects()
	refreshTextObjects()
	refreshSkullObject()
end

refreshBossObjects()
hideBossText()
hideSkull()

task.spawn(function()
	local ok, err = pcall(function()
		local preloadTargets = table.clone(FRAME_IDS)
		for _, preloadImage in ipairs(framePreloadLabels) do
			table.insert(preloadTargets, preloadImage)
		end
		table.insert(preloadTargets, bossAnimSound)
		table.insert(preloadTargets, bossLoopSound)
		table.insert(preloadTargets, bossStartLayerSound)
		table.insert(preloadTargets, skullFallSound)
		table.insert(preloadTargets, skullShakeSound)
		ContentProvider:PreloadAsync(preloadTargets)
	end)
	if not ok then
		warn("[BossUI] Failed to preload boss animation frames:", err)
	end
end)

local function waitFrame(token, seconds)
	local elapsed = 0
	while elapsed < seconds do
		if playToken ~= token then
			return false
		end
		elapsed += task.wait(math.min(seconds - elapsed, FRAME_TIME))
	end
	return playToken == token
end

local function playBossAnimSound()
	bossAnimSound:Stop()
	bossAnimSound.TimePosition = 0
	bossAnimSound:Play()
end

local function playSound(sound)
	sound:Stop()
	sound.TimePosition = 0
	sound:Play()
end

local function clearBossEffects()
	effectSlowdownToken = 0
	effectsLayer.Visible = false
	whiteHoleCore.Size = UDim2.fromScale(0.02, 0.02)
	whiteHoleCore.BackgroundTransparency = 1
	whiteHoleStroke.Transparency = 1

	for _, child in ipairs(effectsLayer:GetChildren()) do
		if child ~= whiteHoleCore then
			child:Destroy()
		end
	end
end

local function createRedShard(name, width, thickness, color, transparency)
	local shard = Instance.new("Frame")
	shard.Name = name
	shard.AnchorPoint = Vector2.new(0.5, 0.5)
	shard.BackgroundColor3 = color
	shard.BackgroundTransparency = transparency
	shard.BorderSizePixel = 0
	shard.Size = UDim2.fromOffset(width, thickness)
	shard.ZIndex = 94

	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, rng:NextInteger(145, 225), rng:NextInteger(125, 190))),
		ColorSequenceKeypoint.new(0.2, color),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(rng:NextInteger(95, 170), 0, 0)),
	})
	gradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, rng:NextNumber(0.2, 0.55)),
		NumberSequenceKeypoint.new(0.35, rng:NextNumber(0, 0.16)),
		NumberSequenceKeypoint.new(1, rng:NextNumber(0.45, 0.86)),
	})
	gradient.Rotation = rng:NextNumber(-12, 12)
	gradient.Parent = shard

	return shard
end

local function spawnRedShard(token, intensity)
	if playToken ~= token then
		return
	end

	local angle = rng:NextNumber(0, math.pi * 2)
	local distance = rng:NextNumber(180 + intensity * 110, 430 + intensity * 360)
	local startRadius = rng:NextNumber(0, 24 + intensity * 26)
	local width = rng:NextNumber(26 + intensity * 18, 88 + intensity * 75)
	local thickness = rng:NextNumber(5, 22 + intensity * 16)
	local direction = Vector2.new(math.cos(angle), math.sin(angle))
	local startOffset = direction * startRadius
	local endOffset = direction * distance
	local color = Color3.fromRGB(255, rng:NextInteger(0, 72), rng:NextInteger(0, 44))
	local shard = createRedShard("RedBlastShard", width, thickness, color, rng:NextNumber(0.04, 0.48))
	shard.Position = UDim2.new(0.5, startOffset.X, 0.5, startOffset.Y)
	shard.Rotation = math.deg(angle)
	shard.Parent = effectsLayer

	local travelTime = rng:NextNumber(0.26, 0.56)
	TweenService:Create(shard, TweenInfo.new(travelTime, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, endOffset.X, 0.5, endOffset.Y),
		Size = UDim2.fromOffset(width * rng:NextNumber(0.65, 1.55), math.max(2, thickness * rng:NextNumber(0.2, 0.72))),
		BackgroundTransparency = 1,
		Rotation = shard.Rotation,
	}):Play()

	task.delay(travelTime, function()
		if shard.Parent then
			shard:Destroy()
		end
	end)
end

local function startRedBlast(token)
	effectSlowdownToken = 0
	effectSlowdownStartedAt = 0
	effectsLayer.Visible = true

	task.spawn(function()
		local startedAt = os.clock()

		while playToken == token do
			local intensity = math.clamp((os.clock() - startedAt) / EFFECT_RAMP_TIME, 0, 1)
			if effectSlowdownToken == token then
				local slowdownProgress = math.clamp((os.clock() - effectSlowdownStartedAt) / EFFECT_SLOWDOWN_TIME, 0, 1)
				intensity = math.clamp(1 - slowdownProgress, 0, 1)
				if slowdownProgress >= 1 then
					break
				end
			end

			local burstCount = math.max(1, math.floor(1 + intensity * 4))
			for _ = 1, burstCount do
				spawnRedShard(token, intensity)
			end

			task.wait(0.075 - intensity * 0.035)
		end
	end)
end

local function slowRedBlast(token)
	if playToken ~= token then
		return
	end

	effectSlowdownToken = token
	effectSlowdownStartedAt = os.clock()
end

local function showFrame(token, imageId)
	if playToken ~= token then
		return false
	end

	frame.Image = imageId
	frame.Visible = true
	return true
end

local function popText(token, guiObject)
	local defaults = guiObject and textDefaults[guiObject]
	if playToken ~= token or not defaults then
		return
	end

	guiObject.Visible = true
	guiObject.BackgroundTransparency = 1
	if guiObject:IsA("TextLabel") then
		guiObject.TextTransparency = 1
	end
	defaults.scale.Scale = 0.25

	local stroke = guiObject:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Transparency = 1
	end

	TweenService:Create(defaults.scale, TweenInfo.new(TEXT_POP_DURATION * 0.62, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Scale = 1.15,
	}):Play()

	task.delay(TEXT_POP_DURATION * 0.62, function()
		if playToken ~= token or not defaults.scale.Parent then return end
		TweenService:Create(defaults.scale, TweenInfo.new(TEXT_POP_DURATION * 0.38, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Scale = 1,
		}):Play()
	end)

	if guiObject:IsA("TextLabel") then
		TweenService:Create(guiObject, TweenInfo.new(TEXT_POP_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			TextTransparency = defaults.textTransparency,
			BackgroundTransparency = defaults.backgroundTransparency,
		}):Play()
	else
		TweenService:Create(guiObject, TweenInfo.new(TEXT_POP_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundTransparency = defaults.backgroundTransparency,
		}):Play()
	end

	if stroke and defaults.strokeTransparency then
		TweenService:Create(stroke, TweenInfo.new(TEXT_POP_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Transparency = defaults.strokeTransparency,
		}):Play()
	end
end

local function popOutText(token, guiObject)
	local defaults = guiObject and textDefaults[guiObject]
	if playToken ~= token or not defaults then
		return
	end

	local stroke = guiObject:FindFirstChildOfClass("UIStroke")
	TweenService:Create(defaults.scale, TweenInfo.new(TEXT_POP_OUT_DURATION, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
		Scale = 0.25,
	}):Play()

	if guiObject:IsA("TextLabel") then
		TweenService:Create(guiObject, TweenInfo.new(TEXT_POP_OUT_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			TextTransparency = 1,
			BackgroundTransparency = 1,
		}):Play()
	else
		TweenService:Create(guiObject, TweenInfo.new(TEXT_POP_OUT_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			BackgroundTransparency = 1,
		}):Play()
	end

	if stroke then
		TweenService:Create(stroke, TweenInfo.new(TEXT_POP_OUT_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Transparency = 1,
		}):Play()
	end

	task.delay(TEXT_POP_OUT_DURATION, function()
		if playToken ~= token or not guiObject.Parent then return end
		setTextHidden(guiObject)
	end)
end

local function dropSkull(token)
	if playToken ~= token or not skull or not skullDefaults then
		return
	end

	playSound(skullFallSound)

	skull.Visible = true
	skull.Position = skullDefaults.position
	skull.Size = skullDefaults.size
	skull.Rotation = skullDefaults.rotation
	skull.BackgroundTransparency = 1
	skullDefaults.scale.Scale = skullDefaults.scaleValue * SKULL_START_SCALE_MULTIPLIER

	if skullDefaults.imageTransparency then
		skull.ImageTransparency = 1
	end

	TweenService:Create(skullDefaults.scale, TweenInfo.new(SKULL_FALL_DURATION, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
		Scale = skullDefaults.scaleValue,
	}):Play()

	local skullFadeProperties = {
		BackgroundTransparency = skullDefaults.backgroundTransparency,
	}
	if skullDefaults.imageTransparency then
		skullFadeProperties.ImageTransparency = skullDefaults.imageTransparency
	end

	TweenService:Create(skull, TweenInfo.new(SKULL_FALL_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), skullFadeProperties):Play()
end

local function slamShake(token)
	if playToken ~= token then
		return
	end

	playSound(skullShakeSound)

	if skull and skullDefaults then
		skull.Visible = true
		skull.Position = skullDefaults.position
		skull.Size = skullDefaults.size
		skull.Rotation = skullDefaults.rotation
		skull.BackgroundTransparency = skullDefaults.backgroundTransparency
		skullDefaults.scale.Scale = skullDefaults.scaleValue
		if skullDefaults.imageTransparency then
			skull.ImageTransparency = skullDefaults.imageTransparency
		end
	end

	local targets = {
		{ object = frame, position = frame.Position },
	}
	if skull and skullDefaults then
		table.insert(targets, { object = skull, position = skullDefaults.position })
	end

	local offsets = {
		Vector2.new(0, 10),
		Vector2.new(-12, -5),
		Vector2.new(10, 4),
		Vector2.new(-6, 2),
		Vector2.new(4, -1),
		Vector2.new(0, 0),
	}

	task.spawn(function()
		for _, offset in ipairs(offsets) do
			if playToken ~= token then
				for _, target in ipairs(targets) do
					if target.object.Parent then
						target.object.Position = target.position
					end
				end
				return
			end

			for _, target in ipairs(targets) do
				if target.object.Parent then
					target.object.Position = offsetPosition(target.position, offset)
				end
			end
			task.wait(FRAME_TIME * 0.28)
		end

		for _, target in ipairs(targets) do
			if target.object.Parent then
				target.object.Position = target.position
			end
		end
	end)
end

local function playBossAnimation()
	if bossPlaying then
		return
	end

	bossPlaying = true
	playToken += 1
	local token = playToken
	local uiSnapshots = captureVisibleUi()
	local uiRestored = false
	bossLoopSound:Stop()
	bossStartLayerSound:Stop()
	refreshBossObjects()
	hideBossText()
	hideSkull()
	clearBossEffects()

	local function finish()
		if uiRestored then
			return
		end

		uiRestored = true
		frame.Visible = false
		hideBossText()
		hideSkull()
		clearBossEffects()
		bossLoopSound:Stop()
		fadeUiIn(uiSnapshots)
		bossPlaying = false
	end

	task.spawn(function()
		fadeUiOut(uiSnapshots)
		if playToken ~= token then
			finish()
			return
		end

		playSound(bossLoopSound)
		playSound(bossStartLayerSound)
		playBossAnimSound()
		startRedBlast(token)

		for index, imageId in ipairs(FRAME_IDS) do
			if not showFrame(token, imageId) then finish(); return end
			if index == 6 then
				popText(token, text1)
			elseif index == 7 then
				popText(token, text2)
			end
			if not waitFrame(token, FRAME_TIME) then finish(); return end
		end

		if not waitFrame(token, HOLD_TIME) then finish(); return end

		slowRedBlast(token)
		playBossAnimSound()

		for index = #FRAME_IDS, 1, -1 do
			if not showFrame(token, FRAME_IDS[index]) then finish(); return end
			if index == 10 then
				popOutText(token, text2)
			elseif index == 9 then
				popOutText(token, text1)
			elseif index == 7 then
				dropSkull(token)
			elseif index == 2 then
				slamShake(token)
			end
			if not waitFrame(token, FRAME_TIME) then finish(); return end
		end

		if playToken == token then
			finish()
		end
	end)
end

BossAnimRemote.OnClientEvent:Connect(playBossAnimation)
