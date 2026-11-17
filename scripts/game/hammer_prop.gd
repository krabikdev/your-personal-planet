class_name HammerProp
extends Node3D

## A small wooden mallet the boy uses to drive the stake into the ground.

const WOOD := Color("5d4e43")
const IRON := Color("28222c")


func _init() -> void:
	name = "Hammer"
	position = Vector3(0.0, -0.278, 0.0)
	visible = false
	_build()


func _build() -> void:
	var wood := _material(WOOD, 0.9)
	var iron := _material(IRON, 0.55)

	var handle := CylinderMesh.new()
	handle.top_radius = 0.015
	handle.bottom_radius = 0.018
	handle.height = 0.36
	handle.radial_segments = 8
	_add_mesh(handle, wood, Vector3(0.0, -0.17, 0.0))

	var head := BoxMesh.new()
	head.size = Vector3(0.18, 0.085, 0.085)
	_add_mesh(head, iron, Vector3(0.0, -0.36, 0.0))

	var band := CylinderMesh.new()
	band.top_radius = 0.024
	band.bottom_radius = 0.024
	band.height = 0.03
	band.radial_segments = 8
	_add_mesh(band, iron, Vector3(0.0, -0.31, 0.0))


func _material(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material


func _add_mesh(mesh: Mesh, material: Material, offset: Vector3) -> void:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	node.position = offset
	add_child(node)
