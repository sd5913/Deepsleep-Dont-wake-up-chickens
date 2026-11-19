class_name CoopPlayer
extends CharacterBody2D

@export_range(1.0, 600.0, 1.0) var move_speed := 250.0

var movement_locked := false
var searching := false
var invulnerable := false
var concealed := false
var _facing := Vector2.UP
var _toss_left := 0.0
var _startle_left := 0.0

@onready var _art: CoopCharacterArt = $Art
@onready var _search_glow: Sprite2D = $SearchGlow


func aim_direction() -> Vector2:
	var direction := Vector2.ZERO if movement_locked else _move_input()
	return _facing if direction.is_zero_approx() else direction.normalized()


func _physics_process(delta: float) -> void:
	_art.modulate = Color(0.65,0.92,1.0,0.58) if concealed else (Color(0.72,0.94,1.0) if invulnerable else Color.WHITE)
	_search_glow.visible = searching
	_toss_left = maxf(0.0, _toss_left - delta)
	_startle_left = maxf(0.0,_startle_left-delta)
	if movement_locked:
		velocity = Vector2.ZERO
		_art.update_pose(_facing, false, &"search" if searching else &"idle", delta)
		return
	var direction := _move_input()
	if not direction.is_zero_approx():
		_facing = direction.normalized()
	velocity = direction * move_speed
	move_and_slide()
	_art.update_pose(_facing, get_real_velocity().length_squared() > 1.0, &"startle" if _startle_left > 0.0 else (&"toss" if _toss_left > 0.0 else &"idle"), delta)


func show_startle() -> void:
	_startle_left = 0.42

func show_feed_toss() -> void:
	_toss_left = 0.3


func _move_input() -> Vector2:
	return Input.get_vector("move_left", "move_right", "move_up", "move_down")
