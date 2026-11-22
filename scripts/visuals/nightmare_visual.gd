class_name NightmareVisual
extends Node2D
## NightmareVisual — enemy silhouettes, drawn in code.
##
## Each category gets a genuinely different outline, because the design rule is
## that no two enemies are the same shape with a different colour. A player
## should be able to name the threat from its outline alone at a glance, which
## is the whole basis of readable combat.
##
## The revealed core uses the reserved gold. When gold appears, it means real.

var nightmare: NightmareBase = null
var ai: NightmareAI = null

var _time: float = 0.0
var _facing: float = 1.0
var _hurt_flash: float = 0.0
var _glow: GradientTexture2D = null
var _telegraph_amount: float = 0.0


func _ready() -> void:
	z_index = 8
	_glow = _make_glow()


func bind(target: NightmareBase) -> void:
	nightmare = target
	if target != null:
		ai = target.get_node_or_null("AI") as NightmareAI


func _process(delta: float) -> void:
	if nightmare == null:
		return
	_time += delta
	_hurt_flash = maxf(0.0, _hurt_flash - delta * 5.0)
	if ai != null:
		_facing = ai.facing
		# The telegraph is drawn as part of the creature, not as a separate
		# widget, so the warning and the threat are the same object.
		_telegraph_amount = 1.0 if ai.is_telegraphing else lerpf(_telegraph_amount, 0.0, delta * 12.0)
	queue_redraw()


func flash() -> void:
	_hurt_flash = 1.0


func _draw() -> void:
	if nightmare == null or nightmare.data == null:
		return
	var body: Color = nightmare.data.body_color
	var revealed: bool = nightmare.is_revealed
	if revealed:
		body = body.lerp(nightmare.data.revealed_color, 0.55)
	if _hurt_flash > 0.0:
		body = body.lerp(Palette.HURT_FLASH, _hurt_flash * 0.9)

	var hover: float = sin(_time * 2.4) * 2.0
	_draw_aura(body, revealed)

	match nightmare.data.category:
		NightmareData.Category.WARDEN: _draw_warden(body, hover)
		NightmareData.Category.MIMIC: _draw_mimic(body, hover)
		NightmareData.Category.FRAGMENTED: _draw_fragmented(body, hover)
		NightmareData.Category.STALKER: _draw_stalker(body, hover)
		NightmareData.Category.HUNTER: _draw_hunter(body, hover)
		NightmareData.Category.DISTORTER: _draw_distorter(body, hover)
		NightmareData.Category.MEMORY_EATER: _draw_memory_eater(body, hover)

	_draw_telegraph()
	_draw_core(revealed)


## Called by NightmareBase when damage lands.
func flash() -> void:
	_hurt_flash = 1.0


## Soft mass behind the creature so it separates from the background.
func _draw_aura(body: Color, revealed: bool) -> void:
	if _glow == null:
		return
	var tint: Color = nightmare.data.revealed_color if revealed else body
	var size: float = 76.0 + (14.0 if revealed else 0.0)
	draw_texture_rect(
		_glow,
		Rect2(Vector2(-size * 0.5, -size * 0.62), Vector2(size, size)),
		false,
		Color(tint.r, tint.g, tint.b, 0.32 if revealed else 0.2)
	)


# --- Warden: broad, low, shielded. Holds ground. ----------------------------
func _draw_warden(body: Color, hover: float) -> void:
	var points := PackedVector2Array([
		Vector2(-17, 2), Vector2(-19, -22), Vector2(-9, -34),
		Vector2(9, -34), Vector2(19, -22), Vector2(17, 2),
	])
	draw_colored_polygon(points, body.darkened(0.3))
	# Shield on the facing side: tells the player which way it is armoured.
	var shield := PackedVector2Array([
		Vector2(_facing * 12, -30), Vector2(_facing * 22, -20),
		Vector2(_facing * 22, -4), Vector2(_facing * 12, 0),
	])
	draw_colored_polygon(shield, body.lightened(0.12))
	draw_polyline(shield, Palette.NIGHTMARE_EDGE, 1.5)
	# Two low eyes, close together. Slow blink.
	var blink: float = 1.0 if fmod(_time, 4.0) > 0.15 else 0.15
	draw_circle(Vector2(_facing * 3 - 4, -24 + hover * 0.3), 2.0, Color(1, 0.9, 0.7, blink))
	draw_circle(Vector2(_facing * 3 + 4, -24 + hover * 0.3), 2.0, Color(1, 0.9, 0.7, blink))


# --- Mimic: almost human. That is the threat. -------------------------------
func _draw_mimic(body: Color, hover: float) -> void:
	# Upright, proportioned like a person, but slightly wrong: too still, and
	# the outline flickers between shapes while unrevealed.
	var flicker: float = 0.0 if nightmare.is_revealed else (1.0 if fmod(_time * 6.0, 1.0) < 0.12 else 0.0)
	var head_r: float = 6.0 + flicker * 1.5
	draw_circle(Vector2(0, -34 + hover), head_r, body.lightened(0.18))
	var torso := PackedVector2Array([
		Vector2(-7, -28 + hover), Vector2(7, -28 + hover),
		Vector2(6, -8 + hover), Vector2(-6, -8 + hover),
	])
	draw_colored_polygon(torso, body)
	draw_line(Vector2(-3, -8 + hover), Vector2(-4, 2), body.darkened(0.35), 3.0)
	draw_line(Vector2(3, -8 + hover), Vector2(4, 2), body.darkened(0.35), 3.0)
	# Arms held slightly out, as if mid-gesture. Unsettling on purpose.
	draw_line(Vector2(-7, -26 + hover), Vector2(-13, -14 + hover), body.darkened(0.2), 2.6)
	draw_line(Vector2(7, -26 + hover), Vector2(13, -14 + hover), body.darkened(0.2), 2.6)
	# No face until revealed.
	if not nightmare.is_revealed:
		draw_circle(Vector2(_facing * 2, -35 + hover), 1.6, Color(0.05, 0.04, 0.09))


# --- Fragmented: a cluster, never one shape. --------------------------------
func _draw_fragmented(body: Color, hover: float) -> void:
	for i: int in range(4):
		var angle: float = _time * 1.1 + float(i) * TAU / 4.0
		var offset: Vector2 = Vector2(cos(angle), sin(angle) * 0.55) * 13.0
		var size: float = 8.0 - float(i) * 1.1
		var points := PackedVector2Array()
		for k: int in range(5):
			var a: float = float(k) * TAU / 5.0 + _time * 0.6
			points.append(offset + Vector2(cos(a), sin(a)) * size + Vector2(0, -18 + hover))
		draw_colored_polygon(points, body.lightened(0.05 * float(i)))
	# A thread connecting the pieces: they are one creature, and it matters.
	for i: int in range(4):
		var a1: float = _time * 1.1 + float(i) * TAU / 4.0
		var a2: float = _time * 1.1 + float(i + 1) * TAU / 4.0
		draw_line(
			Vector2(cos(a1), sin(a1) * 0.55) * 13.0 + Vector2(0, -18 + hover),
			Vector2(cos(a2), sin(a2) * 0.55) * 13.0 + Vector2(0, -18 + hover),
			Color(body.r, body.g, body.b, 0.4), 1.0
		)


# --- Stalker: tall, thin, trailing. -----------------------------------------
func _draw_stalker(body: Color, hover: float) -> void:
	var points := PackedVector2Array([
		Vector2(-5, 4), Vector2(-8, -26 + hover), Vector2(0, -40 + hover),
		Vector2(8, -26 + hover), Vector2(5, 4),
	])
	draw_colored_polygon(points, body.darkened(0.2))
	# Trails upward like smoke being pulled the wrong way.
	for i: int in range(3):
		var sway: float = sin(_time * 2.0 + float(i)) * 4.0
		draw_line(
			Vector2(-3 + float(i) * 3, -26 + hover),
			Vector2(-3 + float(i) * 3 + sway, -48 - float(i) * 5 + hover),
			Color(body.r, body.g, body.b, 0.35), 1.4
		)
	draw_circle(Vector2(_facing * 2, -32 + hover), 2.2, Palette.TELEGRAPH.darkened(0.2))


# --- Hunter: leaning forward, built to chase. -------------------------------
func _draw_hunter(body: Color, hover: float) -> void:
	var lean: float = _facing * 6.0
	var points := PackedVector2Array([
		Vector2(-lean * 0.5 - 8, 2), Vector2(-lean - 6, -20 + hover),
		Vector2(lean - 2, -30 + hover), Vector2(lean + 10, -16 + hover),
		Vector2(lean * 0.5 + 8, 2),
	])
	draw_colored_polygon(points, body)
	# Head low and forward.
	draw_circle(Vector2(lean + 6, -24 + hover), 6.0, body.lightened(0.2))
	draw_circle(Vector2(lean + 9, -25 + hover), 1.8, Palette.TELEGRAPH)


# --- Distorter: heavy, floating, wrong in the middle. ------------------------
func _draw_distorter(body: Color, hover: float) -> void:
	var points := PackedVector2Array()
	for i: int in range(9):
		var a: float = float(i) * TAU / 9.0
		var wobble: float = 1.0 + sin(_time * 1.6 + float(i) * 1.3) * 0.16
		points.append(Vector2(cos(a), sin(a) * 0.8) * 22.0 * wobble + Vector2(0, -22 + hover))
	draw_colored_polygon(points, body.darkened(0.25))
	draw_polyline(points, Palette.NIGHTMARE_EDGE, 1.2)
	# Space bends around it: concentric rings that drift.
	for i: int in range(3):
		var r: float = 28.0 + float(i) * 7.0 + sin(_time * 1.2 + float(i)) * 3.0
		draw_arc(Vector2(0, -22 + hover), r, 0.0, TAU, 24, Color(body.r, body.g, body.b, 0.22), 1.0)


# --- Memory Eater: open, grasping, hollow. ----------------------------------
func _draw_memory_eater(body: Color, hover: float) -> void:
	draw_circle(Vector2(0, -22 + hover), 15.0, body.darkened(0.35))
	# A mouth that is too large for the body. It eats resources, not flesh.
	draw_circle(Vector2(_facing * 4, -22 + hover), 8.0, Color(0.03, 0.025, 0.06))
	for i: int in range(5):
		var a: float = -0.9 + float(i) * 0.45
		var base: Vector2 = Vector2(cos(a), sin(a)) * 8.0 + Vector2(_facing * 4, -22 + hover)
		var tip: Vector2 = Vector2(cos(a), sin(a)) * 13.0 + Vector2(_facing * 4, -22 + hover)
		draw_line(base, tip, body.lightened(0.25), 1.6)


## The readable warning before an attack lands.
func _draw_telegraph() -> void:
	if _telegraph_amount <= 0.02 or nightmare.data == null:
		return
	var reach: float = nightmare.data.attack_range
	var tint: Color = nightmare.data.telegraph_color
	var alpha: float = _telegraph_amount * 0.5
	# A wedge on the ground in the direction of the swing: unmistakable, and it
	# communicates reach as well as timing.
	var wedge := PackedVector2Array([
		Vector2(0, 0),
		Vector2(_facing * reach, -16.0),
		Vector2(_facing * reach, 4.0),
	])
	draw_colored_polygon(wedge, Color(tint.r, tint.g, tint.b, alpha))
	draw_line(Vector2(0, -22), Vector2(_facing * reach, -22), Color(tint.r, tint.g, tint.b, alpha * 1.4), 2.0)


## The revealed vulnerability. Reserved gold, and only here.
func _draw_core(revealed: bool) -> void:
	if not revealed:
		return
	var pulse: float = 1.0 + sin(_time * 7.0) * 0.18
	draw_circle(Vector2(0, -22), 7.0 * pulse, Palette.TRUTH_CORE)
	draw_circle(Vector2(0, -22), 12.0 * pulse, Color(Palette.TRUTH.r, Palette.TRUTH.g, Palette.TRUTH.b, 0.28))


func _make_glow() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 0.5))
	gradient.set_color(1, Color(1, 1, 1, 0.0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 64
	texture.height = 64
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(0.5, 0.0)
	return texture
