extends Node2D

# Chronoflora - GameManager
# Main gameplay logic following the GDD specification.
# Implements: Observe -> Tend -> Record -> Shift -> Discover -> Preserve loop.

# Signals
signal era_shifted(old_era, new_era)
signal plant_planted(species_id, tile_x, tile_y)
signal plant_watered(species_id, tile_x, tile_y)
signal plant_grown(species_id, old_stage, new_stage)
signal species_discovered(species_id)
signal journal_updated()

# Game state
var current_era = "pre_bloom"
var previous_era = null
var current_zone = "central_glade"
var player: Node2D
var era_manager: Node
var hud: Node
var journal_ui: Node

# Garden data structure:
# {era: {zone: {grid: [[tile_type]], plants: [PlantData]}}}
var garden_state = {}

# Resources
var plant_database: Dictionary = {}
var era_palettes: Dictionary = {}

# Player resources
var temporal_stamina: float = 100.0
var temporal_stamina_max: float = 100.0
var water_charges: int = 3
var water_charges_max: int = 3
var selected_seed: String = ""

# UI
var interaction_prompt: String = ""

# Tutorial
var tutorial_step: int = 0
var tutorial_timer: float = 0.0
var show_tutorial: bool = true
var tutorial_messages = [
	"Welcome to Chronoflora.",
	"Use WASD or Arrow Keys to move.",
	"Press E near an Anchor Stone to shift between eras.",
	"Press 1-6 to select a seed type, then click on soil to plant.",
	"Press W to water plants.",
	"Your actions in one era affect the other.",
	"Open the Journal with J to track discoveries.",
	"Press ESC to pause.",
]

# Constants
const TILE_SIZE = 32
const ZONE_WIDTH = 20
const ZONE_HEIGHT = 15
const ERA_PRE_BLOOM = "pre_bloom"
const ERA_ROOTED_AGE = "rooted_age"
const ZONE_CENTRAL_GLADE = "central_glade"
const ZONE_ROOT_TERRACE = "root_terrace"

const ERA_DISPLAY_NAMES = {
	ERA_PRE_BLOOM: "Pre-Bloom",
	ERA_ROOTED_AGE: "Rooted Age",
}

const SEED_SPECIES = {
	1: "ember_moss",
	2: "whisper_fern",
	3: "sun_pitcher",
	4: "mud_lily",
	5: "thornvine",
	6: "sylthene_oak",
}

# Anchor Stone positions per zone (tile coordinates)
const ANCHOR_STONES = {
	ZONE_CENTRAL_GLADE: Vector2(10, 7),
	ZONE_ROOT_TERRACE: Vector2(15, 4),
}

# Water spring position
const WATER_SPRING = Vector2(10, 9)

func _ready():
	# Initialize systems via node paths
	era_manager = get_node("EraManager")
	player = get_node("Player")
	hud = get_node("HUD")
	journal_ui = get_node("JournalUI")
	
	# Load plant database
	_load_plant_database()
	
	# Initialize garden state
	_initialize_garden_state()
	
	# Setup initial plants
	_setup_initial_garden()

func _process(delta):
	if tutorial_step < tutorial_messages.size() and show_tutorial:
		tutorial_timer += delta
		if tutorial_timer > 4.0:
			tutorial_step += 1
			tutorial_timer = 0
	
	# Regenerate temporal stamina
	if temporal_stamina < temporal_stamina_max:
		temporal_stamina += delta * 10.0
		if temporal_stamina > temporal_stamina_max:
			temporal_stamina = temporal_stamina_max
	
	# Update plants
	_update_plant_growth(delta)

func _input(event):
	if event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
	
	if event.is_action_pressed("journal_open"):
		# Toggle journal via JournalUI node
		journal_ui.call("toggle")
	
	if event.is_action_pressed("era_shift"):
		_try_shift_era()
	
	if event.is_action_pressed("water_plant"):
		_water_plant_at_player()
	
	# Seed selection
	for i in range(1, 7):
		if event.is_action_pressed(f"seed_{i}"):
			selected_seed = SEED_SPECIES.get(i, "")
	
	if event.is_action_pressed("mouse_left"):
		_handle_mouse_click(event.position)

func _load_plant_database():
	"""Load plant species definitions (data-driven)."""
	plant_database = {
		"ember_moss": {
			"name": "Ember Moss",
			"eras": [ERA_PRE_BLOOM, ERA_ROOTED_AGE],
			"growth_time": [2.0, 5.0, 8.0, 12.0],
			"water_need": 1,
			"special": "bioluminescent",
		},
		"whisper_fern": {
			"name": "Whisper Fern",
			"eras": [ERA_PRE_BLOOM],
			"growth_time": [3.0, 6.0, 10.0, 15.0],
			"water_need": 2,
			"special": "sound_dampening",
		},
		"sun_pitcher": {
			"name": "Sun-pitcher",
			"eras": [ERA_PRE_BLOOM, ERA_ROOTED_AGE],
			"growth_time": [2.0, 4.0, 7.0, 10.0],
			"water_need": 3,
			"special": "carnivorous",
		},
		"mud_lily": {
			"name": "Mud-lily",
			"eras": [ERA_PRE_BLOOM, ERA_ROOTED_AGE],
			"growth_time": [2.0, 4.0, 6.0, 9.0],
			"water_need": 4,
			"special": "aquatic",
		},
		"thornvine": {
			"name": "Thornvine",
			"eras": [ERA_PRE_BLOOM, ERA_ROOTED_AGE],
			"growth_time": [1.0, 3.0, 6.0, 10.0],
			"water_need": 1,
			"special": "invasive",
		},
		"sylthene_oak": {
			"name": "Sylthene Oak",
			"eras": [ERA_ROOTED_AGE],
			"growth_time": [5.0, 10.0, 20.0, 30.0],
			"water_need": 2,
			"special": "memory_tree_host",
		},
	}

	era_palettes = {
		ERA_PRE_BLOOM: {
			"sky": Color(0.13, 0.18, 0.20),
			"grass": Color(0.18, 0.35, 0.24),
			"ui_bg": Color(0.12, 0.12, 0.14),
			"ui_fg": Color(0.86, 0.86, 0.86),
			"ui_accent": Color(0.39, 0.86, 0.78),
		},
		ERA_ROOTED_AGE: {
			"sky": Color(1.0, 0.71, 0.39),
			"grass": Color(0.47, 0.71, 0.24),
			"ui_bg": Color(0.20, 0.16, 0.12),
			"ui_fg": Color(0.94, 0.86, 0.71),
			"ui_accent": Color(1.0, 0.78, 0.31),
		},
	}

func _initialize_garden_state():
	"""Create empty garden state for all eras and zones."""
	garden_state = {}
	for era in [ERA_PRE_BLOOM, ERA_ROOTED_AGE]:
		garden_state[era] = {}
		for zone in [ZONE_CENTRAL_GLADE, ZONE_ROOT_TERRACE]:
			garden_state[era][zone] = {
				"grid": _generate_zone_grid(era, zone),
				"plants": [],
			}

func _generate_zone_grid(era, zone):
	"""Generate base tile grid for a zone in an era."""
	var grid = []
	var is_pre_bloom = era == ERA_PRE_BLOOM
	
	for y in range(ZONE_HEIGHT):
		var row = []
		for x in range(ZONE_WIDTH):
			var tile = "grass_pre" if is_pre_bloom else "grass_rooted"
			
			if zone == ZONE_CENTRAL_GLADE:
				if is_pre_bloom:
					if (x + y) % 7 == 0 and x > 2 and x < 17:
						tile = "water_pre"
					else:
						tile = "grass_pre"
				else:
					if x < 3 or x > 16 or y < 2 or y > 12:
						tile = "stone_pre"
					else:
						tile = "soil_pre"
			elif zone == ZONE_ROOT_TERRACE:
				if is_pre_bloom:
					if y > 10:
						tile = "water_pre"
					elif (x + y) % 5 == 0:
						tile = "stone_pre"
					else:
						tile = "grass_pre"
				else:
					if x > 12 and y < 6:
						tile = "stone_pre"  # Root Lock wall
					elif x < 2 or x > 17 or y < 1 or y > 13:
						tile = "stone_pre"
					else:
						tile = "soil_pre"
			row.append(tile)
		grid.append(row)
	
	return grid

func _setup_initial_garden():
	"""Place initial plants in the garden."""
	# Era 1: Pre-Bloom - Central Glade
	_add_plant(ERA_PRE_BLOOM, ZONE_CENTRAL_GLADE, "ember_moss", 4, 6, 2)
	_add_plant(ERA_PRE_BLOOM, ZONE_CENTRAL_GLADE, "whisper_fern", 6, 8, 1)
	_add_plant(ERA_PRE_BLOOM, ZONE_CENTRAL_GLADE, "mud_lily", 12, 6, 3)
	
	# Era 1: Pre-Bloom - Root Terrace
	_add_plant(ERA_PRE_BLOOM, ZONE_ROOT_TERRACE, "thornvine", 14, 6, 2)
	
	# Era 2: Rooted Age - Central Glade
	_add_plant(ERA_ROOTED_AGE, ZONE_CENTRAL_GLADE, "sylthene_oak", 5, 5, 3)
	_add_plant(ERA_ROOTED_AGE, ZONE_CENTRAL_GLADE, "sun_pitcher", 7, 7, 2)
	
	# Era 2: Rooted Age - Root Terrace
	_add_plant(ERA_ROOTED_AGE, ZONE_ROOT_TERRACE, "sylthene_oak", 13, 3, 3)
	
	# Water spring
	_add_plant(ERA_PRE_BLOOM, ZONE_CENTRAL_GLADE, "mud_lily", 10, 9, 3)
	_add_plant(ERA_ROOTED_AGE, ZONE_CENTRAL_GLADE, "mud_lily", 10, 9, 3)

func _add_plant(era, zone, species_id, tx, ty, stage):
	"""Add plant instance to garden state."""
	var plant = {
		"species_id": species_id,
		"tx": tx,
		"ty": ty,
		"stage": stage,
		"growth_points": 0.0,
		"water_level": 0,
	}
	garden_state[era][zone]["plants"].append(plant)

func _update_plant_growth(delta):
	"""Update all plants in current era/zone."""
	var plants = garden_state[current_era][current_zone]["plants"]
	for plant in plants:
		if plant["stage"] >= 3:
			continue
		
		plant["growth_points"] += delta * 1.0
		var species = plant_database.get(plant["species_id"], {})
		var growth_time = species.get("growth_time", [1,1,1,1])[plant["stage"]]
		var required_seconds = growth_time * 60.0
		
		if plant["growth_points"] >= required_seconds:
			plant["stage"] += 1
			plant["growth_points"] = 0.0
			plant_grown.emit(plant["species_id"], plant["stage"] - 1, plant["stage"])

func _world_to_tile(world_pos):
	"""Convert world position to tile coordinates."""
	var cam = get_node("Camera2D")
	var screen_size = get_viewport().size
	var tx = int((world_pos.x + cam.position.x - screen_size.x / 2) / TILE_SIZE)
	var ty = int((world_pos.y + cam.position.y - screen_size.y / 2) / TILE_SIZE)
	return Vector2(tx, ty)

func _get_tile_at(world_x, world_y):
	"""Get tile type at world coordinates."""
	var cam = get_node("Camera2D")
	var tx = int((world_x + cam.position.x - get_viewport().size.x / 2) / TILE_SIZE)
	var ty = int((world_y + cam.position.y - get_viewport().size.y / 2) / TILE_SIZE)
	
	if tx >= 0 and tx < ZONE_WIDTH and ty >= 0 and ty < ZONE_HEIGHT:
		return garden_state[current_era][current_zone]["grid"][ty][tx]
	return null

func _get_plant_at(tx, ty):
	"""Get plant at tile coordinates."""
	var plants = garden_state[current_era][current_zone]["plants"]
	for plant in plants:
		if plant["tx"] == tx and plant["ty"] == ty:
			return plant
	return null

func _try_shift_era():
	"""Shift between eras at an Anchor Stone."""
	if temporal_stamina < 25:
		return
	
	# Check if player is near Anchor Stone
	var player_tile = _world_to_tile(player.position)
	var anchor_pos = ANCHOR_STONES.get(current_zone, Vector2(-1, -1))
	
	if anchor_pos.distance_to(player_tile) <= 1.5:
		previous_era = current_era
		era_manager.call("shift_era")
		current_era = era_manager.call("get_current_era")
		temporal_stamina -= 25
		era_shifted.emit(previous_era, current_era)
		_apply_cross_era_consequences()

func _apply_cross_era_consequences():
	"""Apply Root Echoes and Seed Drift when shifting eras."""
	var source = previous_era
	var target = current_era
	var zone = current_zone
	
	if source == ERA_PRE_BLOOM and target == ERA_ROOTED_AGE:
		# Root Echo: Thornvine grown in Era 1 cracks stone in Era 2
		var plants = garden_state[source][zone]["plants"]
		var has_mature_thornvine = false
		for plant in plants:
			if plant["species_id"] == "thornvine" and plant["stage"] >= 2:
				has_mature_thornvine = true
				break
		
		if has_mature_thornvine and zone == ZONE_ROOT_TERRACE:
			print("Root Echo: Stone barrier cracked by roots from Pre-Bloom era.")
	
	# Seed Drift
	if source == ERA_PRE_BLOOM and target == ERA_ROOTED_AGE:
		var random = RandomNumberGenerator.new()
		for plant in garden_state[source][zone]["plants"]:
			if plant["stage"] >= 3 and random.randf() < 0.3:
				var tx = plant["tx"]
				var ty = plant["ty"]
				var tile = garden_state[target][zone]["grid"][ty][tx]
				if tile == "soil_rooted":
					var exists = false
					for p in garden_state[target][zone]["plants"]:
						if p["tx"] == tx and p["ty"] == ty:
							exists = true
							break
					if not exists:
						garden_state[target][zone]["plants"].append({
							"species_id": plant["species_id"],
							"tx": tx,
							"ty": ty,
							"stage": 0,
							"growth_points": 0.0,
							"water_level": 0,
						})

func _plant_seed(world_x, world_y):
	"""Plant a seed at world coordinates."""
	if not selected_seed:
		return
	
	var tile = _get_tile_at(world_x, world_y)
	if tile != "soil_pre" and tile != "soil_rooted":
		return
	
	var tile_x = int(world_x / TILE_SIZE)
	var tile_y = int(world_y / TILE_SIZE)
	var plant = _get_plant_at(tile_x, tile_y)
	if plant:
		return
	
	var species = plant_database.get(selected_seed, {})
	if current_era not in species.get("eras", []):
		return
	
	_add_plant(current_era, current_zone, selected_seed,
		tile_x, tile_y, 0)
	plant_planted.emit(selected_seed, tile_x, tile_y)

func _water_plant_at_player():
	"""Water plant near player."""
	if water_charges <= 0:
		return
	
	var player_tile = _world_to_tile(player.position)
	var plants = garden_state[current_era][current_zone]["plants"]
	var closest = null
	var closest_dist = 1e9
	
	for plant in plants:
		var dist = abs(plant["tx"] - player_tile.x) + abs(plant["ty"] - player_tile.y)
		if dist <= 2 and dist < closest_dist:
			closest_dist = dist
			closest = plant
	
	if closest:
		closest["water_level"] = min(closest["water_level"] + 1, 3)
		water_charges -= 1
		plant_watered.emit(closest["species_id"], closest["tx"], closest["ty"])

func _handle_mouse_click(pos):
	"""Handle mouse click in game world."""
	var cam = get_node("Camera2D")
	var screen_size = get_viewport().size
	var world_x = pos.x + cam.position.x - screen_size.x / 2
	var world_y = pos.y + cam.position.y - screen_size.y / 2
	
	var tile_x = int(world_x / TILE_SIZE)
	var tile_y = int(world_y / TILE_SIZE)
	
	# Check plant
	var plant = _get_plant_at(tile_x, tile_y)
	if plant:
		# Examine - record discovery
		journal_ui.call("discover_species", plant["species_id"])
		return
	
	# Check Anchor Stone
	var anchor_pos = ANCHOR_STONES.get(current_zone, Vector2(-1, -1))
	if Vector2(tile_x, tile_y) == anchor_pos:
		_try_shift_era()
		return
	
	# Check water spring
	if Vector2(tile_x, tile_y) == WATER_SPRING:
		water_charges = water_charges_max
		return
	
	# Plant seed
	if selected_seed:
		_plant_seed(world_x, world_y)

func get_state_for_save():
	"""Get serializable state."""
	return {
		"era": current_era,
		"zone": current_zone,
		"player_x": player.position.x,
		"player_y": player.position.y,
		"stamina": temporal_stamina,
		"water": water_charges,
		"seed": selected_seed,
		"garden": garden_state,
	}

func load_state_from_save(state):
	"""Load state from save data."""
	current_era = state.get("era", ERA_PRE_BLOOM)
	current_zone = state.get("zone", ZONE_CENTRAL_GLADE)
	player.position = Vector2(state.get("player_x", 160), state.get("player_y", 240))
	temporal_stamina = state.get("stamina", 100.0)
	water_charges = state.get("water", 3)
	selected_seed = state.get("seed", "")
	# Re-initialize garden state (grids are regenerated)
	_initialize_garden_state()
	# Load saved plant instances
	var saved_garden = state.get("garden", {})
	for era in [ERA_PRE_BLOOM, ERA_ROOTED_AGE]:
		for zone in [ZONE_CENTRAL_GLADE, ZONE_ROOT_TERRACE]:
			var plants_data = saved_garden.get(era, {}).get(zone, {}).get("plants", [])
			for pdata in plants_data:
				garden_state[era][zone]["plants"].append({
					"species_id": pdata.get("species_id", ""),
					"tx": pdata.get("tx", 0),
					"ty": pdata.get("ty", 0),
					"stage": pdata.get("stage", 0),
					"growth_points": pdata.get("growth_points", 0.0),
					"water_level": pdata.get("water_level", 0),
				})
