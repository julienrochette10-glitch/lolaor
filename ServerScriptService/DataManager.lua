local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Stats = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Stats"))

local profileStore = DataStoreService:GetDataStore("ProgressionSoldierProfile_v1")

local DataManager = {}
DataManager.Profiles = {}

local function getKey(player)
	return "player_" .. player.UserId
end

function DataManager:LoadProfile(player)
	local profile = Stats.GetDefaultProfile()
	local success, result = pcall(function()
		return profileStore:GetAsync(getKey(player))
	end)

	if success and result then
		profile = Stats.SanitizeProfile(result)
	end

	self.Profiles[player] = profile
	return profile
end

function DataManager:GetProfile(player)
	return self.Profiles[player]
end

function DataManager:SetProfile(player, profile)
	self.Profiles[player] = Stats.SanitizeProfile(profile)
end

function DataManager:SaveProfile(player)
	local profile = self.Profiles[player]
	if not profile then
		return
	end

	local success, err = pcall(function()
		profileStore:UpdateAsync(getKey(player), function()
			return profile
		end)
	end)

	if not success then
		warn("[DataManager] Save failed for", player.Name, err)
	end
end

function DataManager:UpdateFromAttributes(player)
	local profile = self.Profiles[player]
	if not profile then
		return
	end

	profile.Level = player:GetAttribute("Level") or profile.Level
	profile.Power = player:GetAttribute("Power") or profile.Power
	profile.Soldiers = player:GetAttribute("Soldiers") or profile.Soldiers
	profile.Coins = player:GetAttribute("Coins") or profile.Coins
	profile.CurrentWeapon = player:GetAttribute("CurrentWeapon") or profile.CurrentWeapon
end

Players.PlayerRemoving:Connect(function(player)
	DataManager:UpdateFromAttributes(player)
	DataManager:SaveProfile(player)
	DataManager.Profiles[player] = nil
end)

game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		DataManager:UpdateFromAttributes(player)
		DataManager:SaveProfile(player)
	end
end)

return DataManager
