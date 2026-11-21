// One look for characters (generated bodies with their own painted textures): the same two-band
// cel light and soft warm rim as the environment's toon_painted shader, over the model's texture
// and normal map. Mobile renderer safe.
shader_type spatial;
render_mode cull_back, depth_draw_opaque;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap;
uniform float normal_strength = 0.8;
uniform bool use_normal = false;
uniform vec4 shadow_tint : source_color = vec4(0.62, 0.5, 0.58, 1.0);
uniform float shadow_floor : hint_range(0.0, 1.0) = 0.62;
uniform float band_softness : hint_range(0.001, 0.3) = 0.08;
uniform vec4 rim_color : source_color = vec4(1.0, 0.86, 0.62, 1.0);
uniform float rim_strength : hint_range(0.0, 2.0) = 0.35;
uniform float flash = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0, 0.9, 0.7, 1.0);

void fragment() {
	vec3 base = texture(albedo_tex, UV).rgb;
	ALBEDO = mix(base, flash_color.rgb, flash);
	if (use_normal) {
		NORMAL_MAP = texture(normal_tex, UV).rgb;
		NORMAL_MAP_DEPTH = normal_strength;
	}
	ROUGHNESS = 0.9;
	SPECULAR = 0.15;
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	EMISSION = rim_color.rgb * base * rim * rim_strength;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float lit = smoothstep(0.0, band_softness, ndl) * ATTENUATION;
	DIFFUSE_LIGHT += mix(shadow_tint.rgb * shadow_floor, vec3(1.0), lit) * LIGHT_COLOR / PI;
}
