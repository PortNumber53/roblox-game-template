-- WallPaintingService: manages the grid of paintable wall cells during a game session

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))

local WallPaintingService = {}

-- Grid state: [row][col] = userId or nil (unpainted)
local grid = {}

--------------------------------------------------
-- Public API
--------------------------------------------------

function WallPaintingService.ResetWalls()
	grid = {}
	for r = 1, GameConfig.WALL_GRID_ROWS do
		grid[r] = {}
		for c = 1, GameConfig.WALL_GRID_COLS do
			grid[r][c] = nil
		end
	end
end

--- Attempt to paint a cell. Returns true if the cell was unpainted and is now claimed.
function WallPaintingService.PaintCell(player, row: number, col: number): boolean
	-- Validate bounds
	if row < 1 or row > GameConfig.WALL_GRID_ROWS then
		return false
	end
	if col < 1 or col > GameConfig.WALL_GRID_COLS then
		return false
	end

	-- Row may not exist yet if grid was not reset (safety check)
	if not grid[row] then
		return false
	end

	-- Only allow painting unpainted cells
	if grid[row][col] ~= nil then
		return false
	end

	grid[row][col] = player.UserId
	return true
end

function WallPaintingService.GetGrid()
	return grid
end

function WallPaintingService.GetCellOwner(row: number, col: number)
	if grid[row] then
		return grid[row][col]
	end
	return nil
end

return WallPaintingService
