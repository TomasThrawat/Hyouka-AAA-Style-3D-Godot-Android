extends CharacterBody3D

signal defeated(enemy: Node3D, boss: bool)
signal attack_requested(origin: Vector3, direction: Vector3, damage: float)

var target: Node3D
var enemy_type := "drone"
var speed := 3.2
var health := 50.0
var max_health := 50.0
var touch_damage := 8.0
var ranged_damage := 9.0
var attack_cooldown := 0.0
var phase := 0.0
var ai_timer := 0.0
var cached_direction := Vector3.FORWARD
var cached_distance := 999.0
var boss := false
var visual_root: Node3D

func setup(target_node: Node3D, difficulty: float, kind: String, is_boss: bool) -> void:
	target = target_node
	enemy_type = kind
	boss = is_boss
	phase = randf() * TAU
	match enemy_type:
		"striker":
			speed = 2.65 + difficulty * 0.42
			max_health = 72.0 + difficulty * 18.0
			touch_damage = 6.0
			ranged_damage = 13.0 + difficulty * 2.0
		"juggernaut":
			speed = 1.65 + difficulty * 0.2
			max_health = 190.0 + difficulty * 50.0
			touch_damage = 15.0
			ranged_damage = 10.0
		_:
			speed = 3.1 + difficulty * 0.62
			max_health = 44.0 + difficulty * 11.0
			touch_damage = 8.0 + difficulty
			ranged_damage = 8.0
	if boss:
		speed *= 0.9
		max_health *= 5.5
		touch_damage *= 1.5
		scale = Vector3.ONE * 1.6
	else:
		scale = Vector3.ONE * (0.9 + difficulty * 0.035)
	health = max_health
	collision_layer = 0
	collision_mask = 0
	_build_visual()

func _build_visual() -> void:
	visual_root = Node3D.new()
	visual_root.name = "Visual"
	add_child(visual_root)
	var tint := Color("#ff4d83")
	if enemy_type == "striker":
		tint = Color("#b06aff")
	elif enemy_type == "juggernaut":
		tint = Color("#ffb84a")

	var core := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.6 if enemy_type != "juggernaut" else 0.85
	mesh.height = 1.2 if enemy_type != "juggernaut" else 1.7
	mesh.material = _mat(Color("#2b1727") if enemy_type != "juggernaut" else Color("#33220f"), 0.45, 0.18, tint, 2.5)
	core.mesh = mesh
	core.position.y = 0.85
	visual_root.add_child(core)

	var ring := MeshInstance3D.new()
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.67 if enemy_type != "juggernaut" else 0.9
	ring_mesh.outer_radius = 0.76 if enemy_type != "juggernaut" else 1.02
	ring_mesh.material = _mat(Color("#ffe1ea"), 0.12, 0.12, tint, 2.8)
	ring.mesh = ring_mesh
	ring.rotation_degrees.x = 90
	ring.position.y = 0.85
	visual_root.add_child(ring)

	for x in [-1.0, 1.0]:
		var fin := MeshInstance3D.new()
		var fin_mesh := BoxMesh.new()
		fin_mesh.size = Vector3(0.18, 0.72, 0.62)
		fin_mesh.material = _mat(Color("#34182a"), 0.36, 0.22, tint, 1.4)
		fin.mesh = fin_mesh
		fin.position = Vector3(x * (0.68 if enemy_type != "juggernaut" else 0.94), 0.72, 0)
		fin.rotation_degrees.z = x * 18.0
		visual_root.add_child(fin)

	var collider := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.8 if enemy_type != "juggernaut" else 1.15
	collider.shape = shape
	collider.position.y = 0.8
	add_child(collider)

	if boss:
		var core_ring := MeshInstance3D.new()
		var core_mesh := TorusMesh.new()
		core_mesh.inner_radius = 1.2
		core_mesh.outer_radius = 1.34
		core_mesh.material = _mat(Color("#fff0c7"), 0.2, 0.14, Color("#ffd363"), 4.0)
		core_ring.mesh = core_mesh
		core_ring.position.y = 1.0
		core_ring.rotation_degrees.x = 90
		add_child(core_ring)

func _physics_process(delta: float) -> void:
	if get_tree().paused or target == null:
		return
	phase += delta
	attack_cooldown = max(0.0, attack_cooldown - delta)
	ai_timer -= delta
	if ai_timer <= 0.0:
		ai_timer = 0.10
		cached_distance = global_position.distance_to(target.global_position)
		if cached_distance > 62.0:
			velocity = Vector3.ZERO
			return
		var flat_target := target.global_position
		flat_target.y = global_position.y
		cached_direction = (flat_target - global_position).normalized()
		if enemy_type == "striker":
			_striker_ai(cached_direction, cached_distance)
		elif enemy_type == "juggernaut":
			_juggernaut_ai(cached_direction, cached_distance)
		else:
			_drone_ai(cached_direction, cached_distance)
	move_and_slide()
	_update_animation(delta, cached_direction)

func _drone_ai(direction: Vector3, distance: float) -> void:
	if distance > 2.2:
		velocity = direction * speed
	else:
		velocity = Vector3.ZERO
		if attack_cooldown <= 0.0 and target.has_method("take_damage"):
			target.take_damage(touch_damage)
			attack_cooldown = 1.05

func _striker_ai(direction: Vector3, distance: float) -> void:
	var desired_distance := 10.5
	var orbit := direction.cross(Vector3.UP).normalized()
	var move_dir := orbit * sin(phase * 0.9) * 0.7
	if distance > desired_distance + 2.0:
		move_dir += direction
	elif distance < desired_distance - 2.0:
		move_dir -= direction
	velocity = move_dir.normalized() * speed
	if attack_cooldown <= 0.0 and distance < 18.0:
		var attack_dir := (target.global_position + Vector3.UP * 0.8 - (global_position + Vector3.UP)).normalized()
		attack_requested.emit(global_position + Vector3.UP * 0.9, attack_dir, ranged_damage)
		attack_cooldown = 1.7

func _juggernaut_ai(direction: Vector3, distance: float) -> void:
	if distance > 2.8:
		velocity = direction * speed
	else:
		velocity = Vector3.ZERO
		if attack_cooldown <= 0.0 and target.has_method("take_damage"):
			target.take_damage(touch_damage)
			attack_cooldown = 1.15
	if attack_cooldown <= 0.0 and distance < 13.0 and boss:
		var attack_dir := (target.global_position + Vector3.UP * 0.7 - (global_position + Vector3.UP * 0.6)).normalized()
		attack_requested.emit(global_position + Vector3.UP * 1.2, attack_dir, ranged_damage + 5.0)
		attack_cooldown = 2.6

func _update_animation(delta: float, direction: Vector3) -> void:
	if visual_root == null:
		return
	var moving := velocity.length() > 0.3
	visual_root.position.y = 0.08 + sin(phase * 4.0) * (0.1 if moving else 0.045)
	visual_root.rotation.y += delta * (1.2 if enemy_type != "juggernaut" else 0.55)
	rotation.y = lerp_angle(rotation.y, atan2(-direction.x, -direction.z), min(1.0, delta * 6.0))

func take_damage(amount: float) -> void:
	health -= amount
	if health <= 0.0:
		defeated.emit(self, boss)
		queue_free()

func _mat(color: Color, metallic: float, roughness: float, emission: Color, energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color.lerp(Color("#6b665d"), 0.50)
	material.metallic = min(metallic, 0.82)
	material.roughness = max(roughness, 0.44)
	material.emission_enabled = energy > 0.10
	material.emission = emission.lerp(Color("#9b7a50"), 0.52)
	material.emission_energy_multiplier = min(energy * 0.30, 0.52)
	return material
