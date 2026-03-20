-- LeaderboardService: persists and retrieves leaderboard data using DataStoreService
-- Tracks: most walls painted overall, most walls painted in a single session

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local LeaderboardService = {}

local overallStore = DataStoreService:GetOrderedDataStore("WallsPaintedOverall")
local sessionStore = DataStoreService:GetOrderedDataStore("WallsPaintedBestSession")

-- Local cache of player stats for fast access during gameplay
local playerStats = {} -- [userId] = { overall = number, bestSession = number }

local MAX_ENTRIES = 50

--------------------------------------------------
-- Internal helpers
--------------------------------------------------

local function safeGetAsync(store, key)
	local success, value = pcall(function()
		return store:GetAsync(key)
	end)
	if success then
		return value or 0
	end
	warn("[LeaderboardService] GetAsync failed for key " .. tostring(key))
	return 0
end

local function safeSetAsync(store, key, value)
	local success, err = pcall(function()
		store:SetAsync(key, value)
	end)
	if not success then
		warn("[LeaderboardService] SetAsync failed: " .. tostring(err))
	end
end

local function fetchTopEntries(store)
	local entries = {}
	local success, pages = pcall(function()
		return store:GetSortedAsync(false, MAX_ENTRIES)
	end)
	if not success or not pages then
		warn("[LeaderboardService] GetSortedAsync failed")
		return entries
	end

	local data = pages:GetCurrentPage()
	for rank, entry in ipairs(data) do
		-- Key is stored as the UserId string; resolve display name
		local userId = tonumber(entry.key)
		local displayName = "Player"
		if userId then
			local success2, name = pcall(function()
				return Players:GetNameFromUserIdAsync(userId)
			end)
			if success2 and name then
				displayName = name
			end
		end
		table.insert(entries, {
			Rank = rank,
			Name = displayName,
			UserId = userId,
			Value = entry.value,
		})
	end
	return entries
end

--------------------------------------------------
-- Public API
--------------------------------------------------

function LeaderboardService.LoadPlayer(player: Player)
	local key = tostring(player.UserId)
	local overall = safeGetAsync(overallStore, key)
	local bestSession = safeGetAsync(sessionStore, key)
	playerStats[player.UserId] = {
		overall = overall,
		bestSession = bestSession,
	}
end

function LeaderboardService.UnloadPlayer(player: Player)
	-- Save before clearing cache
	LeaderboardService.SavePlayer(player)
	playerStats[player.UserId] = nil
end

function LeaderboardService.SavePlayer(player: Player)
	local stats = playerStats[player.UserId]
	if not stats then
		return
	end
	local key = tostring(player.UserId)
	safeSetAsync(overallStore, key, stats.overall)
	safeSetAsync(sessionStore, key, stats.bestSession)
end

--- Call after each wall is painted during a game session.
function LeaderboardService.RecordWallPainted(player: Player)
	local stats = playerStats[player.UserId]
	if not stats then
		return
	end
	stats.overall = stats.overall + 1
end

--- Call at the end of a game session with the number of walls the player painted.
function LeaderboardService.RecordSessionEnd(player: Player, wallsPaintedThisSession: number)
	local stats = playerStats[player.UserId]
	if not stats then
		return
	end
	if wallsPaintedThisSession > stats.bestSession then
		stats.bestSession = wallsPaintedThisSession
	end
	-- Persist immediately after session ends
	LeaderboardService.SavePlayer(player)
end

function LeaderboardService.GetPlayerStats(player: Player)
	return playerStats[player.UserId] or { overall = 0, bestSession = 0 }
end

function LeaderboardService.GetOverallLeaderboard()
	return fetchTopEntries(overallStore)
end

function LeaderboardService.GetSessionLeaderboard()
	return fetchTopEntries(sessionStore)
end

return LeaderboardService
