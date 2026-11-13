class_name CoopNest
extends Node2D

enum Status { UNSEARCHED, SEARCHABLE, EMPTY }

const MIN_EGGS := 1
const MAX_EGGS := 4

@export_range(1.0, 200.0, 1.0) var interaction_radius := 44.0

@export var risky := false

var eggs_left := 0
var status := Status.UNSEARCHED

@onready var _straw: Sprite2D = $Straw
@onready var _status_mark: Label = $StatusMark


func _ready() -> void:
	$YieldHint.text = "3-4" if risky else "1-2"
	var badge := StyleBoxFlat.new()
	badge.bg_color = Color("0b1225")
	badge.set_border_width_all(1)
	badge.border_color = Color("ffac73") if risky else Color("a9dfce")
	$YieldHint.add_theme_stylebox_override("normal", badge)
	$YieldHint.add_theme_color_override("font_color", badge.border_color)
	_status_mark.modulate = Color("ffbc81") if risky else Color("d1f3d9")


func minimum_stock() -> int:
	return 3 if risky else 1


func maximum_stock() -> int:
	return 4 if risky else 2


func search_multiplier() -> float:
	return 1.1 if risky else 0.65


func set_initial_stock(stock: int) -> void:
	eggs_left = stock


func take_egg() -> bool:
	if eggs_left <= 0:
		return false
	eggs_left -= 1
	if eggs_left == 0:
		status = Status.EMPTY
		_straw.modulate = Color(0.58, 0.52, 0.45)
		_status_mark.text = "X"
		$YieldHint.hide()
	else:
		status = Status.SEARCHABLE
		_straw.modulate = Color(1.0, 0.9, 0.67)
		_status_mark.text = "+"
	return true


func set_targeted(targeted: bool) -> void:
	$Highlight.visible = targeted
