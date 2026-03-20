local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local evStatsSync = remotes:WaitForChild("StatsSync")
local evMilestone = remotes:WaitForChild("MilestoneReached")

-- Build the ScreenGui
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "HUD"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

-- BindableEvents so PaintController can poke HUD
local statsUpdated = Instance.new("BindableEvent")
statsUpdated.Name = "StatsUpdated"
statsUpdated.Parent = screenGui

local milestoneTriggered = Instance.new("BindableEvent")
milestoneTriggered.Name = "MilestoneTriggered"
milestoneTriggered.Parent = screenGui

-- Helpers
local function makeLabel(parent, name, text, size, pos, color, fontSize, bold)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Text = text
	label.Size = size
	label.Position = pos
	label.BackgroundTransparency = 1
	label.TextColor3 = color or Color3.new(1, 1, 1)
	label.TextSize = fontSize or 16
	label.Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham
	label.TextStrokeTransparency = 0.6
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = parent
	return label
end

local function makeFrame(parent, name, size, pos, color, transparency)
	local f = Instance.new("Frame")
	f.Name = name
	f.Size = size
	f.Position = pos
	f.BackgroundColor3 = color or Color3.fromRGB(20, 20, 20)
	f.BackgroundTransparency = transparency or 0.35
	f.BorderSizePixel = 0
	f.Parent = parent
	return f
end

local function makeCorner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 8)
	c.Parent = parent
end

-- Bottom bar panel
local panel = makeFrame(
	screenGui, "StatsPanel",
	UDim2.new(0, 340, 0, 130),
	UDim2.new(0, 14, 1, -144),
	Color3.fromRGB(15, 15, 15), 0.3
)
makeCorner(panel, 10)

-- Paint bar background
local paintBarBG = makeFrame(panel, "PaintBarBG", UDim2.new(1, -20, 0, 18), UDim2.new(0, 10, 0, 10), Color3.fromRGB(40, 40, 40), 0)
makeCorner(paintBarBG, 6)

local paintBar = makeFrame(paintBarBG, "PaintBar", UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0), Color3.fromRGB(80, 160, 255), 0)
makeCorner(paintBar, 6)

local paintLabel = makeLabel(panel, "PaintLabel", "Paint: 120 / 120", UDim2.new(1, -20, 0, 18), UDim2.new(0, 10, 0, 10), Color3.fromRGB(210, 235, 255), 13)

-- Size bar background
local sizeBarBG = makeFrame(panel, "SizeBarBG", UDim2.new(1, -20, 0, 18), UDim2.new(0, 10, 0, 38), Color3.fromRGB(40, 40, 40), 0)
makeCorner(sizeBarBG, 6)

local sizeBar = makeFrame(sizeBarBG, "SizeBar", UDim2.new(0, 0, 1, 0), UDim2.new(0, 0, 0, 0), Color3.fromRGB(120, 220, 130), 0)
makeCorner(sizeBar, 6)

local sizeLabel = makeLabel(panel, "SizeLabel", "Size: 1.00 / 3.00", UDim2.new(1, -20, 0, 18), UDim2.new(0, 10, 0, 38), Color3.fromRGB(200, 255, 210), 13)

-- Milestone label
local milestoneLabel = makeLabel(panel, "MilestoneLabel", "Next milestone: 1.5x  (+25 coins)", UDim2.new(1, -20, 0, 18), UDim2.new(0, 10, 0, 66), Color3.fromRGB(255, 230, 140), 13)
milestoneLabel.TextSize = 11
milestoneLabel.TextScaled = true
milestoneLabel.TextWrapped = false

-- Coins label
local coinsLabel = makeLabel(panel, "CoinsLabel", "Coins: 0", UDim2.new(1, -20, 0, 18), UDim2.new(0, 10, 0, 90), Color3.fromRGB(255, 220, 60), 15, true)

-- Milestone popup
local popup = Instance.new("Frame")
popup.Name = "MilestonePopup"
popup.Size = UDim2.new(0, 280, 0, 60)
popup.Position = UDim2.new(0.5, -140, 0, -80)
popup.BackgroundColor3 = Color3.fromRGB(255, 200, 50)
popup.BackgroundTransparency = 0.1
popup.BorderSizePixel = 0
popup.Parent = screenGui
makeCorner(popup, 12)

local popupLabel = Instance.new("TextLabel")
popupLabel.Size = UDim2.new(1, -16, 1, 0)
popupLabel.Position = UDim2.new(0, 8, 0, 0)
popupLabel.BackgroundTransparency = 1
popupLabel.TextColor3 = Color3.fromRGB(30, 20, 0)
popupLabel.TextSize = 18
popupLabel.Font = Enum.Font.GothamBold
popupLabel.TextXAlignment = Enum.TextXAlignment.Center
popupLabel.Parent = popup

popup.Visible = false

local function getNextMilestone(milestoneIndex)
	local next = Config.Milestones[milestoneIndex + 1]
	return next
end

local function updateBars(stats)
	local paintFraction = math.clamp((stats.paint or 0) / math.max(1, stats.maxPaint or 120), 0, 1)
	TweenService:Create(paintBar, TweenInfo.new(0.12), { Size = UDim2.new(paintFraction, 0, 1, 0) }):Play()
	paintLabel.Text = string.format("Paint: %d / %d", math.floor(stats.paint or 0), stats.maxPaint or 120)

	local sizeCap = stats.sizeCap or 3
	local currentSize = stats.size or 1
	local baseScale = Config.BaseCharacterScale or 1
	local sizeFraction = math.clamp((currentSize - baseScale) / math.max(0.01, sizeCap - baseScale), 0, 1)
	TweenService:Create(sizeBar, TweenInfo.new(0.12), { Size = UDim2.new(sizeFraction, 0, 1, 0) }):Play()
	sizeLabel.Text = string.format("Size: %.2f / %.2f", currentSize, sizeCap)

	local next = getNextMilestone(stats.milestoneIndex or 0)
	if next then
		local remaining = math.max(0, next.size - currentSize)
		if currentSize >= sizeCap and next.size > sizeCap then
			milestoneLabel.Text = string.format(
				"Cap reached - buy Max Size (Next %.1fx, %.2f left)",
				next.size,
				remaining
			)
		else
			milestoneLabel.Text = string.format(
				"Next %.1fx (+%d), need %.2f",
				next.size,
				next.reward,
				remaining
			)
		end
	else
		milestoneLabel.Text = "All milestones reached!"
	end

	coinsLabel.Text = string.format("Coins: %d", stats.coins or 0)
end

evStatsSync.OnClientEvent:Connect(function(stats)
	updateBars(stats)
end)

local popupActive = false
evMilestone.OnClientEvent:Connect(function(coinsEarned, newSize)
	if popupActive then return end
	popupActive = true
	popupLabel.Text = string.format("Milestone! Size %.1f  +%d coins!", newSize, coinsEarned)
	popup.Visible = true
	popup.Position = UDim2.new(0.5, -140, 0, -80)
	TweenService:Create(popup, TweenInfo.new(0.3, Enum.EasingStyle.Back), {
		Position = UDim2.new(0.5, -140, 0, 24)
	}):Play()
	task.delay(2.8, function()
		TweenService:Create(popup, TweenInfo.new(0.25), {
			Position = UDim2.new(0.5, -140, 0, -80)
		}):Play()
		task.delay(0.3, function()
			popup.Visible = false
			popupActive = false
		end)
	end)
end)

-- Shop toggle button
local shopBtn = Instance.new("TextButton")
shopBtn.Name = "ShopButton"
shopBtn.Size = UDim2.new(0, 100, 0, 38)
shopBtn.Position = UDim2.new(1, -114, 1, -52)
shopBtn.BackgroundColor3 = Color3.fromRGB(255, 200, 40)
shopBtn.TextColor3 = Color3.fromRGB(30, 20, 0)
shopBtn.TextSize = 16
shopBtn.Font = Enum.Font.GothamBold
shopBtn.Text = "Shop"
shopBtn.BorderSizePixel = 0
shopBtn.Parent = screenGui
makeCorner(shopBtn, 10)

local shopToggle = Instance.new("BindableEvent")
shopToggle.Name = "ToggleShop"
shopToggle.Parent = screenGui

shopBtn.MouseButton1Click:Connect(function()
	shopToggle:Fire()
end)
