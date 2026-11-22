extends Node
## AudioManager — procedural audio, synthesised at runtime.
##
## Still placeholder material, but no longer a stub: real assets slot in by
## replacing `_spec_for` with a stream lookup. Three things here matter for
## game feel and were missing before:
##
##   1. **A voice pool.** One player meant every new sound cut off the last,
##      so a hit landing during a swing was silent. Combat needs overlap.
##   2. **Noise for impacts.** A blade hitting something is broadband, not a
##      tone. Sine waves alone read as UI blips.
##   3. **Pitch jitter.** Repeating the same light attack at an identical pitch
##      sounds like a machine gun within four swings.
##
## Everything is generated, so the web build carries no audio payload.

const VOICE_COUNT: int = 8
const MAX_GENERATION_LENGTH: float = 1.4

## Cached so a sound played hundreds of times is synthesised once.
var _cache: Dictionary = {}
var _voices: Array[AudioStreamPlayer] = []
var _next_voice: int = 0
var _music_player: AudioStreamPlayer = null
var _sample_rate: int = 22050
var _rng := RandomNumberGenerator.new()
var _sfx_bus_index: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	_ensure_buses()
	for i: int in range(VOICE_COUNT):
		var voice := AudioStreamPlayer.new()
		voice.bus = &"SFX"
		add_child(voice)
		_voices.append(voice)
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = &"Music"
	_music_player.volume_db = -18.0
	add_child(_music_player)


## The default project only has Master. SFX and Music buses are added in code
## so the settings screen has something real to attenuate.
func _ensure_buses() -> void:
	var bus_count: int = AudioServer.bus_count
	for i: int in range(bus_count):
		if AudioServer.get_bus_name(i) == "SFX":
			return
	var sfx := AudioServer.get_bus_index("Master")
	AudioServer.add_bus(sfx + 1)
	AudioServer.set_bus_name(sfx + 1, "SFX")
	AudioServer.set_bus_send(sfx + 1, "Master")
	AudioServer.add_bus(sfx + 2)
	AudioServer.set_bus_name(sfx + 2, "Music")
	AudioServer.set_bus_send(sfx + 2, "Master")


func play_named(sound: StringName) -> void:
	var spec: Array = _spec_for(sound)
	var stream: AudioStreamWAV = _get_stream(sound, spec)
	var voice: AudioStreamPlayer = _voices[_next_voice]
	_next_voice = (_next_voice + 1) % _voices.size()
	voice.stream = stream
	voice.volume_db = float(spec[2])
	# Jitter keeps repeated attacks from locking into a single pitch.
	voice.pitch_scale = 1.0 + _rng.randf_range(-0.06, 0.06)
	voice.play()


func set_sfx_volume_db(value: float) -> void:
	var index: int = AudioServer.get_bus_index("SFX")
	if index >= 0:
		AudioServer.set_bus_volume_db(index, value)


func set_music_volume_db(value: float) -> void:
	var index: int = AudioServer.get_bus_index("Music")
	if index >= 0:
		AudioServer.set_bus_volume_db(index, value)


func set_master_volume_db(value: float) -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), value)


# --- Synthesis --------------------------------------------------------------
func _get_stream(sound: StringName, spec: Array) -> AudioStreamWAV:
	if _cache.has(sound):
		return _cache[sound]
	var stream: AudioStreamWAV = _synthesise(spec)
	_cache[sound] = stream
	return stream


## spec: [frequency, length, volume_db, shape, noise_mix, pitch_drop]
func _synthesise(spec: Array) -> AudioStreamWAV:
	var frequency: float = float(spec[0])
	var length: float = minf(float(spec[1]), MAX_GENERATION_LENGTH)
	var shape: String = String(spec[3]) if spec.size() > 3 else "sine"
	var noise_mix: float = float(spec[4]) if spec.size() > 4 else 0.0
	var pitch_drop: float = float(spec[5]) if spec.size() > 5 else 0.0

	var frames: int = maxi(1, int(_sample_rate * length))
	var data := PackedByteArray()
	data.resize(frames * 2)
	var phase: float = 0.0
	for i: int in range(frames):
		var t: float = float(i) / float(_sample_rate)
		var progress: float = float(i) / float(frames)
		# Percussive envelope: fast attack, exponential-ish decay.
		var envelope: float = powf(1.0 - progress, 2.4)
		var current: float = frequency * (1.0 - pitch_drop * progress)
		phase += TAU * current / float(_sample_rate)
		var sample: float = 0.0
		match shape:
			"square":
				sample = 1.0 if sin(phase) >= 0.0 else -1.0
				sample *= 0.42
			"triangle":
				sample = absf(fmod(phase / PI, 2.0) - 1.0) * 2.0 - 1.0
				sample *= 0.7
			_:
				sample = sin(phase)
		if noise_mix > 0.0:
			sample = lerpf(sample, _rng.randf_range(-1.0, 1.0), noise_mix)
		sample *= envelope * 0.62
		var value: int = clampi(int(sample * 32767.0), -32768, 32767)
		data.encode_s16(i * 2, value)

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = _sample_rate
	stream.stereo = false
	stream.data = data
	return stream


## Sound design table.
##
## Attacks are separated by register and by noise content, so a light and a
## heavy are distinguishable without looking at the screen — which is the
## point of distinct attack SFX.
func _spec_for(sound: StringName) -> Array:
	match sound:
		# --- Blade ---
		&"light_attack": return [620.0, 0.07, -15.0, "triangle", 0.28, 0.35]
		&"heavy_attack": return [190.0, 0.2, -10.0, "square", 0.34, 0.5]
		&"charged_attack": return [130.0, 0.34, -8.0, "square", 0.42, 0.68]
		&"aerial_attack": return [480.0, 0.1, -14.0, "triangle", 0.3, 0.55]
		&"counter": return [880.0, 0.18, -9.0, "square", 0.2, 0.3]
		# --- Impact ---
		&"hit_landed": return [330.0, 0.08, -12.0, "square", 0.6, 0.6]
		&"heavy_impact": return [150.0, 0.16, -8.0, "square", 0.72, 0.75]
		&"nightmare_hit": return [260.0, 0.1, -12.0, "square", 0.55, 0.5]
		&"nightmare_revealed": return [740.0, 0.4, -10.0, "sine", 0.12, 0.25]
		# --- Movement ---
		&"jump": return [420.0, 0.09, -18.0, "sine", 0.1, -0.4]
		&"double_jump": return [560.0, 0.1, -17.0, "sine", 0.1, -0.5]
		&"land": return [120.0, 0.12, -16.0, "square", 0.62, 0.55]
		&"wall_jump": return [300.0, 0.1, -17.0, "triangle", 0.4, -0.3]
		&"dash": return [760.0, 0.09, -18.0, "triangle", 0.45, 0.6]
		# --- Instruments and story ---
		&"lantern": return [880.0, 0.28, -13.0, "sine", 0.08, 0.2]
		&"anchor": return [96.0, 0.5, -8.0, "square", 0.3, 0.35]
		&"revelation": return [660.0, 0.7, -8.0, "sine", 0.06, 0.15]
		&"clue": return [1180.0, 0.16, -16.0, "sine", 0.05, 0.1]
		&"resolution": return [220.0, 0.9, -8.0, "sine", 0.1, 0.3]
		&"death": return [70.0, 1.1, -6.0, "square", 0.25, 0.4]
	return [440.0, 0.1, -14.0, "sine", 0.1, 0.2]
