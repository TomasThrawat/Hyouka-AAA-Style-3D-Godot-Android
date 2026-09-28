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

	var accent := Color("#a88452")
	if enemy_type == "striker":
		accent = Color("#8e806d")
	elif enemy_type == "juggernaut":
		accent = Color("#b08b57")

	var torso := MeshInstance3D.new()
	var torso_mesh := CapsuleMesh.new()
	torso_mesh.radius = 0.46 if enemy_type != "juggernaut" else 0.68
	torso_mesh.height = 1.25 if enemy_type != "juggernaut" else 1.65
	torso_mesh.material = _mat(Color("#302e2a"), 0.72, 0.36, accent, 0.16)
	torso.mesh = torso_mesh
	torso.scale = Vector3(1.0, 1.0, 0.74)
	torso.position.y = 1.05
	visual_root.add_child(torso)

	var chest_plate := MeshInstance3D.new()
	var chest_mesh := CapsuleMesh.new()
	chest_mesh.radius = 0.28 if not boss else 0.38
	chest_mesh.height = 0.74 if not boss else 0.95
	chest_mesh.material = _mat(Color("#1d1c1a"), 0.80, 0.28, accent, 0.24)
	chest_plate.mesh = chest_mesh
	chest_plate.scale = Vector3(1.0, 0.55, 0.70)
	chest_plate.position = Vector3(0, 1.22, -0.35)
	visual_root.add_child(chest_plate)

	var head := MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.36 if not boss else 0.48
	head_mesh.height = 0.68 if not boss else 0.88
	head_mesh.material = _mat(Color("#3a3833"), 0.66, 0.32, accent, 0.14)
	head.mesh = head_mesh
	head.position.y = 2.02 if not boss else 2.52
	visual_root.add_child(head)

	var visor := MeshInstance3D.new()
	var visor_mesh := CapsuleMesh.new()
	visor_mesh.radius = 0.13 if not boss else 0.17
	visor_mesh.height = 0.42 if not boss else 0.54
	visor_mesh.material = _mat(Color("#151514"), 0.82, 0.16, accent, 0.28)
	visor.mesh = visor_mesh
	visor.rotation_degrees.z = 90.0
	visor.scale = Vector3(1.0, 0.34, 0.42)
	visor.position = Vector3(0, head.position.y, -0.31)
	visual_root.add_child(visor)

	var limb_scale := 1.0 if not boss else 1.18
	for x in [-1.0, 1.0]:
		var shoulder := MeshInstance3D.new()
		var shoulder_mesh := SphereMesh.new()
		shoulder_mesh.radius = 0.22 * limb_scale
		shoulder_mesh.height = 0.42 * limb_scale
		shoulder_mesh.material = _mat(Color("#3a3731"), 0.70, 0.34, accent, 0.12)
		shoulder.mesh = shoulder_mesh
		shoulder.position = Vector3(x * 0.66 * limb_scale, 1.42 * limb_scale, 0)
		visual_root.add_child(shoulder)

		var arm := MeshInstance3D.new()
		var arm_mesh := CapsuleMesh.new()
		arm_mesh.radius = 0.15 * limb_scale
		arm_mesh.height = 0.88 * limb_scale
		arm_mesh.material = _mat(Color("#292724"), 0.62, 0.42, accent, 0.10)
		arm.mesh = arm_mesh
		arm.position = Vector3(x * 0.72 * limb_scale, 0.96 * limb_scale, 0)
		arm.rotation_degrees.z = x * -8.0
		visual_root.add_child(arm)

		var leg := MeshInstance3D.new()
		var leg_mesh := CapsuleMesh.new()
		leg_mesh.radius = 0.18 * limb_scale
		leg_mesh.height = 1.0 * limb_scale
		leg_mesh.material = _mat(Color("#252421"), 0.62, 0.44, accent, 0.08)
		leg.mesh = leg_mesh
		leg.position = Vector3(x * 0.28 * limb_scale, 0.44 * limb_scale, 0)
		visual_root.add_child(leg)

		var boot := MeshInstance3D.new()
		var boot_mesh := CapsuleMesh.new()
		boot_mesh.radius = 0.14 * limb_scale
		boot_mesh.height = 0.46 * limb_scale
		boot_mesh.material = _mat(Color("#171715"), 0.72, 0.38, accent, 0.10)
		boot.mesh = boot_mesh
		boot.scale = Vector3(1.12, 0.46, 1.55)
		boot.rotation_degrees.x = 90.0
		boot.position = Vector3(x * 0.28 * limb_scale, -0.03, -0.14)
		visual_root.add_child(boot)

	var weapon := MeshInstance3D.new()
	var weapon_mesh := CylinderMesh.new()
	weapon_mesh.top_radius = 0.07 * limb_scale
	weapon_mesh.bottom_radius = 0.11 * limb_scale
	weapon_mesh.height = 0.62 * limb_scale
	weapon_mesh.material = _mat(Color("#161614"), 0.80, 0.30, accent, 0.22)
	weapon.mesh = weapon_mesh
	weapon.rotation_degrees.x = 90.0
	weapon.position = Vector3(0, 1.02 * limb_scale, -0.58 * limb_scale)
	visual_root.add_child(weapon)

	var collider := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.80 if enemy_type != "juggernaut" else 1.15
	shape.height = 1.9 if enemy_type != "juggernaut" else 2.7
	collider.shape = shape
	collider.position.y = 0.95
	add_child(collider)

	if boss:
		var boss_ring := MeshInstance3D.new()
		var boss_ring_mesh := TorusMesh.new()
		boss_ring_mesh.inner_radius = 1.08
		boss_ring_mesh.outer_radius = 1.20
		boss_ring_mesh.material = _mat(Color("#7d684d"), 0.40, 0.28, accent, 0.50)
		boss_ring.mesh = boss_ring_mesh
		boss_ring.position.y = 2.35
		visual_root.add_child(boss_ring)


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
