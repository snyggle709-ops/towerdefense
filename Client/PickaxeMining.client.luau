local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local remote = ReplicatedStorage:WaitForChild("RequestMineResourceRemote")

local lastRequestAt = 0
local REQUEST_COOLDOWN = 0.12

local function hasEquippedTool()
	local character = player.Character
	return character and character:FindFirstChildOfClass("Tool") ~= nil
end

local function getMouseTarget()
	local mouse = player:GetMouse()
	return mouse and mouse.Target or nil
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed or input.UserInputType ~= Enum.UserInputType.MouseButton1 then
		return
	end

	if not hasEquippedTool() then
		return
	end

	local now = os.clock()
	if now - lastRequestAt < REQUEST_COOLDOWN then
		return
	end

	local target = getMouseTarget()
	if not target then
		return
	end

	lastRequestAt = now
	remote:FireServer(target)
end)
