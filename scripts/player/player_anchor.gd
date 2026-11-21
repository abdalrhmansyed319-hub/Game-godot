class_name PlayerAnchor
extends Node
## The Anchor of Wakefulness — GDD section 4C.
##
## Temporarily stabilises distorted dream reality. Interrupts attacks, holds
## platforms still, stops nightmares teleporting, carves safe zones, and holds
## a nightmare in its vulnerable state. Central to boss fights.

signal zone_created(center: Vector2, radius: float, duration: float)
signal zone_expired
signal target_anchored(target: Node)
signal platform_stabilised(platform: Node)
signal attack_interrupted(target: Node)

const BASE_DURATION: float = 4.0
const BASE_RADIUS: float = 130.0
const COOLDOWN: float = 9.0
## The Anchor costs Resonance: you must fight well before you can stabilise.
const RESONANCE_COST: float = 25.0

var is_active: bool = false
var active_timer: float = 0.0
var cooldown_timer: float = 0.0
var anchored_targets: Array[Node] = []


func _process(delta: float) -> void:
	cooldown_timer = maxf(0.0, cooldown_timer - delta)
	if not is_active:
		return
	active_timer -= delta
	if active_timer <= 0.0:
		deactivate()


func duration() -> float:
	return BASE_DURATION * maxf(0.4, ProgressionManager.effect_total(&"anchor_duration") + 0.6)


func radius() -> float:
	var bonus: float = ProgressionManager.effect_total(&"safe_zone_radius")
	return BASE_RADIUS + bonus


func is_ready() -> bool:
	return cooldown_timer <= 0.0 and not is_active


func can_afford() -> bool:
	return GameManager.resonance >= RESONANCE_COST


## Deploys the Anchor at `center`, stabilising everything inside.
func deploy(center: Vector2, candidates: Array[Node]) -> bool:
	if not is_ready() or not can_afford():
		return false
	GameManager.spend_resonance(RESONANCE_COST)
	is_active = true
	active_timer = duration()
	cooldown_timer = COOLDOWN
	anchored_targets.clear()
	AudioManager.play_named(&"anchor")

	var active_radius: float = radius()
	for candidate: Node in candidates:
		if candidate == null or not is_instance_valid(candidate):
			continue
		if not candidate is Node2D:
			continue
		var node := candidate as Node2D
		if center.distance_to(node.global_position) > active_radius:
			continue
		if node.has_method("set_anchored"):
			node.set_anchored(true, duration())
			anchored_targets.append(node)
			target_anchored.emit(node)
		if node.has_method("stabilise"):
			node.stabilise(duration())
			platform_stabilised.emit(node)
		if node.has_method("interrupt_current_ability"):
			if node.interrupt_current_ability():
				attack_interrupted.emit(node)

	zone_created.emit(center, active_radius, duration())
	return true


func deactivate() -> void:
	if not is_active:
		return
	is_active = false
	active_timer = 0.0
	for target: Node in anchored_targets:
		if is_instance_valid(target) and target.has_method("set_anchored"):
			target.set_anchored(false, 0.0)
	anchored_targets.clear()
	zone_expired.emit()


func is_inside(center: Vector2, point: Vector2) -> bool:
	return is_active and center.distance_to(point) <= radius()
