class_name Terrain
extends Node3D
## The valley of the Sigurd legend: a long rectangle (192 m x 1024 m) walled
## by mountains. A winding path runs from Regin's forge at the southern end
## (+z) to Fafnir's lair under the northern cliffs (-z). Medium hills thick
## with dark pine break up the land; the forest withers into the blasted
## heath of Gnitaheath as you near the wurm.

const W := 192.0
const L := 1024.0
const CELL := 2.0
const NX := 96                # cells across
const NZ := 512               # cells along
const CHUNK := 32             # cells per chunk side

var heights := PackedFloat32Array()
var n_hill := FastNoiseLite.new()
var n_var := FastNoiseLite.new()
var n_detail := FastNoiseLite.new()
var n_path := FastNoiseLite.new()
var rng := RandomNumberGenerator.new()

# Landmarks (x, z on the ground). Filled in by _plan().
var forge := Vector2.ZERO
var start := Vector2.ZERO
var mounds: Array[Vector2] = []
var ring := Vector2.ZERO
var pool := Vector2.ZERO
var cave := Vector2.ZERO
var runestones: Array[Vector2] = []
var flats: Array = []           # [Vector2 centre, radius]: hills suppressed here

var trees_pine: Array = []      # per chunk: Array[Transform3D]
var trees_broad: Array = []
var trees_dead: Array = []
var shrubs: Array = []
var rocks: Array = []


func generate(seed_v: int) -> void:
	rng.seed = seed_v
	for n in [n_hill, n_var, n_detail, n_path]:
		(n as FastNoiseLite).seed = rng.randi()
		(n as FastNoiseLite).noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n_hill.frequency = 0.0115
	n_hill.fractal_octaves = 3
	n_var.frequency = 0.03
	n_detail.frequency = 0.07
	n_path.frequency = 0.006
	_plan()
	heights.resize((NX + 1) * (NZ + 1))
	for iz in NZ + 1:
		for ix in NX + 1:
			heights[iz * (NX + 1) + ix] = _height(ix * CELL, iz * CELL)
	var nchunks := (NX / CHUNK) * (NZ / CHUNK)
	for a in [trees_pine, trees_broad, trees_dead, shrubs, rocks]:
		(a as Array).resize(nchunks)
		for i in nchunks:
			a[i] = [] as Array[Transform3D]
	_scatter()


# ------------------------------------------------------------- shape

func path_x(z: float) -> float:
	return W * 0.5 + 34.0 * sin(z * 0.0061 + 1.3) + 16.0 * sin(z * 0.0157 + 0.4) + 10.0 * n_path.get_noise_1d(z)


## 0 at the southern start, 1 at the wurm's lair.
func progress(z: float) -> float:
	return clampf(1.0 - z / L, 0.0, 1.0)


func _plan() -> void:
	start = Vector2(path_x(L - 32.0), L - 32.0)
	forge = Vector2(path_x(L - 58.0) + 13.0, L - 58.0)
	mounds = [Vector2(path_x(770.0) - 26.0, 770.0), Vector2(path_x(752.0) - 38.0, 752.0), Vector2(path_x(735.0) - 24.0, 735.0)]
	ring = Vector2(path_x(560.0) + 22.0, 560.0)
	pool = Vector2(path_x(300.0) + 26.0, 300.0)
	cave = Vector2(path_x(30.0), 30.0)
	for z in [930.0, 850.0, 660.0, 470.0, 390.0, 210.0, 130.0]:
		var side := 1.0 if int(z) % 3 == 0 else -1.0
		runestones.append(Vector2(path_x(z) + side * 7.5, z))
	flats = [[forge, 16.0], [start, 14.0], [ring, 17.0], [pool, 16.0], [cave + Vector2(0, 22), 18.0]]
	for m in mounds:
		flats.append([m, 12.0])


## The wurm's trail: a scorched furrow it has worn from its cave to the pool.
func trail_x(z: float) -> float:
	return path_x(z) + 4.5


func trail_dist(x: float, z: float) -> float:
	if z < 40.0 or z > 312.0:
		return 999.0
	if z > 284.0:
		# The final bend down into the pool.
		var t := (z - 284.0) / 28.0
		var tx := lerpf(trail_x(284.0), pool.x - 8.0, t)
		return absf(x - tx)
	return absf(x - trail_x(z))


func _flat_mask(x: float, z: float) -> float:
	var m := 0.0
	for f in flats:
		var c: Vector2 = f[0]
		var r: float = f[1]
		var d := Vector2(x - c.x, z - c.y).length()
		m = maxf(m, 1.0 - smoothstep(r * 0.6, r, d))
	return m


func hill_value(x: float, z: float) -> float:
	var n := n_hill.get_noise_2d(x, z)
	var hv := clampf(n * 1.35 + 0.3, 0.0, 1.0)
	return hv * hv * (3.0 - 2.0 * hv)


func edge_value(x: float, z: float) -> float:
	var e := smoothstep(W * 0.5 - 36.0, W * 0.5 - 4.0, absf(x - W * 0.5))
	e = maxf(e, smoothstep(L - 22.0, L, z))           # southern wall behind the forge
	e = maxf(e, smoothstep(26.0, 2.0, z))             # the northern cliffs
	return e


func _height(x: float, z: float) -> float:
	var p := progress(z)
	var d := absf(x - path_x(z))
	var hv := hill_value(x, z)
	var hills := hv * (11.0 + 8.0 * n_var.get_noise_2d(x, z))
	# Gnitaheath: the hills sink into a bleak, open heath near the lair.
	hills *= lerpf(1.0, 0.3, smoothstep(0.76, 0.9, p))
	hills *= smoothstep(5.0, 21.0, d)                 # the valley floor the path follows
	hills *= 1.0 - _flat_mask(x, z)
	var h := n_detail.get_noise_2d(x, z) * 0.9 + n_var.get_noise_2d(x * 0.5, z * 0.5) * 1.6 + hills
	var e := edge_value(x, z)
	h += e * (28.0 + 12.0 * n_var.get_noise_2d(x * 1.3, z * 1.3))
	# The pool, and the furrow the wurm has worn on its way to drink.
	var pd := Vector2(x - pool.x, z - pool.y).length()
	h -= 2.6 * (1.0 - smoothstep(4.0, 10.0, pd))
	h -= 0.7 * (1.0 - smoothstep(1.0, 2.6, trail_dist(x, z)))
	# Burial mounds.
	for m in mounds:
		var md := Vector2(x - m.x, z - m.y).length()
		h += 3.2 * (1.0 - smoothstep(0.0, 7.0, md))
	# The cave: carve a dark mouth into the cliff face.
	var cd := Vector2((x - cave.x) * 0.8, z - cave.y).length()
	h -= 9.0 * (1.0 - smoothstep(3.0, 9.0, cd)) * smoothstep(34.0, 18.0, z)
	return h


## Ground height at any point (bilinear over the grid, matches the mesh well).
func height_at(x: float, z: float) -> float:
	var fx := clampf(x / CELL, 0.0, NX - 0.001)
	var fz := clampf(z / CELL, 0.0, NZ - 0.001)
	var ix := int(fx)
	var iz := int(fz)
	var tx := fx - ix
	var tz := fz - iz
	var r := NX + 1
	var a := heights[iz * r + ix]
	var b := heights[iz * r + ix + 1]
	var c := heights[(iz + 1) * r + ix]
	var e := heights[(iz + 1) * r + ix + 1]
	return lerpf(lerpf(a, b, tx), lerpf(c, e, tx), tz)


# ------------------------------------------------------------- colour

func _ground_color(x: float, z: float, n: Vector3) -> Color:
	var p := progress(z)
	var slope := 1.0 - n.y
	var d := absf(x - path_x(z))
	var hv := hill_value(x, z)
	var e := edge_value(x, z)
	var j := n_detail.get_noise_2d(x * 3.1, z * 3.1) * 0.05
	# Deep snow over the whole valley, a touch greyer and more trodden under the trees.
	var snow := Color(0.8, 0.82, 0.87)
	var forest := Color(0.7, 0.72, 0.78)
	var c := snow.lerp(forest, smoothstep(0.25, 0.6, hv) * smoothstep(8.0, 20.0, d))
	# Mountains: wind-scoured snow.
	c = c.lerp(Color(0.8, 0.82, 0.87), smoothstep(0.3, 0.8, e))
	# Steep faces are bare dark rock, where snow can't cling.
	c = c.lerp(Color(0.3, 0.31, 0.35), smoothstep(0.42, 0.62, slope))
	# The path: snow churned to grey slush and frozen mud.
	c = c.lerp(Color(0.52, 0.5, 0.49), 1.0 - smoothstep(1.6, 3.6, d))
	c = c.lerp(Color(0.38, 0.33, 0.29), (1.0 - smoothstep(0.4, 1.4, d)) * 0.6)
	# The wurm's trail has melted the snow to black, scorched earth; the heath is ash on snow.
	var td := trail_dist(x, z)
	c = c.lerp(Color(0.12, 0.1, 0.09), (1.0 - smoothstep(1.2, 3.2, td)) * 0.9)
	c = c.lerp(Color(0.5, 0.49, 0.5), smoothstep(0.9, 0.98, p) * 0.7)
	return c.lightened(j) if j > 0.0 else c.darkened(-j)


# ------------------------------------------------------------- meshes

func build(parent: Node3D) -> void:
	var cx_n := NX / CHUNK
	var cz_n := NZ / CHUNK
	var r := NX + 1
	for cz in cz_n:
		for cx in cx_n:
			var g := Geo.new()
			for iz in range(cz * CHUNK, (cz + 1) * CHUNK):
				for ix in range(cx * CHUNK, (cx + 1) * CHUNK):
					var x0 := ix * CELL
					var z0 := iz * CELL
					var p00 := Vector3(x0, heights[iz * r + ix], z0)
					var p10 := Vector3(x0 + CELL, heights[iz * r + ix + 1], z0)
					var p01 := Vector3(x0, heights[(iz + 1) * r + ix], z0 + CELL)
					var p11 := Vector3(x0 + CELL, heights[(iz + 1) * r + ix + 1], z0 + CELL)
					# Alternate the diagonal for a less regular facet pattern.
					if (ix + iz) % 2 == 0:
						_tri(g, p00, p10, p01)
						_tri(g, p10, p11, p01)
					else:
						_tri(g, p00, p11, p01)
						_tri(g, p00, p10, p11)
			var mi := MeshInstance3D.new()
			mi.mesh = g.mesh(false)
			Toon.apply(mi, Toon.mat(false), true)
			parent.add_child(mi)
			var ci := cz * cx_n + cx
			_multimesh(parent, Props.pine(), trees_pine[ci], 160.0, Toon.foliage())
			_multimesh(parent, Props.broadleaf(), trees_broad[ci], 160.0, Toon.foliage())
			_multimesh(parent, Props.dead_tree(), trees_dead[ci], 160.0, Toon.mat(true))
			_multimesh(parent, Props.shrub(), shrubs[ci], 90.0, Toon.foliage(), false)
			_multimesh(parent, Props.boulder(), rocks[ci], 130.0, Toon.mat(true))
	_build_backdrop(parent)


func _tri(g: Geo, a: Vector3, b: Vector3, c: Vector3) -> void:
	var cen := (a + b + c) / 3.0
	var n := (c - a).cross(b - a).normalized()
	if n.y < 0.0:
		n = -n
	g.tri(a, b, c, _ground_color(cen.x, cen.z, n))


func _multimesh(parent: Node3D, mesh: Mesh, xfs: Array, vis: float, mat: Material, shadows := true) -> void:
	if xfs.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = xfs.size()
	for i in xfs.size():
		var t: Transform3D = xfs[i]
		mm.set_instance_transform(i, t)
		var v := 0.85 + 0.3 * rng.randf()
		mm.set_instance_color(i, Color(v, v * rng.randf_range(0.95, 1.05), v))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.visibility_range_end = vis
	mmi.visibility_range_end_margin = 20.0
	mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
	Toon.apply(mmi, mat, shadows)
	parent.add_child(mmi)


## Far peaks beyond the valley walls, and a dark plain under everything.
func _build_backdrop(parent: Node3D) -> void:
	var g := Geo.new()
	g.quad(Vector3(-3000, -2, -3000), Vector3(-3000, -2, L + 3000), Vector3(W + 3000, -2, L + 3000), Vector3(W + 3000, -2, -3000), Color(0.6, 0.62, 0.66))
	var brng := RandomNumberGenerator.new()
	brng.seed = 99
	for k in 70:
		var side := k % 4
		var x: float
		var z: float
		match side:
			0:
				x = brng.randf_range(-140, -30)
				z = brng.randf_range(-120, L + 120)
			1:
				x = W + brng.randf_range(30, 140)
				z = brng.randf_range(-120, L + 120)
			2:
				x = brng.randf_range(-120, W + 120)
				z = brng.randf_range(-160, -30)
			_:
				x = brng.randf_range(-120, W + 120)
				z = L + brng.randf_range(30, 140)
		var hh := brng.randf_range(45, 110)
		var rr := hh * brng.randf_range(0.7, 1.1)
		g.prism(Vector3(x, -2, z), rr, 0.0, hh, brng.randi_range(5, 7), Color(0.5, 0.52, 0.57), Color(0.85, 0.87, 0.91), brng.randf() * TAU)
	var mi := MeshInstance3D.new()
	mi.mesh = g.mesh(false)
	Toon.apply(mi, Toon.mat(false), false)
	parent.add_child(mi)


# ------------------------------------------------------------- scatter

func _chunk_of(x: float, z: float) -> int:
	var cx := clampi(int(x / CELL) / CHUNK, 0, NX / CHUNK - 1)
	var cz := clampi(int(z / CELL) / CHUNK, 0, NZ / CHUNK - 1)
	return cz * (NX / CHUNK) + cx


func _near_landmark(x: float, z: float, pad: float) -> bool:
	for f in flats:
		if Vector2(x - f[0].x, z - f[0].y).length() < f[1] * 0.7 + pad:
			return true
	for rs in runestones:
		if Vector2(x - rs.x, z - rs.y).length() < 3.0 + pad:
			return true
	return false


func _scatter() -> void:
	var step := 3.3
	var z := 2.0
	while z < L - 2.0:
		var x := 2.0
		while x < W - 2.0:
			var px := x + rng.randf_range(-1.4, 1.4)
			var pz := z + rng.randf_range(-1.4, 1.4)
			_try_tree(px, pz)
			x += step
		z += step
	# Boulders, heavier on the slopes and the heath.
	for k in 900:
		var bx := rng.randf_range(4, W - 4)
		var bz := rng.randf_range(4, L - 4)
		var d := absf(bx - path_x(bz))
		if d < 4.0 or _near_landmark(bx, bz, 1.0):
			continue
		var s := rng.randf_range(0.5, 1.6) * (1.6 if edge_value(bx, bz) > 0.3 else 1.0)
		var t := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.6, 1.0), s)), Vector3(bx, height_at(bx, bz) - 0.15 * s, bz))
		(rocks[_chunk_of(bx, bz)] as Array).append(t)


func _try_tree(x: float, z: float) -> void:
	var p := progress(z)
	var d := absf(x - path_x(z))
	if d < 5.0 or _near_landmark(x, z, 2.0):
		return
	var hv := hill_value(x, z)
	var e := edge_value(x, z)
	var h := height_at(x, z)
	# Hills are thick with trees; the valley floor is open meadow.
	var density := 0.05 + 0.8 * smoothstep(0.15, 0.55, hv) * smoothstep(7.0, 18.0, d)
	density = maxf(density, 0.55 * smoothstep(0.1, 0.4, e) * (1.0 - smoothstep(0.55, 0.85, e)))
	density *= lerpf(1.0, 0.25, smoothstep(0.75, 0.92, p))
	if d < 14.0:
		density *= 0.4
	if rng.randf() > density:
		if rng.randf() < 0.04 and d > 6.0 and p < 0.85:
			_place(shrubs, x, z, h, rng.randf_range(0.7, 1.3))
		return
	var dead_chance := smoothstep(0.7, 0.88, p) * 0.95 + 0.02
	var s := rng.randf_range(0.8, 1.25)
	if rng.randf() < dead_chance:
		_place(trees_dead, x, z, h - 0.1, s)
	elif p > 0.25 and p < 0.75 and rng.randf() < 0.28 and e < 0.3:
		_place(trees_broad, x, z, h - 0.1, s)
	else:
		_place(trees_pine, x, z, h - 0.15, s * rng.randf_range(0.9, 1.2))


func _place(list: Array, x: float, z: float, y: float, s: float) -> void:
	var b := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3(1, 0, 0), rng.randf_range(-0.05, 0.05))
	b = b.scaled(Vector3(s, s * rng.randf_range(0.9, 1.15), s))
	(list[_chunk_of(x, z)] as Array).append(Transform3D(b, Vector3(x, y, z)))
