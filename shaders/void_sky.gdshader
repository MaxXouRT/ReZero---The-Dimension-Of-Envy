// The sky of the Dimension of Envy: there is no sun, no day, no stars.
// Only a slow violet abyss with drifting nebulous veins and, far below,
// a darker horizon that swallows everything.
shader_type sky;

#include "res://shaders/common.gdshaderinc"

global uniform float envy_pulse;

uniform vec4 zenith : source_color = vec4(0.010, 0.004, 0.018, 1.0);
uniform vec4 horizon : source_color = vec4(0.055, 0.018, 0.075, 1.0);
uniform vec4 abyss : source_color = vec4(0.004, 0.001, 0.008, 1.0);
uniform vec4 vein_color : source_color = vec4(0.30, 0.06, 0.45, 1.0);
uniform float vein_strength = 0.35;
uniform float eye_strength = 0.0; // the giant "eye" of the throne, chapter 5

void sky() {
	vec3 d = EYEDIR;
	float h = d.y;
	vec3 col = mix(horizon.rgb, zenith.rgb, smoothstep(0.0, 0.7, h));
	col = mix(col, abyss.rgb, smoothstep(0.0, -0.35, h));
	vec2 p = d.xz / (abs(d.y) + 0.35) * 1.6;
	float n = fbm(p + vec2(TIME * 0.004, TIME * 0.002));
	float veins = smoothstep(0.04, 0.0, abs(fbm(p * 1.7 - TIME * 0.006) - 0.5));
	col += vein_color.rgb * veins * vein_strength * (0.4 + 0.6 * n) * smoothstep(-0.1, 0.3, h);
	col += vein_color.rgb * 0.15 * envy_pulse * n;
	// faint dust specks (not stars: they move and breathe)
	float speck = step(0.9985, hash12(floor(p * 60.0))) * (0.5 + 0.5 * sin(TIME * 0.7 + hash12(floor(p * 60.0)) * 40.0));
	col += vec3(0.25, 0.15, 0.35) * speck * 0.4;
	// the eye in the sky
	if (eye_strength > 0.0) {
		vec3 eye_dir = normalize(vec3(0.0, 0.35, -1.0));
		float a = dot(d, eye_dir);
		float iris = smoothstep(0.985, 0.995, a);
		float pupil = smoothstep(0.9975, 0.9985, a);
		float glow = smoothstep(0.9, 1.0, a);
		col += (vec3(0.5, 0.1, 0.7) * iris * (1.0 - pupil) + vec3(0.25, 0.05, 0.35) * glow * 0.5) * eye_strength;
		col *= 1.0 - pupil * eye_strength;
	}
	COLOR = col;
}
