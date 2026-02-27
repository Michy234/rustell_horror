--!strict
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PathfindingService = game:GetService("PathfindingService")

local Settings = require(ReplicatedStorage.Shared.Settings)
local BraceService = require(script.Parent.BraceService)
local NPCService = require(script.Parent.NPCService)

local DogService = {}

local originalHomeCFrame: CFrame? = nil

function DogService.init()
	-- Cache the dog's spawn position once at boot
	task.spawn(function()
		task.wait(2) -- Wait for Workspace to load
		local dog = Workspace:FindFirstChild("dogMalus", true)
		if dog then
			originalHomeCFrame = dog:GetPivot()
			print("[DogService] Cached original home position.")
		end
	end)

	task.spawn(function()
		while true do
			-- Random interval: 45s to 75s (45s to 1m15s as requested)
			local interval = math.random(45, 75)
			task.wait(interval)
			if game:GetAttribute("GameStarted") then
				DogService.spawnDog(true)
			end
		end
	end)
end

local isMoving = false
local dogChased = false
local clickCount = 0
local CLICKS_TO_CHASE = Settings.DOG_CLICKS_MIN or 20

-- Watch for game stop/reset: force-unlock isMoving so :dog works again next round
game:GetAttributeChangedSignal("GameStarted"):Connect(function()
	if not game:GetAttribute("GameStarted") then
		-- Game stopped — abort any running dog sequence
		dogChased = true   -- breaks movement loops inside spawnDog
		isMoving = false   -- allows spawnDog to be called again
		print("[DogService] GameStarted=false → isMoving reset.")
	end
end)


-- Create/Get RemoteEvent for dog clicks
local DogClickEvent = ReplicatedStorage:FindFirstChild("DogClickEvent")
if not DogClickEvent then
	DogClickEvent = Instance.new("RemoteEvent")
	DogClickEvent.Name = "DogClickEvent"
	DogClickEvent.Parent = ReplicatedStorage
end

local function createDogUI(rootPart: BasePart): BillboardGui
	local existing = rootPart:FindFirstChild("DogChaseUI")
	if existing then existing:Destroy() end
	
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "DogChaseUI"
	-- Use world-space studs so text shrinks with distance
	billboard.Size = UDim2.fromOffset(180, 55)
	billboard.MaxDistance = 50  -- invisible beyond 30 studs
	billboard.StudsOffset = Vector3.new(0, 3, 0)
	billboard.AlwaysOnTop = false  -- occludes behind walls
	billboard.ResetOnSpawn = false
	billboard.Parent = rootPart
	
	-- NO background frame: transparent
	local label = Instance.new("TextLabel")
	label.Name = "CountLabel"
	label.Size = UDim2.fromScale(1, 0.5)
	label.Position = UDim2.fromScale(0, 0)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.new(1, 1, 0)
	label.TextSize = 13
	label.Text = "Clicca per scacciarmi!"
	label.Parent = billboard
	Instance.new("UIStroke", label).Thickness = 1
	
	local bar = Instance.new("TextLabel")
	bar.Name = "BarLabel"
	bar.Size = UDim2.fromScale(1, 0.5)
	bar.Position = UDim2.fromScale(0, 0.5)
	bar.BackgroundTransparency = 1
	bar.Font = Enum.Font.GothamBold
	bar.TextColor3 = Color3.new(1, 0.4, 0.1)
	bar.TextSize = 16
	bar.Text = "0 / " .. CLICKS_TO_CHASE
	bar.Parent = billboard
	Instance.new("UIStroke", bar).Thickness = 1
	
	return billboard
end

local function updateDogUI(rootPart: BasePart, count: number)
	local billboard = rootPart:FindFirstChild("DogChaseUI")
	if not billboard then return end
	local bar = billboard:FindFirstChild("BarLabel")
	if bar then
		bar.Text = count .. " / " .. CLICKS_TO_CHASE
		if count >= CLICKS_TO_CHASE * 0.7 then
			bar.TextColor3 = Color3.new(1, 0, 0)
		end
	end
end

local function cleanDogUI(rootPart: BasePart)
	local billboard = rootPart:FindFirstChild("DogChaseUI")
	if billboard then billboard:Destroy() end
end

local function showDogSpeech(rootPart: BasePart, text: string, duration: number?)
	local existing = rootPart:FindFirstChild("DogSpeech")
	if existing then existing:Destroy() end
	
	local bubble = Instance.new("BillboardGui")
	bubble.Name = "DogSpeech"
	bubble.Size = UDim2.fromOffset(200, 70)
	bubble.MaxDistance = 50
	bubble.StudsOffset = Vector3.new(0, 6, 0)
	bubble.AlwaysOnTop = false
	bubble.ResetOnSpawn = false
	bubble.Parent = rootPart
	
	-- Bubble background panel
	local bg = Instance.new("Frame")
	bg.Name = "BubbleBG"
	bg.Size = UDim2.new(1, 0, 0.78, 0)
	bg.Position = UDim2.fromScale(0, 0)
	bg.BackgroundColor3 = Color3.fromRGB(255, 255, 240)
	bg.BorderSizePixel = 0
	bg.Parent = bubble
	local bgCorner = Instance.new("UICorner")
	bgCorner.CornerRadius = UDim.new(0, 10)
	bgCorner.Parent = bg
	local bgStroke = Instance.new("UIStroke")
	bgStroke.Color = Color3.fromRGB(80, 50, 20)
	bgStroke.Thickness = 2
	bgStroke.Parent = bg
	
	-- Text inside bubble
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.fromRGB(50, 25, 0)
	label.TextSize = 16
	label.Text = text
	label.TextWrapped = true
	label.Parent = bg
	
	-- Triangle pointer (downward notch) using a rotated frame
	local tail = Instance.new("Frame")
	tail.Name = "Tail"
	tail.Size = UDim2.fromOffset(18, 18)
	tail.Position = UDim2.new(0.5, -9, 0.78, -2)
	tail.BackgroundColor3 = Color3.fromRGB(255, 255, 240)
	tail.BorderSizePixel = 0
	tail.Rotation = 45
	tail.ZIndex = 0
	tail.Parent = bubble
	
	task.delay(duration or 4, function()
		if bubble and bubble.Parent then bubble:Destroy() end
	end)
end

local function moveModel(model: Model, targetPos: Vector3, speed: number, yOffset: number?)
	local root = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
	if not root then return end
	
	-- Use waypoint Y + pivot offset so the dog follows stairs/ramps correctly.
	-- yOffset = how high the pivot sits above ground (computed once per trip with raycast).
	local offset = yOffset or 0
	local startPos = root.Position
	local targetY = targetPos.Y + offset
	local flatTarget = Vector3.new(targetPos.X, targetY, targetPos.Z)
	
	local distance = (flatTarget - startPos).Magnitude
	if distance < 0.1 then return end
	
	local duration = distance / speed
	local startCFrame = model:GetPivot()
	
	-- Rotation: face the direction of movement (flat XZ)
	local dir = (flatTarget - startPos)
	local targetRotation
	if dir.Magnitude > 0.1 then
		targetRotation = CFrame.lookAt(startPos, flatTarget).Rotation
	else
		targetRotation = startCFrame.Rotation
	end

	-- Phase 1: Rotate in place to face target (max 0.25s)
	local rotDuration = math.min(0.25, duration * 0.4)
	local rotStart = os.clock()
	while (os.clock() - rotStart) < rotDuration do
		local alpha = (os.clock() - rotStart) / rotDuration
		model:PivotTo(CFrame.new(root.Position) * startCFrame.Rotation:Lerp(targetRotation, alpha))
		task.wait()
	end
	
	-- Phase 2: Glide forward, following the target Y (stairs/ramps)
	local moveStart = os.clock()
	local currentStartPos = startPos
	while (os.clock() - moveStart) < duration do
		local alpha = math.min(1, (os.clock() - moveStart) / duration)
		local p = currentStartPos:Lerp(flatTarget, alpha)
		model:PivotTo(CFrame.new(p) * targetRotation)
		task.wait()
		if (root.Position - flatTarget).Magnitude < 0.2 then break end
	end
	model:PivotTo(CFrame.new(flatTarget) * targetRotation)
end

local function rigDog(model: Model)
	local root = model.PrimaryPart or model:FindFirstChild("HumanoidRootPart") or model:FindFirstChildWhichIsA("BasePart", true)
	if not root then return end
	if not model.PrimaryPart then model.PrimaryPart = root end
	
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = true
			p.Massless = true
			p.CanCollide = false
		elseif p:IsA("Humanoid") then
			p:Destroy()
		end
	end

	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") and p ~= root then
			local hasJoint = false
			for _, joint in p:GetJoints() do
				if joint.Part0 and joint.Part1 then hasJoint = true break end
			end
			if not hasJoint then
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = root
				weld.Part1 = p
				weld.Parent = p
			end
		end
	end
end

function DogService.spawnDog(isAuto: boolean?)
	if isMoving then return end
	if isAuto and math.random() < 0.3 then return end
	
	local dog = Workspace:FindFirstChild("dogMalus", true)
	if not dog then return end
	
	-- Use cached home or current if not cached
	local homeCFrame = originalHomeCFrame or dog:GetPivot()

	isMoving = true
	dogChased = false
	clickCount = 0
	
	-- Dynamic click threshold: more clicks needed when less time remains
	-- Range: 20 (lots of time) → 40 (almost no time)
	do
		local remaining = Workspace:GetAttribute("GameRemainingTime") or 300
		local winTime = Settings.WIN_TIME or 300
		local t = math.clamp(remaining / winTime, 0, 1) -- 1 = full time, 0 = no time
		local minClicks = Settings.DOG_CLICKS_MIN or 20
		local maxClicks = Settings.DOG_CLICKS_MAX or 40
		CLICKS_TO_CHASE = math.floor(minClicks + (1 - t) * (maxClicks - minClicks))
	end
	
	-- Server-side click listener (valid only for this trip)
	local clickConn = DogClickEvent.OnServerEvent:Connect(function(_player)
		if not isMoving or dogChased then return end
		clickCount += 1
		local rootPart = dog.PrimaryPart
		if rootPart then updateDogUI(rootPart, clickCount) end
		if clickCount >= CLICKS_TO_CHASE then
			dogChased = true
		end
	end)
	
	local successSequence, err = pcall(function()
		rigDog(dog)
		
		local allBraces = {}
		local hasMeat = false
		for _, obj in Workspace:GetDescendants() do
			if obj:IsA("Model") and obj.Name:lower():match("brace") then
				table.insert(allBraces, obj)
				for i = 1, 4 do
					if obj:GetAttribute("Slot" .. i .. "_Status") ~= Settings.STATUS.EMPTY then
						hasMeat = true
						break
					end
				end
			end
		end
		
		print("[DogService] spawnDog: hasMeat=" .. tostring(hasMeat) .. " braces=" .. #allBraces .. " isAuto=" .. tostring(isAuto))
		if not hasMeat then
			if isAuto then
				-- Auto spawn aborted: nothing to steal
				print("[DogService] Auto spawn aborted: no meat in any brace.")
				isMoving = false
				return
			end
			-- Manual :dog command: walk to brace anyway (for testing / scary effect)
			print("[DogService] Manual call: walking to brace even with no meat.")
		end

		local rootPart = dog.PrimaryPart
		
		-- Show click counter UI on the dog
		createDogUI(rootPart)
		
		local walkSound = Instance.new("Sound")
		walkSound.Name = "DogWalkLoop"
		walkSound.SoundId = Settings.DOG_WALK_SOUND_ID
		walkSound.Looped = true
		walkSound.Volume = 0.5
		walkSound.Parent = rootPart
		walkSound:Play()
		
		local targetBrace = nil
		local minDist = math.huge
		for _, brace in allBraces do
			local braceHasMeat = false
			for i = 1, 4 do
				if brace:GetAttribute("Slot" .. i .. "_Status") ~= Settings.STATUS.EMPTY then
					braceHasMeat = true
					break
				end
			end
			if braceHasMeat then
				local d = (rootPart.Position - brace:GetPivot().Position).Magnitude
				if d < minDist then
					minDist = d
					targetBrace = brace
				end
			end
		end

		if not targetBrace then 
			walkSound:Destroy()
			return 
		end
		
		local bracePos = targetBrace:GetPivot().Position
		
		-- Compute yOffset once via raycast: how far the pivot sits above the ground.
		-- This lets the dog correctly descend/ascend stairs instead of floating.
		local yOffset = 0
		do
			local rayParams = RaycastParams.new()
			rayParams.FilterDescendantsInstances = {dog}
			rayParams.FilterType = Enum.RaycastFilterType.Exclude
			local hit = Workspace:Raycast(rootPart.Position, Vector3.new(0, -10, 0), rayParams)
			if hit then
				yOffset = rootPart.Position.Y - hit.Position.Y
				print(string.format("[DogService] yOffset computed: %.2f", yOffset))
			end
		end
		
		local path = PathfindingService:CreatePath({AgentRadius = 3})
		local ok = pcall(function() path:ComputeAsync(rootPart.Position, bracePos) end)
		
		if ok and path.Status == Enum.PathStatus.Success then
			for _, waypoint in path:GetWaypoints() do
				if dogChased then break end
				moveModel(dog, waypoint.Position, 20, yOffset)
				if (rootPart.Position - bracePos).Magnitude < 8 then break end
			end
		else
			if not dogChased then
				moveModel(dog, bracePos, 20, yOffset)
			end
		end
		
		if (rootPart.Position - bracePos).Magnitude < 15 and not dogChased then
			walkSound:Stop()
			task.wait(1.5)
			
			local remaining = Workspace:GetAttribute("GameRemainingTime") or 0
			local m = math.floor(remaining / 60)
			local s = math.floor(remaining % 60)
			
			local d1 = m
			local d2 = math.floor(s / 10)
			local d3 = s % 10
			local sum = d1 + d2 + d3
			
			local countToSteal = (sum % 2 == 0) and 1 or 2
			print("[DogService] Time: " .. m .. ":" .. string.format("%02d", s) .. " | Sum: " .. sum .. " -> " .. countToSteal)

			for _ = 1, countToSteal do
				local meatModel = BraceService.stealMeat(targetBrace)
				if meatModel then
					NPCService.playSound(rootPart, Settings.DOG_SOUND_ID, 1.0)
					
					-- Clone the meat and attach to the dog's mouth
					local carriedMeat = meatModel:Clone()
					carriedMeat.Name = "CarriedMeat"
					carriedMeat.Parent = dog
					
					-- Find the head/snout part dynamically for correct positioning
					local headPart = dog:FindFirstChild("Head")
						or dog:FindFirstChild("DogHead")
						or dog:FindFirstChild("UpperTorso")
						or rootPart
					
					-- 1) Place meat at the snout: front of head, chin level
					local snoutCFrame = headPart.CFrame * CFrame.new(0, -0.4, -1.2)
					carriedMeat:PivotTo(snoutCFrame)
					
					-- 2) THEN weld each meat part to rootPart (offset is recorded from current world position)
					for _, p in carriedMeat:GetDescendants() do
						if p:IsA("BasePart") then
							p.Transparency = 0
							p.Anchored = false
							p.CanCollide = false
							local weld = Instance.new("WeldConstraint")
							weld.Part0 = rootPart
							weld.Part1 = p
							weld.Parent = p
						end
					end
					task.wait(0.3)
				end
			end
			
			task.wait(0.5)
			
			-- Dog won! Hide click counter, show victory taunt
			cleanDogUI(rootPart)
			showDogSpeech(rootPart, "rustell :]")
			
			walkSound:Play()
			
			local pathBack = PathfindingService:CreatePath({AgentRadius = 3})
			local okBack = pcall(function() pathBack:ComputeAsync(rootPart.Position, homeCFrame.Position) end)

			-- Recompute yOffset at current position before walking back
			local yOffsetBack = 0
			do
				local rp = RaycastParams.new()
				rp.FilterDescendantsInstances = {dog}
				rp.FilterType = Enum.RaycastFilterType.Exclude
				local hit = Workspace:Raycast(rootPart.Position, Vector3.new(0, -10, 0), rp)
				if hit then yOffsetBack = rootPart.Position.Y - hit.Position.Y end
			end

			if okBack and pathBack.Status == Enum.PathStatus.Success then
				for _, waypoint in pathBack:GetWaypoints() do
					moveModel(dog, waypoint.Position, 18, yOffsetBack)
				end
			else
				moveModel(dog, homeCFrame.Position, 18, yOffsetBack)
			end
			
			for _, child in dog:GetChildren() do
				if child.Name == "CarriedMeat" then child:Destroy() end
			end
		end
		
		if dogChased then
			-- CHASED HOME: walk back sadly with slow bark, no steal
			walkSound:Stop()
			walkSound:Destroy()  -- destroy immediately so it can't replay
			task.wait(0.3)
			
			-- Player won! Hide click counter, show sad message
			cleanDogUI(rootPart)
			showDogSpeech(rootPart, "che palle :[", 5)
			
			-- One-shot sad bark: create directly (not via NPCService) to ensure it's one-shot
			local barkSound = Instance.new("Sound")
			barkSound.SoundId = Settings.DOG_SOUND_ID
			barkSound.Volume = 0.5
			barkSound.Looped = false
			barkSound.PlaybackSpeed = 0.75
			barkSound.Parent = rootPart
			barkSound:Play()
			barkSound.Ended:Connect(function() barkSound:Destroy() end)
			
			-- Sad walk: slow trudge home
			local sadWalk = Instance.new("Sound")
			sadWalk.Name = "SadWalkLoop"
			sadWalk.SoundId = Settings.DOG_WALK_SOUND_ID
			sadWalk.Looped = true
			sadWalk.Volume = 0.3
			sadWalk.PlaybackSpeed = 0.6
			sadWalk.Parent = rootPart
			sadWalk:Play()
			
			local pathHome = PathfindingService:CreatePath({AgentRadius = 3})
			local okHome = pcall(function() pathHome:ComputeAsync(rootPart.Position, homeCFrame.Position) end)

			-- Recompute yOffset at current position before sad walk home
			local yOffsetHome = 0
			do
				local rp = RaycastParams.new()
				rp.FilterDescendantsInstances = {dog}
				rp.FilterType = Enum.RaycastFilterType.Exclude
				local hit = Workspace:Raycast(rootPart.Position, Vector3.new(0, -10, 0), rp)
				if hit then yOffsetHome = rootPart.Position.Y - hit.Position.Y end
			end

			if okHome and pathHome.Status == Enum.PathStatus.Success then
				for _, waypoint in pathHome:GetWaypoints() do
					moveModel(dog, waypoint.Position, 12, yOffsetHome)
				end
				else
				moveModel(dog, homeCFrame.Position, 12, yOffsetHome)
			end
			
			sadWalk:Destroy()
		end
		
		walkSound:Destroy()
		dog:PivotTo(homeCFrame)
	end)
	
	clickConn:Disconnect()
	cleanDogUI(dog.PrimaryPart)
	
	if not successSequence then warn("[DogService] Error: " .. tostring(err)) end
	isMoving = false
end

return DogService
