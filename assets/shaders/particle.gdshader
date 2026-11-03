// Pixel particles (MultiMesh): unshaded, coloured per instance, HDR for bloom.
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;

void fragment() {
	ALBEDO = COLOR.rgb;
}
