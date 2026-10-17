-- ============================================================
-- 🎃 GHOST HUB v5.0 — Halloween Edition
-- Repo:     https://github.com/zovlane/GhostHub
-- WindUI:   https://github.com/zovlane/WindUI (our fork — loads dist/main.lua)
-- Load:     loadstring(game:HttpGet("https://raw.githubusercontent.com/zovlane/GhostHub/main/main.lua"))()
-- ============================================================
local TweenService      = game:GetService("TweenService")
local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService   = game:GetService("TeleportService")
local HttpService       = game:GetService("HttpService")
local TextChatService   = game:GetService("TextChatService")
local StarterGui        = game:GetService("StarterGui")
local LocalPlayer       = Players.LocalPlayer
local CoreGui           = game:GetService("CoreGui")
local VirtualUser       = game:GetService("VirtualUser")

-- ============================================================
-- CLEANUP (re-execute safe — Vision Hub pattern)
-- ============================================================
local queue_on_teleport = queue_on_teleport
    or (syn and syn.queue_on_teleport)
    or (fluxus and fluxus.queue_on_teleport)
    or function() end

if getgenv().VisionHub_Connections then
    for i, conn in pairs(getgenv().VisionHub_Connections) do
        if conn then pcall(function() conn:Disconnect() end) end
        getgenv().VisionHub_Connections[i] = nil
    end
end
getgenv().VisionHub_Connections = {}

-- clean up Drawing-based crosshair from previous run
if getgenv()._crosshairClean then pcall(getgenv()._crosshairClean) end
getgenv()._crosshairClean = nil

-- destroy our own CoreGui overlays
for _, gui in ipairs(CoreGui:GetChildren()) do
    if gui.Name == "MM2HubMain" or gui.Name == "MM2HubOpenBtn"
    or gui.Name == "MM2HubTimer" or gui.Name == "MM2HubLoad"
    or gui.Name == "MM2HubMobile" or gui.Name:sub(1,9) == "VisionBtn"
    or gui.Name == "VisionESP"   or gui.Name == "VisionTimerGUI"
    or gui.Name == "MM2HubCrosshair" then
        pcall(function() gui:Destroy() end)
    end
end
-- destroy previous WindUI window — patched WindUI nests inside CoreGui.RobloxGui
pcall(function()
    local robloxGui = CoreGui:FindFirstChild("RobloxGui")
    if robloxGui then
        for _, child in ipairs(robloxGui:GetChildren()) do
            if child.Name == "WindUI" then pcall(function() child:Destroy() end) end
        end
    end
end)
-- also check PlayerGui in case some executor puts it there
if LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui") then
    for _, gui in ipairs(LocalPlayer.PlayerGui:GetChildren()) do
        if gui.Name == "WindUI" then pcall(function() gui:Destroy() end) end
    end
end

for _, player in ipairs(Players:GetPlayers()) do
    if player.Character then
        local hl1 = player.Character:FindFirstChild("VisionHighlight")
        if hl1 then hl1:Destroy() end
        local head = player.Character:FindFirstChild("Head")
        if head then
            local n = head:FindFirstChild("NameESP"); if n then n:Destroy() end
        end
    end
end

for _, obj in ipairs(workspace:GetDescendants()) do
    if obj.Name == "VisionGunHighlight" or obj.Name == "VisionGunLabel" then
        pcall(function() obj:Destroy() end)
    end
end

if getgenv().FPDH then
    workspace.FallenPartsDestroyHeight = getgenv().FPDH
end

local function AddConnection(conn)
    local t = getgenv().VisionHub_Connections
    for i = #t, 1, -1 do
        if not t[i] or not t[i].Connected then table.remove(t, i) end
    end
    table.insert(t, conn)
    return conn
end

-- ============================================================
-- LOADING WINDUI
-- ============================================================
local WindUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/zovlane/WindUI/main/dist/main.lua"))()

-- ============================================================
-- MODULES (Vision Hub pattern, exact)
-- ============================================================
local Modules = {}

local firetouchinterest = firetouchinterest or nil
local writefile = writefile or nil
local readfile_fn = readfile or nil

Modules.Player        = LocalPlayer
Modules.GetMouse      = LocalPlayer:GetMouse()
Modules.PlayerGui     = LocalPlayer:FindFirstChildWhichIsA("PlayerGui")
Modules.PlaceId       = game.PlaceId
Modules.JobId         = game.JobId
Modules.RunService    = RunService
Modules.UserInputService = UserInputService
Modules.Workspace     = workspace
Modules.ReplicatedStorage = ReplicatedStorage
Modules.HttpService   = HttpService
Modules.StarterGui    = StarterGui
Modules.TextChatService = TextChatService

Modules.Config = {
    GodMode            = false,
    AntiFling          = false,
    AntiAfk            = false,
    EnableWalkSpeed    = false,
    WalkSpeed          = 16,
    EnableJumpPower    = false,
    JumpPower          = 50,
    Noclip             = false,
    InfiniteJump       = false,
    AutoGrabGun        = false,
    AutoKill           = false,
    KnifeAura          = false,
    AuraRadius         = 10,
    EspPlayers         = false,
    ShowNames          = false,
    EspDroppedGun      = false,
    SilentThrow        = false,
    AutoShootMurderer  = false,
    AutoQueue          = true,
    QueueUrl           = 'loadstring(game:HttpGet("https://raw.githubusercontent.com/zovlane/Files/refs/heads/main/officialscript.lua",true))()',
    NotifyMurderer     = false,
    NotifySheriff      = false,
    NotifyGunDropped   = false,
    ButtonsLocked      = false,
}

Modules.PlayerData   = {}
Modules.MobileButtons = {}

-- ============================================================
-- CHARACTER REFS (Vision Hub pattern)
-- ============================================================
local function updateCharacterRefs(character)
    Modules.Character = character
    if character then
        local hum = character:FindFirstChildOfClass("Humanoid")
            or character:WaitForChild("Humanoid", 5)
        Modules.Humanoid = hum
        Modules.Backpack  = Modules.Player:FindFirstChild("Backpack")
        Modules.RootPart  = character:FindFirstChild("HumanoidRootPart") or character.PrimaryPart
        Modules.Camera    = workspace.CurrentCamera
    else
        Modules.Humanoid = nil; Modules.RootPart = nil
    end
end

if LocalPlayer.Character then updateCharacterRefs(LocalPlayer.Character) end
AddConnection(LocalPlayer.CharacterAdded:Connect(function(c)
    updateCharacterRefs(c)
end))
AddConnection(LocalPlayer.CharacterRemoving:Connect(function()
    updateCharacterRefs(nil)
end))
AddConnection(Players.PlayerRemoving:Connect(function(p)
    if p and Modules.PlayerData[p.Name] then Modules.PlayerData[p.Name] = nil end
end))

-- ============================================================
-- PLAYERDATA (Vision Hub exact)
-- ============================================================
do
    local ok, remotes = pcall(function()
        return ReplicatedStorage:WaitForChild("Remotes", 5)
    end)
    if ok and remotes then
        local gp = remotes:FindFirstChild("Gameplay") or remotes:FindFirstChild("Gameplay", true)
        if gp then
            local pde = gp:FindFirstChild("PlayerDataChanged")
            if pde and pde:IsA("RemoteEvent") then
                AddConnection(pde.OnClientEvent:Connect(function(data)
                    if type(data) == "table" then Modules.PlayerData = data end
                end))
            end
        end
    end
    local getPD = ReplicatedStorage:FindFirstChild("GetPlayerData", true)
    if getPD and typeof(getPD.InvokeServer) == "function" then
        pcall(function()
            local ok2, res = pcall(function() return getPD:InvokeServer() end)
            if ok2 and type(res) == "table" then Modules.PlayerData = res end
        end)
    end
end

-- ============================================================
-- HELPERS (Vision Hub)
-- ============================================================
local function getMap()
    for _, o in ipairs(workspace:GetChildren()) do
        if o:FindFirstChild("CoinContainer") and o:FindFirstChild("Spawns") then return o end
    end
end

local function getLobby()
    for _, obj in ipairs(workspace:GetChildren()) do
        if obj:FindFirstChild("Lobby") then return obj.Lobby end
        if obj.Name:lower() == "lobby" then return obj end
    end
end

function Modules.GetPlayerByName(name)
    if not name then return nil end
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Name:lower() == name:lower() then return p end
    end
end

function Modules.FindMurderer()
    for _, p in ipairs(Players:GetPlayers()) do
        if p:FindFirstChild("Backpack") and p.Backpack:FindFirstChild("Knife") then return p end
    end
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Character and p.Character:FindFirstChild("Knife") then return p end
    end
    for name, data in pairs(Modules.PlayerData) do
        if data and (data.Role=="Murderer" or data.role=="Murderer") then
            local f = Players:FindFirstChild(name); if f then return f end
        end
    end
end

function Modules.FindSheriff()
    for _, p in ipairs(Players:GetPlayers()) do
        if p:FindFirstChild("Backpack") and p.Backpack:FindFirstChild("Gun") then return p end
    end
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Character and p.Character:FindFirstChild("Gun") then return p end
    end
    for name, data in pairs(Modules.PlayerData) do
        if data and (data.Role=="Sheriff" or data.role=="Sheriff") then
            local f = Players:FindFirstChild(name); if f then return f end
        end
    end
end

function Modules.FindSheriffThatsNotMe()
    local lp = LocalPlayer
    for _, p in ipairs(Players:GetPlayers()) do
        if p~=lp and p:FindFirstChild("Backpack") and p.Backpack:FindFirstChild("Gun") then return p end
    end
    for _, p in ipairs(Players:GetPlayers()) do
        if p~=lp and p.Character and p.Character:FindFirstChild("Gun") then return p end
    end
    for name, data in pairs(Modules.PlayerData) do
        if data and (data.Role=="Sheriff" or data.role=="Sheriff") then
            local f=Players:FindFirstChild(name); if f and f~=lp then return f end
        end
    end
end

function Modules.FindHero()
    for name, data in pairs(Modules.PlayerData) do
        if data and (data.Role=="Hero" or data.role=="Hero") then
            return Players:FindFirstChild(name)
        end
    end
end

-- ============================================================
-- ANTI-FLING (Vision Hub exact)
-- ============================================================
do
    local antiFlingConn = nil
    function Modules.ToggleAntiFling(enable)
        Modules.Config.AntiFling = enable
        if antiFlingConn then antiFlingConn:Disconnect(); antiFlingConn = nil end
        if not enable then return end
        antiFlingConn = AddConnection(RunService.Stepped:Connect(function()
            if not Modules.Character then return end
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= Modules.Player and p.Character then
                    for _, part in ipairs(p.Character:GetChildren()) do
                        if part:IsA("BasePart") and part.CanCollide then
                            part.CanCollide = false
                            if part.Name == "HumanoidRootPart" then
                                part.Velocity    = Vector3.new()
                                part.RotVelocity = Vector3.new()
                            end
                        end
                    end
                end
            end
        end))
    end
end

-- ============================================================
-- REJOIN / SERVER HOP (Vision Hub exact)
-- ============================================================
function Modules.HandleQueueTeleport()
    if Modules.Config.AutoQueue and Modules.Config.QueueUrl ~= "" then
        pcall(function() queue_on_teleport(Modules.Config.QueueUrl) end)
    end
end

function Modules.Rejoin()
    Modules.HandleQueueTeleport()
    pcall(function()
        TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
    end)
end

function Modules.ServerHop()
    Modules.HandleQueueTeleport()
    local url = "https://games.roblox.com/v1/games/"..game.PlaceId.."/servers/Public?sortOrder=Asc&limit=100"
    local ok, result = pcall(function() return HttpService:JSONDecode(game:HttpGet(url)) end)
    if ok and result and result.data then
        for _, sv in ipairs(result.data) do
            if sv.id ~= game.JobId and sv.playing < sv.maxPlayers then
                TeleportService:TeleportToPlaceInstance(game.PlaceId, sv.id, LocalPlayer); return
            end
        end
    end
    TeleportService:Teleport(game.PlaceId, LocalPlayer)
end

-- ============================================================
-- TELEPORTS (Vision Hub exact)
-- ============================================================
function Modules.TeleportToMap()
    local character = Modules.Character; if not character then return end
    local map = getMap(); if not map then return end
    local spawns = map:FindFirstChild("Spawns"); if not spawns then return end
    local list = {}
    for _, v in ipairs(spawns:GetChildren()) do if v:IsA("BasePart") then list[#list+1]=v end end
    local sp = #list>0 and list[math.random(1,#list)] or spawns:FindFirstChild("Spawn") or spawns:FindFirstChild("PlayerSpawn")
    if sp and sp:IsA("BasePart") then character:PivotTo(sp.CFrame * CFrame.new(0,5,0)) end
end

function Modules.TeleportToLobby()
    local character = Modules.Character; if not character then return end
    local lobby = getLobby(); if not lobby then return end
    local spawns = lobby:FindFirstChild("Spawns"); if not spawns then return end
    local list = {}
    for _, v in ipairs(spawns:GetChildren()) do if v:IsA("BasePart") then list[#list+1]=v end end
    local sp = #list>0 and list[math.random(1,#list)] or spawns:FindFirstChild("SpawnLocation")
    if sp and sp:IsA("BasePart") then character:PivotTo(sp.CFrame * CFrame.new(0,5,0)) end
end

function Modules.TeleportToPlayer(target)
    if not Modules.RootPart then return false end
    if not (target and target.Character and target.Character.PrimaryPart) then return false end
    local ok = pcall(function()
        Modules.Character:SetPrimaryPartCFrame(target.Character.PrimaryPart.CFrame * CFrame.new(0,3,0))
    end)
    return ok
end

-- ============================================================
-- FLING SYSTEM (Epix/Skid proven algorithm — supports single or "all")
-- ============================================================
local function miniFling(Targets)
    local AllBool = false

    local GetPlayer = function(Name)
        Name = Name:lower()
        if Name == "all" or Name == "others" then AllBool = true; return end
        for _, x in next, Players:GetPlayers() do
            if x ~= LocalPlayer then
                if x.Name:lower():match("^"..Name) or x.DisplayName:lower():match("^"..Name) then
                    return x
                end
            end
        end
    end

    local SkidFling = function(TargetPlayer)
        local Character = LocalPlayer.Character
        local Humanoid  = Character and Character:FindFirstChildOfClass("Humanoid")
        local RootPart  = Humanoid and Humanoid.RootPart
        local TCharacter= TargetPlayer.Character
        if not TCharacter then return end

        local THumanoid = TCharacter:FindFirstChildOfClass("Humanoid")
        local TRootPart = THumanoid and THumanoid.RootPart
        local THead     = TCharacter:FindFirstChild("Head")
        local Accessory = TCharacter:FindFirstChildOfClass("Accessory")
        local Handle    = Accessory and Accessory:FindFirstChild("Handle")

        if Character and Humanoid and RootPart then
            if RootPart.Velocity.Magnitude < 50 then
                getgenv().OldPos = RootPart.CFrame
            end
            if THumanoid and THumanoid.Sit and not AllBool then return end

            if THead then
                workspace.CurrentCamera.CameraSubject = THead
            elseif Handle then
                workspace.CurrentCamera.CameraSubject = Handle
            elseif THumanoid and TRootPart then
                workspace.CurrentCamera.CameraSubject = THumanoid
            end

            if not TCharacter:FindFirstChildWhichIsA("BasePart") then return end

            local FPos = function(BasePart, Pos, Ang)
                RootPart.CFrame = CFrame.new(BasePart.Position) * Pos * Ang
                Character:SetPrimaryPartCFrame(CFrame.new(BasePart.Position) * Pos * Ang)
                RootPart.Velocity    = Vector3.new(9e7, 9e7*10, 9e7)
                RootPart.RotVelocity = Vector3.new(9e8, 9e8, 9e8)
            end

            local SFBasePart = function(BasePart)
                local TimeToWait = 2
                local Time = tick()
                local Angle = 0
                repeat
                    if RootPart and THumanoid then
                        if BasePart.Velocity.Magnitude < 50 then
                            Angle = Angle + 100
                            FPos(BasePart, CFrame.new(0,  1.5, 0) + THumanoid.MoveDirection * BasePart.Velocity.Magnitude / 1.25, CFrame.Angles(math.rad(Angle), 0, 0)); task.wait()
                            FPos(BasePart, CFrame.new(0, -1.5, 0) + THumanoid.MoveDirection * BasePart.Velocity.Magnitude / 1.25, CFrame.Angles(math.rad(Angle), 0, 0)); task.wait()
                            FPos(BasePart, CFrame.new( 2.25, 1.5,-2.25) + THumanoid.MoveDirection * BasePart.Velocity.Magnitude / 1.25, CFrame.Angles(math.rad(Angle), 0, 0)); task.wait()
                            FPos(BasePart, CFrame.new(-2.25,-1.5, 2.25) + THumanoid.MoveDirection * BasePart.Velocity.Magnitude / 1.25, CFrame.Angles(math.rad(Angle), 0, 0)); task.wait()
                            FPos(BasePart, CFrame.new(0,  1.5, 0) + THumanoid.MoveDirection, CFrame.Angles(math.rad(Angle), 0, 0)); task.wait()
                            FPos(BasePart, CFrame.new(0, -1.5, 0) + THumanoid.MoveDirection, CFrame.Angles(math.rad(Angle), 0, 0)); task.wait()
                        else
                            FPos(BasePart, CFrame.new(0,  1.5,  THumanoid.WalkSpeed), CFrame.Angles(math.rad(90), 0, 0)); task.wait()
                            FPos(BasePart, CFrame.new(0, -1.5, -THumanoid.WalkSpeed), CFrame.Angles(0, 0, 0));            task.wait()
                            FPos(BasePart, CFrame.new(0,  1.5,  THumanoid.WalkSpeed), CFrame.Angles(math.rad(90), 0, 0)); task.wait()
                            FPos(BasePart, CFrame.new(0,  1.5,  TRootPart.Velocity.Magnitude / 1.25), CFrame.Angles(math.rad(90), 0, 0));  task.wait()
                            FPos(BasePart, CFrame.new(0, -1.5, -TRootPart.Velocity.Magnitude / 1.25), CFrame.Angles(0, 0, 0));             task.wait()
                            FPos(BasePart, CFrame.new(0,  1.5,  TRootPart.Velocity.Magnitude / 1.25), CFrame.Angles(math.rad(90), 0, 0));  task.wait()
                            FPos(BasePart, CFrame.new(0, -1.5, 0), CFrame.Angles(math.rad(90), 0, 0));  task.wait()
                            FPos(BasePart, CFrame.new(0, -1.5, 0), CFrame.Angles(0, 0, 0));             task.wait()
                            FPos(BasePart, CFrame.new(0, -1.5, 0), CFrame.Angles(math.rad(-90), 0, 0)); task.wait()
                            FPos(BasePart, CFrame.new(0, -1.5, 0), CFrame.Angles(0, 0, 0));             task.wait()
                        end
                    else
                        break
                    end
                until BasePart.Velocity.Magnitude > 500 or BasePart.Parent ~= TargetPlayer.Character
                    or TargetPlayer.Parent ~= Players or THumanoid.Sit
                    or Humanoid.Health <= 0 or tick() > Time + TimeToWait
            end

            if not getgenv().FPDH then getgenv().FPDH = workspace.FallenPartsDestroyHeight end
            workspace.FallenPartsDestroyHeight = 0/0

            local BV = Instance.new("BodyVelocity")
            BV.Name     = "EpixVel"
            BV.Velocity = Vector3.new(9e8, 9e8, 9e8)
            BV.MaxForce = Vector3.new(1/0, 1/0, 1/0)
            BV.Parent   = RootPart

            Humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, false)

            if TRootPart and THead then
                if (TRootPart.CFrame.p - THead.CFrame.p).Magnitude > 5 then SFBasePart(THead)
                else SFBasePart(TRootPart) end
            elseif TRootPart then SFBasePart(TRootPart)
            elseif THead      then SFBasePart(THead)
            elseif Accessory and Handle then SFBasePart(Handle)
            end

            BV:Destroy()
            Humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, true)
            workspace.CurrentCamera.CameraSubject = Humanoid

            repeat
                RootPart.CFrame = getgenv().OldPos * CFrame.new(0, .5, 0)
                Character:SetPrimaryPartCFrame(getgenv().OldPos * CFrame.new(0, .5, 0))
                Humanoid:ChangeState("GettingUp")
                table.foreach(Character:GetChildren(), function(_, x)
                    if x:IsA("BasePart") then
                        x.Velocity, x.RotVelocity = Vector3.new(), Vector3.new()
                    end
                end)
                task.wait()
            until (RootPart.Position - getgenv().OldPos.p).Magnitude < 25
            workspace.FallenPartsDestroyHeight = -500
        end
        workspace.FallenPartsDestroyHeight = -500
    end

    if not Targets[1] then return end

    -- Check if targeting all players
    for _, target in next, Targets do
        if target:lower() == "all" or target:lower() == "others" then
            AllBool = true
            break
        end
    end

    if AllBool then
        for _, x in next, Players:GetPlayers() do
            if x ~= LocalPlayer then
                SkidFling(x)
                task.wait(0.5)
            end
        end
    else
        for _, x in next, Targets do
            local p = GetPlayer(x)
            if p and p ~= LocalPlayer then
                SkidFling(p)
                task.wait(0.5)
            end
        end
    end
end

-- Convenience wrapper kept for existing callers
local SkidFling = function(TargetPlayer)
    if TargetPlayer and TargetPlayer.Name then
        miniFling({ TargetPlayer.Name })
    end
end

-- ============================================================
-- SHOOT MURDERER (finds Tool with "Shoot" RemoteEvent — correct MM2 mechanic)
-- ============================================================
local function findGunTool()
    local char = LocalPlayer.Character
    local bp   = LocalPlayer.Backpack
    local function findIn(parent)
        if not parent then return nil, nil end
        for _, child in ipairs(parent:GetChildren()) do
            if child:IsA("Tool") then
                local shoot = child:FindFirstChild("Shoot")
                if shoot and shoot:IsA("RemoteEvent") then return child, shoot end
            end
        end
        return nil, nil
    end
    local gun, shoot = findIn(char)
    if gun then return gun, shoot end
    return findIn(bp)
end

-- Auto-grab nearest GunDrop via firetouchinterest (no teleport)
local function grabGunFromDrop()
    local char = LocalPlayer.Character
    local lHRP = char and char:FindFirstChild("HumanoidRootPart")
    if not lHRP then return false end
    local nearest, minD = nil, math.huge
    for _, desc in ipairs(workspace:GetDescendants()) do
        if desc.Name == "GunDrop" and desc:IsA("BasePart") then
            local dist = (lHRP.Position - desc.Position).Magnitude
            if dist < minD then nearest = desc; minD = dist end
        end
    end
    if not nearest then return false end
    local returnCF = lHRP.CFrame
    pcall(function()
        firetouchinterest(lHRP, nearest, 0)
        task.wait()
        firetouchinterest(lHRP, nearest, 1)
        task.wait(0.1)
        lHRP.CFrame = returnCF
    end)
    return true
end

-- Notify when a gun drops
workspace.DescendantAdded:Connect(function(desc)
    if desc.Name == "GunDrop" and desc:IsA("BasePart") then
        pcall(function()
            WindUI:Notify({ Title="Gun Dropped!", Content="A gun appeared on the map!", Icon="alert-circle", Duration=4 })
        end)
    end
end)

-- shared: find murderer player
local function findMurdererPlayer()
    local murderer = nil
    pcall(function()
        local roles = ReplicatedStorage:FindFirstChild("GetPlayerData", true):InvokeServer()
        if type(roles) == "table" then
            for name, data in pairs(roles) do
                if data and data.Role == "Murderer" then
                    murderer = Players:FindFirstChild(name); break
                end
            end
        end
    end)
    if not murderer then
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                local bp2 = p:FindFirstChild("Backpack")
                if p.Character:FindFirstChild("Knife") or (bp2 and bp2:FindFirstChild("Knife")) then
                    murderer = p; break
                end
            end
        end
    end
    return murderer
end

-- shared: ensure we have a gun (grab from drop if needed), return shootRemote or nil
local function ensureGun()
    local _, shootRemote = findGunTool()
    if not shootRemote then
        grabGunFromDrop()
        task.wait(0.15)
        _, shootRemote = findGunTool()
    end
    return shootRemote
end

-- TP & Shoot: teleport in front of murderer, fire, return
function Modules.ShootMurdererOnce()
    local char = LocalPlayer and LocalPlayer.Character
    local hum  = char and char:FindFirstChildOfClass("Humanoid")
    if not char or not hum or hum.Health <= 0 then return end
    local lHRP = char:FindFirstChild("HumanoidRootPart")
    if not lHRP then return end

    local murderer = findMurdererPlayer()
    if not murderer or not murderer.Character then return end
    local hum2 = murderer.Character:FindFirstChildOfClass("Humanoid")
    if not hum2 or hum2.Health <= 0 then return end
    local tHRP = murderer.Character:FindFirstChild("HumanoidRootPart")
    if not tHRP then return end

    local shootRemote = ensureGun()
    if not shootRemote then return end

    local savedCF = lHRP.CFrame
    pcall(function() lHRP.CFrame = tHRP.CFrame * CFrame.new(0, 0, -4) end)
    task.wait(0.05)
    lHRP = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not lHRP then return end

    local noise = Vector3.new((math.random()-0.5)*0.08, (math.random()-0.5)*0.08, (math.random()-0.5)*0.08)
    pcall(function() shootRemote:FireServer(lHRP.CFrame, tHRP.CFrame + noise) end)

    task.wait(0.05)
    pcall(function()
        local r2 = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if r2 then r2.CFrame = savedCF end
    end)
end

-- Silent Aim: __namecall hook — intercepts every Shoot:FireServer and redirects to murderer
local _silentAimEnabled = false
pcall(function()
    local mt  = getrawmetatable(game)
    local old = mt.__namecall
    setreadonly(mt, false)
    mt.__namecall = newcclosure(function(self, ...)
        if _silentAimEnabled and getnamecallmethod() == "FireServer"
            and self.Name == "Shoot" and self:IsA("RemoteEvent") then
            local murderer = findMurdererPlayer()
            if murderer and murderer.Character then
                local tHRP = murderer.Character:FindFirstChild("HumanoidRootPart")
                local lc   = LocalPlayer.Character
                local lHRP = lc and lc:FindFirstChild("HumanoidRootPart")
                if tHRP and lHRP then
                    -- predict position based on velocity
                    local pred = tHRP.CFrame + tHRP.Velocity * 0.1
                    return old(self, lHRP.CFrame, pred)
                end
            end
        end
        return old(self, ...)
    end)
    setreadonly(mt, true)
end)

function Modules.ShootMurdererSilent()
    _silentAimEnabled = not _silentAimEnabled
    WindUI:Notify({
        Title   = "Silent Aim",
        Content = _silentAimEnabled and "Enabled — shots redirect to murderer!" or "Disabled",
        Icon    = _silentAimEnabled and "crosshair" or "x-circle",
        Duration = 2,
    })
end

do
    local autoShootId = 0
    local GUN_RELOAD = 1.8 -- seconds to wait after shooting before trying again
    function Modules.ToggleAutoShootMurderer(enable)
        Modules.Config.AutoShootMurderer = enable
        autoShootId = autoShootId + 1
        if not enable then return end
        local myId = autoShootId
        task.spawn(function()
            while Modules.Config.AutoShootMurderer and autoShootId == myId do
                pcall(function()
                    local char = LocalPlayer and LocalPlayer.Character
                    local hum = char and char:FindFirstChildOfClass("Humanoid")
                    if not (char and hum and hum.Health > 0) then return end

                    local gun = char:FindFirstChild("Gun")
                        or (LocalPlayer.Backpack and LocalPlayer.Backpack:FindFirstChild("Gun"))
                    if not gun then return end

                    -- save original position
                    local localRoot = char:FindFirstChild("HumanoidRootPart")
                    if not localRoot then return end
                    local savedCF = localRoot.CFrame

                    -- shoot
                    Modules.ShootMurdererOnce()

                    -- return to original spot
                    task.wait(0.1)
                    pcall(function()
                        local c2 = LocalPlayer.Character
                        local r2 = c2 and c2:FindFirstChild("HumanoidRootPart")
                        if r2 then r2.CFrame = savedCF end
                    end)

                    -- wait for gun reload before next attempt
                    task.wait(GUN_RELOAD)
                end)
                task.wait(0.1)
            end
        end)
    end
end

-- ============================================================
-- GOD MODE (Vision Hub exact)
-- ============================================================
do
    local _godConn = nil
    function Modules.EnableGodMode(enable)
        Modules.Config.GodMode = enable
        if _godConn then _godConn:Disconnect(); _godConn=nil end
        if not enable then return end
        local function protectHumanoid(h)
            if not h then return end
            local hc = h.HealthChanged:Connect(function(hp)
                if Modules.Config.GodMode and hp < h.MaxHealth then h.Health = h.MaxHealth end
            end)
            task.spawn(function()
                while Modules.Config.GodMode and h and h.Parent do
                    if h.Health < h.MaxHealth then h.Health = h.MaxHealth end
                    if h:GetState() == Enum.HumanoidStateType.Dead then
                        h:ChangeState(Enum.HumanoidStateType.GettingUp)
                        h.Health = h.MaxHealth
                    end
                    task.wait(0.2)
                end
                hc:Disconnect()
            end)
        end
        if Modules.Humanoid then protectHumanoid(Modules.Humanoid) end
        _godConn = AddConnection(LocalPlayer.CharacterAdded:Connect(function(char)
            local hum = char:WaitForChild("Humanoid", 5)
            if hum then task.wait(0.5); protectHumanoid(hum) end
        end))
    end
end

-- ============================================================
-- WALKSPEED (Vision Hub exact)
-- ============================================================
do
    local _speedConn = nil; local _origSpeed = 16
    function Modules.EnableWalkSpeed(enable)
        Modules.Config.EnableWalkSpeed = enable
        if _speedConn then _speedConn:Disconnect(); _speedConn=nil end
        if enable then
            _speedConn = AddConnection(RunService.Heartbeat:Connect(function()
                if Modules.Humanoid and Modules.Humanoid.WalkSpeed ~= Modules.Config.WalkSpeed then
                    Modules.Humanoid.WalkSpeed = Modules.Config.WalkSpeed
                end
            end))
        else
            if Modules.Humanoid then Modules.Humanoid.WalkSpeed = _origSpeed end
        end
    end
    function Modules.SetWalkSpeed(v)
        Modules.Config.WalkSpeed = math.clamp(v, 16, 200)
        if Modules.Config.EnableWalkSpeed and Modules.Humanoid then
            Modules.Humanoid.WalkSpeed = Modules.Config.WalkSpeed
        end
    end
end

-- ============================================================
-- JUMPPOWER (Vision Hub exact)
-- ============================================================
do
    local _jumpConn = nil; local _origJump = 50
    function Modules.EnableJumpPower(enable)
        Modules.Config.EnableJumpPower = enable
        if _jumpConn then _jumpConn:Disconnect(); _jumpConn=nil end
        if enable then
            _jumpConn = AddConnection(RunService.Heartbeat:Connect(function()
                if Modules.Humanoid and Modules.Humanoid.JumpPower ~= Modules.Config.JumpPower then
                    Modules.Humanoid.JumpPower = Modules.Config.JumpPower
                end
            end))
        else
            if Modules.Humanoid then Modules.Humanoid.JumpPower = _origJump end
        end
    end
    function Modules.SetJumpPower(v)
        Modules.Config.JumpPower = math.clamp(v, 50, 300)
        if Modules.Config.EnableJumpPower and Modules.Humanoid then
            Modules.Humanoid.JumpPower = Modules.Config.JumpPower
        end
    end
end

-- ============================================================
-- NOCLIP (Vision Hub exact)
-- ============================================================
do
    local _noclipConn = nil; local _saved = {}
    function Modules.EnableNoclip(enable)
        Modules.Config.Noclip = enable
        if enable then
            if Modules.Character then
                for _, p in ipairs(Modules.Character:GetDescendants()) do
                    if p:IsA("BasePart") then _saved[p]=p.CanCollide; p.CanCollide=false end
                end
            end
            if _noclipConn then _noclipConn:Disconnect() end
            _noclipConn = AddConnection(RunService.Stepped:Connect(function()
                if not Modules.Character then return end
                for _, p in ipairs(Modules.Character:GetDescendants()) do
                    if p:IsA("BasePart") then p.CanCollide=false end
                end
            end))
        else
            if _noclipConn then _noclipConn:Disconnect(); _noclipConn=nil end
            for part, state in pairs(_saved) do
                if part and part.Parent then part.CanCollide=state end
            end; _saved={}
        end
    end
end

-- ============================================================
-- INFINITE JUMP (Vision Hub exact)
-- ============================================================
do
    local _ijConn = nil
    function Modules.InfiniteJump(enable)
        Modules.Config.InfiniteJump = enable
        if _ijConn then _ijConn:Disconnect(); _ijConn=nil end
        if enable then
            _ijConn = AddConnection(UserInputService.JumpRequest:Connect(function()
                if Modules.Humanoid then
                    Modules.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
                end
            end))
        end
    end
end

-- ============================================================
-- GRAB GUN (Vision Hub exact)
-- ============================================================
do
    local grabConn = nil
    function Modules.GrabGun()
        local root = Modules.RootPart
        if not root or not root.Parent then return end
        local map = getMap(); if not map then return end
        local gunDrop = map:FindFirstChild("GunDrop")
        if gunDrop and gunDrop:IsA("BasePart") then
            pcall(function()
                firetouchinterest(gunDrop, root, 1)
                firetouchinterest(gunDrop, root, 0)
            end)
        end
    end
    function Modules.ToggleAutoGrabGun(enable)
        Modules.Config.AutoGrabGun = enable
        if grabConn then grabConn:Disconnect(); grabConn=nil end
        if enable then grabConn = AddConnection(RunService.Heartbeat:Connect(Modules.GrabGun)) end
    end
end

-- ============================================================
-- KILL ALL (firetouchinterest on knife Handle — no teleport needed)
-- ============================================================
local function equipKnife()
    local char = LocalPlayer.Character
    local hum  = char and char:FindFirstChildOfClass("Humanoid")
    if not hum then return nil end
    local knife = char:FindFirstChild("Knife")
    if knife then return knife end
    knife = LocalPlayer.Backpack:FindFirstChild("Knife")
    if knife then
        hum:EquipTool(knife)
        task.wait(0.1)
        return char:FindFirstChild("Knife")
    end
    return nil
end

do
    function Modules.KillAll()
        local char = Modules.Character
        local hum  = Modules.Humanoid
        if not char or not hum or hum.Health <= 0 then return end

        local knife = equipKnife()
        if not knife then return end
        local handle = knife:FindFirstChild("Handle")
        if not handle then return end

        for _, v in ipairs(Players:GetPlayers()) do
            if v ~= Modules.Player and v.Character then
                local vh = v.Character:FindFirstChildOfClass("Humanoid")
                local tHRP = v.Character:FindFirstChild("HumanoidRootPart")
                if vh and vh.Health > 0 and tHRP then
                    VirtualUser:ClickButton1(Vector2.new())
                    firetouchinterest(tHRP, handle, 1)
                    firetouchinterest(tHRP, handle, 0)
                    task.wait(0.05)
                end
            end
        end
    end
end

do
    local autoKillId = 0
    function Modules.ToggleAutoKillAll(enable)
        Modules.Config.AutoKill = enable
        autoKillId = autoKillId + 1
        if not enable then return end
        local myId = autoKillId
        task.spawn(function()
            while Modules.Config.AutoKill and autoKillId == myId do
                local char = Modules.Character
                local hum  = Modules.Humanoid
                if char and hum and hum.Health > 0 then
                    local knife = char:FindFirstChild("Knife")
                        or (Modules.Backpack and Modules.Backpack:FindFirstChild("Knife"))
                    if knife then
                        pcall(Modules.KillAll)
                    end
                end
                task.wait(0.5)
            end
        end)
    end
end

-- ============================================================
-- KILL AURA (Vision Hub exact)
-- ============================================================
do
    local auraConn = nil
    function Modules.KillAura(enable)
        Modules.Config.KillAura = enable
        if auraConn then auraConn:Disconnect(); auraConn=nil end
        if not enable then return end
        auraConn = AddConnection(RunService.Heartbeat:Connect(function()
            local Knife = Modules.Character and Modules.Character:FindFirstChild("Knife")
            if not Knife or not Knife:IsA("Tool") then return end
            local Handle = Knife:FindFirstChild("Handle")
            local Stab   = Knife:FindFirstChild("Stab")
            local Root   = Modules.RootPart
            if not Handle or not Root or Knife.Parent ~= Modules.Character then return end
            local range = math.max(1, tonumber(Modules.Config.AuraRadius) or 10)
            for _, v in ipairs(Players:GetPlayers()) do
                if v ~= Modules.Player and v.Character then
                    local hum = v.Character:FindFirstChildOfClass("Humanoid")
                    local er  = v.Character:FindFirstChild("HumanoidRootPart") or v.Character.PrimaryPart
                    if hum and hum.Health>0 and er and (er.Position-Root.Position).Magnitude<=range then
                        firetouchinterest(Handle, er, 1)
                        firetouchinterest(Handle, er, 0)
                        if Stab and typeof(Stab.FireServer)=="function" then Stab:FireServer(er.Position) end
                        break
                    end
                end
            end
        end))
    end
end

-- ============================================================
-- SILENT THROW / THROW KNIFE (Vision Hub exact)
-- ============================================================
do
    local throwTask = nil
    function Modules.ExecuteThrowAtNearest()
        local knife = (Modules.Backpack and Modules.Backpack:FindFirstChild("Knife"))
            or (Modules.Character and Modules.Character:FindFirstChild("Knife"))
        if knife and knife.Parent == Modules.Backpack and Modules.Humanoid then
            Modules.Humanoid:EquipTool(knife); task.wait(0.1)
            knife = Modules.Character and Modules.Character:FindFirstChild("Knife")
        end
        if not knife or not knife:FindFirstChild("Throw") then return end
        if not Modules.RootPart then return end
        local myPos = Modules.RootPart.Position
        local target, dist = nil, 1000
        for _, v in ipairs(Players:GetPlayers()) do
            if v ~= Modules.Player and v.Character then
                local h = v.Character:FindFirstChild("Humanoid")
                local r = v.Character:FindFirstChild("HumanoidRootPart")
                if h and h.Health>0 and r then
                    local d = (myPos-r.Position).Magnitude
                    if d < dist then dist=d; target=r end
                end
            end
        end
        if target then
            local vel = target.AssemblyLinearVelocity or Vector3.new()
            local pred = target.Position + (vel * 0.05 * (dist/100))
            local throwCF = CFrame.new(myPos, pred)
            pcall(function() knife.Throw:FireServer(throwCF, pred) end)
        end
    end
    function Modules.ToggleSilentThrow(enable)
        Modules.Config.SilentThrow = enable
        if throwTask then pcall(task.cancel, throwTask); throwTask=nil end
        if enable then
            throwTask = task.spawn(function()
                while Modules.Config.SilentThrow do
                    if Modules.FindMurderer() == Modules.Player then
                        Modules.ExecuteThrowAtNearest()
                    end
                    task.wait(0.8)
                end
            end)
        end
    end
end

-- ============================================================
-- NOTIFY GUN DROPPED (Vision Hub exact)
-- ============================================================
do
    local _notifyConn = nil; local _lastNotified = nil
    local function notifyGun(gunPart)
        if not gunPart or not gunPart.Parent then return end
        if _lastNotified == gunPart then return end
        _lastNotified = gunPart
        pcall(function()
            WindUI:Notify({Title="Gun Dropped", Content="A gun has been dropped in the map.",
                Icon="crosshair", Duration=5})
        end)
    end
    function Modules.ToggleNotifyGunDropped(enable)
        Modules.Config.NotifyGunDropped = enable
        if _notifyConn then _notifyConn:Disconnect(); _notifyConn=nil end
        _lastNotified = nil
        if not enable then return end
        _notifyConn = AddConnection(workspace.DescendantAdded:Connect(function(d)
            if not Modules.Config.NotifyGunDropped then return end
            if d.Name=="GunDrop" and d:IsA("BasePart") then notifyGun(d) end
        end))
    end
end

-- ============================================================
-- PLAY EMOTE (Vision Hub exact)
-- ============================================================
function Modules.PlayEmote(emoteName)
    pcall(function()
        local remotes = ReplicatedStorage:FindFirstChild("Remotes")
        if remotes and remotes:FindFirstChild("PlayEmote") then
            remotes.PlayEmote:Fire(emoteName)
        elseif ReplicatedStorage:FindFirstChild("PlayEmote", true) then
            ReplicatedStorage:FindFirstChild("PlayEmote", true):Fire(emoteName)
        end
    end)
end

-- ============================================================
-- ROUND TIMER (event-based — GetTimer blocks in lobby so we use RoundStart/GameOver)
-- ============================================================
do
    local timerTask = nil; local timerGui = nil
    local roundEndTime = nil  -- tick() when round ends

    local function fmtTime(s)
        if not s or s < 0 then return "LOBBY" end
        return string.format("%d:%02d", math.floor(s/60), math.floor(s%60))
    end

    -- listen for round events globally
    local _roundStartConn, _gameOverConn
    pcall(function()
        _roundStartConn = AddConnection(ReplicatedStorage.Remotes.Gameplay.RoundStart.OnClientEvent:Connect(function()
            -- call GetTimer in a separate thread with a 3s timeout to get accurate start time
            task.spawn(function()
                local duration = 180  -- default MM2 round length
                local done = false
                task.spawn(function()
                    local ok, v = pcall(function()
                        return ReplicatedStorage.Remotes.Extras.GetTimer:InvokeServer()
                    end)
                    if ok and type(v)=="number" and v > 0 then duration = v end
                    done = true
                end)
                local t0 = tick()
                while not done and tick()-t0 < 3 do task.wait(0.1) end
                roundEndTime = tick() + duration
            end)
        end))
        _gameOverConn = AddConnection(ReplicatedStorage.Remotes.Gameplay.GameOver.OnClientEvent:Connect(function()
            roundEndTime = nil
        end))
    end)

    function Modules.ToggleRoundTimer(enable)
        Modules.Config.RoundTimer = enable
        if timerGui then timerGui:Destroy(); timerGui=nil end
        if timerTask then pcall(task.cancel,timerTask); timerTask=nil end
        if not enable then return end

        timerGui = Instance.new("ScreenGui")
        timerGui.Name="MM2HubTimer"; timerGui.ResetOnSpawn=false; timerGui.IgnoreGuiInset=true
        timerGui.DisplayOrder=50
        pcall(function() timerGui.Parent=CoreGui end)
        if not timerGui.Parent then timerGui.Parent=LocalPlayer.PlayerGui end

        local bg=Instance.new("Frame",timerGui)
        bg.Size=UDim2.fromOffset(130,40); bg.Position=UDim2.new(0.5,-65,0,8)
        bg.BackgroundColor3=Color3.fromRGB(10,10,18); bg.BackgroundTransparency=0.25
        bg.BorderSizePixel=0
        Instance.new("UICorner",bg).CornerRadius=UDim.new(0,10)
        local bgStroke=Instance.new("UIStroke",bg)
        bgStroke.Color=borderColor; bgStroke.Thickness=1.5
        bgStroke.ApplyStrokeMode=Enum.ApplyStrokeMode.Border

        local lbl=Instance.new("TextLabel",bg)
        lbl.Size=UDim2.new(1,0,1,0); lbl.BackgroundTransparency=1
        lbl.Font=Enum.Font.GothamBold; lbl.TextSize=18
        lbl.TextColor3=Color3.fromRGB(255,255,255); lbl.TextStrokeTransparency=0.5
        lbl.Text="LOBBY"

        timerTask = task.spawn(function()
            while timerGui and timerGui.Parent do
                if roundEndTime then
                    local remaining = roundEndTime - tick()
                    if remaining < 0 then remaining = 0 end
                    lbl.Text = fmtTime(remaining)
                    lbl.TextColor3 = remaining <= 15
                        and Color3.fromRGB(255,60,60)
                        or  Color3.fromRGB(255,255,255)
                else
                    lbl.Text = "LOBBY"
                    lbl.TextColor3 = Color3.fromRGB(160,160,180)
                end
                -- keep border color synced
                bgStroke.Color = borderColor
                task.wait(0.25)
            end
        end)
    end
end

-- ============================================================
-- NOTIFY MURDERER / SHERIFF (Vision Hub exact)
-- ============================================================
do
    local roleMonTask = nil; local notifiedM = false; local notifiedS = false
    -- reset on round boundaries
    AddConnection(ReplicatedStorage.Remotes.Gameplay.RoundStart.OnClientEvent:Connect(function()
        notifiedM=false; notifiedS=false
    end))
    AddConnection(ReplicatedStorage.Remotes.Gameplay.GameOver.OnClientEvent:Connect(function()
        notifiedM=false; notifiedS=false
    end))

    local function loopRoleMonitor()
        while true do
            -- use getMap() to detect if in round — works even if script ran mid-round
            local inRound = getMap() ~= nil
            if inRound then
                -- get roles from server for accuracy
                local murdName, sherName = nil, nil
                pcall(function()
                    local roles = ReplicatedStorage:FindFirstChild("GetPlayerData", true):InvokeServer()
                    if type(roles)=="table" then
                        for name, data in pairs(roles) do
                            if data and data.Role == "Murderer" then murdName = name
                            elseif data and data.Role == "Sheriff" then sherName = name
                            end
                        end
                    end
                end)

                if Modules.Config.NotifyMurderer and not notifiedM then
                    local p = murdName and Players:FindFirstChild(murdName) or Modules.FindMurderer()
                    if p then
                        notifiedM = true
                        pcall(function()
                            WindUI:Notify({Title="🔪 Murderer Detected!", Content=p.Name,
                                Icon="rbxthumb://type=AvatarHeadShot&id="..p.UserId.."&w=150&h=150",
                                Duration=8})
                        end)
                    end
                end
                if Modules.Config.NotifySheriff and not notifiedS then
                    local p = sherName and Players:FindFirstChild(sherName) or Modules.FindSheriff()
                    if p then
                        notifiedS = true
                        pcall(function()
                            WindUI:Notify({Title="🔫 Sheriff Detected!", Content=p.Name,
                                Icon="rbxthumb://type=AvatarHeadShot&id="..p.UserId.."&w=150&h=150",
                                Duration=8})
                        end)
                    end
                end
            else
                -- in lobby, reset so next round fires again
                notifiedM=false; notifiedS=false
            end
            task.wait(1.5)
        end
    end
    function Modules.UpdateRoleNotify()
        if roleMonTask then pcall(task.cancel, roleMonTask); roleMonTask=nil end
        if Modules.Config.NotifyMurderer or Modules.Config.NotifySheriff then
            roleMonTask = task.spawn(loopRoleMonitor)
        end
    end
end

-- ============================================================
-- CHAT ROLES (Vision Hub exact)
-- ============================================================
local function sendChat(msg)
    if TextChatService.ChatVersion==Enum.ChatVersion.TextChatService then
        local chan=TextChatService:FindFirstChild("TextChannels")
        if chan and chan:FindFirstChild("RBXGeneral") then
            pcall(function() chan.RBXGeneral:SendAsync(msg) end)
        end
    else
        local es=ReplicatedStorage:FindFirstChild("DefaultChatSystemChatEvents")
        if es and es:FindFirstChild("SayMessageRequest") then
            pcall(function() es.SayMessageRequest:FireServer(msg,"Normal") end)
        end
    end
end

function Modules.ChatRoles()
    -- use GetPlayerData for accurate server-side roles
    local murdName, sherName, heroName = "Unknown", "Unknown", nil
    pcall(function()
        local roles = ReplicatedStorage:FindFirstChild("GetPlayerData", true):InvokeServer()
        if type(roles)=="table" then
            for name, data in pairs(roles) do
                if data and data.Role == "Murderer" then murdName = name
                elseif data and data.Role == "Sheriff" then sherName = name
                elseif data and data.Role == "Hero" then heroName = name
                end
            end
        end
    end)
    -- fallback to tool check
    if murdName == "Unknown" then local m = Modules.FindMurderer(); murdName = m and m.Name or "Unknown" end
    if sherName == "Unknown" then local s = Modules.FindSheriff(); sherName = s and s.Name or "Unknown" end

    local msg = "🔪 Murderer: "..murdName.." | 🔫 Sheriff: "..sherName
    if heroName then msg = msg .. " | ⭐ Hero: "..heroName end
    sendChat(msg)
end

-- ============================================================
-- CREATE GUI BUTTON (Vision Hub exact)
-- ============================================================
function Modules.CreateGuiButton(id, settings, callback)
    if Modules.MobileButtons[id] then
        if Modules.MobileButtons[id].Parent then Modules.MobileButtons[id]:Destroy() end
        Modules.MobileButtons[id] = nil
    end
    if not settings.Enabled then return end

    local sg = Instance.new("ScreenGui")
    sg.Name = "VisionBtn_"..id; sg.Parent=CoreGui
    sg.ResetOnSpawn=false; sg.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
    Modules.MobileButtons[id] = sg

    local btnCount=0
    for _, g in pairs(Modules.MobileButtons) do if g and g.Parent then btnCount=btnCount+1 end end

    local btn
    if settings.Type=="Text" then
        btn=Instance.new("TextButton")
        btn.Text=settings.Text or id
        btn.TextColor3=settings.TextColor or Color3.new(1,1,1)
        btn.TextScaled=true; btn.Font=Enum.Font.GothamBold
    else
        btn=Instance.new("ImageButton")
        btn.Image=settings.Icon or ""
        btn.ImageColor3=settings.ImageColor or Color3.fromRGB(230,247,255)
    end
    btn.Name="ActionBtn"; btn.Size=UDim2.fromOffset(60,60)
    local iy=0.45+(btnCount*0.08); if iy>0.8 then iy=0.45 end
    btn.Position=UDim2.new(0.9,-20,iy,0)
    btn.BackgroundColor3=Color3.fromRGB(9,32,43); btn.BackgroundTransparency=0.3
    btn.AutoButtonColor=true; btn.Parent=sg
    Instance.new("UICorner",btn).CornerRadius=UDim.new(1,0)
    local stroke=Instance.new("UIStroke",btn)
    stroke.Color=Color3.fromRGB(0,191,255); stroke.Thickness=2.5
    stroke.ApplyStrokeMode=Enum.ApplyStrokeMode.Border

    local dragging,dragStart,startPos,hasMoved=false,nil,nil,false
    btn.InputBegan:Connect(function(inp)
        if inp.UserInputType==Enum.UserInputType.MouseButton1 or inp.UserInputType==Enum.UserInputType.Touch then
            dragging=true; hasMoved=false; dragStart=inp.Position; startPos=btn.Position
        end
    end)
    btn.InputChanged:Connect(function(inp)
        if (inp.UserInputType==Enum.UserInputType.MouseMovement or inp.UserInputType==Enum.UserInputType.Touch) and dragging then
            if Modules.Config.ButtonsLocked then return end
            local delta=inp.Position-dragStart
            if delta.Magnitude>3 then hasMoved=true end
            btn.Position=UDim2.new(startPos.X.Scale,startPos.X.Offset+delta.X,startPos.Y.Scale,startPos.Y.Offset+delta.Y)
        end
    end)
    btn.InputEnded:Connect(function(inp)
        if inp.UserInputType==Enum.UserInputType.MouseButton1 or inp.UserInputType==Enum.UserInputType.Touch then
            dragging=false
            if not hasMoved or Modules.Config.ButtonsLocked then
                if callback then
                    local orig=stroke.Color; stroke.Color=Color3.new(1,1,1)
                    task.spawn(callback)
                    task.delay(0.15,function() if stroke and stroke.Parent then stroke.Color=orig end end)
                end
            end
        end
    end)
end

-- ============================================================
-- FONT (apply to PlayerGui + workspace only, NOT CoreGui)
-- ============================================================
local FONT_ASSET = "rbxassetid://16658246179"
pcall(function() WindUI:SetFont(FONT_ASSET) end)
task.spawn(function()
    task.wait(1.5)
    local function applyFont(root)
        if not root then return end
        for _, obj in ipairs(root:GetDescendants()) do
            pcall(function()
                if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
                    obj.FontFace = Font.new(FONT_ASSET)
                end
            end)
        end
    end
    applyFont(LocalPlayer:FindFirstChild("PlayerGui"))
    applyFont(StarterGui)
    for _, obj in ipairs(workspace:GetDescendants()) do
        pcall(function()
            if (obj:IsA("BillboardGui") or obj:IsA("SurfaceGui")) and not obj:IsDescendantOf(CoreGui) then
                for _, c in ipairs(obj:GetDescendants()) do
                    if c:IsA("TextLabel") or c:IsA("TextButton") then
                        c.FontFace = Font.new(FONT_ASSET)
                    end
                end
            end
        end)
    end
end)

-- ============================================================
-- MOBILE DETECTION
-- ============================================================
local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

-- ============================================================
-- WINDOW (our styling — MAC buttons, gradient open button)
-- ============================================================
local _borderStroke  = nil
local borderColor    = Color3.fromRGB(255, 115, 0)
local borderThickness= 5

-- avatar as topbar icon
local _avatarIcon = "rbxthumb://type=AvatarHeadShot&id="..LocalPlayer.UserId.."&w=150&h=150"

local Window = WindUI:CreateWindow({
    Title   = "🎃 Ghost HUB",
    Author  = "👻 halloween · v5.0",
    Folder  = "GhostHubV5",
    Icon    = _avatarIcon,
    Size    = isMobile and UDim2.new(0,280,0,380) or UDim2.new(0,620,0,680),
    Transparent   = false,
    Theme         = "Dark",
    NewElements   = true,
    SideBarWidth  = isMobile and 110 or 200,
    HideSearchBar = false,
    User    = { Enabled=false, Anonymous=false },
    Topbar  = { Height=52, ButtonsType="Mac" },
})

Window.ConfigManager:CreateConfig("Default")
pcall(function() Window:SetToggleKey(Enum.KeyCode.G) end)

-- ============================================================
-- 🎃 CANDY HARVEST — FARM / AUTOMATION SYSTEM
-- ============================================================
local FarmConfig = {
    -- Coin Farm
    CoinEnabled       = false,
    CoinSpeed         = 22,
    CoinInstantTP     = false,
    CoinFarmV2        = false,  -- firetouchinterest instant collection
    AutoFlingOnDone   = false,
    -- Bag Full Actions
    KillAtBag         = false,
    FlingAtBag        = false,
    TeleportUnderAtBag= false,
    DieAtBag          = false,
    -- Other
    XPFarmEnabled     = false,
    AntiAFKEnabled    = false,
    AutoPrestige      = false,
    AutoOpenCrates    = false,
    CrateName         = "Classic",
    CrateType         = "Normal",
    AutoServerHopEmpty= false,
    ServerHopThreshold= 2,
    EmoteSpam         = false,
    EmoteSpamSpeed    = 1,
    SelectedEmote     = "zombie",
    ShuffleWeapons    = false,
    KillOnStart       = false,
    FlingMurdOnStart  = false,
    FlingSheriOnStart = false,
}
local _farmFlingCooldown = 0
local _antiAFKConn       = nil
local _bagFullHandled    = false

-- ── Coin helpers (AutoFarm v1 method: TouchInterest check) ──
local function getCoins()
    local coins = {}
    for _, child in ipairs(workspace:GetChildren()) do
        local container = child:FindFirstChild("CoinContainer")
        if container then
            for _, obj in ipairs(container:GetChildren()) do
                if obj.Name == "Coin_Server" and obj:IsA("BasePart") and obj.Parent
                    and not obj:FindFirstChild("CollectedCoin")
                    and obj:FindFirstChild("TouchInterest") then
                    table.insert(coins, obj)
                end
            end
        end
    end
    if #coins == 0 then
        for _, obj in ipairs(workspace:GetDescendants()) do
            if (obj.Name == "Coin" or obj.Name == "Coin_Server")
                and obj:IsA("BasePart") and obj.Parent then
                table.insert(coins, obj)
            end
        end
    end
    return coins
end

local function getNearestCoin(from)
    local best, bestDist = nil, math.huge
    for _, c in ipairs(getCoins()) do
        local d = (c.Position - from).Magnitude
        if d < bestDist then bestDist = d; best = c end
    end
    return best, bestDist
end

local function isBagFull()
    local ok, full = pcall(function()
        local gui = LocalPlayer:FindFirstChildWhichIsA("PlayerGui", true)
        if not gui then return false end
        local bag = gui:FindFirstChild("Bag", true)
        if bag then
            local indicator = bag:FindFirstChild("Full", true) or bag:FindFirstChild("FullBagIcon", true)
            if indicator then return indicator.Visible end
        end
        -- AutoFarm method: Game.CoinBags.Container.Candy.Full.Visible
        local cb = workspace:FindFirstChild("Game")
        if cb then
            local c = cb:FindFirstChild("CoinBags")
            if c then
                local cont = c:FindFirstChild("Container")
                if cont then
                    local candy = cont:FindFirstChild("Candy")
                    if candy then
                        local f = candy:FindFirstChild("Full")
                        if f and f:IsA("GuiObject") then return f.Visible end
                    end
                end
            end
        end
        return false
    end)
    return ok and full
end

-- ── Safe spot teleport (AutoFarm v2 safe spot) ──
local function teleportToSafeSpot()
    local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    if workspace:FindFirstChild("GhostSafeSpot") then
        hrp.CFrame = CFrame.new(-106, 87.5, 2)
    else
        local Part = Instance.new("Part")
        Part.Name = "GhostSafeSpot"; Part.Size = Vector3.new(25, 3, 25)
        Part.Position = Vector3.new(-106, 83, 2); Part.Parent = workspace
        Part.Anchored = true; Part.CanCollide = true; Part.Transparency = 0
        task.wait()
        for i = 1, 3 do
            local h2 = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if not h2 then return end
            h2.CFrame = CFrame.new(-106, 87.5, 2)
            task.wait(0.1)
        end
    end
end

-- ── Kill All Anchor (AutoFarm method: anchor HRP + Stab:FireServer) ──
local function killAllAnchor()
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not char or not hum then return end
    if not char:FindFirstChild("Knife") then
        local knife = LocalPlayer.Backpack and LocalPlayer.Backpack:FindFirstChild("Knife")
        if not knife then return end
        hum:EquipTool(knife)
    end
    local myHRP = char:FindFirstChild("HumanoidRootPart")
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local HRP = player.Character:FindFirstChild("HumanoidRootPart")
            if HRP and myHRP then
                HRP.Anchored = true
                HRP.CFrame = myHRP.CFrame + myHRP.CFrame.LookVector * 1
            end
        end
    end
    pcall(function() char.Knife.Stab:FireServer("Slash") end)
end

-- ── Destroy map except coins ──
local function destroyMapExceptCoins()
    for _, child in pairs(workspace:GetChildren()) do
        if child:IsA("Model") and child:FindFirstChild("CoinContainer") then
            for _, child2 in pairs(child:GetChildren()) do
                if child2.Name ~= "CoinContainer" then pcall(function() child2:Destroy() end) end
            end
        end
    end
end

-- ── Destroy other players from workspace ──
local function destroyOtherPlayers()
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local char2 = workspace:FindFirstChild(player.Name)
            if char2 then pcall(function() char2:Destroy() end) end
        end
    end
end

-- ── Shuffle weapons ──
local function shuffleWeapons()
    local weapons = {}
    pcall(function()
        local result = require(ReplicatedStorage.Modules.InventoryModule).MyInventory.Data.Weapons
        for _, v in pairs(result) do
            for k in pairs(v) do table.insert(weapons, k) end
        end
    end)
    if #weapons == 0 then return end
    local randomWeapon = weapons[math.random(1, #weapons)]
    pcall(function() ReplicatedStorage.Remotes.Inventory.Equip:FireServer(randomWeapon, "Weapons") end)
end

local function flingMurdererFarm()
    local now = tick()
    if now - _farmFlingCooldown < 8 then return end
    _farmFlingCooldown = now
    local m = Modules.FindMurderer()
    if m and m ~= LocalPlayer then
        task.spawn(function() miniFling({m.Name}) end)
    end
end

local function applyAntiAFK(enabled)
    if _antiAFKConn then _antiAFKConn:Disconnect(); _antiAFKConn = nil end
    if enabled then
        _antiAFKConn = LocalPlayer.Idled:Connect(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
        end)
    end
end

-- ── Stats overlay ──
local _coinsCollected = 0; local _farmStartTime = tick()
pcall(function()
    local CoinCollected = ReplicatedStorage.Remotes.Gameplay:FindFirstChild("CoinCollected")
    if CoinCollected then
        AddConnection(CoinCollected.OnClientEvent:Connect(function(_, p1, p2)
            if p1 == LocalPlayer then _coinsCollected = _coinsCollected + 1 end
            -- Bag full handler
            if p1 == p2 and not _bagFullHandled then
                _bagFullHandled = true
                task.spawn(function()
                    if FarmConfig.KillAtBag and Modules.FindMurderer() == LocalPlayer then
                        for i = 1, 10 do
                            if Modules.FindMurderer() ~= LocalPlayer then break end
                            killAllAnchor(); task.wait(1)
                        end
                    elseif FarmConfig.FlingAtBag and Modules.FindMurderer() ~= LocalPlayer then
                        for i = 1, 5 do
                            local murd = Modules.FindMurderer()
                            if not murd or murd == LocalPlayer then break end
                            miniFling({murd.Name}); task.wait(1)
                        end
                    elseif FarmConfig.TeleportUnderAtBag then
                        task.wait(0.1); teleportToSafeSpot()
                    elseif FarmConfig.DieAtBag then
                        local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
                        if hum then hum:ChangeState(Enum.HumanoidStateType.Dead) end
                    end
                    task.wait(2); _bagFullHandled = false
                end)
            end
        end))
    end
end)

-- ── Round start handler ──
pcall(function()
    AddConnection(ReplicatedStorage.Remotes.Gameplay.RoundStart.OnClientEvent:Connect(function()
        _coinsCollected = 0; _farmStartTime = tick()
        if FarmConfig.KillOnStart then
            task.spawn(function()
                task.wait(1)
                repeat killAllAnchor(); task.wait(1) until Modules.FindMurderer() ~= LocalPlayer
            end)
        end
        if FarmConfig.FlingMurdOnStart then
            local m = Modules.FindMurderer()
            if m and m ~= LocalPlayer then task.spawn(function() miniFling({m.Name}) end) end
        end
        if FarmConfig.FlingSheriOnStart then
            local s = Modules.FindSheriff()
            if s and s ~= LocalPlayer then task.spawn(function() miniFling({s.Name}) end) end
        end
    end))
end)

-- ── CoinFarm v2: firetouchinterest instant collection loop ──
task.spawn(function()
    while true do
        task.wait(0.05)
        if FarmConfig.CoinFarmV2 and firetouchinterest then
            local lc  = LocalPlayer.Character
            local hrp = lc and lc:FindFirstChild("HumanoidRootPart")
            if hrp then
                for _, child in ipairs(workspace:GetChildren()) do
                    local container = child:FindFirstChild("CoinContainer")
                    if container then
                        for _, coin in ipairs(container:GetChildren()) do
                            if coin.Name == "Coin_Server" and coin:IsA("BasePart")
                                and not coin:FindFirstChild("CollectedCoin")
                                and coin:FindFirstChild("TouchInterest") then
                                pcall(function()
                                    firetouchinterest(hrp, coin, 0)
                                    firetouchinterest(hrp, coin, 1)
                                end)
                            end
                        end
                    end
                end
            end
        end
    end
end)

-- ── CoinFarm v1: TweenService smooth / instant TP loop ──
task.spawn(function()
    while true do
        task.wait(0.05)
        if FarmConfig.CoinEnabled and not FarmConfig.CoinFarmV2 then
            if isBagFull() then
                if FarmConfig.AutoFlingOnDone then flingMurdererFarm() end
            else
                local lc  = LocalPlayer.Character
                local hrp = lc and lc:FindFirstChild("HumanoidRootPart")
                if hrp then
                    local coin, dist = getNearestCoin(hrp.Position)
                    if coin then
                        if FarmConfig.CoinInstantTP then
                            pcall(function() hrp.CFrame = CFrame.new(coin.Position + Vector3.new(0, 3, 0)) end)
                        else
                            local step = math.min(FarmConfig.CoinSpeed * 0.05, dist)
                            local dir  = (coin.Position - hrp.Position).Unit
                            pcall(function() hrp.CFrame = CFrame.new(hrp.Position + dir * step) end)
                        end
                    else
                        if FarmConfig.AutoFlingOnDone then flingMurdererFarm() end
                    end
                end
            end
        end
    end
end)

-- ── XP farm loop ──
task.spawn(function()
    while true do
        task.wait(1.5)
        if FarmConfig.XPFarmEnabled then
            local lc  = LocalPlayer.Character
            local hrp = lc and lc:FindFirstChild("HumanoidRootPart")
            if hrp then
                for _, p in ipairs(Players:GetPlayers()) do
                    if p ~= LocalPlayer then
                        local bp2 = p:FindFirstChild("Backpack")
                        local isMurd = p.Character and (p.Character:FindFirstChild("Knife") or (bp2 and bp2:FindFirstChild("Knife")))
                        if isMurd then
                            local mHRP = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
                            if mHRP then
                                pcall(function() hrp.CFrame = mHRP.CFrame * CFrame.new(0, 0, 3) end)
                                task.wait(0.1)
                                local tool = lc:FindFirstChildWhichIsA("Tool")
                                if tool then
                                    local remote = tool:FindFirstChildOfClass("RemoteEvent") or tool:FindFirstChildOfClass("RemoteFunction")
                                    if remote then pcall(function() remote:FireServer(mHRP.CFrame) end) end
                                end
                            end
                            break
                        end
                    end
                end
            end
        end
    end
end)

-- ── Auto Prestige loop ──
task.spawn(function()
    while true do
        task.wait(30)
        if FarmConfig.AutoPrestige then
            pcall(function() ReplicatedStorage.Remotes.Inventory.Prestige:FireServer() end)
        end
    end
end)

-- ── Auto Open Crates loop ──
task.spawn(function()
    while true do
        task.wait(1)
        if FarmConfig.AutoOpenCrates then
            pcall(function()
                ReplicatedStorage.Remotes.MysteryBox.OpenBox:FireServer("OpenBox", FarmConfig.CrateName, FarmConfig.CrateType)
            end)
        end
    end
end)

-- ── Emote spam loop ──
task.spawn(function()
    while true do
        task.wait(1 / math.max(FarmConfig.EmoteSpamSpeed, 1))
        if FarmConfig.EmoteSpam then
            pcall(function() ReplicatedStorage.Remotes.Misc.PlayEmote:Fire(FarmConfig.SelectedEmote) end)
        end
    end
end)

-- ── Shuffle weapons loop ──
task.spawn(function()
    while true do
        task.wait(5)
        if FarmConfig.ShuffleWeapons then shuffleWeapons() end
    end
end)

-- ── Server hop when empty ──
AddConnection(Players.PlayerRemoving:Connect(function()
    task.defer(function()
        if FarmConfig.AutoServerHopEmpty and #Players:GetPlayers() <= FarmConfig.ServerHopThreshold then
            Modules.ServerHop()
        end
    end)
end))

-- ============================================================
-- TABS (our sidebar Section system + Vision Hub tab content)
-- ============================================================

-- ── HOME ────────────────────────────────────────────────────
local HomeTab = Window:Tab({Title="🎃 Haunted Hub", Icon="skull"})
HomeTab:Paragraph({
    Title = "🎃 Welcome to Ghost HUB!",
    Desc  = "Halloween Edition v5.0 — All AutoFarm methods loaded. RShift to toggle.",
})
HomeTab:Space()
HomeTab:Paragraph({
    Title = "🕸️ Changelog v5.0 — Halloween",
    Desc  = [[
[Ghost HUB v5.0 — Halloween Edition]
+ Full Halloween theme: orange border, spooky names
+ AutoFarm v1: TweenService smooth coin farm (TouchInterest check)
+ AutoFarm v2: firetouchinterest instant collection
+ Kill All Anchor: anchor HRP + Stab:FireServer("Slash")
+ AH2 Auto Shoot: RenderStepped raycast + KnifeLocal.CreateBeam:InvokeServer
+ Bag Full Actions: Kill / Fling / Teleport Under / Die at bag full
+ Round Start: Kill All, Fling Murderer, Fling Sheriff on start
+ Auto Prestige (every 30s)
+ Auto Open Crates (every 1s, custom name/type)
+ Auto Server Hop When Empty (player threshold)
+ Emote Spam (speed slider)
+ Shuffle Weapons (random every 5s)
+ Destroy Map Except Coins
+ Destroy Other Players
+ Candy Stats: coins/hr counter
+ Safe Spot teleport (-106, 87.5, 2)
--- Original features below ---
+ Script by Zovlane
+ MultiSection Combat (General / Murderer / Sheriff)
+ MultiSection Visuals (ESP / Notify)
+ MultiSection Teleports (Players / Roles / Locations)
+ MultiSection Misc (Fling / Emotes / Chat)
+ ButtonKeybind elements (G=GrabGun, K=KillAll, E=Shoot, Q=Throw)
+ Buttons tab — draggable individual mobile buttons
+ Save / Load Config
+ Auto Shoot with ping prediction (rf:InvokeServer AH2)
+ Kill All + Auto Kill + Knife Aura (with Stab remote)
+ Auto Knife Throw / Throw Knife
+ God Mode (HealthChanged + polling)
+ Anti-Fling (CanCollide=false on others)
+ Noclip + Infinite Jump
+ ESP: Highlight + BillboardGui names + Hero role
+ Gun Drop ESP (Highlight + BillboardGui)
+ Round Timer HUD
+ Notify Murderer / Sheriff (avatar thumbnails)
+ Notify Gun Dropped
+ Fling by role (Murderer / Sheriff / Hero)
+ Teleport to Map / Lobby / Player / Role
+ Server Hop + Rejoin (with confirm dialog)
+ Queue on Teleport toggle
+ Emotes (sit, zombie, ninja, zen, floss, dab)
+ Chat Roles in chat
+ Farming tab placeholder
+ Our GUI: border, open pill, MAC buttons, avatar, font
    ]]
})
HomeTab:Space()
HomeTab:Paragraph({Title="Found a bug?", Desc="-- Re-execute the script or rejoin --"})

-- ── COMBAT SECTION ─────────────────────────────────────────
local CombatSection = Window:Section({Title="Dark Spells 🔮", Opened=true})

-- Combat Tab
local CombatTab = CombatSection:Tab({Title="Blood Ritual 🩸", Icon="crosshair"})

local CombatGeneral = CombatTab:Section({Title="General", Opened=true})
CombatGeneral:Button({Title="Grab Gun [G]", Desc="Pick up gun from the map",
    Icon="hand", Callback=Modules.GrabGun})
CombatGeneral:Toggle({Title="Auto Grab Gun", Desc="Automatically grab gun", Flag="AutoGrabGunToggle",
    Callback=Modules.ToggleAutoGrabGun})
CombatGeneral:Space()
CombatGeneral:Toggle({Title="God Mode", Desc="Grants extra lives", Flag="GodModeToggle",
    Callback=Modules.EnableGodMode})
CombatGeneral:Toggle({Title="Anti-Fling", Desc="Prevents players from flinging you", Flag="AntiFlingToggle",
    Callback=Modules.ToggleAntiFling})

local CombatMurdS = CombatTab:Section({Title="💀 Murderer", Opened=true})
CombatMurdS:Button({Title="Kill All [K]", Desc="Kill all players (firetouchinterest)",
    Icon="skull", Callback=Modules.KillAll})
CombatMurdS:Button({Title="☠️ Kill All (Anchor)", Desc="Anchor HRP + Stab:FireServer — AutoFarm method",
    Icon="skull", Callback=function() task.spawn(killAllAnchor) end})
CombatMurdS:Toggle({Title="Auto Kill All", Desc="Automatically kill players", Flag="AutoKillToggle",
    Callback=Modules.ToggleAutoKillAll})
CombatMurdS:Space()
CombatMurdS:Toggle({Title="Knife Aura", Desc="Kill players within a radius", Flag="KillAuraToggle",
    Callback=Modules.KillAura})
CombatMurdS:Slider({Title="Aura Radius", Desc="Detection radius", Flag="AuraRadiusSlider",
    Value={Min=5,Max=100,Default=10}, Callback=function(v) Modules.Config.AuraRadius=v end})
CombatMurdS:Space()
CombatMurdS:Toggle({Title="Auto Knife Throw", Desc="Throws knife at nearest automatically", Flag="ThrowKnifeFlag",
    Callback=Modules.ToggleSilentThrow})
CombatMurdS:Button({Title="Throw Knife [Q]", Desc="Throw knife at nearest player",
    Icon="crosshair", Callback=Modules.ExecuteThrowAtNearest})

local CombatSherS = CombatTab:Section({Title="🔫 Sheriff", Opened=true})
CombatSherS:Toggle({Title="Auto Shoot (TP method)", Desc="Automatically shoots the murderer (TP + Shoot:FireServer)", Flag="AutoShootMurderer",
    Callback=Modules.ToggleAutoShootMurderer})
CombatSherS:Toggle({Title="🎯 Auto Shoot AH2", Desc="RenderStepped raycast + KnifeLocal.CreateBeam:InvokeServer — AutoFarm method", Flag="AutoShootAH2Toggle",
    Callback=function(v)
        if v then
            AddConnection(RunService.RenderStepped:Connect(function()
                if not v then return end
                local murderer = Modules.FindMurderer()
                if not murderer or not murderer.Character then return end
                local mHRP = murderer.Character:FindFirstChild("HumanoidRootPart")
                if not mHRP then return end
                local myChar = LocalPlayer.Character
                local myHRP = myChar and myChar:FindFirstChild("HumanoidRootPart")
                if not myHRP then return end
                local dir = mHRP.Position - myHRP.Position
                local rayParams = RaycastParams.new()
                rayParams.FilterType = Enum.RaycastFilterType.Exclude
                rayParams.FilterDescendantsInstances = {myChar}
                local hit = workspace:Raycast(myHRP.Position, dir, rayParams)
                if not hit or hit.Instance.Parent == murderer.Character then
                    local Gun = myChar:FindFirstChild("Gun") or LocalPlayer.Backpack:FindFirstChild("Gun")
                    if Gun then
                        local hum = myChar:FindFirstChildOfClass("Humanoid")
                        if hum and Gun.Parent == LocalPlayer.Backpack then hum:EquipTool(Gun) end
                        local UpperTorso = murderer.Character:FindFirstChild("UpperTorso")
                        local mHum = murderer.Character:FindFirstChild("Humanoid")
                        if not UpperTorso or not mHum then return end
                        local moveDir = mHum.MoveDirection
                        local predictedPos = UpperTorso.Position + UpperTorso.AssemblyLinearVelocity * Vector3.new(0, 0.5, 0) * 0.14 + moveDir * 2.8
                        pcall(function()
                            local Gun2 = myChar:FindFirstChild("Gun")
                            if Gun2 then Gun2.KnifeLocal.CreateBeam.RemoteFunction:InvokeServer(1, predictedPos, "AH2") end
                        end)
                    end
                end
            end))
        end
    end})
CombatSherS:Button({Title="TP & Shoot Murderer [E]", Desc="Teleports in front of murderer then shoots",
    Icon="crosshair", Callback=Modules.ShootMurdererOnce})
CombatSherS:Button({Title="Toggle Silent Aim", Desc="Hooks your gun — every shot auto-aims at murderer",
    Icon="crosshair", Callback=Modules.ShootMurdererSilent})

-- Visuals Tab
local VisualsTab = CombatSection:Tab({Title="Spirit Eye 👁", Icon="eye"})

-- ESP system (Vision Hub exact — Highlight + BillboardGui)
local ESP_Folder = CoreGui:FindFirstChild("VisionESP")
if not ESP_Folder then
    ESP_Folder = Instance.new("Folder"); ESP_Folder.Name="VisionESP"; ESP_Folder.Parent=CoreGui
end

local function CreateBillboard(targetHead)
    local bg = Instance.new("BillboardGui")
    bg.Name="NameESP"; bg.Adornee=targetHead
    bg.Size=UDim2.new(0,200,0,50); bg.StudsOffset=Vector3.new(0,3,0); bg.AlwaysOnTop=true
    local txt=Instance.new("TextLabel"); txt.BackgroundTransparency=1
    txt.Size=UDim2.new(1,0,1,0); txt.TextSize=16; txt.TextScaled=false
    txt.Font=Enum.Font.SourceSansBold; txt.TextColor3=Color3.new(1,1,1)
    txt.TextStrokeTransparency=0; txt.TextStrokeColor3=Color3.new(0,0,0); txt.Parent=bg
    return bg
end

local function UpdateESPState()
    local inMap = getMap() ~= nil  -- true = active round, false = lobby

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= Modules.Player and plr.Character then
            local char = plr.Character
            local plrHum = char:FindFirstChildOfClass("Humanoid")
            local plrAlive = plrHum and plrHum.Health > 0

            -- In a round: only ESP players who are alive in the map.
            -- In lobby: ESP everyone.
            local shouldShow = (not inMap) or plrAlive

            if not shouldShow then
                -- clean up ESP for this player (dead/spectating)
                local hl = char:FindFirstChild("VisionHighlight"); if hl then hl:Destroy() end
                local head = char:FindFirstChild("Head")
                if head then local n=head:FindFirstChild("NameESP"); if n then n:Destroy() end end
                continue
            end

            local espColor = Color3.fromRGB(0,255,0); local espRole = "Innocent"
            local isMurderer = (Modules.FindMurderer()==plr)
            local isSheriff  = (Modules.FindSheriff()==plr)
            if Modules.PlayerData[plr.Name] then
                local d=Modules.PlayerData[plr.Name]
                if d.Role=="Hero" or d.role=="Hero" then
                    espColor=Color3.fromRGB(255,255,0); espRole="Hero"
                end
            end
            if isMurderer then espColor=Color3.fromRGB(255,0,0); espRole="Murderer"
            elseif isSheriff then espColor=Color3.fromRGB(0,0,255); espRole="Sheriff" end

            if Modules.Config.EspPlayers then
                if not char:FindFirstChild("VisionHighlight") then
                    local hl=Instance.new("Highlight"); hl.Name="VisionHighlight"
                    hl.FillTransparency=0.85; hl.OutlineTransparency=0; hl.Parent=char
                end
                local hl=char:FindFirstChild("VisionHighlight")
                if hl then hl.FillColor=espColor; hl.OutlineColor=espColor; hl.Enabled=true end
            else
                local hl=char:FindFirstChild("VisionHighlight"); if hl then hl:Destroy() end
            end

            if Modules.Config.ShowNames then
                local head=char:FindFirstChild("Head")
                if head then
                    if not head:FindFirstChild("NameESP") then
                        CreateBillboard(head).Parent=head
                    end
                    local bg=head:FindFirstChild("NameESP")
                    local lbl=bg and bg:FindFirstChild("TextLabel")
                    local root=Modules.RootPart
                    local er=char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart
                    local dist=(root and er) and math.floor((root.Position-er.Position).Magnitude) or "?"
                    if lbl then
                        lbl.Text=string.format("%s\n[%s] [%s studs]", plr.Name, espRole, tostring(dist))
                        lbl.TextColor3=espColor
                    end
                end
            else
                local head=char:FindFirstChild("Head")
                if head then local esp=head:FindFirstChild("NameESP"); if esp then esp:Destroy() end end
            end
        end
    end
end

local espLoop = nil
local function ToggleESP_System(enable)
    if enable then
        if not espLoop then espLoop=AddConnection(RunService.RenderStepped:Connect(UpdateESPState)) end
    else
        if not Modules.Config.EspPlayers and not Modules.Config.ShowNames then
            if espLoop then espLoop:Disconnect(); espLoop=nil end
            for _, p in ipairs(Players:GetPlayers()) do
                if p.Character then
                    local hl=p.Character:FindFirstChild("VisionHighlight"); if hl then hl:Destroy() end
                    local head=p.Character:FindFirstChild("Head")
                    if head then local n=head:FindFirstChild("NameESP"); if n then n:Destroy() end end
                end
            end
        end
    end
end

local gunESPConn = nil
local function RemoveGunESP()
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj.Name=="GunDrop" then
            local h=obj:FindFirstChild("VisionGunHighlight"); if h then h:Destroy() end
            local b=obj:FindFirstChild("VisionGunLabel"); if b then b:Destroy() end
        end
    end
end
local function AddGunESP(gun)
    if not gun or not gun:IsA("BasePart") then return end
    if gun:FindFirstChild("VisionGunHighlight") then gun.VisionGunHighlight:Destroy() end
    if gun:FindFirstChild("VisionGunLabel") then gun.VisionGunLabel:Destroy() end
    local hl=Instance.new("Highlight"); hl.Name="VisionGunHighlight"; hl.Adornee=gun
    hl.FillColor=Color3.fromRGB(0,255,255); hl.OutlineColor=Color3.fromRGB(255,255,255)
    hl.FillTransparency=0.5; hl.OutlineTransparency=0; hl.Parent=gun
    local bg=Instance.new("BillboardGui"); bg.Name="VisionGunLabel"; bg.Adornee=gun
    bg.Size=UDim2.new(0,150,0,50); bg.StudsOffset=Vector3.new(0,2,0); bg.AlwaysOnTop=true
    local txt=Instance.new("TextLabel"); txt.BackgroundTransparency=1; txt.Size=UDim2.new(1,0,1,0)
    txt.TextSize=14; txt.Font=Enum.Font.GothamBold; txt.Text="DROPPED GUN"
    txt.TextColor3=Color3.fromRGB(0,255,255); txt.TextStrokeTransparency=0
    txt.TextStrokeColor3=Color3.new(0,0,0); txt.Parent=bg; bg.Parent=gun
end
function Modules.ToggleGunESP(enable)
    Modules.Config.EspDroppedGun=enable
    if gunESPConn then gunESPConn:Disconnect(); gunESPConn=nil end
    if enable then
        for _, v in ipairs(workspace:GetDescendants()) do if v.Name=="GunDrop" then AddGunESP(v) end end
        gunESPConn=AddConnection(workspace.DescendantAdded:Connect(function(v)
            if v.Name=="GunDrop" then task.wait(); AddGunESP(v) end
        end))
    else RemoveGunESP() end
end

local VisualsESP = VisualsTab:Section({Title="ESP", Opened=true})
VisualsESP:Toggle({Title="ESP Players", Desc="Highlight players in round", Flag="EspToggle",
    Callback=function(v) Modules.Config.EspPlayers=v; ToggleESP_System(v or Modules.Config.ShowNames) end})
VisualsESP:Toggle({Title="Show Informations", Desc="Show name, role and distance", Flag="ShowNamesToggle",
    Callback=function(v) Modules.Config.ShowNames=v; ToggleESP_System(v or Modules.Config.EspPlayers) end})
VisualsESP:Toggle({Title="ESP Dropped Gun", Desc="Highlight gun when dropped", Flag="EspGunToggle",
    Callback=function(v) Modules.ToggleGunESP(v) end})
VisualsESP:Space()
VisualsESP:Toggle({Title="Round Timer", Desc="Show round timer HUD", Flag="RoundTimerToggle",
    Callback=function(v) Modules.ToggleRoundTimer(v) end})

local VisualsNotify = VisualsTab:Section({Title="Notify", Opened=true})
VisualsNotify:Toggle({Title="Notify Gun Dropped", Desc="Alert when gun is dropped", Flag="NotifyGunToggle",
    Callback=function(v) Modules.ToggleNotifyGunDropped(v) end})
VisualsNotify:Toggle({Title="Notify Murderer", Desc="Alert with picture when Murderer spawns", Flag="NotifyMurdererToggle",
    Callback=function(v) Modules.Config.NotifyMurderer=v; Modules.UpdateRoleNotify() end})
VisualsNotify:Toggle({Title="Notify Sheriff", Desc="Alert with picture when Sheriff spawns", Flag="NotifySheriffToggle",
    Callback=function(v) Modules.Config.NotifySheriff=v; Modules.UpdateRoleNotify() end})

-- Troll Tab
local TrollTab = CombatSection:Tab({Title="Cursed Tricks 💀", Icon="zap"})

-- ── CHAT (first) ───────────────────────────────────────────
local TrollChat = TrollTab:Section({Title="Chat", Opened=true})
TrollChat:Button({Title="Expose Roles in Chat", Desc="Say murderer/sheriff names in chat",
    Icon="message-circle", Callback=Modules.ChatRoles})

do
    local autoExposeId = 0
    local _autoExposeRoundConn = nil
    TrollChat:Toggle({Title="Auto Expose Roles", Desc="Expose roles in chat every round start",
        Flag="AutoExposeToggle", Value=false,
        Callback=function(enabled)
            autoExposeId = autoExposeId + 1
            -- disconnect previous RoundStart hook
            if _autoExposeRoundConn then
                pcall(function() _autoExposeRoundConn:Disconnect() end)
                _autoExposeRoundConn = nil
            end
            if not enabled then return end
            local myId = autoExposeId
            -- expose immediately if already mid-round
            if getMap() ~= nil then
                task.spawn(function()
                    task.wait(1)
                    if autoExposeId == myId then pcall(Modules.ChatRoles) end
                end)
            end
            -- hook the real RoundStart remote — fires reliably every round
            pcall(function()
                _autoExposeRoundConn = AddConnection(
                    ReplicatedStorage.Remotes.Gameplay.RoundStart.OnClientEvent:Connect(function()
                        if autoExposeId ~= myId then return end
                        task.spawn(function()
                            task.wait(4) -- wait for server to assign roles
                            if autoExposeId == myId then pcall(Modules.ChatRoles) end
                        end)
                    end)
                )
            end)
        end})
end

TrollChat:Space()

local TrollFling = TrollTab:Section({Title="Fling", Opened=true})

local selectedFlingPlayer = nil
local flingDropdown = TrollFling:Dropdown({
    Title="Select Player", Desc="Choose a player", Flag="FlingDropdown",
    Callback=function(opt)
        selectedFlingPlayer = Players:FindFirstChild(type(opt)=="table" and opt.Title or opt)
    end,
})
local function refreshFlingList()
    local items={}
    for _, p in ipairs(Players:GetPlayers()) do
        if p~=Modules.Player then
            items[#items+1]={Title=p.Name, Icon="rbxthumb://type=AvatarHeadShot&id="..p.UserId.."&w=150&h=150"}
        end
    end
    pcall(function() flingDropdown:Refresh(items) end)
end
refreshFlingList()
AddConnection(Players.PlayerAdded:Connect(refreshFlingList))
AddConnection(Players.PlayerRemoving:Connect(refreshFlingList))

TrollFling:Button({Title="Fling Player", Desc="Fling selected player", Icon="wind",
    Callback=function()
        if selectedFlingPlayer and selectedFlingPlayer.Character then
            task.spawn(function() SkidFling(selectedFlingPlayer) end)
        end
    end})
TrollFling:Button({Title="Fling All Players", Desc="Fling everyone one by one", Icon="wind",
    Callback=function()
        task.spawn(function() miniFling({"all"}) end)
    end})
TrollFling:Space()
TrollFling:Button({Title="Fling Murderer", Icon="skull",
    Callback=function()
        local m=Modules.FindMurderer()
        if m and m.Character then task.spawn(function() SkidFling(m) end) end
    end})
TrollFling:Button({Title="Fling Sheriff", Icon="shield",
    Callback=function()
        local s=Modules.FindSheriff()
        if s and s.Character then task.spawn(function() SkidFling(s) end) end
    end})
TrollFling:Button({Title="Fling Hero", Icon="star",
    Callback=function()
        local h=Modules.FindHero()
        if h and h.Character then task.spawn(function() SkidFling(h) end) end
    end})

local TrollEmotes = TrollTab:Section({Title="Emotes", Opened=true})
local selectedEmote = nil
TrollEmotes:Dropdown({Title="Select Emote", Desc="Choose emote", Flag="EmoteDropdown",
    Values={"sit","zombie","ninja","zen","floss","dab"},
    Callback=function(v) selectedEmote=v end})
TrollEmotes:Button({Title="Play Emote", Icon="play",
    Callback=function()
        if selectedEmote then Modules.PlayEmote(selectedEmote) end
    end})

-- ── MOVEMENT SECTION ───────────────────────────────────────
local MovSection = Window:Section({Title="Shadow Walk 🌙", Opened=true})

local PlayerTab = MovSection:Tab({Title="Phantom Steps 👣", Icon="footprints"})
local CharSec = PlayerTab:Section({Title="Character", Opened=true})
CharSec:Toggle({Title="Enable WalkSpeed", Desc="Allow custom speed", Flag="EnableWSToggle",
    Callback=Modules.EnableWalkSpeed})
CharSec:Slider({Title="WalkSpeed", Desc="Set your speed", Flag="WSSlider",
    Value={Min=16,Max=200,Default=16}, Callback=Modules.SetWalkSpeed})
CharSec:Space()
CharSec:Toggle({Title="Enable JumpPower", Desc="Allow custom jump", Flag="EnableJPToggle",
    Callback=Modules.EnableJumpPower})
CharSec:Slider({Title="Jump Power", Desc="Set your jump", Flag="JPSlider",
    Value={Min=50,Max=300,Default=50}, Callback=Modules.SetJumpPower})
CharSec:Space()
CharSec:Toggle({Title="Noclip", Desc="Walk through walls", Flag="NoclipToggle",
    Callback=Modules.EnableNoclip})
CharSec:Toggle({Title="Infinite Jump", Desc="Jump infinitely", Flag="InfJumpToggle",
    Callback=Modules.InfiniteJump})
CharSec:Button({Title="Reset Character", Desc="Respawn your character", Icon="refresh-cw",
    Callback=function()
        if Modules.Character then Modules.Character:BreakJoints() end
    end})

local TpTab = MovSection:Tab({Title="Dark Portal 🔮", Icon="map-pin"})

local TpPlayers = TpTab:Section({Title="Players", Opened=true})
local selectedPlayer = nil
local playerDropdown = TpPlayers:Dropdown({
    Title="Select Player", Desc="Choose a player to teleport to",
    Callback=function(opt)
        selectedPlayer = Modules.GetPlayerByName(type(opt)=="table" and opt.Title or opt)
    end,
})
local function refreshPlayerList()
    local items={}
    for _, p in ipairs(Players:GetPlayers()) do
        if p~=Modules.Player then
            items[#items+1]={Title=p.Name, Icon="rbxthumb://type=AvatarHeadShot&id="..p.UserId.."&w=150&h=150"}
        end
    end
    pcall(function() playerDropdown:Refresh(items) end)
end
refreshPlayerList()
AddConnection(Players.PlayerAdded:Connect(refreshPlayerList))
AddConnection(Players.PlayerRemoving:Connect(refreshPlayerList))
TpPlayers:Button({Title="Teleport to Player", Icon="arrow-right",
    Callback=function()
        if selectedPlayer then Modules.TeleportToPlayer(selectedPlayer) end
    end})

local TpRoles = TpTab:Section({Title="Roles", Opened=true})
TpRoles:Button({Title="Teleport to Murderer", Icon="skull",
    Callback=function() local m=Modules.FindMurderer(); if m then Modules.TeleportToPlayer(m) end end})
TpRoles:Button({Title="Teleport to Sheriff", Icon="shield",
    Callback=function() local s=Modules.FindSheriff(); if s then Modules.TeleportToPlayer(s) end end})
TpRoles:Button({Title="Teleport to Hero", Icon="star",
    Callback=function() local h=Modules.FindHero(); if h then Modules.TeleportToPlayer(h) end end})

local TpLocations = TpTab:Section({Title="Locations", Opened=true})
TpLocations:Button({Title="Teleport to Lobby", Icon="house", Callback=Modules.TeleportToLobby})
TpLocations:Button({Title="Teleport to Map", Icon="map", Callback=Modules.TeleportToMap})

-- ── CANDY HARVEST SECTION ──────────────────────────────────
local AutoSection = Window:Section({Title="Candy Harvest 🍬", Opened=true})

local FarmTab = AutoSection:Tab({Title="Candy Farm 🍭", Icon="dollar-sign"})

-- Candy Collection (Coin Farm)
local FarmCoinSub = FarmTab:Section({Title="Candy Collection 🍬", Opened=true})
FarmCoinSub:Toggle({Title="🍭 Smooth Candy Farm", Desc="TweenService smooth movement to each coin (v1)", Flag="CoinFarmToggle",
    Callback=function(v) FarmConfig.CoinEnabled = v; FarmConfig.CoinFarmV2 = false end})
FarmCoinSub:Toggle({Title="⚡ Instant Candy Farm", Desc="firetouchinterest instant collection — fastest (v2)", Flag="CoinFarmV2Toggle",
    Callback=function(v) FarmConfig.CoinFarmV2 = v; if v then FarmConfig.CoinEnabled = false end end})
FarmCoinSub:Toggle({Title="Instant Teleport", Desc="Snap directly to each coin (smooth mode only)", Flag="CoinInstantTPToggle",
    Callback=function(v) FarmConfig.CoinInstantTP = v end})
FarmCoinSub:Slider({Title="Farm Speed", Desc="Studs/sec toward each coin (smooth mode only)", Flag="CoinFarmSpeed",
    Value={Min=1, Max=200, Default=22},
    Callback=function(v) FarmConfig.CoinSpeed = v end})
FarmCoinSub:Space()
FarmCoinSub:Button({Title="🕸️ Collect All Now", Icon="zap", Desc="Instantly teleport to every coin on the map",
    Callback=function()
        task.spawn(function()
            local lc  = LocalPlayer.Character
            local hrp = lc and lc:FindFirstChild("HumanoidRootPart")
            if not hrp then return end
            local all = getCoins()
            for _, c in ipairs(all) do
                if c and c.Parent then
                    pcall(function() hrp.CFrame = CFrame.new(c.Position + Vector3.new(0, 3, 0)) end)
                    task.wait(0.05)
                end
            end
            WindUI:Notify({Title="🎃 Done!", Content="Collected " .. #all .. " candy coins!", Icon="check-circle", Duration=3})
        end)
    end})
FarmCoinSub:Button({Title="Check Candy Count", Icon="search", Desc="See how many coins are on the map",
    Callback=function()
        local count = #getCoins()
        WindUI:Notify({Title=count .. " 🍬 Candies Found",
            Content=count > 0 and "Happy haunting!" or "No candy yet — wait for a round.",
            Icon=count > 0 and "check-circle" or "info", Duration=3})
    end})
FarmCoinSub:Button({Title="👻 Teleport to Safe Spot", Icon="map-pin", Desc="Teleport under the map to safe spot (-106, 87.5, 2)",
    Callback=function() task.spawn(teleportToSafeSpot) end})
FarmCoinSub:Space()
FarmCoinSub:Toggle({Title="Auto-Fling Murderer When Done",
    Desc="Flings murderer when bag is full or no coins remain", Flag="AutoFlingDoneToggle",
    Callback=function(v) FarmConfig.AutoFlingOnDone = v end})
FarmCoinSub:Space()
FarmCoinSub:Button({Title="Check Bag", Icon="package", Desc="See if your candy bag is full",
    Callback=function()
        local full = isBagFull()
        WindUI:Notify({Title=full and "🎃 Bag Full!" or "Bag Not Full",
            Content=full and "Your candy bag is bursting!" or "Still room for more candy.",
            Icon=full and "check-circle" or "info", Duration=3})
    end})
FarmCoinSub:Space()

-- Bag Full Actions
local BagFullSub = FarmTab:Section({Title="When Bag Is Full 🎃", Opened=true})
BagFullSub:Toggle({Title="💀 Kill All at Bag Full", Desc="Kill everyone when bag is full (Murderer only — anchor method)", Flag="KillAtBagToggle",
    Callback=function(v) FarmConfig.KillAtBag = v end})
BagFullSub:Toggle({Title="🌪️ Fling at Bag Full", Desc="Fling the murderer when bag is full", Flag="FlingAtBagToggle",
    Callback=function(v) FarmConfig.FlingAtBag = v end})
BagFullSub:Toggle({Title="👻 Teleport Under Map at Bag Full", Desc="Teleport to safe spot when bag is full", Flag="TpUnderAtBagToggle",
    Callback=function(v) FarmConfig.TeleportUnderAtBag = v end})
BagFullSub:Toggle({Title="☠️ Die at Bag Full", Desc="Kill yourself when bag is full to reset round", Flag="DieAtBagToggle",
    Callback=function(v) FarmConfig.DieAtBag = v end})
BagFullSub:Space()

-- XP Farm
local FarmXPSub = FarmTab:Section({Title="🩸 XP Farm", Opened=true})
FarmXPSub:Toggle({Title="Enable XP Farm",
    Desc="Every 1.5s: teleports behind murderer and fires your tool", Flag="XPFarmToggle",
    Callback=function(v) FarmConfig.XPFarmEnabled = v end})
FarmXPSub:Space()

-- Anti AFK
local FarmAFKSub = FarmTab:Section({Title="🕯️ Anti AFK", Opened=true})
FarmAFKSub:Toggle({Title="Enable Anti AFK", Desc="Prevents kick on idle", Flag="AntiAFKToggle",
    Callback=function(v) FarmConfig.AntiAFKEnabled = v; applyAntiAFK(v) end})
FarmAFKSub:Space()

-- ── Dark Rituals Tab ────────────────────────────────────────
local RitualsTab = AutoSection:Tab({Title="Dark Rituals ⚗️", Icon="flask"})

-- Round Start Actions
local RoundStartSub = RitualsTab:Section({Title="On Round Start 🎃", Opened=true})
RoundStartSub:Toggle({Title="💀 Kill Everyone on Start", Desc="Kill all players at round start (Murderer — anchor method)", Flag="KillOnStartToggle",
    Callback=function(v) FarmConfig.KillOnStart = v end})
RoundStartSub:Toggle({Title="🌪️ Fling Murderer on Start", Desc="Auto-fling the murderer at round start", Flag="FlingMurdOnStartToggle",
    Callback=function(v) FarmConfig.FlingMurdOnStart = v end})
RoundStartSub:Toggle({Title="🌪️ Fling Sheriff on Start", Desc="Auto-fling the sheriff at round start", Flag="FlingSheriOnStartToggle",
    Callback=function(v) FarmConfig.FlingSheriOnStart = v end})
RoundStartSub:Space()

-- Cursed Automation
local CursedAutoSub = RitualsTab:Section({Title="Cursed Automation 🕸️", Opened=true})
CursedAutoSub:Toggle({Title="🏆 Auto Prestige", Desc="Automatically prestige every 30 seconds", Flag="AutoPrestigeToggle",
    Callback=function(v) FarmConfig.AutoPrestige = v end})
CursedAutoSub:Space()
CursedAutoSub:Toggle({Title="📦 Auto Open Crates", Desc="Automatically open crates every second", Flag="AutoCratesToggle",
    Callback=function(v) FarmConfig.AutoOpenCrates = v end})
CursedAutoSub:Dropdown({Title="Crate Name", Desc="Which crate to open", Flag="CrateNameBox",
    Values={"Classic","Vintage","Knife","Gun","Pet","Rainbow"},
    Callback=function(v) FarmConfig.CrateName = v end})
CursedAutoSub:Dropdown({Title="Crate Type", Desc="Crate type", Flag="CrateTypeBox",
    Values={"Normal","Premium","Special"},
    Callback=function(v) FarmConfig.CrateType = v end})
CursedAutoSub:Space()
CursedAutoSub:Toggle({Title="🌐 Auto Server Hop When Empty", Desc="Server hop when player count drops below threshold", Flag="AutoHopEmptyToggle",
    Callback=function(v) FarmConfig.AutoServerHopEmpty = v end})
CursedAutoSub:Slider({Title="Player Threshold", Desc="Hop when players fall to this count", Flag="HopThresholdSlider",
    Value={Min=1, Max=20, Default=2},
    Callback=function(v) FarmConfig.ServerHopThreshold = v end})
CursedAutoSub:Space()

-- Phantom Chaos
local PhantomSub = RitualsTab:Section({Title="Phantom Chaos 💫", Opened=true})
PhantomSub:Toggle({Title="🎭 Emote Spam", Desc="Spam a selected emote continuously", Flag="EmoteSpamToggle",
    Callback=function(v) FarmConfig.EmoteSpam = v end})
PhantomSub:Dropdown({Title="Emote to Spam", Desc="Pick your spooky emote", Flag="EmoteSpamDropdown",
    Values={"sit","zombie","ninja","zen","floss","dab"},
    Callback=function(v) FarmConfig.SelectedEmote = v end})
PhantomSub:Slider({Title="Emote Speed", Desc="Emotes per second", Flag="EmoteSpeedSlider",
    Value={Min=1, Max=20, Default=1},
    Callback=function(v) FarmConfig.EmoteSpamSpeed = v end})
PhantomSub:Space()
PhantomSub:Toggle({Title="🎲 Shuffle Weapons", Desc="Randomly equip a different weapon every 5 seconds", Flag="ShuffleWeaponsToggle",
    Callback=function(v) FarmConfig.ShuffleWeapons = v end})
PhantomSub:Space()
PhantomSub:Button({Title="🗺️ Destroy Map (Keep Coins)", Icon="trash", Desc="Destroy all map parts except the CoinContainer",
    Callback=function() task.spawn(destroyMapExceptCoins) end})
PhantomSub:Button({Title="👤 Destroy Other Players", Icon="user-x", Desc="Remove other players from workspace (visual)",
    Callback=function() task.spawn(destroyOtherPlayers) end})
PhantomSub:Space()

-- Stats
local StatsSub = RitualsTab:Section({Title="📊 Candy Stats", Opened=true})
StatsSub:Button({Title="Check Coins/hr", Icon="bar-chart", Desc="See your current farm rate",
    Callback=function()
        local elapsed = tick() - _farmStartTime
        local perHr = elapsed > 0 and math.floor(_coinsCollected / elapsed * 3600) or 0
        WindUI:Notify({Title="🍬 " .. _coinsCollected .. " candies collected",
            Content="Rate: " .. perHr .. " candies/hr",
            Icon="bar-chart", Duration=5})
    end})

-- ── BUTTONS TAB (Vision Hub exact — standalone) ────────────
local ButtonsTab = Window:Tab({Title="Buttons", Icon="square-mouse-pointer"})
local BtnSub = ButtonsTab:Section({Title="Mobile Buttons", Subtitle="Customize your action buttons",
    Opened=true, TextXAlignment="Center", Icon="square-mouse-pointer"})

BtnSub:Toggle({Title="Lock Buttons", Desc="Lock mobile button positions", Flag="LockButtonsToggle",
    Callback=function(v) Modules.Config.ButtonsLocked=v end})
BtnSub:Space()
BtnSub:Toggle({Title="TP & Shoot Button", Desc="Teleports to murderer then shoots (Sheriff)", Flag="ShowShootBtn",
    Callback=function(v)
        Modules.CreateGuiButton("TpShoot",{Enabled=v,Type="Text",Text="TP+Shoot",TextColor=Color3.new(0.3,0.8,1)},
            function() task.spawn(Modules.ShootMurdererOnce) end)
    end})
BtnSub:Toggle({Title="Silent Aim Button", Desc="Toggle button that hooks gun to auto-aim at murderer", Flag="ShowSilentShootBtn",
    Callback=function(v)
        Modules.CreateGuiButton("SilentAim",{Enabled=v,Type="Text",Text="Silent Aim",TextColor=Color3.new(1,0.8,0.2)},
            function() task.spawn(Modules.ShootMurdererSilent) end)
    end})
BtnSub:Space()
BtnSub:Toggle({Title="Fling Murderer Button", Desc="Fling the murderer", Flag="FlingMurdBtn",
    Callback=function(v)
        Modules.CreateGuiButton("FlingMurderer",{Enabled=v,Type="Text",Text="Fling Murderer",TextColor=Color3.new(1,1,1)},
            function() local m=Modules.FindMurderer(); if m and m.Character then SkidFling(m) end end)
    end})
BtnSub:Toggle({Title="Fling Sheriff Button", Desc="Fling the sheriff", Flag="FlingSerBtn",
    Callback=function(v)
        Modules.CreateGuiButton("FlingSheriff",{Enabled=v,Type="Text",Text="Fling Sheriff",TextColor=Color3.new(1,1,1)},
            function() local s=Modules.FindSheriff(); if s and s.Character then SkidFling(s) end end)
    end})
BtnSub:Toggle({Title="Fling Hero Button", Desc="Fling the Hero player", Flag="FlingHeroBtn",
    Callback=function(v)
        Modules.CreateGuiButton("FlingHero",{Enabled=v,Type="Text",Text="Fling Hero",TextColor=Color3.new(1,1,1)},
            function() local h=Modules.FindHero(); if h and h.Character then SkidFling(h) end end)
    end})
BtnSub:Space()
BtnSub:Toggle({Title="Show Kill Button", Desc="Adds Kill All button (Murderer only)", Flag="KillBtn",
    Callback=function(v)
        Modules.CreateGuiButton("Kill",{Enabled=v,Type="Text",Text="Kill All",TextColor=Color3.new(1,1,1)},
            function()
                local char = LocalPlayer.Character
                local bp   = LocalPlayer.Backpack
                local hasKnife = char and (char:FindFirstChild("Knife") or (bp and bp:FindFirstChild("Knife")))
                if not hasKnife then
                    WindUI:Notify({Title="Kill All", Content="You need a knife (be Murderer)!", Icon="x-circle", Duration=3})
                    return
                end
                Modules.KillAll()
            end)
    end})
BtnSub:Toggle({Title="Show Throw Knife Button", Desc="Throw knife at nearest", Flag="ThrowBtn",
    Callback=function(v)
        Modules.CreateGuiButton("ThrowKnife",{Enabled=v,Type="Text",Text="Throw Knife"},
            Modules.ExecuteThrowAtNearest)
    end})
BtnSub:Space()
BtnSub:Toggle({Title="Show Grab Gun Button", Desc="Grab or pick up a gun", Flag="GrabGunBtn",
    Callback=function(v)
        Modules.CreateGuiButton("GrabGun",{Enabled=v,Type="Text",Text="Grab Gun"},Modules.GrabGun)
    end})
BtnSub:Space()
BtnSub:Toggle({Title="Show Teleport Map Button", Desc="Teleport to current map", Flag="TpMapBtn",
    Callback=function(v)
        Modules.CreateGuiButton("Teleport",{Enabled=v,Type="Text",Text="Teleport to Map"},Modules.TeleportToMap)
    end})
BtnSub:Toggle({Title="Show Teleport Lobby Button", Desc="Teleport back to lobby", Flag="TpLobbyBtn",
    Callback=function(v)
        Modules.CreateGuiButton("TeleportLobby",{Enabled=v,Type="Text",Text="Teleport to Lobby"},Modules.TeleportToLobby)
    end})

-- ── SETTINGS TAB (standalone — Vision Hub Config/Theme + our border) ──
local SettTab = Window:Tab({Title="Settings", Icon="settings"})

local SettConfig = SettTab:Section({Title="Config", Opened=true})
SettConfig:Button({Title="Save Config", Desc="Saves your current settings", Icon="save",
    Callback=function()
        Window.CurrentConfig:Save()
        WindUI:Notify({Title="Success", Content="Configuration saved!", Icon="save", Duration=5})
    end})
SettConfig:Button({Title="Load Config", Desc="Loads previously saved settings", Icon="folder-open",
    Callback=function()
        Window.CurrentConfig:Load()
        WindUI:Notify({Title="Success", Content="Configuration loaded!", Icon="loader", Duration=5})
    end})

local SettTheme = SettTab:Section({Title="Theme", Opened=true})
SettTheme:Keybind({Title="Toggle Keybind", Desc="Open/close the UI", Value="G",
    Callback=function(v)
        pcall(function() Window:SetToggleKey(Enum.KeyCode[v]) end)
    end})
SettTheme:Toggle({Title="Transparency", Desc="Semi-transparent interface",
    Flag="UiTransparencyToggle", Value=false,
    Callback=function(v) pcall(function() Window:ToggleTransparency(v) end) end})

SettTab:Space()

local SettKeybinds = SettTab:Section({Title="Keybinds", Opened=true})
local Keybinds = {
    GrabGun    = "None",
    KillAll    = "K",
    ThrowKnife = "Q",
    ShootMurd  = "E",
    TpShoot    = "None",
    FlingMurd  = "None",
}
SettKeybinds:Keybind({Title="Grab Gun",        Desc="Pick up gun from map",         Value=Keybinds.GrabGun,    Callback=function(v) Keybinds.GrabGun=v    end})
SettKeybinds:Keybind({Title="Kill All",         Desc="Kill all players",              Value=Keybinds.KillAll,    Callback=function(v) Keybinds.KillAll=v    end})
SettKeybinds:Keybind({Title="Throw Knife",      Desc="Throw knife at nearest player", Value=Keybinds.ThrowKnife, Callback=function(v) Keybinds.ThrowKnife=v end})
SettKeybinds:Keybind({Title="Silent Shoot",     Desc="Shoot murderer from position",  Value=Keybinds.ShootMurd,  Callback=function(v) Keybinds.ShootMurd=v  end})
SettKeybinds:Keybind({Title="TP & Shoot",       Desc="Teleport + shoot murderer",     Value=Keybinds.TpShoot,    Callback=function(v) Keybinds.TpShoot=v    end})
SettKeybinds:Keybind({Title="Fling Murderer",   Desc="Fling the murderer",            Value=Keybinds.FlingMurd,  Callback=function(v) Keybinds.FlingMurd=v  end})

SettTab:Space()

-- ── KEYBIND HANDLERS ───────────────────────────────────────
AddConnection(UserInputService.InputBegan:Connect(function(inp, gpe)
    if gpe then return end
    local keyName = tostring(inp.KeyCode):match("Enum.KeyCode.(.+)")
    if not keyName then return end

    if keyName == Keybinds.KillAll and Keybinds.KillAll ~= "None" then
        local char = Modules.Character; local hum = Modules.Humanoid
        if char and hum and hum.Health > 0 then
            local knife = char:FindFirstChild("Knife") or (Modules.Backpack and Modules.Backpack:FindFirstChild("Knife"))
            if knife then pcall(Modules.KillAll) end
        end
    elseif keyName == Keybinds.ThrowKnife and Keybinds.ThrowKnife ~= "None" then
        pcall(Modules.ExecuteThrowAtNearest)
    elseif keyName == Keybinds.ShootMurd and Keybinds.ShootMurd ~= "None" then
        pcall(function() Modules.ShootMurdererOnce() end)
    elseif keyName == Keybinds.TpShoot and Keybinds.TpShoot ~= "None" then
        pcall(function() Modules.ShootMurdererOnce() end)
    elseif keyName == Keybinds.FlingMurd and Keybinds.FlingMurd ~= "None" then
        local m = Modules.FindMurderer()
        if m and m.Character then task.spawn(function() SkidFling(m) end) end
    elseif keyName == Keybinds.GrabGun and Keybinds.GrabGun ~= "None" then
        pcall(Modules.GrabGun)
    end
end))

SettTab:Space()

local BorderSub = SettTab:Section({Title="🎃 Border", Opened=true})
BorderSub:Colorpicker({Title="Border Color", Value=Color3.fromRGB(255,115,0),
    Callback=function(v)
        borderColor=v
        if _borderStroke then _borderStroke.Color=v end
        if getgenv().mm2PillStroke then getgenv().mm2PillStroke.Color=v end
    end})
BorderSub:Slider({Title="Border Thickness", Value={Min=1,Max=12,Default=5}, Step=1,
    Callback=function(v)
        borderThickness=v
        if _borderStroke then _borderStroke.Thickness=v end
        if getgenv().mm2PillStroke then getgenv().mm2PillStroke.Thickness=v end
    end})

local ServerSub = SettTab:Section({Title="Server", Desc="Server related actions", Icon="server",
    Opened=true, TextXAlignment="Center"})
ServerSub:Button({Title="Rejoin Server", Desc="Rejoins the current server", Icon="refresh-cw",
    Callback=function()
        Window:Dialog({
            Title="Confirm Rejoin", Content="Are you sure you want to rejoin the server?",
            Buttons={
                {Title="Cancel", Variant="Secondary"},
                {Title="Rejoin", Icon="check", Callback=Modules.Rejoin},
            }
        })
    end})
ServerSub:Button({Title="Server Hop", Desc="Joins a different server", Icon="shuffle",
    Callback=function()
        Window:Dialog({
            Title="Confirm Server Hop", Content="Are you sure you want to server hop?",
            Buttons={
                {Title="Cancel", Variant="Secondary"},
                {Title="Server Hop", Icon="check", Callback=Modules.ServerHop},
            }
        })
    end})
ServerSub:Space()
ServerSub:Toggle({Title="Queue on Teleport", Desc="Executes script automatically on queue",
    Flag="AutoQueueToggle", Value=true,
    Callback=function(v) Modules.Config.AutoQueue=v end})

-- ============================================================
-- SELECT FIRST TAB (Vision Hub pattern)
-- ============================================================
Window:SelectTab(1)

-- ============================================================
-- TOGGLE KEY
-- ============================================================
Window:SetToggleKey(Enum.KeyCode.RightShift)

-- ============================================================
-- HOTKEYS (configurable via Settings > Keybinds)
-- ============================================================
local function keyMatches(inp, bindName)
    local v = Keybinds[bindName]
    if not v or v == "None" or v == "" then return false end
    local ok, kc = pcall(function() return Enum.KeyCode[v] end)
    return ok and kc and inp.KeyCode == kc
end

AddConnection(UserInputService.InputBegan:Connect(function(inp, gameProcessed)
    if gameProcessed then return end
    if     keyMatches(inp, "GrabGun")    then task.spawn(Modules.GrabGun)
    elseif keyMatches(inp, "KillAll")    then task.spawn(Modules.KillAll)
    elseif keyMatches(inp, "ThrowKnife") then task.spawn(Modules.ExecuteThrowAtNearest)
    elseif keyMatches(inp, "ShootMurd")  then task.spawn(Modules.ShootMurdererSilent)
    elseif keyMatches(inp, "TpShoot")   then task.spawn(Modules.ShootMurdererOnce)
    elseif keyMatches(inp, "FlingMurd")  then task.spawn(function() pcall(Modules.FlingMurderer) end)
    end
end))

-- ============================================================
-- AVATAR ICON INJECTION
-- WindUI path: PlayerGui > WindUI ScreenGui > ... > UserIcon > ImageLabel
-- ============================================================
task.spawn(function()
    task.wait(1.5)
    local thumbUrl = ""
    pcall(function()
        thumbUrl = Players:GetUserThumbnailAsync(
            LocalPlayer.UserId,
            Enum.ThumbnailType.AvatarHeadShot,
            Enum.ThumbnailSize.Size150x150)
    end)
    if thumbUrl == "" then return end

    -- Primary: find UserIcon.ImageLabel in the WindUI ScreenGui
    pcall(function()
        local windGui = LocalPlayer.PlayerGui:FindFirstChild("WindUI")
        if not windGui then return end
        for _, obj in ipairs(windGui:GetDescendants()) do
            if obj:IsA("ImageLabel") and obj.Parent and obj.Parent.Name == "UserIcon" then
                obj.Image = thumbUrl
                obj.ScaleType = Enum.ScaleType.Crop
            end
        end
    end)
end)

-- ============================================================
-- BORDER (solid red by default, driven by colorpicker)
-- ============================================================
task.spawn(function()
    task.wait(0.5)
    pcall(function()
        local mainFrame = Window.UIElements and Window.UIElements.Main
        if not mainFrame then return end
        _borderStroke = Instance.new("UIStroke")
        _borderStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        _borderStroke.Thickness = borderThickness
        _borderStroke.Color     = borderColor
        _borderStroke.Parent    = mainFrame
        -- suppress WindUI's gradient border for 3s
        local deadline = tick() + 3
        while tick() < deadline do
            pcall(function()
                for _, obj in ipairs(mainFrame:GetDescendants()) do
                    if obj:IsA("UIStroke") and obj ~= _borderStroke then obj.Transparency=1 end
                    if obj.Name == "GradientBorder" then obj:Destroy() end
                end
            end)
            task.wait(0.05)
        end
        mainFrame.DescendantAdded:Connect(function(obj)
            task.defer(function()
                if obj:IsA("UIStroke") and obj~=_borderStroke then pcall(function() obj.Transparency=1 end) end
                if obj.Name=="GradientBorder" then pcall(function() obj:Destroy() end) end
            end)
        end)
    end)
end)

-- ============================================================
-- TOPBAR AVATAR — bigger + red circle ring
-- ============================================================
task.spawn(function()
    task.wait(1.0)
    pcall(function()
        local rg = CoreGui:FindFirstChild("RobloxGui")
        local windUI = rg and rg:FindFirstChild("WindUI")
        if not windUI then return end

        local avatarImg = nil
        for _, obj in ipairs(windUI:GetDescendants()) do
            if obj:IsA("ImageLabel") and obj.Image and obj.Image:find("rbxthumb")
                and obj:GetFullName():find("Topbar") then
                avatarImg = obj; break
            end
        end
        if not avatarImg then return end

        local S = 32  -- avatar image size

        -- expand parents to avoid clipping
        for _, p in ipairs({avatarImg.Parent, avatarImg.Parent and avatarImg.Parent.Parent}) do
            if p and p:IsA("GuiObject") then
                p.ClipsDescendants = false
                p.Size = UDim2.new(0, S + 8, 1, 0)
            end
        end

        -- avatar
        avatarImg.Size      = UDim2.new(0, S, 0, S)
        avatarImg.Position  = UDim2.new(0.5, -S/2, 0.5, -S/2)
        avatarImg.ScaleType = Enum.ScaleType.Crop
        local corner = avatarImg:FindFirstChildOfClass("UICorner") or Instance.new("UICorner", avatarImg)
        corner.CornerRadius = UDim.new(1, 0)

        -- outline ring via UIStroke (same color as border)
        local stroke = avatarImg:FindFirstChildOfClass("UIStroke") or Instance.new("UIStroke", avatarImg)
        stroke.Color           = borderColor
        stroke.Thickness       = 2
        stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

        -- keep stroke color in sync with border colorpicker
        task.spawn(function()
            while avatarImg and avatarImg.Parent do
                stroke.Color = borderColor
                task.wait(0.5)
            end
        end)
    end)
end)

-- ============================================================
-- OPEN PILL BUTTON (disabled — WindUI toggle handles this)
-- ============================================================
task.spawn(function()
    task.wait(1.2)
    if false then pcall(function()
        -- bigger pill on mobile for touch targets
        local PILL_H = isMobile and 70 or 56
        local AVA_W  = isMobile and 70 or 56
        local LBL_W  = isMobile and 80 or 64

        local pillGui=Instance.new("ScreenGui")
        pillGui.Name="MM2HubOpenBtn"; pillGui.ResetOnSpawn=false; pillGui.DisplayOrder=100
        pcall(function() pillGui.Parent=CoreGui end)
        if not pillGui.Parent then pillGui.Parent=LocalPlayer.PlayerGui end

        -- start visible on mobile so user can always find it
        local startY = isMobile and 0.85 or 0.5
        local pill=Instance.new("Frame",pillGui); pill.Name="Pill"
        pill.Size=UDim2.new(0,AVA_W+LBL_W,0,PILL_H)
        pill.Position=UDim2.new(0,12,startY,-PILL_H/2)
        pill.BackgroundColor3=Color3.fromRGB(12,12,20); pill.BorderSizePixel=0; pill.Visible=false
        getgenv()._mm2Pill = pill
        Instance.new("UICorner",pill).CornerRadius=UDim.new(0,PILL_H/2)
        -- gradient fill
        local grad=Instance.new("UIGradient",pill)
        grad.Color=ColorSequence.new{
            ColorSequenceKeypoint.new(0, Color3.fromRGB(30,10,40)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(10,10,25)),
        }
        grad.Rotation=90
        -- colored border
        local pillStroke=Instance.new("UIStroke",pill)
        pillStroke.Color=borderColor; pillStroke.Thickness=2
        pillStroke.ApplyStrokeMode=Enum.ApplyStrokeMode.Border
        getgenv().mm2PillStroke=pillStroke

        -- avatar circle
        local avaF=Instance.new("Frame",pill)
        avaF.Size=UDim2.new(0,PILL_H,0,PILL_H); avaF.BackgroundTransparency=1
        avaF.BorderSizePixel=0
        local avaImg=Instance.new("ImageLabel",avaF)
        local avaSize=PILL_H-12
        avaImg.Size=UDim2.new(0,avaSize,0,avaSize)
        avaImg.Position=UDim2.new(0.5,-avaSize/2,0.5,-avaSize/2)
        avaImg.BackgroundTransparency=1; avaImg.ScaleType=Enum.ScaleType.Crop
        Instance.new("UICorner",avaImg).CornerRadius=UDim.new(1,0)
        avaImg.Image = _avatarIcon
        -- avatar ring
        local avaStroke=Instance.new("UIStroke",avaImg)
        avaStroke.Color=borderColor; avaStroke.Thickness=2
        avaStroke.ApplyStrokeMode=Enum.ApplyStrokeMode.Border

        -- text area
        local txtFrame=Instance.new("Frame",pill)
        txtFrame.Size=UDim2.new(0,LBL_W,0,PILL_H)
        txtFrame.Position=UDim2.new(0,PILL_H,0,0)
        txtFrame.BackgroundTransparency=1; txtFrame.BorderSizePixel=0

        local openLbl=Instance.new("TextLabel",txtFrame)
        openLbl.Size=UDim2.new(1,0,0.55,0); openLbl.Position=UDim2.new(0,0,0,0)
        openLbl.BackgroundTransparency=1; openLbl.Text="OPEN"
        openLbl.TextColor3=Color3.new(1,1,1)
        openLbl.TextSize= isMobile and 16 or 13
        openLbl.Font=Enum.Font.GothamBold
        openLbl.TextXAlignment=Enum.TextXAlignment.Left

        local subLbl=Instance.new("TextLabel",txtFrame)
        subLbl.Size=UDim2.new(1,0,0.45,0); subLbl.Position=UDim2.new(0,0,0.55,0)
        subLbl.BackgroundTransparency=1; subLbl.Text="Zovlane Hub"
        subLbl.TextColor3=Color3.fromRGB(180,140,255)
        subLbl.TextSize= isMobile and 11 or 9
        subLbl.Font=Enum.Font.Gotham
        subLbl.TextXAlignment=Enum.TextXAlignment.Left

        local dragging=false; local dragStart; local pillStart; local moved=false
        pill.InputBegan:Connect(function(inp)
            if inp.UserInputType==Enum.UserInputType.MouseButton1 or inp.UserInputType==Enum.UserInputType.Touch then
                dragging=true; moved=false; dragStart=inp.Position; pillStart=pill.Position
            end
        end)
        UserInputService.InputChanged:Connect(function(inp)
            if not dragging then return end
            if inp.UserInputType==Enum.UserInputType.MouseMovement or inp.UserInputType==Enum.UserInputType.Touch then
                local delta=inp.Position-dragStart
                if delta.Magnitude>6 then moved=true end
                pill.Position=UDim2.new(pillStart.X.Scale,pillStart.X.Offset+delta.X,
                    pillStart.Y.Scale,pillStart.Y.Offset+delta.Y)
            end
        end)
        UserInputService.InputEnded:Connect(function(inp)
            if not dragging then return end
            if inp.UserInputType==Enum.UserInputType.MouseButton1 or inp.UserInputType==Enum.UserInputType.Touch then
                dragging=false
                if not moved then
                    pill.Visible = false
                    getgenv()._mm2GuiOpen = true
                    -- open the GUI: find the main frame and show it
                    local toggled = false
                    pcall(function() Window:Open(); toggled=true end)
                    if not toggled then pcall(function() Window:Toggle(); toggled=true end) end
                    if not toggled then
                        pcall(function()
                            local rg = CoreGui:FindFirstChild("RobloxGui")
                            local wu = rg and rg:FindFirstChild("WindUI")
                            local wFolder = wu and wu:FindFirstChild("Window")
                            if wFolder then
                                for _, c in ipairs(wFolder:GetChildren()) do
                                    if c:IsA("Frame") and c:FindFirstChild("Main") then
                                        c.Visible = true; break
                                    end
                                end
                            end
                        end)
                    end
                end
            end
        end)

        AddConnection(RunService.Heartbeat:Connect(function()
            pillStroke.Color     = borderColor
            pillStroke.Thickness = borderThickness
            if avaStroke then avaStroke.Color = borderColor end
        end))

        -- start hidden since window is open on load
        task.delay(0.5, function() pill.Visible = false end)
    end) end  -- pill disabled
end)

-- clean up any leftover crosshair from previous run
if getgenv()._crosshairClean then pcall(getgenv()._crosshairClean) end
getgenv()._crosshairClean = nil

task.spawn(function()
    task.wait(2)
    WindUI:Notify({
        Title   = "Zovlane Hub v4.0",
        Content = "Press G to open / close the GUI!",
        Icon    = "info",
        Duration= 7,
    })
end)

return Modules