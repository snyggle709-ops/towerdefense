local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local BILLBOARD_NAME = "ExtractorHeatingBillboardClient"
local SCREEN_GUI_NAME = "ExtractorControlPanelHeatIndicators"
local HEAT_ICON = "rbxassetid://129960581618789"
local SILKSCREEN_FONT = "rbxassetid://12187371840"
local HEAT_TEXT_COLOR = Color3.fromRGB(255, 42, 30)
local placedTowersFolder = workspace:WaitForChild("PlacedTowers", 10)

local activeBillboards = {}
local activeIndicators = {}
local indicatorGui = nil

local function getPlacedTowersFolder()
	if placedTowersFolder and placedTowersFolder.Parent then
		return placedTowersFolder
	end

	placedTowersFolder = workspace:FindFirstChild("PlacedTowers")
	return placedTowersFolder
end

local function isExtractor(instance)
	if not instance:IsA("Model") then
		return false
	end

	local towerType = instance:FindFirstChild("TowerType")
	return towerType and towerType.Value == "Extractor"
end

local function getAdornee(tower)
	return tower:FindFirstChild("HumanoidRootPart", true) or tower:FindFirstChildWhichIsA("BasePart", true)
end

local function shouldShow(tower)
	local heatVal = tower:FindFirstChild("ExtractorHeat")
	local stateVal = tower:FindFirstChild("ExtractorState")
	local stateText = stateVal and stateVal.Value or ""

	return (heatVal and heatVal.Value > 0)
		or string.sub(stateText, 1, #"Overheated") == "Overheated"
		or string.sub(stateText, 1, #"Restarting") == "Restarting"
end

local function startsWith(text, prefix)
	return string.sub(text, 1, #prefix) == prefix
end

local function getHeatText(tower)
	local heatVal = tower:FindFirstChild("ExtractorHeat")
	local stateVal = tower:FindFirstChild("ExtractorState")
	local stateText = stateVal and stateVal.Value or ""

	if startsWith(stateText, "Overheated") then
		return string.upper(stateText)
	end

	if startsWith(stateText, "Restarting") then
		return string.upper(stateText)
	end

	if heatVal and heatVal.Value > 0 then
		return string.format("OVERHEATING - %d%%", math.floor(heatVal.Value + 0.5))
	end

	return ""
end

local function removeBillboard(tower)
	local builtInBillboard = tower:FindFirstChild("ExtractorHeatingBillboard", true)
	if builtInBillboard then
		builtInBillboard.Enabled = false
	end

	local billboard = activeBillboards[tower]
	if billboard then
		billboard:Destroy()
		activeBillboards[tower] = nil
	end
end

local function ensureBillboard(tower)
	local builtInBillboard = tower:FindFirstChild("ExtractorHeatingBillboard", true)
	if builtInBillboard then
		builtInBillboard.Enabled = false
	end

	local existing = activeBillboards[tower]
	if existing and existing.Parent then
		return
	end

	local adornee = getAdornee(tower)
	if not adornee then
		return
	end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = BILLBOARD_NAME
	billboard.Adornee = adornee
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.MaxDistance = 100000
	billboard.Size = UDim2.new(0, 170, 0, 116)
	billboard.StudsOffset = Vector3.new(0, 5, 0)
	billboard.Parent = adornee

	local icon = Instance.new("ImageLabel")
	icon.Name = "Icon"
	icon.BackgroundTransparency = 1
	icon.Image = HEAT_ICON
	icon.ImageTransparency = 0
	icon.ScaleType = Enum.ScaleType.Fit
	icon.AnchorPoint = Vector2.new(0.5, 0)
	icon.Position = UDim2.new(0.5, 0, 0, 0)
	icon.Size = UDim2.new(0, 76, 0, 76)
	icon.Parent = billboard

	local text = Instance.new("TextLabel")
	text.Name = "HeatText"
	text.BackgroundTransparency = 1
	text.FontFace = Font.new(SILKSCREEN_FONT, Enum.FontWeight.Bold)
	text.Text = getHeatText(tower)
	text.TextColor3 = HEAT_TEXT_COLOR
	text.TextScaled = true
	text.TextStrokeColor3 = Color3.fromRGB(35, 0, 0)
	text.TextStrokeTransparency = 0.1
	text.AnchorPoint = Vector2.new(0.5, 0)
	text.Position = UDim2.new(0.5, 0, 0, 78)
	text.Size = UDim2.new(1, 0, 0, 34)
	text.Parent = billboard

	activeBillboards[tower] = billboard
end

local function updateBillboard(tower, billboard)
	local text = billboard:FindFirstChild("HeatText")
	if text and text:IsA("TextLabel") then
		text.Text = getHeatText(tower)
	end
end

local function getIndicatorGui()
	if indicatorGui and indicatorGui.Parent then
		return indicatorGui
	end

	indicatorGui = Instance.new("ScreenGui")
	indicatorGui.Name = SCREEN_GUI_NAME
	indicatorGui.IgnoreGuiInset = true
	indicatorGui.ResetOnSpawn = false
	indicatorGui.DisplayOrder = 850
	indicatorGui.Parent = playerGui
	return indicatorGui
end

local function createIndicator(tower)
	local frame = Instance.new("Frame")
	frame.Name = "HeatDirectionIndicator"
	frame.BackgroundTransparency = 1
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Size = UDim2.fromOffset(126, 92)
	frame.Visible = false
	frame.Parent = getIndicatorGui()

	local icon = Instance.new("ImageLabel")
	icon.Name = "Icon"
	icon.BackgroundTransparency = 1
	icon.Image = HEAT_ICON
	icon.ImageTransparency = 0.05
	icon.ScaleType = Enum.ScaleType.Fit
	icon.AnchorPoint = Vector2.new(0.5, 0)
	icon.Position = UDim2.new(0.5, 0, 0, 0)
	icon.Size = UDim2.fromOffset(58, 58)
	icon.Parent = frame

	local text = Instance.new("TextLabel")
	text.Name = "HeatText"
	text.BackgroundTransparency = 1
	text.FontFace = Font.new(SILKSCREEN_FONT, Enum.FontWeight.Bold)
	text.Text = getHeatText(tower)
	text.TextColor3 = HEAT_TEXT_COLOR
	text.TextScaled = true
	text.TextStrokeColor3 = Color3.fromRGB(35, 0, 0)
	text.TextStrokeTransparency = 0.1
	text.AnchorPoint = Vector2.new(0.5, 0)
	text.Position = UDim2.new(0.5, 0, 0, 58)
	text.Size = UDim2.new(1, 0, 0, 28)
	text.Parent = frame

	local scale = Instance.new("UIScale")
	scale.Scale = 0.7
	scale.Parent = frame
	TweenService:Create(scale, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()

	activeIndicators[tower] = frame
	return frame
end

local function removeIndicator(tower)
	local frame = activeIndicators[tower]
	if frame then
		frame:Destroy()
		activeIndicators[tower] = nil
	end
end

local function clearIndicators()
	for tower in pairs(activeIndicators) do
		removeIndicator(tower)
	end
end

local function getScreenEdgePosition(worldPosition)
	local camera = workspace.CurrentCamera
	if not camera then
		return nil, 0
	end

	local viewportSize = camera.ViewportSize
	local center = viewportSize * 0.5
	local screenPosition = camera:WorldToViewportPoint(worldPosition)
	local direction = Vector2.new(screenPosition.X - center.X, screenPosition.Y - center.Y)

	if screenPosition.Z <= 0 then
		direction = -direction
	end

	if direction.Magnitude < 0.01 then
		direction = Vector2.new(0, -1)
	end

	local margin = 66
	local halfWidth = math.max(1, center.X - margin)
	local halfHeight = math.max(1, center.Y - margin)
	local scale = math.min(
		math.abs(halfWidth / math.max(math.abs(direction.X), 0.001)),
		math.abs(halfHeight / math.max(math.abs(direction.Y), 0.001))
	)

	local edgePosition = center + (direction * scale)
	local rotation = math.deg(math.atan2(direction.Y, direction.X)) + 90
	return edgePosition, rotation
end

local function isWorldPositionOnScreen(worldPosition)
	local camera = workspace.CurrentCamera
	if not camera then
		return false
	end

	local viewportPosition = camera:WorldToViewportPoint(worldPosition)
	if viewportPosition.Z <= 0 then
		return false
	end

	local viewportSize = camera.ViewportSize
	local padding = 34
	return viewportPosition.X >= padding
		and viewportPosition.X <= viewportSize.X - padding
		and viewportPosition.Y >= padding
		and viewportPosition.Y <= viewportSize.Y - padding
end

local function updateScreenIndicators()
	local searchRoot = getPlacedTowersFolder()
	if not searchRoot then
		clearIndicators()
		return
	end

	local seen = {}
	for _, tower in searchRoot:GetChildren() do
		if isExtractor(tower) and shouldShow(tower) then
			local adornee = getAdornee(tower)
			if adornee then
				if isWorldPositionOnScreen(adornee.Position) then
					removeIndicator(tower)
				else
					seen[tower] = true
					local frame = activeIndicators[tower] or createIndicator(tower)
					local position, rotation = getScreenEdgePosition(adornee.Position)
					if position then
						frame.Visible = true
						frame.Position = UDim2.fromOffset(position.X, position.Y)
						frame.Rotation += (rotation - frame.Rotation) * 0.18
						local text = frame:FindFirstChild("HeatText")
						if text and text:IsA("TextLabel") then
							text.Text = getHeatText(tower)
						end
					end
				end
			end
		end
	end

	for tower in pairs(activeIndicators) do
		if not seen[tower] then
			removeIndicator(tower)
		end
	end
end

RunService.RenderStepped:Connect(updateScreenIndicators)

while true do
	for tower, billboard in activeBillboards do
		if not tower.Parent or not billboard.Parent or not shouldShow(tower) then
			removeBillboard(tower)
		else
			updateBillboard(tower, billboard)
		end
	end

	local searchRoot = getPlacedTowersFolder()
	if not searchRoot then
		task.wait(0.25)
		continue
	end

	for _, instance in searchRoot:GetChildren() do
		if isExtractor(instance) then
			if shouldShow(instance) then
				ensureBillboard(instance)
				local billboard = activeBillboards[instance]
				if billboard then
					updateBillboard(instance, billboard)
				end
			else
				removeBillboard(instance)
			end
		end
	end

	task.wait(0.25)
end
