// Sheer outer layers of Satella's dress and sleeves: translucent black-violet
// gauze with glowing edges that frays into smoke near the floor.
// UV.y = 0 at the top of the layer -> 1 at its hem.
shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_never, diffuse_burley;

#include "res://shaders/common.gdshaderinc"

uniform vec4 color : source_color = vec4(0.02, 0.008, 0.035, 1.0);
uniform vec4 rim_color : source_color = vec4(0.38, 0.12, 0.62, 1.0);
uniform float opacity = 0.75;
uniform float rim_strength = 0.28;
uniform float smoke_start = 0.6;   // UV.y where the hem starts dissolving
uniform float sway = 0.03;
uniform float dissolve : hint_range(0.0, 1.0) = 0.0;
uniform float shimmer = 0.0;

varying vec3 v_lpos;

void vertex() {
	float k = UV.y * UV.y;
	VERTEX.x += sin(TIME * 0.9 + VERTEX.y * 3.0 + VERTEX.z * 2.0) * sway * k;
	VERTEX.z += cos(TIME * 0.7 + VERTEX.y * 2.0 + VERTEX.x * 3.0) * sway * k;
	v_lpos = VERTEX;
}

void fragment() {
	float n = fbm3(v_lpos * 4.0 + vec3(0.0, TIME * 0.12, TIME * 0.05));
	float smoke = smoothstep(smoke_start, 1.0, UV.y + (n - 0.5) * 0.35);
	float rim = pow(1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 3.0);
	// fine vertical pleats in the gauze
	float pleat = 0.75 + 0.25 * sin(UV.x * 220.0 + n * 4.0);
	float a = opacity * pleat * (1.0 - smoke) * (0.55 + 0.45 * rim);
	a *= 1.0 - smoothstep(dissolve * 1.1 - 0.15, dissolve * 1.1, 1.0 - n) * step(0.001, dissolve);
	ALBEDO = color.rgb;
	ROUGHNESS = 0.8;
	EMISSION = rim_color.rgb * rim * rim_strength * (1.0 - smoke * 0.6) + vec3(0.75, 0.78, 0.92) * shimmer * rim;
	ALPHA = clamp(a, 0.0, 1.0);
}
