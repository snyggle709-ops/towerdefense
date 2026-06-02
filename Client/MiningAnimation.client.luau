local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local remote = ReplicatedStorage:WaitForChild("MiningAnimationRemote")

local MINING_ANIMATION_ID = "rbxassetid://140322016551494"
local MINING_WEIGHT = 1

local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local animator = humanoid:WaitForChild("Animator")
local miningTrack = nil
local lockConnection = nil

local function setupCharacter(newCharacter)
	character = newCharacter
	humanoid = character:WaitForChild("Humanoid")
	animator = humanoid:WaitForChild("Animator")
	miningTrack = nil
	player:SetAttribute("MiningMovementLocked", false)
	if lockConnection then
		lockConnection:Disconnect()
		lockConnection = nil
	end
end

local function getMiningTrack()
	if miningTrack then
		return miningTrack
	end

	local animation = Instance.new("Animation")
	animation.AnimationId = MINING_ANIMATION_ID
	miningTrack = animator:LoadAnimation(animation)
	animation:Destroy()

	miningTrack.Priority = Enum.AnimationPriority.Action
	return miningTrack
end

local function unlockMiningMovement()
	player:SetAttribute("MiningMovementLocked", false)
	if lockConnection then
		lockConnection:Disconnect()
		lockConnection = nil
	end
end

remote.OnClientEvent:Connect(function()
	if not humanoid or humanoid.Health <= 0 then
		return
	end

	local track = getMiningTrack()
	if not track.IsPlaying then
		track:Play(0.05, MINING_WEIGHT, 1)
	else
		track.TimePosition = 0
	end

	player:SetAttribute("MiningMovementLocked", true)

	if lockConnection then
		lockConnection:Disconnect()
	end

	lockConnection = RunService.Heartbeat:Connect(function()
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root then
			root.AssemblyLinearVelocity = Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
		end

		if not track.IsPlaying then
			unlockMiningMovement()
			return
		end
	end)

	track.Stopped:Once(unlockMiningMovement)
end)

player.CharacterAdded:Connect(setupCharacter)
