local Art = require(script.Parent.ArtDirection)
local Card = {}

local function make(class, parent, properties)
    local object = Instance.new(class)
    for key, value in pairs(properties or {}) do object[key] = value end
    object.Parent = parent
    return object
end
local function round(parent, radius)
    make("UICorner", parent, { CornerRadius = UDim.new(0, radius) })
end
local function line(parent, color, width, transparency)
    return make("UIStroke", parent, { Color = color, Thickness = width or 1,
        Transparency = transparency or 0, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
end
local function box(parent, x, y, w, h, color, radius)
    local object = make("Frame", parent, { Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h),
        BackgroundColor3 = color, BorderSizePixel = 0 })
    if radius then round(object, radius) end
    return object
end
local function text(parent, value, x, y, w, h, size, color, font)
    return make("TextLabel", parent, { Text = value, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h),
        BackgroundTransparency = 1, TextColor3 = color, TextSize = size, FontFace = Font.fromEnum(font or Enum.Font.Garamond),
        TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Center })
end
local function circle(parent, x, y, diameter, color, hollow)
    local object = box(parent, x, y, diameter, diameter, color, diameter / 2)
    if hollow then object.BackgroundTransparency = 1; line(object, color, hollow) end
    return object
end
local function diamond(parent, x, y, size, color, hollow)
    local object = box(parent, x, y, size, size, color, 2)
    object.Rotation = 45
    if hollow then object.BackgroundTransparency = 1; line(object, color, hollow) end
    return object
end

-- Editable engraving studies; optional uploaded illustrations cover this layer.
local function engraving(parent, suit)
    local gold = Art.palette.goldLight
    local root = box(parent, 0, 0, 300, 394, Art.palette[suit])
    root.Name = "Engraving"
    make("UIGradient", root, { Rotation = 90,
        Color = ColorSequence.new(Art.palette[suit]:Lerp(Color3.new(1, 1, 1), 0.15), Art.palette.ink) })
    circle(root, 32, 62, 236, gold, 2)
    circle(root, 50, 80, 200, gold, 1).BackgroundTransparency = 1
    for i = 1, 12 do
        local angle = i * math.pi / 6
        diamond(root, 147 + math.cos(angle) * 111, 177 + math.sin(angle) * 111, 5, gold)
    end
    if suit == "wizard" then
        -- Star, pointed crown, hood and crossed staff: original geometric study.
        diamond(root, 137, 86, 26, gold)
        local hood = diamond(root, 108, 139, 84, gold)
        hood.BackgroundTransparency = 0.07
        circle(root, 122, 158, 56, Art.palette.ink)
        local robe = box(root, 103, 208, 94, 77, Art.palette.ink, 34)
        line(robe, gold, 2)
        local staff = box(root, 204, 120, 5, 177, gold, 2)
        staff.Rotation = 14
        circle(root, 202, 105, 20, gold, 2)
        text(root, "✦", 66, 258, 168, 45, 30, gold)
    elseif suit == "jester" then
        diamond(root, 117, 123, 65, gold)
        circle(root, 122, 140, 57, Art.palette.ink)
        diamond(root, 124, 162, 9, gold)
        diamond(root, 158, 162, 9, gold)
        local smile = circle(root, 126, 176, 47, gold, 2)
        smile.ClipsDescendants = true
        box(root, 125, 173, 51, 24, Art.palette.ink)
        for i = -1, 1 do
            local cap = diamond(root, 135 + i * 45, 104 - math.abs(i) * 12, 25, gold)
            cap.Rotation = i * 25
            circle(root, 142 + i * 47, 84 - math.abs(i) * 12, 10, gold)
        end
        text(root, "✦  ◇  ✦", 55, 262, 190, 40, 23, gold)
    elseif suit == "red" then
        for i = 1, 4 do
            local flame = diamond(root, 89 + i * 20, 113 + math.abs(i - 2.5) * 22, 57, gold)
            flame.Rotation = 45 + (i - 2.5) * 12
        end
        diamond(root, 125, 188, 49, Art.palette.red)
        box(root, 105, 264, 91, 3, gold)
    elseif suit == "yellow" then
        for i = 1, 12 do
            local ray = box(root, 147, 90, 6, 35, gold, 2)
            ray.AnchorPoint, ray.Position = Vector2.new(0.5, 1), UDim2.fromOffset(150, 178)
            ray.Size, ray.Rotation = UDim2.fromOffset(6, 91), i * 30
        end
        circle(root, 112, 140, 76, Art.palette.yellow)
        circle(root, 119, 147, 62, gold, 3)
        diamond(root, 135, 163, 29, gold)
    elseif suit == "green" then
        box(root, 147, 119, 6, 169, gold, 2)
        for i = 1, 4 do
            local leaf = diamond(root, 100, 111 + i * 28, 34, gold)
            leaf.Rotation = 20
            local other = diamond(root, 165, 95 + i * 28, 34, gold)
            other.Rotation = 70
        end
    elseif suit == "blue" then
        circle(root, 106, 110, 88, gold, 3)
        circle(root, 122, 101, 88, Art.palette.blue)
        for i = 1, 3 do text(root, "≋", 63, 172 + i * 24, 178, 43, 63, gold) end
    end
    text(root, "·  A R C A N A  ·", 40, 333, 220, 28, 16, gold)
    return root
end

local function surface(part, name, face)
    return make("SurfaceGui", part, { Name = name, Face = face,
        SizingMode = Enum.SurfaceGuiSizingMode.FixedSize, CanvasSize = Art.card.pixels,
        AlwaysOnTop = false, LightInfluence = 0.3, Brightness = 1,
        MaxDistance = 65, ClipsDescendants = true })
end

local function front(part, data)
    local suit = if data.kind == "number" then data.suit else data.kind
    local p = Art.palette
    local gui = surface(part, "Front", Enum.NormalId.Front)
    local paper = box(gui, 0, 0, 424, 632, p.paper, 24)
    paper.Name = "Paper"
    make("UIGradient", paper, { Rotation = 35, Color = ColorSequence.new(p.paperLight, p.paper) })
    local border = box(paper, 15, 15, 394, 602, p.paper, 18)
    border.BackgroundTransparency = 1; line(border, p.gold, 2)
    local inner = box(paper, 24, 24, 376, 584, p.paper, 14)
    inner.BackgroundTransparency = 1; line(inner, p.gold, 1, 0.45)
    local value = if data.kind == "number" then tostring(data.rank) else Art.symbols[suit]
    text(paper, value, 31, 27, 67, 71, 57, p[suit])
    text(paper, Art.symbols[suit], 36, 94, 55, 39, 31, p[suit])
    local inverted = text(paper, value, 326, 534, 67, 71, 57, p[suit])
    inverted.Rotation = 180
    local symbol = text(paper, Art.symbols[suit], 333, 498, 55, 39, 31, p[suit])
    symbol.Rotation = 180
    local illustration = box(paper, 62, 126, 300, 394, p[suit], 130)
    illustration.Name, illustration.ClipsDescendants = "Illustration", true
    engraving(illustration, suit)
    local image = make("ImageLabel", illustration, { Name = "Artwork", BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1), Image = Art.images[suit] or "", ScaleType = Enum.ScaleType.Crop,
        Visible = Art.images[suit] ~= "" })
    round(image, 22)
    line(illustration, p.gold, 2)
    text(paper, Art.names[suit], 81, 547, 243, 35, 21, p.ink)
    text(paper, "W I Z A R D", 105, 586, 214, 18, 12, p[suit])
end

local function back(part)
    local p = Art.palette
    local gui = surface(part, "Back", Enum.NormalId.Back)
    local root = box(gui, 0, 0, 424, 632, p.ink, 24)
    root.Name = "BackDesign"
    local color = Color3.fromRGB(35, 43, 46)
    make("UIGradient", root, { Rotation = 45, Color = ColorSequence.new(color, p.ink) })
    for i = 0, 6 do
        for k = 0, 10 do
            local tile = diamond(root, 18 + i * 59, 18 + k * 59, 35, p.gold, 1)
            tile:FindFirstChildOfClass("UIStroke").Transparency = 0.76
        end
    end
    for _, inset in ipairs({ 17, 27, 38 }) do
        local border = box(root, inset, inset, 424 - 2 * inset, 632 - 2 * inset, p.ink, 18)
        border.BackgroundTransparency = 1; line(border, p.gold, if inset == 27 then 3 else 1)
    end
    local seal = circle(root, 102, 206, 220, p.ink)
    line(seal, p.goldLight, 3)
    circle(root, 115, 219, 194, p.gold, 1)
    diamond(root, 150, 254, 124, p.gold, 2)
    text(root, "✦", 142, 246, 140, 140, 87, p.goldLight)
    text(root, "A R C A N A", 102, 459, 220, 33, 24, p.goldLight)
    local image = make("ImageLabel", root, { Name = "BackArtwork", BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1), Image = Art.images.back, Visible = Art.images.back ~= "", ScaleType = Enum.ScaleType.Stretch })
    round(image, 24)
end

function Card.create(parent, data, transform)
    assert(table.find(Art.suits, data.suit or data.kind), "Unknown card style")
    local model = make("Model", parent, { Name = data.id or data.kind })
    model:SetAttribute("CardId", data.id or data.kind)
    model:SetAttribute("Style", data.suit or data.kind)
    local body = make("Part", model, { Name = "CardBody", Anchored = true, CanCollide = false,
        CanTouch = false, CanQuery = true, CastShadow = true,
        Size = Vector3.new(Art.card.width, Art.card.height, Art.card.thickness),
        Material = Enum.Material.SmoothPlastic, Color = Art.palette.paper, CFrame = transform or CFrame.new() })
    model.PrimaryPart = body
    front(body, data); back(body)
    return model
end

function Card.setArtwork(model, image, isBack)
    local target = if isBack then model:FindFirstChild("BackArtwork", true) else model:FindFirstChild("Artwork", true)
    assert(target, "Missing artwork slot")
    target.Image, target.Visible = image, image ~= ""
end

function Card.setReadable(model, readable)
    for _, object in ipairs(model:GetDescendants()) do
        if object:IsA("SurfaceGui") then object.LightInfluence = if readable then 0.05 else 0.7 end
    end
end

return Card
