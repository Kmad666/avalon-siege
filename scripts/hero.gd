class_name Hero
extends Node3D
## Merlin. Walks with WASD / arrows or by click-and-hold (Diablo style);
## spells cast on their own (Vampire Survivors style). Mines gold veins by
## standing next to them and hauls the ore home to Camelot.

const WEAPONS := {
	"lightning": {"name": "Chain Lightning", "desc": "Arcs from foe to foe"},
	"bolts": {"name": "Arcane Missiles", "desc": "Homing magic missiles"},
	"fireball": {"name": "Fireball", "desc": "Explodes on impact"},
	"nova": {"name": "Arcane Nova", "desc": "Burst of force around you"},
	"orbs": {"name": "Spell Orbs", "desc": "Orbs circle and smite foes"},
	"heal": {"name": "Healing Light", "desc": "Heals you and nearby troops"},
}
const PASSIVES := {
	"might": {"name": "Might", "desc": "+12% spell damage"},
	"haste": {"name": "Haste", "desc": "-8% cooldowns"},
	"vigor": {"name": "Vigor", "desc": "+25 max HP, +0.6 HP/s"},
	"swift": {"name": "Swiftness", "desc": "+7% move speed"},
	"magnet": {"name": "Magnetism", "desc": "+40% pickup range"},
	"prospect": {"name": "Prospector", "desc": "+35% mining speed, +8 carry"},
}
const WEAPON_MAX := 7
const PASSIVE_MAX := 5

var game: Game
var alive := true
var max_hp := 110.0
var hp := 110.0
var armor := 0.0
var speed := 6.2
var regen := 0.3
var pickup_r := 2.8
var carry_cap := 25.0
var gather_rate := 5.0
var dmg_mult := 1.0
var cd_mult := 1.0
var carry := 0.0
var xp := 0.0
var level := 1
var xp_next := 10.0
var potions := 2
var potion_max := 2
var weapons := {"lightning": 1}
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
var cast_t := 0.0
var anim := 0.0
var orb_hits := {}
var orb_angle := 0.0
var potion_cd := 0.0
var lost_msg_t := 0.0
# Relic bonuses from slain mini-bosses.
var relic_dmg := 1.0
var relic_cd := 1.0
var relic_hp := 0.0
var relic_bounce := 0
var relic_army := 1.0
var relic_gold := 1.0
var relics: Array[String] = []

var body: MeshInstance3D
var staff_pivot: Node3D
var gem: MeshInstance3D
var aura: MeshInstance3D


func setup(g: Game) -> void:
	game = g
	body = MeshInstance3D.new()
	body.mesh = Models.wizard_body()
	Geo.apply(body)
	add_child(body)
	staff_pivot = Node3D.new()
	staff_pivot.position = Vector3(0.36, 0.86, 0.22)
	add_child(staff_pivot)
	var staff := MeshInstance3D.new()
	staff.mesh = Models.wizard_staff()
	Geo.apply(staff)
	staff_pivot.add_child(staff)
	gem = MeshInstance3D.new()
	gem.mesh = Models.staff_gem()
	Geo.apply(gem, true)
	gem.position = Vector3(0, 0.86, 0)
	staff_pivot.add_child(gem)
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
	max_hp = 110.0 + 25.0 * passives.get("vigor", 0) + 25.0 * c.level("armory") + relic_hp
	armor = 1.5 * c.level("armory")
	speed = 6.2 * (1.0 + 0.07 * passives.get("swift", 0)) * (1.0 + 0.1 * c.level("shrine"))
	regen = 0.3 + 0.6 * passives.get("vigor", 0) + 1.0 * c.level("shrine")
	pickup_r = 2.8 * (1.0 + 0.4 * passives.get("magnet", 0))
	carry_cap = 25.0 + 8.0 * passives.get("prospect", 0)
	gather_rate = 6.0 * (1.0 + 0.35 * passives.get("prospect", 0))
	dmg_mult = (1.0 + 0.12 * passives.get("might", 0)) * (1.0 + 0.15 * c.level("forge")) * relic_dmg
	cd_mult = pow(0.92, passives.get("haste", 0)) * pow(0.93, c.level("mage")) * relic_cd
	potion_max = 2 + c.level("shrine")
	hp = max_hp * ratio


func carry_total() -> float:
	return carry


# ------------------------------------------------------------- update

func update(dt: float) -> void:
	invuln = maxf(0.0, invuln - dt)
	hurt_flash = maxf(0.0, hurt_flash - dt)
	potion_cd = maxf(0.0, potion_cd - dt)
	lost_msg_t = maxf(0.0, lost_msg_t - dt)
	cast_t = maxf(0.0, cast_t - dt)
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
	_spells(dt)
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
	if dir != Vector3.ZERO and cast_t <= 0.0:
		facing = lerp_angle(facing, atan2(dir.x, dir.z), minf(1.0, dt * 14.0))


func _gather(dt: float) -> void:
	gather_node = null
	if carry >= carry_cap - 0.001:
		if lost_msg_t <= 0.0 and game.nodes.nearest_harvestable(position) != null:
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
		want = minf(want, carry_cap - carry)
		var got: float = game.nodes.take(n, want)
		carry += got
		if got > 0.0:
			game.fx.number(n.pos + Vector3(0, 1.8, 0), "+%d" % int(got), Color(1, 0.85, 0.3))
			game.fx.burst(n.pos + Vector3(0, 0.8, 0), Color(1, 0.8, 0.3), 2, 2.0, 0.1)
			game.sfx.play("chop", -4.0, 0.2, 0.2)


func _ready_spell(key: String, cd: float, dt: float) -> bool:
	var t: float = timers.get(key, randf() * 0.5) - dt
	if t <= 0.0:
		timers[key] = cd * cd_mult
		return true
	timers[key] = t
	return false


func _cast_at(p: Vector3) -> void:
	facing = atan2(p.x - position.x, p.z - position.z)
	cast_t = 0.22


func staff_tip() -> Vector3:
	return gem.global_position


func _spells(dt: float) -> void:
	var horde := game.horde
	var p := position
	var cit_alive := game.citadel_hp > 0.0
	var cit_d := Vector2(p.x - game.maze.citadel_pos.x, p.z - game.maze.citadel_pos.z).length()
	# --- Chain Lightning (primary)
	var ll: int = weapons.get("lightning", 0)
	if ll > 0:
		var first := horde.nearest_enemy(p, 11.0)
		var hit_cit := first == null and cit_alive and cit_d < 13.0
		if (first != null or hit_cit) and _ready_spell("lightning", 1.05 * pow(0.93, ll - 1), dt):
			var from := staff_tip()
			var dmg2 := (15.0 + 5.0 * (ll - 1)) * dmg_mult
			if hit_cit:
				var cp := game.maze.citadel_pos + Vector3(0, 4.0, 0)
				_cast_at(cp)
				game.fx.lightning(from, cp, Color(0.6, 0.75, 1.0))
				game.damage_citadel(dmg2 * 1.5)
				game.sfx.play("zap", -2.0, 0.1)
			else:
				_cast_at(first.pos)
				var cur: Unit = first
				var hit := {}
				for k in 2 + ll + relic_bounce:
					if cur == null:
						break
					hit[cur] = true
					var to_p := cur.pos + Vector3(0, 0.8, 0)
					game.fx.lightning(from, to_p, Color(0.6, 0.75, 1.0))
					horde.hurt(cur, dmg2, Vector3.ZERO, 0.0, Color(0.7, 0.85, 1.0))
					from = to_p
					var nxt: Unit = null
					var bd := INF
					for u: Unit in horde.enemies_near(cur.pos, 5.5):
						if hit.has(u) or not u.alive:
							continue
						var d := (u.pos - cur.pos).length_squared()
						if d < bd:
							bd = d
							nxt = u
					cur = nxt
				game.sfx.play("zap", -3.0, 0.1)
	# --- Arcane missiles
	var bl: int = weapons.get("bolts", 0)
	if bl > 0:
		var tgt := horde.nearest_enemy(p, 11.0)
		if (tgt != null or (cit_alive and cit_d < 14.0)) and _ready_spell("bolts", 1.3 * pow(0.94, bl - 1), dt):
			var n := 1 + bl / 2
			var aim2 := tgt.pos if tgt != null else game.maze.citadel_pos
			_cast_at(aim2)
			for k in n:
				var spread := (k - (n - 1) * 0.5) * 0.35
				var dirv := (aim2 - p).normalized().rotated(Vector3.UP, spread)
				game.fx.shoot("bolt", p + Vector3(0, 1.0, 0), p + Vector3(0, 1, 0) + dirv * 5.0, 13.0, (11.0 + 4.0 * (bl - 1)) * dmg_mult, 0, tgt)
	# --- Fireball
	var fl: int = weapons.get("fireball", 0)
	if fl > 0:
		var cands := horde.enemies_near(p, 12.0)
		if (not cands.is_empty() or (cit_alive and cit_d < 14.0)) and _ready_spell("fireball", 2.6 * pow(0.92, fl - 1), dt):
			var aim3: Vector3 = (cands[randi() % mini(cands.size(), 6)] as Unit).pos if not cands.is_empty() else game.maze.citadel_pos
			_cast_at(aim3)
			var shots := 1 + (1 if fl >= 4 else 0) + (1 if fl >= 6 else 0)
			for k in shots:
				var off := Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)) * (0.0 if k == 0 else 2.5)
				game.fx.shoot("fireball", p + Vector3(0, 1.0, 0), aim3 + off + Vector3(0, 1, 0), 11.0, (26.0 + 9.0 * (fl - 1)) * dmg_mult, 0, null, 2.3 + 0.3 * fl)
	# --- Arcane nova
	var nl: int = weapons.get("nova", 0)
	if nl > 0:
		var nr := 3.6 + 0.4 * nl
		if horde.nearest_enemy(p, nr) != null and _ready_spell("nova", 3.2 * pow(0.93, nl - 1), dt):
			game.fx.ring(p, 0.5, nr, Color(0.7, 0.6, 1.0), 0.45, 0.25)
			game.fx.ring(p, 0.2, nr * 0.7, Color(0.5, 0.7, 1.0), 0.3, 0.35)
			game.sfx.play("deliver", -6.0, 0.2, 0.0)
			for u: Unit in horde.enemies_near(p, nr):
				var to2 := u.pos - p
				to2.y = 0
				horde.hurt(u, (16.0 + 6.0 * (nl - 1)) * dmg_mult, to2.normalized(), 7.0, Color(0.85, 0.8, 1.0))
	# --- Spell orbs
	var ol: int = weapons.get("orbs", 0)
	if ol > 0:
		orb_angle += dt * (3.0 + 0.2 * ol)
		var adm := (9.0 + 3.0 * (ol - 1)) * dmg_mult
		var now := game.time
		for ap in orb_positions():
			for u: Unit in horde.enemies_near(ap, 0.55):
				var last: float = orb_hits.get(u, -10.0)
				if now - last > 0.45:
					orb_hits[u] = now
					var to3 := u.pos - p
					to3.y = 0
					horde.hurt(u, adm, to3.normalized(), 3.0, Color(0.8, 0.7, 1.0))
		if orb_hits.size() > 200:
			orb_hits.clear()
	# --- Healing light
	var hl: int = weapons.get("heal", 0)
	if hl > 0 and _ready_spell("heal", 5.0 * pow(0.93, hl - 1), dt):
		var amt := (20.0 + 10.0 * (hl - 1)) * dmg_mult
		var healed := hp < max_hp
		hp = minf(max_hp, hp + amt * 0.5)
		for a in horde.friends_near(p, 8.0 + hl * 0.5):
			if a.hp < a.max_hp:
				a.hp = minf(a.max_hp, a.hp + amt)
				game.fx.sparkle(a.pos, Color(0.5, 1.0, 0.55), 3, 0.09)
				healed = true
		if healed:
			game.fx.ring(p, 0.4, 8.0 + hl * 0.5, Color(0.35, 0.9, 0.4), 0.6, 0.15)
			game.fx.sparkle(p, Color(0.5, 1.0, 0.55), 8, 0.1)
		else:
			timers["heal"] = 0.5


func orb_positions() -> Array:
	var out := []
	var ol: int = weapons.get("orbs", 0)
	if ol <= 0:
		return out
	var n := 1 + ol
	var r := 2.2 + 0.1 * ol
	for k in n:
		var a := orb_angle + TAU * k / n
		out.append(position + Vector3(cos(a) * r, 0.8, sin(a) * r))
	return out


func _animate(dt: float) -> void:
	var walking := clampf(vel.length() / speed, 0.0, 1.0)
	body.position.y = absf(sin(anim)) * 0.08 * walking
	rotation.y = facing
	body.rotation.z = sin(anim) * 0.05 * walking
	# Staff: planted at rest, thrust forward when casting.
	var target_rot := Vector3(0.12, 0, 0)
	if cast_t > 0.0:
		target_rot = Vector3(1.0, 0, -0.2)
	elif gather_node != null:
		target_rot = Vector3(0.5 + sin(game.time * 12.0) * 0.5, 0, 0)
		var n = gather_node
		facing = lerp_angle(facing, atan2(n.pos.x - position.x, n.pos.z - position.z), minf(1.0, dt * 10.0))
	staff_pivot.rotation = staff_pivot.rotation.lerp(target_rot, minf(1.0, dt * 18.0))
	var gs := 1.0 + (0.5 if cast_t > 0.0 else 0.1 * sin(game.time * 4.0))
	gem.scale = Vector3(gs, gs, gs)
	gem.rotation.y += dt * 2.0
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
	game.fx.burst(position + Vector3(0, 0.8, 0), Color(0.55, 0.4, 0.25), 16, 5.0, 0.2)
	game.fx.burst(position + Vector3(0, 0.8, 0), Color(0.6, 0.8, 1.0), 10, 4.0, 0.16)
	var lost := carry
	carry = 0.0
	visible = false
	game.on_hero_died(lost)


func _respawn() -> void:
	alive = true
	hp = max_hp
	visible = true
	position = game.maze.castle_pos + Vector3(-1.5, 0, -6.5)
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
			# Coins go straight to Camelot's treasury.
			var v := roundf(val * relic_gold)
			game.castle.add_gold(v, position)
			game.sfx.play("coin", -4.0, 0.06)
		"potion":
			potions = mini(potion_max, potions + 1)


func add_xp(v: float) -> void:
	xp += v
	while xp >= xp_next:
		xp -= xp_next
		level += 1
		xp_next = _xp_for(level)
		game.queue_levelup()


## Up to three random upgrade offers. Spellbooks offer spells only.
func roll_choices(spells_only := false) -> Array:
	var pool := []
	for k in WEAPONS:
		var lv: int = weapons.get(k, 0)
		if lv < WEAPON_MAX:
			pool.append({"type": "weapon", "key": k, "name": WEAPONS[k].name, "desc": WEAPONS[k].desc, "level": lv + 1})
	if not spells_only:
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


## Permanent reward from a slain mini-boss.
func apply_relic(r: Dictionary) -> void:
	relics.append(r.name)
	match r.stat:
		"dmg": relic_dmg *= 1.2
		"cd": relic_cd *= 0.88
		"hp": relic_hp += 60.0
		"bounce": relic_bounce += 2
		"army": relic_army *= 1.25
		"gold": relic_gold *= 1.35
	recompute()
	if r.stat == "hp":
		hp = max_hp
