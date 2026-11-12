// Realistic skin for the people built by tools/build_person.gd.
//
// The photographic texture gives pores and variation; the complexion is set
// per character (the texture is divided by its own average colour and laid
// over `complexion`). Lighting is hand-written for the Mobile renderer, which
// has no screen-space subsurface scattering: a wrapped diffuse whose red
// wraps furthest (light seeming to pass through skin at the terminator), a
// normalised Blinn-Phong sheen with Fresnel, and an optional inner glow
// (Rama's luminous skin).
shader_type spatial;
render_mode cull_back;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, hint_default_white;
uniform vec4 source_avg : source_color = vec4(0.5, 0.36, 0.28, 1.0);
uniform vec4 complexion : source_color = vec4(0.58, 0.42, 0.32, 1.0);
uniform float texture_detail : hint_range(0.0, 1.0) = 0.85;
uniform sampler2D detail_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform float detail_normal_strength : hint_range(0.0, 1.0) = 0.25;
uniform float detail_scale = 18.0;
// Subsurface look: how far each channel's light wraps past the terminator.
uniform vec3 wrap = vec3(0.3, 0.14, 0.1);
uniform vec4 scatter_tint : source_color = vec4(0.85, 0.32, 0.22, 1.0);
uniform float roughness : hint_range(0.1, 1.0) = 0.5;
uniform float specular_strength : hint_range(0.0, 1.0) = 0.35;
uniform vec4 glow_color : source_color = vec4(0.45, 0.55, 0.9, 1.0);
uniform float inner_glow : hint_range(0.0, 0.5) = 0.0;
uniform float rim_strength : hint_range(0.0, 1.0) = 0.12;
uniform vec4 flash_color : source_color = vec4(1.0, 0.2, 0.1, 1.0);
uniform float flash : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec3 tex = texture(albedo_tex, UV).rgb;
	vec3 detail = clamp(tex / max(source_avg.rgb, vec3(0.02)), vec3(0.0), vec3(2.0));
	ALBEDO = complexion.rgb * mix(vec3(1.0), detail, texture_detail);
	vec3 dn = texture(detail_normal, UV * detail_scale).xyz;
	NORMAL_MAP = mix(vec3(0.5, 0.5, 1.0), dn, detail_normal_strength);
	ROUGHNESS = roughness;
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	EMISSION = complexion.rgb * glow_color.rgb * inner_glow + complexion.rgb * rim * rim_strength
		+ flash_color.rgb * flash * 0.6;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	vec3 w = clamp((vec3(ndl) + wrap) / (vec3(1.0) + wrap), vec3(0.0), vec3(1.0));
	// The wrapped band beyond the plain Lambert term glows warm (scattered light).
	float lambert = clamp(ndl, 0.0, 1.0);
	vec3 band = max(w - vec3(lambert), vec3(0.0));
	vec3 diffuse = vec3(lambert) + band * scatter_tint.rgb * 0.6;
	DIFFUSE_LIGHT += diffuse * ATTENUATION * LIGHT_COLOR / PI;
	// Sheen: normalised Blinn-Phong with Schlick Fresnel.
	vec3 h = normalize(VIEW + LIGHT);
	float shin = 2.0 / max(roughness * roughness * roughness * roughness, 0.002) - 2.0;
	float spec = pow(clamp(dot(NORMAL, h), 0.0, 1.0), shin) * (shin + 8.0) / (8.0 * PI);
	float fres = 0.028 + 0.972 * pow(1.0 - clamp(dot(VIEW, h), 0.0, 1.0), 5.0);
	SPECULAR_LIGHT += vec3(spec * fres * lambert * specular_strength) * ATTENUATION * LIGHT_COLOR;
}
