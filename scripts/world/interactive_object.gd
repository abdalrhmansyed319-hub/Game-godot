class_name InteractiveObject
extends StaticBody2D
## InteractiveObject — dream mechanisms, movable structures, breakable walls
## and hidden passages (GDD 3, 13).
##
## Everything here is observable rather than random: secrets reward noticing.

signal interacted(player: Node)
signal resonated
signal stabilised(duration: float)
signal broken_open

enum Kind { MECHANISM, MOVABLE, BREAKABLE, HIDDEN_PASSAGE, MEMORY_SHRINE }

@export var kind: Kind = Kind.MECHANISM
@export var prompt: String = "Examine"
@export var requires_lantern: bool = false
@export var requires_echo: StringName = &""
@export var grants_clue: StringName = &""
@export var nightmare_id: StringName = &""
@export_multiline var examine_text: String = ""
@export var is_hidden: bool = false
@export var opens_passage_to: String = ""

var is_revealed: bool = false
var is_stabilised_flag: bool = false
var is_broken: bool = false
## Drawn by PropVisual, added by whoever spawns this object. Kept as a lookup
## so reveal and break states can drive the drawing instead of a second node.
var _visual: PropVisual = null


func _ready() -> void:
	add_to_group("interactive")
	_visual = _find_prop_visual()


## PropVisual is a sibling in the scene tree rather than something this script
## creates, so the spawner decides what the object looks like.
func _find_prop_visual() -> PropVisual:
	for child: Node in get_children():
		if child is PropVisual:
			return child
	return null


func can_interact() -> bool:
	if is_broken:
		return false
	if is_hidden and not is_revealed:
		return false
	if requires_lantern and not is_revealed:
		return false
	return true


func interact_with(player: Node) -> void:
	match kind:
		Kind.BREAKABLE:
			is_broken = true
			if _visual != null:
				# The boards come apart: dust first, then they are gone.
				Fx.dust(self, global_position + Vector2(0, -20.0), 14)
				FeedbackManager.shake(3.4, 0.16)
				AudioManager.play_named(&"heavy_impact")
				_visual.visible = false
			broken_open.emit()
		Kind.HIDDEN_PASSAGE:
			is_broken = true
			if opens_passage_to != "":
				WorldManager.request_level(opens_passage_to)
		_:
			pass
	if grants_clue != &"":
		GameManager.discover_clue(grants_clue, nightmare_id)
		AudioManager.play_named(&"clue")
	if examine_text != "":
		JournalManager.discover(
			StringName("examined_" + name.to_lower()),
			JournalManager.Category.OBSERVATION,
			String(name),
			examine_text
		)
	interacted.emit(player)


## The Echo of the Hollow Voice makes hidden structures ring out (GDD 10).
func resonate() -> void:
	if is_hidden:
		_reveal(true)
		Fx.reveal_ring(self, global_position + Vector2(0, -24.0))
	resonated.emit()


## Revealed by the Dream Lantern (GDD 4B).
func set_revealed(value: bool, _duration: float) -> void:
	if is_hidden and value and not is_revealed:
		_reveal(true)
		Fx.reveal_ring(self, global_position + Vector2(0, -24.0))
	elif not is_hidden:
		is_revealed = value


func _reveal(value: bool) -> void:
	is_revealed = value
	if _visual != null:
		_visual.set_revealed(value)


## Held still by the Anchor of Wakefulness (GDD 4C, 14).
func stabilise(duration: float) -> void:
	is_stabilised_flag = true
	stabilised.emit(duration)
	get_tree().create_timer(duration).timeout.connect(func() -> void: is_stabilised_flag = false)


func is_stabilised() -> bool:
	return is_stabilised_flag
