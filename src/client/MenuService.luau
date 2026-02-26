local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local Settings = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Settings"))

local MenuService = {}

function MenuService.init()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	-- The camera might change (e.g., when player respawns), so we should use workspace.CurrentCamera directly where needed
	-- or update it when it changes.
	local camera = Workspace.CurrentCamera
	
	-- Listener for camera changes (Roblox replaces the camera object sometimes)
	Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		camera = Workspace.CurrentCamera
		print("[DEBUG-CLIENT] CurrentCamera changed, updating reference.")
	end)
	
	-- LOCK MOVEMENT DURING MENU
	local function lockMovement(locked: boolean)
		local char = player.Character or player.CharacterAdded:Wait()
		local hum = char:WaitForChild("Humanoid") :: Humanoid
		if locked then
			hum.WalkSpeed = 0
			hum.JumpPower = 0
		else
			hum.WalkSpeed = 16
			hum.JumpPower = 50
		end
	end
	lockMovement(true)
	
	-- Main GUI Container (BUMPED DisplayOrder)
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "GameMenuUI"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.DisplayOrder = 999 
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling -- Sibling is easier for relative hierarchies
	screenGui.Parent = playerGui

	---------------------------------------------------------------------------
	-- FAKE LOADING SCREEN
	---------------------------------------------------------------------------
	local loadingOverlay = Instance.new("Frame")
	loadingOverlay.Name = "LoadingOverlay"
	loadingOverlay.Size = UDim2.fromScale(1, 1)
	loadingOverlay.BackgroundColor3 = Color3.fromRGB(10, 10, 20) -- Very dark blue
	loadingOverlay.ZIndex = 10000 -- DEFINITELY ON TOP
	loadingOverlay.Visible = true
	loadingOverlay.Parent = screenGui

	local loadingText = Instance.new("TextLabel")
	loadingText.Size = UDim2.fromScale(0.6, 0.2)
	loadingText.Position = UDim2.fromScale(0.5, 0.45)
	loadingText.AnchorPoint = Vector2.new(0.5, 0.5)
	loadingText.BackgroundTransparency = 1
	loadingText.Text = "Loading..."
	loadingText.Font = Enum.Font.LuckiestGuy
	loadingText.TextColor3 = Color3.fromRGB(0, 160, 255) -- Vibrant Cyan
	loadingText.TextSize = 48
	loadingText.ZIndex = 10001
	loadingText.Parent = loadingOverlay
	
	local lStroke = Instance.new("UIStroke")
	lStroke.Thickness = 3
	lStroke.Color = Color3.new(1, 1, 1)
	lStroke.Parent = loadingText

	local spinner = Instance.new("ImageLabel")
	spinner.Name = "Spinner"
	spinner.Size = UDim2.fromOffset(80, 80)
	spinner.Position = UDim2.fromScale(0.5, 0.6)
	spinner.AnchorPoint = Vector2.new(0.5, 0.5)
	spinner.BackgroundTransparency = 1
	spinner.Image = "rbxassetid://6031104608" -- Standard reliable spinner
	spinner.ImageColor3 = Color3.fromRGB(255, 200, 0) -- Yellow
	spinner.ZIndex = 10001
	spinner.Parent = loadingOverlay

	local spinnerRotate = RunService.RenderStepped:Connect(function()
		spinner.Rotation += 8
	end)

	---------------------------------------------------------------------------
	-- MAIN MENU
	---------------------------------------------------------------------------
	local menuFrame = Instance.new("Frame")
	menuFrame.Name = "MainMenu"
	menuFrame.Size = UDim2.fromScale(1, 1)
	menuFrame.BackgroundTransparency = 1
	menuFrame.Visible = false 
	menuFrame.ZIndex = 10
	menuFrame.Parent = screenGui

	-- Logo / Title (SIMULATOR STYLE)
	local logoLabel = Instance.new("TextLabel")
	logoLabel.Name = "Logo"
	logoLabel.Size = UDim2.fromScale(0.8, 0.2)
	logoLabel.Position = UDim2.fromScale(0.5, 0.2)
	logoLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	logoLabel.BackgroundTransparency = 1
	logoLabel.Text = "RUSTELL SIMULATOR"
	logoLabel.Font = Enum.Font.LuckiestGuy
	logoLabel.TextColor3 = Color3.fromRGB(255, 100, 0) -- Bright Orange
	logoLabel.TextScaled = true
	logoLabel.ZIndex = 20
	logoLabel.Parent = menuFrame

	local logoStroke = Instance.new("UIStroke")
	logoStroke.Thickness = 5
	logoStroke.Color = Color3.new(1, 1, 1)
	logoStroke.Parent = logoLabel

	-- Subtitle
	local subtitle = Instance.new("TextLabel")
	subtitle.Name = "Subtitle"
	subtitle.Size = UDim2.fromScale(0.5, 0.05)
	subtitle.Position = UDim2.fromScale(0.5, 0.3)
	subtitle.AnchorPoint = Vector2.new(0.5, 0.5)
	subtitle.BackgroundTransparency = 1
	subtitle.Text = "IL RE DELLE RUSTELLE" 
	subtitle.Font = Enum.Font.FredokaOne
	subtitle.TextColor3 = Color3.fromRGB(255, 255, 255)
	subtitle.TextScaled = true
	subtitle.ZIndex = 20
	subtitle.Parent = menuFrame
	
	local sStrokeSub = Instance.new("UIStroke")
	sStrokeSub.Thickness = 2
	sStrokeSub.Color = Color3.fromRGB(0, 0, 0)
	sStrokeSub.Parent = subtitle

	-- Button Container
	local buttonFrame = Instance.new("Frame")
	buttonFrame.Size = UDim2.fromScale(0.4, 0.4)
	buttonFrame.Position = UDim2.fromScale(0.5, 0.65)
	buttonFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	buttonFrame.BackgroundTransparency = 1
	buttonFrame.Parent = menuFrame

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 20)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Parent = buttonFrame

	local function createButton(text: string, mainColor: Color3): TextButton
		local btn = Instance.new("TextButton")
		btn.Name = text .. "Btn"
		btn.Size = UDim2.fromScale(0.8, 0.22)
		btn.BackgroundColor3 = mainColor
		btn.BorderSizePixel = 0
		btn.Text = text
		btn.Font = Enum.Font.LuckiestGuy
		btn.TextColor3 = Color3.new(1, 1, 1)
		btn.TextSize = 32
		btn.ZIndex = 30
		
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 12)
		corner.Parent = btn

		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 3
		stroke.Color = Color3.new(1, 1, 1)
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Parent = btn

		local textStroke = Instance.new("UIStroke")
		textStroke.Thickness = 2
		textStroke.Parent = btn

		btn.MouseEnter:Connect(function()
			TweenService:Create(btn, TweenInfo.new(0.2), { Size = UDim2.fromScale(0.85, 0.25) }):Play()
		end)
		btn.MouseLeave:Connect(function()
			TweenService:Create(btn, TweenInfo.new(0.2), { Size = UDim2.fromScale(0.8, 0.22) }):Play()
		end)

		btn.MouseButton1Click:Connect(function()
			local sound = SoundService:FindFirstChild("ButtonClick") or Instance.new("Sound")
			sound.Name = "ButtonClick"
			sound.SoundId = "rbxassetid://452267918" -- Working button click
			sound.Volume = 0.5
			sound.Parent = SoundService
			sound:Play()
		end)

		return btn
	end

	local playBtn = createButton("GIOCA", Color3.fromRGB(0, 200, 100))
	playBtn.Parent = buttonFrame

	local settingsBtn = createButton("IMPOSTAZIONI", Color3.fromRGB(0, 160, 255))
	settingsBtn.Parent = buttonFrame

	---------------------------------------------------------------------------
	-- SETTINGS MENU
	---------------------------------------------------------------------------
	local settingsFrame = Instance.new("Frame")
	settingsFrame.Name = "SettingsMenu"
	settingsFrame.Size = UDim2.fromScale(0.4, 0.6)
	settingsFrame.Position = UDim2.fromScale(0.5, 0.5)
	settingsFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	settingsFrame.BackgroundColor3 = Color3.fromRGB(240, 240, 240) -- Grey-White
	settingsFrame.BorderSizePixel = 0
	settingsFrame.Visible = false
	settingsFrame.ZIndex = 200 -- High enough
	settingsFrame.Parent = screenGui

	local menuCorner = Instance.new("UICorner")
	menuCorner.CornerRadius = UDim.new(0, 16)
	menuCorner.Parent = settingsFrame
	local sStrokeM = Instance.new("UIStroke")
	sStrokeM.Thickness = 4
	sStrokeM.Color = Color3.fromRGB(0, 160, 255)
	sStrokeM.Parent = settingsFrame

	-- Initial Position (for bounce)
	settingsFrame.Position = UDim2.fromScale(0.5, 1.5)

	local function toggleSettings(open: boolean)
		local targetPos = open and UDim2.fromScale(0.5, 0.5) or UDim2.fromScale(0.5, 1.5)
		local easing = open and Enum.EasingStyle.Bounce or Enum.EasingStyle.Back
		
		if open then 
			settingsFrame.Visible = true 
		end
		
		local tween = TweenService:Create(settingsFrame, TweenInfo.new(0.6, easing), {Position = targetPos})
		tween:Play()
		
		if not open then
			tween.Completed:Connect(function()
				if settingsFrame.Position.Y.Scale > 1 then 
					settingsFrame.Visible = false 
				end
			end)
		end
	end

	local settingsTitle = Instance.new("TextLabel")
	settingsTitle.Size = UDim2.fromScale(1, 0.2)
	settingsTitle.BackgroundTransparency = 1
	settingsTitle.Text = "IMPOSTAZIONI"
	settingsTitle.Font = Enum.Font.LuckiestGuy
	settingsTitle.TextColor3 = Color3.fromRGB(0, 160, 255)
	settingsTitle.TextSize = 32
	settingsTitle.ZIndex = 201
	settingsTitle.Parent = settingsFrame

	local settingsList = Instance.new("ScrollingFrame")
	settingsList.Size = UDim2.fromScale(0.9, 0.7)
	settingsList.Position = UDim2.fromScale(0.5, 0.6)
	settingsList.AnchorPoint = Vector2.new(0.5, 0.5)
	settingsList.BackgroundTransparency = 1
	settingsList.BorderSizePixel = 0
	settingsList.ScrollBarThickness = 8
	settingsList.ZIndex = 201
	settingsList.CanvasSize = UDim2.new(0, 0, 0, 0)
	settingsList.AutomaticCanvasSize = Enum.AutomaticSize.Y
	settingsList.Parent = settingsFrame

	local sLayout = Instance.new("UIListLayout")
	sLayout.Padding = UDim.new(0, 15)
	sLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	sLayout.Parent = settingsList

	-- Close Button
	local closeBtn = Instance.new("TextButton")
	closeBtn.Size = UDim2.fromOffset(40, 40)
	closeBtn.Position = UDim2.new(1, -10, 0, 10)
	closeBtn.AnchorPoint = Vector2.new(1, 0)
	closeBtn.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
	closeBtn.TextColor3 = Color3.new(1, 1, 1)
	closeBtn.Text = "X"
	closeBtn.Font = Enum.Font.LuckiestGuy
	closeBtn.TextSize = 24
	closeBtn.ZIndex = 205
	closeBtn.Parent = settingsFrame
	local closeCorner = Instance.new("UICorner")
	closeCorner.Parent = closeBtn

	closeBtn.MouseButton1Click:Connect(function()
		local s = SoundService:FindFirstChild("ButtonClick") or Instance.new("Sound")
		s.Name = "ButtonClick"
		s.SoundId = "rbxassetid://452267918"
		s.Volume = 0.5
		s.Parent = SoundService
		s:Play()
		settingsFrame.Visible = false
	end)

	---------------------------------------------------------------------------
	-- SETTINGS ICON (BOTTOM RIGHT)
	---------------------------------------------------------------------------
	local settingsIcon = Instance.new("TextButton")
	settingsIcon.Name = "SettingsIcon"
	settingsIcon.Size = UDim2.fromOffset(140, 45)
	settingsIcon.Position = UDim2.new(1, -20, 1, -20)
	settingsIcon.AnchorPoint = Vector2.new(1, 1)
	settingsIcon.BackgroundColor3 = Color3.fromRGB(0, 160, 255)
	settingsIcon.Text = "IMPOSTAZIONI"
	settingsIcon.Font = Enum.Font.LuckiestGuy
	settingsIcon.TextColor3 = Color3.new(1, 1, 1)
	settingsIcon.TextSize = 14
	settingsIcon.Visible = false -- HIDE BY DEFAULT
	settingsIcon.ZIndex = 20000 -- DEFINITELY ON TOP
	settingsIcon.Parent = screenGui

	local iconCorner = Instance.new("UICorner")
	iconCorner.CornerRadius = UDim.new(0, 10)
	iconCorner.Parent = settingsIcon

	local iconStroke = Instance.new("UIStroke")
	iconStroke.Color = Color3.new(0, 0, 0) -- Dark background for readability
	iconStroke.Thickness = 2
	iconStroke.Parent = settingsIcon

	settingsIcon.MouseButton1Click:Connect(function()
		local s = SoundService:FindFirstChild("ButtonClick") or Instance.new("Sound")
		s.Name = "ButtonClick"
		s.SoundId = "rbxassetid://452267918"
		s.Volume = 0.5
		s.Parent = SoundService
		s:Play()
		
		toggleSettings(not settingsFrame.Visible or settingsFrame.Position.Y.Scale > 1)
	end)

	-- Slider Logic (Bvibrant)
	local function createSlider(name: string, default: number, callback: (number) -> ())
		local container = Instance.new("Frame")
		container.Size = UDim2.new(0.95, 0, 0, 60)
		container.BackgroundTransparency = 1
		container.ZIndex = 202
		container.Parent = settingsList

		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 0.4)
		label.BackgroundTransparency = 1
		label.Text = name
		label.TextColor3 = Color3.fromRGB(100, 100, 100)
		label.Font = Enum.Font.FredokaOne
		label.TextSize = 18
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.ZIndex = 203
		label.Parent = container

		local sliderBg = Instance.new("Frame")
		sliderBg.Size = UDim2.fromScale(1, 0.3)
		sliderBg.Position = UDim2.fromScale(0, 0.7)
		sliderBg.BackgroundColor3 = Color3.fromRGB(200, 200, 200)
		sliderBg.ZIndex = 203
		sliderBg.Parent = container
		local sliderCorner = Instance.new("UICorner")
		sliderCorner.Parent = sliderBg

		local sliderFill = Instance.new("Frame")
		sliderFill.Size = UDim2.fromScale(default, 1)
		sliderFill.BackgroundColor3 = Color3.fromRGB(0, 160, 255)
		sliderFill.ZIndex = 204
		sliderFill.Parent = sliderBg
		
		local fillCorner = Instance.new("UICorner")
		fillCorner.Parent = sliderFill

		local handle = Instance.new("TextButton")
		handle.Size = UDim2.fromOffset(24, 24)
		handle.Position = UDim2.fromScale(default, 0.5)
		handle.AnchorPoint = Vector2.new(0.5, 0.5)
		handle.Text = ""
		handle.BackgroundColor3 = Color3.new(1, 1, 1)
		handle.ZIndex = 205
		handle.Parent = sliderBg
		local handleCorner = Instance.new("UICorner")
		handleCorner.CornerRadius = UDim.new(1, 0)
		handleCorner.Parent = handle
		
		local handleStroke = Instance.new("UIStroke")
		handleStroke.Thickness = 2
		handleStroke.Parent = handle

		local dragging = false
		handle.MouseButton1Down:Connect(function() dragging = true end)
		game:GetService("UserInputService").InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then 
				dragging = false 
			end
		end)

		RunService.RenderStepped:Connect(function()
			if dragging then
				local mousePos = game:GetService("UserInputService"):GetMouseLocation().X
				local relativeX = (mousePos - sliderBg.AbsolutePosition.X) / sliderBg.AbsoluteSize.X
				local percent = math.clamp(relativeX, 0, 1)
				handle.Position = UDim2.fromScale(percent, 0.5)
				sliderFill.Size = UDim2.fromScale(percent, 1)
				callback(percent)
			end
		end)
	end

	createSlider("Volume Audio", Settings.AUDIO_VOLUME or 0.5, function(v)
		Settings.AUDIO_VOLUME = v
	end)

	createSlider("Musica", Settings.MUSIC_VOLUME or 0.3, function(v)
		Settings.MUSIC_VOLUME = v
		local bgm = SoundService:FindFirstChild("BackgroundMusic")
		if bgm and bgm:IsA("Sound") then
			bgm.Volume = v
		end
	end)

	createSlider("Difficoltà (Fame)", 0.5, function(v)
		local difficulty = 0.5 + (v * 2.0)
		game:SetAttribute("Difficulty", difficulty)
	end)

	-- TOP-DOWN CAMERA LOGIC
	local cameraConn: RBXScriptConnection?
	local menuCameraActive = false
	
	local function startMenuCamera()
		print("[DEBUG-CLIENT] startMenuCamera call (active: " .. tostring(menuCameraActive) .. ")")
		if menuCameraActive then return end
		menuCameraActive = true
		camera.CameraType = Enum.CameraType.Scriptable
		local lookPoint = Vector3.new(0, 0, 0)
		
		print("[DEBUG-CLIENT] Cerco brace per focus camera...")
		for _, v in Workspace:GetDescendants() do
			if v.Name:lower():match("brace") and v:IsA("Model") then
				local pivot = v:GetPivot()
				lookPoint = pivot.Position
				print("[DEBUG-CLIENT] Brace trovata a " .. tostring(lookPoint))
				break
			end
		end

		-- FALLBACK: If no brace found, use origin or a fixed point
		if lookPoint == Vector3.new(0, 0, 0) then
			warn("[DEBUG-CLIENT] Nessuna brace trovata! Uso (0, 0, 0) come fallback.")
		end

		cameraConn = RunService.RenderStepped:Connect(function()
			local t = tick() * 0.1
			local radius = 80
			local camPos = lookPoint + Vector3.new(math.cos(t) * radius, 100, math.sin(t) * radius)
			
			-- FORCE Scriptable every frame if using menu camera to prevent Roblox from overriding it
			if camera.CameraType ~= Enum.CameraType.Scriptable then
				camera.CameraType = Enum.CameraType.Scriptable
			end
			
			camera.CFrame = CFrame.lookAt(camPos, lookPoint)
		end)
	end

	local function stopMenuCamera()
		print("[DEBUG-CLIENT] stopMenuCamera call")
		if cameraConn then
			cameraConn:Disconnect()
			cameraConn = nil
			print("[DEBUG-CLIENT] Camera connection scollegata.")
		end
		menuCameraActive = false
		camera.CameraType = Enum.CameraType.Custom
		
		-- FIX: Ensure camera subject is restored to player
		local char = player.Character
		if char then
			local hum = char:FindFirstChildOfClass("Humanoid")
			if hum then
				camera.CameraSubject = hum
				print("[DEBUG-CLIENT] CameraSubject ripristinato su Humanoid.")
			end
		end
	end

	-- LOADING SCREEN SEQUENCER (FIXED)
	task.spawn(function()
		loadingText.Font = Enum.Font.GothamMedium -- Simpler font
		loadingText.Text = "Loading"
		
		-- Animated Dots Logic
		local dotsThread = task.spawn(function()
			local dots = 0
			while loadingOverlay.Parent do
				dots = (dots + 1) % 4
				local dotStr = string.rep(".", dots)
				loadingText.Text = "Loading" .. dotStr
				task.wait(0.5)
			end
		end)

		task.wait(3)
		if dotsThread then
			task.cancel(dotsThread) -- Stop dots
		end
		loadingText.Text = "Done!"
		
		if spinnerRotate then 
			spinnerRotate:Disconnect() 
		end
		if spinner then 
			spinner.Visible = false 
		end
		
		task.wait(1)
		
		-- FIX: SET CAMERA AND MENU BEFORE FADING
		startMenuCamera()
		menuFrame.Visible = true
		task.wait(0.5) -- THE BLACK BUFFER REQUESTED
		
		-- COMPLETE FADE OUT (Including Strokes)
		local function fadeOutRecursive(obj: Instance)
			if obj:IsA("GuiObject") then
				local props = {}
				if pcall(function() return obj.BackgroundTransparency end) then 
					props.BackgroundTransparency = 1 
				end
				if obj:IsA("TextLabel") or obj:IsA("TextButton") then 
					props.TextTransparency = 1 
				end
				if obj:IsA("ImageLabel") or obj:IsA("ImageButton") then 
					props.ImageTransparency = 1 
				end
				
				if next(props) ~= nil then
					TweenService:Create(obj, TweenInfo.new(1), props):Play()
				end
			end
			if obj:IsA("UIStroke") then
				TweenService:Create(obj, TweenInfo.new(1), { Transparency = 1 }):Play()
			end
			for _, child in obj:GetChildren() do
				fadeOutRecursive(child)
			end
		end

		fadeOutRecursive(loadingOverlay)
		task.wait(1)
		loadingOverlay.Visible = false
		-- ICON STAYS HIDDEN UNTIL PLAY IS PRESSED per user request
		
		-- Start music slightly earlier
		task.delay(0.5, function()
			local bgm = SoundService:FindFirstChild("BackgroundMusic")
			if bgm and bgm:IsA("Sound") then
				bgm:Play()
			end
		end)
	end)

	-- Main Buttons Logic
	playBtn.MouseButton1Click:Connect(function()
		print("[DEBUG-CLIENT] Play button cliccato.")
		local s = SoundService:FindFirstChild("ButtonClick") or Instance.new("Sound")
		s.Name = "ButtonClick"
		s.SoundId = "rbxassetid://452267918"
		s.Volume = 0.5
		s.Parent = SoundService
		s:Play()

		print("[DEBUG-CLIENT] Invio GameStartEvent al server...")
		local event = ReplicatedStorage:FindFirstChild("GameStartEvent")
		if event and event:IsA("RemoteEvent") then
			event:FireServer()
		end
		
		game:SetAttribute("GameStarted", true)
		print("[DEBUG-CLIENT] Interrompo camera menu e ripristino controlli.")
		stopMenuCamera()
		
		-- RESTORE MOVEMENT
		local char = player.Character
		if char then
			local hum = char:FindFirstChildOfClass("Humanoid")
			if hum then
				hum.WalkSpeed = 16
				hum.JumpPower = 50
				print("[DEBUG-CLIENT] Movimento ripristinato.")
			end
		end

		-- SHOW SETTINGS ICON NOW
		local sIcon = screenGui:FindFirstChild("SettingsIcon")
		if sIcon then sIcon.Visible = true end
		
		print("[DEBUG-CLIENT] Avvio fade-out menu...")
		local function fadeOutMenu(obj: Instance)
			if obj:IsA("GuiObject") then
				-- Skip settings icon AND the settings menu frame
				if obj == settingsIcon or obj == settingsFrame or obj:IsDescendantOf(settingsFrame) then 
					return 
				end
				
				local props = {}
				local sBg, _ = pcall(function() return obj.BackgroundTransparency end)
				if sBg then 
					props.BackgroundTransparency = 1 
				end
				
				if obj:IsA("TextLabel") or obj:IsA("TextButton") then 
					props.TextTransparency = 1 
				end
				
				if obj:IsA("ImageLabel") or obj:IsA("ImageButton") then 
					props.ImageTransparency = 1 
				end
				
				if next(props) ~= nil then
					TweenService:Create(obj, TweenInfo.new(0.5), props):Play()
				end
			end
			if obj:IsA("UIStroke") then
				if not obj:IsDescendantOf(settingsFrame) and obj.Parent ~= settingsIcon then
					TweenService:Create(obj, TweenInfo.new(0.5), { Transparency = 1 }):Play()
				end
			end
			for _, child in obj:GetChildren() do
				fadeOutMenu(child)
			end
		end

		fadeOutMenu(screenGui) -- Scan the whole screenGui but skip settings

		task.wait(0.6)
		menuFrame.Visible = false
	end)

	-- RESET LOGIC
	local function fullReset()
		print("[DEBUG-CLIENT] Inizio fullReset...")
		game:SetAttribute("GameStarted", false)
		
		print("[DEBUG-CLIENT] Richiedo ResetEvent al server...")
		local resetEvent = ReplicatedStorage:FindFirstChild("GameResetEvent")
		if resetEvent and resetEvent:IsA("RemoteEvent") then
			resetEvent:FireServer()
		else
			warn("[DEBUG-CLIENT] GameResetEvent non trovato!")
		end
		
		print("[DEBUG-CLIENT] Mostro caricamento e resetto UI forzatamente...")
		
		-- FUNCTION TO RESET OVERLAY TRANSPARENCY
		local function resetOverlay(obj: Instance)
			if obj:IsA("GuiObject") then
				if obj:IsA("TextLabel") or obj:IsA("TextButton") then 
					obj.TextTransparency = 0 
				end
				if obj:IsA("ImageLabel") or obj:IsA("ImageButton") then 
					obj.ImageTransparency = 0 
				end
				pcall(function() 
					(obj :: any).BackgroundTransparency = 0 
				end)
			end
			if obj:IsA("UIStroke") then
				obj.Transparency = 0
			end
			for _, child in obj:GetChildren() do
				resetOverlay(child)
			end
		end

		-- Mostra overlay di caricamento
		loadingOverlay.Visible = true
		resetOverlay(loadingOverlay)
		loadingText.Text = "Loading" -- Reset text too
		
		-- Restore UI
		for _, v in screenGui:GetDescendants() do
			if v:IsA("GuiObject") then
				if v == settingsIcon or v == settingsFrame or v:IsDescendantOf(settingsFrame) then
					-- Keep settings hidden
					v.Visible = false
					if v:IsA("CanvasGroup") or v:IsA("Frame") or v:IsA("TextLabel") or v:IsA("TextButton") or v:IsA("ImageLabel") then
						-- Restore transparency for future use
						pcall(function() 
							(v :: any).BackgroundTransparency = 0 
						end)
						if v:IsA("TextLabel") or v:IsA("TextButton") then 
							(v :: any).TextTransparency = 0 
						end
						if v:IsA("ImageLabel") or v:IsA("ImageButton") then 
							(v :: any).ImageTransparency = 0 
						end
					end
				else
					-- Show main menu elements (MenuFrame etc)
					if not v:IsDescendantOf(loadingOverlay) and v ~= loadingOverlay then
						v.Visible = true
						if v:IsA("CanvasGroup") or v:IsA("Frame") or v:IsA("TextLabel") or v:IsA("TextButton") or v:IsA("ImageLabel") then
							pcall(function() 
								(v :: any).BackgroundTransparency = 0 
							end)
							if v:IsA("TextLabel") or v:IsA("TextButton") then 
								(v :: any).TextTransparency = 0 
							end
							if v:IsA("ImageLabel") or v:IsA("ImageButton") then 
								(v :: any).ImageTransparency = 0 
							end
						end
					end
				end
			end
			if v:IsA("UIStroke") then
				v.Transparency = 0
			end
		end
		
		menuFrame.Visible = true
		settingsIcon.Visible = false
		settingsFrame.Visible = false
		settingsFrame.Position = UDim2.fromScale(0.5, 1.5)
		
		-- Ensure jumpscare is hidden
		local jsOverlay = screenGui:FindFirstChild("JumpscareOverlay")
		if jsOverlay then
			jsOverlay.Visible = false
		end
		
		print("[DEBUG-CLIENT] Camera e Input reset...")
		startMenuCamera()
		lockMovement(true)
		
		task.wait(1)
		TweenService:Create(loadingOverlay, TweenInfo.new(1), {BackgroundTransparency = 1}):Play()
		task.wait(1)
		loadingOverlay.Visible = false
		print("[DEBUG-CLIENT] Reset completato.")
	end

	-- JUMPSCARE GUI
	local jumpscareOverlay = Instance.new("Frame")
	jumpscareOverlay.Name = "JumpscareOverlay"
	jumpscareOverlay.Size = UDim2.fromScale(1, 1)
	jumpscareOverlay.BackgroundColor3 = Color3.new(0, 0, 0)
	jumpscareOverlay.ZIndex = 50000
	jumpscareOverlay.Visible = false
	jumpscareOverlay.Parent = screenGui

	local jumpscareImage = Instance.new("ImageLabel")
	jumpscareImage.Name = "IShowSpeed"
	jumpscareImage.Size = UDim2.fromScale(0.8, 0.8)
	jumpscareImage.Position = UDim2.fromScale(0.5, 0.5)
	jumpscareImage.AnchorPoint = Vector2.new(0.5, 0.5)
	jumpscareImage.BackgroundTransparency = 1
	jumpscareImage.Image = "rbxassetid://12411985396" -- Placeholder: Change to IShowSpeed ID
	jumpscareImage.ZIndex = 50001
	jumpscareImage.Parent = jumpscareOverlay

	-- GAME OVER LOGIC
	local gameOverEvent = ReplicatedStorage:WaitForChild("GameOverEvent")
	gameOverEvent.OnClientEvent:Connect(function()
		print("[DEBUG-CLIENT] GameOverEvent ricevuto!")
		game:SetAttribute("GameStarted", false)
		lockMovement(true)

		-- Fade out music
		local bgm = SoundService:FindFirstChild("BackgroundMusic")
		if bgm and bgm:IsA("Sound") then
			TweenService:Create(bgm, TweenInfo.new(1.5), { Volume = 0 }):Play()
		end

		task.wait(1.5)

		-- JUMPSCARE DI BOTTO
		jumpscareOverlay.Visible = true
		local scarySound = Instance.new("Sound")
		scarySound.SoundId = "rbxassetid://8395374561"
		scarySound.Volume = 1
		scarySound.Parent = SoundService
		scarySound:Play()

		task.wait(3)
		jumpscareOverlay.Visible = false
		scarySound:Destroy()
		
		-- Restore BGM volume for next game
		if bgm and bgm:IsA("Sound") then
			bgm.Volume = Settings.MUSIC_VOLUME or 0.3
			bgm:Stop()
		end

		fullReset()
	end)

	settingsBtn.MouseButton1Click:Connect(function()
		toggleSettings(true)
	end)

	local function onCharacter(char)
		print("[DEBUG-CLIENT] onCharacter: caricato -> " .. char.Name)
		local hum = char:WaitForChild("Humanoid")
		
		-- Maintain camera if game hasn't started
		if not game:GetAttribute("GameStarted") then
			print("[DEBUG-CLIENT] Caricamento personaggio in Menu: forzo camera...")
			task.wait(1) -- Yield longer for Roblox character loading defaults to settle
			startMenuCamera()
			lockMovement(true)
		end

		hum.Died:Connect(function()
			print("[DEBUG-CLIENT] Personaggio morto. Avvio reset in 2s...")
			task.wait(2) -- Wait for death animation
			fullReset()
		end)
	end
	
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then 
		print("[DEBUG-CLIENT] Personaggio già presente all'init.")
		onCharacter(player.Character) 
	end
end

return MenuService
