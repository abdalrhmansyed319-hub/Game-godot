class_name PlayerCombat
extends Node
## PlayerCombat — the Reverberation Blade in real time (GDD 4A and 5).
##
## Light chains, heavy hits that break defences, aerial attacks, charged
## strikes and counters. Attacks are frame-phased (startup / active /
## recovery) so everything stays readable and punishable.

signal attack_started(kind: int)
signal attack_finished(kind: int)
signal hit_connected(result: Dictionary, kind: int)
signal counter_succeeded(target: Node)
signal charge_ready
signal charge_released(power: float)

enum Phase { NONE, STARTUP, ACTIVE, RECOVERY }

@export var hitbox: Hitbox
@export var resonance: ResonanceSystem
@export var resonance_bonus_per_hit: float = 0.0
## Widened by the Counterpoint skill (GDD 9, Path A).
@export var counter_window: float = 0.22

var weapon: WeaponFormData = null
var phase: int = Phase.NONE
var phase_timer: float = 0.0
var current_kind: int = Hitbox.Kind.LIGHT
var combo_index: int = 0
var combo_timer: float = 0.0
var combo_window: float = 0.55
var is_airborne: bool = false
var is_charging: bool = false
var charge_timer: float = 0.0
var _counter_window_timer: float = 0.0
var _counter_armed: bool = false
var _has_hit_this_swing: bool = false
var _facing: float = 1.0


func setup(blade_hitbox: Hitbox, resonance_system: ResonanceSystem) -> void:
	hitbox = blade_hitbox
	resonance = resonance_system
	if hitbox != null:
		hitbox.deactivate()
		hitbox.area_entered.connect(_on_hitbox_area_entered)


func set_weapon(form: WeaponFormData) -> void:
	if form == null:
		return
	weapon = form


func is_busy() -> bool:
	return phase != Phase.NONE or is_charging


func can_attack() -> bool:
	return phase == Phase.NONE and not is_charging


func max_combo() -> int:
	return 2 + int(ProgressionManager.effect_total(&"combo_extension"))


func set_facing(value: float) -> void:
	_facing = value


func set_airborne(value: bool) -> void:
	is_airborne = value


func _physics_process(delta: float) -> void:
	combo_timer = maxf(0.0, combo_timer - delta)
	if combo_timer <= 0.0:
		combo_index = 0
	_counter_window_timer = maxf(0.0, _counter_window_timer - delta)
	if _counter_window_timer <= 0.0:
		_counter_armed = false

	if is_charging:
		charge_timer += delta
		if weapon != null and charge_timer >= weapon.charge_time:
			if not _charge_ready_emitted:
				_charge_ready_emitted = true
				charge_ready.emit()
		return

	if phase == Phase.NONE:
		return
	phase_timer -= delta
	if phase == Phase.STARTUP and phase_timer <= 0.0:
		_enter_active()
	elif phase == Phase.ACTIVE and phase_timer <= 0.0:
		_enter_recovery()
	elif phase == Phase.RECOVERY and phase_timer <= 0.0:
		_finish_attack()


var _charge_ready_emitted: bool = false


# --- Attack entry points ----------------------------------------------------
func start_light_attack() -> bool:
	if not can_attack():
		return false
	if weapon == null:
		return false
	current_kind = Hitbox.Kind.LIGHT
	combo_index = mini(combo_index + 1, max_combo())
	combo_timer = combo_window
	_begin_phase(weapon.light_startup, weapon.light_recovery, weapon.light_damage, weapon.resonance_per_hit + resonance_bonus_per_hit)
	return true


func start_heavy_attack() -> bool:
	if not can_attack():
		return false
	if weapon == null:
		return false
	current_kind = Hitbox.Kind.HEAVY
	combo_index = 0
	# Heavy doubles as a counter when timed against a counterable attack (GDD 5).
	_counter_armed = true
	_counter_window_timer = counter_window + weapon.counter_window_bonus
	_begin_phase(weapon.heavy_startup, weapon.heavy_recovery, weapon.heavy_damage, weapon.resonance_per_hit * 1.5 + resonance_bonus_per_hit)
	return true


func start_aerial_attack() -> bool:
	if not can_attack() or not is_airborne:
		return false
	if weapon == null:
		return false
	if ProgressionManager.effect_total(&"aerial_chain") <= 0.0:
		return false
	current_kind = Hitbox.Kind.AERIAL
	combo_index = mini(combo_index + 1, max_combo())
	combo_timer = combo_window
	_begin_phase(weapon.light_startup * 0.9, weapon.light_recovery * 1.1, weapon.aerial_damage, weapon.resonance_per_hit)
	return true


func begin_charge() -> bool:
	if not can_attack() or weapon == null:
		return false
	is_charging = true
	charge_timer = 0.0
	_charge_ready_emitted = false
	return true


func release_charge() -> bool:
	if not is_charging or weapon == null:
		return false
	var power: float = clampf(charge_timer / weapon.charge_time, 0.0, 1.0)
	is_charging = false
	var damage: float = weapon.charge_damage * (0.35 + 0.65 * power)
	current_kind = Hitbox.Kind.CHARGED
	charge_released.emit(power)
	_begin_phase(weapon.heavy_startup * 0.7, weapon.heavy_recovery, damage, weapon.resonance_per_hit * 2.0 * power)
	return true


func cancel() -> void:
	if hitbox != null:
		hitbox.deactivate()
	phase = Phase.NONE
	phase_timer = 0.0
	is_charging = false
	charge_timer = 0.0
	_has_hit_this_swing = false


# --- Phase flow -------------------------------------------------------------
func _begin_phase(startup: float, recovery: float, damage: float, resonance_gain: float) -> void:
	phase = Phase.STARTUP
	phase_timer = startup
	_has_hit_this_swing = false
	if hitbox != null:
		hitbox.damage = damage
		hitbox.kind = current_kind as Hitbox.Kind
		hitbox.stagger_power = weapon.stagger_power if weapon != null else 6.0
		hitbox.resonance_on_hit = resonance_gain
		hitbox.counterable = false
		hitbox.deactivate()
	attack_started.emit(current_kind)
	AudioManager.play_named(&"heavy_attack" if current_kind in [Hitbox.Kind.HEAVY, Hitbox.Kind.CHARGED] else &"light_attack")


func _enter_active() -> void:
	phase = Phase.ACTIVE
	# Active window is short and fixed: the swing is a moment, not a state.
	phase_timer = 0.1
	if hitbox != null:
		hitbox.activate()


func _enter_recovery() -> void:
	phase = Phase.RECOVERY
	if hitbox != null:
		hitbox.deactivate()


func _finish_attack() -> void:
	var finished_kind: int = current_kind
	phase = Phase.NONE
	phase_timer = 0.0
	attack_finished.emit(finished_kind)


func _on_hitbox_area_entered(area: Area2D) -> void:
	if phase != Phase.ACTIVE or _has_hit_this_swing:
		return
	if not area is Hurtbox:
		return
	var hurtbox := area as Hurtbox
	if not hurtbox.can_be_hit():
		return
	var target: Node = hurtbox.owner_node()
	if target == null or target == hitbox.source():
		return

	# Revealed nightmares take the multiplier from the Resonance system (GDD 6).
	hurtbox.damage_taken_multiplier = 1.0
	if resonance != null and resonance.vulnerability_exposed():
		hurtbox.damage_taken_multiplier = resonance.revealed_damage_multiplier()

	var result: Dictionary = DamageSystem.apply(hurtbox, hitbox)
	_has_hit_this_swing = true
	hit_connected.emit(result, current_kind)

	if resonance != null:
		resonance.register_precise_attack()


## Wired to the player's Hurtbox. A counter is landing a strike inside the
## window while an enemy's *counterable* attack is connecting (GDD 5):
## it interrupts the nightmare, opens it up, and returns combat energy.
func on_player_hit_taken(result: Dictionary) -> void:
	if not _counter_armed or is_charging:
		return
	if int(result.get("kind", -1)) != Hitbox.Kind.ENEMY:
		return
	_counter_armed = false
	_counter_window_timer = 0.0

	var target: Node = result.get("source", null)
	if target != null and target.has_method("apply_stagger"):
		# The interrupt: the nightmare loses its current action.
		target.apply_stagger(weapon.stagger_power * 2.0 if weapon != null else 14.0)
	if target != null and target.has_method("interrupt_current_ability"):
		target.interrupt_current_ability()

	var bonus: float = 1.0 + ProgressionManager.effect_total(&"counter_damage_bonus")
	GameManager.add_resonance(12.0 * bonus)
	GameManager.restore_lantern(10.0)
	AudioManager.play_named(&"hit_landed")
	if resonance != null:
		resonance.register_counter()
	counter_succeeded.emit(target)


## Interface hook used by DamageSystem attribution.
func register_counter(_hitbox: Hitbox) -> void:
	pass
