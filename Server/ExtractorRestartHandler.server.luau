local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local ExtractorRestartRemote = ReplicatedStorage:WaitForChild("ExtractorRestartRemote")

local function isOwnedExtractor(player, tower)
	if typeof(tower) ~= "Instance" then
		return false
	end

	if not tower:IsDescendantOf(Workspace) then
		return false
	end

	local towerType = tower:FindFirstChild("TowerType")
	if not towerType or towerType.Value ~= "Extractor" then
		return false
	end

	return tower:GetAttribute("OwnerUserId") == player.UserId
end

ExtractorRestartRemote.OnServerEvent:Connect(function(player, tower)
	if not isOwnedExtractor(player, tower) then
		return
	end

	local requestValue = tower:FindFirstChild("ExtractorRestartRequest")
	if not requestValue then
		requestValue = Instance.new("IntValue")
		requestValue.Name = "ExtractorRestartRequest"
		requestValue.Parent = tower
	end

	requestValue.Value += 1
end)
