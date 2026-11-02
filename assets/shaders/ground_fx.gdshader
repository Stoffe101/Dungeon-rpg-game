// Flat shapes painted on the floor: attack telegraphs, slash arcs, shockwave
// rings, sigils. UVs are snapped to the 16px-per-tile grid so every effect is
// crisp pixel art no matter its size or rotation.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

instance uniform vec4 color : source_color = vec4(1.0, 0.2, 0.3, 0.5);
instance uniform vec4 edge_color : source_color = vec4(1.0, 0.5, 0.5, 1.0);
instance uniform float shape = 0.0;       // 0 disc, 1 ring, 2 cone, 3 rect, 4 swipe, 5 sigil
instance uniform float progress = 0.0;    // telegraph fill / swipe sweep 0..1
instance uniform float half_angle = 1.0;  // cone / swipe half width (radians)
instance uniform float inner = 0.0;       // ring / swipe inner radius (0..1 of outer)
instance uniform float px_size = 32.0;    // quad size in pixels (for snapping)
instance uniform float fade = 1.0;
instance uniform float glow = 1.0;

const float BAYER[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

float bayer4(vec2 p) {
	int x = int(mod(p.x, 4.0));
	int y = int(mod(p.y, 4.0));
	return (BAYER[x + y * 4] + 0.5) / 16.0;
}

void fragment() {
	vec2 cell = floor(UV * px_size);
	vec2 uv = (cell + 0.5) / px_size;
	vec2 p = uv * 2.0 - 1.0;               // -1..1, +x forward for cones/swipes
	float r = length(p);
	float ang = atan(p.y, p.x);
	float px = 2.0 / px_size;              // one pixel in p-space
	float a = 0.0;
	float e = 0.0;
	int s = int(shape + 0.5);
	if (s == 0) {
		// filled disc that grows outward with progress, solid rim
		if (r > 1.0) discard;
		e = step(1.0 - px * 1.5, r);
		a = step(r, progress) * 0.55 + 0.12;
	} else if (s == 1) {
		// ring band between inner and 1
		if (r > 1.0 || r < inner) discard;
		float band = (r - inner) / max(1.0 - inner, 0.001);
		e = step(band, 0.35) + step(0.8, band);
		a = 0.6;
	} else if (s == 2) {
		if (r > 1.0 || abs(ang) > half_angle) discard;
		e = step(1.0 - px * 1.5, r) + step(half_angle - px / max(r, 0.05) * 1.5, abs(ang));
		a = step(r, progress) * 0.55 + 0.12;
	} else if (s == 3) {
		// rect: x is length (forward), y is width; fill along length
		if (abs(p.y) > 1.0) discard;
		float l = uv.x;
		e = step(1.0 - px * 1.5, abs(p.y)) + step(1.0 - px, l) + step(l, px);
		a = step(l, progress) * 0.55 + 0.12;
	} else if (s == 4) {
		// swipe: sector of a ring revealed by progress with a bright leading edge
		if (r > 1.0 || r < inner || abs(ang) > half_angle) discard;
		float t = (ang + half_angle) / (2.0 * half_angle);   // 0..1 across the sector
		float lead = progress;
		if (t > lead) discard;
		float tail = clamp(1.0 - (lead - t) * 1.8, 0.0, 1.0);
		float band = (r - inner) / max(1.0 - inner, 0.001);
		a = tail * (0.55 + 0.45 * band);
		e = step(0.82, band) * tail + step(lead - 0.06, t);
		if (a < 0.08) discard;
	} else {
		// sigil: two rings and spokes
		if (r > 1.0) discard;
		float ring1 = step(0.88, r) * step(r, 0.97);
		float ring2 = step(0.55, r) * step(r, 0.62);
		float spokes = step(0.94, cos(ang * 6.0 + progress * 6.283)) * step(0.62, r) * step(r, 0.88);
		e = max(max(ring1, ring2), spokes);
		a = 0.1 + 0.15 * step(r, progress);
		if (e < 0.5 && a < 0.12) discard;
	}
	vec4 col = mix(color, edge_color, clamp(e, 0.0, 1.0));
	float alpha = clamp(max(a, e), 0.0, 1.0) * col.a * fade;
	// solid where strong, ordered dither only in the soft falloff
	float thr = alpha > 0.62 ? 0.0 : bayer4(FRAGCOORD.xy);
	if (thr > alpha * 1.3) discard;
	ALBEDO = col.rgb * glow;
}
