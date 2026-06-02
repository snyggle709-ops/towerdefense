local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ResourceService = require(script.Parent:WaitForChild("ResourceService"))
local BalanceLogger = require(script.Parent:WaitForChild("BalanceLogger"))
local AntiCheatService = require(script.Parent:WaitForChild("AntiCheatService"))

local CashService = {}

local SELL_PRICES = {
	stone = 5,
	crystal = 50,
	metal = 500,
}

local CASH_ATTRIBUTE = "cash"

local cashBurstRemote = ReplicatedStorage:FindFirstChild("RoundRewardBurstRemote")
if not cashBurstRemote then
	cashBurstRemote = Instance.new("RemoteEvent")
	cashBurstRemote.Name = "RoundRewardBurstRemote"
	cashBurstRemote.Parent = ReplicatedStorage
end

local cashSyncRemote = ReplicatedStorage:FindFirstChild("CashSyncRemote")
if cashSyncRemote and not cashSyncRemote:IsA("RemoteEvent") then
	cashSyncRemote:Destroy()
	cashSyncRemote = nil
end

if not cashSyncRemote then
	cashSyncRemote = Instance.new("RemoteEvent")
	cashSyncRemote.Name = "CashSyncRemote"
	cashSyncRemote.Parent = ReplicatedStorage
end

local cashSellRemote = ReplicatedStorage:FindFirstChild("CashSellRemote")
if cashSellRemote and not cashSellRemote:IsA("RemoteFunction") then
	cashSellRemote:Destroy()
	cashSellRemote = nil
end

if not cashSellRemote then
	cashSellRemote = Instance.new("RemoteFunction")
	cashSellRemote.Name = "CashSellRemote"
	cashSellRemote.Parent = ReplicatedStorage
end

local function clampCash(amount)
	if typeof(amount) ~= "number" then
		return 0
	end

	return math.max(0, math.floor(amount + 0.5))
end

local function getCash(player)
	return clampCash(player:GetAttribute(CASH_ATTRIBUTE))
end

local function setCash(player, amount)
	local value = clampCash(amount)
	player:SetAttribute(CASH_ATTRIBUTE, value)
	AntiCheatService:SetTrustedAttribute(player, CASH_ATTRIBUTE, value)
end

function CashService:Get(player)
	if not player or player.Parent ~= Players then
		return 0
	end

	return getCash(player)
end

function CashService:Sync(player)
	if not player or player.Parent ~= Players then
		return
	end

	cashSyncRemote:FireClient(player, getCash(player))
end

function CashService:InitPlayer(player)
	if not player or player.Parent ~= Players then
		return
	end

	setCash(player, player:GetAttribute(CASH_ATTRIBUTE))
	self:Sync(player)
end

function CashService:Add(player, amount, options)
	if not player or player.Parent ~= Players or typeof(amount) ~= "number" then
		self:Sync(player)
		return 0
	end

	local current = getCash(player)
	local nextValue = clampCash(current + amount)
	local delta = nextValue - current

	if delta ~= 0 then
		setCash(player, nextValue)
	end

	self:Sync(player)
	if delta > 0 and not (options and options.suppressBurst == true) then
		cashBurstRemote:FireClient(player, delta)
	end
	return delta
end

function CashService:CanAfford(player, amount)
	if not player or player.Parent ~= Players then
		return false
	end

	return getCash(player) >= clampCash(amount)
end

function CashService:Spend(player, amount)
	local cost = clampCash(amount)
	if not self:CanAfford(player, cost) then
		self:Sync(player)
		return false
	end

	if cost > 0 then
		setCash(player, getCash(player) - cost)
	end

	self:Sync(player)
	return true
end

function CashService:SellResource(player, resourceType)
	local price = SELL_PRICES[resourceType]
	if not price then
		self:Sync(player)
		ResourceService:Sync(player)
		return false
	end

	if not ResourceService:Spend(player, {
		[resourceType] = 1,
		}) then
		self:Sync(player)
		return false
	end

	local cashGained = self:Add(player, price)
	BalanceLogger:RecordResourceSale(player, resourceType, cashGained)
	return true
end

cashSellRemote.OnServerInvoke = function(player, resourceType)
	return CashService:SellResource(player, resourceType)
end

return CashService
