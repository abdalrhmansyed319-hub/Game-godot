extends Node
## GameManager — authoritative run state and cross-system signals.
##
## Everything that must survive a scene change lives here. Systems talk to each
## other through these signals rather than reaching into one another.

# --- Resources (GDD 12) -----------------------------------------------------
signal health_changed(current: float, maximum: float)
signal resonance_changed(current: float, maximum: float)
signal lantern_changed(current: float, maximum: float)
signal fragments_changed(amount: int)

# --- Hunt state (GDD 6) -----------------------------------------------------
signal nightmare_resolved(nightmare_id: StringName, resolution: int)
signal revelation_started(nightmare_id: StringName)
signal revelation_ended(nightmare_id: StringName)
signal clue_discovered(clue_id: StringName, nightmare_id: StringName)

# --- Progression (GDD 9) ----------------------------------------------------
signal experience_gained(amount: int)
signal hunter_level_up(new_level: int, points: int)
signal attribute_changed(attribute: StringName, value: int)

# --- World / flow -----------------------------------------------------------
signal player_died
signal checkpoint_reached(checkpoint_id: StringName)
signal distortion_changed(region_id: StringName, level: float)

const MAX_HEALTH_BASE: float = 100.0
const MAX_RESONANCE_BASE: float = 100.0
const MAX_LANTERN_BASE: float = 100.0

var max_health: float = MAX_HEALTH_BASE
var health: float = MAX_HEALTH_BASE
var max_resonance: float = MAX_RESONANCE_BASE
var resonance: float = 0.0
var max_lantern: float = MAX_LANTERN_BASE
var lantern_charge: float = MAX_LANTERN_BASE
var dream_fragments: int = 0

## Clues discovered, keyed by nightmare id. Drives which resolutions unlock.
var clues: Dictionary = {}
## Nightmares resolved this run, keyed by id -> resolution kind.
var resolutions: Dictionary = {}

var _ready_state_emitted: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func reset_run_state() -> void:
	max_health = MAX_HEALTH_BASE
	health = max_health
	max_resonance = MAX_RESONANCE_BASE
	resonance = 0.0
	max_lantern = MAX_LANTERN_BASE
	lantern_charge = max_lantern
	dream_fragments = 0
	clues.clear()
	resolutions.clear()
	health_changed.emit(health, max_health)
	resonance_changed.emit(resonance, max_resonance)
	lantern_changed.emit(lantern_charge, max_lantern)
	fragments_changed.emit(dream_fragments)


# --- Health -----------------------------------------------------------------
func damage(amount: float) -> void:
	if amount <= 0.0:
		return
	health = clampf(health - amount, 0.0, max_health)
	health_changed.emit(health, max_health)
	if health <= 0.0:
		player_died.emit()


func heal(amount: float) -> void:
	health = clampf(health + amount, 0.0, max_health)
	health_changed.emit(health, max_health)


func set_max_health(value: float) -> void:
	var ratio: float = health / max_health if max_health > 0.0 else 1.0
	max_health = maxf(1.0, value)
	health = clampf(max_health * ratio, 0.0, max_health)
	health_changed.emit(health, max_health)


func is_alive() -> bool:
	return health > 0.0


# --- Resonance --------------------------------------------------------------
func add_resonance(amount: float) -> void:
	if amount == 0.0:
		return
	resonance = clampf(resonance + amount, 0.0, max_resonance)
	resonance_changed.emit(resonance, max_resonance)


func spend_resonance(amount: float) -> bool:
	if resonance < amount:
		return false
	resonance = clampf(resonance - amount, 0.0, max_resonance)
	resonance_changed.emit(resonance, max_resonance)
	return true


func set_max_resonance(value: float) -> void:
	max_resonance = maxf(1.0, value)
	resonance = clampf(resonance, 0.0, max_resonance)
	resonance_changed.emit(resonance, max_resonance)


# --- Lantern ----------------------------------------------------------------
func spend_lantern(amount: float) -> bool:
	if lantern_charge < amount:
		return false
	lantern_charge = clampf(lantern_charge - amount, 0.0, max_lantern)
	lantern_changed.emit(lantern_charge, max_lantern)
	return true


func restore_lantern(amount: float) -> void:
	lantern_charge = clampf(lantern_charge + amount, 0.0, max_lantern)
	lantern_changed.emit(lantern_charge, max_lantern)


# --- Fragments --------------------------------------------------------------
func add_fragments(amount: int) -> void:
	dream_fragments = maxi(0, dream_fragments + amount)
	fragments_changed.emit(dream_fragments)


# --- Clues / resolution (GDD 2 and 6) ---------------------------------------
func discover_clue(clue_id: StringName, nightmare_id: StringName) -> bool:
	if not clues.has(nightmare_id):
		clues[nightmare_id] = []
	var list: Array = clues[nightmare_id]
	if list.has(clue_id):
		return false
	list.append(clue_id)
	clue_discovered.emit(clue_id, nightmare_id)
	return true


func has_clue(clue_id: StringName, nightmare_id: StringName) -> bool:
	return clues.has(nightmare_id) and (clues[nightmare_id] as Array).has(clue_id)


func clue_count(nightmare_id: StringName) -> int:
	return 0 if not clues.has(nightmare_id) else (clues[nightmare_id] as Array).size()


func record_resolution(nightmare_id: StringName, resolution: int) -> void:
	resolutions[nightmare_id] = resolution
	nightmare_resolved.emit(nightmare_id, resolution)


func is_resolved(nightmare_id: StringName) -> bool:
	return resolutions.has(nightmare_id)


# --- Serialization ----------------------------------------------------------
func to_dict() -> Dictionary:
	return {
		"max_health": max_health,
		"health": health,
		"max_resonance": max_resonance,
		"resonance": resonance,
		"max_lantern": max_lantern,
		"lantern_charge": lantern_charge,
		"dream_fragments": dream_fragments,
		"clues": _serialize_clues(),
		"resolutions": resolutions.duplicate(true),
	}


func from_dict(data: Dictionary) -> void:
	max_health = float(data.get("max_health", MAX_HEALTH_BASE))
	health = clampf(float(data.get("health", max_health)), 0.0, max_health)
	max_resonance = float(data.get("max_resonance", MAX_RESONANCE_BASE))
	resonance = float(data.get("resonance", 0.0))
	max_lantern = float(data.get("max_lantern", MAX_LANTERN_BASE))
	lantern_charge = float(data.get("lantern_charge", max_lantern))
	dream_fragments = int(data.get("dream_fragments", 0))
	clues = _deserialize_clues(data.get("clues", {}))
	resolutions = (data.get("resolutions", {}) as Dictionary).duplicate(true)
	health_changed.emit(health, max_health)
	resonance_changed.emit(resonance, max_resonance)
	lantern_changed.emit(lantern_charge, max_lantern)
	fragments_changed.emit(dream_fragments)


func _serialize_clues() -> Dictionary:
	var out: Dictionary = {}
	for nightmare_id: StringName in clues.keys():
		var packed: PackedStringArray = PackedStringArray()
		for clue_id: StringName in clues[nightmare_id]:
			packed.append(String(clue_id))
		out[String(nightmare_id)] = packed
	return out


func _deserialize_clues(raw: Variant) -> Dictionary:
	var out: Dictionary = {}
	var as_dict: Dictionary = raw if raw is Dictionary else {}
	for key: String in as_dict.keys():
		var list: Array = []
		var values: Variant = as_dict[key]
		if values is PackedStringArray:
			for value: String in values:
				list.append(StringName(value))
		elif values is Array:
			for value: Variant in values:
				list.append(StringName(String(value)))
		out[StringName(key)] = list
	return out
