--!strict
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Settings = require(ReplicatedStorage.Shared.Settings)

local BraceService = {}

-- Setup RemoteEvent for Notifications
local notificationEvent = ReplicatedStorage:FindFirstChild("NotificationEvent") or Instance.new("RemoteEvent")
notificationEvent.Name = "NotificationEvent"
notificationEvent.Parent = ReplicatedStorage

function BraceService.init()
	print("BraceService: Inizializzazione...")
	
	-- Funzione interna per cercare i bracieri
	local function scanForBraces()
		local count = 0
		for _, object in Workspace:GetDescendants() do
			if object:IsA("Model") then
				local name = object.Name
				local lowerName = string.lower(name)
				
				if name == "Brace" or name == "brace" or string.find(lowerName, "brace") or string.find(lowerName, "braciere") then
					print("BraceService: Trovato modello corrispondente -> " .. object:GetFullName())
					BraceService.setupBrace(object)
					count = count + 1
				end
			end
		end
		return count
	end
	
	-- Primo tentativo immediato
	local found = scanForBraces()
	print("BraceService: Inizializzati " .. found .. " bracieri al primo scan.")
	
	-- Se non ne abbiamo trovati, riproviamo (caricamento asincrono?)
	if found == 0 then
		task.spawn(function()
			for i = 1, 5 do
				task.wait(1)
				found = scanForBraces()
				if found > 0 then
					print("BraceService: Trovati " .. found .. " bracieri nello scan di recupero #" .. i)
					break
				end
			end
		end)
	end
	
	-- Watcher per nuovi inserimenti
	Workspace.DescendantAdded:Connect(function(object)
		if object:IsA("Model") then
			local name = object.Name
			local lowerName = string.lower(name)
			if name == "Brace" or name == "brace" or string.find(lowerName, "brace") or string.find(lowerName, "braciere") then
				print("BraceService: Nuovo braciere detected: " .. object:GetFullName())
				BraceService.setupBrace(object)
			end
		end
	end)
end

function BraceService.setRustelleVisibility(brace: Model, visible: boolean)
	local rustelleModel = brace:FindFirstChild("Model") :: Model
	if not rustelleModel then return end
	
	local transparency = visible and 0 or 1
	
	for i = 1, 4 do
		local r = rustelleModel:FindFirstChild("rustell" .. i)
		if r then
			if r:IsA("BasePart") then
				r.Transparency = transparency
			elseif r:IsA("Model") then
				-- Se è un modello, impostiamo la trasparenza a tutte le sue parti
				for _, part in r:GetDescendants() do
					if part:IsA("BasePart") then
						part.Transparency = transparency
					end
				end
			end
		end
	end
end

function BraceService.notify(player: Player, message: string)
	notificationEvent:FireClient(player, message)
end

function BraceService.playSound(parent: Instance, soundId: string, looped: boolean?)
	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Volume = 0.5
	sound.Looped = looped or false
	sound.Parent = parent
	sound:Play()
	
	if not sound.Looped then
		sound.Ended:Connect(function()
			sound:Destroy()
		end)
	else
		-- Ensure looped sounds are cleaned up if a new one is started on same parent
		local existing = parent:FindFirstChild(sound.Name)
		if existing and existing ~= sound then
			existing:Destroy()
		end
	end
	return sound
end

function BraceService.setupBrace(brace: Model)
	if brace:GetAttribute("Initialized") then return end
	brace:SetAttribute("Initialized", true)
	
	-- Initial State
	brace:SetAttribute("HasCoal", false)
	brace:SetAttribute("SaltActive", false)   -- salt state for the whole brace
	for i = 1, 4 do
		brace:SetAttribute("Slot" .. i .. "_Status", Settings.STATUS.EMPTY)
		brace:SetAttribute("Slot" .. i .. "_StartTime", 0)
		brace:SetAttribute("Slot" .. i .. "_CookedTime", 0)
		brace:SetAttribute("Slot" .. i .. "_Salted", false)
	end
	
	-- Store original colors
	local rustelleModel = brace:FindFirstChild("Model") :: Model
	if rustelleModel then
		for i = 1, 4 do
			local r = rustelleModel:FindFirstChild("rustell" .. i)
			if r then
				for _, part in r:GetDescendants() do
					if part:IsA("BasePart") and part.Name ~= "stecca" then
						part:SetAttribute("CookedColor", part.Color)
					end
				end
			end
		end
	end
	
	BraceService.setRustelleVisibility(brace, false)
	
	-- HIDE EXISTING FIRE OBJECT INITIALLY (Robustly)
	task.spawn(function()
		local fireObject = brace:WaitForChild("Fire", 5)
		if fireObject and fireObject:IsA("ParticleEmitter") then
			fireObject.Enabled = false
			fireObject:SetAttribute("OriginalRate", fireObject.Rate)
			fireObject.Rate = 0
		elseif not fireObject then
			-- Try recursive search if WaitForChild fails on top level
			local foundFire = brace:FindFirstChild("Fire", true)
			if foundFire and foundFire:IsA("ParticleEmitter") then
				foundFire.Enabled = false
				foundFire:SetAttribute("OriginalRate", foundFire.Rate)
				foundFire.Rate = 0
			end
		end
	end)
	
	local parentPart = brace.PrimaryPart or brace:FindFirstChildWhichIsA("BasePart", true)
	if not parentPart then return end
	
	-- Clean old prompts
	for _, child in parentPart:GetChildren() do
		if child:IsA("ProximityPrompt") then
			child:Destroy()
		end
	end
	
	-- 1. Coal/Insert Prompt
	local insertPrompt = Instance.new("ProximityPrompt")
	insertPrompt.Name = "InsertPrompt"
	insertPrompt.ActionText = "Inserisci Carbone"
	insertPrompt.ObjectText = "Braciere"
	insertPrompt.Style = Enum.ProximityPromptStyle.Custom
	insertPrompt.KeyboardKeyCode = Enum.KeyCode.E
	insertPrompt.HoldDuration = 0.5
	insertPrompt.RequiresLineOfSight = false
	insertPrompt.MaxActivationDistance = Settings.INTERACTION_DISTANCE
	insertPrompt.Parent = parentPart
	
	-- 2. Take Prompt
	local takePrompt = Instance.new("ProximityPrompt")
	takePrompt.Name = "TakePrompt"
	takePrompt.ActionText = "Prendi Rustella"
	takePrompt.ObjectText = "Pronta!"
	takePrompt.Style = Enum.ProximityPromptStyle.Custom
	takePrompt.KeyboardKeyCode = Enum.KeyCode.R
	takePrompt.HoldDuration = 1.2
	takePrompt.Enabled = false
	takePrompt.RequiresLineOfSight = false
	takePrompt.MaxActivationDistance = Settings.INTERACTION_DISTANCE
	takePrompt.Parent = parentPart
	
	takePrompt.MaxActivationDistance = Settings.INTERACTION_DISTANCE
	takePrompt.Parent = parentPart
	
	-- No more RekindlePrompt (Q), everything is on insertPrompt (E) as requested

	
	-- Helper: start the fire opacity watcher for the coal timer
	local function startCoalTimer()
		brace:SetAttribute("CoalStartTime", os.clock())

		
		-- Find fire by CLASS (works regardless of instance name)
		local fireObj = brace:FindFirstChildWhichIsA("Fire", true)
			if not fireObj then fireObj = brace:FindFirstChildWhichIsA("ParticleEmitter", true) end
		
		task.spawn(function()
			local duration = Settings.COAL_DURATION or 40
			while true do
				local elapsed = os.clock() - (brace:GetAttribute("CoalStartTime") or os.clock())
				local remaining = duration - elapsed
				local ratio = math.clamp(remaining / duration, 0, 1)
				
				-- Update Fire opacity linearly
				if fireObj then
					if fireObj:IsA("ParticleEmitter") then
						local maxRate = fireObj:GetAttribute("OriginalRate") or 50
						fireObj.Rate = ratio * maxRate
						fireObj.Enabled = ratio > 0
					elseif fireObj:IsA("Fire") then
						-- Ridotto: Size 1.0-3.5 (era 1.5-4.5), Heat 2-7
						fireObj.Size = 1.0 + (ratio * 2.5)
						fireObj.Heat = 2 + (ratio * 5)
						fireObj.Enabled = ratio > 0.02
						if elapsed % 5 < 0.5 then
							print(string.format("[DEBUG] Fire - Ratio: %.2f, Size: %.1f, Heat: %.1f", ratio, fireObj.Size, fireObj.Heat))
						end
					end
				end
				
				if remaining <= 0 then
					-- Coal exhausted — extinguish and restore E-key prompt
					brace:SetAttribute("HasCoal", false)
					if fireObj then
						if fireObj:IsA("ParticleEmitter") then
							fireObj.Enabled = false
							fireObj.Rate = 0
						elseif fireObj:IsA("Fire") then
						fireObj.Size = 1.5
						fireObj.Heat = 2
						fireObj.Enabled = false
					end
					print("[DEBUG] Fire Extinguished")
					end
					local coalSound = parentPart:FindFirstChild("CoalLoopSound")
					if coalSound then
						coalSound:Stop()
						coalSound:Destroy()
					end
					
					-- Restore E-key: show 'Inserisci Carbone' again so player can relight
					insertPrompt.ActionText = "Inserisci Carbone"
					insertPrompt.Enabled = true
					print("[BraceService] Carbonella esaurita, brace spenta. Premi E per riaccendere.")
					return
				end
				
				task.wait(0.5)
			end
		end)
	end
	
	BraceService.setupSpawn(parentPart)
	
	insertPrompt.Triggered:Connect(function(player)
		local hasCoal = brace:GetAttribute("HasCoal")
		if not hasCoal then
			brace:SetAttribute("HasCoal", true)
			BraceService.notify(player, "Hai inserito il carbone!")
			local s = BraceService.playSound(parentPart, Settings.SOUNDS.COAL, true)
			s.Name = "CoalLoopSound"
			
			-- Gradual Fire Fade-In — search by class, ignore name
			local fireObj = brace:FindFirstChildWhichIsA("Fire", true)
				if not fireObj then fireObj = brace:FindFirstChildWhichIsA("ParticleEmitter", true) end
			
			print("[DEBUG] Coal inserted (E-key). Fire found:", fireObj and fireObj.Name or "NONE")
			
			if fireObj then
				if fireObj:IsA("ParticleEmitter") then
					fireObj.Enabled = true
					local targetRate = fireObj:GetAttribute("OriginalRate") or 50
					task.spawn(function()
						for i = 1, 20 do
							fireObj.Rate = (i / 20) * targetRate
							task.wait(0.1)
						end
						fireObj.Rate = targetRate
						fireObj:SetAttribute("OriginalRate", targetRate)
					end)
				elseif fireObj:IsA("Fire") then
					fireObj.Size = 3.0   -- ridotto da 4.5
					fireObj.Heat = 7
					fireObj.Enabled = true
					print("[DEBUG] Fire activated (Size 3.0, Heat 7)")
				end
			end
			startCoalTimer()
			BraceService.updatePrompts(brace, insertPrompt, takePrompt)
		else
			BraceService.handleInsert(brace, player, insertPrompt, takePrompt)
		end
	end)
	
	takePrompt.Triggered:Connect(function(player)
		BraceService.handleTake(brace, player, insertPrompt, takePrompt)
	end)

	BraceService.updatePrompts(brace, insertPrompt, takePrompt)
end

function BraceService.setupSpawn(part: BasePart)
	local spawnName = "BraceSpawn"
	local existingSpawn = Workspace:FindFirstChild(spawnName)
	
	local spawnLoc: SpawnLocation
	if existingSpawn and existingSpawn:IsA("SpawnLocation") then
		spawnLoc = existingSpawn
	else
		spawnLoc = Instance.new("SpawnLocation")
		spawnLoc.Name = spawnName
		spawnLoc.Size = Vector3.new(6, 1, 6)
		spawnLoc.Transparency = 1
		spawnLoc.CanCollide = false
		spawnLoc.Anchored = true
		spawnLoc.Parent = Workspace
	end
	
	-- Posiziona lo spawn davanti alla parte (offset di 5 stud)
	spawnLoc.CFrame = part.CFrame * CFrame.new(0, 0, 5) * CFrame.Angles(0, math.pi, 0)
end

function BraceService.updatePrompts(brace: Model, insertPrompt: ProximityPrompt, takePrompt: ProximityPrompt)
	local hasCoal = brace:GetAttribute("HasCoal")
	local busySlots = 0
	local readySlots = 0
	
	for i = 1, 4 do
		local status = brace:GetAttribute("Slot" .. i .. "_Status")
		if status ~= Settings.STATUS.EMPTY then
			busySlots = busySlots + 1
		end
		if status == Settings.STATUS.COOKED or status == "Burnt" then
			readySlots = readySlots + 1
		end
	end
	
	if not hasCoal then
		insertPrompt.ActionText = "Inserisci Carbone"
		insertPrompt.Enabled = true
	else
		insertPrompt.ActionText = "Inserisci Rustella (" .. busySlots .. "/4)"
		insertPrompt.Enabled = (busySlots < 4)
	end
	
	takePrompt.Enabled = (readySlots > 0)
	if readySlots > 0 then
		takePrompt.ActionText = "Prendi Rustella (" .. readySlots .. " pronte)"
	end
end

function BraceService.handleInsert(brace: Model, player: Player, insertPrompt: ProximityPrompt, takePrompt: ProximityPrompt)
	local slotIndex = 0
	for i = 1, 4 do
		if brace:GetAttribute("Slot" .. i .. "_Status") == Settings.STATUS.EMPTY then
			slotIndex = i
			break
		end
	end
	
	if slotIndex == 0 then return end
	
	print("BraceService: Inserimento in Slot " .. slotIndex)
	brace:SetAttribute("Slot" .. slotIndex .. "_Status", Settings.STATUS.COOKING)
	brace:SetAttribute("Slot" .. slotIndex .. "_StartTime", os.clock())
	
	BraceService.playSound(insertPrompt.Parent, Settings.SOUNDS.INSERT)
	BraceService.notify(player, "Hai inserito una rustella (" .. slotIndex .. "/4)")
	
	-- Show visual
	local rustelleModel = brace:FindFirstChild("Model") :: Model
	local slotModel = rustelleModel and rustelleModel:FindFirstChild("rustell" .. slotIndex)
	if slotModel then
		for _, p in slotModel:GetDescendants() do
			if p:IsA("BasePart") then
				p.Transparency = 0
				if p.Name ~= "stecca" then p.Color = Settings.RAW_COLOR end
			end
		end
	end
	
	BraceService.updatePrompts(brace, insertPrompt, takePrompt)
	
	-- Cooking Task
	task.spawn(function()
		local cookingTime = Settings.COOKING_TIME
		local start = os.clock()
		local totalPausedTime = 0       -- accumulated seconds spent without coal
		local pauseStart: number? = nil -- when the current pause began
		
		while true do
			local now = os.clock()
			
			-- Track pause start/end
			if not brace:GetAttribute("HasCoal") then
				if pauseStart == nil then
					pauseStart = now
				end
				task.wait(0.3)
				continue
			else
				if pauseStart ~= nil then
					-- Coal was just re-lit: accumulate the pause duration
					totalPausedTime += now - pauseStart
					pauseStart = nil
				end
			end
			
			-- Actual elapsed cooking time (excluding pauses)
			local elapsed = now - start - totalPausedTime
			if elapsed >= cookingTime then break end
			
			local alpha = elapsed / cookingTime
			if slotModel then
				for _, p in slotModel:GetDescendants() do
					if p:IsA("BasePart") and p.Name ~= "stecca" then
						local cookedColor = p:GetAttribute("CookedColor") or p.Color
						p.Color = Settings.RAW_COLOR:Lerp(cookedColor, alpha)
					end
				end
			end
			task.wait(0.1)
			if brace:GetAttribute("Slot" .. slotIndex .. "_Status") == Settings.STATUS.EMPTY then return end
		end
		
		-- Cooked State
		brace:SetAttribute("Slot" .. slotIndex .. "_Status", Settings.STATUS.COOKED)
		brace:SetAttribute("Slot" .. slotIndex .. "_CookedTime", os.clock())
		BraceService.playSound(insertPrompt.Parent, Settings.SOUNDS.COOKED)
		BraceService.updatePrompts(brace, insertPrompt, takePrompt)
		
		-- Gradual Burning Transition (Lerp to Black)
		local burnStart = os.clock()
		local burningTime = Settings.BURNING_TIME
		
		while (os.clock() - burnStart) < burningTime do
			local alpha = (os.clock() - burnStart) / burningTime
			if brace:GetAttribute("Slot" .. slotIndex .. "_Status") ~= Settings.STATUS.COOKED then return end -- Taken during burning
			
			if slotModel then
				for _, p in slotModel:GetDescendants() do
					if p:IsA("BasePart") and p.Name ~= "stecca" then
						local cookedColor = p:GetAttribute("CookedColor") or p.Color
						p.Color = cookedColor:Lerp(Settings.BURNT_COLOR, alpha)
					end
				end
			end
			task.wait(0.1)
		end
		
		-- Final Burnt State
		if brace:GetAttribute("Slot" .. slotIndex .. "_Status") == Settings.STATUS.COOKED then
			brace:SetAttribute("Slot" .. slotIndex .. "_Status", "Burnt")
			if slotModel then
				for _, p in slotModel:GetDescendants() do
					if p:IsA("BasePart") and p.Name ~= "stecca" then
						p.Color = Settings.BURNT_COLOR
					end
				end
			end
			BraceService.updatePrompts(brace, insertPrompt, takePrompt)
		end
	end)
end

function BraceService.handleTake(brace: Model, player: Player, insertPrompt: ProximityPrompt, takePrompt: ProximityPrompt)
	-- Find oldest ready slot
	local targetSlot = 0
	local oldestTime = math.huge
	
	for i = 1, 4 do
		local status = brace:GetAttribute("Slot" .. i .. "_Status")
		if status == Settings.STATUS.COOKED or status == "Burnt" then
			local t = brace:GetAttribute("Slot" .. i .. "_CookedTime") or 0
			if t < oldestTime then
				oldestTime = t
				targetSlot = i
			end
		end
	end
	
	if targetSlot == 0 then return end
	
	local status = brace:GetAttribute("Slot" .. targetSlot .. "_Status")
	local isBurnt = (status == "Burnt")
	local isSalted = brace:GetAttribute("Slot" .. targetSlot .. "_Salted") == true
	
	-- Give Tool logic
	local toolName = isBurnt and "Rustella Bruciata"
		or isSalted and "Rustella Salata"
		or "Rustella"
	local rustelleModel = brace:FindFirstChild("Model") :: Model
	local rOriginal = rustelleModel and rustelleModel:FindFirstChild("rustell" .. targetSlot)
	
	if rOriginal then
	local tool = Instance.new("Tool")
			tool.Name = toolName
		tool.RequiresHandle = true
		
		local handle = Instance.new("Part")
		handle.Name = "Handle"
		handle.Size = Vector3.new(0.5, 0.5, 0.5)
		handle.Transparency = 1
		handle.CanCollide = false
		handle.Parent = tool
		
		local visualClone = rOriginal:Clone()
		visualClone.Name = "Visual"
		if visualClone:IsA("Model") then
			visualClone:PivotTo(handle.CFrame * CFrame.Angles(0, math.rad(90), 0))
		elseif visualClone:IsA("BasePart") then
			visualClone.CFrame = handle.CFrame * CFrame.Angles(0, math.rad(90), 0)
		end
		visualClone.Parent = tool
		
		for _, p in visualClone:GetDescendants() do
			if p:IsA("BasePart") then
				p.Transparency = 0
				p.Anchored = false
				p.CanCollide = false
				if isBurnt then
					p.Color = Settings.BURNT_COLOR
				elseif isSalted then
					-- Slightly lighter/whitish tint for salted rustelle
					p.Color = p.Color:Lerp(Color3.new(1,1,1), 0.25)
				end
				local w = Instance.new("WeldConstraint")
				w.Part0 = handle
				w.Part1 = p
				w.Parent = p
			end
		end
		
		tool.Parent = player:WaitForChild("Backpack")
		
		-- Update player counter
		local currentCount = player:GetAttribute("RustelleCount") or 0
		player:SetAttribute("RustelleCount", currentCount + 1)
		
		BraceService.notify(player,
			isBurnt and "Hai preso una rustella... ma è bruciata!"
			or isSalted and "Hai preso una rustella salata!"
			or "Hai preso una rustella cotta!")
	end
	
	-- Reset slot (including salt)
	brace:SetAttribute("Slot" .. targetSlot .. "_Status", Settings.STATUS.EMPTY)
	brace:SetAttribute("Slot" .. targetSlot .. "_Salted", false)
	local slotModel = rustelleModel and rustelleModel:FindFirstChild("rustell" .. targetSlot)
	if slotModel then
		for _, p in slotModel:GetDescendants() do
			if p:IsA("BasePart") then 
				p.Transparency = 1 
			end
		end
	end
	
	BraceService.updatePrompts(brace, insertPrompt, takePrompt)
end

function BraceService.stealMeat(brace: Model)
	local occupied = {}
	for i = 1, 4 do
		if brace:GetAttribute("Slot" .. i .. "_Status") ~= Settings.STATUS.EMPTY then
			table.insert(occupied, i)
		end
	end
	
	if #occupied == 0 then return nil end
	
	local targetSlot = occupied[math.random(1, #occupied)]
	brace:SetAttribute("Slot" .. targetSlot .. "_Status", Settings.STATUS.EMPTY)
	
	local rustelleModel = brace:FindFirstChild("Model") :: Model
	local slotModel = rustelleModel and rustelleModel:FindFirstChild("rustell" .. targetSlot)
	if slotModel then
		for _, p in slotModel:GetDescendants() do
			if p:IsA("BasePart") then p.Transparency = 1 end
		end
	end
	
	-- Update prompts if they exist on the primary part
	local parentPart = brace.PrimaryPart or brace:FindFirstChildWhichIsA("BasePart", true)
	if parentPart then
		local insertP = parentPart:FindFirstChild("InsertPrompt")
		local takeP = parentPart:FindFirstChild("TakePrompt")
		if insertP and takeP then
			BraceService.updatePrompts(brace, insertP, takeP)
		end
	end
	
	return slotModel
end

function BraceService.resetAll()
	print("BraceService: [RESET] Resetting all braces...")
	for _, obj in Workspace:GetDescendants() do
		if obj:IsA("Model") then
			local name = obj.Name
			local lowerName = string.lower(name)
			if name == "Brace" or name == "brace" or string.find(lowerName, "brace") or string.find(lowerName, "braciere") then
				BraceService.resetBrace(obj)
			end
		end
	end
end

function BraceService.resetBrace(brace: Model)
	brace:SetAttribute("HasCoal", false)
	for i = 1, 4 do
		brace:SetAttribute("Slot" .. i .. "_Status", Settings.STATUS.EMPTY)
		brace:SetAttribute("Slot" .. i .. "_StartTime", 0)
		brace:SetAttribute("Slot" .. i .. "_CookedTime", 0)
	end
	
	-- Reset Visuals
	BraceService.setRustelleVisibility(brace, false)
	local fireObj = brace:FindFirstChild("Fire", true)
	if fireObj and fireObj:IsA("ParticleEmitter") then
		fireObj.Enabled = false
		fireObj.Rate = 0
	end
	
	-- Stop Sounds
	local parentPart = brace.PrimaryPart or brace:FindFirstChildWhichIsA("BasePart", true)
	if parentPart then
		local coalLoop = parentPart:FindFirstChild("CoalLoopSound")
		if coalLoop then coalLoop:Destroy() end
		
		-- Update prompts
		local insertP = parentPart:FindFirstChild("InsertPrompt")
		local takeP = parentPart:FindFirstChild("TakePrompt")
		if insertP and takeP then
			BraceService.updatePrompts(brace, insertP, takeP)
		end
	end
	print("BraceService: [RESET] Brace reset -> " .. brace.Name)
end

-- PUBLIC API: Called by SaltService when the player interacts with the Salt model.
-- Marks every non-empty slot in the brace as salted and adds a subtle white tint.
function BraceService.applySalt(brace: Model)
	brace:SetAttribute("SaltActive", true)
	local rustelleModel = brace:FindFirstChild("Model") :: Model
	for i = 1, 4 do
		local status = brace:GetAttribute("Slot" .. i .. "_Status")
		if status ~= nil and status ~= Settings.STATUS.EMPTY then
			brace:SetAttribute("Slot" .. i .. "_Salted", true)
			-- Visual: lighten the meat colour slightly
			if rustelleModel then
				local slot = rustelleModel:FindFirstChild("rustell" .. i)
				if slot then
					for _, p in slot:GetDescendants() do
						if p:IsA("BasePart") and p.Name ~= "stecca" then
							p.Color = p.Color:Lerp(Color3.new(1, 1, 1), 0.2)
						end
					end
				end
			end
		end
	end
	print("[BraceService] Sale applicato a " .. brace.Name)
end

return BraceService
