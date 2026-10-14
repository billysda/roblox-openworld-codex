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
local lv = hrp:WaitForChild("LinearVelocity", 5)
local ao = hrp:WaitForChild("AlignOrientation", 5)

-- Unanchor dragon
for _, desc in ipairs(dragon:GetDescendants()) do
    if desc:IsA("BasePart") then
        desc.Anchored = false
    end
end
pcall(function() hrp:SetNetworkOwner(nil) end)

lv.Enabled = true
ao.Enabled = true
ao.CFrame = hrp.CFrame
lv.VectorVelocity = Vector3.new(50, 0, 0)

-- Test 1: Dragon alone (no player seated)
local init1 = hrp.Position
task.wait(1.5)
local d1 = (hrp.Position - init1).Magnitude
local vel1 = tostring(hrp.AssemblyLinearVelocity)

-- Reset
lv.VectorVelocity = Vector3.zero
dragon:PivotTo(CFrame.new(-124.18, 4.75, 120.37))
task.wait(0.2)

-- Test 2: Player seated via seat:Sit, hum.PlatformStand = true
seat:Sit(hum)
hum.PlatformStand = true
hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
pcall(function() hrp:SetNetworkOwner(nil) end)

lv.VectorVelocity = Vector3.new(50, 0, 0)
local init2 = hrp.Position
task.wait(1.5)
local d2 = (hrp.Position - init2).Magnitude
local vel2 = tostring(hrp.AssemblyLinearVelocity)

-- Reset
lv.VectorVelocity = Vector3.zero
dragon:PivotTo(CFrame.new(-124.18, 4.75, 120.37))
task.wait(0.2)

-- Test 3: Player seated via WeldConstraint (no SeatWeld), hum.PlatformStand = true, hum.EvaluateStateMachine = false
local sw = seat:FindFirstChildOfClass("Weld") or seat:FindFirstChild("SeatWeld")
if sw then sw:Destroy() end

local w = Instance.new("WeldConstraint")
w.Part0 = seat
w.Part1 = char.HumanoidRootPart
w.Parent = seat

hum.PlatformStand = true
pcall(function() hum.EvaluateStateMachine = false end)
pcall(function() hrp:SetNetworkOwner(nil) end)

lv.VectorVelocity = Vector3.new(50, 0, 0)
local init3 = hrp.Position
task.wait(1.5)
local d3 = (hrp.Position - init3).Magnitude
local vel3 = tostring(hrp.AssemblyLinearVelocity)

-- Re-anchor
lv.VectorVelocity = Vector3.zero
lv.Enabled = false
ao.Enabled = false
for _, desc in ipairs(dragon:GetDescendants()) do
    if desc:IsA("BasePart") then
        desc.Anchored = true
    end
end

local resObj = Instance.new("StringValue")
resObj.Name = "HumanoidPinTestResults"
resObj.Value = game:GetService("HttpService"):JSONEncode({
    Test1_NoPlayer_Displacement = d1,
    Test1_NoPlayer_Velocity = vel1,
    Test2_PlatformStandSit_Displacement = d2,
    Test2_PlatformStandSit_Velocity = vel2,
    Test3_NoStateMachine_Displacement = d3,
    Test3_NoStateMachine_Velocity = vel3
})
resObj.Parent = Workspace
