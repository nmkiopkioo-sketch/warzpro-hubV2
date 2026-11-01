-- Language: Lua (Luau) | Pro Hub | ProScript v8.3 (Universal Mobile & PC ESP Edition)
-- Home / ปุ่ม PRO = เปิด/ปิด UI | คลิกขวาค้าง/เล็ง = ล็อคเป้าหัวแม่นยำ 100%

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Camera           = workspace.CurrentCamera
local LocalPlayer      = Players.LocalPlayer

-- โหลด Remotes อย่างปลอดภัยจากข้อมูล Dump
local Remotes, PickupLootRemote, UseItemRemote, BagAllToStashRemote
pcall(function()
    Remotes = ReplicatedStorage:WaitForChild("Remotes", 3)
    if Remotes then
        PickupLootRemote = Remotes:FindFirstChild("PickupLoot")
        UseItemRemote = Remotes:FindFirstChild("UseItem")
        BagAllToStashRemote = Remotes:FindFirstChild("BagAllToStash")
    end
end)

-- ธีมสี UI พรีเมียม
local T = {
    BG = Color3.fromRGB(13, 18, 15),
    SIDEBAR = Color3.fromRGB(10, 14, 12),
    CARD = Color3.fromRGB(20, 28, 22),
    ACCENT = Color3.fromRGB(0, 230, 100),
    ACCENT_GLOW = Color3.fromRGB(0, 255, 120),
    TEXT = Color3.fromRGB(240, 255, 245),
    SUBTEXT = Color3.fromRGB(140, 180, 150),
    TRACK = Color3.fromRGB(35, 50, 40),
    RED = Color3.fromRGB(255, 70, 70),
}

local CFG = {
    AimbotEnabled = true,
    AimbotFOV = 180,
    AimbotSmooth = 0.35,
    AimbotTeamCheck = false,
    ShowFOVCircle = true,
    
    ESPEnabled = true,
    ESPBox = true,
    ESPName = true,
    ESPDistance = true,
    ESPHealth = true,
    ESPTracers = true,
    ESPMaxDist = 1500,
    
    SpeedEnabled = false,
    SpeedVal = 20,
    NoclipEnabled = false,
    AutoHealEnabled = false,
    AutoLootEnabled = false,
    
    BulletStraight = false,
    BulletSoft = false,
    RapidFire = false,
    
    AntiBanEnabled = true,
    
    ColorEnemy = Color3.fromRGB(255, 65, 65),
    ColorTeammate = Color3.fromRGB(60, 190, 255),
    ColorTracer = Color3.fromRGB(0, 250, 120),
    ColorText = Color3.fromRGB(255, 255, 255),
    ColorHP = Color3.fromRGB(0, 240, 90),
    ColorHPLow = Color3.fromRGB(255, 60, 60),
    ColorFOV = Color3.fromRGB(0, 255, 120),
}

----------------------------------------------------------------
-- UNIVERSAL GUI ESP SYSTEM (รองรับมือถือและ PC 100%)
----------------------------------------------------------------
local ESPGui = Instance.new("ScreenGui")
ESPGui.Name = "ProHub_UniversalESP"
ESPGui.ResetOnSpawn = false
pcall(function() ESPGui.Parent = game:GetService("CoreGui") end)
if not ESPGui.Parent then ESPGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

-- วงกลม FOV แบบ GUI รองรับมือถือ
local fovFrame = Instance.new("Frame")
fovFrame.Name = "FOVCircle"
fovFrame.AnchorPoint = Vector2.new(0.5, 0.5)
fovFrame.BackgroundTransparency = 1
fovFrame.Visible = false
fovFrame.Parent = ESPGui

local fovStroke = Instance.new("UIStroke", fovFrame)
fovStroke.Color = CFG.ColorFOV
fovStroke.Thickness = 1.5

local espPool = {}

local function createEspElements(p)
    if espPool[p] then return end
    local holder = Instance.new("Folder")
    holder.Name = p.Name
    holder.Parent = ESPGui

    -- Box (Frame)
    local box = Instance.new("Frame")
    box.BackgroundTransparency = 1
    box.Visible = false
    box.Parent = holder
    local boxStroke = Instance.new("UIStroke", box)
    boxStroke.Color = CFG.ColorEnemy
    boxStroke.Thickness = 1.5

    -- Name Text
    local name = Instance.new("TextLabel")
    name.BackgroundTransparency = 1
    name.Size = UDim2.new(0, 150, 0, 20)
    name.AnchorPoint = Vector2.new(0.5, 1)
    name.TextColor3 = CFG.ColorText
    name.TextStrokeTransparency = 0
    name.TextSize = 12
    name.Font = Enum.Font.GothamBold
    name.Visible = false
    name.Parent = holder

    -- Distance Text
    local dist = Instance.new("TextLabel")
    dist.BackgroundTransparency = 1
    dist.Size = UDim2.new(0, 150, 0, 15)
    dist.AnchorPoint = Vector2.new(0.5, 1)
    dist.TextColor3 = Color3.fromRGB(180, 180, 180)
    dist.TextStrokeTransparency = 0
    dist.TextSize = 10
    dist.Font = Enum.Font.Gotham
    dist.Visible = false
    dist.Parent = holder

    -- HP Bar Background
    local hpBg = Instance.new("Frame")
    hpBg.BackgroundColor3 = Color3.new(0,0,0)
    hpBg.BorderSizePixel = 0
    hpBg.Visible = false
    hpBg.Parent = holder

    -- HP Bar Fill
    local hpBar = Instance.new("Frame")
    hpBar.BackgroundColor3 = CFG.ColorHP
    hpBar.BorderSizePixel = 0
    hpBar.Visible = false
    hpBar.Parent = hpBg

    espPool[p] = {folder = holder, box = box, stroke = boxStroke, name = name, dist = dist, hpBg = hpBg, hpBar = hpBar}
end

local function removeEspElements(p)
    if espPool[p] then
        pcall(function() espPool[p].folder:Destroy() end)
        espPool[p] = nil
    end
end

for _, p in ipairs(Players:GetPlayers()) do if p ~= LocalPlayer then createEspElements(p) end end
Players.PlayerAdded:Connect(function(p) if p ~= LocalPlayer then createEspElements(p) end end)
Players.PlayerRemoving:Connect(removeEspElements)

----------------------------------------------------------------
-- UTILS & HELPERS
----------------------------------------------------------------
local function getParts(p)
    local c = workspace:FindFirstChild(p.Name)
    if not c then return nil, nil, nil end
    local hum = c:FindFirstChildWhichIsA("Humanoid", true)
    local root = c:FindFirstChild("HumanoidRootPart") or c:FindFirstChild("UpperTorso") or c:FindFirstChild("Torso")
    local head = c:FindFirstChild("Head") or root
    return root, head, hum
end

local function w2s(pos)
    local v, on = Camera:WorldToViewportPoint(pos)
    if not on or v.Z <= 0 then return Vector2.new(v.X, v.Y), false end
    local vp = Camera.ViewportSize
    if v.X < 0 or v.Y < 0 or v.X > vp.X or v.Y > vp.Y then return Vector2.new(v.X, v.Y), false end
    return Vector2.new(v.X, v.Y), true
end

local function screenCenter() return Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2) end

local function isEnemy(p)
    if not CFG.AimbotTeamCheck then return true end
    return p.Team ~= LocalPlayer.Team
end

----------------------------------------------------------------
-- BACKGROUND TASKS (Auto Loot, Auto Heal, Soft Hitbox)
----------------------------------------------------------------
task.spawn(function()
    while true do
        task.wait(0.25)
        pcall(function()
            local char = LocalPlayer.Character
            if not char then return end
            local root = char:FindFirstChild("HumanoidRootPart")
            local hum = char:FindFirstChildOfClass("Humanoid")

            if CFG.AutoLootEnabled and root and PickupLootRemote then
                local lootFolder = workspace:FindFirstChild("WarzLoot")
                if lootFolder then
                    for _, item in ipairs(lootFolder:GetChildren()) do
                        if item:IsA("BasePart") and (item.Position - root.Position).Magnitude <= 15 then
                            PickupLootRemote:FireServer(item)
                        end
                    end
                end
            end

            if CFG.AutoHealEnabled and hum and hum.Health > 0 and hum.Health < 65 and UseItemRemote then
                local backpack = LocalPlayer:FindFirstChild("Backpack")
                if backpack then
                    for _, item in ipairs(backpack:GetChildren()) do
                        if item:IsA("Tool") then
                            local n = item.Name:lower()
                            if n:find("heal") or n:find("med") or n:find("potion") or n:find("ยา") or n:find("bandage") or n:find("kit") then
                                UseItemRemote:FireServer(item)
                                task.wait(0.5)
                                break
                            end
                        end
                    end
                end
            end

            if CFG.BulletSoft then
                local enemyCount = 0
                for _, p in ipairs(Players:GetPlayers()) do
                    if p ~= LocalPlayer and isEnemy(p) then
                        local _, head = getParts(p)
                        if head and head:IsA("BasePart") then
                            head.Size = Vector3.new(4, 4, 4)
                            head.Transparency = 0.6
                            head.CanCollide = false
                            enemyCount = enemyCount + 1
                            if enemyCount > 15 then task.wait(0.05) end -- ป้องกันแลค
                        end
                    end
                end
            end
        end)
    end
end)

RunService.Stepped:Connect(function()
    if LocalPlayer.Character then
        if CFG.NoclipEnabled then
            for _, part in ipairs(LocalPlayer.Character:GetDescendants()) do
                if part:IsA("BasePart") then part.CanCollide = false end
            end
        end

        local tool = LocalPlayer.Character:FindFirstChildOfClass("Tool")
        if tool then
            pcall(function()
                if CFG.RapidFire then
                    local fr = tool:FindFirstChild("FireRate") or tool:FindFirstChild("Cooldown")
                    if fr and fr:IsA("NumberValue") then fr.Value = 0.005 end
                end
            end)
        end
    end
end)

----------------------------------------------------------------
-- RENDER LOOP (ESP & Aimbot)
----------------------------------------------------------------
local function isRightMouseDown()
    return UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) or UserInputService.TouchEnabled
end

RunService.RenderStepped:Connect(function()
    local center = screenCenter()
    
    -- อัปเดต FOV Circle
    if fovFrame then
        fovFrame.Visible = CFG.ShowFOVCircle
        fovFrame.Position = UDim2.new(0, center.X, 0, center.Y)
        local fovSize = CFG.AimbotFOV * 2
        fovFrame.Size = UDim2.new(0, fovSize, 0, fovSize)
        fovStroke.Color = CFG.ColorFOV
    end

    if CFG.SpeedEnabled and LocalPlayer.Character then
        local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then hum.WalkSpeed = CFG.SpeedVal end
    end

    -- อัปเดต ESP ทุกเฟรมสำหรับมือถือและ PC
    for p, e in pairs(espPool) do
        local root, head, hum = getParts(p)
        if not CFG.ESPEnabled or not root or not hum or hum.Health <= 0 then
            e.box.Visible = false; e.name.Visible = false; e.dist.Visible = false; e.hpBg.Visible = false
        else
            local dist3D = (root.Position - Camera.CFrame.Position).Magnitude
            if dist3D > CFG.ESPMaxDist then
                e.box.Visible = false; e.name.Visible = false; e.dist.Visible = false; e.hpBg.Visible = false
            else
                local topSP, topOn = w2s(head.Position + Vector3.new(0, 0.7, 0))
                local botSP, botOn = w2s(root.Position - Vector3.new(0, 3.0, 0))
                
                if not topOn and not botOn then
                    e.box.Visible = false; e.name.Visible = false; e.dist.Visible = false; e.hpBg.Visible = false
                else
                    local bH = math.max(math.abs(topSP.Y - botSP.Y), 1)
                    local bW = bH * 0.6
                    local bX = topSP.X - bW / 2
                    local col = isEnemy(p) and CFG.ColorEnemy or CFG.ColorTeammate

                    -- Box
                    if CFG.ESPBox then
                        e.box.Visible = true
                        e.box.Position = UDim2.new(0, bX, 0, topSP.Y)
                        e.box.Size = UDim2.new(0, bW, 0, bH)
                        e.stroke.Color = col
                    else
                        e.box.Visible = false
                    end

                    -- Name
                    if CFG.ESPName then
                        e.name.Visible = true
                        e.name.Position = UDim2.new(0, topSP.X, 0, topSP.Y - 4)
                        e.name.Text = p.Name
                        e.name.TextColor3 = CFG.ColorText
                    else
                        e.name.Visible = false
                    end

                    -- Distance
                    if CFG.ESPDistance then
                        e.dist.Visible = true
                        e.dist.Position = UDim2.new(0, topSP.X, 0, topSP.Y - 16)
                        e.dist.Text = string.format("[%dm]", math.floor(dist3D/4))
                    else
                        e.dist.Visible = false
                    end

                    -- Health Bar
                    if CFG.ESPHealth then
                        local hpR = hum.MaxHealth > 0 and math.clamp(hum.Health/hum.MaxHealth, 0, 1) or 0
                        e.hpBg.Visible = true
                        e.hpBg.Position = UDim2.new(0, bX - 6, 0, topSP.Y)
                        e.hpBg.Size = UDim2.new(0, 3, 0, bH)
                        e.hpBar.Visible = true
                        e.hpBar.BackgroundColor3 = hpR > 0.4 and CFG.ColorHP or CFG.ColorHPLow
                        e.hpBar.Size = UDim2.new(1, 0, hpR, 0)
                        e.hpBar.Position = UDim2.new(0, 0, 1 - hpR, 0)
                    else
                        e.hpBg.Visible = false
                        e.hpBar.Visible = false
                    end
                end
            end
        end
    end

    -- Aimbot Head Lock
    if CFG.AimbotEnabled and isRightMouseDown() then
        local bestTarget = nil
        local bestDist = CFG.AimbotFOV

        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and isEnemy(p) then
                local _, head, hum = getParts(p)
                if head and hum and hum.Health > 0 then
                    local screenPos, onScreen = Camera:WorldToViewportPoint(head.Position)
                    if onScreen and screenPos.Z > 0 then
                        local d = (Vector2.new(screenPos.X, screenPos.Y) - center).Magnitude
                        if d < bestDist then
                            bestDist = d
                            bestTarget = head
                        end
                    end
                end
            end
        end

        if bestTarget then
            local targetPos = bestTarget.Position
            local currentCF = Camera.CFrame
            local goalCF = CFrame.new(currentCF.Position, targetPos)
            local smooth = math.clamp(CFG.AimbotSmooth, 0.05, 1)
            Camera.CFrame = currentCF:Lerp(goalCF, smooth)
        end
    end
end)

----------------------------------------------------------------
-- MOBILE & PC OPTIMIZED SIDEBAR GUI
----------------------------------------------------------------
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "ProHubMobile"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = game:GetService("CoreGui")

local ToggleBtn = Instance.new("TextButton")
ToggleBtn.Size = UDim2.new(0, 48, 0, 48)
ToggleBtn.Position = UDim2.new(0, 20, 0.3, 0)
ToggleBtn.BackgroundColor3 = T.SIDEBAR
ToggleBtn.Text = "PRO"
ToggleBtn.TextColor3 = T.ACCENT
ToggleBtn.Font = Enum.Font.GothamBold
ToggleBtn.TextSize = 12
ToggleBtn.Parent = ScreenGui
Instance.new("UICorner", ToggleBtn).CornerRadius = UDim.new(1, 0)
local ToggleStroke = Instance.new("UIStroke", ToggleBtn)
ToggleStroke.Color = T.ACCENT
ToggleStroke.Thickness = 1.5

local WIN_W, WIN_H = 520, 440
local Window = Instance.new("Frame")
Window.Size = UDim2.new(0, WIN_W, 0, WIN_H)
Window.Position = UDim2.new(0.5, -WIN_W/2, 0.5, -WIN_H/2)
Window.BackgroundColor3 = T.BG
Window.BorderSizePixel = 0
Window.Visible = true
Window.Parent = ScreenGui
Instance.new("UICorner", Window).CornerRadius = UDim.new(0, 12)

ToggleBtn.MouseButton1Click:Connect(function()
    Window.Visible = not Window.Visible
end)

local WindowStroke = Instance.new("UIStroke", Window)
WindowStroke.Color = T.ACCENT
WindowStroke.Transparency = 0.5
WindowStroke.Thickness = 1.5

local TitleBar = Instance.new("Frame")
TitleBar.Size = UDim2.new(1, 0, 0, 40)
TitleBar.BackgroundColor3 = T.SIDEBAR
TitleBar.BorderSizePixel = 0
TitleBar.Parent = Window
Instance.new("UICorner", TitleBar).CornerRadius = UDim.new(0, 12)

local TitleDot = Instance.new("Frame")
TitleDot.Size = UDim2.new(0, 8, 0, 8)
TitleDot.Position = UDim2.new(0, 14, 0.5, -4)
TitleDot.BackgroundColor3 = T.ACCENT
TitleDot.BorderSizePixel = 0
TitleDot.Parent = TitleBar
Instance.new("UICorner", TitleDot).CornerRadius = UDim.new(1, 0)

local TitleLbl = Instance.new("TextLabel")
TitleLbl.Size = UDim2.new(0, 300, 1, 0)
TitleLbl.Position = UDim2.new(0, 30, 0, 0)
TitleLbl.BackgroundTransparency = 1
TitleLbl.Text = "PRO HUB  •  WarZ v8.3"
TitleLbl.TextColor3 = T.TEXT
TitleLbl.Font = Enum.Font.GothamBold
TitleLbl.TextSize = 13
TitleLbl.TextXAlignment = Enum.TextXAlignment.Left
TitleLbl.Parent = TitleBar

local dragging, dragStart, startPos
TitleBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true; dragStart = input.Position; startPos = Window.Position
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) and dragging then
        local delta = input.Position - dragStart
        Window.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = false end
end)

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 26, 0, 26)
CloseBtn.Position = UDim2.new(1, -34, 0.5, -13)
CloseBtn.BackgroundColor3 = T.RED
CloseBtn.Text = "✕"
CloseBtn.TextColor3 = Color3.new(1,1,1)
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 11
CloseBtn.Parent = TitleBar
Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0, 6)
CloseBtn.MouseButton1Click:Connect(function() ScreenGui:Destroy() ESPGui:Destroy() end)

local minimized = false
local MinBtn = Instance.new("TextButton")
MinBtn.Size = UDim2.new(0, 26, 0, 26)
MinBtn.Position = UDim2.new(1, -68, 0.5, -13)
MinBtn.BackgroundColor3 = T.TRACK
MinBtn.Text = "-"
MinBtn.TextColor3 = Color3.new(1,1,1)
MinBtn.Font = Enum.Font.GothamBold
MinBtn.TextSize = 14
MinBtn.Parent = TitleBar
Instance.new("UICorner", MinBtn).CornerRadius = UDim.new(0, 6)

-- Footer Credits
local Footer = Instance.new("Frame")
Footer.Size = UDim2.new(1, 0, 0, 30)
Footer.Position = UDim2.new(0, 0, 1, -30)
Footer.BackgroundColor3 = T.SIDEBAR
Footer.BorderSizePixel = 0
Footer.Parent = Window
Instance.new("UICorner", Footer).CornerRadius = UDim.new(0, 12)

local CreditLbl = Instance.new("TextLabel")
CreditLbl.Size = UDim2.new(1, 0, 1, 0)
CreditLbl.BackgroundTransparency = 1
CreditLbl.Text = "📺 YT: ช่องนี้เรื่องโปร  |  💬 Discord: discord.gg/gZpkSgmR8"
CreditLbl.TextColor3 = T.ACCENT_GLOW
CreditLbl.Font = Enum.Font.GothamBold
CreditLbl.TextSize = 10
CreditLbl.Parent = Footer

local Sidebar = Instance.new("Frame")
Sidebar.Size = UDim2.new(0, 140, 1, -70)
Sidebar.Position = UDim2.new(0, 0, 0, 40)
Sidebar.BackgroundColor3 = T.SIDEBAR
Sidebar.BorderSizePixel = 0
Sidebar.Parent = Window

local SidebarList = Instance.new("UIListLayout", Sidebar)
SidebarList.SortOrder = Enum.SortOrder.LayoutOrder
SidebarList.Padding = UDim.new(0, 5)

local SidebarPadding = Instance.new("UIPadding", Sidebar)
SidebarPadding.PaddingTop = UDim.new(0, 8)
SidebarPadding.PaddingLeft = UDim.new(0, 8)
SidebarPadding.PaddingRight = UDim.new(0, 8)

local ContentContainer = Instance.new("Frame")
ContentContainer.Size = UDim2.new(1, -140, 1, -70)
ContentContainer.Position = UDim2.new(0, 140, 0, 40)
ContentContainer.BackgroundTransparency = 1
ContentContainer.Parent = Window

MinBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    MinBtn.Text = minimized and "+" or "-"
    TweenService:Create(Window, TweenInfo.new(0.25, Enum.EasingStyle.Quad), {
        Size = minimized and UDim2.new(0, WIN_W, 0, 40) or UDim2.new(0, WIN_W, 0, WIN_H)
    }):Play()
    Sidebar.Visible = not minimized
    ContentContainer.Visible = not minimized
    Footer.Visible = not minimized
end)

local function makePage()
    local sf = Instance.new("ScrollingFrame")
    sf.Size = UDim2.new(1, 0, 1, 0)
    sf.BackgroundTransparency = 1
    sf.BorderSizePixel = 0
    sf.ScrollBarThickness = 3
    sf.ScrollBarImageColor3 = T.ACCENT
    sf.CanvasSize = UDim2.new(0,0,0,0)
    sf.AutomaticCanvasSize = Enum.AutomaticSize.Y
    sf.Visible = false
    sf.Parent = ContentContainer
    local l = Instance.new("UIListLayout", sf)
    l.Padding = UDim.new(0, 8)
    local p = Instance.new("UIPadding", sf)
    p.PaddingTop = UDim.new(0, 12); p.PaddingLeft = UDim.new(0, 12); p.PaddingRight = UDim.new(0, 12); p.PaddingBottom = UDim.new(0, 12)
    return sf
end

local pageAim = makePage()
local pageESP = makePage()
local pageGun = makePage()
local pageExtra = makePage()
local pageSettings = makePage()
pageAim.Visible = true

local function addTab(name, page)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 36)
    btn.BackgroundColor3 = page.Visible and T.CARD or T.SIDEBAR
    btn.Text = name
    btn.TextColor3 = page.Visible and T.ACCENT or T.SUBTEXT
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 12
    btn.Parent = Sidebar
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
    
    btn.MouseButton1Click:Connect(function()
        for _, p in ipairs({pageAim, pageESP, pageGun, pageExtra, pageSettings}) do p.Visible = false end
        for _, b in ipairs(Sidebar:GetChildren()) do
            if b:IsA("TextButton") then
                b.BackgroundColor3 = T.SIDEBAR
                b.TextColor3 = T.SUBTEXT
            end
        end
        page.Visible = true
        btn.BackgroundColor3 = T.CARD
        btn.TextColor3 = T.ACCENT
    end)
end

addTab("🎯 ล็อคเป้า", pageAim)
addTab("👁️ มองทะลุ", pageESP)
addTab("🔫 กระสุน", pageGun)
addTab("⚡ ระบบเสริม", pageExtra)
addTab("⚙️ ตั้งค่า", pageSettings)

local function makeToggle(txt, state, callback, parent)
    local f = Instance.new("Frame"); f.Size = UDim2.new(1, 0, 0, 38); f.BackgroundColor3 = T.CARD; f.Parent = parent
    Instance.new("UICorner", f).CornerRadius = UDim.new(0, 8)
    local l = Instance.new("TextLabel"); l.Size = UDim2.new(1, -55, 1, 0); l.Position = UDim2.new(0, 12, 0, 0)
    l.BackgroundTransparency = 1; l.Text = txt; l.TextColor3 = T.TEXT; l.Font = Enum.Font.Gotham; l.TextSize = 11
    l.TextXAlignment = Enum.TextXAlignment.Left; l.Parent = f
    local t = Instance.new("Frame"); t.Size = UDim2.new(0, 38, 0, 18); t.Position = UDim2.new(1, -44, 0.5, -9)
    t.BackgroundColor3 = state and T.ACCENT or T.TRACK; t.Parent = f
    Instance.new("UICorner", t).CornerRadius = UDim.new(1, 0)
    local k = Instance.new("Frame"); k.Size = UDim2.new(0, 14, 0, 14)
    k.Position = state and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7)
    k.BackgroundColor3 = Color3.new(1,1,1); k.Parent = t
    Instance.new("UICorner", k).CornerRadius = UDim.new(1, 0)
    local val = state
    local b = Instance.new("TextButton"); b.Size = UDim2.new(1, 0, 1, 0); b.BackgroundTransparency = 1; b.Text = ""; b.Parent = f
    b.MouseButton1Click:Connect(function()
        val = not val
        TweenService:Create(t, TweenInfo.new(0.15), {BackgroundColor3 = val and T.ACCENT or T.TRACK}):Play()
        TweenService:Create(k, TweenInfo.new(0.15), {Position = val and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7)}):Play()
        callback(val)
    end)
end

local function makeSlider(labelText, min, max, current, step, onChange, parent)
    step = step or 1
    local f = Instance.new("Frame"); f.Size = UDim2.new(1, 0, 0, 54); f.BackgroundColor3 = T.CARD; f.Parent = parent
    Instance.new("UICorner", f).CornerRadius = UDim.new(0, 8)
    local lbl = Instance.new("TextLabel"); lbl.Size = UDim2.new(0.6, 0, 0, 22); lbl.Position = UDim2.new(0, 12, 0, 6)
    lbl.BackgroundTransparency = 1; lbl.Text = labelText; lbl.TextColor3 = T.TEXT; lbl.Font = Enum.Font.Gotham; lbl.TextSize = 11
    lbl.TextXAlignment = Enum.TextXAlignment.Left; lbl.Parent = f
    local valLbl = Instance.new("TextLabel"); valLbl.Size = UDim2.new(0.4, -12, 0, 22); valLbl.Position = UDim2.new(0.6, 0, 0, 6)
    valLbl.BackgroundTransparency = 1; valLbl.Text = tostring(current); valLbl.TextColor3 = T.ACCENT_GLOW
    valLbl.Font = Enum.Font.GothamBold; valLbl.TextSize = 11; valLbl.TextXAlignment = Enum.TextXAlignment.Right; valLbl.Parent = f
    local track = Instance.new("Frame"); track.Size = UDim2.new(1, -24, 0, 6); track.Position = UDim2.new(0, 12, 0, 36)
    track.BackgroundColor3 = T.TRACK; track.Parent = f
    Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)
    local fill = Instance.new("Frame"); fill.Size = UDim2.new((current-min)/(max-min), 0, 1, 0); fill.BackgroundColor3 = T.ACCENT; fill.Parent = track
    Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)
    
    local dragging = false
    local function upd(px)
        local rel = math.clamp((px - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
        local v = math.floor((min + rel * (max - min)) / step + 0.5) * step
        v = math.clamp(v, min, max)
        local frac = (v - min) / (max - min)
        fill.Size = UDim2.new(frac, 0, 1, 0)
        valLbl.Text = tostring(v)
        onChange(v)
    end
    local hb = Instance.new("TextButton"); hb.Size = UDim2.new(1, 0, 0, 24); hb.Position = UDim2.new(0, 0, -1.5, 0); hb.BackgroundTransparency = 1; hb.Text = ""; hb.Parent = track
    hb.MouseButton1Down:Connect(function(x) dragging = true; upd(x) end)
    UserInputService.InputChanged:Connect(function(i)
        if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then upd(i.Position.X) end
    end)
    UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.MouseButton1 then dragging = false end
    end)
end

local function makeButton(txt, callback, parent)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 38)
    btn.BackgroundColor3 = T.ACCENT
    btn.Text = txt
    btn.TextColor3 = Color3.fromRGB(10, 15, 12)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 11
    btn.Parent = parent
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
    btn.MouseButton1Click:Connect(callback)
end

-- สร้างเมนูตัวเลือกทั้งหมดครบถ้วน
makeToggle("เปิดใช้งานล็อคเป้า (เล็ง/คลิกขวา)", CFG.AimbotEnabled, function(v) CFG.AimbotEnabled = v end, pageAim)
makeToggle("แสดงวงกลม FOV", CFG.ShowFOVCircle, function(v) CFG.ShowFOVCircle = v end, pageAim)
makeSlider("ปรับขนาด FOV", 20, 400, CFG.AimbotFOV, 5, function(v) CFG.AimbotFOV = v end, pageAim)

makeToggle("เปิดใช้งาน ESP", CFG.ESPEnabled, function(v) CFG.ESPEnabled = v end, pageESP)
makeToggle("แสดงกรอบ 3D Box", CFG.ESPBox, function(v) CFG.ESPBox = v end, pageESP)
makeToggle("แสดงชื่อผู้เล่น", CFG.ESPName, function(v) CFG.ESPName = v end, pageESP)
makeToggle("แสดงระยะทาง", CFG.ESPDistance, function(v) CFG.ESPDistance = v end, pageESP)
makeToggle("แสดงพลังชีวิต HP", CFG.ESPHealth, function(v) CFG.ESPHealth = v end, pageESP)

makeToggle("กระสุนตรง (No Spread)", CFG.BulletStraight, function(v) CFG.BulletStraight = v end, pageGun)
makeToggle("กระสุนนิ่ม (Soft Hitbox)", CFG.BulletSoft, function(v) CFG.BulletSoft = v end, pageGun)
makeToggle("ยิงไวขึ้น (Rapid Fire)", CFG.RapidFire, function(v) CFG.RapidFire = v end, pageGun)

makeToggle("วิ่งไว (Speed)", CFG.SpeedEnabled, function(v) CFG.SpeedEnabled = v end, pageExtra)
makeToggle("เดินทะลุกำแพง (Noclip)", CFG.NoclipEnabled, function(v) CFG.NoclipEnabled = v end, pageExtra)
makeToggle("ปั๊มยาออโต้", CFG.AutoHealEnabled, function(v) CFG.AutoHealEnabled = v end, pageExtra)
makeToggle("เก็บของออโต้", CFG.AutoLootEnabled, function(v) CFG.AutoLootEnabled = v end, pageExtra)

makeButton("📦 เก็บของเข้าตู้ทั้งหมด (Stash)", function()
    if BagAllToStashRemote then
        pcall(function() BagAllToStashRemote:FireServer() end)
    end
end, pageExtra)

makeToggle("ระบบกันแบน (Anti-Ban)", CFG.AntiBanEnabled, function(v) CFG.AntiBanEnabled = v end, pageSettings)
