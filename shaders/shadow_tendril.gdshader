// The Witch's shadow hands: pure black matter with a violet, slowly crawling
// rim. Vertex wobble keeps them alive even when the skeleton is still.
shader_type spatial;
render_mode blend_mix, cull_back, unshaded;

#include "res://shaders/common.gdshaderinc"

uniform vec4 core : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 rim_color : source_color = vec4(0.22, 0.03, 0.32, 1.0);
uniform float wobble = 0.03;
uniform float dissolve : hint_range(0.0, 1.0) = 0.0;

varying vec3 lpos;

void vertex() {
	lpos = VERTEX;
	VERTEX += NORMAL * sin(TIME * 6.0 + VERTEX.y * 9.0 + VERTEX.x * 7.0) * wobble;
}

void fragment() {
	float n = fbm3(lpos * 5.0 + vec3(0.0, -TIME * 0.6, 0.0));
	if (n < dissolve * 1.1 - 0.05) {
		discard;
	}
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 5.0);
	ALBEDO = core.rgb + rim_color.rgb * rim * (0.4 + 0.8 * n);
}
