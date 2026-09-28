extends CharacterBody3D

const BAKED_CHARACTER_SCRIPT = preload("res://baked_character.gd")

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
	var base_color := Color("#ffc1a8")
	var suit_color := Color("#5b2731")
	var glow_color := Color("#ff704d")
	if enemy_type == "striker":
		base_color = Color("#ffe0bb")
		suit_color = Color("#313f62")
		glow_color = Color("#70b8ff")
	elif enemy_type == "juggernaut":
		base_color = Color("#ffd0a5")
		suit_color = Color("#55321f")
		glow_color = Color("#ff9b58")

	var skin := _character_mat(base_color, glow_color)
	var suit := _character_mat(suit_color, glow_color)
	var dark := _character_mat(Color("#171217"), glow_color)
	var scale_value := 1.25 if enemy_type == "juggernaut" else 1.0

	var torso_mesh := CapsuleMesh.new()
	torso_mesh.radius = 0.34
	torso_mesh.height = 1.12
	_add_part("CharacterMesh", torso_mesh, Vector3(0.0, 1.05 * scale_value, 0.0), Vector3.ONE * scale_value, suit)

	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.27
	head_mesh.height = 0.54
	_add_part("Head", head_mesh, Vector3(0.0, 1.84 * scale_value, 0.0), Vector3.ONE * scale_value, skin)

	var visor_mesh := SphereMesh.new()
	visor_mesh.radius = 0.20
	visor_mesh.height = 0.28
	_add_part("Visor", visor_mesh, Vector3(0.0, 1.85 * scale_value, -0.18 * scale_value), Vector3(1.0, 0.55, 0.22) * scale_value, dark)

	var arm_mesh := CapsuleMesh.new()
	arm_mesh.radius = 0.11
	arm_mesh.height = 0.76
	_add_part("LeftArm", arm_mesh, Vector3(-0.43 * scale_value, 1.08 * scale_value, 0.0), Vector3.ONE * scale_value, skin)
	_add_part("RightArm", arm_mesh, Vector3(0.43 * scale_value, 1.08 * scale_value, 0.0), Vector3.ONE * scale_value, skin)

	var leg_mesh := CapsuleMesh.new()
	leg_mesh.radius = 0.13
	leg_mesh.height = 0.88
	_add_part("LeftLeg", leg_mesh, Vector3(-0.18 * scale_value, 0.46 * scale_value, 0.0), Vector3.ONE * scale_value, dark)
	_add_part("RightLeg", leg_mesh, Vector3(0.18 * scale_value, 0.46 * scale_value, 0.0), Vector3.ONE * scale_value, dark)

	var collider: CollisionShape3D = CollisionShape3D.new()
	var shape: CapsuleShape3D = CapsuleShape3D.new()
	shape.radius = 0.50 if enemy_type != "juggernaut" else 0.66
	shape.height = 1.80 if enemy_type != "juggernaut" else 2.30
	collider.shape = shape
	collider.position.y = 0.90 if enemy_type != "juggernaut" else 1.15
	add_child(collider)

func _add_part(part_name: String, mesh: Mesh, position_value: Vector3, scale_value: Vector3, material: StandardMaterial3D) -> void:
	var part := MeshInstance3D.new()
	part.name = part_name
	part.mesh = mesh
	part.position = position_value
	part.scale = scale_value
	part.material_override = material
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	visual_root.add_child(part)

func _character_mat(base_color: Color, glow_color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = base_color
	material.emission_enabled = true
	material.emission = glow_color
	material.emission_energy_multiplier = 0.28
	return material


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
	_hit_feedback()
	if health <= 0.0:
		defeated.emit(self, boss)
		queue_free()

func _hit_feedback() -> void:
	var mesh := visual_root.find_child("CharacterMesh", true, false) as MeshInstance3D if visual_root else null
	if mesh == null:
		return
	var base := mesh.material_override
	var flash := StandardMaterial3D.new()
	flash.albedo_color = Color("#f0deca")
	flash.emission_enabled = true
	flash.emission = Color("#c18b52")
	flash.emission_energy_multiplier = 1.35
	mesh.material_override = flash
	var tween := create_tween()
	tween.tween_interval(0.055)
	tween.tween_callback(func():
		if is_instance_valid(mesh):
			mesh.material_override = base
	)



func _mat(color: Color, metallic: float, roughness: float, emission: Color, energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color.lerp(Color("#6b665d"), 0.50)
	material.metallic = min(metallic, 0.82)
	material.roughness = max(roughness, 0.44)
	material.emission_enabled = energy > 0.10
	material.emission = emission.lerp(Color("#9b7a50"), 0.52)
	material.emission_energy_multiplier = min(energy * 0.30, 0.52)
	return material
