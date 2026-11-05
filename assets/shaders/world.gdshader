// Environment surfaces (floors, wall faces, wall tops, pits).
// Lighting is quantised into bands with ordered dithering at the band edges so
// real 3D lights read like hand-shaded pixel art.
//
// The dungeon's grammar (LevelBuilder passes what each surface touches):
//   floor  - quieter than anything that stands on it; a contact shadow where
//            it meets a wall, a pillar or a solid prop; a lit lip at a pit.
//   top    - the cap of something you cannot walk through: a bright rim on
//            every open edge, darkening toward the middle of thick rock (it
//            used to read as another floor, a level up).
//   wall   - a face: dark at its foot where it meets the floor, a lip of light
//            under its cap.
//   pit    - falls away into the dark.
// Every step is snapped to the 16-texel grid and dithered, never smooth.
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
uniform int surface = 0;          // 0 floor, 1 top, 2 wall face, 3 pit
uniform float contrast = 1.0;     // floors: eased toward their own average
uniform vec3 mid : source_color = vec3(0.2);
uniform float rim_strength = 1.0;
uniform vec3 rim_color : source_color = vec3(0.5, 0.52, 0.62);   // the region's dressed stone
uniform float contact_strength = 1.0;

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
const float SQ2 = 1.41421356;

float bayer4(vec2 p) {
	int x = int(mod(p.x, 4.0));
	int y = int(mod(p.y, 4.0));
	return (BAYER[x + y * 4] + 0.5) / 16.0;
}

bool bit(int bits, int i) {
	return ((bits >> i) & 1) != 0;
}

// a stepped falloff over `d` texels: 0 at the edge, 1 beyond `reach`
float steps(float d, float reach) {
	return clamp(floor(d / reach * 3.0) / 3.0, 0.0, 1.0);
}

void fragment() {
	vec4 c = texture(albedo_tex, UV * uv_scale);
	vec3 col = c.rgb * tint.rgb;
	float rim_glow = 0.0;     // a faint light of its own: a wall's outline survives the dark
	// the 16-texel grid of this tile (world x is the tile x; z is the tile y * sqrt2)
	vec2 tw = vec2(wpos.x, wpos.z / SQ2) * 16.0;
	vec2 tx = floor(tw);
	vec2 lt = tx - floor(tw / 16.0) * 16.0;      // 0..15 within the tile
	float j = bayer4(tx) - 0.5;                    // world-locked dither
	if (surface == 0) {
		if (grime > 0.0) {
			// snap to the texel grid so the patches stay pixel art
			vec2 g = floor(wpos.xz * 16.0) / 16.0;
			float n = vnoise(g * 0.22) * 0.65 + vnoise(g * 0.71 + 13.0) * 0.35;
			float d = bayer4(floor(wpos.xz * 16.0)) * 0.12;
			float k = smoothstep(0.52, 0.53, n + d) * 0.6 + smoothstep(0.66, 0.67, n + d) * 0.4;
			col = mix(col, col * grime_color, k * grime);
		}
		col = mid * tint.rgb + (col - mid * tint.rgb) * contrast;
		int sb = int(UV2.x + 0.5);
		int pb = int(UV2.y + 0.5);
		float ao = 1.0;
		// N: the foot of a wall face - the strongest contact shadow
		if (bit(sb, 0)) ao = min(ao, mix(0.5, 1.0, steps(lt.y + j * 1.5, 6.0)));
		if (bit(sb, 1)) ao = min(ao, mix(0.66, 1.0, steps(15.0 - lt.x + j * 1.5, 4.0)));
		if (bit(sb, 2)) ao = min(ao, mix(0.74, 1.0, steps(15.0 - lt.y + j * 1.5, 3.0)));
		if (bit(sb, 3)) ao = min(ao, mix(0.66, 1.0, steps(lt.x + j * 1.5, 4.0)));
		// corners the edges above do not already cover
		if (bit(sb, 4) && !bit(sb, 0) && !bit(sb, 1)) ao = min(ao, mix(0.62, 1.0, steps(max(15.0 - lt.x, lt.y) + j, 4.0)));
		if (bit(sb, 5) && !bit(sb, 2) && !bit(sb, 1)) ao = min(ao, mix(0.75, 1.0, steps(max(15.0 - lt.x, 15.0 - lt.y) + j, 3.0)));
		if (bit(sb, 6) && !bit(sb, 2) && !bit(sb, 3)) ao = min(ao, mix(0.75, 1.0, steps(max(lt.x, 15.0 - lt.y) + j, 3.0)));
		if (bit(sb, 7) && !bit(sb, 0) && !bit(sb, 3)) ao = min(ao, mix(0.62, 1.0, steps(max(lt.x, lt.y) + j, 4.0)));
		col *= mix(1.0, ao, contact_strength);
		// the lip of a pit catches the light
		float lip = 0.0;
		if (bit(pb, 0) && lt.y < 1.0) lip = 1.0;
		if (bit(pb, 1) && lt.x > 14.0) lip = 1.0;
		if (bit(pb, 2) && lt.y > 14.0) lip = 1.0;
		if (bit(pb, 3) && lt.x < 1.0) lip = 1.0;
		col *= 1.0 + 0.35 * lip;
	} else if (surface == 1) {
		int ob = int(UV2.x + 0.5);
		// rim: one bright texel row (and a softer second) on every open edge
		float e = 99.0;
		if (bit(ob, 0)) e = min(e, lt.y);
		if (bit(ob, 1)) e = min(e, 15.0 - lt.x);
		if (bit(ob, 2)) e = min(e, 15.0 - lt.y);
		if (bit(ob, 3)) e = min(e, lt.x);
		if (bit(ob, 4)) e = min(e, max(15.0 - lt.x, lt.y));
		if (bit(ob, 5)) e = min(e, max(15.0 - lt.x, 15.0 - lt.y));
		if (bit(ob, 6)) e = min(e, max(lt.x, 15.0 - lt.y));
		if (bit(ob, 7)) e = min(e, max(lt.x, lt.y));
		// the cap is dressed stone (lifted toward the region's stone), and thick
		// rock darkens toward its middle (COLOR.r: depth into the rock, 0..1 of 6 tiles)
		col = mix(col, rim_color * 0.5, 0.45);
		float depth = COLOR.r * 6.0;
		// (flat on the rim tiles; dithered steps only where the rock thickens)
		float shade = 1.0;
		if (depth > 1.0) {
			shade = clamp(1.0 - 0.3 * (depth - 1.0) + j * 0.12, 0.16, 1.0);
			shade = floor(shade * 6.0 + 0.5) / 6.0;
		}
		col *= shade;
		col = mix(col, vec3(0.012, 0.012, 0.022), clamp((depth - 1.6) * 0.3, 0.0, 0.75));
		if (e < 1.0) {
			col = mix(col, rim_color, 0.72 * rim_strength);
			rim_glow = 0.12 * rim_strength;
		} else if (e < 2.0) {
			col = mix(col, rim_color, 0.26 * rim_strength);
		}
	} else if (surface == 2) {
		// UV2.x: the face's height in tiles; UV2.y: 0 at its cap, 1 at its foot
		float hh = max(UV2.x, 0.25);
		float from_top = UV2.y * hh * 16.0;
		float from_foot = (1.0 - UV2.y) * hh * 16.0;
		float k = mix(0.52, 1.0, steps(from_foot + j * 1.5, 6.0));
		if (from_top < 1.0) {
			k = 1.22;
		}
		col *= mix(1.0, k, contact_strength);
	} else if (surface == 3) {
		// a pit's floor is far below; its far wall falls away into the dark
		float f = UV2.y;
		float k = 0.72 - 0.66 * clamp(floor((f + j * 0.12) * 6.0) / 6.0, 0.0, 1.0);
		col = mix(vec3(0.01, 0.008, 0.02), col, k);
	}
	ALBEDO = col;
	EMISSION = emission_color.rgb + rim_color * rim_glow;
}

// the light's tail is lifted before it is banded (v^falloff): the pool a
// lantern or a torch throws reads several tiles further before the last band
// gives out (it used to drop to black about four tiles from the lantern)
uniform float falloff = 0.62;

void light() {
	float ndl = clamp((dot(NORMAL, LIGHT) + wrap) / (1.0 + wrap), 0.0, 1.0);
	float v = pow(ndl * ATTENUATION, falloff);
	float d = (bayer4(FRAGCOORD.xy) - 0.5) * dither_strength;
	float q = floor(v * bands + 0.5 + d) / bands;
	DIFFUSE_LIGHT += max(q, 0.0) * LIGHT_COLOR / PI;
}
