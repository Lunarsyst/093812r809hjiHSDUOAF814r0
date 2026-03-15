--[[ aegis.dev // v5.9 | LocalScript → StarterPlayerScripts ]]--
-- Services needed for the bypass (declared at chunk level so they don't burn registers)
local _Players  = game:GetService("Players")
local _UIS      = game:GetService("UserInputService")
local _LP       = _Players.LocalPlayer

-- PLACE CHECK (first thing, before any UI)
if game.PlaceId ~= 328028363 then _LP:Kick("[Aegis] join tc2"); return end
if setthreadidentity then setthreadidentity(8) end

-- ANTICHEAT BYPASS (before UI so AC threads are dead before we create GUI)
do
    local _RS  = game:GetService("RunService")
    local _Rep = game:GetService("ReplicatedStorage")
    if setthreadidentity then setthreadidentity(8) end
    print("[Aegis] bypass: waiting for sv_setup...")
    repeat _RS.Heartbeat:Wait()
    until _Rep:GetAttribute("sv_setup") and _LP:GetAttribute("FillMeIn")
    for _ = 1, 20 do _RS.Heartbeat:Wait() end
    local cancelled = 0
    pcall(function()
        for _, thread in getreg() do
            if typeof(thread) ~= "thread" then continue end
            local src = debug.info(thread, 1, "s")
            if src and src:match("NewLoader") then
                task.cancel(thread); cancelled += 1
                if cancelled == 3 then break end
            end
        end
    end)
    print(("[Aegis] bypass: %d thread(s) cancelled"):format(cancelled))
    getgenv().tc2_anticheat_breaker = (cancelled == 3)
end

-- Everything else lives in one do..end so the top-level chunk only uses 3 locals above.
-- This keeps us well under Luau's 200-register-per-chunk limit.
local function _buildUI()
-- Re-declare services inside the scoped block
local Players   = _Players
local UIS       = _UIS
local TweenSvc  = game:GetService("TweenService")
local Run       = game:GetService("RunService")
local Http      = game:GetService("HttpService")
local TxtSvc    = game:GetService("TextService")
local LP        = _LP
local Mouse     = LP:GetMouse()
local PGui      = LP:WaitForChild("PlayerGui")

if not rawget(_G,"Toggles") then _G.Toggles={} end
if not rawget(_G,"Options") then _G.Options={} end
local Toggles,Options=_G.Toggles,_G.Options

pcall(function() for _,p in ipairs({"LB","LB/settings"}) do if not isfolder(p) then makefolder(p) end end end)

----------------------------------------------------------------------  Theme
local T={
    Font=Enum.Font.Gotham, FontB=Enum.Font.GothamBold,
    FontC=Color3.fromRGB(228,228,238), Dim=Color3.fromRGB(155,155,172),
    Main=Color3.fromRGB(26,26,31),    Bg=Color3.fromRGB(16,16,20),
    Accent=Color3.fromRGB(255,105,160), Outline=Color3.fromRGB(48,48,60),
    Black=Color3.new(0,0,0),          RowAlt=Color3.fromRGB(20,20,25),
    TabBg=Color3.fromRGB(22,22,28),   Tooltip=Color3.fromRGB(20,20,26),
}
local function Dk(c) local h,s,v=Color3.toHSV(c); return Color3.fromHSV(h,s,v/1.5) end
T.AccentD=Dk(T.Accent)
local WW,WH=570,548

----------------------------------------------------------------------  Helpers
local function N(cls,props,par)
    local o=Instance.new(cls); for k,v in pairs(props) do pcall(function() o[k]=v end) end
    if par then o.Parent=par end; return o
end
local function Tw(o,d,p) TweenSvc:Create(o,TweenInfo.new(d,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),p):Play() end
local function Cr(p,r) N("UICorner",{CornerRadius=UDim.new(0,r or 4)},p) end
local function StC(p,c,t) return N("UIStroke",{Color=c or T.Outline,Thickness=t or 1,ApplyStrokeMode=Enum.ApplyStrokeMode.Border},p) end
local function Grad(p) N("UIGradient",{Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.new(1,1,1)),ColorSequenceKeypoint.new(1,Color3.fromRGB(210,210,210))}),Rotation=90},p) end
local function AH() return ("rgb(%d,%d,%d)"):format(math.floor(T.Accent.R*255+.5),math.floor(T.Accent.G*255+.5),math.floor(T.Accent.B*255+.5)) end

local function Drag(handle,target)
    target=target or handle
    local on=false; local ox,oy=0,0; local px,py=UDim2.new(),UDim2.new()
    handle.InputBegan:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
            on=true; ox,oy=i.Position.X,i.Position.Y; px,py=target.Position.X,target.Position.Y end
    end)
    UIS.InputChanged:Connect(function(i)
        if on and (i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch) then
            target.Position=UDim2.new(px.Scale,px.Offset+(i.Position.X-ox),py.Scale,py.Offset+(i.Position.Y-oy)) end
    end)
    UIS.InputEnded:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then on=false end
    end)
end

local function MakeDragX(elem,cb)
    local d=false
    elem.InputBegan:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
            d=true; cb(i.Position.X)
            if i.UserInputType==Enum.UserInputType.MouseButton1 then
                while UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) do cb(Mouse.X); Run.RenderStepped:Wait() end; d=false end
        end
    end)
    UIS.InputChanged:Connect(function(i) if d and i.UserInputType==Enum.UserInputType.Touch then cb(i.Position.X) end end)
    UIS.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.Touch then d=false end end)
end
local function MakeDragY(elem,cb)
    local d=false
    elem.InputBegan:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
            d=true; cb(i.Position.Y)
            if i.UserInputType==Enum.UserInputType.MouseButton1 then
                while UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) do cb(Mouse.Y); Run.RenderStepped:Wait() end; d=false end
        end
    end)
    UIS.InputChanged:Connect(function(i) if d and i.UserInputType==Enum.UserInputType.Touch then cb(i.Position.Y) end end)
    UIS.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.Touch then d=false end end)
end
local function MakeDragXY(elem,cbX,cbY)
    local d=false
    elem.InputBegan:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
            d=true; cbX(i.Position.X); cbY(i.Position.Y)
            if i.UserInputType==Enum.UserInputType.MouseButton1 then
                while UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) do cbX(Mouse.X); cbY(Mouse.Y); Run.RenderStepped:Wait() end; d=false end
        end
    end)
    UIS.InputChanged:Connect(function(i) if d and i.UserInputType==Enum.UserInputType.Touch then cbX(i.Position.X); cbY(i.Position.Y) end end)
    UIS.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.Touch then d=false end end)
end

----------------------------------------------------------------------  ScreenGui + Win
local Gui=N("ScreenGui",{Name="aegis.dev",ResetOnSpawn=false,ZIndexBehavior=Enum.ZIndexBehavior.Global,DisplayOrder=100},PGui)
print("[aegis.dev] ScreenGui created")

local activePopup=nil
local function ClosePopup() if activePopup and activePopup.Parent then activePopup:Destroy() end; activePopup=nil end

local Win=N("Frame",{Size=UDim2.fromOffset(WW,WH),Position=UDim2.new(0.5,-WW/2,0.5,-WH/2),BackgroundColor3=T.Bg,BorderSizePixel=0,ZIndex=2},Gui)
Cr(Win,6); N("UIStroke",{Color=T.Accent,Thickness=1.2,ApplyStrokeMode=Enum.ApplyStrokeMode.Border},Win)
for i=1,2 do
    local g=N("Frame",{Size=UDim2.new(1,i*14,1,i*14),Position=UDim2.new(0,-i*7,0,-i*7),BackgroundColor3=T.Accent,BackgroundTransparency=0.88+i*0.05,BorderSizePixel=0,ZIndex=1},Win); Cr(g,10+i*6)
end

local function RefWinScale()
    local gs=Gui.AbsoluteSize; if gs.X<=0 or gs.Y<=0 then return end
    local sc=math.min(gs.X/1920,gs.Y/1080,1)
    local nw=math.floor(WW*sc); local nh=math.floor(WH*sc)
    Win.Size=UDim2.fromOffset(nw,nh); Win.Position=UDim2.new(0.5,-nw/2,0.5,-nh/2)
end
task.defer(RefWinScale); Gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(RefWinScale)

-- Resize grip
local MIN_W,MIN_H=360,320; local MAX_W,MAX_H=900,800
local ResizeGrip=N("TextButton",{Text="",BackgroundTransparency=1,Size=UDim2.fromOffset(14,14),Position=UDim2.new(1,-14,1,-14),ZIndex=20},Win)
do local rc=Color3.fromRGB(80,80,100)
    N("Frame",{Size=UDim2.fromOffset(8,1),Position=UDim2.fromOffset(6,13),BackgroundColor3=rc,BorderSizePixel=0,ZIndex=21},ResizeGrip)
    N("Frame",{Size=UDim2.fromOffset(1,8),Position=UDim2.fromOffset(13,6),BackgroundColor3=rc,BorderSizePixel=0,ZIndex=21},ResizeGrip)
    N("Frame",{Size=UDim2.fromOffset(5,1),Position=UDim2.fromOffset(9,10),BackgroundColor3=rc,BorderSizePixel=0,ZIndex=21},ResizeGrip)
    N("Frame",{Size=UDim2.fromOffset(1,5),Position=UDim2.fromOffset(10,9),BackgroundColor3=rc,BorderSizePixel=0,ZIndex=21},ResizeGrip)
end
ResizeGrip.MouseEnter:Connect(function() ResizeGrip.BackgroundTransparency=0.85; ResizeGrip.BackgroundColor3=T.Accent end)
ResizeGrip.MouseLeave:Connect(function() ResizeGrip.BackgroundTransparency=1 end)
ResizeGrip.InputBegan:Connect(function(i)
    if i.UserInputType==Enum.UserInputType.MouseButton1 then
        local sx,sy=i.Position.X,i.Position.Y; local sw,sh=Win.AbsoluteSize.X,Win.AbsoluteSize.Y
        local spx,spy=Win.AbsolutePosition.X,Win.AbsolutePosition.Y
        while UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) do
            local nw=math.clamp(sw+(Mouse.X-sx),MIN_W,MAX_W); local nh=math.clamp(sh+(Mouse.Y-sy),MIN_H,MAX_H)
            Win.Size=UDim2.fromOffset(nw,nh); Win.Position=UDim2.fromOffset(spx,spy); Run.RenderStepped:Wait()
        end
    end
end)

----------------------------------------------------------------------  Tooltip system
-- Single shared tooltip frame; shown near mouse, hidden on leave.
local TipFrame=N("Frame",{BackgroundColor3=T.Tooltip,BorderSizePixel=0,ZIndex=500,Visible=false,Size=UDim2.fromOffset(10,20)},Gui)
Cr(TipFrame,3); StC(TipFrame,T.Accent,1)
local TipLabel=N("TextLabel",{BackgroundTransparency=1,Font=T.Font,TextColor3=T.FontC,TextSize=11,TextXAlignment=Enum.TextXAlignment.Left,TextWrapped=true,ZIndex=501,Size=UDim2.new(1,-8,1,0),Position=UDim2.fromOffset(4,0)},TipFrame)
local tipActive=false

-- SetTooltip wires hover/leave on any GuiObject to show/hide the tooltip.
local function SetTooltip(frame,text)
    if not text or text=="" then return end
    frame.MouseEnter:Connect(function()
        tipActive=true
        TipLabel.Text=text
        local tw=TxtSvc:GetTextSize(text,11,T.Font,Vector2.new(220,9999))
        TipFrame.Size=UDim2.fromOffset(math.min(tw.X+12,230),tw.Y+8)
        TipFrame.Visible=true
    end)
    frame.MouseLeave:Connect(function() tipActive=false; TipFrame.Visible=false end)
    -- Keep on screen, follow mouse
    Run.RenderStepped:Connect(function()
        if not tipActive then return end
        local gs=Gui.AbsoluteSize; local ts=TipFrame.AbsoluteSize
        local px=math.clamp(Mouse.X+14,2,gs.X-ts.X-2)
        local py=math.clamp(Mouse.Y-ts.Y-6,2,gs.Y-ts.Y-2)
        TipFrame.Position=UDim2.fromOffset(px,py)
    end)
end

----------------------------------------------------------------------  Title bar
local TH=30
local TB=N("Frame",{Size=UDim2.new(1,0,0,TH),BackgroundColor3=T.Main,BorderSizePixel=0,ZIndex=5},Win)
Cr(TB,6); N("Frame",{Size=UDim2.new(1,0,0.5,0),Position=UDim2.new(0,0,0.5,0),BackgroundColor3=T.Main,BorderSizePixel=0,ZIndex=5},TB)
N("Frame",{Size=UDim2.new(1,0,0,1),Position=UDim2.new(0,0,1,-1),BackgroundColor3=T.Outline,BorderSizePixel=0,ZIndex=6},TB)
Drag(TB,Win)
local TitleLbl=N("TextLabel",{Text="",RichText=true,Size=UDim2.new(1,-34,1,0),Position=UDim2.fromOffset(8,0),BackgroundTransparency=1,Font=T.Font,TextColor3=T.FontC,TextSize=14,TextXAlignment=Enum.TextXAlignment.Left,ZIndex=6},TB)
local function RefTitle() TitleLbl.Text=('aegis<font color="%s">.dev</font>'):format(AH()) end; RefTitle()
local CX=N("TextButton",{Text="×",Size=UDim2.fromOffset(24,24),Position=UDim2.new(1,-28,0.5,-12),BackgroundTransparency=1,Font=T.FontB,TextColor3=T.Dim,TextSize=18,ZIndex=7},TB)
CX.MouseEnter:Connect(function() Tw(CX,0.1,{TextColor3=Color3.fromRGB(255,65,65)}) end)
CX.MouseLeave:Connect(function() Tw(CX,0.1,{TextColor3=T.Dim}) end)
CX.MouseButton1Click:Connect(function() print("[aegis.dev] closed"); Gui:Destroy() end)

----------------------------------------------------------------------  Content + Footer
local TABH=26; local tabAreaY=TH+1; local FOOT=22; local CY=tabAreaY+TABH+5
local ContentArea=N("Frame",{Size=UDim2.new(1,-12,1,-(CY+FOOT+4)),Position=UDim2.new(0,6,0,CY),BackgroundColor3=T.Main,BorderSizePixel=0,ZIndex=3},Win)
Cr(ContentArea,4); StC(ContentArea,T.Outline,1)
local TabContainer=N("Frame",{Size=UDim2.new(1,0,1,0),BackgroundTransparency=1,ZIndex=3},ContentArea)

local Foot=N("Frame",{Size=UDim2.new(1,0,0,FOOT),Position=UDim2.new(0,0,1,-FOOT),BackgroundColor3=T.Main,BorderSizePixel=0,ZIndex=5},Win)
Cr(Foot,6); N("Frame",{Size=UDim2.new(1,0,0.5,0),BackgroundColor3=T.Main,BorderSizePixel=0,ZIndex=5},Foot)
N("Frame",{Size=UDim2.new(1,0,0,1),BackgroundColor3=T.Outline,BorderSizePixel=0,ZIndex=6},Foot)
local FL=N("TextLabel",{Text="",RichText=true,Size=UDim2.new(0.55,-10,1,0),Position=UDim2.fromOffset(9,0),BackgroundTransparency=1,Font=T.Font,TextColor3=T.Dim,TextSize=11,TextXAlignment=Enum.TextXAlignment.Left,ZIndex=6},Foot)
local FR=N("TextLabel",{Text="",RichText=true,Size=UDim2.new(0.45,-9,1,0),Position=UDim2.new(0.55,0,0,0),BackgroundTransparency=1,Font=T.Font,TextColor3=T.Dim,TextSize=11,TextXAlignment=Enum.TextXAlignment.Right,ZIndex=6},Foot)
local function RefFoot() local a=AH()
    FL.Text=('user: <font color="%s">astral</font>  //  subscription: <font color="%s">lite</font>'):format(a,a)
    FR.Text=('build: <font color="%s">developer</font>'):format(a)
end; RefFoot()

----------------------------------------------------------------------  Notifications
local NArea=N("Frame",{Position=UDim2.fromOffset(4,42),Size=UDim2.fromOffset(260,500),BackgroundTransparency=1,ZIndex=300},Gui)
N("UIListLayout",{Padding=UDim.new(0,3),FillDirection=Enum.FillDirection.Vertical,SortOrder=Enum.SortOrder.LayoutOrder},NArea)
local function Notify(txt,dur)
    print("[notify] "..txt)
    local xs=TxtSvc:GetTextSize(txt,12,T.Font,Vector2.new(9999,9999)).X
    local f=N("Frame",{Size=UDim2.fromOffset(0,20),ClipsDescendants=true,BackgroundColor3=T.Main,BorderSizePixel=0,ZIndex=301},NArea)
    Cr(f,3); StC(f,T.Outline,1)
    N("Frame",{Size=UDim2.fromOffset(3,20),BackgroundColor3=T.Accent,BorderSizePixel=0,ZIndex=302},f)
    N("TextLabel",{Text=txt,Size=UDim2.new(1,-10,1,0),Position=UDim2.fromOffset(9,0),BackgroundTransparency=1,Font=T.Font,TextColor3=T.FontC,TextSize=12,TextXAlignment=Enum.TextXAlignment.Left,ZIndex=302},f)
    Tw(f,0.22,{Size=UDim2.fromOffset(xs+18,20)})
    task.spawn(function() task.wait(dur or 4); Tw(f,0.22,{Size=UDim2.fromOffset(0,20)}); task.wait(0.23); pcall(function() f:Destroy() end) end)
end

----------------------------------------------------------------------  Watermark
local WMF=N("Frame",{Size=UDim2.fromOffset(180,22),Position=UDim2.new(0.5,-WW/2,0.5,-WH/2-30),BackgroundColor3=T.Main,BorderSizePixel=0,ZIndex=150,Visible=false},Gui)
Cr(WMF,4); StC(WMF,T.Accent,1)
do local g=N("Frame",{Size=UDim2.new(1,12,1,12),Position=UDim2.new(0,-6,0,-6),BackgroundColor3=T.Accent,BackgroundTransparency=0.88,BorderSizePixel=0,ZIndex=149},WMF); Cr(g,9) end
N("Frame",{Size=UDim2.new(1,0,0,2),BackgroundColor3=T.Accent,BorderSizePixel=0,ZIndex=151},WMF)
local WML=N("TextLabel",{Text="",RichText=true,Size=UDim2.new(1,-10,1,0),Position=UDim2.fromOffset(6,0),BackgroundTransparency=1,Font=T.Font,TextColor3=T.Dim,TextSize=12,TextXAlignment=Enum.TextXAlignment.Left,ZIndex=151},WMF)
Drag(WMF)
local fpsC,fpsA,fpsT,wmOn=0,0,0,false
local wmUserMoved=false
do local _on=false
    WMF.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then _on=true end end)
    UIS.InputEnded:Connect(function(i) if _on and (i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch) then _on=false; wmUserMoved=true end end)
end
Run.RenderStepped:Connect(function(dt)
    fpsA+=1; fpsT+=dt
    if fpsT>=1 then fpsC=fpsA; fpsA=0; fpsT=0 end
    if not wmOn then return end
    local plain=("aegis.dev  |  %d fps  |  %s"):format(fpsC,os.date("%H:%M:%S"))
    local xs=TxtSvc:GetTextSize(plain,12,T.Font,Vector2.new(9999,9999)).X
    WMF.Size=UDim2.fromOffset(xs+16,22)
    if not wmUserMoved then local wp=Win.AbsolutePosition; WMF.Position=UDim2.fromOffset(wp.X,wp.Y-28) end
    WML.Text=('aegis<font color="%s">.dev</font>  |  <font color="rgb(200,200,210)">%d fps</font>  |  <font color="rgb(105,105,122)">%s</font>'):format(AH(),fpsC,os.date("%H:%M:%S"))
end)

----------------------------------------------------------------------  Keybind Widget
local KBW_BASE=180
local KBF=N("Frame",{Size=UDim2.fromOffset(KBW_BASE,24),Position=UDim2.new(0.5,WW/2-KBW_BASE,0.5,-WH/2-30),BackgroundColor3=Color3.fromRGB(14,14,18),BorderSizePixel=0,ZIndex=150,Visible=false,ClipsDescendants=true},Gui)
Cr(KBF,4); StC(KBF,T.Outline,1)
do local g=N("Frame",{Size=UDim2.new(1,12,1,12),Position=UDim2.new(0,-6,0,-6),BackgroundColor3=T.Accent,BackgroundTransparency=0.9,BorderSizePixel=0,ZIndex=149},KBF); Cr(g,9) end
N("Frame",{Size=UDim2.new(1,0,0,2),BackgroundColor3=T.Accent,BorderSizePixel=0,ZIndex=151},KBF)
local KBHead=N("Frame",{Size=UDim2.new(1,0,0,20),BackgroundTransparency=1,ZIndex=151},KBF)
N("TextLabel",{Text="keybinds",Size=UDim2.new(1,-8,1,0),Position=UDim2.fromOffset(5,2),BackgroundTransparency=1,Font=T.Font,TextColor3=T.FontC,TextSize=12,TextXAlignment=Enum.TextXAlignment.Left,ZIndex=151},KBHead)
Drag(KBHead,KBF)
local KBC=N("Frame",{Size=UDim2.new(1,0,1,-20),Position=UDim2.fromOffset(0,20),BackgroundTransparency=1,ZIndex=151},KBF)
N("UIListLayout",{FillDirection=Enum.FillDirection.Vertical,SortOrder=Enum.SortOrder.LayoutOrder},KBC)
N("UIPadding",{PaddingLeft=UDim.new(0,5),PaddingRight=UDim.new(0,5),PaddingBottom=UDim.new(0,3)},KBC)
local kbUserMoved=false
do local _on=false
    KBHead.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then _on=true end end)
    UIS.InputEnded:Connect(function(i) if _on and (i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch) then _on=false; kbUserMoved=true end end)
end

local kbEntries,kbRows,kbShow={},{},false
local function RefKB()
    for _,v in pairs(kbRows) do pcall(function() v:Destroy() end) end; kbRows={}; local n=0
    local maxLabelW=0
    for idx,e in pairs(kbEntries) do
        if e.Key and e.Key~="None" then
            local lw=TxtSvc:GetTextSize(e.Label or idx,11,T.Font,Vector2.new(9999,9999)).X
            if lw>maxLabelW then maxLabelW=lw end
        end
    end
    local KBW=math.max(KBW_BASE, maxLabelW+70)
    for idx,e in pairs(kbEntries) do
        if e.Key and e.Key~="None" then
            local togRef=e.ToggleRef; local active=togRef and togRef.Value or false
            local row=N("Frame",{Size=UDim2.new(1,0,0,18),BackgroundTransparency=1,ZIndex=152,LayoutOrder=n},KBC); kbRows[idx]=row
            local nameLbl=N("TextLabel",{Text=e.Label,Size=UDim2.new(1,-52,1,0),BackgroundTransparency=1,Font=T.Font,TextColor3=active and T.FontC or T.Dim,TextSize=11,TextXAlignment=Enum.TextXAlignment.Left,ZIndex=153},row)
            N("TextLabel",{Text="["..e.Key.."]",Size=UDim2.fromOffset(34,18),Position=UDim2.new(1,-48,0,0),BackgroundTransparency=1,Font=T.Font,TextColor3=T.Accent,TextSize=10,TextXAlignment=Enum.TextXAlignment.Right,ZIndex=153},row)
            if togRef then
                local aBtn=N("TextButton",{Text="",Size=UDim2.fromOffset(12,12),Position=UDim2.new(1,-12,0.5,-6),BackgroundColor3=active and T.Accent or T.Bg,BorderSizePixel=0,ZIndex=153},row)
                Cr(aBtn,99); StC(aBtn,T.Accent,1)
                local function SyncAct(v) Tw(aBtn,0.1,{BackgroundColor3=v and T.Accent or T.Bg}); nameLbl.TextColor3=v and T.FontC or T.Dim end
                aBtn.MouseButton1Click:Connect(function() if togRef then togRef:SetValue(not togRef.Value) end end)
                togRef:OnChanged(function(v) if aBtn.Parent then SyncAct(v) end end)
            end
            n+=1
        end
    end
    KBF.Size=UDim2.fromOffset(KBW,24+(n>0 and n*19+4 or 0)); KBF.Visible=kbShow and n>0
    if not kbUserMoved then local wp=Win.AbsolutePosition; local ws=Win.AbsoluteSize; KBF.Position=UDim2.fromOffset(wp.X+ws.X-KBW,wp.Y-28) end
end

----------------------------------------------------------------------  ELEMENT BUILDERS
local function EBlank(p,h) N("Frame",{Size=UDim2.new(1,0,0,h),BackgroundTransparency=1,ZIndex=5},p) end

local function EGroup(parent)
    local h=N("Frame",{BackgroundTransparency=1,Size=UDim2.new(1,0,0,0),ClipsDescendants=false,ZIndex=5},parent)
    local ll=N("UIListLayout",{Padding=UDim.new(0,0),FillDirection=Enum.FillDirection.Vertical,SortOrder=Enum.SortOrder.LayoutOrder},h)
    ll:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() h.Size=UDim2.new(1,0,0,h.Visible and ll.AbsoluteContentSize.Y or 0) end)
    return h
end

-- EToggle(parent, label, idx, default, tooltip?)
local function EToggle(parent,label,idx,default,tooltip)
    default=default==nil and false or default
    local row=N("Frame",{Size=UDim2.new(1,0,0,18),BackgroundTransparency=1,ZIndex=5},parent)
    N("UIPadding",{PaddingLeft=UDim.new(0,4)},row)
    local outer=N("Frame",{BackgroundColor3=T.Black,BorderSizePixel=0,Size=UDim2.fromOffset(12,12),Position=UDim2.new(0,0,0.5,-6),ZIndex=6},row); Cr(outer,99)
    local inner=N("Frame",{BackgroundColor3=default and T.Accent or T.Main,BorderColor3=default and T.AccentD or T.Outline,BorderMode=Enum.BorderMode.Inset,Size=UDim2.new(1,0,1,0),ZIndex=7},outer); Cr(inner,99)
    local lbl=N("TextLabel",{Text=label,BackgroundTransparency=1,Font=T.Font,TextColor3=T.FontC,TextSize=12,TextXAlignment=Enum.TextXAlignment.Left,Size=UDim2.new(1,-52,1,0),Position=UDim2.fromOffset(16,0),ZIndex=7},row)
    local addonCont=N("Frame",{BackgroundTransparency=1,Size=UDim2.fromOffset(52,18),Position=UDim2.new(1,-52,0,0),ZIndex=7,ClipsDescendants=true},row)
    N("UIListLayout",{Padding=UDim.new(0,2),FillDirection=Enum.FillDirection.Horizontal,HorizontalAlignment=Enum.HorizontalAlignment.Right,VerticalAlignment=Enum.VerticalAlignment.Center,SortOrder=Enum.SortOrder.LayoutOrder},addonCont)
    local hit=N("TextButton",{Text="",BackgroundTransparency=1,Size=UDim2.new(1,-54,1,0),ZIndex=9},row)
    local hStk=StC(outer,T.Accent,1.2); hStk.Transparency=1
    hit.MouseEnter:Connect(function() Tw(hStk,0.1,{Transparency=0}) end)
    hit.MouseLeave:Connect(function() Tw(hStk,0.1,{Transparency=1}) end)
    hit.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.Touch then Tw(hStk,0.1,{Transparency=0}) end end)
    hit.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.Touch then Tw(hStk,0.1,{Transparency=1}) end end)
    if tooltip then SetTooltip(lbl,tooltip); SetTooltip(hit,tooltip) end
    local state=default; local cbs={}
    local obj={Value=state,Type="Toggle",AddonContainer=addonCont,Row=row,
        SetValue=function(self,v) state=v; self.Value=v
            inner.BackgroundColor3=v and T.Accent or T.Main; inner.BorderColor3=v and T.AccentD or T.Outline
            if idx then print("[toggle] "..idx.." = "..tostring(v)) end
            for _,cb in ipairs(cbs) do cb(v) end end,
        OnChanged=function(self,cb) table.insert(cbs,cb); cb(state) end,
    }
    hit.MouseButton1Click:Connect(function() obj:SetValue(not state) end)
    if idx then Toggles[idx]=obj end; EBlank(parent,3); return obj
end

-- ESlider(parent, label, idx, mn, mx, default, suffix, tooltip?)
local function ESlider(parent,label,idx,mn,mx,default,suffix,tooltip)
    default=default or mn; suffix=suffix or ""
    local lrow=N("Frame",{Size=UDim2.new(1,0,0,13),BackgroundTransparency=1,ZIndex=5},parent)
    N("UIPadding",{PaddingLeft=UDim.new(0,4),PaddingRight=UDim.new(0,4)},lrow)
    local lblEl=N("TextLabel",{Text=label,BackgroundTransparency=1,Font=T.Font,TextColor3=T.FontC,TextSize=12,TextXAlignment=Enum.TextXAlignment.Left,Size=UDim2.new(1,-42,1,0),ZIndex=6},lrow)
    local valLbl=N("TextLabel",{Text="",RichText=true,BackgroundTransparency=1,Font=T.Font,TextSize=12,TextXAlignment=Enum.TextXAlignment.Right,Size=UDim2.fromOffset(42,13),Position=UDim2.new(1,-42,0,0),ZIndex=6},lrow)
    EBlank(parent,1)
    local trow=N("Frame",{Size=UDim2.new(1,0,0,6),BackgroundTransparency=1,ZIndex=5},parent)
    N("UIPadding",{PaddingLeft=UDim.new(0,4),PaddingRight=UDim.new(0,4)},trow)
    local tO=N("Frame",{BackgroundColor3=T.Black,BorderSizePixel=0,Size=UDim2.new(1,0,1,0),ZIndex=6},trow); Cr(tO,3)
    local tI=N("Frame",{BackgroundColor3=Color3.fromRGB(34,34,42),BorderColor3=T.Outline,BorderMode=Enum.BorderMode.Inset,Size=UDim2.new(1,0,1,0),ZIndex=7},tO); Cr(tI,3)
    local fill=N("Frame",{BackgroundColor3=T.Accent,BorderSizePixel=0,Size=UDim2.new(0,0,1,0),ZIndex=8},tI); Cr(fill,3)
    local slHit=N("TextButton",{Text="",BackgroundTransparency=1,Size=UDim2.new(1,0,1,0),ZIndex=9},tO)
    local slStk=StC(tI,T.Accent,1); slStk.Transparency=1
    slHit.MouseEnter:Connect(function() Tw(slStk,0.1,{Transparency=0}) end)
    slHit.MouseLeave:Connect(function() Tw(slStk,0.1,{Transparency=1}) end)
    if tooltip then SetTooltip(lblEl,tooltip); SetTooltip(slHit,tooltip) end
    local val=default; local cbs={}
    local function Disp()
        valLbl.Text=('<font color="%s">%s%s</font>'):format(AH(),tostring(val),suffix)
        fill.Size=UDim2.new((val-mn)/(mx-mn),0,1,0)
    end
    local obj={Value=val,Min=mn,Max=mx,Type="Slider",
        SetValue=function(self,v) v=tonumber(v) or mn; v=math.clamp(math.floor(v+0.5),mn,mx)
            self.Value=v; val=v; Disp()
            if idx then print("[slider] "..idx.." = "..tostring(v)) end
            for _,cb in ipairs(cbs) do cb(v) end end,
        OnChanged=function(self,cb) table.insert(cbs,cb); cb(self.Value) end,
    }
    Disp()
    MakeDragX(slHit,function(x) local ap,as=tI.AbsolutePosition,tI.AbsoluteSize; if as.X>0 then obj:SetValue(mn+math.clamp((x-ap.X)/as.X,0,1)*(mx-mn)) end end)
    if idx then Options[idx]=obj end; EBlank(parent,4); return obj
end

-- EDropdown(parent, label, idx, values, default, multi, specialType, tooltip?)
local function EDropdown(parent,label,idx,values,default,multi,specialType,tooltip)
    if specialType=="Player" then values={}; for _,p in ipairs(Players:GetPlayers()) do if p~=LP then table.insert(values,p.Name) end end end
    values=values or {}
    if label and label~="" then
        local lr=N("Frame",{Size=UDim2.new(1,0,0,13),BackgroundTransparency=1,ZIndex=5},parent); N("UIPadding",{PaddingLeft=UDim.new(0,4)},lr)
        local lblEl=N("TextLabel",{Text=label,BackgroundTransparency=1,Font=T.Font,TextColor3=T.FontC,TextSize=12,TextXAlignment=Enum.TextXAlignment.Left,Size=UDim2.new(1,0,1,0),ZIndex=6},lr)
        if tooltip then SetTooltip(lblEl,tooltip) end
        EBlank(parent,1)
    end
    local dr=N("Frame",{Size=UDim2.new(1,0,0,19),BackgroundTransparency=1,ZIndex=5},parent)
    N("UIPadding",{PaddingLeft=UDim.new(0,4),PaddingRight=UDim.new(0,4)},dr)
    local outer=N("Frame",{BackgroundColor3=T.Black,BorderSizePixel=0,Size=UDim2.new(1,0,1,0),ZIndex=6},dr); Cr(outer,2)
    local inner=N("Frame",{BackgroundColor3=T.Main,BorderColor3=T.Outline,BorderMode=Enum.BorderMode.Inset,Size=UDim2.new(1,0,1,0),ZIndex=7},outer); Cr(inner,2); Grad(inner)
    local iLbl=N("TextLabel",{Text="--",BackgroundTransparency=1,Font=T.Font,TextColor3=T.FontC,TextSize=12,TextXAlignment=Enum.TextXAlignment.Left,Size=UDim2.new(1,-8,1,0),Position=UDim2.fromOffset(4,0),ZIndex=8},inner)
    local ddHit=N("TextButton",{Text="",BackgroundTransparency=1,Size=UDim2.new(1,0,1,0),ZIndex=10},inner)
    local ddStk=StC(outer,T.Accent,1); ddStk.Transparency=1
    ddHit.MouseEnter:Connect(function() Tw(ddStk,0.1,{Transparency=0}) end)
    ddHit.MouseLeave:Connect(function() Tw(ddStk,0.1,{Transparency=1}) end)
    ddHit.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.Touch then Tw(ddStk,0.1,{Transparency=0}) end end)
    if tooltip then SetTooltip(ddHit,tooltip); SetTooltip(iLbl,tooltip) end
    local curVal=multi and {} or (default or values[1] or nil); local cVals=values; local cbs={}
    local function Disp()
        if multi then local t={}; for v,_ in pairs(curVal) do table.insert(t,v) end; iLbl.Text=#t>0 and table.concat(t,", ") or "--"
        else iLbl.Text=tostring(curVal or "--") end
    end
    local obj={Value=curVal,Multi=multi,Type="Dropdown",SpecialType=specialType,Row=dr,
        SetValues=function(self,v) cVals=v or {} end,
        OnChanged=function(self,cb) table.insert(cbs,cb); cb(self.Value) end,
        SetValue=function(self,v)
            if multi then local nv={}; if type(v)=="table" then for k,_ in pairs(v) do if table.find(cVals,k) then nv[k]=true end end end; curVal=nv; self.Value=curVal
            else curVal=(v~=nil and table.find(cVals,v)) and v or nil; self.Value=curVal end
            Disp(); if idx then print("[dropdown] "..idx.." = "..tostring(curVal)) end
            for _,cb in ipairs(cbs) do cb(self.Value) end end,
    }; Disp()
    if specialType=="Player" then
        local function RefP() cVals={}; for _,p in ipairs(Players:GetPlayers()) do if p~=LP then table.insert(cVals,p.Name) end end end
        Players.PlayerAdded:Connect(RefP); Players.PlayerRemoving:Connect(function() task.wait(); RefP() end)
    end
    ddHit.MouseButton1Click:Connect(function()
        if activePopup and activePopup.Parent then activePopup:Destroy(); activePopup=nil; return end
        local n=#cVals; if n==0 then return end
        local PH=math.min(n,8)*20+2; local ap=inner.AbsolutePosition; local aw=inner.AbsoluteSize.X
        local popY=ap.Y+inner.AbsoluteSize.Y+1; if popY+PH>Gui.AbsoluteSize.Y-4 then popY=ap.Y-PH-1 end
        local lo=N("Frame",{BackgroundColor3=T.Black,BorderSizePixel=0,Size=UDim2.fromOffset(aw,PH),Position=UDim2.fromOffset(ap.X,popY),ZIndex=200},Gui)
        Cr(lo,3); StC(lo,T.Accent,1)
        local li=N("Frame",{BackgroundColor3=T.Main,BorderSizePixel=0,Size=UDim2.new(1,-2,1,-2),Position=UDim2.fromOffset(1,1),ZIndex=201},lo); Cr(li,3)
        local sf=N("ScrollingFrame",{BackgroundTransparency=1,BorderSizePixel=0,Size=UDim2.new(1,0,1,0),CanvasSize=UDim2.fromOffset(0,n*20+1),ScrollBarThickness=3,ScrollBarImageColor3=T.Accent,ZIndex=201},li)
        N("UIListLayout",{Padding=UDim.new(0,0),FillDirection=Enum.FillDirection.Vertical,SortOrder=Enum.SortOrder.LayoutOrder},sf)
        for _,val in ipairs(cVals) do
            local sel=multi and (type(curVal)=="table" and curVal[val]==true) or (curVal==val)
            local item=N("Frame",{BackgroundColor3=T.Main,Size=UDim2.new(1,-1,0,20),ZIndex=203},sf)
            local check; if multi then
                check=N("Frame",{BackgroundColor3=sel and T.Accent or T.Bg,BorderSizePixel=0,Size=UDim2.fromOffset(8,8),Position=UDim2.fromOffset(5,6),ZIndex=205},item); Cr(check,99); StC(check,T.Accent,1)
            end
            local tl=N("TextLabel",{Text=val,BackgroundTransparency=1,Font=T.Font,TextSize=12,TextXAlignment=Enum.TextXAlignment.Left,Size=UDim2.new(1,multi and -20 or -6,1,0),Position=UDim2.fromOffset(multi and 18 or 6,0),TextColor3=sel and T.Accent or T.FontC,ZIndex=204},item)
            local hb=N("TextButton",{Text="",BackgroundTransparency=1,Size=UDim2.new(1,0,1,0),ZIndex=205},item)
            hb.MouseEnter:Connect(function() item.BackgroundColor3=Color3.fromRGB(32,32,40) end)
            hb.MouseLeave:Connect(function() item.BackgroundColor3=T.Main end)
            hb.MouseButton1Click:Connect(function()
                if multi then
                    if type(curVal)~="table" then curVal={} end
                    if curVal[val] then curVal[val]=nil else curVal[val]=true end
                    obj.Value=curVal; local ns=curVal[val]==true
                    if check then check.BackgroundColor3=ns and T.Accent or T.Bg end
                    tl.TextColor3=ns and T.Accent or T.FontC; Disp()
                    for _,cb in ipairs(cbs) do cb(obj.Value) end
                else obj:SetValue(val); lo:Destroy(); activePopup=nil end
            end)
        end
        activePopup=lo
        local con; con=UIS.InputBegan:Connect(function(inp)
            if inp.UserInputType==Enum.UserInputType.MouseButton1 or inp.UserInputType==Enum.UserInputType.Touch then
                local ax,ay=inp.Position.X,inp.Position.Y; local lp,ls=lo.AbsolutePosition,lo.AbsoluteSize
                if ax<lp.X or ax>lp.X+ls.X or ay<lp.Y or ay>lp.Y+ls.Y then
                    if lo.Parent then lo:Destroy() end; activePopup=nil; con:Disconnect() end
            end
        end)
    end)
    if idx then Options[idx]=obj end; EBlank(parent,4); return obj
end

-- EInput(parent, label, idx, placeholder, default, tooltip?)
local function EInput(parent,label,idx,placeholder,default,tooltip)
    local lr=N("Frame",{Size=UDim2.new(1,0,0,13),BackgroundTransparency=1,ZIndex=5},parent); N("UIPadding",{PaddingLeft=UDim.new(0,4)},lr)
    local lblEl=N("TextLabel",{Text=label,BackgroundTransparency=1,Font=T.Font,TextColor3=T.FontC,TextSize=12,TextXAlignment=Enum.TextXAlignment.Left,Size=UDim2.new(1,0,1,0),ZIndex=6},lr)
    if tooltip then SetTooltip(lblEl,tooltip) end
    EBlank(parent,1)
    local br=N("Frame",{Size=UDim2.new(1,0,0,19),BackgroundTransparency=1,ZIndex=5},parent); N("UIPadding",{PaddingLeft=UDim.new(0,4),PaddingRight=UDim.new(0,4)},br)
    local outer=N("Frame",{BackgroundColor3=T.Black,BorderSizePixel=0,Size=UDim2.new(1,0,1,0),ZIndex=6},br); Cr(outer,2)
    local inner=N("Frame",{BackgroundColor3=T.Main,BorderColor3=T.Outline,BorderMode=Enum.BorderMode.Inset,Size=UDim2.new(1,0,1,0),ZIndex=7},outer); Cr(inner,2); Grad(inner)
    local inStk=StC(outer,T.Accent,1); inStk.Transparency=1
    local clip=N("Frame",{BackgroundTransparency=1,ClipsDescendants=true,Position=UDim2.fromOffset(4,0),Size=UDim2.new(1,-4,1,0),ZIndex=8},inner)
    local box=N("TextBox",{BackgroundTransparency=1,Text=default or "",PlaceholderText=placeholder or "",PlaceholderColor3=Color3.fromRGB(72,72,88),Font=T.Font,TextColor3=T.FontC,TextSize=12,TextXAlignment=Enum.TextXAlignment.Left,Size=UDim2.fromScale(5,1),ZIndex=8},clip)
    inner.MouseEnter:Connect(function() Tw(inStk,0.1,{Transparency=0}) end)
    inner.MouseLeave:Connect(function() if not box:IsFocused() then Tw(inStk,0.1,{Transparency=1}) end end)
    box.FocusLost:Connect(function() Tw(inStk,0.1,{Transparency=1}) end)
    inner.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then box:CaptureFocus() end end)
    local cbs={}
    local obj={Value=default or "",Type="Input",
        SetValue=function(self,v) self.Value=v; box.Text=v; if idx then print("[input] "..idx.." = "..tostring(v)) end; for _,cb in ipairs(cbs) do cb(v) end end,
        OnChanged=function(self,cb) table.insert(cbs,cb); cb(self.Value) end,
    }
    box:GetPropertyChangedSignal("Text"):Connect(function() obj.Value=box.Text; for _,cb in ipairs(cbs) do cb(box.Text) end end)
    if idx then Options[idx]=obj end; EBlank(parent,4); return obj
end

local function EKeyPicker(parent,toggleObj,label,idx,default,noKB)
    local ac=toggleObj and toggleObj.AddonContainer; if not ac then return end
    local outer=N("Frame",{BackgroundColor3=T.Black,BorderSizePixel=0,Size=UDim2.fromOffset(24,12),ZIndex=8,LayoutOrder=100},ac); Cr(outer,99)
    local inner=N("Frame",{BackgroundColor3=T.Bg,BorderColor3=T.Outline,BorderMode=Enum.BorderMode.Inset,Size=UDim2.new(1,0,1,0),ZIndex=9},outer); Cr(inner,99)
    local disp=N("TextLabel",{Text=default or "?",BackgroundTransparency=1,Font=T.Font,TextColor3=T.FontC,TextSize=10,ZIndex=10,Size=UDim2.new(1,0,1,0),TextXAlignment=Enum.TextXAlignment.Center},inner)
    local kStk=StC(outer,T.Accent,1); kStk.Transparency=1
    local hit=N("TextButton",{Text="",BackgroundTransparency=1,Size=UDim2.new(1,0,1,0),ZIndex=11},outer)
    hit.MouseEnter:Connect(function() Tw(kStk,0.1,{Transparency=0}) end)
    hit.MouseLeave:Connect(function() Tw(kStk,0.1,{Transparency=1}) end)
    local MODES={"Always","Toggle","Hold"}
    local mPop=N("Frame",{BackgroundColor3=T.Black,BorderSizePixel=0,Size=UDim2.fromOffset(56,46),Visible=false,ZIndex=200},Gui)
    local mI=N("Frame",{BackgroundColor3=T.Main,BorderColor3=T.Outline,BorderMode=Enum.BorderMode.Inset,Size=UDim2.new(1,0,1,0),ZIndex=201},mPop); Cr(mI,3)
    N("UIListLayout",{FillDirection=Enum.FillDirection.Vertical,SortOrder=Enum.SortOrder.LayoutOrder},mI)
    N("UIPadding",{PaddingLeft=UDim.new(0,4),PaddingTop=UDim.new(0,2)},mI)
    local function RefMPos() local ap=outer.AbsolutePosition; mPop.Position=UDim2.fromOffset(ap.X+outer.AbsoluteSize.X+2,ap.Y) end
    outer:GetPropertyChangedSignal("AbsolutePosition"):Connect(RefMPos); task.spawn(RefMPos)
    local curMode="Toggle"
    for _,mode in ipairs(MODES) do
        local ml=N("TextLabel",{Text=mode,BackgroundTransparency=1,Font=T.Font,Active=true,TextColor3=mode==curMode and T.Accent or T.Dim,TextSize=11,Size=UDim2.new(1,0,0,14),ZIndex=202},mI)
        ml.InputBegan:Connect(function(i)
            if i.UserInputType~=Enum.UserInputType.MouseButton1 and i.UserInputType~=Enum.UserInputType.Touch then return end
            curMode=mode; for _,c in ipairs(mI:GetChildren()) do if c:IsA("TextLabel") then c.TextColor3=c.Text==mode and T.Accent or T.Dim end end
            mPop.Visible=false
        end)
    end
    local picking=false; local cbs={}; local curKey=default or "None"
    local obj={Value=curKey,Mode=curMode,Type="KeyPicker",Toggled=toggleObj and toggleObj.Value or false,
        GetState=function(self)
            if self.Mode=="Always" then return true
            elseif self.Mode=="Hold" then
                local k=self.Value; if k=="None" then return false end
                if k=="MB1" then return UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
                elseif k=="MB2" then return UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
                else local ok,kc=pcall(function() return Enum.KeyCode[k] end); return ok and UIS:IsKeyDown(kc) end
            else return self.Toggled end end,
        Update=function(self)
            if idx and not noKB then
                if self.Value=="None" then kbEntries[idx]=nil
                else kbEntries[idx]={Label=label or idx,Key=self.Value,ToggleRef=toggleObj} end
                RefKB() end end,
        SetValue=function(self,data)
            if type(data)=="table" then self.Value=data[1]; self.Mode=data[2] or "Toggle" else self.Value=tostring(data) end
            if self.Value=="Backspace" then self.Value="None" end
            curKey=self.Value; disp.Text=curKey~="None" and curKey or "?"
            self:Update(); for _,cb in ipairs(cbs) do cb(self.Value) end end,
        OnChanged=function(self,cb) table.insert(cbs,cb); cb(self.Value) end,
    }
    if idx and curKey~="None" and not noKB then kbEntries[idx]={Label=label or idx,Key=curKey,ToggleRef=toggleObj}; RefKB() end
    if idx then Options[idx]=obj end
    hit.MouseButton1Click:Connect(function()
        if picking then return end; mPop.Visible=false
        task.spawn(function()
            picking=true; disp.Text="·"; task.wait(0.1)
            local br=false; local con; con=UIS.InputBegan:Connect(function(inp)
                if br then return end; local k
                if inp.UserInputType==Enum.UserInputType.Keyboard then k=inp.KeyCode.Name
                elseif inp.UserInputType==Enum.UserInputType.MouseButton1 then k="MB1"
                elseif inp.UserInputType==Enum.UserInputType.MouseButton2 then k="MB2" end
                if k then br=true; picking=false; obj:SetValue(k); con:Disconnect() end
            end)
        end)
    end)
    hit.MouseButton2Click:Connect(function() RefMPos(); mPop.Visible=not mPop.Visible end)
    do local touchT=0
        hit.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.Touch then touchT=os.clock() end end)
        hit.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.Touch and os.clock()-touchT>=0.4 then RefMPos(); mPop.Visible=not mPop.Visible end end)
    end
    UIS.InputBegan:Connect(function(i)
        if picking then return end
        if obj.Mode=="Toggle" then
            local k=obj.Value
            if (k=="MB1" and i.UserInputType==Enum.UserInputType.MouseButton1)
            or (k=="MB2" and i.UserInputType==Enum.UserInputType.MouseButton2)
            or (i.UserInputType==Enum.UserInputType.Keyboard and i.KeyCode.Name==k) then
                if toggleObj then toggleObj:SetValue(not toggleObj.Value); obj.Toggled=toggleObj.Value
                else obj.Toggled=not obj.Toggled end
                obj:Update()
            end
        end
        if i.UserInputType==Enum.UserInputType.MouseButton1 and mPop.Visible then
            local mx2,my2=i.Position.X,i.Position.Y; local mp,ms=mPop.AbsolutePosition,mPop.AbsoluteSize
            if mx2<mp.X or mx2>mp.X+ms.X or my2<mp.Y or my2>mp.Y+ms.Y then mPop.Visible=false end
        end
    end)
    if toggleObj then toggleObj:OnChanged(function(v) obj.Toggled=v; RefKB() end) end
    return obj
end

local function EColorPicker(parent,toggleObj,label,idx,default)
    default=default or T.Accent
    local ac=toggleObj and toggleObj.AddonContainer; if not ac then return end
    local dOuter=N("Frame",{BackgroundColor3=T.Black,BorderSizePixel=0,Size=UDim2.fromOffset(20,12),ZIndex=8,LayoutOrder=80},ac); Cr(dOuter,2)
    local swatchChecker=N("ImageLabel",{BackgroundTransparency=1,Size=UDim2.new(1,0,1,0),Image="rbxassetid://4155801252",ZIndex=9,ScaleType=Enum.ScaleType.Tile,TileSize=UDim2.fromOffset(6,6)},dOuter); Cr(swatchChecker,2)
    local disp=N("Frame",{BackgroundColor3=default,BorderSizePixel=0,Size=UDim2.new(1,0,1,0),ZIndex=10,BackgroundTransparency=0},dOuter); Cr(disp,2)
    local cpHit=N("TextButton",{Text="",BackgroundTransparency=1,Size=UDim2.new(1,0,1,0),ZIndex=11},dOuter)
    local cpStk=StC(dOuter,T.Accent,1); cpStk.Transparency=1
    cpHit.MouseEnter:Connect(function() Tw(cpStk,0.1,{Transparency=0}) end)
    cpHit.MouseLeave:Connect(function() Tw(cpStk,0.1,{Transparency=1}) end)
    local curH,curS,curV=Color3.toHSV(default); local curT=0; local cbs={}
    local obj={Value=default,Transparency=0,Type="ColorPicker",
        SetValueRGB=function(self,col,t) self.Value=col; self.Transparency=t or 0; curH,curS,curV=Color3.toHSV(col); curT=t or 0
            disp.BackgroundColor3=col; disp.BackgroundTransparency=curT
            for _,cb in ipairs(cbs) do cb(col) end end,
        OnChanged=function(self,cb) table.insert(cbs,cb); cb(self.Value) end,
    }
    if idx then Options[idx]=obj end
    cpHit.MouseButton1Click:Connect(function()
        ClosePopup()
        local ap=dOuter.AbsolutePosition; local pw=228; local ph=296
        local px=math.max(4, ap.X-pw-20); local py=math.max(4, math.min(ap.Y, Gui.AbsoluteSize.Y-ph-4))
        local pick=N("Frame",{BackgroundColor3=T.Bg,Size=UDim2.fromOffset(pw,ph),Position=UDim2.fromOffset(px,py),ZIndex=200},Gui)
        Cr(pick,4); StC(pick,T.Accent,1); activePopup=pick
        N("Frame",{BackgroundColor3=T.Accent,BorderSizePixel=0,Size=UDim2.new(1,0,0,2),ZIndex=201},pick)
        N("TextLabel",{Text=label,BackgroundTransparency=1,Font=T.Font,TextColor3=T.FontC,TextSize=12,TextXAlignment=Enum.TextXAlignment.Left,Size=UDim2.new(1,0,0,16),Position=UDim2.fromOffset(5,3),ZIndex=201},pick)
        local svO=N("Frame",{BackgroundColor3=T.Black,BorderSizePixel=0,Size=UDim2.fromOffset(198,190),Position=UDim2.fromOffset(4,22),ZIndex=201},pick)
        local svI=N("Frame",{BackgroundColor3=Color3.fromHSV(curH,1,1),BorderColor3=T.Outline,BorderMode=Enum.BorderMode.Inset,Size=UDim2.new(1,0,1,0),ZIndex=202},svO)
        local svImg=N("ImageLabel",{BackgroundTransparency=1,Size=UDim2.new(1,0,1,0),Image="rbxassetid://4155801252",ZIndex=203},svI)
        local cur=N("ImageLabel",{AnchorPoint=Vector2.new(0.5,0.5),Size=UDim2.fromOffset(6,6),BackgroundTransparency=1,Image="rbxassetid://9619665977",ImageColor3=T.Black,ZIndex=204},svImg)
        N("ImageLabel",{Size=UDim2.fromOffset(4,4),Position=UDim2.fromOffset(1,1),BackgroundTransparency=1,Image="rbxassetid://9619665977",ZIndex=205},cur)
        local hO=N("Frame",{BackgroundColor3=T.Black,BorderSizePixel=0,Size=UDim2.fromOffset(14,190),Position=UDim2.fromOffset(206,22),ZIndex=201},pick)
        local hI=N("Frame",{BackgroundColor3=Color3.new(1,1,1),BorderSizePixel=0,Size=UDim2.new(1,0,1,0),ZIndex=202},hO)
        local hSeq={}; for hv=0,1,0.1 do table.insert(hSeq,ColorSequenceKeypoint.new(hv,Color3.fromHSV(hv,1,1))) end
        N("UIGradient",{Color=ColorSequence.new(hSeq),Rotation=90},hI)
        local hCur=N("Frame",{BackgroundColor3=Color3.new(1,1,1),AnchorPoint=Vector2.new(0,0.5),BorderColor3=T.Black,BorderSizePixel=1,Size=UDim2.new(1,0,0,1),ZIndex=203},hI)
        local hxO=N("Frame",{BackgroundColor3=T.Black,BorderSizePixel=0,Size=UDim2.fromOffset(220,18),Position=UDim2.fromOffset(4,216),ZIndex=201},pick)
        local hxI=N("Frame",{BackgroundColor3=T.Main,BorderColor3=T.Outline,BorderMode=Enum.BorderMode.Inset,Size=UDim2.new(1,0,1,0),ZIndex=202},hxO); Grad(hxI)
        local hxB=N("TextBox",{BackgroundTransparency=1,Text="#"..obj.Value:ToHex(),Font=T.Font,TextColor3=T.FontC,TextSize=12,PlaceholderColor3=T.Dim,TextXAlignment=Enum.TextXAlignment.Left,Size=UDim2.new(1,-5,1,0),Position=UDim2.fromOffset(4,0),ZIndex=203},hxI)
        N("TextLabel",{Text="transparency",BackgroundTransparency=1,Font=T.Font,TextColor3=T.Dim,TextSize=10,TextXAlignment=Enum.TextXAlignment.Left,Size=UDim2.fromOffset(100,11),Position=UDim2.fromOffset(4,238),ZIndex=201},pick)
        local tBarO=N("Frame",{BackgroundColor3=T.Black,BorderSizePixel=0,Size=UDim2.fromOffset(220,12),Position=UDim2.fromOffset(4,251),ZIndex=201},pick); Cr(tBarO,3)
        local tCheck=N("ImageLabel",{BackgroundTransparency=1,Size=UDim2.new(1,0,1,0),Image="rbxassetid://4155801252",ZIndex=202,ScaleType=Enum.ScaleType.Tile,TileSize=UDim2.fromOffset(8,8)},tBarO); Cr(tCheck,3)
        local tFill=N("Frame",{BackgroundColor3=obj.Value,BorderSizePixel=0,Size=UDim2.new(1,0,1,0),ZIndex=203},tBarO); Cr(tFill,3)
        N("UIGradient",{Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0),NumberSequenceKeypoint.new(1,1)}),Rotation=0},tFill)
        local tCur=N("Frame",{BackgroundColor3=Color3.new(1,1,1),AnchorPoint=Vector2.new(0.5,0),BorderColor3=T.Black,BorderSizePixel=1,Size=UDim2.new(0,1,1,0),Position=UDim2.new(curT,0,0,0),ZIndex=205},tCheck)
        local tHit=N("TextButton",{Text="",BackgroundTransparency=1,Size=UDim2.new(1,0,1,0),ZIndex=206},tBarO)
        local function DP()
            local col=Color3.fromHSV(curH,curS,curV); obj:SetValueRGB(col,curT)
            svI.BackgroundColor3=Color3.fromHSV(curH,1,1); cur.Position=UDim2.new(curS,0,1-curV,0)
            hCur.Position=UDim2.new(0,0,curH,0); hxB.Text="#"..col:ToHex()
            tFill.BackgroundColor3=col; tCur.Position=UDim2.new(curT,0,0,0)
        end; DP()
        hxB.FocusLost:Connect(function()
            local ok,c=pcall(Color3.fromHex,hxB.Text:gsub("^#",""))
            if ok then curH,curS,curV=Color3.toHSV(c); DP() end
        end)
        MakeDragXY(svImg,
            function(x) local a2,s2=svImg.AbsolutePosition,svImg.AbsoluteSize; if s2.X>0 then curS=math.clamp((x-a2.X)/s2.X,0,1); DP() end end,
            function(y) local a2,s2=svImg.AbsolutePosition,svImg.AbsoluteSize; if s2.Y>0 then curV=1-math.clamp((y-a2.Y)/s2.Y,0,1); DP() end end)
        MakeDragY(hI,function(y) local a2,s2=hI.AbsolutePosition,hI.AbsoluteSize; if s2.Y>0 then curH=math.clamp((y-a2.Y)/s2.Y,0,1); DP() end end)
        MakeDragX(tHit,function(x) local a2,s2=tBarO.AbsolutePosition,tBarO.AbsoluteSize; if s2.X>0 then curT=math.clamp((x-a2.X)/s2.X,0,1); DP() end end)
        local con2; con2=UIS.InputBegan:Connect(function(inp)
            if inp.UserInputType==Enum.UserInputType.MouseButton1 or inp.UserInputType==Enum.UserInputType.Touch then
                local px2,py2=inp.Position.X,inp.Position.Y; local pp,ps=pick.AbsolutePosition,pick.AbsoluteSize
                if px2<pp.X or px2>pp.X+ps.X or py2<pp.Y or py2>pp.Y+ps.Y then
                    if pick.Parent then pick:Destroy() end; activePopup=nil; con2:Disconnect() end
            end
        end)
    end)
    return obj
end

-- EButton(parent, text, func, tooltip?)
local function EButton(parent,text,func,tooltip)
    local row=N("Frame",{Size=UDim2.new(1,0,0,20),BackgroundTransparency=1,ZIndex=5},parent)
    N("UIPadding",{PaddingLeft=UDim.new(0,4),PaddingRight=UDim.new(0,4)},row)
    local outer=N("Frame",{BackgroundColor3=T.Black,BorderSizePixel=0,Size=UDim2.new(1,0,1,0),ZIndex=6},row); Cr(outer,2)
    local inner=N("Frame",{BackgroundColor3=T.Main,BorderColor3=T.Outline,BorderMode=Enum.BorderMode.Inset,Size=UDim2.new(1,0,1,0),ZIndex=7},outer); Cr(inner,2); Grad(inner)
    N("TextLabel",{Text=text,BackgroundTransparency=1,Font=T.Font,TextColor3=T.FontC,TextSize=12,Size=UDim2.new(1,0,1,0),ZIndex=8},inner)
    local bHit=N("TextButton",{Text="",BackgroundTransparency=1,Size=UDim2.new(1,0,1,0),ZIndex=9},inner)
    local bStk=StC(outer,T.Accent,1); bStk.Transparency=1
    bHit.MouseEnter:Connect(function() Tw(bStk,0.1,{Transparency=0}) end)
    bHit.MouseLeave:Connect(function() Tw(bStk,0.1,{Transparency=1}) end)
    bHit.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.Touch then Tw(bStk,0.1,{Transparency=0}) end end)
    bHit.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.Touch then Tw(bStk,0.1,{Transparency=1}) end end)
    if tooltip then SetTooltip(bHit,tooltip) end
    bHit.MouseButton1Click:Connect(function()
        print("[button] "..text); pcall(func)
        Tw(inner,0.05,{BackgroundColor3=T.Accent}); task.delay(0.1,function() if inner.Parent then Tw(inner,0.1,{BackgroundColor3=T.Main}) end end)
    end)
    EBlank(parent,4)
end

-- ELabel(parent, text, wrap, tooltip?)
local function ELabel(parent,text,wrap,tooltip)
    local row=N("Frame",{Size=UDim2.new(1,0,0,wrap and 26 or 14),BackgroundTransparency=1,ZIndex=5},parent)
    N("UIPadding",{PaddingLeft=UDim.new(0,4)},row)
    local l=N("TextLabel",{Text=text,RichText=true,BackgroundTransparency=1,Font=T.Font,TextColor3=T.Dim,TextSize=12,TextXAlignment=Enum.TextXAlignment.Left,TextWrapped=wrap or false,Size=UDim2.new(1,-4,1,0),ZIndex=6},row)
    if tooltip then SetTooltip(l,tooltip) end
    EBlank(parent,3); return l
end

local function EDivider(parent)
    EBlank(parent,3)
    local row=N("Frame",{Size=UDim2.new(1,0,0,5),BackgroundTransparency=1,ZIndex=5},parent)
    N("UIPadding",{PaddingLeft=UDim.new(0,4),PaddingRight=UDim.new(0,4)},row)
    local o=N("Frame",{BackgroundColor3=T.Black,BorderSizePixel=0,Size=UDim2.new(1,0,1,0),ZIndex=6},row); Cr(o,2)
    N("Frame",{BackgroundColor3=T.Main,BorderColor3=T.Outline,BorderMode=Enum.BorderMode.Inset,Size=UDim2.new(1,0,1,0),ZIndex=7},o); Grad(o)
    EBlank(parent,5)
end

----------------------------------------------------------------------  Tabbed Groupbox
local function MakeTabbedGroupbox(sideFrame,name)
    local gbox=N("Frame",{BackgroundColor3=T.Bg,BorderSizePixel=0,Size=UDim2.new(1,0,0,0),ZIndex=3},sideFrame)
    StC(gbox,T.Outline,1); Cr(gbox,3)
    local inner=N("Frame",{BackgroundColor3=T.Bg,BorderSizePixel=0,Size=UDim2.new(1,-2,1,-2),Position=UDim2.fromOffset(1,1),ZIndex=4},gbox); Cr(inner,3)
    local header=N("Frame",{BackgroundColor3=T.Main,BorderSizePixel=0,Size=UDim2.new(1,0,0,26),ZIndex=5},inner)
    N("Frame",{BackgroundColor3=T.Accent,BorderSizePixel=0,Size=UDim2.new(1,0,0,2),ZIndex=6},header)
    if name and name~="" then N("TextLabel",{Text=name,BackgroundTransparency=1,Font=T.Font,TextColor3=T.FontC,TextSize=13,TextXAlignment=Enum.TextXAlignment.Left,Size=UDim2.new(0.45,0,1,0),Position=UDim2.fromOffset(5,0),ZIndex=6},header) end
    local tabBarX=name and name~="" and 0.45 or 0
    local tabBar=N("Frame",{BackgroundTransparency=1,BorderSizePixel=0,Size=UDim2.new(1-tabBarX,-4,1,-4),Position=UDim2.new(tabBarX,0,0,2),ZIndex=6},header)
    N("UIListLayout",{FillDirection=Enum.FillDirection.Horizontal,SortOrder=Enum.SortOrder.LayoutOrder,HorizontalAlignment=Enum.HorizontalAlignment.Right,VerticalAlignment=Enum.VerticalAlignment.Center,Padding=UDim.new(0,2)},tabBar)
    local host=N("Frame",{BackgroundTransparency=1,BorderSizePixel=0,Size=UDim2.new(1,0,1,-26),Position=UDim2.fromOffset(0,26),ZIndex=5},inner)
    local tabs={}; local tabBtns={}; local activeInner=nil
    local function ShowInner(tname)
        for n,sf in pairs(tabs) do sf.Visible=n==tname end
        for n,ref in pairs(tabBtns) do ref.lbl.TextColor3=n==tname and T.FontC or T.Dim; ref.stk.Transparency=n==tname and 0 or 1 end
        activeInner=tname
    end
    local function Resize()
        local maxH=0; for _,sf in pairs(tabs) do if sf.Visible then maxH=sf.CanvasSize.Y.Offset end end
        inner.Size=UDim2.new(1,-2,0,26+maxH); gbox.Size=UDim2.new(1,0,0,26+maxH+2); host.Size=UDim2.new(1,0,0,maxH)
    end
    local gb={}
    function gb:AddTab(tname)
        local W=TxtSvc:GetTextSize(tname,11,T.Font,Vector2.new(9999,9999)).X+10
        local btn=N("Frame",{BackgroundColor3=T.TabBg,BorderSizePixel=0,Size=UDim2.fromOffset(W,18),ZIndex=7},tabBar); Cr(btn,3)
        local lbl=N("TextLabel",{Text=tname,BackgroundTransparency=1,Font=T.Font,TextColor3=T.Dim,TextSize=11,Size=UDim2.new(1,0,1,0),ZIndex=8},btn)
        local stk=StC(btn,T.Accent,1); stk.Transparency=1
        local hb=N("TextButton",{Text="",BackgroundTransparency=1,Size=UDim2.new(1,0,1,0),ZIndex=9},btn)
        tabBtns[tname]={btn=btn,lbl=lbl,stk=stk}
        local sf=N("ScrollingFrame",{BackgroundTransparency=1,BorderSizePixel=0,Size=UDim2.new(1,0,1,0),CanvasSize=UDim2.new(0,0,0,0),ScrollBarThickness=3,ScrollBarImageColor3=T.Accent,ZIndex=6,Visible=false,ElasticBehavior=Enum.ElasticBehavior.Never},host)
        local layout=N("UIListLayout",{Padding=UDim.new(0,0),FillDirection=Enum.FillDirection.Vertical,SortOrder=Enum.SortOrder.LayoutOrder},sf)
        N("UIPadding",{PaddingTop=UDim.new(0,3),PaddingBottom=UDim.new(0,4)},sf)
        layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            local h2=layout.AbsoluteContentSize.Y+7; sf.CanvasSize=UDim2.fromOffset(0,h2)
            if sf.Visible then Resize() end
        end)
        hb.MouseButton1Click:Connect(function() ShowInner(tname); Resize() end)
        hb.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.Touch then ShowInner(tname); Resize() end end)
        tabs[tname]=sf; if not activeInner then ShowInner(tname); task.defer(Resize) end; return sf
    end
    return gb
end

----------------------------------------------------------------------  Plain Groupbox
local function MakeGroupbox(sideFrame,name)
    local gbox=N("Frame",{BackgroundColor3=T.Bg,BorderSizePixel=0,Size=UDim2.new(1,0,0,0),ZIndex=3},sideFrame)
    StC(gbox,T.Outline,1); Cr(gbox,3)
    local inner=N("Frame",{BackgroundColor3=T.Bg,BorderSizePixel=0,Size=UDim2.new(1,-2,1,-2),Position=UDim2.fromOffset(1,1),ZIndex=4},gbox); Cr(inner,3)
    N("Frame",{BackgroundColor3=T.Accent,BorderSizePixel=0,Size=UDim2.new(1,0,0,2),ZIndex=5},inner)
    N("TextLabel",{Text=name,BackgroundTransparency=1,Font=T.Font,TextColor3=T.FontC,TextSize=13,TextXAlignment=Enum.TextXAlignment.Left,Size=UDim2.new(1,-8,0,17),Position=UDim2.fromOffset(5,2),ZIndex=5},inner)
    local scroll=N("ScrollingFrame",{BackgroundTransparency=1,BorderSizePixel=0,Size=UDim2.new(1,-2,1,-21),Position=UDim2.fromOffset(1,21),CanvasSize=UDim2.new(0,0,0,0),ScrollBarThickness=3,ScrollBarImageColor3=T.Accent,ZIndex=5,ElasticBehavior=Enum.ElasticBehavior.Never},inner)
    local layout=N("UIListLayout",{Padding=UDim.new(0,0),FillDirection=Enum.FillDirection.Vertical,SortOrder=Enum.SortOrder.LayoutOrder},scroll)
    N("UIPadding",{PaddingTop=UDim.new(0,3),PaddingBottom=UDim.new(0,4)},scroll)
    local function Resize()
        local h=layout.AbsoluteContentSize.Y+7; scroll.CanvasSize=UDim2.fromOffset(0,h)
        inner.Size=UDim2.new(1,-2,0,21+h); gbox.Size=UDim2.new(1,0,0,21+h+2)
    end
    layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(Resize); task.defer(Resize)
    return scroll
end

----------------------------------------------------------------------  Tab system
local TABS={"aimbot","visuals","misc","exploits","leaderboard","settings"}
local tabFrames={}; local activeTabName=""

local function NewTab(tname)
    local frame=N("Frame",{Name=tname,BackgroundTransparency=1,Size=UDim2.new(1,0,1,0),Visible=false,ZIndex=3},TabContainer)
    local left=N("ScrollingFrame",{BackgroundTransparency=1,BorderSizePixel=0,Position=UDim2.fromOffset(5,5),Size=UDim2.new(0.5,-9,1,-10),CanvasSize=UDim2.new(0,0,0,0),ScrollBarThickness=0,BottomImage="",TopImage="",ZIndex=3},frame)
    local right=N("ScrollingFrame",{BackgroundTransparency=1,BorderSizePixel=0,Position=UDim2.new(0.5,4,0,5),Size=UDim2.new(0.5,-9,1,-10),CanvasSize=UDim2.new(0,0,0,0),ScrollBarThickness=0,BottomImage="",TopImage="",ZIndex=3},frame)
    for _,side in ipairs({left,right}) do
        local ll=N("UIListLayout",{Padding=UDim.new(0,5),FillDirection=Enum.FillDirection.Vertical,SortOrder=Enum.SortOrder.LayoutOrder,HorizontalAlignment=Enum.HorizontalAlignment.Center},side)
        ll:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() side.CanvasSize=UDim2.fromOffset(0,ll.AbsoluteContentSize.Y+8) end)
    end
    local tab={Frame=frame,_left=left,_right=right}
    function tab:AddLeftGroupbox(n2)  return MakeGroupbox(left,n2) end
    function tab:AddRightGroupbox(n2) return MakeGroupbox(right,n2) end
    function tab:AddLeftTabbox(n2)    return MakeTabbedGroupbox(left,n2 or "") end
    function tab:AddRightTabbox(n2)   return MakeTabbedGroupbox(right,n2 or "") end
    function tab:GetFullFrame()
        return N("Frame",{BackgroundTransparency=1,Size=UDim2.new(1,0,1,0),ZIndex=3},frame)
    end
    setmetatable(tab,{
        __index=function(_,k) return frame[k] end,
        __newindex=function(_,k,v) local ok=pcall(function() frame[k]=v end); if not ok then rawset(tab,k,v) end end,
    })
    return tab
end

local function ShowTab(n)
    if tabFrames[activeTabName] then tabFrames[activeTabName].Frame.Visible=false end
    activeTabName=n
    if tabFrames[n] then tabFrames[n].Frame.Visible=true end
end

for _,n in ipairs(TABS) do tabFrames[n]=NewTab(n) end

local tabBtnRefs={}; local tabX=6
for i,tname in ipairs(TABS) do
    local isFirst=i==1
    local W=TxtSvc:GetTextSize(tname,12,T.Font,Vector2.new(9999,9999)).X+14
    local btn=N("Frame",{BackgroundColor3=Color3.fromRGB(0,0,0),BackgroundTransparency=1,BorderSizePixel=0,Size=UDim2.fromOffset(W,TABH-4),Position=UDim2.fromOffset(tabX,tabAreaY+3),ZIndex=5},Win); Cr(btn,4)
    local bStk=StC(btn,T.Accent,1); bStk.Transparency=isFirst and 0 or 1
    local lbl=N("TextLabel",{Text=tname,BackgroundTransparency=1,Font=T.Font,TextColor3=isFirst and T.FontC or T.Dim,TextSize=12,Size=UDim2.new(1,0,1,0),ZIndex=6},btn)
    local hb=N("TextButton",{Text="",BackgroundTransparency=1,Size=UDim2.new(1,0,1,0),ZIndex=8},btn)
    hb.MouseEnter:Connect(function() if tname~=activeTabName then lbl.TextColor3=T.FontC end end)
    hb.MouseLeave:Connect(function() if tname~=activeTabName then lbl.TextColor3=T.Dim end end)
    hb.MouseButton1Click:Connect(function()
        for _,ref in pairs(tabBtnRefs) do ref.stroke.Transparency=1; ref.lbl.TextColor3=T.Dim end
        bStk.Transparency=0; lbl.TextColor3=T.FontC; ShowTab(tname)
    end)
    hb.InputBegan:Connect(function(inp)
        if inp.UserInputType==Enum.UserInputType.Touch then
            for _,ref in pairs(tabBtnRefs) do ref.stroke.Transparency=1; ref.lbl.TextColor3=T.Dim end
            bStk.Transparency=0; lbl.TextColor3=T.FontC; ShowTab(tname)
        end
    end)
    tabBtnRefs[tname]={stroke=bStk,lbl=lbl}; tabX=tabX+W+4
end
ShowTab(TABS[1])

----------------------------------------------------------------------  Config persistence
local function SaveCfg(name)
    if not name or name:gsub(" ","")=="" then Notify("enter a config name"); return end
    local data={objects={}}
    for idx,t2 in pairs(Toggles) do table.insert(data.objects,{type="Toggle",idx=idx,value=t2.Value}) end
    for idx,o in pairs(Options) do
        if o.Type=="Slider" or o.Type=="Input" then table.insert(data.objects,{type=o.Type,idx=idx,value=o.Value})
        elseif o.Type=="Dropdown" then table.insert(data.objects,{type="Dropdown",idx=idx,value=o.Value,multi=o.Multi})
        elseif o.Type=="KeyPicker" then table.insert(data.objects,{type="KeyPicker",idx=idx,key=o.Value,mode=o.Mode}) end
    end
    local ok,enc=pcall(function() return Http:JSONEncode(data) end)
    if ok then pcall(function() writefile("LB/settings/"..name..".json",enc) end); Notify('saved "'..name..'"') end
end
local function LoadCfg(name)
    if not name or name=="" then Notify("select a config first"); return end
    local content; local ok=pcall(function() content=readfile("LB/settings/"..name..".json") end)
    if not ok or not content then Notify("failed to load"); return end
    local ok2,data=pcall(function() return Http:JSONDecode(content) end)
    if not ok2 then return end
    for _,obj in ipairs(data.objects or {}) do task.spawn(function()
        if obj.type=="Toggle" and Toggles[obj.idx] then Toggles[obj.idx]:SetValue(obj.value)
        elseif obj.type=="KeyPicker" and Options[obj.idx] then Options[obj.idx]:SetValue({obj.key,obj.mode})
        elseif Options[obj.idx] then Options[obj.idx]:SetValue(obj.value) end
    end) end
    Notify('loaded "'..name..'"')
end

----------------------------------------------------------------------  CONTENT — AIMBOT

do
    local tf=tabFrames["aimbot"]

    -- LEFT: Weapon profile tabbox
    local PTB=tf:AddLeftTabbox("weapon profiles")

    local function MakeSABlock(tab,wtype)
        EToggle(tab,"silent aim","SA_Enabled_"..wtype,false)
        EToggle(tab,"auto shoot","SA_AutoShoot_"..wtype,false)
        EToggle(tab,"ignore invisible","SA_IgnoreInvis_"..wtype,true)
        ESlider(tab,"fov radius","SA_FOV_"..wtype,10,800,200)
        EToggle(tab,"show fov circle","SA_FOVCircle_"..wtype,true)
        EDropdown(tab,"sort mode","SA_Sort_"..wtype,{"Closest to Mouse","Closest Distance"},"Closest to Mouse")
        EDropdown(tab,"aim at","SA_Targets_"..wtype,{"Players","Sentry","Stickybomb"},nil,true)
        Options["SA_Targets_"..wtype]:SetValue({Players=true})
        EDropdown(tab,"body parts","SA_BodyParts_"..wtype,{"Head","Chest","Torso","Arms","Legs","Feet"},nil,true)
        Options["SA_BodyParts_"..wtype]:SetValue({Head=true})
    end
    local function MakeFireRateBlock(tab,wtype)
        local ftog=EToggle(tab,"fast gun","FastGun_"..wtype,false)
        ESlider(tab,"fire rate multiplier","FireRate_"..wtype,1,25,1,"x")
    end
    local function MakeDmgModBlock(tab,wtype)
        EToggle(tab,"damage mod","DmgMod_"..wtype,false,
            "subscribe to 1_aegis on yt.be")
        ESlider(tab,"dmg multiplier","DmgModMult_"..wtype,1,10,3,"x")
        EToggle(tab,"infinite damage","DmgModInf_"..wtype,false)
    end
    local function MakeInfAmmoBlock(tab,wtype)
        EToggle(tab,"inf use ammo","InfUse_"..wtype,false)
        EToggle(tab,"inf reserve ammo","InfRes_"..wtype,false)
    end

    local PT=PTB:AddTab("primary")
    MakeSABlock(PT,"Primary")
    EDivider(PT); MakeFireRateBlock(PT,"Primary")
    EDivider(PT)
    EToggle(PT,"wallbang","WallbangToggle_Primary",false,"tooltip test btw")
    EDivider(PT)
    EToggle(PT,"no spread","NoSpread_Primary",false)
    ESlider(PT,"spread mult","NoSpreadMult_Primary",0.2,1,0.2)
    EDivider(PT); MakeDmgModBlock(PT,"Primary"); EDivider(PT); MakeInfAmmoBlock(PT,"Primary")

    local HT=PTB:AddTab("secondary")
    MakeSABlock(HT,"Secondary")
    EDivider(HT); MakeFireRateBlock(HT,"Secondary")
    EDivider(HT)
    EToggle(HT,"wallbang","WallbangToggle_Secondary",false,"it does the thing where")
    EDivider(HT)
    EToggle(HT,"no spread","NoSpread_Secondary",false)
    ESlider(HT,"spread mult","NoSpreadMult_Secondary",0.2,1,0.2)
    EDivider(HT); MakeDmgModBlock(HT,"Secondary"); EDivider(HT); MakeInfAmmoBlock(HT,"Secondary")

    local MT=PTB:AddTab("melee")
    MakeSABlock(MT,"Melee")
    EDivider(MT); MakeFireRateBlock(MT,"Melee")
    EDivider(MT); MakeDmgModBlock(MT,"Melee")
    EDivider(MT)
    EToggle(MT,"infinite range","MaxRangeToggle",false,"range: gazillion billion ")
    EToggle(MT,"auto backstab","AutoBackstab",false)
    EToggle(MT,"backstab ignore invis","BackstabIgnoreInvis",true)
    EToggle(MT,"auto warp behind","AutoWarp",false)
    local tWarpDummy=EToggle(MT,"warp key","_WarpKeyDummy",false)
    EKeyPicker(MT,tWarpDummy,"warp","WarpKey","None")
    EDivider(MT)
    EToggle(MT,"auto melee","AutoMelee",false)
    EToggle(MT,"melee ignore invis","MeleeIgnoreInvis",true)
    EDropdown(MT,"melee mode","AutoMeleeMode",{"Rage","Demoknight"},"Rage")

    local ProjT=PTB:AddTab("projectile")
    MakeSABlock(ProjT,"Projectile")
    EDivider(ProjT); MakeFireRateBlock(ProjT,"Projectile")
    EDivider(ProjT); MakeInfAmmoBlock(ProjT,"Projectile")
    EDivider(ProjT)
    EToggle(ProjT,"prediction indicator","ShowPredictionIndicator",false)
    local tPIndDummy=EToggle(ProjT,"indicator color","_PIndColorDummy",false)
    EColorPicker(ProjT,tPIndDummy,"indicator color","PredictionIndicatorColor",Color3.new(0,1,1))

    -- RIGHT: Aim settings + FOV circle
    local FG=tf:AddRightGroupbox("aim settings")
    local tFOVDummy=EToggle(FG,"fov color","_FOVColorDummy",false)
    EColorPicker(FG,tFOVDummy,"fov color","FOVColor",Color3.new(1,1,1))
    EToggle(FG,"aim arms","SilentAimArms",false,"rotates viewmodel arms toward target")
    EDropdown(FG,"arms mode","SilentAimArmsMode",{"Snap","Smooth"},"Snap")
    EDivider(FG)
    ELabel(FG,"global aim key",false)
    local tGlobalDummy=EToggle(FG,"global aim key","_GlobalKeyDummy",false)
    EKeyPicker(FG,tGlobalDummy,"global aim","GlobalAimKey","None")
    EToggle(FG,"global always on","GlobalAimAlwaysOn",false)
end

----------------------------------------------------------------------  CONTENT — VISUALS

do
    local tf=tabFrames["visuals"]

    -- LEFT: player ESP + object ESP tabbox
    local ETB=tf:AddLeftTabbox("esp")

    local ESPT=ETB:AddTab("player esp")
    EToggle(ESPT,"enable esp","ESPEnabled",false)
    EToggle(ESPT,"show enemy","ESPEnemy",true)
    EToggle(ESPT,"show team","ESPTeam",false)
    EToggle(ESPT,"show friends","ESPFriends",true)
    EToggle(ESPT,"ignore invisible","ESPIgnoreInvis",true)
    EDivider(ESPT)
    EDropdown(ESPT,"box type","ESPBoxType",{"None","2D","3D","Corners"},"2D")
    local tBoxDummy=EToggle(ESPT,"box color","_BoxColorDummy",false)
    EColorPicker(ESPT,tBoxDummy,"box color","ESPBoxColor",Color3.new(1,0,0))
    ESlider(ESPT,"box thickness","ESPBoxThickness",1,4,1)
    EToggle(ESPT,"box fill","ESPBoxFill",false)
    local tFillDummy=EToggle(ESPT,"fill color","_FillColorDummy",false)
    EColorPicker(ESPT,tFillDummy,"fill color","ESPBoxFillColor",Color3.fromRGB(200,0,0))
    EDivider(ESPT)
    EToggle(ESPT,"distance","ESPDistance",false)
    EToggle(ESPT,"skeleton","ESPSkeleton",false)
    EToggle(ESPT,"weapon","ESPWeapon",false)
    EToggle(ESPT,"class","ESPClass",false)
    EToggle(ESPT,"status effects","ESPStatus",false,"shows letters according to the infliction :o")
    EDivider(ESPT)
    EToggle(ESPT,"health bar","ESPHealthBar",false)
    EToggle(ESPT,"health value","ESPHealthValue",false)
    EToggle(ESPT,"health %","ESPHealthPercent",false)
    EToggle(ESPT,"hp gradient","ESPHPGradient",true)
    EDropdown(ESPT,"bar side","ESPHPBarSide",{"Left","Right"},"Left")
    ESlider(ESPT,"bar width","ESPHPBarWidth",1,6,2)
    local tHPHighDummy=EToggle(ESPT,"hp full color","_HPHighDummy",false)
    EColorPicker(ESPT,tHPHighDummy,"hp full color","ESPHPColorHigh",Color3.fromRGB(0,220,80))
    local tHPLowDummy=EToggle(ESPT,"hp low color","_HPLowDummy",false)
    EColorPicker(ESPT,tHPLowDummy,"hp low color","ESPHPColorLow",Color3.fromRGB(220,40,40))
    local tHPBGDummy=EToggle(ESPT,"hp bg color","_HPBGDummy",false)
    EColorPicker(ESPT,tHPBGDummy,"hp bg color","ESPHPBGColor",Color3.fromRGB(20,20,20))
    EDivider(ESPT)
    EToggle(ESPT,"tracers","ESPTracer",false)
    local tTracerDummy=EToggle(ESPT,"tracer color","_TracerColorDummy",false)
    EColorPicker(ESPT,tTracerDummy,"tracer color","ESPTracerColor",Color3.new(1,0,0))
    EDropdown(ESPT,"tracer origin","ESPTracerOrigin",{"Bottom","Center","Top"},"Bottom")

    local ESPO=ETB:AddTab("object esp")
    EToggle(ESPO,"enable object esp","ObjESPEnabled",false)
    EDivider(ESPO)
    EToggle(ESPO,"enemy sentry","ObjESPEnemySentry",false)
    EToggle(ESPO,"enemy dispenser","ObjESPEnemyDispenser",false)
    EToggle(ESPO,"enemy teleporter","ObjESPEnemyTeleporter",false)
    EDivider(ESPO)
    EToggle(ESPO,"team sentry","ObjESPTeamSentry",false)
    EToggle(ESPO,"team dispenser","ObjESPTeamDispenser",false)
    EToggle(ESPO,"team teleporter","ObjESPTeamTeleporter",false)
    EDivider(ESPO)
    EToggle(ESPO,"ammo","ObjESPAmmo",false)
    EToggle(ESPO,"health packs","ObjESPHP",false)
    EDivider(ESPO)
    local tObjEDummy=EToggle(ESPO,"enemy color","_ObjEDummy",false)
    EColorPicker(ESPO,tObjEDummy,"enemy color","ObjESPEnemyColor",Color3.new(1,0.2,0.2))
    local tObjTDummy=EToggle(ESPO,"team color","_ObjTDummy",false)
    EColorPicker(ESPO,tObjTDummy,"team color","ObjESPTeamColor",Color3.new(0.2,0.6,1))
    local tObjPDummy=EToggle(ESPO,"pickup color","_ObjPDummy",false)
    EColorPicker(ESPO,tObjPDummy,"pickup color","ObjESPBoxColor",Color3.new(1,1,0))
    EToggle(ESPO,"health value","ObjESPHealthValue",false)
    EToggle(ESPO,"health bar","ObjESPHealthBar",false)
    EToggle(ESPO,"health %","ObjESPHealthPercent",false)

    -- LEFT: Player chams + visible chams tabbox
    local CTB=tf:AddLeftTabbox("chams")
    local CT=CTB:AddTab("player chams")
    EToggle(CT,"enable chams","ChamsEnabled",false)
    EToggle(CT,"show enemy","ChamsShowEnemy",true)
    EToggle(CT,"show team","ChamsShowTeam",false)
    EToggle(CT,"show friends","ChamsShowFriend",true)
    EDivider(CT)
    local tCEFDummy=EToggle(CT,"enemy fill","_CEFDummy",false)
    EColorPicker(CT,tCEFDummy,"enemy fill","ChamsEnemyColor",Color3.new(1,0,0))
    local tCEODummy=EToggle(CT,"enemy outline","_CEODummy",false)
    EColorPicker(CT,tCEODummy,"enemy outline","ChamsEnemyOutline",Color3.new(0.5,0,0))
    EDivider(CT)
    local tCTFDummy=EToggle(CT,"team fill","_CTFDummy",false)
    EColorPicker(CT,tCTFDummy,"team fill","ChamsTeamColor",Color3.new(0,0,1))
    local tCTODummy=EToggle(CT,"team outline","_CTODummy",false)
    EColorPicker(CT,tCTODummy,"team outline","ChamsTeamOutline",Color3.new(0,0,0.5))
    EDivider(CT)
    local tCFFDummy=EToggle(CT,"friend fill","_CFFDummy",false)
    EColorPicker(CT,tCFFDummy,"friend fill","ChamsFriendColor",Color3.new(0,1,0))
    local tCFODummy=EToggle(CT,"friend outline","_CFODummy",false)
    EColorPicker(CT,tCFODummy,"friend outline","ChamsFriendOutline",Color3.new(0,0.5,0))

    local VT=CTB:AddTab("visible chams")
    EToggle(VT,"visible chams override","VisibleChamsEnabled",false)
    local tVCFDummy=EToggle(VT,"visible fill","_VCFDummy",false)
    EColorPicker(VT,tVCFDummy,"visible fill","VisibleChamsColor",Color3.new(1,1,0))
    local tVCODummy=EToggle(VT,"visible outline","_VCODummy",false)
    EColorPicker(VT,tVCODummy,"visible outline","VisibleChamsOutline",Color3.new(0.5,0.5,0))
    EDivider(VT)
    EToggle(VT,"visible only mode","ChamsVisibleOnly",false)
    local tVEDummy=EToggle(VT,"vis enemy color","_VEDummy",false)
    EColorPicker(VT,tVEDummy,"vis enemy","VisibleEnemyColor",Color3.new(1,0,0))
    local tVTDummy=EToggle(VT,"vis team color","_VTDummy",false)
    EColorPicker(VT,tVTDummy,"vis team","VisibleTeamColor",Color3.new(0,0,1))
    local tVFDummy=EToggle(VT,"vis friend color","_VFDummy",false)
    EColorPicker(VT,tVFDummy,"vis friend","VisibleFriendColor",Color3.new(0,1,0))

    -- RIGHT: World chams
    local WG=tf:AddRightGroupbox("world chams")
    EToggle(WG,"world chams","ChamsWorldEnabled",false)
    local tHCFDummy=EToggle(WG,"hp fill","_HCFDummy",false)
    EColorPicker(WG,tHCFDummy,"hp fill","HealthChamsColor",Color3.new(0,1,0))
    local tHCODummy=EToggle(WG,"hp outline","_HCODummy",false)
    EColorPicker(WG,tHCODummy,"hp outline","HealthChamsOutline",Color3.new(0,0.5,0))
    EDivider(WG)
    local tACFDummy=EToggle(WG,"ammo fill","_ACFDummy",false)
    EColorPicker(WG,tACFDummy,"ammo fill","AmmoChamsColor",Color3.new(1,0.5,0))
    local tACODummy=EToggle(WG,"ammo outline","_ACODummy",false)
    EColorPicker(WG,tACODummy,"ammo outline","AmmoChamsOutline",Color3.new(0.5,0.25,0))
    EDivider(WG)
    EToggle(WG,"enemy sentry","SentryChamsEnemy",false)
    EToggle(WG,"team sentry","SentryChamsTeam",false)
    local tSEFDummy=EToggle(WG,"enemy sentry fill","_SEFDummy",false)
    EColorPicker(WG,tSEFDummy,"enemy sentry fill","SentryChamsEnemyColor",Color3.new(1,0,0))
    local tSEODummy=EToggle(WG,"enemy sentry outline","_SEODummy",false)
    EColorPicker(WG,tSEODummy,"enemy sentry outline","SentryChamsEnemyOutline",Color3.new(0.5,0,0))
    local tSTFDummy=EToggle(WG,"team sentry fill","_STFDummy",false)
    EColorPicker(WG,tSTFDummy,"team sentry fill","SentryChamsTeamColor",Color3.new(0,0.5,1))
    local tSTODummy=EToggle(WG,"team sentry outline","_STODummy",false)
    EColorPicker(WG,tSTODummy,"team sentry outline","SentryChamsTeamOutline",Color3.new(0,0.25,0.5))
    EDivider(WG)
    EToggle(WG,"enemy dispenser","DispenserChamsEnemy",false)
    EToggle(WG,"team dispenser","DispenserChamsTeam",false)
    local tDEFDummy=EToggle(WG,"enemy disp fill","_DEFDummy",false)
    EColorPicker(WG,tDEFDummy,"enemy disp fill","DispenserChamsEnemyColor",Color3.new(1,0.3,0))
    local tDTFDummy=EToggle(WG,"team disp fill","_DTFDummy",false)
    EColorPicker(WG,tDTFDummy,"team disp fill","DispenserChamsTeamColor",Color3.new(0,1,0.5))
    EDivider(WG)
    EToggle(WG,"enemy teleporter","TeleporterChamsEnemy",false)
    EToggle(WG,"team teleporter","TeleporterChamsTeam",false)
    local tTEFDummy=EToggle(WG,"enemy tele fill","_TEFDummy",false)
    EColorPicker(WG,tTEFDummy,"enemy tele fill","TeleporterChamsEnemyColor",Color3.new(1,0,1))
    local tTTFDummy=EToggle(WG,"team tele fill","_TTFDummy",false)
    EColorPicker(WG,tTTFDummy,"team tele fill","TeleporterChamsTeamColor",Color3.new(0,0.8,1))
    EDivider(WG)
    EToggle(WG,"projectile chams","ChamsProjectilesEnabled",false)
    local tPCFDummy=EToggle(WG,"proj fill","_PCFDummy",false)
    EColorPicker(WG,tPCFDummy,"proj fill","ProjectileChamsColor",Color3.new(1,1,0))
    local tPCODummy=EToggle(WG,"proj outline","_PCODummy",false)
    EColorPicker(WG,tPCODummy,"proj outline","ProjectileChamsOutline",Color3.new(0.5,0.5,0))

    -- RIGHT: World visuals
    local VR=tf:AddRightGroupbox("world")
    ESlider(VR,"time of day","TimeSlider",0,24,12," hrs")
    local tAmbDummy=EToggle(VR,"ambient","_AmbDummy",false)
    EColorPicker(VR,tAmbDummy,"ambient","AmbientColor",Color3.fromRGB(70,70,70))
    EToggle(VR,"fullbright","FullbrightToggle",false)
    EToggle(VR,"no fog","NoFogToggle",false)
end

----------------------------------------------------------------------  CONTENT — MISC

do
    local tf=tabFrames["misc"]

    local ML=tf:AddLeftGroupbox("misc")
    EToggle(ML,"aegis status","AegisStatus",false,"makes you visible to other Aegis users [BROKEN]")
    EDivider(ML)
    EToggle(ML,"username hider","UsernameHider",false)
    EInput(ML,"fake name","FakeUsername","name...","Player")
    EDivider(ML)
    EToggle(ML,"agent nearby notif","AgentNotification",false)
    EDivider(ML)
    EToggle(ML,"auto bhop","AutoBhop",false)
    EToggle(ML,"no fall damage","NoFallDamage",false)
    EDivider(ML)
    EToggle(ML,"infinite cloak","InfCloakToggle",false,"does the thing")
    EToggle(ML,"infinite shield","InfShieldToggle",false,"demo shield")

    local MR=tf:AddRightGroupbox("vip / other")
    EToggle(MR,"no voice cooldown","NoVoiceCooldown",false)
    EToggle(MR,"third person","ThirdPersonMode",false)
    EToggle(MR,"heal self [medic]","HealSelfToggle",false)
    local tHSDummy=EToggle(MR,"heal self key","_HSDummy",false)
    EKeyPicker(MR,tHSDummy,"heal self","HealSelfKey","None")
    EDivider(MR)
    EToggle(MR,"no autobalance","VIPNoAutoSort",false)
    EToggle(MR,"no respawn time","VIPNoRespawnTime",false)
    EToggle(MR,"no class limits","VIPNoClassLimits",false)
    EToggle(MR,"no team limits","VIPNoTeamLimits",false)
    EToggle(MR,"speed demon (bhop)","VIPSpeedDemon",false)
    EDivider(MR)
    EToggle(MR,"device spoofer","DeviceSpoofEnabled",false,"client side only")
    EDropdown(MR,"platform","DeviceSpoofer",{"Desktop","Mobile","Xbox","Tablet"},"Desktop")
    EDivider(MR)
    EButton(MR,"aegis server",function() Notify("Aegis Server is currently closed.",4) end,
        "im probably not gonna add this (currently closed)")

    local MA=tf:AddRightGroupbox("automation")
    EToggle(MA,"auto sticky detonate","AutoStickyDetonate",false,"buggy")
    EToggle(MA,"visible stickies only","AutoStickyVisibleOnly",false)
    EDivider(MA)
    EToggle(MA,"auto airblast","AutoAirblast",false)
    EToggle(MA,"extinguish teammates","AutoAirblastExt",false)
    EDivider(MA)
    EToggle(MA,"auto uber","AutoUberToggle",false)
    ESlider(MA,"health threshold","AutoUberHealthPercent",5,100,40,"%")
    EDropdown(MA,"uber condition","AutoUberCondition",{"Self","HealTarget","Both"},"Both")
end

----------------------------------------------------------------------  CONTENT — EXPLOITS

do
    local tf=tabFrames["exploits"]

    local EL=tf:AddLeftGroupbox("exploits")
    local tAADummy=EToggle(EL,"anti-aim key","_AADummy",false)
    EKeyPicker(EL,tAADummy,"anti-aim","AAKeybind","None")
    EDropdown(EL,"aa mode","AAMode",{"jitter","backwards","spin"},"jitter")
    ESlider(EL,"jitter angle","JitterAngle",0,180,90,"°")
    ESlider(EL,"jitter speed","JitterSpeed",1,60,15)
    ESlider(EL,"spin speed","SpinSpeed",1,1080,180,"°/s")
    EDivider(EL)
    EToggle(EL,"no spread","NoSpreadToggle",false)
    ESlider(EL,"spread multiplier","SpreadMultiplier",0.2,1,0.2)
    EDivider(EL)
    local tSpeedTog=EToggle(EL,"speed","SpeedToggle",false)
    EKeyPicker(EL,tSpeedTog,"speed key","SpeedKey","None")
    ESlider(EL,"speed value","SpeedValue",1,800,300)

    local TL=tf:AddLeftGroupbox("telestab")
    local tTeleDummy=EToggle(TL,"telestab","TelestabToggle",false)
    EKeyPicker(TL,tTeleDummy,"telestab key","TelestabKey","None")
end

----------------------------------------------------------------------  CONTENT — LEADERBOARD

do
    local tf=tabFrames["leaderboard"]
    local full=tf:GetFullFrame()

    -- Priority storage: persisted via Gui attributes so it survives leaderboard refresh
    -- 0=friendly, 1=default, 2=low threat, 3=medium, 4=high, 5=kill on sight
    local PRIORITY_COLORS={
        [0]=Color3.fromRGB(80,200,120),   -- friendly  (green)
        [1]=Color3.fromRGB(155,155,172),  -- default   (dim)
        [2]=Color3.fromRGB(255,200,80),   -- low       (yellow)
        [3]=Color3.fromRGB(255,140,40),   -- medium    (orange)
        [4]=Color3.fromRGB(255,80,80),    -- high      (red)
        [5]=Color3.fromRGB(255,30,80),    -- KOS       (hot pink)
    }
    local PRIORITY_LABELS={[0]="friendly",[1]="default",[2]="low",[3]="medium",[4]="high",[5]="kos"}

    local function SavePri(uid,val)  pcall(function() Gui:SetAttribute("pri_"..uid,val) end) end
    local function LoadPri(uid)
        local ok,v=pcall(function() return Gui:GetAttribute("pri_"..uid) end)
        return (ok and type(v)=="number") and v or 1
    end

    -- Expose globally so the main Aegis logic can read it
    getgenv().AegisPriority={Get=LoadPri,Set=SavePri,Colors=PRIORITY_COLORS,Labels=PRIORITY_LABELS}

    -- Header row
    local hdr=N("Frame",{Size=UDim2.new(1,-12,0,20),Position=UDim2.fromOffset(6,4),BackgroundColor3=T.Main,BorderSizePixel=0,ZIndex=4},full)
    Cr(hdr,3); StC(hdr,T.Outline,1)
    N("Frame",{BackgroundColor3=T.Accent,BorderSizePixel=0,Size=UDim2.new(1,0,0,2),ZIndex=5},hdr)
    local COLS={{t="DISPLAY",x=0,w=0.21},{t="USERNAME",x=0.21,w=0.20},{t="USER ID",x=0.41,w=0.17},{t="TEAM",x=0.58,w=0.15},{t="PRIORITY",x=0.73,w=0.27}}
    for _,col in ipairs(COLS) do
        N("TextLabel",{Text=col.t,BackgroundTransparency=1,Font=T.Font,TextColor3=T.Dim,TextSize=10,TextXAlignment=Enum.TextXAlignment.Left,Size=UDim2.new(col.w,-4,1,0),Position=UDim2.new(col.x,4,0,2),ZIndex=6},hdr)
    end

    -- Detail panel at bottom
    local DETAIL_H=76
    local detailPanel=N("Frame",{Size=UDim2.new(1,-12,0,DETAIL_H),Position=UDim2.new(0,6,1,-DETAIL_H-4),BackgroundColor3=T.Main,BorderSizePixel=0,ZIndex=4,Visible=false},full)
    Cr(detailPanel,3); StC(detailPanel,T.Outline,1)
    N("Frame",{BackgroundColor3=T.Accent,BorderSizePixel=0,Size=UDim2.new(1,0,0,2),ZIndex=5},detailPanel)
    local avatarImg=N("ImageLabel",{Size=UDim2.fromOffset(52,52),Position=UDim2.fromOffset(8,12),BackgroundColor3=T.Bg,BorderSizePixel=0,ZIndex=5},detailPanel); Cr(avatarImg,4); StC(avatarImg,T.Outline,1)
    N("TextLabel",{Text="?",BackgroundTransparency=1,Font=T.FontB,TextColor3=T.Dim,TextSize=20,Size=UDim2.new(1,0,1,0),ZIndex=6},avatarImg)
    local dName=N("TextLabel",{Text="",BackgroundTransparency=1,Font=T.FontB,TextColor3=T.FontC,TextSize=13,TextXAlignment=Enum.TextXAlignment.Left,Size=UDim2.new(1,-70,0,15),Position=UDim2.new(0,68,0,8),ZIndex=5},detailPanel)
    local dUser=N("TextLabel",{Text="",BackgroundTransparency=1,Font=T.Font,TextColor3=T.Dim,TextSize=11,TextXAlignment=Enum.TextXAlignment.Left,Size=UDim2.new(1,-70,0,13),Position=UDim2.new(0,68,0,24),ZIndex=5},detailPanel)
    local dUID =N("TextLabel",{Text="",BackgroundTransparency=1,Font=T.Font,TextColor3=T.Dim,TextSize=11,TextXAlignment=Enum.TextXAlignment.Left,Size=UDim2.new(1,-70,0,13),Position=UDim2.new(0,68,0,38),ZIndex=5},detailPanel)
    local dPri =N("TextLabel",{Text="",RichText=true,BackgroundTransparency=1,Font=T.Font,TextColor3=T.Dim,TextSize=11,TextXAlignment=Enum.TextXAlignment.Left,Size=UDim2.new(1,-70,0,13),Position=UDim2.new(0,68,0,52),ZIndex=5},detailPanel)

    local function FmtTime(s) s=math.max(0,s); local m=math.floor(s/60); s=s%60; local h2=math.floor(m/60); m=m%60
        return h2>0 and ("%d:%02d:%02d"):format(h2,m,s) or ("%d:%02d"):format(m,s) end
    local joinTimes={} -- track join times
    for _,p in ipairs(Players:GetPlayers()) do joinTimes[p.UserId]=os.time() end
    Players.PlayerAdded:Connect(function(p) joinTimes[p.UserId]=os.time() end)

    local function ShowDetail(p,pri)
        if not p or not p.Parent then detailPanel.Visible=false; return end
        detailPanel.Visible=true
        dName.Text=p.DisplayName; dUser.Text="@"..p.Name; dUID.Text="uid: "..tostring(p.UserId)
        local pCol=PRIORITY_COLORS[pri] or T.Dim; local pLbl=PRIORITY_LABELS[pri] or tostring(pri)
        local hex=("rgb(%d,%d,%d)"):format(math.floor(pCol.R*255),math.floor(pCol.G*255),math.floor(pCol.B*255))
        dPri.Text=('priority: <font color="'..hex..'">'..pLbl.."</font>")
        local ok,img=pcall(function() return Players:GetUserThumbnailAsync(p.UserId,Enum.ThumbnailType.HeadShot,Enum.ThumbnailSize.Size60x60) end)
        if ok then avatarImg.Image=img end
    end

    -- Scroll frame (leaves room for header + detail panel)
    local pScroll=N("ScrollingFrame",{
        Size=UDim2.new(1,-12,1,-28-DETAIL_H-8),Position=UDim2.fromOffset(6,28),
        BackgroundColor3=T.Bg,BorderSizePixel=0,CanvasSize=UDim2.new(0,0,0,0),
        ScrollBarThickness=3,ScrollBarImageColor3=T.Accent,ZIndex=4},full)
    Cr(pScroll,3); StC(pScroll,T.Outline,1)
    N("UIListLayout",{Padding=UDim.new(0,1),FillDirection=Enum.FillDirection.Vertical,SortOrder=Enum.SortOrder.LayoutOrder},pScroll)

    -- Priority stepper widget (inline ◀ 3 medium ▶)
    local function MakePriStepper(parent,uid,onChanged)
        local frame=N("Frame",{BackgroundTransparency=1,Size=UDim2.new(0.27,-6,0,15),Position=UDim2.new(0.73,3,0.5,-7),ZIndex=6},parent)
        local curPri=LoadPri(uid)
        -- ◀ button
        local btnL=N("TextButton",{Text="◀",BackgroundTransparency=1,Font=T.Font,TextColor3=T.Accent,TextSize=9,Size=UDim2.fromOffset(12,15),ZIndex=8},frame)
        -- value label
        local valLbl=N("TextLabel",{Text=PRIORITY_LABELS[curPri],BackgroundTransparency=1,Font=T.Font,TextColor3=PRIORITY_COLORS[curPri],TextSize=10,TextXAlignment=Enum.TextXAlignment.Center,Size=UDim2.new(1,-24,1,0),Position=UDim2.fromOffset(12,0),ZIndex=8},frame)
        -- ▶ button
        local btnR=N("TextButton",{Text="▶",BackgroundTransparency=1,Font=T.Font,TextColor3=T.Accent,TextSize=9,Size=UDim2.fromOffset(12,15),Position=UDim2.new(1,-12,0,0),ZIndex=8},frame)
        local fStk=StC(frame,T.Outline,1); fStk.Transparency=0.6
        local function Refresh()
            valLbl.Text=PRIORITY_LABELS[curPri]; valLbl.TextColor3=PRIORITY_COLORS[curPri]
        end
        btnL.MouseButton1Click:Connect(function()
            curPri=math.max(0,curPri-1); SavePri(uid,curPri); Refresh()
            if onChanged then onChanged(curPri) end
        end)
        btnR.MouseButton1Click:Connect(function()
            curPri=math.min(5,curPri+1); SavePri(uid,curPri); Refresh()
            if onChanged then onChanged(curPri) end
        end)
        -- Touch support
        btnL.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.Touch then
            curPri=math.max(0,curPri-1); SavePri(uid,curPri); Refresh()
            if onChanged then onChanged(curPri) end end end)
        btnR.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.Touch then
            curPri=math.min(5,curPri+1); SavePri(uid,curPri); Refresh()
            if onChanged then onChanged(curPri) end end end)
        return frame, function() curPri=LoadPri(uid); Refresh() end
    end

    local function BuildRows()
        for _,c in ipairs(pScroll:GetChildren()) do if not c:IsA("UIListLayout") then c:Destroy() end end
        local plrs=Players:GetPlayers(); table.sort(plrs,function(a,b) return a.Name<b.Name end)
        for n0,p in ipairs(plrs) do
            local isLocal=p==LP; local uid=p.UserId; local pri=LoadPri(uid)
            local rowBg=N("Frame",{Size=UDim2.new(1,0,0,22),BackgroundColor3=n0%2==0 and T.Main or T.RowAlt,BorderSizePixel=0,ZIndex=5},pScroll)
            local rStk=StC(rowBg,T.Accent,1); rStk.Transparency=1
            local nameC=isLocal and T.Accent or T.FontC
            N("TextLabel",{Text=p.DisplayName,BackgroundTransparency=1,Font=T.Font,TextColor3=nameC,TextSize=11,TextXAlignment=Enum.TextXAlignment.Left,TextTruncate=Enum.TextTruncate.AtEnd,Size=UDim2.new(0.21,-4,1,0),Position=UDim2.new(0,4,0,0),ZIndex=6},rowBg)
            N("TextLabel",{Text=p.Name,BackgroundTransparency=1,Font=T.Font,TextColor3=isLocal and T.Accent or T.Dim,TextSize=11,TextXAlignment=Enum.TextXAlignment.Left,TextTruncate=Enum.TextTruncate.AtEnd,Size=UDim2.new(0.20,-4,1,0),Position=UDim2.new(0.21,4,0,0),ZIndex=6},rowBg)
            N("TextLabel",{Text=tostring(uid),BackgroundTransparency=1,Font=T.Font,TextColor3=T.Dim,TextSize=10,TextXAlignment=Enum.TextXAlignment.Left,TextTruncate=Enum.TextTruncate.AtEnd,Size=UDim2.new(0.17,-4,1,0),Position=UDim2.new(0.41,4,0,0),ZIndex=6},rowBg)
            local tName=p.Team and p.Team.Name or "none"; local tColor=p.Team and p.Team.TeamColor and p.Team.TeamColor.Color or T.Dim
            N("TextLabel",{Text=tName,BackgroundTransparency=1,Font=T.Font,TextColor3=tColor,TextSize=10,TextXAlignment=Enum.TextXAlignment.Left,TextTruncate=Enum.TextTruncate.AtEnd,Size=UDim2.new(0.15,-4,1,0),Position=UDim2.new(0.58,4,0,0),ZIndex=6},rowBg)
            -- Row hover / click → detail
            local rhit=N("TextButton",{Text="",BackgroundTransparency=1,Size=UDim2.new(0.73,0,1,0),ZIndex=9},rowBg)
            rhit.MouseEnter:Connect(function() Tw(rStk,0.08,{Transparency=0}); ShowDetail(p,LoadPri(uid)) end)
            rhit.MouseLeave:Connect(function() Tw(rStk,0.08,{Transparency=1}) end)
            rhit.MouseButton1Click:Connect(function() ShowDetail(p,LoadPri(uid)) end)
            rhit.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.Touch then
                Tw(rStk,0.08,{Transparency=0}); ShowDetail(p,LoadPri(uid)) end end)
            -- Priority stepper
            MakePriStepper(rowBg,uid,function(newPri)
                -- Refresh detail panel if this player is selected
                if detailPanel.Visible then ShowDetail(p,newPri) end
            end)
        end
        pScroll.CanvasSize=UDim2.fromOffset(0,#Players:GetPlayers()*23)
    end

    BuildRows()
    Players.PlayerAdded:Connect(function() task.wait(0.2); BuildRows() end)
    Players.PlayerRemoving:Connect(function() task.wait(0.2); BuildRows() end)
    Players.PlayerAdded:Connect(function(p)
        p:GetPropertyChangedSignal("Team"):Connect(function() task.wait(0.1); BuildRows() end)
    end)
end

----------------------------------------------------------------------  CONTENT — SETTINGS

do
    local tf=tabFrames["settings"]

    local SL=tf:AddLeftGroupbox("interface")
    local tSKB=EToggle(SL,"show keybinds","ShowKeybinds",true)
    local tWM=EToggle(SL,"watermark","ShowWatermark",true)
    tSKB:OnChanged(function(v) kbShow=v; RefKB() end)
    tWM:OnChanged(function(v) WMF.Visible=v; wmOn=v end)
    EDivider(SL)
    EToggle(SL,"custom fov","CustomFOV",false)
    ESlider(SL,"fov amount","CustomFOVAmount",40,120,90,"°")
    EDivider(SL)
    EToggle(SL,"mobile mode","MobileModeToggle",false)
    EDivider(SL)
    ELabel(SL,"menu bind",false)
    local tMenuDummy=EToggle(SL,"menu bind","_MenuDummy",false)
    EKeyPicker(SL,tMenuDummy,"menu","MenuKeybind","RightShift",true)

    local SR=tf:AddRightGroupbox("configuration")
    EInput(SR,"config name","CfgName","name...","")
    local cfgListDrop=EDropdown(SR,"config list","CfgList",{},"",false)
    EDivider(SR)
    local function RefCfgs()
        local list={}
        pcall(function()
            for _,f in ipairs(listfiles("LB/settings")) do
                if f:sub(-5)==".json" then local nm=f:match("[^/\\]+$"); if nm then table.insert(list,nm:sub(1,-6)) end end
            end
        end)
        if Options.CfgList then Options.CfgList:SetValues(list) end
        return list
    end
    EButton(SR,"create config",function() SaveCfg(Options.CfgName and Options.CfgName.Value or ""); RefCfgs() end)
    EButton(SR,"load config",function() LoadCfg(Options.CfgList and Options.CfgList.Value or "") end)
    EButton(SR,"overwrite",function() SaveCfg(Options.CfgList and Options.CfgList.Value or ""); RefCfgs() end)
    EButton(SR,"refresh list",function() RefCfgs() end)
    EButton(SR,"set as autoload",function()
        local n=Options.CfgList and Options.CfgList.Value or ""; if n=="" then return end
        pcall(function() writefile("LB/settings/autoload.txt",n) end); Notify('autoload → "'..n..'"')
    end)
    EDivider(SR)
    local alLbl=ELabel(SR,"autoload: none",false)
    pcall(function() if isfile("LB/settings/autoload.txt") then alLbl.Text="autoload: "..readfile("LB/settings/autoload.txt") end end)
    RefCfgs()
    pcall(function() if isfile("LB/settings/autoload.txt") then task.wait(0.5); LoadCfg(readfile("LB/settings/autoload.txt")) end end)

    -- Init widgets
    kbShow=true; WMF.Visible=true; wmOn=true; RefKB()

-- Stash shared UI vars for backend access
getgenv()._aegisUI={Notify=Notify,Win=Win,CX=CX,WMF=WMF,wmOn=wmOn,TxtSvc=TxtSvc}
end

-- Menu keybind: single persistent connection set up after all content
-- Reads the current key on every press so changing the bind works immediately
UIS.InputBegan:Connect(function(i,gp)
    if gp then return end
    if i.UserInputType~=Enum.UserInputType.Keyboard then return end
    local kb=Options.MenuKeybind; if not kb then return end
    local k=kb.Value; if not k or k=="None" then return end
    local ok,kc=pcall(function() return Enum.KeyCode[k] end)
    if ok and i.KeyCode==kc then Win.Visible=not Win.Visible end
end)

end -- end _buildUI
_buildUI()

local function _runBackend()
-- Read shared UI vars from getgenv (stashed by _buildUI)
local _ui=getgenv()._aegisUI or {}
local Notify=_ui.Notify or function() end
local Win=_ui.Win
local CX=_ui.CX
local WMF=_ui.WMF
local wmOn=_ui.wmOn
local TxtSvc=_ui.TxtSvc
-- Services/globals not declared in this function scope
local UIS=_UIS
local Players=_Players
local Toggles=_G.Toggles
local Options=_G.Options
local T={Font=Enum.Font.Gotham} -- only Font needed by backend watermark updater

----------------------------------------------------------------------  AEGIS BACKEND
-- (Place check and anticheat bypass already ran at the top of the file)

local _Unloaded = false

-- Services for backend (aliases; UI already declared most of these above)
local RunService        = game:GetService("RunService")
local Lighting          = game:GetService("Lighting")
local Workspace         = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VIM               = game:GetService("VirtualInputManager")
local Stats             = game:GetService("Stats")
local LogService        = game:GetService("LogService")
local Camera            = Workspace.CurrentCamera
local LocalPlayer       = _LP

-- Cheater list
do pcall(function()
    local src=game:HttpGet("https://raw.githubusercontent.com/Lunarsyst/-3197-541/refs/heads/main/21398")
    loadstring(src)()
end) end
local CheaterList=getgenv().AegisCheaterList or {}
local function IsCheater(p) return CheaterList[p.UserId]~=nil end

-- Weapons module
local WeaponsModule=nil
task.spawn(function() pcall(function()
    local PG=LocalPlayer:WaitForChild("PlayerGui",30); if not PG then return end
    local G=PG:WaitForChild("GUI",10); if not G then return end
    local C=G:WaitForChild("Client",10); if not C then return end
    local F=C:WaitForChild("Functions",10); if not F then return end
    WeaponsModule=require(F.Weapons)
end) end)
local function FireShot() if WeaponsModule then pcall(function() WeaponsModule.firebullet() end) end end

-- Weapon snapshot (for fire-rate restores)
local WeaponSnapshot={}
task.spawn(function() task.wait(2); pcall(function()
    for _,wep in pairs(ReplicatedStorage.Weapons:GetChildren()) do
        WeaponSnapshot[wep.Name]={}
        for _,child in pairs(wep:GetChildren()) do
            if child:IsA("ValueBase") then WeaponSnapshot[wep.Name][child.Name]=child.Value end
        end
    end
end) end)

local isMobileDevice = UIS.TouchEnabled and not UIS.KeyboardEnabled
local AEGIS_ATTR = "_rbxint"
local AegisUserCache = {}
local function StampAegisCharacter(char)
    if not char then return end; pcall(function() char:SetAttribute(AEGIS_ATTR,true) end)
end
local isMobileMode = false

local BACKSTAB_RANGE=7.8; local MELEE_RANGE_RAGE=7.8; local MELEE_RANGE_DEMOKNIGHT=9
local TC2_GRAVITY=50; local TC2_JUMP_POWER=16
local PROJECTILE_OFFSET=Vector3.new(0.32,-0.14,-0.56)
local SIM_PARAMS_CACHE_TTL=0.5

local cachedPlayerList={}
do
    for _,p in ipairs(Players:GetPlayers()) do table.insert(cachedPlayerList,p) end
    Players.PlayerAdded:Connect(function(p) table.insert(cachedPlayerList,p) end)
    Players.PlayerRemoving:Connect(function(p)
        for i=#cachedPlayerList,1,-1 do if cachedPlayerList[i]==p then table.remove(cachedPlayerList,i) end end
    end)
end

local S={
    charlieKirk=false, shooting=false, lastShotTime=0, shotInterval=0.033,
    jitterDir=1, spinAngle=0, lastJitterUpdate=0, fps=0, frames=0,
    chargeStartTime=0, isCharging=false, currentChargePercent=0,
    lastAgentNotif=0, silentAimKeyActive=false,
    warpActive=false, lastWarpTime=0, lastBackstabTarget=nil,
    lastWorldChamsUpdate=0, lastProjChamsUpdate=0,
    lastUsernameUpdate=0, lastVelocityUpdate=0, lastHitDebugNotif=0,
    lastAirblastTime=0, noSpreadSetup=false, speedConnection=nil,
    _guiLoaded=false,
    ads=nil, adsmodifier=nil, equipped=nil, kirk=nil, ClassValue=nil,
    mobileToggleButton=nil, armTarget=nil, armHoldStart=nil, armReturning=false,
    armReturnStart=nil, lastMeleeTarget=nil,
    simRayParamsCache=nil, simRayParamsCacheTime=0,
}
local healthCache={}; local visibilityCache={}
local playerVelocities={}; local playerAccelerations={}
local playerVerticalHistory={}; local playerStrafeHistory={}; local playerPositionHistory={}
local cachedSentries={}; local cachedDispensers={}; local cachedTeleporters={}
local cachedAmmo={}; local cachedHP={}
local PlayerChamsCache={}; local lastChamsProps={}
local WorldChamsCache={}; local ProjectileChamsCache={}
local FrameCache={
    playerData=nil, silentTarget=nil, silentTargetPlr=nil,
    camPos=Vector3.zero, camCF=CFrame.new(), screenCenter=Vector2.new(),
    frameNum=0, lastPredictedPos=nil,
}

-- Freecam dummy
task.spawn(function()
    local function EFC()
        pcall(function()
            local pg=LocalPlayer:FindFirstChild("PlayerGui"); if not pg then return end
            if not pg:FindFirstChild("FreecamScript") then
                local d=Instance.new("LocalScript"); d.Name="FreecamScript"; d.Disabled=true; d.Parent=pg
            end
        end)
    end
    EFC(); LocalPlayer.CharacterAdded:Connect(function() task.wait(0.5); EFC() end)
    while true do task.wait(5); if _Unloaded then break end; EFC() end
end)

local function EnsureGUILoaded()
    if S._guiLoaded then return true end
    pcall(function()
        local PG=LocalPlayer:FindFirstChild("PlayerGui"); if not PG then return end
        local G=PG:FindFirstChild("GUI"); if not G then return end
        local C=G:FindFirstChild("Client"); if not C then return end
        local L=C:FindFirstChild("LegacyLocalVariables"); if not L then return end
        S.ads=L:FindFirstChild("ads"); S.adsmodifier=L:FindFirstChild("adsmodifier")
        S.equipped=L:FindFirstChild("equipped"); S.kirk=L:FindFirstChild("currentspread")
        local St=LocalPlayer:FindFirstChild("Status")
        if St then S.ClassValue=St:FindFirstChild("Class") end
        if S.ads and S.adsmodifier and S.equipped and S.kirk and S.ClassValue then S._guiLoaded=true end
    end); return S._guiLoaded
end
local function RightClick()
    pcall(function()
        local L=LocalPlayer.PlayerGui.GUI.Client.LegacyLocalVariables
        L.Held2.Value=true; task.wait(0.05); L.Held2.Value=false
    end)
end

local HitboxTables={
    Head={"Head","HeadHB"}, Chest={"UpperTorso","HumanoidRootPart"}, Torso={"LowerTorso"},
    Arms={"LeftLowerArm","RightLowerArm","LeftUpperArm","RightUpperArm","LeftHand","RightHand"},
    Legs={"LeftLowerLeg","RightLowerLeg","LeftUpperLeg","RightUpperLeg"},
    Feet={"LeftFoot","RightFoot"},
}
local SkeletonConnections={
    {"Head","UpperTorso"},{"UpperTorso","LowerTorso"},
    {"UpperTorso","LeftUpperArm"},{"LeftUpperArm","LeftLowerArm"},{"LeftLowerArm","LeftHand"},
    {"UpperTorso","RightUpperArm"},{"RightUpperArm","RightLowerArm"},{"RightLowerArm","RightHand"},
    {"LowerTorso","LeftUpperLeg"},{"LeftUpperLeg","LeftLowerLeg"},{"LeftLowerLeg","LeftFoot"},
    {"LowerTorso","RightUpperLeg"},{"RightUpperLeg","RightLowerLeg"},{"RightLowerLeg","RightFoot"},
}
local ProjectileWeapons={
    ["Direct Hit"]={Speed=123.75,Gravity=0,InitialAngle=0,Lifetime=99},
    ["Maverick"]={Speed=64.75,Gravity=15,InitialAngle=0,Lifetime=99},
    ["Rocket Launcher"]={Speed=64.75,Gravity=0,InitialAngle=0,Lifetime=99},
    ["Double Trouble"]={Speed=64.75,Gravity=0,InitialAngle=0,Lifetime=99},
    ["Blackbox"]={Speed=68.75,Gravity=0,InitialAngle=0,Lifetime=99},
    ["Original"]={Speed=68.75,Gravity=0,InitialAngle=0,Lifetime=99},
    ["Cow Mangler 5000"]={Speed=64.75,Gravity=0,InitialAngle=0,Lifetime=99},
    ["Wreckers Yard"]={Speed=64.75,Gravity=0,InitialAngle=0,Lifetime=99},
    ["G-Bomb"]={Speed=44.6875,Gravity=0,InitialAngle=0,Lifetime=99},
    ["Airstrike"]={Speed=64.75,Gravity=0,InitialAngle=0,Lifetime=99,AirSpeed=110},
    ["Liberty Launcher"]={Speed=96.25,Gravity=0,InitialAngle=0,Lifetime=99},
    ["Grenade Launcher"]={Speed=76,Gravity=42.6,InitialAngle=7.92,Lifetime=0.8},
    ["Ultimatum"]={Speed=76,Gravity=42.6,InitialAngle=7.92,Lifetime=0.8},
    ["Iron Bomber"]={Speed=76,Gravity=42.6,InitialAngle=7.92,Lifetime=0.8},
    ["Loose Cannon"]={Speed=76,Gravity=42.6,InitialAngle=7.92,Lifetime=0.8},
    ["Loch-n-Load"]={Speed=96,Gravity=42.6,InitialAngle=5.412,Lifetime=99},
    ["Syringe Crossbow"]={Speed=125,Gravity=3,InitialAngle=0,Lifetime=99},
    ["Milk Pistol"]={Speed=100,Gravity=3,InitialAngle=0,Lifetime=99},
    ["Flare Gun"]={Speed=125,Gravity=10,InitialAngle=0,Lifetime=99},
    ["Detonator"]={Speed=125,Gravity=10,InitialAngle=0,Lifetime=99},
    ["Rescue Ranger"]={Speed=150,Gravity=3,InitialAngle=0,Lifetime=99},
    ["Apollo"]={Speed=125,Gravity=3,InitialAngle=0,Lifetime=99},
    ["Big Bite"]={Speed=64.75,Gravity=0,InitialAngle=0,Lifetime=99},
    ["Night Sky Ignitor"]={Speed=123.75,Gravity=0,InitialAngle=0,Lifetime=99},
    ["Twin-Turbolence"]={Speed=76,Gravity=42.6,InitialAngle=7.92,Lifetime=0.8},
}
local ChargeWeapons={
    ["Huntsman"]={SpeedMin=113.25,SpeedMax=162.5,GravityMin=24.8,GravityMax=5.0,
        Gravity=24.8,InitialAngle=1.5,ChargeTime=1.0,Lifetime=99},
}
local BackstabWeapons={
    ["Knife"]=true,["Conniver's Kunai"]=true,["Your Eternal Reward"]=true,
    ["Icicle"]=true,["Swift Stiletto"]=true,["Wraith"]=true,["Big Earner"]=true,
    ["Spy-cicle"]=true,["Wanga Prick"]=true,["Karambit"]=true,["Golden Knife"]=true,
}
local MeleeWeapons={
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
    ["Amputator"]=true,["Holiday Punch"]=true,["Prop Handle"]=true,
    ["Trowel"]=true,["Bat"]=true,["Broken Sword"]=true,["Crowbar"]=true,
    ["Fire Extinguisher"]=true,["Fists"]=true,["Knife"]=true,["Saw"]=true,
    ["Wrench"]=true,["Machete"]=true,["The Black Death"]=true,["Eyelander"]=true,
}
local BlacklistedWeapons={
    ["None"]=true,["Sticky Jumper"]=true,["Rocket Jumper"]=true,["Overdrive"]=true,
    ["The Mercy Kill"]=true,["Friendly Fire Foiler"]=true,
    ["Buff Banner"]=true,["Battalion's Backup"]=true,["Concheror"]=true,
    ["Battle Burrito"]=true,["Dire Donut"]=true,["Tenacious Turkey"]=true,
    ["Robar"]=true,["Special-ops Sushi"]=true,["Blood Doctor"]=true,
    ["Kritzkrieg"]=true,["Rejuvenator"]=true,["The Vaccinator"]=true,
    ["Medigun"]=true,["Radius Scanner"]=true,["Slow Burn"]=true,["Spy Camera"]=true,
    ["Stray Reflex"]=true,["Sapper"]=true,["Disguise Kit"]=true,["Jarate"]=true,
    ["Mad Milk"]=true,["Witches Brew"]=true,["Bloxy Cola"]=true,["Lemonade"]=true,
}
local projectileNames={
    "Bauble","Shuriken","Rocket","Grenade","Arrow_Syringe","Sentry Rocket",
    "Arrow","Flare Gun","Baseball","Snowballs","Milk Pistol",
}

local function GetRainbowColor()
    local t=tick()*1.5; local h=t%1; local r,g,b
    local i=math.floor(h*6); local f=h*6-i; local q=1-f
    if i%6==0 then r,g,b=1,f,0 elseif i%6==1 then r,g,b=q,1,0 elseif i%6==2 then r,g,b=0,1,f
    elseif i%6==3 then r,g,b=0,q,1 elseif i%6==4 then r,g,b=f,0,1 else r,g,b=1,0,q end
    return Color3.new(r,g,b)
end
local StatusLetters={
    Bleeding={Letter="B",Color=Color3.fromRGB(255,50,50)},
    Cloaked={Letter="C",Color=Color3.fromRGB(150,150,255)},
    Coated={Letter="Co",Color=Color3.fromRGB(180,100,255)},
    Engulfed={Letter="E",Color=Color3.fromRGB(255,150,0)},
    Lemoned={Letter="L",Color=Color3.fromRGB(255,255,0)},
    Milked={Letter="M",Color=Color3.fromRGB(230,230,230)},
    Poisoned={Letter="P",Color=Color3.fromRGB(100,200,50)},
    Ubercharged={Letter="U",Color=Color3.fromRGB(255,215,0)},
    ADS={Letter="ADS",Color=Color3.fromRGB(200,200,200)},
}

getgenv().Config={
    SilentAim={Enabled=false,FOV=200},
    AntiAim={Enabled=false,Mode="jitter",JitterAngle=90,JitterSpeed=15,AntiAimSpeed=180},
    Wallbang={Enable=false}, NoSpread={Enable=false,Multiplier=0.2},
    Speed={Enable=false,Value=300}, AutoUber={Enabled=false,HealthPercent=40,Condition="Both"},
    DmgMod={Enabled=false,Multiplier=3},
}
local Config=getgenv().Config

local function GetWeaponType(weapon)
    if not weapon or weapon=="Unknown" then return "Unknown" end
    if ProjectileWeapons[weapon] or ChargeWeapons[weapon] then return "Projectile" end
    if MeleeWeapons[weapon] then return "Melee" end
    if BlacklistedWeapons[weapon] then return "Other" end
    return "Hitscan"
end

local function GetCharacter(p) return p and p.Character end
local function GetHumanoid(c) return c and c:FindFirstChildOfClass("Humanoid") end
local function GetHRP(c) return c and c:FindFirstChild("HumanoidRootPart") end
local function GetLocalCharacter() return GetCharacter(LocalPlayer) end
local function IsPlayerAlive(p)
    local c=p and p.Character; local h=c and c:FindFirstChildOfClass("Humanoid")
    return h and h.Health>0
end
local function IsEnemy(p) return p and p.Team~=LocalPlayer.Team end
local function IsFriend(p)
    local ok,r=pcall(function() return LocalPlayer:IsFriendsWith(p.UserId) end); return ok and r
end
local function WorldToViewportPoint(pos)
    local ok,sp,os=pcall(function() return Camera:WorldToViewportPoint(pos) end)
    if not ok or not sp then return Vector2.new(0,0),false,0 end
    return Vector2.new(sp.X,sp.Y),os,sp.Z
end

local raycastParams=RaycastParams.new()
raycastParams.FilterType=Enum.RaycastFilterType.Blacklist; raycastParams.IgnoreWater=true

local function IsPartVisible(part)
    if not part then return false end
    if visibilityCache[part]~=nil then return visibilityCache[part] end
    local toDir=part.Position-FrameCache.camPos
    if toDir.Magnitude>0.1 and FrameCache.camCF.LookVector:Dot(toDir.Unit)<-0.17 then
        visibilityCache[part]=false; return false
    end
    local lc=GetLocalCharacter(); if not lc then return false end
    raycastParams.FilterDescendantsInstances={lc}
    local result=Workspace:Raycast(FrameCache.camPos,toDir,raycastParams)
    local vis=not result or result.Instance:IsDescendantOf(part.Parent)
    visibilityCache[part]=vis; return vis
end
local function IsCharacterVisible(char) local hrp=GetHRP(char); return hrp and IsPartVisible(hrp) end
local function IsCharacterInvisible(char)
    local head=char and char:FindFirstChild("Head"); return head and head.Transparency>0.9
end
local function HasLineOfSight(fromPos,toPos)
    local rp=RaycastParams.new(); rp.FilterType=Enum.RaycastFilterType.Blacklist; rp.IgnoreWater=true
    local lc=GetLocalCharacter(); rp.FilterDescendantsInstances=lc and {lc} or {}
    local dir=toPos-fromPos; local hit=Workspace:Raycast(fromPos,dir,rp)
    return not hit or (hit.Position-fromPos).Magnitude>=dir.Magnitude-1
end

local wallbangActive=false; local wallbangHook=nil

local function GetPlayerWeapon(char)
    if not char then return "Unknown" end
    local g=char:FindFirstChild("Gun"); if g then local b=g:FindFirstChild("Boop"); if b then return tostring(b.Value) end end
    return "Unknown"
end
local function GetLocalWeapon() return GetPlayerWeapon(GetLocalCharacter()) end
local function GetCurrentProfileType()
    local wtype=GetWeaponType(GetLocalWeapon())
    if wtype=="Projectile" then return "Projectile" end
    if wtype=="Melee" then return "Melee" end
    if S.equipped then
        local v=tostring(S.equipped.Value):lower()
        if v=="melee" then return "Melee" elseif v=="primary" then return "Primary" end
    end; return "Secondary"
end
local function GetActiveSAProfile()
    local wtype=GetCurrentProfileType()
    return {
        enabled="SA_Enabled_"..wtype, autoShoot="SA_AutoShoot_"..wtype,
        ignoreInvis="SA_IgnoreInvis_"..wtype, fov="SA_FOV_"..wtype,
        fovCircle="SA_FOVCircle_"..wtype, sort="SA_Sort_"..wtype,
        targets="SA_Targets_"..wtype, bodyParts="SA_BodyParts_"..wtype, wtype=wtype,
    }
end

local function GetBestVisiblePart(char,selectedGroups,sortMode)
    if not char or char==LocalPlayer.Character then return nil end
    sortMode=sortMode or "Closest to Mouse"
    local skipVisCheck=wallbangActive and GetCurrentProfileType()~="Projectile" and GetCurrentProfileType()~="Melee"
    local candidates={}
    for _,groupName in ipairs({"Head","Chest","Torso","Arms","Legs","Feet"}) do
        if selectedGroups[groupName] then
            for _,partName in ipairs(HitboxTables[groupName] or {}) do
                local p=char:FindFirstChild(partName)
                if p and (skipVisCheck or IsPartVisible(p)) then table.insert(candidates,p) end
            end
        end
    end
    if #candidates==0 then return nil end
    if sortMode=="Closest to Mouse" then
        local best,bestDist=nil,math.huge
        for _,p in ipairs(candidates) do
            local sp,onScreen=WorldToViewportPoint(p.Position)
            if onScreen then local d=(sp-FrameCache.screenCenter).Magnitude; if d<bestDist then bestDist=d; best=p end end
        end; return best
    else
        local best,bestDist=nil,math.huge
        for _,p in ipairs(candidates) do
            local d=(FrameCache.camPos-p.Position).Magnitude; if d<bestDist then bestDist=d; best=p end
        end; return best
    end
end

local function GetPlayerClass(p)
    local st=p:FindFirstChild("Status"); if st then local c=st:FindFirstChild("Class"); if c then return tostring(c.Value) end end; return "Unknown"
end
local function GetPlayerMaxHP(player)
    local ok,val=pcall(function() return Workspace[player.Name].MaxHealth.Value end)
    if ok and val and val>0 then return val end
    local char=player.Character; if char then local hum=GetHumanoid(char); if hum then return hum.MaxHealth end end; return 150
end
local function GetLocalClass()
    if not EnsureGUILoaded() then return "Unknown" end; return S.ClassValue and tostring(S.ClassValue.Value) or "Unknown"
end
local function GetPing()
    local p=0; pcall(function() p=Stats.Network.ServerStatsItem["Data Ping"]:GetValue() end); return math.max(p/1000,0.05)
end
local function IsOnGround(char)
    if not char then return false end
    local wsChar=Workspace:FindFirstChild(char.Name)
    if wsChar then
        local mcs=wsChar:GetAttribute("MasterControlState"); if mcs then return mcs=="Grounded" end
        local air=wsChar:GetAttribute("isAirborne"); if air~=nil then return not air end
    end
    local hum=GetHumanoid(char); return hum and hum.FloorMaterial~=Enum.Material.Air
end
local function IsRocketJumped()
    local lc=GetLocalCharacter(); if not lc then return false end; return lc:FindFirstChild("RocketJumped")~=nil
end
local function GetPlayerModifiers(player)
    local mods={}
    pcall(function()
        local char=player.Character; if not char then return end
        local conds=char:FindFirstChild("Conditions"); if not conds then return end
        for attrName in pairs(StatusLetters) do
            if attrName~="ADS" and conds:GetAttribute(attrName)==true then mods[attrName]=true end
        end
    end)
    pcall(function()
        local gui=player.PlayerGui:FindFirstChild("GUI")
        local llv=gui and gui:FindFirstChild("Client") and gui.Client:FindFirstChild("LegacyLocalVariables")
        local adsVal=llv and llv:FindFirstChild("ads"); if adsVal and adsVal.Value==true then mods["ADS"]=true end
    end); return mods
end
local function IsPlayerFullHP(player)
    local char=player.Character; if not char then return true end
    local hum=GetHumanoid(char); if not hum then return true end; return hum.Health>=GetPlayerMaxHP(player)
end
local function IsSyringeWeapon(w) return w=="Syringe Crossbow" or w=="Apollo" end

local function GetSimRayParams()
    local now=tick()
    if S.simRayParamsCache and (now-S.simRayParamsCacheTime)<SIM_PARAMS_CACHE_TTL then return S.simRayParamsCache end
    local rp=RaycastParams.new(); rp.FilterType=Enum.RaycastFilterType.Blacklist; rp.IgnoreWater=true
    local ignore={}
    for _,p in ipairs(cachedPlayerList) do if p.Character then table.insert(ignore,p.Character) end end
    table.insert(ignore,Camera); rp.FilterDescendantsInstances=ignore
    S.simRayParamsCache=rp; S.simRayParamsCacheTime=now; return rp
end

local function UpdateVelocityTracking()
    local now=tick(); if now-S.lastVelocityUpdate<0.03 then return end
    for _,player in ipairs(cachedPlayerList) do
        if player==LocalPlayer then continue end
        local char=player.Character; if not char then continue end
        local hrp=GetHRP(char); if not hrp then continue end
        local vel=hrp.AssemblyLinearVelocity; local pos=hrp.Position
        if not playerPositionHistory[player] then playerPositionHistory[player]={} end
        table.insert(playerPositionHistory[player],{Pos=pos,Time=now})
        while #playerPositionHistory[player]>20 do table.remove(playerPositionHistory[player],1) end
        if not playerVerticalHistory[player] then playerVerticalHistory[player]={} end
        table.insert(playerVerticalHistory[player],{Y=vel.Y,Time=now})
        while #playerVerticalHistory[player]>15 do table.remove(playerVerticalHistory[player],1) end
        local dt=now-S.lastVelocityUpdate
        if playerVelocities[player] then
            local prev=playerVelocities[player].Velocity
            local acc=(vel-prev)/math.max(dt,0.001)
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
    end; S.lastVelocityUpdate=now
end
local function GetPlayerVelocity(player)
    local d=playerVelocities[player]; if d then return d.Velocity end
    local char=player.Character; if char then local hrp=GetHRP(char); if hrp then return hrp.AssemblyLinearVelocity end end; return Vector3.zero
end
local function GetPlayerAcceleration(player) return playerAccelerations[player] or Vector3.zero end
local function GetPositionDerivedVelocity(player)
    local hist=playerPositionHistory[player]; if not hist or #hist<3 then return GetPlayerVelocity(player) end
    local recent=hist[#hist]; local older=hist[math.max(1,#hist-3)]
    local dt=recent.Time-older.Time; if dt<0.01 then return GetPlayerVelocity(player) end
    return (recent.Pos-older.Pos)/dt
end
local function IsVelocityStale(player)
    local hist=playerPositionHistory[player]; if not hist or #hist<5 then return false end
    local recent=hist[#hist]; local older=hist[math.max(1,#hist-5)]
    local dt=recent.Time-older.Time; if dt<0.25 then return false end
    return GetPlayerVelocity(player).Magnitude>10 and (recent.Pos-older.Pos).Magnitude<2
end

local SimulateTargetPosition
do
    local function STG(position,rp)
        local result=Workspace:Raycast(position+Vector3.new(0,3,0),Vector3.new(0,-200,0),rp)
        if result then return result.Position,result.Normal end; return nil,nil
    end
    local function SCW(fromPos,toPos,rp)
        local dir=toPos-fromPos; local hDir=Vector3.new(dir.X,0,dir.Z)
        if hDir.Magnitude<0.01 then return false,toPos end
        local fc=Workspace:Raycast(fromPos+Vector3.new(0,0.5,0),hDir,rp)
        local cc=Workspace:Raycast(fromPos+Vector3.new(0,2,0),hDir,rp)
        if fc or cc then local hit=fc or cc; local stopPos=hit.Position+hit.Normal*0.5; return true,Vector3.new(stopPos.X,fromPos.Y,stopPos.Z) end
        return false,toPos
    end
    local function STS(fromPos,moveDir,distance,rp)
        if distance<0.01 then return fromPos,false end
        local stepSize=2; local numSteps=math.ceil(distance/stepSize); local currentPos=fromPos
        for i=1,numSteps do
            local stepDist=math.min(stepSize,distance-(i-1)*stepSize)
            local nextPos=currentPos+moveDir*stepDist
            local blocked,stopPos=SCW(currentPos,nextPos,rp)
            if blocked then return stopPos,true end
            local groundPos,groundNormal=STG(nextPos,rp)
            if groundPos then
                local slopeAngle=math.acos(math.clamp(groundNormal.Y,-1,1))
                if slopeAngle<math.rad(60) then
                    local heightDiff=groundPos.Y-currentPos.Y
                    if heightDiff<5 and heightDiff>-20 then currentPos=groundPos+Vector3.new(0,2.5,0)
                    else return currentPos,true end
                else currentPos=groundPos+Vector3.new(0,2.5,0) end
            else return nextPos,false end
        end; return currentPos,false
    end
    SimulateTargetPosition=function(player,totalTime,steps,rp,wallCheck)
        steps=steps or 15; rp=rp or GetSimRayParams()
        local char=player.Character; if not char then return nil end
        local hrp=GetHRP(char); if not hrp then return nil end
        local rawVel=GetPlayerVelocity(player); local posVel=GetPositionDerivedVelocity(player)
        local hRaw=Vector3.new(rawVel.X,0,rawVel.Z); local hPos=Vector3.new(posVel.X,0,posVel.Z)
        local hVel
        if hPos.Magnitude>1 and (hPos-hRaw).Magnitude>2 then
            hVel=hPos.Magnitude>0.1 and hPos.Unit*math.max(hRaw.Magnitude,hPos.Magnitude) or hRaw
        else hVel=hRaw end
        if hVel.Magnitude>80 then hVel=hVel.Unit*80 end
        local vY=rawVel.Y; local acceleration=GetPlayerAcceleration(player)
        local grounded=IsOnGround(char); local timeStep=totalTime/steps
        local simPos=hrp.Position; local simVelY=vY; local simGrounded=grounded
        local simHVel=hVel; local simStopped=false
        local isJumping=grounded and vY>TC2_JUMP_POWER*0.5; local lastValidPos=hrp.Position
        local wallRP
        if wallCheck then
            wallRP=RaycastParams.new(); wallRP.FilterType=Enum.RaycastFilterType.Blacklist; wallRP.IgnoreWater=true
            local wi={}; for _,p in ipairs(cachedPlayerList) do if p.Character then table.insert(wi,p.Character) end end
            table.insert(wi,Camera); wallRP.FilterDescendantsInstances=wi
        end
        for _=1,steps do
            if simStopped and simGrounded then continue end
            local prevPos=simPos
            if simGrounded and not isJumping then
                if not simStopped then
                    local hAcc=Vector3.new(acceleration.X,0,acceleration.Z)
                    local stepVel=simHVel+hAcc*timeStep*0.3
                    if stepVel.Magnitude>80 then stepVel=stepVel.Unit*80 end
                    local moveDist=stepVel.Magnitude*timeStep
                    local moveDir=stepVel.Magnitude>0.1 and stepVel.Unit or Vector3.zero
                    if moveDist>0.01 then
                        local newPos,hitWall=STS(simPos,moveDir,moveDist,rp)
                        simPos=newPos
                        if hitWall then simStopped=true; simHVel=Vector3.zero else simHVel=stepVel end
                    end
                end
                local gp=STG(simPos,rp)
                if not gp or (simPos.Y-gp.Y)>5 then simGrounded=false; simVelY=0; simStopped=false end
            else
                if isJumping then simVelY=TC2_JUMP_POWER; simGrounded=false; isJumping=false end
                if not simStopped then
                    local hAcc=Vector3.new(acceleration.X,0,acceleration.Z)
                    simHVel=simHVel+hAcc*timeStep*0.15
                    if simHVel.Magnitude>80 then simHVel=simHVel.Unit*80 end
                end
                local hMove=simHVel*timeStep; local newPos=simPos+hMove
                if hMove.Magnitude>0.01 then
                    local blocked,stopPos=SCW(simPos,newPos,wallRP or rp)
                    if blocked then newPos=stopPos; simHVel=Vector3.zero; simStopped=true end
                end
                local yMove=simVelY*timeStep-0.5*TC2_GRAVITY*timeStep*timeStep
                simVelY=simVelY-TC2_GRAVITY*timeStep
                newPos=Vector3.new(newPos.X,simPos.Y+yMove,newPos.Z)
                local groundPos=STG(newPos,rp)
                if groundPos and newPos.Y<=groundPos.Y+2.5 then
                    newPos=Vector3.new(newPos.X,groundPos.Y+2.5,newPos.Z); simGrounded=true; simVelY=0
                end
                if yMove>0 then
                    local ceilCheck=Workspace:Raycast(simPos,Vector3.new(0,yMove+1,0),rp)
                    if ceilCheck then newPos=Vector3.new(newPos.X,ceilCheck.Position.Y-3,newPos.Z); simVelY=0 end
                end
                simPos=newPos
            end
            if wallCheck and wallRP then
                local dir=simPos-prevPos
                if dir.Magnitude>0.1 then local hit=Workspace:Raycast(prevPos,dir,wallRP); if hit then return lastValidPos end end
            end
            lastValidPos=simPos
        end
        local gp2=STG(simPos,rp)
        if gp2 and simPos.Y<gp2.Y+2.5 then simPos=Vector3.new(simPos.X,gp2.Y+2.5,simPos.Z) end
        return simPos
    end
end

local function RefreshObjectCaches()
    cachedSentries={}; cachedDispensers={}; cachedTeleporters={}
    for _,v in pairs(Workspace:GetChildren()) do
        if v.Name:match("'s Sentry$") then table.insert(cachedSentries,v)
        elseif v.Name:match("'s Dispenser$") then table.insert(cachedDispensers,v)
        elseif v.Name:match("'s Teleporter") then table.insert(cachedTeleporters,v) end
    end
    cachedAmmo={}; cachedHP={}
    local mi=Workspace:FindFirstChild("Map")
    if mi then local items=mi:FindFirstChild("Items"); if items then
        for _,v in pairs(items:GetChildren()) do
            if v.Name:match("Ammo") or v.Name=="DeadAmmo" then table.insert(cachedAmmo,v)
            elseif v.Name:match("HP") then table.insert(cachedHP,v) end
        end
    end end
end
local function removeFrom(t,c)
    for i=#t,1,-1 do if t[i]==c then table.remove(t,i) end end
end
do
    Workspace.ChildAdded:Connect(function(c) task.defer(function()
        if c.Name:match("'s Sentry$") then table.insert(cachedSentries,c)
        elseif c.Name:match("'s Dispenser$") then table.insert(cachedDispensers,c)
        elseif c.Name:match("'s Teleporter") then table.insert(cachedTeleporters,c) end
    end) end)
    Workspace.ChildRemoved:Connect(function(c) task.defer(function()
        removeFrom(cachedSentries,c); removeFrom(cachedDispensers,c); removeFrom(cachedTeleporters,c)
    end) end)
    task.spawn(function() task.wait(3); RefreshObjectCaches()
        while true do task.wait(30); if _Unloaded then break end; pcall(RefreshObjectCaches) end
    end)
    task.spawn(function()
        local mi=Workspace:WaitForChild("Map",10); if not mi then return end
        local items=mi:FindFirstChild("Items"); if not items then return end
        items.ChildAdded:Connect(function(c) task.defer(function()
            if c.Name:match("Ammo") or c.Name=="DeadAmmo" then table.insert(cachedAmmo,c)
            elseif c.Name:match("HP") then table.insert(cachedHP,c) end
        end) end)
        items.ChildRemoved:Connect(function(c) task.defer(function()
            removeFrom(cachedAmmo,c); removeFrom(cachedHP,c)
        end) end)
    end)
end
local function GetMyStickybombs()
    local result={}; local dest=Workspace:FindFirstChild("Destructable"); if not dest then return result end
    for _,v in pairs(dest:GetChildren()) do
        if v.Name:match(LocalPlayer.Name) and v.Name:match("stickybomb$") then
            local p=v:IsA("BasePart") and v or v:FindFirstChildWhichIsA("BasePart")
            if p then table.insert(result,v) end
        end
    end; return result
end
local function GetProjectiles()
    local result={}
    local ri=Workspace:FindFirstChild("Ray_ignore")
    if ri then for _,v in pairs(ri:GetChildren()) do
        for _,n in pairs(projectileNames) do
            if v.Name==n or v.Name:match("bomb$") then
                local pp=v:IsA("BasePart") and v or v:FindFirstChildWhichIsA("BasePart")
                if pp then table.insert(result,v) end; break
            end
        end
    end end
    local dest=Workspace:FindFirstChild("Destructable")
    if dest then for _,v in pairs(dest:GetChildren()) do
        if v.Name:match("stickybomb$") then
            local pp=v:IsA("BasePart") and v or v:FindFirstChildWhichIsA("BasePart")
            if pp then table.insert(result,v) end
        end
    end end; return result
end

UIS.InputBegan:Connect(function(input,processed)
    if processed or _Unloaded then return end
    if input.UserInputType==Enum.UserInputType.MouseButton1 then
        local w=GetLocalWeapon()
        if ChargeWeapons[w] then S.isCharging=true; S.chargeStartTime=tick(); S.currentChargePercent=0 end
    end
end)
UIS.InputEnded:Connect(function(input)
    if _Unloaded then return end
    if input.UserInputType==Enum.UserInputType.MouseButton1 then S.isCharging=false end
end)
local function GetCurrentWeaponSpeed(weaponName)
    if weaponName=="Airstrike" and IsRocketJumped() then return 110,2,0,0,99 end
    local cd=ChargeWeapons[weaponName]
    if cd then
        local cp=S.currentChargePercent
        return cd.SpeedMin+(cd.SpeedMax-cd.SpeedMin)*cp,cd.GravityMin-(cd.GravityMin-cd.GravityMax)*cp,cd.InitialAngle,0,cd.Lifetime
    end
    local pd=ProjectileWeapons[weaponName]
    if pd then return pd.Speed,pd.Gravity,pd.InitialAngle,0,pd.Lifetime end
    return nil
end

local function CalculateAimPoint(origin,targetPos,speed,gravity,weaponName)
    if gravity==0 then return targetPos end
    local dir=targetPos-origin; local hDir=Vector3.new(dir.X,0,dir.Z); local hDist=hDir.Magnitude
    if hDist<1 then return targetPos end
    local initAngle=0
    local pd=ProjectileWeapons[weaponName]; if pd then initAngle=pd.InitialAngle or 0 end
    local cd=ChargeWeapons[weaponName]; if cd then initAngle=cd.InitialAngle or 0 end
    local v,g,x,y=speed,gravity,hDist,dir.Y; local v2=v*v; local v4=v2*v2; local disc=v4-g*(g*x*x+2*y*v2)
    if disc>=0 then
        local sqD=math.sqrt(disc); local angle=math.atan2(v2-sqD,g*x)
        if initAngle>0 then angle=angle-math.rad(initAngle) end
        return origin+hDir.Unit*hDist+Vector3.new(0,math.tan(angle)*hDist,0)
    end
    local ft=hDist/speed; local drop=0.5*gravity*ft*ft; local aim=targetPos+Vector3.new(0,drop,0)
    if initAngle>0 then aim=aim-Vector3.new(0,math.tan(math.rad(initAngle))*hDist*0.3,0) end
    return aim
end
local function CanProjectileHitPosition(origin,targetPos,speed,gravity,initAngle,lifetime,weaponName)
    local wallRP=RaycastParams.new(); wallRP.FilterType=Enum.RaycastFilterType.Blacklist; wallRP.IgnoreWater=true
    local wi={}; for _,p in ipairs(cachedPlayerList) do if p.Character then table.insert(wi,p.Character) end end
    table.insert(wi,Camera); wallRP.FilterDescendantsInstances=wi
    if gravity==0 then
        local dir=targetPos-origin; local hit=Workspace:Raycast(origin,dir,wallRP)
        if hit then return (hit.Position-origin).Magnitude>=dir.Magnitude-2 end; return true
    end
    local aimPoint=CalculateAimPoint(origin,targetPos,speed,gravity,weaponName)
    local aimDir=(aimPoint-origin).Unit; local hDir=Vector3.new(aimDir.X,0,aimDir.Z)
    if hDir.Magnitude<0.01 then return false end; hDir=hDir.Unit
    local pitch=math.asin(math.clamp(aimDir.Y,-1,1)); local totalAngle=pitch+math.rad(initAngle)
    local hSpeed=speed*math.cos(totalAngle); local vSpeed=speed*math.sin(totalAngle)
    local hDist=Vector3.new(targetPos.X-origin.X,0,targetPos.Z-origin.Z).Magnitude
    local totalTime=math.min(hDist/math.max(hSpeed,1),lifetime); local prevPos=origin
    for i=1,20 do
        local t=(i/20)*totalTime; local hPos=origin+hDir*(hSpeed*t); local yPos=origin.Y+vSpeed*t-0.5*gravity*t*t
        local curPos=Vector3.new(hPos.X,yPos,hPos.Z); local hit=Workspace:Raycast(prevPos,curPos-prevPos,wallRP)
        if hit then return (hit.Position-targetPos).Magnitude<5 end; prevPos=curPos
    end; return (prevPos-targetPos).Magnitude<10
end
local function PredictProjectileHit(targetPart,player,weaponName)
    local speed,gravity,initAngle,armTime,lifetime=GetCurrentWeaponSpeed(weaponName)
    if not speed then return targetPart.Position,0 end
    local origin=(Camera.CFrame*CFrame.new(PROJECTILE_OFFSET)).Position; local ping=GetPing()
    local char=targetPart:FindFirstAncestorOfClass("Model"); local hrp=char and GetHRP(char)
    if not hrp then return targetPart.Position,0 end
    local partOffset=targetPart.Position-hrp.Position
    local PART_MIRRORS={LeftLowerLeg="RightLowerLeg",RightLowerLeg="LeftLowerLeg",LeftUpperLeg="RightUpperLeg",RightUpperLeg="LeftUpperLeg",LeftFoot="RightFoot",RightFoot="LeftFoot"}
    local mn=PART_MIRRORS[targetPart.Name]
    if mn then local mp=char:FindFirstChild(mn); if mp then partOffset=((targetPart.Position+mp.Position)*0.5)-hrp.Position end end
    if IsVelocityStale(player) or GetPlayerVelocity(player).Magnitude<0.5 then return targetPart.Position,(targetPart.Position-origin).Magnitude/speed end
    local rp=GetSimRayParams(); local predictedHRP=hrp.Position; local travelTime=0
    local cosAngle=math.cos(math.rad(initAngle))
    for _=1,5 do
        local predictedPart=predictedHRP+partOffset
        local dx=predictedPart.X-origin.X; local dz=predictedPart.Z-origin.Z; local hDist=math.sqrt(dx*dx+dz*dz)
        if gravity==0 and initAngle==0 then travelTime=(predictedPart-origin).Magnitude/speed
        else travelTime=hDist/math.max(speed*cosAngle,1) end
        travelTime=math.min(travelTime,lifetime)
        if armTime and armTime>0 then travelTime=math.max(travelTime,armTime) end
        local totalTime=travelTime+ping*2; local simSteps=math.clamp(math.floor(totalTime/0.033),5,30)
        local simResult=SimulateTargetPosition(player,totalTime,simSteps,rp,true)
        if simResult then predictedHRP=simResult else return targetPart.Position,travelTime end
    end
    local predictedPos=predictedHRP+partOffset
    local myHRP=GetHRP(GetLocalCharacter())
    if myHRP and (predictedPos-myHRP.Position).Magnitude<3 then return targetPart.Position,(targetPart.Position-origin).Magnitude/speed end
    if not CanProjectileHitPosition(origin,predictedPos,speed,gravity,initAngle,lifetime,weaponName) then
        if CanProjectileHitPosition(origin,targetPart.Position,speed,gravity,initAngle,lifetime,weaponName) then return targetPart.Position,(targetPart.Position-origin).Magnitude/speed end
        return nil,0
    end; return predictedPos,travelTime
end

local function BuildPlayerData()
    local data={}; local lc=GetLocalCharacter(); local lhrp=lc and GetHRP(lc); if not lhrp then return data end
    for _,plr in ipairs(cachedPlayerList) do
        if plr==LocalPlayer or not IsPlayerAlive(plr) then continue end
        local char=plr.Character; if not char then continue end
        local hrp=GetHRP(char); if not hrp then continue end
        local sp,onScreen,depth=WorldToViewportPoint(hrp.Position)
        local isAegis=false; pcall(function() isAegis=char:GetAttribute(AEGIS_ATTR)==true end)
        if isAegis then AegisUserCache[plr]=true else AegisUserCache[plr]=nil end
        table.insert(data,{
            Player=plr, Character=char, HRP=hrp, ScreenPos=sp, Depth=depth, OnScreen=onScreen,
            Distance=(lhrp.Position-hrp.Position).Magnitude,
            ScreenDistance=onScreen and (sp-FrameCache.screenCenter).Magnitude or math.huge,
            IsEnemy=IsEnemy(plr), IsFriend=IsFriend(plr), Class=GetPlayerClass(plr), IsCheater=IsCheater(plr),
        })
    end; return data
end

local function GetSilentAimTarget(playerData)
    local prof=GetActiveSAProfile()
    local fov=Options[prof.fov] and Options[prof.fov].Value or 200
    local aimTargets=Options[prof.targets] and Options[prof.targets].Value or {}
    local weapon=GetLocalWeapon(); local isSyringe=IsSyringeWeapon(weapon)
    local sortMode=(Options[prof.sort] and Options[prof.sort].Value) or "Closest to Mouse"
    local selGroups=(Options[prof.bodyParts] and Options[prof.bodyParts].Value) or {Head=true}
    local sc=FrameCache.screenCenter; local bestPart,bestDist,bestPlayer=nil,math.huge,nil
    if aimTargets["Players"] then
        for _,pd in ipairs(playerData) do
            if isSyringe then if pd.IsEnemy then continue end; if IsPlayerFullHP(pd.Player) then continue end
            else if not pd.IsEnemy then continue end end
            if not pd.OnScreen then continue end
            if Toggles[prof.ignoreInvis] and Toggles[prof.ignoreInvis].Value and IsCharacterInvisible(pd.Character) then continue end
            local part=GetBestVisiblePart(pd.Character,selGroups,sortMode); if not part then continue end
            local sp,onScreen=WorldToViewportPoint(part.Position); if not onScreen then continue end
            local dist=sortMode=="Closest to Mouse" and (sp-sc).Magnitude or pd.Distance
            if sortMode=="Closest to Mouse" and dist>fov then continue end
            if dist<bestDist then bestDist=dist; bestPart=part; bestPlayer=pd.Player end
        end
    end
    if aimTargets["Sentry"] then
        for _,v in pairs(cachedSentries) do
            if not v.Parent then continue end
            local ownerName=v.Name:match("^(.+)'s Sentry$"); local isEnemySentry=true
            if ownerName then for _,plr in ipairs(cachedPlayerList) do
                if plr.Name==ownerName and plr.Team==LocalPlayer.Team then isEnemySentry=false; break end
            end end
            if not isEnemySentry then continue end
            local hum=v:FindFirstChildOfClass("Humanoid"); if hum and hum.Health<=0 then continue end
            local pp=v.PrimaryPart or v:FindFirstChildWhichIsA("BasePart")
            if not pp or not IsPartVisible(pp) then continue end
            local sp,os2=WorldToViewportPoint(pp.Position); if not os2 then continue end
            local d=sortMode=="Closest to Mouse" and (sp-sc).Magnitude or (FrameCache.camPos-pp.Position).Magnitude
            if sortMode=="Closest to Mouse" and d>fov then continue end
            if d<bestDist then bestDist=d; bestPart=pp; bestPlayer=nil end
        end
    end
    if aimTargets["Stickybomb"] then
        local dest=Workspace:FindFirstChild("Destructable")
        if dest then for _,v in pairs(dest:GetChildren()) do
            if v.Name:match("stickybomb$") and not v.Name:match(LocalPlayer.Name) then
                local isEn=true
                for _,plr in ipairs(cachedPlayerList) do
                    if v.Name:match(plr.Name) and plr.Team==LocalPlayer.Team then isEn=false; break end
                end
                if not isEn then continue end
                local p=v:IsA("BasePart") and v or v:FindFirstChildWhichIsA("BasePart")
                if not p or not IsPartVisible(p) then continue end
                local sp,os2=WorldToViewportPoint(p.Position); if not os2 then continue end
                local d=sortMode=="Closest to Mouse" and (sp-sc).Magnitude or (FrameCache.camPos-p.Position).Magnitude
                if sortMode=="Closest to Mouse" and d>fov then continue end
                if d<bestDist then bestDist=d; bestPart=p; bestPlayer=nil end
            end
        end end
    end
    if bestPart then local myHRP=GetHRP(GetLocalCharacter()); if myHRP and (bestPart.Position-myHRP.Position).Magnitude<3 then return nil,nil end end
    return bestPart,bestPlayer
end

local ARM_HOLD_TIME=0.5; local ARM_RETURN_TIME=0.3
local function AimArmsAt(targetPos)
    local vm=Camera:FindFirstChild("PrimaryVM"); if not vm then return end
    local am=vm:FindFirstChild("CharacterArmsModel"); if not am then return end
    local vp=vm:GetPivot(); local ao=vp:ToObjectSpace(am:GetPivot())
    am:PivotTo(CFrame.lookAt(vp.Position,targetPos)*CFrame.Angles(math.rad(180),math.rad(180),math.rad(180))*ao)
end
local function ResetArmsToCamera()
    local vm=Camera:FindFirstChild("PrimaryVM"); if not vm then return end
    local am=vm:FindFirstChild("CharacterArmsModel"); if not am then return end
    local vp=vm:GetPivot(); local ao=vp:ToObjectSpace(am:GetPivot())
    am:PivotTo(Camera.CFrame*CFrame.Angles(math.rad(180),math.rad(180),math.rad(180))*ao)
end
local function UpdateAimArms()
    if not (Toggles.SilentAimArms and Toggles.SilentAimArms.Value) then return end
    if not S.armTarget then return end
    local now=tick()
    if S.armReturning then
        local alpha=math.clamp((now-S.armReturnStart)/ARM_RETURN_TIME,0,1)
        if alpha>=1 then S.armReturning=false; S.armTarget=nil; ResetArmsToCamera()
        else
            local vm=Camera:FindFirstChild("PrimaryVM"); if not vm then return end
            local vp=vm:GetPivot(); local tDir=(S.armTarget-vp.Position).Unit; local cDir=Camera.CFrame.LookVector
            AimArmsAt(vp.Position+tDir:Lerp(cDir,alpha)*10)
        end; return
    end
    local elapsed=now-S.armHoldStart
    if elapsed>=ARM_HOLD_TIME then S.armReturning=true; S.armReturnStart=now; return end
    local mode=Options.SilentAimArmsMode and Options.SilentAimArmsMode.Value or "Snap"
    if mode=="Snap" then AimArmsAt(S.armTarget)
    else
        local alpha=math.clamp(elapsed/0.15,0,1)
        local vm=Camera:FindFirstChild("PrimaryVM"); if not vm then return end
        local vp=vm:GetPivot(); local cDir=Camera.CFrame.LookVector; local tDir=(S.armTarget-vp.Position).Unit
        AimArmsAt(vp.Position+cDir:Lerp(tDir,alpha)*10)
    end
end
local function TriggerAimArms(targetPos) if not S.armReturning then S.armTarget=targetPos; S.armHoldStart=tick() end end

local function SafeLookAt(origin,target)
    if not origin or not target then return nil end
    if (origin-target).Magnitude<0.5 then return nil end
    local ok,cf=pcall(CFrame.lookAt,origin,target); if not ok then return nil end
    local rx,ry,rz=cf:ToEulerAnglesXYZ(); if rx~=rx or ry~=ry or rz~=rz then return nil end; return cf
end
local function GetProjectileAimCFrame(target,targetPlr,weapon)
    if weapon=="Huntsman" then
        local tChar=target:FindFirstAncestorOfClass("Model")
        if tChar then local head=tChar:FindFirstChild("Head"); if head and IsPartVisible(head) then target=head end end
    end
    local predicted,_=PredictProjectileHit(target,targetPlr,weapon); if not predicted then return nil end
    FrameCache.lastPredictedPos=predicted
    if weapon=="Huntsman" then predicted=predicted+Vector3.new(0,1.5,0) end
    local spd,grav=GetCurrentWeaponSpeed(weapon); local origin=FrameCache.camPos
    if (origin-predicted).Magnitude<0.5 then return nil end
    local aimTarget=(grav and grav>0) and CalculateAimPoint(origin,predicted,spd,grav,weapon) or predicted
    if not aimTarget or (origin-aimTarget).Magnitude<0.5 then return nil end
    local ok,cf=pcall(CFrame.lookAt,origin,aimTarget); if not ok or cf~=cf then return nil end
    local rx,ry,rz=cf:ToEulerAnglesXYZ(); if rx~=rx or ry~=ry or rz~=rz then return nil end
    return cf,predicted
end

task.spawn(function() pcall(function()
    local camModule=require(ReplicatedStorage.Modules.gameCamera)
    if not (camModule and camModule.GetCameraAimCFrame) then return end
    local orig=camModule.GetCameraAimCFrame
    camModule.GetCameraAimCFrame=function(self2,...)
        if not IsPlayerAlive(LocalPlayer) then return orig(self2,...) end
        local weapon=GetLocalWeapon(); if BlacklistedWeapons[weapon] then return orig(self2,...) end
        local isProj=ProjectileWeapons[weapon]~=nil or ChargeWeapons[weapon]~=nil
        if Config.SilentAim.Enabled and S.silentAimKeyActive then
            local target=FrameCache.silentTarget; local targetPlr=FrameCache.silentTargetPlr
            if target then
                if isProj then
                    if targetPlr then
                        local cf,aimPos=GetProjectileAimCFrame(target,targetPlr,weapon)
                        if cf and aimPos then if Toggles.SilentAimArms and Toggles.SilentAimArms.Value then TriggerAimArms(aimPos) end; return cf end
                    else
                        local spd,grav=GetCurrentWeaponSpeed(weapon); local aimPos=target.Position; local cf
                        if grav and grav>0 then cf=SafeLookAt(FrameCache.camPos,CalculateAimPoint(FrameCache.camPos,aimPos,spd,grav,weapon))
                        else cf=SafeLookAt(FrameCache.camPos,aimPos) end
                        if cf then if Toggles.SilentAimArms and Toggles.SilentAimArms.Value then TriggerAimArms(aimPos) end; return cf end
                    end
                else
                    local cf=SafeLookAt(FrameCache.camPos,target.Position)
                    if cf then if Toggles.SilentAimArms and Toggles.SilentAimArms.Value then TriggerAimArms(target.Position) end; return cf end
                end
            end
        end
        if Toggles.AutoBackstab and Toggles.AutoBackstab.Value then
            local myClass=GetLocalClass(); local myWeapon=GetLocalWeapon()
            if myClass=="Agent" and BackstabWeapons[myWeapon] then
                local lh=GetHRP(GetLocalCharacter())
                if lh then for _,pd in ipairs(FrameCache.playerData or {}) do
                    if not pd.IsEnemy or pd.Distance>BACKSTAB_RANGE then continue end
                    if Toggles.BackstabIgnoreInvis and Toggles.BackstabIgnoreInvis.Value and IsCharacterInvisible(pd.Character) then continue end
                    local toT=(pd.HRP.Position-lh.Position).Unit
                    if toT:Dot(pd.HRP.CFrame.LookVector)>0.3 then
                        if not HasLineOfSight(lh.Position,pd.HRP.Position) then continue end
                        local backPos=pd.HRP.Position-pd.HRP.CFrame.LookVector
                        local cf=SafeLookAt(FrameCache.camPos,backPos)
                        if cf then if Toggles.SilentAimArms and Toggles.SilentAimArms.Value then TriggerAimArms(backPos) end; return cf end
                    end
                end end
            end
        end
        if Toggles.AutoMelee and Toggles.AutoMelee.Value then
            local myWeapon=GetLocalWeapon()
            if MeleeWeapons[myWeapon] then
                local lh=GetHRP(GetLocalCharacter())
                local meleeRange=(Options.AutoMeleeMode and Options.AutoMeleeMode.Value=="Demoknight") and MELEE_RANGE_DEMOKNIGHT or MELEE_RANGE_RAGE
                if lh then
                    local bestTarget,bestDist2=nil,math.huge
                    for _,pd in ipairs(FrameCache.playerData or {}) do
                        if not pd.IsEnemy or pd.Distance>meleeRange then continue end
                        if Toggles.MeleeIgnoreInvis and Toggles.MeleeIgnoreInvis.Value and IsCharacterInvisible(pd.Character) then continue end
                        if not HasLineOfSight(lh.Position,pd.HRP.Position) then continue end
                        if pd.Distance<bestDist2 then bestDist2=pd.Distance; bestTarget=pd end
                    end
                    if bestTarget then local cf=SafeLookAt(FrameCache.camPos,bestTarget.HRP.Position); if cf then return cf end end
                end
            end
        end
        return orig(self2,...)
    end
end) end)

local _ncOrig
_ncOrig=hookmetamethod(game,"__namecall",function(self2,...)
    if not _Unloaded then
        local method=getnamecallmethod()
        if method=="FireServer" and self2.Name=="FallDamage" then
            if Toggles.NoFallDamage and Toggles.NoFallDamage.Value then return end
        end
    end; return _ncOrig(self2,...)
end)

local function InstallWallbangHook()
    if wallbangHook then return end; wallbangActive=true
    local _cc=type(checkcaller)=="function" and checkcaller or function() return false end
    local _nc=type(newcclosure)=="function" and newcclosure or function(f) return f end
    wallbangHook=hookmetamethod(game,"__index",_nc(function(self2,key)
        if wallbangActive and not _cc() then if key=="Clips" then return workspace.Map end end
        return wallbangHook(self2,key)
    end))
end
local function RemoveWallbangHook()
    wallbangActive=false
    if wallbangHook then hookmetamethod(game,"__index",wallbangHook); wallbangHook=nil end
end

local function SetupNoSpread()
    if S.noSpreadSetup or not EnsureGUILoaded() then return end; S.noSpreadSetup=true
    S.kirk.Changed:Connect(function()
        if not Config.NoSpread.Enable or S.charlieKirk then return end
        S.charlieKirk=true; S.kirk.Value=S.kirk.Value*Config.NoSpread.Multiplier; S.charlieKirk=false
    end)
end
local function SetupSpeed()
    if S.speedConnection then S.speedConnection:Disconnect(); S.speedConnection=nil end
    if Config.Speed.Enable and LocalPlayer.Character then
        LocalPlayer.Character:SetAttribute("Speed",Config.Speed.Value)
        S.speedConnection=LocalPlayer.Character:GetAttributeChangedSignal("Speed"):Connect(function()
            if Config.Speed.Enable and not S.warpActive then LocalPlayer.Character:SetAttribute("Speed",Config.Speed.Value) end
        end)
    end
end
local function ApplyThirdPerson(state)
    pcall(function() LocalPlayer:SetAttribute("ThirdPerson",state)
        local vip=ReplicatedStorage:FindFirstChild("VIPSettings")
        if vip then local tp=vip:FindFirstChild("AThirdPersonMode"); if tp then tp.Value=state end end
    end)
end
local function ApplyDeviceSpoof(platform)
    if platform=="None" then return end
    pcall(function()
        local ntp=LocalPlayer:FindFirstChild("newTcPlayer"); if not ntp then return end
        ntp:SetAttribute("Platform",platform); ntp:SetAttribute("Platform Type",platform)
    end)
end
local function CreateMobileButton()
    if S.mobileToggleButton then return end
    local sg=Instance.new("ScreenGui"); sg.Name="AegisMobileButton"; sg.ResetOnSpawn=false
    sg.ZIndexBehavior=Enum.ZIndexBehavior.Sibling; sg.DisplayOrder=999; sg.Parent=LocalPlayer:WaitForChild("PlayerGui")
    local btn=Instance.new("TextButton"); btn.Name="AegisToggle"
    btn.Size=UDim2.new(0,50,0,50); btn.Position=UDim2.new(0,20,0.5,-25)
    btn.BackgroundColor3=Color3.fromRGB(30,30,30); btn.BackgroundTransparency=0.3
    btn.Text="A"; btn.TextColor3=Color3.fromRGB(200,200,255); btn.TextSize=28
    btn.Font=Enum.Font.GothamBold; btn.Parent=sg; btn.Active=true; btn.ZIndex=100
    Instance.new("UICorner",btn).CornerRadius=UDim.new(0,12)
    local stroke=Instance.new("UIStroke",btn); stroke.Color=Color3.fromRGB(100,100,200); stroke.Thickness=2
    local dragging,dragStart,startPos=false,nil,nil
    btn.InputBegan:Connect(function(input)
        if input.UserInputType==Enum.UserInputType.Touch or input.UserInputType==Enum.UserInputType.MouseButton1 then
            dragging=true; dragStart=input.Position; startPos=btn.Position end
    end)
    btn.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType==Enum.UserInputType.Touch or input.UserInputType==Enum.UserInputType.MouseMovement) then
            local d=input.Position-dragStart
            btn.Position=UDim2.new(startPos.X.Scale,startPos.X.Offset+d.X,startPos.Y.Scale,startPos.Y.Offset+d.Y)
        end
    end)
    UIS.InputEnded:Connect(function(input)
        if (input.UserInputType==Enum.UserInputType.Touch or input.UserInputType==Enum.UserInputType.MouseButton1) and dragging then
            local d=input.Position-dragStart; dragging=false
            if d.Magnitude<10 then Win.Visible=not Win.Visible end
        end
    end)
    S.mobileToggleButton=sg
end
local function DestroyMobileButton()
    if S.mobileToggleButton then S.mobileToggleButton:Destroy(); S.mobileToggleButton=nil end
end
local function SetFireRateMultiplier(mult)
    pcall(function()
        local wepName=GetLocalWeapon(); if wepName=="Unknown" then return end
        local wep=ReplicatedStorage.Weapons:FindFirstChild(wepName); if not wep then return end
        local fr=wep:FindFirstChild("FireRate")
        if fr and WeaponSnapshot[wep.Name] and WeaponSnapshot[wep.Name].FireRate then
            local orig=WeaponSnapshot[wep.Name].FireRate
            fr.Value=wep:FindFirstChild("Projectile") and math.clamp(orig/mult,0.1,9e9) or (orig/mult)
        end
    end)
end
local function RestoreFireRate()
    pcall(function()
        for _,wep in pairs(ReplicatedStorage.Weapons:GetChildren()) do
            local fr=wep:FindFirstChild("FireRate")
            if fr and WeaponSnapshot[wep.Name] and WeaponSnapshot[wep.Name].FireRate then fr.Value=WeaponSnapshot[wep.Name].FireRate end
        end
    end)
end
local function SetMaxRange(enabled)
    pcall(function()
        for _,wep in pairs(ReplicatedStorage.Weapons:GetChildren()) do
            local rng=wep:FindFirstChild("Range"); if rng then
                if enabled then rng.Value=9e9
                elseif WeaponSnapshot[wep.Name] and WeaponSnapshot[wep.Name].Range then rng.Value=WeaponSnapshot[wep.Name].Range end
            end
        end
    end)
end

local _dmgModOrig=nil; local _dmgModInstalled=false; local _dmgModFrameworks={}
local function InstallDmgMod()
    if _dmgModInstalled then return end
    task.spawn(function() pcall(function()
        for _,gc in next,getgc(true) do
            if type(gc)=="table" and not _dmgModFrameworks.Weapons then
                if type(rawget(gc,"returndamagemod"))=="function" then _dmgModFrameworks.Weapons=gc end
            end
        end
        if _dmgModFrameworks.Weapons then
            _dmgModOrig=_dmgModFrameworks.Weapons.returndamagemod
            _dmgModFrameworks.Weapons.returndamagemod=function(...)
                local base=_dmgModOrig(...)
                if Config.DmgMod.Enabled then return Config.DmgMod.Multiplier==math.huge and math.huge or base*Config.DmgMod.Multiplier end
                return base
            end; _dmgModInstalled=true
        end
    end) end)
end

local _infCloakConn=nil; local _infShieldConn=nil
local function SetupInfCloak(enabled)
    if _infCloakConn then pcall(function() _infCloakConn:Disconnect() end); _infCloakConn=nil end
    if not enabled then return end
    pcall(function()
        local L=LocalPlayer.PlayerGui.GUI.Client.LegacyLocalVariables
        local cloakleft=L:FindFirstChild("cloakleft"); if not cloakleft then return end
        _infCloakConn=cloakleft:GetPropertyChangedSignal("Value"):Connect(function()
            if cloakleft.Value<10 then cloakleft.Value=10 end
        end)
    end)
end
local function SetupInfShield(enabled)
    if _infShieldConn then pcall(function() _infShieldConn:Disconnect() end); _infShieldConn=nil end
    if not enabled then return end
    pcall(function()
        local L=LocalPlayer.PlayerGui.GUI.Client.LegacyLocalVariables
        local chargeleft=L:FindFirstChild("chargeleft"); if not chargeleft then return end
        _infShieldConn=chargeleft:GetPropertyChangedSignal("Value"):Connect(function()
            if chargeleft.Value<=0 then task.delay(0.1,function() chargeleft.Value=100 end) end
        end)
    end)
end

local _profileInfUseConns={}; local _profileInfResConns={}
local function SetupProfileInfUseAmmo(wtype,enabled)
    if _profileInfUseConns[wtype] then pcall(function() _profileInfUseConns[wtype]:Disconnect() end); _profileInfUseConns[wtype]=nil end
    if not enabled then return end
    pcall(function()
        local L=LocalPlayer.PlayerGui.GUI.Client.LegacyLocalVariables
        local ctr=L:FindFirstChild("ammocount"); if not ctr then return end
        local lastVal=ctr.Value; local tog="InfUse_"..wtype
        _profileInfUseConns[wtype]=ctr:GetPropertyChangedSignal("Value"):Connect(function()
            if not (Toggles[tog] and Toggles[tog].Value) then return end
            if GetCurrentProfileType()~=wtype then return end
            if ctr.Value>=lastVal then lastVal=ctr.Value; return end
            lastVal=ctr.Value
            local wep=ReplicatedStorage.Weapons:FindFirstChild(GetLocalWeapon())
            if wep and wep:FindFirstChild("Ammo") then ctr.Value=wep.Ammo.Value end
        end)
    end)
end
local function SetupProfileInfResAmmo(wtype,enabled)
    if _profileInfResConns[wtype] then pcall(function() _profileInfResConns[wtype]:Disconnect() end); _profileInfResConns[wtype]=nil end
    if not enabled then return end
    pcall(function()
        local L=LocalPlayer.PlayerGui.GUI.Client.LegacyLocalVariables
        local candidates={"primarystored","primary_stored","ammostore","ammocount4"}
        local ctr; for _,name in ipairs(candidates) do local v=L:FindFirstChild(name); if v then ctr=v; break end end
        if not ctr then return end
        local lastVal=ctr.Value; local tog="InfRes_"..wtype
        _profileInfResConns[wtype]=ctr:GetPropertyChangedSignal("Value"):Connect(function()
            if not (Toggles[tog] and Toggles[tog].Value) then return end
            if GetCurrentProfileType()~=wtype then return end
            if ctr.Value>=lastVal then lastVal=ctr.Value; return end
            lastVal=ctr.Value
            local wep=ReplicatedStorage.Weapons:FindFirstChild(GetLocalWeapon())
            if wep and wep:FindFirstChild("Ammo") then ctr.Value=wep.Ammo.Value end
        end)
    end)
end

local function ApplyWeaponProfileFireRates()
    pcall(function()
        local ptype=GetCurrentProfileType(); local tog="FastGun_"..ptype; local opt="FireRate_"..ptype
        if Toggles[tog] and Toggles[tog].Value and Options[opt] then SetFireRateMultiplier(Options[opt].Value) end
    end)
end
local _bhopHeartbeat=nil
do
    local _lastPType=nil
    RunService.Heartbeat:Connect(function()
        if _Unloaded then return end
        local ptype=GetCurrentProfileType()
        if ptype~=_lastPType then _lastPType=ptype; pcall(function() RestoreFireRate(); ApplyWeaponProfileFireRates() end) end
    end)
end
UIS.InputBegan:Connect(function(input,processed)
    if processed or _Unloaded then return end
    if input.KeyCode~=Enum.KeyCode.Space then return end
    if not (Toggles.AutoBhop and Toggles.AutoBhop.Value) then return end
    if _bhopHeartbeat then _bhopHeartbeat:Disconnect(); _bhopHeartbeat=nil end
    _bhopHeartbeat=RunService.Heartbeat:Connect(function()
        if not (Toggles.AutoBhop and Toggles.AutoBhop.Value) then _bhopHeartbeat:Disconnect(); _bhopHeartbeat=nil; return end
        local char=LocalPlayer.Character; if not char then return end
        pcall(function()
            local L=LocalPlayer.PlayerGui.GUI.Client.LegacyLocalVariables
            if L.spinuptick.Value<1 and (char:GetAttribute("Speed") or 0)>0 then
                local hum=char:FindFirstChildOfClass("Humanoid"); if hum then hum.Jump=true end
            end
        end)
    end)
    while UIS:IsKeyDown(Enum.KeyCode.Space) and Toggles.AutoBhop and Toggles.AutoBhop.Value do task.wait() end
    if _bhopHeartbeat then _bhopHeartbeat:Disconnect(); _bhopHeartbeat=nil end
end)

LocalPlayer.CharacterAdded:Connect(function(char)
    task.wait(1); EnsureGUILoaded(); SetupNoSpread(); SetupSpeed()
    S.jitterDir=1; S.spinAngle=0; S.armTarget=nil; S.armReturning=false
    if Toggles.AegisStatus and Toggles.AegisStatus.Value then task.wait(0.5); StampAegisCharacter(char) end
    task.wait(1)
    if Toggles.InfCloakToggle and Toggles.InfCloakToggle.Value then SetupInfCloak(true) end
    if Toggles.InfShieldToggle and Toggles.InfShieldToggle.Value then SetupInfShield(true) end
    for _,wtype in ipairs({"Projectile","Primary","Secondary"}) do
        if Toggles["InfUse_"..wtype] and Toggles["InfUse_"..wtype].Value then SetupProfileInfUseAmmo(wtype,true) end
        if Toggles["InfRes_"..wtype] and Toggles["InfRes_"..wtype].Value then SetupProfileInfResAmmo(wtype,true) end
    end
end)
task.spawn(function() task.wait(2); EnsureGUILoaded(); SetupNoSpread()
    if LocalPlayer.Character then SetupSpeed() end
    if Toggles.AegisStatus and Toggles.AegisStatus.Value then StampAegisCharacter(LocalPlayer.Character) end
end)

-- Wire all toggle/option callbacks to Aegis logic
Toggles.AegisStatus:OnChanged(function(v)
    if v then StampAegisCharacter(LocalPlayer.Character)
    else pcall(function() LocalPlayer.Character:SetAttribute(AEGIS_ATTR,nil) end) end
end)
Toggles.InfCloakToggle:OnChanged(function(v) SetupInfCloak(v) end)
Toggles.InfShieldToggle:OnChanged(function(v) SetupInfShield(v) end)
Toggles.MaxRangeToggle:OnChanged(function(v) SetMaxRange(v) end)
Toggles.ThirdPersonMode:OnChanged(function(v) ApplyThirdPerson(v) end)
Toggles.NoVoiceCooldown:OnChanged(function(v) pcall(function() ReplicatedStorage.VIPSettings.NoVoiceCooldown.Value=v end) end)
Toggles.DeviceSpoofEnabled:OnChanged(function(v) if v then ApplyDeviceSpoof(Options.DeviceSpoofer.Value); Notify("Spoofed: "..Options.DeviceSpoofer.Value,3) end end)
Options.DeviceSpoofer:OnChanged(function() if Toggles.DeviceSpoofEnabled and Toggles.DeviceSpoofEnabled.Value then ApplyDeviceSpoof(Options.DeviceSpoofer.Value); Notify("Spoofed: "..Options.DeviceSpoofer.Value,3) end end)
Toggles.AutoUberToggle:OnChanged(function() Config.AutoUber.Enabled=Toggles.AutoUberToggle.Value end)
Options.AutoUberHealthPercent:OnChanged(function() Config.AutoUber.HealthPercent=Options.AutoUberHealthPercent.Value end)
Options.AutoUberCondition:OnChanged(function() Config.AutoUber.Condition=Options.AutoUberCondition.Value end)
Options.AAMode:OnChanged(function(v) Config.AntiAim.Mode=v end)
Options.JitterAngle:OnChanged(function(v) Config.AntiAim.JitterAngle=v end)
Options.JitterSpeed:OnChanged(function(v) Config.AntiAim.JitterSpeed=v end)
Options.SpinSpeed:OnChanged(function(v) Config.AntiAim.AntiAimSpeed=v end)
Toggles.NoSpreadToggle:OnChanged(function(v)
    Config.NoSpread.Enable=v
    if v then EnsureGUILoaded(); SetupNoSpread()
        if S.kirk then S.charlieKirk=true; S.kirk.Value=S.kirk.Value*Config.NoSpread.Multiplier; S.charlieKirk=false end
    end
end)
Options.SpreadMultiplier:OnChanged(function(v) Config.NoSpread.Multiplier=v end)
Toggles.SpeedToggle:OnChanged(function()
    Config.Speed.Enable=Toggles.SpeedToggle.Value; SetupSpeed()
    if not Toggles.SpeedToggle.Value and S.speedConnection then S.speedConnection:Disconnect(); S.speedConnection=nil end
end)
Options.SpeedValue:OnChanged(function(v)
    Config.Speed.Value=v; if Config.Speed.Enable and LocalPlayer.Character then LocalPlayer.Character:SetAttribute("Speed",v) end
end)
for _,wtype in ipairs({"Primary","Secondary"}) do
    local wt=wtype
    if Toggles["WallbangToggle_"..wt] then
        Toggles["WallbangToggle_"..wt]:OnChanged(function()
            local anyWB=(Toggles.WallbangToggle_Primary and Toggles.WallbangToggle_Primary.Value)
                      or (Toggles.WallbangToggle_Secondary and Toggles.WallbangToggle_Secondary.Value)
            Config.Wallbang.Enable=anyWB
            if anyWB then InstallWallbangHook() else RemoveWallbangHook() end
        end)
    end
end
for _,wtype in ipairs({"Primary","Secondary","Melee","Projectile"}) do
    local wt=wtype
    if Toggles["NoSpread_"..wt] then Toggles["NoSpread_"..wt]:OnChanged(function(v)
        Config.NoSpread.Enable=v
        if v then EnsureGUILoaded(); SetupNoSpread()
            if S.kirk then S.charlieKirk=true; S.kirk.Value=S.kirk.Value*Config.NoSpread.Multiplier; S.charlieKirk=false end
        end
    end) end
    if Options["NoSpreadMult_"..wt] then Options["NoSpreadMult_"..wt]:OnChanged(function(v) Config.NoSpread.Multiplier=v end) end
    if Toggles["FastGun_"..wt] then Toggles["FastGun_"..wt]:OnChanged(function(v) if not v then RestoreFireRate() else ApplyWeaponProfileFireRates() end end) end
    if Options["FireRate_"..wt] then Options["FireRate_"..wt]:OnChanged(function(v)
        if Toggles["FastGun_"..wt] and Toggles["FastGun_"..wt].Value and GetCurrentProfileType()==wt then SetFireRateMultiplier(v) end
    end) end
    if Toggles["DmgMod_"..wt] then Toggles["DmgMod_"..wt]:OnChanged(function(v)
        Config.DmgMod.Enabled=v and GetCurrentProfileType()==wt
        if v and not _dmgModInstalled then InstallDmgMod() end
    end) end
    if Options["DmgModMult_"..wt] then Options["DmgModMult_"..wt]:OnChanged(function(v) Config.DmgMod.Multiplier=v end) end
    if Toggles["DmgModInf_"..wt] then Toggles["DmgModInf_"..wt]:OnChanged(function(v)
        if v then Config.DmgMod.Multiplier=math.huge
        else Config.DmgMod.Multiplier=Options["DmgModMult_"..wt] and Options["DmgModMult_"..wt].Value or 3 end
    end) end
    if Toggles["InfUse_"..wt] then Toggles["InfUse_"..wt]:OnChanged(function(v) SetupProfileInfUseAmmo(wt,v) end) end
    if Toggles["InfRes_"..wt] then Toggles["InfRes_"..wt]:OnChanged(function(v) SetupProfileInfResAmmo(wt,v) end) end
end
if Toggles.CustomFOV then
    Toggles.CustomFOV:OnChanged(function() if Toggles.CustomFOV.Value then Camera.FieldOfView=Options.CustomFOVAmount.Value end end)
    Options.CustomFOVAmount:OnChanged(function() if Toggles.CustomFOV.Value then Camera.FieldOfView=Options.CustomFOVAmount.Value end end)
    Camera:GetPropertyChangedSignal("FieldOfView"):Connect(function() if Toggles.CustomFOV.Value then Camera.FieldOfView=Options.CustomFOVAmount.Value end end)
end
if Toggles.MobileModeToggle then
    Toggles.MobileModeToggle:OnChanged(function() isMobileMode=Toggles.MobileModeToggle.Value end)
    if isMobileDevice then task.defer(function() task.wait(1); if Toggles.MobileModeToggle then Toggles.MobileModeToggle:SetValue(true) end end) end
end
local OL={Ambient=Lighting.Ambient,Brightness=Lighting.Brightness,FogEnd=Lighting.FogEnd,
    FogStart=Lighting.FogStart,ClockTime=Lighting.ClockTime,OutdoorAmbient=Lighting.OutdoorAmbient}
Options.TimeSlider:OnChanged(function() Lighting.ClockTime=Options.TimeSlider.Value end)
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
task.spawn(function() while true do task.wait(1); if _Unloaded then break end
    Lighting.ClockTime=Options.TimeSlider.Value
    if Toggles.FullbrightToggle.Value then Lighting.Brightness=2; Lighting.Ambient=Color3.new(1,1,1); Lighting.OutdoorAmbient=Color3.new(1,1,1)
    else Lighting.Ambient=Options.AmbientColor.Value; Lighting.OutdoorAmbient=Options.AmbientColor.Value end
    if Toggles.NoFogToggle.Value then Lighting.FogEnd=1e10; Lighting.FogStart=1e10 end
end end)
task.spawn(function() while true do task.wait(2); if _Unloaded then break end
    pcall(function()
        if Toggles.NoVoiceCooldown and Toggles.NoVoiceCooldown.Value then ReplicatedStorage.VIPSettings.NoVoiceCooldown.Value=true end
        if Toggles.ThirdPersonMode and Toggles.ThirdPersonMode.Value then
            local v=ReplicatedStorage:FindFirstChild("VIPSettings"); if v then local t=v:FindFirstChild("AThirdPersonMode"); if t then t.Value=true end end end
        if Toggles.DeviceSpoofEnabled and Toggles.DeviceSpoofEnabled.Value then ApplyDeviceSpoof(Options.DeviceSpoofer.Value) end
        local vip=ReplicatedStorage:FindFirstChild("VIPSettings")
        if vip then
            if Toggles.VIPNoAutoSort    and Toggles.VIPNoAutoSort.Value    then pcall(function() vip.NoAutoSort.Value=true    end) end
            if Toggles.VIPNoRespawnTime and Toggles.VIPNoRespawnTime.Value then pcall(function() vip.NoRespawnTime.Value=true  end) end
            if Toggles.VIPNoClassLimits and Toggles.VIPNoClassLimits.Value then pcall(function() vip.NoClassLimits.Value=true  end) end
            if Toggles.VIPNoTeamLimits  and Toggles.VIPNoTeamLimits.Value  then pcall(function() vip.NoTeamLimits.Value=true   end) end
            if Toggles.VIPSpeedDemon    and Toggles.VIPSpeedDemon.Value    then pcall(function() vip.SpeedDemon.Value=true     end) end
        end
        ApplyWeaponProfileFireRates()
    end)
end end)

-- Drawing
local ESPObjects={}; local ObjectESPCache={}
local function NewDrawing(t2)
    if Drawing then return Drawing.new(t2) end
    local stub={}; setmetatable(stub,{__index=function() return stub end,__newindex=function() end})
    stub.Remove=function() end; stub.Visible=false; return stub
end
local FOVCircle=NewDrawing("Circle")
pcall(function() FOVCircle.Thickness=1; FOVCircle.NumSides=64; FOVCircle.Filled=false; FOVCircle.Visible=false; FOVCircle.Transparency=0.8 end)
local PredictionIndicator=NewDrawing("Text")
pcall(function() PredictionIndicator.Size=24; PredictionIndicator.Center=true; PredictionIndicator.Outline=true; PredictionIndicator.Font=2; PredictionIndicator.Visible=false end)
local function MkDraw(t2,p)
    local d=NewDrawing(t2); pcall(function() for k,v in pairs(p or {}) do d[k]=v end end); return d
end

local function CreatePlayerESP(player)
    if ESPObjects[player] then return end
    local d={BoxLines={},BoxOutlines={},CornerLines={},CornerOutlines={},Box3DLines={},Box3DOutlines={},SkeletonLines={},StatusTexts={},HealthSegs={},Hidden=true}
    for i=1,4  do d.BoxOutlines[i]   =MkDraw("Line",{Thickness=1,Color=Color3.new(0,0,0),Visible=false}) end
    for i=1,8  do d.CornerOutlines[i]=MkDraw("Line",{Thickness=1,Color=Color3.new(0,0,0),Visible=false}) end
    for i=1,12 do d.Box3DOutlines[i] =MkDraw("Line",{Thickness=1,Color=Color3.new(0,0,0),Visible=false}) end
    d.BoxFill=MkDraw("Square",{Filled=true,Transparency=1,Visible=false})
    d.HealthBarBG=MkDraw("Line",{Thickness=3,Color=Color3.fromRGB(20,20,20),Visible=false})
    d.HealthBarOutline=MkDraw("Square",{Filled=false,Thickness=1,Color=Color3.new(0,0,0),Visible=false})
    d.TracerOut=MkDraw("Line",{Thickness=3,Color=Color3.new(0,0,0),Visible=false})
    for i=1,4  do d.BoxLines[i]   =MkDraw("Line",{Thickness=1,Visible=false}) end
    for i=1,8  do d.CornerLines[i]=MkDraw("Line",{Thickness=1,Visible=false}) end
    for i=1,12 do d.Box3DLines[i] =MkDraw("Line",{Thickness=1,Visible=false}) end
    d.HealthBar=MkDraw("Line",{Thickness=1,Visible=false})
    for i=1,8 do d.HealthSegs[i]=MkDraw("Line",{Thickness=1,Visible=false}) end
    d.Tracer=MkDraw("Line",{Thickness=1,Visible=false})
    d.NameText=MkDraw("Text",{Size=13,Center=true,Outline=true,Font=2,Visible=false})
    d.CheaterText=MkDraw("Text",{Size=11,Center=true,Outline=true,Font=2,Visible=false,Color=Color3.fromRGB(255,60,60)})
    d.DistanceText=MkDraw("Text",{Size=7,Center=true,Outline=true,Font=2,Visible=false})
    d.WeaponText=MkDraw("Text",{Size=7,Center=true,Outline=true,Font=2,Visible=false})
    d.ClassText=MkDraw("Text",{Size=7,Center=true,Outline=true,Font=2,Visible=false})
    d.HealthText=MkDraw("Text",{Size=11,Center=false,Outline=true,Font=2,Visible=false})
    d.HealthPercentText=MkDraw("Text",{Size=11,Center=false,Outline=true,Font=2,Visible=false})
    d.AegisText=MkDraw("Text",{Size=11,Center=true,Outline=true,Font=2,Visible=false,Color=Color3.fromRGB(180,10,10)})
    for i=1,#SkeletonConnections do d.SkeletonLines[i]=MkDraw("Line",{Thickness=1,Visible=false}) end
    for attrName,info in pairs(StatusLetters) do d.StatusTexts[attrName]=MkDraw("Text",{Size=11,Center=false,Outline=true,Font=2,Visible=false,Color=info.Color}) end
    ESPObjects[player]=d
end
local function DestroyPlayerESP(player)
    local d=ESPObjects[player]; if not d then return end
    local function R(o) pcall(function() o:Remove() end) end
    for i=1,4  do R(d.BoxLines[i]); R(d.BoxOutlines[i]) end
    for i=1,8  do R(d.CornerLines[i]); R(d.CornerOutlines[i]) end
    for i=1,12 do R(d.Box3DLines[i]); R(d.Box3DOutlines[i]) end
    for i=1,#SkeletonConnections do R(d.SkeletonLines[i]) end
    for i=1,8 do R(d.HealthSegs[i]) end
    R(d.BoxFill); R(d.HealthBarBG); R(d.HealthBar); R(d.HealthBarOutline)
    R(d.NameText); R(d.CheaterText); R(d.DistanceText); R(d.WeaponText); R(d.ClassText); R(d.AegisText)
    R(d.HealthText); R(d.HealthPercentText); R(d.Tracer); R(d.TracerOut)
    for _,txt in pairs(d.StatusTexts) do R(txt) end; ESPObjects[player]=nil
end
local function HidePlayerESP(player)
    local d=ESPObjects[player]; if not d or d.Hidden then return end; d.Hidden=true
    for i=1,4  do d.BoxLines[i].Visible=false; d.BoxOutlines[i].Visible=false end
    for i=1,8  do d.CornerLines[i].Visible=false; d.CornerOutlines[i].Visible=false end
    for i=1,12 do d.Box3DLines[i].Visible=false; d.Box3DOutlines[i].Visible=false end
    for i=1,#SkeletonConnections do d.SkeletonLines[i].Visible=false end
    for i=1,8 do d.HealthSegs[i].Visible=false end
    d.BoxFill.Visible=false; d.HealthBarBG.Visible=false; d.HealthBar.Visible=false; d.HealthBarOutline.Visible=false
    d.NameText.Visible=false; d.CheaterText.Visible=false; d.DistanceText.Visible=false
    d.WeaponText.Visible=false; d.ClassText.Visible=false; d.AegisText.Visible=false
    d.HealthText.Visible=false; d.HealthPercentText.Visible=false
    d.Tracer.Visible=false; d.TracerOut.Visible=false
    for _,txt in pairs(d.StatusTexts) do txt.Visible=false end
end
local function CreateObjectESP(inst)
    if ObjectESPCache[inst] then return end
    local d={BoxLines={},BoxOutlines={}}
    for i=1,4 do d.BoxOutlines[i]=MkDraw("Line",{Thickness=3,Color=Color3.new(0,0,0),Visible=false}) end
    d.HealthBarBG=MkDraw("Line",{Thickness=3,Color=Color3.new(0,0,0),Visible=false})
    for i=1,4 do d.BoxLines[i]=MkDraw("Line",{Thickness=1,Visible=false}) end
    d.HealthBar=MkDraw("Line",{Thickness=1,Visible=false})
    d.HealthText=MkDraw("Text",{Size=13,Center=true,Outline=true,Font=2,Visible=false})
    d.HealthPercentText=MkDraw("Text",{Size=13,Center=true,Outline=true,Font=2,Visible=false})
    d.NameText=MkDraw("Text",{Size=13,Center=true,Outline=true,Font=2,Visible=false})
    ObjectESPCache[inst]=d
end
local function DestroyObjectESP(inst)
    local d=ObjectESPCache[inst]; if not d then return end
    for i=1,4 do pcall(function() d.BoxLines[i]:Remove() end); pcall(function() d.BoxOutlines[i]:Remove() end) end
    pcall(function() d.HealthBarBG:Remove() end); pcall(function() d.HealthBar:Remove() end)
    pcall(function() d.HealthText:Remove() end); pcall(function() d.HealthPercentText:Remove() end)
    pcall(function() d.NameText:Remove() end); ObjectESPCache[inst]=nil
end
local function HideObjectESP(inst)
    local d=ObjectESPCache[inst]; if not d then return end
    for i=1,4 do d.BoxLines[i].Visible=false; d.BoxOutlines[i].Visible=false end
    d.HealthBarBG.Visible=false; d.HealthBar.Visible=false
    d.HealthText.Visible=false; d.HealthPercentText.Visible=false; d.NameText.Visible=false
end

local function Get2DBox(pd)
    local sp=pd.ScreenPos; local depth=pd.Depth; if not pd.OnScreen or depth<1 then return nil end
    local sc2=(2*Camera.ViewportSize.Y)/((2*depth*math.tan(math.rad(Camera.FieldOfView)/2))*1.5)
    local w,h=math.floor(3*sc2),math.floor(4*sc2)
    return {X=sp.X-w/2,Y=sp.Y-h/2,W=w,H=h,CX=sp.X,CY=sp.Y,TopY=sp.Y-h/2,BotY=sp.Y+h/2}
end
local function Draw2DBox(d,b,c,th)
    th=th or 1
    local tl=Vector2.new(b.X,b.Y); local tr=Vector2.new(b.X+b.W,b.Y)
    local bl=Vector2.new(b.X,b.Y+b.H); local br=Vector2.new(b.X+b.W,b.Y+b.H)
    local edges={{tl,tr},{tr,br},{br,bl},{bl,tl}}
    for i=1,4 do
        d.BoxOutlines[i].From=edges[i][1]; d.BoxOutlines[i].To=edges[i][2]; d.BoxOutlines[i].Thickness=th+1; d.BoxOutlines[i].Color=Color3.new(0,0,0); d.BoxOutlines[i].Visible=true
        d.BoxLines[i].From=edges[i][1]; d.BoxLines[i].To=edges[i][2]; d.BoxLines[i].Thickness=th; d.BoxLines[i].Color=c; d.BoxLines[i].Visible=true
    end
end
local function DrawCorners(d,b,c,th)
    th=th or 1; local cl=math.max(b.H*0.25,6)
    local tl=Vector2.new(b.X,b.Y); local tr=Vector2.new(b.X+b.W,b.Y)
    local bl=Vector2.new(b.X,b.Y+b.H); local br=Vector2.new(b.X+b.W,b.Y+b.H)
    local cn={{tl,tl+Vector2.new(cl,0)},{tl,tl+Vector2.new(0,cl)},{tr,tr+Vector2.new(-cl,0)},{tr,tr+Vector2.new(0,cl)},
              {bl,bl+Vector2.new(cl,0)},{bl,bl+Vector2.new(0,-cl)},{br,br+Vector2.new(-cl,0)},{br,br+Vector2.new(0,-cl)}}
    for i=1,8 do
        d.CornerOutlines[i].From=cn[i][1]; d.CornerOutlines[i].To=cn[i][2]; d.CornerOutlines[i].Thickness=th+1; d.CornerOutlines[i].Color=Color3.new(0,0,0); d.CornerOutlines[i].Visible=true
        d.CornerLines[i].From=cn[i][1]; d.CornerLines[i].To=cn[i][2]; d.CornerLines[i].Thickness=th; d.CornerLines[i].Color=c; d.CornerLines[i].Visible=true
    end
end
local function Draw3DBox(d,char,c,th)
    th=th or 1; local hrp=GetHRP(char); if not hrp then return end
    local cf=hrp.CFrame; local sz=Vector3.new(2,3,2)
    local corners={
        cf*Vector3.new(sz.X,sz.Y,sz.Z),cf*Vector3.new(-sz.X,sz.Y,sz.Z),
        cf*Vector3.new(-sz.X,sz.Y,-sz.Z),cf*Vector3.new(sz.X,sz.Y,-sz.Z),
        cf*Vector3.new(sz.X,-sz.Y,sz.Z),cf*Vector3.new(-sz.X,-sz.Y,sz.Z),
        cf*Vector3.new(-sz.X,-sz.Y,-sz.Z),cf*Vector3.new(sz.X,-sz.Y,-sz.Z),
    }
    local sc2={}; for _,v in pairs(corners) do table.insert(sc2,(WorldToViewportPoint(v))) end
    local edges={{1,2},{2,3},{3,4},{4,1},{5,6},{6,7},{7,8},{8,5},{1,5},{2,6},{3,7},{4,8}}
    for i,e in pairs(edges) do
        d.Box3DOutlines[i].From=sc2[e[1]]; d.Box3DOutlines[i].To=sc2[e[2]]; d.Box3DOutlines[i].Thickness=th+1; d.Box3DOutlines[i].Color=Color3.new(0,0,0); d.Box3DOutlines[i].Visible=true
        d.Box3DLines[i].From=sc2[e[1]]; d.Box3DLines[i].To=sc2[e[2]]; d.Box3DLines[i].Thickness=th; d.Box3DLines[i].Color=c; d.Box3DLines[i].Visible=true
    end
end

local function UpdatePlayerESP(pd)
    local player=pd.Player; local d=ESPObjects[player]
    if not d then CreatePlayerESP(player); d=ESPObjects[player]; if not d then return end end
    local char=pd.Character; local hum=GetHumanoid(char)
    if not hum or hum.Health<=0 then HidePlayerESP(player); return end
    if pd.IsEnemy     and not Toggles.ESPEnemy.Value   then HidePlayerESP(player); return end
    if not pd.IsEnemy and not pd.IsFriend and not Toggles.ESPTeam.Value then HidePlayerESP(player); return end
    if pd.IsFriend    and not Toggles.ESPFriends.Value then HidePlayerESP(player); return end
    if Toggles.ESPIgnoreInvis.Value and IsCharacterInvisible(char) then HidePlayerESP(player); return end
    if pd.Distance>500 or not pd.OnScreen then HidePlayerESP(player); return end
    local box=Get2DBox(pd); if not box then HidePlayerESP(player); return end
    HidePlayerESP(player); d.Hidden=false
    local color=Options.ESPBoxColor.Value; local boxTrans=Options.ESPBoxColor and Options.ESPBoxColor.Transparency or 0
    local bt=Options.ESPBoxType.Value; local th=Options.ESPBoxThickness and math.max(1,math.floor(Options.ESPBoxThickness.Value)) or 1
    if Toggles.ESPBoxFill and Toggles.ESPBoxFill.Value then
        local fc2=Options.ESPBoxFillColor and Options.ESPBoxFillColor.Value or Color3.new(1,0,0)
        local ft=Options.ESPBoxFillColor and Options.ESPBoxFillColor.Transparency or 0.7
        d.BoxFill.Position=Vector2.new(box.X,box.Y); d.BoxFill.Size=Vector2.new(box.W,box.H); d.BoxFill.Color=fc2; d.BoxFill.Transparency=ft; d.BoxFill.Visible=true
    else d.BoxFill.Visible=false end
    if bt=="2D" then Draw2DBox(d,box,color,th) elseif bt=="Corners" then DrawCorners(d,box,color,th) elseif bt=="3D" then Draw3DBox(d,char,color,th) end
    if bt=="2D" or bt=="3D" then
        local lt=bt=="2D" and d.BoxLines or d.Box3DLines; local n=bt=="2D" and 4 or 12
        for i=1,n do pcall(function() lt[i].Transparency=boxTrans end) end
    elseif bt=="Corners" then for i=1,8 do pcall(function() d.CornerLines[i].Transparency=boxTrans end) end end
    local maxHP=GetPlayerMaxHP(player); local hp=hum.Health; local hf=math.clamp(hp/maxHP,0,1)
    local topY=box.TopY-2; local tX=box.CX
    if pd.IsCheater then topY=topY-13; d.CheaterText.Text="cheater"; d.CheaterText.Position=Vector2.new(tX,topY); d.CheaterText.Color=Color3.fromRGB(255,60,60); d.CheaterText.Visible=true; topY=topY-2 else d.CheaterText.Visible=false end
    if AegisUserCache[player] then topY=topY-13; d.AegisText.Text="[A]"; d.AegisText.Position=Vector2.new(tX,topY); d.AegisText.Color=Color3.fromRGB(180,10,10); d.AegisText.Visible=true; topY=topY-2 else d.AegisText.Visible=false end
    if Toggles.ESPClass and Toggles.ESPClass.Value then topY=topY-15; d.ClassText.Text=pd.Class; d.ClassText.Position=Vector2.new(tX,topY); d.ClassText.Color=Color3.fromRGB(200,200,255); d.ClassText.Visible=true else d.ClassText.Visible=false end
    if Toggles.ESPWeapon and Toggles.ESPWeapon.Value then topY=topY-15; d.WeaponText.Text=GetPlayerWeapon(char); d.WeaponText.Position=Vector2.new(tX,topY); d.WeaponText.Color=Color3.fromRGB(255,200,100); d.WeaponText.Visible=true else d.WeaponText.Visible=false end
    local bY=box.BotY+2
    if Toggles.ESPDistance and Toggles.ESPDistance.Value then d.DistanceText.Text=string.format("[%dm]",math.floor(pd.Distance)); d.DistanceText.Position=Vector2.new(tX,bY); d.DistanceText.Color=Color3.new(1,1,1); d.DistanceText.Visible=true; bY=bY+15 else d.DistanceText.Visible=false end
    if Toggles.ESPStatus and Toggles.ESPStatus.Value then
        local mods=GetPlayerModifiers(player); local rX=box.X+box.W+4; local rY=box.Y
        for attrName,info in pairs(StatusLetters) do
            local txt=d.StatusTexts[attrName]
            if mods[attrName] then txt.Text=info.Letter; txt.Position=Vector2.new(rX,rY); txt.Color=(attrName=="Ubercharged") and GetRainbowColor() or info.Color; txt.Visible=true; rY=rY+12
            else txt.Visible=false end
        end
    else for _,txt in pairs(d.StatusTexts) do txt.Visible=false end end
    if Toggles.ESPHealthBar and Toggles.ESPHealthBar.Value then
        local barW=Options.ESPHPBarWidth and math.max(1,math.floor(Options.ESPHPBarWidth.Value)) or 2
        local side=Options.ESPHPBarSide and Options.ESPHPBarSide.Value or "Left"
        local barTop=box.Y; local barBot=box.Y+box.H; local barH=barBot-barTop; local fillY=barBot-barH*hf
        local barX=side=="Left" and box.X-barW-3 or box.X+box.W+3
        local bgColor=Options.ESPHPBGColor and Options.ESPHPBGColor.Value or Color3.fromRGB(20,20,20)
        local bgTrans=Options.ESPHPBGColor and Options.ESPHPBGColor.Transparency or 0
        d.HealthBarBG.From=Vector2.new(barX+barW/2,barTop); d.HealthBarBG.To=Vector2.new(barX+barW/2,barBot)
        d.HealthBarBG.Thickness=barW; d.HealthBarBG.Color=bgColor; pcall(function() d.HealthBarBG.Transparency=bgTrans end); d.HealthBarBG.Visible=true
        d.HealthBarOutline.Size=Vector2.new(barW+2,barH+2); d.HealthBarOutline.Position=Vector2.new(barX-1,barTop-1); d.HealthBarOutline.Visible=true
        local cHigh=Options.ESPHPColorHigh and Options.ESPHPColorHigh.Value or Color3.fromRGB(0,220,80)
        local cLow=Options.ESPHPColorLow and Options.ESPHPColorLow.Value or Color3.fromRGB(220,40,40)
        local function lerpC(a,b2,t) return Color3.new(a.R+(b2.R-a.R)*t,a.G+(b2.G-a.G)*t,a.B+(b2.B-a.B)*t) end
        if Toggles.ESPHPGradient and Toggles.ESPHPGradient.Value then
            d.HealthBar.Visible=false; local NS=8; local segH=barH/NS
            for i=1,NS do
                local seg=d.HealthSegs[i]; local sTop=barTop+(i-1)*segH; local sBot=barTop+i*segH
                local t=1-(i-0.5)/NS; local c=lerpC(cHigh,cLow,t)
                if sBot<=fillY then seg.Visible=false
                elseif sTop>=fillY then seg.From=Vector2.new(barX+barW/2,sTop); seg.To=Vector2.new(barX+barW/2,sBot); seg.Thickness=barW; seg.Color=c; seg.Visible=true
                else seg.From=Vector2.new(barX+barW/2,fillY); seg.To=Vector2.new(barX+barW/2,sBot); seg.Thickness=barW; seg.Color=c; seg.Visible=true end
            end
        else
            for i=1,8 do d.HealthSegs[i].Visible=false end
            local barColor=hp>maxHP and Color3.fromRGB(0,200,255) or lerpC(cLow,cHigh,hf)
            d.HealthBar.From=Vector2.new(barX+barW/2,fillY); d.HealthBar.To=Vector2.new(barX+barW/2,barBot); d.HealthBar.Thickness=barW; d.HealthBar.Color=barColor; d.HealthBar.Visible=true
        end
        if Toggles.ESPHealthValue and Toggles.ESPHealthValue.Value then
            local txt=tostring(math.floor(hp)); if hp>maxHP then txt=txt.." (+"..math.floor(hp-maxHP)..")" end
            d.HealthText.Text=txt; d.HealthText.Position=Vector2.new(barX-2,fillY-7); d.HealthText.Color=Color3.new(1,1,1); d.HealthText.Center=false; d.HealthText.Visible=true
        else d.HealthText.Visible=false end
        if Toggles.ESPHealthPercent and Toggles.ESPHealthPercent.Value then
            d.HealthPercentText.Text=string.format("%d%%",math.floor(hf*100)); d.HealthPercentText.Position=Vector2.new(barX-2,barBot-7); d.HealthPercentText.Color=Color3.new(1,1,1); d.HealthPercentText.Center=false; d.HealthPercentText.Visible=true
        else d.HealthPercentText.Visible=false end
    else
        d.HealthBarBG.Visible=false; d.HealthBar.Visible=false; d.HealthBarOutline.Visible=false
        for i=1,8 do d.HealthSegs[i].Visible=false end
        if Toggles.ESPHealthValue and Toggles.ESPHealthValue.Value then
            d.HealthText.Text=string.format("HP: %d/%d",math.floor(hp),math.floor(maxHP)); d.HealthText.Position=Vector2.new(tX,bY); d.HealthText.Color=Color3.new(1,1,1); d.HealthText.Center=true; d.HealthText.Visible=true; bY=bY+15
        else d.HealthText.Visible=false end
        if Toggles.ESPHealthPercent and Toggles.ESPHealthPercent.Value then
            d.HealthPercentText.Text=string.format("%d%%",math.floor(hf*100)); d.HealthPercentText.Position=Vector2.new(tX,bY); d.HealthPercentText.Color=Color3.new(1,1,1); d.HealthPercentText.Center=true; d.HealthPercentText.Visible=true
        else d.HealthPercentText.Visible=false end
    end
    if Toggles.ESPSkeleton and Toggles.ESPSkeleton.Value then
        for i,conn in pairs(SkeletonConnections) do
            local pA=char:FindFirstChild(conn[1]); local pB=char:FindFirstChild(conn[2])
            if pA and pB then
                local sA,oA=WorldToViewportPoint(pA.Position); local sB,oB=WorldToViewportPoint(pB.Position)
                if oA and oB then d.SkeletonLines[i].From=sA; d.SkeletonLines[i].To=sB; d.SkeletonLines[i].Color=Color3.new(1,1,1); d.SkeletonLines[i].Visible=true
                else d.SkeletonLines[i].Visible=false end
            else d.SkeletonLines[i].Visible=false end
        end
    end
    if Toggles.ESPTracer and Toggles.ESPTracer.Value then
        local tracerColor=Options.ESPTracerColor and Options.ESPTracerColor.Value or color
        local originMode=Options.ESPTracerOrigin and Options.ESPTracerOrigin.Value or "Bottom"
        local tracerOrigin
        if originMode=="Top" then tracerOrigin=Vector2.new(Camera.ViewportSize.X/2,0)
        elseif originMode=="Center" then tracerOrigin=FrameCache.screenCenter
        else tracerOrigin=Vector2.new(Camera.ViewportSize.X/2,Camera.ViewportSize.Y) end
        d.TracerOut.From=tracerOrigin; d.TracerOut.To=Vector2.new(box.CX,box.BotY); d.TracerOut.Visible=true
        d.Tracer.From=tracerOrigin; d.Tracer.To=Vector2.new(box.CX,box.BotY); d.Tracer.Color=tracerColor; d.Tracer.Visible=true
    else d.Tracer.Visible=false; d.TracerOut.Visible=false end
end

local function GetObjectBox(inst)
    local pp=inst:IsA("Model") and (inst.PrimaryPart or inst:FindFirstChildWhichIsA("BasePart")) or (inst:IsA("BasePart") and inst)
    if not pp then return nil end
    local sp,os2,depth=WorldToViewportPoint(pp.Position); if not os2 or depth<1 then return nil end
    local sc2=(2*Camera.ViewportSize.Y)/((2*depth*math.tan(math.rad(Camera.FieldOfView)/2))*1.5)
    local bW=math.clamp(pp.Size.Magnitude*sc2*0.5,10,200); local bH=math.clamp(pp.Size.Magnitude*sc2*0.7,10,200)
    return {TopLeft=sp-Vector2.new(bW/2,bH/2),TopRight=sp+Vector2.new(bW/2,-bH/2),
            BottomLeft=sp+Vector2.new(-bW/2,bH/2),BottomRight=sp+Vector2.new(bW/2,bH/2),Center=sp,Width=bW,Height=bH}
end
local function GetBuildingTeam(inst)
    local ownerName=inst.Name:match("^(.+)'s ") or inst.Name:match("^(.+)'s")
    if not ownerName then return "unknown" end
    for _,plr in ipairs(cachedPlayerList) do
        if plr.Name==ownerName then return plr.Team==LocalPlayer.Team and "team" or "enemy" end
    end; return "unknown"
end
local function UpdateObjectESP(inst,tn,overrideColor)
    local d=ObjectESPCache[inst]; if not d then CreateObjectESP(inst); d=ObjectESPCache[inst]; if not d then return end end
    local b=GetObjectBox(inst); if not b then HideObjectESP(inst); return end
    local c=overrideColor or Options.ObjESPBoxColor.Value
    local l={{b.TopLeft,b.TopRight},{b.TopRight,b.BottomRight},{b.BottomRight,b.BottomLeft},{b.BottomLeft,b.TopLeft}}
    for i=1,4 do
        d.BoxOutlines[i].From=l[i][1]; d.BoxOutlines[i].To=l[i][2]; d.BoxOutlines[i].Color=Color3.new(0,0,0); d.BoxOutlines[i].Visible=true
        d.BoxLines[i].From=l[i][1]; d.BoxLines[i].To=l[i][2]; d.BoxLines[i].Color=c; d.BoxLines[i].Visible=true
    end
    d.NameText.Text=tn; d.NameText.Position=b.Center-Vector2.new(0,b.Height/2+15); d.NameText.Color=Color3.new(1,1,1); d.NameText.Visible=true
    local hum=inst:FindFirstChildOfClass("Humanoid")
    if hum then
        local hp2,mh2=hum.Health,hum.MaxHealth; local hf2=math.clamp(hp2/mh2,0,1)
        local hc=Color3.fromRGB(255*(1-hf2),255*hf2,0); local yO=b.Height/2+2
        if Toggles.ObjESPHealthValue and Toggles.ObjESPHealthValue.Value then d.HealthText.Text=string.format("HP: %d/%d",math.floor(hp2),math.floor(mh2)); d.HealthText.Position=b.Center+Vector2.new(0,yO); d.HealthText.Color=Color3.new(1,1,1); d.HealthText.Visible=true; yO=yO+15 end
        if Toggles.ObjESPHealthPercent and Toggles.ObjESPHealthPercent.Value then d.HealthPercentText.Text=string.format("%d%%",math.floor(hf2*100)); d.HealthPercentText.Position=b.Center+Vector2.new(0,yO); d.HealthPercentText.Color=Color3.new(1,1,1); d.HealthPercentText.Visible=true end
        if Toggles.ObjESPHealthBar and Toggles.ObjESPHealthBar.Value then
            local bX=b.TopLeft.X-5; local bT=b.TopLeft.Y; local bB=b.BottomLeft.Y
            d.HealthBarBG.From=Vector2.new(bX,bT); d.HealthBarBG.To=Vector2.new(bX,bB); d.HealthBarBG.Thickness=3; d.HealthBarBG.Visible=true
            d.HealthBar.From=Vector2.new(bX,bB-(bB-bT)*hf2); d.HealthBar.To=Vector2.new(bX,bB); d.HealthBar.Thickness=1; d.HealthBar.Color=hc; d.HealthBar.Visible=true
        end
    end
end

-- Chams
local function GetOrCreatePlayerHighlight(pd)
    local cached=PlayerChamsCache[pd.Player]
    if cached then
        if cached.char~=pd.Character or not cached.hl.Parent then
            pcall(function() cached.hl:Destroy() end); PlayerChamsCache[pd.Player]=nil; lastChamsProps[pd.Player]=nil; cached=nil
        else return cached.hl end
    end
    local ok,h=pcall(function()
        local hl=Instance.new("Highlight"); hl.Name="AegisC"; hl.Adornee=pd.Character; hl.Parent=pd.Character; return hl
    end)
    if ok and h then PlayerChamsCache[pd.Player]={hl=h,char=pd.Character}; return h end; return nil
end
local function RemovePlayerHighlight(player)
    local cached=PlayerChamsCache[player]; if cached then pcall(function() cached.hl:Destroy() end); PlayerChamsCache[player]=nil end
    lastChamsProps[player]=nil
end
local function SetChamsProps(hl,player,fc,oc,ft,ot,dm)
    local last=lastChamsProps[player]
    if last and last.fc==fc and last.oc==oc and last.ft==ft and last.ot==ot and last.dm==dm then return end
    hl.FillColor=fc; hl.OutlineColor=oc; hl.FillTransparency=ft; hl.OutlineTransparency=ot; hl.DepthMode=dm; hl.Enabled=true
    lastChamsProps[player]={fc=fc,oc=oc,ft=ft,ot=ot,dm=dm}
end
local function UpdatePlayerChams(pd)
    if pd.Player==LocalPlayer then RemovePlayerHighlight(pd.Player); return end
    local hum=GetHumanoid(pd.Character); if not hum or hum.Health<=0 then RemovePlayerHighlight(pd.Player); return end
    if not Toggles.ChamsEnabled.Value then RemovePlayerHighlight(pd.Player); return end
    if pd.IsEnemy     and not Toggles.ChamsShowEnemy.Value  then RemovePlayerHighlight(pd.Player); return end
    if not pd.IsEnemy and not pd.IsFriend and not Toggles.ChamsShowTeam.Value then RemovePlayerHighlight(pd.Player); return end
    if pd.IsFriend    and not Toggles.ChamsShowFriend.Value then RemovePlayerHighlight(pd.Player); return end
    local fc,oc,ft,ot
    if pd.IsFriend then fc=Options.ChamsFriendColor.Value; oc=Options.ChamsFriendOutline.Value; ft=Options.ChamsFriendColor.Transparency; ot=Options.ChamsFriendOutline.Transparency
    elseif pd.IsEnemy then fc=Options.ChamsEnemyColor.Value; oc=Options.ChamsEnemyOutline.Value; ft=Options.ChamsEnemyColor.Transparency; ot=Options.ChamsEnemyOutline.Transparency
    else fc=Options.ChamsTeamColor.Value; oc=Options.ChamsTeamOutline.Value; ft=Options.ChamsTeamColor.Transparency; ot=Options.ChamsTeamOutline.Transparency end
    if Toggles.VisibleChamsEnabled.Value and IsCharacterVisible(pd.Character) then
        fc=Options.VisibleChamsColor.Value; oc=Options.VisibleChamsOutline.Value; ft=Options.VisibleChamsColor.Transparency; ot=Options.VisibleChamsOutline.Transparency
    end
    if Toggles.ChamsVisibleOnly.Value then
        if not IsCharacterVisible(pd.Character) then RemovePlayerHighlight(pd.Player); return end
        fc=pd.IsFriend and Options.VisibleFriendColor.Value or (pd.IsEnemy and Options.VisibleEnemyColor.Value or Options.VisibleTeamColor.Value)
    end
    local dm=Toggles.ChamsVisibleOnly.Value and Enum.HighlightDepthMode.Occluded or Enum.HighlightDepthMode.AlwaysOnTop
    local hl=GetOrCreatePlayerHighlight(pd); if not hl then return end
    SetChamsProps(hl,pd.Player,fc,oc,ft,ot,dm)
end
local function UpdateWorldChams()
    if not Toggles.ChamsWorldEnabled.Value then
        for i in pairs(WorldChamsCache) do pcall(function() WorldChamsCache[i]:Destroy() end); WorldChamsCache[i]=nil end; return end
    if tick()-S.lastWorldChamsUpdate<0.5 then return end; S.lastWorldChamsUpdate=tick()
    local function A(objs,co,oo)
        for _,obj in pairs(objs) do
            if not obj.Parent then continue end
            if not WorldChamsCache[obj] then
                local ok,h=pcall(function() local hl=Instance.new("Highlight"); hl.Name="AWC"; hl.Adornee=obj; hl.Parent=obj; return hl end)
                if ok and h then WorldChamsCache[obj]=h end
            end
            local hl=WorldChamsCache[obj]; if not hl then continue end
            hl.FillColor=co.Value; hl.OutlineColor=oo.Value; hl.FillTransparency=co.Transparency; hl.OutlineTransparency=oo.Transparency
            hl.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop; hl.Enabled=true
        end
    end
    local function AB(objs,showEnemy,showTeam,eFill,eOut,tFill,tOut)
        for _,obj in pairs(objs) do
            if not obj.Parent then continue end
            local side=GetBuildingTeam(obj)
            local visible=(side=="enemy" and showEnemy.Value) or (side=="team" and showTeam.Value)
            if not visible then local hl=WorldChamsCache[obj]; if hl then hl.Enabled=false end; continue end
            if not WorldChamsCache[obj] then
                local ok,h=pcall(function() local hl=Instance.new("Highlight"); hl.Name="AWC"; hl.Adornee=obj; hl.Parent=obj; return hl end)
                if ok and h then WorldChamsCache[obj]=h end
            end
            local hl=WorldChamsCache[obj]; if not hl then continue end
            local isEnemy=(side=="enemy")
            hl.FillColor=isEnemy and eFill.Value or tFill.Value; hl.OutlineColor=isEnemy and eOut.Value or tOut.Value
            hl.FillTransparency=isEnemy and eFill.Transparency or tFill.Transparency
            hl.OutlineTransparency=isEnemy and eOut.Transparency or tOut.Transparency
            hl.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop; hl.Enabled=true
        end
    end
    A(cachedHP,Options.HealthChamsColor,Options.HealthChamsOutline)
    A(cachedAmmo,Options.AmmoChamsColor,Options.AmmoChamsOutline)
    AB(cachedSentries,Toggles.SentryChamsEnemy,Toggles.SentryChamsTeam,Options.SentryChamsEnemyColor,Options.SentryChamsEnemyOutline,Options.SentryChamsTeamColor,Options.SentryChamsTeamOutline)
    AB(cachedDispensers,Toggles.DispenserChamsEnemy,Toggles.DispenserChamsTeam,Options.DispenserChamsEnemyColor,Options.DispenserChamsEnemyOutline,Options.DispenserChamsTeamColor,Options.DispenserChamsTeamOutline)
    AB(cachedTeleporters,Toggles.TeleporterChamsEnemy,Toggles.TeleporterChamsTeam,Options.TeleporterChamsEnemyColor,Options.TeleporterChamsEnemyOutline,Options.TeleporterChamsTeamColor,Options.TeleporterChamsTeamOutline)
end
local function UpdateProjectileChams()
    if not Toggles.ChamsProjectilesEnabled.Value then
        for i in pairs(ProjectileChamsCache) do pcall(function() ProjectileChamsCache[i]:Destroy() end); ProjectileChamsCache[i]=nil end; return end
    if tick()-S.lastProjChamsUpdate<0.3 then return end; S.lastProjChamsUpdate=tick()
    for _,obj in pairs(GetProjectiles()) do
        if not ProjectileChamsCache[obj] then
            local ok,h=pcall(function() local hl=Instance.new("Highlight"); hl.Name="APC"; hl.Adornee=obj; hl.Parent=obj; return hl end)
            if ok and h then ProjectileChamsCache[obj]=h end
        end
        local hl=ProjectileChamsCache[obj]; if not hl then continue end
        hl.FillColor=Options.ProjectileChamsColor.Value; hl.OutlineColor=Options.ProjectileChamsOutline.Value
        hl.FillTransparency=Options.ProjectileChamsColor.Transparency; hl.OutlineTransparency=Options.ProjectileChamsOutline.Transparency
        hl.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop; hl.Enabled=true
    end
end

local AccChamsCache={}
local function UpdateAccChams()
    if not (Toggles.ChamsEnabled and Toggles.ChamsEnabled.Value) then
        for _,hl in pairs(AccChamsCache) do pcall(function() hl.Enabled=false end) end; return end
    local seen={}
    for _,pd in ipairs(FrameCache.playerData or {}) do
        if pd.Player==LocalPlayer then continue end
        local char=pd.Character; if not char then continue end
        local hum=char:FindFirstChildOfClass("Humanoid"); if not hum or hum.Health<=0 then if AccChamsCache[pd.Player] then pcall(function() AccChamsCache[pd.Player].Enabled=false end) end; continue end
        if pd.IsEnemy and not (Toggles.ChamsShowEnemy and Toggles.ChamsShowEnemy.Value) then if AccChamsCache[pd.Player] then pcall(function() AccChamsCache[pd.Player].Enabled=false end) end; continue end
        if not pd.IsEnemy and pd.IsFriend and not (Toggles.ChamsShowFriend and Toggles.ChamsShowFriend.Value) then if AccChamsCache[pd.Player] then pcall(function() AccChamsCache[pd.Player].Enabled=false end) end; continue end
        if not pd.IsEnemy and not pd.IsFriend and not (Toggles.ChamsShowTeam and Toggles.ChamsShowTeam.Value) then if AccChamsCache[pd.Player] then pcall(function() AccChamsCache[pd.Player].Enabled=false end) end; continue end
        local tool=char:FindFirstChildOfClass("Tool"); if not tool then if AccChamsCache[pd.Player] then pcall(function() AccChamsCache[pd.Player].Enabled=false end) end; continue end
        seen[pd.Player]=true
        local hl=AccChamsCache[pd.Player]
        if not hl or not hl.Parent or hl.Adornee~=tool then
            if hl then pcall(function() hl:Destroy() end) end
            local ok,newhl=pcall(function()
                local h=Instance.new("Highlight"); h.Name="AegisWeaponOutline"; h.Adornee=tool; h.Parent=tool; h.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop; return h
            end)
            AccChamsCache[pd.Player]=ok and newhl or nil; hl=AccChamsCache[pd.Player]
        end
        if not hl then continue end
        local fc,oc,ft,ot
        if pd.IsFriend then fc=Options.ChamsFriendColor.Value; oc=Options.ChamsFriendOutline.Value; ft=Options.ChamsFriendColor.Transparency; ot=Options.ChamsFriendOutline.Transparency
        elseif pd.IsEnemy then fc=Options.ChamsEnemyColor.Value; oc=Options.ChamsEnemyOutline.Value; ft=Options.ChamsEnemyColor.Transparency; ot=Options.ChamsEnemyOutline.Transparency
        else fc=Options.ChamsTeamColor.Value; oc=Options.ChamsTeamOutline.Value; ft=Options.ChamsTeamColor.Transparency; ot=Options.ChamsTeamOutline.Transparency end
        pcall(function() hl.FillColor=fc; hl.OutlineColor=oc; hl.FillTransparency=ft; hl.OutlineTransparency=ot; hl.Enabled=true end)
    end
    for p,hl in pairs(AccChamsCache) do if not seen[p] then pcall(function() hl.Enabled=false end) end end
end

-- Automation
local Auto={}
function Auto.UpdateUsernameHider()
    if not Toggles.UsernameHider.Value then return end
    if tick()-S.lastUsernameUpdate<1 then return end; S.lastUsernameUpdate=tick()
    local fn=Options.FakeUsername.Value~="" and Options.FakeUsername.Value or "Player"
    pcall(function()
        local pg=LocalPlayer:FindFirstChild("PlayerGui"); if not pg then return end
        for _,g in pairs(pg:GetDescendants()) do
            if g:IsA("TextLabel") and (g.Text==LocalPlayer.Name or g.Text==LocalPlayer.DisplayName) then g.Text=fn end
        end
    end)
end
function Auto.CheckAutoUber()
    if not Config.AutoUber.Enabled then return end; if not IsPlayerAlive(LocalPlayer) then return end
    pcall(function()
        if LocalPlayer:FindFirstChild("Status") and LocalPlayer.Status.Class.Value~="Doctor" then return end
        local char=LocalPlayer.Character; if not char then return end
        local hum=GetHumanoid(char); if not hum or hum.Health<=0 then return end
        local uberReady=false
        pcall(function() local L=LocalPlayer.PlayerGui.GUI.Client.LegacyLocalVariables; local uber=L:FindFirstChild("uber"); if uber and uber.Value>=100 then uberReady=true end end)
        if not uberReady then return end
        local myPct=(hum.Health/hum.MaxHealth)*100; local threshold=Config.AutoUber.HealthPercent
        if Config.AutoUber.Condition=="Self" or Config.AutoUber.Condition=="Both" then if myPct<=threshold then RightClick(); return end end
        if Config.AutoUber.Condition=="HealTarget" or Config.AutoUber.Condition=="Both" then
            pcall(function()
                local L=LocalPlayer.PlayerGui.GUI.Client.LegacyLocalVariables
                local ht=L:FindFirstChild("healtarget"); if not ht or ht.Value=="" then return end
                local tp=Players:FindFirstChild(ht.Value)
                if tp and tp.Character then local th=GetHumanoid(tp.Character); if th and (th.Health/th.MaxHealth)*100<=threshold then RightClick() end end
            end)
        end
    end)
end
function Auto.RunAutoAirblast()
    if not (Toggles.AutoAirblast and Toggles.AutoAirblast.Value) then return end
    if tick()-S.lastAirblastTime<0.2 then return end; if not IsPlayerAlive(LocalPlayer) then return end
    pcall(function()
        if LocalPlayer:FindFirstChild("Status") and LocalPlayer.Status.Class.Value~="Arsonist" then return end
        local lc=GetLocalCharacter(); if not lc then return end; local lhrp=GetHRP(lc); if not lhrp then return end
        local ri=Workspace:FindFirstChild("Ray_ignore")
        if ri then for _,v in pairs(ri:GetChildren()) do
            if v:GetAttribute("ProjectileType") and v:GetAttribute("Team")~=LocalPlayer.Status.Team.Value then
                local _,OnScr=Camera:WorldToViewportPoint(v.Position)
                if OnScr and (v.Position-lhrp.Position).Magnitude<=13 then RightClick(); S.lastAirblastTime=tick(); return end
            end
        end end
        local dest=Workspace:FindFirstChild("Destructable")
        if dest then for _,v in pairs(dest:GetChildren()) do
            if v.Name:match("stickybomb") and v:GetAttribute("Team")~=LocalPlayer.Status.Team.Value then
                local _,OnScr=Camera:WorldToViewportPoint(v.Position)
                if OnScr and (v.Position-lhrp.Position).Magnitude<=13 then RightClick(); S.lastAirblastTime=tick(); return end
            end
        end end
        if Toggles.AutoAirblastExt and Toggles.AutoAirblastExt.Value then
            for _,plr in pairs(cachedPlayerList) do
                if plr~=LocalPlayer and plr.Character and plr.Team==LocalPlayer.Team then
                    local conds=plr.Character:FindFirstChild("Conditions")
                    if conds and conds:GetAttribute("Engulfed") then
                        local head=plr.Character:FindFirstChild("Head")
                        if head and (head.Position-lhrp.Position).Magnitude<=13 then RightClick(); S.lastAirblastTime=tick(); return end
                    end
                end
            end
        end
    end)
end
function Auto.RunSilentAimLogic()
    do local char=LocalPlayer.Character
        if char then local deadVal=char:FindFirstChild("Dead"); if deadVal and deadVal.Value==true then
            if S.shooting then VIM:SendMouseButtonEvent(0,0,0,false,game,0); S.shooting=false end
            S.silentAimKeyActive=false; return
        end end
    end
    local prof=GetActiveSAProfile()
    Config.SilentAim.Enabled=(Toggles[prof.enabled] and Toggles[prof.enabled].Value) or false
    if not Config.SilentAim.Enabled then
        if S.shooting then VIM:SendMouseButtonEvent(0,0,0,false,game,0); S.shooting=false end
        S.silentAimKeyActive=false; return
    end
    local globalAlwaysOn=Toggles.GlobalAimAlwaysOn and Toggles.GlobalAimAlwaysOn.Value
    local globalKeyActive=globalAlwaysOn or (Options.GlobalAimKey and Options.GlobalAimKey:GetState()) or false
    if not IsPlayerAlive(LocalPlayer) then if S.shooting then VIM:SendMouseButtonEvent(0,0,0,false,game,0); S.shooting=false end; return end
    local weapon=GetLocalWeapon(); if BlacklistedWeapons[weapon] then return end
    local target=FrameCache.silentTarget; local autoOn=Toggles[prof.autoShoot] and Toggles[prof.autoShoot].Value
    if target and autoOn then
        S.silentAimKeyActive=true
        if not S.shooting then VIM:SendMouseButtonEvent(0,0,0,true,game,0); S.shooting=true; S.lastShotTime=tick()
        elseif tick()-S.lastShotTime>=S.shotInterval then
            VIM:SendMouseButtonEvent(0,0,0,false,game,0); VIM:SendMouseButtonEvent(0,0,0,true,game,0); S.lastShotTime=tick()
        end
    else
        if S.shooting then VIM:SendMouseButtonEvent(0,0,0,false,game,0); S.shooting=false end
        S.silentAimKeyActive=isMobileMode or globalKeyActive
    end
end
function Auto.RunAutoWarp(playerData)
    if not (Toggles.AutoWarp and Toggles.AutoWarp.Value and Options.WarpKey:GetState()) then return end
    if tick()-S.lastWarpTime<1 then return end
    if GetLocalClass()~="Agent" or not BackstabWeapons[GetLocalWeapon()] then return end
    local lc=GetLocalCharacter(); local lh=lc and GetHRP(lc); if not lh then return end
    for _,pd in ipairs(playerData) do
        if not pd.IsEnemy or pd.Distance>BACKSTAB_RANGE then continue end
        local toT=(lh.Position-pd.HRP.Position).Unit
        if toT:Dot(pd.HRP.CFrame.LookVector)>0 then
            lh.CFrame=CFrame.lookAt(pd.HRP.Position-pd.HRP.CFrame.LookVector*3,pd.HRP.Position)
            S.lastWarpTime=tick(); Notify("Warped behind "..pd.Player.Name,1.5); break
        end
    end
end
function Auto.RunAntiAim(dt)
    if not Config.AntiAim.Enabled then return end
    local char=LocalPlayer.Character; if not char then return end
    local hrp=GetHRP(char); if not hrp then return end
    pcall(function() char:SetAttribute("NoAutoRotate",true) end)
    if not LocalPlayer:GetAttribute("ThirdPerson") then return end
    local fwd=Vector3.new(Camera.CFrame.LookVector.X,0,Camera.CFrame.LookVector.Z).Unit
    local nl
    if Config.AntiAim.Mode=="backwards" then nl=-fwd
    elseif Config.AntiAim.Mode=="jitter" then
        if tick()-S.lastJitterUpdate>=1/Config.AntiAim.JitterSpeed then S.jitterDir=-S.jitterDir; S.lastJitterUpdate=tick() end
        local y=math.rad(Config.AntiAim.JitterAngle*S.jitterDir)
        nl=Vector3.new(math.cos(y)*fwd.X-math.sin(y)*fwd.Z,0,math.sin(y)*fwd.X+math.cos(y)*fwd.Z).Unit
    elseif Config.AntiAim.Mode=="spin" then
        S.spinAngle=S.spinAngle+math.rad(Config.AntiAim.AntiAimSpeed*dt)
        nl=Vector3.new(math.sin(S.spinAngle),0,math.cos(S.spinAngle))
    end
    if nl then hrp.CFrame=CFrame.new(hrp.Position,hrp.Position+nl) end
end
function Auto.RunAutoBackstab(playerData)
    if not (Toggles.AutoBackstab and Toggles.AutoBackstab.Value) then return end
    if GetLocalClass()~="Agent" or not BackstabWeapons[GetLocalWeapon()] then return end
    local lc=GetLocalCharacter(); local lh=lc and GetHRP(lc); if not lh then return end
    local foundTarget=false
    for _,pd in ipairs(playerData) do
        if not pd.IsEnemy or pd.Distance>BACKSTAB_RANGE then continue end
        if Toggles.BackstabIgnoreInvis and Toggles.BackstabIgnoreInvis.Value and IsCharacterInvisible(pd.Character) then continue end
        local toT=(pd.HRP.Position-lh.Position).Unit
        if toT:Dot(pd.HRP.CFrame.LookVector)>0.3 then
            if not HasLineOfSight(lh.Position,pd.HRP.Position) then continue end
            foundTarget=true
            if S.lastBackstabTarget~=pd.Player then S.lastBackstabTarget=pd.Player; Notify("Backstab: "..pd.Player.Name,2) end
            if tick()-S.lastShotTime>=0.15 then
                pcall(function() local L=LocalPlayer.PlayerGui.GUI.Client.LegacyLocalVariables; L.Held.Value=true; task.wait(0.05); L.Held.Value=false end)
                S.shooting=true; S.lastShotTime=tick()
            end; break
        end
    end
    if not foundTarget and S.lastBackstabTarget then S.lastBackstabTarget=nil end
end
function Auto.RunAutoMelee(playerData)
    if not (Toggles.AutoMelee and Toggles.AutoMelee.Value) then return end
    if Toggles.AutoBackstab and Toggles.AutoBackstab.Value and GetLocalClass()=="Agent" then return end
    if not MeleeWeapons[GetLocalWeapon()] then return end
    local lc=GetLocalCharacter(); local lh=lc and GetHRP(lc); if not lh then return end
    local meleeRange=(Options.AutoMeleeMode and Options.AutoMeleeMode.Value=="Demoknight") and MELEE_RANGE_DEMOKNIGHT or MELEE_RANGE_RAGE
    for _,pd in ipairs(playerData) do
        if not pd.IsEnemy or pd.Distance>meleeRange then continue end
        if Toggles.MeleeIgnoreInvis and Toggles.MeleeIgnoreInvis.Value and IsCharacterInvisible(pd.Character) then continue end
        if not HasLineOfSight(lh.Position,pd.HRP.Position) then continue end
        S.lastMeleeTarget=pd.Player
        if tick()-S.lastShotTime>=0.15 then FireShot(); S.shooting=true; S.lastShotTime=tick() end; return
    end; S.lastMeleeTarget=nil
end
function Auto.RunAutoSticky(playerData)
    if not (Toggles.AutoStickyDetonate and Toggles.AutoStickyDetonate.Value) then return end
    local stickies=GetMyStickybombs(); if #stickies==0 then return end
    for _,sticky in pairs(stickies) do
        for _,pd in ipairs(playerData) do
            if pd.IsEnemy and (sticky.Position-pd.HRP.Position).Magnitude<=10 then
                if not (Toggles.AutoStickyVisibleOnly and Toggles.AutoStickyVisibleOnly.Value) or IsPartVisible(sticky) then
                    pcall(function() local L=LocalPlayer.PlayerGui.GUI.Client.LegacyLocalVariables; L.Held2.Value=true; task.wait(0.05); L.Held2.Value=false end); return
                end
            end
        end
    end
end
function Auto.RunPredictionIndicator()
    if not (Toggles.ShowPredictionIndicator and Toggles.ShowPredictionIndicator.Value and Config.SilentAim.Enabled and S.silentAimKeyActive) then PredictionIndicator.Visible=false; return end
    local weapon=GetLocalWeapon()
    if not (ProjectileWeapons[weapon] or ChargeWeapons[weapon]) then PredictionIndicator.Visible=false; return end
    local target,targetPlr=FrameCache.silentTarget,FrameCache.silentTargetPlr
    if target and targetPlr then
        local predicted=PredictProjectileHit(target,targetPlr,weapon)
        if predicted then
            local sp,onScreen=WorldToViewportPoint(predicted)
            if onScreen then
                PredictionIndicator.Text="+"
                PredictionIndicator.Position=sp-Vector2.new(0,30)
                PredictionIndicator.Color=Options.PredictionIndicatorColor and Options.PredictionIndicatorColor.Value or Color3.new(0,1,1)
                PredictionIndicator.Visible=true; return
            end
        end
    end; PredictionIndicator.Visible=false
end

UIS.InputBegan:Connect(function(input,processed)
    if processed or _Unloaded then return end
    if Toggles.HealSelfToggle and Toggles.HealSelfToggle.Value then
        pcall(function()
            if Options.HealSelfKey:GetState() then
                Workspace[LocalPlayer.Name].Doctor.ChangeValue:FireServer("Target",LocalPlayer.Name)
            end
        end)
    end
end)

task.defer(function()
    local function TrackCharacter(plr)
        if plr==LocalPlayer then return end
        local char=plr.Character; if not char then return end
        local hum=char:FindFirstChildOfClass("Humanoid"); if not hum then return end
        healthCache[plr]=hum.Health
        hum.HealthChanged:Connect(function(newHealth) healthCache[plr]=newHealth end)
    end
    for _,plr in ipairs(cachedPlayerList) do
        if plr.Character then TrackCharacter(plr) end
        plr.CharacterAdded:Connect(function() task.wait(0.3); TrackCharacter(plr) end)
    end
    Players.PlayerAdded:Connect(function(plr) plr.CharacterAdded:Connect(function() task.wait(0.3); TrackCharacter(plr) end) end)
end)

LogService.MessageOut:Connect(function(message)
    if type(message)~="string" then return end
    if message:find("HIT_DEBUG") and tick()-S.lastHitDebugNotif>2 then Notify("Shot rejected by server",3); S.lastHitDebugNotif=tick() end
end)

task.defer(function()
    local notifiedCheaters={}
    local function CheckCheater(player)
        if player==LocalPlayer then return end
        if CheaterList[player.UserId] and not notifiedCheaters[player.UserId] then notifiedCheaters[player.UserId]=true; Notify("known cheater: "..player.Name,10) end
    end
    for _,p in ipairs(cachedPlayerList) do task.spawn(function() task.wait(2); CheckCheater(p) end) end
    Players.PlayerAdded:Connect(function(player) task.wait(1); CheckCheater(player); if CheaterList[player.UserId] then Notify("known cheater joined: "..player.Name,10) end end)
    Players.PlayerRemoving:Connect(function(p) notifiedCheaters[p.UserId]=nil end)
end)

task.defer(function()
    local STAFF_ATTRS={"IsGroupCoder","IsGroupContributor","IsGroupDeveloper","IsGroupMapper","IsGroupModerator","IsGroupTester"}
    local alreadyNotified={}
    local function CheckPlayerForStaff(player)
        if player==LocalPlayer then return end
        local ntp=player:FindFirstChild("newTcPlayer"); if not ntp then return end
        local found={}
        for _,attr in ipairs(STAFF_ATTRS) do
            local val=ntp:GetAttribute(attr)
            if val and val~=false and val~=0 and val~="" then table.insert(found,attr:gsub("IsGroup","")) end
        end
        if #found>0 then
            local key=player.UserId; local label=table.concat(found,"/")
            if alreadyNotified[key]~=label then alreadyNotified[key]=label; Notify("staff in server: "..player.Name.." ["..label.."]",10) end
        end
    end
    local function HookNTP(player) local ntp=player:FindFirstChild("newTcPlayer"); if not ntp then return end; ntp.AttributeChanged:Connect(function() pcall(CheckPlayerForStaff,player) end); pcall(CheckPlayerForStaff,player) end
    local function SetupPlayer(player) task.spawn(function() task.wait(2); pcall(HookNTP,player); player.ChildAdded:Connect(function(child) if child.Name=="newTcPlayer" then task.wait(0.5); pcall(HookNTP,player) end end) end) end
    for _,p in ipairs(cachedPlayerList) do SetupPlayer(p) end
    Players.PlayerAdded:Connect(SetupPlayer)
    Players.PlayerRemoving:Connect(function(p) alreadyNotified[p.UserId]=nil end)
end)

local RH={}
function RH.UpdateDmgMod()
    local ptype=GetCurrentProfileType(); local tog="DmgMod_"..ptype
    Config.DmgMod.Enabled=Toggles[tog] and Toggles[tog].Value or false
    if Config.DmgMod.Enabled then
        local infTog="DmgModInf_"..ptype
        if Toggles[infTog] and Toggles[infTog].Value then Config.DmgMod.Multiplier=math.huge
        else local opt="DmgModMult_"..ptype; Config.DmgMod.Multiplier=Options[opt] and Options[opt].Value or 3 end
    end
end
function RH.UpdateFOVCircle()
    local prof=GetActiveSAProfile()
    if Config.SilentAim.Enabled and Toggles[prof.fovCircle] and Toggles[prof.fovCircle].Value then
        FOVCircle.Position=FrameCache.screenCenter; FOVCircle.Radius=Options[prof.fov] and Options[prof.fov].Value or 200
        FOVCircle.Color=Options.FOVColor and Options.FOVColor.Value or Color3.new(1,1,1); FOVCircle.Visible=true
    else FOVCircle.Visible=false end
end
function RH.UpdatePlayerESP(playerData)
    local processed={}
    for _,pd in ipairs(playerData) do
        processed[pd.Player]=true
        if Toggles.ESPEnabled.Value then CreatePlayerESP(pd.Player); UpdatePlayerESP(pd) else HidePlayerESP(pd.Player) end
        UpdatePlayerChams(pd)
    end
    for p in pairs(ESPObjects) do if not processed[p] then HidePlayerESP(p) end end
end
function RH.UpdateObjectESP()
    if Toggles.ObjESPEnabled.Value then
        local act={}
        local function PB(cache,enemyTog,teamTog,label)
            for _,o in pairs(cache) do
                if not o.Parent then continue end
                local side=GetBuildingTeam(o)
                local show=(side=="enemy" and enemyTog.Value) or (side=="team" and teamTog.Value)
                if show then local col=side=="enemy" and Options.ObjESPEnemyColor.Value or Options.ObjESPTeamColor.Value; act[o]=true; UpdateObjectESP(o,label,col) end
            end
        end
        PB(cachedSentries,Toggles.ObjESPEnemySentry,Toggles.ObjESPTeamSentry,"Sentry")
        PB(cachedDispensers,Toggles.ObjESPEnemyDispenser,Toggles.ObjESPTeamDispenser,"Dispenser")
        PB(cachedTeleporters,Toggles.ObjESPEnemyTeleporter,Toggles.ObjESPTeamTeleporter,"Teleporter")
        local function PP(cache,tog,name)
            if tog.Value then for _,o in pairs(cache) do if o.Parent then act[o]=true; UpdateObjectESP(o,name,Options.ObjESPBoxColor.Value) end end end
        end
        PP(cachedAmmo,Toggles.ObjESPAmmo,"Ammo"); PP(cachedHP,Toggles.ObjESPHP,"HP")
        for i in pairs(ObjectESPCache) do if not act[i] or not i.Parent then HideObjectESP(i) end end
    else for i in pairs(ObjectESPCache) do HideObjectESP(i) end end
end
function RH.UpdateTelestab(playerData)
    if not (Toggles.TelestabToggle.Value and Options.TelestabKey:GetState()) then return end
    local lc=GetLocalCharacter(); if not lc then return end; local lh=GetHRP(lc); if not lh then return end
    local bestChar,bestDist2=nil,9e9
    for _,pd in ipairs(playerData) do if pd.IsEnemy and pd.Distance<bestDist2 then bestDist2=pd.Distance; bestChar=pd.Character end end
    if bestChar then
        for _,v in pairs(bestChar:GetChildren()) do if v:IsA("BasePart") then v.CanCollide=false end end
        local uh=GetHRP(bestChar); if uh then uh.CFrame=lh.CFrame+lh.CFrame.LookVector*3.25 end
    end
end
function RH.AgentNotify(playerData)
    if not (Toggles.AgentNotification and Toggles.AgentNotification.Value and tick()-S.lastAgentNotif>3) then return end
    for _,pd in ipairs(playerData) do
        if pd.IsEnemy and pd.Class=="Agent" and pd.Distance<=30 then Notify("Enemy Agent nearby! ("..pd.Player.Name..")",3); S.lastAgentNotif=tick(); break end
    end
end

task.spawn(InstallDmgMod)

local MainConnection=RunService.RenderStepped:Connect(function(dt)
    if _Unloaded then return end
    Camera=Workspace.CurrentCamera; S.frames=S.frames+1; visibilityCache={}
    FrameCache.camPos=Camera.CFrame.Position; FrameCache.camCF=Camera.CFrame
    FrameCache.screenCenter=Vector2.new(Camera.ViewportSize.X/2,Camera.ViewportSize.Y/2)
    FrameCache.frameNum=FrameCache.frameNum+1
    EnsureGUILoaded(); UpdateVelocityTracking()
    if S.isCharging then local w=GetLocalWeapon(); local cd=ChargeWeapons[w]; if cd then S.currentChargePercent=math.clamp((tick()-S.chargeStartTime)/cd.ChargeTime,0,1) end end
    FrameCache.playerData=BuildPlayerData()
    FrameCache.silentTarget,FrameCache.silentTargetPlr=GetSilentAimTarget(FrameCache.playerData)
    local playerData=FrameCache.playerData
    Auto.RunSilentAimLogic(); Auto.RunAutoWarp(playerData); UpdateAimArms()
    RH.UpdateDmgMod(); RH.UpdateFOVCircle(); Auto.RunPredictionIndicator()
    RH.UpdatePlayerESP(playerData); RH.UpdateObjectESP()
    UpdateWorldChams(); UpdateProjectileChams(); UpdateAccChams()
    if Toggles.UsernameHider.Value then Auto.UpdateUsernameHider() end
    RH.AgentNotify(playerData); Auto.RunAntiAim(dt); RH.UpdateTelestab(playerData)
    Auto.RunAutoBackstab(playerData); Auto.RunAutoMelee(playerData)
    Auto.RunAutoSticky(playerData); Auto.RunAutoAirblast(); Auto.CheckAutoUber()
    if Toggles.CustomFOV and Toggles.CustomFOV.Value then Camera.FieldOfView=Options.CustomFOVAmount.Value end
end)

task.spawn(function() while true do task.wait(1); if _Unloaded then break end; S.fps=S.frames; S.frames=0 end end)
task.spawn(function() while true do task.wait(1); if _Unloaded then break end
    local ping=0; pcall(function() ping=math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue()) end)
    local plain=("aegis.dev  |  %d fps  |  %d ms  |  %s"):format(S.fps,ping,os.date("%H:%M:%S"))
    if wmOn then WMF.Size=UDim2.fromOffset(TxtSvc:GetTextSize(plain,12,T.Font,Vector2.new(9999,9999)).X+16,22) end
end end)

Players.PlayerRemoving:Connect(function(player)
    DestroyPlayerESP(player); RemovePlayerHighlight(player)
    healthCache[player]=nil; playerVelocities[player]=nil; playerAccelerations[player]=nil
    playerVerticalHistory[player]=nil; playerStrafeHistory[player]=nil; playerPositionHistory[player]=nil
    lastChamsProps[player]=nil
end)

local function Unload()
    _Unloaded=true
    for p in pairs(ESPObjects) do DestroyPlayerESP(p) end
    for i in pairs(ObjectESPCache) do DestroyObjectESP(i) end
    for p in pairs(PlayerChamsCache) do RemovePlayerHighlight(p) end
    for i in pairs(WorldChamsCache) do pcall(function() WorldChamsCache[i]:Destroy() end) end
    for i in pairs(ProjectileChamsCache) do pcall(function() ProjectileChamsCache[i]:Destroy() end) end
    for _,hl in pairs(AccChamsCache) do pcall(function() hl:Destroy() end) end
    FOVCircle:Remove(); pcall(function() PredictionIndicator:Remove() end)
    DestroyMobileButton()
    if OL then Lighting.Ambient=OL.Ambient; Lighting.Brightness=OL.Brightness; Lighting.FogEnd=OL.FogEnd; Lighting.FogStart=OL.FogStart; Lighting.ClockTime=OL.ClockTime; Lighting.OutdoorAmbient=OL.OutdoorAmbient end
    if S.speedConnection then S.speedConnection:Disconnect() end
    pcall(function() if Toggles.MaxRangeToggle and Toggles.MaxRangeToggle.Value then SetMaxRange(false) end end)
    pcall(RestoreFireRate)
    if _infCloakConn then pcall(function() _infCloakConn:Disconnect() end) end
    if _infShieldConn then pcall(function() _infShieldConn:Disconnect() end) end
    for _,c in pairs(_profileInfUseConns) do pcall(function() c:Disconnect() end) end
    for _,c in pairs(_profileInfResConns) do pcall(function() c:Disconnect() end) end
    if _dmgModInstalled and _dmgModFrameworks.Weapons and _dmgModOrig then pcall(function() _dmgModFrameworks.Weapons.returndamagemod=_dmgModOrig end) end
    if wallbangHook then pcall(function() hookmetamethod(game,"__index",wallbangHook) end) end
    MainConnection:Disconnect(); S.shooting=false; playerPositionHistory={}
    print("[Aegis] Unloaded!")
end
CX.MouseButton1Click:Connect(Unload)

task.spawn(function()
    local snd=Instance.new("Sound"); snd.SoundId="rbxassetid://91541918714984"; snd.Volume=2; snd.Parent=workspace
    snd:Play(); snd.Ended:Wait(); snd:Destroy()
end)

print("[aegis.dev] durrr")
end -- end _runBackend
_runBackend()
