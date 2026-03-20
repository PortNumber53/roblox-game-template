-- GameClient: main client-side controller for the wall painting game

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))
local RemoteSetup = require(ReplicatedStorage:WaitForChild("RemoteSetup"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Initialize the waiting room UI
local WaitingRoomUI = require(playerGui:WaitForChild("WaitingRoomGui"):WaitForChild("WaitingRoomUI"))
WaitingRoomUI.Init()

--------------------------------------------------
-- In-game HUD
--------------------------------------------------

local currentState = GameConfig.GameState.WaitingRoom
local sessionScore = 0

-- Simple in-game HUD
local gameHud = Instance.new("ScreenGui")
gameHud.Name = "GameHUD"
gameHud.ResetOnSpawn = false
gameHud.Enabled = false
gameHud.Parent = playerGui

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

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = scoreLabel

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
-- Wall grid interaction (click-to-paint)
--------------------------------------------------

local function onInputBegan(input, gameProcessed)
	if gameProcessed then
		return
	end
	if currentState ~= GameConfig.GameState.InGame then
		return
	end

	-- Handle mouse click or touch tap
	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then

		-- Cast a ray from the camera to find a wall part
		local camera = workspace.CurrentCamera
		local ray = camera:ViewportPointToRay(input.Position.X, input.Position.Y)
		local raycastParams = RaycastParams.new()
		raycastParams.FilterType = Enum.RaycastFilterType.Include

		local wallFolder = workspace:FindFirstChild("WallGrid")
		if not wallFolder then
			return
		end

		raycastParams.FilterDescendantsInstances = { wallFolder }
		local result = workspace:Raycast(ray.Origin, ray.Direction * 200, raycastParams)

		if result and result.Instance then
			local part = result.Instance
			local row = part:GetAttribute("Row")
			local col = part:GetAttribute("Col")
			if row and col then
				RemoteSetup.GetRemote(GameConfig.Remotes.RequestPaintWall):FireServer(row, col)
			end
		end
	end
end

UserInputService.InputBegan:Connect(onInputBegan)

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

-- Wall state updates (color a part when someone paints)
RemoteSetup.GetRemote(GameConfig.Remotes.WallStateUpdate).OnClientEvent:Connect(function(row, col, painterId)
	local wallFolder = workspace:FindFirstChild("WallGrid")
	if not wallFolder then
		return
	end

	local partName = "Wall_" .. row .. "_" .. col
	local part = wallFolder:FindFirstChild(partName)
	if part then
		-- Use the painter's team/chosen color; for now use a default per-player hue
		local hue = (painterId * 0.13) % 1
		part.Color = Color3.fromHSV(hue, 0.7, 0.9)
		part.Material = Enum.Material.SmoothPlastic
	end
end)

print("[GameClient] Initialized")
