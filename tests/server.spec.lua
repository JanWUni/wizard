-- The check runner inserts the actual server source at the marker below.
-- These are transport/lifecycle mocks, not a Roblox engine or rendering test.
local function signal()
    local callbacks = {}
    return {
        Connect = function(_, callback) table.insert(callbacks, callback) end,
        fire = function(_, ...)
            for _, callback in ipairs(callbacks) do callback(...) end
        end,
    }
end
local clock, seed, instances, messages, online = 100, 1, {}, {}, {}
local loop
local Players = { PlayerAdded = signal(), PlayerRemoving = signal() }
function Players:GetPlayers() return table.clone(online) end
function Players:GetPlayerByUserId(id)
    for _, player in ipairs(online) do if player.UserId == id then return player end end
    return nil
end
local game = {}
function game:GetService(name)
    if name == "Players" then return Players end
    if name == "ReplicatedStorage" then return {} end
    error("Unexpected service: " .. name)
end
local workspace = { GetServerTimeNow = function() return clock end }
local Instance = {}
function Instance.new(class)
    local object = { ClassName = class, OnServerEvent = signal() }
    function object:FireClient(player, payload)
        messages[player.UserId] = messages[player.UserId] or {}
        table.insert(messages[player.UserId], payload)
    end
    table.insert(instances, object)
    return object
end
local Random = {}
function Random.new()
    return { NextInteger = function(_, a, b)
        seed = seed * 48271 % 2147483647
        return a + seed % (b - a + 1)
    end }
end
local task = {
    spawn = function(callback) loop = coroutine.create(callback) end,
    wait = function() coroutine.yield() end,
}
local script = { Parent = { Engine = "Engine", World = "World" } }
local realRequire = require
local function require(module)
    if module == "Engine" then return realRequire("../src/server/Engine") end
    if module == "World" then return { build = function() end } end
    error("Unexpected module")
end

-- @SERVER_SOURCE@

local remote
for _, instance in ipairs(instances) do if instance.Name == "Action" then remote = instance end end
assert(remote and loop)
assert(coroutine.resume(loop)) -- pause at the first scheduler wait
local function join(id)
    local player = { UserId = id, DisplayName = "Player " .. id }
    table.insert(online, player)
    Players.PlayerAdded:fire(player)
    return player
end
local function leave(player)
    table.remove(online, table.find(online, player))
    Players.PlayerRemoving:fire(player)
end
local function latest(player)
    for i = #messages[player.UserId], 1, -1 do
        local value = messages[player.UserId][i]
        if not value.error then return value end
    end
    error("No state for player")
end
local function emit(player, verb, value, revision, epoch)
    remote.OnServerEvent:fire(player, verb, value, revision, epoch)
end
local function tick(seconds)
    clock += seconds
    local ok, message = coroutine.resume(loop)
    assert(ok, message)
end
local passed = 0
local function check(name, callback)
    callback(); passed += 1; print("PASS server: " .. name)
end
local p1, p2 = join(101), join(102)
check("first player hosts lobby; fewer than three cannot start multiplayer", function()
    assert(latest(p1).phase == "lobby" and latest(p1).hostId == 101)
    emit(p1, "start", "friends")
    assert(latest(p1).phase == "lobby")
    assert(messages[101][#messages[101]].error)
end)
local p3 = join(103)
check("non-host cannot start multiplayer", function()
    emit(p2, "start", "friends")
    assert(latest(p2).phase == "lobby")
end)
check("host starts three-player game; each client gets only its own hand", function()
    emit(p1, "start", "friends")
    for _, player in ipairs(online) do
        local view = latest(player)
        assert(view.phase ~= "lobby" and #view.hand == 1 and #view.seats == 3)
        for _, seat in ipairs(view.seats) do assert(seat.hand == nil) end
    end
end)
check("late joiner spectates and cannot play or reset the game", function()
    local spectator = join(104)
    local view = latest(spectator)
    assert(view.mySeat == nil and #view.hand == 0)
    local before = latest(p1).revision
    emit(spectator, "bid", 0, view.revision, view.epoch)
    emit(spectator, "lobby")
    assert(latest(p1).revision == before and latest(p1).phase ~= "lobby")
    leave(spectator)
end)
check("stale revisions and epochs cannot change a turn", function()
    local view = latest(p1)
    local actor = Players:GetPlayerByUserId(view.seats[view.turn].id)
    emit(actor, "bid", 0, view.revision - 1, view.epoch)
    assert(latest(actor).revision == view.revision)
    emit(actor, "bid", 0, view.revision, view.epoch - 1)
    assert(latest(actor).revision == view.revision)
end)
check("server rejects an out-of-turn request", function()
    local view = latest(p1)
    local other = Players:GetPlayerByUserId(view.seats[view.turn % 3 + 1].id)
    emit(other, "bid", 0, view.revision, view.epoch)
    assert(messages[other.UserId][#messages[other.UserId]].error)
    assert(latest(p1).revision == view.revision)
end)
check("turn deadline automatically advances an idle human", function()
    local before = latest(p1)
    tick(46)
    assert(latest(p1).revision > before.revision)
end)
check("disconnect becomes bot; host moves to a connected participant", function()
    leave(p1)
    local view = latest(p2)
    assert(view.seats[1].bot and view.hostId == p2.UserId)
end)
check("leaving all human seats frees the table for spectators", function()
    local spectator = join(105)
    leave(p2); leave(p3)
    assert(latest(spectator).phase == "lobby" and latest(spectator).hostId == 105)
end)
local p5 = Players:GetPlayerByUserId(105)
check("practice contains requester and two bots, not other lobby users", function()
    local p6 = join(106)
    emit(p5, "start", "practice")
    local view = latest(p5)
    assert(#view.seats == 3 and view.seats[2].bot and view.seats[3].bot)
    assert(view.seats[1].id == 105 and latest(p6).mySeat == nil)
end)
check("malformed requests and request floods are bounded", function()
    local p6 = Players:GetPlayerByUserId(106)
    local before = #messages[106]
    emit(p6, {}, {}); emit(p6, string.rep("x", 1000))
    assert(#messages[106] == before)
    for _ = 1, 100 do emit(p6, "sync") end
    assert(#messages[106] - before <= 12)
end)
check("scheduler finishes a full practice match and host returns to lobby", function()
    for _ = 1, 4000 do
        if latest(p5).phase == "finished" then break end
        tick(46)
    end
    assert(latest(p5).phase == "finished")
    assert(#latest(p5).history == 20)
    local p6 = Players:GetPlayerByUserId(106)
    emit(p6, "lobby")
    assert(latest(p5).phase == "finished")
    emit(p5, "lobby")
    assert(latest(p5).phase == "lobby")
end)
print(string.format("%d server lifecycle tests passed (mock transport).", passed))
