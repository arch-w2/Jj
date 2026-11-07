

local Aquafield = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/CICAGLISAQ/Aquafield-Library/refs/heads/main/Aquafield"
))()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local PathfindingService = game:GetService("PathfindingService")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- ================================================================
-- CONFIGURACIÓN GENERAL (ESTADO DE CADA FUNCIÓN)
-- ================================================================
local Config = {
    -- Visuals: Player ESP
    ESP = false,
    ShowName = true,
    ESPStatus = true,
    ShowHealth = true,
    ShowInfo = true,
    ShowTools = true,
    ESPAllTools = false,
    Chams = false,
    ESPRange = 2500,
    ESPScale = 1,
    DefaultColor = Color3.fromRGB(255, 255, 255),

    -- Visuals: Ground / Drops ESP
    DropESP = false,
    ShowGuns = true,
    ShowAmmo = true,
    ShowMoney = true,
    ShowMisc = true,
    DropRange = 1000,

    -- Combat: Aimbot
    Aimbot = false,
    SmartHit = false,
    SkipSafe = true,
    AimPart = "Head",
    AimPriority = "Closest",
    AimFOV = 150,
    AimSmooth = 0,
    AimKey = Enum.KeyCode.E,
    AimHolding = false,

    -- Combat: Hitbox Expander
    Hitbox = false,
    HitboxSize = 8,
    HitboxPart = "Head",

    -- Combat: Weapon Mods
    NoRecoil = false,
    NoSpread = false,
    FullAuto = false,
    FastReload = false,
    RPM = false,
    RPMValue = 800,

    -- Combat: Visualize
    ShowFOV = false,
    TargetHL = false,
    TargetLine = false,
    Tracers = false,
    TracerColor = Color3.fromRGB(255, 50, 50),

    -- Farm
    PuddleFarm = false,
    AutoRob = false,
    RobHeight = 15,
    RobSpeed = 50,
    FarmRange = 3000,
}

-- Helpers básicos
local function getChar(p)
    p = p or LocalPlayer
    return p and p.Character
end

local function getRoot(p)
    local c = getChar(p)
    return c and (c:FindFirstChild("HumanoidRootPart") or c:FindFirstChild("Torso") or c:FindFirstChild("UpperTorso"))
end

local function getHum(p)
    local c = getChar(p)
    return c and c:FindFirstChildOfClass("Humanoid")
end

-- ================================================================
-- CREACIÓN DE VENTANA AQUAFIELD
-- ================================================================
local Window = Aquafield:CreateWindow({
    Name = "BQM AUTO FARM ETC",
    Icon = 0,
    LoadingTitle = "Aquafield Farm & Combat",
    LoadingSubtitle = "Delta Executor Edition",
    Theme = "Ocean",
    ConfigurationSaving = {
        Enabled = false,
        FolderName = "AUTOFARM",
        FileName = "Config",
    },
    KeySystem = false,
})

-- BOTÓN FLOTANTE PARA ABRIR/CERRAR MENÚ (MÓVIL & PC)
local Gui = Instance.new("ScreenGui")
Gui.Name = "AquafieldOpenBtn"
Gui.ResetOnSpawn = false
Gui.DisplayOrder = 999
pcall(function() Gui.Parent = game:GetService("CoreGui") end)
if not Gui.Parent then Gui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

local OpenBtn = Instance.new("TextButton")
OpenBtn.Size = UDim2.new(0, 50, 0, 50)
OpenBtn.Position = UDim2.new(0, 15, 0.5, -25)
OpenBtn.BackgroundColor3 = Color3.fromRGB(20, 30, 45)
OpenBtn.TextColor3 = Color3.fromRGB(0, 220, 255)
OpenBtn.Text = "🌊"
OpenBtn.TextSize = 22
OpenBtn.Font = Enum.Font.GothamBold
OpenBtn.AutoButtonColor = false
OpenBtn.Parent = Gui

local BtnCorner = Instance.new("UICorner")
BtnCorner.CornerRadius = UDim.new(0, 25)
BtnCorner.Parent = OpenBtn

local BtnStroke = Instance.new("UIStroke")
BtnStroke.Color = Color3.fromRGB(0, 180, 255)
BtnStroke.Thickness = 1.8
BtnStroke.Parent = OpenBtn

local dragging, dragStart, startPos = false, nil, nil
OpenBtn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = OpenBtn.Position
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        OpenBtn.Position = UDim2.new(
            startPos.X.Scale, startPos.X.Offset + delta.X,
            startPos.Y.Scale, startPos.Y.Offset + delta.Y
        )
    end
end)
local function stopDrag() dragging = false end
OpenBtn.InputEnded:Connect(stopDrag)

local isMenuOpen = true
OpenBtn.MouseButton1Click:Connect(function()
    isMenuOpen = not isMenuOpen
    pcall(function()
        if Window.SetVisible then
            Window:SetVisible(isMenuOpen)
        elseif Window.Main then
            Window.Main.Visible = isMenuOpen
        end
    end)
end)

-- PESTAÑAS PRINCIPALES
local Main = Window:CreateTab("Main", 0)
local FarmTab = Window:CreateTab("Farm", 0)
local CombatTab = Window:CreateTab("Combat", 0)
local VisualsTab = Window:CreateTab("Visuals", 0)
local SettingsTab = Window:CreateTab("Settings", 0)

-- ================================================================
-- TAB: MAIN
-- ================================================================
Main:CreateSection("Usuario & Servidor")
Main:CreateButton({
    Name = "Reconectar Servidor (Rejoin)",
    Callback = function()
        game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
    end,
})
Main:CreateButton({
    Name = "Copiar Nombre de Jugador",
    Callback = function()
        setclipboard(LocalPlayer.Name)
        Aquafield:Notify({ Title = "Copiado", Content = LocalPlayer.Name, Duration = 2 })
    end,
})

-- ================================================================
-- SISTEMA DE FARMS (CHARCOS + AUTO ROB)
-- ================================================================
local FarmSystem = {
    PuddleThread = nil,
    RobThread = nil,
}

-- 1. Farm de Charcos
local function getPuddlePart(obj)
    if not obj then return nil end
    if obj:IsA("BasePart") then return obj end
    if obj:IsA("Model") then return obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart", true) end
    return obj:FindFirstChildWhichIsA("BasePart", true)
end

local function isPuddleVisible(part)
    return part and part.Parent and part.Transparency < 0.85
end

local function findPuddles()
    local list = {}
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj.Name == "SmallPuddle" or obj.Name == "LargePuddle" then
            local part = getPuddlePart(obj)
            if isPuddleVisible(part) then
                local wTime = (obj.Name == "LargePuddle") and 10.2 or 5.2
                table.insert(list, { object = obj, part = part, waitTime = wTime })
            end
        end
    end
    return list
end

local function moveToPuddle(part)
    local hum, root = getHum(), getRoot()
    if not hum or not root or not part then return false end
    local dest = part.Position + Vector3.new(0, 1.5, 0)
    
    local path = PathfindingService:CreatePath({
        AgentRadius = 2, AgentHeight = 5, AgentCanJump = true, WaypointSpacing = 4,
    })
    local ok = pcall(function() path:ComputeAsync(root.Position, dest) end)
    if ok and path.Status == Enum.PathStatus.Success then
        local waypoints = path:GetWaypoints()
        for _, wp in ipairs(waypoints) do
            if not Config.PuddleFarm or not part.Parent then return false end
            hum:MoveTo(wp.Position)
            if wp.Action == Enum.PathWaypointAction.Jump then hum.Jump = true end
            local t0 = os.clock()
            while Config.PuddleFarm and (root.Position - wp.Position).Magnitude > 4 do
                if os.clock() - t0 > 3.5 then break end
                task.wait(0.08)
            end
        end
    else
        hum:MoveTo(dest)
        local t0 = os.clock()
        while Config.PuddleFarm and (root.Position - dest).Magnitude > 5 do
            if os.clock() - t0 > 8 then break end
            task.wait(0.1)
        end
    end
    return (root.Position - dest).Magnitude <= 8
end

local function cleanPuddleWait(part, waitTime)
    local t0 = os.clock()
    while Config.PuddleFarm and part and part.Parent and isPuddleVisible(part) do
        if os.clock() - t0 >= waitTime then break end
        task.wait(0.2)
    end
end

local function runPuddleFarm()
    task.spawn(function()
        while Config.PuddleFarm do
            local targets = findPuddles()
            local root = getRoot()
            if root and #targets > 0 then
                table.sort(targets, function(a, b)
                    return (root.Position - a.part.Position).Magnitude < (root.Position - b.part.Position).Magnitude
                end)
                for _, target in ipairs(targets) do
                    if not Config.PuddleFarm then break end
                    if target.part and target.part.Parent and isPuddleVisible(target.part) then
                        local dist = (root.Position - target.part.Position).Magnitude
                        if dist <= Config.FarmRange then
                            if moveToPuddle(target.part) then
                                cleanPuddleWait(target.part, target.waitTime)
                            end
                        end
                    end
                end
            end
            task.wait(1)
        end
    end)
end

-- 2. Auto Rob Aéreo (Por arriba en el cielo/aire, sin ir abajo del mapa)
local RobState = {
    RobbedPeds = {},
}

local function findBestPedestrian()
    local pedsFolder = workspace:FindFirstChild("Pedestrians") or workspace:FindFirstChild("NPCs") or workspace
    local myRoot = getRoot()
    if not myRoot then return nil, nil end

    local cops = {}
    for _, obj in ipairs(pedsFolder:GetDescendants()) do
        if obj:IsA("Model") and obj.Name:find("Police") then
            local r = obj:FindFirstChild("HumanoidRootPart") or obj.PrimaryPart
            if r then table.insert(cops, r.Position) end
        end
    end

    local bestPed, bestDist = nil, math.huge
    for _, obj in ipairs(pedsFolder:GetDescendants()) do
        if obj:IsA("Model") and obj ~= getChar() and not obj.Name:find("Police") then
            local hum = obj:FindFirstChildOfClass("Humanoid")
            local r = obj:FindFirstChild("HumanoidRootPart") or obj.PrimaryPart
            local prompt = obj:FindFirstChildWhichIsA("ProximityPrompt", true) or (r and r:FindFirstChild("PromptDirect"))
            if hum and hum.Health > 0 and r and prompt and not obj:GetAttribute("Ragdolled") then
                local lastRob = RobState.RobbedPeds[obj] or 0
                if os.clock() - lastRob > 120 then
                    local isSafe = true
                    for _, cp in ipairs(cops) do
                        if (cp - r.Position).Magnitude < 70 then
                            isSafe = false
                            break
                        end
                    end
                    if isSafe then
                        local d = (myRoot.Position - r.Position).Magnitude
                        if d < bestDist then
                            bestDist = d
                            bestPed = { model = obj, root = r, prompt = prompt }
                        end
                    end
                end
            end
        end
    end
    return bestPed
end

local function flyToAir(targetPos, speed)
    local root = getRoot()
    if not root then return false end
    local hum = getHum()
    if hum and hum.SeatPart then hum.Sit = false task.wait(0.2) end

    -- Vuelo suave por el aire (arriba)
    local t0 = os.clock()
    while Config.AutoRob and (root.Position - targetPos).Magnitude > 3 do
        if os.clock() - t0 > 12 then break end
        local dir = (targetPos - root.Position)
        local step = math.min(dir.Magnitude, (speed or 50) * RunService.Heartbeat:Wait())
        root.CFrame = CFrame.new(root.Position + dir.Unit * step, targetPos)
        root.AssemblyLinearVelocity = Vector3.zero
    end
    return (root.Position - targetPos).Magnitude <= 5
end

local function triggerRobPrompt(ped)
    pcall(function()
        if ped.prompt:IsA("ProximityPrompt") then
            fireproximityprompt(ped.prompt)
        elseif ped.root:FindFirstChild("PromptDirect") then
            local pd = ped.root:FindFirstChild("PromptDirect")
            local m = pd and pd:IsA("ObjectValue") and pd.Value
            if m and m:IsA("ModuleScript") then
                local ok, mod = pcall(require, m)
                if ok and type(mod) == "table" then
                    for _, k in ipairs({"OnPrompt", "Prompt", "Triggered", "Interact", "Start"}) do
                        if type(mod[k]) == "function" then
                            task.spawn(pcall, mod[k], ped.root)
                            break
                        end
                    end
                elseif ok and type(mod) == "function" then
                    task.spawn(pcall, mod, ped.root)
                end
            end
        end
    end)
end

local function runAutoRob()
    task.spawn(function()
        while Config.AutoRob do
            local root = getRoot()
            if root then
                local ped = findBestPedestrian()
                if ped and ped.root and ped.root.Parent then
                    -- 1. Viajar por ARRIBA en el aire (evita policías y obstáculos bajo el mapa)
                    local airHeight = Config.RobHeight or 15
                    local airPos = ped.root.Position + Vector3.new(0, airHeight, 0)
                    flyToAir(airPos, Config.RobSpeed or 50)

                    if not Config.AutoRob then break end

                    -- 2. Bajar justo detrás del peatón para ejecutar el robo
                    local groundPos = ped.root.Position - (ped.root.CFrame.LookVector * 2.2) + Vector3.new(0, 0.5, 0)
                    root.CFrame = CFrame.new(groundPos, ped.root.Position)
                    task.wait(0.1)

                    -- 3. Activar el robo
                    triggerRobPrompt(ped)
                    RobState.RobbedPeds[ped.model] = os.clock()

                    -- Mantener cerca brevemente durante la interacción
                    local robTime = os.clock()
                    while Config.AutoRob and os.clock() - robTime < 3.5 do
                        if ped.root and ped.root.Parent then
                            root.CFrame = CFrame.new(ped.root.Position - (ped.root.CFrame.LookVector * 2.2), ped.root.Position)
                            root.AssemblyLinearVelocity = Vector3.zero
                        end
                        RunService.Heartbeat:Wait()
                    end

                    -- 4. Volver inmediatamente hacia ARRIBA (al aire para estar seguro)
                    if root then
                        local safeAir = root.Position + Vector3.new(0, airHeight, 0)
                        flyToAir(safeAir, 60)
                    end
                else
                    -- Flotar seguro arriba si no hay peatones cercanos
                    root.CFrame = root.CFrame + Vector3.new(0, 0.2, 0)
                    root.AssemblyLinearVelocity = Vector3.zero
                end
            end
            task.wait(0.6)
        end
    end)
end

-- ================================================================
-- CONTROLES EN PESTAÑA FARM (AUTO ROB ARRIBA + CHARCOS)
-- ================================================================
FarmTab:CreateSection("Auto Rob Peatones (Aéreo / Por Arriba)")
FarmTab:CreateToggle({
    Name = "Auto Rob (Robar por Arriba)",
    CurrentValue = Config.AutoRob,
    Flag = "AutoRobAir",
    Callback = function(state)
        Config.AutoRob = state
        if state then
            runAutoRob()
            Aquafield:Notify({ Title = "Auto Rob", Content = "Auto Rob aéreo activado (volando por arriba)", Duration = 3 })
        end
    end,
})

FarmTab:CreateSlider({
    Name = "Altura en el Aire (Vuelo)",
    Range = {8, 40},
    Increment = 1,
    Suffix = " studs arriba",
    CurrentValue = Config.RobHeight or 15,
    Flag = "RobHeight",
    Callback = function(v)
        Config.RobHeight = v
    end,
})

FarmTab:CreateSlider({
    Name = "Velocidad de Vuelo Rob",
    Range = {20, 100},
    Increment = 5,
    Suffix = " spd",
    CurrentValue = Config.RobSpeed or 50,
    Flag = "RobSpeed",
    Callback = function(v)
        Config.RobSpeed = v
    end,
})

FarmTab:CreateButton({
    Name = "Detener Auto Rob",
    Callback = function()
        Config.AutoRob = false
        Aquafield:Notify({ Title = "Auto Rob", Content = "Auto Rob detenido.", Duration = 2 })
    end,
})

FarmTab:CreateSection("AutoFarm Limpieza de Charcos")
FarmTab:CreateToggle({
    Name = "AutoFarm Charcos (Small/Large)",
    CurrentValue = Config.PuddleFarm,
    Flag = "PuddleFarm",
    Callback = function(state)
        Config.PuddleFarm = state
        if state then
            runPuddleFarm()
            Aquafield:Notify({ Title = "Farm", Content = "AutoFarm de charcos activado", Duration = 3 })
        end
    end,
})

FarmTab:CreateSlider({
    Name = "Rango de Charcos",
    Range = {100, 8000},
    Increment = 100,
    Suffix = " studs",
    CurrentValue = Config.FarmRange,
    Flag = "FarmRange",
    Callback = function(v)
        Config.FarmRange = v
    end,
})

FarmTab:CreateButton({
    Name = "Detener Farm de Charcos",
    Callback = function()
        Config.PuddleFarm = false
        Aquafield:Notify({ Title = "Farm", Content = "Farm de charcos detenido", Duration = 2 })
    end,
})

FarmTab:CreateSection("Control General de Farms")
FarmTab:CreateButton({
    Name = "Detener Todos los Auto Farms",
    Callback = function()
        Config.PuddleFarm = false
        Config.AutoRob = false
        Aquafield:Notify({ Title = "Farms", Content = "Todos los farms se han detenido.", Duration = 3 })
    end,
})

-- ================================================================
-- SISTEMA DE COMBATE (AIMBOT, HITBOX, WEAPON MODS, VISUALIZE)
-- ================================================================
local CombatSystem = {
    CurrentTarget = nil,
    TargetPart = nil,
}

-- FOV Circle Drawing
local FOVCircle = nil
pcall(function()
    if Drawing and Drawing.new then
        FOVCircle = Drawing.new("Circle")
        FOVCircle.Thickness = 1.5
        FOVCircle.NumSides = 32
        FOVCircle.Radius = Config.AimFOV
        FOVCircle.Filled = false
        FOVCircle.Visible = false
        FOVCircle.Color = Color3.fromRGB(0, 220, 255)
    end
end)

-- Target Tracer Line Drawing
local TargetLine = nil
pcall(function()
    if Drawing and Drawing.new then
        TargetLine = Drawing.new("Line")
        TargetLine.Thickness = 1.5
        TargetLine.Color = Color3.fromRGB(255, 50, 50)
        TargetLine.Visible = false
    end
end)

-- Aimbot Target Finder
local function getAimbotTarget()
    local best = nil
    local bestScore = math.huge
    local myRoot = getRoot()
    if not myRoot then return nil, nil end

    local mousePos = UserInputService:GetMouseLocation()

    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character then
            local char = p.Character
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health > 0 then
                -- Skip safe zone
                local inSafe = char:GetAttribute("SafeZone") == true or char:FindFirstChild("ForceField") ~= nil
                if not (Config.SkipSafe and inSafe) then
                    local pPart = char:FindFirstChild(Config.AimPart) or char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
                    if pPart then
                        local screenPos, onScreen = Camera:WorldToViewportPoint(pPart.Position)
                        if onScreen then
                            local dist2D = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
                            if dist2D <= Config.AimFOV then
                                local score = dist2D
                                if Config.AimPriority == "Lowest HP" then
                                    score = hum.Health
                                elseif Config.AimPriority == "Highest HP" then
                                    score = -hum.Health
                                end
                                if score < bestScore then
                                    bestScore = score
                                    best = p
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    if best and best.Character then
        local part = best.Character:FindFirstChild(Config.AimPart) or best.Character:FindFirstChild("Head")
        return best, part
    end
    return nil, nil
end

-- Aimbot Input Handlers
UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == Config.AimKey or input.UserInputType == Enum.UserInputType.MouseButton2 then
        Config.AimHolding = true
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.KeyCode == Config.AimKey or input.UserInputType == Enum.UserInputType.MouseButton2 then
        Config.AimHolding = false
    end
end)

-- Hitbox Expander
local HitboxState = {
    Originals = setmetatable({}, { __mode = "k" }),
}
local function applyHitbox()
    if not Config.Hitbox then return end
    local want = Vector3.new(Config.HitboxSize, Config.HitboxSize, Config.HitboxSize)
    local partName = (Config.HitboxPart == "Body") and "HumanoidRootPart" or "Head"

    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character then
            local char = p.Character
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health > 0 then
                local pt = char:FindFirstChild(partName)
                if pt and pt:IsA("BasePart") then
                    if not HitboxState.Originals[pt] then
                        HitboxState.Originals[pt] = { pt.Size, pt.Transparency, pt.CanCollide }
                    end
                    pt.Size = want
                    pt.Transparency = 0.6
                    pt.CanCollide = false
                end
            end
        end
    end
end

local function restoreHitboxes()
    for pt, orig in pairs(HitboxState.Originals) do
        if pt and pt.Parent then
            pcall(function()
                pt.Size = orig[1]
                pt.Transparency = orig[2]
                pt.CanCollide = orig[3]
            end)
        end
    end
    HitboxState.Originals = setmetatable({}, { __mode = "k" })
end

-- Weapon Mods (No Recoil, Spread, Full Auto, Instant Reload, RPM)
local GunMods = {}
local PROBE = { "FireRate", "RPM", "Recoil", "Spread", "Damage", "Ammo", "ClipSize", "ReloadTime", "Automatic" }

function GunMods.scanAndPatch()
    pcall(function()
        local char = getChar()
        if not char then return end
        local tool = char:FindFirstChildOfClass("Tool")
        if not tool then return end

        for _, desc in ipairs(tool:GetDescendants()) do
            if desc:IsA("ModuleScript") then
                local ok, mod = pcall(require, desc)
                if ok and type(mod) == "table" then
                    for k, v in pairs(mod) do
                        local lk = tostring(k):lower()
                        if Config.NoRecoil and lk:find("recoil") then
                            if type(v) == "number" then mod[k] = 0 end
                            if type(v) == "Vector3" then mod[k] = Vector3.zero end
                        end
                        if Config.NoSpread and lk:find("spread") then
                            if type(v) == "number" then mod[k] = 0 end
                        end
                        if Config.FullAuto and (lk == "auto" or lk == "automatic" or lk:find("mode")) then
                            mod[k] = true
                        end
                        if Config.FastReload and lk:find("reload") and type(v) == "number" then
                            mod[k] = 0.05
                        end
                        if Config.RPM and (lk:find("rpm") or lk:find("firerate")) and type(v) == "number" then
                            mod[k] = Config.RPMValue
                        end
                    end
                end
            end
        end
    end)
end

-- RenderStepped Combat Loop
RunService.RenderStepped:Connect(function()
    -- FOV Circle
    if FOVCircle then
        FOVCircle.Visible = Config.ShowFOV and Config.Aimbot
        if FOVCircle.Visible then
            local mouse = UserInputService:GetMouseLocation()
            FOVCircle.Position = mouse
            FOVCircle.Radius = Config.AimFOV
        end
    end

    -- Hitbox Expander Tick
    if Config.Hitbox then
        applyHitbox()
    end

    -- Weapon Mods Apply
    if Config.NoRecoil or Config.NoSpread or Config.FullAuto or Config.FastReload or Config.RPM then
        GunMods.scanAndPatch()
    end

    -- Aimbot Tick
    if Config.Aimbot then
        local target, part = getAimbotTarget()
        CombatSystem.CurrentTarget = target
        CombatSystem.TargetPart = part

        if Config.AimHolding and part then
            local aimPos = part.Position
            if Config.AimSmooth > 0 then
                local curCF = Camera.CFrame
                local targetCF = CFrame.new(curCF.Position, aimPos)
                Camera.CFrame = curCF:Lerp(targetCF, math.clamp(1 - (Config.AimSmooth / 20), 0.05, 1))
            else
                Camera.CFrame = CFrame.new(Camera.CFrame.Position, aimPos)
            end
        end

        -- Target Line
        if TargetLine then
            if Config.TargetLine and part then
                local sp, onScreen = Camera:WorldToViewportPoint(part.Position)
                if onScreen then
                    local vp = Camera.ViewportSize
                    TargetLine.From = Vector2.new(vp.X / 2, vp.Y / 2)
                    TargetLine.To = Vector2.new(sp.X, sp.Y)
                    TargetLine.Visible = true
                else
                    TargetLine.Visible = false
                end
            else
                TargetLine.Visible = false
            end
        end
    else
        CombatSystem.CurrentTarget = nil
        CombatSystem.TargetPart = nil
        if TargetLine then TargetLine.Visible = false end
    end
end)

-- CONTROLES EN PESTAÑA COMBAT
CombatTab:CreateSection("Aimbot (Camera Lock)")
CombatTab:CreateToggle({
    Name = "Enable Aimbot",
    CurrentValue = Config.Aimbot,
    Flag = "Aimbot",
    Callback = function(v)
        Config.Aimbot = v
    end,
})

CombatTab:CreateToggle({
    Name = "Smart Hit (Head / Window)",
    CurrentValue = Config.SmartHit,
    Flag = "SmartHit",
    Callback = function(v)
        Config.SmartHit = v
    end,
})

CombatTab:CreateToggle({
    Name = "Skip Safe Zone Players",
    CurrentValue = Config.SkipSafe,
    Flag = "SkipSafe",
    Callback = function(v)
        Config.SkipSafe = v
    end,
})

CombatTab:CreateSlider({
    Name = "Aimbot FOV",
    Range = {20, 800},
    Increment = 10,
    Suffix = " px",
    CurrentValue = Config.AimFOV,
    Flag = "AimFOV",
    Callback = function(v)
        Config.AimFOV = v
    end,
})

CombatTab:CreateSlider({
    Name = "Smoothness (Suavizado)",
    Range = {0, 18},
    Increment = 1,
    Suffix = "",
    CurrentValue = Config.AimSmooth,
    Flag = "AimSmooth",
    Callback = function(v)
        Config.AimSmooth = v
    end,
})

CombatTab:CreateDropdown({
    Name = "Target Hitbox Part",
    Options = {"Head", "HumanoidRootPart"},
    CurrentOption = Config.AimPart,
    Flag = "AimPart",
    Callback = function(opt)
        Config.AimPart = opt
    end,
})

CombatTab:CreateDropdown({
    Name = "Aim Priority",
    Options = {"Closest", "Lowest HP", "Highest HP"},
    CurrentOption = Config.AimPriority,
    Flag = "AimPriority",
    Callback = function(opt)
        Config.AimPriority = opt
    end,
})

CombatTab:CreateKeybind({
    Name = "Aimbot Keybind (Aim Key)",
    CurrentKeybind = "E",
    Flag = "AimKey",
    Callback = function(key)
        Config.AimKey = key
    end,
})

CombatTab:CreateSection("Hitbox Expander")
CombatTab:CreateToggle({
    Name = "Enable Hitbox Expander",
    CurrentValue = Config.Hitbox,
    Flag = "Hitbox",
    Callback = function(v)
        Config.Hitbox = v
        if not v then restoreHitboxes() end
    end,
})

CombatTab:CreateSlider({
    Name = "Hitbox Size",
    Range = {2, 25},
    Increment = 1,
    Suffix = " studs",
    CurrentValue = Config.HitboxSize,
    Flag = "HitboxSize",
    Callback = function(v)
        Config.HitboxSize = v
    end,
})

CombatTab:CreateDropdown({
    Name = "Hitbox Part",
    Options = {"Head", "Body"},
    CurrentOption = Config.HitboxPart,
    Flag = "HitboxPartOption",
    Callback = function(v)
        Config.HitboxPart = v
        restoreHitboxes()
    end,
})

CombatTab:CreateSection("Weapon Mods")
CombatTab:CreateToggle({
    Name = "No Recoil",
    CurrentValue = Config.NoRecoil,
    Flag = "NoRecoil",
    Callback = function(v) Config.NoRecoil = v end,
})

CombatTab:CreateToggle({
    Name = "No Spread",
    CurrentValue = Config.NoSpread,
    Flag = "NoSpread",
    Callback = function(v) Config.NoSpread = v end,
})

CombatTab:CreateToggle({
    Name = "Full Automatic",
    CurrentValue = Config.FullAuto,
    Flag = "FullAuto",
    Callback = function(v) Config.FullAuto = v end,
})

CombatTab:CreateToggle({
    Name = "Instant Reload",
    CurrentValue = Config.FastReload,
    Flag = "FastReload",
    Callback = function(v) Config.FastReload = v end,
})

CombatTab:CreateToggle({
    Name = "Custom Fire Rate (RPM)",
    CurrentValue = Config.RPM,
    Flag = "RPM",
    Callback = function(v) Config.RPM = v end,
})

CombatTab:CreateSlider({
    Name = "Fire Rate (RPM)",
    Range = {100, 2000},
    Increment = 25,
    Suffix = " rpm",
    CurrentValue = Config.RPMValue,
    Flag = "RPMValue",
    Callback = function(v) Config.RPMValue = v end,
})

CombatTab:CreateButton({
    Name = "Rescan Weapons / Gun",
    Callback = function()
        GunMods.scanAndPatch()
        Aquafield:Notify({ Title = "Gun Mods", Content = "Arma reescaneada y parcheada.", Duration = 2 })
    end,
})

CombatTab:CreateSection("Combat Visualization")
CombatTab:CreateToggle({
    Name = "Show FOV Circle",
    CurrentValue = Config.ShowFOV,
    Flag = "ShowFOV",
    Callback = function(v) Config.ShowFOV = v end,
})

CombatTab:CreateToggle({
    Name = "Target Highlight",
    CurrentValue = Config.TargetHL,
    Flag = "TargetHL",
    Callback = function(v) Config.TargetHL = v end,
})

CombatTab:CreateToggle({
    Name = "Target Line to Enemy",
    CurrentValue = Config.TargetLine,
    Flag = "TargetLine",
    Callback = function(v) Config.TargetLine = v end,
})

-- ================================================================
-- SISTEMA VISUALS (PLAYER ESP, HEALTH BAR, OBJETOS DROPS TXT)
-- ================================================================
local VisualSystem = {
    PlayerCache = {},
    DropCache = {},
}

-- Colores dinámicos para Health Bar
local function getHealthColor(percent)
    if percent > 0.75 then
        return Color3.fromRGB(80, 230, 90)
    elseif percent > 0.45 then
        return Color3.fromRGB(240, 210, 40)
    elseif percent > 0.20 then
        return Color3.fromRGB(255, 120, 30)
    else
        return Color3.fromRGB(255, 50, 50)
    end
end

-- Crear estructura ESP para jugador
local function createPlayerESP(player)
    if player == LocalPlayer then return end
    local data = {}

    local bb = Instance.new("BillboardGui")
    bb.Name = "AquaESP_" .. player.Name
    bb.AlwaysOnTop = true
    bb.Size = UDim2.new(0, 180, 0, 90)
    bb.StudsOffset = Vector3.new(0, 2.5, 0)
    bb.Adornee = nil
    bb.Enabled = false
    bb.ResetOnSpawn = false
    pcall(function() bb.Parent = game:GetService("CoreGui") end)
    if not bb.Parent then bb.Parent = LocalPlayer:WaitForChild("PlayerGui") end

    -- Nombre y estado
    local nameLbl = Instance.new("TextLabel")
    nameLbl.Size = UDim2.new(1, 0, 0, 16)
    nameLbl.Position = UDim2.new(0, 0, 0, 0)
    nameLbl.BackgroundTransparency = 1
    nameLbl.Font = Enum.Font.GothamBold
    nameLbl.TextSize = 13
    nameLbl.TextColor3 = Config.DefaultColor
    nameLbl.TextStrokeTransparency = 0.2
    nameLbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    nameLbl.Text = player.DisplayName or player.Name
    nameLbl.Parent = bb

    -- Distancia & HP %
    local infoLbl = Instance.new("TextLabel")
    infoLbl.Size = UDim2.new(1, 0, 0, 14)
    infoLbl.Position = UDim2.new(0, 0, 0, 16)
    infoLbl.BackgroundTransparency = 1
    infoLbl.Font = Enum.Font.GothamMedium
    infoLbl.TextSize = 11
    infoLbl.TextColor3 = Color3.fromRGB(200, 230, 255)
    infoLbl.TextStrokeTransparency = 0.3
    infoLbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    infoLbl.Text = "[0M] [100%]"
    infoLbl.Parent = bb

    -- Health Bar Frame (Contenedor con borde negro)
    local hpBg = Instance.new("Frame")
    hpBg.Size = UDim2.new(0, 110, 0, 6)
    hpBg.Position = UDim2.new(0.5, -55, 0, 32)
    hpBg.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    hpBg.BorderSizePixel = 1
    hpBg.BorderColor3 = Color3.fromRGB(0, 0, 0)
    hpBg.Parent = bb

    local hpFill = Instance.new("Frame")
    hpFill.Size = UDim2.new(1, 0, 1, 0)
    hpFill.BackgroundColor3 = Color3.fromRGB(80, 230, 90)
    hpFill.BorderSizePixel = 0
    hpFill.Parent = hpBg

    local hpTxt = Instance.new("TextLabel")
    hpTxt.Size = UDim2.new(1, 0, 0, 12)
    hpTxt.Position = UDim2.new(0, 0, 0, 40)
    hpTxt.BackgroundTransparency = 1
    hpTxt.Font = Enum.Font.GothamBold
    hpTxt.TextSize = 10
    hpTxt.TextColor3 = Color3.fromRGB(80, 230, 90)
    hpTxt.TextStrokeTransparency = 0.3
    hpTxt.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    hpTxt.Text = "HP: 100/100"
    hpTxt.Parent = bb

    -- Arma equipada
    local toolLbl = Instance.new("TextLabel")
    toolLbl.Size = UDim2.new(1, 0, 0, 14)
    toolLbl.Position = UDim2.new(0, 0, 0, 52)
    toolLbl.BackgroundTransparency = 1
    toolLbl.Font = Enum.Font.GothamMedium
    toolLbl.TextSize = 11
    toolLbl.TextColor3 = Color3.fromRGB(255, 215, 0)
    toolLbl.TextStrokeTransparency = 0.3
    toolLbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    toolLbl.Text = "[Fists]"
    toolLbl.Parent = bb

    -- Chams Highlight
    local hl = Instance.new("Highlight")
    hl.Name = "AquaChams_" .. player.Name
    hl.FillColor = Color3.fromRGB(255, 40, 40)
    hl.OutlineColor = Color3.fromRGB(255, 255, 255)
    hl.FillTransparency = 0.5
    hl.OutlineTransparency = 0.1
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Enabled = false
    pcall(function() hl.Parent = game:GetService("CoreGui") end)
    if not hl.Parent then hl.Parent = LocalPlayer:WaitForChild("PlayerGui") end

    data.Gui = bb
    data.NameLbl = nameLbl
    data.InfoLbl = infoLbl
    data.HpBg = hpBg
    data.HpFill = hpFill
    data.HpTxt = hpTxt
    data.ToolLbl = toolLbl
    data.Chams = hl

    VisualSystem.PlayerCache[player] = data
end

local function removePlayerESP(player)
    local data = VisualSystem.PlayerCache[player]
    if data then
        if data.Gui then data.Gui:Destroy() end
        if data.Chams then data.Chams:Destroy() end
        VisualSystem.PlayerCache[player] = nil
    end
end

for _, p in ipairs(Players:GetPlayers()) do createPlayerESP(p) end
Players.PlayerAdded:Connect(createPlayerESP)
Players.PlayerRemoving:Connect(removePlayerESP)

-- Actualización de Player ESP
RunService.RenderStepped:Connect(function()
    local myRoot = getRoot()
    if not myRoot then return end

    for p, data in pairs(VisualSystem.PlayerCache) do
        local char = p.Character
        local head = char and char:FindFirstChild("Head")
        local hum = char and char:FindFirstChildOfClass("Humanoid")

        if Config.ESP and char and head and hum and hum.Health > 0 then
            local dist = (myRoot.Position - head.Position).Magnitude
            if dist <= Config.ESPRange then
                data.Gui.Adornee = head
                data.Gui.Enabled = true

                -- Nombres y estados
                local status = ""
                if char:GetAttribute("TimeKnocked") or hum.Health <= 15 then
                    status = " [KO]"
                elseif char:GetAttribute("SafeZone") then
                    status = " [SAFE]"
                elseif hum.SeatPart then
                    status = " [CAR]"
                end

                data.NameLbl.Visible = Config.ShowName
                data.NameLbl.Text = (p.DisplayName or p.Name) .. (Config.ESPStatus and status or "")
                data.NameLbl.TextColor3 = Config.DefaultColor

                -- HP bar y porcentaje
                local maxHp = hum.MaxHealth > 0 and hum.MaxHealth or 100
                local curHp = math.clamp(hum.Health, 0, maxHp)
                local hpPct = curHp / maxHp
                local hpCol = getHealthColor(hpPct)

                data.HpBg.Visible = Config.ShowHealth
                data.HpFill.Size = UDim2.new(hpPct, 0, 1, 0)
                data.HpFill.BackgroundColor3 = hpCol
                data.HpTxt.Visible = Config.ShowHealth
                data.HpTxt.Text = string.format("%d / %d", math.floor(curHp), math.floor(maxHp))
                data.HpTxt.TextColor3 = hpCol

                -- Distancia & %
                data.InfoLbl.Visible = Config.ShowInfo
                data.InfoLbl.Text = string.format("[%dM] [%d%%]", math.floor(dist), math.floor(hpPct * 100))

                -- Herramientas
                local tool = char:FindFirstChildOfClass("Tool")
                local toolName = tool and tool.Name or "Fists"
                data.ToolLbl.Visible = Config.ShowTools
                data.ToolLbl.Text = "[" .. toolName .. "]"

                -- Chams
                data.Chams.Adornee = char
                data.Chams.Enabled = Config.Chams
                if CombatSystem.CurrentTarget == p and Config.TargetHL then
                    data.Chams.FillColor = Color3.fromRGB(255, 0, 0)
                    data.Chams.Enabled = true
                else
                    data.Chams.FillColor = Color3.fromRGB(255, 80, 80)
                end
            else
                data.Gui.Enabled = false
                data.Chams.Enabled = false
            end
        else
            data.Gui.Enabled = false
            data.Chams.Enabled = false
        end
    end
end)

-- Objetos tirados en el suelo (Drops ESP TXT)
local function scanDrops()
    local myRoot = getRoot()
    if not myRoot or not Config.DropESP then return end

    local dropsFolder = workspace:FindFirstChild("Drops") or workspace:FindFirstChild("Debris") or workspace:FindFirstChild("Items") or workspace
    for _, item in ipairs(dropsFolder:GetChildren()) do
        if item:IsA("Tool") or item:IsA("Model") or (item:IsA("BasePart") and item.Size.Magnitude < 10) then
            local part = item:IsA("BasePart") and item or (item.PrimaryPart or item:FindFirstChildWhichIsA("BasePart", true))
            if part and not part:IsDescendantOf(getChar()) and not VisualSystem.DropCache[item] then
                local nm = item.Name:lower()
                local isGun = nm:find("gun") or nm:find("rifle") or nm:find("shotgun") or nm:find("pistol") or nm:find("rpg") or nm:find("ak")
                local isAmmo = nm:find("ammo") or nm:find("box") or nm:find("bullet")
                local isCash = nm:find("cash") or nm:find("money") or nm:find("bag") or nm:find("dollar")
                
                local allow = false
                local color = Color3.fromRGB(255, 255, 255)

                if isGun and Config.ShowGuns then
                    allow = true
                    color = Color3.fromRGB(255, 170, 0)
                elseif isAmmo and Config.ShowAmmo then
                    allow = true
                    color = Color3.fromRGB(0, 200, 255)
                elseif isCash and Config.ShowMoney then
                    allow = true
                    color = Color3.fromRGB(80, 240, 100)
                elseif Config.ShowMisc then
                    allow = true
                    color = Color3.fromRGB(220, 220, 220)
                end

                if allow then
                    local bb = Instance.new("BillboardGui")
                    bb.Name = "AquaDrop_" .. item.Name
                    bb.AlwaysOnTop = true
                    bb.Size = UDim2.new(0, 120, 0, 20)
                    bb.Adornee = part
                    bb.ResetOnSpawn = false

                    local lbl = Instance.new("TextLabel")
                    lbl.Size = UDim2.new(1, 0, 1, 0)
                    lbl.BackgroundTransparency = 1
                    lbl.Font = Enum.Font.GothamBold
                    lbl.TextSize = 10
                    lbl.TextColor3 = color
                    lbl.TextStrokeTransparency = 0.3
                    lbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
                    lbl.Text = string.format("[%s]", item.Name)
                    lbl.Parent = bb

                    pcall(function() bb.Parent = game:GetService("CoreGui") end)
                    if not bb.Parent then bb.Parent = LocalPlayer:WaitForChild("PlayerGui") end

                    VisualSystem.DropCache[item] = { Gui = bb, Part = part, Lbl = lbl }
                end
            end
        end
    end
end

task.spawn(function()
    while true do
        if Config.DropESP then scanDrops() end
        task.wait(1.5)
    end
end)

-- CONTROLES EN PESTAÑA VISUALS
VisualsTab:CreateSection("Player ESP (Visuales de Jugadores)")
VisualsTab:CreateToggle({
    Name = "Enable Player ESP",
    CurrentValue = Config.ESP,
    Flag = "EnableESP",
    Callback = function(v) Config.ESP = v end,
})

VisualsTab:CreateToggle({
    Name = "Health Bar (Barra de Vida Dinámica)",
    CurrentValue = Config.ShowHealth,
    Flag = "ShowHealth",
    Callback = function(v) Config.ShowHealth = v end,
})

VisualsTab:CreateToggle({
    Name = "Username (Nombres)",
    CurrentValue = Config.ShowName,
    Flag = "ShowName",
    Callback = function(v) Config.ShowName = v end,
})

VisualsTab:CreateToggle({
    Name = "Status Tags ([KO] [SAFE] [CAR])",
    CurrentValue = Config.ESPStatus,
    Flag = "ESPStatus",
    Callback = function(v) Config.ESPStatus = v end,
})

VisualsTab:CreateToggle({
    Name = "Distance & HP % ([13M] [100%])",
    CurrentValue = Config.ShowInfo,
    Flag = "ShowInfo",
    Callback = function(v) Config.ShowInfo = v end,
})

VisualsTab:CreateToggle({
    Name = "Show Weapons / Guns (Armas)",
    CurrentValue = Config.ShowTools,
    Flag = "ShowTools",
    Callback = function(v) Config.ShowTools = v end,
})

VisualsTab:CreateToggle({
    Name = "Player Chams (Paredes Highlight)",
    CurrentValue = Config.Chams,
    Flag = "Chams",
    Callback = function(v) Config.Chams = v end,
})

VisualsTab:CreateSlider({
    Name = "Player ESP Range",
    Range = {100, 6000},
    Increment = 50,
    Suffix = " studs",
    CurrentValue = Config.ESPRange,
    Flag = "ESPRange",
    Callback = function(v) Config.ESPRange = v end,
})

VisualsTab:CreateColorPicker({
    Name = "ESP Base Color",
    Color = Config.DefaultColor,
    Flag = "ESPColor",
    Callback = function(c) Config.DefaultColor = c end,
})

VisualsTab:CreateButton({
    Name = "Rebuild ESP (Refrescar Jugadores)",
    Callback = function()
        for p in pairs(VisualSystem.PlayerCache) do removePlayerESP(p) end
        for _, p in ipairs(Players:GetPlayers()) do createPlayerESP(p) end
        Aquafield:Notify({ Title = "Visuals", Content = "ESP reconstruido exitosamente.", Duration = 2 })
    end,
})

VisualsTab:CreateSection("Objects & Drops ESP (TXT Suelo)")
VisualsTab:CreateToggle({
    Name = "Enable Ground Drop ESP",
    CurrentValue = Config.DropESP,
    Flag = "DropESP",
    Callback = function(v)
        Config.DropESP = v
        if not v then
            for item, data in pairs(VisualSystem.DropCache) do
                if data.Gui then data.Gui:Destroy() end
            end
            VisualSystem.DropCache = {}
        end
    end,
})

VisualsTab:CreateToggle({
    Name = "Show Ground Guns",
    CurrentValue = Config.ShowGuns,
    Flag = "ShowGuns",
    Callback = function(v) Config.ShowGuns = v end,
})

VisualsTab:CreateToggle({
    Name = "Show Ground Ammo",
    CurrentValue = Config.ShowAmmo,
    Flag = "ShowAmmo",
    Callback = function(v) Config.ShowAmmo = v end,
})

VisualsTab:CreateToggle({
    Name = "Show Ground Money / Cash",
    CurrentValue = Config.ShowMoney,
    Flag = "ShowMoney",
    Callback = function(v) Config.ShowMoney = v end,
})

VisualsTab:CreateToggle({
    Name = "Show Misc Items",
    CurrentValue = Config.ShowMisc,
    Flag = "ShowMisc",
    Callback = function(v) Config.ShowMisc = v end,
})

VisualsTab:CreateSlider({
    Name = "Ground ESP Range",
    Range = {50, 4000},
    Increment = 50,
    Suffix = " studs",
    CurrentValue = Config.DropRange,
    Flag = "DropRange",
    Callback = function(v) Config.DropRange = v end,
})

-- ================================================================
-- TAB: SETTINGS (TEMAS Y APARIENCIA)
-- ================================================================
SettingsTab:CreateSection("Temas de Interfaz")
SettingsTab:CreateButton({
    Name = "Ocean Theme (Por Defecto)",
    Callback = function() Aquafield:SetTheme("Ocean") end,
})

SettingsTab:CreateButton({
    Name = "Matrix Green",
    Callback = function() Aquafield:SetTheme("MatrixGreen") end,
})

SettingsTab:CreateButton({
    Name = "Crimson (Rojo)",
    Callback = function() Aquafield:SetTheme("Crimson") end,
})

SettingsTab:CreateButton({
    Name = "Dark Theme",
    Callback = function() Aquafield:SetTheme("Dark") end,
})

-- Notificación de inicio
Aquafield:Notify({
    Title = "Auto farm Hub Listo",
    Content = "Visuals, Combat y Farm Xd!",
    Duration = 5,
})
