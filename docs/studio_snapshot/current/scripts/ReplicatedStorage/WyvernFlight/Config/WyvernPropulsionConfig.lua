-- WyvernPropulsionConfig.lua
-- Configuración de Propulsión Física Aislada (Fase 5A)

local WyvernPropulsionConfig = {
	-- Magnitud máxima de empuje (en Newtons)
	-- Masa del wyvern = 134.4 kg, Peso = 26,369.28 N
	-- MaxThrust = 20,000 N -> T/W_max = 0.758 (aceleración inicial máxima = 148.8 st/s^2)
	MAX_THRUST = 20000.0,

	-- Punto de aplicación: estrictamente en el Centro de Masa para r x F = 0
	THRUST_ATTACHMENT_OFFSET = Vector3.new(0, 0, 0),

	-- Paso de incremento/decremento para mandos de prueba
	THRUST_STEP = 0.05,

	-- Límite de aceleración de seguridad
	MIN_THRUST_PERCENT = 0.0,
	MAX_THRUST_PERCENT = 1.0,
}

return WyvernPropulsionConfig
