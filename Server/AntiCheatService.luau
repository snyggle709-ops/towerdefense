local Players = game:GetService("Players")

local AntiCheatService = {}

local WARN_COOLDOWN = 1.5
local stateByPlayer = {}

local function getState(player)
	if not player or player.Parent ~= Players then
		return nil
	end

	local state = stateByPlayer[player]
	if not state then
		state = {
			lastWarnedAt = 0,
			trustedAttributes = {},
			violations = tonumber(player:GetAttribute("AntiCheatViolations")) or 0,
		}
		stateByPlayer[player] = state
	end

	return state
end

function AntiCheatService:IsBypassed(player)
	return player and player:GetAttribute("AntiCheatBypass") == true
end

function AntiCheatService:Flag(player, reason, action)
	local state = getState(player)
	if not state then
		return
	end

	state.violations += 1
	player:SetAttribute("AntiCheatViolations", state.violations)

	local now = os.clock()
	if now - state.lastWarnedAt >= WARN_COOLDOWN then
		state.lastWarnedAt = now
		warn(string.format("[AntiCheat] %s: %s (%s)", player.Name, reason, action or "corrected"))
	end
end

function AntiCheatService:SetTrustedAttribute(player, attributeName, value)
	local state = getState(player)
	if not state then
		return
	end

	state.trustedAttributes[attributeName] = value
end

function AntiCheatService:GetTrustedAttribute(player, attributeName)
	local state = getState(player)
	return state and state.trustedAttributes[attributeName] or nil
end

function AntiCheatService:CheckTrustedAttributes(player, attributeNames)
	if self:IsBypassed(player) then
		return
	end

	local state = getState(player)
	if not state then
		return
	end

	for _, attributeName in ipairs(attributeNames) do
		local trustedValue = state.trustedAttributes[attributeName]
		if trustedValue ~= nil then
			local currentValue = player:GetAttribute(attributeName)
			if currentValue ~= trustedValue then
				player:SetAttribute(attributeName, trustedValue)
				self:Flag(player, "trusted attribute tamper: " .. attributeName, "restored")
			end
		end
	end
end

function AntiCheatService:TrackPlayer(player)
	local state = getState(player)
	if not state then
		return
	end

	player:SetAttribute("AntiCheatBypass", player:GetAttribute("AntiCheatBypass") == true)
	player:SetAttribute("AntiCheatViolations", state.violations)
end

Players.PlayerAdded:Connect(function(player)
	AntiCheatService:TrackPlayer(player)
end)

Players.PlayerRemoving:Connect(function(player)
	stateByPlayer[player] = nil
end)

for _, player in ipairs(Players:GetPlayers()) do
	AntiCheatService:TrackPlayer(player)
end

return AntiCheatService
