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
	mainList.Size = UDim2.fromScale(0.25, 0.6) -- Smaller UI
	mainList.Position = UDim2.fromScale(0.01, 0.01)
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
	
	-- Stacking logic
	local lastItem: CanvasGroup? = nil
	local lastMsgText = ""
	local stackCount = 0
	local activeTimers = {} -- Store timer objects to cancel them

	event.OnClientEvent:Connect(function(message: string)
		if lastItem and lastItem.Parent and lastMsgText == message then
			-- STACK!
			stackCount += 1
			local label = lastItem:FindFirstChildWhichIsA("TextLabel")
			if label then
				label.Text = string.format("%s (x%d)", message, stackCount)
			end
			
			-- Reset Timer
			if activeTimers[lastItem] then
				task.cancel(activeTimers[lastItem])
			end
			
			-- notifySound:Play() -- REMOVED: Clicks only on menu buttons
			
			local item = lastItem -- Local ref for closure
			activeTimers[item] = task.delay(3, function()
				local fadeOut = TweenService:Create(item, TweenInfo.new(0.3), {GroupTransparency = 1})
				fadeOut:Play()
				fadeOut.Completed:Connect(function()
					item:Destroy()
					if lastItem == item then lastItem = nil end
				end)
			end)
			return
		end

		-- Create individual notification item
		stackCount = 1
		lastMsgText = message
		
		local item = Instance.new("CanvasGroup")
		item.Name = "NotifyItem"
		item.Size = UDim2.fromScale(1, 0.06) -- Thinner items
		item.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
		item.GroupTransparency = 1
		item.BorderSizePixel = 0
		item.Parent = mainList
		lastItem = item
		
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
		
		-- notifySound:Play() -- REMOVED: Clicks only on menu buttons
		
		-- Animations
		local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
		TweenService:Create(item, tweenInfo, {GroupTransparency = 0}):Play()
		
		-- Lifecycle
		local duration = (Settings.NOTIFY_DURATION_BASE or 1.5) + (#message * (Settings.NOTIFY_CHAR_MULTIPLIER or 0.05))
		
		activeTimers[item] = task.delay(duration, function()
			local fadeOut = TweenService:Create(item, tweenInfo, {GroupTransparency = 1})
			fadeOut:Play()
			fadeOut.Completed:Connect(function()
				item:Destroy()
				if lastItem == item then lastItem = nil end
			end)
		end)
	end)
end

return NotificationService
