-- WyvernAnimationAudit.client.lua -- diagnostico de SOLO LECTURA.
-- Copia aislada: colocar como LocalScript temporal en StarterPlayerScripts.
-- No crea AnimationTracks ni modifica el Animator, el rig o la locomocion.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local wyv = Workspace:WaitForChild("wyvernfbx",15)
local root = wyv and wyv:WaitForChild("DT_Root",10)
local controller = wyv and wyv:WaitForChild("AnimationController",10)
local animator = controller and controller:FindFirstChildOfClass("Animator")
if not (root and animator) then
    warn("[WYV-ANIM-AUDIT][CLIENT] Missing DT_Root or Animator")
    return
end
local folder=wyv:FindFirstChild("Animations")
local scripts=player:WaitForChild("PlayerScripts",10)
local function printSources()
    local group=scripts and scripts:FindFirstChild("WyvernFlightV2")
    if group then
        for _, s in ipairs(group:GetDescendants()) do
            if s:IsA("LocalScript") and (s.Name:find("Anim") or s.Name:find("Organic")) then
                print("[WYV-ANIM-AUDIT][CLIENT] source=",s:GetFullName(),"enabled=",not s.Disabled)
            end
        end
    end
    if not folder then
        warn("[WYV-ANIM-AUDIT][CLIENT] No Animations folder on wyvernfbx")
    else
        for _,name in ipairs({"Idle2","Run","FlightLoop"}) do
            local anim=folder:FindFirstChild(name)
            local id=anim and anim:IsA("Animation") and anim.AnimationId or "MISSING"
            local permanent=type(id)=="string" and id:match("^rbxassetid://%d+$")~=nil
            print("[WYV-ANIM-AUDIT][CLIENT] asset=",name,"id=",id,"permanentFormat=",permanent)
        end
    end
end
printSources()
local elapsed=0
RunService.Heartbeat:Connect(function(dt)
    elapsed+=dt
    if elapsed < 0.5 then return end
    elapsed=0
    local state=root:GetAttribute("Wyvern_MotionState")
    local tracks=animator:GetPlayingAnimationTracks()
    print("[WYV-ANIM-AUDIT][CLIENT] motion=",state,
        "serverSelection=",root:GetAttribute("Wyvern_ServerAnimation"),
        "playingCount=",#tracks,"groundSpeed=",root:GetAttribute("Wyvern_GroundSpeed"))
    for _,t in ipairs(tracks) do
        print("[WYV-ANIM-AUDIT][CLIENT][TRACK]",t.Name,
            "id=", t.Animation and t.Animation.AnimationId or "?",
            "playing=",t.IsPlaying, "length=",t.Length,
            "time=",t.TimePosition,"speed=",t.Speed,
            "weight=",t.WeightCurrent,"priority=",t.Priority)
    end
end)
