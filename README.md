# Chronoflora

A temporal botanical simulation game — Vertical Slice

## Overview

Chronoflora is a PC game where you tend a single garden across five collapsed eras of one forgotten civilization. Plants are temporal anchors: actions in one era physically reshape the world of eras yet to come.

**Genre:** Narrative-driven temporal botanical simulation  
**Platform:** PC (Godot 4.x)  
**Visual Style:** High-quality pixel art  
**Required Godot Version:** 4.7.2-stable or later 4.x

---

## Vertical Slice Contents

This vertical slice includes:

- **Era 1: Pre-Bloom** — Primordial wetland with bioluminescent flora
- **Era 2: Rooted Age** — Sylthene civilization at its height
- **Zones:** Central Glade, Root Terrace
- **6 Plant Species:** Ember Moss, Whisper Fern, Sun-pitcher, Mud-lily, Thornvine, Sylthene Oak
- **Core Systems:** Gardening, era shifting, cross-era persistence, botanical journal, save/load
- **Environmental Puzzle:** Root Lock (grow Thornvine in Era 1 to crack stone wall in Era 2)

---

## How to Run in Godot 4.x

### Prerequisites
- Godot 4.7.2 or later (download from https://godotengine.org/)
- No additional dependencies required

### Installation & Execution

1. **Download Godot 4.x** from https://godotengine.org/download
2. **Open the project:** Launch Godot, click "Import", select this repository folder (the one containing `project.godot`)
3. **Run:** Press **F5** or click the **Play** button in the top-right
4. **Main scene:** `res://scenes/Main.tscn` (set as main scene in `project.godot`)

### Controls

| Key | Action |
|-----|--------|
| WASD / Arrow Keys | Move the Keeper |
| 1-6 | Select seed type (1=Ember Moss, 2=Whisper Fern, 3=Sun-pitcher, 4=Mud-lily, 5=Thornvine, 6=Sylthene Oak) |
| Left Click | Plant seed on soil / interact with objects |
| W | Water plants |
| E | Shift era (at Anchor Stone) |
| J | Open Botanical Journal |
| ESC | Pause / Return to main menu |

---

## How to Run the Python/Pygame Prototype

A Python/Pygame prototype is available in `prototype/` for immediate playtesting without Godot.

**Requirements:** Python 3.11+, pygame

```bash
cd prototype
python3 main.py
```

The prototype implements identical gameplay logic and has a 43-test verification suite (`test_mechanics.py`).

---

## Project Structure

```
Game-godot/
├── project.godot              # Godot project configuration (at repository root)
├── README.md                  # This file
├── .gitignore                 # Godot, Python, and OS ignore rules
├── docs/                      # Design and validation documents
│   ├── CONCEPTS_PHASE_1.md
│   ├── CONCEPTS_EVALUATION_PHASE_2.md
│   ├── CHRONOFLORA_CREATIVE_VISION.md
│   ├── CHRONOFLORA_COMPLETE_GDD.md
│   ├── GODOT_AUDIT.md
│   ├── GODOT_VALIDATION_CHECKLIST.md
│   └── VERTICAL_SLICE_REPORT.md
├── scenes/                    # Godot scenes (.tscn)
│   ├── Main.tscn              # Entry scene
│   ├── Game.tscn              # Main gameplay scene
│   └── MainMenu.tscn          # Main menu
├── scripts/                   # Godot scripts (.gd)
│   ├── GameManager.gd         # Core gameplay logic
│   ├── Player.gd              # Keeper character
│   ├── HUD.gd                 # Heads-up display
│   ├── Journal.gd             # Botanical journal UI
│   ├── EraManager.gd          # Era shifting logic
│   ├── SaveSystem.gd          # JSON save/load
│   └── MainMenu.gd            # Main menu logic
│   └── tests/                 # Godot test scripts (NOT executed)
│       ├── TestRunner.gd
│       ├── PlantGrowthTest.gd
│       ├── EraSwitchingTest.gd
│       ├── PersistenceTest.gd
│       ├── RootEchoTest.gd
│       ├── SaveLoadTest.gd
│       └── InvalidPlantingTest.gd
├── assets/                    # Game assets
│   ├── images/
│   │   ├── player/            # Keeper sprite sheet (4 dirs × 4 frames)
│   │   ├── plants/            # 6 species × 4 growth stages = 24 sprites
│   │   ├── environments/      # 8 tile types × 2 eras + TileSet
│   │   ├── ui/                # HUD, buttons, panels, icons
│   │   └── effects/           # Particles
│   └── sounds/                # (empty — future phase)
├── autoload/                  # (empty — ready for autoloads)
├── saves/                     # Save game files (created at runtime)
├── tools/                     # Asset generation scripts
│   └── generate_assets.py     # Pixel art generator
├── prototype/                 # Python/Pygame playable prototype (SEPARATE)
│   ├── main.py
│   ├── game.py
│   ├── player.py
│   ├── plant.py
│   ├── era_manager.py
│   ├── journal.py
│   ├── save_system.py
│   ├── ui.py
│   └── test_mechanics.py      # 43 tests — ALL PASSED
└── .venv/                     # Python virtual environment (prototype only)
```

---

## Implemented Features

✅ **Core gameplay loop:** Observe → Tend → Record → Shift → Discover → Preserve  
✅ **Two eras:** Pre-Bloom and Rooted Age with distinct palettes, tiles, and flora  
✅ **Plant system:** 6 species, 4 growth stages each, era-specific availability  
✅ **Gardening:** Plant seeds, water plants, watch growth progress  
✅ **Era shifting:** At Anchor Stones with temporal stamina cost (25 per shift)  
✅ **Cross-era consequences:** Root Echoes, Seed Drift implemented  
✅ **Journal:** Species discovery and observation tracking  
✅ **Save/load:** JSON persistence with full state restoration  
✅ **UI:** HUD, Journal, Main Menu, Pause Menu  
✅ **Pixel art:** Original sprites for player, plants, tiles, UI (56 PNGs)  
✅ **Controls:** Keyboard (WASD/arrows) and mouse  
✅ **Input map:** 13 actions configured in project.godot

---

## Known Limitations

| Limitation | Details |
|------------|---------|
| Eras 3-5 not implemented | Vertical slice covers Eras 1-2 only |
| Impossible Flora / Paradox plants | Future phase feature |
| Seed Vault mechanics | Not in slice scope |
| Environmental puzzles beyond Root Lock | Only one puzzle implemented |
| Multiple endings | Single ending (slice scope) |
| Sound effects and music | Audio directory empty |
| Localization | English only |
| Gamepad support | Keyboard/mouse only |
| Bloom animations | Static sprites only |

---

## Testing Status

### Python/Pygame Prototype
- **43/43 automated tests PASSED**
- Tested: initialization, era system, planting, watering, era shifting, cross-era persistence, journal, save/load, plant growth, species data

### Godot Project
- **NOT executed by Godot engine** — Godot 4.x binary unavailable in this build environment (SSL blocked to GitHub release assets)
- All Godot files (.gd scripts, .tscn scenes, project.godot) have been **audited and fixed** by code review
- All identified issues have been resolved (see `docs/GODOT_AUDIT.md`)
- Godot test scripts are written but **NOT executed** (see `scripts/tests/`)
- **You must validate the Godot project on your local machine**

### Validation Checklist
See `docs/GODOT_VALIDATION_CHECKLIST.md` for 15 manual tests to run in Godot 4.x.

---

## Design Philosophy

Chronoflora avoids common indie game tropes:

- ❌ No hero saving the world
- ❌ No medieval fantasy kingdom
- ❌ No zombies or apocalypse
- ❌ No farming-for-coins loop
- ❌ No time-travel-as-reskin
- ❌ No combat

Instead: ecological memory, cross-era consequences, permanent extinction with Seed Vault preservation, and a single garden that tells the story of a civilization through its plants.

---

## Development Status

**Phase 6 Complete — Vertical Slice Ready for Validation**

The vertical slice is complete and awaiting your Godot runtime validation. Do not begin Phase 7 (Eras 3–5, Impossible Flora, Seed Vault, multiple endings) until the Godot project has been verified on your local machine.

See `docs/GODOT_VALIDATION_CHECKLIST.md` for the complete validation procedure.

---

## License

All rights reserved. This is a pre-release vertical slice for evaluation purposes.
