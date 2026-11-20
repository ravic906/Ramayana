// Illustrated look for architecture (gate slice): flat colour multiplied by a
// hand-painted texture projected in world space (the Blender kit has no UVs),
// the baked form shading in the vertex colours, three cel bands with cool painted
// shadows, a warm rim and an optional hard glint for gold. Mobile renderer safe.
shader_type spatial;
render_mode cull_back, depth_draw_opaque;

uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D paint_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform float paint_scale = 0.6;       // tiles per metre
uniform float paint_strength : hint_range(0.0, 2.0) = 1.0;
// Painted detail fades with distance so fine marks do not shimmer when the camera moves.
uniform float detail_fade_near = 22.0;
uniform float detail_fade_far = 70.0;
uniform float vertex_shade : hint_range(0.0, 1.0) = 1.0;
// 1.0 = colour by region masks in the vertex colours (the level kit's arch material):
// none = region_base, R = region_r, G = region_g, B = region_b. Replaces vertex_shade.
uniform float use_regions : hint_range(0.0, 1.0) = 0.0;
uniform vec4 region_base : source_color = vec4(1.0);
uniform vec4 region_r : source_color = vec4(1.0);
uniform vec4 region_g : source_color = vec4(1.0);
uniform vec4 region_b : source_color = vec4(1.0);
uniform vec4 shadow_tint : source_color = vec4(0.52, 0.6, 0.92, 1.0);
uniform float shadow_floor : hint_range(0.0, 1.0) = 0.5;
uniform float band_softness : hint_range(0.001, 0.2) = 0.04;
uniform vec4 rim_color : source_color = vec4(1.0, 0.95, 0.85, 1.0);
uniform float rim_strength : hint_range(0.0, 2.0) = 0.3;
uniform float spec_strength : hint_range(0.0, 3.0) = 0.0;
uniform float spec_size : hint_range(0.0, 1.0) = 0.93;
uniform vec4 glow : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float glow_energy : hint_range(0.0, 8.0) = 0.0;

varying vec3 wpos;
varying vec3 wnrm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

vec3 triplanar(vec3 p, vec3 n) {
	vec3 w = pow(abs(n), vec3(4.0));
	w /= (w.x + w.y + w.z);
	vec3 tx = texture(paint_tex, vec2(p.z, -p.y) * paint_scale).rgb;
	vec3 ty = texture(paint_tex, p.xz * paint_scale).rgb;
	vec3 tz = texture(paint_tex, vec2(p.x, -p.y) * paint_scale).rgb;
	return tx * w.x + ty * w.y + tz * w.z;
}

void fragment() {
	vec3 paint = triplanar(wpos, wnrm);
	float dist = length(wpos - CAMERA_POSITION_WORLD);
	float ps = paint_strength * (1.0 - 0.75 * smoothstep(detail_fade_near, detail_fade_far, dist));
	vec3 base = albedo.rgb * clamp(vec3(1.0) + (paint - 0.5) * 2.0 * ps, 0.0, 2.0);
	if (use_regions > 0.5) {
		vec3 region = region_base.rgb;
		region = mix(region, region_r.rgb, clamp(COLOR.r, 0.0, 1.0));
		region = mix(region, region_g.rgb, clamp(COLOR.g, 0.0, 1.0));
		region = mix(region, region_b.rgb, clamp(COLOR.b, 0.0, 1.0));
		base *= region;
	} else {
		base *= mix(vec3(1.0), COLOR.rgb, vertex_shade);
	}
	ALBEDO = base;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	EMISSION = rim_color.rgb * base * rim * rim_strength + glow.rgb * glow_energy;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float lit = smoothstep(0.0, band_softness, ndl) * 0.6 + smoothstep(0.5, 0.5 + band_softness, ndl) * 0.4;
	lit *= ATTENUATION;
	vec3 band = mix(shadow_tint.rgb * shadow_floor, vec3(1.0), lit);
	DIFFUSE_LIGHT += band * LIGHT_COLOR / PI;
	if (spec_strength > 0.0) {
		vec3 h = normalize(LIGHT + VIEW);
		SPECULAR_LIGHT += LIGHT_COLOR * step(spec_size, dot(NORMAL, h)) * spec_strength * ATTENUATION / PI;
	}
}
