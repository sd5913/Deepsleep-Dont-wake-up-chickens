class_name ArcadePowerups
extends RefCounted

signal picked_up(kind: int)

const CONTACT_RADIUS := 24.0
const MIN_SPACING := 160.0

var drops: Array[ArcadePowerup] = []
var active: Array[float] = [0.0,0.0,0.0]
var available: Array[int] = []
var spawn_left := 0.0
var spawned := 0
var spawn_limit := 0
var world: ArcadeWorld
var player: CoopPlayer
var profile: ArcadeProfile
var zoom := 1.0
var _bag: Array[int] = []
var _sectors: Array[int] = [0,1,2,3]
var _aura: Node2D

func setup(arena: ArcadeWorld, actor: CoopPlayer, progress: ArcadeProfile, map_index: int, room: int, camera_zoom: float) -> void:
	world = arena
	player = actor
	profile = progress
	zoom = camera_zoom
	available = ArcadePowerup.available_for(map_index,room)
	spawn_limit = 0 if available.is_empty() else (4 if map_index == 4 or room >= 3 else 3)
	spawn_left = 1.0
	_aura = Node2D.new()
	_aura.z_index = 4
	player.add_child(_aura)
	_aura.draw.connect(_draw_aura)
	_refill_bag()
	for i in range(3,0,-1):
		var j := world.rng.randi_range(0,i)
		var value := _sectors[i]
		_sectors[i] = _sectors[j]
		_sectors[j] = value
	var actor_sector := world.patrol_sector(player.position)
	_sectors.erase(actor_sector)
	_sectors.push_front(actor_sector)
	# Teach the newest unseen type first, including direct playtest stage selection.
	for i in range(available.size()-1,-1,-1):
		if not profile.powerup_tutorials[available[i]]:
			_bag.erase(available[i])
			_bag.push_front(available[i])
			break

func seed_initial() -> void:
	# Lay out the whole room's supply immediately, one preferred sector at a time.
	while spawned < spawn_limit:
		if not _spawn_next(): break

func _spawn_next() -> bool:
	if _bag.is_empty(): _refill_bag()
	var point := _find_spawn_point(_sectors[spawned%4])
	if point == Vector2.INF: return false
	spawn_at(_bag.pop_front(),point)
	spawned += 1
	return true

func advance(delta: float) -> void:
	for i in range(active.size()): active[i] = maxf(0.0,active[i]-delta)
	player.concealed = active[ArcadePowerup.Kind.STEALTH] > 0.0
	_aura.queue_redraw()
	if spawned >= spawn_limit: return
	spawn_left -= delta
	if spawn_left > 0.0: return
	# Only retry failed initial placements; there is no delayed normal spawn wave.
	seed_initial()
	spawn_left = 1.0

func _refill_bag() -> void:
	_bag.assign(available)
	for i in range(_bag.size()-1,0,-1):
		var j := world.rng.randi_range(0,i)
		var value := _bag[i]
		_bag[i] = _bag[j]
		_bag[j] = value

func _find_spawn_point(sector: int) -> Vector2:
	var half := world.bounds.size*0.5
	var preferred := Rect2(world.bounds.position+Vector2(sector%2,sector/2)*half,half).grow(-24.0/zoom)
	var whole := world.bounds.grow(-24.0/zoom)
	for attempt in range(500):
		var area := preferred if attempt < 160 else whole
		var point := Vector2(world.rng.randf_range(area.position.x,area.end.x),world.rng.randf_range(area.position.y,area.end.y))
		if not world.is_free(point,18.0/zoom,true): continue
		if point.distance_to(player.position) < 64.0/zoom: continue
		var clear := true
		for drop in drops:
			if drop.position.distance_to(point) < MIN_SPACING/zoom:
				clear = false
				break
		if clear: return point
	return Vector2.INF

func touching(drop: ArcadePowerup) -> bool:
	if drop.claimed or player.position.distance_squared_to(drop.position) > pow(CONTACT_RADIUS/zoom,2): return false
	var ray := PhysicsRayQueryParameters2D.create(player.global_position,drop.global_position,2)
	return player.get_world_2d().direct_space_state.intersect_ray(ray).is_empty()

func collect_touching() -> void:
	for drop: ArcadePowerup in drops.duplicate():
		# First contact is explained before the item's short duration begins.
		if profile.powerup_tutorials[drop.kind] and touching(drop): take(drop)

func spawn_at(kind: int, point: Vector2) -> ArcadePowerup:
	var drop := ArcadePowerup.new()
	drop.kind = kind
	drop.position = point
	drop.scale = Vector2.ONE/zoom
	drop.z_index = 2
	world.add_child(drop)
	drops.append(drop)
	return drop

func take(drop: ArcadePowerup) -> void:
	if drop.claimed or not drops.has(drop): return
	drop.claimed = true
	drops.erase(drop)
	active[drop.kind] = ArcadePowerup.DURATIONS[drop.kind]
	player.concealed = active[ArcadePowerup.Kind.STEALTH] > 0.0
	picked_up.emit(drop.kind)
	drop.queue_free()
	_aura.queue_redraw()

func clear() -> void:
	for i in range(active.size()): active[i] = 0.0
	player.concealed = false
	_aura.queue_redraw()

func score_factor() -> int:
	return 2 if active[ArcadePowerup.Kind.DOUBLE] > 0.0 else 1

func radius_factor() -> float:
	return 1.35 if active[ArcadePowerup.Kind.BASKET] > 0.0 else 1.0

func _draw_aura() -> void:
	if active[ArcadePowerup.Kind.STEALTH] <= 0.0: return
	var shape := PackedVector2Array([Vector2(-13,-61),Vector2(13,-61),Vector2(25,-49),Vector2(29,-31),Vector2(25,-10),Vector2(13,2),Vector2(-13,2),Vector2(-25,-10),Vector2(-29,-31),Vector2(-25,-49)])
	var alpha := 0.7 if active[2] > 1.0 else 0.35+0.35*sin(active[2]*22.0)
	_aura.draw_colored_polygon(shape,Color(0.35,0.85,0.9,0.12))
	shape.append(shape[0])
	_aura.draw_polyline(shape,Color(0.5,0.95,1.0,alpha),2.0)
