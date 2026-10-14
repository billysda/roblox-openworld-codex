local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ServerScriptService = game:GetService("ServerScriptService")

task.wait(2.0)

local player = Players:GetPlayers()[1]
if not player then return end
local char = player.Character or player.CharacterAdded:Wait()
local hum = char:WaitForChild("Humanoid", 5)

local dragon = Workspace:WaitForChild("DragonTierraRoblox", 5)
local hrp = dragon:WaitForChild("HumanoidRootPart", 5)
local seat = dragon:WaitForChild("DragonRiderSeat", 5)

-- Mount
seat:Sit(hum)
hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
hum:SetStateEnabled(Enum.HumanoidStateType.GettingUp, false)
task.wait(0.8)

local DragonTierraFlightService = require(ServerScriptService.DragonTierra.Server.Flight.DragonTierraFlightService)
local svc = DragonTierraFlightService.getInstance()
local controller = svc.Controller

-- Trigger Takeoff via active service
controller:RequestToggle()

local initialPos = hrp.Position
local log = {
    InitialPosition = tostring(initialPos),
    TakeoffState = controller.State,
    Samples = {}
}

-- Wait for takeoff to finish and transition to Flying (1.2s)
task.wait(1.2)
log.StateAfterTakeoff = controller.State
log.AnchoredInFlight = hrp.Anchored
log.AssemblyMassInFlight = hrp.AssemblyMass

-- Apply forward W input
controller:UpdateInput({
    moveVector = Vector2.new(0, 1), -- W
    climb = 0,
    boost = false,
    cameraLook = Vector3.new(1, 0, 0) -- Along +X
})

-- Sample position every 0.4s for 2.4 seconds
for i = 1, 6 do
    task.wait(0.4)
    table.insert(log.Samples, {
        elapsed = i * 0.4,
        State = controller.State,
        Pos = tostring(hrp.Position),
        AsmVel = tostring(hrp.AssemblyLinearVelocity),
        Delta = (hrp.Position - initialPos).Magnitude
    })
end

local finalFlightPos = hrp.Position
log.FlightFinalPosition = tostring(finalFlightPos)
log.TotalFlightDisplacement = (finalFlightPos - initialPos).Magnitude
log.HasMovedPhysically = (finalFlightPos - initialPos).Magnitude > 20.0

-- Land
controller:RequestToggle()
log.LandingState = controller.State

task.wait(3.5)
log.FinalGroundedState = controller.State
log.FinalAnchored = hrp.Anchored
log.FinalAssemblyVelocity = tostring(hrp.AssemblyLinearVelocity)
log.FinalGroundedPosition = tostring(hrp.Position)

local val = Instance.new("StringValue")
val.Name = "SystemFlightTravelTestResults"
val.Value = HttpService:JSONEncode(log)
val.Parent = Workspace
