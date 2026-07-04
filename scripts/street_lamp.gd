extends Node3D

@onready var _light: OmniLight3D = $OmniLight3D
@onready var _bulb: MeshInstance3D = $Bulb


func _process(_delta: float) -> void:
	var night := _night_strength()
	_light.light_energy = lerpf(0.0, 2.4, night)
	_light.omni_range = lerpf(0.0, 11.0, night)
	if _bulb and _bulb.material_override is StandardMaterial3D:
		var mat := _bulb.material_override as StandardMaterial3D
		mat.emission_energy_multiplier = lerpf(0.15, 2.8, night)


func _night_strength() -> float:
	var sun := get_tree().get_first_node_in_group("day_night")
	if sun and sun.has_method("get_day_factor"):
		return 1.0 - clampf(sun.call("get_day_factor"), 0.0, 1.0)
	return 0.5
