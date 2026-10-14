-- =========================================================================
--  MOTOR / OVEJA NPC - HOVER ESTABLE SIN MICROSALTOS
-- =========================================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

-- Referencias principales
local oveja = workspace:WaitForChild("MOTOR")
local rootPart = oveja:WaitForChild("HumanoidRootPart")
local animator = oveja:WaitForChild("AnimationController"):WaitForChild("Animator")

local linearVelocity = rootPart:WaitForChild("LinearVelocity")
local alignOrientation = rootPart:WaitForChild("AlignOrientation")

-- Asegurar control del servidor para reducir jitter por red
pcall(function()
	rootPart:SetNetworkOwner(nil)
end)

-- Attachment base
local rootAttachment = rootPart:FindFirstChildWhichIsA("Attachment")
if not rootAttachment then
	rootAttachment = Instance.new("Attachment")
	rootAttachment.Name = "RootAttachment"
	rootAttachment.Parent = rootPart
end

-- Configurar LinearVelocity
linearVelocity.Attachment0 = rootAttachment
linearVelocity.RelativeTo = Enum.ActuatorRelativeTo.World
linearVelocity.ForceLimitMode = Enum.ForceLimitMode.PerAxis
linearVelocity.MaxAxesForce = Vector3.new(100000, 0, 100000)
linearVelocity.VectorVelocity = Vector3.zero

-- Configurar AlignOrientation
alignOrientation.Attachment0 = rootAttachment

-- =========================================================================
-- CONFIGURACIÓN
-- =========================================================================
local ID_CAMINAR = "rbxassetid://77179937004940"
local ID_IDLE    = "rbxassetid://121773693589116"

local RADIO_DETECCION = 15
local VELOCIDAD_HUIDA = 12

local ALTURA_OBJETIVO = 2.6
local RAY_LENGTH = ALTURA_OBJETIVO + 8

-- Control de altura estable
local SPRING = 1400
local DAMPING = 220
local HEIGHT_SMOOTHING = 12
local MAX_CORRECTION_RATIO = 0.75

-- Raycast params
local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Exclude
raycastParams.FilterDescendantsInstances = { oveja }
raycastParams.IgnoreWater = true

-- =========================================================================
-- ANIMACIONES
-- =========================================================================
local animObjCaminar = Instance.new("Animation")
animObjCaminar.AnimationId = ID_CAMINAR
local animTrackCaminar = animator:LoadAnimation(animObjCaminar)
animTrackCaminar.Priority = Enum.AnimationPriority.Movement

local animObjIdle = Instance.new("Animation")
animObjIdle.AnimationId = ID_IDLE
local animTrackIdle = animator:LoadAnimation(animObjIdle)
animTrackIdle.Priority = Enum.AnimationPriority.Idle

-- =========================================================================
-- FUNCIONES
-- =========================================================================
local function conseguirJugadorCercano()
	local masCercano = nil
	local distanciaMinima = RADIO_DETECCION

	for _, jugador in ipairs(Players:GetPlayers()) do
		local personaje = jugador.Character
		if personaje then
			local hrp = personaje:FindFirstChild("HumanoidRootPart")
			local humanoid = personaje:FindFirstChildOfClass("Humanoid")

			if hrp and humanoid and humanoid.Health > 0 then
				local dist = (rootPart.Position - hrp.Position).Magnitude
				if dist < distanciaMinima then
					distanciaMinima = dist
					masCercano = hrp
				end
			end
		end
	end

	return masCercano
end

local function obtenerDireccionPlana(vec)
	local plano = Vector3.new(vec.X, 0, vec.Z)
	if plano.Magnitude > 0.001 then
		return plano.Unit
	end
	return nil
end

-- =========================================================================
-- HOVER ESTABLE
-- =========================================================================
local alturaFiltrada = ALTURA_OBJETIVO

RunService.Heartbeat:Connect(function(dt)
	local origin = rootPart.Position + Vector3.new(0, 0.25, 0)
	local direction = Vector3.new(0, -RAY_LENGTH, 0)

	local result = workspace:Raycast(origin, direction, raycastParams)

	if result then
		-- Distancia real al suelo
		local alturaActual = result.Distance

		-- Suavizado para evitar ruido de medición
		local alpha = math.clamp(dt * HEIGHT_SMOOTHING, 0, 1)
		alturaFiltrada = alturaFiltrada + (alturaActual - alturaFiltrada) * alpha

		local errorAltura = ALTURA_OBJETIVO - alturaFiltrada
		local velocidadVertical = rootPart.AssemblyLinearVelocity.Y

		-- Fuerza base anti-gravedad
		local peso = rootPart.AssemblyMass * workspace.Gravity

		-- Corrección PD suave
		local correccion = (errorAltura * SPRING) - (velocidadVertical * DAMPING)

		-- Limitar corrección para evitar oscilaciones
		local limite = peso * MAX_CORRECTION_RATIO
		correccion = math.clamp(correccion, -limite, limite)

		-- Fuerza final siempre sostiene el peso y corrige suavemente
		local fuerzaFinal = peso + correccion
		hoverForce = rootPart:FindFirstChild("HoverForce")

		if not hoverForce then
			hoverForce = Instance.new("VectorForce")
			hoverForce.Name = "HoverForce"
			hoverForce.Attachment0 = rootAttachment
			hoverForce.RelativeTo = Enum.ActuatorRelativeTo.World
			hoverForce.ApplyAtCenterOfMass = true
			hoverForce.Parent = rootPart
		end

		hoverForce.Force = Vector3.new(0, fuerzaFinal, 0)
	else
		-- Si no detecta suelo, no flota artificialmente
		local hoverForce = rootPart:FindFirstChild("HoverForce")
		if hoverForce then
			hoverForce.Force = Vector3.zero
		end
	end
end)

-- =========================================================================
-- BUCLE DE COMPORTAMIENTO
-- =========================================================================
task.spawn(function()
	while true do
		local objetivo = conseguirJugadorCercano()

		if objetivo and objetivo.Parent then
			-- ESTADO: HUYENDO
			if animTrackIdle.IsPlaying then
				animTrackIdle:Stop(0.25)
			end

			local direccion = rootPart.Position - objetivo.Position
			local direccionPlana = obtenerDireccionPlana(direccion)

			if direccionPlana then
				linearVelocity.VectorVelocity = direccionPlana * VELOCIDAD_HUIDA
				alignOrientation.CFrame = CFrame.lookAt(Vector3.zero, direccionPlana, Vector3.yAxis)

				if not animTrackCaminar.IsPlaying then
					animTrackCaminar:Play(0.25)
				end
			else
				linearVelocity.VectorVelocity = Vector3.zero
			end
		else
			-- ESTADO: IDLE
			linearVelocity.VectorVelocity = Vector3.zero

			local lookDirection = obtenerDireccionPlana(rootPart.CFrame.LookVector)
			if lookDirection then
				alignOrientation.CFrame = CFrame.lookAt(Vector3.zero, lookDirection, Vector3.yAxis)
			end

			if animTrackCaminar.IsPlaying then
				animTrackCaminar:Stop(0.35)
			end

			if not animTrackIdle.IsPlaying then
				animTrackIdle:Play(0.35)
			end
		end

		task.wait(0.1)
	end
end)