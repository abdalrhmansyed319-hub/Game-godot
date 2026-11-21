extends Node
## NightmareDatabase — loads all authored content at boot (GDD 21).
##
## Content is authored as JSON under res://data/ and parsed into typed
## Resources here, so designers add creatures, Echoes, weapon forms, skills
## and quests without editing gameplay scripts. JSON is used instead of .tres
## so the project opens cleanly on any machine without regenerating UIDs.

const NIGHTMARE_DIR: String = "res://data/nightmares"
const ECHO_DIR: String = "res://data/echoes"
const WEAPON_DIR: String = "res://data/weapons"
const SKILL_DIR: String = "res://data/skills"
const QUEST_DIR: String = "res://data/quests"

var nightmares: Dictionary = {}
var echoes: Dictionary = {}
var weapons: Dictionary = {}
var skills: Dictionary = {}
var quests: Dictionary = {}


func _ready() -> void:
	reload()


func reload() -> void:
	nightmares = _load_dir(NIGHTMARE_DIR, "nightmare")
	echoes = _load_dir(ECHO_DIR, "echo")
	weapons = _load_dir(WEAPON_DIR, "weapon")
	skills = _load_dir(SKILL_DIR, "skill")
	quests = _load_dir(QUEST_DIR, "quest")
	_build_resources()


func _load_dir(path: String, kind: String) -> Dictionary:
	var out: Dictionary = {}
	var dir := DirAccess.open(path)
	if dir == null:
		push_warning("NightmareDatabase: missing data dir %s" % path)
		return out
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.get_extension() == "json":
			var parsed: Variant = _read_json(path.path_join(file_name))
			if parsed is Dictionary:
				var record: Dictionary = parsed
				record["__kind"] = kind
				out[String(record.get("id", file_name.get_basename()))] = record
		file_name = dir.get_next()
	dir.list_dir_end()
	return out


func _read_json(path: String) -> Variant:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("NightmareDatabase: cannot read %s" % path)
		return null
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed == null:
		push_warning("NightmareDatabase: invalid JSON in %s" % path)
	return parsed


func _build_resources() -> void:
	var nightmare_resources: Array[NightmareData] = []
	var echo_resources: Array[EchoData] = []
	var weapon_resources: Array[WeaponFormData] = []
	var skill_resources: Array[SkillDef] = []
	var quest_resources: Array[QuestDef] = []

	for key: String in nightmares.keys():
		var resource: NightmareData = NightmareData.from_dict(nightmares[key])
		if resource != null:
			nightmare_resources.append(resource)
	for key: String in echoes.keys():
		var resource: EchoData = EchoData.from_dict(echoes[key])
		if resource != null:
			echo_resources.append(resource)
	for key: String in weapons.keys():
		var resource: WeaponFormData = WeaponFormData.from_dict(weapons[key])
		if resource != null:
			weapon_resources.append(resource)
	for key: String in skills.keys():
		var resource: SkillDef = SkillDef.from_dict(skills[key])
		if resource != null:
			skill_resources.append(resource)
	for key: String in quests.keys():
		var resource: QuestDef = QuestDef.from_dict(quests[key])
		if resource != null:
			quest_resources.append(resource)

	for resource: NightmareData in nightmare_resources:
		nightmares[resource.id] = resource
	for resource: EchoData in echo_resources:
		echoes[resource.id] = resource
	for resource: WeaponFormData in weapon_resources:
		weapons[resource.id] = resource
	for resource: SkillDef in skill_resources:
		skills[resource.id] = resource

	QuestManager.register_all(quest_resources)
	ProgressionManager.register_skills(skill_resources)

	for resource: QuestDef in quest_resources:
		quests[resource.id] = resource


func nightmare(id: StringName) -> NightmareData:
	var value: Variant = nightmares.get(id, null)
	return value if value is NightmareData else null


func echo(id: StringName) -> EchoData:
	var value: Variant = echoes.get(id, null)
	return value if value is EchoData else null


func weapon(id: StringName) -> WeaponFormData:
	var value: Variant = weapons.get(id, null)
	return value if value is WeaponFormData else null


func all_nightmares() -> Array[NightmareData]:
	var out: Array[NightmareData] = []
	for key: String in nightmares.keys():
		if nightmares[key] is NightmareData:
			out.append(nightmares[key])
	return out


func all_echoes() -> Array[EchoData]:
	var out: Array[EchoData] = []
	for key: String in echoes.keys():
		if echoes[key] is EchoData:
			out.append(echoes[key])
	return out


func all_weapons() -> Array[WeaponFormData]:
	var out: Array[WeaponFormData] = []
	for key: String in weapons.keys():
		if weapons[key] is WeaponFormData:
			out.append(weapons[key])
	return out


func default_weapon() -> WeaponFormData:
	var all: Array[WeaponFormData] = all_weapons()
	return all[0] if not all.is_empty() else null
