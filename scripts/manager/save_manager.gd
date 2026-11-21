extends Node
## SaveManager — persistent save/load (GDD 12: Quiet Rooms provide saving).
##
## Saves are plain JSON under user:// so they are inspectable while debugging.
## Story discoveries always survive death (GDD 12), so journal, quests,
## decisions and progression are written even on a checkpoint respawn.

signal save_completed(slot: int)
signal load_completed(slot: int)
signal save_failed(slot: int, reason: String)

const SAVE_VERSION: int = 1
const SAVE_DIR: String = "user://saves"
const MAX_SLOTS: int = 3

var last_slot: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		DirAccess.make_dir_recursive_absolute(SAVE_DIR)


func save_path(slot: int) -> String:
	return "%s/save_%d.json" % [SAVE_DIR, clampi(slot, 0, MAX_SLOTS - 1)]


func save_game(slot: int = 0) -> bool:
	last_slot = slot
	var payload: Dictionary = {
		"version": SAVE_VERSION,
		"saved_at": Time.get_datetime_string_from_system(true),
		"game": GameManager.to_dict(),
		"world": WorldManager.to_dict(),
		"journal": JournalManager.to_dict(),
		"quests": QuestManager.to_dict(),
		"decisions": DecisionTracker.to_dict(),
		"progression": ProgressionManager.to_dict(),
		"echoes": EchoManager.to_dict(),
	}
	var file := FileAccess.open(save_path(slot), FileAccess.WRITE)
	if file == null:
		save_failed.emit(slot, "could not open %s (err %d)" % [save_path(slot), FileAccess.get_open_error()])
		return false
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()
	save_completed.emit(slot)
	return true


func has_save(slot: int = 0) -> bool:
	return FileAccess.file_exists(save_path(slot))


func load_game(slot: int = 0) -> bool:
	last_slot = slot
	if not has_save(slot):
		save_failed.emit(slot, "no save in slot %d" % slot)
		return false
	var file := FileAccess.open(save_path(slot), FileAccess.READ)
	if file == null:
		save_failed.emit(slot, "could not read %s" % save_path(slot))
		return false
	var text: String = file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		save_failed.emit(slot, "save file is not valid JSON")
		return false
	var data: Dictionary = parsed
	GameManager.from_dict(data.get("game", {}))
	WorldManager.from_dict(data.get("world", {}))
	JournalManager.from_dict(data.get("journal", {}))
	QuestManager.from_dict(data.get("quests", {}))
	DecisionTracker.from_dict(data.get("decisions", {}))
	ProgressionManager.from_dict(data.get("progression", {}))
	EchoManager.from_dict(data.get("echoes", {}))
	load_completed.emit(slot)
	return true


func delete_save(slot: int = 0) -> bool:
	if not has_save(slot):
		return false
	return DirAccess.remove_absolute(save_path(slot)) == OK


func list_saves() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for slot: int in range(MAX_SLOTS):
		if not has_save(slot):
			continue
		var file := FileAccess.open(save_path(slot), FileAccess.READ)
		if file == null:
			continue
		var parsed: Variant = JSON.parse_string(file.get_as_text())
		file.close()
		var info: Dictionary = {"slot": slot}
		if parsed is Dictionary:
			info["saved_at"] = String(parsed.get("saved_at", "unknown"))
			info["version"] = int(parsed.get("version", 0))
		out.append(info)
	return out
