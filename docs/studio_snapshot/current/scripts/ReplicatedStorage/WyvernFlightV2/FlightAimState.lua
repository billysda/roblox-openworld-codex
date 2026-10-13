-- FlightAimState.lua
-- Fuente Única de Verdad para el Mouse Aim de WyvernFlightV2 (Fase R4.1)
-- Compartido en ReplicatedStorage para desacoplar completamente la orientación de aim
-- de la cámara visual y del controlador de inputs.

local FlightAimState = {
	playerAimYaw = 0.0,       -- Radianes: rumbo horizontal apuntado por el jugador
	playerAimPitch = 0.0,     -- Radianes: elevación vertical apuntada por el jugador
	isAimActive = true,       -- Si el sistema de aim está activo
	isMouseCaptured = false,  -- Si el cursor está capturado (LockCenter)
	lastMouseDeltaX = 0.0,    -- Último delta X del mouse en píxeles
	lastMouseDeltaY = 0.0,    -- Último delta Y del mouse en píxeles
	aimYawErrorDeg = 0.0,     -- Error horizontal wyvern <-> aim (grados)
	aimPitchErrorDeg = 0.0,   -- Error vertical wyvern <-> aim (grados)
	aimTurnIntent = 0.0,      -- Intención de viraje [-1, 1]
	aimPitchIntent = 0.0,     -- Intención de cabeceo [-1, 1]
	isInitialized = false,
}

function FlightAimState:GetAimDirection()
	return CFrame.fromEulerAnglesYXZ(self.playerAimPitch, self.playerAimYaw, 0).LookVector
end

function FlightAimState:ResetAim(yaw, pitch)
	self.playerAimYaw = yaw or 0.0
	self.playerAimPitch = pitch or 0.0
	self.aimYawErrorDeg = 0.0
	self.aimPitchErrorDeg = 0.0
	self.aimTurnIntent = 0.0
	self.aimPitchIntent = 0.0
	self.lastMouseDeltaX = 0.0
	self.lastMouseDeltaY = 0.0
	self.isInitialized = true
end

function FlightAimState:ApplyMouseDelta(dx, dy, sensitivityDegPerPixel, maxPitchUpDeg, maxPitchDownDeg)
	self.lastMouseDeltaX = dx
	self.lastMouseDeltaY = dy
	
	local sensRad = math.rad(sensitivityDegPerPixel or 0.18)
	if math.abs(dx) > 0 then
		-- dx > 0 (mouse derecha) -> yaw disminuye (giro a la derecha en Roblox)
		-- dx < 0 (mouse izquierda) -> yaw aumenta (giro a la izquierda en Roblox)
		self.playerAimYaw = (self.playerAimYaw - dx * sensRad) % (2 * math.pi)
	end
	
	if math.abs(dy) > 0 then
		local maxUp = math.rad(maxPitchUpDeg or 45.0)
		local maxDown = math.rad(maxPitchDownDeg or 60.0)
		-- dy < 0 (mouse arriba) -> pitch aumenta (subir morro)
		-- dy > 0 (mouse abajo) -> pitch disminuye (bajar morro)
		self.playerAimPitch = math.clamp(self.playerAimPitch - dy * sensRad, -maxDown, maxUp)
	end
end

function FlightAimState:SyncManualTurn(deltaYaw)
	if math.abs(deltaYaw) > 0.0001 then
		self.playerAimYaw = (self.playerAimYaw + deltaYaw) % (2 * math.pi)
	end
end

function FlightAimState:SoftAlignWithDragon(dragonYaw, alpha)
	local diff = (dragonYaw - self.playerAimYaw)
	diff = (diff + math.pi) % (2 * math.pi) - math.pi
	self.playerAimYaw = (self.playerAimYaw + diff * alpha) % (2 * math.pi)
end

return FlightAimState
