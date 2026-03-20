-- GameManager: orchestrates the game flow between waiting room and game sessions

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))
local RemoteSetup = require(ReplicatedStorage:WaitForChild("RemoteSetup"))
local LeaderboardService = require(script.Parent:WaitForChild("LeaderboardService"))
local WallPaintingService = require(script.Parent:WaitForChild("WallPaintingService"))

local GameManager = {}

local currentState = GameConfig.GameState.WaitingRoom
local countdownActive = false
local sessionScores = {} -- [userId] = number of walls painted this session

--------------------------------------------------
-- State management
--------------------------------------------------

local function broadcastState()
	local remote = RemoteSetup.GetRemote(GameConfig.Remotes.GameStateChanged)
	remote:FireAllClients(currentState)
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
		-- Abort if players drop below minimum
		if getPlayerCount() < GameConfig.MIN_PLAYERS_TO_START then
			countdownActive = false
			countdownRemote:FireAllClients(0) -- signal countdown cancelled
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
	sessionScores = {}
	for _, player in ipairs(Players:GetPlayers()) do
		sessionScores[player.UserId] = 0
	end

	-- Initialize the wall grid
	WallPaintingService.ResetWalls()

	setState(GameConfig.GameState.InGame)

	-- Session timer
	task.delay(GameConfig.SESSION_DURATION_SECONDS, function()
		if currentState == GameConfig.GameState.InGame then
			GameManager.EndSession()
		end
	end)
end

function GameManager.EndSession()
	setState(GameConfig.GameState.GameOver)

	-- Record session scores in leaderboards
	for _, player in ipairs(Players:GetPlayers()) do
		local painted = sessionScores[player.UserId] or 0
		LeaderboardService.RecordSessionEnd(player, painted)
	end

	-- Brief pause to show results, then back to waiting room
	task.wait(5)
	sessionScores = {}
	setState(GameConfig.GameState.WaitingRoom)

	-- Check if we should start a new countdown immediately
	tryStartCountdown()
end

--------------------------------------------------
-- Wall painting handler
--------------------------------------------------

local function onPaintWallRequest(player: Player, row: number, col: number)
	if currentState ~= GameConfig.GameState.InGame then
		return
	end

	local success = WallPaintingService.PaintCell(player, row, col)
	if success then
		-- Update scores
		sessionScores[player.UserId] = (sessionScores[player.UserId] or 0) + 1
		LeaderboardService.RecordWallPainted(player)

		-- Notify all clients of the wall update
		local wallRemote = RemoteSetup.GetRemote(GameConfig.Remotes.WallStateUpdate)
		wallRemote:FireAllClients(row, col, player.UserId)

		-- Notify the painting player of their updated session score
		local scoreRemote = RemoteSetup.GetRemote(GameConfig.Remotes.SessionScoreUpdate)
		scoreRemote:FireClient(player, sessionScores[player.UserId])
	end
end

--------------------------------------------------
-- Leaderboard request handler
--------------------------------------------------

local function onLeaderboardRequest(player: Player)
	local overall = LeaderboardService.GetOverallLeaderboard()
	local bestSession = LeaderboardService.GetSessionLeaderboard()
	local playerStats = LeaderboardService.GetPlayerStats(player)

	local remote = RemoteSetup.GetRemote(GameConfig.Remotes.LeaderboardUpdate)
	remote:FireClient(player, {
		Overall = overall,
		BestSession = bestSession,
		PlayerStats = playerStats,
	})
end

--------------------------------------------------
-- Start game request (manual start from waiting room)
--------------------------------------------------

local function onRequestStartGame(player: Player)
	if currentState ~= GameConfig.GameState.WaitingRoom then
		return
	end
	tryStartCountdown()
end

--------------------------------------------------
-- Player lifecycle
--------------------------------------------------

local function onPlayerAdded(player: Player)
	LeaderboardService.LoadPlayer(player)

	-- Send current state to the joining player
	local stateRemote = RemoteSetup.GetRemote(GameConfig.Remotes.GameStateChanged)
	stateRemote:FireClient(player, currentState)

	-- If in waiting room, check if we can start
	tryStartCountdown()
end

local function onPlayerRemoving(player: Player)
	LeaderboardService.UnloadPlayer(player)
	sessionScores[player.UserId] = nil
end

--------------------------------------------------
-- Initialization
--------------------------------------------------

function GameManager.Init()
	-- Create remotes
	RemoteSetup.Init()

	-- Connect remote events
	RemoteSetup.GetRemote(GameConfig.Remotes.RequestPaintWall).OnServerEvent:Connect(onPaintWallRequest)
	RemoteSetup.GetRemote(GameConfig.Remotes.RequestLeaderboard).OnServerEvent:Connect(onLeaderboardRequest)
	RemoteSetup.GetRemote(GameConfig.Remotes.RequestStartGame).OnServerEvent:Connect(onRequestStartGame)

	-- Player connections
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	-- Handle players already in game (Studio quick-start)
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(onPlayerAdded, player)
	end

	setState(GameConfig.GameState.WaitingRoom)
	print("[GameManager] Initialized — waiting room active")
end

return GameManager
