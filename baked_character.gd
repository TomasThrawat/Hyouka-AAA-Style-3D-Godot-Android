extends Node
class_name BakedCharacter

static var mesh_cache: Dictionary = {}

static func create(path: String, tint: Color, scale_factor: float = 1.0) -> Node3D:
	var mesh: ArrayMesh = mesh_cache.get(path) as ArrayMesh
	if mesh == null:
		mesh = _load_mesh(path)
		mesh_cache[path] = mesh
	var root: Node3D = Node3D.new()
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.name = "CharacterMesh"
	instance.mesh = mesh
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = tint
	material.metallic = 0.12
	material.roughness = 0.60
	material.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.emission_enabled = true
	material.emission = tint
	material.emission_energy_multiplier = 0.12
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	root.add_child(instance)

	var ring := MeshInstance3D.new()
	ring.name = "CharacterMarker"
	var torus := TorusMesh.new()
	torus.inner_radius = 0.30
	torus.outer_radius = 0.38
	var ring_material := StandardMaterial3D.new()
	ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	ring_material.albedo_color = tint
	ring_material.emission_enabled = true
	ring_material.emission = tint
	ring_material.emission_energy_multiplier = 1.8
	torus.material = ring_material
	ring.mesh = torus
	ring.position.y = 0.02
	root.add_child(ring)

	root.scale = Vector3(scale_factor * 1.14, scale_factor, scale_factor * 1.14)
	return root

static func _load_mesh(path: String) -> ArrayMesh:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Missing baked character mesh: " + path)
		return ArrayMesh.new()
	var magic: PackedByteArray = file.get_buffer(4)
	var vertex_count: int = file.get_32()
	if magic.get_string_from_ascii() != "HCM1" or vertex_count <= 0:
		push_error("Invalid baked character mesh: " + path)
		return ArrayMesh.new()
	var payload_size: int = file.get_length() - file.get_position()
	var bytes: PackedByteArray = file.get_buffer(payload_size)
	var floats: PackedFloat32Array = bytes.to_float32_array()
	if floats.size() != vertex_count * 6:
		push_error("Baked character mesh size mismatch: " + path)
		return ArrayMesh.new()
	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	for i in range(vertex_count):
		var base: int = i * 6
		vertices.append(Vector3(floats[base], floats[base + 1], floats[base + 2]))
		normals.append(Vector3(floats[base + 3], floats[base + 4], floats[base + 5]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
