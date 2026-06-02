local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local tutorialGui = script.Parent
local TutorialRemote = ReplicatedStorage:WaitForChild("TutorialRemote")

local TEXT_COLOR = "#e8e8e8"
local PURPLE = "#a44cff"
local GREEN = "#67ff70"
local WHITE = "#ffffff"

local UI_OUT_TIME = 0.36
local TYPE_INTERVAL = 0.018
local CLICK_COOLDOWN = 0.25

local stage = "idle"
local typing = false
local clickReadyAt = 0
local hiddenSnapshots = {}
local beamObjects = {}
local tutorialTextSuppressed = false

tutorialGui.Enabled = true

local overlay = Instance.new("Frame")
overlay.Name = "Overlay"
overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
overlay.BackgroundTransparency = 1
overlay.BorderSizePixel = 0
overlay.Size = UDim2.fromScale(1, 1)
overlay.Parent = tutorialGui

local textLabel = Instance.new("TextLabel")
textLabel.Name = "GuideText"
textLabel.AnchorPoint = Vector2.new(0.5, 1)
textLabel.BackgroundTransparency = 1
textLabel.Position = UDim2.fromScale(0.5, 0.875)
textLabel.Size = UDim2.fromScale(0.82, 0.16)
textLabel.RichText = true
textLabel.Text = ""
textLabel.TextColor3 = Color3.fromRGB(232, 232, 232)
textLabel.TextScaled = true
textLabel.TextWrapped = true
textLabel.TextXAlignment = Enum.TextXAlignment.Center
textLabel.TextYAlignment = Enum.TextYAlignment.Center
textLabel.ZIndex = 3
textLabel.Parent = overlay
pcall(function()
	textLabel.FontFace = Font.new("rbxasset://fonts/families/Ubuntu.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal)
end)

local textScale = Instance.new("UIScale")
textScale.Name = "TextPopScale"
textScale.Scale = 0.96
textScale.Parent = textLabel

local promptLabel = Instance.new("TextLabel")
promptLabel.Name = "ContinuePrompt"
promptLabel.AnchorPoint = Vector2.new(0.5, 1)
promptLabel.BackgroundTransparency = 1
promptLabel.Position = UDim2.fromScale(0.5, 0.945)
promptLabel.Size = UDim2.fromScale(0.48, 0.038)
promptLabel.RichText = true
promptLabel.Text = ""
promptLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
promptLabel.TextScaled = true
promptLabel.TextTransparency = 1
promptLabel.ZIndex = 3
promptLabel.Parent = overlay
pcall(function()
	promptLabel.FontFace = Font.new("rbxasset://fonts/families/Ubuntu.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal)
end)

local typingSound = Instance.new("Sound")
typingSound.Name = "TutorialTypingSound"
typingSound.SoundId = "rbxassetid://86312424945274"
typingSound.Volume = 0.18
typingSound.PlaybackSpeed = 1.45
typingSound.Parent = SoundService

local function isTapDevice()
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

local function continuePromptText()
	return isTapDevice() and "[TAP ANYWHERE TO CONTINUE]" or "[CLICK ANYWHERE TO CONTINUE]"
end

local function getOffscreenPosition(guiObject)
	local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
	local centerY = guiObject.AbsolutePosition.Y + guiObject.AbsoluteSize.Y * 0.5
	local direction = centerY < viewport.Y * 0.5 and -1 or 1
	return guiObject.Position + UDim2.fromScale(0, direction * 0.36)
end

local function captureGuiObject(guiObject)
	local state = {
		visible = guiObject.Visible,
		position = guiObject.Position,
		backgroundTransparency = guiObject.BackgroundTransparency,
		imageTransparency = nil,
		textTransparency = nil,
		strokeTransparency = nil,
	}

	if guiObject:IsA("ImageLabel") or guiObject:IsA("ImageButton") then
		state.imageTransparency = guiObject.ImageTransparency
	end
	if guiObject:IsA("TextLabel") or guiObject:IsA("TextButton") or guiObject:IsA("TextBox") then
		state.textTransparency = guiObject.TextTransparency
	end

	local stroke = guiObject:FindFirstChildOfClass("UIStroke")
	if stroke then
		state.strokeTransparency = stroke.Transparency
	end

	return state
end

local function tweenTransparency(guiObject, transparency, duration)
	local props = {}
	if guiObject:IsA("GuiObject") then
		props.BackgroundTransparency = math.max(guiObject.BackgroundTransparency, transparency)
	end
	if guiObject:IsA("ImageLabel") or guiObject:IsA("ImageButton") then
		props.ImageTransparency = transparency
	end
	if guiObject:IsA("TextLabel") or guiObject:IsA("TextButton") or guiObject:IsA("TextBox") then
		props.TextTransparency = transparency
	end

	if next(props) then
		TweenService:Create(guiObject, TweenInfo.new(duration, Enum.EasingStyle.Quart, Enum.EasingDirection.InOut), props):Play()
	end

	local stroke = guiObject:FindFirstChildOfClass("UIStroke")
	if stroke then
		TweenService:Create(stroke, TweenInfo.new(duration, Enum.EasingStyle.Quart, Enum.EasingDirection.InOut), { Transparency = transparency }):Play()
	end
end

local function applyState(guiObject, state)
	if not guiObject.Parent then
		return
	end

	guiObject.Visible = state.visible
	guiObject.Position = state.position
	guiObject.BackgroundTransparency = state.backgroundTransparency

	if state.imageTransparency ~= nil and (guiObject:IsA("ImageLabel") or guiObject:IsA("ImageButton")) then
		guiObject.ImageTransparency = state.imageTransparency
	end
	if state.textTransparency ~= nil and (guiObject:IsA("TextLabel") or guiObject:IsA("TextButton") or guiObject:IsA("TextBox")) then
		guiObject.TextTransparency = state.textTransparency
	end

	local stroke = guiObject:FindFirstChildOfClass("UIStroke")
	if stroke and state.strokeTransparency ~= nil then
		stroke.Transparency = state.strokeTransparency
	end
end

local function hideAllGameUi()
	table.clear(hiddenSnapshots)

	for _, screenGui in ipairs(playerGui:GetChildren()) do
		if screenGui:IsA("ScreenGui") and screenGui ~= tutorialGui and screenGui.Enabled then
			local snapshot = {
				gui = screenGui,
				enabled = screenGui.Enabled,
				objects = {},
				roots = {},
			}

			for _, descendant in ipairs(screenGui:GetDescendants()) do
				if descendant:IsA("GuiObject") then
					snapshot.objects[descendant] = captureGuiObject(descendant)
				end
			end

			for _, child in ipairs(screenGui:GetChildren()) do
				if child:IsA("GuiObject") and child.Visible then
					table.insert(snapshot.roots, {
						object = child,
						position = child.Position,
						offscreen = getOffscreenPosition(child),
					})
					TweenService:Create(child, TweenInfo.new(UI_OUT_TIME, Enum.EasingStyle.Quart, Enum.EasingDirection.InOut), {
						Position = getOffscreenPosition(child),
					}):Play()
				end
			end

			for guiObject, state in pairs(snapshot.objects) do
				if state.visible then
					tweenTransparency(guiObject, 1, UI_OUT_TIME)
				end
			end

			table.insert(hiddenSnapshots, snapshot)
		end
	end
end

local function restoreGuiByName(guiName)
	local info = TweenInfo.new(0.42, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

	for _, snapshot in ipairs(hiddenSnapshots) do
		if snapshot.gui.Name == guiName and snapshot.gui.Parent then
			snapshot.gui.Enabled = snapshot.enabled

			for guiObject, state in pairs(snapshot.objects) do
				if guiObject.Parent then
					applyState(guiObject, state)
				end
			end

			for _, root in ipairs(snapshot.roots) do
				if root.object.Parent then
					root.object.Position = root.offscreen
					TweenService:Create(root.object, info, { Position = root.position }):Play()
				end
			end
		end
	end
end

local function restoreNonRoundGameUi()
	local skipRestore = {
		Timer = true,
		Tip = true,
		Skip = true,
		Dialogue = true,
		Tutorial = true,
	}

	for _, snapshot in ipairs(hiddenSnapshots) do
		if snapshot.gui.Parent and not skipRestore[snapshot.gui.Name] then
			restoreGuiByName(snapshot.gui.Name)
		end
	end
end

local function renderRichSegments(segments, visibleCharacters)
	local remaining = visibleCharacters
	local output = {}

	for _, segment in ipairs(segments) do
		local text = segment.text
		local length = utf8.len(text) or #text
		local take = math.clamp(remaining, 0, length)
		if take > 0 then
			local byteEnd = utf8.offset(text, take + 1)
			local partial = byteEnd and string.sub(text, 1, byteEnd - 1) or text
			table.insert(output, string.format('<font color="%s">%s</font>', segment.color or TEXT_COLOR, partial))
		end
		remaining -= take
		if remaining <= 0 then
			break
		end
	end

	return table.concat(output)
end

local function setTutorialTextVisible(visible)
	tutorialTextSuppressed = not visible
	local targetTransparency = visible and 0 or 1
	local targetPromptTransparency = visible and (promptLabel.Text ~= "" and 0 or 1) or 1
	local targetOffset = visible and 0 or 0.035

	TweenService:Create(textLabel, TweenInfo.new(0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
		TextTransparency = targetTransparency,
		Position = UDim2.fromScale(0.5, 0.875 + targetOffset),
	}):Play()
	TweenService:Create(promptLabel, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		TextTransparency = targetPromptTransparency,
		Position = UDim2.fromScale(0.5, 0.945 + targetOffset),
	}):Play()
end

local function typeSegments(segments)
	typing = true
	promptLabel.TextTransparency = 1
	promptLabel.Text = ""
	textLabel.Text = ""
	textLabel.TextTransparency = tutorialTextSuppressed and 1 or 0
	textScale.Scale = 0.96
	TweenService:Create(textScale, TweenInfo.new(0.32, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()

	local totalCharacters = 0
	for _, segment in ipairs(segments) do
		totalCharacters += utf8.len(segment.text) or #segment.text
	end

	for count = 1, totalCharacters do
		textLabel.Text = renderRichSegments(segments, count)
		if count % 2 == 0 then
			typingSound.PlaybackSpeed = 1.35 + math.random() * 0.2
			typingSound:Play()
		end
		task.wait(TYPE_INTERVAL)
	end

	typing = false
	promptLabel.Text = string.format('<font color="%s">%s</font>', GREEN, continuePromptText())
	if not tutorialTextSuppressed then
		TweenService:Create(promptLabel, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			TextTransparency = 0,
		}):Play()
	end
end

local function clearBeam()
	for _, object in ipairs(beamObjects) do
		if object and object.Parent then
			object:Destroy()
		end
	end
	table.clear(beamObjects)
end

local function createObjectiveBeam(objectiveName)
	clearBeam()

	local objective = workspace:FindFirstChild(objectiveName or "Objective1")
	local character = player.Character or player.CharacterAdded:Wait()
	local rootPart = character:WaitForChild("HumanoidRootPart", 5)
	if not objective or not objective:IsA("BasePart") or not rootPart then
		return
	end

	objective.CanQuery = true

	local playerAttachment = Instance.new("Attachment")
	playerAttachment.Name = "TutorialBeamPlayerAttachment"
	playerAttachment.Position = Vector3.new(0, 1.7, 0)
	playerAttachment.Parent = rootPart

	local objectiveAttachment = Instance.new("Attachment")
	objectiveAttachment.Name = "TutorialBeamObjectiveAttachment"
	objectiveAttachment.Position = Vector3.new(0, objective.Size.Y * 0.5 + 1.25, 0)
	objectiveAttachment.Parent = objective

	local beam = Instance.new("Beam")
	beam.Name = "TutorialObjectiveBeam"
	beam.Attachment0 = playerAttachment
	beam.Attachment1 = objectiveAttachment
	beam.Texture = "rbxassetid://11552476728"
	beam.TextureMode = Enum.TextureMode.Wrap
	beam.TextureLength = 3.5
	beam.TextureSpeed = 2.25
	beam.Width0 = 0.55
	beam.Width1 = 0.55
	beam.LightEmission = 0.8
	beam.LightInfluence = 0
	beam.Color = ColorSequence.new(Color3.fromRGB(170, 80, 255), Color3.fromRGB(120, 255, 130))
	beam.Transparency = NumberSequence.new(0.08)
	beam.FaceCamera = true
	beam.Parent = rootPart

	table.insert(beamObjects, playerAttachment)
	table.insert(beamObjects, objectiveAttachment)
	table.insert(beamObjects, beam)
end

local function showIntro()
	stage = "intro"
	hideAllGameUi()
	overlay.BackgroundTransparency = 1
	typeSegments({
		{ text = "Welcome to ", color = TEXT_COLOR },
		{ text = "The Rift", color = PURPLE },
		{ text = "! Don't worry. I'm a lot friendlier than that gamemaster. I'm your guide, and I'm going to walk you through the basics. ", color = TEXT_COLOR },
		{ text = "Ready to begin the tutorial?", color = GREEN },
	})
end

local function showStoneBonus()
	stage = "stoneBonus"
	TutorialRemote:FireServer("GrantStartingStone")
	restoreGuiByName("Resources")
	restoreGuiByName("Cash")
	typeSegments({
		{ text = "Great! To get you started, I'll give you ", color = TEXT_COLOR },
		{ text = "40 stone", color = WHITE },
		{ text = " as a bonus.", color = TEXT_COLOR },
	})
end

local function showTowerObjective(objectiveName)
	stage = "towerObjective"
	promptLabel.Text = ""
	promptLabel.TextTransparency = 1
	restoreGuiByName("Towers")
	createObjectiveBeam(objectiveName)

	local instruction
	if isTapDevice() then
		instruction = "tapping the tower button in the top left."
	else
		instruction = 'pressing "1" on your keyboard, or by clicking the tower button in the top left.'
	end

	typeSegments({
		{ text = "Place your first tower where you are shown to by opening your tower menu and placing one ", color = TEXT_COLOR },
		{ text = "Cannon", color = WHITE },
		{ text = ". You can do this by " .. instruction, color = TEXT_COLOR },
	})
	task.spawn(function()
		while typing do
			task.wait()
		end
		promptLabel.Text = ""
		promptLabel.TextTransparency = 1
	end)
end

local function finishFirstSegment()
	stage = "done"
	clearBeam()
	restoreNonRoundGameUi()
	TweenService:Create(overlay, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = 1,
	}):Play()
	TweenService:Create(textLabel, TweenInfo.new(0.24, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		TextTransparency = 1,
	}):Play()
	task.delay(0.4, function()
		tutorialGui.Enabled = false
	end)
end

local function continue()
	if typing or os.clock() < clickReadyAt then
		return
	end
	clickReadyAt = os.clock() + CLICK_COOLDOWN

	if stage == "intro" then
		showStoneBonus()
	elseif stage == "stoneBonus" then
		showTowerObjective(player:GetAttribute("TutorialPlacementObjective") or "Objective1")
	end
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end

	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		continue()
	end
end)

player:GetAttributeChangedSignal("TowerMenuOpen"):Connect(function()
	if stage ~= "towerObjective" then
		return
	end

	setTutorialTextVisible(player:GetAttribute("TowerMenuOpen") ~= true)
end)

TutorialRemote.OnClientEvent:Connect(function(action, payload)
	if action == "Start" then
		showIntro()
	elseif action == "FirstPlacementComplete" then
		finishFirstSegment()
	end
end)

task.defer(function()
	task.wait(0.4)
	if stage == "idle" and player:GetAttribute("TutorialActive") == true then
		showIntro()
	end
end)
