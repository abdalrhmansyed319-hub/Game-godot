# Chronoflora — Godot Validation Checklist

**Project:** Chronoflora (Vertical Slice)
**Required Godot Version:** 4.7.2-stable (or later 4.x)
**Project Root:** `/home/user/Game-godot/` (contains `project.godot`)
**Main Scene:** `res://scenes/Main.tscn`

---

## IMPORTANT: Runtime Status

**The Godot project has NOT been executed by the Godot engine in this environment.**
All files have been audited and fixed by code review, but the Godot 4.x binary could not be downloaded or compiled in this sandbox (SSL blocked to `objects.githubusercontent.com`; no root access for compilation dependencies).

These tests are **written and ready to run** but **NOT yet executed**. You must run them on your own PC.

---

## How to Use This Checklist

1. Install Godot 4.7.2 or later from https://godotengine.org/
2. Open the project folder in Godot (`project.godot` at repository root)
3. Press F5 or click the Play button
4. Perform each test below in order
5. Record results: PASS / FAIL / NOT TESTED
6. Report any failures with screenshots and error messages

---

## Test 1: Project Import

**Steps:**
1. Install Godot 4.7.2+
2. Click "Import" in the Godot project manager
3. Select the repository root folder containing `project.godot`
4. Click "Import & Edit"

**Expected Result:**
- Project imports without errors
- Project appears in the project manager list
- Editor opens showing `Main.tscn` or the FileSystem dock

**Failure Looks Like:**
- Import dialog shows missing files or dependencies
- Editor reports "Failed to load scene" or script errors
- `project.godot` not recognized

**How to Report:** Screenshot of the import dialog error + full error text from the Godot console/output tab.

---

## Test 2: Main Menu

**Steps:**
1. Press F5 to run the project
2. Observe the opening screen

**Expected Result:**
- "CHRONOFLORA" title is displayed
- Three buttons visible: "NEW GAME", "CONTINUE", "QUIT"
- Background color is dark (approx. RGB 20, 20, 30)
- Title text color is teal/green (approx. RGB 100, 220, 200)

**Failure Looks Like:**
- Blank screen
- Missing title or buttons
- Error messages in the Godot output/console tab
- Scene fails to load

**How to Report:** Screenshot of the screen + console output tab contents.

---

## Test 3: New Game

**Steps:**
1. From the main menu, click "NEW GAME" (or navigate with keyboard and press Enter)
2. Observe the transition to gameplay

**Expected Result:**
- Main menu scene changes to the Game scene
- Player character (Keeper) appears in the center-left of the screen
- Garden tiles are visible (Pre-Bloom era: deep greens, moss browns, water)
- HUD appears in top-left showing ERA, STAMINA, WATER, SEED
- Era indicator shows "ERA: Pre-Bloom"
- Two Anchor Stones are visible in the garden

**Failure Looks Like:**
- Game scene doesn't load
- Player not visible
- HUD missing or showing errors
- Wrong era displayed

**How to Report:** Screenshot + scene tree from Godot editor (remote tab while running).

---

## Test 4: Player Movement

**Steps:**
1. In the gameplay scene, press WASD keys or arrow keys
2. Observe the Keeper character

**Expected Result:**
- Keeper moves in the direction of the pressed keys
- Movement is smooth at approximately 120 pixels/second
- Keeper sprite changes direction (down/up/left/right) based on movement
- Walking animation plays (4 frames per direction)
- Keeper stops when keys are released

**Failure Looks Like:**
- Keeper doesn't move
- Keeper moves but doesn't change direction
- No animation (static sprite)
- Movement is jerky or teleports

**How to Report:** Screenshot showing Keeper in different directions + description of which keys work/don't work.

---

## Test 5: Player Animations

**Steps:**
1. Hold a movement key for 2+ seconds
2. Observe the Keeper sprite
3. Release the key
4. Observe the Keeper returns to idle

**Expected Result:**
- Walking animation cycles through 4 frames while moving
- Animation stops on the first frame when idle
- Sprite sheet rows: Row 0 = down, Row 1 = up, Row 2 = left, Row 3 = right
- Each frame is 16×24 pixels, displayed at 32×48 (2× scale)

**Failure Looks Like:**
- Animation doesn't cycle (stuck on one frame)
- Wrong direction row displayed
- Sprite appears stretched or distorted
- Animation plays when idle

**How to Report:** Screenshot of the sprite sheet in the Godot editor + description of animation behavior.

---

## Test 6: Plant Selection

**Steps:**
1. Press keys 1 through 6 in sequence
2. Observe the HUD "SEED:" indicator

**Expected Result:**
- Key 1: "SEED: ember_moss"
- Key 2: "SEED: whisper_fern"
- Key 3: "SEED: sun_pitcher"
- Key 4: "SEED: mud_lily"
- Key 5: "SEED: thornvine"
- Key 6: "SEED: sylthene_oak"
- HUD updates immediately on key press

**Failure Looks Like:**
- HUD doesn't change when keys are pressed
- Wrong species name displayed
- Key 6 (sylthene_oak) not recognized in Pre-Bloom era (should still select but planting should be rejected)

**How to Report:** Screenshot of HUD after pressing each key + list of keys that work/don't work.

---

## Test 7: Planting

**Steps:**
1. Select a seed (press 1 for ember_moss)
2. Move the Keeper to a soil tile (dark brown, not water or stone)
3. Left-click on the soil tile
4. Observe the result

**Expected Result:**
- A seed sprite appears at the clicked tile location
- The seed is at stage 0 (seed)
- If clicking on water or stone, nothing happens
- If no seed is selected, nothing happens
- Plant appears in the current era only

**Failure Looks Like:**
- No plant appears after clicking soil
- Plant appears on water or stone (should be rejected)
- Plant appears in wrong location (offset from click)
- Error in console output

**How to Report:** Screenshot showing planted seed + description of which tiles accept/reject planting.

---

## Test 8: Watering

**Steps:**
1. Ensure WATER charges > 0 (starts at 3/3)
2. Move near a planted seed or existing plant
3. Press W key
4. Observe water charge and plant

**Expected Result:**
- Water charge decreases by 1 (e.g., 3 → 2)
- Plant's water_level increases
- If water is 0, pressing W does nothing
- Water refills to 3/3 when standing on the water spring tile (Central Glade, tile 10,9)

**Failure Looks Like:**
- Water doesn't decrease when pressing W
- Water goes below 0
- Water doesn't refill at the spring
- No visual/audio feedback

**How to Report:** Screenshot of HUD showing water counts + description of behavior.

---

## Test 9: Plant Growth

**Steps:**
1. Plant a seed (ember_moss recommended, fast growth)
2. Wait and observe the plant
3. Ember moss seed stage: ~2 days (120 seconds real time)
4. Observe stage transitions: seed → sprout → mature → bloom

**Expected Result:**
- Plant advances through growth stages over time
- Sprite changes at each stage (4 distinct sprites per species)
- Mature stage (stage 2) and bloom stage (stage 3) are visually distinct
- Growth continues even when player moves away

**Failure Looks Like:**
- Plant never advances past seed stage
- Sprite doesn't change between stages
- Plant advances too fast or too slow
- Plant disappears

**How to Report:** Screenshot of each growth stage + approximate time spent waiting.

---

## Test 10: Era Switching

**Steps:**
1. Move the Keeper to an Anchor Stone (two locations: Central Glade at tile 10,7 and Root Terrace at tile 15,4)
2. Press E key
3. Observe the transition

**Expected Result:**
- Screen cross-dissolves between era palettes (Pre-Bloom → Rooted Age or vice versa)
- Era indicator updates ("ERA: Rooted Age" or "ERA: Pre-Bloom")
- Temporal stamina decreases by 25 (e.g., 100 → 75)
- Tiles change appearance (grass_pre → grass_rooted, etc.)
- Plants in the new era are visible
- Player position is preserved

**Failure Looks Like:**
- E key does nothing at Anchor Stone
- Screen doesn't transition between eras
- Era indicator doesn't update
- Stamina doesn't decrease
- Plants from previous era incorrectly visible or missing

**How to Report:** Screenshot of both eras + HUD showing stamina before/after.

---

## Test 11: Cross-Era Persistence

**Steps:**
1. In Era 1 (Pre-Bloom), plant a thornvine at Root Terrace (near tile 14,6)
2. Wait for it to reach stage 2 (mature) or higher
3. Shift to Era 2 (Rooted Age) at the Anchor Stone
4. Observe the stone wall at Root Terrace (tile 14,4 area)
5. Shift back to Era 1
6. Observe the thornvine is still there

**Expected Result:**
- Thornvine planted in Era 1 persists when returning to Era 1
- In Era 2, the thornvine's root system should have cracked the stone wall (Root Echo)
- Plants in Era 2 are independent from Era 1 plants
- No plant data is lost when shifting

**Failure Looks Like:**
- Thornvine disappears after shifting eras
- Stone wall in Era 2 doesn't show signs of cracking
- Era 1 plants appear in Era 2 or vice versa
- Plant growth state resets on shift

**How to Report:** Screenshot of both eras showing the thornvine + description of wall state.

---

## Test 12: Root Echo (Root Lock Puzzle)

**Steps:**
1. Ensure a mature thornvine (stage 2+) exists in Era 1 at Root Terrace
2. Shift to Era 2 (Rooted Age)
3. Observe the stone barrier at Root Terrace
4. The barrier should be cracked/passable

**Expected Result:**
- Stone wall in Era 2 is visually altered (cracked by roots)
- Player can move through the previously blocked area
- Journal records the Root Echo discovery

**Failure Looks Like:**
- Stone wall unchanged in Era 2
- Area still blocked despite mature thornvine in Era 1
- No journal entry about Root Echo

**How to Report:** Screenshot of Root Terrace in both eras + description of whether the path is open.

---

## Test 13: Journal

**Steps:**
1. Press J key to open the Botanical Journal
2. Observe the journal interface
3. Plant a new species or examine an existing plant
4. Observe the journal updates
5. Press J or ESC to close

**Expected Result:**
- Journal panel opens in center of screen
- "BOTANICAL JOURNAL" title visible
- List of discovered species displayed
- Plant examination adds observations to the journal
- Journal closes when J or ESC is pressed again

**Failure Looks Like:**
- Journal doesn't open
- Journal opens but is blank
- Species not added after examination
- Journal doesn't close

**How to Report:** Screenshot of journal open + description of missing species/observations.

---

## Test 14: Save/Load

**Steps:**
1. Make some changes to the game state (plant seeds, shift eras, water plants)
2. Press ESC to open Pause menu
3. Click "SAVE"
4. Make more changes (plant different seeds, shift eras again)
5. Click "LOAD"
6. Observe the game state

**Expected Result:**
- Save button writes to `user://saves/savegame.json`
- Load button restores the saved state
- Era, player position, stamina, water, selected seed, and all plant states are restored
- Changes made after saving are undone by loading

**Failure Looks Like:**
- Save button does nothing
- Load button restores wrong state
- Plant states not preserved
- Player position wrong after load
- Save file not created

**How to Report:** Screenshot of game state before save, after changes, and after load + contents of save file if accessible.

---

## Test 15: Return to Main Menu

**Steps:**
1. In gameplay, press ESC to open Pause menu
2. Click "QUIT TO MENU"
3. Observe the transition

**Expected Result:**
- Game scene changes back to Main Menu
- "CHRONOFLORA" title displayed
- All three buttons visible
- No errors in console

**Failure Looks Like:**
- Game doesn't return to main menu
- Main menu shows errors
- Game state not properly cleared

**How to Report:** Screenshot of main menu + console output.

---

## Test Summary Table

| # | Test | Result (PASS/FAIL/NOT TESTED) | Notes |
|---|------|-------------------------------|-------|
| 1 | Project Import | | |
| 2 | Main Menu | | |
| 3 | New Game | | |
| 4 | Player Movement | | |
| 5 | Player Animations | | |
| 6 | Plant Selection | | |
| 7 | Planting | | |
| 8 | Watering | | |
| 9 | Plant Growth | | |
| 10 | Era Switching | | |
| 11 | Cross-Era Persistence | | |
| 12 | Root Echo | | |
| 13 | Journal | | |
| 14 | Save/Load | | |
| 15 | Return to Main Menu | | |

---

## How to Report Issues

For each failed test, provide:

1. **Test number and name**
2. **Expected result** (from this checklist)
3. **Actual result** (what you observed)
4. **Screenshot** (if applicable)
5. **Godot console/output tab contents** (copy-paste the error messages)
6. **Godot version** (Help → About or title bar)
7. **Operating system**

Send this information to the project lead for debugging.

---

## Notes for Testers

- **Do not** modify any project files before testing
- **Do** test in the order listed (some tests depend on earlier ones)
- **Do** take screenshots of failures
- **Do** note the exact Godot version used
- The Python/Pygame prototype in `prototype/` is a separate implementation and its test results do not apply to the Godot project