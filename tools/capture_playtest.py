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
        time.sleep(seconds)
        self.key(name, False)

    def tap(self, name: str) -> None:
        self.hold(name, 0.06)

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
            time.sleep(6)
            shot("02_protagonist")

            # 3. Move right to show the environment scrolling, then shoot wide.
            #    Ground west spans x -700..700 and the steps (x 430..610) float
            #    80 px overhead, so this walk passes cleanly beneath them.
            driver.hold("right", 2.0)
            time.sleep(0.5)
            shot("03_environment")

            # 4. Cross the 260 px gap. Every number here comes from
            #    tools/simulate_traversal.py, not from guesswork:
            #
            #      after step 3      player rests at x ~577 (2.0 s walk from
            #                        spawn 120, then friction stops it)
            #      take-off window   x 642..700 -> walk 0.35..0.59 s from rest,
            #                        centre 0.47 s -> x ~672 (+/-120 ms slack)
            #      apex              0.439 s; releasing earlier hits
            #                        release_jump() -> velocity * 0.45 jump cut
            #      dash frame 39     0.65 s after take-off -> full 318 px
            #      airtime           1.117 s, landing x ~990 on ground mid
            driver.key("right", True)
            time.sleep(0.47)
            driver.key("jump", True)
            time.sleep(0.65)          # past apex, so the cut cannot fire
            driver.tap("dash")        # dash duration is timer-driven, a tap is enough
            driver.key("jump", False)
            time.sleep(0.50)          # 1.21 s > 1.117 s airtime: landed
            # Ground mid runs 960..1860; the second nightmare (borrowed_face,
            # a mimic) spawns at 1720 and patrols +/-140 -> 1580..1860.
            #
            # Landing is x~1012, so 2.38 s at run_speed stops at x~1559 --
            # LEFT of the whole patrol range. That guarantees the enemy is
            # always ahead (21..301 px right) and inside its 340 px detect
            # radius, so it closes in rather than ending up behind the Hunter.
            # Stopping at 2.9 s (x~1679) sat inside the patrol band instead,
            # which is why the first good run showed a swing at empty air.
            time.sleep(2.38)
            driver.key("right", False)
            time.sleep(0.5)
            shot("04_enemy_encounter")

            # 5. Attack. The mimic investigates for 1.4 s, then pursues at
            #    move_speed * 0.55 = 72.6 px/s until it sits at its own 58 px
            #    attack range. Worst case it starts 301 px out, so closing
            #    takes 1.4 + 243/72.6 = 4.75 s -- 4.5 s left it ~78 px away,
            #    past the 54 px hitbox, and the swing hit nothing.
            #    Player has 100 HP against 12 damage, so waiting is safe.
            time.sleep(5.5)
            # Step in so the 52-wide hitbox (reaching 54 px right of the
            # origin) overlaps the 26-wide enemy hurtbox. Player and nightmare
            # masks are both 1 (world only), so they pass through each other
            # rather than colliding -- overshooting would walk straight past.
            driver.key("right", True)
            time.sleep(0.10)
            driver.key("right", False)
            time.sleep(0.3)

            # Aim first, then swing: _aim_from_mouse() reads the cursor in
            # _physics_process, so moving the mouse and clicking in the same
            # instant can attack before the facing flips. The 14 px deadzone
            # means the cursor must sit clearly right of centre.
            driver.move_to(900, 430)
            time.sleep(0.25)

            # Swing 1 -- catch the procedural SlashArc. attack_started fires at
            # the START of startup, and the arc lives 0.11 + (32/46)*0.03 =
            # 0.131 s total, so the screenshot has to be requested well inside
            # that. page.screenshot() itself takes time, hence the short sleep.
            driver.click(900, 430, pause=0.02)
            time.sleep(0.04)
            shot("05_combat_effects")

            # Swing 2 -- catch the hit. Recovery ends by ~0.50 s even for the
            # slowest blade; the hurt flash starts on contact and decays at
            # 5.0/s from 1.0 (0.2 s of life), and damage_system spawns a
            # second SlashArc on the target at the same moment.
            time.sleep(0.60)
            driver.click(900, 430, pause=0.02)
            time.sleep(0.20)
            shot("05b_combat_hit")
            driver.tap("dash")
            time.sleep(0.6)

            # 6. Pause.
            driver.tap("pause")
            time.sleep(1.5)
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
