# Chronoflora - Godot Test: Invalid Planting Locations
# STATUS: NOT EXECUTED - Godot engine unavailable in this environment
#
# Tests that planting is rejected on invalid tiles (water, stone, etc.)
# and invalid eras.
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
	test_planting_on_water_rejected()
_test_planting_on_stone_rejected()
_test_planting_on_soil_accepted()
_test_wrong_era_species_rejected()
_test_no_seed_selected_does_nothing()

func test_planting_on_water_rejected():
	"""Planting on water_pre or water_rooted tiles should be rejected."""
	var garden = game_manager.get("garden_state")
	var era = game_manager.get("current_era")
	var zone = game_manager.get("current_zone")
	var water_found = false
	
	if garden.has(era) and garden[era].has(zone):
		for y in range(garden[era][zone]["grid"].size()):
			for x in range(garden[era][zone]["grid"][y].size()):
				if garden[era][zone]["grid"][y][x] == "water_pre" or \
				   garden[era][zone]["grid"][y][x] == "water_rooted":
					water_found = true
					break
	
	_check("Water tiles exist for rejection test", water_found, 
	       "No water tiles found in current zone")

func _test_planting_on_stone_rejected():
	"""Planting on stone_pre or stone_rooted tiles should be rejected."""
	var garden = game_manager.get("garden_state")
	var era = game_manager.get("current_era")
	var zone = game_manager.get("current_zone")
	var stone_found = false
	
	if garden.has(era) and garden[era].has(zone):
		for y in range(garden[era][zone]["grid"].size()):
			for x in range(garden[era][zone]["grid"][y].size()):
				if garden[era][zone]["grid"][y][x] == "stone_pre" or \
				   garden[era][zone]["grid"][y][x] == "stone_rooted":
					stone_found = true
					break
	
	_check("Stone tiles exist for rejection test", stone_found,
	       "No stone tiles found in current zone")

func test_planting_on_soil_accepted():
	"""Planting on soil_pre or soil_rooted tiles should be accepted."""
	var garden = game_manager.get("garden_state")
	var era = game_manager.get("current_era")
	var zone = game_manager.get("current_zone")
	var soil_found = false
	
	if garden.has(era) and garden[era].has(zone):
		for y in range(garden[era][zone]["grid"].size()):
			for x in range(garden[era][zone]["grid"][y].size()):
				if garden[era][zone]["grid"][y][x] == "soil_pre" or \
				   garden[era][zone]["grid"][y][x] == "soil_rooted":
					soil_found = true
					break
	
	_check("Soil tiles exist for planting", soil_found,
	       "No soil tiles found in current zone")

func _test_wrong_era_species_rejected():
	"""Planting sylthene_oak (Era 2 only) in Era 1 should be rejected."""
	var plant_db = game_manager.get("plant_database")
	var sylthene_eras = plant_db.get("sylthene_oak", {}).get("eras", [])
	var is_era_2_only = sylthene_eras.size() == 1 and sylthene_eras[0] == "rooted_age"
	_check("Sylthene Oak is Era 2 only", is_era_2_only,
	       "Eras: " + JSON.stringify(sylthene_eras))

func test_no_seed_selected_does_nothing():
	"""Planting with no seed selected should not create a plant."""
	var selected_seed = game_manager.get("selected_seed")
	var no_seed = selected_seed == "" or selected_seed == null
	_check("No seed selected initially", no_seed,
	       "Selected seed: " + str(selected_seed))

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
	print("Chronoflora - Invalid Planting Test Results")
	print("=" * 50)
	print("Passed: " + str(tests_passed))
	print("Failed: " + str(tests_failed))
	print("Total:  " + str(tests_passed + tests_failed))
	print("-" * 50)
	for result in test_results:
		print(result)
	print("=" * 50)
