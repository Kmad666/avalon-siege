class_name Horde
extends Node3D
## Every unit on the field: the Dread Army (team 1), and Camelot's side (team 0):
## Merlin's knight escort, the marching counter-waves, and the gold miners.
## Units are plain data; each kind is drawn with a single MultiMesh.

## Swarm tuning: rank-and-file foes are fragile, but there are many of them.
const KINDS := {
	# Dread Army
	"goblin": {"hp": 11.0, "spd": 4.1, "dmg": 4.0, "r": 0.36, "xp": 1, "gold": 0.35, "cd": 0.9, "reach": 0.45},
	"orc": {"hp": 32.0, "spd": 3.2, "dmg": 9.0, "r": 0.5, "xp": 2, "gold": 0.45, "cd": 1.1, "reach": 0.5},
	"skeleton": {"hp": 17.0, "spd": 3.0, "dmg": 6.0, "r": 0.4, "xp": 1, "gold": 0.35, "cd": 1.8, "reach": 0.4, "ranged": 10.0},
	"ogre": {"hp": 150.0, "spd": 2.5, "dmg": 20.0, "r": 0.85, "xp": 8, "gold": 1.0, "cd": 1.6, "reach": 0.7},
	"dark_knight": {"hp": 450.0, "spd": 3.4, "dmg": 26.0, "r": 0.62, "xp": 20, "gold": 1.0, "cd": 1.2, "reach": 0.7},
	"wolf": {"hp": 19.0, "spd": 6.0, "dmg": 5.0, "r": 0.48, "xp": 1, "gold": 0.35, "cd": 0.8, "reach": 0.5},
	"shaman": {"hp": 27.0, "spd": 3.0, "dmg": 7.0, "r": 0.45, "xp": 3, "gold": 0.5, "cd": 2.0, "reach": 0.4, "ranged": 9.0},
	"necro": {"hp": 42.0, "spd": 2.8, "dmg": 9.0, "r": 0.42, "xp": 4, "gold": 0.6, "cd": 2.2, "reach": 0.4, "ranged": 10.0},
	# Camelot
	"knight": {"hp": 90.0, "spd": 5.6, "dmg": 11.0, "r": 0.42, "cd": 0.8, "reach": 0.55},
	"guard": {"hp": 420.0, "spd": 4.6, "dmg": 22.0, "r": 0.5, "cd": 0.9, "reach": 0.6},
	"footman": {"hp": 12.0, "spd": 4.0, "dmg": 4.5, "r": 0.38, "cd": 0.9, "reach": 0.5},
	"swordsman": {"hp": 33.0, "spd": 3.2, "dmg": 9.0, "r": 0.5, "cd": 1.1, "reach": 0.5},
	"archer": {"hp": 17.0, "spd": 3.0, "dmg": 6.0, "r": 0.4, "cd": 1.8, "reach": 0.4, "ranged": 10.0},
	"paladin": {"hp": 150.0, "spd": 2.5, "dmg": 20.0, "r": 0.8, "cd": 1.6, "reach": 0.7},
	"champion": {"hp": 450.0, "spd": 3.4, "dmg": 26.0, "r": 0.62, "cd": 1.2, "reach": 0.7},
	"cavalry": {"hp": 19.0, "spd": 6.0, "dmg": 5.0, "r": 0.5, "cd": 0.8, "reach": 0.55},
	"cleric": {"hp": 27.0, "spd": 3.0, "dmg": 4.0, "r": 0.42, "cd": 1.2, "reach": 0.5},
	"battlemage": {"hp": 42.0, "spd": 2.8, "dmg": 11.0, "r": 0.42, "cd": 2.2, "reach": 0.4, "ranged": 10.0},
	"worker": {"hp": 40.0, "spd": 4.6, "dmg": 0.0, "r": 0.34, "cd": 1.0, "reach": 0.4},
	# The Circle of Avalon: Merlin's hooded adepts.
	"adept_frost": {"hp": 85.0, "spd": 6.8, "dmg": 13.0, "r": 0.4, "cd": 1.6, "reach": 0.4},
	"adept_ember": {"hp": 85.0, "spd": 6.8, "dmg": 16.0, "r": 0.4, "cd": 3.2, "reach": 0.4},
	"adept_thorn": {"hp": 85.0, "spd": 6.8, "dmg": 9.0, "r": 0.4, "cd": 6.0, "reach": 0.4},
	"adept_light": {"hp": 85.0, "spd": 6.8, "dmg": 0.0, "r": 0.4, "cd": 7.0, "reach": 0.4},
}
const ADEPTS := ["adept_frost", "adept_ember", "adept_thorn", "adept_light"]
const ADEPT_NAMES := {"adept_frost": "Frost", "adept_ember": "Ember", "adept_thorn": "Thorn", "adept_light": "Light"}
## Camelot's answer to each kind of Dread soldier.
const MIRROR := {"goblin": "footman", "orc": "swordsman", "skeleton": "archer", "ogre": "paladin", "dark_knight": "champion",
	"wolf": "cavalry", "shaman": "cleric", "necro": "battlemage"}
const MAX_ENEMIES := 460
const MAX_SOLDIERS := 180

var game: Game
var maze: Maze
var enemies: Array[Unit] = []
var allies: Array[Unit] = []      # Merlin's knight escort
var soldiers: Array[Unit] = []    # marching counter-waves
var workers: Array[Unit] = []     # gold miners
var dying: Array[Unit] = []
var mms := {}                     # kind -> MultiMesh
var bucket: Array = []            # tile index -> Array[Unit] or null (awake enemies)
var fbucket: Array = []           # tile index -> Array[Unit] or null (friendly)
var _bused := PackedInt32Array()
var _fused := PackedInt32Array()
var _buffers := {}
var camp_fields := {}             # camp id -> PackedInt32Array next
var _frame := 0


func setup(g: Game) -> void:
	game = g
	maze = g.maze
	bucket.resize(Maze.G * Maze.G)
	fbucket.resize(Maze.G * Maze.G)
	var meshes := {
		"goblin": [Models.goblin_mesh(), 470], "orc": [Models.orc_mesh(), 300], "skeleton": [Models.skeleton_mesh(), 320],
		"ogre": [Models.ogre_mesh(), 80], "dark_knight": [Models.dark_knight_mesh(), 24],
		"knight": [Models.ally_mesh(), 24], "footman": [Models.ally_mesh(), 240], "swordsman": [Models.swordsman_mesh(), 200],
		"archer": [Models.archer_mesh(), 200], "paladin": [Models.paladin_mesh(), 50], "champion": [Models.champion_mesh(), 14],
		"worker": [Models.worker_mesh(), 16], "guard": [Models.royal_guard_mesh(), 16],
		"wolf": [Models.wolf_rider_mesh(), 220], "shaman": [Models.shaman_mesh(), 100], "necro": [Models.necromancer_mesh(), 60],
		"cavalry": [Models.cavalry_mesh(), 200], "cleric": [Models.cleric_mesh(), 100], "battlemage": [Models.battlemage_mesh(), 60],
		"adept_frost": [Models.adept_mesh(0), 1], "adept_ember": [Models.adept_mesh(1), 1],
		"adept_thorn": [Models.adept_mesh(2), 1], "adept_light": [Models.adept_mesh(3), 1],
	}
	for k in meshes:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = meshes[k][0]
		mm.instance_count = meshes[k][1]
		mm.visible_instance_count = 0
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		Geo.apply(mmi)
		mmi.custom_aabb = AABB(Vector3(-20, -5, -20), Vector3(Maze.G * Maze.T + 40, 30, Maze.G * Maze.T + 40))
		add_child(mmi)
		mms[k] = mm


func make(kind: String, p: Vector3, team := 1, power := 1.0) -> Unit:
	var d: Dictionary = KINDS[kind]
	var u := Unit.new()
	u.kind = kind
	u.team = team
	u.pos = p
	u.home = p
	u.max_hp = d.hp * power
	u.hp = u.max_hp
	u.speed = d.spd * randf_range(0.92, 1.08)
	u.dmg = d.dmg * (1.0 + (power - 1.0) * 0.5)
	u.r = d.r
	u.xp = d.get("xp", 0)
	u.gold_chance = d.get("gold", 0.0)
	u.atk_cd = d.cd
	u.reach = d.reach
	u.ranged = d.get("ranged", 0.0)
	u.facing = randf() * TAU
	u.anim = randf() * 10.0
	u.think = randf() * 0.15
	if kind == "dark_knight":
		u.boss = true
	return u


func spawn(kind: String, p: Vector3, mode: String, power := 1.0, elite := false) -> Unit:
	if enemies.size() >= MAX_ENEMIES:
		return null
	var u := make(kind, p, 1, power * game.diff)
	u.mode = mode
	if elite:
		u.elite = true
		u.max_hp *= 2.5
		u.hp = u.max_hp
		u.dmg *= 1.4
		u.xp *= 3
		u.gold_chance = 1.0
		u.scale = 1.25
		u.tint = Color(1.0, 0.8, 0.62)
	enemies.append(u)
	return u


func spawn_soldier(kind: String, p: Vector3, power: float) -> Unit:
	if soldiers.size() >= MAX_SOLDIERS:
		return null
	var u := make(kind, p, 0, power)
	u.mode = "march"
	soldiers.append(u)
	return u


func add_ally(p: Vector3, power: float) -> Unit:
	var u := make("knight", p, 0, power)
	u.slot = allies.size()
	u.mode = "follow"
	allies.append(u)
	return u


## A Royal Guard posted at one of Camelot's gates.
func add_guard(p: Vector3) -> Unit:
	var u := make("guard", maze.collide(p, 0.5), 0, 1.0)
	u.mode = "guard"
	u.home = u.pos
	u.tint = Color(1.0, 0.95, 0.88)
	allies.append(u)
	return u


## A hooded adept of the Circle of Avalon, sworn to follow Merlin.
func add_adept(kind: String, p: Vector3, slot: int) -> Unit:
	var u := make(kind, maze.collide(p, 0.4), 0, 1.0)
	u.mode = "adept"
	u.slot = slot
	u.skill_t = randf_range(0.5, 2.0)
	allies.append(u)
	return u


func add_worker(p: Vector3) -> Unit:
	var u := make("worker", maze.collide(p, 0.34), 0, 1.0)
	u.mode = "w_go"
	workers.append(u)
	return u


# ------------------------------------------------------------- queries

## Flat per-tile spatial index, rebuilt each frame. Sleeping lair monsters are
## left out: nothing near them needs to find them.
func _rebuild_buckets() -> void:
	for i in _bused:
		bucket[i] = null
	for i in _fused:
		fbucket[i] = null
	_bused.clear()
	_fused.clear()
	var T := Maze.T
	var G := Maze.G
	for u in enemies:
		if u.dormant:
			continue
		var ti := clampi(int(u.pos.z / T), 0, G - 1) * G + clampi(int(u.pos.x / T), 0, G - 1)
		u.tile = ti
		var l = bucket[ti]
		if l == null:
			bucket[ti] = [u]
			_bused.append(ti)
		else:
			(l as Array).append(u)
	for list: Array[Unit] in [allies, soldiers, workers]:
		for u in list:
			if not u.alive:
				continue
			var ti2 := clampi(int(u.pos.z / T), 0, G - 1) * G + clampi(int(u.pos.x / T), 0, G - 1)
			u.tile = ti2
			var l2 = fbucket[ti2]
			if l2 == null:
				fbucket[ti2] = [u]
				_fused.append(ti2)
			else:
				(l2 as Array).append(u)


func _near(b: Array, p: Vector3, radius: float) -> Array:
	var out := []
	var t0 := Maze.tile_of(p - Vector3(radius, 0, radius))
	var t1 := Maze.tile_of(p + Vector3(radius, 0, radius))
	for y in range(t0.y, t1.y + 1):
		for x in range(t0.x, t1.x + 1):
			var l = b[y * Maze.G + x]
			if l == null:
				continue
			for u: Unit in l:
				if u.alive:
					var dx := u.pos.x - p.x
					var dz := u.pos.z - p.z
					var rr := radius + u.r
					if dx * dx + dz * dz < rr * rr:
						out.append(u)
	return out


func enemies_near(p: Vector3, radius: float) -> Array:
	return _near(bucket, p, radius)


func friends_near(p: Vector3, radius: float) -> Array:
	return _near(fbucket, p, radius)


func _nearest_in(list: Array, p: Vector3) -> Unit:
	var best: Unit = null
	var bd := INF
	for u: Unit in list:
		var d := (u.pos - p).length_squared()
		if d < bd:
			bd = d
			best = u
	return best


func nearest_enemy(p: Vector3, radius: float) -> Unit:
	return _nearest_in(enemies_near(p, radius), p)


func nearest_friend(p: Vector3, radius: float) -> Unit:
	return _nearest_in(friends_near(p, radius), p)


# ------------------------------------------------------------- damage

func hurt(u: Unit, amount: float, from_dir := Vector3.ZERO, knock := 0.0, color := Color(1, 0.95, 0.6)) -> void:
	if not u.alive:
		return
	# Dread Aura: the Citadel's own defenders shrug off half of all harm.
	if u.camp_id == -2 or u == game.dread_lord:
		amount *= 0.5
	u.hp -= amount
	u.flash = 0.18
	u.aggro = true
	if knock > 0.0 and not u.boss and u.mini < 0 and not u.structure:
		var kb := knock / (1.0 + u.r * 2.0)
		u.vel += from_dir * kb
	game.fx.number(u.pos + Vector3(0, 1.4 * u.scale, 0), str(int(round(amount))), color)
	game.sfx.play("hit", -6.0, 0.045)
	if u.hp <= 0.0:
		_kill(u)


## Damage dealt to anything on Camelot's side.
func hurt_friend(a: Unit, amount: float) -> void:
	if a == null or not a.alive:
		return
	a.hp -= amount * (1.0 - game.castle.ally_armor())
	a.flash = 0.18
	if a.hp <= 0.0:
		a.alive = false
		a.dying = 0.4
		dying.append(a)
		if a.mode == "follow":
			a.respawn_t = 18.0
		elif a.mode == "adept":
			a.respawn_t = 15.0
			game.hud.message("%s adept has fallen — returning in 15 s" % ADEPT_NAMES[a.kind], 2.5, Color(1, 0.6, 0.5))
		elif a.mode == "guard":
			a.respawn_t = 25.0
		elif a.kind == "worker":
			a.respawn_t = 20.0
			if a.job != null:
				a.job.workers -= 1
				a.job = null
			a.cargo = 0.0
		game.fx.burst(a.pos + Vector3(0, 0.5, 0), Color(0.75, 0.78, 0.85), 8, 4.0, 0.16)


func _kill(u: Unit) -> void:
	u.alive = false
	u.dying = 0.4
	dying.append(u)
	if u.team == 1:
		game.on_enemy_killed(u)
		game.sfx.play("kill", -3.0 if not u.boss else 4.0, 0.06)
	var col := Color(0.6, 0.85, 0.3)
	match u.kind:
		"orc": col = Color(0.45, 0.6, 0.35)
		"skeleton": col = Color(0.92, 0.9, 0.8)
		"ogre": col = Color(0.7, 0.55, 0.45)
		"dark_knight": col = Color(0.85, 0.15, 0.12)
	game.fx.burst(u.pos + Vector3(0, 0.5, 0), col, 6 + int(u.r * 8), 4.0, 0.16)


# ------------------------------------------------------------- update

func update(dt: float) -> void:
	var t := Time.get_ticks_usec()
	_rebuild_buckets()
	t = game._p("h_bucket", t)
	_frame += 1
	_update_enemies(dt)
	t = game._p("h_enemy", t)
	_update_soldiers(dt)
	t = game._p("h_sold", t)
	_update_allies(dt)
	t = game._p("h_ally", t)
	_update_workers(dt)
	_update_dying(dt)
	t = game._p("h_rest", t)


func _update_enemies(dt: float) -> void:
	var hero: Hero = game.hero
	var hero_ok := hero.alive
	var hp := hero.position
	var castle_p := maze.castle_pos
	var ui := 0
	for u in enemies:
		ui += 1
		if not u.alive or u.structure:
			continue
		# Idle lairs far from Merlin sleep: checked one frame in four, no movement.
		if u.dormant and (ui + _frame) & 3 != 0:
			continue
		u.atk_t -= dt
		u.flash = maxf(0.0, u.flash - dt)
		u.lunge = maxf(0.0, u.lunge - dt * 4.0)
		var dormant := u.mode == "camp" and u.t_kind == "" and not u.aggro and u.flash <= 0.0 and absf(hp.x - u.pos.x) + absf(hp.z - u.pos.z) > 40.0
		u.dormant = dormant and u.path_dir == Vector3.ZERO
		u.think -= dt
		if u.think <= 0.0:
			u.think = (0.5 if dormant else 0.11) + randf() * 0.05
			_decide(u, hero_ok, hp, castle_p)
		if dormant and u.path_dir == Vector3.ZERO:
			continue
		if u.kind == "shaman" or u.kind == "necro":
			_enemy_skill(u, dt)
		var desire := Vector3.ZERO
		var target_pos := Vector3.ZERO
		var target_r := 0.0
		match u.t_kind:
			"hero":
				target_pos = hp
				target_r = 0.45
			"ally":
				if u.t_ally == null or not u.t_ally.alive:
					u.t_kind = ""
				else:
					target_pos = u.t_ally.pos
					target_r = u.t_ally.r
			"castle":
				target_pos = castle_p
				target_r = 7.4
		if u.t_kind == "hero" and not hero_ok:
			u.t_kind = ""
		var to_t := Vector3(target_pos.x - u.pos.x, 0, target_pos.z - u.pos.z)
		var dist := to_t.length()
		if u.t_kind != "":
			var in_melee := dist < u.r + target_r + u.reach
			var can_shoot := u.ranged > 0.0 and u.los and dist < u.ranged
			if dist > 0.01:
				u.facing = lerp_angle(u.facing, atan2(to_t.x, to_t.z), minf(1.0, dt * 10.0))
			if can_shoot:
				if u.atk_t <= 0.0:
					u.atk_t = u.atk_cd
					u.lunge = 1.0
					var aim := target_pos + Vector3(0, 0.8, 0)
					if u.t_kind == "castle":
						aim = target_pos + Vector3(randf_range(-2, 2), 2.0, randf_range(-2, 2))
					game.fx.shoot("earrow" if u.kind == "skeleton" else "dark", u.pos + Vector3(0, 1.0, 0), aim, 13.0, u.dmg, 1)
				if dist < u.ranged * 0.45 and u.t_kind != "castle":
					desire = -to_t / maxf(dist, 0.01)
			elif in_melee:
				if u.atk_t <= 0.0:
					u.atk_t = u.atk_cd
					u.lunge = 1.0
					match u.t_kind:
						"hero": hero.take_damage(u.dmg, u.pos)
						"ally": hurt_friend(u.t_ally, u.dmg)
						"castle": game.castle.take_damage(u.dmg)
			elif u.los and u.t_kind != "castle":
				desire = to_t / maxf(dist, 0.01)
			else:
				desire = u.path_dir
		else:
			desire = u.path_dir
			if u.mode == "camp" and desire == Vector3.ZERO:
				u.anim += dt * 0.2
				desire = Vector3(sin(u.anim * 0.7 + u.home.x), 0, cos(u.anim * 0.5 + u.home.z)) * 0.15
			if desire.length_squared() > 0.01:
				u.facing = lerp_angle(u.facing, atan2(desire.x, desire.z), minf(1.0, dt * 8.0))
		if (ui + _frame) % 2 == 0:
			u.sep = _separation(u, bucket)
		_step(u, desire * u.speed + u.sep * 3.0, dt, 7.0)


## Shamans heal the Dread host around them; necromancers raise skeletons.
func _enemy_skill(u: Unit, dt: float) -> void:
	u.skill_t -= dt
	if u.skill_t > 0.0:
		return
	if u.kind == "shaman":
		u.skill_t = 3.0
		var healed := false
		for e: Unit in enemies_near(u.pos, 6.0):
			if e.hp < e.max_hp:
				e.hp = minf(e.max_hp, e.hp + 12.0 + u.max_hp * 0.25)
				healed = true
		if healed:
			game.fx.ring(u.pos, 0.3, 6.0, Color(0.3, 1.0, 0.35), 0.5, 0.12)
	else:
		u.skill_t = 7.0
		if u.t_kind == "" and u.mode == "camp":
			return
		if enemies.size() < MAX_ENEMIES - 20:
			game.fx.ring(u.pos, 0.3, 3.0, Color(0.7, 0.3, 1.0), 0.5, 0.12)
			for k in 2:
				var p := maze.collide(u.pos + Vector3(randf_range(-1.5, 1.5), 0, randf_range(-1.5, 1.5)), 0.4)
				var s := spawn("skeleton", p, u.mode, maxf(0.6, u.max_hp / 75.0 / game.diff * 0.6), false)
				if s != null:
					s.camp_id = u.camp_id
					s.home = u.home
					s.xp = 1
					s.gold_chance = 0.2
					game.fx.burst(p + Vector3(0, 0.4, 0), Color(0.7, 0.3, 1.0), 6, 3.0, 0.12)


func _step(u: Unit, want: Vector3, dt: float, accel: float) -> void:
	if u.slow_t > 0.0:
		u.slow_t -= dt
		want *= 0.45
	u.vel = u.vel.lerp(want, minf(1.0, dt * accel))
	var np := maze.collide(u.pos + u.vel * dt, u.r)
	var moved := (np - u.pos).length()
	if moved > 0.002:
		u.anim += moved * 2.4
	u.pos = np


func _decide(u: Unit, hero_ok: bool, hp: Vector3, castle_p: Vector3) -> void:
	u.t_kind = ""
	u.t_ally = null
	u.los = false
	u.path_dir = Vector3.ZERO
	var dh := INF
	if hero_ok:
		dh = Vector2(hp.x - u.pos.x, hp.z - u.pos.z).length()
	var aggro_r := 9.0 if u.mode == "camp" else 7.5
	if u.aggro:
		aggro_r = 14.0
	if u.mini >= 0:
		aggro_r = 11.0
	if dh < aggro_r and game.hero_dist(u.pos) < 230:
		u.t_kind = "hero"
	else:
		u.aggro = false
		var f: Unit = null
		if u.mode == "march" or u.camp_id == -2:
			f = nearest_friend(u.pos, 6.0)
		else:
			# Lair monsters ignore passing soldiers and miners; they only fight Merlin's escort.
			for c: Unit in friends_near(u.pos, 7.5):
				if (c.mode == "follow" or c.mode == "adept") and (c.pos - u.home).length() < 16.0:
					f = c
					break
		if f != null:
			u.t_kind = "ally"
			u.t_ally = f
		elif u.mode == "march" and (castle_p - u.pos).length() < 9.0:
			u.t_kind = "castle"
	match u.t_kind:
		"hero":
			var d := Vector2(hp.x - u.pos.x, hp.z - u.pos.z).length()
			u.los = d < maxf(6.0, u.ranged) and maze.line_clear(u.pos, hp)
			if not u.los:
				u.path_dir = game.hero_flow(u.pos)
				if u.path_dir == Vector3.ZERO:
					u.path_dir = Vector3(hp.x - u.pos.x, 0, hp.z - u.pos.z).normalized()
		"ally":
			u.los = maze.line_clear(u.pos, u.t_ally.pos)
			if not u.los:
				u.path_dir = _march_dir(u.pos) if u.mode == "march" else Vector3(u.t_ally.pos.x - u.pos.x, 0, u.t_ally.pos.z - u.pos.z).normalized()
		"castle":
			u.los = u.ranged > 0.0 and (castle_p - u.pos).length() < 13.0
			u.path_dir = _march_dir(u.pos)
		_:
			if u.mode == "march":
				u.path_dir = _march_dir(u.pos)
			elif u.mode == "camp":
				var hd := Vector3(u.home.x - u.pos.x, 0, u.home.z - u.pos.z)
				if hd.length() > 2.5:
					var fld = camp_fields.get(u.camp_id)
					if fld != null and not maze.line_clear(u.pos, u.home):
						u.path_dir = maze.flow_dir(u.pos, fld)
					else:
						u.path_dir = hd.normalized()


## Follow the flow field to Camelot; at the end of it, close in on the walls.
func _march_dir(p: Vector3) -> Vector3:
	var d := maze.flow_dir(p, maze.to_castle_next)
	if d == Vector3.ZERO:
		var to := maze.castle_pos - p
		to.y = 0
		return to.normalized()
	return d


func _assault_dir(p: Vector3) -> Vector3:
	var d := maze.flow_dir(p, maze.to_citadel_next)
	if d == Vector3.ZERO:
		var to := maze.citadel_pos - p
		to.y = 0
		return to.normalized()
	return d


func _separation(u: Unit, b: Array) -> Vector3:
	var s := Vector3.ZERO
	var t := u.tile
	var x := t % Maze.G
	var y := t / Maze.G
	var seen := 0
	var ux := u.pos.x
	var uz := u.pos.z
	var fx := ux / Maze.T - x
	var fz := uz / Maze.T - y
	var x0 := -1 if fx < 0.5 else 0
	var y0 := -1 if fz < 0.5 else 0
	for dy in range(y0, y0 + 2):
		for dx in range(x0, x0 + 2):
			var ti := (y + dy) * Maze.G + x + dx
			if ti < 0 or ti >= b.size():
				continue
			var l = b[ti]
			if l == null:
				continue
			for o: Unit in l:
				seen += 1
				if seen > 14:
					return s
				if o == u:
					continue
				var ddx := ux - o.pos.x
				var ddz := uz - o.pos.z
				var rr := u.r + o.r
				var d2 := ddx * ddx + ddz * ddz
				if d2 < rr * rr and d2 > 1e-6:
					var d := sqrt(d2)
					var push := (rr - d) / rr
					s.x += ddx / d * push
					s.z += ddz / d * push
	return s


# ------------------------------------------------------------- Camelot's soldiers

func _update_soldiers(dt: float) -> void:
	var cit_alive := game.citadel_hp > 0.0
	var cp := maze.citadel_pos
	var ui := 0
	for u in soldiers:
		ui += 1
		if not u.alive:
			continue
		u.atk_t -= dt
		u.flash = maxf(0.0, u.flash - dt)
		u.lunge = maxf(0.0, u.lunge - dt * 4.0)
		if u.kind == "cleric":
			u.skill_t -= dt
			if u.skill_t <= 0.0:
				u.skill_t = 3.0
				var healed := false
				for f: Unit in friends_near(u.pos, 6.0):
					if f.hp < f.max_hp:
						f.hp = minf(f.max_hp, f.hp + 14.0 + u.max_hp * 0.25)
						healed = true
				if healed:
					game.fx.ring(u.pos, 0.3, 6.0, Color(1.0, 0.9, 0.45), 0.5, 0.12)
		u.think -= dt
		if u.think <= 0.0:
			u.think = 0.18 + randf() * 0.06
			u.t_kind = ""
			u.t_ally = null
			u.los = false
			var foe: Unit = null
			var bd := INF
			for e: Unit in enemies_near(u.pos, 8.0):
				if e.mode == "march" or e.camp_id == -2 or e.t_ally == u:
					var d := (e.pos - u.pos).length_squared()
					if d < bd:
						bd = d
						foe = e
			if foe != null:
				u.t_kind = "enemy"
				u.t_ally = foe
				u.los = maze.line_clear(u.pos, foe.pos)
				u.path_dir = _assault_dir(u.pos) if not u.los else Vector3.ZERO
			elif cit_alive and (cp - u.pos).length() < 9.5:
				u.t_kind = "citadel"
				u.los = true
			else:
				u.path_dir = _assault_dir(u.pos)
		var desire := Vector3.ZERO
		var tp := Vector3.ZERO
		var tr := 0.0
		if u.t_kind == "enemy":
			if u.t_ally == null or not u.t_ally.alive:
				u.t_kind = ""
				u.think = 0.0
			else:
				tp = u.t_ally.pos
				tr = u.t_ally.r
		elif u.t_kind == "citadel":
			if not cit_alive:
				u.t_kind = ""
			tp = cp
			tr = 7.4
		if u.t_kind != "":
			var to := Vector3(tp.x - u.pos.x, 0, tp.z - u.pos.z)
			var dist := to.length()
			if dist > 0.01:
				u.facing = lerp_angle(u.facing, atan2(to.x, to.z), minf(1.0, dt * 10.0))
			if u.ranged > 0.0 and u.los and dist < u.ranged:
				if u.atk_t <= 0.0:
					u.atk_t = u.atk_cd
					u.lunge = 1.0
					if u.t_kind == "citadel":
						game.damage_citadel(u.dmg * 0.25, false)
						game.fx.shoot("arrow", u.pos + Vector3(0, 1.0, 0), tp + Vector3(randf_range(-2, 2), 3.0, randf_range(-2, 2)), 24.0, 0.0, 0)
					elif u.kind == "battlemage":
						game.fx.shoot("fireball", u.pos + Vector3(0, 1.0, 0), tp + Vector3(0, 1.0, 0), 11.0, u.dmg, 0, null, 1.8)
					else:
						game.fx.shoot("arrow", u.pos + Vector3(0, 1.0, 0), tp + u.t_ally.vel * 0.3 + Vector3(0, 0.7, 0), 24.0, u.dmg, 0)
			elif dist < u.r + tr + u.reach:
				if u.atk_t <= 0.0:
					u.atk_t = u.atk_cd
					u.lunge = 1.0
					if u.t_kind == "citadel":
						game.damage_citadel(u.dmg * 0.25, false)
					else:
						hurt(u.t_ally, u.dmg, to / maxf(dist, 0.01), 1.5, Color(0.7, 0.85, 1.0))
			elif u.los:
				desire = to / maxf(dist, 0.01)
			else:
				desire = u.path_dir
		else:
			desire = u.path_dir
			if desire.length_squared() > 0.01:
				u.facing = lerp_angle(u.facing, atan2(desire.x, desire.z), minf(1.0, dt * 8.0))
		if (ui + _frame) % 2 == 0:
			u.sep = _separation(u, fbucket)
		_step(u, desire * u.speed + u.sep * 3.0, dt, 7.0)
	var j := soldiers.size() - 1
	while j >= 0:
		if not soldiers[j].alive and soldiers[j].dying <= 0.0:
			soldiers.remove_at(j)
		j -= 1


# ------------------------------------------------------------- knight escort

func _update_allies(dt: float) -> void:
	var hero: Hero = game.hero
	var hp := hero.position
	var knights := 0
	for a in allies:
		if a.mode == "follow":
			knights += 1
	for a in allies:
		if not a.alive:
			if a.dying <= 0.0:
				a.respawn_t -= dt
				if a.respawn_t <= 0.0:
					a.alive = true
					a.hp = a.max_hp
					a.vel = Vector3.ZERO
					a.slow_t = 0.0
					match a.mode:
						"guard": a.pos = a.home
						"adept":
							var base := hp if hero.alive else maze.castle_pos + Vector3(-2, 0, -7)
							a.pos = maze.collide(base + Vector3(randf_range(-1.5, 1.5), 0, randf_range(-1.5, 1.5)), a.r)
							game.fx.ring(a.pos, 0.2, 1.5, Color(0.7, 0.85, 1.0), 0.5, 0.15)
						_: a.pos = maze.collide(maze.castle_pos + Vector3(randf_range(-4, 4), 0, -7.5), a.r)
			continue
		a.atk_t -= dt
		a.flash = maxf(0.0, a.flash - dt)
		a.lunge = maxf(0.0, a.lunge - dt * 4.0)
		match a.mode:
			"guard": _update_guard(a, dt)
			"adept": _update_adept(a, hero, dt)
			_: _update_knight(a, hero, knights, dt)


func _update_knight(a: Unit, hero: Hero, n: int, dt: float) -> void:
	var hp := hero.position
	a.hp = minf(a.max_hp, a.hp + dt * 1.5)
	var desire := Vector3.ZERO
	var foe: Unit = null
	var leash_p := hp if hero.alive else maze.castle_pos
	var near := nearest_enemy(a.pos, 6.5)
	if near != null and (near.pos - leash_p).length() < 11.0:
		foe = near
	if foe != null:
		var to := Vector3(foe.pos.x - a.pos.x, 0, foe.pos.z - a.pos.z)
		var d := to.length()
		a.facing = lerp_angle(a.facing, atan2(to.x, to.z), minf(1.0, dt * 10.0))
		if d < a.r + foe.r + a.reach:
			if a.atk_t <= 0.0:
				a.atk_t = a.atk_cd
				a.lunge = 1.0
				hurt(foe, a.dmg * game.castle.ally_dmg_mult(), to / maxf(d, 0.01), 2.0, Color(0.7, 0.85, 1.0))
		else:
			desire = to / maxf(d, 0.01)
	else:
		var ang := TAU * float(a.slot) / maxf(1.0, float(n)) + 0.4
		var ring_r := 1.8 + 0.5 * float(a.slot % 2)
		desire = _follow_dir(a, leash_p + Vector3(cos(ang), 0, sin(ang)) * ring_r, hero, dt)
	_step(a, desire * a.speed, dt, 8.0)


## Walk toward `spot`, routing around walls with Merlin's flow field.
func _follow_dir(a: Unit, spot: Vector3, hero: Hero, dt: float) -> Vector3:
	var to := Vector3(spot.x - a.pos.x, 0, spot.z - a.pos.z)
	var d := to.length()
	if d <= 0.6:
		return Vector3.ZERO
	var desire: Vector3
	if not maze.line_clear(a.pos, spot):
		desire = game.hero_flow(a.pos) if hero.alive else maze.flow_dir(a.pos, maze.to_castle_next)
		if desire == Vector3.ZERO:
			desire = to / d
	else:
		desire = to / d * clampf(d / 2.0, 0.2, 1.0)
	a.facing = lerp_angle(a.facing, atan2(desire.x, desire.z), minf(1.0, dt * 8.0))
	return desire


func _update_guard(a: Unit, dt: float) -> void:
	a.hp = minf(a.max_hp, a.hp + dt * 4.0)
	var desire := Vector3.ZERO
	var foe := nearest_enemy(a.home, 10.0)
	if foe != null:
		var to := Vector3(foe.pos.x - a.pos.x, 0, foe.pos.z - a.pos.z)
		var d := to.length()
		a.facing = lerp_angle(a.facing, atan2(to.x, to.z), minf(1.0, dt * 10.0))
		if d < a.r + foe.r + a.reach:
			if a.atk_t <= 0.0:
				a.atk_t = a.atk_cd
				a.lunge = 1.0
				hurt(foe, a.dmg * game.castle.ally_dmg_mult(), to / maxf(d, 0.01), 3.0, Color(1.0, 0.85, 0.6))
		else:
			desire = to / maxf(d, 0.01)
	else:
		var th := Vector3(a.home.x - a.pos.x, 0, a.home.z - a.pos.z)
		if th.length() > 0.5:
			desire = th.normalized() * clampf(th.length() / 2.0, 0.3, 1.0)
			a.facing = lerp_angle(a.facing, atan2(desire.x, desire.z), minf(1.0, dt * 8.0))
		else:
			# Face out toward the realm.
			var out := maze.citadel_pos - a.pos
			a.facing = lerp_angle(a.facing, atan2(out.x, out.z), minf(1.0, dt * 2.0))
	_step(a, desire * a.speed, dt, 8.0)


func _update_adept(a: Unit, hero: Hero, dt: float) -> void:
	var hp := hero.position
	a.hp = minf(a.max_hp, a.hp + dt * 2.0)
	a.skill_t -= dt
	# Left far behind (waypoint travel, blink): catch up by arcane step.
	if hero.alive and (a.pos - hp).length() > 24.0:
		game.fx.ring(a.pos, 0.2, 1.2, Color(0.7, 0.85, 1.0), 0.4, 0.15)
		a.pos = maze.collide(hp + Vector3(randf_range(-1.5, 1.5), 0, randf_range(-1.5, 1.5)), a.r)
		game.fx.ring(a.pos, 1.2, 0.2, Color(0.7, 0.85, 1.0), 0.4, 0.15)
	# Formation: a loose arc behind Merlin.
	var ang := hero.facing + PI + (float(a.slot) - 1.5) * 0.55
	var spot := hp + Vector3(sin(ang), 0, cos(ang)) * 2.6
	var desire := _follow_dir(a, spot, hero, dt) if hero.alive else Vector3.ZERO
	var foe: Unit = null
	if hero.alive:
		var nf := nearest_enemy(a.pos, 9.5)
		if nf != null and (nf.pos - hp).length() < 13.0:
			foe = nf
	if foe != null:
		var tf := foe.pos - a.pos
		a.facing = lerp_angle(a.facing, atan2(tf.x, tf.z), minf(1.0, dt * 10.0))
	if a.skill_t <= 0.0:
		_adept_cast(a, foe, hero)
	_step(a, desire * a.speed, dt, 9.0)


func _adept_cast(a: Unit, foe: Unit, hero: Hero) -> void:
	var dm := a.dmg * hero.dmg_mult * (1.0 + 0.04 * hero.level)
	var src := a.pos + Vector3(0, 1.3, 0)
	match a.kind:
		"adept_frost":
			if foe == null:
				a.skill_t = 0.3
				return
			a.skill_t = a.atk_cd
			a.lunge = 0.8
			game.fx.shoot("frost", src, foe.pos + Vector3(0, 0.7, 0), 16.0, dm, 0, foe)
		"adept_ember":
			if foe == null or (foe.pos - a.pos).length() > 6.0:
				a.skill_t = 0.3
				return
			a.skill_t = a.atk_cd
			a.lunge = 1.0
			var yaw := atan2(foe.pos.x - a.pos.x, foe.pos.z - a.pos.z)
			var fwd := Vector3(sin(yaw), 0, cos(yaw))
			game.fx.slash(a.pos, yaw, 5.5, Color(1.0, 0.45, 0.1))
			game.fx.burst(a.pos + fwd * 2.5 + Vector3(0, 0.6, 0), Color(1.0, 0.5, 0.1), 10, 5.0, 0.16, 2.0)
			game.sfx.play("fire", -6.0, 0.15)
			for u: Unit in enemies_near(a.pos, 5.5):
				var to := u.pos - a.pos
				to.y = 0
				if to.length() < 1.0 or fwd.dot(to.normalized()) > 0.35:
					hurt(u, dm, to.normalized(), 3.0, Color(1, 0.6, 0.25))
		"adept_thorn":
			if foe == null:
				a.skill_t = 0.4
				return
			a.skill_t = a.atk_cd
			a.lunge = 0.8
			# Root the thickest part of the swarm.
			var best := foe.pos
			var bc := 0
			for u: Unit in enemies_near(foe.pos, 4.0):
				var c := enemies_near(u.pos, 2.6).size()
				if c > bc:
					bc = c
					best = u.pos
			game.fx.zone(best, 2.8, dm, 4.0)
		"adept_light":
			# Mending Ward: heal and shield whoever needs it most.
			var need := hero.alive and (hero.hp < hero.max_hp * 0.85 or hero.barrier < 5.0)
			var low: Unit = null
			for o in allies:
				if o.alive and o.mode == "adept" and o.hp < o.max_hp * 0.6:
					low = o
			if not need and low == null:
				a.skill_t = 0.5
				return
			a.skill_t = a.atk_cd
			a.lunge = 0.8
			if need:
				hero.hp = minf(hero.max_hp, hero.hp + 12.0 + hero.max_hp * 0.06)
				hero.barrier = maxf(hero.barrier, 25.0 + 3.0 * hero.level)
				game.fx.lightning(src, hp_top(hero), Color(1.0, 0.95, 0.6))
				game.fx.ring(hero.position, 0.3, 1.6, Color(1.0, 0.9, 0.5), 0.5, 0.25)
			if low != null:
				low.hp = minf(low.max_hp, low.hp + 40.0)
				game.fx.sparkle(low.pos, Color(1.0, 0.95, 0.6), 6, 0.1)


func hp_top(hero: Hero) -> Vector3:
	return hero.position + Vector3(0, 1.0, 0)


# ------------------------------------------------------------- miners

func _update_workers(dt: float) -> void:
	var nodes: ResNodes = game.nodes
	for w in workers:
		if not w.alive:
			if w.dying <= 0.0:
				w.respawn_t -= dt
				if w.respawn_t <= 0.0:
					w.alive = true
					w.hp = w.max_hp
					w.mode = "w_go"
					w.pos = maze.collide(maze.castle_pos + Vector3(randf_range(-3, 3), 0, -7.5), w.r)
			continue
		w.flash = maxf(0.0, w.flash - dt)
		w.hp = minf(w.max_hp, w.hp + dt)
		var desire := Vector3.ZERO
		# Run home when a foe gets close.
		w.think -= dt
		if w.think <= 0.0:
			w.think = 0.25
			w.aggro = false
			for e: Unit in enemies_near(w.pos, 4.5):
				if e.mode == "march" or e.t_ally == w:
					w.aggro = true
					break
		match w.mode:
			"w_go":
				if w.job == null or w.job.amount <= 0.0:
					if w.job != null:
						w.job.workers -= 1
					w.job = nodes.pick_for_worker()
					if w.job != null:
						w.job.workers += 1
				if w.job == null:
					desire = _march_dir(w.pos) if (w.pos - maze.castle_pos).length() > 9.0 else Vector3.ZERO
				elif w.aggro:
					desire = _march_dir(w.pos)
				else:
					var to: Vector3 = w.job.pos - w.pos
					to.y = 0
					if to.length() < 1.9:
						w.mode = "w_mine"
					elif to.length() < 4.0 and maze.line_clear(w.pos, w.job.pos):
						desire = to.normalized()
					else:
						desire = maze.flow_dir(w.pos, nodes.path_to(w.job))
			"w_mine":
				if w.job == null or w.job.amount <= 0.0 or w.cargo >= 12.0 or w.aggro:
					if w.job != null:
						w.job.workers -= 1
						w.job = null
					w.mode = "w_home"
				else:
					var got: float = nodes.take(w.job, 3.0 * dt)
					w.cargo += got
					w.anim += dt * 8.0
					var tj: Vector3 = w.job.pos - w.pos
					w.facing = atan2(tj.x, tj.z)
					w.lunge = absf(sin(game.time * 8.0)) * 0.5
			"w_home":
				if (w.pos - maze.castle_pos).length() < 9.0:
					if w.cargo >= 1.0:
						game.castle.add_gold(floorf(w.cargo), w.pos)
						game.sfx.play("coin", -8.0, 0.1)
					w.cargo = 0.0
					w.mode = "w_go"
				else:
					desire = _march_dir(w.pos)
		if desire.length_squared() > 0.01:
			w.facing = lerp_angle(w.facing, atan2(desire.x, desire.z), minf(1.0, dt * 8.0))
		_step(w, desire * w.speed, dt, 8.0)


func _update_dying(dt: float) -> void:
	var i := dying.size() - 1
	while i >= 0:
		var u: Unit = dying[i]
		u.dying -= dt
		if u.dying <= 0.0:
			dying.remove_at(i)
		i -= 1
	var j := enemies.size() - 1
	while j >= 0:
		if not enemies[j].alive:
			enemies.remove_at(j)
		j -= 1


# ------------------------------------------------------------- render

func render() -> void:
	# Only units near the camera are drawn; the fog hides the rest anyway.
	var cf := game.cam_focus
	var vr := game.camera.size * 1.35
	var vr2 := vr * vr
	var groups := {}
	for k in mms:
		groups[k] = []
	for u in enemies:
		var dx := u.pos.x - cf.x
		var dz := u.pos.z - cf.z
		if dx * dx + dz * dz < vr2 and groups.has(u.kind):
			(groups[u.kind] as Array).append(u)
	for list: Array[Unit] in [allies, soldiers, workers]:
		for a in list:
			if a.alive:
				var dx2 := a.pos.x - cf.x
				var dz2 := a.pos.z - cf.z
				if dx2 * dx2 + dz2 * dz2 < vr2:
					(groups[a.kind] as Array).append(a)
	for u in dying:
		if groups.has(u.kind):
			(groups[u.kind] as Array).append(u)
	for k in mms:
		var mm: MultiMesh = mms[k]
		var list: Array = groups[k]
		var n := mini(list.size(), mm.instance_count)
		if n == 0 and mm.visible_instance_count == 0:
			continue
		var buf: PackedFloat32Array = _buffers.get(k, PackedFloat32Array())
		if buf.size() != mm.instance_count * 16:
			buf.resize(mm.instance_count * 16)
		for i in n:
			var u: Unit = list[i]
			var s := u.scale
			var y := 0.0
			var walking := clampf(u.vel.length() / maxf(u.speed, 0.1), 0.0, 1.0)
			y += absf(sin(u.anim)) * 0.14 * walking * s
			var tilt := sin(u.anim) * 0.08 * walking
			var fwd := Vector3(sin(u.facing), 0, cos(u.facing))
			var p := u.pos + fwd * (u.lunge * u.lunge * 0.35)
			if u.dying > 0.0:
				var t := 1.0 - u.dying / 0.4
				y -= t * 0.6
				s *= 1.0 - t * 0.6
				tilt += t * 0.9
			var b := Basis(Vector3.UP, u.facing) * Basis(Vector3(0, 0, 1), tilt) * Basis(Vector3(1, 0, 0), -u.lunge * 0.25)
			b = b.scaled(Vector3(s, s, s))
			var o := i * 16
			buf[o] = b.x.x; buf[o + 1] = b.y.x; buf[o + 2] = b.z.x; buf[o + 3] = p.x
			buf[o + 4] = b.x.y; buf[o + 5] = b.y.y; buf[o + 6] = b.z.y; buf[o + 7] = y
			buf[o + 8] = b.x.z; buf[o + 9] = b.y.z; buf[o + 10] = b.z.z; buf[o + 11] = p.z
			var col := u.tint
			if u.flash > 0.0 or u.dying > 0.0:
				col = Color(1.0, 0.3, 0.25)
			buf[o + 12] = col.r; buf[o + 13] = col.g; buf[o + 14] = col.b; buf[o + 15] = 1.0
		_buffers[k] = buf
		mm.buffer = buf
		mm.visible_instance_count = n
