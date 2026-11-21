class_name Hitbox
extends Area2D
## Hitbox — deals damage to overlapping Hurtboxes (GDD 21: Combat layer).
##
## Attacks enable a hitbox for a window of frames rather than instant-hitting,
## so telegraphs, startup and recovery stay readable (GDD 19).

signal hit_landed(hurtbox: Hurtbox)

enum Kind { LIGHT, HEAVY, AERIAL, CHARGED, COUNTER, ENEMY, HAZARD }

@export var damage: float = 10.0
@export var kind: Kind = Kind.LIGHT
@export var knockback: Vector2 = Vector2(180.0, -40.0)
@export var stagger_power: float = 6.0
## Set true for attacks the player is allowed to counter (GDD 5).
@export var counterable: bool = false
@export var resonance_on_hit: float = 0.0
## NodePath to the combatant that owns this hitbox; used for attribution.
@export var owner_path: NodePath

var is_active: bool = false


func _ready() -> void:
	monitoring = false
	monitorable = true
	if owner_path.is_empty():
		owner_path = get_parent().get_path()


func source() -> Node:
	return get_node_or_null(owner_path)


func activate() -> void:
	is_active = true
	monitoring = true


func deactivate() -> void:
	is_active = false
	monitoring = false


func overlapping_hurtboxes() -> Array[Hurtbox]:
	var found: Array[Hurtbox] = []
	for area: Area2D in get_overlapping_areas():
		if area is Hurtbox and area.can_be_hit():
			found.append(area)
	return found
