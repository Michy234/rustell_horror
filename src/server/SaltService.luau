--!strict
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Settings = require(ReplicatedStorage.Shared.Settings)
local BraceService = require(script.Parent:WaitForChild("BraceService"))

local SaltService = {}

local SALT_SOUND_ID = Settings.SALT_SOUND_ID or "rbxassetid://6042053626"

local function playSaltSound(parent: BasePart)
	local s = Instance.new("Sound")
	s.SoundId  = SALT_SOUND_ID
	s.Volume   = 0.9
	s.Looped   = false
	s.Parent   = parent
	s:Play()
	s.Ended:Connect(function() s:Destroy() end)
end

local function getAllBraces(): {Model}
	local braces = {}
	for _, obj in Workspace:GetDescendants() do
		if obj:IsA("Model") and obj.Name:lower():find("brace") then
			table.insert(braces, obj)
		end
	end
	return braces
end

-- Returns true if any brace has at least one non-empty slot
local function anyBraceHasMeat(): boolean
	for _, obj in Workspace:GetDescendants() do
		if obj:IsA("Model") and obj.Name:lower():find("brace") then
			for i = 1, 4 do
				if obj:GetAttribute("Slot" .. i .. "_Status") ~= Settings.STATUS.EMPTY then
					return true
				end
			end
		end
	end
	return false
end

function SaltService.init()
	local saltModel: Model? = Workspace:FindFirstChild("Salt") :: Model?
	if not saltModel then
		task.spawn(function()
			for _ = 1, 10 do
				task.wait(1)
				saltModel = Workspace:FindFirstChild("Salt") :: Model?
				if saltModel then break end
			end
			if saltModel then
				SaltService.setupSalt(saltModel)
			else
				warn("[SaltService] Modello 'Salt' non trovato nel Workspace!")
			end
		end)
	else
		SaltService.setupSalt(saltModel)
	end
end

function SaltService.setupSalt(saltModel: Model)
	local root = saltModel.PrimaryPart or saltModel:FindFirstChildWhichIsA("BasePart", true)
	if not root then
		warn("[SaltService] Salt model non ha BasePart.")
		return
	end

	-- Remove any existing prompt
	for _, c in root:GetChildren() do
		if c:IsA("ProximityPrompt") then c:Destroy() end
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText          = "Aggiungi Sale"
	prompt.ObjectText          = "Sale  [F]"
	prompt.Style               = Enum.ProximityPromptStyle.Custom
	prompt.KeyboardKeyCode     = Enum.KeyCode.F   -- F, separato da E (carbone/rustella)
	prompt.HoldDuration        = 0.8
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance = 8
	prompt.Enabled = false   -- abilitato solo se c'è carne sulla brace
	prompt.Parent = root

	-- Watcher: abilita il prompt solo quando c'è carne e non è già stato usato
	task.spawn(function()
		while prompt.Parent do
			if anyBraceHasMeat() then
				prompt.Enabled = true
			else
				prompt.Enabled = false
			end
			task.wait(0.5)
		end
	end)

	prompt.Triggered:Connect(function(player: Player)
		-- Removed SaltUsed setting to allow reusability
		prompt.Enabled = false

		playSaltSound(root)

		local notifEv = ReplicatedStorage:FindFirstChild("NotificationEvent")
		if notifEv then
			notifEv:FireClient(player, "🧂 Sale aggiunto alle rustelle!")
		end

		for _, brace in getAllBraces() do
			BraceService.applySalt(brace)
		end

		print("[SaltService] " .. player.Name .. " ha salato le rustelle.")
	end)

	print("[SaltService] Pronto — tasto F, attivo solo con rustelle sulla brace.")
end

return SaltService
