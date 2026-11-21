class_name Hurtbox
extends Area2D
## Hurtbox — receives damage (GDD 21: Combat layer).
##
## Deliberately thin: it detects, DamageSystem decides. That keeps damage
## rules (revealed multipliers, armour, counters) in one place.

signal hit_taken(result: Dictionary)
signal became_invulnerable(duration: float)
signal invulnerability_ended

@export var owner_path: NodePath

var invulnerable: bool = false
var invulnerability_timer: float = 0.0
## Armour absorbs stagger but not damage (used by Wardens, GDD 7).
var armour: float = 0.0
## Multiplier applied to incoming damage, driven by the Revealed state.
var damage_taken_multiplier: float = 1.0


func _ready() -> void:
	monitoring = true
	monitorable = true
	area_entered.connect(_on_area_entered)
	if owner_path.is_empty():
		owner_path = get_parent().get_path()


func _process(delta: float) -> void:
	if not invulnerable:
		return
	invulnerability_timer -= delta
	if invulnerability_timer <= 0.0:
		invulnerable = false
		invulnerability_ended.emit()


func owner_node() -> Node:
	return get_node_or_null(owner_path)


func can_be_hit() -> bool:
	return not invulnerable


func grant_invulnerability(duration: float) -> void:
	if duration <= 0.0:
		return
	invulnerable = true
	invulnerability_timer = maxf(invulnerability_timer, duration)
	became_invulnerable.emit(duration)


func _on_area_entered(area: Area2D) -> void:
	if not area is Hitbox:
		return
	var hitbox := area as Hitbox
	if not hitbox.is_active:
		return
	var target: Node = owner_node()
	if target == null:
		return
	# Never let a combatant hit itself.
	if hitbox.source() == target:
		return
	var result: Dictionary = DamageSystem.apply(self, hitbox)
	hit_taken.emit(result)
