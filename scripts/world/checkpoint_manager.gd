class_name CheckpointManager
extends Area2D
## Quiet Room — the in-fiction checkpoint (GDD 12).
##
## A small stable space inside an unstable dream. Provides saving, healing,
## equipment management, skill upgrades and journal access. Some evolve as the
## story progresses, driven by recorded decisions.

signal activated(checkpoint_id: StringName)
signal rested
signal room_evolved(checkpoint_id: StringName, stage: int)

@export var checkpoint_id: StringName = &"quiet_room"
@export var room_name: String = "A Quiet Room"
@export_multiline var flavour_text: String = "The air here holds still. Whatever is dreaming, it is not looking at this corner."
@export var heal_amount: float = 1.0
@export var lantern_restore: float = 1.0

var is_active: bool = false
var evolution_stage: int = 0


func _ready() -> void:
	add_to_group("interactive")
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	activate()


func activate() -> void:
	is_active = true
	WorldManager.register_checkpoint(checkpoint_id, global_position)
	WorldManager.activate_checkpoint(checkpoint_id)
	GameManager.health = GameManager.max_health
	GameManager.health_changed.emit(GameManager.health, GameManager.max_health)
	GameManager.restore_lantern(GameManager.max_lantern * lantern_restore)
	GameManager.heal(GameManager.max_health * heal_amount)
	SaveManager.save_game(SaveManager.last_slot)
	_evolve_if_earned()
	activated.emit(checkpoint_id)
	rested.emit()
	JournalManager.discover(
		StringName("room_" + String(checkpoint_id)),
		JournalManager.Category.REGION,
		room_name,
		flavour_text
	)


## Quiet Rooms change as the world does (GDD 12).
func _evolve_if_earned() -> void:
	var stage: int = 0
	if GameManager.resolutions.size() >= 1:
		stage = 1
	if GameManager.resolutions.size() >= 3:
		stage = 2
	if stage != evolution_stage:
		evolution_stage = stage
		room_evolved.emit(checkpoint_id, stage)


func can_interact() -> bool:
	return true


func interact_with(_player: Node) -> void:
	activate()
