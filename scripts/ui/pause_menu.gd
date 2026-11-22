class_name PauseMenu
extends CanvasLayer
## PauseMenu — pause, and the settings that control game feel.
##
## Built in code rather than as a scene: it is a handful of controls, and
## keeping it here means the comfort options live next to the code that
## consumes them instead of behind a node path that can silently break.
##
## Everything on this screen is reachable with the mouse *and* the keyboard,
## because the jam requires the game to be fully playable with both.

const OPTION_FONT_SIZE: int = 15

var _panel: PanelContainer = null
var _rows: Dictionary = {}
var _resume_button: Button = null


func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause"):
		toggle()
		get_viewport().set_input_as_handled()


func toggle() -> void:
	if visible:
		close()
	else:
		open()


func open() -> void:
	visible = true
	get_tree().paused = true
	if _resume_button != null:
		_resume_button.grab_focus()


func close() -> void:
	visible = false
	get_tree().paused = false


# --- Construction -----------------------------------------------------------
func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.04, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.custom_minimum_size = Vector2(460, 0)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var style := StyleBoxFlat.new()
	style.bg_color = Palette.UI_BG
	style.border_color = Palette.UI_EDGE
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.set_content_margin_all(22)
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 9)
	_panel.add_child(column)

	_add_title(column, "PAUSED")
	_add_spacer(column)

	_resume_button = _add_button(column, "Resume", close)
	_add_button(column, "Return to title", _quit_to_title)

	_add_spacer(column)
	_add_title(column, "COMFORT")
	_add_toggle(column, "screen_shake", "Screen shake", "screen_shake")
	_add_toggle(column, "hit_stop", "Hit stop", "hit_stop")
	_add_toggle(column, "allow_flashes", "Screen flashes", "allow_flashes")
	_add_toggle(column, "use_mouse_to_aim", "Aim with the mouse", "use_mouse_to_aim")

	_add_spacer(column)
	_add_title(column, "VISUALS")
	_add_option(column, "particle_quality", "Particle quality", ["Low", "Medium", "High"], "particle_quality")

	_add_spacer(column)
	_add_title(column, "AUDIO")
	_add_slider(column, "master", "Master volume", "master")
	_add_slider(column, "sfx", "Effects volume", "sfx")
	_add_slider(column, "music", "Music volume", "music")

	_add_spacer(column)
	_add_label(column, "Esc closes this menu. Every option saves immediately.", Palette.UI_TEXT_DIM)


func _add_title(parent: Control, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Palette.LANTERN)
	parent.add_child(label)


func _add_label(parent: Control, text: String, tint: Color) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", tint)
	parent.add_child(label)


func _add_spacer(parent: Control) -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	parent.add_child(spacer)


func _add_button(parent: Control, text: String, handler: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_size_override("font_size", OPTION_FONT_SIZE)
	button.focus_mode = Control.FOCUS_ALL
	# An empty Callable means the caller connects its own handler afterwards.
	if handler.is_valid():
		button.pressed.connect(handler)
	parent.add_child(button)
	return button


## Note on construction order: GDScript captures lambda variables by value at
## creation time, so a lambda cannot reference the button it is being passed
## to. The handler is therefore connected *after* the button exists.
func _add_toggle(parent: Control, row_id: String, text: String, setting: String) -> void:
	var button := _add_button(parent, _toggle_text(text, setting), Callable())
	button.pressed.connect(func() -> void:
		Settings.set(setting, not bool(Settings.get(setting)))
		Settings.save_to_disk()
		button.text = _toggle_text(text, setting)
	)
	_rows[row_id] = button


func _add_option(parent: Control, row_id: String, text: String, labels: Array, setting: String) -> void:
	var button := _add_button(parent, _option_text(text, labels, setting), Callable())
	button.pressed.connect(func() -> void:
		var next: int = (int(Settings.get(setting)) + 1) % labels.size()
		Settings.set(setting, next)
		Settings.save_to_disk()
		button.text = _option_text(text, labels, setting)
	)
	_rows[row_id] = button


func _toggle_text(text: String, setting: String) -> String:
	return "%s: %s" % [text, _on_off(Settings.get(setting))]


func _option_text(text: String, labels: Array, setting: String) -> String:
	return "%s: %s" % [text, labels[int(Settings.get(setting))]]


func _add_slider(parent: Control, row_id: String, text: String, setting: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	parent.add_child(row)

	var label := Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(150, 0)
	label.add_theme_font_size_override("font_size", OPTION_FONT_SIZE)
	label.add_theme_color_override("font_color", Palette.UI_TEXT)
	row.add_child(label)

	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value = float(Settings.get(setting))
	slider.value_changed.connect(func(value: float) -> void:
		Settings.set(setting, value)
		Settings.save_to_disk()
		Settings.apply_audio_volumes()
	)
	row.add_child(slider)
	_rows[row_id] = slider


func _on_off(value: Variant) -> String:
	return "On" if bool(value) else "Off"


func _quit_to_title() -> void:
	close()
	GameManager.return_to_title()
