local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Workspace = game:GetService("Workspace")

local SlingshotImpactFX = {}

local SPARK_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE_TEXTURE = "rbxasset://textures/particles/smoke_main.dds"

local function validVector3(value)
	return typeof(value) == "Vector3"
		and value.X == value.X
		and value.Y == value.Y
		and value.Z == value.Z
end

local function safeNormal(normal)
	if validVector3(normal) and normal.Magnitude > 0.001 then
		return normal.Unit
	end
	return Vector3.yAxis
end

local function createImpactRoot(position, normal)
	local root = Instance.new("Part")
	root.Name = "SlingshotEggImpactFX"
	root.Size = Vector3.new(0.1, 0.1, 0.1)
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CanTouch = false
	root.CanQuery = false
	root.CastShadow = false
	root.CFrame = CFrame.lookAt(position + normal * 0.04, position + normal)
	root.Parent = Workspace
	return root
end

local function createParticleBurst(root)
	local attachment = Instance.new("Attachment")
	attachment.Name = "ImpactAttachment"
	attachment.Parent = root

	local sparks = Instance.new("ParticleEmitter")
	sparks.Name = "AnimeSparkBurst"
	sparks.Texture = SPARK_TEXTURE
	sparks.Rate = 0
	sparks.Lifetime = NumberRange.new(0.15, 0.30)
	sparks.Speed = NumberRange.new(6, 13)
	sparks.SpreadAngle = Vector2.new(150, 150)
	sparks.Drag = 5
	sparks.Rotation = NumberRange.new(0, 360)
	sparks.RotSpeed = NumberRange.new(-220, 220)
	sparks.LightEmission = 0.65
	sparks.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 247, 214)),
		ColorSequenceKeypoint.new(0.45, Color3.fromRGB(255, 205, 107)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(222, 151, 62)),
	})
	sparks.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.34),
		NumberSequenceKeypoint.new(0.35, 0.20),
		NumberSequenceKeypoint.new(1, 0),
	})
	sparks.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.05),
		NumberSequenceKeypoint.new(0.7, 0.22),
		NumberSequenceKeypoint.new(1, 1),
	})
	sparks.EmissionDirection = Enum.NormalId.Front
	sparks.Parent = attachment

	local puff = Instance.new("ParticleEmitter")
	puff.Name = "EggImpactPuff"
	puff.Texture = SMOKE_TEXTURE
	puff.Rate = 0
	puff.Lifetime = NumberRange.new(0.20, 0.38)
	puff.Speed = NumberRange.new(1.5, 3.8)
	puff.SpreadAngle = Vector2.new(115, 115)
	puff.Drag = 3
	puff.LightEmission = 0.15
	puff.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 238, 184)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(190, 139, 72)),
	})
	puff.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.42),
		NumberSequenceKeypoint.new(0.45, 0.78),
		NumberSequenceKeypoint.new(1, 1.05),
	})
	puff.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.22),
		NumberSequenceKeypoint.new(0.55, 0.52),
		NumberSequenceKeypoint.new(1, 1),
	})
	puff.EmissionDirection = Enum.NormalId.Front
	puff.Parent = attachment

	sparks:Emit(14)
	puff:Emit(6)
end

local function createFlash(root, position)
	local flash = Instance.new("Part")
	flash.Name = "EggImpactFlash"
	flash.Shape = Enum.PartType.Ball
	flash.Size = Vector3.new(0.20, 0.20, 0.20)
	flash.Material = Enum.Material.Neon
	flash.Color = Color3.fromRGB(255, 221, 132)
	flash.Transparency = 0.08
	flash.Anchored = true
	flash.CanCollide = false
	flash.CanTouch = false
	flash.CanQuery = false
	flash.CastShadow = false
	flash.CFrame = CFrame.new(position)
	flash.Parent = root

	local tween = TweenService:Create(
		flash,
		TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{
			Size = Vector3.new(0.95, 0.95, 0.95),
			Transparency = 1,
		}
	)
	tween:Play()
end

local function createImpactRing(root)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ImpactRing"
	billboard.Size = UDim2.fromOffset(48, 48)
	billboard.StudsOffsetWorldSpace = Vector3.zero
	billboard.AlwaysOnTop = false
	billboard.LightInfluence = 0
	billboard.Parent = root

	local ring = Instance.new("Frame")
	ring.Name = "Ring"
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.Position = UDim2.fromScale(0.5, 0.5)
	ring.Size = UDim2.fromOffset(10, 10)
	ring.BackgroundTransparency = 1
	ring.Parent = billboard

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = ring

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2.2
	stroke.Transparency = 0.08
	stroke.Color = Color3.fromRGB(255, 220, 136)
	stroke.Parent = ring

	TweenService:Create(
		ring,
		TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = UDim2.fromOffset(42, 42) }
	):Play()

	TweenService:Create(
		stroke,
		TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ Transparency = 1 }
	):Play()
end

function SlingshotImpactFX.Play(position, normal)
	if not validVector3(position) then
		return
	end

	normal = safeNormal(normal)
	local root = createImpactRoot(position, normal)
	createParticleBurst(root)
	createFlash(root, position)
	createImpactRing(root)
	Debris:AddItem(root, 0.75)
end

return SlingshotImpactFX
