// Gothic stained glass lit from "outside" by the violet void.
shader_type spatial;
render_mode cull_disabled, unshaded;

#include "res://shaders/common.gdshaderinc"

uniform vec4 glass_a : source_color = vec4(0.35, 0.05, 0.5, 1.0);
uniform vec4 glass_b : source_color = vec4(0.08, 0.02, 0.25, 1.0);
uniform vec4 glass_c : source_color = vec4(0.6, 0.55, 0.75, 1.0);
uniform float energy = 1.4;

void fragment() {
	vec2 p = UV * vec2(4.0, 8.0);
	vec2 id = floor(p + vec2(hash12(floor(p.yy)) * 0.5, 0.0));
	float h = hash12(id);
	vec2 f = fract(p);
	float lead = smoothstep(0.0, 0.06, min(min(f.x, 1.0 - f.x), min(f.y, 1.0 - f.y)));
	// central silhouette (a woman with long hair, arms open)
	vec2 c = UV - vec2(0.5, 0.45);
	float body = smoothstep(0.02, 0.0, length(c * vec2(3.0, 1.2)) - 0.18);
	float head = smoothstep(0.01, 0.0, length(UV - vec2(0.5, 0.22)) - 0.06);
	vec3 col = mix(glass_b.rgb, glass_a.rgb, h);
	col = mix(col, glass_c.rgb, step(0.85, h));
	col = mix(col, vec3(0.01), max(body, head) * 0.95);
	col *= lead;
	float arch = step(length((UV - vec2(0.5, 0.25)) * vec2(1.0, 1.6)), 0.5) + step(0.25, UV.y);
	col *= clamp(arch, 0.0, 1.0);
	ALBEDO = col * energy * (0.85 + 0.15 * sin(TIME * 0.5 + h * 6.0));
}
