extends Node
## AudioManager — placeholder procedural audio so systems are wired end to end
## before real assets exist (GDD 22: audio is part of the vertical slice).
##
## Generates short tones at runtime; swap `play_named` bodies for stream
## playback when produced audio lands in 03 - Audio.

var _sfx_player: AudioStreamPlayer
var _music_player: AudioStreamPlayer
var _sample_rate: int = 22050


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_sfx_player = AudioStreamPlayer.new()
	_sfx_player.bus = &"Master"
	add_child(_sfx_player)
	_music_player = AudioStreamPlayer.new()
	_music_player.volume_db = -14.0
	add_child(_music_player)


## Placeholder tone generator. Replaced by real assets later.
func _tone(frequency: float, length: float, volume_db: float = -12.0) -> AudioStreamWAV:
	var frames: int = maxi(1, int(_sample_rate * length))
	var data := PackedByteArray()
	data.resize(frames * 2)
	for i: int in range(frames):
		var t: float = float(i) / float(_sample_rate)
		var envelope: float = clampf(1.0 - (t / length), 0.0, 1.0)
		var sample: float = sin(TAU * frequency * t) * envelope * 0.6
		var value: int = clampi(int(sample * 32767.0), -32768, 32767)
		data.encode_s16(i * 2, value)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = _sample_rate
	stream.stereo = false
	stream.data = data
	return stream


func play_named(name: StringName) -> void:
	var spec: Array = _spec_for(name)
	var stream: AudioStreamWAV = _tone(float(spec[0]), float(spec[1]))
	_sfx_player.stream = stream
	_sfx_player.volume_db = float(spec[2])
	_sfx_player.play()


func _spec_for(name: StringName) -> Array:
	match name:
		&"light_attack": return [520.0, 0.07, -14.0]
		&"heavy_attack": return [180.0, 0.18, -10.0]
		&"hit_landed": return [300.0, 0.09, -12.0]
		&"player_hurt": return [120.0, 0.22, -8.0]
		&"dash": return [760.0, 0.08, -18.0]
		&"lantern": return [880.0, 0.25, -14.0]
		&"anchor": return [96.0, 0.5, -8.0]
		&"revelation": return [660.0, 0.7, -8.0]
		&"clue": return [1180.0, 0.14, -16.0]
		&"resolution": return [220.0, 0.9, -8.0]
		&"death": return [70.0, 1.1, -6.0]
	return [440.0, 0.1, -14.0]
