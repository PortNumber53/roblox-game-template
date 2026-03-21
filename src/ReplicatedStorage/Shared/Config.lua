local Config = {}

Config.EnableStudioPersistence = true
Config.BaseMoveSpeed = 16
Config.BaseJumpPower = 50
Config.MoveSpeedCap = 34
Config.PaintCapacityBase = 120
Config.PaintPerBrushTick = 2
Config.PaintTilesPerCoin = 8
Config.PaintSplashTileBudget = 6
Config.PaintSplashCoverage = 0.18
Config.PaintSplashJitter = 0.35
Config.RefillRatePerTick = 12
Config.RefillTickSeconds = 0.1

-- Weapon defaults
Config.SplashRadiusBase = 7
Config.FireRateBase = 0.18
Config.ProjectileRangeBase = 150
Config.ProjectileSpeed = 200
Config.ProjectileSize = 0.4

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
	SplashRadius = 1.75,
	FireRate = 0.015,
	AmmoCapacity = 25,
	MoveSpeed = 2,
	Range = 15,
	ReloadSpeed = 8,
}

return Config
