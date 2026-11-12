// Woven cloth for the realistic people's garments (dhoti, uttariya): the
// outfit region masks in the vertex colour pick the palette colour (R the
// lower garment, G the zari border, B the upper cloth), a fine weave and
// soft folds give it texture, and zari catches the light like metal thread.
shader_type spatial;
render_mode cull_disabled;

uniform vec4 region_r : source_color = vec4(0.92, 0.72, 0.18, 1.0);
uniform vec4 region_g : source_color = vec4(0.85, 0.62, 0.2, 1.0);
uniform vec4 region_b : source_color = vec4(0.85, 0.35, 0.12, 1.0);
uniform float weave_scale = 900.0;
uniform float fold_strength : hint_range(0.0, 1.0) = 0.25;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void fragment() {
	vec3 m = COLOR.rgb;
	vec3 base = region_r.rgb * m.r + region_b.rgb * m.b;
	float zari = m.g;
	base = mix(base, region_g.rgb, zari);
	// weave: two crossing thread directions
	vec2 w = UV * weave_scale;
	float weave = 0.5 + 0.5 * sin(w.x) * sin(w.y);
	float n = hash(floor(UV * weave_scale * 0.25));
	// soft folds along the drape (V runs down the garment)
	float fold = 0.5 + 0.5 * sin(UV.x * 60.0 + sin(UV.y * 9.0) * 2.0);
	ALBEDO = base * (0.9 + 0.08 * weave + 0.04 * n) * (1.0 - fold_strength * 0.3 * (1.0 - fold));
	ROUGHNESS = mix(0.85, 0.35, zari);
	METALLIC = zari * 0.6;
	SPECULAR = 0.3;
}
