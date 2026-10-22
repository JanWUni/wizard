local Rules = require("../src/shared/Rules")
local Engine = require("../src/server/Engine")
local count = 0
local function test(name, callback)
    callback()
    count += 1
    print("PASS " .. name)
end
local function equal(actual, expected)
    assert(actual == expected, string.format("expected %s, got %s", tostring(expected), tostring(actual)))
end
local function n(suit, rank) return { kind = "number", suit = suit, rank = rank, id = suit .. rank } end
local function w(id) return { kind = "wizard", id = id or "wizard1", rank = 0 } end
local function j(id) return { kind = "jester", id = id or "jester1", rank = 0 } end
local function trick(cards)
    local plays = {}
    for i, card in ipairs(cards) do plays[i] = { seat = i, card = card } end
    return plays
end
local function seats(size)
    local result = {}
    for i = 1, size do result[i] = { id = i, name = "Player " .. i, bot = true } end
    return result
end
local function rng(seed)
    local value = seed
    return function(a, b)
        value = (value * 48271) % 2147483647
        return a + value % (b - a + 1)
    end
end

test("60 unique cards: four suits, four Wizards, four jesters", function()
    local deck, ids, kinds = Rules.deck(), {}, { number = 0, wizard = 0, jester = 0 }
    equal(#deck, 60)
    for _, card in ipairs(deck) do
        assert(not ids[card.id]); ids[card.id] = true
        kinds[card.kind] += 1
    end
    equal(kinds.number, 52); equal(kinds.wizard, 4); equal(kinds.jester, 4)
end)

test("highest lead card wins; off-suit cannot win", function()
    equal(Rules.winner(trick({ n("red", 4), n("blue", 13), n("red", 7) }), nil), 3)
end)
test("trump beats lead; highest trump wins", function()
    equal(Rules.winner(trick({ n("red", 13), n("blue", 1), n("blue", 2) }), "blue"), 3)
end)
test("first Wizard wins, including against trump", function()
    equal(Rules.winner(trick({ n("blue", 13), w(), w("wizard2") }), "blue"), 2)
end)
test("only jesters: first jester wins", function()
    equal(Rules.winner(trick({ j(), j("jester2"), j("jester3") }), "red"), 1)
end)
test("leading jester defers the lead suit", function()
    equal(Rules.leadSuit(trick({ j(), n("green", 1) })), "green")
    equal(Rules.winner(trick({ j(), n("green", 1), n("blue", 13) }), nil), 2)
end)
test("leading Wizard frees all subsequent players", function()
    equal(Rules.leadSuit(trick({ w(), n("green", 1) })), nil)
    equal(Rules.canPlay({ n("green", 5) }, n("red", 3), trick({ w(), n("green", 1) })), true)
end)
test("jester followed by Wizard frees all subsequent players", function()
    equal(Rules.leadSuit(trick({ j(), w(), n("green", 1) })), nil)
end)
test("Wizard after number does not remove established suit", function()
    local plays = trick({ n("red", 1), w() })
    equal(Rules.leadSuit(plays), "red")
    equal(Rules.canPlay({ n("red", 2), n("blue", 3) }, n("blue", 3), plays), false)
end)
test("follow suit, special exceptions, and void suit", function()
    local plays = trick({ n("red", 1) })
    local hand = { n("red", 2), n("blue", 3), w(), j() }
    equal(Rules.canPlay(hand, hand[1], plays), true)
    equal(Rules.canPlay(hand, hand[2], plays), false)
    equal(Rules.canPlay(hand, hand[3], plays), true)
    equal(Rules.canPlay(hand, hand[4], plays), true)
    equal(Rules.canPlay({ hand[2] }, hand[2], plays), true)
end)
test("scoring exact zero, exact nonzero, overbid and underbid", function()
    equal(Rules.score(0, 0), 20); equal(Rules.score(3, 3), 50)
    equal(Rules.score(3, 1), -20); equal(Rules.score(1, 3), -20)
end)
test("integer guard rejects NaN, infinity, fractional and typed payloads", function()
    for _, value in ipairs({ 0/0, math.huge, -math.huge, 1.5, "1", {}, -1, 21 }) do
        equal(Rules.integer(value, 0, 20), false)
    end
    equal(Rules.integer(0, 0, 20), true); equal(Rules.integer(20, 0, 20), true)
end)
test("shuffle is reproducible and preserves the deck", function()
    local a, b, seen = Rules.shuffle(Rules.deck(), rng(91)), Rules.shuffle(Rules.deck(), rng(91)), {}
    for i, card in ipairs(a) do equal(card.id, b[i].id); assert(not seen[card.id]); seen[card.id] = true end
end)
test("Wizard turned up: dealer chooses; jester and final round: no trump", function()
    -- Identity shuffle leaves the first turned card at a predictable position.
    local game = Engine.new(seats(3), function(_, b) return b end)
    while game.round < 18 do
        game.phase = "roundComplete"; game:nextRound()
    end
    -- 3*18 cards consumed -> card 55 is Wizard 2.
    equal(game.turnedCard.kind, "wizard"); equal(game.phase, "chooseTrump"); equal(game.turn, game.dealer)
    equal(game:act(game.turn, "trump", "purple"), false)
    equal(game:act(game.turn, "trump", "green"), true); equal(game.trump, "green")
    equal(game.turn, game.leader)
    game.phase = "roundComplete"; game:nextRound()
    equal(game.turnedCard.kind, "jester"); equal(game.trump, nil)
    game.phase = "roundComplete"; game:nextRound()
    equal(game.turnedCard, nil); equal(game.trump, nil)
end)
test("invalid actions leave revision and hand unchanged", function()
    local game = Engine.new(seats(3), rng(7))
    while game.phase == "chooseTrump" do game:act(game.turn, "trump", "blue") end
    local rev = game.revision
    equal(game:act(game:nextSeat(game.turn), "bid", 0), false)
    for _, bid in ipairs({ -1, 2, math.huge, 0/0, 0.5, "0", {} }) do
        equal(game:act(game.turn, "bid", bid), false)
    end
    equal(game.revision, rev)
    for _ = 1, 3 do equal(game:act(game.turn, "bid", 0), true) end
    equal(game.phase, "playing") -- total bid may equal trick count in the base rules.
    rev = game.revision
    local handSize = #game.seats[game.turn].hand
    equal(game:act(game.turn, "play", "forged"), false)
    equal(game:act(game.turn, "play", {}), false)
    equal(game:act(game.turn, "bid", 0), false)
    equal(game.revision, rev); equal(#game.seats[game.turn].hand, handSize)
end)
test("sum of bids may equal the number of tricks", function()
    local game = Engine.new(seats(3), rng(19))
    if game.phase == "chooseTrump" then game:act(game.turn, "trump", "blue") end
    equal(game:act(game.turn, "bid", 1), true)
    equal(game:act(game.turn, "bid", 0), true)
    equal(game:act(game.turn, "bid", 0), true)
    equal(game.phase, "playing")
end)
test("server rejects failing to follow suit", function()
    local game = Engine.new(seats(3), rng(1))
    game.phase, game.turn, game.trick = "playing", 2, trick({ n("red", 1) })
    game.seats[2].hand = { n("blue", 13), n("red", 2) }
    equal(game:act(2, "play", "blue13"), false)
    equal(#game.seats[2].hand, 2)
    equal(game:act(2, "play", "red2"), true)
end)
test("view never exposes another player's hand, and copies are isolated", function()
    local game = Engine.new(seats(3), rng(8))
    local view = game:view(1)
    equal(#view.hand, 1); equal(view.seats[2].hand, nil); equal(view.randomInteger, nil)
    equal(#game:view(999).hand, 0); equal(game:view(999).mySeat, nil)
    view.hand[1].id = "mutated"
    assert(game.seats[1].hand[1].id ~= "mutated")
    if view.turnedCard then view.turnedCard.id = "mutated"; assert(game.turnedCard.id ~= "mutated") end
end)

local games, actions, rounds = 0, 0, 0
for size = 3, 6 do
    test("20 complete " .. size .. "-player matches: transitions, scoring, privacy and conservation", function()
        for seed = 1, 20 do
            local game = Engine.new(seats(size), rng(seed * 101 + size))
            local roundSeen, playsInRound = 0, {}
            local roundActions = 0
            while game.phase ~= "finished" do
                if roundSeen ~= game.round then
                    roundSeen, playsInRound, roundActions = game.round, {}, 0
                    rounds += 1
                    equal(game.dealer, (game.round - 1) % size + 1)
                    local seen = {}
                    for _, seat in ipairs(game.seats) do
                        equal(#seat.hand, game.round)
                        for _, card in ipairs(seat.hand) do assert(not seen[card.id]); seen[card.id] = true end
                    end
                    if game.turnedCard then assert(not seen[game.turnedCard.id]) end
                end
                local beforeRevision = game.revision
                if game.phase == "trickComplete" or game.phase == "roundComplete" then
                    if game.phase == "trickComplete" then
                        local taken = 0
                        for _, seat in ipairs(game.seats) do taken += seat.taken end
                        equal(taken, game.trickNumber)
                        equal(#game.trick, size)
                    end
                    equal(game:advance(), true)
                else
                    local turn, phase = game.turn, game.phase
                    local verb, value = game:autoAction()
                    if phase == "playing" then
                        assert(not playsInRound[value]); playsInRound[value] = true
                        roundActions += 1
                        local view = game:view(game.seats[turn].id)
                        equal(view.legal[value], true)
                        for _, public in ipairs(view.seats) do equal(public.hand, nil) end
                    end
                    local ok, message = game:act(turn, verb, value)
                    assert(ok, message)
                    actions += 1
                    if game.phase == "trickComplete" and game.trickNumber == game.round then
                        equal(roundActions, size * game.round)
                        for _, seat in ipairs(game.seats) do equal(#seat.hand, 0) end
                    end
                end
                assert(game.revision > beforeRevision)
                assert(actions < 200000, "Infinite loop")
            end
            equal(game.round, math.floor(60 / size))
            equal(#game.history, game.maxRounds)
            for i, seat in ipairs(game.seats) do
                local score = 0
                for _, row in ipairs(game.history) do
                    equal(row[i].delta, Rules.score(row[i].bid, row[i].taken))
                    score += row[i].delta; equal(row[i].score, score)
                end
                equal(seat.score, score)
            end
            equal(game.trump, nil)
            games += 1
        end
    end)
end
print(string.format("\n%d tests passed · %d complete matches · %d rounds · %d actions", count, games, rounds, actions))
