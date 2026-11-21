extends CanvasLayer

# Chronoflora - HUD
# Displays era, stamina, water, and selected seed using Label nodes.

var game_manager: Node

const ERA_DISPLAY_NAMES = {
	"pre_bloom": "Pre-Bloom",
	"rooted_age": "Rooted Age",
}

var era_label: Label
var stamina_label: Label
var water_label: Label
var seed_label: Label
var controls_label: Label

func _ready():
	game_manager = get_node("/root/Main/Game")
	
	# Create HUD labels (use default theme font)
	era_label = Label.new()
	era_label.position = Vector2(30, 30)
	add_child(era_label)
	
	stamina_label = Label.new()
	stamina_label.position = Vector2(30, 55)
	add_child(stamina_label)
	
	water_label = Label.new()
	water_label.position = Vector2(30, 80)
	add_child(water_label)
	
	seed_label = Label.new()
	seed_label.position = Vector2(30, 105)
	add_child(seed_label)
	
	controls_label = Label.new()
	controls_label.position = Vector2(20, get_viewport().size.y - 25)
	add_child(controls_label)

func _process(delta):
	if not game_manager:
		return
	
	var era_name = ERA_DISPLAY_NAMES.get(game_manager.current_era, "Unknown")
	era_label.text = "ERA: " + era_name
	
	stamina_label.text = "STAMINA: " + str(int(game_manager.temporal_stamina)) + "/" + str(int(game_manager.temporal_stamina_max))
	
	water_label.text = "WATER: " + str(game_manager.water_charges) + "/" + str(game_manager.water_charges_max)
	
	var seed_text = "SEED: " + (game_manager.selected_seed if game_manager.selected_seed else "None")
	seed_label.text = seed_text
	
	controls_label.text = "1-6: Seed | W: Water | E: Shift | J: Journal | ESC: Pause"
