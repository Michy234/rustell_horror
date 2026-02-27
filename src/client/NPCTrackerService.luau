--!strict
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Settings = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Settings"))

local NPCTrackerService = {}

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local trackerDistance = Settings.NPC_TRACKER_DISTANCE or 100

-- Main ScreenGui
local screenGui: ScreenGui
-- Track active rows: npcModel -> wrapper frame
local activeCards: {[Model]: Frame} = {}

-- ═══════════════════════════════════════════════════════════
-- UI CREATION
-- ═══════════════════════════════════════════════════════════

local function createScreenGui(): ScreenGui
	local gui = Instance.new("ScreenGui")
	gui.Name = "NPCTrackerUI"
	gui.IgnoreGuiInset = false
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 50
	gui.Parent = playerGui

	-- Container on the left side, vertical list
	local container = Instance.new("ScrollingFrame")
	container.Name = "CardContainer"
	container.Size = UDim2.new(0, 210, 0.75, 0)
	container.Position = UDim2.new(0, 10, 0.12, 0)
	container.BackgroundTransparency = 1
	container.BorderSizePixel = 0
	container.ScrollBarThickness = 3
	container.ScrollBarImageColor3 = Color3.fromRGB(255, 255, 255)
	container.ScrollBarImageTransparency = 0.5
	container.CanvasSize = UDim2.new(0, 0, 0, 0) -- auto-managed
	container.AutomaticCanvasSize = Enum.AutomaticSize.Y
	container.Parent = gui

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.Name
	layout.Padding = UDim.new(0, 8)
	layout.Parent = container

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 4)
	padding.PaddingLeft = UDim.new(0, 4)
	padding.PaddingRight = UDim.new(0, 4)
	padding.Parent = container

	return gui
end

local function createNPCCard(npc: Model): Frame
	-- Wrapper frame for the row (card + arrow side by side)
	local wrapper = Instance.new("Frame")
	wrapper.Name = npc.Name
	wrapper.Size = UDim2.new(1, 0, 0, 48)
	wrapper.BackgroundTransparency = 1
	wrapper.BorderSizePixel = 0
	wrapper.Parent = nil

	-- Card body (CanvasGroup for fade support)
	local card = Instance.new("CanvasGroup")
	card.Name = "CardBody"
	card.Size = UDim2.new(1, -30, 1, 0)
	card.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
	card.BackgroundTransparency = 0.15
	card.BorderSizePixel = 0
	card.GroupTransparency = 0
	card.Parent = wrapper

	local cardCorner = Instance.new("UICorner")
	cardCorner.CornerRadius = UDim.new(0, 8)
	cardCorner.Parent = card

	-- Direction arrow (right of card, built from Frames)
	local arrowColor = Color3.fromRGB(255, 255, 255)
	local outlineColor = Color3.fromRGB(200, 200, 220)

	local arrowFrame = Instance.new("Frame")
	arrowFrame.Name = "DirectionArrow"
	arrowFrame.Size = UDim2.fromOffset(36, 26)
	arrowFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	arrowFrame.Position = UDim2.new(1, -18, 0.5, 0)
	arrowFrame.BackgroundTransparency = 1
	arrowFrame.Rotation = 0
	arrowFrame.Parent = wrapper

	-- Shaft (slim horizontal bar)
	local shaft = Instance.new("Frame")
	shaft.Name = "Shaft"
	shaft.Size = UDim2.fromOffset(20, 8)
	shaft.Position = UDim2.fromOffset(0, 9)
	shaft.BackgroundColor3 = arrowColor
	shaft.BorderSizePixel = 0
	shaft.Parent = arrowFrame

	local shaftStroke = Instance.new("UIStroke")
	shaftStroke.Color = outlineColor
	shaftStroke.Thickness = 1
	shaftStroke.Transparency = 0.3
	shaftStroke.Parent = shaft

	-- Arrowhead (rotated square → diamond, shaft covers left corners)
	local arrowHead = Instance.new("Frame")
	arrowHead.Name = "Head"
	arrowHead.Size = UDim2.fromOffset(19, 19)
	arrowHead.AnchorPoint = Vector2.new(0.5, 0.5)
	arrowHead.Position = UDim2.fromOffset(25, 13)
	arrowHead.Rotation = 45
	arrowHead.BackgroundColor3 = arrowColor
	arrowHead.BorderSizePixel = 0
	arrowHead.Parent = arrowFrame

	local headStroke = Instance.new("UIStroke")
	headStroke.Color = outlineColor
	headStroke.Thickness = 1
	headStroke.Transparency = 0.3
	headStroke.Parent = arrowHead

	-- ── Left: 3D Head viewport ──
	local viewport = Instance.new("ViewportFrame")
	viewport.Name = "HeadViewport"
	viewport.Size = UDim2.fromOffset(40, 40)
	viewport.Position = UDim2.new(0, 4, 0.5, -20)
	viewport.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
	viewport.BackgroundTransparency = 0.5
	viewport.BorderSizePixel = 0
	viewport.Parent = card

	local vpCorner = Instance.new("UICorner")
	vpCorner.CornerRadius = UDim.new(0, 6)
	vpCorner.Parent = viewport

	-- Clone the NPC head + all accessories into the viewport
	local head = npc:FindFirstChild("Head")
	if head then
		-- WorldModel is required for proper ViewportFrame rendering
		local worldModel = Instance.new("WorldModel")
		worldModel.Parent = viewport

		local headClone = head:Clone()
		headClone.Anchored = true
		-- Rotate head 180° so the face points toward the camera
		headClone.CFrame = CFrame.new(0, 0, 0) * CFrame.Angles(0, math.rad(180), 0)
		headClone.Parent = worldModel

		-- Clone all accessories (hair, hats, face accessories)
		for _, child in npc:GetChildren() do
			if child:IsA("Accessory") then
				local accClone = child:Clone()
				accClone.Parent = worldModel
				-- Position the accessory relative to the head
				local handle = accClone:FindFirstChild("Handle")
				if handle and handle:IsA("BasePart") then
					handle.Anchored = true
					-- Find the attachment in the accessory handle
					local accAttach = handle:FindFirstChildOfClass("Attachment")
					local headAttach = accAttach and headClone:FindFirstChild(accAttach.Name)
					if headAttach and headAttach:IsA("Attachment") then
						-- Position handle using attachment offsets
						handle.CFrame = headClone.CFrame
							* headAttach.CFrame
							* accAttach.CFrame:Inverse()
					else
						-- Fallback: just place near head
						handle.CFrame = headClone.CFrame
					end
				end
			end
		end

		-- Camera looking at the front of the face
		local cam = Instance.new("Camera")
		cam.CFrame = CFrame.new(Vector3.new(0, 0.2, 2.5), Vector3.new(0, 0.1, 0))
		cam.Parent = viewport
		viewport.CurrentCamera = cam
	else
		-- Fallback emoji
		local emoji = Instance.new("TextLabel")
		emoji.Size = UDim2.fromScale(1, 1)
		emoji.BackgroundTransparency = 1
		emoji.Text = "😐"
		emoji.TextScaled = true
		emoji.Parent = viewport
	end

	-- ── Right content ──
	local cx = 48 -- content start X
	local cw = -56 -- content width offset

	-- Row 1: Name + Salt on same line
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "NameLabel"
	nameLabel.Size = UDim2.new(0.5, -24, 0, 14)
	nameLabel.Position = UDim2.fromOffset(cx, 4)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = npc.Name
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextColor3 = Color3.new(1, 1, 1)
	nameLabel.TextScaled = true
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Parent = card

	-- Salt preference (right of name)
	local saltLabel = Instance.new("TextLabel")
	saltLabel.Name = "SaltLabel"
	saltLabel.Size = UDim2.new(0.5, -4, 0, 14)
	saltLabel.Position = UDim2.new(0.5, 0, 0, 4)
	saltLabel.BackgroundTransparency = 1
	saltLabel.Font = Enum.Font.GothamBold
	saltLabel.TextScaled = true
	saltLabel.TextXAlignment = Enum.TextXAlignment.Right
	saltLabel.Parent = card

	local wantsSalt = npc:GetAttribute("WantsSalted") == true
	saltLabel.Text = wantsSalt and "🧂 SALATA" or "🍖 NATURALE"
	saltLabel.TextColor3 = wantsSalt
		and Color3.fromRGB(255, 220, 60)
		or Color3.fromRGB(140, 220, 140)

	-- Row 2: Hunger bar
	local hungerBg = Instance.new("Frame")
	hungerBg.Name = "HungerBg"
	hungerBg.Size = UDim2.new(1, cw, 0, 10)
	hungerBg.Position = UDim2.fromOffset(cx, 22)
	hungerBg.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	hungerBg.Parent = card

	local bgCorner = Instance.new("UICorner")
	bgCorner.CornerRadius = UDim.new(0, 4)
	bgCorner.Parent = hungerBg

	local hungerFill = Instance.new("Frame")
	hungerFill.Name = "HungerFill"
	hungerFill.Size = UDim2.fromScale(1, 1)
	hungerFill.BackgroundColor3 = Color3.fromRGB(0, 200, 0)
	hungerFill.Parent = hungerBg

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 4)
	fillCorner.Parent = hungerFill

	-- Hunger text overlay
	local hungerText = Instance.new("TextLabel")
	hungerText.Name = "HungerText"
	hungerText.Size = UDim2.fromScale(1, 1)
	hungerText.BackgroundTransparency = 1
	hungerText.Text = "100%"
	hungerText.Font = Enum.Font.GothamBold
	hungerText.TextColor3 = Color3.new(1, 1, 1)
	hungerText.TextScaled = true
	hungerText.ZIndex = 2
	hungerText.Parent = hungerBg

	-- Row 3: Distance (small, bottom right)
	local distLabel = Instance.new("TextLabel")
	distLabel.Name = "DistLabel"
	distLabel.Size = UDim2.new(1, cw, 0, 10)
	distLabel.Position = UDim2.fromOffset(cx, 35)
	distLabel.BackgroundTransparency = 1
	distLabel.Text = "0m"
	distLabel.Font = Enum.Font.Gotham
	distLabel.TextColor3 = Color3.fromRGB(130, 130, 150)
	distLabel.TextScaled = true
	distLabel.TextXAlignment = Enum.TextXAlignment.Right
	distLabel.Parent = card

	return wrapper
end

-- ═══════════════════════════════════════════════════════════
-- UPDATE LOGIC
-- ═══════════════════════════════════════════════════════════

local function updateCard(wrapper: Frame, npc: Model, distance: number)
	local card = wrapper:FindFirstChild("CardBody")
	if not card then return end
	-- Update salt preference
	local saltLabel = card:FindFirstChild("SaltLabel") :: TextLabel?
	if saltLabel then
		local wantsSalt = npc:GetAttribute("WantsSalted") == true
		saltLabel.Text = wantsSalt and "🧂 SALATA" or "🍖 NATURALE"
		saltLabel.TextColor3 = wantsSalt
			and Color3.fromRGB(255, 230, 80)
			or Color3.fromRGB(180, 255, 180)
	end

	-- Update hunger bar
	local hungerBg = card:FindFirstChild("HungerBg") :: Frame?
	if hungerBg then
		local fill = hungerBg:FindFirstChild("HungerFill") :: Frame?
		local text = hungerBg:FindFirstChild("HungerText") :: TextLabel?
		local hunger = npc:GetAttribute("Hunger") or 100
		local p = math.clamp(hunger / 100, 0, 1)

		if fill then
			TweenService:Create(fill, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {
				Size = UDim2.fromScale(p, 1),
				BackgroundColor3 = Color3.fromRGB(255, 0, 0):Lerp(Color3.fromRGB(0, 255, 0), p),
			}):Play()
		end
		if text then
			text.Text = math.floor(hunger) .. "%"
		end
	end

	-- Update distance text
	local distLabel = card:FindFirstChild("DistLabel") :: TextLabel?
	if distLabel then
		distLabel.Text = math.floor(distance) .. "m"
	end
end

local function fadeInCard(wrapper: Frame)
	local card = wrapper:FindFirstChild("CardBody") :: CanvasGroup?
	if card then
		card.GroupTransparency = 1
		TweenService:Create(card, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			GroupTransparency = 0,
		}):Play()
	end
end

local function fadeOutAndRemove(wrapper: Frame, npc: Model)
	local card = wrapper:FindFirstChild("CardBody") :: CanvasGroup?
	if card then
		TweenService:Create(card, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			GroupTransparency = 1,
		}):Play()
	end
	task.delay(0.35, function()
		if wrapper.Parent then
			wrapper:Destroy()
		end
		activeCards[npc] = nil
	end)
end

-- ═══════════════════════════════════════════════════════════
-- MAIN LOOP
-- ═══════════════════════════════════════════════════════════

function NPCTrackerService.init()
	print("[NPCTrackerService] ✅ init() called, trackerDistance =", trackerDistance)
	screenGui = createScreenGui()
	print("[NPCTrackerService] ✅ ScreenGui created, parent =", screenGui.Parent and screenGui.Parent.Name or "nil")
	local container = screenGui:FindFirstChild("CardContainer") :: ScrollingFrame
	print("[NPCTrackerService] ✅ CardContainer found =", container ~= nil)

	task.spawn(function()
		local loopCount = 0
		while true do
			loopCount += 1
			local character = player.Character
			local rootPart = character and (character:FindFirstChild("HumanoidRootPart") :: BasePart?)

			if loopCount <= 5 or loopCount % 20 == 0 then
				print(string.format("[NPCTrackerService] 🔄 Loop #%d | Character: %s | RootPart: %s | GameStarted: %s",
					loopCount,
					character and character.Name or "nil",
					rootPart and "yes" or "nil",
					tostring(game:GetAttribute("GameStarted"))
				))
			end

			if rootPart and game:GetAttribute("GameStarted") then
				local playerPos = rootPart.Position

				-- Collect all current NPCs
				local currentNPCs: {[Model]: number} = {}
				local npcCount = 0
				local qualifiedCount = 0
				for _, obj in Workspace:GetDescendants() do
					if obj:IsA("Model") and obj.Name:lower():match("npc") then
						npcCount += 1
						local hasHumanoid = obj:FindFirstChildOfClass("Humanoid") ~= nil
						local isDead = obj:GetAttribute("IsDead") == true
						local isInit = obj:GetAttribute("Initialized") == true

						if hasHumanoid and not isDead and isInit then
							local npcRoot = obj.PrimaryPart or obj:FindFirstChild("HumanoidRootPart")
							if npcRoot then
								local dist = (npcRoot.Position - playerPos).Magnitude
								qualifiedCount += 1
								if dist > trackerDistance then
									currentNPCs[obj] = dist
								end
								if loopCount <= 3 then
									print(string.format("[NPCTrackerService] 📍 NPC '%s' dist=%.1f threshold=%d show=%s",
										obj.Name, dist, trackerDistance, tostring(dist > trackerDistance)))
								end
							else
								if loopCount <= 3 then
									print("[NPCTrackerService] ⚠️ NPC '" .. obj.Name .. "' has no PrimaryPart/HumanoidRootPart")
								end
							end
						else
							if loopCount <= 3 then
								print(string.format("[NPCTrackerService] ⏭️ NPC '%s' skipped: humanoid=%s dead=%s init=%s",
									obj.Name, tostring(hasHumanoid), tostring(isDead), tostring(isInit)))
							end
						end
					end
				end

				if loopCount <= 5 or loopCount % 20 == 0 then
					local showCount = 0
					for _ in currentNPCs do showCount += 1 end
					print(string.format("[NPCTrackerService] 📊 Found %d NPC models, %d qualified, %d to show cards",
						npcCount, qualifiedCount, showCount))
				end

				-- Create cards for newly distant NPCs
				for npc, dist in currentNPCs do
					if not activeCards[npc] then
						print("[NPCTrackerService] 🆕 Creating card for '" .. npc.Name .. "' at dist=" .. math.floor(dist))
						local card = createNPCCard(npc)
						card.Parent = container
						activeCards[npc] = card
						fadeInCard(card)
					end
					updateCard(activeCards[npc], npc, dist)
				end

				-- Remove cards for NPCs that are now close (or gone)
				for npc, card in activeCards do
					if not currentNPCs[npc] then
						print("[NPCTrackerService] 🗑️ Removing card for '" .. npc.Name .. "'")
						fadeOutAndRemove(card, npc)
					end
				end
			else
				-- Game not started or no character: remove all cards
				local hadCards = false
				for npc, card in activeCards do
					hadCards = true
					if card.Parent then
						card:Destroy()
					end
					activeCards[npc] = nil
				end
				if hadCards then
					print("[NPCTrackerService] 🧹 Cleared all cards (game not started or no character)")
				end
			end

			task.wait(0.5)
		end
	end)

	-- 60fps arrow rotation via RenderStepped
	RunService.RenderStepped:Connect(function()
		local camera = Workspace.CurrentCamera
		if not camera then return end
		local camCF = camera.CFrame

		for npc, wrapper in activeCards do
			local arrow = wrapper:FindFirstChild("DirectionArrow") :: Frame?
			if not arrow then continue end

			local npcRoot = npc.PrimaryPart or npc:FindFirstChild("HumanoidRootPart")
			if not npcRoot then continue end

			local toNPC = npcRoot.Position - camCF.Position
			local flatDir = Vector3.new(toNPC.X, 0, toNPC.Z)
			if flatDir.Magnitude < 0.1 then continue end

			local camFwd = Vector3.new(camCF.LookVector.X, 0, camCF.LookVector.Z)
			if camFwd.Magnitude < 0.1 then continue end

			camFwd = camFwd.Unit
			flatDir = flatDir.Unit
			local dot = camFwd:Dot(flatDir)
			local cross = camFwd:Cross(flatDir).Y
			arrow.Rotation = math.deg(math.atan2(cross, dot))
		end
	end)

	print("[NPCTrackerService] ✅ Initialized — tracking NPCs beyond " .. trackerDistance .. " studs.")
end

return NPCTrackerService
