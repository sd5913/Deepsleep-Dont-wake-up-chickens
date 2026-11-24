class_name ArcadeSnake
extends CharacterBody2D

signal player_hit
signal dashed
signal hatched
const ATLAS := preload("res://assets/art/snake_atlas.png")
const ART_SCALE := 0.24
const HATCH_SECONDS := 0.78
const BURST_SECONDS := 1.50
const DASH_SPEED := 460.0
const MAX_DASH_SECONDS := 1.55
var player: CoopPlayer
var direction := Vector2.RIGHT
var preview := false
var age := 0.0
var retiring := false
var retire_age := 0.0
var art: Node2D
var sprite: Sprite2D
var frame_index := -1
var hand_offset := Vector2.ZERO
var did_hatch := false
var did_dash := false
static var _textures: Array[AtlasTexture] = []

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = 3
	collision_layer = 0
	collision_mask = 2
	var collider := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 7.0
	collider.shape = circle
	add_child(collider)
	if _textures.is_empty():
		for i in range(12):
			var texture := AtlasTexture.new()
			texture.atlas = ATLAS
			texture.region = Rect2((i%4)*362,(i/4)*362,362,362)
			_textures.append(texture)
	art = Node2D.new()
	add_child(art)
	sprite = Sprite2D.new()
	sprite.centered = false
	sprite.scale = Vector2.ONE*ART_SCALE
	sprite.material = ThemeSprites.pixel_material(_textures[0].region,36,ATLAS)
	art.add_child(sprite)
	if is_instance_valid(player): hand_offset = player.global_position+Vector2(16,-30)-global_position
	_update_art()

func _process(delta: float) -> void:
	if preview:
		age = fmod(age+delta,0.9)
		_update_art()
	queue_redraw()

func _physics_process(delta: float) -> void:
	if preview: return
	if retiring:
		retire_age += delta
		_update_art()
		if retire_age >= 0.2: queue_free()
		return
	if age < HATCH_SECONDS and is_instance_valid(player):
		hand_offset = player.global_position+Vector2(16,-30)-global_position
	age += delta
	if not did_hatch and age >= HATCH_SECONDS:
		did_hatch = true
		hatched.emit()
	_update_art()
	if age < BURST_SECONDS: return
	if not did_dash:
		did_dash = true
		dashed.emit()
	var previous := global_position
	var travel := direction*DASH_SPEED*minf(delta,age-BURST_SECONDS)
	var collision := move_and_collide(travel)
	# Swept contact prevents fast snakes tunneling through the player.
	if is_instance_valid(player) and not player.invulnerable:
		var nearest := Geometry2D.get_closest_point_to_segment(player.global_position,previous+direction*9.0,global_position+direction*9.0)
		if player.global_position.distance_squared_to(nearest) <= 20.0*20.0:
			player_hit.emit()
			retiring = true
	if collision != null or age >= BURST_SECONDS+MAX_DASH_SECONDS: retiring = true

func _update_art() -> void:
	var index := 0
	if preview: index = 6+int(age*12.0)%4
	elif age < 0.40: index = 0
	elif age < HATCH_SECONDS: index = 1
	elif age < 0.94: index = 2
	elif age < 1.10: index = 3
	elif age < BURST_SECONDS: index = 4 if age < 1.28 else 5
	else: index = 6+int(age*12.0)%4
	if retiring: index = 10 if retire_age < 0.1 else 11
	art.position = Vector2.ZERO
	art.scale = Vector2.ONE
	if not preview and age < HATCH_SECONDS:
		var lift := clampf(age/0.32,0.0,1.0)
		art.position = hand_offset*lift
		art.scale = Vector2.ONE*lerpf(0.6,1.12,lift)
		if age > 0.40: art.position.x += sin(age*70.0)*2.5
	elif not preview and age < 1.10:
		var fall := clampf((age-HATCH_SECONDS)/(1.10-HATCH_SECONDS),0.0,1.0)
		art.position = hand_offset*(1.0-fall)+Vector2(0,-sin(fall*PI)*18.0)
	if index == frame_index: return
	frame_index = index
	sprite.texture = _textures[index]
	var anchor := Vector2(280 if index >= 5 and index <= 9 else 181,335 if index < 4 else 289)
	sprite.position = -anchor*ART_SCALE
	art.rotation = direction.angle() if index >= 5 and not preview else 0.0
	var region: Rect2 = _textures[index].region
	sprite.material.set_shader_parameter("frame_region",Vector4(region.position.x/ATLAS.get_width(),region.position.y/ATLAS.get_height(),region.size.x/ATLAS.get_width(),region.size.y/ATLAS.get_height()))

func _draw() -> void:
	if preview or age < HATCH_SECONDS or age >= BURST_SECONDS: return
	var color := Color(1.0,0.9,0.5,0.65)
	var tip := direction*46.0
	draw_line(direction*18.0,tip,color,2.0)
	draw_line(tip,tip-direction.rotated(0.6)*9.0,color,2.0)
	draw_line(tip,tip-direction.rotated(-0.6)*9.0,color,2.0)
