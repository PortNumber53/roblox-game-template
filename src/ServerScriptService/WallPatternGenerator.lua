-- WallPatternGenerator: produces unique wall layouts for each game session
--
-- Each pattern is a 2D grid where each cell is one of:
--   "open"    — paintable by players
--   "blocked" — solid obstacle, cannot be painted
--   "bonus"   — paintable and worth double points
--
-- The generator picks a random base pattern, then applies random transforms
-- (mirror, rotate, scatter) so sessions rarely feel the same.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))

local WallPatternGenerator = {}

local ROWS = GameConfig.WALL_GRID_ROWS
local COLS = GameConfig.WALL_GRID_COLS

local CellType = {
	Open = "open",
	Blocked = "blocked",
	Bonus = "bonus",
}
WallPatternGenerator.CellType = CellType

--------------------------------------------------
-- Helper: create an empty grid filled with a value
--------------------------------------------------

local function makeGrid(rows, cols, fillValue)
	local g = {}
	for r = 1, rows do
		g[r] = {}
		for c = 1, cols do
			g[r][c] = fillValue
		end
	end
	return g
end

--------------------------------------------------
-- Base pattern generators
--------------------------------------------------

-- 1. Columns: vertical pillars of blocked cells
local function patternColumns(grid)
	local spacing = math.random(3, 5)
	local pillarWidth = math.random(1, 2)
	for c = spacing, COLS, spacing do
		for w = 0, pillarWidth - 1 do
			if c + w <= COLS then
				for r = 1, ROWS do
					grid[r][c + w] = CellType.Blocked
				end
			end
		end
	end
end

-- 2. Maze-like: random horizontal and vertical walls with gaps
local function patternMaze(grid)
	-- Horizontal walls
	for r = 3, ROWS - 2, math.random(2, 4) do
		local gapStart = math.random(1, COLS - 3)
		local gapLen = math.random(2, 4)
		for c = 1, COLS do
			if c < gapStart or c > gapStart + gapLen then
				grid[r][c] = CellType.Blocked
			end
		end
	end
	-- Vertical walls
	for c = 4, COLS - 3, math.random(3, 5) do
		local gapStart = math.random(1, ROWS - 2)
		local gapLen = math.random(2, 3)
		for r = 1, ROWS do
			if r < gapStart or r > gapStart + gapLen then
				grid[r][c] = CellType.Blocked
			end
		end
	end
end

-- 3. Diamond: a large diamond shape of open cells surrounded by blocked
local function patternDiamond(grid)
	local centerR = math.ceil(ROWS / 2)
	local centerC = math.ceil(COLS / 2)
	local radiusR = math.floor(ROWS / 2) - 1
	local radiusC = math.floor(COLS / 2) - 1

	for r = 1, ROWS do
		for c = 1, COLS do
			local distR = math.abs(r - centerR) / radiusR
			local distC = math.abs(c - centerC) / radiusC
			if distR + distC > 1 then
				grid[r][c] = CellType.Blocked
			end
		end
	end
end

-- 4. Islands: scattered rectangular blocked regions
local function patternIslands(grid)
	local numIslands = math.random(4, 8)
	for _ = 1, numIslands do
		local iw = math.random(1, 3)
		local ih = math.random(1, 3)
		local sr = math.random(2, ROWS - ih)
		local sc = math.random(2, COLS - iw)
		for r = sr, math.min(sr + ih - 1, ROWS) do
			for c = sc, math.min(sc + iw - 1, COLS) do
				grid[r][c] = CellType.Blocked
			end
		end
	end
end

-- 5. Stripes: alternating horizontal bands of open and blocked
local function patternStripes(grid)
	local bandHeight = math.random(2, 3)
	local blocked = false
	for r = 1, ROWS do
		if (math.floor((r - 1) / bandHeight)) % 2 == 1 then
			-- Leave gaps so players can still reach open rows
			local gapStart = math.random(1, math.max(1, COLS - 4))
			local gapLen = math.random(3, 5)
			for c = 1, COLS do
				if c < gapStart or c > gapStart + gapLen then
					grid[r][c] = CellType.Blocked
				end
			end
		end
	end
end

-- 6. Checkerboard: alternating 2x2 blocks
local function patternCheckerboard(grid)
	local blockSize = math.random(2, 3)
	for r = 1, ROWS do
		for c = 1, COLS do
			local br = math.floor((r - 1) / blockSize)
			local bc = math.floor((c - 1) / blockSize)
			if (br + bc) % 2 == 1 then
				grid[r][c] = CellType.Blocked
			end
		end
	end
end

-- 7. Border arena: blocked border with open interior
local function patternArena(grid)
	local thickness = math.random(1, 2)
	for r = 1, ROWS do
		for c = 1, COLS do
			if r <= thickness or r > ROWS - thickness or c <= thickness or c > COLS - thickness then
				grid[r][c] = CellType.Blocked
			end
		end
	end
	-- Add a few internal pillars
	for _ = 1, math.random(2, 5) do
		local pr = math.random(thickness + 2, ROWS - thickness - 1)
		local pc = math.random(thickness + 2, COLS - thickness - 1)
		grid[pr][pc] = CellType.Blocked
	end
end

-- 8. Spiral path: a rough spiral of open cells in a blocked field
local function patternSpiral(grid)
	-- Fill with blocked, then carve a spiral path
	for r = 1, ROWS do
		for c = 1, COLS do
			grid[r][c] = CellType.Blocked
		end
	end

	local top, bottom, left, right = 1, ROWS, 1, COLS
	local pathWidth = 2

	while top <= bottom and left <= right do
		-- Carve top row
		for c = left, right do
			for w = 0, pathWidth - 1 do
				if top + w <= ROWS then
					grid[top + w][c] = CellType.Open
				end
			end
		end
		top = top + pathWidth + 1

		-- Carve right column
		for r = top, bottom do
			for w = 0, pathWidth - 1 do
				if right - w >= 1 then
					grid[r][right - w] = CellType.Open
				end
			end
		end
		right = right - pathWidth - 1

		-- Carve bottom row
		if top <= bottom then
			for c = right, left, -1 do
				for w = 0, pathWidth - 1 do
					if bottom - w >= 1 then
						grid[bottom - w][c] = CellType.Open
					end
				end
			end
			bottom = bottom - pathWidth - 1
		end

		-- Carve left column
		if left <= right then
			for r = bottom, top, -1 do
				for w = 0, pathWidth - 1 do
					if left + w <= COLS then
						grid[r][left + w] = CellType.Open
					end
				end
			end
			left = left + pathWidth + 1
		end
	end
end

--------------------------------------------------
-- Transforms applied after base pattern
--------------------------------------------------

local function mirrorHorizontal(grid)
	for r = 1, ROWS do
		for c = 1, math.floor(COLS / 2) do
			grid[r][COLS - c + 1] = grid[r][c]
		end
	end
end

local function mirrorVertical(grid)
	for r = 1, math.floor(ROWS / 2) do
		for c = 1, COLS do
			grid[ROWS - r + 1][c] = grid[r][c]
		end
	end
end

local function scatterBonusCells(grid, count)
	local openCells = {}
	for r = 1, ROWS do
		for c = 1, COLS do
			if grid[r][c] == CellType.Open then
				table.insert(openCells, { r, c })
			end
		end
	end

	-- Shuffle and pick up to `count`
	for i = #openCells, 2, -1 do
		local j = math.random(1, i)
		openCells[i], openCells[j] = openCells[j], openCells[i]
	end

	for i = 1, math.min(count, #openCells) do
		local cell = openCells[i]
		grid[cell[1]][cell[2]] = CellType.Bonus
	end
end

--------------------------------------------------
-- Ensure the pattern is playable (enough open cells)
--------------------------------------------------

local function countOpen(grid)
	local n = 0
	for r = 1, ROWS do
		for c = 1, COLS do
			if grid[r][c] ~= CellType.Blocked then
				n = n + 1
			end
		end
	end
	return n
end

local function ensureMinimumOpen(grid, minFraction)
	local total = ROWS * COLS
	local needed = math.floor(total * minFraction)
	local current = countOpen(grid)

	if current >= needed then
		return
	end

	-- Randomly open blocked cells until we have enough
	local blockedCells = {}
	for r = 1, ROWS do
		for c = 1, COLS do
			if grid[r][c] == CellType.Blocked then
				table.insert(blockedCells, { r, c })
			end
		end
	end

	for i = #blockedCells, 2, -1 do
		local j = math.random(1, i)
		blockedCells[i], blockedCells[j] = blockedCells[j], blockedCells[i]
	end

	local toOpen = needed - current
	for i = 1, math.min(toOpen, #blockedCells) do
		local cell = blockedCells[i]
		grid[cell[1]][cell[2]] = CellType.Open
	end
end

--------------------------------------------------
-- Public API
--------------------------------------------------

local patternFunctions = {
	patternColumns,
	patternMaze,
	patternDiamond,
	patternIslands,
	patternStripes,
	patternCheckerboard,
	patternArena,
	patternSpiral,
}

--- Generate a new random wall pattern.
--- Returns the grid and the pattern name (for logging/display).
function WallPatternGenerator.Generate(): ({ [number]: { [number]: string } }, string)
	local grid = makeGrid(ROWS, COLS, CellType.Open)

	-- Pick a random base pattern
	local index = math.random(1, #patternFunctions)
	local patternNames = {
		"Columns", "Maze", "Diamond", "Islands",
		"Stripes", "Checkerboard", "Arena", "Spiral",
	}

	patternFunctions[index](grid)

	-- Random chance to apply symmetry transforms
	if math.random() > 0.5 then
		mirrorHorizontal(grid)
	end
	if math.random() > 0.7 then
		mirrorVertical(grid)
	end

	-- Ensure at least 40% of cells are playable
	ensureMinimumOpen(grid, 0.4)

	-- Scatter bonus cells (5-15% of open cells)
	local openCount = countOpen(grid)
	local bonusCount = math.random(
		math.floor(openCount * 0.05),
		math.floor(openCount * 0.15)
	)
	scatterBonusCells(grid, bonusCount)

	local patternName = patternNames[index]
	print("[WallPatternGenerator] Generated pattern: " .. patternName)

	return grid, patternName
end

return WallPatternGenerator
