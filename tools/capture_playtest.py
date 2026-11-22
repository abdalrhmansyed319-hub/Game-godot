#!/usr/bin/env python3
"""Drive the exported Web build with real input and capture playtest screenshots.

The smoke test only proves a frame was drawn. This goes further: it feeds
genuine keyboard and mouse events into the Godot canvas through the Chrome
DevTools Protocol, waits for real time to pass, and screenshots the result.

Everything here is input-level, never script-level. Nothing calls into
GDScript, nothing pokes the scene tree, nothing forces a state. If a screenshot
shows the Hunter mid-slash, it is because a mouse-down event reached the canvas
and the game's own code produced the arc.

Usage: python3 tools/capture_playtest.py <build-dir> <output-dir>
Exit 0 = every required shot was captured.
"""

from __future__ import annotations

import hashlib
import http.server
import os
import socketserver
import sys
import threading
import time
from functools import partial

REQUIRED = [
    "01_main_menu",
    "02_protagonist",
    "03_environment",
    "04_enemy_encounter",
    "05_combat_effects",
    "06_pause_menu",
]

# Godot maps these DOM key codes onto the project's input actions.
KEYS = {
    "right": {"code": "KeyD", "key": "d", "keyCode": 68, "windowsVirtualKeyCode": 68},
    "left": {"code": "KeyA", "key": "a", "keyCode": 65, "windowsVirtualKeyCode": 65},
    "jump": {"code": "Space", "key": " ", "keyCode": 32, "windowsVirtualKeyCode": 32},
    "light": {"code": "KeyJ", "key": "j", "keyCode": 74, "windowsVirtualKeyCode": 74},
    "heavy": {"code": "KeyK", "key": "k", "keyCode": 75, "windowsVirtualKeyCode": 75},
    "dash": {"code": "ShiftLeft", "key": "Shift", "keyCode": 16, "windowsVirtualKeyCode": 16},
    "lantern": {"code": "KeyF", "key": "f", "keyCode": 70, "windowsVirtualKeyCode": 70},
    "pause": {"code": "Escape", "key": "Escape", "keyCode": 27, "windowsVirtualKeyCode": 27},
    "enter": {"code": "Enter", "key": "Enter", "keyCode": 13, "windowsVirtualKeyCode": 13},
}


def note(message: str) -> None:
    print(message)
    print("::notice::" + message)


# --- Waiting on the game's clock, not the machine's -------------------------
#
# Godot steps a fixed 60 Hz physics clock but caps each rendered frame at
# Engine.max_physics_steps_per_frame (8 steps = 133 ms of simulation).
# Under software rendering a frame routinely costs more than that, so wall
# clock and simulation clock drift apart: time.sleep(0.52) can hand the game
# only 0.35 s of movement, take-off then happens inside the 260 px gap, and
# shot 04 comes back as empty space.
#
# The probe accumulates requestAnimationFrame deltas clamped to the same
# 8/60 s budget the engine allows. While the renderer keeps up, every delta
# sits under the cap and this tracks time.sleep() to within half a frame;
# while it stalls, the wait stretches instead of the crossing silently
# shortening. Clamped deltas never sum past wall time, so the stretch is
# the only direction game_sleep can deviate in when the engine keeps up.

PROBE_JS = """() => {
  if (window.__nhProbe) { return; }
  const CAP = 8 / 60;
  const p = {
    acc: 0, frames: 0, last: null, lastC: 0, ema: 0,
    minDelta: Infinity, maxDelta: 0, sumDelta: 0,
    winFrames: 0, winSum: 0, winAcc: 0, winMin: Infinity, winMax: 0,
  };
  p.resetWindow = () => {
    p.winFrames = 0; p.winSum = 0; p.winAcc = 0;
    p.winMin = Infinity; p.winMax = 0;
  };
  p.snapshot = () => ({
    acc: p.acc,
    frames: p.frames,
    lastC: p.lastC,
    ema: p.ema,
    minDelta: p.minDelta === Infinity ? 0 : p.minDelta,
    maxDelta: p.maxDelta,
    avgDelta: p.frames ? p.sumDelta / p.frames : 0,
    winFrames: p.winFrames,
    winAcc: p.winAcc,
    winMin: p.winMin === Infinity ? 0 : p.winMin,
    winMax: p.winMax,
    winAvg: p.winFrames ? p.winSum / p.winFrames : 0,
  });
  window.__nhProbe = p;
  const tick = (now) => {
    if (p.last !== null) {
      const d = (now - p.last) / 1000;
      const c = Math.min(d, CAP);
      p.acc += c;
      p.lastC = c;
      p.ema = p.ema === 0 ? c : p.ema + 0.25 * (c - p.ema);
      p.frames += 1;
      p.sumDelta += d;
      p.winAcc += c;
      p.winFrames += 1;
      p.winSum += d;
      if (d < p.minDelta) p.minDelta = d;
      if (d > p.maxDelta) p.maxDelta = d;
      if (d < p.winMin) p.winMin = d;
      if (d > p.winMax) p.winMax = d;
    }
    p.last = now;
    requestAnimationFrame(tick);
  };
  requestAnimationFrame(tick);
}"""


# The target is pulled back by half a frame on purpose. The probe only
# observes acc at frame boundaries and the key we send after the resolve is
# only applied on the *next* frame, so a naive "wait until acc >= start + s"
# would land one whole frame late every time and the chain of waits would
# drift the crossing off the ledge. Half a frame of headroom turns that
# one-sided bias into a symmetric +/- d/2, which is the tolerance the
# timings below were designed against. It is capped at half the requested
# duration so a stale lastC -- left over from a screenshot stall -- can
# never pull the target to or below `start` and make a short wait resolve
# on the very next frame.
SLEEP_JS = """(seconds) => new Promise((resolve) => {
  const p = window.__nhProbe;
  const start = p.acc;
  // Smoothed frame length, not the raw last one: a single stalled frame
  // right after a screenshot would otherwise over-size the pull-back and
  // make the wait that follows it come up short.
  const pull = Math.min((p.ema || p.lastC || 0) / 2, seconds / 2);
  const target = start + seconds - pull;
  const t0 = performance.now();
  let done = false;
  let timer = 0;
  const finish = () => {
    if (done) { return; }
    done = true;
    clearTimeout(timer);
    resolve({ game: p.acc - start, wall: (performance.now() - t0) / 1000 });
  };
  // Bounded so a page whose rAF loop dies cannot hang CI forever. The
  // factor is generous on purpose: at the 8/60 s physics cap a slow
  // renderer needs up to 7.5x wall time to deliver the same game time.
  timer = setTimeout(finish, (seconds * 12 + 15) * 1000);
  const check = () => {
    if (done) { return; }
    if (p.acc >= target) { finish(); return; }
    requestAnimationFrame(check);
  };
  requestAnimationFrame(check);
})"""


# (label, requested game seconds, wall seconds actually spent)
_SLEEP_LOG: list[tuple[str, float, float]] = []


def game_sleep(page, seconds: float, label: str = "") -> None:
    """Wait for `seconds` of simulation time instead of wall-clock time."""
    if seconds <= 0:
        return
    try:
        result = page.evaluate(SLEEP_JS, seconds)
    except Exception as exc:  # pragma: no cover - defensive fallback
        note(f"{label or 'game_sleep'}: evaluate failed ({exc}); using wall clock")
        time.sleep(seconds)
        _SLEEP_LOG.append((label or "?", seconds, seconds))
        return
    wall = float(result.get("wall", seconds))
    _SLEEP_LOG.append((label or "?", seconds, wall))
    if wall > seconds * 1.5 + 0.25:
        note(f"{label or 'wait'}: {seconds:.2f}s of game time needed {wall:.2f}s wall")


class InputDriver:
    """Sends raw key/mouse events through CDP, not through Playwright helpers."""

    def __init__(self, page):
        self.page = page
        self.cdp = page.context.new_cdp_session(page)

    def key(self, name: str, down: bool) -> None:
        self.cdp.send(
            "Input.dispatchKeyEvent",
            {
                "type": "keyDown" if down else "keyUp",
                **{k: v for k, v in KEYS[name].items()},
            },
        )

    def hold(self, name: str, seconds: float) -> None:
        self.key(name, True)
        # Game time, not wall time: the 2.0 s walk below is what puts the
        # Hunter at x~577, and a renderer stall during it would otherwise
        # start the crossing from the wrong place.
        game_sleep(self.page, seconds, f"hold {name} {seconds:g}s")
        self.key(name, False)

    def tap(self, name: str) -> None:
        # Deliberately *not* game_sleep: a tap only has to outlive one input
        # poll, and holding the key while the renderer stalls would desync
        # the key-down/key-up pair across unrelated frames.
        self.key(name, True)
        time.sleep(0.06)
        self.key(name, False)

    def mouse(self, x: float, y: float, button: str = "left", down: bool = True) -> None:
        buttons = 1 if down else 0
        self.cdp.send(
            "Input.dispatchMouseEvent",
            {
                "type": "mousePressed" if down else "mouseReleased",
                "x": x,
                "y": y,
                "button": button,
                "buttons": buttons,
                "clickCount": 1,
            },
        )

    def click(self, x: float, y: float, button: str = "left", pause: float = 0.08) -> None:
        self.cdp.send("Input.dispatchMouseEvent", {"type": "mouseMoved", "x": x, "y": y})
        self.mouse(x, y, button, True)
        time.sleep(pause)
        self.mouse(x, y, button, False)

    def move_to(self, x: float, y: float) -> None:
        self.cdp.send("Input.dispatchMouseEvent", {"type": "mouseMoved", "x": x, "y": y})

    def focus_canvas(self) -> None:
        """Godot only reads input once the canvas has DOM focus."""
        self.page.evaluate("() => document.querySelector('canvas').focus()")
        self.cdp.send("Input.dispatchMouseEvent", {"type": "mouseMoved", "x": 640, "y": 360})


def main() -> int:
    if len(sys.argv) < 3:
        print("usage: capture_playtest.py <build-dir> <output-dir>")
        return 2
    build_dir = os.path.abspath(sys.argv[1])
    out_dir = os.path.abspath(sys.argv[2])
    os.makedirs(out_dir, exist_ok=True)
    if not os.path.isdir(build_dir):
        print(f"build directory not found: {build_dir}")
        return 1

    from playwright.sync_api import sync_playwright

    handler = partial(http.server.SimpleHTTPRequestHandler, directory=build_dir)

    class QuietServer(socketserver.TCPServer):
        allow_reuse_address = True

        def handle_error(self, request, client_address):
            pass

    httpd = QuietServer(("127.0.0.1", 0), handler)
    port = httpd.server_address[1]
    threading.Thread(target=httpd.serve_forever, daemon=True).start()
    url = f"http://127.0.0.1:{port}/index.html"
    note(f"serving {build_dir} at {url}")

    shots: dict[str, str] = {}
    failures: list[str] = []
    console_errors: list[str] = []

    try:
        with sync_playwright() as pw:
            browser = pw.chromium.launch(
                args=["--use-gl=swiftshader", "--enable-unsafe-swiftshader", "--disable-gpu-sandbox"]
            )
            page = browser.new_page(viewport={"width": 1280, "height": 720})
            page.on("console", lambda m: console_errors.append(m.text) if m.type == "error" else None)
            page.on("pageerror", lambda e: console_errors.append(str(e)))

            page.goto(url, wait_until="load", timeout=90000)
            page.wait_for_selector("canvas", timeout=60000)
            note("canvas present; waiting for the engine to boot")
            time.sleep(20)

            # Install the game clock before any timed input. Every wait below
            # is measured against the simulation's own frame cadence rather
            # than the wall clock, so a slow renderer stretches the wait
            # instead of silently shortening it.
            page.evaluate(PROBE_JS)

            driver = InputDriver(page)
            driver.focus_canvas()

            def shot(label: str) -> None:
                path = os.path.join(out_dir, label + ".png")
                page.screenshot(path=path)
                with open(path, "rb") as fh:
                    blob = fh.read()
                # Hash the whole file. Hashing a prefix is useless here: every
                # PNG opens with the same 8-byte signature plus a fixed IHDR
                # header, so the first dozen bytes are identical in every
                # screenshot and a prefix comparison "detects duplicates" that
                # are not there.
                digest = hashlib.sha256(blob).hexdigest()[:16]
                shots[label] = digest
                note(f"captured {label} ({len(blob)} bytes, sha256 {digest})")

            # 1. Main menu. PlayButton has an initial focus owner, so Enter
            #    activates it without a mouse.
            shot("01_main_menu")

            # 2. Enter the region.
            driver.tap("enter")
            # Game time: if the region load stalls the main thread, a
            # wall-clock 6 s can be entirely consumed by the load itself and
            # shot02 catches a half-built scene.
            game_sleep(page, 6, "region load")
            shot("02_protagonist")
            # Let the screenshot's forced render finish before any timed input.
            # page.screenshot() competes with the game loop for the main thread
            # under software rendering, and if the game is still catching up
            # when the walk starts, wall-clock sleeps under-count physics frames
            # and the Hunter ends up short of the gap.
            game_sleep(page, 1.0, "settle after shot02")

            # 3. Move right to show the environment scrolling, then shoot wide.
            #    Ground west spans x -700..700 and the steps (x 430..610) float
            #    80 px overhead, so this walk passes cleanly beneath them.
            driver.hold("right", 2.0)
            # Friction needs 0.096 s of *game* time to stop from run_speed;
            # a wall-clock settle can expire before one slow frame elapses.
            game_sleep(page, 0.5, "friction stop")
            shot("03_environment")
            # Same settle, and this one is critical: the crossing below is timed
            # to the frame, and it starts immediately after this screenshot.
            # Game time, so a renderer stall here extends the settle instead
            # of letting the crossing start while the engine is still behind.
            game_sleep(page, 1.2, "settle after shot03")

            # 4. Cross the 260 px gap. Every number here comes from
            #    tools/simulate_traversal.py, not from guesswork:
            #
            #      after step 3      player rests at x ~577 (2.0 s walk from
            #                        spawn 120, then friction stops it)
            #      take-off window   x 642..723 -> walk 0.35..0.69 s from rest,
            #                        centre 0.52 s (was 0.47, which sat only
            #                        120 ms from the early edge -- the side
            #                        that fails when the game hitches)
            #      apex              0.439 s; releasing earlier hits
            #                        release_jump() -> velocity * 0.45 jump cut
            #      dash window       0.45..0.80 s after take-off, centre 0.62 s
            #                        -> full 318 px anywhere inside it
            #      airtime           1.117 s, landing x ~990 on ground mid
            driver.key("right", True)
            game_sleep(page, 0.52, "walk to take-off")
            driver.key("jump", True)
            game_sleep(page, 0.62, "jump rise")   # past apex, so the cut cannot fire
            driver.tap("dash")        # dash duration is timer-driven, a tap is enough
            driver.key("jump", False)
            game_sleep(page, 0.55, "airtime")     # 1.17 s > 1.117 s airtime: landed
            # Ground mid runs 960..1860; the second nightmare (borrowed_face,
            # a mimic) spawns at 1720 and patrols +/-140 -> 1580..1860.
            #
            # Landing is x~1012, so 2.38 s at run_speed stops at x~1559 --
            # LEFT of the whole patrol range. That guarantees the enemy is
            # always ahead (21..301 px right) and inside its 340 px detect
            # radius, so it closes in rather than ending up behind the Hunter.
            # Stopping at 2.9 s (x~1679) sat inside the patrol band instead,
            # which is why the first good run showed a swing at empty air.
            game_sleep(page, 2.38, "walk to enemy")
            driver.key("right", False)
            game_sleep(page, 0.5, "friction stop before shot04")
            # One line of evidence: if the renderer is the culprit, this is
            # where it shows up. r well below 1 means wall-clock sleeps were
            # under-feeding the simulation during the crossing above.
            _snap = page.evaluate("() => window.__nhProbe.snapshot()")
            if _snap and _snap.get("frames"):
                note(
                    f"game clock: {_snap['frames']} frames, "
                    f"avg {_snap['avgDelta'] * 1000:.0f} ms, "
                    f"max {_snap['maxDelta'] * 1000:.0f} ms "
                    f"(r = {_snap['acc'] / max(_snap['avgDelta'] * _snap['frames'], 1e-9):.2f})"
                )
            shot("04_enemy_encounter")

            # 5. Attack. The mimic investigates for 1.4 s, then pursues at
            #    move_speed * 0.55 = 72.6 px/s until it sits at its own 58 px
            #    attack range. Worst case it starts 301 px out, so closing
            #    takes 1.4 + 243/72.6 = 4.75 s -- 4.5 s left it ~78 px away,
            #    past the 54 px hitbox, and the swing hit nothing.
            #    Player has 100 HP against 12 damage, so waiting is safe.
            game_sleep(page, 5.5, "enemy approach")
            # Step in so the 52-wide hitbox (reaching 54 px right of the
            # origin) overlaps the 26-wide enemy hurtbox. Player and nightmare
            # masks are both 1 (world only), so they pass through each other
            # rather than colliding -- overshooting would walk straight past.
            driver.key("right", True)
            game_sleep(page, 0.10, "step in")
            driver.key("right", False)
            game_sleep(page, 0.3, "settle after step-in")

            # Aim first, then swing: _aim_from_mouse() reads the cursor in
            # _physics_process, so moving the mouse and clicking in the same
            # instant can attack before the facing flips. The 14 px deadzone
            # means the cursor must sit clearly right of centre.
            driver.move_to(900, 430)
            game_sleep(page, 0.25, "aim settle")

            # Swing 1 -- catch the procedural SlashArc. attack_started fires at
            # the START of startup, and the arc lives 0.11 + (32/46)*0.03 =
            # 0.131 s total, so the screenshot has to be requested well inside
            # that. That budget is in *simulation* seconds, so the waits here
            # are game time too.
            driver.click(900, 430, pause=0.02)
            game_sleep(page, 0.04, "arc window")
            shot("05_combat_effects")

            # Swing 2 -- catch the hit. Recovery ends by ~0.50 s even for the
            # slowest blade; the hurt flash starts on contact and decays at
            # 5.0/s from 1.0 (0.2 s of life), and damage_system spawns a
            # second SlashArc on the target at the same moment.
            game_sleep(page, 0.60, "recovery")
            driver.click(900, 430, pause=0.02)
            game_sleep(page, 0.20, "flash window")
            shot("05b_combat_hit")
            driver.tap("dash")
            game_sleep(page, 0.6, "post-dash")

            # 6. Pause.
            driver.tap("pause")
            game_sleep(page, 1.5, "pause settle")
            shot("06_pause_menu")

            browser.close()
    finally:
        httpd.shutdown()

    real_errors = [
        e for e in console_errors
        if "AudioContext" not in e and "was not allowed to start" not in e
    ]
    if real_errors:
        note(f"{len(real_errors)} console/page error(s)")
        for line in real_errors[:20]:
            print("::error::" + line[:300])
        failures.append(f"{len(real_errors)} console/page error(s)")

    missing = [name for name in REQUIRED if name not in shots]
    if missing:
        failures.append("missing shots: " + ", ".join(missing))

    # A shot of the player falling through the void is a smooth vertical
    # gradient with almost no edges. Any frame with content in it -- platforms,
    # HUD, a menu -- has many more. Measured against the run that produced the
    # bad frames: void shots score ~275 edges, genuine playtest frames score
    # 1333 or more. The threshold sits well clear of both.
    try:
        from PIL import Image

        for name, path in sorted(
            (k, os.path.join(out_dir, k + ".png")) for k in shots
        ):
            if not os.path.exists(path):
                continue
            gray = Image.open(path).convert("L").resize((160, 90))
            pixels = list(gray.tobytes())
            edges = sum(
                1
                for y in range(1, 90)
                for x in range(1, 160)
                if abs(pixels[y * 160 + x] - pixels[y * 160 + x - 1]) > 6
                or abs(pixels[y * 160 + x] - pixels[(y - 1) * 160 + x]) > 6
            )
            if edges < 600:
                failures.append(
                    f"{name}: looks like empty space ({edges} edges); "
                    "likely a void frame, not a playtest shot"
                )
    except ImportError:
        note("Pillow unavailable — skipping the void-frame check")

    # Two screenshots of different scenes must not be byte-identical, or the
    # "capture" is really a stuck frame.
    if len(set(shots.values())) < len(shots):
        failures.append("duplicate screenshot content detected — frames may be stuck")

    if failures:
        print("\nFAILED:")
        for message in failures:
            print("  - " + message)
        return 1
    note(f"captured {len(shots)} distinct frames of the running game")
    return 0


if __name__ == "__main__":
    sys.exit(main())
