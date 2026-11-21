extends Node
## JournalManager — the Hunter's Journal (GDD 17).
##
## Information is discovered, never automatically revealed. Entries are written
## from the protagonist's perspective when the player learns something.

signal entry_added(entry_id: StringName, category: String)
signal entry_updated(entry_id: StringName)

enum Category { CHARACTER, NIGHTMARE, OBSERVATION, MEMORY, REGION, QUEST, MYSTERY, DECISION, WEAKNESS }

## entry_id -> {category, title, body, discovered_at, read}
var entries: Dictionary = {}


func category_name(category: int) -> String:
	match category:
		Category.CHARACTER: return "Characters"
		Category.NIGHTMARE: return "Nightmares"
		Category.OBSERVATION: return "Observations"
		Category.MEMORY: return "Memories"
		Category.REGION: return "Regions"
		Category.QUEST: return "Quests"
		Category.MYSTERY: return "Unresolved Mysteries"
		Category.DECISION: return "Decisions"
		Category.WEAKNESS: return "Known Weaknesses"
	return "Notes"


func discover(
	entry_id: StringName,
	category: int,
	title: String,
	body: String,
	overwrite: bool = false
) -> bool:
	if entries.has(entry_id) and not overwrite:
		return false
	var existing_read: bool = false
	if entries.has(entry_id):
		existing_read = bool((entries[entry_id] as Dictionary).get("read", false))
	entries[entry_id] = {
		"category": category,
		"title": title,
		"body": body,
		"discovered_at": Time.get_datetime_string_from_system(true),
		"read": existing_read,
	}
	if overwrite:
		entry_updated.emit(entry_id)
	else:
		entry_added.emit(entry_id, category_name(category))
	return true


func has_entry(entry_id: StringName) -> bool:
	return entries.has(entry_id)


func mark_read(entry_id: StringName) -> void:
	if entries.has(entry_id):
		(entries[entry_id] as Dictionary)["read"] = true


func unread_count() -> int:
	var count: int = 0
	for entry_id: StringName in entries.keys():
		if not bool((entries[entry_id] as Dictionary).get("read", false)):
			count += 1
	return count


func entries_in_category(category: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for entry_id: StringName in entries.keys():
		var entry: Dictionary = entries[entry_id]
		if int(entry.get("category", -1)) == category:
			var copy: Dictionary = entry.duplicate(true)
			copy["id"] = String(entry_id)
			out.append(copy)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["title"] < b["title"])
	return out


func clear_all() -> void:
	entries.clear()


func to_dict() -> Dictionary:
	return {"entries": entries.duplicate(true)}


func from_dict(data: Dictionary) -> void:
	entries = (data.get("entries", {}) as Dictionary).duplicate(true)
