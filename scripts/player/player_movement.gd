class_name PlayerMovement
extends Node
## PlayerMovement — the movement feel spec from GDD section 3.
##
## Agile but not weightless: variable-height jumping, coyote time, jump
## buffering, double jump, wall slide/jump, ledge climb, dash, air control,
## gravity scaling and landing weight.

signal landed(impact_speed: float)
signal jumped
signal double_jumped
signal wall_jumped(direction: float)
signal dashed(direction: Vector2)
signal wall_slide_started
signal ledge_grabbed

## Tuning. Exposed so feel can be iterated without touching code.
@export var run_speed: float = 230.0
@export var acceleration: float = 1900.0
@export var ground_friction: float = 2400.0
@export var air_friction: float = 700.0
@export var air_control: float = 0.82
@export var jump_velocity: float = -430.0
@export var jump_cut_multiplier: float = 0.45      ## Variable-height jump.
@export var jump_buffer_time: float = 0.12
@export var coyote_time: float = 0.10
@export var max_jumps: int = 2                      ## 2nd unlocked via progression.
@export var gravity_scale: float = 1.0
@export var gravity_rising_multiplier: float = 1.0
@export var gravity_falling_multiplier: float = 1.35 ## Heavier on the way down.
@export var terminal_velocity: float = 900.0
@export var wall_slide_max_speed: float = 110.0
@export var wall_jump_velocity: Vector2 = Vector2(280.0, -390.0)
@export var wall_jump_lock_time: float = 0.16
@export var dash_speed: float = 620.0
@export var dash_duration: float = 0.16
@export var dash_cooldown: float = 0.45
@export var dash_iframe_duration: float = 0.0
@export var ledge_climb_duration: float = 0.28
@export var can_double_jump: bool = false
@export var can_wall_interact: bool = true
@export var can_ledge_climb: bool = true

var body: CharacterBody2D
var hurtbox: Hurtbox

var move_direction: float = 0.0
var facing: float = 1.0
var jumps_used: int = 0
var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var was_on_floor: bool = false
## Mirrors the body's floor state. PlayerController pushes it each physics
## frame so visuals and abilities agree with what the physics actually did.
var is_airborne: bool = false
var is_dashing: bool = false
var dash_timer: float = 0.0
var dash_cooldown_timer: float = 0.0
var dash_direction: Vector2 = Vector2.RIGHT
var is_wall_sliding: bool = false
var wall_normal: Vector2 = Vector2.ZERO
var wall_jump_lock_timer: float = 0.0
var is_ledge_climbing: bool = false
var ledge_climb_timer: float = 0.0
var ledge_target: Vector2 = Vector2.ZERO
var gravity_flip: bool = false


func setup(owner_body: CharacterBody2D, owner_hurtbox: Hurtbox) -> void:
	body = owner_body
	hurtbox = owner_hurtbox


func _physics_process(delta: float) -> void:
	if body == null:
		return
	_tick_timers(delta)
	if is_ledge_climbing:
		_process_ledge_climb(delta)
		return
	if is_dashing:
		_process_dash(delta)
		return

	move_direction = Input.get_axis(&"move_left", &"move_right")
	if not is_zero_approx(move_direction):
		facing = signf(move_direction)

	_apply_gravity(delta)
	_apply_horizontal(delta)
	_handle_coyote_and_buffer(delta)
	_handle_wall_slide()
	body.move_and_slide()

	if body.is_on_floor():
		jumps_used = 0
		coyote_timer = coyote_time
		if not was_on_floor:
			var impact: float = absf(body.velocity.y)
			landed.emit(impact)
	else:
		coyote_timer = maxf(0.0, coyote_timer - delta)
	was_on_floor = body.is_on_floor()


# --- Input entry points (called by PlayerController) ------------------------
func request_jump() -> void:
	jump_buffer_timer = jump_buffer_time


func release_jump() -> void:
	# Variable-height jump: letting go early cuts the rise short.
	if body.velocity.y * _gravity_sign() < 0.0:
		body.velocity.y *= jump_cut_multiplier


func request_dash() -> bool:
	if dash_cooldown_timer > 0.0 or is_dashing or is_ledge_climbing:
		return false
	is_dashing = true
	dash_timer = dash_duration
	dash_cooldown_timer = dash_cooldown
	dash_direction = Vector2(move_direction if not is_zero_approx(move_direction) else facing, 0.0).normalized()
	if dash_direction == Vector2.ZERO:
		dash_direction = Vector2(facing, 0.0)
	if dash_iframe_duration > 0.0 and hurtbox != null:
		hurtbox.grant_invulnerability(dash_iframe_duration)
	AudioManager.play_named(&"dash")
	dashed.emit(dash_direction)
	return true


func request_double_jump_unlock() -> void:
	can_double_jump = true
	max_jumps = maxi(max_jumps, 2)


func set_gravity_flip(active: bool) -> void:
	gravity_flip = active


## PlayerController pushes the authoritative facing in here every physics
## frame. Movement input sets it too, but mouse aiming overrides it, and that
## override has to survive the next input read rather than fight it.
func set_facing(value: float) -> void:
	if is_zero_approx(value):
		return
	facing = value


func set_airborne(value: bool) -> void:
	is_airborne = value


# --- Internals --------------------------------------------------------------
func _gravity_sign() -> float:
	return -1.0 if gravity_flip else 1.0


func _tick_timers(delta: float) -> void:
	jump_buffer_timer = maxf(0.0, jump_buffer_timer - delta)
	dash_cooldown_timer = maxf(0.0, dash_cooldown_timer - delta)
	wall_jump_lock_timer = maxf(0.0, wall_jump_lock_timer - delta)


func _apply_gravity(delta: float) -> void:
	if body.is_on_floor() and body.velocity.y * _gravity_sign() >= 0.0:
		return
	var base_gravity: float = _project_gravity()
	var multiplier: float = gravity_rising_multiplier if body.velocity.y * _gravity_sign() < 0.0 else gravity_falling_multiplier
	if is_wall_sliding:
		multiplier = 0.35
	body.velocity.y += base_gravity * gravity_scale * multiplier * delta
	body.velocity.y = clampf(body.velocity.y, -terminal_velocity, terminal_velocity)


func _project_gravity() -> float:
	var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity", 980.0)
	return gravity * _gravity_sign()


func _apply_horizontal(delta: float) -> void:
	if wall_jump_lock_timer > 0.0:
		return
	var target_speed: float = move_direction * run_speed * speed_modifier()
	var control: float = air_control if not body.is_on_floor() else 1.0
	var rate: float = (acceleration if absf(target_speed) > absf(body.velocity.x) else (ground_friction if body.is_on_floor() else air_friction)) * control
	body.velocity.x = move_toward(body.velocity.x, target_speed, rate * delta)


## Equipment and Echoes can modify movement speed (GDD 11).
func speed_modifier() -> float:
	var modifier: float = 1.0 + ProgressionManager.effect_total(&"move_speed")
	modifier += float(ProgressionManager.agility - 5) * 0.012
	return clampf(modifier, 0.7, 1.35)


func _handle_coyote_and_buffer(_delta: float) -> void:
	if jump_buffer_timer <= 0.0:
		return
	if body.is_on_floor() or coyote_timer > 0.0:
		_do_jump()
	elif jumps_used < max_jumps and can_double_jump:
		_do_double_jump()
	elif is_wall_sliding and can_wall_interact:
		_do_wall_jump()


func _do_jump() -> void:
	body.velocity.y = jump_velocity * _gravity_sign()
	jumps_used = 1
	coyote_timer = 0.0
	jump_buffer_timer = 0.0
	# A jump taken from coyote time still counts as the first jump: the player
	# pressed in time, so the game should never punish them for it.
	AudioManager.play_named(&"jump")
	jumped.emit()


func _do_double_jump() -> void:
	body.velocity.y = jump_velocity * 0.9 * _gravity_sign()
	jumps_used += 1
	jump_buffer_timer = 0.0
	AudioManager.play_named(&"double_jump")
	double_jumped.emit()


func _do_wall_jump() -> void:
	var direction: float = -signf(wall_normal.x) if wall_normal.x != 0.0 else facing
	body.velocity = Vector2(wall_jump_velocity.x * direction, wall_jump_velocity.y * _gravity_sign())
	wall_jump_lock_timer = wall_jump_lock_time
	jumps_used = 1
	jump_buffer_timer = 0.0
	is_wall_sliding = false
	AudioManager.play_named(&"wall_jump")
	Fx.dust(body, body.global_position + Vector2(-direction * 8.0, -12.0), 6)
	wall_jumped.emit(direction)


func _handle_wall_slide() -> void:
	var sliding: bool = (
		can_wall_interact
		and not body.is_on_floor()
		and body.is_on_wall()
		and body.velocity.y > 0.0
		and not is_zero_approx(move_direction)
	)
	if sliding and not is_wall_sliding:
		wall_slide_started.emit()
	is_wall_sliding = sliding
	if is_wall_sliding:
		wall_normal = body.get_wall_normal()
		body.velocity.y = minf(body.velocity.y, wall_slide_max_speed)
		if can_ledge_climb and Input.is_action_just_pressed(&"jump"):
			_try_ledge_grab()


func _try_ledge_grab() -> void:
	# Ledge is above and slightly inward from the wall we are sliding on.
	var probe_origin: Vector2 = body.global_position + Vector2(-wall_normal.x * 14.0, -34.0)
	var space: PhysicsDirectSpaceState2D = body.get_world_2d().direct_space_state
	if space == null:
		return
	var query := PhysicsRayQueryParameters2D.create(probe_origin, probe_origin + Vector2(-wall_normal.x * 26.0, 0.0))
	query.exclude = [body.get_rid()]
	query.collision_mask = 1
	var hit: Dictionary = space.intersect_ray(query)
	if hit.is_empty():
		return
	ledge_target = Vector2(probe_origin.x - wall_normal.x * 20.0, body.global_position.y - 52.0)
	is_ledge_climbing = true
	ledge_climb_timer = ledge_climb_duration
	ledge_grabbed.emit()


func _process_ledge_climb(delta: float) -> void:
	ledge_climb_timer -= delta
	var t: float = 1.0 - clampf(ledge_climb_timer / ledge_climb_duration, 0.0, 1.0)
	body.global_position = body.global_position.lerp(ledge_target, t * 0.35)
	body.velocity = Vector2.ZERO
	if ledge_climb_timer <= 0.0:
		is_ledge_climbing = false
		body.global_position = ledge_target
		jumps_used = 0


func _process_dash(delta: float) -> void:
	dash_timer -= delta
	body.velocity = dash_direction * dash_speed
	body.velocity.y = 0.0 if not gravity_flip else body.velocity.y
	body.move_and_slide()
	if dash_timer <= 0.0:
		is_dashing = false
		# Dash recovery: keep a little momentum so it feels weighty, not floaty.
		body.velocity.x = dash_direction.x * run_speed * 0.6


func can_act() -> bool:
	return not is_ledge_climbing


func reset_at(position: Vector2) -> void:
	body.global_position = position
	body.velocity = Vector2.ZERO
	is_dashing = false
	is_ledge_climbing = false
	is_wall_sliding = false
	jumps_used = 0
	dash_cooldown_timer = 0.0
	gravity_flip = false
