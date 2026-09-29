extends CharacterBody3D
class_name AAAEnemy

const CHARACTER_SCENE = preload("res://assets/enemy_android.glb")

signal defeated(enemy: Node3D, boss: bool)
signal attack_requested(origin: Vector3, direction: Vector3, damage: float)
signal health_changed(current: float, maximum: float)

var target: Node3D
var enemy_type := "scout"
var speed := 3.2
var health := 60.0
var max_health := 60.0
var touch_damage := 8.0
var ranged_damage := 10.0
var attack_cooldown := 0.0
var decision_timer := 0.0
var phase := 0.0
var boss := false
var enraged := false
var visual_root: Node3D
var core_light: OmniLight3D

func setup(target_node: Node3D, difficulty: float, kind: String, is_boss: bool) -> void:
	target = target_node
	enemy_type = kind
	boss = is_boss
	phase = randf() * TAU
	match enemy_type:
		"striker":
			speed = 3.0 + difficulty * 0.36
			max_health = 88.0 + difficulty * 20.0
			touch_damage = 7.0
			ranged_damage = 13.0 + difficulty * 2.0
		"heavy":
			speed = 1.75 + difficulty * 0.18
			max_health = 170.0 + difficulty * 46.0
			touch_damage = 15.0
			ranged_damage = 11.0
		_:
			speed = 3.5 + difficulty * 0.50
			max_health = 54.0 + difficulty * 12.0
			touch_damage = 8.0 + difficulty
			ranged_damage = 9.0
	if boss:
		speed *= 0.82
		max_health *= 6.0
		touch_damage *= 1.6
		ranged_damage *= 1.4
		scale = Vector3.ONE * 1.55
	else:
		scale = Vector3.ONE * (0.88 + difficulty * 0.035)
	health = max_health
	collision_layer = 0
	collision_mask = 1
	_build_visual()
	health_changed.emit(health, max_health)

func _build_visual() -> void:
	visual_root = Node3D.new()
	visual_root.name = "EnemyVisual"
	add_child(visual_root)
	var model := CHARACTER_SCENE.instantiate()
	model.name = "Android"
	model.rotation.y = PI
	visual_root.add_child(model)
	for node in model.find_children("*", "MeshInstance3D", true, false):
		if node is MeshInstance3D:
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var animation_player := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if animation_player:
		var clips := animation_player.get_animation_list()
		if clips.size() > 0:
			animation_player.play(clips[0])
	var collider := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.54 if not boss else 0.78
	shape.height = 1.85 if not boss else 2.70
	collider.shape = shape
	collider.position.y = 0.92 if not boss else 1.35
	add_child(collider)
	core_light = OmniLight3D.new()
	core_light.light_color = Color("#ff6d68") if enemy_type != "heavy" else Color("#ffad65")
	core_light.light_energy = 1.8 if boss else 0.60
	core_light.omni_range = 4.5 if boss else 2.7
	core_light.position = Vector3(0, 1.15, 0)
	visual_root.add_child(core_light)
	if boss:
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.92
		torus.outer_radius = 1.05
		torus.material = _material(Color("#ef6862"), Color("#ff554e"), 2.8)
		ring.mesh = torus
		ring.position.y = 0.08
		visual_root.add_child(ring)

func _material(albedo: Color, emission: Color, energy: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = albedo
	mat.roughness = 0.30
	mat.metallic = 0.48
	mat.emission_enabled = true
	mat.emission = emission
	mat.emission_energy_multiplier = energy
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return mat

func _physics_process(delta: float) -> void:
	if get_tree().paused or target == null:
		return
	phase += delta
	attack_cooldown = max(0.0, attack_cooldown - delta)
	decision_timer -= delta
	if boss and not enraged and health <= max_health * 0.50:
		enraged = true
		speed *= 1.22
		ranged_damage *= 1.30
		core_light.light_energy = 2.8
	if decision_timer <= 0.0:
		decision_timer = 0.10
		var flat_target := target.global_position
		flat_target.y = global_position.y
		var to_target := flat_target - global_position
		var distance := to_target.length()
		var direction := to_target.normalized()
		if enemy_type == "striker":
			_striker_ai(direction, distance)
		elif enemy_type == "heavy" or boss:
			_heavy_ai(direction, distance)
		else:
			_scout_ai(direction, distance)
	move_and_slide()
	_update_visual(delta)

func _scout_ai(direction: Vector3, distance: float) -> void:
	if distance > 2.0:
		velocity = direction * speed
	elif attack_cooldown <= 0.0 and target.has_method("take_damage"):
		velocity = Vector3.ZERO
		target.take_damage(touch_damage)
		attack_cooldown = 0.95

func _striker_ai(direction: Vector3, distance: float) -> void:
	var orbit := direction.cross(Vector3.UP).normalized()
	var move_dir := orbit * sin(phase * 1.2)
	if distance > 13.0:
		move_dir += direction
	elif distance < 8.0:
		move_dir -= direction
	velocity = move_dir.normalized() * speed
	if attack_cooldown <= 0.0 and distance < 21.0:
		var attack_dir := (target.global_position + Vector3.UP * 0.8 - global_position).normalized()
		attack_requested.emit(global_position + Vector3.UP, attack_dir, ranged_damage)
		attack_cooldown = 1.35

func _heavy_ai(direction: Vector3, distance: float) -> void:
	if distance > 10.5:
		velocity = direction * speed
	elif distance < 6.0 and not boss:
		velocity = -direction * speed * 0.65
	else:
		velocity = direction.cross(Vector3.UP).normalized() * sin(phase * 0.6) * speed * 0.55
	if attack_cooldown <= 0.0 and distance < (24.0 if boss else 17.0):
		var attack_dir := (target.global_position + Vector3.UP * 0.8 - global_position).normalized()
		attack_requested.emit(global_position + Vector3.UP * 1.25, attack_dir, ranged_damage)
		attack_cooldown = 1.05 if boss else 1.7

func _update_visual(delta: float) -> void:
	if visual_root == null:
		return
	var movement := Vector2(velocity.x, velocity.z).length()
	var bob := sin(phase * (4.0 + movement * 0.5)) * 0.014
	visual_root.position.y = lerp(visual_root.position.y, bob, min(1.0, delta * 8.0))
	visual_root.rotation.y = sin(phase * 0.55) * 0.012

func take_damage(amount: float) -> void:
	if health <= 0.0:
		return
	var final_damage := amount
	if boss and health <= max_health * 0.25:
		final_damage *= 0.78
	health = max(0.0, health - final_damage)
	health_changed.emit(health, max_health)
	if health <= 0.0:
		defeated.emit(self, boss)
		queue_free()

func get_state() -> Dictionary:
	return {
		"type": enemy_type,
		"boss": boss,
		"health": health,
		"maxHealth": max_health,
		"position": global_position
	}
