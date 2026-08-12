# Pasture Mobile UI v1

Objetivo: añadir controles táctiles al pastoreo sin crear scripts por botón o por icono. La lógica de F/G permanece centralizada en `StarterPlayerScripts.PastureClient`.

## Regla de arquitectura

- 1 solo LocalScript controlador: `PastureClient`.
- 0 scripts dentro de `StarterGui.PastureHUD`.
- Los botones son `ImageButton`/`TextLabel`/`Frame` normales.
- Los iconos son `ImageLabel` con `Image = ""` hasta que existan los asset IDs.
- Cuando haya IDs, se cambian únicamente las propiedades `Icon.Image`; no hace falta reescribir lógica.
- El fondo, borde, forma circular, colores y estados del botón se construyen con GuiObjects (`UICorner`, `UIStroke`, `Frame`) para no hornear variantes dentro de las imágenes.

## Jerarquía exacta a crear en StarterGui

```text
StarterGui
└─ PastureHUD (ScreenGui)
   ├─ MobileActions (Frame)
   │  ├─ UIListLayout
   │  ├─ WhistleButton (ImageButton)
   │  │  ├─ UICorner
   │  │  ├─ UIStroke
   │  │  ├─ Icon (ImageLabel)            Image=""
   │  │  └─ Fallback (TextLabel)         "SILBAR"
   │  └─ CommandButton (ImageButton)
   │     ├─ UICorner
   │     ├─ UIStroke
   │     ├─ Icon (ImageLabel)             Image=""
   │     └─ Fallback (TextLabel)          "ORDENAR"
   ├─ CommandReticle (Frame)
   │  ├─ Top (Frame)
   │  ├─ Bottom (Frame)
   │  ├─ Left (Frame)
   │  └─ Right (Frame)
   ├─ SheepCounter (Frame)               Visible=false por ahora
   │  ├─ Icon (ImageLabel)                Image=""
   │  └─ CountLabel (TextLabel)           "0/0"
   ├─ GrazingPanel (Frame)               Visible=false por ahora
   │  ├─ Icon (ImageLabel)                Image=""
   │  ├─ Label (TextLabel)                "PASTOREO"
   │  ├─ BarBackground (Frame)
   │  │  └─ Fill (Frame)
   │  └─ PercentLabel (TextLabel)         "0%"
   └─ FoxWarning (Frame)                 Visible=false por ahora
      ├─ Icon (ImageLabel)                Image=""
      └─ Label (TextLabel)                "ZORRO CERCA"
```

## Propiedades principales

### PastureHUD
- `ResetOnSpawn = false`
- `IgnoreGuiInset = false`
- `ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets`
- `ZIndexBehavior = Sibling`

### MobileActions
- `BackgroundTransparency = 1`
- `AnchorPoint = Vector2.new(1, 1)`
- `Position = UDim2.new(1, -24, 1, -180)`
- `Size = UDim2.fromOffset(78, 164)`
- `Visible = false` por defecto; `PastureClient` decide según `UserInputService.PreferredInput`.

### UIListLayout
- `FillDirection = Vertical`
- `HorizontalAlignment = Center`
- `VerticalAlignment = Bottom`
- `Padding = UDim.new(0, 10)`
- `SortOrder = LayoutOrder`

### WhistleButton / CommandButton
- `Size = UDim2.fromOffset(72, 72)`
- `BackgroundColor3 = Color3.fromRGB(39, 32, 25)`
- `BackgroundTransparency = 0.12`
- `AutoButtonColor = true`
- `BorderSizePixel = 0`
- `Image = ""` (el ImageButton no lleva el icono directamente; lo lleva el hijo `Icon`)
- `WhistleButton.LayoutOrder = 1`
- `CommandButton.LayoutOrder = 2`

### UICorner
- `CornerRadius = UDim.new(1, 0)`

### UIStroke
- `Thickness = 2`
- `Transparency = 0.15`
- `Color = Color3.fromRGB(236, 219, 171)`

### Icon de cada botón
- `BackgroundTransparency = 1`
- `AnchorPoint = Vector2.new(0.5, 0.5)`
- `Position = UDim2.fromScale(0.5, 0.5)`
- `Size = UDim2.fromScale(0.62, 0.62)`
- `Image = ""`
- `ScaleType = Fit`
- `ImageColor3 = Color3.fromRGB(248, 239, 211)`
- `ZIndex` superior al fondo.

### Fallback
- `BackgroundTransparency = 1`
- ocupa aproximadamente 76% del botón
- `TextScaled = true`
- `TextWrapped = true`
- `Font = GothamBold` o equivalente legible
- `TextColor3 = Color3.fromRGB(248, 239, 211)`
- `TextStrokeTransparency = 0.75`
- `SILBAR` para WhistleButton
- `ORDENAR` para CommandButton

`PastureClient` oculta automáticamente el Fallback cuando `Icon.Image` deja de estar vacío.

## CommandReticle

No usa textura ni imagen. Se construye con cuatro `Frame` simples para ahorrar assets.

- Frame raíz: `BackgroundTransparency=1`, `AnchorPoint=(0.5,0.5)`, `Position=(0.5,0.5)`, `Size=UDim2.fromOffset(30,30)`, `Visible=false`.
- Cada línea usa color crema/verde suave y 2 px de grosor.
- Dejar un espacio vacío de aproximadamente 8 px en el centro.
- El retículo solo aparece en Touch cuando el bastón `PastureStaff=true` está realmente equipado.

## Comportamiento implementado por PastureClient

### PC
- F -> `Whistle:FireServer()`.
- G -> exige bastón equipado, raycast desde cursor, marker, `CommandTarget:FireServer(position)`.

### Touch
- `WhistleButton.Activated` -> exactamente la misma función de silbido.
- `CommandButton.Activated` -> exige bastón, hace raycast desde el centro de la cámara (retículo), valida distancia <= 220 y dispara el mismo RemoteEvent.
- Los botones se muestran cuando `PreferredInput == Enum.PreferredInput.Touch`.
- `CommandButton` y `CommandReticle` solo aparecen con bastón equipado.

## Slots de iconos preparados

No colocar IDs inventados. Los cinco slots quedan vacíos:

1. `WhistleButton.Icon.Image`
2. `CommandButton.Icon.Image`
3. `SheepCounter.Icon.Image`
4. `GrazingPanel.Icon.Image`
5. `FoxWarning.Icon.Image`

Formato futuro:

```lua
rbxassetid://123456789012345
```

No añadir LocalScripts a ninguno de esos ImageLabel/ImageButton.
