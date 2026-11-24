extends Node

const CUES := {
	"01_pickup_single": preload("res://assets/audio/gameplay/01_pickup_single.wav"),
	"02_pickup_batch": preload("res://assets/audio/gameplay/02_pickup_batch.wav"),
	"03_pickup_gold": preload("res://assets/audio/gameplay/03_pickup_gold.wav"),
	"04_multiplier_x2": preload("res://assets/audio/gameplay/04_multiplier_x2.wav"),
	"04_multiplier_x3": preload("res://assets/audio/gameplay/04_multiplier_x3.wav"),
	"04_multiplier_x4": preload("res://assets/audio/gameplay/04_multiplier_x4.wav"),
	"05_pickup_invalid": preload("res://assets/audio/gameplay/05_pickup_invalid.wav"),
	"06_spotted": preload("res://assets/audio/gameplay/06_spotted.wav"),
	"07_farmer_warning": preload("res://assets/audio/gameplay/07_farmer_warning.wav"),
	"08_escape_safe": preload("res://assets/audio/gameplay/08_escape_safe.wav"),
	"09_snake_hatch": preload("res://assets/audio/gameplay/09_snake_hatch.wav"),
	"10_snake_dash": preload("res://assets/audio/gameplay/10_snake_dash.wav"),
	"11_snake_hit": preload("res://assets/audio/gameplay/11_snake_hit.wav"),
	"12_ui_confirm": preload("res://assets/audio/gameplay/12_ui_confirm.wav"),
	"13_upgrade_purchase": preload("res://assets/audio/gameplay/13_upgrade_purchase.wav"),
	"14_countdown_tick": preload("res://assets/audio/gameplay/14_countdown_tick.wav"),
	"15_round_complete": preload("res://assets/audio/gameplay/15_round_complete.wav"),
	"16_caught_end": preload("res://assets/audio/gameplay/16_caught_end.wav"),
	"17_badge_activate": preload("res://assets/audio/gameplay/17_badge_activate.wav"),
	"18_basket_activate": preload("res://assets/audio/gameplay/18_basket_activate.wav"),
	"19_cloak_activate": preload("res://assets/audio/gameplay/19_cloak_activate.wav"),
	"20_powerup_refresh": preload("res://assets/audio/gameplay/20_powerup_refresh.wav"),
	"21_badge_end": preload("res://assets/audio/gameplay/21_badge_end.wav"),
	"22_basket_end": preload("res://assets/audio/gameplay/22_basket_end.wav"),
	"23_cloak_expiring": preload("res://assets/audio/gameplay/23_cloak_expiring.wav"),
	"24_cloak_end": preload("res://assets/audio/gameplay/24_cloak_end.wav"),
	"25_guide_open": preload("res://assets/audio/gameplay/25_guide_open.wav"),
	"26_guide_confirm": preload("res://assets/audio/gameplay/26_guide_confirm.wav"),
	"27_protection_end": preload("res://assets/audio/gameplay/27_protection_end.wav"),
	"28_pause": preload("res://assets/audio/gameplay/28_pause.wav"),
	"29_resume": preload("res://assets/audio/gameplay/29_resume.wav"),
	"30_ten_seconds": preload("res://assets/audio/gameplay/30_ten_seconds.wav"),
	"31_golden_arrival": preload("res://assets/audio/gameplay/31_golden_arrival.wav"),
	"32_new_record": preload("res://assets/audio/gameplay/32_new_record.wav"),
	"33_map_complete": preload("res://assets/audio/gameplay/33_map_complete.wav"),
	"34_coin_settlement": preload("res://assets/audio/gameplay/34_coin_settlement.wav"),
	"35_map_select": preload("res://assets/audio/gameplay/35_map_select.wav"),
	"36_start_transition": preload("res://assets/audio/gameplay/36_start_transition.wav"),
	"37_harvest_wool": preload("res://assets/audio/gameplay/37_harvest_wool.wav"),
	"38_harvest_cone": preload("res://assets/audio/gameplay/38_harvest_cone.wav"),
	"39_harvest_cabbage": preload("res://assets/audio/gameplay/39_harvest_cabbage.wav"),
	"40_hen_alarm": preload("res://assets/audio/gameplay/40_hen_alarm.wav"),
	"41_sheep_alarm": preload("res://assets/audio/gameplay/41_sheep_alarm.wav"),
	"42_squirrel_alarm": preload("res://assets/audio/gameplay/42_squirrel_alarm.wav"),
	"43_dog_alarm": preload("res://assets/audio/gameplay/43_dog_alarm.wav"),
}
const TRACKS := [
 preload("res://assets/audio/music/01_Coop_Loop.wav"),
 preload("res://assets/audio/music/02_Sheepfold_Loop.wav"),
 preload("res://assets/audio/music/03_Squirrel_Yard_Loop.wav"),
 preload("res://assets/audio/music/04_Garden_Loop.wav")]
var music: AudioStreamPlayer
var voices: Array[AudioStreamPlayer] = []
var cooldowns := {}
var duck_left := 0.0
var reward_left := 0.0
var music_enabled := true
var effects_enabled := true

func _ready() -> void:
 process_mode = Node.PROCESS_MODE_ALWAYS
 music = AudioStreamPlayer.new()
 add_child(music)
 for i in range(12):
  var voice := AudioStreamPlayer.new()
  voice.process_mode = Node.PROCESS_MODE_PAUSABLE if i < 10 else Node.PROCESS_MODE_ALWAYS
  add_child(voice)
  voices.append(voice)

func play(cue: String, urgent := false, ui := false) -> void:
 if not effects_enabled or not CUES.has(cue): return
 var now := Time.get_ticks_msec()
 if now < int(cooldowns.get(cue,0)): return
 cooldowns[cue] = now + (700 if cue.contains("invalid") else 80)
 var chosen: AudioStreamPlayer
 for i in range(10 if ui else 0,12 if ui else 10):
  if not voices[i].playing:
   chosen = voices[i]
   break
 if chosen == null:
  if not urgent: return
  chosen = voices[0]
 chosen.stream = CUES[cue]
 chosen.volume_db = -2.0
 chosen.play()
 if urgent: duck_left = 0.9

func set_map(index: int) -> void:
 var stream: AudioStreamWAV = TRACKS[clampi(index-1,0,3)]
 if music.stream == stream: return
 stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
 stream.loop_begin = 0
 stream.loop_end = stream.data.size() / (4 if stream.stereo else 2)
 music.stream = stream
 music.volume_db = -8.0
 if music_enabled: music.play()

func _process(delta: float) -> void:
 if reward_left > 0.0:
  reward_left = maxf(0.0,reward_left-delta)
  if reward_left == 0.0: play("34_coin_settlement",false,true)
 if not get_tree().paused: duck_left = maxf(0.0,duck_left-delta)
 var target := -18.0 if get_tree().paused or duck_left > 0 else -8.0
 music.volume_db = move_toward(music.volume_db,target,delta*35)
 music.stream_paused = not music_enabled

func stop_world() -> void:
 reward_left = 0.0
 for i in range(10): voices[i].stop()
