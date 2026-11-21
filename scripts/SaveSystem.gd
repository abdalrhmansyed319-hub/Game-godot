extends Node

# Chronoflora - SaveSystem
# Handles save/load of game state using JSON.

var save_dir = "user://saves/"
var save_file = "user://saves/savegame.json"

func _ready():
	DirAccess.make_dir_recursive_absolute(save_dir)

func save_exists():
	var f = FileAccess.new()
	return f.file_exists(save_file)

func save_game(state: Dictionary):
	var f = FileAccess.new()
	f.open(save_file, FileAccess.WRITE)
	f.store_string(JSON.stringify(state, "  "))
	f.close()

func load_game():
	var f = FileAccess.new()
	if not f.file_exists(save_file):
		return null
	f.open(save_file, FileAccess.READ)
	var content = f.get_as_text()
	f.close()
	return JSON.parse(content).result
