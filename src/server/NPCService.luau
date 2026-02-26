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
				Workspace:SetAttribute("GameRemainingTime", remaining)
				
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

	-- Each NPC gets a unique random hunger profile so they don't all die together
	local startingHunger = math.random(70, 100)
	local hungerSpeed = 0.5 + math.random() * 1.3
	npc:SetAttribute("Hunger", startingHunger)
	npc:SetAttribute("HungerSpeed", hungerSpeed)
	-- Salt preference: random, flips periodically
	npc:SetAttribute("WantsSalted", math.random() > 0.5)
	NPCService.createHungerUI(npc)

	-- Flip salt preference every 30-90 seconds
	task.spawn(function()
		while npc.Parent do
			task.wait(math.random(30, 90))
			if not npc.Parent then break end
			npc:SetAttribute("WantsSalted", math.random() > 0.5)
			NPCService.updateSaltIcon(npc)
		end
	end)

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
				local npcHungerSpeed = npc:GetAttribute("HungerSpeed") or 1.0
				local decay = (Settings.HUNGER_DECAY_RATE or 0.5) * difficulty * npcHungerSpeed
				-- tiny tick jitter so even same-speed NPCs drift apart
				decay = decay * (0.9 + math.random() * 0.2)
				hunger = math.max(0, hunger - decay)
				npc:SetAttribute("Hunger", hunger)
				NPCService.updateHungerUI(npc, hunger)
			end
			-- randomise wait too: 0.8-1.2s, adds natural drift over time
			task.wait(0.8 + math.random() * 0.4)
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
				local goalPos = nil
				
				if targetBrace then
					local center = targetBrace:GetPivot().Position
					-- Try multiple times to find a spot well away from ALL braces
					for _ = 1, 8 do
						local angle = math.random() * math.pi * 2
						local dist = math.random(35, Settings.NPC_WALK_RADIUS)
						local testPos = center + Vector3.new(math.cos(angle) * dist, 0, math.sin(angle) * dist)
						
						-- Must be at least 35 studs from ANY brace
						local tooClose = false
						for _, b in Workspace:GetDescendants() do
							if b:IsA("Model") and b.Name:lower():match("brace") then
								if (b:GetPivot().Position - testPos).Magnitude < 35 then
									tooClose = true
									break
								end
							end
						end
						
						if not tooClose then
							goalPos = testPos
							break
						end
					end
				end
				
				-- Fallback random movement if no good spot found
				if not goalPos then
					local angle = math.random() * math.pi * 2
					local dist = math.random(10, 30)
					goalPos = npc:GetPivot().Position + Vector3.new(math.cos(angle) * dist, 0, math.sin(angle) * dist)
				end

				if goalPos then
					local path = PathfindingService:CreatePath({
						AgentRadius = 4,
						AgentHeight = 6,
						AgentCanJump = false,
					})
					path:ComputeAsync(npc:GetPivot().Position, goalPos)
					if path.Status == Enum.PathStatus.Success then
						for _, waypoint in path:GetWaypoints() do
							if not game:GetAttribute("GameStarted") or npc:GetAttribute("IsEating") or npc:GetAttribute("IsDead") then 
								break 
							end
							
							-- Skip waypoints too close to any brace
							local waypointTooClose = false
							for _, b in Workspace:GetDescendants() do
								if b:IsA("Model") and b.Name:lower():match("brace") then
									if (b:GetPivot().Position - waypoint.Position).Magnitude < 20 then
										waypointTooClose = true
										break
									end
								end
							end
							if waypointTooClose then continue end
							
							humanoid:MoveTo(waypoint.Position)
							
							local reached = false
							local conn = humanoid.MoveToFinished:Connect(function() reached = true end)
							
							local t = 0
							while t < 1.0 and not reached do
								t += task.wait(0.1)
								if (npc:GetPivot().Position - waypoint.Position).Magnitude < 4 then
									reached = true
								end
							end
							if conn then conn:Disconnect() end
							task.wait(0.05)
						end
					end
				end
			end
			task.wait(math.random(4, 9))
		end
	end)
end

function NPCService.handleInteraction(npc: Model, player: Player, prompt: ProximityPrompt)
	if npc:GetAttribute("IsEating") then return end
	local char = player.Character
	if not char then return end

	-- Check both Character (equipped) and Backpack (in inventory)
	local function findRustellaTool()
		local playerChar = player.Character
		for _, toolName in {"Rustella Salata", "Rustella Bruciata", "Rustella"} do
			if playerChar then
				local t = playerChar:FindFirstChild(toolName)
				if t then return t end
			end
			local bp = player:FindFirstChild("Backpack")
			if bp then
				local t = bp:FindFirstChild(toolName)
				if t then return t end
			end
		end
		return nil
	end
	local tool = findRustellaTool()
	if tool then
		local isBurnt   = (tool.Name == "Rustella Bruciata")
		local isSalted  = (tool.Name == "Rustella Salata")
		local wantsSalt = npc:GetAttribute("WantsSalted") == true
		tool:Destroy()
		npc:SetAttribute("IsEating", true)
		prompt.Enabled = false

		if isBurnt then
			NPCService.playSound(npc:GetPivot().Position, Settings.BURNT_FEED_SOUND, 0.35)
			NPCService.notify(player, npc.Name .. ": 'Bleah! Che schifo!'")
			local hunger = npc:GetAttribute("Hunger") or 0
			npc:SetAttribute("Hunger", math.max(0, hunger - 20))
		elseif isSalted and wantsSalt then
			-- Perfect match!
			NPCService.playSound(npc:GetPivot().Position, Settings.SOUNDS.WOAH)
			NPCService.notify(player, npc.Name .. ": 'Mmmh, salata! PERFETTA!'")
			local hunger = npc:GetAttribute("Hunger") or 0
			npc:SetAttribute("Hunger", math.min(100, hunger + 50))  -- bonus
		elseif (not isSalted) and (not wantsSalt) then
			-- Also fine — natural when they want natural
			NPCService.playSound(npc:GetPivot().Position, Settings.SOUNDS.WOAH)
			NPCService.notify(player, npc.Name .. ": 'Woah! Grazie!'")
			local hunger = npc:GetAttribute("Hunger") or 0
			npc:SetAttribute("Hunger", math.min(100, hunger + 35))
		else
			-- Wrong type (salted when they didn't want, or plain when they wanted salt)
			local msg = wantsSalt
				and npc.Name .. ": 'Dove e' il sale?!'"
				or npc.Name .. ": 'Bleah, troppo sale!'"
			NPCService.notify(player, msg)
			local hunger = npc:GetAttribute("Hunger") or 0
			npc:SetAttribute("Hunger", math.min(100, hunger + 15))  -- small gain
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
	frame.Position = UDim2.fromScale(0, 0.5)
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

	-- Salt preference icon — shown BELOW the hunger bar so it doesn't overlap the name
	local saltIcon = Instance.new("TextLabel")
	saltIcon.Name = "SaltIcon"
	saltIcon.Size = UDim2.fromScale(1, 0.35)
	saltIcon.Position = UDim2.fromScale(0, 1.05)    -- below the frame (hunger bar)
	saltIcon.BackgroundTransparency = 1
	saltIcon.Font = Enum.Font.GothamBold
	saltIcon.TextColor3 = Color3.fromRGB(255, 245, 180)
	saltIcon.TextScaled = true
	saltIcon.Parent = frame
	Instance.new("UIStroke", saltIcon)
	local wantsSalt = npc:GetAttribute("WantsSalted") == true
	saltIcon.Text = wantsSalt and "🧂 SALATA" or "🍖 NATURALE"
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

function NPCService.updateSaltIcon(npc: Model)
	local head = npc:FindFirstChild("Head") or npc:FindFirstChildWhichIsA("BasePart", true)
	if not head then return end
	local bgui = head:FindFirstChild("HungerUI")
	if not bgui then return end
	local frame = bgui:FindFirstChild("Frame")
	if not frame then return end
	local icon = frame:FindFirstChild("SaltIcon")
	if not icon then return end
	local wantsSalt = npc:GetAttribute("WantsSalted") == true
	icon.Text = wantsSalt and "🧂 SALATA" or "🍖 NATURALE"
end

function NPCService.notify(player: Player, message: string)
	local ev = ReplicatedStorage:FindFirstChild("NotificationEvent")
	if ev then
		ev:FireClient(player, message)
	end
end

return NPCService
