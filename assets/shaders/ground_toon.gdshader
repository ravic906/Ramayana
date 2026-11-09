// Stylised ground: world-space value noise between two tones (forest floor or
// dirt path). Optional soft edges across UV.x for path ribbons.
shader_type spatial;
render_mode cull_back, depth_draw_opaque;

uniform vec4 color_a : source_color = vec4(0.22, 0.24, 0.16, 1.0);
uniform vec4 color_b : source_color = vec4(0.32, 0.27, 0.18, 1.0);
uniform float scale = 0.35;
uniform float soft_edges = 0.0;
uniform vec4 shadow_tint : source_color = vec4(0.5, 0.5, 0.65, 1.0);

varying vec3 world_pos;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz * scale;
	float n = noise(p) * 0.6 + noise(p * 3.1) * 0.3 + noise(p * 9.0) * 0.1;
	ALBEDO = mix(color_a.rgb, color_b.rgb, smoothstep(0.3, 0.7, n));
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	if (soft_edges > 0.0) {
		ALPHA = smoothstep(0.0, soft_edges, UV.x) * smoothstep(1.0, 1.0 - soft_edges, UV.x);
	}
}

void light() {
	float lit = smoothstep(0.0, 0.05, dot(NORMAL, LIGHT)) * ATTENUATION;
	DIFFUSE_LIGHT += mix(shadow_tint.rgb * 0.45, vec3(1.0), lit) * LIGHT_COLOR / PI;
}
