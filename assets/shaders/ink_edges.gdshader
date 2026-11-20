// Screen-space ink lines for the illustrated look. Put on a QuadMesh (size 2x2)
// that the camera always sees; it covers the whole screen.
// Lines come from colour/brightness edges of the rendered frame (a Sobel filter on a
// slightly softened copy, so painted texture grain does not turn into scribbles).
// Colour-based because the depth texture is not available to this pass on the
// Mobile renderer in our recordings.
shader_type spatial;
render_mode unshaded, depth_test_disabled, depth_draw_never, cull_disabled, fog_disabled;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform vec4 ink : source_color = vec4(0.2, 0.08, 0.18, 1.0);
uniform float thickness = 1.2;      // pixels
uniform float threshold = 0.36;     // edge strength that starts a line
uniform float softness = 0.06;
uniform float strength : hint_range(0.0, 1.0) = 0.9;
uniform float lod = 1.0;            // mip level used for the edge test (softens grain)

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

float luma(vec2 uv) {
	vec3 c = textureLod(screen_tex, clamp(uv, vec2(0.003), vec2(0.997)), lod).rgb;
	return dot(c, vec3(0.3, 0.55, 0.15)) + 0.35 * (max(c.r, max(c.g, c.b)) - min(c.r, min(c.g, c.b)));
}

void fragment() {
	vec2 px = thickness / VIEWPORT_SIZE;
	float tl = luma(SCREEN_UV + px * vec2(-1.0, -1.0));
	float t = luma(SCREEN_UV + px * vec2(0.0, -1.0));
	float tr = luma(SCREEN_UV + px * vec2(1.0, -1.0));
	float l = luma(SCREEN_UV + px * vec2(-1.0, 0.0));
	float r = luma(SCREEN_UV + px * vec2(1.0, 0.0));
	float bl = luma(SCREEN_UV + px * vec2(-1.0, 1.0));
	float b = luma(SCREEN_UV + px * vec2(0.0, 1.0));
	float br = luma(SCREEN_UV + px * vec2(1.0, 1.0));
	float gx = (tr + 2.0 * r + br) - (tl + 2.0 * l + bl);
	float gy = (bl + 2.0 * b + br) - (tl + 2.0 * t + tr);
	float g = sqrt(gx * gx + gy * gy);
	float e = smoothstep(threshold, threshold + softness, g) * strength;
	vec3 col = textureLod(screen_tex, SCREEN_UV, 0.0).rgb;
	// Ink takes a little of the underlying colour so lines on gold read warm, on marble cool.
	vec3 inkc = mix(ink.rgb, col * 0.3, 0.2);
	ALBEDO = mix(col, inkc, e);
}
