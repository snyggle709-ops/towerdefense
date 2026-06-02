local Players = game:GetService("Players")
local CashService = require(script.Parent:WaitForChild("CashService"))
local ResourceService = require(script.Parent:WaitForChild("ResourceService"))

local function setupPlayer(player)
	player:SetAttribute("PickaxeStrength", 0)
	player:SetAttribute("ResourceMultiplier", 1)
	CashService:InitPlayer(player)
	ResourceService:InitPlayer(player)

	player.CharacterAdded:Connect(function()
		task.delay(0.25, function()
			if player.Parent == Players then
				CashService:Sync(player)
				ResourceService:Sync(player)
			end
		end)
	end)
end

Players.PlayerAdded:Connect(setupPlayer)

for _, player in ipairs(Players:GetPlayers()) do
	setupPlayer(player)
end
