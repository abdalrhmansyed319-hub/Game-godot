class_name DamageSystem
extends RefCounted
## DamageSystem — the single place damage rules live (GDD 21).
##
## Centralising this is what keeps "revealed nightmares take more damage" and
## "counters interrupt" from being duplicated across every enemy script.


## Applies `hitbox` to `hurtbox` and returns a result describing what happened.
## Result keys: damage, stagger, killed, counter, resonance, target, source.
static func apply(hurtbox: Hurtbox, hitbox: Hitbox) -> Dictionary:
	var result: Dictionary = {
		"damage": 0.0,
		"stagger": 0.0,
		"killed": false,
		"counter": false,
		"resonance": 0.0,
		"target": hurtbox.owner_node(),
		"source": hitbox.source(),
		"kind": hitbox.kind,
	}
	if not hurtbox.can_be_hit():
		return result

	var amount: float = hitbox.damage * hurtbox.damage_taken_multiplier
	result["damage"] = amount

	# Armour absorbs stagger, not damage: Wardens hold ground but still bleed.
	var effective_stagger: float = maxf(0.0, hitbox.stagger_power - hurtbox.armour)
	result["stagger"] = effective_stagger

	if result["target"] != null and result["target"].has_method("take_damage"):
		result["killed"] = bool(result["target"].take_damage(amount, result))

	if effective_stagger > 0.0 and result["target"] != null and result["target"].has_method("apply_stagger"):
		result["target"].apply_stagger(effective_stagger)

	_apply_knockback(result, hitbox)
	_apply_impact(result, hitbox)

	# A counter is a counterable enemy attack that the player answered in time.
	if hitbox.counterable and result["source"] != null and result["source"].has_method("register_counter"):
		result["counter"] = true
		result["source"].register_counter(hitbox)

	if hitbox.resonance_on_hit > 0.0:
		GameManager.add_resonance(hitbox.resonance_on_hit)
		result["resonance"] = hitbox.resonance_on_hit

	AudioManager.play_named(&"hit_landed" if hitbox.kind != Hitbox.Kind.ENEMY else &"player_hurt")
	return result


## How much feedback this hit deserves. Everything scales from one number so a
## light tap and a charged blow read completely differently.
static func impact_intensity(kind: int) -> float:
	match kind:
		Hitbox.Kind.LIGHT: return 0.55
		Hitbox.Kind.AERIAL: return 0.6
		Hitbox.Kind.HEAVY: return 1.0
		Hitbox.Kind.CHARGED: return 1.35
		Hitbox.Kind.COUNTER: return 1.2
		Hitbox.Kind.ENEMY: return 0.8
		_: return 0.45


## Pushes the target away from whoever hit it.
##
## Enemies get shoved; the player's knockback stays in PlayerHealth, because
## moving the player is a feel decision and belongs with the player's movement.
static func _apply_knockback(result: Dictionary, hitbox: Hitbox) -> void:
	var target: Variant = result.get("target", null)
	if target == null or not (target is Node2D):
		return
	if hitbox.kind == Hitbox.Kind.ENEMY:
		return
	if not target.has_method("apply_knockback"):
		return
	var direction: Vector2 = Vector2(signf(hitbox.knockback.x) if hitbox.knockback.x != 0.0 else 1.0, -1.0)
	var source: Variant = result.get("source", null)
	if source is Node2D and is_instance_valid(source):
		direction.x = signf((target as Node2D).global_position.x - (source as Node2D).global_position.x)
		if is_zero_approx(direction.x):
			direction.x = 1.0
	target.apply_knockback(direction, hitbox.knockback.length() * impact_intensity(hitbox.kind))


## Hit-stop, shake, flash and particles, in one call, from one place.
##
## Doing this here rather than in every attack script is what stops the game
## from drifting into inconsistent feedback as content grows.
static func _apply_impact(result: Dictionary, hitbox: Hitbox) -> void:
	var target: Variant = result.get("target", null)
	if not (target is Node2D) or not is_instance_valid(target):
		return
	var target_node := target as Node2D
	var point: Vector2 = target_node.global_position + Vector2(0, -22.0)
	var source: Variant = result.get("source", null)
	if source is Node2D and is_instance_valid(source):
		point = point.lerp((source as Node2D).global_position + Vector2(0, -22.0), 0.35)

	var strength: float = impact_intensity(hitbox.kind)
	var is_player_hurt: bool = hitbox.kind == Hitbox.Kind.ENEMY

	FeedbackManager.impact_feedback(point, strength, is_player_hurt)
	if target_node.has_method("hit_react"):
		target_node.hit_react(strength, point)

	var sparks: Color = Palette.HURT_FLASH if is_player_hurt else Palette.BLOODLESS_IMPACT
	if not is_player_hurt and target_node.has_method("revealed_spark_color"):
		sparks = target_node.revealed_spark_color()
	Fx.burst(target_node, point, sparks, int(roundf(5.0 + strength * 9.0)))
	if hitbox.kind in [Hitbox.Kind.HEAVY, Hitbox.Kind.CHARGED]:
		var swing: Vector2 = Vector2(1.0, 0.0)
		if source is Node2D and is_instance_valid(source):
			swing = (target_node.global_position - (source as Node2D).global_position).normalized()
			if swing == Vector2.ZERO:
				swing = Vector2(1.0, 0.0)
		SlashArc.spawn(target_node, point, swing, Palette.BLADE_TRAIL, 34.0 + strength * 12.0)
