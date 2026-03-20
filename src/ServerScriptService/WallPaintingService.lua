-- WallPaintingService: manages the grid of paintable wall cells during a game session
-- Now integrates with WallPatternGenerator for unique layouts each session.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))
local WallPatternGenerator = require(script.Parent:WaitForChild("WallPatternGenerator"))

local CellType = WallPatternGenerator.CellType

local WallPaintingService = {}

-- Grid state: [row][col] = userId or nil (unpainted)
local grid = {}
-- Layout: [row][col] = CellType ("open" | "blocked" | "bonus")
local layout = {}
-- Current pattern name (for display)
local currentPatternName = ""

--------------------------------------------------
-- Public API
--------------------------------------------------

function WallPaintingService.ResetWalls()
	-- Generate a fresh random layout
	layout, currentPatternName = WallPatternGenerator.Generate()

	-- Initialize the paint grid — only open/bonus cells are paintable
	grid = {}
	for r = 1, GameConfig.WALL_GRID_ROWS do
		grid[r] = {}
		for c = 1, GameConfig.WALL_GRID_COLS do
			grid[r][c] = nil -- nil means unpainted (blocked cells simply can't be painted)
		end
	end
end

--- Attempt to paint a cell. Returns points earned (0 if failed).
function WallPaintingService.PaintCell(player, row: number, col: number): number
	-- Validate bounds
	if row < 1 or row > GameConfig.WALL_GRID_ROWS then
		return 0
	end
	if col < 1 or col > GameConfig.WALL_GRID_COLS then
		return 0
	end

	if not grid[row] or not layout[row] then
		return 0
	end

	-- Cannot paint blocked cells
	local cellType = layout[row][col]
	if cellType == CellType.Blocked then
		return 0
	end

	-- Only allow painting unpainted cells
	if grid[row][col] ~= nil then
		return 0
	end

	grid[row][col] = player.UserId

	-- Bonus cells are worth more
	if cellType == CellType.Bonus then
		return GameConfig.BONUS_CELL_MULTIPLIER
	end
	return 1
end

function WallPaintingService.GetGrid()
	return grid
end

function WallPaintingService.GetLayout()
	return layout
end

function WallPaintingService.GetPatternName()
	return currentPatternName
end

function WallPaintingService.GetCellOwner(row: number, col: number)
	if grid[row] then
		return grid[row][col]
	end
	return nil
end

function WallPaintingService.GetCellType(row: number, col: number): string
	return (layout[row] and layout[row][col]) or CellType.Open
end

return WallPaintingService
