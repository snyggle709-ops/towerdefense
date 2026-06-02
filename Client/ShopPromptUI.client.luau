local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local tower = workspace:WaitForChild("Tower")
local model = tower:WaitForChild("Model")
local proximityPart = model:WaitForChild("ProximityPart")
local prompt = proximityPart:WaitForChild("ProximityPrompt")

local billboardGui = Instance.new("BillboardGui")
billboardGui.Size = UDim2.new(0, 300, 0, 70)
billboardGui.StudsOffset = Vector3.new(0, 5, 0)
billboardGui.AlwaysOnTop = true
billboardGui.Parent = proximityPart

local container = Instance.new("Frame")
container.BackgroundTransparency = 1
container.Size = UDim2.new(1, 0, 1, 0)
container.Parent = billboardGui

local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Horizontal
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.VerticalAlignment = Enum.VerticalAlignment.Center
layout.Padding = UDim.new(0, 20)
layout.Parent = container

local keyBox = Instance.new("Frame")
keyBox.Size = UDim2.new(0, 60, 0, 60)
keyBox.BackgroundColor3 = Color3.new(0, 0, 0)
keyBox.BorderSizePixel = 0
keyBox.BackgroundTransparency = 1
keyBox.Parent = container

local keyCorner = Instance.new("UICorner")
keyCorner.CornerRadius = UDim.new(0, 8)
keyCorner.Parent = keyBox

local keyStroke = Instance.new("UIStroke")
keyStroke.Thickness = 3
keyStroke.Color = Color3.new(1, 1, 1)
keyStroke.Transparency = 1
keyStroke.Parent = keyBox

local keyLabel = Instance.new("TextLabel")
keyLabel.Size = UDim2.new(1, 0, 1, 0)
keyLabel.BackgroundTransparency = 1
keyLabel.Text = "E"
keyLabel.TextColor3 = Color3.new(1, 1, 1)
keyLabel.TextSize = 40
keyLabel.FontFace = Font.new("rbxassetid://12187371840", Enum.FontWeight.Bold)
keyLabel.TextTransparency = 1
keyLabel.Parent = keyBox

local actionLabel = Instance.new("TextLabel")
actionLabel.Size = UDim2.new(0, 200, 1, 0)
actionLabel.BackgroundTransparency = 1
actionLabel.Text = "Open Upgrades"
actionLabel.TextColor3 = Color3.new(1, 1, 1)
actionLabel.TextSize = 28
actionLabel.FontFace = Font.new("rbxassetid://12187371840")
actionLabel.TextXAlignment = Enum.TextXAlignment.Left
actionLabel.TextTransparency = 1
actionLabel.Parent = container

local actionStroke = Instance.new("UIStroke")
actionStroke.Thickness = 2
actionStroke.Color = Color3.new(0, 0, 0)
actionStroke.Transparency = 1
actionStroke.Parent = actionLabel

billboardGui.Enabled = false

prompt.PromptShown:Connect(function()
	billboardGui.Enabled = true
	container.Size = UDim2.new(0.7, 0, 0.7, 0)
	TweenService:Create(container, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size = UDim2.new(1, 0, 1, 0)}):Play()
	TweenService:Create(keyBox, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = 0}):Play()
	TweenService:Create(keyStroke, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Transparency = 0}):Play()
	TweenService:Create(keyLabel, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {TextTransparency = 0}):Play()
	TweenService:Create(actionLabel, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {TextTransparency = 0}):Play()
	TweenService:Create(actionStroke, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Transparency = 0.3}):Play()
end)

prompt.PromptHidden:Connect(function()
	TweenService:Create(container, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Size = UDim2.new(0.5, 0, 0.5, 0)}):Play()
	TweenService:Create(keyBox, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {BackgroundTransparency = 1}):Play()
	TweenService:Create(keyStroke, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Transparency = 1}):Play()
	TweenService:Create(keyLabel, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {TextTransparency = 1}):Play()
	TweenService:Create(actionLabel, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {TextTransparency = 1}):Play()
	TweenService:Create(actionStroke, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Transparency = 1}):Play()
	task.delay(0.2, function()
		billboardGui.Enabled = false
	end)
end)