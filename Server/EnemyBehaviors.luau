local EnemyBehaviors = {}
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RUNNER_SPEED_MULTIPLIER = 2
local SUPPORT_RADIUS = 18
local SUPPORT_SPEED_BONUS = 4
local SUPPORT_HEAL_AMOUNT = 8
local SUPPORT_HEAL_INTERVAL = 1.25
local HEAL_FX_FADE_IN = 0.12
local HEAL_FX_HOLD = 0.5
local HEAL_FX_FADE_OUT = 0.25

local supportSpeedAffectedEnemies = {}
local supportHealAffectedEnemies = {}
local lastSupportHealPulse = 0

local function isSupportEnemy(enemy)
	return enemy and enemy.Parent and enemy:FindFirstChild("Support") ~= nil
end

local function getEnemyRootPart(enemy)
	if not enemy or not enemy.Parent then
		return nil
	end

	local root = enemy:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end

	if enemy.PrimaryPart then
		return enemy.PrimaryPart
	end

	return enemy:FindFirstChildWhichIsA("BasePart", true)
end

local function setHealFxPartsInvisible(effect)
	for _, descendant in ipairs(effect:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Transparency = 1
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
			descendant.Massless = true
			descendant.Anchored = false
		end
	end

	if effect:IsA("BasePart") then
		effect.Transparency = 1
		effect.CanCollide = false
		effect.CanTouch = false
		effect.CanQuery = false
		effect.Massless = true
		effect.Anchored = false
	end
end

local function getEffectMainPart(effect)
	if effect:IsA("BasePart") then
		return effect
	end

	if effect:IsA("Model") then
		if effect.PrimaryPart then
			return effect.PrimaryPart
		end

		local part = effect:FindFirstChildWhichIsA("BasePart", true)
		if part then
			effect.PrimaryPart = part
			return part
		end
	end

	return effect:FindFirstChildWhichIsA("BasePart", true)
end

local function weldHealFxToEnemy(effect, enemy)
	local root = getEnemyRootPart(enemy)
	local mainPart = getEffectMainPart(effect)
	if not root or not mainPart then
		return false
	end

	local bottomOffset = -(root.Size.Y * 0.5)
	local targetCFrame = root.CFrame * CFrame.new(0, bottomOffset, 0)

	if effect:IsA("Model") then
		effect:PivotTo(targetCFrame)
	else
		mainPart.CFrame = targetCFrame
	end

	for _, descendant in ipairs(effect:GetDescendants()) do
		if descendant:IsA("BasePart") then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = root
			weld.Part1 = descendant
			weld.Parent = descendant
		end
	end

	if effect:IsA("BasePart") then
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = effect
		weld.Parent = effect
	end

	return true
end

local function setEmitterAlpha(emitters, alpha)
	for _, emitterData in ipairs(emitters) do
		local emitter = emitterData.emitter
		if emitter.Parent then
			emitter.Rate = emitterData.rate * alpha
		end
	end
end

local function animateHealFxEmitters(effect)
	local emitters = {}
	local maxLifetime = 0

	for _, descendant in ipairs(effect:GetDescendants()) do
		if descendant:IsA("ParticleEmitter") then
			local rate = descendant.Rate
			maxLifetime = math.max(maxLifetime, descendant.Lifetime.Max)
			descendant.Enabled = false
			descendant.Rate = 0
			table.insert(emitters, {
				emitter = descendant,
				rate = rate,
			})
		end
	end

	if #emitters == 0 then
		Debris:AddItem(effect, HEAL_FX_HOLD + 1)
		return
	end

	task.spawn(function()
		for _, emitterData in ipairs(emitters) do
			if emitterData.emitter.Parent then
				emitterData.emitter.Enabled = true
			end
		end

		local steps = 6
		for i = 1, steps do
			setEmitterAlpha(emitters, i / steps)
			task.wait(HEAL_FX_FADE_IN / steps)
		end

		task.wait(HEAL_FX_HOLD)

		for i = steps, 0, -1 do
			setEmitterAlpha(emitters, i / steps)
			task.wait(HEAL_FX_FADE_OUT / steps)
		end

		for _, emitterData in ipairs(emitters) do
			if emitterData.emitter.Parent then
				emitterData.emitter.Enabled = false
			end
		end
	end)

	Debris:AddItem(effect, HEAL_FX_FADE_IN + HEAL_FX_HOLD + HEAL_FX_FADE_OUT + maxLifetime + 0.25)
end

local function playSupportHealFx(enemy)
	local template = ReplicatedStorage:FindFirstChild("HealFX")
	if not template then
		local highlight = Instance.new("Highlight")
		highlight.Name = "SupportHealFallback"
		highlight.FillColor = Color3.fromRGB(80, 255, 120)
		highlight.OutlineColor = Color3.fromRGB(190, 255, 190)
		highlight.FillTransparency = 0.35
		highlight.OutlineTransparency = 0
		highlight.DepthMode = Enum.HighlightDepthMode.Occluded
		highlight.Parent = enemy

		task.delay(HEAL_FX_HOLD, function()
			if highlight.Parent then
				highlight.FillTransparency = 1
				highlight.OutlineTransparency = 1
			end
		end)
		Debris:AddItem(highlight, HEAL_FX_HOLD + 0.25)
		return
	end

	local effect = template:Clone()
	setHealFxPartsInvisible(effect)
	animateHealFxEmitters(effect)
	effect.Parent = enemy

	if not weldHealFxToEnemy(effect, enemy) then
		effect:Destroy()
	end
end

function EnemyBehaviors.initEnemy(enemy)
	if not enemy or not enemy.Parent then
		return
	end

	local speedVal = enemy:FindFirstChild("Speed")
	if speedVal and enemy:FindFirstChild("Runner") and not enemy:GetAttribute("RunnerSpeedApplied") then
		speedVal.Value *= RUNNER_SPEED_MULTIPLIER
		enemy:SetAttribute("RunnerSpeedApplied", true)
	end
end

function EnemyBehaviors.cleanupEnemy(enemy)
	supportSpeedAffectedEnemies[enemy] = nil
	supportHealAffectedEnemies[enemy] = nil
end

function EnemyBehaviors.hasSupportAura(enemy)
	return supportSpeedAffectedEnemies[enemy] == true
end

function EnemyBehaviors.getSupportSpeedBonus()
	return SUPPORT_SPEED_BONUS
end

function EnemyBehaviors.refreshSupportAuras(activeEnemies, getEnemiesInRadius)
	table.clear(supportSpeedAffectedEnemies)

	for enemy in pairs(activeEnemies) do
		if enemy.Parent and isSupportEnemy(enemy) then
			local hrp = enemy:FindFirstChild("HumanoidRootPart")
			local healthVal = enemy:FindFirstChild("Health")

			if hrp and healthVal and healthVal.Value > 0 then
				for _, entry in ipairs(getEnemiesInRadius(hrp.Position, SUPPORT_RADIUS, false)) do
					if entry.enemy ~= enemy then
						supportSpeedAffectedEnemies[entry.enemy] = true
					end
				end
			end
		end
	end
end

function EnemyBehaviors.updateSupportHealing(now, activeEnemies, getEnemiesInRadius, getEnemyMaxHealth)
	if now - lastSupportHealPulse < SUPPORT_HEAL_INTERVAL then
		return
	end

	lastSupportHealPulse = now
	table.clear(supportHealAffectedEnemies)

	for enemy in pairs(activeEnemies) do
		if enemy.Parent and isSupportEnemy(enemy) then
			local hrp = enemy:FindFirstChild("HumanoidRootPart")
			local healthVal = enemy:FindFirstChild("Health")

			if hrp and healthVal and healthVal.Value > 0 then
				for _, entry in ipairs(getEnemiesInRadius(hrp.Position, SUPPORT_RADIUS, false)) do
					local ally = entry.enemy

					if ally ~= enemy and not supportHealAffectedEnemies[ally] then
						local allyHealthVal, allyHumanoid, maxHealth = getEnemyMaxHealth(ally)

						if allyHealthVal and allyHealthVal.Value > 0 and maxHealth > 0 then
							local newHealth = math.min(maxHealth, allyHealthVal.Value + SUPPORT_HEAL_AMOUNT)
							allyHealthVal.Value = newHealth

							if allyHumanoid then
								allyHumanoid.MaxHealth = maxHealth
								allyHumanoid.Health = newHealth
							end

							playSupportHealFx(ally)

							supportHealAffectedEnemies[ally] = true
						end
					end
				end
			end
		end
	end
end

return EnemyBehaviors
