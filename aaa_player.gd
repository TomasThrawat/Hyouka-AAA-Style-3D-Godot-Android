extends CharacterBody3D
class_name AAAPlayer

const CHARACTER_SCENE = preload("res://assets/player_astronaut.glb")

signal boost_requested
signal fire_requested(origin: Vector3, direction: Vector3, damage: float)
signal tactical_requested(origin: Vector3, direction: Vector3)
signal shield_requested
signal health_changed(value: float)
signal energy_changed(value: float)
signal ammo_changed(current: int, capacity: int)
signal state_changed
signal died

@export var move_speed := 8.4
@export var acceleration := 27.0
@export var friction := 31.0
@export var max_health := 100.0
@export var max_energy := 100.0
@export var fire_rate := 0.12
@export var shot_damage := 28.0
@export var magazine_size := 30

var health := 100.0
var energy := 100.0
var ammo := 30
var move_stick := Vector2.ZERO
var fire_input := false
var boost_time := 0.0
var boost_cooldown := 0.0
var tactical_cooldown := 0.0
var shield_cooldown := 0.0
var shield_time := 0.0
var fire_cooldown := 0.0
var reload_timer := 0.0
var invulnerability := 0.0
var anim_time := 0.0
var visual_root: Node3D
var weapon_flash: OmniLight3D
var weapon_glow: MeshInstance3D
var aim_direction := Vector3.FORWARD

func _ready() -> void:
	collision_layer = 1
	collision_mask = 1
	_build_visual()
	reset_for_run()

func _build_visual() -> void:
	visual_root = Node3D.new()
	visual_root.name = "PlayerVisual"
	add_child(visual_root)
	var model := CHARACTER_SCENE.instantiate()
	model.name = "Astronaut"
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
	shape.radius = 0.46
	shape.height = 1.95
	collider.shape = shape
	collider.position.y = 0.98
	add_child(collider)
	var visor := OmniLight3D.new()
	visor.name = "SuitLight"
	visor.light_color = Color("#78d9ff")
	visor.light_energy = 0.42
	visor.omni_range = 2.8
	visor.position = Vector3(0, 1.55, -0.35)
	visual_root.add_child(visor)
	weapon_glow = MeshInstance3D.new()
	var glow_mesh := SphereMesh.new()
	glow_mesh.radius = 0.08
	glow_mesh.height = 0.16
	var glow_mat := StandardMaterial3D.new()
	glow_mat.albedo_color = Color("#c8f5ff")
	glow_mat.emission_enabled = true
	glow_mat.emission = Color("#55d8ff")
	glow_mat.emission_energy_multiplier = 3.5
	glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow_mesh.material = glow_mat
	weapon_glow.mesh = glow_mesh
	weapon_glow.position = Vector3(0.38, 1.14, -0.92)
	visual_root.add_child(weapon_glow)
	weapon_flash = OmniLight3D.new()
	weapon_flash.light_color = Color("#79e6ff")
	weapon_flash.light_energy = 0.0
	weapon_flash.omni_range = 3.0
	weapon_flash.position = weapon_glow.position
	visual_root.add_child(weapon_flash)

func _physics_process(delta: float) -> void:
	if get_tree().paused:
		return
	anim_time += delta
	boost_cooldown = max(0.0, boost_cooldown - delta)
	boost_time = max(0.0, boost_time - delta)
	tactical_cooldown = max(0.0, tactical_cooldown - delta)
	shield_cooldown = max(0.0, shield_cooldown - delta)
	shield_time = max(0.0, shield_time - delta)
	fire_cooldown = max(0.0, fire_cooldown - delta)
	invulnerability = max(0.0, invulnerability - delta)
	if reload_timer > 0.0:
		reload_timer = max(0.0, reload_timer - delta)
		if reload_timer == 0.0:
			ammo = magazine_size
			ammo_changed.emit(ammo, magazine_size)
			state_changed.emit()
	energy = min(max_energy, energy + delta * 12.0)
	energy_changed.emit(energy)
	var keyboard := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var input_vector := move_stick if move_stick.length() > 0.05 else keyboard
	var current_speed := move_speed * (1.9 if boost_time > 0.0 else 1.0)
	var desired := Vector3(input_vector.x, 0.0, input_vector.y) * current_speed
	velocity.x = move_toward(velocity.x, desired.x, acceleration * delta)
	velocity.z = move_toward(velocity.z, desired.z, acceleration * delta)
	if input_vector.length() < 0.05:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)
		velocity.z = move_toward(velocity.z, 0.0, friction * delta)
	if desired.length() > 0.2:
		var target_yaw := atan2(-desired.x, -desired.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, min(1.0, 14.0 * delta))
		aim_direction = -global_transform.basis.z
	move_and_slide()
	if fire_input or Input.is_action_pressed("ui_accept"):
		shoot()
	_update_animation(delta)

func _update_animation(delta: float) -> void:
	if visual_root == null:
		return
	var movement := Vector2(velocity.x, velocity.z).length()
	var phase := anim_time * (7.0 + movement)
	var bob := 0.02 + sin(phase) * (0.012 if movement < 0.2 else 0.028)
	visual_root.position.y = lerp(visual_root.position.y, bob, min(1.0, delta * 10.0))
	weapon_flash.light_energy = max(0.0, weapon_flash.light_energy - delta * 14.0)

func shoot() -> void:
	if reload_timer > 0.0 or fire_cooldown > 0.0 or health <= 0.0:
		return
	if ammo <= 0:
		reload()
		return
	ammo -= 1
	ammo_changed.emit(ammo, magazine_size)
	fire_cooldown = fire_rate
	var direction := aim_direction.normalized()
	if direction.length() < 0.2:
		direction = -global_transform.basis.z
	var origin := global_position + Vector3.UP * 1.3 + direction * 0.95
	fire_requested.emit(origin, direction, shot_damage)
	weapon_flash.light_energy = 2.6

func reload() -> void:
	if reload_timer > 0.0 or ammo >= magazine_size:
		return
	reload_timer = 1.0
	fire_input = false
	state_changed.emit()

func boost() -> void:
	if boost_cooldown > 0.0 or energy < 24.0 or get_tree().paused:
		return
	boost_time = 0.58
	boost_cooldown = 1.65
	energy -= 24.0
	energy_changed.emit(energy)
	boost_requested.emit()

func tactical() -> void:
	if tactical_cooldown > 0.0 or energy < 42.0 or get_tree().paused:
		return
	tactical_cooldown = 5.5
	energy -= 42.0
	energy_changed.emit(energy)
	tactical_requested.emit(global_position + Vector3.UP * 0.75, -global_transform.basis.z)

func shield() -> void:
	if shield_cooldown > 0.0 or energy < 32.0 or get_tree().paused:
		return
	shield_cooldown = 8.0
	shield_time = 3.0
	energy -= 32.0
	energy_changed.emit(energy)
	shield_requested.emit()

func set_move_input(value: Vector2) -> void:
	move_stick = value.limit_length(1.0)

func clear_move_input() -> void:
	move_stick = Vector2.ZERO

func set_fire_input(value: bool) -> void:
	fire_input = value

func set_aim_direction(value: Vector3) -> void:
	if value.length() > 0.15:
		aim_direction = value.normalized()

func take_damage(amount: float) -> void:
	if health <= 0.0 or invulnerability > 0.0:
		return
	var final_damage := amount
	if shield_time > 0.0:
		final_damage *= 0.22
		invulnerability = 0.15
	else:
		invulnerability = 0.24
	health = max(0.0, health - final_damage)
	health_changed.emit(health)
	state_changed.emit()
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
	ammo = magazine_size
	move_stick = Vector2.ZERO
	fire_input = false
	reload_timer = 0.0
	fire_cooldown = 0.0
	boost_cooldown = 0.0
	boost_time = 0.0
	tactical_cooldown = 0.0
	shield_cooldown = 0.0
	shield_time = 0.0
	invulnerability = 0.0
	aim_direction = -global_transform.basis.z if is_inside_tree() else Vector3.FORWARD
	health_changed.emit(health)
	energy_changed.emit(energy)
	ammo_changed.emit(ammo, magazine_size)
	state_changed.emit()

func get_state() -> Dictionary:
	return {
		"health": health,
		"energy": energy,
		"ammo": ammo,
		"magazineSize": magazine_size,
		"reloadTimer": reload_timer,
		"boostCooldown": boost_cooldown,
		"pulseCooldown": tactical_cooldown,
		"shieldCooldown": shield_cooldown,
		"shieldActive": shield_time > 0.0,
		"position": global_position
	}
