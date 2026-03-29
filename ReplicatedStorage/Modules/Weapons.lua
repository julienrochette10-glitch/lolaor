local Weapons = {}

Weapons.Definitions = {
	Basic = {
		Id = "Basic",
		DisplayName = "Arme basique",
		Damage = 8,
		FireRate = 1,
		Color = Color3.fromRGB(210, 210, 210),
	},
	Fast = {
		Id = "Fast",
		DisplayName = "Arme rapide",
		Damage = 5,
		FireRate = 2,
		Color = Color3.fromRGB(95, 205, 255),
	},
	Heavy = {
		Id = "Heavy",
		DisplayName = "Arme lourde",
		Damage = 16,
		FireRate = 0.7,
		Color = Color3.fromRGB(255, 155, 85),
	},
	Explosive = {
		Id = "Explosive",
		DisplayName = "Arme explosive",
		Damage = 12,
		FireRate = 0.8,
		SplashRadius = 8,
		Color = Color3.fromRGB(255, 80, 80),
	},
	Special = {
		Id = "Special",
		DisplayName = "Arme spéciale",
		Damage = 22,
		FireRate = 0.5,
		Color = Color3.fromRGB(180, 95, 255),
	},
}

function Weapons.GetWeapon(id)
	return Weapons.Definitions[id] or Weapons.Definitions.Basic
end

function Weapons.GetAll()
	local all = {}
	for _, definition in pairs(Weapons.Definitions) do
		table.insert(all, definition)
	end
	table.sort(all, function(a, b)
		return a.DisplayName < b.DisplayName
	end)
	return all
end

return Weapons
