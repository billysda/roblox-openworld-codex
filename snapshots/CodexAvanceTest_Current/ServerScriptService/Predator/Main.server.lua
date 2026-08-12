local Root = script.Parent
local M = Root:WaitForChild("M")

local PredatorCfg = require(M:WaitForChild("PredatorCfg"))
local CaptureService = require(M:WaitForChild("CaptureService"))
local PredatorService = require(M:WaitForChild("PredatorService"))

if not PredatorCfg.Enabled then
	print("[Predator] Sistema desactivado por configuración")
	return
end

local captureService = CaptureService.new()
local predatorService = PredatorService.new(PredatorCfg, captureService)

predatorService:Start()

print("[Predator] Fox Predator v0 iniciado")
