class_name EchoData
extends Resource
## An Echo: a fragment of a resolved nightmare's nature (GDD section 10).
##
## An Echo is not a damage upgrade. Each one grants a distinct ability with a
## visual effect, an audio signature, a narrative origin, and specific uses in
## exploration or combat. Active slots are limited, so builds are choices.

enum Kind { EXPLORATION, COMBAT, INVESTIGATION, HYBRID }

@export var id: StringName = &""
@export var display_name: String = ""
@export var kind: Kind = Kind.HYBRID

@export_category("Origin")
@export var source_nightmare: StringName = &""
@export_multiline var narrative_origin: String = ""

@export_category("Effect")
## Machine-readable ability key consumed by PlayerAbilities / PlayerMovement.
## Examples: "gravity_flip", "hollow_voice", "unfinished_step", "borrowed_faces".
@export var ability_key: StringName = &""
@export var duration: float = 4.0
@export var cooldown: float = 12.0
@export var stamina_cost: float = 0.0
@export_multiline var effect_description: String = ""

@export_category("Presentation")
@export var tint: Color = Color(0.6, 0.8, 1.0)
## Placeholder audio signature until real SFX are produced.
@export_range(120.0, 2000.0) var audio_pitch_hz: float = 440.0


static func from_dict(dict: Dictionary) -> EchoData:
	var data := EchoData.new()
	data.id = StringName(String(dict.get("id", "")))
	if data.id == &"":
		push_warning("EchoData.from_dict: record has no id")
		return null
	data.display_name = String(dict.get("display_name", data.id))
	match String(dict.get("kind", "hybrid")).to_lower():
		"exploration": data.kind = Kind.EXPLORATION
		"combat": data.kind = Kind.COMBAT
		"investigation": data.kind = Kind.INVESTIGATION
		_: data.kind = Kind.HYBRID
	data.source_nightmare = StringName(String(dict.get("source_nightmare", "")))
	data.narrative_origin = String(dict.get("narrative_origin", ""))
	data.ability_key = StringName(String(dict.get("ability_key", "")))
	data.duration = float(dict.get("duration", data.duration))
	data.cooldown = float(dict.get("cooldown", data.cooldown))
	data.stamina_cost = float(dict.get("stamina_cost", data.stamina_cost))
	data.effect_description = String(dict.get("effect_description", ""))
	var tint: Variant = dict.get("tint", null)
	if tint is Array and (tint as Array).size() >= 3:
		var values: Array = tint
		data.tint = Color(float(values[0]), float(values[1]), float(values[2]))
	data.audio_pitch_hz = float(dict.get("audio_pitch_hz", data.audio_pitch_hz))
	return data


func kind_name() -> String:
	match kind:
		Kind.EXPLORATION: return "Exploration"
		Kind.COMBAT: return "Combat"
		Kind.INVESTIGATION: return "Investigation"
		Kind.HYBRID: return "Hybrid"
	return "Unknown"
