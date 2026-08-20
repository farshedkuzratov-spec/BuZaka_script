-- BuZaka Script v19 (ENGLISH ONLY)
local ApiFTAP = loadstring(game:HttpGet("https://raw.githubusercontent.com/Oxwoey/FTAP-Module/refs/heads/main/Module/ModuleFTAP"))()

local C = {
    Master = true,
    AntiKick = true,
    AntiFling = true,
    AntiGrab = true,
    AntiBlobman = true,
    NoCollide = true,
    AutoRejoin = true,
    ThrowStrength = 50,
    Wings = false,
    Clones = false,
    AutoKick = false,
    Trigger = false,
    TriggerDist = 15,
    ESP = false,
    Water = false,
    Qtp = false,
    SavePos = nil,
}

local R = {
    wings = {}, clones = {}, esp = {}, conns = {}, waterObjects = {},
    waterConn = nil, wingConn = nil, cloneConn = nil, physicsConn = nil,
    autoKickThread = nil,
    rejoinAttempts = 0,
    blobmanCache = {}, playerCache = {},
    cacheConnections = {},
    espList = {},
}

local function dc(c)
    if c and type(c) == "RBXScriptConnection" then pcall(c.Disconnect, c) end
end

local function clearWings()
    for _, c in pairs(R.wings) do if c and c.Parent then c:Destroy() end end
    R.wings = {}; C.Wings = false; dc(R.wingConn)
end

local function clearClones()
    for _, c in pairs(R.clones) do if c and c.Parent then c:Destroy() end end
    R.clones = {}; C.Clones = false; dc(R.cloneConn)
end

local function clearESP()
    for _, data in pairs(R.espList) do
        if data.Box then pcall(data.Box.Remove, data.Box) end
        if data.Name then pcall(data.Name.Remove, data.Name) end
        if data.Conn then dc(data.Conn) end
    end
    R.espList = {}
    R.esp = {}
    for _, c in pairs(R.conns) do dc(c) end
    R.conns = {}
end

local function clearAll()
    clearWings(); clearClones(); clearESP()
    for _, pair in pairs(R.waterObjects) do
        if pair.obj and pair.obj.Parent then pair.obj.CanCollide = pair.original end
    end
    R.waterObjects = {}
    dc(R.waterConn); dc(R.wingConn); dc(R.cloneConn); dc(R.physicsConn)
    if R.autoKickThread then pcall(coroutine.close, R.autoKickThread); R.autoKickThread = nil end
    R.rejoinAttempts = 0
    C.Wings = false; C.Clones = false; C.ESP = false; C.Water = false; C.AutoKick = false
    for _, conn in pairs(R.cacheConnections) do dc(conn) end
    R.cacheConnections = {}
    R.blobmanCache = {}
    R.playerCache = {}
    R.espList = {}
end

game.Players.LocalPlayer.CharacterAdded:Connect(clearAll)
pcall(function() game:GetService("TeleportService").TeleportStarted:Connect(clearAll) end)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local GuiService = game:GetService("GuiService")
local LocalPlayer = Players.LocalPlayer

local function initHookShield()
    if not hookmetamethod then return end
    local oldNamecall
    oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
        if not C.AntiKick then return oldNamecall(self, ...) end
        local method = getnamecallmethod()
        if self == LocalPlayer and method and method:lower() == "kick" then
            return function() end
        end
        return oldNamecall(self, ...)
    end)
    local oldIndex
    oldIndex = hookmetamethod(game, "__index", function(self, key)
        if not C.AntiKick then return oldIndex(self, key) end
        if self == LocalPlayer and typeof(key) == "string" and key:lower() == "kick" then
            return function() end
        end
        return oldIndex(self, key)
    end)
end

local function breakExternalConstraints(char)
    if not char then return end
    for _, desc in ipairs(char:GetDescendants()) do
        if desc:IsA("Motor6D") then continue end
        if desc:IsA("Constraint") or desc:IsA("Weld") or desc:IsA("WeldConstraint") or desc:IsA("BodyMover") then
            if desc:IsA("WeldConstraint") or desc:IsA("Weld") then
                local p0, p1 = desc.Part0, desc.Part1
                if p0 and p1 and p0.Parent and p1.Parent then
                    if (p0:IsDescendantOf(char) and not p1:IsDescendantOf(char)) or
                       (p1:IsDescendantOf(char) and not p0:IsDescendantOf(char)) then
                        pcall(desc.Destroy, desc)
                    end
                end
            else
                if desc.Parent and not desc.Parent:IsDescendantOf(char) then
                    pcall(desc.Destroy, desc)
                end
            end
        end
    end
end

local function refreshBlobmanCache()
    R.blobmanCache = {}
    for _, obj in ipairs(workspace:GetChildren()) do
        if obj:IsA("Model") and string.lower(obj.Name):find("blobman") and obj.Parent then
            local parts = {}
            for _, part in ipairs(obj:GetDescendants()) do
                if part:IsA("BasePart") and part.Parent then
                    table.insert(parts, part)
                end
            end
            if #parts > 0 then R.blobmanCache[obj] = parts end
        end
    end
end

local function refreshPlayerCache()
    R.playerCache = {}
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character then
            local parts = {}
            for _, part in ipairs(p.Character:GetDescendants()) do
                if part:IsA("BasePart") and part.Parent then
                    table.insert(parts, part)
                end
            end
            if #parts > 0 then R.playerCache[p] = parts end
        end
    end
end

local function updateCache()
    refreshBlobmanCache()
    refreshPlayerCache()
end

local blobmanAddedConn = workspace.ChildAdded:Connect(function(child)
    if child:IsA("Model") and string.lower(child.Name):find("blobman") then
        refreshBlobmanCache()
    end
end)
table.insert(R.cacheConnections, blobmanAddedConn)

local blobmanRemovedConn = workspace.ChildRemoved:Connect(function(child)
    if child:IsA("Model") and string.lower(child.Name):find("blobman") then
        refreshBlobmanCache()
    end
end)
table.insert(R.cacheConnections, blobmanRemovedConn)

local function trackPlayer(player)
    if player == LocalPlayer then return end
    local addedConn = player.CharacterAdded:Connect(refreshPlayerCache)
    local removedConn = player.CharacterRemoving:Connect(refreshPlayerCache)
    table.insert(R.cacheConnections, addedConn)
    table.insert(R.cacheConnections, removedConn)
end

for _, p in pairs(Players:GetPlayers()) do trackPlayer(p) end

local playerAddedConn = Players.PlayerAdded:Connect(function(p)
    trackPlayer(p)
    refreshPlayerCache()
end)
local playerRemovedConn = Players.PlayerRemoving:Connect(refreshPlayerCache)
table.insert(R.cacheConnections, playerAddedConn)
table.insert(R.cacheConnections, playerRemovedConn)

updateCache()

local function startPhysicsShield()
    dc(R.physicsConn)
    R.physicsConn = RunService.Stepped:Connect(function()
        if not C.Master then return end
        local char = LocalPlayer.Character
        if not char then return end
        local hum = char:FindFirstChildOfClass("Humanoid")
        local root = char:FindFirstChild("HumanoidRootPart")

        if hum and hum.Sit then hum.Sit = false end
        if C.AntiFling and root and root.AssemblyLinearVelocity.Magnitude > 150 then
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
        end

        if C.NoCollide and root then
            local radius = 10
            local pos = root.Position
            for _, parts in pairs(R.playerCache) do
                for _, part in ipairs(parts) do
                    if part and part.Parent and (part.Position - pos).Magnitude < radius then
                        part.CanCollide = false
                        part.AssemblyLinearVelocity = Vector3.zero
                        part.AssemblyAngularVelocity = Vector3.zero
                    end
                end
            end
            if C.AntiBlobman then
                for _, parts in pairs(R.blobmanCache) do
                    for _, part in ipairs(parts) do
                        if part and part.Parent and (part.Position - pos).Magnitude < radius then
                            part.CanCollide = false
                        end
                    end
                end
            end
        end

        if C.AntiGrab then
            breakExternalConstraints(char)
        end
    end)
end

local function initAutoRejoin()
    GuiService.ErrorMessageChanged:Connect(function()
        if not C.AutoRejoin or not C.Master then return end
        if R.rejoinAttempts >= 3 then return end
        R.rejoinAttempts = R.rejoinAttempts + 1
        task.wait(2)
        pcall(function()
            if game.JobId and #Players:GetPlayers() > 1 then
                TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
            else
                TeleportService:Teleport(game.PlaceId, LocalPlayer)
            end
        end)
    end)
end

pcall(initHookShield)
pcall(startPhysicsShield)
pcall(initAutoRejoin)

local function updateWater(obj)
    if obj:IsA("BasePart") and (obj.Material == Enum.Material.Water or string.lower(obj.Name):find("water")) and obj.Parent then
        local original = obj.CanCollide
        if C.Water and C.Master then obj.CanCollide = true end
        table.insert(R.waterObjects, {obj = obj, original = original})
    end
end

local function startWaterLoop()
    dc(R.waterConn)
    R.waterObjects = {}
    for _, obj in pairs(workspace:GetDescendants()) do
        if obj and obj.Parent then updateWater(obj) end
    end
    R.waterConn = workspace.ChildAdded:Connect(updateWater)
end

local function startWingLoop()
    dc(R.wingConn)
    R.wingConn = RunService.Heartbeat:Connect(function()
        if not C.Wings or not C.Master or #R.wings == 0 then return end
        local t = tick()
        for _, data in pairs(R.wings) do
            if data.part and data.part.Parent then
                local angle = math.sin(t * 2.5 + data.index * 0.5) * 0.4
                local flap = math.sin(t * 3 + data.index * 0.7) * 0.15
                local rotZ = math.rad(10 * data.index * data.side + angle * 20 + flap * 30)
                local weld = data.part:FindFirstChildOfClass("Weld")
                if weld then
                    weld.C0 = CFrame.new(0, data.offsetY + math.sin(t * 3 + data.index) * 0.05, data.offsetZ) *
                              CFrame.Angles(0, 0, rotZ)
                end
                if data.glow and data.glow.Parent then
                    local pulse = 0.6 + math.sin(t * 3 + data.index) * 0.15
                    data.glow.Size = Vector3.new(pulse, pulse, pulse)
                end
            end
        end
    end)
end

local function startCloneLoop()
    dc(R.cloneConn)
    R.cloneConn = RunService.Heartbeat:Connect(function()
        if not C.Clones or not C.Master or #R.clones == 0 then return end
        local char = LocalPlayer.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if not root or not root.Parent then return end
        local t = tick()
        for i, clone in pairs(R.clones) do
            if clone and clone.Parent then
                local angle = (i - 1) / #R.clones * math.pi * 2 + t * 1.5
                local rad = 5 + math.sin(t * 0.5 + i) * 0.5
                local x = math.cos(angle) * rad
                local z = math.sin(angle) * rad
                local y = math.sin(t * 0.8 + i * 0.5) * 1
                clone.CFrame = root.CFrame * CFrame.new(x, y, z)
                for _, player in pairs(Players:GetPlayers()) do
                    if player ~= LocalPlayer and player.Character then
                        local tr = player.Character:FindFirstChild("HumanoidRootPart")
                        if tr and tr.Parent and (tr.Position - clone.Position).Magnitude < 4 then
                            local dir = (tr.Position - clone.Position).Unit
                            tr.Velocity = dir * 100 + Vector3.new(0, 30, 0)
                        end
                    end
                end
            end
        end
    end)
end

local function kill()
    if not C.Master then return end
    local b
    for _, v in pairs(workspace:GetChildren()) do
        if v:IsA("Model") and v.Parent and string.lower(v.Name):find("blobman") then
            b = v
            break
        end
    end
    if not b or not b.Parent then return end
    pcall(function()
        ApiFTAP.GrabBlobman and ApiFTAP.GrabBlobman(b)
        task.wait(0.05)
        ApiFTAP.KickAura(true)
        task.wait(0.05)
        ApiFTAP.KickAura(false)
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character and p.Character.Parent then
                if ApiFTAP.KillPlayer then pcall(ApiFTAP.KillPlayer, p) end
            end
        end
        ApiFTAP.ReleaseBlobman and ApiFTAP.ReleaseBlobman(b)
    end)
end

local function tpPlayer(name)
    local t = Players:FindFirstChild(name)
    if not t or not t.Character or not t.Character.Parent then return end
    local c = LocalPlayer.Character
    if c and c:FindFirstChild("HumanoidRootPart") and c.Parent then
        c.HumanoidRootPart.CFrame = t.Character.HumanoidRootPart.CFrame + Vector3.new(0, 3, 0)
    end
end

local function tpLook()
    local c = LocalPlayer.Character
    if not c or not c:FindFirstChild("HumanoidRootPart") or not c.Parent then return end
    local root = c.HumanoidRootPart
    local m = LocalPlayer:GetMouse()
    local p = RaycastParams.new()
    p.FilterDescendantsInstances = {c}
    p.FilterType = Enum.RaycastFilterType.Blacklist
    local cam = workspace.CurrentCamera
    local ray = cam:ScreenPointToRay(m.X, m.Y)
    local res = workspace:Raycast(ray.Origin, ray.Direction * 1000, p)
    if res and res.Parent then
        root.CFrame = CFrame.new(res.Position + Vector3.new(0, 3, 0))
    end
end

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
local Window = Rayfield:CreateWindow({
    Name = "BuZaka Script",
    LoadingTitle = "Loading...",
    LoadingSubtitle = "by Grid | Final",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "BuZaka_Script",
        FileName = "Config_v19"
    }
})

local DefenseTab = Window:CreateTab("Defense")
DefenseTab:CreateSection("Master")
DefenseTab:CreateToggle({Name = "Master Toggle", CurrentValue = true, Callback = function(v) C.Master = v; if not v then clearAll() end end})
DefenseTab:CreateSection("Passive Defense")
DefenseTab:CreateToggle({Name = "Anti-Kick (Hooks)", CurrentValue = true, Callback = function(v) C.AntiKick = v end})
DefenseTab:CreateToggle({Name = "Anti-Fling", CurrentValue = true, Callback = function(v) C.AntiFling = v end})
DefenseTab:CreateToggle({Name = "Anti-Grab", CurrentValue = true, Callback = function(v) C.AntiGrab = v end})
DefenseTab:CreateToggle({Name = "Anti-Blobman", CurrentValue = true, Callback = function(v) C.AntiBlobman = v end})
DefenseTab:CreateToggle({Name = "Disable Enemy Collision", CurrentValue = true, Callback = function(v) C.NoCollide = v end})
DefenseTab:CreateToggle({Name = "Auto-Rejoin", CurrentValue = true, Callback = function(v) C.AutoRejoin = v; if not v then R.rejoinAttempts = 0 end end})

local AttackTab = Window:CreateTab("Attack")
AttackTab:CreateSection("Blobman")
AttackTab:CreateButton({Name = "Kick + Kill", Callback = kill})
AttackTab:CreateToggle({Name = "Auto-Kick (Loop)", CurrentValue = false, Callback = function(v)
    C.AutoKick = v and C.Master
    if v and C.Master then
        if R.autoKickThread then pcall(coroutine.close, R.autoKickThread) end
        R.autoKickThread = coroutine.create(function()
            while C.AutoKick and C.Master do
                kill()
                task.wait(0.15)
            end
        end)
        coroutine.resume(R.autoKickThread)
    end
end})
AttackTab:CreateSection("Trigger Lock")
AttackTab:CreateToggle({Name = "Lock on Grab (E)", CurrentValue = false, Callback = function(v) C.Trigger = v and C.Master end})
AttackTab:CreateSlider({Name = "Distance", Range = {5, 30}, Increment = 1, CurrentValue = 15, Callback = function(v) C.TriggerDist = v end})
AttackTab:CreateSection("Throw Power")
AttackTab:CreateSlider({Name = "Throw Power", Range = {1, 10000}, Increment = 10, CurrentValue = 50, Callback = function(v)
    C.ThrowStrength = v
    if C.Master and ApiFTAP.SetThrowStrength then ApiFTAP.SetThrowStrength(v) end
end})
AttackTab:CreateButton({Name = "Super Throw", Callback = function()
    if not C.Master then return end
    local char = LocalPlayer.Character
    if char and char:FindFirstChild("HumanoidRootPart") and char.Parent then
        local root = char.HumanoidRootPart
        local dir = (char:FindFirstChild("Head") and char.Head.CFrame.LookVector) or Vector3.new(1, 0, 0)
        root.Velocity = dir * (C.ThrowStrength or 50) * 50
    end
end})
AttackTab:CreateSection("Clones")
AttackTab:CreateToggle({Name = "Active Clones", CurrentValue = false, Callback = function(v)
    if not C.Master then return end
    if v then
        clearClones()
        local char = LocalPlayer.Character
        if char and char:FindFirstChild("HumanoidRootPart") and char.Parent then
            local root = char.HumanoidRootPart
            for i = 1, 6 do
                local clone = Instance.new("Part")
                clone.Size = Vector3.new(2, 4, 2)
                clone.Shape = Enum.PartType.Cylinder
                clone.Anchored = false
                clone.CanCollide = false
                clone.Material = Enum.Material.Neon
                clone.BrickColor = BrickColor.new("Bright red")
                clone.Transparency = 0.3
                clone.Parent = workspace
                local angle = (i - 1) / 6 * math.pi * 2
                clone.CFrame = root.CFrame * CFrame.new(math.cos(angle) * 5, 0, math.sin(angle) * 5)
                table.insert(R.clones, clone)
            end
            C.Clones = true
            startCloneLoop()
        end
    else
        clearClones()
    end
end})

local MiscTab = Window:CreateTab("Misc")
MiscTab:CreateSection("ESP")
MiscTab:CreateToggle({Name = "ESP (Boxes + Names)", CurrentValue = false, Callback = function(v)
    if not C.Master then return end
    C.ESP = v
    if v then
        clearESP()
        local Camera = workspace.CurrentCamera
        local function createESP(player)
            if player == LocalPlayer or R.espList[player] then return end
            local box = Drawing.new("Square")
            box.Visible = false
            box.Color = Color3.fromRGB(255, 50, 50)
            box.Thickness = 1.5
            box.Filled = false
            local name = Drawing.new("Text")
            name.Visible = false
            name.Color = Color3.fromRGB(255, 255, 255)
            name.Size = 14
            name.Center = true
            name.Outline = true
            local conn = RunService.RenderStepped:Connect(function()
                if not C.ESP or not C.Master then
                    box.Visible = false; name.Visible = false; return
                end
                local char = player.Character
                local root = char and char:FindFirstChild("HumanoidRootPart")
                local hum = char and char:FindFirstChild("Humanoid")
                if char and char.Parent and root and root.Parent and hum and hum.Health > 0 then
                    local pos, onScreen = Camera:WorldToViewportPoint(root.Position)
                    if onScreen then
                        local head = char:FindFirstChild("Head")
                        local top = head and Camera:WorldToViewportPoint(head.Position + Vector3.new(0, 0.5, 0)) or pos
                        local bottom = Camera:WorldToViewportPoint(root.Position - Vector3.new(0, 3, 0))
                        local h = math.abs(top.Y - bottom.Y)
                        local w = h / 2
                        box.Size = Vector2.new(w, h)
                        box.Position = Vector2.new(pos.X - w / 2, top.Y)
                        box.Visible = true
                        name.Text = player.Name .. " [" .. math.floor(hum.Health) .. " HP]"
                        name.Position = Vector2.new(pos.X, top.Y - 18)
                        name.Visible = true
                    else
                        box.Visible = false; name.Visible = false
                    end
                else
                    box.Visible = false; name.Visible = false
                end
            end)
            R.espList[player] = {Box = box, Name = name, Conn = conn}
            table.insert(R.esp, box)
            table.insert(R.esp, name)
        end
        for _, p in pairs(Players:GetPlayers()) do createESP(p) end
        local added = Players.PlayerAdded:Connect(createESP)
        local removed = Players.PlayerRemoving:Connect(function(p)
            local data = R.espList[p]
            if data then
                if data.Box then pcall(data.Box.Remove, data.Box) end
                if data.Name then pcall(data.Name.Remove, data.Name) end
                dc(data.Conn)
                R.espList[p] = nil
            end
        end)
        table.insert(R.conns, added)
        table.insert(R.conns, removed)
    else
        clearESP()
    end
end})

MiscTab:CreateSection("Wings")
MiscTab:CreateToggle({Name = "Wooden Wings", CurrentValue = false, Callback = function(v)
    if not C.Master then return end
    if v then
        if #R.wings > 0 and R.wings[1].part and R.wings[1].part.Material == Enum.Material.Neon then clearWings() end
        clearWings()
        local char = LocalPlayer.Character
        if char and char:FindFirstChild("HumanoidRootPart") and char.Parent then
            local root = char.HumanoidRootPart
            local wings = Instance.new("Model")
            wings.Name = "FarshWings"
            wings.Parent = char
            for side = -1, 1, 2 do
                for i = 0, 3 do
                    local plank = Instance.new("Part")
                    plank.Size = Vector3.new(0.2, 2.5, 0.8)
                    plank.Anchored = false
                    plank.CanCollide = false
                    plank.BrickColor = BrickColor.new("Bright brown")
                    plank.Material = Enum.Material.Wood
                    plank.Parent = wings
                    local offZ = (i + 1) * 0.9 * side
                    local offY = 0.8 - i * 0.25
                    local weld = Instance.new("Weld")
                    weld.Part0 = root
                    weld.Part1 = plank
                    weld.C0 = root.CFrame:Inverse() * (root.CFrame * CFrame.new(0, offY, offZ) * CFrame.Angles(0, math.rad(15 * i * side), 0))
                    weld.Parent = plank
                    table.insert(R.wings, {part = plank, index = i, side = side, offsetY = offY, offsetZ = offZ})
                end
            end
            C.Wings = true
            startWingLoop()
        end
    else
        clearWings()
    end
end})
MiscTab:CreateToggle({Name = "Glow Stick Wings", CurrentValue = false, Callback = function(v)
    if not C.Master then return end
    if v then
        if #R.wings > 0 and R.wings[1].part and R.wings[1].part.Material == Enum.Material.Wood then clearWings() end
        clearWings()
        local char = LocalPlayer.Character
        if char and char:FindFirstChild("HumanoidRootPart") and char.Parent then
            local root = char.HumanoidRootPart
            local wings = Instance.new("Model")
            wings.Name = "FarshWings"
            wings.Parent = char
            for side = -1, 1, 2 do
                for i = 0, 3 do
                    local stick = Instance.new("Part")
                    stick.Size = Vector3.new(0.12, 0.12, 2.8)
                    stick.Anchored = false
                    stick.CanCollide = false
                    stick.BrickColor = BrickColor.new("Dark brown")
                    stick.Material = Enum.Material.Wood
                    stick.Parent = wings
                    local offZ = (i + 1) * 0.8 * side
                    local offY = 0.6 - i * 0.2
                    local weld = Instance.new("Weld")
                    weld.Part0 = root
                    weld.Part1 = stick
                    weld.C0 = root.CFrame:Inverse() * (root.CFrame * CFrame.new(0, offY, offZ) * CFrame.Angles(0, math.rad(20 * i * side), 0))
                    weld.Parent = stick
                    local glow = Instance.new("Part")
                    glow.Size = Vector3.new(0.7, 0.7, 0.7)
                    glow.Shape = Enum.PartType.Ball
                    glow.Anchored = false
                    glow.CanCollide = false
                    glow.Material = Enum.Material.Neon
                    glow.BrickColor = BrickColor.new("Bright cyan")
                    glow.Parent = wings
                    local gw = Instance.new("Weld")
                    gw.Part0 = stick
                    gw.Part1 = glow
                    gw.C0 = CFrame.new(0, 0, 1.4 + 0.35)
                    gw.Parent = glow
                    table.insert(R.wings, {part = stick, glow = glow, index = i, side = side, offsetY = offY, offsetZ = offZ})
                end
            end
            C.Wings = true
            startWingLoop()
        end
    else
        clearWings()
    end
end})

MiscTab:CreateSection("Water")
MiscTab:CreateToggle({Name = "Solid Water", CurrentValue = false, Callback = function(v)
    C.Water = v and C.Master
    if v and C.Master then startWaterLoop()
    else
        dc(R.waterConn)
        for _, pair in pairs(R.waterObjects) do
            if pair.obj and pair.obj.Parent then
                pair.obj.CanCollide = pair.original
            end
        end
        R.waterObjects = {}
    end
end})

MiscTab:CreateSection("Teleports")
local selectedPlayer = nil
local playerNames = {}
for _, p in pairs(Players:GetPlayers()) do
    if p ~= LocalPlayer then table.insert(playerNames, p.Name) end
end

local PlayerDropdown = MiscTab:CreateDropdown({
    Name = "Select Player",
    Options = playerNames,
    CurrentOption = playerNames[1] or "",
    Callback = function(Option)
        selectedPlayer = type(Option) == "table" and Option[1] or Option
    end,
})

local function updatePlayerDropdown()
    local list = {}
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then table.insert(list, p.Name) end
    end
    PlayerDropdown:Set(list)
end

Players.PlayerAdded:Connect(updatePlayerDropdown)
Players.PlayerRemoving:Connect(updatePlayerDropdown)

MiscTab:CreateButton({
    Name = "Teleport to Selected Player",
    Callback = function()
        if selectedPlayer then tpPlayer(selectedPlayer) end
    end
})
MiscTab:CreateToggle({Name = "Q Teleport (Look)", CurrentValue = false, Callback = function(v) C.Qtp = v and C.Master end})
MiscTab:CreateButton({Name = "Save Position", Callback = function()
    if not C.Master then return end
    local char = LocalPlayer.Character
    if char and char:FindFirstChild("HumanoidRootPart") and char.Parent then
        C.SavePos = char.HumanoidRootPart.CFrame
    end
end})
MiscTab:CreateButton({Name = "Return to Saved", Callback = function()
    if not C.Master or not C.SavePos then return end
    local char = LocalPlayer.Character
    if char and char:FindFirstChild("HumanoidRootPart") and char.Parent then
        char.HumanoidRootPart.CFrame = C.SavePos
    end
end})

local UIS = game:GetService("UserInputService")
UIS.InputBegan:Connect(function(input, gp)
    if gp or not C.Master then return end
    if input.KeyCode == Enum.KeyCode.Q and C.Qtp then tpLook() end
end)

print("BuZaka Script v19 LOADED")
