local Config = {}

Config.BaseMoveSpeed = 16
Config.BaseJumpPower = 50
Config.BaseCharacterScale = 1
Config.MoveSpeedCap = 34
Config.SizePerPaintUnit = 0.008
Config.SizeCapBase = 3
Config.PaintCapacityBase = 120
Config.PaintPerBrushTick = 2
Config.PaintTilesPerCoin = 8
Config.PaintSplashTileBudget = 6
Config.PaintSplashCoverage = 0.18
Config.PaintSplashJitter = 0.35
Config.BrushRadiusBase = 7
Config.BrushCooldownBase = 0.18
Config.RefillRatePerTick = 12
Config.RefillTickSeconds = 0.1
Config.Milestones = {
	{ size = 1.5, reward = 25 },
	{ size = 2, reward = 50 },
	{ size = 2.5, reward = 75 },
	{ size = 3, reward = 100 },
	{ size = 4, reward = 150 },
	{ size = 5, reward = 250 },
}
Config.PaintColors = {
	Color3.fromRGB(255, 96, 96),
	Color3.fromRGB(96, 170, 255),
	Color3.fromRGB(125, 255, 153),
	Color3.fromRGB(255, 215, 120),
	Color3.fromRGB(215, 140, 255),
}
Config.TeamSpawnSpacing = 70
Config.WallRows = 3
Config.WallsPerRow = 4
Config.WallWidth = 36
Config.WallHeight = 18
Config.WallThickness = 2
Config.WallGap = 8
Config.WallTileSize = 0.75
Config.UpgradeStepValues = {
	MaxSize = 0.45,
	SizeMultiplier = 0.2,
	BrushSize = 1.75,
	BrushSpeed = 0.015,
	BucketCapacity = 25,
	MoveSpeed = 2,
}

return Config
