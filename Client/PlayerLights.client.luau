local Players = game:GetService("Players")

local LIGHT_NAME = "GentlePlayerLight"
local LIGHT_BRIGHTNESS = 0.55
local LIGHT_RANGE = 11
local LIGHT_COLOR = Color3.fromRGB(255, 223, 185)

local function getLightPart(character)
	return character:FindFirstChild("HumanoidRootPart")
		or character:FindFirstChild("UpperTorso")
		or character:FindFirstChild("Torso")
		or character:FindFirstChild("Head")
end

local function attachLight(character)
	local lightPart = getLightPart(character)
	if not lightPart then
		task.spawn(function()
			lightPart = character:WaitForChild("HumanoidRootPart", 5)
				or character:WaitForChild("UpperTorso", 1)
				or character:WaitForChild("Torso", 1)
				or character:WaitForChild("Head", 1)
			if character.Parent and lightPart then
				attachLight(character)
			end
		end)
		return
	end

	local existingLight = lightPart:FindFirstChild(LIGHT_NAME)
	if existingLight and existingLight:IsA("PointLight") then
		existingLight.Brightness = LIGHT_BRIGHTNESS
		existingLight.Range = LIGHT_RANGE
		existingLight.Color = LIGHT_COLOR
		existingLight.Shadows = false
		return
	end

	local light = Instance.new("PointLight")
	light.Name = LIGHT_NAME
	light.Brightness = LIGHT_BRIGHTNESS
	light.Range = LIGHT_RANGE
	light.Color = LIGHT_COLOR
	light.Shadows = false
	light.Parent = lightPart
end

local function setupPlayer(player)
	if player.Character then
		attachLight(player.Character)
	end

	player.CharacterAdded:Connect(attachLight)
end

for _, player in ipairs(Players:GetPlayers()) do
	setupPlayer(player)
end

Players.PlayerAdded:Connect(setupPlayer)
