class_name ResonanceSystem
extends Node
## ResonanceSystem — the game's defining mechanic (GDD 6).
##
## Resonance is built by *intelligent* play: precise attacks, counters, correct
## Lantern use, learned patterns, environmental opportunities. Raw damage alone
## fills it slowly on purpose. At threshold the Hunter may force a Revelation,
## which exposes the nightmare's deeper structure and its true vulnerability.

signal revelation_available_changed(available: bool)
signal revelation_started(nightmare_id: StringName, duration: float)
signal revelation_ended(nightmare_id: StringName)
signal pattern_learned(pattern_id: StringName)
signal threshold_changed(threshold: float)

const BASE_THRESHOLD: float = 100.0
const BASE_REVELATION_DURATION: float = 8.0
const COOLDOWN_AFTER_REVELATION: float = 2.5

## The nightmare currently being hunted. Its NightmareData sets the rewards.
var target_data: NightmareData = null
var target_id: StringName = &""

var threshold: float = BASE_THRESHOLD
var is_revealing: bool = false
var revelation_timer: float = 0.0
var revelation_duration: float = BASE_REVELATION_DURATION
## Tracks which attack patterns the player has already read, so a repeated
## tell stops paying out. Understanding is rewarded once, not farmed.
var learned_patterns: Dictionary = {}
var _revelation_cooldown: float = 0.0


## RefCounted rather than a Node: it is a combat rule set attached to a
## combatant, not a scene node. Ticked by its owner's _process.
func _init() -> void:
	GameManager.resonance_changed.connect(_on_resonance_changed)


func tick(delta: float) -> void:
	if _revelation_cooldown > 0.0:
		_revelation_cooldown = maxf(0.0, _revelation_cooldown - delta)
	if not is_revealing:
		return
	revelation_timer -= delta
	if revelation_timer <= 0.0:
		end_revelation()


# --- Setup ------------------------------------------------------------------
func set_target(data: NightmareData) -> void:
	target_data = data
	target_id = data.id if data != null else &""
	learned_patterns.clear()
	if is_revealing:
		end_revelation()


func clear_target() -> void:
	if is_revealing:
		end_revelation()
	target_data = null
	target_id = &""
	learned_patterns.clear()


func set_threshold(value: float) -> void:
	threshold = maxf(1.0, value)
	threshold_changed.emit(threshold)


func progress_ratio() -> float:
	return clampf(GameManager.resonance / threshold, 0.0, 1.0)


func is_ready_for_revelation() -> bool:
	return (
		not is_revealing
		and _revelation_cooldown <= 0.0
		and GameManager.resonance >= threshold
		and target_data != null
	)


func _on_resonance_changed(_current: float, _maximum: float) -> void:
	revelation_available_changed.emit(is_ready_for_revelation())


# --- Resonance sources (GDD 6) ----------------------------------------------
func register_precise_attack() -> void:
	if target_data == null:
		return
	GameManager.add_resonance(target_data.resonance_on_precise_attack)


func register_counter() -> void:
	if target_data == null:
		return
	GameManager.add_resonance(target_data.resonance_on_counter)


func register_lantern_reveal() -> void:
	if target_data == null:
		return
	GameManager.add_resonance(target_data.resonance_on_lantern_reveal)


func register_environment() -> void:
	if target_data == null:
		return
	GameManager.add_resonance(target_data.resonance_on_environment)


## Pays out only the first time a pattern is read (no farming the same tell).
func register_pattern(pattern_id: StringName) -> bool:
	if target_data == null or learned_patterns.has(pattern_id):
		return false
	learned_patterns[pattern_id] = true
	var bonus: float = target_data.resonance_on_pattern_learned
	var skill_bonus: float = ProgressionManager.effect_total(&"resonance_pattern_bonus")
	bonus *= 1.0 + skill_bonus
	GameManager.add_resonance(bonus)
	pattern_learned.emit(pattern_id)
	return true


func patterns_learned() -> int:
	return learned_patterns.size()


# --- Revelation (GDD 6) -----------------------------------------------------
func start_revelation() -> bool:
	if not is_ready_for_revelation():
		return false
	var duration: float = BASE_REVELATION_DURATION + ProgressionManager.effect_total(&"revelation_duration")
	is_revealing = true
	revelation_duration = duration
	revelation_timer = duration
	GameManager.spend_resonance(threshold)
	AudioManager.play_named(&"revelation")
	revelation_started.emit(target_id, duration)
	GameManager.revelation_started.emit(target_id)
	revelation_available_changed.emit(false)
	return true


func end_revelation() -> void:
	if not is_revealing:
		return
	is_revealing = false
	revelation_timer = 0.0
	_revelation_cooldown = COOLDOWN_AFTER_REVELATION
	revelation_ended.emit(target_id)
	GameManager.revelation_ended.emit(target_id)
	revelation_available_changed.emit(is_ready_for_revelation())


## Damage multiplier currently applied to the target (GDD 6).
func revealed_damage_multiplier() -> float:
	if not is_revealing or target_data == null:
		return 1.0
	return target_data.damage_multiplier_when_revealed


## True when the nightmare's true vulnerability is exposed and interactable.
func vulnerability_exposed() -> bool:
	return is_revealing and target_data != null


func reset() -> void:
	if is_revealing:
		end_revelation()
	learned_patterns.clear()
	_revelation_cooldown = 0.0
	GameManager.resonance = 0.0
	GameManager.resonance_changed.emit(GameManager.resonance, GameManager.max_resonance)
