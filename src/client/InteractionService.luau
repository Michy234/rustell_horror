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
	local activePromptItems = {} -- Prompt -> Frame
	local promptConnections = {} -- Prompt -> List of connections
	local billboardShowCount = {} -- BillboardGui -> number of visible prompts

	local function getOrCreateBillboard(adornee: Instance): BillboardGui
		if activeBillboards[adornee] then return activeBillboards[adornee] end
		
		local bgui = Instance.new("BillboardGui")
		bgui.Name = "PromptUI_" .. adornee.Name
		bgui.Size = UDim2.fromOffset(250, 100)
		bgui.AlwaysOnTop = false
		bgui.ExtentsOffset = Vector3.new(0, 2, 0)
		bgui.ResetOnSpawn = false
		bgui.MaxDistance = 25 -- Impedisce di vederlo da lontano
		bgui.ZIndexBehavior = Enum.ZIndexBehavior.Global
		bgui.Adornee = adornee:IsA("BasePart") and adornee or (adornee:IsA("Model") and adornee.PrimaryPart) or nil
		
		-- Use CanvasGroup for fade in/out
		local listFrame = Instance.new("CanvasGroup")
		listFrame.Name = "ListFrame"
		listFrame.Size = UDim2.fromScale(1, 1)
		listFrame.BackgroundTransparency = 1
		listFrame.GroupTransparency = 1 -- Start transparent
		listFrame.Parent = bgui
		
		local layout = Instance.new("UIListLayout")
		layout.Padding = UDim.new(0, 5)
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
		layout.Parent = listFrame

		bgui.Parent = playerGui
		activeBillboards[adornee] = bgui
		return bgui
	end

	local function createPromptItem(prompt: ProximityPrompt, billboard: BillboardGui)
		local list = billboard:FindFirstChild("ListFrame") or billboard
		
		local item = Instance.new("Frame")
		item.Name = "PromptItem"
		item.Size = UDim2.new(1, 0, 0, 40)
		item.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
		item.BackgroundTransparency = 0.2
		item.BorderSizePixel = 0
		item.Parent = list
		
		Instance.new("UICorner", item).CornerRadius = UDim.new(0, 6)
		
		-- Key Frame
		local keyFrame = Instance.new("Frame")
		keyFrame.Size = UDim2.fromOffset(28, 28)
		keyFrame.Position = UDim2.new(0, 6, 0.5, 0)
		keyFrame.AnchorPoint = Vector2.new(0, 0.5)
		keyFrame.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
		keyFrame.Parent = item
		
		Instance.new("UICorner", keyFrame).CornerRadius = UDim.new(0, 4)

		local keyText = Instance.new("TextLabel")
		keyText.Size = UDim2.fromScale(1, 1)
		keyText.BackgroundTransparency = 1
		keyText.TextColor3 = Color3.new(1, 1, 1)
		keyText.Text = prompt.KeyboardKeyCode.Name
		keyText.Font = Enum.Font.GothamBold
		keyText.TextSize = 16
		keyText.Parent = keyFrame

		-- Action Text
		local actionText = Instance.new("TextLabel")
		actionText.Name = "ActionLabel"
		actionText.Size = UDim2.new(1, -45, 1, 0)
		actionText.Position = UDim2.fromOffset(40, 0)
		actionText.BackgroundTransparency = 1
		actionText.TextColor3 = Color3.new(1, 1, 1)
		actionText.Text = prompt.ActionText
		actionText.Font = Enum.Font.GothamBold
		actionText.TextSize = 14
		actionText.TextXAlignment = Enum.TextXAlignment.Left
		actionText.Parent = item

		-- Progress Bar (Hold)
		if prompt.HoldDuration > 0 then
			local barBg = Instance.new("Frame")
			barBg.Name = "ProgressBarBackground"
			barBg.Size = UDim2.new(1, 0, 0, 4)
			barBg.Position = UDim2.new(0, 0, 1, -4)
			barBg.BackgroundColor3 = Color3.new(0, 0, 0)
			barBg.BackgroundTransparency = 0.5
			barBg.BorderSizePixel = 0
			barBg.Parent = item
			
			local barFill = Instance.new("Frame")
			barFill.Name = "Fill"
			barFill.Size = UDim2.fromScale(0, 1)
			barFill.BackgroundColor3 = Color3.fromRGB(0, 255, 120)
			barFill.BorderSizePixel = 0
			barFill.Parent = barBg
			
			local progressConn: RunService.RenderStepped?
			
			local begin = prompt.PromptButtonHoldBegan:Connect(function()
				local startTime = tick()
				if progressConn then progressConn:Disconnect() end
				progressConn = RunService.RenderStepped:Connect(function()
					local alpha = math.clamp((tick() - startTime) / prompt.HoldDuration, 0, 1)
					barFill.Size = UDim2.fromScale(alpha, 1)
					if alpha >= 1 then 
						if progressConn then progressConn:Disconnect() end
						progressConn = nil
					end
				end)
			end)
			
			local ended = prompt.PromptButtonHoldEnded:Connect(function()
				if progressConn then progressConn:Disconnect() end
				progressConn = nil
				barFill.Size = UDim2.fromScale(0, 1)
			end)
			
			promptConnections[prompt] = {begin, ended}
		end

		activePromptItems[prompt] = item
		
		-- Property binding for real-time text updates
		local propConn = prompt:GetPropertyChangedSignal("ActionText"):Connect(function()
			actionText.Text = prompt.ActionText
		end)
		table.insert(promptConnections[prompt] or {}, propConn)
	end

	ProximityPromptService.PromptShown:Connect(function(prompt, _)
		if prompt.Style == Enum.ProximityPromptStyle.Custom then
			local adornee = prompt.Parent
			if not adornee then return end
			
			local billboard = getOrCreateBillboard(adornee)
			if activePromptItems[prompt] then activePromptItems[prompt]:Destroy() end
			createPromptItem(prompt, billboard)
			
			-- Track how many prompts are showing for this billboard
			billboardShowCount[billboard] = (billboardShowCount[billboard] or 0) + 1
			
			-- Fade in only if it's the first prompt or if it was fading out
			local container = billboard:FindFirstChild("ListFrame")
			if container and container:IsA("CanvasGroup") then
				TweenService:Create(container, TweenInfo.new(0.3), {GroupTransparency = 0}):Play()
			end
		end
	end)

	ProximityPromptService.PromptHidden:Connect(function(prompt)
		local item = activePromptItems[prompt]
		if item then
			local billboard = item.Parent.Parent :: BillboardGui
			local container = billboard:FindFirstChild("ListFrame")
			
			billboardShowCount[billboard] = math.max(0, (billboardShowCount[billboard] or 1) - 1)
			
			if billboardShowCount[billboard] == 0 then
				-- Last prompt hidden, fade out everything
				if container and container:IsA("CanvasGroup") then
					local fadeOut = TweenService:Create(container, TweenInfo.new(0.3), {GroupTransparency = 1})
					fadeOut:Play()
					fadeOut.Completed:Connect(function()
						if billboardShowCount[billboard] == 0 then
							item:Destroy()
							activePromptItems[prompt] = nil
							
							if promptConnections[prompt] then
								for _, c in promptConnections[prompt] do c:Disconnect() end
								promptConnections[prompt] = nil
							end
							
							-- Cleanup billboard
							local adornee = billboard.Adornee
							if adornee then activeBillboards[adornee] = nil end
							billboardShowCount[billboard] = nil
							billboard:Destroy()
						end
					end)
				else
					item:Destroy()
					activePromptItems[prompt] = nil
				end
			else
				-- Other prompts still visible, just destroy this item
				item:Destroy()
				activePromptItems[prompt] = nil
				if promptConnections[prompt] then
					for _, c in promptConnections[prompt] do c:Disconnect() end
					promptConnections[prompt] = nil
				end
			end
		end
	end)
end

return InteractionService
