shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float grain_amount : hint_range(0.0, 0.05) = 0.009;
uniform float vignette_amount : hint_range(0.0, 1.0) = 0.28;
uniform float image_width = 1152.0;

float grain(vec2 position) {
	return fract(sin(dot(position, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 resolution = 1.0 / SCREEN_PIXEL_SIZE;
	float width = min(resolution.x, image_width);
	vec2 grid = vec2(width, width * resolution.y / resolution.x);
	vec2 sample_uv = (floor(SCREEN_UV * grid) + 0.5) / grid;
	vec3 color = textureLod(screen_texture, sample_uv, 0.0).rgb;
	float luminance = dot(color, vec3(0.299, 0.587, 0.114));
	color = mix(vec3(luminance), color, 0.83);
	// Cold green-grey shadows and slightly warm paper highlights.
	color *= mix(vec3(0.88, 0.98, 0.96), vec3(1.04, 1.015, 0.95), smoothstep(0.12, 0.72, luminance));
	color = (color - 0.12) * 1.08 + 0.12;
	float noise = grain(floor(SCREEN_UV * resolution) + floor(TIME * 12.0));
	vec3 posterized = floor(clamp(color, vec3(0.0), vec3(1.0)) * 48.0 + noise) / 48.0;
	color = mix(color, posterized, 0.35);
	vec2 centered = SCREEN_UV * 2.0 - 1.0;
	float vignette = 1.0 - vignette_amount * smoothstep(0.35, 1.65, dot(centered, centered));
	color = color * vignette + (noise - 0.5) * grain_amount;
	COLOR = vec4(clamp(color, vec3(0.0), vec3(1.0)), 1.0);
}
