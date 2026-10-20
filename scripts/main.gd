class_name Game
extends Node3D
## Avalon Siege — game manager. Builds the world, runs the war, owns the camera.

static var inst: Game
static var skip_title := false
static var diff_idx := 1

const CITADEL_HP := 16000.0
const DIFFS := [
	{"name": "Squire", "mult": 0.75, "desc": "A gentler war. Foes are weaker."},
	{"name": "Knight", "mult": 1.0, "desc": "The intended challenge."},
	{"name": "Legend", "mult": 1.4, "desc": "The Dread Army at full strength."},
]
const FIRST_WAVE := 150.0
const MINIBOSSES := [
	{"name": "Gorm the Goblin King", "kind": "goblin", "scale": 2.3, "hp": 900.0, "tint": Color(1.0, 0.85, 0.35), "relic": {"name": "Goblin Hoard", "desc": "+35% gold from every coin", "stat": "gold"}},
	{"name": "Urzag the Warlord", "kind": "orc", "scale": 2.0, "hp": 1500.0, "tint": Color(1.0, 0.55, 0.45), "relic": {"name": "Warlord's Banner", "desc": "Camelot's armies +25% stronger", "stat": "army"}},
	{"name": "The Bone Lich", "kind": "skeleton", "scale": 2.0, "hp": 1300.0, "tint": Color(0.75, 0.55, 1.0), "relic": {"name": "Lich Phylactery", "desc": "-12% spell cooldowns", "stat": "cd"}},
	{"name": "Grukk the Troll King", "kind": "ogre", "scale": 1.6, "hp": 2600.0, "tint": Color(0.6, 0.95, 0.6), "relic": {"name": "Troll Heart", "desc": "+60 max HP", "stat": "hp"}},
	{"name": "Ogre Magus", "kind": "ogre", "scale": 1.6, "hp": 2800.0, "tint": Color(0.55, 0.7, 1.0), "relic": {"name": "Mana Font", "desc": "+20% spell damage", "stat": "dmg"}},
	{"name": "The Black Knight", "kind": "dark_knight", "scale": 1.5, "hp": 3200.0, "tint": Color(0.55, 0.55, 0.6), "relic": {"name": "Storm Crown", "desc": "Chain Lightning +2 bounces", "stat": "bounce"}},
]

var maze: Maze
var horde: Horde
var fx: FX
var nodes: ResNodes
var items: Items
var marks: Landmarks
var diff := 1.0
var lord_spawned := false
var dread_lord: Unit = null
var _shield_msg_t := 0.0
var fog: Fog
var lane_t := 10.0
var _hud_t := 0.0
var _pulse_t := 4.0
var garrison_caps: Array[Unit] = []
const VISION := 7.5
var castle: Castle
var hero: Hero
var hud: HUD
var sfx: Sfx
var camera: Camera3D
var sun: DirectionalLight3D
var world_env: WorldEnvironment
var citadel: Node3D
var citadel_gem: MeshInstance3D

var state := "title"      # title | play | levelup | paused | travel | over | won
var time := 0.0
var play_time := 0.0
var wave := 0
var wave_t := FIRST_WAVE
var spawn_queue: Array = []   # [delay, kind, power, elite]
var spawn_t := 0.0
var ally_queue: Array = []    # [delay, kind, power]
var ally_t := 0.0
var books := 0
var choice_title := "LEVEL UP!  Choose a blessing"
var minibosses: Array[Unit] = []
var kills := 0
var stats_delivered := 0.0
var shake := 0.0
var castle_hit_t := 0.0
var citadel_hp := CITADEL_HP
var citadel_flash := 0.0
var citadel_fire_t := 2.0
var citadel_guard_t := 5.0
var citadel_guards: Array[Unit] = []
var end_t := 0.0
var levelups := 0
var choices: Array = []
var cam_size := 19.0
var cam_focus := Vector3.ZERO
var mouse_held := false
var autopilot := false
var auto_choice_t := 0.0

var quality := 1            # 0 low, 1 medium, 2 high
var quality_auto := true
var fps_now := 60.0
var _fps_frames := 0
var _fps_time := 0.0
var _slow_windows := 0
var low_quality: bool:
	get: return quality == 0

var _hero_field_tile := -1
var _hero_dist := PackedInt32Array()
var _hero_next := PackedInt32Array()
var _hero_field_t := 0.0
var _click_tile := -1
var _click_next := PackedInt32Array()

# test / screenshot hooks (command line: -- --shots=DIR --auto --bench)
var shot_dir := ""
var shot_times: Array = []
var bench := false
var stress := false
var defend := false
var war := false
var ui_test := false
var endgame_test := false
var sim := false
var _sim_wave := -1
var _ui_step := 0
var _bench_frames := 0
var _bench_time := 0.0


func _ready() -> void:
	inst = self
	_parse_args()
	_setup_input()
	randomize()
	sfx = Sfx.new()
	add_child(sfx)
	var seed_v := randi()
	if shot_dir != "":
		seed_v = 12345
	diff = DIFFS[diff_idx].mult
	maze = Maze.new()
	maze.generate(seed_v)
	var world := Node3D.new()
	world.name = "World"
	add_child(world)
	maze.build_meshes(world)
	_setup_env()
	fx = FX.new()
	add_child(fx)
	castle = Castle.new()
	add_child(castle)
	horde = Horde.new()
	add_child(horde)
	nodes = ResNodes.new()
	add_child(nodes)
	hero = Hero.new()
	add_child(hero)
	items = Items.new()
	add_child(items)
	marks = Landmarks.new()
	add_child(marks)
	fx.setup(self)
	castle.setup(self)
	horde.setup(self)
	horde.camp_fields[-2] = maze.to_citadel_next
	nodes.setup(self)
	hero.setup(self)
	hero.position = maze.castle_pos + Vector3(-1.5, 0, -6.5)
	hero.position = maze.collide(hero.position, 0.42)
	hero.facing = PI * 1.25
	castle.fortify()
	hero.recompute()
	# The Circle of Avalon: four hooded adepts sworn to follow Merlin.
	for i in Horde.ADEPTS.size():
		horde.add_adept(Horde.ADEPTS[i], hero.position + Vector3(1.5 - i, 0, 2.0), i)
	_build_citadel()
	_spawn_camps()
	items.setup(self)
	marks.setup(self)
	_place_pocket_treasure()
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = cam_size
	camera.near = 1.0
	camera.far = 160.0
	add_child(camera)
	cam_focus = hero.position
	_update_camera(0.0, true)
	hud = HUD.new()
	var layer := CanvasLayer.new()
	add_child(layer)
	layer.add_child(hud)
	hud.setup(self)
	fog = Fog.new()
	var fog_layer := CanvasLayer.new()
	fog_layer.layer = 0
	add_child(fog_layer)
	fog_layer.add_child(fog)
	move_child(fog_layer, layer.get_index())
	_apply_quality()
	if sim:
		start()
	if (skip_title or shot_dir != "" or bench) and not ui_test:
		start()
	if (shot_dir != "" or bench) and not ui_test:
		# Test mode: early war, every spell unlocked, march on the citadel.
		wave_t = 6.0
		hero.weapons = {"lightning": 2, "bolts": 2, "fireball": 2, "nova": 2, "orbs": 2, "heal": 2}
		hero.max_hp = 600.0
		hero.hp = 600.0
	if stress:
		var gates := _citadel_gates()
		for k in 230:
			var t: Vector2i = gates[k % gates.size()]
			horde.spawn(["goblin", "orc", "skeleton"][k % 3], Maze.tile_center(t) + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)), "march", 1.0)
		var cg := _castle_gates()
		for k in 100:
			horde.spawn_soldier(["footman", "swordsman", "archer"][k % 3], Maze.tile_center(cg[k % cg.size()]) + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)), 1.0)
		hero.position = maze.citadel_pos + Vector3(14, 0, 14)
		hero.position = maze.collide(hero.position, 0.5)


func _parse_args() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			shot_dir = a.substr(8)
			shot_times = [1.0, 6.0, 14.0, 24.0, 40.0, 60.0, 90.0, 115.0, 140.0]
			if a.ends_with("quick"): shot_times = [10.0, 30.0]
			autopilot = true
		elif a.begins_with("--zoom="):
			cam_size = float(a.substr(7))
		elif a == "--sim":
			sim = true
			autopilot = true
			Engine.time_scale = 6.0
		elif a == "--endgame":
			endgame_test = true
			ui_test = true
		elif a == "--ui":
			ui_test = true
		elif a == "--war":
			war = true
			shot_times = [3.0, 40.0, 90.0, 150.0, 240.0]
			autopilot = true
		elif a == "--defend":
			defend = true
			shot_times = [5.0, 70.0, 85.0, 100.0, 120.0]
			autopilot = true
		elif a == "--auto":
			autopilot = true
		elif a == "--stress":
			bench = true
			autopilot = true
			stress = true
		elif a == "--bench":
			bench = true
			autopilot = true
	if ui_test:
		autopilot = false


func _setup_input() -> void:
	var binds := {
		"move_up": [KEY_W, KEY_UP], "move_down": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT],
	}
	for action in binds:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			for k in binds[action]:
				var ev := InputEventKey.new()
				ev.physical_keycode = k
				InputMap.action_add_event(action, ev)


func _setup_env() -> void:
	world_env = WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.09, 0.11, 0.08)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.66, 0.78)
	env.ambient_light_energy = 0.75
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	world_env.environment = env
	add_child(world_env)
	sun = DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-52.0), deg_to_rad(-30.0), 0)
	sun.light_color = Color(1.0, 0.93, 0.8)
	sun.light_energy = 1.05
	sun.shadow_enabled = false
	add_child(sun)


func _build_citadel() -> void:
	citadel = Node3D.new()
	citadel.position = maze.citadel_pos
	add_child(citadel)
	var m := MeshInstance3D.new()
	m.mesh = Models.citadel_mesh()
	Geo.apply(m)
	citadel.add_child(m)
	citadel_gem = MeshInstance3D.new()
	citadel_gem.mesh = Models.citadel_gem()
	Geo.apply(citadel_gem, true)
	citadel_gem.position = Vector3(0, 10.5, 0)
	citadel.add_child(citadel_gem)


func _spawn_camps() -> void:
	var cid := 0
	for room: Rect2i in maze.rooms:
		var c := room.get_center()
		if absi(c.x - maze.castle_tile.x) < 11 and absi(c.y - maze.castle_tile.y) < 11:
			continue
		var rg := maze.region[Maze.idx(c)]
		var count := 6 + int(rg * 8.0) + randi_range(0, 3)
		var power := 1.0 + rg * 1.4
		var field: Array = maze.field_from(PackedInt32Array([Maze.idx(maze.random_floor_in(room))]), 500)
		horde.camp_fields[cid] = field[1]
		for k in count:
			var t := maze.random_floor_in(room)
			if t.x < 0:
				continue
			var kind := "goblin"
			var roll := randf()
			if rg < 0.35:
				kind = "goblin" if roll < 0.8 else "orc"
			elif rg < 0.65:
				kind = "goblin" if roll < 0.4 else ("orc" if roll < 0.75 else "skeleton")
			else:
				kind = "orc" if roll < 0.45 else ("skeleton" if roll < 0.85 else "ogre")
			var elite := k == 0 and randf() < 0.25 + rg * 0.4
			var u := horde.spawn(kind, Maze.tile_center(t) + Vector3(randf_range(-0.8, 0.8), 0, randf_range(-0.8, 0.8)), "camp", power, elite)
			if u != null:
				u.camp_id = cid
		cid += 1
	_spawn_minibosses()
	_spawn_garrisons()
	_spawn_pocket_lurkers()


## Dread garrisons squat on the Royal Roads and the Kingsroad: fast routes,
## but only for a Merlin strong enough to break them.
func _spawn_garrisons() -> void:
	var kinds := ["orc", "orc", "wolf", "skeleton", "shaman", "orc", "skeleton", "wolf", "ogre", "necro", "orc"]
	for i in maze.garrisons.size():
		var gt: Vector2i = maze.garrisons[i][0]
		if not maze.is_open_t(gt):
			continue
		var gp := Maze.tile_center(gt)
		var rg := maze.region[Maze.idx(gt)]
		var power := 2.6 + rg * 2.4
		var cid := 200 + i
		horde.camp_fields[cid] = maze.field_from(PackedInt32Array([Maze.idx(gt)]), 400)[1]
		for k in kinds.size():
			var p := maze.collide(gp + Vector3(randf_range(-4, 4), 0, randf_range(-4, 4)), 0.6)
			var u := horde.spawn(kinds[k], p, "camp", power, false)
			if u != null:
				u.camp_id = cid
				u.home = p
		var cap := horde.spawn("dark_knight", gp, "camp", power * 0.55, true)
		if cap != null:
			cap.camp_id = cid
			cap.title = "Garrison Captain — %s" % maze.garrisons[i][1]
			cap.xp = 30
			garrison_caps.append(cap)
		var deco := MeshInstance3D.new()
		deco.mesh = Models.dread_camp_mesh()
		Geo.apply(deco)
		deco.position = gp
		add_child(deco)


## A few lurkers haunt every maze pocket.
func _spawn_pocket_lurkers() -> void:
	for k in maze.pockets.size():
		var pk: Dictionary = maze.pockets[k]
		var r: Rect2i = pk.rect
		var rt: Vector2i = pk.reward
		var rg := maze.region[Maze.idx(rt)]
		var cid := 300 + k
		horde.camp_fields[cid] = maze.field_from(PackedInt32Array([Maze.idx(rt)]), 400)[1]
		for n in 6 + int(rg * 6.0):
			var t := maze.random_floor_in(r)
			if t.x < 0:
				continue
			var kind: String = ["goblin", "wolf", "skeleton"][randi() % 3] if rg > 0.4 else ["goblin", "goblin", "wolf"][randi() % 3]
			var u := horde.spawn(kind, Maze.tile_center(t), "camp", 1.0 + rg * 1.4, n == 0 and randf() < 0.5)
			if u != null:
				u.camp_id = cid


## Treasure chests at the heart of "chest" pockets, and a hoard at each hub.
func _place_pocket_treasure() -> void:
	for pk in maze.pockets:
		if pk.kind != "chest":
			continue
		var rt: Vector2i = pk.reward
		var rg := maze.region[Maze.idx(rt)]
		items.drop(Items.make(2 + int(rg * 8.0), 3 if randf() < 0.3 + rg * 0.3 else 2), Maze.tile_center(rt))
	for h: Vector2i in maze.hubs:
		items.drop(Items.make(7, 3), Maze.tile_center(h))


## Six named mini-bosses lair in glades spread across the maze, toughest furthest out.
func _spawn_minibosses() -> void:
	var cands: Array = []
	var cid := 0
	for room: Rect2i in maze.rooms:
		var c := room.get_center()
		if not (absi(c.x - maze.castle_tile.x) < 11 and absi(c.y - maze.castle_tile.y) < 11):
			cands.append([maze.region[Maze.idx(c)], room, cid])
			cid += 1
	cands.sort_custom(func(a, b): return a[0] < b[0])
	if cands.is_empty():
		return
	var hub_c: Array = []
	var glade_c: Array = []
	for c2 in cands:
		var at_hub := false
		for h: Vector2i in maze.hubs:
			if (c2[1] as Rect2i).has_point(h):
				at_hub = true
		if at_hub:
			hub_c.append(c2)
		else:
			glade_c.append(c2)
	var order := [[0, -1], [1, -1], [2, -1], [3, 0], [4, 1], [5, -1]]
	var gi := 0
	for oi in order:
		var i: int = oi[0]
		var pick: Array
		if oi[1] >= 0 and oi[1] < hub_c.size():
			pick = hub_c[oi[1]]
		else:
			pick = glade_c[mini(glade_c.size() - 1, int(float(gi) / 4.0 * glade_c.size() + glade_c.size() * 0.15))]
			gi += 1
		var room: Rect2i = pick[1]
		var def: Dictionary = MINIBOSSES[i]
		var t := maze.random_floor_in(room)
		if t.x < 0:
			continue
		var u := horde.spawn(def.kind, Maze.tile_center(t), "camp", 1.0, false)
		if u == null:
			continue
		u.mini = i
		u.title = def.name
		u.tint = def.tint
		u.scale = def.scale
		u.r *= def.scale * 0.8
		u.max_hp = def.hp * (1.0 + pick[0] * 0.6) * diff
		u.hp = u.max_hp
		u.dmg *= 2.2
		u.xp = 40
		u.gold_chance = 1.0
		u.camp_id = pick[2]
		u.speed *= 0.85
		minibosses.append(u)


## Pick a difficulty on the title screen (rescales the Dread host already placed).
func set_difficulty(i: int) -> void:
	var r: float = DIFFS[i].mult / diff
	diff_idx = i
	diff = DIFFS[i].mult
	for u in horde.enemies:
		u.max_hp *= r
		u.hp *= r
		u.dmg *= 1.0 + (r - 1.0) * 0.6


func start() -> void:
	state = "play"
	hud.message("Camelot is defended — the adventure is yours. Follow the trails to treasure. Right-click to Blink.", 8.0, Color(1, 0.9, 0.6))


# ------------------------------------------------------------- main loop

func _process(delta: float) -> void:
	var dt := minf(delta, 0.05)
	time += dt
	_track_fps(delta)
	if state == "play":
		play_time += dt
		_update_world(dt)
		if books > 0:
			state = "levelup"
			choice_title = "SPELLBOOK FOUND!  Learn a spell"
			choices = hero.roll_choices(true)
			auto_choice_t = 0.6
		elif levelups > 0:
			state = "levelup"
			choice_title = "LEVEL UP!  Choose a blessing"
			choices = hero.roll_choices()
			auto_choice_t = 0.6
	elif state == "levelup":
		if autopilot:
			auto_choice_t -= dt
			if auto_choice_t <= 0.0:
				choose(0)
	elif state == "over" or state == "won":
		end_t += dt
		fx.update(dt)
		if state == "won":
			_citadel_collapse(dt)
	if state == "play" and mouse_held and hero.alive and not autopilot:
		var gp := _mouse_ground()
		if gp != Vector3.INF:
			hero.move_target = gp
	var t := Time.get_ticks_usec()
	horde.render()
	t = _p("r_horde", t)
	fx.render()
	t = _p("r_fx", t)
	nodes.render()
	items.render()
	_animate_citadel(dt)
	_update_camera(dt, false)
	fog.track(camera, (hero.position if hero.alive else maze.castle_pos) + Vector3(0, 0.6, 0), VISION, time)
	# The HUD keeps its last drawing between redraws; 30 per second is plenty.
	_hud_t -= delta
	if _hud_t <= 0.0 or state != "play" or fps_now < 40.0:
		_hud_t = 1.0 / 30.0
		hud.queue_redraw()
	t = _p("r_misc", t)
	_shots()


var prof := {}
func _p(key: String, t0: int) -> int:
	var t1 := Time.get_ticks_usec()
	prof[key] = prof.get(key, 0) + (t1 - t0)
	return t1


func _update_world(dt: float) -> void:
	var t := Time.get_ticks_usec()
	_update_hero_field(dt)
	t = _p("field", t)
	hero.update(dt)
	t = _p("hero", t)
	if hero.alive:
		_explore(hero.position)
	castle.update(dt)
	t = _p("castle", t)
	horde.update(dt)
	t = _p("horde", t)
	nodes.update(dt)
	items.update(dt)
	marks.update(dt)
	fx.update(dt)
	t = _p("fx", t)
	_update_waves(dt)
	_update_citadel(dt)
	castle_hit_t = maxf(0.0, castle_hit_t - dt)


func _explore(p: Vector3) -> void:
	var t := Maze.tile_of(p)
	for dy in range(-4, 5):
		for dx in range(-4, 5):
			if dx * dx + dy * dy > 20:
				continue
			var x := t.x + dx
			var y := t.y + dy
			if x >= 0 and y >= 0 and x < Maze.G and y < Maze.G:
				var i := y * Maze.G + x
				if maze.explored[i] == 0:
					maze.explored[i] = 1
					hud.new_tiles.append(i)


# ------------------------------------------------------------- flow fields

func _update_hero_field(dt: float) -> void:
	_hero_field_t -= dt
	var ti := Maze.idx(Maze.tile_of(hero.position))
	if ti != _hero_field_tile and _hero_field_t <= 0.0 and maze.is_open_i(ti):
		_hero_field_tile = ti
		_hero_field_t = 0.2
		var res := maze.field_from(PackedInt32Array([ti]), 320)
		_hero_dist = res[0]
		_hero_next = res[1]


## Path distance (x10 per tile) from p to the hero, or a huge number.
func hero_dist(p: Vector3) -> int:
	if _hero_dist.is_empty() or not hero.alive:
		return 1 << 30
	return _hero_dist[Maze.idx(Maze.tile_of(p))]


func hero_flow(p: Vector3) -> Vector3:
	if _hero_next.is_empty():
		return Vector3.ZERO
	return maze.flow_dir(p, _hero_next)


func click_flow(p: Vector3) -> Vector3:
	var t := Maze.tile_of(hero.move_target)
	if not maze.is_open_t(t):
		return Vector3.ZERO
	var ti := Maze.idx(t)
	if ti != _click_tile:
		_click_tile = ti
		_click_next = maze.field_from(PackedInt32Array([ti]), 900)[1]
	return maze.flow_dir(p, _click_next)


## Test autopilot: fight toward the citadel, go home to deliver when full.
func autopilot_dir() -> Vector3:
	if war:
		return Vector3.ZERO
	if sim:
		# Stay home and let the steward build.
		var home2 := maze.castle_pos + Vector3(-2, 0, -7)
		var to3 := home2 - hero.position
		to3.y = 0
		return to3.normalized() if to3.length() > 1.0 else Vector3.ZERO
	if defend:
		if play_time < 3.0:
			castle.gold = 3000.0
		var foe2 := horde.nearest_enemy(hero.position, 6.0)
		if foe2 != null:
			return Vector3.ZERO
		var home := maze.castle_pos + Vector3(-2, 0, -7)
		var to2 := home - hero.position
		to2.y = 0
		return to2.normalized() if to2.length() > 1.0 else Vector3.ZERO
	if shot_dir != "" or bench:
		var foe := horde.nearest_enemy(hero.position, 9.0)
		if foe != null and hero.hp > hero.max_hp * 0.3:
			var to := foe.pos - hero.position
			to.y = 0
			if to.length() < 2.5:
				return Vector3.ZERO
			var hf := maze.flow_dir(hero.position, maze.to_citadel_next)
			return to.normalized() if maze.line_clear(hero.position, foe.pos) else hf
		return maze.flow_dir(hero.position, maze.to_citadel_next)
	var full := hero.carry_total() >= hero.carry_cap * 0.9
	if full or hero.hp < hero.max_hp * 0.35:
		if (hero.position - maze.castle_pos).length() < 7.5:
			return Vector3.ZERO
		return maze.flow_dir(hero.position, maze.to_castle_next)
	if hero.gather_node != null:
		return Vector3.ZERO
	var near := nodes.nearest_harvestable(hero.position)
	if near != null:
		return Vector3.ZERO
	return maze.flow_dir(hero.position, maze.to_citadel_next)


# ------------------------------------------------------------- the war

func _update_waves(dt: float) -> void:
	wave_t -= dt
	if wave_t <= 0.0:
		wave += 1
		wave_t = maxf(80.0, 120.0 - wave * 2.0)
		_queue_wave()
	if not ally_queue.is_empty():
		ally_t -= dt
		if ally_t <= 0.0:
			var a: Array = ally_queue.pop_front()
			ally_t = a[0]
			var cg := _castle_gates()
			var ap: Vector3 = Maze.tile_center(cg[randi() % cg.size()]) + Vector3(randf_range(-0.8, 0.8), 0, randf_range(-0.8, 0.8))
			horde.spawn_soldier(a[1], ap, a[2])
	_update_lane(dt)
	if not spawn_queue.is_empty():
		spawn_t -= dt
		if spawn_t <= 0.0:
			var s: Array = spawn_queue.pop_front()
			spawn_t = s[0]
			var gates := _citadel_gates()
			var p: Vector3 = Maze.tile_center(gates[randi() % gates.size()])
			p += Vector3(randf_range(-0.8, 0.8), 0, randf_range(-0.8, 0.8))
			horde.spawn(s[1], p, "march", s[2], s[3])


## The War Lane never sleeps: both sides feed fresh squads into it, so there
## is always a battle raging between the two fortresses.
func _update_lane(dt: float) -> void:
	lane_t -= dt
	if lane_t > 0.0:
		return
	lane_t = 6.0
	var dm := 0
	for u in horde.enemies:
		if u.alive and u.mode == "march":
			dm += 1
	var power := (1.0 + 0.14 * wave + 0.004 * wave * wave) * 0.8
	# Tug of war: the side being pushed back sends more, and tougher, troops.
	var f := lane_front()
	var k := clampf((f - 0.5) * 2.2, -1.0, 1.0) if f >= 0.0 else 0.0
	var d_n := 4 + int(maxf(0.0, k) * 5.0)
	var s_n := 4 + int(maxf(0.0, -k) * 5.0)
	var d_pow := power * (1.0 + maxf(0.0, k) * 1.6)
	var s_pow := power * 0.95 * (1.0 + maxf(0.0, -k) * 1.6)
	if dm < 60:
		var gates := _citadel_gates()
		for i in d_n:
			horde.spawn(_wave_kind(), Maze.tile_center(gates[randi() % gates.size()]) + Vector3(randf_range(-0.8, 0.8), 0, randf_range(-0.8, 0.8)), "march", d_pow, false)
	if horde.soldiers.size() < 60:
		var cg := _castle_gates()
		for i in s_n:
			horde.spawn_soldier(Horde.MIRROR[_wave_kind()], Maze.tile_center(cg[randi() % cg.size()]) + Vector3(randf_range(-0.8, 0.8), 0, randf_range(-0.8, 0.8)), s_pow * castle.army_power())


## Where the War Lane battle stands: mean progress of every marching unit,
## 0 = at Camelot's gate, 1 = at the Citadel's. -1 when the lane is empty.
func lane_front() -> float:
	var total: float = maze.to_castle_dist[Maze.idx(maze.citadel_tile + Vector2i(3, 3))]
	var sum := 0.0
	var n := 0
	for u in horde.enemies:
		if u.alive and u.mode == "march":
			sum += clampf(maze.to_castle_dist[u.tile] / total, 0.0, 1.0)
			n += 1
	for u in horde.soldiers:
		if u.alive:
			sum += clampf(maze.to_castle_dist[u.tile] / total, 0.0, 1.0)
			n += 1
	return sum / n if n > 0 else -1.0


## The Dread Army grows through eras: wolves, then orcs and shamans, then the
## undead and their necromancers, then ogres and Dark Knights.
func _wave_kind() -> String:
	var table := [["goblin", 70.0], ["wolf", 30.0]]
	if wave >= 3: table.append(["orc", 35.0])
	if wave >= 4: table.append(["shaman", 10.0])
	if wave >= 6: table.append(["skeleton", 30.0])
	if wave >= 8: table.append(["necro", 7.0])
	if wave >= 10: table[0][1] = 30.0
	var total := 0.0
	for e in table: total += e[1]
	var r := randf() * total
	for e in table:
		r -= e[1]
		if r <= 0.0:
			return e[0]
	return "goblin"


func _queue_wave() -> void:
	var n := mini(8 + int(wave * 4.5), 110)
	var power := 1.0 + 0.14 * wave + 0.004 * wave * wave
	var boss := wave % 5 == 0
	for k in n:
		spawn_queue.append([0.25, _wave_kind(), power, randf() < 0.04 * wave])
	if wave >= 5:
		for k in 1 + (wave - 5) / 4:
			spawn_queue.append([0.4, "ogre", power, false])
	if boss:
		spawn_queue.append([0.5, "dark_knight", power, false])
	# Camelot answers with a mirrored host, so the two armies meet mid-maze.
	var apower := power * 0.85 * castle.army_power()
	for s in spawn_queue:
		ally_queue.append([s[0], Horde.MIRROR[s[1]], apower * (1.6 if s[3] else 1.0)])
	for k in castle.level("warcamp"):
		ally_queue.append([0.3, "swordsman" if k % 2 == 0 else "archer", apower])
	if wave % 4 == 0:
		_refill_camps()
	var msg := "Wave %d — the armies march! Camelot's host rides to meet them." % wave
	if boss:
		msg = "Wave %d — a Dark Knight leads the host!" % wave
	hud.message(msg, 4.5, Color(1.0, 0.45, 0.35))
	sfx.play("horn", 2.0, 0.5, 0.0)


func _refill_camps() -> void:
	var alive_by_camp := {}
	for u in horde.enemies:
		if u.mode == "camp":
			alive_by_camp[u.camp_id] = alive_by_camp.get(u.camp_id, 0) + 1
	var cid := 0
	for room: Rect2i in maze.rooms:
		var c := room.get_center()
		if absi(c.x - maze.castle_tile.x) < 11 and absi(c.y - maze.castle_tile.y) < 11:
			continue
		if alive_by_camp.get(cid, 0) == 0:
			var rg := maze.region[Maze.idx(c)]
			for k in 2 + int(rg * 3.0):
				var t := maze.random_floor_in(room)
				if t.x < 0:
					continue
				var kind: String = ["goblin", "orc", "skeleton"][randi() % 3] if rg > 0.3 else "goblin"
				var u := horde.spawn(kind, Maze.tile_center(t), "camp", 1.0 + rg * 1.4 + wave * 0.08, false)
				if u != null:
					u.camp_id = cid
		cid += 1


## Open tiles just outside Camelot on the maze side, where its soldiers muster.
func _castle_gates() -> Array:
	var out := []
	var c := maze.castle_tile
	for dy in range(-3, 4):
		for dx in range(-3, 4):
			if absi(dx) == 3 or absi(dy) == 3:
				var t := c + Vector2i(dx, dy)
				if maze.is_open_t(t) and (dx < 0 or dy < 0):
					out.append(t)
	if out.is_empty():
		out.append(c + Vector2i(-3, -2))
	return out


func _citadel_gates() -> Array:
	var out := []
	var c := maze.citadel_tile
	for dy in range(-3, 4):
		for dx in range(-3, 4):
			if absi(dx) == 3 or absi(dy) == 3:
				var t := c + Vector2i(dx, dy)
				if maze.is_open_t(t) and (dx > 0 or dy > 0):
					out.append(t)
	if out.is_empty():
		out.append(c + Vector2i(3, 3))
	return out


func _update_citadel(dt: float) -> void:
	if citadel_hp <= 0.0:
		return
	citadel_flash = maxf(0.0, citadel_flash - dt)
	citadel_hp = minf(CITADEL_HP, citadel_hp + dt * 3.0)
	if not lord_spawned and citadel_hp < CITADEL_HP * 0.5:
		_spawn_dread_lord()
	var d := (hero.position - maze.citadel_pos).length()
	# The citadel's dark bolts also rain on Camelot's soldiers at its gates.
	var sold := horde.nearest_friend(maze.citadel_pos, 15.0)
	if sold != null and not (hero.alive and d < 17.0):
		citadel_fire_t -= dt
		if citadel_fire_t <= 0.0:
			citadel_fire_t = 0.9
			fx.shoot("dark", maze.citadel_pos + Vector3(0, 6.0, 0), sold.pos + Vector3(0, 0.8, 0), 12.0, 24.0 + wave * 2.0, 1)
	# Dread Pulse: the Citadel scours soldiers massing at its gate.
	_pulse_t -= dt
	if _pulse_t <= 0.0:
		_pulse_t = 4.0
		var hit := horde.friends_near(maze.citadel_pos, 13.0)
		var n_hit := 0
		for f2: Unit in hit:
			if f2.mode == "march":
				horde.hurt_friend(f2, 26.0 + wave * 3.0)
				n_hit += 1
		if n_hit > 0:
			fx.ring(maze.citadel_pos, 2.0, 13.0, Color(0.85, 0.15, 0.25), 0.6, 0.2)
	var hero_near := hero.alive and d < 17.0
	if hero_near or sold != null:
		if hero_near:
			citadel_fire_t -= dt
		if hero_near and citadel_fire_t <= 0.0:
			citadel_fire_t = maxf(0.9, 1.8 - wave * 0.05)
			var src := maze.citadel_pos + Vector3(0, 6.0, 0)
			var aim := hero.position + hero.vel * 0.4 + Vector3(0, 0.8, 0)
			fx.shoot("dark", src, aim, 12.0, 12.0 + wave * 1.2, 1)
		citadel_guard_t -= dt
		if citadel_guard_t <= 0.0:
			citadel_guard_t = 7.0
			var i := citadel_guards.size() - 1
			while i >= 0:
				if not citadel_guards[i].alive:
					citadel_guards.remove_at(i)
				i -= 1
			if citadel_guards.size() < 10:
				var gates := _citadel_gates()
				for k in 2:
					var kind := "orc" if randf() < 0.6 else "skeleton"
					var u := horde.spawn(kind, Maze.tile_center(gates[randi() % gates.size()]), "camp", 1.6 + wave * 0.1, false)
					if u != null:
						u.camp_id = -2
						u.home = maze.citadel_pos + Vector3(6, 0, 6)
						u.aggro = true
						citadel_guards.append(u)


func _spawn_dread_lord() -> void:
	lord_spawned = true
	var u := horde.spawn("dark_knight", maze.citadel_pos + Vector3(6.5, 0, 6.5), "camp", 1.0, false)
	if u == null:
		return
	u.title = "THE DREAD LORD"
	u.tint = Color(0.5, 0.32, 0.65)
	u.scale = 2.4
	u.r = 1.2
	u.max_hp = 9000.0 * diff
	u.hp = u.max_hp
	u.dmg = 55.0 * diff
	u.speed = 3.0
	u.xp = 150
	u.camp_id = -2
	u.home = maze.citadel_pos + Vector3(6, 0, 6)
	u.aggro = true
	dread_lord = u
	shake = 0.5
	fx.ring(u.pos, 0.5, 10.0, Color(0.7, 0.3, 1.0), 1.0, 0.2)
	fx.burst(u.pos + Vector3(0, 2, 0), Color(0.6, 0.25, 0.9), 40, 8.0, 0.3, 8.0)
	hud.message("THE DREAD LORD RISES FROM THE CITADEL!", 6.0, Color(0.85, 0.5, 1.0))
	sfx.play("horn", 6.0, 0.0, 0.0)


func damage_citadel(amount: float, show := true) -> void:
	if citadel_hp <= 0.0 or state != "play" or amount <= 0.0:
		return
	if marks.shield_up:
		if show and time - _shield_msg_t > 0.6:
			_shield_msg_t = time
			fx.number(maze.citadel_pos + Vector3(randf_range(-2, 2), 7.0, randf_range(-2, 2)), "SHIELDED", Color(1, 0.4, 0.35))
		return
	citadel_hp -= amount
	citadel_flash = 0.15
	if show:
		fx.number(maze.citadel_pos + Vector3(randf_range(-2, 2), 6.0, randf_range(-2, 2)), str(int(round(amount))), Color(1, 0.6, 0.5))
	if citadel_hp <= 0.0:
		citadel_hp = 0.0
		state = "won"
		end_t = 0.0
		hud.message("The Dread Citadel has fallen! Avalon is saved.", 8.0, Color(1, 0.9, 0.5))
		sfx.play("explode", 6.0, 0.0, 0.0)
		sfx.play("levelup", 2.0, 0.0, 0.0)
		# The army breaks and flees.
		for u in horde.enemies:
			if u.alive:
				horde._kill(u)


func _animate_citadel(dt: float) -> void:
	if citadel_hp > 0.0:
		citadel_gem.position.y = 10.5 + sin(time * 1.5) * 0.4
		citadel_gem.rotation.y += dt * 0.8
		var s := 1.0 + (0.15 if citadel_flash > 0.0 else 0.0)
		citadel_gem.scale = Vector3(s, s, s)


func _citadel_collapse(dt: float) -> void:
	if end_t < 3.0:
		citadel.position.y = -end_t * 1.6
		citadel.rotation.z = sin(end_t * 25.0) * 0.02
		if randf() < 0.6:
			var p := maze.citadel_pos + Vector3(randf_range(-4, 4), randf_range(1, 6), randf_range(-4, 4))
			fx.burst(p, Color(1.0, 0.45, 0.15) if randf() < 0.5 else Color(0.3, 0.25, 0.28), 6, 6.0, 0.25, 6.0)
		shake = 0.25
	citadel_gem.visible = end_t < 1.0


# ------------------------------------------------------------- events

func on_enemy_killed(u: Unit) -> void:
	kills += 1
	# The War Lane is a battle of attrition: its fallen leave no gold or soul gems.
	if u.mode == "march":
		return
	fx.drop("gem", u.pos, u.xp)
	if u.structure:
		marks.on_ward_destroyed(u)
		for k in 12:
			fx.drop("coin", u.pos, 20 + wave)
		items.roll_drop(u.pos, 1.0, 2.0, 3)
		return
	if u == dread_lord:
		hud.message("The Dread Lord is vanquished! Finish the Citadel!", 6.0, Color(1, 0.9, 0.5))
		for k in 20:
			fx.drop("coin", u.pos, 30 + wave)
		items.roll_drop(u.pos, 1.0, 2.0, 3)
		items.roll_drop(u.pos, 1.0, 2.0, 3)
		shake = 0.5
		return
	# Loot: rare from the rank and file, likely from elites, assured from bosses.
	if u.mini >= 0:
		items.roll_drop(u.pos, 1.0, 1.5, 2)
	elif u.boss:
		items.roll_drop(u.pos, 0.7, 1.0, 1)
	elif u.elite:
		items.roll_drop(u.pos, 0.3, 0.5)
	else:
		items.roll_drop(u.pos, 0.02, 0.0)
	if randf() < u.gold_chance:
		var base: int = {"goblin": 3, "orc": 6, "skeleton": 4, "ogre": 16, "dark_knight": 40, "wolf": 4, "shaman": 7, "necro": 10}.get(u.kind, 3)
		var coins := 1
		if u.elite:
			coins = 3
		if u.boss:
			coins = 5
		if u.mini >= 0:
			coins = 10
		for k in coins:
			fx.drop("coin", u.pos, base + randi_range(0, base / 2) + wave / 2)
	if u.mini >= 0:
		var r: Dictionary = MINIBOSSES[u.mini].relic
		hero.apply_relic(r)
		shake = 0.35
		fx.ring(u.pos, 0.5, 6.0, Color(1, 0.85, 0.4), 0.8, 0.2)
		fx.burst(u.pos + Vector3(0, 1, 0), Color(1, 0.85, 0.4), 30, 7.0, 0.2, 6.0)
		hud.message("%s is slain!  Relic: %s — %s" % [u.title, r.name, r.desc], 6.0, Color(1, 0.85, 0.4))
		sfx.play("levelup", 2.0, 0.0, 0.0)
		return
	var pc := 0.015
	if u.elite:
		pc = 0.25
	if u.boss:
		pc = 1.0
	if randf() < pc:
		fx.drop("potion", u.pos)
	if u.boss:
		shake = 0.3
		hud.message("The Dark Knight is slain!", 3.0, Color(1, 0.85, 0.4))


func on_hero_died(lost: float) -> void:
	shake = 0.3
	var msg := "Merlin has fallen! Returning to Camelot..."
	if lost >= 1.0:
		msg += "  (%d gold ore lost)" % int(lost)
	hud.message(msg, 5.0, Color(1, 0.4, 0.35))


func on_castle_destroyed() -> void:
	state = "over"
	end_t = 0.0
	shake = 0.4
	fx.burst(maze.castle_pos + Vector3(0, 5, 0), Color(1.0, 0.5, 0.2), 40, 8.0, 0.3, 8.0)
	hud.message("Camelot has fallen.", 8.0, Color(1, 0.35, 0.3))
	sfx.play("explode", 6.0, 0.0, 0.0)
	sfx.play("horn", 0.0, 0.0, 0.0)


func queue_levelup() -> void:
	levelups += 1
	sfx.play("levelup", 0.0, 0.3, 0.0)
	fx.ring(hero.position, 0.3, 3.5, Color(0.5, 0.9, 1.0), 0.6, 0.2)
	fx.sparkle(hero.position, Color(0.6, 0.9, 1.0), 14, 0.12)


func on_spellbook() -> void:
	books += 1
	sfx.play("levelup", 2.0, 0.0, 0.0)


func choose(i: int) -> void:
	if state != "levelup" or i < 0 or i >= choices.size():
		return
	hero.apply_choice(choices[i])
	if books > 0:
		books -= 1
	else:
		levelups -= 1
	# Return to play; the next pending choice (if any) opens on the next frame.
	state = "play"


func at_castle() -> bool:
	return hero.alive and (hero.position - maze.castle_pos).length() < Castle.DELIVER_R + 1.0


func restart() -> void:
	skip_title = true
	get_tree().reload_current_scene()


# ------------------------------------------------------------- input / camera

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT:
			if state == "play":
				hero.blink(_mouse_ground())
			return
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				if hud.click(mb.position):
					return
				if state == "travel":
					state = "play"
					return
				if state == "title":
					start()
					return
				if (state == "over" or state == "won") and end_t > 1.5:
					restart()
					return
				if state == "play":
					mouse_held = true
					var gp := _mouse_ground()
					if gp != Vector3.INF:
						hero.move_target = gp
						fx.ring(gp, 0.1, 0.6, Color(0.6, 0.9, 0.5), 0.3, 0.08)
			else:
				mouse_held = false
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			cam_size = maxf(14.0, cam_size - 1.5)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			cam_size = minf(36.0, cam_size + 1.5)
	elif event is InputEventKey and event.pressed and not event.echo:
		var k := (event as InputEventKey).physical_keycode
		if state == "title":
			if k >= KEY_1 and k <= KEY_3:
				set_difficulty(k - KEY_1)
			start()
			return
		if state == "travel":
			if k >= KEY_1 and k <= KEY_9:
				travel_to(k - KEY_1)
			elif k == KEY_T or k == KEY_ESCAPE:
				state = "play"
			return
		if state == "levelup":
			if k >= KEY_1 and k <= KEY_3:
				choose(k - KEY_1)
			return
		if (state == "over" or state == "won") and end_t > 1.5 and (k == KEY_ENTER or k == KEY_SPACE):
			restart()
			return
		match k:
			KEY_P, KEY_ESCAPE:
				if state == "play":
					state = "paused"
				elif state == "paused":
					state = "play"
			KEY_F:
				var fs := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if fs else DisplayServer.WINDOW_MODE_FULLSCREEN)
			KEY_G:
				quality = (quality + 1) % 3
				quality_auto = false
				_apply_quality()
				hud.message("Graphics: " + ["Low", "Medium", "High"][quality], 1.5)
			KEY_SPACE, KEY_Q:
				if state == "play":
					hero.drink_potion()
			KEY_N:
				toggle_mute()
			KEY_M:
				hud.big_map = not hud.big_map
			KEY_E:
				if state == "play":
					hero.blink(_mouse_ground())
			KEY_T:
				if state == "play":
					if marks.waypoint_here():
						state = "travel"
					else:
						hud.message("Stand at Camelot or a Ley Shrine you hold to travel.", 2.0, Color(1, 0.8, 0.5))


## Waypoint destinations: Camelot first, then every shrine Camelot holds.
func travel_targets() -> Array:
	var out := [["Camelot", maze.castle_pos + Vector3(-1.5, 0, -6.5)]]
	for s in marks.owned_shrines():
		out.append([s.name, s.pos + Vector3(2.6, 0, 2.6)])
	return out


func travel_to(i: int) -> void:
	var t := travel_targets()
	if i < 0 or i >= t.size():
		return
	fx.ring(hero.position, 0.3, 3.0, Color(0.5, 0.8, 1.0), 0.5, 0.2)
	fx.sparkle(hero.position, Color(0.6, 0.85, 1.0), 16, 0.12)
	hero.position = maze.collide(t[i][1], 0.42)
	hero.move_target = Vector3.INF
	hero.vel = Vector3.ZERO
	fx.ring(hero.position, 3.0, 0.3, Color(0.5, 0.8, 1.0), 0.5, 0.2)
	sfx.play("zap", 0.0, 0.0, 0.0)
	_update_camera(0.0, true)
	state = "play"


func choose_difficulty(i: int) -> void:
	set_difficulty(i)
	start()


func toggle_mute() -> void:
	sfx.toggle()
	hud.message("Sound off" if Sfx.muted else "Sound on", 1.2)


func _mouse_ground() -> Vector3:
	var mp := get_viewport().get_mouse_position()
	var o := camera.project_ray_origin(mp)
	var d := camera.project_ray_normal(mp)
	if absf(d.y) < 1e-4:
		return Vector3.INF
	var t := -o.y / d.y
	if t < 0.0:
		return Vector3.INF
	return o + d * t


func _update_camera(dt: float, snap: bool) -> void:
	var target := hero.position if hero.alive else maze.castle_pos
	if war:
		# Follow the front line: the soldier furthest along the road to the citadel.
		var best := INF
		for s in horde.soldiers:
			if s.alive:
				var d: int = maze.to_citadel_dist[Maze.idx(Maze.tile_of(s.pos))]
				if d < best:
					best = d
					target = s.pos
	if state == "won" and end_t < 4.0:
		target = maze.citadel_pos
	if snap:
		cam_focus = target
	else:
		cam_focus = cam_focus.lerp(target, minf(1.0, dt * 5.0))
	camera.size = lerpf(camera.size, cam_size, minf(1.0, dt * 6.0)) if not snap else cam_size
	shake = maxf(0.0, shake - dt)
	var off := Vector3.ZERO
	if shake > 0.0:
		off = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)) * shake * 0.6
	# Isometric: yaw 45 degrees, pitch ~55 degrees down.
	var pitch := deg_to_rad(55.0)
	var dist := 60.0
	var back := Vector3(1, 0, 1).normalized() * cos(pitch) * dist + Vector3(0, sin(pitch) * dist, 0)
	camera.position = cam_focus + off + back
	camera.look_at(cam_focus + off, Vector3.UP)


# ------------------------------------------------------------- performance

func _track_fps(delta: float) -> void:
	_fps_frames += 1
	_fps_time += delta
	if _fps_time >= 1.0:
		fps_now = _fps_frames / _fps_time
		_fps_frames = 0
		_fps_time = 0.0
		if quality_auto and state == "play" and time > 4.0 and quality > 0:
			if fps_now < 42.0:
				_slow_windows += 1
				if _slow_windows >= 3:
					quality -= 1
					_slow_windows = 0
					_apply_quality()
					hud.message("Graphics lowered for smoother play (G to change)", 2.5)
			else:
				_slow_windows = 0
	if bench and state == "play":
		_bench_frames += 1
		_bench_time += delta
		if play_time > 30.0:
			var line := ""
			for k2 in prof: line += "%s=%.2f " % [k2, prof[k2] / 1000.0 / maxf(1.0, Engine.get_process_frames())]
			print("BENCH per-frame ms: ", line)
			print("BENCH avg_fps=%.1f enemies=%d draw_calls=%d" % [_bench_frames / _bench_time, horde.enemies.size(),
				RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)])
			get_tree().quit()


func _apply_quality() -> void:
	var vp := get_viewport()
	match quality:
		0:
			vp.scaling_3d_scale = 0.66
			fx.part_cap = 220
		1:
			vp.scaling_3d_scale = 1.0
			fx.part_cap = 450
		2:
			vp.scaling_3d_scale = 1.0
			vp.msaa_3d = Viewport.MSAA_2X
			fx.part_cap = 600
	if quality != 2:
		vp.msaa_3d = Viewport.MSAA_DISABLED


func _endgame_shots() -> void:
	var steps := [[1.0, "e_start"], [3.0, "e_shield_down"], [5.5, "e_lord"], [8.0, "e_won"], [12.0, "e_end"]]
	if _ui_step >= steps.size():
		get_tree().quit()
		return
	if time < steps[_ui_step][0]:
		return
	var name_s: String = steps[_ui_step][1]
	_ui_step += 1
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [shot_dir, name_s])
	print("ENDGAME %s shield=%s wards=%d citadel=%d lord=%s state=%s" % [name_s, marks.shield_up, marks.wards_alive(), citadel_hp, dread_lord != null and dread_lord.alive, state])
	match name_s:
		"e_start":
			start()
			hero.invuln = 999.0
			hero.max_hp = 99999.0
			hero.hp = 99999.0
			for w in marks.wards:
				horde.hurt(w, 1e7)
		"e_shield_down":
			hero.position = maze.collide(maze.citadel_pos + Vector3(10, 0, 10), 0.42)
			_update_camera(0.0, true)
			damage_citadel(CITADEL_HP * 0.55)
		"e_lord":
			if dread_lord != null:
				horde.hurt(dread_lord, 1e7)
			damage_citadel(1e7)


func _ui_shots() -> void:
	if endgame_test:
		_endgame_shots()
		return
	var steps := [[1.5, "title"], [3.0, "levelup"], [4.5, "inventory"], [7.5, "shrine"], [10.5, "ward"], [13.5, "over"]]
	if _ui_step >= steps.size():
		get_tree().quit()
		return
	if time < steps[_ui_step][0]:
		return
	var name_s: String = steps[_ui_step][1]
	_ui_step += 1
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/ui_%s.png" % [shot_dir, name_s])
	match name_s:
		"title":
			start()
			on_spellbook()
		"levelup":
			choose(0)
			for k in 7:
				hero.take_item(Items.make(6, [0, 1, 2, 3, 1, 2, 3][k]))
		"inventory":
			var sh: Landmarks.Shrine = marks.shrines[0]
			hero.position = maze.collide(sh.pos + Vector3(2.5, 0, 2.5), 0.42)
			hero.invuln = 99.0
			items.drop(Items.make(5, 3), hero.position + Vector3(1.5, 0, 0))
			items.drop(Items.make(5, 1), hero.position + Vector3(-1.5, 0, 0.5))
			_update_camera(0.0, true)
		"shrine":
			hero.position = maze.collide(marks.wards[0].pos + Vector3(5, 0, 5), 0.42)
			_update_camera(0.0, true)
		"ward":
			castle.take_damage(99999)


func _sim_report() -> void:
	if int(play_time / 30.0) != _sim_wave:
		_sim_wave = int(play_time / 30.0)
		var sold := 0
		for u in horde.soldiers:
			if u.alive: sold += 1
		var march := 0
		for u in horde.enemies:
			if u.alive and u.mode == "march": march += 1
		var lv := ""
		for u in Castle.UPGRADES: lv += str(castle.level(u.key))
		# Where is the front? Mean progress of marching Dread (0 = citadel, 1 = Camelot).
		var fr := 0.0
		var nf := 0
		var total: float = maze.to_castle_dist[Maze.idx(maze.citadel_tile + Vector2i(3, 3))]
		for u in horde.enemies:
			if u.alive and u.mode == "march":
				fr += 1.0 - maze.to_castle_dist[Maze.idx(Maze.tile_of(u.pos))] / total
				nf += 1
		print("SIM t=%d wave=%d castle=%d soldiers=%d dread=%d lane_front=%.2f (0=Camelot 1=Citadel)" % [play_time, wave, castle.hp, sold, march, lane_front()])
	if play_time > 1300.0 or state == "over":
		print("SIM END state=%s t=%d wave=%d" % [state, play_time, wave])
		get_tree().quit()


func _shots() -> void:
	if sim:
		_sim_report()
		return
	if ui_test and shot_dir != "":
		_ui_shots()
		return
	if shot_dir == "" or shot_times.is_empty():
		return
	if play_time >= shot_times[0]:
		var t: float = shot_times.pop_front()
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.save_png("%s/shot_%03d.png" % [shot_dir, int(t)])
		print("SHOT proc_ms=%.2f frames=%d" % [Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, Engine.get_process_frames()])
		var tot := 0
		for k in prof: tot += prof[k]
		var line := ""
		for k in prof: line += "%s=%.2f " % [k, prof[k] / 1000.0 / maxf(1.0, Engine.get_process_frames())]
		print("  per-frame ms: ", line)
		var wk := 0
		for w in horde.workers:
			if w.alive: wk += 1
		print("SHOT gold=%d workers=%d soldiers=%d" % [castle.gold, wk, horde.soldiers.size()])
		print("SHOT t=%d fps=%.1f enemies=%d allies=%d lvl=%d wave=%d hp=%d carry=%d castle=%d draws=%d" % [t, fps_now, horde.enemies.size(), horde.allies.size(), hero.level, wave, hero.hp, hero.carry_total(), castle.hp,
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)])
		if shot_times.is_empty():
			get_tree().quit()
