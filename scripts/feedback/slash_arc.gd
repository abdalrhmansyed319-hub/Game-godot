class_name SlashArc
extends Node2D
## SlashArc — the blade's swing, drawn procedurally.
##
## An attack needs to be *seen*, not just heard. This draws a tapered arc that
## sweeps and fades over a few frames. It is the single most important piece of
## combat readability: telegraphs and swings use the same visual language.
##
## The arc is oriented by a direction *vector* rather than a sign, so a swing
## can point up, down or sideways. Facing alone cannot express an aerial slam.

const ARC_RADIUS: float = 46.0
const ARC_WIDTH: float = 13.0
const ARC_STEPS: int = 12

var color: Color = Palette.BLADE_TRAIL
var progress: float = 0.0
var duration: float = 0.14
## Base angle of the swing, in radians, in world space.
var base_angle: float = 0.0
var sweep: float = 1.7
var radius_scale: float = 1.0


func _ready() -> void:
	z_index = 30


func _process(delta: float) -> void:
	progress += delta
	queue_redraw()
	if progress >= duration:
		queue_free()


## `direction` is the way the blade is travelling; the arc is centred on it.
static func spawn(
	host: Node,
	at: Vector2,
	direction: Vector2,
	tint: Color,
	radius: float = ARC_RADIUS,
	sweep_angle: float = 1.7
) -> SlashArc:
	var arc := SlashArc.new()
	var aim: Vector2 = direction if direction.length_squared() > 0.0001 else Vector2.RIGHT
	arc.base_angle = aim.angle()
	arc.sweep = sweep_angle
	arc.color = tint
	arc.radius_scale = maxf(0.2, radius / ARC_RADIUS)
	# Duration scales with size so a big arc does not blink out of existence.
	arc.duration = 0.11 + arc.radius_scale * 0.03
	host.add_child(arc)
	# Set after entering the tree: `global_position` only resolves against a
	# parent once the node is actually in the scene.
	if host is Node2D:
		arc.global_position = at
	else:
		arc.position = at
	return arc


func _draw() -> void:
	var t: float = clampf(progress / duration, 0.0, 1.0)
	# Ease out so the swing starts fast and settles.
	var eased: float = 1.0 - pow(1.0 - t, 2.4)
	var alpha: float = (1.0 - t) * 0.9
	if alpha <= 0.01:
		return

	var start_angle: float = base_angle - sweep * 0.5
	var end_angle: float = start_angle + sweep * eased
	var radius: float = ARC_RADIUS * radius_scale

	var points := PackedVector2Array()
	# Outer edge.
	for i: int in range(ARC_STEPS + 1):
		var f: float = float(i) / float(ARC_STEPS)
		var angle: float = lerpf(start_angle, end_angle, f)
		# Taper: widest in the middle of the sweep.
		var taper: float = sin(f * PI) * 0.75 + 0.35
		points.append(Vector2(cos(angle), sin(angle)) * radius * taper)
	# Back along the inner edge so the arc has thickness.
	for i: int in range(ARC_STEPS, -1, -1):
		var f: float = float(i) / float(ARC_STEPS)
		var angle: float = lerpf(start_angle, end_angle, f)
		var taper: float = sin(f * PI) * 0.75 + 0.35
		var inner: float = maxf(3.0, (radius - ARC_WIDTH) * taper)
		points.append(Vector2(cos(angle), sin(angle)) * inner)

	if points.size() < 3:
		return
	draw_colored_polygon(points, Color(color.r, color.g, color.b, alpha))
