shader_type spatial;
render_mode cull_disabled;

uniform vec4 core_color : source_color = vec4(1.0, 0.9, 0.45, 1.0);
uniform vec4 magma_color : source_color = vec4(0.95, 0.28, 0.03, 1.0);
uniform float flow_speed : hint_range(0.0, 10.0) = 3.2;
uniform float emission_intensity : hint_range(1.0, 15.0) = 5.5;

void fragment() {
	float scroll = fract(UV.y * 2.5 - TIME * flow_speed);
	float bands = sin(scroll * 6.28318) * 0.5 + 0.5;
	bands += sin((UV.x * 3.0 + TIME * 1.5) * 6.28318) * 0.25;
	bands = clamp(bands, 0.0, 1.0);

	vec3 col = mix(magma_color.rgb, core_color.rgb, bands);
	ALBEDO = col;
	EMISSION = col * emission_intensity;
	ROUGHNESS = 0.2;
	METALLIC = 0.1;
}
