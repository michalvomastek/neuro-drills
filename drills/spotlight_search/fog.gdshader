shader_type canvas_item;

// Dark fog with a soft circular hole around the pointer (UV space).
uniform vec2 spot_center = vec2(0.5, 0.5);
uniform float spot_radius = 0.12;
uniform float softness = 0.03;
uniform float aspect = 1.0;
uniform vec4 fog_color : source_color = vec4(0.07, 0.075, 0.09, 1.0);

void fragment() {
	vec2 d = UV - spot_center;
	d.x *= aspect;
	float alpha = smoothstep(spot_radius - softness, spot_radius, length(d));
	COLOR = vec4(fog_color.rgb, alpha);
}
