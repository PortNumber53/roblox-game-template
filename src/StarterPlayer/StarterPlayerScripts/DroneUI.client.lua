-- DroneUI: purchase and manage paint refill drones

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))
local RemoteSetup = require(ReplicatedStorage:WaitForChild("RemoteSetup"))
local DroneUpgradeDefinitions = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("DroneUpgradeDefinitions"))
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local currentStats = nil
local droneSlots = {}

local function createInstance(className, props)
	local inst = Instance.new(className)
	for k, v in pairs(props) do
		if k ~= "Parent" then inst[k] = v end
	end
	if props.Parent then inst.Parent = props.Parent end
	return inst
end

local function makeCorner(parent, radius)
	createInstance("UICorner", { CornerRadius = UDim.new(0, radius or 8), Parent = parent })
end

--------------------------------------------------
-- Toggle button
--------------------------------------------------

local toggleGui = createInstance("ScreenGui", {
	Name = "DroneToggle",
	ResetOnSpawn = false,
	Enabled = true,
	Parent = playerGui,
})

local toggleBtn = createInstance("TextButton", {
	Text = "Drones",
	Size = UDim2.new(0, 110, 0, 36),
	Position = UDim2.new(0, 15, 0.5, 66),
	BackgroundColor3 = Color3.fromRGB(80, 140, 200),
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
	Name = "DronePanel",
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
createInstance("UIStroke", { Color = Color3.fromRGB(80, 140, 200), Thickness = 2, Parent = panel })

createInstance("TextLabel", {
	Text = "Paint Drones",
	Size = UDim2.new(0.6, 0, 0, 30),
	Position = UDim2.new(0, 16, 0, 10),
	BackgroundTransparency = 1,
	TextColor3 = Color3.fromRGB(255, 255, 255),
	Font = Enum.Font.GothamBold,
	TextSize = 18,
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
	TextSize = 14,
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
	Size = UDim2.new(1, -20, 1, -50),
	Position = UDim2.new(0, 10, 0, 45),
	BackgroundTransparency = 1,
	ScrollBarThickness = 5,
	CanvasSize = UDim2.new(0, 0, 0, 0),
	Parent = panel,
})

--------------------------------------------------
-- Build drone slots
--------------------------------------------------

local SLOT_HEIGHT = 115

for slotIndex = 1, Config.DroneMaxCount do
	local yOffset = (slotIndex - 1) * (SLOT_HEIGHT + 8)

	local slotFrame = createInstance("Frame", {
		Name = "Slot" .. slotIndex,
		Size = UDim2.new(1, -8, 0, SLOT_HEIGHT),
		Position = UDim2.new(0, 4, 0, yOffset),
		BackgroundColor3 = Color3.fromRGB(30, 30, 48),
		BackgroundTransparency = 0.3,
		Parent = scrollFrame,
	})
	makeCorner(slotFrame, 8)

	local titleLabel = createInstance("TextLabel", {
		Name = "Title",
		Text = "Drone " .. slotIndex,
		Size = UDim2.new(0.5, 0, 0, 22),
		Position = UDim2.new(0, 10, 0, 4),
		BackgroundTransparency = 1,
		TextColor3 = Color3.fromRGB(200, 220, 255),
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = slotFrame,
	})

	local statusLabel = createInstance("TextLabel", {
		Name = "Status",
		Text = "Not Owned",
		Size = UDim2.new(0.5, -10, 0, 22),
		Position = UDim2.new(0.5, 0, 0, 4),
		BackgroundTransparency = 1,
		TextColor3 = Color3.fromRGB(150, 150, 170),
		Font = Enum.Font.Gotham,
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = slotFrame,
	})

	-- Buy button (shown when not owned/expired)
	local buyBtn = createInstance("TextButton", {
		Name = "BuyBtn",
		Text = "Buy Drone (R$99)",
		Size = UDim2.new(1, -20, 0, 32),
		Position = UDim2.new(0, 10, 0, 30),
		BackgroundColor3 = Color3.fromRGB(80, 140, 200),
		TextColor3 = Color3.fromRGB(255, 255, 255),
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		Parent = slotFrame,
	})
	makeCorner(buyBtn, 6)

	buyBtn.MouseButton1Click:Connect(function()
		RemoteSetup.GetRemote(GameConfig.Remotes.RequestBuyDrone):FireServer()
	end)

	-- Upgrade buttons (shown when active)
	local upgradeFrame = createInstance("Frame", {
		Name = "Upgrades",
		Size = UDim2.new(1, -20, 0, 75),
		Position = UDim2.new(0, 10, 0, 30),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = slotFrame,
	})

	local speedBtn = createInstance("TextButton", {
		Name = "SpeedBtn",
		Text = "Speed Lv 0 - Buy (80)",
		Size = UDim2.new(1, 0, 0, 30),
		Position = UDim2.new(0, 0, 0, 0),
		BackgroundColor3 = Color3.fromRGB(50, 120, 70),
		TextColor3 = Color3.fromRGB(255, 255, 255),
		Font = Enum.Font.GothamBold,
		TextSize = 12,
		Parent = upgradeFrame,
	})
	makeCorner(speedBtn, 6)

	speedBtn.MouseButton1Click:Connect(function()
		local rf = RemoteSetup.GetRemoteFunction(GameConfig.RemoteFunctions.BuyDroneUpgrade)
		rf:InvokeServer(slotIndex, "DroneSpeed")
	end)

	local capacityBtn = createInstance("TextButton", {
		Name = "CapacityBtn",
		Text = "Capacity Lv 0 - Buy (80)",
		Size = UDim2.new(1, 0, 0, 30),
		Position = UDim2.new(0, 0, 0, 35),
		BackgroundColor3 = Color3.fromRGB(50, 120, 70),
		TextColor3 = Color3.fromRGB(255, 255, 255),
		Font = Enum.Font.GothamBold,
		TextSize = 12,
		Parent = upgradeFrame,
	})
	makeCorner(capacityBtn, 6)

	capacityBtn.MouseButton1Click:Connect(function()
		local rf = RemoteSetup.GetRemoteFunction(GameConfig.RemoteFunctions.BuyDroneUpgrade)
		rf:InvokeServer(slotIndex, "DroneCapacity")
	end)

	droneSlots[slotIndex] = {
		frame = slotFrame,
		titleLabel = titleLabel,
		statusLabel = statusLabel,
		buyBtn = buyBtn,
		upgradeFrame = upgradeFrame,
		speedBtn = speedBtn,
		capacityBtn = capacityBtn,
	}
end

scrollFrame.CanvasSize = UDim2.new(0, 0, 0, Config.DroneMaxCount * (SLOT_HEIGHT + 8))

--------------------------------------------------
-- Refresh
--------------------------------------------------

local function formatTime(seconds)
	local days = math.floor(seconds / 86400)
	local hours = math.floor((seconds % 86400) / 3600)
	if days > 0 then
		return string.format("%dd %dh", days, hours)
	end
	local mins = math.floor((seconds % 3600) / 60)
	return string.format("%dh %dm", hours, mins)
end

local function refresh()
	if not currentStats then return end

	local drones = currentStats.drones or {}

	for slotIndex = 1, Config.DroneMaxCount do
		local slot = droneSlots[slotIndex]
		local droneInfo = drones[slotIndex]

		if droneInfo and droneInfo.active then
			slot.statusLabel.Text = formatTime(droneInfo.remainingSeconds) .. " left"
			slot.statusLabel.TextColor3 = Color3.fromRGB(100, 220, 130)
			slot.buyBtn.Visible = false
			slot.upgradeFrame.Visible = true

			local speedLevel = droneInfo.speed or 0
			local capLevel = droneInfo.capacity or 0
			local speedDef = DroneUpgradeDefinitions.DroneSpeed
			local capDef = DroneUpgradeDefinitions.DroneCapacity
			local speedCost = math.floor(speedDef.baseCost * (speedDef.costMultiplier ^ speedLevel))
			local capCost = math.floor(capDef.baseCost * (capDef.costMultiplier ^ capLevel))
			local coins = currentStats.coins or 0

			slot.speedBtn.Text = string.format("Speed Lv %d - Buy (%d)", speedLevel, speedCost)
			slot.speedBtn.BackgroundColor3 = coins >= speedCost and Color3.fromRGB(50, 120, 70) or Color3.fromRGB(100, 50, 50)

			slot.capacityBtn.Text = string.format("Capacity Lv %d - Buy (%d)", capLevel, capCost)
			slot.capacityBtn.BackgroundColor3 = coins >= capCost and Color3.fromRGB(50, 120, 70) or Color3.fromRGB(100, 50, 50)
		elseif droneInfo and not droneInfo.active then
			slot.statusLabel.Text = "Expired"
			slot.statusLabel.TextColor3 = Color3.fromRGB(200, 100, 100)
			slot.buyBtn.Visible = true
			slot.buyBtn.Text = "Renew (R$99)"
			slot.upgradeFrame.Visible = false
		else
			slot.statusLabel.Text = "Not Owned"
			slot.statusLabel.TextColor3 = Color3.fromRGB(150, 150, 170)
			slot.buyBtn.Visible = true
			slot.buyBtn.Text = "Buy Drone (R$99)"
			slot.upgradeFrame.Visible = false
		end
	end

	coinsLabel.Text = "Coins: " .. (currentStats.coins or 0)
end

--------------------------------------------------
-- Toggle
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

RemoteSetup.GetRemote(GameConfig.Remotes.GameStateChanged).OnClientEvent:Connect(function()
	setVisible(false)
end)

print("[DroneUI] Initialized")
