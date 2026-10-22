-- Visual experiments live here until the lab has been reviewed in Studio.
local Art = {}
Art.palette = {
    ink = Color3.fromRGB(19, 20, 27), paper = Color3.fromRGB(225, 211, 178),
    paperLight = Color3.fromRGB(248, 239, 210), gold = Color3.fromRGB(188, 145, 75),
    goldLight = Color3.fromRGB(237, 205, 134), muted = Color3.fromRGB(173, 161, 143),
    wood = Color3.fromRGB(73, 45, 29), felt = Color3.fromRGB(26, 52, 48),
    red = Color3.fromRGB(158, 53, 49), yellow = Color3.fromRGB(161, 118, 36),
    green = Color3.fromRGB(43, 102, 77), blue = Color3.fromRGB(43, 77, 119),
    wizard = Color3.fromRGB(80, 54, 112), jester = Color3.fromRGB(96, 54, 68),
}
Art.suits = { "red", "yellow", "green", "blue", "wizard", "jester" }
Art.names = { red = "GLUT", yellow = "LICHT", green = "WALD", blue = "GEZEITEN", wizard = "DER MAGIER", jester = "DER NARR" }
Art.symbols = { red = "◆", yellow = "☀", green = "♣", blue = "≋", wizard = "W", jester = "N" }
Art.card = { width = 1.06, height = 1.58, thickness = 0.025, pixels = Vector2.new(424, 632) }
-- Upload original artwork through Roblox's Asset Manager, then enter its image ID.
-- Empty slots deliberately render the editable emblem study instead.
Art.images = { red = "", yellow = "", green = "", blue = "", wizard = "", jester = "", back = "" }
Art.samples = {
    { kind = "number", suit = "red", rank = 13, id = "red13" },
    { kind = "number", suit = "yellow", rank = 7, id = "yellow7" },
    { kind = "number", suit = "green", rank = 3, id = "green3" },
    { kind = "number", suit = "blue", rank = 11, id = "blue11" },
    { kind = "wizard", rank = 0, id = "wizard1" },
    { kind = "jester", rank = 0, id = "jester1" },
}
return Art
