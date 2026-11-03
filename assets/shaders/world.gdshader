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
// large, soft patches of grime and wear so floors don't read as one tile repeated
uniform float grime = 0.0;
uniform vec3 grime_color : source_color = vec3(0.0);

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float hash2(vec2 p) {
	return fract(sin(dot(p, vec2(41.3, 289.1))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash2(i), hash2(i + vec2(1.0, 0.0)), f.x), mix(hash2(i + vec2(0.0, 1.0)), hash2(i + vec2(1.0, 1.0)), f.x), f.y);
}

const float BAYER[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

float bayer4(vec2 p) {
	int x = int(mod(p.x, 4.0));
	int y = int(mod(p.y, 4.0));
	return (BAYER[x + y * 4] + 0.5) / 16.0;
}

void fragment() {
	vec4 c = texture(albedo_tex, UV * uv_scale);
	vec3 col = c.rgb * tint.rgb;
	if (grime > 0.0) {
		// snap to the texel grid so the patches stay pixel art
		vec2 g = floor(wpos.xz * 16.0) / 16.0;
		float n = vnoise(g * 0.22) * 0.65 + vnoise(g * 0.71 + 13.0) * 0.35;
		float d = bayer4(floor(wpos.xz * 16.0)) * 0.12;
		float k = smoothstep(0.52, 0.53, n + d) * 0.6 + smoothstep(0.66, 0.67, n + d) * 0.4;
		col = mix(col, col * grime_color, k * grime);
	}
	ALBEDO = col;
	EMISSION = emission_color.rgb;
}

void light() {
	float ndl = clamp((dot(NORMAL, LIGHT) + wrap) / (1.0 + wrap), 0.0, 1.0);
	float v = ndl * ATTENUATION;
	float d = (bayer4(FRAGCOORD.xy) - 0.5) * dither_strength;
	float q = floor(v * bands + 0.5 + d) / bands;
	DIFFUSE_LIGHT += max(q, 0.0) * LIGHT_COLOR / PI;
}
