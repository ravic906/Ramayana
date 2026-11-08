// Golden-hour sky in the miniature-painting palette: saffron horizon,
// rose band, indigo zenith, a soft sun with halo, painterly cloud bands.
shader_type sky;

uniform vec3 zenith_color : source_color = vec3(0.2, 0.25, 0.52);
uniform vec3 rose_color : source_color = vec3(0.9, 0.5, 0.48);
uniform vec3 horizon_color : source_color = vec3(1.0, 0.74, 0.4);
uniform vec3 ground_color : source_color = vec3(0.42, 0.3, 0.24);
uniform vec3 cloud_light : source_color = vec3(1.0, 0.82, 0.62);
uniform vec3 cloud_shadow : source_color = vec3(0.78, 0.45, 0.48);
uniform float sun_size = 0.045;
uniform float sun_intensity = 6.0;

void sky() {
	vec3 d = EYEDIR;
	float y = d.y;
	vec3 col;
	if (y >= 0.0) {
		col = mix(horizon_color, rose_color, smoothstep(0.0, 0.22, y));
		col = mix(col, zenith_color, smoothstep(0.15, 0.85, y));
	} else {
		col = mix(horizon_color * 0.85, ground_color, smoothstep(0.0, -0.25, y));
	}
	if (LIGHT0_ENABLED) {
		float s = max(dot(d, LIGHT0_DIRECTION), 0.0);
		float halo = pow(s, 6.0) * 0.35 + pow(s, 48.0) * 0.6;
		float disk = smoothstep(cos(sun_size), cos(sun_size * 0.7), s);
		col += LIGHT0_COLOR * (halo + disk * sun_intensity) * 0.6;
	}
	if (!AT_CUBEMAP_PASS || true) {
		float az = atan(d.x, d.z);
		float band = smoothstep(0.03, 0.09, y) * smoothstep(0.32, 0.13, y);
		float n = (sin(az * 6.0 + sin(az * 2.0) * 1.7) * 0.5 + 0.5) * (sin(az * 15.0 + 1.3 + y * 20.0) * 0.5 + 0.5);
		float cloud = band * smoothstep(0.3, 0.7, n);
		vec3 cc = mix(cloud_shadow, cloud_light, smoothstep(0.06, 0.2, y));
		col = mix(col, cc, cloud * 0.65);
	}
	COLOR = col;
}
