# NIGHTMARE HUNTER

A 2D side-scrolling action RPG built in **Godot 4.7**.

> Every nightmare is a creature to fight, a mystery to investigate, and a story to understand.

The full design bible lives in [`docs/NIGHTMARE_HUNTER-GDD.md`](docs/NIGHTMARE_HUNTER-GDD.md).
Everything in this repository implements that document; where code and document
disagree, the document wins.

---

## What is built right now

This is the **Prototype** stage from GDD §22: player movement, dash, the three
instruments, real-time combat, one nightmare mechanic, one exploration region,
and the systems layer that the vertical slice will hang off.

Playable: press **Begin the Hunt** on the title screen.

### Controls

Everything below works with keyboard **and** mouse, which the jam requires.
Bindings live in `project.godot` under `[input]`; the comfort options
(including mouse aiming) are on the pause menu.

| Action | Key | Mouse | Pad |
| --- | --- | --- | --- |
| Move | `A` / `D` (or arrows) | — | Left stick |
| Jump (variable height) | `Space` / `Z` | — | A |
| Light attack | `J` | Left button | X |
| Heavy attack / counter | `K` | Right button | Y |
| Dash | `Shift` / `L` | Wheel up | B |
| Dream Lantern (reveal) | `F` | Middle button | LB |
| Anchor of Wakefulness (stabilise) | `G` | Mouse button 5 | RB |
| Revelation | `R` | — | LT |
| Active Echo | `Q` | — | RT |
| Interact | `E` | — | Start |
| Journal | `N` / `Tab` | — | Select |
| Pause / settings | `Esc` | — | Start |

Jump is variable height only: hold to rise higher, tap to cut short. The GDD's
double jump is a progression unlock, and nothing in M1 calls
`request_double_jump_unlock()`, so it does not fire yet — treat the single
jump plus dash as the whole movement kit for this milestone.

Aiming follows the mouse cursor by default, with a 14-pixel deadzone around
the Hunter so a resting pointer in the middle of the screen does not pin the
facing. Turn it off in the pause menu and facing falls back to movement
direction.

All actions are remappable in **Project Settings → Input Map**.

### The hunt, in one paragraph

Fight a nightmare and you do damage. *Read* it — land a precise hit, answer a
telegraphed attack with a counter, sweep the Dream Lantern across it, notice the
thing it keeps doing — and **Resonance** fills. Spend a full meter on a
**Revelation** and its true structure shows: the forgotten name, the trapped
voice, the unfinished verse. That is when it can actually be ended, and when it
ends you choose **Destroy / Capture / Release / Reconcile**. Each choice changes
what the region and its people become.

---

## Running it

1. Install [Godot 4.7.x](https://godotengine.org/download) (standard build, not .NET).
2. Open the repository folder in the Godot Project Manager.
3. Press F5.

The project uses the **Compatibility** renderer, so the same code targets
desktop and Web.

### Verifying without opening the editor

```bash
python3 tools/check_project.py
```

This does not need Godot. It checks the contracts that break a project on load:
every `$NodePath` against the scene it is attached to (including instanced
sub-scenes), every `res://` reference, input actions against `project.godot`,
autoload targets, duplicate `class_name`s, `.new()` on a `Node` subclass,
`load_steps` counts, and every authored data file.

It is a real check, not a smoke test — `tools/check_project.py` was validated by
injecting ten known faults and confirming each one is reported.

The full engine check runs in CI (`.github/workflows/godot.yml`): a headless
Godot 4.7.2 load that parses every script and resolves every scene, plus an
autoload boot that must print the content manifest.

---

## Architecture

Data-driven by rule (GDD §21): creatures, Echoes, weapon forms, skills and
quests are authored as JSON under `data/` and parsed into typed `Resource`
objects at boot by `NightmareDatabase`. Adding a nightmare does not touch
gameplay code.

```
scripts/
  manager/    autoloads: GameManager, SaveManager, WorldManager, AudioManager,
              JournalManager, QuestManager, DecisionTracker, ProgressionManager,
              EchoManager, NightmareDatabase
  resources/  NightmareData, EchoData, WeaponFormData, SkillDef, QuestDef
  combat/     Hitbox, Hurtbox, DamageSystem, StatusEffectSystem,
              ResonanceSystem, BossEncounterManager
  player/     PlayerController, PlayerMovement, PlayerCombat, PlayerHealth,
              PlayerLantern, PlayerAnchor, PlayerAbilities
  nightmares/ NightmareBase, NightmareAI, NightmareMemory
  world/      region_level, DreamDistortion, CheckpointManager, InteractiveObject
  ui/         HUD, JournalScreen
  main/       Boot, MainMenu

data/         nightmares/ echoes/ weapons/ skills/ quests/   (authored JSON)
scenes/       main/ entities/ world/ ui/
```

Design notes that are load-bearing:

- **`DamageSystem` is the only place damage is decided.** That is what keeps
  "revealed nightmares take more damage" and "counters interrupt" from being
  copy-pasted into every enemy.
- **`ResonanceSystem` and `BossEncounterManager` are `RefCounted`, not `Node`.**
  They are per-encounter rule sets created with `.new()`, which Godot forbids
  for scene-tree classes.
- **Enemies share one `NightmareAI` FSM.** Their difference comes from the
  `category` field in `NightmareData`, so a Stalker, a Warden and a Memory Eater
  behave differently without three scripts drifting apart.
- **Memory Eaters attack resources, not health.** They drain Lantern charge and
  Resonance, which makes them a different problem rather than a recoloured one.

---

## Content shipped

| | |
| --- | --- |
| Nightmares | The Hollow Choir (Fragmented), The Borrowed Face (Mimic), The Bell Without a Tongue (Distorter, boss) |
| Echoes | Weightlessness, Hollow Voice, Unfinished Step, Borrowed Faces |
| Blade forms | Whisper, Dirge, Resonant |
| Skill paths | The Blade / The Lantern / The Anchor, 3 nodes each |
| Quests | The Bell That Stopped Ringing, The Nameless Grave |
| Region | The Hollow Village — platforming, wall jump, Quiet Room, memories, hidden structures, boss arena |

---

## Not done yet

Stated plainly, so nobody mistakes the prototype for the game:

- **No art.** Every visual is an engine primitive (`ColorRect`). Swap the
  `_build_placeholder_visual()` methods and the generated platforms for
  `AnimatedSprite2D` and `TileMapLayer` when assets exist.
- **No real audio.** `AudioManager` synthesises placeholder tones at runtime.
- **No Web export yet.** The project is configured for Compatibility, but no
  export template or `export_presets.cfg` has been run.
- **No animation states.** `PlayerAnimation` from GDD §21 is not implemented.
- **Dialogue, NPC relationships and endings** are stubbed through
  `DecisionTracker` and `JournalManager` but have no content.
- **Untested in the editor.** The static checks and CI pass; nobody has played
  it. Feel is unverified and almost certainly needs tuning.

## Drive hub

Design, assets, builds and notes live in the **Game Godot Project** folder in
Google Drive. This repository is the source of truth for code only.
