class_name ResNodes
extends Node3D
## Harvestable resources scattered through the maze: golden oaks (timber),
## gold-veined boulders (gold) and mana crystals (crystal). They regrow.

class RNode:
	var kind := "wood"     # wood | gold | crystal
	var pos := Vector3.ZERO
	var amount := 30.0
	var max_amount := 30.0
	var regrow := 0.0
	var yaw := 0.0
	var pulse := 0.0

const REGROW_TIME := 55.0
const REACH := 2.3

var game: Game
var list: Array[RNode] = []
var b_wood: Batch
var b_stump: Batch
var b_gold: Batch
var b_crystal: Batch


func setup(g: Game) -> void:
	game = g
	b_wood = Batch.new(self, Models.lumber_mesh(), 80, Geo.mat())
	b_stump = Batch.new(self, Models.stump_mesh(), 80, Geo.mat())
	b_gold = Batch.new(self, Models.ore_mesh(), 80, Geo.mat())
	b_crystal = Batch.new(self, Models.crystal_mesh(), 80, Geo.mat())
	_place()


func _place() -> void:
	var maze := game.maze
	var rng := maze.rng
	var used := {}
	# A starter patch just outside the castle courtyard.
	var starters := [["wood", Vector2i(Maze.G - 13, Maze.G - 6)], ["gold", Vector2i(Maze.G - 6, Maze.G - 13)],
		["wood", Vector2i(Maze.G - 13, Maze.G - 10)], ["gold", Vector2i(Maze.G - 10, Maze.G - 13)]]
	for s in starters:
		var t := _nearest_open(s[1])
		if t.x >= 0 and not used.has(t):
			used[t] = true
			_add(s[0], t, 0.0)
	for room: Rect2i in maze.rooms:
		var n := rng.randi_range(2, 3) if room.size.x * room.size.y > 25 else rng.randi_range(1, 2)
		for k in n:
			var t := maze.random_floor_in(room.grow(-1) if room.size.x > 3 and room.size.y > 3 else room)
			if t.x < 0 or used.has(t):
				continue
			used[t] = true
			var rg := maze.region[Maze.idx(t)]
			_add(_pick_kind(rng, rg), t, rg)
	# Some along corridors, to reward exploring.
	var extra := 0
	var tries := 0
	while extra < 14 and tries < 400:
		tries += 1
		var t := Vector2i(rng.randi_range(2, Maze.G - 3), rng.randi_range(2, Maze.G - 3))
		if not maze.is_open_t(t) or used.has(t):
			continue
		if absi(t.x - maze.castle_tile.x) < 9 and absi(t.y - maze.castle_tile.y) < 9:
			continue
		if absi(t.x - maze.citadel_tile.x) < 8 and absi(t.y - maze.citadel_tile.y) < 8:
			continue
		# Only in dead-end-ish spots so they don't clog corridors.
		var open := 0
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if maze.is_open_t(t + d):
				open += 1
		if open > 2:
			continue
		used[t] = true
		var rg2 := maze.region[Maze.idx(t)]
		_add(_pick_kind(rng, rg2), t, rg2)
		extra += 1


func _nearest_open(t: Vector2i) -> Vector2i:
	for r in 4:
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if game.maze.is_open_t(t + Vector2i(dx, dy)):
					return t + Vector2i(dx, dy)
	return Vector2i(-1, -1)


func _pick_kind(rng: RandomNumberGenerator, rg: float) -> String:
	var roll := rng.randf()
	if rg < 0.4:
		return "wood" if roll < 0.55 else ("gold" if roll < 0.9 else "crystal")
	if rg < 0.7:
		return "wood" if roll < 0.35 else ("gold" if roll < 0.75 else "crystal")
	return "wood" if roll < 0.15 else ("gold" if roll < 0.55 else "crystal")


func _add(kind: String, t: Vector2i, rg: float) -> void:
	var n := RNode.new()
	n.kind = kind
	n.pos = Maze.tile_center(t) + Vector3(randf_range(-0.3, 0.3), 0, randf_range(-0.3, 0.3))
	var base: float = {"wood": 40.0, "gold": 35.0, "crystal": 24.0}[kind]
	n.max_amount = roundf(base * (1.0 + rg * 0.8))
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
				game.fx.sparkle(n.pos, Color(0.6, 1.0, 0.6), 8, 0.12)


## The resource node the hero is close enough to harvest (or null).
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


func take(n: RNode, amount: float) -> float:
	var got := minf(amount, n.amount)
	n.amount -= got
	n.pulse = 1.0
	if n.amount <= 0.0:
		n.amount = 0.0
		n.regrow = REGROW_TIME
		var col: Color = {"wood": Color(0.7, 0.6, 0.25), "gold": Color(1, 0.8, 0.3), "crystal": Color(0.7, 0.5, 1)}[n.kind]
		game.fx.burst(n.pos + Vector3(0, 0.6, 0), col, 12, 4.0, 0.18)
	return got


func render() -> void:
	for b in [b_wood, b_stump, b_gold, b_crystal]:
		b.begin()
	for n in list:
		var full := n.amount / n.max_amount
		var wobble := sin(n.pulse * 18.0) * 0.06 * n.pulse
		var b := Basis(Vector3.UP, n.yaw) * Basis(Vector3(0, 0, 1), wobble)
		if n.amount <= 0.0:
			if n.kind == "wood":
				b_stump.add(Basis(Vector3.UP, n.yaw), n.pos, Color.WHITE)
			continue
		var s := 0.6 + 0.4 * full
		b = b.scaled(Vector3(s, s, s))
		match n.kind:
			"wood": b_wood.add(b, n.pos, Color.WHITE)
			"gold": b_gold.add(b, n.pos, Color.WHITE)
			"crystal": b_crystal.add(b, n.pos, Color.WHITE)
	for b in [b_wood, b_stump, b_gold, b_crystal]:
		b.finish()
