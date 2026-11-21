# Chronoflora - Godot Test Runner
# STATUS: NOT EXECUTED - Godot engine unavailable in this environment
#
# Runs all test suites and reports combined results.
# To run: Add this script to an Autoload or a Node in Main.tscn
#
# Usage in Godot editor:
# 1. Add TestRunner.gd as a script on a Node in your main scene
# 2. Or load it as an Autoload in Project Settings > Autoloads
# 3. Run the project and observe the output console

extends Node

func _ready():
	print("=" * 60)
	print("Chronoflora - Godot Test Suite")
	print("Status: NOT EXECUTED (Godot unavailable in build environment)")
	print("These tests must be run on a local machine with Godot 4.x")
	print("=" * 60)
	print("")
	print("Test suites available:")
	print("  1. scripts/tests/PlantGrowthTest.gd")
	print("  2. scripts/tests/EraSwitchingTest.gd")
	print("  3. scripts/tests/PersistenceTest.gd")
	print("  4. scripts/tests/RootEchoTest.gd")
	print("  5. scripts/tests/SaveLoadTest.gd")
	print("  6. scripts/tests/InvalidPlantingTest.gd")
	print("")
	print("To run individual tests, add the script to a Node in your scene.")
	print("To run all tests, instantiate each test script and call _ready().")
	print("=" * 60)
