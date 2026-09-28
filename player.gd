extends CharacterBody3D

signal boost_requested
signal fire_requested(origin: Vector3, direction: Vector3, damage: float)
signal health_changed(value: float)
signal energy_changed(value: float)
signal died

@export var move_speed := 7.6
@export var acceleration := 22.0
@export var friction := 24.0
@export var max_health := 100.0
@export var max_energy := 100.0
@export var fire_rate := 0.18
@export var shot_damage := 24.0

var health := 100.0
var energy := 100.0
var move_stick := Vector2.ZERO
var fire_input := false
var boost_time := 0.0
var boost_cooldown := 0.0
var fire_cooldown := 0.0
var anim_time := 0.0
var invulnerability := 0.0
var torso: Node3D
var head: Node3D
var left_leg: Node3D
var right_leg: Node3D
var weapon: Node3D
var weapon_flash: OmniLight3D

func _ready() -> void:
	collision_layer = 1
	collision_mask = 1
	_build_visual()

func _build_visual() -> void:
	torso = Node3D.new()
	torso.name = "Torso"
	add_child(torso)

	var chest := MeshInstance3D.new()
	var chest_mesh := CapsuleMesh.new()
	chest_mesh.radius = 0.48
	chest_mesh.height = 1.18
	chest_mesh.material = _mat(Color("#32302c"), 0.72, 0.34, Color("#a88452"), 0.18)
	chest.mesh = chest_mesh
	chest.scale = Vector3(1.0, 1.0, 0.72)
	chest.position.y = 1.24
	torso.add_child(chest)

	var abdomen := MeshInstance3D.new()
	var abdomen_mesh := CapsuleMesh.new()
	abdomen_mesh.radius = 0.34
	abdomen_mesh.height = 0.72
	abdomen_mesh.material = _mat(Color("#242321"), 0.64, 0.42, Color("#6f5b43"), 0.10)
	abdomen.mesh = abdomen_mesh
	abdomen.scale = Vector3(1.0, 1.0, 0.72)
	abdomen.position = Vector3(0, 0.60, 0)
	torso.add_child(abdomen)

	head = Node3D.new()
	head.name = "Head"
	torso.add_child(head)
	var helmet := MeshInstance3D.new()
	var helmet_mesh := SphereMesh.new()
	helmet_mesh.radius = 0.39
	helmet_mesh.height = 0.72
	helmet_mesh.material = _mat(Color("#3b3935"), 0.68, 0.30, Color("#b18c59"), 0.16)
	helmet.mesh = helmet_mesh
	helmet.position = Vector3(0, 0.82, 0)
	head.add_child(helmet)
	var visor := MeshInstance3D.new()
	var visor_mesh := CapsuleMesh.new()
	visor_mesh.radius = 0.17
	visor_mesh.height = 0.48
	visor_mesh.material = _mat(Color("#171817"), 0.78, 0.18, Color("#c09a60"), 0.30)
	visor.mesh = visor_mesh
	visor.scale = Vector3(1.0, 0.34, 0.38)
	visor.rotation_degrees.z = 90.0
	visor.position = Vector3(0, 0.79, -0.33)
	head.add_child(visor)

	for x in [-1.0, 1.0]:
		var shoulder := MeshInstance3D.new()
		var shoulder_mesh := SphereMesh.new()
		shoulder_mesh.radius = 0.24
		shoulder_mesh.height = 0.44
		shoulder_mesh.material = _mat(Color("#403d37"), 0.70, 0.30, Color("#8d7049"), 0.12)
		shoulder.mesh = shoulder_mesh
		shoulder.position = Vector3(x * 0.65, 1.40, 0)
		torso.add_child(shoulder)

		var arm := MeshInstance3D.new()
		var arm_mesh := CapsuleMesh.new()
		arm_mesh.radius = 0.16
		arm_mesh.height = 0.94
		arm_mesh.material = _mat(Color("#292825"), 0.60, 0.40, Color("#6e5941"), 0.10)
		arm.mesh = arm_mesh
		arm.position = Vector3(x * 0.70, 0.98, -0.02)
		arm.rotation_degrees.z = x * -8.0
		torso.add_child(arm)

	left_leg = _build_leg("LeftLeg", -0.27)
	right_leg = _build_leg("RightLeg", 0.27)

	weapon = Node3D.new()
	weapon.name = "Weapon"
	weapon.position = Vector3(0.0, 1.03, -0.58)
	add_child(weapon)
	var barrel := MeshInstance3D.new()
	var barrel_mesh := CylinderMesh.new()
	barrel_mesh.top_radius = 0.095
	barrel_mesh.bottom_radius = 0.13
	barrel_mesh.height = 0.76
	barrel_mesh.material = _mat(Color("#181917"), 0.78, 0.28, Color("#b18c59"), 0.20)
	barrel.mesh = barrel_mesh
	barrel.rotation_degrees.x = 90.0
	barrel.position.z = -0.34
	weapon.add_child(barrel)

	var grip := MeshInstance3D.new()
	var grip_mesh := CapsuleMesh.new()
	grip_mesh.radius = 0.12
	grip_mesh.height = 0.42
	grip_mesh.material = _mat(Color("#232220"), 0.58, 0.44, Color("#6e5a43"), 0.08)
	grip.mesh = grip_mesh
	grip.rotation_degrees.x = 15.0
	grip.position = Vector3(0, -0.20, 0.05)
	weapon.add_child(grip)

	var pack := MeshInstance3D.new()
	var pack_mesh := CapsuleMesh.new()
	pack_mesh.radius = 0.25
	pack_mesh.height = 0.88
	pack_mesh.material = _mat(Color("#242320"), 0.55, 0.48, Color("#6d5942"), 0.08)
	pack.mesh = pack_mesh
	pack.scale = Vector3(1.2, 1.0, 0.55)
	pack.position = Vector3(0, 1.04, 0.48)
	add_child(pack)

	var thruster := GPUParticles3D.new()
	thruster.name = "Thruster"
	thruster.amount = 6
	thruster.lifetime = 0.30
	thruster.position = Vector3(0, 0.42, 0.42)
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 0, 1)
	pm.spread = 14.0
	pm.initial_velocity_min = 0.8
	pm.initial_velocity_max = 1.8
	pm.scale_min = 0.025
	pm.scale_max = 0.06
	pm.color = Color("#b18c59")
	thruster.process_material = pm
	var particle_mesh := SphereMesh.new()
	particle_mesh.radius = 0.04
	particle_mesh.height = 0.08
	particle_mesh.material = _mat(Color("#b18c59"), 0.0, 0.16, Color("#b18c59"), 0.7)
	thruster.draw_pass_1 = particle_mesh
	thruster.emitting = true
	add_child(thruster)

	var collider := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.46
	shape.height = 1.85
	collider.shape = shape
	collider.position.y = 0.95
	add_child(collider)


func _build_leg(node_name: String, x: float) -> Node3D:
	var leg := Node3D.new()
	leg.name = node_name
	leg.position = Vector3(x, 0.55, 0)
	add_child(leg)
	var mesh := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.18
	capsule.height = 1.02
	capsule.material = _mat(Color("#292825"), 0.62, 0.40, Color("#6f5b43"), 0.08)
	mesh.mesh = capsule
	leg.add_child(mesh)
	var boot := MeshInstance3D.new()
	var boot_mesh := CapsuleMesh.new()
	boot_mesh.radius = 0.14
	boot_mesh.height = 0.48
	boot_mesh.material = _mat(Color("#171715"), 0.72, 0.34, Color("#8b7049"), 0.10)
	boot.mesh = boot_mesh
	boot.scale = Vector3(1.15, 0.48, 1.65)
	boot.rotation_degrees.x = 90.0
	boot.position = Vector3(0, -0.47, -0.15)
	leg.add_child(boot)
	return leg

func _physics_process(delta: float) -> void:
	if get_tree().paused:
		return
	anim_time += delta
	boost_cooldown = max(0.0, boost_cooldown - delta)
	boost_time = max(0.0, boost_time - delta)
	fire_cooldown = max(0.0, fire_cooldown - delta)
	invulnerability = max(0.0, invulnerability - delta)

	energy = min(max_energy, energy + delta * 10.0)
	energy_changed.emit(energy)

	var keyboard := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var input_vector := move_stick if move_stick.length() > 0.05 else keyboard
	var current_speed := move_speed * (1.85 if boost_time > 0.0 else 1.0)
	var desired := Vector3(input_vector.x, 0.0, input_vector.y) * current_speed
	velocity.x = move_toward(velocity.x, desired.x, acceleration * delta)
	velocity.z = move_toward(velocity.z, desired.z, acceleration * delta)
	if input_vector.length() < 0.05:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)
		velocity.z = move_toward(velocity.z, 0.0, friction * delta)

	if desired.length() > 0.3:
		rotation.y = lerp_angle(rotation.y, atan2(-desired.x, -desired.z), min(1.0, 11.0 * delta))

	move_and_slide()

	if fire_input or Input.is_action_pressed("ui_accept"):
		shoot()

	_update_animation(delta)

func _update_animation(delta: float) -> void:
	var movement := Vector2(velocity.x, velocity.z).length()
	var run_phase := anim_time * (7.0 + movement * 0.8)
	if left_leg and right_leg:
		left_leg.rotation.x = sin(run_phase) * min(0.35, movement * 0.045)
		right_leg.rotation.x = -sin(run_phase) * min(0.35, movement * 0.045)
	if torso:
		torso.position.y = 0.035 + sin(anim_time * 3.0) * (0.018 if movement < 0.2 else 0.045)
	if head:
		head.rotation.z = sin(anim_time * 2.3) * 0.018
	if weapon:
		weapon.rotation.x = lerp(weapon.rotation.x, -0.04 if movement < 0.2 else -0.08, min(1.0, delta * 8.0))

func shoot() -> void:
	if fire_cooldown > 0.0 or get_tree().paused or health <= 0.0:
		return
	fire_cooldown = fire_rate
	var direction := -global_transform.basis.z
	var origin := global_position + Vector3.UP * 1.3 + direction * 0.95
	fire_requested.emit(origin, direction, shot_damage)

func boost() -> void:
	if boost_cooldown > 0.0 or energy < 28.0 or get_tree().paused:
		return
	boost_time = 0.65
	boost_cooldown = 2.0
	energy -= 28.0
	energy_changed.emit(energy)
	boost_requested.emit()

func set_move_input(value: Vector2) -> void:
	move_stick = value.limit_length(1.0)

func clear_move_input() -> void:
	move_stick = Vector2.ZERO

func set_fire_input(value: bool) -> void:
	fire_input = value

func take_damage(amount: float) -> void:
	if health <= 0.0 or invulnerability > 0.0:
		return
	invulnerability = 0.28
	health = max(0.0, health - amount)
	health_changed.emit(health)
	if health <= 0.0:
		died.emit()

func heal(amount: float) -> void:
	health = min(max_health, health + amount)
	health_changed.emit(health)

func restore_energy(amount: float) -> void:
	energy = min(max_energy, energy + amount)
	energy_changed.emit(energy)

func reset_for_run() -> void:
	health = max_health
	energy = max_energy
	fire_cooldown = 0.0
	boost_cooldown = 0.0
	boost_time = 0.0
	invulnerability = 0.0
	fire_input = false
	velocity = Vector3.ZERO
	health_changed.emit(health)
	energy_changed.emit(energy)

func _mat(color: Color, metallic: float, roughness: float, emission: Color, energy_value: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color.lerp(Color("#6b665d"), 0.50)
	material.metallic = min(metallic, 0.82)
	material.roughness = max(roughness, 0.44)
	material.emission_enabled = energy_value > 0.10
	material.emission = emission.lerp(Color("#9b7a50"), 0.52)
	material.emission_energy_multiplier = min(energy_value * 0.30, 0.52)
	return material
