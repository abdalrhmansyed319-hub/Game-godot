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

## 7. What this file does not claim

Nothing here has been playtested by a human. The knockback impulse magnitude,
the decay rate, the hit-stop durations and the shake curve are all first-pass
values chosen by reasoning, not by feel. They are expected to need tuning, and
every one of them is a single named constant.
