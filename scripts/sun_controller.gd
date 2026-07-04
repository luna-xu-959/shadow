extends Node3D

## Day/night sun orbit: daylight with shadows, night with no direct sunlight.
const CYCLE_SECONDS := 90.0
const SUNRISE_PHASE := 0.08
const SUNSET_PHASE := 0.58

@onready var _sun: DirectionalLight3D = $MainSun

var _cycle_phase: float = 0.22
var _world_env: WorldEnvironment


func _ready() -> void:
	add_to_group("day_night")
	_world_env = get_parent().get_node_or_null("WorldEnvironment") as WorldEnvironment
	_configure_sunlight()
	_apply_day_night(0.0)


func _configure_sunlight() -> void:
	_sun.add_to_group(ShadowRules.MAIN_SHADOW_LIGHT_GROUP)
	_sun.shadow_enabled = true
	_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	_sun.directional_shadow_max_distance = 120.0


func _process(delta: float) -> void:
	_cycle_phase = fposmod(_cycle_phase + delta / CYCLE_SECONDS, 1.0)
	_apply_day_night(delta)


func _apply_day_night(_delta: float) -> void:
	var day_factor := _compute_day_factor()
	var sunlit := day_factor > 0.06

	rotation.y = _cycle_phase * TAU
	var elevation := lerpf(-12.0, -58.0, day_factor)
	_sun.rotation_degrees = Vector3(elevation, 0.0, 0.0)

	_sun.visible = sunlit
	_sun.light_energy = lerpf(0.0, 1.85, day_factor)
	_sun.shadow_enabled = day_factor > 0.18
	_sun.light_color = Color(1.0, 0.94, 0.82).lerp(Color(0.55, 0.65, 0.95, 1.0), 1.0 - day_factor)

	if _world_env and _world_env.environment:
		var env := _world_env.environment
		var night := 1.0 - day_factor
		env.background_color = Color(0.62, 0.8, 0.96).lerp(Color(0.03, 0.05, 0.11), night)
		env.ambient_light_color = Color(0.78, 0.86, 0.95).lerp(Color(0.18, 0.22, 0.38), night)
		env.ambient_light_energy = lerpf(0.38, 0.14, night)
		env.adjustment_enabled = night > 0.45
		env.adjustment_brightness = lerpf(1.0, 1.08, night)


func _compute_day_factor() -> float:
	if _cycle_phase < SUNRISE_PHASE:
		return 0.0
	if _cycle_phase > SUNSET_PHASE:
		return 0.0
	var noon_phase := (_cycle_phase - SUNRISE_PHASE) / (SUNSET_PHASE - SUNRISE_PHASE)
	return sin(noon_phase * PI)


func get_sun_light() -> DirectionalLight3D:
	return _sun


func get_cycle_phase() -> float:
	return _cycle_phase


func get_day_factor() -> float:
	return _compute_day_factor()


func is_sunlit() -> bool:
	return _compute_day_factor() > 0.06


func get_time_label() -> String:
	if not is_sunlit():
		return "Night"
	var day_factor := _compute_day_factor()
	if day_factor > 0.82:
		return "Noon"
	if _cycle_phase < 0.5:
		return "Morning"
	return "Afternoon"
