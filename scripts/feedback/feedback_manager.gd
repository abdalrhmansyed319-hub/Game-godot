extends Node
## FeedbackManager — the game-feel layer.
##
## Everything that makes an impact *feel* like an impact lives here: hit-stop,
## camera shake, screen flash and one-shot particles. Keeping it in one autoload
## means gameplay code asks for feedback instead of each system inventing its
## own, so intensity stays consistent and tunable in one place.
##
## All of it is individually switchable through Settings for accessibility
## (motion and flash reduction are not optional polish).

signal shake_requested(intensity: float, duration: float)
signal hit_stop_started(duration: float)
signal impact(position: Vector2, strength: float, tint: Color)

const MAX_TIME_SCALE_REDUCTION: float = 0.05
const MAX_SHAKE: float = 18.0

var shake_intensity: float = 0.0
var shake_duration: float = 0.0
var shake_timer: float = 0.0
var _flash_rect: ColorRect = null
var _flash_alpha: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_flash_layer()


func _process(delta: float) -> void:
	if shake_timer > 0.0:
		shake_timer = maxf(0.0, shake_timer - delta)
		if shake_timer <= 0.0:
			shake_intensity = 0.0
			shake_duration = 0.0
	if _flash_alpha > 0.0:
		_flash_alpha = maxf(0.0, _flash_alpha - delta * 4.5)
		if _flash_rect != null:
			_flash_rect.color.a = _flash_alpha


## Current camera offset. The active Camera2D reads this every frame.
func shake_offset() -> Vector2:
	if shake_timer <= 0.0 or shake_intensity <= 0.0:
		return Vector2.ZERO
	if not Settings.screen_shake:
		return Vector2.ZERO
	var falloff: float = shake_timer / shake_duration if shake_duration > 0.0 else 0.0
	var magnitude: float = shake_intensity * falloff
	return Vector2(
		randf_range(-magnitude, magnitude),
		randf_range(-magnitude, magnitude) * 0.6
	)


## Request camera shake. Intensity is in pixels and is clamped so a big hit
## never makes the game unreadable.
func shake(intensity: float, duration: float = 0.22) -> void:
	if not Settings.screen_shake:
		return
	shake_intensity = clampf(intensity, 0.0, MAX_SHAKE)
	shake_duration = maxf(0.01, duration)
	shake_timer = shake_duration
	shake_requested.emit(shake_intensity, shake_duration)


## Hit-stop: a very short freeze that sells an impact. Uses real time so the
## freeze itself is not slowed. Disabled entirely when the player asks.
func hit_stop(duration: float = 0.07) -> void:
	if not Settings.hit_stop or duration <= 0.0:
		return
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	tree.time_scale = MAX_TIME_SCALE_REDUCTION
	hit_stop_started.emit(duration)
	tree.create_timer(duration, true, false, true).timeout.connect(
		func() -> void: tree.time_scale = 1.0
	)


## Brief full-screen flash. Suppressed when flash reduction is on.
func flash(alpha: float = 0.22, color: Color = Color(1, 1, 1)) -> void:
	if not Settings.allow_flashes or _flash_rect == null:
		return
	_flash_alpha = clampf(alpha, 0.0, 0.5)
	_flash_rect.color = Color(color.r, color.g, color.b, _flash_alpha)


## Convenience wrapper bundling what a landed hit should do.
##
## `strength` is normalised around 1.0 for a heavy blow. Taking the player
## separately matters: being hit should feel worse than hitting, so it gets
## more shake, more stop and a flash, while the player's own strikes stay
## crisp enough to chain.
func impact_feedback(position: Vector2, strength: float, player_is_victim: bool = false) -> void:
	var tint: Color = Palette.HURT_FLASH if player_is_victim else Palette.BLOODLESS_IMPACT
	impact.emit(position, strength, tint)
	if player_is_victim:
		shake(4.0 + strength * 3.0, 0.26)
		hit_stop(0.07 + clampf(strength * 0.01, 0.0, 0.05))
		flash(0.16 + clampf(strength * 0.03, 0.0, 0.12), Palette.TELEGRAPH)
	else:
		shake(1.6 + strength * 1.4, 0.13 + strength * 0.02)
		hit_stop(0.04 + clampf(strength * 0.02, 0.0, 0.05))


## Clears any feedback still in flight. Called on death and on leaving a
## region, so a shake never follows the player into the next scene and a
## time-scale reduction never survives a scene change.
func cancel_all() -> void:
	shake_intensity = 0.0
	shake_duration = 0.0
	shake_timer = 0.0
	_flash_alpha = 0.0
	if _flash_rect != null:
		_flash_rect.color.a = 0.0
	var tree: SceneTree = get_tree()
	if tree != null:
		tree.time_scale = 1.0


func _build_flash_layer() -> void:
	var layer := CanvasLayer.new()
	layer.name = "FeedbackLayer"
	layer.layer = 90
	add_child(layer)
	_flash_rect = ColorRect.new()
	_flash_rect.color = Color(1, 1, 1, 0)
	_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_flash_rect)
