class_name Fx
extends RefCounted
## Fx — one-shot particle and shape effects (GDD 6/20: impactful, readable).
##
## Textures are generated once and cached, so no image assets ship and the Web
## build stays small. Particle counts scale with Settings.particle_scale() and
## stay well inside the jam's performance budget.

static var _spark_texture: GradientTexture2D = null
static var _live_effects: int = 0

## Hard cap on simultaneous effects. Protects frame pacing in the browser,
## which is a scored jam category.
const MAX_LIVE_EFFECTS: int = 12


static func spark_texture() -> GradientTexture2D:
	if _spark_texture != null:
		return _spark_texture
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 1))
	gradient.set_color(1, Color(1, 1, 1, 0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 8
	texture.height = 8
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(0.5, 0.0)
	_spark_texture = texture
	return texture


static func live_count() -> int:
	return _live_effects


## Burst of sparks at a point. `amount` is a base count, scaled by settings.
static func burst(
	host: Node,
	at: Vector2,
	tint: Color,
	amount: int = 14,
	spread: float = 160.0,
	lifetime: float = 0.35,
	direction: Vector2 = Vector2.RIGHT
) -> void:
	if host == null or not is_instance_valid(host):
		return
	if _live_effects >= MAX_LIVE_EFFECTS:
		return
	var count: int = clampi(int(float(amount) * Settings.particle_scale()), 4, 40)

	var particles := GPUParticles2D.new()
	particles.global_position = at
	particles.z_index = 40
	particles.amount = count
	particles.lifetime = lifetime
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.local_coords = false
	particles.texture = spark_texture()

	var material := ParticleProcessMaterial.new()
	material.direction = Vector3(direction.x, direction.y, 0.0)
	material.spread = clampf(spread, 1.0, 180.0)
	material.initial_velocity_min = 90.0
	material.initial_velocity_max = 230.0
	material.gravity = Vector3(0, 520, 0)
	material.scale_min = 0.6
	material.scale_max = 1.6
	material.color = tint
	particles.process_material = material

	_live_effects += 1
	var parent: Node = host.get_parent()
	if parent != null:
		parent.add_child(particles)
	else:
		host.add_child(particles)
	particles.emitting = true
	particles.finished.connect(func() -> void: _release(particles))
	# Safety net: never leak an effect if `finished` does not fire.
	host.get_tree().create_timer(lifetime + 0.6, true, false, true).timeout.connect(
		func() -> void: _release(particles)
	)


## Dust kicked up on landing or dashing.
static func dust(host: Node, at: Vector2, amount: int = 8) -> void:
	burst(host, at, Color(0.72, 0.7, 0.82, 0.55), amount, 70.0, 0.4, Vector2(0, -1))


## Lantern reveal: a soft expanding ring of light.
static func reveal_ring(host: Node, at: Vector2) -> void:
	burst(host, at, Palette.LANTERN, 22, 180.0, 0.5, Vector2(0, -1))


## Anchor deployment: cold, heavy, downward.
static func anchor_slam(host: Node, at: Vector2) -> void:
	burst(host, at, Palette.ANCHOR, 18, 120.0, 0.45, Vector2(0, 1))


static func _release(particles: GPUParticles2D) -> void:
	_live_effects = maxi(0, _live_effects - 1)
	if is_instance_valid(particles):
		particles.queue_free()
