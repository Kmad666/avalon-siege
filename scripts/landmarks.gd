class_name Landmarks
extends Node3D
## Dread Wards (three obelisks that shield the Citadel) and Ley Shrines
## (capturable waypoints that give gold and healing).

class Shrine:
	var pos := Vector3.ZERO
	var owner := 1            # 1 = Dread, 0 = Camelot
	var cap := 0.0            # capture progress (seconds)
	var hp := 600.0
	var max_hp := 600.0
	var name := ""
	var node: Node3D
	var red: MeshInstance3D
	var blue: MeshInstance3D
	var hit_t := 0.0

const SHRINE_NAMES := ["Shrine of Brocéliande", "Shrine of Tintagel", "Shrine of Glastonbury", "Shrine of Lyonesse", "Shrine of Carbonek"]
const CAPTURE_TIME := 4.0
const WARD_HP := 3200.0

var game: Game
var shrines: Array[Shrine] = []
var wards: Array[Unit] = []
var ward_nodes: Array[Node3D] = []
var ward_beams: Array[MeshInstance3D] = []
var ward_fire: Array[float] = []
var shield: MeshInstance3D
var shield_up := true
var _income_acc := 0.0


func setup(g: Game) -> void:
	game = g
	_place_wards()
	_place_shrines()
	shield = MeshInstance3D.new()
	shield.mesh = Models.orb_mesh()
	shield.material_override = Geo.mat_add().duplicate()
	shield.position = game.maze.citadel_pos + Vector3(0, 3.0, 0)
	shield.scale = Vector3(10, 10, 10)
	add_child(shield)


func _rooms_by_region() -> Array:
	var maze := game.maze
	var out := []
	var cid := 0
	for room: Rect2i in maze.rooms:
		var c := room.get_center()
		if not (absi(c.x - maze.castle_tile.x) < 11 and absi(c.y - maze.castle_tile.y) < 11):
			out.append([maze.region[Maze.idx(c)], room, cid])
			cid += 1
	return out


func _place_wards() -> void:
	var maze := game.maze
	var cands := _rooms_by_region()
	cands.sort_custom(func(a, b): return a[0] > b[0])
	var picked: Array[Vector3] = []
	for c in cands:
		if picked.size() >= 3:
			break
		var t := maze.random_floor_in((c[1] as Rect2i).grow(-1) if c[1].size.x > 3 else c[1])
		if t.x < 0:
			continue
		var p := Maze.tile_center(t)
		if (p - maze.citadel_pos).length() < 22.0 or c[0] < 0.45:
			continue
		var ok := true
		for q in picked:
			if (q - p).length() < 34.0:
				ok = false
		if ok:
			picked.append(p)
	# Fallback: open tiles in the far half of the realm.
	var tries := 0
	while picked.size() < 3 and tries < 3000:
		tries += 1
		var t2 := Vector2i(randi_range(3, Maze.G - 4), randi_range(3, Maze.G - 4))
		if not maze.is_open_t(t2) or maze.region[Maze.idx(t2)] < 0.5:
			continue
		var p2 := Maze.tile_center(t2)
		var ok2 := (p2 - maze.citadel_pos).length() > 20.0
		for q in picked:
			if (q - p2).length() < 28.0:
				ok2 = false
		if ok2:
			picked.append(p2)
	for i in picked.size():
		var p: Vector3 = picked[i]
		var u := game.horde.make("goblin", p, 1, 1.0)
		u.kind = "ward"
		u.structure = true
		u.mode = "ward"
		u.r = 1.6
		u.max_hp = WARD_HP * game.diff
		u.hp = u.max_hp
		u.speed = 0.0
		u.xp = 60
		u.gold_chance = 1.0
		u.camp_id = -3
		u.title = "Dread Ward"
		game.horde.enemies.append(u)
		wards.append(u)
		ward_fire.append(1.0)
		var n := Node3D.new()
		n.position = p
		add_child(n)
		var m := MeshInstance3D.new()
		m.mesh = Models.ward_mesh()
		Geo.apply(m)
		n.add_child(m)
		var gem := MeshInstance3D.new()
		gem.mesh = Models.citadel_gem()
		Geo.apply(gem, true)
		gem.scale = Vector3(0.55, 0.55, 0.55)
		gem.position = Vector3(0, 7.2, 0)
		n.add_child(gem)
		ward_nodes.append(n)
		# A dark beam from the ward to the citadel's crown.
		var a := p + Vector3(0, 7.5, 0)
		var b := game.maze.citadel_pos + Vector3(0, 10.0, 0)
		var beam := MeshInstance3D.new()
		beam.mesh = Models.cube_mesh()
		var bm: StandardMaterial3D = Geo.mat_add().duplicate()
		bm.albedo_color = Color(0.55, 0.06, 0.1)
		beam.material_override = bm
		var d := b - a
		var z := d.normalized()
		var x := z.cross(Vector3.UP).normalized()
		var y := x.cross(z)
		beam.transform = Transform3D(Basis(x * 0.18, y * 0.18, z * d.length()), (a + b) * 0.5)
		add_child(beam)
		ward_beams.append(beam)
		# Its guardians.
		var cid := 100 + i
		game.horde.camp_fields[cid] = game.maze.field_from(PackedInt32Array([Maze.idx(Maze.tile_of(p))]), 500)[1]
		var kinds := ["orc", "shaman", "skeleton", "necro", "ogre", "orc", "skeleton"]
		for k in kinds.size():
			var gp := game.maze.collide(p + Vector3(randf_range(-4, 4), 0, randf_range(-4, 4)), 0.6)
			var gu := game.horde.spawn(kinds[k], gp, "camp", 2.0, k == 0)
			if gu != null:
				gu.camp_id = cid
				gu.home = p


func _place_shrines() -> void:
	var maze := game.maze
	var cands := _rooms_by_region()
	var targets := [0.18, 0.32, 0.46, 0.6, 0.74]
	var used: Array[Vector3] = []
	for i in targets.size():
		var best = null
		var bd := INF
		for c in cands:
			var room: Rect2i = c[1]
			var p := Maze.tile_center(room.get_center())
			if not maze.is_open_t(room.get_center()):
				continue
			var far := true
			for q in used:
				if (q - p).length() < 26.0:
					far = false
			for w in wards:
				if (w.pos - p).length() < 18.0:
					far = false
			if not far:
				continue
			var d := absf(c[0] - targets[i])
			if d < bd:
				bd = d
				best = p
		if best == null:
			continue
		used.append(best)
		var s := Shrine.new()
		s.pos = best
		s.name = SHRINE_NAMES[i]
		s.node = Node3D.new()
		s.node.position = best
		add_child(s.node)
		var base := MeshInstance3D.new()
		base.mesh = Models.shrine_base_mesh()
		Geo.apply(base)
		s.node.add_child(base)
		s.red = MeshInstance3D.new()
		s.red.mesh = Models.shrine_crystal_mesh()
		s.red.material_override = _tinted(Color(1.0, 0.3, 0.2))
		s.red.position = Vector3(0, 1.6, 0)
		s.node.add_child(s.red)
		s.blue = MeshInstance3D.new()
		s.blue.mesh = Models.shrine_crystal_mesh()
		s.blue.material_override = _tinted(Color(0.4, 0.7, 1.0))
		s.blue.position = Vector3(0, 1.6, 0)
		s.blue.visible = false
		s.node.add_child(s.blue)
		shrines.append(s)


func _tinted(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.albedo_color = c
	return m


func wards_alive() -> int:
	var n := 0
	for w in wards:
		if w.alive:
			n += 1
	return n


func on_ward_destroyed(u: Unit) -> void:
	var i := wards.find(u)
	if i < 0:
		return
	game.fx.burst(u.pos + Vector3(0, 3, 0), Color(1.0, 0.3, 0.15), 40, 8.0, 0.3, 8.0)
	game.fx.ring(u.pos, 0.5, 8.0, Color(1, 0.4, 0.2), 0.8, 0.2)
	ward_beams[i].visible = false
	var tw := create_tween()
	tw.tween_property(ward_nodes[i], "position:y", -8.0, 2.5)
	game.shake = 0.35
	var left := wards_alive()
	if left > 0:
		game.hud.message("A Dread Ward is destroyed! %d remain shielding the Citadel." % left, 5.0, Color(1, 0.8, 0.45))
	else:
		shield_up = false
		game.hud.message("The last Ward falls — the Citadel's shield is down! Strike now!", 6.0, Color(1, 0.9, 0.4))
		game.sfx.play("horn", 4.0, 0.0, 0.0)


func update(dt: float) -> void:
	var hero := game.hero
	# Shield shimmer.
	if shield_up:
		var p := 0.12 + 0.05 * sin(game.time * 2.0)
		shield.visible = true
		shield.rotation.y += dt * 0.2
		var col := Color(0.9 * p * 1.5, 0.15 * p * 1.5, 0.25 * p * 1.5)
		(shield.material_override as StandardMaterial3D).albedo_color = col
	else:
		shield.visible = false
	# Ward turrets.
	for i in wards.size():
		var w := wards[i]
		if not w.alive:
			continue
		var gem: Node3D = ward_nodes[i].get_child(1)
		gem.position.y = 7.2 + sin(game.time * 1.7 + i) * 0.3
		gem.rotation.y += dt
		ward_fire[i] -= dt
		if ward_fire[i] <= 0.0 and hero.alive and (hero.position - w.pos).length() < 13.0:
			ward_fire[i] = 1.4
			game.fx.shoot("dark", w.pos + Vector3(0, 6.5, 0), hero.position + hero.vel * 0.3 + Vector3(0, 0.8, 0), 12.0, 14.0 + game.wave * 1.5, 1)
	# Shrines.
	var income := 0.0
	for s in shrines:
		s.hit_t = maxf(0.0, s.hit_t - dt)
		var crystal: Node3D = s.blue if s.owner == 0 else s.red
		crystal.position.y = 1.6 + sin(game.time * 2.0 + s.pos.x) * 0.15
		crystal.rotation.y += dt
		if s.owner == 1:
			var near_hero := hero.alive and Vector2(hero.position.x - s.pos.x, hero.position.z - s.pos.z).length() < 3.2
			var foes := 0
			for e: Unit in game.horde.enemies_near(s.pos, 8.0):
				if not e.structure:
					foes += 1
			if near_hero and foes == 0:
				s.cap += dt
				if s.cap >= CAPTURE_TIME:
					_capture(s)
			else:
				s.cap = maxf(0.0, s.cap - dt * 0.5)
		else:
			income += 1.2
			# Heal Camelot's side nearby.
			if hero.alive and (hero.position - s.pos).length() < 6.0:
				hero.hp = minf(hero.max_hp, hero.hp + 5.0 * dt)
			for f: Unit in game.horde.friends_near(s.pos, 6.0):
				f.hp = minf(f.max_hp, f.hp + 5.0 * dt)
			# Raiders tear at it.
			var dmg := 0.0
			for e: Unit in game.horde.enemies_near(s.pos, 3.8):
				if e.mode == "march":
					dmg += e.dmg * 0.6
			if dmg > 0.0:
				s.hp -= dmg * dt
				s.hit_t = 0.5
				if s.hp <= 0.0:
					s.owner = 1
					s.cap = 0.0
					s.red.visible = true
					s.blue.visible = false
					game.hud.message("%s has fallen to the Dread!" % s.name, 4.0, Color(1, 0.5, 0.4))
			else:
				s.hp = minf(s.max_hp, s.hp + 8.0 * dt)
	_income_acc += income * dt
	if _income_acc >= 1.0:
		var v := floorf(_income_acc)
		_income_acc -= v
		game.castle.add_gold(v, Vector3.ZERO, false)


func _capture(s: Shrine) -> void:
	s.owner = 0
	s.cap = 0.0
	s.hp = s.max_hp
	s.red.visible = false
	s.blue.visible = true
	game.fx.ring(s.pos, 0.5, 6.0, Color(0.4, 0.7, 1.0), 0.8, 0.2)
	game.fx.sparkle(s.pos + Vector3(0, 1, 0), Color(0.5, 0.8, 1.0), 20, 0.14)
	game.sfx.play("build", 2.0, 0.0, 0.0)
	game.hud.message("%s is yours! +gold, healing, and a waypoint (T)." % s.name, 5.0, Color(0.6, 0.85, 1.0))


func owned_shrines() -> Array:
	var out := []
	for s in shrines:
		if s.owner == 0:
			out.append(s)
	return out


func income_rate() -> float:
	return owned_shrines().size() * 1.2


## The waypoint Merlin is standing at (Camelot counts), or null.
func waypoint_here() -> bool:
	var hp := game.hero.position
	if (hp - game.maze.castle_pos).length() < Castle.DELIVER_R:
		return true
	for s in shrines:
		if s.owner == 0 and (hp - s.pos).length() < 4.0:
			return true
	return false


## Push Merlin out of the solid landmark bases.
func collide_hero(p: Vector3) -> Vector3:
	for w in wards:
		var d := Vector3(p.x - w.pos.x, 0, p.z - w.pos.z)
		var rr := 2.0
		if d.length() < rr and d.length() > 0.001:
			p = w.pos + d.normalized() * rr + Vector3(0, p.y, 0)
	return p
