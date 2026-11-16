// Full-screen post process of the game (CanvasLayer > ColorRect).
// Film grain, vignette, violet grading, chromatic aberration, panic pulse,
// screen-space distortion waves and digital glitch blocks.
// Every "violent" parameter is clamped by the accessibility settings on the
// CPU side (reduce flashes / reduce camera motion).
shader_type canvas_item;

#include "res://shaders/common.gdshaderinc"

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float grain = 0.06;
uniform float vignette = 0.55;
uniform float panic = 0.0;
uniform float aberration = 0.0;
uniform float glitch = 0.0;
uniform float wave = 0.0;
uniform float desaturate = 0.15;
uniform float brightness = 1.0;
uniform float black_fade = 0.0;
uniform vec4 tint : source_color = vec4(0.92, 0.85, 1.0, 1.0);
uniform float red_flash = 0.0;
uniform float time_offset = 0.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	float t = TIME + time_offset;
	// distortion wave (reality bending)
	if (wave > 0.0) {
		uv.x += sin(uv.y * 18.0 + t * 4.0) * 0.006 * wave;
		uv.y += cos(uv.x * 14.0 + t * 3.0) * 0.004 * wave;
	}
	// glitch blocks
	if (glitch > 0.0) {
		float row = floor(uv.y * 24.0);
		float g = step(1.0 - glitch * 0.35, hash12(vec2(row, floor(t * 18.0))));
		uv.x += (hash12(vec2(row, floor(t * 30.0))) - 0.5) * 0.12 * g * glitch;
	}
	vec2 center = uv - 0.5;
	float ab = aberration * 0.006 + panic * 0.002;
	vec3 col;
	col.r = textureLod(screen_tex, uv + center * ab, 0.0).r;
	col.g = textureLod(screen_tex, uv, 0.0).g;
	col.b = textureLod(screen_tex, uv - center * ab, 0.0).b;
	// grading
	float lum = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(col, vec3(lum), desaturate);
	col *= tint.rgb * brightness;
	// vignette, pulsing with the heartbeat when panicking
	float pulse = panic * (0.5 + 0.5 * sin(t * mix(5.0, 11.0, panic)));
	float v = smoothstep(0.85, 0.2, length(center * vec2(1.25, 1.0)) * (1.0 + vignette * 0.6 + pulse * 0.35));
	col *= mix(1.0, v, clamp(vignette + panic * 0.4, 0.0, 1.0));
	// grain
	float n = hash12(FRAGCOORD.xy + fract(t) * 1000.0) - 0.5;
	col += n * grain * (1.0 + panic);
	// glitch color split lines
	if (glitch > 0.0) {
		float line = step(0.985, hash12(vec2(floor(uv.y * 200.0), floor(t * 20.0))));
		col = mix(col, vec3(0.6, 0.2, 0.9) * lum * 2.0, line * glitch);
	}
	col += vec3(0.5, 0.0, 0.15) * red_flash;
	col = mix(col, vec3(0.0), black_fade);
	COLOR = vec4(col, 1.0);
}
