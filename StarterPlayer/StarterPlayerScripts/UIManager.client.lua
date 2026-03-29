local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local remotes = ReplicatedStorage:WaitForChild("RemoteEvents")
local RequestProfile = remotes:WaitForChild("RequestProfile")
local StartChoice = remotes:WaitForChild("StartChoice")
local StatsUpdate = remotes:WaitForChild("StatsUpdate")
local Notification = remotes:WaitForChild("Notification")
local ShopOpen = remotes:WaitForChild("ShopOpen")
local PurchaseRequest = remotes:WaitForChild("PurchaseRequest")
local EquipWeaponRequest = remotes:WaitForChild("EquipWeaponRequest")

local function createTextButton(parent, text, position)
	local button = Instance.new("TextButton")
	button.Size = UDim2.fromOffset(220, 46)
	button.Position = position
	button.BackgroundColor3 = Color3.fromRGB(38, 46, 66)
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.Font = Enum.Font.GothamBold
	button.TextSize = 18
	button.Text = text
	button.AutoButtonColor = true
	button.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = button

	return button
end

local mainGui = Instance.new("ScreenGui")
mainGui.Name = "MainHUD"
mainGui.ResetOnSpawn = false
mainGui.Parent = playerGui

local topPanel = Instance.new("Frame")
topPanel.Size = UDim2.fromOffset(520, 60)
topPanel.Position = UDim2.fromScale(0.5, 0.04)
topPanel.AnchorPoint = Vector2.new(0.5, 0)
topPanel.BackgroundColor3 = Color3.fromRGB(18, 24, 34)
topPanel.BackgroundTransparency = 0.15
topPanel.Parent = mainGui

local topCorner = Instance.new("UICorner")
topCorner.CornerRadius = UDim.new(0, 14)
topCorner.Parent = topPanel

local levelLabel = Instance.new("TextLabel")
levelLabel.Size = UDim2.fromScale(0.32, 1)
levelLabel.BackgroundTransparency = 1
levelLabel.Font = Enum.Font.GothamBold
levelLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
levelLabel.TextScaled = true
levelLabel.Text = "Niveau: 1"
levelLabel.Parent = topPanel

local powerLabel = levelLabel:Clone()
powerLabel.Position = UDim2.fromScale(0.33, 0)
powerLabel.Text = "Puissance: 0"
powerLabel.Parent = topPanel

local soldiersLabel = levelLabel:Clone()
soldiersLabel.Position = UDim2.fromScale(0.66, 0)
soldiersLabel.Text = "Soldats: 1"
soldiersLabel.Parent = topPanel

local menuFrame = Instance.new("Frame")
menuFrame.Size = UDim2.fromOffset(500, 310)
menuFrame.Position = UDim2.fromScale(0.5, 0.5)
menuFrame.AnchorPoint = Vector2.new(0.5, 0.5)
menuFrame.BackgroundColor3 = Color3.fromRGB(17, 22, 32)
menuFrame.Parent = mainGui

local menuCorner = Instance.new("UICorner")
menuCorner.CornerRadius = UDim.new(0, 14)
menuCorner.Parent = menuFrame

local menuTitle = Instance.new("TextLabel")
menuTitle.Size = UDim2.fromOffset(420, 50)
menuTitle.Position = UDim2.fromOffset(40, 30)
menuTitle.BackgroundTransparency = 1
menuTitle.Font = Enum.Font.GothamBlack
menuTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
menuTitle.TextSize = 32
menuTitle.Text = "Progression Soldiers"
menuTitle.Parent = menuFrame

local continueButton = createTextButton(menuFrame, "Continuer", UDim2.fromOffset(140, 120))
local newButton = createTextButton(menuFrame, "Nouvelle partie", UDim2.fromOffset(140, 180))

local notificationLabel = Instance.new("TextLabel")
notificationLabel.Size = UDim2.fromOffset(420, 54)
notificationLabel.Position = UDim2.fromScale(0.5, 0.12)
notificationLabel.AnchorPoint = Vector2.new(0.5, 0)
notificationLabel.BackgroundColor3 = Color3.fromRGB(36, 44, 66)
notificationLabel.BackgroundTransparency = 0.2
notificationLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
notificationLabel.Font = Enum.Font.GothamBold
notificationLabel.TextSize = 24
notificationLabel.Visible = false
notificationLabel.Parent = mainGui

local notifCorner = Instance.new("UICorner")
notifCorner.CornerRadius = UDim.new(0, 12)
notifCorner.Parent = notificationLabel

local shopFrame = Instance.new("Frame")
shopFrame.Size = UDim2.fromOffset(660, 360)
shopFrame.Position = UDim2.fromScale(0.5, 0.72)
shopFrame.AnchorPoint = Vector2.new(0.5, 0.5)
shopFrame.BackgroundColor3 = Color3.fromRGB(14, 18, 28)
shopFrame.Visible = false
shopFrame.Parent = mainGui

local shopCorner = Instance.new("UICorner")
shopCorner.CornerRadius = UDim.new(0, 14)
shopCorner.Parent = shopFrame

local shopTitle = Instance.new("TextLabel")
shopTitle.Size = UDim2.fromOffset(640, 36)
shopTitle.Position = UDim2.fromOffset(10, 10)
shopTitle.BackgroundTransparency = 1
shopTitle.Text = "SHOP"
shopTitle.Font = Enum.Font.GothamBlack
shopTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
shopTitle.TextSize = 26
shopTitle.Parent = shopFrame

local listLayoutContainer = Instance.new("Frame")
listLayoutContainer.Size = UDim2.fromOffset(640, 290)
listLayoutContainer.Position = UDim2.fromOffset(10, 58)
listLayoutContainer.BackgroundTransparency = 1
listLayoutContainer.Parent = shopFrame

local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 8)
listLayout.FillDirection = Enum.FillDirection.Vertical
listLayout.Parent = listLayoutContainer

local function showNotification(title, desc, color)
	notificationLabel.Text = string.format("%s - %s", title or "Info", desc or "")
	notificationLabel.BackgroundColor3 = color or Color3.fromRGB(36, 44, 66)
	notificationLabel.Visible = true
	notificationLabel.TextTransparency = 1
	TweenService:Create(notificationLabel, TweenInfo.new(0.25), {TextTransparency = 0}):Play()
	task.delay(2.5, function()
		TweenService:Create(notificationLabel, TweenInfo.new(0.25), {TextTransparency = 1}):Play()
		task.wait(0.3)
		notificationLabel.Visible = false
	end)
end

local function createShopButton(parent, text, callback)
	local button = createTextButton(parent, text, UDim2.new())
	button.Size = UDim2.fromOffset(620, 40)
	button.MouseButton1Click:Connect(callback)
	return button
end

local function refreshShop(profileData)
	for _, child in ipairs(listLayoutContainer:GetChildren()) do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end

	for _, categoryItems in pairs(profileData.Shop) do
		for _, item in ipairs(categoryItems) do
			createShopButton(listLayoutContainer, string.format("%s - %d pièces", item.Label, item.Cost), function()
				PurchaseRequest:FireServer(item.Id)
			end)
		end
	end

	for _, weapon in ipairs(profileData.Weapons) do
		createShopButton(listLayoutContainer, "Équiper/Acheter: " .. weapon.DisplayName, function()
			EquipWeaponRequest:FireServer(weapon.Id)
		end)
	end
end

local profileResult = RequestProfile:InvokeServer()
if profileResult and profileResult.Profile then
	refreshShop(profileResult)
end

continueButton.MouseButton1Click:Connect(function()
	StartChoice:FireServer({Choice = "Continue"})
	menuFrame.Visible = false
end)

newButton.MouseButton1Click:Connect(function()
	StartChoice:FireServer({Choice = "New"})
	menuFrame.Visible = false
end)

StatsUpdate.OnClientEvent:Connect(function(payload)
	if type(payload) ~= "table" then
		return
	end
	levelLabel.Text = "Niveau: " .. tostring(payload.Level or 1)
	powerLabel.Text = "Puissance: " .. tostring(payload.Power or 0)
	soldiersLabel.Text = "Soldats: " .. tostring(payload.Soldiers or 1)
end)

Notification.OnClientEvent:Connect(function(payload)
	if type(payload) ~= "table" then
		return
	end
	showNotification(payload.Title, payload.Description, payload.Color)
end)

ShopOpen.OnClientEvent:Connect(function(isOpen)
	shopFrame.Visible = isOpen == true
	if isOpen then
		showNotification("Shop", "Zone boutique débloquée", Color3.fromRGB(145, 225, 255))
	end
end)
