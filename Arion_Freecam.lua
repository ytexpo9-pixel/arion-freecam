-- ARION FREECAM / v7.2 - acceso FOV flotante, compatible con v7.1
-- Cliente Roblox (Delta movil + PC). Sin grabacion, sin anclar al personaje.
-- Interfaz de pestañas, dock rapido, control CINE independiente, luz reversible,
-- reset/deshacer integral. F8 o doble toque esquina superior izquierda: recuperar.

-- I. ARRANQUE SEGURO: conservar la secuencia compatible con Lite v3 / v4B.
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local CAS = game:GetService("ContextActionService")
local Run = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local player = Players.LocalPlayer
if not player then warn("[Arion v7] LocalPlayer no disponible"); return end
local pg = player:FindFirstChildOfClass("PlayerGui") or player:WaitForChild("PlayerGui", 8)
if not pg then warn("[Arion v7] PlayerGui no disponible"); return end

local registry = _G
pcall(function()
    if type(getgenv)=="function" then
        local g=getgenv()
        if type(g)=="table" then registry=g end
    end
end)
for _,key in ipairs({"__ArionFreecamV7Stop", "__ArionModularV4Stop", "__ArionFreecamV3Stop"}) do
    if type(registry[key])=="function" then pcall(registry[key]) end
end
for _,name in ipairs({"ArionFreecamFinal", "ArionFreecamModular", "ArionFreecamLite", "Arion Camera"}) do
    local old=pg:FindFirstChild(name)
    if old then pcall(function() old:Destroy() end) end
end

local R={connections={},closed=false,renderBound=false,moveBound=false,hidden={}}
local S={
    active=false, speed=24, sensitivity=.005, smooth=true, smoothStrength=16,
    pos=nil, pitch=0, yaw=0, cam=nil, saved=nil, axis=Vector2.zero,
    rise=false, fall=false, held={}, cineHeld={},
    target=nil, watch=nil, locked=false, aim=1, offset=Vector3.new(0,3,12),
    zoom=false, zoomValue=.5, zoomFactor=1, baseFov=70, cinePanelOpen=true,
    light=0, darkness=0, lightBase=nil, grade=nil,
    mode=1, tab="MOVE", panelOpen=false, quickEnabled=true, otherHUD=false,
    controlsOpacity=.68, quickOpacity=.9, cineOpacity=.88,
    fovOverlayOpen=false, snapshot=nil
}
local Input=Enum.UserInputType
local Keys=Enum.KeyCode
local rgb=Color3.fromRGB
local dim=UDim2.new
local px=UDim2.fromOffset
local C={
    bg=rgb(15,18,25), surface=rgb(24,28,38), elevated=rgb(35,40,53),
    button=rgb(42,48,63), line=rgb(65,73,91), accent=rgb(91,139,211),
    text=rgb(232,238,246), muted=rgb(163,175,194),
    on=rgb(55,119,105), off=rgb(108,55,65), focus=rgb(69,90,126)
}
local function add(signal,callback)
    local c=signal:Connect(callback)
    table.insert(R.connections,c)
    return c
end
local function make(kind,parent,props)
    local item=Instance.new(kind)
    for k,v in pairs(props or {}) do item[k]=v end
    item.Parent=parent
    return item
end
local function rounded(item,r)
    make("UICorner",item,{CornerRadius=UDim.new(0,r)})
end
local function panel(parent,name,size,pos,color,z,r)
    local obj=make("Frame",parent,{Name=name,Size=size,Position=pos,
        BackgroundColor3=color or C.surface,BorderSizePixel=0,ZIndex=z or 10})
    rounded(obj,r or 12)
    return obj
end
local function text(parent,name,value,size,pos,z,fontSize,bold)
    return make("TextLabel",parent,{Name=name,Text=value,Size=size,Position=pos,
        BackgroundTransparency=1,Font=bold and Enum.Font.GothamBold or Enum.Font.Gotham,
        TextColor3=C.text,TextSize=fontSize or 13,TextXAlignment=Enum.TextXAlignment.Left,
        TextTruncate=Enum.TextTruncate.AtEnd,ZIndex=z or 10})
end
local function button(parent,name,value,size,pos,z,color)
    local obj=make("TextButton",parent,{Name=name,Text=value,Size=size,Position=pos,
        BackgroundColor3=color or C.button,BorderSizePixel=0,TextColor3=C.text,
        Font=Enum.Font.GothamMedium,TextSize=13,TextTruncate=Enum.TextTruncate.AtEnd,
        AutoButtonColor=true,ZIndex=z or 10})
    rounded(obj,9)
    return obj
end
local function safe(callback)
    return function(...)
        if R.closed then return end
        local ok,err=pcall(callback,...)
        if not ok then warn("[Arion v7] "..tostring(err)) end
    end
end
local function tap(obj,callback) return add(obj.Activated,safe(callback)) end
local function viewport()
    local size=workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize
    if not size or size.X<100 or size.Y<100 then size=Vector2.new(800,480) end
    return size
end
local function rootSize(root)
    local size=root.AbsoluteSize
    if size.X<100 or size.Y<100 then return viewport() end
    return size
end
local function clampPosition(root,obj,p)
    local s=rootSize(root)
    local w=s.X*obj.Size.X.Scale+obj.Size.X.Offset
    local h=s.Y*obj.Size.Y.Scale+obj.Size.Y.Offset
    obj.Position=px(math.clamp(p.X,0,math.max(0,s.X-w)),
        math.clamp(p.Y,0,math.max(0,s.Y-h)))
end
local function findPos(root,obj)
    return obj.AbsolutePosition-root.AbsolutePosition
end
local function copy(t)
    if not t then return nil end
    local n={}
    for k,v in pairs(t) do n[k]=v end
    return n
end

-- II. GUI DE ALTA PRIORIDAD. La GUI no depende del estado de la camara.
local gui=make("ScreenGui",nil,{Name="ArionFreecamFinal",ResetOnSpawn=false,
    Enabled=true,DisplayOrder=800,ZIndexBehavior=Enum.ZIndexBehavior.Global})
local attached=false
for _,dest in ipairs({pg}) do
    local ok=pcall(function() gui.Parent=dest end)
    if ok and gui.Parent==dest then attached=true;break end
end
if not attached and type(gethui)=="function" then
    local ok,dest=pcall(gethui)
    if ok and dest then
        attached=pcall(function() gui.Parent=dest end) and gui.Parent==dest
    end
end
if not attached then warn("[Arion v7] No fue posible crear ScreenGui");return end
local root=make("Frame",gui,{Name="Root",Size=UDim2.fromScale(1,1),
    BackgroundTransparency=1,Active=false,ZIndex=1})
local look=make("Frame",root,{Name="LookArea",Size=UDim2.fromScale(1,1),
    BackgroundTransparency=1,Active=true,Visible=false,ZIndex=2})

-- Controles de movimiento tactil: bajos, discretos y fuera del centro.
local pad=panel(root,"MovePad",px(116,116),dim(0,14,1,-132),C.elevated,5,58)
pad.Active=true
local stick=panel(pad,"Stick",px(38,38),UDim2.fromScale(.5,.5),C.accent,6,19)
stick.AnchorPoint=Vector2.new(.5,.5)
stick.Active=true
local up=button(root,"Rise","SUBIR",px(62,46),dim(1,-76,1,-118),6)
local down=button(root,"Fall","BAJAR",px(62,46),dim(1,-76,1,-67),6)

local launcher=button(root,"ArionLauncher","AR",px(54,45),px(12,13),37,C.focus)
launcher.TextSize=17
local quick=panel(root,"QuickDock",px(64,303),dim(1,-72,0,12),C.surface,31,11)
make("UIStroke",quick,{Color=C.line,Thickness=1,Transparency=.46})
local qHandle=text(quick,"QuickDrag","MOVER",px(56,25),px(5,4),33,10,true)
qHandle.Active=true
local qPower=button(quick,"QuickPower","CAM",px(54,42),px(5,34),33,C.off)
local qCinema=button(quick,"QuickCinema","CINE",px(54,42),px(5,81),33)
local qSmooth=button(quick,"QuickSmooth","SUAVE",px(54,42),px(5,128),33)
local qReset=button(quick,"QuickReset","RESET",px(54,42),px(5,175),33,C.off)
local qUndo=button(quick,"QuickUndo","UNDO",px(54,42),px(5,222),33)
local qMinimize=button(quick,"QuickFold","-",px(54,26),px(5,269),33)
-- Acceso FOV exterior, sin cambiar posiciones ni tamano del dock existente.
local qFov=button(root,"QuickFOV","FOV",px(60,42),dim(1,-138,0,12),36,C.focus)
qFov.TextSize=13

-- Barra FOV independiente: parte inferior central, como en el ArionCam original.
local fovOverlay=panel(root,"FOVFloating",px(320,78),dim(.5,0,1,-16),C.surface,43,12)
fovOverlay.AnchorPoint=Vector2.new(.5,1)
fovOverlay.Visible=false;fovOverlay.Active=true
make("UIStroke",fovOverlay,{Color=C.line,Thickness=1,Transparency=.46})
local fovLabel=text(fovOverlay,"FOVValue","FOV BASE  /  70",dim(1,-64,0,23),px(14,7),46,13,true)
local fovClose=button(fovOverlay,"FOVClose","X",px(34,28),dim(1,-40,0,5),47)
-- La zona tactil tiene 36 px de altura, pero el rail visible sigue siendo discreto.
local fovTouch=make("Frame",fovOverlay,{Name="FOVTouchTarget",Size=dim(1,-30,0,36),
    Position=px(15,34),BackgroundTransparency=1,Active=true,ZIndex=45})
local fovRail=panel(fovTouch,"FOVTrack",dim(1,-14,0,8),px(7,14),C.line,46,4)
local fovKnob=panel(fovRail,"FOVKnob",px(24,24),UDim2.fromScale((70-30)/90,.5),C.accent,47,12)
fovKnob.AnchorPoint=Vector2.new(.5,.5)
fovRail.Active=true;fovKnob.Active=true

-- Control cinematografico FLOTANTE, separado del panel de configuracion.
local cine=panel(root,"CinematicController",px(194,276),dim(1,-276,0,60),C.surface,38,12)
make("UIStroke",cine,{Color=C.line,Thickness=1,Transparency=.46})
local cineHandle=text(cine,"CinematicDrag","CINE  /  MOVER",px(145,27),px(10,4),41,12,true)
cineHandle.Active=true
local cineClose=button(cine,"CinematicHide","-",px(35,29),px(153,3),41)
local cineUp=button(cine,"CineUp","▲",px(50,42),px(72,40),41)
local cineLeft=button(cine,"CineLeft","◀",px(50,42),px(14,86),41)
local cineDown=button(cine,"CineDown","▼",px(50,42),px(72,86),41)
local cineRight=button(cine,"CineRight","▶",px(50,42),px(130,86),41)
local cineForward=button(cine,"CineForward","AVANZAR",px(82,37),px(9,137),41)
local cineBack=button(cine,"CineBack","RETROCEDER",px(87,37),px(98,137),41)
local cineZoomMinus=button(cine,"CineZoomMinus","ZOOM -",px(84,35),px(9,181),41)
local cineZoomPlus=button(cine,"CineZoomPlus","ZOOM +",px(87,35),px(98,181),41)
local cineZoomRail=panel(cine,"CineZoomTrack",px(164,7),px(15,240),C.line,40,4)
local cineZoomKnob=panel(cineZoomRail,"CineZoomKnob",px(22,22),UDim2.fromScale(.5,.5),C.accent,42,11)
cineZoomKnob.AnchorPoint=Vector2.new(.5,.5)
cineZoomRail.Active=true
cineZoomKnob.Active=true
local cineZoomLabel=text(cine,"CineZoomLabel","Zoom 0%  /  neutro",px(172,18),px(11,219),41,10)

-- Panel con pestañas: no hay que recorrer una unica lista interminable.
local menu=panel(root,"ArionPanel",px(304,458),px(69,11),C.bg,48,13)
menu.Visible=false
make("UIStroke",menu,{Color=C.line,Thickness=1,Transparency=.4})
local header=text(menu,"PanelDrag","ARION / FREECAM",dim(1,-92,0,35),px(12,5),51,14,true)
header.Active=true
local mini=button(menu,"Minimize","-",px(34,34),dim(1,-80,0,5),52)
local close=button(menu,"Close","X",px(34,34),dim(1,-41,0,5),52,C.off)
local menuPower=button(menu,"MainPower","CAMARA APAGADA",dim(1,-20,0,39),px(10,45),51,C.off)
local tabs=panel(menu,"Tabs",dim(1,-16,0,37),px(8,91),C.surface,50,8)
local tabItems={}
local tabNames={{"MOVE","MOV"},{"CINE","CINE"},{"LIGHT","LUZ"},{"PLAYERS","LOCK"},{"UI","GUI"}}
for n,entry in ipairs(tabNames) do
    local b=button(tabs,"Tab"..entry[1],entry[2],dim(.2,-4,1,-4),dim((n-1)*.2,2,0,2),52)
    b.TextSize=11
    tabItems[entry[1]]=b
end
local pages={}
for _,entry in ipairs(tabNames) do
    local page=make("ScrollingFrame",menu,{Name="Page"..entry[1],
        Size=dim(1,-18,1,-181),Position=px(9,135),BackgroundTransparency=1,
        ScrollBarThickness=3,ScrollBarImageColor3=C.accent,BorderSizePixel=0,
        CanvasSize=px(0,0),AutomaticCanvasSize=Enum.AutomaticSize.Y,
        ScrollingDirection=Enum.ScrollingDirection.Y,ZIndex=50,Visible=false})
    make("UIListLayout",page,{SortOrder=Enum.SortOrder.LayoutOrder,Padding=UDim.new(0,6)})
    pages[entry[1]]=page
end
local status=text(menu,"Status","Listo",dim(1,-20,0,31),dim(0,11,1,-36),52,10)
status.TextColor3=C.muted
local function notice(msg)
    status.Text=tostring(msg)
    print("[Arion v7] "..tostring(msg))
end
local function row(page,name,value,order)
    local item=button(page,name,value,dim(1,-5,0,39),px(0,0),52)
    item.LayoutOrder=order
    return item
end
local function section(page,value,order)
    local title=text(page,"Section"..order,value,dim(1,-6,0,23),px(2,0),51,11,true)
    title.LayoutOrder=order
    title.TextColor3=C.muted
    return title
end

-- Control de opacidad que respeta transparencia original de cada elemento.
local baseVisual={}
local function fadeTree(obj,opacity)
    local function apply(item)
        if item:IsA("Frame") or item:IsA("TextButton") or item:IsA("TextLabel") then
            if not baseVisual[item] then
                baseVisual[item]={bg=item.BackgroundTransparency,
                    txt=(item:IsA("TextButton") or item:IsA("TextLabel")) and item.TextTransparency or nil}
            end
            local origin=baseVisual[item]
            item.BackgroundTransparency=origin.bg+(1-origin.bg)*(1-opacity)
            if origin.txt~=nil then item.TextTransparency=origin.txt+(1-origin.txt)*(1-opacity) end
        end
        if item:IsA("UIStroke") then
            if not baseVisual[item] then baseVisual[item]={stroke=item.Transparency} end
            local original=baseVisual[item].stroke
            item.Transparency=original+(1-original)*(1-opacity)
        end
        for _,child in ipairs(item:GetChildren()) do apply(child) end
    end
    apply(obj)
end

-- III. ILUMINACION FOTOGRAFICA: neutro = escena original, valores reversibles.
local function rememberLighting()
    if S.lightBase then return end
    S.lightBase={
        Brightness=Lighting.Brightness,
        ExposureCompensation=Lighting.ExposureCompensation,
        Ambient=Lighting.Ambient,
        OutdoorAmbient=Lighting.OutdoorAmbient
    }
end
local function restoreLighting()
    local old=S.lightBase
    if old then
        pcall(function() Lighting.Brightness=old.Brightness end)
        pcall(function() Lighting.ExposureCompensation=old.ExposureCompensation end)
        pcall(function() Lighting.Ambient=old.Ambient end)
        pcall(function() Lighting.OutdoorAmbient=old.OutdoorAmbient end)
    end
    if S.grade then pcall(function() S.grade:Destroy() end) end
    S.grade=nil; S.lightBase=nil
end
local function applyLighting()
    if S.light==0 and S.darkness==0 then
        restoreLighting()
        return
    end
    rememberLighting()
    local base=S.lightBase
    local lum=S.light/100
    local dark=S.darkness/100
    if not S.grade or not S.grade.Parent then
        S.grade=make("ColorCorrectionEffect",Lighting,{Name="ArionColorGradeV7",
            Enabled=true,Brightness=0,Contrast=0,Saturation=0})
    end
    local newBrightness=math.max(0,base.Brightness*(1+1.15*lum-.76*dark))
    local exposure=math.clamp(base.ExposureCompensation+2.8*lum-3.7*dark,-5,5)
    local black=rgb(0,0,0)
    pcall(function() Lighting.Brightness=newBrightness end)
    pcall(function() Lighting.ExposureCompensation=exposure end)
    pcall(function() Lighting.Ambient=base.Ambient:Lerp(black,dark*.98) end)
    pcall(function() Lighting.OutdoorAmbient=base.OutdoorAmbient:Lerp(black,dark*.98) end)
    S.grade.Brightness=math.clamp(.2*lum-.58*dark,-.85,.3)
    S.grade.Contrast=math.clamp(.12*math.abs(lum)+.24*dark,0,.5)
end

-- IV. CONTROLES DE VALOR: rail de gestos con actualizacion inmediata.
local sliders={}
local pointer={drag=nil,slider=nil,stick=nil,look=nil,lookAt=nil,mouseLook=false,
    zoom=nil,lastRecoverTap=-10}
local refreshUI
local function vec(i) return Vector2.new(i.Position.X,i.Position.Y) end
local function makeSlider(page,name,order,initial,titleFormatter,onValue)
    local trigger=row(page,name,titleFormatter(initial),order)
    local shell=panel(page,name.."Shell",dim(1,-5,0,36),px(0,0),C.surface,51,8)
    shell.LayoutOrder=order+1; shell.Visible=false; shell.Active=true
    local rail=panel(shell,name.."Rail",dim(1,-26,0,7),dim(0,13,.5,-4),C.line,52,4)
    local knob=panel(rail,name.."Knob",px(20,20),UDim2.fromScale(initial,.5),C.accent,53,10)
    knob.AnchorPoint=Vector2.new(.5,.5)
    rail.Active=true;knob.Active=true
    local item={name=name,initial=initial,value=initial,shell=shell,
        rail=rail,knob=knob,trigger=trigger}
    function item.set(v,notify)
        v=math.clamp(v,0,1)
        item.value=v
        knob.Position=UDim2.fromScale(v,.5)
        trigger.Text=titleFormatter(v)
        if notify then
            onValue(v)
            if refreshUI then refreshUI() end
        end
    end
    local function beginSlide(i)
        if pointer.slider or pointer.drag then return end
        if i.UserInputType==Input.Touch or i.UserInputType==Input.MouseButton1 then
            pointer.slider={input=i,mouse=i.UserInputType==Input.MouseButton1,
                update=function(p)
                    item.set((p.X-rail.AbsolutePosition.X)/math.max(1,rail.AbsoluteSize.X),true)
                end}
            pointer.slider.update(vec(i))
        end
    end
    -- En Roblox el evento del hijo (rail/knob) no siempre llega al contenedor.
    add(shell.InputBegan,beginSlide)
    add(rail.InputBegan,beginSlide)
    add(knob.InputBegan,beginSlide)
    tap(trigger,function() shell.Visible=not shell.Visible end)
    table.insert(sliders,item)
    return item
end
local function setZoom(v)
    S.zoomValue=math.clamp(v,0,1)
    local t=2*S.zoomValue-1
    S.zoomFactor=t>0 and 2^(-1.5*t) or 2^(-t)
    cineZoomKnob.Position=UDim2.fromScale(S.zoomValue,.5)
    cineZoomLabel.Text=string.format("Zoom: %+d%%",math.floor((S.zoomValue-.5)*200+.5))
end

section(pages.MOVE,"CAMARA Y MOVIMIENTO",1)
local speedSlider=makeSlider(pages.MOVE,"SpeedControl",10,(24-4)/116,
    function(v) return string.format("Velocidad  /  %d",math.floor(4+116*v+.5)) end,
    function(v) S.speed=math.floor(4+116*v+.5) end)
local sensitivitySlider=makeSlider(pages.MOVE,"SensitivityControl",20,.5,
    function(v) return string.format("Sensibilidad  /  %.1f",1+8*v) end,
    function(v) S.sensitivity=.001+.008*v end)
local smoothToggle=row(pages.MOVE,"SmoothToggle","Suavizado: ON",30)
local smoothSlider=makeSlider(pages.MOVE,"SmoothStrength",40,(16-2)/28,
    function(v) return string.format("Intensidad suave  /  %d",math.floor(2+28*v+.5)) end,
    function(v) S.smoothStrength=math.floor(2+28*v+.5) end)
local fovSlider=makeSlider(pages.MOVE,"FieldOfView",50,(70-30)/90,
    function(v) return string.format("FOV base  /  %d",math.floor(30+90*v+.5)) end,
    function(v) S.baseFov=math.floor(30+90*v+.5) end)
local movementHint=text(pages.MOVE,"MoveHint",
    "PC: WASD / QE / boton derecho. Movil: pad y mirada.",
    dim(1,-8,0,34),px(0,0),51,11)
movementHint.TextWrapped=true;movementHint.LayoutOrder=60;movementHint.TextColor3=C.muted

section(pages.CINE,"CAMARA CINEMATOGRAFICA",1)
local cinemaToggle=row(pages.CINE,"CinemaToggle","Cine: OFF",10)
local cinemaShow=row(pages.CINE,"CinePanelToggle","Control flotante: MOSTRAR",20)
local cinemaHint=text(pages.CINE,"CinemaHelp",
    "Los controles CINE aparecen FUERA del panel. Mantener flechas para desplazar; ZOOM +/- o deslizar rail.",
    dim(1,-8,0,61),px(0,0),51,11)
cinemaHint.LayoutOrder=30;cinemaHint.TextWrapped=true;cinemaHint.TextColor3=C.muted
local zoomReset=row(pages.CINE,"ZoomReset","Restablecer zoom a neutro",40)

section(pages.LIGHT,"EXPOSICION Y SOMBRAS",1)
local brightnessSlider=makeSlider(pages.LIGHT,"LightExposure",10,.5,
    function(v) return string.format("Luz  /  %+d%%",math.floor((v-.5)*200+.5)) end,
    function(v) S.light=math.floor((v-.5)*200+.5);applyLighting() end)
local darknessSlider=makeSlider(pages.LIGHT,"Darkness",20,0,
    function(v) return string.format("Oscuridad  /  %d%%",math.floor(v*100+.5)) end,
    function(v) S.darkness=math.floor(v*100+.5);applyLighting() end)
local lightReset=row(pages.LIGHT,"ResetLight","Restaurar iluminacion original",30)
local lightHelp=text(pages.LIGHT,"LightHelp",
    "Luz neutral: 0%. Oscuridad neutral: 0%. Los cambios se restauran al reiniciar o cerrar.",
    dim(1,-8,0,62),px(0,0),51,11)
lightHelp.LayoutOrder=40;lightHelp.TextWrapped=true;lightHelp.TextColor3=C.muted

section(pages.PLAYERS,"SEGUIMIENTO Y OBJETIVOS",1)
local watchNav=panel(pages.PLAYERS,"WatchNavigation",dim(1,-5,0,42),px(0,0),C.surface,51,8)
watchNav.LayoutOrder=10
local prevPlayer=button(watchNav,"PreviousPlayer","<",px(43,39),px(2,1),52)
local watchPlayer=button(watchNav,"WatchPlayer","Ver jugador",dim(1,-98,0,39),px(49,1),52)
local nextPlayer=button(watchNav,"NextPlayer",">",px(43,39),dim(1,-45,0,1),52)
local pick=row(pages.PLAYERS,"ChoosePlayer","Seleccionar jugador",20)
local picker=panel(pages.PLAYERS,"PlayerPicker",dim(1,