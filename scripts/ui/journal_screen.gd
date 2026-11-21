extends Control
## JournalScreen — the Hunter's Journal (GDD 17).
##
## Only what the player has actually discovered appears here. Information is
## earned, never handed over.

@onready var category_list: ItemList = $HSplit/Categories
@onready var entry_list: ItemList = $HSplit/Entries
@onready var body_text: RichTextLabel = $HSplit/Body
@onready var back_button: Button = $BackButton

var _selected_category: int = -1


func _ready() -> void:
	back_button.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/main/main_menu.tscn"))
	category_list.item_selected.connect(_on_category_selected)
	entry_list.item_selected.connect(_on_entry_selected)
	_populate_categories()
	if category_list.item_count > 0:
		category_list.select(0)
		_on_category_selected(0)


func _populate_categories() -> void:
	category_list.clear()
	var categories: Array[int] = [
		JournalManager.Category.NIGHTMARE,
		JournalManager.Category.WEAKNESS,
		JournalManager.Category.CHARACTER,
		JournalManager.Category.MEMORY,
		JournalManager.Category.OBSERVATION,
		JournalManager.Category.QUEST,
		JournalManager.Category.REGION,
		JournalManager.Category.DECISION,
		JournalManager.Category.MYSTERY,
	]
	for category: int in categories:
		var entries: Array[Dictionary] = JournalManager.entries_in_category(category)
		category_list.add_item("%s (%d)" % [JournalManager.category_name(category), entries.size()])
		category_list.set_item_metadata(category_list.item_count - 1, category)


func _on_category_selected(index: int) -> void:
	_selected_category = int(category_list.get_item_metadata(index))
	entry_list.clear()
	for entry: Dictionary in JournalManager.entries_in_category(_selected_category):
		entry_list.add_item(String(entry["title"]))
		entry_list.set_item_metadata(entry_list.item_count - 1, String(entry["id"]))
	if entry_list.item_count > 0:
		entry_list.select(0)
		_on_entry_selected(0)
	else:
		body_text.text = "Nothing recorded here yet. Discoveries are written down, not given."


func _on_entry_selected(index: int) -> void:
	var entry_id := StringName(String(entry_list.get_item_metadata(index)))
	if not JournalManager.has_entry(entry_id):
		return
	var entry: Dictionary = JournalManager.entries[entry_id]
	body_text.text = "%s\n\n%s\n\n— recorded %s" % [
		String(entry["title"]),
		String(entry["body"]),
		String(entry["discovered_at"]),
	]
	JournalManager.mark_read(entry_id)
