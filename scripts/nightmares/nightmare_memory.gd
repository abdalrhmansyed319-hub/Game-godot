class_name NightmareMemory
extends Area2D
## NightmareMemory — a memory fragment in the world (GDD 2, 4B, 17).
##
## Discovering these is how a hunt turns from "kill the thing" into
## understanding what it is. They are invisible until the Lantern finds them,
## and each one writes into the Hunter's Journal.

signal discovered(memory_id: StringName)

@export var memory_id: StringName = &""
@export var nightmare_id: StringName = &""
@export var title: String = "A memory"
@export_multiline var memory_text: String = ""
## Clue key this memory contributes to the nightmare's understanding.
@export var grants_clue: StringName = &""
@export var requires_lantern: bool = true

var is_revealed: bool = false
var is_collected: bool = false
var _visual: ColorRect = null


func _ready() -> void:
	add_to_group("interactive")
	body_entered.connect(_on_body_entered)
	_build_visual()


func _build_visual() -> void:
	_visual = ColorRect.new()
	_visual.color = Color(0.95, 0.9, 0.7, 0.0 if requires_lantern else 0.8)
	_visual.size = Vector2(10, 14)
	_visual.position = Vector2(-5, -18)
	add_child(_visual)


func set_revealed(value: bool, _duration: float) -> void:
	is_revealed = value
	if _visual != null:
		_visual.color.a = 0.9 if value else (0.0 if requires_lantern else 0.8)


func can_interact() -> bool:
	return not is_collected and (is_revealed or not requires_lantern)


func _on_body_entered(body: Node2D) -> void:
	if is_collected or not body.is_in_group("player"):
		return
	if requires_lantern and not is_revealed:
		return
	collect()


func interact_with(_player: Node) -> void:
	if can_interact():
		collect()


func collect() -> void:
	is_collected = true
	AudioManager.play_named(&"clue")
	if grants_clue != &"":
		GameManager.discover_clue(grants_clue, nightmare_id)
	JournalManager.discover(
		StringName("memory_" + String(memory_id)),
		JournalManager.Category.MEMORY,
		title,
		memory_text
	)
	discovered.emit(memory_id)
	if _visual != null:
		_visual.color.a = 0.25
