extends Node
## ProgressionManager — hunter levels, attributes, three skill paths (GDD 9).
##
## Leveling gives modest stat gains plus progression points. Level grinding
## must never be mandatory: investigation and exploration also grant XP.

signal attribute_changed(attribute: StringName, value: int)
signal skill_points_changed(points: int)
signal skill_learned(skill_id: StringName, path: int)

enum Path { BLADE, LANTERN, ANCHOR }

const EXPERIENCE_PER_LEVEL_BASE: int = 100
const EXPERIENCE_CURVE: float = 1.35
const POINTS_PER_LEVEL: int = 1
const MAX_ATTRIBUTE_POINTS_PER_STAT: int = 20

var experience: int = 0
var level: int = 1
var skill_points: int = 1

## Core attributes (GDD 9).
var vitality: int = 5
var agility: int = 5
var resonance: int = 5
var focus: int = 5
var resolve: int = 5

var learned_skills: Array[StringName] = []
var _skill_defs: Dictionary = {}


func _ready() -> void:
	GameManager.experience_gained.connect(_on_experience_gained)
	GameManager.hunter_level_up.connect(_on_level_up)


# --- Experience -------------------------------------------------------------
func experience_for_next_level() -> int:
	return int(float(EXPERIENCE_PER_LEVEL_BASE) * pow(EXPERIENCE_CURVE, float(level - 1)))


func gain_experience(amount: int) -> void:
	if amount <= 0:
		return
	GameManager.experience_gained.emit(amount)


func _on_experience_gained(amount: int) -> void:
	experience += amount
	while experience >= experience_for_next_level():
		experience -= experience_for_next_level()
		level += 1
		skill_points += POINTS_PER_LEVEL
		GameManager.hunter_level_up.emit(level, skill_points)
		skill_points_changed.emit(skill_points)
		_apply_level_bonuses()


func _on_level_up(_new_level: int, points: int) -> void:
	skill_points_changed.emit(points)


func _apply_level_bonuses() -> void:
	# Modest, controlled growth. No exponential scaling.
	GameManager.set_max_health(GameManager.MAX_HEALTH_BASE + float(vitality) * 6.0)
	GameManager.set_max_resonance(GameManager.MAX_RESONANCE_BASE + float(resonance) * 4.0)


# --- Attributes -------------------------------------------------------------
func spend_point_on(attribute: StringName) -> bool:
	if skill_points <= 0:
		return false
	var current: int = int(get(attribute))
	if current >= MAX_ATTRIBUTE_POINTS_PER_STAT:
		return false
	match attribute:
		&"vitality", &"agility", &"resonance", &"focus", &"resolve":
			set(attribute, current + 1)
		_:
			return false
	skill_points -= 1
	skill_points_changed.emit(skill_points)
	attribute_changed.emit(attribute, int(get(attribute)))
	_apply_attribute_effects(attribute)
	return true


func _apply_attribute_effects(attribute: StringName) -> void:
	match attribute:
		&"vitality":
			GameManager.set_max_health(GameManager.MAX_HEALTH_BASE + float(vitality) * 6.0)
		&"resonance":
			GameManager.set_max_resonance(GameManager.MAX_RESONANCE_BASE + float(resonance) * 4.0)
		&"focus":
			# Focus improves Lantern efficiency: same effect, cheaper charge.
			pass
		&"agility", &"resolve":
			pass


## Focus-driven Lantern cost multiplier (GDD 9: Focus improves instrument efficiency).
func lantern_cost_multiplier() -> float:
	return clampf(1.0 - float(focus - 5) * 0.03, 0.55, 1.25)


## Resolve-driven resistance to distortion damage (GDD 9, 14).
func distortion_resistance() -> float:
	return clampf(float(resolve - 5) * 0.04, -0.2, 0.6)


# --- Skill tree -------------------------------------------------------------
func register_skills(definitions: Array[SkillDef]) -> void:
	for definition: SkillDef in definitions:
		if definition != null and definition.id != &"":
			_skill_defs[definition.id] = definition


func skill_def(skill_id: StringName) -> SkillDef:
	return _skill_defs.get(skill_id, null)


func can_learn(skill_id: StringName) -> bool:
	var definition: SkillDef = _skill_defs.get(skill_id, null)
	if definition == null or learned_skills.has(skill_id):
		return false
	if skill_points < definition.cost:
		return false
	for prerequisite: StringName in definition.requires:
		if not learned_skills.has(prerequisite):
			return false
	return true


func learn(skill_id: StringName) -> bool:
	if not can_learn(skill_id):
		return false
	var definition: SkillDef = _skill_defs[skill_id]
	skill_points -= definition.cost
	learned_skills.append(skill_id)
	skill_points_changed.emit(skill_points)
	skill_learned.emit(skill_id, definition.path)
	return true


func has_skill(skill_id: StringName) -> bool:
	return learned_skills.has(skill_id)


## Sum of effect_value across learned skills sharing an effect_key.
func effect_total(effect_key: StringName) -> float:
	var total: float = 0.0
	for skill_id: StringName in learned_skills:
		var definition: SkillDef = _skill_defs.get(skill_id, null)
		if definition != null and definition.effect_key == effect_key:
			total += definition.effect_value
	return total


func points_in_path(path: int) -> int:
	var count: int = 0
	for skill_id: StringName in learned_skills:
		var definition: SkillDef = _skill_defs.get(skill_id, null)
		if definition != null and definition.path == path:
			count += 1
	return count


func to_dict() -> Dictionary:
	return {
		"experience": experience,
		"level": level,
		"skill_points": skill_points,
		"vitality": vitality,
		"agility": agility,
		"resonance": resonance,
		"focus": focus,
		"resolve": resolve,
		"learned_skills": PackedStringArray(learned_skills.map(func(id: StringName) -> String: return String(id))),
	}


func from_dict(data: Dictionary) -> void:
	experience = int(data.get("experience", 0))
	level = int(data.get("level", 1))
	skill_points = int(data.get("skill_points", 1))
	vitality = int(data.get("vitality", 5))
	agility = int(data.get("agility", 5))
	resonance = int(data.get("resonance", 5))
	focus = int(data.get("focus", 5))
	resolve = int(data.get("resolve", 5))
	learned_skills.clear()
	var packed: Variant = data.get("learned_skills", PackedStringArray())
	if packed is PackedStringArray:
		for skill_id: String in packed:
			learned_skills.append(StringName(skill_id))
	elif packed is Array:
		for skill_id: Variant in packed:
			learned_skills.append(StringName(String(skill_id)))
	skill_points_changed.emit(skill_points)
	GameManager.set_max_health(GameManager.MAX_HEALTH_BASE + float(vitality) * 6.0)
	GameManager.set_max_resonance(GameManager.MAX_RESONANCE_BASE + float(resonance) * 4.0)
