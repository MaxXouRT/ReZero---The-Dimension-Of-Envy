// Used by the pause-menu trap: half of a screenshot of the pause menu, cut
// along a jagged, fibrous tear line. side = 0 keeps the left part, 1 the right.
shader_type canvas_item;

#include "res://shaders/common.gdshaderinc"

uniform float side = 0.0;
uniform float seed = 1.0;

void fragment() {
	float y = UV.y;
	float tear = 0.5 + (vnoise(vec2(y * 12.0, seed)) - 0.5) * 0.08 + (vnoise(vec2(y * 70.0, seed * 3.0)) - 0.5) * 0.02;
	float d = UV.x - tear;
	float keep = side < 0.5 ? step(d, 0.0) : step(0.0, d);
	vec4 c = texture(TEXTURE, UV);
	// fibrous pale edge
	float edge = smoothstep(0.012, 0.0, abs(d));
	c.rgb = mix(c.rgb, vec3(0.8, 0.75, 0.85), edge * 0.6);
	COLOR = vec4(c.rgb, c.a * keep);
}
