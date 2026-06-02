local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local WarningRemote = game.ReplicatedStorage:WaitForChild("WarningRemote")
local GameOverRemote = game.ReplicatedStorage:WaitForChild("GameOverRemote")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local warningGui = playerGui:WaitForChild("Warning")
local label = warningGui:WaitForChild("TextLabel")
local stroke = label:FindFirstChildOfClass("UIStroke")

local TYPE_TIME = 1.35
local DELETE_TIME = 0.65
local activeToken = 0
local dead = false
local roundWarningMessage = nil
local EXTRACTOR_OVERHEAT_MESSAGE = "One of your extractors overheated. Restart it before it overheats to prevent this."

label.BackgroundTransparency = 1
label.TextTransparency = 1
if stroke then
	stroke.Transparency = 1
end

local function textLength(text)
	return utf8.len(text) or #text
end

local function textSlice(text, index)
	if index <= 0 then
		return ""
	end

	local bytePos = utf8.offset(text, index + 1)
	if bytePos then
		return string.sub(text, 1, bytePos - 1)
	end

	return text
end

local function typewrite(text, duration, token)
	local length = textLength(text)
	if length == 0 then
		label.Text = ""
		return
	end

	local stepTime = duration / length
	for i = 1, length do
		if dead or token ~= activeToken then
			return
		end
		label.Text = textSlice(text, i)
		task.wait(stepTime)
	end
	label.Text = text
end

local function backspace(duration, token)
	local text = label.Text
	local length = textLength(text)
	if length == 0 then
		return
	end

	local stepTime = duration / length
	for i = length, 0, -1 do
		if dead or token ~= activeToken then
			return
		end
		label.Text = textSlice(text, i)
		task.wait(stepTime)
	end
	label.Text = ""
end

local function fadeVisible()
	label.BackgroundTransparency = 1
	label.TextTransparency = 1
	if stroke then
		stroke.Transparency = 1
	end
	TweenService:Create(label, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		TextTransparency = 0,
	}):Play()
	if stroke then
		TweenService:Create(stroke, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Transparency = 0,
		}):Play()
	end
end

local function fadeHidden()
	TweenService:Create(label, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		TextTransparency = 1,
	}):Play()
	if stroke then
		TweenService:Create(stroke, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Transparency = 1,
		}):Play()
	end
end

WarningRemote.OnClientEvent:Connect(function(action, message, messageType)
	if dead then
		return
	end

	activeToken += 1
	local token = activeToken

	if action == "Show" then
		if messageType == "Round" then
			roundWarningMessage = message
		end

		task.spawn(function()
			fadeVisible()
			label.Text = ""
			task.wait(0.15)
			typewrite(message or "", TYPE_TIME, token)
		end)
	elseif action == "Hide" then
		roundWarningMessage = nil
		task.spawn(function()
			backspace(DELETE_TIME, token)
			if token ~= activeToken then
				return
			end
			fadeHidden()
		end)
	elseif action == "ExtractorOverheated" then
		local warningToRestore = roundWarningMessage
		task.spawn(function()
			if textLength(label.Text) > 0 then
				backspace(DELETE_TIME, token)
			end
			if token ~= activeToken then
				return
			end

			fadeVisible()
			task.wait(0.1)
			typewrite(EXTRACTOR_OVERHEAT_MESSAGE, TYPE_TIME, token)
			if token ~= activeToken then
				return
			end

			task.wait(10)
			if token ~= activeToken then
				return
			end

			backspace(DELETE_TIME, token)
			if token ~= activeToken then
				return
			end

			if warningToRestore and roundWarningMessage == warningToRestore then
				typewrite(warningToRestore, TYPE_TIME, token)
			else
				fadeHidden()
			end
		end)
	end
end)

GameOverRemote.OnClientEvent:Connect(function()
	dead = true
	activeToken += 1
	label.BackgroundTransparency = 1
	TweenService:Create(label, TweenInfo.new(0.25), {
		TextTransparency = 1,
	}):Play()
	if stroke then
		TweenService:Create(stroke, TweenInfo.new(0.25), { Transparency = 1 }):Play()
	end
end)
