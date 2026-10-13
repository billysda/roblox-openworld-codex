local RunService = game:GetService("RunService")

-- Fase 4: Se ejecuta con prioridad "Last" para ocurrir DESPUÉS de las animaciones y del IK
RunService:BindToRenderStep("ActualizarAsientoCuello", Enum.RenderPriority.Last.Value, function()

	local dragon = workspace:FindFirstChild("DragonModel")
	if not dragon then return end

	-- Buscamos tu asiento con el nombre exacto sin la "t"
	local seat = dragon:FindFirstChild("DragonRiderSea")
	local seatWeld = seat and seat:FindFirstChild("DragonRiderSeaWeld")
	local rootPart = dragon:FindFirstChild("HumanoidRootPart")

	-- Buscamos específicamente el hueso Bip01-Neck2_10
	local mesh = dragon:FindFirstChild("DragonMesh")
	local neckBone = mesh and mesh:FindFirstChild("Bip01-Neck2_10", true)

	if seat and seatWeld and rootPart and neckBone then

		-- 1. Enderezamos al personaje (corrige los ejes de Blender)
		local CORRECCION_ROTACION = CFrame.Angles(math.rad(-90), 0, 0)

		-- 2. Ajuste de posición: (Izquierda/Derecha, Adelante/Atrás, Arriba/Abajo)
		-- Ajusta estos números si quedas muy hundido o flotando
		local SADDLE_OFFSET = CFrame.new(0, -1.5, -1.0) 

		-- 3. Leemos la posición final invencible del hueso en este milisegundo exacto
		local posicionFinalHueso = neckBone.TransformedWorldCFrame * SADDLE_OFFSET * CORRECCION_ROTACION

		-- 4. Actualizamos la soldadura para que siga al cuello
		seatWeld.C0 = rootPart.CFrame:Inverse() * posicionFinalHueso
	end
end)