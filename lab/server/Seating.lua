local Seating = {}

function Seating.canSit(player, seat, room)
    if not seat:IsA("Seat") or not seat:IsDescendantOf(room) or seat.Disabled or seat.Occupant then return false end
    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not humanoid or not root or humanoid.Health <= 0 or humanoid.SeatPart then return false end
    if (root.Position - seat.Position).Magnitude > 6 then return false end
    return true, humanoid
end

function Seating.current(player, room)
    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local seat = humanoid and humanoid.SeatPart
    if not seat or not seat:IsA("Seat") or not seat:IsDescendantOf(room)
        or not seat:GetAttribute("LabSeatIndex") or seat.Occupant ~= humanoid then return nil end
    return seat, humanoid
end

function Seating.attach(room, players, leaveEvent)
    local pending, cooldown = {}, setmetatable({}, { __mode = "k" })
    local function moveOutside(humanoid, seat)
        local character = humanoid.Parent
        local root = character and character:FindFirstChild("HumanoidRootPart")
        local destination = seat:GetAttribute("ExitCFrame")
        if not root or humanoid.Health <= 0 or humanoid.SeatPart or not destination then return end
        if (root.Position - seat.Position).Magnitude > 8 then return end
        root.CFrame = destination
        root.AssemblyLinearVelocity, root.AssemblyAngularVelocity = Vector3.zero, Vector3.zero
    end
    for _, seat in ipairs(room:GetDescendants()) do
        if seat:IsA("Seat") and seat:GetAttribute("LabSeatIndex") then
            local prompt = seat:FindFirstChild("TakeSeat")
            local previous
            local function changed()
                local occupant = seat.Occupant
                prompt.Enabled = occupant == nil
                local dummy = room:FindFirstChild("SeatDummy_" .. seat:GetAttribute("LabSeatIndex"))
                if dummy then
                    for _, part in ipairs(dummy:GetDescendants()) do
                        if part:IsA("BasePart") then part.Transparency = if occupant then 1 else 0 end
                    end
                end
                if previous and previous ~= occupant then
                    local old = previous
                    cooldown[old] = os.clock() + 1
                    task.defer(function() moveOutside(old, seat) end)
                end
                previous = occupant
            end
            prompt.Triggered:Connect(function(player)
                local ok, humanoid = Seating.canSit(player, seat, room)
                if not ok or (pending[seat] or 0) > os.clock() or (cooldown[humanoid] or 0) > os.clock() then return end
                pending[seat] = os.clock() + 1
                seat:Sit(humanoid)
            end)
            seat:GetPropertyChangedSignal("Occupant"):Connect(changed)
            changed()
        end
    end
    leaveEvent.OnServerEvent:Connect(function(player)
        local seat, humanoid = Seating.current(player, room)
        if not seat then return end
        local weld = seat:FindFirstChild("SeatWeld")
        if weld then weld:Destroy() end
        humanoid.Sit = false
        humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
        task.defer(function() moveOutside(humanoid, seat) end)
    end)
    players.PlayerRemoving:Connect(function(player)
        local character = player.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        if humanoid then cooldown[humanoid] = nil end
    end)
end

return Seating
