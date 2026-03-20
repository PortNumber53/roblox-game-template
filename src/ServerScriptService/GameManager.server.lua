local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local PlayerStats = require(ReplicatedStorage.Shared.PlayerStats)
local WorldBuilder = require(script.Parent.WorldBuilder)
local PaintService = require(script.Parent.PaintService)
local GrowthService = require(script.Parent.GrowthService)
local UpgradeService = require(script.Parent.UpgradeService)
local RefillService = require(script.Parent.RefillService)
local DataService = require(script.Parent.DataService)

-- RemoteEvents
local remotes = ReplicatedStorage:FindFirstChild("Remotes")
if remotes then
	remotes:Destroy()
end

remotes = Instance.new("Folder")
remotes.Name = "Remotes"
remotes.Parent = ReplicatedStorage

local function makeRemote(name, isFunction)
	if isFunction then
		local rf = Instance.new("RemoteFunction")
		rf.Name = name
		rf.Parent = remotes
		return rf
	else
		local re = Instance.new("RemoteEvent")
		re.Name = name
		re.Parent = remotes
		return re
	end
end

local evPaint = makeRemote("Paint")
local evStatsSync = makeRemote("StatsSync")
local evMilestone = makeRemote("MilestoneReached")
local evFeedback = makeRemote("Feedback")
local rfBuyUpgrade = makeRemote("BuyUpgrade", true)

-- Build world
WorldBuilder.Build()

-- Per-player state
local playerStates = {}
local colorCounter = 0
local brushCooldowns = {}
local AUTOSAVE_INTERVAL = 60

local function assignColor()
	colorCounter = colorCounter + 1
	if colorCounter > #Config.PaintColors then
		colorCounter = 1
	end
	return colorCounter
end

local function syncStats(player, stats)
	evStatsSync:FireClient(player, stats:Serialize())
end

local function savePlayer(player)
	local stats = playerStates[player.UserId]
	if not stats then
		return
	end

	local saveData = stats:ToSaveData()
	DataService.SavePlayerData(player.UserId, saveData)
end

local function applyCharacterStats(character, stats)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = stats:GetMoveSpeed()
		humanoid.JumpPower = Config.BaseJumpPower
	end

	GrowthService.ApplyToCharacter(character, stats.size)
end

local function setupCharacter(player, character)
	local stats = playerStates[player.UserId]
	if not stats then
		local colorIndex = assignColor()
		stats = PlayerStats.new(colorIndex)
		playerStates[player.UserId] = stats
	end

	brushCooldowns[player.UserId] = 0

	local humanoid = character:WaitForChild("Humanoid", 10)
	if humanoid then
		applyCharacterStats(character, stats)
	end

	syncStats(player, stats)
end

local function setupPlayer(player)
	local colorIndex = assignColor()
	local stats = PlayerStats.new(colorIndex)
	local loadedData = DataService.LoadPlayerData(player.UserId)
	local sanitizedData = DataService.SanitizePlayerData(loadedData, require(ReplicatedStorage.Shared.UpgradeDefinitions), Config)
	if sanitizedData then
		stats:ApplySavedData(sanitizedData)
	end
	playerStates[player.UserId] = stats

	player.CharacterAdded:Connect(function(character)
		setupCharacter(player, character)
	end)

	if player.Character then
		task.defer(function()
			setupCharacter(player, player.Character)
		end)
	end
end

Players.PlayerAdded:Connect(setupPlayer)

for _, player in ipairs(Players:GetPlayers()) do
	setupPlayer(player)
end

Players.PlayerRemoving:Connect(function(player)
	savePlayer(player)
	playerStates[player.UserId] = nil
	brushCooldowns[player.UserId] = nil
end)

-- Paint remote: client fires with a world position and the targeted wall tile
evPaint.OnServerEvent:Connect(function(player, brushPosition, targetTile)
	local stats = playerStates[player.UserId]
	if not stats then return end

	local now = tick()
	local lastTime = brushCooldowns[player.UserId] or 0
	if now - lastTime < stats:GetBrushCooldown() then return end
	brushCooldowns[player.UserId] = now

	-- Validate position is near the character
	local character = player.Character
	if not character then return end
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return end
	if (rootPart.Position - brushPosition).Magnitude > 30 then return end

	local painted = PaintService.TryPaint(player, stats, brushPosition, targetTile)

	if painted > 0 then
		local coinsFromPaint = math.max(1, math.floor(painted / math.max(1, Config.PaintTilesPerCoin)))
		stats.coins = stats.coins + coinsFromPaint

		local changed = GrowthService.ApplyGrowth(stats, painted)
		if changed then
			applyCharacterStats(character, stats)
		end

		local coinsEarned = GrowthService.CheckMilestones(stats)
		if coinsEarned > 0 then
			evMilestone:FireClient(player, coinsEarned, stats.size)
		end
	end

	evFeedback:FireClient(player, "paint", stats.paint, stats.size)
	syncStats(player, stats)
end)

-- Upgrade purchase remote
rfBuyUpgrade.OnServerInvoke = function(player, upgradeId)
	local stats = playerStates[player.UserId]
	if not stats then return false, "No stats" end

	local success, msg = UpgradeService.TryPurchase(stats, upgradeId)
	if success then
		local character = player.Character
		if character then
			applyCharacterStats(character, stats)
		end
		syncStats(player, stats)
	end
	return success, msg
end

-- Refill loop: server polls every 0.1s
local refillAccum = 0
RunService.Heartbeat:Connect(function(dt)
	refillAccum = refillAccum + dt
	if refillAccum < Config.RefillTickSeconds then return end
	refillAccum = 0

	for _, player in ipairs(Players:GetPlayers()) do
		local stats = playerStates[player.UserId]
		if stats then
			local refilled = RefillService.TryRefill(player, stats)
			if refilled then
				syncStats(player, stats)
			end
		end
	end
end)

task.spawn(function()
	while true do
		task.wait(AUTOSAVE_INTERVAL)
		for _, player in ipairs(Players:GetPlayers()) do
			savePlayer(player)
		end
	end
end)

game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		savePlayer(player)
	end
end)
