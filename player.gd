extends CharacterBody3D

signal boost_requested
signal health_changed(value: float)
signal died

@export var move_speed := 7.0
@export var acceleration := 18.0
@export var friction := 20.0
@export var max_health := 100.0

var health := 100.0
var move_stick := Vector2.ZERO
var boost_time := 0.0
var boost_cooldown := 0.0

func _ready() -> void:
	health = max_health
	collision_layer = 1
	collision_mask = 1
	_build_visual()

func _build_visual() -> void:
	var body_mesh := MeshInstance3D.new()
	var body := CapsuleMesh.new()
	body.radius = 0.48
	body.height = 1.5
	body.material = _mat(Color("#54d9ff"), 0.15, 0.2, Color("#54d9ff"), 1.7)
	body_mesh.mesh = body
	body_mesh.position.y = 0.85
	add_child(body_mesh)

	var visor := MeshInstance3D.new()
	var visor_mesh := BoxMesh.new()
	visor_mesh.size = Vector3(0.65, 0.18, 0.5)
	visor_mesh.material = _mat(Color("#e8fbff"), 0.15, 0.1, Color("#4ceaff"), 2.5)
	visor.mesh = visor_mesh
	visor.position = Vector3(0, 1.08, -0.4)
	add_child(visor)

	var pack := MeshInstance3D.new()
	var pack_mesh := BoxMesh.new()
	pack_mesh.size = Vector3(0.65, 0.8, 0.25)
	pack_mesh.material = _mat(Color("#15253e"), 0.2, 0.7, Color("#17334e"), 0.4)
	pack.mesh = pack_mesh
	pack.position = Vector3(0, 0.82, 0.42)
	add_child(pack)

	var collider := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.46
	shape.height = 1.5
	collider.shape = shape
	collider.position.y = 0.85
	add_child(collider)

func _physics_process(delta: float) -> void:
	if get_tree().paused:
		return
	boost_cooldown = max(0.0, boost_cooldown - delta)
	boost_time = max(0.0, boost_time - delta)
	var keyboard := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var input_vector := move_stick if move_stick.length() > 0.05 else keyboard
	var current_speed := move_speed * (1.9 if boost_time > 0.0 else 1.0)
	var desired := Vector3(input_vector.x, 0.0, input_vector.y) * current_speed
	velocity.x = move_toward(velocity.x, desired.x, acceleration * delta)
	velocity.z = move_toward(velocity.z, desired.z, acceleration * delta)
	if input_vector.length() < 0.05:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)
		velocity.z = move_toward(velocity.z, 0.0, friction * delta)
	if desired.length() > 0.3:
		rotation.y = lerp_angle(rotation.y, atan2(-desired.x, -desired.z), min(1.0, 10.0 * delta))
	move_and_slide()

func set_move_input(value: Vector2) -> void:
	move_stick = value.limit_length(1.0)

func clear_move_input() -> void:
	move_stick = Vector2.ZERO

func boost() -> void:
	if boost_cooldown > 0.0 or get_tree().paused:
		return
	boost_time = 0.65
	boost_cooldown = 2.0
	boost_requested.emit()

func take_damage(amount: float) -> void:
	if health <= 0.0:
		return
	health = max(0.0, health - amount)
	health_changed.emit(health)
	if health <= 0.0:
		died.emit()

func heal(amount: float) -> void:
	health = min(max_health, health + amount)
	health_changed.emit(health)

func _mat(color: Color, metallic: float, roughness: float, emission: Color, energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	material.emission_enabled = true
	material.emission = emission
	material.emission_energy_multiplier = energy
	return material
