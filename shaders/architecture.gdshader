// Procedural, world-space (triplanar) architecture material.
// One shader drives every surface of the mansion and the void, so that the
// whole dimension shares a coherent gothic language without texture files.
//
// pattern:
//  0 damask wallpaper   1 wood planks      2 stone blocks    3 carpet
//  4 plaster / ceiling  5 marble tiles     6 aged metal/gilt 7 bark
//  8 forest soil        9 dark wainscot panels
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

#include "res://shaders/common.gdshaderinc"

global uniform float distortion;
global uniform float envy_pulse;

uniform int pattern = 0;
uniform vec4 color_a : source_color = vec4(0.12, 0.06, 0.16, 1.0);
uniform vec4 color_b : source_color = vec4(0.22, 0.12, 0.28, 1.0);
uniform vec4 color_c : source_color = vec4(0.05, 0.03, 0.06, 1.0);
uniform float scale = 1.0;
uniform float roughness_base : hint_range(0.0, 1.0) = 0.8;
uniform float metallic_base : hint_range(0.0, 1.0) = 0.0;
uniform float bump_strength = 0.6;
uniform float grime = 0.5;
uniform float plank_axis = 0.0; // 0 = along X, 1 = along Z
uniform float breathe = 1.0;     // how much this surface reacts to "distortion"
uniform vec4 emission_color : source_color = vec4(0.0);
uniform float emission_energy = 0.0;

varying vec3 wpos;
varying vec3 wnorm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	float d = distortion * breathe;
	if (d > 0.001) {
		float w = sin(TIME * 1.7 + wpos.y * 2.3 + wpos.x * 1.3 + wpos.z * 0.9) * 0.5 + 0.5;
		VERTEX += NORMAL * d * 0.12 * w;
	}
}

vec2 tri_uv(vec3 p, vec3 n) {
	vec3 an = abs(n);
	if (an.y > an.x && an.y > an.z) {
		return plank_axis > 0.5 ? p.zx : p.xz;
	} else if (an.x > an.z) {
		return vec2(p.z, p.y);
	}
	return vec2(p.x, p.y);
}

// returns height in .x, albedo mix factors in .yzw
vec4 eval_pattern(vec2 uv, out vec3 albedo, out float rough) {
	float h = 0.5;
	rough = roughness_base;
	vec2 p = uv * scale;
	float n = fbm(p * 3.0);
	if (pattern == 0) {
		// Damask: diamond lattice + petals + thin stripes
		vec2 cell = vec2(0.55, 0.75);
		vec2 g = p / cell;
		vec2 id = floor(g);
		vec2 f = fract(g) - 0.5;
		if (mod(id.y, 2.0) > 0.5) { f.x = fract(g.x + 0.5) - 0.5; }
		float ang = atan(f.y, f.x);
		float r = length(f * vec2(1.0, 0.8));
		float petals = 0.22 + 0.07 * cos(ang * 6.0);
		float motif = smoothstep(0.02, 0.0, abs(r - petals)) + smoothstep(0.08, 0.05, r);
		float diamond = smoothstep(0.03, 0.0, abs(abs(f.x) + abs(f.y) - 0.46));
		float stripe = smoothstep(0.012, 0.0, abs(fract(p.x * 4.0) - 0.5) - 0.48);
		float m = clamp(motif + diamond * 0.8 + stripe * 0.3, 0.0, 1.0);
		albedo = mix(color_a.rgb, color_b.rgb, m);
		// peeling / water stains
		float stain = smoothstep(0.55, 0.85, fbm(p * 0.7 + 3.1));
		albedo = mix(albedo, color_c.rgb, stain * grime);
		h = 0.5 + m * 0.15 - stain * 0.2;
		rough = roughness_base - m * 0.25;
	} else if (pattern == 1) {
		float w = 0.19;
		float row = floor(p.y / w);
		float along = p.x + hash12(vec2(row, 3.0)) * 7.0;
		float seg = floor(along / 2.4);
		float tint = hash12(vec2(row, seg));
		float grain = sin((p.y * 90.0 + fbm(vec2(along * 1.5, p.y * 20.0)) * 9.0)) * 0.5 + 0.5;
		float gap = smoothstep(0.0, 0.012, fract(p.y / w) * w) * smoothstep(0.0, 0.012, (1.0 - fract(p.y / w)) * w);
		float gap2 = smoothstep(0.0, 0.01, fract(along / 2.4) * 2.4);
		albedo = mix(color_a.rgb, color_b.rgb, tint * 0.7 + grain * 0.3);
		albedo *= mix(0.25, 1.0, gap * gap2);
		albedo = mix(albedo, color_c.rgb, smoothstep(0.6, 0.9, n) * grime);
		h = gap * gap2 * (0.5 + grain * 0.1);
		rough = roughness_base - grain * 0.15;
	} else if (pattern == 2) {
		vec2 bs = vec2(0.62, 0.34);
		vec2 g = p / bs;
		if (mod(floor(g.y), 2.0) > 0.5) { g.x += 0.5; }
		vec2 id = floor(g);
		vec2 f = fract(g);
		float edge = min(min(f.x, 1.0 - f.x) * bs.x, min(f.y, 1.0 - f.y) * bs.y);
		float mortar = smoothstep(0.008, 0.03, edge);
		float tint = hash12(id);
		albedo = mix(color_a.rgb, color_b.rgb, tint * 0.6 + n * 0.4);
		albedo = mix(color_c.rgb, albedo, mortar);
		albedo = mix(albedo, albedo * 0.5, smoothstep(0.55, 0.8, fbm(p * 1.3)) * grime);
		h = mortar * (0.6 + n * 0.3);
		rough = mix(0.95, roughness_base, mortar);
	} else if (pattern == 3) {
		vec2 g = fract(p * 1.6) - 0.5;
		float dia = smoothstep(0.04, 0.0, abs(abs(g.x) + abs(g.y) - 0.35));
		float dot_ = smoothstep(0.08, 0.04, length(g));
		float fuzz = vnoise(p * 140.0);
		albedo = mix(color_a.rgb, color_b.rgb, clamp(dia + dot_, 0.0, 1.0));
		albedo *= 0.85 + fuzz * 0.3;
		albedo = mix(albedo, color_c.rgb, smoothstep(0.5, 0.85, n) * grime);
		h = 0.5 + fuzz * 0.1;
		rough = 1.0;
	} else if (pattern == 4) {
		float crack = smoothstep(0.02, 0.0, abs(fbm(p * 1.5) - 0.5));
		albedo = mix(color_a.rgb, color_b.rgb, n);
		albedo = mix(albedo, color_c.rgb, crack * 0.8 + smoothstep(0.6, 0.85, fbm(p * 0.6)) * grime);
		h = 0.5 - crack * 0.3 + n * 0.1;
	} else if (pattern == 5) {
		vec2 g = floor(p / 0.8);
		float checker = mod(g.x + g.y, 2.0);
		vec2 f = fract(p / 0.8);
		float joint = smoothstep(0.0, 0.01, min(min(f.x, 1.0 - f.x), min(f.y, 1.0 - f.y)));
		float vein = pow(abs(sin(p.x * 3.0 + p.y * 1.5 + fbm(p * 2.0) * 7.0)), 18.0);
		vec3 m1 = mix(color_a.rgb, color_b.rgb, vein);
		vec3 m2 = mix(color_c.rgb, color_a.rgb * 1.3, vein * 0.7);
		albedo = mix(m1, m2, checker) * mix(0.3, 1.0, joint);
		h = joint * 0.6;
		rough = roughness_base + (1.0 - joint) * 0.4 + n * 0.1;
	} else if (pattern == 6) {
		albedo = mix(color_a.rgb, color_b.rgb, n);
		albedo = mix(albedo, color_c.rgb, smoothstep(0.55, 0.8, fbm(p * 4.0)) * grime);
		h = n;
		rough = roughness_base + n * 0.2;
	} else if (pattern == 7) {
		float streak = fbm(vec2(p.x * 9.0, p.y * 0.8));
		float ridges = smoothstep(0.35, 0.65, streak);
		albedo = mix(color_c.rgb, mix(color_a.rgb, color_b.rgb, n), ridges);
		h = ridges;
		rough = 0.95;
	} else if (pattern == 8) {
		float leaves = smoothstep(0.6, 0.62, vnoise(p * 6.0)) * hash12(floor(p * 6.0));
		albedo = mix(color_a.rgb, color_b.rgb, n);
		albedo = mix(albedo, color_c.rgb, leaves);
		h = n + leaves * 0.2;
		rough = 0.98;
	} else {
		// 9: dark wainscot panels (vertical panels with bevelled frames)
		vec2 ps = vec2(0.9, 1.0);
		vec2 f = fract(p / ps);
		float frame = min(min(f.x, 1.0 - f.x) * ps.x, min(f.y, 1.0 - f.y) * ps.y);
		float bevel = smoothstep(0.05, 0.09, frame);
		float grain = sin(p.y * 60.0 + fbm(p * vec2(2.0, 18.0)) * 6.0) * 0.5 + 0.5;
		albedo = mix(color_a.rgb, color_b.rgb, grain * 0.4 + n * 0.3);
		albedo *= mix(0.55, 1.0, bevel);
		albedo = mix(albedo, color_c.rgb, smoothstep(0.6, 0.85, fbm(p * 1.1)) * grime);
		h = bevel * 0.7 + grain * 0.05;
	}
	return vec4(h, 0.0, 0.0, 0.0);
}

void fragment() {
	vec2 uv = tri_uv(wpos, wnorm);
	vec3 albedo;
	float rough;
	vec4 r = eval_pattern(uv, albedo, rough);
	float h = r.x;
	// Screen-space derivative bump mapping (Mikkelsen)
	vec3 dpdx = dFdx(VERTEX);
	vec3 dpdy = dFdy(VERTEX);
	float dhdx = dFdx(h);
	float dhdy = dFdy(h);
	vec3 r1 = cross(dpdy, NORMAL);
	vec3 r2 = cross(NORMAL, dpdx);
	float det = dot(dpdx, r1);
	vec3 grad = sign(det) * (dhdx * r1 + dhdy * r2);
	NORMAL = normalize(abs(det) * NORMAL - bump_strength * 0.04 * grad);
	// Envy pulse: veins of violet light appear in the walls when she is close
	float vein = smoothstep(0.022, 0.0, abs(fbm(uv * 0.45 + TIME * 0.02) - 0.5)) * smoothstep(0.3, 0.7, fbm(uv * 0.2 + 7.0));
	vec3 pulse = vec3(0.45, 0.08, 0.6) * vein * envy_pulse * breathe;
	ALBEDO = albedo;
	ROUGHNESS = clamp(rough, 0.05, 1.0);
	METALLIC = metallic_base;
	AO = clamp(0.35 + h, 0.0, 1.0);
	AO_LIGHT_AFFECT = 0.6;
	EMISSION = emission_color.rgb * emission_energy + pulse * 0.7;
}
