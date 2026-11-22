#!/usr/bin/env python3
"""Simulate PlayerMovement to check the level is actually traversable.

Mirrors scripts/player/player_movement.gd line for line: same gravity
multipliers, same air-control factor applied to acceleration AND friction, same
dash behaviour (velocity.y forced to 0, run-speed momentum handed back on
exit), same 60 Hz physics tick, same `physics/2d/default_gravity` fallback of
980.

Why this exists: telling the user "go playtest the movement" is worthless if
the authored platform spacing cannot be crossed with the authored numbers. The
engine cannot run in this sandbox, so the arithmetic is checked here.

Caveat, stated plainly: this is arithmetic, not the engine. CharacterBody2D
collision response, floor snapping and capsule-vs-ledge behaviour are not
modelled, so treat a pass as "physically reachable" and a fail as "definitely
unreachable".

Usage: python3 tools/simulate_traversal.py
Exit 0 = every required move in the region is reachable.
"""

from __future__ import annotations

import sys

# --- Tuning, copied from scripts/player/player_movement.gd ------------------
RUN_SPEED = 230.0
ACCELERATION = 1900.0
GROUND_FRICTION = 2400.0
AIR_FRICTION = 700.0
AIR_CONTROL = 0.82
JUMP_VELOCITY = -430.0
GRAVITY_RISING = 1.0
GRAVITY_FALLING = 1.35
TERMINAL = 900.0
DASH_SPEED = 620.0
DASH_DURATION = 0.16
DASH_FRAMES = int(round(DASH_DURATION * 60.0))  # 9.6 -> 10 frames
GRAVITY = 980.0
DELTA = 1.0 / 60.0

# The player's CollisionShape2D sits at (0, -20) with a capsule of height 40,
# so the capsule spans y -40..0 relative to the node origin: the origin is at
# the feet. All heights below are therefore measured at the feet.
PLAYER_HEIGHT = 40.0

ANALYTIC_PEAK = (JUMP_VELOCITY ** 2) / (2.0 * GRAVITY * GRAVITY_RISING)


def _approach(current: float, target: float, rate: float) -> float:
    if current < target:
        return min(current + rate * DELTA, target)
    if current > target:
        return max(current - rate * DELTA, target)
    return target


def jump(dash_at_frame: int | None = None) -> tuple[float, float]:
    """Jump right off a ledge. Return (horizontal reach, peak height).

    `dash_at_frame` is the physics frame after take-off on which to dash.
    Sweeping this is what finds the true maximum reach: dashing near the apex
    converts the whole 0.16 s of zero-gravity into forward travel, which is far
    more distance than dashing early on the way up.
    """
    x = y = vx = 0.0
    for _ in range(90):  # reach full run speed on the ground first
        vx = _approach(vx, RUN_SPEED, ACCELERATION if RUN_SPEED > vx else GROUND_FRICTION)
        x += vx * DELTA
    start_x = x
    vy = JUMP_VELOCITY
    peak = 0.0

    for frame in range(1, 1200):
        dashing = dash_at_frame is not None and dash_at_frame <= frame < dash_at_frame + DASH_FRAMES
        if dashing:
            vx = DASH_SPEED
            vy = 0.0
        else:
            vy += GRAVITY * (GRAVITY_RISING if vy < 0.0 else GRAVITY_FALLING) * DELTA
            vy = max(-TERMINAL, min(TERMINAL, vy))
            rate = (ACCELERATION if RUN_SPEED > vx else AIR_FRICTION) * AIR_CONTROL
            vx = _approach(vx, RUN_SPEED, rate)
            if dash_at_frame is not None and frame == dash_at_frame + DASH_FRAMES:
                vx = RUN_SPEED * 0.6  # momentum handed back on dash exit
        x += vx * DELTA
        y += vy * DELTA
        peak = max(peak, -y)
        if y >= 0.0 and not dashing:
            return x - start_x, peak
    return x - start_x, peak


def best_reach() -> tuple[float, int]:
    best = (0.0, -1)
    for frame in range(0, 80):
        reach, _ = jump(frame)
        if reach > best[0]:
            best = (reach, frame)
    return best


# --- Authored geometry, from scripts/world/region_level.gd ------------------
# _add_platform(center, size) -> StaticBody2D centred on `center`.
PLATFORMS = [
    ("ground west", (0, 0), (1400, 40)),
    ("ground mid", (1410, 0), (900, 40)),
    ("ground east", (2500, 0), (1600, 40)),
    ("step 1", (520, -88), (180, 24)),
    ("step 2", (780, -168), (180, 24)),
    ("step 3", (1040, -248), (220, 24)),
    ("wall mid", (1900, 0), (40, 200)),
    ("boss floor", (3450, -60), (700, 40)),
    ("wall boss L", (3120, -220), (40, 320)),
    ("wall boss R", (3780, -220), (40, 320)),
]


def surface(name: str) -> tuple[float, float, float]:
    for n, (cx, cy), (w, h) in PLATFORMS:
        if n == name:
            return cx - w / 2.0, cx + w / 2.0, cy - h / 2.0
    raise KeyError(name)


def check(label: str, need: float, have: float, unit: str = "px") -> list[str]:
    ok = have >= need
    print(f"  {label:<34} need {need:7.1f} {unit}, have {have:7.1f} {unit}  {'OK' if ok else 'UNREACHABLE'}")
    return [] if ok else [f"{label}: needs {need:.1f} {unit}, only {have:.1f} available"]


def main() -> int:
    print("Authored surfaces (y negative = up):")
    print(f"  {'name':<12} {'x from':>8} {'x to':>8} {'top':>7}")
    for name, _, _ in PLATFORMS:
        left, right, top = surface(name)
        print(f"  {name:<12} {left:8.0f} {right:8.0f} {top:7.0f}")

    _, peak = jump(None)
    reach, frame = best_reach()
    print(f"\nSingle jump: peak {peak:.1f} px (analytic {ANALYTIC_PEAK:.2f} px), flat reach {jump(None)[0]:.1f} px")
    print(f"Best dash timing: frame {frame} after take-off -> {reach:.1f} px horizontal")

    failures: list[str] = []

    print("\nRequired moves:")
    # Ground west ends at x=700; ground mid starts at x=1070.
    gw = surface("ground west")
    gm = surface("ground mid")
    failures += check("ground west -> ground mid", gm[0] - gw[1], reach)

    # The stepped climb. Each rise is measured top-to-top; the player must
    # clear the higher top, so the whole rise has to fit inside one jump.
    print("\nStepped climb (rise needed vs single-jump peak):")
    prev = surface("ground west")[2]
    for name in ("step 1", "step 2", "step 3"):
        top = surface(name)[2]
        failures += check(f"{name} (top {top:.0f})", prev - top, peak)
        prev = top

    # The wall is a hurdle the player jumps onto and over.
    wall_top = surface("wall mid")[2]
    ground_top = surface("ground mid")[2]
    print("\nWall mid:")
    failures += check("vault onto wall mid", ground_top - wall_top, peak)

    # Boss arena: the enclosure walls reach y=-380 while the arena floor is at
    # -80, so there is no opening at any height the player can reach.
    arena_wall_top = surface("wall boss L")[2]
    print("\nBoss arena (Bell is out of scope for M1):")
    print(f"  enclosure wall top {arena_wall_top:.0f}, arena floor {surface('boss floor')[2]:.0f}, "
          f"jump peak {peak:.1f} px")
    print(f"  -> the arena is SEALED from the main route; recorded, not fixed (Bell out of scope)")

    # Content must sit somewhere the player can actually stand, or it is
    # unreachable content that looks like a bug during a playtest.
    print("\nContent placement (must rest on a reachable surface):")
    surfaces = [surface("ground west"), surface("ground mid"), surface("ground east"),
                surface("step 1"), surface("step 2"), surface("step 3"), surface("wall mid")]
    # (label, position, half-height of its own collision shape, must-be-touched)
    # A nightmare or prop falls until it lands, so it only needs a floor under
    # it. A floating memory is collected on overlap, so it must also be inside
    # the space a player standing on that floor can reach.
    content = [
        ("nightmare 1", (820, -260), 20.0, False),
        ("nightmare 2", (1720, -40), 20.0, False),
        ("quiet room", (120, -30), 20.0, False),
        ("memory choir_verse", (1080, -300), 20.0, True),
        ("mechanism cellar", (2260, -30), 20.0, False),
    ]
    for label, (cx, cy), half_h, must_touch in content:
        # y is negative upward, so a surface is *beneath* the item when its top
        # y is numerically greater than the item's y.
        floors = [top for left, right, top in surfaces if left <= cx <= right and top >= cy]
        if not floors:
            failures.append(f"{label} at ({cx:.0f},{cy:.0f}) has no surface beneath it")
            print(f"  {label:<22} ({cx:5.0f},{cy:5.0f})  NO SURFACE BENEATH  UNREACHABLE")
            continue
        # The nearest floor beneath the item is the most negative top.
        top = min(floors)
        # A player standing on `top` has its capsule from top-PLAYER_HEIGHT to
        # top, and a jump lifts that whole capsule by `peak`.
        reach_ceiling = top - PLAYER_HEIGHT - peak
        item_bottom = cy + half_h
        note = f"stands at y {top:5.0f}"
        if must_touch:
            if item_bottom < reach_ceiling:
                failures.append(
                    f"{label} at y {cy:.0f} is above the reach of a player on y {top:.0f}"
                )
                note += "  ABOVE REACH  UNREACHABLE"
            else:
                note += "  in reach  OK"
        else:
            note += f"  (falls {-item_bottom + top:4.0f} px)  OK"
        print(f"  {label:<22} ({cx:5.0f},{cy:5.0f})  {note}")

    if failures:
        print("\nFAILED — the authored geometry blocks the route:")
        for f in failures:
            print("  - " + f)
        return 1
    print("\nOK: every required move on the M1 route is reachable with the current tuning.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
