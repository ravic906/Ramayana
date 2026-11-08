// Distant bird silhouettes: wings flap in the vertex shader (per instance).
shader_type spatial;
render_mode unshaded, cull_disabled;

uniform vec4 color : source_color = vec4(0.16, 0.1, 0.12, 1.0);

void vertex() {
	float phase = TIME * 9.0 + float(INSTANCE_ID) * 1.7;
	VERTEX.y += sin(phase) * abs(VERTEX.x) * 0.7;
}

void fragment() {
	ALBEDO = color.rgb;
}
