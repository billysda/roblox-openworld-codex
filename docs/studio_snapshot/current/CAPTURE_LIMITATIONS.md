# Limitaciones de la Captura del DataModel

1. **ServerStorage y RBX_ANIMSAVES**:
   - `ServerStorage.RBX_ANIMSAVES` contiene 1,016,383 descendientes generados automáticamente por el *Roblox Animation Clip Editor* (almacén de keyframes y poses por fotograma para rigs como Gallina, Oveja, wyvernfbx y DragonModel).
   - Por diseño estricto para evitar generar un archivo JSONL de ~500 MB (que excedería el límite de 100 MB de GitHub y tardaría más de 1.8 horas de exportación de red), se exportó el nodo raíz de `RBX_ANIMSAVES` pero se omitió la recursión sobre su millón de fotogramas efímeros de editor.
   - Los assets jugables reales en `ServerStorage.Assets` (186 instancias), `_Reference_DragonClassic` (592 instancias) y `_Reference_DragonTierraLegacy` (498 instancias) fueron exportados al 100% sin truncamiento.

2. **StarterPack**:
   - `StarterPack` contiene un `Script` (deshabilitado) y otra carpeta secundaria `RBX_ANIMSAVES` de 23,609 keyframes de editor.

3. **Geometría Binaria y Assets**:
   - Las instancias `MeshPart`, `SpecialMesh`, `Decal`, `Texture` y `Animation` registran sus propiedades (`MeshId`, `TextureID`, `AnimationId`, `Size`, `CFrame`, etc.), pero los binarios 3D de Roblox (`rbxassetid://`) no se almacenan como blobs en el árbol JSONL.

4. **Terrain**:
   - La instancia `Workspace.Terrain` está registrada con sus propiedades principales de iluminación/material, pero la voxelgrid tridimensional de Terrain requiere exportación específica de voxels (`Terrain:CopyRegion`).

5. **Modo de Captura**:
   - Esta captura fue realizada 100% en modo **Edit** (`RunService:IsEdit() == true`).
   - Las instancias creadas exclusivamente por scripts durante **Play** (como `DT_ClientSaddleProxy`, efectos de partículas temporales, o personajes `Player.Character`) no existen en Edit y deben documentarse a través de sus generadores en código o en una captura Play complementaria.
