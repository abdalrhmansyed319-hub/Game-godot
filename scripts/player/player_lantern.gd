class_name PlayerLantern
extends Node
## The Dream Lantern — GDD section 4B.
##
## Reveals hidden structure and exposes nightmare weaknesses. It is NOT a
## permanent answer: every use costs Lantern charge, so timing it inside a
## fight is a decision, not a habit.

signal revealed(targets: Array[Node])
signal weak_point_exposed(nightmare: Node)
signal memory_illuminated(memory_id: StringName)
signal ability_interrupted(nightmare: Node)
signal charge_insufficient

const BASE_COST: float = 22.0
const BASE_RADIUS: float = 220.0
const REVEAL_HOLD: float = 3.0

@export var resonance: ResonanceSystem

var is_revealing: bool = false
var reveal_timer: float = 0.0


func _process(delta: float) -> void:
	if not is_revealing:
		return
	reveal_timer -= delta
	if reveal_timer <= 0.0:
		is_revealing = false


func cost() -> float:
	var skill_reduction: float = ProgressionManager.effect_total(&"lantern_cost")
	return maxf(4.0, BASE_COST * (1.0 + skill_reduction) * ProgressionManager.lantern_cost_multiplier())


func radius() -> float:
	return BASE_RADIUS * maxf(0.5, ProgressionManager.effect_total(&"lantern_radius") + 0.65)


func can_use() -> bool:
	return GameManager.lantern_charge >= cost()


## Fires the reveal from `origin`. Returns the nodes it exposed.
func reveal_from(origin: Vector2, candidates: Array[Node]) -> Array[Node]:
	if not can_use():
		charge_insufficient.emit()
		return []
	GameManager.spend_lantern(cost())
	is_revealing = true
	reveal_timer = REVEAL_HOLD
	AudioManager.play_named(&"lantern")

	var exposed: Array[Node] = []
	var reveal_radius: float = radius()
	for candidate: Node in candidates:
		if candidate == null or not is_instance_valid(candidate):
			continue
		if not candidate is Node2D:
			continue
		var node := candidate as Node2D
		if origin.distance_to(node.global_position) > reveal_radius:
			continue
		exposed.append(node)
		_expose(node)

	revealed.emit(exposed)
	if resonance != null and not exposed.is_empty():
		resonance.register_lantern_reveal()
	return exposed


func _expose(node: Node) -> void:
	# Invisible enemies become visible.
	if node.has_method("set_revealed"):
		node.set_revealed(true, REVEAL_HOLD)
	# Nightmares expose their true vulnerability while lit.
	if node.has_method("expose_weak_point"):
		node.expose_weak_point()
		weak_point_exposed.emit(node)
	# Certain telegraphed abilities are interrupted by being seen.
	if node.has_method("interrupt_current_ability"):
		if node.interrupt_current_ability():
			ability_interrupted.emit(node)


## Reveals an environmental memory fragment (GDD 2, 4B).
func illuminate_memory(memory_id: StringName) -> void:
	if not can_use():
		charge_insufficient.emit()
		return
	GameManager.spend_lantern(cost() * 0.5)
	AudioManager.play_named(&"lantern")
	memory_illuminated.emit(memory_id)
