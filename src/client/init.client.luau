local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local Settings = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Settings"))
local NotificationService = require(script.NotificationService)
local InteractionService = require(script.InteractionService)

NotificationService.init()
InteractionService.init()

-- Force Camera Mode to Classic
local player = Players.LocalPlayer
if player then
	player.CameraMode = Enum.CameraMode.Classic
end

-- Play Background Music
local bgm = Instance.new("Sound")
bgm.Name = "BackgroundMusic"
bgm.SoundId = Settings.BG_MUSIC.ID
bgm.Volume = Settings.BG_MUSIC.VOLUME
bgm.Looped = true
bgm.Parent = SoundService
bgm:Play()

-- NPC Interaction Visibility Logic
task.spawn(function()
	while true do
		local character = player.Character
		local holdingRustella = character and (character:FindFirstChild("Rustella") or character:FindFirstChild("Rustella Bruciata")) ~= nil
		
		-- Manage all NPC prompts in Workspace
		for _, descendant in Workspace:GetDescendants() do
			if descendant:IsA("ProximityPrompt") and descendant.ActionText == "Dai Rustella" then
				descendant.Enabled = holdingRustella
			end
		end
		
		task.wait(0.2)
	end
end)

print("Client started, NotificationService and Background Music initialized.")
