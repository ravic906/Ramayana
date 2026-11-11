// The Sarayu: broad, slow water flowing along the mesh's V axis. Ripples are
// procedural (two scrolling noise layers, no textures); lit, so the sun lays a
// glint path and the sky reflects at grazing angles. Foam at the banks comes
// from vertex colour alpha. Opaque, for mobile.
shader_type spatial;
render_mode cull_back, depth_draw_opaque;

uniform vec4 deep : source_color = vec4(0.12, 0.22, 0.24, 1.0);
uniform vec4 shallow : source_color = vec4(0.3, 0.36, 0.3, 1.0);
uniform vec4 sky_tint : source_color = vec4(0.95, 0.7, 0.5, 1.0);
uniform float flow_speed = 0.35;   // m/s along V (in metres)
uniform float ripple_scale = 0.9;
uniform float ripple_strength = 0.35;
uniform float roughness : hint_range(0.0, 1.0) = 0.08;
uniform float sky_reflect : hint_range(0.0, 1.0) = 0.45;
uniform vec4 foam_color : source_color = vec4(0.85, 0.82, 0.74, 1.0);

varying vec3 world_pos;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

float height(vec2 uv) {
	vec2 a = uv * ripple_scale + vec2(0.0, -TIME * flow_speed * ripple_scale);
	vec2 b = uv * ripple_scale * 2.3 + vec2(TIME * 0.05, -TIME * flow_speed * ripple_scale * 1.6);
	return noise(a) * 0.65 + noise(b) * 0.35;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// UV is metres: x across the river, y along it.
	vec2 uv = UV;
	float e = 0.08;
	float h = height(uv);
	float hx = height(uv + vec2(e, 0.0)) - h;
	float hy = height(uv + vec2(0.0, e)) - h;
	vec3 n_tan = normalize(vec3(-hx * ripple_strength / e, -hy * ripple_strength / e, 1.0));
	NORMAL_MAP = n_tan * 0.5 + 0.5;
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	float foam = COLOR.a * smoothstep(0.45, 0.75, h + COLOR.a * 0.4);
	vec3 col = mix(deep.rgb, shallow.rgb, COLOR.a * 0.6);
	ALBEDO = mix(col, foam_color.rgb, foam * 0.45);
	ROUGHNESS = mix(roughness, 0.8, foam);
	SPECULAR = 0.6;
	METALLIC = 0.0;
	EMISSION = sky_tint.rgb * fres * sky_reflect * (1.0 - foam);
}
