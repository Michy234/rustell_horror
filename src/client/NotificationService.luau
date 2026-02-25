--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")

local Settings = require(ReplicatedStorage.Shared.Settings)

local NotificationService = {}

function NotificationService.init()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	
	-- Create GUI Container
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "NotificationGui"
	screenGui.ResetOnSpawn = false
	screenGui.Parent = playerGui
	
	-- List Container
	local mainList = Instance.new("Frame")
	mainList.Name = "NotifyList"
	mainList.Size = UDim2.fromScale(0.4, 0.8) -- Larger width for readability
	mainList.Position = UDim2.fromScale(0.02, 0.02) -- Top Left
	mainList.BackgroundTransparency = 1
	mainList.Parent = screenGui
	
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 5) -- Smaller padding
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Left -- Align Left
	layout.VerticalAlignment = Enum.VerticalAlignment.Top
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = mainList
	
	-- Sound
	local notifySound = Instance.new("Sound")
	notifySound.SoundId = Settings.SOUNDS.NOTIFY
	notifySound.Volume = 0.5
	notifySound.Parent = SoundService
	
	-- Listen for events
	local event = ReplicatedStorage:WaitForChild("NotificationEvent") :: RemoteEvent
	
	event.OnClientEvent:Connect(function(message: string)
		-- Create individual notification item
		local item = Instance.new("CanvasGroup")
		item.Name = "NotifyItem"
		item.Size = UDim2.fromScale(1, 0.12) -- Larger height for larger text
		item.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
		item.GroupTransparency = 1
		item.BorderSizePixel = 0
		item.Parent = mainList
		
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = item
		
		local gradient = Instance.new("UIGradient")
		gradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(50, 50, 50)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(20, 20, 20))
		})
		gradient.Rotation = 45
		gradient.Parent = item
		
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(0.95, 0.9)
		label.Position = UDim2.fromScale(0.025, 0.05)
		label.BackgroundTransparency = 1
		label.TextColor3 = Color3.new(1, 1, 1)
		label.TextScaled = true
		label.Font = Enum.Font.GothamBold
		label.Text = message
		label.Parent = item
		
		notifySound:Play()
		
		-- Animations
		local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
		
		-- Fade In
		TweenService:Create(item, tweenInfo, {GroupTransparency = 0}):Play()
		
		-- Lifecycle
		local duration = (Settings.NOTIFY_DURATION_BASE or 1.5) + (#message * (Settings.NOTIFY_CHAR_MULTIPLIER or 0.05))
		
		task.delay(duration, function()
			local fadeOut = TweenService:Create(item, tweenInfo, {GroupTransparency = 1})
			fadeOut:Play()
			fadeOut.Completed:Connect(function()
				item:Destroy()
			end)
		end)
	end)
end

return NotificationService
