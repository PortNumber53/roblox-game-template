-- ShootingService: server-side shot validation and raycast

local Config = require(game.ReplicatedStorage.Shared.Config)

local ShootingService = {}

function ShootingService.ProcessShot(player, stats, origin, direction, lastFireTimes)
	-- Validate fire rate cooldown
	local now = tick()
	local cooldown = stats:GetFireRate()
	local lastFire = lastFireTimes[player.UserId] or 0
	if now - lastFire < cooldown then return nil end
	lastFireTimes[player.UserId] = now

	-- Validate and deduct ammo (every shot costs paint)
	if stats.paint <= 0 then return nil end
	stats.paint = math.max(0, stats.paint - Config.PaintPerBrushTick)

	-- Validate origin is near player character (anti-cheat)
	local character = player.Character
	if not character then return nil end
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return nil end
	if (rootPart.Position - origin).Magnitude > 10 then
		origin = rootPart.Position
	end

	direction = direction.Unit

	-- Server-side raycast against walls
	local range = stats:GetRange()
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Include
	local wallFolder = game:GetService("Workspace"):FindFirstChild("Walls")
	if not wallFolder then return nil end
	raycastParams.FilterDescendantsInstances = { wallFolder }

	local result = game:GetService("Workspace"):Raycast(origin, direction * range, raycastParams)

	if result and result.Instance and result.Instance:GetAttribute("Paintable") then
		return {
			hit = true,
			hitPosition = result.Position,
			hitTile = result.Instance,
		}
	end

	-- Shot was valid (ammo deducted) but missed
	return { hit = false }
end

return ShootingService
