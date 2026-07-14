extends Node3D

const LAMP_RANGE_NIGHT := 6.0
const LAMP_ENERGY_NIGHT := 2.0

var _light: OmniLight3D
var _bulb: MeshInstance3D


func _ready() -> void:
	_light = get_node_or_null("OmniLight3D") as OmniLight3D
	_bulb = get_node_or_null("Bulb") as MeshInstance3D


func _process(_delta: float) -> void:
	if _light == null:
		_light = get_node_or_null("OmniLight3D") as OmniLight3D
		if _light == null:
			return

	var night := _night_strength()
	_light.light_energy = lerpf(0.0, LAMP_ENERGY_NIGHT, night)
	_light.omni_range = lerpf(0.0, LAMP_RANGE_NIGHT, night)
	if _bulb and _bulb.material_override is StandardMaterial3D:
		var mat := _bulb.material_override as StandardMaterial3D
		mat.emission_energy_multiplier = lerpf(0.15, 2.8, night)


func _night_strength() -> float:
	var sun := get_tree().get_first_node_in_group("day_night")
	if sun and sun.has_method("get_day_factor"):
		return 1.0 - clampf(sun.call("get_day_factor"), 0.0, 1.0)
	return 0.5
