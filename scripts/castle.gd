class_name Castle
extends Node3D
## Camelot. Holds the treasury, takes deliveries, sends counter-waves, and
## turns gold into upgrades for the castle, the wizard and the army.

const UPGRADES := [
	{"key": "walls", "name": "Stone Walls", "desc": "+300 castle HP, full repair", "cost": 40},
	{"key": "towers", "name": "Archer Tower", "desc": "builds a tower that shoots raiders", "cost": 50},
	{"key": "miners", "name": "Miners", "desc": "+2 peasants who mine gold for you", "cost": 45},
	{"key": "warcamp", "name": "War Camp", "desc": "+20% strength, +1 soldier per wave", "cost": 70},
	{"key": "barracks", "name": "Barracks", "desc": "+2 knights escort Merlin", "cost": 60},
	{"key": "forge", "name": "Forge", "desc": "+15% damage for all", "cost": 60},
	{"key": "armory", "name": "Armory", "desc": "+25 max HP, +1.5 armour", "cost": 50},
	{"key": "mage", "name": "Mage Tower", "desc": "-7% cooldowns, castle lightning", "cost": 70},
	{"key": "shrine", "name": "Shrine", "desc": "+1 potion, +1 HP/s, +10% move", "cost": 40},
]
const MAX_LEVEL := 5
## The royal steward's priorities: lower builds sooner (miners and towers first).
const BIAS := {"miners": -1.0, "towers": -0.4, "warcamp": -0.1, "forge": 0.2, "walls": 0.3,
	"barracks": 0.4, "mage": 0.5, "armory": 0.6, "shrine": 0.7}
const DELIVER_R := 9.5
const BASE_HP := 1500.0
const TOWER_TILES := [Vector2i(-3, 0), Vector2i(0, -3), Vector2i(-3, -3), Vector2i(-3, 3), Vector2i(3, -3)]

var game: Game
var hp := BASE_HP
var max_hp := BASE_HP
var levels := {}
var gold := 60.0
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


func cost_of(key: String) -> int:
	for u in UPGRADES:
		if u.key == key:
			return int(round(u.cost * pow(1.55, level(key))))
	return 0


func can_afford(key: String) -> bool:
	return level(key) < MAX_LEVEL and gold >= cost_of(key)


func buy(key: String) -> bool:
	if not can_afford(key):
		return false
	gold -= cost_of(key)
	levels[key] = level(key) + 1
	var lv := level(key)
	match key:
		"walls":
			max_hp = BASE_HP + 300.0 * lv
			hp = max_hp
		"towers":
			tower_nodes[lv - 1].visible = true
			game.fx.burst(tower_nodes[lv - 1].global_position + Vector3(0, 2, 0), Color(0.9, 0.8, 0.5), 16, 5.0, 0.2)
		"barracks":
			for k in 2:
				var a := game.horde.add_ally(position + Vector3(randf_range(-3, 3), 0, -7.5), ally_power())
				a.pos = game.maze.collide(a.pos, a.r)
			for a in game.horde.allies:
				a.max_hp = Horde.KINDS["knight"].hp * ally_power()
		"miners":
			for k in 2:
				game.horde.add_worker(position + Vector3(randf_range(-3, 3), 0, -7.5))
		"mage":
			mage_orb.visible = true
	game.hero.recompute()
	game.fx.ring(position, 2.0, 9.0, Color(1.0, 0.85, 0.4), 0.6, 0.2)
	return true


## What the steward is saving for next ("" when everything is built).
func next_key() -> String:
	if hp < max_hp * 0.5 and level("walls") < MAX_LEVEL:
		return "walls"
	var best := ""
	var bs := INF
	for u in UPGRADES:
		var k: String = u.key
		if level(k) >= MAX_LEVEL:
			continue
		var sc: float = level(k) + BIAS[k] + cost_of(k) * 0.0001
		if sc < bs:
			bs = sc
			best = k
	return best


func upgrade_name(key: String) -> String:
	for u in UPGRADES:
		if u.key == key:
			return u.name
	return key


func _steward() -> void:
	var k := next_key()
	if k == "" or gold < cost_of(k):
		return
	if buy(k):
		game.hud.message("Camelot builds %s (level %d) — %s" % [upgrade_name(k), level(k), _desc(k)], 3.5, Color(0.7, 1, 0.7))
		game.sfx.play("build", 0.0, 0.1, 0.0)


func _desc(key: String) -> String:
	for u in UPGRADES:
		if u.key == key:
			return u.desc
	return ""


func ally_power() -> float:
	return 1.0 + 0.25 * level("barracks") + 0.15 * level("forge")


func ally_dmg_mult() -> float:
	return 1.0 + 0.15 * level("forge")


func ally_armor() -> float:
	return minf(0.5, 0.06 * level("armory"))


## Strength multiplier for Camelot's marching counter-waves.
func army_power() -> float:
	return (1.0 + 0.2 * level("warcamp")) * (1.0 + 0.1 * level("forge")) * game.hero.relic_army


func take_damage(amount: float) -> void:
	if game.state != "play":
		return
	hp -= amount
	hit_flash = 0.25
	game.castle_hit_t = 2.0
	if hp <= 0.0:
		hp = 0.0
		game.on_castle_destroyed()


func add_gold(v: float, at: Vector3, show := true) -> void:
	gold += v
	game.stats_delivered += v
	if show:
		game.fx.number(at + Vector3(0, 2.2, 0), "+%d gold" % int(v), Color(1, 0.85, 0.3))


func deliver(hero: Hero) -> void:
	if hero.carry >= 1.0:
		var v := floorf(hero.carry)
		hero.carry -= v
		add_gold(v, hero.position)
		game.fx.ring(hero.position, 0.5, 2.5, Color(1.0, 0.85, 0.4), 0.45)
		game.sfx.play("deliver", 0.0, 0.3, 0.0)


func update(dt: float) -> void:
	hit_flash = maxf(0.0, hit_flash - dt)
	_steward()
	hp = minf(max_hp, hp + dt * (1.5 + level("walls") * 1.0))
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
				var nxt := game.horde.nearest_enemy(foe2.pos, 5.0)
				if nxt != null and nxt != foe2:
					game.fx.lightning(foe2.pos + Vector3(0, 0.8, 0), nxt.pos + Vector3(0, 0.8, 0), Color(0.55, 0.7, 1.0))
					game.horde.hurt(nxt, (20.0 + 10.0 * m) * dmg_mult, Vector3.ZERO, 0.0, Color(0.7, 0.8, 1.0))
			else:
				zap_t = 0.4
