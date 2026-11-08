// Toon shader for the Kodanda: limbs flex toward the archer as `bend` (draw) rises.
shader_type spatial;
render_mode cull_back, depth_draw_opaque;

#include "res://assets/shaders/toon.gdshaderinc"

uniform float bend : hint_range(0.0, 1.0) = 0.0;
const float HALF_LENGTH = 0.71;
const float TIP_PULL = 0.085;

void vertex() {
	float t = clamp(VERTEX.y / HALF_LENGTH, -1.0, 1.0);
	VERTEX.x -= bend * TIP_PULL * t * t;
	VERTEX.y *= 1.0 - bend * 0.03 * t * t;
}
