local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BraceService = require(script:WaitForChild("BraceService"))
local NPCService = require(script:WaitForChild("NPCService"))
local WorldService = require(script:WaitForChild("WorldService"))
local DogService = require(script:WaitForChild("DogService"))
local AdminService = require(script:WaitForChild("AdminService"))
local RainService = require(script:WaitForChild("RainService"))
local SaltService = require(script:WaitForChild("SaltService"))
local GrandpaService = require(script:WaitForChild("GrandpaService"))

BraceService.init()
NPCService.init()
WorldService.init()
DogService.init()
AdminService.init()
RainService.init()
SaltService.init()
GrandpaService.init()

local startEvent = Instance.new("RemoteEvent")
startEvent.Name = "GameStartEvent"
startEvent.Parent = ReplicatedStorage

local resetEvent = Instance.new("RemoteEvent")
resetEvent.Name = "GameResetEvent"
resetEvent.Parent = ReplicatedStorage

local gameOverEvent = Instance.new("RemoteEvent")
gameOverEvent.Name = "GameOverEvent"
gameOverEvent.Parent = ReplicatedStorage

local gameWinEvent = Instance.new("RemoteEvent")
gameWinEvent.Name = "GameWinEvent"
gameWinEvent.Parent = ReplicatedStorage

-- Nonno events
local nonnoWakeEvent = Instance.new("RemoteEvent")
nonnoWakeEvent.Name = "NonnoWakeEvent"
nonnoWakeEvent.Parent = ReplicatedStorage

local nonnoStandsUpEvent = Instance.new("RemoteEvent")
nonnoStandsUpEvent.Name = "NonnoStandsUpEvent"
nonnoStandsUpEvent.Parent = ReplicatedStorage

-- Update Timer Event
local timerUpdateEvent = Instance.new("RemoteEvent")
timerUpdateEvent.Name = "TimerUpdateEvent"
timerUpdateEvent.Parent = ReplicatedStorage


startEvent.OnServerEvent:Connect(function(player)
	if not game:GetAttribute("GameStarted") then
		game:SetAttribute("GameStarted", true)
		print("Game Started by " .. player.Name)
	end
end)

resetEvent.OnServerEvent:Connect(function(player)
	print("[DEBUG-SERVER] Game Reset requested by " .. player.Name)
	game:SetAttribute("GameStarted", false)
	
	-- CLEAR ALL PLAYERS INVENTORIES
	for _, p in game:GetService("Players"):GetPlayers() do
		local bp = p:FindFirstChild("Backpack")
		if bp then bp:ClearAllChildren() end
		
		local char = p.Character
		if char then
			for _, tool in char:GetChildren() do
				if tool:IsA("Tool") then tool:Destroy() end
			end
		end
		p:SetAttribute("RustelleCount", 0)
	end
	
	print("[DEBUG-SERVER] Clearing NPCs...")
	NPCService.reset()
	print("[DEBUG-SERVER] Clearing Braces...")
	BraceService.resetAll()
	print("[DEBUG-SERVER] Reset complete.")
end)

print("Server started: Services initialized.")
