class_name TerrainVisual
extends Node2D
## TerrainVisual — a platform drawn in code.
##
## The design rule here is *readability first*: the surface the player lands on
## is the brightest line on screen, and everything below it recedes. If a
## player can misjudge a ledge, no amount of atmosphere is worth it.

var size: Vector2 = Vector2(200, 40)
## Deterministic per-platform variation, so two ledges never look cloned.
var seed: int = 0

var _rng := RandomNumberGenerator.new()
var _cracks: Array[Vector2] = []
var _tufts: Array[Vector2] = []


func setup(surface_size: Vector2, variation_seed: int) -> void:
	size = surface_size
	seed = variation_seed
	_rng.seed = variation_seed
	_scatter()
	z_index = -1
	queue_redraw()


func _scatter() -> void:
	_cracks.clear()
	_tufts.clear()
	# Only wide platforms carry detail; a 40px wall does not need cracks.
	if size.x < 90.0:
		return
	var crack_count: int = int(size.x / 110.0)
	for i: int in range(crack_count):
		_cracks.append(Vector2(_rng.randf_range(0.1, 0.9), _rng.randf_range(0.25, 0.9)))
	var tuft_count: int = int(size.x / 70.0)
	for i: int in range(tuft_count):
		_tufts.append(Vector2(_rng.randf_range(0.05, 0.95), _rng.randf_range(4.0, 9.0)))


func _draw() -> void:
	var top_left: Vector2 = -size * 0.5
	var rect := Rect2(top_left, size)

	# Body: darker toward the bottom, so the platform reads as volume.
	draw_rect(rect, Palette.GROUND.darkened(0.35))
	var band := Rect2(top_left, Vector2(size.x, minf(size.y, 12.0)))
	draw_rect(band, Palette.GROUND)

	# The landing line. Brightest thing in the scene, deliberately.
	draw_line(
		Vector2(top_left.x, top_left.y + 0.5),
		Vector2(top_left.x + size.x, top_left.y + 0.5),
		Palette.GROUND_EDGE, 2.0
	)
	# A soft glow just above the edge makes the silhouette separate from
	# whatever is behind it without costing a light.
	draw_rect(
		Rect2(Vector2(top_left.x, top_left.y - 3.0), Vector2(size.x, 3.0)),
		Color(Palette.GROUND_EDGE.r, Palette.GROUND_EDGE.g, Palette.GROUND_EDGE.b, 0.14)
	)

	# Cracks, deterministic so they never flicker between frames.
	for crack: Vector2 in _cracks:
		var origin: Vector2 = top_left + Vector2(crack.x * size.x, 2.0)
		var points := PackedVector2Array([origin])
		var cursor: Vector2 = origin
		for step: int in range(3):
			cursor += Vector2(_deterministic(step, crack.x) * 7.0, 5.0 + step * 2.0)
			points.append(cursor)
		draw_polyline(points, Palette.NIGHT_FAR, 1.2)

	# Sparse growth: this village has been empty a long time, not forever.
	for tuft: Vector2 in _tufts:
		var base: Vector2 = top_left + Vector2(tuft.x * size.x, 0.0)
		var height: float = tuft.y
		var sway: float = _deterministic(int(tuft.x * 100.0), tuft.y) * 3.0
		draw_line(base, base + Vector2(sway * 0.4, -height), Palette.NIGHTMARE_EDGE.darkened(0.35), 1.1)
		draw_line(base, base + Vector2(sway * 0.4 - 2.0, -height * 0.7), Palette.NIGHTMARE_EDGE.darkened(0.5), 1.0)


## Small stable hash so the scatter is identical every frame without storing
## per-vertex randomness.
func _deterministic(step: int, salt: float) -> float:
	var value: float = sin(float(seed) * 12.9898 + float(step) * 78.233 + salt * 37.719) * 43758.5453
	return (value - floorf(value)) * 2.0 - 1.0
