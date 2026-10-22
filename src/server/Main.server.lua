local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Engine = require(script.Parent.Engine)
local World = require(script.Parent.World)
World.build()
Players.CharacterAutoLoads = false

local remotes = Instance.new("Folder")
remotes.Name, remotes.Parent = "WizardRemotes", ReplicatedStorage
local action = Instance.new("RemoteEvent")
action.Name, action.Parent = "Action", remotes
local state = Instance.new("RemoteEvent")
state.Name, state.Parent = "State", remotes

local match, hostId, deadline
local order, buckets = {}, {}
local epoch = 0
local random = Random.new()
local TURN_SECONDS = 45

local function host()
    if hostId and Players:GetPlayerByUserId(hostId) then return hostId end
    hostId = nil
    -- Give control to a participant before considering spectators.
    if match then
        for _, seat in ipairs(match.seats) do
            if not seat.bot and Players:GetPlayerByUserId(seat.id) then hostId = seat.id; return hostId end
        end
    end
    for _, id in ipairs(order) do
        if Players:GetPlayerByUserId(id) then hostId = id; break end
    end
    return hostId
end

local function send(player)
    local view
    if match then view = match:view(player.UserId)
    else
        view = { phase = "lobby", seats = {}, revision = 0 }
        for _, id in ipairs(order) do
            local member = Players:GetPlayerByUserId(id)
            if member then table.insert(view.seats, { id = id, name = member.DisplayName }) end
        end
    end
    view.hostId, view.deadline, view.epoch = host(), deadline, epoch
    state:FireClient(player, view)
end

local function publish()
    for _, player in ipairs(Players:GetPlayers()) do send(player) end
end

local function schedule()
    if not match or match.phase == "finished" then deadline = nil; return end
    local duration
    if match.phase == "trickComplete" then duration = 2.5
    elseif match.phase == "roundComplete" then duration = 8
    elseif match.seats[match.turn].bot then duration = 1.2
    else duration = TURN_SECONDS end
    deadline = workspace:GetServerTimeNow() + duration
end

local function start(player, mode)
    if match then return end
    local seats = {}
    if mode == "practice" then
        -- Practice can be started by anyone and only seats the requester.
        table.insert(seats, { id = player.UserId, name = player.DisplayName })
        table.insert(seats, { id = -1, name = "Mira", bot = true })
        table.insert(seats, { id = -2, name = "Orion", bot = true })
    elseif mode == "friends" then
        if player.UserId ~= host() then return end
        for _, id in ipairs(order) do
            local member = Players:GetPlayerByUserId(id)
            if member and #seats < 6 then table.insert(seats, { id = id, name = member.DisplayName }) end
        end
        if #seats < 3 then
            state:FireClient(player, { error = "Für eine Mehrspielerpartie braucht ihr mindestens 3 Spieler." })
            return
        end
    else return end
    match = Engine.new(seats, function(a, b) return random:NextInteger(a, b) end)
    hostId, epoch = player.UserId, epoch + 1
    schedule()
    publish()
end

-- A token bucket limits all remote requests, including initial state requests.
local function allowed(player)
    local now = os.clock()
    local bucket = buckets[player.UserId] or { tokens = 12, time = now }
    bucket.tokens = math.min(12, bucket.tokens + (now - bucket.time) * 4)
    bucket.time = now
    buckets[player.UserId] = bucket
    if bucket.tokens < 1 then return false end
    bucket.tokens -= 1
    return true
end

action.OnServerEvent:Connect(function(player, verb, value, revision, clientEpoch)
    if not allowed(player) or type(verb) ~= "string" or #verb > 16 then return end
    if verb == "sync" then send(player); return end
    if verb == "start" then start(player, value); return end
    if verb == "lobby" then
        if match and match.phase == "finished" and player.UserId == host() then
            match, deadline = nil, nil
            epoch += 1
            publish()
        end
        return
    end
    if not match then return end
    if revision ~= match.revision or clientEpoch ~= epoch then send(player); return end
    local seatIndex = match:seatFor(player.UserId)
    if not seatIndex or match.seats[seatIndex].bot then return end
    local ok, message = match:act(seatIndex, verb, value)
    if ok then schedule(); publish()
    else state:FireClient(player, { error = message }) end
end)

local function joined(player)
    if not table.find(order, player.UserId) then table.insert(order, player.UserId) end
    publish()
end
Players.PlayerAdded:Connect(joined)
for _, player in ipairs(Players:GetPlayers()) do joined(player) end

Players.PlayerRemoving:Connect(function(player)
    local index = table.find(order, player.UserId)
    if index then table.remove(order, index) end
    buckets[player.UserId] = nil
    if hostId == player.UserId then hostId = nil end
    if match then
        local seatIndex = match:seatFor(player.UserId)
        if seatIndex then
            match.seats[seatIndex].bot = true
            match.seats[seatIndex].name ..= " (Bot)"
            match.revision += 1
            if match.turn == seatIndex then schedule() end
        end
        local humans = 0
        for _, seat in ipairs(match.seats) do if not seat.bot then humans += 1 end end
        if humans == 0 then match, deadline = nil, nil; epoch += 1 end
    end
    publish()
end)

task.spawn(function()
    while true do
        task.wait(0.2)
        if match and deadline and workspace:GetServerTimeNow() >= deadline then
            if match.phase == "trickComplete" or match.phase == "roundComplete" then match:advance()
            elseif match.turn then
                local verb, value = match:autoAction()
                match:act(match.turn, verb, value)
            end
            schedule()
            publish()
        end
    end
end)
