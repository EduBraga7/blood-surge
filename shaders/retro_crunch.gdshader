shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;

// Game-feel and aesthetics knobs
uniform bool enabled = true;
uniform float dither_strength : hint_range(0.0, 1.0) = 0.35;
uniform float color_depth : hint_range(8.0, 64.0) = 32.0;
uniform float vignette_intensity : hint_range(0.0, 1.5) = 0.45;
uniform float vignette_opacity : hint_range(0.0, 1.0) = 0.55;
uniform float pixel_size : hint_range(1.0, 6.0, 1.0) = 1.0;

// 4x4 Bayer Dither Matrix for authentic 90s software hardware rasterization
const float bayer4x4[16] = float[16](
    0.0 / 16.0,  8.0 / 16.0,  2.0 / 16.0, 10.0 / 16.0,
   12.0 / 16.0,  4.0 / 16.0, 14.0 / 16.0,  6.0 / 16.0,
    3.0 / 16.0, 11.0 / 16.0,  1.0 / 16.0,  9.0 / 16.0,
   15.0 / 16.0,  7.0 / 16.0, 13.0 / 16.0,  5.0 / 16.0
);

void fragment() {
	if (!enabled) {
		COLOR = texture(screen_texture, SCREEN_UV);
	} else {
		vec2 uv = SCREEN_UV;
		if (pixel_size > 1.0) {
			vec2 screen_res = 1.0 / SCREEN_PIXEL_SIZE;
			vec2 target_res = screen_res / pixel_size;
			uv = floor(uv * target_res) / target_res;
		}

		vec3 col = texture(screen_texture, uv).rgb;

		// Bayer Dithering
		ivec2 coord = ivec2(FRAGCOORD.xy / pixel_size) % 4;
		int index = coord.y * 4 + coord.x;
		float dither_val = (bayer4x4[index] - 0.5) * (1.0 / color_depth) * dither_strength;

		// Color Quantization
		col += vec3(dither_val);
		col = floor(col * color_depth + 0.5) / color_depth;

		// Atmospheric Vignette
		vec2 center_dist = (SCREEN_UV - 0.5) * 1.4;
		float vig = clamp(dot(center_dist, center_dist) * vignette_intensity, 0.0, 1.0);
		col = mix(col, col * (1.0 - vig), vignette_opacity);

		COLOR = vec4(col, 1.0);
	}
}
