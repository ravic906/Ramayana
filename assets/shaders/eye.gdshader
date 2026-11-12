// Eyes for the realistic people: the iris and sclera texture, a wet sheen,
// and the cornea shell (mapped to the texture's pale-blue corner) left clear
// rather than drawn opaque over the iris.
shader_type spatial;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, hint_default_white;
uniform float brightness : hint_range(0.3, 1.5) = 0.85;

void fragment() {
	vec3 c = texture(albedo_tex, UV).rgb;
	if (c.b > c.r + 0.12 && c.b > 0.65) {
		discard;  // the cornea
	}
	// Deepen the iris toward a dark brown (the source irises lean red).
	float sat = max(c.r, max(c.g, c.b)) - min(c.r, min(c.g, c.b));
	vec3 iris = c * vec3(0.55, 0.45, 0.4);
	ALBEDO = mix(c, iris, smoothstep(0.12, 0.3, sat)) * brightness;
	ROUGHNESS = 0.08;
	SPECULAR = 0.7;
}
