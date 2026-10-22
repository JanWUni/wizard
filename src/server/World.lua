local World = {}

function World.build()
    local Lighting = game:GetService("Lighting")
    Lighting.ClockTime = 0
    Lighting.Brightness = 1.5
    Lighting.Ambient = Color3.fromRGB(60, 49, 87)
    Lighting.OutdoorAmbient = Color3.fromRGB(24, 28, 50)
    Lighting.FogColor = Color3.fromRGB(14, 15, 30)
    Lighting.FogStart, Lighting.FogEnd = 40, 140
    local bloom = Instance.new("BloomEffect")
    bloom.Intensity, bloom.Size, bloom.Threshold = 0.4, 32, 1.2
    bloom.Parent = Lighting
    local model = Instance.new("Model")
    model.Name, model.Parent = "ArcaneHall", workspace

    local function part(name, size, position, color, material, shape)
        local object = Instance.new("Part")
        object.Name, object.Size, object.Position = name, size, position
        object.Color, object.Material = color, material or Enum.Material.Slate
        object.Anchored, object.CanCollide = true, false
        if shape then object.Shape = shape end
        object.Parent = model
        return object
    end
    local stone = Color3.fromRGB(32, 31, 48)
    local gold = Color3.fromRGB(170, 129, 67)
    part("Floor", Vector3.new(150, 1, 150), Vector3.new(0, -1, 0), stone)
    local tableBase = part("TableRim", Vector3.new(1, 26, 26), Vector3.new(0, 4, 0), gold, Enum.Material.Metal, Enum.PartType.Cylinder)
    tableBase.CFrame = CFrame.new(0, 4, 0) * CFrame.Angles(0, 0, math.pi / 2)
    local felt = part("Velvet", Vector3.new(0.25, 24.5, 24.5), Vector3.new(0, 4.7, 0), Color3.fromRGB(24, 58, 59), Enum.Material.Fabric, Enum.PartType.Cylinder)
    felt.CFrame = CFrame.new(0, 4.7, 0) * CFrame.Angles(0, 0, math.pi / 2)
    for i = 1, 12 do
        local angle = i * math.pi / 6
        local x, z = math.cos(angle) * 27, math.sin(angle) * 27
        part("Pillar", Vector3.new(3, 23, 3), Vector3.new(x, 10, z), stone, Enum.Material.Marble)
        part("Capital", Vector3.new(4.2, 0.8, 4.2), Vector3.new(x, 21.5, z), gold, Enum.Material.Metal)
        local orb = part("ArcaneLight", Vector3.new(1.7, 1.7, 1.7), Vector3.new(x * 0.8, 9, z * 0.8),
            Color3.fromRGB(148, 115, 255), Enum.Material.Neon, Enum.PartType.Ball)
        local light = Instance.new("PointLight")
        light.Color, light.Brightness, light.Range = orb.Color, 2, 20
        light.Parent = orb
    end
    for i = 1, 6 do
        local angle = (i - 1) * math.pi / 3
        local position = Vector3.new(math.cos(angle) * 16, 3, math.sin(angle) * 16)
        part("Chair", Vector3.new(4, 1, 4), position, Color3.fromRGB(69, 42, 84), Enum.Material.Fabric)
    end
end

return World
