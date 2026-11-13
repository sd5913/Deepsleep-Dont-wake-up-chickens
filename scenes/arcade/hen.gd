class_name ArcadeHen
extends CoopChicken

var world: ArcadeWorld
var golden := false
var lay_left := 6.0
var roaming_enabled := true
var roam_target := Vector2.INF
var _sectors: Array[int] = []
var _last_sector := -1
var _stuck_left := 0.0
var _target_age := 0.0
signal egg_laid(point: Vector2, gold: bool)

func _ready() -> void:
	_last_sector = world.patrol_sector(position)
	_facing = Vector2.from_angle(_patrol_rng.randf_range(0,TAU))
	if golden:
		_body.modulate = Color(1.25,1.05,0.38)
		_body.scale = Vector2.ONE * 1.15
	lay_left = 1.0 if golden else world.rng.randf_range(4,8)

func _physics_process(delta: float) -> void:
	# Reuse turning, occluded sight and alarms, with global roaming below.
	if NavigationServer2D.map_get_iteration_id(get_world_2d().navigation_map) == 0: return
	super._physics_process(delta)
	lay_left -= delta
	if lay_left <= 0.0:
		egg_laid.emit(position + Vector2(0,12),golden)
		lay_left = world.rng.randf_range(1.5,2.5) if golden else world.rng.randf_range(6,10)
	queue_redraw()

func _patrol(delta: float) -> void:
	if not roaming_enabled: return
	if _wait_left > 0:
		_wait_left -= delta
		return
	if roam_target == Vector2.INF:
		_choose_roam_target()
		return
	_target_age += delta
	if position.distance_squared_to(roam_target) <= 144 or _stuck_left > 1.8 or _target_age > 22.0:
		roam_target = Vector2.INF
		_wait_left = _patrol_rng.randf_range(0.15,0.5)
		return
	var offset := CoopNavigation.next_offset(self,roam_target,true)
	if offset == Vector2.INF:
		roam_target = Vector2.INF
		return
	var previous := position
	_move_toward_feed_point(offset,patrol_speed*(1.0+_segment_speed_offset*speed_variation),delta)
	_stuck_left = _stuck_left+delta if position.distance_squared_to(previous) < 0.01 else 0.0

func _choose_roam_target() -> void:
	# A shuffled tour visits every quadrant, then reshuffles for fresh global routes.
	if _sectors.is_empty():
		_sectors.assign([0,1,2,3])
		for i in range(3,0,-1):
			var other := _patrol_rng.randi_range(0,i)
			var value := _sectors[i]
			_sectors[i] = _sectors[other]
			_sectors[other] = value
		if _sectors.back() == _last_sector:
			var other := _patrol_rng.randi_range(0,2)
			_sectors[3] = _sectors[other]
			_sectors[other] = _last_sector
	var sector: int = _sectors.pop_back()
	for attempt in range(20):
		var point := world.patrol_point(sector)
		if point != Vector2.INF and CoopNavigation.next_offset(self,point,true) != Vector2.INF:
			roam_target = point
			_last_sector = sector
			_stuck_left = 0.0
			_target_age = 0.0
			_segment_speed_offset = _patrol_rng.randf_range(-1,1)
			return

func _draw() -> void:
	if golden:
		draw_arc(Vector2(0,-15),24,0,TAU,24,Color(1,0.8,0.2,0.45),2)
		draw_rect(Rect2(-4,-53,8,4),Color("ffe28a"))
