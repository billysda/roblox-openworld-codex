-- OrganicMotionConfigR42.lua
-- OpenWorld Codex | WyvernFlightV2 R4.2 (SOLO VISUAL, opt-in)
-- PERFIL EXTREMO / MAX: movimientos intencionalmente exagerados para evaluar en Play.
-- Antigravity confirmo ejes del rig en Issue #52; revisar clipping en giros fuertes.
-- Ninguno de estos campos altera velocidad/fisica/camara/inputs de R4.1.

return {
    Animation = {
        SlowMultiplier = 0.65,   -- frenado: fuerte contraste respecto a crucero
        CruiseMultiplier = 1.00, -- Flight_Speed ~= CruiseSpeed
        FastMultiplier = 1.45,   -- aceleracion maxima sin boost
        BoostMultiplier = 1.80,  -- boost: aleteo marcadamente acelerado
        ResponseSeconds = 0.20,
        TrackSearchSeconds = 0.40,
    },

    Tail = {
        Names = {
            "Cola_1_076", "Cola_2_077", "Cola_3_078", "Cola_4_079",
            "Cola_5_080", "Cola_6_081", "Cola_7_082",
        },
        LocalYawAxis = Vector3.new(0, 1, 0),
        DirectionSign = -1,           -- confirmado en giros por Antigravity; cola contraria al giro
        TotalYawDegrees = 90.0,      -- MAX total repartido entre 7 huesos; NO 90 por hueso
        Weights = {0.18, 0.17, 0.16, 0.15, 0.13, 0.12, 0.09},
        FollowSeconds = {0.07, 0.12, 0.18, 0.25, 0.32, 0.40, 0.50},
        SwayDegreesPerJoint = 3.0,   -- oscilacion ambiente exagerada, creciente hacia la punta
        SwayFrequencyHz = 0.62,
        SwayPhaseRadiansPerJoint = 0.42,
    },

    Neck = {
        Names = {"Cuello_1_025", "Cuello_2_026", "Cuello_3_027"},
        LocalYawAxis = Vector3.new(0, 1, 0),
        DirectionSign = 1,           -- anticipacion fuerte del cuello
        TotalYawDegrees = 25.0,       -- grados acumulados entre los tres huesos de cuello
        Weights = {0.30, 0.35, 0.35},
        ResponseSeconds = {0.13, 0.10, 0.07},
    },

    Head = {
        Name = "Cabeza_028",
        LocalYawAxis = Vector3.new(0, 1, 0),
        LocalPitchAxis = Vector3.new(1, 0, 0),
        YawSign = 1,
        PitchSign = 1,
        MaxYawDegrees = 12.0,
        MaxPitchDegrees = 6.0,
        ResponseSeconds = 0.06,
    },

    -- FlightController R4.1 publica Flight_HeadingDeltaPerSecond,
    -- que sirve como fuente de curvatura REAL (no solo tecla presionada).
    MaxMeasuredTurnRateDegPerSecond = 8.0, -- 6-8 deg/s ya produce fuerte flexion de cola
}
