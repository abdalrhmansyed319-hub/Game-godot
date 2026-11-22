class_name PropVisual
extends Node2D
## PropVisual — the interactive objects of the village, drawn in code.
##
## One rule governs all of them: **a thing you can interact with must be
## findable by eye.** So every prop carries its own small light. In a dream
## this dark, "glowing" and "important" are the same word, and the game should
## use that honestly rather than hiding content behind invisible triggers.

enum Kind { QUIET_ROOM, MEMORY, MECHANISM, HIDDEN }

var kind: int = Kind.QUIET_ROOM
var revealed: bool = false

var _time: float = 0.0
var _glow: GradientTexture2D = null


func _ready() -> void:
	_glow = _make_glow()
	z_index = 2


func setup(prop_kind: int, is_revealed: bool = false) -> void:
	kind = prop_kind
	revealed = is_revealed
	# A hidden passage draws nothing until it is found.
	visible = kind != Kind.HIDDEN or is_revealed
	queue_redraw()


func set_revealed(value: bool) -> void:
	revealed = value
	if kind == Kind.HIDDEN:
		visible = value
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	match kind:
		Kind.QUIET_ROOM: _draw_quiet_room()
		Kind.MEMORY: _draw_memory()
		Kind.MECHANISM: _draw_mechanism()
		Kind.HIDDEN: _draw_hidden()


func _glow_at(center: Vector2, radius: float, tint: Color, alpha: float) -> void:
	if _glow == null:
		return
	var size: Vector2 = Vector2.ONE * radius
	draw_texture_rect(
		_glow, Rect2(center - size * 0.5, size), false, Color(tint.r, tint.g, tint.b, alpha)
	)


## The Quiet Room: a doorway with a lamp and no house behind it.
func _draw_quiet_room() -> void:
	var flicker: float = 1.0 + sin(_time * 3.3) * 0.06
	_glow_at(Vector2(0, -46), 130.0 * flicker, Palette.LANTERN, 0.30)

	# Doorframe.
	draw_rect(Rect2(Vector2(-22, -70), Vector2(44, 70)), Palette.NIGHT_NEAR.darkened(0.3))
	draw_rect(Rect2(Vector2(-22, -70), Vector2(44, 70)), Palette.GROUND_EDGE, false, 2.0)
	# The doorway itself: pure void. Nothing is behind it, and that is the point.
	draw_rect(Rect2(Vector2(-16, -64), Vector2(32, 64)), Palette.VOID)
	# The lamp, hanging in the empty space.
	var lamp := Vector2(0, -50)
	draw_line(lamp + Vector2(0, -14), lamp + Vector2(0, -5), Palette.CLOAK_LIT, 1.5)
	draw_rect(Rect2(lamp - Vector2(4, 4), Vector2(8, 10)), Palette.LANTERN)
	draw_rect(Rect2(lamp - Vector2(4, 4), Vector2(8, 10)), Palette.LANTERN.darkened(0.35), false, 1.0)
	# Warm spill on the threshold: this place is safe, and you should feel it.
	draw_rect(Rect2(Vector2(-16, -4), Vector2(32, 4)), Color(Palette.LANTERN.r, Palette.LANTERN.g, Palette.LANTERN.b, 0.22))


## A memory fragment: a page, or an object, holding still in the air.
func _draw_memory() -> void:
	var bob: float = sin(_time * 1.6) * 3.0
	# Gold, and only gold: a memory fragment is revealed truth by definition.
	_glow_at(Vector2(0, -24 + bob), 78.0, Palette.TRUTH, 0.26)
	var page := PackedVector2Array([
		Vector2(-7, -32 + bob), Vector2(7, -34 + bob),
		Vector2(8, -16 + bob), Vector2(-6, -14 + bob),
	])
	draw_colored_polygon(page, Palette.TRUTH_CORE.darkened(0.1))
	draw_polyline(page, Palette.TRUTH, 1.2)
	# Writing. Not legible at this size, and it does not need to be.
	for i: int in range(3):
		var y: float = -30.0 + float(i) * 5.0 + bob
		draw_line(Vector2(-4, y), Vector2(4 - float(i) * 1.5, y - 0.4), Palette.NIGHTMARE_DARK, 1.0)


## Boards over a cellar stair. Breakable, and it looks breakable.
func _draw_mechanism() -> void:
	_glow_at(Vector2(0, -20), 60.0, Palette.LANTERN, 0.12)
	for i: int in range(4):
		var y: float = -38.0 + float(i) * 10.0
		draw_rect(Rect2(Vector2(-14, y), Vector2(28, 7)), Palette.GROUND.darkened(0.15))
		draw_rect(Rect2(Vector2(-14, y), Vector2(28, 7)), Palette.GROUND_EDGE.darkened(0.2), false, 1.0)
	# Nails. They are on the outside, which is the detail the writing refers to.
	for i: int in range(4):
		var y: float = -35.0 + float(i) * 10.0
		draw_circle(Vector2(-11, y), 1.1, Palette.CLOAK_LIT)
		draw_circle(Vector2(11, y), 1.1, Palette.CLOAK_LIT)


## Found: the passage opens, and the gold says so.
func _draw_hidden() -> void:
	if not revealed:
		return
	_glow_at(Vector2(0, -24), 96.0, Palette.TRUTH, 0.24)
	draw_rect(Rect2(Vector2(-16, -48), Vector2(32, 48)), Palette.VOID)
	draw_rect(Rect2(Vector2(-16, -48), Vector2(32, 48)), Palette.TRUTH, false, 1.6)


func _make_glow() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 0.55))
	gradient.set_color(1, Color(1, 1, 1, 0.0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 64
	texture.height = 64
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(0.5, 0.0)
	return texture
