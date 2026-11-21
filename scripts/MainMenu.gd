extends Control

# Chronoflora - Main Menu

func _on_new_game_pressed():
	get_tree().change_scene_to_file("res://scenes/Game.tscn")

func _on_continue_pressed():
	var save = FileAccess.new()
	if save.file_exists("user://saves/savegame.json"):
		var state = JSON.parse(save.get_as_text()).result
		# Load state into game
		get_tree().change_scene_to_file("res://scenes/Game.tscn")
		# Note: Full state restoration handled by GameManager

func _on_quit_pressed():
	get_tree().quit()
