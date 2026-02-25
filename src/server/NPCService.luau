--!strict
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Settings = require(ReplicatedStorage.Shared.Settings)

local NPCService = {}

function NPCService.init()
	print("NPCService: [ULTRA BOOT] Avvio monitoraggio totale...")
	
	task.spawn(function()
		while true do
			-- Scansione di ogni oggetto nel Workspace per trovare NPC
			for _, obj in Workspace:GetDescendants() do
				if obj:IsA("Model") and not obj:GetAttribute("Initialized") then
					local name = obj.Name:lower()
					if name:match("npc") then
						print("NPCService: [FOUND] Rilevato potenziale NPC -> " .. obj.Name)
						NPCService.setupNPC(obj)
					end
				end
			end
			task.wait(2)
		end
	end)
end

function NPCService.setupNPC(npc: Model)
	npc:SetAttribute("Initialized", true)
	npc:SetAttribute("IsEating", false)
	print("NPCService: [SYSTEM] Inizializzazione forzata per -> " .. npc.Name)
	
	local humanoid = npc:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		task.wait(1) -- Aspetta un secondo per caricamento modello
		humanoid = npc:FindFirstChildOfClass("Humanoid")
		if not humanoid then
			warn("NPCService: [FAIL] NPC " .. npc.Name .. " non ha un Humanoid!")
			return
		end
	end
	
	-- Configurazione Humanoid
	humanoid.WalkSpeed = 12
	humanoid.AutoRotate = true
	
	-- Animation Setup (Detect RigType for compatibility)
	local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid)
	local walkAnim = Instance.new("Animation")
	
	print("NPCService: RigType detected for " .. npc.Name .. " -> " .. tostring(humanoid.RigType))
	
	if humanoid.RigType == Enum.HumanoidRigType.R6 then
		walkAnim.AnimationId = "rbxassetid://180426354" -- Standard R6 Walk
	else
		walkAnim.AnimationId = "rbxassetid://507767714" -- Standard R15 Walk
	end
	
	local walkTrack: AnimationTrack?
	local success, err = pcall(function()
		walkTrack = animator:LoadAnimation(walkAnim)
	end)
	
	if not success or not walkTrack then
		warn("NPCService: [FAIL] Impossibile caricare animazione per " .. npc.Name .. ": " .. tostring(err))
	else
		walkTrack.Looped = true
		print("NPCService: [OK] Animazione caricata per " .. npc.Name)
	end
	
	-- T-Pose Animation for death (Common Roblox ID)
	local tPoseAnim = Instance.new("Animation")
	tPoseAnim.AnimationId = "rbxassetid://507768375" 
	-- Track will be loaded on death to ensure smoothness
	
	local rootPart = npc.PrimaryPart or npc:FindFirstChild("HumanoidRootPart") or npc:FindFirstChildWhichIsA("BasePart", true)
	if not rootPart then
		warn("NPCService: [FAIL] NPC " .. npc.Name .. " non ha parti fisiche!")
		return
	end
	
	-- Hunger System Initialization
	npc:SetAttribute("Hunger", 100)
	NPCService.createHungerUI(npc)
	
	task.spawn(function()
		while npc.Parent do
			local hunger = npc:GetAttribute("Hunger") or 100
			
			if hunger <= 0 then
				NPCService.die(npc)
				break
			end
			
			hunger = math.max(0, hunger - (Settings.HUNGER_DECAY_RATE or 0.5))
			npc:SetAttribute("Hunger", hunger)
			NPCService.updateHungerUI(npc, hunger)
			task.wait(1)
		end
	end)
	
	-- AI Watchdog
	task.spawn(function()
		while npc.Parent do
			print(string.format("NPCService: [WATCHDOG] %s | Hunger: %.1f | Eating: %s | Rig: %s", 
				npc.Name, npc:GetAttribute("Hunger") or 0, tostring(npc:GetAttribute("IsEating")), tostring(humanoid.RigType)))
			task.wait(10)
		end
	end)
	
	-- SBLOCCO TOTALE RICORSIVO
	task.spawn(function()
		while npc.Parent do
			for _, part in npc:GetDescendants() do
				if part:IsA("BasePart") then
					part.Anchored = false
					part.CanCollide = true
				end
			end
			task.wait(5)
		end
	end)
	
	-- Setup Interazione
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Dai Rustella"
	prompt.ObjectText = npc.Name
	prompt.Style = Enum.ProximityPromptStyle.Custom
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 25
	prompt.RequiresLineOfSight = false
	prompt.Parent = rootPart
	
	prompt.Triggered:Connect(function(player)
		NPCService.handleInteraction(npc, player, prompt)
	end)
	
	-- AI Movement Loop (FORZATO CON STUCK CHECK)
	task.spawn(function()
		print("NPCService: [AI START] " .. npc.Name .. " è operativo.")
		while npc.Parent do
			if not npc:GetAttribute("IsEating") then
				local targetBrace = NPCService.findNearestBrace(rootPart.Position)
				local centerPos = rootPart.Position
				
				if targetBrace then
					local p = targetBrace.PrimaryPart or targetBrace:FindFirstChildWhichIsA("BasePart", true)
					if p then centerPos = p.Position end
				end
				
				-- Repulsion: Se è troppo vicino alla brace, forza la fuga
				local distToCenter = (rootPart.Position - centerPos).Magnitude
				local goalPos
				
				if distToCenter < Settings.NPC_MIN_DISTANCE then
					-- Direzione di fuga dalla brace
					local fleeDir = (rootPart.Position - centerPos).Unit
					if fleeDir.Magnitude == 0 or distToCenter < 1 then 
						fleeDir = Vector3.new(math.random()-0.5, 0, math.random()-0.5).Unit
					end
					goalPos = centerPos + fleeDir * (Settings.NPC_MIN_DISTANCE + math.random(5, 10))
					-- print("NPCService: " .. npc.Name .. " troppo vicino! Fuga verso: " .. tostring(goalPos))
				else
					-- Destinazione random tra min e max
					local angle = math.random() * math.pi * 2
					local dist = math.random(Settings.NPC_MIN_DISTANCE, Settings.NPC_WALK_RADIUS)
					goalPos = centerPos + Vector3.new(math.cos(angle) * dist, 0, math.sin(angle) * dist)
				end
				
				-- MOVE-TO CON TIMEOUT (Antistuck)
				humanoid:MoveTo(goalPos)
				
				-- Start walking animation
				if walkTrack then
					walkTrack:Play(0.2)
					walkTrack:AdjustSpeed(humanoid.WalkSpeed / 16)
				end
				
				-- Aspetta il completamento o timeout di 8 secondi
				local finished = false
				local conn
				conn = humanoid.MoveToFinished:Connect(function()
					finished = true
					if conn then conn:Disconnect() end
				end)
				
				local startWait = tick()
				while not finished and (tick() - startWait) < 8 do
					task.wait(0.5)
				end
				if conn then conn:Disconnect() end
				
				if walkTrack then walkTrack:Stop(0.3) end
				task.wait(Settings.NPC_IDLE_TIME or 5)
			else
				task.wait(1)
			end
		end
	end)
end

function NPCService.findNearestBrace(pos: Vector3): Model?
	local nearest = nil
	local minDist = math.huge
	
	for _, obj in Workspace:GetDescendants() do
		local name = obj.Name:lower()
		if name:match("brace") and obj:IsA("Model") then
			local part = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart", true)
			if part then
				local dist = (part.Position - pos).Magnitude
				if dist < minDist then
					minDist = dist
					nearest = obj
				end
			end
		end
	end
	return nearest
end

function NPCService.handleInteraction(npc: Model, player: Player, prompt: ProximityPrompt)
	if npc:GetAttribute("IsEating") then return end
	
	local character = player.Character
	if not character then return end
	
	local tool = character:FindFirstChild("Rustella") or character:FindFirstChild("Rustella Bruciata")
	if not tool then
		local backpack = player:FindFirstChild("Backpack")
		if backpack then
			tool = backpack:FindFirstChild("Rustella") or backpack:FindFirstChild("Rustella Bruciata")
		end
	end
	
	if tool then
		local isBurntItem = (tool.Name == "Rustella Bruciata")
		-- Consume Tool
		tool:Destroy()
		npc:SetAttribute("IsEating", true)
		prompt.Enabled = false
		
		-- Stop walk animation
		local humanoid = npc:FindFirstChildOfClass("Humanoid")
		if humanoid then
			for _, track in humanoid:GetPlayingAnimationTracks() do
				track:Stop(0.5)
			end
		end
		
		-- Play Sound
		local rootPart = npc:FindFirstChild("HumanoidRootPart")
		if isBurntItem then
			NPCService.playSound(rootPart or npc, Settings.BURNT_FEED_SOUND)
			print("NPCService: " .. npc.Name .. " ha ricevuto una rustella BRUCIATA!")
			NPCService.notify(player, npc.Name .. ": 'Bleah! Che schifo!'")
			
			-- Hunger Penalty
			local currentHunger = npc:GetAttribute("Hunger") or 0
			npc:SetAttribute("Hunger", math.max(0, currentHunger - (Settings.BURNT_PENALTY or 20)))
		else
			NPCService.playSound(rootPart or npc, Settings.SOUNDS.WOAH)
			print("NPCService: " .. npc.Name .. " ha ricevuto una rustella da " .. player.Name)
			NPCService.notify(player, npc.Name .. ": 'Woah! Grazie!'")
			
			-- Hunger Restore
			local currentHunger = npc:GetAttribute("Hunger") or 0
			npc:SetAttribute("Hunger", math.min(100, currentHunger + (Settings.FEED_RESTORE_AMOUNT or 35)))
		end
		
			-- Visual: Put rustella in hand (Horizontal & Real Model)
			local hand = npc:FindFirstChild("RightHand") or npc:FindFirstChild("Right Arm")
			if hand and hand:IsA("BasePart") then
				local visualRustella = Instance.new("Part")
				visualRustella.Name = "EatingRustellaHandle"
				visualRustella.Size = Vector3.new(0.5, 0.5, 0.5)
				visualRustella.Transparency = 1
				visualRustella.CanCollide = false
				
				-- Orientamento Orizzontale al limite della mano
				visualRustella.CFrame = hand.CFrame * CFrame.new(0.6, 0, 0)
				visualRustella.Parent = npc
				
				-- Provo a recuperare il modello originale dal primo braciere trovato
				local nearestBrace = NPCService.findNearestBrace(npc.PrimaryPart.Position)
				local modelSource = nearestBrace and nearestBrace:FindFirstChild("Model")
				local rSource = modelSource and modelSource:FindFirstChild("rustell1")
				
				if rSource then
					local clone = rSource:Clone()
					clone.Name = "Visual"
					
					-- Position model to target BEFORE welding
					if clone:IsA("Model") then
						clone:PivotTo(visualRustella.CFrame * CFrame.Angles(0, math.rad(90), 0))
					elseif clone:IsA("BasePart") then
						clone.CFrame = visualRustella.CFrame * CFrame.Angles(0, math.rad(90), 0)
					end
					
					clone.Parent = visualRustella
					
					-- Weld ALL parts of the model
					for _, p in clone:GetDescendants() do
						if p:IsA("BasePart") then
							p.Transparency = 0
							p.Anchored = false
							p.CanCollide = false
							p.Color = isBurntItem and Settings.BURNT_COLOR or Color3.fromRGB(150, 100, 80)
							
							local w = Instance.new("WeldConstraint")
							w.Part0 = visualRustella
							w.Part1 = p
							w.Parent = p
						end
					end

					-- Individual part case
					if clone:IsA("BasePart") then
						local w = Instance.new("WeldConstraint")
						w.Part0 = visualRustella
						w.Part1 = clone
						w.Parent = clone
					end
				else
					-- Fallback se non trova il modello
					visualRustella.Transparency = 0
					visualRustella.Color = isBurntItem and Settings.BURNT_COLOR or Color3.fromRGB(80, 40, 20)
					visualRustella.Size = Vector3.new(0.1, 0.1, 1.2)
					visualRustella.CFrame = visualRustella.CFrame * CFrame.Angles(0, math.rad(90), 0)
				end
				
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = hand
				weld.Part1 = visualRustella
				weld.Parent = visualRustella
			
			-- Wait hold time
			task.wait(Settings.NPC_HOLD_TIME)
			
			-- Eat: Play CHOMP sound
			NPCService.playSound(rootPart or npc, Settings.SOUNDS.CHOMP)
			visualRustella:Destroy()
			
			if isBurntItem then
				NPCService.notify(player, npc.Name .. " ha mangiato la rustella bruciata. Ne soffre!")
			else
				NPCService.notify(player, npc.Name .. " ha mangiato la rustella. Fame ripristinata!")
			end
		end
		
		task.wait(1) -- Small delay before resuming
		npc:SetAttribute("IsEating", false)
		prompt.Enabled = true
	else
		NPCService.notify(player, "Devi avere una rustella in mano per nutrire " .. npc.Name .. "!")
	end
end

function NPCService.notify(player: Player, message: string)
	local event = ReplicatedStorage:FindFirstChild("NotificationEvent")
	if event and event:IsA("RemoteEvent") then
		event:FireClient(player, message)
	end
end

function NPCService.playSound(parent: Instance, soundId: string)
	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Volume = 1 -- Max volume for visibility
	sound.RollOffMaxDistance = 100
	sound.RollOffMinDistance = 10
	sound.Parent = parent
	sound:Play()
	sound.Ended:Connect(function() sound:Destroy() end)
end

function NPCService.die(npc: Model)
	if npc:GetAttribute("IsDead") then return end
	npc:SetAttribute("IsDead", true)
	print("NPCService: " .. npc.Name .. " è morto di fame!")
	
	local humanoid = npc:FindFirstChildOfClass("Humanoid")
	if humanoid then
		-- Stop current animations
		for _, track in humanoid:GetPlayingAnimationTracks() do
			track:Stop(0.1)
		end
		
		-- Play T-Pose animation for 1 second before dying
		local animator = humanoid:FindFirstChildOfClass("Animator")
		if animator then
			local tPoseAnim = Instance.new("Animation")
			tPoseAnim.AnimationId = "rbxassetid://507768375"
			local tPoseTrack = animator:LoadAnimation(tPoseAnim)
			if tPoseTrack then
				tPoseTrack:Play(0.5) -- Smooth 0.5s transition to T-Pose
			end
		end
	end
	
	-- Play Death Sound 
	local sound = Instance.new("Sound")
	sound.SoundId = Settings.DEATH_SOUND_ID
	sound.Volume = Settings.DEATH_VOLUME or 0.8
	sound.Parent = Workspace
	sound:Play()
	
	sound.Ended:Connect(function()
		sound:Destroy()
	end)
	
	-- Wait 1 second in T-Pose
	task.wait(1)
	
	-- Fade NPC Avatar
	local fadeInfo = TweenInfo.new(0.2, Enum.EasingStyle.Linear)
	for _, part in npc:GetDescendants() do
		if part:IsA("BasePart") or part:IsA("Decal") or part:IsA("Texture") then
			TweenService:Create(part, fadeInfo, {Transparency = 1}):Play()
		end
	end
	
	-- Remove UI and NPC
	local head = npc:FindFirstChild("Head")
	if head then
		local ui = head:FindFirstChild("HungerUI")
		if ui then ui:Destroy() end
	end
	
	task.wait(0.2)
	npc:Destroy()
end

function NPCService.createHungerUI(npc: Model)
	local head = npc:FindFirstChild("Head") or npc:FindFirstChildWhichIsA("BasePart", true)
	if not head then return end
	
	-- Rimuovi eventuali vecchi UI
	local existing = head:FindFirstChild("HungerUI")
	if existing then existing:Destroy() end
	
	local bgui = Instance.new("BillboardGui")
	bgui.Name = "HungerUI"
	bgui.Size = UDim2.new(5, 0, 0.7, 0)
	bgui.Adornee = head
	bgui.AlwaysOnTop = true
	bgui.ExtentsOffset = Vector3.new(0, 2.5, 0)
	bgui.Parent = head
	
	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(1, 0, 1, 0)
	frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	frame.BorderSizePixel = 2
	frame.Parent = bgui
	
	local bar = Instance.new("Frame")
	bar.Name = "Bar"
	bar.Size = UDim2.new(1, 0, 1, 0)
	bar.BackgroundColor3 = Color3.fromRGB(0, 200, 0)
	bar.BorderSizePixel = 0
	bar.Parent = frame
	
	local text = Instance.new("TextLabel")
	text.Name = "Percent"
	text.Size = UDim2.new(1, 0, 1, 0)
	text.BackgroundTransparency = 1
	text.TextColor3 = Color3.fromRGB(255, 255, 255)
	text.Font = Enum.Font.GothamBold
	text.TextScaled = true
	text.Text = "100%"
	text.ZIndex = 3
	text.Parent = frame
	
	-- Adjust Tag size of NPC Name (if any)
	for _, d in npc:GetDescendants() do
		if d:IsA("BillboardGui") and d.Name ~= "HungerUI" then
			d.Size = UDim2.new(4, 0, 1, 0) -- Resize tags or other displays
		end
	end
end

function NPCService.updateHungerUI(npc: Model, hunger: number)
	local head = npc:FindFirstChild("Head") or npc:FindFirstChildWhichIsA("BasePart", true)
	if not head then return end
	
	local bgui = head:FindFirstChild("HungerUI")
	if bgui and bgui:IsA("BillboardGui") then
		local bar = bgui.Frame:FindFirstChild("Bar")
		local text = bgui.Frame:FindFirstChild("Percent")
		if bar and text then
			local progress = hunger / 100
			bar.Size = UDim2.new(progress, 0, 1, 0)
			bar.BackgroundColor3 = Color3.fromRGB(255, 0, 0):Lerp(Color3.fromRGB(0, 255, 0), progress)
			text.Text = math.floor(hunger) .. "%"
		end
	end
end

return NPCService
