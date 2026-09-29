extends Node3D
class_name AAAProjectile

var direction := Vector3.FORWARD
var speed := 24.0
var damage := 10.0
var lifetime := 3.0
var friendly := true
var hit_radius := 0.42
var active := true
var color := Color.WHITE

func setup(origin: Vector3, dir: Vector3, is_friendly: bool, amount: float, projectile_speed: float, life: float, tint: Color) -> void:
	global_position = origin
	direction = dir.normalized()
	friendly = is_friendly
	damage = amount
	speed = projectile_speed
	lifetime = life
	color = tint
	_build_visual()

func _build_visual() -> void:
	var mesh_instance := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.075 if friendly else 0.11
	mesh.height = mesh.radius * 2.0
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 4.0 if friendly else 2.6
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = material
	mesh_instance.mesh = mesh
	add_child(mesh_instance)

	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 0.7 if friendly else 0.35
	light.omni_range = 2.4 if friendly else 1.8
	add_child(light)

	var trail := MeshInstance3D.new()
	var trail_mesh := BoxMesh.new()
	trail_mesh.size = Vector3(0.035 if friendly else 0.055, 0.035 if friendly else 0.055, 0.8 if friendly else 0.58)
	var trail_material := StandardMaterial3D.new()
	trail_material.albedo_color = color
	trail_material.emission_enabled = true
	trail_material.emission = color
	trail_material.emission_energy_multiplier = 1.8
	trail_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	trail_mesh.material = trail_material
	trail.mesh = trail_mesh
	trail.position.z = 0.4 if friendly else 0.29
	add_child(trail)
	look_at(global_position + direction, Vector3.UP)

func advance(delta: float) -> void:
	if not active:
		return
	global_position += direction * speed * delta
	lifetime -= delta
	if lifetime <= 0.0:
		active = false
