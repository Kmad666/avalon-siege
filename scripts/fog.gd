class_name Fog
extends ColorRect
## Silent Hill fog: a grey, slowly drifting haze that swallows everything
## beyond a short radius around Merlin. One full-screen quad, a few noise
## lookups per pixel; cheap on integrated graphics.

const SHADER := """
shader_type canvas_item;
render_mode unshaded;

uniform vec2 screen_size = vec2(1280.0, 720.0);
uniform vec2 center = vec2(640.0, 360.0);
uniform vec2 radii = vec2(200.0, 160.0);
uniform float fade = 1.75;
uniform float max_alpha = 0.94;
uniform float t = 0.0;
uniform vec3 fog_color = vec3(0.6, 0.61, 0.6);

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	vec2 px = UV * screen_size;
	vec2 d = (px - center) / radii;
	float r = length(d);
	float n = noise(px * 0.0045 + vec2(t * 0.06, t * 0.025)) * 0.6
		+ noise(px * 0.013 - vec2(t * 0.09, -t * 0.03)) * 0.4;
	float a = smoothstep(1.0, fade, r + (n - 0.5) * 0.45);
	a = max(a * max_alpha, 0.08 + 0.1 * n);
	COLOR = vec4(fog_color * (0.9 + 0.2 * n), a);
}
"""

var mat := ShaderMaterial.new()


func _ready() -> void:
	var sh := Shader.new()
	sh.code = SHADER
	mat.shader = sh
	material = mat
	color = Color.WHITE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


## Centre the clear patch on a world point; `radius` is the clear distance in metres.
func track(cam: Camera3D, world: Vector3, radius: float, time_s: float) -> void:
	var vs := get_viewport_rect().size
	size = vs
	var px_per_m := vs.y / cam.size
	mat.set_shader_parameter("screen_size", vs)
	mat.set_shader_parameter("center", cam.unproject_position(world))
	# The camera looks down at 55 degrees, so ground depth is foreshortened.
	mat.set_shader_parameter("radii", Vector2(radius * px_per_m, radius * px_per_m * 0.82))
	mat.set_shader_parameter("t", time_s)
