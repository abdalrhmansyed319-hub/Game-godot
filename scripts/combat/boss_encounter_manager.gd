class_name BossEncounterManager
extends RefCounted
## BossEncounterManager — multi-phase boss flow and the Resolution decision
## (GDD 6 and 8).
##
## Phases: RECOGNITION -> DISTORTION -> REVELATION -> RESOLUTION.
## Not every boss uses all four; `phase_plan` declares which ones it has.

signal phase_entered(phase: int, boss_id: StringName)
signal encounter_started(boss_id: StringName)
signal resolution_offered(boss_id: StringName, options: Array[int])
signal resolution_chosen(boss_id: StringName, resolution: int)

enum Phase { RECOGNITION, DISTORTION, REVELATION, RESOLUTION, ENDED }

@export var boss_id: StringName = &""
## Health fractions that trigger DISTORTION and REVELATION.
@export var distortion_at: float = 0.66
@export var revelation_at: float = 0.33
@export var arena_distortion_on_phase_2: float = 0.7

var phase: int = Phase.RECOGNITION
var phase_plan: Array[int] = [Phase.RECOGNITION, Phase.DISTORTION, Phase.REVELATION, Phase.RESOLUTION]
var boss: Node = null
var resonance: ResonanceSystem = null
var _health_seen: float = 0.0


## RefCounted rather than a Node: a boss owns one of these and creates it when
## the encounter opens, so it must be constructible outside the scene tree.
func _init() -> void:
	GameManager.revelation_started.connect(_on_revelation_started)
	GameManager.revelation_ended.connect(_on_revelation_ended)


func begin(boss_node: Node, boss_data: NightmareData, resonance_system: ResonanceSystem) -> void:
	boss = boss_node
	resonance = resonance_system
	boss_id = boss_data.id if boss_data != null else &""
	phase = Phase.RECOGNITION
	_health_seen = 1.0
	resonance_system.set_target(boss_data)
	encounter_started.emit(boss_id)
	_enter(Phase.RECOGNITION)


## Call every physics frame with the boss's normalised health (0..1).
func update_health(normalised_health: float) -> void:
	if phase == Phase.ENDED:
		return
	_health_seen = normalised_health
	if phase == Phase.RECOGNITION and normalised_health <= distortion_at and _planned(Phase.DISTORTION):
		_enter(Phase.DISTORTION)
	elif phase == Phase.DISTORTION and normalised_health <= revelation_at and _planned(Phase.REVELATION):
		_enter(Phase.REVELATION)
	elif normalised_health <= 0.0:
		offer_resolution()


func _planned(candidate: int) -> bool:
	return phase_plan.has(candidate)


func _enter(new_phase: int) -> void:
	phase = new_phase
	match new_phase:
		Phase.DISTORTION:
			# Phase 2 Distortion: the arena itself changes (GDD 8).
			GameManager.distortion_changed.emit(WorldManager.current_region, arena_distortion_on_phase_2)
		Phase.REVELATION:
			if resonance != null and resonance.is_ready_for_revelation():
				resonance.start_revelation()
		Phase.RESOLUTION:
			pass
	phase_entered.emit(new_phase, boss_id)


func _on_revelation_started(_nightmare_id: StringName, _duration: float) -> void:
	if phase == Phase.DISTORTION and _planned(Phase.REVELATION):
		_enter(Phase.REVELATION)


func _on_revelation_ended(_nightmare_id: StringName) -> void:
	# If the Revelation window lapses the fight falls back to Distortion.
	if phase == Phase.REVELATION and _health_seen > 0.0:
		phase = Phase.DISTORTION if _planned(Phase.DISTORTION) else Phase.RECOGNITION
		phase_entered.emit(phase, boss_id)


## Which resolutions the narrative currently permits (GDD 6).
func available_resolutions(data: NightmareData) -> Array[int]:
	var out: Array[int] = []
	if data == null:
		return out
	for option: int in data.available_resolutions:
		match option:
			NightmareData.ResolutionKind.DESTROY:
				out.append(option)
			NightmareData.ResolutionKind.CAPTURE:
				if _requirement_met(data.capture_requirement):
					out.append(option)
			NightmareData.ResolutionKind.RELEASE:
				if _requirement_met(data.release_requirement):
					out.append(option)
			NightmareData.ResolutionKind.RECONCILE:
				if _requirement_met(data.reconcile_requirement):
					out.append(option)
	return out


## A requirement written as "decision_id=value" pairs, or free text matched
## against discovered clues. Empty requirements are always satisfied.
func _requirement_met(requirement: String) -> bool:
	if requirement.strip_edges().is_empty():
		return true
	for part: String in requirement.split(";", false):
		var clause: String = part.strip_edges()
		if clause.contains("="):
			var pieces: PackedStringArray = clause.split("=", false, 2)
			if not DecisionTracker.is_value(StringName(pieces[0]), StringName(pieces[1])):
				return false
		else:
			if not GameManager.has_clue(StringName(clause.to_snake_case()), boss_id):
				return false
	return true


func offer_resolution() -> void:
	if phase == Phase.ENDED:
		return
	var data: NightmareData = NightmareDatabase.nightmare(boss_id)
	phase = Phase.RESOLUTION
	phase_entered.emit(phase, boss_id)
	resolution_offered.emit(boss_id, available_resolutions(data))


func choose(resolution: int) -> void:
	var data: NightmareData = NightmareDatabase.nightmare(boss_id)
	if data == null:
		return
	if not available_resolutions(data).has(resolution):
		return
	GameManager.record_resolution(boss_id, resolution)
	DecisionTracker.record(StringName("resolution_" + String(boss_id)), StringName(data.resolution_label(resolution).to_lower()))
	WorldManager.mark_region_changed(WorldManager.current_region, StringName(data.resolution_label(resolution).to_lower()))

	match resolution:
		NightmareData.ResolutionKind.DESTROY:
			if data.journal_entry_on_understanding != "":
				JournalManager.discover(
					StringName("resolution_destroy_" + String(boss_id)),
					JournalManager.Category.DECISION,
					"%s — destroyed" % data.display_name,
					"I ended it. Whatever it was holding, it is gone now, and so is the reason it existed."
				)
		NightmareData.ResolutionKind.CAPTURE:
			if data.grants_echo_on_capture != &"":
				EchoManager.collect(data.grants_echo_on_capture)
		NightmareData.ResolutionKind.RELEASE:
			if data.grants_echo_on_release != &"":
				EchoManager.collect(data.grants_echo_on_release)
			if data.journal_entry_on_understanding != "":
				JournalManager.discover(
					StringName("resolution_release_" + String(boss_id)),
					JournalManager.Category.DECISION,
					"%s — released" % data.display_name,
					data.journal_entry_on_understanding
				)
		NightmareData.ResolutionKind.RECONCILE:
			if data.journal_entry_on_understanding != "":
				JournalManager.discover(
					StringName("resolution_reconcile_" + String(boss_id)),
					JournalManager.Category.DECISION,
					"%s — reconciled" % data.display_name,
					data.journal_entry_on_understanding
				)

	ProgressionManager.gain_experience(120)
	AudioManager.play_named(&"resolution")
	resolution_chosen.emit(boss_id, resolution)
	phase = Phase.ENDED
	if resonance != null:
		resonance.clear_target()
