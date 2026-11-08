// Stylised tank water: deep teal with moving sky-coloured ripple glints.
shader_type spatial;
render_mode cull_back, unshaded;

uniform vec4 deep : source_color = vec4(0.1, 0.32, 0.36, 1.0);
uniform vec4 shallow : source_color = vec4(0.25, 0.55, 0.52, 1.0);
uniform vec4 glint : source_color = vec4(1.0, 0.8, 0.55, 1.0);

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += sin(TIME * 1.4 + world_pos.x * 1.7) * 0.015;
}

void fragment() {
	vec2 p = world_pos.xz;
	float w = sin(p.x * 3.1 + TIME * 1.2) * sin(p.y * 2.7 - TIME * 0.9) + sin((p.x + p.y) * 1.3 + TIME * 0.6);
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	vec3 col = mix(deep.rgb, shallow.rgb, fres);
	col += glint.rgb * smoothstep(1.35, 1.7, w) * 0.6;
	ALBEDO = col;
}
