-- Shared physical layout, also checked outside the engine with Roblox datatypes.
local Layout = {}
function Layout.flat(position, angle, faceDown)
    return CFrame.new(position) * CFrame.Angles(0, angle or 0, 0)
        * CFrame.Angles(if faceDown then -math.pi / 2 else math.pi / 2, 0, 0)
end
function Layout.hand(camera, index, count, raised, flipped, overview, aspect)
    local center = index - (count + 1) / 2
    local availableWidth = math.min(5.45, 2 * 3.15 * math.tan(math.rad(33)) * (aspect or 1.6) - 1.55)
    local spread = math.min(0.56, math.max(1.5, availableWidth) / math.max(1, count - 1))
    if overview then
        return Layout.flat(Vector3.new(center * spread, 3.4 + index * 0.012 + raised * 0.12, 5.9), center * 0.05, flipped)
    end
    local roll = math.rad(-center * math.min(4, 36 / math.max(1, count - 1)))
    return camera * CFrame.new(center * spread, -0.66 - math.abs(center) * 0.014 + raised * 0.24,
        -3.35 + math.abs(center) * 0.012 - raised * 0.08) * CFrame.Angles(0, math.pi + (if flipped then math.pi else 0), roll)
end
function Layout.camera(mode, eye, focus, inspection, yaw, pitch)
    if mode == "inspect" then return CFrame.lookAt(inspection + Vector3.new(0, 0, 4), inspection), 37 end
    if mode == "top" then return CFrame.lookAt(Vector3.new(0, 21, 0.1), Vector3.new(0, 3.3, 0)), 57 end
    return CFrame.lookAt(eye, focus) * CFrame.Angles(pitch or 0, yaw or 0, 0), 66
end
return Layout
