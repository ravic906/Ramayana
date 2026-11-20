// Painted day sky for the illustrated look: deep blue gradient, warm haze at the
// horizon, cel-shaded clouds (lit tops, lavender bellies) and three layers of
// distant hills fading into the haze. Procedural, no textures.
shader_type sky;

uniform vec3 zenith : source_color = vec3(0.06, 0.24, 0.62);
uniform vec3 mid : source_color = vec3(0.24, 0.52, 0.88);
uniform vec3 horizon : source_color = vec3(0.86, 0.9, 0.92);
uniform vec3 haze_warm : source_color = vec3(1.0, 0.86, 0.66);
uniform vec3 cloud_lit : source_color = vec3(1.0, 0.99, 0.95);
uniform vec3 cloud_shade : source_color = vec3(0.68, 0.7, 0.9);
uniform vec3 hill_near : source_color = vec3(0.36, 0.5, 0.52);
uniform vec3 hill_far : source_color = vec3(0.62, 0.74, 0.86);
uniform float cloud_cover : hint_range(0.0, 1.0) = 0.22;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}
float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) { v += a * noise(p); p *= 2.03; a *= 0.5; }
	return v;
}

void sky() {
	vec3 d = EYEDIR;
	float y = d.y;
	vec3 col = mix(horizon, mid, smoothstep(0.0, 0.25, y));
	col = mix(col, zenith, smoothstep(0.2, 0.9, y));
	if (LIGHT0_ENABLED) {
		vec2 sh = normalize(LIGHT0_DIRECTION.xz + vec2(1e-4));
		float s = max(dot(normalize(d.xz + vec2(1e-4)), sh), 0.0);
		col = mix(col, haze_warm, (1.0 - smoothstep(0.0, 0.22, y)) * s * 0.45);
		float sd = max(dot(d, LIGHT0_DIRECTION), 0.0);
		col += LIGHT0_COLOR * (pow(sd, 400.0) * 3.0 + pow(sd, 12.0) * 0.12);
	}
	if (y > 0.02) {  // cel-shaded clouds on a plane overhead
		vec2 p = d.xz / (y + 0.08) * 0.9;
		float c = fbm(p * 1.1) + 0.35 * fbm(p * 3.0);
		float m = smoothstep(1.0 - cloud_cover, 1.05 - cloud_cover, c * 0.9);
		float top = fbm(p * 1.1 + vec2(0.0, -0.08)) + 0.35 * fbm(p * 3.0 + vec2(0.0, -0.24));
		float lit = step(c * 0.9 - 0.02, top * 0.9);
		vec3 cc = mix(cloud_shade, cloud_lit, mix(0.35, 1.0, lit));
		m *= smoothstep(0.02, 0.12, y);
		col = mix(col, cc, m * 0.95);
	}
	float az = atan(d.x, d.z);
	for (int i = 0; i < 3; i++) {  // distant hills, far to near
		float k = float(i) / 2.0;
		float seed = 3.0 + float(i) * 7.0;
		float h = mix(0.035, 0.07, k) * (0.55 + 0.45 * fbm(vec2(az * mix(4.5, 2.0, k) + seed, seed)));
		if (y < h && y > -0.2) {
			vec3 hc = mix(hill_far, hill_near, k);
			hc = mix(hc, horizon, smoothstep(h - 0.05, h, y) * 0.25);
			col = hc;
		}
	}
	if (y < 0.0) {
		col = mix(col, hill_near * 0.9, smoothstep(0.0, -0.1, y));
	}
	COLOR = col;
}
