-- WyvernAnimationAudit.server.lua -- SOLO LECTURA.
-- Colocar temporalmente en ServerScriptService de copia aislada.
local Workspace=game:GetService("Workspace")
local SSS=game:GetService("ServerScriptService")
local wyv=Workspace:WaitForChild("wyvernfbx",15)
local root=wyv and wyv:WaitForChild("DT_Root",10)
local ctrl=wyv and wyv:WaitForChild("AnimationController",10)
local animator=ctrl and ctrl:FindFirstChildOfClass("Animator")
if not (root and animator) then
    warn("[WYV-ANIM-AUDIT][SERVER] Missing DT_Root or Animator")
    return
end
local folder=wyv:FindFirstChild("Animations")
if folder then
    for _,name in ipairs({"Idle2","Run","FlightLoop"}) do
        local anim=folder:FindFirstChild(name)
        local id=anim and anim:IsA("Animation") and anim.AnimationId or "MISSING"
        print("[WYV-ANIM-AUDIT][SERVER] asset=",name,"id=",id)
    end
else
    warn("[WYV-ANIM-AUDIT][SERVER] Animations folder is absent")
end
local scripts=SSS:FindFirstChild("WyvernFlightV2")
if scripts then
    local serverScript=scripts:FindFirstChild("FlightAnimationServerV022")
    print("[WYV-ANIM-AUDIT][SERVER] FlightAnimationServerV022=",
        serverScript and serverScript:GetFullName() or "MISSING",
        "enabled=",serverScript and not serverScript.Disabled)
end
local function emit()
    print("[WYV-ANIM-AUDIT][SERVER] motion=",root:GetAttribute("Wyvern_MotionState"),
        "serverSelection=",root:GetAttribute("Wyvern_ServerAnimation"),
        "playingCount=",#animator:GetPlayingAnimationTracks())
    for _,track in ipairs(animator:GetPlayingAnimationTracks()) do
        print("[WYV-ANIM-AUDIT][SERVER][TRACK]",track.Name,
            "id=",track.Animation and track.Animation.AnimationId or "?",
            "playing=",track.IsPlaying,"length=",track.Length,
            "speed=",track.Speed,"weight=",track.WeightCurrent)
    end
end
root:GetAttributeChangedSignal("Wyvern_MotionState"):Connect(emit)
task.spawn(function()
    while wyv.Parent do
        emit()
        task.wait(2)
    end
end)
