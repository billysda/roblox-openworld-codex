-- GroundCollisionV022.lua -- v0.2.3 physical contact profile.
-- Gran Wyvern de Tierra: physical torso contact persists in ALL states,
-- including flight, approach, touchdown, ground recovery and takeoff.
-- Prototype only: validate real claws and slopes in isolated Play Place.
local GroundCollision = {}
GroundCollision.__index = GroundCollision

local PROXY_NAME = "DT_TorsoCollisionV022"
local WELD_NAME = "DT_TorsoCollisionWeldV022"
local LOCAL_OFFSET = Vector3.new(0, -0.27, 0)
local PROXY_SIZE = Vector3.new(3, 3, 3)

function GroundCollision.new(model, root)
    assert(model and root and root:IsA("BasePart"), "Wyvern collider requires root")
    local self = setmetatable({}, GroundCollision)
    self.model = model
    self.root = root

    -- Animation skeleton and original collider must never handle collisions.
    for _, part in ipairs(model:GetDescendants()) do
        if part:IsA("MeshPart") or part.Name == "RootPart" then
            part.CanCollide = false
        end
    end
    local obsolete = model:FindFirstChild("DT_GroundCollider")
    if obsolete and obsolete:IsA("BasePart") then
        obsolete.CanCollide = false
    end
    root.CanCollide = false

    local proxy = model:FindFirstChild(PROXY_NAME)
    if proxy then
        assert(proxy:IsA("Part"), "Existing torso proxy is not a Part")
    else
        proxy = Instance.new("Part")
        proxy.Name = PROXY_NAME
        proxy.Parent = model
    end

    -- Rebuild ONLY the proxy's own weld in the isolated test Place:
    -- do not change DT_RootWeld, NeckSeat weld or mesh Motor6D.
    local oldWeld = proxy:FindFirstChild(WELD_NAME)
    if oldWeld and not oldWeld:IsA("WeldConstraint") then
        error("Unexpected proxy weld class")
    end
    if oldWeld then oldWeld:Destroy() end
    proxy.CanCollide = false -- avoid impulse during reconfiguration
    proxy.Anchored = false
    proxy.Massless = true
    proxy.Shape = Enum.PartType.Ball
    proxy.Size = PROXY_SIZE
    proxy.CFrame = root.CFrame * CFrame.new(LOCAL_OFFSET)
    proxy.CanTouch = true
    proxy.CanQuery = false
    proxy.Transparency = 1
    proxy.CastShadow = false
    proxy.CustomPhysicalProperties = PhysicalProperties.new(
        0.7, -- density (proxy massless)
        0.85, -- friction, terrain traction
        0.0, -- elasticity: do not bounce
        100.0, -- friction weight
        100.0 -- elasticity weight
    )

    local weld = Instance.new("WeldConstraint")
    weld.Name = WELD_NAME
    weld.Part0 = root
    weld.Part1 = proxy
    weld.Parent = proxy

    -- Permanent physical collision, explicitly never toggled during flight.
    proxy.CanCollide = true
    self.proxy = proxy
    self.lastGrounded = false
    return self
end

function GroundCollision:SetActive(grounded)
    -- Compatibility with v0.2.2 FlightController call sites.
    -- Records gameplay state only: the collider is always physically active.
    self.lastGrounded = grounded
    if not self.proxy.CanCollide then
        self.proxy.CanCollide = true
    end
end

function GroundCollision:GetBottomOffset()
    -- Flat-ground rest height required for physical contact at current yaw.
    return -LOCAL_OFFSET.Y + PROXY_SIZE.Y * 0.5
end

return GroundCollision
