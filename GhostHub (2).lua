--[[
    GHOST HUB - STUDIO KIT (SCRIPT ÚNICO)
    Coloque este LocalScript em StarterPlayer > StarterPlayerScripts.
    Funciona somente no Roblox Studio.

    Baús: Workspace.Chests ou tag CollectionService "Chest"
    Mobs: Workspace.Mobs ou tag CollectionService "Mob"
    Tipo do baú: atributo ChestType = "Silver", "Gold" ou "Diamond"
                  (também reconhece o tipo pelo nome do objeto)
]]

local RunService = game:GetService("RunService")
if not RunService:IsStudio() then
    warn("GHOST HUB: ferramentas desativadas fora do Roblox Studio")
    return
end

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Default = {
    Language = "pt",
    UIMode = "TargetBox", -- TargetBox | BarBox | Box
    ChestEnabled = false,
    ChestMethod = "Tween", -- Tween | TP | Tween + TP
    ChestFilter = "All", -- All | Silver | Gold | Diamond
    TweenSpeed = 300,
    TPDistance = 35,
    BoostEnabled = true,
    BoostSpeed = 600,
    BoostDistance = 120,
    ReachDistance = 7,
    RetargetRate = 0.10,
    ChestLock = false,
    GrabChest = true,
    SimpleChests = false,
    LightMap = false,
    MobFlyEnabled = false,
    MobTweenSpeed = 300,
    MobHeight = 12,
}

local config = {}
for key, value in pairs(Default) do config[key] = value end

local L = {
    pt = {
        title="GHOST HUB", subtitle="STUDIO KIT", main="AUTO BAÚ", mob="MOB FLY", visual="VISUAL", ui="UI",
        chest="Coletar baús", method="Método", filter="Tipo de baú", all="Todos", silver="Prata", gold="Ouro", diamond="Diamante",
        tweenSpeed="Velocidade Tween", tpDistance="Distância para TP", boost="Boost por distância", boostSpeed="Velocidade do Boost",
        boostDistance="Boost começa na distância", reach="Distância de coleta", lock="Travar no alvo atual", grab="Mexidas no baú",
        retarget="Tempo de re-alvo", current="Alvo atual", speed="Velocidade atual", waiting="Aguardando", none="Nenhum baú encontrado",
        mobFly="Voar sobre mob próximo", mobSpeed="Tween para mob", mobHeight="Altura sobre a cabeça", closestMob="Mob atual",
        simple="Skin neon dos baús", lightMap="Modo leve do mapa", controls="Modo dos controles", language="Idioma",
        targetBox="Target + Caixa", barBox="Barra dinâmica + Caixa", box="Só caixa de texto",
        on="ON", off="OFF", studio="SOMENTE STUDIO", collected="Baús alcançados", hint="Clique no valor para trocar o preset",
    },
    en = {
        title="GHOST HUB", subtitle="STUDIO KIT", main="AUTO CHEST", mob="MOB FLY", visual="VISUAL", ui="UI",
        chest="Collect chests", method="Method", filter="Chest type", all="All", silver="Silver", gold="Gold", diamond="Diamond",
        tweenSpeed="Tween speed", tpDistance="TP distance", boost="Distance boost", boostSpeed="Boost speed",
        boostDistance="Boost starts at distance", reach="Collection distance", lock="Lock current target", grab="Chest movement",
        retarget="Retarget time", current="Current target", speed="Current speed", waiting="Waiting", none="No chest found",
        mobFly="Fly over nearest mob", mobSpeed="Mob tween", mobHeight="Height above head", closestMob="Current mob",
        simple="Neon chest skin", lightMap="Light map mode", controls="Controls mode", language="Language",
        targetBox="Target + Text box", barBox="Dynamic bar + Text box", box="Text box only",
        on="ON", off="OFF", studio="STUDIO ONLY", collected="Chests reached", hint="Click the value to change preset",
    },
    vi = {
        title="GHOST HUB", subtitle="STUDIO KIT", main="TỰ ĐỘNG RƯƠNG", mob="BAY TRÊN QUÁI", visual="HIỂN THỊ", ui="GIAO DIỆN",
        chest="Thu thập rương", method="Phương thức", filter="Loại rương", all="Tất cả", silver="Bạc", gold="Vàng", diamond="Kim cương",
        tweenSpeed="Tốc độ Tween", tpDistance="Khoảng cách TP", boost="Tăng tốc theo khoảng cách", boostSpeed="Tốc độ tăng",
        boostDistance="Bắt đầu tăng ở khoảng cách", reach="Khoảng cách nhặt", lock="Khóa mục tiêu hiện tại", grab="Chuyển động rương",
        retarget="Thời gian đổi mục tiêu", current="Mục tiêu hiện tại", speed="Tốc độ hiện tại", waiting="Đang chờ", none="Không tìm thấy rương",
        mobFly="Bay trên quái gần nhất", mobSpeed="Tween tới quái", mobHeight="Độ cao trên đầu", closestMob="Quái hiện tại",
        simple="Skin rương neon", lightMap="Chế độ bản đồ nhẹ", controls="Kiểu điều khiển", language="Ngôn ngữ",
        targetBox="Mốc + Ô nhập", barBox="Thanh động + Ô nhập", box="Chỉ ô nhập",
        on="BẬT", off="TẮT", studio="CHỈ STUDIO", collected="Rương đã tới", hint="Nhấn giá trị để đổi mức",
    },
}

local function T(key)
    local language = L[config.Language] or L.pt
    return language[key] or L.pt[key] or key
end

local function rootPart()
    local character = player.Character
    return character and character:FindFirstChild("HumanoidRootPart")
end

local function targetPart(instance)
    if not instance or not instance.Parent then return nil end
    if instance:IsA("BasePart") then return instance end
    if instance:IsA("Model") then
        return instance.PrimaryPart
            or instance:FindFirstChild("HumanoidRootPart")
            or instance:FindFirstChildWhichIsA("BasePart", true)
    end
    return instance:FindFirstChildWhichIsA("BasePart", true)
end

local function normalizeTarget(instance)
    if instance:IsA("Model") then return instance end
    local model = instance:FindFirstAncestorOfClass("Model")
    return model or instance
end

local function collectCandidates(folderName, tagName)
    local results, seen = {}, {}
    local folder = workspace:FindFirstChild(folderName)
    if folder then
        for _, child in ipairs(folder:GetChildren()) do
            local candidate = normalizeTarget(child)
            if not seen[candidate] then seen[candidate] = true; table.insert(results, candidate) end
        end
    end
    for _, tagged in ipairs(CollectionService:GetTagged(tagName)) do
        local candidate = normalizeTarget(tagged)
        if not seen[candidate] then seen[candidate] = true; table.insert(results, candidate) end
    end
    return results
end

local function chestType(chest)
    local attribute = chest:GetAttribute("ChestType")
    local name = string.lower(tostring(attribute or chest.Name))
    if string.find(name, "diamond", 1, true) or string.find(name, "diamante", 1, true) then return "Diamond" end
    if string.find(name, "gold", 1, true) or string.find(name, "ouro", 1, true) then return "Gold" end
    return "Silver"
end

local ignoredUntil = setmetatable({}, { __mode = "k" })
local reached = setmetatable({}, { __mode = "k" })
local currentChest, currentMob
local reachedCount = 0

local function validChest(chest)
    if not chest or not chest.Parent then return false end
    if chest:GetAttribute("Collected") == true then return false end
    if (ignoredUntil[chest] or 0) > os.clock() then return false end
    return config.ChestFilter == "All" or chestType(chest) == config.ChestFilter
end

local function nearestChest()
    local root = rootPart()
    if not root then return nil end
    local best, bestDistance
    for _, chest in ipairs(collectCandidates("Chests", "Chest")) do
        local part = targetPart(chest)
        if part and validChest(chest) then
            local distance = (root.Position - part.Position).Magnitude
            if not bestDistance or distance < bestDistance then
                best, bestDistance = chest, distance
            end
        end
    end
    return best, bestDistance
end

local NPC_WORDS = { "quest", "vendor", "seller", "shop", "dealer", "gacha", "boat", "merchant" }
local function validMob(mob)
    if not mob or not mob.Parent or mob == player.Character then return false end
    local humanoid = mob:IsA("Model") and mob:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return false end
    if Players:GetPlayerFromCharacter(mob) then return false end
    if mob:GetAttribute("IsNPC") == true or mob:GetAttribute("IgnoreGhostHub") == true then return false end
    local name = string.lower(mob.Name)
    for _, word in ipairs(NPC_WORDS) do
        if string.find(name, word, 1, true) then return false end
    end
    return true
end

local function nearestMob()
    local root = rootPart()
    if not root then return nil end
    local best, bestDistance
    for _, mob in ipairs(collectCandidates("Mobs", "Mob")) do
        local part = targetPart(mob)
        if part and validMob(mob) then
            local distance = (root.Position - part.Position).Magnitude
            if not bestDistance or distance < bestDistance then
                best, bestDistance = mob, distance
            end
        end
    end
    return best, bestDistance
end

local activeTween, movingTarget, movingSpeed, movingGoal
local function cancelTween()
    if activeTween then activeTween:Cancel() end
    activeTween, movingTarget, movingSpeed, movingGoal = nil, nil, nil, nil
end

local function tweenTo(goal, speed, target)
    local root = rootPart()
    if not root then return end
    local distance = (root.Position - goal.Position).Magnitude
    if activeTween and movingTarget == target and movingSpeed == speed and movingGoal and (movingGoal.Position - goal.Position).Magnitude < 2 then
        return
    end
    cancelTween()
    movingTarget, movingSpeed, movingGoal = target, speed, goal
    activeTween = TweenService:Create(
        root,
        TweenInfo.new(math.max(distance / math.max(speed, 1), 0.03), Enum.EasingStyle.Linear),
        { CFrame = goal }
    )
    activeTween:Play()
end

local function teleportTo(part, offset)
    local character, root = player.Character, rootPart()
    if not character or not root or not part then return end
    cancelTween()
    character:PivotTo(part.CFrame * CFrame.new(offset))
    root.AssemblyLinearVelocity = Vector3.zero
    root.AssemblyAngularVelocity = Vector3.zero
end

local function chestSpeed(distance)
    if config.BoostEnabled and distance <= config.BoostDistance then return config.BoostSpeed end
    return config.TweenSpeed
end

local visualBackup = setmetatable({}, { __mode = "k" })
local function remember(object, property)
    visualBackup[object] = visualBackup[object] or {}
    if visualBackup[object][property] == nil then visualBackup[object][property] = object[property] end
end

local function applyChestSkins()
    for _, chest in ipairs(collectCandidates("Chests", "Chest")) do
        local kind = chestType(chest)
        local color = kind == "Diamond" and Color3.fromRGB(20, 170, 255)
            or kind == "Gold" and Color3.fromRGB(255, 210, 30)
            or Color3.fromRGB(235, 248, 255)
        for _, object in ipairs(chest:GetDescendants()) do
            if object:IsA("BasePart") then
                remember(object, "Material"); remember(object, "Color")
                object.Material = Enum.Material.Neon; object.Color = color
            elseif object:IsA("Texture") or object:IsA("Decal") then
                remember(object, "Transparency"); object.Transparency = 1
            end
        end
    end
end

local function setLightMap(enabled)
    local chests = workspace:FindFirstChild("Chests")
    local mobs = workspace:FindFirstChild("Mobs")
    for _, object in ipairs(workspace:GetDescendants()) do
        local protected = (chests and object:IsDescendantOf(chests)) or (mobs and object:IsDescendantOf(mobs))
        if object:IsA("BasePart") and not protected and not (player.Character and object:IsDescendantOf(player.Character)) then
            remember(object, "LocalTransparencyModifier")
            object.LocalTransparencyModifier = enabled and 0.82 or (visualBackup[object] and visualBackup[object].LocalTransparencyModifier or 0)
        elseif (object:IsA("Texture") or object:IsA("Decal")) and not protected then
            remember(object, "Transparency")
            object.Transparency = enabled and 1 or (visualBackup[object] and visualBackup[object].Transparency or 0)
        end
    end
end

local function restoreChestSkins()
    for object, properties in pairs(visualBackup) do
        if object and object.Parent then
            for property, value in pairs(properties) do pcall(function() object[property] = value end) end
        end
    end
    visualBackup = setmetatable({}, { __mode = "k" })
    if config.LightMap then setLightMap(true) end
end

-- Interface inspirada no painel do site: azul-marinho, ciano e verde-limão.
local old = playerGui:FindFirstChild("GhostHubStudio")
if old then old:Destroy() end
local gui = Instance.new("ScreenGui")
gui.Name = "GhostHubStudio"; gui.ResetOnSpawn = false; gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling; gui.Parent = playerGui

local C = {
    bg=Color3.fromRGB(8, 15, 31), side=Color3.fromRGB(10, 25, 48), card=Color3.fromRGB(15, 35, 61),
    row=Color3.fromRGB(19, 45, 76), stroke=Color3.fromRGB(25, 127, 211), text=Color3.fromRGB(232, 247, 255),
    dim=Color3.fromRGB(145, 178, 205), cyan=Color3.fromRGB(43, 206, 255), lime=Color3.fromRGB(176, 255, 77), red=Color3.fromRGB(255, 91, 106),
}
local function corner(object, radius) local x=Instance.new("UICorner"); x.CornerRadius=UDim.new(0,radius or 8); x.Parent=object; return x end
local function stroke(object, color, thickness) local x=Instance.new("UIStroke"); x.Color=color or C.stroke; x.Thickness=thickness or 1; x.Transparency=.15; x.Parent=object; return x end
local function gradient(object, a, b, rotation) local x=Instance.new("UIGradient"); x.Color=ColorSequence.new(a,b); x.Rotation=rotation or 0; x.Parent=object; return x end

local panel = Instance.new("Frame")
panel.Name="Panel"; panel.Size=UDim2.fromOffset(620,480); panel.Position=UDim2.new(.5,-310,.5,-240); panel.BackgroundColor3=C.bg; panel.BorderSizePixel=0; panel.Active=true; panel.Draggable=true; panel.Parent=gui
corner(panel,14); stroke(panel,C.cyan,2); gradient(panel,C.bg,Color3.fromRGB(5,31,61),135)

local top = Instance.new("Frame")
top.Size=UDim2.new(1,0,0,58); top.BackgroundTransparency=1; top.Parent=panel
local ghost = Instance.new("TextLabel")
ghost.Size=UDim2.fromOffset(44,44); ghost.Position=UDim2.fromOffset(12,7); ghost.BackgroundColor3=C.side; ghost.Text=utf8.char(0x1F47B); ghost.TextSize=25; ghost.Parent=top; corner(ghost,22); stroke(ghost,C.cyan,2)
local title = Instance.new("TextLabel")
title.Size=UDim2.new(1,-150,0,25); title.Position=UDim2.fromOffset(66,8); title.BackgroundTransparency=1; title.Font=Enum.Font.GothamBlack; title.TextSize=19; title.TextColor3=C.text; title.TextXAlignment=Enum.TextXAlignment.Left; title.Parent=top
local subtitle = Instance.new("TextLabel")
subtitle.Size=UDim2.new(1,-150,0,18); subtitle.Position=UDim2.fromOffset(67,33); subtitle.BackgroundTransparency=1; subtitle.Font=Enum.Font.GothamMedium; subtitle.TextSize=11; subtitle.TextColor3=C.lime; subtitle.TextXAlignment=Enum.TextXAlignment.Left; subtitle.Parent=top
local minimize = Instance.new("TextButton")
minimize.Size=UDim2.fromOffset(38,32); minimize.Position=UDim2.new(1,-50,0,12); minimize.BackgroundColor3=C.row; minimize.Text="—"; minimize.TextColor3=C.text; minimize.TextSize=20; minimize.Font=Enum.Font.GothamBold; minimize.Parent=top; corner(minimize,8); stroke(minimize,C.stroke,1)

local sidebar = Instance.new("Frame")
sidebar.Size=UDim2.new(0,126,1,-68); sidebar.Position=UDim2.fromOffset(10,58); sidebar.BackgroundColor3=C.side; sidebar.BorderSizePixel=0; sidebar.Parent=panel; corner(sidebar,10); stroke(sidebar,C.stroke,1)
local sideLayout=Instance.new("UIListLayout"); sideLayout.Padding=UDim.new(0,7); sideLayout.HorizontalAlignment=Enum.HorizontalAlignment.Center; sideLayout.Parent=sidebar
local sidePad=Instance.new("UIPadding"); sidePad.PaddingTop=UDim.new(0,10); sidePad.Parent=sidebar

local pageHost = Instance.new("Frame")
pageHost.Size=UDim2.new(1,-152,1,-68); pageHost.Position=UDim2.fromOffset(142,58); pageHost.BackgroundTransparency=1; pageHost.Parent=panel

local bubble = Instance.new("TextButton")
bubble.Name="GhostBubble"; bubble.Size=UDim2.fromOffset(78,78); bubble.Position=panel.Position; bubble.Visible=false; bubble.Text=""; bubble.BackgroundColor3=Color3.fromRGB(5,28,66); bubble.Parent=gui; corner(bubble,39); stroke(bubble,C.cyan,3); gradient(bubble,Color3.fromRGB(5,20,52),Color3.fromRGB(13,78,132),135)
local bubbleGhost=Instance.new("TextLabel")
bubbleGhost.Size=UDim2.new(1,0,0,37); bubbleGhost.Position=UDim2.fromOffset(0,3); bubbleGhost.BackgroundTransparency=1; bubbleGhost.Text=utf8.char(0x1F47B); bubbleGhost.TextSize=27; bubbleGhost.Parent=bubble
local bubbleText=Instance.new("TextLabel")
bubbleText.Size=UDim2.new(1,0,0,31); bubbleText.Position=UDim2.fromOffset(0,40); bubbleText.BackgroundTransparency=1; bubbleText.Text="GHOST\nHUB"; bubbleText.TextColor3=C.text; bubbleText.Font=Enum.Font.GothamBold; bubbleText.TextSize=10; bubbleText.Parent=bubble
minimize.MouseButton1Click:Connect(function() bubble.Position=panel.Position; panel.Visible=false; bubble.Visible=true end)
bubble.MouseButton1Click:Connect(function() panel.Position=bubble.Position; bubble.Visible=false; panel.Visible=true end)

local pages, tabButtons, refreshers = {}, {}, {}
local activePage = "main"
local function addRefresh(fn) table.insert(refreshers,fn); fn() end
local function refreshAll() for _,fn in ipairs(refreshers) do pcall(fn) end end
local function makePage(key)
    local page=Instance.new("ScrollingFrame"); page.Name=key; page.Size=UDim2.fromScale(1,1); page.BackgroundTransparency=1; page.BorderSizePixel=0
    page.ScrollBarThickness=3; page.ScrollBarImageColor3=C.cyan; page.AutomaticCanvasSize=Enum.AutomaticSize.Y; page.CanvasSize=UDim2.new(); page.Visible=false; page.Parent=pageHost
    local list=Instance.new("UIListLayout"); list.Padding=UDim.new(0,8); list.SortOrder=Enum.SortOrder.LayoutOrder; list.Parent=page
    local pad=Instance.new("UIPadding"); pad.PaddingRight=UDim.new(0,7); pad.PaddingBottom=UDim.new(0,8); pad.Parent=page
    pages[key]=page; return page
end
local function showPage(key)
    activePage=key
    for name,page in pairs(pages) do page.Visible=name==key end
    for name,button in pairs(tabButtons) do
        button.BackgroundColor3=name==key and Color3.fromRGB(18,74,112) or C.row
        button.TextColor3=name==key and C.lime or C.text
    end
end
local tabNames={main="main",mob="mob",visual="visual",ui="ui"}
for _,key in ipairs({"main","mob","visual","ui"}) do
    local button=Instance.new("TextButton"); button.Size=UDim2.new(1,-14,0,40); button.BackgroundColor3=C.row; button.TextColor3=C.text
    button.Font=Enum.Font.GothamBold; button.TextSize=12; button.Parent=sidebar; corner(button,7); tabButtons[key]=button
    button.MouseButton1Click:Connect(function() showPage(key) end)
    addRefresh(function() button.Text=T(tabNames[key]) end)
    makePage(key)
end
showPage("main")

local function section(page,key)
    local label=Instance.new("TextLabel"); label.Size=UDim2.new(1,0,0,28); label.BackgroundTransparency=1; label.TextColor3=C.cyan
    label.Font=Enum.Font.GothamBold; label.TextSize=13; label.TextXAlignment=Enum.TextXAlignment.Left; label.Parent=page
    addRefresh(function() label.Text=T(key) end); return label
end
local function rowFrame(page,height)
    local row=Instance.new("Frame"); row.Size=UDim2.new(1,0,0,height or 42); row.BackgroundColor3=C.card; row.BorderSizePixel=0; row.Parent=page; corner(row,8); stroke(row,C.stroke,1); return row
end
local function toggle(page,labelKey,configKey,onChange)
    local row=rowFrame(page,42)
    local label=Instance.new("TextLabel"); label.Size=UDim2.new(1,-90,1,0); label.Position=UDim2.fromOffset(12,0); label.BackgroundTransparency=1
    label.TextColor3=C.text; label.Font=Enum.Font.GothamMedium; label.TextSize=12; label.TextXAlignment=Enum.TextXAlignment.Left; label.Parent=row
    local button=Instance.new("TextButton"); button.Size=UDim2.fromOffset(66,28); button.Position=UDim2.new(1,-76,.5,-14); button.Font=Enum.Font.GothamBold; button.TextSize=11; button.Parent=row; corner(button,14)
    local function update()
        label.Text=T(labelKey); button.Text=config[configKey] and T("on") or T("off")
        button.BackgroundColor3=config[configKey] and C.lime or C.row; button.TextColor3=config[configKey] and C.bg or C.dim
    end
    button.MouseButton1Click:Connect(function() config[configKey]=not config[configKey]; update(); if onChange then onChange(config[configKey]) end end)
    addRefresh(update); return button
end
local function choice(page,labelKey,configKey,values,display)
    local row=rowFrame(page,42)
    local label=Instance.new("TextLabel"); label.Size=UDim2.new(.48,-12,1,0); label.Position=UDim2.fromOffset(12,0); label.BackgroundTransparency=1
    label.TextColor3=C.text; label.Font=Enum.Font.GothamMedium; label.TextSize=12; label.TextXAlignment=Enum.TextXAlignment.Left; label.Parent=row
    local button=Instance.new("TextButton"); button.Size=UDim2.new(.52,-10,0,28); button.Position=UDim2.new(.48,0,.5,-14); button.BackgroundColor3=C.row
    button.TextColor3=C.lime; button.Font=Enum.Font.GothamBold; button.TextSize=11; button.Parent=row; corner(button,7)
    local function update() label.Text=T(labelKey); button.Text=display and display(config[configKey]) or tostring(config[configKey]) end
    button.MouseButton1Click:Connect(function()
        local index=table.find(values,config[configKey]) or 1; config[configKey]=values[index % #values + 1]; update(); cancelTween()
    end)
    addRefresh(update); return button
end

local presets={
    TweenSpeed={250,280,300,310,330,350,400,500,600}, TPDistance={20,35,50,75,100,150,250,500},
    BoostSpeed={400,500,600,750,900,1200}, BoostDistance={35,50,75,100,120,150,250,500},
    ReachDistance={3,5,7,10,14}, RetargetRate={0.05,0.08,0.10,0.15,0.25}, MobHeight={5,8,12,16,20,30},
}
local limits={TweenSpeed={1,2000},TPDistance={2,1000},BoostSpeed={1,3000},BoostDistance={1,2000},ReachDistance={2,30},RetargetRate={0.03,1},MobHeight={3,100}}
local function numberControl(page,labelKey,configKey)
    local row=rowFrame(page,62)
    local label=Instance.new("TextLabel"); label.Size=UDim2.new(.51,-12,0,42); label.Position=UDim2.fromOffset(12,0); label.BackgroundTransparency=1
    label.TextColor3=C.text; label.Font=Enum.Font.GothamMedium; label.TextSize=12; label.TextXAlignment=Enum.TextXAlignment.Left; label.Parent=row
    local box=Instance.new("TextBox"); box.Size=UDim2.new(.28,-8,0,28); box.Position=UDim2.new(.72,0,0,7); box.BackgroundColor3=C.row; box.TextColor3=C.text
    box.Font=Enum.Font.GothamBold; box.TextSize=12; box.ClearTextOnFocus=false; box.Parent=row; corner(box,7); stroke(box,C.stroke,1)
    local target=Instance.new("TextButton"); target.Size=UDim2.new(.21,-7,0,28); target.Position=UDim2.new(.51,0,0,7); target.BackgroundColor3=Color3.fromRGB(15,67,103)
    target.TextColor3=C.lime; target.Font=Enum.Font.GothamBold; target.TextSize=11; target.Parent=row; corner(target,7)
    local bar=Instance.new("Frame"); bar.Size=UDim2.new(1,-24,0,6); bar.Position=UDim2.fromOffset(12,49); bar.BackgroundColor3=C.row; bar.BorderSizePixel=0; bar.Parent=row; corner(bar,3)
    local fill=Instance.new("Frame"); fill.Size=UDim2.fromScale(.5,1); fill.BackgroundColor3=C.cyan; fill.BorderSizePixel=0; fill.Parent=bar; corner(fill,3)
    local dragging=false
    local minimum,maximum=limits[configKey][1],limits[configKey][2]
    local function setValue(value)
        config[configKey]=math.clamp(value,minimum,maximum); box.Text=tostring(config[configKey]); target.Text=tostring(config[configKey])
        fill.Size=UDim2.fromScale(math.clamp((config[configKey]-minimum)/(maximum-minimum),0,1),1); cancelTween()
    end
    local function update()
        label.Text=T(labelKey); box.Text=tostring(config[configKey]); target.Text=tostring(config[configKey])
        local mode=config.UIMode; target.Visible=mode=="TargetBox"; bar.Visible=mode=="BarBox"
        box.Position=mode=="Box" and UDim2.new(.51,0,0,7) or UDim2.new(.72,0,0,7)
        box.Size=mode=="Box" and UDim2.new(.49,-10,0,28) or UDim2.new(.28,-8,0,28)
    end
    box.FocusLost:Connect(function() setValue(tonumber(box.Text) or config[configKey]) end)
    target.MouseButton1Click:Connect(function()
        local list=presets[configKey]; local index=table.find(list,config[configKey]) or 0; setValue(list[index % #list + 1])
    end)
    bar.InputBegan:Connect(function(input) if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then dragging=true end end)
    UserInputService.InputEnded:Connect(function(input) if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then dragging=false end end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType==Enum.UserInputType.MouseMovement or input.UserInputType==Enum.UserInputType.Touch) then
            local alpha=math.clamp((input.Position.X-bar.AbsolutePosition.X)/math.max(bar.AbsoluteSize.X,1),0,1)
            setValue(math.floor(minimum+(maximum-minimum)*alpha+.5))
        end
    end)
    addRefresh(update); setValue(config[configKey]); return row
end
local function statusRow(page,labelKey,valueFn)
    local row=rowFrame(page,38)
    local label=Instance.new("TextLabel"); label.Size=UDim2.new(.45,-12,1,0); label.Position=UDim2.fromOffset(12,0); label.BackgroundTransparency=1; label.TextColor3=C.dim
    label.Font=Enum.Font.GothamMedium; label.TextSize=11; label.TextXAlignment=Enum.TextXAlignment.Left; label.Parent=row
    local value=Instance.new("TextLabel"); value.Size=UDim2.new(.55,-12,1,0); value.Position=UDim2.new(.45,0,0,0); value.BackgroundTransparency=1; value.TextColor3=C.lime
    value.Font=Enum.Font.GothamBold; value.TextSize=11; value.TextXAlignment=Enum.TextXAlignment.Right; value.Parent=row
    addRefresh(function() label.Text=T(labelKey) end)
    task.spawn(function() while row.Parent do value.Text=valueFn(); task.wait(.15) end end)
end

local main=pages.main
section(main,"main")
toggle(main,"chest","ChestEnabled",function(enabled) if not enabled then currentChest=nil; cancelTween() end end)
choice(main,"method","ChestMethod",{"Tween","TP","Tween + TP"})
choice(main,"filter","ChestFilter",{"All","Silver","Gold","Diamond"},function(value) return T(string.lower(value)) end)
numberControl(main,"tweenSpeed","TweenSpeed")
numberControl(main,"tpDistance","TPDistance")
toggle(main,"boost","BoostEnabled")
numberControl(main,"boostSpeed","BoostSpeed")
numberControl(main,"boostDistance","BoostDistance")
statusRow(main,"current",function() return currentChest and currentChest.Name or T("none") end)
statusRow(main,"speed",function()
    if not config.ChestEnabled then return "0" end
    local root,part=rootPart(),currentChest and targetPart(currentChest)
    if not root or not part then return "0" end
    return tostring(chestSpeed((root.Position-part.Position).Magnitude))
end)
statusRow(main,"collected",function() return tostring(reachedCount) end)

local mob=pages.mob
section(mob,"mob")
toggle(mob,"mobFly","MobFlyEnabled",function(enabled) if not enabled then currentMob=nil; cancelTween() end end)
statusRow(mob,"mobSpeed",function() return "300" end)
numberControl(mob,"mobHeight","MobHeight")
statusRow(mob,"closestMob",function() return currentMob and currentMob.Name or T("waiting") end)

local visual=pages.visual
section(visual,"visual")
toggle(visual,"simple","SimpleChests",function(enabled) if enabled then applyChestSkins() else restoreChestSkins() end end)
toggle(visual,"lightMap","LightMap",function(enabled) setLightMap(enabled) end)
toggle(visual,"grab","GrabChest")
toggle(visual,"lock","ChestLock")
numberControl(visual,"reach","ReachDistance")
numberControl(visual,"retarget","RetargetRate")

local uiPage=pages.ui
section(uiPage,"ui")
choice(uiPage,"controls","UIMode",{"TargetBox","BarBox","Box"},function(value)
    return value=="TargetBox" and T("targetBox") or value=="BarBox" and T("barBox") or T("box")
end)
choice(uiPage,"language","Language",{"pt","en","vi"},function(value) return value=="pt" and "Português" or value=="en" and "English" or "Tiếng Việt" end)
local hint=rowFrame(uiPage,62)
local hintText=Instance.new("TextLabel"); hintText.Size=UDim2.new(1,-24,1,-12); hintText.Position=UDim2.fromOffset(12,6); hintText.BackgroundTransparency=1; hintText.TextWrapped=true
hintText.TextColor3=C.dim; hintText.Font=Enum.Font.Gotham; hintText.TextSize=11; hintText.Parent=hint
addRefresh(function() title.Text=T("title"); subtitle.Text=T("subtitle").."  •  "..T("studio"); hintText.Text=T("hint") end)

-- Atualiza idioma e modo imediatamente depois de qualquer escolha.
for _,button in pairs(tabButtons) do button.MouseButton1Click:Connect(refreshAll) end
task.spawn(function()
    local oldLanguage,oldMode=config.Language,config.UIMode
    while gui.Parent do
        if oldLanguage~=config.Language or oldMode~=config.UIMode then
            oldLanguage,oldMode=config.Language,config.UIMode
            refreshAll()
        end
        task.wait(.1)
    end
end)

-- Loop principal: Mob Fly tem prioridade quando ligado; caso contrário, usa o baú realmente mais próximo.
task.spawn(function()
    while gui.Parent do
        task.wait(math.clamp(config.RetargetRate,.03,1))
        if config.SimpleChests then applyChestSkins() end
        if config.MobFlyEnabled then
            local mobTarget=nearestMob(); currentMob=mobTarget; currentChest=nil
            local part=mobTarget and targetPart(mobTarget)
            if part then
                local goal=CFrame.new(part.Position+Vector3.new(0,config.MobHeight,0),part.Position)
                tweenTo(goal,300,mobTarget)
            else cancelTween() end
        elseif config.ChestEnabled then
            currentMob=nil
            if not (config.ChestLock and validChest(currentChest)) then currentChest=nil end
            local lockedPart=currentChest and targetPart(currentChest)
            local distance
            if lockedPart then
                local root=rootPart(); distance=root and (root.Position-lockedPart.Position).Magnitude
            else
                currentChest,distance=nearestChest()
            end
            local part=currentChest and targetPart(currentChest)
            if part and distance then
                local offset=Vector3.new(0,3,4)
                if config.ChestMethod=="TP" then
                    teleportTo(part,offset)
                elseif config.ChestMethod=="Tween + TP" and distance<=config.TPDistance then
                    teleportTo(part,offset)
                else
                    tweenTo(part.CFrame*CFrame.new(offset),chestSpeed(distance),currentChest)
                end
                local root=rootPart()
                local remaining=root and (root.Position-part.Position).Magnitude or distance
                if remaining<=config.ReachDistance then
                    if config.GrabChest and root then
                        root.AssemblyLinearVelocity=Vector3.zero; root.AssemblyAngularVelocity=Vector3.zero
                    end
                    if not reached[currentChest] then reached[currentChest]=true; reachedCount=reachedCount+1 end
                    ignoredUntil[currentChest]=os.clock()+1.5
                    currentChest=nil; cancelTween()
                end
            else
                cancelTween()
                -- Sem outro baú, permanece onde chegou; não volta para uma posição aleatória.
            end
        else
            currentChest,currentMob=nil,nil; cancelTween()
        end
    end
end)

player.CharacterAdded:Connect(function()
    currentChest,currentMob=nil,nil; cancelTween()
end)
