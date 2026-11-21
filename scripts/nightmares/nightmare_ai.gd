class_name NightmareAI
extends Node
## NightmareAI — behavioural identity per nightmare (GDD 7).
##
## One FSM, but the `category` in NightmareData changes how each state behaves
## so enemies are never interchangeable damage sources:
##   Stalker     — stalks at range, blinks out, strikes from behind.
##   Warden      — holds ground, controls space, armoured while defending.
##   Distorter   — raises local distortion instead of closing distance.
##   Mimic       — looks harmless until observed, then commits.
##   Fragmented  — erratic movement, splits attention between feints.
##   Hunter      — pursues across long distances, never gives up early.
##   MemoryEater — drains Lantern charge and Resonance rather than health.
##
## Every attack has a readable telegraph (GDD 19). Difficulty comes from
## reading behaviour, never from invisible hits.

signal state_changed(new_state: int)
signal telegraph_started(duration: float)
signal attack_committed

enum State { IDLE, PATROL, INVESTIGATE, PURSUE, TELEGRAPH, ATTACK, RECOVER, DODGE, DEFEND, STAGGERED, RETREAT, DEAD }

@export var patrol_range: float = 140.0
@export var investigate_time: float = 1.4
@export var retreat_health_fraction: float = 0.2
@export var dodge_reaction_time: float = 0.18

var nightmare: NightmareBase
var state: int = State.IDLE
var state_timer: float = 0.0
var patrol_origin: Vector2 = Vector2.ZERO
var patrol_direction: float = 1.0
var target: Node2D = null
var facing: float = 1.0
var is_telegraphing: bool = false
var _dodge_timer: float = 0.0
var _telegraph_visual: ColorRect = null


func _ready() -> void:
	nightmare = get_parent() as NightmareBase
	if nightmare == null:
		push_error("NightmareAI must be a child of NightmareBase")
		return
	patrol_origin = nightmare.global_position
	_build_telegraph_visual()


func _physics_process(delta: float) -> void:
	if nightmare == null or nightmare.data == null or nightmare.is_dead:
		return
	if nightmare.is_staggered and state != State.STAGGERED:
		change_state(State.STAGGERED, 0.85)

	state_timer -= delta
	_refresh_target()

	match state:
		State.IDLE: _tick_idle(delta)
		State.PATROL: _tick_patrol(delta)
		State.INVESTIGATE: _tick_investigate(delta)
		State.PURSUE: _tick_pursue(delta)
		State.TELEGRAPH: _tick_telegraph(delta)
		State.ATTACK: _tick_attack(delta)
		State.RECOVER: _tick_recover(delta)
		State.DODGE: _tick_dodge(delta)
		State.DEFEND: _tick_defend(delta)
		State.STAGGERED: _tick_staggered(delta)
		State.RETREAT: _tick_retreat(delta)
		State.DEAD: pass

	nightmare.move_and_slide()


# --- State entry ------------------------------------------------------------
func change_state(new_state: int, duration: float = 0.0) -> void:
	if state == new_state:
		return
	state = new_state
	state_timer = duration
	match new_state:
		State.TELEGRAPH:
			is_telegraphing = true
			_show_telegraph(true)
			telegraph_started.emit(nightmare.data.attack_startup)
		State.ATTACK:
			is_telegraphing = false
			_show_telegraph(false)
			nightmare.hitbox.activate()
			attack_committed.emit()
		_:
			is_telegraphing = false
			_show_telegraph(false)
			nightmare.hitbox.deactivate()
	state_changed.emit(new_state)


## Called by Lantern/Anchor/counter. Cancels the current action.
func interrupt() -> bool:
	if nightmare.is_dead:
		return false
	if state in [State.TELEGRAPH, State.ATTACK, State.RECOVER]:
		change_state(State.STAGGERED, 0.7)
		return true
	return false


# --- Per-state behaviour ----------------------------------------------------
func _tick_idle(_delta: float) -> void:
	nightmare.velocity.x = move_toward(nightmare.velocity.x, 0.0, 900.0 * get_physics_process_delta_time())
	if target != null and _distance_to_target() < nightmare.data.detect_range:
		change_state(State.PURSUE if _aggressive() else State.INVESTIGATE, investigate_time)
	elif state_timer <= 0.0:
		change_state(State.PATROL)


func _tick_patrol(_delta: float) -> void:
	var speed: float = nightmare.data.move_speed * 0.45
	nightmare.velocity.x = patrol_direction * speed
	facing = patrol_direction
	if absf(nightmare.global_position.x - patrol_origin.x) > patrol_range:
		patrol_direction = -patrol_direction
	if target != null and _distance_to_target() < nightmare.data.detect_range:
		change_state(State.PURSUE if _aggressive() else State.INVESTIGATE, investigate_time)


func _tick_investigate(_delta: float) -> void:
	# Turns to look. Wardens and Stalkers watch before committing.
	nightmare.velocity.x = move_toward(nightmare.velocity.x, 0.0, 700.0 * get_physics_process_delta_time())
	if target != null:
		facing = signf(target.global_position.x - nightmare.global_position.x)
	if state_timer <= 0.0:
		change_state(State.PURSUE)


func _tick_pursue(_delta: float) -> void:
	if target == null:
		change_state(State.PATROL)
		return
	_apply_category_pursuit()
	var distance: float = _distance_to_target()
	if nightmare.normalised_health() <= retreat_health_fraction and _should_retreat():
		change_state(State.RETREAT, 2.0)
		return
	if distance <= nightmare.data.attack_range:
		change_state(State.TELEGRAPH, nightmare.data.attack_startup)


func _apply_category_pursuit() -> void:
	var delta: float = get_physics_process_delta_time()
	var speed: float = nightmare.data.move_speed
	match nightmare.data.category:
		NightmareData.Category.STALKER:
			# Keeps its distance, blinks to the far side when it can.
			if _distance_to_target() < nightmare.data.attack_range * 0.6 and nightmare.can_teleport():
				_blink_behind_target()
			nightmare.velocity.x = move_toward(nightmare.velocity.x, _direction_to_target() * speed * 0.8, 1200.0 * delta)
		NightmareData.Category.WARDEN:
			# Advances slowly and defends rather than chasing.
			if _distance_to_target() > nightmare.data.attack_range * 1.4:
				change_state(State.DEFEND, 1.2)
				return
			nightmare.velocity.x = move_toward(nightmare.velocity.x, _direction_to_target() * speed * 0.4, 700.0 * delta)
			nightmare.hurtbox.armour = 8.0
		NightmareData.Category.DISTORTER:
			# Raises distortion instead of closing in.
			nightmare.velocity.x = move_toward(nightmare.velocity.x, -_direction_to_target() * speed * 0.35, 700.0 * delta)
			if state_timer <= 0.0:
				GameManager.distortion_changed.emit(WorldManager.current_region, 0.6)
				state_timer = 3.0
		NightmareData.Category.MIMIC:
			# Walks like a person until it is very close.
			nightmare.velocity.x = move_toward(nightmare.velocity.x, _direction_to_target() * speed * 0.55, 900.0 * delta)
		NightmareData.Category.FRAGMENTED:
			# Erratic: alternates direction on a short cadence.
			if randf() < 0.02:
				patrol_direction = -patrol_direction
			nightmare.velocity.x = move_toward(nightmare.velocity.x, patrol_direction * speed, 1400.0 * delta)
		NightmareData.Category.HUNTER:
			nightmare.velocity.x = move_toward(nightmare.velocity.x, _direction_to_target() * speed, 1500.0 * delta)
		NightmareData.Category.MEMORY_EATER:
			nightmare.velocity.x = move_toward(nightmare.velocity.x, _direction_to_target() * speed * 0.7, 1000.0 * delta)
			if _distance_to_target() < nightmare.data.attack_range and state_timer <= 0.0:
				_drain_resources()
				state_timer = 2.5
	facing = _direction_to_target()


func _tick_telegraph(_delta: float) -> void:
	# Telegraph: the player can read it and answer it (GDD 19).
	nightmare.velocity.x = move_toward(nightmare.velocity.x, 0.0, 1600.0 * get_physics_process_delta_time())
	if state_timer <= 0.0:
		change_state(State.ATTACK, 0.12)


func _tick_attack(_delta: float) -> void:
	if nightmare.data.category == NightmareData.Category.MEMORY_EATER:
		_drain_resources()
	nightmare.velocity.x = facing * nightmare.data.move_speed * 0.5
	if state_timer <= 0.0:
		change_state(State.RECOVER, nightmare.data.attack_recovery)


func _tick_recover(_delta: float) -> void:
	nightmare.velocity.x = move_toward(nightmare.velocity.x, 0.0, 900.0 * get_physics_process_delta_time())
	# Recovery is the punish window. Dodge only if it survives the roll.
	if target != null and _distance_to_target() < nightmare.data.attack_range * 0.8:
		if randf() < nightmare.data.dodge_chance:
			change_state(State.DODGE, dodge_reaction_time)
			return
	if state_timer <= 0.0:
		change_state(State.PURSUE)


func _tick_dodge(_delta: float) -> void:
	nightmare.velocity.x = -facing * nightmare.data.move_speed * 1.6
	if state_timer <= 0.0:
		change_state(State.PURSUE)


func _tick_defend(delta: float) -> void:
	nightmare.hurtbox.armour = 10.0
	nightmare.velocity.x = move_toward(nightmare.velocity.x, 0.0, 1200.0 * delta)
	if state_timer <= 0.0:
		nightmare.hurtbox.armour = 0.0
		change_state(State.PURSUE)


func _tick_staggered(delta: float) -> void:
	nightmare.velocity.x = move_toward(nightmare.velocity.x, 0.0, 1400.0 * delta)
	if not nightmare.is_staggered and state_timer <= 0.0:
		change_state(State.PURSUE)


func _tick_retreat(_delta: float) -> void:
	nightmare.velocity.x = -_direction_to_target() * nightmare.data.move_speed
	if state_timer <= 0.0:
		change_state(State.PURSUE)


# --- Helpers ----------------------------------------------------------------
func _refresh_target() -> void:
	var players: Array[Node] = nightmare.get_tree().get_nodes_in_group("player")
	target = players[0] as Node2D if not players.is_empty() else null


func _distance_to_target() -> float:
	if target == null:
		return INF
	return absf(target.global_position.x - nightmare.global_position.x)


func _direction_to_target() -> float:
	if target == null:
		return facing
	var direction: float = signf(target.global_position.x - nightmare.global_position.x)
	return facing if is_zero_approx(direction) else direction


## Stalkers and Hunters commit immediately; the others observe first.
func _aggressive() -> bool:
	return nightmare.data.category in [
		NightmareData.Category.HUNTER,
		NightmareData.Category.FRAGMENTED,
	]


func _should_retreat() -> bool:
	return nightmare.data.category in [
		NightmareData.Category.STALKER,
		NightmareData.Category.MIMIC,
		NightmareData.Category.MEMORY_EATER,
	]


func _blink_behind_target() -> void:
	if target == null or not nightmare.can_teleport():
		return
	var offset: float = 70.0 * -_direction_to_target()
	nightmare.global_position.x = target.global_position.x + offset


## Memory Eaters attack resources instead of health (GDD 7).
func _drain_resources() -> void:
	GameManager.spend_lantern(12.0)
	GameManager.spend_resonance(10.0)
	AudioManager.play_named(&"player_hurt")


## Readable warning before the hit lands.
func _build_telegraph_visual() -> void:
	_telegraph_visual = ColorRect.new()
	_telegraph_visual.color = nightmare.data.telegraph_color
	_telegraph_visual.size = Vector2(nightmare.data.attack_range, 4)
	_telegraph_visual.position = Vector2(0, -6)
	_telegraph_visual.visible = false
	nightmare.add_child(_telegraph_visual)


func _show_telegraph(visible: bool) -> void:
	if _telegraph_visual == null:
		return
	_telegraph_visual.visible = visible
	_telegraph_visual.position.x = 0.0 if facing > 0.0 else -nightmare.data.attack_range
