class_name CoopHUD
extends CanvasLayer

signal restart_requested
signal start_requested
signal pause_requested
signal paused_interact_released

enum Failure { TIMEOUT, CAUGHT }

const CLUCK_NOTICE_SECONDS := 1.2
const FEED_NOTICE_SECONDS := 1.5

static var _locale := "zh_CN"

var _cluck_notice_left := 0.0
var _feed_notice_left := 0.0
var _formatted_text: Dictionary[Label, Array] = {}
var _search_key: Label
var _pixel_font := preload("res://assets/fonts/PressStart2P-Regular.ttf")

@onready var _egg_count: Label = %EggCount
@onready var _clock: Label = %Clock
@onready var _alert_value: Label = %AlertValue
@onready var _alert_bar: ProgressBar = %AlertBar
@onready var _sight_notice: Label = %SightNotice
@onready var _cluck_notice: Label = %CluckNotice
@onready var _farmer_notice: Label = %FarmerNotice
@onready var _feed_count: Label = %FeedCount
@onready var _feed_notice: Label = %FeedNotice
@onready var _hint: Label = %InteractionHint
@onready var _progress: ProgressBar = %SearchProgress
@onready var _result: Control = %Result
@onready var _result_title: Label = %ResultTitle
@onready var _result_detail: Label = %ResultDetail
@onready var _result_stats: Label = %ResultStats
@onready var _restart_button: Button = %Restart
@onready var _menu: Control = %Menu
@onready var _menu_title: Label = %MenuTitle
@onready var _menu_primary: Button = %MenuPrimary
@onready var _menu_restart: Button = %MenuRestart
@onready var _pause_button: Button = %PauseButton
@onready var _menu_language: Button = %MenuLanguage
@onready var _result_language: Button = %ResultLanguage


func _ready() -> void:
	_search_key = Label.new()
	_search_key.text = "E"
	_search_key.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_search_key.add_theme_font_override("font", _pixel_font)
	_search_key.add_theme_font_size_override("font_size", 13)
	_search_key.add_theme_color_override("font_color", Color("ffe7a0"))
	_search_key.add_theme_color_override("font_outline_color", Color("0b1225"))
	_search_key.add_theme_constant_override("outline_size", 5)
	_search_key.hide()
	$Screen.add_child(_search_key)
	_apply_language()


func _input(event: InputEvent) -> void:
	if get_tree().paused and event.is_action_released("interact"):
		paused_interact_released.emit()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_round"):
		get_viewport().set_input_as_handled()
		pause_requested.emit()


func show_start(ready_to_start: bool) -> void:
	_menu_title.text = "夜访鸡舍"
	_menu_primary.text = "开始行动" if ready_to_start else "正在准备鸡舍"
	_menu_primary.disabled = not ready_to_start
	_menu_restart.hide()
	_pause_button.hide()
	_menu.show()
	if ready_to_start:
		_menu_primary.grab_focus()


func show_layout_error() -> void:
	_menu_title.text = "地图验证失败"
	_menu_primary.text = "无法开始行动"
	_menu_primary.disabled = true
	_menu_restart.show()
	_pause_button.hide()
	_menu.show()
	_menu_restart.grab_focus()


func show_pause() -> void:
	_menu_title.text = "行动暂停"
	_menu_primary.text = "继续行动"
	_menu_primary.disabled = false
	_menu_restart.show()
	_pause_button.hide()
	_menu.show()
	_menu_primary.grab_focus()


func hide_menu() -> void:
	_menu.hide()
	_pause_button.show()


func update_status(eggs: int, goal: int, seconds_left: int) -> void:
	_set_formatted_text(_egg_count, "鸡蛋 %d / %d", [eggs, goal])
	_set_formatted_text(_clock, "%s", [_format_time(seconds_left)])


func update_interaction(hint: String, progress: float, searching: bool, missing_eggs := 0) -> void:
	if missing_eggs > 0:
		_set_formatted_text(_hint, hint, [missing_eggs])
	else:
		_formatted_text.erase(_hint)
		_hint.text = hint
	_progress.value = progress
	_progress.visible = searching
	_search_key.visible = searching
	if searching:
		var player := get_parent().get_node("Player") as Node2D
		_progress.position = (player.global_position + Vector2(-33, -81)).clamp(Vector2(8, 76), Vector2(862, 449))
		_search_key.position = _progress.position + Vector2(74, -4)


func update_alert(level: float, seen: bool, clucked: bool, delta: float) -> void:
	_alert_bar.value = level
	_set_formatted_text(_alert_value, "警戒 %d / 100", [floori(level)])
	_sight_notice.visible = seen
	_cluck_notice_left = CLUCK_NOTICE_SECONDS if clucked else maxf(_cluck_notice_left - delta, 0.0)
	_cluck_notice.visible = _cluck_notice_left > 0.0


func show_farmer_status(status: String) -> void:
	_farmer_notice.text = status
	_farmer_notice.visible = not status.is_empty()


func update_feed(count: int, delta: float) -> void:
	_set_formatted_text(_feed_count, "饲料 %d", [count])
	_feed_notice_left = maxf(_feed_notice_left - delta, 0.0)
	_feed_notice.visible = _feed_notice_left > 0.0


func show_feed_notice(message: String) -> void:
	_feed_notice.text = message
	_feed_notice_left = 0.0 if message.is_empty() else FEED_NOTICE_SECONDS
	_feed_notice.visible = _feed_notice_left > 0.0


func show_result(won: bool, eggs: int, goal: int, elapsed: int, failure: Failure) -> void:
	if won:
		_result_title.text = "撤离成功"
		_result_detail.text = "已安全离开鸡舍。"
	elif failure == Failure.CAUGHT:
		_result_title.text = "被农夫抓住"
		_result_detail.text = "农夫追上了你，未能撤离。"
	else:
		_result_title.text = "时间耗尽"
		_result_detail.text = "倒计时归零，未能及时撤离。"
	_set_formatted_text(_result_stats, "鸡蛋 %d / %d    用时 %s", [eggs, goal, _format_time(elapsed)])
	_pause_button.hide()
	_result.show()
	_restart_button.grab_focus()


func _on_restart_pressed() -> void:
	restart_requested.emit()


func _on_pause_pressed() -> void:
	pause_requested.emit()


func _on_menu_primary_pressed() -> void:
	if get_tree().paused:
		pause_requested.emit()
	else:
		start_requested.emit()


func _on_language_pressed() -> void:
	_locale = "zh_CN" if _locale == "en" else "en"
	_apply_language()


func _apply_language() -> void:
	TranslationServer.set_locale(_locale)
	for node_name in ["Title", "EggCount", "Clock", "FeedCount", "AlertValue", "MovementHint"]:
		var label := $Screen.get_node(node_name) as Label
		if _locale == "en":
			label.add_theme_font_override("font", _pixel_font)
			label.add_theme_font_size_override("font_size", 12 if node_name == "Title" else (9 if node_name == "MovementHint" or node_name == "AlertValue" else 11))
		else:
			label.remove_theme_font_override("font")
			label.add_theme_font_size_override("font_size", 18 if node_name == "Title" else 15)
		label.clip_text = true
	_hint.clip_text = true
	_hint.add_theme_font_size_override("font_size", 13 if _locale == "en" else 15)
	var button_text := "中文" if _locale == "en" else "English"
	_menu_language.text = button_text
	_result_language.text = button_text
	for label: Label in _formatted_text:
		var entry := _formatted_text[label]
		label.text = tr(entry[0]) % entry[1]


func _set_formatted_text(label: Label, message: String, values: Array) -> void:
	# Keep the template and values available while the round is paused or over.
	_formatted_text[label] = [message, values]
	label.text = tr(message) % values


func _format_time(seconds: int) -> String:
	@warning_ignore("integer_division")
	var minutes := seconds / 60
	return "%d:%02d" % [minutes, seconds % 60]
