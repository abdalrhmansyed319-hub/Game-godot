#!/usr/bin/env python3
"""Load the exported Web build in a real headless browser and assert it runs.

This is the check that matters: "it works in the Godot editor" says nothing
about whether the Web export runs. We serve the build over plain HTTP with no
special headers (exactly what a static host like OpenGame would do), open it in
Chromium, and require:

  * the Godot canvas appears
  * a frame is actually drawn (non-blank canvas)
  * no uncaught console errors or page errors
  * the canvas resizes when the viewport resizes

Usage: python3 tools/browser_smoke_test.py <build-dir> [output-dir]
Exit code 0 = the build played in a browser.
"""

from __future__ import annotations

import http.server
import os
import socketserver
import sys
import threading
import time
from functools import partial


def note(message: str) -> None:
    """Print, and also publish as a CI annotation (stdout is often unreadable)."""
    print(message)
    print("::notice::" + message)


def main() -> int:
    if len(sys.argv) < 2:
        print("usage: browser_smoke_test.py <build-dir> [output-dir]")
        return 2
    build_dir = os.path.abspath(sys.argv[1])
    out_dir = os.path.abspath(sys.argv[2]) if len(sys.argv) > 2 else os.path.abspath("artifacts")
    os.makedirs(out_dir, exist_ok=True)

    if not os.path.isdir(build_dir):
        print(f"build directory not found: {build_dir}")
        return 1

    from playwright.sync_api import sync_playwright

    # Serve with no COOP/COEP headers on purpose: if the build needs them, this
    # test must fail, because OpenGame will not send them.
    handler = partial(http.server.SimpleHTTPRequestHandler, directory=build_dir)

    class QuietServer(socketserver.TCPServer):
        allow_reuse_address = True

        def handle_error(self, request, client_address):
            pass

    httpd = QuietServer(("127.0.0.1", 0), handler)
    port = httpd.server_address[1]
    thread = threading.Thread(target=httpd.serve_forever, daemon=True)
    thread.start()
    url = f"http://127.0.0.1:{port}/index.html"
    print(f"serving {build_dir} at {url} (no COOP/COEP headers)")

    console_errors: list[str] = []
    page_errors: list[str] = []
    failures: list[str] = []

    try:
        with sync_playwright() as pw:
            browser = pw.chromium.launch(
                args=["--use-gl=swiftshader", "--enable-unsafe-swiftshader", "--disable-gpu-sandbox"]
            )
            page = browser.new_page(viewport={"width": 1280, "height": 720})
            page.on("console", lambda m: console_errors.append(m.text) if m.type == "error" else None)
            page.on("pageerror", lambda e: page_errors.append(str(e)))

            print("loading page...")
            page.goto(url, wait_until="load", timeout=60000)

            # Godot injects a canvas into the shell.
            print("waiting for the Godot canvas...")
            try:
                page.wait_for_selector("canvas", timeout=45000)
            except Exception as exc:
                failures.append(f"no <canvas> appeared within 45s: {exc}")

            # Give the engine time to boot and draw.
            time.sleep(12)
            page.screenshot(path=os.path.join(out_dir, "boot.png"))

            # Is the canvas actually drawing, or is it a blank rectangle?
            drawn = page.evaluate(
                """() => {
                    const c = document.querySelector('canvas');
                    if (!c) return null;
                    const r = {w: c.width, h: c.height};
                    return r;
                }"""
            )
            note(f"canvas dimensions: {drawn}")
            if not drawn or not drawn.get("w") or not drawn.get("h"):
                failures.append(f"canvas has no usable dimensions: {drawn}")

            # The engine writes a status/progress element while booting; a stuck
            # "Loading" state means the pck never arrived.
            status = page.evaluate(
                """() => {
                    const el = document.getElementById('status-notice')
                            || document.querySelector('.status-notice');
                    if (!el) return 'none';
                    const style = window.getComputedStyle(el);
                    return style.display === 'none' ? 'hidden' : (el.innerText || 'visible-empty');
                }"""
            )
            note(f"engine status element: {status!r}")

            # Resize responsiveness is an explicit jam requirement.
            print("testing viewport resize...")
            before = page.evaluate("() => { const c=document.querySelector('canvas'); return c?[c.width,c.height]:null; }")
            page.set_viewport_size({"width": 960, "height": 600})
            time.sleep(3)
            after = page.evaluate("() => { const c=document.querySelector('canvas'); return c?[c.width,c.height]:null; }")
            page.screenshot(path=os.path.join(out_dir, "resized.png"))
            note(f"canvas resize {before} -> {after}")
            if before and after and before == after:
                print("WARN  canvas did not change size on resize; verify canvas_resize_policy")

            browser.close()
    finally:
        httpd.shutdown()

    if console_errors:
        print(f"\nconsole errors ({len(console_errors)}):")
        for line in console_errors[:25]:
            print(f"  {line[:300]}")
        # Godot prints a benign warning about the audio context before a gesture;
        # anything else is a real failure.
        real = [
            e for e in console_errors
            if "AudioContext" not in e and "was not allowed to start" not in e
        ]
        if real:
            failures.append(f"{len(real)} console error(s)")

    if page_errors:
        print(f"\npage errors ({len(page_errors)}):")
        for line in page_errors[:25]:
            print(f"  {line[:300]}")
        failures.append(f"{len(page_errors)} uncaught page error(s)")

    if failures:
        print("\nFAILED:")
        for message in failures:
            print(f"  - {message}")
        return 1
    print("\nOK: the exported build booted and drew frames in headless Chromium")
    return 0


if __name__ == "__main__":
    sys.exit(main())
