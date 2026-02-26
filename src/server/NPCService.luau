--!strict
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local ServerStorage = game:GetService("ServerStorage")
local Settings = require(ReplicatedStorage.Shared.Settings)

local NPCService = {}
local npcsSnapshot: {Model} = {} -- Store clones here
local aliveNPCs = 0

function NPCService.init()
	print("[DEBUG-SERVER] NPCService: [ULTRA BOOT] Avvio monitoraggio totale...")

	-- CREATE SNAPSHOT OF ORIGINAL NPCs
	print("[DEBUG-SERVER] NPCService: [SNAPSHOT] Inizio scansione Workspace per template NPC...")
	for _, obj in Workspace:GetDescendants() do
		if obj:IsA("Model") and obj.Name:lower():match("npc") then
			-- Ensure it has a humanoid or is marked as NPC
			if obj:FindFirstChildOfClass("Humanoid") or obj:GetAttribute("NPC_Hunger") then
				local clone = obj:Clone()
				clone:SetAttribute("Initialized", nil)
				table.insert(npcsSnapshot, clone)
				print("[DEBUG-SERVER] NPCService: [SNAPSHOT] Salvato template -> " .. obj.Name .. " (Percorso: " .. obj:GetFullName() .. ")")
			end
		end
	end
	
	print("[DEBUG-SERVER] NPCService: [SNAPSHOT] Totale template salvati: " .. #npcsSnapshot)
	if #npcsSnapshot == 0 then
		warn("[DEBUG-SERVER] NPCService: [WARNING] Nessun NPC trovato nel Workspace durante l'init!")
	end

	task.spawn(function()
		while true do
			-- Scansione per inizializzare nuovi NPC
			for _, obj in Workspace:GetDescendants() do
				if obj:IsA("Model") and not obj:GetAttribute("Initialized") then
					local name = obj.Name:lower()
					if name:match("npc") then
						print("[DEBUG-SERVER] NPCService: [FOUND] Inizializzo -> " .. obj.Name)
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
	aliveNPCs += 1
	print("NPCService: [SYSTEM] Inizializzazione forzata per -> " .. npc.Name .. " (Vivi: " .. aliveNPCs .. ")")

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
	local loadSuccess, loadErr = pcall(function()
		walkTrack = animator:LoadAnimation(walkAnim)
	end)

	if not loadSuccess or not walkTrack then
		warn("NPCService: [FAIL] Impossibile caricare animazione per " .. npc.Name .. ": " .. tostring(loadErr))
	else
		walkTrack.Looped = true
		print("NPCService: [OK] Animazione caricata per " .. npc.Name)
	end

	-- T-Pose Animation for death (Common Roblox ID)
	local tPoseAnim = Instance.new("Animation")
	tPoseAnim.AnimationId = "rbxassetid://507768375"
	-- Track will be loaded on death to ensure smoothness

	local rootPart = npc.PrimaryPart
		or npc:FindFirstChild("HumanoidRootPart")
		or npc:FindFirstChildWhichIsA("BasePart", true)
	if not rootPart then
		warn("NPCService: [FAIL] NPC " .. npc.Name .. " non ha parti fisiche!")
		return
	end

	-- Hunger System Initialization
	npc:SetAttribute("Hunger", 100)
	NPCService.createHungerUI(npc)

	task.spawn(function()
		while npc.Parent do
			if game:GetAttribute("GameStarted") then
				local hunger = npc:GetAttribute("Hunger") or 100

				if hunger <= 0 then
					NPCService.die(npc)
					break
				end

				-- Calcola il decay rate basato sulla difficoltà
				local difficulty = game:GetAttribute("Difficulty") or Settings.DIFFICULTY or 1.0
				local decay = (Settings.HUNGER_DECAY_RATE or 0.5) * difficulty
				
				hunger = math.max(0, hunger - decay)
				npc:SetAttribute("Hunger", hunger)
				NPCService.updateHungerUI(npc, hunger)
			end
			task.wait(1)
		end
	end)

	-- AI Watchdog
	task.spawn(function()
		while npc.Parent do
			print(
				string.format(
					"NPCService: [WATCHDOG] %s | Hunger: %.1f | Eating: %s | Rig: %s",
					npc.Name,
					npc:GetAttribute("Hunger") or 0,
					tostring(npc:GetAttribute("IsEating")),
					tostring(humanoid.RigType)
				)
			)
			task.wait(10)
		end
	end)

	-- SBLOCCO E SETUP FISICA (Watchdog per prevenire jitter)
	task.spawn(function()
		local function setOwner(obj: Model)
			local hrp = obj:FindFirstChild("HumanoidRootPart")
			if hrp then
				pcall(function()
					if (hrp :: BasePart):GetNetworkOwner() ~= nil then
						(hrp :: BasePart):SetNetworkOwner(nil)
					end
				end)
			end
			for _, p in obj:GetDescendants() do
				if p:IsA("BasePart") then
					pcall(function()
						if p:GetNetworkOwner() ~= nil then
							p:SetNetworkOwner(nil)
						end
					end)
				end
			end
		end

		while npc.Parent and not npc:GetAttribute("IsDead") do
			setOwner(npc)
			task.wait(5)
		end
	end)

	task.spawn(function()
		-- Disabilita stati fisici problematici
		humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Flying, false)

		for _, part in npc:GetDescendants() do
			if part:IsA("BasePart") then
				part.Anchored = false

				-- Se c'è un CollisionGroup per gli NPC è meglio ma di base disabilitiamo collisioni
				-- tra braccia/gambe per evitare incastri
				if
					part.Name ~= "HumanoidRootPart"
					and part.Name ~= "Head"
					and part.Name ~= "Torso"
					and part.Name ~= "UpperTorso"
					and part.Name ~= "LowerTorso"
				then
					part.CanCollide = false
				end

				-- Forza il gruppo collisione se esiste, altrimenti previeni che si spingano
				pcall(function()
					part.CollisionGroup = "NPCs"
				end)
			end
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

	-- AI Movement Loop (SMOOTH PATHFOLLOWING)
	local PathfindingService = game:GetService("PathfindingService")

	task.spawn(function()
		print("NPCService: [AI START] " .. npc.Name .. " è operativo.")
		while npc.Parent do
			if game:GetAttribute("GameStarted") and not npc:GetAttribute("IsEating") then
				local targetBrace = NPCService.findNearestBrace(rootPart.Position)
				local centerPos = rootPart.Position

				if targetBrace then
					local p = targetBrace.PrimaryPart or targetBrace:FindFirstChildWhichIsA("BasePart", true)
					if p then
						centerPos = p.Position
					end
				end

				-- Calcola destinazione intelligente
				local distToCenter = (rootPart.Position - centerPos).Magnitude
				local goalPos

				if distToCenter < Settings.NPC_MIN_DISTANCE then
					-- Direzione di fuga dalla brace
					local fleeDir = (rootPart.Position - centerPos).Unit
					if fleeDir.Magnitude == 0 or distToCenter < 1 then
						fleeDir = Vector3.new(math.random() - 0.5, 0, math.random() - 0.5).Unit
					end
					goalPos = centerPos + fleeDir * (Settings.NPC_MIN_DISTANCE + math.random(5, 10))
				else
					-- Destinazione random in modo naturale
					local angle = math.random() * math.pi * 2
					local dist = math.random(Settings.NPC_MIN_DISTANCE, Settings.NPC_WALK_RADIUS)
					goalPos = centerPos + Vector3.new(math.cos(angle) * dist, 0, math.sin(angle) * dist)
				end

				-- Usa Pathfinding per aggirare ostacoli
				local path = PathfindingService:CreatePath({
					AgentRadius = 2,
					AgentHeight = 5,
					AgentCanJump = false,
					AgentCanClimb = false,
					WaypointSpacing = 4,
				})

				local success, err = pcall(function()
					path:ComputeAsync(rootPart.Position, goalPos)
				end)

				if success and path.Status == Enum.PathStatus.Success then
					local waypoints = path:GetWaypoints()

					if walkTrack then
						walkTrack:Play(0.2)
						walkTrack:AdjustSpeed(humanoid.WalkSpeed / 16)
					end

					for i, waypoint in ipairs(waypoints) do
						if not game:GetAttribute("GameStarted") or npc:GetAttribute("IsEating") or not npc.Parent then
							break
						end

						-- Salta i primissimi waypoint se troppo vicini
						if i == 1 then
							continue
						end

						humanoid:MoveTo(waypoint.Position)
						
						-- Aspetta che finisca o timeout (senza connessioni multiple che causano jitter)
						local reached = humanoid.MoveToFinished:Wait()
						if not reached then
							-- Prova a saltare se incastrato? (Opzionale, qui lo saltiamo)
						end
					end

					if walkTrack then
						walkTrack:Stop(0.3)
					end
				else
					-- Path fallito (destinazione irraggiungibile)
					task.wait(1)
				end

				-- Pausa prima di camminare di nuovo
				if not npc:GetAttribute("IsEating") then
					task.wait(Settings.NPC_IDLE_TIME or math.random(3, 7))
				end
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
	if npc:GetAttribute("IsEating") then
		return
	end

	local character = player.Character
	if not character then
		return
	end

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

		-- Play Sound (Lowered volume for Yuck per user request)
		local rootPart = npc:FindFirstChild("HumanoidRootPart")
		if isBurntItem then
			NPCService.playSound(rootPart or npc, Settings.BURNT_FEED_SOUND, 0.35) -- 65% reduction (1.0 -> 0.35)
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
			
			-- Allow immediate re-feed
			npc:SetAttribute("IsEating", false)
			local interactionPrompt = npc:FindFirstChild("InteractionPrompt", true) or npc:FindFirstChildOfClass("ProximityPrompt")
			if interactionPrompt then 
				interactionPrompt.Enabled = true 
			end
		end

		task.wait(0.5) -- Minimum buffer
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

function NPCService.playSound(parent: Instance, soundId: string, volume: number?)
	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Volume = volume or 1.0
	sound.RollOffMaxDistance = 100
	sound.RollOffMinDistance = 10
	sound.Parent = parent
	sound:Play()
	sound.Ended:Connect(function()
		sound:Destroy()
	end)
end

function NPCService.die(npc: Model)
	npc:SetAttribute("IsDead", true)
	aliveNPCs = math.max(0, aliveNPCs - 1)
	print("NPCService: " .. npc.Name .. " è morto di fame! (Rimanenti: " .. aliveNPCs .. ")")

	if game:GetAttribute("GameStarted") then
		print("NPCService: [GAME OVER] Un NPC è morto!")
		local gameOverEvent = ReplicatedStorage:FindFirstChild("GameOverEvent")
		if gameOverEvent and gameOverEvent:IsA("RemoteEvent") then
			gameOverEvent:FireAllClients()
		end
	end

	-- PLAY YUCK SOUND IMMEDIATELY ON DEATH per user request
	local head = npc:FindFirstChild("Head")
	if head then
		NPCService.playSound(head, Settings.BURNT_FEED_SOUND, 0.4)
	end

	local humanoid = npc:FindFirstChildOfClass("Humanoid")
	local rootPart = npc.PrimaryPart or npc:FindFirstChild("HumanoidRootPart")
	if humanoid and rootPart then
		-- Stop movement immediately
		humanoid:MoveTo(rootPart.Position)
		
		-- Stop current animations
		for _, track in humanoid:GetPlayingAnimationTracks() do
			track:Stop(0.1)
		end

		-- DISABLE ANIMATOR TO PREVENT HANDS RISING/GLITCHES
		local animator = humanoid:FindFirstChildOfClass("Animator")
		if animator then
			animator:Destroy() -- Permette di "bloccare" il rig fisicamente
		end

		-- ANCHOR ALL PARTS TO FREEZE POSE
		for _, p in npc:GetDescendants() do
			if p:IsA("BasePart") then
				p.Anchored = true
			end
		end
	end

	-- Play Death Sound SPATIALLY (at NPC position)
	if rootPart then
		-- Temporary Part for sound to prevent cutting
		local soundPart = Instance.new("Part")
		soundPart.Name = "DeathSoundSource"
		soundPart.Transparency = 1
		soundPart.CanCollide = false
		soundPart.Anchored = true
		soundPart.Position = rootPart.Position
		soundPart.Parent = Workspace

		local sound = Instance.new("Sound")
		sound.SoundId = Settings.DEATH_SOUND_ID
		sound.Volume = Settings.DEATH_VOLUME or 0.8
		sound.RollOffMaxDistance = 150
		sound.RollOffMinDistance = 10
		sound.Parent = soundPart
		sound:Play()
		
		sound.Ended:Connect(function()
			soundPart:Destroy()
		end)
	end

	-- Wait in T-Pose
	task.wait(2)

	-- Fade NPC Avatar (FASTER per user request)
	local fadeInfo = TweenInfo.new(0.3, Enum.EasingStyle.Linear)
	for _, part in npc:GetDescendants() do
		if part:IsA("BasePart") or part:IsA("Decal") or part:IsA("Texture") then
			TweenService:Create(part, fadeInfo, { Transparency = 1 }):Play()
		end
	end

	-- Wait for fade to complete
	task.wait(0.4)

	-- Remove UI and NPC
	local targetHeadForCleanup = npc:FindFirstChild("Head")
	if targetHeadForCleanup then
		local ui = targetHeadForCleanup:FindFirstChild("HungerUI")
		if ui then
			ui:Destroy()
		end
	end

	npc:Destroy()
end

function NPCService.createHungerUI(npc: Model)
	local targetHeadForUI = npc:FindFirstChild("Head") or npc:FindFirstChildWhichIsA("BasePart", true)
	if not targetHeadForUI then
		return
	end

	-- Rimuovi eventuali vecchi UI
	local existing = targetHeadForUI:FindFirstChild("HungerUI")
	if existing then
		existing:Destroy()
	end

	local bgui = Instance.new("BillboardGui")
	bgui.Name = "HungerUI"
	bgui.Size = UDim2.fromScale(5, 0.7)
	bgui.Adornee = targetHeadForUI
	bgui.AlwaysOnTop = true
	bgui.ExtentsOffset = Vector3.new(0, 2.5, 0)
	bgui.Parent = targetHeadForUI

	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	frame.BorderSizePixel = 2
	frame.Parent = bgui

	local bar = Instance.new("Frame")
	bar.Name = "Bar"
	bar.Size = UDim2.fromScale(1, 1)
	bar.BackgroundColor3 = Color3.fromRGB(0, 200, 0)
	bar.BorderSizePixel = 0
	bar.Parent = frame

	local text = Instance.new("TextLabel")
	text.Name = "Percent"
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.TextColor3 = Color3.fromRGB(255, 255, 255)
	text.Font = Enum.Font.GothamBold
	text.TextScaled = true
	text.Parent = frame
	text.Text = "100%"
	text.ZIndex = 3
	text.Parent = frame

	-- Adjust Tag size of NPC Name (if any)
	for _, d in npc:GetDescendants() do
		if d:IsA("BillboardGui") and d.Name ~= "HungerUI" then
			d.Size = UDim2.fromScale(4, 1) -- Resize tags or other displays
		end
	end
end

function NPCService.updateHungerUI(npc: Model, hunger: number)
	local head = npc:FindFirstChild("Head") or npc:FindFirstChildWhichIsA("BasePart", true)
	if not head then
		return
	end

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

function NPCService.reset()
	print("[DEBUG-SERVER] NPCService: [RESET] Inizio pulizia Workspace...")
	local count = 0
	
	local Players = game:GetService("Players")

	for _, npc in Workspace:GetDescendants() do
		if npc:IsA("Model") and (npc:FindFirstChild("Humanoid") or npc:GetAttribute("NPC_Hunger")) then
			-- SKIP THE ACTUAL PLAYER CHARACTER!
			if Players:GetPlayerFromCharacter(npc) then
				continue
			end

			print("[DEBUG-SERVER] NPCService: [RESET] Distruggo NPC rimasto -> " .. npc.Name)
			npc:Destroy()
			count += 1
		end
	end
	aliveNPCs = 0
	print("[DEBUG-SERVER] NPCService: [RESET] Rimossi " .. count .. " NPC.")

	print("[DEBUG-SERVER] NPCService: [RESET] Ripristino NPC dai template...")
	for _, template in npcsSnapshot do
		local newNPC = template:Clone()
		newNPC.Parent = Workspace
		print("[DEBUG-SERVER] NPCService: [RESET] Ripristinato " .. newNPC.Name .. " in posizione originale.")
	end
end

return NPCService
