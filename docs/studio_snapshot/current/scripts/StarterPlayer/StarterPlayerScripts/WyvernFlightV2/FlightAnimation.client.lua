-- FlightAnimation.client.lua
-- Reproductor de Animación de Vuelo Existente para Wyvern (Fase R1)
-- Reproduce exclusivamente la animación importada original vía Animator. NO modifica Bones ni aplica cinemática procedural.

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local wyvernFlightV2 = ReplicatedStorage:WaitForChild("WyvernFlightV2")
local WyvernFlightConfig = require(wyvernFlightV2:WaitForChild("Config"):WaitForChild("WyvernFlightConfig"))

local function getWyvern()
	return Workspace:WaitForChild("wyvernfbx", 15) or Workspace:WaitForChild("DragonTierraRoblox", 15)
end

local function initFlightAnimation()
	local wyvern = getWyvern()
	if not wyvern then
		warn("[FlightAnimation V2] No se encontró wyvernfbx.")
		return
	end

	local animCtrl = wyvern:WaitForChild("AnimationController", 10)
	if not animCtrl then
		warn("[FlightAnimation V2] No se encontró AnimationController en wyvernfbx.")
		return
	end

	local animator = animCtrl:WaitForChild("Animator", 10)
	if not animator then
		warn("[FlightAnimation V2] No se encontró Animator en AnimationController.")
		return
	end

	-- Detener cualquier animación previa para evitar solapamientos
	for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
		track:Stop(0.1)
	end

	local anim = Instance.new("Animation")
	anim.Name = "WyvernFlightLoopAnim_V2"
	anim.AnimationId = WyvernFlightConfig.AnimationId

	local ok, track = pcall(function()
		return animator:LoadAnimation(anim)
	end)

	if ok and track then
		track.Priority = Enum.AnimationPriority.Movement
		track.Looped = true
		track:Play(0.2, 1.0, WyvernFlightConfig.AnimationSpeed)
		print(string.format("[FlightAnimation V2] Animación de vuelo iniciada correctamente (ID: %s, Duración: %.2fs).", WyvernFlightConfig.AnimationId, track.Length))
	else
		warn("[FlightAnimation V2] Error cargando AnimationTrack: " .. tostring(track))
	end
end

task.spawn(function()
	task.wait(0.5)
	initFlightAnimation()
end)
