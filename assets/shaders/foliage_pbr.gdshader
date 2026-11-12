// Foliage for the Realistic style: alpha cutout + wind sway with standard
// physically based lighting (no toon bands).
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, hint_default_white;
uniform vec4 tint : source_color = vec4(1.0);
uniform float alpha_cut : hint_range(0.0, 1.0) = 0.45;
uniform float wind_strength = 0.05;
uniform float wind_speed = 1.3;
// Height (local units) above which sway reaches full strength.
uniform float sway_height = 3.0;
uniform vec4 shadow_tint : source_color = vec4(0.55, 0.5, 0.7, 1.0);
uniform vec4 rim_color : source_color = vec4(1.0, 0.8, 0.5, 1.0);
uniform float rim_strength = 0.25;
// Ambient fill for baked-lighting levels (set by BakedLighting): foliage
// batches get no light from the lightmap probes on the Mobile renderer.
global uniform vec4 gi_fill;

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float h = clamp(VERTEX.y / sway_height, 0.0, 1.0);
	float phase = TIME * wind_speed + world.x * 0.35 + world.z * 0.27;
	VERTEX.x += sin(phase) * wind_strength * h;
	VERTEX.z += cos(phase * 0.8) * wind_strength * 0.6 * h;
}

void fragment() {
	vec4 c = texture(albedo_tex, UV);
	ALBEDO = c.rgb * tint.rgb;
	ALPHA = c.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_cut;
	ROUGHNESS = 0.85;
	SPECULAR = 0.25;
	BACKLIGHT = vec3(0.35, 0.4, 0.15);
	float rim = pow(1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 3.0);
	EMISSION = rim_color.rgb * ALBEDO * rim * rim_strength + ALBEDO * gi_fill.rgb;
}
