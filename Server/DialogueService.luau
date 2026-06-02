local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DialogueRemote = ReplicatedStorage:WaitForChild("RoundOneDialogueRemote")
local DialogueAckRemote = ReplicatedStorage:WaitForChild("RoundOneDialogueAckRemote")
local DialoguePollRemote = ReplicatedStorage:WaitForChild("RoundOneDialoguePollRemote")

local RETRY_INTERVAL = 0.65
local MAX_PUSH_ATTEMPTS = 20
local REQUEST_LIFETIME = 60

local nextRequestId = 0
local pendingByUserId = {}

local DialogueService = {}

local function getPendingForPlayer(player)
	local userPending = pendingByUserId[player.UserId]
	if not userPending then
		userPending = {}
		pendingByUserId[player.UserId] = userPending
	end
	return userPending
end

local function sendAttempt(player, requestId, request)
	if not player.Parent then
		return
	end

	DialogueRemote:FireClient(player, requestId, request.messageText, request.options)
end

local function trackReliableRequest(player, messageText, options)
	if not player or not player.Parent then
		return
	end

	nextRequestId += 1
	local requestId = nextRequestId
	local request = {
		messageText = messageText,
		options = options,
		attempts = 0,
		createdAt = os.clock(),
	}

	getPendingForPlayer(player)[requestId] = request

	task.spawn(function()
		while player.Parent do
			local userPending = pendingByUserId[player.UserId]
			if not userPending or userPending[requestId] ~= request then
				return
			end

			request.attempts += 1
			sendAttempt(player, requestId, request)

			if request.attempts >= MAX_PUSH_ATTEMPTS then
				warn(string.format("[Dialogue] Push ack missing for %s after %d attempts; waiting for client poll.", player.Name, request.attempts))
				return
			end

			if os.clock() - request.createdAt > REQUEST_LIFETIME then
				userPending[requestId] = nil
				return
			end

			task.wait(RETRY_INTERVAL)
		end
	end)
end

function DialogueService:FireClient(player, messageText, options)
	trackReliableRequest(player, messageText, options)
end

function DialogueService:FireAllClients(messageText, options)
	for _, player in ipairs(Players:GetPlayers()) do
		trackReliableRequest(player, messageText, options)
	end
end

DialogueAckRemote.OnServerEvent:Connect(function(player, requestId)
	if typeof(requestId) ~= "number" then
		return
	end

	local userPending = pendingByUserId[player.UserId]
	if userPending then
		userPending[requestId] = nil
	end
end)

DialoguePollRemote.OnServerInvoke = function(player)
	local userPending = pendingByUserId[player.UserId]
	if not userPending then
		return {}
	end

	local now = os.clock()
	local requests = {}

	for requestId, request in pairs(userPending) do
		if now - request.createdAt > REQUEST_LIFETIME then
			userPending[requestId] = nil
		else
			table.insert(requests, {
				id = requestId,
				messageText = request.messageText,
				options = request.options,
			})
		end
	end

	table.sort(requests, function(a, b)
		return a.id < b.id
	end)

	return requests
end

Players.PlayerRemoving:Connect(function(player)
	pendingByUserId[player.UserId] = nil
end)

return DialogueService
