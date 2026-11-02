// Environment surfaces (floors, wall faces, wall tops).
// Lighting is quantised into bands with ordered dithering at the band edges so
// real 3D lights read like hand-shaded pixel art.
shader_type spatial;
render_mode specular_disabled, diffuse_lambert;

uniform sampler2D albedo_tex : source_color, filter_nearest, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0);
uniform float bands = 5.0;
uniform float dither_strength = 0.6;
uniform float wrap = 0.25;
uniform vec4 emission_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec2 uv_scale = vec2(1.0, 1.0);

const float BAYER[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

float bayer4(vec2 p) {
	int x = int(mod(p.x, 4.0));
	int y = int(mod(p.y, 4.0));
	return (BAYER[x + y * 4] + 0.5) / 16.0;
}

void fragment() {
	vec4 c = texture(albedo_tex, UV * uv_scale);
	ALBEDO = c.rgb * tint.rgb;
	EMISSION = emission_color.rgb;
}

void light() {
	float ndl = clamp((dot(NORMAL, LIGHT) + wrap) / (1.0 + wrap), 0.0, 1.0);
	float v = ndl * ATTENUATION;
	float d = (bayer4(FRAGCOORD.xy) - 0.5) * dither_strength;
	float q = floor(v * bands + 0.5 + d) / bands;
	DIFFUSE_LIGHT += max(q, 0.0) * LIGHT_COLOR / PI;
}
