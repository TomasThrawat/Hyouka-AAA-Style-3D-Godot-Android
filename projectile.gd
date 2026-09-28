extends Node3D

var direction := Vector3.FORWARD
var friendly := true
var damage := 10.0
var speed := 20.0
var remaining_life := 4.0
var expired := false
var hit_radius := 0.85
var spin := 0.0

func setup(direction_value: Vector3, friendly_value: bool, damage_value: float, speed_value: float, lifetime: float, color: Color) -> void:
	direction = direction_value.normalized()
	friendly = friendly_value
	damage = damage_value
	speed = speed_value
	remaining_life = lifetime
	var mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.12 if friendly else 0.15
	sphere.height = 0.24 if friendly else 0.3
	sphere.material = _mat(color, 0.15, 0.08, color, 4.5)
	mesh.mesh = sphere
	add_child(mesh)
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 3.8
	light.omni_range = 2.6
	add_child(light)
	var trail := GPUParticles3D.new()
	trail.amount = 18
	trail.lifetime = 0.24
	trail.position = -direction * 0.25
	var pm := ParticleProcessMaterial.new()
	pm.direction = -direction
	pm.spread = 8.0
	pm.initial_velocity_min = 1.0
	pm.initial_velocity_max = 2.3
	pm.scale_min = 0.02
	pm.scale_max = 0.045
	pm.color = color
	trail.process_material = pm
	var pmesh := SphereMesh.new()
	pmesh.radius = 0.035
	pmesh.height = 0.07
	pmesh.material = _mat(color, 0.0, 0.1, color, 3.0)
	trail.draw_pass_1 = pmesh
	trail.emitting = true
	add_child(trail)

func advance(delta: float) -> void:
	if expired:
		return
	remaining_life -= delta
	if remaining_life <= 0.0:
		expired = true
		return
	position += direction * speed * delta
	spin += delta * 12.0
	rotation.z = spin

func _mat(color: Color, metallic: float, roughness: float, emission: Color, energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	material.emission_enabled = true
	material.emission = emission
	material.emission_energy_multiplier = energy
	return material
