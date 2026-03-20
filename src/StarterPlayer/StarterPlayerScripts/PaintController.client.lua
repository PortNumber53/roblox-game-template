local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local evPaint = remotes:WaitForChild("Paint")
local evStatsSync = remotes:WaitForChild("StatsSync")
local evMilestone = remotes:WaitForChild("MilestoneReached")
local evFeedback = remotes:WaitForChild("Feedback")

local localStats = {
	paint = 120,
	maxPaint = 120,
	size = 1,
	sizeCap = 3,
	coins = 0,
	brushCooldown = 0.18,
	brushRadius = 7,
	milestoneIndex = 0,
	upgrades = {},
}

local isPainting = false
local lastPaintTime = 0

-- Update local stats cache whenever server syncs
evStatsSync.OnClientEvent:Connect(function(data)
	for k, v in pairs(data) do
		localStats[k] = v
	end

	-- Notify HUD
	local hud = player.PlayerGui:FindFirstChild("HUD")
	if hud then
		local event = hud:FindFirstChild("StatsUpdated")
		if event then
			event:Fire(localStats)
		end
	end
end)

evMilestone.OnClientEvent:Connect(function(coinsEarned, newSize)
	local hud = player.PlayerGui:FindFirstChild("HUD")
	if hud then
		local milestoneEvent = hud:FindFirstChild("MilestoneTriggered")
		if milestoneEvent then
			milestoneEvent:Fire(coinsEarned, newSize)
		end
	end
end)

evFeedback.OnClientEvent:Connect(function(feedbackType, paint, size)
	-- empty bucket feedback handled by HUD watching localStats
end)

-- Update character ref on respawn
player.CharacterAdded:Connect(function(newChar)
	character = newChar
end)

local function getRootPart()
	if character then
		return character:FindFirstChild("HumanoidRootPart")
	end
	return nil
end

local function getPaintTarget()
	local camera = Workspace.CurrentCamera
	if not camera then
		return nil
	end

	local mouseLocation = UserInputService:GetMouseLocation()
	local ray = camera:ViewportPointToRay(mouseLocation.X, mouseLocation.Y)

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	params.IgnoreWater = true

	local result = Workspace:Raycast(ray.Origin, ray.Direction * 200, params)
	if not result then
		return nil
	end

	local instance = result.Instance
	if not instance or not instance:IsA("BasePart") then
		return nil
	end

	if not instance:GetAttribute("Paintable") then
		return nil
	end

	return {
		position = result.Position,
		part = instance,
	}
end

-- Paint on hold (mouse button 1 or screen tap)
local function tryPaint()
	local root = getRootPart()
	if not root then return end
	local now = tick()
	if now - lastPaintTime < (localStats.brushCooldown or 0.18) then return end
	if (localStats.paint or 0) <= 0 then return end
	local target = getPaintTarget()
	if not target then return end
	lastPaintTime = now
	evPaint:FireServer(target.position, target.part)
end

RunService.RenderStepped:Connect(function()
	if isPainting then
		tryPaint()
	end
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then
		isPainting = true
	end
end)

UserInputService.InputEnded:Connect(function(input, processed)
	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then
		isPainting = false
	end
end)

return localStats
