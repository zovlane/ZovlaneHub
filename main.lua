-- ============================================================
-- ZOVLANE HUB v5.0 - Halloween Edition
-- Repo:     https://github.com/zovlane/ZovlaneHub
-- WindUI:   https://github.com/zovlane/WindUI (our fork — loads dist/main.lua)
-- Load:     loadstring(game:HttpGet("https://raw.githubusercontent.com/zovlane/ZovlaneHub/main/main.lua"))()
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
    or gui.Name == "MM2HubCrosshair" or gui.Name == "GhostStatsOverlay" then
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

local _borderStroke   = nil
local borderColor     = Color3.fromRGB(255, 115, 0)
local borderThickness = 3
local _borderGradient = nil
local function applyBorderColor()
    if not _borderGradient then return end
    _borderGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, borderColor),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(183, 107, 255)),
        ColorSequenceKeypoint.new(1, borderColor),
    })
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
    QueueUrl           = 'loadstring(game:HttpGet("https://raw.githubusercontent.com/zovlane/ZovlaneHub/main/main.lua",true))()',
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
            WindUI:Notify({ Title="Gun Dropped!", Content="A gun appeared on the map!", Icon="circle-alert", Duration=4 })
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
        Icon    = _silentAimEnabled and "crosshair" or "circle-x",
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
                            WindUI:Notify({Title="Murderer Detected!", Content=p.Name,
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
                            WindUI:Notify({Title="Sheriff Detected!", Content=p.Name,
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

    local msg = " Murderer: "..murdName.." |  Sheriff: "..sherName
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
-- avatar as topbar icon
local _avatarIcon = "rbxthumb://type=AvatarHeadShot&id="..LocalPlayer.UserId.."&w=150&h=150"

-- ── Halloween theme (gradient values become UIGradients inside WindUI) ──
do
    local ORANGE = Color3.fromHex("#ff7a00")
    local AMBER  = Color3.fromHex("#ffb347")
    local VIOLET = Color3.fromHex("#b76bff")
    local function grad(a, b, c, rotation)
        local stops = {["0"] = {Color = a}, ["100"] = {Color = c or b}}
        if c then stops["50"] = {Color = b} end
        return WindUI:Gradient(stops, {Rotation = rotation or 0})
    end
    WindUI:AddTheme({
        Name = "Halloween",
        Accent      = Color3.fromHex("#1a0e20"),
        Dialog      = Color3.fromHex("#170c1c"),
        Outline     = ORANGE,
        Text        = Color3.fromHex("#fff4e8"),
        Placeholder = Color3.fromHex("#a08cab"),
        Background  = Color3.fromHex("#0e0811"),
        Button      = Color3.fromHex("#4a2a5a"),
        Icon        = Color3.fromHex("#ffa040"),
        Toggle      = ORANGE,
        Slider      = ORANGE,
        Checkbox    = ORANGE,
        Primary     = ORANGE,
        SliderIcon  = Color3.fromHex("#b494c4"),

        PanelBackground = Color3.fromHex("#ffffff"),
        PanelBackgroundTransparency = 0.965,
        LabelBackground = Color3.fromHex("#000000"),
        LabelBackgroundTransparency = 0.8,
        ElementBackground = Color3.fromHex("#211428"),
        ElementBackgroundTransparency = 0,

        WindowBackground   = grad(Color3.fromHex("#22102c"), Color3.fromHex("#0c0710"), nil, 90),
        WindowTopbarTitle  = grad(ORANGE, AMBER, VIOLET),
        WindowTopbarAuthor = Color3.fromHex("#c6a4d6"),
        WindowTopbarIcon   = ORANGE,
        WindowSearchBarBackground = Color3.fromHex("#1a0f20"),
        SearchBarBorder = ORANGE,
        SearchBarBorderTransparency = 0.7,

        TabText  = grad(AMBER, VIOLET),
        TabTitle = grad(ORANGE, AMBER, VIOLET),
        TabIcon  = ORANGE,
        TabBackgroundActive = ORANGE,
        TabBackgroundActiveTransparency = 0.86,
        TabBorder = ORANGE,
        TabBorderTransparencyActive = 0.5,

        ElementTitle = grad(Color3.fromHex("#ffffff"), Color3.fromHex("#ffc58a")),
        ElementDesc  = Color3.fromHex("#bfa9c9"),
        ElementIcon  = Color3.fromHex("#ff9a3c"),
        SectionIcon       = Color3.fromHex("#ff9a3c"),
        SectionExpandIcon = Color3.fromHex("#ff9a3c"),
        SectionBoxBorder  = ORANGE,
        SectionBoxBorderTransparency = 0.8,

        NotificationTitle = grad(ORANGE, AMBER, VIOLET),
        NotificationBorder = ORANGE,
        NotificationBorderTransparency = 0.6,
        DropdownBackground = Color3.fromHex("#140b19"),
        Tooltip = Color3.fromHex("#2a1633"),
    })
end

local function fittedWindowSize()
    local cam = workspace.CurrentCamera
    local vp = cam and cam.ViewportSize or Vector2.new(1280, 720)
    local w = math.clamp(math.floor(vp.X * 0.9), 300, 580)
    local h = math.clamp(math.floor(vp.Y * 0.8), 240, 460)
    return UDim2.fromOffset(w, h)
end

local Window = WindUI:CreateWindow({
    Title   = "Zovlane Hub",
    Author  = "Halloween Edition · v5.0",
    Folder  = "ZovlaneHub",
    Icon    = _avatarIcon,
    Size    = fittedWindowSize(),
    MinSize = Vector2.new(300, 240),
    Transparent   = false,
    Theme         = "Halloween",
    NewElements   = true,
    SideBarWidth  = isMobile and 130 or 180,
    HideSearchBar = false,
    User    = { Enabled=false, Anonymous=false },
    Topbar  = { Height=46, ButtonsType="Mac" },
    OpenButton = {
        Title           = "Zovlane Hub",
        Icon            = "ghost",
        Enabled         = true,
        OnlyMobile      = true,
        Draggable       = true,
        CornerRadius    = UDim.new(1, 0),
        StrokeThickness = 2,
        Color           = ColorSequence.new(Color3.fromRGB(255, 115, 0), Color3.fromRGB(150, 60, 255)),
    },
})

Window.ConfigManager:CreateConfig("Default")
pcall(function()
    Window:Tag({Title = "v5.0", Icon = "ghost", Radius = 8,
        Color = WindUI:Gradient({["0"] = {Color = Color3.fromHex("#ff7a00")}, ["100"] = {Color = Color3.fromHex("#b76bff")}}, {Rotation = 0})})
end)

-- ============================================================
-- AUTOFARM (ported from Project Reverse MM2 AutoFarm)
-- ============================================================
local Workspace     = workspace
local Lighting      = game:GetService("Lighting")
local GameRemotes   = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Gameplay")
local CoinCollected = GameRemotes:WaitForChild("CoinCollected")
local RoundStartRE  = GameRemotes:WaitForChild("RoundStart")

local AF = {
    AutoRevealRoles = false,
    StatsOverlay    = false,
    TrapESP         = false,
    AutoPickUpGun   = false,
    AutoShooting    = false,
    LoopFlingAll    = false,
    ShuffleWeapons  = false,
    XPFarm          = false,
    CoinFarm  = { State=false, Speed=22.5, DestroyMap=false, DestroyPlayers=false, DieAtFullBag=false },
    CoinFarm2 = { State=false },
    AutoFarm  = {
        TeleportSpawn=false, KillEveryone=false, AutoFlingMurderer=false, AutoFlingSheriff=false,
        AutoPrestige=false, KillAtFullBag=false, TeleportUnderMap=false, FlingMurdererAtFullBag=false,
        AutoServerHop=false, PlayersToServerHop=2,
    },
    AutoOpenCrates = { State=false, Crate="MysteryBox1", CrateType="MysteryBox" },
    Emotes = { Selected="zen", SpamRandom=false, SpamSelected=false, Speed=1 },
}

local function notify(title, content, icon, duration)
    pcall(function()
        WindUI:Notify({Title=title, Content=content, Icon=icon or "info", Duration=duration or 4})
    end)
end
local function getHum()
    local c = LocalPlayer.Character
    return c and c:FindFirstChildOfClass("Humanoid")
end
local function getHRP()
    local c = LocalPlayer.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end
local function noclipSelf()
    local c = LocalPlayer.Character
    if not c then return end
    for _, d in ipairs(c:GetDescendants()) do
        if d:IsA("BasePart") and d.CanCollide then d.CanCollide = false end
    end
end
local function getRoundMap()
    for _, c in ipairs(Workspace:GetChildren()) do
        if c:FindFirstChild("CoinContainer") and c:FindFirstChild("Spawns") then return c end
    end
end
local function getCoinMap()
    for _, c in ipairs(Workspace:GetChildren()) do
        if c:FindFirstChild("CoinContainer") then return c end
    end
end
-- returns (coin bag UI visible, bag full)
local function bagState()
    local mg = LocalPlayer.PlayerGui:FindFirstChild("MainGUI")
    local g = mg and mg:FindFirstChild("Game")
    local bags = g and g:FindFirstChild("CoinBags")
    if not bags then return false, false end
    local full = false
    local cont = bags:FindFirstChild("Container")
    if cont then
        for _, b in ipairs(cont:GetChildren()) do
            local f = b:FindFirstChild("Full")
            if f and f:IsA("GuiObject") and f.Visible then full = true; break end
        end
    end
    return bags.Visible, full
end
local function set3DRendering(on)
    pcall(function() RunService:Set3dRenderingEnabled(on) end)
end

-- ── Stats overlay ──
local statTotal, statBag, statMax, statStart = 0, 0, 40, tick()
local statGui = Instance.new("ScreenGui")
statGui.Name = "GhostStatsOverlay"; statGui.ResetOnSpawn = false; statGui.IgnoreGuiInset = true
pcall(function() statGui.Parent = CoreGui end)
if not statGui.Parent then statGui.Parent = LocalPlayer.PlayerGui end
local statLabel = Instance.new("TextLabel")
statLabel.Visible = false
statLabel.Size = UDim2.new(0.5, 0, 0.1, 0)
statLabel.Position = UDim2.new(0.5, 0, 0.5, 0)
statLabel.AnchorPoint = Vector2.new(0.5, 0.5)
statLabel.BackgroundTransparency = 1
statLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
statLabel.TextStrokeColor3 = Color3.fromRGB(255, 115, 0)
statLabel.TextStrokeTransparency = 0.35
statLabel.Font = Enum.Font.SourceSansBold
statLabel.TextSize = 42
statLabel.Parent = statGui
AddConnection(CoinCollected.OnClientEvent:Connect(function(_, cur, max)
    statTotal += 1
    statBag = tonumber(cur) or statBag
    statMax = tonumber(max) or statMax
end))
AddConnection(RunService.RenderStepped:Connect(function()
    statLabel.Visible = AF.StatsOverlay
    if not AF.StatsOverlay then return end
    local perHour = math.floor(statTotal * 3600 / math.max(tick() - statStart, 1))
    statLabel.Text = string.format("Coins Collected: %d/%d\nTotal Coins: %d\nCoins Per Hour: %d", statBag, statMax, statTotal, perHour)
end))

-- ── Teleport under map (safe spot) ──
local function teleportUnderMap()
    local hrp = getHRP()
    if not hrp then return end
    if Workspace:FindFirstChild("safespot") then
        hrp.CFrame = CFrame.new(-106, 87.5, 2)
        return
    end
    local p = Instance.new("Part")
    p.Name = "safespot"; p.Size = Vector3.new(25, 3, 25); p.Position = Vector3.new(-106, 83, 2)
    p.Anchored = true; p.CanCollide = true; p.Transparency = 0; p.Parent = Workspace
    task.wait()
    for _ = 1, 3 do
        local h = getHRP()
        if not h then return end
        h.CFrame = CFrame.new(-106, 87.5, 2)
        task.wait(0.1)
    end
end

-- ── Emotes ──
local EMOTES = {"sit","ninja","dab","zen","floss","headless","zombie","wave","cheer","laugh"}
local function playEmote(name)
    pcall(function() ReplicatedStorage.Remotes.Misc.PlayEmote:Fire(name) end)
end
Modules.PlayEmote = playEmote
task.spawn(function()
    while true do
        task.wait(1 / math.max(AF.Emotes.Speed, 1))
        if AF.Emotes.SpamRandom then playEmote(EMOTES[math.random(1, #EMOTES)]) end
    end
end)

local freeEmotesRunning = false
local function unlockAllEmotes()
    local mg = LocalPlayer.PlayerGui:FindFirstChild("MainGUI")
    local g = mg and mg:FindFirstChild("Game")
    local emotesUI = g and g:FindFirstChild("Emotes")
    local hum = getHum()
    if not emotesUI or not getHRP() or not hum or hum.Health <= 0 then
        notify("Not ready", "Wait for the game to finish loading.", "alert-triangle", 3)
        return
    end
    pcall(function() ReplicatedStorage.Remotes.Extras.GetPlayerData:InvokeServer("GetData") end)
    local mod = ReplicatedStorage.Modules:FindFirstChild("EmoteModule")
    if not mod then return end
    local list = {"headless","zombie","zen","ninja","floss","dab","sit"}
    pcall(function() require(mod).GeneratePage(list, emotesUI, "Free Emotes") end)
    notify("Emotes", "Free emotes page added to your emote menu.", "smile", 3)
    if freeEmotesRunning then return end
    freeEmotesRunning = true
    task.spawn(function()
        while emotesUI.Parent do
            local pages = emotesUI:FindFirstChild("EmotePages")
            if pages and not pages:FindFirstChild("Free Emotes") then
                pcall(function() require(mod).GeneratePage(list, emotesUI, "Free Emotes") end)
            end
            task.wait(0.2)
        end
        freeEmotesRunning = false
    end)
end

-- ── Destroy helpers ──
local function destroyOtherPlayers()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            local m = Workspace:FindFirstChild(p.Name)
            if m then m:Destroy() end
        end
    end
end
local function destroyMapExceptCoins()
    for _, c in ipairs(Workspace:GetChildren()) do
        if c:IsA("Model") and c:FindFirstChild("CoinContainer") then
            for _, c2 in ipairs(c:GetChildren()) do
                if c2.Name ~= "CoinContainer" then c2:Destroy() end
            end
        end
    end
end

-- ── Shuffle weapons ──
local function randomOwnedWeapon()
    local ok, weapons = pcall(function()
        return require(ReplicatedStorage.Modules.InventoryModule).MyInventory.Data.Weapons
    end)
    if not ok or not weapons then return nil end
    local list = {}
    for _, cat in pairs(weapons) do
        for k in pairs(cat) do table.insert(list, k) end
    end
    if #list == 0 then return nil end
    return list[math.random(1, #list)]
end

local lastShuffle = 0
AddConnection(RunService.Stepped:Connect(function()
    if AF.Emotes.SpamSelected then playEmote(AF.Emotes.Selected) end
    if AF.ShuffleWeapons and tick() - lastShuffle > 0.1 then
        lastShuffle = tick()
        local w = randomOwnedWeapon()
        if w then
            pcall(function() ReplicatedStorage.Remotes.Inventory.Equip:FireServer(w, "Weapons") end)
        end
    end
    if AF.CoinFarm.DestroyPlayers then destroyOtherPlayers() end
end))
AddConnection(RunService.Heartbeat:Connect(function()
    if AF.CoinFarm.DestroyMap then destroyMapExceptCoins() end
end))

-- ── Kill everyone (anchor + slash) ──
local function killEveryone()
    local char = LocalPlayer.Character
    if not char then return end
    if not char:FindFirstChild("Knife") then
        local bp = LocalPlayer:FindFirstChild("Backpack")
        local knife = bp and bp:FindFirstChild("Knife")
        if not knife then return end
        local hum = char:FindFirstChild("Humanoid")
        if hum then hum:EquipTool(knife) end
    end
    local myHRP = char:FindFirstChild("HumanoidRootPart")
    if not myHRP then return end
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character then
            local hrp = p.Character:FindFirstChild("HumanoidRootPart")
            if hrp then
                hrp.Anchored = true
                hrp.CFrame = myHRP.CFrame + myHRP.CFrame.LookVector * 1
            end
        end
    end
    pcall(function() LocalPlayer.Character.Knife.Stab:FireServer("Slash") end)
end
Modules.KillAll = killEveryone

local function bringAllPlayers()
    if Modules.FindMurderer() ~= LocalPlayer then
        notify("Not the murderer", "This is only useful when you are the murderer.", "alert-triangle", 4)
        return
    end
    local myHRP = getHRP()
    if not myHRP then return end
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character then
            local hrp = p.Character:FindFirstChild("HumanoidRootPart")
            if hrp then
                hrp.Anchored = true
                hrp.CFrame = myHRP.CFrame + myHRP.CFrame.LookVector * 5
            end
        end
    end
    notify("Teleported Everyone", "All players moved to your position.", "check-circle", 3)
end

-- ── Teleports (MoveTo method) ──
local oldTeleportToLobby = Modules.TeleportToLobby
Modules.TeleportToLobby = function()
    local lobby = Workspace:FindFirstChild("Lobby")
    if lobby and LocalPlayer.Character then
        LocalPlayer.Character:MoveTo(lobby.WorldPivot.Position)
    else
        oldTeleportToLobby()
    end
end
local oldTeleportToMap = Modules.TeleportToMap
Modules.TeleportToMap = function()
    local map = getRoundMap()
    local spawns = map and map:FindFirstChild("Spawns")
    if not spawns then return oldTeleportToMap() end
    local list = spawns:GetChildren()
    if #list > 0 and LocalPlayer.Character then
        LocalPlayer.Character:MoveTo(list[math.random(1, #list)].Position)
    end
end

-- ── Pick up gun (walk to drop, wait for gun, return) ──
local function pickUpGun()
    local map = getRoundMap()
    local drop = map and map:FindFirstChild("GunDrop")
    if not drop then return end
    if Modules.FindMurderer() == LocalPlayer then return end
    local char = LocalPlayer.Character
    if not char then return end
    local pivot = char:GetPivot()
    char:MoveTo(drop.Position)
    local bp = LocalPlayer:FindFirstChild("Backpack")
    local t0 = tick()
    while not (bp and bp:FindFirstChild("Gun")) and tick() - t0 < 2 do task.wait() end
    char:PivotTo(pivot)
end
Modules.GrabGun = function() task.spawn(pickUpGun) end
Modules.ToggleAutoGrabGun = function(v)
    Modules.Config.AutoGrabGun = v
    AF.AutoPickUpGun = v
    if v then task.spawn(pickUpGun) end
end

-- ── Trap ESP + auto pick up gun on drop ──
local trapTemplate = Instance.new("Highlight")
trapTemplate.Name = "TrapESP"
trapTemplate.OutlineTransparency = 1
trapTemplate.FillColor = Color3.fromRGB(255, 0, 0)
trapTemplate.FillTransparency = 0.4
trapTemplate.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
local function addTrapESP(d)
    if not (d.Parent and d.Parent:IsDescendantOf(Workspace)) then return end
    pcall(function() d.Transparency = 0 end)
    local h = trapTemplate:Clone()
    h.Adornee = d
    h.Parent = Workspace
end
local function setTrapESP(on)
    AF.TrapESP = on
    if on then
        for _, d in ipairs(Workspace:GetDescendants()) do
            if d.Name == "Trap" then addTrapESP(d) end
        end
    else
        for _, c in ipairs(Workspace:GetChildren()) do
            if c.Name == "TrapESP" and c:IsA("Highlight") then c:Destroy() end
        end
    end
end
AddConnection(Workspace.DescendantAdded:Connect(function(d)
    if AF.TrapESP and d.Name == "Trap" then addTrapESP(d) end
    if AF.AutoPickUpGun and d.Name == "GunDrop" then
        task.wait(0.5)
        for _ = 1, 5 do pickUpGun() end
    end
end))

-- ── Auto shoot murderer (raycast + KnifeLocal.CreateBeam "AH2") ──
local function shootMurdererAH2()
    local char = LocalPlayer.Character
    if not char then return end
    local bp = LocalPlayer:FindFirstChild("Backpack")
    local gun = char:FindFirstChild("Gun") or (bp and bp:FindFirstChild("Gun"))
    if not gun then return end
    local hum = getHum()
    if hum and gun.Parent == bp then hum:EquipTool(gun) end
    local m = Modules.FindMurderer()
    if not m or not m.Character then return end
    local torso = m.Character:FindFirstChild("UpperTorso")
    local mHum = m.Character:FindFirstChild("Humanoid")
    if not torso or not mHum then return end
    local aim = torso.Position + torso.AssemblyLinearVelocity * Vector3.new(0, 0.5, 0) * 0.14 + mHum.MoveDirection * 2.8
    pcall(function()
        local g = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Gun")
        if g then g.KnifeLocal.CreateBeam.RemoteFunction:InvokeServer(1, aim, "AH2") end
    end)
end
AddConnection(RunService.RenderStepped:Connect(function()
    if not AF.AutoShooting or Modules.FindSheriff() ~= LocalPlayer then return end
    local m = Modules.FindMurderer()
    if not m or not m.Character then return end
    local mHRP = m.Character:FindFirstChild("HumanoidRootPart")
    local myHRP = getHRP()
    if not mHRP or not myHRP then return end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {LocalPlayer.Character}
    local hit = Workspace:Raycast(myHRP.Position, mHRP.Position - myHRP.Position, params)
    if not hit or hit.Instance.Parent == m.Character then shootMurdererAH2() end
end))
Modules.ToggleAutoShootMurderer = function(v)
    Modules.Config.AutoShootMurderer = v
    AF.AutoShooting = v
end
Modules.ShootMurdererOnce = function() task.spawn(shootMurdererAH2) end

-- ── Fling extras ──
local function otherPlayers()
    local list = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then table.insert(list, p) end
    end
    return list
end
local function flingRandomPlayer()
    local list = otherPlayers()
    if #list == 0 then
        notify("No target", "There are no other players in the server.", "alert-triangle", 3)
        return
    end
    miniFling({list[math.random(#list)].Name})
end
task.spawn(function()
    while true do
        task.wait(2)
        if AF.LoopFlingAll then
            for _, p in ipairs(otherPlayers()) do
                if not AF.LoopFlingAll then break end
                pcall(miniFling, {p.Name})
                task.wait(0.1)
            end
        end
    end
end)

-- ── Roles ──
local function revealRoles()
    local data = Modules.PlayerData
    if type(data) ~= "table" or next(data) == nil then
        notify("No data", "Player data has not loaded yet.", "alert-triangle", 3)
        return
    end
    local lines = {}
    for name, d in pairs(data) do
        table.insert(lines, string.format("%s - %s", name, tostring(type(d) == "table" and d.Role or "?")))
    end
    notify("Roles", table.concat(lines, "\n"), "users", 8)
end
local function notifyRoleName(role)
    local p = role == "Murderer" and Modules.FindMurderer() or Modules.FindSheriff()
    if p then
        notify(role .. " Username", p.Name, "user", 5)
    else
        notify(role, "Not found.", "alert-triangle", 3)
    end
end

-- ── Coin Farm 1 (fly / tween to nearest coin) ──
local function findNearestCoin()
    local hrp = getHRP()
    if not hrp then return end
    local best, bestDist = nil, 100
    for _, m in ipairs(Workspace:GetChildren()) do
        if m:IsA("Model") and m:FindFirstChild("CoinContainer") then
            for _, c in ipairs(m.CoinContainer:GetChildren()) do
                if c.Name == "Coin_Server" and not c:FindFirstChild("CollectedCoin") and c:FindFirstChild("TouchInterest") then
                    local d = (hrp.Position - c.Position).Magnitude
                    if d < bestDist then best, bestDist = c, d end
                end
            end
        end
    end
    return best
end

local cf1Conns = {}
local function cf1Stop()
    for _, c in ipairs(cf1Conns) do pcall(function() c:Disconnect() end) end
    table.clear(cf1Conns)
    local hrp = getHRP()
    if hrp then
        hrp.Anchored = false
        local bv = hrp:FindFirstChild("MM2_CoinFarmVelocity")
        if bv then bv:Destroy() end
    end
end
local function cf1Step()
    if not AF.CoinFarm.State then return end
    local visible, full = bagState()
    local hrp = getHRP()
    if not (visible and not full and hrp) then return end
    if not hrp:FindFirstChild("MM2_CoinFarmVelocity") then
        local bv = Instance.new("BodyVelocity")
        bv.MaxForce = Vector3.new(9e9, 9e9, 9e9)
        bv.Name = "MM2_CoinFarmVelocity"
        bv.Parent = hrp
    end
    noclipSelf()
    local coin = findNearestCoin()
    if coin then
        hrp.Anchored = false
        task.spawn(function()
            local h = getHRP()
            if not h then return end
            local t = (h.Position - coin.Position).Magnitude / AF.CoinFarm.Speed
            TweenService:Create(h, TweenInfo.new(t, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), {
                CFrame = CFrame.new(coin.Position + Vector3.new(0, -1, 0))
            }):Play()
            if coin.Parent then
                local tc
                tc = coin.Touched:Connect(function()
                    task.wait(0.1)
                    if coin then coin:Destroy() end
                    if tc then tc:Disconnect() end
                end)
            end
        end)
    else
        hrp.Anchored = true
    end
    task.wait(0.02)
end
local function cf1Start()
    cf1Stop()
    table.insert(cf1Conns, AddConnection(RunService.Heartbeat:Connect(cf1Step)))
    table.insert(cf1Conns, AddConnection(CoinCollected.OnClientEvent:Connect(function(_, cur, max)
        if cur == max then cf1Stop() end
    end)))
    local hum = getHum()
    if hum then
        table.insert(cf1Conns, AddConnection(hum.Died:Connect(function()
            if not AF.CoinFarm.State then return end
            task.wait(1)
            repeat task.wait() until LocalPlayer.Character
            task.wait(1)
            LocalPlayer.PlayerGui:WaitForChild("MainGUI")
            task.wait(1)
            Modules.TeleportToMap()
        end)))
    end
    local endFade = GameRemotes:FindFirstChild("RoundEndFade")
    if endFade then
        table.insert(cf1Conns, AddConnection(endFade.OnClientEvent:Connect(cf1Stop)))
    end
end
task.spawn(cf1Start)

-- ── Coin Farm 2 (safe platform under map + firetouchinterest) ──
local oldPlatform = Workspace:FindFirstChild("GhostCF2Platform")
if oldPlatform then oldPlatform:Destroy() end
local cf2Platform = Instance.new("Part")
cf2Platform.Name = "GhostCF2Platform"
cf2Platform.Anchored = true
cf2Platform.Position = Vector3.new(1, -100, 1)
cf2Platform.Size = Vector3.new(100, 1.2, 100)
cf2Platform.Parent = Workspace

local cf2Done, cf2Running = false, false
local function cf2ToPlatform()
    local hrp = getHRP()
    if hrp then
        hrp.CFrame = CFrame.new(cf2Platform.Position + Vector3.new(math.random(-10, 5), 5, math.random(-10, 5)))
    end
end
local function cf2UnderCoin(coin)
    local hrp = getHRP()
    if coin and hrp then hrp.CFrame = CFrame.new(coin.Position + Vector3.new(0, -6, 0)) end
end
local function cf2Run()
    if cf2Running then return end
    cf2Running = true
    cf2Done = false
    if AF.CoinFarm2.State then cf2ToPlatform() end
    while not cf2Done do
        local map = getCoinMap()
        if not map then
            task.wait(1)
            if AF.CoinFarm2.State then continue end
        elseif AF.CoinFarm2.State then
            task.spawn(function() pcall(destroyMapExceptCoins) end)
            local target, lowest = nil, math.huge
            for _, c in ipairs(map.CoinContainer:GetChildren()) do
                if c:FindFirstChild("TouchInterest") and c.Position.Y < lowest then
                    lowest = c.Position.Y
                    target = c
                end
            end
            if not target then
                task.wait(0.1)
                continue
            end
            local collected = false
            cf2UnderCoin(target)
            local conn = CoinCollected.OnClientEvent:Connect(function(_, cur, max)
                collected = true
                if cur == max then cf2Done = true end
            end)
            while true do
                task.wait()
                task.spawn(function()
                    local hrp = getHRP()
                    if hrp then
                        pcall(firetouchinterest, hrp, target, 0)
                        pcall(firetouchinterest, hrp, target, 1)
                    end
                end)
                task.wait()
                noclipSelf()
                cf2UnderCoin(target)
                if collected or not target:FindFirstChild("TouchInterest") then break end
            end
            conn:Disconnect()
            cf2ToPlatform()
            task.wait(2)
            continue
        end
        break
    end
    cf2Running = false
end
AddConnection(LocalPlayer.CharacterAdded:Connect(function(c)
    if AF.CoinFarm2.State then
        c:WaitForChild("HumanoidRootPart", 5)
        cf2ToPlatform()
    end
end))

-- ── Event Farm (attribute coins: Candy / BeachBall / Coin / SnowToken / Egg) ──
local EF = {
    PlayerData = {}, MaxCoins = 40, CoinBag = 0, TotalCollected = 0, SessionTime = 0,
    PauseFloatTP = false, IsFarming = false, CoinTypes = {"Any"}, Mode = "Under", Speed = 22.7,
    KillAllOnFull = false, ResetOnFullBag = false, FlingMurdererOnFull = false,
    FlingedRecently = false, LastFlingTime = 0, Enabled = false,
}
local ExtrasRemotes = ReplicatedStorage.Remotes:FindFirstChild("Extras")
local function efIsElite()
    local ok, r = pcall(function() return ExtrasRemotes.AmElite:InvokeServer() end)
    return ok and r
end
task.spawn(function()
    pcall(function()
        EF.PlayerData = GameRemotes.GetCurrentPlayerData:InvokeServer() or {}
        EF.MaxCoins = efIsElite() and 50 or 40
        local me = EF.PlayerData[LocalPlayer.Name]
        if me then
            EF.CoinBag = me.Coins or 0
            EF.IsFarming = not me.Dead
        end
    end)
end)
do
    local pdc = GameRemotes:FindFirstChild("PlayerDataChanged")
    if pdc then
        AddConnection(pdc.OnClientEvent:Connect(function(d)
            if type(d) == "table" then EF.PlayerData = d end
        end))
    end
    AddConnection(CoinCollected.OnClientEvent:Connect(function(_, cur)
        EF.CoinBag = tonumber(cur) or EF.CoinBag
        EF.TotalCollected += 1
    end))
    local lm = GameRemotes:FindFirstChild("LoadingMap")
    if lm then AddConnection(lm.OnClientEvent:Connect(function() EF.CoinBag = 0 end)) end
    AddConnection(RoundStartRE.OnClientEvent:Connect(function()
        EF.IsFarming = true
        task.spawn(function() EF.MaxCoins = efIsElite() and 50 or 40 end)
    end))
    local ef = GameRemotes:FindFirstChild("RoundEndFade")
    if ef then AddConnection(ef.OnClientEvent:Connect(function() EF.IsFarming = false end)) end
end

local function efAlive()
    local c = LocalPlayer.Character
    local h = c and c:FindFirstChildWhichIsA("Humanoid")
    return c ~= nil and h ~= nil and h.Health > 0
end
local function efInRound(p)
    local d = EF.PlayerData[p.Name]
    return d ~= nil and not d.Dead
end
local function efMap()
    for _, c in ipairs(Workspace:GetChildren()) do
        if c:GetAttribute("MapID") then return c end
    end
end
local function efFull() return EF.CoinBag >= EF.MaxCoins end
local function efIsMurderer()
    local d = EF.PlayerData[LocalPlayer.Name]
    return d ~= nil and d.Role == "Murderer"
end
local function efOnlyMurdererLeft()
    local alive, murdAlive = 0, false
    for name, d in pairs(EF.PlayerData) do
        if name ~= LocalPlayer.Name and d and not d.Dead then
            alive += 1
            if d.Role == "Murderer" then murdAlive = true end
        end
    end
    return efInRound(LocalPlayer) and alive == 1 and murdAlive
end
local function efReset()
    EF.PauseFloatTP = true
    task.wait(0.5)
    if efAlive() then getHum():ChangeState(Enum.HumanoidStateType.Dead) end
    repeat task.wait(0.2) until efAlive()
    EF.PauseFloatTP = false
end
local function efKillAll()
    local hum = getHum()
    local bp = LocalPlayer:FindFirstChild("Backpack")
    if bp and bp:FindFirstChild("Knife") and hum then hum:EquipTool(bp.Knife) end
    local knife = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Knife")
    if not knife then return end
    for _, p in ipairs(Players:GetPlayers()) do
        task.spawn(function()
            local myHRP = getHRP()
            if p ~= LocalPlayer and p.Character and myHRP and efInRound(p) then
                local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                if hrp then
                    pcall(function()
                        firetouchinterest(knife.Handle, hrp, 1)
                        knife:FindFirstChild("Events"):FindFirstChild("KnifeStabbed"):FireServer()
                        knife:Activate()
                        firetouchinterest(knife.Handle, hrp, 0)
                    end)
                end
            end
        end)
    end
end
local function efNearestCoin()
    local hrp = getHRP()
    if not hrp then return end
    local map = efMap()
    local cc = map and map:FindFirstChild("CoinContainer")
    if not cc then return end
    local best, bestD = nil, math.huge
    for _, c in ipairs(cc:GetChildren()) do
        local id = c:GetAttribute("CoinID")
        if id and not c:GetAttribute("Collected") and c:IsA("BasePart")
            and (table.find(EF.CoinTypes, id) or table.find(EF.CoinTypes, "Any")) then
            local vis = c:FindFirstChild("CoinVisual")
            local main = vis and vis:FindFirstChild("MainCoin")
            if main and main.Transparency == 0 then
                local d = (hrp.Position - c.Position).Magnitude
                if d < bestD then best, bestD = c, d end
            end
        end
    end
    return best
end
local function efMarkFling()
    EF.FlingedRecently = true
    EF.LastFlingTime = tick()
    task.delay(30, function()
        if tick() - EF.LastFlingTime >= 30 then EF.FlingedRecently = false end
    end)
end

local efFloat, efStartPos = nil, nil
local efConns = {}
local function efParkFloat()
    if efFloat and efFloat.Parent then efFloat.CFrame = CFrame.new(100, 0, 100) end
end
local function efHandleFullBag()
    if EF.FlingMurdererOnFull and not efIsMurderer() and efAlive() and efFull() then
        if efOnlyMurdererLeft() then
            efReset()
        else
            for name, d in pairs(EF.PlayerData) do
                if name ~= LocalPlayer.Name and d.Role == "Murderer" and not d.Dead then
                    EF.PauseFloatTP = true
                    efMarkFling()
                    miniFling({name})
                    EF.PauseFloatTP = false
                    task.wait(0.5)
                    break
                end
            end
        end
    end
    if efIsMurderer() and EF.KillAllOnFull and efFull() and efInRound(LocalPlayer) and efAlive() then
        efKillAll()
    end
    if EF.ResetOnFullBag and efFull() and efAlive() and not efIsMurderer() and not EF.FlingedRecently and efInRound(LocalPlayer) then
        efReset()
    end
end
local function efCollect(hrp)
    local coin = efNearestCoin()
    if not coin then return end
    local offset = EF.Mode == "Under" and -6 or -2
    local target = CFrame.new(coin.Position) * CFrame.new(0, offset - 1, 0)
    local dist = (hrp.Position - target.Position).Magnitude
    if dist >= 200 then
        efFloat.CFrame = target
    else
        local tw = TweenService:Create(efFloat, TweenInfo.new(dist / EF.Speed, Enum.EasingStyle.Linear), {CFrame = target})
        tw:Play()
        if not efFull() then
            tw.Completed:Wait()
            tw:Cancel()
        end
    end
    for _ = 0, 200 do
        pcall(function()
            firetouchinterest(hrp, coin, 1)
            firetouchinterest(hrp, coin, 0)
        end)
    end
    coin:Destroy()
end
local function efSetEnabled(on)
    EF.Enabled = on
    for _, c in ipairs(efConns) do pcall(function() c:Disconnect() end) end
    table.clear(efConns)
    if not on then
        if efFloat then efFloat:Destroy(); efFloat = nil end
        local hrp = getHRP()
        if hrp and efStartPos then
            hrp.Anchored = true
            hrp.CFrame = CFrame.new(efStartPos)
            hrp.Velocity = Vector3.zero
            task.wait(0.7)
            hrp.Anchored = false
        end
        return
    end
    if efFloat then efFloat:Destroy() end
    efFloat = Instance.new("Part")
    efFloat.Name = "GhostEventFloat"
    efFloat.Size = Vector3.new(5, 0.1, 5)
    efFloat.CanCollide = true; efFloat.Anchored = true; efFloat.Transparency = 1
    efFloat.Parent = Workspace
    local hrp0 = getHRP()
    efStartPos = hrp0 and hrp0.Position or Vector3.zero
    table.insert(efConns, AddConnection(RunService.RenderStepped:Connect(function(dt)
        EF.SessionTime += dt
        if getHRP() then noclipSelf() end
    end)))
    table.insert(efConns, AddConnection(RunService.Heartbeat:Connect(function()
        local hrp = getHRP()
        if hrp and efFloat and efAlive() and not EF.PauseFloatTP then
            local cf = efFloat.CFrame * CFrame.new(0, 3, 0)
            if efInRound(LocalPlayer) and not efFull() and EF.IsFarming then
                cf = cf * CFrame.Angles(math.rad(90), 0, 0)
            end
            hrp.CFrame = cf
            hrp.Velocity = Vector3.zero
            hrp.RotVelocity = Vector3.zero
        end
    end)))
    task.spawn(function()
        while EF.Enabled do
            local hrp = getHRP()
            if not hrp or not efAlive() then
                task.wait(1)
            elseif not efMap() then
                efParkFloat()
            elseif not efInRound(LocalPlayer) or efFull() or not EF.IsFarming then
                if EF.IsFarming then efHandleFullBag() end
                efParkFloat()
                task.wait(0.1)
            else
                efCollect(hrp)
            end
            task.wait()
        end
    end)
end
local function efStatsText()
    local function fmtTime(s)
        return string.format("%02d:%02d:%02d", math.floor(s / 3600), math.floor(s / 60) % 60, math.floor(s % 60))
    end
    local function commas(n)
        local s = tostring(n):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
        return s
    end
    local perHour = EF.SessionTime > 0 and math.round(EF.TotalCollected / EF.SessionTime * 3600) or 0
    return string.format("Time: %s\nCoins: %s | Per Hour: %s", fmtTime(EF.SessionTime), commas(EF.TotalCollected), commas(perHour))
end

-- ── Round start ──
AddConnection(RoundStartRE.OnClientEvent:Connect(function()
    task.spawn(cf2Run)
    task.spawn(function()
        if AF.AutoRevealRoles then
            task.wait(1)
            revealRoles()
        end
        if AF.AutoFarm.KillEveryone then
            task.wait(1)
            repeat
                killEveryone()
                task.wait(1)
            until Modules.FindMurderer() ~= LocalPlayer
        end
        if AF.AutoFarm.AutoFlingMurderer then
            local m = Modules.FindMurderer()
            if m and m ~= LocalPlayer then miniFling({m.Name}) end
        end
        if AF.AutoFarm.AutoFlingSheriff then
            local s = Modules.FindSheriff()
            if s and s ~= LocalPlayer then miniFling({s.Name}) end
        end
        if AF.AutoFarm.TeleportSpawn then Modules.TeleportToLobby() end
        cf1Start()
    end)
end))

-- ── Full bag actions ──
local bagHandled = false
AddConnection(CoinCollected.OnClientEvent:Connect(function(_, cur, max)
    if cur ~= max or bagHandled then return end
    bagHandled = true
    task.spawn(function()
        if AF.AutoFarm.KillAtFullBag and Modules.FindMurderer() == LocalPlayer then
            for _ = 1, 10 do
                if Modules.FindMurderer() ~= LocalPlayer then break end
                killEveryone()
                task.wait(1)
            end
        elseif AF.AutoFarm.FlingMurdererAtFullBag and Modules.FindMurderer() ~= LocalPlayer then
            for _ = 1, 5 do
                local m = Modules.FindMurderer()
                if not m or m == LocalPlayer then break end
                miniFling({m.Name})
                task.wait(1)
            end
        elseif AF.AutoFarm.TeleportUnderMap then
            task.wait(0.1)
            teleportUnderMap()
        elseif AF.CoinFarm.DieAtFullBag then
            local h = getHum()
            if h then h:ChangeState(Enum.HumanoidStateType.Dead) end
        end
        task.wait(2)
        bagHandled = false
    end)
end))

-- ── Auto prestige / auto open crates / server hop when empty ──
task.spawn(function()
    while true do
        task.wait(30)
        if AF.AutoFarm.AutoPrestige then
            pcall(function() ReplicatedStorage.Remotes.Inventory.Prestige:FireServer() end)
        end
    end
end)

local CRATES, CRATE_TYPES = {}, {}
pcall(function()
    for name, info in pairs(require(ReplicatedStorage.Database.Sync.Shop).Weapons) do
        local n = tostring(name)
        table.insert(CRATES, n)
        if type(info) == "table" then CRATE_TYPES[n] = info.DataType end
    end
    table.sort(CRATES)
end)
local function selectCrate(name)
    AF.AutoOpenCrates.Crate = name
    if CRATE_TYPES[name] then AF.AutoOpenCrates.CrateType = CRATE_TYPES[name] end
end
if CRATES[1] and not table.find(CRATES, AF.AutoOpenCrates.Crate) then selectCrate(CRATES[1]) end
task.spawn(function()
    while true do
        task.wait(0.5)
        if AF.AutoOpenCrates.State and AF.AutoOpenCrates.Crate then
            pcall(function()
                ReplicatedStorage.Remotes.MysteryBox.OpenBox:FireServer("OpenBox", AF.AutoOpenCrates.Crate, AF.AutoOpenCrates.CrateType)
            end)
        end
    end
end)

AddConnection(Players.PlayerRemoving:Connect(function()
    task.defer(function()
        if AF.AutoFarm.AutoServerHop and AF.AutoFarm.PlayersToServerHop > #Players:GetPlayers() then
            Modules.ServerHop()
        end
    end)
end))

-- ── Remove depth-of-field blur ──
local function killDepthOfField(c)
    if c.Name == "DepthOfField" then
        pcall(function()
            c.InFocusRadius = 500
            c:Destroy()
        end)
    end
end
for _, c in ipairs(Lighting:GetChildren()) do killDepthOfField(c) end
AddConnection(Lighting.ChildAdded:Connect(killDepthOfField))

-- ── XP farm (teleport behind murderer + fire held tool) ──
task.spawn(function()
    while true do
        task.wait(1.5)
        if AF.XPFarm then
            local hrp = getHRP()
            local m = Modules.FindMurderer()
            local mHRP = m and m ~= LocalPlayer and m.Character and m.Character:FindFirstChild("HumanoidRootPart")
            if hrp and mHRP then
                pcall(function() hrp.CFrame = mHRP.CFrame * CFrame.new(0, 0, 3) end)
                task.wait(0.1)
                local tool = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildWhichIsA("Tool")
                local remote = tool and (tool:FindFirstChildOfClass("RemoteEvent") or tool:FindFirstChildOfClass("RemoteFunction"))
                if remote and remote:IsA("RemoteEvent") then
                    pcall(function() remote:FireServer(mHRP.CFrame) end)
                end
            end
        end
    end
end)

-- ── Anti AFK ──
local antiAFKConn = nil
local function applyAntiAFK(enabled)
    if antiAFKConn then antiAFKConn:Disconnect(); antiAFKConn = nil end
    if enabled then
        antiAFKConn = AddConnection(LocalPlayer.Idled:Connect(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
        end))
    end
end

-- ── Fly GUI ──
local function openFlyGui()
    local ok, err = pcall(function()
        loadstring(game:HttpGet("https://raw.githubusercontent.com/XNEOFF/FlyGuiV3/main/FlyGuiV3.txt"))()
    end)
    if not ok then notify("Fly GUI failed", tostring(err), "circle-x", 4) end
end

-- ── Inventory value ──
local function getValueList()
    local cachePath = "ValueData/mm2_values.json"
    pcall(function()
        if not isfolder("ValueData") then makefolder("ValueData") end
    end)
    local okCache, cached = pcall(function()
        if isfile(cachePath) then return HttpService:JSONDecode(readfile(cachePath)) end
    end)
    if okCache and type(cached) == "table" and os.time() - (cached._time or 0) < 3600 then
        return cached.data or {}
    end
    local ok, raw = pcall(function()
        return game:HttpGet("https://api.project-reverse.org/valuables/get-game-valuables?game=mm2")
    end)
    if ok then
        local ok2, data = pcall(HttpService.JSONDecode, HttpService, raw)
        if ok2 and type(data) == "table" then
            pcall(function() writefile(cachePath, HttpService:JSONEncode({data = data.data, _time = os.time()})) end)
            return data.data or {}
        end
    end
    return (okCache and type(cached) == "table" and cached.data) or {}
end
local function inventoryReport(playerName)
    local prices = {}
    for _, v in pairs(getValueList()) do
        if type(v) == "table" and v.name then prices[v.name] = tonumber(v.price) or 0 end
    end
    local res = ReplicatedStorage.Remotes.Extras.GetFullInventory:InvokeServer(playerName) or {}
    local items = {}
    for k, n in pairs((res.Weapons or {}).Owned or {}) do items[k] = (items[k] or 0) + (tonumber(n) or 0) end
    for k, n in pairs((res.Pets or {}).Owned or {}) do items[k] = (items[k] or 0) + (tonumber(n) or 0) end
    local rows, total, count = {}, 0, 0
    for name, n in pairs(items) do
        local price = prices[name] or 0
        if price > 0 then
            table.insert(rows, {name = name, count = n, price = price, total = price * n})
            total += price * n
            count += n
        end
    end
    table.sort(rows, function(a, b) return a.total > b.total end)
    local lines = {"Inventory Analysis:", string.rep("-", 40)}
    for _, r in ipairs(rows) do
        table.insert(lines, string.format("%-20s x%-4d | $%8.2f | $%10.2f", r.name, r.count, r.price, r.total))
    end
    table.insert(lines, string.rep("-", 40))
    table.insert(lines, string.format("Total Items: %d", count))
    table.insert(lines, string.format("Total Value: $%d", math.floor(total)))
    return table.concat(lines, "\n"), total, count
end

-- ============================================================
-- TABS (our sidebar Section system + Vision Hub tab content)
-- ============================================================

do
-- ── HOME ────────────────────────────────────────────────────
local HomeTab = Window:Tab({Title="Home", Icon="house"})
HomeTab:Paragraph({
    Title = "Welcome to Zovlane Hub",
    Desc  = "Halloween Edition v5.0. RightShift opens/closes the menu on PC; on mobile use the Zovlane Hub button.",
})
HomeTab:Space()
HomeTab:Paragraph({
    Title = "What's new in v5.0",
    Desc  = [[
+ Coin Farm 1 (fly), Coin Farm 2 (safe TP under map), Event Farm (Candy / BeachBall / SnowToken / Egg)
+ Stats overlay, session coins per hour
+ On full bag: kill everyone, fling murderer, teleport under map, or die
+ Round start: kill everyone, fling murderer / sheriff, teleport to lobby
+ Auto shoot murderer with line-of-sight check and movement prediction
+ Kill everyone + bring all players (murderer)
+ Auto pick up gun, trap ESP, reveal roles
+ Fling random player, loop fling all
+ Unlock all emotes, emote spam, shuffle weapons
+ Auto open crates (real crate list), auto prestige, server hop when empty
+ Inventory value analyzer
+ Trade Helper: item values + totals in trades (Supreme or USD), auto offer with min profit
+ Item Spawner: visual-only items and crate animations to troll friends
+ Keybinds are all off until you set them in Settings
+ Mobile open button, window fits your screen
    ]]
})
HomeTab:Space()
HomeTab:Paragraph({Title="Found a bug?", Desc="Re-execute the script or rejoin."})

end
do
-- ── ROLES SECTION ──────────────────────────────────────────
local CombatSection = Window:Section({Title="Roles", Opened=true})

-- Innocent: survive, grab the gun, deal with the murderer
local InnocentTab = CombatSection:Tab({Title="Innocent", Icon="shield"})
local InnoGun = InnocentTab:Section({Title="Gun", Opened=true})
InnoGun:Button({Title="Pick Up Gun", Desc="Walks to the dropped gun, grabs it and returns",
    Icon="hand", Callback=Modules.GrabGun})
InnoGun:Toggle({Title="Auto Pick Up Gun", Desc="Grab the gun as soon as it drops", Flag="AutoGrabGunToggle",
    Callback=Modules.ToggleAutoGrabGun})
local InnoSurvive = InnocentTab:Section({Title="Survive", Opened=true})
InnoSurvive:Toggle({Title="God Mode", Desc="Grants extra lives", Flag="GodModeToggle",
    Callback=Modules.EnableGodMode})
InnoSurvive:Toggle({Title="Anti-Fling", Desc="Prevents players from flinging you", Flag="AntiFlingToggle",
    Callback=Modules.ToggleAntiFling})
InnoSurvive:Button({Title="Who Is The Murderer?", Icon="skull",
    Callback=function() notifyRoleName("Murderer") end})
InnoSurvive:Button({Title="Fling Murderer", Icon="wind",
    Callback=function()
        local m = Modules.FindMurderer()
        if m and m ~= LocalPlayer then task.spawn(miniFling, {m.Name}) end
    end})

-- Sheriff: shoot the murderer
local SheriffTab = CombatSection:Tab({Title="Sheriff", Icon="crosshair"})
local CombatSherS = SheriffTab:Section({Title="Shooting", Opened=true})
CombatSherS:Toggle({Title="Auto Shoot Murderer", Desc="Shoots the murderer whenever you have line of sight", Flag="AutoShootMurderer",
    Callback=Modules.ToggleAutoShootMurderer})
CombatSherS:Button({Title="Shoot Murderer", Desc="Fire one predicted shot at the murderer",
    Icon="crosshair", Callback=Modules.ShootMurdererOnce})
CombatSherS:Button({Title="Toggle Silent Aim", Desc="Redirects your manual shots to the murderer",
    Icon="crosshair", Callback=Modules.ShootMurdererSilent})
CombatSherS:Button({Title="Who Is The Murderer?", Icon="skull",
    Callback=function() notifyRoleName("Murderer") end})

-- Murderer: kill everyone
local MurdererTab = CombatSection:Tab({Title="Murderer", Icon="skull"})
local CombatMurdS = MurdererTab:Section({Title="Killing", Opened=true})
CombatMurdS:Button({Title="Kill Everyone", Desc="Pulls everyone in front of you and slashes",
    Icon="skull", Callback=function()
        if Modules.FindMurderer() ~= LocalPlayer then
            notify("Not the murderer", "You do not have the knife.", "alert-triangle", 4)
        end
        task.spawn(killEveryone)
    end})
CombatMurdS:Button({Title="Bring All Players", Desc="Teleport every player in front of you",
    Icon="users", Callback=bringAllPlayers})
CombatMurdS:Toggle({Title="Auto Kill All", Desc="Keep killing everyone while you have the knife", Flag="AutoKillToggle",
    Callback=Modules.ToggleAutoKillAll})
CombatMurdS:Toggle({Title="Knife Aura", Desc="Kill players within a radius", Flag="KillAuraToggle",
    Callback=Modules.KillAura})
CombatMurdS:Slider({Title="Aura Radius", Desc="Detection radius", Flag="AuraRadiusSlider",
    Value={Min=5,Max=100,Default=10}, Callback=function(v) Modules.Config.AuraRadius=v end})
local MurdThrow = MurdererTab:Section({Title="Knife Throw", Opened=true})
MurdThrow:Toggle({Title="Auto Knife Throw", Desc="Throws knife at nearest automatically", Flag="ThrowKnifeFlag",
    Callback=Modules.ToggleSilentThrow})
MurdThrow:Button({Title="Throw Knife", Desc="Throw knife at nearest player",
    Icon="crosshair", Callback=Modules.ExecuteThrowAtNearest})
local MurdSheriff = MurdererTab:Section({Title="Deal With The Sheriff", Opened=true})
MurdSheriff:Button({Title="Who Is The Sheriff?", Icon="shield",
    Callback=function() notifyRoleName("Sheriff") end})
MurdSheriff:Button({Title="Fling Sheriff", Icon="wind",
    Callback=function()
        local s = Modules.FindSheriff()
        if s and s ~= LocalPlayer then task.spawn(miniFling, {s.Name}) end
    end})

-- ── VISUALS & TROLL SECTION ─────────────────────────────────
local ExtrasSection = Window:Section({Title="Visuals & Troll", Opened=true})

-- Visuals Tab
local VisualsTab = ExtrasSection:Tab({Title="Visuals", Icon="eye"})

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
VisualsESP:Toggle({Title="Trap ESP", Desc="Highlight traps placed by the murderer", Flag="TrapEspToggle",
    Callback=setTrapESP})

local VisualsNotify = VisualsTab:Section({Title="Notify", Opened=true})
VisualsNotify:Toggle({Title="Notify Gun Dropped", Desc="Alert when gun is dropped", Flag="NotifyGunToggle",
    Callback=function(v) Modules.ToggleNotifyGunDropped(v) end})
VisualsNotify:Toggle({Title="Notify Murderer", Desc="Alert with picture when Murderer spawns", Flag="NotifyMurdererToggle",
    Callback=function(v) Modules.Config.NotifyMurderer=v; Modules.UpdateRoleNotify() end})
VisualsNotify:Toggle({Title="Notify Sheriff", Desc="Alert with picture when Sheriff spawns", Flag="NotifySheriffToggle",
    Callback=function(v) Modules.Config.NotifySheriff=v; Modules.UpdateRoleNotify() end})
VisualsNotify:Space()
VisualsNotify:Button({Title="Reveal Roles", Desc="Show every player's role", Icon="users", Callback=revealRoles})
VisualsNotify:Toggle({Title="Auto Reveal Roles", Desc="Show roles at the start of every round", Flag="AutoRevealRolesToggle",
    Callback=function(v) AF.AutoRevealRoles = v end})
VisualsNotify:Button({Title="Murderer Username", Icon="skull", Callback=function() notifyRoleName("Murderer") end})
VisualsNotify:Button({Title="Sheriff Username", Icon="shield", Callback=function() notifyRoleName("Sheriff") end})

-- Troll Tab
local TrollTab = ExtrasSection:Tab({Title="Troll", Icon="zap"})

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
TrollFling:Button({Title="Fling Random Player", Icon="shuffle",
    Callback=function() task.spawn(flingRandomPlayer) end})
TrollFling:Toggle({Title="Loop Fling All Players", Desc="Keeps flinging everyone every 2 seconds", Flag="LoopFlingAllToggle",
    Callback=function(v) AF.LoopFlingAll = v end})
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
TrollEmotes:Button({Title="Unlock All Emotes", Desc="Adds a Free Emotes page to your emote menu", Icon="lock-open",
    Callback=unlockAllEmotes})
TrollEmotes:Dropdown({Title="Select Emote", Desc="Choose emote", Flag="EmoteDropdown",
    Values=EMOTES, Value=AF.Emotes.Selected,
    Callback=function(v) AF.Emotes.Selected = v end})
TrollEmotes:Button({Title="Play Emote", Icon="play",
    Callback=function() playEmote(AF.Emotes.Selected) end})
TrollEmotes:Toggle({Title="Spam Selected Emote", Flag="SpamSelectedEmoteToggle",
    Callback=function(v) AF.Emotes.SpamSelected = v end})
TrollEmotes:Toggle({Title="Spam Random Emotes", Flag="SpamRandomEmoteToggle",
    Callback=function(v) AF.Emotes.SpamRandom = v end})
TrollEmotes:Slider({Title="Random Spam Speed", Desc="Emotes per second", Flag="EmoteSpeedSlider",
    Value={Min=1, Max=50, Default=1},
    Callback=function(v) AF.Emotes.Speed = v end})

end
do
-- ── MOVEMENT SECTION ───────────────────────────────────────
local MovSection = Window:Section({Title="Movement", Opened=true})

local PlayerTab = MovSection:Tab({Title="Character", Icon="footprints"})
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

local TpTab = MovSection:Tab({Title="Teleports", Icon="map-pin"})

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

end
do
-- ── AUTOMATION SECTION ─────────────────────────────────────
local AutoSection = Window:Section({Title="Automation", Opened=true})

-- Coin Farm tab
local FarmTab = AutoSection:Tab({Title="Coin Farm", Icon="dollar-sign"})

local CF1Sub = FarmTab:Section({Title="Coin Farm 1 (Fly)", Opened=true})
CF1Sub:Toggle({Title="Enable Coin Farm 1", Desc="Flies to the nearest coin with a tween", Flag="CF1Toggle",
    Callback=function(v)
        AF.CoinFarm.State = v
        if v then cf1Start() else cf1Stop() end
    end})
CF1Sub:Slider({Title="Farm Speed", Desc="Studs per second (above 22.5 may kick)", Flag="CF1Speed",
    Step=0.5, Value={Min=15, Max=25, Default=22.5},
    Callback=function(v) AF.CoinFarm.Speed = v end})

local CF2Sub = FarmTab:Section({Title="Coin Farm 2 (Safe TP)", Opened=true})
CF2Sub:Toggle({Title="Enable Coin Farm 2", Desc="Waits on a platform under the map and grabs coins from below", Flag="CF2Toggle",
    Callback=function(v)
        AF.CoinFarm2.State = v
        if v then task.spawn(cf2Run) end
    end})

local EventSub = FarmTab:Section({Title="Event Farm", Opened=true})
local eventStatsPara = EventSub:Paragraph({Title="Session Progress", Desc=efStatsText()})
task.spawn(function()
    while eventStatsPara do
        pcall(function() eventStatsPara:SetDesc(efStatsText()) end)
        task.wait(0.5)
    end
end)
EventSub:Toggle({Title="Enable Event Farm", Desc="Floats under event coins (Candy, BeachBall, SnowToken, Egg...)", Flag="EventFarmToggle",
    Callback=function(v) task.spawn(efSetEnabled, v) end})
EventSub:Dropdown({Title="Coin Types", Desc="Which coins to collect", Flag="EventCoinTypes",
    Values={"Any","Candy","BeachBall","Coin","SnowToken","Egg"}, Value={"Any"}, Multi=true, AllowNone=true,
    Callback=function(v)
        if type(v) ~= "table" then v = {v} end
        EF.CoinTypes = #v > 0 and v or {"Any"}
    end})
EventSub:Dropdown({Title="Teleport Mode", Desc="Under = below the coin, Normal = at the coin", Flag="EventTPMode",
    Values={"Under","Normal"}, Value="Under",
    Callback=function(v) EF.Mode = v end})
EventSub:Slider({Title="Event Farm Speed", Desc="Studs per second (above 22 might kick)", Flag="EventSpeed",
    Step=0.1, Value={Min=19, Max=26, Default=22.7},
    Callback=function(v) EF.Speed = v end})
EventSub:Toggle({Title="Kill All On Full Bag", Desc="Knife required", Flag="EventKillAll",
    Callback=function(v) EF.KillAllOnFull = v end})
EventSub:Toggle({Title="Reset On Full Bag", Flag="EventReset",
    Callback=function(v) EF.ResetOnFullBag = v end})
EventSub:Toggle({Title="Fling Murderer On Full Bag", Flag="EventFlingMurd",
    Callback=function(v) EF.FlingMurdererOnFull = v end})

local CoinSettings = FarmTab:Section({Title="Coin Settings", Opened=true})
CoinSettings:Toggle({Title="Stats Overlay", Desc="Coins collected, total and coins per hour on screen", Flag="StatsOverlayToggle",
    Callback=function(v) AF.StatsOverlay = v end})
CoinSettings:Toggle({Title="Destroy Player Models", Flag="DestroyPlayersToggle",
    Callback=function(v) AF.CoinFarm.DestroyPlayers = v end})
CoinSettings:Toggle({Title="Destroy Map", Desc="Removes everything except the coins", Flag="DestroyMapToggle",
    Callback=function(v) AF.CoinFarm.DestroyMap = v end})
CoinSettings:Toggle({Title="Disable 3D Rendering", Desc="Black screen, lowers CPU usage", Flag="Disable3DToggle",
    Callback=function(v) set3DRendering(not v) end})
CoinSettings:Button({Title="Teleport Under Map", Desc="Go to the safe spot now", Icon="arrow-down",
    Callback=function() task.spawn(teleportUnderMap) end})

local BagFullSub = FarmTab:Section({Title="On Full Bag", Opened=true})
BagFullSub:Toggle({Title="Kill Everyone (Murderer)", Flag="KillAtBagToggle",
    Callback=function(v) AF.AutoFarm.KillAtFullBag = v end})
BagFullSub:Toggle({Title="Fling Murderer", Flag="FlingAtBagToggle",
    Callback=function(v) AF.AutoFarm.FlingMurdererAtFullBag = v end})
BagFullSub:Toggle({Title="Teleport Under Map", Flag="TpUnderAtBagToggle",
    Callback=function(v) AF.AutoFarm.TeleportUnderMap = v end})
BagFullSub:Toggle({Title="Die", Desc="Reset your character", Flag="DieAtBagToggle",
    Callback=function(v) AF.CoinFarm.DieAtFullBag = v end})

local FarmXPSub = FarmTab:Section({Title="XP Farm", Opened=true})
FarmXPSub:Toggle({Title="Enable XP Farm", Desc="Every 1.5s: teleports behind murderer and fires your tool", Flag="XPFarmToggle",
    Callback=function(v) AF.XPFarm = v end})
FarmXPSub:Toggle({Title="Anti AFK", Desc="Prevents kick on idle", Flag="AntiAFKToggle",
    Callback=applyAntiAFK})

-- Auto Farm tab
local AutoFarmTab = AutoSection:Tab({Title="Auto Farm", Icon="repeat"})
local RoundSub = AutoFarmTab:Section({Title="Round Start", Opened=true})
RoundSub:Toggle({Title="Teleport To Lobby Spawn", Desc="When the round starts", Flag="AutoTPSpawnToggle",
    Callback=function(v) AF.AutoFarm.TeleportSpawn = v end})
RoundSub:Toggle({Title="Kill Everyone As Murderer", Flag="KillOnStartToggle",
    Callback=function(v) AF.AutoFarm.KillEveryone = v end})
RoundSub:Toggle({Title="Fling Murderer", Flag="FlingMurdOnStartToggle",
    Callback=function(v) AF.AutoFarm.AutoFlingMurderer = v end})
RoundSub:Toggle({Title="Fling Sheriff", Flag="FlingSheriOnStartToggle",
    Callback=function(v) AF.AutoFarm.AutoFlingSheriff = v end})

local ServerAutoSub = AutoFarmTab:Section({Title="Server & Progress", Opened=true})
ServerAutoSub:Toggle({Title="Auto Prestige", Desc="Tries to prestige every 30 seconds", Flag="AutoPrestigeToggle",
    Callback=function(v) AF.AutoFarm.AutoPrestige = v end})
ServerAutoSub:Toggle({Title="Server Hop If Empty", Desc="Hop when players drop below the threshold", Flag="AutoHopEmptyToggle",
    Callback=function(v) AF.AutoFarm.AutoServerHop = v end})
ServerAutoSub:Slider({Title="Player Threshold", Flag="HopThresholdSlider",
    Value={Min=1, Max=12, Default=2},
    Callback=function(v) AF.AutoFarm.PlayersToServerHop = v end})

-- Misc tab
local MiscTab = AutoSection:Tab({Title="Misc", Icon="box"})
local CrateSub = MiscTab:Section({Title="Auto Open Crates", Opened=true})
CrateSub:Toggle({Title="Auto Open Crates", Desc="Opens the chosen box every 0.5s", Flag="AutoCratesToggle",
    Callback=function(v) AF.AutoOpenCrates.State = v end})
if #CRATES > 0 then
    CrateSub:Dropdown({Title="Choose Box", Flag="CrateDropdown",
        Values=CRATES, Value=AF.AutoOpenCrates.Crate,
        Callback=selectCrate})
end

local WeaponSub = MiscTab:Section({Title="Skins", Opened=true})
WeaponSub:Toggle({Title="Shuffle Weapons", Desc="Rapidly equips random weapons you own", Flag="ShuffleWeaponsToggle",
    Callback=function(v) AF.ShuffleWeapons = v end})

local InvSub = MiscTab:Section({Title="Inventory Value", Opened=true})
local invPara = InvSub:Paragraph({Title="Your Inventory", Desc="Press Analyze."})
local invBusy = false
InvSub:Button({Title="Analyze Inventory", Icon="bar-chart",
    Callback=function()
        if invBusy then return end
        invBusy = true
        pcall(function() invPara:SetDesc("Collecting data...") end)
        task.spawn(function()
            local ok, report = pcall(inventoryReport, LocalPlayer.Name)
            pcall(function() invPara:SetDesc(ok and report or "Failed to fetch inventory.") end)
            invBusy = false
        end)
    end})
InvSub:Button({Title="Copy Report", Icon="copy",
    Callback=function()
        task.spawn(function()
            local ok, report = pcall(inventoryReport, LocalPlayer.Name)
            if ok and setclipboard then
                setclipboard(report)
                notify("Copied", "Inventory report copied to clipboard.", "check-circle", 3)
            end
        end)
    end})

local ToolsSub = MiscTab:Section({Title="Tools", Opened=true})
ToolsSub:Button({Title="Fly GUI", Desc="Loads Fly GUI V3", Icon="plane", Callback=openFlyGui})

end
do
-- ============================================================
-- TRADE HELPER (values from pastefy / USD) + ITEM SPAWNER (visual only)
-- ============================================================
local ItemDB = {}
pcall(function() ItemDB = require(ReplicatedStorage.Database.Sync.Item) end)

local SupremeList  = {}
local SupremeVals  = {}   -- item id -> supreme value
local UsdVals      = {}   -- item id -> usd price
local TradeValues  = SupremeVals

local function lookupSupreme(itemName, rarity, isChroma, itemType, year)
    if not itemName or itemName == "" then return nil end
    local bucketName = rarity or ""
    if isChroma then bucketName = "Chroma" end
    if bucketName == "Classic" then bucketName = "Vintage" end
    local bucket = SupremeList[bucketName]
    if type(bucket) ~= "table" then return nil end
    local v = itemName:lower()
    if isChroma then v = "chroma " .. v end
    if bucket[v] then return bucket[v] end
    if bucketName == "Pet" then
        local spaced = v:gsub("(%u)", " %1"):lower():gsub("^%s+", "")
        if spaced ~= v and bucket[spaced] then return bucket[spaced] end
        local squashed = v:gsub("%s+", "")
        for key, val in pairs(bucket) do
            if key:gsub("%s+", "") == squashed then return val end
        end
        return nil
    end
    local t = (itemType or ""):lower()
    local y = tostring(year or "")
    local tries = {v.." ("..t..")", v.." "..t}
    if y ~= "" then
        table.insert(tries, v.." ("..y..")")
        table.insert(tries, v.." "..y)
        table.insert(tries, v.." "..t.." ("..y..")")
        table.insert(tries, v.." ("..t..") ("..y..")")
        table.insert(tries, v.." ("..y..") ("..t..")")
    end
    for _, k in ipairs(tries) do
        if bucket[k] then return bucket[k] end
    end
    local clean = v:gsub(" %([^%)]+%)$", "")
    for key, val in pairs(bucket) do
        if key:gsub(" %([^%)]+%)$", "") == clean then return val end
    end
    return nil
end
local function rebuildSupremeValues()
    table.clear(SupremeVals)
    for id, item in pairs(ItemDB) do
        if type(item) == "table" and item.Rarity and item.Rarity ~= "" and item.ItemName and item.ItemName ~= "" then
            local isChroma = item.Chroma == true or tostring(id):find("Chroma", 1, true) ~= nil
            local val = lookupSupreme(item.ItemName, item.Rarity, isChroma, item.ItemType, item.Year)
            if val then SupremeVals[id] = val end
        end
    end
end
task.spawn(function()
    for _, url in ipairs({"https://pastefy.app/3Jpf5myz/raw", "https://www.astatine.vip/scripts/mm2_value.lua"}) do
        local ok, res = pcall(function() return loadstring(game:HttpGet(url, true))() end)
        if ok and type(res) == "table" and next(res) then
            SupremeList = res
            break
        end
    end
    rebuildSupremeValues()
end)
task.spawn(function()
    for _, v in pairs(getValueList()) do
        if type(v) == "table" and v.name then UsdVals[v.name] = tonumber(v.price) or 0 end
    end
end)

local TH = {
    ShowValues = false, AutoOffer = false, MinProfit = 6, Mode = "Supreme",
    Gui = nil, MyTitle = nil, TheirTitle = nil, MyOffer = nil, TheirOffer = nil,
    MyTotal = 0, TheirTotal = 0, MyInventory = {}, Busy = false,
}
local TradeRemotes = ReplicatedStorage:FindFirstChild("Trade")

local function setPriceMode(mode)
    TH.Mode = mode
    TradeValues = mode == "USD" and UsdVals or SupremeVals
end
local function valueOf(id) return TradeValues[id] or 0 end
local function offerTotal(offer)
    local total = 0
    for _, e in pairs(offer or {}) do
        total += valueOf(e[1]) * (tonumber(e[2]) or 1)
    end
    return total
end
local function getTradeFrame()
    local mg = LocalPlayer.PlayerGui:FindFirstChild("MainGUI")
    local lobby = mg and mg:FindFirstChild("Lobby")
    local phone = lobby and lobby:FindFirstChild("LeaderBar") ~= nil
    local name = phone and "TradeGUI_Phone" or "TradeGUI"
    local g = LocalPlayer.PlayerGui:FindFirstChild(name) or LocalPlayer.PlayerGui:WaitForChild(name, 5)
    local c = g and g:FindFirstChild("Container")
    return c and c:FindFirstChild("Trade")
end
local function setValueLabel(container, text)
    local old = container:FindFirstChild("Value")
    if old then old:Destroy() end
    local l = Instance.new("TextLabel")
    l.Name = "Value"
    l.Size = UDim2.new(1, 0, 0.3, 0)
    l.TextScaled = true
    l.TextWrapped = true
    l.TextStrokeTransparency = 0.7
    l.ZIndex = 10
    l.BackgroundTransparency = 1
    l.TextColor3 = Color3.fromRGB(255, 255, 255)
    l.Text = text
    l.Parent = container
end
local function eachOfferSlot(side, offer, fn)
    local f = TH.Gui
    local cont = f and f:FindFirstChild(side) and f[side]:FindFirstChild("Container")
    if not cont then return end
    for i, e in pairs(offer or {}) do
        local slot = cont:FindFirstChild("NewItem" .. i)
        local c = slot and slot:FindFirstChild("Container")
        if c then fn(c, e) end
    end
end
local function drawTradeValues()
    if not TH.Gui then return end
    eachOfferSlot("TheirOffer", TH.TheirOffer, function(c, e)
        setValueLabel(c, "Value: " .. valueOf(e[1]) * (tonumber(e[2]) or 1))
    end)
    eachOfferSlot("YourOffer", TH.MyOffer, function(c, e)
        setValueLabel(c, "Value: " .. valueOf(e[1]) * (tonumber(e[2]) or 1))
        local amt = c:FindFirstChild("Amount")
        if amt then amt.Position = UDim2.new(0.23, -4, 0.76, 0) end
    end)
    if TH.MyTitle then TH.MyTitle.Text = "YOUR OFFER | TOTAL: " .. TH.MyTotal end
    if TH.TheirTitle then TH.TheirTitle.Text = "THEIR OFFER | TOTAL: " .. TH.TheirTotal end
end
local function clearTradeValues()
    pcall(function() TH.Gui = getTradeFrame() end)
    if not TH.Gui then return end
    for _, side in ipairs({"TheirOffer", "YourOffer"}) do
        local cont = TH.Gui:FindFirstChild(side) and TH.Gui[side]:FindFirstChild("Container")
        if cont then
            for _, slot in ipairs(cont:GetChildren()) do
                local c = slot:IsA("Frame") and slot:FindFirstChild("Container")
                local v = c and c:FindFirstChild("Value")
                if v then v:Destroy() end
            end
        end
    end
    if TH.MyTitle then TH.MyTitle.Text = "YOUR OFFER" end
    if TH.TheirTitle then TH.TheirTitle.Text = "THEIR OFFER" end
end
local function valuableInventory()
    local inv = {}
    local ok, owned = pcall(function()
        return ReplicatedStorage.Remotes.Extras.GetFullInventory:InvokeServer(LocalPlayer.Name).Weapons.Owned
    end)
    if not ok or type(owned) ~= "table" then return inv end
    for id, qty in pairs(owned) do
        local v = valueOf(id)
        if v > 0 then inv[id] = {value = v, quantity = tonumber(qty) or 1} end
    end
    return inv
end
-- best set of up to 4 of your items whose total stays under their total minus the profit margin
local function pickOffer(theirTotal, inventory, profitPct)
    if not theirTotal or theirTotal <= 0 then return {}, 0 end
    local cap = theirTotal * (1 - profitPct / 100)
    local pool = {}
    for id, info in pairs(inventory) do
        for _ = 1, info.quantity do table.insert(pool, {name = id, value = info.value}) end
    end
    table.sort(pool, function(a, b) return a.value > b.value end)
    local maxItems = 4
    local dp = {}
    for i = 0, #pool do
        dp[i] = {}
        for k = 0, maxItems do dp[i][k] = 0 end
    end
    for i = 1, #pool do
        for k = 0, maxItems do
            dp[i][k] = dp[i - 1][k]
            if k > 0 and dp[i - 1][k - 1] + pool[i].value <= cap then
                dp[i][k] = math.max(dp[i][k], dp[i - 1][k - 1] + pool[i].value)
            end
        end
    end
    local chosen, k = {}, maxItems
    for i = #pool, 1, -1 do
        if k > 0 and dp[i][k] ~= dp[i - 1][k] then
            table.insert(chosen, pool[i].name)
            k -= 1
        end
    end
    return chosen, dp[#pool][maxItems]
end
local function tradeOfferItem(id)
    pcall(function() TradeRemotes.OfferItem:FireServer(id, "Weapons") end)
end
local function tradeRemoveItem(id)
    pcall(function() TradeRemotes.RemoveOffer:FireServer(id, "Weapons") end)
end
local function clearMyOffer()
    for _, e in pairs(TH.MyOffer or {}) do
        for _ = 1, tonumber(e[2]) or 1 do tradeRemoveItem(e[1]) end
    end
end
local function generateOffer()
    if not TH.TheirOffer then
        notify("Trade Helper", "Open a trade first.", "alert-triangle", 3)
        return
    end
    if #TH.TheirOffer == 0 then
        clearMyOffer()
        return
    end
    local chosen, total = pickOffer(TH.TheirTotal, TH.MyInventory, TH.MinProfit)
    if total ~= TH.MyTotal then
        TH.Busy = true
        clearMyOffer()
        for _, id in ipairs(chosen) do tradeOfferItem(id) end
        task.delay(0.6, function() TH.Busy = false end)
    end
end
local function readTradeState(data)
    if type(data) ~= "table" then return false end
    local me, them
    if data.Player1 and data.Player1.Player == LocalPlayer then
        me, them = data.Player1, data.Player2
    elseif data.Player2 and data.Player2.Player == LocalPlayer then
        me, them = data.Player2, data.Player1
    end
    if not me or not them then return false end
    TH.MyOffer, TH.TheirOffer = me.Offer, them.Offer
    pcall(function() TH.Gui = getTradeFrame() end)
    if not TH.Gui then return false end
    TH.MyTitle = TH.Gui.YourOffer.Title
    TH.TheirTitle = TH.Gui.TheirOffer.Title
    TH.MyTotal = offerTotal(TH.MyOffer)
    TH.TheirTotal = offerTotal(TH.TheirOffer)
    return true
end
if TradeRemotes then
    AddConnection(TradeRemotes.StartTrade.OnClientEvent:Connect(function()
        pcall(function() TH.Gui = getTradeFrame() end)
        if TH.Gui then
            TH.MyTitle = TH.Gui.YourOffer.Title
            TH.TheirTitle = TH.Gui.TheirOffer.Title
            if TH.ShowValues then
                TH.MyTitle.Text = "YOUR OFFER | TOTAL: 0"
                TH.TheirTitle.Text = "THEIR OFFER | TOTAL: 0"
            end
        end
        task.spawn(function() TH.MyInventory = valuableInventory() end)
    end))
    AddConnection(TradeRemotes.UpdateTrade.OnClientEvent:Connect(function(data)
        if not readTradeState(data) then return end
        if TH.ShowValues then pcall(drawTradeValues) end
        if TH.AutoOffer and not TH.Busy then pcall(generateOffer) end
    end))
    AddConnection(TradeRemotes.AcceptTrade.OnClientEvent:Connect(function()
        if TH.AutoOffer and not TH.Busy then pcall(generateOffer) end
    end))
    AddConnection(TradeRemotes.EndTrade.OnClientEvent:Connect(function()
        TH.MyOffer, TH.TheirOffer = nil, nil
        TH.MyTotal, TH.TheirTotal = 0, 0
    end))
end

-- ── Item spawner (client-side only: nobody else sees these, gone on rejoin) ──
local InvRemotes = ReplicatedStorage.Remotes:FindFirstChild("Inventory")
local ChangeInventoryItem = InvRemotes and InvRemotes:FindFirstChild("ChangeInventoryItem")
local ItemGift = ReplicatedStorage:FindFirstChild("ItemGift")
local BoxModule = nil
pcall(function() BoxModule = require(ReplicatedStorage.Modules.BoxModule) end)
local localCounts = {}
pcall(function()
    for k, v in pairs(require(ReplicatedStorage.Modules.ProfileData).Weapons.Owned) do localCounts[k] = v end
end)

local RARITY_ORDER = {Unique=1, Ancient=2, Godly=3, Classic=4, Vintage=5, Legendary=6}
local SpawnLabels, SpawnIdByLabel = {}, {}
do
    local rows = {}
    for id, item in pairs(ItemDB) do
        if type(item) == "table" and RARITY_ORDER[item.Rarity]
            and (item.ItemType == nil or item.ItemType == "Knife" or item.ItemType == "Gun") then
            table.insert(rows, {id = id, name = item.ItemName or tostring(id), rarity = item.Rarity})
        end
    end
    table.sort(rows, function(a, b)
        if RARITY_ORDER[a.rarity] ~= RARITY_ORDER[b.rarity] then return RARITY_ORDER[a.rarity] < RARITY_ORDER[b.rarity] end
        return a.name:lower() < b.name:lower()
    end)
    for _, r in ipairs(rows) do
        local label = string.format("%s [%s]", r.name, r.rarity == "Classic" and "Vintage" or r.rarity)
        if SpawnIdByLabel[label] then label = label .. " " .. tostring(r.id) end
        SpawnIdByLabel[label] = r.id
        table.insert(SpawnLabels, label)
    end
end

local function spawnItem(id, amount)
    if not firesignal or not ChangeInventoryItem then
        notify("Spawner", "Your executor does not support firesignal.", "circle-x", 4)
        return false
    end
    local newCount = (localCounts[id] or 0) + amount
    localCounts[id] = newCount
    pcall(function() firesignal(ChangeInventoryItem.OnClientEvent, "Weapons", id, newCount) end)
    if ItemGift then
        pcall(function() firesignal(ItemGift.OnClientEvent, id, "Weapons", amount) end)
    end
    return true
end
local function randomBoxName()
    local ok, boxes = pcall(function() return require(ReplicatedStorage.Database.Sync.MysteryBox) end)
    if not ok or type(boxes) ~= "table" then return nil end
    local names = {}
    for k in pairs(boxes) do table.insert(names, k) end
    return #names > 0 and names[math.random(1, #names)] or nil
end
local function openCrateVisual(id)
    if BoxModule then
        pcall(function() BoxModule.OpenBox(randomBoxName(), id) end)
    end
    spawnItem(id, 1)
end

-- ── TRADING SECTION ────────────────────────────────────────
local TradingSection = Window:Section({Title="Trading", Opened=true})

local TradeTab = TradingSection:Tab({Title="Trade Helper", Icon="repeat-2"})
local TradeInfo = TradeTab:Section({Title="Trade Values", Opened=true})
TradeInfo:Paragraph({Title="Trade Helper",
    Desc="Shows the value of every item in a trade and both totals. Supreme values come from the value list, USD from the Project Reverse price list."})
TradeInfo:Dropdown({Title="Price Display", Flag="TradePriceMode",
    Values={"Supreme","USD"}, Value="Supreme",
    Callback=function(v)
        setPriceMode(v)
        if TH.ShowValues and TH.MyOffer then
            TH.MyTotal, TH.TheirTotal = offerTotal(TH.MyOffer), offerTotal(TH.TheirOffer)
            pcall(drawTradeValues)
        end
    end})
TradeInfo:Toggle({Title="Show Values In Trade", Desc="Value under each item + totals in the titles", Flag="TradeShowValues",
    Callback=function(v)
        TH.ShowValues = v
        if v then pcall(drawTradeValues) else pcall(clearTradeValues) end
    end})

local TradeAuto = TradeTab:Section({Title="Auto Offer", Opened=true})
TradeAuto:Paragraph({Title="How it works",
    Desc="Picks up to 4 of your items so your side is worth less than theirs by at least the profit %. It changes your offer by itself, so try it on an alt first."})
TradeAuto:Toggle({Title="Automatically Generate Offers", Desc="Re-picks your items every time their offer changes", Flag="TradeAutoOffer",
    Callback=function(v)
        TH.AutoOffer = v
        if v then task.spawn(function() TH.MyInventory = valuableInventory() end) end
    end})
TradeAuto:Button({Title="Generate Offer", Icon="wand-sparkles",
    Callback=function()
        task.spawn(function()
            if next(TH.MyInventory) == nil then TH.MyInventory = valuableInventory() end
            pcall(generateOffer)
        end)
    end})
TradeAuto:Button({Title="Clear My Offer", Icon="trash-2",
    Callback=function() pcall(clearMyOffer) end})
TradeAuto:Slider({Title="Minimum Profit", Desc="Percent", Flag="TradeMinProfit",
    Value={Min=0, Max=100, Default=6},
    Callback=function(v) TH.MinProfit = v end})

local SpawnerTab = TradingSection:Tab({Title="Item Spawner", Icon="sparkles"})
local SpawnSub = SpawnerTab:Section({Title="Spawner", Opened=true})
SpawnSub:Paragraph({Title="Visual only",
    Desc="Spawned items only show on your screen. Nobody else can see them, they can't be traded, and they disappear when you rejoin."})
local spawnSelection, spawnAmount = {}, 1
SpawnSub:Dropdown({Title="Items", Desc="Search and pick one or more", Flag="SpawnItems",
    Values=SpawnLabels, Value={}, Multi=true, AllowNone=true, SearchBarEnabled=true, MenuWidth=260,
    Callback=function(v)
        if type(v) ~= "table" then v = {v} end
        spawnSelection = v
    end})
SpawnSub:Slider({Title="Amount", Desc="Per selected item", Flag="SpawnAmount",
    Value={Min=1, Max=100, Default=1},
    Callback=function(v) spawnAmount = v end})
SpawnSub:Button({Title="Spawn Selected", Icon="plus-circle",
    Callback=function()
        if #spawnSelection == 0 then
            notify("Nothing selected", "Pick at least one item first.", "alert-triangle", 3)
            return
        end
        local n = 0
        for _, label in ipairs(spawnSelection) do
            local id = SpawnIdByLabel[label]
            if id and spawnItem(id, spawnAmount) then n += 1 end
        end
        if n > 0 then
            notify("Spawned", string.format("%d item(s) x %d each", n, spawnAmount), "check-circle", 3)
        end
    end})
SpawnSub:Button({Title="Open In Crate", Desc="Plays the crate opening animation for each selected item", Icon="package-open",
    Callback=function()
        if #spawnSelection == 0 then
            notify("Nothing selected", "Pick at least one item first.", "alert-triangle", 3)
            return
        end
        task.spawn(function()
            for _, label in ipairs(spawnSelection) do
                local id = SpawnIdByLabel[label]
                if id then openCrateVisual(id) end
                task.wait(0.05)
            end
        end)
    end})

end
do
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
                    WindUI:Notify({Title="Kill All", Content="You need a knife (be Murderer)!", Icon="circle-x", Duration=3})
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

end
do
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
SettTheme:Keybind({Title="Toggle UI", Desc="Open / close the menu", Value="RightShift",
    Callback=function(v)
        pcall(function() Window:SetToggleKey(Enum.KeyCode[v]) end)
    end})
SettTheme:Dropdown({Title="Theme", Desc="Halloween has gradient text", Flag="ThemeDropdown",
    Values={"Halloween","Dark"}, Value="Halloween",
    Callback=function(v) pcall(function() WindUI:SetTheme(v) end) end})
SettTheme:Toggle({Title="Transparency", Desc="Semi-transparent interface",
    Flag="UiTransparencyToggle", Value=false,
    Callback=function(v) pcall(function() Window:ToggleTransparency(v) end) end})

SettTab:Space()

-- Action keybinds: all unbound until the player picks a key
local SettKeybinds = SettTab:Section({Title="Keybinds", Desc="All unbound by default. Click one and press a key to set it.", Opened=true})
local Keybinds = {
    GrabGun    = "None",
    KillAll    = "None",
    ThrowKnife = "None",
    ShootMurd  = "None",
    SilentAim  = "None",
    FlingMurd  = "None",
}
local KeybindActions = {
    GrabGun    = function() Modules.GrabGun() end,
    KillAll    = function() killEveryone() end,
    ThrowKnife = function() Modules.ExecuteThrowAtNearest() end,
    ShootMurd  = function() Modules.ShootMurdererOnce() end,
    SilentAim  = function() Modules.ShootMurdererSilent() end,
    FlingMurd  = function()
        local m = Modules.FindMurderer()
        if m and m ~= LocalPlayer then miniFling({m.Name}) end
    end,
}
local function bindRow(id, title, desc)
    SettKeybinds:Keybind({Title=title, Desc=desc, Value="None", Flag="Key_"..id,
        Callback=function(v) Keybinds[id] = v end})
end
bindRow("GrabGun",    "Pick Up Gun",     "Grab the dropped gun")
bindRow("KillAll",    "Kill Everyone",   "Murderer only")
bindRow("ThrowKnife", "Throw Knife",     "At the nearest player")
bindRow("ShootMurd",  "Shoot Murderer",  "Sheriff only")
bindRow("SilentAim",  "Toggle Silent Aim", "Redirect manual shots")
bindRow("FlingMurd",  "Fling Murderer",  "Fling the murderer")

AddConnection(UserInputService.InputBegan:Connect(function(inp, gpe)
    if gpe or inp.UserInputType ~= Enum.UserInputType.Keyboard then return end
    local keyName = inp.KeyCode.Name
    for id, key in pairs(Keybinds) do
        if key ~= "None" and key ~= "" and key == keyName then
            task.spawn(function() pcall(KeybindActions[id]) end)
        end
    end
end))

SettTab:Space()

local BorderSub = SettTab:Section({Title="Border", Opened=true})
BorderSub:Colorpicker({Title="Border Color", Value=Color3.fromRGB(255,115,0),
    Callback=function(v)
        borderColor=v
        applyBorderColor()
        if getgenv().mm2PillStroke then getgenv().mm2PillStroke.Color=v end
    end})
BorderSub:Slider({Title="Border Thickness", Value={Min=1,Max=12,Default=3}, Step=1,
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

end
-- ============================================================
-- SELECT FIRST TAB (Vision Hub pattern)
-- ============================================================
Window:SelectTab(1)

-- ============================================================
-- TOGGLE KEY
-- ============================================================
Window:SetToggleKey(Enum.KeyCode.RightShift)


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
-- BORDER (orange UIStroke on WindUI's rounded inner Main frame)
-- ============================================================
task.spawn(function()
    local target
    for _ = 1, 40 do
        local outer = Window.UIElements and Window.UIElements.Main
        target = outer and (outer:FindFirstChild("Main") or outer)
        if target then break end
        task.wait(0.25)
    end
    if not target then return end
    if not target:FindFirstChildOfClass("UICorner") then
        Instance.new("UICorner", target).CornerRadius = UDim.new(0, 16)
    end
    local old = target:FindFirstChild("GhostBorder")
    if old then old:Destroy() end
    _borderStroke = Instance.new("UIStroke")
    _borderStroke.Name            = "GhostBorder"
    _borderStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    _borderStroke.LineJoinMode    = Enum.LineJoinMode.Round
    _borderStroke.Thickness       = borderThickness
    _borderStroke.Color           = Color3.new(1, 1, 1)
    _borderStroke.Transparency    = 0
    _borderStroke.Parent          = target
    _borderGradient = Instance.new("UIGradient")
    _borderGradient.Parent = _borderStroke
    applyBorderColor()
    task.spawn(function()
        local spin = 0
        while _borderGradient and _borderGradient.Parent do
            spin = (spin + RunService.Heartbeat:Wait() * 60) % 360
            _borderGradient.Rotation = spin
        end
    end)

    -- slow shimmer across the gradient title text
    task.spawn(function()
        task.wait(1)
        for _, obj in ipairs(Window.UIElements.Main:GetDescendants()) do
            if obj:IsA("TextLabel") and obj.Text == "Zovlane Hub" then
                local g = obj:FindFirstChild("LibraryGradient")
                if g then
                    g.Offset = Vector2.new(-0.35, 0)
                    TweenService:Create(g, TweenInfo.new(2.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
                        Offset = Vector2.new(0.35, 0),
                    }):Play()
                end
            end
        end
    end)

    local oldPumpkin = target:FindFirstChild("GhostPumpkin")
    if oldPumpkin then oldPumpkin:Destroy() end
    local pumpkin = Instance.new("TextLabel")
    pumpkin.Name                   = "GhostPumpkin"
    pumpkin.Text                   = "\u{1F383}"
    pumpkin.BackgroundTransparency = 1
    pumpkin.TextScaled             = true
    pumpkin.Size                   = UDim2.fromOffset(42, 42)
    pumpkin.AnchorPoint            = Vector2.new(0.5, 0.5)
    pumpkin.Position               = UDim2.new(1, 2, 0, 4)
    pumpkin.Rotation               = -12
    pumpkin.ZIndex                 = 500
    pumpkin.Parent                 = target
    TweenService:Create(pumpkin, TweenInfo.new(1.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
        Rotation = 12,
        Position = UDim2.new(1, 2, 0, -2),
    }):Play()
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
