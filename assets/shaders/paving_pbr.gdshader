// Realistic sandstone paving (Poly Haven, CC0) with the rangoli medallion
// kept as a polished stone inlay.
shader_type spatial;
render_mode cull_back;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D arm_tex : filter_linear_mipmap, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0, 0.88, 0.7, 1.0);
uniform float tile_metres = 2.5;
uniform vec2 medallion_center = vec2(0.0, -28.0);
uniform float medallion_radius = 9.0;
uniform vec4 inlay_saffron : source_color = vec4(0.93, 0.5, 0.12, 1.0);
uniform vec4 inlay_red : source_color = vec4(0.62, 0.12, 0.1, 1.0);
uniform vec4 inlay_white : source_color = vec4(0.95, 0.92, 0.84, 1.0);
uniform vec4 inlay_blue : source_color = vec4(0.18, 0.28, 0.55, 1.0);

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

vec3 medallion(vec2 p, vec3 base) {
	vec2 q = p - medallion_center;
	float r = length(q) / medallion_radius;
	if (r > 1.0) {
		return base;
	}
	float a = atan(q.y, q.x);
	vec3 col = base;
	// Outer ring band.
	col = mix(col, inlay_red.rgb, step(0.9, r) * step(r, 0.97));
	col = mix(col, inlay_white.rgb, step(0.87, r) * step(r, 0.9));
	// Lotus petals (16).
	float petal = abs(cos(a * 8.0));
	float petal_r = 0.55 + 0.3 * pow(petal, 0.6);
	col = mix(col, inlay_saffron.rgb, step(0.45, r) * step(r, petal_r) * step(r, 0.86));
	col = mix(col, inlay_white.rgb, step(0.45, r) * step(abs(r - petal_r), 0.015) * step(r, 0.86));
	// Inner star (8 points) and core.
	float star = 0.28 + 0.14 * pow(abs(cos(a * 4.0)), 3.0);
	col = mix(col, inlay_blue.rgb, step(0.16, r) * step(r, star));
	col = mix(col, inlay_red.rgb, step(r, 0.16));
	col = mix(col, inlay_saffron.rgb, step(r, 0.07));
	return col;
}

void fragment() {
	vec2 uv = world_pos.xz / tile_metres;
	vec3 stone = texture(albedo_tex, uv).rgb * tint.rgb;
	vec3 arm = texture(arm_tex, uv).rgb;
	vec3 col = medallion(world_pos.xz, stone);
	float inlay = step(0.02, distance(col, stone));
	ALBEDO = mix(col, col * (0.85 + 0.3 * stone), inlay * 0.6);
	AO = arm.r;
	AO_LIGHT_AFFECT = 0.5;
	ROUGHNESS = mix(arm.g, 0.35, inlay);
	SPECULAR = 0.45;
	NORMAL_MAP = mix(texture(normal_tex, uv).rgb, vec3(0.5, 0.5, 1.0), inlay * 0.7);
}
