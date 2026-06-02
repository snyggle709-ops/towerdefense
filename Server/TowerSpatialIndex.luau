local TowerSpatialIndex = {}
TowerSpatialIndex.__index = TowerSpatialIndex

function TowerSpatialIndex.new(activeEnemies, unregisterEnemy)
	return setmetatable({
		activeEnemies = activeEnemies,
		unregisterEnemy = unregisterEnemy,
		cellSize = 32,
		updateInterval = 0.1,
		grid = {},
		dirty = true,
		elapsed = 0,
		maxDetectionRadius = 0,
		detectionRadiusCache = {},
	}, TowerSpatialIndex)
end

function TowerSpatialIndex:markDirty()
	self.dirty = true
end

function TowerSpatialIndex:remove(enemy)
	self.detectionRadiusCache[enemy] = nil
	self.dirty = true
end

function TowerSpatialIndex.getFlatDistance(a, b)
	local dx = a.X - b.X
	local dz = a.Z - b.Z
	return math.sqrt((dx * dx) + (dz * dz))
end

function TowerSpatialIndex.getFlatDistanceSquared(a, b)
	local dx = a.X - b.X
	local dz = a.Z - b.Z
	return (dx * dx) + (dz * dz)
end

function TowerSpatialIndex:getEnemyDetectionRadius(enemy)
	local cached = self.detectionRadiusCache[enemy]
	if cached then
		return cached
	end

	if not enemy:IsA("Model") then
		self.detectionRadiusCache[enemy] = 0
		return 0
	end

	local ok, _, size = pcall(function()
		return enemy:GetBoundingBox()
	end)

	if not ok or not size then
		self.detectionRadiusCache[enemy] = 0
		return 0
	end

	local radius = math.max(size.X, size.Z) * 0.5
	self.detectionRadiusCache[enemy] = radius
	return radius
end

function TowerSpatialIndex:isWithinTargetRadius(enemy, point, radius)
	local hrp = enemy:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return false
	end

	local allowedDistance = radius + self:getEnemyDetectionRadius(enemy)
	return TowerSpatialIndex.getFlatDistanceSquared(hrp.Position, point) <= allowedDistance * allowedDistance
end

function TowerSpatialIndex:getCellCoord(value)
	return math.floor(value / self.cellSize)
end

function TowerSpatialIndex:getCellKey(cellX, cellZ)
	return tostring(cellX) .. ":" .. tostring(cellZ)
end

function TowerSpatialIndex:addEnemy(enemy, hrp)
	local cellX = self:getCellCoord(hrp.Position.X)
	local cellZ = self:getCellCoord(hrp.Position.Z)
	local key = self:getCellKey(cellX, cellZ)
	local bucket = self.grid[key]

	if not bucket then
		bucket = {}
		self.grid[key] = bucket
	end

	table.insert(bucket, enemy)
end

function TowerSpatialIndex:rebuild()
	self.grid = {}
	self.maxDetectionRadius = 0

	for enemy in pairs(self.activeEnemies) do
		if not enemy.Parent then
			self.unregisterEnemy(enemy)
			continue
		end

		local hrp = enemy:FindFirstChild("HumanoidRootPart")
		local healthVal = enemy:FindFirstChild("Health")

		if hrp and healthVal and healthVal.Value > 0 then
			self.detectionRadiusCache[enemy] = nil
			self.maxDetectionRadius = math.max(self.maxDetectionRadius, self:getEnemyDetectionRadius(enemy))
			self:addEnemy(enemy, hrp)
		end
	end

	self.dirty = false
end

function TowerSpatialIndex:update(dt)
	self.elapsed += dt
	if self.elapsed >= self.updateInterval then
		self.elapsed = 0
		self:rebuild()
	end
end

function TowerSpatialIndex:getCandidatesNear(centerPosition, radius)
	if self.dirty then
		self:rebuild()
	end

	local results = {}
	local seen = {}
	local queryRadius = radius + self.maxDetectionRadius
	local minCellX = self:getCellCoord(centerPosition.X - queryRadius)
	local maxCellX = self:getCellCoord(centerPosition.X + queryRadius)
	local minCellZ = self:getCellCoord(centerPosition.Z - queryRadius)
	local maxCellZ = self:getCellCoord(centerPosition.Z + queryRadius)

	for cellX = minCellX, maxCellX do
		for cellZ = minCellZ, maxCellZ do
			local bucket = self.grid[self:getCellKey(cellX, cellZ)]
			if bucket then
				for _, enemy in ipairs(bucket) do
					if not seen[enemy] then
						seen[enemy] = true
						table.insert(results, enemy)
					end
				end
			end
		end
	end

	return results
end

function TowerSpatialIndex:getTargetDistance(enemy, point)
	local hrp = enemy:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return math.huge
	end

	local centerDistance = TowerSpatialIndex.getFlatDistance(hrp.Position, point)
	return math.max(0, centerDistance - self:getEnemyDetectionRadius(enemy))
end

return TowerSpatialIndex
