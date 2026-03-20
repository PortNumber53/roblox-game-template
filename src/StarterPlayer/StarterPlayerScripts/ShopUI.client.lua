local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local UpgradeDefinitions = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UpgradeDefinitions"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local rfBuyUpgrade = remotes:WaitForChild("BuyUpgrade")
local evStatsSync = remotes:WaitForChild("StatsSync")

local UPGRADE_ORDER = { "MaxSize", "SizeMultiplier", "BrushSize", "BrushSpeed", "BucketCapacity", "MoveSpeed" }
local UPGRADE_ICONS = {
	MaxSize = "📏",
	SizeMultiplier = "⬆️",
	BrushSize = "🖌️",
	BrushSpeed = "⚡",
	BucketCapacity = "🪣",
	MoveSpeed = "🏃",
}

local localStats = { coins = 0, upgrades = {} }

local function makeCorner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 8)
	c.Parent = parent
end

local function makeStroke(parent, color, thickness)
	local s = Instance.new("UIStroke")
	s.Color = color or Color3.fromRGB(80, 80, 80)
	s.Thickness = thickness or 1.5
	s.Parent = parent
end

-- Build ScreenGui
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ShopUI"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

-- Backdrop
local backdrop = Instance.new("Frame")
backdrop.Name = "Backdrop"
backdrop.Size = UDim2.new(1, 0, 1, 0)
backdrop.BackgroundColor3 = Color3.new(0, 0, 0)
backdrop.BackgroundTransparency = 0.55
backdrop.BorderSizePixel = 0
backdrop.ZIndex = 10
backdrop.Parent = screenGui

-- Main panel
local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.Size = UDim2.new(0, 420, 0, 480)
panel.Position = UDim2.new(0.5, -210, 0.5, -240)
panel.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
panel.BorderSizePixel = 0
panel.ZIndex = 11
panel.Parent = screenGui
makeCorner(panel, 14)
makeStroke(panel, Color3.fromRGB(255, 200, 40), 2)

-- Title
local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -50, 0, 44)
title.Position = UDim2.new(0, 16, 0, 8)
title.BackgroundTransparency = 1
title.TextColor3 = Color3.fromRGB(255, 215, 50)
title.TextSize = 22
title.Font = Enum.Font.GothamBold
title.Text = "Upgrade Shop"
title.TextXAlignment = Enum.TextXAlignment.Left
title.ZIndex = 12
title.Parent = panel

-- Coins display in title bar
local coinsDisplay = Instance.new("TextLabel")
coinsDisplay.Name = "CoinsDisplay"
coinsDisplay.Size = UDim2.new(0, 130, 0, 28)
coinsDisplay.Position = UDim2.new(1, -144, 0, 14)
coinsDisplay.BackgroundTransparency = 1
coinsDisplay.TextColor3 = Color3.fromRGB(255, 220, 60)
coinsDisplay.TextSize = 16
coinsDisplay.Font = Enum.Font.GothamBold
coinsDisplay.Text = "Coins: 0"
coinsDisplay.TextXAlignment = Enum.TextXAlignment.Right
coinsDisplay.ZIndex = 12
coinsDisplay.Parent = panel

-- Close button
local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 36, 0, 36)
closeBtn.Position = UDim2.new(1, -46, 0, 8)
closeBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
closeBtn.TextColor3 = Color3.new(1, 1, 1)
closeBtn.TextSize = 18
closeBtn.Font = Enum.Font.GothamBold
closeBtn.Text = "✕"
closeBtn.BorderSizePixel = 0
closeBtn.ZIndex = 12
closeBtn.Parent = panel
makeCorner(closeBtn, 8)

-- Divider
local divider = Instance.new("Frame")
divider.Size = UDim2.new(1, -32, 0, 1)
divider.Position = UDim2.new(0, 16, 0, 54)
divider.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
divider.BorderSizePixel = 0
divider.ZIndex = 12
divider.Parent = panel

-- Scroll frame for upgrade cards
local scroll = Instance.new("ScrollingFrame")
scroll.Name = "UpgradeScroll"
scroll.Size = UDim2.new(1, -16, 1, -70)
scroll.Position = UDim2.new(0, 8, 0, 62)
scroll.BackgroundTransparency = 1
scroll.BorderSizePixel = 0
scroll.ScrollBarThickness = 4
scroll.ScrollBarImageColor3 = Color3.fromRGB(255, 200, 40)
scroll.ZIndex = 12
scroll.Parent = panel

local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 8)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Parent = scroll

local listPad = Instance.new("UIPadding")
listPad.PaddingTop = UDim.new(0, 6)
listPad.PaddingLeft = UDim.new(0, 4)
listPad.PaddingRight = UDim.new(0, 4)
listPad.Parent = scroll

-- Upgrade card rows
local cardRefs = {}

local function getUpgradeCost(id, level)
	local def = UpgradeDefinitions[id]
	if not def then return 0 end
	if level >= def.maxLevel then return math.huge end
	return def.baseCost + def.costStep * level
end

local function refreshCards()
	for _, id in ipairs(UPGRADE_ORDER) do
		local ref = cardRefs[id]
		if not ref then continue end
		local def = UpgradeDefinitions[id]
		local level = (localStats.upgrades and localStats.upgrades[id]) or 0
		local maxLevel = def.maxLevel
		local cost = getUpgradeCost(id, level)
		local coins = localStats.coins or 0
		local isMax = level >= maxLevel
		local canAfford = coins >= cost and not isMax

		ref.levelLabel.Text = isMax and "MAX" or string.format("Lv %d / %d", level, maxLevel)
		ref.costLabel.Text = isMax and "—" or string.format("%d coins", cost)

		ref.buyBtn.BackgroundColor3 = isMax
			and Color3.fromRGB(60, 60, 70)
			or (canAfford and Color3.fromRGB(50, 180, 80) or Color3.fromRGB(140, 50, 50))
		ref.buyBtn.Text = isMax and "MAX" or "Buy"
		ref.buyBtn.Active = canAfford

		-- level bar
		local fraction = maxLevel > 0 and (level / maxLevel) or 0
		ref.levelBar.Size = UDim2.new(fraction, 0, 1, 0)

		coinsDisplay.Text = string.format("Coins: %d", coins)
	end
end

for i, id in ipairs(UPGRADE_ORDER) do
	local def = UpgradeDefinitions[id]

	local card = Instance.new("Frame")
	card.Name = "Card_" .. id
	card.Size = UDim2.new(1, -8, 0, 72)
	card.BackgroundColor3 = Color3.fromRGB(28, 28, 36)
	card.BorderSizePixel = 0
	card.LayoutOrder = i
	card.ZIndex = 13
	card.Parent = scroll
	makeCorner(card, 10)
	makeStroke(card, Color3.fromRGB(50, 50, 65), 1)

	-- Icon
	local icon = Instance.new("TextLabel")
	icon.Size = UDim2.new(0, 42, 0, 42)
	icon.Position = UDim2.new(0, 10, 0.5, -21)
	icon.BackgroundTransparency = 1
	icon.TextColor3 = Color3.new(1, 1, 1)
	icon.TextSize = 26
	icon.Font = Enum.Font.Gotham
	icon.Text = UPGRADE_ICONS[id] or "+"
	icon.ZIndex = 14
	icon.Parent = card

	-- Name
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(0, 170, 0, 22)
	nameLabel.Position = UDim2.new(0, 58, 0, 10)
	nameLabel.BackgroundTransparency = 1
	nameLabel.TextColor3 = Color3.fromRGB(230, 230, 240)
	nameLabel.TextSize = 14
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.Text = def.displayName
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.ZIndex = 14
	nameLabel.Parent = card

	-- Level label
	local levelLabel = Instance.new("TextLabel")
	levelLabel.Name = "LevelLabel"
	levelLabel.Size = UDim2.new(0, 120, 0, 18)
	levelLabel.Position = UDim2.new(0, 58, 0, 32)
	levelLabel.BackgroundTransparency = 1
	levelLabel.TextColor3 = Color3.fromRGB(160, 160, 180)
	levelLabel.TextSize = 12
	levelLabel.Font = Enum.Font.Gotham
	levelLabel.Text = "Lv 0 / " .. def.maxLevel
	levelLabel.TextXAlignment = Enum.TextXAlignment.Left
	levelLabel.ZIndex = 14
	levelLabel.Parent = card

	-- Level bar BG
	local barBG = Instance.new("Frame")
	barBG.Size = UDim2.new(0, 120, 0, 5)
	barBG.Position = UDim2.new(0, 58, 0, 54)
	barBG.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
	barBG.BorderSizePixel = 0
	barBG.ZIndex = 14
	barBG.Parent = card
	makeCorner(barBG, 3)

	local levelBar = Instance.new("Frame")
	levelBar.Name = "LevelBar"
	levelBar.Size = UDim2.new(0, 0, 1, 0)
	levelBar.BackgroundColor3 = Color3.fromRGB(255, 200, 40)
	levelBar.BorderSizePixel = 0
	levelBar.ZIndex = 15
	levelBar.Parent = barBG
	makeCorner(levelBar, 3)

	-- Cost label
	local costLabel = Instance.new("TextLabel")
	costLabel.Name = "CostLabel"
	costLabel.Size = UDim2.new(0, 90, 0, 22)
	costLabel.Position = UDim2.new(1, -198, 0.5, -11)
	costLabel.BackgroundTransparency = 1
	costLabel.TextColor3 = Color3.fromRGB(255, 220, 60)
	costLabel.TextSize = 13
	costLabel.Font = Enum.Font.GothamBold
	costLabel.Text = string.format("%d coins", def.baseCost)
	costLabel.TextXAlignment = Enum.TextXAlignment.Right
	costLabel.ZIndex = 14
	costLabel.Parent = card

	-- Buy button
	local buyBtn = Instance.new("TextButton")
	buyBtn.Name = "BuyBtn"
	buyBtn.Size = UDim2.new(0, 72, 0, 34)
	buyBtn.Position = UDim2.new(1, -84, 0.5, -17)
	buyBtn.BackgroundColor3 = Color3.fromRGB(50, 180, 80)
	buyBtn.TextColor3 = Color3.new(1, 1, 1)
	buyBtn.TextSize = 14
	buyBtn.Font = Enum.Font.GothamBold
	buyBtn.Text = "Buy"
	buyBtn.BorderSizePixel = 0
	buyBtn.ZIndex = 14
	buyBtn.Parent = card
	makeCorner(buyBtn, 8)

	local upgradeId = id
	buyBtn.MouseButton1Click:Connect(function()
		local level = (localStats.upgrades and localStats.upgrades[upgradeId]) or 0
		local def2 = UpgradeDefinitions[upgradeId]
		if level >= def2.maxLevel then return end
		local cost = getUpgradeCost(upgradeId, level)
		if (localStats.coins or 0) < cost then return end

		local success, msg = rfBuyUpgrade:InvokeServer(upgradeId)
		if success then
			TweenService:Create(buyBtn, TweenInfo.new(0.1), {
				BackgroundColor3 = Color3.fromRGB(255, 255, 100)
			}):Play()
			task.delay(0.15, function()
				refreshCards()
			end)
		end
	end)

	cardRefs[id] = {
		card = card,
		levelLabel = levelLabel,
		costLabel = costLabel,
		buyBtn = buyBtn,
		levelBar = levelBar,
	}
end

-- Auto-size scroll canvas
listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
	scroll.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y + 16)
end)

-- Show/hide logic
local visible = false

local function setVisible(v)
	visible = v
	backdrop.Visible = v
	panel.Visible = v
	if v then refreshCards() end
end

setVisible(false)

closeBtn.MouseButton1Click:Connect(function()
	setVisible(false)
end)

backdrop.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		setVisible(false)
	end
end)

-- Listen for HUD shop toggle
local function waitForToggle()
	local hud = playerGui:WaitForChild("HUD", 10)
	if not hud then return end
	local toggle = hud:WaitForChild("ToggleShop", 10)
	if not toggle then return end
	toggle.Event:Connect(function()
		setVisible(not visible)
	end)
end
task.spawn(waitForToggle)

-- Sync stats
evStatsSync.OnClientEvent:Connect(function(data)
	localStats = data
	if visible then
		refreshCards()
	end
	coinsDisplay.Text = string.format("Coins: %d", localStats.coins or 0)
end)
