local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local Settings = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Settings"))
local NotificationService = require(script.NotificationService)
local InteractionService = require(script.InteractionService)
local MenuService = require(script.MenuService)
local NPCTrackerService = nil
local trackerOk, trackerErr = pcall(function()
	NPCTrackerService = require(script.NPCTrackerService)
end)
if not trackerOk then
	warn("[Client] ❌ NPCTrackerService require FAILED:", trackerErr)
end

NotificationService.init()
InteractionService.init()
MenuService.init()

if NPCTrackerService then
	local initOk, initErr = pcall(function()
		NPCTrackerService.init()
	end)
	if not initOk then
		warn("[Client] ❌ NPCTrackerService.init() FAILED:", initErr)
	end
else
	warn("[Client] ⚠️ NPCTrackerService not loaded, skipping init")
end

-- FIRST PERSON by default (toggle in settings)
local player = Players.LocalPlayer
if player then
	player.CameraMode = Enum.CameraMode.LockFirstPerson
end

-- Expose camera mode toggle globally for settings checkbox
_G.SetFirstPerson = function(enabled: boolean)
	if enabled then
		player.CameraMode = Enum.CameraMode.LockFirstPerson
	else
		player.CameraMode = Enum.CameraMode.Classic
	end
end

-- Prepare Background Music (Music will be played by MenuService after loading)
local bgm = SoundService:FindFirstChild("BackgroundMusic") or Instance.new("Sound")
bgm.Name = "BackgroundMusic"
bgm.SoundId = Settings.BG_MUSIC.ID
bgm.Volume = Settings.MUSIC_VOLUME or Settings.BG_MUSIC.VOLUME
bgm.Looped = true
bgm.Parent = SoundService

-- NPC Interaction Visibility Logic
task.spawn(function()
	while true do
		local character = player.Character
		local holdingRustella = character and (
			character:FindFirstChild("Rustella")
			or character:FindFirstChild("Rustella Salata")
			or character:FindFirstChild("Rustella Bruciata")
		) ~= nil
		
		for _, descendant in Workspace:GetDescendants() do
			if descendant:IsA("ProximityPrompt") and descendant.ActionText == "Dai Rustella" then
				descendant.Enabled = holdingRustella
			end
		end
		
		task.wait(0.2)
	end
end)

print("Client started, NotificationService, InteractionService, and MenuService initialized.")

-- DOG CLICK DETECTION
local mouse = player:GetMouse()
local DogClickEvent = ReplicatedStorage:WaitForChild("DogClickEvent", 10)

if DogClickEvent then
	mouse.Button1Down:Connect(function()
		local target = mouse.Target
		if not target then return end
		local model = target:FindFirstAncestorOfClass("Model")
		if model and model.Name == "dogMalus" then
			DogClickEvent:FireServer()
		end
	end)
end

-- BRACE CLICK DETECTION (click per prendere rustella)
local BraceTakeEvent = ReplicatedStorage:WaitForChild("BraceTakeEvent", 10)

if BraceTakeEvent then
	mouse.Button1Down:Connect(function()
		local target = mouse.Target
		if not target then return end
		local model = target:FindFirstAncestorOfClass("Model")
		if not model then return end

		local lowerName = string.lower(model.Name)
		local isBrace = model.Name == "Brace" or model.Name == "brace"
			or string.find(lowerName, "brace") ~= nil or string.find(lowerName, "braciere") ~= nil
		if not isBrace then return end

		local takePrompt = model:FindFirstChild("TakePrompt", true)
		if not takePrompt or not (takePrompt :: ProximityPrompt).Enabled then return end

		local character = player.Character
		if not character then return end
		local hrp = character:FindFirstChild("HumanoidRootPart")
		local primaryPart = model.PrimaryPart
		if not hrp or not primaryPart then return end
		if (hrp.Position - primaryPart.Position).Magnitude > Settings.INTERACTION_DISTANCE then return end

		BraceTakeEvent:FireServer(model)
	end)
end

-- ============================================================
-- RAIN VISUALS
-- ============================================================
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local RainStartEvent = ReplicatedStorage:WaitForChild("RainStartEvent", 10)
local RainStopEvent  = ReplicatedStorage:WaitForChild("RainStopEvent",  10)

local rainGui: ScreenGui? = nil
local rainSound: Sound? = nil
local rainConn: RBXScriptConnection? = nil

-- Save original Lighting properties the first time
local originalBrightness = Lighting.Brightness
local originalFogEnd = Lighting.FogEnd
local originalFogColor = Lighting.FogColor
local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
local originalDensity = atmosphere and atmosphere.Density or 0
local originalHaze = atmosphere and atmosphere.Haze or 0

local function startRainVisuals()
	-- 1) SKY TWEEN - 3s slow darkening
	TweenService:Create(Lighting, TweenInfo.new(3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Brightness = 0.15,
		FogEnd = 50,
		FogStart = 5,
		FogColor = Color3.fromRGB(110, 125, 145),
	}):Play()
	if atmosphere then
		TweenService:Create(atmosphere, TweenInfo.new(3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Density = 0.65,
			Haze = 0.8,
		}):Play()
	end

	-- 2) RAIN SOUND
	local snd = Instance.new("Sound")
	snd.Name = "RainLoop"
	snd.SoundId = Settings.RAIN_SOUND_ID or "rbxassetid://237985445"
	snd.Volume = 0   -- start silent, fade in
	snd.Looped = true
	snd.Parent = SoundService
	snd:Play()
	TweenService:Create(snd, TweenInfo.new(0.5), {Volume = 0.7}):Play()  -- 0.5s fade in
	rainSound = snd

	-- 3) RAIN OVERLAY (animated scanlines)
	local gui = Instance.new("ScreenGui")
	gui.Name = "RainOverlay"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 200   -- ScreenGui uses DisplayOrder, not ZIndex
	gui.Parent = player.PlayerGui
	rainGui = gui

	-- Pre-create rain drops, starting fully transparent for fade-in
	local drops: {{frame: Frame, speed: number, x: number, targetAlpha: number}} = {}
	for _ = 1, 150 do
		local targetAlpha = math.random(20, 50) / 100
		local f = Instance.new("Frame")
		f.BackgroundColor3 = Color3.fromRGB(200, 220, 255)
		f.BackgroundTransparency = 1   -- start invisible
		f.BorderSizePixel = 0
		f.Size = UDim2.fromOffset(math.random(1, 2), math.random(20, 50))
		f.Position = UDim2.fromScale(math.random(), math.random())
		f.Parent = gui
		-- Fade-in: tween each drop to its target transparency over 3s
		TweenService:Create(f, TweenInfo.new(3.0, Enum.EasingStyle.Quad), {BackgroundTransparency = targetAlpha}):Play()
		table.insert(drops, {
			frame = f,
			speed = math.random(8, 18) / 10,
			x = math.random(),
			targetAlpha = targetAlpha,
		})
	end

	rainConn = RunService.RenderStepped:Connect(function(dt)
		for _, d in drops do
			local newY = d.frame.Position.Y.Scale + dt * d.speed
			if newY > 1.05 then
				newY = -0.05
				d.x = math.random()
			end
			d.frame.Position = UDim2.new(d.x, 0, newY, 0)
		end
	end)
end

local function stopRainVisuals()
	-- Reverse lighting over 3s
	TweenService:Create(Lighting, TweenInfo.new(3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Brightness = originalBrightness,
		FogEnd = originalFogEnd,
		FogStart = 0,
		FogColor = originalFogColor,
	}):Play()
	if atmosphere then
		TweenService:Create(atmosphere, TweenInfo.new(3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Density = originalDensity,
			Haze = originalHaze,
		}):Play()
	end

	-- Stop sound with 3s fade
	if rainSound then
		TweenService:Create(rainSound, TweenInfo.new(3), {Volume = 0}):Play()
		task.delay(3.1, function()
			if rainSound then rainSound:Destroy() rainSound = nil end
		end)
	end

	-- Fade out drops over 3s, but KEEP animation running so drops move during fade
	if rainGui then
		for _, child in rainGui:GetChildren() do
			if child:IsA("Frame") then
				TweenService:Create(child, TweenInfo.new(3.0, Enum.EasingStyle.Quad), {BackgroundTransparency = 1}):Play()
			end
		end
		-- Disconnect + destroy AFTER the 3s fade completes
		task.delay(3.1, function()
			if rainConn then rainConn:Disconnect() rainConn = nil end
			if rainGui then rainGui:Destroy() rainGui = nil end
		end)
	end
end

if RainStartEvent then
	RainStartEvent.OnClientEvent:Connect(startRainVisuals)
end
if RainStopEvent then
	RainStopEvent.OnClientEvent:Connect(stopRainVisuals)
end
