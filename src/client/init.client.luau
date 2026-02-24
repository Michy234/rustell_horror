local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

local screenGui = playerGui:WaitForChild("MainMenu")
local menuFrame = screenGui:WaitForChild("MenuFrame")
local playButton = menuFrame:WaitForChild("PlayButton")
local fadeFrame = screenGui:WaitForChild("FadeFrame")

local isPlaying = false

local function onPlay()
	if isPlaying then
		return
	end
	isPlaying = true

	-- Nasconde subito logo + bottone
	menuFrame.Visible = false

	-- Schermo nero che poi sfuma sul gioco
	fadeFrame.Visible = true
	fadeFrame.BackgroundTransparency = 0

	local tweenInfo = TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local tween = TweenService:Create(fadeFrame, tweenInfo, {
		BackgroundTransparency = 1,
	})

	tween.Completed:Connect(function()
		screenGui.Enabled = false
	end)

	tween:Play()
end

playButton.MouseButton1Click:Connect(onPlay)