-- ARION FREECAM / v7.1 - correccion RESET/UNDO sin apertura automatica del panel
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
    snapshot=nil
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
local picker=panel(pages.PLAYERS,"PlayerPicker",dim(1,-5,0,174),px(0,0),C.surface,51,8)
picker.LayoutOrder=21;picker.Visible=false
local search=make("TextBox",picker,{Name="SearchPlayers",Text="",PlaceholderText="Buscar usuario...",
    ClearTextOnFocus=false,Size=dim(1,-10,0,39),Position=px(5,5),
    BackgroundColor3=C.elevated,TextColor3=C.text,PlaceholderColor3=C.muted,
    Font=Enum.Font.Gotham,TextSize=12,ZIndex=53})
rounded(search,7)
local playerList=make("ScrollingFrame",picker,{Name="PlayerList",
    Size=dim(1,-10,1,-52),Position=px(5,49),BackgroundTransparency=1,
    BorderSizePixel=0,ScrollBarThickness=3,CanvasSize=px(0,0),
    AutomaticCanvasSize=Enum.AutomaticSize.Y,ZIndex=52})
make("UIListLayout",playerList,{SortOrder=Enum.SortOrder.LayoutOrder,
    Padding=UDim.new(0,3)})
local aimButton=row(pages.PLAYERS,"AimPart","Apuntar: Torso",30)
local lockButton=row(pages.PLAYERS,"LockPlayer","Activar lock",40)
local clearWatch=row(pages.PLAYERS,"StopWatching","Dejar de seguir jugador",50)

section(pages.UI,"INTERFAZ Y ACCESO RAPIDO",1)
local modeButton=row(pages.UI,"VisualMode","Interfaz: Completa",10)
local hudButton=row(pages.UI,"HideOtherGUI","Ocultar interfaces del juego",20)
local quickButton=row(pages.UI,"QuickEnabled","Barra rapida: ON",30)
local controlOpacitySlider=makeSlider(pages.UI,"ControlOpacity",40,.68,
    function(v) return string.format("Opacidad tactil  /  %d%%",math.floor(v*100+.5)) end,
    function(v) S.controlsOpacity=v end)
local quickOpacitySlider=makeSlider(pages.UI,"QuickOpacity",50,.9,
    function(v) return string.format("Opacidad barra rapida  /  %d%%",math.floor(v*100+.5)) end,
    function(v) S.quickOpacity=v end)
local cineOpacitySlider=makeSlider(pages.UI,"CineOpacity",60,.88,
    function(v) return string.format("Opacidad panel CINE  /  %d%%",math.floor(v*100+.5)) end,
    function(v) S.cineOpacity=v end)
local guiHint=text(pages.UI,"GuiHint",
    "Arrastra AR, cabecera, MOVER y CINE. F8 o doble toque en esquina izquierda para recuperar modo invisible.",
    dim(1,-8,0,58),px(0,0),51,11)
guiHint.TextWrapped=true;guiHint.LayoutOrder=70;guiHint.TextColor3=C.muted
local recover=button(root,"RecoverUI","",px(76,76),px(0,0),65)
recover.Visible=false;recover.TextTransparency=1;recover.BackgroundTransparency=1

-- V. MOTOR DE CAMARA (ejecuta solo si esta encendido).
local Camera={render="ArionFreecamV7Render",action="ArionFreecamV7Move"}
local function resetInputs()
    pointer.stick=nil;pointer.look=nil;pointer.lookAt=nil;pointer.mouseLook=false
    pointer.slider=nil;pointer.zoom=nil
    S.axis=Vector2.zero;S.rise=false;S.fall=false
    S.held={};S.cineHeld={}
    stick.Position=UDim2.fromScale(.5,.5)
end
local function restoreCurrent()
    local cam,old=S.cam,S.saved
    S.cam=nil;S.saved=nil
    if not cam or not old then return end
    pcall(function()
        if not cam.Parent then return end
        cam.CFrame=old.cframe
        cam.Focus=old.focus
        cam.FieldOfView=old.fov
        if old.subject and old.subject.Parent then
            cam.CameraSubject=old.subject
        else
            local char=player.Character
            local hum=char and char:FindFirstChildOfClass("Humanoid")
            if hum then cam.CameraSubject=hum end
        end
        cam.CameraType=old.kind
    end)
end
local function attachCurrent()
    local cam=workspace.CurrentCamera
    if not cam then return false end
    S.cam=cam
    S.saved={kind=cam.CameraType,subject=cam.CameraSubject,
        cframe=cam.CFrame,focus=cam.Focus,fov=cam.FieldOfView}
    S.pos=cam.CFrame.Position
    S.pitch,S.yaw=cam.CFrame:ToOrientation()
    cam.CameraType=Enum.CameraType.Scriptable
    return true
end
local function torso(p)
    local char=p and p.Character
    if not char then return nil end
    local obj=char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")
        or char:FindFirstChild("HumanoidRootPart")
    return obj and obj.Position or nil
end
local function targetPosition(p)
    local char=p and p.Character
    if not char then return nil end
    if S.aim==2 then
        local head=char:FindFirstChild("Head")
        if head then return head.Position end
    elseif S.aim==3 then
        local lower=char:FindFirstChild("LowerTorso")
        if lower then return lower.Position end
        local classic=char:FindFirstChild("Torso")
        if classic then
            return classic.CFrame:PointToWorldSpace(Vector3.new(0,-classic.Size.Y*.3,0))
        end
    end
    return torso(p)
end
local function key(name)
    return S.held[name] and 1 or 0
end
local function cineKey(name)
    return S.cineHeld[name] and 1 or 0
end
local function updateCamera(dt)
    if not S.active then return end
    if workspace.CurrentCamera~=S.cam then
        restoreCurrent()
        if not attachCurrent() then return end
    end
    local cam=S.cam
    if not cam then return end
    if cam.CameraType~=Enum.CameraType.Scriptable then cam.CameraType=Enum.CameraType.Scriptable end
    local rotation=CFrame.fromOrientation(S.pitch,S.yaw,0)
    local cineX=cineKey("right")-cineKey("left")
    local cineY=cineKey("up")-cineKey("down")
    local cineZ=cineKey("back")-cineKey("forward")
    local dir=Vector3.new(
        S.axis.X+key("D")-key("A")+cineX,
        (S.rise and 1 or 0)-(S.fall and 1 or 0)+key("E")-key("Q")+cineY,
        S.axis.Y+key("S")-key("W")+cineZ
    )
    if dir.Magnitude>1 then dir=dir.Unit end
    local dtCap=math.min(math.max(dt,0),.075)
    local motion=rotation:VectorToWorldSpace(dir)*S.speed*dtCap
    local watchPos=torso(S.watch)
    if watchPos then
        S.offset=S.offset+motion
        S.pos=watchPos+S.offset
    else
        if S.watch then S.watch=nil end
        S.pos=S.pos+motion
    end
    local aim=S.locked and targetPosition(S.target) or watchPos
    if S.locked and not aim then S.locked=false end
    local goal=CFrame.new(S.pos)*rotation
    if aim and (aim-S.pos).Magnitude>.01 then
        goal=CFrame.lookAt(S.pos,aim)
        S.pitch,S.yaw=goal:ToOrientation()
    end
    local blend=S.smooth and (1-math.exp(-S.smoothStrength*dtCap)) or 1
    cam.CFrame=blend>=1 and goal or cam.CFrame:Lerp(goal,blend)
    cam.Focus=CFrame.new(aim or (cam.CFrame.Position+cam.CFrame.LookVector*18))
    cam.FieldOfView=math.clamp(S.baseFov*(S.zoom and S.zoomFactor or 1),5,120)
end
function Camera.stop()
    if R.renderBound then
        pcall(function() Run:UnbindFromRenderStep(Camera.render) end)
        R.renderBound=false
    end
    if R.moveBound then
        pcall(function() CAS:UnbindAction(Camera.action) end)
        R.moveBound=false
    end
    S.active=false
    resetInputs()
    restoreCurrent()
    if refreshUI then refreshUI() end
end
function Camera.start()
    if S.active then return true end
    local ok,attached=pcall(attachCurrent)
    if not ok or not attached then
        notice("Camara no disponible")
        Camera.stop()
        return false
    end
    local actionOK,actionError=pcall(function()
        CAS:BindActionAtPriority(Camera.action,function(_,state,input)
            if UIS:GetFocusedTextBox() then return Enum.ContextActionResult.Pass end
            local k=input.KeyCode.Name
            if k=="W" or k=="A" or k=="S" or k=="D" or k=="Q" or k=="E" then
                S.held[k]=(state==Enum.UserInputState.Begin or state==Enum.UserInputState.Change)
            end
            return Enum.ContextActionResult.Sink
        end,false,3100,Keys.W,Keys.A,Keys.S,Keys.D,Keys.Q,Keys.E,
        Enum.PlayerActions.CharacterForward,Enum.PlayerActions.CharacterBackward,
        Enum.PlayerActions.CharacterLeft,Enum.PlayerActions.CharacterRight,
        Enum.PlayerActions.CharacterJump)
    end)
    R.moveBound=actionOK
    if not actionOK then warn("[Arion v7] Accion PC no vinculada: "..tostring(actionError)) end
    local runOK,runErr=pcall(function()
        Run:BindToRenderStep(Camera.render,Enum.RenderPriority.Camera.Value+1,function(dt)
            local good,errorMessage=pcall(updateCamera,dt)
            if not good then
                warn("[Arion v7] Motor de camara: "..tostring(errorMessage))
                Camera.stop()
                notice("Camara detenida: error de motor")
            end
        end)
    end)
    if not runOK then
        notice("No se pudo iniciar: "..tostring(runErr))
        Camera.stop()
        return false
    end
    R.renderBound=true;S.active=true
    if refreshUI then refreshUI() end
    notice("Camara activa")
    return true
end

-- VI. GUARDADO / RESTAURACION DE INTERFACES DEL JUEGO.
local function hideGameHUD(hidden)
    if hidden then
        for _,element in ipairs(pg:GetChildren()) do
            if element:IsA("ScreenGui") and element~=gui and R.hidden[element]==nil then
                R.hidden[element]=element.Enabled
                element.Enabled=false
            end
        end
    else
        for element,value in pairs(R.hidden) do
            pcall(function() if element.Parent then element.Enabled=value end end)
        end
        R.hidden={}
    end
    S.otherHUD=hidden
    if refreshUI then refreshUI() end
end
add(pg.ChildAdded,function(element)
    if S.otherHUD and element:IsA("ScreenGui") and element~=gui and R.hidden[element]==nil then
        R.hidden[element]=element.Enabled
        element.Enabled=false
    end
end)

local roster={}
local function refreshRoster(leaving)
    roster={}
    for _,p in ipairs(Players:GetPlayers()) do
        if p~=player and p~=leaving then table.insert(roster,p) end
    end
    table.sort(roster,function(a,b) return a.Name:lower()<b.Name:lower() end)
    if S.target and not table.find(roster,S.target) then S.target=nil;S.locked=false end
    if S.watch and not table.find(roster,S.watch) then S.watch=nil end
    pick.Text=S.target and ("Objetivo: @"..S.target.Name) or "Seleccionar jugador"
    for _,child in ipairs(playerList:GetChildren()) do
        if child:IsA("TextButton") then child:Destroy() end
    end
    local needle=search.Text:lower()
    local visible=0
    for _,p in ipairs(roster) do
        if p.Name:lower():find(needle,1,true) then
            visible=visible+1
            local entry=button(playerList,"Player"..visible,"@"..p.Name,
                dim(1,-4,0,35),px(0,0),53)
            entry.LayoutOrder=visible
            -- Eventos de elementos dinamicos: al destruir el TextButton, se liberan.
            entry.Activated:Connect(safe(function()
                S.target=p
                pick.Text="Objetivo: @"..p.Name
                picker.Visible=false
                if refreshUI then refreshUI() end
            end))
        end
    end
    if refreshUI then refreshUI() end
end
local function watchStep(direction)
    if #roster==0 then notice("No hay jugadores para observar");return end
    if not S.active and not Camera.start() then return end
    local index=table.find(roster,S.watch) or (direction>0 and 0 or 1)
    S.watch=roster[(index-1+direction)%#roster+1]
    S.offset=Vector3.new(0,3,12)
    if refreshUI then refreshUI() end
end

local resetPanel=row(pages.UI,"ResetAll","RESET GENERAL",80)
local undoPanel=row(pages.UI,"UndoAll","DESHACER RESET",90)
S.quickFolded=false
local function layout()
    local size=rootSize(root)
    local width=math.min(310,math.max(195,size.X-83))
    local height=math.min(468,math.max(268,size.Y-20))
    menu.Size=px(width,height)
    -- En pantallas estrechas deja el dock rapido libre en el borde derecho.
    if size.X<650 and menu.Position.X.Scale==0 and menu.Position.X.Offset==69 then
        menu.Position=px(8,11)
    end
    -- La pagina se adapta a la altura real, sin fijar 420 px en pantallas pequenas.
    for _,page in pairs(pages) do page.Size=dim(1,-18,0,math.max(89,height-181)) end
    local function bound(obj)
        local p=obj.Position
        clampPosition(root,obj,Vector2.new(size.X*p.X.Scale+p.X.Offset,
            size.Y*p.Y.Scale+p.Y.Offset))
    end
    bound(launcher);bound(menu);bound(quick);bound(cine)
end
local function modeName()
    return ({"Completa","Minima","Invisible"})[S.mode]
end
refreshUI=function()
    if R.closed then return end
    local invisible=S.mode==3
    local minimal=S.mode==2
    launcher.Visible=not invisible
    menu.Visible=S.panelOpen and not invisible
    quick.Visible=not invisible and S.quickEnabled
    quick.Size=px(64,S.quickFolded and 113 or 303)
    for _,b in ipairs({qCinema,qSmooth,qReset,qUndo}) do b.Visible=not S.quickFolded end
    qMinimize.Position=px(5,S.quickFolded and 80 or 269)
    qMinimize.Text=S.quickFolded and "+" or "-"
    recover.Visible=invisible
    local small=rootSize(root).X<620
    cine.Visible=S.active and S.zoom and S.cinePanelOpen and not invisible and (not S.panelOpen or not small)
    look.Visible=S.active
    local touch=S.active and UIS.TouchEnabled
    pad.Visible=touch;up.Visible=touch;down.Visible=touch
    fadeTree(pad,invisible and 0 or (minimal and math.min(S.controlsOpacity,.30) or S.controlsOpacity))
    fadeTree(up,invisible and 0 or (minimal and math.min(S.controlsOpacity,.30) or S.controlsOpacity))
    fadeTree(down,invisible and 0 or (minimal and math.min(S.controlsOpacity,.30) or S.controlsOpacity))
    fadeTree(quick,S.quickOpacity)
    fadeTree(cine,S.cineOpacity)
    local enabled=S.active
    qPower.Text=enabled and "CAM ON" or "CAM OFF"
    qPower.BackgroundColor3=enabled and C.on or C.off
    menuPower.Text=enabled and "CAMARA ACTIVADA" or "CAMARA APAGADA"
    menuPower.BackgroundColor3=enabled and C.on or C.off
    qCinema.Text=S.zoom and "CINE ON" or "CINE"
    qCinema.BackgroundColor3=S.zoom and C.on or C.button
    qSmooth.Text=S.smooth and "SUAVE" or "SECO"
    qSmooth.BackgroundColor3=S.smooth and C.focus or C.button
    qUndo.Text=S.snapshot and "UNDO" or "SIN UNDO"
    qUndo.TextSize=S.snapshot and 11 or 9
    qUndo.BackgroundColor3=S.snapshot and C.focus or C.elevated
    cinemaToggle.Text=S.zoom and "Cine: ON  /  desactivar" or "Cine: OFF  /  activar"
    cinemaShow.Text=S.cinePanelOpen and "Panel flotante: VISIBLE" or "Panel flotante: OCULTO"
    smoothToggle.Text=S.smooth and "Suavizado: ON" or "Suavizado: OFF"
    watchPlayer.Text=S.watch and ("@"..S.watch.Name) or "Ver jugador"
    lockButton.Text=S.locked and "Desactivar Lock Jugador" or "Activar Lock Jugador"
    aimButton.Text=({"Apuntar: Torso","Apuntar: Cabeza","Apuntar: Torso bajo"})[S.aim]
    hudButton.Text=S.otherHUD and "Mostrar interfaces del juego" or "Ocultar interfaces del juego"
    modeButton.Text="Interfaz: "..modeName()
    quickButton.Text=S.quickEnabled and "Barra rapida: ON" or "Barra rapida: OFF"
    undoPanel.Text=S.snapshot and "DESHACER RESET" or "DESHACER (sin registro)"
    for key,page in pairs(pages) do page.Visible=(S.tab==key) end
    for key,tabButton in pairs(tabItems) do
        tabButton.BackgroundColor3=S.tab==key and C.focus or C.button
    end
end
local function setMode(value)
    S.mode=math.clamp(value,1,3)
    if S.mode~=1 then S.panelOpen=false end
    refreshUI()
end
local function openPanel(open)
    S.panelOpen=open
    refreshUI()
end
local function toggleCamera()
    if S.active then Camera.stop() else Camera.start() end
end
local function toggleCinema()
    if not S.active or not S.zoom then
        if not S.active and not Camera.start() then return end
        S.zoom=true;S.cinePanelOpen=true
        if rootSize(root).X<620 then S.panelOpen=false end
        notice("Cine activado. Arrastra CINE para mover el control")
    else
        S.zoom=false;S.cineHeld={}
        notice("Cine desactivado")
    end
    refreshUI()
end

-- VII. RESET INTEGRAL: captura antes de detener y deshacer simetrico.
local snapFields={"speed","sensitivity","smooth","smoothStrength","baseFov",
    "controlsOpacity","quickOpacity","cineOpacity","light","darkness",
    "aim","locked","target","watch","offset","zoom","zoomValue",
    "mode","tab","quickEnabled","quickFolded","cinePanelOpen",
    "otherHUD","active","pos","pitch","yaw"}
local function captureSnapshot()
    local shot={sliderValues={},sliderOpen={},pickerOpen=picker.Visible,
        searchText=search.Text,lightBase=copy(S.lightBase),
        positions={launcher=launcher.Position,menu=menu.Position,
            quick=quick.Position,cine=cine.Position}}
    for _,field in ipairs(snapFields) do shot[field]=S[field] end
    for _,item in ipairs(sliders) do
        shot.sliderValues[item.name]=item.value
        shot.sliderOpen[item.name]=item.shell.Visible
    end
    return shot
end
local function clearSliders()
    for _,item in ipairs(sliders) do
        item.set(item.initial,false)
        item.shell.Visible=false
    end
end
local function resetAll()
    if R.closed then return end
    S.snapshot=captureSnapshot()
    Camera.stop()
    hideGameHUD(false)
    restoreLighting()
    S.speed=24;S.sensitivity=.005;S.smooth=true;S.smoothStrength=16
    S.baseFov=70;S.light=0;S.darkness=0
    S.controlsOpacity=.68;S.quickOpacity=.9;S.cineOpacity=.88
    S.aim=1;S.locked=false;S.target=nil;S.watch=nil
    S.offset=Vector3.new(0,3,12);S.zoom=false;setZoom(.5)
    -- RESET cambia ajustes, no debe desplegar el panel si estaba cerrado.
    S.mode=1;S.tab="MOVE";S.quickEnabled=true
    S.quickFolded=false;S.cinePanelOpen=true;picker.Visible=false
    search.Text=""
    clearSliders()
    launcher.Position=px(12,13)
    menu.Position=px(69,11)
    quick.Position=dim(1,-72,0,12)
    cine.Position=dim(1,-276,0,60)
    layout();refreshRoster();refreshUI()
    notice("Reset completo. UNDO restaura la sesion anterior")
end
local function undoReset()
    local shot=S.snapshot
    if not shot then notice("No hay un reset para deshacer");return end
    Camera.stop()
    hideGameHUD(false)
    restoreLighting()
    for _,field in ipairs(snapFields) do S[field]=shot[field] end
    S.active=false -- Camera.start debe capturar otra vez la camara actual.
    for _,item in ipairs(sliders) do
        local v=shot.sliderValues[item.name]
        item.set(v~=nil and v or item.initial,false)
        item.shell.Visible=shot.sliderOpen[item.name] or false
    end
    search.Text=shot.searchText
    picker.Visible=shot.pickerOpen
    S.lightBase=copy(shot.lightBase)
    if S.light~=0 or S.darkness~=0 then
        applyLighting()
    else
        restoreLighting()
    end
    setZoom(shot.zoomValue)
    launcher.Position=shot.positions.launcher
    menu.Position=shot.positions.menu
    quick.Position=shot.positions.quick
    cine.Position=shot.positions.cine
    layout()
    refreshRoster()
    if shot.active and Camera.start() then
        S.pos=shot.pos or S.pos
        S.pitch=shot.pitch;S.yaw=shot.yaw
    end
    if shot.otherHUD then hideGameHUD(true) end
    S.snapshot=nil
    refreshUI()
    notice("Reset deshecho; ajustes recuperados")
end

-- VIII. GESTOS POR PUNTERO: arrastre real de paneles, no .Draggable.
local function startDrag(handle,target,callback)
    handle.Active=true
    add(handle.InputBegan,function(i)
        if pointer.drag or pointer.slider then return end
        if i.UserInputType~=Input.Touch and i.UserInputType~=Input.MouseButton1 then return end
        pointer.drag={input=i,mouse=i.UserInputType==Input.MouseButton1,
            start=vec(i),origin=findPos(root,target),target=target,
            onTap=callback,moved=false}
    end)
end
local function updatePad(point)
    local origin=pad.AbsolutePosition+pad.AbsoluteSize/2
    local d=(point-origin)/40
    S.axis=d.Magnitude>1 and d.Unit or d
    stick.Position=dim(.5,S.axis.X*34,.5,S.axis.Y*34)
end
local function updateZoomPoint(point)
    local v=(point.X-cineZoomRail.AbsolutePosition.X)/math.max(1,cineZoomRail.AbsoluteSize.X)
    setZoom(v)
end
local touchVertical={rise=nil,fall=nil}
local function holdVertical(obj,name)
    add(obj.InputBegan,function(i)
        if i.UserInputType==Input.Touch or i.UserInputType==Input.MouseButton1 then
            S[name]=true
            touchVertical[name]=i
        end
    end)
    add(obj.InputEnded,function(i)
        if i==touchVertical[name] or i.UserInputType==Input.MouseButton1 then
            S[name]=false;touchVertical[name]=nil
        end
    end)
end
holdVertical(up,"rise")
holdVertical(down,"fall")
local holdCine={}
local function cinePress(obj,name)
    add(obj.InputBegan,function(i)
        if i.UserInputType==Input.Touch or i.UserInputType==Input.MouseButton1 then
            if S.active and S.zoom then
                S.cineHeld[name]=true
                holdCine[name]=i
            end
        end
    end)
    add(obj.InputEnded,function(i)
        if i==holdCine[name] or i.UserInputType==Input.MouseButton1 then
            S.cineHeld[name]=nil;holdCine[name]=nil
        end
    end)
end
for _,entry in ipairs({{cineUp,"up"},{cineDown,"down"},
    {cineLeft,"left"},{cineRight,"right"},
    {cineForward,"forward"},{cineBack,"back"}}) do
    cinePress(entry[1],entry[2])
end
local function beginStick(i)
    if i.UserInputType==Input.Touch and not pointer.stick and S.active then
        pointer.stick=i;updatePad(vec(i))
    end
end
add(pad.InputBegan,beginStick)
add(stick.InputBegan,beginStick)
add(look.InputBegan,function(i)
    if i.UserInputType==Input.Touch and not pointer.look and not pointer.drag
        and not pointer.slider and S.active then
        pointer.look=i;pointer.lookAt=vec(i)
    end
end)
add(cineZoomRail.InputBegan,function(i)
    if i.UserInputType==Input.Touch or i.UserInputType==Input.MouseButton1 then
        pointer.zoom={input=i,mouse=i.UserInputType==Input.MouseButton1}
        updateZoomPoint(vec(i))
    end
end)
add(cineZoomKnob.InputBegan,function(i)
    if i.UserInputType==Input.Touch or i.UserInputType==Input.MouseButton1 then
        pointer.zoom={input=i,mouse=i.UserInputType==Input.MouseButton1}
        updateZoomPoint(vec(i))
    end
end)
add(UIS.InputChanged,function(i)
    local point=vec(i)
    local d=pointer.drag
    if d and (d.input==i or (d.mouse and i.UserInputType==Input.MouseMovement)) then
        local delta=point-d.start
        if delta.Magnitude>7 then d.moved=true end
        if d.moved then clampPosition(root,d.target,d.origin+delta) end
        return
    end
    local s=pointer.slider
    if s and (s.input==i or (s.mouse and i.UserInputType==Input.MouseMovement)) then
        s.update(point);return
    end
    local z=pointer.zoom
    if z and (z.input==i or (z.mouse and i.UserInputType==Input.MouseMovement)) then
        updateZoomPoint(point);return
    end
    if pointer.stick==i then updatePad(point);return end
    if pointer.look==i and S.active then
        local delta=point-pointer.lookAt
        pointer.lookAt=point
        S.yaw=S.yaw-delta.X*S.sensitivity
        S.pitch=math.clamp(S.pitch-delta.Y*S.sensitivity,-1.54,1.54)
    elseif pointer.mouseLook and S.active and i.UserInputType==Input.MouseMovement then
        S.yaw=S.yaw-i.Delta.X*S.sensitivity
        S.pitch=math.clamp(S.pitch-i.Delta.Y*S.sensitivity,-1.54,1.54)
    end
end)
add(UIS.InputEnded,function(i)
    local d=pointer.drag
    if d and (d.input==i or (d.mouse and i.UserInputType==Input.MouseButton1)) then
        pointer.drag=nil
        if not d.moved and d.onTap then safe(d.onTap)() end
    end
    local s=pointer.slider
    if s and (s.input==i or (s.mouse and i.UserInputType==Input.MouseButton1)) then
        pointer.slider=nil
    end
    local z=pointer.zoom
    if z and (z.input==i or (z.mouse and i.UserInputType==Input.MouseButton1)) then
        pointer.zoom=nil
    end
    if pointer.stick==i then
        pointer.stick=nil;S.axis=Vector2.zero;stick.Position=UDim2.fromScale(.5,.5)
    end
    if pointer.look==i then pointer.look=nil;pointer.lookAt=nil end
    for _,name in ipairs({"rise","fall"}) do
        if i==touchVertical[name] or (i.UserInputType==Input.MouseButton1 and touchVertical[name]) then
            S[name]=false;touchVertical[name]=nil
        end
    end
    for name,heldInput in pairs(holdCine) do
        if i==heldInput or (i.UserInputType==Input.MouseButton1 and heldInput.UserInputType==Input.MouseButton1) then
            S.cineHeld[name]=nil;holdCine[name]=nil
        end
    end
    if i.UserInputType==Input.MouseButton2 then pointer.mouseLook=false end
    if i.UserInputType==Input.Keyboard then S.held[i.KeyCode.Name]=nil end
end)
add(UIS.InputBegan,function(i,processed)
    if i.KeyCode==Keys.F8 and not UIS:GetFocusedTextBox() then
        if S.mode==3 then S.mode=1;S.panelOpen=true;refreshUI()
        else setMode(3) end
        return
    end
    if not S.active or UIS:GetFocusedTextBox() then return end
    if i.UserInputType==Input.MouseButton2 then pointer.mouseLook=true end
    if i.UserInputType==Input.Keyboard and not processed then
        local keyName=i.KeyCode.Name
        if keyName=="W" or keyName=="A" or keyName=="S" or keyName=="D"
            or keyName=="Q" or keyName=="E" then S.held[keyName]=true end
    end
end)
add(UIS.WindowFocusReleased,function()
    resetInputs()
    touchVertical.rise=nil;touchVertical.fall=nil;holdCine={}
end)
add(root:GetPropertyChangedSignal("AbsoluteSize"),function()
    pointer.drag=nil;pointer.slider=nil;pointer.zoom=nil
    layout();refreshUI()
end)

-- IX. ENLACES DE LA INTERFAZ Y SUS ACCESOS RAPIDOS.
startDrag(launcher,launcher,function() openPanel(not S.panelOpen) end)
startDrag(header,menu,nil)
startDrag(qHandle,quick,nil)
startDrag(cineHandle,cine,nil)
tap(mini,function() openPanel(false) end)
tap(close,function() if registry.__ArionFreecamV7Stop then registry.__ArionFreecamV7Stop() end end)
tap(menuPower,toggleCamera)
tap(qPower,toggleCamera)
tap(qCinema,toggleCinema)
tap(cinemaToggle,toggleCinema)
tap(qSmooth,function() S.smooth=not S.smooth;refreshUI() end)
tap(smoothToggle,function() S.smooth=not S.smooth;refreshUI() end)
tap(qReset,resetAll)
tap(qUndo,undoReset)
tap(resetPanel,resetAll)
tap(undoPanel,undoReset)
tap(qMinimize,function() S.quickFolded=not S.quickFolded;refreshUI();layout() end)
tap(cinemaShow,function() S.cinePanelOpen=not S.cinePanelOpen;refreshUI() end)
tap(cineClose,function() S.cinePanelOpen=false;refreshUI() end)
tap(cineZoomMinus,function() setZoom(S.zoomValue-.075) end)
tap(cineZoomPlus,function() setZoom(S.zoomValue+.075) end)
tap(zoomReset,function() setZoom(.5);refreshUI() end)
for key,tabButton in pairs(tabItems) do
    local selected=key
    tap(tabButton,function() S.tab=selected;refreshUI() end)
end
tap(lightReset,function()
    S.light=0;S.darkness=0
    brightnessSlider.set(.5,false)
    darknessSlider.set(0,false)
    restoreLighting()
    refreshUI();notice("Iluminacion original restaurada")
end)
tap(modeButton,function() setMode(S.mode%3+1) end)
tap(hudButton,function() hideGameHUD(not S.otherHUD) end)
tap(quickButton,function() S.quickEnabled=not S.quickEnabled;refreshUI() end)
tap(pick,function() picker.Visible=not picker.Visible end)
tap(prevPlayer,function() watchStep(-1) end)
tap(nextPlayer,function() watchStep(1) end)
tap(watchPlayer,function()
    if S.watch then S.watch=nil;refreshUI() else watchStep(1) end
end)
tap(clearWatch,function() S.watch=nil;refreshUI() end)
tap(aimButton,function() S.aim=S.aim%3+1;refreshUI() end)
tap(lockButton,function()
    if not S.target then picker.Visible=true;notice("Selecciona un jugador");return end
    if not S.active and not Camera.start() then return end
    S.locked=not S.locked
    refreshUI()
end)
tap(recover,function()
    local now=os.clock()
    if now-pointer.lastRecoverTap<.7 then
        pointer.lastRecoverTap=-10
        S.mode=1;S.panelOpen=true
        refreshUI()
    else
        pointer.lastRecoverTap=now
    end
end)
add(search:GetPropertyChangedSignal("Text"),function() refreshRoster() end)
add(Players.PlayerAdded,function() refreshRoster() end)
add(Players.PlayerRemoving,function(p) refreshRoster(p) end)

-- X. SALIDA / REEJECUCION IDÉMPOTENTE.
local function cleanup(fromDestroy)
    if R.closed then return end
    Camera.stop()
    hideGameHUD(false)
    restoreLighting()
    R.closed=true
    for _,connection in ipairs(R.connections) do pcall(function() connection:Disconnect() end) end
    R.connections={}
    if registry.__ArionFreecamV7Stop then registry.__ArionFreecamV7Stop=nil end
    if not fromDestroy and gui.Parent then gui:Destroy() end
end
registry.__ArionFreecamV7Stop=function() cleanup(false) end
add(gui.Destroying,function() cleanup(true) end)

-- XI. PUBLICACION DE LA INTERFAZ ANTES DE ENCENDER LA CAMARA.
setZoom(.5)
refreshRoster()
refreshUI()
task.defer(function()
    if not R.closed and gui.Parent then layout();refreshUI() end
end)
notice("Interfaz lista; AR abre el panel, CINE muestra control flotante")
print("[Arion v7] GUI montada en: "..tostring(gui.Parent))
