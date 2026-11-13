class_name CoopFarmer
extends CharacterBody2D

signal player_caught
signal departed

enum State { SEARCHING, CHASING, RETREATING }

const SEARCH_DIRECTIONS := [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP]

@export_range(1.0, 400.0, 1.0) var chase_speed := 185.0
@export_range(1.0, 400.0, 1.0) var walk_speed := 125.0
@export_range(16.0, 600.0, 1.0) var vision_distance := 240.0
@export_range(8.0, 60.0, 1.0) var capture_distance := 25.0
@export_range(0.5, 20.0, 0.1) var search_seconds := 3.0
@export_range(8.0, 150.0, 1.0) var search_radius := 48.0
@export_range(0.0, 100.0, 1.0) var retreat_alert_level := 30.0

var player: CoopPlayer
var alert: CoopAlert
var home_position := Vector2.ZERO
var last_known_position := Vector2.ZERO
var sees_player := false
var state := State.SEARCHING

var _search_index := -1
var _search_elapsed := 0.0
var _facing := Vector2.DOWN
var _sight_ray := PhysicsRayQueryParameters2D.new()

@onready var _body: CoopCharacterArt = $Body


func _physics_process(delta: float) -> void:
	var previous_position := position
	var distance := global_position.distance_to(player.global_position)
	# The same clear ray is required for pursuit and capture.
	sees_player = not player.invulnerable and distance <= vision_distance and _has_clear_sight(player.global_position)
	if sees_player:
		last_known_position = player.global_position
		_search_index = -1
		_search_elapsed = 0.0
		state = State.CHASING
		if distance <= capture_distance:
			set_physics_process(false)
			player_caught.emit()
			return
		_walk_to(last_known_position, chase_speed, delta)
	elif state == State.RETREATING:
		if _walk_to(home_position, walk_speed, delta):
			set_physics_process(false)
			departed.emit()
	else:
		state = State.SEARCHING
		_search(delta)

	_body.update_pose(_facing, position.distance_squared_to(previous_position) > 0.001, &"idle", delta)


func _has_clear_sight(target: Vector2) -> bool:
	_sight_ray.from = global_position
	_sight_ray.to = target
	_sight_ray.collision_mask = collision_mask
	return get_world_2d().direct_space_state.intersect_ray(_sight_ray).is_empty()


func _search(delta: float) -> void:
	if _search_index == -1:
		if _walk_to(last_known_position, walk_speed, delta):
			_search_index = 0
		return

	_search_elapsed += delta
	if _search_elapsed >= search_seconds and alert.level <= retreat_alert_level:
		state = State.RETREATING
		return

	var search_point: Vector2 = last_known_position + SEARCH_DIRECTIONS[_search_index] * search_radius
	if _walk_to(search_point, walk_speed, delta):
		_search_index = (_search_index + 1) % SEARCH_DIRECTIONS.size()


func _walk_to(target: Vector2, speed: float, delta: float) -> bool:
	var offset := CoopNavigation.next_offset(self, target)
	if offset == Vector2.INF:
		return false
	if offset.is_zero_approx():
		return true
	_facing = offset.normalized()
	move_and_collide(offset.limit_length(speed * delta))
	return false
