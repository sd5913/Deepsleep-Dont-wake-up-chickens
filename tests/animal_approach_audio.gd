extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func expect(ok: bool, label: String) -> void:
 if not ok:
  failures += 1
  push_error(label)
func run() -> void:
 expect(is_equal_approx(AnimalApproachAudio.sector_gap(Vector2(120,0),Vector2.RIGHT,100,PI/4),20.0),"Radial margin")
 expect(AnimalApproachAudio.sector_gap(Vector2(50,0),Vector2.RIGHT,100,PI/4)==0.0,"Inside cone belongs to detection")
 expect(AnimalApproachAudio.sector_gap(Vector2(-80,0),Vector2.RIGHT,100,PI/4)>42.0,"Behind animal is not a threat")
 expect(AnimalApproachAudio.sector_gap(Vector2(60,75),Vector2.RIGHT,100,PI/4)>0.0,"Side edge margin")
 var game = load("res://scenes/arcade/game.tscn").instantiate()
 game.profile = ArcadeProfile.new()
 game.profile.save_path = "user://animal-audio-test.json"
 game.profile.powerup_tutorials = [true,true,true]
 root.add_child(game)
 await physics_frame
 game.begin_round(1,1)
 game.set_process(false)
 game.world.process_mode = Node.PROCESS_MODE_DISABLED
 var hen = game.hens[0]
 game.player.invulnerable = false
 game.player.concealed = false
 hen.sees_player = false
 hen._eat_left = 0.0
 hen._facing = Vector2.RIGHT
 hen.vision_distance = 55.0
 game.hens.clear()
 game.hens.append(hen)
 # Find a clear horizontal corridor and keep both endpoints on the floor.
 var origin := Vector2.INF
 for y in range(90,int(game.world.bounds.end.y)-60,25):
  for x in range(60,int(game.world.bounds.end.x)-200,25):
   var a := Vector2(x,y)
   var b := a+Vector2(150,0)
   var ray := PhysicsRayQueryParameters2D.create(a,b,2)
   if game.world.is_free(a,15) and game.world.is_free(b,15) and game.get_world_2d().direct_space_state.intersect_ray(ray).is_empty():
    origin = a
    break
  if origin != Vector2.INF: break
 expect(origin != Vector2.INF,"Clear test corridor")
 hen.global_position = origin
 game.player.global_position = origin+Vector2(135,0)
 game.approach_audio.advance(game,.1)
 game.player.global_position = origin+Vector2(75,0)
 game.approach_audio.advance(game,.1)
 expect(game.audio.cooldowns.has("44_hen_near"),"Chicken warns before actual sight")
 expect(not hen.sees_player,"Proximity cue does not set detection")
 var first: float = game.approach_audio.next_call
 game.player.global_position -= Vector2(5,0)
 game.approach_audio.advance(game,.1)
 expect(game.approach_audio.next_call == first,"Global and per-animal rate limiting")
 game.approach_audio.reset()
 game.player.concealed = true
 game.approach_audio.advance(game,.1)
 expect(game.approach_audio.history.is_empty(),"No warnings while concealed")
 game.player.concealed = false
 game.player.invulnerable = true
 game.approach_audio.advance(game,.1)
 expect(game.approach_audio.history.is_empty(),"No warnings during protection")
 game.player.invulnerable = false
 var wall := StaticBody2D.new()
 wall.collision_layer = 2
 wall.process_mode = Node.PROCESS_MODE_ALWAYS
 var shape := CollisionShape2D.new()
 var rect := RectangleShape2D.new()
 rect.size = Vector2(6,70)
 shape.shape = rect
 wall.add_child(shape)
 game.world.add_child(wall)
 wall.global_position = origin+Vector2(40,0)
 await physics_frame
 await physics_frame
 game.player.global_position = origin+Vector2(135,0)
 game.approach_audio.advance(game,.1)
 game.player.global_position = origin+Vector2(75,0)
 game.approach_audio.advance(game,.1)
 expect(game.approach_audio.next_call == 0.0,"Cover blocks approach call")
 expect(AnimalApproachAudio.CUES.size()==4,"Each map has its own call")
 game.queue_free()
 await process_frame
 if failures == 0: print("PASS: cone edge geometry, early approach, cooldown, stealth/protection, cover and four animal cues")
 quit(1 if failures else 0)
