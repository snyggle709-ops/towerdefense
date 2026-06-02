local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local camera = workspace.CurrentCamera

local HIGHLIGHT_RADIUS = 15
local SELECTION_RADIUS = 15
local RADIUS_CYLINDER_HEIGHT = 3
local UPDATE_INTERVAL = 0.12
local towerPopBusy = {}
local TOWER_POP_COOLDOWN = 0.18
local selectedTower = nil
local radiusPreview = nil
local highlightedTowers = {}
local trackedTowers = {}
local sellingTowers = {}
local scanTimer = 0
local CONTROL_PANEL_CAMERA_ATTRIBUTE = "ControlPanelCameraActive"

local function isControlPanelMode()
	return player:GetAttribute(CONTROL_PANEL_CAMERA_ATTRIBUTE) == true
end

-- CREATE BINDABLE EVENT FOR TOWER SELECTION COMMUNICATION
local TowerSelectedEvent = Instance.new("BindableEvent")
TowerSelectedEvent.Name = "TowerSelectedEvent"
TowerSelectedEvent.Parent = ReplicatedStorage

local ClearTowerSelectionEvent = ReplicatedStorage:FindFirstChild("ClearTowerSelectionEvent")
if not ClearTowerSelectionEvent then
	ClearTowerSelectionEvent = Instance.new("BindableEvent")
	ClearTowerSelectionEvent.Name = "ClearTowerSelectionEvent"
	ClearTowerSelectionEvent.Parent = ReplicatedStorage
end
local UI_SOUND_IDS = {
	AddHighlight = "rbxassetid://129333831475604",
	RemoveHighlight = "rbxassetid://129086741682190",
}

local UI_SOUND_VOLUMES = {
	AddHighlight = 0.9,
	RemoveHighlight = 0.9,
}

local uiSounds = {}
for name, id in UI_SOUND_IDS do
	local s = Instance.new("Sound")
	s.Name = "TowerSelectUI_" .. name
	s.SoundId = id
	s.Volume = UI_SOUND_VOLUMES[name] or 0.8
	s.Parent = SoundService
	uiSounds[name] = s
end

local function playUISound(name)
	local s = uiSounds[name]
	if not s then
		return
	end

	local clone = s:Clone()
	clone.Parent = SoundService
	clone:Play()
	clone.Ended:Once(function()
		clone:Destroy()
	end)
end

local SELECT_POP_COOLDOWN = 0.18
local selectPopBusy = {}

local function popHighlight(tower)
	local highlight = highlightedTowers[tower]
	if not highlight then
		return
	end

	if selectPopBusy[tower] then
		return
	end

	selectPopBusy[tower] = true

	local popOut = TweenService:Create(highlight, TweenInfo.new(0.07, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		LineThickness = 0.09,
		SurfaceTransparency = 0.7,
	})

	local popBack = TweenService:Create(highlight, TweenInfo.new(0.14, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		LineThickness = 0.04,
		SurfaceTransparency = 0.85,
	})

	popOut:Play()
	popOut.Completed:Once(function()
		if highlight and highlight.Parent then
			popBack:Play()
		end
	end)

	task.delay(SELECT_POP_COOLDOWN, function()
		selectPopBusy[tower] = nil
	end)
end
local function isTower(obj)
	return obj:FindFirstChild("TowerType")
		or obj.Name == "Extractor"
		or obj:FindFirstChild("ExtractorEnabled")
		or (obj:FindFirstChild("Radius")
		and obj:FindFirstChild("Damage")
		and obj:FindFirstChild("AttackSpeed"))
end

local function getPosition(obj)
	if obj:IsA("BasePart") then
		return obj.Position
	end

	if obj:IsA("Model") then
		return obj:GetPivot().Position
	end
end

local function getCharacterPosition()
	local hrp = character:FindFirstChild("HumanoidRootPart")
	return hrp and hrp.Position or nil
end
local function popTowerModel(tower)
	if not tower or towerPopBusy[tower] then
		return
	end

	towerPopBusy[tower] = true

	local totalTime = 0.5 -- change this only
	local popScale = 1.28 -- how strong the pop is

	local growTime = totalTime * 0.35
	local shrinkTime = totalTime - growTime

	if tower:IsA("Model") then
		local pivot = tower:GetPivot()
		local parts = {}

		for _, obj in ipairs(tower:GetDescendants()) do
			if obj:IsA("BasePart") then
				local relative = pivot:ToObjectSpace(obj.CFrame)
				local relativePos = relative.Position
				local relativeRot = relative - relative.Position

				local targetRelative = CFrame.new(relativePos * popScale) * relativeRot
				local targetCFrame = pivot * targetRelative

				table.insert(parts, {
					part = obj,
					originalSize = obj.Size,
					originalCFrame = obj.CFrame,
					targetSize = obj.Size * popScale,
					targetCFrame = targetCFrame,
				})
			end
		end

		for _, data in ipairs(parts) do
			TweenService:Create(
				data.part,
				TweenInfo.new(growTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{
					Size = data.targetSize,
					CFrame = data.targetCFrame,
				}
			):Play()
		end

		task.delay(growTime, function()
			for _, data in ipairs(parts) do
				if data.part and data.part.Parent then
					TweenService:Create(
						data.part,
						TweenInfo.new(shrinkTime, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
						{
							Size = data.originalSize,
							CFrame = data.originalCFrame,
						}
					):Play()
				end
			end
		end)

	elseif tower:IsA("BasePart") then
		local originalSize = tower.Size
		local originalCFrame = tower.CFrame
		local targetSize = originalSize * popScale

		TweenService:Create(
			tower,
			TweenInfo.new(growTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{
				Size = targetSize,
			}
		):Play()

		task.delay(growTime, function()
			if tower and tower.Parent then
				TweenService:Create(
					tower,
					TweenInfo.new(shrinkTime, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
					{
						Size = originalSize,
						CFrame = originalCFrame,
					}
				):Play()
			end
		end)
	end

	task.delay(totalTime, function()
		towerPopBusy[tower] = nil
	end)
end
local function addHighlight(tower)
	if sellingTowers[tower] then
		return
	end

	if highlightedTowers[tower] then
		return
	end

	local highlight = Instance.new("SelectionBox")
	highlight.Adornee = tower
	highlight.Color3 = Color3.fromRGB(255, 220, 50)
	highlight.LineThickness = 0.04
	highlight.SurfaceTransparency = 0.85
	highlight.SurfaceColor3 = Color3.fromRGB(255, 220, 50)
	highlight.Transparency = 1
	highlight.Parent = workspace
	highlightedTowers[tower] = highlight

	playUISound("AddHighlight")

	TweenService:Create(highlight, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Transparency = 0,
	}):Play()
end

local function removeHighlight(tower)
	local highlight = highlightedTowers[tower]
	if not highlight then
		return
	end

	playUISound("RemoveHighlight")

	local tween = TweenService:Create(highlight, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Transparency = 1,
	})
	tween:Play()
	tween.Completed:Once(function()
		highlight:Destroy()
	end)

	highlightedTowers[tower] = nil
end

local function removeHighlightImmediate(tower)
	local highlight = highlightedTowers[tower]
	if not highlight then
		return
	end

	highlightedTowers[tower] = nil
	selectPopBusy[tower] = nil
	highlight:Destroy()
end

local function getBottomY(obj)
	if obj:IsA("BasePart") then
		return obj.Position.Y - (obj.Size.Y / 2)
	end

	if obj:IsA("Model") then
		local boundingCFrame, boundingSize = obj:GetBoundingBox()
		return boundingCFrame.Position.Y - (boundingSize.Y / 2)
	end

	return nil
end

local function showRadiusPreview(tower)
	if radiusPreview then
		radiusPreview:Destroy()
		radiusPreview = nil
	end

	local radiusVal = tower:FindFirstChild("Radius")
	local radius = radiusVal and radiusVal.Value or 20
	local pos = getPosition(tower)
	local bottomY = getBottomY(tower)
	if not pos or not bottomY then
		return
	end

	local cylinder = Instance.new("Part")
	cylinder.Shape = Enum.PartType.Cylinder
	cylinder.Size = Vector3.new(RADIUS_CYLINDER_HEIGHT, 0.1, 0.1)
	cylinder.CFrame = CFrame.new(pos.X, bottomY, pos.Z) * CFrame.Angles(0, 0, math.rad(90))
	cylinder.Anchored = true
	cylinder.CanCollide = false
	cylinder.CanQuery = false
	cylinder.CastShadow = false
	cylinder.Material = Enum.Material.Neon
	cylinder.Color = Color3.fromRGB(255, 220, 50)
	cylinder.Transparency = 0.5
	cylinder.Parent = workspace
	radiusPreview = cylinder

	local highlight = Instance.new("Highlight")
	highlight.Adornee = cylinder
	highlight.FillColor = Color3.fromRGB(255, 220, 50)
	highlight.OutlineColor = Color3.fromRGB(255, 220, 50)
	highlight.FillTransparency = 0.5
	highlight.OutlineTransparency = 0
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Parent = cylinder

	TweenService:Create(cylinder, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = Vector3.new(RADIUS_CYLINDER_HEIGHT, radius * 2, radius * 2),
		Transparency = 0.8,
	}):Play()
end

local function hideRadiusPreview()
	if not radiusPreview then
		return
	end

	local preview = radiusPreview
	radiusPreview = nil

	TweenService:Create(preview, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Size = Vector3.new(RADIUS_CYLINDER_HEIGHT, 0.1, 0.1),
		Transparency = 1,
	}):Play()

	task.delay(0.32, function()
		if preview then
			preview:Destroy()
		end
	end)
end

local function deselectTower()
	if not selectedTower then
		return
	end

	selectedTower = nil
	hideRadiusPreview()
	-- FIRE EVENT WITH NIL TO SIGNAL DESELECTION
	TowerSelectedEvent:Fire(nil)
end

local function selectTower(tower)
	if selectedTower == tower then
		popTowerModel(tower)
		return
	end

	deselectTower()
	selectedTower = tower
	popTowerModel(tower)
	showRadiusPreview(tower)
	-- FIRE EVENT WITH THE SELECTED TOWER
	TowerSelectedEvent:Fire(tower)
end

local function registerTowerCandidate(obj)
	if isTower(obj) then
		trackedTowers[obj] = true
		return
	end

	local current = obj.Parent
	local placedTowersFolder = workspace:FindFirstChild("PlacedTowers")
	while current and current ~= placedTowersFolder and current ~= workspace do
		if isTower(current) then
			trackedTowers[current] = true
			return
		end
		current = current.Parent
	end
end

local function unregisterTowerCandidate(obj)
	if not trackedTowers[obj] then
		return
	end

	trackedTowers[obj] = nil
	sellingTowers[obj] = nil
	removeHighlight(obj)

	if selectedTower == obj then
		deselectTower()
	end
end

local placedTowersFolder = workspace:WaitForChild("PlacedTowers")

for _, obj in ipairs(placedTowersFolder:GetChildren()) do
	registerTowerCandidate(obj)
end

placedTowersFolder.ChildAdded:Connect(registerTowerCandidate)
placedTowersFolder.ChildRemoved:Connect(unregisterTowerCandidate)

ClearTowerSelectionEvent.Event:Connect(function(towerToClear)
	if towerToClear then
		sellingTowers[towerToClear] = true
		removeHighlightImmediate(towerToClear)
	end

	if selectedTower and (not towerToClear or selectedTower == towerToClear) then
		selectedTower = nil
		hideRadiusPreview()
	end
end)

RunService.Heartbeat:Connect(function(dt)
	scanTimer += dt
	if scanTimer < UPDATE_INTERVAL then
		return
	end

	scanTimer = 0

	local charPos = getCharacterPosition()
	if not charPos then
		return
	end

	local currentInRange = {}
	for tower in pairs(trackedTowers) do
		if not tower.Parent then
			unregisterTowerCandidate(tower)
			continue
		end

		if sellingTowers[tower] then
			removeHighlightImmediate(tower)
			continue
		end

		local towerPos = getPosition(tower)
		if not towerPos then
			continue
		end

		if isControlPanelMode() or (charPos - towerPos).Magnitude <= HIGHLIGHT_RADIUS then
			currentInRange[tower] = true
			addHighlight(tower)
		end
	end

	for tower in pairs(highlightedTowers) do
		if sellingTowers[tower] then
			removeHighlightImmediate(tower)
			continue
		end

		if not currentInRange[tower] then
			removeHighlight(tower)
			if selectedTower == tower then
				deselectTower()
			end
		end
	end
end)

UserInputService.InputBegan:Connect(function(input, gpe)
	if gpe or input.UserInputType ~= Enum.UserInputType.MouseButton1 then
		return
	end

	local charPos = getCharacterPosition()
	if not charPos then
		return
	end

	local mouse = player:GetMouse()
	local unitRay = camera:ScreenPointToRay(mouse.X, mouse.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {character}

	local result = workspace:Raycast(unitRay.Origin, unitRay.Direction * 1000, params)
	if not result then
		deselectTower()
		return
	end

	local current = result.Instance
	local foundTower = nil
	while current and current ~= workspace do
		if trackedTowers[current] or isTower(current) then
			foundTower = current
			break
		end

		current = current.Parent
	end

	if foundTower then
		local towerPos = getPosition(foundTower)
		if towerPos and (isControlPanelMode() or (charPos - towerPos).Magnitude <= SELECTION_RADIUS) then
			selectTower(foundTower)
			return
		end
	end

	deselectTower()
end)

player.CharacterAdded:Connect(function(newChar)
	character = newChar
	deselectTower()

	for tower in pairs(highlightedTowers) do
		removeHighlight(tower)
	end
end)
