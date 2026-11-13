class_name CoopFeedField
extends Node2D

enum ThrowResult { PLACED, EMPTY, BLOCKED }

const FEED_SCENE := preload("res://scenes/feed.tscn")
const BAIT_SPACING_SQUARED := 324.0

@export_range(16.0, 80.0, 1.0) var pickup_distance := 38.0
@export_range(24.0, 240.0, 1.0) var throw_distance := 160.0
@export_range(0, 9) var starting_feed := 2

var held_count := 0

@onready var _supplies: Node2D = $Supplies
@onready var _baits: Node2D = $Baits


func _ready() -> void:
	held_count = starting_feed


func nearest_pickup(origin: Vector2) -> CoopFeed:
	var nearest: CoopFeed
	var nearest_distance := INF
	for supply: CoopFeed in _supplies.get_children():
		if supply.is_queued_for_deletion():
			continue
		var distance := origin.distance_squared_to(supply.global_position)
		if distance <= pickup_distance * pickup_distance and distance < nearest_distance:
			nearest = supply
			nearest_distance = distance
	return nearest


func collect(supply: CoopFeed) -> void:
	if supply.is_queued_for_deletion():
		return
	supply.queue_free()
	held_count += 1


func aim_destination(player: CoopPlayer) -> Vector2:
	var offset := player.get_global_mouse_position() - player.global_position
	if offset.length_squared() < 24.0 * 24.0:
		offset = player.aim_direction() * 24.0
	return player.global_position + offset.limit_length(throw_distance)


func can_place(player: CoopPlayer, destination: Vector2) -> bool:
	if player.global_position.distance_squared_to(destination) > throw_distance * throw_distance + 0.01:
		return false
	var map := get_world_2d().navigation_map
	if NavigationServer2D.map_get_iteration_id(map) == 0:
		return false
	if NavigationServer2D.map_get_closest_point(map, destination).distance_squared_to(destination) > 1.0:
		return false
	if player.test_move(player.global_transform, destination - player.global_position):
		return false
	for bait: CoopFeed in _baits.get_children():
		if not bait.is_queued_for_deletion() and bait.global_position.distance_squared_to(destination) < BAIT_SPACING_SQUARED:
			return false
	return true


func throw_from(player: CoopPlayer, destination := Vector2.INF) -> ThrowResult:
	if held_count == 0:
		return ThrowResult.EMPTY
	if destination == Vector2.INF:
		destination = aim_destination(player)
	if not can_place(player, destination):
		return ThrowResult.BLOCKED
	var bait: CoopFeed = FEED_SCENE.instantiate()
	bait.dropped = true
	bait.position = _baits.to_local(destination)
	_baits.add_child(bait)
	held_count -= 1
	return ThrowResult.PLACED
