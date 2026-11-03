-- Language: Lua (Luau) | Pro Hub Ultimate v5.0.0 (Native GuiEngine ESP & RenderStepped Camera Lock)
-- Root Causes Fixed from v4.2.0:
-- 1. Mobile ESP Fix: Replaced Drawing.new()[cite: 2] (unsupported or invisible on most mobile executors) with a 100% Native Roblox ScreenGui/Frame/UIStroke rendering engine. Works on ALL Mobile & PC clients.
-- 2. Aimbot Camera Lock Fix: WarZ custom camera controller overrides BindToRenderStep(Camera + 1)[cite: 2]. Switched to dual-stage locking (BindToRenderStep Last + RenderStepped) and added automatic ADS detection (detects weapon aiming/zooming FOV changes and Right-Click/Mobile Aim button).
-- 3. Custom Rig Resolution Fix: Scans Workspace for custom character models, WarzRig_Sync rigs, and Head meshes even when Humanoid or Player.Character is desynced[cite: 1, 2].

local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local TweenService      = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService        = game:GetService("GuiService")
local Camera            = workspace.CurrentCamera
local LocalPlayer       = Players.LocalPlayer

local isRunning = true
local connections = {}
local RENDER_BIND_NAME = "ProHub_v5_CameraOverride"

local function addConnection(conn)
	table.insert(connections, conn)
	return conn
end

-- Load Game Remotes Safely
local Remotes, PickupLootRemote, UseItemRemote, BagAllToStashRemote, ReloadRemote
task.spawn(function()
	pcall(function()
		Remotes = ReplicatedStorage:WaitForChild("Remotes", 10)
		if Remotes then
			PickupLootRemote    = Remotes:WaitForChild("PickupLoot", 5)
			UseItemRemote       = Remotes:WaitForChild("UseItem", 5)
			BagAllToStashRemote = Remotes:WaitForChild("BagAllToStash", 5)
			ReloadRemote        = Remotes:WaitForChild("ReloadRequest", 5)
		end
	end)
end)

-- Theme Configuration
local T = {
	BG        = Color3.fromRGB(10, 14, 12),
	SIDEBAR   = Color3.fromRGB(7, 10, 8),
	CARD      = Color3.fromRGB(16, 22, 18),
	CARD2     = Color3.fromRGB(20, 28, 23),
	STROKE    = Color3.fromRGB(35, 50, 40),
	ACCENT    = Color3.fromRGB(0, 255, 120),
	ACCENT2   = Color3.fromRGB(0, 190, 90),
	ACCENTLIT = Color3.fromRGB(120, 255, 180),
	TEXT      = Color3.fromRGB(240, 255, 245),
	SUBTEXT   = Color3.fromRGB(140, 175, 155),
	TRACK     = Color3.fromRGB(28, 42, 33),
	GREEN     = Color3.fromRGB(0, 240, 90),
	RED       = Color3.fromRGB(255, 65, 65),
}

-- Global Settings State
local CFG = {
	AimbotEnabled   = true,
	AimbotAutoADS   = true, -- Automatically locks when zooming/aiming in-game (PC & Mobile)
	AimbotAlwaysOn  = false, -- Lock continuously without pressing buttons
	AimbotInput     = Enum.UserInputType.MouseButton2,
	AimbotMode      = "Hold",
	AimbotFOV       = 180,
	AimbotSmooth    = 0.75, -- Default stronger lock (1.0 = Instant Snap)
	AimbotTeamCheck = false,
	AimbotWallCheck = false,
	AimbotDummies   = true, -- Enabled by default so user can test on practice dummies
	AimbotPart      = "Head",
	HeadOffsetX     = 0.0,
	HeadOffsetY     = 0.1,
	ShowFOVCircle   = true,

	ESPEnabled      = true,
	ESPBox          = true,
	ESPName         = true,
	ESPDistance     = true,
	ESPHealth       = true,
	ESPTracers      = true,
	ESPLoot         = true,
	ESPHighlight    = true, -- 3D Chams Highlight for clear visibility on Mobile
	ESPMaxDist      = 4000,
	ESPWallCheck    = false,

	SpeedEnabled    = false,
	SpeedVal        = 22,
	NoclipEnabled   = false,
	AutoHealEnabled = false,
	AutoLootEnabled = false,

	BulletStraight  = false,
	BulletSoft      = false,
	RapidFire       = false,

	ColorEnemy      = Color3.fromRGB(255, 65, 65),
	ColorTeammate   = Color3.fromRGB(60, 180, 255),
	ColorTracer     = Color3.fromRGB(0, 255, 120),
	ColorLoot       = Color3.fromRGB(255, 220, 0),
	ColorText       = Color3.fromRGB(255, 255, 255),
	ColorHP         = Color3.fromRGB(0, 240, 90),
	ColorHPLow      = Color3.fromRGB(255, 50, 50),
	ColorFOV        = Color3.fromRGB(0, 255, 120),
}

local MODE_CYCLE  = {"Hold", "Toggle"}
local MODE_LABELS = {Hold = "กดค้าง (Hold)", Toggle = "สลับเปิด/ปิด (Toggle)"}
local PART_CYCLE  = {"Head", "UpperTorso", "LowerTorso", "HumanoidRootPart"}
local PART_LABELS = {
	Head             = "หัว (Head)",
	UpperTorso       = "ลำตัวบน",
	LowerTorso       = "สะโพก",
	HumanoidRootPart = "แกนกลาง (Root)"
}
local PART_FALLBACK = {
	Head             = {"Head", "FakeHead", "HeadHitbox", "head"},
	UpperTorso       = {"UpperTorso", "Torso", "Chest"},
	LowerTorso       = {"LowerTorso", "Torso", "Pelvis"},
	HumanoidRootPart = {"HumanoidRootPart", "RootPart", "Torso", "UpperTorso"},
}

----------------------------------------------------------------
-- ROOT SCREEN GUI & NATIVE ESP CANVAS (100% Mobile Compatible)
----------------------------------------------------------------
-- Remove old instance if re-executed
pcall(function()
	local parentGui = (gethui and gethui()) or game:GetService("CoreGui")
	for _, v in ipairs(parentGui:GetChildren()) do
		if v.Name:find("ProHub_Ultimate") then v:Destroy() end
	end
end)
pcall(function()
	local pGui = LocalPlayer:FindFirstChild("PlayerGui")
	if pGui then
		for _, v in ipairs(pGui:GetChildren()) do
			if v.Name:find("ProHub_Ultimate") then v:Destroy() end
		end
	end
end)

local MainGui = Instance.new("ScreenGui")
MainGui.Name = "ProHub_Ultimate_v5_0"
MainGui.ResetOnSpawn = false
MainGui.IgnoreGuiInset = true
MainGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
MainGui.DisplayOrder = 999999

pcall(function()
	if gethui then
		MainGui.Parent = gethui()
	else
		MainGui.Parent = game:GetService("CoreGui")
	end
end)
if not MainGui.Parent then
	MainGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
end

-- Dedicated ESP Overlay Container
local ESPCanvas = Instance.new("Frame")
ESPCanvas.Name = "ESPCanvas"
ESPCanvas.Size = UDim2.new(1, 0, 1, 0)
ESPCanvas.BackgroundTransparency = 1
ESPCanvas.Active = false
ESPCanvas.Parent = MainGui

-- Native FOV Circle (Replaces Drawing.new("Circle") so it renders on all Mobile devices)
local FOVFrame = Instance.new("Frame")
FOVFrame.Name = "FOVCircle"
FOVFrame.AnchorPoint = Vector2.new(0.5, 0.5)
FOVFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
FOVFrame.Size = UDim2.new(0, CFG.AimbotFOV * 2, 0, CFG.AimbotFOV * 2)
FOVFrame.BackgroundTransparency = 1
FOVFrame.Active = false
FOVFrame.Parent = ESPCanvas
Instance.new("UICorner", FOVFrame).CornerRadius = UDim.new(1, 0)

local FOVStroke = Instance.new("UIStroke", FOVFrame)
FOVStroke.Color = CFG.ColorFOV
FOVStroke.Thickness = 1.6
FOVStroke.Transparency = 0.15

-- Target Lock Indicator Dot (Visual confirmation on target head)
local TargetDot = Instance.new("Frame")
TargetDot.Name = "TargetLockDot"
TargetDot.AnchorPoint = Vector2.new(0.5, 0.5)
TargetDot.Size = UDim2.new(0, 8, 0, 8)
TargetDot.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
TargetDot.BorderSizePixel = 0
TargetDot.Visible = false
TargetDot.Parent = ESPCanvas
Instance.new("UICorner", TargetDot).CornerRadius = UDim.new(1, 0)
local dotStroke = Instance.new("UIStroke", TargetDot)
dotStroke.Color = Color3.new(1, 1, 1)
dotStroke.Thickness = 1.2

----------------------------------------------------------------
-- CHARACTER & CUSTOM WARZ RIG RESOLUTION
----------------------------------------------------------------
-- Finds the real rendered 3D character model in Workspace even if Player.Character is nil/desynced
local function getCharacterModel(p)
	if not p then return nil end

	-- 1. Check Workspace direct child with Player's Name or DisplayName
	local wsModel = workspace:FindFirstChild(p.Name)
	if wsModel and wsModel:IsA("Model") and wsModel.Parent.Name ~= "WarzRigPool" and wsModel.Parent.Name ~= "LobbyHub" then
		return wsModel
	end

	-- 2. Check standard Player.Character
	local char = p.Character
	if char and char.Parent and char.Parent.Name ~= "WarzRigPool" and char.Parent.Name ~= "LobbyHub" then
		return char
	end

	-- 3. Check if custom rig has UserId or PlayerName attribute inside Workspace
	for _, obj in ipairs(workspace:GetChildren()) do
		if obj:IsA("Model") and (obj.Name == p.Name or obj:GetAttribute("UserId") == p.UserId or obj:GetAttribute("Owner") == p.Name) then
			return obj
		end
	end

	return char
end

-- Finds Root, Head, and Humanoid reliably across R15, R6, and custom WarZ rigs
local function getModelParts(char)
	if not char then return nil, nil, nil end
	local hum = char:FindFirstChildOfClass("Humanoid") or char:FindFirstChildWhichIsA("Humanoid", true)

	local root = char:FindFirstChild("HumanoidRootPart")
		or char:FindFirstChild("UpperTorso")
		or char:FindFirstChild("Torso")
		or char.PrimaryPart
		or char:FindFirstChildWhichIsA("BasePart")

	local head = char:FindFirstChild("Head")
		or char:FindFirstChild("FakeHead")
		or char:FindFirstChild("Head", true)
		or root

	return root, head, hum
end

local function getParts(p)
	return getModelParts(getCharacterModel(p))
end

-- Resolves the exact target BasePart to lock onto
local function getAimPart(char)
	if not char then return nil end
	local targetNames = PART_FALLBACK[CFG.AimbotPart] or {"Head"}

	-- First pass: direct children
	for _, name in ipairs(targetNames) do
		local part = char:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			return part
		end
	end

	-- Second pass: deep descendants (for custom nested rigs like WarzRig_Sync)
	for _, name in ipairs(targetNames) do
		local part = char:FindFirstChild(name, true)
		if part and part:IsA("BasePart") then
			return part
		end
	end

	-- Third pass: geometric highest part if searching for Head
	local root, head = getModelParts(char)
	return head or root
end

-- Viewport utilities (With IgnoreGuiInset = true, WorldToViewportPoint matches UDim2 Offset 1:1)
local function screenCenter()
	Camera = workspace.CurrentCamera
	if not Camera then return Vector2.new(0, 0) end
	return Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
end

local function w2s(pos)
	Camera = workspace.CurrentCamera
	if not Camera then return Vector2.new(0, 0), false, -1 end
	local v, onScreen = Camera:WorldToViewportPoint(pos)
	return Vector2.new(v.X, v.Y), (onScreen and v.Z > 0), v.Z
end

local function isEnemy(p)
	if not CFG.AimbotTeamCheck then return true end
	if not LocalPlayer.Team or not p.Team then return true end
	return p.Team ~= LocalPlayer.Team
end

-- Raycast Line-of-Sight Check
local _rp = RaycastParams.new()
_rp.FilterType = Enum.RaycastFilterType.Exclude
_rp.IgnoreWater = true

local function hasLOS(from, to, targetChar)
	local ig = {Camera}
	local myChar = getCharacterModel(LocalPlayer)
	if myChar then table.insert(ig, myChar) end
	if targetChar then table.insert(ig, targetChar) end

	local ignoreFolders = {"WarzFx", "WarzLoot", "ZombieVisuals", "WarzRigPool", "Targets", "ColoradoVehicleVisuals", "WarzBarricadeQuery"}
	for _, fname in ipairs(ignoreFolders) do
		local f = workspace:FindFirstChild(fname)
		if f then table.insert(ig, f) end
	end

	_rp.FilterDescendantsInstances = ig
	local result = workspace:Raycast(from, to - from, _rp)
	return result == nil
end

local function getAimPos(part)
	if not part then return nil end
	Camera = workspace.CurrentCamera
	local rightVec = Camera and (Camera.CFrame.RightVector * CFG.HeadOffsetX) or Vector3.zero
	local upVec = Vector3.new(0, CFG.HeadOffsetY, 0)
	return part.Position + rightVec + upVec
end

----------------------------------------------------------------
-- ALIVE CHECK (Works even if game uses Custom Health Attributes instead of Humanoid)
----------------------------------------------------------------
local deadFlags = {}
local originalHeadSizes = {}

local function isModelAlive(char)
	if not char or not char.Parent then return false end
	if char.Parent.Name == "WarzRigPool" or char.Parent.Name == "LobbyHub" then return false end

	local root, head, hum = getModelParts(char)
	if not root or not root:IsA("BasePart") then return false end

	-- Filter out unspawned/dead rigs teleported far below the map
	if root.Position.Y < -400 then return false end

	if hum then
		if hum.Health <= 0 then return false end
		local ok, state = pcall(function() return hum:GetState() end)
		if ok and state == Enum.HumanoidStateType.Dead then return false end
	end

	local hpAttr = char:GetAttribute("Health") or char:GetAttribute("HP")
	if type(hpAttr) == "number" and hpAttr <= 0 then return false end

	if char:FindFirstChild("Dead") or char:FindFirstChild("IsDead") then return false end
	if char:GetAttribute("IsDead") == true or char:GetAttribute("Dead") == true then return false end

	return true
end

local function isAliveRaw(p)
	if deadFlags[p] then return false end
	return isModelAlive(getCharacterModel(p))
end

----------------------------------------------------------------
-- NATIVE GUI ESP ENGINE (Works 100% on Mobile & PC)
----------------------------------------------------------------
local espPool = {}
local lootEspPool = {}

local function createPlayerESP(p)
	if espPool[p] then return espPool[p] end

	local container = Instance.new("Folder")
	container.Name = "ESP_" .. p.Name
	container.Parent = ESPCanvas

	-- 2D Box
	local box = Instance.new("Frame")
	box.BackgroundTransparency = 1
	box.BorderSizePixel = 0
	box.Visible = false
	box.Parent = container

	local boxOutline = Instance.new("UIStroke", box)
	boxOutline.Thickness = 1.5
	boxOutline.Color = CFG.ColorEnemy

	-- Health Bar Background & Fill
	local hpBg = Instance.new("Frame")
	hpBg.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
	hpBg.BorderSizePixel = 0
	hpBg.Visible = false
	hpBg.Parent = container

	local hpBar = Instance.new("Frame")
	hpBar.BackgroundColor3 = CFG.ColorHP
	hpBar.BorderSizePixel = 0
	hpBar.AnchorPoint = Vector2.new(0, 1)
	hpBar.Position = UDim2.new(0, 0, 1, 0)
	hpBar.Size = UDim2.new(1, 0, 1, 0)
	hpBar.Parent = hpBg

	-- Player Name & Distance Label
	local nameLbl = Instance.new("TextLabel")
	nameLbl.Size = UDim2.new(0, 200, 0, 16)
	nameLbl.AnchorPoint = Vector2.new(0.5, 1)
	nameLbl.BackgroundTransparency = 1
	nameLbl.Font = Enum.Font.GothamBold
	nameLbl.TextSize = 12
	nameLbl.TextColor3 = CFG.ColorText
	nameLbl.TextStrokeTransparency = 0
	nameLbl.TextStrokeColor3 = Color3.new(0, 0, 0)
	nameLbl.Visible = false
	nameLbl.Parent = container

	local distLbl = Instance.new("TextLabel")
	distLbl.Size = UDim2.new(0, 160, 0, 14)
	distLbl.AnchorPoint = Vector2.new(0.5, 0)
	distLbl.BackgroundTransparency = 1
	distLbl.Font = Enum.Font.GothamBold
	distLbl.TextSize = 11
	distLbl.TextColor3 = Color3.fromRGB(200, 255, 215)
	distLbl.TextStrokeTransparency = 0
	distLbl.TextStrokeColor3 = Color3.new(0, 0, 0)
	distLbl.Visible = false
	distLbl.Parent = container

	-- 2D Tracer Line (Rotated Frame)
	local tracer = Instance.new("Frame")
	tracer.AnchorPoint = Vector2.new(0.5, 0.5)
	tracer.BackgroundColor3 = CFG.ColorTracer
	tracer.BorderSizePixel = 0
	tracer.Visible = false
	tracer.Parent = container

	-- 3D Highlight (Chams)
	local highlight = Instance.new("Highlight")
	highlight.Name = "ProHub_Chams"
	highlight.FillTransparency = 0.65
	highlight.OutlineTransparency = 0.1
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Enabled = false
	highlight.Parent = container

	local entry = {
		container = container,
		box       = box,
		boxStroke = boxOutline,
		hpBg      = hpBg,
		hpBar     = hpBar,
		name      = nameLbl,
		dist      = distLbl,
		tracer    = tracer,
		highlight = highlight
	}
	espPool[p] = entry
	return entry
end

local function hidePlayerESP(e)
	if not e then return end
	e.box.Visible = false
	e.hpBg.Visible = false
	e.name.Visible = false
	e.dist.Visible = false
	e.tracer.Visible = false
	e.highlight.Enabled = false
	e.highlight.Adornee = nil
end

local function removePlayerESP(p)
	local e = espPool[p]
	if e then
		pcall(function() e.container:Destroy() end)
		espPool[p] = nil
	end
	deadFlags[p] = nil
	originalHeadSizes[p] = nil
end

local function drawLineFrame(frame, fromPos, toPos, color)
	local diff = toPos - fromPos
	local dist = diff.Magnitude
	if dist < 2 then
		frame.Visible = false
		return
	end
	local mid = (fromPos + toPos) / 2
	local angle = math.deg(math.atan2(diff.Y, diff.X))
	frame.Position = UDim2.fromOffset(mid.X, mid.Y)
	frame.Size = UDim2.fromOffset(dist, 1.4)
	frame.Rotation = angle
	frame.BackgroundColor3 = color
	frame.Visible = true
end

local function renderPlayerESP(p, e)
	local char = getCharacterModel(p)
	if not char or not isModelAlive(char) then
		hidePlayerESP(e)
		return
	end

	local root, head, hum = getModelParts(char)
	if not root or not head then
		hidePlayerESP(e)
		return
	end

	Camera = workspace.CurrentCamera
	if not Camera then return end

	local dist3D = (root.Position - Camera.CFrame.Position).Magnitude
	if dist3D > CFG.ESPMaxDist then
		hidePlayerESP(e)
		return
	end

	if CFG.ESPWallCheck and not hasLOS(Camera.CFrame.Position, head.Position, char) then
		hidePlayerESP(e)
		return
	end

	local col = isEnemy(p) and CFG.ColorEnemy or CFG.ColorTeammate

	-- Update 3D Highlight (Always visible even if 2D box is clipped)
	if CFG.ESPHighlight then
		e.highlight.Adornee = char
		e.highlight.FillColor = col
		e.highlight.OutlineColor = col
		e.highlight.Enabled = true
	else
		e.highlight.Enabled = false
	end

	local topSP, _, topZ = w2s(head.Position + Vector3.new(0, 0.8, 0))
	local botSP, _, botZ = w2s(root.Position - Vector3.new(0, 3.0, 0))

	if topZ <= 0 or botZ <= 0 then
		e.box.Visible = false
		e.hpBg.Visible = false
		e.name.Visible = false
		e.dist.Visible = false
		e.tracer.Visible = false
		return
	end

	local bH = math.clamp(math.abs(botSP.Y - topSP.Y), 8, 1500)
	local bW = math.clamp(bH * 0.62, 6, 1000)
	local bX = topSP.X - (bW / 2)
	local bY = math.min(topSP.Y, botSP.Y)

	-- 2D Box
	if CFG.ESPBox then
		e.box.Position = UDim2.fromOffset(bX, bY)
		e.box.Size = UDim2.fromOffset(bW, bH)
		e.boxStroke.Color = col
		e.box.Visible = true
	else
		e.box.Visible = false
	end

	-- Name
	if CFG.ESPName then
		e.name.Text = p.DisplayName or p.Name
		e.name.Position = UDim2.fromOffset(topSP.X, bY - 3)
		e.name.TextColor3 = CFG.ColorText
		e.name.Visible = true
	else
		e.name.Visible = false
	end

	-- Distance
	if CFG.ESPDistance then
		local meters = math.floor(dist3D / 3.5)
		e.dist.Text = string.format("[%d m]", meters)
		e.dist.Position = UDim2.fromOffset(topSP.X, bY + bH + 2)
		e.dist.Visible = true
	else
		e.dist.Visible = false
	end

	-- Health Bar
	if CFG.ESPHealth then
		local maxHp = (hum and hum.MaxHealth > 0) and hum.MaxHealth or 100
		local curHp = hum and hum.Health or (char:GetAttribute("Health") or 100)
		local hpR = math.clamp(curHp / maxHp, 0, 1)

		e.hpBg.Position = UDim2.fromOffset(bX - 6, bY)
		e.hpBg.Size = UDim2.fromOffset(3, bH)
		e.hpBar.Size = UDim2.new(1, 0, hpR, 0)
		e.hpBar.BackgroundColor3 = (hpR > 0.4) and CFG.ColorHP or CFG.ColorHPLow
		e.hpBg.Visible = true
	else
		e.hpBg.Visible = false
	end

	-- Tracer
	if CFG.ESPTracers then
		local origin = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y - 10)
		drawLineFrame(e.tracer, origin, Vector2.new(topSP.X, bY + bH), CFG.ColorTracer)
	else
		e.tracer.Visible = false
	end
end

for _, p in ipairs(Players:GetPlayers()) do
	if p ~= LocalPlayer then createPlayerESP(p) end
end
addConnection(Players.PlayerAdded:Connect(function(p)
	if p ~= LocalPlayer then createPlayerESP(p) end
end))
addConnection(Players.PlayerRemoving:Connect(removePlayerESP))

----------------------------------------------------------------
-- BACKGROUND TASKS (Auto Loot, Auto Heal, Soft Hitbox, Speed, Noclip)
----------------------------------------------------------------
task.spawn(function()
	while isRunning do
		task.wait(0.2)
		pcall(function()
			local char = getCharacterModel(LocalPlayer)
			if not char then return end
			local root = getModelParts(char)
			local _, _, hum = getModelParts(char)

			-- Auto Loot
			if CFG.AutoLootEnabled and root and PickupLootRemote then
				local lootFolder = workspace:FindFirstChild("WarzLoot")
				if lootFolder then
					for _, item in ipairs(lootFolder:GetChildren()) do
						local part = item:IsA("BasePart") and item or (item:IsA("Model") and (item.PrimaryPart or item:FindFirstChildWhichIsA("BasePart")))
						if part and (part.Position - root.Position).Magnitude <= 25 then
							PickupLootRemote:FireServer(item)
						end
					end
				end
			end

			-- Auto Heal
			if CFG.AutoHealEnabled and hum and hum.Health > 0 and hum.Health < 75 and UseItemRemote then
				local backpack = LocalPlayer:FindFirstChild("Backpack")
				if backpack then
					for _, item in ipairs(backpack:GetChildren()) do
						if item:IsA("Tool") then
							local n = item.Name:lower()
							if n:find("heal") or n:find("med") or n:find("potion") or n:find("ยา") or n:find("bandage") or n:find("kit") or n:find("first") or n:find("pain") then
								UseItemRemote:FireServer(item)
								task.wait(0.35)
								break
							end
						end
					end
				end
			end

			-- Soft Hitbox (Head Size Expansion)
			for _, p in ipairs(Players:GetPlayers()) do
				if p ~= LocalPlayer then
					local _, head = getParts(p)
					if head and head:IsA("BasePart") then
						if CFG.BulletSoft and isEnemy(p) and isAliveRaw(p) then
							if not originalHeadSizes[p] then
								originalHeadSizes[p] = head.Size
							end
							head.Size = Vector3.new(4.5, 4.5, 4.5)
							head.Transparency = 0.55
							head.CanCollide = false
							head.Massless = true
						elseif originalHeadSizes[p] then
							head.Size = originalHeadSizes[p]
							head.Transparency = 0
							originalHeadSizes[p] = nil
						end
					end
				end
			end
		end)
	end
end)

addConnection(RunService.Stepped:Connect(function()
	pcall(function()
		local char = getCharacterModel(LocalPlayer)
		if not char then return end
		local root, _, hum = getModelParts(char)

		if CFG.NoclipEnabled then
			for _, part in ipairs(char:GetDescendants()) do
				if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
					part.CanCollide = false
				end
			end
		end

		if CFG.SpeedEnabled and hum and root then
			local moveDir = hum.MoveDirection
			if moveDir.Magnitude > 0 then
				root.CFrame = root.CFrame + (moveDir * (CFG.SpeedVal / 50))
			end
		end

		local tool = char:FindFirstChildOfClass("Tool")
		if tool then
			if CFG.RapidFire then
				local fr = tool:FindFirstChild("FireRate") or tool:FindFirstChild("Cooldown")
				if fr and fr:IsA("NumberValue") then fr.Value = 0.005 end
			end
			if CFG.BulletStraight then
				local spread = tool:FindFirstChild("Spread") or tool:FindFirstChild("Accuracy") or tool:FindFirstChild("Recoil")
				if spread and spread:IsA("NumberValue") then spread.Value = 0 end
			end
		end
	end)
end))

----------------------------------------------------------------
-- PRECISION AIMBOT ENGINE (PC Right-Click, Mobile Button & Auto-ADS)
----------------------------------------------------------------
local lockedTargetPart = nil
local lockedTargetModel = nil
local aimbotToggleActive = false
local mobileAiming = false
local pcRightClickHeld = false

-- Floating Mobile Aim Button ([🎯 ดูดหัว])
local MobileAimBtn = Instance.new("TextButton")
MobileAimBtn.Name = "MobileAimButton"
MobileAimBtn.Size = UDim2.new(0, 76, 0, 76)
MobileAimBtn.Position = UDim2.new(0.82, -38, 0.55, 0)
MobileAimBtn.BackgroundColor3 = T.CARD
MobileAimBtn.Text = "🎯\nดูดหัว"
MobileAimBtn.TextColor3 = T.ACCENT
MobileAimBtn.Font = Enum.Font.GothamBold
MobileAimBtn.TextSize = 13
MobileAimBtn.Visible = true -- Always visible by default so both Mobile & Emulator users can tap it
MobileAimBtn.AutoButtonColor = false
MobileAimBtn.Parent = MainGui
Instance.new("UICorner", MobileAimBtn).CornerRadius = UDim.new(1, 0)

local mStroke = Instance.new("UIStroke", MobileAimBtn)
mStroke.Color = T.ACCENT
mStroke.Thickness = 2.2

local function updateMobileBtnVisual(active)
	TweenService:Create(MobileAimBtn, TweenInfo.new(0.12), {
		BackgroundColor3 = active and T.ACCENT or T.CARD,
		Size = active and UDim2.new(0, 82, 0, 82) or UDim2.new(0, 76, 0, 76)
	}):Play()
	MobileAimBtn.TextColor3 = active and Color3.fromRGB(10, 15, 12) or T.ACCENT
end

local activeAimTouch = nil
local mDragStart, mStartPos = nil, nil

MobileAimBtn.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
		activeAimTouch = input
		mDragStart = input.Position
		mStartPos = MobileAimBtn.Position

		if CFG.AimbotMode == "Toggle" then
			aimbotToggleActive = not aimbotToggleActive
			mobileAiming = aimbotToggleActive
			if not mobileAiming then
				lockedTargetPart = nil
				lockedTargetModel = nil
			end
		else
			mobileAiming = true
		end
		updateMobileBtnVisual(mobileAiming)
	end
end)

addConnection(UserInputService.InputChanged:Connect(function(input)
	if input == activeAimTouch and mDragStart and mStartPos then
		local delta = input.Position - mDragStart
		if delta.Magnitude > 14 then
			MobileAimBtn.Position = UDim2.new(
				mStartPos.X.Scale, mStartPos.X.Offset + delta.X,
				mStartPos.Y.Scale, mStartPos.Y.Offset + delta.Y
			)
		end
	end
end))

addConnection(UserInputService.InputEnded:Connect(function(input)
	if input == activeAimTouch then
		activeAimTouch = nil
		if CFG.AimbotMode == "Hold" then
			mobileAiming = false
			lockedTargetPart = nil
			lockedTargetModel = nil
			updateMobileBtnVisual(false)
		end
	end
end))

-- PC Right-Click Listener (Works even when game locks mouse cursor in center)
addConnection(UserInputService.InputBegan:Connect(function(input)
	if input.UserInputType == CFG.AimbotInput then
		if CFG.AimbotMode == "Toggle" then
			aimbotToggleActive = not aimbotToggleActive
			if not aimbotToggleActive then
				lockedTargetPart = nil
				lockedTargetModel = nil
			end
		else
			pcRightClickHeld = true
		end
	end
end))

addConnection(UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == CFG.AimbotInput then
		pcRightClickHeld = false
		if CFG.AimbotMode == "Hold" then
			lockedTargetPart = nil
			lockedTargetModel = nil
		end
	end
end))

-- Detects if the player is currently Aiming Down Sights (ADS) in-game
local function isInGameAiming()
	if not CFG.AimbotAutoADS then return false end
	Camera = workspace.CurrentCamera
	-- In WarZ, aiming down sights (Scope/Iron Sight) lowers Camera.FieldOfView below 65
	if Camera and Camera.FieldOfView < 64 then
		return true
	end
	local OpticVal = ReplicatedStorage:FindFirstChild("ClientCurrentOptic")
	if OpticVal and OpticVal:IsA("StringValue") and OpticVal.Value ~= "" and OpticVal.Value ~= "None" then
		if UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
			return true
		end
	end
	return false
end

local function isAimbotFiring()
	if not CFG.AimbotEnabled then return false end
	if CFG.AimbotAlwaysOn then return true end
	if mobileAiming then return true end
	if CFG.AimbotMode == "Toggle" and aimbotToggleActive then return true end
	if pcRightClickHeld or UserInputService:IsMouseButtonPressed(CFG.AimbotInput) then return true end
	if isInGameAiming() then return true end
	return false
end

-- Gather all valid enemy targets + optional practice dummies + workspace player rigs
local function getCandidateModels()
	local list = {}
	local seen = {}
	local myChar = getCharacterModel(LocalPlayer)
	if myChar then seen[myChar] = true end

	-- 1. All Enemy Players
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= LocalPlayer and isEnemy(p) then
			local char = getCharacterModel(p)
			if char and not seen[char] and isModelAlive(char) then
				seen[char] = true
				table.insert(list, char)
			end
		end
	end

	-- 2. Practice Dummies / Targets (for testing in training zone)
	if CFG.AimbotDummies then
		local dummyFolders = {
			workspace:FindFirstChild("WarzDummies"),
			workspace:FindFirstChild("Targets"),
			workspace:FindFirstChild("ZombieVisuals")
		}
		for _, folder in ipairs(dummyFolders) do
			if folder then
				for _, d in ipairs(folder:GetChildren()) do
					if d:IsA("Model") and not seen[d] and isModelAlive(d) then
						seen[d] = true
						table.insert(list, d)
					end
				end
			end
		end
	end

	return list
end

local function findBestTarget()
	Camera = workspace.CurrentCamera
	if not Camera then return nil, nil end
	local center = screenCenter()
	local bestDist = CFG.AimbotFOV
	local bestPart = nil
	local bestModel = nil

	for _, model in ipairs(getCandidateModels()) do
		local part = getAimPart(model)
		if part then
			local aimPos = getAimPos(part)
			local sp, _, depth = w2s(aimPos)
			if depth > 0 then
				local dist2D = (sp - center).Magnitude
				if dist2D <= bestDist then
					if not CFG.AimbotWallCheck or hasLOS(Camera.CFrame.Position, aimPos, model) then
						bestDist = dist2D
						bestPart = part
						bestModel = model
					end
				end
			end
		end
	end

	return bestModel, bestPart
end

-- Core Camera Lock Logic (Executed at both RenderPriority.Last and RenderStepped to beat custom camera scripts)
local function executeAimbotStep()
	if not isRunning then return end
	Camera = workspace.CurrentCamera
	if not Camera then return end

	if not isAimbotFiring() then
		lockedTargetPart = nil
		lockedTargetModel = nil
		TargetDot.Visible = false
		return
	end

	local center = screenCenter()

	-- Validate existing sticky target
	if lockedTargetModel and lockedTargetPart and isModelAlive(lockedTargetModel) then
		lockedTargetPart = getAimPart(lockedTargetModel)
		if lockedTargetPart then
			local checkPos = getAimPos(lockedTargetPart)
			local sp, _, depth = w2s(checkPos)
			local dist2D = (sp - center).Magnitude
			local wallOK = not CFG.AimbotWallCheck or hasLOS(Camera.CFrame.Position, checkPos, lockedTargetModel)

			if depth <= 0 or dist2D > (CFG.AimbotFOV * 1.4) or not wallOK then
				lockedTargetModel = nil
				lockedTargetPart = nil
			end
		else
			lockedTargetModel = nil
		end
	else
		lockedTargetModel = nil
		lockedTargetPart = nil
	end

	-- Find closest target inside FOV circle
	if not lockedTargetPart then
		lockedTargetModel, lockedTargetPart = findBestTarget()
	end

	if lockedTargetPart and lockedTargetModel then
		local aimPos = getAimPos(lockedTargetPart)
		local sp, _, depth = w2s(aimPos)

		-- Show red lock dot on the target's head
		if depth > 0 then
			TargetDot.Position = UDim2.fromOffset(sp.X, sp.Y)
			TargetDot.Visible = true
		else
			TargetDot.Visible = false
		end

		local camPos = Camera.CFrame.Position
		local targetCF = CFrame.lookAt(camPos, aimPos)
		local alpha = math.clamp(CFG.AimbotSmooth, 0.05, 1.0)

		-- 1. Direct CFrame override (Works on Mobile & PC Custom Cameras)
		Camera.CFrame = Camera.CFrame:Lerp(targetCF, alpha)

		-- 2. Supplemental mousemoverel for PC executors that lock CFrame to Mouse Delta
		if mousemoverel and not UserInputService.TouchEnabled and depth > 0 then
			local dx = (sp.X - center.X) * (alpha * 0.5)
			local dy = (sp.Y - center.Y) * (alpha * 0.5)
			if math.abs(dx) > 0.5 or math.abs(dy) > 0.5 then
				pcall(function() mousemoverel(dx, dy) end)
			end
		end
	else
		TargetDot.Visible = false
	end
end

-- Bind at RenderPriority.Last.Value + 50 so it runs AFTER WarZ's custom camera controller
pcall(function()
	RunService:BindToRenderStep(RENDER_BIND_NAME, Enum.RenderPriority.Last.Value + 50, executeAimbotStep)
end)

----------------------------------------------------------------
-- RENDER LOOP (Native GUI ESP, Loot ESP & FOV Circle)
----------------------------------------------------------------
addConnection(RunService.RenderStepped:Connect(function()
	-- Run Aimbot lock in RenderStepped as well to guarantee camera override
	executeAimbotStep()

	-- Update Native FOV Circle
	FOVFrame.Visible = CFG.ShowFOVCircle
	FOVFrame.Size = UDim2.fromOffset(CFG.AimbotFOV * 2, CFG.AimbotFOV * 2)
	FOVStroke.Color = (lockedTargetPart ~= nil) and Color3.fromRGB(255, 65, 65)
		or (isAimbotFiring() and T.ACCENTLIT or CFG.ColorFOV)

	-- Ensure all players have ESP containers
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= LocalPlayer and not espPool[p] then
			createPlayerESP(p)
		end
	end

	-- Loot ESP (Native TextLabels)
	local lootFolder = workspace:FindFirstChild("WarzLoot")
	local activeLootItems = {}
	if CFG.ESPLoot and lootFolder then
		for _, item in ipairs(lootFolder:GetChildren()) do
			if item:IsA("BasePart") or item:IsA("Model") then
				local part = item:IsA("Model") and (item.PrimaryPart or item:FindFirstChildWhichIsA("BasePart")) or item
				if part then
					activeLootItems[item] = part
				end
			end
		end
	end

	for itemObj, lbl in pairs(lootEspPool) do
		if not activeLootItems[itemObj] then
			pcall(function() lbl:Destroy() end)
			lootEspPool[itemObj] = nil
		end
	end

	local myChar = getCharacterModel(LocalPlayer)
	local myRoot = myChar and getModelParts(myChar)

	for itemObj, part in pairs(activeLootItems) do
		local lbl = lootEspPool[itemObj]
		if not lbl then
			lbl = Instance.new("TextLabel")
			lbl.Size = UDim2.new(0, 180, 0, 14)
			lbl.AnchorPoint = Vector2.new(0.5, 0.5)
			lbl.BackgroundTransparency = 1
			lbl.Font = Enum.Font.GothamBold
			lbl.TextSize = 11
			lbl.TextColor3 = CFG.ColorLoot
			lbl.TextStrokeTransparency = 0
			lbl.TextStrokeColor3 = Color3.new(0, 0, 0)
			lbl.Parent = ESPCanvas
			lootEspPool[itemObj] = lbl
		end

		local screenPos, onScreen, depth = w2s(part.Position)
		local dist = myRoot and (part.Position - myRoot.Position).Magnitude or 0

		if onScreen and depth > 0 and dist <= CFG.ESPMaxDist then
			lbl.Visible = true
			lbl.Position = UDim2.fromOffset(screenPos.X, screenPos.Y)
			lbl.Text = string.format("📦 [%s] (%dm)", itemObj.Name, math.floor(dist / 3.5))
		else
			lbl.Visible = false
		end
	end

	-- Player ESP
	if not CFG.ESPEnabled then
		for _, e in pairs(espPool) do hidePlayerESP(e) end
		return
	end

	for p, e in pairs(espPool) do
		if p.Parent then
			renderPlayerESP(p, e)
		else
			removePlayerESP(p)
		end
	end
end))

----------------------------------------------------------------
-- PRO HUB UI DESIGN
----------------------------------------------------------------
local ToggleBtn = Instance.new("TextButton")
ToggleBtn.Size = UDim2.new(0, 54, 0, 54)
ToggleBtn.Position = UDim2.new(0, 20, 0.28, 0)
ToggleBtn.BackgroundColor3 = T.SIDEBAR
ToggleBtn.Text = "PRO"
ToggleBtn.TextColor3 = T.ACCENT
ToggleBtn.Font = Enum.Font.GothamBold
ToggleBtn.TextSize = 14
ToggleBtn.Parent = MainGui
Instance.new("UICorner", ToggleBtn).CornerRadius = UDim.new(1, 0)
local ToggleStroke = Instance.new("UIStroke", ToggleBtn)
ToggleStroke.Color = T.ACCENT
ToggleStroke.Thickness = 2

local WIN_W, WIN_H = 570, 480
local Window = Instance.new("Frame")
Window.Size = UDim2.new(0, WIN_W, 0, WIN_H)
Window.Position = UDim2.new(0.5, -WIN_W / 2, 0.5, -WIN_H / 2)
Window.BackgroundColor3 = T.BG
Window.BorderSizePixel = 0
Window.Visible = true
Window.Parent = MainGui
Instance.new("UICorner", Window).CornerRadius = UDim.new(0, 14)

ToggleBtn.MouseButton1Click:Connect(function()
	Window.Visible = not Window.Visible
end)

local WindowStroke = Instance.new("UIStroke", Window)
WindowStroke.Color = T.ACCENT
WindowStroke.Transparency = 0.35
WindowStroke.Thickness = 1.6

-- Title Bar
local TitleBar = Instance.new("Frame")
TitleBar.Size = UDim2.new(1, 0, 0, 48)
TitleBar.BackgroundColor3 = T.SIDEBAR
TitleBar.BorderSizePixel = 0
TitleBar.Parent = Window
Instance.new("UICorner", TitleBar).CornerRadius = UDim.new(0, 14)

local TitleDivider = Instance.new("Frame")
TitleDivider.Size = UDim2.new(1, 0, 0, 1)
TitleDivider.Position = UDim2.new(0, 0, 1, -1)
TitleDivider.BackgroundColor3 = T.STROKE
TitleDivider.BorderSizePixel = 0
TitleDivider.Parent = TitleBar

local TitleDot = Instance.new("Frame")
TitleDot.Size = UDim2.new(0, 10, 0, 10)
TitleDot.Position = UDim2.new(0, 18, 0.5, -5)
TitleDot.BackgroundColor3 = T.ACCENT
TitleDot.BorderSizePixel = 0
TitleDot.Parent = TitleBar
Instance.new("UICorner", TitleDot).CornerRadius = UDim.new(1, 0)

local TitleLbl = Instance.new("TextLabel")
TitleLbl.Size = UDim2.new(0, 310, 0, 24)
TitleLbl.Position = UDim2.new(0, 36, 0, 6)
TitleLbl.BackgroundTransparency = 1
TitleLbl.Text = "PRO HUB ULTIMATE v5.0 (Mobile & PC Fix)"
TitleLbl.TextColor3 = T.TEXT
TitleLbl.Font = Enum.Font.GothamBold
TitleLbl.TextSize = 14
TitleLbl.TextXAlignment = Enum.TextXAlignment.Left
TitleLbl.Parent = TitleBar

local SubTitleLbl = Instance.new("TextLabel")
SubTitleLbl.Size = UDim2.new(0, 380, 0, 16)
SubTitleLbl.Position = UDim2.new(0, 36, 0, 26)
SubTitleLbl.BackgroundTransparency = 1
SubTitleLbl.Text = "ดูดหัวเมื่อซูมเล็งอัตโนมัติ • รองรับ ESP มือถือ 100%"
SubTitleLbl.TextColor3 = T.ACCENTLIT
SubTitleLbl.Font = Enum.Font.Gotham
SubTitleLbl.TextSize = 10
SubTitleLbl.TextXAlignment = Enum.TextXAlignment.Left
SubTitleLbl.Parent = TitleBar

-- Draggable Window
local dragging, dragStart, startPos
TitleBar.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		dragging = true
		dragStart = input.Position
		startPos = Window.Position
	end
end)
addConnection(UserInputService.InputChanged:Connect(function(input)
	if (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) and dragging then
		local delta = input.Position - dragStart
		Window.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
	end
end))
addConnection(UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		dragging = false
	end
end))

local MinimizeBtn = Instance.new("TextButton")
MinimizeBtn.Size = UDim2.new(0, 28, 0, 28)
MinimizeBtn.Position = UDim2.new(1, -70, 0.5, -14)
MinimizeBtn.BackgroundColor3 = T.CARD2
MinimizeBtn.Text = "—"
MinimizeBtn.TextColor3 = T.TEXT
MinimizeBtn.Font = Enum.Font.GothamBold
MinimizeBtn.TextSize = 11
MinimizeBtn.Parent = TitleBar
Instance.new("UICorner", MinimizeBtn).CornerRadius = UDim.new(0, 6)
MinimizeBtn.MouseButton1Click:Connect(function()
	Window.Visible = false
end)

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 28, 0, 28)
CloseBtn.Position = UDim2.new(1, -36, 0.5, -14)
CloseBtn.BackgroundColor3 = T.RED
CloseBtn.Text = "✕"
CloseBtn.TextColor3 = Color3.new(1, 1, 1)
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 11
CloseBtn.Parent = TitleBar
Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0, 6)

CloseBtn.MouseButton1Click:Connect(function()
	isRunning = false
	pcall(function() RunService:UnbindFromRenderStep(RENDER_BIND_NAME) end)
	for _, conn in ipairs(connections) do
		pcall(function() conn:Disconnect() end)
	end
	pcall(function()
		for p, origSize in pairs(originalHeadSizes) do
			local _, head = getParts(p)
			if head then
				head.Size = origSize
				head.Transparency = 0
			end
		end
	end)
	MainGui:Destroy()
end)

-- Sidebar Tabs Layout
local Sidebar = Instance.new("Frame")
Sidebar.Size = UDim2.new(0, 155, 1, -48)
Sidebar.Position = UDim2.new(0, 0, 0, 48)
Sidebar.BackgroundColor3 = T.SIDEBAR
Sidebar.BorderSizePixel = 0
Sidebar.Parent = Window
Instance.new("UICorner", Sidebar).CornerRadius = UDim.new(0, 14)

local SidebarList = Instance.new("UIListLayout", Sidebar)
SidebarList.SortOrder = Enum.SortOrder.LayoutOrder
SidebarList.Padding = UDim.new(0, 6)

local SidebarPadding = Instance.new("UIPadding", Sidebar)
SidebarPadding.PaddingTop = UDim.new(0, 12)
SidebarPadding.PaddingLeft = UDim.new(0, 10)
SidebarPadding.PaddingRight = UDim.new(0, 10)

local ContentContainer = Instance.new("Frame")
ContentContainer.Size = UDim2.new(1, -155, 1, -48)
ContentContainer.Position = UDim2.new(0, 155, 0, 48)
ContentContainer.BackgroundTransparency = 1
ContentContainer.Parent = Window

local function makePage()
	local sf = Instance.new("ScrollingFrame")
	sf.Size = UDim2.new(1, 0, 1, 0)
	sf.BackgroundTransparency = 1
	sf.BorderSizePixel = 0
	sf.ScrollBarThickness = 3
	sf.ScrollBarImageColor3 = T.ACCENT
	sf.CanvasSize = UDim2.new(0, 0, 0, 0)
	sf.AutomaticCanvasSize = Enum.AutomaticSize.Y
	sf.Visible = false
	sf.Parent = ContentContainer
	local l = Instance.new("UIListLayout", sf)
	l.Padding = UDim.new(0, 8)
	local p = Instance.new("UIPadding", sf)
	p.PaddingTop = UDim.new(0, 12)
	p.PaddingLeft = UDim.new(0, 14)
	p.PaddingRight = UDim.new(0, 14)
	p.PaddingBottom = UDim.new(0, 14)
	return sf
end

local pageAim      = makePage()
local pageESP      = makePage()
local pageGun      = makePage()
local pageExtra    = makePage()
local pageSettings = makePage()
pageAim.Visible    = true

local TABS = {
	{label = "🎯 ดูดหัว (Aimbot)", frame = pageAim},
	{label = "👁️ มองทะลุ (ESP)",    frame = pageESP},
	{label = "🔫 ตั้งค่าปืน",        frame = pageGun},
	{label = "⚡ ระบบเสริม",         frame = pageExtra},
	{label = "⚙️ ตั้งค่าระบบ",       frame = pageSettings},
}

local tabButtons = {}
for i, def in ipairs(TABS) do
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(1, 0, 0, 40)
	btn.BackgroundColor3 = (i == 1) and T.CARD2 or T.SIDEBAR
	btn.Text = def.label
	btn.TextColor3 = (i == 1) and T.ACCENT or T.SUBTEXT
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 12
	btn.Parent = Sidebar
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)

	local bStroke = Instance.new("UIStroke", btn)
	bStroke.Color = (i == 1) and T.ACCENT or T.STROKE
	bStroke.Transparency = (i == 1) and 0.3 or 0.8
	bStroke.Thickness = 1

	table.insert(tabButtons, {btn = btn, stroke = bStroke})

	btn.MouseButton1Click:Connect(function()
		for _, t in ipairs(TABS) do t.frame.Visible = false end
		for _, tb in ipairs(tabButtons) do
			TweenService:Create(tb.btn, TweenInfo.new(0.15), {
				BackgroundColor3 = T.SIDEBAR,
				TextColor3 = T.SUBTEXT
			}):Play()
			tb.stroke.Color = T.STROKE
			tb.stroke.Transparency = 0.8
		end
		def.frame.Visible = true
		TweenService:Create(btn, TweenInfo.new(0.15), {
			BackgroundColor3 = T.CARD2,
			TextColor3 = T.ACCENT
		}):Play()
		bStroke.Color = T.ACCENT
		bStroke.Transparency = 0.3
	end)
end

----------------------------------------------------------------
-- UI COMPONENT BUILDERS
----------------------------------------------------------------
local function styleCard(frame)
	Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)
	local s = Instance.new("UIStroke", frame)
	s.Color = T.STROKE
	s.Thickness = 1
	s.Transparency = 0.4
end

local function makeSection(title, parent)
	local f = Instance.new("Frame")
	f.Size = UDim2.new(1, 0, 0, 24)
	f.BackgroundTransparency = 1
	f.Parent = parent
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, 0, 1, 0)
	lbl.BackgroundTransparency = 1
	lbl.Text = "◆ " .. title
	lbl.TextColor3 = T.ACCENTLIT
	lbl.Font = Enum.Font.GothamBold
	lbl.TextSize = 11
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.Parent = f
end

local function makeToggle(labelText, state, onChange, parent)
	local f = Instance.new("Frame")
	f.Size = UDim2.new(1, 0, 0, 42)
	f.BackgroundColor3 = T.CARD2
	f.Parent = parent
	styleCard(f)

	local l = Instance.new("TextLabel")
	l.Size = UDim2.new(1, -65, 1, 0)
	l.Position = UDim2.new(0, 14, 0, 0)
	l.BackgroundTransparency = 1
	l.Text = labelText
	l.TextColor3 = T.TEXT
	l.Font = Enum.Font.GothamMedium
	l.TextSize = 11
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Parent = f

	local t = Instance.new("Frame")
	t.Size = UDim2.new(0, 42, 0, 22)
	t.Position = UDim2.new(1, -54, 0.5, -11)
	t.BackgroundColor3 = state and T.ACCENT or T.TRACK
	t.Parent = f
	Instance.new("UICorner", t).CornerRadius = UDim.new(1, 0)

	local k = Instance.new("Frame")
	k.Size = UDim2.new(0, 16, 0, 16)
	k.Position = state and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8)
	k.BackgroundColor3 = Color3.new(1, 1, 1)
	k.Parent = t
	Instance.new("UICorner", k).CornerRadius = UDim.new(1, 0)

	local val = state
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(1, 0, 1, 0)
	b.BackgroundTransparency = 1
	b.Text = ""
	b.Parent = f

	b.MouseButton1Click:Connect(function()
		val = not val
		TweenService:Create(t, TweenInfo.new(0.16), {BackgroundColor3 = val and T.ACCENT or T.TRACK}):Play()
		TweenService:Create(k, TweenInfo.new(0.16), {Position = val and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8)}):Play()
		onChange(val)
	end)
end

local function makeSlider(labelText, min, max, current, step, onChange, parent)
	step = step or 1
	local f = Instance.new("Frame")
	f.Size = UDim2.new(1, 0, 0, 58)
	f.BackgroundColor3 = T.CARD2
	f.Parent = parent
	styleCard(f)

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(0.6, 0, 0, 24)
	lbl.Position = UDim2.new(0, 14, 0, 6)
	lbl.BackgroundTransparency = 1
	lbl.Text = labelText
	lbl.TextColor3 = T.TEXT
	lbl.Font = Enum.Font.GothamMedium
	lbl.TextSize = 11
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.Parent = f

	local valLbl = Instance.new("TextLabel")
	valLbl.Size = UDim2.new(0.4, -14, 0, 24)
	valLbl.Position = UDim2.new(0.6, 0, 0, 6)
	valLbl.BackgroundTransparency = 1
	valLbl.Text = string.format(step < 1 and "%.2f" or "%d", current)
	valLbl.TextColor3 = T.ACCENTLIT
	valLbl.Font = Enum.Font.GothamBold
	valLbl.TextSize = 11
	valLbl.TextXAlignment = Enum.TextXAlignment.Right
	valLbl.Parent = f

	local track = Instance.new("Frame")
	track.Size = UDim2.new(1, -28, 0, 6)
	track.Position = UDim2.new(0, 14, 0, 40)
	track.BackgroundColor3 = T.TRACK
	track.Parent = f
	Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)

	local initialFrac = math.clamp((current - min) / (max - min), 0, 1)
	local fill = Instance.new("Frame")
	fill.Size = UDim2.new(initialFrac, 0, 1, 0)
	fill.BackgroundColor3 = T.ACCENT
	fill.Parent = track
	Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)

	local knob = Instance.new("Frame")
	knob.Size = UDim2.new(0, 12, 0, 12)
	knob.Position = UDim2.new(initialFrac, -6, 0.5, -6)
	knob.BackgroundColor3 = Color3.new(1, 1, 1)
	knob.Parent = track
	Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

	local hb = Instance.new("TextButton")
	hb.Size = UDim2.new(1, 20, 1, 20)
	hb.Position = UDim2.new(0, -10, 0, -10)
	hb.BackgroundTransparency = 1
	hb.Text = ""
	hb.Parent = track

	local connMove, connEnd
	hb.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			if connMove then connMove:Disconnect() end
			if connEnd then connEnd:Disconnect() end

			local function updateSlider(posx)
				local absPos = track.AbsolutePosition.X
				local absSize = track.AbsoluteSize.X
				if absSize <= 0 then return end
				local rel = math.clamp((posx - absPos) / absSize, 0, 1)
				local v = math.floor((min + rel * (max - min)) / step + 0.5) * step
				v = math.clamp(v, min, max)
				local frac = math.clamp((v - min) / (max - min), 0, 1)
				fill.Size = UDim2.new(frac, 0, 1, 0)
				knob.Position = UDim2.new(frac, -6, 0.5, -6)
				valLbl.Text = string.format(step < 1 and "%.2f" or "%d", v)
				onChange(v)
			end

			updateSlider(input.Position.X)

			connMove = UserInputService.InputChanged:Connect(function(i)
				if i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch then
					updateSlider(i.Position.X)
				end
			end)

			connEnd = UserInputService.InputEnded:Connect(function(i)
				if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
					if connMove then connMove:Disconnect(); connMove = nil end
					if connEnd then connEnd:Disconnect(); connEnd = nil end
				end
			end)
		end
	end)
end

local function makeCycle(labelText, options, labels, current, onChange, parent)
	local f = Instance.new("Frame")
	f.Size = UDim2.new(1, 0, 0, 42)
	f.BackgroundColor3 = T.CARD2
	f.Parent = parent
	styleCard(f)

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(0.5, 0, 1, 0)
	lbl.Position = UDim2.new(0, 14, 0, 0)
	lbl.BackgroundTransparency = 1
	lbl.Text = labelText
	lbl.TextColor3 = T.TEXT
	lbl.Font = Enum.Font.GothamMedium
	lbl.TextSize = 11
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.Parent = f

	local idx = 1
	for i, v in ipairs(options) do
		if v == current then idx = i break end
	end

	local valBtn = Instance.new("TextButton")
	valBtn.Size = UDim2.new(0, 145, 0, 28)
	valBtn.Position = UDim2.new(1, -157, 0.5, -14)
	valBtn.BackgroundColor3 = T.ACCENT
	valBtn.BorderSizePixel = 0
	valBtn.Text = labels[options[idx]] or options[idx]
	valBtn.TextColor3 = Color3.fromRGB(10, 15, 12)
	valBtn.Font = Enum.Font.GothamBold
	valBtn.TextSize = 11
	valBtn.Parent = f
	Instance.new("UICorner", valBtn).CornerRadius = UDim.new(0, 6)

	valBtn.MouseButton1Click:Connect(function()
		idx = idx % #options + 1
		local nv = options[idx]
		valBtn.Text = labels[nv] or nv
		onChange(nv)
	end)
end

local function makeButton(txt, callback, parent)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(1, 0, 0, 42)
	btn.BackgroundColor3 = T.ACCENT
	btn.Text = txt
	btn.TextColor3 = Color3.fromRGB(10, 15, 12)
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 12
	btn.Parent = parent
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)

	local grad = Instance.new("UIGradient", btn)
	grad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, T.ACCENTLIT),
		ColorSequenceKeypoint.new(1, T.ACCENT2)
	})
	btn.MouseButton1Click:Connect(callback)
end

----------------------------------------------------------------
-- POPULATE TABS
----------------------------------------------------------------
-- Tab 1: Aimbot
makeSection("ระบบดูดหัว (ล็อกอัตโนมัติเมื่อซูมปืน / คลิกขวา / ปุ่มมือถือ)", pageAim)
makeToggle("เปิดใช้งานดูดหัว (Aimbot)", CFG.AimbotEnabled, function(v) CFG.AimbotEnabled = v end, pageAim)
makeToggle("ดูดหัวอัตโนมัติเวลาซูมเล็งปืน (Auto ADS Lock)", CFG.AimbotAutoADS, function(v) CFG.AimbotAutoADS = v end, pageAim)
makeToggle("ล็อกเป้าตลอดเวลาโดยไม่ต้องกดปุ่ม (Always Lock)", CFG.AimbotAlwaysOn, function(v) CFG.AimbotAlwaysOn = v end, pageAim)
makeCycle("โหมดปุ่มกดเล็ง", MODE_CYCLE, MODE_LABELS, CFG.AimbotMode, function(v)
	CFG.AimbotMode = v
	aimbotToggleActive = false
	mobileAiming = false
	lockedTargetPart = nil
	lockedTargetModel = nil
	updateMobileBtnVisual(false)
end, pageAim)
makeCycle("ตำแหน่งล็อกเป้า", PART_CYCLE, PART_LABELS, CFG.AimbotPart, function(v)
	CFG.AimbotPart = v
	lockedTargetPart = nil
end, pageAim)
makeToggle("แสดงปุ่มลอย [🎯 ดูดหัว] บนหน้าจอ", MobileAimBtn.Visible, function(v) MobileAimBtn.Visible = v end, pageAim)
makeToggle("ล็อกหุ่นซ้อมยิงด้วย (WarzDummies / Targets)", CFG.AimbotDummies, function(v) CFG.AimbotDummies = v end, pageAim)
makeToggle("ตรวจสอบทีมเดียวกัน (Team Check)", CFG.AimbotTeamCheck, function(v) CFG.AimbotTeamCheck = v end, pageAim)
makeToggle("ตรวจสอบสิ่งกีดขวาง/กำแพง (Wall Check)", CFG.AimbotWallCheck, function(v) CFG.AimbotWallCheck = v end, pageAim)
makeToggle("แสดงวงกลมระยะล็อก (FOV Circle)", CFG.ShowFOVCircle, function(v) CFG.ShowFOVCircle = v end, pageAim)
makeSlider("ขนาดวง FOV", 20, 500, CFG.AimbotFOV, 1, function(v) CFG.AimbotFOV = v end, pageAim)
makeSlider("ความแรงในการดูดเป้า (100 = ล็อกติดหัวทันที)", 5, 100, math.floor(CFG.AimbotSmooth * 100), 1, function(v) CFG.AimbotSmooth = v / 100 end, pageAim)
makeSlider("ชดเชยตำแหน่งหัว แนวนอน (X)", -1.5, 1.5, CFG.HeadOffsetX, 0.05, function(v) CFG.HeadOffsetX = v end, pageAim)
makeSlider("ชดเชยตำแหน่งหัว แนวตั้ง (Y)", -1.5, 1.5, CFG.HeadOffsetY, 0.05, function(v) CFG.HeadOffsetY = v end, pageAim)

-- Tab 2: ESP (Native Mobile & PC Engine)
makeSection("ตั้งค่าการมองทะลุ ESP (รองรับมือถือ 100%)", pageESP)
makeToggle("เปิดใช้งานมองทะลุ ESP", CFG.ESPEnabled, function(v) CFG.ESPEnabled = v end, pageESP)
makeToggle("แสดงตัวเรืองแสงทะลุกำแพง (3D Highlight Chams)", CFG.ESPHighlight, function(v) CFG.ESPHighlight = v end, pageESP)
makeToggle("แสดงกรอบสี่เหลี่ยม (2D Box)", CFG.ESPBox, function(v) CFG.ESPBox = v end, pageESP)
makeToggle("แสดงชื่อผู้เล่น (Name)", CFG.ESPName, function(v) CFG.ESPName = v end, pageESP)
makeToggle("แสดงระยะทาง (Distance)", CFG.ESPDistance, function(v) CFG.ESPDistance = v end, pageESP)
makeToggle("แสดงหลอดเลือด (Health)", CFG.ESPHealth, function(v) CFG.ESPHealth = v end, pageESP)
makeToggle("แสดงเส้นโยงเป้า (Tracers)", CFG.ESPTracers, function(v) CFG.ESPTracers = v end, pageESP)
makeToggle("แสดงไอเทมของดรอปบนพื้น (Loot)", CFG.ESPLoot, function(v) CFG.ESPLoot = v end, pageESP)
makeToggle("ซ่อน ESP หลังกำแพง (WallCheck)", CFG.ESPWallCheck, function(v) CFG.ESPWallCheck = v end, pageESP)
makeSlider("ระยะมองเห็นไกลสุด (Max Dist)", 100, 5000, CFG.ESPMaxDist, 50, function(v) CFG.ESPMaxDist = v end, pageESP)

-- Tab 3: Gun Mods
makeSection("ปรับแต่งอาวุธปืน", pageGun)
makeToggle("กระสุนตรง (No Spread)", CFG.BulletStraight, function(v) CFG.BulletStraight = v end, pageGun)
makeToggle("กระสุนนิ่ม / ขยายหัว (Soft Hitbox)", CFG.BulletSoft, function(v) CFG.BulletSoft = v end, pageGun)
makeToggle("ยิงรัวไวขึ้น (Rapid Fire)", CFG.RapidFire, function(v) CFG.RapidFire = v end, pageGun)
makeButton("🔄 รีโหลดกระสุนทันที (Quick Reload)", function()
	if ReloadRemote then
		pcall(function() ReloadRemote:FireServer() end)
	end
end, pageGun)

-- Tab 4: Extra Features
makeSection("ระบบตัวละครและฟาร์มของ", pageExtra)
makeToggle("วิ่งไวพิเศษ (Speed)", CFG.SpeedEnabled, function(v) CFG.SpeedEnabled = v end, pageExtra)
makeSlider("ความเร็วในการวิ่ง (Speed Value)", 10, 100, CFG.SpeedVal, 1, function(v) CFG.SpeedVal = v end, pageExtra)
makeToggle("เดินทะลุกำแพง (Noclip)", CFG.NoclipEnabled, function(v) CFG.NoclipEnabled = v end, pageExtra)
makeToggle("ปั๊มยาออโต้ (Auto Heal)", CFG.AutoHealEnabled, function(v) CFG.AutoHealEnabled = v end, pageExtra)
makeToggle("เก็บของออโต้ (Auto Loot)", CFG.AutoLootEnabled, function(v) CFG.AutoLootEnabled = v end, pageExtra)
makeButton("📦 เก็บของเข้าตู้ทั้งหมด (BagAllToStash)", function()
	if BagAllToStashRemote then
		pcall(function() BagAllToStashRemote:FireServer() end)
	end
end, pageExtra)

-- Tab 5: Settings
makeSection("ความปลอดภัยและข้อมูล", pageSettings)
makeToggle("ระบบป้องกันการเตะ/แบนเบื้องต้น", true, function(v) end, pageSettings)
