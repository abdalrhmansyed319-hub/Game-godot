class_name DreamSky
extends Node2D
## DreamSky — the atmosphere of the Hollow Village, drawn in code.
##
## Four layers at different scroll rates, and one rule: the further away
## something is, the closer its colour sits to the void. That is what makes a
## 2D scene read as deep without a single texture.
##
## Every element here is deterministic or slowly drifting. Nothing flashes,
## because a background that competes with the player for attention is a
## background that makes the game harder to read.

enum Layer { VOID, FAR, NEAR, FOG }

var layer: int = Layer.VOID
var span: Vector2 = Vector2(5200, 1400)
var seed: int = 7

var _time: float = 0.0
var _rng := RandomNumberGenerator.new()
var _spires: Array[Dictionary] = []
var _motes: Array[Dictionary] = []
var _windows: Array[Dictionary] = []
var _sky_texture: GradientTexture2D = null


func setup(target_layer: int, world_span: Vector2, variation_seed: int = 7) -> void:
	layer = target_layer
	span = world_span
	seed = variation_seed
	_rng.seed = variation_seed
	_build()
	z_index = -40 + layer * 2
	if layer == Layer.FOG:
		set_process(true)
	else:
		set_process(false)


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _build() -> void:
	match layer:
		Layer.VOID:
			_sky_texture = _make_sky()
		Layer.FAR:
			for i: int in range(11):
				_spires.append({
					"x": -300.0 + float(i) * (span.x / 10.0) + _rng.randf_range(-60.0, 60.0),
					"w": _rng.randf_range(70.0, 150.0),
					"h": _rng.randf_range(240.0, 520.0),
				})
		Layer.NEAR:
			for i: int in range(7):
				_spires.append({
					"x": -200.0 + float(i) * (span.x / 6.0) + _rng.randf_range(-90.0, 90.0),
					"w": _rng.randf_range(90.0, 190.0),
					"h": _rng.randf_range(150.0, 320.0),
				})
			# A few lit windows. Warm light in a dead village is the story.
			for i: int in range(14):
				_windows.append({
					"x": _rng.randf_range(0.0, span.x),
					"y": _rng.randf_range(-360.0, -140.0),
					"w": _rng.randf_range(5.0, 9.0),
					"phase": _rng.randf_range(0.0, TAU),
				})
		Layer.FOG:
			for i: int in range(46):
				_motes.append({
					"x": _rng.randf_range(-200.0, span.x + 200.0),
					"y": _rng.randf_range(-520.0, 40.0),
					"r": _rng.randf_range(0.8, 2.4),
					"speed": _rng.randf_range(4.0, 16.0),
					"drift": _rng.randf_range(0.0, TAU),
				})


func _draw() -> void:
	match layer:
		Layer.VOID: _draw_void()
		Layer.FAR: _draw_spires(Palette.NIGHT_FAR, 0.0)
		Layer.NEAR: _draw_near()
		Layer.FOG: _draw_motes()


func _draw_void() -> void:
	if _sky_texture == null:
		return
	draw_texture_rect(_sky_texture, Rect2(Vector2(-600, -1100), span + Vector2(1200, 1500)), false)
	# The Bell hangs in the distance. It is never explained here; it is simply
	# always present, which is how a place gets a reputation.
	var bell := Vector2(span.x * 0.72, -760.0)
	draw_circle(bell, 46.0, Color(Palette.NIGHT_MID.r, Palette.NIGHT_MID.g, Palette.NIGHT_MID.b, 0.55))
	draw_line(bell + Vector2(-46, -10), bell + Vector2(46, -10), Color(Palette.NIGHT_NEAR.r, Palette.NIGHT_NEAR.g, Palette.NIGHT_NEAR.b, 0.6), 3.0)
	draw_line(bell, bell + Vector2(0, -120), Color(Palette.NIGHT_NEAR.r, Palette.NIGHT_NEAR.g, Palette.NIGHT_NEAR.b, 0.35), 2.0)


func _draw_spires(tint: Color, _unused: float) -> void:
	for spire: Dictionary in _spires:
		var origin := Vector2(float(spire["x"]), 60.0)
		var width: float = float(spire["w"])
		var height: float = float(spire["h"])
		var points := PackedVector2Array([
			origin + Vector2(-width * 0.5, 0),
			origin + Vector2(-width * 0.32, -height),
			origin + Vector2(width * 0.32, -height),
			origin + Vector2(width * 0.5, 0),
		])
		draw_colored_polygon(points, tint)
		# Roofline, slightly lighter: enough to separate overlapping towers.
		draw_polyline(
			PackedVector2Array([
				origin + Vector2(-width * 0.32, -height),
				origin + Vector2(0, -height - 22.0),
				origin + Vector2(width * 0.32, -height),
			]),
			tint.lightened(0.22), 1.4
		)


func _draw_near() -> void:
	_draw_spires(Palette.NIGHT_NEAR, 0.0)
	for window: Dictionary in _windows:
		var position := Vector2(float(window["x"]), float(window["y"]))
		var width: float = float(window["w"])
		# Windows breathe. A slow flicker reads as a lamp, not a light bulb.
		var glow: float = 0.42 + sin(_time * 1.1 + float(window["phase"])) * 0.1
		draw_rect(
			Rect2(position, Vector2(width, width * 1.5)),
			Color(Palette.LANTERN.r, Palette.LANTERN.g, Palette.LANTERN.b, glow)
		)


## Slow dust. This is the cheapest thing in the scene that makes a static
## 2D world feel like it has air in it.
func _draw_motes() -> void:
	for mote: Dictionary in _motes:
		var base := Vector2(float(mote["x"]), float(mote["y"]))
		var offset := Vector2(
			sin(_time * 0.23 + float(mote["drift"])) * 26.0,
			-_time * float(mote["speed"]) * 0.35
		)
		var position: Vector2 = base + offset
		# Wrap vertically so the motes never run out.
		position.y = fposmod(position.y + 560.0, 620.0) - 560.0
		var alpha: float = 0.10 + sin(_time * 0.7 + float(mote["drift"])) * 0.05
		draw_circle(position, float(mote["r"]), Color(Palette.LANTERN.r, Palette.LANTERN.g, Palette.LANTERN.b, alpha))


func _make_sky() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Palette.VOID)
	gradient.add_point(0.55, Palette.NIGHT_FAR)
	gradient.set_color(1, Palette.NIGHT_MID.darkened(0.35))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 8
	texture.height = 256
	texture.fill = GradientTexture2D.FILL_LINEAR
	texture.fill_from = Vector2(0.5, 0.0)
	texture.fill_to = Vector2(0.5, 1.0)
	return texture
