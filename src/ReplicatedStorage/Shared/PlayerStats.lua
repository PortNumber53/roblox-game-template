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
	self.size = Config.BaseCharacterScale
	self.milestoneIndex = 0
	self.upgrades = {
		MaxSize = 0,
		SizeMultiplier = 0,
		BrushSize = 0,
		BrushSpeed = 0,
		BucketCapacity = 0,
		MoveSpeed = 0,
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
	local bonus = self.upgrades.BucketCapacity * Config.UpgradeStepValues.BucketCapacity
	return Config.PaintCapacityBase + bonus
end

function PlayerStats:GetSizeCap()
	local bonus = self.upgrades.MaxSize * Config.UpgradeStepValues.MaxSize
	return Config.SizeCapBase + bonus
end

function PlayerStats:GetSizeMultiplier()
	return 1 + self.upgrades.SizeMultiplier * Config.UpgradeStepValues.SizeMultiplier
end

function PlayerStats:GetBrushRadius()
	local bonus = self.upgrades.BrushSize * Config.UpgradeStepValues.BrushSize
	return Config.BrushRadiusBase + bonus
end

function PlayerStats:GetBrushCooldown()
	local reduction = self.upgrades.BrushSpeed * Config.UpgradeStepValues.BrushSpeed
	return math.max(0.05, Config.BrushCooldownBase - reduction)
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
	self.milestoneIndex = data.milestoneIndex or self.milestoneIndex

	if typeof(data.upgrades) == "table" then
		for upgradeId, level in pairs(data.upgrades) do
			if self.upgrades[upgradeId] ~= nil then
				self.upgrades[upgradeId] = level
			end
		end
	end

	self.paint = self:GetMaxPaint()
	self.size = Config.BaseCharacterScale
end

function PlayerStats:ToSaveData()
	return {
		version = 1,
		coins = self.coins,
		milestoneIndex = self.milestoneIndex,
		upgrades = {
			MaxSize = self.upgrades.MaxSize,
			SizeMultiplier = self.upgrades.SizeMultiplier,
			BrushSize = self.upgrades.BrushSize,
			BrushSpeed = self.upgrades.BrushSpeed,
			BucketCapacity = self.upgrades.BucketCapacity,
			MoveSpeed = self.upgrades.MoveSpeed,
		},
	}
end

function PlayerStats:Serialize()
	return {
		coins = self.coins,
		paint = self.paint,
		size = self.size,
		milestoneIndex = self.milestoneIndex,
		upgrades = {
			MaxSize = self.upgrades.MaxSize,
			SizeMultiplier = self.upgrades.SizeMultiplier,
			BrushSize = self.upgrades.BrushSize,
			BrushSpeed = self.upgrades.BrushSpeed,
			BucketCapacity = self.upgrades.BucketCapacity,
			MoveSpeed = self.upgrades.MoveSpeed,
		},
		maxPaint = self:GetMaxPaint(),
		sizeCap = self:GetSizeCap(),
		brushRadius = self:GetBrushRadius(),
		brushCooldown = self:GetBrushCooldown(),
		moveSpeed = self:GetMoveSpeed(),
	}
end

return PlayerStats
