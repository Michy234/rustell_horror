--!strict
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Settings = require(ReplicatedStorage.Shared.Settings)
local BraceService = require(script.Parent:WaitForChild("BraceService"))

local SaltService = {}

-- Sound played when salt is applied (shaker-style)
-- Using a generic shaker sfx; user can swap the ID in Settings.
local SALT_SOUND_ID  = Settings.SALT_SOUND_ID or "rbxassetid://6042053626"

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

function SaltService.init()
	-- Wait up to 10 seconds for the Salt model to appear in Workspace
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
	-- Find a BasePart to attach the prompt to (PrimaryPart preferred)
	local root = saltModel.PrimaryPart or saltModel:FindFirstChildWhichIsA("BasePart", true)
	if not root then
		warn("[SaltService] Salt model non ha BasePart, impossibile aggiungere ProximityPrompt.")
		return
	end

	-- Remove any existing prompt
	for _, c in root:GetChildren() do
		if c:IsA("ProximityPrompt") then c:Destroy() end
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText       = "Aggiungi Sale"
	prompt.ObjectText       = "Sale"
	prompt.Style            = Enum.ProximityPromptStyle.Custom   -- picked up by InteractionService
	prompt.KeyboardKeyCode  = Enum.KeyCode.E
	prompt.HoldDuration     = 0.5
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance = 8
	prompt.Parent = root

	prompt.Triggered:Connect(function(player: Player)
		-- One-shot: disable immediately so it can't be spammed
		prompt.Enabled = false

		-- Play the salt shaker SFX
		playSaltSound(root)

		-- Notify the player
		local notifEv = ReplicatedStorage:FindFirstChild("NotificationEvent")
		if notifEv then
			notifEv:FireClient(player, "🧂 Sale aggiunto alle rustelle!")
		end

		-- Apply salt to every brace
		local braces = getAllBraces()
		for _, brace in braces do
			BraceService.applySalt(brace)
		end

		print("[SaltService] " .. player.Name .. " ha salato le rustelle.")
		-- Salt stays consumed — prompt remains disabled permanently until game reset
	end)

	print("[SaltService] Pronto — prompt sul modello Salt.")
end

return SaltService
