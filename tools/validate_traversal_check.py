#!/usr/bin/env python3
"""Fault-inject the ORIGINAL broken geometry into the simulator and prove it fails.

Three-state validation: the check must pass on the fixed geometry, fail on the
broken geometry, and pass again after restore. A check that only ever passes is
not evidence of anything.
"""
import subprocess
import sys

PATH = "tools/simulate_traversal.py"
src = open(PATH, encoding="utf-8").read()

# The values the level shipped with before the fix.
FIXED = '''    ("ground mid", (1410, 0), (900, 40)),'''
BROKEN = '''    ("ground mid", (1520, 0), (900, 40)),'''
assert src.count(FIXED) == 1, "fixed ground mid line not found exactly once"

STEP_FIXED = '''    ("step 1", (520, -88), (180, 24)),
    ("step 2", (780, -168), (180, 24)),
    ("step 3", (1040, -248), (220, 24)),
    ("wall mid", (1900, 0), (40, 200)),'''
STEP_BROKEN = '''    ("step 1", (520, -110), (180, 24)),
    ("step 2", (780, -210), (180, 24)),
    ("step 3", (1040, -320), (220, 24)),
    ("wall mid", (1900, -140), (40, 280)),'''
assert src.count(STEP_FIXED) == 1, "fixed step block not found exactly once"


def run() -> int:
    return subprocess.run([sys.executable, PATH], capture_output=True).returncode


results = {}
try:
    results["fixed geometry"] = run()

    open(PATH, "w", encoding="utf-8").write(src.replace(FIXED, BROKEN))
    results["broken gap only"] = run()

    open(PATH, "w", encoding="utf-8").write(
        src.replace(FIXED, BROKEN).replace(STEP_FIXED, STEP_BROKEN)
    )
    results["all original geometry"] = run()

    # Only the steps broken, gap left fixed: must still fail.
    open(PATH, "w", encoding="utf-8").write(src.replace(STEP_FIXED, STEP_BROKEN))
    results["broken steps only"] = run()
finally:
    open(PATH, "w", encoding="utf-8").write(src)
    results["restored"] = run()

expected = {
    "fixed geometry": 0,
    "broken gap only": 1,
    "all original geometry": 1,
    "broken steps only": 1,
    "restored": 0,
}
ok = True
for name, code in results.items():
    good = code == expected[name]
    ok = ok and good
    print(f"  {name:<24} exit {code}  expected {expected[name]}  {'OK' if good else 'MISMATCH'}")
print("\nVALIDATION " + ("PASSED" if ok else "FAILED"))
sys.exit(0 if ok else 1)
