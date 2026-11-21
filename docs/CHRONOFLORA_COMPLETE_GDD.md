# Game-godot — Chronoflora: Complete Game Design Document

**Project:** Chronoflora (working title)
**Document:** Phase 5 — Complete Game Design Document (GDD)
**Branch:** `arena/5213ce08-game-godot` (from `528aba3f32cb10313f1fc195c0e1620a5ccec0fe`)
**Date:** 2026-11-21
**Status:** Pre-production design — awaiting approval before prototype
**Engine:** Godot 4.x
**Platform:** PC (Windows, Mac, Linux)

---

## 1. Core Gameplay Architecture

### 1.1 The Core Gameplay Loop

Chronoflora operates on a **six-phase loop** that repeats across eras. Each iteration represents one "season" in the current era.

| Phase | Action | Player Input | Output / Consequence |
|-------|--------|--------------|----------------------|
| **Observe** | Survey the current garden state in the active era. | Walk, look, examine plants, read journal. | Identify which plants are thriving, fading, extinct, or mutated. Note temporal anomalies. |
| **Tend** | Perform gardening actions on plants and soil. | Plant seeds, water, prune, harvest seeds, cross-pollinate, remove weeds. | Immediate plant state changes; soil depletion; seed inventory changes; water consumption. |
| **Record** | Log discoveries in the Botanical Journal. | Open journal, add notes, press flowers, sketch. | Unlocks lore entries, puzzle hints, species data. No direct world change. |
| **Shift** | Change the active temporal era. | Press Era Shift key at an Anchor Stone (specific locations). | Garden geometry, lighting, flora, and state transform to the target era. Temporal stamina cost. |
| **Discover** | Explore newly accessible areas created by cross-era changes. | Walk into previously blocked zones, examine fossils, read echoes. | New seeds, journal entries, tool upgrades, Impossible Flora. |
| **Preserve** | Deposit seeds and record extinct species in the Seed Vault. | Access Vault at the Crown (central hub). | Species protected from permanent extinction; unlocks replanting in any era. |

**Loop duration:** One full loop (all six phases) takes approximately 10–15 real minutes. A full playthrough comprises roughly 80–100 loops across five eras.

### 1.2 Player Controls and Interactions

| Input | Action | Context | Result |
|-------|--------|---------|--------|
| WASD / Left Stick | Move Keeper | All times | Smooth 2D movement; animation state: idle → walk → run (hold Shift). |
| Mouse / Right Stick | Aim cursor | All times | Highlights interactable objects (plants, Anchor Stones, objects). |
| Left Click / Action Button | Interact | On plant | Context menu: Plant / Water / Prune / Harvest / Examine. On object: Use / Examine / Take. |
| Right Click / Secondary Button | Examine | On any object | Open journal entry; show plant stats; show temporal echo if applicable. |
| E / Era Shift Key | Shift Era | At Anchor Stone | Open era selector; choose target era; pay temporal stamina; transition. |
| Tab / Journal Key | Open Journal | Any time | Pause game; view species data, notes, pressed flowers, quest log. |
| V / Vault Key | Open Seed Vault | At Crown only | Deposit/withdraw seeds; view extinction status; replay preserved species. |
| 1-5 / Quick Plant | Quick-select seed | Holding seeds | Equip selected seed type for immediate planting. |

**Interaction constraints:**
- The Keeper cannot enter deep water without a lily pad bridge (unlocked via Era 2 root growth).
- The Keeper cannot climb steep cliffs without vine handholds (grown in Era 1, persist to Era 3).
- The Keeper can carry maximum 8 seed packets and 3 tools at once.

### 1.3 How Gardening Works

**Planting rules:**
- Seeds can only be planted in tillable soil tiles (dark brown, not rock, not ash, not water).
- Each seed has an `era_affinity` array listing eras in which it can germinate.
- Planting outside affinity = seed consumed, no growth, "The soil rejects this seed" journal note.
- One plant per 2×2 tile plot. Plants cannot overlap.

**Growth model:**
- Each species has 4 growth stages: Seed → Sprout → Mature → Bloom → Seed-bearing.
- Advancement requires: accumulated `growth_points` (GP) from sunlight + water + correct temperature.
- GP gained per in-game day: `base_rate × climate_multiplier(era) × soil_quality_multiplier`.
- Watering adds immediate `water_bonus` GP (max 1 application per day per plant).
- Pruning mature plants can trigger secondary blooms or seed production.

**Soil system:**
- Each 2×2 plot has `soil_quality` (0–100) and `nutrient_profile` (nitrogen, phosphorus, potassium).
- Planting consumes nutrients based on species `nutrient_cost`.
- Soil quality degrades by 5 per growth cycle; restored by: fallow (1 day = +10), cover crops (clover species), compost (crafted from harvested plant waste).
- Soil below 20 quality = plants grow at 25% rate; below 5 = cannot plant.

### 1.4 Botanical Experimentation

**Cross-pollination rules:**
- Two mature plants of different species within 3 tiles can cross-pollinate if:
  - Both are in Bloom stage.
  - Same era (cross-era pollination impossible except via Impossible Flora).
  - Pollinator present (bee/butterfly species active in that era).
- Result: 1–3 hybrid seeds with mixed traits.
- Hybrid trait inheritance:
  - Color: 50% parent A, 50% parent B.
  - Era affinity: intersection of parents (if empty, hybrid is sterile).
  - Growth rate: average of parents ±10% random.
  - Special properties: 30% chance to inherit one special property from each parent.

**Impossible Flora creation:**
- Requires: one plant from Era N, one from Era N+2 (skipping an era), and a Paradox Pollen (rare drop from temporal anomalies).
- Result: a plant that exists in two eras simultaneously.
- Implementation: The plant object is duplicated across both era states with a shared `paradox_id`. Changes to one (watering, pruning, death) apply to both.

### 1.5 Time Shifting

**Mechanics:**
- The player can only shift at **Anchor Stones** — 7 fixed locations in the garden, one per major zone.
- Shifting costs `temporal_stamina` (max 100). Cost = 25 per era step (shifting from Era 1 to Era 3 costs 50).
- Temporal stamina regenerates at 1 per real minute, or instantly when resting at the Crown (Era 5 hub).
- During shift: screen cross-dissolves between era palettes over 1.5 seconds. Player input disabled during transition.

**State preservation:**
- All object states (plant growth, soil quality, placed items, opened puzzles) are saved per era in `GardenState`.
- Shifting loads the target era's state and unloads the current era's state (kept in memory, not destroyed).

### 1.6 Plants Across Five Eras

Each plant species has an `era_presence` definition:

| Presence Type | Meaning | Example |
|---------------|---------|---------|
| Native | Grows naturally in this era. | Ember Moss in Pre-Bloom. |
| Introduced | Player brought it from another era. | Rooted Age oak planted in Ash Epoch. |
| Fossil | Dead imprint only; can be excavated but not grown. | God Bloom fossil in Ash Epoch. |
| Extinct | Was present, now gone; can be revived from Seed Vault. | Sylthene Memory Tree. |
| Impossible | Exists in two eras simultaneously via paradox. | Chrono-Bloom (Era 2 + Era 4). |

A plant that is Native in Era 1 but not planted/tended may become Fossil in Era 3, then Extinct in Era 5 unless the player intervenes.

### 1.7 Ecosystem Evolution

**Fauna system:**
- Fauna are aesthetic + functional indicators, not directly controllable.
- Species spawn based on plant diversity:
  - Bees: require 3+ blooming flowers in era → increase pollination rate by 20%.
  - Earthworms: require high soil quality → increase soil regeneration by 10%.
  - Birds: require mature trees → spread seeds 2 tiles beyond planted plots.

**Succession rules:**
- Empty tillable plots progress naturally over eras:
  - Day 1–30: Bare soil.
  - Day 31–90: Moss (Pre-Bloom/Ash only) or Grass (other eras).
  - Day 91+: Shrub → Young Tree → Mature Tree (era-dependent maximum).
- Player can halt succession by planting desired species or paving with stone (Era 3+).

### 1.8 Exploration

**Movement gating:**
- Some zones blocked by: deep water (Era 1 only, unless lily pads grown), rockfalls (Era 3+), thorn barriers (Era 2), temporal fog (Era 4).
- Gates open via cross-era actions: roots from Era 1 crack Era 3 rocks; branches from Era 2 bridge Era 4 water.

**Discovery objects:**
- Fossil beds: excavate with Trowel (tool) to obtain extinct species seeds.
- Memory Trees: interact to play 10–20 second audio-visual flashback of Sylthene life.
- Cave paintings: Era 1 only; reveal locations of Impossible Flora.
- Anchor Stones: unlock era shift capability for their zone.

### 1.9 Resource Management

| Resource | Obtained From | Used For | Capacity |
|----------|---------------|----------|----------|
| Seeds | Harvested plants, fossil excavation, quest rewards | Planting | 8 packets |
| Water | Temporal Spring (Crown), rain (era-dependent) | Watering plants | 3 uses (refills at spring) |
| Compost | Harvested plant waste, food scraps | Soil restoration | 10 units |
| Temporal Stamina | Rest at Crown, time passage | Era shifting | 100 points |
| Journal Pages | Exploration, discoveries | Unlock lore/puzzle hints | Unlimited |

### 1.10 Progression

**Progression is gated by:**
- **Era access:** Start with Era 1 and Era 5. Unlock Eras 2, 3, 4 by restoring Anchor Stones and resolving narrative blocks.
- **Tool tiers:** Trowel (start) → Glass Lantern (see temporal echoes) → Shears (prune paradox plants) → Seed Press (create hybrid seeds).
- **Knowledge:** Journal entries unlock planting tips, era affinity data, puzzle solutions.

---

## 2. The Five Eras

### 2.1 Era Overview Table

| Era | Name | Time Period | Palette | Climate | Soil | Unlock Requirement |
|-----|------|-------------|---------|---------|------|-------------------|
| 1 | Pre-Bloom | Primordial wild | Deep green, moss brown, bioluminescent cyan | Humid, warm, frequent rain | Rich peat, soft | Start (available) |
| 2 | The Rooted Age | Sylthene civilization height | Amber, terracotta, leaf-green, sun-gold | Temperate, steady rainfall | Loam, cultivated | Restore Anchor Stone in Era 1 |
| 3 | The Withering | Civilization collapse | Rust red, bruised purple, sickly yellow, ochre | Erratic, drought, acid rain | Compacted, dry | Preserve 5 species across Era 1→2 |
| 4 | The Ash Epoch | Post-collapse silence | Ash grey, charcoal, pale bone, ember orange | Cold, dry, wind | Ash, thin | Resolve Withering puzzle in Era 3 |
| 5 | The Emergence | Present / uncertain future | Mint, blush, pale gold, lavender | Mild, regenerating | Mixed, recovering | Restore Anchor Stone in Era 4 |

### 2.2 Era 1 — Pre-Bloom (The Wild Before)

**Environmental appearance:**
- Primordial wetland. Giant ferns, cycads, bioluminescent moss pools. Shallow water covers 30% of the garden. No stone structures, only cave openings.
- Lighting: dappled sunlight through canopy; bioluminescent plants glow at night.

**Available plant species:**
- Ember Moss (native), Whisper Fern (native), Sun-pitcher (native), Mud-lily (native, aquatic), Thornvine (native, invasive).

**Soil and climate:**
- Soil: peat-rich, high water retention.
- Climate: 70% chance of rain each day; temperature stable.

**Environmental hazards:**
- Deep water: Keeper cannot enter without lily pad bridge.
- Thornvine: spreads 1 tile per day if unpruned; blocks paths.

**Unique gameplay opportunities:**
- First era where players learn cross-era root mechanics (roots planted here crack Era 3 stone).
- Cave paintings reveal Impossible Flora locations.

**Important discoveries:**
- First fossil bed (Era 2 species fossilized here).
- Child's cave paintings (narrative: nomadic humans observe the garden).

**Changes caused by previous eras:**
- None (this is the earliest era). Changes made here propagate to Eras 2–5.

**Main objectives:**
- Plant 3 native species to restore water spring.
- Unlock Anchor Stone in Central Glade.
- Discover first fossil bed.

**Narrative revelations:**
- The garden existed before humans. Nomads drew it but did not understand it.
- The Sylthene did not create the garden; they found it already here.

### 2.3 Era 2 — The Rooted Age (Civilization at Height)

**Environmental appearance:**
- Grown architecture: hollow trees as homes, root bridges, living walls. Gardens are cultivated and ordered. Flower beds, trellises, arbors.
- Lighting: golden hour permanently; warm, abundant.

**Available plant species:**
- Sylthene Oak (native), Memory Tree (native), Sunspire (native), Bloomvine (native), Hearthbloom (native, cultural significance).

**Soil and climate:**
- Soil: loam, cultivated by Sylthene; high baseline quality.
- Climate: steady rainfall; mild temperature.

**Environmental hazards:**
- None natural. Sylthene structures can block paths if not navigated around.

**Unique gameplay opportunities:**
- Cross-pollination with bee pollinators (20% bonus).
- Memory Trees store playable flashbacks when tended.
- Root bridges grown here persist as platforms in Era 4.

**Important discoveries:**
- Sylthene journals describing the God Bloom experiment.
- The Seed-Witch's first appearance (ambiguous vendor).

**Changes caused by previous eras:**
- If Ember Moss was grown in Era 1, bioluminescent pockets appear in Era 2 caves.
- If Thornvine was left unchecked in Era 1, it chokes Sylthene root bridges in Era 2.

**Main objectives:**
- Grow 2 Memory Trees to unlock flashback #1.
- Restore 1 Anchor Stone.
- Cross-pollinate first hybrid.

**Narrative revelations:**
- The Sylthene worshipped the Crown Garden as the heartbeat of time.
- They began the God Bloom experiment to see all time at once.

### 2.4 Era 3 — The Withering (The Collapse)

**Environmental appearance:**
- Decaying version of Era 2. Root bridges are cracked stone arches. Trees are petrified stumps. Flower beds are overgrown with weeds. Acid rain stains.
- Lighting: bruised purple sky; sickly yellow sun; long shadows.

**Available plant species:**
- Ashwillow (native), Rustvine (native, invasive), Sicklebloom (native), Witherwort (native), Petrified Fern (fossil only).

**Soil and climate:**
- Soil: compacted, dry, low nutrients.
- Climate: 40% chance of acid rain (damages plants not under cover); 30% drought (water costs doubled).

**Environmental hazards:**
- Acid rain: damages unprotected plants by 1 stage per storm.
- Dust storms: obscure vision; reduce solar GP by 50%.
- Temporal loops: small areas repeat the same 2 minutes; player can walk through but actions reset.

**Unique gameplay opportunities:**
- Fossil excavation yields Era 1 and Era 2 species seeds.
- Petrified wood can be harvested for tool upgrades.
- Temporal loop puzzles: actions must be completed within one loop cycle.

**Important discoveries:**
- The God Bloom excavation site (locked until Era 4 shift).
- Sylthene mass grave / root burial site.

**Changes caused by previous eras:**
- If forests were grown in Era 2, acid rain is reduced by canopy cover.
- If root bridges were grown in Era 2, they are collapsed but climbable ruins in Era 3.

**Main objectives:**
- Excavate 2 fossil beds.
- Survive 3 acid rain events (protect plants with covers or move them).
- Unlock Anchor Stone in Ruined Terrace.

**Narrative revelations:**
- The God Bloom experiment fractured time. The Sylthene did not die; they were absorbed into the garden's root system.

### 2.5 Era 4 — The Ash Epoch (The Silence)

**Environmental appearance:**
- Ash-covered valley. Petrified trees as blackened statues. Sparse grey grass. Ember flowers grow in cracks. Monks' simple stone shelters.
- Lighting: cold grey dawn; ember orange at sunset; moonlight silver at night.

**Available plant species:**
- Ashwillow (native), Ghost-pollen (native), Ember Flower (native), Cinder Moss (native), Petrified Root (fossil only).

**Soil and climate:**
- Soil: thin ash, poor water retention.
- Climate: cold, dry, constant wind. Water evaporates 50% faster.

**Environmental hazards:**
- Cold snap: water freezes overnight; plants cannot be watered until thaw.
- Wind: spreads ash, reduces visibility; can blow unharvested seeds away.

**Unique gameplay opportunities:**
- Root networks from Era 1 and Era 2 are visible as translucent echoes, revealing hidden paths.
- Ash-covered fossils are easier to spot (contrast).
- Monk shelters offer rest (temporal stamina restore) and lore.

**Important discoveries:**
- The Archivist (monk NPC) trades knowledge for rare seeds.
- Impossible Flora blooming in ash cracks.

**Changes caused by previous eras:**
- If trees were grown in Era 2, their petrified forms create climbable structures in Era 4.
- If water spring was restored in Era 1, a small oasis exists in Era 4 around it.

**Main objectives:**
- Restore Anchor Stone in Ash Grove.
- Complete Archivist's seed collection quest (3 rare species).
- Discover first Impossible Flora.

**Narrative revelations:**
- The previous Keeper (Echo) tried and failed to save the garden.
- The Archivist remembers species names lost in The Withering.

### 2.6 Era 5 — The Emergence (Present / Future)

**Environmental appearance:**
- Valley awakening. New growth on old foundations. Pastel wildflowers. Young trees. Simple human settlements at valley edge (not in garden). The garden is overgrown but alive.
- Lighting: soft morning haze; pastel skies; gentle light.

**Available plant species:**
- Dawn Lily (native), Hopebloom (native), Silvergrass (native), Phoenix Fern (native), Chrono-Bloom (Impossible, if created).

**Soil and climate:**
- Soil: mixed, recovering, moderate quality.
- Climate: mild, regenerating; 50% chance of gentle rain.

**Environmental hazards:**
- None severe. This is the player's "safe" era for experimentation.

**Unique gameplay opportunities:**
- Final cross-era synthesis: combine knowledge from all eras.
- The Seed Vault is fully accessible here.
- Ending choice is made here.

**Important discoveries:**
- The God Bloom's final stage (if player chooses to complete it).
- The player's own journal from an earlier time loop (narrative twist).

**Changes caused by previous eras:**
- Nearly every player action across Eras 1–4 manifests here: forests, extinct species revived, Impossible Flora, cleared paths.

**Main objectives:**
- Make final ending choice.
- Preserve or let go of the garden.

**Narrative revelations:**
- The player is the next Keeper in a cycle, or the previous Keeper returned.
- The garden is a living time machine; its fate determines time's fate.

### 2.7 Cross-Era Dependency System

```
Era 1 actions → Era 2: Root growth, water spring restoration, species introduction
Era 2 actions → Era 3: Tree maturity, canopy cover, structure placement
Era 3 actions → Era 4: Fossil preservation, ruin clarity, temporal loop resolution
Era 4 actions → Era 5: Ash clearing, fossil exposure, knowledge preservation
Era 5 → Era 1: Seed Vault reintroduction (closed loop)
```

Each era has **Anchor Stones** (7 total, one per zone, shared across eras). Restoring an Anchor Stone in one era restores it in all eras, but the method differs:
- Era 1: Clear vines around it.
- Era 2: Clean Sylthene carvings from it.
- Era 3: Excavate it from ash.
- Era 4: Reassemble broken pieces.
- Era 5: Activate it with preserved seeds.

---

## 3. Botanical System

### 3.1 Plant Data Architecture (Data-Driven)

Each species is a Godot `Resource` file (`*.tres`) with the following fields:

```gdscript
# Conceptual data structure (not implementation code)
PlantSpecies:
  id: String
  display_name: String
  visual_id: String (sprite atlas reference)
  era_availability: Array[EraEnum] # eras where it can grow natively
  growth_stages: Array[StageDefinition] # 4 stages
  growth_conditions:
    temperature_min: float
    temperature_max: float
    water_required: float
    soil_quality_min: int
    light_required: float
  nutrient_cost: Vector3 # nitrogen, phosphorus, potassium
  special_properties: Array[SpecialProperty] # bioluminescent, paradox, etc.
  cross_era_behavior: CrossEraData
  mutations: Array[MutationDefinition]
  ecological_effects: Array[EcologicalEffect]
  extinction_conditions: Array[ExtinctionCondition]
  seed_yield: int
  harvest_items: Array[ItemDrop]
```

### 3.2 Initial Species Roster (25 Species)

| # | Name | Era | Stages | Water | Soil | Special Properties | Cross-Era Behavior | Mutations | Extinction Condition |
|---|------|-----|--------|-------|------|-------------------|-------------------|-----------|---------------------|
| 1 | Ember Moss | 1,4 | 4 | Low | Low | Bioluminescent | Roots glow in Era 4 echoes | Crimson Moss | Zero living specimens in Eras 1 & 4 |
| 2 | Whisper Fern | 1 | 4 | Medium | Medium | Sound-dampening | Fronds become Era 3 fossils | Silver Fern | Not replanted within 3 eras |
| 3 | Sun-pitcher | 1,2 | 4 | High | Medium | Carnivorous (traps pests) | Becomes petrified in Era 3 | Golden Pitcher | Drought in Era 2 + not watered |
| 4 | Mud-lily | 1 | 4 | Aquatic | Aquatic | Aquatic only | Lily pads bridge Era 4 water | Pink Lily | Water spring not restored by Era 2 |
| 5 | Thornvine | 1,3 | 4 | Low | Low | Invasive, blocks paths | Chokes Era 2 root bridges | Blood Thorn | Actively eradicated in all eras |
| 6 | Sylthene Oak | 2 | 5 | Medium | High | Memory Tree host | Petrified trunk in Era 4 | Black Oak | Not grown in Era 2 |
| 7 | Memory Tree | 2 | 5 | Medium | High | Stores flashbacks | Roots visible as echoes in Era 4 | Crystal Memory | Not tended in Era 2 for 10 days |
| 8 | Sunspire | 2 | 4 | Medium | High | Attracts bees | Stalks become Era 3 ruins | Red Sunspire | No pollinators in Era 2 |
| 9 | Bloomvine | 2 | 4 | Medium | Medium | Climbing | Bridges Era 4 gaps | White Bloomvine | Not pruned in Era 2 |
| 10 | Hearthbloom | 2 | 4 | Low | Medium | Cultural significance | Ash preserves seeds in Era 4 | Blue Hearthbloom | Sylthene structures destroyed in Era 3 |
| 11 | Ashwillow | 3,4 | 4 | Low | Low | Grey bark, flexible | Grows from Era 3 petrified roots | Black Ashwillow | Ash covers all soil in Era 4 |
| 12 | Rustvine | 3 | 4 | Low | Low | Corrosive, damages stone | Spreads to Era 4 ruins | Deep Rust | Actively removed in Era 3 |
| 13 | Sicklebloom | 3 | 4 | Low | Low | Blooms during acid rain | Seeds survive to Era 5 | Pale Sicklebloom | Not seeded during acid rain event |
| 14 | Witherwort | 3 | 4 | Low | Low | Indicates temporal loops | Roots stabilize Era 5 soil | Dark Witherwort | Not harvested during loop event |
| 15 | Petrified Fern | 3,4 (fossil) | 1 (fossil) | N/A | N/A | Excavatable | N/A | N/A | N/A (fossil) |
| 16 | Ghost-pollen | 4 | 4 | Low | Low | Translucent, drifting | Crosses eras as pollen | Silver Pollen | Wind blows all seeds away |
| 17 | Ember Flower | 4 | 4 | Low | Low | Glows in dark | Seeds germinate in Era 5 dawn | Orange Ember | Not blooming during Era 4 sunset |
| 18 | Cinder Moss | 4 | 4 | Low | Low | Ash-tolerant | Covers Era 5 barren soil | Grey Cinder | Era 5 soil too rich (outcompeted) |
| 19 | Dawn Lily | 5 | 4 | Medium | Medium | First bloom of day | Opens Era 1 echoes | Pink Dawn | Not planted in Era 5 |
| 20 | Hopebloom | 5 | 4 | Medium | High | Endgame species | Grows from God Bloom seed | Gold Hope | God Bloom not completed |
| 21 | Silvergrass | 5 | 4 | Low | Medium | Fast succession | Covers empty Era 5 plots | Variegated Silver | Not present in Era 5 |
| 22 | Phoenix Fern | 5 | 4 | Medium | Medium | Fire-resistant | Survives Era 4 ash | Red Phoenix | Era 4 cold snap kills all |
| 23 | Chrono-Bloom | 2,4 (Impossible) | 4 | Medium | Medium | Exists in two eras | Paradox plant; shared state | Purple Chrono | Dies in either era |
| 24 | God Bloom | 2,3,5 | 5 | High | High | Endgame objective | Fossil in Era 3, bloom in Era 5 | White God | Not completed before Withering spreads |
| 25 | Rootvine | 1,2,3 | 4 | Medium | Medium | Structural roots | Cracks Era 3 stone; bridges Era 4 | Iron Root | Not grown in Era 1 |

### 3.3 Growth Stage Definitions

Each stage has:
- `duration_days`: days to advance (modified by conditions).
- `sprite_set`: per-era sprite variations.
- `interactions_allowed`: what player can do (water, prune, harvest).
- `ecological_output`: what it produces (pollen, oxygen, shade, root depth).

Example — Sylthene Oak:
- Seed: 2 days. Cannot interact.
- Sprout: 5 days. Water required.
- Mature: 10 days. Can prune; hosts Memory Tree flashbacks.
- Ancient: 20 days (Era 2 only). Produces acorns; roots deepen (cross-era effect).

### 3.4 Impossible Flora System

**Definition:** Plants that exist in two eras simultaneously, sharing a single logical state.

**Implementation:**
- Created via cross-pollination between Era N and Era N+2 species using Paradox Pollen.
- The plant object has a `paradox_id`. When the player shifts to either linked era, the same plant instance loads with era-appropriate sprites.
- Watering in Era 2 waters the plant in Era 4. Killing it in one era kills it in both.
- **Gameplay use:** Paradox plants act as temporal anchors. If a Chrono-Bloom is blooming in Era 2 and Era 4 simultaneously, it stabilizes the Anchor Stone between them, allowing era shifts without stamina cost in that zone.

**Mutations:**
- Hybrids have a 5% base chance to mutate into Impossible Flora if pollinated across an era gap with Paradox Pollen.
- Mutation chances increase with: Garden Tier (higher = more stable time), presence of other Impossible Flora nearby.

---

## 4. Cross-Era Simulation

### 4.1 Root Echoes

**Rule:** Roots grown in Era N create physical changes in Era N+2.

| Root Depth | Era N Effect | Era N+2 Effect |
|------------|--------------|----------------|
| Shallow (0–2 tiles) | None | None |
| Medium (3–5 tiles) | None | Small cracks in stone walls (climbable) |
| Deep (6+ tiles) | None | Large cracks (passable), platform collapses, new cave entrances |

**Visual:** In Era N+2, root cracks appear as darker fissures in stone. In Era N, roots are visible as normal root systems.

**Implementation:** `RootEcho` data stores `source_plot`, `target_era`, `tiles_affected`, `echo_type`. Applied when loading target era.

### 4.2 Seed Drift

**Rule:** Seeds released by mature plants can travel across eras via wind, water, or animal vectors.

- Wind-dispersed seeds: 10% chance to appear in adjacent era's empty plots next season.
- Water-dispersed seeds: appear in Era 4 if plant grew near water in Era 1.
- Animal-dispersed: birds carry seeds 1–2 tiles beyond plot in same era only.

**Condition:** The receiving era must have suitable soil and climate for the species.

### 4.3 Climate Inheritance

**Rule:** Large-scale plantings in one era alter climate variables in future eras.

| Action in Era N | Effect in Era N+1 |
|-----------------|-------------------|
| Forest (5+ mature trees) | -1 temperature, +20% rainfall |
| Wetland (3+ aquatic plants) | +30% humidity, fog in mornings |
| Barren/ash (no plants) | +1 temperature, -20% rainfall, dust storms |
| Flower field (10+ blooming) | +1 pollinator species |

**Implementation:** `ClimateState` resource per era, modified by `EcologicalEffect` components on plants.

### 4.4 Ecological Succession

**Rule:** Untended plots follow a fixed succession timeline per era.

```
Bare soil → Moss/Grass → Shrub → Young Tree → Mature Tree (era max)
```

Player can interrupt succession by planting desired species or placing stone paths (Era 3+).

### 4.5 Species Extinction

**Rule:** Each species has a population count across all eras where it can exist.

- Population decreases when: plants die, are harvested without reseeding, or era conditions become unsuitable.
- Population increases when: player plants, seeds drift naturally, hybrids are created.

**Extinction threshold:** Population reaches 0 in ALL eras where the species can exist.

**Consequence:** Species is marked `extinct` in the journal. Its sprite is greyed out. It can only be replanted if the player previously deposited seeds in the Seed Vault.

**Warning system:** When a species drops to its last living specimen, the journal shows: *"Last known specimen: Era 2, Central Glade."*

### 4.6 The Seed Vault

**Location:** The Crown (Era 5 hub), accessible from Era 5 only.

**Capacity:** 50 seed slots.

**Functions:**
- Deposit seeds from any era (protected from extinction).
- Withdraw seeds to plant in any era where they are viable.
- View extinction status of all species.
- Reintroduce extinct species (costs 1 seed deposit + 1 journal entry about that species).

**Narrative role:** The Vault is the previous Keeper's legacy. Finding empty slots with names written in them creates emotional weight.

### 4.7 Temporal Paradoxes

**Definition:** Situations where a plant's existence in two eras creates contradictory requirements.

**Example:** Chrono-Bloom needs water in Era 2, but Era 4 is experiencing a drought. Watering in Era 2 satisfies both; if the player chooses not to water in Era 2, the Era 4 instance dies too.

**Resolution UI:** When shifting eras, if a paradox plant is in critical state in the other linked era, a warning appears: *"Your Chrono-Bloom is wilting in The Rooted Age."*

**Paradox puzzles:** Some doors require a paradox plant to be blooming in both eras simultaneously to unlock.

### 4.8 System Interaction Safeguards

To prevent confusing or unpredictable outcomes:

1. **Transparency:** Root echoes are visible as translucent overlays when the player holds the Glass Lantern.
2. **Predictability:** Seed drift has a maximum range (1 era away, adjacent plots only). No random long-distance jumps.
3. **Warnings:** Extinction warnings appear 3 game days before permanent loss.
4. **Undo limit:** Players can undo the last gardening action within the same session (not across era shifts).
5. **Cache:** Era states are held in memory; shifting is instant after first load.

---

## 5. World and Level Design

### 5.1 Main Garden Layout

The garden is a single hand-crafted map, approximately 160×120 tiles (10×8 zones of 16×15 tiles each). The same collision geometry is used across all eras; only tile sprites, decorations, and plant states change.

**Zones:**
1. **Central Glade** — Starting area. Contains the first Anchor Stone and the water spring.
2. **Root Terrace** — Elevated area with stone steps. Era 2 has root bridges.
3. **Ash Grove** — Lower area. Era 4 is ash-covered; Era 1 is marsh.
4. **Sun Bowl** — Open, sunny area. Era 2 has flower fields.
5. **Moon Hollow** — Shaded, northern area. Era 4 has monk shelters.
6. **God Bloom Crater** — Central depression. Locked until late game.
7. **Echo Cliffs** — Western edge. Cave paintings in Era 1; fossils in Era 3.

### 5.2 Important Locations

| Location | Era 1 | Era 2 | Era 3 | Era 4 | Era 5 |
|----------|-------|-------|-------|-------|-------|
| Crown (Hub) | Marsh clearing | Sylthene gathering circle | Petrified stump | Monk shelter | Keeper's residence |
| Water Spring | Active pool | Decorated fountain | Dry crack | Frozen trickle | Restored spring |
| Anchor Stone (each zone) | Vine-covered | Carved | Excavated | Reassembled | Activated |
| Fossil Bed | Fresh bones | Buried | Exposed | Ash-covered | Studied |

### 5.3 Exploration Areas

**Surface zones (7):** All listed above, accessible from start in Era 5; gated in earlier eras.

**Subterranean zones (3):**
- **Root Caves** (Era 1 & 3): Accessible via root cracks grown in Era 1. Contains fossil beds.
- **Sylthene Vault** (Era 2 & 3): Underground library. Accessible via Memory Tree roots.
- **The Heart** (Era 5 only): Final area beneath God Bloom Crater.

### 5.4 Hidden Areas

| Hidden Area | Access Method | Era | Contents |
|-------------|---------------|-----|----------|
| Impossibility Grove | Paradox plant blooming | 2 & 4 | Impossible Flora seeds |
| Echo Archive | Memory Tree flashback complete | 2 | Sylthene history journals |
| First Garden | All Anchor Stones restored | 5 | Original Keeper's tools |

### 5.5 Interactive Objects

| Object | Interaction | Tool Required | Result |
|--------|-------------|---------------|--------|
| Anchor Stone | Shift era | None | Open era selector |
| Fossil Bed | Excavate | Trowel | Seeds, journal pages |
| Memory Tree | Tend | None | Flashback cutscene |
| Cave Painting | Examine | None | Impossible Flora location |
| Temporal Spring | Collect water | Glass Bottle (tool) | Refill water |
| Seed Vault | Deposit/withdraw | None | Seed management |
| God Bloom | Tend | Shears, Glass Lantern | Endgame |

### 5.6 Environmental Puzzles

**Puzzle 1: The Root Lock (Era 3 → Era 1)**
- A stone wall blocks Root Terrace in Era 3.
- Player must grow Rootvine in Era 1 to crack the wall.
- Result: Wall is cracked/passable in Era 3.

**Puzzle 2: The Bloom Gate (Era 2 & Era 4)**
- A door in Era 4 requires two Hearthblooms blooming simultaneously in Era 2 and Era 4.
- Player must preserve Hearthbloom seeds from Era 2, plant in Era 4, and bloom both.

**Puzzle 3: The Fossil Key (Era 3)**
- Petrified Fern fossil must be revived by planting its living relative (Whisper Fern) in Era 1 nearby.
- Result: Fossil becomes living fern in Era 3, unlocking a path.

**Puzzle 4: The Paradox Bridge (Era 2 & Era 4)**
- Chrono-Bloom must bloom in both eras to create a root bridge across Ash Grove water.

### 5.7 Unlockable Regions

| Region | Unlock Condition | Era(s) |
|--------|-----------------|--------|
| Root Terrace | Restore Anchor Stone in Central Glade | All |
| Ash Grove | Restore Anchor Stone in Root Terrace | All |
| Sun Bowl | Grow 3 trees in Era 2 | 2, 3, 4, 5 |
| Moon Hollow | Complete Archivist quest | 4, 5 |
| God Bloom Crater | Preserve 10 species + read 5 journals | 5 |
| The Heart | Complete God Bloom puzzle | 5 |

### 5.8 Same Location Across Five Eras — Example: Central Glade

- **Era 1:** Marsh with standing water, ferns, cave entrance. Anchor Stone covered in vines.
- **Era 2:** Cultivated garden with flower beds, Sylthene stone path, Anchor Stone carved with glyphs.
- **Era 3:** Cracked fountain, dead trees, weeds, Anchor Stone half-buried in ash.
- **Era 4:** Grey ash, petrified tree stump, monk shelter nearby, Anchor Stone in pieces.
- **Era 5:** Restored spring, new wildflowers, Keeper's tools, Anchor Stone active with glowing seeds.

---

## 6. Story and Quest Structure

### 6.1 Main Chapters

| Chapter | Era Focus | Main Objective | Narrative Revelation |
|---------|-----------|----------------|---------------------|
| 1 — First Tending | 1, 5 | Restore water spring; learn era shifting | The garden exists across time |
| 2 — The Rooted Past | 2 | Grow Memory Trees; read 2 flashbacks | The Sylthene built a civilization here |
| 3 — The Withering | 3 | Excavate fossils; survive acid rain | The God Bloom experiment collapsed time |
| 4 — The Ash Silence | 4 | Meet the Archivist; find Impossible Flora | The previous Keeper failed |
| 5 — The Emergence | 5 | Access God Bloom Crater | The player is part of the cycle |
| 6 — Final Tending | 5 | Make ending choice | Fate of time and the garden |

### 6.2 Side Quests

| Quest | Giver | Era | Reward |
|-------|-------|-----|--------|
| The Archivist's Collection | Archivist | 4 | Rare seeds, lore entries |
| The Seed-Witch's Bargain | Seed-Witch | 2, 5 | Paradox Pollen, hybrid recipes |
| The Child's Drawings | Cave paintings | 1 | Impossible Flora locations |
| The Last Specimen | Journal system | Any | Seed Vault slot, extinct species revival |

### 6.3 Character Encounters

- **The Echo:** Seen at edge of screen in Eras 1, 3, 4. Never speaks. Leaves seed-packets with messages.
- **The Archivist:** Era 4 monk shelter. Trades knowledge for seeds. Knows names of extinct species.
- **The Seed-Witch:** Era 2 (disguised) and Era 5 (revealed). Sells Impossible Flora hybrids. Motives unknown.
- **The Child:** Era 1 cave paintings only. Never seen directly; their drawings are the encounter.

### 6.4 Major Revelations

1. **Mid-game:** The Sylthene did not vanish; they merged with the garden's root system. The "echoes" are them.
2. **Late-game:** The player's journal entries from Era 5 are the same ones found in Era 1 cave paintings — a closed time loop.
3. **Pre-ending:** The God Bloom is not a flower; it is the garden itself, blooming across all eras simultaneously.

### 6.5 Narrative Consequences

- Species preserved → Archivist dialogue changes; Seed-Witch offers better trades.
- Species extinct → Journal entries turn to ash; some puzzle solutions become unavailable.
- Ending choice → Determines which eras survive and whether the player remains as Keeper or becomes an Echo.

### 6.6 Ending Conditions

| Ending | Requirement | Outcome |
|--------|-------------|---------|
| The Weave | Preserve ≥15 species, complete God Bloom | All eras survive, intertwined. Garden becomes shared sanctuary. |
| The Bloom | Complete God Bloom, allow extinctions | Time unified; garden loses wildness; player becomes Echo. |
| The Silence | Allow garden to die, no extinctions prevented | Time resets to Pre-Bloom. Journal left for next Keeper. |

---

## 7. Player Progression

### 7.1 Player Abilities (No RPG Stats)

The Keeper has no level, no skill tree, no combat stats. Progression is entirely through **tools, knowledge, and access**.

### 7.2 Tools

| Tool | Unlock | Function | Era Availability |
|------|--------|----------|------------------|
| Trowel | Start | Dig, plant, excavate fossils | All |
| Watering Can | Start | Water plants (3 charges) | All |
| Glass Lantern | Chapter 2 | See temporal echoes and root echoes | All |
| Shears | Chapter 3 | Prune paradox plants; harvest Impossible Flora | All |
| Seed Press | Chapter 4 | Create hybrid seeds from two parent plants | All |
| Glass Bottle | Chapter 1 | Collect water from Temporal Spring | All |

### 7.3 Unlockable Botanical Knowledge

Journal entries unlock:
- Species era affinity (where it can grow).
- Cross-era root echo locations.
- Puzzle hints (optional; can be ignored).
- Lore about Sylthene civilization.

### 7.4 Garden Upgrades

| Upgrade | Cost | Effect |
|---------|------|--------|
| Expanded Seed Pouch | 10 seeds of 5 species | Carry 12 seed packets instead of 8 |
| Larger Watering Can | Water 50 plants | 5 charges instead of 3 |
| Compost Bin | 20 plant waste | Auto-produce compost from waste |
| Seed Vault Expansion | 5 rare species | 50 → 75 seed slots |

### 7.5 New Exploration Capabilities

| Capability | Unlock | Effect |
|------------|--------|--------|
| Lily Pad Bridge | Grow 3 Mud-lilies in Era 1 | Cross deep water in Era 1 & 4 |
| Vine Handholds | Grow Rootvine in Era 1 | Climb Era 3 cliffs |
| Petrified Steps | Excavate Era 3 petrified wood | Access Moon Hollow in Era 4 |
| Temporal Anchor | Restore all 7 Anchor Stones | Shift era without stamina cost |

### 7.6 Progression Milestones

| Milestone | Approx. Playtime | Unlock |
|-----------|------------------|--------|
| First era shift | 30 min | Era 2 access |
| First hybrid | 2 hours | Seed Press recipe |
| First Impossible Flora | 5 hours | Paradox puzzles |
| Seed Vault access | 6 hours | Species preservation |
| God Bloom Crater | 10 hours | Final chapter |
| Ending | 12–18 hours | Game complete |

### 7.7 Difficulty Progression

Difficulty increases through:
- **Time pressure:** Withering spreads faster in later chapters if the player ignores it.
- **Resource scarcity:** Water and soil quality degrade in Eras 3 and 4.
- **Puzzle complexity:** Cross-era puzzles require planning across 3+ eras by Chapter 4.
- **Extinction risk:** More species are at risk simultaneously in late game.

No combat difficulty; no permadeath (except species extinction).

---

## 8. UI/UX and Audio

### 8.1 Main Menu

- New Game / Load Game / Settings / Credits.
- Visual: A single seed on soil, with era-shift particles in background.
- Music: Main theme (piano, soft strings).

### 8.2 In-Game HUD

Minimal and diegetic:
- **Top-left:** Era indicator (icon + name), temporal stamina (circular gauge around lantern icon).
- **Top-right:** Seed pouch (4 visible slots; scroll for more), watering can charges (droplet icon).
- **Bottom-center:** Context action prompt ("Plant", "Water", "Shift Era") appears when near interactable.
- No health bar. Plant health shown visually (drooping, color fade, particle loss).

### 8.3 Botanical Journal

Diegetic menu (the Keeper's actual journal):
- **Species Page:** Illustration, growth stats, era affinity, extinction status, notes.
- **Pressed Flowers:** Collected plant samples, arranged by era.
- **Era Map:** Garden layout showing current era state and root echo connections.
- **Quest Log:** Active objectives, character messages.
- **Flashbacks:** Unlocked Memory Tree scenes, replayable.

### 8.4 Plant Information

Examining a plant shows:
- Name, stage, days to next stage, water/soil status.
- Era presence (Native / Introduced / Fossil / Extinct).
- Cross-era status (if linked to another era).
- Special properties.

### 8.5 Era Navigation

Era selector at Anchor Stones:
- Carousel of 5 era icons with palette-preview thumbnails.
- Shows temporal stamina cost and current stamina.
- Unavailable eras greyed out with reason ("Anchor Stone not restored").

### 8.6 Inventory

- Seed pouch grid (8 slots, expandable to 12).
- Tool belt (3 slots).
- Items: seeds, compost, Paradox Pollen, journal pages.

### 8.7 Quest Tracking

- Active quest shown in journal only. No HUD quest markers.
- World-based hints: the Keeper's journal has hand-drawn maps with X marks.

### 8.8 Settings

- Display (resolution, fullscreen, integer scale toggle).
- Audio (master, music, SFX).
- Controls (rebind keys/gamepad).
- Accessibility: colorblind mode (adds pattern overlays to era indicators), text size, slow era-shift transition.

### 8.9 Save/Load Interface

- Accessible from main menu and pause.
- Auto-save on era shift, journal entry, and seed deposit.
- Manual save slots: 5.
- Save thumbnail shows garden in current era.

### 8.10 Audio Direction

**Music:**
- 5 era themes (one per era), each 2–3 minutes, looping.
- Crossfade on era shift (2 seconds).
- Main theme plays in menu and Era 5.
- Dynamic layer: instruments drop out when Withering is active; return when garden is healthy.

**Sound Design:**
- **Era ambience:** Insects (Era 1), wind through leaves and distant chimes (Era 2), cracking earth (Era 3), wind through ash (Era 4), birds and gentle wind (Era 5).
- **Gardening SFX:** Seed drop (soft click), water droplet, soil crunch, plant bloom (gentle chime), leaf rustle.
- **Era shift:** Reversed cymbal swell + deep root groan (1.5 seconds).
- **UI:** Journal page turn, seed packet rustle, era selector click.
- **No voiced dialogue.** All communication via text + sound effects.

---

## 9. Technical Design for Godot 4

### 9.1 Scene Architecture

```
/res/
  scenes/
    world/
      garden.tscn          # Main garden node (Node2D)
      zones/
        central_glade.tscn
        root_terrace.tscn
        ...
      era_manager.tscn     # Autoload: manages era state
    gameplay/
      plant.tscn           # Plant instance (Node2D + Sprite2D + Area2D)
      keeper.tscn          # Player character (CharacterBody2D)
      anchor_stone.tscn    # Era shift trigger
      seed_vault.tscn      # Vault UI + data
    ui/
      journal.tscn
      hud.tscn
      main_menu.tscn
  scripts/
    managers/
      GardenManager.gd     # Central game state
      EraManager.gd        # Era shifting logic
      PlantManager.gd      # Plant growth simulation
      ExtinctionManager.gd # Species population tracking
    entities/
      Plant.gd
      Keeper.gd
    ui/
      Journal.gd
      HUD.gd
  resources/
    plants/                # *.tres plant definitions
    eras/                  # *.tres era definitions
    save_data.tres
```

### 9.2 Core Gameplay Managers

**GardenManager (Autoload, Singleton):**
- Holds `GardenState` resource: current era, all plot states, plant instances, species populations.
- Saves/loads to `user://savegame.sav` (JSON or encrypted BinaryFile).
- Emits signals: `era_changed`, `species_extinct`, `plant_bloomed`, `anchor_restored`.

**EraManager:**
- Handles era shift transitions: cross-dissolve shader, state load/unload, stamina cost.
- Maintains `EraState[5]` array; only active era is fully instantiated, others kept as serialized data.

**PlantManager:**
- Processes plant growth each in-game day.
- Calculates GP based on climate, soil, water.
- Handles cross-pollination, mutations, succession.
- Runs on a timer (1 game day = 8–12 real minutes, adjustable).

**ExtinctionManager:**
- Tracks species populations across eras.
- Emits warnings at population thresholds.
- Marks species extinct when population = 0 across all eras.
- Interfaces with Seed Vault for reintroduction.

### 9.3 Data-Driven Plant Definitions

- Each species is a `PlantSpecies.tres` resource in `res://resources/plants/`.
- Plants instantiate from these resources at runtime, allowing modding and easy balancing.
- Growth stages reference `StageDefinition.tres` resources (sprite, duration, interactions).
- Era definitions in `res://resources/eras/` (palette, climate, ambient audio bus).

### 9.4 Save System

- Save file contains:
  - Current era and player position.
  - `GardenState`: per-plot soil, plant species, growth stage, cross-era echoes.
  - Species populations and extinction flags.
  - Journal entries, unlocked tools, quest progress.
  - Seed Vault contents.
- Format: Godot `FileAccess` with JSON or `ResourceSaver` for `.tres`.
- Auto-save slots overwrite; manual saves are separate files.

### 9.5 Era State Management

- Each era's tilemap uses `TileMapLayer` with identical layer names across eras.
- Era switching:
  1. Serialize current era plant/soil state to `EraState` resource.
  2. Cross-dissolve shader plays.
  3. Deserialize target era `EraState`; instantiate plants at their growth stages.
  4. Apply cross-era echoes (root cracks, seed drift results).
- Performance: Only active era's plants are `Node2D` instances; inactive eras are plain data.

### 9.6 Cross-Era Simulation Architecture

- `CrossEraSimulation` node processes when an era is loaded:
  - Reads `RootEcho` data from source eras and applies to target era tiles.
  - Applies `ClimateInheritance` modifiers to target era climate.
  - Processes `SeedDrift` events.
- Simulation runs once per era load, not every frame.

### 9.7 Resource Management

- `AtlasTexture` for plant sprites (one atlas per era to minimize texture swaps).
- `Sprite2D` with `AnimationPlayer` for growth stages.
- `Light2D` for Keeper's lantern and era-specific ambient lighting.
- `Particles2D` for pollen, ash, fireflies, bioluminescence.

### 9.8 Performance Considerations

- Target: 60 FPS on integrated graphics (Intel UHD, 8 GB RAM).
- Plant culling: Plants outside camera view pause growth calculations (still advance via time delta on load).
- Tilemap layers: static geometry baked; only plants and particles are dynamic.
- Max concurrent plants: ~200 per era (well within Godot 2D limits).
- Save file size: estimated <1 MB.

---

## 10. Production Scope

### 10.1 Asset Breakdown

| Asset Category | Count | Reusable Across Eras | Notes |
|----------------|-------|---------------------|-------|
| Environments (zones) | 7 zones × 5 eras = 35 states | Base geometry (100%), tile palettes (50%) | Same collision, different sprites/lighting |
| Plant species | 25 | Sprites partially reusable (leaves, stems modular) | Each species needs 4 stage sprites × era variants |
| Growth animations | 25 species × 3 transitions | 75% reusable (sway loops shared) | Bloom animations unique per species |
| Environmental animations | 30 | 60% reusable (wind, water, particles) | Era-specific particle colors |
| Interactive objects | 15 | 100% reusable (Anchor Stones, spring, vault) | Era-specific wear states |
| UI assets | 40 | 100% reusable | Journal pages have era-specific artwork |
| Visual effects | 20 | 50% reusable (shaders, particles) | Era shift shader unique |
| Music tracks | 6 | 0 reusable | 5 era themes + main menu |
| Sound effects | 60 | 80% reusable | Era ambience unique per era |

### 10.2 Total Estimated Production

| Discipline | Person-Months |
|------------|---------------|
| Game Design / Direction | 3 |
| Programming (Godot) | 6 |
| Pixel Art & Animation | 8 |
| Writing / Narrative | 2 |
| Audio (Music + SFX) | 3 |
| QA / Testing | 2 |
| Production / Management | 2 |
| **Total** | **26 person-months** |

For a 5-person core team: **~5.5 months of full-time production** plus 2 months pre-production = **7–8 months**.

With part-time/contractor art: **12–14 months**.

### 10.3 Reusable vs. Unique Assets

**Highly reusable (build once, use across eras):**
- Keeper sprite and animations.
- Tool sprites.
- UI framework.
- Collision geometry.
- Shaders.

**Era-unique (must be produced 5 times):**
- Tile palettes and autotiles.
- Ambient lighting and particle colors.
- Era-specific plant variants (a tree looks different in Era 1 vs Era 4).
- Music themes.

---

## 11. Critical Design Review

### 11.1 Boring or Repetitive Loops

**Risk:** Planting and watering every day becomes a chore by hour 8.

**Solution:**
- Watering can has 3 charges; refill at spring (encourages exploration, not repetitive clicking).
- Plants don't die from one missed watering; they just pause growth.
- Cross-era consequences make each planting feel consequential, not repetitive.
- Automation: Compost bin and rain reduce manual watering in mid-game.

### 11.2 Frustrating Mechanics

**Risk:** Permanent species extinction feels punishing and may cause save-scumming.

**Solution:**
- Extinction warnings 3 game days in advance.
- Seed Vault allows reintroduction if player planned ahead.
- "The Silence" ending explicitly allows extinction as a valid path — not a failure state.
- No permadeath for the player; extinction is ecological, not personal.

**Risk:** Era shift stamina cost limits experimentation.

**Solution:**
- Temporal stamina regenerates while resting at Crown.
- Late-game upgrade (Temporal Anchor) removes cost for restored Anchor Stones.
- Early-game shifts are cheap (25 stamina = one shift; max 100).

**Risk:** Cross-era puzzles are opaque; players don't know why a wall cracked.

**Solution:**
- Glass Lantern reveals root echoes as translucent overlays.
- Journal entries hint at connections ("Roots from the marsh reach the stone terrace").
- First puzzle (Root Lock) is heavily telegraphed with tutorial messages.

### 11.3 Overcomplicated Systems

**Risk:** Climate inheritance + succession + seed drift + root echoes = too many variables to track.

**Solution:**
- Systems are layered: root echoes are introduced first (Chapter 1), climate in Chapter 2, succession in Chapter 3.
- UI shows only active influences on the selected plot.
- Journal summarizes cross-era effects for the current era.

### 11.4 Technical Risks

**Risk:** Era state desync (plant dies in Era 2 but is alive in Era 3 when it shouldn't be).

**Solution:**
- Single source of truth: `GardenState` resource. Era loading is deterministic from this resource.
- Unit tests for era transitions: shift 1→2→1 and verify state integrity.

**Risk:** Save file corruption on era shift.

**Solution:**
- Atomic writes: write to temp file, then rename.
- Keep last 3 save slots; auto-backup on era shift.

### 11.5 Production Bottlenecks

**Risk:** 25 plant species × 4 stages × 5 eras = 500+ sprite variations.

**Solution:**
- Modular sprite system: base plant body + era-specific overlays (flowers, leaves, fruit).
- Share stem/leaf sprites across species where botanically similar.
- Prioritize: 15 species fully unique, 10 species modular variants.

**Risk:** Animation workload for bloom sequences.

**Solution:**
- Reuse bloom animation frames with color swaps.
- Limit elaborate animations to 8 key species (including God Bloom and Impossible Flora).

### 11.6 Pacing Problems

**Risk:** Mid-game (Chapters 3–4) drags if extinction management dominates.

**Solution:**
- Chapter 3 introduces fossil excavation (new interaction) to break up gardening.
- Chapter 4 introduces the Archivist and Seed-Witch (new characters, dialogue).
- Impossible Flora mid-game provides a mechanical "power spike" (paradox puzzles).

### 11.7 Weak Progression Systems

**Risk:** Tool upgrades feel insignificant.

**Solution:**
- Each tool unlocks a new interaction type, not just a stat boost:
  - Shears → can prune paradox plants (new mechanic).
  - Seed Press → can create hybrids (new mechanic).
  - Glass Lantern → can see echoes (new information).

---

## Final Summary

### 1. Finalized Game Design Summary

**Chronoflora** is a single-location, cross-era botanical simulation for PC. The player tends one garden across five collapsed eras of one civilization. Plants are temporal anchors: actions in one era physically reshape other eras via root echoes, seed drift, and climate inheritance. Species can go extinct permanently. The player preserves botanical history through a Seed Vault, solves environmental puzzles that span eras, and chooses the fate of time in one of three endings.

### 2. Most Important Design Decisions

1. **One map, five eras:** A single hand-crafted garden viewed through five temporal lenses. This keeps asset production manageable while delivering massive environmental variety.
2. **Plants as temporal anchors:** Cross-era persistence is the core mechanic, not a side feature.
3. **Permanent extinction:** Creates emotional stakes and forces player choices; balanced by the Seed Vault.
4. **No combat, no RPG stats:** Progression through tools, knowledge, and access only.
5. **Diegetic UI:** The Keeper's journal is the menu; minimal HUD preserves immersion.
6. **Godot 4 data-driven architecture:** Plant species as Resources enables modding, balancing, and team collaboration.

### 3. Biggest Remaining Risks

| Risk | Severity | Mitigation |
|------|----------|------------|
| Cross-era puzzle opacity | High | Glass lantern echoes, journal hints, heavy tutorial on first puzzle |
| Sprite production volume (25 species × 5 eras) | High | Modular sprite system, prioritize 15 unique + 10 variants |
| Extinction frustration | Medium | Warnings, Seed Vault, valid "extinction allowed" ending |
| Pacing drag in mid-game | Medium | New interactions per chapter (fossils, paradox plants, characters) |
| Save desync across eras | Medium | Single source of truth (GardenState), deterministic loading |

### 4. Estimated Total Development Scope

- **Team:** 5 core (design, programming, art, writing, audio) + part-time QA.
- **Duration:** 12–14 months (including pre-production, production, polish).
- **Budget tier:** Indie / small studio.
- **Content:** ~25 plant species, 7 garden zones × 5 eras, 6 main chapters, 4 side quests, 3 endings, 6 music tracks, 60 SFX.
- **Playtime:** 12–18 hours main; 20–25 completionist.

### 5. Readiness Assessment for Prototype

**Ready to prototype:** Yes. The GDD specifies all mechanics with clear rules, inputs, outputs, and consequences. The Godot 4 scene architecture is laid out. Asset counts are quantified.

**Recommended first prototype (vertical slice):**
- Era 1 and Era 2 only.
- Central Glade + Root Terrace zones.
- 6 plant species (including Rootvine and one cross-pollination pair).
- Core loop: plant → grow → shift era → see root echo → unlock path.
- Save/load and era shift functionality.
- Journal with species entries.

**Estimated prototype duration:** 6–8 weeks.

---

**This GDD is complete and ready for your approval.** Once approved, the project may proceed to the vertical slice prototype in Godot 4. No code has been written and no assets have been produced yet.

Please confirm your approval of this complete Game Design Document, or request revisions before we proceed to prototyping.