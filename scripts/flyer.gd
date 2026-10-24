class_name Flyer
extends Node3D
## The hooded hero, flying free for now so the valley can be inspected. A
## third-person orbit camera follows; he leans into flight and his cloak streams.
##
## Mouse: look (click to capture) · WASD: fly · Space/E: up · C/Q: down ·
## Shift: faster · wheel: camera distance.

const SPEED := 16.0
const BOOST := 3.2

var game: Game
var cam: Camera3D
var body: MeshInstance3D
var cloak_pivot: Node3D
var vel := Vector3.ZERO
var cam_yaw := 0.0
var cam_pitch := -0.25
var cam_dist := 7.0
var body_yaw := 0.0
var _lean := 0.0
var _bank := 0.0
var _last_yaw := 0.0


func setup(g: Game, camera: Camera3D) -> void:
	game = g
	cam = camera
	body = MeshInstance3D.new()
	body.mesh = Props.hero_body()
	Toon.apply(body, Toon.hero())
	add_child(body)
	# Glowing eyes in the dark of the hood, with a faint ember light inside it.
	var eyes := MeshInstance3D.new()
	eyes.mesh = Props.hero_eyes()
	Geo.apply(eyes, true)
	body.add_child(eyes)
	var haze := MeshInstance3D.new()
	haze.mesh = Props.hero_eye_haze()
	haze.material_override = Geo.mat_add()
	haze.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(haze)
	var glow := OmniLight3D.new()
	glow.position = Vector3(0, 1.5, 0.32)
	glow.light_color = Props.EYE
	glow.light_energy = 1.2
	glow.omni_range = 0.6
	body.add_child(glow)
	cloak_pivot = Node3D.new()
	cloak_pivot.position = Vector3(0, 1.3, -0.2)
	body.add_child(cloak_pivot)
	var cloak := MeshInstance3D.new()
	cloak.mesh = Props.hero_cloak()
	Toon.apply(cloak, Toon.hero())
	cloak_pivot.add_child(cloak)


func teleport(p: Vector3, yaw: float) -> void:
	position = p
	vel = Vector3.ZERO
	cam_yaw = yaw
	body_yaw = yaw + PI      # the model faces +z; the camera at yaw 0 looks -z
	_last_yaw = body_yaw
	_update_camera(0.0, true)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			cam_dist = maxf(2.5, cam_dist * 0.88)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			cam_dist = minf(40.0, cam_dist * 1.14)
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
			cam_yaw -= mm.relative.x * 0.004
			cam_pitch = clampf(cam_pitch - mm.relative.y * 0.004, -1.45, 0.9)
	elif event is InputEventKey and event.pressed and (event as InputEventKey).physical_keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _process(dt: float) -> void:
	dt = minf(dt, 0.05)
	if game.shot_dir != "":
		_update_camera(dt, true)
		_animate(dt)
		return
	# Fly where the camera looks.
	var look := Vector3(sin(cam_yaw), 0, cos(cam_yaw)) * -1.0
	var fwd3 := (Basis(Vector3.UP, cam_yaw) * Basis(Vector3(1, 0, 0), cam_pitch)) * Vector3(0, 0, -1)
	var right := Vector3(-look.z, 0, look.x)
	var want := Vector3.ZERO
	want += fwd3 * (Input.get_action_strength("fly_fwd") - Input.get_action_strength("fly_back"))
	want += right * (Input.get_action_strength("fly_right") - Input.get_action_strength("fly_left"))
	want.y += Input.get_action_strength("fly_up") - Input.get_action_strength("fly_down")
	if want.length_squared() > 1.0:
		want = want.normalized()
	var sp := SPEED * (BOOST if Input.is_action_pressed("fly_boost") else 1.0)
	vel = vel.lerp(want * sp, minf(1.0, dt * 3.5))
	position += vel * dt
	# Stay inside the valley and above the ground.
	position.x = clampf(position.x, 2.0, Terrain.W - 2.0)
	position.z = clampf(position.z, 2.0, Terrain.L - 2.0)
	var floor_y := game.terrain.height_at(position.x, position.z) + 0.9
	if position.y < floor_y:
		position.y = floor_y
		vel.y = maxf(vel.y, 0.0)
	position.y = minf(position.y, 160.0)
	var flat := Vector2(vel.x, vel.z)
	if flat.length() > 1.0:
		body_yaw = lerp_angle(body_yaw, atan2(vel.x, vel.z), minf(1.0, dt * 5.0))
	_animate(dt)
	_update_camera(dt, false)


func _animate(dt: float) -> void:
	var t := game.time
	var hsp := Vector2(vel.x, vel.z).length()
	# Lean into the flight; bank into turns.
	var turn := wrapf(body_yaw - _last_yaw, -PI, PI) / maxf(dt, 0.001)
	_last_yaw = body_yaw
	_lean = lerpf(_lean, clampf(hsp * 0.03, 0.0, 0.75), minf(1.0, dt * 4.0))
	_bank = lerpf(_bank, clampf(-turn * 0.25, -0.6, 0.6), minf(1.0, dt * 4.0))
	rotation = Vector3.ZERO
	body.rotation = Vector3(_lean, body_yaw, _bank)
	body.position.y = sin(t * 1.8) * 0.12
	# The cloak streams back with speed and flutters.
	var stream := clampf(0.12 + hsp * 0.05 + absf(vel.y) * 0.03, 0.1, 1.35)
	cloak_pivot.rotation.x = -stream + sin(t * 9.0 + hsp) * 0.05 * (0.4 + stream)
	cloak_pivot.rotation.z = sin(t * 5.3) * 0.04


func _update_camera(dt: float, snap: bool) -> void:
	var target := position + Vector3(0, 1.3, 0)
	var dir := (Basis(Vector3.UP, cam_yaw) * Basis(Vector3(1, 0, 0), cam_pitch)) * Vector3(0, 0, 1)
	var want := target + dir * cam_dist
	var ground := game.terrain.height_at(want.x, want.z) + 0.6
	if want.y < ground:
		want.y = ground
	cam.position = want if snap else cam.position.lerp(want, minf(1.0, dt * 12.0))
	cam.look_at(target, Vector3.UP)
