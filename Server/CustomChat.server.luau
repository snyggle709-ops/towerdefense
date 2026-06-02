local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CustomChatRemote = ReplicatedStorage:WaitForChild("CustomChatRemote")

CustomChatRemote.OnServerEvent:Connect(function(player, rawMessage)
	if typeof(rawMessage) ~= "string" then
		return
	end

	if string.sub(rawMessage, 1, 1) ~= "/" then
		return
	end
end)
