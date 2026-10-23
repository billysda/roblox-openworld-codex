--!strict
-- WyvernGroundV01.lua
-- Exclusivo para Workspace.wyvernfbx (Gran Wyvern de Tierra).
-- Sensor de suelo + sustentacion vertical amortiguada SOLO en tierra.
-- No modifica huesos, Welds, CFrame ni el vuelo R4.1/R4.2.

local Workspace = game:GetService("Workspace")
local Ground = {}
Ground.__index = Ground

Ground.CONFIG = {
    -- Calibracion inicial tomada del apoyo Idle 2; ajustar con pruebas Play.
    RestRootHeight = 1.798,
    MaxRayDistance = 70,
    MaximumSlopeNormalY = math.cos(math.rad(30)),
    SupportKp = 38,  -- aceleracion por stud de error vertical
    SupportKd = 11,  -- amortiguacion de velocidad vertical
    MaxSupportAcceleration = 2.5 * Workspace.Gravity,
}

local PROBES = {
    Center = Vector3.new(0, 0, 0),
    Front = Vector3.new(0, 0, -3),  -- DT_Root corregido: -Z = cabeza
    Rear = Vector3.new(0, 0, 3),
    Left = Vector3.new(-2.5, 0, 0),
    Right = Vector3.new(2.5, 0, 0),
}

function Ground.new(model, rootPart, attachment)
    local self = setmetatable({}, Ground)
    self.model = model
    self.root = rootPart

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { model }
    params.RespectCanCollide = true
    params.IgnoreWater = true
    self.params = params

    local support = rootPart:FindFirstChild("WyvernGroundSupportV01")
    if not support then
        support = Instance.new("VectorForce")
        support.Name = "WyvernGroundSupportV01"
        support.Attachment0 = attachment
        support.RelativeTo = Enum.ActuatorRelativeTo.World
        support.ApplyAtCenterOfMass = true
        support.Force = Vector3.zero
        support.Enabled = false
        support.Parent = rootPart
    end
    self.support = support
    return self
end

function Ground:Sense()
    local cf = self.root.CFrame
    local rootPosition = self.root.Position
    local hits = {}
    local valid = 0
    local averagedNormal = Vector3.zero

    for key, offset in pairs(PROBES) do
        local transformed = cf:PointToWorldSpace(offset)
        -- Los puntos de muestreo siempre salen desde la misma altura Y,
        -- incluso cuando el dragon hace pitch o roll.
        local rayOrigin = Vector3.new(transformed.X, rootPosition.Y + 4, transformed.Z)
        local hit = Workspace:Raycast(rayOrigin, Vector3.new(0, -Ground.CONFIG.MaxRayDistance, 0), self.params)
        if hit and hit.Normal.Y >= Ground.CONFIG.MaximumSlopeNormalY then
            hits[key] = hit
            valid += 1
            averagedNormal += hit.Normal
        end
    end

    local center = hits.Center
    if not center then
        return { valid = false, clearance = math.huge, hitCount = valid, normal = Vector3.yAxis }
    end

    local normal = valid > 0 and (averagedNormal / valid).Unit or Vector3.yAxis
    local clearance = rootPosition.Y - center.Position.Y - Ground.CONFIG.RestRootHeight
    return {
        valid = valid >= 3 and normal.Y >= Ground.CONFIG.MaximumSlopeNormalY,
        clearance = clearance,  -- 0 significa altura de apoyo calibrada
        groundY = center.Position.Y,
        normal = normal,
        hitCount = valid,
        hit = center,
    }
end

function Ground:DisableSupport()
    self.support.Force = Vector3.zero
    self.support.Enabled = false
end

function Ground:ApplyGroundSupport(sample)
    if not sample or not sample.valid then
        self:DisableSupport()
        return
    end

    local mass = self.root.AssemblyMass
    if mass <= 0 then
        self:DisableSupport()
        return
    end

    -- Al cambiar a tierra, el controlador principal deshabilita la fuerza
    -- VERTICAL de LinearVelocity. Esta VectorForce solo compensa gravedad y
    -- regula la altura suavemente. Sin anclaje ni teletransporte por frame.
    local heightError = -sample.clearance
    local velocityY = self.root.AssemblyLinearVelocity.Y
    local accel = Workspace.Gravity
        + Ground.CONFIG.SupportKp * heightError
        - Ground.CONFIG.SupportKd * velocityY
    accel = math.clamp(accel, 0, Ground.CONFIG.MaxSupportAcceleration)

    self.support.Force = Vector3.new(0, mass * accel, 0)
    self.support.Enabled = true
end

return Ground
