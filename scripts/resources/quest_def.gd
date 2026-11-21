class_name QuestDef
extends Resource
## A quest definition (GDD section 16).
##
## Every quest must have a narrative reason to exist, distinct objectives,
## meaningful discoveries, interesting gameplay, appropriate rewards and a
## visible journal record. No fetch padding.

enum Kind { MAIN_STORY, HUNTING_CONTRACT, CHARACTER_STORY, REGIONAL_MYSTERY, LEGENDARY_HUNT, HIDDEN }

@export var id: StringName = &""
@export var title: String = ""
@export var kind: Kind = Kind.MAIN_STORY
@export_multiline var narrative_reason: String = ""
@export var objectives: Array[String] = []
@export var target_nightmare: StringName = &""
@export var region: StringName = &""
@export var reward_experience: int = 0
@export var reward_fragments: int = 0
@export var reward_echo: StringName = &""
@export_multiline var journal_record: String = ""


static func from_dict(dict: Dictionary) -> QuestDef:
	var data := QuestDef.new()
	data.id = StringName(String(dict.get("id", "")))
	if data.id == &"":
		push_warning("QuestDef.from_dict: record has no id")
		return null
	data.title = String(dict.get("title", data.id))
	match String(dict.get("kind", "main_story")).to_lower():
		"hunting_contract": data.kind = Kind.HUNTING_CONTRACT
		"character_story": data.kind = Kind.CHARACTER_STORY
		"regional_mystery": data.kind = Kind.REGIONAL_MYSTERY
		"legendary_hunt": data.kind = Kind.LEGENDARY_HUNT
		"hidden": data.kind = Kind.HIDDEN
		_: data.kind = Kind.MAIN_STORY
	data.narrative_reason = String(dict.get("narrative_reason", ""))
	var objectives: Variant = dict.get("objectives", [])
	if objectives is Array:
		for objective: Variant in objectives:
			data.objectives.append(String(objective))
	data.target_nightmare = StringName(String(dict.get("target_nightmare", "")))
	data.region = StringName(String(dict.get("region", "")))
	data.reward_experience = int(dict.get("reward_experience", 0))
	data.reward_fragments = int(dict.get("reward_fragments", 0))
	data.reward_echo = StringName(String(dict.get("reward_echo", "")))
	data.journal_record = String(dict.get("journal_record", ""))
	return data


func kind_name() -> String:
	match kind:
		Kind.MAIN_STORY: return "Main Story"
		Kind.HUNTING_CONTRACT: return "Hunting Contract"
		Kind.CHARACTER_STORY: return "Character Story"
		Kind.REGIONAL_MYSTERY: return "Regional Mystery"
		Kind.LEGENDARY_HUNT: return "Legendary Hunt"
		Kind.HIDDEN: return "Hidden Quest"
	return "Quest"
