-- WaitingRoomUI: portal popup showing countdown and player count
-- Shown only when player stands on the portal pad

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))
local RemoteSetup = require(ReplicatedStorage:WaitForChild("RemoteSetup"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local WaitingRoomUI = {}

local screenGui
local countdownLabel
local currentStats = nil

--------------------------------------------------
-- UI Construction
--------------------------------------------------

local function createInstance(className, props)
	local inst = Instance.new(className)
	for k, v in pairs(props) do
		if k ~= "Children" and k ~= "Parent" then
			inst[k] = v
		end
	end
	if props.Parent then
		inst.Parent = props.Parent
	end
	return inst
end

--------------------------------------------------
-- Main Build
--------------------------------------------------

function WaitingRoomUI.Init()
	screenGui = createInstance("ScreenGui", {
		Name = "PortalPopup",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Enabled = false,
		Parent = playerGui,
	})

	local frame = createInstance("Frame", {
		Name = "PopupFrame",
		Size = UDim2.new(0, 300, 0, 150),
		Position = UDim2.new(0.5, -150, 0, 30),
		BackgroundColor3 = Color3.fromRGB(20, 20, 35),
		BackgroundTransparency = 0.15,
		Parent = screenGui,
	})
	createInstance("UICorner", { CornerRadius = UDim.new(0, 12), Parent = frame })
	createInstance("UIStroke", {
		Color = Color3.fromRGB(100, 200, 255),
		Thickness = 2,
		Parent = frame,
	})

	createInstance("TextLabel", {
		Name = "Title",
		Text = "Paintball Arena",
		Size = UDim2.new(1, 0, 0, 30),
		Position = UDim2.new(0, 0, 0, 12),
		BackgroundTransparency = 1,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		Font = Enum.Font.GothamBold,
		TextSize = 20,
		Parent = frame,
	})

	createInstance("TextLabel", {
		Name = "PlayerCount",
		Text = "Players: " .. #Players:GetPlayers() .. "/" .. GameConfig.MAX_PLAYERS,
		Size = UDim2.new(1, 0, 0, 24),
		Position = UDim2.new(0, 0, 0, 48),
		BackgroundTransparency = 1,
		TextColor3 = Color3.fromRGB(180, 220, 255),
		Font = Enum.Font.GothamBold,
		TextSize = 16,
		Parent = frame,
	})

	countdownLabel = createInstance("TextLabel", {
		Name = "Countdown",
		Text = "Waiting for players...",
		Size = UDim2.new(1, 0, 0, 40),
		Position = UDim2.new(0, 0, 0, 80),
		BackgroundTransparency = 1,
		TextColor3 = Color3.fromRGB(255, 220, 100),
		Font = Enum.Font.GothamBold,
		TextSize = 28,
		Parent = frame,
	})

	-- Update player count
	local playerCountLabel = frame.PlayerCount
	local function updateCount()
		playerCountLabel.Text = "Players: " .. #Players:GetPlayers() .. "/" .. GameConfig.MAX_PLAYERS
	end
	Players.PlayerAdded:Connect(updateCount)
	Players.PlayerRemoving:Connect(function()
		task.defer(updateCount)
	end)

	-- Countdown ticks
	RemoteSetup.GetRemote(GameConfig.Remotes.CountdownTick).OnClientEvent:Connect(function(seconds)
		if countdownLabel then
			if seconds <= 0 then
				countdownLabel.Text = "Waiting for players..."
			else
				countdownLabel.Text = "Starting in " .. seconds .. "..."
			end
		end
	end)

	-- Hide on game state change away from waiting room
	RemoteSetup.GetRemote(GameConfig.Remotes.GameStateChanged).OnClientEvent:Connect(function(newState)
		if newState ~= GameConfig.GameState.WaitingRoom then
			screenGui.Enabled = false
		end
	end)

	-- Show/hide based on portal proximity
	RemoteSetup.GetRemote(GameConfig.Remotes.PortalStatus).OnClientEvent:Connect(function(onPortal)
		screenGui.Enabled = onPortal
		if not onPortal and countdownLabel then
			countdownLabel.Text = "Waiting for players..."
		end
	end)

	print("[WaitingRoomUI] Initialized")
end

function WaitingRoomUI.UpdateStats(stats)
	currentStats = stats
end

function WaitingRoomUI.GetSelectedColor()
	return GameConfig.DefaultSettings.PaintColor
end

return WaitingRoomUI
