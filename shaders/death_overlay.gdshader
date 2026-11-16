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
	float fingers = fbm(vec2(a * 3.0, r * 2.0 - TIME * 0.6)) * 0.35 + 0.5 * pow(abs(sin(a * 7.0 + TIME * 0.3)), 6.0) * 0.25;
	float reach = mix(1.2, -0.2, progress);
	float shadow = smoothstep(reach + 0.08, reach - 0.02, 1.0 - r - fingers * 0.5);
	shadow = 1.0 - shadow;
	float rim = smoothstep(0.05, 0.0, abs((1.0 - r - fingers * 0.5) - reach)) * (1.0 - collapse);
	vec3 col = vec3(0.0) + vec3(0.5, 0.12, 0.7) * rim * 0.8;
	float alpha = max(shadow, rim);
	float singularity = smoothstep(collapse * 1.2, collapse * 1.2 - 0.05, r);
	alpha = max(alpha, collapse > 0.0 ? 1.0 - singularity * 0.0 : 0.0);
	col += vec3(0.6, 0.2, 0.9) * smoothstep(0.02, 0.0, abs(r - (1.0 - collapse) * 0.6)) * collapse * (1.0 - collapse) * 3.0;
	COLOR = vec4(col, clamp(alpha, 0.0, 1.0));
}
