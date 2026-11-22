extends Control
## MainMenu — title screen with the two things a prototype needs: play, and
## open the Hunter's Journal.


func _ready() -> void:
	$VBox/PlayButton.pressed.connect(_on_play)
	$VBox/JournalButton.pressed.connect(_on_journal)
	$VBox/QuitButton.pressed.connect(func() -> void: get_tree().quit())
	$VBox/Title.text = "NIGHTMARE HUNTER"
	$VBox/Subtitle.text = "Every nightmare is a creature to fight, a mystery to investigate, and a story to understand."
	# The jam requires the game to be fully playable with keyboard and mouse.
	# Without an initial focus owner the menu can only be used with the mouse,
	# so the first button takes focus and Tab walks the rest.
	$VBox/PlayButton.grab_focus()


func _on_play() -> void:
	get_tree().change_scene_to_file("res://scenes/world/region_hollow_village.tscn")


func _on_journal() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/journal_screen.tscn")
