local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local playerModule = require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule"))
local controls = playerModule:GetControls()

local CONTROL_PANEL_CAMERA_ATTRIBUTE = "ControlPanelCameraActive"
local CONTROL_PANEL_ACTION = "ControlPanelRailMovement"
local INTERACT_RADIUS = 12
local MOVE_SPEED = 24
local SHIFT_SPEED_MULTIPLIER = 4
local SMOOTH_SPEED = 14
local DRAG_SPEED = 0.18
local SCROLL_SPEED = 4
local TERRAIN_COLLISION_PADDING = 1.5

local active = false
local viewPart = nil
local baseCFrame = nil
local sideAxis = Vector3.xAxis
local forwardAxis = Vector3.zAxis
local sideOffset = 0
local targetSideOffset = 0
local forwardOffset = 0
local targetForwardOffset = 0
local zoomOffset = 0
local targetZoomOffset = 0
local dragging = false
local lastDragPosition = nil
local anchoredRootPart = nil
local anchoredRootWasAnchored = false
local heldDirections = {
	left = false,
	right = false,
	forward = false,
	backward = false,
	fast = false,
}
local terrainRayParams = RaycastParams.new()
terrainRayParams.FilterType = Enum.RaycastFilterType.Include
terrainRayParams.FilterDescendantsInstances = {workspace.Terrain}

local function getTowerType(tower)
	local typeTag = tower and tower:FindFirstChild("TowerType")
	if typeTag and typeTag:IsA("StringValue") then
		return typeTag.Value
	end

	return nil
end

local function getPosition(instance)
	if instance:IsA("BasePart") then
		return instance.Position
	elseif instance:IsA("Model") then
		return instance:GetPivot().Position
	end

	return nil
end

local function getCharacterRoot()
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") or nil
end

local function findNearestControlPanel()
	local root = getCharacterRoot()
	if not root then
		return nil
	end

	local placedTowers = workspace:FindFirstChild("PlacedTowers")
	if not placedTowers then
		return nil
	end

	local nearest = nil
	local nearestDistance = INTERACT_RADIUS

	for _, tower in ipairs(placedTowers:GetChildren()) do
		if getTowerType(tower) == "Control Panel" then
			local position = getPosition(tower)
			if position then
				local distance = (root.Position - position).Magnitude
				if distance <= nearestDistance then
					nearest = tower
					nearestDistance = distance
				end
			end
		end
	end

	return nearest
end

local function getHorizontalAxis(vector, fallback)
	local axis = vector
	axis = Vector3.new(axis.X, 0, axis.Z)
	if axis.Magnitude < 0.001 then
		axis = fallback
	end

	return axis.Unit
end

local function resetHeldDirections()
	heldDirections.left = false
	heldDirections.right = false
	heldDirections.forward = false
	heldDirections.backward = false
	heldDirections.fast = false
end

local function setCharacterMovementEnabled(enabled)
	if enabled then
		controls:Enable()
	else
		controls:Disable()
	end

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if enabled then
		if anchoredRootPart and anchoredRootPart.Parent then
			anchoredRootPart.Anchored = anchoredRootWasAnchored
		end
		anchoredRootPart = nil
		anchoredRootWasAnchored = false
	elseif root then
		if anchoredRootPart ~= root then
			anchoredRootPart = root
			anchoredRootWasAnchored = root.Anchored
		end
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
		root.Anchored = true
	end

	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid:Move(Vector3.zero, false)
	end
end

local function getViewDirection()
	if not baseCFrame then
		return Vector3.yAxis
	end

	return baseCFrame.LookVector
end

local function getMaxZoomOffset()
	local lookDirection = getViewDirection()
	if not baseCFrame or math.abs(lookDirection.Y) < 0.001 then
		return 0
	end

	local zoomLimit = workspace:FindFirstChild("ZoomLimit")
	if zoomLimit and zoomLimit:IsA("BasePart") then
		local limitOffset = (zoomLimit.Position.Y - baseCFrame.Position.Y) / lookDirection.Y
		if limitOffset > 0 then
			return limitOffset
		end
	end

	return 0
end

local function getZoomLimitHeight()
	local zoomLimit = workspace:FindFirstChild("ZoomLimit")
	if zoomLimit and zoomLimit:IsA("BasePart") then
		return zoomLimit.Position.Y
	end

	return nil
end

local function clampZoomOffset(value)
	if not baseCFrame then
		return 0
	end

	local lookDirection = getViewDirection()
	if lookDirection.Y < -0.001 then
		return math.clamp(value, 0, getMaxZoomOffset())
	elseif lookDirection.Y > 0.001 then
		return math.clamp(value, -getMaxZoomOffset(), 0)
	end

	return 0
end

local function getBaseMovedPosition(currentSideOffset, currentForwardOffset)
	return baseCFrame.Position
		+ (sideAxis * currentSideOffset)
		+ (forwardAxis * currentForwardOffset)
end

local function getZoomedPosition(movedPosition)
	local desired = movedPosition + (getViewDirection() * zoomOffset)
	local minimumHeight = getZoomLimitHeight()
	if minimumHeight and desired.Y < minimumHeight then
		desired = Vector3.new(desired.X, minimumHeight, desired.Z)
	end

	return desired
end

local function canMoveToPosition(nextSideOffset, nextForwardOffset)
	if not baseCFrame then
		return false
	end

	local currentMovedPosition = getBaseMovedPosition(sideOffset, forwardOffset)
	local nextMovedPosition = getBaseMovedPosition(nextSideOffset, nextForwardOffset)
	local movement = nextMovedPosition - currentMovedPosition
	if movement.Magnitude < 0.001 then
		return true
	end

	local cameraPosition = getZoomedPosition(currentMovedPosition)
	local hit = workspace:Raycast(cameraPosition, movement + (movement.Unit * TERRAIN_COLLISION_PADDING), terrainRayParams)
	return hit == nil
end

local function setHeldKey(keyCode, isDown)
	if keyCode == Enum.KeyCode.A or keyCode == Enum.KeyCode.Left then
		heldDirections.left = isDown
	elseif keyCode == Enum.KeyCode.D or keyCode == Enum.KeyCode.Right then
		heldDirections.right = isDown
	elseif keyCode == Enum.KeyCode.W or keyCode == Enum.KeyCode.Up then
		heldDirections.forward = isDown
	elseif keyCode == Enum.KeyCode.S or keyCode == Enum.KeyCode.Down then
		heldDirections.backward = isDown
	elseif keyCode == Enum.KeyCode.LeftShift or keyCode == Enum.KeyCode.RightShift then
		heldDirections.fast = isDown
	end
end

local function bindPanelMovement()
	ContextActionService:BindActionAtPriority(
		CONTROL_PANEL_ACTION,
		function(_, inputState, input)
			local isDown = inputState == Enum.UserInputState.Begin or inputState == Enum.UserInputState.Change
			local isUp = inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel

			if isDown then
				setHeldKey(input.KeyCode, true)
			elseif isUp then
				setHeldKey(input.KeyCode, false)
			end

			return Enum.ContextActionResult.Sink
		end,
		false,
		Enum.ContextActionPriority.High.Value + 100,
		Enum.KeyCode.W,
		Enum.KeyCode.A,
		Enum.KeyCode.S,
		Enum.KeyCode.D,
		Enum.KeyCode.Up,
		Enum.KeyCode.Down,
		Enum.KeyCode.Left,
		Enum.KeyCode.Right,
		Enum.KeyCode.LeftShift,
		Enum.KeyCode.RightShift
	)
end

local function unbindPanelMovement()
	ContextActionService:UnbindAction(CONTROL_PANEL_ACTION)
	resetHeldDirections()
end

local function exitPanelMode()
	if not active then
		return
	end

	active = false
	player:SetAttribute(CONTROL_PANEL_CAMERA_ATTRIBUTE, false)
	unbindPanelMovement()
	if viewPart and viewPart.Parent and baseCFrame then
		viewPart.CFrame = baseCFrame
	end
	setCharacterMovementEnabled(true)
	dragging = false
	lastDragPosition = nil
	viewPart = nil
	baseCFrame = nil
	UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
	UserInputService.MouseIconEnabled = false
end

local function enterPanelMode()
	if active then
		return
	end

	local panel = findNearestControlPanel()
	if not panel then
		return
	end

	local foundViewPart = workspace:FindFirstChild("ControlPanelView")
	if not foundViewPart or not foundViewPart:IsA("BasePart") then
		warn("[ControlPanel] Missing Workspace.ControlPanelView BasePart.")
		return
	end

	active = true
	viewPart = foundViewPart
	baseCFrame = viewPart.CFrame
	sideAxis = getHorizontalAxis(baseCFrame.RightVector, Vector3.xAxis)
	forwardAxis = getHorizontalAxis(baseCFrame.UpVector, Vector3.zAxis)
	sideOffset = 0
	targetSideOffset = 0
	forwardOffset = 0
	targetForwardOffset = 0
	zoomOffset = 0
	targetZoomOffset = 0
	dragging = false
	lastDragPosition = nil
	resetHeldDirections()
	player:SetAttribute(CONTROL_PANEL_CAMERA_ATTRIBUTE, true)
	bindPanelMovement()
	setCharacterMovementEnabled(false)
	camera.CameraType = Enum.CameraType.Scriptable
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	UserInputService.MouseIconEnabled = true
end

UserInputService.InputBegan:Connect(function(input, processed)
	if active then
		setHeldKey(input.KeyCode, true)
	end

	if processed then
		return
	end

	if input.KeyCode == Enum.KeyCode.E then
		if active then
			exitPanelMode()
		else
			enterPanelMode()
		end
	elseif active and (input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.Backspace) then
		exitPanelMode()
	elseif active and input.UserInputType == Enum.UserInputType.MouseButton1 then
		dragging = true
		lastDragPosition = input.Position
	elseif active and input.UserInputType == Enum.UserInputType.Touch then
		dragging = true
		lastDragPosition = input.Position
	end
end)

UserInputService.InputChanged:Connect(function(input, processed)
	if not active then
		return
	end

	if input.UserInputType == Enum.UserInputType.MouseWheel then
		targetZoomOffset += input.Position.Z * SCROLL_SPEED
		targetZoomOffset = clampZoomOffset(targetZoomOffset)
		return
	end

	if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
		if lastDragPosition then
			local delta = input.Position - lastDragPosition
			local speedMultiplier = heldDirections.fast and SHIFT_SPEED_MULTIPLIER or 1
			local requestedSideOffset = targetSideOffset - (delta.X * DRAG_SPEED * speedMultiplier)
			local requestedForwardOffset = targetForwardOffset + (delta.Y * DRAG_SPEED * speedMultiplier)
			if canMoveToPosition(requestedSideOffset, requestedForwardOffset) then
				targetSideOffset = requestedSideOffset
				targetForwardOffset = requestedForwardOffset
			end
		end
		lastDragPosition = input.Position
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if active then
		setHeldKey(input.KeyCode, false)
	end

	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		dragging = false
		lastDragPosition = nil
	end
end)

RunService.RenderStepped:Connect(function(dt)
	if not active then
		return
	end

	if not viewPart or not viewPart.Parent then
		exitPanelMode()
		return
	end

	local sideDirection = 0
	if heldDirections.left then
		sideDirection -= 1
	end
	if heldDirections.right then
		sideDirection += 1
	end

	local forwardDirection = 0
	if heldDirections.forward then
		forwardDirection += 1
	end
	if heldDirections.backward then
		forwardDirection -= 1
	end

	local speedMultiplier = heldDirections.fast and SHIFT_SPEED_MULTIPLIER or 1
	local requestedSideOffset = targetSideOffset + (sideDirection * MOVE_SPEED * speedMultiplier * dt)
	local requestedForwardOffset = targetForwardOffset + (forwardDirection * MOVE_SPEED * speedMultiplier * dt)
	if canMoveToPosition(requestedSideOffset, requestedForwardOffset) then
		targetSideOffset = requestedSideOffset
		targetForwardOffset = requestedForwardOffset
	end

	local blend = 1 - math.exp(-SMOOTH_SPEED * dt)
	sideOffset += (targetSideOffset - sideOffset) * blend
	forwardOffset += (targetForwardOffset - forwardOffset) * blend
	targetZoomOffset = clampZoomOffset(targetZoomOffset)
	zoomOffset += (targetZoomOffset - zoomOffset) * blend

	local movedPosition = getBaseMovedPosition(sideOffset, forwardOffset)
	local zoomedPosition = getZoomedPosition(movedPosition)
	local panelCFrame = baseCFrame - baseCFrame.Position + zoomedPosition
	viewPart.CFrame = panelCFrame
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = panelCFrame

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid:Move(Vector3.zero, false)
	end
end)

player.CharacterAdded:Connect(function()
	exitPanelMode()
end)
