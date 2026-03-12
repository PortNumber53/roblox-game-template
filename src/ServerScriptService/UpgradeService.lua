local UpgradeDefinitions = require(game.ReplicatedStorage.Shared.UpgradeDefinitions)

local UpgradeService = {}

function UpgradeService.TryPurchase(stats, upgradeId)
	local def = UpgradeDefinitions[upgradeId]
	if not def then
		return false, "Unknown upgrade"
	end

	local level = stats.upgrades[upgradeId] or 0
	if level >= def.maxLevel then
		return false, "Max level reached"
	end

	local cost = stats:GetUpgradeCost(upgradeId)
	if stats.coins < cost then
		return false, "Not enough coins"
	end

	stats.coins = stats.coins - cost
	stats.upgrades[upgradeId] = level + 1
	return true, "OK"
end

return UpgradeService
