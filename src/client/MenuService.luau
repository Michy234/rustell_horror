local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Settings = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Settings"))

local MenuService = {}

local bgm: Sound? = nil

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

	local settingsOpen = false
	local wasFirstPerson = false
	local savedCameraCF: CFrame? = nil

	-- Helper: zoom camera out when switching to third person
	local function zoomOutCamera()
		-- Force Roblox camera controller to zoom out by temporarily raising min zoom
		player.CameraMinZoomDistance = 10
		task.delay(0.3, function()
			player.CameraMinZoomDistance = 0.5
		end)
	end

	local function toggleSettings(open: boolean)
		settingsOpen = open
		local targetPos = open and UDim2.fromScale(0.5, 0.5) or UDim2.fromScale(0.5, 1.5)
		local easing = open and Enum.EasingStyle.Bounce or Enum.EasingStyle.Back
		
		if open then 
			settingsFrame.Visible = true
			-- If in first person, freeze camera and free mouse
			if game:GetAttribute("GameStarted") and player.CameraMode == Enum.CameraMode.LockFirstPerson then
				wasFirstPerson = true
				savedCameraCF = camera.CFrame
				player.CameraMode = Enum.CameraMode.Classic
				camera.CameraType = Enum.CameraType.Scriptable
				-- Keep the current view frozen
				if savedCameraCF then
					camera.CFrame = savedCameraCF
				end
				UserInputService.MouseBehavior = Enum.MouseBehavior.Default
				UserInputService.MouseIconEnabled = true
			end
		end
		
		local tween = TweenService:Create(settingsFrame, TweenInfo.new(0.6, easing), {Position = targetPos})
		tween:Play()
		
		if not open then
			-- Restore camera based on what user chose while settings were open
			if camera.CameraType == Enum.CameraType.Scriptable then
				camera.CameraType = Enum.CameraType.Custom
				-- Restore camera subject
				local char = player.Character
				if char then
					local hum = char:FindFirstChildOfClass("Humanoid")
					if hum then
						camera.CameraSubject = hum
					end
				end
				-- Apply the correct camera mode based on wasFirstPerson
				if wasFirstPerson then
					player.CameraMode = Enum.CameraMode.LockFirstPerson
				else
					player.CameraMode = Enum.CameraMode.Classic
					zoomOutCamera()
				end
				wasFirstPerson = false
				savedCameraCF = nil
			end
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
		toggleSettings(false)
	end)

	---------------------------------------------------------------------------
	-- SETTINGS ICON (BOTTOM RIGHT)
	---------------------------------------------------------------------------
	local settingsIcon = Instance.new("TextButton")
	settingsIcon.Name = "SettingsIcon"
	settingsIcon.Size = UDim2.fromOffset(50, 50)
	settingsIcon.Position = UDim2.new(1, -20, 1, -20)
	settingsIcon.AnchorPoint = Vector2.new(1, 1)
	settingsIcon.BackgroundColor3 = Color3.fromRGB(0, 160, 255)
	settingsIcon.Text = "⚙"
	settingsIcon.Font = Enum.Font.GothamBold
	settingsIcon.TextColor3 = Color3.new(1, 1, 1)
	settingsIcon.TextSize = 28
	settingsIcon.Visible = false
	settingsIcon.ZIndex = 20000
	settingsIcon.Parent = screenGui

	local iconCorner = Instance.new("UICorner")
	iconCorner.CornerRadius = UDim.new(0, 12)
	iconCorner.Parent = settingsIcon

	local iconStroke = Instance.new("UIStroke")
	iconStroke.Color = Color3.fromRGB(255, 255, 255)
	iconStroke.Thickness = 2.5
	iconStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	iconStroke.Parent = settingsIcon

	settingsIcon.MouseButton1Click:Connect(function()
		local s = SoundService:FindFirstChild("ButtonClick") or Instance.new("Sound")
		s.Name = "ButtonClick"
		s.SoundId = "rbxassetid://452267918"
		s.Volume = 0.5
		s.Parent = SoundService
		s:Play()
		
		toggleSettings(not settingsOpen)
	end)

	-- "I" key to toggle settings (with mouse unlock in first person)
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if input.KeyCode ~= Enum.KeyCode.I then return end
		-- Only block if actively typing in a TextBox (chat)
		local focused = UserInputService:GetFocusedTextBox()
		if focused then return end
		if settingsIcon.Visible then
			toggleSettings(not settingsOpen)
		end
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
		if bgm and bgm:IsA("Sound") then
			bgm.Volume = v
		end
	end)

	createSlider("Difficoltà (Fame)", 0.5, function(v)
		local difficulty = 0.5 + (v * 2.0)
		game:SetAttribute("Difficulty", difficulty)
	end)
	
	-- FIRST PERSON TOGGLE CHECKBOX
	do
		local isFirstPerson = true  -- default ON
		
		local row = Instance.new("Frame")
		row.Size = UDim2.new(0.95, 0, 0, 44)
		row.BackgroundTransparency = 1
		row.ZIndex = 202
		row.Parent = settingsList
		
		local rowLabel = Instance.new("TextLabel")
		rowLabel.Size = UDim2.new(0.75, 0, 1, 0)
		rowLabel.BackgroundTransparency = 1
		rowLabel.Font = Enum.Font.FredokaOne
		rowLabel.TextColor3 = Color3.fromRGB(100, 100, 100)
		rowLabel.TextSize = 18
		rowLabel.TextXAlignment = Enum.TextXAlignment.Left
		rowLabel.Text = "Prima Persona"
		rowLabel.ZIndex = 203
		rowLabel.Parent = row
		
		local checkBtn = Instance.new("TextButton")
		checkBtn.Size = UDim2.fromOffset(36, 36)
		checkBtn.Position = UDim2.new(1, -36, 0.5, -18)
		checkBtn.BackgroundColor3 = Color3.fromRGB(0, 160, 80) -- green = ON
		checkBtn.Text = "✓"
		checkBtn.Font = Enum.Font.GothamBold
		checkBtn.TextSize = 20
		checkBtn.TextColor3 = Color3.new(1, 1, 1)
		checkBtn.ZIndex = 204
		checkBtn.Parent = row
		Instance.new("UICorner", checkBtn).CornerRadius = UDim.new(0, 6)
		
		local function updateCheckbox()
			if isFirstPerson then
				checkBtn.BackgroundColor3 = Color3.fromRGB(0, 160, 80)
				checkBtn.Text = "✓"
			else
				checkBtn.BackgroundColor3 = Color3.fromRGB(160, 50, 50)
				checkBtn.Text = "✗"
			end

			-- If settings are open with camera frozen (Scriptable),
			-- only update wasFirstPerson — actual CameraMode changes when settings close
			if settingsOpen and camera.CameraType == Enum.CameraType.Scriptable then
				wasFirstPerson = isFirstPerson
				-- Keep mouse free since settings are open
				UserInputService.MouseBehavior = Enum.MouseBehavior.Default
				UserInputService.MouseIconEnabled = true
			elseif settingsOpen then
				-- Settings open but not in Scriptable (e.g. was third person)
				if isFirstPerson then
					-- Don't apply LockFirstPerson while menu is open — defer
					wasFirstPerson = true
				else
					player.CameraMode = Enum.CameraMode.Classic
					zoomOutCamera()
				end
				UserInputService.MouseBehavior = Enum.MouseBehavior.Default
				UserInputService.MouseIconEnabled = true
			else
				-- Settings closed: apply immediately
				if isFirstPerson then
					player.CameraMode = Enum.CameraMode.LockFirstPerson
				else
					player.CameraMode = Enum.CameraMode.Classic
					zoomOutCamera()
				end
			end
		end
		
		checkBtn.MouseButton1Click:Connect(function()
			isFirstPerson = not isFirstPerson
			updateCheckbox()
		end)
		
		-- Also expose globally for init.client.luau compatibility
		_G.SetFirstPerson = function(enabled: boolean)
			isFirstPerson = enabled
			updateCheckbox()
		end
		
		updateCheckbox()  -- Apply default state
	end

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
			local radius = 50 -- ZOOMED IN (was 80)
			local camPos = lookPoint + Vector3.new(math.cos(t) * radius, 60, math.sin(t) * radius) -- Lowered from 100
			
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

		task.wait(1.9)
		if dotsThread then
			task.cancel(dotsThread) -- Stop dots
		end
		loadingText.Text = "Done!"
		
		-- Start music exactly when "Done!" appears
		bgm = SoundService:FindFirstChild("BackgroundMusic")
		if bgm and bgm:IsA("Sound") then
			bgm.Volume = Settings.MUSIC_VOLUME or 0.3
			bgm:Play()
		end
		
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
			-- EXCLUDE WIN UI
			if obj.Name == "WinLabel" or obj.Name == "WinTimer" then return end
			
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
			-- EXCLUDE WIN UI
			if obj.Name == "WinLabel" or obj.Name == "WinTimer" then return end

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

	-- TIMER UI CONTAINER
	local timerContainer = Instance.new("Frame")
	timerContainer.Name = "TimerContainer"
	timerContainer.Size = UDim2.fromOffset(220, 80)
	timerContainer.Position = UDim2.new(0.5, 0, 1, -20)
	timerContainer.AnchorPoint = Vector2.new(0.5, 1)
	timerContainer.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	timerContainer.BackgroundTransparency = 0.5
	timerContainer.Visible = false
	timerContainer.ZIndex = 100000
	timerContainer.Parent = screenGui
	
	local containerCorner = Instance.new("UICorner")
	containerCorner.CornerRadius = UDim.new(0, 12)
	containerCorner.Parent = timerContainer

	local timerTitle = Instance.new("TextLabel")
	timerTitle.Name = "Title"
	timerTitle.Size = UDim2.fromScale(1, 0.4)
	timerTitle.Position = UDim2.fromScale(0, 0.1)
	timerTitle.BackgroundTransparency = 1
	timerTitle.Font = Enum.Font.LuckiestGuy
	timerTitle.TextColor3 = Color3.new(1, 1, 1)
	timerTitle.TextSize = 18
	timerTitle.Text = "Tempo rimanente:"
	timerTitle.ZIndex = 100001
	timerTitle.Parent = timerContainer
	
	local titleStroke = Instance.new("UIStroke")
	titleStroke.Thickness = 2
	titleStroke.Parent = timerTitle

	local timerLabel = Instance.new("TextLabel")
	timerLabel.Name = "WinTimer"
	timerLabel.Size = UDim2.fromScale(1, 0.6)
	timerLabel.Position = UDim2.fromScale(0, 0.4)
	timerLabel.BackgroundTransparency = 1
	timerLabel.Font = Enum.Font.LuckiestGuy
	timerLabel.TextColor3 = Color3.new(1, 1, 1)
	timerLabel.TextSize = 36
	timerLabel.Text = ""
	timerLabel.ZIndex = 100001
	timerLabel.Parent = timerContainer
	
	local timerStroke = Instance.new("UIStroke")
	timerStroke.Thickness = 3
	timerStroke.Parent = timerLabel

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

		-- Teletrasporta il personaggio allo SpawnLocation originale
		-- così il prossimo respawn non avviene nel punto della morte
		local spawnLoc = Workspace:FindFirstChildOfClass("SpawnLocation")
		local char = player.Character
		if char then
			local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
			if hrp then
				if spawnLoc then
					hrp.CFrame = spawnLoc.CFrame + Vector3.new(0, 5, 0)
				else
					-- Fallback: usa gli attributi del Nonno invertiti per trovare il centro mappa
					hrp.CFrame = CFrame.new(0, 10, 0)
				end
			end
		end
		
		print("[DEBUG-CLIENT] Mostro caricamento e resetto UI forzatamente...")
		
		loadingOverlay.Visible = true
		loadingText.Text = "Loading"
		
		-- Restore original UI transparencies globally
		for _, v in screenGui:GetDescendants() do
			if v:IsA("GuiObject") then
				local origBg = v:GetAttribute("OrigBgTrans")
				if origBg ~= nil then v.BackgroundTransparency = origBg end
				
				local origText = v:GetAttribute("OrigTextTrans")
				if origText ~= nil and (v:IsA("TextLabel") or v:IsA("TextButton")) then v.TextTransparency = origText end
				
				local origImg = v:GetAttribute("OrigImgTrans")
				if origImg ~= nil and (v:IsA("ImageLabel") or v:IsA("ImageButton")) then v.ImageTransparency = origImg end
			end
			if v:IsA("UIStroke") then
				local origTrans = v:GetAttribute("OrigStrokeTrans")
				if origTrans ~= nil then v.Transparency = origTrans end
			end
		end

		menuFrame.Visible = true
		settingsIcon.Visible = false
		timerContainer.Visible = false
		
		settingsFrame.Visible = false
		settingsFrame.Position = UDim2.fromScale(0.5, 1.5)
		
		local jsOverlay = screenGui:FindFirstChild("JumpscareOverlay")
		if jsOverlay then
			jsOverlay.Visible = false
		end
		
		-- CLEAR BLACK SCREEN FADE
		local oldFade = screenGui:FindFirstChild("GameOverFade")
		if oldFade then 
			oldFade:Destroy() 
		end
		
		print("[DEBUG-CLIENT] Camera e Input reset...")
		startMenuCamera()
		lockMovement(true)
		
		task.wait(1)
		
		-- Fade out loading overlay properly
		local function fadeOutRecursive(obj: Instance)
			-- EXCLUDE WIN UI
			if obj.Name == "WinLabel" or obj.Name == "WinTimer" then return end

			if obj:IsA("GuiObject") then
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

		task.wait(1)
		loadingText.Text = "Done!"

		-- FIX: Ensure music restarts on reset exactly when "Done!" appears
		bgm = SoundService:FindFirstChild("BackgroundMusic")
		if bgm and bgm:IsA("Sound") then
			bgm.Volume = Settings.MUSIC_VOLUME or 0.3
			bgm:Play()
		end
		
		task.wait(1)

		fadeOutRecursive(loadingOverlay)
		task.wait(1)
		loadingOverlay.Visible = false
		
		print("[DEBUG-CLIENT] Reset completato.")
	end

	-- JUMPSCARE GUI
	local jumpscareOverlay = Instance.new("Frame")
	jumpscareOverlay.Name = "JumpscareOverlay"
	jumpscareOverlay.Size = UDim2.fromScale(1, 1)
	jumpscareOverlay.BackgroundColor3 = Color3.new(0, 0, 0)
	jumpscareOverlay.BackgroundTransparency = 0
	jumpscareOverlay.ZIndex = 50000
	jumpscareOverlay.Visible = false
	jumpscareOverlay.Parent = screenGui

	local jumpscareImage = Instance.new("ImageLabel")
	jumpscareImage.Name = "IShowSpeed"
	jumpscareImage.Size = UDim2.fromScale(1, 1) -- Set to fill screen entirely
	jumpscareImage.Position = UDim2.fromScale(0.5, 0.5)
	jumpscareImage.AnchorPoint = Vector2.new(0.5, 0.5)
	jumpscareImage.BackgroundTransparency = 1
	jumpscareImage.ImageTransparency = 0
	jumpscareImage.ScaleType = Enum.ScaleType.Stretch -- Use Stretch to fill screen as requested
	jumpscareImage.Image = "rbxassetid://124354529432666" 
	jumpscareImage.ZIndex = 50001
	jumpscareImage.Parent = jumpscareOverlay

	-- GAME OVER LOGIC
	local function triggerGameOver()
		-- Prevent double triggering
		if not game:GetAttribute("GameStarted") then return end

		print("[DEBUG-CLIENT] Game Over Triggerato!")
		game:SetAttribute("GameStarted", false)
		lockMovement(true)

		local standupSound: Sound? = nil -- Riferimento al suono STANDUP per fermarlo prima del jumpscare

		-- Fade out music
		bgm = SoundService:FindFirstChild("BackgroundMusic")
		if bgm and bgm:IsA("Sound") then
			TweenService:Create(bgm, TweenInfo.new(1.5), { Volume = 0 }):Play()
		end

		-- ── Sequenza Nonno ─────────────────────────────────────────────────────
		local grandpa = Workspace:FindFirstChild("ilNonno") :: Model?
		if grandpa then
			-- 1. Imposta camera scriptable e tween verso il Nonno
			camera.CameraType = Enum.CameraType.Scriptable
			local rootPart = grandpa:FindFirstChild("HumanoidRootPart") :: BasePart?
			if rootPart then
				-- Posizione camera: di fronte al nonno, leggermente in alto
				local faceCF = rootPart.CFrame
				local camTarget = faceCF * CFrame.new(0, 1.5, -5) -- -5 = davanti al nonno (in Roblox +Z è DIETRO)
				local camLookAt = faceCF.Position + Vector3.new(0, 1.5, 0) -- guarda la testa
				local targetCamCF = CFrame.lookAt(camTarget.Position, camLookAt)

				local camTween = TweenService:Create(
					camera,
					TweenInfo.new(2.0, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
					{ CFrame = targetCamCF }
				)
				camTween:Play()
				camTween.Completed:Wait()

				task.wait(0.3)

				-- 2. Prima dell'animazione di salto: salva le CFrame ORIGINALI di tutte le parti
				--    (usate per ripristinare client-side subito dopo il salto)
				local savedPartCFrames: {[BasePart]: CFrame} = {}
				for _, p in grandpa:GetDescendants() do
					if p:IsA("BasePart") then
						savedPartCFrames[p] = p.CFrame
					end
				end
				savedPartCFrames[rootPart] = rootPart.CFrame  -- assicura che HRP sia incluso

				-- 3. Salva offset di ogni parte rispetto all'HRP per il Heartbeat
				--    (muove TUTTE le parti insieme, inclusi capelli/hat senza weld)
				local partOffsets: {[BasePart]: CFrame} = {}
				for _, p in grandpa:GetDescendants() do
					if p:IsA("BasePart") and p ~= rootPart then
						-- Offset della parte rispetto all'HRP in spazio locale
						partOffsets[p] = rootPart.CFrame:Inverse() * p.CFrame
					end
				end

				-- Heartbeat: aggiorna tutte le parti secondarie mentre HRP si muove
				local heartConn = RunService.Heartbeat:Connect(function()
					for part, offset in partOffsets do
						part.CFrame = rootPart.CFrame * offset
					end
				end)

				-- Fase A: abbassa leggermente (raccoglie slancio, 0.25s)
				local sinkCF = rootPart.CFrame * CFrame.new(0, -0.6, 0)
				TweenService:Create(
					rootPart,
					TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
					{ CFrame = sinkCF }
				):Play()
				task.wait(0.25)

				-- Fase B: scatta verso la CAMERA (world-space)
				local nonnoPos  = rootPart.Position
				local camPos    = camera.CFrame.Position
				local towardCam = (Vector3.new(camPos.X, nonnoPos.Y, camPos.Z) - nonnoPos).Unit
				local jumpPos   = nonnoPos + towardCam * 3 + Vector3.new(0, 1.8, 0)
				local jumpCF    = CFrame.lookAt(jumpPos, camPos + Vector3.new(0, 1.8, 0))
				local jumpTween = TweenService:Create(
					rootPart,
					TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
					{ CFrame = jumpCF }
				)

				-- 3. Cambia faccia ad arrabbiata
				local head = grandpa:FindFirstChild("Head") :: BasePart?
				if head then
					local face = head:FindFirstChild("face")
					if face and face:IsA("Decal") then
						face.Texture = Settings.GRANDPA_FACE_ANGRY or "rbxassetid://10749405"
					end
				end

				-- 4. Suona SFX del Nonno che si alza
				if Settings.GRANDPA_STANDUP_ID and Settings.GRANDPA_STANDUP_ID ~= "rbxassetid://0" then
					standupSound = Instance.new("Sound")
					standupSound.SoundId = Settings.GRANDPA_STANDUP_ID
					standupSound.Volume = (Settings.GRANDPA_STANDUP_VOLUME :: number?) or 3.0
					standupSound.Parent = workspace.CurrentCamera
					standupSound:Play()
				end

				jumpTween:Play()
				jumpTween.Completed:Wait()
				task.wait(0.15)

				-- Stop Heartbeat: ripristina SUBITO tutte le parti alle posizioni originali
				-- (evita che il nonno resti in aria visivamente alla prossima partita)
				heartConn:Disconnect()
				for part, savedCF in savedPartCFrames do
					part.CFrame = savedCF
				end

			end
		end

		-- ── Jumpscare (direttamente dopo la sequenza, senza fade al nero) ───
		jumpscareOverlay.BackgroundTransparency = 1
		jumpscareImage.ImageTransparency = 0
		jumpscareOverlay.Visible = true

		-- ── Flash bianco ─────────────────────────────────────────────────────
		local flashFrame = Instance.new("Frame")
		flashFrame.Name = "JumpscareFlash"
		flashFrame.Size = UDim2.fromScale(1, 1)
		flashFrame.BackgroundColor3 = Color3.new(1, 1, 1)
		flashFrame.BackgroundTransparency = 0
		flashFrame.BorderSizePixel = 0
		flashFrame.ZIndex = 60000 -- Sopra il jumpscare overlay (50001)
		flashFrame.Parent = screenGui
		TweenService:Create(flashFrame, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundTransparency = 1
		}):Play()
		task.delay(0.5, function() flashFrame:Destroy() end)

		-- Ferma STANDUP quando il flash ha finito il fade-out (0.35s) + 0.3s extra
		task.delay(0.65, function()
			if standupSound then
				standupSound:Stop()
				standupSound:Destroy()
				standupSound = nil
			end
		end)

		local scarySound = Instance.new("Sound")
		scarySound.SoundId = Settings.SOUNDS.JUMPSCARE
		scarySound.Volume = 10
		scarySound.PlaybackSpeed = 1
		scarySound.Parent = SoundService
		scarySound:Play()

		local interventionSound = Instance.new("Sound")
		interventionSound.SoundId = "rbxassetid://5033272182"
		interventionSound.Volume = 10
		interventionSound.PlaybackSpeed = 1
		interventionSound.Parent = SoundService
		interventionSound:Play()

		-- Ripristina camera
		camera.CameraType = Enum.CameraType.Custom

		task.wait(3)
		jumpscareOverlay.Visible = false
		scarySound:Destroy()
		interventionSound:Destroy()

		-- Restore BGM volume for next game
		if bgm and bgm:IsA("Sound") then
			bgm.Volume = Settings.MUSIC_VOLUME or 0.3
			bgm:Stop()
		end

		fullReset()
	end

	-- WIN UI
	local winLabel = Instance.new("TextLabel")
	winLabel.Name = "WinLabel"
	winLabel.Size = UDim2.fromScale(1, 0.2)
	winLabel.Position = UDim2.fromScale(0.5, 1.2) -- Start below
	winLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	winLabel.BackgroundTransparency = 1
	winLabel.Font = Enum.Font.LuckiestGuy
	winLabel.TextColor3 = Color3.fromRGB(0, 255, 100) -- Green
	winLabel.Text = "HAI VINTO!"
	winLabel.TextSize = 100
	winLabel.Visible = false
	winLabel.ZIndex = 100000
	winLabel.Parent = screenGui
	
	local winStroke = Instance.new("UIStroke")
	winStroke.Thickness = 8
	winStroke.Color = Color3.new(1, 1, 1)
	winStroke.Parent = winLabel

	local function triggerWin()
		if not game:GetAttribute("GameStarted") then return end
		game:SetAttribute("GameStarted", false)
		print("[DEBUG-CLIENT] Win Triggerata!")
		
		-- 1. Music Fade Out
		if bgm then
			local fadeInfo = TweenInfo.new(0.5, Enum.EasingStyle.Linear)
			TweenService:Create(bgm, fadeInfo, {Volume = 0}):Play()
		end
		
		-- 2. Wait half a second before celebration
		task.wait(0.5)
		
		timerContainer.Visible = false  -- hide entire timer (title + number)
		winLabel.Visible = true
		winLabel.TextTransparency = 0 -- FORCE VISIBLE
		winLabel.Position = UDim2.fromScale(0.5, 1.2)
		winLabel.ZIndex = 100000 -- FORCE FRONT
		
		-- Play Win Sound
		local winSound = Instance.new("Sound")
		winSound.SoundId = Settings.WIN_SOUND_ID or "rbxassetid://356817586"
		winSound.Volume = 1
		winSound.Parent = SoundService
		winSound:Play()
		
		-- Slide Up Animation (Smooth)
		TweenService:Create(winLabel, TweenInfo.new(1.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Position = UDim2.fromScale(0.5, 0.5)
		}):Play()
		
		-- Confetti
		task.spawn(function()
			for i = 1, 50 do
				local c = Instance.new("Frame")
				c.Size = UDim2.fromOffset(math.random(10, 20), math.random(10, 20))
				c.Position = UDim2.fromScale(math.random(0, 100)/100, 1.1)
				c.BackgroundColor3 = Color3.fromHSV(math.random(), 1, 1)
				c.Rotation = math.random(0, 360)
				c.ZIndex = 100001
				c.Parent = screenGui
				
				local corner = Instance.new("UICorner")
				corner.CornerRadius = UDim.new(0.5, 0)
				corner.Parent = c
				
				local targetPos = UDim2.fromScale(c.Position.X.Scale + (math.random(-2, 2)/10), math.random(-2, 5)/10)
				TweenService:Create(c, TweenInfo.new(math.random(2, 4), Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
					Position = targetPos,
					Rotation = c.Rotation + math.random(360, 720),
					BackgroundTransparency = 1
				}):Play()
				
				task.wait(0.05)
				task.delay(4, function() c:Destroy() end)
			end
		end)
		
		task.wait(6)
		winLabel.Visible = false
		winSound:Destroy()
		fullReset()
	end

	local gameWinEvent = ReplicatedStorage:WaitForChild("GameWinEvent")
	gameWinEvent.OnClientEvent:Connect(function()
		triggerWin()
	end)
	
	local timerUpdateEvent = ReplicatedStorage:WaitForChild("TimerUpdateEvent")
	timerUpdateEvent.OnClientEvent:Connect(function(remaining)
		if not game:GetAttribute("GameStarted") then 
			timerContainer.Visible = false 
			return 
		end
		
		timerContainer.Visible = true
		timerLabel.TextTransparency = 0 -- FORCE VISIBLE
		timerTitle.TextTransparency = 0
		timerContainer.BackgroundTransparency = 0.5
		
		local mins = math.floor(remaining / 60)
		local secs = math.floor(remaining % 60)
		timerLabel.Text = string.format("%02d:%02d", mins, secs)
		
		-- Pulse if near end
		if remaining < 10 then
			timerLabel.TextColor3 = Color3.new(1, 0, 0)
			TweenService:Create(timerLabel, TweenInfo.new(0.2), {TextSize = 44}):Play()
			task.delay(0.2, function()
				TweenService:Create(timerLabel, TweenInfo.new(0.2), {TextSize = 36}):Play()
			end)
		else
			timerLabel.TextColor3 = Color3.new(1, 1, 1)
		end
	end)

	local gameResetEvent = ReplicatedStorage:WaitForChild("GameResetEvent")
	gameResetEvent.OnClientEvent:Connect(function()
		fullReset()
	end)

	local gameOverEvent = ReplicatedStorage:WaitForChild("GameOverEvent")
	gameOverEvent.OnClientEvent:Connect(function()
		print("[DEBUG-CLIENT] GameOverEvent ricevuto (fallback/admin)")
		task.spawn(triggerGameOver)
	end)

	-- NonnoStandsUpEvent: sequenza principale (trigger da NPCService quando tutti gli NPC muoiono)
	local nonnoStandsUpEvent = ReplicatedStorage:WaitForChild("NonnoStandsUpEvent")
	nonnoStandsUpEvent.OnClientEvent:Connect(function()
		print("[DEBUG-CLIENT] NonnoStandsUpEvent ricevuto — avvio sequenza Nonno")
		task.spawn(triggerGameOver)
	end)

	-- NonnoWakeEvent: nonno si sveglia (2 NPC rimasti) — lato client solo animazione faccia
	local nonnoWakeEvent = ReplicatedStorage:WaitForChild("NonnoWakeEvent")
	nonnoWakeEvent.OnClientEvent:Connect(function()
		print("[DEBUG-CLIENT] NonnoWakeEvent — Nonno si sveglia!")
		-- Visivo lato client: potrebbe aggiungere un overlay o effetto
		-- La faccia è già cambiata server-side da GrandpaService
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
			if game:GetAttribute("GameStarted") then
				print("[DEBUG-CLIENT] Personaggio morto in partita! Avvio Jumpscare...")
				triggerGameOver()
			else
				print("[DEBUG-CLIENT] Personaggio morto fuori partita. Reset normale...")
				task.wait(2)
				fullReset()
			end
		end)
	end
	
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then 
		print("[DEBUG-CLIENT] Personaggio già presente all'init.")
		onCharacter(player.Character) 
	end

	-- Save original transparencies to restore cleanly on reset
	for _, v in screenGui:GetDescendants() do
		if v:IsA("GuiObject") then
			v:SetAttribute("OrigBgTrans", v.BackgroundTransparency)
			if v:IsA("TextLabel") or v:IsA("TextButton") then
				v:SetAttribute("OrigTextTrans", v.TextTransparency)
			end
			if v:IsA("ImageLabel") or v:IsA("ImageButton") then
				v:SetAttribute("OrigImgTrans", v.ImageTransparency)
			end
		end
		if v:IsA("UIStroke") then
			v:SetAttribute("OrigStrokeTrans", v.Transparency)
		end
	end
end

return MenuService
