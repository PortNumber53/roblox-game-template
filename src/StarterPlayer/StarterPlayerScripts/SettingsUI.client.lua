-- SettingsUI: toggleable settings panel

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))
local RemoteSetup = require(ReplicatedStorage:WaitForChild("RemoteSetup"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local playerSettings = {
	MusicEnabled = true,
	SFXEnabled = true,
}

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
	Name = "SettingsToggle",
	ResetOnSpawn = false,
	Enabled = true,
	Parent = playerGui,
})

local toggleBtn = createInstance("TextButton", {
	Name = "SettingsBtn",
	Text = "Settings",
	Size = UDim2.new(0, 110, 0, 36),
	Position = UDim2.new(0, 15, 0.5, 22),
	BackgroundColor3 = Color3.fromRGB(60, 60, 90),
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
	Name = "SettingsPanel",
	ResetOnSpawn = false,
	Enabled = false,
	Parent = playerGui,
})

local backdrop = createInstance("Frame", {
	Size = UDim2.new(1, 0, 1, 0),
	BackgroundColor3 = Color3.new(0, 0, 0),
	BackgroundTransparency = 0.5,
	BorderSizePixel = 0,
	Parent = screenGui,
})

local panel = createInstance("Frame", {
	Name = "Panel",
	Size = UDim2.new(0, 320, 0, 200),
	Position = UDim2.new(0.5, -160, 0.5, -100),
	BackgroundColor3 = Color3.fromRGB(20, 20, 35),
	BorderSizePixel = 0,
	Parent = screenGui,
})
makeCorner(panel, 12)
createInstance("UIStroke", { Color = Color3.fromRGB(80, 80, 120), Thickness = 2, Parent = panel })

createInstance("TextLabel", {
	Text = "Settings",
	Size = UDim2.new(1, -50, 0, 30),
	Position = UDim2.new(0, 16, 0, 10),
	BackgroundTransparency = 1,
	TextColor3 = Color3.fromRGB(255, 255, 255),
	Font = Enum.Font.GothamBold,
	TextSize = 20,
	TextXAlignment = Enum.TextXAlignment.Left,
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

-- Music toggle
local musicBtn = createInstance("TextButton", {
	Text = "Music: ON",
	Size = UDim2.new(0.5, -20, 0, 40),
	Position = UDim2.new(0, 15, 0, 55),
	BackgroundColor3 = Color3.fromRGB(50, 50, 70),
	TextColor3 = Color3.fromRGB(255, 255, 255),
	Font = Enum.Font.GothamBold,
	TextSize = 14,
	Parent = panel,
})
makeCorner(musicBtn, 8)

musicBtn.MouseButton1Click:Connect(function()
	playerSettings.MusicEnabled = not playerSettings.MusicEnabled
	musicBtn.Text = "Music: " .. (playerSettings.MusicEnabled and "ON" or "OFF")
end)

-- SFX toggle
local sfxBtn = createInstance("TextButton", {
	Text = "SFX: ON",
	Size = UDim2.new(0.5, -20, 0, 40),
	Position = UDim2.new(0.5, 5, 0, 55),
	BackgroundColor3 = Color3.fromRGB(50, 50, 70),
	TextColor3 = Color3.fromRGB(255, 255, 255),
	Font = Enum.Font.GothamBold,
	TextSize = 14,
	Parent = panel,
})
makeCorner(sfxBtn, 8)

sfxBtn.MouseButton1Click:Connect(function()
	playerSettings.SFXEnabled = not playerSettings.SFXEnabled
	sfxBtn.Text = "SFX: " .. (playerSettings.SFXEnabled and "ON" or "OFF")
end)

--------------------------------------------------
-- Toggle logic
--------------------------------------------------

local function setVisible(v)
	screenGui.Enabled = v
end

toggleBtn.MouseButton1Click:Connect(function()
	setVisible(not screenGui.Enabled)
end)

closeBtn.MouseButton1Click:Connect(function()
	setVisible(false)
end)

backdrop.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		setVisible(false)
	end
end)

toggleGui.Enabled = true

RemoteSetup.GetRemote(GameConfig.Remotes.GameStateChanged).OnClientEvent:Connect(function(newState)
	setVisible(false)
end)

print("[SettingsUI] Initialized")
