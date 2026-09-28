extends Node
class_name ObjCharacter

static var mesh_cache: Dictionary = {}

static func build(path: String, tint: Color, target_height: float = 1.8, scale_factor: float = 1.0) -> Node3D:
	var mesh := mesh_cache.get(path) as ArrayMesh
	if mesh == null:
		mesh = _load_obj(path, target_height)
		mesh_cache[path] = mesh

	var root := Node3D.new()
	var instance := MeshInstance3D.new()
	instance.name = "CharacterMesh"
	instance.mesh = mesh

	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.metallic = 0.26
	material.roughness = 0.68
	material.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	instance.material_override = material
	root.add_child(instance)
	root.scale = Vector3.ONE * scale_factor
	return root

static func _load_obj(path: String, target_height: float) -> ArrayMesh:
	var source := FileAccess.get_file_as_string(path)
	var raw_vertices := PackedVector3Array()
	var triangles := PackedInt32Array()
	var min_v := Vector3(INF, INF, INF)
	var max_v := Vector3(-INF, -INF, -INF)

	for line in source.split("
"):
		var parts := line.strip_edges().split(" ", false)
		if parts.is_empty():
			continue
		if parts[0] == "v" and parts.size() >= 4:
			var p := Vector3(float(parts[1]), float(parts[2]), float(parts[3]))
			raw_vertices.append(p)
			min_v = min_v.min(p)
			max_v = max_v.max(p)
		elif parts[0] == "f" and parts.size() >= 4:
			var face := PackedInt32Array()
			for k in range(1, parts.size()):
				var token: String = parts[k]
				var slash := token.find("/")
				var index: int = int(token.substr(0, slash) if slash >= 0 else token)
				if index < 0:
					index = raw_vertices.size() + index
				else:
					index -= 1
				if index >= 0 and index < raw_vertices.size():
					face.append(index)
			if face.size() >= 3:
				for k in range(1, face.size() - 1):
					triangles.append(face[0])
					triangles.append(face[k])
					triangles.append(face[k + 1])

	var origin := Vector3((min_v.x + max_v.x) * 0.5, min_v.y, (min_v.z + max_v.z) * 0.5)
	var height := max(0.001, max_v.y - min_v.y)
	var unit_scale := target_height / height
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()

	for i in range(0, triangles.size(), 3):
		var a := (raw_vertices[triangles[i]] - origin) * unit_scale
		var b := (raw_vertices[triangles[i + 1]] - origin) * unit_scale
		var c := (raw_vertices[triangles[i + 2]] - origin) * unit_scale
		var n := (b - a).cross(c - a)
		if n.length_squared() < 0.000001:
			n = Vector3.UP
		else:
			n = n.normalized()
		vertices.append(a)
		vertices.append(b)
		vertices.append(c)
		normals.append(n)
		normals.append(n)
		normals.append(n)

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
