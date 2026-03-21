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
local UpgradeService = require(script.Parent:WaitForChild("UpgradeService"))
local RefillService = require(script.Parent:WaitForChild("RefillService"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local ShootingService = require(script.Parent:WaitForChild("ShootingService"))

local GameManager = {}

-- Session state
local currentState = GameConfig.GameState.WaitingRoom
local countdownActive = false
local countdownCancelled = false
local sessionScores = {}
local playersOnPortal = {}

-- Progression state
local playerStates = {}
local colorCounter = 0
local brushCooldowns = {}
local refillAccum = 0
local AUTOSAVE_INTERVAL = 60
local shuttingDown = false
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
end

local function setupCharacter(player, character)
	local stats = playerStates[player.UserId]
	if not stats then
		return
	end

	brushCooldowns[player.UserId] = 0

	-- Refill ammo on respawn
	stats.paint = stats:GetMaxPaint()

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

local function getPortalPlayerCount()
	local count = 0
	for _, onPortal in pairs(playersOnPortal) do
		if onPortal then
			count = count + 1
		end
	end
	return count
end

local function cancelCountdown()
	if countdownActive then
		countdownCancelled = true
	end
end

local function startCountdown()
	if countdownActive then
		return
	end
	countdownActive = true
	countdownCancelled = false

	local countdownRemote = RemoteSetup.GetRemote(GameConfig.Remotes.CountdownTick)

	for i = GameConfig.COUNTDOWN_SECONDS, 1, -1 do
		if countdownCancelled or getPortalPlayerCount() < GameConfig.MIN_PLAYERS_TO_START then
			countdownActive = false
			countdownCancelled = false
			countdownRemote:FireAllClients(0)
			return
		end
		countdownRemote:FireAllClients(i)
		task.wait(1)
	end

	countdownActive = false
	countdownCancelled = false
	GameManager.StartSession()
end

local function tryStartCountdown()
	if currentState ~= GameConfig.GameState.WaitingRoom then
		return
	end
	if getPortalPlayerCount() >= GameConfig.MIN_PLAYERS_TO_START and not countdownActive then
		task.spawn(startCountdown)
	end
end

--------------------------------------------------
-- Game session
--------------------------------------------------

function GameManager.StartSession()
	-- Clear portal state
	playersOnPortal = {}

	-- Reset per-round state for all players
	sessionScores = {}
	for _, player in ipairs(Players:GetPlayers()) do
		sessionScores[player.UserId] = 0
		local stats = playerStates[player.UserId]
		if stats then
			stats.paint = stats:GetMaxPaint()
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
	LeaderboardService.Save()

	-- Brief pause to show results
	task.wait(5)

	-- Reset per-round stats for next round
	for _, player in ipairs(Players:GetPlayers()) do
		local stats = playerStates[player.UserId]
		if stats then
			stats.paint = stats:GetMaxPaint()

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
	updateLeaderboardBoards()
	tryStartCountdown()
end

--------------------------------------------------
-- Shooting handler (paintball)
--------------------------------------------------

local function onShootPaintball(player, origin, direction)
	if currentState ~= GameConfig.GameState.InGame then
		return
	end

	local stats = playerStates[player.UserId]
	if not stats then return end

	if typeof(origin) ~= "Vector3" or typeof(direction) ~= "Vector3" then return end

	local shotResult = ShootingService.ProcessShot(player, stats, origin, direction, brushCooldowns)
	if not shotResult then return end

	if shotResult.hit then
		local painted = PaintService.TryPaint(player, stats, shotResult.hitPosition, shotResult.hitTile)

		RemoteSetup.GetRemote(GameConfig.Remotes.PaintballHit):FireClient(
			player, shotResult.hitPosition, painted > 0
		)

		if painted > 0 then
			local coinsFromPaint = math.max(1, math.floor(painted / math.max(1, Config.PaintTilesPerCoin)))
			stats.coins = stats.coins + coinsFromPaint

			sessionScores[player.UserId] = (sessionScores[player.UserId] or 0) + painted
			LeaderboardService.RecordWallPainted(player)
			RemoteSetup.GetRemote(GameConfig.Remotes.SessionScoreUpdate):FireClient(player, sessionScores[player.UserId])
		end
	end

	-- Always sync stats so client sees ammo decrease
	RemoteSetup.GetRemote(GameConfig.Remotes.Feedback):FireClient(player, "paint", stats.paint)
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
		savePlayer(player)
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
	if not shuttingDown then
		local painted = sessionScores[player.UserId] or 0
		if painted > 0 then
			LeaderboardService.RecordSessionEnd(player, painted)
			LeaderboardService.Save()
		end
		savePlayer(player)
	end

	LeaderboardService.UnloadPlayer(player)
	playerStates[player.UserId] = nil
	brushCooldowns[player.UserId] = nil
	sessionScores[player.UserId] = nil
	playersOnPortal[player.UserId] = nil
end

--------------------------------------------------
-- Leaderboard display boards
--------------------------------------------------

local function populateBoard(surfaceGui, entries)
	local bg = surfaceGui:FindFirstChild("Background")
	if not bg then return end

	-- Clear old entries
	for _, child in ipairs(bg:GetChildren()) do
		child:Destroy()
	end

	for i, entry in ipairs(entries) do
		if i > 10 then break end

		local row = Instance.new("TextLabel")
		row.Size = UDim2.new(1, -20, 0, 26)
		row.Position = UDim2.new(0, 10, 0, (i - 1) * 28 + 8)
		row.BackgroundTransparency = 1
		row.Font = Enum.Font.GothamBold
		row.TextSize = 18
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.TextColor3 = i <= 3 and Color3.fromRGB(255, 220, 100) or Color3.fromRGB(200, 200, 220)
		row.Text = string.format("#%d  %s  —  %d", entry.Rank, entry.Name, entry.Value)
		row.Parent = bg
	end

	if #entries == 0 then
		local empty = Instance.new("TextLabel")
		empty.Size = UDim2.new(1, 0, 1, 0)
		empty.BackgroundTransparency = 1
		empty.Font = Enum.Font.Gotham
		empty.TextSize = 20
		empty.TextColor3 = Color3.fromRGB(120, 120, 140)
		empty.Text = "No data yet"
		empty.Parent = bg
	end
end

local function updateLeaderboardBoards()
	local lobby = game:GetService("Workspace"):FindFirstChild("Lobby")
	if not lobby then return end

	local overallBoard = lobby:FindFirstChild("OverallBoard")
	local sessionBoard = lobby:FindFirstChild("SessionBoard")

	if overallBoard then
		local entries = LeaderboardService.GetOverallLeaderboard()
		local front = overallBoard:FindFirstChild("LeaderboardDisplay")
		local back = overallBoard:FindFirstChild("LeaderboardDisplayBack")
		if front then populateBoard(front, entries) end
		if back then populateBoard(back, entries) end
	end

	if sessionBoard then
		local entries = LeaderboardService.GetSessionLeaderboard()
		local front = sessionBoard:FindFirstChild("LeaderboardDisplay")
		local back = sessionBoard:FindFirstChild("LeaderboardDisplayBack")
		if front then populateBoard(front, entries) end
		if back then populateBoard(back, entries) end
	end
end

--------------------------------------------------
-- Initialization
--------------------------------------------------

function GameManager.Init()
	-- Create remotes
	RemoteSetup.Init()

	-- Load leaderboard history from DataStore
	LeaderboardService.Init()

	-- Build the physical world
	WorldBuilder.Build()

	-- Connect remote events
	RemoteSetup.GetRemote(GameConfig.Remotes.ShootPaintball).OnServerEvent:Connect(onShootPaintball)
	RemoteSetup.GetRemote(GameConfig.Remotes.RequestLeaderboard).OnServerEvent:Connect(onLeaderboardRequest)
	RemoteSetup.GetRemote(GameConfig.Remotes.RequestStartGame).OnServerEvent:Connect(onRequestStartGame)

	-- Connect remote function
	RemoteSetup.GetRemoteFunction(GameConfig.RemoteFunctions.BuyUpgrade).OnServerInvoke = onBuyUpgrade

	-- Portal pad proximity polling (replaces unreliable Touched/TouchEnded)
	local portalPad = game:GetService("Workspace"):FindFirstChild("Lobby") and game:GetService("Workspace").Lobby:FindFirstChild("PortalPad")
	local portalRemote = RemoteSetup.GetRemote(GameConfig.Remotes.PortalStatus)
	local PORTAL_RADIUS = 7

	RunService.Heartbeat:Connect(function()
		if currentState ~= GameConfig.GameState.WaitingRoom then return end
		if not portalPad then return end

		local portalPos = portalPad.Position

		for _, p in ipairs(Players:GetPlayers()) do
			local character = p.Character
			local rootPart = character and character:FindFirstChild("HumanoidRootPart")
			local wasOnPortal = playersOnPortal[p.UserId] or false
			local isOnPortal = false

			if rootPart then
				local offset = rootPart.Position - portalPos
				isOnPortal = math.abs(offset.X) <= PORTAL_RADIUS
					and math.abs(offset.Z) <= PORTAL_RADIUS
					and math.abs(offset.Y) <= 5
			end

			if isOnPortal and not wasOnPortal then
				playersOnPortal[p.UserId] = true
				portalRemote:FireClient(p, true)
				tryStartCountdown()
			elseif not isOnPortal and wasOnPortal then
				playersOnPortal[p.UserId] = false
				portalRemote:FireClient(p, false)
				if getPortalPlayerCount() < GameConfig.MIN_PLAYERS_TO_START then
					cancelCountdown()
				end
			end
		end
	end)

	-- Update leaderboard display boards periodically
	task.spawn(function()
		while true do
			task.wait(15)
			updateLeaderboardBoards()
		end
	end)

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
		shuttingDown = true
		for _, player in ipairs(Players:GetPlayers()) do
			-- Only record if not already handled by PlayerRemoving
			local painted = sessionScores[player.UserId]
			if painted and painted > 0 then
				LeaderboardService.RecordSessionEnd(player, painted)
				sessionScores[player.UserId] = nil
			end
			if playerStates[player.UserId] then
				savePlayer(player)
			end
		end
		LeaderboardService.Save()
		task.wait(2)
	end)

	setState(GameConfig.GameState.WaitingRoom)
	updateLeaderboardBoards()
	print("[GameManager] Initialized — waiting room active with progression system")
end

return GameManager
