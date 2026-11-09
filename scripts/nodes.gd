class_name ResNodes
extends Node3D
## Gold-veined boulders scattered through the maze (they regrow), plus the
## ancient spellbooks waiting on pedestals in hidden glades.

class RNode:
	var kind := "gold"
	var pos := Vector3.ZERO
	var amount := 30.0
	var max_amount := 30.0
	var regrow := 0.0
	var yaw := 0.0
	var pulse := 0.0
	var workers := 0
	var next: PackedInt32Array = PackedInt32Array()   # flow field toward this node (cached)

class Book:
	var pos := Vector3.ZERO
	var taken := false
	var t := 0.0

const REGROW_TIME := 50.0
const REACH := 2.3

var game: Game
var list: Array[RNode] = []
var books: Array[Book] = []
var b_gold: Batch
var b_rubble: Batch
var b_book: Batch
var b_glow: Batch


func setup(g: Game) -> void:
	game = g
	b_gold = Batch.new(self, Models.ore_mesh(), 140, Geo.mat())
	b_rubble = Batch.new(self, Models.stump_mesh(), 140, Geo.mat())
	b_book = Batch.new(self, Models.spellbook_mesh(), 16, Geo.mat())
	b_glow = Batch.new(self, Models.ring_mesh(), 16, Geo.mat_add())
	_place()


func _place() -> void:
	var maze := game.maze
	var rng := maze.rng
	var used := {}
	# A starter patch just outside the castle courtyard.
	var starters := [Vector2i(Maze.G - 13, Maze.G - 6), Vector2i(Maze.G - 6, Maze.G - 13),
		Vector2i(Maze.G - 13, Maze.G - 10), Vector2i(Maze.G - 10, Maze.G - 13)]
	for s in starters:
		var t := _nearest_open(s)
		if t.x >= 0 and not used.has(t):
			used[t] = true
			_add(t, 0.0)
	for room: Rect2i in maze.rooms:
		var n := rng.randi_range(1, 3)
		for k in n:
			var t := maze.random_floor_in(room.grow(-1) if room.size.x > 3 and room.size.y > 3 else room)
			if t.x < 0 or used.has(t):
				continue
			used[t] = true
			_add(t, maze.region[Maze.idx(t)])
	# Maze pocket rewards: spellbooks and rich gold seams at the heart of each labyrinth.
	for pk in maze.pockets:
		var rt: Vector2i = pk.reward
		used[rt] = true
		if pk.kind == "book":
			var bk := Book.new()
			bk.pos = Maze.tile_center(rt)
			books.append(bk)
		elif pk.kind == "gold":
			_add(rt, maze.region[Maze.idx(rt)] + 0.8)
			for d in [Vector2i(2, 0), Vector2i(-2, 0), Vector2i(0, 2), Vector2i(0, -2)]:
				var t2: Vector2i = rt + d
				if maze.is_open_t(t2) and (pk.rect as Rect2i).has_point(t2) and not used.has(t2):
					used[t2] = true
					_add(t2, maze.region[Maze.idx(t2)] + 0.8)
	# Dead-end trail tips get a vein too, rewarding every branch.
	var extra := 0
	var tries := 0
	while extra < 14 and tries < 2000:
		tries += 1
		var t := Vector2i(rng.randi_range(2, Maze.G - 3), rng.randi_range(2, Maze.G - 3))
		if not maze.is_open_t(t) or used.has(t) or maze.lane[Maze.idx(t)] == Maze.L_WAR or maze.protect[Maze.idx(t)] == 1:
			continue
		if absi(t.x - maze.castle_tile.x) < 9 and absi(t.y - maze.castle_tile.y) < 9:
			continue
		var open := 0
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if maze.is_open_t(t + d):
				open += 1
		if open > 2:
			continue
		used[t] = true
		_add(t, maze.region[Maze.idx(t)])
		extra += 1


func _nearest_open(t: Vector2i) -> Vector2i:
	for r in 4:
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if game.maze.is_open_t(t + Vector2i(dx, dy)):
					return t + Vector2i(dx, dy)
	return Vector2i(-1, -1)


func _add(t: Vector2i, rg: float) -> void:
	var n := RNode.new()
	n.pos = Maze.tile_center(t) + Vector3(randf_range(-0.3, 0.3), 0, randf_range(-0.3, 0.3))
	n.max_amount = roundf(40.0 * (1.0 + rg * 1.2))
	n.amount = n.max_amount
	n.yaw = randf() * TAU
	list.append(n)


func update(dt: float) -> void:
	for n in list:
		n.pulse = maxf(0.0, n.pulse - dt * 3.0)
		if n.amount <= 0.0:
			n.regrow -= dt
			if n.regrow <= 0.0:
				n.amount = n.max_amount
				game.fx.sparkle(n.pos, Color(1.0, 0.9, 0.4), 8, 0.12)
	var hero := game.hero
	for b in books:
		b.t += dt
		if not b.taken and hero.alive and Vector2(b.pos.x - hero.position.x, b.pos.z - hero.position.z).length() < 1.6:
			b.taken = true
			game.fx.ring(b.pos, 0.3, 4.0, Color(0.6, 0.8, 1.0), 0.7, 0.2)
			game.fx.sparkle(b.pos, Color(0.7, 0.85, 1.0), 20, 0.14)
			game.on_spellbook()


## The gold vein the hero is close enough to mine (or null).
func nearest_harvestable(p: Vector3) -> RNode:
	var best: RNode = null
	var bd := REACH * REACH
	for n in list:
		if n.amount <= 0.0:
			continue
		var d := Vector2(n.pos.x - p.x, n.pos.z - p.z).length_squared()
		if d < bd:
			bd = d
			best = n
	return best


## Best vein for a miner: closest to Camelot by path, not overcrowded.
func pick_for_worker() -> RNode:
	var best: RNode = null
	var bd := 1 << 30
	var maze := game.maze
	for n in list:
		if n.amount <= 5.0 or n.workers >= 2:
			continue
		var d := maze.to_castle_dist[Maze.idx(Maze.tile_of(n.pos))] + n.workers * 120
		if d < bd:
			bd = d
			best = n
	return best


func path_to(n: RNode) -> PackedInt32Array:
	if n.next.is_empty():
		n.next = game.maze.field_from(PackedInt32Array([Maze.idx(Maze.tile_of(n.pos))]), 1 << 30)[1]
	return n.next


func take(n: RNode, amount: float) -> float:
	var got := minf(amount, n.amount)
	n.amount -= got
	n.pulse = 1.0
	if n.amount <= 0.0:
		n.amount = 0.0
		n.regrow = REGROW_TIME
		game.fx.burst(n.pos + Vector3(0, 0.6, 0), Color(1, 0.8, 0.3), 12, 4.0, 0.18)
	return got


func render() -> void:
	for b in [b_gold, b_rubble, b_book, b_glow]:
		b.begin()
	for n in list:
		if n.amount <= 0.0:
			b_rubble.add(Basis(Vector3.UP, n.yaw).scaled(Vector3(1.4, 0.5, 1.4)), n.pos, Color(0.55, 0.52, 0.5))
			continue
		var full := n.amount / n.max_amount
		var wobble := sin(n.pulse * 18.0) * 0.06 * n.pulse
		var s := 0.6 + 0.4 * full
		b_gold.add((Basis(Vector3.UP, n.yaw) * Basis(Vector3(0, 0, 1), wobble)).scaled(Vector3(s, s, s)), n.pos, Color.WHITE)
	for bk in books:
		if bk.taken:
			continue
		b_book.add(Basis(Vector3.UP, PI * 0.25), bk.pos, Color.WHITE)
		var p := 0.5 + 0.5 * sin(bk.t * 3.0)
		b_glow.add(Basis.IDENTITY.scaled(Vector3(1.1 + p * 0.3, 1, 1.1 + p * 0.3)), bk.pos + Vector3(0, 0.05, 0), Color(0.3 + 0.3 * p, 0.45 + 0.3 * p, 1.0))
		if randf() < 0.08:
			game.fx.sparkle(bk.pos + Vector3(0, 0.8, 0), Color(0.6, 0.8, 1.0), 1, 0.08)
	for b in [b_gold, b_rubble, b_book, b_glow]:
		b.finish()
