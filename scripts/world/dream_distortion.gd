class_name DreamDistortion
extends Node2D
## DreamDistortion — the world system that makes the dream feel alive (GDD 14).
##
## Distortion is not a visual effect. As it rises: platforms move, gravity
## shifts, paths vanish, enemy behaviour changes, audio becomes unreliable and
## memories surface. The Anchor can stabilise it — but some puzzles need the
## distortion left alone, so control and adaptation are both valid answers.

signal level_changed(level: float)
signal platform_moved(platform: Node2D, offset: Vector2)
signal gravity_shifted(multiplier: float)
signal memory_surfaced(memory_id: StringName)

@export_range(0.0, 1.0) var level: float = 0.0
@export var drift_speed: float = 0.35
@export var platform_drift_amplitude: float = 26.0
@export var gravity_shift_at: float = 0.75
@export var audio_unreliable_at: float = 0.55

var _platforms: Array[Node2D] = []
var _elapsed: float = 0.0
var _surfaced: Dictionary = {}


func _ready() -> void:
	GameManager.distortion_changed.connect(_on_distortion_changed)
	GameManager.revelation_started.connect(func(_id: StringName) -> void: _on_revelation())


func register_platform(platform: Node2D) -> void:
	if not _platforms.has(platform):
		_platforms.append(platform)


func set_level(value: float) -> void:
	level = clampf(value, 0.0, 1.0)
	level_changed.emit(level)


func _on_distortion_changed(_region: StringName, value: float) -> void:
	set_level(value)


func _process(delta: float) -> void:
	_elapsed += delta
	# Slow ambient drift so a distorted area never feels static.
	var drift: float = sin(_elapsed * drift_speed) * level
	for platform: Node2D in _platforms:
		if not is_instance_valid(platform):
			continue
		if platform.has_method("is_stabilised") and bool(platform.is_stabilised()):
			continue
		var offset: Vector2 = Vector2(0.0, drift * platform_drift_amplitude)
		platform.position = platform.position.lerp(platform.position + offset, 0.05)
		platform_moved.emit(platform, offset)

	if level >= gravity_shift_at:
		gravity_shifted.emit(1.0 + (level - gravity_shift_at) * 1.5)
	if level >= audio_unreliable_at and fmod(_elapsed, 6.0) < delta:
		# Audio becomes unreliable: cues may lie to the player.
		AudioManager.play_named(&"clue")
	if level >= 0.6 and fmod(_elapsed, 11.0) < delta:
		_surface_memory()


func _surface_memory() -> void:
	var memory_id := StringName("memory_%s_%d" % [String(WorldManager.current_region), int(_elapsed)])
	if _surfaced.has(memory_id):
		return
	_surfaced[memory_id] = true
	memory_surfaced.emit(memory_id)


## The Anchor pushes distortion back down locally (GDD 4C, 14).
func stabilise(amount: float) -> void:
	set_level(level - amount)


func _on_revelation() -> void:
	# A Revelation always tears the local dream open a little further.
	set_level(minf(1.0, level + 0.2))
