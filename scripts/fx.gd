class_name FX
extends Node3D
## Projectiles, particles, pickups, spell rings, slashes, lightning and
## floating numbers. Everything pooled and drawn through Batches.

class Proj:
	var kind := ""
	var pos := Vector3.ZERO
	var vel := Vector3.ZERO
	var dmg := 0.0
	var team := 0
	var life := 3.0
	var target: Unit = null
	var radius := 0.0
	var spin := 0.0
	var dead := false
	var hero := false      # cast by Merlin or his adepts (resisted by the Citadel)

class Part:
	var pos := Vector3.ZERO
	var vel := Vector3.ZERO
	var life := 1.0
	var max_life := 1.0
	var col := Color.WHITE
	var size := 0.15
	var grav := 9.0

class Pick:
	var kind := "gem"   # gem | coin | potion
	var pos := Vector3.ZERO
	var vel := Vector3.ZERO
	var val := 1
	var t := 0.0
	var pulled := false

class Ring:
	var pos := Vector3.ZERO
	var r0 := 0.5
	var r1 := 3.0
	var t := 0.0
	var dur := 0.4
	var col := Color.WHITE
	var y := 0.1

class Slash:
	var pos := Vector3.ZERO
	var yaw := 0.0
	var r := 2.0
	var t := 0.0
	var dur := 0.22
	var col := Color.WHITE

class Zone:
	var pos := Vector3.ZERO
	var r := 2.5
	var dps := 10.0
	var t := 0.0
	var dur := 4.0
	var tick := 0.0

class Beam:
	var a := Vector3.ZERO
	var b := Vector3.ZERO
	var t := 0.0
	var dur := 0.2
	var col := Color.WHITE
	var w := 0.12

var game: Game
var projs: Array[Proj] = []
var parts: Array[Part] = []
var picks: Array[Pick] = []
var rings: Array[Ring] = []
var slashes: Array[Slash] = []
var beams: Array[Beam] = []
var numbers: Array = []   # [pos, text, color, t]
var zones: Array[Zone] = []
const HERO_CITADEL_MULT := 0.25
var part_cap := 500

var b_arrow: Batch
var b_earrow: Batch
var b_orb: Batch
var b_part: Batch
var b_gem: Batch
var b_coin: Batch
var b_potion: Batch
var b_ring: Batch
var b_slash: Batch
var b_beam: Batch
var b_axe: Batch
var time := 0.0


func setup(g: Game) -> void:
	game = g
	b_arrow = Batch.new(self, Models.arrow_mesh(), 120, Geo.mat())
	b_earrow = Batch.new(self, Models.arrow_mesh(), 160, Geo.mat())
	b_orb = Batch.new(self, Models.orb_mesh(), 160, Geo.mat_add())
	b_part = Batch.new(self, Models.cube_mesh(), 600, Geo.mat_glow())
	b_gem = Batch.new(self, Models.gem_mesh(), 500, Geo.mat_glow())
	b_coin = Batch.new(self, Models.coin_mesh(), 200, Geo.mat())
	b_potion = Batch.new(self, Models.potion_mesh(), 20, Geo.mat())
	b_ring = Batch.new(self, Models.ring_mesh(), 40, Geo.mat_add())
	b_slash = Batch.new(self, Models.slash_mesh(), 20, Geo.mat_add())
	b_beam = Batch.new(self, Models.cube_mesh(), 80, Geo.mat_add())
	b_axe = Batch.new(self, Models.rune_mesh(), 12, Geo.mat_glow())


# ------------------------------------------------------------- spawners

func shoot(kind: String, from: Vector3, to: Vector3, speed: float, dmg: float, team: int, target: Unit = null, radius := 0.0) -> Proj:
	var p := Proj.new()
	p.kind = kind
	p.pos = from
	var d := to - from
	p.vel = d.normalized() * speed
	p.dmg = dmg
	p.team = team
	p.target = target
	p.radius = radius
	p.life = 2.5 if kind != "bolt" else 3.0
	p.hero = kind == "frost"
	projs.append(p)
	match kind:
		"fireball": game.sfx.play("fire", -4.0, 0.1)
		"arrow", "earrow": game.sfx.play("arrow", -6.0, 0.08)
	return p


## Thorn Field: a patch of grasping briars that hurts and slows the Dread host.
func zone(pos: Vector3, r: float, dps: float, dur: float) -> void:
	var z := Zone.new()
	z.pos = Vector3(pos.x, 0, pos.z)
	z.r = r
	z.dps = dps
	z.dur = dur
	zones.append(z)
	burst(z.pos + Vector3(0, 0.3, 0), Color(0.4, 0.85, 0.3), 10, 3.0, 0.14, 3.0)


func _update_zones(dt: float) -> void:
	var i := zones.size() - 1
	while i >= 0:
		var z: Zone = zones[i]
		z.t += dt
		z.tick -= dt
		if z.tick <= 0.0:
			z.tick = 0.5
			for u: Unit in game.horde.enemies_near(z.pos, z.r):
				game.horde.hurt(u, z.dps * 0.5, Vector3.ZERO, 0.0, Color(0.55, 1.0, 0.45))
				u.slow_t = maxf(u.slow_t, 1.0)
			if randf() < 0.8:
				sparkle(z.pos + Vector3(randf_range(-z.r, z.r) * 0.7, 0, randf_range(-z.r, z.r) * 0.7), Color(0.45, 0.9, 0.3), 2, 0.1)
		if z.t >= z.dur:
			zones.remove_at(i)
		i -= 1


func burst(pos: Vector3, col: Color, count: int, spd: float, size: float, up := 3.0) -> void:
	if game.low_quality:
		count = maxi(1, count / 2)
	for k in count:
		if parts.size() >= part_cap:
			parts.pop_front()
		var p := Part.new()
		p.pos = pos
		var a := randf() * TAU
		var s := randf_range(0.3, 1.0) * spd
		p.vel = Vector3(cos(a) * s, randf_range(0.5, 1.0) * up, sin(a) * s)
		p.life = randf_range(0.35, 0.7)
		p.max_life = p.life
		p.col = col.lightened(randf_range(-0.1, 0.15))
		p.size = size * randf_range(0.6, 1.2)
		parts.append(p)


func sparkle(pos: Vector3, col: Color, count: int, size := 0.1) -> void:
	for k in count:
		if parts.size() >= part_cap:
			return
		var p := Part.new()
		p.pos = pos + Vector3(randf_range(-0.4, 0.4), randf_range(0, 0.6), randf_range(-0.4, 0.4))
		p.vel = Vector3(0, randf_range(1.0, 2.5), 0)
		p.grav = 0.0
		p.life = randf_range(0.4, 0.8)
		p.max_life = p.life
		p.col = col
		p.size = size
		parts.append(p)


func ring(pos: Vector3, r0: float, r1: float, col: Color, dur := 0.4, y := 0.12) -> void:
	var r := Ring.new()
	r.pos = pos
	r.r0 = r0
	r.r1 = r1
	r.col = col
	r.dur = dur
	r.y = y
	rings.append(r)


func slash(pos: Vector3, yaw: float, radius: float, col: Color) -> void:
	var s := Slash.new()
	s.pos = pos
	s.yaw = yaw
	s.r = radius
	s.col = col
	slashes.append(s)


func lightning(a: Vector3, b: Vector3, col: Color) -> void:
	# Three jagged segments.
	var pts := [a]
	for k in range(1, 3):
		var t := k / 3.0
		pts.append(a.lerp(b, t) + Vector3(randf_range(-0.5, 0.5), randf_range(-0.2, 0.3), randf_range(-0.5, 0.5)))
	pts.append(b)
	for k in 3:
		var bm := Beam.new()
		bm.a = pts[k]
		bm.b = pts[k + 1]
		bm.col = col
		beams.append(bm)


func drop(kind: String, pos: Vector3, val := 1) -> void:
	if picks.size() >= 480:
		# Merge into an existing gem rather than dropping more.
		if kind == "gem":
			for q in picks:
				if q.kind == "gem":
					q.val += val
					return
		return
	var p := Pick.new()
	p.kind = kind
	p.pos = pos + Vector3(randf_range(-0.3, 0.3), 0.3, randf_range(-0.3, 0.3))
	var a := randf() * TAU
	p.vel = Vector3(cos(a) * 1.5, 4.0, sin(a) * 1.5)
	p.val = val
	p.t = randf() * 10.0
	picks.append(p)


func number(pos: Vector3, text: String, col: Color) -> void:
	if numbers.size() > 45:
		numbers.pop_front()
	numbers.append([pos + Vector3(randf_range(-0.3, 0.3), 0, randf_range(-0.3, 0.3)), text, col, 0.0])


# ------------------------------------------------------------- update

func update(dt: float) -> void:
	time += dt
	_update_projs(dt)
	_update_zones(dt)
	_update_parts(dt)
	_update_picks(dt)
	var i := rings.size() - 1
	while i >= 0:
		rings[i].t += dt
		if rings[i].t >= rings[i].dur:
			rings.remove_at(i)
		i -= 1
	i = slashes.size() - 1
	while i >= 0:
		slashes[i].t += dt
		if slashes[i].t >= slashes[i].dur:
			slashes.remove_at(i)
		i -= 1
	i = beams.size() - 1
	while i >= 0:
		beams[i].t += dt
		if beams[i].t >= beams[i].dur:
			beams.remove_at(i)
		i -= 1
	i = numbers.size() - 1
	while i >= 0:
		numbers[i][3] += dt
		if numbers[i][3] > 0.8:
			numbers.remove_at(i)
		i -= 1


func _update_projs(dt: float) -> void:
	var maze := game.maze
	var horde := game.horde
	for p in projs:
		p.life -= dt
		if p.life <= 0.0:
			p.dead = true
			if p.kind == "fireball":
				_explode(p)
			continue
		if p.kind == "bolt" or p.kind == "frost":
			if p.target != null and p.target.alive:
				var want := (p.target.pos + Vector3(0, 0.7, 0) - p.pos)
				want.y = 0
				p.vel = p.vel.lerp(want.normalized() * p.vel.length(), minf(1.0, dt * 6.0))
			elif p.target != null:
				p.target = horde.nearest_enemy(p.pos, 8.0)
		p.spin += dt * 12.0
		p.pos += p.vel * dt
		if p.pos.y < 0.05:
			burst(p.pos, Color(0.6, 0.55, 0.5) if p.kind != "dark" else Color(0.9, 0.2, 0.2), 3, 2.0, 0.08, 1.0)
			p.dead = true
			continue
		if p.kind == "arrow" or p.kind == "earrow":
			p.vel.y -= dt * 2.0
		# Walls stop everything except homing bolts.
		if p.kind != "bolt" and p.kind != "frost" and p.pos.y < Maze.WALL_H + 0.3 and not maze.is_open_p(p.pos):
			# Let shots strike the fortress they are aimed at.
			if p.team == 1 and (p.pos - maze.castle_pos).length() < 7.5:
				game.castle.take_damage(p.dmg)
			elif p.team == 0 and (p.pos - maze.citadel_pos).length() < 6.5:
				game.damage_citadel(p.dmg * (HERO_CITADEL_MULT if p.hero else 1.0))
			if p.kind == "fireball":
				_explode(p)
			else:
				burst(p.pos, Color(0.8, 0.75, 0.6), 2, 2.0, 0.08, 1.0)
			p.dead = true
			continue
		if p.team == 0 and p.dmg <= 0.0:
			# Cosmetic volley (soldiers shooting at the citadel).
			if (p.pos - game.maze.citadel_pos).length() < 5.0:
				p.dead = true
			continue
		if p.team == 0:
			var hits := horde.enemies_near(p.pos, 0.35)
			if not hits.is_empty():
				var u: Unit = hits[0]
				if p.kind == "fireball":
					_explode(p)
				elif p.kind == "frost":
					horde.hurt(u, p.dmg, p.vel.normalized(), 1.0, Color(0.6, 0.9, 1.0))
					u.slow_t = maxf(u.slow_t, 2.5)
					burst(p.pos, Color(0.7, 0.95, 1.0), 5, 2.5, 0.1, 1.5)
				else:
					var col := Color(0.75, 0.85, 1.0) if p.kind == "bolt" else Color(1, 0.95, 0.7)
					horde.hurt(u, p.dmg, p.vel.normalized(), 2.5, col)
					burst(p.pos, Color(0.6, 0.6, 1.0) if p.kind == "bolt" else Color(0.9, 0.85, 0.7), 3, 2.5, 0.08, 1.5)
				p.dead = true
				continue
			if (p.pos - game.maze.citadel_pos).length() < 5.0:
				if p.kind == "fireball":
					_explode(p)
				game.damage_citadel(p.dmg * (HERO_CITADEL_MULT if p.hero else 1.0))
				p.dead = true
		else:
			var hero := game.hero
			if hero.alive and Vector2(p.pos.x - hero.position.x, p.pos.z - hero.position.z).length() < 0.6:
				hero.take_damage(p.dmg, p.pos - p.vel)
				burst(p.pos, Color(1, 0.3, 0.2), 4, 2.5, 0.08)
				p.dead = true
				continue
			var fr := horde.friends_near(p.pos, 0.2)
			if not fr.is_empty():
				horde.hurt_friend(fr[0], p.dmg)
				p.dead = true
	var j := projs.size() - 1
	while j >= 0:
		if projs[j].dead:
			projs.remove_at(j)
		j -= 1


func _explode(p: Proj) -> void:
	var r := p.radius
	ring(p.pos * Vector3(1, 0, 1), 0.3, r, Color(1.0, 0.55, 0.15), 0.35)
	burst(p.pos, Color(1.0, 0.5, 0.1), 14, 6.0, 0.18, 4.0)
	burst(p.pos, Color(1.0, 0.85, 0.3), 6, 3.0, 0.12, 5.0)
	for u: Unit in game.horde.enemies_near(p.pos, r):
		var d := (u.pos - p.pos)
		d.y = 0
		game.horde.hurt(u, p.dmg, d.normalized(), 4.0, Color(1, 0.6, 0.25))
	if (p.pos - game.maze.citadel_pos).length() < 5.0 + r:
		game.damage_citadel(p.dmg * 0.5 * (HERO_CITADEL_MULT if p.hero else 1.0))
	if (p.pos - game.hero.position).length() < 14.0:
		game.shake = maxf(game.shake, 0.15)
		game.sfx.play("explode", -4.0, 0.1)


func _update_parts(dt: float) -> void:
	var i := parts.size() - 1
	while i >= 0:
		var p: Part = parts[i]
		p.life -= dt
		if p.life <= 0.0:
			parts.remove_at(i)
		else:
			p.vel.y -= p.grav * dt
			p.pos += p.vel * dt
			if p.pos.y < 0.05:
				p.pos.y = 0.05
				p.vel *= 0.5
		i -= 1


func _update_picks(dt: float) -> void:
	var hero := game.hero
	var hp := hero.position + Vector3(0, 0.5, 0)
	var pr := hero.pickup_r
	var i := picks.size() - 1
	while i >= 0:
		var p: Pick = picks[i]
		p.t += dt
		var to := hp - p.pos
		var d := to.length()
		var can := hero.alive
		if p.kind == "potion" and hero.potions >= hero.potion_max:
			can = false
		if can and (d < pr or p.pulled):
			p.pulled = true
			p.vel = p.vel.lerp(to.normalized() * (10.0 + p.t), minf(1.0, dt * 8.0))
			if d < 0.55:
				hero.collect(p.kind, p.val)
				picks.remove_at(i)
				i -= 1
				continue
		else:
			p.pulled = false
			p.vel.y -= 14.0 * dt
			p.vel.x *= 1.0 - minf(1.0, dt * 3.0)
			p.vel.z *= 1.0 - minf(1.0, dt * 3.0)
		p.pos += p.vel * dt
		if not p.pulled and p.pos.y < 0.25:
			p.pos.y = 0.25
			p.vel.y = absf(p.vel.y) * 0.3
		p.pos = game.maze.collide(p.pos, 0.15) if not p.pulled else p.pos
		i -= 1


# ------------------------------------------------------------- render

func render() -> void:
	for b in [b_arrow, b_earrow, b_orb, b_part, b_gem, b_coin, b_potion, b_ring, b_slash, b_beam, b_axe]:
		b.begin()
	for p in projs:
		var yaw := atan2(p.vel.x, p.vel.z)
		match p.kind:
			"arrow":
				var pitch := -atan2(p.vel.y, Vector2(p.vel.x, p.vel.z).length())
				b_arrow.add(Basis(Vector3.UP, yaw) * Basis(Vector3(1, 0, 0), pitch), p.pos, Color.WHITE)
			"earrow":
				var pitch2 := -atan2(p.vel.y, Vector2(p.vel.x, p.vel.z).length())
				b_earrow.add(Basis(Vector3.UP, yaw) * Basis(Vector3(1, 0, 0), pitch2), p.pos, Color(0.45, 0.25, 0.3))
			"bolt":
				var s := 0.32 + sin(p.spin) * 0.05
				b_orb.add(Basis(Vector3.UP, p.spin).scaled(Vector3(s, s, s)), p.pos, Color(0.45, 0.55, 1.0))
				b_orb.add(Basis.IDENTITY.scaled(Vector3(0.15, 0.15, 0.15)), p.pos - p.vel.normalized() * 0.3, Color(0.25, 0.3, 0.8))
			"fireball":
				var s2 := 0.55 + sin(p.spin) * 0.06
				b_orb.add(Basis(Vector3.UP, p.spin).scaled(Vector3(s2, s2, s2)), p.pos, Color(1.0, 0.55, 0.15))
				b_orb.add(Basis.IDENTITY.scaled(Vector3(0.3, 0.3, 0.3)), p.pos, Color(1.0, 0.9, 0.5))
				if randf() < 0.5:
					sparkle(p.pos, Color(1.0, 0.45, 0.1), 1, 0.12)
			"frost":
				var sf := 0.28 + sin(p.spin) * 0.04
				b_orb.add(Basis(Vector3.UP, p.spin).scaled(Vector3(sf, sf, sf)), p.pos, Color(0.55, 0.85, 1.0))
				b_orb.add(Basis.IDENTITY.scaled(Vector3(0.14, 0.14, 0.14)), p.pos - p.vel.normalized() * 0.35, Color(0.3, 0.55, 0.8))
			"dark":
				var s3 := 0.5 + sin(p.spin) * 0.08
				b_orb.add(Basis(Vector3.UP, p.spin).scaled(Vector3(s3, s3, s3)), p.pos, Color(0.9, 0.12, 0.2))
	for p in parts:
		var k := p.life / p.max_life
		var s := p.size * (0.4 + 0.6 * k)
		b_part.add(Basis.IDENTITY.scaled(Vector3(s, s, s)), p.pos, p.col)
	for p in picks:
		var bob := sin(p.t * 3.0) * 0.08
		match p.kind:
			"gem":
				var c := Color(0.35, 1.0, 0.5)
				var sc := 1.0
				if p.val >= 10:
					c = Color(0.85, 0.4, 1.0); sc = 1.5
				elif p.val >= 3:
					c = Color(0.35, 0.7, 1.0); sc = 1.25
				b_gem.add(Basis(Vector3.UP, p.t * 2.0).scaled(Vector3(sc, sc, sc)), p.pos + Vector3(0, bob, 0), c)
			"coin":
				var cs := 1.0 + minf(1.2, p.val / 12.0)
				b_coin.add(Basis(Vector3.UP, p.t * 4.0).scaled(Vector3(cs, cs, cs)), p.pos + Vector3(0, bob, 0), Color.WHITE)
			"potion":
				b_potion.add(Basis(Vector3.UP, p.t), p.pos + Vector3(0, bob - 0.15, 0), Color.WHITE)
	for r in rings:
		var k2 := r.t / r.dur
		var rad := lerpf(r.r0, r.r1, 1.0 - (1.0 - k2) * (1.0 - k2))
		var f := 1.0 - k2
		b_ring.add(Basis.IDENTITY.scaled(Vector3(rad, 1, rad)), r.pos + Vector3(0, r.y, 0), Color(r.col.r * f, r.col.g * f, r.col.b * f))
	for z in zones:
		var f4 := clampf((z.dur - z.t) / 0.6, 0.0, 1.0) * (0.75 + 0.25 * sin(z.t * 8.0))
		b_ring.add(Basis.IDENTITY.scaled(Vector3(z.r, 1, z.r)), z.pos + Vector3(0, 0.1, 0), Color(0.3 * f4, 0.75 * f4, 0.25 * f4))
		b_ring.add(Basis.IDENTITY.scaled(Vector3(z.r * 0.6, 1, z.r * 0.6)), z.pos + Vector3(0, 0.12, 0), Color(0.2 * f4, 0.5 * f4, 0.15 * f4))
	for s in slashes:
		var k3 := s.t / s.dur
		var f2 := 1.0 - k3
		var sw := s.yaw + (k3 - 0.5) * 0.9
		b_slash.add(Basis(Vector3.UP, sw).scaled(Vector3(s.r, 1, s.r)), s.pos + Vector3(0, 0.6, 0), Color(s.col.r * f2, s.col.g * f2, s.col.b * f2))
	for bm in beams:
		var f3 := 1.0 - bm.t / bm.dur
		var d := bm.b - bm.a
		var l := d.length()
		if l < 0.01:
			continue
		var z := d / l
		var x := z.cross(Vector3.UP)
		if x.length_squared() < 1e-4:
			x = Vector3.RIGHT
		x = x.normalized()
		var y := x.cross(z).normalized()
		var bb := Basis(x * bm.w, y * bm.w, z * l)
		b_beam.add(bb, (bm.a + bm.b) * 0.5, Color(bm.col.r * f3, bm.col.g * f3, bm.col.b * f3))
	# Merlin's orbiting spell orbs.
	var hero := game.hero
	if hero.alive:
		for a in hero.orb_positions():
			b_orb.add(Basis(Vector3.UP, time * 5.0).scaled(Vector3(0.38, 0.38, 0.38)), a, Color(0.65, 0.45, 1.0))
			b_axe.add(Basis(Vector3.UP, time * 3.0), a - Vector3(0, 0.6, 0), Color(0.4, 0.3, 0.8))
	for b in [b_arrow, b_earrow, b_orb, b_part, b_gem, b_coin, b_potion, b_ring, b_slash, b_beam, b_axe]:
		b.finish()
