// Satella body material: dark cloth / pale skin / silver hair with a violet
// rim so her silhouette always reads in the darkness, and a noise dissolve
// used when she appears or vanishes ("she is not there anymore").
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley;

#include "res://shaders/common.gdshaderinc"

uniform vec4 albedo : source_color = vec4(0.03, 0.02, 0.04, 1.0);
uniform float roughness = 0.7;
uniform vec4 rim_color : source_color = vec4(0.55, 0.25, 0.8, 1.0);
uniform float rim_power = 3.0;
uniform float rim_strength = 0.6;
uniform float dissolve : hint_range(0.0, 1.0) = 0.0;
uniform vec4 dissolve_edge : source_color = vec4(0.7, 0.3, 1.0, 1.0);
uniform vec4 emission : source_color = vec4(0.0);
uniform float emission_energy = 0.0;
uniform float flutter = 0.0; // cloth / hair waving amount
uniform float shimmer = 0.0;  // the original Satella's faint silver light

varying vec3 lpos;

void vertex() {
	lpos = VERTEX;
	if (flutter > 0.0) {
		float w = sin(TIME * 3.0 + VERTEX.y * 4.0 + VERTEX.x * 3.0) * flutter * max(0.0, -VERTEX.y + 0.2);
		VERTEX.x += w * 0.05;
		VERTEX.z += cos(TIME * 2.3 + VERTEX.y * 3.0) * flutter * 0.04 * max(0.0, -VERTEX.y + 0.2);
	}
}

void fragment() {
	float n = fbm3(lpos * 6.0 + vec3(0.0, TIME * 0.1, 0.0));
	if (dissolve > 0.0 && n < dissolve * 1.1 - 0.05) {
		discard;
	}
	float edge = (dissolve > 0.0) ? smoothstep(0.08, 0.0, n - (dissolve * 1.1 - 0.05)) : 0.0;
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), rim_power);
	ALBEDO = albedo.rgb * (0.85 + 0.3 * n);
	ROUGHNESS = roughness;
	EMISSION = rim_color.rgb * rim * rim_strength + dissolve_edge.rgb * edge * 4.0 + emission.rgb * emission_energy
		+ vec3(0.75, 0.78, 0.9) * shimmer * (0.3 + 0.7 * rim) * (0.6 + 0.4 * sin(TIME * 2.0 + lpos.y * 5.0));
}
