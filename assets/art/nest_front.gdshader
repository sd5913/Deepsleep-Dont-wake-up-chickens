shader_type canvas_item;
uniform float front_start = 0.55;
void fragment() {
 if (UV.y < front_start || COLOR.a < 0.5) { discard; }
 COLOR.a = 1.0;
}
