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
var _map_t := 0.0


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
func click(p: Vector2) -> bool:
	if game.state == "levelup":
		for i in _choice_rects.size():
			if _choice_rects[i].has_point(p):
				game.choose(i)
		return true
	if game.state == "play":
		for i in _upgrade_rects.size():
			if _upgrade_rects[i].has_point(p):
				game.try_buy(i)
				return true
	return false


func _process(dt: float) -> void:
	msg_t = maxf(0.0, msg_t - dt)
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
	match game.state:
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
		if (u.elite or u.boss or u.kind == "ogre") and u.hp < u.max_hp:
			var sp2 := cam.unproject_position(u.pos + Vector3(0, 2.0 * u.scale + (1.0 if u.kind == "ogre" else 0.0), 0))
			_bar(Rect2(sp2 - Vector2(22, 0), Vector2(44, 4)), u.hp / u.max_hp, Color(0.9, 0.2, 0.15))
	for a in game.horde.allies:
		if a.alive and a.hp < a.max_hp * 0.98:
			var sp3 := cam.unproject_position(a.pos + Vector3(0, 1.6, 0))
			_bar(Rect2(sp3 - Vector2(15, 0), Vector2(30, 3)), a.hp / a.max_hp, Color(0.35, 0.6, 1.0))
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
	_str(Vector2(22, 34), "Sir Percival", 18, TEXT)
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
	_str(Vector2(22, 125), "Pack %d/%d" % [int(tot), int(h.carry_cap)], 15, pack_col)
	_res(Vector2(130, 125), h.carry.gold, GOLD)
	_res(Vector2(185, 125), h.carry.wood, WOOD)
	_res(Vector2(240, 125), h.carry.crystal, CRYS)
	# weapons list
	var y := 156.0
	for k in h.weapons:
		_str(Vector2(16, y), "%s %d" % [Hero.WEAPONS[k].name, h.weapons[k]], 13, Color(0.85, 0.85, 0.75))
		y += 16
	for k in h.passives:
		_str(Vector2(16, y), "%s %d" % [Hero.PASSIVES[k].name, h.passives[k]], 13, DIM)
		y += 16


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
	_bar(Rect2(x + 90, 41, w - 102, 12), game.citadel_hp / Game.CITADEL_HP, Color(1, 1, 1) if game.citadel_flash > 0 else Color(0.75, 0.12, 0.12))
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
	var t := game.castle.treasury
	_res(Vector2(x + 12, 54), t.gold, GOLD)
	_res(Vector2(x + 82, 54), t.wood, WOOD)
	_res(Vector2(x + 152, 54), t.crystal, CRYS)
	var mins := int(game.play_time) / 60
	var secs := int(game.play_time) % 60
	_str(Vector2(x + 12, 76), "%d:%02d   %d slain" % [mins, secs, game.kills], 13, DIM)
	_str(Vector2(x + 140, 30), "%d fps %s" % [int(game.fps_now), ["L", "M", "H"][game.quality]], 12, DIM, HORIZONTAL_ALIGNMENT_RIGHT, 80)


func _draw_upgrades(vs: Vector2) -> void:
	var c := game.castle
	var home := game.at_castle()
	var n := Castle.UPGRADES.size()
	var bh := 62.0
	var gap := 5.0
	# Fit between the left edge and the minimap.
	var avail := vs.x - 170.0 * 1.5 - 40.0
	var bw := minf(130.0, (avail - (n - 1) * gap) / n)
	var scale := bw / 128.0
	var total := n * bw + (n - 1) * gap
	var x0 := maxf(10.0, (avail - total) * 0.5 + 10.0)
	var y0 := vs.y - bh - 12.0
	if not home:
		_str(Vector2(x0, y0 + bh - 4), "Return to Camelot to deliver your pack and build upgrades (1-8)", 15, DIM)
		return
	_str(Vector2(x0, y0 - 8), "CAMELOT — click or press 1-8 to build", 14, EDGE)
	var mp := get_viewport().get_mouse_position()
	for i in n:
		var u: Dictionary = Castle.UPGRADES[i]
		var r := Rect2(x0 + i * (bw + gap), y0, bw, bh)
		_upgrade_rects.append(r)
		var lv := c.level(u.key)
		var maxed := lv >= Castle.MAX_LEVEL
		var ok := c.can_afford(u.key)
		var bg := Color(0.12, 0.16, 0.1, 0.9) if ok else Color(0.09, 0.08, 0.08, 0.85)
		if r.has_point(mp):
			bg = bg.lightened(0.12)
		draw_rect(r, bg)
		draw_rect(r, EDGE if ok else Color(0.4, 0.36, 0.3), false, 1.5)
		_str(r.position + Vector2(6, 16), "%d %s" % [i + 1, u.name], 13, TEXT if ok else DIM)
		for k in Castle.MAX_LEVEL:
			draw_rect(Rect2(r.position + Vector2(6 + k * 9, 22), Vector2(7, 4)), GOLD if k < lv else Color(0.3, 0.28, 0.25))
		if maxed:
			_str(r.position + Vector2(6, 44), "MAX", 13, GOLD)
		else:
			var cost := c.cost_of(u.key)
			var cx := 6.0
			for res in cost:
				var col: Color = {"gold": GOLD, "wood": WOOD, "crystal": CRYS}[res]
				var have: float = c.treasury[res]
				draw_circle(r.position + Vector2(cx + 4, 39), 4, col)
				_str(r.position + Vector2(cx + 10, 44), str(cost[res]), 13, col if have >= cost[res] else Color(0.9, 0.35, 0.3))
				cx += 46.0 * minf(1.0, scale)
		if r.has_point(mp):
			_str(Vector2(x0, y0 - 26), u.desc, 14, TEXT)
		_str(r.position + Vector2(6, 58), "", 11, DIM)


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
		var col: Color = {"wood": WOOD, "gold": GOLD, "crystal": CRYS}[n.kind]
		draw_rect(Rect2(Vector2(n.pos.x, n.pos.z) / Maze.T - half - Vector2(0.6, 0.6), Vector2(1.2, 1.2)), col)
	for u in game.horde.enemies:
		var p := Vector2(u.pos.x, u.pos.z) / Maze.T
		if u.mode == "camp" and m.explored[Maze.idx(Maze.tile_of(u.pos))] == 0:
			continue
		draw_rect(Rect2(p - half - Vector2(0.5, 0.5), Vector2(1, 1)), Color(1, 0.25, 0.2) if not u.boss else Color(1, 0.8, 0.2))
	for a in game.horde.allies:
		if a.alive:
			draw_rect(Rect2(Vector2(a.pos.x, a.pos.z) / Maze.T - half - Vector2(0.5, 0.5), Vector2(1, 1)), Color(0.5, 0.75, 1.0))
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
	_str(Vector2(0, vs.y * 0.25), "LEVEL UP!  Choose a blessing", 30, Color(0.6, 0.9, 1.0), HORIZONTAL_ALIGNMENT_CENTER, vs.x)
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
		var tag := "NEW WEAPON" if c.type == "weapon" and c.level == 1 else ("WEAPON" if c.type == "weapon" else "BLESSING")
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
		"Resources delivered  %d" % int(game.stats_delivered),
	]
	for i in lines.size():
		_str(Vector2(0, vs.y * 0.36 + 48 + i * 26), lines[i], 18, TEXT, HORIZONTAL_ALIGNMENT_CENTER, vs.x)
	_str(Vector2(0, vs.y * 0.36 + 200), "Click or press Enter to play again", 18, DIM, HORIZONTAL_ALIGNMENT_CENTER, vs.x)


func _draw_title(vs: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, vs), Color(0, 0, 0, 0.62))
	var y := vs.y * 0.2
	_str(Vector2(0, y), "AVALON SIEGE", 64, GOLD, HORIZONTAL_ALIGNMENT_CENTER, vs.x)
	_str(Vector2(0, y + 40), "Gather. Build. Break the Dread Citadel.", 20, TEXT, HORIZONTAL_ALIGNMENT_CENTER, vs.x)
	var lines := [
		"Move: click & hold (or WASD / arrows). Your weapons strike on their own.",
		"Stand by golden oaks, gold boulders and mana crystals to gather them.",
		"Carry your pack home to Camelot to bank it, then build upgrades with 1-8.",
		"Every wave, the Dread Army marches from the far corner. Hold Camelot!",
		"Level up from soul gems to gain new weapons and blessings.",
		"Find the Dread Citadel at the far side of the maze and destroy it to win.",
		"",
		"SPACE potion   ·   M map   ·   wheel zoom   ·   P pause   ·   F fullscreen   ·   G graphics   ·   N sound",
	]
	for i in lines.size():
		_str(Vector2(0, y + 100 + i * 28), lines[i], 17, Color(0.88, 0.86, 0.8) if i < 6 else DIM, HORIZONTAL_ALIGNMENT_CENTER, vs.x)
	if int(game.time * 2.0) % 2 == 0:
		_str(Vector2(0, vs.y * 0.86), "Click or press any key to begin", 24, TEXT, HORIZONTAL_ALIGNMENT_CENTER, vs.x)
