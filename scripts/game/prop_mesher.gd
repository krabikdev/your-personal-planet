class_name PropMesher
extends RefCounted

## Collects primitive parts and merges them into a single mesh per material.
## A prop can be built from a hundred little meshes and still cost only a
## handful of draw calls, which is what lets the dry trees and the monsters have
## enough geometry to read as real shapes.

var _groups: Dictionary[int, Array] = {}
var _materials: Dictionary[int, StandardMaterial3D] = {}
var _order: Array[int] = []
var _part_count: int = 0


## Adds a primitive at an explicit transform.
func add(mesh: Mesh, xform: Transform3D, material: StandardMaterial3D) -> void:
	var key: int = material.get_instance_id()
	if not _groups.has(key):
		_groups[key] = []
		_materials[key] = material
		_order.append(key)
	(_groups[key] as Array).append({"mesh": mesh, "xform": xform})
	_part_count += 1


## Adds a primitive at a position, with a rotation in degrees and a scale.
func add_at(
	mesh: Mesh,
	position: Vector3,
	material: StandardMaterial3D,
	rotation_deg: Vector3 = Vector3.ZERO,
	scale: Vector3 = Vector3.ONE
) -> void:
	add(mesh, Transform3D(_basis(rotation_deg, scale), position), material)


## Adds a mesh whose local +Y axis points along `direction`. Tapered cylinders
## are built along Y, so this is how branches and twigs are aimed.
func add_along(
	mesh: Mesh,
	position: Vector3,
	direction: Vector3,
	material: StandardMaterial3D,
	scale: Vector3 = Vector3.ONE
) -> void:
	add(mesh, Transform3D(_along_basis(direction, scale), position), material)


func get_part_count() -> int:
	return _part_count


func get_material_count() -> int:
	return _order.size()


## Merges everything and adds one MeshInstance3D per material under `parent`.
## Returns the number of mesh instances created.
func commit(parent: Node3D) -> int:
	var created: int = 0
	for key: int in _order:
		var parts: Array = _groups[key]
		if parts.is_empty():
			continue
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		for part: Dictionary in parts:
			tool.append_from(part["mesh"] as Mesh, 0, part["xform"] as Transform3D)
		var merged: ArrayMesh = tool.commit()
		if merged == null:
			continue
		var node := MeshInstance3D.new()
		node.mesh = merged
		node.material_override = _materials[key]
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		parent.add_child(node)
		created += 1
	return created


static func _basis(rotation_deg: Vector3, scale: Vector3) -> Basis:
	var radians := Vector3(
		deg_to_rad(rotation_deg.x), deg_to_rad(rotation_deg.y), deg_to_rad(rotation_deg.z)
	)
	return Basis.from_euler(radians).scaled(scale)


static func _along_basis(direction: Vector3, scale: Vector3) -> Basis:
	var up: Vector3 = direction.normalized()
	var reference: Vector3 = Vector3.RIGHT
	if absf(up.dot(reference)) > 0.94:
		reference = Vector3.FORWARD
	var side: Vector3 = reference.cross(up).normalized()
	var other: Vector3 = side.cross(up).normalized()
	return Basis(side, up, other).scaled(scale)
