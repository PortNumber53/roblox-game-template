local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local Config = require(game.ReplicatedStorage.Shared.Config)

local PlayerDataStore = DataStoreService:GetDataStore("PlayerProgress_v1")

local DataService = {}

local SAVE_RETRIES = 3
local LOAD_RETRIES = 3
local STUDIO_PERSISTENCE_DISABLED = RunService:IsStudio() and not Config.EnableStudioPersistence
local hasWarnedStudioBypass = false

local function warnStudioBypass()
	if not STUDIO_PERSISTENCE_DISABLED or hasWarnedStudioBypass then
		return
	end

	hasWarnedStudioBypass = true
	warn("[DataService] Studio detected. Persistence is disabled because Config.EnableStudioPersistence is false.")
end

local function sanitizeNumber(value, default, minValue, maxValue)
	if typeof(value) ~= "number" then
		return default
	end

	value = math.floor(value)
	if minValue ~= nil then
		value = math.max(minValue, value)
	end
	if maxValue ~= nil then
		value = math.min(maxValue, value)
	end
	return value
end

function DataService.LoadPlayerData(userId)
	if STUDIO_PERSISTENCE_DISABLED then
		warnStudioBypass()
		return nil
	end

	local key = tostring(userId)

	for attempt = 1, LOAD_RETRIES do
		local success, data = pcall(function()
			return PlayerDataStore:GetAsync(key)
		end)

		if success then
			if typeof(data) ~= "table" then
				return nil
			end
			return data
		end

		warn(string.format("[DataService] Load failed for %s on attempt %d", key, attempt))
		task.wait(attempt)
	end

	return nil
end

function DataService.SavePlayerData(userId, data)
	if STUDIO_PERSISTENCE_DISABLED then
		warnStudioBypass()
		return true
	end

	if typeof(data) ~= "table" then
		return false
	end

	local key = tostring(userId)

	for attempt = 1, SAVE_RETRIES do
		local success = pcall(function()
			PlayerDataStore:SetAsync(key, data)
		end)

		if success then
			return true
		end

		warn(string.format("[DataService] Save failed for %s on attempt %d", key, attempt))
		task.wait(attempt)
	end

	return false
end

function DataService.SanitizePlayerData(data, upgradeDefinitions, config)
	if typeof(data) ~= "table" then
		return nil
	end

	local sanitized = {
		version = sanitizeNumber(data.version, 1, 1),
		coins = sanitizeNumber(data.coins, 0, 0),
		upgrades = {},
	}

	local sourceUpgrades = typeof(data.upgrades) == "table" and data.upgrades or {}

	-- Migrate v1 save data keys to v2 weapon terminology
	local MIGRATION_MAP = {
		BrushSize = "SplashRadius",
		BrushSpeed = "FireRate",
		BucketCapacity = "AmmoCapacity",
	}
	for oldKey, newKey in pairs(MIGRATION_MAP) do
		if sourceUpgrades[oldKey] and not sourceUpgrades[newKey] then
			sourceUpgrades[newKey] = sourceUpgrades[oldKey]
		end
	end

	for upgradeId, _ in pairs(upgradeDefinitions) do
		sanitized.upgrades[upgradeId] = sanitizeNumber(sourceUpgrades[upgradeId], 0, 0)
	end

	-- Sanitize drone data
	if typeof(data.drones) == "table" then
		sanitized.drones = {}
		for i = 1, math.min(#data.drones, config.DroneMaxCount or 3) do
			local d = data.drones[i]
			if typeof(d) == "table" then
				table.insert(sanitized.drones, {
					expiresAt = sanitizeNumber(d.expiresAt, 0, 0),
					speed = sanitizeNumber(d.speed, 0, 0),
					capacity = sanitizeNumber(d.capacity, 0, 0),
				})
			end
		end
	end

	return sanitized
end

return DataService
