// Saffron Suryavansha banner: cloth waves from the pole (UV.x = 0) and shows
// a golden sun emblem with rays and a gold border.
shader_type spatial;
render_mode cull_disabled;

uniform vec4 cloth : source_color = vec4(0.95, 0.48, 0.1, 1.0);
uniform vec4 trim : source_color = vec4(0.85, 0.62, 0.18, 1.0);
uniform vec4 sun : source_color = vec4(1.0, 0.82, 0.3, 1.0);
uniform float wave = 0.12;

void vertex() {
	float t = UV.x;
	vec3 world = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	VERTEX.z += sin(TIME * 3.0 - t * 6.0 + world.x) * wave * t;
	VERTEX.y += sin(TIME * 2.1 - t * 4.0) * wave * 0.25 * t;
}

void fragment() {
	vec2 uv = UV;
	vec3 col = cloth.rgb;
	float border = step(min(min(uv.x, 1.0 - uv.x), min(uv.y, 1.0 - uv.y)), 0.06);
	col = mix(col, trim.rgb, border);
	vec2 c = (uv - vec2(0.5, 0.5)) * vec2(1.0, 1.6);
	float r = length(c);
	float a = atan(c.y, c.x);
	float rays = step(r, 0.25 + 0.06 * step(0.0, sin(a * 12.0)));
	col = mix(col, sun.rgb, rays * step(0.17, r));
	col = mix(col, sun.rgb * 1.1, step(r, 0.14));
	ALBEDO = col;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
