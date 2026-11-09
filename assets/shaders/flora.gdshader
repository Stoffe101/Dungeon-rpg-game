// Ground cover: thousands of blades drawn as one MultiMesh a room. A frame is
// picked here (it sways on its own, no script per plant); INSTANCE_CUSTOM says
// which plant (r), when it sways (g), how it stands (b: 0 up, 0.5 parted by a
// foot, 1 burnt) and which way it faces (a).
shader_type spatial;
render_mode cull_disabled, specular_disabled;

uniform sampler2D atlas : source_color, filter_nearest;
uniform sampler2D emit_atlas : source_color, filter_nearest, hint_default_black;
uniform vec2 frame_uv = vec2(1.0, 1.0);
uniform float emit_strength = 2.4;
// a mood of the Hollow Below repaints what grows there (a = how much)
uniform vec4 tint = vec4(0.0);
uniform float bands = 4.0;
uniform float dither_strength = 0.5;
uniform float falloff = 0.62;

varying flat vec4 inst;

void vertex() {
	inst = INSTANCE_CUSTOM;
}

const float BAYER[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

float bayer4(vec2 p) {
	int x = int(mod(p.x, 4.0));
	int y = int(mod(p.y, 4.0));
	return (BAYER[x + y * 4] + 0.5) / 16.0;
}

void fragment() {
	float col_i = mod(floor(TIME * 0.8 + inst.g * 2.0), 2.0);
	if (inst.b > 0.75) {
		col_i = 3.0;
	} else if (inst.b > 0.25) {
		col_i = 2.0;
	}
	vec2 uv = UV;
	if (inst.a > 0.5) {
		uv.x = 1.0 - uv.x;
	}
	vec2 auv = (vec2(col_i, floor(inst.r * 255.0 + 0.5)) + uv) * frame_uv;
	vec4 c = texture(atlas, auv);
	if (c.a < 0.5) {
		discard;
	}
	vec3 col = mix(c.rgb, vec3(dot(c.rgb, vec3(0.34, 0.5, 0.16))) * tint.rgb * 2.2, tint.a);
	ALBEDO = col;
	EMISSION = col * texture(emit_atlas, auv).r * emit_strength;
}

void light() {
	float v = pow(ATTENUATION, falloff);
	float d = (bayer4(FRAGCOORD.xy) - 0.5) * dither_strength;
	float q = floor(v * bands + 0.5 + d) / bands;
	DIFFUSE_LIGHT += max(q, 0.0) * LIGHT_COLOR / PI;
}
