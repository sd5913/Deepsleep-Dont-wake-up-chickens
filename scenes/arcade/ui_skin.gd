class_name ArcadeUISkin
extends RefCounted

const INK := Color("09121f")
const PANEL := Color("101e30")
const CARD := Color("172a3b")
const GOLD := Color("ddb875")
const CREAM := Color("ffedc3")
const MUTED := Color("a4b2b5")
const ACCENTS := [Color("e9be73"),Color("accd8a"),Color("75c9bd"),Color("d3cf7c")]
const MENU_BACKGROUND := preload("res://assets/ui/farm_menu_background.svg")
const BUTTON_TEXTURES := {
	"normal": preload("res://assets/ui/farm_buttons/button_normal.svg"),
	"hover": preload("res://assets/ui/farm_buttons/button_hover.svg"),
	"pressed": preload("res://assets/ui/farm_buttons/button_pressed.svg"),
	"disabled": preload("res://assets/ui/farm_buttons/button_disabled.svg"),
	"selected": preload("res://assets/ui/farm_buttons/button_selected.svg"),
	"level_selected": preload("res://assets/ui/farm_buttons/button_level_selected.svg"),
	"primary": preload("res://assets/ui/farm_buttons/button_primary.svg"),
}

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

static func button(state := "normal") -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = BUTTON_TEXTURES.get(state, BUTTON_TEXTURES.normal)
	style.texture_margin_left = 18
	style.texture_margin_right = 18
	style.texture_margin_top = 10
	style.texture_margin_bottom = 10
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style

static func focus() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0,0,0,0)
	style.border_color = Color("fff0b0")
	style.set_border_width_all(2)
	return style

static func meter(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	return style
