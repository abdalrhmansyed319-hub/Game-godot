extends Node
## Boot — initialises systems then hands off to the main menu (GDD 21: Main).


func _ready() -> void:
	# NightmareDatabase is an autoload, so content is already loaded. Log it so
	# a missing data folder is obvious immediately rather than silently empty.
	print(
		"[Nightmare Hunter] content loaded: %d nightmares, %d echoes, %d weapon forms, %d skills, %d quests"
		% [
			NightmareDatabase.all_nightmares().size(),
			NightmareDatabase.all_echoes().size(),
			NightmareDatabase.all_weapons().size(),
			NightmareDatabase.skills.size(),
			NightmareDatabase.quests.size(),
		]
	)
	if SaveManager.has_save(0):
		SaveManager.load_game(0)
	await get_tree().process_frame
	get_tree().change_scene_to_file("res://scenes/main/main_menu.tscn")
