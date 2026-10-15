shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D surface_map : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 tint : source_color = vec4(0.5, 0.5, 0.5, 1.0);
uniform vec4 map_average : source_color = vec4(0.5, 0.5, 0.5, 1.0);
uniform float repeat_scale = 1.0;
uniform float detail_strength = 0.60;
uniform float surface_roughness = 0.88;
uniform float surface_metallic = 0.0;
varying vec3 local_position;
varying vec3 local_normal;

void vertex() {
	local_position = VERTEX;
	local_normal = NORMAL;
}

void fragment() {
	vec3 weights = pow(abs(normalize(local_normal)), vec3(8.0));
	weights /= max(weights.x + weights.y + weights.z, 0.001);
	vec3 p = local_position * repeat_scale;
	vec3 texel = texture(surface_map, p.zy).rgb * weights.x;
	texel += texture(surface_map, p.xz).rgb * weights.y;
	texel += texture(surface_map, p.xy).rgb * weights.z;
	vec3 variation = texel / max(map_average.rgb, vec3(0.025));
	ALBEDO = clamp(tint.rgb * mix(vec3(1.0), variation, detail_strength), vec3(0.0), vec3(0.95));
	ROUGHNESS = surface_roughness;
	METALLIC = surface_metallic;
	SPECULAR = 0.25;
}
