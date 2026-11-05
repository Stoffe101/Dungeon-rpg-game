// Second pass for the player sprite: where the sprite is hidden behind walls
// or pillars, draw a dithered warm silhouette so the Kindled is never lost.
shader_type spatial;
render_mode unshaded, depth_test_disabled, depth_draw_never, cull_disabled, shadows_disabled;

uniform sampler2D atlas : source_color, filter_nearest;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform vec2 frame_uv = vec2(1.0, 1.0);
uniform vec4 color : source_color = vec4(1.0, 0.62, 0.3, 1.0);

instance uniform vec2 frame = vec2(0.0);
instance uniform float flip = 0.0;
instance uniform float silhouette = 1.0;

// (the body leads toward the camera like every sprite: sprite.gdshader)
uniform float depth_lead = 0.8;
instance uniform float lead = 1.0;

void vertex() {
	vec4 v = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	v.z += depth_lead * lead;
	POSITION = PROJECTION_MATRIX * v;
}

const float BAYER[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

void fragment() {
	if (silhouette < 0.5) {
		discard;
	}
	vec2 uv = UV;
	if (flip > 0.5) {
		uv.x = 1.0 - uv.x;
	}
	vec4 c = texture(atlas, (frame + uv) * frame_uv);
	if (c.a < 0.5) {
		discard;
	}
	float scene = texture(depth_tex, SCREEN_UV).r;
	// reversed-Z: a larger stored depth means something sits in front of us
	// (by more than the armour layered a hair in front of the body itself)
	if (scene <= FRAGCOORD.z + 0.0004) {
		discard;
	}
	int x = int(mod(FRAGCOORD.x, 4.0));
	int y = int(mod(FRAGCOORD.y, 4.0));
	if ((BAYER[x + y * 4] + 0.5) / 16.0 > 0.55) {
		discard;
	}
	ALBEDO = color.rgb;
	ALPHA = 1.0;
}
