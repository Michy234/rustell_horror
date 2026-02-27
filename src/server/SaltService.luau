--!strict
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Settings = require(ReplicatedStorage.Shared.Settings)

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
	prompt.ActionText          = "Sala Rustella"
	prompt.ObjectText          = "Sale  [F]"
	prompt.Style               = Enum.ProximityPromptStyle.Custom
	prompt.KeyboardKeyCode     = Enum.KeyCode.F
	prompt.HoldDuration        = 0.8
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance = 8
	prompt.Enabled = true
	prompt.Parent = root

	prompt.Triggered:Connect(function(player: Player)
		local character = player.Character
		if not character then return end

		-- Find equipped tool (child of character)
		local tool: Tool? = nil
		for _, child in character:GetChildren() do
			if child:IsA("Tool") then
				local name = child.Name
				if name == "Rustella" or name == "Rustella Cotta" then
					tool = child :: Tool
					break
				end
			end
		end

		local notifEv = ReplicatedStorage:FindFirstChild("NotificationEvent")

		if not tool then
			if notifEv then
				notifEv:FireClient(player, "🧂 Devi avere una rustella in mano!")
			end
			return
		end

		-- Salt the held tool
		tool.Name = "Rustella Salata"

		-- Visual: apply white tint to all parts of the tool
		local visual = tool:FindFirstChild("Visual")
		if visual then
			for _, p in visual:GetDescendants() do
				if p:IsA("BasePart") and p.Name ~= "stecca" then
					p.Color = p.Color:Lerp(Color3.new(1, 1, 1), 0.25)
				end
			end
		end

		playSaltSound(root)

		if notifEv then
			notifEv:FireClient(player, "🧂 Rustella salata!")
		end

		print("[SaltService] " .. player.Name .. " ha salato la rustella in mano.")
	end)

	print("[SaltService] Pronto — tasto F, sala la rustella in mano.")
end

return SaltService
