if setthreadidentity then setthreadidentity(8) end

-- LIBRARY
local repo='https://raw.githubusercontent.com/christianfbi19/Aegis-Linoria/main/'
local libSource=game:HttpGet(repo..'Library.lua')
libSource=libSource:gsub('Instance%.new%((%w+)%)','(function() if setthreadidentity then setthreadidentity(8) end return Instance.new(%1) end)()')
libSource=libSource:gsub('Instance%.new%("([^"]+)"%)','(function() if setthreadidentity then setthreadidentity(8) end return Instance.new("%1") end)()')
libSource=libSource:gsub("Instance%.new%('([^']+)'%)",'(function() if setthreadidentity then setthreadidentity(8) end return Instance.new("%1") end)()')
local Library=loadstring(libSource)()
local ThemeManager=loadstring(game:HttpGet(repo..'ThemeManager.lua'))()
local SaveManager=loadstring(game:HttpGet(repo..'SaveManager.lua'))()

-- SERVICES
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local UserInputService=game:GetService("UserInputService")
local Lighting=game:GetService("Lighting")
local Workspace=game:GetService("Workspace")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local VirtualInputManager=game:GetService("VirtualInputManager")
local Stats=game:GetService("Stats")
local LogService=game:GetService("LogService")
local Camera=Workspace.CurrentCamera
local LocalPlayer=Players.LocalPlayer

local isMobileDevice=UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local isMobileMode=false

local BACKSTAB_RANGE=7.5
local MELEE_RANGE_RAGE=7.5
local MELEE_RANGE_DEMOKNIGHT=9

-- State table
local S={
    charlieKirk=false,shooting=false,lastShotTime=0,shotInterval=0.033,
    currentTarget=nil,lastHitTime=0,hitCooldown=0.1,
    jitterDir=1,spinAngle=0,lastJitterUpdate=0,
    AdsEnabled=false,ADSMultiplier=1,fps=0,frames=0,
    chargeStartTime=0,isCharging=false,currentChargePercent=0,
    lastAgentNotif=0,
    shootingRemote=nil,shootingRemoteFound=false,
    silentAimKeyActive=false,lastTriggerTime=0,
    warpActive=false,lastWarpTime=0,lastBackstabTarget=nil,
    lastChamsProps={},lastWorldChamsUpdate=0,lastProjChamsUpdate=0,lastUsernameUpdate=0,
    lastVelocityUpdate=0,lastHitDebugNotif=0,
    noSpreadSetup=false,speedConnection=nil,
    _guiLoaded=false,
    ads=nil,adsmodifier=nil,equipped=nil,kirk=nil,ClassValue=nil,
    mobileToggleButton=nil,
    -- Aim arms smooth state
    armTarget=nil,armSmoothStart=0,armReturning=false,armReturnStart=0,
    shotConfirmed=false,shotConfirmTime=0,
    -- Auto melee state
    lastMeleeTarget=nil,
}

local healthCache={}
local visibilityCache={}
local lastKnownAmmo={}
local remoteSet={}
local activePredictionVisuals={}
local playerVelocities={}
local playerAccelerations={}
local playerVerticalHistory={}
local playerStrafeHistory={}
local playerPositionHistory={}
local cachedSentries={}
local cachedDispensers={}
local cachedTeleporters={}
local cachedAmmo={}
local cachedHP={}

-- Frame cache
local FrameCache={
    playerData=nil,silentTarget=nil,silentTargetPlr=nil,
    ragebotTarget=nil,ragebotTargetPlr=nil,
    camPos=Vector3.zero,camCF=CFrame.new(),screenCenter=Vector2.zero,
    simRayParams=nil,frameNum=0,
    predictedPos=nil,predictedTime=0,
}

local PATH_MAX_SEGMENTS=40
local TC2_GRAVITY=50
local TC2_JUMP_POWER=16
local raycastParams=RaycastParams.new()
raycastParams.FilterType=Enum.RaycastFilterType.Blacklist
raycastParams.IgnoreWater=true

-- Charge tick value for Huntsman
local ChargeTick = {Value = 0}

-- FREECAM FIX
task.spawn(function()
    local function EnsureFreecamDummy()
        pcall(function()
            local pg=LocalPlayer:FindFirstChild("PlayerGui")
            if pg and not pg:FindFirstChild("FreecamScript") then
                local dummy=Instance.new("LocalScript");dummy.Name="FreecamScript";dummy.Disabled=true;dummy.Parent=pg
            end
        end)
    end
    EnsureFreecamDummy()
    LocalPlayer.CharacterAdded:Connect(function() task.wait(0.5);EnsureFreecamDummy() end)
    while true do task.wait(5);if Library.Unloaded then break end;EnsureFreecamDummy() end
end)

local function EnsureGUILoaded()
    if S._guiLoaded then return true end
    pcall(function()
        local PG=LocalPlayer:FindFirstChild("PlayerGui");if not PG then return end
        local G=PG:FindFirstChild("GUI");if not G then return end
        local C=G:FindFirstChild("Client");if not C then return end
        local L=C:FindFirstChild("LegacyLocalVariables");if not L then return end
        S.ads=L:FindFirstChild("ads");S.adsmodifier=L:FindFirstChild("adsmodifier")
        S.equipped=L:FindFirstChild("equipped");S.kirk=L:FindFirstChild("currentspread")
        local St=LocalPlayer:FindFirstChild("Status")
        if St then S.ClassValue=St:FindFirstChild("Class") end
        if S.ads and S.adsmodifier and S.equipped and S.kirk and S.ClassValue then S._guiLoaded=true end
    end)
    return S._guiLoaded
end

-- Right click helper for auto airblast / auto uber
local function RightClick()
    pcall(function()
        local LLV = LocalPlayer.PlayerGui.GUI.Client.LegacyLocalVariables
        LLV.Held2.Value = true
        task.wait(0.05)
        LLV.Held2.Value = false
    end)
end

------------------------------------------------------------
-- DATA TABLES
------------------------------------------------------------
local HitboxTables={
    ["Head"]={"Head","HeadHB"},
    ["Chest"]={"UpperTorso","HumanoidRootPart"},
    ["Torso"]={"LowerTorso"},
    ["Arms"]={"LeftLowerArm","RightLowerArm","LeftUpperArm","RightUpperArm","LeftHand","RightHand"},
    ["Legs"]={"LeftLowerLeg","RightLowerLeg","LeftUpperLeg","RightUpperLeg"},
    ["Feet"]={"LeftFoot","RightFoot"},
}

local AllBodyParts={
    "Head","HeadHB","UpperTorso","HumanoidRootPart","LowerTorso",
    "LeftUpperArm","RightUpperArm","LeftLowerArm","RightLowerArm","LeftHand","RightHand",
    "LeftUpperLeg","RightUpperLeg","LeftLowerLeg","RightLowerLeg","LeftFoot","RightFoot",
}

local SkeletonConnections={
    {"Head","UpperTorso"},{"UpperTorso","LowerTorso"},
    {"UpperTorso","LeftUpperArm"},{"LeftUpperArm","LeftLowerArm"},{"LeftLowerArm","LeftHand"},
    {"UpperTorso","RightUpperArm"},{"RightUpperArm","RightLowerArm"},{"RightLowerArm","RightHand"},
    {"LowerTorso","LeftUpperLeg"},{"LeftUpperLeg","LeftLowerLeg"},{"LeftLowerLeg","LeftFoot"},
    {"LowerTorso","RightUpperLeg"},{"RightUpperLeg","RightLowerLeg"},{"RightLowerLeg","RightFoot"},
}

local ProjectileWeapons={
    ["Direct Hit"]={Speed=123.75,Gravity=0,InitialAngle=0,Lifetime=99,Type="Rocket"},
    ["Maverick"]={Speed=68.75,Gravity=15,InitialAngle=0,Lifetime=99,Type="Rocket"},
    ["Rocket Launcher"]={Speed=68.75,Gravity=0,InitialAngle=0,Lifetime=99,Type="Rocket"},
    ["Double Trouble"]={Speed=68.75,Gravity=0,InitialAngle=0,Lifetime=99,Type="Rocket"},
    ["Blackbox"]={Speed=68.75,Gravity=0,InitialAngle=0,Lifetime=99,Type="Rocket"},
    ["Original"]={Speed=68.75,Gravity=0,InitialAngle=0,Lifetime=99,Type="Rocket"},
    ["Cow Mangler 5000"]={Speed=68.75,Gravity=0,InitialAngle=0,Lifetime=99,Type="Rocket"},
    ["Wreckers Yard"]={Speed=68.75,Gravity=0,InitialAngle=0,Lifetime=99,Type="Rocket"},
    ["G-Bomb"]={Speed=44.6875,Gravity=0,InitialAngle=0,Lifetime=99,Type="Rocket"},
    ["Airstrike"]={Speed=68.75,Gravity=0,InitialAngle=0,Lifetime=99,Type="Rocket",AirSpeed=110},
    ["Liberty Launcher"]={Speed=96.25,Gravity=0,InitialAngle=0,Lifetime=99,Type="Rocket"},
    ["Grenade Launcher"]={Speed=76,Gravity=42.6,InitialAngle=7.92,Lifetime=0.8,Type="Grenade"},
    ["Ultimatum"]={Speed=76,Gravity=42.6,InitialAngle=7.92,Lifetime=0.8,Type="Grenade"},
    ["Iron Bomber"]={Speed=76,Gravity=42.6,InitialAngle=7.92,Lifetime=0.8,Type="Grenade"},
    ["Loose Cannon"]={Speed=76,Gravity=42.6,InitialAngle=7.92,Lifetime=0.8,Type="Grenade"},
    ["Loch-n-Load"]={Speed=96,Gravity=42.6,InitialAngle=5.412,Lifetime=99,Type="Grenade"},
    ["Syringe Crossbow"]={Speed=100,Gravity=3,InitialAngle=0,Lifetime=99,Type="Syringe"},
    ["Milk Pistol"]={Speed=100,Gravity=3,InitialAngle=0,Lifetime=99,Type="Grenade"},
    ["Flare Gun"]={Speed=125,Gravity=10,InitialAngle=0,Lifetime=99,Type="Flare"},
    ["Detonator"]={Speed=125,Gravity=10,InitialAngle=0,Lifetime=99,Type="Flare"},
    ["Rescue Ranger"]={Speed=150,Gravity=3,InitialAngle=0,Lifetime=99,Type="Syringe"},
}

local ChargeWeapons={
    ["Huntsman"]={SpeedMin=113.25,SpeedMax=162.5,GravityMin=24.8,GravityMax=5.0,Gravity=24.8,InitialAngle=0,ChargeTime=1.0,Lifetime=99,Type="Arrow"},
}

local PathVisualWeapons={}
for k in pairs(ProjectileWeapons) do PathVisualWeapons[k]=true end
for k in pairs(ChargeWeapons) do PathVisualWeapons[k]=true end

local ArcWeapons={
    ["Grenade Launcher"]=true,["Ultimatum"]=true,
    ["Iron Bomber"]=true,["Loose Cannon"]=true,["Loch-n-Load"]=true,
    ["Huntsman"]=true,["Flare Gun"]=true,["Maverick"]=true,["Detonator"]=true,["Milk Pistol"]=true,["Syringe Crossbow"]=true,
    ["Rescue Ranger"]=true,
}

local BackstabWeapons={
    ["Knife"]=true,["Conniver's Kunai"]=true,["Your Eternal Reward"]=true,
    ["Icicle"]=true,["Swift Stiletto"]=true,["The Wraith"]=true,
    ["Big Earner"]=true,["Spy-cicle"]=true,["Wanga Prick"]=true,
}

local MeleeWeapons={
    ["Fist"]=true,["Ice Dagger"]=true,["Linked Sword"]=true,["Mummy Staff"]=true,
    ["Rapier"]=true,["Wrecking Ball"]=true,["Le Executeur"]=true,["Pirate Cutlass"]=true,
    ["Warrior's Spirit"]=true,["Pain Train"]=true,["Icicle"]=true,["Mummy Sword"]=true,
    ["Karambit"]=true,["Skeleton Scythe"]=true,["Rally Racket"]=true,["Eviction Notice"]=true,
    ["Your Eternal Reward"]=true,["Conscientious Objector"]=true,["Gunslinger"]=true,
    ["Slash n' Burn"]=true,["Doll Maker"]=true,["Three Rune Blade"]=true,["Equalizer"]=true,
    ["Golden Wrench"]=true,["Southern Hospitality"]=true,["Wraith"]=true,
    ["Conniver's Kunai"]=true,["Elegant Blade"]=true,["Homewrecker"]=true,
    ["Rising Sun Katana"]=true,["Caber"]=true,["Rubber Chicken"]=true,["Holy Mackerel"]=true,
    ["Sandman"]=true,["Golden Frying Pan"]=true,["Frying Pan"]=true,["Tribalman's Shiv"]=true,
    ["Market Gardener"]=true,["Market Gardener2"]=true,["Atomizer"]=true,
    ["Katana"]=true,["Golf Club"]=true,["Skeleton Bat"]=true,["Six Point Shuriken"]=true,
    ["Fan O' War"]=true,["Wrap Assassin"]=true,["Shahanshah"]=true,["Golden Knife"]=true,
    ["Candy Cane"]=true,["Fists of Steel"]=true,["Scotsman's Skullcutter"]=true,
    ["Brooklyn Basher"]=true,["Supersaw"]=true,["Pestilence Poker"]=true,["Amputator"]=true,
    ["Big Earner"]=true,["Holiday Punch"]=true,["Prop Handle"]=true,["Trowel"]=true,
    ["Bat"]=true,["Broken Sword"]=true,["Crowbar"]=true,["Fire Extinguisher"]=true,
    ["Fists"]=true,["Knife"]=true,["Saw"]=true,["Wrench"]=true,["Machete"]=true,["The Black Death"]=true,["Eyelander"]=true,
}

local AirblastWeapons={
    ["Degreaser"]=true,["The Interceptor"]=true,["Phlogistinator"]=true,["Flamethrower"]=true,
}

local BlacklistedWeapons={
    ["Sticky Jumper"]=true,["Rocket Jumper"]=true,["Overdrive"]=true,
    ["The Mercy Kill"]=true,["Friendly Fire Foiler"]=true,
    ["Buff Banner"]=true,["Battalion's Backup"]=true,["Concheror"]=true,
    ["Battle Burrito"]=true,["Dire Donut"]=true,["Tenacious Turkey"]=true,
    ["Robar"]=true,["Special-ops Sushi"]=true,
    ["Blood Doctor"]=true,["Kritzkrieg"]=true,["Rejuvenator"]=true,["The Vaccinator"]=true,
    ["Medigun"]=true,["Radius Scanner"]=true,["Slow Burn"]=true,["Spy Camera"]=true,
    ["Stray Reflex"]=true,["Sapper"]=true,["Disguise Kit"]=true,["Jarate"]=true,
    ["Mad Milk"]=true,["Witches Brew"]=true,["Bloxy Cola"]=true,
}

-- Projectile CFrame offsets for aim calculation
local ProjectileCFrameOffsets={
    ["Rocket Launcher"]=CFrame.new(0.75, -0.1875, -0.275),
    ["Direct Hit"]=CFrame.new(0.75, -0.1875, 1.635),
    ["Blackbox"]=CFrame.new(0.75, -0.1875, -0.265),
    ["Cow Mangler 5000"]=CFrame.new(0.75, -0.1875, 0.35),
    ["G-Bomb"]=CFrame.new(0.75, -0.1875, 0.52),
    ["Original"]=CFrame.new(0, -1, 1.191),
    ["Liberty Launcher"]=CFrame.new(0.75, -0.1877, 1.3),
    ["Maverick"]=CFrame.new(0.75, -0.1875, 0),
    ["Airstrike"]=CFrame.new(0.75, -0.1877, 1.3),
    ["Flare Gun"]=CFrame.new(0.75, -0.1875, 0.41),
    ["Detonator"]=CFrame.new(0.75, -0.1875, 0.2),
    ["Grenade Launcher"]=CFrame.new(0.5, -0.375, 0),
    ["Loch-n-Load"]=CFrame.new(0.5, -0.375, 0),
    ["Loose Cannon"]=CFrame.new(0.5, -0.375, 0),
    ["Iron Bomber"]=CFrame.new(0.5, -0.375, 0),
    ["Ultimatum"]=CFrame.new(0.5, -0.375, 0),
    ["Rescue Ranger"]=CFrame.new(0.5, 0.2, 0.5),
    ["Milk Pistol"]=CFrame.new(0.5, 0.1875, 0.5),
    ["Syringe Crossbow"]=CFrame.new(0.5, 0.1875, 0.5),
    ["Huntsman"]=CFrame.new(0.5, -0.1875, -2),
}

-- Projectile sizes: Rockets = 3,1,1 | Grenades = 2,1,1 | Rest = 1,1,1
local ProjectileSizes={
    ["Rocket"]=Vector3.new(4,1,1),
    ["Grenade"]=Vector3.new(3,1,1),
    ["Syringe"]=Vector3.new(1,1,1),
    ["Arrow"]=Vector3.new(1,1,1),
}

local PROJECTILE_OFFSET=Vector3.new(0.32,-0.14,-0.56)

local projectileNames={
    "Bauble","Shuriken","Rocket","Grenade","Arrow_Syringe","Sentry Rocket",
    "Arrow","Flare Gun","Baseball","Snowballs","Milk Pistol"
}

local StatusLetters={
    Bleeding={Letter="B",Color=Color3.fromRGB(255,50,50)},
    Cloaked={Letter="C",Color=Color3.fromRGB(150,150,255)},
    Engulfed={Letter="E",Color=Color3.fromRGB(255,150,0)},
    Lemoned={Letter="L",Color=Color3.fromRGB(255,255,0)},
    Milked={Letter="M",Color=Color3.fromRGB(230,230,230)},
    Ubercharged={Letter="U",Color=Color3.fromRGB(255,215,0)},
}

local PredictionSymbols={"+", "*"}

local CLASS_MAX_HP={
    Flanker=125,Mechanic=125,Brute=300,Annihilator=175,
    Marksman=125,Doctor=150,Arsonist=175,Agent=125,
    Trooper=200,Unknown=150,
}

------------------------------------------------------------
-- CONFIG
------------------------------------------------------------
getgenv().Config={
    Ragebot={Enabled=false,AllowMelee=false,HitscanMode="All Visible",PriorityHitbox="Head"},
    SilentAim={Enabled=false,FOV=200},
    AntiAim={Enabled=false,Mode="jitter",JitterAngle=90,JitterSpeed=15,AntiAimSpeed=180},
    Wallbang={Enable=false},
    NoSpread={Enable=false,Multiplier=0.2},
    Speed={Enable=false,Value=300},
    AimArms={Enable=false},
    Notifications={ShowHits=false,ShowRagebotMisses=false},
    Flags={Enabled=false,ShowDamage=false,ShowRemainingHealth=false,ShowName=false},
    AutoUber={Enabled=false,HealthPercent=40,Condition="Both"},
}

------------------------------------------------------------
-- WINDOW & TABS
------------------------------------------------------------
local Window=Library:CreateWindow({
    Title='                                                                   Aegis | Typical Colors 2',
    Center=true,AutoShow=true,TabPadding=4,MenuFadeTime=0.2
})

local Tabs={
    Aimbot=Window:AddTab('Aimbot'),
    Visuals=Window:AddTab('Visuals'),
    Misc=Window:AddTab('Misc'),
    Exploits=Window:AddTab('Exploits'),
    Settings=Window:AddTab('Settings'),
    ['UI Settings']=Window:AddTab('UI Settings'),
}

------------------------------------------------------------
-- UTILITY FUNCTIONS
------------------------------------------------------------
local function GetCharacter(p) return p and p.Character end
local function GetLocalCharacter() return GetCharacter(LocalPlayer) end
local function GetHumanoid(c) return c and c:FindFirstChildOfClass("Humanoid") end
local function GetHRP(c) return c and c:FindFirstChild("HumanoidRootPart") end
local function IsPlayerAlive(p)
    local c=p and p.Character;local h=c and c:FindFirstChildOfClass("Humanoid")
    return h and h.Health>0
end
local function IsEnemy(p) return p and p.Team~=LocalPlayer.Team end
local function IsFriend(p)
    local ok,r=pcall(function() return LocalPlayer:IsFriendsWith(p.UserId) end)
    return ok and r
end

local function WorldToViewportPoint(pos)
    local ok,sp,os=pcall(function() return Camera:WorldToViewportPoint(pos) end)
    if not ok or not sp then return Vector2.new(0,0),false,0 end
    return Vector2.new(sp.X,sp.Y),os,sp.Z
end

local function IsPartVisible(part)
    if not part then return false end
    local lc=GetLocalCharacter();if not lc then return false end
    if visibilityCache[part]~=nil then return visibilityCache[part] end
    raycastParams.FilterDescendantsInstances={lc}
    local origin=FrameCache.camPos
    local result=Workspace:Raycast(origin,part.Position-origin,raycastParams)
    local vis=not result or result.Instance:IsDescendantOf(part.Parent)
    visibilityCache[part]=vis
    return vis
end

local function IsCharacterVisible(char) local hrp=GetHRP(char);return hrp and IsPartVisible(hrp) end

local function GetBestVisiblePart(char,selectedParts)
    if not char or char==LocalPlayer.Character then return nil end
    local sel=selectedParts or {Head=true}
    local closestToMouse=sel["Closest to Mouse"]
    local candidates={}
    for _,groupName in ipairs({"Head","Chest","Torso","Arms","Legs","Feet"}) do
        if sel[groupName] then
            for _,partName in ipairs(HitboxTables[groupName] or {}) do
                local p=char:FindFirstChild(partName)
                if p and IsPartVisible(p) then table.insert(candidates,p) end
            end
        end
    end
    if #candidates==0 then
        for _,name in ipairs(AllBodyParts) do
            local p=char:FindFirstChild(name)
            if p and IsPartVisible(p) then return p end
        end
        return nil
    end
    if closestToMouse then
        local best,bestDist=nil,math.huge
        for _,p in ipairs(candidates) do
            local sp,onScreen=WorldToViewportPoint(p.Position)
            if onScreen then local d=(sp-FrameCache.screenCenter).Magnitude;if d<bestDist then bestDist=d;best=p end end
        end
        return best
    end
    return candidates[1]
end

local function GetPlayerClass(p)
    local st=p:FindFirstChild("Status")
    if st then local c=st:FindFirstChild("Class");if c then return tostring(c.Value) end end
    return "Unknown"
end

local function GetClassMaxHP(player)
    return CLASS_MAX_HP[GetPlayerClass(player)] or 150
end

local function GetPlayerWeapon(char)
    if not char then return "Unknown" end
    local g=char:FindFirstChild("Gun")
    if g then local b=g:FindFirstChild("Boop");if b then return tostring(b.Value) end end
    return "Unknown"
end

local function GetLocalWeapon() return GetPlayerWeapon(GetLocalCharacter()) end

local function GetLocalClass()
    if not EnsureGUILoaded() then return "Unknown" end
    return S.ClassValue and tostring(S.ClassValue.Value) or "Unknown"
end

local function GetPing()
    local p=0;pcall(function() p=Stats.Network.ServerStatsItem['Data Ping']:GetValue() end)
    local result=p/1000
    if result<0.05 then result=0.05 end
    return result
end

local function IsOnGround(char)
    if not char then return false end
    local hum=char:FindFirstChildOfClass("Humanoid")
    if not hum then return false end
    return hum.FloorMaterial~=Enum.Material.Air
end

local function IsBlastJumping()
    local lc=GetLocalCharacter();if not lc then return false end
    local hrp=GetHRP(lc);if not hrp then return false end
    local rp=RaycastParams.new()
    rp.FilterType=Enum.RaycastFilterType.Blacklist
    rp.FilterDescendantsInstances={lc}
    rp.IgnoreWater=true
    local result=Workspace:Raycast(hrp.Position,Vector3.new(0,-100,0),rp)
    if result then return (hrp.Position.Y-result.Position.Y)>6 end
    return true
end

local function IsRocketJumped()
    local lc=GetLocalCharacter();if not lc then return false end
    local rj=lc:FindFirstChild("RocketJumped")
    return rj~=nil
end

local function GetPlayerModifiers(player)
    local mods={}
    pcall(function()
        local char=Workspace:FindFirstChild(player.Name)
        if char then local mf=char:FindFirstChild("Modifiers");if mf then
            for attrName in pairs(StatusLetters) do if mf:GetAttribute(attrName)==true then mods[attrName]=true end end
        end end
    end)
    return mods
end

local function WeaponAllowed()
    if not EnsureGUILoaded() then return false end
    local eq=S.equipped.Value;local class=S.ClassValue.Value
    local weapon=GetLocalWeapon()
    if BlacklistedWeapons[weapon] then return false end
    if not Config.Ragebot.AllowMelee and eq=="melee" then return false end
    if eq=="equipment" then return false end
    if class=="Agent" then return eq=="primary" end
    if class=="Trooper" then return eq~="primary" end
    if class=="Annihilator" then return eq~="primary" and eq~="secondary" end
    return true
end

local function IsSyringeWeapon(weapon)
    return weapon=="Syringe Crossbow" or weapon=="Crusader's Crossbow"
end

local function IsPlayerFullHP(player)
    local char=player.Character;if not char then return true end
    local hum=GetHumanoid(char);if not hum then return true end
    local maxHP=GetClassMaxHP(player)
    return hum.Health>=maxHP
end

------------------------------------------------------------
-- SIM RAY PARAMS (cached per frame)
------------------------------------------------------------
local function BuildSimRayParams()
    local rp=RaycastParams.new()
    rp.FilterType=Enum.RaycastFilterType.Blacklist
    local ignore={}
    for _,p in ipairs(Players:GetPlayers()) do if p.Character then table.insert(ignore,p.Character) end end
    table.insert(ignore,Camera)
    rp.FilterDescendantsInstances=ignore
    rp.IgnoreWater=true
    return rp
end

local function GetSimRayParams()
    if FrameCache.simRayParams then return FrameCache.simRayParams end
    FrameCache.simRayParams=BuildSimRayParams()
    return FrameCache.simRayParams
end

------------------------------------------------------------
-- VELOCITY TRACKING
------------------------------------------------------------
local function UpdateVelocityTracking()
    local now=tick()
    local dt=now-S.lastVelocityUpdate
    if dt<0.03 then return end
    for _,player in ipairs(Players:GetPlayers()) do
        if player==LocalPlayer then continue end
        local char=player.Character;if not char then continue end
        local hrp=GetHRP(char);if not hrp then continue end
        local vel=hrp.AssemblyLinearVelocity
        local pos=hrp.Position
        if not playerPositionHistory[player] then playerPositionHistory[player]={} end
        table.insert(playerPositionHistory[player],{Pos=pos,Time=now})
        while #playerPositionHistory[player]>20 do table.remove(playerPositionHistory[player],1) end
        if not playerVerticalHistory[player] then playerVerticalHistory[player]={} end
        table.insert(playerVerticalHistory[player],{Y=vel.Y,Time=now})
        while #playerVerticalHistory[player]>15 do table.remove(playerVerticalHistory[player],1) end
        if playerVelocities[player] then
            local prev=playerVelocities[player].Velocity
            local acc=(vel-prev)/dt
            acc=Vector3.new(math.clamp(acc.X,-80,80),math.clamp(acc.Y,-300,300),math.clamp(acc.Z,-80,80))
            playerAccelerations[player]=acc
        end
        playerVelocities[player]={Velocity=vel,Time=now}
        local hVel=Vector3.new(vel.X,0,vel.Z)
        if hVel.Magnitude>1 then
            if not playerStrafeHistory[player] then playerStrafeHistory[player]={} end
            table.insert(playerStrafeHistory[player],{Dir=hVel.Unit,Time=now})
            while #playerStrafeHistory[player]>20 do table.remove(playerStrafeHistory[player],1) end
        end
    end
    S.lastVelocityUpdate=now
end

local function GetPlayerVelocity(player)
    local data=playerVelocities[player]
    if data then return data.Velocity end
    local char=player.Character
    if char then local hrp=GetHRP(char);if hrp then return hrp.AssemblyLinearVelocity end end
    return Vector3.zero
end

local function GetPlayerAcceleration(player) return playerAccelerations[player] or Vector3.zero end

local function GetPositionDerivedVelocity(player)
    local hist=playerPositionHistory[player]
    if not hist or #hist<3 then return GetPlayerVelocity(player) end
    local recent=hist[#hist]
    local older=hist[math.max(1,#hist-3)]
    local dt=recent.Time-older.Time
    if dt<0.01 then return GetPlayerVelocity(player) end
    return (recent.Pos-older.Pos)/dt
end

------------------------------------------------------------
-- MOVEMENT SIMULATION
------------------------------------------------------------
local function SimTraceGround(position,rp)
    local result=Workspace:Raycast(position+Vector3.new(0,3,0),Vector3.new(0,-200,0),rp)
    if result then return result.Position,result.Normal end
    return nil,nil
end

local function SimCheckWall(fromPos,toPos,rp)
    local dir=toPos-fromPos
    if dir.Magnitude<0.01 then return false,toPos end
    local hDir=Vector3.new(dir.X,0,dir.Z)
    if hDir.Magnitude<0.01 then return false,toPos end
    local feetCheck=Workspace:Raycast(fromPos+Vector3.new(0,0.5,0),hDir,rp)
    local chestCheck=Workspace:Raycast(fromPos+Vector3.new(0,2,0),hDir,rp)
    if feetCheck or chestCheck then
        local hit=feetCheck or chestCheck
        local stopPos=hit.Position+hit.Normal*0.5
        return true,Vector3.new(stopPos.X,fromPos.Y,stopPos.Z)
    end
    return false,toPos
end

local function SimTraceSurface(fromPos,moveDir,distance,rp)
    if distance<0.01 then return fromPos,false end
    local stepSize=2;local numSteps=math.ceil(distance/stepSize);local currentPos=fromPos
    for i=1,numSteps do
        local stepDist=math.min(stepSize,distance-(i-1)*stepSize)
        local nextPos=currentPos+moveDir*stepDist
        local blocked,stopPos=SimCheckWall(currentPos,nextPos,rp)
        if blocked then return stopPos,true end
        local groundPos,groundNormal=SimTraceGround(nextPos,rp)
        if groundPos then
            local slopeAngle=math.acos(math.clamp(groundNormal.Y,-1,1))
            if slopeAngle<math.rad(60) then
                local heightDiff=groundPos.Y-currentPos.Y
                if heightDiff<5 and heightDiff>-20 then currentPos=groundPos+Vector3.new(0,2.5,0)
                else return currentPos,true end
            else currentPos=groundPos+Vector3.new(0,2.5,0) end
        else return nextPos,false end
    end
    return currentPos,false
end

local function SimulateTargetPosition(player,totalTime,steps,rp)
    steps=steps or 15
    rp=rp or GetSimRayParams()
    local char=player.Character;if not char then return nil end
    local hrp=GetHRP(char);if not hrp then return nil end
    local currentPos=hrp.Position
    local rawVel=GetPlayerVelocity(player)
    local posVel=GetPositionDerivedVelocity(player)
    local hRaw=Vector3.new(rawVel.X,0,rawVel.Z)
    local hPos=Vector3.new(posVel.X,0,posVel.Z)
    local hVel
    if hPos.Magnitude>1 and (hPos-hRaw).Magnitude>2 then
        hVel=hPos.Magnitude>0.1 and hPos.Unit*math.max(hRaw.Magnitude,hPos.Magnitude) or hRaw
    else hVel=hRaw end
    local vY=rawVel.Y
    local acceleration=GetPlayerAcceleration(player)
    local grounded=IsOnGround(char)
    if hVel.Magnitude>80 then hVel=hVel.Unit*80 end
    local timeStep=totalTime/steps
    local simPos=currentPos;local simVelY=vY;local simGrounded=grounded
    local simHVel=hVel;local simStopped=false
    local isJumping=grounded and vY>TC2_JUMP_POWER*0.5
    for i=1,steps do
        if simStopped and simGrounded then continue end
        local t=timeStep
        if simGrounded and not isJumping then
            if not simStopped then
                local hAcc=Vector3.new(acceleration.X,0,acceleration.Z)
                local stepVel=simHVel+hAcc*t*0.3
                if stepVel.Magnitude>80 then stepVel=stepVel.Unit*80 end
                local moveDist=stepVel.Magnitude*t
                local moveDir2=stepVel.Magnitude>0.1 and stepVel.Unit or Vector3.zero
                if moveDist>0.01 then
                    local newPos,hitWall=SimTraceSurface(simPos,moveDir2,moveDist,rp)
                    simPos=newPos
                    if hitWall then simStopped=true;simHVel=Vector3.zero else simHVel=stepVel end
                end
            end
            local groundCheck=SimTraceGround(simPos,rp)
            if not groundCheck or (simPos.Y-groundCheck.Y)>5 then simGrounded=false;simVelY=0;simStopped=false end
        else
            if isJumping then simVelY=TC2_JUMP_POWER;simGrounded=false;isJumping=false end
            if not simStopped then
                local hAcc=Vector3.new(acceleration.X,0,acceleration.Z)
                simHVel=simHVel+hAcc*t*0.15
                if simHVel.Magnitude>80 then simHVel=simHVel.Unit*80 end
            end
            local hMove=simHVel*t;local newPos=simPos+hMove
            if hMove.Magnitude>0.01 then
                local blocked,stopPos=SimCheckWall(simPos,newPos,rp)
                if blocked then newPos=stopPos;simHVel=Vector3.zero;simStopped=true end
            end
            local yMove=simVelY*t-0.5*TC2_GRAVITY*t*t
            simVelY=simVelY-TC2_GRAVITY*t
            newPos=Vector3.new(newPos.X,simPos.Y+yMove,newPos.Z)
            local groundPos=SimTraceGround(newPos,rp)
            if groundPos and newPos.Y<=groundPos.Y+2.5 then
                newPos=Vector3.new(newPos.X,groundPos.Y+2.5,newPos.Z);simGrounded=true;simVelY=0
            end
            if yMove>0 then
                local ceilCheck=Workspace:Raycast(simPos,Vector3.new(0,yMove+1,0),rp)
                if ceilCheck then newPos=Vector3.new(newPos.X,ceilCheck.Position.Y-3,newPos.Z);simVelY=0 end
            end
            simPos=newPos
        end
    end
    local groundCheck2=SimTraceGround(simPos,rp)
    if groundCheck2 and simPos.Y<groundCheck2.Y+2.5 then
        simPos=Vector3.new(simPos.X,groundCheck2.Y+2.5,simPos.Z)
    end
    return simPos
end

------------------------------------------------------------
-- OBJECT CACHING
------------------------------------------------------------
local function RefreshObjectCaches()
    cachedSentries={};cachedDispensers={};cachedTeleporters={}
    for _,v in pairs(Workspace:GetChildren()) do
        if v.Name:match("'s Sentry$") then table.insert(cachedSentries,v)
        elseif v.Name:match("'s Dispenser$") then table.insert(cachedDispensers,v)
        elseif v.Name:match("'s Teleporter") then table.insert(cachedTeleporters,v) end
    end
    cachedAmmo={};cachedHP={}
    local mi=Workspace:FindFirstChild("Map")
    if mi then local items=mi:FindFirstChild("Items");if items then
        for _,v in pairs(items:GetChildren()) do
            if v.Name:match("Ammo") or v.Name=="DeadAmmo" then table.insert(cachedAmmo,v)
            elseif v.Name:match("HP") then table.insert(cachedHP,v) end
        end
    end end
end

local function removeFrom(t,c) for i=#t,1,-1 do if t[i]==c then table.remove(t,i) end end end

do
    Workspace.ChildAdded:Connect(function(c) task.defer(function()
        if c.Name:match("'s Sentry$") then table.insert(cachedSentries,c)
        elseif c.Name:match("'s Dispenser$") then table.insert(cachedDispensers,c)
        elseif c.Name:match("'s Teleporter") then table.insert(cachedTeleporters,c) end
    end) end)
    Workspace.ChildRemoved:Connect(function(c) task.defer(function()
        removeFrom(cachedSentries,c);removeFrom(cachedDispensers,c);removeFrom(cachedTeleporters,c)
    end) end)
    task.spawn(function()
        task.wait(3);RefreshObjectCaches()
        local mi=Workspace:FindFirstChild("Map")
        if mi then local items=mi:FindFirstChild("Items");if items then
            items.ChildAdded:Connect(function(c) task.defer(function()
                if c.Name:match("Ammo") or c.Name=="DeadAmmo" then table.insert(cachedAmmo,c)
                elseif c.Name:match("HP") then table.insert(cachedHP,c) end
            end) end)
            items.ChildRemoved:Connect(function(c) task.defer(function()
                removeFrom(cachedAmmo,c);removeFrom(cachedHP,c)
            end) end)
        end end
    end)
end

local function GetMyStickybombs()
    local s2={};local dest=Workspace:FindFirstChild("Destructable")
    if dest then for _,v in pairs(dest:GetChildren()) do
        if v.Name:match(LocalPlayer.Name) and v.Name:match("stickybomb$") then
            local p=v:IsA("BasePart") and v or v:FindFirstChildWhichIsA("BasePart")
            if p then table.insert(s2,p) end
        end
    end end;return s2
end

local function GetProjectiles()
    local proj={}
    local ri=Workspace:FindFirstChild("Ray_ignore")
    if ri then for _,v in pairs(ri:GetChildren()) do
        local isP=false
        for _,n in pairs(projectileNames) do if v.Name==n or v.Name:match("bomb$") then isP=true;break end end
        if isP then local pp=v:IsA("BasePart") and v or v:FindFirstChildWhichIsA("BasePart");if pp then table.insert(proj,v) end end
    end end
    local dest=Workspace:FindFirstChild("Destructable")
    if dest then for _,v in pairs(dest:GetChildren()) do
        if v.Name:match("stickybomb$") then local pp=v:IsA("BasePart") and v or v:FindFirstChildWhichIsA("BasePart");if pp then table.insert(proj,v) end end
    end end
    return proj
end

------------------------------------------------------------
-- CHARGE DETECTION
------------------------------------------------------------
local function GetCurrentWeaponSpeed(weaponName)
    if weaponName=="Airstrike" then
        local rj = IsRocketJumped()
        return rj and 110 or 68.75, 0, 0, 0, 99
    end
    local cd=ChargeWeapons[weaponName]
    if cd then
        local chargeAmount = S.currentChargePercent
        local speed=cd.SpeedMin+(cd.SpeedMax-cd.SpeedMin)*chargeAmount
        local gravity
        if cd.GravityMin and cd.GravityMax then
            gravity=cd.GravityMin-(cd.GravityMin-cd.GravityMax)*chargeAmount
        else
            gravity=cd.Gravity
        end
        return speed,gravity,cd.InitialAngle,cd.ArmTime or 0,cd.Lifetime or 99
    end
    local pd=ProjectileWeapons[weaponName]
    if pd then return pd.Speed,pd.Gravity,pd.InitialAngle,0,pd.Lifetime or 99 end
    return nil
end

do
    UserInputService.InputBegan:Connect(function(input,processed)
        if processed or Library.Unloaded then return end
        if input.UserInputType==Enum.UserInputType.MouseButton1 then
            local w=GetLocalWeapon()
            if ChargeWeapons[w] then S.isCharging=true;S.chargeStartTime=tick();S.currentChargePercent=0;ChargeTick.Value=tick() end
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if Library.Unloaded then return end
        if input.UserInputType==Enum.UserInputType.MouseButton1 then S.isCharging=false end
    end)
    UserInputService.TouchStarted:Connect(function()
        if Library.Unloaded or not isMobileMode then return end
        local w=GetLocalWeapon()
        if ChargeWeapons[w] then S.isCharging=true;S.chargeStartTime=tick();S.currentChargePercent=0;ChargeTick.Value=tick() end
    end)
    UserInputService.TouchEnded:Connect(function()
        if Library.Unloaded or not isMobileMode then return end
        S.isCharging=false
    end)
end

------------------------------------------------------------
-- PROJECTILE PATH SIMULATION
------------------------------------------------------------
local function SimulateProjectilePath(origin,aimDir,speed,gravity,initAngle,lifetime,rp)
    rp=rp or GetSimRayParams()
    local hDir=Vector3.new(aimDir.X,0,aimDir.Z)
    if hDir.Magnitude<0.01 then return nil,false end
    hDir=hDir.Unit
    local pitch=math.asin(math.clamp(aimDir.Y,-1,1))
    local totalAngle=pitch+math.rad(initAngle)
    local hSpeed=speed*math.cos(totalAngle)
    local vSpeed=speed*math.sin(totalAngle)
    local steps=30;local maxTime=math.min(lifetime,5)
    local prevPos=origin
    for i=1,steps do
        local t=(i/steps)*maxTime
        local hPos=origin+hDir*(hSpeed*t)
        local yPos=origin.Y+vSpeed*t-0.5*gravity*t*t
        local curPos=Vector3.new(hPos.X,yPos,hPos.Z)
        local hit=Workspace:Raycast(prevPos,curPos-prevPos,rp)
        if hit then return hit.Position,true end
        prevPos=curPos
    end
    return prevPos,false
end

local function CanProjectileReachTarget(origin,targetPos,speed,gravity,initAngle,lifetime,weaponName,rp)
    rp=rp or GetSimRayParams()
    if gravity==0 then
        local dir=(targetPos-origin)
        local hit=Workspace:Raycast(origin,dir,rp)
        if hit then
            local hitDist=(hit.Position-origin).Magnitude
            local targetDist=dir.Magnitude
            return hitDist>=targetDist*0.95
        end
        return true
    end
    local aimPoint=targetPos
    local aimDir=(aimPoint-origin).Unit
    local endPos,hitSomething=SimulateProjectilePath(origin,aimDir,speed,gravity,initAngle,lifetime,rp)
    if not endPos then return false end
    local distToTarget=(endPos-targetPos).Magnitude
    return distToTarget<10
end

------------------------------------------------------------
-- PROJECTILE PREDICTION
------------------------------------------------------------
local function PredictProjectileHit(targetPart,player,weaponName)
    local speed,gravity,initAngle,armTime,lifetime=GetCurrentWeaponSpeed(weaponName)
    if not speed then return targetPart.Position,0 end
    local origin=(Camera.CFrame*CFrame.new(PROJECTILE_OFFSET)).Position
    local ping=GetPing()
    local char=targetPart:FindFirstAncestorOfClass("Model")
    local hrp=char and GetHRP(char)
    if not hrp then return targetPart.Position,0 end
    local currentPos=hrp.Position
    local velocity=GetPlayerVelocity(player)
    if velocity.Magnitude<0.5 then return currentPos,(currentPos-origin).Magnitude/speed end
    local rp=GetSimRayParams()
    local predictedPos=currentPos;local travelTime=0
    for iteration=1,5 do
        local dx=predictedPos.X-origin.X;local dz=predictedPos.Z-origin.Z
        local horizontalDist=math.sqrt(dx*dx+dz*dz)
        if gravity==0 and initAngle==0 then
            travelTime=(predictedPos-origin).Magnitude/speed
        else
            local angleRad=math.rad(initAngle)
            local horizontalSpeed=speed*math.cos(angleRad)
            travelTime=horizontalDist/math.max(horizontalSpeed,1)
        end
        travelTime=math.min(travelTime,lifetime)
        if armTime and armTime>0 then travelTime=math.max(travelTime,armTime) end
        -- Apply ping compensation twice (client -> server -> client)
        local totalTime=travelTime+(ping*2)
        local simSteps=math.clamp(math.floor(totalTime/0.033),5,30)
        local simResult=SimulateTargetPosition(player,totalTime,simSteps,rp)
        if simResult then predictedPos=simResult else return currentPos,travelTime end
    end

    local myHRP=GetHRP(GetLocalCharacter())
    if myHRP and (predictedPos-myHRP.Position).Magnitude<3 then
        return currentPos,(currentPos-origin).Magnitude/speed
    end

    local fireDir=(predictedPos-origin).Unit
    local closeWall=Workspace:Raycast(origin,fireDir*8,rp)
    if closeWall then return currentPos,(currentPos-origin).Magnitude/speed end

    if ArcWeapons[weaponName] and gravity>0 then
        if not CanProjectileReachTarget(origin,predictedPos,speed,gravity,initAngle,lifetime,weaponName,rp) then
            if CanProjectileReachTarget(origin,currentPos,speed,gravity,initAngle,lifetime,weaponName,rp) then
                return currentPos,(currentPos-origin).Magnitude/speed
            end
            return currentPos,(currentPos-origin).Magnitude/speed
        end
    end

    if gravity==0 then
        local losCheck=Workspace:Raycast(origin,(predictedPos-origin),rp)
        if losCheck then
            local hitDist=(losCheck.Position-origin).Magnitude
            local targetDist=(predictedPos-origin).Magnitude
            if hitDist<targetDist*0.95 then
                return currentPos,(currentPos-origin).Magnitude/speed
            end
        end
    end

    return predictedPos,travelTime
end

local function CalculateAimPoint(origin,targetPos,speed,gravity,weaponName)
    if gravity==0 then return targetPos end
    local dir=targetPos-origin;local hDir=Vector3.new(dir.X,0,dir.Z);local hDist=hDir.Magnitude
    if hDist<1 then return targetPos end
    local initAngle=0
    local pd=ProjectileWeapons[weaponName];if pd then initAngle=pd.InitialAngle or 0 end
    local cd=ChargeWeapons[weaponName];if cd then initAngle=cd.InitialAngle or 0 end
    local v,g,x,y=speed,gravity,hDist,dir.Y
    local v2=v*v;local v4=v2*v2;local disc=v4-g*(g*x*x+2*y*v2)
    if disc>=0 then
        local sqD=math.sqrt(disc);local angle=math.atan2(v2-sqD,g*x)
        if initAngle>0 then angle=angle-math.rad(initAngle) end
        return origin+hDir.Unit*hDist+Vector3.new(0,math.tan(angle)*hDist,0)
    end
    local flightTime=hDist/speed;local drop=0.5*gravity*flightTime*flightTime
    local aim=targetPos+Vector3.new(0,drop,0)
    if initAngle>0 then aim=aim-Vector3.new(0,math.tan(math.rad(initAngle))*hDist*0.3,0) end
    return aim
end

local function GenerateProjectilePath(origin,targetPos,weaponName,steps)
    steps=steps or 30
    local speed,gravity,initAngle=GetCurrentWeaponSpeed(weaponName)
    if not speed then return {origin,targetPos} end
    if not ArcWeapons[weaponName] or gravity==0 then return {origin,targetPos} end
    local aimPoint=CalculateAimPoint(origin,targetPos,speed,gravity,weaponName)
    local aimDir=(aimPoint-origin).Unit
    local hAimDir=Vector3.new(aimDir.X,0,aimDir.Z)
    if hAimDir.Magnitude<0.01 then return {origin,targetPos} end
    hAimDir=hAimDir.Unit
    local aimPitch=math.asin(math.clamp(aimDir.Y,-1,1))
    local totalAngle=aimPitch+math.rad(initAngle)
    local hSpeed=speed*math.cos(totalAngle);local vSpeed=speed*math.sin(totalAngle)
    local hDist=Vector3.new(targetPos.X-origin.X,0,targetPos.Z-origin.Z).Magnitude
    local totalTime=hDist/math.max(hSpeed,1)
    local rp=GetSimRayParams();local points={}
    for i=0,steps do
        local t=(i/steps)*totalTime
        local hPos=origin+hAimDir*(hSpeed*t);local yPos=origin.Y+vSpeed*t-0.5*gravity*t*t
        local point=Vector3.new(hPos.X,yPos,hPos.Z)
        if #points>0 then
            local last=points[#points];local wh=Workspace:Raycast(last,point-last,rp)
            if wh then table.insert(points,wh.Position);break end
        end
        table.insert(points,point)
    end
    return points
end

------------------------------------------------------------
-- TARGET SELECTION
------------------------------------------------------------
local function BuildPlayerData()
    local data={};local lc=GetLocalCharacter();local lhrp=lc and GetHRP(lc)
    if not lhrp then return data end
    for _,plr in ipairs(Players:GetPlayers()) do
        if plr==LocalPlayer or not IsPlayerAlive(plr) then continue end
        local char=plr.Character;if not char then continue end
        local hrp=GetHRP(char);if not hrp then continue end
        local sp,onScreen=WorldToViewportPoint(hrp.Position)
        table.insert(data,{
            Player=plr,Character=char,HRP=hrp,ScreenPos=sp,OnScreen=onScreen,
            Distance=(lhrp.Position-hrp.Position).Magnitude,
            ScreenDistance=onScreen and (sp-FrameCache.screenCenter).Magnitude or math.huge,
            IsEnemy=IsEnemy(plr),IsFriend=IsFriend(plr),Class=GetPlayerClass(plr),
        })
    end
    return data
end

local function GetBestHitscanPart(char)
    if char==LocalPlayer.Character then return nil end
    local mode=Config.Ragebot.HitscanMode;local priority=Config.Ragebot.PriorityHitbox
    if mode=="Force Priority" or mode=="Priority Only" then
        for _,partName in ipairs(HitboxTables[priority] or {}) do
            local p=char:FindFirstChild(partName)
            if p and (Config.Wallbang.Enable or IsPartVisible(p)) then return p end
        end
        return nil
    end
    local best,shortest=nil,math.huge
    for _,hb in ipairs({"Head","Chest","Torso","Arms","Legs","Feet"}) do
        for _,partName in ipairs(HitboxTables[hb] or {}) do
            local p=char:FindFirstChild(partName)
            if p and (Config.Wallbang.Enable or IsPartVisible(p)) then
                local d=(FrameCache.camPos-p.Position).Magnitude
                if d<shortest then shortest=d;best=p end
            end
        end
    end
    return best
end

local function GetRagebotTarget(playerData)
    if not WeaponAllowed() then return nil,nil end
    local best,shortest,bestPlr=nil,math.huge,nil
    for _,pd in ipairs(playerData) do
        if not pd.IsEnemy then continue end
        local part=GetBestHitscanPart(pd.Character);if not part then continue end
        local d=(FrameCache.camPos-part.Position).Magnitude
        if d<shortest then shortest=d;best=part;bestPlr=pd.Player end
    end
    return best,bestPlr
end

local function GetSilentAimTarget(playerData)
    local fov=Options.SilentAimFOV.Value
    local bestPart,bestDist,bestPlayer=nil,math.huge,nil
    local aimTargets=Options.AimAtTargets and Options.AimAtTargets.Value or {}
    local weapon=GetLocalWeapon()
    local isSyringe=IsSyringeWeapon(weapon)
    local sortMode=Options.SilentAimSort and Options.SilentAimSort.Value or "Closest to Mouse"
    local selParts=Options.SilentAimBodyParts and Options.SilentAimBodyParts.Value or {Head=true}
    local sc=FrameCache.screenCenter

    if aimTargets["Players"] then
        for _,pd in ipairs(playerData) do
            if isSyringe then
                if pd.IsEnemy then continue end
                if IsPlayerFullHP(pd.Player) then continue end
            else
                if not pd.IsEnemy then continue end
            end
            if not pd.OnScreen then continue end
            if Toggles.SilentIgnoreInvis and Toggles.SilentIgnoreInvis.Value then
                local h=pd.Character:FindFirstChild("Head")
                if h and h.Transparency>0.9 then continue end
            end
            local part=GetBestVisiblePart(pd.Character,selParts)
            if not part then local hrp=GetHRP(pd.Character);if hrp and IsPartVisible(hrp) then part=hrp end end
            if not part then continue end
            local sp,onScreen=WorldToViewportPoint(part.Position);if not onScreen then continue end
            local dist=sortMode=="Closest to Mouse" and (sp-sc).Magnitude or pd.Distance
            if (sortMode=="Closest to Mouse" and dist<=fov and dist<bestDist) or (sortMode=="Closest Distance" and dist<bestDist) then
                bestDist=dist;bestPart=part;bestPlayer=pd.Player
            end
        end
    end

    if aimTargets["Sentry"] then
        for _,v in pairs(cachedSentries) do
            if not v.Parent then continue end
            local ownerName=v.Name:match("^(.+)'s Sentry$")
            local isEnemySentry=true
            if ownerName then for _,plr in ipairs(Players:GetPlayers()) do
                if plr.Name==ownerName and plr.Team==LocalPlayer.Team then isEnemySentry=false;break end
            end end
            if not isEnemySentry then continue end
            local hum=v:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health<=0 then continue end
            local pp=v.PrimaryPart or v:FindFirstChildWhichIsA("BasePart")
            if not pp then for _,child in pairs(v:GetDescendants()) do if child:IsA("BasePart") then pp=child;break end end end
            if not pp or not IsPartVisible(pp) then continue end
            local sp,os2=WorldToViewportPoint(pp.Position);if not os2 then continue end
            local d=sortMode=="Closest to Mouse" and (sp-sc).Magnitude or (FrameCache.camPos-pp.Position).Magnitude
            if (sortMode=="Closest to Mouse" and d<=fov and d<bestDist) or (sortMode=="Closest Distance" and d<bestDist) then bestDist=d;bestPart=pp;bestPlayer=nil end
        end
    end

    if aimTargets["Stickybomb"] then
        local dest=Workspace:FindFirstChild("Destructable")
        if dest then for _,v in pairs(dest:GetChildren()) do
            if v.Name:match("stickybomb$") and not v.Name:match(LocalPlayer.Name) then
                local isEn=true
                for _,plr in ipairs(Players:GetPlayers()) do
                    if v.Name:match(plr.Name) and plr.Team==LocalPlayer.Team then isEn=false;break end
                end
                if not isEn then continue end
                local p=v:IsA("BasePart") and v or v:FindFirstChildWhichIsA("BasePart")
                if not p or not IsPartVisible(p) then continue end
                local sp,os2=WorldToViewportPoint(p.Position);if not os2 then continue end
                local d=sortMode=="Closest to Mouse" and (sp-sc).Magnitude or (FrameCache.camPos-p.Position).Magnitude
                if (sortMode=="Closest to Mouse" and d<=fov and d<bestDist) or (sortMode=="Closest Distance" and d<bestDist) then bestDist=d;bestPart=p;bestPlayer=nil end
            end
        end end
    end

    if bestPart then
        local myHRP=GetHRP(GetLocalCharacter())
        if myHRP and (bestPart.Position-myHRP.Position).Magnitude<3 then return nil,nil end
    end

    return bestPart,bestPlayer
end

local function GetTriggerbotTarget(playerData)
    local sc=FrameCache.screenCenter
    local trigParts=Options.TriggerbotParts and Options.TriggerbotParts.Value or {Head=true,Chest=true}
    local weapon=GetLocalWeapon();local isSyringe=IsSyringeWeapon(weapon)
    for _,pd in ipairs(playerData) do
        if isSyringe then if pd.IsEnemy then continue end
        else if not pd.IsEnemy then continue end end
        if not pd.OnScreen or not IsPlayerAlive(pd.Player) then continue end
        for groupName,enabled in pairs(trigParts) do
            if not enabled then continue end
            local parts=HitboxTables[groupName];if not parts then continue end
            for _,partName in ipairs(parts) do
                local part=pd.Character:FindFirstChild(partName)
                if not part or not IsPartVisible(part) then continue end
                local sp,onScreen=WorldToViewportPoint(part.Position)
                if not onScreen then continue end
                if (sp-sc).Magnitude<=1 then return true,pd.Player end
            end
        end
    end
    return false,nil
end

------------------------------------------------------------
-- AIM ARMS
------------------------------------------------------------
local function AimArmsAtTarget(targetPos)
    if not targetPos then return end
    local vm=Camera:FindFirstChild("PrimaryVM");if not vm then return end
    local am=vm:FindFirstChild("CharacterArmsModel");if not am then return end
    local vp=vm:GetPivot();local ao=vp:ToObjectSpace(am:GetPivot())
    local lr=CFrame.lookAt(vp.Position,targetPos)*CFrame.Angles(math.rad(180),math.rad(180),math.rad(180))
    am:PivotTo(lr*ao)
end

local function UpdateSmoothAimArms()
    if not (Toggles.SilentAimArms and Toggles.SilentAimArms.Value) then return end
    if not (Options.SilentAimArmsMode and Options.SilentAimArmsMode.Value=="Smooth") then return end
    local vm=Camera:FindFirstChild("PrimaryVM");if not vm then return end
    local am=vm:FindFirstChild("CharacterArmsModel");if not am then return end
    local now=tick()

    if S.armReturning then
        local elapsed=now-S.armReturnStart
        if elapsed>=0.7 then S.armReturning=false;S.armTarget=nil;return end
        return
    end

    if S.shotConfirmed and (now-S.shotConfirmTime)<0.1 then
        if S.armTarget then AimArmsAtTarget(S.armTarget) end
        return
    elseif S.shotConfirmed and (now-S.shotConfirmTime)>=0.1 then
        S.shotConfirmed=false;S.armReturning=true;S.armReturnStart=now
        return
    end

    if S.armTarget then
        local elapsed=now-S.armSmoothStart
        local alpha=math.clamp(elapsed/0.15,0,1)
        if alpha<1 then
            local vp2=vm:GetPivot()
            local camDir=Camera.CFrame.LookVector
            local targetDir=(S.armTarget-vp2.Position).Unit
            local lerpedDir=camDir:Lerp(targetDir,alpha)
            local lerpedPos=vp2.Position+lerpedDir*10
            AimArmsAtTarget(lerpedPos)
        else
            AimArmsAtTarget(S.armTarget)
        end
    end
end

------------------------------------------------------------
-- REMOTE FINDERS
------------------------------------------------------------
local function FindBannerFolder()
    S.bannerFolder=ReplicatedStorage:FindFirstChild("Folder ")
    if not S.bannerFolder then
        for _,child in ipairs(ReplicatedStorage:GetChildren()) do
            if child.Name:match("^Folder") then S.bannerFolder=child;break end
        end
    end
end

local function SetupRemoteFinder()
    FindBannerFolder()
    if not S.bannerFolder then Library:Notify("⚠ Could not find remote folder",4);return end
    remoteSet={}
    for _,child in ipairs(S.bannerFolder:GetChildren()) do
        if child:IsA("RemoteEvent") or child:IsA("RemoteFunction") then remoteSet[child]=true end
    end
    Library:Notify("🔍 Shoot your weapon to detect the remote...",5)
end

------------------------------------------------------------
-- GET AIM CFRAME (shared between silent aim and ragebot)
------------------------------------------------------------
local function GetProjectileAimCFrame(target,targetPlr,weapon)
    if weapon=="Huntsman" then
        local tChar=target:FindFirstAncestorOfClass("Model")
        if tChar then local head=tChar:FindFirstChild("Head");if head and IsPartVisible(head) then target=head end end
    end
    local predicted,pt=PredictProjectileHit(target,targetPlr,weapon)
    if weapon=="Huntsman" then predicted=predicted+Vector3.new(0,1.5,0) end
    local spd,grav=GetCurrentWeaponSpeed(weapon)
    if grav and grav>0 then
        return CFrame.lookAt(FrameCache.camPos,CalculateAimPoint(FrameCache.camPos,predicted,spd,grav,weapon)),predicted
    else
        return CFrame.lookAt(FrameCache.camPos,predicted),predicted
    end
end

------------------------------------------------------------
-- SILENT AIM HOOK
------------------------------------------------------------
task.spawn(function()
    pcall(function()
        local camModule=require(ReplicatedStorage.Modules.gameCamera)
        if camModule and camModule.GetCameraAimCFrame then
            local orig=camModule.GetCameraAimCFrame
            camModule.GetCameraAimCFrame=function(self2,...)
                if not IsPlayerAlive(LocalPlayer) then return orig(self2,...) end
                local weapon=GetLocalWeapon()
                if BlacklistedWeapons[weapon] then return orig(self2,...) end
                local isProj=ProjectileWeapons[weapon]~=nil or ChargeWeapons[weapon]~=nil

                -- Silent aim
                if Config.SilentAim.Enabled and S.silentAimKeyActive then
                    local target=FrameCache.silentTarget
                    local targetPlr=FrameCache.silentTargetPlr
                    if target then
                        if isProj and targetPlr then
                            local cf,aimPos=GetProjectileAimCFrame(target,targetPlr,weapon)
                            FrameCache.predictedPos=aimPos
                            if Toggles.SilentAimArms and Toggles.SilentAimArms.Value then
                                local mode=Options.SilentAimArmsMode and Options.SilentAimArmsMode.Value or "Snap"
                                if mode=="Snap" then AimArmsAtTarget(aimPos)
                                else S.armTarget=aimPos;S.armSmoothStart=tick() end
                            end
                            return cf
                        else
                            if Toggles.SilentAimArms and Toggles.SilentAimArms.Value then
                                local mode=Options.SilentAimArmsMode and Options.SilentAimArmsMode.Value or "Snap"
                                if mode=="Snap" then AimArmsAtTarget(target.Position)
                                else S.armTarget=target.Position;S.armSmoothStart=tick() end
                            end
                            return CFrame.lookAt(FrameCache.camPos,target.Position)
                        end
                    end
                end

                -- Auto backstab
                if Toggles.AutoBackstab and Toggles.AutoBackstab.Value then
                    local myClass=GetLocalClass();local myWeapon=GetLocalWeapon()
                    if myClass=="Agent" and BackstabWeapons[myWeapon] then
                        local lh=GetHRP(GetLocalCharacter())
                        if lh then
                            local pd=FrameCache.playerData or {}
                            for _,pdi in ipairs(pd) do
                                if not pdi.IsEnemy or pdi.Distance>BACKSTAB_RANGE then continue end
                                local toT=(pdi.HRP.Position-lh.Position).Unit
                                if toT:Dot(pdi.HRP.CFrame.LookVector)>0.3 then
                                    local backPos=pdi.HRP.Position-pdi.HRP.CFrame.LookVector*1
                                    if Toggles.AutoBackstabAimArms and Toggles.AutoBackstabAimArms.Value then
                                        AimArmsAtTarget(backPos)
                                    end
                                    return CFrame.lookAt(FrameCache.camPos,backPos)
                                end
                            end
                        end
                    end
                end

                -- Auto melee aim (does not stack with auto backstab)
                if Toggles.AutoMelee and Toggles.AutoMelee.Value then
                    local myWeapon=GetLocalWeapon()
                    if MeleeWeapons[myWeapon] and not (Toggles.AutoBackstab and Toggles.AutoBackstab.Value and GetLocalClass()=="Agent" and BackstabWeapons[myWeapon]) then
                        local meleeMode=Options.AutoMeleeMode and Options.AutoMeleeMode.Value or "Rage"
                        local meleeRange=meleeMode=="Demoknight" and MELEE_RANGE_DEMOKNIGHT or MELEE_RANGE_RAGE
                        local lh=GetHRP(GetLocalCharacter())
                        if lh then
                            local pd=FrameCache.playerData or {}
                            local bestTarget,bestDist=nil,math.huge
                            for _,pdi in ipairs(pd) do
                                if not pdi.IsEnemy or pdi.Distance>meleeRange then continue end
                                if pdi.Distance<bestDist then bestDist=pdi.Distance;bestTarget=pdi end
                            end
                            if bestTarget then
                                return CFrame.lookAt(FrameCache.camPos,bestTarget.HRP.Position)
                            end
                        end
                    end
                end

                -- Ragebot
                if Config.Ragebot.Enabled and WeaponAllowed() then
                    local part=FrameCache.ragebotTarget
                    local partPlr=FrameCache.ragebotTargetPlr
                    if part then
                        if isProj and partPlr then
                            local cf,aimPos=GetProjectileAimCFrame(part,partPlr,weapon)
                            FrameCache.predictedPos=aimPos
                            return cf
                        else
                            return CFrame.lookAt(FrameCache.camPos,part.Position)
                        end
                    end
                end

                return orig(self2,...)
            end
        end
    end)
end)

------------------------------------------------------------
-- HOOKS
------------------------------------------------------------
do
    local OldIndex
    OldIndex=hookmetamethod(game,"__index",function(Self,Key)
        if Key=="Clips" and Config.Wallbang.Enable and not checkcaller() then return Workspace.Map end
        return OldIndex(Self,Key)
    end)

    local OldNamecall
    OldNamecall=hookmetamethod(game,"__namecall",function(self2,...)
        local method=getnamecallmethod()

        -- Shooting remote detection
        if not S.shootingRemoteFound and remoteSet[self2] and (method=="FireServer" or method=="InvokeServer") then
            local args={...}
            if #args>=3 then
                local wn;pcall(function()
                    local c=Workspace:FindFirstChild(LocalPlayer.Name)
                    if c then c=c:FindFirstChild("Gun");if c then c=c:FindFirstChild("Boop");if c then wn=c.Value end end end
                end)
                if wn and type(args[1])=="string" and string.find(args[1],wn,1,true) and type(args[2])=="number" and type(args[3])=="number" then
                    local rn=self2.Name;local prev=lastKnownAmmo[rn];lastKnownAmmo[rn]=args[2]
                    if prev and args[2]<prev then
                        S.shootingRemoteFound=true;S.shootingRemote=self2;getgenv().ShootingRemote=self2
                        Library:Notify("🎯 Shooting remote found: "..rn,4)
                    end
                end
            end
        end

        -- Shot confirmed (for prediction visuals + smooth aim arms)
        if S.shootingRemoteFound and self2==S.shootingRemote and not checkcaller() and (method=="FireServer" or method=="InvokeServer") then
            local args={...}
            if #args>=2 and type(args[2])=="number" then
                local rn=self2.Name;local prev=lastKnownAmmo[rn];lastKnownAmmo[rn]=args[2]
                if prev and args[2]<prev then
                    S.shotConfirmed=true;S.shotConfirmTime=tick()
                    task.spawn(function()
                        local showBox=Toggles.ShowPrediction and Toggles.ShowPrediction.Value
                        local showCircle=Toggles.ShowPredictionCircle and Toggles.ShowPredictionCircle.Value
                        if showBox or showCircle then
                            local weapon=GetLocalWeapon()
                            if PathVisualWeapons[weapon] then
                                local target=FrameCache.silentTarget or FrameCache.ragebotTarget
                                local targetPlr=FrameCache.silentTargetPlr or FrameCache.ragebotTargetPlr
                                if target and targetPlr then
                                    local predicted,travelTime=PredictProjectileHit(target,targetPlr,weapon)
                                    local origin2=(Camera.CFrame*CFrame.new(PROJECTILE_OFFSET)).Position
                                    local pathPts=GenerateProjectilePath(origin2,predicted,weapon,40)
                                    activePredictionVisuals[tick()]={
                                        TargetPos=predicted,TravelTime=travelTime,
                                        SpawnTime=tick(),FadeTime=travelTime+0.3,
                                        PathPoints=pathPts,Weapon=weapon,
                                    }
                                end
                            end
                        end
                    end)
                end
            end
        end

        return OldNamecall(self2,...)
    end)
end

task.spawn(function() task.wait(2);SetupRemoteFinder() end)

------------------------------------------------------------
-- NO SPREAD
------------------------------------------------------------
local function SetupNoSpread()
    if S.noSpreadSetup or not EnsureGUILoaded() then return end
    S.noSpreadSetup=true
    S.kirk.Changed:Connect(function()
        if not Config.NoSpread.Enable or S.charlieKirk then return end
        S.charlieKirk=true;S.kirk.Value=S.kirk.Value*Config.NoSpread.Multiplier;S.charlieKirk=false
    end)
end

------------------------------------------------------------
-- SPEED
------------------------------------------------------------
local function SetupSpeed()
    if S.speedConnection then S.speedConnection:Disconnect();S.speedConnection=nil end
    if Config.Speed.Enable and LocalPlayer.Character then
        LocalPlayer.Character:SetAttribute("Speed",Config.Speed.Value)
        S.speedConnection=LocalPlayer.Character:GetAttributeChangedSignal("Speed"):Connect(function()
            if Config.Speed.Enable and not S.warpActive then LocalPlayer.Character:SetAttribute("Speed",Config.Speed.Value) end
        end)
    end
end

local function ApplyThirdPerson(state)
    pcall(function()
        if LocalPlayer:GetAttribute("ThirdPerson")==nil then LocalPlayer:SetAttribute("ThirdPerson",false) end
        LocalPlayer:SetAttribute("ThirdPerson",state)
        local vip=ReplicatedStorage:FindFirstChild("VIPSettings")
        if vip then local tp=vip:FindFirstChild("AThirdPersonMode");if tp then tp.Value=state end end
    end)
end

local function ApplyDeviceSpoof(platform)
    if platform=="None" then return end
    pcall(function()
        local ntp=LocalPlayer:FindFirstChild("newTcPlayer")
        if ntp then ntp:SetAttribute("Platform",platform);ntp:SetAttribute("Platform Type",platform) end
    end)
end

------------------------------------------------------------
-- MOBILE BUTTON
------------------------------------------------------------
local function CreateMobileButton()
    if S.mobileToggleButton then return end
    local screenGui=Instance.new("ScreenGui")
    screenGui.Name="AegisMobileButton";screenGui.ResetOnSpawn=false
    screenGui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling;screenGui.DisplayOrder=999
    screenGui.Parent=LocalPlayer:WaitForChild("PlayerGui")
    local button=Instance.new("TextButton")
    button.Name="AegisToggle";button.Size=UDim2.new(0,50,0,50)
    button.Position=UDim2.new(0,20,0.5,-25);button.BackgroundColor3=Color3.fromRGB(30,30,30)
    button.BackgroundTransparency=0.3;button.Text="A";button.TextColor3=Color3.fromRGB(200,200,255)
    button.TextSize=28;button.Font=Enum.Font.GothamBold;button.Parent=screenGui
    button.Active=true;button.ZIndex=100
    Instance.new("UICorner",button).CornerRadius=UDim.new(0,12)
    local stroke=Instance.new("UIStroke",button);stroke.Color=Color3.fromRGB(100,100,200);stroke.Thickness=2
    local dragging,dragStart,startPos=false,nil,nil
    button.InputBegan:Connect(function(input)
        if input.UserInputType==Enum.UserInputType.Touch or input.UserInputType==Enum.UserInputType.MouseButton1 then
            dragging=true;dragStart=input.Position;startPos=button.Position
        end
    end)
    button.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType==Enum.UserInputType.Touch or input.UserInputType==Enum.UserInputType.MouseMovement) then
            local delta=input.Position-dragStart
            button.Position=UDim2.new(startPos.X.Scale,startPos.X.Offset+delta.X,startPos.Y.Scale,startPos.Y.Offset+delta.Y)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if (input.UserInputType==Enum.UserInputType.Touch or input.UserInputType==Enum.UserInputType.MouseButton1) and dragging then
            local delta=input.Position-dragStart;dragging=false
            if delta.Magnitude<10 then pcall(function() Library:ToggleMenu() end) end
        end
    end)
    S.mobileToggleButton=screenGui
end

local function DestroyMobileButton()
    if S.mobileToggleButton then S.mobileToggleButton:Destroy();S.mobileToggleButton=nil end
end

------------------------------------------------------------
-- CHARACTER RESPAWN
------------------------------------------------------------
LocalPlayer.CharacterAdded:Connect(function()
    task.wait(1);EnsureGUILoaded();SetupNoSpread();SetupSpeed()
    S.jitterDir=1;S.spinAngle=0
    if S.shootingRemote and not S.shootingRemote.Parent then
        S.shootingRemoteFound=false;S.shootingRemote=nil;lastKnownAmmo={};remoteSet={}
        task.wait(1);SetupRemoteFinder()
    end
end)
task.spawn(function()
    task.wait(2);EnsureGUILoaded();SetupNoSpread()
    if LocalPlayer.Character then SetupSpeed() end
end)

------------------------------------------------------------
-- DRAWING SYSTEM
------------------------------------------------------------
local ESPObjects={}
local ObjectESPCache={}

local FOVCircle=Drawing.new("Circle")
FOVCircle.Thickness=1;FOVCircle.NumSides=64;FOVCircle.Filled=false;FOVCircle.Visible=false;FOVCircle.Transparency=0.8

local PredictionIndicator=Drawing.new("Text")
PredictionIndicator.Size=24;PredictionIndicator.Center=true;PredictionIndicator.Outline=true;PredictionIndicator.Font=2;PredictionIndicator.Visible=false

local function CreateDrawing(t,p) local d=Drawing.new(t);for k,v in pairs(p or {}) do d[k]=v end;return d end

local function CreatePlayerESP(player)
    if ESPObjects[player] then return end
    local d={BoxLines={},BoxOutlines={},CornerLines={},CornerOutlines={},Box3DLines={},Box3DOutlines={},
        StatusTexts={},SkeletonLines={},Hidden=true}
    for i=1,4 do d.BoxOutlines[i]=CreateDrawing("Line",{Thickness=3,Color=Color3.new(0,0,0),Visible=false}) end
    for i=1,8 do d.CornerOutlines[i]=CreateDrawing("Line",{Thickness=3,Color=Color3.new(0,0,0),Visible=false}) end
    for i=1,12 do d.Box3DOutlines[i]=CreateDrawing("Line",{Thickness=3,Color=Color3.new(0,0,0),Visible=false}) end
    d.HealthBarBG=CreateDrawing("Line",{Thickness=3,Color=Color3.fromRGB(20,20,20),Visible=false})
    d.HealthBarOutline=CreateDrawing("Square",{Filled=false,Thickness=1,Color=Color3.new(0,0,0),Visible=false})
    d.TracerOut=CreateDrawing("Line",{Thickness=3,Color=Color3.new(0,0,0),Visible=false})
    for i=1,4 do d.BoxLines[i]=CreateDrawing("Line",{Thickness=1,Visible=false}) end
    for i=1,8 do d.CornerLines[i]=CreateDrawing("Line",{Thickness=1,Visible=false}) end
    for i=1,12 do d.Box3DLines[i]=CreateDrawing("Line",{Thickness=1,Visible=false}) end
    d.HealthBar=CreateDrawing("Line",{Thickness=1,Visible=false})
    d.HealthDmg=CreateDrawing("Line",{Thickness=1,Color=Color3.fromRGB(255,120,0),Visible=false})
    d.Tracer=CreateDrawing("Line",{Thickness=1,Visible=false})
    d.NameText=CreateDrawing("Text",{Size=13,Center=true,Outline=true,Font=2,Visible=false})
    d.DistanceText=CreateDrawing("Text",{Size=13,Center=true,Outline=true,Font=2,Visible=false})
    d.WeaponText=CreateDrawing("Text",{Size=13,Center=true,Outline=true,Font=2,Visible=false})
    d.ClassText=CreateDrawing("Text",{Size=13,Center=true,Outline=true,Font=2,Visible=false})
    d.HealthText=CreateDrawing("Text",{Size=11,Center=false,Outline=true,Font=2,Visible=false})
    d.HealthPercentText=CreateDrawing("Text",{Size=11,Center=false,Outline=true,Font=2,Visible=false})
    d.SightLine=CreateDrawing("Line",{Thickness=1,Color=Color3.new(1,0,0),Visible=false})
    for i=1,#SkeletonConnections do d.SkeletonLines[i]=CreateDrawing("Line",{Thickness=1,Visible=false}) end
    for attrName,info in pairs(StatusLetters) do d.StatusTexts[attrName]=CreateDrawing("Text",{Size=11,Center=false,Outline=true,Font=2,Visible=false,Color=info.Color}) end
    ESPObjects[player]=d
end

local function DestroyPlayerESP(player)
    local d=ESPObjects[player];if not d then return end
    local function R(obj) pcall(function() obj:Remove() end) end
    for i=1,4 do R(d.BoxLines[i]);R(d.BoxOutlines[i]) end
    for i=1,8 do R(d.CornerLines[i]);R(d.CornerOutlines[i]) end
    for i=1,12 do R(d.Box3DLines[i]);R(d.Box3DOutlines[i]) end
    for i=1,#SkeletonConnections do R(d.SkeletonLines[i]) end
    R(d.HealthBarBG);R(d.HealthBar);R(d.HealthDmg);R(d.HealthBarOutline)
    R(d.NameText);R(d.DistanceText);R(d.WeaponText);R(d.ClassText);R(d.HealthText);R(d.HealthPercentText)
    R(d.SightLine);R(d.Tracer);R(d.TracerOut)
    for _,txt in pairs(d.StatusTexts) do R(txt) end
    ESPObjects[player]=nil
end

local function HidePlayerESP(player)
    local d=ESPObjects[player];if not d or d.Hidden then return end
    d.Hidden=true
    for i=1,4 do d.BoxLines[i].Visible=false;d.BoxOutlines[i].Visible=false end
    for i=1,8 do d.CornerLines[i].Visible=false;d.CornerOutlines[i].Visible=false end
    for i=1,12 do d.Box3DLines[i].Visible=false;d.Box3DOutlines[i].Visible=false end
    for i=1,#SkeletonConnections do d.SkeletonLines[i].Visible=false end
    d.HealthBarBG.Visible=false;d.HealthBar.Visible=false;d.HealthDmg.Visible=false;d.HealthBarOutline.Visible=false
    d.NameText.Visible=false;d.DistanceText.Visible=false;d.WeaponText.Visible=false;d.ClassText.Visible=false
    d.HealthText.Visible=false;d.HealthPercentText.Visible=false;d.SightLine.Visible=false
    d.Tracer.Visible=false;d.TracerOut.Visible=false
    for _,txt in pairs(d.StatusTexts) do txt.Visible=false end
end

local function CreateObjectESP(inst)
    if ObjectESPCache[inst] then return end
    local d={BoxLines={},BoxOutlines={}}
    for i=1,4 do d.BoxOutlines[i]=CreateDrawing("Line",{Thickness=3,Color=Color3.new(0,0,0),Visible=false}) end
    d.HealthBarBG=CreateDrawing("Line",{Thickness=3,Color=Color3.new(0,0,0),Visible=false})
    for i=1,4 do d.BoxLines[i]=CreateDrawing("Line",{Thickness=1,Visible=false}) end
    d.HealthBar=CreateDrawing("Line",{Thickness=1,Visible=false})
    d.HealthText=CreateDrawing("Text",{Size=13,Center=true,Outline=true,Font=2,Visible=false})
    d.HealthPercentText=CreateDrawing("Text",{Size=13,Center=true,Outline=true,Font=2,Visible=false})
    d.NameText=CreateDrawing("Text",{Size=13,Center=true,Outline=true,Font=2,Visible=false})
    ObjectESPCache[inst]=d
end

local function DestroyObjectESP(inst)
    local d=ObjectESPCache[inst];if not d then return end
    for i=1,4 do pcall(function() d.BoxLines[i]:Remove() end);pcall(function() d.BoxOutlines[i]:Remove() end) end
    pcall(function() d.HealthBarBG:Remove() end);pcall(function() d.HealthBar:Remove() end)
    pcall(function() d.HealthText:Remove() end);pcall(function() d.HealthPercentText:Remove() end)
    pcall(function() d.NameText:Remove() end)
    ObjectESPCache[inst]=nil
end

local function HideObjectESP(inst)
    local d=ObjectESPCache[inst];if not d then return end
    for i=1,4 do d.BoxLines[i].Visible=false;d.BoxOutlines[i].Visible=false end
    d.HealthBarBG.Visible=false;d.HealthBar.Visible=false;d.HealthText.Visible=false
    d.HealthPercentText.Visible=false;d.NameText.Visible=false
end

------------------------------------------------------------
-- PREDICTION DRAWING POOL
------------------------------------------------------------
local predictionDrawingPool={}

local function GetPredictionDrawingSet()
    for _,set in ipairs(predictionDrawingPool) do if not set.InUse then set.InUse=true;return set end end
    local set={InUse=true,Box3DLines={},Box3DOutlines={},PathLines={},PathOutlines={},CircleLines={},CircleOutlineLines={}}
    for i=1,12 do set.Box3DOutlines[i]=CreateDrawing("Line",{Thickness=2,Color=Color3.new(0,0,0),Visible=false}) end
    for i=1,PATH_MAX_SEGMENTS do set.PathOutlines[i]=CreateDrawing("Line",{Thickness=2,Color=Color3.new(0,0,0),Visible=false}) end
    for i=1,32 do set.CircleOutlineLines[i]=CreateDrawing("Line",{Thickness=2,Color=Color3.new(0,0,0),Visible=false}) end
    for i=1,12 do set.Box3DLines[i]=CreateDrawing("Line",{Thickness=1,Visible=false}) end
    for i=1,PATH_MAX_SEGMENTS do set.PathLines[i]=CreateDrawing("Line",{Thickness=1,Visible=false}) end
    for i=1,32 do set.CircleLines[i]=CreateDrawing("Line",{Thickness=1,Visible=false}) end
    table.insert(predictionDrawingPool,set);return set
end

local function HidePredictionSet(set)
    for _,l in pairs(set.Box3DLines) do l.Visible=false end
    for _,l in pairs(set.Box3DOutlines) do l.Visible=false end
    for _,l in pairs(set.PathLines) do l.Visible=false end
    for _,l in pairs(set.PathOutlines) do l.Visible=false end
    for _,l in pairs(set.CircleLines) do l.Visible=false end
    for _,l in pairs(set.CircleOutlineLines) do l.Visible=false end
end

local function ReleasePredictionSet(set) HidePredictionSet(set);set.InUse=false end

local function Draw3DCircleAtFeet(ds,position,color,outlineColor,thickness)
    local segs=#ds.CircleLines;local radius=2.5;local circleY=position.Y-2.5
    local points={}
    for i=0,segs do
        local angle=(i/segs)*math.pi*2
        local wp=Vector3.new(position.X+math.cos(angle)*radius,circleY,position.Z+math.sin(angle)*radius)
        local sp,onScreen=WorldToViewportPoint(wp)
        table.insert(points,{Pos=sp,Visible=onScreen})
    end
    for i=1,segs do
        local p1,p2=points[i],points[i+1]
        if p1 and p2 and p1.Visible and p2.Visible then
            ds.CircleOutlineLines[i].From=p1.Pos;ds.CircleOutlineLines[i].To=p2.Pos
            ds.CircleOutlineLines[i].Color=outlineColor or Color3.new(0,0,0);ds.CircleOutlineLines[i].Thickness=(thickness or 1)+2;ds.CircleOutlineLines[i].Visible=true
            ds.CircleLines[i].From=p1.Pos;ds.CircleLines[i].To=p2.Pos
            ds.CircleLines[i].Color=color;ds.CircleLines[i].Thickness=thickness or 1;ds.CircleLines[i].Visible=true
        else ds.CircleOutlineLines[i].Visible=false;ds.CircleLines[i].Visible=false end
    end
end

local function Draw3DPredictionBox(ds,position,color,outlineColor,thickness)
    local sz=Vector3.new(4,6,4)/2;local cf=CFrame.new(position)
    local cn={cf*CFrame.new(sz.X,sz.Y,sz.Z),cf*CFrame.new(-sz.X,sz.Y,sz.Z),cf*CFrame.new(-sz.X,sz.Y,-sz.Z),cf*CFrame.new(sz.X,sz.Y,-sz.Z),
        cf*CFrame.new(sz.X,-sz.Y,sz.Z),cf*CFrame.new(-sz.X,-sz.Y,sz.Z),cf*CFrame.new(-sz.X,-sz.Y,-sz.Z),cf*CFrame.new(sz.X,-sz.Y,-sz.Z)}
    local sc2={};for _,v in pairs(cn) do table.insert(sc2,(WorldToViewportPoint(v.Position))) end
    local e={{1,2},{2,3},{3,4},{4,1},{5,6},{6,7},{7,8},{8,5},{1,5},{2,6},{3,7},{4,8}}
    for i,edge in pairs(e) do
        ds.Box3DOutlines[i].From=sc2[edge[1]];ds.Box3DOutlines[i].To=sc2[edge[2]]
        ds.Box3DOutlines[i].Color=outlineColor or Color3.new(0,0,0);ds.Box3DOutlines[i].Thickness=(thickness or 1)+2;ds.Box3DOutlines[i].Visible=true
        ds.Box3DLines[i].From=sc2[edge[1]];ds.Box3DLines[i].To=sc2[edge[2]]
        ds.Box3DLines[i].Color=color;ds.Box3DLines[i].Thickness=thickness or 1;ds.Box3DLines[i].Visible=true
    end
end

------------------------------------------------------------
-- CHAMS
------------------------------------------------------------
local ChamsCache={}
local WorldChamsCache={}
local ProjectileChamsCache={}

local function GetOrCreateHighlight(parent,cache,name)
    if cache[parent] then
        if cache[parent].Parent~=parent then pcall(function() cache[parent]:Destroy() end);cache[parent]=nil
        else return cache[parent] end
    end
    local ok,h=pcall(function()
        local hl=Instance.new("Highlight");hl.Name=name or "AegisChams";hl.Adornee=parent;hl.Parent=parent;return hl
    end)
    if ok and h then cache[parent]=h;return h end;return nil
end

local function RemoveHighlight(parent,cache)
    if cache[parent] then pcall(function() cache[parent]:Destroy() end);cache[parent]=nil end
    S.lastChamsProps[parent]=nil
end

local function SetChamsProps(hl,parent,fc,oc,ft,ot,dm)
    local last=S.lastChamsProps[parent]
    if last and last.fc==fc and last.oc==oc and last.ft==ft and last.ot==ot and last.dm==dm then return end
    hl.FillColor=fc;hl.OutlineColor=oc;hl.FillTransparency=ft;hl.OutlineTransparency=ot;hl.DepthMode=dm;hl.Enabled=true
    S.lastChamsProps[parent]={fc=fc,oc=oc,ft=ft,ot=ot,dm=dm}
end

------------------------------------------------------------
-- ESP RENDER
------------------------------------------------------------
local function Get2DBox(char)
    local hrp=GetHRP(char);if not hrp then return nil end
    local sp,os2,d=WorldToViewportPoint(hrp.Position);if not os2 or d<1 then return nil end
    local sc2=(2*Camera.ViewportSize.Y)/((2*d*math.tan(math.rad(Camera.FieldOfView)/2))*1.5)
    local w,h=math.floor(3*sc2),math.floor(4*sc2)
    return {X=sp.X-w/2,Y=sp.Y-h/2,W=w,H=h,CX=sp.X,CY=sp.Y,TopY=sp.Y-h/2,BotY=sp.Y+h/2}
end

local function Draw2DBox(d,b,c)
    local tl=Vector2.new(b.X,b.Y);local tr=Vector2.new(b.X+b.W,b.Y)
    local bl=Vector2.new(b.X,b.Y+b.H);local br=Vector2.new(b.X+b.W,b.Y+b.H)
    local edges={{tl,tr},{tr,br},{br,bl},{bl,tl}}
    for i=1,4 do
        d.BoxOutlines[i].From=edges[i][1];d.BoxOutlines[i].To=edges[i][2];d.BoxOutlines[i].Color=Color3.new(0,0,0);d.BoxOutlines[i].Visible=true
        d.BoxLines[i].From=edges[i][1];d.BoxLines[i].To=edges[i][2];d.BoxLines[i].Color=c;d.BoxLines[i].Visible=true
    end
end

local function DrawCorners(d,b,c)
    local cl=math.max(b.H*0.25,6)
    local tl=Vector2.new(b.X,b.Y);local tr=Vector2.new(b.X+b.W,b.Y)
    local bl=Vector2.new(b.X,b.Y+b.H);local br=Vector2.new(b.X+b.W,b.Y+b.H)
    local cn={{tl,tl+Vector2.new(cl,0)},{tl,tl+Vector2.new(0,cl)},{tr,tr+Vector2.new(-cl,0)},{tr,tr+Vector2.new(0,cl)},
        {bl,bl+Vector2.new(cl,0)},{bl,bl+Vector2.new(0,-cl)},{br,br+Vector2.new(-cl,0)},{br,br+Vector2.new(0,-cl)}}
    for i=1,8 do
        d.CornerOutlines[i].From=cn[i][1];d.CornerOutlines[i].To=cn[i][2];d.CornerOutlines[i].Color=Color3.new(0,0,0);d.CornerOutlines[i].Visible=true
        d.CornerLines[i].From=cn[i][1];d.CornerLines[i].To=cn[i][2];d.CornerLines[i].Color=c;d.CornerLines[i].Visible=true
    end
end

local function Draw3DBox(d,char,c)
    local hrp=GetHRP(char);if not hrp then return end
    local cf=hrp.CFrame;local sz=Vector3.new(2,3,2)
    local cn={cf*Vector3.new(sz.X,sz.Y,sz.Z),cf*Vector3.new(-sz.X,sz.Y,sz.Z),cf*Vector3.new(-sz.X,sz.Y,-sz.Z),cf*Vector3.new(sz.X,sz.Y,-sz.Z),
        cf*Vector3.new(sz.X,-sz.Y,sz.Z),cf*Vector3.new(-sz.X,-sz.Y,sz.Z),cf*Vector3.new(-sz.X,-sz.Y,-sz.Z),cf*Vector3.new(sz.X,-sz.Y,-sz.Z)}
    local sc2={};for _,v in pairs(cn) do table.insert(sc2,(WorldToViewportPoint(v))) end
    local e={{1,2},{2,3},{3,4},{4,1},{5,6},{6,7},{7,8},{8,5},{1,5},{2,6},{3,7},{4,8}}
    for i,edge in pairs(e) do
        d.Box3DOutlines[i].From=sc2[edge[1]];d.Box3DOutlines[i].To=sc2[edge[2]];d.Box3DOutlines[i].Color=Color3.new(0,0,0);d.Box3DOutlines[i].Visible=true
        d.Box3DLines[i].From=sc2[edge[1]];d.Box3DLines[i].To=sc2[edge[2]];d.Box3DLines[i].Color=c;d.Box3DLines[i].Visible=true
    end
end

local function UpdatePlayerESP(pd)
    local player=pd.Player
    local d=ESPObjects[player];if not d then CreatePlayerESP(player);d=ESPObjects[player];if not d then return end end
    local char=pd.Character;local hum=GetHumanoid(char)
    if not hum or hum.Health<=0 then HidePlayerESP(player);return end
    if pd.IsEnemy and not Toggles.ESPEnemy.Value then HidePlayerESP(player);return end
    if not pd.IsEnemy and not pd.IsFriend and not Toggles.ESPTeam.Value then HidePlayerESP(player);return end
    if pd.IsFriend and not Toggles.ESPFriends.Value then HidePlayerESP(player);return end
    if Toggles.ESPIgnoreInvis.Value then local h=char:FindFirstChild("Head");if h and h.Transparency>0.9 then HidePlayerESP(player);return end end
    if pd.Distance>500 or not pd.OnScreen then HidePlayerESP(player);return end
    local box=Get2DBox(char);if not box then HidePlayerESP(player);return end
    local color=Options.ESPBoxColor.Value
    local hp,mhp=hum.Health,hum.MaxHealth;local hf=math.clamp(hp/mhp,0,1)
    HidePlayerESP(player);d.Hidden=false
    local bt=Options.ESPBoxType.Value
    if bt=="2D" then Draw2DBox(d,box,color) elseif bt=="Corners" then DrawCorners(d,box,color) elseif bt=="3D" then Draw3DBox(d,char,color) end
    local topY=box.TopY-2;local tX=box.CX
    if Toggles.ESPClass and Toggles.ESPClass.Value then topY=topY-15;d.ClassText.Text=pd.Class;d.ClassText.Position=Vector2.new(tX,topY);d.ClassText.Color=Color3.fromRGB(200,200,255);d.ClassText.Visible=true end
    if Toggles.ESPWeapon and Toggles.ESPWeapon.Value then topY=topY-15;d.WeaponText.Text=GetPlayerWeapon(char);d.WeaponText.Position=Vector2.new(tX,topY);d.WeaponText.Color=Color3.fromRGB(255,200,100);d.WeaponText.Visible=true end
    local bY=box.BotY+2
    if Toggles.ESPDistance and Toggles.ESPDistance.Value then d.DistanceText.Text=string.format("[%dm]",math.floor(pd.Distance));d.DistanceText.Position=Vector2.new(tX,bY);d.DistanceText.Color=Color3.new(1,1,1);d.DistanceText.Visible=true;bY=bY+15 end
    if Toggles.ESPStatus and Toggles.ESPStatus.Value then
        local mods=GetPlayerModifiers(player)
        local rightX=box.X+box.W+4;local rightY=box.Y
        for attrName,info in pairs(StatusLetters) do local txt=d.StatusTexts[attrName]
            if mods[attrName] then txt.Text=info.Letter;txt.Position=Vector2.new(rightX,rightY);txt.Color=info.Color;txt.Visible=true;rightY=rightY+12
            else txt.Visible=false end
        end
    else for _,txt in pairs(d.StatusTexts) do txt.Visible=false end end
    if Toggles.ESPHealthBar and Toggles.ESPHealthBar.Value then
        local classMax=GetClassMaxHP(player);local hpFrac=math.clamp(hp/classMax,0,1.5)
        local barW=3;local barX=box.X-barW-3;local barTop=box.Y;local barBot=box.Y+box.H;local barH=barBot-barTop
        local hpHeight=barH*math.min(hpFrac,1);local fillY=barBot-hpHeight
        d.HealthBarOutline.Size=Vector2.new(barW+2,barH+2);d.HealthBarOutline.Position=Vector2.new(barX-1,barTop-1);d.HealthBarOutline.Visible=true
        d.HealthBarBG.From=Vector2.new(barX+1,barTop);d.HealthBarBG.To=Vector2.new(barX+1,barBot);d.HealthBarBG.Thickness=barW;d.HealthBarBG.Visible=true
        d.HealthBar.From=Vector2.new(barX+1,fillY);d.HealthBar.To=Vector2.new(barX+1,barBot);d.HealthBar.Thickness=barW-2
        if hpFrac>1 then d.HealthBar.Color=Color3.fromRGB(0,200,255) else d.HealthBar.Color=Color3.fromRGB(255*(1-hpFrac),255*hpFrac,0) end
        d.HealthBar.Visible=true
        d.HealthDmg.Visible=false
        if Toggles.ESPHealthValue and Toggles.ESPHealthValue.Value then
            local txt=tostring(math.floor(hp));if hpFrac>1 then txt=txt.." (+"..math.floor(hp-classMax)..")" end
            d.HealthText.Text=txt;d.HealthText.Position=Vector2.new(barX-2,fillY-6);d.HealthText.Color=d.HealthBar.Color;d.HealthText.Visible=true
        else d.HealthText.Visible=false end
        if Toggles.ESPHealthPercent and Toggles.ESPHealthPercent.Value then
            d.HealthPercentText.Text=string.format("%d%%",math.floor(hpFrac*100));d.HealthPercentText.Position=Vector2.new(barX-2,barBot-12);d.HealthPercentText.Color=Color3.new(1,1,1);d.HealthPercentText.Visible=true
        else d.HealthPercentText.Visible=false end
    else
        d.HealthBarBG.Visible=false;d.HealthBar.Visible=false;d.HealthDmg.Visible=false;d.HealthBarOutline.Visible=false
        if Toggles.ESPHealthValue and Toggles.ESPHealthValue.Value then
            d.HealthText.Text=string.format("HP: %d/%d",math.floor(hp),math.floor(mhp));d.HealthText.Position=Vector2.new(tX,bY);d.HealthText.Color=Color3.new(1,1,1);d.HealthText.Visible=true;d.HealthText.Center=true;bY=bY+15
        else d.HealthText.Visible=false end
        if Toggles.ESPHealthPercent and Toggles.ESPHealthPercent.Value then
            d.HealthPercentText.Text=string.format("%d%%",math.floor(hf*100));d.HealthPercentText.Position=Vector2.new(tX,bY);d.HealthPercentText.Color=Color3.new(1,1,1);d.HealthPercentText.Visible=true;d.HealthPercentText.Center=true
        else d.HealthPercentText.Visible=false end
    end
    if Toggles.ESPSkeleton and Toggles.ESPSkeleton.Value then
        for i,conn in pairs(SkeletonConnections) do local pA=char:FindFirstChild(conn[1]);local pB=char:FindFirstChild(conn[2])
            if pA and pB then local sA,oA=WorldToViewportPoint(pA.Position);local sB,oB=WorldToViewportPoint(pB.Position)
                if oA and oB then d.SkeletonLines[i].From=sA;d.SkeletonLines[i].To=sB;d.SkeletonLines[i].Color=Color3.new(1,1,1);d.SkeletonLines[i].Visible=true
                else d.SkeletonLines[i].Visible=false end
            else d.SkeletonLines[i].Visible=false end end
    end
    if Toggles.SightlinesToggle and Toggles.SightlinesToggle.Value and pd.Class=="Marksman" then
        local head=char:FindFirstChild("Head")
        if head then local sS,oS=WorldToViewportPoint(head.Position);local sE,oE=WorldToViewportPoint(head.Position+head.CFrame.LookVector*500)
            if oS or oE then d.SightLine.From=sS;d.SightLine.To=sE;d.SightLine.Color=Color3.new(1,0,0);d.SightLine.Visible=true
            else d.SightLine.Visible=false end
        else d.SightLine.Visible=false end
    end
    if Toggles.ESPTracer and Toggles.ESPTracer.Value then
        local tracerColor=Options.ESPTracerColor and Options.ESPTracerColor.Value or color
        local originMode=Options.ESPTracerOrigin and Options.ESPTracerOrigin.Value or "Bottom"
        local tracerOrigin
        if originMode=="Top" then tracerOrigin=Vector2.new(Camera.ViewportSize.X/2,0)
        elseif originMode=="Center" then tracerOrigin=FrameCache.screenCenter
        else tracerOrigin=Vector2.new(Camera.ViewportSize.X/2,Camera.ViewportSize.Y) end
        d.TracerOut.From=tracerOrigin;d.TracerOut.To=Vector2.new(box.CX,box.BotY);d.TracerOut.Visible=true
        d.Tracer.From=tracerOrigin;d.Tracer.To=Vector2.new(box.CX,box.BotY);d.Tracer.Color=tracerColor;d.Tracer.Visible=true
    end
end

local function GetObjectBox(inst)
    local pp=inst:IsA("Model") and (inst.PrimaryPart or inst:FindFirstChildWhichIsA("BasePart")) or (inst:IsA("BasePart") and inst)
    if not pp then return nil end
    local ok,pos,os2=pcall(function() return Camera:WorldToViewportPoint(pp.Position) end)
    if not ok or not pos then return nil end
    local depth=pos.Z;if not os2 or not depth or depth<1 then return nil end
    local sp=Vector2.new(pos.X,pos.Y)
    local sc2=(2*Camera.ViewportSize.Y)/((2*depth*math.tan(math.rad(Camera.FieldOfView)/2))*1.5)
    local bW=math.clamp(pp.Size.Magnitude*sc2*0.5,10,200);local bH=math.clamp(pp.Size.Magnitude*sc2*0.7,10,200)
    return {TopLeft=sp-Vector2.new(bW/2,bH/2),TopRight=sp+Vector2.new(bW/2,-bH/2),BottomLeft=sp+Vector2.new(-bW/2,bH/2),BottomRight=sp+Vector2.new(bW/2,bH/2),Center=sp,Width=bW,Height=bH}
end

local function UpdateObjectESP(inst,tn)
    local d=ObjectESPCache[inst];if not d then CreateObjectESP(inst);d=ObjectESPCache[inst];if not d then return end end
    local b=GetObjectBox(inst);if not b then HideObjectESP(inst);return end
    local c=Options.ObjESPBoxColor.Value
    local l={{b.TopLeft,b.TopRight},{b.TopRight,b.BottomRight},{b.BottomRight,b.BottomLeft},{b.BottomLeft,b.TopLeft}}
    for i=1,4 do
        d.BoxOutlines[i].From=l[i][1];d.BoxOutlines[i].To=l[i][2];d.BoxOutlines[i].Color=Color3.new(0,0,0);d.BoxOutlines[i].Visible=true
        d.BoxLines[i].From=l[i][1];d.BoxLines[i].To=l[i][2];d.BoxLines[i].Color=c;d.BoxLines[i].Visible=true
    end
    d.NameText.Text=tn..": "..inst.Name;d.NameText.Position=b.Center-Vector2.new(0,b.Height/2+15);d.NameText.Color=Color3.new(1,1,1);d.NameText.Visible=true
    local hum=inst:FindFirstChildOfClass("Humanoid")
    if hum then
        local hp,mh=hum.Health,hum.MaxHealth;local hf2=math.clamp(hp/mh,0,1);local hc=Color3.fromRGB(255*(1-hf2),255*hf2,0);local yO=b.Height/2+2
        if Toggles.ObjESPHealthValue and Toggles.ObjESPHealthValue.Value then d.HealthText.Text=string.format("HP: %d/%d",math.floor(hp),math.floor(mh));d.HealthText.Position=b.Center+Vector2.new(0,yO);d.HealthText.Color=Color3.new(1,1,1);d.HealthText.Visible=true;yO=yO+15 end
        if Toggles.ObjESPHealthPercent and Toggles.ObjESPHealthPercent.Value then d.HealthPercentText.Text=string.format("%d%%",math.floor(hf2*100));d.HealthPercentText.Position=b.Center+Vector2.new(0,yO);d.HealthPercentText.Color=Color3.new(1,1,1);d.HealthPercentText.Visible=true end
        if Toggles.ObjESPHealthBar and Toggles.ObjESPHealthBar.Value then
            local bX=b.TopLeft.X-5;local bT=b.TopLeft.Y;local bB=b.BottomLeft.Y
            d.HealthBarBG.From=Vector2.new(bX,bT);d.HealthBarBG.To=Vector2.new(bX,bB);d.HealthBarBG.Thickness=3;d.HealthBarBG.Visible=true
            d.HealthBar.From=Vector2.new(bX,bB-(bB-bT)*hf2);d.HealthBar.To=Vector2.new(bX,bB);d.HealthBar.Thickness=1;d.HealthBar.Color=hc;d.HealthBar.Visible=true
        end
    end
end

------------------------------------------------------------
-- CHAMS UPDATE
------------------------------------------------------------
local function UpdatePlayerChams(pd)
    local c=pd.Character;if pd.Player==LocalPlayer then if c then RemoveHighlight(c,ChamsCache) end;return end
    local h=GetHumanoid(c);if not h or h.Health<=0 then RemoveHighlight(c,ChamsCache);return end
    if not Toggles.ChamsEnabled.Value then RemoveHighlight(c,ChamsCache);return end
    if pd.IsEnemy and not Toggles.ChamsShowEnemy.Value then RemoveHighlight(c,ChamsCache);return end
    if not pd.IsEnemy and not pd.IsFriend and not Toggles.ChamsShowTeam.Value then RemoveHighlight(c,ChamsCache);return end
    if pd.IsFriend and not Toggles.ChamsShowFriend.Value then RemoveHighlight(c,ChamsCache);return end
    local fc,oc,ft,ot
    if pd.IsFriend then fc=Options.ChamsFriendColor.Value;oc=Options.ChamsFriendOutline.Value;ft=Options.ChamsFriendTrans.Value;ot=Options.ChamsFriendOutlineTrans.Value
    elseif pd.IsEnemy then fc=Options.ChamsEnemyColor.Value;oc=Options.ChamsEnemyOutline.Value;ft=Options.ChamsEnemyTrans.Value;ot=Options.ChamsEnemyOutlineTrans.Value
    else fc=Options.ChamsTeamColor.Value;oc=Options.ChamsTeamOutline.Value;ft=Options.ChamsTeamTrans.Value;ot=Options.ChamsTeamOutlineTrans.Value end
    if Toggles.VisibleChamsEnabled.Value and IsCharacterVisible(c) then fc=Options.VisibleChamsColor.Value;oc=Options.VisibleChamsOutline.Value;ft=Options.VisibleChamsTrans.Value;ot=Options.VisibleOutlineTrans.Value end
    if Toggles.ChamsVisibleOnly.Value then if not IsCharacterVisible(c) then RemoveHighlight(c,ChamsCache);return end
        if pd.IsFriend then fc=Options.VisibleFriendColor.Value elseif pd.IsEnemy then fc=Options.VisibleEnemyColor.Value else fc=Options.VisibleTeamColor.Value end end
    local dm=Toggles.ChamsVisibleOnly.Value and Enum.HighlightDepthMode.Occluded or Enum.HighlightDepthMode.AlwaysOnTop
    local hl=GetOrCreateHighlight(c,ChamsCache,"AegisC");if not hl then return end
    SetChamsProps(hl,c,fc,oc,ft,ot,dm)
end

local function UpdateWorldChams()
    if not Toggles.ChamsWorldEnabled.Value then for i in pairs(WorldChamsCache) do RemoveHighlight(i,WorldChamsCache) end;return end
    if tick()-S.lastWorldChamsUpdate<0.5 then return end;S.lastWorldChamsUpdate=tick()
    local function A(o,co,oo,to,oto) for _,obj in pairs(o) do if not obj.Parent then continue end
        local h2=GetOrCreateHighlight(obj,WorldChamsCache,"AWC");if h2 then SetChamsProps(h2,obj,co.Value,oo.Value,to.Value,oto.Value,Enum.HighlightDepthMode.AlwaysOnTop) end end end
    A(cachedHP,Options.HealthChamsColor,Options.HealthChamsOutline,Options.HealthChamsTrans,Options.HealthChamsOutlineTrans)
    A(cachedAmmo,Options.AmmoChamsColor,Options.AmmoChamsOutline,Options.AmmoChamsTrans,Options.AmmoChamsOutlineTrans)
    A(cachedSentries,Options.SentryChamsColor,Options.SentryChamsOutline,Options.SentryChamsTrans,Options.SentryChamsOutlineTrans)
    A(cachedDispensers,Options.DispenserChamsColor,Options.DispenserChamsOutline,Options.DispenserChamsTrans,Options.DispenserChamsOutlineTrans)
    A(cachedTeleporters,Options.TeleporterChamsColor,Options.TeleporterChamsOutline,Options.TeleporterChamsTrans,Options.TeleporterChamsOutlineTrans)
end

local function UpdateProjectileChams()
    if not Toggles.ChamsProjectilesEnabled.Value then for i in pairs(ProjectileChamsCache) do RemoveHighlight(i,ProjectileChamsCache) end;return end
    if tick()-S.lastProjChamsUpdate<0.3 then return end;S.lastProjChamsUpdate=tick()
    for _,obj in pairs(GetProjectiles()) do local h2=GetOrCreateHighlight(obj,ProjectileChamsCache,"APC")
        if h2 then SetChamsProps(h2,obj,Options.ProjectileChamsColor.Value,Options.ProjectileChamsOutline.Value,Options.ProjectileChamsTrans.Value,Options.ProjectileChamsOutlineTrans.Value,Enum.HighlightDepthMode.AlwaysOnTop) end end
end

------------------------------------------------------------
-- UI TABS
------------------------------------------------------------
do
    local SG=Tabs.Aimbot:AddLeftGroupbox('Silent Aim')
    SG:AddToggle('SilentAimToggle',{Text='Enable Silent Aim',Default=false})
    Toggles.SilentAimToggle:OnChanged(function() Config.SilentAim.Enabled=Toggles.SilentAimToggle.Value end)
    SG:AddLabel('Aim Key'):AddKeyPicker('SilentAimKey',{Default='C',Mode='Hold',Text='Aim Key'})
    SG:AddToggle('SilentAimMobile',{Text='Mobile Mode (Toggle Key)',Default=false})
    Toggles.SilentAimMobile:OnChanged(function()
        if Options.SilentAimKey then Options.SilentAimKey.Mode=Toggles.SilentAimMobile.Value and 'Always' or 'Hold' end
    end)
    SG:AddToggle('SilentIgnoreInvis',{Text='Ignore Invisible',Default=true})
    SG:AddSlider('SilentAimFOV',{Text='FOV Radius',Default=200,Min=10,Max=800,Rounding=0})
    SG:AddToggle('ShowFOVCircle',{Text='Show FOV Circle',Default=true})
    SG:AddLabel('FOV Color'):AddColorPicker('FOVColor',{Default=Color3.new(1,1,1),Title='FOV Color'})
    SG:AddDropdown('SilentAimSort',{Values={'Closest to Mouse','Closest Distance'},Default='Closest to Mouse',Text='Sort Mode'})
    SG:AddDropdown('AimAtTargets',{Values={'Players','Sentry','Stickybomb'},Default=1,Multi=true,Text='Aim At'})
    Options.AimAtTargets:SetValue({Players=true})
    SG:AddDropdown('SilentAimBodyParts',{Values={'Head','Chest','Torso','Arms','Legs','Feet','Closest to Mouse'},Default=1,Multi=true,Text='Body Parts'})
    Options.SilentAimBodyParts:SetValue({Head=true})
    SG:AddDivider()
    SG:AddToggle('SilentAimArms',{Text='Aim Arms',Default=false})
    SG:AddDropdown('SilentAimArmsMode',{Values={'Snap','Smooth'},Default='Snap',Text='Arms Mode'})
end

do
    local PG=Tabs.Aimbot:AddLeftGroupbox('Prediction Visuals')
    PG:AddToggle('ShowPrediction',{Text='Show Prediction Box',Default=false})
    PG:AddToggle('ShowPredictionCircle',{Text='Show Prediction Circle',Default=false})
    PG:AddToggle('ShowProjectilePath',{Text='Show Projectile Path',Default=false})
    PG:AddToggle('ShowPredictionIndicator',{Text='Prediction Indicator',Default=false})
    PG:AddDropdown('PredictionIndicatorSymbol',{Values=PredictionSymbols,Default='+',Text='Indicator Symbol'})
    PG:AddLabel('Indicator Color'):AddColorPicker('PredictionIndicatorColor',{Default=Color3.new(0,1,1),Title='Indicator Color'})
end

do
    local TG=Tabs.Aimbot:AddLeftGroupbox('Triggerbot')
    TG:AddToggle('TriggerbotToggle',{Text='Enable Triggerbot',Default=false})
    TG:AddLabel('Triggerbot Key'):AddKeyPicker('TriggerbotKey',{Default='None',Mode='Hold',Text='Triggerbot'})
    TG:AddSlider('TriggerbotDelay',{Text='Delay',Default=0.05,Min=0,Max=0.5,Rounding=2,Suffix='s'})
    TG:AddDropdown('TriggerbotParts',{Values={'Head','Chest','Torso','Arms','Legs','Feet'},Default=1,Multi=true,Text='Target Parts'})
    Options.TriggerbotParts:SetValue({Head=true,Chest=true})
end

do
    local RG=Tabs.Aimbot:AddRightGroupbox('Ragebot')
    RG:AddToggle('RagebotToggle',{Text='Enable Ragebot',Default=false}):AddKeyPicker('RagebotKey',{Default='T',Mode='Toggle',Text='Ragebot',SyncToggleState=true})
    Toggles.RagebotToggle:OnChanged(function() Config.Ragebot.Enabled=Toggles.RagebotToggle.Value;if Toggles.RagebotToggle.Value then Library:Notify("⚠ Ragebot is obvious!",4) end end)
    RG:AddToggle('AllowMelee',{Text='Allow Melee',Default=false,Callback=function(v) Config.Ragebot.AllowMelee=v end})
    RG:AddDropdown('HitscanMode',{Values={'All Visible','Priority Only','Force Priority'},Default='All Visible',Text='Hitscan Mode',Callback=function(v) Config.Ragebot.HitscanMode=v end})
    RG:AddDropdown('PriorityHitbox',{Values={'Head','Chest','Torso','Arms','Legs','Feet'},Default='Head',Text='Priority Hitbox',Callback=function(v) Config.Ragebot.PriorityHitbox=v end})
    RG:AddToggle('AimArmsToggle',{Text='Aim Arms',Default=false,Callback=function(v) Config.AimArms.Enable=v end})
end

do
    local SN=Tabs.Aimbot:AddRightGroupbox('Sniper')
    SN:AddLabel('ADS Keybind'):AddKeyPicker('ADSBind',{Default='G',Mode='Toggle',Text='ADS',Callback=function(v) S.AdsEnabled=v;if not v and S.ads then S.ads.Value=false end end})
    SN:AddSlider('ADSModifier',{Text='ADS Modifier',Default=1,Min=0.1,Max=3,Rounding=2,Callback=function(v) S.ADSMultiplier=v;if S.AdsEnabled and S.adsmodifier then S.adsmodifier.Value=v end end})
end

do
    local NG=Tabs.Aimbot:AddRightGroupbox('Notifications')
    NG:AddToggle('ShowHits',{Text='Show Hits',Default=false,Callback=function(v) Config.Notifications.ShowHits=v end})
    NG:AddToggle('ShowRageBotMiss',{Text='Show RageBot Miss',Default=false,Callback=function(v) Config.Notifications.ShowRagebotMisses=v end})
    NG:AddToggle('EnableFlags',{Text='Hit Flags',Default=false,Callback=function(v) Config.Flags.Enabled=v end})
    NG:AddToggle('ShowDamage',{Text='Show Damage',Default=false,Callback=function(v) Config.Flags.ShowDamage=v end})
    NG:AddToggle('ShowRemainingHp',{Text='Show Remaining HP',Default=false,Callback=function(v) Config.Flags.ShowRemainingHealth=v end})
    NG:AddToggle('ShowHitName',{Text='Show Name',Default=false,Callback=function(v) Config.Flags.ShowName=v end})
end

do
    local TrG=Tabs.Aimbot:AddRightGroupbox('Weapon Tracers')
    TrG:AddToggle('WeaponTracers',{Text='Hitscan Tracers',Default=false})
    TrG:AddLabel('Tracer Color'):AddColorPicker('TracerColor',{Default=Color3.new(1,0,0),Title='Tracer Color'})
end

-- VISUALS TAB
do
    local ETB=Tabs.Visuals:AddLeftTabbox()
    local ESPT=ETB:AddTab('Player ESP')
    ESPT:AddToggle('ESPEnabled',{Text='Enable ESP',Default=false})
    ESPT:AddToggle('ESPEnemy',{Text='Show Enemy',Default=true})
    ESPT:AddToggle('ESPTeam',{Text='Show Team',Default=false})
    ESPT:AddToggle('ESPFriends',{Text='Show Friends',Default=true})
    ESPT:AddToggle('ESPIgnoreInvis',{Text='Ignore Invisible',Default=true})
    ESPT:AddDivider()
    ESPT:AddDropdown('ESPBoxType',{Values={'None','2D','3D','Corners'},Default=2,Text='Box Type'})
    ESPT:AddLabel('Box Color'):AddColorPicker('ESPBoxColor',{Default=Color3.new(1,0,0),Title='Box Color'})
    ESPT:AddToggle('ESPDistance',{Text='Distance',Default=false})
    ESPT:AddToggle('ESPSkeleton',{Text='Skeleton',Default=false})
    ESPT:AddToggle('ESPWeapon',{Text='Weapon',Default=false})
    ESPT:AddToggle('ESPClass',{Text='Class',Default=false})
    ESPT:AddToggle('ESPHealthValue',{Text='Health Value',Default=false})
    ESPT:AddToggle('ESPHealthBar',{Text='Health Bar',Default=false})
    ESPT:AddToggle('ESPHealthPercent',{Text='Health %',Default=false})
    ESPT:AddToggle('ESPStatus',{Text='Status Effects',Default=false})
    ESPT:AddDivider()
    ESPT:AddToggle('ESPTracer',{Text='Tracers',Default=false})
    ESPT:AddLabel('Tracer Color'):AddColorPicker('ESPTracerColor',{Default=Color3.new(1,0,0),Title='Tracer'})
    ESPT:AddDropdown('ESPTracerOrigin',{Values={'Bottom','Center','Top'},Default='Bottom',Text='Tracer Origin'})

    local ESPO=ETB:AddTab('Object ESP')
    ESPO:AddToggle('ObjESPEnabled',{Text='Enable Object ESP',Default=false})
    ESPO:AddDivider()
    ESPO:AddToggle('ObjESPSentry',{Text='Sentry',Default=false})
    ESPO:AddToggle('ObjESPDispenser',{Text='Dispenser',Default=false})
    ESPO:AddToggle('ObjESPTeleporter',{Text='Teleporter',Default=false})
    ESPO:AddToggle('ObjESPAmmo',{Text='Ammo',Default=false})
    ESPO:AddToggle('ObjESPHP',{Text='Health Packs',Default=false})
    ESPO:AddDivider()
    ESPO:AddLabel('Object Color'):AddColorPicker('ObjESPBoxColor',{Default=Color3.new(1,1,0),Title='Obj Color'})
    ESPO:AddToggle('ObjESPHealthValue',{Text='Health Value',Default=false})
    ESPO:AddToggle('ObjESPHealthBar',{Text='Health Bar',Default=false})
    ESPO:AddToggle('ObjESPHealthPercent',{Text='Health %',Default=false})
end

do
    local CTB=Tabs.Visuals:AddLeftTabbox()
    local CT=CTB:AddTab('Player')
    CT:AddToggle('ChamsEnabled',{Text='Enable Chams',Default=false})
    CT:AddToggle('ChamsShowEnemy',{Text='Show Enemy',Default=true})
    CT:AddToggle('ChamsShowTeam',{Text='Show Team',Default=false})
    CT:AddToggle('ChamsShowFriend',{Text='Show Friends',Default=true})
    CT:AddDivider()
    CT:AddLabel('Enemy'):AddColorPicker('ChamsEnemyColor',{Default=Color3.new(1,0,0)})
    CT:AddLabel('Enemy Out'):AddColorPicker('ChamsEnemyOutline',{Default=Color3.new(0.5,0,0)})
    CT:AddSlider('ChamsEnemyTrans',{Text='Enemy Trans',Default=0,Min=0,Max=1,Rounding=2})
    CT:AddSlider('ChamsEnemyOutlineTrans',{Text='Enemy Out Trans',Default=0,Min=0,Max=1,Rounding=2})
    CT:AddDivider()
    CT:AddLabel('Team'):AddColorPicker('ChamsTeamColor',{Default=Color3.new(0,0,1)})
    CT:AddLabel('Team Out'):AddColorPicker('ChamsTeamOutline',{Default=Color3.new(0,0,0.5)})
    CT:AddSlider('ChamsTeamTrans',{Text='Team Trans',Default=0,Min=0,Max=1,Rounding=2})
    CT:AddSlider('ChamsTeamOutlineTrans',{Text='Team Out Trans',Default=0,Min=0,Max=1,Rounding=2})
    CT:AddDivider()
    CT:AddLabel('Friend'):AddColorPicker('ChamsFriendColor',{Default=Color3.new(0,1,0)})
    CT:AddLabel('Friend Out'):AddColorPicker('ChamsFriendOutline',{Default=Color3.new(0,0.5,0)})
    CT:AddSlider('ChamsFriendTrans',{Text='Friend Trans',Default=0,Min=0,Max=1,Rounding=2})
    CT:AddSlider('ChamsFriendOutlineTrans',{Text='Friend Out Trans',Default=0,Min=0,Max=1,Rounding=2})
end

do
    local CTB2=Tabs.Visuals:AddLeftTabbox()
    local VT=CTB2:AddTab('Visible')
    VT:AddToggle('VisibleChamsEnabled',{Text='Visible Chams',Default=false})
    local VD=VT:AddDependencyBox()
    VD:AddLabel('Fill'):AddColorPicker('VisibleChamsColor',{Default=Color3.new(1,1,0)})
    VD:AddLabel('Outline'):AddColorPicker('VisibleChamsOutline',{Default=Color3.new(0.5,0.5,0)})
    VD:AddSlider('VisibleChamsTrans',{Text='Fill Trans',Default=0,Min=0,Max=1,Rounding=2})
    VD:AddSlider('VisibleOutlineTrans',{Text='Out Trans',Default=0,Min=0,Max=1,Rounding=2})
    VD:SetupDependencies({{Toggles.VisibleChamsEnabled,true}})
    VT:AddDivider()
    VT:AddToggle('ChamsVisibleOnly',{Text='Visible Only',Default=false})
    VT:AddLabel('Vis Enemy'):AddColorPicker('VisibleEnemyColor',{Default=Color3.new(1,0,0)})
    VT:AddLabel('Vis Team'):AddColorPicker('VisibleTeamColor',{Default=Color3.new(0,0,1)})
    VT:AddLabel('Vis Friend'):AddColorPicker('VisibleFriendColor',{Default=Color3.new(0,1,0)})
end

do
    local WG=Tabs.Visuals:AddRightGroupbox('World Chams')
    WG:AddToggle('ChamsWorldEnabled',{Text='World Chams',Default=false})
    WG:AddLabel('HP'):AddColorPicker('HealthChamsColor',{Default=Color3.new(0,1,0)})
    WG:AddLabel('HP Out'):AddColorPicker('HealthChamsOutline',{Default=Color3.new(0,0.5,0)})
    WG:AddSlider('HealthChamsTrans',{Text='HP Trans',Default=0.5,Min=0,Max=1,Rounding=2})
    WG:AddSlider('HealthChamsOutlineTrans',{Text='HP Out',Default=0.5,Min=0,Max=1,Rounding=2})
    WG:AddDivider()
    WG:AddLabel('Ammo'):AddColorPicker('AmmoChamsColor',{Default=Color3.new(1,0.5,0)})
    WG:AddLabel('Ammo Out'):AddColorPicker('AmmoChamsOutline',{Default=Color3.new(0.5,0.25,0)})
    WG:AddSlider('AmmoChamsTrans',{Text='Ammo Trans',Default=0.5,Min=0,Max=1,Rounding=2})
    WG:AddSlider('AmmoChamsOutlineTrans',{Text='Ammo Out',Default=0.5,Min=0,Max=1,Rounding=2})
    WG:AddDivider()
    WG:AddLabel('Sentry'):AddColorPicker('SentryChamsColor',{Default=Color3.new(1,0,0.5)})
    WG:AddLabel('Sen Out'):AddColorPicker('SentryChamsOutline',{Default=Color3.new(0.5,0,0.25)})
    WG:AddSlider('SentryChamsTrans',{Text='Sen Trans',Default=0.5,Min=0,Max=1,Rounding=2})
    WG:AddSlider('SentryChamsOutlineTrans',{Text='Sen Out',Default=0.5,Min=0,Max=1,Rounding=2})
    WG:AddDivider()
    WG:AddLabel('Disp'):AddColorPicker('DispenserChamsColor',{Default=Color3.new(0,1,1)})
    WG:AddLabel('Disp Out'):AddColorPicker('DispenserChamsOutline',{Default=Color3.new(0,0.5,0.5)})
    WG:AddSlider('DispenserChamsTrans',{Text='Disp Trans',Default=0.5,Min=0,Max=1,Rounding=2})
    WG:AddSlider('DispenserChamsOutlineTrans',{Text='Disp Out',Default=0.5,Min=0,Max=1,Rounding=2})
    WG:AddDivider()
    WG:AddLabel('Tele'):AddColorPicker('TeleporterChamsColor',{Default=Color3.new(0.5,0,1)})
    WG:AddLabel('Tele Out'):AddColorPicker('TeleporterChamsOutline',{Default=Color3.new(0.25,0,0.5)})
    WG:AddSlider('TeleporterChamsTrans',{Text='Tele Trans',Default=0.5,Min=0,Max=1,Rounding=2})
    WG:AddSlider('TeleporterChamsOutlineTrans',{Text='Tele Out',Default=0.5,Min=0,Max=1,Rounding=2})
    WG:AddDivider()
    WG:AddToggle('ChamsProjectilesEnabled',{Text='Projectile Chams',Default=false})
    WG:AddLabel('Proj'):AddColorPicker('ProjectileChamsColor',{Default=Color3.new(1,1,0)})
    WG:AddLabel('Proj Out'):AddColorPicker('ProjectileChamsOutline',{Default=Color3.new(0.5,0.5,0)})
    WG:AddSlider('ProjectileChamsTrans',{Text='Proj Trans',Default=0.5,Min=0,Max=1,Rounding=2})
    WG:AddSlider('ProjectileChamsOutlineTrans',{Text='Proj Out',Default=0.5,Min=0,Max=1,Rounding=2})
end

do
    local PSG=Tabs.Visuals:AddRightGroupbox('Prediction Visual Style')
    PSG:AddLabel('Inline Color'):AddColorPicker('PredictionInlineColor',{Default=Color3.new(0,1,1),Title='Prediction Inline'})
    PSG:AddLabel('Outline Color'):AddColorPicker('PredictionOutlineColor',{Default=Color3.fromRGB(0,0,0),Title='Prediction Outline'})
    PSG:AddSlider('PredictionThickness',{Text='Thickness',Default=1,Min=1,Max=5,Rounding=0})
end

local OL
do
    local VR=Tabs.Visuals:AddRightGroupbox('World Visuals')
    VR:AddInput('SkyboxID',{Default='',Numeric=true,Finished=true,Text='Skybox ID',Placeholder='Asset ID'})
    VR:AddSlider('TimeSlider',{Text='Time',Default=12,Min=0,Max=24,Rounding=1,Suffix=' hrs'})
    VR:AddLabel('Ambient'):AddColorPicker('AmbientColor',{Default=Lighting.Ambient,Title='Ambient'})
    VR:AddToggle('FullbrightToggle',{Text='Fullbright',Default=false})
    VR:AddToggle('NoFogToggle',{Text='No Fog',Default=false})
    VR:AddToggle('SightlinesToggle',{Text='"Marksman" Sightlines',Default=false})
    OL={Ambient=Lighting.Ambient,Brightness=Lighting.Brightness,FogEnd=Lighting.FogEnd,FogStart=Lighting.FogStart,ClockTime=Lighting.ClockTime,OutdoorAmbient=Lighting.OutdoorAmbient}
    local function ApplySkybox(id) if id=='' then return end
        pcall(function() local sk=Lighting:FindFirstChildOfClass("Sky");if not sk then sk=Instance.new("Sky");sk.Parent=Lighting end
            local a="rbxassetid://"..id;sk.SkyboxBk,sk.SkyboxDn,sk.SkyboxFt,sk.SkyboxLf,sk.SkyboxRt,sk.SkyboxUp=a,a,a,a,a,a end) end
    Options.SkyboxID:OnChanged(function() ApplySkybox(Options.SkyboxID.Value) end)
    Options.TimeSlider:OnChanged(function() Lighting.ClockTime=Options.TimeSlider.Value end)
    Options.AmbientColor:OnChanged(function() if not Toggles.FullbrightToggle.Value then Lighting.Ambient=Options.AmbientColor.Value;Lighting.OutdoorAmbient=Options.AmbientColor.Value end end)
    Toggles.FullbrightToggle:OnChanged(function() if Toggles.FullbrightToggle.Value then Lighting.Brightness=2;Lighting.Ambient=Color3.new(1,1,1);Lighting.OutdoorAmbient=Color3.new(1,1,1) else Lighting.Brightness=OL.Brightness;Lighting.Ambient=Options.AmbientColor.Value;Lighting.OutdoorAmbient=Options.AmbientColor.Value end end)
    Toggles.NoFogToggle:OnChanged(function() if Toggles.NoFogToggle.Value then Lighting.FogEnd=1e10;Lighting.FogStart=1e10 else Lighting.FogEnd=OL.FogEnd;Lighting.FogStart=OL.FogStart end end)
    task.spawn(function() while true do task.wait(1);if Library.Unloaded then break end
        if Options.SkyboxID.Value~='' then ApplySkybox(Options.SkyboxID.Value) end;Lighting.ClockTime=Options.TimeSlider.Value
        if Toggles.FullbrightToggle.Value then Lighting.Brightness=2;Lighting.Ambient=Color3.new(1,1,1);Lighting.OutdoorAmbient=Color3.new(1,1,1) else Lighting.Ambient=Options.AmbientColor.Value;Lighting.OutdoorAmbient=Options.AmbientColor.Value end
        if Toggles.NoFogToggle.Value then Lighting.FogEnd=1e10;Lighting.FogStart=1e10 end
    end end)
end

-- MISC TAB
do
    local ML=Tabs.Misc:AddLeftGroupbox('Misc')
    ML:AddToggle('TelestabToggle',{Text='Telestab',Default=false})
    ML:AddLabel('Telestab Bind'):AddKeyPicker('TelestabKey',{Default='V',Mode='Hold',Text='Telestab'})
    ML:AddDivider()
    ML:AddToggle('HealSelfToggle',{Text='Heal Self [Medic]',Default=false})
    ML:AddLabel('Heal Self Bind'):AddKeyPicker('HealSelfKey',{Default='X',Mode='Toggle',Text='Heal Self'})
    ML:AddDivider()
    ML:AddToggle('UsernameHider',{Text='Username Hider',Default=false})
    ML:AddInput('FakeUsername',{Default='Player',Numeric=false,Finished=false,Text='Fake Name',Placeholder='Name'})
    ML:AddDivider()
    ML:AddToggle('AgentNotification',{Text='Agent Notification',Default=false})
    ML:AddDivider()
    ML:AddDropdown('DeviceSpoofer',{Values={'None','Desktop','Mobile','Xbox','Tablet'},Default='None',Text='Device Spoofer'})
    Options.DeviceSpoofer:OnChanged(function() local val=Options.DeviceSpoofer.Value;if val~="None" then ApplyDeviceSpoof(val);Library:Notify("📱 Spoofed device to: "..val,3) end end)
end

do
    local MR=Tabs.Misc:AddRightGroupbox('Automation')
    MR:AddToggle('AutoStickyDetonate',{Text='Auto Sticky Detonate',Default=false})
    MR:AddToggle('AutoStickyVisibleOnly',{Text='Visible Only (Sticky)',Default=false})
    MR:AddDivider()
    MR:AddToggle('AutoAirblast',{Text='Auto Airblast',Default=false})
    MR:AddToggle('AutoAirblastExt',{Text='Extinguish Teammates',Default=false})
    MR:AddDivider()
    MR:AddToggle('AutoUberToggle',{Text='Auto Uber [Doctor]',Default=false})
    Toggles.AutoUberToggle:OnChanged(function() Config.AutoUber.Enabled=Toggles.AutoUberToggle.Value end)
    MR:AddSlider('AutoUberHealthPercent',{Text='Health Threshold',Default=40,Min=5,Max=100,Rounding=0,Suffix='%'})
    Options.AutoUberHealthPercent:OnChanged(function() Config.AutoUber.HealthPercent=Options.AutoUberHealthPercent.Value end)
    MR:AddDropdown('AutoUberCondition',{Values={'Self','HealTarget','Both'},Default='Both',Text='Uber Condition'})
    Options.AutoUberCondition:OnChanged(function() Config.AutoUber.Condition=Options.AutoUberCondition.Value end)
end

-- EXPLOITS TAB
do
    local EL=Tabs.Exploits:AddLeftGroupbox('Exploits')
    EL:AddLabel('Anti-Aim'):AddKeyPicker('AAKeybind',{Default='J',Mode='Toggle',Text='Anti-Aim',Callback=function(v) Config.AntiAim.Enabled=v end})
    EL:AddDropdown('AAMode',{Values={'jitter','backwards','spin'},Default='jitter',Text='AA Mode',Callback=function(v) Config.AntiAim.Mode=v end})
    EL:AddSlider('JitterAngle',{Text='Jitter Angle',Default=90,Min=0,Max=180,Rounding=0,Callback=function(v) Config.AntiAim.JitterAngle=v end})
    EL:AddSlider('JitterSpeed',{Text='Jitter Speed',Default=15,Min=1,Max=60,Rounding=0,Callback=function(v) Config.AntiAim.JitterSpeed=v end})
    EL:AddSlider('SpinSpeed',{Text='Spin Speed',Default=180,Min=1,Max=1080,Rounding=0,Callback=function(v) Config.AntiAim.AntiAimSpeed=v end})
    EL:AddDivider()
    EL:AddToggle('WallbangToggle',{Text='Wallbang',Default=false,Callback=function(v) Config.Wallbang.Enable=v;if v then Library:Notify("⚠ Wallbang is obvious!",4) end end})
    EL:AddToggle('NoSpreadToggle',{Text='No Spread',Default=false,Callback=function(v) Config.NoSpread.Enable=v
        if v then EnsureGUILoaded();SetupNoSpread();Library:Notify("⚠ No Spread is obvious!",4)
            if S.kirk then S.charlieKirk=true;S.kirk.Value=S.kirk.Value*Config.NoSpread.Multiplier;S.charlieKirk=false end end end})
    EL:AddSlider('SpreadMultiplier',{Text='Spread Mult',Default=0.2,Min=0.2,Max=1,Rounding=2,Callback=function(v) Config.NoSpread.Multiplier=v end})
    EL:AddDivider()
    EL:AddToggle('SpeedToggle',{Text='Speed',Default=false}):AddKeyPicker('SpeedKey',{Default='N',Mode='Toggle',Text='Speed',SyncToggleState=true})
    Toggles.SpeedToggle:OnChanged(function() Config.Speed.Enable=Toggles.SpeedToggle.Value;SetupSpeed()
        if not Toggles.SpeedToggle.Value and S.speedConnection then S.speedConnection:Disconnect();S.speedConnection=nil end end)
    EL:AddSlider('SpeedValue',{Text='Speed',Default=300,Min=1,Max=600,Rounding=0,Callback=function(v) Config.Speed.Value=v;if Config.Speed.Enable and LocalPlayer.Character then LocalPlayer.Character:SetAttribute("Speed",v) end end})
end

do
    local AB=Tabs.Exploits:AddLeftGroupbox('Auto Backstab')
    AB:AddToggle('AutoBackstab',{Text='Auto Backstab',Default=false})
    AB:AddToggle('AutoBackstabAimArms',{Text='Aim Arms',Default=false})
    AB:AddDivider()
    AB:AddToggle('AutoWarp',{Text='Auto Warp Behind',Default=false})
    AB:AddLabel('Warp Key'):AddKeyPicker('WarpKey',{Default='B',Mode='Toggle',Text='Warp'})
end

do
    local AM=Tabs.Exploits:AddLeftGroupbox('Auto Melee')
    AM:AddToggle('AutoMelee',{Text='Auto Melee',Default=false})
    AM:AddDropdown('AutoMeleeMode',{Values={'Rage','Demoknight'},Default='Rage',Text='Melee Mode'})
end

do
    local ER=Tabs.Exploits:AddRightGroupbox('VIP / Other')
    ER:AddToggle('NoVoiceCooldown',{Text='No Voice Cooldown',Default=false,Callback=function(v) pcall(function() ReplicatedStorage.VIPSettings.NoVoiceCooldown.Value=v end) end})
    ER:AddToggle('ThirdPersonMode',{Text='Third Person',Default=false,Callback=function(v) ApplyThirdPerson(v) end})
end

task.spawn(function() while true do task.wait(2);if Library.Unloaded then break end
    pcall(function()
        if Toggles.NoVoiceCooldown.Value then ReplicatedStorage.VIPSettings.NoVoiceCooldown.Value=true end
        if Toggles.ThirdPersonMode.Value then local v=ReplicatedStorage:FindFirstChild("VIPSettings");if v then local t=v:FindFirstChild("AThirdPersonMode");if t then t.Value=true end end end
        local ds=Options.DeviceSpoofer.Value;if ds~="None" then ApplyDeviceSpoof(ds) end
    end)
end end)

-- SETTINGS TAB
do
    local SL=Tabs.Settings:AddLeftGroupbox('FOV')
    SL:AddToggle('CustomFOV',{Text='FOV Modifications',Default=false})
    SL:AddSlider('CustomFOVAmount',{Text='FOV',Default=90,Min=0,Max=120,Rounding=0,Suffix='°'})
    Toggles.CustomFOV:OnChanged(function() if Toggles.CustomFOV.Value then Camera.FieldOfView=Options.CustomFOVAmount.Value end end)
    Options.CustomFOVAmount:OnChanged(function() if Toggles.CustomFOV.Value then Camera.FieldOfView=Options.CustomFOVAmount.Value end end)
    Camera:GetPropertyChangedSignal("FieldOfView"):Connect(function() if Toggles.CustomFOV.Value then Camera.FieldOfView=Options.CustomFOVAmount.Value end end)
end

do
    local MG=Tabs.Settings:AddLeftGroupbox('Mobile')
    MG:AddToggle('MobileModeToggle',{Text='Mobile Mode',Default=isMobileDevice})
    Toggles.MobileModeToggle:OnChanged(function() isMobileMode=Toggles.MobileModeToggle.Value;if isMobileMode then CreateMobileButton() else DestroyMobileButton() end end)
    if isMobileDevice then task.defer(function() task.wait(1);if Toggles.MobileModeToggle then Toggles.MobileModeToggle:SetValue(true) end end) end
end

------------------------------------------------------------
-- USERNAME HIDER
------------------------------------------------------------
local function UpdateUsernameHider()
    if not Toggles.UsernameHider.Value then return end
    if tick()-S.lastUsernameUpdate<1 then return end;S.lastUsernameUpdate=tick()
    local fn=Options.FakeUsername.Value~='' and Options.FakeUsername.Value or 'Player'
    pcall(function() local pg=LocalPlayer:FindFirstChild("PlayerGui");if not pg then return end
        for _,g in pairs(pg:GetDescendants()) do if g:IsA("TextLabel") and (g.Text==LocalPlayer.Name or g.Text==LocalPlayer.DisplayName) then g.Text=fn end end end)
end
------------------------------------------------------------
-- AUTO UBER
------------------------------------------------------------
local function CheckAutoUber()
    if not Config.AutoUber.Enabled then return end
    if not IsPlayerAlive(LocalPlayer) then return end
    if not LocalPlayer:FindFirstChild("Status") then return end
    if LocalPlayer.Status.Class.Value ~= "Doctor" then return end

    local char = LocalPlayer.Character
    if not char then return end
    local hum = GetHumanoid(char)
    if not hum or hum.Health <= 0 then return end

    -- Check if uber is ready by looking for the Doctor tool/attribute
    local uberReady = false
    pcall(function()
        -- Check various ways uber might be indicated
        local gun = char:FindFirstChild("Gun")
        if gun then
            local boop = gun:FindFirstChild("Boop")
            if boop then
                local weaponName = boop.Value
                -- Only activate on medigun-type weapons
                if weaponName == "Medigun" or weaponName == "Kritzkrieg" or weaponName == "Blood Doctor" 
                    or weaponName == "Rejuvenator" or weaponName == "The Vaccinator" then
                    -- Check uber percentage via GUI
                    local pg = LocalPlayer:FindFirstChild("PlayerGui")
                    if pg then
                        local gui = pg:FindFirstChild("GUI")
                        if gui then
                            local client = gui:FindFirstChild("Client")
                            if client then
                                local llv = client:FindFirstChild("LegacyLocalVariables")
                                if llv then
                                    local uber = llv:FindFirstChild("uber")
                                    if uber and uber.Value >= 100 then
                                        uberReady = true
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end)

    if not uberReady then return end

    local myHealth = hum.Health
    local myMaxHealth = hum.MaxHealth
    local myHealthPercent = (myHealth / myMaxHealth) * 100
    local threshold = Config.AutoUber.HealthPercent

    -- Check self health
    if Config.AutoUber.Condition == "Self" or Config.AutoUber.Condition == "Both" then
        if myHealthPercent <= threshold then
            RightClick()
            return
        end
    end

    -- Check heal target health
    if Config.AutoUber.Condition == "HealTarget" or Config.AutoUber.Condition == "Both" then
        pcall(function()
            local pg = LocalPlayer:FindFirstChild("PlayerGui")
            if pg then
                local gui = pg:FindFirstChild("GUI")
                if gui then
                    local client = gui:FindFirstChild("Client")
                    if client then
                        local llv = client:FindFirstChild("LegacyLocalVariables")
                        if llv then
                            local healTarget = llv:FindFirstChild("healtarget")
                            if healTarget and healTarget.Value ~= "" then
                                local targetPlayer = Players:FindFirstChild(healTarget.Value)
                                if targetPlayer and targetPlayer.Character then
                                    local targetHum = GetHumanoid(targetPlayer.Character)
                                    if targetHum then
                                        local targetHealthPercent = (targetHum.Health / targetHum.MaxHealth) * 100
                                        if targetHealthPercent <= threshold then
                                            RightClick()
                                            return
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end)
    end
end

------------------------------------------------------------
-- AUTO AIRBLAST (reworked)
------------------------------------------------------------
local function RunAutoAirblast()
    if not (Toggles.AutoAirblast and Toggles.AutoAirblast.Value) then return end
    if not IsPlayerAlive(LocalPlayer) then return end
    if not LocalPlayer:FindFirstChild("Status") then return end
    if LocalPlayer.Status.Class.Value ~= "Arsonist" then return end
    local lc = GetLocalCharacter()
    if not lc then return end
    local lhrp = GetHRP(lc)
    if not lhrp then return end

    local Vec, OnScr

    -- Check enemy projectiles in Ray_Ignore
    for _, v in workspace.Ray_Ignore:GetChildren() do
        if v:GetAttribute("ProjectileType") and v:GetAttribute("Team") then
            if v:GetAttribute("Team") ~= LocalPlayer.Status.Team.Value then
                Vec, OnScr = Camera:WorldToViewportPoint(v.Position)
                if OnScr and ((v.Position - lhrp.Position).Magnitude) <= 13 then
                    RightClick()
                    return
                end
            end
        end
    end

    -- Check enemy stickybombs in Destructable
    for _, v in workspace.Destructable:GetChildren() do
        if v.Name:match("stickybomb") and v:GetAttribute("Team") then
            if v:GetAttribute("Team") ~= LocalPlayer.Status.Team.Value then
                Vec, OnScr = Camera:WorldToViewportPoint(v.Position)
                if OnScr and ((v.Position - lhrp.Position).Magnitude) <= 13 then
                    RightClick()
                    return
                end
            end
        end
    end

    -- Extinguish teammates
    if Toggles.AutoAirblastExt and Toggles.AutoAirblastExt.Value then
        for _, v in Players:GetPlayers() do
            if v.Character and v ~= LocalPlayer then
                if v.Team == LocalPlayer.Team and v.Character:FindFirstChild("Conditions") then
                    if v.Character.Conditions:GetAttribute("Engulfed") and (v.Character.Head.Position - lhrp.Position).Magnitude <= 13 then
                        RightClick()
                        return
                    end
                end
            end
        end
    end
end

------------------------------------------------------------
-- MAIN LOOP HELPERS
------------------------------------------------------------
local function RunSilentAimLogic()
    if not Config.SilentAim.Enabled then S.silentAimKeyActive=false;return end
    S.silentAimKeyActive=Options.SilentAimKey:GetState()
    if S.silentAimKeyActive and IsPlayerAlive(LocalPlayer) then
        local weapon=GetLocalWeapon()
        if not BlacklistedWeapons[weapon] then
            local target=FrameCache.silentTarget
            if target then
                if not S.shooting then
                    VirtualInputManager:SendMouseButtonEvent(0,0,0,true,game,0);S.shooting=true;S.lastShotTime=tick()
                elseif tick()-S.lastShotTime>=S.shotInterval then
                    VirtualInputManager:SendMouseButtonEvent(0,0,0,false,game,0)
                    VirtualInputManager:SendMouseButtonEvent(0,0,0,true,game,0);S.lastShotTime=tick()
                end
            elseif S.shooting and not Config.Ragebot.Enabled then
                VirtualInputManager:SendMouseButtonEvent(0,0,0,false,game,0);S.shooting=false
            end
        end
    elseif not S.silentAimKeyActive and S.shooting and not Config.Ragebot.Enabled then
        VirtualInputManager:SendMouseButtonEvent(0,0,0,false,game,0);S.shooting=false
    end
end

local function RunAutoWarp(playerData)
    if not (Toggles.AutoWarp and Toggles.AutoWarp.Value and Options.WarpKey:GetState()) then return end
    if tick()-S.lastWarpTime<1 then return end
    local myClass=GetLocalClass();local myWeapon=GetLocalWeapon()
    if myClass~="Agent" or not BackstabWeapons[myWeapon] then return end
    local lc=GetLocalCharacter();local lh=lc and GetHRP(lc);if not lh then return end
    for _,pd in ipairs(playerData) do
        if not pd.IsEnemy or pd.Distance>BACKSTAB_RANGE then continue end
        local toT=(lh.Position-pd.HRP.Position).Unit
        local dot=toT:Dot(pd.HRP.CFrame.LookVector)
        if dot>0 then
            local behindPos=pd.HRP.Position-pd.HRP.CFrame.LookVector*3
            lh.CFrame=CFrame.lookAt(behindPos,pd.HRP.Position)
            S.lastWarpTime=tick()
            Library:Notify("🔪 Warped behind "..pd.Player.Name,1.5)
            break
        end
    end
end

local function RunAntiAim(dt)
    if not Config.AntiAim.Enabled then return end
    local char=LocalPlayer.Character;if not char then return end
    local hrp=GetHRP(char);if not hrp or not hrp:IsDescendantOf(Workspace) then return end
    pcall(function() char:SetAttribute("NoAutoRotate",true) end)
    if not LocalPlayer:GetAttribute("ThirdPerson") then return end
    local pos=hrp.Position;local fwd=Vector3.new(Camera.CFrame.LookVector.X,0,Camera.CFrame.LookVector.Z).Unit;local nl
    if Config.AntiAim.Mode=="backwards" then nl=-fwd
    elseif Config.AntiAim.Mode=="jitter" then
        if tick()-S.lastJitterUpdate>=1/Config.AntiAim.JitterSpeed then S.jitterDir=-S.jitterDir;S.lastJitterUpdate=tick() end
        local y=math.rad(Config.AntiAim.JitterAngle*S.jitterDir)
        nl=Vector3.new(math.cos(y)*fwd.X-math.sin(y)*fwd.Z,0,math.sin(y)*fwd.X+math.cos(y)*fwd.Z).Unit
    elseif Config.AntiAim.Mode=="spin" then
        S.spinAngle=S.spinAngle+math.rad(Config.AntiAim.AntiAimSpeed*dt)
        nl=Vector3.new(math.sin(S.spinAngle),0,math.cos(S.spinAngle))
    end
    if nl then hrp.CFrame=CFrame.new(pos,pos+nl) end
end

local function RunAutoBackstab(playerData)
    if not (Toggles.AutoBackstab and Toggles.AutoBackstab.Value) then return end
    local myClass=GetLocalClass();local myWeapon=GetLocalWeapon()
    if myClass~="Agent" or not BackstabWeapons[myWeapon] then return end
    local lc=GetLocalCharacter();local lh=lc and GetHRP(lc);if not lh then return end
    local foundTarget=false
    for _,pd in ipairs(playerData) do
        if not pd.IsEnemy or pd.Distance>BACKSTAB_RANGE then continue end
        local toT=(pd.HRP.Position-lh.Position).Unit
        if toT:Dot(pd.HRP.CFrame.LookVector)>0.3 then
            foundTarget=true
            if S.lastBackstabTarget~=pd.Player then S.lastBackstabTarget=pd.Player;Library:Notify("🔪 Backstab target: "..pd.Player.Name,2) end
            if Toggles.AutoBackstabAimArms and Toggles.AutoBackstabAimArms.Value then
                AimArmsAtTarget(pd.HRP.Position-pd.HRP.CFrame.LookVector*2)
            end
            if not S.shooting then
                VirtualInputManager:SendMouseButtonEvent(0,0,0,true,game,0);S.shooting=true;S.lastShotTime=tick()
            elseif tick()-S.lastShotTime>=0.15 then
                VirtualInputManager:SendMouseButtonEvent(0,0,0,false,game,0)
                VirtualInputManager:SendMouseButtonEvent(0,0,0,true,game,0);S.lastShotTime=tick()
            end;break
        end
    end
    if not foundTarget and S.lastBackstabTarget then Library:Notify("🔪 Target lost",1.5);S.lastBackstabTarget=nil end
end

local function RunAutoMelee(playerData)
    if not (Toggles.AutoMelee and Toggles.AutoMelee.Value) then return end
    -- Don't stack with auto backstab
    if Toggles.AutoBackstab and Toggles.AutoBackstab.Value and GetLocalClass()=="Agent" then return end
    local myWeapon=GetLocalWeapon()
    if not MeleeWeapons[myWeapon] then return end
    local lc=GetLocalCharacter();local lh=lc and GetHRP(lc);if not lh then return end
    local meleeMode=Options.AutoMeleeMode and Options.AutoMeleeMode.Value or "Rage"
    local meleeRange=meleeMode=="Demoknight" and MELEE_RANGE_DEMOKNIGHT or MELEE_RANGE_RAGE
    local foundTarget=false
    for _,pd in ipairs(playerData) do
        if not pd.IsEnemy or pd.Distance>meleeRange then continue end
        foundTarget=true
        if S.lastMeleeTarget~=pd.Player then S.lastMeleeTarget=pd.Player end
        if not S.shooting then
            VirtualInputManager:SendMouseButtonEvent(0,0,0,true,game,0);S.shooting=true;S.lastShotTime=tick()
        elseif tick()-S.lastShotTime>=0.15 then
            VirtualInputManager:SendMouseButtonEvent(0,0,0,false,game,0)
            VirtualInputManager:SendMouseButtonEvent(0,0,0,true,game,0);S.lastShotTime=tick()
        end
        break
    end
    if not foundTarget then S.lastMeleeTarget=nil end
end

local function RunAutoSticky(playerData)
    if not (Toggles.AutoStickyDetonate and Toggles.AutoStickyDetonate.Value) then return end
    local stickies=GetMyStickybombs();if #stickies==0 then return end
    local shouldDet=false
    for _,sticky in pairs(stickies) do
        for _,pd in ipairs(playerData) do
            if pd.IsEnemy and (sticky.Position-pd.HRP.Position).Magnitude<=10 then
                if Toggles.AutoStickyVisibleOnly and Toggles.AutoStickyVisibleOnly.Value then
                    if IsPartVisible(sticky) then shouldDet=true;break end
                else shouldDet=true;break end
            end
        end;if shouldDet then break end
    end
    if shouldDet then VirtualInputManager:SendMouseButtonEvent(0,0,1,true,game,0);task.wait(0.05);VirtualInputManager:SendMouseButtonEvent(0,0,1,false,game,0) end
end

local function RunTriggerbot(playerData)
    if not (Toggles.TriggerbotToggle and Toggles.TriggerbotToggle.Value and Options.TriggerbotKey:GetState()) then return end
    if not IsPlayerAlive(LocalPlayer) or tick()-S.lastTriggerTime<Options.TriggerbotDelay.Value then return end
    local weapon=GetLocalWeapon();if BlacklistedWeapons[weapon] then return end
    local hit=GetTriggerbotTarget(playerData)
    if hit then VirtualInputManager:SendMouseButtonEvent(0,0,0,true,game,0);task.wait(0.05);VirtualInputManager:SendMouseButtonEvent(0,0,0,false,game,0);S.lastTriggerTime=tick() end
end

local function RunRagebot()
    if not (Config.Ragebot.Enabled and IsPlayerAlive(LocalPlayer) and WeaponAllowed()) or S.silentAimKeyActive then return end
    local part=FrameCache.ragebotTarget
    if part then
        S.currentTarget=part:FindFirstAncestorOfClass("Model")
        if not S.shooting then
            VirtualInputManager:SendMouseButtonEvent(0,0,0,true,game,0);S.shooting=true;S.lastShotTime=tick()
        elseif tick()-S.lastShotTime>=S.shotInterval then
            VirtualInputManager:SendMouseButtonEvent(0,0,0,false,game,0)
            VirtualInputManager:SendMouseButtonEvent(0,0,0,true,game,0);S.lastShotTime=tick()
        end
        if Config.AimArms.Enable then AimArmsAtTarget(part.Position) end
    elseif S.shooting and not S.silentAimKeyActive then
        VirtualInputManager:SendMouseButtonEvent(0,0,0,false,game,0);S.shooting=false;S.currentTarget=nil
    end
end

local function RunPredictionIndicator()
    if not (Toggles.ShowPredictionIndicator and Toggles.ShowPredictionIndicator.Value and Config.SilentAim.Enabled and S.silentAimKeyActive) then
        PredictionIndicator.Visible=false;return
    end
    local weapon=GetLocalWeapon()
    if not (ProjectileWeapons[weapon] or ChargeWeapons[weapon]) then PredictionIndicator.Visible=false;return end
    local target,targetPlr=FrameCache.silentTarget,FrameCache.silentTargetPlr
    if target and targetPlr then
        local predicted=FrameCache.predictedPos
        if not predicted then predicted=(PredictProjectileHit(target,targetPlr,weapon)) end
        local sp,onScreen=WorldToViewportPoint(predicted)
        if onScreen then
            PredictionIndicator.Text=Options.PredictionIndicatorSymbol and Options.PredictionIndicatorSymbol.Value or "+"
            PredictionIndicator.Position=sp-Vector2.new(0,30)
            PredictionIndicator.Color=Options.PredictionIndicatorColor and Options.PredictionIndicatorColor.Value or Color3.new(0,1,1)
            PredictionIndicator.Visible=true
        else PredictionIndicator.Visible=false end
    else PredictionIndicator.Visible=false end
end

local function RunPredictionVisuals()
    local now=tick()
    local predInline=Options.PredictionInlineColor and Options.PredictionInlineColor.Value or Color3.new(0,1,1)
    local predOutline=Options.PredictionOutlineColor and Options.PredictionOutlineColor.Value or Color3.new(0,0,0)
    local predThick=Options.PredictionThickness and Options.PredictionThickness.Value or 1
    for id,vis in pairs(activePredictionVisuals) do
        local elapsed=now-vis.SpawnTime
        if elapsed>vis.FadeTime then
            if vis.DrawingSet then ReleasePredictionSet(vis.DrawingSet) end
            activePredictionVisuals[id]=nil
        else
            if not vis.DrawingSet then vis.DrawingSet=GetPredictionDrawingSet() end
            local ds=vis.DrawingSet
            if Toggles.ShowPrediction and Toggles.ShowPrediction.Value then
                Draw3DPredictionBox(ds,vis.TargetPos,predInline,predOutline,predThick)
            else for _,l in pairs(ds.Box3DLines) do l.Visible=false end;for _,l in pairs(ds.Box3DOutlines) do l.Visible=false end end
            if Toggles.ShowPredictionCircle and Toggles.ShowPredictionCircle.Value then
                Draw3DCircleAtFeet(ds,vis.TargetPos,predInline,predOutline,predThick)
            else for _,l in pairs(ds.CircleLines) do l.Visible=false end;for _,l in pairs(ds.CircleOutlineLines) do l.Visible=false end end
            if Toggles.ShowProjectilePath and Toggles.ShowProjectilePath.Value and vis.PathPoints and #vis.PathPoints>1 then
                for i=1,math.min(#vis.PathPoints-1,PATH_MAX_SEGMENTS) do
                    local s1,o1=WorldToViewportPoint(vis.PathPoints[i]);local s2,o2=WorldToViewportPoint(vis.PathPoints[i+1])
                    if o1 and o2 then
                        ds.PathOutlines[i].From=s1;ds.PathOutlines[i].To=s2;ds.PathOutlines[i].Color=predOutline;ds.PathOutlines[i].Thickness=predThick+2;ds.PathOutlines[i].Visible=true
                        ds.PathLines[i].From=s1;ds.PathLines[i].To=s2;ds.PathLines[i].Color=predInline;ds.PathLines[i].Thickness=predThick;ds.PathLines[i].Visible=true
                    else ds.PathOutlines[i].Visible=false;ds.PathLines[i].Visible=false end
                end
                for i=math.min(#vis.PathPoints,PATH_MAX_SEGMENTS+1),PATH_MAX_SEGMENTS do ds.PathOutlines[i].Visible=false;ds.PathLines[i].Visible=false end
            else for i=1,PATH_MAX_SEGMENTS do ds.PathOutlines[i].Visible=false;ds.PathLines[i].Visible=false end end
        end
    end
end

------------------------------------------------------------
-- MAIN RENDER LOOP
------------------------------------------------------------
local MainConnection=RunService.RenderStepped:Connect(function(dt)
    if Library.Unloaded then return end
    Camera=Workspace.CurrentCamera
    S.frames=S.frames+1
    visibilityCache={}

    -- Frame cache
    FrameCache.camPos=Camera.CFrame.Position
    FrameCache.camCF=Camera.CFrame
    local vp=Camera.ViewportSize
    FrameCache.screenCenter=Vector2.new(vp.X/2,vp.Y/2)
    FrameCache.simRayParams=nil
    FrameCache.predictedPos=nil
    FrameCache.frameNum=FrameCache.frameNum+1

    EnsureGUILoaded()
    UpdateVelocityTracking()

    if S.isCharging then
        local w=GetLocalWeapon();local cd=ChargeWeapons[w]
        if cd then S.currentChargePercent=math.clamp((tick()-S.chargeStartTime)/cd.ChargeTime,0,1) end
    end

    -- Build and cache player data + targets
    FrameCache.playerData=BuildPlayerData()
    FrameCache.silentTarget,FrameCache.silentTargetPlr=GetSilentAimTarget(FrameCache.playerData)
    FrameCache.ragebotTarget,FrameCache.ragebotTargetPlr=GetRagebotTarget(FrameCache.playerData)

    local playerData=FrameCache.playerData

    RunSilentAimLogic()
    RunAutoWarp(playerData)
    UpdateSmoothAimArms()

    if Toggles.ShowFOVCircle and Toggles.ShowFOVCircle.Value and Config.SilentAim.Enabled then
        FOVCircle.Position=FrameCache.screenCenter
        FOVCircle.Radius=Options.SilentAimFOV.Value;FOVCircle.Color=Options.FOVColor.Value;FOVCircle.Visible=true
    else FOVCircle.Visible=false end

    RunPredictionIndicator()

    do
        local processedPlayers={}
        for _,pd in ipairs(playerData) do
            processedPlayers[pd.Player]=true
            if Toggles.ESPEnabled.Value then CreatePlayerESP(pd.Player);UpdatePlayerESP(pd) else HidePlayerESP(pd.Player) end
            UpdatePlayerChams(pd)
        end
        for p in pairs(ESPObjects) do if not processedPlayers[p] then HidePlayerESP(p) end end
    end

    if Toggles.ObjESPEnabled.Value then
        local act={}
        local function P(cache,tog,name) if tog.Value then for _,o in pairs(cache) do if o.Parent then act[o]=true;UpdateObjectESP(o,name) end end end end
        P(cachedSentries,Toggles.ObjESPSentry,"Sentry");P(cachedDispensers,Toggles.ObjESPDispenser,"Dispenser")
        P(cachedTeleporters,Toggles.ObjESPTeleporter,"Teleporter");P(cachedAmmo,Toggles.ObjESPAmmo,"Ammo");P(cachedHP,Toggles.ObjESPHP,"HP")
        for i in pairs(ObjectESPCache) do if not act[i] or not i.Parent then HideObjectESP(i) end end
    else for i in pairs(ObjectESPCache) do HideObjectESP(i) end end

    UpdateWorldChams();UpdateProjectileChams()
    if Toggles.UsernameHider.Value then UpdateUsernameHider() end

    if Toggles.AgentNotification and Toggles.AgentNotification.Value and tick()-S.lastAgentNotif>3 then
        for _,pd in ipairs(playerData) do
            if pd.IsEnemy and pd.Class=="Agent" and pd.Distance<=30 then
                Library:Notify("🔪 Enemy Agent nearby! ("..pd.Player.Name..")",3);S.lastAgentNotif=tick();break
            end
        end
    end

    RunAntiAim(dt)

    if Toggles.TelestabToggle.Value and Options.TelestabKey:GetState() then
        local lc=GetLocalCharacter();if lc then local lh=GetHRP(lc);if lh then
            local mg,usr=9e9,nil
            for _,pd in ipairs(playerData) do if pd.IsEnemy and pd.Distance<mg then mg=pd.Distance;usr=pd.Character end end
            if usr then for _,v in pairs(usr:GetChildren()) do if v:IsA("BasePart") then v.CanCollide=false end end
                local uh=GetHRP(usr);if uh then uh.CFrame=lh.CFrame+lh.CFrame.LookVector*3.25 end end
        end end
    end

    RunAutoBackstab(playerData)
    RunAutoMelee(playerData)
    RunAutoSticky(playerData)
    RunAutoAirblast()
    CheckAutoUber()
    RunTriggerbot(playerData)
    RunRagebot()

    if S.AdsEnabled and EnsureGUILoaded() then S.ads.Value=true;S.adsmodifier.Value=S.ADSMultiplier end

    RunPredictionVisuals()
end)

------------------------------------------------------------
-- FPS COUNTER
------------------------------------------------------------
task.spawn(function() while task.wait(1) do if Library.Unloaded then break end;S.fps=S.frames;S.frames=0 end end)

------------------------------------------------------------
-- HEAL SELF
------------------------------------------------------------
UserInputService.InputBegan:Connect(function(input,processed)
    if processed or Library.Unloaded then return end
    if Toggles.HealSelfToggle.Value then pcall(function()
        if Options.HealSelfKey:GetState() then Workspace[LocalPlayer.Name].Doctor.ChangeValue:FireServer("Target",LocalPlayer.Name) end
    end) end
end)

------------------------------------------------------------
-- HIT TRACKING
------------------------------------------------------------
do
    local function TrackCharacter(plr)
        if plr==LocalPlayer then return end
        local char=plr.Character;if not char then return end
        local hum=char:FindFirstChildOfClass("Humanoid");if not hum then return end
        healthCache[plr]=hum.Health
        hum.HealthChanged:Connect(function(newHealth)
            if not Config.Flags.Enabled then return end
            local old=healthCache[plr];if not old then healthCache[plr]=newHealth;return end
            if newHealth<old then
                local dmg=math.floor(old-newHealth);local rem=math.floor(newHealth)
                if dmg>0 and dmg<200 and Config.Notifications.ShowHits then
                    local ct=tick()
                    if ct-S.lastHitTime>S.hitCooldown then
                        local msg=""
                        if Config.Flags.ShowName then msg=msg..plr.Name end
                        if Config.Flags.ShowDamage then msg=msg..(msg~="" and " | " or "")..string.format("-%d HP",dmg) end
                        if Config.Flags.ShowRemainingHealth then msg=msg..(msg~="" and " | " or "")..string.format("%d HP left",rem) end
                        if msg~="" then Library:Notify(msg,2) end;S.lastHitTime=ct
                    end
                end
            end
            healthCache[plr]=newHealth
        end)
    end
    for _,plr in ipairs(Players:GetPlayers()) do
        if plr.Character then TrackCharacter(plr) end
        plr.CharacterAdded:Connect(function() task.wait(0.3);TrackCharacter(plr) end)
    end
    Players.PlayerAdded:Connect(function(plr) plr.CharacterAdded:Connect(function() task.wait(0.3);TrackCharacter(plr) end) end)
end

-- HIT_DEBUG detection
LogService.MessageOut:Connect(function(message)
    if typeof(message)~="string" then return end
    if message:find("HIT_DEBUG") then
        if tick()-S.lastHitDebugNotif>2 then
            Library:Notify("⚠ Shot rejected by server — your ping may be too high",3)
            S.lastHitDebugNotif=tick()
        end
    end
end)

------------------------------------------------------------
-- CLEANUP
------------------------------------------------------------
Players.PlayerRemoving:Connect(function(player)
    DestroyPlayerESP(player)
    local c=GetCharacter(player);if c then RemoveHighlight(c,ChamsCache) end
    healthCache[player]=nil;playerVelocities[player]=nil;playerAccelerations[player]=nil
    playerVerticalHistory[player]=nil;playerStrafeHistory[player]=nil;playerPositionHistory[player]=nil
end)

------------------------------------------------------------
-- WATERMARK
------------------------------------------------------------
Library:SetWatermarkVisibility(true)
Library.KeybindFrame.Visible=true
task.spawn(function() while true do task.wait(1);if Library.Unloaded then break end
    local ping=0;pcall(function() ping=math.floor(Stats.Network.ServerStatsItem['Data Ping']:GetValue()) end)
    Library:SetWatermark(('Aegis.dev / %s fps / %s ms'):format(math.floor(S.fps),ping))
end end)

------------------------------------------------------------
-- UNLOAD
------------------------------------------------------------
Library:OnUnload(function()
    for p in pairs(ESPObjects) do DestroyPlayerESP(p) end
    for i in pairs(ObjectESPCache) do DestroyObjectESP(i) end
    for i in pairs(ChamsCache) do RemoveHighlight(i,ChamsCache) end
    for i in pairs(WorldChamsCache) do RemoveHighlight(i,WorldChamsCache) end
    for i in pairs(ProjectileChamsCache) do RemoveHighlight(i,ProjectileChamsCache) end
    for _,set in pairs(predictionDrawingPool) do
        for _,l in pairs(set.Box3DLines) do pcall(function() l:Remove() end) end
        for _,l in pairs(set.Box3DOutlines) do pcall(function() l:Remove() end) end
        for _,l in pairs(set.PathLines) do pcall(function() l:Remove() end) end
        for _,l in pairs(set.PathOutlines) do pcall(function() l:Remove() end) end
        for _,l in pairs(set.CircleLines) do pcall(function() l:Remove() end) end
        for _,l in pairs(set.CircleOutlineLines) do pcall(function() l:Remove() end) end
    end
    FOVCircle:Remove();pcall(function() PredictionIndicator:Remove() end)
    DestroyMobileButton()
    Lighting.Ambient=OL.Ambient;Lighting.Brightness=OL.Brightness;Lighting.FogEnd=OL.FogEnd
    Lighting.FogStart=OL.FogStart;Lighting.ClockTime=OL.ClockTime;Lighting.OutdoorAmbient=OL.OutdoorAmbient
    if S.speedConnection then S.speedConnection:Disconnect() end
    MainConnection:Disconnect()
    if S.shooting then VirtualInputManager:SendMouseButtonEvent(0,0,0,false,game,0);S.shooting=false end
    playerPositionHistory={};print('Unloaded!');Library.Unloaded=true
end)

------------------------------------------------------------
-- UI SETTINGS
------------------------------------------------------------
do
    local MG=Tabs['UI Settings']:AddLeftGroupbox('Menu')
    MG:AddButton('Unload',function() Library:Unload() end)
    MG:AddLabel('Menu bind'):AddKeyPicker('MenuKeybind',{Default='Insert',NoUI=true,Text='Menu keybind'})
    Library.ToggleKeybind=Options.MenuKeybind
end

print("[Aegis Loaded!]")
print("[Premium]")

ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({'MenuKeybind'})
ThemeManager:SetFolder('Aegis')
SaveManager:SetFolder('Aegis/TC2')
SaveManager:BuildConfigSection(Tabs['UI Settings'])
ThemeManager:ApplyToTab(Tabs['UI Settings'])
SaveManager:LoadAutoloadConfig()
