#!/usr/bin/env python3
"""Assertions on the exported Web build, against OpenGame Jam requirements.

Run after `godot --export-release "Web"` with the build directory as argv[1].
Exit code 0 = every hard requirement met.

Checks (from opengame.io/rules, verified 21 Nov 2026):
  * index.html exists at the root of the build folder
  * total bytes before first playable frame < 50 MB (warns at review)
  * the build is NOT thread-enabled, so it does not require SharedArrayBuffer
    and therefore does not need COOP/COEP headers we cannot set on a static host
  * the .pck is not encrypted (encrypted packs are rejected: they cannot be
    malware-scanned)
"""

from __future__ import annotations

import os
import sys

MAX_FIRST_FRAME_BYTES = 50 * 1024 * 1024


def human(n: int) -> str:
    return f"{n / (1024 * 1024):.2f} MB"


def note(message: str) -> None:
    """Print, and also publish as a CI annotation.

    Actions stores job logs on blob storage that is unreachable from some
    networks, while check-run annotations come from api.github.com. Anything
    worth reporting has to go out as an annotation to be readable at all.
    """
    print(message)
    print("::notice::" + message)


def main() -> int:
    if len(sys.argv) < 2:
        print("usage: web_export_checks.py <build-dir>")
        return 2
    root = sys.argv[1]
    failures: list[str] = []

    if not os.path.isdir(root):
        print(f"build directory not found: {root}")
        return 1

    files = {}
    for dirpath, _dirs, names in os.walk(root):
        for name in names:
            full = os.path.join(dirpath, name)
            files[os.path.relpath(full, root)] = os.path.getsize(full)

    print(f"build directory: {root}")
    print(f"file count: {len(files)}")
    for name in sorted(files):
        print(f"  {human(files[name]):>10}  {name}")

    # --- index.html at root -------------------------------------------------
    if "index.html" not in files:
        failures.append("index.html is missing from the root of the build folder")
    else:
        print("OK  index.html present at build root")

    if files.get("index.html", 0) < 500:
        failures.append("index.html is suspiciously small; export may be incomplete")

    # --- first-frame download size -----------------------------------------
    # Everything the shell needs before the game can draw: html, wasm, js, pck.
    core = [n for n in files if n.endswith((".html", ".wasm", ".js", ".pck", ".png", ".svg", ".json"))]
    first_frame = sum(files[n] for n in core)
    total = sum(files.values())
    note(f"first-frame payload {human(first_frame)} of {human(MAX_FIRST_FRAME_BYTES)} budget")
    note(f"total build size {human(total)} across {len(files)} files")
    if first_frame >= MAX_FIRST_FRAME_BYTES:
        failures.append(
            f"first-frame payload is {human(first_frame)}, over the {human(MAX_FIRST_FRAME_BYTES)} target"
        )

    # --- thread support -----------------------------------------------------
    # A thread-enabled Godot web build spawns a Worker and needs
    # SharedArrayBuffer, which browsers only expose under COOP/COEP headers.
    # OpenGame serves static files we do not control, so the build must be
    # single-threaded. The export emits <name>.worker.js when threads are on.
    workers = [n for n in files if n.endswith(".worker.js")]
    if workers:
        failures.append(
            f"build is thread-enabled ({', '.join(workers)}); it will require "
            "SharedArrayBuffer and COOP/COEP headers a static host cannot provide. "
            'Set variant/thread_support=false in export_presets.cfg.'
        )
    else:
        note("no worker script: build is single-threaded, so no COOP/COEP headers are needed")

    js = [n for n in files if n.endswith(".js")]
    for name in js:
        with open(os.path.join(root, name), encoding="utf-8", errors="replace") as handle:
            text = handle.read()
        if "SharedArrayBuffer" in text:
            print(f"WARN  {name} mentions SharedArrayBuffer; confirm it is not required at runtime")

    # --- unencrypted pck ----------------------------------------------------
    pcks = [n for n in files if n.endswith(".pck")]
    if not pcks:
        print("NOTE  no .pck file; game data may be embedded in the html/js")
    for name in pcks:
        with open(os.path.join(root, name), "rb") as handle:
            magic = handle.read(4)
        if magic != b"GDPC":
            failures.append(
                f"{name} does not start with the GDPC magic (got {magic!r}); "
                "it is encrypted or corrupt. Encrypted packs are rejected by the jam."
            )
        else:
            print(f"OK  {name} is unencrypted (GDPC magic present)")

    # --- file count ---------------------------------------------------------
    if len(files) > 25000:
        failures.append(f"{len(files)} files exceeds the 25,000 file limit")

    if failures:
        print("\nFAILED:")
        for message in failures:
            print(f"  - {message}")
        return 1
    print("\nOK: web build satisfies the OpenGame hard requirements checked here")
    return 0


if __name__ == "__main__":
    sys.exit(main())
