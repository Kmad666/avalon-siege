class_name HUD
extends Control
## All 2D interface, drawn in one pass with draw_* calls.

const GOLD := Color(1.0, 0.84, 0.32)
const WOOD := Color(0.86, 0.68, 0.38)
const CRYS := Color(0.74, 0.56, 1.0)
const PANEL := Color(0.07, 0.07, 0.06, 0.78)
const EDGE := Color(0.75, 0.62, 0.35, 0.9)
const TEXT := Color(0.96, 0.93, 0.85)
const DIM := Color(0.65, 0.62, 0.55)

var game: Game
var font: Font
var msg := ""
var msg_t := 0.0
var msg_col := Color.WHITE
var minimap_dirty := true
var map_tex: ImageTexture
var map_img: Image
var big_map := false
var _upgrade_rects: Array[Rect2] = []
var _choice_rects: Array[Rect2] = []
var _diff_rects: Array[Rect2] = []
var _bag_rects: Array[Rect2] = []
var _gear_rects := {}             # slot -> Rect2
var _travel_rects: Array[Rect2] = []
var _map_t := 0.0
var loot_log: Array = []          # [text, color, t]


func loot_msg(it, equipped: bool) -> void:
	var txt: String = ("Equipped  " if equipped else "Melted down  ") + it.name
	loot_log.append([txt, Items.RARITY_COLORS[it.rarity] if equipped else DIM, 6.0])
	if loot_log.size() > 4:
		loot_log.pop_front()


func setup(g: Game) -> void:
	game = g
	font = ThemeDB.fallback_font
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_img = Image.create(Maze.G, Maze.G, false, Image.FORMAT_RGBA8)
	map_tex = ImageTexture.create_from_image(map_img)


func message(text: String, dur := 3.0, col := TEXT) -> void:
	msg = text
	msg_t = dur
	msg_col = col


## Returns true if the click hit the interface.
func click(p: Vector2, right := false) -> bool:
	if game.state == "title":
		for i in _diff_rects.size():
			if _diff_rects[i].has_point(p):
				game.choose_difficulty(i)
				return true
		return false
	if game.state == "travel":
		for i in _travel_rects.size():
			if _travel_rects[i].has_point(p):
				game.travel_to(i)
		return true
	if right:
		return false
	if game.state == "levelup":
		for i in _choice_rects.size():
			if _choice_rects[i].has_point(p):
				game.choose(i)
		return true
	return false


func _process(dt: float) -> void:
	msg_t = maxf(0.0, msg_t - dt)
	for l in loot_log:
		l[2] -= dt
	while not loot_log.is_empty() and loot_log[0][2] <= 0.0:
		loot_log.pop_front()
	_map_t -= dt
	if minimap_dirty and _map_t <= 0.0:
		_map_t = 0.4
		minimap_dirty = false
		_refresh_map()


func _refresh_map() -> void:
	var m := game.maze
	for y in Maze.G:
		for x in Maze.G:
			var i := y * Maze.G + x
			var c := Color(0, 0, 0, 0)
			if m.explored[i] != 0:
				match m.tiles[i]:
					Maze.FLOOR: c = Color(0.55, 0.6, 0.45, 0.95).lerp(Color(0.45, 0.38, 0.36, 0.95), m.region[i])
					Maze.WALL: c = Color(0.16, 0.2, 0.14, 0.95).lerp(Color(0.14, 0.11, 0.12, 0.95), m.region[i])
					Maze.KEEP: c = Color(0.45, 0.6, 1.0, 1)
					Maze.CITADEL: c = Color(0.9, 0.2, 0.15, 1)
			map_img.set_pixel(x, y, c)
	map_tex.update(map_img)


func _str(p: Vector2, text: String, size: int, col: Color, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
	draw_string_outline(font, p, text, align, width, size, 4, Color(0, 0, 0, 0.85))
	draw_string(font, p, text, align, width, size, col)


func _bar(r: Rect2, frac: float, col: Color, back := Color(0, 0, 0, 0.6)) -> void:
	draw_rect(r.grow(2), Color(0, 0, 0, 0.7))
	draw_rect(r, back)
	draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(frac, 0, 1), r.size.y)), col)
	draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(frac, 0, 1), r.size.y * 0.35)), Color(1, 1, 1, 0.18))


func _panel(r: Rect2) -> void:
	draw_rect(r, PANEL)
	draw_rect(r, EDGE, false, 1.5)


func _draw() -> void:
	var t0 := Time.get_ticks_usec()
	_draw2()
	game.prof["hud"] = game.prof.get("hud", 0) + Time.get_ticks_usec() - t0


func _draw2() -> void:
	var vs := get_viewport_rect().size
	_upgrade_rects.clear()
	_choice_rects.clear()
	_diff_rects.clear()
	_bag_rects.clear()
	_gear_rects.clear()
	_travel_rects.clear()
	_draw_world_text()
	if game.state == "title":
		_draw_title(vs)
		return
	_draw_top_left()
	_draw_top_center(vs)
	_draw_top_right(vs)
	_draw_upgrades(vs)
	_draw_minimap(vs)
	if msg_t > 0.0 and (game.state == "play" or game.state == "paused" or (game.state == "won" and game.end_t < 1.5)):
		var a := clampf(msg_t, 0.0, 1.0)
		var c := msg_col
		c.a = a
		_str(Vector2(0, vs.y * 0.27), msg, 22, c, HORIZONTAL_ALIGNMENT_CENTER, vs.x)
	if not game.hero.alive and game.state == "play":
		_str(Vector2(0, vs.y * 0.45), "Respawning in %d..." % int(ceil(game.hero.respawn_t)), 26, Color(1, 0.6, 0.5), HORIZONTAL_ALIGNMENT_CENTER, vs.x)
	if game.state == "play" and game.hero.alive:
		var hints := []
		if game.marks.waypoint_here():
			hints.append("T: waypoint travel")
		if not hints.is_empty():
			_str(Vector2(0, vs.y - 92), "   ·   ".join(hints), 14, Color(0.7, 0.85, 1.0), HORIZONTAL_ALIGNMENT_CENTER, vs.x)
	match game.state:
		"travel": _draw_travel(vs)
		"levelup": _draw_levelup(vs)
		"paused": _draw_overlay(vs, "PAUSED", "Press P to resume")
		"over": _draw_end(vs, false)
		"won": _draw_end(vs, true)


func _draw_world_text() -> void:
	var cam := game.camera
	for n in game.fx.numbers:
		var p3: Vector3 = n[0] + Vector3(0, n[3] * 1.6, 0)
		if cam.is_position_behind(p3):
			continue
		var sp := cam.unproject_position(p3)
		var c: Color = n[2]
		c.a = clampf(1.6 - n[3] * 2.0, 0.0, 1.0)
		var size := 16 if n[1].length() < 4 else 15
		_str(sp - Vector2(40, 0), n[1], size, c, HORIZONTAL_ALIGNMENT_CENTER, 80)
	# HP bars over elites, bosses, and wounded knights.
	for u in game.horde.enemies:
		if u.mini >= 0 or u.title != "":
			if (u.pos - game.hero.position).length() < 18.0 and u.hp < u.max_hp or (u.pos - game.hero.position).length() < 12.0:
				var sm := cam.unproject_position(u.pos + Vector3(0, 2.4 * u.scale + (3.5 if u.structure else 0.0), 0))
				_str(sm - Vector2(100, 8), u.title, 15, Color(1, 0.8, 0.4), HORIZONTAL_ALIGNMENT_CENTER, 200)
				_bar(Rect2(sm - Vector2(45, 0), Vector2(90, 6)), u.hp / u.max_hp, Color(0.95, 0.55, 0.15))
			continue
		if (u.elite or u.boss or u.kind == "ogre") and u.hp < u.max_hp:
			var sp2 := cam.unproject_position(u.pos + Vector3(0, 2.0 * u.scale + (1.0 if u.kind == "ogre" else 0.0), 0))
			_bar(Rect2(sp2 - Vector2(22, 0), Vector2(44, 4)), u.hp / u.max_hp, Color(0.9, 0.2, 0.15))
	for a in game.horde.allies:
		if a.alive and a.hp < a.max_hp * 0.98:
			var sp3 := cam.unproject_position(a.pos + Vector3(0, 1.6, 0))
			_bar(Rect2(sp3 - Vector2(15, 0), Vector2(30, 3)), a.hp / a.max_hp, Color(0.35, 0.6, 1.0))
	# Shrines: name, capture progress, health.
	for s in game.marks.shrines:
		var d := (s.pos - game.hero.position).length()
		if d < 14.0:
			var sp4 := cam.unproject_position(s.pos + Vector3(0, 3.4, 0))
			_str(sp4 - Vector2(110, 10), s.name, 14, Color(0.6, 0.8, 1.0) if s.owner == 0 else Color(1, 0.55, 0.45), HORIZONTAL_ALIGNMENT_CENTER, 220)
			if s.owner == 1 and s.cap > 0.0:
				_bar(Rect2(sp4 - Vector2(40, 0), Vector2(80, 6)), s.cap / Landmarks.CAPTURE_TIME, Color(0.4, 0.7, 1.0))
			elif s.owner == 1 and d < 5.0:
				_str(sp4 + Vector2(-110, 14), "Clear nearby foes and stand here to capture", 12, DIM, HORIZONTAL_ALIGNMENT_CENTER, 220)
			elif s.owner == 0 and s.hp < s.max_hp:
				_bar(Rect2(sp4 - Vector2(40, 0), Vector2(80, 5)), s.hp / s.max_hp, Color(0.4, 0.7, 1.0))
	# Loot labels.
	for dr in game.items.drops:
		if (dr.pos - game.hero.position).length() < 12.0:
			var lp := cam.unproject_position(dr.pos + Vector3(0, 0.9, 0))
			_str(lp - Vector2(100, 0), dr.item.name, 13, Items.RARITY_COLORS[dr.item.rarity], HORIZONTAL_ALIGNMENT_CENTER, 200)
	var h := game.hero
	if h.alive and game.state != "title":
		var hp_p := cam.unproject_position(h.position + Vector3(0, 2.0, 0))
		_bar(Rect2(hp_p - Vector2(24, 0), Vector2(48, 5)), h.hp / h.max_hp, Color(0.3, 0.9, 0.35))
		var tot := h.carry_total()
		if tot > 0.0:
			_bar(Rect2(hp_p + Vector2(-24, 8), Vector2(48, 3)), tot / h.carry_cap, GOLD)


func _draw_top_left() -> void:
	var h := game.hero
	_panel(Rect2(10, 10, 300, 128))
	_str(Vector2(22, 34), "Merlin", 18, TEXT)
	_str(Vector2(200, 34), "Level %d" % h.level, 18, Color(0.6, 0.85, 1.0))
	_bar(Rect2(22, 44, 276, 16), h.hp / h.max_hp, Color(0.8, 0.18, 0.15))
	_str(Vector2(22, 57), "%d / %d" % [int(h.hp), int(h.max_hp)], 13, TEXT, HORIZONTAL_ALIGNMENT_CENTER, 276)
	_bar(Rect2(22, 66, 276, 6), h.xp / h.xp_next, Color(0.35, 0.75, 1.0))
	# potions
	for i in h.potion_max:
		var pc := Vector2(30 + i * 20, 90)
		if i < h.potions:
			draw_circle(pc, 7, Color(0.9, 0.15, 0.2))
			draw_rect(Rect2(pc + Vector2(-2, -12), Vector2(4, 5)), Color(0.8, 0.8, 0.85))
		else:
			draw_arc(pc, 7, 0, TAU, 12, Color(0.5, 0.4, 0.4), 1.5)
	_str(Vector2(30 + h.potion_max * 20, 95), "SPACE", 11, DIM)
	# carried pack
	var tot := h.carry_total()
	var pack_col := Color(1, 0.55, 0.35) if tot >= h.carry_cap - 0.01 else DIM
	_str(Vector2(22, 125), "Ore pack", 15, pack_col)
	_res(Vector2(100, 125), tot, GOLD)
	_str(Vector2(150, 125), "/ %d" % int(h.carry_cap), 15, pack_col)
	# weapons list
	var y := 156.0
	for k in h.weapons:
		_str(Vector2(16, y), "%s %d" % [Hero.WEAPONS[k].name, h.weapons[k]], 13, Color(0.85, 0.85, 0.75))
		y += 16
	for k in h.passives:
		_str(Vector2(16, y), "%s %d" % [Hero.PASSIVES[k].name, h.passives[k]], 13, DIM)
		y += 16
	for r in h.relics:
		_str(Vector2(16, y), "Relic: " + r, 13, GOLD)
		y += 16
	# Worn gear (auto-equipped).
	y += 6
	var gx := 16.0
	for slot in Items.SLOTS:
		var gr := Rect2(gx, y, 30, 30)
		if h.gear.has(slot):
			_item_icon(gr, h.gear[slot])
			if gr.has_point(get_viewport().get_mouse_position()):
				_tooltip(get_viewport().get_mouse_position(), h.gear[slot], null)
		else:
			draw_rect(gr, Color(0.08, 0.08, 0.08, 0.6))
			draw_rect(gr, Color(0.3, 0.28, 0.25), false, 1.0)
		gx += 34
	y += 46
	for l in loot_log:
		var lc: Color = l[1]
		lc.a = clampf(l[2], 0.0, 1.0)
		_str(Vector2(16, y), l[0], 12, lc)
		y += 15


func _res(p: Vector2, v: float, c: Color) -> void:
	draw_circle(p + Vector2(5, -5), 5, c)
	_str(p + Vector2(13, 0), str(int(v)), 15, c)


func _draw_top_center(vs: Vector2) -> void:
	var w := 360.0
	var x := (vs.x - w) * 0.5
	_panel(Rect2(x, 10, w, 74))
	var c := game.castle
	var flash := c.hit_flash > 0.0
	_str(Vector2(x + 12, 30), "Camelot", 14, Color(0.6, 0.75, 1.0))
	_bar(Rect2(x + 90, 19, w - 102, 12), c.hp / c.max_hp, Color(1, 0.4, 0.3) if flash else Color(0.3, 0.55, 1.0))
	_str(Vector2(x + 12, 52), "Citadel", 14, Color(1.0, 0.5, 0.45))
	var shielded := game.marks.shield_up
	_bar(Rect2(x + 90, 41, w - 102, 12), game.citadel_hp / Game.CITADEL_HP, Color(0.55, 0.3, 0.7) if shielded else (Color(1, 1, 1) if game.citadel_flash > 0 else Color(0.75, 0.12, 0.12)))
	if shielded:
		_str(Vector2(x + 90, 52), "SHIELDED — %d Dread Wards remain" % game.marks.wards_alive(), 11, TEXT, HORIZONTAL_ALIGNMENT_CENTER, w - 102)
	var wt := "Wave %d in %d s" % [game.wave + 1, int(ceil(game.wave_t))]
	if not game.spawn_queue.is_empty():
		wt = "Wave %d is marching!" % game.wave
	_str(Vector2(x, 76), wt, 14, Color(1, 0.7, 0.55) if game.wave_t < 10.0 or not game.spawn_queue.is_empty() else DIM, HORIZONTAL_ALIGNMENT_CENTER, w)
	if game.castle_hit_t > 0.0 and game.state == "play" and int(game.time * 4.0) % 2 == 0:
		_str(Vector2(x, 102), "CAMELOT IS UNDER ATTACK!", 16, Color(1, 0.35, 0.3), HORIZONTAL_ALIGNMENT_CENTER, w)


func _draw_top_right(vs: Vector2) -> void:
	var w := 230.0
	var x := vs.x - w - 10
	_panel(Rect2(x, 10, w, 74))
	_str(Vector2(x + 12, 30), "Treasury", 14, DIM)
	draw_circle(Vector2(x + 20, 50), 8, GOLD)
	draw_circle(Vector2(x + 20, 50), 5, GOLD.darkened(0.25))
	_str(Vector2(x + 34, 57), "%d gold" % int(game.castle.gold), 20, GOLD)
	var army := 0
	for s in game.horde.soldiers:
		if s.alive: army += 1
	_str(Vector2(x + 140, 57), "%d army" % army, 13, Color(0.6, 0.75, 1.0))
	var inc := game.marks.income_rate()
	if inc > 0.0:
		_str(Vector2(x + 140, 76), "+%.1f/s" % inc, 12, GOLD)
	var mins := int(game.play_time) / 60
	var secs := int(game.play_time) % 60
	_str(Vector2(x + 12, 76), "%d:%02d   %d slain" % [mins, secs, game.kills], 13, DIM)
	_str(Vector2(x + 140, 30), "%d fps %s" % [int(game.fps_now), ["L", "M", "H"][game.quality]], 12, DIM, HORIZONTAL_ALIGNMENT_RIGHT, 80)


## Read-only: Camelot's steward builds on its own. Shows levels and what's next.
func _draw_upgrades(vs: Vector2) -> void:
	var c := game.castle
	var n := Castle.UPGRADES.size()
	var avail := vs.x - 170.0 * 1.5 - 40.0
	var bw := minf(108.0, (avail - (n - 1) * 4.0) / n)
	var total := n * bw + (n - 1) * 4.0
	var x0 := maxf(10.0, (avail - total) * 0.5 + 10.0)
	var y0 := vs.y - 34.0
	var nk := c.next_key()
	if nk != "":
		var cost := c.cost_of(nk)
		_str(Vector2(x0, y0 - 8), "Camelot's steward is saving for  %s  (%d / %d gold)" % [c.upgrade_name(nk), int(c.gold), cost], 14, EDGE)
		_bar(Rect2(x0 + total - 120, y0 - 18, 120, 8), c.gold / maxf(1.0, cost), GOLD)
	else:
		_str(Vector2(x0, y0 - 8), "Camelot is fully built!", 14, GOLD)
	var mp := get_viewport().get_mouse_position()
	for i in n:
		var u: Dictionary = Castle.UPGRADES[i]
		var r := Rect2(x0 + i * (bw + 4.0), y0, bw, 24)
		var lv := c.level(u.key)
		draw_rect(r, Color(0.08, 0.08, 0.07, 0.8) if u.key != nk else Color(0.16, 0.14, 0.08, 0.9))
		draw_rect(r, EDGE if u.key == nk else Color(0.35, 0.32, 0.28), false, 1.0)
		_str(r.position + Vector2(5, 13), u.name, 11, TEXT if lv > 0 else DIM)
		for k in Castle.MAX_LEVEL:
			draw_rect(Rect2(r.position + Vector2(5 + k * 8, 17), Vector2(6, 3)), GOLD if k < lv else Color(0.3, 0.28, 0.25))
		if r.has_point(mp):
			_str(Vector2(x0, y0 - 28), "%s — %s" % [u.name, u.desc], 13, TEXT)


func _draw_minimap(vs: Vector2) -> void:
	var size := 170.0 if not big_map else minf(vs.y * 0.7, 480.0)
	var center := Vector2(vs.x - size * 0.75 - 12, vs.y - size * 0.75 - 12) if not big_map else vs * 0.5
	var scale := size / Maze.G
	var half := Vector2(Maze.G, Maze.G) * 0.5
	draw_circle(center, size * 0.74, Color(0.05, 0.05, 0.04, 0.75))
	draw_arc(center, size * 0.74, 0, TAU, 48, EDGE, 1.5)
	# Rotate 45 degrees so the map matches the isometric view.
	draw_set_transform(center, PI * 0.25, Vector2(scale, scale))
	draw_texture(map_tex, -half)
	var hp := game.hero.position / Maze.T
	var m := game.maze
	for n in game.nodes.list:
		if n.amount <= 0.0:
			continue
		var t := Maze.tile_of(n.pos)
		if m.explored[Maze.idx(t)] == 0:
			continue
		draw_rect(Rect2(Vector2(n.pos.x, n.pos.z) / Maze.T - half - Vector2(0.6, 0.6), Vector2(1.2, 1.2)), GOLD)
	for b in game.nodes.books:
		if not b.taken and m.explored[Maze.idx(Maze.tile_of(b.pos))] != 0:
			draw_rect(Rect2(Vector2(b.pos.x, b.pos.z) / Maze.T - half - Vector2(1.1, 1.1), Vector2(2.2, 2.2)), Color(0.5, 0.75, 1.0))
	for s in game.horde.soldiers:
		if s.alive:
			draw_rect(Rect2(Vector2(s.pos.x, s.pos.z) / Maze.T - half - Vector2(0.5, 0.5), Vector2(1, 1)), Color(0.4, 0.6, 1.0))
	for w in game.horde.workers:
		if w.alive:
			draw_rect(Rect2(Vector2(w.pos.x, w.pos.z) / Maze.T - half - Vector2(0.5, 0.5), Vector2(1, 1)), Color(0.9, 0.85, 0.6))
	for u in game.horde.enemies:
		var p := Vector2(u.pos.x, u.pos.z) / Maze.T
		if u.mode == "camp" and m.explored[Maze.idx(Maze.tile_of(u.pos))] == 0:
			continue
		if u.mini >= 0:
			if m.explored[Maze.idx(Maze.tile_of(u.pos))] != 0:
				draw_circle(p - half, 1.6, Color(1, 0.6, 0.1))
			continue
		draw_rect(Rect2(p - half - Vector2(0.5, 0.5), Vector2(1, 1)), Color(1, 0.25, 0.2) if not u.boss else Color(1, 0.8, 0.2))
	for a in game.horde.allies:
		if a.alive:
			draw_rect(Rect2(Vector2(a.pos.x, a.pos.z) / Maze.T - half - Vector2(0.5, 0.5), Vector2(1, 1)), Color(0.5, 0.75, 1.0))
	# Shrines and wards are landmarks: always shown.
	for sh in game.marks.shrines:
		var spm := Vector2(sh.pos.x, sh.pos.z) / Maze.T - half
		draw_circle(spm, 1.9, Color(0, 0, 0, 0.8))
		draw_circle(spm, 1.4, Color(0.45, 0.7, 1.0) if sh.owner == 0 else Color(0.95, 0.4, 0.3))
	for wd in game.marks.wards:
		if wd.alive:
			var wp := Vector2(wd.pos.x, wd.pos.z) / Maze.T - half
			draw_rect(Rect2(wp - Vector2(1.8, 1.8), Vector2(3.6, 3.6)), Color(0, 0, 0, 0.8))
			draw_rect(Rect2(wp - Vector2(1.2, 1.2), Vector2(2.4, 2.4)), Color(0.75, 0.25, 0.9))
	# Fortress markers always shown.
	var cp := Vector2(m.castle_pos.x, m.castle_pos.z) / Maze.T - half
	draw_rect(Rect2(cp - Vector2(1.5, 1.5), Vector2(3, 3)), Color(0.45, 0.65, 1.0))
	var dp := Vector2(m.citadel_pos.x, m.citadel_pos.z) / Maze.T - half
	draw_rect(Rect2(dp - Vector2(1.5, 1.5), Vector2(3, 3)), Color(0.95, 0.2, 0.15))
	if game.hero.alive:
		draw_circle(Vector2(hp.x, hp.z) - half, 1.2, Color(1, 1, 0.6))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_str(Vector2(center.x - 60, center.y + size * 0.74 + 2), "M: map", 11, DIM, HORIZONTAL_ALIGNMENT_CENTER, 120)


func _draw_levelup(vs: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, vs), Color(0, 0, 0, 0.55))
	_str(Vector2(0, vs.y * 0.25), game.choice_title, 30, Color(0.6, 0.9, 1.0), HORIZONTAL_ALIGNMENT_CENTER, vs.x)
	var n := game.choices.size()
	var cw := 250.0
	var ch := 150.0
	var gap := 24.0
	var x0 := (vs.x - (n * cw + (n - 1) * gap)) * 0.5
	var y0 := vs.y * 0.34
	var mp := get_viewport().get_mouse_position()
	for i in n:
		var c: Dictionary = game.choices[i]
		var r := Rect2(x0 + i * (cw + gap), y0, cw, ch)
		_choice_rects.append(r)
		var hover := r.has_point(mp)
		draw_rect(r, Color(0.1, 0.12, 0.16, 0.95) if not hover else Color(0.16, 0.2, 0.26, 0.98))
		draw_rect(r, Color(0.6, 0.85, 1.0) if hover else EDGE, false, 2.0)
		var tag := "NEW SPELL" if c.type == "weapon" and c.level == 1 else ("SPELL" if c.type == "weapon" else "BLESSING")
		_str(r.position + Vector2(14, 26), "%d   %s" % [i + 1, tag], 13, DIM)
		_str(r.position + Vector2(14, 60), c.name, 22, TEXT)
		if c.level > 0:
			_str(r.position + Vector2(14, 86), "Level %d" % c.level, 15, GOLD)
		_str(r.position + Vector2(14, 120), c.desc, 15, Color(0.8, 0.85, 0.8))


func _draw_overlay(vs: Vector2, title: String, sub: String) -> void:
	draw_rect(Rect2(Vector2.ZERO, vs), Color(0, 0, 0, 0.5))
	_str(Vector2(0, vs.y * 0.42), title, 42, TEXT, HORIZONTAL_ALIGNMENT_CENTER, vs.x)
	_str(Vector2(0, vs.y * 0.42 + 40), sub, 18, DIM, HORIZONTAL_ALIGNMENT_CENTER, vs.x)


func _draw_end(vs: Vector2, won: bool) -> void:
	var a := clampf(game.end_t * 0.6, 0.0, 0.65)
	draw_rect(Rect2(Vector2.ZERO, vs), Color(0, 0, 0, a))
	if game.end_t < 1.5:
		return
	var title := "VICTORY" if won else "CAMELOT HAS FALLEN"
	_str(Vector2(0, vs.y * 0.36), title, 48, GOLD if won else Color(1, 0.4, 0.35), HORIZONTAL_ALIGNMENT_CENTER, vs.x)
	var mins := int(game.play_time) / 60
	var secs := int(game.play_time) % 60
	var lines := [
		"Time  %d:%02d" % [mins, secs],
		"Waves survived  %d" % game.wave,
		"Foes slain  %d" % game.kills,
		"Hero level  %d" % game.hero.level,
		"Gold earned  %d" % int(game.stats_delivered),
	]
	for i in lines.size():
		_str(Vector2(0, vs.y * 0.36 + 48 + i * 26), lines[i], 18, TEXT, HORIZONTAL_ALIGNMENT_CENTER, vs.x)
	_str(Vector2(0, vs.y * 0.36 + 200), "Click or press Enter to play again", 18, DIM, HORIZONTAL_ALIGNMENT_CENTER, vs.x)


func _draw_title(vs: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, vs), Color(0, 0, 0, 0.66))
	var y := vs.y * 0.13
	_str(Vector2(0, y), "AVALON SIEGE", 60, GOLD, HORIZONTAL_ALIGNMENT_CENTER, vs.x)
	_str(Vector2(0, y + 36), "Gather. Build. Break the Dread Citadel.", 19, TEXT, HORIZONTAL_ALIGNMENT_CENTER, vs.x)
	var lines := [
		"You are Merlin. Click & hold (or WASD) to move; your spells cast on their own.",
		"Mine gold and bank it at Camelot; its steward builds miners, towers and your army on its own.",
		"Each wave, Camelot's host marches out to meet the Dread Army. The Dread grows stronger every era.",
		"Capture Ley Shrines for gold and waypoints (T). Hunt spellbooks, mini-bosses and loot.",
		"Three Dread Wards shield the Citadel. Destroy them, face the Dread Lord, and end the siege.",
	]
	for i in lines.size():
		_str(Vector2(0, y + 80 + i * 25), lines[i], 16, Color(0.88, 0.86, 0.8), HORIZONTAL_ALIGNMENT_CENTER, vs.x)
	# Difficulty cards.
	var cw := 220.0
	var ch := 92.0
	var gap := 20.0
	var x0 := (vs.x - (3 * cw + 2 * gap)) * 0.5
	var cy := y + 80 + lines.size() * 25 + 22
	_str(Vector2(0, cy - 8), "Choose your difficulty", 18, EDGE, HORIZONTAL_ALIGNMENT_CENTER, vs.x)
	var mp := get_viewport().get_mouse_position()
	for i in 3:
		var d: Dictionary = Game.DIFFS[i]
		var r := Rect2(x0 + i * (cw + gap), cy + 6, cw, ch)
		_diff_rects.append(r)
		var sel := i == Game.diff_idx
		var hover := r.has_point(mp)
		draw_rect(r, Color(0.14, 0.13, 0.1, 0.95) if not hover else Color(0.2, 0.18, 0.13, 0.98))
		draw_rect(r, GOLD if sel or hover else Color(0.45, 0.4, 0.32), false, 2.0)
		_str(r.position + Vector2(0, 32), "%d  %s" % [i + 1, d.name], 22, [Color(0.6, 0.9, 0.6), TEXT, Color(1, 0.5, 0.4)][i], HORIZONTAL_ALIGNMENT_CENTER, cw)
		_str(r.position + Vector2(0, 62), d.desc, 13, DIM, HORIZONTAL_ALIGNMENT_CENTER, cw)
	_str(Vector2(0, cy + ch + 46), "SPACE potion · T travel · M map · wheel zoom · P pause · F fullscreen · G graphics · N sound", 14, DIM, HORIZONTAL_ALIGNMENT_CENTER, vs.x)
	if int(game.time * 2.0) % 2 == 0:
		_str(Vector2(0, cy + ch + 76), "Press 1, 2 or 3 — or click a difficulty — to begin", 20, TEXT, HORIZONTAL_ALIGNMENT_CENTER, vs.x)


func _item_icon(r: Rect2, it) -> void:
	var c: Color = Items.RARITY_COLORS[it.rarity]
	draw_rect(r, Color(c.r * 0.18, c.g * 0.18, c.b * 0.18, 0.95))
	draw_rect(r, c, false, 2.0)
	var m := r.get_center()
	var s := r.size.x * 0.28
	match it.slot:
		"staff":
			draw_line(m + Vector2(-s, s), m + Vector2(s * 0.7, -s * 0.7), Color(0.6, 0.42, 0.25), 4.0)
			draw_circle(m + Vector2(s * 0.8, -s * 0.8), s * 0.35, c)
		"hat":
			draw_colored_polygon(PackedVector2Array([m + Vector2(-s * 1.2, s * 0.7), m + Vector2(s * 1.2, s * 0.7), m + Vector2(0, -s * 1.2)]), Color(0.5, 0.34, 0.2))
			draw_line(m + Vector2(-s * 1.2, s * 0.7), m + Vector2(s * 1.2, s * 0.7), c, 3.0)
		"robe":
			draw_colored_polygon(PackedVector2Array([m + Vector2(-s * 0.5, -s), m + Vector2(s * 0.5, -s), m + Vector2(s, s), m + Vector2(-s, s)]), Color(0.5, 0.34, 0.2))
			draw_line(m + Vector2(-s * 0.7, 0), m + Vector2(s * 0.7, 0), c, 2.0)
		"amulet":
			draw_arc(m + Vector2(0, -s * 0.4), s * 0.8, PI * 0.1, PI * 0.9, 10, Color(0.8, 0.7, 0.4), 2.0)
			draw_circle(m + Vector2(0, s * 0.4), s * 0.5, c)
		"ring":
			draw_arc(m, s * 0.7, 0, TAU, 16, Color(0.9, 0.78, 0.4), 3.0)
			draw_circle(m + Vector2(0, -s * 0.7), s * 0.3, c)


func _tooltip(p: Vector2, it, compare) -> void:
	var lines := Items.stat_lines(it)
	var w := 270.0
	var h := 58.0 + lines.size() * 18.0 + (40.0 if compare != null else 0.0)
	var vs := get_viewport_rect().size
	var r := Rect2(minf(p.x + 16, vs.x - w - 8), minf(p.y + 8, vs.y - h - 8), w, h)
	draw_rect(r, Color(0.04, 0.04, 0.05, 0.96))
	draw_rect(r, Items.RARITY_COLORS[it.rarity], false, 1.5)
	_str(r.position + Vector2(10, 22), it.name, 16, Items.RARITY_COLORS[it.rarity])
	_str(r.position + Vector2(10, 40), "%s %s  ·  item level %d" % [Items.RARITY_NAMES[it.rarity], Items.SLOT_NAMES[it.slot], it.ilvl], 12, DIM)
	var yy := 60.0
	for l in lines:
		_str(r.position + Vector2(10, yy), l, 14, Color(0.6, 0.75, 1.0))
		yy += 18
	if compare != null:
		var diff := Items.score(it) - Items.score(compare)
		var txt := "Better than equipped %s" % compare.name if diff > 0.5 else ("Worse than equipped %s" % compare.name if diff < -0.5 else "About equal to equipped")
		_str(r.position + Vector2(10, yy + 6), txt, 13, Color(0.5, 1, 0.5) if diff > 0.5 else (Color(1, 0.5, 0.45) if diff < -0.5 else DIM))
	else:
		_str(r.position + Vector2(10, yy + 6), "Melts down for %d gold" % it.value, 12, DIM)


func _draw_travel(vs: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, vs), Color(0, 0, 0, 0.55))
	var t := game.travel_targets()
	var w := 420.0
	var h := 70.0 + t.size() * 44.0
	var r := Rect2((vs.x - w) * 0.5, (vs.y - h) * 0.5, w, h)
	_panel(r)
	_str(r.position + Vector2(0, 32), "Waypoint Travel", 22, Color(0.6, 0.85, 1.0), HORIZONTAL_ALIGNMENT_CENTER, w)
	var mp := get_viewport().get_mouse_position()
	for i in t.size():
		var br := Rect2(r.position + Vector2(20, 50 + i * 44), Vector2(w - 40, 36))
		_travel_rects.append(br)
		draw_rect(br, Color(0.12, 0.16, 0.22, 0.95) if not br.has_point(mp) else Color(0.18, 0.24, 0.32, 0.98))
		draw_rect(br, Color(0.45, 0.65, 0.9), false, 1.5)
		_str(br.position + Vector2(14, 24), "%d   %s" % [i + 1, t[i][0]], 16, TEXT)
