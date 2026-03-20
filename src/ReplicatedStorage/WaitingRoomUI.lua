-- WaitingRoomUI: builds and manages the waiting room GUI
-- Tabs: Lobby, Upgrades, Settings, Leaderboards

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))
local RemoteSetup = require(ReplicatedStorage:WaitForChild("RemoteSetup"))
local UpgradeDefinitions = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UpgradeDefinitions"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local WaitingRoomUI = {}

local screenGui
local mainFrame
local tabButtons = {}
local tabPanels = {}
local countdownLabel
local activeTab = "Lobby"

-- Player settings (local state)
local playerSettings = {
	PaintColorIndex = 1,
	MusicEnabled = true,
	SFXEnabled = true,
}

-- Current stats from server
local currentStats = nil
local upgradeButtons = {}

--------------------------------------------------
-- UI Construction Helpers
--------------------------------------------------

local function createInstance(className, props)
	local inst = Instance.new(className)
	for k, v in pairs(props) do
		if k ~= "Children" and k ~= "Parent" then
			inst[k] = v
		end
	end
	if props.Children then
		for _, child in ipairs(props.Children) do
			child.Parent = inst
		end
	end
	if props.Parent then
		inst.Parent = props.Parent
	end
	return inst
end

local function makeTextButton(text, position, size, parent, callback)
	local btn = createInstance("TextButton", {
		Text = text,
		Position = position,
		Size = size,
		BackgroundColor3 = Color3.fromRGB(60, 60, 80),
		TextColor3 = Color3.fromRGB(255, 255, 255),
		Font = Enum.Font.GothamBold,
		TextSize = 16,
		Parent = parent,
	})
	createInstance("UICorner", { CornerRadius = UDim.new(0, 6), Parent = btn })
	if callback then
		btn.MouseButton1Click:Connect(callback)
	end
	return btn
end

--------------------------------------------------
-- Tab Switching
--------------------------------------------------

local function switchTab(tabName)
	activeTab = tabName
	for name, panel in pairs(tabPanels) do
		panel.Visible = (name == tabName)
	end
	for name, btn in pairs(tabButtons) do
		if name == tabName then
			btn.BackgroundColor3 = Color3.fromRGB(80, 120, 200)
		else
			btn.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
		end
	end

	if tabName == "Leaderboards" then
		RemoteSetup.GetRemote(GameConfig.Remotes.RequestLeaderboard):FireServer()
	end
end

--------------------------------------------------
-- Lobby Panel
--------------------------------------------------

local function buildLobbyPanel(parent)
	local panel = createInstance("Frame", {
		Name = "LobbyPanel",
		Size = UDim2.new(1, 0, 1, -50),
		Position = UDim2.new(0, 0, 0, 50),
		BackgroundTransparency = 1,
		Parent = parent,
	})

	createInstance("TextLabel", {
		Name = "Title",
		Text = "Wall Painting Arena",
		Size = UDim2.new(1, 0, 0, 40),
		Position = UDim2.new(0, 0, 0, 10),
		BackgroundTransparency = 1,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		Font = Enum.Font.GothamBold,
		TextSize = 28,
		Parent = panel,
	})

	createInstance("TextLabel", {
		Name = "Description",
		Text = "Paint the walls, grow bigger, earn coins!\nBuy upgrades between rounds.",
		Size = UDim2.new(1, -40, 0, 50),
		Position = UDim2.new(0, 20, 0, 60),
		BackgroundTransparency = 1,
		TextColor3 = Color3.fromRGB(200, 200, 220),
		Font = Enum.Font.Gotham,
		TextSize = 16,
		TextWrapped = true,
		Parent = panel,
	})

	createInstance("TextLabel", {
		Name = "PlayerCount",
		Text = "Players: " .. #Players:GetPlayers() .. "/" .. GameConfig.MAX_PLAYERS,
		Size = UDim2.new(1, 0, 0, 30),
		Position = UDim2.new(0, 0, 0, 130),
		BackgroundTransparency = 1,
		TextColor3 = Color3.fromRGB(180, 220, 255),
		Font = Enum.Font.GothamBold,
		TextSize = 18,
		Parent = panel,
	})

	countdownLabel = createInstance("TextLabel", {
		Name = "Countdown",
		Text = "",
		Size = UDim2.new(1, 0, 0, 50),
		Position = UDim2.new(0, 0, 0, 170),
		BackgroundTransparency = 1,
		TextColor3 = Color3.fromRGB(255, 220, 100),
		Font = Enum.Font.GothamBold,
		TextSize = 32,
		Parent = panel,
	})

	makeTextButton(
		"Ready Up",
		UDim2.new(0.5, -80, 0, 240),
		UDim2.new(0, 160, 0, 45),
		panel,
		function()
			RemoteSetup.GetRemote(GameConfig.Remotes.RequestStartGame):FireServer()
		end
	)

	Players.PlayerAdded:Connect(function()
		panel.PlayerCount.Text = "Players: " .. #Players:GetPlayers() .. "/" .. GameConfig.MAX_PLAYERS
	end)
	Players.PlayerRemoving:Connect(function()
		task.defer(function()
			panel.PlayerCount.Text = "Players: " .. #Players:GetPlayers() .. "/" .. GameConfig.MAX_PLAYERS
		end)
	end)

	return panel
end

--------------------------------------------------
-- Upgrades Panel
--------------------------------------------------

local function refreshUpgradeButtons()
	if not currentStats then return end

	for upgradeId, entry in pairs(upgradeButtons) do
		local def = UpgradeDefinitions[upgradeId]
		if not def then continue end

		local level = 0
		if currentStats.upgrades and currentStats.upgrades[upgradeId] then
			level = currentStats.upgrades[upgradeId]
		end

		local maxed = level >= def.maxLevel
		local cost = def.baseCost + def.costStep * level
		local canAfford = currentStats.coins and currentStats.coins >= cost

		entry.levelLabel.Text = string.format("Lv %d / %d", level, def.maxLevel)

		if maxed then
			entry.button.Text = "MAXED"
			entry.button.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
		else
			entry.button.Text = string.format("Buy (%d coins)", cost)
			if canAfford then
				entry.button.BackgroundColor3 = Color3.fromRGB(50, 140, 80)
			else
				entry.button.BackgroundColor3 = Color3.fromRGB(100, 50, 50)
			end
		end
	end

	-- Update coins display in upgrades panel
	local upgradesPanel = tabPanels["Upgrades"]
	if upgradesPanel then
		local coinsDisplay = upgradesPanel:FindFirstChild("CoinsDisplay")
		if coinsDisplay then
			coinsDisplay.Text = "Coins: " .. (currentStats.coins or 0)
		end
	end
end

local function buildUpgradesPanel(parent)
	local panel = createInstance("Frame", {
		Name = "UpgradesPanel",
		Size = UDim2.new(1, 0, 1, -50),
		Position = UDim2.new(0, 0, 0, 50),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = parent,
	})

	createInstance("TextLabel", {
		Name = "Title",
		Text = "Upgrades",
		Size = UDim2.new(1, 0, 0, 30),
		Position = UDim2.new(0, 0, 0, 5),
		BackgroundTransparency = 1,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		Font = Enum.Font.GothamBold,
		TextSize = 22,
		Parent = panel,
	})

	createInstance("TextLabel", {
		Name = "CoinsDisplay",
		Text = "Coins: 0",
		Size = UDim2.new(1, 0, 0, 24),
		Position = UDim2.new(0, 0, 0, 35),
		BackgroundTransparency = 1,
		TextColor3 = Color3.fromRGB(255, 220, 100),
		Font = Enum.Font.GothamBold,
		TextSize = 18,
		Parent = panel,
	})

	local scrollFrame = createInstance("ScrollingFrame", {
		Name = "UpgradeList",
		Size = UDim2.new(1, -20, 1, -70),
		Position = UDim2.new(0, 10, 0, 65),
		BackgroundTransparency = 1,
		ScrollBarThickness = 6,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		Parent = panel,
	})

	-- Build upgrade rows sorted by id for stable ordering
	local sortedIds = {}
	for id in pairs(UpgradeDefinitions) do
		table.insert(sortedIds, id)
	end
	table.sort(sortedIds)

	local yOffset = 0
	local ROW_HEIGHT = 55

	for _, upgradeId in ipairs(sortedIds) do
		local def = UpgradeDefinitions[upgradeId]

		local row = createInstance("Frame", {
			Name = upgradeId,
			Size = UDim2.new(1, -10, 0, ROW_HEIGHT - 5),
			Position = UDim2.new(0, 5, 0, yOffset),
			BackgroundColor3 = Color3.fromRGB(40, 40, 60),
			BackgroundTransparency = 0.3,
			Parent = scrollFrame,
		})
		createInstance("UICorner", { CornerRadius = UDim.new(0, 6), Parent = row })

		-- Upgrade name
		createInstance("TextLabel", {
			Text = def.displayName,
			Size = UDim2.new(0.45, -5, 0, 22),
			Position = UDim2.new(0, 10, 0, 5),
			BackgroundTransparency = 1,
			TextColor3 = Color3.fromRGB(220, 220, 240),
			Font = Enum.Font.GothamBold,
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = row,
		})

		-- Level label
		local levelLabel = createInstance("TextLabel", {
			Name = "Level",
			Text = "Lv 0 / " .. def.maxLevel,
			Size = UDim2.new(0.45, -5, 0, 18),
			Position = UDim2.new(0, 10, 0, 27),
			BackgroundTransparency = 1,
			TextColor3 = Color3.fromRGB(160, 160, 180),
			Font = Enum.Font.Gotham,
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = row,
		})

		-- Buy button
		local buyBtn = createInstance("TextButton", {
			Name = "BuyBtn",
			Text = string.format("Buy (%d coins)", def.baseCost),
			Size = UDim2.new(0.45, -10, 0, 32),
			Position = UDim2.new(0.55, 0, 0.5, -16),
			BackgroundColor3 = Color3.fromRGB(50, 140, 80),
			TextColor3 = Color3.fromRGB(255, 255, 255),
			Font = Enum.Font.GothamBold,
			TextSize = 13,
			Parent = row,
		})
		createInstance("UICorner", { CornerRadius = UDim.new(0, 6), Parent = buyBtn })

		buyBtn.MouseButton1Click:Connect(function()
			local rf = RemoteSetup.GetRemoteFunction(GameConfig.RemoteFunctions.BuyUpgrade)
			local success, msg = rf:InvokeServer(upgradeId)
			if not success then
				buyBtn.Text = msg or "Failed"
				task.delay(1, refreshUpgradeButtons)
			end
		end)

		upgradeButtons[upgradeId] = {
			button = buyBtn,
			levelLabel = levelLabel,
		}

		yOffset = yOffset + ROW_HEIGHT
	end

	scrollFrame.CanvasSize = UDim2.new(0, 0, 0, yOffset + 10)

	return panel
end

--------------------------------------------------
-- Settings Panel
--------------------------------------------------

local function buildSettingsPanel(parent)
	local panel = createInstance("Frame", {
		Name = "SettingsPanel",
		Size = UDim2.new(1, 0, 1, -50),
		Position = UDim2.new(0, 0, 0, 50),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = parent,
	})

	createInstance("TextLabel", {
		Name = "Title",
		Text = "Settings",
		Size = UDim2.new(1, 0, 0, 40),
		Position = UDim2.new(0, 0, 0, 10),
		BackgroundTransparency = 1,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		Font = Enum.Font.GothamBold,
		TextSize = 24,
		Parent = panel,
	})

	createInstance("TextLabel", {
		Text = "Paint Color:",
		Size = UDim2.new(0, 120, 0, 30),
		Position = UDim2.new(0, 20, 0, 70),
		BackgroundTransparency = 1,
		TextColor3 = Color3.fromRGB(200, 200, 220),
		Font = Enum.Font.GothamBold,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = panel,
	})

	local colorFrame = createInstance("Frame", {
		Name = "ColorPicker",
		Size = UDim2.new(1, -40, 0, 40),
		Position = UDim2.new(0, 20, 0, 100),
		BackgroundTransparency = 1,
		Parent = panel,
	})

	createInstance("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 8),
		Parent = colorFrame,
	})

	local selectedColorButton = nil

	for i, colorData in ipairs(GameConfig.PaintColors) do
		local colorBtn = createInstance("TextButton", {
			Name = colorData.Name,
			Text = "",
			Size = UDim2.new(0, 35, 0, 35),
			BackgroundColor3 = colorData.Color,
			Parent = colorFrame,
		})
		createInstance("UICorner", { CornerRadius = UDim.new(0, 6), Parent = colorBtn })

		if i == playerSettings.PaintColorIndex then
			createInstance("UIStroke", {
				Name = "Selected",
				Color = Color3.fromRGB(255, 255, 255),
				Thickness = 3,
				Parent = colorBtn,
			})
			selectedColorButton = colorBtn
		end

		colorBtn.MouseButton1Click:Connect(function()
			if selectedColorButton then
				local oldStroke = selectedColorButton:FindFirstChild("Selected")
				if oldStroke then oldStroke:Destroy() end
			end
			createInstance("UIStroke", {
				Name = "Selected",
				Color = Color3.fromRGB(255, 255, 255),
				Thickness = 3,
				Parent = colorBtn,
			})
			selectedColorButton = colorBtn
			playerSettings.PaintColorIndex = i
		end)
	end

	local musicBtn = makeTextButton(
		"Music: ON",
		UDim2.new(0, 20, 0, 160),
		UDim2.new(0, 160, 0, 40),
		panel,
		nil
	)
	musicBtn.MouseButton1Click:Connect(function()
		playerSettings.MusicEnabled = not playerSettings.MusicEnabled
		musicBtn.Text = "Music: " .. (playerSettings.MusicEnabled and "ON" or "OFF")
	end)

	local sfxBtn = makeTextButton(
		"SFX: ON",
		UDim2.new(0, 200, 0, 160),
		UDim2.new(0, 160, 0, 40),
		panel,
		nil
	)
	sfxBtn.MouseButton1Click:Connect(function()
		playerSettings.SFXEnabled = not playerSettings.SFXEnabled
		sfxBtn.Text = "SFX: " .. (playerSettings.SFXEnabled and "ON" or "OFF")
	end)

	return panel
end

--------------------------------------------------
-- Leaderboards Panel
--------------------------------------------------

local function buildLeaderboardEntry(parent, rank, name, value, yOffset)
	local entryFrame = createInstance("Frame", {
		Size = UDim2.new(1, -20, 0, 28),
		Position = UDim2.new(0, 10, 0, yOffset),
		BackgroundColor3 = (rank % 2 == 0) and Color3.fromRGB(45, 45, 65) or Color3.fromRGB(55, 55, 75),
		BackgroundTransparency = 0.3,
		Parent = parent,
	})
	createInstance("UICorner", { CornerRadius = UDim.new(0, 4), Parent = entryFrame })

	createInstance("TextLabel", {
		Text = "#" .. rank,
		Size = UDim2.new(0, 40, 1, 0),
		Position = UDim2.new(0, 5, 0, 0),
		BackgroundTransparency = 1,
		TextColor3 = (rank <= 3) and Color3.fromRGB(255, 220, 100) or Color3.fromRGB(180, 180, 200),
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = entryFrame,
	})

	createInstance("TextLabel", {
		Text = name,
		Size = UDim2.new(0.6, -60, 1, 0),
		Position = UDim2.new(0, 50, 0, 0),
		BackgroundTransparency = 1,
		TextColor3 = Color3.fromRGB(220, 220, 240),
		Font = Enum.Font.Gotham,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = entryFrame,
	})

	createInstance("TextLabel", {
		Text = tostring(value),
		Size = UDim2.new(0.3, 0, 1, 0),
		Position = UDim2.new(0.7, 0, 0, 0),
		BackgroundTransparency = 1,
		TextColor3 = Color3.fromRGB(100, 220, 255),
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = entryFrame,
	})
end

local function buildLeaderboardsPanel(parent)
	local panel = createInstance("Frame", {
		Name = "LeaderboardsPanel",
		Size = UDim2.new(1, 0, 1, -50),
		Position = UDim2.new(0, 0, 0, 50),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = parent,
	})

	local overallBtn = makeTextButton("Most Painted (Overall)", UDim2.new(0, 10, 0, 5), UDim2.new(0.5, -15, 0, 32), panel, nil)
	local sessionBtn = makeTextButton("Best Single Session", UDim2.new(0.5, 5, 0, 5), UDim2.new(0.5, -15, 0, 32), panel, nil)

	local overallScroll = createInstance("ScrollingFrame", {
		Name = "OverallScroll",
		Size = UDim2.new(1, 0, 1, -50),
		Position = UDim2.new(0, 0, 0, 45),
		BackgroundTransparency = 1,
		ScrollBarThickness = 6,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		Parent = panel,
	})

	local sessionScroll = createInstance("ScrollingFrame", {
		Name = "SessionScroll",
		Size = UDim2.new(1, 0, 1, -50),
		Position = UDim2.new(0, 0, 0, 45),
		BackgroundTransparency = 1,
		ScrollBarThickness = 6,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		Visible = false,
		Parent = panel,
	})

	local personalLabel = createInstance("TextLabel", {
		Name = "PersonalStats",
		Text = "",
		Size = UDim2.new(1, -20, 0, 24),
		Position = UDim2.new(0, 10, 1, -30),
		BackgroundTransparency = 1,
		TextColor3 = Color3.fromRGB(180, 220, 255),
		Font = Enum.Font.Gotham,
		TextSize = 13,
		Parent = panel,
	})

	local function showOverall()
		overallScroll.Visible = true
		sessionScroll.Visible = false
		overallBtn.BackgroundColor3 = Color3.fromRGB(80, 120, 200)
		sessionBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
	end
	local function showSession()
		overallScroll.Visible = false
		sessionScroll.Visible = true
		sessionBtn.BackgroundColor3 = Color3.fromRGB(80, 120, 200)
		overallBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
	end

	overallBtn.MouseButton1Click:Connect(showOverall)
	sessionBtn.MouseButton1Click:Connect(showSession)
	showOverall()

	RemoteSetup.GetRemote(GameConfig.Remotes.LeaderboardUpdate).OnClientEvent:Connect(function(data)
		for _, child in ipairs(overallScroll:GetChildren()) do
			if child:IsA("Frame") then child:Destroy() end
		end
		for _, child in ipairs(sessionScroll:GetChildren()) do
			if child:IsA("Frame") then child:Destroy() end
		end

		if data.Overall then
			for _, entry in ipairs(data.Overall) do
				buildLeaderboardEntry(overallScroll, entry.Rank, entry.Name, entry.Value, (entry.Rank - 1) * 32)
			end
			overallScroll.CanvasSize = UDim2.new(0, 0, 0, #data.Overall * 32 + 10)
		end

		if data.BestSession then
			for _, entry in ipairs(data.BestSession) do
				buildLeaderboardEntry(sessionScroll, entry.Rank, entry.Name, entry.Value, (entry.Rank - 1) * 32)
			end
			sessionScroll.CanvasSize = UDim2.new(0, 0, 0, #data.BestSession * 32 + 10)
		end

		if data.PlayerStats then
			personalLabel.Text = string.format(
				"Your stats — Overall: %d walls | Best session: %d walls",
				data.PlayerStats.overall or 0,
				data.PlayerStats.bestSession or 0
			)
		end
	end)

	return panel
end

--------------------------------------------------
-- Main Build
--------------------------------------------------

function WaitingRoomUI.Init()
	screenGui = createInstance("ScreenGui", {
		Name = "WaitingRoomGui",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = playerGui,
	})

	mainFrame = createInstance("Frame", {
		Name = "MainFrame",
		Size = UDim2.new(0, 500, 0, 420),
		Position = UDim2.new(0.5, -250, 0.5, -210),
		BackgroundColor3 = Color3.fromRGB(30, 30, 50),
		BackgroundTransparency = 0.05,
		Parent = screenGui,
	})
	createInstance("UICorner", { CornerRadius = UDim.new(0, 12), Parent = mainFrame })
	createInstance("UIStroke", {
		Color = Color3.fromRGB(80, 80, 120),
		Thickness = 2,
		Parent = mainFrame,
	})

	-- Tab bar
	local tabNames = { "Lobby", "Upgrades", "Settings", "Leaderboards" }
	local tabWidth = 1 / #tabNames

	for i, name in ipairs(tabNames) do
		local btn = createInstance("TextButton", {
			Name = name .. "Tab",
			Text = name,
			Size = UDim2.new(tabWidth, -4, 0, 40),
			Position = UDim2.new(tabWidth * (i - 1), 2, 0, 5),
			BackgroundColor3 = (i == 1) and Color3.fromRGB(80, 120, 200) or Color3.fromRGB(60, 60, 80),
			TextColor3 = Color3.fromRGB(255, 255, 255),
			Font = Enum.Font.GothamBold,
			TextSize = 14,
			Parent = mainFrame,
		})
		createInstance("UICorner", { CornerRadius = UDim.new(0, 6), Parent = btn })
		btn.MouseButton1Click:Connect(function()
			switchTab(name)
		end)
		tabButtons[name] = btn
	end

	-- Build panels
	tabPanels["Lobby"] = buildLobbyPanel(mainFrame)
	tabPanels["Upgrades"] = buildUpgradesPanel(mainFrame)
	tabPanels["Settings"] = buildSettingsPanel(mainFrame)
	tabPanels["Leaderboards"] = buildLeaderboardsPanel(mainFrame)

	-- Listen for countdown ticks
	RemoteSetup.GetRemote(GameConfig.Remotes.CountdownTick).OnClientEvent:Connect(function(seconds)
		if countdownLabel then
			if seconds <= 0 then
				countdownLabel.Text = ""
			else
				countdownLabel.Text = "Starting in " .. seconds .. "..."
			end
		end
	end)

	-- Listen for game state changes
	RemoteSetup.GetRemote(GameConfig.Remotes.GameStateChanged).OnClientEvent:Connect(function(newState)
		if newState == GameConfig.GameState.WaitingRoom then
			screenGui.Enabled = true
			refreshUpgradeButtons()
		else
			screenGui.Enabled = false
		end
	end)

	print("[WaitingRoomUI] Initialized")
end

function WaitingRoomUI.GetSelectedColor()
	local colorData = GameConfig.PaintColors[playerSettings.PaintColorIndex]
	return colorData and colorData.Color or GameConfig.DefaultSettings.PaintColor
end

function WaitingRoomUI.GetSettings()
	return playerSettings
end

function WaitingRoomUI.UpdateStats(stats)
	currentStats = stats
	refreshUpgradeButtons()
end

return WaitingRoomUI
