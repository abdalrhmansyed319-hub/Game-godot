class_name PlayerAbilities
extends Node
## PlayerAbilities — equipped Echoes in play (GDD 10).
##
## Each Echo maps an `ability_key` to behaviour. Echoes grant capability,
## never flat damage, and the player can only carry a few at a time.

signal ability_activated(ability_key: StringName)
signal ability_ended(ability_key: StringName)
signal cooldown_changed(ability_key: StringName, remaining: float)

var _active: Dictionary = {}
var _cooldowns: Dictionary = {}


func tick(delta: float, _player: CharacterBody2D) -> void:
	var finished: Array[StringName] = []
	for ability_key: StringName in _active.keys():
		_active[ability_key] = float(_active[ability_key]) - delta
		if float(_active[ability_key]) <= 0.0:
			finished.append(ability_key)
	for ability_key: StringName in finished:
		_active.erase(ability_key)
		ability_ended.emit(ability_key)

	var cooled: Array[StringName] = []
	for ability_key: StringName in _cooldowns.keys():
		_cooldowns[ability_key] = maxf(0.0, float(_cooldowns[ability_key]) - delta)
		cooldown_changed.emit(ability_key, float(_cooldowns[ability_key]))
		if float(_cooldowns[ability_key]) <= 0.0:
			cooled.append(ability_key)
	for ability_key: StringName in cooled:
		_cooldowns.erase(ability_key)


func is_active(ability_key: StringName) -> bool:
	return _active.has(ability_key)


func cooldown_remaining(ability_key: StringName) -> float:
	return 0.0 if not _cooldowns.has(ability_key) else float(_cooldowns[ability_key])


## Activates the Echo bound to the "special" slot. Returns false when nothing
## usable is equipped or the Echo is still cooling.
func activate_special(player: CharacterBody2D, movement: PlayerMovement) -> bool:
	for data: EchoData in EchoManager.active_echoes():
		if _cooldowns.has(data.ability_key):
			continue
		if _apply(data, player, movement):
			_active[data.ability_key] = data.duration
			_cooldowns[data.ability_key] = data.cooldown
			AudioManager.play_named(&"revelation")
			ability_activated.emit(data.ability_key)
			return true
	return false


func _apply(data: EchoData, player: CharacterBody2D, movement: PlayerMovement) -> bool:
	match data.ability_key:
		&"gravity_flip":
			# Echo of Weightlessness: fight on the ceiling (GDD 10).
			movement.set_gravity_flip(not movement.gravity_flip)
			return true
		&"unfinished_step":
			# Echo of the Unfinished Step: one step across a gap not yet built.
			movement.request_dash()
			return true
		&"hollow_voice":
			# Echo of the Hollow Voice: rings out hidden structures.
			_ring_out_hidden_structures(player)
			return true
		&"borrowed_faces":
			# Echo of Borrowed Faces: mimics lose their borrowed shape.
			_unmask_mimics(player, data.duration)
			return true
	return false


func _ring_out_hidden_structures(player: CharacterBody2D) -> void:
	for node: Node in player.get_tree().get_nodes_in_group("interactive"):
		if node.has_method("resonate"):
			node.resonate()


func _unmask_mimics(player: CharacterBody2D, duration: float) -> void:
	for node: Node in player.get_tree().get_nodes_in_group("nightmares"):
		if node.has_method("unmask"):
			node.unmask(duration)
