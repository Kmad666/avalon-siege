class_name Castle
extends Node3D
## Your home: Camelot keep. Holds the treasury, takes deliveries, and turns
## gold / timber / crystal into upgrades for the castle, the hero and the army.

const UPGRADES := [
	{"key": "walls", "name": "Stone Walls", "desc": "+250 castle HP, full repair", "cost": {"wood": 25, "gold": 10}},
	{"key": "towers", "name": "Archer Tower", "desc": "builds a tower that shoots raiders", "cost": {"wood": 25, "gold": 15}},
	{"key": "barracks", "name": "Barracks", "desc": "+2 knights escort you", "cost": {"gold": 25, "wood": 15}},
	{"key": "forge", "name": "Forge", "desc": "+15% damage for all", "cost": {"gold": 20, "crystal": 10}},
	{"key": "armory", "name": "Armory", "desc": "+25 max HP, +1.5 armour", "cost": {"gold": 20, "wood": 15}},
	{"key": "mage", "name": "Mage Tower", "desc": "-7% cooldowns, castle lightning", "cost": {"crystal": 20, "gold": 15}},
	{"key": "stables", "name": "Stables", "desc": "+12 carry, +6% speed", "cost": {"wood": 20, "gold": 10}},
	{"key": "shrine", "name": "Shrine", "desc": "+1 potion, +1 HP/s regen", "cost": {"crystal": 15, "gold": 10}},
]
const MAX_LEVEL := 5
const DELIVER_R := 9.5
const BASE_HP := 1500.0
const TOWER_TILES := [Vector2i(-3, 0), Vector2i(0, -3), Vector2i(-3, -3), Vector2i(-3, 3), Vector2i(3, -3)]

var game: Game
var hp := BASE_HP
var max_hp := BASE_HP
var levels := {}
var treasury := {"gold": 20.0, "wood": 25.0, "crystal": 5.0}
var tower_nodes: Array[MeshInstance3D] = []
var tower_t: Array[float] = []
var zap_t := 2.0
var hit_flash := 0.0
var mage_orb: MeshInstance3D
var keep: MeshInstance3D


func setup(g: Game) -> void:
	game = g
	position = g.maze.castle_pos
	for u in UPGRADES:
		levels[u.key] = 0
	keep = MeshInstance3D.new()
	keep.mesh = Models.castle_mesh()
	Geo.apply(keep)
	add_child(keep)
	for tt: Vector2i in TOWER_TILES:
		var p := Vector3(tt.x * Maze.T, 0, tt.y * Maze.T)
		var plot := MeshInstance3D.new()
		plot.mesh = Models.tower_plot_mesh()
		Geo.apply(plot)
		plot.position = p
		add_child(plot)
		var t := MeshInstance3D.new()
		t.mesh = Models.archer_tower_mesh()
		Geo.apply(t)
		t.position = p + Vector3(0, 0.3, 0)
		t.visible = false
		add_child(t)
		tower_nodes.append(t)
		tower_t.append(randf())
	mage_orb = MeshInstance3D.new()
	mage_orb.mesh = Models.orb_mesh()
	mage_orb.material_override = Geo.mat_add()
	mage_orb.position = Vector3(-0.8, 6.6, -0.8)
	mage_orb.visible = false
	add_child(mage_orb)


func level(key: String) -> int:
	return levels.get(key, 0)


func cost_of(key: String) -> Dictionary:
	for u in UPGRADES:
		if u.key == key:
			var out := {}
			var mult := pow(1.6, level(key))
			for r in u.cost:
				out[r] = int(round(u.cost[r] * mult))
			return out
	return {}


func can_afford(key: String) -> bool:
	if level(key) >= MAX_LEVEL:
		return false
	var c := cost_of(key)
	for r in c:
		if treasury[r] < c[r]:
			return false
	return true


func buy(key: String) -> bool:
	if not can_afford(key):
		return false
	var c := cost_of(key)
	for r in c:
		treasury[r] -= c[r]
	levels[key] = level(key) + 1
	var lv := level(key)
	match key:
		"walls":
			max_hp = BASE_HP + 250.0 * lv
			hp = max_hp
		"towers":
			tower_nodes[lv - 1].visible = true
			game.fx.burst(tower_nodes[lv - 1].global_position + Vector3(0, 2, 0), Color(0.9, 0.8, 0.5), 16, 5.0, 0.2)
		"barracks":
			for k in 2:
				var a := game.horde.add_ally(position + Vector3(randf_range(-3, 3), 0, 7.5), ally_power())
				a.pos = game.maze.collide(a.pos, a.r)
			for a in game.horde.allies:
				a.max_hp = Horde.KINDS["knight"].hp * ally_power()
		"mage":
			mage_orb.visible = true
	game.hero.recompute()
	game.fx.ring(position, 2.0, 9.0, Color(1.0, 0.85, 0.4), 0.6, 0.2)
	return true


func ally_power() -> float:
	return 1.0 + 0.25 * level("barracks") + 0.15 * level("forge")


func ally_dmg_mult() -> float:
	return 1.0 + 0.15 * level("forge")


func ally_armor() -> float:
	return minf(0.5, 0.06 * level("armory"))


func take_damage(amount: float) -> void:
	if game.state != "play":
		return
	hp -= amount
	hit_flash = 0.25
	game.castle_hit_t = 2.0
	if hp <= 0.0:
		hp = 0.0
		game.on_castle_destroyed()


func deliver(hero: Hero) -> void:
	var any := false
	for r in hero.carry:
		var v: float = hero.carry[r]
		if v >= 1.0:
			treasury[r] += floor(v)
			hero.carry[r] = v - floor(v)
			var col: Color = {"wood": Color(0.85, 0.7, 0.35), "gold": Color(1, 0.85, 0.3), "crystal": Color(0.75, 0.55, 1)}[r]
			game.fx.number(hero.position + Vector3(0, 2.2, 0), "+%d %s" % [int(v), r], col)
			game.stats_delivered += v
			any = true
	if any:
		game.fx.ring(hero.position, 0.5, 2.5, Color(1.0, 0.85, 0.4), 0.45)
		game.sfx.play("deliver", 0.0, 0.3, 0.0)


func update(dt: float) -> void:
	hit_flash = maxf(0.0, hit_flash - dt)
	# Slow self-repair.
	hp = minf(max_hp, hp + dt * (1.0 + level("walls") * 1.0))
	var t_lv := level("towers")
	var dmg_mult := game.hero.dmg_mult
	for i in t_lv:
		tower_t[i] -= dt
		if tower_t[i] <= 0.0:
			var tp := tower_nodes[i].global_position + Vector3(0, 3.0, 0)
			var foe := game.horde.nearest_enemy(tower_nodes[i].global_position, 15.0)
			if foe != null:
				tower_t[i] = maxf(0.45, 1.1 - 0.08 * t_lv)
				var lead := foe.pos + foe.vel * 0.35 + Vector3(0, 0.7, 0)
				game.fx.shoot("arrow", tp, lead, 26.0, (14.0 + 4.0 * t_lv) * dmg_mult, 0)
			else:
				tower_t[i] = 0.3
	var m := level("mage")
	if m > 0:
		mage_orb.position.y = 6.8 + sin(game.time * 2.0) * 0.25
		zap_t -= dt
		if zap_t <= 0.0:
			var foe2 := game.horde.nearest_enemy(position, 17.0)
			if foe2 != null:
				zap_t = maxf(1.2, 3.6 - 0.4 * m)
				var src := mage_orb.global_position
				game.fx.lightning(src, foe2.pos + Vector3(0, 0.8, 0), Color(0.55, 0.7, 1.0))
				game.sfx.play("zap", -6.0, 0.15)
				game.horde.hurt(foe2, (30.0 + 15.0 * m) * dmg_mult, Vector3.ZERO, 0.0, Color(0.7, 0.8, 1.0))
				# small chain
				var nxt := game.horde.nearest_enemy(foe2.pos, 5.0)
				if nxt != null and nxt != foe2:
					game.fx.lightning(foe2.pos + Vector3(0, 0.8, 0), nxt.pos + Vector3(0, 0.8, 0), Color(0.55, 0.7, 1.0))
					game.horde.hurt(nxt, (20.0 + 10.0 * m) * dmg_mult, Vector3.ZERO, 0.0, Color(0.7, 0.8, 1.0))
			else:
				zap_t = 0.4
