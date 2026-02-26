--!strict
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PathfindingService = game:GetService("PathfindingService")

local Settings = require(ReplicatedStorage.Shared.Settings)
local BraceService = require(script.Parent.BraceService)
local NPCService = require(script.Parent.NPCService)

local DogService = {}

function DogService.init()
	task.spawn(function()
		while true do
			task.wait(Settings.DOG_SPAWN_INTERVAL or 45)
			if game:GetAttribute("GameStarted") then
				DogService.spawnDog()
			end
		end
	end)
end

function DogService.spawnDog()
	print("[DEBUG-SERVER] DogService: Spawning dogMalus...")
	
	-- Create a simple dog visualization (using a small block for now as per instructions to "add code for the model")
	-- The user will provide the actual model named "dogMalus", but I'll write logic to handle it.
	local dog = Workspace:FindFirstChild("dogMalus")
	if not dog then
		-- Fallback to a placeholder if model isn't there yet
		dog = Instance.new("Model")
		dog.Name = "dogMalus"
		local h = Instance.new("Humanoid", dog)
		local hrp = Instance.new("Part", dog)
		hrp.Name = "HumanoidRootPart"
		hrp.Size = Vector3.new(3, 2, 4)
		hrp.Color = Color3.fromRGB(139, 69, 19)
		dog.PrimaryPart = hrp
		dog.Parent = Workspace
	else
		-- Clone existing model
		dog = dog:Clone()
		dog.Name = "DogMalus_Active"
		dog.Parent = Workspace
	end
	
	local rootPart = dog.PrimaryPart
	if not rootPart then return end
	
	-- Spawn far away
	-- Spawn far away but on ground
	rootPart.CFrame = CFrame.new(Settings.DOG_SPAWN_POS or Vector3.new(200, 2, 200))
	
	local humanoid = dog:FindFirstChildOfClass("Humanoid")
	if humanoid then humanoid.WalkSpeed = 20 end
	
	-- Target Brace
	local targetBrace = NPCService.findNearestBrace(rootPart.Position)
	if not targetBrace then 
		dog:Destroy()
		return 
	end
	
	local bracePos = targetBrace.PrimaryPart.Position
	
	-- Pathfinding to Brace
	local path = PathfindingService:CreatePath({AgentRadius = 3, AgentCanJump = true})
	path:ComputeAsync(rootPart.Position, bracePos)
	
	if path.Status == Enum.PathStatus.Success then
		local waypoints = path:GetWaypoints()
		for i, waypoint in waypoints do
			if not game:GetAttribute("GameStarted") then break end
			if humanoid then humanoid:MoveTo(waypoint.Position) end
			humanoid.MoveToFinished:Wait()
			
			-- If close to brace
			if (rootPart.Position - bracePos).Magnitude < 10 then
				print("[DEBUG-SERVER] Dog reached brace!")
				-- Play Bark
				NPCService.playSound(rootPart, Settings.DOG_SOUND_ID, 1.0)
				
				-- Steal Meat
				local stolen = BraceService.stealMeat(targetBrace)
				if stolen then
					print("[DEBUG-SERVER] Dog stole meat!")
				end
				
				task.wait(1)
				break
			end
		end
	end
	
	-- Run Away
	if humanoid then
		humanoid:MoveTo(Vector3.new(300, 10, 300))
		task.wait(5)
	end
	
	dog:Destroy()
end

return DogService
