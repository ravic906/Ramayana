// Focus vignette: darkens and warms the screen edges while drawing.
shader_type canvas_item;

uniform float strength : hint_range(0.0, 1.0) = 0.0;
uniform vec4 edge_color : source_color = vec4(0.08, 0.04, 0.02, 1.0);
uniform vec4 glow_color : source_color = vec4(1.0, 0.8, 0.3, 1.0);
uniform float glow : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 p = UV - 0.5;
	p.x *= 1.6;
	float d = smoothstep(0.35, 0.95, length(p));
	vec3 col = mix(edge_color.rgb, glow_color.rgb, glow * 0.6);
	COLOR = vec4(col, d * strength);
}
