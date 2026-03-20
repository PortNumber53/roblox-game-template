-- ShootingController: client-side paintball shooting with auto-fire and projectile visuals

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))
local RemoteSetup = require(ReplicatedStorage:WaitForChild("RemoteSetup"))
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local player = Players.LocalPlayer
local mouse = player:GetMouse()

local isFiring = false
local lastFireTime = 0
local localFireRate = Config.FireRateBase
local localRange = Config.ProjectileRangeBase
local localPaintColor = Config.PaintColors[1]
local localAmmo = Config.PaintCapacityBase

-- Track game state from GameClient
local currentState = GameConfig.GameState.WaitingRoom

-- Projectile visuals folder
local projectilesFolder = Instance.new("Folder")
projectilesFolder.Name = "Projectiles"
projectilesFolder.Parent = workspace

--------------------------------------------------
-- Projectile visual
--------------------------------------------------

local function spawnSplatEffect(position, didPaint)
	local splat = Instance.new("Part")
	splat.Name = "PaintSplat"
	splat.Shape = Enum.PartType.Ball
	splat.Size = Vector3.new(0.5, 0.5, 0.5)
	splat.Position = position
	splat.Anchored = true
	splat.CanCollide = false
	splat.CanQuery = false
	splat.CanTouch = false
	splat.Color = didPaint and localPaintColor or Color3.fromRGB(100, 100, 100)
	splat.Material = Enum.Material.Neon
	splat.Transparency = 0.3
	splat.Parent = projectilesFolder

	local expandSize = didPaint and Vector3.new(2.5, 2.5, 2.5) or Vector3.new(1, 1, 1)
	local tween = TweenService:Create(splat, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = expandSize,
		Transparency = 1,
	})
	tween:Play()
	tween.Completed:Connect(function()
		splat:Destroy()
	end)
end

local function spawnProjectile(origin, direction, range)
	local rayParams = RaycastParams.new()
	rayParams.FilterDescendantsInstances = { projectilesFolder, player.Character }
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	local hitResult = workspace:Raycast(origin, direction * range, rayParams)

	local hitDist = hitResult and (hitResult.Position - origin).Magnitude or range
	local endPosition = hitResult and hitResult.Position or (origin + direction * range)
	local travelTime = hitDist / Config.ProjectileSpeed

	local ball = Instance.new("Part")
	ball.Name = "Paintball"
	ball.Shape = Enum.PartType.Ball
	ball.Size = Vector3.new(Config.ProjectileSize, Config.ProjectileSize, Config.ProjectileSize)
	ball.Position = origin
	ball.Anchored = true
	ball.CanCollide = false
	ball.CanQuery = false
	ball.CanTouch = false
	ball.Color = localPaintColor
	ball.Material = Enum.Material.Neon
	ball.Parent = projectilesFolder

	local tween = TweenService:Create(ball, TweenInfo.new(travelTime, Enum.EasingStyle.Linear), {
		Position = endPosition,
	})
	tween:Play()
	tween.Completed:Connect(function()
		ball:Destroy()
		if hitResult then
			spawnSplatEffect(endPosition, true)
		end
	end)

	task.delay(travelTime + 0.5, function()
		if ball.Parent then
			ball:Destroy()
		end
	end)

	return ball
end

--------------------------------------------------
-- Input handling (hold to auto-fire)
--------------------------------------------------

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then
		isFiring = true
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then
		isFiring = false
	end
end)

--------------------------------------------------
-- Auto-fire loop
--------------------------------------------------

RunService.Heartbeat:Connect(function()
	if not isFiring then return end
	if currentState ~= GameConfig.GameState.InGame then return end
	if localAmmo <= 0 then return end

	local now = tick()
	if now - lastFireTime < localFireRate then return end
	lastFireTime = now

	local character = player.Character
	if not character then return end
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return end

	local camera = workspace.CurrentCamera
	if not camera then return end

	-- Raycast from camera through mouse to find the aim target point
	local aimRay = camera:ScreenPointToRay(mouse.X, mouse.Y)
	local aimOrigin = aimRay.Origin
	local aimDirection = aimRay.Direction.Unit

	-- Find what the mouse is pointing at to get the target position
	local raycastParams = RaycastParams.new()
	raycastParams.FilterDescendantsInstances = { character }
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	local aimResult = workspace:Raycast(aimOrigin, aimDirection * (localRange + 100), raycastParams)

	local targetPoint
	if aimResult then
		targetPoint = aimResult.Position
	else
		targetPoint = aimOrigin + aimDirection * localRange
	end

	-- Projectile fires from character toward the target point
	local gunOrigin = rootPart.Position + Vector3.new(0, 1, 0)
	local direction = (targetPoint - gunOrigin).Unit

	-- Fire to server
	RemoteSetup.GetRemote(GameConfig.Remotes.ShootPaintball):FireServer(gunOrigin, direction)

	-- Spawn local visual projectile
	spawnProjectile(gunOrigin, direction, localRange)
end)

--------------------------------------------------
-- Remote listeners
--------------------------------------------------

-- Update local stats for fire rate, range, and ammo
RemoteSetup.GetRemote(GameConfig.Remotes.StatsSync).OnClientEvent:Connect(function(stats)
	if stats.fireRate then
		localFireRate = stats.fireRate
	end
	if stats.range then
		localRange = stats.range
	end
	if stats.paint then
		localAmmo = stats.paint
	end
end)

-- Also update ammo from feedback (more frequent than full sync)
RemoteSetup.GetRemote(GameConfig.Remotes.Feedback).OnClientEvent:Connect(function(feedbackType, paint)
	if feedbackType == "paint" and paint then
		localAmmo = paint
	end
end)

-- Update paint color from player stats
local function updatePaintColor()
	local character = player.Character
	if not character then return end
	-- Use the player's assigned color from Config
	-- This is set server-side via colorIndex
end

-- Hit confirmation from server
RemoteSetup.GetRemote(GameConfig.Remotes.PaintballHit).OnClientEvent:Connect(function(hitPosition, didPaint)
	spawnSplatEffect(hitPosition, didPaint)
end)

-- Track game state
RemoteSetup.GetRemote(GameConfig.Remotes.GameStateChanged).OnClientEvent:Connect(function(newState)
	currentState = newState
	if newState ~= GameConfig.GameState.InGame then
		isFiring = false
	end
end)

print("[ShootingController] Initialized")
