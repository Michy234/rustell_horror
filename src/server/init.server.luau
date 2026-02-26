local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BraceService = require(script:WaitForChild("BraceService"))
local NPCService = require(script:WaitForChild("NPCService"))
local WorldService = require(script:WaitForChild("WorldService"))

local startEvent = Instance.new("RemoteEvent")
startEvent.Name = "GameStartEvent"
startEvent.Parent = ReplicatedStorage

local resetEvent = Instance.new("RemoteEvent")
resetEvent.Name = "GameResetEvent"
resetEvent.Parent = ReplicatedStorage

local gameOverEvent = Instance.new("RemoteEvent")
gameOverEvent.Name = "GameOverEvent"
gameOverEvent.Parent = ReplicatedStorage

BraceService.init()
NPCService.init()
WorldService.init()

startEvent.OnServerEvent:Connect(function(player)
	if not game:GetAttribute("GameStarted") then
		game:SetAttribute("GameStarted", true)
		print("Game Started by " .. player.Name)
	end
end)

resetEvent.OnServerEvent:Connect(function(player)
	print("[DEBUG-SERVER] Game Reset requested by " .. player.Name)
	game:SetAttribute("GameStarted", false)
	print("[DEBUG-SERVER] Clearing NPCs...")
	NPCService.reset()
	print("[DEBUG-SERVER] NPC Reset complete.")
end)

print("Server started: Services initialized.")
