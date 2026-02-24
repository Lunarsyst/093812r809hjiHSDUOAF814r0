local repo = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/"
local Library = loadstring(game:HttpGet(repo .. "Library.lua"))()
local ThemeManager = loadstring(game:HttpGet(repo .. "addons/ThemeManager.lua"))()
local SaveManager = loadstring(game:HttpGet(repo .. "addons/SaveManager.lua"))()

local Options = Library.Options
local Toggles = Library.Toggles

local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local UIS = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

Library.ForceCheckbox = false
Library.ShowToggleFrameInKeybinds = true

local Window = Library:CreateWindow({
	Title = "Aegisaken",
	Footer = "[ discord.gg/axu9dZypbb ]",
	NotifySide = "Right",
	ShowCustomCursor = true,
})

local Tabs = {
	Main = Window:AddTab("Main", "user"),
	Exploits = Window:AddTab("Exploits", "zap"),
	Visuals = Window:AddTab("Visuals", "eye"),
	Anti = Window:AddTab("Removals", "shield"),
	["UI Settings"] = Window:AddTab("UI Settings", "settings"),
}

-- ══════════════════════════════════════
-- SHARED UTILITIES
-- ══════════════════════════════════════
local function setupCharacter(character)
	if not character then return end
	local Humanoid = character:FindFirstChild("Humanoid")
	local HumanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	if Humanoid and HumanoidRootPart then
		_G.Humanoid = Humanoid
		_G.HumanoidRootPart = HumanoidRootPart
	end
end

if LocalPlayer.Character then setupCharacter(LocalPlayer.Character) end
LocalPlayer.CharacterAdded:Connect(setupCharacter)

local function getCharacter()
	return LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
end

local function getHumanoid(character)
	return character and character:FindFirstChildOfClass("Humanoid")
end

local function getRootPart(character)
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function click(btnName)
	local ui = PlayerGui:FindFirstChild("MainUI")
	local btn = ui and ui:FindFirstChild("AbilityContainer") and ui.AbilityContainer:FindFirstChild(btnName)
	if not btn then return end
	for _, c in ipairs(getconnections(btn.MouseButton1Click)) do pcall(function() c:Fire() end) end
	pcall(function() btn:Activate() end)
end

local function pressKey(keyCode)
	VirtualInputManager:SendKeyEvent(true, keyCode, false, game)
end

local function releaseKey(keyCode)
	VirtualInputManager:SendKeyEvent(false, keyCode, false, game)
end

local function holdKey(keyCode, duration)
	pressKey(keyCode)
	task.wait(duration)
	releaseKey(keyCode)
end

local function tapKey(keyCode)
	pressKey(keyCode)
	task.wait(0.05)
	releaseKey(keyCode)
end

local KillersFolder = workspace:WaitForChild("Players"):WaitForChild("Killers")

-- ══════════════════════════════════════
-- KILLER DETECTION
-- ══════════════════════════════════════
local function isOnKillerTeam()
	local char = LocalPlayer.Character
	if not char then return false end
	local killersFolder = workspace:FindFirstChild("Players") and workspace.Players:FindFirstChild("Killers")
	if killersFolder then
		for _, k in ipairs(killersFolder:GetChildren()) do
			if k.Name == LocalPlayer.Name then
				return true
			end
		end
	end
	local role = LocalPlayer:GetAttribute("Role")
	if role and tostring(role):lower() == "killer" then return true end
	local playingAs = LocalPlayer:GetAttribute("PlayingAs")
	if playingAs and tostring(playingAs):lower():find("killer") then return true end
	return false
end

-- ══════════════════════════════════════
-- DEBUG HUD
-- ══════════════════════════════════════
local debugEnabled = false
local autofarmStartTime = 0
local currentDebugStatus = "Idle"
local currentTargetName = ""
local currentProgressDisplay = ""

local debugGui = Instance.new("ScreenGui")
debugGui.Name = "AegisDebugHUD"
debugGui.ResetOnSpawn = false
debugGui.DisplayOrder = 999999
debugGui.Parent = game:GetService("CoreGui")

local debugFrame = Instance.new("Frame")
debugFrame.Name = "DebugFrame"
debugFrame.BackgroundTransparency = 1
debugFrame.Position = UDim2.new(0, 10, 0.35, 0)
debugFrame.Size = UDim2.new(0, 400, 0, 110)
debugFrame.Parent = debugGui

local debugStatusLabel = Instance.new("TextLabel")
debugStatusLabel.Name = "StatusLabel"
debugStatusLabel.BackgroundTransparency = 1
debugStatusLabel.Position = UDim2.new(0, 0, 0, 0)
debugStatusLabel.Size = UDim2.new(1, 0, 0, 25)
debugStatusLabel.Font = Enum.Font.Gotham
debugStatusLabel.TextColor3 = Color3.new(1, 1, 1)
debugStatusLabel.TextSize = 16
debugStatusLabel.TextXAlignment = Enum.TextXAlignment.Left
debugStatusLabel.TextStrokeTransparency = 0.5
debugStatusLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
debugStatusLabel.Text = ""
debugStatusLabel.Parent = debugFrame

local debugTargetLabel = Instance.new("TextLabel")
debugTargetLabel.Name = "TargetLabel"
debugTargetLabel.BackgroundTransparency = 1
debugTargetLabel.Position = UDim2.new(0, 0, 0, 25)
debugTargetLabel.Size = UDim2.new(1, 0, 0, 25)
debugTargetLabel.Font = Enum.Font.Gotham
debugTargetLabel.TextColor3 = Color3.new(1, 1, 1)
debugTargetLabel.TextSize = 14
debugTargetLabel.TextXAlignment = Enum.TextXAlignment.Left
debugTargetLabel.TextStrokeTransparency = 0.5
debugTargetLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
debugTargetLabel.Text = ""
debugTargetLabel.Parent = debugFrame

local debugProgressLabel = Instance.new("TextLabel")
debugProgressLabel.Name = "ProgressLabel"
debugProgressLabel.BackgroundTransparency = 1
debugProgressLabel.Position = UDim2.new(0, 0, 0, 50)
debugProgressLabel.Size = UDim2.new(1, 0, 0, 25)
debugProgressLabel.Font = Enum.Font.Gotham
debugProgressLabel.TextColor3 = Color3.fromRGB(180, 255, 180)
debugProgressLabel.TextSize = 14
debugProgressLabel.TextXAlignment = Enum.TextXAlignment.Left
debugProgressLabel.TextStrokeTransparency = 0.5
debugProgressLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
debugProgressLabel.Text = ""
debugProgressLabel.Parent = debugFrame

local debugTimeLabel = Instance.new("TextLabel")
debugTimeLabel.Name = "TimeLabel"
debugTimeLabel.BackgroundTransparency = 1
debugTimeLabel.Position = UDim2.new(0, 0, 0, 75)
debugTimeLabel.Size = UDim2.new(1, 0, 0, 25)
debugTimeLabel.Font = Enum.Font.Gotham
debugTimeLabel.TextColor3 = Color3.new(0.8, 0.8, 0.8)
debugTimeLabel.TextSize = 13
debugTimeLabel.TextXAlignment = Enum.TextXAlignment.Left
debugTimeLabel.TextStrokeTransparency = 0.5
debugTimeLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
debugTimeLabel.Text = ""
debugTimeLabel.Parent = debugFrame

debugGui.Enabled = false

local function setDebugStatus(status, targetName)
	currentDebugStatus = status
	currentTargetName = targetName or ""
end

local function setDebugProgress(text)
	currentProgressDisplay = text or ""
end

local function formatTime(seconds)
	local mins = math.floor(seconds / 60)
	local secs = math.floor(seconds % 60)
	return string.format("%02d:%02d", mins, secs)
end

task.spawn(function()
	while true do
		task.wait(0.2)
		if Library.Unloaded then break end
		debugGui.Enabled = debugEnabled and (Toggles.Autofarm and Toggles.Autofarm.Value)
		if debugGui.Enabled then
			debugStatusLabel.Text = "[Aegis] " .. currentDebugStatus
			debugTargetLabel.Text = currentTargetName ~= "" and ("Target: " .. currentTargetName) or ""
			debugProgressLabel.Text = currentProgressDisplay
			debugTimeLabel.Text = autofarmStartTime > 0 and ("Elapsed: " .. formatTime(tick() - autofarmStartTime)) or ""
		end
	end
end)

-- ══════════════════════════════════════
-- TARGET HIGHLIGHT
-- ══════════════════════════════════════
local highlightTargetEnabled = false
local currentTargetHighlight = nil

local function setTargetHighlight(target)
	if currentTargetHighlight and currentTargetHighlight.Parent then
		currentTargetHighlight:Destroy()
	end
	currentTargetHighlight = nil
	if not highlightTargetEnabled or not target then return end
	local h = Instance.new("Highlight")
	h.Name = "AegisTargetHL"
	h.FillColor = Color3.new(1, 1, 1)
	h.FillTransparency = 0.5
	h.OutlineColor = Color3.new(1, 1, 1)
	h.OutlineTransparency = 0
	h.Adornee = target
	h.Parent = target
	currentTargetHighlight = h
end

local function clearTargetHighlight()
	if currentTargetHighlight and currentTargetHighlight.Parent then
		currentTargetHighlight:Destroy()
	end
	currentTargetHighlight = nil
end

-- ══════════════════════════════════════
-- PATH VISUALIZER
-- ══════════════════════════════════════
local pathVisualizerParts = {}

local function clearPathVisualizer()
	for _, part in ipairs(pathVisualizerParts) do
		if part and part.Parent then part:Destroy() end
	end
	pathVisualizerParts = {}
end

local function visualizePath(waypoints)
	clearPathVisualizer()
	if not waypoints then return end
	for _, waypoint in ipairs(waypoints) do
		local dot = Instance.new("Part")
		dot.Name = "AegisPathDot"
		dot.Shape = Enum.PartType.Ball
		dot.Size = Vector3.new(0.6, 0.6, 0.6)
		dot.Position = waypoint.Position + Vector3.new(0, 0.3, 0)
		dot.Anchored = true
		dot.CanCollide = false
		dot.Material = Enum.Material.Neon
		dot.Color = Color3.new(1, 1, 1)
		dot.Transparency = 0.3
		dot.Parent = workspace
		table.insert(pathVisualizerParts, dot)
	end
end

-- ══════════════════════════════════════
-- SPRINT MANAGER
-- ══════════════════════════════════════
local sprintRunning = false
local sprintInfStamina = false
local sprintHoldTime = 8
local sprintRestTime = 10
local sprintRestTimeInf = 0.5
local sprintCoroutine = nil

local function startSprintLoop()
	if sprintCoroutine then return end
	sprintCoroutine = task.spawn(function()
		while sprintRunning do
			if Library.Unloaded then break end
			if not (Toggles.Autofarm and Toggles.Autofarm.Value) then
				releaseKey(Enum.KeyCode.LeftShift)
				task.wait(0.2)
				continue
			end
			pressKey(Enum.KeyCode.LeftShift)
			local elapsed = 0
			while elapsed < sprintHoldTime and sprintRunning and Toggles.Autofarm.Value do
				if Library.Unloaded then break end
				task.wait(0.1)
				elapsed = elapsed + 0.1
			end
			releaseKey(Enum.KeyCode.LeftShift)
			local restDuration = sprintInfStamina and sprintRestTimeInf or sprintRestTime
			elapsed = 0
			while elapsed < restDuration and sprintRunning do
				if Library.Unloaded then break end
				task.wait(0.1)
				elapsed = elapsed + 0.1
			end
		end
		releaseKey(Enum.KeyCode.LeftShift)
		sprintCoroutine = nil
	end)
end

local function stopSprintLoop()
	sprintRunning = false
	releaseKey(Enum.KeyCode.LeftShift)
	sprintCoroutine = nil
end

-- ══════════════════════════════════════
-- AUTO USE ABILITY
-- ══════════════════════════════════════
local autoUseAbility = false
local autoAbilityCoroutine = nil

local function startAutoAbility()
	if autoAbilityCoroutine then return end
	autoAbilityCoroutine = task.spawn(function()
		while autoUseAbility do
			if Library.Unloaded then break end
			if Toggles.Autofarm and Toggles.Autofarm.Value then
				tapKey(Enum.KeyCode.Q)
				task.wait(0.1)
				tapKey(Enum.KeyCode.E)
				task.wait(0.1)
				tapKey(Enum.KeyCode.R)
				task.wait(1)
			else
				task.wait(0.5)
			end
		end
		autoAbilityCoroutine = nil
	end)
end

local function stopAutoAbility()
	autoUseAbility = false
	autoAbilityCoroutine = nil
end

-- ══════════════════════════════════════
-- SERVER HOP
-- ══════════════════════════════════════
local function serverHop()
	pcall(function()
		local placeId = game.PlaceId
		local found = false
		for i = 1, 5 do
			local url = "https://games.roblox.com/v1/games/" .. placeId .. "/servers/Public?sortOrder=Asc&limit=100"
			local success, result = pcall(function()
				return HttpService:JSONDecode(game:HttpGet(url))
			end)
			if not success or not result then break end
			for _, server in ipairs(result.data or {}) do
				if server.id ~= game.JobId and server.playing < server.maxPlayers then
					TeleportService:TeleportToPlaceInstance(placeId, server.id)
					found = true
					break
				end
			end
			if found then break end
			local cursor = result.nextPageCursor or ""
			if cursor == "" then break end
		end
		if not found then
			TeleportService:Teleport(placeId)
		end
	end)
end

-- ══════════════════════════════════════
-- GENERATOR / GINGERBREAD DETECTION
-- ══════════════════════════════════════
local collectedGingerbreads = {} -- blacklist for gingerbreads we already walked through

local function getCurrencyLocations()
	local results = {}
	pcall(function()
		local folder = workspace.Map.Ingame.CurrencyLocations
		for _, child in ipairs(folder:GetChildren()) do
			if not collectedGingerbreads[child] then
				table.insert(results, child)
			end
		end
	end)
	return results
end

local function getGeneratorProgress(gen)
	local progressChild = gen:FindFirstChild("Progress")
	if progressChild and progressChild:IsA("ValueBase") then
		return progressChild.Value
	end
	local attrProgress = nil
	pcall(function()
		attrProgress = gen:GetAttribute("Progress")
	end)
	if type(attrProgress) == "number" then
		return attrProgress
	end
	return 0
end

local function isGeneratorDone(gen)
	return getGeneratorProgress(gen) >= 100
end

-- Track generator enter/leave state via remotes
local generatorEntered = {} -- [generator] = true/false

local function hookGeneratorRemotes(genModel)
	pcall(function()
		local remotesFolder = genModel:FindFirstChild("Remotes")
		if not remotesFolder then return end
		local rf = remotesFolder:FindFirstChild("RF")
		if not rf then return end

		-- We can't easily hook RemoteFunction calls from client side,
		-- but we can monitor if Enter/Leave children exist
		-- Instead, we'll track proximity + F holding as our enter/leave detection
	end)
end

local function getAllGeneratorModels()
	local gens = {}
	pcall(function()
		local mapFolder = workspace:FindFirstChild("Map")
		if not mapFolder then return end
		local ingame = mapFolder:FindFirstChild("Ingame")
		if not ingame then return end
		local mapInner = ingame:FindFirstChild("Map")
		if not mapInner then return end
		for _, obj in ipairs(mapInner:GetDescendants()) do
			if obj.Name == "Generator" and (obj:IsA("Model") or obj:IsA("BasePart")) then
				table.insert(gens, obj)
			end
		end
	end)
	return gens
end

local function getGenerators()
	local gens = {}
	for _, gen in ipairs(getAllGeneratorModels()) do
		local progress = getGeneratorProgress(gen)
		if progress < 100 then
			table.insert(gens, gen)
		end
	end
	return gens
end

local function getTargetPosition(target)
	if target:IsA("BasePart") then
		return target.Position
	elseif target:IsA("Model") then
		local primary = target.PrimaryPart or target:FindFirstChildWhichIsA("BasePart")
		if primary then return primary.Position end
	end
	return nil
end

local function getClosestFromList(rootPart, list, maxDist)
	local closest = nil
	local closestDist = math.huge
	maxDist = maxDist or 2000
	for _, loc in ipairs(list) do
		local targetPos = getTargetPosition(loc)
		if targetPos then
			local dist = (rootPart.Position - targetPos).Magnitude
			if dist < closestDist and dist <= maxDist then
				closestDist = dist
				closest = loc
			end
		end
	end
	return closest, closestDist
end

local function getDistanceToTarget(target)
	local character = getCharacter()
	local rootPart = getRootPart(character)
	if not rootPart then return math.huge end
	local targetPos = getTargetPosition(target)
	if not targetPos then return math.huge end
	return (rootPart.Position - targetPos).Magnitude
end

local function isTargetGingerbread(target)
	local success, result = pcall(function()
		local currFolder = workspace.Map.Ingame.CurrencyLocations
		return target:IsDescendantOf(currFolder) or target.Parent == currFolder
	end)
	return success and result
end

local function getTargetTypeName(target)
	if isTargetGingerbread(target) then
		return "Gingerbread (" .. target.Name .. ")"
	else
		return "Generator"
	end
end

-- ══════════════════════════════════════
-- F HOLD MANAGEMENT
-- ══════════════════════════════════════
local holdingF = false

local function startHoldingF()
	if holdingF then return end
	holdingF = true
	pressKey(Enum.KeyCode.F)
end

local function stopHoldingF()
	if not holdingF then return end
	holdingF = false
	releaseKey(Enum.KeyCode.F)
end

-- ══════════════════════════════════════
-- TELEPORT MODE
-- ══════════════════════════════════════
local function teleportToTarget(target)
	local character = getCharacter()
	local rootPart = getRootPart(character)
	local humanoid = getHumanoid(character)
	if not rootPart or not humanoid or humanoid.Health <= 0 then return false end

	local targetPos = getTargetPosition(target)
	if not targetPos then return false end

	-- Teleport slightly above the target to avoid clipping
	rootPart.CFrame = CFrame.new(targetPos + Vector3.new(0, 3, 0))
	task.wait(0.3)
	return true
end

-- ══════════════════════════════════════
-- PATHFINDING (fewer waypoints for running)
-- ══════════════════════════════════════
local autofarmActive = false
local blacklistedTargets = {}
local foundFirstTarget = false
local useTeleportMode = false

local function pathfindTo(target)
	local character = getCharacter()
	local humanoid = getHumanoid(character)
	local rootPart = getRootPart(character)

	if not humanoid or not rootPart or humanoid.Health <= 0 then return false end

	local targetPos = getTargetPosition(target)
	if not targetPos then return false end

	if (rootPart.Position - targetPos).Magnitude > 2000 then return false end

	-- For gingerbread: if already close, just walk through
	if isTargetGingerbread(target) then
		local dist = (rootPart.Position - targetPos).Magnitude
		if dist <= 8 then
			humanoid:MoveTo(targetPos)
			task.wait(0.5)
			collectedGingerbreads[target] = true
			return true
		end
	end

	local path = PathfindingService:CreatePath({
		AgentRadius = 2,
		AgentHeight = 5,
		AgentCanJump = true,
		AgentCanClimb = false,
		WaypointSpacing = 12, -- INCREASED from 4 to 12 so running actually works between points
	})

	local success, err = pcall(function()
		path:ComputeAsync(rootPart.Position, targetPos)
	end)

	if not success or path.Status ~= Enum.PathStatus.Success then
		if Toggles.AutofarmVisualizer and Toggles.AutofarmVisualizer.Value then
			clearPathVisualizer()
		end
		humanoid:MoveTo(targetPos)
		local reached = false
		local moveStart = tick()
		local conn
		conn = humanoid.MoveToFinished:Connect(function(r)
			reached = true
			if conn then conn:Disconnect() end
		end)
		while not reached and tick() - moveStart < 10 do
			if not (Toggles.Autofarm and Toggles.Autofarm.Value) then
				if conn and conn.Connected then conn:Disconnect() end
				return false
			end
			-- Gingerbread: walk through check
			if isTargetGingerbread(target) and getDistanceToTarget(target) <= 4 then
				if conn and conn.Connected then conn:Disconnect() end
				collectedGingerbreads[target] = true
				return true
			end
			task.wait(0.1)
		end
		if conn and conn.Connected then conn:Disconnect() end
		if isTargetGingerbread(target) then collectedGingerbreads[target] = true end
		return reached
	end

	local waypoints = path:GetWaypoints()

	if Toggles.AutofarmVisualizer and Toggles.AutofarmVisualizer.Value then
		visualizePath(waypoints)
	end

	local pathStartTime = tick()

	for i, waypoint in ipairs(waypoints) do
		if not (Toggles.Autofarm and Toggles.Autofarm.Value) then
			clearPathVisualizer()
			return false
		end
		if tick() - pathStartTime > 15 then
			clearPathVisualizer()
			return false
		end

		local character2 = getCharacter()
		local humanoid2 = getHumanoid(character2)
		local rootPart2 = getRootPart(character2)
		if not humanoid2 or not rootPart2 or humanoid2.Health <= 0 then
			clearPathVisualizer()
			return false
		end

		if waypoint.Action == Enum.PathWaypointAction.Jump then
			humanoid2.Jump = true
		end

		humanoid2:MoveTo(waypoint.Position)

		if pathVisualizerParts[i] and pathVisualizerParts[i].Parent then
			pathVisualizerParts[i]:Destroy()
		end

		local reached = false
		local waypointStart = tick()
		local conn
		conn = humanoid2.MoveToFinished:Connect(function(r)
			reached = r
			if conn then conn:Disconnect() end
		end)

		while not reached and tick() - waypointStart < 8 do
			if not (Toggles.Autofarm and Toggles.Autofarm.Value) then
				if conn and conn.Connected then conn:Disconnect() end
				clearPathVisualizer()
				return false
			end
			if tick() - pathStartTime > 15 then
				if conn and conn.Connected then conn:Disconnect() end
				clearPathVisualizer()
				return false
			end
			-- Gingerbread: if close enough, mark collected and move on
			if isTargetGingerbread(target) and getDistanceToTarget(target) <= 4 then
				if conn and conn.Connected then conn:Disconnect() end
				clearPathVisualizer()
				collectedGingerbreads[target] = true
				return true
			end
			task.wait(0.1)
		end

		if conn and conn.Connected then conn:Disconnect() end
		if not reached then
			clearPathVisualizer()
			return false
		end
	end

	clearPathVisualizer()

	-- Mark gingerbread as collected
	if isTargetGingerbread(target) then
		collectedGingerbreads[target] = true
	end

	return true
end

-- ══════════════════════════════════════
-- GENERATOR INTERACTION WITH REMOTE MONITORING
-- ══════════════════════════════════════
local function getGeneratorRemoteProgress(genModel)
	-- Try to read progress from the generator's Remotes/RE
	local progress = getGeneratorProgress(genModel)
	return progress
end

local function doGeneratorInteraction(target)
	setDebugStatus("Doing generator..", getTargetTypeName(target))

	-- Initial check
	local initialProgress = getGeneratorProgress(target)
	setDebugProgress("Progress: " .. tostring(math.floor(initialProgress)))

	if initialProgress >= 100 then
		setDebugProgress("")
		setDebugStatus("Generator already done, skipping..")
		return
	end

	local baseTimeout = 12
	local lastProgress = initialProgress
	local lastProgressTime = tick()
	local interactionStartTime = tick()
	local firstCheckDone = false

	startHoldingF()

	while Toggles.Autofarm and Toggles.Autofarm.Value do
		if Library.Unloaded then break end

		local dist = getDistanceToTarget(target)

		-- If too far, stop
		if dist > 12 then
			setDebugStatus("Too far from generator, stopping..")
			break
		end

		-- Keep holding F if close
		if dist <= 8 then
			startHoldingF()
		else
			stopHoldingF()
		end

		-- Wait 2-3 seconds after starting before first progress check
		-- (puzzle completion takes a moment to register)
		local elapsed = tick() - interactionStartTime

		if elapsed >= 3 and not firstCheckDone then
			firstCheckDone = true
			local currentProgress = getGeneratorProgress(target)
			setDebugProgress("Progress: " .. tostring(math.floor(currentProgress)))
			if currentProgress > lastProgress then
				lastProgress = currentProgress
				lastProgressTime = tick()
				setDebugStatus("Generator progress increasing..", getTargetTypeName(target))
			end
		end

		-- Check progress every second after initial wait
		if firstCheckDone then
			local currentProgress = getGeneratorProgress(target)
			setDebugProgress("Progress: " .. tostring(math.floor(currentProgress)))

			-- Done!
			if currentProgress >= 100 then
				setDebugStatus("Generator complete!", getTargetTypeName(target))
				break
			end

			if currentProgress > lastProgress then
				-- Progress going up, extend timer by 10 seconds
				lastProgress = currentProgress
				lastProgressTime = tick()
				setDebugStatus("Generator progress increasing..", getTargetTypeName(target))
			end

			-- Timeout from last progress change
			local timeSinceProgress = tick() - lastProgressTime
			if timeSinceProgress > baseTimeout then
				setDebugStatus("Generator timeout, moving on..", getTargetTypeName(target))
				break
			end
		else
			-- Before first check, still enforce a maximum wait
			if elapsed > 15 then
				setDebugStatus("Generator initial timeout..")
				break
			end
		end

		task.wait(1)
	end

	stopHoldingF()
	setDebugProgress("")
end

-- ══════════════════════════════════════
-- GINGERBREAD INTERACTION (just walk through)
-- ══════════════════════════════════════
local function doGingerbreadInteraction(target)
	setDebugStatus("Grabbing gingerbread..", getTargetTypeName(target))
	-- Just walk to exact position
	local character = getCharacter()
	local humanoid = getHumanoid(character)
	local targetPos = getTargetPosition(target)

	if humanoid and targetPos then
		humanoid:MoveTo(targetPos)
		-- Wait briefly but don't stall
		local startTime = tick()
		while tick() - startTime < 1.5 do
			if getDistanceToTarget(target) <= 3 then break end
			if not (Toggles.Autofarm and Toggles.Autofarm.Value) then break end
			task.wait(0.1)
		end
	end

	-- Mark as collected regardless
	collectedGingerbreads[target] = true
end

-- ══════════════════════════════════════
-- MAIN TAB - AUTOFARM
-- ══════════════════════════════════════
local LeftGroupBox = Tabs.Main:AddLeftGroupbox("Autofarm")

LeftGroupBox:AddLabel("Sprint keybind = Shift\nInteract keybind = F\nKiller = Off", true)
LeftGroupBox:AddDivider()

LeftGroupBox:AddDropdown("AutofarmMode", {
	Values = { "Gingerbread", "Generators", "Both (Generators Priority)" },
	Default = "Both (Generators Priority)",
	Text = "Autofarm Mode",
	Tooltip = "Choose what to pathfind to",
})

LeftGroupBox:AddDropdown("AutofarmMovement", {
	Values = { "Pathfind", "Teleport" },
	Default = "Pathfind",
	Text = "Movement Mode",
	Tooltip = "Pathfind walks to targets, Teleport instantly moves you there",
})

LeftGroupBox:AddToggle("Autofarm", {
	Text = "Autofarm",
	Tooltip = "Automatically farms currency locations and generators.",
	Default = false,
})

LeftGroupBox:AddToggle("AutofarmRun", {
	Text = "Run While Farming",
	Tooltip = "Holds shift to sprint while autofarm is active",
	Default = false,
})

LeftGroupBox:AddToggle("AutofarmRunInfStamina", {
	Text = "Run Infinite Stamina Mode",
	Tooltip = "Run 8s, rest 0.5s instead of 10s",
	Default = false,
})

LeftGroupBox:AddToggle("AutoUseAbility", {
	Text = "Auto Use Ability (Q/E/R)",
	Tooltip = "Automatically presses Q, E, R abilities while autofarm is active",
	Default = false,
})

LeftGroupBox:AddToggle("AutofarmVisualizer", {
	Text = "Show Path Visualizer",
	Tooltip = "Shows white dots along the pathfinding route",
	Default = true,
})

LeftGroupBox:AddToggle("AutofarmDebug", {
	Text = "Debug HUD",
	Tooltip = "Shows what the autofarm is currently doing",
	Default = false,
	Callback = function(v) debugEnabled = v end,
})

LeftGroupBox:AddToggle("AutofarmHighlightTarget", {
	Text = "Highlight Current Target",
	Tooltip = "Highlights the current autofarm target in white",
	Default = false,
	Callback = function(v)
		highlightTargetEnabled = v
		if not v then clearTargetHighlight() end
	end,
})

LeftGroupBox:AddToggle("AutofarmServerHop", {
	Text = "Auto Server Hop (No Targets)",
	Tooltip = "Server hops when no more targets are available after finding at least one",
	Default = false,
})

LeftGroupBox:AddDivider()
LeftGroupBox:AddLabel("Killer Detection")

LeftGroupBox:AddToggle("KillerAutoReset", {
	Text = "Auto Reset if Killer",
	Tooltip = "Automatically resets character if you are on the killer team",
	Default = false,
})

LeftGroupBox:AddToggle("KillerAutoHop", {
	Text = "Auto Server Hop if Killer",
	Tooltip = "Automatically server hops if you are on the killer team",
	Default = false,
})

Toggles.AutofarmRun:OnChanged(function()
	if Toggles.AutofarmRun.Value then
		sprintRunning = true
		startSprintLoop()
	else
		stopSprintLoop()
	end
end)

Toggles.AutofarmRunInfStamina:OnChanged(function()
	sprintInfStamina = Toggles.AutofarmRunInfStamina.Value
end)

Toggles.AutoUseAbility:OnChanged(function()
	if Toggles.AutoUseAbility.Value then
		autoUseAbility = true
		startAutoAbility()
	else
		stopAutoAbility()
	end
end)

-- Killer detection loop
task.spawn(function()
	while true do
		task.wait(2)
		if Library.Unloaded then break end
		if isOnKillerTeam() then
			if Toggles.KillerAutoHop and Toggles.KillerAutoHop.Value then
				Library:Notify("Killer detected! Server hopping...", 3)
				task.wait(1)
				serverHop()
				task.wait(10)
			elseif Toggles.KillerAutoReset and Toggles.KillerAutoReset.Value then
				Library:Notify("Killer detected! Resetting...", 3)
				task.wait(0.5)
				local char = LocalPlayer.Character
				local humanoid = char and char:FindFirstChildOfClass("Humanoid")
				if humanoid then humanoid.Health = 0 end
				task.wait(5)
			end
		end
	end
end)

-- Clean up collected gingerbreads that got removed from workspace
task.spawn(function()
	while true do
		task.wait(5)
		if Library.Unloaded then break end
		for ginger, _ in pairs(collectedGingerbreads) do
			if not ginger or not ginger.Parent then
				collectedGingerbreads[ginger] = nil
			end
		end
	end
end)

-- ══════════════════════════════════════
-- AUTOFARM MAIN LOOP
-- ══════════════════════════════════════
task.spawn(function()
	while true do
		task.wait(0.3)

		if Library.Unloaded then
			clearPathVisualizer()
			clearTargetHighlight()
			stopHoldingF()
			break
		end

		if Toggles.Autofarm and Toggles.Autofarm.Value and not autofarmActive then
			if autofarmStartTime == 0 then
				autofarmStartTime = tick()
				foundFirstTarget = false
				collectedGingerbreads = {}
			end

			local movementMode = Options.AutofarmMovement and Options.AutofarmMovement.Value or "Pathfind"

			local character = getCharacter()
			local rootPart = getRootPart(character)
			local humanoid = getHumanoid(character)

			if rootPart and humanoid and humanoid.Health > 0 then
				setDebugStatus("Looking for target..")
				setDebugProgress("")

				local mode = Options.AutofarmMode and Options.AutofarmMode.Value or "Both (Generators Priority)"
				local target = nil

				local function filterBlacklisted(list)
					local filtered = {}
					for _, item in ipairs(list) do
						if not blacklistedTargets[item] then
							table.insert(filtered, item)
						end
					end
					return filtered
				end

				-- Check generator progress before selecting
				if mode == "Generators" or mode == "Both (Generators Priority)" then
					setDebugStatus("Checking progress on closest generator..")
					local allGens = getGenerators()
					local filteredGens = filterBlacklisted(allGens)
					local closestGenCheck = getClosestFromList(rootPart, filteredGens, 2000)
					if closestGenCheck then
						local prog = getGeneratorProgress(closestGenCheck)
						setDebugProgress("Progress: " .. tostring(math.floor(prog)))
						task.wait(0.2)
					end
				end

				if mode == "Gingerbread" then
					target = getClosestFromList(rootPart, filterBlacklisted(getCurrencyLocations()), 2000)
				elseif mode == "Generators" then
					target = getClosestFromList(rootPart, filterBlacklisted(getGenerators()), 2000)
				elseif mode == "Both (Generators Priority)" then
					local filteredGens = filterBlacklisted(getGenerators())
					local filteredGinger = filterBlacklisted(getCurrencyLocations())
					local closestGen, genDist = getClosestFromList(rootPart, filteredGens, 2000)
					local closestGinger, gingerDist = getClosestFromList(rootPart, filteredGinger, 2000)

					if closestGinger and closestGen then
						if gingerDist < genDist then
							target = closestGinger
						else
							target = closestGen
						end
					elseif closestGen then
						target = closestGen
					elseif closestGinger then
						target = closestGinger
					end
				end

				if target then
					foundFirstTarget = true
					autofarmActive = true
					local targetType = getTargetTypeName(target)
					local isGinger = isTargetGingerbread(target)

					if isGinger then
						setDebugStatus("Travelling to gingerbread..", targetType)
					else
						setDebugStatus("Travelling to generator..", targetType)
					end
					setTargetHighlight(target)

					local reachedTarget = false

					if movementMode == "Teleport" then
						reachedTarget = teleportToTarget(target)
						if isGinger and reachedTarget then
							collectedGingerbreads[target] = true
						end
					else
						reachedTarget = pathfindTo(target)
					end

					if reachedTarget and Toggles.Autofarm and Toggles.Autofarm.Value then
						if isGinger then
							-- Gingerbread: already collected by walking through / teleporting
							-- No F tap needed, just mark and move on
							if not collectedGingerbreads[target] then
								collectedGingerbreads[target] = true
							end
							setDebugStatus("Gingerbread collected!", targetType)
						else
							-- Generator: stop pathfinding, stay and do the generator
							if not isGeneratorDone(target) then
								doGeneratorInteraction(target)
							else
								setDebugStatus("Generator already done, skipping..")
							end
						end
					elseif not reachedTarget then
						blacklistedTargets[target] = true
						task.delay(15, function()
							blacklistedTargets[target] = nil
						end)
					end

					clearTargetHighlight()
					setDebugProgress("")
					autofarmActive = false
				else
					setDebugStatus("No (more) targets..")
					setDebugProgress("")
					clearTargetHighlight()

					local rawGens = getGenerators()
					local rawGinger = getCurrencyLocations()
					if #rawGens == 0 and #rawGinger == 0 then
						blacklistedTargets = {}
					end

					if Toggles.AutofarmServerHop and Toggles.AutofarmServerHop.Value and foundFirstTarget then
						setDebugStatus("Server hopping..")
						task.wait(1)
						serverHop()
					end

					task.wait(2)
				end
			end
		else
			if not (Toggles.Autofarm and Toggles.Autofarm.Value) then
				if autofarmActive then autofarmActive = false end
				clearPathVisualizer()
				clearTargetHighlight()
				stopHoldingF()
				blacklistedTargets = {}
				autofarmStartTime = 0
				foundFirstTarget = false
				collectedGingerbreads = {}
				setDebugStatus("Idle")
				setDebugProgress("")
			end
		end
	end
end)

Toggles.Autofarm:OnChanged(function()
	if not Toggles.Autofarm.Value then
		autofarmActive = false
		clearPathVisualizer()
		clearTargetHighlight()
		stopHoldingF()
		releaseKey(Enum.KeyCode.F)
		blacklistedTargets = {}
		autofarmStartTime = 0
		foundFirstTarget = false
		collectedGingerbreads = {}
		setDebugStatus("Idle")
		setDebugProgress("")
	end
end)

-- ══════════════════════════════════════
-- MAIN TAB - AUTO GENERATOR (SEPARATE)
-- ══════════════════════════════════════
local GenGroupBox = Tabs.Main:AddLeftGroupbox("Auto Generator")

local autoGen = false
local autoGenSpeed = 0.08

GenGroupBox:AddToggle("AutoGen", {
	Text = "Auto Generator",
	Default = false,
	Callback = function(v) autoGen = v end
})
GenGroupBox:AddInput("GenSpeed", {
	Text = "Gen Speed",
	Default = "0.08",
	Numeric = true,
	PlaceholderText = "0.03 - 0.5",
	Callback = function(text)
		local num = tonumber(text)
		if num and num >= 0.03 and num <= 0.5 then
			autoGenSpeed = num
		else
			autoGenSpeed = 0.08
			Library:Notify("Gen Speed must be between 0.03 and 0.5!", 3)
		end
	end
})

do
	local FlowGameModule
	local oldNew
	local hookedGen = false

	local function isNeighbour(r1, c1, r2, c2)
		return (r2 == r1-1 and c2 == c1) or (r2 == r1+1 and c2 == c1) or (r2 == r1 and c2 == c1-1) or (r2 == r1 and c2 == c1+1)
	end

	local function key(n) return n.row .. "-" .. n.col end

	local function orderPath(path, endpoints)
		if not path or #path == 0 then return path end
		local start = endpoints and endpoints[1] or path[1]
		local pool = {}
		for _, n in ipairs(path) do pool[key(n)] = {row = n.row, col = n.col} end
		local ordered = {}
		local cur = {row = start.row, col = start.col}
		table.insert(ordered, cur)
		pool[key(cur)] = nil
		while next(pool) do
			local found = false
			for k, n in pairs(pool) do
				if isNeighbour(cur.row, cur.col, n.row, n.col) then
					table.insert(ordered, n)
					pool[k] = nil
					cur = n
					found = true
					break
				end
			end
			if not found then break end
		end
		return ordered
	end

	local HintSystem = {}
	function HintSystem:Draw(puzzle)
		if not puzzle or not puzzle.Solution then return end
		for i = 1, #puzzle.Solution do
			local path = puzzle.Solution[i]
			local ends = puzzle.targetPairs[i]
			local ordered = orderPath(path, ends)
			puzzle.paths[i] = {}
			for _, node in ipairs(ordered) do
				if not autoGen then return end
				table.insert(puzzle.paths[i], {row = node.row, col = node.col})
				puzzle:updateGui()
				task.wait(autoGenSpeed)
			end
			puzzle:checkForWin()
		end
	end

	local function hookAutoGen()
		if hookedGen then return end
		pcall(function()
			local mod = ReplicatedStorage.Modules.Misc.FlowGameManager.FlowGame
			FlowGameModule = require(mod)
			oldNew = oldNew or FlowGameModule.new
			FlowGameModule.new = function(...)
				local puzzle = oldNew(...)
				task.spawn(function()
					if autoGen then HintSystem:Draw(puzzle) end
				end)
				return puzzle
			end
			hookedGen = true
		end)
	end

	hookAutoGen()
end

-- ══════════════════════════════════════
-- MAIN TAB - AUTOBLOCK
-- ══════════════════════════════════════
local RightGroupBox = Tabs.Main:AddRightGroupbox("Auto Block")

local autoBlockTriggerSounds = {
	["102228729296384"]=true,["140242176732868"]=true,["112809109188560"]=true,["136323728355613"]=true,
	["115026634746636"]=true,["84116622032112"]=true,["108907358619313"]=true,["127793641088496"]=true,
	["86174610237192"]=true,["95079963655241"]=true,["101199185291628"]=true,["119942598489800"]=true,
	["84307400688050"]=true,["113037804008732"]=true,["105200830849301"]=true,["75330693422988"]=true,
	["82221759983649"]=true,["81702359653578"]=true,["108610718831698"]=true,["112395455254818"]=true,
	["109431876587852"]=true,["109348678063422"]=true,["85853080745515"]=true,["12222216"]=true,
	["105840448036441"]=true,["114742322778642"]=true,["119583605486352"]=true,["79980897195554"]=true,
	["71805956520207"]=true,["79391273191671"]=true,["89004992452376"]=true,["101553872555606"]=true,
	["101698569375359"]=true,["106300477136129"]=true,["116581754553533"]=true,["117231507259853"]=true,
	["119089145505438"]=true,["121954639447247"]=true,["125213046326879"]=true,["131406927389838"]=true
}

local AttackAnimations = {
	"rbxassetid://131430497821198","rbxassetid://83829782357897","rbxassetid://126830014841198",
	"rbxassetid://126355327951215","rbxassetid://121086746534252","rbxassetid://105458270463374",
	"rbxassetid://127172483138092","rbxassetid://18885919947","rbxassetid://18885909645",
	"rbxassetid://87259391926321","rbxassetid://106014898528300","rbxassetid://86545133269813",
	"rbxassetid://89448354637442","rbxassetid://90499469533503","rbxassetid://116618003477002",
	"rbxassetid://106086955212611","rbxassetid://107640065977686","rbxassetid://77124578197357",
	"rbxassetid://101771617803133","rbxassetid://134958187822107","rbxassetid://111313169447787",
	"rbxassetid://71685573690338","rbxassetid://129843313690921","rbxassetid://97623143664485",
	"rbxassetid://136007065400978","rbxassetid://86096387000557","rbxassetid://108807732150251",
	"rbxassetid://138040001965654","rbxassetid://73502073176819","rbxassetid://86709774283672",
	"rbxassetid://140703210927645","rbxassetid://96173857867228","rbxassetid://121255898612475",
	"rbxassetid://98031287364865","rbxassetid://119462383658044","rbxassetid://77448521277146",
	"rbxassetid://103741352379819","rbxassetid://131696603025265","rbxassetid://122503338277352",
	"rbxassetid://97648548303678","rbxassetid://94162446513587","rbxassetid://84426150435898",
	"rbxassetid://93069721274110","rbxassetid://114620047310688","rbxassetid://97433060861952",
	"rbxassetid://82183356141401","rbxassetid://100592913030351","rbxassetid://121293883585738",
	"rbxassetid://70447634862911","rbxassetid://92173139187970","rbxassetid://106847695270773",
	"rbxassetid://125403313786645","rbxassetid://81639435858902","rbxassetid://137314737492715",
	"rbxassetid://120112897026015","rbxassetid://82113744478546","rbxassetid://118298475669935",
	"rbxassetid://126681776859538","rbxassetid://129976080405072","rbxassetid://109667959938617",
	"rbxassetid://74707328554358","rbxassetid://133336594357903","rbxassetid://86204001129974",
	"rbxassetid://124243639579224","rbxassetid://70371667919898","rbxassetid://131543461321709",
	"rbxassetid://136323728355613","rbxassetid://109230267448394","rbxassetid://122709416391891",
	"rbxassetid://121808371053483","rbxassetid://106538427162796","rbxassetid://88451353906104"
}

local autoBlockOn = false
local autoBlockAudioOn = false
local detectionRange = 12
local facingCheckEnabled = true
local customFacingDot = -0.3
local blockdelay = 0

local cachedBlockBtn, cachedCooldown
local function refreshUIRefs()
	local main = PlayerGui:FindFirstChild("MainUI")
	if main then
		local ability = main:FindFirstChild("AbilityContainer")
		cachedBlockBtn = ability and ability:FindFirstChild("Block")
		cachedCooldown = cachedBlockBtn and cachedBlockBtn:FindFirstChild("CooldownTime")
	end
end
refreshUIRefs()
PlayerGui.ChildAdded:Connect(function(child)
	if child.Name == "MainUI" then task.delay(0.02, refreshUIRefs) end
end)
LocalPlayer.CharacterAdded:Connect(function() task.delay(0.5, refreshUIRefs) end)

local function isFacing(myRoot, targetRoot)
	if not facingCheckEnabled then return true end
	local dir = (myRoot.Position - targetRoot.Position).Unit
	local dot = targetRoot.CFrame.LookVector:Dot(dir)
	return dot > customFacingDot
end

RightGroupBox:AddToggle("AutoBlockAnim", {
	Text = "Auto Block (Animation)",
	Default = false,
	Callback = function(v) autoBlockOn = v end
}):AddKeyPicker("AutoBlockAnimKeybind", {
	Default = "V",
	SyncToggleState = true,
	Mode = "Toggle",
	Text = "Auto Block (Anim)",
	NoUI = false,
})

RightGroupBox:AddToggle("AutoBlockAudio", {
	Text = "Auto Block (Audio)",
	Default = false,
	Callback = function(v) autoBlockAudioOn = v end
}):AddKeyPicker("AutoBlockAudioKeybind", {
	Default = "B",
	SyncToggleState = true,
	Mode = "Toggle",
	Text = "Auto Block (Audio)",
	NoUI = false,
})

RightGroupBox:AddInput("DetectionRange", {
	Text = "Detection Range",
	Default = "12",
	Numeric = true,
	Callback = function(t) detectionRange = tonumber(t) or detectionRange end
})
RightGroupBox:AddToggle("FacingCheck", {
	Text = "Enable Facing Check",
	Default = true,
	Callback = function(v) facingCheckEnabled = v end
})
RightGroupBox:AddInput("FacingDot", {
	Text = "Facing Check DOT",
	Default = "-0.3",
	Numeric = true,
	Callback = function(t) customFacingDot = tonumber(t) or customFacingDot end
})
RightGroupBox:AddInput("BlockDelay", {
	Text = "Block Delay (seconds)",
	Default = "0",
	Numeric = true,
	Callback = function(t) blockdelay = tonumber(t) or blockdelay end
})

local soundHooks = {}
local soundBlockedUntil = {}
local lastLocalBlockTime = 0
local AUDIO_LOCAL_COOLDOWN = 0.35

local function extractNumericSoundId(sound)
	local sid = sound.SoundId
	if type(sid) ~= "string" then sid = tostring(sid) end
	return sid:match("rbxassetid://(%d+)") or sid:match("://(%d+)") or sid:match("^(%d+)$")
end

local function hookSound(sound)
	if not sound:IsA("Sound") or soundHooks[sound] then return end
	local id = extractNumericSoundId(sound)
	if not id or not autoBlockTriggerSounds[id] then return end
	soundHooks[sound] = true
	local function tryBlock()
		if not autoBlockAudioOn then return end
		if tick() - lastLocalBlockTime < AUDIO_LOCAL_COOLDOWN then return end
		if soundBlockedUntil[sound] and tick() < soundBlockedUntil[sound] then return end
		local myRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
		if not myRoot then return end
		local parent = sound.Parent
		while parent and not parent:FindFirstChild("HumanoidRootPart") do parent = parent.Parent end
		local hrp = parent and parent:FindFirstChild("HumanoidRootPart")
		if not hrp then return end
		if (hrp.Position - myRoot.Position).Magnitude > detectionRange then return end
		if facingCheckEnabled and not isFacing(myRoot, hrp) then return end
		refreshUIRefs()
		if cachedCooldown and cachedCooldown.Text ~= "" then return end
		task.wait(blockdelay)
		click("Block")
		lastLocalBlockTime = tick()
		soundBlockedUntil[sound] = tick() + 1
	end
	sound.Played:Connect(tryBlock)
	sound:GetPropertyChangedSignal("IsPlaying"):Connect(function() if sound.IsPlaying then tryBlock() end end)
	if sound.IsPlaying then tryBlock() end
end

for _, desc in ipairs(KillersFolder:GetDescendants()) do if desc:IsA("Sound") then hookSound(desc) end end
KillersFolder.DescendantAdded:Connect(function(desc) if desc:IsA("Sound") then hookSound(desc) end end)

RunService.RenderStepped:Connect(function()
	if not autoBlockOn then return end
	local myChar = LocalPlayer.Character
	if not myChar then return end
	local myRoot = myChar:FindFirstChild("HumanoidRootPart")
	if not myRoot then return end
	refreshUIRefs()
	if cachedCooldown and cachedCooldown.Text ~= "" then return end
	for _, killer in ipairs(KillersFolder:GetChildren()) do
		local hrp = killer:FindFirstChild("HumanoidRootPart")
		if hrp and (hrp.Position - myRoot.Position).Magnitude <= detectionRange then
			local hum = killer:FindFirstChildOfClass("Humanoid")
			local animator = hum and hum:FindFirstChildOfClass("Animator")
			if animator then
				for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
					local animId = tostring(track.Animation.AnimationId):match("%d+")
					if animId and table.find(AttackAnimations, animId) then
						if not facingCheckEnabled or isFacing(myRoot, hrp) then
							task.wait(blockdelay)
							click("Block")
							return
						end
					end
				end
			end
		end
	end
end)

-- ══════════════════════════════════════
-- EXPLOITS TAB
-- ══════════════════════════════════════
local StaminaGroup = Tabs.Exploits:AddLeftGroupbox("Stamina")
local StaminaValuesGroup = Tabs.Exploits:AddRightGroupbox("Stamina Values")
local MiscExploitsGroup = Tabs.Exploits:AddLeftGroupbox("Misc Exploits")

local customMaxStamina = 100
local customStaminaGain = 20
local customStaminaLoss = 5
local customSprintSpeed = 28
local infStamina = false
local enableMaxStamina = false
local enableStaminaGain = false
local enableStaminaLoss = false
local enableSprintSpeed = false
local originalMaxStamina = nil
local originalStaminaGain = nil
local originalStaminaLoss = nil
local originalSprintSpeed = nil

local SprintingModule = nil
pcall(function()
	SprintingModule = require(ReplicatedStorage.Systems.Character.Game.Sprinting)
end)

task.spawn(function()
	while task.wait(0.1) do
		if Library.Unloaded then break end
		if SprintingModule then
			if infStamina then
				SprintingModule.Stamina = SprintingModule.MaxStamina
			else
				if enableMaxStamina then SprintingModule.MaxStamina = customMaxStamina
				elseif originalMaxStamina then SprintingModule.MaxStamina = originalMaxStamina end
				if enableStaminaGain then SprintingModule.StaminaGain = customStaminaGain
				elseif originalStaminaGain then SprintingModule.StaminaGain = originalStaminaGain end
				if enableStaminaLoss then SprintingModule.StaminaLoss = customStaminaLoss
				elseif originalStaminaLoss then SprintingModule.StaminaLoss = originalStaminaLoss end
				if enableSprintSpeed then SprintingModule.SprintSpeed = customSprintSpeed
				elseif originalSprintSpeed then SprintingModule.SprintSpeed = originalSprintSpeed end
			end
		end
	end
end)

task.spawn(function()
	while task.wait(1) do
		if Library.Unloaded then break end
		if SprintingModule then
			if not originalMaxStamina then originalMaxStamina = SprintingModule.MaxStamina end
			if not originalStaminaGain then originalStaminaGain = SprintingModule.StaminaGain end
			if not originalStaminaLoss then originalStaminaLoss = SprintingModule.StaminaLoss end
			if not originalSprintSpeed then originalSprintSpeed = SprintingModule.SprintSpeed end
		end
	end
end)

StaminaGroup:AddToggle("InfStamina", { Text = "Infinite Stamina", Default = false, Callback = function(v) infStamina = v end })
StaminaGroup:AddToggle("EnableMaxStamina", { Text = "Custom Max Stamina", Default = false, Callback = function(v) enableMaxStamina = v end })
StaminaGroup:AddToggle("EnableStaminaGain", { Text = "Custom Stamina Gain", Default = false, Callback = function(v) enableStaminaGain = v end })
StaminaGroup:AddToggle("EnableStaminaLoss", { Text = "Custom Stamina Loss", Default = false, Callback = function(v) enableStaminaLoss = v end })
StaminaGroup:AddToggle("EnableSprintSpeed", { Text = "Custom Sprint Speed", Default = false, Callback = function(v) enableSprintSpeed = v end })

StaminaValuesGroup:AddInput("MaxStamina", { Text = "Max Stamina", Default = "100", Numeric = true, Callback = function(v) customMaxStamina = tonumber(v) or 100 end })
StaminaValuesGroup:AddInput("StaminaGain", { Text = "Stamina Gain", Default = "20", Numeric = true, Callback = function(v) customStaminaGain = tonumber(v) or 20 end })
StaminaValuesGroup:AddInput("StaminaLoss", { Text = "Stamina Loss", Default = "5", Numeric = true, Callback = function(v) customStaminaLoss = tonumber(v) or 5 end })
StaminaValuesGroup:AddInput("SprintSpeed", { Text = "Sprint Speed", Default = "28", Numeric = true, Callback = function(v) customSprintSpeed = tonumber(v) or 28 end })

MiscExploitsGroup:AddToggle("HakariDance", {
	Text = "Hakari Dance",
	Default = false,
	Callback = function(state)
		local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
		local humanoid = char:WaitForChild("Humanoid")
		local rootPart = char:WaitForChild("HumanoidRootPart")
		if state then
			humanoid.PlatformStand = true
			humanoid.JumpPower = 0
			local bv = Instance.new("BodyVelocity")
			bv.MaxForce = Vector3.new(100000, 100000, 100000)
			bv.Velocity = Vector3.zero
			bv.Parent = rootPart
			local anim = Instance.new("Animation")
			anim.AnimationId = "rbxassetid://138019937280193"
			local track = humanoid:LoadAnimation(anim)
			track:Play()
			local snd = Instance.new("Sound")
			snd.SoundId = "rbxassetid://87166578676888"
			snd.Parent = rootPart
			snd.Volume = 0.5
			snd.Looped = true
			snd:Play()
			pcall(function()
				local fx = ReplicatedStorage.Assets.Emotes.HakariDance.HakariBeamEffect:Clone()
				fx.Name = "PlayerEmoteVFX"
				fx.CFrame = char.PrimaryPart.CFrame * CFrame.new(0, -1, -0.3)
				fx.WeldConstraint.Part0 = char.PrimaryPart
				fx.WeldConstraint.Part1 = fx
				fx.Parent = char
				fx.CanCollide = false
			end)
			pcall(function()
				ReplicatedStorage.Modules.Network.RemoteEvent:FireServer("PlayEmote", "Animations", "HakariDance")
			end)
			track.Stopped:Connect(function()
				if not Toggles.HakariDance.Value then
					humanoid.PlatformStand = false
					if bv and bv.Parent then bv:Destroy() end
				end
			end)
		else
			humanoid.PlatformStand = false
			humanoid.JumpPower = 50
			local bv = rootPart:FindFirstChildOfClass("BodyVelocity")
			if bv then bv:Destroy() end
			local snd = rootPart:FindFirstChildOfClass("Sound")
			if snd and snd.SoundId:find("87166578676888") then snd:Stop() snd:Destroy() end
			local fx = char:FindFirstChild("PlayerEmoteVFX")
			if fx then fx:Destroy() end
			for _, t in ipairs(humanoid:GetPlayingAnimationTracks()) do
				if t.Animation.AnimationId == "rbxassetid://138019937280193" then t:Stop() end
			end
		end
	end
}):AddKeyPicker("HakariDanceKeybind", { Default = "H", SyncToggleState = true, Mode = "Toggle", Text = "Hakari Dance", NoUI = false })

do
	local voidrushcontrol = false
	local ORIGINAL_DASH_SPEED = 55
	local isOverrideActive = false
	local voidConnection
	local function startOverride()
		if isOverrideActive then return end
		isOverrideActive = true
		voidConnection = RunService.RenderStepped:Connect(function()
			local hum = _G.Humanoid
			local rp = _G.HumanoidRootPart
			if not hum or not rp then return end
			hum.WalkSpeed = ORIGINAL_DASH_SPEED
			hum.AutoRotate = false
			local dir = rp.CFrame.LookVector
			local h = Vector3.new(dir.X, 0, dir.Z)
			if h.Magnitude > 0 then hum:Move(h.Unit) end
		end)
	end
	local function stopOverride()
		if not isOverrideActive then return end
		isOverrideActive = false
		local hum = _G.Humanoid
		if hum then hum.WalkSpeed = 18 hum.AutoRotate = true hum:Move(Vector3.zero) end
		if voidConnection then voidConnection:Disconnect() voidConnection = nil end
	end
	RunService.RenderStepped:Connect(function()
		if not voidrushcontrol then return end
		local char = _G.Humanoid and _G.Humanoid.Parent
		local state = char and char:GetAttribute("VoidRushState")
		if state == "Dashing" then startOverride() else stopOverride() end
	end)
	MiscExploitsGroup:AddToggle("VoidrushControl", { Text = "Voidrush Controllable", Default = false, Callback = function(v) voidrushcontrol = v end })
end

do
	local veronicaEnabled = false
	local activeMonitors = {}
	local descendantAddedConn = nil
	local behaviorFolder = nil
	pcall(function() behaviorFolder = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Survivors"):WaitForChild("Veeronica"):WaitForChild("Behavior") end)

	local function getSprintingButton() return LocalPlayer.PlayerGui:WaitForChild("MainUI"):WaitForChild("SprintingButton") end
	local function safeConnect(inst, prop, fn)
		local ok, sig = pcall(function() return inst:GetPropertyChangedSignal(prop) end)
		if ok and sig then return sig:Connect(fn) end
	end

	local function monitorHL(h)
		if not h or activeMonitors[h] then return end
		local conns = {}
		local prev = false
		local function cleanup() for _, c in ipairs(conns) do if c and c.Connected then c:Disconnect() end end activeMonitors[h] = nil end
		local function isPlayer() local a = h.Adornee local c = LocalPlayer.Character if not a or not c then return false end return a == c or a:IsDescendantOf(c) end
		local function onChg()
			if not veronicaEnabled or not h or not h.Parent then cleanup() return end
			local cur = isPlayer()
			if prev ~= cur and cur then
				local ok, btn = pcall(getSprintingButton)
				if ok and btn then for _, v in pairs(getconnections(btn.MouseButton1Down)) do pcall(v.Fire, v) end end
			end
			prev = cur
		end
		local c = safeConnect(h, "Adornee", onChg) if c then table.insert(conns, c) end
		table.insert(conns, h.AncestryChanged:Connect(function(_, p) if not p then cleanup() else onChg() end end))
		table.insert(conns, LocalPlayer.CharacterAdded:Connect(onChg))
		table.insert(conns, LocalPlayer.CharacterRemoving:Connect(onChg))
		activeMonitors[h] = cleanup
		task.spawn(onChg)
	end

	local function startMgr()
		if descendantAddedConn or not behaviorFolder then return end
		for _, d in ipairs(behaviorFolder:GetDescendants()) do if d:IsA("Highlight") then monitorHL(d) end end
		descendantAddedConn = behaviorFolder.DescendantAdded:Connect(function(c) if c:IsA("Highlight") then monitorHL(c) end end)
	end
	local function stopMgr()
		if descendantAddedConn and descendantAddedConn.Connected then descendantAddedConn:Disconnect() end
		descendantAddedConn = nil
		for _, cl in pairs(activeMonitors) do pcall(cl) end
		activeMonitors = {}
	end

	MiscExploitsGroup:AddToggle("AutoTrick", { Text = "Veronica Auto Trick", Default = false, Callback = function(v) veronicaEnabled = v if v then startMgr() else stopMgr() end end })
end

MiscExploitsGroup:AddToggle("AlwaysShowChat", {
	Text = "Always Show Chat",
	Default = false,
	Callback = function(state)
		_G.showChat = state
		if state then
			task.spawn(function()
				while _G.showChat and task.wait() do
					if Library.Unloaded then break end
					local cfg = game:GetService("TextChatService"):FindFirstChildOfClass("ChatWindowConfiguration")
					if cfg then cfg.Enabled = true end
				end
			end)
		else
			local ps = LocalPlayer:GetAttribute("PlayingState") or "Playing"
			if ps ~= "Spectating" then
				local cfg = game:GetService("TextChatService"):FindFirstChildOfClass("ChatWindowConfiguration")
				if cfg then cfg.Enabled = false end
			end
		end
	end
})

-- ══════════════════════════════════════
-- VISUALS TAB
-- ══════════════════════════════════════
local ESPGroup = Tabs.Visuals:AddLeftGroupbox("ESP / Highlights")
local LightingGroup = Tabs.Visuals:AddRightGroupbox("Lighting")

local visualEnabled = false
local showKiller = false
local showSurvivor = false
local showItems = false
local showGen = false
local showGingerbread = false

local killerColor = Color3.fromRGB(255, 70, 70)
local survivorColor = Color3.fromRGB(70, 255, 70)
local generatorColor = Color3.fromRGB(255, 255, 0)
local itemColor = Color3.fromRGB(180, 0, 255)
local gingerbreadColor = Color3.fromRGB(255, 165, 0)

ESPGroup:AddToggle("ESPEnabled", { Text = "Enable ESP", Default = false, Callback = function(v) visualEnabled = v end })
ESPGroup:AddToggle("ShowKiller", { Text = "Killer Outline", Default = false, Callback = function(v) showKiller = v end }):AddColorPicker("KillerColor", { Default = killerColor, Title = "Killer Color", Callback = function(v) killerColor = v end })
ESPGroup:AddToggle("ShowSurvivor", { Text = "Survivor Outline", Default = false, Callback = function(v) showSurvivor = v end }):AddColorPicker("SurvivorColor", { Default = survivorColor, Title = "Survivor Color", Callback = function(v) survivorColor = v end })
ESPGroup:AddToggle("ShowGenerator", { Text = "Generator Outline", Default = false, Callback = function(v) showGen = v end }):AddColorPicker("GeneratorColor", { Default = generatorColor, Title = "Generator Color", Callback = function(v) generatorColor = v end })
ESPGroup:AddToggle("ShowItems", { Text = "Medkit & BloxyCola Outline", Default = false, Callback = function(v) showItems = v end }):AddColorPicker("ItemColor", { Default = itemColor, Title = "Item Color", Callback = function(v) itemColor = v end })
ESPGroup:AddToggle("ShowGingerbread", { Text = "Gingerbread Outline", Default = false, Callback = function(v) showGingerbread = v end }):AddColorPicker("GingerbreadColor", { Default = gingerbreadColor, Title = "Gingerbread Color", Callback = function(v) gingerbreadColor = v end })

local function addHL(obj, color)
	local ex = obj:FindFirstChild("AegisHL")
	if ex then ex.OutlineColor = color return end
	local h = Instance.new("Highlight")
	h.Name = "AegisHL"
	h.FillTransparency = 1
	h.OutlineTransparency = 0
	h.OutlineColor = color
	h.Parent = obj
	h.Adornee = obj
end

local function clearVisual()
	for _, v in ipairs(workspace:GetDescendants()) do
		if v:IsA("Highlight") and v.Name == "AegisHL" then v:Destroy() end
	end
end

local oldAmbient = Lighting.Ambient
local oldOutdoor = Lighting.OutdoorAmbient
local oldBrightness = Lighting.Brightness
local oldFogEnd = Lighting.FogEnd
local oldFogStart = Lighting.FogStart
local customAmbientOn = false
local customAmbientColor = Color3.new(1, 1, 1)

LightingGroup:AddToggle("Fullbright", { Text = "Fullbright", Default = false, Callback = function(v) if v then Lighting.Brightness = 6 Lighting.OutdoorAmbient = Color3.new(1,1,1) else Lighting.Brightness = oldBrightness Lighting.OutdoorAmbient = oldOutdoor end end })
LightingGroup:AddToggle("NoFog", { Text = "No Fog", Default = false, Callback = function(v) if v then Lighting.FogEnd = 1000000 Lighting.FogStart = 1000000 else Lighting.FogEnd = oldFogEnd Lighting.FogStart = oldFogStart end end })
LightingGroup:AddToggle("CustomAmbient", { Text = "Custom Ambient", Default = false, Callback = function(v) customAmbientOn = v if v then Lighting.Ambient = customAmbientColor else Lighting.Ambient = oldAmbient end end }):AddColorPicker("AmbientColor", { Default = Color3.new(1,1,1), Title = "Ambient Color", Callback = function(v) customAmbientColor = v if customAmbientOn then Lighting.Ambient = v end end })

task.spawn(function()
	while task.wait(1) do
		if Library.Unloaded then break end
		if not visualEnabled then clearVisual() continue end
		clearVisual()
		local pf = workspace:FindFirstChild("Players")
		if pf then
			if showKiller and pf:FindFirstChild("Killers") then for _, k in ipairs(pf.Killers:GetChildren()) do if k:FindFirstChild("Humanoid") then addHL(k, killerColor) end end end
			if showSurvivor and pf:FindFirstChild("Survivors") then for _, s in ipairs(pf.Survivors:GetChildren()) do if s:FindFirstChild("Humanoid") then addHL(s, survivorColor) end end end
		end
		if showItems then for _, i in ipairs(workspace:GetDescendants()) do if i.Name == "Medkit" or i.Name == "BloxyCola" then addHL(i, itemColor) end end end
		if showGen then for _, g in ipairs(workspace:GetDescendants()) do if g.Name:lower():find("generator") then addHL(g, generatorColor) end end end
		if showGingerbread then pcall(function() for _, c in ipairs(workspace.Map.Ingame.CurrencyLocations:GetChildren()) do addHL(c, gingerbreadColor) end end) end
	end
end)

-- ══════════════════════════════════════
-- ANTI TAB
-- ══════════════════════════════════════
local AntiGroup = Tabs.Anti:AddLeftGroupbox("Removals")

local anti1xConn
AntiGroup:AddToggle("Anti1x", {
	Text = "Anti 1x1x1x1 Popups", Default = true,
	Callback = function(state)
		_G.no1x = state
		if anti1xConn then anti1xConn:Disconnect() anti1xConn = nil end
		if not state then return end
		local function handlePopup(p) task.wait(0.3) if firesignal and p and p:IsA("ImageButton") then pcall(function() firesignal(p.MouseButton1Click) end) end end
		local function scan(gui) if gui.Name ~= "TemporaryUI" then return end local p = gui:FindFirstChild("1x1x1x1Popup") if p then handlePopup(p) end gui.ChildAdded:Connect(function(c) if c.Name == "1x1x1x1Popup" then handlePopup(c) end end) end
		for _, ui in ipairs(LocalPlayer.PlayerGui:GetChildren()) do scan(ui) end
		anti1xConn = LocalPlayer.PlayerGui.ChildAdded:Connect(scan)
	end
})

AntiGroup:AddToggle("AntiStun", { Text = "Stun", Default = false, Callback = function(v) task.spawn(function() while v and Toggles.AntiStun and Toggles.AntiStun.Value and task.wait() do if Library.Unloaded then break end local c = LocalPlayer.Character if c and c:FindFirstChild("SpeedMultipliers") then local s = c.SpeedMultipliers:FindFirstChild("Stunned") if s then s.Value = 1.2 end end end end) end })
AntiGroup:AddToggle("AntiSlow", { Text = "Slow", Default = false, Callback = function(v) task.spawn(function() while v and Toggles.AntiSlow and Toggles.AntiSlow.Value and task.wait() do if Library.Unloaded then break end local c = LocalPlayer.Character if c and c:FindFirstChild("SpeedMultipliers") then for _, m in ipairs(c.SpeedMultipliers:GetChildren()) do if m.Value < 1 then m.Value = 1.2 end end end end end) end })
AntiGroup:AddToggle("AntiBlind", { Text = "Blindness", Default = false, Callback = function(v) task.spawn(function() while v and Toggles.AntiBlind and Toggles.AntiBlind.Value and task.wait() do if Library.Unloaded then break end local b = Lighting:FindFirstChild("BlindnessBlur") if b then b:Destroy() end end end) end })
AntiGroup:AddToggle("AntiSubspace", { Text = "Subspace", Default = false, Callback = function(v) task.spawn(function() while v and Toggles.AntiSubspace and Toggles.AntiSubspace.Value and task.wait() do if Library.Unloaded then break end local a = Lighting:FindFirstChild("SubspaceVFXBlur") local b = Lighting:FindFirstChild("SubspaceVFXColorCorrection") if a then a:Destroy() end if b then b:Destroy() end end end) end })

-- ══════════════════════════════════════
-- UI SETTINGS TAB
-- ══════════════════════════════════════
local MenuGroup = Tabs["UI Settings"]:AddLeftGroupbox("Menu", "wrench")

MenuGroup:AddToggle("KeybindMenuOpen", { Default = Library.KeybindFrame.Visible, Text = "Open Keybind Menu", Callback = function(v) Library.KeybindFrame.Visible = v end })
MenuGroup:AddToggle("ShowCustomCursor", { Text = "Custom Cursor", Default = true, Callback = function(v) Library.ShowCustomCursor = v end })
MenuGroup:AddDropdown("NotificationSide", { Values = {"Left","Right"}, Default = "Right", Text = "Notification Side", Callback = function(v) Library:SetNotifySide(v) end })
MenuGroup:AddDivider()
MenuGroup:AddLabel("Menu bind"):AddKeyPicker("MenuKeybind", { Default = "RightShift", NoUI = true, Text = "Menu keybind" })
MenuGroup:AddButton("Unload", function() Library:Unload() end)

Library.ToggleKeybind = Options.MenuKeybind

Library:OnUnload(function()
	clearVisual()
	clearPathVisualizer()
	clearTargetHighlight()
	stopSprintLoop()
	stopAutoAbility()
	stopHoldingF()
	releaseKey(Enum.KeyCode.F)
	releaseKey(Enum.KeyCode.LeftShift)
	if debugGui then debugGui:Destroy() end
	Lighting.Ambient = oldAmbient
	Lighting.OutdoorAmbient = oldOutdoor
	Lighting.Brightness = oldBrightness
	Lighting.FogEnd = oldFogEnd
	Lighting.FogStart = oldFogStart
	print("Aegis Unloaded!")
end)

ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({ "MenuKeybind" })
ThemeManager:SetFolder("Aegis")
SaveManager:SetFolder("Aegis/Foreskin")
SaveManager:BuildConfigSection(Tabs["UI Settings"])
ThemeManager:ApplyToTab(Tabs["UI Settings"])
SaveManager:LoadAutoloadConfig()

Library:Notify("Aegis loaded successfully!", 5)
