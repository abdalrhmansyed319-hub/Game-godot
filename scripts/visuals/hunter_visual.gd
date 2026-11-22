class_name HunterVisual
extends Node2D
## HunterVisual — the protagonist, drawn entirely in code.
##
## No sprite sheet, no import pipeline, nothing to break in a browser. The look
## is silhouette-first: a hooded shape readable against a dark dream, with one
## warm light. Every animated element is driven by real gameplay state, so the
## drawing *is* the animation rather than a decoration on top of it.

const LANTERN_GLOW_RADIUS: float = 92.0

var player: CharacterBody2D = null
var movement: PlayerMovement = null
var combat: PlayerCombat = null

var _run_cycle: float = 0.0
var _idle_bob: float = 0.0
var _facing: float = 1.0
var _airborne: bool = false
var _swing: float = 0.0
var _swing_kind: int = -1
var _hurt_flash: float = 0.0
var _dash_ghost: float = 0.0
var _glow: GradientTexture2D = null


func _ready() -> void:
	z_index = 10
	_glow = _make_glow()


func bind(target: CharacterBody2D, move: PlayerMovement, fight: PlayerCombat) -> void:
	player = target
	movement = move
	combat = fight
	if fight != null:
		fight.attack_started.connect(_on_attack_started)


func _process(delta: float) -> void:
	if player == null:
		return
	_idle_bob += delta
	_hurt_flash = maxf(0.0, _hurt_flash - delta * 5.0)
	_dash_ghost = maxf(0.0, _dash_ghost - delta * 3.2)
	if _swing >= 0.0:
		_swing += delta * 9.0
		if _swing > 1.0:
			_swing = -1.0
			_swing_kind = -1
	var speed: float = absf(player.velocity.x)
	_run_cycle += delta * (6.0 + speed * 0.035)
	if movement != null:
		_facing = movement.facing
	_airborne = not player.is_on_floor()
	queue_redraw()


func flash() -> void:
	_hurt_flash = 1.0


## PlayerController feeds the dash timer in; the after-image fades with it.
func dash_ghost(value: float) -> void:
	_dash_ghost = maxf(_dash_ghost, clampf(value, 0.0, 1.0))


func _on_attack_started(kind: int) -> void:
	_swing = 0.0
	_swing_kind = kind


func _draw() -> void:
	var bob: float = 0.0
	if not _airborne and absf(player.velocity.x) < 12.0:
		bob = sin(_idle_bob * 2.2) * 1.4

	var cloak: Color = Palette.CLOAK
	var lit: Color = Palette.CLOAK_LIT
	if _hurt_flash > 0.0:
		cloak = cloak.lerp(Palette.HURT_FLASH, _hurt_flash * 0.85)
		lit = lit.lerp(Palette.HURT_FLASH, _hurt_flash * 0.85)

	_draw_dash_ghost()
	_draw_lantern_glow(bob)
	_draw_legs(bob)
	_draw_cloak(bob, cloak, lit)
	_draw_hood(bob, cloak, lit)
	_draw_blade(bob)


## After-image behind a dash. Cheap, and it makes speed legible.
func _draw_dash_ghost() -> void:
	if _dash_ghost <= 0.01:
		return
	var alpha: float = _dash_ghost * 0.35
	var offset: Vector2 = Vector2(-_facing * 16.0, 0.0)
	draw_circle(offset + Vector2(0, -22), 13.0, Color(Palette.CLOAK_LIT.r, Palette.CLOAK_LIT.g, Palette.CLOAK_LIT.b, alpha))


func _draw_lantern_glow(bob: float) -> void:
	if _glow == null:
		return
	var lamp: Vector2 = Vector2(_facing * 12.0, -20.0 + bob)
	var pulse: float = 1.0 + sin(_idle_bob * 3.1) * 0.05
	var size: Vector2 = Vector2.ONE * LANTERN_GLOW_RADIUS * pulse
	draw_texture_rect(_glow, Rect2(lamp - size * 0.5, size), false, Color(1, 1, 1, 0.5))


func _draw_cloak(bob: float, cloak: Color, lit: Color) -> void:
	# The cloak trails opposite the direction of travel, so motion reads even
	# when the character is small on screen.
	var trail: float = clampf(-player.velocity.x * 0.028, -7.0, 7.0)
	var points := PackedVector2Array([
		Vector2(-8.0, -30.0 + bob),
		Vector2(8.0, -30.0 + bob),
		Vector2(11.0 + trail, -6.0 + bob),
		Vector2(4.0 + trail * 1.5, -2.0 + bob),
		Vector2(-4.0 + trail * 1.5, -2.0 + bob),
		Vector2(-11.0 + trail, -6.0 + bob),
	])
	draw_colored_polygon(points, cloak)
	# One lit edge, so the silhouette separates from the background.
	draw_polyline(
		PackedVector2Array([Vector2(-8.0, -30.0 + bob), Vector2(-11.0 + trail, -6.0 + bob)]),
		lit, 1.6
	)


func _draw_hood(bob: float, cloak: Color, lit: Color) -> void:
	var center: Vector2 = Vector2(0.0, -33.0 + bob)
	# Hood as a triangle-ish shape: distinctive at any size.
	var hood := PackedVector2Array([
		center + Vector2(-7.5, 5.0),
		center + Vector2(0.0, -9.0),
		center + Vector2(7.5, 5.0),
		center + Vector2(3.0, 6.5),
		center + Vector2(-3.0, 6.5),
	])
	draw_colored_polygon(hood, cloak.darkened(0.25))
	# Face in shadow, with the lamp catching one cheek.
	draw_circle(center + Vector2(_facing * 2.0, 1.0), 4.2, Color(0.05, 0.045, 0.09))
	draw_circle(center + Vector2(_facing * 3.6, 0.4), 1.5, Color(Palette.LANTERN.r, Palette.LANTERN.g, Palette.LANTERN.b, 0.75))

	# The lamp itself.
	var lamp: Vector2 = Vector2(_facing * 12.0, -20.0 + bob)
	draw_line(center + Vector2(_facing * 5.0, 2.0), lamp + Vector2(0, -4), Palette.CLOAK_LIT, 2.0)
	draw_rect(Rect2(lamp - Vector2(3.0, 3.0), Vector2(6.0, 8.0)), Palette.LANTERN)
	draw_rect(Rect2(lamp - Vector2(3.0, 3.0), Vector2(6.0, 8.0)), Palette.LANTERN.darkened(0.3), false, 1.0)


func _draw_legs(bob: float) -> void:
	var grounded: bool = not _airborne
	var speed: float = absf(player.velocity.x)
	var stride: float = 0.0
	if grounded and speed > 12.0:
		stride = sin(_run_cycle) * 5.0
	elif _airborne:
		stride = 3.0
	var hip: float = -6.0 + bob
	draw_line(Vector2(-3.0, hip), Vector2(-3.0 + stride, 0.0), Palette.CLOAK.darkened(0.4), 3.2)
	draw_line(Vector2(3.0, hip), Vector2(3.0 - stride, 0.0), Palette.CLOAK.darkened(0.4), 3.2)


func _draw_blade(bob: float) -> void:
	var shoulder: Vector2 = Vector2(_facing * 6.0, -24.0 + bob)
	var tint: Color = Palette.BLADE
	if combat != null and combat.weapon != null:
		tint = combat.weapon.blade_color

	# The Blade brightens as Resonance fills: the weapon shows your progress.
	var resonance: float = GameManager.resonance / maxf(1.0, GameManager.max_resonance)
	tint = tint.lerp(Palette.TRUTH, resonance * 0.45)

	var angle: float = -0.5
	if _swing >= 0.0:
		# Sweep from up-and-back to down-and-forward; heavy swings wider.
		var wide: float = 1.5 if _swing_kind in [Hitbox.Kind.HEAVY, Hitbox.Kind.CHARGED] else 1.0
		angle = lerpf(-1.25, 1.05 * wide, _swing)
	elif _airborne:
		angle = -0.9

	var direction: Vector2 = Vector2(cos(angle), sin(angle)) * Vector2(_facing, 1.0)
	var tip: Vector2 = shoulder + direction.normalized() * 26.0
	draw_line(shoulder, tip, tint, 3.0)
	draw_line(shoulder, tip, Color(tint.r, tint.g, tint.b, 0.35), 6.0)
	# Hilt.
	draw_circle(shoulder, 2.4, Palette.CLOAK_LIT)


func _make_glow() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(Palette.LANTERN.r, Palette.LANTERN.g, Palette.LANTERN.b, 0.42))
	gradient.set_color(1, Color(Palette.LANTERN.r, Palette.LANTERN.g, Palette.LANTERN.b, 0.0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 64
	texture.height = 64
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(0.5, 0.0)
	return texture
