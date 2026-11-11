// The Sarayu's banks: meadow blending to river sand by vertex colour (R: 0
// meadow, 1 sand). Realistic: world-tiled PBR sets (Poly Haven, CC0).
// Stylised: two-tone value noise per surface, like ground_toon.
shader_type spatial;
render_mode cull_back, depth_draw_opaque;

uniform bool use_textures = false;
uniform sampler2D meadow_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D meadow_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D meadow_arm : filter_linear_mipmap, repeat_enable;
uniform sampler2D sand_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D sand_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D sand_arm : filter_linear_mipmap, repeat_enable;
uniform float tile_metres = 4.0;
uniform vec4 meadow_tint : source_color = vec4(1.0);
uniform vec4 sand_tint : source_color = vec4(1.0);
// Stylised tones.
uniform vec4 meadow_a : source_color = vec4(0.36, 0.42, 0.2, 1.0);
uniform vec4 meadow_b : source_color = vec4(0.46, 0.47, 0.24, 1.0);
uniform vec4 sand_a : source_color = vec4(0.72, 0.62, 0.45, 1.0);
uniform vec4 sand_b : source_color = vec4(0.62, 0.53, 0.38, 1.0);
// Wet sand darkens toward the water line (world height).
uniform float water_level = -0.35;

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
	// Break up the blend line with noise so the bank edge is never a straight seam.
	float n = noise(world_pos.xz * 0.35) * 0.6 + noise(world_pos.xz * 1.7) * 0.4;
	float s = smoothstep(0.25, 0.75, COLOR.r + (n - 0.5) * 0.5);
	float wet = 1.0 - smoothstep(water_level, water_level + 0.45, world_pos.y);
	if (use_textures) {
		vec2 uv = world_pos.xz / tile_metres;
		vec3 ma = texture(meadow_arm, uv).rgb;
		vec3 sa = texture(sand_arm, uv * 0.8).rgb;
		ALBEDO = mix(texture(meadow_albedo, uv).rgb * meadow_tint.rgb, texture(sand_albedo, uv * 0.8).rgb * sand_tint.rgb, s);
		ROUGHNESS = mix(mix(ma.g, sa.g, s), 0.35, wet * 0.8);
		AO = mix(ma.r, sa.r, s);
		AO_LIGHT_AFFECT = 0.5;
		NORMAL_MAP = mix(texture(meadow_normal, uv).rgb, texture(sand_normal, uv * 0.8).rgb, s);
	} else {
		float m = smoothstep(0.3, 0.7, noise(world_pos.xz * 0.6) * 0.6 + noise(world_pos.xz * 2.4) * 0.4);
		ALBEDO = mix(mix(meadow_a.rgb, meadow_b.rgb, m), mix(sand_a.rgb, sand_b.rgb, m), s);
		ROUGHNESS = mix(1.0, 0.5, wet);
		SPECULAR = 0.1;
	}
	ALBEDO *= 1.0 - wet * 0.35;
}
