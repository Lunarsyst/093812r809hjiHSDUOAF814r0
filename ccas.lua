------------------------------------------------------------
-- PLACE CHECK
------------------------------------------------------------
if game.PlaceId ~= 328028363 then
    game:GetService("Players").LocalPlayer:Kick("[Aegis] join tc2 jittleyang")
    return
end

if setthreadidentity then setthreadidentity(8) end

------------------------------------------------------------
-- ANTICHEAT BYPASS (blocks NewLoader before anything loads)
------------------------------------------------------------
do
    local _RS  = game:GetService("RunService")
    local _Rep = game:GetService("ReplicatedStorage")
    local _LP  = game:GetService("Players").LocalPlayer or game:GetService("Players").PlayerAdded:Wait()
    -- Wait for TC2 to finish server setup before hooking
    repeat _RS.Heartbeat:Wait()
    until _Rep:GetAttribute("sv_setup") and _LP:GetAttribute("FillMeIn")
    _RS.Heartbeat:Wait()

    local _timeout   = 0
    local _done      = false
    local _old
    _old = hookmetamethod(game, "__namecall", newcclosure(function(...)
        if getcallingscript() and getcallingscript().Name == "NewLoader" then
            _done = true
            error("NewLoader thread terminated by Aegis")
        end
        return _old(...)
    end))
    local _tc = _RS.Heartbeat:Connect(function(dt)
        _timeout += dt
        if _timeout >= 5 then _done = true end
    end)
    repeat _RS.Heartbeat:Wait() until _done
    _tc:Disconnect()
    task.wait(1.5)
    hookmetamethod(game, "__namecall", _old)
end


------------------------------------------------------------
-- LIBRARY
------------------------------------------------------------
local repo        = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/"
local Library     = loadstring(game:HttpGet(repo .. "Library.lua"))()
local ThemeManager = loadstring(game:HttpGet(repo .. "addons/ThemeManager.lua"))()
local SaveManager  = loadstring(game:HttpGet(repo .. "addons/SaveManager.lua"))()

local Options = Library.Options
local Toggles = Library.Toggles

Library.ShowToggleFrameInKeybinds = true

------------------------------------------------------------
-- CHEATER LIST (external loadstring)
-- The linked script should set:
--   getgenv().AegisCheaterList = { [userId] = "DisplayName", ... }
-- If the link hasn't been set yet, this is a no-op.
------------------------------------------------------------
do
    local CHEATER_LIST_URL = "https://raw.githubusercontent.com/Lunarsyst/-3197-541/refs/heads/main/21398?token=GHSAT0AAAAAADWRVML2IKRWVD3EOHTPZ4662NCAY6A"
    if CHEATER_LIST_URL ~= "" then
        pcall(function() loadstring(game:HttpGet(CHEATER_LIST_URL))() end)
    end
end
-- AegisCheaterList is now either set by the above loadstring or nil.
local CheaterList = getgenv().AegisCheaterList or {}

local function IsCheater(player)
    return CheaterList[player.UserId] ~= nil
end

------------------------------------------------------------
-- SERVICES
------------------------------------------------------------
local Players            = game:GetService("Players")
local RunService         = game:GetService("RunService")
local UserInputService   = game:GetService("UserInputService")
local Lighting           = game:GetService("Lighting")
local Workspace          = game:GetService("Workspace")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local VirtualInputManager = game:GetService("VirtualInputManager")
local Stats              = game:GetService("Stats")
local LogService         = game:GetService("LogService")

------------------------------------------------------------
-- WEAPON VALUE SNAPSHOT (for Gun Mod restores)
------------------------------------------------------------
local WeaponSnapshot = {}
task.spawn(function()
    task.wait(2)
    pcall(function()
        for _, wep in pairs(ReplicatedStorage.Weapons:GetChildren()) do
            WeaponSnapshot[wep.Name] = {}
            for _, child in pairs(wep:GetChildren()) do
                if child:IsA("ValueBase") then
                    WeaponSnapshot[wep.Name][child.Name] = child.Value
                end
            end
        end
    end)
end)


local Camera      = Workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

local isMobileDevice = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

------------------------------------------------------------
-- AEGIS STATUS (attribute handshake)
------------------------------------------------------------
local AEGIS_ATTR = "_rbxint"
local AegisUserCache = {}  -- [player] = true

local function StampAegisCharacter(char)
    if not char then return end
    pcall(function() char:SetAttribute(AEGIS_ATTR, true) end)
end
local isMobileMode   = false

------------------------------------------------------------
-- CONSTANTS
------------------------------------------------------------
local BACKSTAB_RANGE         = 7.5
local MELEE_RANGE_RAGE       = 7.5
local MELEE_RANGE_DEMOKNIGHT = 9
local TC2_GRAVITY            = 50
local TC2_JUMP_POWER         = 16
local PROJECTILE_OFFSET      = Vector3.new(0.32, -0.14, -0.56)
local SIM_PARAMS_CACHE_TTL   = 0.5

------------------------------------------------------------
-- CACHED PLAYER LIST
-- Rebuilt only on join/leave, never per-frame
------------------------------------------------------------
local cachedPlayerList = {}
do
    for _, p in ipairs(Players:GetPlayers()) do table.insert(cachedPlayerList, p) end
    Players.PlayerAdded:Connect(function(p)
        table.insert(cachedPlayerList, p)
    end)
    Players.PlayerRemoving:Connect(function(p)
        for i = #cachedPlayerList, 1, -1 do
            if cachedPlayerList[i] == p then table.remove(cachedPlayerList, i) end
        end
    end)
end

------------------------------------------------------------
-- STATE
------------------------------------------------------------
local S = {
    charlieKirk = false,
    shooting = false, lastShotTime = 0, shotInterval = 0.033,
    lastHitTime = 0, hitCooldown = 0.1,
    jitterDir = 1, spinAngle = 0, lastJitterUpdate = 0,
    fps = 0, frames = 0,
    chargeStartTime = 0, isCharging = false, currentChargePercent = 0,
    lastAgentNotif = 0,
    silentAimKeyActive = false,
    warpActive = false, lastWarpTime = 0, lastBackstabTarget = nil,
    lastWorldChamsUpdate = 0, lastProjChamsUpdate = 0,
    lastUsernameUpdate = 0, lastVelocityUpdate = 0, lastHitDebugNotif = 0,
    lastAirblastTime = 0,
    noSpreadSetup = false, speedConnection = nil,
    _guiLoaded = false,
    ads = nil, adsmodifier = nil, equipped = nil, kirk = nil, ClassValue = nil,
    mobileToggleButton = nil,
    armTarget = nil, armHoldStart = nil, armReturning = false,
    armReturnStart = nil, armOriginalCF = nil,
    lastMeleeTarget = nil,
    simRayParamsCache = nil, simRayParamsCacheTime = 0,

}

local healthCache         = {}
local visibilityCache     = {}
local playerVelocities    = {}
local playerAccelerations = {}
local playerVerticalHistory  = {}
local playerStrafeHistory    = {}
local playerPositionHistory  = {}
local cachedSentries     = {}
local cachedDispensers   = {}
local cachedTeleporters  = {}
local cachedAmmo         = {}
local cachedHP           = {}
-- Chams cache keyed on player (not char) so respawns don't cause stale entries
local PlayerChamsCache   = {}  -- [player] = { hl=Highlight, char=Model }
local lastChamsProps     = {}  -- [player] = { fc, oc, ft, ot, dm }
local WorldChamsCache    = {}
local ProjectileChamsCache = {}

local FrameCache = {
    playerData = nil,
    silentTarget = nil, silentTargetPlr = nil,
    camPos = Vector3.zero, camCF = CFrame.new(),
    screenCenter = Vector2.new(),
    frameNum = 0,
}

------------------------------------------------------------
-- FREECAM DUMMY
------------------------------------------------------------
task.spawn(function()
    local function EnsureFreecamDummy()
        pcall(function()
            local pg = LocalPlayer:FindFirstChild("PlayerGui"); if not pg then return end
            if not pg:FindFirstChild("FreecamScript") then
                local d = Instance.new("LocalScript"); d.Name = "FreecamScript"; d.Disabled = true; d.Parent = pg
            end
        end)
    end
    EnsureFreecamDummy()
    LocalPlayer.CharacterAdded:Connect(function() task.wait(0.5); EnsureFreecamDummy() end)
    while true do task.wait(5); if Library.Unloaded then break end; EnsureFreecamDummy() end
end)

------------------------------------------------------------
-- GUI LOADER
------------------------------------------------------------
local function EnsureGUILoaded()
    if S._guiLoaded then return true end
    pcall(function()
        local PG = LocalPlayer:FindFirstChild("PlayerGui"); if not PG then return end
        local G = PG:FindFirstChild("GUI"); if not G then return end
        local C = G:FindFirstChild("Client"); if not C then return end
        local L = C:FindFirstChild("LegacyLocalVariables"); if not L then return end
        S.ads = L:FindFirstChild("ads"); S.adsmodifier = L:FindFirstChild("adsmodifier")
        S.equipped = L:FindFirstChild("equipped"); S.kirk = L:FindFirstChild("currentspread")
        local St = LocalPlayer:FindFirstChild("Status")
        if St then S.ClassValue = St:FindFirstChild("Class") end
        if S.ads and S.adsmodifier and S.equipped and S.kirk and S.ClassValue then S._guiLoaded = true end
    end)
    return S._guiLoaded
end

local function RightClick()
    pcall(function()
        local L = LocalPlayer.PlayerGui.GUI.Client.LegacyLocalVariables
        L.Held2.Value = true; task.wait(0.05); L.Held2.Value = false
    end)
end

------------------------------------------------------------
-- DATA TABLES
------------------------------------------------------------
local HitboxTables = {
    Head  = {"Head","HeadHB"},
    Chest = {"UpperTorso","HumanoidRootPart"},
    Torso = {"LowerTorso"},
    Arms  = {"LeftLowerArm","RightLowerArm","LeftUpperArm","RightUpperArm","LeftHand","RightHand"},
    Legs  = {"LeftLowerLeg","RightLowerLeg","LeftUpperLeg","RightUpperLeg"},
    Feet  = {"LeftFoot","RightFoot"},
}

local SkeletonConnections = {
    {"Head","UpperTorso"},{"UpperTorso","LowerTorso"},
    {"UpperTorso","LeftUpperArm"},{"LeftUpperArm","LeftLowerArm"},{"LeftLowerArm","LeftHand"},
    {"UpperTorso","RightUpperArm"},{"RightUpperArm","RightLowerArm"},{"RightLowerArm","RightHand"},
    {"LowerTorso","LeftUpperLeg"},{"LeftUpperLeg","LeftLowerLeg"},{"LeftLowerLeg","LeftFoot"},
    {"LowerTorso","RightUpperLeg"},{"RightUpperLeg","RightLowerLeg"},{"RightLowerLeg","RightFoot"},
}

local ProjectileWeapons = {
    ["Direct Hit"]       = {Speed=123.75, Gravity=0,    InitialAngle=0,    Lifetime=99,  Type="Rocket"},
    ["Maverick"]         = {Speed=64.75,  Gravity=15,   InitialAngle=0,    Lifetime=99,  Type="Rocket"},
    ["Rocket Launcher"]  = {Speed=64.75,  Gravity=0,    InitialAngle=0,    Lifetime=99,  Type="Rocket"},
    ["Double Trouble"]   = {Speed=64.75,  Gravity=0,    InitialAngle=0,    Lifetime=99,  Type="Rocket"},
    ["Blackbox"]         = {Speed=68.75,  Gravity=0,    InitialAngle=0,    Lifetime=99,  Type="Rocket"},
    ["Original"]         = {Speed=68.75,  Gravity=0,    InitialAngle=0,    Lifetime=99,  Type="Rocket"},
    ["Cow Mangler 5000"] = {Speed=64.75,  Gravity=0,    InitialAngle=0,    Lifetime=99,  Type="Rocket"},
    ["Wreckers Yard"]    = {Speed=64.75,  Gravity=0,    InitialAngle=0,    Lifetime=99,  Type="Rocket"},
    ["G-Bomb"]           = {Speed=44.6875,Gravity=0,    InitialAngle=0,    Lifetime=99,  Type="Rocket"},
    ["Airstrike"]        = {Speed=64.75,  Gravity=0,    InitialAngle=0,    Lifetime=99,  Type="Rocket", AirSpeed=110},
    ["Liberty Launcher"] = {Speed=96.25,  Gravity=0,    InitialAngle=0,    Lifetime=99,  Type="Rocket"},
    ["Grenade Launcher"] = {Speed=76,     Gravity=42.6, InitialAngle=7.92, Lifetime=0.8, Type="Grenade"},
    ["Ultimatum"]        = {Speed=76,     Gravity=42.6, InitialAngle=7.92, Lifetime=0.8, Type="Grenade"},
    ["Iron Bomber"]      = {Speed=76,     Gravity=42.6, InitialAngle=7.92, Lifetime=0.8, Type="Grenade"},
    ["Loose Cannon"]     = {Speed=76,     Gravity=42.6, InitialAngle=7.92, Lifetime=0.8, Type="Grenade"},
    ["Loch-n-Load"]      = {Speed=96,     Gravity=42.6, InitialAngle=5.412,Lifetime=99,  Type="Grenade"},
    ["Syringe Crossbow"] = {Speed=125,    Gravity=3,    InitialAngle=0,    Lifetime=99,  Type="Syringe"},
    ["Milk Pistol"]      = {Speed=100,    Gravity=3,    InitialAngle=0,    Lifetime=99,  Type="Grenade"},
    ["Flare Gun"]        = {Speed=125,    Gravity=10,   InitialAngle=0,    Lifetime=99,  Type="Flare"},
    ["Detonator"]        = {Speed=125,    Gravity=10,   InitialAngle=0,    Lifetime=99,  Type="Flare"},
    ["Rescue Ranger"]    = {Speed=150,    Gravity=3,    InitialAngle=0,    Lifetime=99,  Type="Syringe"},
    ["Apollo"]           = {Speed=125,    Gravity=3,    InitialAngle=0,    Lifetime=99,  Type="Syringe"},
    ["Big Bite"]         = {Speed=64.75,  Gravity=0,    InitialAngle=0,    Lifetime=99,  Type="Rocket"},
    ["Night Sky Ignitor"]= {Speed=123.75, Gravity=0,    InitialAngle=0,    Lifetime=99,  Type="Rocket"},
    ["Twin-Turbolence"]  = {Speed=76,     Gravity=42.6, InitialAngle=7.92, Lifetime=0.8, Type="Grenade"},
}

local ChargeWeapons = {
    ["Huntsman"] = {SpeedMin=113.25, SpeedMax=162.5, GravityMin=24.8, GravityMax=5.0,
                    Gravity=24.8, InitialAngle=0, ChargeTime=1.0, Lifetime=99, Type="Arrow"},
}

local BackstabWeapons = {
    ["Knife"]=true,["Conniver's Kunai"]=true,["Your Eternal Reward"]=true,
    ["Icicle"]=true,["Swift Stiletto"]=true,["Wraith"]=true,["Big Earner"]=true,
    ["Spy-cicle"]=true,["Wanga Prick"]=true,["Karambit"]=true,["Golden Knife"]=true,
}

local MeleeWeapons = {
    ["Fist"]=true,["Ice Dagger"]=true,["Linked Sword"]=true,["Mummy Staff"]=true,
    ["Rapier"]=true,["Wrecking Ball"]=true,["Le Executeur"]=true,["Pirate Cutlass"]=true,
    ["Warrior's Spirit"]=true,["Pain Train"]=true,["Icicle"]=true,["Mummy Sword"]=true,
    ["Skeleton Scythe"]=true,["Rally Racket"]=true,["Eviction Notice"]=true,
    ["Conscientious Objector"]=true,["Gunslinger"]=true,["Slash n' Burn"]=true,
    ["Doll Maker"]=true,["Three Rune Blade"]=true,["Equalizer"]=true,
    ["Golden Wrench"]=true,["Southern Hospitality"]=true,["Elegant Blade"]=true,
    ["Homewrecker"]=true,["Rising Sun Katana"]=true,["Caber"]=true,
    ["Rubber Chicken"]=true,["Holy Mackerel"]=true,["Sandman"]=true,
    ["Golden Frying Pan"]=true,["Frying Pan"]=true,["Tribalman's Shiv"]=true,
    ["Market Gardener"]=true,["Market Gardener2"]=true,["Atomizer"]=true,
    ["Katana"]=true,["Golf Club"]=true,["Skeleton Bat"]=true,["Six Point Shuriken"]=true,
    ["Fan O' War"]=true,["Wrap Assassin"]=true,["Shahanshah"]=true,
    ["Candy Cane"]=true,["Fists of Steel"]=true,["Scotsman's Skullcutter"]=true,
    ["Brooklyn Basher"]=true,["Supersaw"]=true,["Pestilence Poker"]=true,
    ["Amputator"]=true,["Big Earner"]=true,["Holiday Punch"]=true,
    ["Prop Handle"]=true,["Trowel"]=true,["Bat"]=true,["Broken Sword"]=true,
    ["Crowbar"]=true,["Fire Extinguisher"]=true,["Fists"]=true,["Knife"]=true,
    ["Saw"]=true,["Wrench"]=true,["Machete"]=true,["The Black Death"]=true,["Eyelander"]=true,
}

local BlacklistedWeapons = {
    ["Sticky Jumper"]=true,["Rocket Jumper"]=true,["Overdrive"]=true,
    ["The Mercy Kill"]=true,["Friendly Fire Foiler"]=true,
    ["Buff Banner"]=true,["Battalion's Backup"]=true,["Concheror"]=true,
    ["Battle Burrito"]=true,["Dire Donut"]=true,["Tenacious Turkey"]=true,
    ["Robar"]=true,["Special-ops Sushi"]=true,["Blood Doctor"]=true,
    ["Kritzkrieg"]=true,["Rejuvenator"]=true,["The Vaccinator"]=true,
    ["Medigun"]=true,["Radius Scanner"]=true,["Slow Burn"]=true,["Spy Camera"]=true,
    ["Stray Reflex"]=true,["Sapper"]=true,["Disguise Kit"]=true,["Jarate"]=true,
    ["Mad Milk"]=true,["Witches Brew"]=true,["Bloxy Cola"]=true,
}

local projectileNames = {
    "Bauble","Shuriken","Rocket","Grenade","Arrow_Syringe","Sentry Rocket",
    "Arrow","Flare Gun","Baseball","Snowballs","Milk Pistol",
}

-- Rainbow color helper for Ubercharged status
local function GetRainbowColor()
    local t = tick() * 1.5  -- speed
    local h = t % 1
    local r, g, b
    local i = math.floor(h * 6)
    local f = h * 6 - i
    local q = 1 - f
    if     i % 6 == 0 then r,g,b = 1,f,0
    elseif i % 6 == 1 then r,g,b = q,1,0
    elseif i % 6 == 2 then r,g,b = 0,1,f
    elseif i % 6 == 3 then r,g,b = 0,q,1
    elseif i % 6 == 4 then r,g,b = f,0,1
    else                    r,g,b = 1,0,q end
    return Color3.new(r,g,b)
end

-- Status effects from workspace.PlayerName.Conditions attributes
-- Matches exactly what TC2 uses (confirmed via screenshot)
local StatusLetters = {
    Bleeding    = {Letter="B",  Color=Color3.fromRGB(255,50,50)},
    Cloaked     = {Letter="C",  Color=Color3.fromRGB(150,150,255)},
    Coated      = {Letter="Co", Color=Color3.fromRGB(180,100,255)},
    Engulfed    = {Letter="E",  Color=Color3.fromRGB(255,150,0)},
    Lemoned     = {Letter="L",  Color=Color3.fromRGB(255,255,0)},
    Milked      = {Letter="M",  Color=Color3.fromRGB(230,230,230)},
    Poisoned    = {Letter="P",  Color=Color3.fromRGB(100,200,50)},
    Ubercharged = {Letter="U",  Color=Color3.fromRGB(255,215,0)},
}

------------------------------------------------------------
-- CONFIG
------------------------------------------------------------
getgenv().Config = {
    SilentAim     = {Enabled=false, FOV=200},
    AntiAim       = {Enabled=false, Mode="jitter", JitterAngle=90, JitterSpeed=15, AntiAimSpeed=180},
    Wallbang      = {Enable=false},
    NoSpread      = {Enable=false, Multiplier=0.2},
    Speed         = {Enable=false, Value=300},
    Notifications = {ShowHits=false},
    Flags         = {Enabled=false, ShowDamage=false, ShowRemainingHealth=false, ShowName=false},
    AutoUber      = {Enabled=false, HealthPercent=40, Condition="Both"},
}

------------------------------------------------------------
-- WINDOW & TABS
------------------------------------------------------------
local Window = Library:CreateWindow({
    Title = "Aegis",
    Footer = "aegis.dev | it's the weekend!",
    NotifySide = "Right",
    ShowCustomCursor = true,
})

local Tabs = {
    Aimbot        = Window:AddTab("Aimbot",   "crosshair"),
    Visuals       = Window:AddTab("Visuals",  "eye"),
    Misc          = Window:AddTab("Misc",     "wrench"),
    Exploits      = Window:AddTab("Exploits", "zap"),
    Settings      = Window:AddTab("Settings", "sliders-horizontal"),
    ["UI Settings"] = Window:AddTab("UI",     "settings"),
}

------------------------------------------------------------
-- NOTIFY HELPER
------------------------------------------------------------
local function Notify(msg, duration)
    Library:Notify({ Title="Aegis", Description=tostring(msg), Time=duration or 3 })
end

------------------------------------------------------------
-- UTILITY
------------------------------------------------------------
local function GetCharacter(p)    return p and p.Character end
local function GetHumanoid(c)     return c and c:FindFirstChildOfClass("Humanoid") end
local function GetHRP(c)          return c and c:FindFirstChild("HumanoidRootPart") end
local function GetLocalCharacter() return GetCharacter(LocalPlayer) end

local function IsPlayerAlive(p)
    local c = p and p.Character
    local h = c and c:FindFirstChildOfClass("Humanoid")
    return h and h.Health > 0
end

local function IsEnemy(p)  return p and p.Team ~= LocalPlayer.Team end
local function IsFriend(p)
    local ok, r = pcall(function() return LocalPlayer:IsFriendsWith(p.UserId) end)
    return ok and r
end

local function WorldToViewportPoint(pos)
    local ok, sp, os = pcall(function() return Camera:WorldToViewportPoint(pos) end)
    if not ok or not sp then return Vector2.new(0,0), false, 0 end
    return Vector2.new(sp.X, sp.Y), os, sp.Z
end

------------------------------------------------------------
-- VISIBILITY (with early-exit dot product to skip off-screen raycasts)
------------------------------------------------------------
local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
raycastParams.IgnoreWater = true

local function IsPartVisible(part)
    if not part then return false end
    if visibilityCache[part] ~= nil then return visibilityCache[part] end
    -- Skip raycast entirely if part is behind camera (~100° off screen)
    local toDir = part.Position - FrameCache.camPos
    if toDir.Magnitude > 0.1 and FrameCache.camCF.LookVector:Dot(toDir.Unit) < -0.17 then
        visibilityCache[part] = false; return false
    end
    local lc = GetLocalCharacter(); if not lc then return false end
    raycastParams.FilterDescendantsInstances = {lc}
    local result = Workspace:Raycast(FrameCache.camPos, toDir, raycastParams)
    local vis = not result or result.Instance:IsDescendantOf(part.Parent)
    visibilityCache[part] = vis
    return vis
end

local function IsCharacterVisible(char)
    local hrp = GetHRP(char); return hrp and IsPartVisible(hrp)
end

local function IsCharacterInvisible(char)
    local head = char and char:FindFirstChild("Head")
    return head and head.Transparency > 0.9
end

------------------------------------------------------------
-- REACH CHECK (used by melee/backstab to verify LOS)
------------------------------------------------------------
local function HasLineOfSight(fromPos, toPos)
    local rp = RaycastParams.new()
    rp.FilterType = Enum.RaycastFilterType.Blacklist
    rp.IgnoreWater = true
    local lc = GetLocalCharacter()
    rp.FilterDescendantsInstances = lc and {lc} or {}
    local dir = toPos - fromPos
    local hit = Workspace:Raycast(fromPos, dir, rp)
    return not hit or (hit.Position - fromPos).Magnitude >= dir.Magnitude - 1
end

------------------------------------------------------------
-- GetBestVisiblePart (fixed — no fallback, sort from dropdown)
------------------------------------------------------------
local function GetBestVisiblePart(char, selectedGroups, sortMode)
    if not char or char == LocalPlayer.Character then return nil end
    sortMode = sortMode or "Closest to Mouse"

    local candidates = {}
    for _, groupName in ipairs({"Head","Chest","Torso","Arms","Legs","Feet"}) do
        if selectedGroups[groupName] then
            for _, partName in ipairs(HitboxTables[groupName] or {}) do
                local p = char:FindFirstChild(partName)
                if p and IsPartVisible(p) then table.insert(candidates, p) end
            end
        end
    end
    if #candidates == 0 then return nil end

    if sortMode == "Closest to Mouse" then
        local best, bestDist = nil, math.huge
        for _, p in ipairs(candidates) do
            local sp, onScreen = WorldToViewportPoint(p.Position)
            if onScreen then
                local d = (sp - FrameCache.screenCenter).Magnitude
                if d < bestDist then bestDist = d; best = p end
            end
        end
        return best
    else
        local best, bestDist = nil, math.huge
        for _, p in ipairs(candidates) do
            local d = (FrameCache.camPos - p.Position).Magnitude
            if d < bestDist then bestDist = d; best = p end
        end
        return best
    end
end

------------------------------------------------------------
-- PLAYER INFO HELPERS
------------------------------------------------------------
local function GetPlayerClass(p)
    local st = p:FindFirstChild("Status")
    if st then local c = st:FindFirstChild("Class"); if c then return tostring(c.Value) end end
    return "Unknown"
end

-- Read MaxHealth directly from workspace character, fallback to humanoid MaxHealth
local function GetPlayerMaxHP(player)
    local ok, val = pcall(function()
        return Workspace[player.Name].MaxHealth.Value
    end)
    if ok and val and val > 0 then return val end
    local char = player.Character
    if char then
        local hum = GetHumanoid(char); if hum then return hum.MaxHealth end
    end
    return 150
end

local function GetPlayerWeapon(char)
    if not char then return "Unknown" end
    local g = char:FindFirstChild("Gun")
    if g then local b = g:FindFirstChild("Boop"); if b then return tostring(b.Value) end end
    return "Unknown"
end

local function GetLocalWeapon()  return GetPlayerWeapon(GetLocalCharacter()) end

local function GetLocalClass()
    if not EnsureGUILoaded() then return "Unknown" end
    return S.ClassValue and tostring(S.ClassValue.Value) or "Unknown"
end

local function GetPing()
    local p = 0; pcall(function() p = Stats.Network.ServerStatsItem["Data Ping"]:GetValue() end)
    return math.max(p / 1000, 0.05)
end

-- Use workspace MasterControlState / isAirborne for accurate ground state
local function IsOnGround(char)
    if not char then return false end
    local wsChar = Workspace:FindFirstChild(char.Name)
    if wsChar then
        local mcs = wsChar:GetAttribute("MasterControlState")
        if mcs then return mcs == "Grounded" end
        local airborne = wsChar:GetAttribute("isAirborne")
        if airborne ~= nil then return not airborne end
    end
    local hum = GetHumanoid(char)
    return hum and hum.FloorMaterial ~= Enum.Material.Air
end

-- Ground check for local player
local function IsLocalGrounded()
    local wsChar = Workspace:FindFirstChild(LocalPlayer.Name)
    if wsChar then
        local mcs = wsChar:GetAttribute("MasterControlState")
        if mcs then return mcs == "Grounded" end
        local airborne = wsChar:GetAttribute("isAirborne")
        if airborne ~= nil then return not airborne end
    end
    local char = GetLocalCharacter()
    if char then
        local hum = GetHumanoid(char)
        return hum and hum.FloorMaterial ~= Enum.Material.Air
    end
    return true
end

local function IsRocketJumped()
    local lc = GetLocalCharacter(); if not lc then return false end
    return lc:FindFirstChild("RocketJumped") ~= nil
end

-- Fixed: reads from workspace.CharName.Conditions, uses player.Character
local function GetPlayerModifiers(player)
    local mods = {}
    pcall(function()
        local char = player.Character; if not char then return end
        local conds = char:FindFirstChild("Conditions"); if not conds then return end
        for attrName in pairs(StatusLetters) do
            if conds:GetAttribute(attrName) == true then mods[attrName] = true end
        end
    end)
    return mods
end

local function IsPlayerFullHP(player)
    local char = player.Character; if not char then return true end
    local hum = GetHumanoid(char); if not hum then return true end
    return hum.Health >= GetPlayerMaxHP(player)
end

local function IsSyringeWeapon(weapon)
    return weapon == "Syringe Crossbow" or weapon == "Apollo"
end

------------------------------------------------------------
-- SIM RAY PARAMS (cached TTL, using cachedPlayerList)
------------------------------------------------------------
local function GetSimRayParams()
    local now = tick()
    if S.simRayParamsCache and (now - S.simRayParamsCacheTime) < SIM_PARAMS_CACHE_TTL then
        return S.simRayParamsCache
    end
    local rp = RaycastParams.new()
    rp.FilterType = Enum.RaycastFilterType.Blacklist
    rp.IgnoreWater = true
    local ignore = {}
    for _, p in ipairs(cachedPlayerList) do if p.Character then table.insert(ignore, p.Character) end end
    table.insert(ignore, Camera)
    rp.FilterDescendantsInstances = ignore
    S.simRayParamsCache = rp
    S.simRayParamsCacheTime = now
    return rp
end

------------------------------------------------------------
-- VELOCITY TRACKING (uses cachedPlayerList)
------------------------------------------------------------
local function UpdateVelocityTracking()
    local now = tick()
    if now - S.lastVelocityUpdate < 0.03 then return end
    for _, player in ipairs(cachedPlayerList) do
        if player == LocalPlayer then continue end
        local char = player.Character; if not char then continue end
        local hrp = GetHRP(char); if not hrp then continue end
        local vel = hrp.AssemblyLinearVelocity
        local pos = hrp.Position

        if not playerPositionHistory[player] then playerPositionHistory[player] = {} end
        table.insert(playerPositionHistory[player], {Pos=pos, Time=now})
        while #playerPositionHistory[player] > 20 do table.remove(playerPositionHistory[player], 1) end

        if not playerVerticalHistory[player] then playerVerticalHistory[player] = {} end
        table.insert(playerVerticalHistory[player], {Y=vel.Y, Time=now})
        while #playerVerticalHistory[player] > 15 do table.remove(playerVerticalHistory[player], 1) end

        local dt = now - S.lastVelocityUpdate
        if playerVelocities[player] then
            local prev = playerVelocities[player].Velocity
            local acc = (vel - prev) / math.max(dt, 0.001)
            acc = Vector3.new(math.clamp(acc.X,-80,80), math.clamp(acc.Y,-300,300), math.clamp(acc.Z,-80,80))
            playerAccelerations[player] = acc
        end
        playerVelocities[player] = {Velocity=vel, Time=now}

        local hVel = Vector3.new(vel.X, 0, vel.Z)
        if hVel.Magnitude > 1 then
            if not playerStrafeHistory[player] then playerStrafeHistory[player] = {} end
            table.insert(playerStrafeHistory[player], {Dir=hVel.Unit, Time=now})
            while #playerStrafeHistory[player] > 20 do table.remove(playerStrafeHistory[player], 1) end
        end
    end
    S.lastVelocityUpdate = now
end

local function GetPlayerVelocity(player)
    local d = playerVelocities[player]; if d then return d.Velocity end
    local char = player.Character
    if char then local hrp = GetHRP(char); if hrp then return hrp.AssemblyLinearVelocity end end
    return Vector3.zero
end

local function GetPlayerAcceleration(player) return playerAccelerations[player] or Vector3.zero end

local function GetPositionDerivedVelocity(player)
    local hist = playerPositionHistory[player]
    if not hist or #hist < 3 then return GetPlayerVelocity(player) end
    local recent = hist[#hist]; local older = hist[math.max(1, #hist-3)]
    local dt = recent.Time - older.Time
    if dt < 0.01 then return GetPlayerVelocity(player) end
    return (recent.Pos - older.Pos) / dt
end

local function IsVelocityStale(player)
    local hist = playerPositionHistory[player]
    if not hist or #hist < 5 then return false end
    local recent = hist[#hist]; local older = hist[math.max(1, #hist-5)]
    local dt = recent.Time - older.Time
    if dt < 0.25 then return false end
    return GetPlayerVelocity(player).Magnitude > 10 and (recent.Pos - older.Pos).Magnitude < 2
end

------------------------------------------------------------
-- MOVEMENT SIMULATION
------------------------------------------------------------
local function SimTraceGround(position, rp)
    local result = Workspace:Raycast(position + Vector3.new(0,3,0), Vector3.new(0,-200,0), rp)
    if result then return result.Position, result.Normal end
    return nil, nil
end

local function SimCheckWall(fromPos, toPos, rp)
    local dir = toPos - fromPos
    local hDir = Vector3.new(dir.X, 0, dir.Z)
    if hDir.Magnitude < 0.01 then return false, toPos end
    local feetCheck  = Workspace:Raycast(fromPos + Vector3.new(0,0.5,0), hDir, rp)
    local chestCheck = Workspace:Raycast(fromPos + Vector3.new(0,2,0),   hDir, rp)
    if feetCheck or chestCheck then
        local hit = feetCheck or chestCheck
        local stopPos = hit.Position + hit.Normal * 0.5
        return true, Vector3.new(stopPos.X, fromPos.Y, stopPos.Z)
    end
    return false, toPos
end

local function SimTraceSurface(fromPos, moveDir, distance, rp)
    if distance < 0.01 then return fromPos, false end
    local stepSize = 2; local numSteps = math.ceil(distance / stepSize); local currentPos = fromPos
    for i = 1, numSteps do
        local stepDist = math.min(stepSize, distance - (i-1)*stepSize)
        local nextPos = currentPos + moveDir * stepDist
        local blocked, stopPos = SimCheckWall(currentPos, nextPos, rp)
        if blocked then return stopPos, true end
        local groundPos, groundNormal = SimTraceGround(nextPos, rp)
        if groundPos then
            local slopeAngle = math.acos(math.clamp(groundNormal.Y, -1, 1))
            if slopeAngle < math.rad(60) then
                local heightDiff = groundPos.Y - currentPos.Y
                if heightDiff < 5 and heightDiff > -20 then
                    currentPos = groundPos + Vector3.new(0, 2.5, 0)
                else return currentPos, true end
            else currentPos = groundPos + Vector3.new(0, 2.5, 0) end
        else return nextPos, false end
    end
    return currentPos, false
end

local function SimulateTargetPosition(player, totalTime, steps, rp, wallCheck)
    steps = steps or 15
    rp = rp or GetSimRayParams()
    local char = player.Character; if not char then return nil end
    local hrp = GetHRP(char); if not hrp then return nil end

    local currentPos = hrp.Position
    local rawVel  = GetPlayerVelocity(player)
    local posVel  = GetPositionDerivedVelocity(player)
    local hRaw    = Vector3.new(rawVel.X, 0, rawVel.Z)
    local hPos    = Vector3.new(posVel.X, 0, posVel.Z)
    local hVel
    if hPos.Magnitude > 1 and (hPos - hRaw).Magnitude > 2 then
        hVel = hPos.Magnitude > 0.1 and hPos.Unit * math.max(hRaw.Magnitude, hPos.Magnitude) or hRaw
    else hVel = hRaw end
    if hVel.Magnitude > 80 then hVel = hVel.Unit * 80 end

    local vY = rawVel.Y
    local acceleration = GetPlayerAcceleration(player)
    local grounded    = IsOnGround(char)
    local timeStep    = totalTime / steps
    local simPos      = currentPos
    local simVelY     = vY
    local simGrounded = grounded
    local simHVel     = hVel
    local simStopped  = false
    local isJumping   = grounded and vY > TC2_JUMP_POWER * 0.5
    local lastValidPos = currentPos

    local wallRP
    if wallCheck then
        wallRP = RaycastParams.new()
        wallRP.FilterType = Enum.RaycastFilterType.Blacklist
        wallRP.IgnoreWater = true
        local wi = {}
        for _, p in ipairs(cachedPlayerList) do if p.Character then table.insert(wi, p.Character) end end
        table.insert(wi, Camera)
        wallRP.FilterDescendantsInstances = wi
    end

    for _ = 1, steps do
        if simStopped and simGrounded then continue end
        local t = timeStep
        local prevPos = simPos

        if simGrounded and not isJumping then
            if not simStopped then
                local hAcc    = Vector3.new(acceleration.X, 0, acceleration.Z)
                local stepVel = simHVel + hAcc * t * 0.3
                if stepVel.Magnitude > 80 then stepVel = stepVel.Unit * 80 end
                local moveDist = stepVel.Magnitude * t
                local moveDir  = stepVel.Magnitude > 0.1 and stepVel.Unit or Vector3.zero
                if moveDist > 0.01 then
                    local newPos, hitWall = SimTraceSurface(simPos, moveDir, moveDist, rp)
                    simPos = newPos
                    if hitWall then simStopped = true; simHVel = Vector3.zero else simHVel = stepVel end
                end
            end
            local gp = SimTraceGround(simPos, rp)
            if not gp or (simPos.Y - gp.Y) > 5 then
                simGrounded = false; simVelY = 0; simStopped = false
            end
        else
            if isJumping then simVelY = TC2_JUMP_POWER; simGrounded = false; isJumping = false end
            if not simStopped then
                local hAcc = Vector3.new(acceleration.X, 0, acceleration.Z)
                simHVel = simHVel + hAcc * t * 0.15
                if simHVel.Magnitude > 80 then simHVel = simHVel.Unit * 80 end
            end
            local hMove = simHVel * t; local newPos = simPos + hMove
            if hMove.Magnitude > 0.01 then
                local blocked, stopPos = SimCheckWall(simPos, newPos, rp)
                if blocked then newPos = stopPos; simHVel = Vector3.zero; simStopped = true end
            end
            local yMove = simVelY * t - 0.5 * TC2_GRAVITY * t * t
            simVelY = simVelY - TC2_GRAVITY * t
            newPos = Vector3.new(newPos.X, simPos.Y + yMove, newPos.Z)
            local groundPos = SimTraceGround(newPos, rp)
            if groundPos and newPos.Y <= groundPos.Y + 2.5 then
                newPos = Vector3.new(newPos.X, groundPos.Y + 2.5, newPos.Z); simGrounded = true; simVelY = 0
            end
            if yMove > 0 then
                local ceilCheck = Workspace:Raycast(simPos, Vector3.new(0, yMove+1, 0), rp)
                if ceilCheck then newPos = Vector3.new(newPos.X, ceilCheck.Position.Y-3, newPos.Z); simVelY = 0 end
            end
            simPos = newPos
        end

        if wallCheck and wallRP then
            local dir = simPos - prevPos
            if dir.Magnitude > 0.1 then
                local hit = Workspace:Raycast(prevPos, dir, wallRP)
                if hit then return lastValidPos end
            end
        end
        lastValidPos = simPos
    end

    local gp2 = SimTraceGround(simPos, rp)
    if gp2 and simPos.Y < gp2.Y + 2.5 then
        simPos = Vector3.new(simPos.X, gp2.Y + 2.5, simPos.Z)
    end
    return simPos
end

------------------------------------------------------------
-- OBJECT CACHING
------------------------------------------------------------
local function RefreshObjectCaches()
    cachedSentries = {}; cachedDispensers = {}; cachedTeleporters = {}
    for _, v in pairs(Workspace:GetChildren()) do
        if     v.Name:match("'s Sentry$")    then table.insert(cachedSentries,    v)
        elseif v.Name:match("'s Dispenser$") then table.insert(cachedDispensers,  v)
        elseif v.Name:match("'s Teleporter") then table.insert(cachedTeleporters, v) end
    end
    cachedAmmo = {}; cachedHP = {}
    local mi = Workspace:FindFirstChild("Map")
    if mi then
        local items = mi:FindFirstChild("Items"); if items then
            for _, v in pairs(items:GetChildren()) do
                if v.Name:match("Ammo") or v.Name == "DeadAmmo" then table.insert(cachedAmmo, v)
                elseif v.Name:match("HP") then table.insert(cachedHP, v) end
            end
        end
    end
end

local function removeFrom(t, c) for i = #t, 1, -1 do if t[i] == c then table.remove(t, i) end end end

do
    Workspace.ChildAdded:Connect(function(c) task.defer(function()
        if     c.Name:match("'s Sentry$")    then table.insert(cachedSentries,    c)
        elseif c.Name:match("'s Dispenser$") then table.insert(cachedDispensers,  c)
        elseif c.Name:match("'s Teleporter") then table.insert(cachedTeleporters, c) end
    end) end)
    Workspace.ChildRemoved:Connect(function(c) task.defer(function()
        removeFrom(cachedSentries, c); removeFrom(cachedDispensers, c); removeFrom(cachedTeleporters, c)
    end) end)
    task.spawn(function()
        task.wait(3); RefreshObjectCaches()
        while true do task.wait(30); if Library.Unloaded then break end; pcall(RefreshObjectCaches) end
    end)
    task.spawn(function()
        local mi = Workspace:WaitForChild("Map", 10); if not mi then return end
        local items = mi:FindFirstChild("Items"); if not items then return end
        items.ChildAdded:Connect(function(c) task.defer(function()
            if c.Name:match("Ammo") or c.Name == "DeadAmmo" then table.insert(cachedAmmo, c)
            elseif c.Name:match("HP") then table.insert(cachedHP, c) end
        end) end)
        items.ChildRemoved:Connect(function(c) task.defer(function()
            removeFrom(cachedAmmo, c); removeFrom(cachedHP, c)
        end) end)
    end)
end

local function GetMyStickybombs()
    local result = {}; local dest = Workspace:FindFirstChild("Destructable"); if not dest then return result end
    for _, v in pairs(dest:GetChildren()) do
        if v.Name:match(LocalPlayer.Name) and v.Name:match("stickybomb$") then
            local p = v:IsA("BasePart") and v or v:FindFirstChildWhichIsA("BasePart")
            if p then table.insert(result, v) end
        end
    end
    return result
end

local function GetProjectiles()
    local result = {}
    local ri = Workspace:FindFirstChild("Ray_ignore")
    if ri then for _, v in pairs(ri:GetChildren()) do
        for _, n in pairs(projectileNames) do
            if v.Name == n or v.Name:match("bomb$") then
                local pp = v:IsA("BasePart") and v or v:FindFirstChildWhichIsA("BasePart")
                if pp then table.insert(result, v) end; break
            end
        end
    end end
    local dest = Workspace:FindFirstChild("Destructable")
    if dest then for _, v in pairs(dest:GetChildren()) do
        if v.Name:match("stickybomb$") then
            local pp = v:IsA("BasePart") and v or v:FindFirstChildWhichIsA("BasePart")
            if pp then table.insert(result, v) end
        end
    end end
    return result
end

------------------------------------------------------------
-- CHARGE TRACKING
------------------------------------------------------------
UserInputService.InputBegan:Connect(function(input, processed)
    if processed or Library.Unloaded then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        local w = GetLocalWeapon()
        if ChargeWeapons[w] then S.isCharging = true; S.chargeStartTime = tick(); S.currentChargePercent = 0 end
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if Library.Unloaded then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1 then S.isCharging = false end
end)

local function GetCurrentWeaponSpeed(weaponName)
    if weaponName == "Airstrike" and IsRocketJumped() then return 110, 2, 0, 0, 99 end
    local cd = ChargeWeapons[weaponName]
    if cd then
        local cp = S.currentChargePercent
        local speed   = cd.SpeedMin + (cd.SpeedMax - cd.SpeedMin) * cp
        local gravity = cd.GravityMin - (cd.GravityMin - cd.GravityMax) * cp
        return speed, gravity, cd.InitialAngle, 0, cd.Lifetime
    end
    local pd = ProjectileWeapons[weaponName]
    if pd then return pd.Speed, pd.Gravity, pd.InitialAngle, 0, pd.Lifetime end
    return nil
end

------------------------------------------------------------
-- PROJECTILE PREDICTION
------------------------------------------------------------
local function CalculateAimPoint(origin, targetPos, speed, gravity, weaponName)
    if gravity == 0 then return targetPos end
    local dir  = targetPos - origin
    local hDir = Vector3.new(dir.X, 0, dir.Z); local hDist = hDir.Magnitude
    if hDist < 1 then return targetPos end
    local initAngle = 0
    local pd = ProjectileWeapons[weaponName]; if pd then initAngle = pd.InitialAngle or 0 end
    local cd = ChargeWeapons[weaponName];     if cd then initAngle = cd.InitialAngle or 0 end
    local v, g, x, y = speed, gravity, hDist, dir.Y
    local v2 = v*v; local v4 = v2*v2; local disc = v4 - g*(g*x*x + 2*y*v2)
    if disc >= 0 then
        local sqD   = math.sqrt(disc)
        local angle = math.atan2(v2 - sqD, g*x)
        if initAngle > 0 then angle = angle - math.rad(initAngle) end
        return origin + hDir.Unit * hDist + Vector3.new(0, math.tan(angle)*hDist, 0)
    end
    local flightTime = hDist / speed
    local drop = 0.5 * gravity * flightTime * flightTime
    local aim  = targetPos + Vector3.new(0, drop, 0)
    if initAngle > 0 then aim = aim - Vector3.new(0, math.tan(math.rad(initAngle))*hDist*0.3, 0) end
    return aim
end

local function CanProjectileHitPosition(origin, targetPos, speed, gravity, initAngle, lifetime, weaponName)
    local wallRP = RaycastParams.new()
    wallRP.FilterType = Enum.RaycastFilterType.Blacklist; wallRP.IgnoreWater = true
    local wi = {}
    for _, p in ipairs(cachedPlayerList) do if p.Character then table.insert(wi, p.Character) end end
    table.insert(wi, Camera); wallRP.FilterDescendantsInstances = wi

    if gravity == 0 then
        local dir = targetPos - origin; local hit = Workspace:Raycast(origin, dir, wallRP)
        if hit then return (hit.Position - origin).Magnitude >= dir.Magnitude - 2 end
        return true
    end
    local aimPoint = CalculateAimPoint(origin, targetPos, speed, gravity, weaponName)
    local aimDir   = (aimPoint - origin).Unit
    local hDir     = Vector3.new(aimDir.X, 0, aimDir.Z); if hDir.Magnitude < 0.01 then return false end
    hDir = hDir.Unit
    local pitch    = math.asin(math.clamp(aimDir.Y, -1, 1))
    local totalAngle = pitch + math.rad(initAngle)
    local hSpeed   = speed * math.cos(totalAngle); local vSpeed = speed * math.sin(totalAngle)
    local hDist    = Vector3.new(targetPos.X-origin.X, 0, targetPos.Z-origin.Z).Magnitude
    local totalTime = math.min(hDist / math.max(hSpeed, 1), lifetime)
    local prevPos  = origin
    for i = 1, 20 do
        local t = (i/20) * totalTime
        local hPos = origin + hDir*(hSpeed*t); local yPos = origin.Y + vSpeed*t - 0.5*gravity*t*t
        local curPos = Vector3.new(hPos.X, yPos, hPos.Z)
        local hit = Workspace:Raycast(prevPos, curPos - prevPos, wallRP)
        if hit then return (hit.Position - targetPos).Magnitude < 5 end
        prevPos = curPos
    end
    return (prevPos - targetPos).Magnitude < 10
end

local function PredictProjectileHit(targetPart, player, weaponName)
    local speed, gravity, initAngle, armTime, lifetime = GetCurrentWeaponSpeed(weaponName)
    if not speed then return targetPart.Position, 0 end
    local origin = (Camera.CFrame * CFrame.new(PROJECTILE_OFFSET)).Position
    local ping   = GetPing()
    local char   = targetPart:FindFirstAncestorOfClass("Model")
    local hrp    = char and GetHRP(char); if not hrp then return targetPart.Position, 0 end

    -- Capture selected part's offset from HRP; simulation tracks HRP, we re-apply offset at end
    local partOffset = targetPart.Position - hrp.Position

    if IsVelocityStale(player) or GetPlayerVelocity(player).Magnitude < 0.5 then
        return targetPart.Position, (targetPart.Position - origin).Magnitude / speed
    end

    local rp = GetSimRayParams()
    local predictedHRP = hrp.Position
    local travelTime   = 0
    local cosAngle     = math.cos(math.rad(initAngle))

    for _ = 1, 5 do
        local predictedPart  = predictedHRP + partOffset
        local dx = predictedPart.X - origin.X; local dz = predictedPart.Z - origin.Z
        local hDist = math.sqrt(dx*dx + dz*dz)
        if gravity == 0 and initAngle == 0 then
            travelTime = (predictedPart - origin).Magnitude / speed
        else
            travelTime = hDist / math.max(speed * cosAngle, 1)
        end
        travelTime = math.min(travelTime, lifetime)
        if armTime and armTime > 0 then travelTime = math.max(travelTime, armTime) end

        local totalTime = travelTime + ping * 2   -- 1 round-trip
        local simSteps  = math.clamp(math.floor(totalTime / 0.033), 5, 30)
        local simResult = SimulateTargetPosition(player, totalTime, simSteps, rp, true)
        if simResult then predictedHRP = simResult else return targetPart.Position, travelTime end
    end

    local predictedPos = predictedHRP + partOffset

    local myHRP = GetHRP(GetLocalCharacter())
    if myHRP and (predictedPos - myHRP.Position).Magnitude < 3 then
        return targetPart.Position, (targetPart.Position - origin).Magnitude / speed
    end

    if not CanProjectileHitPosition(origin, predictedPos, speed, gravity, initAngle, lifetime, weaponName) then
        if CanProjectileHitPosition(origin, targetPart.Position, speed, gravity, initAngle, lifetime, weaponName) then
            return targetPart.Position, (targetPart.Position - origin).Magnitude / speed
        end
        return nil, 0
    end
    return predictedPos, travelTime
end

------------------------------------------------------------
-- BUILD PLAYER DATA (single WorldToViewportPoint per player)
------------------------------------------------------------
local function BuildPlayerData()
    local data  = {}
    local lc    = GetLocalCharacter(); local lhrp = lc and GetHRP(lc); if not lhrp then return data end
    for _, plr in ipairs(cachedPlayerList) do
        if plr == LocalPlayer or not IsPlayerAlive(plr) then continue end
        local char = plr.Character; if not char then continue end
        local hrp  = GetHRP(char); if not hrp then continue end
        local sp, onScreen, depth = WorldToViewportPoint(hrp.Position)
        -- Aegis handshake scan
        local isAegis = false
        pcall(function() isAegis = char:GetAttribute(AEGIS_ATTR) == true end)
        if isAegis then AegisUserCache[plr] = true else AegisUserCache[plr] = nil end
        table.insert(data, {
            Player    = plr,
            Character = char,
            HRP       = hrp,
            ScreenPos = sp,
            Depth     = depth,
            OnScreen  = onScreen,
            Distance  = (lhrp.Position - hrp.Position).Magnitude,
            ScreenDistance = onScreen and (sp - FrameCache.screenCenter).Magnitude or math.huge,
            IsEnemy   = IsEnemy(plr),
            IsFriend  = IsFriend(plr),
            Class     = GetPlayerClass(plr),
            IsCheater = IsCheater(plr),
        })
    end
    return data
end

------------------------------------------------------------
-- SILENT AIM TARGET SELECTION
------------------------------------------------------------
local function GetSilentAimTarget(playerData)
    local fov        = Options.SilentAimFOV.Value
    local aimTargets = Options.AimAtTargets.Value or {}
    local weapon     = GetLocalWeapon()
    local isSyringe  = IsSyringeWeapon(weapon)
    local sortMode   = Options.SilentAimSort.Value or "Closest to Mouse"
    local selGroups  = Options.SilentAimBodyParts.Value or {Head=true}
    local sc         = FrameCache.screenCenter

    local bestPart, bestDist, bestPlayer = nil, math.huge, nil

    if aimTargets["Players"] then
        for _, pd in ipairs(playerData) do
            if isSyringe then
                if pd.IsEnemy then continue end
                if IsPlayerFullHP(pd.Player) then continue end
            else
                if not pd.IsEnemy then continue end
            end
            if not pd.OnScreen then continue end
            if Toggles.SilentIgnoreInvis.Value and IsCharacterInvisible(pd.Character) then continue end

            local part = GetBestVisiblePart(pd.Character, selGroups, sortMode)
            if not part then continue end

            local sp, onScreen = WorldToViewportPoint(part.Position); if not onScreen then continue end
            local dist = sortMode == "Closest to Mouse" and (sp - sc).Magnitude or pd.Distance
            if sortMode == "Closest to Mouse" and dist > fov then continue end
            if dist < bestDist then bestDist = dist; bestPart = part; bestPlayer = pd.Player end
        end
    end

    if aimTargets["Sentry"] then
        for _, v in pairs(cachedSentries) do
            if not v.Parent then continue end
            local ownerName = v.Name:match("^(.+)'s Sentry$"); local isEnemySentry = true
            if ownerName then for _, plr in ipairs(cachedPlayerList) do
                if plr.Name == ownerName and plr.Team == LocalPlayer.Team then isEnemySentry = false; break end
            end end
            if not isEnemySentry then continue end
            local hum = v:FindFirstChildOfClass("Humanoid"); if hum and hum.Health <= 0 then continue end
            local pp  = v.PrimaryPart or v:FindFirstChildWhichIsA("BasePart")
            if not pp or not IsPartVisible(pp) then continue end
            local sp, os2 = WorldToViewportPoint(pp.Position); if not os2 then continue end
            local d = sortMode == "Closest to Mouse" and (sp-sc).Magnitude or (FrameCache.camPos-pp.Position).Magnitude
            if sortMode == "Closest to Mouse" and d > fov then continue end
            if d < bestDist then bestDist = d; bestPart = pp; bestPlayer = nil end
        end
    end

    if aimTargets["Stickybomb"] then
        local dest = Workspace:FindFirstChild("Destructable")
        if dest then for _, v in pairs(dest:GetChildren()) do
            if v.Name:match("stickybomb$") and not v.Name:match(LocalPlayer.Name) then
                local isEn = true
                for _, plr in ipairs(cachedPlayerList) do
                    if v.Name:match(plr.Name) and plr.Team == LocalPlayer.Team then isEn = false; break end
                end
                if not isEn then continue end
                local p = v:IsA("BasePart") and v or v:FindFirstChildWhichIsA("BasePart")
                if not p or not IsPartVisible(p) then continue end
                local sp, os2 = WorldToViewportPoint(p.Position); if not os2 then continue end
                local d = sortMode == "Closest to Mouse" and (sp-sc).Magnitude or (FrameCache.camPos-p.Position).Magnitude
                if sortMode == "Closest to Mouse" and d > fov then continue end
                if d < bestDist then bestDist = d; bestPart = p; bestPlayer = nil end
            end
        end end
    end

    if bestPart then
        local myHRP = GetHRP(GetLocalCharacter())
        if myHRP and (bestPart.Position - myHRP.Position).Magnitude < 3 then return nil, nil end
    end
    return bestPart, bestPlayer
end

------------------------------------------------------------
-- AIM ARMS (0.5s hold, 0.3s smooth return)
------------------------------------------------------------
local ARM_HOLD_TIME   = 0.5
local ARM_RETURN_TIME = 0.3

local function AimArmsAt(targetPos)
    local vm = Camera:FindFirstChild("PrimaryVM"); if not vm then return end
    local am = vm:FindFirstChild("CharacterArmsModel"); if not am then return end
    local vp = vm:GetPivot()
    local ao = vp:ToObjectSpace(am:GetPivot())
    local lr = CFrame.lookAt(vp.Position, targetPos) * CFrame.Angles(math.rad(180), math.rad(180), math.rad(180))
    am:PivotTo(lr * ao)
end

local function ResetArmsToCamera()
    local vm = Camera:FindFirstChild("PrimaryVM"); if not vm then return end
    local am = vm:FindFirstChild("CharacterArmsModel"); if not am then return end
    local vp = vm:GetPivot()
    local ao = vp:ToObjectSpace(am:GetPivot())
    am:PivotTo(Camera.CFrame * CFrame.Angles(math.rad(180), math.rad(180), math.rad(180)) * ao)
end

local function UpdateAimArms()
    if not (Toggles.SilentAimArms and Toggles.SilentAimArms.Value) then return end
    if not S.armTarget then return end
    local now = tick()

    if S.armReturning then
        local alpha = math.clamp((now - S.armReturnStart) / ARM_RETURN_TIME, 0, 1)
        if alpha >= 1 then
            S.armReturning = false; S.armTarget = nil; ResetArmsToCamera()
        else
            local vm = Camera:FindFirstChild("PrimaryVM"); if not vm then return end
            local vp = vm:GetPivot()
            local tDir = (S.armTarget - vp.Position).Unit
            local cDir = Camera.CFrame.LookVector
            AimArmsAt(vp.Position + tDir:Lerp(cDir, alpha) * 10)
        end
        return
    end

    local elapsed = now - S.armHoldStart
    if elapsed >= ARM_HOLD_TIME then S.armReturning = true; S.armReturnStart = now; return end

    local mode = Options.SilentAimArmsMode and Options.SilentAimArmsMode.Value or "Snap"
    if mode == "Snap" then
        AimArmsAt(S.armTarget)
    else
        local alpha = math.clamp(elapsed / 0.15, 0, 1)
        local vm = Camera:FindFirstChild("PrimaryVM"); if not vm then return end
        local vp = vm:GetPivot()
        local cDir = Camera.CFrame.LookVector
        local tDir = (S.armTarget - vp.Position).Unit
        AimArmsAt(vp.Position + cDir:Lerp(tDir, alpha) * 10)
    end
end

local function TriggerAimArms(targetPos)
    if not S.armReturning then
        S.armTarget = targetPos; S.armHoldStart = tick()
    end
end

------------------------------------------------------------
-- CAMERA HOOK
------------------------------------------------------------
local function GetProjectileAimCFrame(target, targetPlr, weapon)
    if weapon == "Huntsman" then
        local tChar = target:FindFirstAncestorOfClass("Model")
        if tChar then local head = tChar:FindFirstChild("Head"); if head and IsPartVisible(head) then target = head end end
    end
    local predicted, _ = PredictProjectileHit(target, targetPlr, weapon)
    if not predicted then return nil end
    if weapon == "Huntsman" then predicted = predicted + Vector3.new(0, 1.5, 0) end
    local spd, grav = GetCurrentWeaponSpeed(weapon)
    if grav and grav > 0 then
        return CFrame.lookAt(FrameCache.camPos, CalculateAimPoint(FrameCache.camPos, predicted, spd, grav, weapon)), predicted
    else
        return CFrame.lookAt(FrameCache.camPos, predicted), predicted
    end
end

task.spawn(function()
    pcall(function()
        local camModule = require(ReplicatedStorage.Modules.gameCamera)
        if not (camModule and camModule.GetCameraAimCFrame) then return end
        local orig = camModule.GetCameraAimCFrame
        camModule.GetCameraAimCFrame = function(self2, ...)
            if not IsPlayerAlive(LocalPlayer) then return orig(self2, ...) end
            local weapon = GetLocalWeapon()
            if BlacklistedWeapons[weapon] then return orig(self2, ...) end
            local isProj = ProjectileWeapons[weapon] ~= nil or ChargeWeapons[weapon] ~= nil

            if Config.SilentAim.Enabled and S.silentAimKeyActive then
                local target    = FrameCache.silentTarget
                local targetPlr = FrameCache.silentTargetPlr
                if target then
                    if isProj and targetPlr then
                        local cf, aimPos = GetProjectileAimCFrame(target, targetPlr, weapon)
                        if cf and aimPos then
                            if Toggles.SilentAimArms.Value then TriggerAimArms(aimPos) end
                            return cf
                        end
                    else
                        if Toggles.SilentAimArms.Value then TriggerAimArms(target.Position) end
                        return CFrame.lookAt(FrameCache.camPos, target.Position)
                    end
                end
            end

            if Toggles.AutoBackstab and Toggles.AutoBackstab.Value then
                local myClass = GetLocalClass(); local myWeapon = GetLocalWeapon()
                if myClass == "Agent" and BackstabWeapons[myWeapon] then
                    local lh = GetHRP(GetLocalCharacter())
                    if lh then for _, pd in ipairs(FrameCache.playerData or {}) do
                        if not pd.IsEnemy or pd.Distance > BACKSTAB_RANGE then continue end
                        if Toggles.BackstabIgnoreInvis.Value and IsCharacterInvisible(pd.Character) then continue end
                        local toT = (pd.HRP.Position - lh.Position).Unit
                        if toT:Dot(pd.HRP.CFrame.LookVector) > 0.3 then
                            if not HasLineOfSight(lh.Position, pd.HRP.Position) then continue end
                            local backPos = pd.HRP.Position - pd.HRP.CFrame.LookVector
                            if Toggles.SilentAimArms.Value then TriggerAimArms(backPos) end
                            return CFrame.lookAt(FrameCache.camPos, backPos)
                        end
                    end end
                end
            end

            if Toggles.AutoMelee and Toggles.AutoMelee.Value then
                local myWeapon = GetLocalWeapon()
                if MeleeWeapons[myWeapon] then
                    local lh = GetHRP(GetLocalCharacter())
                    local meleeRange = (Options.AutoMeleeMode and Options.AutoMeleeMode.Value == "Demoknight") and MELEE_RANGE_DEMOKNIGHT or MELEE_RANGE_RAGE
                    if lh then
                        local bestTarget, bestDist2 = nil, math.huge
                        for _, pd in ipairs(FrameCache.playerData or {}) do
                            if not pd.IsEnemy or pd.Distance > meleeRange then continue end
                            if Toggles.MeleeIgnoreInvis.Value and IsCharacterInvisible(pd.Character) then continue end
                            if not HasLineOfSight(lh.Position, pd.HRP.Position) then continue end
                            if pd.Distance < bestDist2 then bestDist2 = pd.Distance; bestTarget = pd end
                        end
                        if bestTarget then return CFrame.lookAt(FrameCache.camPos, bestTarget.HRP.Position) end
                    end
                end
            end

            return orig(self2, ...)
        end
    end)
end)

------------------------------------------------------------
-- NAMECALL HOOK (Fall Damage intercept)
------------------------------------------------------------
local _ncOrig
_ncOrig = hookmetamethod(game, "__namecall", function(self2, ...)
    if not Library.Unloaded then
        local method = getnamecallmethod()
        if method == "FireServer" and self2.Name == "FallDamage" then
            if Toggles.NoFallDamage and Toggles.NoFallDamage.Value then return end
        end
    end
    return _ncOrig(self2, ...)
end)

------------------------------------------------------------
-- WALLBANG hook — __namecall intercept on Raycast
------------------------------------------------------------
local wallbangHook = nil
local wallbangActive = false

local function InstallWallbangHook()
    if wallbangHook then return end
    wallbangActive = true
    wallbangHook = hookmetamethod(game, "__namecall", newcclosure(function(self2, ...)
        if wallbangActive then
            local method = getnamecallmethod()
            -- Intercept workspace:Raycast — strip collisions by nullifying params
            if method == "Raycast" and self2 == Workspace then
                local args = {...}
                -- Rebuild params with no filter so bullets pass through everything
                local rp = RaycastParams.new()
                rp.FilterType = Enum.RaycastFilterType.Blacklist
                local lc = GetLocalCharacter()
                rp.FilterDescendantsInstances = lc and {lc, Camera} or {Camera}
                args[3] = rp
                return wallbangHook(self2, table.unpack(args))
            end
        end
        return wallbangHook(self2, ...)
    end))
end

local function RemoveWallbangHook()
    wallbangActive = false
    if wallbangHook then
        hookmetamethod(game, "__namecall", wallbangHook)
        wallbangHook = nil
    end
end

------------------------------------------------------------
-- NO SPREAD
------------------------------------------------------------
local function SetupNoSpread()
    if S.noSpreadSetup or not EnsureGUILoaded() then return end
    S.noSpreadSetup = true
    S.kirk.Changed:Connect(function()
        if not Config.NoSpread.Enable or S.charlieKirk then return end
        S.charlieKirk = true; S.kirk.Value = S.kirk.Value * Config.NoSpread.Multiplier; S.charlieKirk = false
    end)
end

------------------------------------------------------------
-- SPEED
------------------------------------------------------------
local function SetupSpeed()
    if S.speedConnection then S.speedConnection:Disconnect(); S.speedConnection = nil end
    if Config.Speed.Enable and LocalPlayer.Character then
        LocalPlayer.Character:SetAttribute("Speed", Config.Speed.Value)
        S.speedConnection = LocalPlayer.Character:GetAttributeChangedSignal("Speed"):Connect(function()
            if Config.Speed.Enable and not S.warpActive then
                LocalPlayer.Character:SetAttribute("Speed", Config.Speed.Value)
            end
        end)
    end
end

------------------------------------------------------------
-- MISC
------------------------------------------------------------
local function ApplyThirdPerson(state)
    pcall(function()
        LocalPlayer:SetAttribute("ThirdPerson", state)
        local vip = ReplicatedStorage:FindFirstChild("VIPSettings")
        if vip then local tp = vip:FindFirstChild("AThirdPersonMode"); if tp then tp.Value = state end end
    end)
end

local function ApplyDeviceSpoof(platform)
    if platform == "None" then return end
    pcall(function()
        local ntp = LocalPlayer:FindFirstChild("newTcPlayer"); if not ntp then return end
        ntp:SetAttribute("Platform", platform); ntp:SetAttribute("Platform Type", platform)
    end)
end

------------------------------------------------------------
-- MOBILE BUTTON
------------------------------------------------------------
local function CreateMobileButton()
    if S.mobileToggleButton then return end
    local sg = Instance.new("ScreenGui"); sg.Name = "AegisMobileButton"
    sg.ResetOnSpawn = false; sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    sg.DisplayOrder = 999; sg.Parent = LocalPlayer:WaitForChild("PlayerGui")
    local btn = Instance.new("TextButton"); btn.Name = "AegisToggle"
    btn.Size = UDim2.new(0,50,0,50); btn.Position = UDim2.new(0,20,0.5,-25)
    btn.BackgroundColor3 = Color3.fromRGB(30,30,30); btn.BackgroundTransparency = 0.3
    btn.Text = "A"; btn.TextColor3 = Color3.fromRGB(200,200,255); btn.TextSize = 28
    btn.Font = Enum.Font.GothamBold; btn.Parent = sg; btn.Active = true; btn.ZIndex = 100
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0,12)
    local stroke = Instance.new("UIStroke", btn); stroke.Color = Color3.fromRGB(100,100,200); stroke.Thickness = 2
    local dragging, dragStart, startPos = false, nil, nil
    btn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true; dragStart = input.Position; startPos = btn.Position
        end
    end)
    btn.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement) then
            local d = input.Position - dragStart
            btn.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset+d.X, startPos.Y.Scale, startPos.Y.Offset+d.Y)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1) and dragging then
            local d = input.Position - dragStart; dragging = false
            if d.Magnitude < 10 then pcall(function() Library:ToggleMenu() end) end
        end
    end)
    S.mobileToggleButton = sg
end

local function DestroyMobileButton()
    if S.mobileToggleButton then S.mobileToggleButton:Destroy(); S.mobileToggleButton = nil end
end

------------------------------------------------------------
-- CHARACTER RESPAWN
------------------------------------------------------------
LocalPlayer.CharacterAdded:Connect(function(char)
    task.wait(1); EnsureGUILoaded(); SetupNoSpread(); SetupSpeed()
    S.jitterDir = 1; S.spinAngle = 0; S.armTarget = nil; S.armReturning = false;
    if Toggles.AegisStatus and Toggles.AegisStatus.Value then
        task.wait(0.5); StampAegisCharacter(char)
    end
end)
task.spawn(function() task.wait(2); EnsureGUILoaded(); SetupNoSpread()
    if LocalPlayer.Character then SetupSpeed() end
    if Toggles.AegisStatus and Toggles.AegisStatus.Value then
        StampAegisCharacter(LocalPlayer.Character)
    end
end)

------------------------------------------------------------
-- DRAWING HELPERS
------------------------------------------------------------
local ESPObjects    = {}
local ObjectESPCache = {}

local FOVCircle = Drawing.new("Circle")
FOVCircle.Thickness = 1; FOVCircle.NumSides = 64; FOVCircle.Filled = false
FOVCircle.Visible = false; FOVCircle.Transparency = 0.8

local PredictionIndicator = Drawing.new("Text")
PredictionIndicator.Size = 24; PredictionIndicator.Center = true
PredictionIndicator.Outline = true; PredictionIndicator.Font = 2; PredictionIndicator.Visible = false

local function MkDraw(t, p)
    local d = Drawing.new(t); for k,v in pairs(p or {}) do d[k] = v end; return d
end

local function CreatePlayerESP(player)
    if ESPObjects[player] then return end
    local d = {BoxLines={}, BoxOutlines={}, CornerLines={}, CornerOutlines={},
               Box3DLines={}, Box3DOutlines={}, SkeletonLines={}, StatusTexts={}, Hidden=true}
    for i=1,4  do d.BoxOutlines[i]   = MkDraw("Line",{Thickness=3,Color=Color3.new(0,0,0),Visible=false}) end
    for i=1,8  do d.CornerOutlines[i]= MkDraw("Line",{Thickness=3,Color=Color3.new(0,0,0),Visible=false}) end
    for i=1,12 do d.Box3DOutlines[i] = MkDraw("Line",{Thickness=3,Color=Color3.new(0,0,0),Visible=false}) end
    d.HealthBarBG      = MkDraw("Line",{Thickness=3,Color=Color3.fromRGB(20,20,20),Visible=false})
    d.HealthBarOutline = MkDraw("Square",{Filled=false,Thickness=1,Color=Color3.new(0,0,0),Visible=false})
    d.TracerOut        = MkDraw("Line",{Thickness=3,Color=Color3.new(0,0,0),Visible=false})
    for i=1,4  do d.BoxLines[i]    = MkDraw("Line",{Thickness=1,Visible=false}) end
    for i=1,8  do d.CornerLines[i] = MkDraw("Line",{Thickness=1,Visible=false}) end
    for i=1,12 do d.Box3DLines[i]  = MkDraw("Line",{Thickness=1,Visible=false}) end
    d.HealthBar         = MkDraw("Line",{Thickness=1,Visible=false})
    d.HealthDmg         = MkDraw("Line",{Thickness=1,Color=Color3.fromRGB(255,120,0),Visible=false})
    d.Tracer            = MkDraw("Line",{Thickness=1,Visible=false})
    d.NameText          = MkDraw("Text",{Size=13,Center=true,Outline=true,Font=2,Visible=false})
    d.CheaterText       = MkDraw("Text",{Size=11,Center=true,Outline=true,Font=2,Visible=false,Color=Color3.fromRGB(255,60,60)})
    d.DistanceText      = MkDraw("Text",{Size=7,Center=true,Outline=true,Font=2,Visible=false,Transparency=0.15})
    d.WeaponText        = MkDraw("Text",{Size=7,Center=true,Outline=true,Font=2,Visible=false,Transparency=0.15})
    d.ClassText         = MkDraw("Text",{Size=7,Center=true,Outline=true,Font=2,Visible=false,Transparency=0.15})
    d.HealthText        = MkDraw("Text",{Size=11,Center=false,Outline=true,Font=2,Visible=false})
    d.HealthPercentText = MkDraw("Text",{Size=11,Center=false,Outline=true,Font=2,Visible=false})
    d.SightLine         = MkDraw("Line",{Thickness=1,Color=Color3.new(1,0,0),Visible=false})
    d.AegisText         = MkDraw("Text",{Size=11,Center=true,Outline=true,Font=2,Visible=false,Color=Color3.fromRGB(180,10,10)})
    for i=1,#SkeletonConnections do d.SkeletonLines[i] = MkDraw("Line",{Thickness=1,Visible=false}) end
    for attrName, info in pairs(StatusLetters) do
        d.StatusTexts[attrName] = MkDraw("Text",{Size=11,Center=false,Outline=true,Font=2,Visible=false,Color=info.Color})
    end
    ESPObjects[player] = d
end

local function DestroyPlayerESP(player)
    local d = ESPObjects[player]; if not d then return end
    local function R(o) pcall(function() o:Remove() end) end
    for i=1,4  do R(d.BoxLines[i]);    R(d.BoxOutlines[i]) end
    for i=1,8  do R(d.CornerLines[i]); R(d.CornerOutlines[i]) end
    for i=1,12 do R(d.Box3DLines[i]);  R(d.Box3DOutlines[i]) end
    for i=1,#SkeletonConnections do R(d.SkeletonLines[i]) end
    R(d.HealthBarBG); R(d.HealthBar); R(d.HealthDmg); R(d.HealthBarOutline)
    R(d.NameText); R(d.CheaterText); R(d.DistanceText); R(d.WeaponText); R(d.ClassText); R(d.AegisText)
    R(d.HealthText); R(d.HealthPercentText); R(d.SightLine); R(d.Tracer); R(d.TracerOut)
    for _, txt in pairs(d.StatusTexts) do R(txt) end
    ESPObjects[player] = nil
end

local function HidePlayerESP(player)
    local d = ESPObjects[player]; if not d or d.Hidden then return end; d.Hidden = true
    for i=1,4  do d.BoxLines[i].Visible=false;    d.BoxOutlines[i].Visible=false end
    for i=1,8  do d.CornerLines[i].Visible=false;  d.CornerOutlines[i].Visible=false end
    for i=1,12 do d.Box3DLines[i].Visible=false;   d.Box3DOutlines[i].Visible=false end
    for i=1,#SkeletonConnections do d.SkeletonLines[i].Visible=false end
    d.HealthBarBG.Visible=false; d.HealthBar.Visible=false; d.HealthDmg.Visible=false; d.HealthBarOutline.Visible=false
    d.NameText.Visible=false; d.CheaterText.Visible=false; d.DistanceText.Visible=false
    d.WeaponText.Visible=false; d.ClassText.Visible=false; d.AegisText.Visible=false
    d.HealthText.Visible=false; d.HealthPercentText.Visible=false; d.SightLine.Visible=false
    d.Tracer.Visible=false; d.TracerOut.Visible=false
    for _, txt in pairs(d.StatusTexts) do txt.Visible=false end
end

local function CreateObjectESP(inst)
    if ObjectESPCache[inst] then return end
    local d = {BoxLines={}, BoxOutlines={}}
    for i=1,4 do d.BoxOutlines[i] = MkDraw("Line",{Thickness=3,Color=Color3.new(0,0,0),Visible=false}) end
    d.HealthBarBG       = MkDraw("Line",{Thickness=3,Color=Color3.new(0,0,0),Visible=false})
    for i=1,4 do d.BoxLines[i] = MkDraw("Line",{Thickness=1,Visible=false}) end
    d.HealthBar         = MkDraw("Line",{Thickness=1,Visible=false})
    d.HealthText        = MkDraw("Text",{Size=13,Center=true,Outline=true,Font=2,Visible=false})
    d.HealthPercentText = MkDraw("Text",{Size=13,Center=true,Outline=true,Font=2,Visible=false})
    d.NameText          = MkDraw("Text",{Size=13,Center=true,Outline=true,Font=2,Visible=false})
    ObjectESPCache[inst] = d
end

local function DestroyObjectESP(inst)
    local d = ObjectESPCache[inst]; if not d then return end
    for i=1,4 do pcall(function() d.BoxLines[i]:Remove() end); pcall(function() d.BoxOutlines[i]:Remove() end) end
    pcall(function() d.HealthBarBG:Remove() end); pcall(function() d.HealthBar:Remove() end)
    pcall(function() d.HealthText:Remove() end); pcall(function() d.HealthPercentText:Remove() end)
    pcall(function() d.NameText:Remove() end)
    ObjectESPCache[inst] = nil
end

local function HideObjectESP(inst)
    local d = ObjectESPCache[inst]; if not d then return end
    for i=1,4 do d.BoxLines[i].Visible=false; d.BoxOutlines[i].Visible=false end
    d.HealthBarBG.Visible=false; d.HealthBar.Visible=false
    d.HealthText.Visible=false; d.HealthPercentText.Visible=false; d.NameText.Visible=false
end

------------------------------------------------------------
-- ESP RENDERING
------------------------------------------------------------
local function Get2DBox(pd)
    local sp = pd.ScreenPos; local depth = pd.Depth
    if not pd.OnScreen or depth < 1 then return nil end
    local sc2 = (2 * Camera.ViewportSize.Y) / ((2 * depth * math.tan(math.rad(Camera.FieldOfView)/2)) * 1.5)
    local w, h = math.floor(3*sc2), math.floor(4*sc2)
    return {X=sp.X-w/2, Y=sp.Y-h/2, W=w, H=h, CX=sp.X, CY=sp.Y, TopY=sp.Y-h/2, BotY=sp.Y+h/2}
end

local function Draw2DBox(d, b, c)
    local tl=Vector2.new(b.X,b.Y); local tr=Vector2.new(b.X+b.W,b.Y)
    local bl=Vector2.new(b.X,b.Y+b.H); local br=Vector2.new(b.X+b.W,b.Y+b.H)
    local edges = {{tl,tr},{tr,br},{br,bl},{bl,tl}}
    for i=1,4 do
        d.BoxOutlines[i].From=edges[i][1]; d.BoxOutlines[i].To=edges[i][2]; d.BoxOutlines[i].Color=Color3.new(0,0,0); d.BoxOutlines[i].Visible=true
        d.BoxLines[i].From=edges[i][1];    d.BoxLines[i].To=edges[i][2];    d.BoxLines[i].Color=c;                     d.BoxLines[i].Visible=true
    end
end

local function DrawCorners(d, b, c)
    local cl = math.max(b.H*0.25, 6)
    local tl=Vector2.new(b.X,b.Y); local tr=Vector2.new(b.X+b.W,b.Y)
    local bl=Vector2.new(b.X,b.Y+b.H); local br=Vector2.new(b.X+b.W,b.Y+b.H)
    local cn = {{tl,tl+Vector2.new(cl,0)},{tl,tl+Vector2.new(0,cl)},{tr,tr+Vector2.new(-cl,0)},{tr,tr+Vector2.new(0,cl)},
                {bl,bl+Vector2.new(cl,0)},{bl,bl+Vector2.new(0,-cl)},{br,br+Vector2.new(-cl,0)},{br,br+Vector2.new(0,-cl)}}
    for i=1,8 do
        d.CornerOutlines[i].From=cn[i][1]; d.CornerOutlines[i].To=cn[i][2]; d.CornerOutlines[i].Color=Color3.new(0,0,0); d.CornerOutlines[i].Visible=true
        d.CornerLines[i].From=cn[i][1];    d.CornerLines[i].To=cn[i][2];    d.CornerLines[i].Color=c;                     d.CornerLines[i].Visible=true
    end
end

local function Draw3DBox(d, char, c)
    local hrp = GetHRP(char); if not hrp then return end
    local cf = hrp.CFrame; local sz = Vector3.new(2,3,2)
    local corners = {
        cf*Vector3.new(sz.X,sz.Y,sz.Z),  cf*Vector3.new(-sz.X,sz.Y,sz.Z),
        cf*Vector3.new(-sz.X,sz.Y,-sz.Z), cf*Vector3.new(sz.X,sz.Y,-sz.Z),
        cf*Vector3.new(sz.X,-sz.Y,sz.Z),  cf*Vector3.new(-sz.X,-sz.Y,sz.Z),
        cf*Vector3.new(-sz.X,-sz.Y,-sz.Z),cf*Vector3.new(sz.X,-sz.Y,-sz.Z),
    }
    local sc2 = {}; for _, v in pairs(corners) do table.insert(sc2, (WorldToViewportPoint(v))) end
    local edges = {{1,2},{2,3},{3,4},{4,1},{5,6},{6,7},{7,8},{8,5},{1,5},{2,6},{3,7},{4,8}}
    for i, e in pairs(edges) do
        d.Box3DOutlines[i].From=sc2[e[1]]; d.Box3DOutlines[i].To=sc2[e[2]]; d.Box3DOutlines[i].Color=Color3.new(0,0,0); d.Box3DOutlines[i].Visible=true
        d.Box3DLines[i].From=sc2[e[1]];    d.Box3DLines[i].To=sc2[e[2]];    d.Box3DLines[i].Color=c;                     d.Box3DLines[i].Visible=true
    end
end

local function UpdatePlayerESP(pd)
    local player = pd.Player
    local d = ESPObjects[player]; if not d then CreatePlayerESP(player); d = ESPObjects[player]; if not d then return end end
    local char = pd.Character; local hum = GetHumanoid(char)
    if not hum or hum.Health <= 0 then HidePlayerESP(player); return end
    if pd.IsEnemy      and not Toggles.ESPEnemy.Value   then HidePlayerESP(player); return end
    if not pd.IsEnemy  and not pd.IsFriend and not Toggles.ESPTeam.Value then HidePlayerESP(player); return end
    if pd.IsFriend     and not Toggles.ESPFriends.Value then HidePlayerESP(player); return end
    if Toggles.ESPIgnoreInvis.Value and IsCharacterInvisible(char) then HidePlayerESP(player); return end
    if pd.Distance > 500 or not pd.OnScreen then HidePlayerESP(player); return end

    local box = Get2DBox(pd); if not box then HidePlayerESP(player); return end
    HidePlayerESP(player); d.Hidden = false

    local color = Options.ESPBoxColor.Value
    local bt = Options.ESPBoxType.Value
    if     bt == "2D"      then Draw2DBox(d, box, color)
    elseif bt == "Corners" then DrawCorners(d, box, color)
    elseif bt == "3D"      then Draw3DBox(d, char, color) end

    local maxHP = GetPlayerMaxHP(player)
    local hp = hum.Health; local hf = math.clamp(hp/maxHP, 0, 1)
    local topY = box.TopY - 2; local tX = box.CX

    -- Cheater tag
    if pd.IsCheater then
        topY = topY - 13
        d.CheaterText.Text = "cheater"; d.CheaterText.Position = Vector2.new(tX, topY)
        d.CheaterText.Color = Color3.fromRGB(255,60,60); d.CheaterText.Visible = true
        topY = topY - 2
    else d.CheaterText.Visible = false end

    -- Aegis user tag
    if AegisUserCache[player] then
        topY = topY - 13
        d.AegisText.Text = "[A]"; d.AegisText.Position = Vector2.new(tX, topY)
        d.AegisText.Color = Color3.fromRGB(180,10,10); d.AegisText.Visible = true
        topY = topY - 2
    else d.AegisText.Visible = false end

    if Toggles.ESPClass and Toggles.ESPClass.Value then
        topY = topY - 15; d.ClassText.Text = pd.Class; d.ClassText.Position = Vector2.new(tX,topY); d.ClassText.Color = Color3.fromRGB(200,200,255); d.ClassText.Visible = true
    end
    if Toggles.ESPWeapon and Toggles.ESPWeapon.Value then
        topY = topY - 15; d.WeaponText.Text = GetPlayerWeapon(char); d.WeaponText.Position = Vector2.new(tX,topY); d.WeaponText.Color = Color3.fromRGB(255,200,100); d.WeaponText.Visible = true
    end
    local bY = box.BotY + 2
    if Toggles.ESPDistance and Toggles.ESPDistance.Value then
        d.DistanceText.Text = string.format("[%dm]", math.floor(pd.Distance)); d.DistanceText.Position = Vector2.new(tX,bY); d.DistanceText.Color = Color3.new(1,1,1); d.DistanceText.Visible = true; bY = bY + 15
    end
    if Toggles.ESPStatus and Toggles.ESPStatus.Value then
        local mods = GetPlayerModifiers(player); local rightX = box.X+box.W+4; local rightY = box.Y
        for attrName, info in pairs(StatusLetters) do
            local txt = d.StatusTexts[attrName]
            if mods[attrName] then txt.Text=info.Letter; txt.Position=Vector2.new(rightX,rightY); txt.Color=(attrName=="Ubercharged") and GetRainbowColor() or info.Color; txt.Visible=true; rightY=rightY+12
            else txt.Visible=false end
        end
    else for _, txt in pairs(d.StatusTexts) do txt.Visible=false end end

    if Toggles.ESPHealthBar and Toggles.ESPHealthBar.Value then
        local hpFrac = math.clamp(hp/maxHP, 0, 1.5)
        local barW=3; local barX=box.X-barW-3; local barTop=box.Y; local barBot=box.Y+box.H; local barH=barBot-barTop
        local hpHeight=barH*math.min(hpFrac,1); local fillY=barBot-hpHeight
        d.HealthBarOutline.Size=Vector2.new(barW+2,barH+2); d.HealthBarOutline.Position=Vector2.new(barX-1,barTop-1); d.HealthBarOutline.Visible=true
        d.HealthBarBG.From=Vector2.new(barX+1,barTop); d.HealthBarBG.To=Vector2.new(barX+1,barBot); d.HealthBarBG.Thickness=barW; d.HealthBarBG.Visible=true
        d.HealthBar.From=Vector2.new(barX+1,fillY); d.HealthBar.To=Vector2.new(barX+1,barBot); d.HealthBar.Thickness=barW-2
        d.HealthBar.Color = hpFrac>1 and Color3.fromRGB(0,200,255) or Color3.fromRGB(255*(1-hf),255*hf,0)
        d.HealthBar.Visible=true; d.HealthDmg.Visible=false
        if Toggles.ESPHealthValue and Toggles.ESPHealthValue.Value then
            local txt = tostring(math.floor(hp)); if hpFrac>1 then txt=txt.." (+"..math.floor(hp-maxHP)..")" end
            d.HealthText.Text=txt; d.HealthText.Position=Vector2.new(barX-2,fillY-6); d.HealthText.Color=d.HealthBar.Color; d.HealthText.Visible=true
        else d.HealthText.Visible=false end
        if Toggles.ESPHealthPercent and Toggles.ESPHealthPercent.Value then
            d.HealthPercentText.Text=string.format("%d%%",math.floor(hf*100)); d.HealthPercentText.Position=Vector2.new(barX-2,barBot-12); d.HealthPercentText.Color=Color3.new(1,1,1); d.HealthPercentText.Visible=true
        else d.HealthPercentText.Visible=false end
    else
        d.HealthBarBG.Visible=false; d.HealthBar.Visible=false; d.HealthDmg.Visible=false; d.HealthBarOutline.Visible=false
        if Toggles.ESPHealthValue and Toggles.ESPHealthValue.Value then
            d.HealthText.Text=string.format("HP: %d/%d",math.floor(hp),math.floor(maxHP)); d.HealthText.Position=Vector2.new(tX,bY); d.HealthText.Color=Color3.new(1,1,1); d.HealthText.Visible=true; d.HealthText.Center=true; bY=bY+15
        else d.HealthText.Visible=false end
        if Toggles.ESPHealthPercent and Toggles.ESPHealthPercent.Value then
            d.HealthPercentText.Text=string.format("%d%%",math.floor(hf*100)); d.HealthPercentText.Position=Vector2.new(tX,bY); d.HealthPercentText.Color=Color3.new(1,1,1); d.HealthPercentText.Visible=true; d.HealthPercentText.Center=true
        else d.HealthPercentText.Visible=false end
    end

    if Toggles.ESPSkeleton and Toggles.ESPSkeleton.Value then
        for i, conn in pairs(SkeletonConnections) do
            local pA = char:FindFirstChild(conn[1]); local pB = char:FindFirstChild(conn[2])
            if pA and pB then
                local sA, oA = WorldToViewportPoint(pA.Position); local sB, oB = WorldToViewportPoint(pB.Position)
                if oA and oB then d.SkeletonLines[i].From=sA; d.SkeletonLines[i].To=sB; d.SkeletonLines[i].Color=Color3.new(1,1,1); d.SkeletonLines[i].Visible=true
                else d.SkeletonLines[i].Visible=false end
            else d.SkeletonLines[i].Visible=false end
        end
    end

    if Toggles.SightlinesToggle and Toggles.SightlinesToggle.Value and pd.Class == "Marksman" then
        local head = char:FindFirstChild("Head")
        if head then
            local sS, oS = WorldToViewportPoint(head.Position); local sE, oE = WorldToViewportPoint(head.Position + head.CFrame.LookVector*500)
            if oS or oE then d.SightLine.From=sS; d.SightLine.To=sE; d.SightLine.Color=Color3.new(1,0,0); d.SightLine.Visible=true
            else d.SightLine.Visible=false end
        else d.SightLine.Visible=false end
    end

    if Toggles.ESPTracer and Toggles.ESPTracer.Value then
        local tracerColor = Options.ESPTracerColor and Options.ESPTracerColor.Value or color
        local originMode  = Options.ESPTracerOrigin and Options.ESPTracerOrigin.Value or "Bottom"
        local tracerOrigin
        if     originMode == "Top"    then tracerOrigin = Vector2.new(Camera.ViewportSize.X/2, 0)
        elseif originMode == "Center" then tracerOrigin = FrameCache.screenCenter
        else tracerOrigin = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y) end
        d.TracerOut.From=tracerOrigin; d.TracerOut.To=Vector2.new(box.CX,box.BotY); d.TracerOut.Visible=true
        d.Tracer.From=tracerOrigin;    d.Tracer.To=Vector2.new(box.CX,box.BotY); d.Tracer.Color=tracerColor; d.Tracer.Visible=true
    end
end

local function GetObjectBox(inst)
    local pp = inst:IsA("Model") and (inst.PrimaryPart or inst:FindFirstChildWhichIsA("BasePart")) or (inst:IsA("BasePart") and inst)
    if not pp then return nil end
    local sp, os2, depth = WorldToViewportPoint(pp.Position)
    if not os2 or depth < 1 then return nil end
    local sc2 = (2*Camera.ViewportSize.Y) / ((2*depth*math.tan(math.rad(Camera.FieldOfView)/2))*1.5)
    local bW = math.clamp(pp.Size.Magnitude*sc2*0.5, 10, 200); local bH = math.clamp(pp.Size.Magnitude*sc2*0.7, 10, 200)
    return {TopLeft=sp-Vector2.new(bW/2,bH/2), TopRight=sp+Vector2.new(bW/2,-bH/2),
            BottomLeft=sp+Vector2.new(-bW/2,bH/2), BottomRight=sp+Vector2.new(bW/2,bH/2), Center=sp, Width=bW, Height=bH}
end


------------------------------------------------------------
-- BUILDING TEAM HELPER
-- Returns "enemy", "team", or "unknown" for a building model
------------------------------------------------------------
local function GetBuildingTeam(inst)
    local ownerName = inst.Name:match("^(.+)'s ") or inst.Name:match("^(.+)'s")
    if not ownerName then return "unknown" end
    for _, plr in ipairs(cachedPlayerList) do
        if plr.Name == ownerName then
            return plr.Team == LocalPlayer.Team and "team" or "enemy"
        end
    end
    return "unknown"
end

local function UpdateObjectESP(inst, tn, overrideColor)
    local d = ObjectESPCache[inst]; if not d then CreateObjectESP(inst); d = ObjectESPCache[inst]; if not d then return end end
    local b = GetObjectBox(inst); if not b then HideObjectESP(inst); return end
    local c = overrideColor or Options.ObjESPBoxColor.Value
    local l = {{b.TopLeft,b.TopRight},{b.TopRight,b.BottomRight},{b.BottomRight,b.BottomLeft},{b.BottomLeft,b.TopLeft}}
    for i=1,4 do
        d.BoxOutlines[i].From=l[i][1]; d.BoxOutlines[i].To=l[i][2]; d.BoxOutlines[i].Color=Color3.new(0,0,0); d.BoxOutlines[i].Visible=true
        d.BoxLines[i].From=l[i][1];    d.BoxLines[i].To=l[i][2];    d.BoxLines[i].Color=c;                     d.BoxLines[i].Visible=true
    end
    d.NameText.Text=tn..": "..inst.Name; d.NameText.Position=b.Center-Vector2.new(0,b.Height/2+15); d.NameText.Color=Color3.new(1,1,1); d.NameText.Visible=true
    local hum = inst:FindFirstChildOfClass("Humanoid")
    if hum then
        local hp, mh = hum.Health, hum.MaxHealth; local hf2 = math.clamp(hp/mh, 0, 1)
        local hc = Color3.fromRGB(255*(1-hf2), 255*hf2, 0); local yO = b.Height/2+2
        if Toggles.ObjESPHealthValue  and Toggles.ObjESPHealthValue.Value then  d.HealthText.Text=string.format("HP: %d/%d",math.floor(hp),math.floor(mh)); d.HealthText.Position=b.Center+Vector2.new(0,yO); d.HealthText.Color=Color3.new(1,1,1); d.HealthText.Visible=true; yO=yO+15 end
        if Toggles.ObjESPHealthPercent and Toggles.ObjESPHealthPercent.Value then d.HealthPercentText.Text=string.format("%d%%",math.floor(hf2*100)); d.HealthPercentText.Position=b.Center+Vector2.new(0,yO); d.HealthPercentText.Color=Color3.new(1,1,1); d.HealthPercentText.Visible=true end
        if Toggles.ObjESPHealthBar    and Toggles.ObjESPHealthBar.Value then
            local bX=b.TopLeft.X-5; local bT=b.TopLeft.Y; local bB=b.BottomLeft.Y
            d.HealthBarBG.From=Vector2.new(bX,bT); d.HealthBarBG.To=Vector2.new(bX,bB); d.HealthBarBG.Thickness=3; d.HealthBarBG.Visible=true
            d.HealthBar.From=Vector2.new(bX,bB-(bB-bT)*hf2); d.HealthBar.To=Vector2.new(bX,bB); d.HealthBar.Thickness=1; d.HealthBar.Color=hc; d.HealthBar.Visible=true
        end
    end
end

------------------------------------------------------------
-- CHAMS (keyed on player, handles respawns correctly)
------------------------------------------------------------
local function GetOrCreatePlayerHighlight(pd)
    local cached = PlayerChamsCache[pd.Player]
    if cached then
        -- If character changed (respawn), destroy the old highlight
        if cached.char ~= pd.Character then
            pcall(function() cached.hl:Destroy() end)
            PlayerChamsCache[pd.Player] = nil; lastChamsProps[pd.Player] = nil
            cached = nil
        elseif not cached.hl.Parent then
            pcall(function() cached.hl:Destroy() end)
            PlayerChamsCache[pd.Player] = nil; lastChamsProps[pd.Player] = nil
            cached = nil
        else
            return cached.hl
        end
    end
    local ok, h = pcall(function()
        local hl = Instance.new("Highlight"); hl.Name = "AegisC"
        hl.Adornee = pd.Character; hl.Parent = pd.Character; return hl
    end)
    if ok and h then
        PlayerChamsCache[pd.Player] = {hl=h, char=pd.Character}; return h
    end
    return nil
end

local function RemovePlayerHighlight(player)
    local cached = PlayerChamsCache[player]
    if cached then pcall(function() cached.hl:Destroy() end); PlayerChamsCache[player] = nil end
    lastChamsProps[player] = nil
end

local function SetChamsProps(hl, player, fc, oc, ft, ot, dm)
    local last = lastChamsProps[player]
    if last and last.fc==fc and last.oc==oc and last.ft==ft and last.ot==ot and last.dm==dm then return end
    hl.FillColor=fc; hl.OutlineColor=oc; hl.FillTransparency=ft; hl.OutlineTransparency=ot; hl.DepthMode=dm; hl.Enabled=true
    lastChamsProps[player] = {fc=fc,oc=oc,ft=ft,ot=ot,dm=dm}
end

local function UpdatePlayerChams(pd)
    if pd.Player == LocalPlayer then RemovePlayerHighlight(pd.Player); return end
    local hum = GetHumanoid(pd.Character); if not hum or hum.Health <= 0 then RemovePlayerHighlight(pd.Player); return end
    if not Toggles.ChamsEnabled.Value then RemovePlayerHighlight(pd.Player); return end
    if pd.IsEnemy      and not Toggles.ChamsShowEnemy.Value  then RemovePlayerHighlight(pd.Player); return end
    if not pd.IsEnemy  and not pd.IsFriend and not Toggles.ChamsShowTeam.Value then RemovePlayerHighlight(pd.Player); return end
    if pd.IsFriend     and not Toggles.ChamsShowFriend.Value then RemovePlayerHighlight(pd.Player); return end
    local fc, oc, ft, ot
    if pd.IsFriend then
        fc=Options.ChamsFriendColor.Value; oc=Options.ChamsFriendOutline.Value; ft=Options.ChamsFriendTrans.Value; ot=Options.ChamsFriendOutlineTrans.Value
    elseif pd.IsEnemy then
        fc=Options.ChamsEnemyColor.Value; oc=Options.ChamsEnemyOutline.Value; ft=Options.ChamsEnemyTrans.Value; ot=Options.ChamsEnemyOutlineTrans.Value
    else
        fc=Options.ChamsTeamColor.Value; oc=Options.ChamsTeamOutline.Value; ft=Options.ChamsTeamTrans.Value; ot=Options.ChamsTeamOutlineTrans.Value
    end
    if Toggles.VisibleChamsEnabled.Value and IsCharacterVisible(pd.Character) then
        fc=Options.VisibleChamsColor.Value; oc=Options.VisibleChamsOutline.Value; ft=Options.VisibleChamsTrans.Value; ot=Options.VisibleOutlineTrans.Value
    end
    if Toggles.ChamsVisibleOnly.Value then
        if not IsCharacterVisible(pd.Character) then RemovePlayerHighlight(pd.Player); return end
        fc = pd.IsFriend and Options.VisibleFriendColor.Value or (pd.IsEnemy and Options.VisibleEnemyColor.Value or Options.VisibleTeamColor.Value)
    end
    local dm = Toggles.ChamsVisibleOnly.Value and Enum.HighlightDepthMode.Occluded or Enum.HighlightDepthMode.AlwaysOnTop
    local hl = GetOrCreatePlayerHighlight(pd); if not hl then return end
    SetChamsProps(hl, pd.Player, fc, oc, ft, ot, dm)
end

local function UpdateWorldChams()
    if not Toggles.ChamsWorldEnabled.Value then for i in pairs(WorldChamsCache) do
        pcall(function() WorldChamsCache[i]:Destroy() end); WorldChamsCache[i]=nil
    end; return end
    if tick()-S.lastWorldChamsUpdate < 0.5 then return end; S.lastWorldChamsUpdate = tick()

    -- Generic apply (pickups/HP/ammo — no team distinction)
    local function A(objs, co, oo, to, oto)
        for _, obj in pairs(objs) do
            if not obj.Parent then continue end
            if not WorldChamsCache[obj] then
                local ok, h = pcall(function()
                    local hl = Instance.new("Highlight"); hl.Name = "AWC"; hl.Adornee = obj; hl.Parent = obj; return hl
                end)
                if ok and h then WorldChamsCache[obj] = h end
            end
            local hl = WorldChamsCache[obj]; if not hl then continue end
            hl.FillColor=co.Value; hl.OutlineColor=oo.Value; hl.FillTransparency=to.Value; hl.OutlineTransparency=oto.Value
            hl.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop; hl.Enabled=true
        end
    end

    -- Team-aware apply (buildings)
    local function AB(objs, showEnemy, showTeam, eFill, eOut, eTrans, eOTrans, tFill, tOut, tTrans, tOTrans)
        for _, obj in pairs(objs) do
            if not obj.Parent then continue end
            local side = GetBuildingTeam(obj)
            local visible = (side == "enemy" and showEnemy.Value) or (side == "team" and showTeam.Value)
            if not visible then
                -- Hide if exists
                local hl = WorldChamsCache[obj]
                if hl then hl.Enabled = false end
                continue
            end
            if not WorldChamsCache[obj] then
                local ok, h = pcall(function()
                    local hl = Instance.new("Highlight"); hl.Name = "AWC"; hl.Adornee = obj; hl.Parent = obj; return hl
                end)
                if ok and h then WorldChamsCache[obj] = h end
            end
            local hl = WorldChamsCache[obj]; if not hl then continue end
            local isEnemy = (side == "enemy")
            hl.FillColor         = isEnemy and eFill.Value   or tFill.Value
            hl.OutlineColor      = isEnemy and eOut.Value    or tOut.Value
            hl.FillTransparency  = isEnemy and eTrans.Value  or tTrans.Value
            hl.OutlineTransparency = isEnemy and eOTrans.Value or tOTrans.Value
            hl.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop; hl.Enabled=true
        end
    end

    A(cachedHP,   Options.HealthChamsColor,  Options.HealthChamsOutline,  Options.HealthChamsTrans,  Options.HealthChamsOutlineTrans)
    A(cachedAmmo, Options.AmmoChamsColor,    Options.AmmoChamsOutline,    Options.AmmoChamsTrans,    Options.AmmoChamsOutlineTrans)

    AB(cachedSentries,
        Toggles.SentryChamsEnemy,    Toggles.SentryChamsTeam,
        Options.SentryChamsEnemyColor,  Options.SentryChamsEnemyOutline,  Options.SentryChamsEnemyTrans,  Options.SentryChamsEnemyOutlineTrans,
        Options.SentryChamsTeamColor,   Options.SentryChamsTeamOutline,   Options.SentryChamsTeamTrans,   Options.SentryChamsTeamOutlineTrans)
    AB(cachedDispensers,
        Toggles.DispenserChamsEnemy, Toggles.DispenserChamsTeam,
        Options.DispenserChamsEnemyColor, Options.DispenserChamsEnemyOutline, Options.DispenserChamsEnemyTrans, Options.DispenserChamsEnemyOutlineTrans,
        Options.DispenserChamsTeamColor,  Options.DispenserChamsTeamOutline,  Options.DispenserChamsTeamTrans,  Options.DispenserChamsTeamOutlineTrans)
    AB(cachedTeleporters,
        Toggles.TeleporterChamsEnemy, Toggles.TeleporterChamsTeam,
        Options.TeleporterChamsEnemyColor, Options.TeleporterChamsEnemyOutline, Options.TeleporterChamsEnemyTrans, Options.TeleporterChamsEnemyOutlineTrans,
        Options.TeleporterChamsTeamColor,  Options.TeleporterChamsTeamOutline,  Options.TeleporterChamsTeamTrans,  Options.TeleporterChamsTeamOutlineTrans)
end

local function UpdateProjectileChams()
    if not Toggles.ChamsProjectilesEnabled.Value then for i in pairs(ProjectileChamsCache) do
        pcall(function() ProjectileChamsCache[i]:Destroy() end); ProjectileChamsCache[i]=nil
    end; return end
    if tick()-S.lastProjChamsUpdate < 0.3 then return end; S.lastProjChamsUpdate = tick()
    for _, obj in pairs(GetProjectiles()) do
        if not ProjectileChamsCache[obj] then
            local ok, h = pcall(function()
                local hl = Instance.new("Highlight"); hl.Name = "APC"; hl.Adornee = obj; hl.Parent = obj; return hl
            end)
            if ok and h then ProjectileChamsCache[obj] = h end
        end
        local hl = ProjectileChamsCache[obj]; if not hl then continue end
        hl.FillColor=Options.ProjectileChamsColor.Value; hl.OutlineColor=Options.ProjectileChamsOutline.Value
        hl.FillTransparency=Options.ProjectileChamsTrans.Value; hl.OutlineTransparency=Options.ProjectileChamsOutlineTrans.Value
        hl.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop; hl.Enabled=true
    end
end


------------------------------------------------------------
-- GUN MOD HELPERS
------------------------------------------------------------
local _infAmmoConn1, _infAmmoConn2

local function SetupInfiniteAmmo(enabled)
    if _infAmmoConn1 then _infAmmoConn1:Disconnect(); _infAmmoConn1 = nil end
    if _infAmmoConn2 then _infAmmoConn2:Disconnect(); _infAmmoConn2 = nil end
    if not enabled then return end
    pcall(function()
        local L = LocalPlayer.PlayerGui.GUI.Client.LegacyLocalVariables
        _infAmmoConn1 = L.ammocount:GetPropertyChangedSignal("Value"):Connect(function()
            if not (Toggles.InfiniteAmmo and Toggles.InfiniteAmmo.Value) then return end
            local wep = ReplicatedStorage.Weapons:FindFirstChild(L.primary.Value)
            if wep and wep:FindFirstChild("Ammo") then L.ammocount.Value = wep.Ammo.Value end
        end)
        _infAmmoConn2 = L.ammocount2:GetPropertyChangedSignal("Value"):Connect(function()
            if not (Toggles.InfiniteAmmo and Toggles.InfiniteAmmo.Value) then return end
            local wep = ReplicatedStorage.Weapons:FindFirstChild(L.secondary.Value)
            if wep and wep:FindFirstChild("Ammo") then L.ammocount2.Value = wep.Ammo.Value end
        end)
    end)
end

local function SetFireRateMultiplier(mult)
    pcall(function()
        for _, wep in pairs(ReplicatedStorage.Weapons:GetChildren()) do
            local fr = wep:FindFirstChild("FireRate")
            if fr and WeaponSnapshot[wep.Name] and WeaponSnapshot[wep.Name].FireRate then
                local orig = WeaponSnapshot[wep.Name].FireRate
                fr.Value = wep:FindFirstChild("Projectile") and math.clamp(orig / mult, 0.1, 9e9) or (orig / mult)
            end
        end
    end)
end

local function RestoreFireRate()
    pcall(function()
        for _, wep in pairs(ReplicatedStorage.Weapons:GetChildren()) do
            local fr = wep:FindFirstChild("FireRate")
            if fr and WeaponSnapshot[wep.Name] and WeaponSnapshot[wep.Name].FireRate then
                fr.Value = WeaponSnapshot[wep.Name].FireRate
            end
        end
    end)
end

local function SetAutomatic(enabled)
    pcall(function()
        for _, wep in pairs(ReplicatedStorage.Weapons:GetChildren()) do
            local auto = wep:FindFirstChild("Auto")
            if auto then
                if enabled then
                    auto.Value = true
                elseif WeaponSnapshot[wep.Name] and WeaponSnapshot[wep.Name].Auto ~= nil then
                    auto.Value = WeaponSnapshot[wep.Name].Auto
                end
            end
        end
    end)
end

------------------------------------------------------------
-- BHOP
------------------------------------------------------------
local _bhopHeartbeat = nil

UserInputService.InputBegan:Connect(function(input, processed)
    if processed or Library.Unloaded then return end
    if input.KeyCode ~= Enum.KeyCode.Space then return end
    if not (Toggles.AutoBhop and Toggles.AutoBhop.Value) then return end
    if _bhopHeartbeat then _bhopHeartbeat:Disconnect(); _bhopHeartbeat = nil end
    _bhopHeartbeat = RunService.Heartbeat:Connect(function()
        if not (Toggles.AutoBhop and Toggles.AutoBhop.Value) then
            _bhopHeartbeat:Disconnect(); _bhopHeartbeat = nil; return
        end
        local char = LocalPlayer.Character; if not char then return end
        pcall(function()
            local L = LocalPlayer.PlayerGui.GUI.Client.LegacyLocalVariables
            if L.spinuptick.Value < 1 and (char:GetAttribute("Speed") or 0) > 0 then
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hum then hum.Jump = true end
            end
        end)
    end)
    while UserInputService:IsKeyDown(Enum.KeyCode.Space) and Toggles.AutoBhop and Toggles.AutoBhop.Value do
        task.wait()
    end
    if _bhopHeartbeat then _bhopHeartbeat:Disconnect(); _bhopHeartbeat = nil end
end)

------------------------------------------------------------
-- UI — AIMBOT TAB
------------------------------------------------------------
do
    local SG = Tabs.Aimbot:AddLeftGroupbox("Silent Aim", "crosshair")
    SG:AddToggle("SilentAimToggle", { Text="Enable Silent Aim", Default=false })
    Toggles.SilentAimToggle:OnChanged(function() Config.SilentAim.Enabled = Toggles.SilentAimToggle.Value end)
    SG:AddLabel("Aim Key"):AddKeyPicker("SilentAimKey", { Default="None", Mode="Hold", Text="Aim Key" })
    SG:AddToggle("AutoShoot",     { Text="Auto Shoot (while aiming)", Default=false })
    SG:AddToggle("SilentAimMobile", { Text="Mobile Mode (Always On)", Default=false })
    Toggles.SilentAimMobile:OnChanged(function()
        if Options.SilentAimKey then Options.SilentAimKey.Mode = Toggles.SilentAimMobile.Value and "Always" or "Hold" end
    end)
    SG:AddToggle("SilentIgnoreInvis", { Text="Ignore Invisible", Default=true })
    SG:AddSlider("SilentAimFOV",  { Text="FOV Radius", Default=200, Min=10, Max=800, Rounding=0 })
    SG:AddToggle("ShowFOVCircle", { Text="Show FOV Circle", Default=true })
    SG:AddLabel("FOV Color"):AddColorPicker("FOVColor", { Default=Color3.new(1,1,1), Title="FOV Color" })
    SG:AddDropdown("SilentAimSort", { Values={"Closest to Mouse","Closest Distance"}, Default="Closest to Mouse", Text="Sort Mode" })
    SG:AddDropdown("AimAtTargets", { Values={"Players","Sentry","Stickybomb"}, Default=1, Multi=true, Text="Aim At" })
    Options.AimAtTargets:SetValue({ Players=true })
    SG:AddDropdown("SilentAimBodyParts", { Values={"Head","Chest","Torso","Arms","Legs","Feet"}, Default=1, Multi=true, Text="Body Parts" })
    Options.SilentAimBodyParts:SetValue({ Head=true })
    SG:AddDivider()
    SG:AddToggle("SilentAimArms", { Text="Aim Arms", Default=false })
    SG:AddDropdown("SilentAimArmsMode", { Values={"Snap","Smooth"}, Default="Snap", Text="Arms Mode" })
end

do
    local PI = Tabs.Aimbot:AddLeftGroupbox("Prediction Indicator", "activity")
    PI:AddToggle("ShowPredictionIndicator", { Text="Show Prediction Indicator", Default=false })
    PI:AddDropdown("PredictionIndicatorSymbol", { Values={"+","*","•","×"}, Default="+", Text="Symbol" })
    PI:AddLabel("Indicator Color"):AddColorPicker("PredictionIndicatorColor", { Default=Color3.new(0,1,1), Title="Indicator Color" })
end

do
    local NG = Tabs.Aimbot:AddLeftGroupbox("Notifications", "bell")
    NG:AddToggle("ShowHits",       { Text="Show Hits",    Default=false, Callback=function(v) Config.Notifications.ShowHits=v end })
    NG:AddToggle("EnableFlags",    { Text="Hit Flags",    Default=false, Callback=function(v) Config.Flags.Enabled=v end })
    NG:AddToggle("ShowDamage",     { Text="Show Damage",  Default=false, Callback=function(v) Config.Flags.ShowDamage=v end })
    NG:AddToggle("ShowRemainingHp",{ Text="Remaining HP", Default=false, Callback=function(v) Config.Flags.ShowRemainingHealth=v end })
    NG:AddToggle("ShowHitName",    { Text="Show Name",    Default=false, Callback=function(v) Config.Flags.ShowName=v end })
end

------------------------------------------------------------
-- UI — VISUALS TAB
------------------------------------------------------------
do
    local ETB  = Tabs.Visuals:AddLeftTabbox()
    local ESPT = ETB:AddTab("Player ESP")
    ESPT:AddToggle("ESPEnabled",     { Text="Enable ESP",       Default=false })
    ESPT:AddToggle("ESPEnemy",       { Text="Show Enemy",       Default=true })
    ESPT:AddToggle("ESPTeam",        { Text="Show Team",        Default=false })
    ESPT:AddToggle("ESPFriends",     { Text="Show Friends",     Default=true })
    ESPT:AddToggle("ESPIgnoreInvis", { Text="Ignore Invisible", Default=true })
    ESPT:AddDivider()
    ESPT:AddDropdown("ESPBoxType",    { Values={"None","2D","3D","Corners"}, Default=2, Text="Box Type" })
    ESPT:AddLabel("Box Color"):AddColorPicker("ESPBoxColor", { Default=Color3.new(1,0,0), Title="Box Color" })
    ESPT:AddToggle("ESPDistance",     { Text="Distance",      Default=false })
    ESPT:AddToggle("ESPSkeleton",     { Text="Skeleton",      Default=false })
    ESPT:AddToggle("ESPWeapon",       { Text="Weapon",        Default=false })
    ESPT:AddToggle("ESPClass",        { Text="Class",         Default=false })
    ESPT:AddToggle("ESPHealthValue",  { Text="Health Value",  Default=false })
    ESPT:AddToggle("ESPHealthBar",    { Text="Health Bar",    Default=false })
    ESPT:AddToggle("ESPHealthPercent",{ Text="Health %",      Default=false })
    ESPT:AddToggle("ESPStatus",       { Text="Status Effects",Default=false })
    ESPT:AddDivider()
    ESPT:AddToggle("ESPTracer",       { Text="Tracers",       Default=false })
    ESPT:AddLabel("Tracer Color"):AddColorPicker("ESPTracerColor", { Default=Color3.new(1,0,0), Title="Tracer" })
    ESPT:AddDropdown("ESPTracerOrigin", { Values={"Bottom","Center","Top"}, Default="Bottom", Text="Origin" })

    local ESPO = ETB:AddTab("Object ESP")
    ESPO:AddToggle("ObjESPEnabled",    { Text="Enable Object ESP", Default=false })
    ESPO:AddDivider()
    -- Enemy buildings
    ESPO:AddToggle("ObjESPEnemySentry",     { Text="Enemy Sentry",      Default=false })
    ESPO:AddToggle("ObjESPEnemyDispenser",  { Text="Enemy Dispenser",   Default=false })
    ESPO:AddToggle("ObjESPEnemyTeleporter", { Text="Enemy Teleporter",  Default=false })
    ESPO:AddDivider()
    -- Team buildings
    ESPO:AddToggle("ObjESPTeamSentry",      { Text="Team Sentry",       Default=false })
    ESPO:AddToggle("ObjESPTeamDispenser",   { Text="Team Dispenser",    Default=false })
    ESPO:AddToggle("ObjESPTeamTeleporter",  { Text="Team Teleporter",   Default=false })
    ESPO:AddDivider()
    -- Pickups (no team distinction)
    ESPO:AddToggle("ObjESPAmmo",            { Text="Ammo",              Default=false })
    ESPO:AddToggle("ObjESPHP",              { Text="Health Packs",      Default=false })
    ESPO:AddDivider()
    ESPO:AddLabel("Enemy Color"):AddColorPicker("ObjESPEnemyColor",  { Default=Color3.new(1,0.2,0.2), Title="Enemy Color" })
    ESPO:AddLabel("Team Color"):AddColorPicker("ObjESPTeamColor",    { Default=Color3.new(0.2,0.6,1), Title="Team Color" })
    ESPO:AddLabel("Pickup Color"):AddColorPicker("ObjESPBoxColor",   { Default=Color3.new(1,1,0), Title="Pickup Color" })
    ESPO:AddToggle("ObjESPHealthValue",   { Text="Health Value", Default=false })
    ESPO:AddToggle("ObjESPHealthBar",     { Text="Health Bar",   Default=false })
    ESPO:AddToggle("ObjESPHealthPercent", { Text="Health %",     Default=false })
end

do
    local CTB = Tabs.Visuals:AddLeftTabbox()
    local CT  = CTB:AddTab("Player Chams")
    CT:AddToggle("ChamsEnabled",    { Text="Enable Chams",  Default=false })
    CT:AddToggle("ChamsShowEnemy",  { Text="Show Enemy",    Default=true })
    CT:AddToggle("ChamsShowTeam",   { Text="Show Team",     Default=false })
    CT:AddToggle("ChamsShowFriend", { Text="Show Friends",  Default=true })
    CT:AddDivider()
    CT:AddLabel("Enemy Fill"):AddColorPicker("ChamsEnemyColor",    { Default=Color3.new(1,0,0) })
    CT:AddLabel("Enemy Outline"):AddColorPicker("ChamsEnemyOutline",{ Default=Color3.new(0.5,0,0) })
    CT:AddSlider("ChamsEnemyTrans",       { Text="Enemy Fill Trans",    Default=0, Min=0, Max=1, Rounding=2 })
    CT:AddSlider("ChamsEnemyOutlineTrans",{ Text="Enemy Outline Trans", Default=0, Min=0, Max=1, Rounding=2 })
    CT:AddDivider()
    CT:AddLabel("Team Fill"):AddColorPicker("ChamsTeamColor",    { Default=Color3.new(0,0,1) })
    CT:AddLabel("Team Outline"):AddColorPicker("ChamsTeamOutline",{ Default=Color3.new(0,0,0.5) })
    CT:AddSlider("ChamsTeamTrans",       { Text="Team Fill Trans",    Default=0, Min=0, Max=1, Rounding=2 })
    CT:AddSlider("ChamsTeamOutlineTrans",{ Text="Team Outline Trans", Default=0, Min=0, Max=1, Rounding=2 })
    CT:AddDivider()
    CT:AddLabel("Friend Fill"):AddColorPicker("ChamsFriendColor",    { Default=Color3.new(0,1,0) })
    CT:AddLabel("Friend Outline"):AddColorPicker("ChamsFriendOutline",{ Default=Color3.new(0,0.5,0) })
    CT:AddSlider("ChamsFriendTrans",       { Text="Friend Fill Trans",    Default=0, Min=0, Max=1, Rounding=2 })
    CT:AddSlider("ChamsFriendOutlineTrans",{ Text="Friend Outline Trans", Default=0, Min=0, Max=1, Rounding=2 })

    local VT = CTB:AddTab("Visible Chams")
    VT:AddToggle("VisibleChamsEnabled", { Text="Visible Chams Override", Default=false })
    VT:AddLabel("Visible Fill"):AddColorPicker("VisibleChamsColor",    { Default=Color3.new(1,1,0) })
    VT:AddLabel("Visible Outline"):AddColorPicker("VisibleChamsOutline",{ Default=Color3.new(0.5,0.5,0) })
    VT:AddSlider("VisibleChamsTrans",  { Text="Fill Trans",    Default=0, Min=0, Max=1, Rounding=2 })
    VT:AddSlider("VisibleOutlineTrans",{ Text="Outline Trans", Default=0, Min=0, Max=1, Rounding=2 })
    VT:AddDivider()
    VT:AddToggle("ChamsVisibleOnly", { Text="Visible Only Mode", Default=false })
    VT:AddLabel("Vis Enemy"):AddColorPicker("VisibleEnemyColor",  { Default=Color3.new(1,0,0) })
    VT:AddLabel("Vis Team"):AddColorPicker("VisibleTeamColor",    { Default=Color3.new(0,0,1) })
    VT:AddLabel("Vis Friend"):AddColorPicker("VisibleFriendColor",{ Default=Color3.new(0,1,0) })
end

do
    local WG = Tabs.Visuals:AddRightGroupbox("World Chams", "layers")
    WG:AddToggle("ChamsWorldEnabled", { Text="World Chams", Default=false })
    WG:AddLabel("HP Fill"):AddColorPicker("HealthChamsColor",    { Default=Color3.new(0,1,0) })
    WG:AddLabel("HP Outline"):AddColorPicker("HealthChamsOutline",{ Default=Color3.new(0,0.5,0) })
    WG:AddSlider("HealthChamsTrans",       { Text="HP Fill Trans",    Default=0.5, Min=0, Max=1, Rounding=2 })
    WG:AddSlider("HealthChamsOutlineTrans",{ Text="HP Outline Trans", Default=0.5, Min=0, Max=1, Rounding=2 })
    WG:AddDivider()
    WG:AddLabel("Ammo Fill"):AddColorPicker("AmmoChamsColor",    { Default=Color3.new(1,0.5,0) })
    WG:AddLabel("Ammo Outline"):AddColorPicker("AmmoChamsOutline",{ Default=Color3.new(0.5,0.25,0) })
    WG:AddSlider("AmmoChamsTrans",       { Text="Ammo Fill Trans",    Default=0.5, Min=0, Max=1, Rounding=2 })
    WG:AddSlider("AmmoChamsOutlineTrans",{ Text="Ammo Outline Trans", Default=0.5, Min=0, Max=1, Rounding=2 })
    WG:AddDivider()
    -- Sentry
    WG:AddToggle("SentryChamsEnemy", { Text="Enemy Sentry",  Default=false })
    WG:AddToggle("SentryChamsTeam",  { Text="Team Sentry",   Default=false })
    WG:AddLabel("Enemy Sentry Fill"):AddColorPicker("SentryChamsEnemyColor",    { Default=Color3.new(1,0,0) })
    WG:AddLabel("Enemy Sentry Outline"):AddColorPicker("SentryChamsEnemyOutline",{ Default=Color3.new(0.5,0,0) })
    WG:AddSlider("SentryChamsEnemyTrans",       { Text="Enemy Fill Trans",    Default=0.5, Min=0, Max=1, Rounding=2 })
    WG:AddSlider("SentryChamsEnemyOutlineTrans",{ Text="Enemy Outline Trans", Default=0.5, Min=0, Max=1, Rounding=2 })
    WG:AddLabel("Team Sentry Fill"):AddColorPicker("SentryChamsTeamColor",    { Default=Color3.new(0,0.5,1) })
    WG:AddLabel("Team Sentry Outline"):AddColorPicker("SentryChamsTeamOutline",{ Default=Color3.new(0,0.25,0.5) })
    WG:AddSlider("SentryChamsTeamTrans",       { Text="Team Fill Trans",    Default=0.5, Min=0, Max=1, Rounding=2 })
    WG:AddSlider("SentryChamsTeamOutlineTrans",{ Text="Team Outline Trans", Default=0.5, Min=0, Max=1, Rounding=2 })
    WG:AddDivider()
    -- Dispenser
    WG:AddToggle("DispenserChamsEnemy", { Text="Enemy Dispenser",  Default=false })
    WG:AddToggle("DispenserChamsTeam",  { Text="Team Dispenser",   Default=false })
    WG:AddLabel("Enemy Dispenser Fill"):AddColorPicker("DispenserChamsEnemyColor",    { Default=Color3.new(1,0.3,0) })
    WG:AddLabel("Enemy Dispenser Outline"):AddColorPicker("DispenserChamsEnemyOutline",{ Default=Color3.new(0.5,0.15,0) })
    WG:AddSlider("DispenserChamsEnemyTrans",       { Text="Enemy Fill Trans",    Default=0.5, Min=0, Max=1, Rounding=2 })
    WG:AddSlider("DispenserChamsEnemyOutlineTrans",{ Text="Enemy Outline Trans", Default=0.5, Min=0, Max=1, Rounding=2 })
    WG:AddLabel("Team Dispenser Fill"):AddColorPicker("DispenserChamsTeamColor",    { Default=Color3.new(0,1,0.5) })
    WG:AddLabel("Team Dispenser Outline"):AddColorPicker("DispenserChamsTeamOutline",{ Default=Color3.new(0,0.5,0.25) })
    WG:AddSlider("DispenserChamsTeamTrans",       { Text="Team Fill Trans",    Default=0.5, Min=0, Max=1, Rounding=2 })
    WG:AddSlider("DispenserChamsTeamOutlineTrans",{ Text="Team Outline Trans", Default=0.5, Min=0, Max=1, Rounding=2 })
    WG:AddDivider()
    -- Teleporter
    WG:AddToggle("TeleporterChamsEnemy", { Text="Enemy Teleporter",  Default=false })
    WG:AddToggle("TeleporterChamsTeam",  { Text="Team Teleporter",   Default=false })
    WG:AddLabel("Enemy Tele Fill"):AddColorPicker("TeleporterChamsEnemyColor",    { Default=Color3.new(1,0,1) })
    WG:AddLabel("Enemy Tele Outline"):AddColorPicker("TeleporterChamsEnemyOutline",{ Default=Color3.new(0.5,0,0.5) })
    WG:AddSlider("TeleporterChamsEnemyTrans",       { Text="Enemy Fill Trans",    Default=0.5, Min=0, Max=1, Rounding=2 })
    WG:AddSlider("TeleporterChamsEnemyOutlineTrans",{ Text="Enemy Outline Trans", Default=0.5, Min=0, Max=1, Rounding=2 })
    WG:AddLabel("Team Tele Fill"):AddColorPicker("TeleporterChamsTeamColor",    { Default=Color3.new(0,0.8,1) })
    WG:AddLabel("Team Tele Outline"):AddColorPicker("TeleporterChamsTeamOutline",{ Default=Color3.new(0,0.4,0.5) })
    WG:AddSlider("TeleporterChamsTeamTrans",       { Text="Team Fill Trans",    Default=0.5, Min=0, Max=1, Rounding=2 })
    WG:AddSlider("TeleporterChamsTeamOutlineTrans",{ Text="Team Outline Trans", Default=0.5, Min=0, Max=1, Rounding=2 })
    WG:AddDivider()
    WG:AddToggle("ChamsProjectilesEnabled", { Text="Projectile Chams", Default=false })
    WG:AddLabel("Projectile Fill"):AddColorPicker("ProjectileChamsColor",    { Default=Color3.new(1,1,0) })
    WG:AddLabel("Projectile Outline"):AddColorPicker("ProjectileChamsOutline",{ Default=Color3.new(0.5,0.5,0) })
    WG:AddSlider("ProjectileChamsTrans",       { Text="Projectile Fill Trans",    Default=0.5, Min=0, Max=1, Rounding=2 })
    WG:AddSlider("ProjectileChamsOutlineTrans",{ Text="Projectile Outline Trans", Default=0.5, Min=0, Max=1, Rounding=2 })
end

local OL
do
    local VR = Tabs.Visuals:AddRightGroupbox("World Visuals", "sun")
    VR:AddInput("SkyboxID", { Default="", Numeric=true, Finished=true, Text="Skybox ID", Placeholder="Asset ID" })
    VR:AddSlider("TimeSlider", { Text="Time of Day", Default=12, Min=0, Max=24, Rounding=1, Suffix=" hrs" })
    VR:AddLabel("Ambient"):AddColorPicker("AmbientColor", { Default=Lighting.Ambient, Title="Ambient" })
    VR:AddToggle("FullbrightToggle", { Text="Fullbright",          Default=false })
    VR:AddToggle("NoFogToggle",      { Text="No Fog",              Default=false })
    VR:AddToggle("SightlinesToggle", { Text="Marksman Sightlines", Default=false })

    OL = {Ambient=Lighting.Ambient, Brightness=Lighting.Brightness, FogEnd=Lighting.FogEnd,
          FogStart=Lighting.FogStart, ClockTime=Lighting.ClockTime, OutdoorAmbient=Lighting.OutdoorAmbient}

    local function ApplySkybox(id)
        if id == "" then return end
        pcall(function()
            local sk = Lighting:FindFirstChildOfClass("Sky")
            if not sk then sk = Instance.new("Sky"); sk.Parent = Lighting end
            local a = "rbxassetid://"..id
            sk.SkyboxBk=a; sk.SkyboxDn=a; sk.SkyboxFt=a; sk.SkyboxLf=a; sk.SkyboxRt=a; sk.SkyboxUp=a
        end)
    end
    Options.SkyboxID:OnChanged(function() ApplySkybox(Options.SkyboxID.Value) end)
    Options.TimeSlider:OnChanged(function() Lighting.ClockTime = Options.TimeSlider.Value end)
    Options.AmbientColor:OnChanged(function()
        if not Toggles.FullbrightToggle.Value then Lighting.Ambient=Options.AmbientColor.Value; Lighting.OutdoorAmbient=Options.AmbientColor.Value end
    end)
    Toggles.FullbrightToggle:OnChanged(function()
        if Toggles.FullbrightToggle.Value then Lighting.Brightness=2; Lighting.Ambient=Color3.new(1,1,1); Lighting.OutdoorAmbient=Color3.new(1,1,1)
        else Lighting.Brightness=OL.Brightness; Lighting.Ambient=Options.AmbientColor.Value; Lighting.OutdoorAmbient=Options.AmbientColor.Value end
    end)
    Toggles.NoFogToggle:OnChanged(function()
        if Toggles.NoFogToggle.Value then Lighting.FogEnd=1e10; Lighting.FogStart=1e10
        else Lighting.FogEnd=OL.FogEnd; Lighting.FogStart=OL.FogStart end
    end)
    task.spawn(function() while true do task.wait(1); if Library.Unloaded then break end
        if Options.SkyboxID.Value ~= "" then ApplySkybox(Options.SkyboxID.Value) end
        Lighting.ClockTime = Options.TimeSlider.Value
        if Toggles.FullbrightToggle.Value then Lighting.Brightness=2; Lighting.Ambient=Color3.new(1,1,1); Lighting.OutdoorAmbient=Color3.new(1,1,1)
        else Lighting.Ambient=Options.AmbientColor.Value; Lighting.OutdoorAmbient=Options.AmbientColor.Value end
        if Toggles.NoFogToggle.Value then Lighting.FogEnd=1e10; Lighting.FogStart=1e10 end
    end end)
end

------------------------------------------------------------
-- UI — MISC TAB
------------------------------------------------------------
do
    local ML = Tabs.Misc:AddLeftGroupbox("Misc", "wrench")
    ML:AddToggle("AegisStatus", { Text="Aegis Status", Default=false,
        Tooltip="Makes you visible to other Aegis users, even those with this option off." })
    Toggles.AegisStatus:OnChanged(function(v)
        if v then StampAegisCharacter(LocalPlayer.Character)
        else pcall(function() LocalPlayer.Character:SetAttribute(AEGIS_ATTR, nil) end) end
    end)
    ML:AddDivider()
    ML:AddToggle("UsernameHider", { Text="Username Hider", Default=false })
    ML:AddInput("FakeUsername", { Default="Player", Numeric=false, Finished=false, Text="Fake Name", Placeholder="Name" })
    ML:AddDivider()
    ML:AddToggle("AgentNotification", { Text="Agent Nearby Notification", Default=false })
    ML:AddDivider()
    -- Movement
    ML:AddToggle("AutoBhop",     { Text="Auto Bhop",      Default=false })
    ML:AddToggle("NoFallDamage", { Text="No Fall Damage", Default=false })
    ML:AddDivider()
    -- Backstab / Melee
    ML:AddToggle("AutoBackstab",        { Text="Auto Backstab",    Default=false })
    ML:AddToggle("BackstabIgnoreInvis", { Text="Ignore Invisible (BS)", Default=true })
    ML:AddToggle("AutoWarp",            { Text="Auto Warp Behind", Default=false })
    ML:AddLabel("Warp Key"):AddKeyPicker("WarpKey", { Default="None", Mode="Toggle", Text="Warp" })
    ML:AddDivider()
    ML:AddToggle("AutoMelee",        { Text="Auto Melee",            Default=false })
    ML:AddToggle("MeleeIgnoreInvis", { Text="Ignore Invisible (Melee)", Default=true })
    ML:AddDropdown("AutoMeleeMode",  { Values={"Rage","Demoknight"}, Default="Rage", Text="Melee Mode" })
end

do
    local MR = Tabs.Misc:AddRightGroupbox("VIP / Other", "crown")
    MR:AddToggle("NoVoiceCooldown", { Text="No Voice Cooldown", Default=false,
        Callback=function(v) pcall(function() ReplicatedStorage.VIPSettings.NoVoiceCooldown.Value=v end) end })
    MR:AddToggle("ThirdPersonMode", { Text="Third Person", Default=false,
        Callback=function(v) ApplyThirdPerson(v) end })
    MR:AddToggle("HealSelfToggle",  { Text="Heal Self [Medic]", Default=false })
    MR:AddLabel("Heal Self Bind"):AddKeyPicker("HealSelfKey", { Default="None", Mode="Toggle", Text="Heal Self" })
    MR:AddDivider()
    -- Device Spoofer
    MR:AddToggle("DeviceSpoofEnabled", { Text="Device Spoofer", Default=false,
        Tooltip="Client side only — does not affect server-side platform checks." })
    MR:AddDropdown("DeviceSpoofer", { Values={"Desktop","Mobile","Xbox","Tablet"}, Default="Desktop", Text="Platform" })
    Toggles.DeviceSpoofEnabled:OnChanged(function(v)
        if v then
            ApplyDeviceSpoof(Options.DeviceSpoofer.Value)
            Notify("Spoofed device to: "..Options.DeviceSpoofer.Value, 3)
        end
    end)
    Options.DeviceSpoofer:OnChanged(function()
        if Toggles.DeviceSpoofEnabled and Toggles.DeviceSpoofEnabled.Value then
            ApplyDeviceSpoof(Options.DeviceSpoofer.Value)
            Notify("Spoofed device to: "..Options.DeviceSpoofer.Value, 3)
        end
    end)
    MR:AddDivider()
    -- Server
    MR:AddButton({ Text="Aegis Server", Tooltip="Aegis Server is closed right now." }, function()
        Notify("Aegis Server is currently closed.", 4)
    end)
end

do
    local MA = Tabs.Misc:AddRightGroupbox("Automation", "cpu")
    MA:AddToggle("AutoStickyDetonate",  { Text="Auto Sticky Detonate", Default=false,
        Tooltip="Buggy" })
    MA:AddToggle("AutoStickyVisibleOnly",{ Text="Visible Only (Sticky)", Default=false })
    MA:AddDivider()
    MA:AddToggle("AutoAirblast",    { Text="Auto Airblast",        Default=false })
    MA:AddToggle("AutoAirblastExt", { Text="Extinguish Teammates", Default=false })
    MA:AddDivider()
    MA:AddToggle("AutoUberToggle", { Text="Auto Uber [Doctor]", Default=false })
    Toggles.AutoUberToggle:OnChanged(function() Config.AutoUber.Enabled = Toggles.AutoUberToggle.Value end)
    MA:AddSlider("AutoUberHealthPercent", { Text="Health Threshold", Default=40, Min=5, Max=100, Rounding=0, Suffix="%" })
    Options.AutoUberHealthPercent:OnChanged(function() Config.AutoUber.HealthPercent = Options.AutoUberHealthPercent.Value end)
    MA:AddDropdown("AutoUberCondition", { Values={"Self","HealTarget","Both"}, Default="Both", Text="Condition" })
    Options.AutoUberCondition:OnChanged(function() Config.AutoUber.Condition = Options.AutoUberCondition.Value end)
end

------------------------------------------------------------
-- UI — EXPLOITS TAB
------------------------------------------------------------
do
    local EL = Tabs.Exploits:AddLeftGroupbox("Exploits", "zap")

    EL:AddLabel("Anti-Aim"):AddKeyPicker("AAKeybind", { Default="None", Mode="Toggle", Text="Anti-Aim",
        Callback=function(v) Config.AntiAim.Enabled = v end })
    EL:AddDropdown("AAMode",    { Values={"jitter","backwards","spin"}, Default="jitter", Text="Mode",         Callback=function(v) Config.AntiAim.Mode=v end })
    EL:AddSlider("JitterAngle", { Text="Jitter Angle", Default=90,  Min=0,   Max=180,  Rounding=0, Callback=function(v) Config.AntiAim.JitterAngle=v end })
    EL:AddSlider("JitterSpeed", { Text="Jitter Speed", Default=15,  Min=1,   Max=60,   Rounding=0, Callback=function(v) Config.AntiAim.JitterSpeed=v end })
    EL:AddSlider("SpinSpeed",   { Text="Spin Speed",   Default=180, Min=1,   Max=1080, Rounding=0, Callback=function(v) Config.AntiAim.AntiAimSpeed=v end })
    EL:AddDivider()

    EL:AddToggle("WallbangToggle", { Text="Wallbang", Default=false, Tooltip="Broken rn",
        Callback=function(v)
            Config.Wallbang.Enable = v
            if v then InstallWallbangHook() else RemoveWallbangHook() end
        end })
    EL:AddToggle("NoSpreadToggle", { Text="No Spread", Default=false,
        Callback=function(v)
            Config.NoSpread.Enable = v
            if v then EnsureGUILoaded(); SetupNoSpread()
                if S.kirk then S.charlieKirk=true; S.kirk.Value=S.kirk.Value*Config.NoSpread.Multiplier; S.charlieKirk=false end
            end
        end })
    EL:AddSlider("SpreadMultiplier", { Text="Spread Multiplier", Default=0.2, Min=0.2, Max=1, Rounding=2, Callback=function(v) Config.NoSpread.Multiplier=v end })
    EL:AddDivider()

    EL:AddToggle("SpeedToggle", { Text="Speed", Default=false })
        :AddKeyPicker("SpeedKey", { Default="None", Mode="Toggle", Text="Speed", SyncToggleState=true })
    Toggles.SpeedToggle:OnChanged(function()
        Config.Speed.Enable = Toggles.SpeedToggle.Value; SetupSpeed()
        if not Toggles.SpeedToggle.Value and S.speedConnection then S.speedConnection:Disconnect(); S.speedConnection=nil end
    end)
    EL:AddSlider("SpeedValue", { Text="Speed Value", Default=300, Min=1, Max=600, Rounding=0,
        Callback=function(v) Config.Speed.Value=v; if Config.Speed.Enable and LocalPlayer.Character then LocalPlayer.Character:SetAttribute("Speed",v) end end })
end

do
    local TL = Tabs.Exploits:AddLeftGroupbox("Telestab", "move")
    TL:AddToggle("TelestabToggle", { Text="Telestab", Default=false })
    TL:AddLabel("Telestab Bind"):AddKeyPicker("TelestabKey", { Default="None", Mode="Hold", Text="Telestab" })
end

do
    local GM = Tabs.Exploits:AddRightGroupbox("Gun Mods", "package")
    GM:AddToggle("InfiniteAmmo", { Text="Infinite Ammo", Default=false,
        Callback=function(v) SetupInfiniteAmmo(v) end })
    GM:AddDivider()
    GM:AddToggle("FastGun", { Text="Fast Gun", Default=false,
        Callback=function(v)
            if v then SetFireRateMultiplier(Options.FireRateMultiplier.Value)
            else RestoreFireRate() end
        end })
    GM:AddSlider("FireRateMultiplier", { Text="Fire Rate", Default=1, Min=1, Max=25, Rounding=1, Suffix="x",
        Callback=function(v)
            if Toggles.FastGun and Toggles.FastGun.Value then SetFireRateMultiplier(v) end
        end })
    GM:AddDivider()
    GM:AddToggle("AutomaticToggle", { Text="Automatic", Default=false,
        Callback=function(v) SetAutomatic(v) end })
end

task.spawn(function() while true do task.wait(2); if Library.Unloaded then break end
    pcall(function()
        if Toggles.NoVoiceCooldown and Toggles.NoVoiceCooldown.Value then ReplicatedStorage.VIPSettings.NoVoiceCooldown.Value=true end
        if Toggles.ThirdPersonMode and Toggles.ThirdPersonMode.Value then local v=ReplicatedStorage:FindFirstChild("VIPSettings"); if v then local t=v:FindFirstChild("AThirdPersonMode"); if t then t.Value=true end end end
        if Toggles.DeviceSpoofEnabled and Toggles.DeviceSpoofEnabled.Value then ApplyDeviceSpoof(Options.DeviceSpoofer.Value) end
    end)
end end)

------------------------------------------------------------
-- UI — SETTINGS TAB
------------------------------------------------------------
do
    local SL = Tabs.Settings:AddLeftGroupbox("FOV", "maximize")
    SL:AddToggle("CustomFOV", { Text="Custom FOV", Default=false })
    SL:AddSlider("CustomFOVAmount", { Text="FOV", Default=90, Min=40, Max=120, Rounding=0, Suffix="°" })
    Toggles.CustomFOV:OnChanged(function() if Toggles.CustomFOV.Value then Camera.FieldOfView=Options.CustomFOVAmount.Value end end)
    Options.CustomFOVAmount:OnChanged(function() if Toggles.CustomFOV.Value then Camera.FieldOfView=Options.CustomFOVAmount.Value end end)
    Camera:GetPropertyChangedSignal("FieldOfView"):Connect(function() if Toggles.CustomFOV.Value then Camera.FieldOfView=Options.CustomFOVAmount.Value end end)
end

do
    local MG = Tabs.Settings:AddLeftGroupbox("Mobile", "smartphone")
    MG:AddToggle("MobileModeToggle", { Text="Mobile Mode", Default=isMobileDevice })
    Toggles.MobileModeToggle:OnChanged(function()
        isMobileMode = Toggles.MobileModeToggle.Value
        if isMobileMode then CreateMobileButton() else DestroyMobileButton() end
    end)
    if isMobileDevice then task.defer(function() task.wait(1); if Toggles.MobileModeToggle then Toggles.MobileModeToggle:SetValue(true) end end) end
end

------------------------------------------------------------
-- AUTOMATION LOGIC
------------------------------------------------------------
local function UpdateUsernameHider()
    if not Toggles.UsernameHider.Value then return end
    if tick()-S.lastUsernameUpdate < 1 then return end; S.lastUsernameUpdate = tick()
    local fn = Options.FakeUsername.Value ~= "" and Options.FakeUsername.Value or "Player"
    pcall(function()
        local pg = LocalPlayer:FindFirstChild("PlayerGui"); if not pg then return end
        for _, g in pairs(pg:GetDescendants()) do
            if g:IsA("TextLabel") and (g.Text==LocalPlayer.Name or g.Text==LocalPlayer.DisplayName) then g.Text=fn end
        end
    end)
end

local function CheckAutoUber()
    if not Config.AutoUber.Enabled then return end
    if not IsPlayerAlive(LocalPlayer) then return end
    pcall(function()
        if LocalPlayer:FindFirstChild("Status") and LocalPlayer.Status.Class.Value ~= "Doctor" then return end
        local char = LocalPlayer.Character; if not char then return end
        local hum  = GetHumanoid(char); if not hum or hum.Health <= 0 then return end
        local uberReady = false
        pcall(function()
            local L = LocalPlayer.PlayerGui.GUI.Client.LegacyLocalVariables
            local uber = L:FindFirstChild("uber"); if uber and uber.Value >= 100 then uberReady=true end
        end)
        if not uberReady then return end
        local myPct = (hum.Health/hum.MaxHealth)*100; local threshold=Config.AutoUber.HealthPercent
        if Config.AutoUber.Condition=="Self" or Config.AutoUber.Condition=="Both" then
            if myPct <= threshold then RightClick(); return end
        end
        if Config.AutoUber.Condition=="HealTarget" or Config.AutoUber.Condition=="Both" then
            pcall(function()
                local L  = LocalPlayer.PlayerGui.GUI.Client.LegacyLocalVariables
                local ht = L:FindFirstChild("healtarget"); if not ht or ht.Value=="" then return end
                local tp = Players:FindFirstChild(ht.Value)
                if tp and tp.Character then
                    local th = GetHumanoid(tp.Character)
                    if th and (th.Health/th.MaxHealth)*100 <= threshold then RightClick() end
                end
            end)
        end
    end)
end

local function RunAutoAirblast()
    if not (Toggles.AutoAirblast and Toggles.AutoAirblast.Value) then return end
    if tick()-S.lastAirblastTime < 0.2 then return end
    if not IsPlayerAlive(LocalPlayer) then return end
    pcall(function()
        if LocalPlayer:FindFirstChild("Status") and LocalPlayer.Status.Class.Value ~= "Arsonist" then return end
        local lc=GetLocalCharacter(); if not lc then return end
        local lhrp=GetHRP(lc); if not lhrp then return end
        local ri = Workspace:FindFirstChild("Ray_ignore")
        if ri then for _, v in pairs(ri:GetChildren()) do
            if v:GetAttribute("ProjectileType") and v:GetAttribute("Team") ~= LocalPlayer.Status.Team.Value then
                local _, OnScr = Camera:WorldToViewportPoint(v.Position)
                if OnScr and (v.Position-lhrp.Position).Magnitude <= 13 then
                    RightClick(); S.lastAirblastTime=tick(); return
                end
            end
        end end
        local dest = Workspace:FindFirstChild("Destructable")
        if dest then for _, v in pairs(dest:GetChildren()) do
            if v.Name:match("stickybomb") and v:GetAttribute("Team") ~= LocalPlayer.Status.Team.Value then
                local _, OnScr = Camera:WorldToViewportPoint(v.Position)
                if OnScr and (v.Position-lhrp.Position).Magnitude <= 13 then
                    RightClick(); S.lastAirblastTime=tick(); return
                end
            end
        end end
        if Toggles.AutoAirblastExt and Toggles.AutoAirblastExt.Value then
            for _, plr in pairs(cachedPlayerList) do
                if plr ~= LocalPlayer and plr.Character and plr.Team==LocalPlayer.Team then
                    local conds = plr.Character:FindFirstChild("Conditions")
                    if conds and conds:GetAttribute("Engulfed") then
                        local head = plr.Character:FindFirstChild("Head")
                        if head and (head.Position-lhrp.Position).Magnitude <= 13 then
                            RightClick(); S.lastAirblastTime=tick(); return
                        end
                    end
                end
            end
        end
    end)
end

local function RunSilentAimLogic()
    if not Config.SilentAim.Enabled then S.silentAimKeyActive = false; return end
    S.silentAimKeyActive = isMobileMode or Options.SilentAimKey:GetState()

    if not S.silentAimKeyActive then
        if S.shooting then
            if isMobileMode then pcall(function() LocalPlayer.PlayerGui.GUI.Client.LegacyLocalVariables.Held1.Value=false end)
            else VirtualInputManager:SendMouseButtonEvent(0,0,0,false,game,0) end
            S.shooting = false
        end
        return
    end

    if not IsPlayerAlive(LocalPlayer) then return end
    local weapon = GetLocalWeapon(); if BlacklistedWeapons[weapon] then return end

    local target = FrameCache.silentTarget
    if target and Toggles.AutoShoot and Toggles.AutoShoot.Value then
        if isMobileMode then
            pcall(function()
                local L = LocalPlayer.PlayerGui.GUI.Client.LegacyLocalVariables
                if not L.Held1.Value then L.Held1.Value=true; S.shooting=true; S.lastShotTime=tick() end
            end)
        else
            if not S.shooting then
                VirtualInputManager:SendMouseButtonEvent(0,0,0,true,game,0); S.shooting=true; S.lastShotTime=tick()
            elseif tick()-S.lastShotTime >= S.shotInterval then
                VirtualInputManager:SendMouseButtonEvent(0,0,0,false,game,0)
                VirtualInputManager:SendMouseButtonEvent(0,0,0,true,game,0); S.lastShotTime=tick()
            end
        end
    elseif not target and S.shooting then
        if isMobileMode then pcall(function() LocalPlayer.PlayerGui.GUI.Client.LegacyLocalVariables.Held1.Value=false end)
        else VirtualInputManager:SendMouseButtonEvent(0,0,0,false,game,0) end
        S.shooting = false
    end
end

local function RunAutoWarp(playerData)
    if not (Toggles.AutoWarp and Toggles.AutoWarp.Value and Options.WarpKey:GetState()) then return end
    if tick()-S.lastWarpTime < 1 then return end
    if GetLocalClass() ~= "Agent" or not BackstabWeapons[GetLocalWeapon()] then return end
    local lc=GetLocalCharacter(); local lh=lc and GetHRP(lc); if not lh then return end
    for _, pd in ipairs(playerData) do
        if not pd.IsEnemy or pd.Distance > BACKSTAB_RANGE then continue end
        local toT = (lh.Position-pd.HRP.Position).Unit
        if toT:Dot(pd.HRP.CFrame.LookVector) > 0 then
            local behindPos = pd.HRP.Position - pd.HRP.CFrame.LookVector*3
            lh.CFrame = CFrame.lookAt(behindPos, pd.HRP.Position)
            S.lastWarpTime = tick(); Notify("Warped behind "..pd.Player.Name, 1.5); break
        end
    end
end

local function RunAntiAim(dt)
    if not Config.AntiAim.Enabled then return end
    local char=LocalPlayer.Character; if not char then return end
    local hrp=GetHRP(char); if not hrp then return end
    pcall(function() char:SetAttribute("NoAutoRotate", true) end)
    if not LocalPlayer:GetAttribute("ThirdPerson") then return end
    local fwd = Vector3.new(Camera.CFrame.LookVector.X, 0, Camera.CFrame.LookVector.Z).Unit
    local nl
    if     Config.AntiAim.Mode=="backwards" then nl = -fwd
    elseif Config.AntiAim.Mode=="jitter" then
        if tick()-S.lastJitterUpdate >= 1/Config.AntiAim.JitterSpeed then S.jitterDir=-S.jitterDir; S.lastJitterUpdate=tick() end
        local y = math.rad(Config.AntiAim.JitterAngle*S.jitterDir)
        nl = Vector3.new(math.cos(y)*fwd.X-math.sin(y)*fwd.Z, 0, math.sin(y)*fwd.X+math.cos(y)*fwd.Z).Unit
    elseif Config.AntiAim.Mode=="spin" then
        S.spinAngle = S.spinAngle + math.rad(Config.AntiAim.AntiAimSpeed*dt)
        nl = Vector3.new(math.sin(S.spinAngle), 0, math.cos(S.spinAngle))
    end
    if nl then hrp.CFrame = CFrame.new(hrp.Position, hrp.Position+nl) end
end


local function RunAutoBackstab(playerData)
    if not (Toggles.AutoBackstab and Toggles.AutoBackstab.Value) then return end
    if GetLocalClass() ~= "Agent" or not BackstabWeapons[GetLocalWeapon()] then return end
    local lc=GetLocalCharacter(); local lh=lc and GetHRP(lc); if not lh then return end
    local foundTarget = false
    for _, pd in ipairs(playerData) do
        if not pd.IsEnemy or pd.Distance > BACKSTAB_RANGE then continue end
        if Toggles.BackstabIgnoreInvis.Value and IsCharacterInvisible(pd.Character) then continue end
        local toT = (pd.HRP.Position-lh.Position).Unit
        if toT:Dot(pd.HRP.CFrame.LookVector) > 0.3 then
            if not HasLineOfSight(lh.Position, pd.HRP.Position) then continue end
            foundTarget = true
            if S.lastBackstabTarget ~= pd.Player then S.lastBackstabTarget=pd.Player; Notify("Backstab: "..pd.Player.Name, 2) end
            if not S.shooting then
                VirtualInputManager:SendMouseButtonEvent(0,0,0,true,game,0); S.shooting=true; S.lastShotTime=tick()
            elseif tick()-S.lastShotTime >= 0.15 then
                VirtualInputManager:SendMouseButtonEvent(0,0,0,false,game,0)
                VirtualInputManager:SendMouseButtonEvent(0,0,0,true,game,0); S.lastShotTime=tick()
            end; break
        end
    end
    if not foundTarget and S.lastBackstabTarget then S.lastBackstabTarget=nil end
end

local function RunAutoMelee(playerData)
    if not (Toggles.AutoMelee and Toggles.AutoMelee.Value) then return end
    if Toggles.AutoBackstab and Toggles.AutoBackstab.Value and GetLocalClass()=="Agent" then return end
    if not MeleeWeapons[GetLocalWeapon()] then return end
    local lc=GetLocalCharacter(); local lh=lc and GetHRP(lc); if not lh then return end
    local meleeRange = (Options.AutoMeleeMode and Options.AutoMeleeMode.Value=="Demoknight") and MELEE_RANGE_DEMOKNIGHT or MELEE_RANGE_RAGE
    for _, pd in ipairs(playerData) do
        if not pd.IsEnemy or pd.Distance > meleeRange then continue end
        if Toggles.MeleeIgnoreInvis.Value and IsCharacterInvisible(pd.Character) then continue end
        if not HasLineOfSight(lh.Position, pd.HRP.Position) then continue end
        S.lastMeleeTarget = pd.Player
        if not S.shooting then
            VirtualInputManager:SendMouseButtonEvent(0,0,0,true,game,0); S.shooting=true; S.lastShotTime=tick()
        elseif tick()-S.lastShotTime >= 0.15 then
            VirtualInputManager:SendMouseButtonEvent(0,0,0,false,game,0)
            VirtualInputManager:SendMouseButtonEvent(0,0,0,true,game,0); S.lastShotTime=tick()
        end; return
    end
    S.lastMeleeTarget = nil
end

local function RunAutoSticky(playerData)
    if not (Toggles.AutoStickyDetonate and Toggles.AutoStickyDetonate.Value) then return end
    local stickies = GetMyStickybombs(); if #stickies==0 then return end
    for _, sticky in pairs(stickies) do
        for _, pd in ipairs(playerData) do
            if pd.IsEnemy and (sticky.Position-pd.HRP.Position).Magnitude <= 10 then
                if not (Toggles.AutoStickyVisibleOnly and Toggles.AutoStickyVisibleOnly.Value) or IsPartVisible(sticky) then
                    VirtualInputManager:SendMouseButtonEvent(0,0,1,true,game,0); task.wait(0.05); VirtualInputManager:SendMouseButtonEvent(0,0,1,false,game,0); return
                end
            end
        end
    end
end

local function RunPredictionIndicator()
    if not (Toggles.ShowPredictionIndicator and Toggles.ShowPredictionIndicator.Value and Config.SilentAim.Enabled and S.silentAimKeyActive) then
        PredictionIndicator.Visible = false; return
    end
    local weapon = GetLocalWeapon()
    if not (ProjectileWeapons[weapon] or ChargeWeapons[weapon]) then PredictionIndicator.Visible = false; return end
    local target, targetPlr = FrameCache.silentTarget, FrameCache.silentTargetPlr
    if target and targetPlr then
        local predicted = PredictProjectileHit(target, targetPlr, weapon)
        if predicted then
            local sp, onScreen = WorldToViewportPoint(predicted)
            if onScreen then
                PredictionIndicator.Text     = Options.PredictionIndicatorSymbol and Options.PredictionIndicatorSymbol.Value or "+"
                PredictionIndicator.Position = sp - Vector2.new(0, 30)
                PredictionIndicator.Color    = Options.PredictionIndicatorColor and Options.PredictionIndicatorColor.Value or Color3.new(0,1,1)
                PredictionIndicator.Visible  = true; return
            end
        end
    end
    PredictionIndicator.Visible = false
end

------------------------------------------------------------
-- HEAL SELF
------------------------------------------------------------
UserInputService.InputBegan:Connect(function(input, processed)
    if processed or Library.Unloaded then return end
    if Toggles.HealSelfToggle.Value then
        pcall(function()
            if Options.HealSelfKey:GetState() then
                Workspace[LocalPlayer.Name].Doctor.ChangeValue:FireServer("Target", LocalPlayer.Name)
            end
        end)
    end
end)

------------------------------------------------------------
-- HIT TRACKING
------------------------------------------------------------
do
    local function TrackCharacter(plr)
        if plr == LocalPlayer then return end
        local char = plr.Character; if not char then return end
        local hum  = char:FindFirstChildOfClass("Humanoid"); if not hum then return end
        healthCache[plr] = hum.Health
        hum.HealthChanged:Connect(function(newHealth)
            if not Config.Flags.Enabled then return end
            local old = healthCache[plr]; if not old then healthCache[plr]=newHealth; return end
            if newHealth < old then
                local dmg = math.floor(old-newHealth); local rem = math.floor(newHealth)
                if dmg > 0 and dmg < 200 and Config.Notifications.ShowHits then
                    local ct = tick()
                    if ct-S.lastHitTime > S.hitCooldown then
                        local msg = ""
                        if Config.Flags.ShowName            then msg=msg..plr.Name end
                        if Config.Flags.ShowDamage          then msg=msg..(msg~="" and " | " or "")..string.format("-%d HP",dmg) end
                        if Config.Flags.ShowRemainingHealth then msg=msg..(msg~="" and " | " or "")..string.format("%d HP left",rem) end
                        if msg ~= "" then Notify(msg, 2) end; S.lastHitTime=ct
                    end
                end
            end
            healthCache[plr] = newHealth
        end)
    end
    for _, plr in ipairs(cachedPlayerList) do
        if plr.Character then TrackCharacter(plr) end
        plr.CharacterAdded:Connect(function() task.wait(0.3); TrackCharacter(plr) end)
    end
    Players.PlayerAdded:Connect(function(plr)
        plr.CharacterAdded:Connect(function() task.wait(0.3); TrackCharacter(plr) end)
    end)
end

LogService.MessageOut:Connect(function(message)
    if type(message) ~= "string" then return end
    if message:find("HIT_DEBUG") and tick()-S.lastHitDebugNotif > 2 then
        Notify("Shot rejected by server — ping may be too high", 3); S.lastHitDebugNotif=tick()
    end
end)

------------------------------------------------------------
-- CHEATER DETECTOR
------------------------------------------------------------
do
    local notifiedCheaters = {}
    local function CheckCheater(player)
        if player == LocalPlayer then return end
        if CheaterList[player.UserId] and not notifiedCheaters[player.UserId] then
            notifiedCheaters[player.UserId] = true
            Notify("known cheater: " .. player.Name, 10)
        end
    end
    for _, p in ipairs(cachedPlayerList) do task.spawn(function() task.wait(2); CheckCheater(p) end) end
    Players.PlayerAdded:Connect(function(player)
        task.wait(1); CheckCheater(player)
        if CheaterList[player.UserId] then
            Notify("known cheater joined: " .. player.Name, 10)
        end
    end)
    Players.PlayerRemoving:Connect(function(p) notifiedCheaters[p.UserId] = nil end)
end

------------------------------------------------------------
-- MOD / STAFF DETECTOR
------------------------------------------------------------
do
    local STAFF_ATTRS = {
        "IsGroupCoder","IsGroupContributor","IsGroupDeveloper",
        "IsGroupMapper","IsGroupModerator","IsGroupTester",
    }
    local alreadyNotified = {}

    local function CheckPlayerForStaff(player)
        if player == LocalPlayer then return end
        local ntp = player:FindFirstChild("newTcPlayer"); if not ntp then return end
        local found = {}
        for _, attr in ipairs(STAFF_ATTRS) do
            local val = ntp:GetAttribute(attr)
            if val and val ~= false and val ~= 0 and val ~= "" then
                table.insert(found, attr:gsub("IsGroup",""))
            end
        end
        if #found > 0 then
            local key = player.UserId; local label = table.concat(found, "/")
            if alreadyNotified[key] ~= label then
                alreadyNotified[key] = label
                Notify("staff in server: " .. player.Name .. " [" .. label .. "]", 10)
            end
        end
    end

    local function HookNTP(player)
        local ntp = player:FindFirstChild("newTcPlayer"); if not ntp then return end
        ntp.AttributeChanged:Connect(function() pcall(CheckPlayerForStaff, player) end)
        pcall(CheckPlayerForStaff, player)
    end

    local function SetupPlayer(player)
        task.spawn(function()
            task.wait(2); pcall(HookNTP, player)
            player.ChildAdded:Connect(function(child)
                if child.Name == "newTcPlayer" then task.wait(0.5); pcall(HookNTP, player) end
            end)
        end)
    end

    for _, p in ipairs(cachedPlayerList) do SetupPlayer(p) end
    Players.PlayerAdded:Connect(SetupPlayer)
    Players.PlayerRemoving:Connect(function(p) alreadyNotified[p.UserId] = nil end)
end

------------------------------------------------------------
-- MAIN RENDER LOOP
------------------------------------------------------------
local MainConnection = RunService.RenderStepped:Connect(function(dt)
    if Library.Unloaded then return end
    Camera = Workspace.CurrentCamera
    S.frames = S.frames + 1
    visibilityCache = {}

    FrameCache.camPos      = Camera.CFrame.Position
    FrameCache.camCF       = Camera.CFrame
    FrameCache.screenCenter = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
    FrameCache.frameNum    = FrameCache.frameNum + 1

    EnsureGUILoaded()
    UpdateVelocityTracking()


    if S.isCharging then
        local w = GetLocalWeapon(); local cd = ChargeWeapons[w]
        if cd then S.currentChargePercent = math.clamp((tick()-S.chargeStartTime)/cd.ChargeTime, 0, 1) end
    end

    FrameCache.playerData   = BuildPlayerData()
    FrameCache.silentTarget, FrameCache.silentTargetPlr = GetSilentAimTarget(FrameCache.playerData)

    local playerData = FrameCache.playerData

    RunSilentAimLogic()
    RunAutoWarp(playerData)
    UpdateAimArms()

    -- FOV circle
    if Toggles.ShowFOVCircle and Toggles.ShowFOVCircle.Value and Config.SilentAim.Enabled then
        FOVCircle.Position = FrameCache.screenCenter; FOVCircle.Radius = Options.SilentAimFOV.Value
        FOVCircle.Color    = Options.FOVColor.Value;   FOVCircle.Visible = true
    else FOVCircle.Visible = false end

    RunPredictionIndicator()

    -- Player ESP & Chams
    do
        local processed = {}
        for _, pd in ipairs(playerData) do
            processed[pd.Player] = true
            if Toggles.ESPEnabled.Value then CreatePlayerESP(pd.Player); UpdatePlayerESP(pd) else HidePlayerESP(pd.Player) end
            UpdatePlayerChams(pd)
        end
        for p in pairs(ESPObjects) do if not processed[p] then HidePlayerESP(p) end end
    end

    -- Object ESP
    if Toggles.ObjESPEnabled.Value then
        local act = {}
        -- Buildings: split by enemy/team
        local function PBuilding(cache, enemyTog, teamTog, label)
            for _, o in pairs(cache) do
                if not o.Parent then continue end
                local side = GetBuildingTeam(o)
                local show = (side=="enemy" and enemyTog.Value) or (side=="team" and teamTog.Value)
                if show then
                    local col = side=="enemy" and Options.ObjESPEnemyColor.Value or Options.ObjESPTeamColor.Value
                    act[o] = true; UpdateObjectESP(o, label, col)
                end
            end
        end
        PBuilding(cachedSentries,    Toggles.ObjESPEnemySentry,    Toggles.ObjESPTeamSentry,    "Sentry")
        PBuilding(cachedDispensers,  Toggles.ObjESPEnemyDispenser, Toggles.ObjESPTeamDispenser, "Dispenser")
        PBuilding(cachedTeleporters, Toggles.ObjESPEnemyTeleporter,Toggles.ObjESPTeamTeleporter,"Teleporter")
        -- Pickups: no team distinction
        local function PPickup(cache, tog, name)
            if tog.Value then for _, o in pairs(cache) do if o.Parent then act[o]=true; UpdateObjectESP(o, name, Options.ObjESPBoxColor.Value) end end end
        end
        PPickup(cachedAmmo, Toggles.ObjESPAmmo, "Ammo")
        PPickup(cachedHP,   Toggles.ObjESPHP,   "HP")
        for i in pairs(ObjectESPCache) do if not act[i] or not i.Parent then HideObjectESP(i) end end
    else for i in pairs(ObjectESPCache) do HideObjectESP(i) end end

    UpdateWorldChams(); UpdateProjectileChams()

    if Toggles.UsernameHider.Value then UpdateUsernameHider() end

    if Toggles.AgentNotification and Toggles.AgentNotification.Value and tick()-S.lastAgentNotif > 3 then
        for _, pd in ipairs(playerData) do
            if pd.IsEnemy and pd.Class=="Agent" and pd.Distance <= 30 then
                Notify("Enemy Agent nearby! ("..pd.Player.Name..")", 3); S.lastAgentNotif=tick(); break
            end
        end
    end

    RunAntiAim(dt)

    -- Telestab
    if Toggles.TelestabToggle.Value and Options.TelestabKey:GetState() then
        local lc=GetLocalCharacter(); if lc then local lh=GetHRP(lc); if lh then
            local bestChar, bestDist2 = nil, 9e9
            for _, pd in ipairs(playerData) do if pd.IsEnemy and pd.Distance < bestDist2 then bestDist2=pd.Distance; bestChar=pd.Character end end
            if bestChar then
                for _, v in pairs(bestChar:GetChildren()) do if v:IsA("BasePart") then v.CanCollide=false end end
                local uh = GetHRP(bestChar); if uh then uh.CFrame = lh.CFrame + lh.CFrame.LookVector * 3.25 end
            end
        end end
    end

    RunAutoBackstab(playerData)
    RunAutoMelee(playerData)
    RunAutoSticky(playerData)
    RunAutoAirblast()
    CheckAutoUber()

    if Toggles.CustomFOV and Toggles.CustomFOV.Value then
        Camera.FieldOfView = Options.CustomFOVAmount.Value
    end
end)

------------------------------------------------------------
-- FPS COUNTER & WATERMARK
------------------------------------------------------------
task.spawn(function() while true do task.wait(1); if Library.Unloaded then break end; S.fps=S.frames; S.frames=0 end end)
task.spawn(function() while true do task.wait(1); if Library.Unloaded then break end
    local ping=0; pcall(function() ping=math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue()) end)
    Library:SetWatermark(("Aegis.dev / %d fps / %d ms"):format(S.fps, ping))
end end)
Library:SetWatermarkVisibility(true)

------------------------------------------------------------
-- CLEANUP
------------------------------------------------------------
Players.PlayerRemoving:Connect(function(player)
    DestroyPlayerESP(player)
    RemovePlayerHighlight(player)
    healthCache[player]=nil; playerVelocities[player]=nil; playerAccelerations[player]=nil
    playerVerticalHistory[player]=nil; playerStrafeHistory[player]=nil; playerPositionHistory[player]=nil
    lastChamsProps[player]=nil
end)

------------------------------------------------------------
-- UI SETTINGS TAB
------------------------------------------------------------
do
    local MenuGroup = Tabs["UI Settings"]:AddLeftGroupbox("Menu", "wrench")
    MenuGroup:AddToggle("KeybindMenuOpen", { Default=Library.KeybindFrame.Visible, Text="Open Keybind Menu",
        Callback=function(v) Library.KeybindFrame.Visible=v end })
    MenuGroup:AddToggle("ShowCustomCursor", { Text="Custom Cursor", Default=true,
        Callback=function(v) Library.ShowCustomCursor=v end })
    MenuGroup:AddDropdown("NotificationSide", { Values={"Left","Right"}, Default="Right", Text="Notification Side",
        Callback=function(v) Library:SetNotifySide(v) end })
    MenuGroup:AddDropdown("DPIDropdown", { Values={"50%","75%","100%","125%","150%","175%","200%"}, Default="100%", Text="DPI Scale",
        Callback=function(v) local DPI=tonumber(v:gsub("%%","")); Library:SetDPIScale(DPI) end })
    MenuGroup:AddDivider()
    MenuGroup:AddLabel("Menu Bind"):AddKeyPicker("MenuKeybind", { Default="RightShift", NoUI=true, Text="Menu keybind" })
    MenuGroup:AddButton("Unload", function() Library:Unload() end)
    Library.ToggleKeybind = Options.MenuKeybind
end

ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({ "MenuKeybind" })
ThemeManager:SetFolder("Aegis")
SaveManager:SetFolder("Aegis/TC2")
SaveManager:BuildConfigSection(Tabs["UI Settings"])
ThemeManager:ApplyToTab(Tabs["UI Settings"])
SaveManager:LoadAutoloadConfig()

------------------------------------------------------------
-- UNLOAD
------------------------------------------------------------
Library:OnUnload(function()
    for p in pairs(ESPObjects)    do DestroyPlayerESP(p) end
    for i in pairs(ObjectESPCache) do DestroyObjectESP(i) end
    for p in pairs(PlayerChamsCache) do RemovePlayerHighlight(p) end
    for i in pairs(WorldChamsCache)  do pcall(function() WorldChamsCache[i]:Destroy() end) end
    for i in pairs(ProjectileChamsCache) do pcall(function() ProjectileChamsCache[i]:Destroy() end) end
    FOVCircle:Remove(); pcall(function() PredictionIndicator:Remove() end)
    DestroyMobileButton()
    if OL then
        Lighting.Ambient=OL.Ambient; Lighting.Brightness=OL.Brightness; Lighting.FogEnd=OL.FogEnd
        Lighting.FogStart=OL.FogStart; Lighting.ClockTime=OL.ClockTime; Lighting.OutdoorAmbient=OL.OutdoorAmbient
    end
    if S.speedConnection then S.speedConnection:Disconnect() end
    MainConnection:Disconnect()
    if S.shooting then VirtualInputManager:SendMouseButtonEvent(0,0,0,false,game,0); S.shooting=false end
    playerPositionHistory={}
    print("[Aegis] Unloaded!")
    Library.Unloaded = true
end)

print("[Aegis] loaded, account stolen.")
