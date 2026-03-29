local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remotes = ReplicatedStorage:WaitForChild("RemoteEvents")
local PlaceCannonRequest = remotes:WaitForChild("PlaceCannonRequest")

local debounce = false

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end

	if input.KeyCode == Enum.KeyCode.C and not debounce then
		debounce = true
		PlaceCannonRequest:FireServer()
		task.delay(1, function()
			debounce = false
		end)
	end
end)
