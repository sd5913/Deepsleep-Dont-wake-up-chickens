shader_type canvas_item;
// COLOR already includes the texture and node modulation in a canvas fragment.
void fragment() {
 if (COLOR.a < 0.5) { discard; }
 COLOR.a = 1.0;
}
