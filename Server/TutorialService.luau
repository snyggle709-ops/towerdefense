local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ResourceService = require(script.Parent:WaitForChild("ResourceService"))

local TutorialRemote = ReplicatedStorage:WaitForChild("TutorialRemote")

local TutorialService = {}

local BONUS_STONE = 40
local OBJECTIVE_NAME = "Objective1"
local REQUIRED_TOWER = "Cannon"

local completedByUserId = {}
local startedByUserId = {}
local bonusGrantedByUserId = {}

local function setTutorialAttributes(player, active)
	player:SetAttribute("TutorialActive", active)
	player:SetAttribute("TutorialPlacementActive", active)
	player:SetAttribute("TutorialPlacementObjective", active and OBJECTIVE_NAME or nil)
	player:SetAttribute("TutorialRequiredTower", active and REQUIRED_TOWER or nil)

	if active then
		local objective = workspace:FindFirstChild(OBJECTIVE_NAME)
		if objective and objective:IsA("BasePart") then
			objective.CanQuery = true
		end
	end
end

function TutorialService:IsCompleted(player)
	return player and completedByUserId[player.UserId] == true
end

function TutorialService:Start(player)
	if not player or player.Parent ~= Players or startedByUserId[player.UserId] then
		return
	end

	startedByUserId[player.UserId] = true
	setTutorialAttributes(player, true)
	TutorialRemote:FireClient(player, "Start", {
		objectiveName = OBJECTIVE_NAME,
		requiredTower = REQUIRED_TOWER,
	})
end

function TutorialService:GrantStartingStone(player)
	if not player or player.Parent ~= Players or bonusGrantedByUserId[player.UserId] then
		return
	end

	bonusGrantedByUserId[player.UserId] = true
	ResourceService:Add(player, "stone", BONUS_STONE)
	TutorialRemote:FireClient(player, "StartingStoneGranted", BONUS_STONE)
end

function TutorialService:CompleteFirstPlacement(player)
	if not player or player.Parent ~= Players or completedByUserId[player.UserId] then
		return
	end

	completedByUserId[player.UserId] = true
	setTutorialAttributes(player, false)
	TutorialRemote:FireClient(player, "FirstPlacementComplete")
end

function TutorialService:WaitForAllCurrentPlayersComplete()
	while true do
		local allComplete = true
		for _, player in ipairs(Players:GetPlayers()) do
			if not self:IsCompleted(player) then
				allComplete = false
				self:Start(player)
			end
		end

		if allComplete then
			return
		end

		task.wait(0.25)
	end
end

TutorialRemote.OnServerEvent:Connect(function(player, action)
	if action == "GrantStartingStone" then
		TutorialService:GrantStartingStone(player)
	end
end)

Players.PlayerAdded:Connect(function(player)
	task.spawn(function()
		player.CharacterAdded:Wait()
		task.wait(0.25)
		TutorialService:Start(player)
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	startedByUserId[player.UserId] = nil
	bonusGrantedByUserId[player.UserId] = nil
	completedByUserId[player.UserId] = nil
end)

for _, player in ipairs(Players:GetPlayers()) do
	task.defer(function()
		TutorialService:Start(player)
	end)
end

return TutorialService
