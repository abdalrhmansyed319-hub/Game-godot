class_name WeaponFormData
extends Resource
## A form of the Reverberation Blade (GDD sections 4A and 11).
##
## Forms trade attack speed, damage, Resonance generation and counter
## generosity. No form is objectively superior (GDD 23.3).

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export_multiline var lore: String = ""

@export_category("Feel")
@export var light_damage: float = 7.0
@export var light_startup: float = 0.10
@export var light_recovery: float = 0.16
@export var heavy_damage: float = 18.0
@export var heavy_startup: float = 0.34
@export var heavy_recovery: float = 0.42
@export var charge_damage: float = 30.0
@export var charge_time: float = 0.9
@export var aerial_damage: float = 9.0
@export var attack_range: float = 56.0

@export_category("System interaction")
@export var resonance_per_hit: float = 5.0
@export var counter_window_bonus: float = 0.0
@export var stagger_power: float = 8.0
@export var move_speed_modifier: float = 1.0

@export_category("Presentation")
@export var blade_color: Color = Color(0.75, 0.85, 1.0)


static func from_dict(dict: Dictionary) -> WeaponFormData:
	var data := WeaponFormData.new()
	data.id = StringName(String(dict.get("id", "")))
	if data.id == &"":
		push_warning("WeaponFormData.from_dict: record has no id")
		return null
	data.display_name = String(dict.get("display_name", data.id))
	data.description = String(dict.get("description", ""))
	data.lore = String(dict.get("lore", ""))
	data.light_damage = float(dict.get("light_damage", data.light_damage))
	data.light_startup = float(dict.get("light_startup", data.light_startup))
	data.light_recovery = float(dict.get("light_recovery", data.light_recovery))
	data.heavy_damage = float(dict.get("heavy_damage", data.heavy_damage))
	data.heavy_startup = float(dict.get("heavy_startup", data.heavy_startup))
	data.heavy_recovery = float(dict.get("heavy_recovery", data.heavy_recovery))
	data.charge_damage = float(dict.get("charge_damage", data.charge_damage))
	data.charge_time = float(dict.get("charge_time", data.charge_time))
	data.aerial_damage = float(dict.get("aerial_damage", data.aerial_damage))
	data.attack_range = float(dict.get("attack_range", data.attack_range))
	data.resonance_per_hit = float(dict.get("resonance_per_hit", data.resonance_per_hit))
	data.counter_window_bonus = float(dict.get("counter_window_bonus", data.counter_window_bonus))
	data.stagger_power = float(dict.get("stagger_power", data.stagger_power))
	data.move_speed_modifier = float(dict.get("move_speed_modifier", data.move_speed_modifier))
	var tint: Variant = dict.get("blade_color", null)
	if tint is Array and (tint as Array).size() >= 3:
		var values: Array = tint
		data.blade_color = Color(float(values[0]), float(values[1]), float(values[2]))
	return data
