// Palette swap for portraits in menus (same rule as sprite.gdshader):
// texels that match a source colour take the target colour.
shader_type canvas_item;

uniform int swap_count = 0;
uniform vec3 swap_from[12];
uniform vec3 swap_to[12];

// COLOR in fragment() already holds texture * modulate; keep the modulate
// apart so the swapped texel is not multiplied by the original one
varying vec4 modulate;

void vertex() {
	modulate = COLOR;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	for (int i = 0; i < 12; i++) {
		if (i >= swap_count) {
			break;
		}
		if (distance(c.rgb, swap_from[i]) < 0.012) {
			c.rgb = swap_to[i];
			break;
		}
	}
	COLOR = c * modulate;
}
