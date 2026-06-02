local ContentProvider = game:GetService("ContentProvider")
local SoundService = game:GetService("SoundService")

local Songs = workspace:WaitForChild("Songs")

local FADE_TIME = 2
local LOAD_TIMEOUT = 8
local CHECK_INTERVAL = 0.1
local MIN_REAL_SECONDS = 1

local playerA = Instance.new("Sound")
playerA.Name = "MusicPlayerA"
playerA.Parent = SoundService
playerA.Volume = 0
playerA.Looped = false

local playerB = Instance.new("Sound")
playerB.Name = "MusicPlayerB"
playerB.Parent = SoundService
playerB.Volume = 0
playerB.Looped = false

local activePlayer = playerA
local idlePlayer = playerB
local currentSong = nil

local function waitForLoaded(soundObject, timeout)
	timeout = timeout or LOAD_TIMEOUT

	if soundObject.IsLoaded then
		return true
	end

	pcall(function()
		ContentProvider:PreloadAsync({soundObject})
	end)

	if soundObject.IsLoaded then
		return true
	end

	local start = os.clock()
	while os.clock() - start < timeout do
		if soundObject.IsLoaded then
			return true
		end
		task.wait(0.05)
	end

	return soundObject.IsLoaded
end

local function getSongList()
	local list = {}

	for _, item in ipairs(Songs:GetChildren()) do
		if item:IsA("Sound") then
			table.insert(list, item)
		end
	end

	return list
end

local function isSongUsable(song)
	if not song or not song:IsA("Sound") then
		return false
	end

	if song.SoundId == nil or song.SoundId == "" then
		return false
	end

	if song.Volume <= 0 then
		return false
	end

	if not waitForLoaded(song, LOAD_TIMEOUT) then
		return false
	end

	if song.TimeLength <= 0 then
		return false
	end

	local playbackSpeed = math.max(song.PlaybackSpeed, 0.01)
	local realSeconds = song.TimeLength / playbackSpeed

	if realSeconds < MIN_REAL_SECONDS then
		return false
	end

	return true
end

local function getUsableSongs()
	local usable = {}

	for _, song in ipairs(getSongList()) do
		if isSongUsable(song) then
			table.insert(usable, song)
		end
	end

	return usable
end

local function getRandomSong(excludeSong)
	local usable = getUsableSongs()

	if #usable == 0 then
		return nil
	end

	if #usable == 1 then
		return usable[1]
	end

	local filtered = {}
	for _, song in ipairs(usable) do
		if song ~= excludeSong then
			table.insert(filtered, song)
		end
	end

	if #filtered == 0 then
		return usable[math.random(1, #usable)]
	end

	return filtered[math.random(1, #filtered)]
end

local function copySongSettings(fromSong, toPlayer)
	toPlayer.SoundId = fromSong.SoundId
	toPlayer.PlaybackSpeed = fromSong.PlaybackSpeed
	toPlayer.RollOffMode = fromSong.RollOffMode
	toPlayer.RollOffMaxDistance = fromSong.RollOffMaxDistance
	toPlayer.RollOffMinDistance = fromSong.RollOffMinDistance
	toPlayer.EmitterSize = fromSong.EmitterSize
	toPlayer.SoundGroup = fromSong.SoundGroup
	toPlayer.TimePosition = 0
	toPlayer.Looped = false
	toPlayer.Volume = 0
end

local function preparePlayer(player, song)
	copySongSettings(song, player)

	if not waitForLoaded(player, LOAD_TIMEOUT) then
		return false
	end

	if player.TimeLength <= 0 then
		return false
	end

	return true
end

local function fadeTo(soundInstance, targetVolume, duration)
	local startVolume = soundInstance.Volume
	local steps = math.max(1, math.floor(duration / 0.05))
	local stepTime = duration / steps

	for i = 1, steps do
		if not soundInstance.Parent then
			return
		end

		local alpha = i / steps
		soundInstance.Volume = startVolume + ((targetVolume - startVolume) * alpha)
		task.wait(stepTime)
	end

	if soundInstance.Parent then
		soundInstance.Volume = targetVolume
	end
end

local function getRemainingTime(soundInstance)
	local playbackSpeed = math.max(soundInstance.PlaybackSpeed, 0.01)
	local remaining = (soundInstance.TimeLength - soundInstance.TimePosition) / playbackSpeed
	return math.max(0, remaining)
end

local function swapPlayers()
	activePlayer, idlePlayer = idlePlayer, activePlayer
end

local function startSong(player, song)
	local targetVolume = song.Volume

	if not preparePlayer(player, song) then
		return false
	end

	player.Volume = 0
	player:Play()

	task.spawn(function()
		fadeTo(player, targetVolume, FADE_TIME)
	end)

	return true
end

local function stopPlayer(player)
	player:Stop()
	player.TimePosition = 0
	player.Volume = 0
end

pcall(function()
	ContentProvider:PreloadAsync(getSongList())
end)

task.spawn(function()
	while true do
		if not currentSong then
			local firstSong = getRandomSong(nil)

			if not firstSong then
				task.wait(1)
				continue
			end

			local ok = startSong(activePlayer, firstSong)
			if ok then
				currentSong = firstSong
			else
				task.wait(0.25)
				continue
			end
		end

		while activePlayer.Playing do
			local remaining = getRemainingTime(activePlayer)

			if remaining <= FADE_TIME then
				break
			end

			task.wait(CHECK_INTERVAL)
		end

		if not activePlayer.Playing then
			currentSong = nil
			task.wait(0.1)
			continue
		end

		local nextSong = getRandomSong(currentSong)

		if not nextSong then
			activePlayer.Ended:Wait()
			stopPlayer(activePlayer)
			currentSong = nil
			task.wait(0.1)
			continue
		end

		if not preparePlayer(idlePlayer, nextSong) then
			activePlayer.Ended:Wait()
			stopPlayer(activePlayer)
			currentSong = nil
			task.wait(0.1)
			continue
		end

		idlePlayer.Volume = 0
		idlePlayer:Play()

		local nextTargetVolume = nextSong.Volume

		task.spawn(function()
			fadeTo(activePlayer, 0, FADE_TIME)
		end)

		task.spawn(function()
			fadeTo(idlePlayer, nextTargetVolume, FADE_TIME)
		end)

		task.wait(FADE_TIME)

		stopPlayer(activePlayer)
		swapPlayers()
		currentSong = nextSong
	end
end)