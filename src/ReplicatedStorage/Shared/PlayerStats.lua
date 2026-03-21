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
		ReloadSpeed = 0,
	}
	return self
end

function PlayerStats:GetUpgradeCost(upgradeId)
	local def = UpgradeDefinitions[upgradeId]
	if not def then return math.huge end
	local level = self.upgrades[upgradeId] or 0
	return math.floor(def.baseCost * (def.costMultiplier ^ level))
end

-- Diminishing returns: base + step * ln(1 + level)
-- Each level always improves the stat, but by less than the previous one
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
	-- Lower is better; approaches min asymptotically
	local minRate = 0.03
	local range = Config.FireRateBase - minRate
	return minRate + range / (1 + self.upgrades.FireRate * 0.15)
end

function PlayerStats:GetRange()
	local bonus = diminishing(self.upgrades.Range, Config.UpgradeStepValues.Range)
	return Config.ProjectileRangeBase + bonus
end

function PlayerStats:GetMoveSpeed()
	-- Approaches cap asymptotically
	local maxSpeed = Config.MoveSpeedCap
	local range = maxSpeed - Config.BaseMoveSpeed
	return maxSpeed - range / (1 + self.upgrades.MoveSpeed * 0.12)
end

function PlayerStats:GetReloadRate()
	-- Higher is better; base rate increased with diminishing returns
	local bonus = diminishing(self.upgrades.ReloadSpeed, Config.UpgradeStepValues.ReloadSpeed)
	return Config.RefillRatePerTick + bonus
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
			ReloadSpeed = self.upgrades.ReloadSpeed,
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
			ReloadSpeed = self.upgrades.ReloadSpeed,
		},
		maxPaint = self:GetMaxPaint(),
		splashRadius = self:GetSplashRadius(),
		fireRate = self:GetFireRate(),
		range = self:GetRange(),
		moveSpeed = self:GetMoveSpeed(),
		reloadRate = self:GetReloadRate(),
	}
end

return PlayerStats
