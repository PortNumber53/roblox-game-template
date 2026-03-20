local Config = require(game.ReplicatedStorage.Shared.Config)

local GrowthService = {}

function GrowthService.ApplyGrowth(stats, wallsPainted)
	if wallsPainted <= 0 then return false end

	local gain = Config.SizePerPaintUnit * stats:GetSizeMultiplier()
	local cap = stats:GetSizeCap()
	local newSize = math.min(stats.size + gain, cap)
	local changed = newSize ~= stats.size
	stats.size = newSize
	return changed
end

function GrowthService.ApplyToCharacter(character, size)
	if not character then return end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	local ok = pcall(function()
		local desc = humanoid:GetAppliedDescription()
		desc.HeadScale = size
		desc.BodyWidthScale = size
		desc.BodyHeightScale = size
		desc.BodyDepthScale = size
		humanoid:ApplyDescription(desc)
	end)

	if ok then
		return
	end

	local bodyDepthScale = humanoid:FindFirstChild("BodyDepthScale")
	local bodyHeightScale = humanoid:FindFirstChild("BodyHeightScale")
	local bodyWidthScale = humanoid:FindFirstChild("BodyWidthScale")
	local headScale = humanoid:FindFirstChild("HeadScale")

	if bodyDepthScale then
		bodyDepthScale.Value = size
	end
	if bodyHeightScale then
		bodyHeightScale.Value = size
	end
	if bodyWidthScale then
		bodyWidthScale.Value = size
	end
	if headScale then
		headScale.Value = size
	end
end

function GrowthService.CheckMilestones(stats)
	local earned = 0
	for i = stats.milestoneIndex + 1, #Config.Milestones do
		local milestone = Config.Milestones[i]
		if stats.size >= milestone.size then
			stats.milestoneIndex = i
			stats.coins = stats.coins + milestone.reward
			earned = earned + milestone.reward
		else
			break
		end
	end
	return earned
end

return GrowthService
