extends CharacterBody3D

@export var peer_id: int = 1
@export var display_name: String = "玩家"
@export var body_tint: Color = Color(0.9, 0.9, 0.95)

const MOVE_SPEED := 6.5
const JUMP_SPEED := 7.0
const GRAVITY := 24.0

var _visual: MeshInstance3D


func _ready() -> void:
	add_to_group("match_players")
	_build_visual()
	if NetworkManager.is_online:
		set_multiplayer_authority(peer_id)


func configure_from_lobby(player_peer_id: int, payload: Dictionary) -> void:
	peer_id = player_peer_id
	display_name = str(payload.get("name", "玩家"))
	var character_id := str(payload.get("character_id", ""))
	var skin_id := str(payload.get("skin_id", "default"))
	var skin: Dictionary = CharacterCatalog.get_skin(character_id, skin_id)
	body_tint = CharacterCatalog.color_from_value(skin.get("tint", Color(0.9, 0.9, 0.95)), Color(0.9, 0.9, 0.95))
	name = "Player_%d" % peer_id
	if _visual:
		(_visual.material_override as StandardMaterial3D).albedo_color = body_tint


func _build_visual() -> void:
	var shape := CapsuleShape3D.new()
	shape.radius = 0.45
	shape.height = 1.2
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position = Vector3(0.0, 1.0, 0.0)
	add_child(collision)

	_visual = UiFactory.make_preview_mesh_instance(body_tint)
	add_child(_visual)


func _physics_process(delta: float) -> void:
	if NetworkManager.is_online and not is_multiplayer_authority():
		return

	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction := Vector3(input_dir.x, 0.0, input_dir.y)
	if direction.length_squared() > 0.01:
		direction = direction.normalized()
		velocity.x = direction.x * MOVE_SPEED
		velocity.z = direction.z * MOVE_SPEED
	else:
		velocity.x = move_toward(velocity.x, 0.0, MOVE_SPEED * delta * 4.0)
		velocity.z = move_toward(velocity.z, 0.0, MOVE_SPEED * delta * 4.0)

	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	elif Input.is_action_just_pressed("ui_accept"):
		velocity.y = JUMP_SPEED

	move_and_slide()
