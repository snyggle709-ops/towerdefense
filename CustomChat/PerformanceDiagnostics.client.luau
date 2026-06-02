local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Stats = game:GetService("Stats")

local PerformanceRequestRemote = ReplicatedStorage:WaitForChild("PerformanceRequestRemote")
local PerformanceResponseRemote = ReplicatedStorage:WaitForChild("PerformanceResponseRemote")

local frameTimes = {}
local frameWindowSeconds = 5

RunService.RenderStepped:Connect(function(dt)
	local now = os.clock()
	table.insert(frameTimes, {
		time = now,
		dt = dt,
	})

	while #frameTimes > 0 and now - frameTimes[1].time > frameWindowSeconds do
		table.remove(frameTimes, 1)
	end
end)

local function getAverageFps()
	if #frameTimes == 0 then
		return 0
	end

	local total = 0
	for _, sample in ipairs(frameTimes) do
		total += sample.dt
	end

	local avgDt = total / #frameTimes
	return avgDt > 0 and (1 / avgDt) or 0
end

local function getMemoryMb()
	local ok, value = pcall(function()
		return Stats:GetTotalMemoryUsageMb()
	end)

	if ok and typeof(value) == "number" then
		return value
	end

	return collectgarbage("count") / 1024
end

PerformanceRequestRemote.OnClientEvent:Connect(function(requestId)
	PerformanceResponseRemote:FireServer(requestId, {
		fps = getAverageFps(),
		memoryMb = getMemoryMb(),
	})
end)
