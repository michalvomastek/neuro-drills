shader_type canvas_item;

// Sinusoidal grating under a Gaussian envelope on mid grey.
uniform float contrast = 0.5;
uniform float orientation = 0.0;
uniform float frequency = 6.0;
uniform float sigma = 0.16;

void fragment() {
	vec2 p = UV - vec2(0.5, 0.5);
	float x = p.x * cos(orientation) + p.y * sin(orientation);
	float grating = sin(x * frequency * 6.2831853);
	float envelope = exp(-dot(p, p) / (2.0 * sigma * sigma));
	float v = 0.5 + 0.5 * contrast * grating * envelope;
	COLOR = vec4(vec3(v), 1.0);
}
