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
## The page is drawn by PropVisual, which whoever spawns this adds as a child.
var _visual: PropVisual = null


func _ready() -> void:
	add_to_group("interactive")
	body_entered.connect(_on_body_entered)
	for child: Node in get_children():
		if child is PropVisual:
			_visual = child
			break
	# Lantern-gated memories stay unseen until something reveals them.
	if _visual != null:
		_visual.visible = not requires_lantern
		_visual.revealed = not requires_lantern


func set_revealed(value: bool, _duration: float) -> void:
	is_revealed = value
	if _visual != null:
		_visual.visible = value or not requires_lantern
		_visual.set_revealed(value or not requires_lantern)
	if value:
		Fx.reveal_ring(self, global_position + Vector2(0, -24.0))
		AudioManager.play_named(&"nightmare_revealed")


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
	Fx.burst(self, global_position + Vector2(0, -24.0), Palette.TRUTH, 12)
	if _visual != null:
		# The page stays where it fell. You already have the words.
		_visual.modulate = Color(1, 1, 1, 0.3)
