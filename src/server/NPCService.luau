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
			-- skip the dog — it has a Humanoid but is managed by DogService
			if obj.Name:lower():match("dog") then continue end
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
	local npcRootPart = npc.PrimaryPart or npc:FindFirstChild("HumanoidRootPart")
	if npcRootPart then
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Dai Rustella"
		prompt.ObjectText = npc.Name
		prompt.Style = Enum.ProximityPromptStyle.Custom
		prompt.MaxActivationDistance = 25
		prompt.RequiresLineOfSight = false
		prompt.Parent = npcRootPart
		prompt.Triggered:Connect(function(player)
			NPCService.handleInteraction(npc, player, prompt)
		end)
	end
	
	-- Movement Loop (with obstacle avoidance)
	task.spawn(function()
		local PathfindingService = game:GetService("PathfindingService")

		-- Cache: collect all brace positions (refreshed each cycle)
		local function getBracePositions(): {Vector3}
			local positions = {}
			for _, obj in Workspace:GetDescendants() do
				if obj:IsA("Model") and obj.Name:lower():match("brace") then
					local pp = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart", true)
					if pp then
						table.insert(positions, pp.Position)
					end
				end
			end
			return positions
		end

		-- Check if a position is too close to any brace
		local function isTooCloseToBrace(pos: Vector3, bracePositions: {Vector3}, minDist: number): boolean
			for _, bp in bracePositions do
				if (Vector3.new(pos.X, bp.Y, pos.Z) - bp).Magnitude < minDist then
					return true
				end
			end
			return false
		end

		-- Get other NPC positions for separation
		local function getOtherNPCPositions(): {Vector3}
			local positions = {}
			for _, obj in Workspace:GetDescendants() do
				if obj:IsA("Model") and obj ~= npc and obj.Name:lower():match("npc") then
					if obj:FindFirstChildOfClass("Humanoid") and not obj:GetAttribute("IsDead") then
						local pp = obj.PrimaryPart or obj:FindFirstChild("HumanoidRootPart")
						if pp then
							table.insert(positions, pp.Position)
						end
					end
				end
			end
			return positions
		end

		-- Compute separation vector (steer away from nearby NPCs)
		local function computeSeparation(pos: Vector3): Vector3
			local sepRadius = Settings.NPC_SEPARATION_RADIUS or 6
			local steer = Vector3.zero
			local count = 0
			for _, otherPos in getOtherNPCPositions() do
				local diff = pos - otherPos
				local dist = diff.Magnitude
				if dist > 0.1 and dist < sepRadius then
					-- Weight inversely by distance (closer = stronger push)
					steer = steer + diff.Unit * (1 - dist / sepRadius)
					count += 1
				end
			end
			if count > 0 then
				steer = steer / count
				-- Cap separation offset to avoid huge jumps
				if steer.Magnitude > 4 then
					steer = steer.Unit * 4
				end
			end
			return steer
		end

		-- Raycast forward to detect obstacles
		local function isObstacleAhead(rp: BasePart): boolean
			local rayDist = Settings.NPC_OBSTACLE_RAYCAST_DISTANCE or 8
			local direction = rp.CFrame.LookVector * rayDist

			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Exclude
			-- Exclude the NPC itself from raycast
			params.FilterDescendantsInstances = {npc}

			local result = Workspace:Raycast(rp.Position, direction, params)
			if result then
				local hitPart = result.Instance
				-- Check if it's a brace or another NPC
				local hitModel = hitPart:FindFirstAncestorWhichIsA("Model")
				if hitModel then
					local hitName = hitModel.Name:lower()
					if hitName:match("brace") or hitName:match("npc") or hitName:match("salt") then
						return true
					end
				end
				-- Also flag if we're very close to any solid obstacle (< 3 studs)
				if result.Distance < 3 then
					return true
				end
			end
			return false
		end

		-- Pick a safe goal position far from braces and other NPCs
		local function pickSafeGoal(): Vector3?
			local bracePositions = getBracePositions()
			local avoidRadius = Settings.NPC_BRACE_AVOID_RADIUS or 15
			local walkRadius = Settings.NPC_WALK_RADIUS or 50
			local npcPos = npc:GetPivot().Position

			-- Try up to 12 random positions
			for _ = 1, 12 do
				local angle = math.random() * math.pi * 2
				local dist = math.random(15, walkRadius)
				local testPos = npcPos + Vector3.new(math.cos(angle) * dist, 0, math.sin(angle) * dist)

				if not isTooCloseToBrace(testPos, bracePositions, avoidRadius) then
					return testPos
				end
			end

			-- Fallback: move directly AWAY from the nearest brace
			if #bracePositions > 0 then
				local nearestBracePos = bracePositions[1]
				local minDist = math.huge
				for _, bp in bracePositions do
					local d = (npcPos - bp).Magnitude
					if d < minDist then
						minDist = d
						nearestBracePos = bp
					end
				end
				local awayDir = (npcPos - nearestBracePos)
				if awayDir.Magnitude > 0.1 then
					awayDir = Vector3.new(awayDir.X, 0, awayDir.Z).Unit
				else
					awayDir = Vector3.new(1, 0, 0)
				end
				return npcPos + awayDir * 25
			end

			-- Absolute fallback
			return npcPos + Vector3.new(math.random(-20, 20), 0, math.random(-20, 20))
		end

		local rootPart = npcRootPart

		while npc.Parent and not npc:GetAttribute("IsDead") do
			if game:GetAttribute("GameStarted") and not npc:GetAttribute("IsEating") then
				local goalPos = pickSafeGoal()

				if goalPos and rootPart then
					local path = PathfindingService:CreatePath({
						AgentRadius = 4,
						AgentHeight = 6,
						AgentCanJump = false,
						Costs = {
							Obstacle = math.huge, -- avoid tagged obstacles
						},
					})
					
					local ok, _ = pcall(function()
						path:ComputeAsync(rootPart.Position, goalPos)
					end)

					if ok and path.Status == Enum.PathStatus.Success then
						local bracePositions = getBracePositions()
						local avoidRadius = Settings.NPC_BRACE_AVOID_RADIUS or 15

						for _, waypoint in path:GetWaypoints() do
							-- Bail on state changes
							if not npc.Parent or npc:GetAttribute("IsDead") then break end
							if not game:GetAttribute("GameStarted") then break end
							if npc:GetAttribute("IsEating") then break end

							-- Skip waypoints too close to braces
							if isTooCloseToBrace(waypoint.Position, bracePositions, avoidRadius) then
								-- Instead of just skipping (which breaks the path),
								-- compute a detour point away from the brace
								local detour = waypoint.Position
								for _, bp in bracePositions do
									local diff = waypoint.Position - bp
									if diff.Magnitude < avoidRadius and diff.Magnitude > 0.1 then
										detour = bp + Vector3.new(diff.X, 0, diff.Z).Unit * (avoidRadius + 3)
									end
								end
								humanoid:MoveTo(detour)
								humanoid.MoveToFinished:Wait()
								continue
							end

							-- Real-time obstacle check via raycast
							if isObstacleAhead(rootPart) then
								-- Obstacle detected — steer sideways and break to recompute
								local rightDir = rootPart.CFrame.RightVector
								humanoid:MoveTo(rootPart.Position + rightDir * 8)
								task.wait(0.8)
								break
							end

							-- Apply NPC separation steering
							local sep = computeSeparation(rootPart.Position)
							local adjustedTarget = waypoint.Position + Vector3.new(sep.X, 0, sep.Z)
							-- Make sure the adjusted target isn't itself near a brace
							if isTooCloseToBrace(adjustedTarget, bracePositions, avoidRadius) then
								adjustedTarget = waypoint.Position
							end

							humanoid:MoveTo(adjustedTarget)

							-- Wait for movement with stuck detection
							local stuckTimeout = Settings.NPC_STUCK_TIMEOUT or 3
							local startPos = rootPart.Position
							local elapsed = 0
							local reached = false

							local conn = humanoid.MoveToFinished:Connect(function()
								reached = true
							end)

							while elapsed < stuckTimeout and not reached do
								local dt = task.wait(0.15)
								elapsed += dt

								-- Check if we arrived close enough
								if (rootPart.Position - adjustedTarget).Magnitude < 4 then
									reached = true
									break
								end

								-- Bail on state changes
								if not npc.Parent or npc:GetAttribute("IsDead") then break end
								if npc:GetAttribute("IsEating") then break end

								-- Mid-move raycast check
								if isObstacleAhead(rootPart) then
									break
								end
							end

							conn:Disconnect()

							-- Stuck detection: if we barely moved, break and recompute
							if not reached and (rootPart.Position - startPos).Magnitude < 1 then
								-- NPC is stuck — force a sidestep
								local sideDir = rootPart.CFrame.RightVector * (math.random() > 0.5 and 1 or -1)
								humanoid:MoveTo(rootPart.Position + sideDir * 10)
								task.wait(1)
								break
							end
						end
					end
				end
			end
			-- Idle wait between movement cycles
			task.wait(math.random(3, 7))
		end
	end)
end

function NPCService.handleInteraction(npc: Model, player: Player, prompt: ProximityPrompt)
	if npc:GetAttribute("IsEating") then return end
	local char = player.Character
	if not char then return end

	-- Check both Character (equipped) and Backpack (in inventory)
	-- Priority: prefer the currently equipped tool, then Salata > Natural > Burnt
	local function findRustellaTool()
		local playerChar = player.Character
		local bp = player:FindFirstChild("Backpack")

		-- 1. If something is equipped (in character), use it — any rustella type
		if playerChar then
			for _, toolName in {"Rustella Salata", "Rustella", "Rustella Bruciata"} do
				local t = playerChar:FindFirstChild(toolName)
				if t then return t end
			end
		end

		-- 2. Nothing equipped — prefer Salata, then Natural, then Burnt from backpack
		if bp then
			for _, toolName in {"Rustella Salata", "Rustella", "Rustella Bruciata"} do
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
	bgui.Size = UDim2.fromScale(5, 2.5)   -- tall enough for 3 rows
	bgui.AlwaysOnTop = true
	bgui.ExtentsOffset = Vector3.new(0, 3, 0)
	
	-- ROW 1: Salt preference (top) — direct child of bgui to avoid clipping
	local saltIcon = Instance.new("TextLabel", bgui)
	saltIcon.Name = "SaltIcon"
	saltIcon.Size = UDim2.fromScale(1, 0.3)
	saltIcon.Position = UDim2.fromScale(0, 0)
	saltIcon.BackgroundTransparency = 1
	saltIcon.Font = Enum.Font.LuckiestGuy
	saltIcon.TextColor3 = Color3.fromRGB(255, 230, 80)
	saltIcon.TextScaled = true
	local wantsSalt = npc:GetAttribute("WantsSalted") == true
	saltIcon.Text = wantsSalt and "🧂 SALATA" or "🍖 NATURALE"
	local saltStroke = Instance.new("UIStroke")
	saltStroke.Thickness = 2
	saltStroke.Parent = saltIcon

	-- ROW 2: NPC name — direct child of bgui
	local nl = Instance.new("TextLabel", bgui)
	nl.Name = "NameLabel"
	nl.Size = UDim2.fromScale(1, 0.3)
	nl.Position = UDim2.fromScale(0, 0.32)
	nl.BackgroundTransparency = 1
	nl.Text = npc.Name
	nl.Font = Enum.Font.LuckiestGuy
	nl.TextColor3 = Color3.new(1, 1, 1)
	nl.TextScaled = true
	local nameStroke = Instance.new("UIStroke")
	nameStroke.Thickness = 2
	nameStroke.Parent = nl

	-- ROW 3: Hunger bar — direct child of bgui
	local frame = Instance.new("Frame", bgui)
	frame.Name = "Frame"
	frame.Size = UDim2.fromScale(1, 0.2)
	frame.Position = UDim2.fromScale(0, 0.68)
	frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)

	local bar = Instance.new("Frame", frame)
	bar.Name = "Bar"
	bar.Size = UDim2.fromScale(1, 1)
	bar.BackgroundColor3 = Color3.fromRGB(0, 200, 0)

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
		local hungerFrame = bgui:FindFirstChild("Frame")
		local bar = hungerFrame and hungerFrame:FindFirstChild("Bar")
		local text = hungerFrame and hungerFrame:FindFirstChild("Percent")
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
	-- SaltIcon is now a direct child of bgui (not inside Frame)
	local icon = bgui:FindFirstChild("SaltIcon")
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
