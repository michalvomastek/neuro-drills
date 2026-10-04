shader_type canvas_item;

// Radial streaks flowing from the centre outwards: a cheap optic-flow field.
uniform float speed = 0.6;
uniform float density = 40.0;
uniform vec4 streak_color : source_color = vec4(0.55, 0.6, 0.7, 1.0);

float hash(float n) {
	return fract(sin(n) * 43758.5453);
}

void fragment() {
	vec2 p = UV - vec2(0.5, 0.5);
	float r = length(p) + 0.001;
	float a = atan(p.y, p.x);
	float ray = floor((a / 6.2831853 + 0.5) * density);
	float seed = hash(ray);
	float phase = fract(log(r * 8.0 + 1.0) * 2.0 - TIME * speed * (0.6 + seed));
	float streak = smoothstep(0.0, 0.08, phase) * (1.0 - smoothstep(0.12, 0.3, phase));
	float width = 1.0 - smoothstep(0.0, 0.45, abs(fract((a / 6.2831853 + 0.5) * density) - 0.5));
	float v = streak * width * smoothstep(0.03, 0.2, r);
	COLOR = vec4(streak_color.rgb, v * 0.75);
}
