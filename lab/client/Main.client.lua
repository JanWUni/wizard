local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local ContentProvider = game:GetService("ContentProvider")
local StarterGui = game:GetService("StarterGui")
local player = Players.LocalPlayer
local assets = game:GetService("ReplicatedStorage"):WaitForChild("WizardAssets")
local Art = require(assets:WaitForChild("ArtDirection"))
local Card = require(assets:WaitForChild("CardModel"))
local Tavern = require(assets:WaitForChild("Tavern"))
local Layout = require(assets:WaitForChild("TableLayout"))
while not workspace:GetAttribute("AssetLabReady") do task.wait() end

local p = Art.palette
local scene = Instance.new("Folder")
scene.Name, scene.Parent = "LocalAssetStudies", workspace
local hand, tableCards, sample, hover = {}, {}, nil, nil
local selected, handCount, rank = 5, 6, 13
local mode, preset, flipped, readable = "table", "tavern", false, true
local spin, heldDrag, lastPointer = 0, false, nil
local yaw, pitch = 0, 0
local artworks, backArt = {}, ""
local notice, updateLabels, rebuild, setMode, playSelected
local busy, playCounter, redrawToken = false, 0, 0
local ray = RaycastParams.new()
ray.FilterType = Enum.RaycastFilterType.Include
ray.FilterDescendantsInstances = { scene }

local function make(class, parent, properties)
    local instance = Instance.new(class)
    for key, value in pairs(properties or {}) do instance[key] = value end
    instance.Parent = parent
    return instance
end
local function round(object, radius)
    make("UICorner", object, { CornerRadius = UDim.new(0, radius or 9) })
end
local function text(parent, value, position, size, fontSize, color)
    return make("TextLabel", parent, { Text = value, Position = position, Size = size, TextSize = fontSize,
        Font = Enum.Font.Gotham, TextColor3 = color or p.paperLight, BackgroundTransparency = 1,
        TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left })
end
local function button(parent, value, x, y, width, callback, accent)
    local object = make("TextButton", parent, { Text = value, Position = UDim2.fromOffset(x, y),
        Size = UDim2.fromOffset(width, 35), BackgroundColor3 = if accent then p.gold else Color3.fromRGB(42, 43, 44),
        BorderSizePixel = 0, TextColor3 = if accent then p.ink else p.paperLight,
        Font = Enum.Font.GothamMedium, TextSize = 13 })
    round(object, 8)
    object.Activated:Connect(callback)
    return object
end
local gui = make("ScreenGui", player:WaitForChild("PlayerGui"), { Name = "AssetLabUI", ResetOnSpawn = false,
    IgnoreGuiInset = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling })
local header = make("Frame", gui, { Position = UDim2.new(0, 20, 0, 12), Size = UDim2.new(1, -40, 0, 69),
    BackgroundColor3 = p.ink, BackgroundTransparency = 0.13, BorderSizePixel = 0 })
round(header, 12)
text(header, "WIZARD  /  ASSET LAB", UDim2.fromOffset(18, 10), UDim2.new(0.65, 0, 0, 24), 19, p.goldLight)
local description = text(header, "", UDim2.fromOffset(18, 38), UDim2.new(1, -32, 0, 21), 12, p.muted)
local hint = text(gui, "", UDim2.new(0, 38, 0, 94), UDim2.new(0.8, 0, 0, 44), 15, p.paperLight)
local toolbar = make("Frame", gui, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -18),
    Size = UDim2.fromOffset(996, 142), BackgroundColor3 = p.ink, BackgroundTransparency = 0.06, BorderSizePixel = 0 })
round(toolbar, 14)
local toolbarScale = make("UIScale", toolbar, {})
local function resizeUI()
    local camera = workspace.CurrentCamera
    if camera then toolbarScale.Scale = math.min(1, (camera.ViewportSize.X - 24) / 996) end
end
local toast = text(gui, "", UDim2.new(0.15, 0, 1, -194), UDim2.new(0.7, 0, 0, 32), 15, p.goldLight)
toast.TextXAlignment = Enum.TextXAlignment.Center
notice = function(message)
    toast.Text = message
    task.delay(5, function() if toast.Text == message then toast.Text = "" end end)
end

local function dataFor(index)
    local data = table.clone(Art.samples[(index - 1) % #Art.samples + 1])
    if data.kind == "number" then data.rank = rank; data.id = data.suit .. rank .. "_" .. index end
    return data
end
local function dress(model, data)
    local style = data.suit or data.kind
    Card.setReadable(model, readable)
    Card.setArtwork(model, artworks[style] or Art.images[style], false)
    Card.setArtwork(model, backArt, true)
end
local function animate(model, target, seconds)
    local value = Instance.new("CFrameValue")
    value.Value = model:GetPivot()
    local connection = value.Changed:Connect(function(transform)
        if model.Parent then model:PivotTo(transform) end
    end)
    local tween = TweenService:Create(value, TweenInfo.new(seconds, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Value = target })
    tween.Completed:Once(function() connection:Disconnect(); value:Destroy() end)
    tween:Play()
    return tween
end
local flat = Layout.flat

local function newHand()
    for _, entry in ipairs(hand) do entry.model:Destroy() end
    hand, hover, yaw, pitch = {}, nil, 0, 0
    for i = 1, handCount do
        local data = dataFor(i)
        local model = Card.create(scene, data)
        model:SetAttribute("HandIndex", i)
        dress(model, data)
        table.insert(hand, { model = model, data = data, raised = 0 })
    end
end
local function newSample()
    if sample then sample:Destroy() end
    local data = dataFor(selected)
    sample = Card.create(scene, data,
        CFrame.lookAt(Tavern.inspection, Tavern.inspection + Vector3.new(0, 0, 5)))
    sample.Name = "InspectionCard"
    dress(sample, data)
end

local function clearTable()
    for _, card in ipairs(tableCards) do card:Destroy() end
    tableCards, playCounter = {}, 0
end
local function opponentHands()
    local old = scene:FindFirstChild("OpponentCards")
    if old then old:Destroy() end
    local group = make("Folder", scene, { Name = "OpponentCards" })
    for seat = 2, 6 do
        local angle = (seat - 1) * math.pi / 3
        for i = 1, 3 do
            local transform = CFrame.Angles(0, angle, 0) * CFrame.new((i - 2) * 0.38, 3.34 + i * 0.018, 6.0)
                * CFrame.Angles(-math.pi / 2, 0, 0.08 * (i - 2))
            local model = Card.create(group, Art.samples[1], transform)
            dress(model, Art.samples[1])
        end
    end
    for i = 1, 6 do
        local model = Card.create(group, Art.samples[1], flat(Vector3.new(-3.2, 3.34 + i * 0.027, -0.5), 0.1, true))
        dress(model, Art.samples[1])
    end
end

rebuild = function()
    redrawToken += 1
    busy = false
    selected = math.clamp(selected, 1, handCount)
    flipped, spin = false, 0
    clearTable(); newHand(); newSample(); opponentHands()
    updateLabels()
end

local function selectCard(index)
    if busy then return end
    selected, flipped, spin = math.clamp(index, 1, handCount), false, 0
    newSample(); updateLabels()
end

setMode = function(value)
    mode, yaw, pitch = value, 0, 0
    updateLabels()
end

playSelected = function()
    if busy or mode == "inspect" then return end
    local index = selected
    local entry = hand[index]
    if not entry or entry.played then notice("Diese Karte liegt bereits auf dem Tisch. Mit Neu austeilen zurücksetzen."); return end
    entry.played, busy = true, true
    playCounter += 1
    -- Keep a six-card comparison grid; older studies leave the table.
    if #tableCards >= 6 then table.remove(tableCards, 1):Destroy() end
    table.insert(tableCards, entry.model)
    local slot = (playCounter - 1) % 6
    local position = Vector3.new((slot % 3 - 1) * 1.35, Tavern.tableTop + 0.035, if slot < 3 then 0.3 else -1.6)
    local token = redrawToken
    local tween = animate(entry.model, flat(position, (slot - 2) * 0.055, flipped), 0.6)
    tween.Completed:Once(function()
        if token ~= redrawToken then return end
        busy = false
        notice("Echte 3D-Karte auf dem Tisch · Licht und Entfernung vergleichen")
        for i = 1, #hand do
            if not hand[i].played then selected = i; break end
        end
        newSample()
        updateLabels()
    end)
end

local modeButtons = {}
modeButtons.table = button(toolbar, "1  Am Tisch", 14, 12, 183, function() setMode("table") end)
modeButtons.top = button(toolbar, "2  Überblick", 205, 12, 183, function() setMode("top") end)
modeButtons.inspect = button(toolbar, "3  Karte prüfen", 396, 12, 183, function() setMode("inspect") end)
local lightButton = button(toolbar, "", 587, 12, 190, function()
    preset = if preset == "tavern" then "neutral" elseif preset == "neutral" then "moon" else "tavern"
    Tavern.lighting(preset); updateLabels()
end)
button(toolbar, "Bedienung", 785, 12, 196, function()
    notice("1–3 Ansicht · ← → Karte · F umdrehen · Leertaste ausspielen · R neu · Rechtsziehen: umsehen / Karte drehen")
end)
button(toolbar, "‹", 14, 56, 38, function() selectCard(selected - 1) end)
local cardLabel = text(toolbar, "", UDim2.fromOffset(63, 56), UDim2.fromOffset(266, 35), 13, p.goldLight)
button(toolbar, "›", 339, 56, 38, function() selectCard(selected + 1) end)
button(toolbar, "Umdrehen · F", 396, 56, 183, function() flipped = not flipped; updateLabels() end)
button(toolbar, "Auf Tisch · Leertaste", 587, 56, 190, playSelected, true)
button(toolbar, "Neu austeilen · R", 785, 56, 196, rebuild)
local countButton = button(toolbar, "", 14, 100, 183, function()
    handCount = if handCount == 6 then 10 elseif handCount == 10 then 20 else 6
    rebuild()
end)
local rankButton = button(toolbar, "", 205, 100, 183, function()
    rank = if rank == 13 then 1 elseif rank == 1 then 7 else 13
    rebuild()
end)
local readableButton = button(toolbar, "", 396, 100, 183, function()
    readable = not readable
    for _, entry in ipairs(hand) do Card.setReadable(entry.model, readable) end
    if sample then Card.setReadable(sample, readable) end
    for _, object in ipairs(scene.OpponentCards:GetChildren()) do Card.setReadable(object, readable) end
    updateLabels()
end)
local artPanel = make("Frame", gui, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -20, 0, 94),
    Size = UDim2.fromOffset(352, 206), BackgroundColor3 = p.ink, BackgroundTransparency = 0.03, BorderSizePixel = 0,
    Visible = false })
round(artPanel, 12)
text(artPanel, "Eigene Illustration ausprobieren", UDim2.fromOffset(14, 10), UDim2.fromOffset(320, 27), 15, p.goldLight)
text(artPanel, "Bild in Roblox hochladen. Die Bild-ID hier eingeben. Gilt nur für diese Lab-Sitzung.",
    UDim2.fromOffset(14, 40), UDim2.fromOffset(320, 44), 12, p.muted)
local imageInput = make("TextBox", artPanel, { Position = UDim2.fromOffset(14, 93), Size = UDim2.fromOffset(322, 35),
    Text = "", PlaceholderText = "Bild-ID, z. B. 123456789", TextColor3 = p.paperLight, PlaceholderColor3 = p.muted,
    Font = Enum.Font.Gotham, TextSize = 14, BackgroundColor3 = Color3.fromRGB(43, 43, 47), BorderSizePixel = 0,
    ClearTextOnFocus = false })
round(imageInput, 7)
local applyImage
button(artPanel, "Vorderseite", 14, 140, 151, function() applyImage(false) end, true)
button(artPanel, "Rückseite", 177, 140, 159, function() applyImage(true) end)
text(artPanel, "Leeres Feld: Ornamententwurf wiederherstellen", UDim2.fromOffset(14, 179), UDim2.fromOffset(322, 20), 10, p.muted)
button(toolbar, "Illustration testen", 587, 100, 190, function() artPanel.Visible = not artPanel.Visible end)
button(toolbar, "Maßstab & Hinweise", 785, 100, 196, function()
    notice("Karte 1,06 × 1,58 Studs · sechs Sitzplätze · Figuren sind Maßstabs-Dummys · noch keine Spielregeln im Lab")
end)

applyImage = function(isBack)
    local raw = imageInput.Text:match("^%s*(.-)%s*$")
    local id = raw:match("^(%d+)$") or raw:match("^rbxassetid://(%d+)$")
    if raw ~= "" and not id then notice("Bitte nur eine Bild-ID oder rbxassetid://ID eingeben."); return end
    local image = if id then "rbxassetid://" .. id else ""
    local style = dataFor(selected).suit or dataFor(selected).kind
    if isBack then backArt = image else artworks[style] = image end
    local function apply(model)
        if model and model.PrimaryPart and (isBack or model:GetAttribute("Style") == style) then
            Card.setArtwork(model, image, isBack)
        end
    end
    -- Hidden inspection/hand models have no Parent; update those handles too.
    apply(sample)
    for _, entry in ipairs(hand) do apply(entry.model) end
    for _, object in ipairs(scene.OpponentCards:GetChildren()) do apply(object) end
    if image == "" then notice("Ornamententwurf wiederhergestellt."); return end
    notice("Illustration wird geladen …")
    task.spawn(function()
        local probe = Instance.new("ImageLabel")
        probe.Image = image
        local loaded = false
        local ok = pcall(function()
            ContentProvider:PreloadAsync({ probe }, function(_, status)
                loaded = status == Enum.AssetFetchStatus.Success
            end)
        end)
        probe:Destroy()
        notice(if ok and loaded then "Bild geladen. Jetzt Vorder-/Rückseite und Licht prüfen."
            else "Bild nicht geladen: Bild-ID, Freigabe oder Roblox-Moderation prüfen.")
    end)
end

updateLabels = function()
    local names = { table = "Sitzperspektive", top = "Tischübersicht", inspect = "Kartenprüfung" }
    local lights = { tavern = "Taverne", neutral = "Neutral", moon = "Mondlicht" }
    description.Text = names[mode] .. "  ·  " .. lights[preset] .. "  ·  Grafikstudie, kein laufendes Spiel"
    hint.Text = if mode == "inspect" then "Einzelkarte: mit rechter Maustaste ziehen zum Drehen. F zeigt die Rückseite."
        elseif mode == "top" then "Karten ausspielen und Größen, Schatten sowie Überlappungen beurteilen."
        else "Karte anklicken zum Anheben, noch einmal zum Ausspielen. Rechtsziehen zum Umsehen."
    cardLabel.Text = string.format("%d / %d · %s%s", selected, handCount, Art.names[dataFor(selected).suit or dataFor(selected).kind],
        if flipped then " · Rücken" else "")
    lightButton.Text, countButton.Text = "Licht: " .. lights[preset], "Hand: " .. handCount .. " Karten"
    rankButton.Text = "Zahlenkarte: " .. rank
    readableButton.Text = if readable then "Lesbarkeit: unterstützt" else "Lesbarkeit: Raumlicht"
    for key, object in pairs(modeButtons) do
        object.BackgroundColor3 = if mode == key then p.gold else Color3.fromRGB(42, 43, 44)
        object.TextColor3 = if mode == key then p.ink else p.paperLight
    end
end

local cameraValue = Instance.new("CFrameValue")
cameraValue.Value = CFrame.lookAt(Tavern.eye, Tavern.focus)
local lastMode = "table"
local function pick(point)
    local camera = workspace.CurrentCamera
    if not camera then return nil end
    -- ScreenPointToRay uses screen coordinates, matching GetMouseLocation/touch.
    local cast = camera:ScreenPointToRay(point.X, point.Y)
    local result = workspace:Raycast(cast.Origin, cast.Direction * 80, ray)
    if not result then return nil end
    local model = result.Instance:FindFirstAncestorOfClass("Model")
    return model and model:GetAttribute("HandIndex")
end

UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.UserInputType == Enum.UserInputType.MouseButton2 then
        heldDrag, lastPointer = true, UserInputService:GetMouseLocation()
    elseif input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        if mode == "inspect" then return end
        local point = if input.UserInputType == Enum.UserInputType.Touch then input.Position else UserInputService:GetMouseLocation()
        local index = pick(point)
        if index and hand[index] and not hand[index].played then
            if selected == index then hover = index; playSelected() else selectCard(index) end
        end
    elseif input.KeyCode == Enum.KeyCode.One then setMode("table")
    elseif input.KeyCode == Enum.KeyCode.Two then setMode("top")
    elseif input.KeyCode == Enum.KeyCode.Three then setMode("inspect")
    elseif input.KeyCode == Enum.KeyCode.Left then selectCard(selected - 1)
    elseif input.KeyCode == Enum.KeyCode.Right then selectCard(selected + 1)
    elseif input.KeyCode == Enum.KeyCode.F then flipped = not flipped; updateLabels()
    elseif input.KeyCode == Enum.KeyCode.Space then hover = nil; playSelected()
    elseif input.KeyCode == Enum.KeyCode.R then rebuild() end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton2 then heldDrag, lastPointer = false, nil end
end)

rebuild()
Tavern.lighting(preset)
pcall(function()
    StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
    StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
    StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
end)
RunService:BindToRenderStep("AssetLabCamera", Enum.RenderPriority.Camera.Value + 1, function(dt)
    local camera = workspace.CurrentCamera
    if not camera then return end
    resizeUI()
    if heldDrag then
        local pointer = UserInputService:GetMouseLocation()
        if lastPointer then
            local delta = pointer - lastPointer
            if mode == "inspect" then spin += delta.X * 0.012
            elseif mode == "table" then
                yaw = math.clamp(yaw - delta.X * 0.0025, -0.7, 0.7)
                pitch = math.clamp(pitch - delta.Y * 0.0025, -0.32, 0.32)
            end
        end
        lastPointer = pointer
    end
    local target, fov = Layout.camera(mode, Tavern.eye, Tavern.focus, Tavern.inspection, yaw, pitch)
    if lastMode ~= mode then
        cameraValue.Value = camera.CFrame
        -- The camera follows a single spring below; no competing camera scripts.
        lastMode = mode
    end
    cameraValue.Value = cameraValue.Value:Lerp(target, 1 - math.exp(-dt * 8))
    camera.CameraType, camera.CFrame, camera.FieldOfView = Enum.CameraType.Scriptable, cameraValue.Value, fov
    if mode ~= "inspect" and not UserInputService.TouchEnabled then hover = pick(UserInputService:GetMouseLocation()) else hover = nil end
    for i, entry in ipairs(hand) do
        if not entry.played then
            entry.model.Parent = if mode == "inspect" then nil else scene
            if mode ~= "inspect" then
                local wanted = if i == selected or i == hover then 1 else 0
                entry.raised += (wanted - entry.raised) * (1 - math.exp(-dt * 15))
                local position = Layout.hand(camera.CFrame, i, #hand, entry.raised, i == selected and flipped,
                    mode == "top", camera.ViewportSize.X / math.max(1, camera.ViewportSize.Y))
                entry.model:PivotTo(position)
            end
        end
    end
    sample.Parent = if mode == "inspect" then scene else nil
    if mode == "inspect" then
        sample:PivotTo(CFrame.lookAt(Tavern.inspection, Tavern.inspection + Vector3.new(0, 0, 5))
            * CFrame.Angles(0, spin + (if flipped then math.pi else 0), 0))
    end
end)
