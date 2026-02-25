--!strict
local ProximityPromptService = game:GetService("ProximityPromptService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local InteractionService = {}

function InteractionService.init()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	local activeBillboards = {} -- Adornee -> BillboardGui
	local activePromptItems = {} -- Prompt -> CanvasGroup
	local promptConnections = {} -- Prompt -> List of connections

	local function getOrCreateBillboard(adornee: Instance): BillboardGui
		if activeBillboards[adornee] then
			return activeBillboards[adornee]
		end

		local bgui = Instance.new("BillboardGui")
		bgui.Name = "PromptUI_" .. adornee.Name
		bgui.Size = UDim2.fromOffset(250, 150)
		bgui.AlwaysOnTop = true
		bgui.ExtentsOffset = Vector3.new(0, 2, 0)
		bgui.ResetOnSpawn = false
		bgui.MaxDistance = 35
		bgui.ZIndexBehavior = Enum.ZIndexBehavior.Global
		bgui.Adornee = adornee:IsA("BasePart") and adornee or (adornee:IsA("Model") and adornee.PrimaryPart) or nil

		local layout = Instance.new("UIListLayout")
		layout.Padding = UDim.new(0, 5)
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
		layout.Parent = bgui

		bgui.Parent = playerGui
		activeBillboards[adornee] = bgui
		return bgui
	end

	local function createPromptItem(prompt: ProximityPrompt, billboard: BillboardGui)
		local item = Instance.new("CanvasGroup")
		item.Name = "PromptItem"
		item.Size = UDim2.new(1, 0, 0, 40)
		item.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
		item.BackgroundTransparency = 0.2
		item.GroupTransparency = 1
		item.BorderSizePixel = 0
		item.Parent = billboard

		Instance.new("UICorner", item).CornerRadius = UDim.new(0, 6)

		-- Key Frame (Circular Background for the Key)
		local keyFrame = Instance.new("Frame")
		keyFrame.Size = UDim2.fromOffset(32, 32)
		keyFrame.Position = UDim2.new(0, 4, 0.5, 0)
		keyFrame.AnchorPoint = Vector2.new(0, 0.5)
		keyFrame.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
		keyFrame.ZIndex = 2
		keyFrame.Parent = item

		Instance.new("UICorner", keyFrame).CornerRadius = UDim.new(1, 0)

		local keyText = Instance.new("TextLabel")
		keyText.Size = UDim2.fromScale(1, 1)
		keyText.BackgroundTransparency = 1
		keyText.TextColor3 = Color3.new(1, 1, 1)
		keyText.Text = prompt.KeyboardKeyCode.Name
		keyText.Font = Enum.Font.GothamBold
		keyText.TextSize = 16
		keyText.ZIndex = 3
		keyText.Parent = keyFrame

		-- Action Text
		local actionText = Instance.new("TextLabel")
		actionText.Name = "ActionLabel"
		actionText.Size = UDim2.new(1, -50, 1, 0)
		actionText.Position = UDim2.fromOffset(45, 0)
		actionText.BackgroundTransparency = 1
		actionText.TextColor3 = Color3.new(1, 1, 1)
		actionText.Text = prompt.ActionText
		actionText.Font = Enum.Font.GothamBold
		actionText.TextSize = 14
		actionText.TextXAlignment = Enum.TextXAlignment.Left
		actionText.ZIndex = 2
		actionText.Parent = item

		-- Background Fill Progress (Hold)
		if prompt.HoldDuration > 0 then
			local backgroundFill = Instance.new("Frame")
			backgroundFill.Name = "BackgroundFill"
			backgroundFill.Size = UDim2.fromScale(0, 1)
			backgroundFill.BackgroundColor3 = Color3.fromRGB(0, 255, 150)
			backgroundFill.BackgroundTransparency = 0.5
			backgroundFill.BorderSizePixel = 0
			backgroundFill.ZIndex = 1
			backgroundFill.Parent = item

			local uiCorner = Instance.new("UICorner")
			uiCorner.CornerRadius = UDim.new(0, 6)
			uiCorner.Parent = backgroundFill

			local progressConn: RBXScriptConnection?
			local sizeTween: any = nil

			local begin = prompt.PromptButtonHoldBegan:Connect(function()
				if sizeTween then
					sizeTween:Cancel()
					sizeTween = nil
				end
				backgroundFill.Size = UDim2.fromScale(0, 1)
				backgroundFill.BackgroundTransparency = 0.5

				local startTime = tick()
				if progressConn then
					progressConn:Disconnect()
				end
				progressConn = RunService.RenderStepped:Connect(function()
					local alpha = math.clamp((tick() - startTime) / prompt.HoldDuration, 0, 1)
					backgroundFill.Size = UDim2.fromScale(alpha, 1)
					if alpha >= 1 then
						if progressConn then
							progressConn:Disconnect()
						end
						progressConn = nil
					end
				end)
			end)

			local ended = prompt.PromptButtonHoldEnded:Connect(function()
				if progressConn then
					progressConn:Disconnect()
				end
				progressConn = nil
				sizeTween = TweenService:Create(
					backgroundFill,
					TweenInfo.new(0.2, Enum.EasingStyle.Sine),
					{ BackgroundTransparency = 1 }
				)
				sizeTween:Play()
			end)

			promptConnections[prompt] = { begin, ended }
		end

		activePromptItems[prompt] = item

		local propConn = prompt:GetPropertyChangedSignal("ActionText"):Connect(function()
			actionText.Text = prompt.ActionText
		end)
		if not promptConnections[prompt] then
			promptConnections[prompt] = {}
		end
		table.insert(promptConnections[prompt], propConn)
	end

	ProximityPromptService.PromptShown:Connect(function(prompt, _)
		if prompt.Style == Enum.ProximityPromptStyle.Custom then
			local adornee = prompt.Parent
			if not adornee then
				return
			end

			local billboard = getOrCreateBillboard(adornee)
			if activePromptItems[prompt] then
				activePromptItems[prompt]:Destroy()
			end

			createPromptItem(prompt, billboard)
			local item = activePromptItems[prompt]

			if item then
				TweenService:Create(item, TweenInfo.new(0.2, Enum.EasingStyle.Sine), { GroupTransparency = 0 }):Play()
			end
		end
	end)

	ProximityPromptService.PromptHidden:Connect(function(prompt)
		local item = activePromptItems[prompt]
		if item then
			local billboard = item.Parent :: BillboardGui

			local fade = TweenService:Create(item, TweenInfo.new(0.2, Enum.EasingStyle.Sine), { GroupTransparency = 1 })
			fade:Play()
			fade.Completed:Connect(function(state)
				if state == Enum.PlaybackState.Completed and activePromptItems[prompt] == item then
					item:Destroy()
					activePromptItems[prompt] = nil

					if promptConnections[prompt] then
						for _, c in promptConnections[prompt] do
							c:Disconnect()
						end
						promptConnections[prompt] = nil
					end

					local hasOther = false
					for _, otherItem in activePromptItems do
						if otherItem.Parent == billboard then
							hasOther = true
							break
						end
					end

					if not hasOther then
						local adornee = billboard.Adornee
						if adornee then
							activeBillboards[adornee] = nil
						end
						billboard:Destroy()
					end
				end
			end)
		end
	end)
end

return InteractionService
