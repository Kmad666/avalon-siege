class_name Game
extends Node3D
## Fafnir's Bane — map preview. Builds the valley, lights it for a cel-shaded
## dusk, and lets Sigurd fly freely above it so the land can be inspected.

static var inst: Game

const START_ALT := 14.0

var terrain: Terrain
var flyer: Flyer
var camera: Camera3D
var hud: HUD
var sfx: Sfx
var sun: DirectionalLight3D
var env: Environment
var world: Node3D
var time := 0.0

var quality := 1            # 0 low, 1 medium, 2 high
var quality_auto := true
var fps_now := 60.0
var _fps_frames := 0
var _fps_time := 0.0
var _slow := 0

## Places worth a look, for the number keys.
var landmarks: Array = []   # [name, Vector3 focus]

# Test hooks: -- --shots=DIR
var shot_dir := ""
var _shot_i := 0
var _shot_t := 0.0


func _ready() -> void:
	inst = self
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			shot_dir = a.substr(8)
	_setup_input()
	sfx = Sfx.new()
	add_child(sfx)
	_setup_env()
	world = Node3D.new()
	add_child(world)
	terrain = Terrain.new()
	add_child(terrain)
	terrain.generate(1871)
	terrain.build(world)
	_place_landmarks()
	flyer = Flyer.new()
	add_child(flyer)
	camera = Camera3D.new()
	camera.fov = 62.0
	camera.near = 0.15
	camera.far = 700.0
	add_child(camera)
	flyer.setup(self, camera)
	var s := terrain.start
	flyer.teleport(Vector3(s.x, terrain.height_at(s.x, s.y) + START_ALT, s.y), PI)
	hud = HUD.new()
	var layer := CanvasLayer.new()
	add_child(layer)
	layer.add_child(hud)
	hud.setup(self)
	_apply_quality()


func _setup_input() -> void:
	var binds := {
		"fly_fwd": [KEY_W, KEY_UP], "fly_back": [KEY_S, KEY_DOWN],
		"fly_left": [KEY_A, KEY_LEFT], "fly_right": [KEY_D, KEY_RIGHT],
		"fly_up": [KEY_SPACE, KEY_E], "fly_down": [KEY_C, KEY_Q], "fly_boost": [KEY_SHIFT],
	}
	for action in binds:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			for k in binds[action]:
				var ev := InputEventKey.new()
				ev.physical_keycode = k
				InputMap.action_add_event(action, ev)


## Blue hour over a dark land: a deep blue sky graded down to a bright
## horizon, a pale moon throwing cold light and long shadows, and blue haze
## that melts the far hills into the sky.
const SKY_TOP := Color(0.039, 0.18, 0.525)
const SKY_HORIZON := Color(0.188, 0.427, 0.878)

const SKY_SHADER := """
shader_type sky;
uniform vec3 top_color;
uniform vec3 horizon_color;
uniform vec3 ground_color;
uniform float grade_height = 0.55;

vec3 to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(0.04045, c));
}

void sky() {
	float y = EYEDIR.y;
	vec3 col = mix(horizon_color, top_color, smoothstep(0.0, grade_height, y));
	col = mix(col, ground_color, smoothstep(0.0, -0.08, y));
	// The moon: a pale disc with a soft halo, where the light comes from.
	if (LIGHT0_ENABLED) {
		float d = dot(EYEDIR, LIGHT0_DIRECTION);
		col = mix(col, vec3(0.93, 0.95, 1.0), smoothstep(0.99955, 0.9997, d));
		col += vec3(0.25, 0.3, 0.4) * pow(max(d, 0.0), 220.0) * 0.6;
	}
	COLOR = col;
}
"""


func _setup_env() -> void:
	var we := WorldEnvironment.new()
	env = Environment.new()
	var sky := Sky.new()
	var sm := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = SKY_SHADER
	sm.shader = sh
	sm.set_shader_parameter("top_color", Vector3(SKY_TOP.r, SKY_TOP.g, SKY_TOP.b))
	sm.set_shader_parameter("horizon_color", Vector3(SKY_HORIZON.r, SKY_HORIZON.g, SKY_HORIZON.b))
	sm.set_shader_parameter("ground_color", Vector3(0.05, 0.09, 0.2))
	sky.sky_material = sm
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.36, 0.46, 0.8)
	env.ambient_light_energy = 0.95
	# Linear tonemapping so the sky shows exactly the chosen blues.
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.tonemap_exposure = 1.0
	env.fog_enabled = true
	env.fog_light_color = SKY_HORIZON.darkened(0.12)
	env.fog_density = 0.0038
	env.fog_sun_scatter = 0.0
	env.fog_sky_affect = 0.0
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	# A low moon ahead and to the left of the road north: long shadows, and
	# visible in the sky as you fly toward the lair.
	sun.rotation = Vector3(deg_to_rad(-24.0), deg_to_rad(118.0), 0)
	sun.light_color = Color(0.85, 0.9, 1.0)
	sun.light_energy = 3.6
	sun.shadow_enabled = true
	sun.shadow_bias = 0.06
	sun.shadow_normal_bias = 1.5
	add_child(sun)


func _place_landmarks() -> void:
	var t := terrain
	var f := t.forge
	_put(Props.forge(), f, PI * 0.5)
	_light(Vector3(f.x - 2.3, t.height_at(f.x, f.y) + 1.5, f.y + 1.6), Color(1.0, 0.5, 0.18), 3.0, 9.0)
	var fire := t.forge + Vector2(-8.0, 6.0)
	_put(Props.campfire(), fire, 0.0)
	var fl := _put(Props.flame(), fire, 0.0)
	var fm := StandardMaterial3D.new()
	fm.vertex_color_use_as_albedo = true
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fl.material_override = fm
	fl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_light(Vector3(fire.x, t.height_at(fire.x, fire.y) + 1.0, fire.y), Color(1.0, 0.55, 0.2), 2.5, 10.0)
	for rs in t.runestones:
		_put(Props.runestone(), rs, randf() * TAU)
	for i in t.mounds.size():
		var m: Vector2 = t.mounds[i]
		# Doorway on the side facing the path.
		var dir := signf(t.path_x(m.y) - m.x)
		_put(Props.mound_door(), m + Vector2(dir * 6.2, 0), dir * PI * 0.5)
	for k in 9:
		var a := k * TAU / 9.0
		var p := t.ring + Vector2(cos(a), sin(a)) * 9.0
		_put(Props.standing_stone(), p, a, null, randf_range(0.85, 1.2))
	# The pool the wurm drinks from: still black water.
	var water := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(19, 19)
	water.mesh = pm
	var wm := StandardMaterial3D.new()
	wm.albedo_color = Color(0.05, 0.08, 0.1)
	wm.roughness = 0.08
	wm.metallic_specular = 0.9
	water.material_override = wm
	water.position = Vector3(t.pool.x, t.height_at(t.pool.x + 9.5, t.pool.y) - 1.0, t.pool.y)
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(water)
	# Gnitaheath: the cave, the hoard, the bones of those who came before.
	var c := t.cave
	var cy := t.height_at(c.x, c.y + 14.0)
	var arch := _put(Props.cave_arch(), c + Vector2(0, 6.0), 0.0, null, 1.7)
	arch.position.y = cy - 1.0
	var hoard := _put(Props.hoard(), c + Vector2(0, 13.0), 0.3)
	hoard.position.y = cy - 0.3
	# The hoard's glow spills out of the dark: the one warm light on the heath.
	_light(Vector3(c.x, cy + 2.5, c.y + 12.0), Color(1.0, 0.7, 0.3), 4.5, 22.0)
	_light(Vector3(c.x, cy + 5.0, c.y + 3.0), Color(1.0, 0.45, 0.2), 3.0, 16.0)
	var br := RandomNumberGenerator.new()
	br.seed = 5
	for k in 12:
		var bp := c + Vector2(br.randf_range(-18, 18), br.randf_range(16, 60))
		_put(Props.bones(), bp, br.randf() * TAU)
	landmarks = [
		["Regin's Forge", _v3(t.forge)],
		["The Barrows", _v3(t.mounds[0])],
		["The Stone Ring", _v3(t.ring)],
		["The Wurm's Pool", _v3(t.pool)],
		["Gnitaheath", _v3(t.cave + Vector2(0, 70))],
		["Fafnir's Lair", _v3(t.cave + Vector2(0, 14))],
	]


func _v3(p: Vector2) -> Vector3:
	return Vector3(p.x, terrain.height_at(p.x, p.y), p.y)


func _put(mesh: Mesh, p: Vector2, yaw: float, mat: Material = null, s := 1.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	Toon.apply(mi, mat if mat != null else Toon.mat(true))
	mi.position = Vector3(p.x, terrain.height_at(p.x, p.y) - 0.05, p.y)
	mi.rotation.y = yaw
	mi.scale = Vector3(s, s, s)
	world.add_child(mi)
	return mi


func _light(p: Vector3, c: Color, energy: float, rng: float) -> void:
	var l := OmniLight3D.new()
	l.position = p
	l.light_color = c
	l.light_energy = energy
	l.omni_range = rng
	l.shadow_enabled = false
	world.add_child(l)


# ------------------------------------------------------------- loop

func _process(delta: float) -> void:
	time += delta
	_track_fps(delta)
	hud.queue_redraw()
	if shot_dir != "":
		_shots(delta)


func jump_to(i: int) -> void:
	if i < 0 or i >= landmarks.size():
		return
	var focus: Vector3 = landmarks[i][1]
	var from := focus + Vector3(0, 0, 26.0)
	from.y = maxf(terrain.height_at(from.x, from.z), focus.y) + 13.0
	flyer.teleport(from, 0.0)
	flyer.cam_pitch = -0.35
	hud.flash(landmarks[i][0])


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var k := (event as InputEventKey).physical_keycode
		if k >= KEY_1 and k <= KEY_6:
			jump_to(k - KEY_1)
		match k:
			KEY_G:
				quality = (quality + 1) % 3
				quality_auto = false
				_apply_quality()
				hud.flash("Graphics: " + ["Low", "Medium", "High"][quality])
			KEY_N:
				toggle_mute()
			KEY_F:
				var fs := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if fs else DisplayServer.WINDOW_MODE_FULLSCREEN)
			KEY_H:
				hud.visible = not hud.visible


func toggle_mute() -> void:
	sfx.toggle()
	hud.flash("Sound off" if Sfx.muted else "Sound on")


# ------------------------------------------------------------- performance

func _track_fps(delta: float) -> void:
	_fps_frames += 1
	_fps_time += delta
	if _fps_time >= 1.0:
		fps_now = _fps_frames / _fps_time
		_fps_frames = 0
		_fps_time = 0.0
		if quality_auto and time > 5.0 and quality > 0 and shot_dir == "":
			_slow = _slow + 1 if fps_now < 40.0 else 0
			if _slow >= 3:
				_slow = 0
				quality -= 1
				_apply_quality()
				hud.flash("Graphics lowered for smoother play (G to change)")


func _apply_quality() -> void:
	var vp := get_viewport()
	match quality:
		0:
			vp.scaling_3d_scale = 0.7
			sun.shadow_enabled = false
			Toon.set_outlines(false)
			vp.msaa_3d = Viewport.MSAA_DISABLED
		1:
			vp.scaling_3d_scale = 1.0
			sun.shadow_enabled = true
			sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
			sun.directional_shadow_max_distance = 70.0
			Toon.set_outlines(true)
			vp.msaa_3d = Viewport.MSAA_DISABLED
		2:
			vp.scaling_3d_scale = 1.0
			sun.shadow_enabled = true
			sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
			sun.directional_shadow_max_distance = 120.0
			Toon.set_outlines(true)
			vp.msaa_3d = Viewport.MSAA_2X


# ------------------------------------------------------------- test hooks

## Fly to a set of viewpoints and photograph each.
func _shots(delta: float) -> void:
	var t := terrain
	var mid := Terrain.W * 0.5
	# [name, ground point, camera yaw, camera pitch, camera distance, altitude]
	var views := [
		["start", Vector3(t.start.x, 0, t.start.y), 0.0, -0.25, 7.0, 12.0],
		["hero", Vector3(t.start.x, 0, t.start.y - 20.0), 0.6, -0.05, 3.2, 3.0],
		["face", Vector3(t.start.x, 0, t.start.y - 20.0), 0.35, -0.02, 2.6, 3.0],
		["forge", Vector3(t.forge.x - 4.0, 0, t.forge.y + 18.0), 0.2, -0.3, 7.0, 6.0],
		["valley", Vector3(t.path_x(700.0), 0, 700.0), 0.0, -0.35, 9.0, 34.0],
		["ring", Vector3(t.ring.x - 6.0, 0, t.ring.y + 26.0), 0.1, -0.35, 8.0, 12.0],
		["pool", Vector3(t.pool.x - 6.0, 0, t.pool.y + 30.0), 0.1, -0.4, 8.0, 16.0],
		["heath", Vector3(t.path_x(130.0), 0, 130.0), 0.0, -0.25, 8.0, 14.0],
		["lair", Vector3(t.cave.x + 6.0, 0, t.cave.y + 44.0), 0.1, -0.15, 5.0, 6.0],
		["high", Vector3(mid, 0, 960.0), 0.0, -0.5, 12.0, 70.0],
	]
	if _shot_i >= views.size():
		get_tree().quit()
		return
	var v: Array = views[_shot_i]
	if _shot_t == 0.0:
		var p: Vector3 = v[1]
		p.y = t.height_at(p.x, p.z) + v[5]
		flyer.teleport(p, v[2])
		flyer.cam_pitch = v[3]
		flyer.cam_dist = v[4]
		if v[0] == "face":
			flyer.body_yaw = v[2]    # turn to face the camera
			flyer._last_yaw = v[2]
	_shot_t += delta
	if _shot_t > 2.5:
		_shot_t = 0.0
		_shot_i += 1
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/%s.png" % [shot_dir, v[0]])
		print("SHOT %s fps=%.1f draws=%d prims=%d" % [v[0], fps_now,
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)])
