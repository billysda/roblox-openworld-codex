-- OrganicMotionConfigR42.lua
-- OpenWorld Codex | WyvernFlightV2 R4.2 (SOLO VISUAL, opt-in)
-- Valores iniciales: Antigravity debe calibrar ejes/signos observando el rig real.
-- Ninguno de estos campos altera velocidad/fisica/camara/inputs de R4.1.

return {
    Animation = {
        SlowMultiplier = 0.85,   -- Flight_Speed <= MinSpeed
        CruiseMultiplier = 1.00, -- Flight_Speed ~= CruiseSpeed
        FastMultiplier = 1.10,   -- Flight_Speed >= MaxSpeed (sin boost)
        BoostMultiplier = 1.20,  -- Flight_IsBoosting == true
        ResponseSeconds = 0.32,
        TrackSearchSeconds = 0.40,
    },

    Tail = {
        Names = {
            "Cola_1_076", "Cola_2_077", "Cola_3_078", "Cola_4_079",
            "Cola_5_080", "Cola_6_081", "Cola_7_082",
        },
        LocalYawAxis = Vector3.new(0, 1, 0),
        DirectionSign = -1,           -- calibrar con giro real izquierda/derecha
        TotalYawDegrees = 16.0,      -- distribuido entre 7 huesos (no 16 por hueso)
        Weights = {0.18, 0.17, 0.16, 0.15, 0.13, 0.12, 0.09},
        FollowSeconds = {0.14, 0.20, 0.27, 0.34, 0.42, 0.50, 0.58},
        SwayDegreesPerJoint = 0.42,  -- oscilacion ambiente muy tenue
        SwayFrequencyHz = 0.48,
        SwayPhaseRadiansPerJoint = 0.32,
    },

    Neck = {
        Names = {"Cuello_1_025", "Cuello_2_026", "Cuello_3_027"},
        LocalYawAxis = Vector3.new(0, 1, 0),
        DirectionSign = 1,           -- calibrar con rig; movimiento sutil
        TotalYawDegrees = 4.0,
        Weights = {0.30, 0.35, 0.35},
        ResponseSeconds = {0.23, 0.18, 0.14},
    },

    Head = {
        Name = "Cabeza_028",
        LocalYawAxis = Vector3.new(0, 1, 0),
        LocalPitchAxis = Vector3.new(1, 0, 0),
        YawSign = 1,
        PitchSign = 1,
        MaxYawDegrees = 1.6,
        MaxPitchDegrees = 0.7,
        ResponseSeconds = 0.13,
    },

    -- FlightController R4.1 publica Flight_HeadingDeltaPerSecond,
    -- que sirve como fuente de curvatura REAL (no solo tecla presionada).
    MaxMeasuredTurnRateDegPerSecond = 50.0,
}
