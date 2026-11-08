// Shared toon shading (Art Bible): 3 cel bands, cool painted shadows,
// soft rim light and an optional specular glint for gold.

uniform vec4 tint : source_color = vec4(1.0);
// 1.0 = colour by region masks painted in the vertex colours. Masks are pure
// 0/1 per channel so they survive any sRGB/linear handling by the renderer:
// none = region_base, R = region_r, G = region_g, B = region_b.
uniform float use_vertex_color : hint_range(0.0, 1.0) = 0.0;
uniform vec4 region_base : source_color = vec4(1.0);
uniform vec4 region_r : source_color = vec4(1.0);
uniform vec4 region_g : source_color = vec4(1.0);
uniform vec4 region_b : source_color = vec4(1.0);
// Greyscale detail map where 0.5 = no change.
uniform sampler2D detail_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float detail_strength : hint_range(0.0, 1.0) = 0.0;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform float normal_strength : hint_range(0.0, 2.0) = 0.0;

uniform vec4 shadow_tint : source_color = vec4(0.62, 0.58, 0.78, 1.0);
uniform float band_softness : hint_range(0.001, 0.2) = 0.03;
uniform vec4 rim_color : source_color = vec4(1.0, 0.92, 0.75, 1.0);
uniform float rim_strength : hint_range(0.0, 2.0) = 0.35;
uniform float rim_power : hint_range(1.0, 8.0) = 3.0;
uniform float specular_strength : hint_range(0.0, 2.0) = 0.0;
// Additive flash (hit feedback, attack wind-up glow). 0 = off.
uniform vec4 flash_color : source_color = vec4(1.0, 0.2, 0.1, 1.0);
uniform float flash : hint_range(0.0, 4.0) = 0.0;
uniform float specular_size : hint_range(0.0, 1.0) = 0.94;

void fragment() {
	vec3 base = tint.rgb;
	if (use_vertex_color > 0.5) {
		vec3 region = region_base.rgb;
		region = mix(region, region_r.rgb, clamp(COLOR.r, 0.0, 1.0));
		region = mix(region, region_g.rgb, clamp(COLOR.g, 0.0, 1.0));
		region = mix(region, region_b.rgb, clamp(COLOR.b, 0.0, 1.0));
		base *= region;
	}
	if (detail_strength > 0.0) {
		float d = texture(detail_tex, UV).r;
		base *= clamp(1.0 + (d - 0.5) * 2.0 * detail_strength, 0.0, 2.0);
	}
	ALBEDO = base;
	if (normal_strength > 0.0) {
		NORMAL_MAP = texture(normal_tex, UV).rgb;
		NORMAL_MAP_DEPTH = normal_strength;
	}
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), rim_power);
	EMISSION = rim_color.rgb * base * rim * rim_strength + flash_color.rgb * flash * (0.35 + rim);
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float lit = smoothstep(0.0, band_softness, ndl) * 0.55
		+ smoothstep(0.45, 0.45 + band_softness, ndl) * 0.45;
	lit *= ATTENUATION;
	vec3 band = mix(shadow_tint.rgb * 0.35, vec3(1.0), lit);
	// Godot multiplies DIFFUSE_LIGHT by ALBEDO afterwards.
	DIFFUSE_LIGHT += band * LIGHT_COLOR / PI;
	if (specular_strength > 0.0) {
		vec3 h = normalize(LIGHT + VIEW);
		float s = step(specular_size, dot(NORMAL, h)) * ATTENUATION;
		SPECULAR_LIGHT += LIGHT_COLOR * s * specular_strength / PI;
	}
}
