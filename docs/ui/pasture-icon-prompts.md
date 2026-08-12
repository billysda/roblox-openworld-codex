# Prompts de iconos — Pasture HUD

## Regla visual común

Todos los iconos deben compartir exactamente el mismo lenguaje visual para que parezcan parte del mismo juego.

**Prompt base para reutilizar en todos:**

> Create a clean mobile game UI icon for a cozy medieval pastoral fantasy game. Single-color warm ivory/cream glyph, strong readable silhouette, simple chunky shapes, slight hand-crafted medieval feel, centered composition, transparent background, no text, no letters, no numbers, no border, no circular button background, no drop shadow, no glow, no scenery, no extra objects. The icon must remain recognizable at 48–64 pixels on a phone screen. Flat 2D vector-like design, high contrast, minimal internal detail. Square 1:1 canvas, preferably 256x256 PNG with transparency. Leave 12–15% empty padding around the glyph. The GUI itself will provide the circular dark-brown button, outline and pressed states, so generate only the foreground symbol.

No generar el fondo marrón del botón dentro de la imagen. Así una sola textura puede reutilizarse y recolorearse desde Roblox mediante `ImageColor3`.

---

## 1. Whistle / Silbar

**Uso:** `PastureHUD.MobileActions.WhistleButton.Icon`

**Prompt:**

> Create a shepherd whistle icon using the shared Pasture HUD style. Show a small traditional shepherd whistle in side profile, compact and unmistakable, with two short curved sound-wave marks coming from the opening. Keep the silhouette bold and simple, not a modern sports referee whistle, not a musical instrument, no human face. Single warm ivory/cream glyph on transparent background, centered, readable at 48–64 px, 256x256 square PNG, no text and no button background.

Clave visual: debe comunicar `silbar / llamar al rebaño` en menos de un segundo.

---

## 2. Command / Ordenar destino

**Uso:** `PastureHUD.MobileActions.CommandButton.Icon`

**Prompt:**

> Create a shepherd command-target icon using the shared Pasture HUD style. Combine a simple shepherd's crook/staff angled diagonally with a small ground target marker made of one clean ring and a tiny center dot near the lower end of the staff. The composition must clearly communicate “direct the flock to this place,” not combat and not magic. Bold simple silhouette, single warm ivory/cream glyph, transparent background, centered, readable at 48–64 px, 256x256 square PNG, no text, no arrows outside the symbol, no button background.

Debe distinguirse claramente del icono de silbido.

---

## 3. Sheep / Rebaño

**Uso:** `PastureHUD.SheepCounter.Icon`

**Prompt:**

> Create a sheep head icon using the shared Pasture HUD style. Front-facing friendly sheep head with a rounded wool silhouette, small ears and very simple facial geometry. Cozy rather than cartoonish, no exaggerated smile, no body, no farm scenery. Strong compact silhouette, single warm ivory/cream glyph, transparent background, centered, readable at 40–56 px, 256x256 square PNG, no text and no button background.

Debe funcionar junto a un contador como `2/2`.

---

## 4. Grazing / Pastoreo

**Uso:** `PastureHUD.GrazingPanel.Icon`

**Prompt:**

> Create a grazing icon using the shared Pasture HUD style. Show three simple curved blades of grass growing from one small ground arc, with a tiny leaf-like accent suggesting fresh pasture. Keep it organic and pastoral, not a cannabis leaf, not wheat, not a flower. Single warm ivory/cream glyph, bold simple silhouette, transparent background, centered, readable at 40–56 px, 256x256 square PNG, no text and no button background.

Debe comunicar `pasto / zona de pastoreo / progreso de comer hierba`.

---

## 5. Fox Warning / Zorro cerca

**Uso:** `PastureHUD.FoxWarning.Icon`

**Prompt:**

> Create a fox threat warning icon using the shared Pasture HUD style. Show a sharp but simple front-facing fox head silhouette with pointed ears and narrow cheek shapes, immediately recognizable as a fox. Add one very small alert notch/accent above the head only if needed, but do not place the fox inside a warning triangle because the Roblox GUI will provide the warning container. The fox should look alert and dangerous enough to signal a predator, without horror or gore. Single warm ivory/cream glyph, transparent background, centered, readable at 40–56 px, 256x256 square PNG, no text and no button background.

Debe distinguirse de un perro o lobo mediante orejas grandes y hocico fino.

---

## Exportación para Roblox

- PNG con transparencia.
- 1:1.
- Recomendado: 256x256; 512x512 solo si el generador pierde demasiado detalle a 256.
- Sin texto incrustado.
- Sin fondo.
- Sin estados hover/pressed separados.
- Una imagen por símbolo.
- Después de subir cada imagen a Roblox, copiar su Asset ID y asignarlo únicamente a la propiedad `Image` del slot correspondiente.
