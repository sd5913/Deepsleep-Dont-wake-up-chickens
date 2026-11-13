shader_type canvas_item;
// Align the illustrated floor edges with the existing rectangular collision arena.
void fragment() {
 vec2 uv = UV;
 float top = 74.0 / 540.0;
 float bottom = 478.0 / 540.0;
 float t = clamp((uv.y - top) / (bottom - top), 0.0, 1.0);
 float sy;
 if (uv.y < top) { sy = uv.y / top * 0.233; }
 else if (uv.y > bottom) { sy = mix(0.827, 1.0, (uv.y-bottom)/(1.0-bottom)); }
 else { sy = mix(0.233, 0.827, t); }
 float edge = mix(0.078, 0.027, t);
 float sx;
 if (uv.x < 0.0375) { sx = uv.x / 0.0375 * edge; }
 else if (uv.x > 0.9625) { sx = mix(1.0-edge, 1.0, (uv.x-0.9625)/0.0375); }
 else { sx = mix(edge, 1.0-edge, (uv.x-0.0375)/0.925); }
 COLOR = texture(TEXTURE, vec2(sx, sy));
}
