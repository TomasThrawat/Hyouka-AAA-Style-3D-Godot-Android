extends CharacterBody3D

signal defeated(drone: Node3D)

var target: Node3D
var speed := 2.8
var health := 40.0
var contact_cooldown := 0.0
var phase := 0.0
var visual: Node3D

func setup(target_node: Node3D, difficulty: float) -> void:
	target = target_node
	speed = 2.2 + difficulty * 0.65
	health = 28.0 + difficulty * 7.0
	scale = Vector3.ONE * (0.88 + difficulty * 0.025)
	_build_visual()

func _build_visual() -> void:
	var core := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.58
	mesh.height = 1.15
	mesh.material = _mat(Color("#ff3d74"), 0.15, 0.22, Color("#ff275f"), 2.2)
	core.mesh = mesh
	core.position.y = 0.7
	add_child(core)
	visual = core

	var ring := MeshInstance3D.new()
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.62
	ring_mesh.outer_radius = 0.7
	ring_mesh.material = _mat(Color("#ffb2c6"), 0.1, 0.18, Color("#ff3d74"), 2.4)
	ring.mesh = ring_mesh
	ring.rotation_degrees.x = 90
	ring.position.y = 0.7
	add_child(ring)

	var collider := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.78
	collider.shape = shape
	collider.position.y = 0.7
	add_child(collider)

func _physics_process(delta: float) -> void:
	if get_tree().paused or target == null:
		return
	phase += delta
	contact_cooldown -= delta
	var flat_target := target.global_position
	flat_target.y = global_position.y
	var distance := global_position.distance_to(flat_target)
	var direction := (flat_target - global_position).normalized()
	if distance > 2.1:
		velocity = direction * speed
		move_and_slide()
		rotation.y = lerp_angle(rotation.y, atan2(-direction.x, -direction.z), min(1.0, delta * 8.0))
	else:
		velocity = Vector3.ZERO
		if contact_cooldown <= 0.0 and target.has_method("take_damage"):
			target.take_damage(7.0)
			contact_cooldown = 1.2
	if visual:
		visual.position.y = 0.7 + sin(phase * 3.0) * 0.08
		visual.rotation.y += delta * 0.8

func take_damage(amount: float) -> void:
	health -= amount
	if health <= 0.0:
		defeated.emit(self)
		queue_free()

func _mat(color: Color, metallic: float, roughness: float, emission: Color, energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	material.emission_enabled = true
	material.emission = emission
	material.emission_energy_multiplier = energy
	return material
