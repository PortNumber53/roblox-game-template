-- LeaderboardService: tracks session results with DataStore persistence
-- Allows multiple entries per player

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local LeaderboardService = {}

local MAX_ENTRIES = GameConfig.LEADERBOARD_MAX_ENTRIES
local STORE_KEY = "SessionHistory_v1"

local PERSISTENCE_ENABLED = not RunService:IsStudio() or Config.EnableStudioPersistence

local leaderboardStore = nil
if PERSISTENCE_ENABLED then
	local ok, store = pcall(function()
		return DataStoreService:GetDataStore("LeaderboardData")
	end)
	if ok then
		leaderboardStore = store
	else
		warn("[LeaderboardService] Failed to get DataStore: " .. tostring(store))
	end
end

-- All session results: { { Name, UserId, Score, Timestamp }, ... }
local sessionHistory = {}

-- Per-player running totals for the current session
local currentSessionPainted = {}

--------------------------------------------------
-- Persistence helpers
--------------------------------------------------

local function loadHistory()
	if not leaderboardStore then return end

	local success, data = pcall(function()
		return leaderboardStore:GetAsync(STORE_KEY)
	end)

	if success and typeof(data) == "table" then
		sessionHistory = data
		-- Cap to max entries (keep highest scores)
		if #sessionHistory > MAX_ENTRIES then
			table.sort(sessionHistory, function(a, b)
				return a.Score > b.Score
			end)
			local trimmed = {}
			for i = 1, MAX_ENTRIES do
				trimmed[i] = sessionHistory[i]
			end
			sessionHistory = trimmed
		end
		print("[LeaderboardService] Loaded " .. #sessionHistory .. " entries from DataStore")
	end
end

local function saveHistory()
	if not leaderboardStore then
		warn("[LeaderboardService] No DataStore available, skipping save")
		return
	end

	if #sessionHistory == 0 then
		print("[LeaderboardService] No entries to save")
		return
	end

	-- Only persist top entries to stay within DataStore size limits
	local toSave = {}
	local sorted = {}
	for _, entry in ipairs(sessionHistory) do
		table.insert(sorted, entry)
	end
	table.sort(sorted, function(a, b)
		return a.Score > b.Score
	end)
	for i = 1, math.min(#sorted, MAX_ENTRIES) do
		table.insert(toSave, {
			Name = sorted[i].Name,
			UserId = sorted[i].UserId,
			Score = sorted[i].Score,
			Timestamp = sorted[i].Timestamp,
		})
	end

	print("[LeaderboardService] Saving " .. #toSave .. " entries to DataStore...")
	local success, err = pcall(function()
		leaderboardStore:SetAsync(STORE_KEY, toSave)
	end)
	if success then
		print("[LeaderboardService] Save successful")
	else
		warn("[LeaderboardService] Save failed: " .. tostring(err))
	end
end

--------------------------------------------------
-- Query helpers
--------------------------------------------------

local function getPlayerName(player)
	return player.DisplayName or player.Name or "Player"
end

local function getSortedByScore()
	local sorted = {}
	for _, entry in ipairs(sessionHistory) do
		table.insert(sorted, entry)
	end
	table.sort(sorted, function(a, b)
		return a.Score > b.Score
	end)
	local results = {}
	for i = 1, math.min(#sorted, MAX_ENTRIES) do
		table.insert(results, {
			Rank = i,
			Name = sorted[i].Name,
			UserId = sorted[i].UserId,
			Value = sorted[i].Score,
		})
	end
	return results
end

local function getBestSessions()
	return getSortedByScore()
end

--------------------------------------------------
-- Public API
--------------------------------------------------

function LeaderboardService.Init()
	loadHistory()
end

function LeaderboardService.LoadPlayer(player)
	currentSessionPainted[player.UserId] = 0
end

function LeaderboardService.UnloadPlayer(player)
	currentSessionPainted[player.UserId] = nil
end

function LeaderboardService.SavePlayer(player)
	-- Handled by saveHistory at session end
end

function LeaderboardService.RecordWallPainted(player)
	currentSessionPainted[player.UserId] = (currentSessionPainted[player.UserId] or 0) + 1
end

function LeaderboardService.RecordSessionEnd(player, wallsPaintedThisSession)
	if wallsPaintedThisSession <= 0 then return end

	table.insert(sessionHistory, {
		Name = getPlayerName(player),
		UserId = player.UserId,
		Score = wallsPaintedThisSession,
		Timestamp = os.time(),
	})

	currentSessionPainted[player.UserId] = 0
end

function LeaderboardService.Save()
	saveHistory()
end

function LeaderboardService.GetPlayerStats(player)
	local totalPainted = 0
	local bestSession = 0
	local sessionCount = 0

	for _, entry in ipairs(sessionHistory) do
		if entry.UserId == player.UserId then
			totalPainted = totalPainted + entry.Score
			sessionCount = sessionCount + 1
			if entry.Score > bestSession then
				bestSession = entry.Score
			end
		end
	end

	return {
		overall = totalPainted,
		bestSession = bestSession,
		sessions = sessionCount,
	}
end

function LeaderboardService.GetOverallLeaderboard()
	return getSortedByScore()
end

function LeaderboardService.GetSessionLeaderboard()
	return getBestSessions()
end

return LeaderboardService
