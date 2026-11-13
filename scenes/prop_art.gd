extends Sprite2D

const ATLAS := preload("res://assets/art/coop_props.png")
const REGIONS := [Rect2(190, 80, 400, 410), Rect2(735, 80, 735, 410), Rect2(190, 560, 380, 395), Rect2(900, 650, 435, 240)]
@export_enum("Nest", "Cover", "Feed sack", "Grain") var prop := 0
@export_range(8.0, 256.0, 1.0) var display_width := 70.0
@export var ground_offset := 20.0

func _ready() -> void:
	var atlas := AtlasTexture.new()
	atlas.atlas = ATLAS
	atlas.region = REGIONS[prop]
	texture = atlas
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# One scale factor keeps the original atlas proportions for every prop.
	scale = Vector2.ONE * display_width / atlas.region.size.x
	position.y = ground_offset - atlas.region.size.y * scale.y * 0.5
	var cutout := ShaderMaterial.new()
	cutout.shader = preload("res://assets/art/pixel_cutout.gdshader")
	material = cutout
