extends Node

# Chronoflora - EraManager
# Manages temporal era shifting and cross-era state.

signal era_shifted(old_era, new_era)

const ERA_PRE_BLOOM = "pre_bloom"
const ERA_ROOTED_AGE = "rooted_age"
var ERAS = [ERA_PRE_BLOOM, ERA_ROOTED_AGE]

var current_era = ERA_PRE_BLOOM
var previous_era = null
var shift_count = 0

const ERA_DISPLAY_NAMES = {
	ERA_PRE_BLOOM: "Pre-Bloom",
	ERA_ROOTED_AGE: "Rooted Age",
}

func shift_era():
	"""Shift to the next era."""
	previous_era = current_era
	var current_index = ERAS.find(current_era)
	var next_index = (current_index + 1) % ERAS.size()
	current_era = ERAS[next_index]
	shift_count += 1
	era_shifted.emit(previous_era, current_era)

func get_current_era():
	return current_era

func get_previous_era():
	return previous_era

func get_display_name(era: String = ""):
	if era == "":
		era = current_era
	return ERA_DISPLAY_NAMES.get(era, era)

func get_other_era():
	for era in ERAS:
		if era != current_era:
			return era
	return null
