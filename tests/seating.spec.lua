-- Executes the actual seating service with mocked signals and avatar physics.
local function signal()
    local callbacks = {}
    return { Connect = function(_, fn) table.insert(callbacks, fn) end,
        fire = function(_, ...) for _, fn in ipairs(callbacks) do fn(...) end end }
end
local function vec(x)
    return setmetatable({ X = x }, { __sub = function(a, b) return { Magnitude = math.abs(a.X - b.X) } end })
end
local Vector3 = { zero = vec(0) }
local Enum = { HumanoidStateType = { GettingUp = "gettingUp" } }
local task = { defer = function(callback) callback() end }
local Seating = (function()
-- @SEATING_SOURCE@
end)()
local room = { children = {} }
function room:GetDescendants() return self.children end
function room:FindFirstChild() return nil end
local players = { PlayerRemoving = signal() }
local leave = { OnServerEvent = signal() }
local changed = signal()
local seat = { Position = vec(0), Parent = room, Disabled = false,
    attributes = { LabSeatIndex = 1, ExitCFrame = { marker = "outside" } },
    TakeSeat = { Triggered = signal(), Enabled = true } }
function seat:IsA(kind) return kind == "Seat" end
function seat:IsDescendantOf(parent) return self.Parent == parent end
function seat:GetAttribute(name) return self.attributes[name] end
function seat:GetPropertyChangedSignal() return changed end
function seat:FindFirstChild(name)
    if name == "TakeSeat" then return self.TakeSeat end
    if name == "SeatWeld" and self.Occupant then
        return { Destroy = function()
            self.Occupant.SeatPart, self.Occupant.Sit, self.Occupant = nil, false, nil
            changed:fire()
        end }
    end
end
function seat:Sit(humanoid)
    self.Occupant, humanoid.SeatPart, humanoid.Sit = humanoid, self, true
    changed:fire()
end
table.insert(room.children, seat)
local function player(position)
    local root = { Position = vec(position) }
    local humanoid = { Health = 100 }
    function humanoid:ChangeState(state) self.state = state end
    local character = {}
    humanoid.Parent = character
    function character:FindFirstChild(name) if name == "HumanoidRootPart" then return root end end
    function character:FindFirstChildOfClass(name) if name == "Humanoid" then return humanoid end end
    return { Character = character }, humanoid, root
end
Seating.attach(room, players, leave)
local passed = 0
local function test(name, callback)
    callback(); passed += 1; print("PASS seating: " .. name)
end
test("far, dead, missing or already seated avatars cannot take a chair", function()
    local p, h, root = player(7)
    assert(not Seating.canSit(p, seat, room))
    root.Position = vec(0); h.Health = 0
    assert(not Seating.canSit(p, seat, room))
    h.Health, h.SeatPart = 100, {}
    assert(not Seating.canSit(p, seat, room))
    assert(not Seating.canSit({}, seat, room))
end)
test("disabled, occupied and unrelated chairs reject entry", function()
    local p = player(0)
    seat.Disabled = true; assert(not Seating.canSit(p, seat, room)); seat.Disabled = false
    seat.Occupant = {}; assert(not Seating.canSit(p, seat, room)); seat.Occupant = nil
    seat.Parent = {}; assert(not Seating.canSit(p, seat, room)); seat.Parent = room
end)
local p, h, root = player(4)
test("nearby player sits through the native Seat; occupied prompt disappears", function()
    seat.TakeSeat.Triggered:fire(p)
    assert(seat.Occupant == h and h.SeatPart == seat and h.Sit)
    assert(not seat.TakeSeat.Enabled)
end)
test("another player cannot leave or claim the occupied seat", function()
    local other = player(2)
    assert(not Seating.canSit(other, seat, room))
    leave.OnServerEvent:fire(other)
    assert(seat.Occupant == h)
end)
test("standing up releases the actual seat and moves outside the chair", function()
    leave.OnServerEvent:fire(p)
    assert(not h.Sit and not h.SeatPart and not seat.Occupant)
    assert(root.CFrame == seat.attributes.ExitCFrame)
    assert(seat.TakeSeat.Enabled and h.state == "gettingUp")
end)
test("native jump exit also moves outside and restores the prompt", function()
    local jumper, jumpHumanoid, jumpRoot = player(0)
    -- Direct native contact can seat a character without the prompt.
    seat:Sit(jumpHumanoid)
    seat:FindFirstChild("SeatWeld"):Destroy()
    assert(not jumpHumanoid.SeatPart and seat.TakeSeat.Enabled)
    assert(jumpRoot.CFrame == seat.attributes.ExitCFrame)
end)
test("standing requests outside the table do nothing", function()
    local walker, _, walkRoot = player(0)
    leave.OnServerEvent:fire(walker)
    assert(walkRoot.CFrame == nil)
end)
test("a dead avatar is not moved on seat release", function()
    local dying, dyingHumanoid, dyingRoot = player(0)
    seat:Sit(dyingHumanoid); dyingHumanoid.Health = 0
    seat:FindFirstChild("SeatWeld"):Destroy()
    assert(dyingRoot.CFrame == nil and seat.TakeSeat.Enabled)
end)
print(passed .. " seating lifecycle tests passed (mock avatar physics).")
