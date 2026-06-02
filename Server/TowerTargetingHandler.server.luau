local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local targetingRemote = ReplicatedStorage:FindFirstChild("TowerTargetingRemote")
if targetingRemote and not targetingRemote:IsA("RemoteEvent") then
	targetingRemote:Destroy()
	targetingRemote = nil
end

if not targetingRemote then
	targetingRemote = Instance.new("RemoteEvent")
	targetingRemote.Name = "TowerTargetingRemote"
	targetingRemote.Parent = ReplicatedStorage
end

local validModes = {
	closest = true,
	furthest = true,
	strongest = true,
	weakest = true,
}

local modeOrder = {"closest", "furthest", "strongest", "weakest"}

local function ownsTower(player, tower)
	local ownerUserId = tower:GetAttribute("OwnerUserId")
	if typeof(ownerUserId) ~= "number" then
		if #Players:GetPlayers() == 1 then
			tower:SetAttribute("OwnerUserId", player.UserId)
			return true
		end
		return false
	end

	return ownerUserId == player.UserId
end

local function isTower(instance)
	return instance
		and instance.Parent
		and instance:IsDescendantOf(Workspace)
		and instance:FindFirstChild("TowerType") ~= nil
end

local function getOrCreateTargetingMode(tower)
	local modeVal = tower:FindFirstChild("TargetingMode")
	if modeVal and modeVal:IsA("StringValue") then
		return modeVal
	end

	if modeVal then
		modeVal:Destroy()
	end

	modeVal = Instance.new("StringValue")
	modeVal.Name = "TargetingMode"
	modeVal.Value = "closest"
	modeVal.Parent = tower
	return modeVal
end

local function getNextMode(currentMode)
	currentMode = string.lower(tostring(currentMode or "closest"))
	for index, mode in ipairs(modeOrder) do
		if mode == currentMode then
			return modeOrder[(index % #modeOrder) + 1]
		end
	end

	return "closest"
end

targetingRemote.OnServerEvent:Connect(function(player, tower, requestedMode)
	if not isTower(tower) or not ownsTower(player, tower) then
		return
	end

	local modeVal = getOrCreateTargetingMode(tower)
	local mode = string.lower(tostring(requestedMode or ""))
	if not validModes[mode] then
		mode = getNextMode(modeVal.Value)
	end

	modeVal.Value = mode
end)
