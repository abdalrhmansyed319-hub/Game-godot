class_name SkillDef
extends Resource
## One node of the three-path skill tree (GDD section 9).
##
## path 0 = The Blade, 1 = The Lantern, 2 = The Anchor.

@export var id: StringName = &""
@export var display_name: String = ""
@export_range(0, 2) var path: int = 0
@export var tier: int = 1
@export var cost: int = 1
@export var requires: Array[StringName] = []
@export_multiline var description: String = ""
## Machine-readable effect key consumed by the relevant system.
@export var effect_key: StringName = &""
@export var effect_value: float = 1.0


static func from_dict(dict: Dictionary) -> SkillDef:
	var data := SkillDef.new()
	data.id = StringName(String(dict.get("id", "")))
	if data.id == &"":
		push_warning("SkillDef.from_dict: record has no id")
		return null
	data.display_name = String(dict.get("display_name", data.id))
	match String(dict.get("path", "blade")).to_lower():
		"lantern": data.path = SkillPath.LANTERN
		"anchor": data.path = SkillPath.ANCHOR
		_: data.path = SkillPath.BLADE
	data.tier = int(dict.get("tier", data.tier))
	data.cost = int(dict.get("cost", data.cost))
	data.requires.clear()
	var prerequisites: Variant = dict.get("requires", [])
	if prerequisites is Array:
		for prerequisite: Variant in prerequisites:
			data.requires.append(StringName(String(prerequisite)))
	data.description = String(dict.get("description", ""))
	data.effect_key = StringName(String(dict.get("effect_key", "")))
	data.effect_value = float(dict.get("effect_value", data.effect_value))
	return data


func path_name() -> String:
	match path:
		0: return "The Blade"
		1: return "The Lantern"
		2: return "The Anchor"
	return "Unknown"
