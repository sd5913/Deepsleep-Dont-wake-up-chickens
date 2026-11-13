class_name CoopAlert
extends Node

@export_range(0.0, 100.0, 0.5) var sight_gain_per_second := 8.0
@export_range(0.0, 100.0, 0.5) var cluck_gain := 14.0
@export_range(0.0, 10.0, 0.1) var calm_delay := 3.0
@export_range(0.0, 100.0, 0.5) var decay_per_second := 10.0

var level := 0.0

var _calm_delay_left := 0.0


func advance(delta: float, seeing_hens: int, clucks: int, farmer_sees_player := false) -> void:
	if seeing_hens > 0 or clucks > 0 or farmer_sees_player:
		_calm_delay_left = calm_delay
		var gain := sight_gain_per_second * seeing_hens * delta + cluck_gain * clucks
		level = minf(level + gain, 100.0)
		return

	var decay_time := maxf(delta - _calm_delay_left, 0.0)
	_calm_delay_left = maxf(_calm_delay_left - delta, 0.0)
	level = maxf(level - decay_per_second * decay_time, 0.0)
