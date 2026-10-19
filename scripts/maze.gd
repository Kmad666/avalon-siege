class_name Maze
extends RefCounted
## The labyrinth: a braided maze with open glades, your castle in one corner and
## the Dread Citadel in the opposite one. Also owns pathfinding (Dijkstra flow
## fields over the tile grid) and circle-vs-wall collision, so no physics engine
## is needed at all.

const FLOOR := 0
const WALL := 1
const KEEP := 2      # the player's castle (solid)
const CITADEL := 3   # the enemy fortress (solid)

const CELLS := 34
const G := CELLS * 2 + 1   # 69 tiles across
const T := 3.0             # tile size in metres
const WALL_H := 1.5

var tiles := PackedByteArray()
var wall_h := PackedFloat32Array()
var region := PackedFloat32Array()  # 0 = near castle (green) .. 1 = near citadel (ashen)
var explored := PackedByteArray()
var rooms: Array = []               # Rect2i in tile coords
var rng := RandomNumberGenerator.new()

var castle_tile := Vector2i(G - 5, G - 5)   # centre of the 3x3 keep
var citadel_tile := Vector2i(4, 4)          # centre of the 3x3 citadel
var castle_pos: Vector3
var citadel_pos: Vector3

var to_castle_dist := PackedInt32Array()
var to_castle_next := PackedInt32Array()
var to_citadel_dist := PackedInt32Array()
var to_citadel_next := PackedInt32Array()

const NB := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]


func generate(seed_v: int) -> void:
	rng.seed = seed_v
	tiles.resize(G * G)
	tiles.fill(WALL)
	explored.resize(G * G)
	explored.fill(0)
	_carve_maze()
	_braid(0.7)
	_carve_rooms()
	# Clearings around both fortresses.
	_clear(Rect2i(G - 12, G - 12, 11, 11))
	_clear(Rect2i(1, 1, 10, 10))
	# A few broad avenues so armies can flow and the hero has room to kite.
	for k in 5:
		var y := rng.randi_range(6, CELLS - 6) * 2 + 1
		var x0 := rng.randi_range(4, 14)
		_clear(Rect2i(x0, y, rng.randi_range(8, 16), 1))
		var x := rng.randi_range(6, CELLS - 6) * 2 + 1
		var y0 := rng.randi_range(4, 14)
		_clear(Rect2i(x, y0, 1, rng.randi_range(8, 16)))
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			_put_tile(castle_tile + Vector2i(dx, dy), KEEP)
			_put_tile(citadel_tile + Vector2i(dx, dy), CITADEL)
	# Archer tower plots around the castle are solid too.
	for tt: Vector2i in Castle.TOWER_TILES:
		_put_tile(castle_tile + tt, KEEP)
	castle_pos = tile_center(castle_tile)
	citadel_pos = tile_center(citadel_tile)
	wall_h.resize(G * G)
	region.resize(G * G)
	var span := float(G - 1) * 2.0
	for y in G:
		for x in G:
			var i := y * G + x
			# 0 at the castle corner, 1 at the citadel corner, wobbling a bit.
			var r := 1.0 - float(x + y) / span
			r += sin(x * 0.45 + y * 0.2) * 0.06 + cos(y * 0.37 - x * 0.15) * 0.06
			region[i] = clampf(r, 0.0, 1.0)
			wall_h[i] = WALL_H * rng.randf_range(0.85, 1.2)
			if region[i] > 0.7:
				# Broken ruins: jagged heights.
				wall_h[i] = WALL_H * rng.randf_range(0.45, 1.6)
	to_castle_dist = PackedInt32Array()
	var cs := _ring_sources(castle_tile)
	var res := field_from(cs, 1 << 30)
	to_castle_dist = res[0]
	to_castle_next = res[1]
	var res2 := field_from(_ring_sources(citadel_tile), 1 << 30)
	to_citadel_dist = res2[0]
	to_citadel_next = res2[1]


func _ring_sources(c: Vector2i) -> PackedInt32Array:
	var out := PackedInt32Array()
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			if absi(dx) == 2 or absi(dy) == 2:
				var t := c + Vector2i(dx, dy)
				if is_open_t(t):
					out.append(idx(t))
	return out


func _carve_maze() -> void:
	var visited := PackedByteArray()
	visited.resize(CELLS * CELLS)
	var stack: Array[Vector2i] = [Vector2i(CELLS - 1, CELLS - 1)]
	visited[(CELLS - 1) * CELLS + CELLS - 1] = 1
	_put_tile(Vector2i(CELLS * 2 - 1, CELLS * 2 - 1), FLOOR)
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	while not stack.is_empty():
		var c: Vector2i = stack.back()
		var opts: Array[Vector2i] = []
		for d in dirs:
			var n: Vector2i = c + d
			if n.x >= 0 and n.y >= 0 and n.x < CELLS and n.y < CELLS and visited[n.y * CELLS + n.x] == 0:
				opts.append(d)
		if opts.is_empty():
			stack.pop_back()
			continue
		var d: Vector2i = opts[rng.randi() % opts.size()]
		var n2: Vector2i = c + d
		visited[n2.y * CELLS + n2.x] = 1
		_put_tile(Vector2i(c.x * 2 + 1 + d.x, c.y * 2 + 1 + d.y), FLOOR)
		_put_tile(Vector2i(n2.x * 2 + 1, n2.y * 2 + 1), FLOOR)
		stack.append(n2)


## Knock out walls at dead ends so the maze has loops (no hopeless cul-de-sacs).
func _braid(chance: float) -> void:
	for cy in CELLS:
		for cx in CELLS:
			var t := Vector2i(cx * 2 + 1, cy * 2 + 1)
			var walls: Array[Vector2i] = []
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var w: Vector2i = t + d
				if w.x > 0 and w.y > 0 and w.x < G - 1 and w.y < G - 1 and tiles[idx(w)] == WALL:
					walls.append(w)
			if walls.size() >= 3 and rng.randf() < chance:
				_put_tile(walls[rng.randi() % walls.size()], FLOOR)


func _carve_rooms() -> void:
	var tries := 0
	while rooms.size() < 34 and tries < 700:
		tries += 1
		var w := rng.randi_range(3, 6) * 2 - 1
		var h := rng.randi_range(3, 6) * 2 - 1
		var x := rng.randi_range(1, CELLS - w / 2 - 2) * 2 + 1
		var y := rng.randi_range(1, CELLS - h / 2 - 2) * 2 + 1
		var r := Rect2i(x, y, w, h)
		if r.end.x >= G - 1 or r.end.y >= G - 1:
			continue
		# Keep rooms out of the fortress clearings.
		if r.intersects(Rect2i(G - 14, G - 14, 14, 14)) or r.intersects(Rect2i(0, 0, 13, 13)):
			continue
		var ok := true
		for o in rooms:
			if r.grow(2).intersects(o):
				ok = false
				break
		if not ok:
			continue
		rooms.append(r)
		_clear(r)
		# A pillar or two so glades don't feel empty.
		if w >= 7 and h >= 7 and rng.randf() < 0.6:
			_put_tile(Vector2i(x + w / 2, y + h / 2), WALL)


func _clear(r: Rect2i) -> void:
	for y in range(maxi(1, r.position.y), mini(G - 1, r.end.y)):
		for x in range(maxi(1, r.position.x), mini(G - 1, r.end.x)):
			tiles[y * G + x] = FLOOR


func _put_tile(t: Vector2i, v: int) -> void:
	if t.x >= 0 and t.y >= 0 and t.x < G and t.y < G:
		tiles[t.y * G + t.x] = v


static func idx(t: Vector2i) -> int:
	return t.y * G + t.x


static func tile_of(p: Vector3) -> Vector2i:
	return Vector2i(clampi(int(floor(p.x / T)), 0, G - 1), clampi(int(floor(p.z / T)), 0, G - 1))


static func tile_center(t: Vector2i) -> Vector3:
	return Vector3((t.x + 0.5) * T, 0.0, (t.y + 0.5) * T)


func is_open_t(t: Vector2i) -> bool:
	if t.x < 0 or t.y < 0 or t.x >= G or t.y >= G:
		return false
	return tiles[t.y * G + t.x] == FLOOR


func is_open_i(i: int) -> bool:
	return tiles[i] == FLOOR


func is_open_p(p: Vector3) -> bool:
	return is_open_t(tile_of(p))


## Dijkstra over the 8-connected grid (Dial's buckets: costs 10 / 14).
## Returns [dist, next] where next[i] is the neighbouring tile one step closer.
func field_from(sources: PackedInt32Array, max_cost: int) -> Array:
	var n := G * G
	var dist := PackedInt32Array()
	dist.resize(n)
	dist.fill(1 << 30)
	var nxt := PackedInt32Array()
	nxt.resize(n)
	nxt.fill(-1)
	var buckets: Array = []
	buckets.resize(16)
	for b in 16:
		buckets[b] = []
	var b0: Array = buckets[0]
	for s in sources:
		dist[s] = 0
		nxt[s] = s
		b0.append(s)
	var cur := 0
	var pending := sources.size()
	while pending > 0:
		var bi := cur % 16
		var bucket: Array = buckets[bi]
		if bucket.is_empty():
			cur += 1
			continue
		buckets[bi] = []
		for i: int in bucket:
			pending -= 1
			if dist[i] != cur:
				continue
			if cur > max_cost:
				continue
			var x := i % G
			var y := i / G
			for k in 8:
				var d: Vector2i = NB[k]
				var nx := x + d.x
				var ny := y + d.y
				if nx < 0 or ny < 0 or nx >= G or ny >= G:
					continue
				var j := ny * G + nx
				if tiles[j] != FLOOR:
					continue
				var c := 10
				if k >= 4:
					if tiles[y * G + nx] != FLOOR or tiles[ny * G + x] != FLOOR:
						continue
					c = 14
				var nd := cur + c
				if nd < dist[j]:
					dist[j] = nd
					nxt[j] = i
					(buckets[nd % 16] as Array).append(j)
					pending += 1
		cur += 1
	return [dist, nxt]


## Push a circle (xz) out of any solid tiles it overlaps.
func collide(p: Vector3, r: float) -> Vector3:
	var tx := int(floor(p.x / T))
	var ty := int(floor(p.z / T))
	# Fast path: well inside an open tile, nothing to do.
	var lx := p.x - tx * T
	var lz := p.z - ty * T
	if lx > r and lx < T - r and lz > r and lz < T - r and tx >= 0 and ty >= 0 and tx < G and ty < G and tiles[ty * G + tx] == FLOOR:
		return p
	for pass_i in 2:
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var x := tx + dx
				var y := ty + dy
				var solid := x < 0 or y < 0 or x >= G or y >= G
				if not solid:
					solid = tiles[y * G + x] != FLOOR
				if not solid:
					continue
				var minx := x * T
				var minz := y * T
				var cx := clampf(p.x, minx, minx + T)
				var cz := clampf(p.z, minz, minz + T)
				var ddx := p.x - cx
				var ddz := p.z - cz
				var d2 := ddx * ddx + ddz * ddz
				if d2 < r * r:
					if d2 > 1e-8:
						var d := sqrt(d2)
						p.x = cx + ddx / d * r
						p.z = cz + ddz / d * r
					else:
						# Centre inside the block: shove out along the shallowest axis.
						var l := p.x - minx
						var rr := minx + T - p.x
						var u := p.z - minz
						var dn := minz + T - p.z
						var m := minf(minf(l, rr), minf(u, dn))
						if m == l: p.x = minx - r
						elif m == rr: p.x = minx + T + r
						elif m == u: p.z = minz - r
						else: p.z = minz + T + r
	return p


## Cheap line-of-sight across the grid.
func line_clear(a: Vector3, b: Vector3) -> bool:
	var d := Vector3(b.x - a.x, 0, b.z - a.z)
	var l := d.length()
	var steps := int(l / (T * 0.4)) + 1
	for s in range(1, steps):
		var p := a + d * (float(s) / steps)
		if not is_open_t(tile_of(p)):
			return false
	return true


## Direction to walk along a flow field from p (xz unit vector, or ZERO).
func flow_dir(p: Vector3, nxt: PackedInt32Array) -> Vector3:
	var t := tile_of(p)
	var i := idx(t)
	var n := nxt[i]
	if n < 0:
		# Standing on an unreachable/solid tile: nudge toward any open neighbour.
		for d in NB:
			if is_open_t(t + d):
				var c := tile_center(t + d)
				return Vector3(c.x - p.x, 0, c.z - p.z).normalized()
		return Vector3.ZERO
	if n == i:
		return Vector3.ZERO
	# Look two steps ahead when the path is straight, for smoother walking.
	var n2 := nxt[n]
	var target := tile_center(Vector2i(n % G, n / G))
	if n2 >= 0 and n2 != n:
		var t2 := tile_center(Vector2i(n2 % G, n2 / G))
		if line_clear(p, t2):
			target = t2
	var dv := Vector3(target.x - p.x, 0, target.z - p.z)
	return dv.normalized() if dv.length_squared() > 1e-6 else Vector3.ZERO


func random_floor_in(r: Rect2i) -> Vector2i:
	for k in 40:
		var t := Vector2i(rng.randi_range(r.position.x, r.end.x - 1), rng.randi_range(r.position.y, r.end.y - 1))
		if is_open_t(t):
			return t
	return Vector2i(-1, -1)


func region_color(rg: float, green: Color, mid: Color, ash: Color) -> Color:
	if rg < 0.5:
		return green.lerp(mid, rg * 2.0)
	return mid.lerp(ash, (rg - 0.5) * 2.0)


# ---------------------------------------------------------------- meshes

## Ground, walls and decorations merged into a handful of meshes.
func build_meshes(parent: Node3D) -> void:
	var ground := Geo.new()
	var walls := Geo.new()
	var trees: Array[Transform3D] = []
	var dead_trees: Array[Transform3D] = []
	var deco := rng
	# Far skirt so the map edge isn't a void.
	ground.quad(Vector3(-60, -0.05, -60), Vector3(-60, -0.05, G * T + 60), Vector3(G * T + 60, -0.05, G * T + 60), Vector3(G * T + 60, -0.05, -60), Color(0.13, 0.17, 0.11))
	for y in G:
		for x in G:
			var i := y * G + x
			var rg := region[i]
			var x0 := x * T
			var z0 := y * T
			var tt := tiles[i]
			if tt == FLOOR or tt == KEEP or tt == CITADEL:
				var base := region_color(rg, Color(0.36, 0.55, 0.27), Color(0.47, 0.47, 0.3), Color(0.33, 0.29, 0.27))
				if tt == KEEP or _near(Vector2i(x, y), castle_tile, 5):
					base = Color(0.52, 0.5, 0.42) if (x + y) % 2 == 0 else Color(0.48, 0.46, 0.39)
				elif tt == CITADEL or _near(Vector2i(x, y), citadel_tile, 4):
					base = Color(0.2, 0.17, 0.18) if (x + y) % 2 == 0 else Color(0.24, 0.19, 0.19)
				var c := base.lightened(deco.randf_range(-0.04, 0.05))
				# Split the tile in two triangles with slightly different tones = faceted look.
				ground.tri(Vector3(x0, 0, z0), Vector3(x0 + T, 0, z0), Vector3(x0, 0, z0 + T), c)
				ground.tri(Vector3(x0 + T, 0, z0), Vector3(x0 + T, 0, z0 + T), Vector3(x0, 0, z0 + T), c.darkened(0.04))
				if tt == FLOOR and not _near(Vector2i(x, y), castle_tile, 5):
					_decorate(ground, Vector3(x0, 0, z0), rg)
			else:
				_wall_tile(walls, x, y, rg, trees, dead_trees)
	for g in [ground, walls]:
		var mi := MeshInstance3D.new()
		mi.mesh = g.mesh()
		Geo.apply(mi)
		parent.add_child(mi)
	_tree_multimesh(parent, trees, Models.tree_mesh())
	_tree_multimesh(parent, dead_trees, Models.dead_tree_mesh())


func _near(a: Vector2i, b: Vector2i, r: int) -> bool:
	return absi(a.x - b.x) <= r and absi(a.y - b.y) <= r


func _decorate(g: Geo, o: Vector3, rg: float) -> void:
	var n := rng.randi_range(0, 3)
	for k in n:
		var p := o + Vector3(rng.randf_range(0.3, T - 0.3), 0, rng.randf_range(0.3, T - 0.3))
		var roll := rng.randf()
		if roll < 0.55:
			# grass tuft
			var gc := region_color(rg, Color(0.3, 0.5, 0.2), Color(0.45, 0.43, 0.25), Color(0.3, 0.26, 0.22))
			g.prism(p, 0.14, 0.0, rng.randf_range(0.25, 0.45), 3, gc.darkened(0.1), Color(0, 0, 0, 0), rng.randf() * TAU)
		elif roll < 0.8:
			g.blob(p, rng.randf_range(0.12, 0.28), rng.randf_range(0.1, 0.22), Color(0.5, 0.49, 0.46).darkened(rg * 0.3), rng.randi(), 5, 1)
		elif rg < 0.55:
			var fc: Color = [Color(0.95, 0.85, 0.3), Color(0.9, 0.4, 0.45), Color(0.75, 0.6, 0.95), Color(0.95, 0.95, 0.9)][rng.randi() % 4]
			g.prism(p, 0.03, 0.03, 0.22, 3, Color(0.3, 0.5, 0.2))
			g.prism(p + Vector3(0, 0.22, 0), 0.1, 0.0, 0.06, 5, fc, fc)
		else:
			# bones / ash pile near the citadel
			g.box(p + Vector3(0, 0.04, 0), Vector3(0.35, 0.07, 0.08), Color(0.85, 0.82, 0.72))


func _wall_tile(g: Geo, x: int, y: int, rg: float, trees: Array[Transform3D], dead: Array[Transform3D]) -> void:
	var i := y * G + x
	var h := wall_h[i]
	var x0 := x * T
	var z0 := y * T
	var forest := rg < 0.42
	var ruin := rg > 0.7
	var side: Color
	var top: Color
	if forest:
		h *= 0.45
		side = Color(0.24, 0.33, 0.18)
		top = Color(0.2, 0.38, 0.17)
	elif ruin:
		side = Color(0.33, 0.29, 0.3) if (x + y) % 3 != 0 else Color(0.38, 0.3, 0.28)
		top = Color(0.4, 0.34, 0.34)
	else:
		side = Color(0.55, 0.53, 0.48)
		top = Color(0.42, 0.5, 0.3)  # mossy stone
	side = side.lightened(rng.randf_range(-0.05, 0.05))
	top = top.lightened(rng.randf_range(-0.05, 0.05))
	g.quad(Vector3(x0, h, z0), Vector3(x0, h, z0 + T), Vector3(x0 + T, h, z0 + T), Vector3(x0 + T, h, z0), top)
	# Side faces only where the neighbour is lower.
	var sides := [[Vector2i(0, 1), Vector3(x0, 0, z0 + T), Vector3(x0 + T, 0, z0 + T)],
		[Vector2i(0, -1), Vector3(x0 + T, 0, z0), Vector3(x0, 0, z0)],
		[Vector2i(1, 0), Vector3(x0 + T, 0, z0 + T), Vector3(x0 + T, 0, z0)],
		[Vector2i(-1, 0), Vector3(x0, 0, z0), Vector3(x0, 0, z0 + T)]]
	for s in sides:
		var nt: Vector2i = Vector2i(x, y) + s[0]
		var nh := 0.0
		if nt.x >= 0 and nt.y >= 0 and nt.x < G and nt.y < G and tiles[idx(nt)] == WALL:
			nh = _eff_h(nt)
		if nh >= h - 0.001:
			continue
		var a: Vector3 = s[1]
		var b: Vector3 = s[2]
		var sc: Color = side if s[0].y != 0 else side.darkened(0.12)
		g.quad(a + Vector3(0, nh, 0), b + Vector3(0, nh, 0), b + Vector3(0, h, 0), a + Vector3(0, h, 0), sc)
	var c := Vector3(x0 + T * 0.5, h, z0 + T * 0.5)
	if forest:
		var n := rng.randi_range(1, 2)
		for k in n:
			var p := c + Vector3(rng.randf_range(-0.7, 0.7), 0, rng.randf_range(-0.7, 0.7))
			var s2 := rng.randf_range(0.8, 1.15)
			trees.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s2, s2 * rng.randf_range(0.85, 1.1), s2)), p))
	elif ruin:
		var roll := rng.randf()
		if roll < 0.25:
			dead.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU), c))
		elif roll < 0.5:
			# Obsidian spikes.
			for k in rng.randi_range(1, 3):
				g.prism(c + Vector3(rng.randf_range(-0.9, 0.9), 0, rng.randf_range(-0.9, 0.9)), rng.randf_range(0.18, 0.32), 0.0, rng.randf_range(0.6, 1.4), 4, Color(0.22, 0.17, 0.2), Color(0, 0, 0, 0), rng.randf())
		elif roll < 0.75:
			# Rubble and a broken pillar stub.
			g.blob(c + Vector3(rng.randf_range(-0.6, 0.6), 0, rng.randf_range(-0.6, 0.6)), 0.5, 0.4, Color(0.4, 0.36, 0.35), rng.randi(), 5, 1)
			g.prism(c + Vector3(rng.randf_range(-0.5, 0.5), 0, rng.randf_range(-0.5, 0.5)), 0.3, 0.3, rng.randf_range(0.4, 0.9), 6, Color(0.5, 0.46, 0.44))
		elif roll < 0.85:
			# Ember crack glowing on the stone.
			g.box(c + Vector3(0, 0.01, 0), Vector3(rng.randf_range(0.8, 1.8), 0.02, 0.12), Color(1.0, 0.35, 0.1))
	else:
		# Crenellations on stone walls.
		if rng.randf() < 0.5:
			g.box(c + Vector3(-0.8, 0.18, -0.8), Vector3(0.6, 0.36, 0.6), side, top)
		if rng.randf() < 0.3:
			g.blob(c + Vector3(0.5, 0, 0.4), 0.55, 0.45, Color(0.3, 0.48, 0.22), rng.randi(), 5, 1)


func _eff_h(t: Vector2i) -> float:
	var i := idx(t)
	var h := wall_h[i]
	if region[i] < 0.42:
		h *= 0.45
	return h


func _tree_multimesh(parent: Node3D, xfs: Array[Transform3D], m: Mesh) -> void:
	if xfs.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = m
	mm.instance_count = xfs.size()
	for k in xfs.size():
		mm.set_instance_transform(k, xfs[k])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	Geo.apply(mmi)
	parent.add_child(mmi)
