// Upright pixel-art sprite on a quad that faces the camera axis.
// One material per sprite sheet; frame, flip, flash and dissolve are per-instance
// so every enemy of a type shares a single material.
shader_type spatial;
render_mode cull_disabled, specular_disabled;

uniform sampler2D atlas : source_color, filter_nearest;
uniform sampler2D emit_atlas : source_color, filter_nearest, hint_default_black;
uniform vec2 frame_uv = vec2(1.0, 1.0);
uniform float emit_strength = 2.4;
uniform float bands = 4.0;
uniform float dither_strength = 0.5;
uniform float self_light = 0.0;
uniform bool unshaded_sprite = false;

instance uniform vec2 frame = vec2(0.0);
instance uniform float flip = 0.0;
instance uniform vec4 flash : source_color = vec4(1.0, 1.0, 1.0, 0.0);
instance uniform float dissolve = 0.0;
instance uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
instance uniform float glow_mult = 1.0;

const float BAYER[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

float bayer4(vec2 p) {
	int x = int(mod(p.x, 4.0));
	int y = int(mod(p.y, 4.0));
	return (BAYER[x + y * 4] + 0.5) / 16.0;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;
	if (flip > 0.5) {
		uv.x = 1.0 - uv.x;
	}
	vec2 auv = (frame + uv) * frame_uv;
	vec4 c = texture(atlas, auv);
	if (c.a < 0.5) {
		discard;
	}
	vec2 tex_size = vec2(textureSize(atlas, 0));
	vec2 texel = floor(auv * tex_size);
	float glow = texture(emit_atlas, auv).r;
	vec3 col = c.rgb * tint.rgb;
	vec3 emit = c.rgb * glow * emit_strength * glow_mult;
	if (dissolve > 0.0) {
		float n = hash(texel);
		// burn from the bottom up with a hot ember edge
		float h = 1.0 - uv.y;
		float t = n * 0.6 + h * 0.4;
		if (t < dissolve) {
			discard;
		}
		if (t < dissolve + 0.08) {
			col = vec3(1.0, 0.55, 0.2);
			emit += vec3(1.6, 0.7, 0.25);
		}
	}
	col = mix(col, flash.rgb, flash.a);
	emit += flash.rgb * flash.a * 1.2;
	if (tint.a < 0.99) {
		if (bayer4(FRAGCOORD.xy) > tint.a) {
			discard;
		}
	}
	ALBEDO = col;
	EMISSION = emit + col * self_light;
	if (unshaded_sprite) {
		ALBEDO = vec3(0.0);
		EMISSION = col + emit;
	}
}

void light() {
	float v = ATTENUATION;
	float d = (bayer4(FRAGCOORD.xy) - 0.5) * dither_strength;
	float q = floor(v * bands + 0.5 + d) / bands;
	DIFFUSE_LIGHT += max(q, 0.0) * LIGHT_COLOR / PI;
}
