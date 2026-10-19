class_name Batch
extends RefCounted
## A MultiMesh whose instances are re-written every frame from scratch.
## One draw call for any number of identical things.

var mm := MultiMesh.new()
var mmi := MultiMeshInstance3D.new()
var buf := PackedFloat32Array()
var n := 0
var cap := 0


func _init(parent: Node3D, mesh: Mesh, capacity: int, material: Material) -> void:
	cap = capacity
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = capacity
	mm.visible_instance_count = 0
	buf.resize(capacity * 16)
	mmi.multimesh = mm
	mmi.material_override = material
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.custom_aabb = AABB(Vector3(-50, -10, -50), Vector3(250, 60, 250))
	parent.add_child(mmi)


func begin() -> void:
	n = 0


func add(b: Basis, p: Vector3, c: Color) -> void:
	if n >= cap:
		return
	var o := n * 16
	buf[o] = b.x.x; buf[o + 1] = b.y.x; buf[o + 2] = b.z.x; buf[o + 3] = p.x
	buf[o + 4] = b.x.y; buf[o + 5] = b.y.y; buf[o + 6] = b.z.y; buf[o + 7] = p.y
	buf[o + 8] = b.x.z; buf[o + 9] = b.y.z; buf[o + 10] = b.z.z; buf[o + 11] = p.z
	buf[o + 12] = c.r; buf[o + 13] = c.g; buf[o + 14] = c.b; buf[o + 15] = c.a
	n += 1


func finish() -> void:
	if n == 0 and mm.visible_instance_count == 0:
		return
	mm.buffer = buf
	mm.visible_instance_count = n
