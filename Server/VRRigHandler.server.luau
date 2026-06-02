local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local remote = ReplicatedStorage:FindFirstChild("VRRigRequestRemote")
if not remote then
	remote = Instance.new("RemoteEvent")
	remote.Name = "VRRigRequestRemote"
	remote.Parent = ReplicatedStorage
end

local reloadingPlayers = {}

remote.OnServerEvent:Connect(function(player)
	if reloadingPlayers[player] then
		return
	end

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.RigType == Enum.HumanoidRigType.R15 then
		return
	end

	reloadingPlayers[player] = true
	StarterPlayer.CharacterRigType = Enum.HumanoidRigType.R15
	player:LoadCharacter()

	task.delay(5, function()
		reloadingPlayers[player] = nil
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	reloadingPlayers[player] = nil
end)
