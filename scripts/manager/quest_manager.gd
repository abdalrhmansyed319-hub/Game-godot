extends Node
## QuestManager — quest lifecycle and objective tracking (GDD 16).

signal quest_started(quest_id: StringName)
signal quest_objective_completed(quest_id: StringName, objective: String)
signal quest_completed(quest_id: StringName)
signal quest_failed(quest_id: StringName)

enum State { INACTIVE, ACTIVE, COMPLETED, FAILED }

var _definitions: Dictionary = {}
## quest_id -> {state, completed_objectives: Array[int]}
var _runtime: Dictionary = {}


func register(definition: QuestDef) -> void:
	if definition == null or definition.id == &"":
		return
	_definitions[definition.id] = definition


func register_all(definitions: Array[QuestDef]) -> void:
	for definition: QuestDef in definitions:
		register(definition)


func definition(quest_id: StringName) -> QuestDef:
	return _definitions.get(quest_id, null)


func start(quest_id: StringName) -> bool:
	if not _definitions.has(quest_id):
		return false
	if _runtime.has(quest_id) and state_of(quest_id) != State.INACTIVE:
		return false
	_runtime[quest_id] = {"state": State.ACTIVE, "completed_objectives": []}
	var definition: QuestDef = _definitions[quest_id]
	JournalManager.discover(
		StringName("quest_" + String(quest_id)),
		JournalManager.Category.QUEST,
		definition.title,
		definition.narrative_reason
	)
	quest_started.emit(quest_id)
	return true


func state_of(quest_id: StringName) -> int:
	if not _runtime.has(quest_id):
		return State.INACTIVE
	return int((_runtime[quest_id] as Dictionary).get("state", State.INACTIVE))


func complete_objective(quest_id: StringName, objective_index: int) -> bool:
	if state_of(quest_id) != State.ACTIVE:
		return false
	var definition: QuestDef = _definitions.get(quest_id, null)
	if definition == null:
		return false
	if objective_index < 0 or objective_index >= definition.objectives.size():
		return false
	var completed: Array = _runtime[quest_id]["completed_objectives"]
	if completed.has(objective_index):
		return false
	completed.append(objective_index)
	quest_objective_completed.emit(quest_id, definition.objectives[objective_index])
	if completed.size() >= definition.objectives.size():
		complete(quest_id)
	return true


func complete_objective_by_text(quest_id: StringName, objective_text: String) -> bool:
	var definition: QuestDef = _definitions.get(quest_id, null)
	if definition == null:
		return false
	var index: int = definition.objectives.find(objective_text)
	if index < 0:
		return false
	return complete_objective(quest_id, index)


func complete(quest_id: StringName) -> void:
	if state_of(quest_id) == State.COMPLETED:
		return
	_runtime[quest_id]["state"] = State.COMPLETED
	var definition: QuestDef = _definitions.get(quest_id, null)
	if definition != null:
		if definition.reward_experience > 0:
			ProgressionManager.gain_experience(definition.reward_experience)
		if definition.reward_fragments > 0:
			GameManager.add_fragments(definition.reward_fragments)
		if definition.reward_echo != &"":
			EchoManager.collect(definition.reward_echo)
		JournalManager.discover(
			StringName("quest_done_" + String(quest_id)),
			JournalManager.Category.QUEST,
			"%s — resolved" % definition.title,
			definition.journal_record
		)
	quest_completed.emit(quest_id)


func fail(quest_id: StringName) -> void:
	if state_of(quest_id) != State.ACTIVE:
		return
	_runtime[quest_id]["state"] = State.FAILED
	quest_failed.emit(quest_id)


func active_quests() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for quest_id: StringName in _runtime.keys():
		if state_of(quest_id) != State.ACTIVE:
			continue
		var definition: QuestDef = _definitions.get(quest_id, null)
		if definition == null:
			continue
		out.append({
			"id": String(quest_id),
			"title": definition.title,
			"kind": definition.kind_name(),
			"objectives": definition.objectives.duplicate(),
			"completed": (_runtime[quest_id]["completed_objectives"] as Array).duplicate(),
		})
	return out


func to_dict() -> Dictionary:
	return {"runtime": _runtime.duplicate(true)}


func from_dict(data: Dictionary) -> void:
	_runtime = (data.get("runtime", {}) as Dictionary).duplicate(true)
