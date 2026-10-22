-- Pure rules, usable both by Roblox and the standalone Luau test runner.
local Rules = {}
Rules.suits = { "red", "yellow", "green", "blue" }
Rules.suitNames = { red = "Rot", yellow = "Gelb", green = "Grün", blue = "Blau" }

function Rules.deck()
    local deck = {}
    for _, suit in ipairs(Rules.suits) do
        for rank = 1, 13 do
            table.insert(deck, { id = suit .. rank, kind = "number", suit = suit, rank = rank })
        end
    end
    for i = 1, 4 do
        table.insert(deck, { id = "wizard" .. i, kind = "wizard", rank = 0 })
        table.insert(deck, { id = "jester" .. i, kind = "jester", rank = 0 })
    end
    return deck
end

function Rules.shuffle(deck, randomInteger)
    for i = #deck, 2, -1 do
        local j = randomInteger(1, i)
        deck[i], deck[j] = deck[j], deck[i]
    end
    return deck
end

-- The first non-jester decides whether a suit must be followed.
-- A Wizard after an established suit does NOT remove the obligation.
function Rules.leadSuit(trick)
    for _, play in ipairs(trick) do
        if play.card.kind == "wizard" then return nil end
        if play.card.kind == "number" then return play.card.suit end
    end
    return nil
end

function Rules.canPlay(hand, card, trick)
    if card.kind ~= "number" then return true end
    local lead = Rules.leadSuit(trick)
    if not lead or card.suit == lead then return true end
    for _, held in ipairs(hand) do
        if held.kind == "number" and held.suit == lead then return false end
    end
    return true
end

function Rules.winner(trick, trump)
    assert(#trick > 0, "Cannot resolve an empty trick")
    for _, play in ipairs(trick) do
        if play.card.kind == "wizard" then return play.seat end
    end
    local lead = Rules.leadSuit(trick)
    local best, strength = trick[1].seat, -1
    for _, play in ipairs(trick) do
        local card = play.card
        local value = 0
        if card.kind == "number" then
            if card.suit == trump then value = 100 + card.rank
            elseif card.suit == lead then value = card.rank end
        end
        if value > strength then best, strength = play.seat, value end
    end
    return best
end

function Rules.score(bid, taken)
    if bid == taken then return 20 + 10 * taken end
    return -10 * math.abs(bid - taken)
end

function Rules.integer(value, minimum, maximum)
    return type(value) == "number" and value == value
        and value >= minimum and value <= maximum and value % 1 == 0
end

return Rules
