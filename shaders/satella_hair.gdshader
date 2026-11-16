// Satella's hair: a single mesh of long ribbons (one per lock).
// UV.y = 0 at the scalp -> 1 at the tip. COLOR.r = lock tint (0 = black,
// 1 = pale grey-violet strand), COLOR.g = per-lock phase.
// Wind grows quadratically toward the tips; tips thin out into the dark.
shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

#include "res://shaders/common.gdshaderinc"

uniform vec4 root_color : source_color = vec4(0.012, 0.006, 0.02, 1.0);
uniform vec4 tip_color : source_color = vec4(0.05, 0.025, 0.08, 1.0);
uniform vec4 strand_color : source_color = vec4(0.32, 0.28, 0.38, 1.0);
uniform vec4 rim_color : source_color = vec4(0.55, 0.22, 0.9, 1.0);
uniform float rim_strength = 0.22;
uniform float wind = 0.25;
uniform float flow = 0.0;         // running: hair streams backward (+ local -Z)
uniform float dissolve : hint_range(0.0, 1.0) = 0.0;
uniform float tint = 0.0;         // 0 = witch (black hair), 1 = original (silver)

varying float v_len;
varying float v_tint;
varying float v_phase;
varying vec3 v_lpos;

void vertex() {
	v_len = UV.y;
	v_tint = COLOR.r;
	v_phase = COLOR.g * 6.2831;
	float k = v_len * v_len;
	VERTEX.x += sin(TIME * 1.3 + v_phase + v_len * 3.0) * 0.07 * wind * k;
	VERTEX.z += cos(TIME * 1.1 + v_phase * 1.7 + v_len * 2.0) * 0.06 * wind * k - flow * 0.45 * k;
	VERTEX.y += flow * 0.25 * k;
	v_lpos = VERTEX;
}

void fragment() {
	// thin, broken tips
	// pointed, tapering tips (and the odd split end)
	float taper = 1.0 - smoothstep(0.7, 1.0, v_len) * 0.95;
	float across = abs(UV.x - 0.5) * 2.0;
	float n = fbm3(v_lpos * 7.0 + vec3(0.0, TIME * 0.05, 0.0));
	if (across > taper || n < dissolve * 1.1 - 0.05) {
		discard;
	}
	// fibres across the ribbon width
	float fibre = 0.85 + 0.15 * sin(UV.x * 24.0 + v_phase * 10.0);
	vec3 base = mix(root_color.rgb, tip_color.rgb, v_len);
	base = mix(base, strand_color.rgb, v_tint * 0.85);
	base = mix(base, vec3(0.78, 0.8, 0.88), tint * (0.6 + 0.3 * v_tint));
	float rim = pow(1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 5.0);
	ALBEDO = base * fibre;
	ROUGHNESS = 0.45;
	SPECULAR = 0.45;
	EMISSION = rim_color.rgb * rim * rim_strength * (0.35 + 0.65 * fibre) * (0.4 + 0.6 * (1.0 - v_len * 0.5));
}
