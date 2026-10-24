class_name Geo
extends RefCounted
## Tiny low-poly mesh builder. Every triangle gets a flat normal and a vertex
## colour, so the whole world can share one vertex-colour material and batch well.

var verts := PackedVector3Array()
var norms := PackedVector3Array()
var cols := PackedColorArray()
var xf := Transform3D.IDENTITY
var _stack: Array[Transform3D] = []


func push(t: Transform3D) -> void:
	_stack.append(xf)
	xf = xf * t


func push_at(pos: Vector3, yaw := 0.0, scl := Vector3.ONE) -> void:
	var b := Basis(Vector3.UP, yaw).scaled(scl)
	push(Transform3D(b, pos))


func pop() -> void:
	xf = _stack.pop_back()


func tri(a: Vector3, b: Vector3, c: Vector3, col: Color) -> void:
	a = xf * a
	b = xf * b
	c = xf * c
	var n := (c - a).cross(b - a)
	if n.length_squared() < 1e-12:
		return
	n = n.normalized()
	verts.append(a); verts.append(b); verts.append(c)
	norms.append(n); norms.append(n); norms.append(n)
	cols.append(col); cols.append(col); cols.append(col)


## Quad a-b-c-d listed counter-clockwise when seen from the outside.
func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color) -> void:
	tri(a, c, b, col)
	tri(a, d, c, col)


## Axis-aligned box centred at c (bottom face skipped unless asked).
func box(c: Vector3, s: Vector3, col: Color, top := Color(0, 0, 0, 0), bottom := false, shade := true) -> void:
	var h := s * 0.5
	var tc := col.lightened(0.12) if top.a == 0.0 else top
	var x0 := c.x - h.x; var x1 := c.x + h.x
	var y0 := c.y - h.y; var y1 := c.y + h.y
	var z0 := c.z - h.z; var z1 := c.z + h.z
	var side_a := col
	var side_b := col.darkened(0.12) if shade else col
	quad(Vector3(x0, y1, z0), Vector3(x0, y1, z1), Vector3(x1, y1, z1), Vector3(x1, y1, z0), tc)
	quad(Vector3(x0, y0, z1), Vector3(x1, y0, z1), Vector3(x1, y1, z1), Vector3(x0, y1, z1), side_a)
	quad(Vector3(x1, y0, z0), Vector3(x0, y0, z0), Vector3(x0, y1, z0), Vector3(x1, y1, z0), side_a)
	quad(Vector3(x1, y0, z1), Vector3(x1, y0, z0), Vector3(x1, y1, z0), Vector3(x1, y1, z1), side_b)
	quad(Vector3(x0, y0, z0), Vector3(x0, y0, z1), Vector3(x0, y1, z1), Vector3(x0, y1, z0), side_b)
	if bottom:
		quad(Vector3(x0, y0, z0), Vector3(x1, y0, z0), Vector3(x1, y0, z1), Vector3(x0, y0, z1), col.darkened(0.3))


## Frustum / cylinder / cone / pyramid with `sides` sides, base at c.
func prism(c: Vector3, r0: float, r1: float, h: float, sides: int, col: Color, cap: Color = Color(0, 0, 0, 0), rot := 0.0, bottom := false) -> void:
	var capc := col.lightened(0.1) if cap.a == 0.0 else cap
	var top := c + Vector3(0, h, 0)
	for i in sides:
		var a0 := rot + TAU * i / sides
		var a1 := rot + TAU * (i + 1) / sides
		var d0 := Vector3(cos(a0), 0, sin(a0))
		var d1 := Vector3(cos(a1), 0, sin(a1))
		var p0 := c + d0 * r0
		var p1 := c + d1 * r0
		var q0 := top + d0 * r1
		var q1 := top + d1 * r1
		var shade := col.darkened(0.14 * (0.5 + 0.5 * sin(a0 * 1.0 + 0.8)))
		if r1 > 0.001:
			quad(p1, p0, q0, q1, shade)
			tri(top, q0, q1, capc)
		else:
			tri(p0, p1, top, shade)
		if bottom:
			tri(c, p1, p0, col.darkened(0.3))


## Chunky low-poly blob (rock / bush / foliage): a squashed, jittered octahedron-ish dome.
func blob(c: Vector3, r: float, h: float, col: Color, seed_v: int, sides := 6, rings := 2) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var pts: Array = []
	for k in rings + 1:
		var t := float(k) / rings
		var ring: Array = []
		var rr := r * sin(lerpf(0.35, PI * 0.5, 1.0 - t)) if k > 0 else r
		var yy := h * t * 0.85
		if k == rings:
			rr = r * 0.45
		for i in sides:
			var a := TAU * (i + 0.5 * k) / sides
			var j := rng.randf_range(0.82, 1.15)
			ring.append(c + Vector3(cos(a) * rr * j, yy + rng.randf_range(-0.06, 0.06) * h, sin(a) * rr * j))
		pts.append(ring)
	var apex := c + Vector3(rng.randf_range(-0.1, 0.1) * r, h, rng.randf_range(-0.1, 0.1) * r)
	for k in rings:
		var ra: Array = pts[k]
		var rb: Array = pts[k + 1]
		var cc := col.darkened(0.1 * (rings - k) / rings)
		for i in sides:
			var i1 := (i + 1) % sides
			var a: Vector3 = ra[i]
			var b: Vector3 = ra[i1]
			var a2: Vector3 = rb[i]
			var b2: Vector3 = rb[i1]
			var jitter := cc.lightened(rng.randf_range(-0.05, 0.08))
			tri(a, b, a2, jitter)
			tri(b, b2, a2, jitter.darkened(0.04))
	var last: Array = pts[rings]
	for i in sides:
		tri(last[i], last[(i + 1) % sides], apex, col.lightened(0.1))


## Flat disc on the ground (blob shadows, rings).
func disc(c: Vector3, r: float, sides: int, col: Color, sx := 1.0) -> void:
	for i in sides:
		var a0 := TAU * i / sides
		var a1 := TAU * (i + 1) / sides
		tri(c, c + Vector3(cos(a0) * r * sx, 0, sin(a0) * r), c + Vector3(cos(a1) * r * sx, 0, sin(a1) * r), col)


## Thin flat ring on the ground.
func ring(c: Vector3, r: float, w: float, sides: int, col: Color) -> void:
	for i in sides:
		var a0 := TAU * i / sides
		var a1 := TAU * (i + 1) / sides
		var d0 := Vector3(cos(a0), 0, sin(a0))
		var d1 := Vector3(cos(a1), 0, sin(a1))
		quad(c + d0 * r, c + d1 * r, c + d1 * (r + w), c + d0 * (r + w), col)


## Pointed crystal shard.
func shard(c: Vector3, r: float, h: float, col: Color, tilt := Vector3.ZERO) -> void:
	var top := c + Vector3(tilt.x, h, tilt.z)
	var mid := c + Vector3(tilt.x * 0.6, h * 0.62, tilt.z * 0.6)
	for i in 5:
		var a0 := TAU * i / 5.0
		var a1 := TAU * (i + 1) / 5.0
		var p0 := c + Vector3(cos(a0) * r * 0.7, 0, sin(a0) * r * 0.7)
		var p1 := c + Vector3(cos(a1) * r * 0.7, 0, sin(a1) * r * 0.7)
		var m0 := mid + Vector3(cos(a0) * r, 0, sin(a0) * r)
		var m1 := mid + Vector3(cos(a1) * r, 0, sin(a1) * r)
		var sh := col.darkened(0.15 * (0.5 + 0.5 * sin(a0 + 1.0)))
		quad(p1, p0, m0, m1, sh)
		tri(top, m0, m1, sh.lightened(0.15))


func is_empty() -> bool:
	return verts.is_empty()


## Build the mesh. With `outline_normals`, a smoothed normal per position is
## stored in CUSTOM0 so the ink-outline pass can push the hull out without
## cracking open at the flat-shaded hard edges.
func mesh(outline_normals := false) -> ArrayMesh:
	var am := ArrayMesh.new()
	if verts.is_empty():
		return am
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_COLOR] = cols
	var flags := 0
	if outline_normals:
		var acc := {}
		for i in verts.size():
			var k := Vector3i(roundi(verts[i].x * 500.0), roundi(verts[i].y * 500.0), roundi(verts[i].z * 500.0))
			acc[k] = acc.get(k, Vector3.ZERO) + norms[i]
		var cust := PackedFloat32Array()
		cust.resize(verts.size() * 3)
		for i in verts.size():
			var k2 := Vector3i(roundi(verts[i].x * 500.0), roundi(verts[i].y * 500.0), roundi(verts[i].z * 500.0))
			var n: Vector3 = acc[k2]
			n = n.normalized() if n.length_squared() > 1e-8 else norms[i]
			cust[i * 3] = n.x
			cust[i * 3 + 1] = n.y
			cust[i * 3 + 2] = n.z
		arr[Mesh.ARRAY_CUSTOM0] = cust
		flags = Mesh.ARRAY_CUSTOM_RGB_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr, [], {}, flags)
	return am


static var _mat: StandardMaterial3D
static var _mat_glow: StandardMaterial3D
static var _mat_unshaded: StandardMaterial3D


## Shared lit vertex-colour material (per-vertex lighting: cheap on iGPUs).
static func mat() -> StandardMaterial3D:
	if _mat == null:
		_mat = StandardMaterial3D.new()
		_mat.vertex_color_use_as_albedo = true
		_mat.vertex_color_is_srgb = true
		_mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
		_mat.roughness = 1.0
		_mat.metallic_specular = 0.0
		_mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return _mat


## Unshaded vertex colour: projectiles, sparks, magic. Reads as glowing.
static func mat_glow() -> StandardMaterial3D:
	if _mat_glow == null:
		_mat_glow = StandardMaterial3D.new()
		_mat_glow.vertex_color_use_as_albedo = true
		_mat_glow.vertex_color_is_srgb = true
		_mat_glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return _mat_glow


static var _mat_add: StandardMaterial3D


## Additive unshaded: fades to nothing as the colour goes to black. Magic & slashes.
static func mat_add() -> StandardMaterial3D:
	if _mat_add == null:
		_mat_add = StandardMaterial3D.new()
		_mat_add.vertex_color_use_as_albedo = true
		_mat_add.vertex_color_is_srgb = true
		_mat_add.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_mat_add.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_mat_add.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_mat_add.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		_mat_add.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _mat_add


static func apply(mi: GeometryInstance3D, glow := false) -> void:
	mi.material_override = mat_glow() if glow else mat()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
