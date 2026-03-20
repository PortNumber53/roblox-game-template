local Config = require(game.ReplicatedStorage.Shared.Config)

local WorldBuilder = {}

local function makeWall(position, size, name, parent)
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = parent

	local tileSize = Config.WallTileSize
	local tilesAcross = math.max(1, math.floor(size.X / tileSize))
	local tilesTall = math.max(1, math.floor(size.Y / tileSize))
	local actualTileWidth = size.X / tilesAcross
	local actualTileHeight = size.Y / tilesTall
	local faceThickness = 0.08
	local faceOffset = math.min(0.04, size.Z / 2 - faceThickness / 2)

	for y = 1, tilesTall do
		for x = 1, tilesAcross do
			local localX = -size.X / 2 + actualTileWidth * (x - 0.5)
			local localY = -size.Y / 2 + actualTileHeight * (y - 0.5)
			local baseLocalPosition = Vector3.new(localX, localY, 0)

			for _, side in ipairs({
				{ label = "Front", direction = 1 },
				{ label = "Back", direction = -1 },
			}) do
				local tile = Instance.new("Part")
				tile.Name = string.format("Tile_%d_%d_%s", x, y, side.label)
				tile.Size = Vector3.new(actualTileWidth, actualTileHeight, faceThickness)
				tile.Anchored = true
				tile.TopSurface = Enum.SurfaceType.Smooth
				tile.BottomSurface = Enum.SurfaceType.Smooth
				tile.BrickColor = BrickColor.new("Medium stone grey")
				tile.Material = Enum.Material.SmoothPlastic
				tile:SetAttribute("Paintable", true)
				tile:SetAttribute("PaintedBy", 0)
				tile:SetAttribute("PaintSide", side.label)
				tile.Position = position + baseLocalPosition + Vector3.new(0, 0, side.direction * faceOffset)
				tile.Parent = model
			end
		end
	end

	return model
end

local function makeBasePad(position, color, playerIndex, parent)
	local pad = Instance.new("Part")
	pad.Name = "BasePad_" .. playerIndex
	pad.Size = Vector3.new(14, 1, 14)
	pad.Position = position
	pad.Anchored = true
	pad.TopSurface = Enum.SurfaceType.Smooth
	pad.BottomSurface = Enum.SurfaceType.Smooth
	pad.Color = color
	pad.Material = Enum.Material.Neon
	pad.Transparency = 0.4
	pad:SetAttribute("BaseOwner", playerIndex)
	pad.Parent = parent
	return pad
end

local function makeSpawn(position, playerIndex, parent)
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn_" .. playerIndex
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.Position = position
	spawn.Anchored = true
	spawn.Neutral = false
	spawn.Enabled = false
	spawn.TeamColor = BrickColor.White()
	spawn.Duration = 0
	spawn.Transparency = 1
	spawn.Parent = parent
	return spawn
end

function WorldBuilder.Build()
	local workspace = game:GetService("Workspace")

	local existingWalls = workspace:FindFirstChild("Walls")
	if existingWalls then
		existingWalls:Destroy()
	end

	local existingBases = workspace:FindFirstChild("Bases")
	if existingBases then
		existingBases:Destroy()
	end

	local existingGround = workspace:FindFirstChild("Ground")
	if existingGround then
		existingGround:Destroy()
	end

	local baseplate = workspace:FindFirstChild("Baseplate")
	if baseplate and baseplate:IsA("BasePart") then
		baseplate.Transparency = 1
		baseplate.CanCollide = false
	end

	local wallFolder = Instance.new("Folder")
	wallFolder.Name = "Walls"
	wallFolder.Parent = workspace

	local baseFolder = Instance.new("Folder")
	baseFolder.Name = "Bases"
	baseFolder.Parent = workspace

	local groundSize = Vector3.new(
		Config.WallsPerRow * (Config.WallWidth + Config.WallGap) + 80,
		1,
		Config.WallRows * (Config.WallHeight + Config.WallGap) + 80
	)
	local ground = Instance.new("Part")
	ground.Name = "Ground"
	ground.Size = groundSize
	ground.Position = Vector3.new(0, -3, 0)
	ground.Anchored = true
	ground.TopSurface = Enum.SurfaceType.Smooth
	ground.BottomSurface = Enum.SurfaceType.Smooth
	ground.BrickColor = BrickColor.new("Light stone grey")
	ground.Material = Enum.Material.SmoothPlastic
	ground.Parent = workspace

	local wallIndex = 1
	for row = 1, Config.WallRows do
		for col = 1, Config.WallsPerRow do
			local x = (col - 1) * (Config.WallWidth + Config.WallGap) - ((Config.WallsPerRow - 1) * (Config.WallWidth + Config.WallGap)) / 2
			local z = (row - 1) * (Config.WallHeight + Config.WallGap) - ((Config.WallRows - 1) * (Config.WallHeight + Config.WallGap)) / 2
			local wallSize = Vector3.new(Config.WallWidth, Config.WallHeight, Config.WallThickness)
			local wallPos = Vector3.new(x, Config.WallHeight / 2, z)
			makeWall(wallPos, wallSize, "Wall_" .. wallIndex, wallFolder)
			wallIndex = wallIndex + 1
		end
	end

	local spawnPositions = {
		Vector3.new(-Config.TeamSpawnSpacing, 0, -Config.TeamSpawnSpacing),
		Vector3.new( Config.TeamSpawnSpacing, 0, -Config.TeamSpawnSpacing),
		Vector3.new(-Config.TeamSpawnSpacing, 0,  Config.TeamSpawnSpacing),
		Vector3.new( Config.TeamSpawnSpacing, 0,  Config.TeamSpawnSpacing),
	}

	for i, pos in ipairs(spawnPositions) do
		local color = Config.PaintColors[i] or Config.PaintColors[1]
		makeBasePad(pos + Vector3.new(0, 0.5, 0), color, i, baseFolder)
		makeSpawn(pos + Vector3.new(0, 1.5, 0), i, baseFolder)
	end

	-- Waiting room (elevated platform above the arena)
	local existingLobby = workspace:FindFirstChild("Lobby")
	if existingLobby then
		existingLobby:Destroy()
	end

	local lobbyFolder = Instance.new("Folder")
	lobbyFolder.Name = "Lobby"
	lobbyFolder.Parent = workspace

	local LOBBY_Y = 80
	local LOBBY_SIZE = Vector3.new(60, 2, 60)

	-- Main lobby floor
	local lobbyFloor = Instance.new("Part")
	lobbyFloor.Name = "LobbyFloor"
	lobbyFloor.Size = LOBBY_SIZE
	lobbyFloor.Position = Vector3.new(0, LOBBY_Y, 0)
	lobbyFloor.Anchored = true
	lobbyFloor.TopSurface = Enum.SurfaceType.Smooth
	lobbyFloor.BottomSurface = Enum.SurfaceType.Smooth
	lobbyFloor.Color = Color3.fromRGB(60, 60, 80)
	lobbyFloor.Material = Enum.Material.SmoothPlastic
	lobbyFloor.Parent = lobbyFolder

	-- Invisible walls around the lobby so players don't fall off
	for _, wallData in ipairs({
		{ pos = Vector3.new(0, LOBBY_Y + 5, LOBBY_SIZE.Z / 2), size = Vector3.new(LOBBY_SIZE.X, 10, 1) },
		{ pos = Vector3.new(0, LOBBY_Y + 5, -LOBBY_SIZE.Z / 2), size = Vector3.new(LOBBY_SIZE.X, 10, 1) },
		{ pos = Vector3.new(LOBBY_SIZE.X / 2, LOBBY_Y + 5, 0), size = Vector3.new(1, 10, LOBBY_SIZE.Z) },
		{ pos = Vector3.new(-LOBBY_SIZE.X / 2, LOBBY_Y + 5, 0), size = Vector3.new(1, 10, LOBBY_SIZE.Z) },
	}) do
		local barrier = Instance.new("Part")
		barrier.Name = "LobbyBarrier"
		barrier.Size = wallData.size
		barrier.Position = wallData.pos
		barrier.Anchored = true
		barrier.Transparency = 1
		barrier.CanCollide = true
		barrier.Parent = lobbyFolder
	end

	-- Portal pad (glowing pad players walk onto to signal ready)
	local portal = Instance.new("Part")
	portal.Name = "PortalPad"
	portal.Size = Vector3.new(10, 1, 10)
	portal.Position = Vector3.new(0, LOBBY_Y + 1, 20)
	portal.Anchored = true
	portal.TopSurface = Enum.SurfaceType.Smooth
	portal.BottomSurface = Enum.SurfaceType.Smooth
	portal.Color = Color3.fromRGB(100, 200, 255)
	portal.Material = Enum.Material.Neon
	portal.Transparency = 0.2
	portal.Parent = lobbyFolder

	-- Portal label (billboard)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "PortalLabel"
	billboard.Size = UDim2.new(0, 200, 0, 50)
	billboard.StudsOffset = Vector3.new(0, 5, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = portal

	local portalText = Instance.new("TextLabel")
	portalText.Name = "Label"
	portalText.Size = UDim2.new(1, 0, 1, 0)
	portalText.BackgroundTransparency = 1
	portalText.TextColor3 = Color3.fromRGB(100, 220, 255)
	portalText.Font = Enum.Font.GothamBold
	portalText.TextSize = 22
	portalText.TextStrokeTransparency = 0.5
	portalText.Text = "Step here to play!"
	portalText.Parent = billboard

	-- Lobby spawn (where players appear when in waiting room)
	local lobbySpawn = Instance.new("SpawnLocation")
	lobbySpawn.Name = "LobbySpawn"
	lobbySpawn.Size = Vector3.new(8, 1, 8)
	lobbySpawn.Position = Vector3.new(0, LOBBY_Y + 1, -10)
	lobbySpawn.Anchored = true
	lobbySpawn.Neutral = true
	lobbySpawn.Duration = 0
	lobbySpawn.Transparency = 1
	lobbySpawn.Parent = lobbyFolder

	return wallFolder, baseFolder
end

return WorldBuilder
