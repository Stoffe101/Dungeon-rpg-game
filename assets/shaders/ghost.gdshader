// Afterimages: an additive, flat-coloured copy of a sprite frame. Writes no
// depth, so it never occludes the real sprite.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform sampler2D atlas : source_color, filter_nearest;
uniform vec2 frame_uv = vec2(1.0, 1.0);

instance uniform vec2 frame = vec2(0.0);
instance uniform float flip = 0.0;
instance uniform vec4 flash : source_color = vec4(1.0, 0.6, 0.3, 1.0);
instance uniform vec4 tint : source_color = vec4(1.0);

const float BAYER[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

void fragment() {
	vec2 uv = UV;
	if (flip > 0.5) {
		uv.x = 1.0 - uv.x;
	}
	vec4 c = texture(atlas, (frame + uv) * frame_uv);
	int x = int(mod(FRAGCOORD.x, 4.0));
	int y = int(mod(FRAGCOORD.y, 4.0));
	if (c.a < 0.5 || (BAYER[x + y * 4] + 0.5) / 16.0 > tint.a) {
		discard;
	}
	ALBEDO = flash.rgb * 0.8;
	ALPHA = 1.0;
}
