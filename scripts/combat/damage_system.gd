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

	# A counter is a counterable enemy attack that the player answered in time.
	if hitbox.counterable and result["source"] != null and result["source"].has_method("register_counter"):
		result["counter"] = true
		result["source"].register_counter(hitbox)

	if hitbox.resonance_on_hit > 0.0:
		GameManager.add_resonance(hitbox.resonance_on_hit)
		result["resonance"] = hitbox.resonance_on_hit

	AudioManager.play_named(&"hit_landed" if hitbox.kind != Hitbox.Kind.ENEMY else &"player_hurt")
	return result
