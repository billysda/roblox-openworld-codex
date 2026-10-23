-- GroundCollisionV022.lua
-- Gran Wyvern de Tierra - colisiones simplificadas sobre torso.
-- No cambia coordenadas de DT_Root, RootPart ni del esqueleto.
-- Aplicar SOLAMENTE en copia de Place para Play Mode A/B.
local GroundCollision = {}
GroundCollision.__index = GroundCollision

function GroundCollision.new(model, root)
    local self = setmetatable({}, GroundCollision)
    self.model = model
    self.root = root

    -- El RootPart de 0.10 studs provocaba vuelco (auditoria A/B 23-oct).
    -- Ninguna parte del rig visual debe chocar con el ambiente.
    for _, obj in ipairs(model:GetDescendants()) do
        if obj:IsA("MeshPart") or obj.Name == "RootPart" then
            obj.CanCollide = false
        end
    end

    -- GroundCollider original penetra 0.587 studs en la plataforma; no activarlo.
    local originalCollider = model:FindFirstChild("DT_GroundCollider")
    if originalCollider and originalCollider:IsA("BasePart") then
        originalCollider.CanCollide = false
    end
    root.CanCollide = false

    local proxy = model:FindFirstChild("DT_TorsoCollisionV022")
    if not proxy then
        proxy = Instance.new("Part")
        proxy.Name = "DT_TorsoCollisionV022"
        proxy.Shape = Enum.PartType.Ball
        proxy.Size = Vector3.new(3, 3, 3)
        proxy.CFrame = root.CFrame * CFrame.new(0, 0.35, 0)
        proxy.Anchored = false
        proxy.Massless = true
        proxy.CanCollide = false
        proxy.CanTouch = false
        proxy.CanQuery = false
        proxy.Transparency = 1
        proxy.CastShadow = false
        proxy.Parent = model

        local weld = Instance.new("WeldConstraint")
        weld.Name = "DT_TorsoCollisionWeldV022"
        weld.Part0 = root
        weld.Part1 = proxy
        weld.Parent = proxy
    end

    assert(proxy:IsA("BasePart"), "DT_TorsoCollisionV022 no es BasePart")
    self.proxy = proxy
    self.lastActive = false
    return self
end

function GroundCollision:SetActive(active)
    -- Collision proxy solo en modo terrestre. La aproximacion/vuelo R4.2
    -- permanecen exactamente sin colisiones como en la version aprobada.
    if self.lastActive ~= active then
        self.lastActive = active
        self.proxy.CanCollide = active
    end
end

return GroundCollision
