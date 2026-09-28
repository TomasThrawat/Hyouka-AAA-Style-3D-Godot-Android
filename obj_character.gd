extends Node
class_name ObjCharacter

static var mesh_cache: Dictionary = {}

static func build(path: String, tint: Color, target_height: float = 1.8, scale_factor: float = 1.0) -> Node3D:
	var mesh := mesh_cache.get(path) as ArrayMesh
	if mesh == null:
		mesh = _load_meshbin(path)
		mesh_cache[path] = mesh
	var root := Node3D.new()
	var instance := MeshInstance3D.new()
	instance.name = "CharacterMesh"
	instance.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.metallic = 0.24
	material.roughness = 0.66
	material.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	instance.material_override = material
	root.add_child(instance)
	root.scale = Vector3.ONE * scale_factor
	return root

static func _load_meshbin(path: String) -> ArrayMesh:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Missing baked character mesh: " + path)
		return ArrayMesh.new()
	var magic := file.get_buffer(4)
	var vertex_count: int = file.get_32()
	if magic.get_string_from_ascii() != "HCM1" or vertex_count <= 0:
		push_error("Invalid baked character mesh: " + path)
		return ArrayMesh.new()
	var byte_data := file.get_buffer(file.get_length() - file.get_position())
	var floats := byte_data.to_float32_array()
	if floats.size() != vertex_count * 6:
		push_error("Baked mesh payload size mismatch: " + path)
		return ArrayMesh.new()

	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
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
