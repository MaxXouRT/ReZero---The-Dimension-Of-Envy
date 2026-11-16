// Procedural oil paintings for the mansion's walls.
// variant: 0 portrait of a lady  1 the mansion in the fog  2 eyes (they look at you)
//          3 scratched-out portrait (Subaru)  4 silver-haired woman (Satella, original)
//          5 the same woman, but her face is gone (the Witch)
shader_type spatial;
render_mode diffuse_burley;

#include "res://shaders/common.gdshaderinc"

uniform int variant = 0;
uniform float seed = 0.0;
uniform float stare = 0.0;      // 0..1, eyes glow / pupils widen
uniform vec2 look_dir = vec2(0.0); // pupils offset (-1..1)

float sdEllipse(vec2 p, vec2 r) { return (length(p / r) - 1.0) * min(r.x, r.y); }

void fragment() {
	vec2 uv = UV;
	vec2 p = uv - vec2(0.5);
	float canvas = fbm(uv * 40.0 + seed) * 0.08 + fbm(uv * 4.0 + seed) * 0.1;
	vec3 bg = mix(vec3(0.05, 0.03, 0.035), vec3(0.11, 0.07, 0.06), fbm(uv * 3.0 + seed));
	vec3 col = bg;
	vec3 emit = vec3(0.0);
	if (variant == 0 || variant == 4 || variant == 5) {
		vec2 q = p - vec2(0.0, -0.06);
		float head = sdEllipse(q - vec2(0.0, 0.0), vec2(0.11, 0.14));
		float neck = sdEllipse(q - vec2(0.0, 0.17), vec2(0.05, 0.08));
		float shoulders = sdEllipse(q - vec2(0.0, 0.42), vec2(0.34, 0.2));
		float hair = sdEllipse(q - vec2(0.0, 0.08), vec2(0.17, 0.32));
		vec3 skin = variant == 0 ? vec3(0.45, 0.33, 0.28) : vec3(0.62, 0.58, 0.6);
		vec3 hair_c = variant == 0 ? vec3(0.12, 0.06, 0.04) : vec3(0.72, 0.72, 0.78);
		vec3 dress = variant == 0 ? vec3(0.18, 0.04, 0.06) : vec3(0.05, 0.03, 0.08);
		col = mix(col, hair_c * (0.7 + 0.3 * fbm(uv * vec2(8.0, 30.0))), smoothstep(0.01, -0.01, hair));
		col = mix(col, dress, smoothstep(0.01, -0.01, shoulders));
		col = mix(col, skin * 0.8, smoothstep(0.01, -0.01, neck));
		col = mix(col, skin, smoothstep(0.01, -0.01, head));
		if (variant == 5) {
			// the face is a black void that drinks the light
			col = mix(col, vec3(0.0), smoothstep(0.02, -0.02, head + 0.015));
			float eyes = smoothstep(0.012, 0.0, length(q - vec2(-0.04, -0.01))) + smoothstep(0.012, 0.0, length(q - vec2(0.04, -0.01)));
			emit += vec3(0.6, 0.1, 0.9) * eyes * (0.3 + stare * 2.0);
		} else {
			vec2 e1 = q - vec2(-0.04, -0.01) - look_dir * 0.006;
			vec2 e2 = q - vec2(0.04, -0.01) - look_dir * 0.006;
			float eyes = smoothstep(0.012, 0.0, length(e1)) + smoothstep(0.012, 0.0, length(e2));
			col = mix(col, vec3(0.02), eyes * 0.9);
			emit += vec3(0.5, 0.15, 0.7) * eyes * stare;
		}
	} else if (variant == 1) {
		float hill = smoothstep(0.0, 0.01, uv.y - (0.7 + sin(uv.x * 4.0 + seed) * 0.05));
		vec2 m = uv - vec2(0.5, 0.58);
		float house = step(abs(m.x), 0.2) * step(abs(m.y + 0.02), 0.08);
		float roof = step(abs(m.x) * 0.6, 0.12 - (-m.y - 0.06)) * step(-m.y, 0.2) * step(0.06, -m.y);
		float tower = step(abs(m.x - 0.15), 0.03) * step(-0.25, m.y) * step(m.y, 0.0);
		col = mix(vec3(0.07, 0.04, 0.1), vec3(0.2, 0.1, 0.25), uv.y);
		col = mix(col, vec3(0.03, 0.02, 0.03), hill);
		col = mix(col, vec3(0.01), clamp(house + roof + tower, 0.0, 1.0));
		float win = step(0.6, hash12(floor((m + 0.3) * vec2(30.0, 25.0)))) * house;
		emit += vec3(0.5, 0.2, 0.6) * win * 0.4;
		col = mix(col, vec3(0.15, 0.1, 0.18), fbm(uv * vec2(3.0, 9.0) + TIME * 0.01) * 0.5);
	} else if (variant == 2) {
		col = bg * 0.5;
		for (int i = 0; i < 6; i++) {
			vec2 c = vec2(hash12(vec2(float(i), seed)), hash12(vec2(seed, float(i) + 3.0))) * 0.7 + 0.15;
			vec2 d = uv - c;
			float lid = sdEllipse(d, vec2(0.07, 0.03));
			float iris = length(d - look_dir * 0.02) - 0.022;
			col = mix(col, vec3(0.55, 0.5, 0.48), smoothstep(0.005, -0.005, lid));
			col = mix(col, vec3(0.2, 0.05, 0.25), smoothstep(0.004, -0.004, iris) * step(lid, 0.0));
			col = mix(col, vec3(0.0), smoothstep(0.004, -0.004, iris + 0.012 - stare * 0.008) * step(lid, 0.0));
			emit += vec3(0.4, 0.05, 0.6) * smoothstep(0.004, -0.004, iris) * step(lid, 0.0) * stare;
		}
	} else {
		vec2 q = p - vec2(0.0, -0.05);
		float head = sdEllipse(q, vec2(0.12, 0.15));
		float body = sdEllipse(q - vec2(0.0, 0.4), vec2(0.3, 0.22));
		col = mix(col, vec3(0.1, 0.1, 0.12), smoothstep(0.01, -0.01, body));
		col = mix(col, vec3(0.5, 0.4, 0.35), smoothstep(0.01, -0.01, head));
		float scratch = 0.0;
		for (int i = 0; i < 14; i++) {
			float a = hash12(vec2(float(i), 1.0)) * 3.14;
			vec2 dir = vec2(cos(a), sin(a));
			float d = abs(dot(q, vec2(-dir.y, dir.x)) - (hash12(vec2(float(i), 2.0)) - 0.5) * 0.15);
			scratch = max(scratch, smoothstep(0.006, 0.0, d) * step(length(q), 0.2));
		}
		col = mix(col, vec3(0.75, 0.7, 0.65), scratch);
	}
	col *= 0.85 + canvas;
	// varnish crackle
	col *= 0.9 + 0.1 * smoothstep(0.0, 0.03, abs(fbm(uv * 12.0 + seed) - 0.5));
	ALBEDO = col;
	ROUGHNESS = 0.45;
	EMISSION = emit;
}
