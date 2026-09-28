extends Node3D

var direction := Vector3.FORWARD
var friendly := true
var damage := 10.0
var speed := 20.0
var remaining_life := 4.0
var expired := false
var hit_radius := 0.72

func setup(direction_value: Vector3, friendly_value: bool, damage_value: float, speed_value: float, lifetime: float, color: Color) -> void:
\tdirection = direction_value.normalized()
\tfriendly = friendly_value
\tdamage = damage_value
\tspeed = speed_value
\tremaining_life = lifetime
\tvar mesh := MeshInstance3D.new()
\tvar box := BoxMesh.new()
\tbox.size = Vector3(0.11, 0.11, 0.48 if friendly else 0.56)
\tbox.material = _mat(color, 0.05, 0.16, color, 2.8)
\tmesh.mesh = box
\tmesh.position = direction * 0.24
\tadd_child(mesh)
\tlook_at(global_position + direction, Vector3.UP)

func advance(delta: float) -> void:
\tif expired:
\t\treturn
\tremaining_life -= delta
\tif remaining_life <= 0.0:
\t\texpired = true
\t\treturn
\tposition += direction * speed * delta

func _mat(color: Color, metallic: float, roughness: float, emission: Color, energy: float) -> StandardMaterial3D:
\tvar material := StandardMaterial3D.new()
\tmaterial.albedo_color = color
\tmaterial.metallic = metallic
\tmaterial.roughness = roughness
\tmaterial.emission_enabled = true
\tmaterial.emission = emission
\tmaterial.emission_energy_multiplier = energy
\treturn material
