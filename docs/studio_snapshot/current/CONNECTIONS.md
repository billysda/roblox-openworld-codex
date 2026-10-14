# Relaciones y Conexiones del DataModel

Extracción formal de Remotes, Constraints, Welds, Motor6Ds, Attachments y referencias entre instancias.

## 1. RemoteEvents y RemoteFunctions en ReplicatedStorage

| Nombre | Clase | Ruta DataModel |
|---|---|---|
| `Whistle` | `RemoteEvent` | `ReplicatedStorage#root/PastureRemote#1/Whistle#1` |
| `RequestStats` | `RemoteEvent` | `ReplicatedStorage#root/PastureRemote#1/RequestStats#2` |
| `StatsResponse` | `RemoteEvent` | `ReplicatedStorage#root/PastureRemote#1/StatsResponse#3` |
| `RequestHomeInfo` | `RemoteEvent` | `ReplicatedStorage#root/HomesteadRemote#2/RequestHomeInfo#1` |
| `HomeInfo` | `RemoteEvent` | `ReplicatedStorage#root/HomesteadRemote#2/HomeInfo#2` |
| `DropChicken` | `RemoteEvent` | `ReplicatedStorage#root/HomesteadRemote#2/DropChicken#3` |
| `WyvernTestCommand` | `RemoteEvent` | `ReplicatedStorage#root/WyvernFlight#3/Remotes#3/WyvernTestCommand#1` |
| `FlightInput` | `RemoteEvent` | `ReplicatedStorage#root/WyvernFlightV2#4/Remotes#3/FlightInput#1` |
| `ResetCommand` | `RemoteEvent` | `ReplicatedStorage#root/WyvernFlightV2#4/Remotes#3/ResetCommand#2` |

## 2. Constraints, Joints y Ensambles en Workspace

| Instancia | Clase | Part0 / Adornee | Part1 / Referencia | Ruta |
|---|---|---|---|---|
| `SeatAttachment` | `Attachment` | `-` | `-` | `Workspace#root/Terrain#14/DragonRiderSea#1/SeatAttachment#2` |
| `Motor6D` | `Motor6D` | `Workspace.Gallina.HumanodiRootPart` | `Workspace.Gallina.MeshGallina` | `Workspace#root/Gallina#16/HumanodiRootPart#5/Motor6D#1` |
| `Motor6D` | `Motor6D` | `Workspace.WorkspaceGallinaReference.HumanodiRootPart` | `Workspace.WorkspaceGallinaReference.MeshGallina` | `Workspace#root/WorkspaceGallinaReference#17/HumanodiRootPart#2/Motor6D#1` |
| `Motor6D` | `Motor6D` | `Workspace.WorkspaceGallinaReference.HumanodiRootPart` | `Workspace.WorkspaceGallinaReference.MeshGallina` | `Workspace#root/WorkspaceGallinaReference#18/HumanodiRootPart#2/Motor6D#1` |
| `NeckRigAttachment` | `Attachment` | `-` | `-` | `Workspace#root/Rig#19/Head#1/NeckRigAttachment#5` |
| `NeckBallSocket` | `BallSocketConstraint` | `Workspace.Rig.UpperTorso.NeckRigAttachment` | `Workspace.Rig.Head.NeckRigAttachment` | `Workspace#root/Rig#19/Head#1/NeckBallSocket#6` |
| `HatAttachment` | `Attachment` | `-` | `-` | `Workspace#root/Rig#19/Head#1/HatAttachment#9` |
| `FaceFrontAttachment` | `Attachment` | `-` | `-` | `Workspace#root/Rig#19/Head#1/FaceFrontAttachment#11` |
| `FaceCenterAttachment` | `Attachment` | `-` | `-` | `Workspace#root/Rig#19/Head#1/FaceCenterAttachment#12` |
| `HairAttachment` | `Attachment` | `-` | `-` | `Workspace#root/Rig#19/Head#1/HairAttachment#13` |
| `RightKneeBallSocket` | `BallSocketConstraint` | `Workspace.Rig.RightUpperLeg.RightKneeRigAttachment` | `Workspace.Rig.RightLowerLeg.RightKneeRigAttachment` | `Workspace#root/Rig#19/RightLowerLeg#2/RightKneeBallSocket#1` |
| `RightAnkleRigAttachment` | `Attachment` | `-` | `-` | `Workspace#root/Rig#19/RightLowerLeg#2/RightAnkleRigAttachment#5` |
| `RightKneeRigAttachment` | `Attachment` | `-` | `-` | `Workspace#root/Rig#19/RightLowerLeg#2/RightKneeRigAttachment#7` |
| `RightWristRigAttachment` | `Attachment` | `-` | `-` | `Workspace#root/Rig#19/RightHand#3/RightWristRigAttachment#2` |
| `RightWristBallSocket` | `BallSocketConstraint` | `Workspace.Rig.RightLowerArm.RightWristRigAttachment` | `Workspace.Rig.RightHand.RightWristRigAttachment` | `Workspace#root/Rig#19/RightHand#3/RightWristBallSocket#4` |
| `RightGripAttachment` | `Attachment` | `-` | `-` | `Workspace#root/Rig#19/RightHand#3/RightGripAttachment#6` |
| `RightKneeRigAttachment` | `Attachment` | `-` | `-` | `Workspace#root/Rig#19/RightUpperLeg#4/RightKneeRigAttachment#1` |
| `RightHipBallSocket` | `BallSocketConstraint` | `Workspace.Rig.LowerTorso.RightHipRigAttachment` | `Workspace.Rig.RightUpperLeg.RightHipRigAttachment` | `Workspace#root/Rig#19/RightUpperLeg#4/RightHipBallSocket#2` |
| `RightHipRigAttachment` | `Attachment` | `-` | `-` | `Workspace#root/Rig#19/RightUpperLeg#4/RightHipRigAttachment#8` |
| `RootRigAttachment` | `Attachment` | `-` | `-` | `Workspace#root/Rig#19/HumanoidRootPart#6/RootRigAttachment#1` |
| `RootAttachment` | `Attachment` | `-` | `-` | `Workspace#root/Rig#19/HumanoidRootPart#6/RootAttachment#2` |
| `RightElbowRigAttachment` | `Attachment` | `-` | `-` | `Workspace#root/Rig#19/RightLowerArm#7/RightElbowRigAttachment#1` |
| `RightWristRigAttachment` | `Attachment` | `-` | `-` | `Workspace#root/Rig#19/RightLowerArm#7/RightWristRigAttachment#2` |
| `RightElbowBallSocket` | `BallSocketConstraint` | `Workspace.Rig.RightUpperArm.RightElbowRigAttachment` | `Workspace.Rig.RightLowerArm.RightElbowRigAttachment` | `Workspace#root/Rig#19/RightLowerArm#7/RightElbowBallSocket#4` |
| `HairAttachment` | `Attachment` | `-` | `-` | `Workspace#root/Rig#19/Pal Hair#8/Handle#1/HairAttachment#2` |
| `LeftAnkleRigAttachment` | `Attachment` | `-` | `-` | `Workspace#root/Rig#19/LeftFoot#9/LeftAnkleRigAttachment#2` |
| `LeftFootAttachment` | `Attachment` | `-` | `-` | `Workspace#root/Rig#19/LeftFoot#9/LeftFootAttachment#5` |
| `LeftAnkleBallSocket` | `BallSocketConstraint` | `Workspace.Rig.LeftLowerLeg.LeftAnkleRigAttachment` | `Workspace.Rig.LeftFoot.LeftAnkleRigAttachment` | `Workspace#root/Rig#19/LeftFoot#9/LeftAnkleBallSocket#7` |
| `RightShoulderAttachment` | `Attachment` | `-` | `-` | `Workspace#root/Rig#19/RightUpperArm#10/RightShoulderAttachment#1` |
| `RightShoulderRigAttachment` | `Attachment` | `-` | `-` | `Workspace#root/Rig#19/RightUpperArm#10/RightShoulderRigAttachment#3` |
| `JointRotation` | `Attachment` | `-` | `-` | `Workspace#root/Rig#19/RightUpperArm#10/RightShoulderRigAttachment#3/JointRotation#1` |
| `RightShoulderBallSocket` | `BallSocketConstraint` | `Workspace.Rig.UpperTorso.RightShoulderRigAttachment.JointRotation` | `Workspace.Rig.RightUpperArm.RightShoulderRigAttachment.JointRotation` | `Workspace#root/Rig#19/RightUpperArm#10/RightShoulderBallSocket#5` |
| `RightElbowRigAttachment` | `Attachment` | `-` | `-` | `Workspace#root/Rig#19/RightUpperArm#10/RightElbowRigAttachment#6` |
| `LeftKneeRigAttachment` | `Attachment` | `-` | `-` | `Workspace#root/Rig#19/LeftLowerLeg#11/LeftKneeRigAttachment#2` |
| `LeftAnkleRigAttachment` | `Attachment` | `-` | `-` | `Workspace#root/Rig#19/LeftLowerLeg#11/LeftAnkleRigAttachment#3` |
| `LeftKneeBallSocket` | `BallSocketConstraint` | `Workspace.Rig.LeftUpperLeg.LeftKneeRigAttachment` | `Workspace.Rig.LeftLowerLeg.LeftKneeRigAttachment` | `Workspace#root/Rig#19/LeftLowerLeg#11/LeftKneeBallSocket#6` |
| `WaistFrontAttachment` | `Attachment` | `-` | `-` | `Workspace#root/Rig#19/LowerTorso#13/WaistFrontAttachment#7` |
| `WaistBackAttachment` | `Attachment` | `-` | `-` | `Workspace#root/Rig#19/LowerTorso#13/WaistBackAttachment#8` |
| `WaistRigAttachment` | `Attachment` | `-` | `-` | `Workspace#root/Rig#19/LowerTorso#13/WaistRigAttachment#9` |
| `LeftHipRigAttachment` | `Attachment` | `-` | `-` | `Workspace#root/Rig#19/LowerTorso#13/LeftHipRigAttachment#10` |
| `RightHipRigAttachment` | `Attachment` | `-` | `-` | `Workspace#root/Rig#19/LowerTorso#13/RightHipRigAttachment#12` |
| `WaistCenterAttachment` | `Attachment` | `-` | `-` | `Workspace#root/Rig#19/LowerTorso#13/WaistCenterAttachment#14` |
| `RootRigAttachment` | `Attachment` | `-` | `-` | `Workspace#root/Rig#19/LowerTorso#13/RootRigAttachment#15` |
| `LeftKneeRigAttachment` | `Attachment` | `-` | `-` | `Workspace#root/Rig#19/LeftUpperLeg#14/LeftKneeRigAttachment#1` |
| `LeftHipRigAttachment` | `Attachment` | `-` | `-` | `Workspace#root/Rig#19/LeftUpperLeg#14/LeftHipRigAttachment#3` |
| `LeftHipBallSocket` | `BallSocketConstraint` | `Workspace.Rig.LowerTorso.LeftHipRigAttachment` | `Workspace.Rig.LeftUpperLeg.LeftHipRigAttachment` | `Workspace#root/Rig#19/LeftUpperLeg#14/LeftHipBallSocket#9` |
| `RightShoulderRigAttachment` | `Attachment` | `-` | `-` | `Workspace#root/Rig#19/UpperTorso#15/RightShoulderRigAttachment#1` |
| `JointRotation` | `Attachment` | `-` | `-` | `Workspace#root/Rig#19/UpperTorso#15/RightShoulderRigAttachment#1/JointRotation#2` |
| `BodyFrontAttachment` | `Attachment` | `-` | `-` | `Workspace#root/Rig#19/UpperTorso#15/BodyFrontAttachment#2` |
| `WaistBallSocket` | `BallSocketConstraint` | `Workspace.Rig.LowerTorso.WaistRigAttachment` | `Workspace.Rig.UpperTorso.WaistRigAttachment` | `Workspace#root/Rig#19/UpperTorso#15/WaistBallSocket#5` |
| `WaistRigAttachment` | `Attachment` | `-` | `-` | `Workspace#root/Rig#19/UpperTorso#15/WaistRigAttachment#8` |
| `NeckRigAttachment` | `Attachment` | `-` | `-` | `Workspace#root/Rig#19/UpperTorso#15/NeckRigAttachment#11` |
| `LeftShoulderRigAttachment` | `Attachment` | `-` | `-` | `Workspace#root/Rig#19/UpperTorso#15/LeftShoulderRigAttachment#13` |
| `JointRotation` | `Attachment` | `-` | `-` | `Workspace#root/Rig#19/UpperTorso#15/LeftShoulderRigAttachment#13/JointRotation#1` |
| `BodyBackAttachment` | `Attachment` | `-` | `-` | `Workspace#root/Rig#19/UpperTorso#15/BodyBackAttachment#18` |
| `LeftCollarAttachment` | `Attachment` | `-` | `-` | `Workspace#root/Rig#19/UpperTorso#15/LeftCollarAttachment#19` |
| `NeckAttachment` | `Attachment` | `-` | `-` | `Workspace#root/Rig#19/UpperTorso#15/NeckAttachment#20` |
| `RightCollarAttachment` | `Attachment` | `-` | `-` | `Workspace#root/Rig#19/UpperTorso#15/RightCollarAttachment#21` |
| `LeftGripAttachment` | `Attachment` | `-` | `-` | `Workspace#root/Rig#19/LeftHand#16/LeftGripAttachment#1` |
| `LeftWristRigAttachment` | `Attachment` | `-` | `-` | `Workspace#root/Rig#19/LeftHand#16/LeftWristRigAttachment#2` |
| `LeftWristBallSocket` | `BallSocketConstraint` | `Workspace.Rig.LeftLowerArm.LeftWristRigAttachment` | `Workspace.Rig.LeftHand.LeftWristRigAttachment` | `Workspace#root/Rig#19/LeftHand#16/LeftWristBallSocket#6` |
| `LeftWristRigAttachment` | `Attachment` | `-` | `-` | `Workspace#root/Rig#19/LeftLowerArm#20/LeftWristRigAttachment#1` |
| `LeftElbowRigAttachment` | `Attachment` | `-` | `-` | `Workspace#root/Rig#19/LeftLowerArm#20/LeftElbowRigAttachment#2` |
| `LeftElbowBallSocket` | `BallSocketConstraint` | `Workspace.Rig.LeftUpperArm.LeftElbowRigAttachment` | `Workspace.Rig.LeftLowerArm.LeftElbowRigAttachment` | `Workspace#root/Rig#19/LeftLowerArm#20/LeftElbowBallSocket#6` |
| `LeftShoulderRigAttachment` | `Attachment` | `-` | `-` | `Workspace#root/Rig#19/LeftUpperArm#21/LeftShoulderRigAttachment#3` |
| `JointRotation` | `Attachment` | `-` | `-` | `Workspace#root/Rig#19/LeftUpperArm#21/LeftShoulderRigAttachment#3/JointRotation#1` |
| `LeftElbowRigAttachment` | `Attachment` | `-` | `-` | `Workspace#root/Rig#19/LeftUpperArm#21/LeftElbowRigAttachment#6` |
| `LeftShoulderBallSocket` | `BallSocketConstraint` | `Workspace.Rig.UpperTorso.LeftShoulderRigAttachment.JointRotation` | `Workspace.Rig.LeftUpperArm.LeftShoulderRigAttachment.JointRotation` | `Workspace#root/Rig#19/LeftUpperArm#21/LeftShoulderBallSocket#7` |
| `LeftShoulderAttachment` | `Attachment` | `-` | `-` | `Workspace#root/Rig#19/LeftUpperArm#21/LeftShoulderAttachment#8` |
| `RightAnkleBallSocket` | `BallSocketConstraint` | `Workspace.Rig.RightLowerLeg.RightAnkleRigAttachment` | `Workspace.Rig.RightFoot.RightAnkleRigAttachment` | `Workspace#root/Rig#19/RightFoot#22/RightAnkleBallSocket#1` |
| `RightFootAttachment` | `Attachment` | `-` | `-` | `Workspace#root/Rig#19/RightFoot#22/RightFootAttachment#3` |
| `RightAnkleRigAttachment` | `Attachment` | `-` | `-` | `Workspace#root/Rig#19/RightFoot#22/RightAnkleRigAttachment#4` |
| `FaceFrontAttachment` | `Attachment` | `-` | `-` | `Workspace#root/StarterCharacter#20/Accessory (glasses meshAccessory)#1/Handle#1/FaceFrontAttachment#1` |
| `LeftGripAttachment` | `Attachment` | `-` | `-` | `Workspace#root/StarterCharacter#20/LeftHand#2/LeftGripAttachment#2` |
| `LeftWristRigAttachment` | `Attachment` | `-` | `-` | `Workspace#root/StarterCharacter#20/LeftHand#2/LeftWristRigAttachment#3` |
| `LeftWristBallSocket` | `BallSocketConstraint` | `Workspace.StarterCharacter.LeftLowerArm.LeftWristRigAttachment` | `Workspace.StarterCharacter.LeftHand.LeftWristRigAttachment` | `Workspace#root/StarterCharacter#20/LeftHand#2/LeftWristBallSocket#7` |
| `NeckAttachment` | `Attachment` | `-` | `-` | `Workspace#root/StarterCharacter#20/MeshPartAccessory#3/Handle#1/NeckAttachment#1` |
| `RightAnkleBallSocket` | `BallSocketConstraint` | `Workspace.StarterCharacter.RightLowerLeg.RightAnkleRigAttachment` | `Workspace.StarterCharacter.RightFoot.RightAnkleRigAttachment` | `Workspace#root/StarterCharacter#20/RightFoot#4/RightAnkleBallSocket#2` |
| `RightAnkleRigAttachment` | `Attachment` | `-` | `-` | `Workspace#root/StarterCharacter#20/RightFoot#4/RightAnkleRigAttachment#6` |
| `RightFootAttachment` | `Attachment` | `-` | `-` | `Workspace#root/StarterCharacter#20/RightFoot#4/RightFootAttachment#7` |
| `WaistCenterAttachment` | `Attachment` | `-` | `-` | `Workspace#root/StarterCharacter#20/Left leg spikes grey#6/Handle#1/WaistCenterAttachment#3` |
| `LeftShoulderBallSocket` | `BallSocketConstraint` | `Workspace.StarterCharacter.UpperTorso.LeftShoulderRigAttachment.JointRotation` | `Workspace.StarterCharacter.LeftUpperArm.LeftShoulderRigAttachment.JointRotation` | `Workspace#root/StarterCharacter#20/LeftUpperArm#7/LeftShoulderBallSocket#1` |
| `LeftShoulderRigAttachment` | `Attachment` | `-` | `-` | `Workspace#root/StarterCharacter#20/LeftUpperArm#7/LeftShoulderRigAttachment#2` |
| `JointRotation` | `Attachment` | `-` | `-` | `Workspace#root/StarterCharacter#20/LeftUpperArm#7/LeftShoulderRigAttachment#2/JointRotation#1` |
| `LeftElbowRigAttachment` | `Attachment` | `-` | `-` | `Workspace#root/StarterCharacter#20/LeftUpperArm#7/LeftElbowRigAttachment#4` |
| `LeftShoulderAttachment` | `Attachment` | `-` | `-` | `Workspace#root/StarterCharacter#20/LeftUpperArm#7/LeftShoulderAttachment#6` |
| `WaistCenterAttachment` | `Attachment` | `-` | `-` | `Workspace#root/StarterCharacter#20/Accessory (Karambit)#9/Handle#1/WaistCenterAttachment#2` |
| `RightGripAttachment` | `Attachment` | `-` | `-` | `Workspace#root/StarterCharacter#20/RightHand#11/RightGripAttachment#5` |
| `RightWristRigAttachment` | `Attachment` | `-` | `-` | `Workspace#root/StarterCharacter#20/RightHand#11/RightWristRigAttachment#6` |
| `RightWristBallSocket` | `BallSocketConstraint` | `Workspace.StarterCharacter.RightLowerArm.RightWristRigAttachment` | `Workspace.StarterCharacter.RightHand.RightWristRigAttachment` | `Workspace#root/StarterCharacter#20/RightHand#11/RightWristBallSocket#7` |
| `RightHipBallSocket` | `BallSocketConstraint` | `Workspace.StarterCharacter.LowerTorso.RightHipRigAttachment` | `Workspace.StarterCharacter.RightUpperLeg.RightHipRigAttachment` | `Workspace#root/StarterCharacter#20/RightUpperLeg#12/RightHipBallSocket#2` |
| `RightHipRigAttachment` | `Attachment` | `-` | `-` | `Workspace#root/StarterCharacter#20/RightUpperLeg#12/RightHipRigAttachment#7` |
| `RightKneeRigAttachment` | `Attachment` | `-` | `-` | `Workspace#root/StarterCharacter#20/RightUpperLeg#12/RightKneeRigAttachment#8` |
| `HairAttachment` | `Attachment` | `-` | `-` | `Workspace#root/StarterCharacter#20/Accessory (Emo)#13/Handle#1/HairAttachment#2` |
| `RootRigAttachment` | `Attachment` | `-` | `-` | `Workspace#root/StarterCharacter#20/HumanoidRootPart#14/RootRigAttachment#1` |
| `RootAttachment` | `Attachment` | `-` | `-` | `Workspace#root/StarterCharacter#20/HumanoidRootPart#14/RootAttachment#3` |
| `NeckRigAttachment` | `Attachment` | `-` | `-` | `Workspace#root/StarterCharacter#20/Head#15/NeckRigAttachment#7` |
| `HatAttachment` | `Attachment` | `-` | `-` | `Workspace#root/StarterCharacter#20/Head#15/HatAttachment#9` |
| `FaceFrontAttachment` | `Attachment` | `-` | `-` | `Workspace#root/StarterCharacter#20/Head#15/FaceFrontAttachment#11` |
| `NeckBallSocket` | `BallSocketConstraint` | `Workspace.StarterCharacter.UpperTorso.NeckRigAttachment` | `Workspace.StarterCharacter.Head.NeckRigAttachment` | `Workspace#root/StarterCharacter#20/Head#15/NeckBallSocket#12` |
| `HairAttachment` | `Attachment` | `-` | `-` | `Workspace#root/StarterCharacter#20/Head#15/HairAttachment#13` |
| `FaceCenterAttachment` | `Attachment` | `-` | `-` | `Workspace#root/StarterCharacter#20/Head#15/FaceCenterAttachment#14` |
| `RightKneeBallSocket` | `BallSocketConstraint` | `Workspace.StarterCharacter.RightUpperLeg.RightKneeRigAttachment` | `Workspace.StarterCharacter.RightLowerLeg.RightKneeRigAttachment` | `Workspace#root/StarterCharacter#20/RightLowerLeg#16/RightKneeBallSocket#2` |
| `RightKneeRigAttachment` | `Attachment` | `-` | `-` | `Workspace#root/StarterCharacter#20/RightLowerLeg#16/RightKneeRigAttachment#6` |
| `RightAnkleRigAttachment` | `Attachment` | `-` | `-` | `Workspace#root/StarterCharacter#20/RightLowerLeg#16/RightAnkleRigAttachment#7` |
| `RightShoulderRigAttachment` | `Attachment` | `-` | `-` | `Workspace#root/StarterCharacter#20/RightUpperArm#17/RightShoulderRigAttachment#3` |
| `JointRotation` | `Attachment` | `-` | `-` | `Workspace#root/StarterCharacter#20/RightUpperArm#17/RightShoulderRigAttachment#3/JointRotation#2` |
| `RightShoulderAttachment` | `Attachment` | `-` | `-` | `Workspace#root/StarterCharacter#20/RightUpperArm#17/RightShoulderAttachment#4` |
| `RightElbowRigAttachment` | `Attachment` | `-` | `-` | `Workspace#root/StarterCharacter#20/RightUpperArm#17/RightElbowRigAttachment#5` |
| `RightShoulderBallSocket` | `BallSocketConstraint` | `Workspace.StarterCharacter.UpperTorso.RightShoulderRigAttachment.JointRotation` | `Workspace.StarterCharacter.RightUpperArm.RightShoulderRigAttachment.JointRotation` | `Workspace#root/StarterCharacter#20/RightUpperArm#17/RightShoulderBallSocket#7` |
| `LeftKneeBallSocket` | `BallSocketConstraint` | `Workspace.StarterCharacter.LeftUpperLeg.LeftKneeRigAttachment` | `Workspace.StarterCharacter.LeftLowerLeg.LeftKneeRigAttachment` | `Workspace#root/StarterCharacter#20/LeftLowerLeg#18/LeftKneeBallSocket#3` |
| `LeftKneeRigAttachment` | `Attachment` | `-` | `-` | `Workspace#root/StarterCharacter#20/LeftLowerLeg#18/LeftKneeRigAttachment#4` |
| `LeftAnkleRigAttachment` | `Attachment` | `-` | `-` | `Workspace#root/StarterCharacter#20/LeftLowerLeg#18/LeftAnkleRigAttachment#5` |
| `RightElbowRigAttachment` | `Attachment` | `-` | `-` | `Workspace#root/StarterCharacter#20/RightLowerArm#21/RightElbowRigAttachment#5` |
| `RightWristRigAttachment` | `Attachment` | `-` | `-` | `Workspace#root/StarterCharacter#20/RightLowerArm#21/RightWristRigAttachment#6` |
| `RightElbowBallSocket` | `BallSocketConstraint` | `Workspace.StarterCharacter.RightUpperArm.RightElbowRigAttachment` | `Workspace.StarterCharacter.RightLowerArm.RightElbowRigAttachment` | `Workspace#root/StarterCharacter#20/RightLowerArm#21/RightElbowBallSocket#7` |
| `LeftAnkleBallSocket` | `BallSocketConstraint` | `Workspace.StarterCharacter.LeftLowerLeg.LeftAnkleRigAttachment` | `Workspace.StarterCharacter.LeftFoot.LeftAnkleRigAttachment` | `Workspace#root/StarterCharacter#20/LeftFoot#22/LeftAnkleBallSocket#2` |
| `LeftFootAttachment` | `Attachment` | `-` | `-` | `Workspace#root/StarterCharacter#20/LeftFoot#22/LeftFootAttachment#5` |
| `LeftAnkleRigAttachment` | `Attachment` | `-` | `-` | `Workspace#root/StarterCharacter#20/LeftFoot#22/LeftAnkleRigAttachment#6` |
| `RightShoulderRigAttachment` | `Attachment` | `-` | `-` | `Workspace#root/StarterCharacter#20/UpperTorso#24/RightShoulderRigAttachment#8` |
| `JointRotation` | `Attachment` | `-` | `-` | `Workspace#root/StarterCharacter#20/UpperTorso#24/RightShoulderRigAttachment#8/JointRotation#1` |
| `LeftShoulderRigAttachment` | `Attachment` | `-` | `-` | `Workspace#root/StarterCharacter#20/UpperTorso#24/LeftShoulderRigAttachment#10` |
| `JointRotation` | `Attachment` | `-` | `-` | `Workspace#root/StarterCharacter#20/UpperTorso#24/LeftShoulderRigAttachment#10/JointRotation#2` |
| `BodyFrontAttachment` | `Attachment` | `-` | `-` | `Workspace#root/StarterCharacter#20/UpperTorso#24/BodyFrontAttachment#12` |
| `BodyBackAttachment` | `Attachment` | `-` | `-` | `Workspace#root/StarterCharacter#20/UpperTorso#24/BodyBackAttachment#13` |
| `WaistRigAttachment` | `Attachment` | `-` | `-` | `Workspace#root/StarterCharacter#20/UpperTorso#24/WaistRigAttachment#14` |
| `WaistBallSocket` | `BallSocketConstraint` | `Workspace.StarterCharacter.LowerTorso.WaistRigAttachment` | `Workspace.StarterCharacter.UpperTorso.WaistRigAttachment` | `Workspace#root/StarterCharacter#20/UpperTorso#24/WaistBallSocket#15` |
| `NeckRigAttachment` | `Attachment` | `-` | `-` | `Workspace#root/StarterCharacter#20/UpperTorso#24/NeckRigAttachment#16` |
| `LeftCollarAttachment` | `Attachment` | `-` | `-` | `Workspace#root/StarterCharacter#20/UpperTorso#24/LeftCollarAttachment#18` |
| `NeckAttachment` | `Attachment` | `-` | `-` | `Workspace#root/StarterCharacter#20/UpperTorso#24/NeckAttachment#19` |
| `RightCollarAttachment` | `Attachment` | `-` | `-` | `Workspace#root/StarterCharacter#20/UpperTorso#24/RightCollarAttachment#21` |
| `LeftElbowRigAttachment` | `Attachment` | `-` | `-` | `Workspace#root/StarterCharacter#20/LeftLowerArm#25/LeftElbowRigAttachment#2` |
| `LeftWristRigAttachment` | `Attachment` | `-` | `-` | `Workspace#root/StarterCharacter#20/LeftLowerArm#25/LeftWristRigAttachment#3` |
| `LeftElbowBallSocket` | `BallSocketConstraint` | `Workspace.StarterCharacter.LeftUpperArm.LeftElbowRigAttachment` | `Workspace.StarterCharacter.LeftLowerArm.LeftElbowRigAttachment` | `Workspace#root/StarterCharacter#20/LeftLowerArm#25/LeftElbowBallSocket#4` |
| `HatAttachment` | `Attachment` | `-` | `-` | `Workspace#root/StarterCharacter#20/BlackHeadToque#26/Handle#1/HatAttachment#3` |
| `WaistCenterAttachment` | `Attachment` | `-` | `-` | `Workspace#root/StarterCharacter#20/LowerTorso#27/WaistCenterAttachment#3` |
| `WaistBackAttachment` | `Attachment` | `-` | `-` | `Workspace#root/StarterCharacter#20/LowerTorso#27/WaistBackAttachment#5` |
| `RootRigAttachment` | `Attachment` | `-` | `-` | `Workspace#root/StarterCharacter#20/LowerTorso#27/RootRigAttachment#6` |
| `LeftHipRigAttachment` | `Attachment` | `-` | `-` | `Workspace#root/StarterCharacter#20/LowerTorso#27/LeftHipRigAttachment#9` |
| `WaistFrontAttachment` | `Attachment` | `-` | `-` | `Workspace#root/StarterCharacter#20/LowerTorso#27/WaistFrontAttachment#10` |
| `RightHipRigAttachment` | `Attachment` | `-` | `-` | `Workspace#root/StarterCharacter#20/LowerTorso#27/RightHipRigAttachment#12` |
| `WaistRigAttachment` | `Attachment` | `-` | `-` | `Workspace#root/StarterCharacter#20/LowerTorso#27/WaistRigAttachment#13` |
| `LeftKneeRigAttachment` | `Attachment` | `-` | `-` | `Workspace#root/StarterCharacter#20/LeftUpperLeg#28/LeftKneeRigAttachment#2` |
| `LeftHipBallSocket` | `BallSocketConstraint` | `Workspace.StarterCharacter.LowerTorso.LeftHipRigAttachment` | `Workspace.StarterCharacter.LeftUpperLeg.LeftHipRigAttachment` | `Workspace#root/StarterCharacter#20/LeftUpperLeg#28/LeftHipBallSocket#4` |
| `LeftHipRigAttachment` | `Attachment` | `-` | `-` | `Workspace#root/StarterCharacter#20/LeftUpperLeg#28/LeftHipRigAttachment#7` |
| `Cuerpo_Ojos1_0Motor6D` | `Motor6D` | `Workspace.wyvernfbx.RootPart` | `Workspace.wyvernfbx.Cuerpo_Ojos1_0` | `Workspace#root/wyvernfbx#21/Cuerpo_Ojos1_0#5/Cuerpo_Ojos1_0Motor6D#1` |
| `Cuernos_Material_0Motor6D` | `Motor6D` | `Workspace.wyvernfbx.RootPart` | `Workspace.wyvernfbx.Cuernos_Material_0` | `Workspace#root/wyvernfbx#21/Cuernos_Material_0#6/Cuernos_Material_0Motor6D#1` |
| `DT_NeckSeatWeld` | `Weld` | `Workspace.wyvernfbx.DT_Root` | `Workspace.wyvernfbx.DT_NeckSeat` | `Workspace#root/wyvernfbx#21/DT_NeckSeat#7/DT_NeckSeatWeld#2` |
| `Cola_Material_0Motor6D` | `Motor6D` | `Workspace.wyvernfbx.RootPart` | `Workspace.wyvernfbx.Cola_Material_0` | `Workspace#root/wyvernfbx#21/Cola_Material_0#8/Cola_Material_0Motor6D#2` |
| `DT_GroundColliderWeld` | `WeldConstraint` | `Workspace.wyvernfbx.DT_Root` | `Workspace.wyvernfbx.DT_GroundCollider` | `Workspace#root/wyvernfbx#21/DT_GroundCollider#9/DT_GroundColliderWeld#1` |
| `DT_RootWeld` | `WeldConstraint` | `Workspace.wyvernfbx.DT_Root` | `Workspace.wyvernfbx.RootPart` | `Workspace#root/wyvernfbx#21/DT_Root#10/DT_RootWeld#1` |
| `Cuerpo_Material_0Motor6D` | `Motor6D` | `Workspace.wyvernfbx.RootPart` | `Workspace.wyvernfbx.Cuerpo_Material_0` | `Workspace#root/wyvernfbx#21/Cuerpo_Material_0#11/Cuerpo_Material_0Motor6D#2` |
| `Piedras_Material_0Motor6D` | `Motor6D` | `Workspace.wyvernfbx.RootPart` | `Workspace.wyvernfbx.Piedras_Material_0` | `Workspace#root/wyvernfbx#21/Piedras_Material_0#12/Piedras_Material_0Motor6D#1` |
| `Motor6D` | `Motor6D` | `Workspace.Gallina.HumanodiRootPart` | `Workspace.Gallina.MeshGallina` | `Workspace#root/Gallina#24/HumanodiRootPart#1/Motor6D#1` |
