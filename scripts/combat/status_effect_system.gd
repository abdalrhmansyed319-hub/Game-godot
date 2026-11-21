class_name StatusEffectSystem
extends Node
## StatusEffectSystem — timed modifiers applied to a combatant (GDD 21).
##
## Used for stagger, revealed windows, anchored (cannot teleport), silenced,
## and Memory Eater resource drains (GDD 7).

signal effect_applied(effect_id: StringName, duration: float)
signal effect_expired(effect_id: StringName)
signal effect_stacks_changed(effect_id: StringName, stacks: int)

## effect_id -> {duration, remaining, stacks, data}
var _effects: Dictionary = {}


func _process(delta: float) -> void:
	if _effects.is_empty():
		return
	var expired: Array[StringName] = []
	for effect_id: StringName in _effects.keys():
		var effect: Dictionary = _effects[effect_id]
		effect["remaining"] = float(effect["remaining"]) - delta
		if float(effect["remaining"]) <= 0.0:
			expired.append(effect_id)
	for effect_id: StringName in expired:
		_effects.erase(effect_id)
		effect_expired.emit(effect_id)


func apply(effect_id: StringName, duration: float, data: Dictionary = {}) -> void:
	if _effects.has(effect_id):
		var existing: Dictionary = _effects[effect_id]
		existing["remaining"] = maxf(float(existing["remaining"]), duration)
		existing["stacks"] = int(existing["stacks"]) + 1
		effect_stacks_changed.emit(effect_id, int(existing["stacks"]))
		return
	_effects[effect_id] = {
		"duration": duration,
		"remaining": duration,
		"stacks": 1,
		"data": data,
	}
	effect_applied.emit(effect_id, duration)


func remove(effect_id: StringName) -> void:
	if _effects.has(effect_id):
		_effects.erase(effect_id)
		effect_expired.emit(effect_id)


func has_effect(effect_id: StringName) -> bool:
	return _effects.has(effect_id)


func stacks(effect_id: StringName) -> int:
	return 0 if not _effects.has(effect_id) else int((_effects[effect_id] as Dictionary)["stacks"])


func remaining(effect_id: StringName) -> float:
	return 0.0 if not _effects.has(effect_id) else float((_effects[effect_id] as Dictionary)["remaining"])


func clear_all() -> void:
	var ids: Array[StringName] = []
	for effect_id: StringName in _effects.keys():
		ids.append(effect_id)
	for effect_id: StringName in ids:
		_effects.erase(effect_id)
		effect_expired.emit(effect_id)


func active_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for effect_id: StringName in _effects.keys():
		out.append(effect_id)
	return out
