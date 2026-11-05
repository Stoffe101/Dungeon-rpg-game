// Soft edge darkening plus a red pulse when hurt or at low health.
shader_type canvas_item;

uniform float strength = 0.24;
uniform float hurt = 0.0;
uniform float low = 0.0;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	p.x *= 0.8;
	float d = dot(p, p);
	float v = smoothstep(0.55, 1.6, d) * strength;
	float r = smoothstep(0.35, 1.4, d) * max(hurt, low * (0.6 + 0.4 * sin(TIME * 5.0)));
	COLOR = vec4(mix(vec3(0.0), vec3(0.55, 0.02, 0.05), r / max(v + r, 0.001)), clamp(v + r * 0.7, 0.0, 0.9));
}
