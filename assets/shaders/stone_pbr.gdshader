// Realistic stone for the procedural architecture. The 0/1 vertex-colour
// masks of the shared "arch" mesh pick a layer of the texture arrays:
// none = sandstone, R = red sandstone, G = marble, B = dark stone.
// World-space projection on the dominant axis = one sample per map.
shader_type spatial;
render_mode cull_back;

uniform sampler2DArray albedo_arr : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2DArray normal_arr : filter_linear_mipmap, repeat_enable;
uniform sampler2DArray arm_arr : filter_linear_mipmap, repeat_enable;
uniform vec4 tint_sandstone : source_color = vec4(1.0, 0.86, 0.66, 1.0);
uniform vec4 tint_red : source_color = vec4(1.0, 0.66, 0.52, 1.0);
uniform vec4 tint_marble : source_color = vec4(1.0, 0.98, 0.94, 1.0);
uniform vec4 tint_dark : source_color = vec4(0.5, 0.42, 0.38, 1.0);
uniform float tile_metres = 2.0;
uniform float normal_depth = 1.0;
// Painterly golden-hour grade (warms the albedo slightly).
uniform vec4 grade : source_color = vec4(1.0, 0.94, 0.86, 1.0);
uniform float grade_amount = 0.25;

varying vec3 world_pos;
varying vec3 world_normal;
varying flat float layer;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	layer = COLOR.r > 0.5 ? 1.0 : (COLOR.g > 0.5 ? 2.0 : (COLOR.b > 0.5 ? 3.0 : 0.0));
}

void fragment() {
	vec3 an = abs(world_normal);
	vec2 uv;
	if (an.y >= an.x && an.y >= an.z) {
		uv = world_pos.xz;
	} else if (an.x >= an.z) {
		uv = vec2(world_pos.z, -world_pos.y);
	} else {
		uv = vec2(world_pos.x, -world_pos.y);
	}
	vec3 coord = vec3(uv / tile_metres, layer);
	vec4 tints[4] = vec4[](tint_sandstone, tint_red, tint_marble, tint_dark);
	vec3 albedo = texture(albedo_arr, coord).rgb * tints[int(layer)].rgb;
	vec3 arm = texture(arm_arr, coord).rgb;
	ALBEDO = mix(albedo, albedo * grade.rgb, grade_amount);
	AO = arm.r;
	AO_LIGHT_AFFECT = 0.5;
	ROUGHNESS = arm.g;
	METALLIC = 0.0;
	SPECULAR = 0.4;
	NORMAL_MAP = texture(normal_arr, coord).rgb;
	NORMAL_MAP_DEPTH = normal_depth;
}
