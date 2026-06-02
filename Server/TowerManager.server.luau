local Comm = require(game.ReplicatedStorage:WaitForChild("Comm"))
local GameSpeed = require(game.ReplicatedStorage:WaitForChild("GameSpeed"))
local Players = game:GetService("Players")
local HealthRemote = game.ReplicatedStorage:WaitForChild("HealthRemote")
local GameOverRemote = game.ReplicatedStorage:WaitForChild("GameOverRemote")
local DialogueService = require(script.Parent:WaitForChild("DialogueService"))
local RunStats = require(script.Parent:WaitForChild("RunStats"))

local maxHealth = 500
local health = maxHealth
local currentRound = 0
local gameOver = false
local firstHealthLossDialoguePlayed = false
local FIRST_HEALTH_LOSS_DIALOGUE_TEXT = "And there's the first crack. One step closer to failing."
local FIRST_HEALTH_LOSS_DIALOGUE_SOUND_ID = "rbxassetid://129964742687400"

local function broadcastHealth()
	HealthRemote:FireAllClients(health, maxHealth)
end

local function triggerFirstHealthLossDialogue()
	if firstHealthLossDialoguePlayed then
		return
	end

	firstHealthLossDialoguePlayed = true
	DialogueService:FireAllClients(FIRST_HEALTH_LOSS_DIALOGUE_TEXT, {
		soundId = FIRST_HEALTH_LOSS_DIALOGUE_SOUND_ID,
	})
end

local function getEnemyName(enemy)
	return enemy and enemy.Name or nil
end

local function triggerGameOver(finalEnemy)
	if gameOver then
		return
	end

	gameOver = true
	RunStats:RecordFinalLeak(getEnemyName(finalEnemy))
	task.wait(GameSpeed:ScaleDuration(0.1))
	for _, player in ipairs(Players:GetPlayers()) do
		GameOverRemote:FireClient(player, RunStats:GetGameOverSummary(player))
	end
	Comm:Fire("GameOver")
end

Comm:On("RoundStart", function(data)
	currentRound = data.round
end)

Comm:On("EnemyReached", function(enemy)
	if gameOver then return end
	local dmgVal = enemy:FindFirstChild("Damage")
	local dmg = dmgVal and dmgVal.Value or 10
	local previousHealth = health
	health = math.max(0, health - dmg)
	broadcastHealth()
	if health < previousHealth then
		triggerFirstHealthLossDialogue()
	end
	if health <= 0 then
		triggerGameOver(enemy)
	end
end)

Comm:On("HealTower", function(amount)
	if gameOver then return end
	health = math.min(maxHealth, health + amount)
	broadcastHealth()
end)

Comm:On("ModifyCoreHealth", function(amount)
	if typeof(amount) ~= "number" then
		return
	end

	health = math.floor(health + amount + 0.5)
	if health > maxHealth then
		maxHealth = health
	end
	if health > 0 then
		gameOver = false
	end
	broadcastHealth()

	if health <= 0 then
		triggerGameOver(nil)
	end
end)

Comm:On("SetCoreHealth", function(value)
	if typeof(value) ~= "number" then
		return
	end

	health = math.floor(value + 0.5)
	if health > maxHealth then
		maxHealth = health
	end
	if health > 0 then
		gameOver = false
	end
	broadcastHealth()

	if health <= 0 then
		triggerGameOver(nil)
	end
end)

broadcastHealth()
