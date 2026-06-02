local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local VRService = game:GetService("VRService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local OFFSET = Vector3.new(2.5, 0, 8)
local FOCUS_HEIGHT = 2
local SENSITIVITY = 0.25
local MOBILE_SENSITIVITY = 0.4
local SMOOTH_XZ = 12
local SMOOTH_Y_GROUND = 14
local SMOOTH_Y_AIR = 2.5
local SMOOTH_DIST_IN = 16
local SMOOTH_DIST_OUT = 4
local SMOOTH_CHAR_ROT = 10
local SMOOTH_CAM_ROT = 25
local VELOCITY_LEAD = 0.12
local SMOOTH_VELOCITY = 6
local COLLISION_RADIUS = 0.4
local COLLISION_PAD = 0.5
local MIN_DIST = 0.5
local ROCK_DETECTION_RANGE = 10
local ROCK_YAW_STRENGTH = 0.3
local ROCK_YAW_SMOOTH = 1.5
local CRYSTAL_DETECTION_RANGE = 10
local METAL_DETECTION_RANGE = 10
local DETECTION_INTERVAL = 0.12

local yawInput, pitchInput = 0, 0
local yawSmooth, pitchSmooth = 0, 0
local focusPos, camDist, charYaw
local smoothVelocity = Vector3.zero
local lastRootPos
local initialized = false
local rockYawNudge = 0
local uiOpen = false
local mouseLocked = true
local TOWER_MENU_MOUSE_UNLOCK_ATTRIBUTE = "TowerMenuMouseUnlocked"
local TOWER_UPGRADE_MOUSE_UNLOCK_ATTRIBUTE = "TowerUpgradeMouseUnlocked"
local SETTINGS_MOUSE_UNLOCK_ATTRIBUTE = "SettingsMouseUnlocked"
local TOWER_PLACEMENT_MOUSE_LOCK_ATTRIBUTE = "TowerPlacementMouseLocked"
local CONTROL_PANEL_CAMERA_ATTRIBUTE = "ControlPanelCameraActive"
local FORCE_MOUSE_UNLOCKED_ATTRIBUTE = "ForceMouseUnlocked"
local detectionTimer = 0
local lastNearestRock = nil
local lastNearestRockDist = math.huge

local isMobile = UIS.TouchEnabled

local lookTouchInput = nil
local lookTouchLastPos = nil
local lookGui = nil
local lookRingOuter = nil
local lookRingInner = nil

local activeHighlights = {}
local crystalHighlights = {}
local metalHighlights = {}
local rockTargets = {}
local crystalTargets = {}
local metalTargets = {}
local collisionPartConnections = {}
local collisionExcludedParts = {}
local collisionFilterList = {}
local collisionFilterDirty = true
local collisionFilterCharacter = nil

local function damp(current, target, speed, dt)
	local blend = 1 - math.exp(-speed * dt)
	return current + (target - current) * blend
end

local function dampVec3(current, target, speed, dt)
	local blend = 1 - math.exp(-speed * dt)
	return current:Lerp(target, blend)
end

local function dampAngle(current, target, speed, dt)
	local delta = (target - current) % (math.pi * 2)
	if delta > math.pi then
		delta = delta - math.pi * 2
	end
	return current + delta * (1 - math.exp(-speed * dt))
end

local function destroyHighlight(highlightTable, key)
	local highlight = highlightTable[key]
	if highlight and highlight.Parent then
		highlight:Destroy()
	end
	highlightTable[key] = nil
end

local function markCollisionPart(part, shouldExclude)
	if shouldExclude then
		collisionExcludedParts[part] = true
	else
		collisionExcludedParts[part] = nil
	end
	collisionFilterDirty = true
end

local function refreshCollisionPart(part)
	if not part or not part.Parent then
		markCollisionPart(part, false)
		return
	end
	markCollisionPart(part, not part.CanCollide or part.Transparency >= 1)
end

local function untrackCollisionPart(part)
	local connections = collisionPartConnections[part]
	if connections then
		for _, connection in ipairs(connections) do
			connection:Disconnect()
		end
	end
	collisionPartConnections[part] = nil
	markCollisionPart(part, false)
end

local function trackCollisionPart(part)
	if collisionPartConnections[part] then
		return
	end
	refreshCollisionPart(part)
	collisionPartConnections[part] = {
		part:GetPropertyChangedSignal("CanCollide"):Connect(function()
			refreshCollisionPart(part)
		end),
		part:GetPropertyChangedSignal("Transparency"):Connect(function()
			refreshCollisionPart(part)
		end),
		part.AncestryChanged:Connect(function(_, parent)
			if not parent then
				untrackCollisionPart(part)
			end
		end),
	}
end

local function createHighlightForPart(target, fillColor, outlineColor, fillTransparency)
	local highlight = Instance.new("Highlight")
	highlight.FillColor = fillColor
	highlight.OutlineColor = outlineColor
	highlight.FillTransparency = fillTransparency
	highlight.OutlineTransparency = 0
	highlight.Parent = target
	return highlight
end

local function hasPickaxeEquipped()
	local character = player.Character
	local tool = character and character:FindFirstChild("Pickaxe")
	return tool ~= nil and tool:IsA("Tool")
end

local function clearResourceHighlights()
	for rock in pairs(activeHighlights) do
		destroyHighlight(activeHighlights, rock)
	end
	for crystal in pairs(crystalHighlights) do
		destroyHighlight(crystalHighlights, crystal)
	end
	for metal in pairs(metalHighlights) do
		destroyHighlight(metalHighlights, metal)
	end
	lastNearestRock = nil
	lastNearestRockDist = math.huge
	rockYawNudge = 0
end

local function trackDescendant(obj)
	if obj:IsA("BasePart") then
		trackCollisionPart(obj)
		if obj.Name:match("^LowPolyRock") then
			rockTargets[obj] = true
		end
	end
	if obj:IsA("Model") and obj.Name:lower():match("^crystalrock") then
		crystalTargets[obj] = true
	end
	if (obj:IsA("BasePart") or obj:IsA("Model")) and obj.Name:lower():match("^metal") then
		metalTargets[obj] = true
	end
end

local function untrackDescendant(obj)
	if obj:IsA("BasePart") then
		untrackCollisionPart(obj)
	end
	if rockTargets[obj] then
		rockTargets[obj] = nil
		destroyHighlight(activeHighlights, obj)
	end
	if crystalTargets[obj] then
		crystalTargets[obj] = nil
		destroyHighlight(crystalHighlights, obj)
	end
	if metalTargets[obj] then
		metalTargets[obj] = nil
		destroyHighlight(metalHighlights, obj)
	end
end

for _, obj in ipairs(workspace:GetDescendants()) do
	trackDescendant(obj)
end

workspace.DescendantAdded:Connect(trackDescendant)
workspace.DescendantRemoving:Connect(untrackDescendant)

local function updateRockDetection(characterPos)
	local nearestRock = nil
	local nearestDist = math.huge
	if not hasPickaxeEquipped() then
		for rock in pairs(activeHighlights) do
			destroyHighlight(activeHighlights, rock)
		end
		return nil, math.huge
	end

	for rock in pairs(rockTargets) do
		if not rock.Parent then
			rockTargets[rock] = nil
			destroyHighlight(activeHighlights, rock)
			continue
		end
		local distance = (rock.Position - characterPos).Magnitude
		if distance <= ROCK_DETECTION_RANGE then
			if not activeHighlights[rock] then
				activeHighlights[rock] = createHighlightForPart(
					rock,
					Color3.fromRGB(255, 200, 100),
					Color3.fromRGB(255, 255, 150),
					0.7
				)
			end
			if distance < nearestDist then
				nearestDist = distance
				nearestRock = rock
			end
		else
			destroyHighlight(activeHighlights, rock)
		end
	end
	return nearestRock, nearestDist
end

local function updateCrystalDetection(characterPos)
	if not hasPickaxeEquipped() then
		for crystal in pairs(crystalHighlights) do
			destroyHighlight(crystalHighlights, crystal)
		end
		return
	end

	for crystal in pairs(crystalTargets) do
		if not crystal.Parent then
			crystalTargets[crystal] = nil
			destroyHighlight(crystalHighlights, crystal)
			continue
		end
		local rootPart = crystal.PrimaryPart or crystal:FindFirstChildWhichIsA("BasePart")
		if not rootPart then
			destroyHighlight(crystalHighlights, crystal)
			continue
		end
		local distance = (rootPart.Position - characterPos).Magnitude
		if distance <= CRYSTAL_DETECTION_RANGE then
			if not crystalHighlights[crystal] then
				crystalHighlights[crystal] = createHighlightForPart(
					crystal,
					Color3.fromRGB(130, 80, 255),
					Color3.fromRGB(180, 120, 255),
					0.5
				)
			end
		else
			destroyHighlight(crystalHighlights, crystal)
		end
	end
end

local function updateMetalDetection(characterPos)
	if not hasPickaxeEquipped() then
		for metal in pairs(metalHighlights) do
			destroyHighlight(metalHighlights, metal)
		end
		return
	end

	for metal in pairs(metalTargets) do
		if not metal.Parent then
			metalTargets[metal] = nil
			destroyHighlight(metalHighlights, metal)
			continue
		end
		local position
		if metal:IsA("BasePart") then
			position = metal.Position
		else
			local rootPart = metal.PrimaryPart or metal:FindFirstChildWhichIsA("BasePart")
			position = rootPart and rootPart.Position or nil
		end
		if not position then
			destroyHighlight(metalHighlights, metal)
			continue
		end
		local distance = (position - characterPos).Magnitude
		if distance <= METAL_DETECTION_RANGE then
			if not metalHighlights[metal] then
				metalHighlights[metal] = createHighlightForPart(
					metal,
					Color3.fromRGB(140, 185, 220),
					Color3.fromRGB(190, 220, 240),
					0.55
				)
			end
		else
			destroyHighlight(metalHighlights, metal)
		end
	end
end

local function updateMouseBehavior()
	if player:GetAttribute(FORCE_MOUSE_UNLOCKED_ATTRIBUTE) == true then
		UIS.MouseBehavior = Enum.MouseBehavior.Default
		UIS.MouseIconEnabled = true
		return
	end

	if VRService.VREnabled then
		UIS.MouseBehavior = Enum.MouseBehavior.Default
		UIS.MouseIconEnabled = false
		return
	end

	if isMobile then
		UIS.MouseBehavior = Enum.MouseBehavior.Default
		UIS.MouseIconEnabled = false
		return
	end

	local controlPanelCameraActive = player:GetAttribute(CONTROL_PANEL_CAMERA_ATTRIBUTE) == true
	if controlPanelCameraActive then
		UIS.MouseBehavior = Enum.MouseBehavior.Default
		UIS.MouseIconEnabled = true
		return
	end

	local towerPlacementMouseLocked = player:GetAttribute(TOWER_PLACEMENT_MOUSE_LOCK_ATTRIBUTE) == true
	if towerPlacementMouseLocked then
		UIS.MouseBehavior = Enum.MouseBehavior.LockCenter
		UIS.MouseIconEnabled = false
		return
	end

	local towerMenuMouseUnlocked = player:GetAttribute(TOWER_MENU_MOUSE_UNLOCK_ATTRIBUTE) == true
	local towerUpgradeMouseUnlocked = player:GetAttribute(TOWER_UPGRADE_MOUSE_UNLOCK_ATTRIBUTE) == true
	local settingsMouseUnlocked = player:GetAttribute(SETTINGS_MOUSE_UNLOCK_ATTRIBUTE) == true
	if uiOpen or towerMenuMouseUnlocked or towerUpgradeMouseUnlocked or settingsMouseUnlocked or not mouseLocked then
		UIS.MouseBehavior = Enum.MouseBehavior.Default
		UIS.MouseIconEnabled = true
	else
		UIS.MouseBehavior = Enum.MouseBehavior.LockCenter
		UIS.MouseIconEnabled = false
	end
end

local function getCollisionExclusions(character)
	if not collisionFilterDirty and collisionFilterCharacter == character then
		return collisionFilterList
	end
	table.clear(collisionFilterList)
	table.insert(collisionFilterList, character)
	for part in pairs(collisionExcludedParts) do
		table.insert(collisionFilterList, part)
	end
	collisionFilterDirty = false
	collisionFilterCharacter = character
	return collisionFilterList
end

-- Mobile GUI
local function createLookJoystickGui()
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "MobileLookGui"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.DisplayOrder = 10

	local outer = Instance.new("Frame")
	outer.Name = "OuterRing"
	outer.Size = UDim2.new(0, 140, 0, 140)
	outer.AnchorPoint = Vector2.new(0.5, 0.5)
	outer.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	outer.BackgroundTransparency = 0.8
	outer.BorderSizePixel = 0
	outer.Visible = false
	outer.Parent = screenGui

	local outerCorner = Instance.new("UICorner")
	outerCorner.CornerRadius = UDim.new(1, 0)
	outerCorner.Parent = outer

	local outerStroke = Instance.new("UIStroke")
	outerStroke.Color = Color3.fromRGB(255, 255, 255)
	outerStroke.Transparency = 0.4
	outerStroke.Thickness = 3
	outerStroke.Parent = outer

	local inner = Instance.new("Frame")
	inner.Name = "InnerDot"
	inner.Size = UDim2.new(0, 60, 0, 60)
	inner.AnchorPoint = Vector2.new(0.5, 0.5)
	inner.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	inner.BackgroundTransparency = 0.5
	inner.BorderSizePixel = 0
	inner.Position = UDim2.new(0.5, 0, 0.5, 0)
	inner.Parent = outer

	local innerCorner = Instance.new("UICorner")
	innerCorner.CornerRadius = UDim.new(1, 0)
	innerCorner.Parent = inner

	screenGui.Parent = player:WaitForChild("PlayerGui")
	return screenGui, outer, inner
end

local function showLookJoystick(position)
	if not lookRingOuter then return end
	lookRingOuter.Position = UDim2.new(0, position.X, 0, position.Y)
	lookRingOuter.Visible = true
	lookRingInner.Position = UDim2.new(0.5, 0, 0.5, 0)
end

local function hideLookJoystick()
	if not lookRingOuter then return end
	lookRingOuter.Visible = false
end

local function updateLookJoystickThumb(currentPos)
	if not lookRingOuter or not lookTouchLastPos then return end
	local startPos = lookTouchLastPos
	if lookRingOuter.Visible then
		-- Get the anchor position from the frame itself
		local outerAbsPos = lookRingOuter.AbsolutePosition + lookRingOuter.AbsoluteSize / 2
		local delta = currentPos - outerAbsPos
		local maxRadius = 70
		local clampedDelta = delta.Magnitude <= maxRadius and delta or (delta.Unit * maxRadius)
		lookRingInner.Position = UDim2.new(0.5, clampedDelta.X, 0.5, clampedDelta.Y)
	end
end

if isMobile then
	lookGui, lookRingOuter, lookRingInner = createLookJoystickGui()
end

if VRService.VREnabled then
	UIS.MouseBehavior = Enum.MouseBehavior.Default
	UIS.MouseIconEnabled = false
else
	camera.CameraType = Enum.CameraType.Scriptable
	updateMouseBehavior()
end

task.spawn(function()
	repeat task.wait() until _G.OnUpgradeUIChanged
	_G.OnUpgradeUIChanged:Connect(function(open)
		uiOpen = open
		updateMouseBehavior()
		if open and lookTouchInput then
			lookTouchInput = nil
			lookTouchLastPos = nil
			hideLookJoystick()
		end
	end)
end)

if not isMobile then
	UIS.InputBegan:Connect(function(input, processed)
		if VRService.VREnabled then return end
		if processed then return end
		if input.KeyCode == Enum.KeyCode.M then
			mouseLocked = not mouseLocked
			updateMouseBehavior()
		end
	end)

	UIS.InputChanged:Connect(function(input, processed)
		if VRService.VREnabled then return end
		local towerPlacementMouseLocked = player:GetAttribute(TOWER_PLACEMENT_MOUSE_LOCK_ATTRIBUTE) == true
		if processed or ((uiOpen or not mouseLocked) and not towerPlacementMouseLocked) then return end
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			yawInput -= input.Delta.X * SENSITIVITY
			pitchInput = math.clamp(pitchInput - input.Delta.Y * SENSITIVITY, -75, 75)
		end
	end)
end

if isMobile then
	-- Right 55% of screen is the look zone
	-- Left 45% is left alone so the default thumbstick works untouched
	local LOOK_ZONE_X = 0.45

	local function isInLookZone(pos)
		return pos.X / camera.ViewportSize.X >= LOOK_ZONE_X
	end

	UIS.TouchStarted:Connect(function(touch, processed)
		-- processed = true means it hit a GUI element (thumbstick, jump button, etc)
		-- We must ignore those completely so movement works
		if processed then return end
		if uiOpen then return end
		if lookTouchInput then return end

		local pos = touch.Position
		if not isInLookZone(pos) then return end

		lookTouchInput = touch
		lookTouchLastPos = Vector2.new(pos.X, pos.Y)
		showLookJoystick(lookTouchLastPos)
	end)

	UIS.TouchMoved:Connect(function(touch, processed)
		if touch ~= lookTouchInput then return end
		if uiOpen then return end

		local pos = Vector2.new(touch.Position.X, touch.Position.Y)
		local delta = pos - lookTouchLastPos
		lookTouchLastPos = pos

		yawInput -= delta.X * MOBILE_SENSITIVITY
		pitchInput = math.clamp(pitchInput - delta.Y * MOBILE_SENSITIVITY, -75, 75)

		updateLookJoystickThumb(pos)
	end)

	UIS.TouchEnded:Connect(function(touch, processed)
		if touch ~= lookTouchInput then return end
		lookTouchInput = nil
		lookTouchLastPos = nil
		hideLookJoystick()
	end)
end

RunService.RenderStepped:Connect(function(dt)
	if VRService.VREnabled then
		UIS.MouseBehavior = Enum.MouseBehavior.Default
		UIS.MouseIconEnabled = false
		lookTouchInput = nil
		lookTouchLastPos = nil
		hideLookJoystick()
		return
	end

	if player:GetAttribute(CONTROL_PANEL_CAMERA_ATTRIBUTE) == true then
		updateMouseBehavior()
		lookTouchInput = nil
		lookTouchLastPos = nil
		hideLookJoystick()
		return
	end

	camera.CameraType = Enum.CameraType.Scriptable
	updateMouseBehavior()

	local char = player.Character
	if not char then return end

	local root = char:FindFirstChild("HumanoidRootPart")
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not root or not hum then return end

	hum.AutoRotate = false

	local rootPos = root.Position
	local grounded = hum.FloorMaterial ~= Enum.Material.Air

	yawSmooth = damp(yawSmooth, yawInput, SMOOTH_CAM_ROT, dt)
	pitchSmooth = damp(pitchSmooth, pitchInput, SMOOTH_CAM_ROT, dt)

	local rawVelocity = lastRootPos and (rootPos - lastRootPos) / math.max(dt, 0.0001) or Vector3.zero
	lastRootPos = rootPos
	smoothVelocity = dampVec3(smoothVelocity, rawVelocity, SMOOTH_VELOCITY, dt)

	if not initialized then
		focusPos = rootPos + Vector3.new(0, FOCUS_HEIGHT, 0)
		camDist = OFFSET.Magnitude
		charYaw = math.atan2(-root.CFrame.LookVector.X, -root.CFrame.LookVector.Z)
		yawSmooth, pitchSmooth = yawInput, pitchInput
		smoothVelocity = Vector3.zero
		initialized = true
	end

	detectionTimer += dt
	if detectionTimer >= DETECTION_INTERVAL then
		lastNearestRock, lastNearestRockDist = updateRockDetection(rootPos)
		updateCrystalDetection(rootPos)
		updateMetalDetection(rootPos)
		detectionTimer = 0
	end

	local targetRockYawNudge = 0
	if lastNearestRock then
		local toRock = lastNearestRock.Position - rootPos
		local rockWorldYaw = math.deg(math.atan2(-toRock.X, -toRock.Z))
		local angleDiff = rockWorldYaw - yawSmooth
		angleDiff = ((angleDiff + 180) % 360) - 180
		local distanceFade = 1 - (lastNearestRockDist / ROCK_DETECTION_RANGE)
		targetRockYawNudge = angleDiff * ROCK_YAW_STRENGTH * distanceFade
	end

	rockYawNudge = damp(rockYawNudge, targetRockYawNudge, ROCK_YAW_SMOOTH, dt)
	local finalYaw = yawSmooth + rockYawNudge

	local velocityLead = Vector3.new(smoothVelocity.X, 0, smoothVelocity.Z) * VELOCITY_LEAD
	local targetFocus = rootPos + Vector3.new(0, FOCUS_HEIGHT, 0) + velocityLead
	local ySmoothing = grounded and SMOOTH_Y_GROUND or SMOOTH_Y_AIR

	focusPos = Vector3.new(
		damp(focusPos.X, targetFocus.X, SMOOTH_XZ, dt),
		damp(focusPos.Y, targetFocus.Y, ySmoothing, dt),
		damp(focusPos.Z, targetFocus.Z, SMOOTH_XZ, dt)
	)

	local rotation = CFrame.Angles(0, math.rad(finalYaw), 0) * CFrame.Angles(math.rad(pitchSmooth), 0, 0)
	local worldOffset = rotation:VectorToWorldSpace(OFFSET)
	local maxDist = worldOffset.Magnitude
	local direction = worldOffset.Unit

	local params = RaycastParams.new()
	params.FilterDescendantsInstances = getCollisionExclusions(char)
	params.FilterType = Enum.RaycastFilterType.Exclude

	local desiredDist = maxDist
	local sphereHit = workspace:Spherecast(focusPos, COLLISION_RADIUS, direction * (maxDist + COLLISION_PAD), params)
	if sphereHit then
		local hitDist = math.max((sphereHit.Position - focusPos).Magnitude - COLLISION_PAD, MIN_DIST)
		desiredDist = math.min(desiredDist, hitDist)
	end

	local rayHit = workspace:Raycast(focusPos, direction * (maxDist + COLLISION_PAD), params)
	if rayHit then
		local hitDist = math.max((rayHit.Position - focusPos).Magnitude - COLLISION_PAD, MIN_DIST)
		desiredDist = math.min(desiredDist, hitDist)
	end

	local distSmoothing = desiredDist < camDist and SMOOTH_DIST_IN or SMOOTH_DIST_OUT
	camDist = damp(camDist, desiredDist, distSmoothing, dt)

	-- Keep camera CFrame updated so mobile thumbstick reads correct forward direction
	local finalCamCFrame = CFrame.lookAt(focusPos + direction * camDist, focusPos)
	camera.CFrame = finalCamCFrame

	local moveDir = hum.MoveDirection
	if moveDir.Magnitude > 0.1 then
		local targetCharYaw = math.atan2(-moveDir.X, -moveDir.Z)
		charYaw = dampAngle(charYaw, targetCharYaw, SMOOTH_CHAR_ROT, dt)
	end

	root.CFrame = CFrame.new(rootPos) * CFrame.Angles(0, charYaw, 0)
end)

player.CharacterAdded:Connect(function()
	focusPos = nil
	camDist = nil
	charYaw = nil
	lastRootPos = nil
	smoothVelocity = Vector3.zero
	rockYawNudge = 0
	initialized = false
	lastNearestRock = nil
	lastNearestRockDist = math.huge
	detectionTimer = 0
	collisionFilterCharacter = nil
	lookTouchInput = nil
	lookTouchLastPos = nil
	hideLookJoystick()

	for rock in pairs(activeHighlights) do
		destroyHighlight(activeHighlights, rock)
	end
	for crystal in pairs(crystalHighlights) do
		destroyHighlight(crystalHighlights, crystal)
	end
	for metal in pairs(metalHighlights) do
		destroyHighlight(metalHighlights, metal)
	end
end)
