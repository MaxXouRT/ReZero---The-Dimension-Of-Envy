// Mirror surface: displays the reflection camera's viewport (horizontally
// flipped), aged silver: dark smudges, foxing and a faint violet sheen.
shader_type spatial;
render_mode unshaded, cull_back;

#include "res://shaders/common.gdshaderinc"

uniform sampler2D reflection : source_color, filter_linear;
uniform float age = 0.5;
uniform float crack = 0.0;

void fragment() {
	vec2 uv = vec2(1.0 - UV.x, UV.y);
	float n = fbm(UV * 6.0);
	vec2 off = vec2(0.0);
	if (crack > 0.0) {
		float c = smoothstep(0.02, 0.0, abs(fbm(UV * 3.0) - 0.5));
		off = vec2(c * 0.01 * crack);
	}
	vec3 col = texture(reflection, uv + off).rgb * 0.82;
	float fox = smoothstep(0.62, 0.8, fbm(UV * 9.0 + 4.0)) * age;
	col = mix(col, vec3(0.03, 0.02, 0.025), fox);
	float edge = smoothstep(0.0, 0.08, min(min(UV.x, 1.0 - UV.x), min(UV.y, 1.0 - UV.y)));
	col *= mix(0.4, 1.0, edge);
	col += vec3(0.04, 0.01, 0.06) * n;
	ALBEDO = col;
}
