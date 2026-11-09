// Realistic ground: world-space tiled PBR texture set (Poly Haven, CC0), with
// optional soft edges across UV.x for path ribbons.
shader_type spatial;
render_mode cull_back, depth_draw_opaque;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D arm_tex : filter_linear_mipmap, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0);
uniform float tile_metres = 3.0;
uniform float soft_edges = 0.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = world_pos.xz / tile_metres;
	vec3 arm = texture(arm_tex, uv).rgb;
	ALBEDO = texture(albedo_tex, uv).rgb * tint.rgb;
	AO = arm.r;
	AO_LIGHT_AFFECT = 0.5;
	ROUGHNESS = arm.g;
	NORMAL_MAP = texture(normal_tex, uv).rgb;
	if (soft_edges > 0.0) {
		ALPHA = smoothstep(0.0, soft_edges, UV.x) * smoothstep(1.0, 1.0 - soft_edges, UV.x);
	}
}
