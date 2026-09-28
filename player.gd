extends CharacterBody3D

const BAKED_CHARACTER_SCRIPT = preload("res://baked_character.gd")

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
var visual_root: Node3D

func _ready() -> void:
	collision_layer = 1
	collision_mask = 1
	_build_visual()

func _build_visual() -> void:
	visual_root = BAKED_CHARACTER_SCRIPT.create("res://assets/player_human.meshbin", Color("#aaa49a"), 1.04)
	visual_root.name = "CharacterModel"
	add_child(visual_root)
	var collider: CollisionShape3D = CollisionShape3D.new()
	var shape: CapsuleShape3D = CapsuleShape3D.new()
	shape.radius = 0.42
	shape.height = 1.78
	collider.shape = shape
	collider.position.y = 0.89
	add_child(collider)


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
	if visual_root == null:
		return
	var movement := Vector2(velocity.x, velocity.z).length()
	var run_phase := anim_time * (7.0 + movement * 0.8)
	var target_bob := 0.018 + sin(run_phase * 0.5) * (0.008 if movement < 0.2 else 0.022)
	visual_root.position.y = lerp(visual_root.position.y, target_bob, min(1.0, delta * 8.0))
	visual_root.rotation.y = lerp_angle(visual_root.rotation.y, rotation.y, min(1.0, delta * (9.0 if movement > 0.3 else 4.0)))


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
