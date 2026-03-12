local Config = require(game.ReplicatedStorage.Shared.Config)

local PaintService = {}

local paintedSurfaces = {}

local function getWallFolder()
	return game:GetService("Workspace"):FindFirstChild("Walls")
end

local function getPaintAreaRadius(stats)
	return math.max(1.5, stats.size * 1.75)
end

local function getSplashTileBudget(stats, radius, paintAreaRadius, sampleTile)
	local tileWidth = sampleTile and sampleTile.Size.X or Config.WallTileSize
	local tileHeight = sampleTile and sampleTile.Size.Y or Config.WallTileSize
	local tileArea = math.max(0.01, tileWidth * tileHeight)
	local splashArea = math.pi * radius * paintAreaRadius * Config.PaintSplashCoverage
	local scaledBudget = math.floor(splashArea / tileArea)
	return math.max(Config.PaintSplashTileBudget, scaledBudget)
end

function PaintService.TryPaint(player, stats, position, targetTile)
	if stats.paint <= 0 then
		return 0
	end

	local wallFolder = getWallFolder()
	if not wallFolder then return 0 end
	if not targetTile or not targetTile:IsA("BasePart") then return 0 end
	if not targetTile:GetAttribute("Paintable") then return 0 end
	if not targetTile:IsDescendantOf(wallFolder) then return 0 end

	local radius = stats:GetBrushRadius()
	local paintAreaRadius = getPaintAreaRadius(stats)
	local painted = 0
	local targetWall = targetTile.Parent
	local targetSide = targetTile:GetAttribute("PaintSide")
	local candidates = {}

	if not targetWall then
		return 0
	end

	for _, tile in ipairs(targetWall:GetChildren()) do
		if not tile:IsA("BasePart") then continue end
		if not tile:GetAttribute("Paintable") then continue end
		if tile:GetAttribute("PaintSide") ~= targetSide then continue end

		local offset = tile.Position - position
		local dist = offset.Magnitude
		if dist > radius + paintAreaRadius then continue end

		local xNorm = math.abs(offset.X) / math.max(0.001, radius)
		local yNorm = math.abs(offset.Y) / math.max(0.001, paintAreaRadius)
		local shapeScore = xNorm + yNorm * 1.35
		local jitterSeed = math.abs(math.sin(tile.Position.X * 12.73 + tile.Position.Y * 7.19 + tile.Position.Z * 3.11))
		local threshold = 1.15 + jitterSeed * Config.PaintSplashJitter

		if shapeScore <= threshold then
			table.insert(candidates, {
				tile = tile,
				dist = dist,
				score = shapeScore + jitterSeed * 0.15,
			})
		end
	end

	table.sort(candidates, function(a, b)
		if a.score == b.score then
			return a.dist < b.dist
		end
		return a.score < b.score
	end)

	local maxNewTiles = math.min(
		#candidates,
		getSplashTileBudget(stats, radius, paintAreaRadius, targetTile),
		math.max(1, math.floor(stats.paint / Config.PaintPerBrushTick))
	)

	for i = 1, maxNewTiles do
		local tile = candidates[i].tile
		local alreadyOwned = paintedSurfaces[tile] == player.UserId
		if not alreadyOwned then
			paintedSurfaces[tile] = player.UserId
			tile.Color = stats.paintColor
			tile:SetAttribute("PaintedBy", player.UserId)
			painted = painted + 1
		end
	end

	local paintUsed = math.min(stats.paint, Config.PaintPerBrushTick * math.max(1, painted))
	stats.paint = math.max(0, stats.paint - paintUsed)

	return painted
end

function PaintService.GetPlayerWallCount(userId)
	local count = 0
	for _, ownerId in pairs(paintedSurfaces) do
		if ownerId == userId then
			count = count + 1
		end
	end
	return count
end

function PaintService.ResetWalls()
	paintedSurfaces = {}
	local wallFolder = getWallFolder()
	if not wallFolder then return end
	for _, wall in ipairs(wallFolder:GetChildren()) do
		for _, tile in ipairs(wall:GetChildren()) do
			if tile:IsA("BasePart") then
				tile.BrickColor = BrickColor.new("Medium stone grey")
				tile:SetAttribute("PaintedBy", 0)
			end
		end
	end
end

return PaintService
