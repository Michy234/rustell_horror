--!strict
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Settings = require(ReplicatedStorage.Shared.Settings)

local NPCService = {}
local npcsSnapshot: {Model} = {} -- Store clones here
local aliveNPCs = 0

function NPCService.findNearestBrace(pos: Vector3): Model?
	local nearest = nil
	local minDist = math.huge
	for _, obj in Workspace:GetDescendants() do
		if obj:IsA("Model") and obj.Name:lower():match("brace") then
			local d = (obj:GetPivot().Position - pos).Magnitude
			if d < minDist then
				minDist = d
				nearest = obj
			end
		end
	end
	return nearest
end

function NPCService.playSound(target: any, soundId: string, volume: number?)
	local p: Attachment
	if typeof(target) == "Vector3" then
		p = Instance.new("Attachment")
		p.Position = target
		p.Parent = Workspace.Terrain
	elseif typeof(target) == "Instance" and target:IsA("BasePart") then
		p = Instance.new("Attachment")
		p.Parent = target
	elseif typeof(target) == "Instance" and target:IsA("Attachment") then
		p = target
	elseif typeof(target) == "Instance" and target:IsA("Model") and target.PrimaryPart then
		p = Instance.new("Attachment")
		p.Parent = target.PrimaryPart
	else
		-- Fallback to origin
		p = Instance.new("Attachment")
		p.Position = Vector3.new(0, 5, 0)
		p.Parent = Workspace.Terrain
	end

	local s = Instance.new("Sound")
	s.SoundId = soundId
	s.Volume = volume or 1
	s.Parent = p
	s:Play()
	s.Ended:Connect(function()
		if p and p.Parent == Workspace.Terrain then
			p:Destroy()
		end
		s:Destroy()
	end)
end

function NPCService.reset()
	aliveNPCs = 0
	for _, obj in Workspace:GetDescendants() do
		if obj:IsA("Model") and (obj:FindFirstChildOfClass("Humanoid") or obj.Name:lower():match("npc")) then
			if not game:GetService("Players"):GetPlayerFromCharacter(obj) then
				obj:Destroy()
			end
		end
	end
	
	-- Respawn all from snapshot
	task.wait(1)
	for _, template in npcsSnapshot do
		local clone = template:Clone()
		clone.Parent = Workspace
		print("NPCService: [RESET] Respawned " .. clone.Name)
	end
end

function NPCService.triggerWin()
	print("NPCService: [WIN] Win condition triggered.")
	game:SetAttribute("GameStarted", false)
	local winEvent = ReplicatedStorage:FindFirstChild("GameWinEvent")
	if winEvent then
		winEvent:FireAllClients()
	end
end

function NPCService.triggerReset()
	print("NPCService: [ADMIN] Forced Reset.")
	game:SetAttribute("GameStarted", false)
	local ev = ReplicatedStorage:FindFirstChild("GameResetEvent")
	if ev then
		-- We fire to all clients to clear UI/Camera
		ev:FireAllClients()
	end
end

function NPCService.init()
	print("[DEBUG-SERVER] NPCService: [ULTRA BOOT] Avvio...")
	table.clear(npcsSnapshot) -- Prevent accumulation

	-- CREATE SNAPSHOT
	for _, obj in Workspace:GetDescendants() do
		if obj:IsA("Model") and obj.Name:lower():match("npc") then
			if obj:FindFirstChildOfClass("Humanoid") or obj:GetAttribute("NPC_Hunger") then
				local clone = obj:Clone()
				clone:SetAttribute("Initialized", nil)
				table.insert(npcsSnapshot, clone)
				print("[DEBUG-SERVER] NPCService: [SNAPSHOT] Salvato -> " .. obj.Name)
			end
		end
	end

	task.spawn(function()
		local startTime = 0
		while true do
			if game:GetAttribute("GameStarted") then
				if startTime == 0 then
					startTime = os.clock()
				end
				local elapsed = os.clock() - startTime
				local remaining = math.max(0, Settings.WIN_TIME - elapsed)
				
				local timerUpdate = ReplicatedStorage:FindFirstChild("TimerUpdateEvent")
				if timerUpdate then
					timerUpdate:FireAllClients(remaining)
				end
				
				if remaining <= 0 then
					NPCService.triggerWin()
					startTime = 0
					task.wait(5)
				end
			else
				startTime = 0
			end
			
			for _, obj in Workspace:GetDescendants() do
				if obj:IsA("Model") and not obj:GetAttribute("Initialized") then
					local name = obj.Name:lower()
					if name:match("npc") and not game:GetService("Players"):GetPlayerFromCharacter(obj) then
						NPCService.setupNPC(obj)
					end
				end
			end
			task.wait(1)
		end
	end)
end

function NPCService.setupNPC(npc: Model)
	npc:SetAttribute("Initialized", true)
	npc:SetAttribute("IsEating", false)
	aliveNPCs += 1

	local humanoid = npc:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	humanoid.WalkSpeed = 12
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.AutoRotate = true

	-- UNANCHOR ALL PARTS
	for _, p in npc:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = false
		end
	end

	npc:SetAttribute("Hunger", 100)
	NPCService.createHungerUI(npc)

	-- FINAL ROBUST ANIMATOR (Server-Side)
	task.spawn(function()
		local animator = humanoid:WaitForChild("Animator", 10) or Instance.new("Animator", humanoid)
		local isR15 = npc:FindFirstChild("UpperTorso") ~= nil
		
		-- DEBUG: Search for existing animations in the model
		for _, v in npc:GetDescendants() do
			if v:IsA("Animation") then
				print("[DEBUG-ANIM-EXISTING] " .. npc.Name .. " has: " .. v.Name .. " ID: " .. v.AnimationId)
			end
		end

		local animIdle = Instance.new("Animation")
		animIdle.Name = "IdleAnim"
		animIdle.AnimationId = isR15 and "http://www.roblox.com/asset/?id=507766388" or "http://www.roblox.com/asset/?id=180435571"
		
		local animWalk = Instance.new("Animation")
		animWalk.Name = "WalkAnim"
		animWalk.AnimationId = isR15 and "http://www.roblox.com/asset/?id=507777826" or "http://www.roblox.com/asset/?id=180426354"
		
		local idleTrack, walkTrack
		local success, err = pcall(function()
			idleTrack = animator:LoadAnimation(animIdle)
			walkTrack = animator:LoadAnimation(animWalk)
		end)

		if not success then
			print("[DEBUG-ANIM-ERROR] " .. npc.Name .. " failed to load animations: " .. tostring(err))
			return
		end

		idleTrack.Priority = Enum.AnimationPriority.Action4 -- Maximum priority
		walkTrack.Priority = Enum.AnimationPriority.Action4
		
		idleTrack:Play() -- Start with Idle
		print("[DEBUG-ANIM] Started for " .. npc.Name .. " | R15: " .. tostring(isR15))
		
		local rootPart = npc.PrimaryPart or npc:FindFirstChild("HumanoidRootPart")

		while npc.Parent and not npc:GetAttribute("IsDead") do
			local moveMag = humanoid.MoveDirection.Magnitude
			-- Also check velocity as fallback
			local velMag = if rootPart then rootPart.Velocity.Magnitude else 0
			
			if moveMag > 0.1 or velMag > 0.2 then
				if not walkTrack.IsPlaying then
					idleTrack:Stop(0.1)
					walkTrack:Play(0.1)
				end
			else
				if not idleTrack.IsPlaying then
					walkTrack:Stop(0.1)
					idleTrack:Play(0.1)
				end
			end
			task.wait(0.1)
		end
	end)

	task.spawn(function()
		while npc.Parent do
			if game:GetAttribute("GameStarted") then
				local hunger = npc:GetAttribute("Hunger") or 100
				if hunger <= 0 then
					NPCService.die(npc)
					break
				end
				local difficulty = game:GetAttribute("Difficulty") or Settings.DIFFICULTY or 1.0
				local decay = (Settings.HUNGER_DECAY_RATE or 0.5) * difficulty
				hunger = math.max(0, hunger - decay)
				npc:SetAttribute("Hunger", hunger)
				NPCService.updateHungerUI(npc, hunger)
			end
			task.wait(1)
		end
	end)

	-- Proximity Prompt
	local rootPart = npc.PrimaryPart or npc:FindFirstChild("HumanoidRootPart")
	if rootPart then
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Dai Rustella"
		prompt.ObjectText = npc.Name
		prompt.Style = Enum.ProximityPromptStyle.Custom
		prompt.MaxActivationDistance = 25
		prompt.RequiresLineOfSight = false
		prompt.Parent = rootPart
		prompt.Triggered:Connect(function(player)
			NPCService.handleInteraction(npc, player, prompt)
		end)
	end
	
	-- Movement Loop
	task.spawn(function()
		local PathfindingService = game:GetService("PathfindingService")
		while npc.Parent and not npc:GetAttribute("IsDead") do
			if game:GetAttribute("GameStarted") and not npc:GetAttribute("IsEating") then
				local targetBrace = NPCService.findNearestBrace(npc:GetPivot().Position)
				local goalPos
				if targetBrace then
					local center = targetBrace:GetPivot().Position
					local angle = math.random() * math.pi * 2
					local dist = math.random(Settings.NPC_MIN_DISTANCE, Settings.NPC_WALK_RADIUS)
					goalPos = center + Vector3.new(math.cos(angle) * dist, 0, math.sin(angle) * dist)
					
					local path = PathfindingService:CreatePath({AgentRadius = 2, AgentHeight = 5})
					path:ComputeAsync(npc:GetPivot().Position, goalPos)
					if path.Status == Enum.PathStatus.Success then
						for _, waypoint in path:GetWaypoints() do
							if not game:GetAttribute("GameStarted") or npc:GetAttribute("IsEating") or npc:GetAttribute("IsDead") then break end
							humanoid:MoveTo(waypoint.Position)
							
							local reached = false
							local conn;
							conn = humanoid.MoveToFinished:Connect(function() reached = true end)
							
							local t = 0
							-- Shorter timeout for individual waypoints
							while t < 2 and not reached do
								t += task.wait(0.1)
								if (npc:GetPivot().Position - waypoint.Position).Magnitude < 3 then
									reached = true
								end
							end
							if conn then conn:Disconnect() end
						end
					end
				end
			end
			task.wait(math.random(3, 7))
		end
	end)
end

function NPCService.handleInteraction(npc: Model, player: Player, prompt: ProximityPrompt)
	if npc:GetAttribute("IsEating") then return end
	local char = player.Character
	if not char then return end

	local tool = char:FindFirstChild("Rustella") or char:FindFirstChild("Rustella Bruciata")
	if tool then
		local isBurnt = (tool.Name == "Rustella Bruciata")
		tool:Destroy()
		npc:SetAttribute("IsEating", true)
		prompt.Enabled = false

		if isBurnt then
			NPCService.playSound(npc:GetPivot().Position, Settings.BURNT_FEED_SOUND, 0.35)
			NPCService.notify(player, npc.Name .. ": 'Bleah! Che schifo!'")
			local hunger = npc:GetAttribute("Hunger") or 0
			npc:SetAttribute("Hunger", math.max(0, hunger - 20))
		else
			NPCService.playSound(npc:GetPivot().Position, Settings.SOUNDS.WOAH)
			NPCService.notify(player, npc.Name .. ": 'Woah! Grazie!'")
			local hunger = npc:GetAttribute("Hunger") or 0
			npc:SetAttribute("Hunger", math.min(100, hunger + 35))
		end

		task.wait(Settings.NPC_HOLD_TIME)
		NPCService.playSound(npc:GetPivot().Position, Settings.SOUNDS.CHOMP)
		npc:SetAttribute("IsEating", false)
		prompt.Enabled = true
	else
		NPCService.notify(player, "Prendi una rustella prima!")
	end
end

function NPCService.triggerGameOver()
	print("NPCService: [ADMIN] Forced Game Over.")
	local ev = ReplicatedStorage:FindFirstChild("GameOverEvent")
	if ev then
		ev:FireAllClients()
	end
end

function NPCService.die(npc: Model)
	if npc:GetAttribute("IsDead") then return end
	npc:SetAttribute("IsDead", true)
	aliveNPCs = math.max(0, aliveNPCs - 1)
	
	NPCService.playSound(npc:GetPivot().Position, Settings.DEATH_SOUND_ID, 0.8)
	
	local remaining = 0
	for _, v in Workspace:GetDescendants() do
		if v:IsA("Model") and v.Name:lower():match("npc") and v:FindFirstChild("Humanoid") and not v:GetAttribute("IsDead") and v ~= npc then
			remaining += 1
		end
	end
	
	if remaining <= 0 then
		local ev = ReplicatedStorage:FindFirstChild("GameOverEvent")
		if ev then ev:FireAllClients() end
	end
	
	task.wait(0.3)
	for _, p in npc:GetDescendants() do
		if p:IsA("BasePart") or p:IsA("Decal") then
			TweenService:Create(p, TweenInfo.new(0.5), {Transparency = 1}):Play()
		end
	end
	task.wait(0.6)
	npc:Destroy()
end

function NPCService.createHungerUI(npc: Model)
	local head = npc:FindFirstChild("Head") or npc:FindFirstChildWhichIsA("BasePart", true)
	if not head then return end
	
	local bgui = Instance.new("BillboardGui", head)
	bgui.Name = "HungerUI"
	bgui.Size = UDim2.fromScale(5, 1.5)
	bgui.AlwaysOnTop = true
	bgui.ExtentsOffset = Vector3.new(0, 3, 0)
	
	local frame = Instance.new("Frame", bgui)
	frame.Size = UDim2.fromScale(1, 0.4)
	frame.Position = UDim2.fromScale(0, 0.6)
	frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	
	local bar = Instance.new("Frame", frame)
	bar.Name = "Bar"
	bar.Size = UDim2.fromScale(1, 1)
	bar.BackgroundColor3 = Color3.fromRGB(0, 200, 0)
	
	local nl = Instance.new("TextLabel", frame)
	nl.Size = UDim2.fromScale(1, 1)
	nl.Position = UDim2.fromScale(0, -1.2)
	nl.BackgroundTransparency = 1
	nl.Text = npc.Name
	nl.Font = Enum.Font.LuckiestGuy
	nl.TextColor3 = Color3.new(1, 1, 1)
	nl.TextScaled = true
	Instance.new("UIStroke", nl)

	local pl = Instance.new("TextLabel", frame)
	pl.Name = "Percent"
	pl.Size = UDim2.fromScale(1, 1)
	pl.BackgroundTransparency = 1
	pl.Text = "Fame: 100%"
	pl.Font = Enum.Font.GothamBold
	pl.TextColor3 = Color3.new(1, 1, 1)
	pl.TextScaled = true
end

function NPCService.updateHungerUI(npc: Model, hunger: number)
	local head = npc:FindFirstChild("Head") or npc:FindFirstChildWhichIsA("BasePart", true)
	if not head then return end
	local bgui = head:FindFirstChild("HungerUI")
	if bgui then
		local bar = bgui.Frame:FindFirstChild("Bar")
		local text = bgui.Frame:FindFirstChild("Percent")
		if bar and text then
			local p = hunger/100
			bar.Size = UDim2.fromScale(p, 1)
			bar.BackgroundColor3 = Color3.fromRGB(255,0,0):Lerp(Color3.fromRGB(0,255,0), p)
			text.Text = "Fame: " .. math.floor(hunger) .. "%"
		end
	end
end

function NPCService.notify(player: Player, message: string)
	local ev = ReplicatedStorage:FindFirstChild("NotificationEvent")
	if ev then ev:FireClient(player, message) end
end

return NPCService
