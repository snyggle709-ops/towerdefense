local Players = game:GetService("Players")
local ResourceService = require(script.Parent:WaitForChild("ResourceService"))
local CashService = require(game.ServerScriptService:WaitForChild("CashService"))
local hasReceivedStartingResources = {} -- track who already got their starting bonus

local STARTING_RESOURCES = {
	stone = 0,
	crystal = 0,
	metal = 0,
}

local STARTING_CASH = 0

local function grantStartingResources(player)
	-- Only give starting resources once
	if not hasReceivedStartingResources[player.UserId] then
		hasReceivedStartingResources[player.UserId] = true

		task.spawn(function()
			player.CharacterAdded:Wait()
			task.wait(0.5)

			if player.Parent == Players then
				for resourceType, amount in pairs(STARTING_RESOURCES) do
					ResourceService:Add(player, resourceType, amount)
				end

				CashService:Add(player, STARTING_CASH)

				print(string.format(
					"[Economy] Starting loadout for %s: stone=%d crystal=%d metal=%d cash=%d",
					player.Name,
					STARTING_RESOURCES.stone,
					STARTING_RESOURCES.crystal,
					STARTING_RESOURCES.metal,
					STARTING_CASH
				))
			end
		end)
	end
end

Players.PlayerAdded:Connect(grantStartingResources)

for _, player in ipairs(Players:GetPlayers()) do
	grantStartingResources(player)
end

Players.PlayerRemoving:Connect(function(player)
	-- Clean up when player leaves to prevent memory leak
	hasReceivedStartingResources[player.UserId] = nil
end)
