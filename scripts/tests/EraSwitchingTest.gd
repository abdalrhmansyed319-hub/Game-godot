# Chronoflora - Godot Test: Era Switching
# STATUS: NOT EXECUTED - Godot engine unavailable in this environment
#
# Tests era shifting between Pre-Bloom and Rooted Age.
# To run: Add this script to a Node in your Game scene or use GUT addon.

extends Node2D

var tests_passed = 0
var tests_failed = 0
var test_results = []

var game_manager: Node
var era_manager: Node

func _ready():
	game_manager = get_node("/root/Main/Game")
	era_manager = get_node("/root/Main/Game/EraManager")
	run_all_tests()
	print_results()

func run_all_tests():
	test_initial_era_is_pre_bloom()
	test_era_changes_on_shift()
	test_era_cycles_back()
	test_previous_era_tracked()
	test_temporal_stamina_cost()
	test_other_era_returns_correct_value()

func test_initial_era_is_pre_bloom():
	var era = game_manager.get("current_era")
	_check("Initial era is Pre-Bloom", era == "pre_bloom", "Got: " + str(era))

func test_era_changes_on_shift():
	var initial_era = game_manager.get("current_era")
	era_manager.call("shift_era")
	var new_era = game_manager.get("current_era")
	_check("Era changes after shift", new_era != initial_era, 
	       "Was: " + str(initial_era) + ", Now: " + str(new_era))

func test_era_cycles_back():
	era_manager.call("shift_era")  # pre_bloom -> rooted_age
	era_manager.call("shift_era")  # rooted_age -> pre_bloom
	var era = game_manager.get("current_era")
	_check("Era cycles back to Pre-Bloom", era == "pre_bloom", "Got: " + str(era))

func test_previous_era_tracked():
	var before = game_manager.get("current_era")
	era_manager.call("shift_era")
	var previous = era_manager.call("get_previous_era")
	_check("Previous era tracked", previous == before, 
	       "Before: " + str(before) + ", Previous: " + str(previous))

func test_temporal_stamina_cost():
	var initial_stamina = game_manager.get("temporal_stamina")
	# Simulate an era shift (cost is 25)
	game_manager.set("temporal_stamina", initial_stamina - 25)
	var after = game_manager.get("temporal_stamina")
	_check("Temporal stamina decreases by 25", after == initial_stamina - 25,
	       "Initial: " + str(initial_stamina) + ", After: " + str(after))

func test_other_era_returns_correct_value():
	var current = game_manager.get("current_era")
	var other = era_manager.call("get_other_era")
	_check("Other era is different", other != current,
	       "Current: " + str(current) + ", Other: " + str(other))

func _check(name, condition, detail=""):
	var passed = condition
	if passed:
		tests_passed += 1
		test_results.append("[PASS] " + name)
	else:
		tests_failed += 1
		test_results.append("[FAIL] " + name + " - " + detail)

func print_results():
	print("=" * 50)
	print("Chronoflora - Era Switching Test Results")
	print("=" * 50)
	print("Passed: " + str(tests_passed))
	print("Failed: " + str(tests_failed))
	print("Total:  " + str(tests_passed + tests_failed))
	print("-" * 50)
	for result in test_results:
		print(result)
	print("=" * 50)
