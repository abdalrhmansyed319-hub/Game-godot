#!/usr/bin/env python3
"""Unit test for the game-clock JS embedded in capture_playtest.py.

`game_sleep()` waits on a clamped requestAnimationFrame accumulator instead of
the wall clock, so that a slow software renderer stretches the wait rather than
silently handing the game less simulation time than the crossing was designed
around. Playwright is not importable in every environment this repo is checked
out in, so the two JS bodies are extracted from the driver source and exercised
under a hand-built rAF/timer shim in Node.

Run:  python3 tools/test_game_clock.py
Exit: 0 on pass, 1 on failure.
"""

from __future__ import annotations

import os
import re
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
DRIVER = os.path.join(HERE, "capture_playtest.py")


def grab(source: str, name: str) -> str:
    """Pull a triple-quoted JS constant out of the driver by name."""
    match = re.search(rf'^{name} = """(.*?)"""', source, re.S | re.M)
    if not match:
        sys.exit(f"missing {name} in {DRIVER}")
    return match.group(1)


HARNESS = r"""
global.window = {};
let frames = [], timers = [];
let wall = 0;
global.requestAnimationFrame = (cb) => { frames.push(cb); return frames.length; };
global.performance = { now: () => wall };
global.setTimeout = (fn, ms) => { timers.push({fn, ms, live: true}); return timers.length; };
global.clearTimeout = (id) => { if (timers[id - 1]) timers[id - 1].live = false; };

const install = PROBE_SRC;
install();
if (!window.__nhProbe) { console.log("PROBE NOT INSTALLED"); process.exit(1); }

let t = 0;
function pump(dt) {
  t += dt; wall += dt;
  const cbs = frames; frames = [];
  for (const cb of cbs) cb(t);
}
const tick = () => new Promise(r => setImmediate(r));
let failures = 0;
const check = (label, ok, detail) => {
  console.log((ok ? "PASS " : "FAIL ") + label + (detail ? "  " + detail : ""));
  if (!ok) failures += 1;
};

(async () => {
  // --- steady 60 fps: acc tracks wall, lastC sits at one frame -------------
  for (let i = 0; i < 60; i++) pump(16.7);
  const s0 = window.__nhProbe.snapshot();
  check("steady acc ~1s", Math.abs(s0.acc - 1.0) < 0.03, "acc=" + s0.acc.toFixed(3));
  check("steady lastC one frame", Math.abs(s0.lastC - 0.0167) < 0.002,
        "lastC=" + s0.lastC.toFixed(4));

  // --- a 500 ms stall must clamp, never inflate acc -----------------------
  const accBefore = window.__nhProbe.acc;
  pump(500);
  const s1 = window.__nhProbe.snapshot();
  const gained = s1.acc - accBefore;
  check("stall clamps to 8/60", Math.abs(gained - 8 / 60) < 1e-9,
        "gained=" + gained.toFixed(4) + " expect=" + (8 / 60).toFixed(4));
  check("clamped delta never exceeds cap", s1.lastC <= 8 / 60 + 1e-9,
        "lastC=" + s1.lastC.toFixed(4));

  // --- sleep(0.5) at a steady 60 fps delivers ~0.5 s of game time ---------
  const sleepFn = SLEEP_SRC;
  let out = null;
  sleepFn(0.5).then(r => { out = r; });
  let guard = 0;
  while (!out && guard < 500) { pump(16.7); await tick(); guard++; }
  check("steady sleep resolves", out !== null, "frames=" + guard);
  if (out) {
    check("steady sleep delivers ~0.5s game",
          Math.abs(out.game - 0.5) < 0.05, "game=" + out.game.toFixed(4));
    check("steady sleep no leaked timers",
          timers.filter(x => x.live).length === 0);
  }

  // --- THE REGRESSION: a stall mid-wait must stretch the wall wait --------
  // wall-clock sleep(0.5) across a 700 ms stall would resolve after 0.5 s of
  // wall time having handed the game only ~0.2 s of simulation. game_sleep
  // has to keep waiting until the game clock itself has advanced 0.5 s.
  out = null;
  const wallBeforeStall = wall;
  sleepFn(0.5).then(r => { out = r; });
  guard = 0;
  while (!out && guard < 500) {
    if (guard === 3) pump(700); else pump(16.7);
    await tick();
    guard++;
  }
  check("stalled sleep resolves", out !== null, "frames=" + guard);
  if (out) {
    check("stalled sleep delivers ~0.5s game time",
          Math.abs(out.game - 0.5) < 0.05,
          "game=" + out.game.toFixed(4) + " (wall=" + out.wall.toFixed(3) + ")");
    check("stalled sleep outlasts the stall on the wall clock",
          out.wall > 0.7, "wall=" + out.wall.toFixed(3));
    check("stalled sleep wall ~= accumulated pump time",
          Math.abs(out.wall - (wall - wallBeforeStall) / 1000) < 0.05,
          "wall=" + out.wall.toFixed(3));
    check("stalled sleep no leaked timers",
          timers.filter(x => x.live).length === 0);
  }

  // --- the guard must fire if rAF dies, or CI would hang ------------------
  out = null;
  sleepFn(3).then(r => { out = r; });
  await tick();
  const g = timers.filter(x => x.live).pop();
  if (g) { g.live = false; g.fn(); }
  await tick();
  check("guard resolves a dead rAF loop", out !== null);
  check("guard leaves no live timers", timers.filter(x => x.live).length === 0);

  // --- and a normal wait must not trip the guard early --------------------
  out = null;
  sleepFn(1.0).then(r => { out = r; });
  guard = 0;
  while (!out && guard < 500) { pump(16.7); await tick(); guard++; }
  check("1s sleep under guard", out !== null && Math.abs(out.game - 1.0) < 0.05,
        out ? "game=" + out.game.toFixed(3) : "unresolved");

  console.log(failures === 0 ? "ALL PASS" : failures + " FAILED");
  process.exit(failures === 0 ? 0 : 1);
})();
"""


def main() -> int:
    with open(DRIVER, encoding="utf-8") as fh:
        source = fh.read()

    harness = HARNESS.replace("PROBE_SRC", grab(source, "PROBE_JS"))
    harness = harness.replace("SLEEP_SRC", grab(source, "SLEEP_JS"))

    with tempfile.NamedTemporaryFile(
        "w", suffix=".js", delete=False, dir=HERE
    ) as handle:
        handle.write(harness)
        path = handle.name

    try:
        result = subprocess.run(
            ["node", path], capture_output=True, text=True, timeout=60
        )
        sys.stdout.write(result.stdout)
        if result.stderr:
            sys.stderr.write(result.stderr)
        return result.returncode
    finally:
        os.unlink(path)


if __name__ == "__main__":
    sys.exit(main())
