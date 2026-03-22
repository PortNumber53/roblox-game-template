-- DroneVisuals: visual drone Parts that fly between Paint Fountain and player

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))
local RemoteSetup = require(ReplicatedStorage:WaitForChild("RemoteSetup"))
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local player = Players.LocalPlayer
local currentStats = nil
local currentState = GameConfig.GameState.WaitingRoom

local droneParts = {}
local droneFolder = Instance.new("Folder")
droneFolder.Name = "DroneVisuals"
droneFolder.Parent = workspace

local HOVER_HEIGHT = 5
local DRONE_OFFSETS = {
	Vector3.new(-2, 0, 0),
	Vector3.new(2, 0, 0),
	Vector3.new(0, 0, 2),
}

local function getRefillPadPos()
	local bases = workspace:FindFirstChild("Bases")
	if not bases then return Vector3.new(0, 5, 0) end

	-- Find this player's assigned base pad from stats
	local colorIndex = currentStats and currentStats.colorIndex or 1
	local pad = bases:FindFirstChild("BasePad_" .. colorIndex)
	if pad then
		return pad.Position + Vector3.new(0, 3, 0)
	end

	-- Fallback: try any base pad
	for _, child in ipairs(bases:GetChildren()) do
		if child.Name:match("^BasePad_") then
			return child.Position + Vector3.new(0, 3, 0)
		end
	end

	return Vector3.new(0, 5, 0)
end

local function getPlayerPosition()
	local character = player.Character
	if not character then return nil end
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return nil end
	return rootPart.Position + Vector3.new(0, HOVER_HEIGHT, 0)
end

local DRONE_SHAPES = {
	{ -- Drone 1: flat disc
		shape = Enum.PartType.Cylinder,
		size = Vector3.new(0.5, 2, 2),
		color = Color3.fromRGB(80, 180, 255),
		rotation = CFrame.Angles(0, 0, math.rad(90)),
	},
	{ -- Drone 2: sphere
		shape = Enum.PartType.Ball,
		size = Vector3.new(1.2, 1.2, 1.2),
		color = Color3.fromRGB(255, 160, 60),
		rotation = CFrame.new(),
	},
	{ -- Drone 3: wedge block
		shape = Enum.PartType.Block,
		size = Vector3.new(1.8, 0.6, 1.2),
		color = Color3.fromRGB(120, 255, 140),
		rotation = CFrame.new(),
	},
}

local function createDronePart(index)
	local spec = DRONE_SHAPES[index] or DRONE_SHAPES[1]

	local part = Instance.new("Part")
	part.Name = "Drone_" .. index
	part.Shape = spec.shape
	part.Size = spec.size
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Material = Enum.Material.Neon
	part.Color = spec.color
	part.Parent = droneFolder

	-- Store rotation offset for the update loop
	part:SetAttribute("RotOffset", index)

	return part, spec.rotation
end

local function destroyDrone(index)
	if droneParts[index] then
		if droneParts[index].part then
			droneParts[index].part:Destroy()
		end
		droneParts[index] = nil
	end
end

local droneDeliverRemote = nil
local CONTACT_DISTANCE = 4

local function ensureDrone(index)
	if not droneParts[index] then
		local part, rotation = createDronePart(index)
		droneParts[index] = {
			part = part,
			rotation = rotation,
			phase = "flyingToPad",
			timer = 0,
			cycleTime = Config.DroneBaseCycleTime,
			loaded = false,
			filledThisStop = false,
			deliveredThisStop = false,
		}
	end
	return droneParts[index]
end

-- Quadratic bezier arc between two points with a height offset
local function arcLerp(from, to, t, arcHeight)
	local mid = (from + to) / 2 + Vector3.new(0, arcHeight, 0)
	local p1 = from:Lerp(mid, t)
	local p2 = mid:Lerp(to, t)
	return p1:Lerp(p2, t)
end

--------------------------------------------------
-- Update loop
--------------------------------------------------

RunService.Heartbeat:Connect(function(dt)
	if currentState ~= GameConfig.GameState.InGame then
		for i in pairs(droneParts) do
			destroyDrone(i)
		end
		return
	end

	local drones = currentStats and currentStats.drones or {}
	local playerPos = getPlayerPosition()
	local fountainPos = getRefillPadPos()

	for i in pairs(droneParts) do
		local info = drones[i]
		if not info or not info.active then
			destroyDrone(i)
		end
	end

	if not playerPos then return end

	for i, droneInfo in ipairs(drones) do
		if not droneInfo.active then continue end

		local drone = ensureDrone(i)
		local offset = DRONE_OFFSETS[i] or Vector3.new(0, 0, 0)
		local hoverTarget = playerPos + offset
		local padPos = fountainPos
		drone.cycleTime = droneInfo.cycleTime or Config.DroneBaseCycleTime

		drone.timer = drone.timer + dt

		local halfCycle = drone.cycleTime / 2
		local padPause = 0.4
		local playerPause = 0.8

		-- Phases match server: flyingToPad -> atPad -> flyingToPlayer -> atPlayer
		if drone.phase == "flyingToPad" then
			local t = math.clamp(drone.timer / halfCycle, 0, 1)
			if t < 0.01 then
				drone._tripStart = drone.part.Position
			end
			drone.part.Position = arcLerp(drone._tripStart or drone.part.Position, padPos, t, 8)
			if t >= 1 then
				drone.phase = "atPad"
				drone.timer = 0
			end

		elseif drone.phase == "atPad" then
			drone.part.Position = padPos
			-- Fill drone at the pad (once per stop)
			if not drone.filledThisStop then
				drone.filledThisStop = true
				drone.loaded = true
				if not droneDeliverRemote then
					droneDeliverRemote = RemoteSetup.GetRemote(GameConfig.Remotes.DroneDeliver)
				end
				droneDeliverRemote:FireServer(i, "fill")
			end
			if drone.timer >= padPause then
				drone.phase = "flyingToPlayer"
				drone.timer = 0
				drone._tripStart = padPos
				drone.filledThisStop = false
			end

		elseif drone.phase == "flyingToPlayer" then
			local t = math.clamp(drone.timer / halfCycle, 0, 1)
			-- Fly toward a point just behind the player's back at torso height
			local backTarget = playerPos + offset + Vector3.new(0, -3, -1.5)
			drone.part.Position = arcLerp(drone._tripStart or padPos, backTarget, t, 8)
			if t >= 1 then
				drone.phase = "atPlayer"
				drone.timer = 0
			end

		elseif drone.phase == "atPlayer" then
			-- Move to player's back at torso height
			local backPos = playerPos + offset + Vector3.new(0, -3, -1.5)
			drone.part.Position = drone.part.Position:Lerp(backPos, math.min(1, dt * 10))

			-- Deliver paint when close enough to the player
			if not drone.deliveredThisStop and drone.loaded then
				local character = player.Character
				local rootPart = character and character:FindFirstChild("HumanoidRootPart")
				if rootPart and (drone.part.Position - rootPart.Position).Magnitude <= CONTACT_DISTANCE then
					-- Check if player has room for paint
					local paint = currentStats and currentStats.paint or 0
					local maxPaint = currentStats and currentStats.maxPaint or 1
					if paint < maxPaint then
						drone.loaded = false
						drone.deliveredThisStop = true
						if not droneDeliverRemote then
							droneDeliverRemote = RemoteSetup.GetRemote(GameConfig.Remotes.DroneDeliver)
						end
						droneDeliverRemote:FireServer(i, "deliver")
					end
					-- If full, keep hovering (don't deliver, don't fly back)
				end
			end

			-- Only fly back to pad after delivering (or if not loaded)
			if drone.timer >= playerPause and (drone.deliveredThisStop or not drone.loaded) then
				drone.phase = "flyingToPad"
				drone.timer = 0
				drone.deliveredThisStop = false
			end
		end

		-- Gentle bobbing + spin
		local bobOffset = Vector3.new(0, math.sin(tick() * 3 + i) * 0.3, 0)
		local spin = CFrame.Angles(0, tick() * 1.5 + i * 2, 0)
		drone.part.CFrame = CFrame.new(drone.part.Position + bobOffset) * spin * (drone.rotation or CFrame.new())
	end
end)

--------------------------------------------------
-- Events
--------------------------------------------------

RemoteSetup.GetRemote(GameConfig.Remotes.StatsSync).OnClientEvent:Connect(function(stats)
	currentStats = stats
end)

RemoteSetup.GetRemote(GameConfig.Remotes.GameStateChanged).OnClientEvent:Connect(function(newState)
	currentState = newState
end)

print("[DroneVisuals] Initialized")
