local dragon = workspace:WaitForChild("DragonModel", 10)
if not dragon then return end

print("=== DragonPivotDirectTest ===")
print("FullName:", dragon:GetFullName())
print("ClassName:", dragon.ClassName)
print("Pivot inicial:", tostring(dragon:GetPivot().Position))

local hasDragonMesh = dragon:FindFirstChild("DragonMesh", true) ~= nil
local hasHRP = dragon:FindFirstChild("HumanoidRootPart", true) ~= nil
local hrp = dragon:FindFirstChild("HumanoidRootPart", true)
local hasMotor6D = false
if hrp then
    for _, d in ipairs(hrp:GetChildren()) do
        if d:IsA("Motor6D") then hasMotor6D = true break end
    end
end

print("Has DragonMesh:", hasDragonMesh)
print("Has HumanoidRootPart:", hasHRP)
print("Has Motor6D in HRP:", hasMotor6D)

print("BaseParts:")
for _, d in ipairs(dragon:GetDescendants()) do
    if d:IsA("BasePart") then
        print(string.format(" - %s | Pos: %s | Anchored: %s | CanCollide: %s",
            d.Name, tostring(d.Position), tostring(d.Anchored), tostring(d.CanCollide)))
    end
end

task.wait(3)

local before = dragon:GetPivot()
print("[DirectPivotTest] BEFORE:", tostring(before.Position))

dragon:PivotTo(before * CFrame.new(0, 0, -20))

task.wait(1)

local after = dragon:GetPivot()
print("[DirectPivotTest] AFTER:", tostring(after.Position))
print("[DirectPivotTest] DELTA:", (after.Position - before.Position).Magnitude)

local mesh = dragon:FindFirstChild("DragonMesh", true)
print("[DirectPivotTest] DragonMesh pos:", mesh and mesh:IsA("BasePart") and tostring(mesh.Position))
print("[DirectPivotTest] HRP pos:", hrp and hrp:IsA("BasePart") and tostring(hrp.Position))
