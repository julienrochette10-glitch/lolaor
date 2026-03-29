local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local DataManager = require(ServerScriptService:WaitForChild("DataManager"))
local Config = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Config"))
local Weapons = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Weapons"))

local remoteFolder = ReplicatedStorage:WaitForChild("RemoteEvents")
local StatsUpdate = remoteFolder:WaitForChild("StatsUpdate")
local Notification = remoteFolder:WaitForChild("Notification")
local ShopOpen = remoteFolder:WaitForChild("ShopOpen")

local mapFolder = workspace:FindFirstChild("Map")
if not mapFolder then
	mapFolder = Instance.new("Folder")
	mapFolder.Name = "Map"
	mapFolder.Parent = workspace
end

local doorsFolder = workspace:FindFirstChild("Doors")
if not doorsFolder then
	doorsFolder = Instance.new("Folder")
	doorsFolder.Name = "Doors"
	doorsFolder.Parent = workspace
end

local enemiesFolder = workspace:FindFirstChild("Enemies")
if not enemiesFolder then
	enemiesFolder = Instance.new("Folder")
	enemiesFolder.Name = "Enemies"
	enemiesFolder.Parent = workspace
end

local function sendStats(player)
	StatsUpdate:FireClient(player, {
		Level = player:GetAttribute("Level") or 1,
		Power = player:GetAttribute("Power") or 0,
		Soldiers = player:GetAttribute("Soldiers") or 1,
		Coins = player:GetAttribute("Coins") or 0,
		CurrentWeapon = player:GetAttribute("CurrentWeapon") or "Basic",
	})
end

local function createDoor(position, buff)
	local door = Instance.new("Part")
	door.Name = "Door_" .. buff.Label
	door.Size = Vector3.new(8, 10, 1)
	door.Anchored = true
	door.Material = Enum.Material.ForceField
	door.Color = Color3.fromRGB(110, 220, 255)
	door.Transparency = 0.2
	door.CanCollide = false
	door.CFrame = CFrame.new(position)
	door.Parent = doorsFolder

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(220, 70)
	billboard.StudsOffset = Vector3.new(0, 6, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = door

	local textLabel = Instance.new("TextLabel")
	textLabel.Size = UDim2.fromScale(1, 1)
	textLabel.BackgroundTransparency = 1
	textLabel.Font = Enum.Font.GothamBold
	textLabel.TextScaled = true
	textLabel.TextStrokeTransparency = 0.4
	textLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	textLabel.Text = buff.Label
	textLabel.Parent = billboard

	return door
end

local function clearFolder(folder)
	for _, child in ipairs(folder:GetChildren()) do
		child:Destroy()
	end
end

local function spawnEnemy(level, index, isBoss)
	local enemy = Instance.new("Part")
	enemy.Name = isBoss and "Boss" or "Enemy_" .. index
	enemy.Size = isBoss and Vector3.new(6, 8, 6) or Vector3.new(3, 4, 3)
	enemy.Anchored = true
	enemy.Material = Enum.Material.Neon
	enemy.Color = isBoss and Color3.fromRGB(255, 75, 75) or Color3.fromRGB(255, 145, 95)
	enemy.CanCollide = true
	enemy.Parent = enemiesFolder

	local health = isBoss
		and (Config.ENEMY_SCALE_BY_LEVEL.BaseBossHealth + level * Config.ENEMY_SCALE_BY_LEVEL.BossHealthPerLevel)
		or (Config.ENEMY_SCALE_BY_LEVEL.BaseHealth + level * Config.ENEMY_SCALE_BY_LEVEL.HealthPerLevel)
	enemy:SetAttribute("Health", health)
	enemy:SetAttribute("MaxHealth", health)
	enemy:SetAttribute("IsBoss", isBoss)
	enemy:SetAttribute("Level", level)
	enemy:SetAttribute("Reward", isBoss and (120 + level * 15) or (8 + level * 3))

	local laneOffset = (index % 4) * 8
	enemy.CFrame = CFrame.new(-12 + laneOffset, isBoss and 5 or 2, -120 - (index * 8) - (level * 20))

	return enemy
end

local function buildLevelGeometry(level)
	clearFolder(mapFolder)
	clearFolder(doorsFolder)
	clearFolder(enemiesFolder)

	local floor = Instance.new("Part")
	floor.Name = "Runway"
	floor.Anchored = true
	floor.Size = Vector3.new(60, 1, 520)
	floor.Color = Color3.fromRGB(36, 41, 56)
	floor.Material = Enum.Material.Slate
	floor.Position = Vector3.new(0, -3, -170)
	floor.Parent = mapFolder

	local wallLeft = Instance.new("Part")
	wallLeft.Name = "WallLeft"
	wallLeft.Anchored = true
	wallLeft.Size = Vector3.new(1, 16, 520)
	wallLeft.Position = Vector3.new(-30, 4, -170)
	wallLeft.Color = Color3.fromRGB(20, 24, 34)
	wallLeft.Parent = mapFolder

	local wallRight = wallLeft:Clone()
	wallRight.Name = "WallRight"
	wallRight.Position = Vector3.new(30, 4, -170)
	wallRight.Parent = mapFolder

	for i = 1, 8 do
		local buff = Config.DOOR_BUFFS[((i - 1) % #Config.DOOR_BUFFS) + 1]
		createDoor(Vector3.new(((i % 2 == 0) and 12 or -12), 2, -35 - (i * 22)), buff)
	end

	local count = Config.ENEMY_SCALE_BY_LEVEL.BaseCount + (level - 1) * Config.ENEMY_SCALE_BY_LEVEL.CountPerLevel
	for i = 1, count do
		spawnEnemy(level, i, false)
	end
	spawnEnemy(level, count + 1, true)
end

local function onDoorTouched(door, hit)
	local character = hit.Parent
	if not character then
		return
	end
	local player = Players:GetPlayerFromCharacter(character)
	if not player then
		return
	end
	if door:GetAttribute("Used") then
		return
	end
	door:SetAttribute("Used", true)

	for _, buff in ipairs(Config.DOOR_BUFFS) do
		if door.Name == "Door_" .. buff.Label then
			if buff.Type == "Soldiers" then
				player:SetAttribute("Soldiers", (player:GetAttribute("Soldiers") or 1) + buff.Value)
			elseif buff.Type == "Power" then
				player:SetAttribute("Power", (player:GetAttribute("Power") or 0) + buff.Value)
			end
			break
		end
	end

	door.Transparency = 0.8
	door.Color = Color3.fromRGB(80, 255, 120)
	sendStats(player)
end

local function connectDoorTriggers()
	for _, door in ipairs(doorsFolder:GetChildren()) do
		door.Touched:Connect(function(hit)
			onDoorTouched(door, hit)
		end)
	end
end

local function completeLevel(player)
	local currentLevel = player:GetAttribute("Level") or 1
	local nextLevel = math.min(Config.TOTAL_LEVELS, currentLevel + 1)
	player:SetAttribute("Level", nextLevel)
	player:SetAttribute("Coins", (player:GetAttribute("Coins") or 0) + 150)

	Notification:FireClient(player, {
		Title = "Niveau terminé",
		Description = "Boss éliminé ! +150 pièces",
		Color = Color3.fromRGB(100, 255, 150),
	})

	if currentLevel == 1 then
		ShopOpen:FireClient(player, true)
	end

	sendStats(player)
	buildLevelGeometry(nextLevel)
	connectDoorTriggers()

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root then
		root.CFrame = CFrame.new(0, 4, 40)
	end

	local profile = DataManager:GetProfile(player)
	if profile then
		profile.Level = nextLevel
		profile.Power = player:GetAttribute("Power") or profile.Power
		profile.Soldiers = player:GetAttribute("Soldiers") or profile.Soldiers
		profile.Coins = player:GetAttribute("Coins") or profile.Coins
		profile.CurrentWeapon = player:GetAttribute("CurrentWeapon") or profile.CurrentWeapon
	end
end

task.spawn(function()
	while true do
		task.wait(Config.AUTO_DAMAGE_INTERVAL)
		for _, player in ipairs(Players:GetPlayers()) do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if root then
				local currentWeapon = Weapons.GetWeapon(player:GetAttribute("CurrentWeapon") or "Basic")
				local power = player:GetAttribute("Power") or 0
				local soldiers = player:GetAttribute("Soldiers") or 1
				local dps = power + (soldiers * 2) + currentWeapon.Damage

				for _, enemy in ipairs(enemiesFolder:GetChildren()) do
					if enemy:IsA("BasePart") then
						local distance = (enemy.Position - root.Position).Magnitude
						if distance <= Config.AUTO_DAMAGE_RANGE then
							local health = enemy:GetAttribute("Health") or 0
							health -= dps * Config.AUTO_DAMAGE_INTERVAL * currentWeapon.FireRate
							enemy:SetAttribute("Health", health)
							if health <= 0 then
								local reward = enemy:GetAttribute("Reward") or 10
								player:SetAttribute("Coins", (player:GetAttribute("Coins") or 0) + reward)
								local wasBoss = enemy:GetAttribute("IsBoss") == true
								enemy:Destroy()
								sendStats(player)
								if wasBoss then
									Notification:FireClient(player, {
										Title = "Boss vaincu",
										Description = "Récompense obtenue !",
										Color = Color3.fromRGB(255, 210, 100),
									})
									completeLevel(player)
								end
							end
						end
					end
				end
			end
		end
	end
end)

buildLevelGeometry(1)
connectDoorTriggers()

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		task.wait(0.2)
		local root = character:FindFirstChild("HumanoidRootPart")
		if root then
			root.CFrame = CFrame.new(0, 4, 40)
		end
	end)
end)

return {}
