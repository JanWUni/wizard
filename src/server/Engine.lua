local Rules = if script then require(game:GetService("ReplicatedStorage").Shared.Rules)
    else require("../shared/Rules")
local Engine = {}
Engine.__index = Engine

function Engine.new(seats, randomInteger)
    assert(#seats >= 3 and #seats <= 6, "Wizard needs 3–6 seats")
    local self = setmetatable({}, Engine)
    self.seats, self.randomInteger = {}, randomInteger
    self.round, self.dealer, self.revision = 0, #seats, 0
    self.maxRounds, self.history = math.floor(60 / #seats), {}
    for _, seat in ipairs(seats) do
        table.insert(self.seats, { id = seat.id, name = seat.name, bot = seat.bot == true,
            score = 0, taken = 0, hand = {} })
    end
    self:nextRound()
    return self
end

function Engine:nextSeat(seat) return seat % #self.seats + 1 end

function Engine:nextRound()
    assert(self.round == 0 or self.phase == "roundComplete", "Round is not complete")
    self.round += 1
    self.dealer = self:nextSeat(self.dealer)
    self.leader = self:nextSeat(self.dealer)
    self.turn, self.trick, self.trickNumber, self.lastWinner = self.leader, {}, 1, nil
    self.trump, self.turnedCard = nil, nil
    local deck = Rules.shuffle(Rules.deck(), self.randomInteger)
    local cursor = 1
    for _, seat in ipairs(self.seats) do seat.hand, seat.bid, seat.taken, seat.delta = {}, nil, 0, nil end
    for _ = 1, self.round do
        for offset = 1, #self.seats do
            local seat = self.seats[(self.dealer + offset - 1) % #self.seats + 1]
            table.insert(seat.hand, deck[cursor])
            cursor += 1
        end
    end
    self.turnedCard = deck[cursor]
    if self.turnedCard and self.turnedCard.kind == "wizard" then
        self.phase, self.turn = "chooseTrump", self.dealer
    else
        if self.turnedCard and self.turnedCard.kind == "number" then self.trump = self.turnedCard.suit end
        self.phase = "bidding"
    end
    self.revision += 1
end

function Engine:act(seatIndex, action, value)
    if seatIndex ~= self.turn then return false, "Du bist noch nicht am Zug." end
    local seat = self.seats[seatIndex]
    if self.phase == "chooseTrump" and action == "trump" then
        if type(value) ~= "string" or not table.find(Rules.suits, value) then
            return false, "Wähle eine der vier Farben."
        end
        self.trump, self.phase, self.turn = value, "bidding", self.leader
    elseif self.phase == "bidding" and action == "bid" then
        if not Rules.integer(value, 0, self.round) then return false, "Ungültige Stichansage." end
        seat.bid = value
        self.turn = self:nextSeat(self.turn)
        if self.turn == self.leader then self.phase = "playing" end
    elseif self.phase == "playing" and action == "play" then
        if type(value) ~= "string" or #value > 24 then return false, "Ungültige Karte." end
        local index
        for i, card in ipairs(seat.hand) do if card.id == value then index = i; break end end
        if not index then return false, "Diese Karte hast du nicht auf der Hand." end
        if not Rules.canPlay(seat.hand, seat.hand[index], self.trick) then
            return false, "Du musst die angespielte Farbe bedienen."
        end
        table.insert(self.trick, { seat = seatIndex, card = table.remove(seat.hand, index) })
        self.turn = self:nextSeat(self.turn)
        if #self.trick == #self.seats then
            self.lastWinner = Rules.winner(self.trick, self.trump)
            self.seats[self.lastWinner].taken += 1
            self.phase, self.turn = "trickComplete", nil
        end
    else
        return false, "Diese Aktion ist gerade nicht möglich."
    end
    self.revision += 1
    return true
end

function Engine:advance()
    if self.phase == "trickComplete" then
        if self.trickNumber == self.round then
            local results = {}
            for i, seat in ipairs(self.seats) do
                seat.delta = Rules.score(seat.bid, seat.taken)
                seat.score += seat.delta
                results[i] = { bid = seat.bid, taken = seat.taken, delta = seat.delta, score = seat.score }
            end
            table.insert(self.history, results)
            self.phase = if self.round == self.maxRounds then "finished" else "roundComplete"
        else
            self.trickNumber += 1
            self.trick, self.turn, self.phase = {}, self.lastWinner, "playing"
        end
        self.revision += 1
    elseif self.phase == "roundComplete" then self:nextRound()
    else return false end
    return true
end

function Engine:seatFor(id)
    for i, seat in ipairs(self.seats) do if seat.id == id then return i end end
    return nil
end

function Engine:view(id)
    local mine = self:seatFor(id)
    local view = { phase = self.phase, round = self.round, maxRounds = self.maxRounds,
        dealer = self.dealer, turn = self.turn, trump = self.trump, turnedCard = self.turnedCard,
        trickNumber = self.trickNumber, lastWinner = self.lastWinner, revision = self.revision,
        seats = {}, trick = {}, hand = {}, legal = {}, history = {}, mySeat = mine }
    for i, seat in ipairs(self.seats) do
        view.seats[i] = { id = seat.id, name = seat.name, bot = seat.bot, score = seat.score,
            bid = seat.bid, taken = seat.taken, count = #seat.hand, delta = seat.delta }
    end
    for i, play in ipairs(self.trick) do
        view.trick[i] = { seat = play.seat, card = table.clone(play.card) }
    end
    if self.turnedCard then view.turnedCard = table.clone(self.turnedCard) end
    if mine then
        for _, card in ipairs(self.seats[mine].hand) do
            table.insert(view.hand, table.clone(card))
            if self.phase == "playing" and self.turn == mine
                and Rules.canPlay(self.seats[mine].hand, card, self.trick) then view.legal[card.id] = true end
        end
    end
    for r, row in ipairs(self.history) do
        view.history[r] = {}
        for i, result in ipairs(row) do view.history[r][i] = table.clone(result) end
    end
    return view
end

-- Simple practice opponent: uses its own hand and public trick only.
function Engine:autoAction()
    local seat = self.seats[self.turn]
    if self.phase == "chooseTrump" then
        local best, weight = Rules.suits[1], -1
        for _, suit in ipairs(Rules.suits) do
            local total = 0
            for _, card in ipairs(seat.hand) do if card.suit == suit then total += card.rank end end
            if total > weight then best, weight = suit, total end
        end
        return "trump", best
    elseif self.phase == "bidding" then
        local estimate = 0
        for _, card in ipairs(seat.hand) do
            if card.kind == "wizard" then estimate += 1
            elseif card.kind == "number" then
                if card.suit == self.trump then estimate += 0.55 + card.rank / 40
                elseif card.rank >= 11 then estimate += 0.35 end
            end
        end
        return "bid", math.clamp(math.floor(estimate + 0.25), 0, self.round)
    elseif self.phase == "playing" then
        local choices = {}
        for _, card in ipairs(seat.hand) do
            if Rules.canPlay(seat.hand, card, self.trick) then table.insert(choices, card) end
        end
        local function strength(card)
            if card.kind == "wizard" then return 100 end
            if card.kind == "jester" then return 0 end
            return card.rank + (if card.suit == self.trump then 20 else 0)
        end
        table.sort(choices, function(a, b) return strength(a) < strength(b) end)
        if seat.taken < seat.bid then
            for _, card in ipairs(choices) do
                local trial = table.clone(self.trick)
                table.insert(trial, { seat = self.turn, card = card })
                if Rules.winner(trial, self.trump) == self.turn then return "play", card.id end
            end
        end
        return "play", choices[1].id
    end
    error("No automatic action available in " .. self.phase)
end

return Engine
