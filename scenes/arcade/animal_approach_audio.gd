class_name AnimalApproachAudio
extends RefCounted

const MARGIN_PIXELS := 42.0
const GLOBAL_INTERVAL := 2.4
const ANIMAL_INTERVAL := 5.0
const CUES := ["44_hen_near","45_sheep_near","46_squirrel_near","47_dog_near"]
var clock := 0.0
var next_call := 0.0
var history := {}
var ready_at := {}

# Euclidean distance to the finite vision sector, in world coordinates.
static func sector_gap(offset: Vector2, facing: Vector2, radius: float, half_angle: float) -> float:
 var distance := offset.length()
 var angle := absf(facing.angle_to(offset))
 if angle <= half_angle: return maxf(0.0,distance-radius)
 var edge := facing.rotated(half_angle if facing.angle_to(offset) >= 0 else -half_angle)
 return offset.distance_to(edge*clampf(offset.dot(edge),0.0,radius))

func reset() -> void:
 clock = 0.0
 next_call = 0.0
 history.clear()
 ready_at.clear()

func advance(game: Node2D, delta: float) -> void:
 clock += delta
 if not game.guards_enabled or game.player.invulnerable or game.player.concealed:
  history.clear()
  return
 var candidate: ArcadeHen
 var best_gap := INF
 var alive := {}
 for hen: ArcadeHen in game.hens:
  var id := hen.get_instance_id()
  alive[id] = true
  var offset: Vector2 = game.player.global_position-hen.global_position
  var gap: float = sector_gap(offset,hen._facing,hen.vision_distance*hen._sense_scale(),deg_to_rad(hen.vision_angle*0.5))*game.camera.zoom.x
  var previous: float = history.get(id,INF)
  history[id] = gap
  # Actual detection owns the louder alarm. Only warn on a closing, visible edge.
  if hen.sees_player or hen._eat_left > 0.0 or gap <= 0.01 or gap > MARGIN_PIXELS: continue
  if not is_finite(previous) or gap >= previous-0.025: continue
  if clock < float(ready_at.get(id,0.0)) or clock < next_call: continue
  var ray := PhysicsRayQueryParameters2D.create(hen.global_position,game.player.global_position,2)
  if not game.get_world_2d().direct_space_state.intersect_ray(ray).is_empty(): continue
  if gap < best_gap:
   candidate = hen
   best_gap = gap
 for id in history.keys():
  if not alive.has(id):
   history.erase(id)
   ready_at.erase(id)
 if candidate == null or game._was_seen or game.audio.duck_left > 0.0: return
 ready_at[candidate.get_instance_id()] = clock+ANIMAL_INTERVAL
 next_call = clock+GLOBAL_INTERVAL
 game.audio.play(CUES[game.current_map-1],false,false,lerpf(-1.0,-6.0,best_gap/MARGIN_PIXELS))
