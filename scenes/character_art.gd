class_name CoopCharacterArt
extends Node2D

# Shared pixel atlas: four poses per character, one character per row.
const ATLAS := preload("res://assets/art/characters.png")
const RUN_ATLAS := preload("res://assets/art/thief_run.png")
const RUN_REGIONS := [
	[Rect2(133,51,240,354),Rect2(541,51,240,354),Rect2(987,51,240,354),Rect2(1429,51,240,354)],
	[Rect2(120,491,240,354),Rect2(532,491,240,354),Rect2(979,491,240,354),Rect2(1420,491,240,354)],
]
@export_enum("Thief", "Keeper", "Hen") var character := 0
@export var sprite_height := 48.0

var _sprite: Sprite2D
var _frames: Array[AtlasTexture] = []
var _phase := 0.0
var _run_clock := 0.0
var _run_frames: Array[AtlasTexture] = []
# Tight regions in the generated atlas, aligned to each pose's foot baseline.
const REGIONS := [
	[Rect2(125, 60, 168, 264), Rect2(467, 60, 162, 264), Rect2(794, 60, 176, 264), Rect2(1140, 60, 184, 264)],
	[Rect2(61, 411, 262, 277), Rect2(433, 411, 229, 277), Rect2(793, 413, 205, 275), Rect2(1129, 416, 253, 272)],
	[Rect2(114, 810, 167, 187), Rect2(458, 810, 165, 187), Rect2(798, 844, 203, 153), Rect2(1151, 810, 218, 187)],
]
var _pixel_scale := 1.0

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite = Sprite2D.new()
	for column in range(4):
		var frame := AtlasTexture.new()
		frame.atlas = ATLAS
		frame.region = REGIONS[character][column]
		_frames.append(frame)
	if character == 0:
		for row in RUN_REGIONS:
			for region in row:
				var frame := AtlasTexture.new()
				frame.atlas = RUN_ATLAS
				frame.region = region
				_run_frames.append(frame)
	_pixel_scale = sprite_height / [264.0, 277.0, 187.0][character]
	_sprite.texture = _frames[0]
	_sprite.scale = Vector2.ONE * _pixel_scale
	var material := ShaderMaterial.new()
	material.shader = preload("res://assets/art/pixel_cutout.gdshader")
	_sprite.material = material
	_sprite.position.y = -_frames[0].region.size.y * _pixel_scale * 0.5
	add_child(_sprite)

func update_pose(direction: Vector2, moving: bool, action: StringName, delta: float) -> void:
	if _sprite == null:
		return
	_phase += delta
	var frame := 0
	var bob := 0.0
	_sprite.flip_h = direction.x < -0.15
	_sprite.rotation = 0.0
	_sprite.modulate = Color.WHITE
	_sprite.scale = Vector2.ONE * _pixel_scale
	if character == 0 and moving and absf(direction.y) > absf(direction.x) and action != &"search":
		_show_vertical_run(direction,delta)
		return
	_run_clock = 0.0
	if character == 2:
		if action == &"eat":
			frame = 2
			bob = sin(_phase * 16.0) * 0.6
		elif action == &"alarm":
			frame = 3
		elif moving:
			frame = 1 if int(_phase * 9.0) % 2 else 0
			bob = -absf(sin(_phase * 12.0)) * 1.0
	else:
		if absf(direction.y) > absf(direction.x):
			frame = 1 if direction.y < 0.0 else 0
		else:
			frame = 3 if moving and int(_phase * 8.0) % 2 else 2
		if moving:
			bob = -absf(sin(_phase * 13.0)) * 1.5
		if action == &"search":
			frame = 2
			_sprite.rotation = (-0.1 if _sprite.flip_h else 0.1) + sin(_phase * 12.0) * 0.025
			bob = sin(_phase * 12.0) * 0.7
		elif action == &"toss":
			frame = 3
			_sprite.rotation = -0.12 if _sprite.flip_h else 0.12
	if character == 1:
		var lantern := get_node_or_null("LanternGlow") as Sprite2D
		if lantern != null:
			var side := -1.0 if frame == 0 else 1.0
			lantern.position = Vector2(side * (-1.0 if _sprite.flip_h else 1.0) * sprite_height * 0.32, -sprite_height * 0.28)
	_sprite.texture = _frames[frame]
	_sprite.position.y = -_frames[frame].region.size.y * _pixel_scale * 0.5 + bob

func _show_vertical_run(direction: Vector2, delta: float) -> void:
	_run_clock += delta
	var index := floori(_run_clock * 10.0) % 4
	if direction.y < 0.0: index += 4
	_sprite.texture = _run_frames[index]
	_sprite.scale = Vector2.ONE * sprite_height / 354.0
	_sprite.flip_h = false
	_sprite.position = Vector2(0,-sprite_height*0.5)
