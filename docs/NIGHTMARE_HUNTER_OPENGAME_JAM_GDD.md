# NIGHTMARE HUNTER — OPENGAME JAM EDITION GDD

**Target:** OpenGame Game Jam #1 · browser-playable · 15–25 minute complete experience
**Engine:** Godot 4.7, Compatibility renderer, Web export
**Genre track:** Action & adventure (secondary fit: RPG)
**Source of truth for vision:** [`NIGHTMARE_HUNTER-GDD.md`](NIGHTMARE_HUNTER-GDD.md)

This document defines the game that will actually be shipped. Where it narrows
the original design, it says so explicitly and says why.

---

## 0. COMPETITION CONSTRAINTS (verified against opengame.io/rules, 21 Nov 2026)

These are hard requirements, not aspirations.

| Constraint | Value | Consequence for us |
| --- | --- | --- |
| Entries open → close | 18 Nov 2026 → **18 Dec 2026, 11:59 pm PT** | ~27 days |
| Winners announced | 30 Dec 2026 | |
| Entry point | `index.html` at build root | Godot Web export, not a wrapper |
| Download before first playable frame | **< 50 MB** (warns) | No large audio/video. Procedural assets. |
| Time to playable | **< 10 s** (warns) | No long boot, no asset streaming |
| Median FPS at 1080p | **≥ 45** (warns) | Compatibility renderer, capped particles |
| Peak memory | < 1.2 GB | Trivial for 2D |
| Resize | Must respond to window resize | `canvas_items` stretch + `keep` aspect |
| Input | **Mouse and keyboard mandatory**, controller optional | Current build is keyboard-only — gap |
| Login | **None.** No account, no email, no key | No sign-in of any kind |
| Offline first frame | Must draw a frame with no network | No CDN fonts, no remote assets |
| Ads / tracking | Forbidden | No portal SDK, no analytics pixels |
| Encrypted `.pck` | **Rejected** — they cannot scan it | Web export must ship unencrypted |
| Payments / crypto | Forbidden | N/A |
| Judged on | Creativity · Depth · Fun · Performance · Visual fidelity — **equal weight** | Performance and art are scored, not optional |

Cross-submission available: **Chroma Awards** Game Division, *Interactive
narrative* category ($3,500), which maps to the RPG/action tracks. Free to
enter by submitting the same link by 7 Jan 2027.

---

## 1. ELIGIBILITY — READ THIS BEFORE BUILDING FURTHER

Stated plainly, because it affects whether any of this is worth shipping.

**What the rules require:** the game must be *created during the Jam* (opened
18 Nov 2026). Reusable engines, libraries, tools and general-purpose frameworks
are permitted. **"Pre-existing game-specific gameplay, levels and substantial
completed game systems are not."** They may request development history or
source as evidence.

**Our position, factually:**
- Repository's first commit `528aba3` — **21 Nov 2026**, three days after entries
  opened. All game code was written after kickoff. Nothing predates the Jam.
- The engine (Godot 4.7) is explicitly permitted.
- Entry is **individual only** — teams and "entries made on someone else's
  behalf" are ineligible. The entry and any prize belong to one person: you.

**The real risk, and it is not the dates.** The rules say they want
*"thoughtfully crafted games, not one-shot generations."* A repository whose
entire content arrived in a small number of large automated commits reads
exactly like the thing that sentence is aimed at. Nothing in the rules forbids
using AI tools, but the judging criterion and the review language both point the
same way.

**Recommended response** (your decision, not mine):
1. Play the game yourself. Tune it. Break it. The feel tuning cannot be done
   without a human playing it, and it is also the most visible evidence of craft.
2. Author some content by hand — write dialogue, name the NPCs, adjust the Bell's
   timings, pick the palette. Even a small amount of hand-authored content is
   both better art and better evidence.
3. Keep normal-sized commits from here, one concern each.
4. Be able to explain any design decision when asked.

This is worth deciding **before** investing the remaining weeks.

---

## 2. CONCEPT — WHAT WE ARE ACTUALLY SHIPPING

> You are a hunter of nightmares, and you are wrong about what that means.

A 2D side-scrolling action game in one interconnected dream region. You
investigate a village that has gone quiet, learn what it silenced, and confront
**The Bell Without a Tongue**. The fight cannot be won by damage. It is won by
finding out why the bell stopped ringing — and then choosing what to do about it.

**Duration:** 15–25 minutes, one continuous arc, no save required mid-run.

**The line the whole game is built to earn:** the most dangerous creature is the
one you finally understand, and understanding it changes what killing it means.

---

## 3. SCOPE DECISIONS — KEEP / SIMPLIFY / CUT

Per the brief: do not silently discard ideas from the original GDD.

### KEPT IN FULL (the identity)
| System | Why it survives |
| --- | --- |
| Three instruments (Blade / Lantern / Anchor) | The signature. The game is unrecognisable without all three. |
| Manifest ↔ Revealed state | The core fiction. |
| Resonance meter + Revelation | Turns "read the enemy" into a mechanic instead of a vibe. |
| Resolution decision (Destroy / Release / Reconcile) | The ending depends on it. |
| Investigation → clue → altered encounter | The mystery is the point. |
| Dream distortion as gameplay, not shader | Makes the world feel alive cheaply. |
| Environmental storytelling | Zero dialogue cost, high payoff. |

### SIMPLIFIED (kept, reduced)
| Original | Jam version | Reason |
| --- | --- | --- |
| 7 nightmare categories | **3 enemies + 1 boss** | Depth over breadth. Each must be distinct, not recoloured. |
| 3 skill paths, 9 nodes | **Cut entirely** | A 20-minute game has no room for a build. Progression comes from instruments, not a tree. |
| Echoes collection | **1 Echo**, earned from the one nightmare | Preserves the idea; a collection system needs volume we don't have. |
| 5 core attributes | **Cut** | No time to make stats feel meaningful. |
| Equipment / weapon forms | **Cut** | Same reason. The Blade has one form, and it changes visually as it absorbs resonance. |
| Multiple regions | **1 interconnected region** with 4 named areas | Metroidvania-lite, not open world. |
| Save system | **One autosave at the Quiet Room**, resume from menu | Enough for a 20-minute run; not a feature to build out. |
| Quest log | **3 objectives shown in the journal only** | No quest UI. The journal *is* the log. |

### CUT (with reason, per rule 12.1)
| Cut | Reason |
| --- | --- |
| Character relationship simulation | Needs many NPCs and long playtime to mean anything. One NPC, tracked by one flag. |
| Nightmare encyclopedia | Becomes the journal's nightmare page. Same content, no extra screen. |
| Difficulty settings | Not enough time to balance two difficulties properly. Better one fair curve. |
| Legendary hunts, hidden quests | Volume features. |
| Double jump / wall climb as progression gates | Region is designed so all mandatory traversal works with base movement + dash. Abilities are never a hard gate, per the original GDD's own warning about ability-gated checklists. |

**Nothing above is cut for convenience.** Each cut removes a system whose value
depends on content volume this scope cannot supply. Shipping a hollow version of
a big system would violate "no fake interactions."

---

## 4. NARRATIVE

**Setting:** The Hollow Village, inside a dream that has been repeating the same
eleven years.

**Premise:** The village bell has not rung in eleven years. Nobody will say why.
The Hunter arrives because the village hired one — not to kill something, but
because the villagers have started forgetting each other's names.

**The truth (discoverable, never told outright):** the villagers removed the
bell's clapper to stop it warning the valley about what was coming. The quiet
bought them one safe winter. The bell has been holding the warning inside itself
ever since, and the pressure is what is eating the village's memory.

**Three endings**, gated by what the player discovered — not by a morality meter:

1. **Destroy** — always available. The bell breaks. The warning dies with it.
   The village keeps its quiet and slowly loses the rest of its names.
2. **Release** — requires finding the removed clapper in the drowned cellar.
   The bell rings once. The warning is finally delivered, eleven years late.
   The village remembers, and has to live with what it did.
3. **Reconcile** — requires both the clapper *and* learning who ordered the bell
   silenced, then choosing not to strike. The rarest ending; the only one where
   the Hunter learns something about themself.

Endings are presented as a short sequence with the journal's final entry read
over it. No placeholder text, no "THE END" card.

---

## 5. STRUCTURE — THE 20 MINUTES

| # | Beat | Time | Purpose |
| --- | --- | --- | --- |
| 1 | **Cold open.** Text over black: the contract. The Hunter wakes on the ash steps. Movement is taught by terrain, not tutorial text. | 0–2 min | Identity in the first minute. |
| 2 | **The Hollow Village.** One NPC: **Ilsa**, the lamplighter, who keeps a lamp in a doorway with no house behind it. She cannot remember her brother's name. | 2–5 min | Emotional hook; teaches interaction. |
| 3 | **Investigation.** Three clues, two mandatory: the unmarked grave, the cellar boards nailed *from the outside*, the worn-smooth name plate. Lantern reveals memory fragments. | 5–9 min | The mystery becomes concrete. |
| 4 | **The Ash Steps.** Platforming + 2 enemy types + one environmental puzzle requiring the Anchor. | 9–13 min | Combat and traversal mastery. |
| 5 | **The Hollow Choir** — the unique nightmare (non-boss). Teaches the full hunt loop on a forgiving target: read → resonate → reveal → resolve. | 13–16 min | The signature system, proven before the boss. |
| 6 | **The Bell Without a Tongue.** Four phases. | 16–21 min | The highlight. |
| 7 | **Resolution + ending.** | 21–23 min | Payoff. |

Quiet Room checkpoints at beats 2, 4 and 6 (pre-fight). Death returns you there;
discovered clues persist, per the original GDD.

---

## 6. PLAYER MECHANICS

### Movement (must feel excellent — this is the thing players touch constantly)
- Run, variable-height jump, air control, **coyote time (0.10 s)**, **jump
  buffering (0.12 s)**, dash with recovery.
- Gravity is heavier falling than rising (1.35×) so jumps have weight.
- Dash: 0.16 s, 0.45 s cooldown. **No invulnerability by default** — the original
  GDD explicitly warns against depending on i-frames.
- Landing produces dust particles, a small camera dip and a sound. Feel is built
  from feedback, not from stats.

### Mouse support (jam requirement — currently missing)
- **Left click** = light attack, **right click** = heavy attack.
- Cursor position on the correct side of the player sets facing during combat.
- All menus and dialogue are mouse-clickable as well as keyboard-driven.
- Every action remains bound to a key. Mouse is a first-class alternative, not a
  replacement.

### The three instruments
| Instrument | Input | Cost | Role |
| --- | --- | --- | --- |
| **Reverberation Blade** | Click / `J`,`K` | none | Damage, pressure, counters. Glows brighter as Resonance rises. |
| **Dream Lantern** | `F` | 22 Lantern charge (regen slowly) | Reveals hidden structure, exposes true vulnerability, interrupts some telegraphed abilities. Deliberately not spammable. |
| **Anchor of Wakefulness** | `G` | 25 Resonance | Stabilises the arena, stops teleporting, holds a nightmare in its revealed state, carves a safe zone. |

**Design rule:** no encounter is solvable by one instrument. The Lantern without
the Anchor cannot hold what it reveals; the Anchor without the Lantern is
stabilising something you cannot see.

### Resonance and Revelation
Resonance fills from **reading**, not from damage:
- precise hit: 6 · successful counter: 17 · correct Lantern reveal: 14
- first time a pattern is read: 10 (each pattern pays **once** — no farming)
- environmental opportunity: 9

At 100 the player may force a **Revelation**: the nightmare's true structure
shows, its damage multiplier rises, and its vulnerability becomes interactable.
Revelation lasts 8 s, then a 2.5 s cooldown.

---

## 7. ENEMIES (3 + boss — each must be a different problem)

| Enemy | Category | The problem it poses | Telegraph |
| --- | --- | --- | --- |
| **Ashen Warden** | Warden | Holds a chokepoint with armour while defending. Cannot be rushed; must be broken out of its guard with a heavy or lured off the ledge. | Shield raise + low tone |
| **Borrowed Face** | Mimic | Looks like Ilsa until it is very close. Punishes attacking what looks friendly. The Lantern unmasks it. | Borrowed silhouette flickers |
| **Hollow Choir** | Fragmented | Splits into three half-formed singers. Killing fragments is pointless; you must reveal which one holds the verse. | Phrase stops mid-bar before each strike |
| **The Bell Without a Tongue** | Distorter (boss) | See §8. | — |

**Rule enforced:** no two enemies share a behaviour with a palette swap. If a
new enemy would be a recoloured old one, it does not ship.

All enemies share one AI FSM differentiated by a `category` field, so behaviour
variants cannot drift apart across scripts.

---

## 8. THE BOSS — THE BELL WITHOUT A TONGUE

The centrepiece. It must be memorable after the player closes the tab.

**Presentation:** a giant bronze bell floating over a flooded village square,
ringed by fragments of abandoned voices that drift like moths. It never rings.
The silence is where its attacks live.

### Phase 1 — Recognition
The bell sways. Its **sway is the telegraph**: it always leans before it strikes.
- **Sway & Drop** — leans, then drops, sending a shockwave along the ground.
  Jump it.
- **Voice Sweep** — releases three voice fragments in an arc. Duck or dash.
Player learns: *watch the lean, not the bell.*

### Phase 2 — Distortion (66% health)
The bell begins to vibrate and **gravity bends**.
- The arena's platforms drift. Some invert — the player fights on the ceiling.
- **Echo Copy**: the bell's vibration produces a ghost duplicate of the arena
  layout for 6 seconds, offset by half a screen. Attacks land in *both*.
- The Anchor becomes necessary: stabilising a platform stops it drifting and
  gives the player somewhere to stand.
Player learns: *the Anchor is not a defensive button, it is terrain control.*

### Phase 3 — Revelation (33% health, or earlier if Resonance is full)
The bell goes **completely silent**. This is the phase's core deception:
- **Silence is the telegraph.** During silence the next attack is invisible.
  The only warning is that the voice fragments stop moving.
- The **Lantern** reveals the voices trapped *inside* the bell — dozens of them,
  pressed against the bronze, still trying to finish a sentence.
- Revealing them exposes the **tongue socket**: the place where the clapper was
  torn out. That is the true vulnerability, and it is only interactable while
  the Anchor holds the bell still.
Player learns: *it was never guarding this place. It was containing something.*

**This is the moment the fight changes meaning.** Damage dealt before this point
was just pressure. From here, the player is not killing a monster — they are
deciding whether a warning gets delivered.

### Phase 4 — Resolution
The bell is held, revealed, and open. Time slows. Three prompts appear, gated by
what the player found:
- **Destroy** (always) — strike the socket.
- **Release** (needs the clapper) — return the tongue; the bell rings.
- **Reconcile** (needs the clapper + the name of whoever silenced it) — refuse
  the blow and speak the name instead.

The arena, the audio and the ending all branch here.

### Boss rules
- No health-bar-only design. Every phase teaches one thing and the next phase
  tests it.
- Every attack has a visual *and* audio telegraph, readable at 45 fps.
- The boss is beatable without perfect play. It is not beatable without
  understanding it.
- Arena is enclosed; no way to fall out and softlock.

---

## 9. ART DIRECTION — PROCEDURAL, NOT AI-IMAGE

Judged on visual fidelity, and we have no artist. Decision: **build the entire
visual identity in code**, using Godot's `_draw()`, `Polygon2D`, gradients,
`CanvasModulate`, `PointLight2D` and `GPUParticles2D`.

**Why this is the right call for this jam:**
- **Total visual control and perfect consistency** — one palette, one hand.
- **Tiny build.** No textures to ship. Directly serves the <50 MB / <10 s targets.
- **Zero licensing risk.** Every pixel is generated at runtime by our code.
- **Animation is free.** Shapes tween by code; no sprite-sheet frame alignment.
- **Guaranteed to run in the browser** — no import pipeline to break.

**Style:** high-contrast silhouette-first. Near-black dream (background
`#090810`), a single warm accent for the Hunter's lamp (`#f5dc7a`), a cold
violet for nightmare mass (`#4b2e83`), and one reveal gold (`#ffd98a`) reserved
**exclusively** for revealed truth. That gold appearing anywhere in the game
means *this is real*. Never use it decoratively.

**Readable by rule:** player, enemies, attacks, hazards and interactables are
distinguishable by silhouette alone, with colour as a secondary cue. Attack
telegraphs are shapes, never particle soup.

**Layered parallax:** 3 layers (far mist, mid spires, near ash) at 0.2 / 0.55 /
0.85 scroll scale.

**Lighting:** one `CanvasModulate` for the dream's overall dark, `PointLight2D`
on the Hunter's lamp and on revealed objects only. Light is information.

---

## 10. AUDIO — SYNTHESISED, NOT RECORDED

No audio assets ship. `AudioManager` synthesises every sound at runtime into
`AudioStreamWAV` buffers.

This is not a compromise to hide — it is a deliberate identity choice: a game
about a bell that cannot ring should sound like it is *built from* bells.

| Layer | How |
| --- | --- |
| **Impacts** | Short detuned partials with fast decay; pitch rises with combo index. |
| **The Bell** | Inharmonic partials (1.0, 2.76, 5.4, 8.9 ratios) — a real bell's spectrum. Used for the boss's presence even when silent (very low, almost subliminal). |
| **Silence** | The boss's Phase 3 ducks the entire mix. The absence is the effect. |
| **Ambience** | Filtered noise bed, slowly modulated. Reverbs via short convolution-free feedback delay. |
| **Revelation** | A rising cluster that resolves to the bell's fundamental. The player should *feel* the answer before reading it. |
| **Endings** | Destroy: bell fundamental cut off mid-decay. Release: full bell strike, long tail. Reconcile: bell plus a human-range voice tone, in tune. |

Budget: keep total synthesised buffers small, generate lazily, cache by name.

---

## 11. UI AND PRESENTATION

No default Godot theme. Everything styled to the palette above.

- **Main menu** — title, Begin, Continue (if autosave exists), Settings, Credits.
  Background is the dream itself, slowly drifting. No stock buttons.
- **Settings** — master/music/SFX volume, screen shake toggle, **flash reduction
  toggle** (accessibility), input rebind for the core actions.
- **Pause** — resume, settings, quit to menu.
- **HUD** — health, Resonance, Lantern charge, contextual prompt. Boss health is
  a thin arc at the top that **only appears once the boss is understood**, so the
  UI itself reinforces the theme.
- **Dialogue** — bottom-left, Ilsa's lamp lighting the text. Click or `E` to
  advance. Never more than three lines per box.
- **Journal** — the only menu that matters. Categories: Nightmares, Weaknesses,
  Memories, Observations, Decisions. Entries are written in the Hunter's voice.
  Information is earned, never auto-filled.
- **Ending** — no HUD. Text over the resolved arena.

**No dead UI.** Every button works or does not exist.

---

## 12. WEB TECHNICAL REQUIREMENTS

- Compatibility renderer (already configured).
- **No encrypted `.pck`** — export unencrypted or the submission is rejected.
- `canvas_items` stretch mode, `keep` aspect, tested at 1280×720, 1920×1080,
  1366×768, 2560×1440 and a resized window.
- Cap `GPUParticles2D` at ~300 particles on screen total; use `local_coords`
  where possible; no particle-emitting-per-frame enemies.
- No custom shaders beyond one cheap distortion shader for the boss arena.
- Draw calls: keep under ~200. Batch by using few distinct materials.
- First frame must render with no network access.
- Audio must survive the browser's autoplay policy: the AudioContext is resumed
  on the first user gesture (the Begin button), never before.
- `SharedArrayBuffer` requirement: Godot 4 Web needs cross-origin isolation
  headers **or** a single-threaded build. OpenGame serves static files we do not
  control, so **export with threads disabled** to avoid needing COOP/COEP
  headers. This is a concrete, easy-to-miss failure mode.

---

## 13. MILESTONES

| # | Milestone | Deliverable | Exit criterion |
| --- | --- | --- | --- |
| M0 | **Green build** | Project compiles in Godot 4.7, CI passes | Headless import + boot clean |
| M1 | **Feel** | Movement + combat + camera + hit feedback | A human plays it for 5 minutes and does not want to stop |
| M2 | **Web proof** | First Web export, served and played in a real browser | Playable in browser, <50 MB, ≥45 fps, resize works |
| M3 | **The hunt loop** | Hollow Choir encounter, full read→resonate→reveal→resolve | Loop is understandable without explanation |
| M4 | **The Bell** | Boss phases 1–4 with all three resolutions | Fight changes after the truth is found |
| M5 | **Content complete** | Opening, village, investigation, endings | Completable start to finish |
| M6 | **Polish** | Art pass, audio pass, UI styling, juice | Looks and sounds intentional |
| M7 | **QA + submission** | Full playtest matrix, OpenGame CLI upload | Passes their automated review |

**M2 comes early on purpose.** The brief is right that a working editor run
proves nothing about the browser. The single highest-risk technical unknown —
does the Godot 4 Web export run on OpenGame's static hosting without COOP/COEP
headers — must be answered in week one, not week four.

---

## 14. ACCEPTANCE CRITERIA

The build ships only when every line is true.

**Completeness**
- [ ] Playable start to finish with no editor, no console, no restart.
- [ ] All three endings reachable and distinct.
- [ ] No placeholder text, no TODO, no grey-box art in the final build.
- [ ] Every button does something. Every interaction that looks usable is usable.
- [ ] No softlock: every mandatory objective reachable with base movement; every
      arena enclosed; death always returns to a working checkpoint.

**Gameplay**
- [ ] Movement responsive; jump and collision precise; no coyote-time bugs.
- [ ] Every enemy attack telegraphed visually and audibly.
- [ ] All three instruments required to finish the boss.
- [ ] Revelation changes the boss's behaviour observably.
- [ ] Difficulty fair: a competent player finishes without dying more than ~3 times.

**Technical**
- [ ] `index.html` at build root; unencrypted `.pck`.
- [ ] <50 MB before first playable frame; playable in <10 s on a normal laptop.
- [ ] ≥45 fps median at 1080p; stable frame pacing.
- [ ] Correct at 5 viewport sizes; responds to live resize.
- [ ] Mouse + keyboard fully playable. Controller optional.
- [ ] First frame renders with network disabled.
- [ ] No ads, no tracking, no login, no payments, no remote assets.
- [ ] Tested in Chrome and Firefox, in the actual exported build.

---

## 15. HIGHEST RISKS

| # | Risk | Severity | Mitigation |
| --- | --- | --- | --- |
| R1 | **Godot 4 Web export fails on static hosting** (needs `SharedArrayBuffer` → COOP/COEP headers we cannot set) | **Critical** | Export single-threaded. Test M2 in week 1. Fallback: host behind our own headers is *not* allowed, so this must work. |
| R2 | **Eligibility challenge** — "not one-shot generations" | **Critical** | §1. Human playtest, hand-authored content, normal commit cadence. Decide before investing further. |
| R3 | Nobody has played it; feel is unverified and probably wrong | **High** | M1 before any content work. Feel first, content second. |
| R4 | Procedural art looks amateur | **High** | Silhouette-first, 4-colour discipline, one reserved accent. Constraint is the style. |
| R5 | Synthesised audio sounds cheap | Medium | Bell-based palette is coherent and distinctive; duck and sidechain for dynamics. |
| R6 | Scope creep back toward the full GDD | Medium | This document is the contract. Adding a system requires removing one. |
| R7 | Agent sandbox cannot run Godot, so verification loops are slow | Medium | CI as the engine oracle; annotations as the readable channel; static checks as the fast inner loop. |
