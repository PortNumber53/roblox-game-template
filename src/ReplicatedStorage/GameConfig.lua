-- GameConfig: shared constants and configuration for the wall-painting game

local GameConfig = {}

-- Game states
GameConfig.GameState = {
	WaitingRoom = "WaitingRoom",
	InGame = "InGame",
	GameOver = "GameOver",
}

-- Waiting room settings
GameConfig.MIN_PLAYERS_TO_START = 1
GameConfig.COUNTDOWN_SECONDS = 10
GameConfig.MAX_PLAYERS = 12

-- Game session settings
GameConfig.SESSION_DURATION_SECONDS = 120
GameConfig.WALL_GRID_ROWS = 10
GameConfig.WALL_GRID_COLS = 16

-- Leaderboard
GameConfig.LEADERBOARD_MAX_ENTRIES = 50

-- Remote event names
GameConfig.Remotes = {
	-- Server -> Client
	GameStateChanged = "GameStateChanged",
	LeaderboardUpdate = "LeaderboardUpdate",
	CountdownTick = "CountdownTick",
	WallStateUpdate = "WallStateUpdate",
	SessionScoreUpdate = "SessionScoreUpdate",

	-- Client -> Server
	RequestStartGame = "RequestStartGame",
	RequestPaintWall = "RequestPaintWall",
	RequestLeaderboard = "RequestLeaderboard",
	RequestSettings = "RequestSettings",
	UpdateSetting = "UpdateSetting",
}

-- Player settings defaults
GameConfig.DefaultSettings = {
	PaintColor = Color3.fromRGB(0, 120, 255),
	MusicEnabled = true,
	SFXEnabled = true,
}

-- Available paint colors
GameConfig.PaintColors = {
	{ Name = "Blue",   Color = Color3.fromRGB(0, 120, 255) },
	{ Name = "Red",    Color = Color3.fromRGB(255, 50, 50) },
	{ Name = "Green",  Color = Color3.fromRGB(50, 200, 50) },
	{ Name = "Yellow", Color = Color3.fromRGB(255, 220, 50) },
	{ Name = "Purple", Color = Color3.fromRGB(160, 50, 255) },
	{ Name = "Orange", Color = Color3.fromRGB(255, 140, 0) },
	{ Name = "Pink",   Color = Color3.fromRGB(255, 100, 180) },
	{ Name = "White",  Color = Color3.fromRGB(240, 240, 240) },
}

return GameConfig
