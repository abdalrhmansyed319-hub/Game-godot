# Physics & Feel Notes

Standing rule for this project: **no major physics change without documenting it.**
This file is that record. Everything below was introduced during **M1 — Combat
and Movement Feel**.

---

## 1. Hit-stop changes `SceneTree.time_scale` (global)

`FeedbackManager.hit_stop()` sets `time_scale = 0.05` for a few milliseconds,
then restores `1.0`.

- **Why it is safe:** the timer is created with `process_always = true`
  (`create_timer(duration, true, false, true)`), so it expires on real time
  rather than scaled time. The freeze cannot fail to end.
- **Bounds:** 40–120 ms, driven by `impact_intensity()`.
- **Escape hatch:** `FeedbackManager.cancel_all()` forces `time_scale = 1.0`.
  It is called on death and on `GameManager.return_to_title()`, so a scene
  change can never strand the game in slow motion.
- **Off switch:** `Settings.hit_stop = false` returns immediately, leaving
  `time_scale` untouched.
- **Risk:** anything using a scaled `Timer` will appear to stall for the
  duration. At 120 ms this is imperceptible; if hit-stop is ever lengthened,
  re-check every `Timer` in the project.

## 2. Enemy knockback (new)

Previously enemies took damage and staggered but never moved. Now:

- `Hitbox.knockback` (already existed, previously unused for enemies) is applied
  by `DamageSystem._apply_knockback()`.
- Direction is **away from the attacker**, recomputed from world positions
  rather than trusting the authored vector's sign.
- Magnitude is `hitbox.knockback.length() * impact_intensity(kind)`.
- `NightmareBase.apply_knockback()` accumulates an impulse into
  `_knockback_velocity`; `NightmareBase._physics_process()` folds it into
  `velocity` and decays it at `1400 px/s²` (framerate-independent,
  `move_toward`).

**No new force model was introduced.** The impulse is added to the existing
`velocity` that `NightmareAI` already drives into `move_and_slide()`, so
gravity, floor and wall behaviour are unchanged.

## 3. `NightmareData.mass` (new field)

```gdscript
@export var mass: float = 1.0
```

- Divides knockback. A Warden at `mass = 2.0` travels half as far as a Stalker.
- **Default `1.0` preserves existing behaviour** for every nightmare JSON that
  does not set it. `NightmareData.from_dict()` clamps it to `>= 0.2` so a
  hand-authored `0` cannot cause a divide-by-near-zero.
- Not authored in any `data/nightmares/*.json` yet — all three current
  nightmares use the default. This is a tuning hook, not a content change.

## 4. Enemy attacks never move the player through this path

`_apply_knockback()` returns early for `Hitbox.Kind.ENEMY`. Player knockback
stays in `PlayerHealth._apply_knockback()`, because moving the player is a
movement-feel decision and belongs with the player's own movement code. Having
two systems both write `player.velocity` was the bug this avoids.

## 5. Player movement — fixes, not new physics

`PlayerMovement` already implemented coyote time, jump buffering, variable
jump height, wall slide/jump, ledge climb and dash. M1 changed:

- **`set_facing()` and `set_airborne()` were being called but did not exist.**
  `PlayerController._physics_process()` called both every physics frame. They
  are now real methods. This was a genuine defect, not a tuning change.
- **Jumping played the dash sound** (`AudioManager.play_named(&"dash")` inside
  `_do_jump()`). Now `&"jump"`, with `&"double_jump"` and `&"wall_jump"` added.
- `is_airborne` is now a stored mirror of the floor state, pushed in by
  `PlayerController` so visuals and abilities agree with physics.

No gravity constant, speed, acceleration or collision value was altered.

## 6. Camera shake uses `offset`, not `position`

`ShakeCamera` writes `Camera2D.offset`. Using `position` would fight the
`position_smoothing` that makes following readable, and would leave a residual
displacement if a shake was interrupted. Shake is clamped twice — once in
`FeedbackManager.shake()` (`MAX_SHAKE = 18`) and again in `ShakeCamera`
(`MAX_SHAKE_OFFSET = 16`). The double clamp is deliberate: the camera is the
last thing between a large number and an unreadable screen.

## 7. Level geometry was wrong for the movement numbers (M1 exit)

No movement constant was changed. The **level** was changed, because the
authored platform spacing did not match what the movement code can actually do.

A single jump peaks at:

```
jump_velocity² / (2 · gravity) = 430² / (2 · 980) = 94.3 px
```

and the double jump is dead code — `request_double_jump_unlock()` has **no
callers anywhere in the project**, so `can_double_jump` stays `false` at
runtime and `max_jumps` is effectively 1.

Against that, the region had:

| feature | was | needed | verdict |
|---|---|---|---|
| ground west → ground mid | 370 px gap | best dash-jump reaches 318 px | uncrossable |
| step 1 / 2 / 3 | 102 / 100 / 110 px rises | 94.3 px max | unclimbable |
| "wall to wall-jump" | 280 px, single wall | — | sealed the level at x=1880 |

The player spawns at `(120, -40)` on ground west. Both exits were blocked, so
the Hunter was **trapped on the starting platform with no reachable enemy.**
None of this was visible to any check that existed: the scripts parse, the
scenes resolve, the export succeeds, and the browser smoke test draws frames.

**Fixes applied to `scripts/world/region_level.gd` (geometry only):**

- ground mid moved to centre x `1410` → the gap is **260 px**. Still demands a
  dash (a plain jump covers 188 px) but leaves ~58 px of margin.
- steps re-spaced to an **80 px rise each** (tops at −100 / −180 / −260),
  ~14 px of headroom per step.
- the 280 px wall became an **80 px vault** (`(1900, 0)`, size `40 × 200`). A
  single wall cannot be wall-jump climbed — there is no opposing surface to push
  against — so it is now something the player jumps onto and over.
- memory `choir_verse` moved from y `-370` to `-300` so it sits within reach of
  a player standing on step 3.

**Recorded, not fixed:** the boss arena is sealed. Its enclosure walls reach
y `-380` while the arena floor is at `-80`, so there is no opening at any height
the player can reach. The Bell is out of scope for M1, so this is left alone and
flagged instead. Nightmare 3 and the `shrine_plate` mechanism inside it are
therefore unreachable this milestone.

**Guard:** `tools/simulate_traversal.py` re-derives all of the above and fails
the build if any required move becomes unreachable. `tools/validate_traversal_check.py`
re-injects the original broken geometry and asserts the guard actually fires.
Both run in CI.

**Caveat:** the simulator is arithmetic, not the engine. It does not model
`CharacterBody2D` collision response, floor snapping, or capsule-vs-ledge
behaviour. A pass means "physically reachable"; only a human playing it can
confirm it *feels* reachable.

## 8. What this file does not claim

Nothing here has been playtested by a human. The knockback impulse magnitude,
the decay rate, the hit-stop durations and the shake curve are all first-pass
values chosen by reasoning, not by feel. They are expected to need tuning, and
every one of them is a single named constant.
