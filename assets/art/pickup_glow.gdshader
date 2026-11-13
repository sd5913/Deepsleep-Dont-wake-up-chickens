shader_type canvas_item;

void fragment() {
	float radius = length(UV * 2.0 - 1.0);
	// A feathered annulus leaves the center clear and fades at the real boundary.
	float haze = smoothstep(0.64, 0.84, radius) * (1.0 - smoothstep(0.88, 1.0, radius));
	float rim = smoothstep(0.84, 0.9, radius) * (1.0 - smoothstep(0.9, 0.97, radius));
	COLOR = vec4(1.0, 0.88, 0.49, haze * 0.10 + rim * 0.13);
}
