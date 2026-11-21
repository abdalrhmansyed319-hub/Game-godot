class_name NightmareData
extends Resource
## Data-driven definition of a nightmare creature (GDD sections 6 and 7).
##
## Every nightmare is authored as a Resource so designers can add creatures
## without touching gameplay code. `NightmareDatabase` loads these at boot.

enum Category {
	STALKER,     ## Observes, disappears, attacks unexpectedly.
	WARDEN,      ## Defends an area, controls space with positioning.
	DISTORTER,   ## Changes the environment during combat.
	MIMIC,       ## Imitates characters, objects or other creatures.
	FRAGMENTED,  ## Moves unpredictably, may split into multiple forms.
	HUNTER,      ## Actively pursues the protagonist across a level section.
	MEMORY_EATER ## Manipulates the player's abilities or combat resources.
}

enum ResolutionKind { DESTROY, CAPTURE, RELEASE, RECONCILE }

@export var id: StringName = &""
@export var display_name: String = ""
@export_category("Identity")
@export var category: Category = Category.STALKER
@export_multiline var summary: String = ""
@export_multiline var emotional_origin: String = ""

@export_category("Combat stats")
@export var max_health: float = 60.0
@export var contact_damage: float = 8.0
@export var move_speed: float = 90.0
@export var attack_damage: float = 10.0
@export var attack_range: float = 70.0
@export var detect_range: float = 260.0
@export var attack_startup: float = 0.38    ## Telegraph window: readable by design (GDD 19).
@export var attack_recovery: float = 0.55
@export var stagger_threshold: float = 26.0
@export var dodge_chance: float = 0.0
@export var can_teleport: bool = false

@export_category("Revealed structure (GDD 6)")
## True vulnerability. Not necessarily anatomical: may be a forgotten name,
## a repeating memory, a broken promise, a trapped voice, a symbol...
@export_multiline var revealed_trait: String = ""
@export var revealed_trait_kind: String = "memory"
@export var damage_multiplier_when_revealed: float = 2.5
@export_multiline var revelation_hint: String = ""
@export var requires_lantern_to_reveal: bool = true
@export var requires_anchor_to_hold: bool = false

@export_category("Resonance rewards (GDD 6)")
## Deliberately rewards intelligent play over raw damage output.
@export var resonance_on_precise_attack: float = 6.0
@export var resonance_on_counter: float = 16.0
@export var resonance_on_lantern_reveal: float = 12.0
@export var resonance_on_pattern_learned: float = 10.0
@export var resonance_on_environment: float = 9.0

@export_category("Resolution (GDD 6)")
@export var available_resolutions: Array[int] = [ResolutionKind.DESTROY]
@export var capture_requirement: String = ""
@export var release_requirement: String = ""
@export var reconcile_requirement: String = ""
@export var grants_echo_on_release: StringName = &""
@export var grants_echo_on_capture: StringName = &""

@export_category("Narrative")
@export_multiline var journal_entry_on_discovery: String = ""
@export_multiline var journal_entry_on_understanding: String = ""

@export_category("Presentation")
@export var body_color: Color = Color(0.55, 0.35, 0.75)
@export var revealed_color: Color = Color(0.95, 0.88, 0.62)
@export var telegraph_color: Color = Color(1.0, 0.35, 0.35)


## Builds a NightmareData from an authored JSON record.
static func from_dict(dict: Dictionary) -> NightmareData:
	var data := NightmareData.new()
	data.id = StringName(String(dict.get("id", "")))
	if data.id == &"":
		push_warning("NightmareData.from_dict: record has no id")
		return null
	data.display_name = String(dict.get("display_name", data.id))
	data.category = _parse_category(String(dict.get("category", "stalker")))
	data.summary = String(dict.get("summary", ""))
	data.emotional_origin = String(dict.get("emotional_origin", ""))

	data.max_health = float(dict.get("max_health", data.max_health))
	data.contact_damage = float(dict.get("contact_damage", data.contact_damage))
	data.move_speed = float(dict.get("move_speed", data.move_speed))
	data.attack_damage = float(dict.get("attack_damage", data.attack_damage))
	data.attack_range = float(dict.get("attack_range", data.attack_range))
	data.detect_range = float(dict.get("detect_range", data.detect_range))
	data.attack_startup = float(dict.get("attack_startup", data.attack_startup))
	data.attack_recovery = float(dict.get("attack_recovery", data.attack_recovery))
	data.stagger_threshold = float(dict.get("stagger_threshold", data.stagger_threshold))
	data.dodge_chance = float(dict.get("dodge_chance", data.dodge_chance))
	data.can_teleport = bool(dict.get("can_teleport", data.can_teleport))

	data.revealed_trait = String(dict.get("revealed_trait", ""))
	data.revealed_trait_kind = String(dict.get("revealed_trait_kind", data.revealed_trait_kind))
	data.damage_multiplier_when_revealed = float(
		dict.get("damage_multiplier_when_revealed", data.damage_multiplier_when_revealed)
	)
	data.revelation_hint = String(dict.get("revelation_hint", ""))
	data.requires_lantern_to_reveal = bool(dict.get("requires_lantern_to_reveal", data.requires_lantern_to_reveal))
	data.requires_anchor_to_hold = bool(dict.get("requires_anchor_to_hold", data.requires_anchor_to_hold))

	data.resonance_on_precise_attack = float(
		dict.get("resonance_on_precise_attack", data.resonance_on_precise_attack)
	)
	data.resonance_on_counter = float(dict.get("resonance_on_counter", data.resonance_on_counter))
	data.resonance_on_lantern_reveal = float(
		dict.get("resonance_on_lantern_reveal", data.resonance_on_lantern_reveal)
	)
	data.resonance_on_pattern_learned = float(
		dict.get("resonance_on_pattern_learned", data.resonance_on_pattern_learned)
	)
	data.resonance_on_environment = float(
		dict.get("resonance_on_environment", data.resonance_on_environment)
	)

	data.available_resolutions = _parse_resolutions(dict.get("available_resolutions", ["destroy"]))
	data.capture_requirement = String(dict.get("capture_requirement", ""))
	data.release_requirement = String(dict.get("release_requirement", ""))
	data.reconcile_requirement = String(dict.get("reconcile_requirement", ""))
	data.grants_echo_on_release = StringName(String(dict.get("grants_echo_on_release", "")))
	data.grants_echo_on_capture = StringName(String(dict.get("grants_echo_on_capture", "")))

	data.journal_entry_on_discovery = String(dict.get("journal_entry_on_discovery", ""))
	data.journal_entry_on_understanding = String(dict.get("journal_entry_on_understanding", ""))

	data.body_color = _parse_color(dict.get("body_color", null), data.body_color)
	data.revealed_color = _parse_color(dict.get("revealed_color", null), data.revealed_color)
	data.telegraph_color = _parse_color(dict.get("telegraph_color", null), data.telegraph_color)
	return data


static func _parse_category(value: String) -> int:
	match value.to_lower():
		"stalker": return Category.STALKER
		"warden": return Category.WARDEN
		"distorter": return Category.DISTORTER
		"mimic": return Category.MIMIC
		"fragmented": return Category.FRAGMENTED
		"hunter": return Category.HUNTER
		"memory_eater": return Category.MEMORY_EATER
	push_warning("NightmareData: unknown category '%s'" % value)
	return Category.STALKER


static func _parse_resolutions(raw: Variant) -> Array[int]:
	var out: Array[int] = []
	var values: Array = raw if raw is Array else []
	for entry: Variant in values:
		match String(entry).to_lower():
			"destroy": out.append(ResolutionKind.DESTROY)
			"capture": out.append(ResolutionKind.CAPTURE)
			"release": out.append(ResolutionKind.RELEASE)
			"reconcile": out.append(ResolutionKind.RECONCILE)
	if out.is_empty():
		out.append(ResolutionKind.DESTROY)
	return out


static func _parse_color(raw: Variant, fallback: Color) -> Color:
	if raw is Array and (raw as Array).size() >= 3:
		var values: Array = raw
		return Color(float(values[0]), float(values[1]), float(values[2]))
	return fallback


func category_name() -> String:
	match category:
		Category.STALKER: return "Stalker"
		Category.WARDEN: return "Warden"
		Category.DISTORTER: return "Distorter"
		Category.MIMIC: return "Mimic"
		Category.FRAGMENTED: return "Fragmented"
		Category.HUNTER: return "Hunter"
		Category.MEMORY_EATER: return "Memory Eater"
	return "Unknown"


func resolution_label(kind: int) -> String:
	match kind:
		ResolutionKind.DESTROY: return "Destroy"
		ResolutionKind.CAPTURE: return "Capture"
		ResolutionKind.RELEASE: return "Release"
		ResolutionKind.RECONCILE: return "Reconcile"
	return "Unknown"
