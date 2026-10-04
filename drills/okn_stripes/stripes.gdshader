shader_type canvas_item;

// Vertical stripes scrolling sideways at a constant speed.
uniform float speed = 0.25;
uniform float stripes = 14.0;
uniform vec4 dark : source_color = vec4(0.1, 0.11, 0.14, 1.0);
uniform vec4 light : source_color = vec4(0.42, 0.45, 0.52, 1.0);

void fragment() {
	float x = fract(UV.x * stripes - TIME * speed * stripes);
	COLOR = x < 0.5 ? dark : light;
}
