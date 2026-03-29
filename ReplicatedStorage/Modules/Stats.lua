local Config = require(script.Parent.Config)

local Stats = {}

function Stats.GetDefaultProfile()
	return {
		Level = Config.BASE_LEVEL,
		Power = Config.BASE_POWER,
		Soldiers = Config.BASE_SOLDIERS,
		Coins = 0,
		CurrentWeapon = "Basic",
		OwnedWeapons = {"Basic"},
		OwnedCannons = {"Basic"},
	}
end

function Stats.SanitizeProfile(data)
	local profile = Stats.GetDefaultProfile()
	if type(data) ~= "table" then
		return profile
	end

	profile.Level = tonumber(data.Level) or profile.Level
	profile.Power = math.max(0, tonumber(data.Power) or profile.Power)
	profile.Soldiers = math.max(1, tonumber(data.Soldiers) or profile.Soldiers)
	profile.Coins = math.max(0, tonumber(data.Coins) or profile.Coins)
	profile.CurrentWeapon = tostring(data.CurrentWeapon or profile.CurrentWeapon)

	if type(data.OwnedWeapons) == "table" then
		profile.OwnedWeapons = {}
		for _, weaponId in ipairs(data.OwnedWeapons) do
			if type(weaponId) == "string" then
				table.insert(profile.OwnedWeapons, weaponId)
			end
		end
		if #profile.OwnedWeapons == 0 then
			profile.OwnedWeapons = {"Basic"}
		end
	end

	if type(data.OwnedCannons) == "table" then
		profile.OwnedCannons = {}
		for _, cannonId in ipairs(data.OwnedCannons) do
			if type(cannonId) == "string" then
				table.insert(profile.OwnedCannons, cannonId)
			end
		end
		if #profile.OwnedCannons == 0 then
			profile.OwnedCannons = {"Basic"}
		end
	end

	return profile
end

function Stats.ToAttributes(player, profile)
	player:SetAttribute("Level", profile.Level)
	player:SetAttribute("Power", profile.Power)
	player:SetAttribute("Soldiers", profile.Soldiers)
	player:SetAttribute("Coins", profile.Coins)
	player:SetAttribute("CurrentWeapon", profile.CurrentWeapon)
end

function Stats.FromAttributes(player)
	return {
		Level = player:GetAttribute("Level") or Config.BASE_LEVEL,
		Power = player:GetAttribute("Power") or Config.BASE_POWER,
		Soldiers = player:GetAttribute("Soldiers") or Config.BASE_SOLDIERS,
		Coins = player:GetAttribute("Coins") or 0,
		CurrentWeapon = player:GetAttribute("CurrentWeapon") or "Basic",
	}
end

return Stats
