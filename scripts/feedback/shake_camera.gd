class_name ShakeCamera
extends Camera2D
## ShakeCamera — the player camera, and the one place feedback reaches the view.
##
## Three jobs, in order of importance:
##
##   1. **Shake.** Reads `FeedbackManager.shake_offset()` and applies it as a
##      camera offset, never as a position change, so the smoothing that makes
##      following readable is never fighting the shake.
##   2. **Look-ahead.** The camera leads the Hunter slightly in the direction of
##      travel. In a game about reading telegraphs, seeing more of what is
##      ahead of you is a fairness feature, not a flourish.
##   3. **Landing dip.** A hard arrival pushes the camera down a few pixels and
##      eases back. Small, and it does most of the work of making a landing
##      feel weighted.
##
## Intensity is clamped here as well as in FeedbackManager. Two independent
## clamps is deliberate: the camera is the last thing standing between a big
## number and an unreadable screen.

const MAX_SHAKE_OFFSET: float = 16.0
const MAX_LOOK_AHEAD: float = 46.0
const MAX_DIP: float = 14.0

@export var look_ahead_strength: float = 0.35
@export var look_ahead_speed: float = 4.5
@export var dip_recovery_speed: float = 6.0

var _owner_body: CharacterBody2D = null
var _look_target: float = 0.0
var _dip: float = 0.0
var _was_on_floor: bool = true


func _ready() -> void:
	make_current()


func bind(target: CharacterBody2D) -> void:
	_owner_body = target


func _process(delta: float) -> void:
	_update_look_ahead(delta)
	_update_dip(delta)
	offset = _clamped_shake() + Vector2(_look_target, _dip)


func _clamped_shake() -> Vector2:
	var shake: Vector2 = FeedbackManager.shake_offset()
	shake.x = clampf(shake.x, -MAX_SHAKE_OFFSET, MAX_SHAKE_OFFSET)
	shake.y = clampf(shake.y, -MAX_SHAKE_OFFSET, MAX_SHAKE_OFFSET)
	return shake


func _update_look_ahead(delta: float) -> void:
	if _owner_body == null:
		return
	var desired: float = 0.0
	# Mouse aiming gets priority: the player is looking where the cursor is.
	if Settings.use_mouse_to_aim:
		var pointer: float = get_global_mouse_position().x - _owner_body.global_position.x
		desired = clampf(pointer * 0.35, -MAX_LOOK_AHEAD, MAX_LOOK_AHEAD)
	else:
		desired = clampf(_owner_body.velocity.x * look_ahead_strength * 0.25, -MAX_LOOK_AHEAD, MAX_LOOK_AHEAD)
	_look_target = lerpf(_look_target, desired, clampf(delta * look_ahead_speed, 0.0, 1.0))


func _update_dip(delta: float) -> void:
	_dip = move_toward(_dip, 0.0, dip_recovery_speed * MAX_DIP * delta)
	if _owner_body == null:
		return
	var grounded: bool = _owner_body.is_on_floor()
	if grounded and not _was_on_floor:
		# Only a genuinely hard landing moves the camera.
		var impact: float = absf(_owner_body.velocity.y)
		if impact > 260.0:
			_dip = clampf(impact / 900.0, 0.0, 1.0) * MAX_DIP
	_was_on_floor = grounded
