local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local StarterGui = game:GetService("StarterGui")
local player = Players.LocalPlayer
local Rules = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Rules"))
local remotes = ReplicatedStorage:WaitForChild("WizardRemotes")
local action = remotes:WaitForChild("Action")
local state = remotes:WaitForChild("State")

local C = {
    ink = Color3.fromRGB(15, 19, 32), panel = Color3.fromRGB(27, 32, 48),
    text = Color3.fromRGB(242, 234, 218), muted = Color3.fromRGB(164, 169, 188),
    gold = Color3.fromRGB(226, 189, 113), purple = Color3.fromRGB(173, 142, 245),
    green = Color3.fromRGB(106, 216, 178), red = Color3.fromRGB(238, 118, 131),
}
local suitColors = { red = Color3.fromRGB(195, 70, 83), yellow = Color3.fromRGB(176, 125, 37),
    green = Color3.fromRGB(37, 132, 112), blue = Color3.fromRGB(55, 108, 185),
    wizard = Color3.fromRGB(112, 70, 169), jester = Color3.fromRGB(83, 92, 112) }
local symbols = { red = "◆", yellow = "☀", green = "♣", blue = "≋", wizard = "W", jester = "N" }
local current, render, modal
local bidValue, bidRound, bidEpoch = 0, nil, nil
local pending = false
local handScroll = Vector2.zero
local lastHand

local function create(class, parent, properties)
    local instance = Instance.new(class)
    for key, value in pairs(properties or {}) do instance[key] = value end
    instance.Parent = parent
    return instance
end
local function corner(object, radius)
    create("UICorner", object, { CornerRadius = UDim.new(0, radius or 14) })
end
local function stroke(object, color, thickness, transparency)
    return create("UIStroke", object, { Color = color, Thickness = thickness or 1,
        Transparency = transparency or 0 })
end
local function frame(parent, x, y, w, h, color, transparency)
    return create("Frame", parent, { Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h),
        BackgroundColor3 = color or C.panel, BackgroundTransparency = transparency or 0, BorderSizePixel = 0 })
end
local function label(parent, text, x, y, w, h, size, color, alignment)
    return create("TextLabel", parent, { Text = text, Position = UDim2.fromOffset(x, y),
        Size = UDim2.fromOffset(w, h), BackgroundTransparency = 1, TextColor3 = color or C.text,
        Font = Enum.Font.GothamMedium, TextSize = size or 18, TextWrapped = true,
        TextXAlignment = alignment or Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Center })
end
local function button(parent, text, x, y, w, h, callback, color, disabled)
    local object = create("TextButton", parent, { Text = text, Position = UDim2.fromOffset(x, y),
        Size = UDim2.fromOffset(w, h), BackgroundColor3 = color or C.gold, BorderSizePixel = 0,
        TextColor3 = if disabled then C.muted else C.ink, TextSize = 16, Font = Enum.Font.GothamBold,
        AutoButtonColor = not disabled, Active = not disabled, Selectable = not disabled })
    if disabled then object.BackgroundColor3 = C.panel end
    corner(object, 10)
    object.Activated:Connect(function() if not disabled then callback() end end)
    return object
end
local function request(verb, value)
    if pending then return end
    pending = true
    action:FireServer(verb, value, current and current.revision, current and current.epoch)
    task.delay(0.8, function() pending = false end)
end

local gui = create("ScreenGui", player:WaitForChild("PlayerGui"), {
    Name = "WizardUI", ResetOnSpawn = false, IgnoreGuiInset = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling })
local background = create("Frame", gui, { Size = UDim2.fromScale(1, 1), BorderSizePixel = 0,
    BackgroundColor3 = C.ink, BackgroundTransparency = 0.28 })
local root = create("Frame", background, { Size = UDim2.fromOffset(1280, 800),
    AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), BackgroundTransparency = 1 })
local scale = create("UIScale", root, {})
local function resize()
    scale.Scale = math.min(background.AbsoluteSize.X / 1280, background.AbsoluteSize.Y / 800)
end
background:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize)
resize()

local content = frame(root, 0, 0, 1280, 800, C.ink, 1)
label(root, "W I Z A R D", 34, 12, 320, 48, 34, C.gold, Enum.TextXAlignment.Left)
label(root, "D E R   M A G I S C H E   K A R T E N T I S C H", 36, 57, 410, 20, 11, C.muted, Enum.TextXAlignment.Left)
local status = label(root, "Verbindung zum Tisch …", 485, 16, 440, 42, 18)
local timer = label(root, "", 940, 20, 80, 35, 17, C.gold)
local toast = label(root, "", 210, 778, 860, 22, 14, C.red)

local function notify(message)
    toast.Text = message
    task.delay(4, function() if toast.Text == message then toast.Text = "" end end)
end

local function card(parent, data, x, y, width, height, playable, callback)
    local suit = if data.kind == "number" then data.suit else data.kind
    local color = suitColors[suit]
    local object = create("TextButton", parent, { Text = "", BackgroundColor3 = Color3.fromRGB(242, 232, 208),
        Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(width, height), BorderSizePixel = 0,
        AutoButtonColor = false, Selectable = playable == true })
    corner(object, 10)
    stroke(object, if playable then C.gold else color, if playable then 3 else 1)
    local inset = frame(object, 6, 6, width - 12, height - 12, color)
    corner(inset, 7)
    create("UIGradient", inset, { Color = ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.15), color) })
    local value = if data.kind == "number" then tostring(data.rank) else symbols[suit]
    label(object, value, 8, 7, 34, 27, math.min(22, width * 0.25))
    label(object, symbols[suit], 0, height * 0.24, width, height * 0.42, width * 0.43)
    local name = if data.kind == "wizard" then "WIZARD" elseif data.kind == "jester" then "NARR" else Rules.suitNames[data.suit]
    label(object, name, 5, height - 33, width - 10, 22, math.min(12, width * 0.12))
    if playable == false then
        local shade = frame(object, 0, 0, width, height, C.ink, 0.52)
        corner(shade, 10)
    end
    if playable and callback then
        object.Activated:Connect(callback)
        object.MouseEnter:Connect(function()
            TweenService:Create(object, TweenInfo.new(0.12), { Position = UDim2.fromOffset(x, y - 8) }):Play()
        end)
        object.MouseLeave:Connect(function()
            TweenService:Create(object, TweenInfo.new(0.12), { Position = UDim2.fromOffset(x, y) }):Play()
        end)
    end
    return object
end

local function openModal(title)
    if modal then modal:Destroy() end
    modal = frame(root, 0, 0, 1280, 800, C.ink, 0.1)
    modal.ZIndex = 10
    local panel = frame(modal, 210, 80, 860, 650, C.panel)
    corner(panel, 20); stroke(panel, C.gold, 1, 0.5)
    label(panel, title, 35, 20, 700, 45, 25, C.gold, Enum.TextXAlignment.Left)
    button(panel, "Schließen", 680, 25, 145, 40, function() modal:Destroy(); modal = nil end)
    return panel
end

button(root, "Punkte", 1030, 22, 100, 40, function()
    local panel = openModal("Block der Wahrheit")
    if not current or not current.history or #current.history == 0 then
        label(panel, "Nach der ersten Runde erscheint hier euer Punkteverlauf.", 50, 140, 760, 100, 20)
        return
    end
    local scroll = create("ScrollingFrame", panel, { Position = UDim2.fromOffset(25, 90),
        Size = UDim2.fromOffset(810, 530), CanvasSize = UDim2.fromOffset(0, 45 + #current.history * 38),
        BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 5 })
    label(scroll, "Runde", 0, 0, 80, 35, 14, C.muted)
    local width = 710 / #current.seats
    for i, seat in ipairs(current.seats) do label(scroll, seat.name, 80 + (i - 1) * width, 0, width, 35, 13, C.gold) end
    for r, row in ipairs(current.history) do
        label(scroll, tostring(r), 0, r * 38, 80, 35, 16)
        for i, result in ipairs(row) do
            label(scroll, string.format("%d/%d · %d P.", result.taken, result.bid, result.score),
                80 + (i - 1) * width, r * 38, width, 35, 14, if result.delta >= 0 then C.green else C.red)
        end
    end
end, C.purple)

button(root, "Spielregeln", 1140, 22, 110, 40, function()
    local panel = openModal("So spielst du Wizard")
    local text = "1   Sage voraus, wie viele Stiche du in dieser Runde gewinnst. In Runde 1 erhältst du eine Karte, in Runde 2 zwei – und so weiter.\n\n"
        .. "2   Spiele reihum eine Karte. Du musst die zuerst angespielte Farbe bedienen, wenn du sie hast. Wizards und Narren darfst du immer spielen. Gold umrandete Karten sind spielbar.\n\n"
        .. "3   Der erste Wizard gewinnt. Sonst gewinnt der höchste Trumpf, sonst die höchste Karte der angespielten Farbe. Nur Narren? Der erste Narr gewinnt. Ein eröffnender Wizard hebt die Bedienpflicht auf; nach eröffnenden Narren entscheidet die erste andere Karte.\n\n"
        .. "4   Genau richtig angesagt: 20 Punkte plus 10 pro Stich. Daneben: minus 10 pro Stich Abweichung. Die Summe aller Ansagen darf der Stichzahl entsprechen (Grundregel).\n\n"
        .. "Die aufgedeckte Karte bestimmt Trumpf. Bei einem Wizard wählt der Geber eine Farbe; bei einem Narren oder leerem Stapel gibt es keinen Trumpf. Der Stichgewinner spielt als Nächstes aus.\n\n"
        .. "Du hast 45 Sekunden pro Zug. Danach spielt der Assistent für dich. Bei Verbindungsabbruch übernimmt ein Bot. Auf kleinen Displays empfiehlt sich Querformat."
    local body = label(panel, text, 40, 85, 780, 530, 17, C.text, Enum.TextXAlignment.Left)
    body.TextYAlignment = Enum.TextYAlignment.Top
end)

local function lobby(view)
    status.Text = "Die Akademie wartet auf dich"
    local panel = frame(content, 310, 190, 660, 365, C.panel, 0.05)
    corner(panel, 22); stroke(panel, C.gold, 1, 0.5)
    label(panel, "Dein nächster Stich ist Magie.", 35, 25, 590, 60, 30, C.gold)
    label(panel, "Schätze deine Stiche. Spiele deine Karten.\nBeweise deine Gabe der Vorhersehung.", 55, 92, 550, 60, 19, C.text)
    button(panel, "Mit Bots üben", 55, 178, 260, 56, function() request("start", "practice") end)
    local canStart = view.hostId == player.UserId and #view.seats >= 3
    button(panel, "Mehrspieler starten", 330, 178, 275, 56, function() request("start", "friends") end, C.purple, not canStart)
    label(panel, string.format("%d Spieler in der Lobby · 3–6 pro Partie", #view.seats), 55, 251, 550, 28, 16, C.muted)
    local names = {}
    for _, seat in ipairs(view.seats) do table.insert(names, seat.name) end
    label(panel, table.concat(names, "  ·  "), 40, 282, 580, 45, 16)
    label(content, "Übungsmodus: du + Mira + Orion\nMehrspieler: Der Gastgeber startet, sobald mindestens 3 Spieler da sind.",
        310, 585, 660, 65, 16, C.muted)
end

render = function(view)
    if lastHand and lastHand.Parent then handScroll = lastHand.CanvasPosition end
    content:ClearAllChildren()
    if view.phase == "lobby" then lobby(view); return end
    if bidRound ~= view.round or bidEpoch ~= view.epoch then
        bidRound, bidEpoch, bidValue = view.round, view.epoch, 0
    end
    status.Text = string.format("Runde %d / %d   ·   Stich %d / %d", view.round, view.maxRounds, view.trickNumber, view.round)
    local seatWidth = 1200 / #view.seats
    for i, seat in ipairs(view.seats) do
        local isTurn = view.turn == i
        local panel = frame(content, 40 + (i - 1) * seatWidth, 100, seatWidth - 10, 95, C.panel, 0.08)
        corner(panel, 12)
        if isTurn then stroke(panel, C.gold, 2) end
        local suffix = if seat.bot then " · BOT" elseif view.mySeat == i then " · DU" else ""
        local name = label(panel, seat.name .. suffix, 10, 6, seatWidth - 30, 27, 16, if isTurn then C.gold else C.text)
        name.TextTruncate = Enum.TextTruncate.AtEnd
        name.TextWrapped = false
        label(panel, string.format("%d Punkte   ·   %d Karten", seat.score, seat.count), 8, 35, seatWidth - 26, 22, 14, C.muted)
        label(panel, "Stiche: " .. seat.taken .. " / " .. (if seat.bid ~= nil then tostring(seat.bid) else "–")
            .. (if view.dealer == i then "   ◇ Geber" else ""), 8, 60, seatWidth - 26, 24, 14, C.text)
    end
    local tableFrame = frame(content, 190, 222, 900, 280, Color3.fromRGB(22, 58, 58), 0.12)
    corner(tableFrame, 130); stroke(tableFrame, C.gold, 2, 0.35)
    local inner = frame(tableFrame, 13, 13, 874, 254, Color3.fromRGB(22, 58, 58), 1)
    corner(inner, 120); stroke(inner, C.gold, 1, 0.78)
    label(tableFrame, "A K A D E M I E   D E R   V O R H E R S E H U N G", 100, 14, 700, 24, 11, C.gold)
    if #view.trick == 0 then
        label(tableFrame, "W", 350, 65, 200, 100, 80, C.gold).TextTransparency = 0.75
        label(tableFrame, "Jede Karte erzählt dein Schicksal.", 200, 175, 500, 35, 16, C.muted)
    else
        local width, gap = 100, 18
        local startX = (900 - (#view.trick * (width + gap) - gap)) / 2
        for i, play in ipairs(view.trick) do
            local x = startX + (i - 1) * (width + gap)
            card(tableFrame, play.card, x, 56, width, 148, nil)
            label(tableFrame, view.seats[play.seat].name, x - 9, 211, width + 18, 30, 13,
                if play.seat == view.lastWinner and view.phase ~= "playing" then C.gold else C.text)
        end
    end
    label(content, "T R U M P F", 30, 225, 145, 30, 12, C.muted)
    local trumpName = if view.phase == "chooseTrump" then "Wird gewählt …" elseif view.trump then Rules.suitNames[view.trump] else "Kein Trumpf"
    label(content, trumpName, 30, 258, 145, 30, 20, C.gold)
    if view.turnedCard then card(content, view.turnedCard, 57, 300, 90, 132, nil)
    else label(content, "Alle Karten\nsind verteilt.", 30, 318, 145, 75, 16, C.muted) end
    label(content, "DEIN ZIEL", 1110, 260, 140, 30, 12, C.muted)
    local mine = view.mySeat and view.seats[view.mySeat]
    if mine then
        label(content, tostring(mine.taken) .. " / " .. (if mine.bid ~= nil then tostring(mine.bid) else "–"), 1110, 297, 140, 60, 34, C.gold)
        label(content, "Stiche / Ansage", 1110, 358, 140, 35, 14, C.muted)
    else label(content, "Zuschauer", 1110, 300, 140, 45, 18, C.gold) end

    local message = ""
    if view.phase == "trickComplete" then message = view.seats[view.lastWinner].name .. " gewinnt den Stich."
    elseif view.phase == "roundComplete" then message = "Runde beendet. Die nächste Runde beginnt gleich."
    elseif view.phase == "finished" then
        local high, winners = -math.huge, {}
        for _, seat in ipairs(view.seats) do
            if seat.score > high then high, winners = seat.score, { seat.name }
            elseif seat.score == high then table.insert(winners, seat.name) end
        end
        message = table.concat(winners, " & ") .. " gewinnt!  ·  " .. high .. " Punkte"
    elseif view.turn then
        local who = if view.turn == view.mySeat then "Du bist" else view.seats[view.turn].name .. " ist"
        message = who .. (if view.phase == "bidding" then " mit der Ansage dran." elseif view.phase == "chooseTrump" then " mit der Trumpfwahl dran." else " am Zug.")
    end
    label(content, message, 190, 478, 900, 36, 20, C.gold)
    local controls = frame(content, 190, 526, 900, 59, C.panel, 0.1)
    corner(controls, 12)
    if view.turn == view.mySeat and view.phase == "bidding" then
        label(controls, "Wie viele Stiche gewinnst du?", 12, 10, 355, 38, 18, C.text)
        button(controls, "−", 390, 8, 45, 43, function() bidValue = math.max(0, bidValue - 1); render(current) end, C.purple)
        label(controls, tostring(bidValue), 444, 8, 65, 43, 25, C.gold)
        button(controls, "+", 520, 8, 45, 43, function() bidValue = math.min(view.round, bidValue + 1); render(current) end, C.purple)
        button(controls, "Ansage bestätigen", 600, 8, 280, 43, function() request("bid", bidValue) end)
    elseif view.turn == view.mySeat and view.phase == "chooseTrump" then
        label(controls, "Wähle Trumpf:", 10, 10, 205, 38, 18)
        for i, suit in ipairs(Rules.suits) do
            button(controls, symbols[suit] .. " " .. Rules.suitNames[suit], 230 + (i - 1) * 162, 8, 150, 43,
                function() request("trump", suit) end, suitColors[suit]).TextColor3 = C.text
        end
    elseif view.phase == "roundComplete" or view.phase == "finished" then
        if mine then
            label(controls, string.format("Deine Runde: %d von %d Stichen · %+d Punkte · Gesamt: %d", mine.taken, mine.bid, mine.delta or 0, mine.score),
                10, 8, if view.phase == "finished" then 650 else 880, 43, 18, if (mine.delta or 0) >= 0 then C.green else C.red)
        end
        if view.phase == "finished" and view.hostId == player.UserId then
            button(controls, "Zur Lobby", 690, 8, 190, 43, function() request("lobby") end)
        end
    else
        label(controls, if view.turn == view.mySeat then "Wähle eine gold umrandete Karte aus deiner Hand." else "Beobachte den Tisch und plane deinen nächsten Zug.",
            15, 8, 870, 43, 17, C.muted)
    end
    label(content, if mine then "DEINE HAND  ·  " .. #view.hand .. " KARTEN" else "DU SCHAUST ZU · Die nächste Partie startet in der Lobby.",
        40, 593, 1120, 24, 12, C.muted, Enum.TextXAlignment.Left)
    local hand = create("ScrollingFrame", content, { Position = UDim2.fromOffset(38, 621), Size = UDim2.fromOffset(1204, 155),
        CanvasSize = UDim2.fromOffset(math.max(1204, #view.hand * 106 + 12), 0), ScrollBarThickness = 5,
        BackgroundTransparency = 1, BorderSizePixel = 0, ScrollingDirection = Enum.ScrollingDirection.X })
    lastHand = hand
    hand.CanvasPosition = Vector2.new(math.min(handScroll.X, math.max(0, #view.hand * 106 + 12 - 1204)), 0)
    local sorted = table.clone(view.hand)
    table.sort(sorted, function(a, b)
        local ka, kb = a.suit or a.kind, b.suit or b.kind
        if ka == kb then return a.rank < b.rank end
        return ka < kb
    end)
    local startX = math.max(10, (1204 - #sorted * 106) / 2)
    for i, data in ipairs(sorted) do
        local playable = if view.phase == "playing" then view.legal[data.id] == true else nil
        card(hand, data, startX + (i - 1) * 106, 10, 94, 133, playable, function() request("play", data.id) end)
    end
end

state.OnClientEvent:Connect(function(view)
    pending = false
    if view.error then notify(view.error); return end
    current = view
    render(view)
end)

RunService.RenderStepped:Connect(function()
    local camera = workspace.CurrentCamera
    if camera then
        camera.CameraType = Enum.CameraType.Scriptable
        camera.CFrame = CFrame.lookAt(Vector3.new(0, 31, 32), Vector3.new(0, 3, 0))
        camera.FieldOfView = 55
    end
    if current and current.deadline then
        timer.Text = tostring(math.max(0, math.ceil(current.deadline - workspace:GetServerTimeNow()))) .. " s"
    else timer.Text = "" end
end)
pcall(function()
    StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
    StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
    StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
end)
action:FireServer("sync")
