-- GameManager: orchestrates waiting room, sessions, and progression mechanics

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))
local RemoteSetup = require(ReplicatedStorage:WaitForChild("RemoteSetup"))
local Config = require(ReplicatedStorage.Shared.Config)
local PlayerStats = require(ReplicatedStorage.Shared.PlayerStats)
local UpgradeDefinitions = require(ReplicatedStorage.Shared.UpgradeDefinitions)

local LeaderboardService = require(script.Parent:WaitForChild("LeaderboardService"))
local WorldBuilder = require(script.Parent:WaitForChild("WorldBuilder"))
local PaintService = require(script.Parent:WaitForChild("PaintService"))
local GrowthService = require(script.Parent:WaitForChild("GrowthService"))
local UpgradeService = require(script.Parent:WaitForChild("UpgradeService"))
local RefillService = require(script.Parent:WaitForChild("RefillService"))
local DataService = require(script.Parent:WaitForChild("DataService"))

local GameManager = {}

-- Session state
local currentState = GameConfig.GameState.WaitingRoom
local countdownActive = false
local sessionScores = {}

-- Progression state
local playerStates = {}
local colorCounter = 0
local brushCooldowns = {}
local refillAccum = 0
local AUTOSAVE_INTERVAL = 60
local LOBBY_Y = 80

-- Arena spawn positions (mirrored from WorldBuilder)
local arenaSpawns = {
	Vector3.new(-Config.TeamSpawnSpacing, 2, -Config.TeamSpawnSpacing),
	Vector3.new( Config.TeamSpawnSpacing, 2, -Config.TeamSpawnSpacing),
	Vector3.new(-Config.TeamSpawnSpacing, 2,  Config.TeamSpawnSpacing),
	Vector3.new( Config.TeamSpawnSpacing, 2,  Config.TeamSpawnSpacing),
}
local lobbySpawnPos = Vector3.new(0, LOBBY_Y + 3, -10)

--------------------------------------------------
-- Helpers
--------------------------------------------------

local function teleportPlayer(player, position)
	local character = player.Character
	if not character then return end
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return end
	rootPart.CFrame = CFrame.new(position)
end

local function teleportAllToArena()
	for _, player in ipairs(Players:GetPlayers()) do
		local stats = playerStates[player.UserId]
		local spawnIndex = stats and stats.colorIndex or 1
		spawnIndex = math.clamp(spawnIndex, 1, #arenaSpawns)
		teleportPlayer(player, arenaSpawns[spawnIndex])
	end
end

local function teleportAllToLobby()
	for _, player in ipairs(Players:GetPlayers()) do
		teleportPlayer(player, lobbySpawnPos)
	end
end

local function assignColor()
	colorCounter = colorCounter + 1
	if colorCounter > #Config.PaintColors then
		colorCounter = 1
	end
	return colorCounter
end

local function syncStats(player, stats)
	RemoteSetup.GetRemote(GameConfig.Remotes.StatsSync):FireClient(player, stats:Serialize())
end

local function savePlayer(player)
	local stats = playerStates[player.UserId]
	if not stats then
		return
	end
	DataService.SavePlayerData(player.UserId, stats:ToSaveData())
end

local function applyCharacterStats(character, stats)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = stats:GetMoveSpeed()
		humanoid.JumpPower = Config.BaseJumpPower
	end
	GrowthService.ApplyToCharacter(character, stats.size)
end

local function setupCharacter(player, character)
	local stats = playerStates[player.UserId]
	if not stats then
		return
	end

	brushCooldowns[player.UserId] = 0

	local humanoid = character:WaitForChild("Humanoid", 10)
	if humanoid then
		applyCharacterStats(character, stats)
	end

	syncStats(player, stats)
end

--------------------------------------------------
-- State management
--------------------------------------------------

local function broadcastState()
	RemoteSetup.GetRemote(GameConfig.Remotes.GameStateChanged):FireAllClients(currentState)
end

local function setState(newState)
	currentState = newState
	broadcastState()
end

function GameManager.GetState()
	return currentState
end

--------------------------------------------------
-- Waiting room
--------------------------------------------------

local function getPlayerCount()
	return #Players:GetPlayers()
end

local function startCountdown()
	if countdownActive then
		return
	end
	countdownActive = true

	local countdownRemote = RemoteSetup.GetRemote(GameConfig.Remotes.CountdownTick)

	for i = GameConfig.COUNTDOWN_SECONDS, 1, -1 do
		if getPlayerCount() < GameConfig.MIN_PLAYERS_TO_START then
			countdownActive = false
			countdownRemote:FireAllClients(0)
			return
		end
		countdownRemote:FireAllClients(i)
		task.wait(1)
	end

	countdownActive = false
	GameManager.StartSession()
end

local function tryStartCountdown()
	if currentState ~= GameConfig.GameState.WaitingRoom then
		return
	end
	if getPlayerCount() >= GameConfig.MIN_PLAYERS_TO_START and not countdownActive then
		task.spawn(startCountdown)
	end
end

--------------------------------------------------
-- Game session
--------------------------------------------------

function GameManager.StartSession()
	-- Reset per-round state for all players
	sessionScores = {}
	for _, player in ipairs(Players:GetPlayers()) do
		sessionScores[player.UserId] = 0
		local stats = playerStates[player.UserId]
		if stats then
			stats.paint = stats:GetMaxPaint()
			stats.size = Config.BaseCharacterScale
			stats.milestoneIndex = 0
			brushCooldowns[player.UserId] = 0

			local character = player.Character
			if character then
				applyCharacterStats(character, stats)
			end
			syncStats(player, stats)
		end
	end

	-- Reset wall paint for the new round
	PaintService.ResetWalls()

	-- Teleport players to arena
	teleportAllToArena()

	setState(GameConfig.GameState.InGame)
end

function GameManager.EndSession()
	setState(GameConfig.GameState.GameOver)

	-- Record leaderboard scores and save progression
	for _, player in ipairs(Players:GetPlayers()) do
		local painted = sessionScores[player.UserId] or 0
		LeaderboardService.RecordSessionEnd(player, painted)
		savePlayer(player)
	end

	-- Brief pause to show results
	task.wait(5)

	-- Reset per-round stats for next round
	for _, player in ipairs(Players:GetPlayers()) do
		local stats = playerStates[player.UserId]
		if stats then
			stats.paint = stats:GetMaxPaint()
			stats.size = Config.BaseCharacterScale
			stats.milestoneIndex = 0

			local character = player.Character
			if character then
				applyCharacterStats(character, stats)
			end
			syncStats(player, stats)
		end
	end

	sessionScores = {}

	-- Teleport players back to lobby
	teleportAllToLobby()

	setState(GameConfig.GameState.WaitingRoom)
	tryStartCountdown()
end

--------------------------------------------------
-- Paint handler (physical wall painting)
--------------------------------------------------

local function onPaintRequest(player, brushPosition, targetTile)
	if currentState ~= GameConfig.GameState.InGame then
		return
	end

	local stats = playerStates[player.UserId]
	if not stats then return end

	local now = tick()
	local lastTime = brushCooldowns[player.UserId] or 0
	if now - lastTime < stats:GetBrushCooldown() then return end
	brushCooldowns[player.UserId] = now

	local character = player.Character
	if not character then return end
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return end
	if (rootPart.Position - brushPosition).Magnitude > 30 then return end

	local painted = PaintService.TryPaint(player, stats, brushPosition, targetTile)

	if painted > 0 then
		-- Award coins
		local coinsFromPaint = math.max(1, math.floor(painted / math.max(1, Config.PaintTilesPerCoin)))
		stats.coins = stats.coins + coinsFromPaint

		-- Growth
		local changed = GrowthService.ApplyGrowth(stats, painted)
		if changed then
			applyCharacterStats(character, stats)
		end

		-- Milestones
		local coinsEarned = GrowthService.CheckMilestones(stats)
		if coinsEarned > 0 then
			RemoteSetup.GetRemote(GameConfig.Remotes.MilestoneReached):FireClient(player, coinsEarned, stats.size)
		end

		-- Session score + leaderboard
		sessionScores[player.UserId] = (sessionScores[player.UserId] or 0) + painted
		LeaderboardService.RecordWallPainted(player)

		RemoteSetup.GetRemote(GameConfig.Remotes.SessionScoreUpdate):FireClient(player, sessionScores[player.UserId])
	end

	RemoteSetup.GetRemote(GameConfig.Remotes.Feedback):FireClient(player, "paint", stats.paint, stats.size)
	syncStats(player, stats)
end

--------------------------------------------------
-- Upgrade handler
--------------------------------------------------

local function onBuyUpgrade(player, upgradeId)
	local stats = playerStates[player.UserId]
	if not stats then return false, "No stats" end

	local success, msg = UpgradeService.TryPurchase(stats, upgradeId)
	if success then
		local character = player.Character
		if character then
			applyCharacterStats(character, stats)
		end
		syncStats(player, stats)
	end
	return success, msg
end

--------------------------------------------------
-- Leaderboard request handler
--------------------------------------------------

local function onLeaderboardRequest(player)
	local overall = LeaderboardService.GetOverallLeaderboard()
	local bestSession = LeaderboardService.GetSessionLeaderboard()
	local pStats = LeaderboardService.GetPlayerStats(player)

	RemoteSetup.GetRemote(GameConfig.Remotes.LeaderboardUpdate):FireClient(player, {
		Overall = overall,
		BestSession = bestSession,
		PlayerStats = pStats,
	})
end

--------------------------------------------------
-- Start game request
--------------------------------------------------

local function onRequestStartGame(player)
	if currentState ~= GameConfig.GameState.WaitingRoom then
		return
	end
	tryStartCountdown()
end

--------------------------------------------------
-- Player lifecycle
--------------------------------------------------

local function onPlayerAdded(player)
	-- Create stats with saved progression
	local colorIndex = assignColor()
	local stats = PlayerStats.new(colorIndex)
	local loadedData = DataService.LoadPlayerData(player.UserId)
	local sanitizedData = DataService.SanitizePlayerData(loadedData, UpgradeDefinitions, Config)
	if sanitizedData then
		stats:ApplySavedData(sanitizedData)
	end
	playerStates[player.UserId] = stats
	brushCooldowns[player.UserId] = 0

	-- Load leaderboard data
	LeaderboardService.LoadPlayer(player)

	-- Character setup
	player.CharacterAdded:Connect(function(character)
		setupCharacter(player, character)
		-- Teleport to correct location based on game state
		task.defer(function()
			if currentState == GameConfig.GameState.InGame then
				local spawnIndex = math.clamp(stats.colorIndex, 1, #arenaSpawns)
				teleportPlayer(player, arenaSpawns[spawnIndex])
			else
				teleportPlayer(player, lobbySpawnPos)
			end
		end)
	end)
	if player.Character then
		task.defer(function()
			setupCharacter(player, player.Character)
			if currentState == GameConfig.GameState.InGame then
				local spawnIndex = math.clamp(stats.colorIndex, 1, #arenaSpawns)
				teleportPlayer(player, arenaSpawns[spawnIndex])
			else
				teleportPlayer(player, lobbySpawnPos)
			end
		end)
	end

	-- Send current state and stats to joining player
	RemoteSetup.GetRemote(GameConfig.Remotes.GameStateChanged):FireClient(player, currentState)
	syncStats(player, stats)
end

local function onPlayerRemoving(player)
	savePlayer(player)
	LeaderboardService.UnloadPlayer(player)
	playerStates[player.UserId] = nil
	brushCooldowns[player.UserId] = nil
	sessionScores[player.UserId] = nil
end

--------------------------------------------------
-- Initialization
--------------------------------------------------

function GameManager.Init()
	-- Create remotes
	RemoteSetup.Init()

	-- Build the physical world
	WorldBuilder.Build()

	-- Connect remote events
	RemoteSetup.GetRemote(GameConfig.Remotes.Paint).OnServerEvent:Connect(onPaintRequest)
	RemoteSetup.GetRemote(GameConfig.Remotes.RequestLeaderboard).OnServerEvent:Connect(onLeaderboardRequest)
	RemoteSetup.GetRemote(GameConfig.Remotes.RequestStartGame).OnServerEvent:Connect(onRequestStartGame)

	-- Connect remote function
	RemoteSetup.GetRemoteFunction(GameConfig.RemoteFunctions.BuyUpgrade).OnServerInvoke = onBuyUpgrade

	-- Portal pad touch starts countdown
	local lobby = game:GetService("Workspace"):FindFirstChild("Lobby")
	if lobby then
		local portal = lobby:FindFirstChild("PortalPad")
		if portal then
			portal.Touched:Connect(function(hit)
				local touchPlayer = Players:GetPlayerFromCharacter(hit.Parent)
				if touchPlayer then
					tryStartCountdown()
				end
			end)
		end
	end

	-- Player connections
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(onPlayerAdded, player)
	end

	-- Refill loop
	RunService.Heartbeat:Connect(function(dt)
		refillAccum = refillAccum + dt
		if refillAccum < Config.RefillTickSeconds then return end
		refillAccum = 0

		for _, player in ipairs(Players:GetPlayers()) do
			local stats = playerStates[player.UserId]
			if stats then
				local refilled = RefillService.TryRefill(player, stats)
				if refilled then
					syncStats(player, stats)
				end
			end
		end
	end)

	-- Autosave loop
	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_INTERVAL)
			for _, player in ipairs(Players:GetPlayers()) do
				savePlayer(player)
			end
		end
	end)

	-- Save all on shutdown
	game:BindToClose(function()
		for _, player in ipairs(Players:GetPlayers()) do
			savePlayer(player)
		end
	end)

	setState(GameConfig.GameState.WaitingRoom)
	print("[GameManager] Initialized — waiting room active with progression system")
end

return GameManager
