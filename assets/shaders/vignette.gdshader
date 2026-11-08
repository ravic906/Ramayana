// Focus vignette: darkens and warms the screen edges while drawing.
shader_type canvas_item;

uniform float strength : hint_range(0.0, 1.0) = 0.0;
uniform vec4 edge_color : source_color = vec4(0.08, 0.04, 0.02, 1.0);
uniform vec4 glow_color : source_color = vec4(1.0, 0.8, 0.3, 1.0);
uniform float glow : hint_range(0.0, 1.0) = 0.0;
// Red pulse when Rama is hurt.
uniform float hurt : hint_range(0.0, 1.0) = 0.0;
// Orange flash when an astra detonates.
uniform float fire : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 p = UV - 0.5;
	p.x *= 1.6;
	float d = smoothstep(0.35, 0.95, length(p));
	vec3 col = mix(edge_color.rgb, glow_color.rgb, glow * 0.6);
	col = mix(col, vec3(0.75, 0.02, 0.02), hurt);
	col = mix(col, vec3(1.0, 0.55, 0.15), fire);
	float a = max(d * strength, max(d * hurt * 0.9, (0.25 + d * 0.6) * fire));
	COLOR = vec4(col, a);
}
