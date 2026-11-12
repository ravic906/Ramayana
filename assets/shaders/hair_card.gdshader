// Hair, brows, lashes and beards for the realistic people: alpha-tested
// strand cards whose colour is set per character (the texture gives only
// strand detail and coverage), darker at the roots, with a soft
// anisotropic-looking highlight along the strands.
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;

uniform sampler2D strands_tex : source_color, filter_linear_mipmap, hint_default_white;
uniform vec4 hair_color : source_color = vec4(0.06, 0.045, 0.035, 1.0);
uniform float alpha_cut : hint_range(0.0, 1.0) = 0.35;
uniform float detail : hint_range(0.0, 1.0) = 0.6;
uniform float sheen : hint_range(0.0, 1.0) = 0.35;

void fragment() {
	vec4 t = texture(strands_tex, UV);
	float lum = dot(t.rgb, vec3(0.299, 0.587, 0.114));
	float d = clamp(lum / 0.35, 0.3, 1.6);
	ALBEDO = hair_color.rgb * mix(1.0, d, detail);
	// Opaque path with a cut-out (writing ALPHA would send hair down the
	// transparent path, which the Mobile renderer lights wrongly here).
	if (t.a < alpha_cut) {
		discard;
	}
	ROUGHNESS = 0.55;
	SPECULAR = sheen;
}
