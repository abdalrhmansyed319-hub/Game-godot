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

import base64
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
                    digest = base64.b64encode(fh.read()).decode()[:16]
                shots[label] = digest
                note(f"captured {label} ({os.path.getsize(path)} bytes, b64 head {digest})")

            # 1. Main menu. PlayButton has an initial focus owner, so Enter
            #    activates it without a mouse.
            shot("01_main_menu")

            # 2. Enter the region.
            driver.tap("enter")
            time.sleep(6)
            shot("02_protagonist")

            # 3. Move right to show the environment scrolling, then shoot wide.
            driver.hold("right", 1.4)
            time.sleep(1.0)
            shot("03_environment")

            # 4. Keep moving east toward the nightmare that spawns at x=1720.
            #    This is the longest walk; the shots along the way are real.
            for _ in range(6):
                driver.hold("right", 1.2)
                time.sleep(0.25)
            driver.tap("jump")
            time.sleep(0.8)
            shot("04_enemy_encounter")

            # 5. Attack. Mouse-down on the canvas is the light attack, so this
            #    exercises the real aim path including the deadzone.
            driver.focus_canvas()
            driver.click(860, 360)
            time.sleep(0.12)
            shot("05_combat_effects")
            driver.tap("heavy")
            time.sleep(0.10)
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
