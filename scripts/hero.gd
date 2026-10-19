class_name Hero
extends Node3D
## Sir Percival. Walks with WASD / arrows or by click-and-hold (Diablo style);
## weapons fire on their own (Vampire Survivors style). Gathers resources by
## standing next to them and hauls them home to the castle.

const WEAPONS := {
	"sword": {"name": "Excalibur", "desc": "Sweeping sword arc"},
	"bolts": {"name": "Arcane Bolts", "desc": "Homing magic missiles"},
	"fireball": {"name": "Fireball", "desc": "Explodes on impact"},
	"nova": {"name": "Holy Nova", "desc": "Burst of light around you"},
	"axes": {"name": "Whirling Axes", "desc": "Axes orbit around you"},
	"lightning": {"name": "Chain Lightning", "desc": "Arcs between foes"},
}
const PASSIVES := {
	"might": {"name": "Might", "desc": "+12% damage"},
	"haste": {"name": "Haste", "desc": "-8% cooldowns"},
	"vigor": {"name": "Vigor", "desc": "+25 max HP, +0.6 HP/s"},
	"swift": {"name": "Swiftness", "desc": "+7% move speed"},
	"magnet": {"name": "Magnetism", "desc": "+40% pickup range"},
	"harvest": {"name": "Woodsman", "desc": "+35% gather speed, +6 carry"},
}
const WEAPON_MAX := 6
const PASSIVE_MAX := 5

var game: Game
var alive := true
var max_hp := 120.0
var hp := 120.0
var armor := 0.0
var speed := 6.2
var regen := 0.3
var pickup_r := 2.6
var carry_cap := 25.0
var gather_rate := 5.0
var dmg_mult := 1.0
var cd_mult := 1.0
var carry := {"gold": 0.0, "wood": 0.0, "crystal": 0.0}
var xp := 0.0
var level := 1
var xp_next := 10.0
var potions := 1
var potion_max := 2
var weapons := {"sword": 1}
var passives := {}
var timers := {}
var vel := Vector3.ZERO
var facing := 0.0
var invuln := 0.0
var hurt_flash := 0.0
var respawn_t := 0.0
var move_target := Vector3.INF
var gather_node = null
var gather_acc := 0.0
var swing_t := 0.0
var swing_yaw := 0.0
var anim := 0.0
var axe_hits := {}
var axe_angle := 0.0
var potion_cd := 0.0
var lost_msg_t := 0.0

var body: MeshInstance3D
var sword_pivot: Node3D
var shield: MeshInstance3D
var aura: MeshInstance3D


func setup(g: Game) -> void:
	game = g
	body = MeshInstance3D.new()
	body.mesh = Models.hero_body()
	Geo.apply(body)
	add_child(body)
	sword_pivot = Node3D.new()
	sword_pivot.position = Vector3(0.36, 0.78, 0.05)
	add_child(sword_pivot)
	var sword := MeshInstance3D.new()
	sword.mesh = Models.hero_sword()
	Geo.apply(sword)
	sword_pivot.add_child(sword)
	shield = MeshInstance3D.new()
	shield.mesh = Models.hero_shield()
	Geo.apply(shield)
	shield.position = Vector3(-0.42, 0.75, 0.08)
	add_child(shield)
	# Faint gather / pickup ring under the hero.
	aura = MeshInstance3D.new()
	aura.mesh = Models.ring_mesh()
	aura.material_override = Geo.mat_add()
	aura.position.y = 0.06
	aura.visible = false
	add_child(aura)
	recompute()
	hp = max_hp
	xp_next = _xp_for(1)


func _xp_for(l: int) -> float:
	return 8.0 + l * 6.0 + l * l * 1.1


func recompute() -> void:
	var c := game.castle
	var ratio := hp / max_hp if max_hp > 0.0 else 1.0
	max_hp = 120.0 + 25.0 * passives.get("vigor", 0) + 25.0 * c.level("armory")
	armor = 1.5 * c.level("armory")
	speed = 6.2 * (1.0 + 0.07 * passives.get("swift", 0)) * (1.0 + 0.06 * c.level("stables"))
	regen = 0.3 + 0.6 * passives.get("vigor", 0) + 1.0 * c.level("shrine")
	pickup_r = 2.6 * (1.0 + 0.4 * passives.get("magnet", 0))
	carry_cap = 25.0 + 6.0 * passives.get("harvest", 0) + 12.0 * c.level("stables")
	gather_rate = 5.0 * (1.0 + 0.35 * passives.get("harvest", 0))
	dmg_mult = (1.0 + 0.12 * passives.get("might", 0)) * (1.0 + 0.15 * c.level("forge"))
	cd_mult = pow(0.92, passives.get("haste", 0)) * pow(0.93, c.level("mage"))
	potion_max = 2 + c.level("shrine")
	hp = max_hp * ratio


func carry_total() -> float:
	return carry.gold + carry.wood + carry.crystal


# ------------------------------------------------------------- update

func update(dt: float) -> void:
	invuln = maxf(0.0, invuln - dt)
	hurt_flash = maxf(0.0, hurt_flash - dt)
	potion_cd = maxf(0.0, potion_cd - dt)
	lost_msg_t = maxf(0.0, lost_msg_t - dt)
	if not alive:
		respawn_t -= dt
		if respawn_t <= 0.0:
			_respawn()
		return
	var at_castle := (position - game.maze.castle_pos).length() < Castle.DELIVER_R
	hp = minf(max_hp, hp + regen * dt * (6.0 if at_castle else 1.0))
	if at_castle:
		game.castle.deliver(self)
		if potions < potion_max and potion_cd <= 0.0:
			potions += 1
			potion_cd = 2.0
	_move(dt)
	_gather(dt)
	_weapons(dt)
	_animate(dt)


func _input_dir() -> Vector3:
	var v := Vector2.ZERO
	if Input.is_action_pressed("move_up"): v.y -= 1
	if Input.is_action_pressed("move_down"): v.y += 1
	if Input.is_action_pressed("move_left"): v.x -= 1
	if Input.is_action_pressed("move_right"): v.x += 1
	if v == Vector2.ZERO:
		return Vector3.ZERO
	v = v.normalized()
	# Screen axes in world space for the isometric camera.
	var right := Vector3(1, 0, -1).normalized()
	var down := Vector3(1, 0, 1).normalized()
	return right * v.x + down * v.y


func _move(dt: float) -> void:
	var dir := _input_dir()
	if dir != Vector3.ZERO:
		move_target = Vector3.INF
	elif game.autopilot:
		dir = game.autopilot_dir()
	elif move_target != Vector3.INF:
		var to := Vector3(move_target.x - position.x, 0, move_target.z - position.z)
		if to.length() < 0.35:
			move_target = Vector3.INF
		else:
			dir = to.normalized()
			# Route around walls with the flow field when the straight line is blocked.
			if not game.maze.line_clear(position, move_target):
				var f := game.click_flow(position)
				if f != Vector3.ZERO:
					dir = f
	var want := dir * speed
	vel = vel.lerp(want, minf(1.0, dt * 14.0))
	var np := game.maze.collide(position + vel * dt, 0.42)
	var moved := (np - position).length()
	position = np
	anim += moved * 2.2
	if dir != Vector3.ZERO and swing_t <= 0.0:
		facing = lerp_angle(facing, atan2(dir.x, dir.z), minf(1.0, dt * 14.0))


func _gather(dt: float) -> void:
	gather_node = null
	if carry_total() >= carry_cap - 0.001:
		if carry_total() > 0 and lost_msg_t <= 0.0 and game.nodes.nearest_harvestable(position) != null:
			game.fx.number(position + Vector3(0, 2.2, 0), "PACK FULL", Color(1, 0.6, 0.3))
			lost_msg_t = 2.5
		return
	var n = game.nodes.nearest_harvestable(position)
	if n == null:
		return
	gather_node = n
	gather_acc += dt * gather_rate
	if gather_acc >= 1.0:
		var want := floorf(gather_acc)
		gather_acc -= want
		want = minf(want, carry_cap - carry_total())
		var got: float = game.nodes.take(n, want)
		carry[n.kind] += got
		if got > 0.0:
			var col: Color = {"wood": Color(0.85, 0.7, 0.35), "gold": Color(1, 0.85, 0.3), "crystal": Color(0.75, 0.55, 1)}[n.kind]
			game.fx.number(n.pos + Vector3(0, 1.8, 0), "+%d" % int(got), col)
			game.fx.burst(n.pos + Vector3(0, 0.8, 0), col, 2, 2.0, 0.1)
			game.sfx.play("chop", -4.0, 0.2, 0.2)


func _ready_weapon(key: String, cd: float, dt: float) -> bool:
	var t: float = timers.get(key, randf() * 0.5) - dt
	if t <= 0.0:
		timers[key] = cd * cd_mult
		return true
	timers[key] = t
	return false


func _weapons(dt: float) -> void:
	var horde := game.horde
	var p := position
	var cit_alive := game.citadel_hp > 0.0
	var cit_d := Vector2(p.x - game.maze.citadel_pos.x, p.z - game.maze.citadel_pos.z).length()
	swing_t = maxf(0.0, swing_t - dt)
	# --- Excalibur
	var sl: int = weapons.get("sword", 0)
	if sl > 0:
		var rng_s := 2.3 + 0.18 * sl
		var target := horde.nearest_enemy(p, rng_s + 0.4)
		var hits_cit := cit_alive and cit_d < 5.0 + rng_s
		if target != null or hits_cit:
			if _ready_weapon("sword", 0.78 * pow(0.93, sl - 1), dt):
				var aim := target.pos if target != null else game.maze.citadel_pos
				var yaw := atan2(aim.x - p.x, aim.z - p.z)
				facing = yaw
				swing_yaw = yaw
				swing_t = 0.25
				var dmg := (16.0 + 6.0 * (sl - 1)) * dmg_mult
				game.fx.slash(p, yaw, rng_s, Color(0.95, 0.9, 0.6))
				game.sfx.play("swing", -2.0, 0.1)
				var fwd := Vector3(sin(yaw), 0, cos(yaw))
				for u: Unit in horde.enemies_near(p, rng_s):
					var to := u.pos - p
					to.y = 0
					if to.length() < 0.8 or fwd.dot(to.normalized()) > -0.05:
						horde.hurt(u, dmg, to.normalized(), 3.0)
				if hits_cit:
					game.damage_citadel(dmg)
	# --- Arcane bolts
	var bl: int = weapons.get("bolts", 0)
	if bl > 0:
		var tgt := horde.nearest_enemy(p, 11.0)
		if (tgt != null or (cit_alive and cit_d < 14.0)) and _ready_weapon("bolts", 1.3 * pow(0.94, bl - 1), dt):
			var n := 1 + bl / 2
			for k in n:
				var aim2 := tgt.pos if tgt != null else game.maze.citadel_pos
				var spread := (k - (n - 1) * 0.5) * 0.35
				var dirv := (aim2 - p).normalized().rotated(Vector3.UP, spread)
				game.fx.shoot("bolt", p + Vector3(0, 1.0, 0), p + Vector3(0, 1, 0) + dirv * 5.0, 13.0, (11.0 + 4.0 * (bl - 1)) * dmg_mult, 0, tgt)
	# --- Fireball
	var fl: int = weapons.get("fireball", 0)
	if fl > 0:
		var cands := horde.enemies_near(p, 12.0)
		if (not cands.is_empty() or (cit_alive and cit_d < 14.0)) and _ready_weapon("fireball", 2.6 * pow(0.92, fl - 1), dt):
			var aim3: Vector3 = (cands[randi() % mini(cands.size(), 6)] as Unit).pos if not cands.is_empty() else game.maze.citadel_pos
			var shots := 1 + (1 if fl >= 4 else 0) + (1 if fl >= 6 else 0)
			for k in shots:
				var off := Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)) * (0.0 if k == 0 else 2.5)
				game.fx.shoot("fireball", p + Vector3(0, 1.0, 0), aim3 + off + Vector3(0, 1, 0), 11.0, (26.0 + 9.0 * (fl - 1)) * dmg_mult, 0, null, 2.3 + 0.3 * fl)
	# --- Holy nova
	var nl: int = weapons.get("nova", 0)
	if nl > 0:
		var nr := 3.6 + 0.4 * nl
		if horde.nearest_enemy(p, nr) != null and _ready_weapon("nova", 3.2 * pow(0.93, nl - 1), dt):
			game.fx.ring(p, 0.5, nr, Color(1.0, 0.95, 0.6), 0.45, 0.25)
			game.sfx.play("deliver", -6.0, 0.2, 0.0)
			game.fx.ring(p, 0.2, nr * 0.7, Color(1.0, 0.85, 0.4), 0.3, 0.35)
			for u: Unit in horde.enemies_near(p, nr):
				var to2 := u.pos - p
				to2.y = 0
				horde.hurt(u, (16.0 + 6.0 * (nl - 1)) * dmg_mult, to2.normalized(), 7.0, Color(1, 1, 0.7))
	# --- Whirling axes
	var al: int = weapons.get("axes", 0)
	if al > 0:
		axe_angle += dt * (3.2 + 0.2 * al)
		var adm := (9.0 + 3.0 * (al - 1)) * dmg_mult
		var now := game.time
		for ap in axe_positions():
			for u: Unit in horde.enemies_near(ap, 0.55):
				var last: float = axe_hits.get(u, -10.0)
				if now - last > 0.45:
					axe_hits[u] = now
					var to3 := u.pos - p
					to3.y = 0
					horde.hurt(u, adm, to3.normalized(), 3.0, Color(0.9, 0.95, 1.0))
		if axe_hits.size() > 200:
			axe_hits.clear()
	# --- Chain lightning
	var ll: int = weapons.get("lightning", 0)
	if ll > 0:
		var first := horde.nearest_enemy(p, 10.0)
		if first != null and _ready_weapon("lightning", 2.2 * pow(0.93, ll - 1), dt):
			var from := p + Vector3(0, 1.2, 0)
			var cur: Unit = first
			var hit := {}
			var dmg2 := (18.0 + 5.0 * (ll - 1)) * dmg_mult
			for k in 2 + ll:
				if cur == null:
					break
				hit[cur] = true
				var to_p := cur.pos + Vector3(0, 0.8, 0)
				game.fx.lightning(from, to_p, Color(0.6, 0.75, 1.0))
				game.sfx.play("zap", -4.0, 0.12)
				horde.hurt(cur, dmg2, Vector3.ZERO, 0.0, Color(0.7, 0.85, 1.0))
				from = to_p
				var nxt: Unit = null
				var bd := INF
				for u: Unit in horde.enemies_near(cur.pos, 5.0):
					if hit.has(u) or not u.alive:
						continue
					var d := (u.pos - cur.pos).length_squared()
					if d < bd:
						bd = d
						nxt = u
				cur = nxt


func axe_positions() -> Array:
	var out := []
	var al: int = weapons.get("axes", 0)
	if al <= 0:
		return out
	var n := 1 + al
	var r := 2.2 + 0.1 * al
	for k in n:
		var a := axe_angle + TAU * k / n
		out.append(position + Vector3(cos(a) * r, 0.7, sin(a) * r))
	return out


func _animate(dt: float) -> void:
	var walking := clampf(vel.length() / speed, 0.0, 1.0)
	body.position.y = absf(sin(anim)) * 0.1 * walking
	rotation.y = facing
	body.rotation.z = sin(anim) * 0.06 * walking
	# Sword: rest pose at the side, swing across on attack.
	if swing_t > 0.0:
		var k := 1.0 - swing_t / 0.25
		sword_pivot.rotation = Vector3(-0.2, lerpf(1.3, -1.6, k), 0)
	else:
		sword_pivot.rotation = sword_pivot.rotation.lerp(Vector3(-0.9, 0.5, 0), minf(1.0, dt * 10.0))
	if gather_node != null and swing_t <= 0.0:
		# Work animation: chop / mine.
		var c := sin(game.time * 12.0)
		sword_pivot.rotation = Vector3(-0.4 + c * 0.9, 0.2, 0)
		var n = gather_node
		facing = lerp_angle(facing, atan2(n.pos.x - position.x, n.pos.z - position.z), minf(1.0, dt * 10.0))
	aura.visible = gather_node != null
	if aura.visible:
		var s := 1.0 + sin(game.time * 6.0) * 0.08
		aura.scale = Vector3(s, 1, s) * 0.9
	body.visible = true
	if hurt_flash > 0.0:
		body.visible = int(hurt_flash * 30.0) % 2 == 0


# ------------------------------------------------------------- events

func take_damage(amount: float, from: Vector3) -> void:
	if not alive or invuln > 0.0 or game.state != "play":
		return
	var d := maxf(1.0, amount - armor)
	hp -= d
	invuln = 0.15
	hurt_flash = 0.3
	game.fx.number(position + Vector3(0, 1.9, 0), str(int(round(d))), Color(1.0, 0.3, 0.25))
	game.sfx.play("hurt", 0.0, 0.18)
	game.shake = maxf(game.shake, 0.12)
	var kb := position - from
	kb.y = 0
	if kb.length_squared() > 0.01:
		vel += kb.normalized() * 3.0
	if hp <= 0.0:
		_die()


func _die() -> void:
	alive = false
	hp = 0.0
	respawn_t = 6.0
	game.fx.burst(position + Vector3(0, 0.8, 0), Color(0.75, 0.75, 0.85), 16, 5.0, 0.2)
	game.fx.burst(position + Vector3(0, 0.8, 0), Color(0.8, 0.15, 0.15), 10, 4.0, 0.16)
	var lost := carry_total()
	carry = {"gold": 0.0, "wood": 0.0, "crystal": 0.0}
	visible = false
	game.on_hero_died(lost)


func _respawn() -> void:
	alive = true
	hp = max_hp
	visible = true
	position = game.maze.castle_pos + Vector3(-1.5, 0, 6.0)
	position = game.maze.collide(position, 0.42)
	vel = Vector3.ZERO
	move_target = Vector3.INF
	invuln = 2.0
	game.fx.ring(position, 0.2, 3.0, Color(1, 0.9, 0.5), 0.6)


func drink_potion() -> void:
	if not alive or potions <= 0 or hp >= max_hp:
		return
	potions -= 1
	hp = minf(max_hp, hp + max_hp * 0.5)
	game.fx.sparkle(position, Color(1, 0.35, 0.4), 12, 0.12)
	game.sfx.play("deliver", 0.0, 0.1, 0.0)
	game.fx.number(position + Vector3(0, 2.0, 0), "+%d" % int(max_hp * 0.5), Color(0.5, 1, 0.5))


func collect(kind: String, val: int) -> void:
	match kind:
		"gem":
			add_xp(val)
			game.sfx.play("gem", -6.0, 0.04)
		"coin":
			var add := minf(val, carry_cap - carry_total())
			carry.gold += add
			game.sfx.play("coin", -4.0, 0.06)
			game.fx.number(position + Vector3(0, 1.9, 0), "+%d gold" % int(add), Color(1, 0.85, 0.3))
		"potion":
			potions = mini(potion_max, potions + 1)


func add_xp(v: float) -> void:
	xp += v
	while xp >= xp_next:
		xp -= xp_next
		level += 1
		xp_next = _xp_for(level)
		game.queue_levelup()


## Up to three random upgrade offers for a level-up.
func roll_choices() -> Array:
	var pool := []
	var owned_w := 0
	for k in weapons:
		owned_w += 1
	for k in WEAPONS:
		var lv: int = weapons.get(k, 0)
		if lv < WEAPON_MAX and (lv > 0 or owned_w < 5):
			pool.append({"type": "weapon", "key": k, "name": WEAPONS[k].name, "desc": WEAPONS[k].desc, "level": lv + 1})
	for k in PASSIVES:
		var lv2: int = passives.get(k, 0)
		if lv2 < PASSIVE_MAX:
			pool.append({"type": "passive", "key": k, "name": PASSIVES[k].name, "desc": PASSIVES[k].desc, "level": lv2 + 1})
	pool.shuffle()
	var out := pool.slice(0, 3)
	if out.is_empty():
		out.append({"type": "heal", "key": "heal", "name": "Second Wind", "desc": "Fully restore HP", "level": 0})
	return out


func apply_choice(c: Dictionary) -> void:
	match c.type:
		"weapon":
			weapons[c.key] = weapons.get(c.key, 0) + 1
		"passive":
			passives[c.key] = passives.get(c.key, 0) + 1
			recompute()
		"heal":
			hp = max_hp
