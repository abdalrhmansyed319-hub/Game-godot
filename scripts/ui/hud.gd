extends CanvasLayer
## HUD — atmospheric but readable (GDD 20).
##
## Shows health, Resonance, Lantern charge, active Echoes, selected ability and
## contextual hunting indicators. Nothing decorative is allowed to obscure
## combat information.

@onready var health_bar: ProgressBar = $Root/TopLeft/HealthBar
@onready var resonance_bar: ProgressBar = $Root/TopLeft/ResonanceBar
@onready var lantern_bar: ProgressBar = $Root/TopLeft/LanternBar
@onready var revelation_label: Label = $Root/TopLeft/RevelationLabel
@onready var echo_row: HBoxContainer = $Root/TopRight/EchoRow
@onready var prompt_label: Label = $Root/BottomCenter/PromptLabel
@onready var message_label: Label = $Root/Center/MessageLabel
@onready var hint_label: Label = $Root/BottomLeft/HintLabel

var player: PlayerController = null
var _message_timer: float = 0.0


func _ready() -> void:
	GameManager.health_changed.connect(_on_health_changed)
	GameManager.resonance_changed.connect(_on_resonance_changed)
	GameManager.lantern_changed.connect(_on_lantern_changed)
	GameManager.revelation_started.connect(_on_revelation_started)
	GameManager.revelation_ended.connect(_on_revelation_ended)
	EchoManager.echo_equipped.connect(func(_id: StringName, _slot: int) -> void: _refresh_echoes())
	EchoManager.echo_collected.connect(func(_id: StringName) -> void: _refresh_echoes())
	_on_health_changed(GameManager.health, GameManager.max_health)
	_on_resonance_changed(GameManager.resonance, GameManager.max_resonance)
	_on_lantern_changed(GameManager.lantern_charge, GameManager.max_lantern)
	_refresh_echoes()
	message_label.text = ""
	hint_label.text = "A/D move   Space jump   J light   K heavy   Shift dash   F lantern   G anchor   R revelation   E interact"


func _process(delta: float) -> void:
	if _message_timer > 0.0:
		_message_timer -= delta
		if _message_timer <= 0.0:
			message_label.text = ""


func bind_player(target: PlayerController) -> void:
	player = target
	if player == null:
		return
	player.interaction_available.connect(_on_interaction_available)
	player.interaction_cleared.connect(_on_interaction_cleared)
	player.resolution_prompt_opened.connect(_on_resolution_prompt)


# --- Bars -------------------------------------------------------------------
func _on_health_changed(current: float, maximum: float) -> void:
	health_bar.max_value = maximum
	health_bar.value = current


func _on_resonance_changed(current: float, maximum: float) -> void:
	resonance_bar.max_value = maximum
	resonance_bar.value = current
	# Contextual hunting indicator (GDD 20): tell the player the opening exists.
	if not revelation_label.text.begins_with("REVELATION —"):
		if current >= 100.0:
			revelation_label.text = "RESONANCE FULL — press R to reveal its true shape"
			revelation_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))
		else:
			revelation_label.text = ""


func _on_lantern_changed(current: float, maximum: float) -> void:
	lantern_bar.max_value = maximum
	lantern_bar.value = current


func _on_revelation_started(_id: StringName, duration: float) -> void:
	revelation_label.text = "REVELATION — its true shape is showing"
	revelation_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))


func _on_revelation_ended(_id: StringName) -> void:
	revelation_label.text = ""


# --- Contextual indicators --------------------------------------------------
func _on_interaction_available(target: Node) -> void:
	if target.has_method("can_interact"):
		prompt_label.text = "[E] %s" % _prompt_for(target)


func _on_interaction_cleared() -> void:
	prompt_label.text = ""


func _prompt_for(target: Node) -> String:
	if target.get("prompt") != null and String(target.get("prompt")) != "":
		return String(target.get("prompt"))
	if target is NightmareBase and target.is_dead:
		return "Decide its fate"
	if target is CheckpointManager:
		return "Rest in the Quiet Room"
	return "Examine"


func _on_resolution_prompt(_nightmare: Node, options: Array[int]) -> void:
	var labels: Array[String] = []
	for index: int in options.size():
		var option: int = options[index]
		labels.append("[%d] %s" % [index + 1, _resolution_label(option)])
	show_message("Choose: " + "   ".join(labels))


func _resolution_label(kind: int) -> String:
	match kind:
		NightmareData.ResolutionKind.DESTROY: return "Destroy"
		NightmareData.ResolutionKind.CAPTURE: return "Capture"
		NightmareData.ResolutionKind.RELEASE: return "Release"
		NightmareData.ResolutionKind.RECONCILE: return "Reconcile"
	return "?"


func _unhandled_input(event: InputEvent) -> void:
	if player == null or player.pending_resolution == null:
		return
	for index: int in range(4):
		if event is InputEventKey and (event as InputEventKey).pressed:
			if (event as InputEventKey).keycode == KEY_1 + index:
				player.choose_resolution(index)


# --- Echo slots -------------------------------------------------------------
func _refresh_echoes() -> void:
	for child: Node in echo_row.get_children():
		child.queue_free()
	for data: EchoData in EchoManager.active_echoes():
		var slot := ColorRect.new()
		slot.color = data.tint
		slot.custom_minimum_size = Vector2(22, 22)
		slot.tooltip_text = data.display_name
		echo_row.add_child(slot)


func show_message(text: String, duration: float = 4.0) -> void:
	message_label.text = text
	_message_timer = duration
