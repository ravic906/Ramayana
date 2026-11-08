// Flickering lamp flame (camera-facing, additive).
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;

uniform vec4 color : source_color = vec4(1.0, 0.6, 0.2, 1.0);

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	float flick = 0.85 + 0.15 * sin(TIME * 17.0 + MODEL_MATRIX[3].x * 3.0) * sin(TIME * 11.0 + MODEL_MATRIX[3].z);
	VERTEX *= flick;
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	p.y = p.y * 0.7 + 0.2;
	float d = length(vec2(p.x * 1.6, p.y));
	float core = smoothstep(1.0, 0.0, d);
	ALBEDO = color.rgb * core * 1.6 + vec3(1.0, 0.95, 0.8) * smoothstep(0.35, 0.0, d);
	ALPHA = core;
}
