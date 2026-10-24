class_name Toon
extends RefCounted
## Cel shading for the whole world: banded toon lighting with hard shadows and
## a rim glint from the low sun, plus an ink-outline pass (inverted hull).
## Everything uses vertex colours, so a handful of materials cover the realm.

const TOON := """
shader_type spatial;
render_mode cull_back, specular_disabled;

uniform float rim_strength = 0.35;
uniform float band_soft = 0.04;
uniform float sway = 0.0;          // > 0 for foliage: gentle wind sway

vec3 to_linear(vec3 c) {
	return mix(pow((c + 0.055) / 1.055, vec3(2.4)), c / 12.92, step(c, vec3(0.04045)));
}

void vertex() {
	if (sway > 0.0) {
		vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
		float k = max(VERTEX.y - 0.6, 0.0) * sway;
		VERTEX.x += sin(TIME * 1.3 + wp.x * 0.21 + wp.z * 0.13) * k * 0.05;
		VERTEX.z += cos(TIME * 1.1 + wp.z * 0.19) * k * 0.04;
	}
}

void fragment() {
	ALBEDO = to_linear(COLOR.rgb);
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	// Three tones: shade, half-lit, lit — with crisp edges.
	float b1 = smoothstep(0.0, band_soft, ndl);
	float b2 = smoothstep(0.45, 0.45 + band_soft, ndl);
	float sh = smoothstep(0.35, 0.55, ATTENUATION);
	float lit = (0.55 * b1 + 0.45 * b2) * sh;
	// Rim: a thin hot edge where surfaces turn away from the viewer, on the lit side.
	float rim = smoothstep(0.62, 0.7, 1.0 - max(dot(NORMAL, VIEW), 0.0)) * b1 * sh;
	DIFFUSE_LIGHT += LIGHT_COLOR * (lit + rim * rim_strength) / 3.14159;
}
"""

const OUTLINE := """
shader_type spatial;
render_mode unshaded, cull_front, specular_disabled;

uniform float width = 0.035;
uniform vec3 ink : source_color = vec3(0.03, 0.03, 0.05);
uniform float sway = 0.0;

void vertex() {
	vec3 n = CUSTOM0.xyz;
	if (dot(n, n) < 0.01) { n = NORMAL; }
	if (sway > 0.0) {
		vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
		float k = max(VERTEX.y - 0.6, 0.0) * sway;
		VERTEX.x += sin(TIME * 1.3 + wp.x * 0.21 + wp.z * 0.13) * k * 0.05;
		VERTEX.z += cos(TIME * 1.1 + wp.z * 0.19) * k * 0.04;
	}
	// Lines thicken a little with distance so silhouettes stay readable.
	float d = length((MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz);
	VERTEX += normalize(n) * width * (1.0 + d * 0.012);
}

void fragment() {
	ALBEDO = ink;
}
"""

static var _toon: ShaderMaterial          # no outline (terrain)
static var _toon_ol: ShaderMaterial       # with ink outline
static var _foliage: ShaderMaterial
static var _outline: ShaderMaterial
static var _outline_foliage: ShaderMaterial
static var outlines_on := true


static func _init_all() -> void:
	if _toon != null:
		return
	var st := Shader.new()
	st.code = TOON
	var so := Shader.new()
	so.code = OUTLINE
	_toon = ShaderMaterial.new()
	_toon.shader = st
	_outline = ShaderMaterial.new()
	_outline.shader = so
	_toon_ol = ShaderMaterial.new()
	_toon_ol.shader = st
	_toon_ol.next_pass = _outline
	_foliage = ShaderMaterial.new()
	_foliage.shader = st
	_foliage.set_shader_parameter("sway", 1.0)
	_foliage.set_shader_parameter("rim_strength", 0.25)
	_outline_foliage = ShaderMaterial.new()
	_outline_foliage.shader = so
	_outline_foliage.set_shader_parameter("sway", 1.0)
	_outline_foliage.set_shader_parameter("width", 0.06)
	_foliage.next_pass = _outline_foliage


## Solid cel-shaded surfaces. `outlined` adds the ink pass.
static func mat(outlined := true) -> ShaderMaterial:
	_init_all()
	return _toon_ol if outlined else _toon


## Foliage: same shading, swaying in the wind, with ink.
static func foliage() -> ShaderMaterial:
	_init_all()
	return _foliage


## Turn the ink pass on or off everywhere (graphics quality).
static func set_outlines(on: bool) -> void:
	_init_all()
	outlines_on = on
	_toon_ol.next_pass = _outline if on else null
	_foliage.next_pass = _outline_foliage if on else null


static func apply(gi: GeometryInstance3D, material: Material, shadows := true) -> void:
	gi.material_override = material
	gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
