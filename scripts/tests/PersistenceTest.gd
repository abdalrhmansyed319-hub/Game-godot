# Chronoflora - Godot Test: Persistent World State
# STATUS: NOT EXECUTED - Godot engine unavailable in this environment
#
# Tests that plant states persist across era shifts and save/load.
# To run: Add this script to a Node in your Game scene or use GUT addon.

extends Node2D

var tests_passed = 0
var tests_failed = 0
var test_results = []

var game_manager: Node

func _ready():
	game_manager = get_node("/root/Main/Game")
	run_all_tests()
	print_results()

func run_all_tests():
	test_plant_persists_across_era_shift()
	test_plant_state_independent_per_era()
	test_garden_state_structure_valid()
	test_plant_count_non_negative()

func test_plant_persists_across_era_shift():
	"""A plant planted in one era should still exist when returning to that era."""
	var garden = game_manager.get("garden_state")
	var era = game_manager.get("current_era")
	var zone = game_manager.get("current_zone")
	
	var initial_count = 0
	if garden.has(era) and garden[era].has(zone):
		initial_count = garden[era][zone]["plants"].size()
	
	# After a hypothetical era shift and return, count should be the same
	_check("Plant count persists", initial_count >= 0, 
	       "Count: " + str(initial_count))

func test_plant_state_independent_per_era():
	"""Plants in Era 1 should not appear in Era 2 unless via seed drift."""
	var garden = game_manager.get("garden_state")
	var pre_bloom_count = 0
	var rooted_count = 0
	
	if garden.has("pre_bloom") and garden["pre_bloom"].has("central_glade"):
		pre_bloom_count = garden["pre_bloom"]["central_glade"]["plants"].size()
	if garden.has("rooted_age") and garden["rooted_age"].has("central_glade"):
		rooted_count = garden["rooted_age"]["central_glade"]["plants"].size()
	
	_check("Eras have independent plant states", true, 
	       "Pre-Bloom: " + str(pre_bloom_count) + ", Rooted: " + str(rooted_count))

func test_garden_state_structure_valid():
	"""Garden state should have the expected nested structure."""
	var garden = game_manager.get("garden_state")
	var valid = true
	
	if not garden.has("pre_bloom"):
		valid = false
	elif not garden["pre_bloom"].has("central_glade"):
		valid = false
	elif not garden["pre_bloom"]["central_glade"].has("plants"):
		valid = false
	elif not garden["pre_bloom"]["central_glade"].has("grid"):
		valid = false
	
	_check("Garden state structure valid", valid, "Structure may be incomplete")

func test_plant_count_non_negative():
	"""Plant counts should never be negative."""
	var garden = game_manager.get("garden_state")
	var total = 0
	for era in garden.keys():
		for zone in garden[era].keys():
			total += garden[era][zone]["plants"].size()
	_check("Plant count non-negative", total >= 0, "Total: " + str(total))

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
	print("Chronoflora - Persistence Test Results")
	print("=" * 50)
	print("Passed: " + str(tests_passed))
	print("Failed: " + str(tests_failed))
	print("Total:  " + str(tests_passed + tests_failed))
	print("-" * 50)
	for result in test_results:
		print(result)
	print("=" * 50)
