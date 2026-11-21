# NIGHTMARE HUNTER — Complete Gameplay Systems Design

**Action RPG | 2D Side-Scrolling | Real-Time Combat | Godot 4**

---

## 1. GAMEPLAY IDENTITY

Nightmare Hunter is a 2D side-scrolling action RPG built around three interconnected experiences:

1. Exploration of mysterious dream worlds.
2. Real-time combat against unique nightmare creatures.
3. Hunting, investigating, understanding, and confronting nightmares.

The central gameplay philosophy:

> **Every nightmare is a creature to fight, a mystery to investigate, and a story to understand.**

The player must learn how nightmares behave, discover their emotional origins, exploit their weaknesses, and make decisions that may change their fate.

The game must never become a repetitive sequence of corridors and enemy encounters. Exploration, combat, investigation, character development, and narrative must constantly influence one another.

---

## 2. THE CORE GAMEPLAY LOOP

The main gameplay loop consists of eight stages.

**Stage 1 — Discover.** The player encounters signs of a nightmare in a settlement, dream region, or abandoned location. Signs may include: strange sounds, missing inhabitants, distorted environments, unusual memories, physical traces, characters behaving abnormally.

**Stage 2 — Investigate.** The player gathers clues and interviews characters. Investigation may reveal the nightmare's identity, emotional origin, territory, behavior, unusual abilities, and possible ways to confront it. Not every clue is mandatory, but discoveries can unlock additional solutions.

**Stage 3 — Enter.** The player enters the nightmare's territory. The environment becomes increasingly distorted. Physics, architecture, sound, enemies, and even the player's abilities may change.

**Stage 4 — Explore.** The player navigates the nightmare's domain through platforming, combat, environmental puzzles, secret paths, and unusual interactions.

**Stage 5 — Understand.** The player discovers the nightmare's underlying truth — through environmental clues, memories, dialogue, hidden encounters, or boss behavior.

**Stage 6 — Confront.** The player faces the nightmare in real-time combat. Understanding its nature can unlock alternative combat strategies and opportunities.

**Stage 7 — Decide.** After the encounter the player may destroy, capture, heal/release, or negotiate with the nightmare (when appropriate). Not every creature supports every option.

**Stage 8 — Consequences.** The world changes. Characters may return, disappear, transform, or react differently. New abilities, quests, locations, and story developments may become available.

---

## 3. PLAYER MOVEMENT AND EXPLORATION

2D side-scrolling perspective. Movement must feel responsive, precise, and satisfying.

**Basic movement:** walk, run, jump, variable-height jumping, double jump (unlocked through progression), air control, coyote time, jump buffering, wall interaction where level design requires it, ledge climbing where appropriate, dash.

**Movement philosophy.** The protagonist should feel agile but not weightless. Movement must have personality. The player should feel the weight of landing, the speed of a dash, and the precision of an aerial attack.

**Exploration abilities** (progression unlocks; each must carry narrative significance):

- **Dream Step** — short-range movement ability that passes through certain dream barriers.
- **Memory Hook** — attach to special points and cross dangerous gaps.
- **Falling Between** — controlled descent through certain dream layers.
- **Echo Walk** — reveals invisible paths for a limited duration.

Do not turn every region into a simple ability-gated checklist.

**Environmental interactions:** activate ancient dream mechanisms, move objects, break specific structures, examine memories, open hidden passages, manipulate dream physics, interact with NPCs, discover hidden rooms, use environmental elements during combat.

---

## 4. THE SIGNATURE COMBAT SYSTEM — The Three Instruments of the Hunter

The protagonist uses a unique hunting apparatus of three interconnected instruments.

**A. The Reverberation Blade.** A supernatural weapon for direct combat; its form and properties change according to the dream energy absorbed from defeated or understood nightmares. Functions: fast attacks, heavy attacks, aerial attacks, charged attacks, counterattacks, special weapon techniques.

**B. The Dream Lantern.** Reveals hidden structures and exposes nightmare weaknesses. It can reveal invisible enemies, expose hidden weak points, illuminate memory fragments, reveal environmental clues, interrupt certain enemy abilities, and interact with specific dream mechanisms. It is not a permanent solution to every encounter — it requires resources and precise timing in combat.

**C. The Anchor of Wakefulness.** Temporarily stabilizes distorted dream reality. It can interrupt certain attacks, stabilize unstable platforms, prevent enemies from teleporting, create temporary safe zones, and expose a nightmare's vulnerable state. Especially important during boss encounters.

The three instruments must complement one another rather than function as three unrelated weapons.

---

## 5. REAL-TIME COMBAT

Skill-based, responsive, readable, varied.

**Controls (all remappable):** Attack → light attack; Heavy attack → heavy attack; Jump → jump; Dodge → dash; Special → selected ability; Lantern → reveal/inspect; Anchor → stabilize; Interact → contextual action.

- **Light attacks** — fast, maintain pressure, chain into combinations.
- **Heavy attacks** — slower, more powerful, can interrupt certain enemy actions and break specific defenses.
- **Aerial combat** — attack while airborne; certain nightmares are more vulnerable to aerial attacks.
- **Dodging** — short dash with a carefully balanced recovery period. Some upgrades may grant a brief defensive window, but the game must not depend on excessive invulnerability.
- **Countering** — precise timing. A successful counter can interrupt the enemy, create an opening, restore a small amount of combat energy, and reveal information about the enemy. Not every enemy attack is counterable.

**Combat combinations.** Movement, weapon attacks, abilities, and environmental interactions combine. Example: dodge through an incoming attack → jump over the enemy → strike its exposed weak point → use the Lantern to reveal its hidden core → activate the Anchor to prevent escape → finish with a weapon technique.

The goal is expressive combat, not repetitive button mashing.

---

## 6. THE UNIQUE NIGHTMARE HUNTING MECHANIC

The game's defining system. Every major nightmare has two states.

**Manifest State** — the nightmare appears as a physical creature: it attacks, moves, defends itself, uses supernatural abilities.

**Revealed State** — the player discovers the nightmare's underlying emotional structure and its true vulnerability becomes visible. This is not necessarily an anatomical weak point. It may be a forgotten name, a repeating memory, a broken promise, a trapped voice, a symbol, a specific environmental object, or a contradiction in its behavior. The player must discover and interact with this vulnerability.

**The Resonance Meter.** Built by landing precise attacks, performing successful counters, discovering enemy patterns, using the Lantern correctly, and exploiting environmental opportunities. At a threshold the player may activate a **Revelation**, which temporarily exposes the nightmare's deeper structure: hidden weak points become visible, certain attacks change, new interactions become possible, special finishing opportunities may appear, and additional narrative information may be revealed.

Resonance should reward intelligent play, not simply damage output.

**The Resolution Decision.** When a major nightmare is defeated or sufficiently understood, the player may receive a resolution opportunity: **Destroy** (eliminate permanently), **Capture** (preserve inside the Hunter's apparatus), **Release** (free it from the dream structure sustaining it), **Reconcile** (resolve its underlying conflict when story and encounter permit). Each outcome has different gameplay and narrative consequences.

---

## 7. NIGHTMARE BEHAVIOR AND ENEMY AI

Enemies must not behave like interchangeable damage sources. Every nightmare needs a distinct behavioral identity.

**Categories** (broad behavioral families, not substitutes for individual creature designs):

- **Stalkers** — observe, disappear, attack unexpectedly.
- **Wardens** — defend areas, use positioning to control space.
- **Distorters** — change the environment during combat.
- **Mimics** — imitate characters, objects, or other creatures.
- **Fragmented** — move unpredictably, may split into multiple forms.
- **Hunters** — actively pursue the protagonist across level sections.
- **Memory Eaters** — manipulate the player's abilities or combat resources.

**AI requirements:** patrol, investigation, pursuit, telegraphing, attacking, dodging, defending, retreating, special abilities, stagger, recovery, death or resolution.

Enemy attacks must have readable visual and audio telegraphs. Difficulty should come from understanding and reacting to behavior, not from unfair damage or invisible attacks.

---

## 8. BOSS ENCOUNTER DESIGN

Boss fights are major narrative and gameplay events. Every major boss has its own rules.

A typical encounter: **Phase 1 Recognition** (learn movement and basic attacks) → **Phase 2 Distortion** (arena changes, new attacks and hazards) → **Phase 3 Revelation** (expose the boss's deeper structure; combat pattern changes according to the revealed truth) → **Phase 4 Resolution** (finish the encounter or pursue an alternative outcome).

Not every boss needs four phases. Some should be fast and aggressive; others puzzle-like, psychological, environmental, or emotionally driven.

**Example boss — The Bell Without a Tongue.** A giant floating bell surrounded by fragments of abandoned voices. It does not attack conventionally. Its vibrations alter gravity; its echoes create temporary copies of the arena; its silence hides the next attack. The player must use the Anchor to stabilize the battlefield; the Lantern reveals the voices trapped inside it. The encounter changes after the player discovers why the bell stopped ringing.

---

## 9. RPG PROGRESSION

**Hunter Levels.** Experience from defeating nightmares, completing quests, discovering hidden locations, solving major investigations, overcoming special encounters. Leveling provides modest core stat improvements and progression points. Avoid making level grinding mandatory.

**Core attributes:** Vitality (max health), Agility (movement and selected recovery), Resonance (max Resonance capacity), Focus (Lantern and instrument efficiency), Resolve (resistance to dream distortions). Effects must be meaningful but controlled.

**Three skill paths:**

- **Path A — The Blade:** aggressive combat. Advanced combos, heavy attacks, aerial techniques, counterattacks, weapon transformations.
- **Path B — The Lantern:** investigation and revealing weaknesses. Expanded detection, more efficient revelations, additional memory interactions, improved enemy analysis, new hunting solutions.
- **Path C — The Anchor:** control and defense. Improved stabilization, defensive techniques, environmental manipulation, special counters, additional dream traversal abilities.

The player should be able to develop a preferred playstyle. No path may be objectively superior.

---

## 10. NIGHTMARE ABILITIES AND COLLECTION — Echoes

Some resolved nightmares grant **Echoes** — not conventional skill collectibles but fragments of the nightmare's nature.

- **Echo of Weightlessness** — temporarily alter gravity during specific encounters.
- **Echo of the Hollow Voice** — produce a sound that interacts with hidden structures.
- **Echo of the Unfinished Step** — short movement ability through unstable dream surfaces.
- **Echo of Borrowed Faces** — interact with certain mimics and reveal their identities.

Each Echo needs a unique ability, a visual effect, an audio signature, a narrative origin, and specific exploration/combat applications. Limited active Echo slots create meaningful build choices. Echoes should not simply increase damage.

---

## 11. EQUIPMENT AND CUSTOMIZATION

**Weapon forms** for the Reverberation Blade: fast/lightweight, slow/powerful, balanced, Resonance-generation-focused, precise-counter-rewarding.

**Hunter attire:** passive modifiers — improved exploration, greater distortion defense, more efficient Resonance generation, better resource management.

**Charms and fragments:** small customizable items; limit active slots to prevent overwhelming combinations. Avoid endless randomized loot. Important equipment should have identity, history, and sometimes a story of its own.

---

## 12. HEALTH, RESOURCES, AND DEATH

- **Health** — visible meter; healing limited during dangerous encounters.
- **Resonance** — used for Revelations and selected advanced abilities.
- **Lantern Charge** — special investigations and certain combat interactions.
- **Dream Fragments** — world resource for selected upgrades and crafting.

**Death:** return to a nearby checkpoint; major story discoveries remain recorded; some unbanked resources may be recoverable; boss progress resets unless a specific encounter checkpoint says otherwise. Avoid punishing players so severely that experimentation becomes frustrating.

**Checkpoints — Quiet Rooms:** small stable spaces in unstable dreams. They may provide saving, healing, equipment management, skill upgrades, character conversations, and Dream journal access. Some evolve as the story progresses.

---

## 13. WORLD STRUCTURE AND LEVEL DESIGN

Interconnected side-scrolling regions. Each region contains main paths, optional paths, hidden rooms, environmental puzzles, nightmare encounters, NPCs, hunting clues, shortcuts, boss arenas, and secret discoveries.

**Level design principles:** (1) every region needs a recognizable visual silhouette; (2) every major area needs a unique gameplay idea; (3) exploration rewards curiosity; (4) backtracking introduces new possibilities; (5) boss arenas reflect the boss's identity; (6) secrets reward observation rather than random searching; (7) environments tell stories without excessive dialogue.

Use layered backgrounds and parallax for depth. Keep movement and combat readable against the environment.

---

## 14. DREAM DISTORTION SYSTEM

Certain areas have a **Distortion Level**. As distortion increases: platforms may move, gravity may change, background objects may become interactive, paths may disappear, enemy behavior may transform, audio may become unreliable, memories may appear in the environment.

Distortion is not merely a visual effect — it changes how the player interacts with the world. The player may use the Anchor to stabilize selected objects or locations. Some puzzles require *allowing* distortion rather than eliminating it, creating a meaningful choice between control and adaptation.

---

## 15. NPC AND RELATIONSHIP SYSTEM

Characters react to the player's actions. Track important decisions, not every trivial dialogue choice.

Examples: a rescued character may return to a settlement; a captured nightmare may become a source of information; a destroyed nightmare may permanently alter a character's memories; a released creature may appear in a later region; an ally may refuse to cooperate after a major decision.

Relationships develop through main story events, optional quests, conversations, shared encounters, and player decisions. Do not turn the game into a relationship simulator — relationships serve narrative and world.

---

## 16. QUEST SYSTEM

Categories: **Main Story**, **Hunting Contracts**, **Character Stories**, **Regional Mysteries**, **Legendary Hunts** (long, challenging, multi-region), **Hidden Quests** (require unusual discoveries or decisions).

Each quest must contain a narrative reason to exist, distinct objectives, meaningful discoveries, interesting gameplay, appropriate rewards, and a visible record in the journal. Avoid repetitive fetch quests and artificial padding.

---

## 17. THE HUNTER'S JOURNAL

A major gameplay feature. Records characters, nightmare encounters, creature observations, discovered memories, regional maps, quest progress, unresolved mysteries, important decisions, and known weaknesses.

It should feel like a personal hunting archive. New entries are sometimes written from the protagonist's perspective. Information should be discovered, not automatically revealed.

---

## 18. REPLAYABILITY AND ENDINGS

Player decisions may alter available allies, encounter solutions, regional states, nightmare outcomes, certain boss mechanics, the protagonist's abilities, and final story events.

Plan at least three endings, each reflecting a different interpretation of the world's central mystery. Avoid simple morality meters — the player is judged by actual actions and discoveries.

---

## 19. DIFFICULTY DESIGN

Challenging but fair: clear enemy telegraphs, consistent collision rules, readable attack patterns, carefully balanced damage, optional difficulty assistance, meaningful checkpoints, gradual introduction of mechanics.

Bosses test skills learned during exploration. Difficulty must not rely on enormous health bars — a well-designed boss is memorable for its mechanics, atmosphere, and narrative.

---

## 20. USER INTERFACE

Atmospheric and readable. **Main HUD:** health, Resonance, Lantern charge, active Echoes, selected ability, contextual hunting indicators.

**Additional interfaces:** inventory, equipment, skill tree, journal, map, quest log, character records, nightmare encyclopedia.

The interface must not overwhelm the screen. Use animated transitions and subtle effects, but preserve clarity during combat. All important gameplay information must remain readable at browser resolutions.

---

## 21. GODOT 4 TECHNICAL ARCHITECTURE

Modular architecture:

| Layer | Modules |
| --- | --- |
| Main | Boot, MainMenu, WorldManager, SaveManager, AudioManager |
| Player | PlayerController, PlayerMovement, PlayerCombat, PlayerAbilities, PlayerHealth, PlayerEquipment, PlayerAnimation |
| Combat | CombatManager, Hitbox, Hurtbox, DamageSystem, StatusEffectSystem, ResonanceSystem, BossEncounterManager |
| Nightmares | NightmareBase, NightmareAI, NightmareAbilities, NightmareMemory, NightmareResolution, NightmareDatabase |
| World | RegionManager, LevelManager, CheckpointManager, DreamDistortion, InteractiveObjects, EnvironmentalPuzzles |
| Narrative | DialogueManager, QuestManager, CharacterManager, DecisionTracker, JournalManager |
| Progression | ExperienceManager, SkillTree, EchoManager, InventoryManager, EquipmentManager |
| UI | HUD, InventoryScreen, SkillTreeScreen, JournalScreen, MapScreen, DialogueUI |

Use reusable scenes and data-driven resources. Important gameplay data belongs in structured Godot Resources or appropriate data files — avoid hardcoding every enemy, quest, or item into gameplay scripts.

**Performance:** efficient 2D rendering; Compatibility renderer for browser builds; avoid unnecessarily expensive shaders; optimize particle counts; use texture atlases where appropriate; avoid excessive simultaneously active enemies; efficient scene loading; profile browser builds regularly; test keyboard and controller behavior; maintain stable frame pacing. **The Web build must be tested throughout development, not only at release.**

---

## 22. PRODUCTION PRIORITIES

**Prototype:** player movement; jumping and dash; basic weapon attacks; one enemy; one unique nightmare mechanic; one small exploration area; one browser-exported build.

**Vertical Slice:** one complete region; one major NPC; one investigation quest; three common nightmares; one boss with multiple mechanics; one meaningful resolution decision; one checkpoint; basic progression; polished audio and visual presentation.

**Full Production:** remaining regions; complete narrative; full nightmare roster; character storylines; boss encounters; skills and equipment; optional content; endings.

**Final Polish:** combat feel; animation quality; level readability; performance; audio; save reliability; browser compatibility; bug fixing; accessibility.

---

## 23. NON-NEGOTIABLE DESIGN RULES

1. No generic enemies with different colors and names.
2. No bosses that only have oversized health bars.
3. No meaningless skill upgrades.
4. No repetitive quests disguised as content.
5. No unnecessary dialogue walls.
6. No confusing combat visual effects.
7. No artificial difficulty.
8. No random mechanics without narrative justification.
9. No major feature that exists only to inflate the game.
10. No sacrifice of browser performance for unnecessary technical complexity.

Every major system must reinforce the central identity of Nightmare Hunter.

---

## FINAL GAMEPLAY PRINCIPLE

The player should begin the game believing they are a hunter of monsters. As they explore, they discover that hunting is not simply about killing. They learn that every nightmare has a reason to exist. They discover that the most dangerous creatures may be the ones they understand best. And eventually, they must confront the possibility that the line between hunter and nightmare is not as clear as they once believed.

> **Nightmare Hunter must make exploration mysterious, combat expressive, progression meaningful, and every major hunt unforgettable.**
