--!strict
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PathfindingService = game:GetService("PathfindingService")

local Settings = require(ReplicatedStorage.Shared.Settings)
local BraceService = require(script.Parent.BraceService)
local NPCService = require(script.Parent.NPCService)

local DogService = {}

local originalHomeCFrame: CFrame? = nil

function DogService.init()
	task.spawn(function()
		task.wait(2)
		local dog = Workspace:FindFirstChild("dogMalus", true)
		if dog then
			originalHomeCFrame = dog:GetPivot()
			print("[DogService] Cached original home position.")
		end
	end)

	task.spawn(function()
		while true do
			local interval = math.random(45, 75)
			task.wait(interval)
			if game:GetAttribute("GameStarted") then
				DogService.spawnDog(true)
			end
		end
	end)
end

local isMoving = false
local dogChased = false
local clickCount = 0
local CLICKS_TO_CHASE = Settings.DOG_CLICKS_MIN or 20

game:GetAttributeChangedSignal("GameStarted"):Connect(function()
	if not game:GetAttribute("GameStarted") then
		dogChased = true
		isMoving = false
		print("[DogService] GameStarted=false → isMoving reset.")
	end
end)

local DogClickEvent = ReplicatedStorage:FindFirstChild("DogClickEvent")
if not DogClickEvent then
	DogClickEvent = Instance.new("RemoteEvent")
	DogClickEvent.Name = "DogClickEvent"
	DogClickEvent.Parent = ReplicatedStorage
end

-- ── UI helpers ────────────────────────────────────────────────────────────────

local function createDogUI(rootPart: BasePart): BillboardGui
	local existing = rootPart:FindFirstChild("DogChaseUI")
	if existing then existing:Destroy() end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "DogChaseUI"
	billboard.Size = UDim2.fromOffset(180, 55)
	billboard.MaxDistance = 50
	billboard.StudsOffset = Vector3.new(0, 3, 0)
	billboard.AlwaysOnTop = false
	billboard.ResetOnSpawn = false
	billboard.Parent = rootPart

	local label = Instance.new("TextLabel")
	label.Name = "CountLabel"
	label.Size = UDim2.fromScale(1, 0.5)
	label.Position = UDim2.fromScale(0, 0)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.new(1, 1, 0)
	label.TextSize = 13
	label.Text = "Clicca per scacciarmi!"
	label.Parent = billboard
	Instance.new("UIStroke", label).Thickness = 1

	local bar = Instance.new("TextLabel")
	bar.Name = "BarLabel"
	bar.Size = UDim2.fromScale(1, 0.5)
	bar.Position = UDim2.fromScale(0, 0.5)
	bar.BackgroundTransparency = 1
	bar.Font = Enum.Font.GothamBold
	bar.TextColor3 = Color3.new(1, 0.4, 0.1)
	bar.TextSize = 16
	bar.Text = "0 / " .. CLICKS_TO_CHASE
	bar.Parent = billboard
	Instance.new("UIStroke", bar).Thickness = 1

	return billboard
end

local function updateDogUI(rootPart: BasePart, count: number)
	local billboard = rootPart:FindFirstChild("DogChaseUI")
	if not billboard then return end
	local bar = billboard:FindFirstChild("BarLabel")
	if bar then
		bar.Text = count .. " / " .. CLICKS_TO_CHASE
		if count >= CLICKS_TO_CHASE * 0.7 then
			bar.TextColor3 = Color3.new(1, 0, 0)
		end
	end
end

local function cleanDogUI(rootPart: BasePart?)
	if not rootPart then return end
	local billboard = rootPart:FindFirstChild("DogChaseUI")
	if billboard then billboard:Destroy() end
end

local function showDogSpeech(rootPart: BasePart, text: string, duration: number?)
	local existing = rootPart:FindFirstChild("DogSpeech")
	if existing then existing:Destroy() end

	local bubble = Instance.new("BillboardGui")
	bubble.Name = "DogSpeech"
	bubble.Size = UDim2.fromOffset(200, 70)
	bubble.MaxDistance = 50
	bubble.StudsOffset = Vector3.new(0, 6, 0)
	bubble.AlwaysOnTop = false
	bubble.ResetOnSpawn = false
	bubble.Parent = rootPart

	local bg = Instance.new("Frame")
	bg.Name = "BubbleBG"
	bg.Size = UDim2.new(1, 0, 0.78, 0)
	bg.Position = UDim2.fromScale(0, 0)
	bg.BackgroundColor3 = Color3.fromRGB(255, 255, 240)
	bg.BorderSizePixel = 0
	bg.Parent = bubble
	local bgCorner = Instance.new("UICorner")
	bgCorner.CornerRadius = UDim.new(0, 10)
	bgCorner.Parent = bg
	local bgStroke = Instance.new("UIStroke")
	bgStroke.Color = Color3.fromRGB(80, 50, 20)
	bgStroke.Thickness = 2
	bgStroke.Parent = bg

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.fromScale(1, 1)
	lbl.BackgroundTransparency = 1
	lbl.Font = Enum.Font.GothamBold
	lbl.TextColor3 = Color3.fromRGB(50, 25, 0)
	lbl.TextSize = 16
	lbl.Text = text
	lbl.TextWrapped = true
	lbl.Parent = bg

	local tail = Instance.new("Frame")
	tail.Name = "Tail"
	tail.Size = UDim2.fromOffset(18, 18)
	tail.Position = UDim2.new(0.5, -9, 0.78, -2)
	tail.BackgroundColor3 = Color3.fromRGB(255, 255, 240)
	tail.BorderSizePixel = 0
	tail.Rotation = 45
	tail.ZIndex = 0
	tail.Parent = bubble

	task.delay(duration or 4, function()
		if bubble and bubble.Parent then bubble:Destroy() end
	end)
end

-- ── Movement core ─────────────────────────────────────────────────────────────

-- Raycast params that exclude the dog model from self-collision.
local function makeRayParams(model: Model): RaycastParams
	local rp = RaycastParams.new()
	rp.FilterDescendantsInstances = { model }
	rp.FilterType = Enum.RaycastFilterType.Exclude
	return rp
end

-- For each waypoint XZ, raycast downward to find the actual ground Y.
-- This handles stairs: each step has the correct surface Y.
-- Returns the corrected Y (surface + half the dog's visual height).
local DOG_HALF_HEIGHT = 1.5 -- studs from ground to pivot center
local function groundY(xz: Vector3, rp: RaycastParams): number
	-- Cast from well above (10 studs) so we catch stair tops too.
	local hit = Workspace:Raycast(
		Vector3.new(xz.X, xz.Y + 10, xz.Z),
		Vector3.new(0, -20, 0),
		rp
	)
	if hit then
		return hit.Position.Y + DOG_HALF_HEIGHT
	end
	-- Fallback: trust the navmesh Y with the half-height offset.
	return xz.Y + DOG_HALF_HEIGHT
end

-- Walk the model through an ordered list of XYZ positions.
-- For each segment we raycast ONCE at the target waypoint to get the real ground Y,
-- then lerp smoothly from current position to that corrected target.
-- This keeps the dog on the ground at every step/stair without per-frame raycasts.
local function followPositions(
	model: Model,
	positions: { Vector3 },
	speed: number,
	shouldStop: () -> boolean
)
	local root = model.PrimaryPart
	if not root or #positions < 2 then return end

	local rp = makeRayParams(model)

	for i = 2, #positions do
		if shouldStop() then return end

		local wp = positions[i]

		local fromX = root.Position.X
		local fromY = root.Position.Y
		local fromZ = root.Position.Z
		local toX = wp.X
		-- Raycast once per waypoint to get the real surface Y at this XZ.
		local toY = groundY(wp, rp)
		local toZ = wp.Z

		local dist = math.sqrt((toX - fromX) ^ 2 + (toZ - fromZ) ^ 2)
		if dist < 0.05 then
			continue
		end

		-- Face the next waypoint.
		local dir = Vector3.new(toX - fromX, 0, toZ - fromZ).Unit
		local targetRot = CFrame.lookAt(Vector3.zero, dir).Rotation
		local startRot = model:GetPivot().Rotation
		local rotDur = math.min(0.10, dist / speed * 0.15)
		local t0 = os.clock()
		while (os.clock() - t0) < rotDur do
			if shouldStop() then return end
			local a = (os.clock() - t0) / rotDur
			model:PivotTo(CFrame.new(root.Position) * startRot:Lerp(targetRot, a))
			task.wait()
		end

		-- Lerp from current position to corrected target.
		local duration = dist / speed
		local tStart = os.clock()
		while true do
			if shouldStop() then return end
			local alpha = math.min(1, (os.clock() - tStart) / duration)
			local px = fromX + (toX - fromX) * alpha
			local py = fromY + (toY - fromY) * alpha
			local pz = fromZ + (toZ - fromZ) * alpha
			model:PivotTo(CFrame.new(Vector3.new(px, py, pz)) * targetRot)
			if alpha >= 1 then
				break
			end
			task.wait()
		end
	end
end

-- Compute a path from `from` to `to`.
-- Tries two agent configs before giving up.
-- Returns an array of waypoint positions on success, nil otherwise.
local function computePath(from: Vector3, to: Vector3): { Vector3 }?
	local function try(params: { [string]: any }): { Vector3 }?
		local path = PathfindingService:CreatePath(params)
		local ok = pcall(function()
			path:ComputeAsync(from, to)
		end)
		if not ok or path.Status ~= Enum.PathStatus.Success then
			return nil
		end
		local positions: { Vector3 } = {}
		for _, wp in path:GetWaypoints() do
			table.insert(positions, wp.Position)
		end
		return positions
	end

	-- Small agent fits through stairs; AgentCanClimb lets it use ladder/stair geometry.
	return try({ AgentRadius = 1.5, AgentHeight = 2, AgentCanJump = false, AgentCanClimb = true, WaypointSpacing = 2 })
		or try({ AgentRadius = 1, AgentHeight = 2, AgentCanJump = true, WaypointSpacing = 2 })
end

-- High-level: walk the model to `target`.
-- Uses PathfindingService where possible; falls back to a straight-line walk.
local function walkTo(model: Model, target: Vector3, speed: number, shouldStop: () -> boolean)
	local root = model.PrimaryPart
	if not root then return end

	local positions = computePath(root.Position, target)
	if positions then
		followPositions(model, positions, speed, shouldStop)
	else
		followPositions(model, { root.Position, target }, speed, shouldStop)
	end
end

-- ── Rig ───────────────────────────────────────────────────────────────────────

local function rigDog(model: Model)
	local root = model.PrimaryPart
		or model:FindFirstChild("HumanoidRootPart")
		or model:FindFirstChildWhichIsA("BasePart", true)
	if not root then return end
	if not model.PrimaryPart then
		model.PrimaryPart = root
	end

	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = true
			p.Massless = true
			p.CanCollide = false
		elseif p:IsA("Humanoid") then
			p:Destroy()
		end
	end

	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") and p ~= root then
			local hasJoint = false
			for _, joint in p:GetJoints() do
				if joint.Part0 and joint.Part1 then
					hasJoint = true
					break
				end
			end
			if not hasJoint then
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = root
				weld.Part1 = p
				weld.Parent = p
			end
		end
	end
end

-- ── spawnDog ──────────────────────────────────────────────────────────────────

function DogService.spawnDog(isAuto: boolean?)
	if isMoving then return end
	if isAuto and math.random() < 0.3 then return end

	local dog = Workspace:FindFirstChild("dogMalus", true)
	if not dog then return end

	local homeCFrame = originalHomeCFrame or dog:GetPivot()

	isMoving = true
	dogChased = false
	clickCount = 0

	-- Dynamic click threshold: harder when less time remains.
	do
		local remaining = Workspace:GetAttribute("GameRemainingTime") or 300
		local winTime = Settings.WIN_TIME or 300
		local t = math.clamp(remaining / winTime, 0, 1)
		local minClicks = Settings.DOG_CLICKS_MIN or 20
		local maxClicks = Settings.DOG_CLICKS_MAX or 40
		CLICKS_TO_CHASE = math.floor(minClicks + (1 - t) * (maxClicks - minClicks))
	end

	local clickConn = DogClickEvent.OnServerEvent:Connect(function()
		if not isMoving or dogChased then return end
		clickCount += 1
		local rootPart = dog.PrimaryPart
		if rootPart then updateDogUI(rootPart, clickCount) end
		if clickCount >= CLICKS_TO_CHASE then
			dogChased = true
		end
	end)

	-- Closure used as the shouldStop predicate throughout this trip.
	local function chased(): boolean
		return dogChased
	end

	local successSequence, err = pcall(function()
		rigDog(dog)

		-- ── Find a brace that has meat ───────────────────────────────────────
		local allBraces: { Model } = {}
		local hasMeat = false
		for _, obj in Workspace:GetDescendants() do
			if obj:IsA("Model") and obj.Name:lower():match("brace") then
				table.insert(allBraces, obj)
				for i = 1, 4 do
					if obj:GetAttribute("Slot" .. i .. "_Status") ~= Settings.STATUS.EMPTY then
						hasMeat = true
						break
					end
				end
			end
		end

		print("[DogService] spawnDog: hasMeat=" .. tostring(hasMeat) .. " braces=" .. #allBraces .. " isAuto=" .. tostring(isAuto))

		if not hasMeat then
			if isAuto then
				print("[DogService] Auto spawn aborted: no meat in any brace.")
				isMoving = false
				return
			end
			print("[DogService] Manual call: walking to brace even with no meat.")
		end

		local rootPart = dog.PrimaryPart
		createDogUI(rootPart)

		local walkSound = Instance.new("Sound")
		walkSound.Name = "DogWalkLoop"
		walkSound.SoundId = Settings.DOG_WALK_SOUND_ID
		walkSound.Looped = true
		walkSound.Volume = 0.5
		walkSound.Parent = rootPart
		walkSound:Play()

		-- Pick the closest brace that has meat.
		local targetBrace: Model? = nil
		local minDist = math.huge
		for _, brace in allBraces do
			local braceHasMeat = false
			for i = 1, 4 do
				if brace:GetAttribute("Slot" .. i .. "_Status") ~= Settings.STATUS.EMPTY then
					braceHasMeat = true
					break
				end
			end
			if braceHasMeat then
				local d = (rootPart.Position - brace:GetPivot().Position).Magnitude
				if d < minDist then
					minDist = d
					targetBrace = brace
				end
			end
		end

		if not targetBrace then
			walkSound:Destroy()
			return
		end

		local bracePos = targetBrace:GetPivot().Position

		-- ── Find a valid walkable approach point in front of the brace ───────
		-- Try several offsets in priority order: from the dog's approach direction
		-- first, then cardinal fallbacks.  Pick the first that lands on solid ground.
		local dogTarget: Vector3
		do
			local rp = RaycastParams.new()
			rp.FilterDescendantsInstances = { dog }
			rp.FilterType = Enum.RaycastFilterType.Exclude

			local toBrace = Vector3.new(bracePos.X - rootPart.Position.X, 0, bracePos.Z - rootPart.Position.Z)
			local approachDir = toBrace.Magnitude > 0.1 and toBrace.Unit or Vector3.new(1, 0, 0)

			-- Offset candidates: approach side first, then cardinal directions.
			local offsets: { Vector3 } = {
				-approachDir * 4,           -- in front (from dog's perspective)
				approachDir * 4,            -- behind the brace
				Vector3.new(4, 0, 0),
				Vector3.new(-4, 0, 0),
				Vector3.new(0, 0, 4),
				Vector3.new(0, 0, -4),
			}

			-- Default fallback: approach side, at the brace's Y (corrected below if we find ground).
			dogTarget = Vector3.new(
				bracePos.X + offsets[1].X,
				bracePos.Y,
				bracePos.Z + offsets[1].Z
			)

			for _, offset in offsets do
				local candidateXZ = Vector3.new(bracePos.X + offset.X, bracePos.Y + 8, bracePos.Z + offset.Z)
				local hit = Workspace:Raycast(candidateXZ, Vector3.new(0, -20, 0), rp)
				if hit then
					dogTarget = hit.Position
					break
				end
			end
		end

		-- ── Walk to the brace ────────────────────────────────────────────────
		walkTo(dog, dogTarget, 20, chased)

		local distToBrace = (Vector3.new(rootPart.Position.X, 0, rootPart.Position.Z)
			- Vector3.new(bracePos.X, 0, bracePos.Z)).Magnitude

		local didSteal = false

		if distToBrace < 8 and not dogChased then
			-- ── Steal sequence ───────────────────────────────────────────────
			walkSound:Stop()
			task.wait(1.5)

			local remaining = Workspace:GetAttribute("GameRemainingTime") or 0
			local m = math.floor(remaining / 60)
			local s = math.floor(remaining % 60)
			local sum = m + math.floor(s / 10) + s % 10
			local countToSteal = (sum % 2 == 0) and 1 or 2
			print("[DogService] Time: " .. m .. ":" .. string.format("%02d", s) .. " | Sum: " .. sum .. " -> steals " .. countToSteal)

			for _ = 1, countToSteal do
				local meatModel = BraceService.stealMeat(targetBrace)
				if meatModel then
					NPCService.playSound(rootPart, Settings.DOG_SOUND_ID, 1.0)

					local carriedMeat = meatModel:Clone()
					carriedMeat.Name = "CarriedMeat"
					carriedMeat.Parent = dog

					local headPart = dog:FindFirstChild("Head")
						or dog:FindFirstChild("DogHead")
						or dog:FindFirstChild("UpperTorso")
						or rootPart

					local snoutCFrame = headPart.CFrame * CFrame.new(0, -0.4, -1.2)
					carriedMeat:PivotTo(snoutCFrame)

					for _, p in carriedMeat:GetDescendants() do
						if p:IsA("BasePart") then
							p.Transparency = 0
							p.Anchored = false
							p.CanCollide = false
							local weld = Instance.new("WeldConstraint")
							weld.Part0 = rootPart
							weld.Part1 = p
							weld.Parent = p
						end
					end
					task.wait(0.3)
				end
			end

			task.wait(0.5)
			didSteal = true
			cleanDogUI(rootPart)
			showDogSpeech(rootPart, "rustell :]")
			walkSound:Play()

			-- Walk home unconditionally (dog won, ignore clicks from here on).
			walkTo(dog, homeCFrame.Position, 18, function() return false end)

			for _, child in dog:GetChildren() do
				if child.Name == "CarriedMeat" then child:Destroy() end
			end
		end

		if dogChased and not didSteal then
			-- ── Chased-home sequence ─────────────────────────────────────────
			walkSound:Stop()
			walkSound:Destroy()
			task.wait(0.3)

			cleanDogUI(rootPart)
			showDogSpeech(rootPart, "che palle :[", 5)

			local barkSound = Instance.new("Sound")
			barkSound.SoundId = Settings.DOG_SOUND_ID
			barkSound.Volume = 0.5
			barkSound.Looped = false
			barkSound.PlaybackSpeed = 0.75
			barkSound.Parent = rootPart
			barkSound:Play()
			barkSound.Ended:Connect(function() barkSound:Destroy() end)

			local sadWalk = Instance.new("Sound")
			sadWalk.Name = "SadWalkLoop"
			sadWalk.SoundId = Settings.DOG_WALK_SOUND_ID
			sadWalk.Looped = true
			sadWalk.Volume = 0.3
			sadWalk.PlaybackSpeed = 0.6
			sadWalk.Parent = rootPart
			sadWalk:Play()

			-- Walk home unconditionally.
			walkTo(dog, homeCFrame.Position, 12, function() return false end)

			sadWalk:Destroy()
		end

		walkSound:Destroy()
		dog:PivotTo(homeCFrame)
	end)

	clickConn:Disconnect()
	cleanDogUI(dog.PrimaryPart)

	if not successSequence then
		warn("[DogService] Error: " .. tostring(err))
	end
	isMoving = false
end

return DogService
