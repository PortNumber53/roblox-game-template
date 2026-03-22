-- DroneService: server-side drone load tracking and marketplace integration
-- Delivery is triggered by the client when the visual drone touches the player.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local Config = require(game.ReplicatedStorage.Shared.Config)
local DroneUpgradeDefinitions = require(game.ReplicatedStorage.Shared.DroneUpgradeDefinitions)

local DroneService = {}

-- Per-player per-drone load: droneLoads[userId][droneIndex] = paintAmount (0 = empty, >0 = carrying)
local droneLoads = {}

local playerStatesRef = nil
local syncStatsRef = nil
local savePlayerRef = nil

--------------------------------------------------
-- Load management
--------------------------------------------------

function DroneService.InitPlayer(userId)
	droneLoads[userId] = {}
end

function DroneService.CleanupPlayer(userId)
	droneLoads[userId] = nil
end

-- Called by client when drone reaches the refill pad
function DroneService.FillDrone(userId, droneIndex, stats)
	if not droneLoads[userId] then return end
	local drone = stats.drones[droneIndex]
	if not drone then return end
	local now = os.time()
	if not drone.expiresAt or drone.expiresAt <= now then return end

	droneLoads[userId][droneIndex] = stats:GetDroneDelivery(droneIndex)
end

-- Called by client when drone touches the player — returns true if paint was delivered
function DroneService.DeliverToPlayer(userId, droneIndex, stats)
	if not droneLoads[userId] then return false end

	local load = droneLoads[userId][droneIndex] or 0
	if load <= 0 then return false end

	local maxPaint = stats:GetMaxPaint()
	if stats.paint >= maxPaint then return false end

	stats.paint = math.min(maxPaint, stats.paint + load)
	droneLoads[userId][droneIndex] = 0
	return true
end

-- Get current load for serialization
function DroneService.GetDroneLoad(userId, droneIndex)
	if not droneLoads[userId] then return 0 end
	return droneLoads[userId][droneIndex] or 0
end

--------------------------------------------------
-- Drone purchase (Robux)
--------------------------------------------------

function DroneService.Init(playerStates, syncCallback, saveCallback)
	playerStatesRef = playerStates
	syncStatsRef = syncCallback
	savePlayerRef = saveCallback

	MarketplaceService.ProcessReceipt = function(receiptInfo)
		local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
		if not player then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end

		if receiptInfo.ProductId == Config.DroneProductId then
			local stats = playerStatesRef[player.UserId]
			if not stats then
				return Enum.ProductPurchaseDecision.NotProcessedYet
			end

			local slot = stats:AddDrone()
			if slot then
				print("[DroneService] Drone granted to " .. player.Name .. " in slot " .. slot)
				syncStatsRef(player, stats)
				savePlayerRef(player)
			end

			return Enum.ProductPurchaseDecision.PurchaseGranted
		end

		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
end

function DroneService.PromptPurchase(player)
	local stats = playerStatesRef and playerStatesRef[player.UserId]
	if not stats then return end

	if stats:GetActiveDroneCount() >= Config.DroneMaxCount then
		return
	end

	local RunService = game:GetService("RunService")
	if RunService:IsStudio() then
		local slot = stats:AddDrone()
		if slot then
			print("[DroneService] Studio: free drone granted in slot " .. slot)
			syncStatsRef(player, stats)
			savePlayerRef(player)
		end
		return
	end

	MarketplaceService:PromptProductPurchase(player, Config.DroneProductId)
end

--------------------------------------------------
-- Drone upgrades (coins)
--------------------------------------------------

function DroneService.TryUpgrade(player, droneIndex, upgradeId)
	local stats = playerStatesRef and playerStatesRef[player.UserId]
	if not stats then return false, "No stats" end

	local def = DroneUpgradeDefinitions[upgradeId]
	if not def then return false, "Unknown upgrade" end

	if typeof(droneIndex) ~= "number" then return false, "Invalid drone" end
	droneIndex = math.floor(droneIndex)

	local drone = stats.drones[droneIndex]
	if not drone then return false, "No drone in slot" end

	local now = os.time()
	if not drone.expiresAt or drone.expiresAt <= now then
		return false, "Drone expired"
	end

	local cost = stats:GetDroneUpgradeCost(droneIndex, upgradeId)
	if stats.coins < cost then return false, "Not enough coins" end

	stats.coins = stats.coins - cost

	if upgradeId == "DroneSpeed" then
		drone.speed = (drone.speed or 0) + 1
	elseif upgradeId == "DroneCapacity" then
		drone.capacity = (drone.capacity or 0) + 1
	end

	return true, "OK"
end

return DroneService
