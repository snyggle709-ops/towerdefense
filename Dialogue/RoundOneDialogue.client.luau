local Players = game:GetService("Players")
local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local remote = ReplicatedStorage:WaitForChild("RoundOneDialogueRemote")
local ackRemote = ReplicatedStorage:WaitForChild("RoundOneDialogueAckRemote")
local pollRemote = ReplicatedStorage:WaitForChild("RoundOneDialoguePollRemote")
local dialogueGui = script.Parent
local DIALOGUE_ACTIVE_ATTRIBUTE = "DialogueActive"

print("[Dialogue] Round one dialogue client loaded")

local UI_FADE_TIME = 0.42
local PANEL_POP_TIME = 0.72
local FIGURE_DELAY = 0.3
local FIGURE_POP_TIME = 0.62
local TITLE_DELAY = 0.56
local TITLE_POP_TIME = 0.48
local DIALOGUE_DELAY = 0.82
local DIALOGUE_POP_TIME = 0.52
local HOLD_TIME = 5
local OUT_TIME = 0.34
local VOICE_LOAD_TIMEOUT = 2
local VOICE_FALLBACK_TIME = 12
local OPEN_SOUND_IDS = {
	"rbxassetid://86312424945274",
	"rbxassetid://106953502377758",
	"rbxassetid://118446898778847",
}
local CLOSE_SOUND_IDS = {
	"rbxassetid://130593012796259",
	"rbxassetid://121598995063717",
}
local VOICE_SOUND_IDS = {
	"rbxassetid://122735084302229",
	"rbxassetid://129964742687400",
	"rbxassetid://97956221537533",
	"rbxassetid://90758965952873",
}

local playing = false
local dialogueQueue = {}
local acknowledgedRequests = {}
local polling = false

local VOLATILE_ROUND_UI = {
	Timer = true,
	Tip = true,
	Skip = true,
}

dialogueGui.Enabled = true
for _, child in ipairs(dialogueGui:GetChildren()) do
	if child:IsA("GuiObject") then
		child.Visible = false
	end
end

local preloadSounds = {}
for index, soundId in ipairs(VOICE_SOUND_IDS) do
	local sound = Instance.new("Sound")
	sound.Name = "PreloadDialogueVoice" .. tostring(index)
	sound.SoundId = soundId
	sound.Volume = 0
	sound.Parent = SoundService
	table.insert(preloadSounds, sound)
end
for index, soundId in ipairs(OPEN_SOUND_IDS) do
	local sound = Instance.new("Sound")
	sound.Name = "PreloadDialogueOpen" .. tostring(index)
	sound.SoundId = soundId
	sound.Volume = 0
	sound.Parent = SoundService
	table.insert(preloadSounds, sound)
end
for index, soundId in ipairs(CLOSE_SOUND_IDS) do
	local sound = Instance.new("Sound")
	sound.Name = "PreloadDialogueClose" .. tostring(index)
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

local function tween(instance, info, props)
	local tweenObject = TweenService:Create(instance, info, props)
	tweenObject:Play()
	return tweenObject
end

local function playRandomUiSound(soundIds, volume, pitchJitterPercent)
	if #soundIds == 0 then
		return
	end

	local sound = Instance.new("Sound")
	sound.SoundId = soundIds[math.random(1, #soundIds)]
	sound.Volume = volume
	sound.PlaybackSpeed = 1 + (math.random(-pitchJitterPercent, pitchJitterPercent) / 100)
	sound.Parent = SoundService
	sound:Play()

	sound.Ended:Once(function()
		sound:Destroy()
	end)

	task.delay(4, function()
		if sound.Parent then
			sound:Destroy()
		end
	end)
end

local function playDialogueVoice(soundId, volume)
	if typeof(soundId) ~= "string" or soundId == "" then
		return nil
	end

	local sound = Instance.new("Sound")
	sound.Name = "DialogueVoice"
	sound.SoundId = soundId
	sound.Volume = tonumber(volume) or 1
	sound.Parent = SoundService

	local state = {
		sound = sound,
		finished = false,
	}

	local endedConnection
	endedConnection = sound.Ended:Connect(function()
		state.finished = true
		if endedConnection then
			endedConnection:Disconnect()
		end
		if sound.Parent then
			sound:Destroy()
		end
	end)

	task.spawn(function()
		sound:Play()

		local loadStartedAt = os.clock()
		while not sound.IsLoaded and sound.Parent and os.clock() - loadStartedAt < VOICE_LOAD_TIMEOUT do
			task.wait()
		end

		if not sound.Parent then
			state.finished = true
			return
		end

		local fallbackTime = sound.TimeLength
		if typeof(fallbackTime) ~= "number" or fallbackTime <= 0 then
			fallbackTime = VOICE_FALLBACK_TIME
		end

		task.delay(fallbackTime + 1, function()
			if not state.finished then
				state.finished = true
				if endedConnection then
					endedConnection:Disconnect()
				end
				if sound.Parent then
					sound:Destroy()
				end
			end
		end)
	end)

	return state
end

local function getScale(guiObject)
	local scale = guiObject:FindFirstChild("DialoguePopScale")
	if not scale then
		scale = Instance.new("UIScale")
		scale.Name = "DialoguePopScale"
		scale.Parent = guiObject
	end
	return scale
end

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

	tween(guiObject, info, props)

	local stroke = getStroke(guiObject)
	if stroke and values.strokeTransparency ~= nil then
		tween(stroke, info, { Transparency = values.strokeTransparency })
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

local function getViewportHeight()
	local camera = workspace.CurrentCamera
	return camera and camera.ViewportSize.Y or 720
end

local function captureVisibleUi(dialogueGui)
	local snapshots = {}

	for _, gui in ipairs(playerGui:GetChildren()) do
		if gui ~= dialogueGui and gui:IsA("ScreenGui") and gui.Enabled then
			local guiSnapshot = {
				gui = gui,
				enabled = gui.Enabled,
				volatile = VOLATILE_ROUND_UI[gui.Name] == true,
				objects = {},
				roots = {},
			}

			for _, child in ipairs(gui:GetChildren()) do
				if child:IsA("GuiObject") and child.Visible then
					local direction = child.AbsolutePosition.Y + child.AbsoluteSize.Y * 0.5 < getViewportHeight() * 0.5 and -1 or 1
					table.insert(guiSnapshot.roots, {
						object = child,
						position = child.Position,
						offscreen = child.Position + UDim2.fromScale(0, direction * 0.28),
					})
				end
			end

			for _, descendant in ipairs(gui:GetDescendants()) do
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
				tween(root.object, info, { Position = root.offscreen })
			end
		end

		for guiObject, state in pairs(guiSnapshot.objects) do
			if guiObject.Parent and state.visible then
				tweenTransparency(guiObject, transparentValues(guiObject), info)
			end
		end
	end

	task.wait(UI_FADE_TIME)
end

local function fadeUiIn(snapshots)
	local info = TweenInfo.new(UI_FADE_TIME, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

	for _, guiSnapshot in ipairs(snapshots) do
		if guiSnapshot.volatile then
			continue
		end

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
				tween(root.object, info, { Position = root.position })
			end
		end

		for guiObject, state in pairs(guiSnapshot.objects) do
			if guiObject.Parent and state.visible then
				tweenTransparency(guiObject, state.transparency, info)
			end
		end
	end
end

local function hideDialogueObject(guiObject)
	if not guiObject or not guiObject:IsA("GuiObject") then
		return nil
	end

	local state = {
		position = guiObject.Position,
		rotation = guiObject.Rotation,
		transparency = captureTransparency(guiObject),
		scale = getScale(guiObject),
	}

	guiObject.Visible = false
	state.scale.Scale = 0.1
	applyTransparency(guiObject, transparentValues(guiObject))

	return state
end

local function popIn(guiObject, state, delayTime, duration, overshootScale)
	if not guiObject or not state then
		return
	end

	task.delay(delayTime, function()
		if not guiObject.Parent then
			return
		end

		guiObject.Visible = true
		playRandomUiSound(OPEN_SOUND_IDS, 0.75, 6)
		guiObject.Position = state.position + UDim2.fromScale(0, 0.035)
		guiObject.Rotation = state.rotation - 3
		state.scale.Scale = 0.18

		local popInfo = TweenInfo.new(duration, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		local fadeInfo = TweenInfo.new(duration * 0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

		tween(guiObject, popInfo, {
			Position = state.position,
			Rotation = state.rotation,
		})
		tween(state.scale, TweenInfo.new(duration * 0.72, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Scale = overshootScale or 1,
		})
		task.delay(duration * 0.45, function()
			if state.scale.Parent then
				tween(state.scale, TweenInfo.new(duration * 0.32, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1 })
			end
		end)
		tweenTransparency(guiObject, state.transparency, fadeInfo)
	end)
end

local function popOut(guiObject, state, delayTime)
	if not guiObject or not state then
		return
	end

	task.delay(delayTime, function()
		if not guiObject.Parent then
			return
		end

		playRandomUiSound(CLOSE_SOUND_IDS, 0.62, 5)

		local info = TweenInfo.new(OUT_TIME, Enum.EasingStyle.Back, Enum.EasingDirection.In)
		tween(guiObject, info, {
			Position = state.position + UDim2.fromScale(0, 0.03),
			Rotation = state.rotation + 2,
		})
		tween(state.scale, info, { Scale = 0.08 })
		tweenTransparency(guiObject, transparentValues(guiObject), TweenInfo.new(OUT_TIME * 0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.In))

		task.delay(OUT_TIME, function()
			if guiObject.Parent then
				guiObject.Visible = false
				guiObject.Position = state.position
				guiObject.Rotation = state.rotation
				state.scale.Scale = 1
				applyTransparency(guiObject, state.transparency)
			end
		end)
	end)
end

local function playDialogue(request)
	print("[Dialogue] Round one dialogue triggered")
	if playing then
		table.insert(dialogueQueue, request)
		return
	end

	playing = true
	player:SetAttribute(DIALOGUE_ACTIVE_ATTRIBUTE, true)
	local ok, err = pcall(function()
		local messageText = request.messageText
		local options = request.options or {}
		options = options or {}

		if not dialogueGui or not dialogueGui:IsA("ScreenGui") then
			warn("[Dialogue] Missing StarterGui Dialogue ScreenGui; sync the toy before testing.")
			return
		end

		local panel = dialogueGui:FindFirstChild("Panel")
		local figure = dialogueGui:FindFirstChild("Figure")
		local title = dialogueGui:FindFirstChild("Title")
		local dialogue = dialogueGui:WaitForChild("Dialogue", 5)

		if not dialogue or not dialogue:IsA("TextLabel") then
			warn("[Dialogue] Dialogue UI needs a TextLabel named Dialogue.")
			return
		end

		if typeof(messageText) == "string" and messageText ~= "" then
			dialogue.Text = messageText
		end

		local snapshots = captureVisibleUi(dialogueGui)
		dialogueGui.Enabled = true
		dialogueGui.DisplayOrder = math.max(dialogueGui.DisplayOrder, 120)

		local panelState = hideDialogueObject(panel)
		local figureState = hideDialogueObject(figure)
		local titleState = hideDialogueObject(title)
		local dialogueState = hideDialogueObject(dialogue)

		fadeUiOut(snapshots)

		popIn(panel, panelState, 0, PANEL_POP_TIME, 1.04)
		popIn(figure, figureState, FIGURE_DELAY, FIGURE_POP_TIME, 1.08)
		popIn(title, titleState, TITLE_DELAY, TITLE_POP_TIME, 1.03)
		local dialogueDelay = panel and DIALOGUE_DELAY or 0
		local voiceState = nil
		task.delay(dialogueDelay, function()
			voiceState = playDialogueVoice(options.soundId, options.volume)
		end)
		popIn(dialogue, dialogueState, dialogueDelay, DIALOGUE_POP_TIME, 1.02)

		task.wait(dialogueDelay + DIALOGUE_POP_TIME + HOLD_TIME)
		while voiceState and not voiceState.finished do
			task.wait()
		end

		popOut(dialogue, dialogueState, 0)
		popOut(title, titleState, 0.08)
		popOut(figure, figureState, 0.16)
		popOut(panel, panelState, 0.24)

		task.wait(0.24 + OUT_TIME)
		fadeUiIn(snapshots)

		task.wait(UI_FADE_TIME)
	end)

	if not ok then
		warn("[Dialogue] Dialogue animation failed:", err)
	end

	player:SetAttribute(DIALOGUE_ACTIVE_ATTRIBUTE, false)
	playing = false

	if #dialogueQueue > 0 then
		task.defer(playDialogue, table.remove(dialogueQueue, 1))
	end
end

local function receiveDialogue(requestIdOrMessage, messageOrOptions, maybeOptions)
	local requestId = nil
	local messageText = requestIdOrMessage
	local options = messageOrOptions

	if typeof(requestIdOrMessage) == "number" then
		requestId = requestIdOrMessage
		messageText = messageOrOptions
		options = maybeOptions

		if acknowledgedRequests[requestId] then
			ackRemote:FireServer(requestId)
			return
		end

		acknowledgedRequests[requestId] = true
		ackRemote:FireServer(requestId)
	end

	playDialogue({
		requestId = requestId,
		messageText = messageText,
		options = options,
	})
end

remote.OnClientEvent:Connect(receiveDialogue)
print("[Dialogue] Remote listener connected")

local function pollPendingDialogues()
	if polling then
		return
	end

	polling = true
	task.spawn(function()
		while dialogueGui.Parent do
			local ok, pending = pcall(function()
				return pollRemote:InvokeServer()
			end)

			if ok and typeof(pending) == "table" then
				for _, request in ipairs(pending) do
					if typeof(request) == "table" and typeof(request.id) == "number" then
						ackRemote:FireServer(request.id)
						if not acknowledgedRequests[request.id] then
							acknowledgedRequests[request.id] = true
							playDialogue({
								requestId = request.id,
								messageText = request.messageText,
								options = request.options,
							})
						end
					end
				end
			end

			task.wait(1)
		end
	end)
end

pollPendingDialogues()
