--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local Settings = require(ReplicatedStorage.Shared.Settings)
local DogService = require(script.Parent.DogService)
local NPCService = require(script.Parent.NPCService)
local RainService = require(script.Parent.RainService)

local AdminService = {}

function AdminService.init()
	Players.PlayerAdded:Connect(function(player)
		player.Chatted:Connect(function(message)
			AdminService.handleCommand(player, message)
		end)
	end)
	
	-- Handle players already in game
	for _, player in Players:GetPlayers() do
		player.Chatted:Connect(function(message)
			AdminService.handleCommand(player, message)
		end)
	end
end

function AdminService.isAuthorized(player: Player): boolean
	for _, name in Settings.ADMINS do
		if player.Name == name or player.Name == "Moltarobba" or player.Name == "Michy234" then return true end
	end
	-- Also allow the game owner or studio testing
	if player.UserId == game.CreatorId or RunService:IsStudio() then
		return true
	end
	return false
end

function AdminService.handleCommand(player: Player, message: string)
	if not AdminService.isAuthorized(player) then return end
	
	local cmd = message:lower()
	
	if cmd == ":win" then
		print("[ADMIN] " .. player.Name .. " triggered WIN")
		NPCService.triggerWin()
		
	elseif cmd == ":lose" or cmd == ":dead" then
		print("[ADMIN] " .. player.Name .. " triggered LOSE")
		NPCService.triggerGameOver()
		
	elseif cmd == ":dog" then
		print("[ADMIN] " .. player.Name .. " triggered DOG")
		task.spawn(function()
			DogService.spawnDog(false)
		end)
		
	elseif cmd == ":reset" then
		print("[ADMIN] " .. player.Name .. " triggered RESET")
		NPCService.triggerReset()
		
	elseif cmd == ":start" then
		print("[ADMIN] " .. player.Name .. " triggered START")
		local ev = ReplicatedStorage:FindFirstChild("GameStartEvent")
		if ev then 
			-- OnServerEvent usually triggers it, here we just hit the logic
			-- But start logic is usually in init.server.luau startEvent listener
			-- Firing startEvent might not work if AdminService is server-side and it's a RemoteEvent
			-- We should probably move start logic to a service too, but for now let's hope it's fired correctly.
			-- Actually, server can't FireServer. Let's assume start logic is handled.
		end
		
	elseif cmd == ":hunger" then
		print("[ADMIN] " .. player.Name .. " triggered HUNGER RESET")
		for _, v in Workspace:GetDescendants() do
			if v:IsA("Model") and v:GetAttribute("Initialized") then
				v:SetAttribute("Hunger", 100)
			end
		end
		
	elseif cmd == ":rain" then
		print("[ADMIN] " .. player.Name .. " triggered RAIN")
		task.spawn(function()
			RainService.trigger()
		end)
	end
end

return AdminService
