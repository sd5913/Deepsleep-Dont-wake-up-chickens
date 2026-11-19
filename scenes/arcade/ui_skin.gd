class_name ArcadeUISkin
extends RefCounted

const INK := Color("09121f")
const PANEL := Color("101e30")
const CARD := Color("172a3b")
const GOLD := Color("ddb875")
const CREAM := Color("ffedc3")
const MUTED := Color("a4b2b5")
const ACCENTS := [Color("e9be73"),Color("accd8a"),Color("75c9bd"),Color("d3cf7c")]

static func box(background := PANEL, border := Color("49515a"), width := 1) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(width)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.shadow_color = Color(0.01,0.025,0.045,0.6)
	style.shadow_size = 3
	style.shadow_offset = Vector2(0,3)
	return style

static func button(background := CARD, border := Color("586265"), width := 1) -> StyleBoxFlat:
	var style := box(background,border,width)
	style.border_width_bottom = maxi(3,width)
	return style

static func meter(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	return style
