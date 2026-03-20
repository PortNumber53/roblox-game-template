local Config = require(script.Parent.Config)
local UpgradeDefinitions = require(script.Parent.UpgradeDefinitions)

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
	}
	return self
end

function PlayerStats:GetUpgradeCost(upgradeId)
	local def = UpgradeDefinitions[upgradeId]
	if not def then return math.huge end
	local level = self.upgrades[upgradeId] or 0
	if level >= def.maxLevel then return math.huge end
	return def.baseCost + def.costStep * level
end

function PlayerStats:GetMaxPaint()
	local bonus = self.upgrades.AmmoCapacity * Config.UpgradeStepValues.AmmoCapacity
	return Config.PaintCapacityBase + bonus
end

function PlayerStats:GetSplashRadius()
	local bonus = self.upgrades.SplashRadius * Config.UpgradeStepValues.SplashRadius
	return Config.SplashRadiusBase + bonus
end

function PlayerStats:GetFireRate()
	local reduction = self.upgrades.FireRate * Config.UpgradeStepValues.FireRate
	return math.max(0.05, Config.FireRateBase - reduction)
end

function PlayerStats:GetRange()
	local bonus = self.upgrades.Range * Config.UpgradeStepValues.Range
	return Config.ProjectileRangeBase + bonus
end

function PlayerStats:GetMoveSpeed()
	local bonus = self.upgrades.MoveSpeed * Config.UpgradeStepValues.MoveSpeed
	return math.min(Config.MoveSpeedCap, Config.BaseMoveSpeed + bonus)
end

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

	self.paint = self:GetMaxPaint()
end

function PlayerStats:ToSaveData()
	return {
		version = 3,
		coins = self.coins,
		upgrades = {
			SplashRadius = self.upgrades.SplashRadius,
			FireRate = self.upgrades.FireRate,
			AmmoCapacity = self.upgrades.AmmoCapacity,
			MoveSpeed = self.upgrades.MoveSpeed,
			Range = self.upgrades.Range,
		},
	}
end

function PlayerStats:Serialize()
	return {
		coins = self.coins,
		paint = self.paint,
		upgrades = {
			SplashRadius = self.upgrades.SplashRadius,
			FireRate = self.upgrades.FireRate,
			AmmoCapacity = self.upgrades.AmmoCapacity,
			MoveSpeed = self.upgrades.MoveSpeed,
			Range = self.upgrades.Range,
		},
		maxPaint = self:GetMaxPaint(),
		splashRadius = self:GetSplashRadius(),
		fireRate = self:GetFireRate(),
		range = self:GetRange(),
		moveSpeed = self:GetMoveSpeed(),
	}
end

return PlayerStats
