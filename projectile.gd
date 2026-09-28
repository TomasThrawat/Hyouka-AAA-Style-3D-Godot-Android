extends Node3D

var direction := Vector3.FORWARD
var friendly := true
var damage := 10.0
var speed := 20.0
var remaining_life := 4.0
var expired := false
var hit_radius := 0.72

func setup(direction_value: Vector3, friendly_value: bool, damage_value: float, speed_value: float, lifetime: float, color: Color) -> void:
	direction = direction_value.normalized()
	friendly = friendly_value
	damage = damage_value
	speed = speed_value
	remaining_life = lifetime
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.11, 0.11, 0.48 if friendly else 0.56)
	box.material = _mat(color, 0.05, 0.16, color, 2.8)
	mesh.mesh = box
	mesh.position = direction * 0.24
	add_child(mesh)
	look_at(global_position + direction, Vector3.UP)

func advance(delta: float) -> void:
	if expired:
		return
	remaining_life -= delta
	if remaining_life <= 0.0:
		expired = true
		return
	position += direction * speed * delta

func _mat(color: Color, metallic: float, roughness: float, emission: Color, energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	material.emission_enabled = true
	material.emission = emission
	material.emission_energy_multiplier = energy
	return material
