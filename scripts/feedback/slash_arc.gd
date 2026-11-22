class_name SlashArc
extends Node2D
## SlashArc — the blade's swing, drawn procedurally.
##
## An attack needs to be *seen*, not just heard. This draws a tapered arc that
## sweeps and fades over a few frames. It is the single most important piece of
## combat readability: telegraphs and swings use the same visual language.

const ARC_RADIUS: float = 46.0
const ARC_WIDTH: float = 13.0

var color: Color = Palette.BLADE_TRAIL
var progress: float = 0.0
var duration: float = 0.14
var facing: float = 1.0
var sweep_start: float = -0.9
var sweep_end: float = 0.9
var radius_scale: float = 1.0


func _ready() -> void:
	z_index = 30


func _process(delta: float) -> void:
	progress += delta
	queue_redraw()
	if progress >= duration:
		queue_free()


static func spawn(
	host: Node,
	at: Vector2,
	direction: float,
	tint: Color,
	duration: float = 0.14,
	radius_scale: float = 1.0
) -> SlashArc:
	var arc := SlashArc.new()
	arc.global_position = at
	arc.facing = direction
	arc.color = tint
	arc.duration = maxf(0.05, duration)
	arc.radius_scale = radius_scale
	host.add_child(arc)
	return arc


func _draw() -> void:
	var t: float = clampf(progress / duration, 0.0, 1.0)
	# Ease out so the swing starts fast and settles.
	var eased: float = 1.0 - pow(1.0 - t, 2.4)
	var alpha: float = (1.0 - t) * 0.9
	if alpha <= 0.01:
		return

	var start_angle: float = sweep_start + (sweep_end - sweep_start) * 0.0
	var current_angle: float = sweep_start + (sweep_end - sweep_start) * eased
	var radius: float = ARC_RADIUS * radius_scale

	var points := PackedVector2Array()
	var steps: int = 12
	for i: int in range(steps + 1):
		var f: float = float(i) / float(steps)
		var angle: float = lerpf(start_angle, current_angle, f)
		# Taper: widest in the middle of the sweep.
		var taper: float = sin(f * PI) * 0.75 + 0.35
		var r: float = radius * taper
		points.append(Vector2(cos(angle), sin(angle)) * r * Vector2(facing, 1.0))
	# Close the shape back along the inner edge so the arc has thickness.
	for i: int in range(steps, -1, -1):
		var f: float = float(i) / float(steps)
		var angle: float = lerpf(start_angle, current_angle, f)
		var taper: float = sin(f * PI) * 0.75 + 0.35
		var r: float = maxf(3.0, radius * taper - ARC_WIDTH * taper)
		points.append(Vector2(cos(angle), sin(angle)) * r * Vector2(facing, 1.0))

	if points.size() < 3:
		return
	draw_colored_polygon(points, Color(color.r, color.g, color.b, alpha))
