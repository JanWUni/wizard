local Art = require(script.Parent.ArtDirection)
local Tavern = {}
Tavern.tableTop = 3.31
Tavern.eye = Vector3.new(0, 6.15, 10.3)
Tavern.focus = Vector3.new(0, 3.65, -0.8)
Tavern.inspection = Vector3.new(13.7, 5.2, 4)

local function instance(class, parent, properties)
    local object = Instance.new(class)
    for name, value in pairs(properties or {}) do object[name] = value end
    object.Parent = parent
    return object
end

function Tavern.lighting(preset)
    local light = game:GetService("Lighting")
    light.ClockTime, light.GlobalShadows = 0.2, true
    light.EnvironmentDiffuseScale, light.EnvironmentSpecularScale = 0.5, 0.65
    light.ExposureCompensation = 0.1
    local neutral = preset == "neutral"
    local moon = preset == "moon"
    light.Brightness = if neutral then 2.4 else 1.4
    light.Ambient = if neutral then Color3.fromRGB(115, 113, 109) else Color3.fromRGB(60, 51, 48)
    light.OutdoorAmbient = if neutral then Color3.fromRGB(95, 102, 111) else Color3.fromRGB(26, 33, 49)
    light.ColorShift_Top = if neutral then Color3.new(0, 0, 0) else Color3.fromRGB(14, 8, 1)
    local correction = light:FindFirstChild("LabColor") or instance("ColorCorrectionEffect", light, { Name = "LabColor" })
    correction.Brightness, correction.Contrast = 0, if neutral then 0 else 0.12
    correction.Saturation = if neutral then 0 else -0.14
    correction.TintColor = if neutral then Color3.new(1, 1, 1) elseif moon then Color3.fromRGB(180, 201, 244) else Color3.fromRGB(255, 232, 203)
    local bloom = light:FindFirstChild("LabBloom") or instance("BloomEffect", light, { Name = "LabBloom" })
    bloom.Intensity, bloom.Size, bloom.Threshold = if neutral then 0 else 0.22, 24, 1.6
    local atmosphere = light:FindFirstChild("LabAtmosphere") or instance("Atmosphere", light, { Name = "LabAtmosphere" })
    atmosphere.Density, atmosphere.Offset, atmosphere.Haze = if neutral then 0.05 else 0.23, 0.15, if neutral then 0 else 1.4
    atmosphere.Color, atmosphere.Decay = Color3.fromRGB(134, 134, 151), Color3.fromRGB(37, 31, 48)
end

function Tavern.build(parent)
    Tavern.lighting("tavern")
    local room = instance("Model", parent, { Name = "TavernStudy" })
    local wood, gold, felt = Art.palette.wood, Art.palette.gold, Art.palette.felt
    local darkWood, iron = Color3.fromRGB(36, 26, 23), Color3.fromRGB(43, 45, 44)
    local function part(name, size, transform, color, material, shape)
        local object = instance("Part", room, { Name = name, Size = size,
            CFrame = if typeof(transform) == "Vector3" then CFrame.new(transform) else transform,
            Color = color, Material = material or Enum.Material.Wood, Anchored = true,
            CanCollide = false, CanTouch = false, CanQuery = false, CastShadow = true })
        if shape then object.Shape = shape end
        return object
    end
    local function disk(name, position, diameter, height, color, material)
        return part(name, Vector3.new(height, diameter, diameter),
            CFrame.new(position) * CFrame.Angles(0, 0, math.pi / 2), color, material, Enum.PartType.Cylinder)
    end
    local function beam(name, a, b, width, color, material)
        return part(name, Vector3.new(width, width, (b - a).Magnitude), CFrame.lookAt((a + b) / 2, b), color, material)
    end
    local function solid(object)
        object.CanCollide, object.CanQuery = true, true
        return object
    end
    local function candle(position, scale)
        scale = scale or 1
        disk("BrassCandleFoot", position, 0.52 * scale, 0.08, gold, Enum.Material.Metal)
        disk("CandleWax", position + Vector3.new(0, 0.42 * scale, 0), 0.2 * scale, 0.8 * scale,
            Color3.fromRGB(213, 191, 142), Enum.Material.SmoothPlastic)
        local flame = part("CandleFlame", Vector3.new(0.1, 0.24, 0.1) * scale,
            position + Vector3.new(0, 0.9 * scale, 0), Color3.fromRGB(255, 203, 115), Enum.Material.Neon, Enum.PartType.Ball)
        local lamp = instance("PointLight", flame, { Brightness = 0.6, Range = 8 * scale,
            Color = Color3.fromRGB(255, 184, 99), Shadows = false })
        lamp.Name = "CandleLight"
    end

    -- Room shell and readable floor grain without downloaded textures.
    for i = 0, 22 do
        part("Floorboard", Vector3.new(1.95, 0.3, 44), Vector3.new(-22 + i * 2, -0.15, 0),
            wood:Lerp(darkWood, (i % 4) * 0.12), Enum.Material.WoodPlanks)
    end
    local floor = solid(part("WalkableFloor", Vector3.new(46, 0.4, 44), Vector3.new(0, -0.2, 0), wood))
    floor.Transparency = 1
    local spawn = instance("SpawnLocation", room, { Name = "TavernEntrance", Anchored = true,
        Size = Vector3.new(4, 0.2, 4), CFrame = CFrame.new(0, 0.12, 16.5), Transparency = 1,
        CanCollide = false, CanTouch = false, CanQuery = false, Neutral = true, Duration = 0 })
    local stone = Color3.fromRGB(60, 56, 55)
    solid(part("BackWall", Vector3.new(46, 17, 0.6), Vector3.new(0, 8.2, -22), stone, Enum.Material.Brick))
    solid(part("EntranceWall", Vector3.new(46, 17, 0.6), Vector3.new(0, 8.2, 22), stone, Enum.Material.Brick))
    for _, x in ipairs({ -23, 23 }) do
        solid(part("SideWall", Vector3.new(0.6, 17, 44), Vector3.new(x, 8.2, 0), stone, Enum.Material.Brick))
    end
    part("Ceiling", Vector3.new(46, 0.5, 44), Vector3.new(0, 16.5, 0), darkWood, Enum.Material.WoodPlanks)
    for _, x in ipairs({ -22.5, -11.5, 0, 11.5, 22.5 }) do
        part("OakPost", Vector3.new(0.8, 16, 0.9), Vector3.new(x, 8, -21.4), darkWood)
        part("RoofBeam", Vector3.new(0.8, 0.9, 44), Vector3.new(x, 15.7, 0), darkWood)
        for _, z in ipairs({ -11, 1, 13 }) do
            part("WallPost", Vector3.new(0.85, 16, 0.8), Vector3.new(-22.5, 8, z), darkWood)
            part("WallPost", Vector3.new(0.85, 16, 0.8), Vector3.new(22.5, 8, z), darkWood)
        end
    end
    for _, z in ipairs({ -21.3, -10, 2, 14 }) do
        part("Crossbeam", Vector3.new(45, 0.8, 0.8), Vector3.new(0, 15.4, z), darkWood)
    end
    -- Moonlit window and mullions behind the players.
    part("WindowFrame", Vector3.new(7.6, 8, 0.35), Vector3.new(-13.7, 9, -21.5), darkWood)
    local glass = part("MoonGlass", Vector3.new(6.7, 7.2, 0.15), Vector3.new(-13.7, 9, -21.2),
        Color3.fromRGB(61, 81, 116), Enum.Material.Neon)
    glass.Transparency = 0.4
    for x = -2, 2 do part("WindowMullion", Vector3.new(0.09, 7.1, 0.22), Vector3.new(-13.7 + x * 1.2, 9, -21), iron, Enum.Material.Metal) end
    for y = -2, 2 do part("WindowMullion", Vector3.new(6.6, 0.09, 0.22), Vector3.new(-13.7, 9 + y * 1.2, -21), iron, Enum.Material.Metal) end
    instance("PointLight", glass, { Color = Color3.fromRGB(107, 142, 213), Brightness = 1.2, Range = 30, Shadows = true })

    -- Six-seat table, real raised rim, inset cloth and separate wood boards.
    local pedestal = disk("TablePedestal", Vector3.new(0, 1.45, 0), 2.8, 2.8, darkWood)
    solid(pedestal)
    disk("CarvedTableFoot", Vector3.new(0, 0.22, 0), 5.5, 0.35, darkWood)
    local rim = disk("OakTableRim", Vector3.new(0, 2.94, 0), 14.8, 0.5, wood)
    solid(rim)
    disk("BrassInlay", Vector3.new(0, 3.202, 0), 14.28, 0.025, gold, Enum.Material.Metal)
    disk("WoodTop", Vector3.new(0, 3.225, 0), 14.09, 0.025, wood)
    for i = -6, 6 do
        local x = i * 1.0
        local length = 2 * math.sqrt(math.max(0, 6.95 * 6.95 - (math.abs(x) + 0.46) ^ 2))
        part("TableBoard", Vector3.new(0.97, 0.025, length), Vector3.new(x, 3.248, 0),
            wood:Lerp(Color3.fromRGB(103, 64, 36), (i + 6) % 4 * 0.13), Enum.Material.Wood)
    end
    disk("FeltBrassBorder", Vector3.new(0, 3.267, 0), 10.65, 0.025, gold, Enum.Material.Metal)
    disk("PlayingCloth", Vector3.new(0, 3.286, 0), 10.48, 0.025, felt, Enum.Material.Fabric)
    -- Small physical inlays frame the center without obscuring cards.
    for i = 1, 24 do
        local angle = i * math.pi / 12
        part("InlayRune", Vector3.new(0.06, 0.012, if i % 2 == 0 then 0.25 else 0.12),
            CFrame.new(math.sin(angle) * 4.9, 3.31, math.cos(angle) * 4.9) * CFrame.Angles(0, angle, 0), gold, Enum.Material.Metal)
    end
    for i = 1, 6 do
        local angle = (i - 1) * math.pi / 3
        local center = Vector3.new(math.sin(angle) * 9.2, 0, math.cos(angle) * 9.2)
        local facing = CFrame.lookAt(center, Vector3.new(0, 0, 0))
        local function chairPart(name, size, offset, color, material)
            return part(name, size, facing * CFrame.new(offset), color, material)
        end
        local seat = instance("Seat", room, { Name = "TableSeat_" .. i, Anchored = true,
            Size = Vector3.new(2.35, 0.45, 2.15), CFrame = facing * CFrame.new(0, 1.95, 0),
            Color = Color3.fromRGB(59, 35, 43), Material = Enum.Material.Fabric,
            CanCollide = true, CanTouch = true, CanQuery = true, Disabled = false })
        seat:SetAttribute("LabSeatIndex", i)
        seat:SetAttribute("ExitCFrame", facing * CFrame.new(0, 3, 3.5))
        instance("ProximityPrompt", seat, { Name = "TakeSeat", ActionText = "Platz nehmen",
            ObjectText = "Kartentisch · Platz " .. i, KeyboardKeyCode = Enum.KeyCode.E,
            GamepadKeyCode = Enum.KeyCode.ButtonX, HoldDuration = 0.2, MaxActivationDistance = 5,
            RequiresLineOfSight = false })
        solid(chairPart("ChairBack", Vector3.new(2.4, 3.2, 0.38), Vector3.new(0, 3.3, 0.92), darkWood))
        chairPart("BackUpholstery", Vector3.new(1.8, 2.45, 0.1), Vector3.new(0, 3.4, 0.69),
            Color3.fromRGB(59, 35, 43), Enum.Material.Fabric)
        for _, x in ipairs({ -0.9, 0.9 }) do
            for _, z in ipairs({ -0.8, 0.8 }) do chairPart("ChairLeg", Vector3.new(0.18, 1.8, 0.18), Vector3.new(x, 0.95, z), darkWood) end
        end
        -- Geometric figures provide seated eye/hand scale. They are not final characters.
        if i ~= 1 then
            local dummy = instance("Model", room, { Name = "SeatDummy_" .. i })
            local cloak = if i % 2 == 0 then Color3.fromRGB(41, 51, 54) else Color3.fromRGB(61, 40, 56)
            local torso = chairPart("ScaleDummyCloak", Vector3.new(1.4, 1.55, 0.8), Vector3.new(0, 3.05, -0.12), cloak, Enum.Material.Fabric)
            torso.Shape, torso.Parent = Enum.PartType.Ball, dummy
            local head = chairPart("ScaleDummyHead", Vector3.new(0.85, 1.0, 0.85), Vector3.new(0, 4.2, -0.16), cloak, Enum.Material.SmoothPlastic)
            head.Shape, head.Parent = Enum.PartType.Ball, dummy
            chairPart("ScaleDummyMask", Vector3.new(0.46, 0.65, 0.12), Vector3.new(0, 4.17, -0.58),
                Color3.fromRGB(139, 126, 102), Enum.Material.SmoothPlastic).Parent = dummy
            for _, x in ipairs({ -0.9, 0.9 }) do
                chairPart("ScaleDummyForearm", Vector3.new(0.4, 0.4, 1.6), Vector3.new(x, 3.12, -1), cloak, Enum.Material.Fabric).Parent = dummy
            end
        end
    end
    -- Candles sit at the edges; the central play area is deliberately clear.
    for _, position in ipairs({ Vector3.new(-5.5, 3.3, -1.2), Vector3.new(5.5, 3.3, -1.2), Vector3.new(0, 3.3, -6.0) }) do
        candle(position, 0.9)
    end
    -- Chandelier: a soft key light plus visible wax flames.
    beam("ChandelierChain", Vector3.new(0, 16, 0), Vector3.new(0, 10.5, 0), 0.07, iron, Enum.Material.Metal)
    disk("ChandelierRing", Vector3.new(0, 10.3, 0), 4.7, 0.13, iron, Enum.Material.Metal)
    for i = 1, 8 do
        local angle = i * math.pi / 4
        candle(Vector3.new(math.cos(angle) * 2.15, 10.4, math.sin(angle) * 2.15), 1.2)
    end
    local key = part("TableKeyLight", Vector3.new(0.1, 0.1, 0.1), Vector3.new(0, 9, 0), gold)
    key.Transparency = 1
    instance("PointLight", key, { Color = Color3.fromRGB(255, 215, 157), Brightness = 2.4, Range = 25, Shadows = true })

    -- Alchemy shelves and fireplace give depth beyond the table.
    for _, y in ipairs({ 3, 6.4, 9.8 }) do
        part("Shelf", Vector3.new(8.5, 0.25, 1.5), Vector3.new(13.5, y, -20.7), darkWood)
        for i = 1, 7 do
            local height = 0.65 + (i % 3) * 0.3
            local color = ({ Color3.fromRGB(46, 70, 62), Color3.fromRGB(82, 54, 74), Color3.fromRGB(110, 79, 40) })[i % 3 + 1]
            disk("AlchemyBottle", Vector3.new(9.8 + i, y + height / 2 + 0.15, -20.4), 0.43, height, color, Enum.Material.Glass)
            disk("BottleNeck", Vector3.new(9.8 + i, y + height + 0.29, -20.4), 0.17, 0.28, color, Enum.Material.Glass)
        end
    end
    part("FireplaceStone", Vector3.new(7, 6.7, 2), Vector3.new(0, 3.35, -21), stone, Enum.Material.Slate)
    part("FireplaceDark", Vector3.new(5.2, 4.5, 0.1), Vector3.new(0, 2.7, -19.95), Art.palette.ink)
    for i = -1, 1 do
        part("HearthFire", Vector3.new(0.8, 1.1 + (if i == 0 then 0.4 else 0), 0.65),
            Vector3.new(i * 0.9, 1.1, -19.7), Color3.fromRGB(215, 109, 46), Enum.Material.Neon, Enum.PartType.Ball)
    end
    local hearth = part("HearthLight", Vector3.new(0.1, 0.1, 0.1), Vector3.new(0, 2, -18.8), gold)
    hearth.Transparency = 1
    instance("PointLight", hearth, { Color = Color3.fromRGB(255, 147, 62), Brightness = 1.6, Range = 18, Shadows = false })
    part("InspectionDesk", Vector3.new(4.7, 0.3, 3.4), Vector3.new(13.7, 3.2, 4), darkWood)
    for _, x in ipairs({ 11.7, 15.7 }) do part("DeskLeg", Vector3.new(0.3, 3.1, 2.8), Vector3.new(x, 1.55, 4), darkWood) end
    candle(Vector3.new(15.5, 3.4, 3.3), 1.0)
    local sampleLight = part("InspectionLight", Vector3.new(0.1, 0.1, 0.1), Vector3.new(13.7, 7.1, 7), gold)
    sampleLight.Transparency = 1
    instance("PointLight", sampleLight, { Color = Color3.fromRGB(255, 235, 209), Brightness = 1.5, Range = 10, Shadows = false })
    return room
end

return Tavern
