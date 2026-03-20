-- GameClient: main client-side controller for session flow and HUD

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))
local RemoteSetup = require(ReplicatedStorage:WaitForChild("RemoteSetup"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Initialize the waiting room UI
local WaitingRoomUI = require(ReplicatedStorage:WaitForChild("WaitingRoomUI"))
WaitingRoomUI.Init()

--------------------------------------------------
-- Local state
--------------------------------------------------

local currentState = GameConfig.GameState.WaitingRoom
local sessionScore = 0
local localStats = nil

--------------------------------------------------
-- In-game HUD
--------------------------------------------------

local gameHud = Instance.new("ScreenGui")
gameHud.Name = "GameHUD"
gameHud.ResetOnSpawn = false
gameHud.Enabled = false
gameHud.Parent = playerGui

-- Score label (top center)
local scoreLabel = Instance.new("TextLabel")
scoreLabel.Name = "ScoreLabel"
scoreLabel.Size = UDim2.new(0, 200, 0, 40)
scoreLabel.Position = UDim2.new(0.5, -100, 0, 10)
scoreLabel.BackgroundColor3 = Color3.fromRGB(30, 30, 50)
scoreLabel.BackgroundTransparency = 0.3
scoreLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
scoreLabel.Font = Enum.Font.GothamBold
scoreLabel.TextSize = 20
scoreLabel.Text = "Walls Painted: 0"
scoreLabel.Parent = gameHud
Instance.new("UICorner", scoreLabel).CornerRadius = UDim.new(0, 8)

-- Timer label
local timerLabel = Instance.new("TextLabel")
timerLabel.Name = "TimerLabel"
timerLabel.Size = UDim2.new(0, 120, 0, 30)
timerLabel.Position = UDim2.new(0.5, -60, 0, 55)
timerLabel.BackgroundTransparency = 1
timerLabel.TextColor3 = Color3.fromRGB(200, 200, 220)
timerLabel.Font = Enum.Font.Gotham
timerLabel.TextSize = 16
timerLabel.Text = ""
timerLabel.Parent = gameHud

--------------------------------------------------
-- Remote event listeners
--------------------------------------------------

-- Game state changes
RemoteSetup.GetRemote(GameConfig.Remotes.GameStateChanged).OnClientEvent:Connect(function(newState)
	currentState = newState

	if newState == GameConfig.GameState.InGame then
		gameHud.Enabled = true
		sessionScore = 0
		scoreLabel.Text = "Walls Painted: 0"
		timerLabel.Text = ""
	elseif newState == GameConfig.GameState.GameOver then
		gameHud.Enabled = true
		timerLabel.Text = "Game Over!"
	else
		gameHud.Enabled = false
		timerLabel.Text = ""
	end
end)

-- Session score updates
RemoteSetup.GetRemote(GameConfig.Remotes.SessionScoreUpdate).OnClientEvent:Connect(function(score)
	sessionScore = score
	scoreLabel.Text = "Walls Painted: " .. score
end)

-- Stats sync from server
RemoteSetup.GetRemote(GameConfig.Remotes.StatsSync).OnClientEvent:Connect(function(stats)
	localStats = stats
	WaitingRoomUI.UpdateStats(stats)
end)

-- Paint feedback
RemoteSetup.GetRemote(GameConfig.Remotes.Feedback).OnClientEvent:Connect(function(feedbackType, paint)
	if feedbackType == "paint" and localStats then
		localStats.paint = paint
	end
end)

print("[GameClient] Initialized")
