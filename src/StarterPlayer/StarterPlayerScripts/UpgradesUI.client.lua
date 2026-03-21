-- UpgradesUI: toggleable upgrade shop panel

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))
local RemoteSetup = require(ReplicatedStorage:WaitForChild("RemoteSetup"))
local UpgradeDefinitions = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UpgradeDefinitions"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local currentStats = nil
local upgradeButtons = {}

--------------------------------------------------
-- Helpers
--------------------------------------------------

local function createInstance(className, props)
	local inst = Instance.new(className)
	for k, v in pairs(props) do
		if k ~= "Parent" then
			inst[k] = v
		end
	end
	if props.Parent then
		inst.Parent = props.Parent
	end
	return inst
end

local function makeCorner(parent, radius)
	createInstance("UICorner", { CornerRadius = UDim.new(0, radius or 8), Parent = parent })
end

--------------------------------------------------
-- Toggle button (always visible in lobby)
--------------------------------------------------

local toggleGui = createInstance("ScreenGui", {
	Name = "UpgradesToggle",
	ResetOnSpawn = false,
	Enabled = true,
	Parent = playerGui,
})

local toggleBtn = createInstance("TextButton", {
	Name = "UpgradesBtn",
	Text = "Upgrades",
	Size = UDim2.new(0, 110, 0, 36),
	Position = UDim2.new(0, 15, 0.5, -22),
	BackgroundColor3 = Color3.fromRGB(50, 140, 80),
	TextColor3 = Color3.fromRGB(255, 255, 255),
	Font = Enum.Font.GothamBold,
	TextSize = 15,
	Parent = toggleGui,
})
makeCorner(toggleBtn, 8)

--------------------------------------------------
-- Panel
--------------------------------------------------

local screenGui = createInstance("ScreenGui", {
	Name = "UpgradesPanel",
	ResetOnSpawn = false,
	Enabled = false,
	Parent = playerGui,
})

local panel = createInstance("Frame", {
	Name = "Panel",
	Size = UDim2.new(0, 320, 0, 400),
	Position = UDim2.new(1, -335, 0.5, -200),
	BackgroundColor3 = Color3.fromRGB(20, 20, 35),
	BackgroundTransparency = 0.2,
	BorderSizePixel = 0,
	Parent = screenGui,
})
makeCorner(panel, 12)
createInstance("UIStroke", { Color = Color3.fromRGB(50, 140, 80), Thickness = 2, Parent = panel })

createInstance("TextLabel", {
	Text = "Upgrades",
	Size = UDim2.new(0.6, 0, 0, 30),
	Position = UDim2.new(0, 16, 0, 10),
	BackgroundTransparency = 1,
	TextColor3 = Color3.fromRGB(255, 255, 255),
	Font = Enum.Font.GothamBold,
	TextSize = 20,
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = panel,
})

local coinsLabel = createInstance("TextLabel", {
	Name = "Coins",
	Text = "Coins: 0",
	Size = UDim2.new(0.4, -50, 0, 30),
	Position = UDim2.new(0.6, 0, 0, 10),
	BackgroundTransparency = 1,
	TextColor3 = Color3.fromRGB(255, 220, 60),
	Font = Enum.Font.GothamBold,
	TextSize = 16,
	TextXAlignment = Enum.TextXAlignment.Right,
	Parent = panel,
})

local closeBtn = createInstance("TextButton", {
	Text = "X",
	Size = UDim2.new(0, 30, 0, 30),
	Position = UDim2.new(1, -40, 0, 8),
	BackgroundColor3 = Color3.fromRGB(180, 50, 50),
	TextColor3 = Color3.fromRGB(255, 255, 255),
	Font = Enum.Font.GothamBold,
	TextSize = 16,
	Parent = panel,
})
makeCorner(closeBtn, 6)

local scrollFrame = createInstance("ScrollingFrame", {
	Size = UDim2.new(1, -20, 1, -55),
	Position = UDim2.new(0, 10, 0, 48),
	BackgroundTransparency = 1,
	ScrollBarThickness = 5,
	CanvasSize = UDim2.new(0, 0, 0, 0),
	Parent = panel,
})

--------------------------------------------------
-- Build upgrade rows
--------------------------------------------------

local sortedIds = {}
for id in pairs(UpgradeDefinitions) do
	table.insert(sortedIds, id)
end
table.sort(sortedIds)

local ROW_HEIGHT = 52
local yOffset = 0

for _, upgradeId in ipairs(sortedIds) do
	local def = UpgradeDefinitions[upgradeId]

	local row = createInstance("Frame", {
		Size = UDim2.new(1, -8, 0, ROW_HEIGHT - 4),
		Position = UDim2.new(0, 4, 0, yOffset),
		BackgroundColor3 = Color3.fromRGB(30, 30, 48),
		BackgroundTransparency = 0.3,
		Parent = scrollFrame,
	})
	makeCorner(row, 6)

	createInstance("TextLabel", {
		Text = def.displayName,
		Size = UDim2.new(0.5, -5, 0, 20),
		Position = UDim2.new(0, 10, 0, 4),
		BackgroundTransparency = 1,
		TextColor3 = Color3.fromRGB(220, 220, 240),
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = row,
	})

	local levelLabel = createInstance("TextLabel", {
		Name = "Level",
		Text = "Lv 0",
		Size = UDim2.new(0.5, -5, 0, 16),
		Position = UDim2.new(0, 10, 0, 26),
		BackgroundTransparency = 1,
		TextColor3 = Color3.fromRGB(150, 150, 170),
		Font = Enum.Font.Gotham,
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = row,
	})

	local buyBtn = createInstance("TextButton", {
		Name = "BuyBtn",
		Text = string.format("Buy (%d)", def.baseCost),
		Size = UDim2.new(0.4, -10, 0, 30),
		Position = UDim2.new(0.6, 0, 0.5, -15),
		BackgroundColor3 = Color3.fromRGB(50, 140, 80),
		TextColor3 = Color3.fromRGB(255, 255, 255),
		Font = Enum.Font.GothamBold,
		TextSize = 12,
		Parent = row,
	})
	makeCorner(buyBtn, 6)

	buyBtn.MouseButton1Click:Connect(function()
		local rf = RemoteSetup.GetRemoteFunction(GameConfig.RemoteFunctions.BuyUpgrade)
		rf:InvokeServer(upgradeId)
	end)

	upgradeButtons[upgradeId] = {
		button = buyBtn,
		levelLabel = levelLabel,
	}

	yOffset = yOffset + ROW_HEIGHT
end

scrollFrame.CanvasSize = UDim2.new(0, 0, 0, yOffset + 8)

--------------------------------------------------
-- Refresh
--------------------------------------------------

local function refresh()
	if not currentStats then return end

	for upgradeId, entry in pairs(upgradeButtons) do
		local def = UpgradeDefinitions[upgradeId]
		if not def then continue end

		local level = currentStats.upgrades and currentStats.upgrades[upgradeId] or 0
		local cost = math.floor(def.baseCost * (def.costMultiplier ^ level))
		local canAfford = currentStats.coins and currentStats.coins >= cost

		entry.levelLabel.Text = string.format("Lv %d", level)
		entry.button.Text = string.format("Buy (%d)", cost)
		entry.button.BackgroundColor3 = canAfford and Color3.fromRGB(50, 140, 80) or Color3.fromRGB(100, 50, 50)
	end

	coinsLabel.Text = "Coins: " .. (currentStats.coins or 0)
end

--------------------------------------------------
-- Toggle logic
--------------------------------------------------

local function setVisible(v)
	screenGui.Enabled = v
	if v then refresh() end
end

toggleBtn.MouseButton1Click:Connect(function()
	setVisible(not screenGui.Enabled)
end)

closeBtn.MouseButton1Click:Connect(function()
	setVisible(false)
end)


--------------------------------------------------
-- Events
--------------------------------------------------

RemoteSetup.GetRemote(GameConfig.Remotes.StatsSync).OnClientEvent:Connect(function(stats)
	currentStats = stats
	if screenGui.Enabled then refresh() end
end)

toggleGui.Enabled = true

RemoteSetup.GetRemote(GameConfig.Remotes.GameStateChanged).OnClientEvent:Connect(function(newState)
	setVisible(false)
end)

print("[UpgradesUI] Initialized")
