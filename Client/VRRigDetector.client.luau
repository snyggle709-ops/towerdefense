local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VRService = game:GetService("VRService")
local Players = game:GetService("Players")

local remote = ReplicatedStorage:WaitForChild("VRRigRequestRemote")
local player = Players.LocalPlayer
local sent = false

local function requestR15ForVr()
	if sent or not VRService.VREnabled then
		return
	end

	sent = true
	remote:FireServer()
end

requestR15ForVr()
VRService:GetPropertyChangedSignal("VREnabled"):Connect(requestR15ForVr)
