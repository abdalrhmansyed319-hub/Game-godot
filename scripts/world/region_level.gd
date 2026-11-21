extends Node2D
## RegionLevel — the prototype exploration area (GDD 22: Prototype).
##
## One small region containing: platforming, three nightmare encounters from
## data, a Quiet Room checkpoint, memory fragments, hidden structures and a
## boss arena trigger. Geometry is generated from primitives so the prototype
## runs with zero art assets; swap `_build_platform` for TileMapLayers when
## 02 - Art & Assets delivers tilesets.

const NIGHTMARE_SCENE: PackedScene = preload("res://scenes/entities/nightmare.tscn")

@export var region_id: StringName = &"hollow_village"
@export var region_title: String = "The Hollow Village"

@onready var player: PlayerController = $Player
@onready var camera: Camera2D = $Player/Camera2D
@onready var distortion: DreamDistortion = $DreamDistortion
@onready var hud: CanvasLayer = $HUD
@onready var platforms_root: Node2D = $Platforms
@onready var entities_root: Node2D = $Entities

## Nightmare ids placed in this region, in encounter order.
@export var region_nightmares: Array[StringName] = [
	&"hollow_choir",
	&"borrowed_face",
	&"bell_without_a_tongue",
]

var spawned: Array[NightmareBase] = []


func _ready() -> void:
	WorldManager.enter_region(region_id)
	GameManager.reset_run_state()
	_build_geometry()
	_spawn_content()
	_build_parallax()
	hud.bind_player(player)
	GameManager.player_died.connect(_on_player_died)
	GameManager.nightmare_resolved.connect(_on_nightmare_resolved)
	# The prototype hunt starts immediately: the village asked about the bell.
	QuestManager.start(&"hunt_bell")


func _on_player_died() -> void:
	hud.show_message("You wake at the last Quiet Room. The dream remembers what you learned.")


func _on_nightmare_resolved(nightmare_id: StringName, resolution: int) -> void:
	var data: NightmareData = NightmareDatabase.nightmare(nightmare_id)
	if data == null:
		return
	hud.show_message("%s — %s" % [data.display_name, data.resolution_label(resolution)])
	QuestManager.complete_objective_by_text(&"hunt_bell", "Decide the Bell's fate")


# --- Geometry ---------------------------------------------------------------
func _build_geometry() -> void:
	# Ground, with a gap the player must jump or dash across.
	_add_platform(Vector2(0, 0), Vector2(1400, 40))
	_add_platform(Vector2(1520, 0), Vector2(900, 40))
	_add_platform(Vector2(2500, 0), Vector2(1600, 40))
	# Stepped climb toward the bell.
	_add_platform(Vector2(520, -110), Vector2(180, 24))
	_add_platform(Vector2(780, -210), Vector2(180, 24))
	_add_platform(Vector2(1040, -320), Vector2(220, 24))
	# A wall to wall-jump.
	_add_platform(Vector2(1900, -140), Vector2(40, 280))
	# Boss arena floor, raised and enclosed.
	_add_platform(Vector2(3450, -60), Vector2(700, 40))
	_add_platform(Vector2(3120, -220), Vector2(40, 320))
	_add_platform(Vector2(3780, -220), Vector2(40, 320))


func _add_platform(center: Vector2, size: Vector2) -> Node2D:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = center

	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = size
	shape.shape = rectangle
	body.add_child(shape)

	var visual := ColorRect.new()
	visual.color = Color(0.13, 0.12, 0.2)
	visual.size = size
	visual.position = -size * 0.5
	body.add_child(visual)

	platforms_root.add_child(body)
	return body


func _build_parallax() -> void:
	# Layered backgrounds give the dream depth (GDD 13).
	var far := Parallax2D.new()
	far.scroll_scale = Vector2(0.2, 0.2)
	var far_rect := ColorRect.new()
	far_rect.color = Color(0.07, 0.06, 0.13)
	far_rect.size = Vector2(2400, 1200)
	far_rect.position = Vector2(-600, -900)
	far.add_child(far_rect)
	add_child(far)

	var near := Parallax2D.new()
	near.scroll_scale = Vector2(0.55, 0.55)
	for i: int in range(9):
		var spire := ColorRect.new()
		spire.color = Color(0.11, 0.1, 0.19)
		spire.size = Vector2(60, 260 + float(i % 3) * 90.0)
		spire.position = Vector2(-200 + i * 460, -200 - spire.size.y)
		near.add_child(spire)
	add_child(near)


# --- Content ----------------------------------------------------------------
func _spawn_content() -> void:
	_spawn_nightmare(region_nightmares[0], Vector2(820, -260))
	_spawn_nightmare(region_nightmares[1], Vector2(1720, -40))
	_spawn_nightmare(region_nightmares[2], Vector2(3450, -120))
	_spawn_quiet_room(Vector2(120, -30))
	_spawn_memory(
		Vector2(1080, -370),
		&"choir_verse",
		&"hollow_choir",
		"The last verse",
		"A page nailed to a beam, the ink still wet after eleven years: 'and we will not be forgotten, and neither will you.'",
		&"choir_missing_verse"
	)
	_spawn_memory(
		Vector2(3300, -120),
		&"bell_clapper",
		&"bell_without_a_tongue",
		"The removed clapper",
		"Half buried in the cellar floor, dragged here by someone in a hurry. The village did not lose the bell's tongue. They took it.",
		&"bell_clapper_found"
	)
	_spawn_mechanism(
		Vector2(2260, -30),
		InteractiveObject.Kind.BREAKABLE,
		"Strike the rotted boards",
		&"cellar_opened",
		&"bell_without_a_tongue",
		"Boards over a cellar stair. Nailed from the outside, which is not how you close a cellar."
	)
	_spawn_mechanism(
		Vector2(3360, -100),
		InteractiveObject.Kind.HIDDEN_PASSAGE,
		"Press the silent plate",
		&"shrine_plate",
		&"borrowed_face",
		"A stone plate with a name worn smooth. Someone pressed this often enough to erase it."
	)


func _spawn_nightmare(id: StringName, at: Vector2) -> void:
	if NIGHTMARE_SCENE == null:
		return
	var instance: Node = NIGHTMARE_SCENE.instantiate()
	if not instance is NightmareBase:
		return
	var nightmare := instance as NightmareBase
	nightmare.nightmare_id = id
	nightmare.data = NightmareDatabase.nightmare(id)
	nightmare.position = at
	entities_root.add_child(nightmare)
	spawned.append(nightmare)


func _spawn_quiet_room(at: Vector2) -> void:
	var room := Area2D.new()
	var script := load("res://scripts/world/checkpoint_manager.gd")
	room.set_script(script)
	room.position = at
	room.checkpoint_id = &"hollow_village_1"
	room.room_name = "The Lamplit Doorway"
	room.flavour_text = "A doorway with no house behind it. Someone keeps a lamp here anyway."

	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(70, 70)
	shape.shape = rectangle
	room.add_child(shape)

	var visual := ColorRect.new()
	visual.color = Color(0.95, 0.82, 0.42, 0.35)
	visual.size = Vector2(46, 60)
	visual.position = Vector2(-23, -60)
	room.add_child(visual)

	entities_root.add_child(room)


func _spawn_memory(
	at: Vector2,
	id: StringName,
	owner_id: StringName,
	title: String,
	text: String,
	clue: StringName
) -> void:
	var memory := Area2D.new()
	memory.set_script(load("res://scripts/nightmares/nightmare_memory.gd"))
	memory.position = at
	memory.memory_id = id
	memory.nightmare_id = owner_id
	memory.title = title
	memory.memory_text = text
	memory.grants_clue = clue

	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(30, 40)
	shape.shape = rectangle
	memory.add_child(shape)

	entities_root.add_child(memory)


func _spawn_mechanism(
	at: Vector2,
	kind: int,
	prompt: String,
	clue: StringName,
	owner_id: StringName,
	text: String
) -> void:
	var object := StaticBody2D.new()
	object.set_script(load("res://scripts/world/interactive_object.gd"))
	object.position = at
	object.kind = kind as InteractiveObject.Kind
	object.prompt = prompt
	object.grants_clue = clue
	object.nightmare_id = owner_id
	object.examine_text = text
	object.is_hidden = kind == InteractiveObject.Kind.HIDDEN_PASSAGE

	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(28, 40)
	shape.shape = rectangle
	object.add_child(shape)

	entities_root.add_child(object)
	distortion.register_platform(object)
