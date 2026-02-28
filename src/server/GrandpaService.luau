--!strict
--[[
	GrandpaService.luau
	Server-side manager per "Il Nonno".
	
	Stato 1: Nonno dorme (snora) sulla sedia a dondolo — sempre attivo dall'inizio.
	Stato 2: Quando AliveNPCs <= GRANDPA_WAKEUP_NPCS, si sveglia e si mette a mormorare.
	Stato 3: Gestito dal client via NonnoStandsUpEvent.
	
	Struttura Workspace:
	  ilNonno              (Model)
	    Head               (BasePart)  → decal "face" per le espressioni
	    HumanoidRootPart   (BasePart)
	  sediaCasa            (Model)
	    sediaSeat          (Model)
	      Seat             (BasePart o VehicleSeat)
]]

local Workspace	    = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService  = game:GetService("TweenService")

local Settings = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Settings"))

local GrandpaService = {}

-- Texture ID reali (estratti dai wrapper asset di Roblox)
-- I Settings contengono gli ID wrapper, ma la texture reale è dentro
-- 15637848 → texture 15637705   (sleeping)
-- 66330106 → texture 66329524   (awake)
-- 10860384 → texture 10749405   (angry)
local function FACE_SLEEPING()
	return Settings.GRANDPA_FACE_SLEEPING ~= "rbxassetid://0" and Settings.GRANDPA_FACE_SLEEPING or "rbxassetid://15637705"
end
local function FACE_AWAKE()
	return Settings.GRANDPA_FACE_AWAKE ~= "rbxassetid://0" and Settings.GRANDPA_FACE_AWAKE or "rbxassetid://66329524"
end
local function FACE_ANGRY()
	return Settings.GRANDPA_FACE_ANGRY ~= "rbxassetid://0" and Settings.GRANDPA_FACE_ANGRY or "rbxassetid://10749405"
end

-- Sound handles
local snoreSound:  Sound? = nil
local mumbleSound: Sound? = nil

-- Motor6D handles — valori C0 di default R6 (in piedi)
-- Vengono applicati da setStandPose quando il nonno si alza
local DEFAULT_RIGHT_HIP_C0 = CFrame.new( 1, -1, 0,  0, 0, 1,  0, 1, 0, -1, 0, 0)
local DEFAULT_LEFT_HIP_C0  = CFrame.new(-1, -1, 0,  0, 0, -1, 0, 1, 0,  1, 0, 0)

-- Ritorna i Motor6D delle anche — cerca in TUTTI i discendenti
local function getHipJoints(model: Model): (Motor6D?, Motor6D?)
	local rh: Motor6D? = nil
	local lh: Motor6D? = nil
	for _, d in model:GetDescendants() do
		if d:IsA("Motor6D") then
			local name = d.Name:lower()
			if name:find("right hip") or name == "right hip" then
				rh = d :: Motor6D
			elseif name:find("left hip") or name == "left hip" then
				lh = d :: Motor6D
			end
		end
	end
	print("[GrandpaService] getHipJoints: RightHip=" .. (rh and rh.Name or "NOT FOUND")
		.. " LeftHip=" .. (lh and lh.Name or "NOT FOUND"))
	return rh, lh
end

-- Raddrizza le gambe con tween (si alza dalla sedia) usando i valori R6 standard
local function setStandPose(model: Model, duration: number)
	local rh, lh = getHipJoints(model)
	if not rh or not lh then return end
	local info = TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(rh, info, {C0 = DEFAULT_RIGHT_HIP_C0}):Play()
	TweenService:Create(lh, info, {C0 = DEFAULT_LEFT_HIP_C0}):Play()
	print("[GrandpaService] Posa in piedi (default R6): tween " .. duration .. "s.")
end

-- ══════════════════════════════════════════════════════════════
--  DEBUG COMPLETO: stampa tutta la struttura di ilNonno
-- ══════════════════════════════════════════════════════════════
local function debugNonno(model: Model)
	print("\n══════════════ [DEBUG ilNonno] ══════════════")
	print("Modello: " .. model.Name .. "  ClassName=" .. model.ClassName)
	print("── Figli diretti ──────────────────────────")
	for _, child in model:GetChildren() do
		local extra = ""
		if child:IsA("BasePart") then
			local bp = child :: BasePart
			extra = "  Anchored=" .. tostring(bp.Anchored)
				.. "  Pos=" .. tostring(bp.Position)
		elseif child:IsA("Humanoid") then
			local h = child :: Humanoid
			extra = "  WalkSpeed=" .. h.WalkSpeed
				.. "  JumpPower=" .. h.JumpPower
				.. "  Sit=" .. tostring(h.Sit)
		end
		print("  ▶ " .. child.Name .. " [" .. child.ClassName .. "]" .. extra)
	end

	print("── Motor6D trovati (tutti i discendenti) ──")
	local m6count = 0
	for _, d in model:GetDescendants() do
		if d:IsA("Motor6D") then
			m6count += 1
			local m = d :: Motor6D
			print("  ⚙ " .. m.Name
				.. "  parent=[" .. (m.Parent and m.Parent.Name or "?") .. "]"
				.. "  Part0=" .. (m.Part0 and m.Part0.Name or "nil")
				.. "  Part1=" .. (m.Part1 and m.Part1.Name or "nil")
				.. "\n    C0=" .. tostring(m.C0))
		end
	end
	if m6count == 0 then
		print("  ⚠ NESSUN Motor6D nel modello — non è un R6 standard!")
	else
		print("  → Totale Motor6D: " .. m6count)
	end

	print("── Suoni nel modello ──────────────────────")
	local snds = 0
	for _, d in model:GetDescendants() do
		if d:IsA("Sound") then
			snds += 1
			local s = d :: Sound
			print("  🔊 " .. s.Name
				.. "  SoundId=" .. s.SoundId
				.. "  Playing=" .. tostring(s.IsPlaying)
				.. "  Vol=" .. s.Volume
				.. "  parent=" .. (s.Parent and s.Parent.Name or "?"))
		end
	end
	if snds == 0 then print("  ⚠ Nessun suono nel modello.") end

	print("── Settings SFX ───────────────────────────")
	print("  SNORE_ID      = " .. tostring(Settings.GRANDPA_SNORE_ID))
	print("  MUMBLE_ID     = " .. tostring(Settings.GRANDPA_MUMBLE_ID))
	print("  FACE_SLEEPING = " .. tostring(Settings.GRANDPA_FACE_SLEEPING))
	print("  FACE_AWAKE    = " .. tostring(Settings.GRANDPA_FACE_AWAKE))
	print("  FACE_ANGRY    = " .. tostring(Settings.GRANDPA_FACE_ANGRY))
	print("  WAKEUP_NPCS   = " .. tostring(Settings.GRANDPA_WAKEUP_NPCS))
	print("══════════════════════════════════════════════\n")
end


local function getGrandpa(): Model?
	return Workspace:FindFirstChild("ilNonno") :: Model?
end

local function getHead(grandpa: Model): BasePart?
	return grandpa:FindFirstChild("Head") :: BasePart?
end

local function setFace(grandpa: Model, textureId: string)
	local head = getHead(grandpa)
	if not head then return end
	-- Cerca la decal "face" sia come direct child che ricorsivamente
	local face: Decal? = nil
	for _, child in head:GetChildren() do
		if child:IsA("Decal") and child.Name:lower() == "face" then
			face = child :: Decal
			break
		end
	end
	-- Se non trovata come child diretto, crea una nuova decal
	if not face then
		face = Instance.new("Decal")
		face.Name = "face"
		face.Face = Enum.NormalId.Front
		face.Parent = head
		print("[GrandpaService] Decal 'face' creata nella Head (non trovata).")
	end
	face.Texture = textureId
	print("[GrandpaService] Faccia impostata: " .. textureId)
end

local function playLoopingSound(parent: BasePart, soundId: string, volume: number): Sound
	local existing = parent:FindFirstChild("GrandpaSFX")
	if existing then existing:Destroy() end

	local s = Instance.new("Sound")
	s.Name              = "GrandpaSFX"
	s.SoundId           = soundId
	s.Volume            = volume
	s.Looped            = true
	-- 3D positional audio: più sei vicino più lo senti
	s.RollOffMode       = Enum.RollOffMode.InverseTapered
	s.RollOffMinDistance = 10   -- distanza (studs) a volume pieno
	s.RollOffMaxDistance = 60   -- distanza (studs) a cui sparisce
	s.Parent            = parent
	s:Play()
	return s
end

-- Sit the Nonno on the chair: positiona manualmente + ancora + animazione seduta
local function sitOnChair(grandpa: Model)
	local sedia = Workspace:FindFirstChild("sediaCasa") :: Model?
	if not sedia then
		warn("[GrandpaService] 'sediaCasa' non trovata nel Workspace!")
		return
	end

	-- Trova qualsiasi BasePart nella sedia che sia il seat (o la superficie principale)
	local seatPart: BasePart? = nil
	for _, d in sedia:GetDescendants() do
		if d:IsA("Seat") or d:IsA("VehicleSeat") then
			seatPart = d :: BasePart
			break
		end
	end
	-- Fallback: usa il PrimaryPart o il primo BasePart della sedia
	if not seatPart then
		seatPart = sedia.PrimaryPart or sedia:FindFirstChildWhichIsA("BasePart", true) :: BasePart?
	end

	if not seatPart then
		warn("[GrandpaService] Nessuna parte trovata in sediaCasa!")
		return
	end

	local humanoid = grandpa:FindFirstChildOfClass("Humanoid")
	local root     = grandpa:FindFirstChild("HumanoidRootPart") :: BasePart?

	if not root then
		warn("[GrandpaService] HumanoidRootPart non trovata in ilNonno!")
		return
	end

	-- Ancora il Nonno in posizione Studio (NON usiamo PivotTo)
	root.Anchored = true

	if humanoid then
		humanoid.WalkSpeed = 0
		humanoid.JumpPower = 0
		humanoid.Sit = true  -- Roblox applica la posa seduta standard
	end

	print("[GrandpaService] sitOnChair: HRP.Anchored=" .. tostring(root.Anchored))
end

-- Espone la CFrame del nonno ai client per la camera (via bindable value)
local function exposeCFrameForClient(grandpa: Model)
	local root = grandpa:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then return end
	-- Salva come game attribute per il client
	local cf = root.CFrame
	game:SetAttribute("NonnoX", cf.X)
	game:SetAttribute("NonnoY", cf.Y)
	game:SetAttribute("NonnoZ", cf.Z)
	game:SetAttribute("NonnoLookX", cf.LookVector.X)
	game:SetAttribute("NonnoLookY", cf.LookVector.Y)
	game:SetAttribute("NonnoLookZ", cf.LookVector.Z)
	print(string.format("[GrandpaService] CFrame esposta: %.1f, %.1f, %.1f", cf.X, cf.Y, cf.Z))
end

function GrandpaService.init()
	-- Crea RemoteEvent per il client
	local function getOrCreate(name: string): RemoteEvent
		local ev = ReplicatedStorage:FindFirstChild(name)
		if not ev then
			ev = Instance.new("RemoteEvent")
			ev.Name = name
			ev.Parent = ReplicatedStorage
		end
		return ev :: RemoteEvent
	end

	local nonnoWakeEvent     = getOrCreate("NonnoWakeEvent")
	local nonnoStandsUpEvent = getOrCreate("NonnoStandsUpEvent")

	task.spawn(function()
		-- Attendi che ilNonno esista nel Workspace
		local grandpa: Model? = nil
		for _ = 1, 20 do
			grandpa = getGrandpa()
			if grandpa then break end
			task.wait(1)
		end

		if not grandpa then
			warn("[GrandpaService] 'ilNonno' non trovato nel Workspace dopo 20s!")
			return
		end

		local grandpaModel = grandpa :: Model

		-- ── DEBUG: stampa struttura completa all'avvio ─────────────────────
		debugNonno(grandpaModel)

		-- ── STATO 1: Nonno dorme ──────────────────────────────────────────
		-- sitOnChair ancora HRP + imposta Sit=true (che applica la posa seduta standard).
		-- NON applichiamo setSitPose: Sit=true da solo mette le gambe nella posizione corretta.
		-- NON de-ancoriamo le parti non-HRP: se lo facessimo, i capelli cadrebbero per gravità;
		-- il de-ancora avviene solo in MenuService appena prima del salto.
		sitOnChair(grandpaModel)
		setFace(grandpaModel, FACE_SLEEPING())

		-- Ancora TUTTE le BasePart subito (non solo HRP) così la fisica
		-- non le sposta durante il gioco, e i capelli non cadono.
		for _, p in grandpaModel:GetDescendants() do
			if p:IsA("BasePart") then
				p.Anchored = true
			end
		end

		-- Salva le CFrame iniziali come lista di {parte, cframe} usando riferimenti
		-- diretti alle istanze (non il nome) così funziona anche con nomi duplicati.
		local initialCFrames: {{part: BasePart, cf: CFrame}} = {}
		for _, p in grandpaModel:GetDescendants() do
			if p:IsA("BasePart") then
				table.insert(initialCFrames, { part = p :: BasePart, cf = p.CFrame })
			end
		end
		print("[GrandpaService] Salvate " .. #initialCFrames .. " CFrame iniziali.")

		local root = grandpaModel:FindFirstChild("HumanoidRootPart") :: BasePart?

		-- Il russare parte SOLO quando il gioco inizia (GameStartEvent).
		-- Così il suono non si sente durante il menu/caricamento.
		local function startSnore()
			if root and Settings.GRANDPA_SNORE_ID and Settings.GRANDPA_SNORE_ID ~= "rbxassetid://0" then
				if snoreSound then snoreSound:Stop() end
				snoreSound = playLoopingSound(root, Settings.GRANDPA_SNORE_ID, 0.5)
			end
		end

		local gameStartEvent = ReplicatedStorage:WaitForChild("GameStartEvent") :: RemoteEvent
		gameStartEvent.OnServerEvent:Connect(function()
			startSnore()  -- parte semplicemente a ogni avvio partita
		end)

		-- Aggiorna CFrame del Nonno per il client
		exposeCFrameForClient(grandpaModel)

		print("[GrandpaService] Stato 1: Nonno dorme.")

		-- ── STATO 2: watcher AliveNPCs ───────────────────────────────────
		local wakeupNPCs = Settings.GRANDPA_WAKEUP_NPCS or 2
		local woken = false

		game:GetAttributeChangedSignal("AliveNPCs"):Connect(function()
			local alive = game:GetAttribute("AliveNPCs") or 999
			if not woken and alive <= wakeupNPCs then
				woken = true
				print("[GrandpaService] Stato 2: Nonno si sveglia! (" .. alive .. " NPC rimasti)")
				setFace(grandpaModel, FACE_AWAKE())

				-- Stop russare, start mormorio
				if snoreSound then
					snoreSound:Stop()
					snoreSound:Destroy()
				end
				local rootPart = grandpaModel:FindFirstChild("HumanoidRootPart") :: BasePart?
				if rootPart then
					if Settings.GRANDPA_MUMBLE_ID and Settings.GRANDPA_MUMBLE_ID ~= "rbxassetid://0" then
						local vol = (Settings.GRANDPA_MUMBLE_VOLUME :: number?) or 1.5
						mumbleSound = playLoopingSound(rootPart, Settings.GRANDPA_MUMBLE_ID, vol)
					end
				end

				-- Notifica i client che il Nonno si è svegliato
				nonnoWakeEvent:FireAllClients()
			end

			-- ── STATO 3: ultimo NPC morto → ferma i suoni e il Nonno si alza ─
			if alive <= 0 then
				-- Ferma SUBITO russare e mormorio per evitare overlap con l'audio jumpscare
				if snoreSound then snoreSound:Stop(); snoreSound:Destroy(); snoreSound = nil end
				if mumbleSound then mumbleSound:Stop(); mumbleSound:Destroy(); mumbleSound = nil end
				print("[GrandpaService] Stato 3: suoni fermati, Nonno si alza.")
				setStandPose(grandpaModel, 1.2)  -- raddrizza le gambe in 1.2 secondi
			end
		end)

		-- ── STATO 3: listen per game over già gestito da NPCService.die() ──
		-- NonnoStandsUpEvent è già emesso lì; qui salviamo la CFrame angry per il client
		nonnoStandsUpEvent.OnServerEvent:Connect(function()
			-- Questo non dovrebbe arrivare (è server→client, non client→server)
		end)

		-- Reset: al reset del gioco, torna a Stato 1
		local resetEvent = ReplicatedStorage:WaitForChild("GameResetEvent") :: RemoteEvent
		resetEvent.OnServerEvent:Connect(function()
			woken = false
			-- Ripristina CFrame originali di tutte le parti (ancorando tutto)
			for _, entry in initialCFrames do
				entry.part.Anchored = true
				entry.part.CFrame   = entry.cf
			end
			-- Re-applica Sit=false poi Sit=true per forzare Roblox a rieseguire l'animazione
			local h = grandpaModel:FindFirstChildOfClass("Humanoid")
			if h then
				h.WalkSpeed = 0
				h.JumpPower = 0
				h.Sit = false
				task.wait()
				h.Sit = true
			end
			setFace(grandpaModel, FACE_SLEEPING())
			if mumbleSound then mumbleSound:Stop(); mumbleSound:Destroy() end
			-- Ferma il russare: ripartirà quando il giocatore premerà Gioca (GameStartEvent)
			if snoreSound then snoreSound:Stop(); snoreSound:Destroy(); snoreSound = nil end
			print("[GrandpaService] Reset: Nonno torna a dormire e posizione ripristinata.")
		end)

		print("[GrandpaService] Inizializzato con successo.")
	end)
end

-- Ferma subito tutti i suoni del Nonno (chiamato da NPCService prima del jumpscare)
function GrandpaService.stopAllSounds()
	if snoreSound then snoreSound:Stop(); snoreSound:Destroy(); snoreSound = nil end
	if mumbleSound then mumbleSound:Stop(); mumbleSound:Destroy(); mumbleSound = nil end
	print("[GrandpaService] stopAllSounds: suoni fermati.")
end

-- Usate da AdminService per testare le fasi
function GrandpaService.forceState1()
	local grandpa = getGrandpa()
	if not grandpa then warn("[GrandpaService] ilNonno non trovato!") return end
	if snoreSound then snoreSound:Stop() end
	if mumbleSound then mumbleSound:Stop() end
	setFace(grandpa, FACE_SLEEPING())
	local root = grandpa:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root and Settings.GRANDPA_SNORE_ID ~= "rbxassetid://0" then
		snoreSound = playLoopingSound(root, Settings.GRANDPA_SNORE_ID, 0.5)
	end
	local h = grandpa:FindFirstChildOfClass("Humanoid")
	if h then h.Sit = true end
	print("[GrandpaService] forceState1: Nonno dorme.")
end

function GrandpaService.forceState2()
	local grandpa = getGrandpa()
	if not grandpa then warn("[GrandpaService] ilNonno non trovato!") return end
	if snoreSound then snoreSound:Stop(); snoreSound:Destroy() end
	setFace(grandpa, FACE_AWAKE())
	local root = grandpa:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root and Settings.GRANDPA_MUMBLE_ID ~= "rbxassetid://0" then
		mumbleSound = playLoopingSound(root, Settings.GRANDPA_MUMBLE_ID, 0.4)
	end
	local ev = game:GetService("ReplicatedStorage"):FindFirstChild("NonnoWakeEvent")
	if ev then (ev :: RemoteEvent):FireAllClients() end
	print("[GrandpaService] forceState2: Nonno sveglio.")
end

-- Espongo il debug per AdminService (comando :nonnodbg)
function GrandpaService.debugDump()
	local grandpa = getGrandpa()
	if grandpa then
		debugNonno(grandpa)
	else
		warn("[GrandpaService] debugDump: ilNonno non trovato!")
	end
end

return GrandpaService
