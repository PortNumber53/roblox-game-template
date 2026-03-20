local Config = require(game.ReplicatedStorage.Shared.Config)

local RefillService = {}

function RefillService.TryRefill(player, stats)
	local maxPaint = stats:GetMaxPaint()
	if stats.paint >= maxPaint then return false end

	local workspace = game:GetService("Workspace")
	local bases = workspace:FindFirstChild("Bases")
	if not bases then return false end

	local character = player.Character
	if not character then return false end
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return false end

	local padName = "BasePad_" .. stats.colorIndex
	local pad = bases:FindFirstChild(padName)
	if not pad then return false end

	local horizontalOffset = rootPart.Position - pad.Position
	local halfX = pad.Size.X / 2
	local halfZ = pad.Size.Z / 2
	local margin = 3

	local insideX = math.abs(horizontalOffset.X) <= halfX + margin
	local insideZ = math.abs(horizontalOffset.Z) <= halfZ + margin

	if not (insideX and insideZ) then
		return false
	end

	stats.paint = math.min(maxPaint, stats.paint + Config.RefillRatePerTick)
	return true
end

return RefillService
