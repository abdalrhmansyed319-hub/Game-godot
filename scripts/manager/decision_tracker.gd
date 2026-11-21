extends Node
## DecisionTracker — records the decisions that actually change the world
## (GDD 15). Trivial dialogue choices are deliberately NOT tracked.

signal decision_recorded(decision_id: StringName, value: StringName)
## Emitted when a recorded decision makes an option available or unavailable.
signal consequence_triggered(decision_id: StringName, value: StringName)

var decisions: Dictionary = {}


func record(decision_id: StringName, value: StringName) -> void:
	var previous: Variant = decisions.get(decision_id, null)
	decisions[decision_id] = value
	decision_recorded.emit(decision_id, value)
	if previous != null and previous != value:
		consequence_triggered.emit(decision_id, value)
	else:
		consequence_triggered.emit(decision_id, value)


func value_of(decision_id: StringName) -> StringName:
	return decisions.get(decision_id, &"")


func has_made(decision_id: StringName) -> bool:
	return decisions.has(decision_id)


func is_value(decision_id: StringName, value: StringName) -> bool:
	return decisions.get(decision_id, &"") == value


## True when every requirement in `requirements` (decision_id -> expected value) holds.
func requirements_met(requirements: Dictionary) -> bool:
	for decision_id: StringName in requirements.keys():
		if decisions.get(decision_id, &"") != requirements[decision_id]:
			return false
	return true


func clear() -> void:
	decisions.clear()


func to_dict() -> Dictionary:
	return {"decisions": decisions.duplicate(true)}


func from_dict(data: Dictionary) -> void:
	decisions = (data.get("decisions", {}) as Dictionary).duplicate(true)
