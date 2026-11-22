# M1 — Combat & Movement Feel: implementation and test report

**Branch:** `arena/c01b8ea4-game-godot`
**Verified commit:** `c472df6`
**CI:** run `45012352644` — `verify` success (10 steps), `web` success (17 steps)

---

## Read this first: what "tested" means here

**No human has played this game.** Not once, at any milestone. Everything
below labelled *implemented* was written and compiled. Everything labelled
*verified* was checked by a machine. Nothing is labelled *playtested*, because
none of it is.

The distinction matters because the entire point of M1 was *feel*, and feel is
not a property a compiler can confirm. A hit-stop of 60 ms either reads as
weight or reads as lag, and only a hand on a keyboard can say which. So this
report is an implementation record plus a test plan, not a playtest result.

| Word | What it actually means |
| --- | --- |
| **Implemented** | The code exists and is committed. Nothing more. |
| **Statically verified** | `tools/check_project.py` and `gdparse` 4.5.0 accept it. |
| **CI verified** | The real Godot 4.7.2 engine imported, booted, and exported it. |
| **Playtested** | A person played it. **Nothing in this project has been.** |

---

## Verified by CI on `c472df6`

| Measurement | Result | Jam limit |
| --- | --- | --- |
| Engine imports and boots headless | yes | required |
| Web export completes | yes, all 17 steps | required |
| Canvas drawn in headless Chromium over plain HTTP | 1280×720 | required |
| Viewport resize | 1280×720 → 960×600 | must respond |
| Console / page errors | none | — |
| Thread support | none (no `worker.js`), so no COOP/COEP | avoids `SharedArrayBuffer` |
| `.pck` | unencrypted | encrypted packs are rejected |
| **First-frame payload** | **38.36 MB / 9 files** | < 50 MB |

The payload grew **0.19 MB** from M2 (38.17 MB). All of M1's art is procedural
`_draw()` calls and all audio is synthesised at runtime, so neither added an
asset. The growth is the extra compiled scripts.

**Honest gap, unchanged from M2:** the browser test confirms the canvas exists,
has dimensions, resizes, and logs no errors. It does **not** sample pixels.
That a frame is visibly drawn is inferred, not measured.

---

## Implemented, statically verified, CI verified — not playtested

### Movement
`PlayerMovement` already had coyote time, jump buffering, variable jump
height, wall slide/jump, ledge climb and dash before M1. What M1 changed:

- **Two methods that did not exist were being called every physics frame.**
  `PlayerController._physics_process()` called `movement.set_facing()` and
  `movement.set_airborne()`. Neither was defined. Both are real now. This was
  a genuine defect, not a tuning change.
- **Jumping played the dash sound.** `_do_jump()` called
  `play_named(&"dash")`. Jump, double jump and wall jump now have distinct
  sounds.
- Landing produces dust and camera shake above 220 px/s of impact; below that
  threshold it produces nothing, so ordinary hopping stays quiet.
- The camera leads the player in the direction of travel, and dips on hard
  landings.

No gravity constant, speed, acceleration or collision value was altered. See
`docs/PHYSICS_NOTES.md`.

### Combat feel
- `DamageSystem` is the single place impact feedback resolves. One
  `impact_intensity(kind)` value — 0.45 to 1.35 — drives hit-stop, shake and
  particle count together, so a light tap and a charged blow cannot drift
  apart as content grows.
- Hit-stop is a real-time `time_scale` reduction of 40–120 ms.
- Enemies now take knockback and squash on impact. Previously they took damage
  and staggered but never moved.
- The swing is drawn as a procedural arc; the enemy telegraph is drawn as part
  of the creature rather than as a separate rectangle.

### Visuals
Six new draw-only scripts replace every coloured rectangle in the game:
`HunterVisual`, `NightmareVisual`, `TerrainVisual`, `PropVisual`, `DreamSky`,
plus `Palette` holding the whole colour language. Each nightmare category gets
a different silhouette rather than a recoloured box. Gold is reserved
exclusively for revealed truth.

### Input
Mouse is bound to light attack (LMB), heavy (RMB), dash (wheel up), lantern
(MMB) and anchor (button 5). Aiming follows the cursor with a 14 px deadzone.
`Esc` opens a pause menu carrying the comfort settings.

### Audio
A voice pool of 8 replaced a single player — previously a hit landing during a
swing was silent, because the new sound cut off the old one. Impacts are
noise-mixed rather than pure tones, and pitch jitters ±6% so repeated attacks
do not machine-gun.

---

## Not done

- **No human playtest.** The single largest risk in this milestone is
  unaddressed by anything in this report.
- No dialogue, NPC or ending content.
- The Bell boss is untouched, as instructed.
- `NightmareData.mass` is a tuning hook; no nightmare JSON sets it, so all
  three use the default `1.0`.
- The Jam GDD and the web build are still not uploaded to Drive.

---

## Playtest plan — what to actually try, in order

Run the exported build and check these in this order. Each one is a yes/no
with a number attached, so the answers are comparable between sessions.

1. **Does the jump feel owned?** Hold and tap jump. The tap should reach
   roughly half the height. If both feel the same, `jump_cut_multiplier`
   (0.45) is wrong.
2. **Can you land where you aim?** Dash across the gap at x≈1400. If you
   overshoot or fall short consistently, `dash_speed` (620) or `air_control`
   (0.82) is wrong.
3. **Do hits feel connected?** Light-attack the Hollow Choir ten times. Count
   how many feel like the blade touched something. Under 8 out of 10 means
   hit-stop is too short or the shake is too small.
4. **Is any of it unreadable?** During a heavy hit, can you still see the
   enemy telegraph? If not, `MAX_SHAKE` (18) is too high.
5. **Does being hit feel worse than hitting?** Take a hit deliberately. It
   should be more disruptive than landing one, by design.
6. **Does mouse aiming help or fight you?** Attack while moving left with the
   cursor right. If the Hunter flips mid-swing, the 14 px deadzone is too
   small.
7. **Any motion discomfort?** Turn off screen shake, hit-stop and flashes in
   the pause menu. The game must still be fully playable.
8. **Does it hold 60 fps?** Watch the frame counter during three simultaneous
   particle bursts.

---

## What four failed CI runs cost, and what changed because of them

Four consecutive runs failed on one duplicated `func flash()` declaration in
`nightmare_visual.gd`. Godot reported

    Parse Error: Could not parse global class "NightmareVisual"

which names the victim, not the cause, and every script referencing it failed
behind it. I diagnosed it twice and was wrong twice — first a suspected
circular class reference, then a suspected invalid property access. Both fixes
were plausible and neither was the bug.

`tools/check_project.py` now checks for duplicate top-level declarations
directly, alongside checks for calls to functions that do not exist in Godot 4
and for static-call signature mismatches. Each was fault-injection validated
against the exact error that reached CI. The lesson recorded in the code is
that a green `verify` job is not evidence the scripts parse: `verify` passed on
commits where `web` failed, because the export step parses more than the boot
step does.
