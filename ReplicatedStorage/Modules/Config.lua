local Config = {}

Config.TOTAL_LEVELS = 10
Config.MAX_SOLDIERS = 200
Config.BASE_POWER = 5
Config.BASE_SOLDIERS = 1
Config.BASE_LEVEL = 1
Config.AUTO_DAMAGE_INTERVAL = 0.4
Config.AUTO_DAMAGE_RANGE = 35
Config.DOOR_BUFFS = {
	{Label = "+1 SOLDAT", Type = "Soldiers", Value = 1},
	{Label = "+2 SOLDATS", Type = "Soldiers", Value = 2},
	{Label = "+5 PUISSANCE", Type = "Power", Value = 5},
	{Label = "+10 PUISSANCE", Type = "Power", Value = 10},
}

Config.SHOP_ITEMS = {
	Power = {
		{Id = "power_small", Label = "+10 Puissance", Cost = 20, Type = "Power", Value = 10},
		{Id = "power_large", Label = "+30 Puissance", Cost = 50, Type = "Power", Value = 30},
	},
	Soldiers = {
		{Id = "soldier_small", Label = "+2 Soldats", Cost = 20, Type = "Soldiers", Value = 2},
		{Id = "soldier_large", Label = "+6 Soldats", Cost = 50, Type = "Soldiers", Value = 6},
	},
	Cannons = {
		{Id = "cannon_basic", Label = "Canon basique", Cost = 60, Type = "CannonUnlock", Value = "Basic"},
		{Id = "cannon_fast", Label = "Canon rapide", Cost = 100, Type = "CannonUnlock", Value = "Fast"},
	}
}

Config.ENEMY_SCALE_BY_LEVEL = {
	BaseCount = 8,
	CountPerLevel = 3,
	BaseHealth = 35,
	HealthPerLevel = 10,
	BaseBossHealth = 250,
	BossHealthPerLevel = 85,
	EnemyPowerPerLevel = 2,
}

return Config
