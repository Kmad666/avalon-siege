class_name Maze
extends RefCounted
## The realm. Camelot sits in one corner and the Dread Citadel in the opposite
## one, joined by a single War Lane. Two Royal Roads run from Camelot to treasure
## hubs in the far corners and the Kingsroad links those hubs across the middle;
## the roads are fast but held by Dread garrisons. Between them lie solid forest
## and ruin, threaded with branching trails that lead to glades and walled maze
## pockets, each hiding a reward at its heart.
## Also owns pathfinding (Dijkstra flow fields) and circle-vs-wall collision.

const FLOOR := 0
const WALL := 1
const KEEP := 2      # the player's castle (solid)
const CITADEL := 3   # the enemy fortress (solid)

const G := 85              # tiles across (~255 m)
const T := 3.0             # tile size in metres
const WALL_H := 1.5

# lane[] values
const L_NONE := 0
const L_WAR := 1
const L_ROAD := 2
const L_TRAIL := 3

var tiles := PackedByteArray()
var wall_h := PackedFloat32Array()
var region := PackedFloat32Array()  # 0 = near castle (green) .. 1 = near citadel (ashen)
var explored := PackedByteArray()
var lane := PackedByteArray()
var protect := PackedByteArray()    # 1 = inside a maze pocket (trails route around)
var rooms: Array = []               # glades (Rect2i), hubs included
var pockets: Array = []             # {rect, entrance, reward, kind}
var hubs: Array[Vector2i] = []
var garrisons: Array = []           # [Vector2i tile, road name]
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
const N4 := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]


func generate(seed_v: int) -> void:
	rng.seed = seed_v
	var n := G * G
	tiles.resize(n)
	tiles.fill(WALL)
	explored.resize(n)
	explored.fill(0)
	lane.resize(n)
	lane.fill(L_NONE)
	protect.resize(n)
	protect.fill(0)
	region.resize(n)
	wall_h.resize(n)
	var span := float(G - 1) * 2.0
	for y in G:
		for x in G:
			var i := y * G + x
			var r := 1.0 - float(x + y) / span
			r += sin(x * 0.37 + y * 0.17) * 0.05 + cos(y * 0.29 - x * 0.13) * 0.05
			region[i] = clampf(r, 0.0, 1.0)
			wall_h[i] = WALL_H * rng.randf_range(0.85, 1.2)
			if region[i] > 0.7:
				wall_h[i] = WALL_H * rng.randf_range(0.45, 1.6)
	_layout_lanes()
	_place_pockets()
	_place_glades()
	_carve_lanes()
	_carve_trails()
	# Fortress clearings.
	_clear(Rect2i(G - 13, G - 13, 12, 12))
	_clear(Rect2i(1, 1, 11, 11))
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			_put_tile(castle_tile + Vector2i(dx, dy), KEEP)
			_put_tile(citadel_tile + Vector2i(dx, dy), CITADEL)
	for tt: Vector2i in Castle.TOWER_TILES:
		_put_tile(castle_tile + tt, KEEP)
	_cull_unreachable()
	castle_pos = tile_center(castle_tile)
	citadel_pos = tile_center(citadel_tile)
	# The road network is common knowledge: reveal it on the map.
	for i in n:
		if lane[i] == L_WAR or lane[i] == L_ROAD:
			explored[i] = 1
	var res := field_from(_ring_sources(castle_tile), 1 << 30)
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


# ------------------------------------------------------------- layout

var _segments: Array = []   # [Vector2 a, Vector2 b, half_width, lane value]


func _layout_lanes() -> void:
	var ne := Vector2i(G - 8, 7)
	var sw := Vector2i(7, G - 8)
	hubs = [ne, sw]
	var c := Vector2(castle_tile)
	var d := Vector2(citadel_tile)
	_segments = [
		[c, d, 2.7, L_WAR],                                   # the War Lane
		[c, Vector2(G - 5, 8), 1.7, L_ROAD],                  # East Road
		[c, Vector2(8, G - 5), 1.7, L_ROAD],                  # South Road
		[Vector2(ne), Vector2(sw), 1.6, L_ROAD],              # Kingsroad
	]
	for s in _segments:
		_paint_segment(s[0], s[1], s[2], s[3])
	for h in hubs:
		_paint_disc(Vector2(h), 5.5, L_ROAD)
	# Garrisons: tough Dread outposts squatting on the roads.
	var spots := [[c, Vector2(G - 5, 8), 0.42, "East Road"], [c, Vector2(G - 5, 8), 0.78, "East Road"],
		[c, Vector2(8, G - 5), 0.42, "South Road"], [c, Vector2(8, G - 5), 0.78, "South Road"],
		[Vector2(ne), Vector2(sw), 0.27, "Kingsroad"], [Vector2(ne), Vector2(sw), 0.73, "Kingsroad"]]
	for sp in spots:
		var p: Vector2 = (sp[0] as Vector2).lerp(sp[1], sp[2])
		garrisons.append([Vector2i(roundi(p.x), roundi(p.y)), sp[3]])


func _paint_segment(a: Vector2, b: Vector2, hw: float, v: int) -> void:
	var x0 := maxi(1, int(minf(a.x, b.x) - hw - 1))
	var x1 := mini(G - 2, int(maxf(a.x, b.x) + hw + 1))
	var y0 := maxi(1, int(minf(a.y, b.y) - hw - 1))
	var y1 := mini(G - 2, int(maxf(a.y, b.y) + hw + 1))
	var ab := b - a
	var l2 := ab.length_squared()
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var p := Vector2(x, y)
			var t := clampf((p - a).dot(ab) / l2, 0.0, 1.0)
			# A little wobble so roads don't look ruled.
			var wob := sin(t * 23.0 + a.x) * 0.45
			if p.distance_to(a + ab * t) <= hw + wob:
				var i := y * G + x
				if lane[i] == L_NONE or v < lane[i]:
					lane[i] = v


func _paint_disc(c: Vector2, r: float, v: int) -> void:
	for y in range(maxi(1, int(c.y - r - 1)), mini(G - 1, int(c.y + r + 2))):
		for x in range(maxi(1, int(c.x - r - 1)), mini(G - 1, int(c.x + r + 2))):
			if Vector2(x, y).distance_to(c) <= r:
				var i := y * G + x
				if lane[i] == L_NONE:
					lane[i] = v


## True if any lane tile lies within `m` tiles of rect r.
func _near_lane(r: Rect2i, m: int) -> bool:
	for y in range(maxi(0, r.position.y - m), mini(G, r.end.y + m)):
		for x in range(maxi(0, r.position.x - m), mini(G, r.end.x + m)):
			if lane[y * G + x] != L_NONE:
				return true
	return false


func _blocked_rect(r: Rect2i) -> bool:
	if r.position.x < 2 or r.position.y < 2 or r.end.x > G - 2 or r.end.y > G - 2:
		return true
	if r.intersects(Rect2i(G - 16, G - 16, 16, 16)) or r.intersects(Rect2i(0, 0, 15, 15)):
		return true
	return false


func _place_pockets() -> void:
	var tries := 0
	while pockets.size() < 13 and tries < 3000:
		tries += 1
		var w := rng.randi_range(4, 7) * 2 + 1
		var h := rng.randi_range(4, 7) * 2 + 1
		var x := rng.randi_range(2, G - w - 3)
		var y := rng.randi_range(2, G - h - 3)
		var r := Rect2i(x, y, w, h)
		if _blocked_rect(r) or _near_lane(r, 2):
			continue
		var ok := true
		for p in pockets:
			if r.grow(3).intersects(p.rect):
				ok = false
				break
		if not ok:
			continue
		pockets.append(_carve_pocket(r))
	# Rewards: five spellbooks, the rest split between treasure and gold.
	var order := range(pockets.size())
	order.shuffle()
	for k in order.size():
		var pk: Dictionary = pockets[order[k]]
		pk.kind = "book" if k < 5 else ("chest" if k % 2 == 1 else "gold")


## A walled labyrinth with one entrance; the reward sits at its deepest point.
func _carve_pocket(r: Rect2i) -> Dictionary:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			protect[y * G + x] = 1
	var cw := (r.size.x - 1) / 2
	var ch := (r.size.y - 1) / 2
	var visited := PackedByteArray()
	visited.resize(cw * ch)
	var start := Vector2i(rng.randi_range(0, cw - 1), rng.randi_range(0, ch - 1))
	var stack: Array[Vector2i] = [start]
	visited[start.y * cw + start.x] = 1
	var origin := r.position + Vector2i(1, 1)
	_put_tile(origin + start * 2, FLOOR)
	while not stack.is_empty():
		var c: Vector2i = stack.back()
		var opts: Array[Vector2i] = []
		for d in N4:
			var nn: Vector2i = c + d
			if nn.x >= 0 and nn.y >= 0 and nn.x < cw and nn.y < ch and visited[nn.y * cw + nn.x] == 0:
				opts.append(d)
		if opts.is_empty():
			stack.pop_back()
			continue
		var dd: Vector2i = opts[rng.randi() % opts.size()]
		var n2: Vector2i = c + dd
		visited[n2.y * cw + n2.x] = 1
		_put_tile(origin + c * 2 + dd, FLOOR)
		_put_tile(origin + n2 * 2, FLOOR)
		stack.append(n2)
	# A few loops so it isn't a pure tree.
	for k in (cw * ch) / 6:
		var t := origin + Vector2i(rng.randi_range(0, cw - 1) * 2, rng.randi_range(0, ch - 1) * 2)
		var dd2: Vector2i = N4[rng.randi() % 4]
		var wt := t + dd2
		if r.grow(-1).has_point(wt) and tiles[idx(wt)] == WALL:
			_put_tile(wt, FLOOR)
	# Entrance on the side facing the nearest lane.
	var centre := r.get_center()
	var best := Vector2i(-1, -1)
	var bd := INF
	for y in range(maxi(1, centre.y - 30), mini(G - 1, centre.y + 30), 2):
		for x in range(maxi(1, centre.x - 30), mini(G - 1, centre.x + 30), 2):
			if lane[y * G + x] != L_NONE:
				var dist := Vector2(x - centre.x, y - centre.y).length()
				if dist < bd:
					bd = dist
					best = Vector2i(x, y)
	var dir := Vector2(best - centre) if best.x >= 0 else Vector2(1, 1)
	var ent: Vector2i
	if absf(dir.x) * r.size.y > absf(dir.y) * r.size.x:
		var ex := r.end.x - 1 if dir.x > 0 else r.position.x
		var cy := r.position.y + 1 + clampi(roundi((centre.y - r.position.y - 1) / 2.0), 0, ch - 1) * 2
		ent = Vector2i(ex, cy)
	else:
		var ey := r.end.y - 1 if dir.y > 0 else r.position.y
		var cx := r.position.x + 1 + clampi(roundi((centre.x - r.position.x - 1) / 2.0), 0, cw - 1) * 2
		ent = Vector2i(cx, ey)
	_put_tile(ent, FLOOR)
	# Reward: the floor tile furthest from the entrance.
	var far := ent
	var dist_map := {ent: 0}
	var q: Array[Vector2i] = [ent]
	var qi := 0
	while qi < q.size():
		var c2: Vector2i = q[qi]
		qi += 1
		for d in N4:
			var nb: Vector2i = c2 + d
			if r.has_point(nb) and tiles[idx(nb)] == FLOOR and not dist_map.has(nb):
				dist_map[nb] = dist_map[c2] + 1
				q.append(nb)
				if dist_map[nb] > dist_map[far]:
					far = nb
	return {"rect": r, "entrance": ent, "reward": far, "kind": "gold"}


func _place_glades() -> void:
	var tries := 0
	while rooms.size() < 30 and tries < 4000:
		tries += 1
		var w := rng.randi_range(5, 9)
		var h := rng.randi_range(5, 9)
		var r := Rect2i(rng.randi_range(2, G - w - 3), rng.randi_range(2, G - h - 3), w, h)
		if _blocked_rect(r) or _near_lane(r, 1):
			continue
		var ok := true
		for p in pockets:
			if r.grow(2).intersects(p.rect):
				ok = false
				break
		for o in rooms:
			if r.grow(3).intersects(o):
				ok = false
				break
		if not ok:
			continue
		rooms.append(r)
		_clear(r)
		if w >= 8 and h >= 8 and rng.randf() < 0.5:
			_put_tile(r.get_center(), WALL)
	for h2 in hubs:
		rooms.append(Rect2i(h2 - Vector2i(3, 3), Vector2i(7, 7)))


func _carve_lanes() -> void:
	for i in G * G:
		if lane[i] != L_NONE and protect[i] == 0:
			tiles[i] = FLOOR


## Branching trails: each glade and pocket entrance (nearest first) is joined to
## the existing network by a winding path, so trails fork off the roads like
## branches off a trunk.
func _carve_trails() -> void:
	var net := PackedByteArray()
	net.resize(G * G)
	for i in G * G:
		if lane[i] != L_NONE:
			net[i] = 1
	var noise := FastNoiseLite.new()
	noise.seed = rng.randi()
	noise.frequency = 0.09
	var cost := PackedByteArray()
	cost.resize(G * G)
	for y in G:
		for x in G:
			cost[y * G + x] = 1 + int((noise.get_noise_2d(x, y) + 1.0) * 2.0)
	var targets: Array = []
	for r: Rect2i in rooms:
		targets.append(r.get_center())
	for p in pockets:
		targets.append(p.entrance)
	# Nearest-to-a-road first, so later trails can branch off earlier ones.
	targets.sort_custom(func(a, b): return _lane_dist(a) < _lane_dist(b))
	for t: Vector2i in targets:
		if net[idx(t)] == 1:
			continue
		_trail_from(t, net, cost, 0)
		_mark_area(t, net)
	# A few extra links make loops, so not every branch is a dead end.
	for k in 12:
		var t2: Vector2i = targets[rng.randi() % targets.size()]
		_trail_from(t2, net, cost, 14)


func _lane_dist(t: Vector2i) -> float:
	var bd := 1e9
	for y in range(maxi(1, t.y - 40), mini(G - 1, t.y + 40), 3):
		for x in range(maxi(1, t.x - 40), mini(G - 1, t.x + 40), 3):
			if lane[y * G + x] != L_NONE:
				bd = minf(bd, Vector2(x - t.x, y - t.y).length())
	return bd


func _mark_area(t: Vector2i, net: PackedByteArray) -> void:
	for r: Rect2i in rooms:
		if r.has_point(t):
			for y in range(r.position.y, r.end.y):
				for x in range(r.position.x, r.end.x):
					net[y * G + x] = 1
	net[idx(t)] = 1


## Dijkstra from `start` until it reaches a network tile (at least `min_d`
## tiles away), then carve that path two tiles wide.
func _trail_from(start: Vector2i, net: PackedByteArray, cost: PackedByteArray, min_d: int) -> void:
	var dist := {}
	var prev := {}
	var buckets: Array = []
	for b in 6:
		buckets.append([])
	dist[start] = 0
	(buckets[0] as Array).append(start)
	var cur := 0
	var found := Vector2i(-1, -1)
	var pending := 1
	var guard := 0
	while pending > 0 and guard < 20000:
		guard += 1
		var bucket: Array = buckets[cur % 6]
		if bucket.is_empty():
			cur += 1
			continue
		var t: Vector2i = bucket.pop_back()
		pending -= 1
		if dist[t] != cur:
			continue
		if net[idx(t)] == 1 and t != start and Vector2(t - start).length() >= min_d:
			found = t
			break
		for d in N4:
			var nb: Vector2i = t + d
			if nb.x < 2 or nb.y < 2 or nb.x > G - 3 or nb.y > G - 3:
				continue
			var ni := idx(nb)
			if protect[ni] == 1 and tiles[ni] != FLOOR:
				continue
			var nd: int = cur + cost[ni]
			if nd < dist.get(nb, 1 << 30):
				dist[nb] = nd
				prev[nb] = t
				(buckets[nd % 6] as Array).append(nb)
				pending += 1
	if found.x < 0:
		return
	var t2 := found
	while t2 != start:
		_carve_trail_tile(t2, net)
		t2 = prev[t2]
	_carve_trail_tile(start, net)


func _carve_trail_tile(t: Vector2i, net: PackedByteArray) -> void:
	for o in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1)]:
		var p: Vector2i = t + o
		if p.x < 1 or p.y < 1 or p.x > G - 2 or p.y > G - 2:
			continue
		var i := idx(p)
		if protect[i] == 1:
			continue
		tiles[i] = FLOOR
		net[i] = 1
		if lane[i] == L_NONE:
			lane[i] = L_TRAIL
	var i0 := idx(t)
	tiles[i0] = FLOOR
	net[i0] = 1


## Any floor not reachable from Camelot is sealed back into wall.
func _cull_unreachable() -> void:
	var seen := PackedByteArray()
	seen.resize(G * G)
	var q := PackedInt32Array()
	var s := idx(castle_tile + Vector2i(-3, -3))
	for k in [castle_tile + Vector2i(-3, -3), castle_tile + Vector2i(-4, -4), castle_tile + Vector2i(-5, 0)]:
		if is_open_t(k):
			s = idx(k)
			break
	q.append(s)
	seen[s] = 1
	var qi := 0
	while qi < q.size():
		var i := q[qi]
		qi += 1
		var x := i % G
		var y := i / G
		for d in N4:
			var nx: int = x + d.x
			var ny: int = y + d.y
			if nx < 0 or ny < 0 or nx >= G or ny >= G:
				continue
			var j := ny * G + nx
			if seen[j] == 0 and tiles[j] == FLOOR:
				seen[j] = 1
				q.append(j)
	for i in G * G:
		if tiles[i] == FLOOR and seen[i] == 0:
			tiles[i] = WALL


func _clear(r: Rect2i) -> void:
	for y in range(maxi(1, r.position.y), mini(G - 1, r.end.y)):
		for x in range(maxi(1, r.position.x), mini(G - 1, r.end.x)):
			tiles[y * G + x] = FLOOR


func _put_tile(t: Vector2i, v: int) -> void:
	if t.x >= 0 and t.y >= 0 and t.x < G and t.y < G:
		tiles[t.y * G + t.x] = v


func lane_at(p: Vector3) -> int:
	return lane[idx(tile_of(p))]


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

const CHUNK := 17

## Ground, walls and decorations, merged per 17x17-tile chunk so the camera
## culls everything off-screen.
func build_meshes(parent: Node3D) -> void:
	var skirt := Geo.new()
	skirt.quad(Vector3(-60, -0.05, -60), Vector3(-60, -0.05, G * T + 60), Vector3(G * T + 60, -0.05, G * T + 60), Vector3(G * T + 60, -0.05, -60), Color(0.13, 0.17, 0.11))
	var smi := MeshInstance3D.new()
	smi.mesh = skirt.mesh()
	Geo.apply(smi)
	parent.add_child(smi)
	var nc := (G + CHUNK - 1) / CHUNK
	for cy in nc:
		for cx in nc:
			var ground := Geo.new()
			var walls := Geo.new()
			var trees: Array[Transform3D] = []
			var dead_trees: Array[Transform3D] = []
			for y in range(cy * CHUNK, mini(G, (cy + 1) * CHUNK)):
				for x in range(cx * CHUNK, mini(G, (cx + 1) * CHUNK)):
					_build_tile(x, y, ground, walls, trees, dead_trees)
			for gg in [ground, walls]:
				if gg.is_empty():
					continue
				var mi := MeshInstance3D.new()
				mi.mesh = gg.mesh()
				Geo.apply(mi)
				parent.add_child(mi)
			_tree_multimesh(parent, trees, Models.tree_mesh())
			_tree_multimesh(parent, dead_trees, Models.dead_tree_mesh())


func _build_tile(x: int, y: int, ground: Geo, walls: Geo, trees: Array[Transform3D], dead_trees: Array[Transform3D]) -> void:
	var i := y * G + x
	var rg := region[i]
	var x0 := x * T
	var z0 := y * T
	var tt := tiles[i]
	if tt == FLOOR or tt == KEEP or tt == CITADEL:
		var base := region_color(rg, Color(0.36, 0.55, 0.27), Color(0.47, 0.47, 0.3), Color(0.33, 0.29, 0.27))
		var ln := lane[i]
		if ln == L_WAR:
			base = Color(0.42, 0.36, 0.28).lerp(Color(0.3, 0.24, 0.22), rg)     # trampled war-mud
		elif ln == L_ROAD:
			base = Color(0.6, 0.56, 0.46).lerp(Color(0.42, 0.38, 0.36), rg)     # cobbled road
		elif ln == L_TRAIL:
			base = base.lerp(Color(0.5, 0.42, 0.3), 0.45)                       # dirt trail
		if tt == KEEP or _near(Vector2i(x, y), castle_tile, 5):
			base = Color(0.52, 0.5, 0.42) if (x + y) % 2 == 0 else Color(0.48, 0.46, 0.39)
		elif tt == CITADEL or _near(Vector2i(x, y), citadel_tile, 4):
			base = Color(0.2, 0.17, 0.18) if (x + y) % 2 == 0 else Color(0.24, 0.19, 0.19)
		var c := base.lightened(rng.randf_range(-0.04, 0.05))
		if ln == L_ROAD and (x + y) % 2 == 0:
			c = c.darkened(0.05)
		ground.tri(Vector3(x0, 0, z0), Vector3(x0 + T, 0, z0), Vector3(x0, 0, z0 + T), c)
		ground.tri(Vector3(x0 + T, 0, z0), Vector3(x0 + T, 0, z0 + T), Vector3(x0, 0, z0 + T), c.darkened(0.04))
		if tt == FLOOR and not _near(Vector2i(x, y), castle_tile, 5) and ln != L_ROAD and ln != L_WAR:
			_decorate(ground, Vector3(x0, 0, z0), rg)
	else:
		_wall_tile(walls, x, y, rg, trees, dead_trees)


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
