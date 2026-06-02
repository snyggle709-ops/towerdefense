local RunService = game:GetService("RunService")

local placedTowersFolder = workspace:WaitForChild("PlacedTowers")

local shinyOffset = CFrame.new(0.0000305176, 0.0000014305, 0.0000123978, 1.0000000000, -0.0000000000, 0.0000000000, 0.0000000000, 1.0000000000, 0.0000001629, -0.0000000000, -0.0000001629, 1.0000000000)
local sparksOffset = CFrame.new(0.1558303833, 2.1064019203, 0.0000123978, 0.9993187785, -0.0369053334, 0.0000000000, 0.0369053334, 0.9993187785, 0.0000001629, -0.0000000060, -0.0000001628, 1.0000000000)

local trackedMagnets = {}

local function isMagnet(tower)
	if not tower:IsA("Model") then
		return false
	end

	local towerType = tower:FindFirstChild("TowerType")
	return tower.Name == "Magnet" or (towerType and towerType:IsA("StringValue") and towerType.Value == "Magnet")
end

local function trackMagnet(tower)
	if not isMagnet(tower) then
		return
	end

	local shiny = tower:FindFirstChild("Shiny")
	local sparksb = tower:FindFirstChild("sparksb")
	local root = tower:FindFirstChild("RootPart")
	local bone003 = root and root:FindFirstChild("Bone.003")
	local bone = bone003 and bone003:FindFirstChild("Bone")

	if not shiny or not sparksb or not bone then
		return
	end

	for _, part in ipairs({ shiny, sparksb }) do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
			part.CanTouch = false
			part.CanQuery = true
			part.Massless = true
		end
	end

	trackedMagnets[tower] = {
		shiny = shiny,
		sparksb = sparksb,
		bone = bone,
	}
end

local function untrackMagnet(tower)
	trackedMagnets[tower] = nil
end

for _, tower in ipairs(placedTowersFolder:GetChildren()) do
	trackMagnet(tower)
end

placedTowersFolder.ChildAdded:Connect(trackMagnet)
placedTowersFolder.ChildRemoved:Connect(untrackMagnet)

RunService.RenderStepped:Connect(function()
	for tower, state in pairs(trackedMagnets) do
		if not tower.Parent or not state.bone.Parent then
			trackedMagnets[tower] = nil
			continue
		end

		local boneCF = state.bone.TransformedWorldCFrame
		state.shiny.CFrame = boneCF * shinyOffset
		state.sparksb.CFrame = boneCF * sparksOffset
	end
end)
