extends CanvasLayer

# Chronoflora - Botanical Journal
# Tracks discovered species and observations using Label nodes.

var discovered_species = []
var observations = []
var visible = false

var panel_rect: Rect2
var title_label: Label
var species_list_label: Label
var close_label: Label

func _ready():
	hide()

func toggle():
	visible = not visible
	if visible:
		show()
	else:
		hide()

func discover_species(species_id: String):
	if species_id not in discovered_species:
		discovered_species.append(species_id)

func add_observation(species_id: String, text: String):
	observations.append({"species": species_id, "text": text})

func _draw():
	if not visible:
		return
	
	var center_x = get_viewport().size.x / 2
	var center_y = get_viewport().size.y / 2
	
	panel_rect = Rect2(center_x - 350, center_y - 250, 700, 500)
	draw_rect(panel_rect, Color(0.16, 0.14, 0.18, 0.9))

func _input(event):
	if event.is_action_pressed("journal_open") and visible:
		toggle()
