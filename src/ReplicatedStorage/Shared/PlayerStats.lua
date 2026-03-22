local Config = require(script.Parent.Config)
local UpgradeDefinitions = require(script.Parent.UpgradeDefinitions)
local DroneUpgradeDefinitions = require(script.Parent.DroneUpgradeDefinitions)

local PlayerStats = {}
PlayerStats.__index = PlayerStats

function PlayerStats.new(colorIndex)
	local self = setmetatable({}, PlayerStats)
	self.colorIndex = colorIndex
	self.paintColor = Config.PaintColors[colorIndex] or Config.PaintColors[1]
	self.coins = 0
	self.paint = Config.PaintCapacityBase
	self.upgrades = {
		SplashRadius = 0,
		FireRate = 0,
		AmmoCapacity = 0,
		MoveSpeed = 0,
		Range = 0,
		ReloadSpeed = 0,
	}
	self.drones = {} -- up to 3: { expiresAt, speed, capacity }
	return self
end

function PlayerStats:GetUpgradeCost(upgradeId)
	local def = UpgradeDefinitions[upgradeId]
	if not def then return math.huge end
	local level = self.upgrades[upgradeId] or 0
	return math.floor(def.baseCost * (def.costMultiplier ^ level))
end

-- Diminishing returns: base + step * ln(1 + level)
local function diminishing(level, step)
	return step * math.log(1 + level)
end

function PlayerStats:GetMaxPaint()
	local bonus = diminishing(self.upgrades.AmmoCapacity, Config.UpgradeStepValues.AmmoCapacity)
	return math.floor(Config.PaintCapacityBase + bonus)
end

function PlayerStats:GetSplashRadius()
	local bonus = diminishing(self.upgrades.SplashRadius, Config.UpgradeStepValues.SplashRadius)
	return Config.SplashRadiusBase + bonus
end

function PlayerStats:GetFireRate()
	local minRate = 0.03
	local range = Config.FireRateBase - minRate
	return minRate + range / (1 + self.upgrades.FireRate * 0.15)
end

function PlayerStats:GetRange()
	local bonus = diminishing(self.upgrades.Range, Config.UpgradeStepValues.Range)
	return Config.ProjectileRangeBase + bonus
end

function PlayerStats:GetMoveSpeed()
	local maxSpeed = Config.MoveSpeedCap
	local range = maxSpeed - Config.BaseMoveSpeed
	return maxSpeed - range / (1 + self.upgrades.MoveSpeed * 0.12)
end

function PlayerStats:GetReloadRate()
	local bonus = diminishing(self.upgrades.ReloadSpeed, Config.UpgradeStepValues.ReloadSpeed)
	return Config.RefillRatePerTick + bonus
end

--------------------------------------------------
-- Drone methods
--------------------------------------------------

function PlayerStats:GetActiveDrones()
	local active = {}
	local now = os.time()
	for i, drone in ipairs(self.drones) do
		if drone.expiresAt and drone.expiresAt > now then
			table.insert(active, { index = i, drone = drone })
		end
	end
	return active
end

function PlayerStats:GetActiveDroneCount()
	local count = 0
	local now = os.time()
	for _, drone in ipairs(self.drones) do
		if drone.expiresAt and drone.expiresAt > now then
			count = count + 1
		end
	end
	return count
end

function PlayerStats:AddDrone()
	local now = os.time()
	local duration = Config.DroneSubscriptionDays * 86400

	-- Try to reuse an expired slot first
	for i, drone in ipairs(self.drones) do
		if not drone.expiresAt or drone.expiresAt <= now then
			drone.expiresAt = now + duration
			return i
		end
	end

	-- Add new slot if under max
	if #self.drones < Config.DroneMaxCount then
		table.insert(self.drones, {
			expiresAt = now + duration,
			speed = 0,
			capacity = 0,
		})
		return #self.drones
	end

	return nil
end

function PlayerStats:GetDroneCycleTime(droneIndex)
	local drone = self.drones[droneIndex]
	if not drone then return Config.DroneBaseCycleTime end
	return Config.DroneBaseCycleTime / (1 + drone.speed * Config.DroneSpeedStep)
end

function PlayerStats:GetDroneDelivery(droneIndex)
	local drone = self.drones[droneIndex]
	if not drone then return Config.DroneBaseDelivery end
	return math.floor(Config.DroneBaseDelivery + diminishing(drone.capacity, Config.DroneCapacityStep))
end

function PlayerStats:GetDroneUpgradeCost(droneIndex, upgradeId)
	local drone = self.drones[droneIndex]
	if not drone then return math.huge end
	local def = DroneUpgradeDefinitions[upgradeId]
	if not def then return math.huge end
	local level = 0
	if upgradeId == "DroneSpeed" then
		level = drone.speed
	elseif upgradeId == "DroneCapacity" then
		level = drone.capacity
	end
	return math.floor(def.baseCost * (def.costMultiplier ^ level))
end

--------------------------------------------------
-- Save/Load
--------------------------------------------------

function PlayerStats:ApplySavedData(data)
	if typeof(data) ~= "table" then
		return
	end

	self.coins = data.coins or self.coins

	if typeof(data.upgrades) == "table" then
		for upgradeId, level in pairs(data.upgrades) do
			if self.upgrades[upgradeId] ~= nil then
				self.upgrades[upgradeId] = level
			end
		end
	end

	if typeof(data.drones) == "table" then
		self.drones = {}
		for i = 1, math.min(#data.drones, Config.DroneMaxCount) do
			local d = data.drones[i]
			if typeof(d) == "table" then
				table.insert(self.drones, {
					expiresAt = d.expiresAt or 0,
					speed = d.speed or 0,
					capacity = d.capacity or 0,
				})
			end
		end
	end

	self.paint = self:GetMaxPaint()
end

function PlayerStats:ToSaveData()
	local droneData = {}
	for _, drone in ipairs(self.drones) do
		table.insert(droneData, {
			expiresAt = drone.expiresAt,
			speed = drone.speed,
			capacity = drone.capacity,
		})
	end

	return {
		version = 4,
		coins = self.coins,
		upgrades = {
			SplashRadius = self.upgrades.SplashRadius,
			FireRate = self.upgrades.FireRate,
			AmmoCapacity = self.upgrades.AmmoCapacity,
			MoveSpeed = self.upgrades.MoveSpeed,
			Range = self.upgrades.Range,
			ReloadSpeed = self.upgrades.ReloadSpeed,
		},
		drones = droneData,
	}
end

function PlayerStats:Serialize()
	local now = os.time()
	local droneInfo = {}
	for i, drone in ipairs(self.drones) do
		local active = drone.expiresAt and drone.expiresAt > now
		table.insert(droneInfo, {
			active = active,
			remainingSeconds = active and (drone.expiresAt - now) or 0,
			speed = drone.speed,
			capacity = drone.capacity,
			cycleTime = self:GetDroneCycleTime(i),
			delivery = self:GetDroneDelivery(i),
		})
	end

	return {
		colorIndex = self.colorIndex,
		coins = self.coins,
		paint = self.paint,
		upgrades = {
			SplashRadius = self.upgrades.SplashRadius,
			FireRate = self.upgrades.FireRate,
			AmmoCapacity = self.upgrades.AmmoCapacity,
			MoveSpeed = self.upgrades.MoveSpeed,
			Range = self.upgrades.Range,
			ReloadSpeed = self.upgrades.ReloadSpeed,
		},
		maxPaint = self:GetMaxPaint(),
		splashRadius = self:GetSplashRadius(),
		fireRate = self:GetFireRate(),
		range = self:GetRange(),
		moveSpeed = self:GetMoveSpeed(),
		reloadRate = self:GetReloadRate(),
		drones = droneInfo,
	}
end

return PlayerStats
