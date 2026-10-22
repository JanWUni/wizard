-- Run from the repository root: lune run tools/build_lab.luau
-- Uses real Roblox instance/property data, but is NOT a renderer or game engine.
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local luau = require("@lune/luau")
local game = roblox.Instance.new("DataModel")
local workspace = game:GetService("Workspace")
local modules = {}
local function loadModule(name)
    if modules[name] then return modules[name] end
    local environment = {
        game = game, workspace = workspace,
        script = { Parent = { ArtDirection = "ArtDirection" } },
        require = loadModule,
    }
    for _, key in ipairs({ "Instance", "Vector3", "Vector2", "CFrame", "Color3", "ColorSequence", "UDim", "UDim2", "Enum", "Font" }) do
        environment[key] = roblox[key]
    end
    local source = fs.readFile("src/assets/" .. name .. ".lua")
    modules[name] = luau.load(source, { debugName = name, environment = environment })()
    return modules[name]
end
local Art, Card, Tavern = loadModule("ArtDirection"), loadModule("CardModel"), loadModule("Tavern")
local Layout = loadModule("TableLayout")
local room = Tavern.build(workspace)
local gallery = roblox.Instance.new("Folder")
gallery.Name, gallery.Parent = "EditorCardGallery", room
local samples, parts, surfaces = {}, 0, 0
for i, data in ipairs(Art.samples) do
    local transform = roblox.CFrame.new((i - 3.5) * 1.4, Tavern.tableTop + 0.04, 0)
        * roblox.CFrame.Angles(math.pi / 2, 0, 0)
    local model = Card.create(gallery, data, transform)
    assert(model.PrimaryPart.Size.Z > 0, "A card needs physical thickness")
    assert(model.PrimaryPart.CFrame.LookVector.Y > 0.99, "Card front must face up on table")
    assert(model.PrimaryPart.CFrame.Position.Y > 3.31, "Card must be above the cloth")
    assert(model:FindFirstChild("Front", true) and model:FindFirstChild("Back", true))
    assert(model:FindFirstChild("Artwork", true), "Artwork slot is missing")
    Card.setReadable(model, false)
    assert(model:FindFirstChild("Front", true).LightInfluence > 0.6)
    Card.setReadable(model, true)
    Card.setArtwork(model, "rbxassetid://123456789", false)
    assert(model:FindFirstChild("Artwork", true).Visible)
    Card.setArtwork(model, "", false)
    assert(not model:FindFirstChild("Artwork", true).Visible)
    assert(model.PrimaryPart.CanCollide == false and model.PrimaryPart.CanQuery)
    table.insert(samples, model)
end
for _, object in ipairs(room:GetDescendants()) do
    if object:IsA("BasePart") then
        parts += 1
        assert(object.Anchored, "Lab props must be anchored")
        assert(object.Size.X > 0 and object.Size.Y > 0 and object.Size.Z > 0)
    elseif object:IsA("SurfaceGui") then
        surfaces += 1
        assert(not object.AlwaysOnTop, "Cards must occlude naturally in 3D")
    end
end
assert(parts < 600, "Room geometry budget exceeded")
assert(surfaces == 12, "Six samples need twelve distinct physical faces")
local camera, fov = Layout.camera("table", Tavern.eye, Tavern.focus, Tavern.inspection, 0, 0)
for _, count in ipairs({ 6, 10, 20 }) do
    for _, aspect in ipairs({ 1.4, 1.6, 16 / 9 }) do
        for i = 1, count do
            local transform = Layout.hand(camera, i, count, 1, false, false, aspect)
            assert(transform.LookVector:Dot((camera.Position - transform.Position).Unit) > 0.7, "Face must point toward the player")
            -- Outer corners must fit the horizontal field of view at supported desktop ratios.
            for _, x in ipairs({ -Art.card.width / 2, Art.card.width / 2 }) do
                for _, y in ipairs({ -Art.card.height / 2, Art.card.height / 2 }) do
                    local point = camera:PointToObjectSpace(transform:PointToWorldSpace(roblox.Vector3.new(x, y, 0)))
                    local ndcX = point.X / (-point.Z * math.tan(math.rad(fov / 2)) * aspect)
                    assert(math.abs(ndcX) < 1, "Hand leaves the screen")
                end
            end
        end
    end
end
assert(Layout.flat(roblox.Vector3.zero, 0, false).LookVector.Y > 0.99)
assert(Layout.flat(roblox.Vector3.zero, 0, true).LookVector.Y < -0.99)
for _, preset in ipairs({ "neutral", "moon", "tavern" }) do Tavern.lighting(preset) end
fs.writeDir("lab/models")
fs.writeFile("lab/models/TavernStudy.rbxm", roblox.serializeModel({ room }))
fs.writeFile("lab/models/CardSamples.rbxm", roblox.serializeModel(samples))
local roundtrip = roblox.deserializeModel(fs.readFile("lab/models/CardSamples.rbxm"))
assert(#roundtrip == 6)
for _, model in ipairs(roundtrip) do
    assert(model.PrimaryPart and model:FindFirstChild("Front", true) and model:FindFirstChild("Back", true))
end
print(string.format("Lab assets verified and baked: %d anchored parts, six cards, twelve surfaces; property and serialization checks passed.", parts))
