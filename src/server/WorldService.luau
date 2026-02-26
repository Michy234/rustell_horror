--!strict
local Workspace = game:GetService("Workspace")
local WorldService = {}

function WorldService.init()
	print("WorldService: Creazione bordi mappa...")
	
	local borderContainer = Instance.new("Folder")
	borderContainer.Name = "WorldBorders"
	borderContainer.Parent = Workspace
	
	local size = 500 -- Large enough walls
	local thickness = 5
	local radius = 300 -- Distance from center
	
	local function createWall(name: string, cframe: CFrame, s: Vector3)
		local wall = Instance.new("Part")
		wall.Name = name
		wall.Size = s
		wall.CFrame = cframe
		wall.Anchored = true
		wall.Transparency = 1
		wall.CanCollide = true
		wall.CastShadow = false
		wall.Parent = borderContainer
	end
	
	-- North
	createWall("Wall_N", CFrame.new(0, size/2, -radius), Vector3.new(size, size, thickness))
	-- South
	createWall("Wall_S", CFrame.new(0, size/2, radius), Vector3.new(size, size, thickness))
	-- East
	createWall("Wall_E", CFrame.new(radius, size/2, 0), Vector3.new(thickness, size, size))
	-- West
	createWall("Wall_W", CFrame.new(-radius, size/2, 0), Vector3.new(thickness, size, size))
	
	print("WorldService: Bordi mappa creati a raggio " .. radius)
end

return WorldService
