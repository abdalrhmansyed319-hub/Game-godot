class_name Palette
extends RefCounted
## Palette — the entire colour language of the game, in one place.
##
## Discipline is the style. Four families, and one rule that matters more than
## any of them: **gold is reserved for revealed truth.** It never appears
## decoratively, so when the player sees it they know it is real.

# --- The dream itself -------------------------------------------------------
const VOID: Color = Color(0.031, 0.027, 0.055)
const NIGHT_FAR: Color = Color(0.055, 0.051, 0.102)
const NIGHT_MID: Color = Color(0.082, 0.075, 0.145)
const NIGHT_NEAR: Color = Color(0.114, 0.102, 0.196)
const GROUND: Color = Color(0.149, 0.137, 0.247)
const GROUND_EDGE: Color = Color(0.243, 0.227, 0.392)

# --- The Hunter -------------------------------------------------------------
const CLOAK: Color = Color(0.125, 0.118, 0.208)
const CLOAK_LIT: Color = Color(0.204, 0.192, 0.325)
const SKIN: Color = Color(0.855, 0.776, 0.678)

# --- Instruments ------------------------------------------------------------
## The Hunter's lamp. Warm, and the only warm light in the dream.
const LANTERN: Color = Color(0.961, 0.863, 0.478)
const ANCHOR: Color = Color(0.545, 0.745, 0.878)
const BLADE: Color = Color(0.776, 0.847, 0.945)
const BLADE_TRAIL: Color = Color(0.643, 0.757, 0.945)

# --- Nightmares -------------------------------------------------------------
const NIGHTMARE: Color = Color(0.294, 0.180, 0.514)
const NIGHTMARE_DARK: Color = Color(0.169, 0.102, 0.310)
const NIGHTMARE_EDGE: Color = Color(0.498, 0.345, 0.769)

# --- Revealed truth. RESERVED. Never decorative. ----------------------------
const TRUTH: Color = Color(1.0, 0.851, 0.541)
const TRUTH_CORE: Color = Color(1.0, 0.949, 0.780)

# --- Combat readability -----------------------------------------------------
const TELEGRAPH: Color = Color(0.945, 0.322, 0.380)
const HURT_FLASH: Color = Color(1.0, 0.878, 0.878)
const BLOODLESS_IMPACT: Color = Color(0.804, 0.733, 0.945)

# --- Interface --------------------------------------------------------------
const UI_BG: Color = Color(0.047, 0.043, 0.086, 0.92)
const UI_EDGE: Color = Color(0.298, 0.278, 0.478)
const UI_TEXT: Color = Color(0.878, 0.867, 0.945)
const UI_TEXT_DIM: Color = Color(0.549, 0.533, 0.678)
const HEALTH: Color = Color(0.831, 0.329, 0.376)
const RESONANCE: Color = Color(0.569, 0.455, 0.878)
const LANTERN_UI: Color = Color(0.961, 0.863, 0.478)
