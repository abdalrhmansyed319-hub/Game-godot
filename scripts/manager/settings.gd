extends Node
## Settings — player-facing options, including the accessibility toggles.
##
## Motion reduction and flash reduction are treated as requirements, not
## extras: every effect in FeedbackManager checks here before running.

signal settings_changed

const CONFIG_PATH: String = "user://settings.cfg"

## Accessibility / comfort.
var screen_shake: bool = true
var hit_stop: bool = true
var allow_flashes: bool = true
var particle_quality: int = 1  ## 0 = low, 1 = normal, 2 = high

## Audio.
var master_volume: float = 1.0
var music_volume: float = 0.8
var sfx_volume: float = 1.0

## Input.
var use_mouse_to_aim: bool = true


func _ready() -> void:
	load_settings()


func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("comfort", "screen_shake", screen_shake)
	config.set_value("comfort", "hit_stop", hit_stop)
	config.set_value("comfort", "allow_flashes", allow_flashes)
	config.set_value("comfort", "particle_quality", particle_quality)
	config.set_value("audio", "master", master_volume)
	config.set_value("audio", "music", music_volume)
	config.set_value("audio", "sfx", sfx_volume)
	config.set_value("input", "use_mouse_to_aim", use_mouse_to_aim)
	config.save(CONFIG_PATH)
	settings_changed.emit()


func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(CONFIG_PATH) != OK:
		return
	screen_shake = bool(config.get_value("comfort", "screen_shake", screen_shake))
	hit_stop = bool(config.get_value("comfort", "hit_stop", hit_stop))
	allow_flashes = bool(config.get_value("comfort", "allow_flashes", allow_flashes))
	particle_quality = int(config.get_value("comfort", "particle_quality", particle_quality))
	master_volume = float(config.get_value("audio", "master", master_volume))
	music_volume = float(config.get_value("audio", "music", music_volume))
	sfx_volume = float(config.get_value("audio", "sfx", sfx_volume))
	use_mouse_to_aim = bool(config.get_value("input", "use_mouse_to_aim", use_mouse_to_aim))
	settings_changed.emit()


## Multiplier applied to particle counts, so low quality really is cheaper.
func particle_scale() -> float:
	match particle_quality:
		0: return 0.4
		2: return 1.5
	return 1.0
