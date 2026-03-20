local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local evStatsSync = remotes:WaitForChild("StatsSync")

-- Build the ScreenGui
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "HUD"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

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
	UDim2.new(0, 220, 0, 60),
	UDim2.new(0, 10, 1, -70),
	Color3.fromRGB(15, 15, 15), 0.3
)
makeCorner(panel, 8)

-- Coins label
local coinsLabel = makeLabel(panel, "CoinsLabel", "Coins: 0", UDim2.new(1, -16, 0, 20), UDim2.new(0, 8, 0, 6), Color3.fromRGB(255, 220, 60), 14, true)

-- Ammo label + bar
local paintLabel = makeLabel(panel, "PaintLabel", "Ammo: 120 / 120", UDim2.new(1, -16, 0, 16), UDim2.new(0, 8, 0, 28), Color3.fromRGB(210, 235, 255), 12)

local paintBarBG = makeFrame(panel, "PaintBarBG", UDim2.new(1, -16, 0, 8), UDim2.new(0, 8, 0, 44), Color3.fromRGB(40, 40, 40), 0)
makeCorner(paintBarBG, 3)

local paintBar = makeFrame(paintBarBG, "PaintBar", UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0), Color3.fromRGB(80, 160, 255), 0)
makeCorner(paintBar, 3)

local function updateBars(stats)
	local paintFraction = math.clamp((stats.paint or 0) / math.max(1, stats.maxPaint or 120), 0, 1)
	TweenService:Create(paintBar, TweenInfo.new(0.12), { Size = UDim2.new(paintFraction, 0, 1, 0) }):Play()
	paintLabel.Text = string.format("Ammo: %d / %d", math.floor(stats.paint or 0), stats.maxPaint or 120)
	coinsLabel.Text = string.format("Coins: %d", stats.coins or 0)
end

evStatsSync.OnClientEvent:Connect(function(stats)
	updateBars(stats)
end)
