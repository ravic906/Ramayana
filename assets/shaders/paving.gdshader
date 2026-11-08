// Sandstone courtyard paving with an inlaid rangoli medallion, all
// procedural in world space (no textures). Toon-lit.
shader_type spatial;
render_mode cull_back;

uniform vec4 stone_a : source_color = vec4(0.8, 0.63, 0.47, 1.0);
uniform vec4 stone_b : source_color = vec4(0.72, 0.55, 0.4, 1.0);
uniform vec4 grout : source_color = vec4(0.55, 0.42, 0.3, 1.0);
uniform float tile_size = 1.6;
uniform vec2 medallion_center = vec2(0.0, -28.0);
uniform float medallion_radius = 9.0;
uniform vec4 inlay_saffron : source_color = vec4(0.93, 0.5, 0.12, 1.0);
uniform vec4 inlay_red : source_color = vec4(0.62, 0.12, 0.1, 1.0);
uniform vec4 inlay_white : source_color = vec4(0.95, 0.92, 0.84, 1.0);
uniform vec4 inlay_blue : source_color = vec4(0.18, 0.28, 0.55, 1.0);
uniform vec4 shadow_tint : source_color = vec4(0.6, 0.5, 0.72, 1.0);

varying vec3 world_pos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

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
	vec2 p = world_pos.xz;
	vec2 cell = floor(p / tile_size);
	vec2 f = fract(p / tile_size);
	float edge = min(min(f.x, 1.0 - f.x), min(f.y, 1.0 - f.y));
	float g = smoothstep(0.012, 0.035, edge);
	vec3 stone = mix(stone_a.rgb, stone_b.rgb, hash(cell));
	stone *= 0.94 + 0.08 * hash(cell * 3.1 + floor(f * 6.0));
	vec3 col = mix(grout.rgb, stone, g);
	col = medallion(p, col);
	ALBEDO = col;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float lit = smoothstep(0.0, 0.03, ndl) * ATTENUATION;
	DIFFUSE_LIGHT += mix(shadow_tint.rgb * 0.45, vec3(1.0), lit) * LIGHT_COLOR / PI;
}
