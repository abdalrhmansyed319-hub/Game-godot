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

## Current status

**Prototype stage (GDD §22) is implemented.** See the root `README.md`.

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
| Cross-reference / data integrity | `python3 tools/check_project.py` | Passing; validated by 10 injected faults |
| Real engine load (parse all scripts, resolve all scenes) | CI: `.github/workflows/godot.yml` | Runs on push |
| Autoload boot + content manifest | CI: headless `--quit-after` | Runs on push |
| Playtest / game feel | Manual, in the editor | **Not done** |

The Godot engine binary cannot be downloaded inside the agent sandbox, so the
engine-level checks run in GitHub Actions rather than locally.

### Next steps
1. Open in Godot 4.7, playtest, tune movement and combat feel.
2. Add `export_presets.cfg` and produce the first Web build into `04 - Builds`.
3. Replace placeholder primitives with sprites from `02 - Art & Assets`.
4. Vertical slice: dialogue, one NPC, endings.

---
Created 2026-11-21.
