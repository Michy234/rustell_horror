--!strict
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Settings = require(ReplicatedStorage.Shared.Settings)

local RainService = {}

-- RemoteEvents for rain visuals on clients
local RainStartEvent = Instance.new("RemoteEvent")
RainStartEvent.Name = "RainStartEvent"
RainStartEvent.Parent = ReplicatedStorage

local RainStopEvent = Instance.new("RemoteEvent")
RainStopEvent.Name = "RainStopEvent"
RainStopEvent.Parent = ReplicatedStorage

local function getAllBraces(): {Model}
	local braces = {}
	for _, obj in Workspace:GetDescendants() do
		if obj:IsA("Model") and obj.Name:lower():find("brace") then
			table.insert(braces, obj)
		end
	end
	return braces
end

local function extinguishBrace(brace: Model)
	-- Only turn off coal — do NOT touch cooking slot status or meat colors.
	-- The cooking loop will pause automatically via HasCoal check.
	brace:SetAttribute("HasCoal", false)

	-- Find fire by CLASS (works regardless of element name)
	local fireObj = brace:FindFirstChildWhichIsA("Fire", true)
	if not fireObj then fireObj = brace:FindFirstChildWhichIsA("ParticleEmitter", true) end
	
	if fireObj then
		print("[DEBUG] Rain extinguishment. Fire object found:", fireObj.Name)
		task.spawn(function()
			if fireObj:IsA("ParticleEmitter") then
				local startRate = fireObj.Rate
				for i = 20, 0, -1 do
					fireObj.Rate = (i / 20) * startRate
					task.wait(0.06)
				end
				fireObj.Enabled = false
				fireObj.Rate = 0
			elseif fireObj:IsA("Fire") then
				-- Fade from new max (Size 3.0, Heat 7) to off (Size 1, Heat 2)
				for i = 20, 0, -1 do
					local r = i / 20
					fireObj.Size = 1 + (r * 2.0)
					fireObj.Heat = 2 + (r * 5)
					task.wait(0.06)
				end
				fireObj.Size = 1
				fireObj.Heat = 2
				fireObj.Enabled = false
				print("[DEBUG] Rain extinguishment complete.")
			end
		end)
	end

	-- Stop coal loop sound
	local parentPart = brace.PrimaryPart or brace:FindFirstChildWhichIsA("BasePart", true)
	if parentPart then
		local coalSound = parentPart:FindFirstChild("CoalLoopSound")
		if coalSound then
			coalSound:Stop()
			coalSound:Destroy()
		end
		
		-- Restore E-key prompt so player can relight the brace
		local insertP = parentPart:FindFirstChild("InsertPrompt")
		if insertP then
			insertP.ActionText = "Inserisci Carbone"
			insertP.Enabled = true
		end
		local rekindleP = parentPart:FindFirstChild("RekindlePrompt")
		if rekindleP then
			rekindleP.Enabled = false
		end
	end

	print("[RainService] Brace extinguished (cooking paused, E to relight).")
end

function RainService.trigger()
	print("[RainService] ☁️ Pioggia in arrivo!")
	
	-- Notify all clients to start rain
	RainStartEvent:FireAllClients()
	
	-- Extinguish all braces
	for _, brace in getAllBraces() do
		extinguishBrace(brace)
	end
	
	-- Rain lasts for RAIN_DURATION seconds
	task.wait(Settings.RAIN_DURATION)
	
	-- Stop rain on clients
	RainStopEvent:FireAllClients()
	print("[RainService] ☀️ Pioggia finita.")
end

function RainService.init()
	task.spawn(function()
		while true do
			-- Wait for game to start before enabling rain
			while not game:GetAttribute("GameStarted") do
				task.wait(1)
			end
			
			local winTime = Settings.WIN_TIME or 300
			local numRains = math.random(2, 3)
			-- Distribute rains across the game time (avoiding the very beginning/end)
			local avgWait = (winTime - 60) / numRains
			
			for _ = 1, numRains do
				local waitTime = avgWait + math.random(-20, 20)
				
				-- Custom wait loop to permit immediate breaks if game stops
				local elapsed = 0
				while elapsed < waitTime and game:GetAttribute("GameStarted") do
					task.wait(1)
					elapsed += 1
				end
				
				if not game:GetAttribute("GameStarted") then break end
				
				RainService.trigger()
			end
			
			-- Idle until the match finishes if we ran out of scheduled rains early
			while game:GetAttribute("GameStarted") do
				task.wait(1)
			end
		end
	end)
end

return RainService
