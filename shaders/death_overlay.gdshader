// Return by Death overlay: black shadow fingers creeping in from the screen
// edges, then everything collapses into a violet singularity.
shader_type canvas_item;

#include "res://shaders/common.gdshaderinc"

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float collapse : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 uv = UV - 0.5;
	float r = length(uv * vec2(1.6, 1.0));
	float a = atan(uv.y, uv.x);
	float fingers = fbm(vec2(a * 2.2, r * 3.0 - TIME * 0.8)) * 0.6 + 0.35 * pow(abs(sin(a * 5.0 + fbm(vec2(a * 4.0, TIME * 0.2)) * 3.0)), 8.0);
	// v is high in the centre, low at the screen edges: the shadow fills
	// every pixel whose v is below the advancing front (edges first).
	float v = 1.0 - r - fingers * 0.5;
	float reach = mix(-0.35, 1.25, progress);
	float shadow = smoothstep(reach + 0.02, reach - 0.06, v);
	float rim = smoothstep(0.06, 0.0, abs(v - reach)) * (1.0 - collapse) * step(0.001, progress);
	vec3 col = vec3(0.5, 0.12, 0.7) * rim * 0.9;
	float alpha = max(shadow, rim);
	COLOR = vec4(col, clamp(alpha, 0.0, 1.0));
}
