class_name ArcadePowerup
extends Node2D

enum Kind { DOUBLE, BASKET, STEALTH }

const ATLAS := preload("res://assets/art/powerups.png")
const REGIONS := [Rect2(138,139,384,480),Rect2(730,128,691,486),Rect2(1629,132,454,479)]
# Ordinals across the four maps: 1-2, 2-1, 3-1. Keep progression data here.
const UNLOCK_STAGES := [2,5,9]
const DURATIONS := [6.0,6.0,4.0]
const NAMES_ZH := ["双倍徽章","大菜篮","隐匿护盾"]
const NAMES_EN := ["Double Badge","Big Basket","Stealth Shield"]
const EFFECTS_ZH := ["6秒内收集得分翻倍，连击还能叠加！","6秒内拾取半径扩大35%，一圈收更多！","4秒内动物和农夫看不到你，趁机抢收或躲藏！"]
const EFFECTS_EN := ["Double collection points for 6s. Stacks with your combo!","35% more pickup radius for 6s. Gather a bigger ring!","Animals and the farmer cannot see you for 4s. Gather or escape!"]
const SHORT_ZH := ["得分×2","范围+35%","隐匿"]
const SHORT_EN := ["Score x2","Reach +35%","Unseen"]
const COLORS := [Color("ffda72"),Color("f0be6b"),Color("85e5e9")]
static var _textures: Array[AtlasTexture] = []

var kind := Kind.DOUBLE
var claimed := false
var highlighted := false
var phase := 0.0

static func available_for(map_index: int, room: int) -> Array[int]:
	var result: Array[int] = []
	var ordinal := (map_index-1)*4+room
	for i in range(UNLOCK_STAGES.size()):
		if ordinal >= UNLOCK_STAGES[i]: result.append(i)
	return result

static func texture_for(index: int) -> AtlasTexture:
	if _textures.is_empty():
		for region in REGIONS:
			var texture := AtlasTexture.new()
			texture.atlas = ATLAS
			texture.region = region
			_textures.append(texture)
	return _textures[index]

static func name_for(index: int, language := "zh") -> String:
	return (NAMES_EN if language == "en" else NAMES_ZH)[index]

static func description_for(index: int, language := "zh") -> String:
	return (EFFECTS_EN if language == "en" else EFFECTS_ZH)[index]

static func unlock_caption(index: int, language := "zh") -> String:
	var ordinal: int = UNLOCK_STAGES[index]-1
	return ("Unlocks %d-%d" if language == "en" else "%d-%d 解锁") % [ordinal/4+1,ordinal%4+1]

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var cutout := ShaderMaterial.new()
	cutout.shader = preload("res://assets/art/pixel_cutout.gdshader")
	material = cutout

func _process(delta: float) -> void:
	phase += delta
	queue_redraw()

func _draw() -> void:
	var color: Color = COLORS[kind]
	draw_colored_polygon(PackedVector2Array([Vector2(-17,7),Vector2(0,1),Vector2(17,7),Vector2(0,13)]),Color(color,0.24))
	var size: Vector2 = REGIONS[kind].size
	size *= 36.0/maxf(size.x,size.y)
	var bob := roundf(sin(phase*3.5)*2.0)
	draw_texture_rect(texture_for(kind),Rect2(Vector2(-size.x*0.5,-size.y+10+bob),size),false,Color(1.22,1.18,1.05) if highlighted else Color.WHITE)
	for i in range(3):
		var angle := phase*1.3+i*TAU/3.0
		var point := Vector2(cos(angle)*20.0,sin(angle)*7.0-8.0).round()
		draw_rect(Rect2(point,Vector2(2,2)),color)
