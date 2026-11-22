# Game Godot Project — Central Hub

This Drive folder is the center for the **Game-godot** project. Everything project-related lives here.

## Repository
- GitHub: https://github.com/abdalrhmansyed319-hub/Game-godot
- Working branch: `arena/c01b8ea4-game-godot` (based on `main`, commit `528aba3`)
- Engine: Godot 4.x

## Folder structure
| Folder | What goes here |
| --- | --- |
| 00 - START HERE | This file, status updates, quick links |
| 01 - Design & Docs | Game design document, mechanics, levels, story, balance |
| 02 - Art & Assets | Sprites, tilesets, UI mockups, concept art, icons |
| 03 - Audio | Music, sound effects, voice |
| 04 - Builds & Releases | Exported builds (Windows / Linux / Web / Android) |
| 05 - Godot Project Source | Zipped snapshots of the project (scenes, scripts, project.godot) |
| 06 - Tasks & Notes | Task lists, sprint plans, playtest feedback |
| 07 - Marketing & Media | Screenshots, trailer, store copy, social assets |

## Conventions
1. Source of truth for code is GitHub. Drive holds design, assets, builds and notes.
2. Snapshot the Godot project into `05 - Godot Project Source` as `game-godot_YYYY-MM-DD.zip`.
3. Name builds `GameGodot_v0.1.0_platform.zip` so versions sort correctly.
4. Keep large art/audio sources in Drive, export-ready versions in the repo.

## Documents

| Document | What it is |
| --- | --- |
| [`NIGHTMARE_HUNTER-GDD.md`](NIGHTMARE_HUNTER-GDD.md) | The full original design. Long-term vision and creative authority. |
| [`NIGHTMARE_HUNTER_OPENGAME_JAM_GDD.md`](NIGHTMARE_HUNTER_OPENGAME_JAM_GDD.md) | **What we are actually shipping.** Jam scope, cut list with reasons, verified competition constraints, milestones, acceptance criteria. |

## Current status

**Prototype stage (GDD §22) is implemented and now compiles under the real
engine.** See the root `README.md`.

- Godot 4.7 project: 39 scripts, 6 scenes, 21 authored data files.
- Systems layer complete: combat, Resonance/Revelation, the three instruments,
  nightmare AI, progression, Echoes, journal, quests, decisions, saves,
  distortion, Quiet Room checkpoints.
- Content: 3 nightmares (incl. The Bell Without a Tongue boss), 4 Echoes,
  3 blade forms, 9 skills, 2 quests, 1 region.
- Art and audio are engine-generated placeholders.
- Web export not yet configured.

### Verification

| Check | How | Status |
| --- | --- | --- |
| Cross-reference / data integrity | `python3 tools/check_project.py` | **Passing**; each rule validated by injecting a known fault |
| Real engine load (parse all scripts, resolve all scenes) | CI: Godot 4.7.2 headless `--import` | **Passing** |
| Autoload boot + content manifest | CI: headless `--quit-after 6` | **Passing** |
| Web export + jam constraints | CI: `--export-release "Web"` + `tools/web_export_checks.py` | **Passing** |
| Runs in a real browser | CI: Playwright/Chromium over plain HTTP | **Passing** (run 45012352644) |
| Every script parses | `gdparse` 4.5.0 over all 52 scripts | **Passing** |
| Playtest / game feel | Manual, in the editor | **Not done** |

A green `verify` job is *not* evidence the scripts parse. On four consecutive
commits `verify` passed while `web` failed, because `--export-release` parses
more of the project than `--quit-after 6` does. Treat `web` as the authority.

### M1 — Combat & movement feel: measured results

Verified on `c472df6`, CI run `45012352644` (both jobs green). Full detail and
the playtest plan are in [`M1_PLAYTEST_REPORT.md`](M1_PLAYTEST_REPORT.md).

| Measurement | Result | Jam limit |
| --- | --- | --- |
| First-frame payload | **38.36 MB** / 9 files | < 50 MB |
| Growth over M2 | +0.19 MB | — |
| Canvas / resize / console errors | 1280×720, resizes to 960×600, none | — |
| Human playtest | **not done** | — |

Every placeholder `ColorRect` is replaced by procedural `_draw()` art and all
audio is synthesised at runtime, so the art pass added no assets. The 0.19 MB
is compiled script.

Physics changes are recorded in [`PHYSICS_NOTES.md`](PHYSICS_NOTES.md), per the
standing rule that no major physics change goes undocumented.

### M2 — Web export: measured results

| Measurement | Result | Jam limit |
| --- | --- | --- |
| Loads in headless Chromium over plain HTTP | yes, no COOP/COEP headers | required |
| Canvas | 1280×720 | — |
| Resize | 1280×720 → 960×600 | must respond to resize |
| Console / page errors | none | — |
| Thread support | none (no `worker.js`) | avoids `SharedArrayBuffer` |
| `.pck` | unencrypted, GDPC magic | encrypted packs are rejected |
| First-frame payload | **38.17 MB** / 9 files | < 50 MB — ~12 MB headroom |

**Risk R1 is retired.** A single-threaded Godot 4 Web export runs on plain
static hosting, which is what OpenGame serves. The payload is almost entirely
the Godot Web runtime; game data is negligible, so headroom grows slowly, but
it must be watched as content is added.

Not yet proven: that a *frame is visibly rendered*. The test asserts the canvas
exists, has dimensions, and resizes, with no console or page errors. It does not
yet sample pixels. `boot.png` and `resized.png` are attached to the CI run.

The Godot engine binary cannot be downloaded inside the agent sandbox
(`github.com` release assets redirect to `objects.githubusercontent.com`, which
is blocked), so the engine-level checks run in GitHub Actions. Their errors are
republished as check-run annotations because Actions log storage is not
reachable from the sandbox either.

### Bugs the engine found that static checks missed

Worth recording, because both produced misleading cascades:

1. `enum Path` shadowed Godot's built-in `Path` class.
2. Renaming it did not help — an enum inside one script is **not** globally
   addressable in Godot 4; only `class_name` is.

Both surfaced as `Failed to compile depended scripts` across four unrelated
files plus a runtime `Nonexistent function 'from_dict'`. `tools/check_project.py`
now has rules for both.

### Next steps
1. Open in Godot 4.7, playtest, tune movement and combat feel.
2. Add `export_presets.cfg` and produce the first Web build into `04 - Builds`.
3. Replace placeholder primitives with sprites from `02 - Art & Assets`.
4. Vertical slice: dialogue, one NPC, endings.

---
Created 2026-11-21.
