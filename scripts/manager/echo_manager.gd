extends Node
## EchoManager — collected and equipped Echoes (GDD 10).
##
## Active slots are limited, so choosing Echoes is a build decision.
## Echoes never simply increase damage.

signal echo_collected(echo_id: StringName)
signal echo_equipped(echo_id: StringName, slot: int)
signal echo_unequipped(slot: int)

const MAX_ACTIVE_SLOTS: int = 3

var collected: Array[StringName] = []
## slot index -> echo id
var equipped: Dictionary = {}


func collect(echo_id: StringName) -> bool:
	if echo_id == &"":
		return false
	var data: EchoData = NightmareDatabase.echo(echo_id)
	if data == null:
		return false
	if collected.has(echo_id):
		return false
	collected.append(echo_id)
	JournalManager.discover(
		StringName("echo_" + String(echo_id)),
		JournalManager.Category.MEMORY,
		data.display_name,
		data.narrative_origin
	)
	echo_collected.emit(echo_id)
	return true


func has_collected(echo_id: StringName) -> bool:
	return collected.has(echo_id)


func equip(echo_id: StringName, slot: int) -> bool:
	if slot < 0 or slot >= MAX_ACTIVE_SLOTS:
		return false
	if not collected.has(echo_id):
		return false
	for used_slot: int in equipped.keys():
		if equipped[used_slot] == echo_id:
			return false
	equipped[slot] = echo_id
	echo_equipped.emit(echo_id, slot)
	return true


func unequip(slot: int) -> bool:
	if not equipped.has(slot):
		return false
	equipped.erase(slot)
	echo_unequipped.emit(slot)
	return true


func echo_in_slot(slot: int) -> EchoData:
	if not equipped.has(slot):
		return null
	return NightmareDatabase.echo(equipped[slot])


func active_echoes() -> Array[EchoData]:
	var out: Array[EchoData] = []
	for slot: int in range(MAX_ACTIVE_SLOTS):
		var data: EchoData = echo_in_slot(slot)
		if data != null:
			out.append(data)
	return out


func has_ability(ability_key: StringName) -> bool:
	for data: EchoData in active_echoes():
		if data.ability_key == ability_key:
			return true
	return false


func to_dict() -> Dictionary:
	return {
		"collected": PackedStringArray(collected.map(func(id: StringName) -> String: return String(id))),
		"equipped": equipped.duplicate(true),
	}


func from_dict(data: Dictionary) -> void:
	collected.clear()
	var packed: Variant = data.get("collected", PackedStringArray())
	if packed is PackedStringArray:
		for echo_id: String in packed:
			collected.append(StringName(echo_id))
	elif packed is Array:
		for echo_id: Variant in packed:
			collected.append(StringName(String(echo_id)))
	equipped.clear()
	var raw_equipped: Variant = data.get("equipped", {})
	if raw_equipped is Dictionary:
		for key: Variant in (raw_equipped as Dictionary).keys():
			equipped[int(key)] = StringName(String((raw_equipped as Dictionary)[key]))
