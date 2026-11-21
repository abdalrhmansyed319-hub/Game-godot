class_name SkillPath
extends RefCounted
## SkillPath — the three hunter paths (GDD section 9).
##
## Lives in its own script with a `class_name` so it is globally addressable.
## An enum declared inside another script is NOT visible outside that script in
## Godot 4, so referencing it from elsewhere is a hard parse error; that bug
## took the whole project down to a cascade of "Failed to compile depended
## scripts" errors pointing at four unrelated files.

const BLADE: int = 0
const LANTERN: int = 1
const ANCHOR: int = 2


static func name_of(path: int) -> String:
	match path:
		BLADE: return "The Blade"
		LANTERN: return "The Lantern"
		ANCHOR: return "The Anchor"
	return "Unknown"
