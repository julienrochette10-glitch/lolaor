local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local RunService = game:GetService("RunService")

local DataManager = require(ServerScriptService:WaitForChild("DataManager"))
local Stats = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Stats"))
local Config = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Config"))
local Weapons = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Weapons"))

local remoteFolder = ReplicatedStorage:FindFirstChild("RemoteEvents")
if not remoteFolder then
	remoteFolder = Instance.new("Folder")
	remoteFolder.Name = "RemoteEvents"
	remoteFolder.Parent = ReplicatedStorage
end

local function ensureRemote(className, name)
	local remote = remoteFolder:FindFirstChild(name)
	if not remote then
		remote = Instance.new(className)
		remote.Name = name
		remote.Parent = remoteFolder
	end
	return remote
end

local RequestProfile = ensureRemote("RemoteFunction", "RequestProfile")
local StartChoice = ensureRemote("RemoteEvent", "StartChoice")
local StatsUpdate = ensureRemote("RemoteEvent", "StatsUpdate")
local Notification = ensureRemote("RemoteEvent", "Notification")
local ShopOpen = ensureRemote("RemoteEvent", "ShopOpen")
local PurchaseRequest = ensureRemote("RemoteEvent", "PurchaseRequest")
local EquipWeaponRequest = ensureRemote("RemoteEvent", "EquipWeaponRequest")
local PlaceCannonRequest = ensureRemote("RemoteEvent", "PlaceCannonRequest")

local soldiersFolder = workspace:FindFirstChild("SoldierUnits")
if not soldiersFolder then
	soldiersFolder = Instance.new("Folder")
	soldiersFolder.Name = "SoldierUnits"
	soldiersFolder.Parent = workspace
end

local playerSoldiers = {}

local function refreshStats(player)
	StatsUpdate:FireClient(player, {
		Level = player:GetAttribute("Level") or Config.BASE_LEVEL,
		Power = player:GetAttribute("Power") or Config.BASE_POWER,
		Soldiers = player:GetAttribute("Soldiers") or Config.BASE_SOLDIERS,
		Coins = player:GetAttribute("Coins") or 0,
		CurrentWeapon = player:GetAttribute("CurrentWeapon") or "Basic",
	})
end

local function createSoldierPart(player, index)
	local part = Instance.new("Part")
	part.Name = string.format("%s_Soldier_%d", player.UserId, index)
	part.Size = Vector3.new(1.2, 2, 1.2)
	part.Color = Color3.fromRGB(80, 180, 255)
	part.Material = Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = soldiersFolder
	return part
end

local function syncSoldierCount(player)
	local targetCount = math.clamp(player:GetAttribute("Soldiers") or Config.BASE_SOLDIERS, 1, Config.MAX_SOLDIERS)
	local list = playerSoldiers[player]
	if not list then
		list = {}
		playerSoldiers[player] = list
	end

	while #list < targetCount do
		table.insert(list, createSoldierPart(player, #list + 1))
	end

	while #list > targetCount do
		local soldier = table.remove(list)
		if soldier and soldier.Parent then
			soldier:Destroy()
		end
	end
end

RunService.Heartbeat:Connect(function()
	for player, list in pairs(playerSoldiers) do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root then
			for index, soldier in ipairs(list) do
				if soldier.Parent then
					local row = math.floor((index - 1) / 6)
					local col = (index - 1) % 6
					local xOffset = (col - 2.5) * 2
					local zOffset = 6 + (row * 3)
					local bob = math.sin(time() * 4 + index) * 0.4
					local target = root.CFrame * CFrame.new(xOffset, bob, zOffset)
					soldier.CFrame = soldier.CFrame:Lerp(target, 0.2)
				end
			end
		end
	end
end)

RequestProfile.OnServerInvoke = function(player)
	local profile = DataManager:GetProfile(player)
	if not profile then
		profile = DataManager:LoadProfile(player)
	end
	return {
		HasSave = profile ~= nil,
		Profile = profile,
		Weapons = Weapons.GetAll(),
		Shop = Config.SHOP_ITEMS,
	}
end

StartChoice.OnServerEvent:Connect(function(player, payload)
	if type(payload) ~= "table" then
		return
	end

	local choice = payload.Choice
	local loadedProfile = DataManager:GetProfile(player) or DataManager:LoadProfile(player)
	if choice == "New" then
		loadedProfile = Stats.GetDefaultProfile()
		DataManager:SetProfile(player, loadedProfile)
	end

	Stats.ToAttributes(player, loadedProfile)
	syncSoldierCount(player)
	refreshStats(player)
end)

PurchaseRequest.OnServerEvent:Connect(function(player, itemId)
	if type(itemId) ~= "string" then
		return
	end

	local profile = DataManager:GetProfile(player)
	if not profile then
		return
	end

	local coins = player:GetAttribute("Coins") or 0
	for _, categoryItems in pairs(Config.SHOP_ITEMS) do
		for _, item in ipairs(categoryItems) do
			if item.Id == itemId and coins >= item.Cost then
				player:SetAttribute("Coins", coins - item.Cost)
				if item.Type == "Power" then
					player:SetAttribute("Power", (player:GetAttribute("Power") or 0) + item.Value)
				elseif item.Type == "Soldiers" then
					player:SetAttribute("Soldiers", (player:GetAttribute("Soldiers") or 0) + item.Value)
					syncSoldierCount(player)
				elseif item.Type == "CannonUnlock" then
					if not table.find(profile.OwnedCannons, item.Value) then
						table.insert(profile.OwnedCannons, item.Value)
					end
				end
				refreshStats(player)
				return
			end
		end
	end
end)

EquipWeaponRequest.OnServerEvent:Connect(function(player, weaponId)
	if type(weaponId) ~= "string" then
		return
	end

	local profile = DataManager:GetProfile(player)
	if not profile then
		return
	end

	if not table.find(profile.OwnedWeapons, weaponId) then
		local weapon = Weapons.GetWeapon(weaponId)
		local price = 90
		if weapon.Id == "Heavy" then
			price = 140
		elseif weapon.Id == "Explosive" then
			price = 170
		elseif weapon.Id == "Special" then
			price = 220
		elseif weapon.Id == "Fast" then
			price = 110
		end
		local coins = player:GetAttribute("Coins") or 0
		if coins < price then
			return
		end
		player:SetAttribute("Coins", coins - price)
		table.insert(profile.OwnedWeapons, weaponId)
	end

	player:SetAttribute("CurrentWeapon", weaponId)
	refreshStats(player)
end)

PlaceCannonRequest.OnServerEvent:Connect(function(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end

	local cannon = Instance.new("Part")
	cannon.Name = string.format("%s_Cannon", player.UserId)
	cannon.Size = Vector3.new(2, 2, 2)
	cannon.Shape = Enum.PartType.Cylinder
	cannon.Color = Color3.fromRGB(90, 90, 90)
	cannon.Material = Enum.Material.Metal
	cannon.Anchored = true
	cannon.CanCollide = true
	cannon.CFrame = root.CFrame * CFrame.new(0, -2, -8) * CFrame.Angles(0, 0, math.rad(90))
	cannon.Parent = workspace

	Notification:FireClient(player, {
		Title = "Canon placé",
		Description = "Ton canon tire automatiquement.",
		Color = Color3.fromRGB(120, 200, 255),
	})

	task.delay(60, function()
		if cannon and cannon.Parent then
			cannon:Destroy()
		end
	end)
end)

Players.PlayerAdded:Connect(function(player)
	local profile = DataManager:LoadProfile(player)

	player:SetAttribute("ProfileReady", true)
	player:SetAttribute("Level", profile.Level)
	player:SetAttribute("Power", profile.Power)
	player:SetAttribute("Soldiers", profile.Soldiers)
	player:SetAttribute("Coins", profile.Coins)
	player:SetAttribute("CurrentWeapon", profile.CurrentWeapon)

	player.CharacterAdded:Connect(function()
		task.wait(0.2)
		syncSoldierCount(player)
		refreshStats(player)
	end)

	ShopOpen:FireClient(player, false)
end)

Players.PlayerRemoving:Connect(function(player)
	local list = playerSoldiers[player]
	if list then
		for _, soldier in ipairs(list) do
			if soldier and soldier.Parent then
				soldier:Destroy()
			end
		end
		playerSoldiers[player] = nil
	end
end)

return {}
