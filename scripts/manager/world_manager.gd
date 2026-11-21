extends Node
## WorldManager — region/level flow, checkpoints, respawns (GDD 12, 13).

signal region_entered(region_id: StringName)
signal level_requested(scene_path: String)
signal respawn_requested(spawn_point: Vector2)

const MAIN_REGIONS: Array[StringName] = [
	&"hollow_village",
	&"ashen_steps",
	&"the_bell_depths",
]

var current_region: StringName = &""
var current_level: String = ""
## checkpoint id -> world position, per region.
var checkpoints: Dictionary = {}
var active_checkpoint: StringName = &""
## Regions whose state has permanently changed because of a resolution.
var changed_regions: Dictionary = {}


func enter_region(region_id: StringName) -> void:
	current_region = region_id
	region_entered.emit(region_id)


func request_level(scene_path: String) -> void:
	current_level = scene_path
	level_requested.emit(scene_path)
	get_tree().change_scene_to_file(scene_path)


func register_checkpoint(checkpoint_id: StringName, world_position: Vector2) -> void:
	if not checkpoints.has(current_region):
		checkpoints[current_region] = {}
	(checkpoints[current_region] as Dictionary)[String(checkpoint_id)] = world_position


func activate_checkpoint(checkpoint_id: StringName) -> void:
	active_checkpoint = checkpoint_id
	GameManager.checkpoint_reached.emit(checkpoint_id)


func respawn_position() -> Vector2:
	var region_data: Variant = checkpoints.get(current_region, {})
	if region_data is Dictionary and region_data.has(String(active_checkpoint)):
		return region_data[String(active_checkpoint)]
	return Vector2.ZERO


func mark_region_changed(region_id: StringName, reason: StringName) -> void:
	changed_regions[region_id] = reason


func to_dict() -> Dictionary:
	var packed_checkpoints: Dictionary = {}
	for region: Variant in checkpoints.keys():
		var entries: Dictionary = {}
		for checkpoint_id: Variant in (checkpoints[region] as Dictionary).keys():
			var pos: Vector2 = (checkpoints[region] as Dictionary)[checkpoint_id]
			entries[String(checkpoint_id)] = {"x": pos.x, "y": pos.y}
		packed_checkpoints[String(region)] = entries
	return {
		"current_region": String(current_region),
		"current_level": current_level,
		"active_checkpoint": String(active_checkpoint),
		"checkpoints": packed_checkpoints,
		"changed_regions": changed_regions.duplicate(true),
	}


func from_dict(data: Dictionary) -> void:
	current_region = StringName(String(data.get("current_region", "")))
	current_level = String(data.get("current_level", ""))
	active_checkpoint = StringName(String(data.get("active_checkpoint", "")))
	checkpoints.clear()
	var packed: Variant = data.get("checkpoints", {})
	if packed is Dictionary:
		for region: String in (packed as Dictionary).keys():
			var entries: Dictionary = {}
			var raw_entries: Variant = (packed as Dictionary)[region]
			if raw_entries is Dictionary:
				for checkpoint_id: String in (raw_entries as Dictionary).keys():
					var raw_pos: Variant = (raw_entries as Dictionary)[checkpoint_id]
					if raw_pos is Dictionary:
						entries[checkpoint_id] = Vector2(
							float((raw_pos as Dictionary).get("x", 0.0)),
							float((raw_pos as Dictionary).get("y", 0.0))
						)
			checkpoints[StringName(region)] = entries
	changed_regions = (data.get("changed_regions", {}) as Dictionary).duplicate(true)
