class_name RockMeshBuilder
extends RefCounted

## Builds faceted low-poly rocks and ice shards from a subdivided icosahedron.
## Everything is generated once at runtime, so there are no binary mesh assets.

static var _icosphere_cache: Dictionary[int, Dictionary] = {}


static func create_rock(
	seed_value: int, subdivisions: int = 1, roughness: float = 0.32, stretch: Vector3 = Vector3.ONE
) -> ArrayMesh:
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 1.0
	noise.fractal_octaves = 3

	var detail := FastNoiseLite.new()
	detail.seed = seed_value + 91
	detail.noise_type = FastNoiseLite.TYPE_SIMPLEX
	detail.frequency = 1.0
	detail.fractal_octaves = 2

	var sphere: Dictionary = _get_icosphere(subdivisions)
	var source: PackedVector3Array = sphere["vertices"]
	var faces: Array[Vector3i] = sphere["faces"]

	var displaced := PackedVector3Array()
	displaced.resize(source.size())
	for i: int in source.size():
		var v: Vector3 = source[i]
		var n: float = noise.get_noise_3dv(v * 1.45)
		var d: float = detail.get_noise_3dv(v * 4.1)
		var amount: float = 1.0 + n * roughness + d * roughness * 0.28
		displaced[i] = v * amount * stretch

	# Normalise so the largest axis is about one unit.
	var longest: float = 0.001
	for v: Vector3 in displaced:
		longest = maxf(longest, maxf(absf(v.x), maxf(absf(v.y), absf(v.z))))
	for i: int in displaced.size():
		displaced[i] = displaced[i] / longest

	return _faces_to_mesh(displaced, faces, seed_value)


static func create_crystal(seed_value: int) -> ArrayMesh:
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 1.0
	noise.fractal_octaves = 2

	var sphere: Dictionary = _get_icosphere(1)
	var source: PackedVector3Array = sphere["vertices"]
	var faces: Array[Vector3i] = sphere["faces"]
	var displaced := PackedVector3Array()
	displaced.resize(source.size())
	for i: int in source.size():
		var v: Vector3 = source[i]
		var n: float = noise.get_noise_3dv(v * 2.1)
		var amount: float = 1.0 + n * 0.22
		var stretched := Vector3(v.x * amount, v.y * amount * 1.65, v.z * amount * 0.82)
		displaced[i] = stretched
	var longest: float = 0.001
	for v: Vector3 in displaced:
		longest = maxf(longest, absf(v.y))
	for i: int in displaced.size():
		displaced[i] = displaced[i] / longest
	return _faces_to_mesh(displaced, faces, seed_value + 7, true)


static func _faces_to_mesh(
	vertices: PackedVector3Array, faces: Array[Vector3i], seed_value: int, crystal: bool = false
) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 7919 + 13

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for face: Vector3i in faces:
		var a: Vector3 = vertices[face.x]
		var b: Vector3 = vertices[face.y]
		var c: Vector3 = vertices[face.z]
		var normal: Vector3 = (b - a).cross(c - a).normalized()
		if normal.dot(a + b + c) < 0.0:
			normal = -normal
		var shade: float = rng.randf_range(0.82, 1.05)
		if crystal:
			shade = rng.randf_range(0.9, 1.16)
		var color := Vector3(shade, shade, shade)
		for point: Vector3 in [a, b, c]:
			st.set_color(Color(color.x, color.y, color.z))
			st.set_normal(normal)
			st.add_vertex(point)
	return st.commit()


static func _get_icosphere(subdivisions: int) -> Dictionary:
	var level: int = clampi(subdivisions, 0, 3)
	if _icosphere_cache.has(level):
		return _icosphere_cache[level]

	var t: float = (1.0 + sqrt(5.0)) * 0.5
	var vertices := PackedVector3Array(
		[
			Vector3(-1, t, 0),
			Vector3(1, t, 0),
			Vector3(-1, -t, 0),
			Vector3(1, -t, 0),
			Vector3(0, -1, t),
			Vector3(0, 1, t),
			Vector3(0, -1, -t),
			Vector3(0, 1, -t),
			Vector3(t, 0, -1),
			Vector3(t, 0, 1),
			Vector3(-t, 0, -1),
			Vector3(-t, 0, 1),
		]
	)
	for i: int in vertices.size():
		vertices[i] = vertices[i].normalized()

	var faces: Array[Vector3i] = [
		Vector3i(0, 11, 5),
		Vector3i(0, 5, 1),
		Vector3i(0, 1, 7),
		Vector3i(0, 7, 10),
		Vector3i(0, 10, 11),
		Vector3i(1, 5, 9),
		Vector3i(5, 11, 4),
		Vector3i(11, 10, 2),
		Vector3i(10, 7, 6),
		Vector3i(7, 1, 8),
		Vector3i(3, 9, 4),
		Vector3i(3, 4, 2),
		Vector3i(3, 2, 6),
		Vector3i(3, 6, 8),
		Vector3i(3, 8, 9),
		Vector3i(4, 9, 5),
		Vector3i(2, 4, 11),
		Vector3i(6, 2, 10),
		Vector3i(8, 6, 7),
		Vector3i(9, 8, 1),
	]

	for _level: int in level:
		var midpoints: Dictionary[Vector2i, int] = {}
		var new_faces: Array[Vector3i] = []
		for face: Vector3i in faces:
			var a: int = face.x
			var b: int = face.y
			var c: int = face.z
			var ab: int = _midpoint(a, b, vertices, midpoints)
			var bc: int = _midpoint(b, c, vertices, midpoints)
			var ca: int = _midpoint(c, a, vertices, midpoints)
			new_faces.append(Vector3i(a, ab, ca))
			new_faces.append(Vector3i(b, bc, ab))
			new_faces.append(Vector3i(c, ca, bc))
			new_faces.append(Vector3i(ab, bc, ca))
		faces = new_faces

	var result: Dictionary = {"vertices": vertices, "faces": faces}
	_icosphere_cache[level] = result
	return result


static func _midpoint(
	a: int, b: int, vertices: PackedVector3Array, cache: Dictionary[Vector2i, int]
) -> int:
	var key := Vector2i(mini(a, b), maxi(a, b))
	if cache.has(key):
		return cache[key]
	var point: Vector3 = ((vertices[a] + vertices[b]) * 0.5).normalized()
	vertices.append(point)
	var index: int = vertices.size() - 1
	cache[key] = index
	return index
