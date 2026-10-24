class_name HUD
extends Control
## Map-preview overlay: where you are, a strip map of the whole valley,
## the controls, and a mute button.

const INK := Color(0.04, 0.04, 0.06, 0.78)
const EDGE := Color(0.7, 0.55, 0.32, 0.9)
const TEXT := Color(0.95, 0.91, 0.82)
const DIM := Color(0.66, 0.62, 0.56)
const GOLD := Color(0.95, 0.75, 0.32)

var game: Game
var font: Font
var map_tex: ImageTexture
var _flash := ""
var _flash_t := 0.0
var _mute_rect := Rect2()
const MAP_SCALE := 0.3   # strip-map pixels per metre


func setup(g: Game) -> void:
	game = g
	font = ThemeDB.fallback_font
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_map()


## Bake the strip map once: ground colour shaded by height.
func _build_map() -> void:
	var t := game.terrain
	var w := int(Terrain.W * MAP_SCALE)
	var h := int(Terrain.L * MAP_SCALE)
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	for py in h:
		for px in w:
			var x := (px + 0.5) / MAP_SCALE
			var z := (py + 0.5) / MAP_SCALE
			var y := t.height_at(x, z)
			var y2 := t.height_at(x + 2.0, z - 2.0)
			var n := Vector3(-(y2 - y), 2.0, -(y - y2)).normalized()
			var c := t._ground_color(x, z, n)
			c = c.lightened(clampf(y / 60.0, 0.0, 0.4))
			var shade := clampf((y2 - y) * 0.15, -0.25, 0.25)
			c = c.lightened(shade) if shade > 0.0 else c.darkened(-shade)
			if t.hill_value(x, z) > 0.45 and absf(x - t.path_x(z)) > 12.0:
				c = c.darkened(0.25)
			img.set_pixel(px, py, c)
	map_tex = ImageTexture.create_from_image(img)


func flash(text: String) -> void:
	_flash = text
	_flash_t = 2.5


func _process(dt: float) -> void:
	_flash_t = maxf(0.0, _flash_t - dt)


func _gui_input(_e: InputEvent) -> void:
	pass


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		if visible and _mute_rect.has_point((event as InputEventMouseButton).position):
			game.toggle_mute()
			get_viewport().set_input_as_handled()


func _str(p: Vector2, text: String, size: int, col: Color, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
	draw_string(font, p + Vector2(1.5, 1.5), text, align, width, size, Color(0, 0, 0, 0.8 * col.a))
	draw_string(font, p, text, align, width, size, col)


func _panel(r: Rect2) -> void:
	draw_rect(r, INK)
	draw_rect(r, EDGE, false, 1.5)


func _draw() -> void:
	var vs := get_viewport_rect().size
	var f := game.flyer
	var t := game.terrain
	# Title and whereabouts.
	_panel(Rect2(12, 12, 300, 92))
	_str(Vector2(24, 38), "FAFNIR'S BANE", 20, GOLD)
	_str(Vector2(24, 58), "Map preview — Sigurd's road to Gnitaheath", 13, DIM)
	var to_lair := maxf(0.0, f.position.z - t.cave.y)
	var alt := f.position.y - t.height_at(f.position.x, f.position.z)
	_str(Vector2(24, 82), "Fafnir's lair: %d m   ·   altitude %d m" % [int(to_lair), int(alt)], 14, TEXT)
	_str(Vector2(24, 98), "%d fps   ·   %s graphics" % [int(game.fps_now), ["Low", "Medium", "High"][game.quality]], 12, DIM)
	# Controls.
	var lines := [
		"Click to look with the mouse  ·  Esc frees the cursor",
		"WASD fly  ·  Space / E up  ·  C / Q down  ·  Shift faster  ·  Wheel zoom",
		"1 Forge  2 Barrows  3 Stone Ring  4 Wurm's Pool  5 Gnitaheath  6 Lair",
		"G graphics  ·  F fullscreen  ·  N sound  ·  H hide this",
	]
	_panel(Rect2(12, vs.y - 96, 520, 84))
	for i in lines.size():
		_str(Vector2(24, vs.y - 74 + i * 19), lines[i], 13, TEXT if i < 3 else DIM)
	_draw_map(vs)
	_draw_mute(vs)
	if _flash_t > 0.0:
		var c := TEXT
		c.a = clampf(_flash_t, 0.0, 1.0)
		_str(Vector2(0, vs.y * 0.22), _flash, 26, c, HORIZONTAL_ALIGNMENT_CENTER, vs.x)
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and game.shot_dir == "" and int(game.time * 1.5) % 2 == 0:
		_str(Vector2(0, vs.y * 0.5 + 60), "Click to take flight", 18, TEXT, HORIZONTAL_ALIGNMENT_CENTER, vs.x)


## The whole valley as a tall strip; north (the lair) at the top.
func _draw_map(vs: Vector2) -> void:
	var t := game.terrain
	var sz := map_tex.get_size()
	var avail := vs.y - 120.0
	var k := minf(1.0, avail / sz.y)
	var dsz := sz * k
	var o := Vector2(vs.x - dsz.x - 18, 60)
	draw_rect(Rect2(o - Vector2(4, 4), dsz + Vector2(8, 8)), INK)
	draw_texture_rect(map_tex, Rect2(o, dsz), false)
	draw_rect(Rect2(o - Vector2(4, 4), dsz + Vector2(8, 8)), EDGE, false, 1.5)
	var s := MAP_SCALE * k
	# Landmarks.
	var marks := [[t.forge, Color(1, 0.55, 0.2)], [t.ring, Color(0.75, 0.75, 0.8)], [t.pool, Color(0.3, 0.55, 0.9)], [t.cave, Color(1, 0.75, 0.3)]]
	for m in t.mounds:
		marks.append([m, Color(0.6, 0.65, 0.5)])
	for mk in marks:
		var mp: Vector2 = mk[0]
		draw_circle(o + mp * s, 3.0, Color(0, 0, 0, 0.8))
		draw_circle(o + mp * s, 2.0, mk[1])
	# Sigurd: an arrow pointing the way he faces.
	var fp := game.flyer.position
	var pp := o + Vector2(fp.x, fp.z) * s
	var yaw := game.flyer.body_yaw
	var dir := Vector2(sin(yaw), cos(yaw))
	var side := Vector2(-dir.y, dir.x)
	draw_colored_polygon(PackedVector2Array([pp + dir * 7, pp - dir * 4 + side * 4, pp - dir * 4 - side * 4]), Color(1, 0.95, 0.7))
	_str(Vector2(o.x - 20, o.y - 10), "Gnitaheath", 11, DIM, HORIZONTAL_ALIGNMENT_CENTER, dsz.x + 40)


func _draw_mute(vs: Vector2) -> void:
	var r := Rect2(vs.x - 260, 14, 34, 34)
	var map_x := vs.x - map_tex.get_size().x * minf(1.0, (vs.y - 120.0) / map_tex.get_size().y) - 18
	r.position.x = map_x - 46
	_mute_rect = r
	draw_rect(r, INK)
	draw_rect(r, EDGE, false, 1.5)
	var c := r.position + Vector2(10, 17)
	var col := TEXT if not Sfx.muted else Color(0.6, 0.55, 0.5)
	draw_rect(Rect2(c + Vector2(-3, -4), Vector2(5, 8)), col)
	draw_colored_polygon(PackedVector2Array([c + Vector2(2, -4), c + Vector2(9, -10), c + Vector2(9, 10), c + Vector2(2, 4)]), col)
	if Sfx.muted:
		draw_line(c + Vector2(13, -5), c + Vector2(21, 5), Color(1, 0.4, 0.35), 2.5)
		draw_line(c + Vector2(21, -5), c + Vector2(13, 5), Color(1, 0.4, 0.35), 2.5)
	else:
		draw_arc(c + Vector2(9, 0), 6, -0.9, 0.9, 8, col, 2.0)
		draw_arc(c + Vector2(9, 0), 11, -0.9, 0.9, 10, col, 2.0)
