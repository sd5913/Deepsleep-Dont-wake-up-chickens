class_name ArcadeProfile
extends RefCounted

const COSTS := [20, 40, 70, 110, 160]
var coins := 0
var unlocked := 1
var best := [0, 0, 0, 0]
var upgrades := [0, 0, 0]
var save_path := "user://coop-rush-v1.json"
var browser_key := "coop-rush-v1"
var saved := true

func load_progress() -> void:
	var raw := ""
	if OS.has_feature("web"):
		var result = JavaScriptBridge.eval("(()=>{try{return localStorage.getItem(" + JSON.stringify(browser_key) + ")||''}catch(e){return ''}})()")
		if result is String: raw = result
	elif FileAccess.file_exists(save_path):
		raw = FileAccess.get_file_as_string(save_path)
	if raw.is_empty(): return
	var parser := JSON.new()
	if parser.parse(raw) != OK: return
	var data = parser.data
	if not data is Dictionary or data.get("version") != 1: return
	coins = _safe_int(data.get("coins"), 0, 100000000)
	unlocked = _safe_int(data.get("unlocked"), 1, 4)
	for pair in [["best", best, 10000000], ["upgrades", upgrades, 5]]:
		var values = data.get(pair[0])
		if values is Array:
			for i in range(mini(values.size(), pair[1].size())):
				pair[1][i] = _safe_int(values[i], 0, pair[2])

func _safe_int(value: Variant, minimum: int, maximum: int) -> int:
	if not (value is int or value is float): return minimum
	if value is float and not is_finite(value): return minimum
	return clampi(int(value), minimum, maximum)

func save_progress() -> bool:
	var raw := JSON.stringify({"version": 1, "coins": coins, "unlocked": unlocked, "best": best, "upgrades": upgrades})
	if OS.has_feature("web"):
		saved = JavaScriptBridge.eval("(()=>{try{localStorage.setItem(" + JSON.stringify(browser_key) + "," + JSON.stringify(raw) + ");return true}catch(e){return false}})()") == true
		return saved
	var file := FileAccess.open(save_path + ".tmp", FileAccess.WRITE)
	if file == null:
		saved = false
		return false
	file.store_string(raw)
	file.close()
	saved = DirAccess.rename_absolute(save_path + ".tmp", save_path) == OK
	return saved

func cost(index: int) -> int:
	return COSTS[upgrades[index]] if index >= 0 and index < 3 and upgrades[index] < 5 else -1

func buy(index: int) -> bool:
	var price := cost(index)
	if price < 0 or coins < price: return false
	coins -= price
	upgrades[index] += 1
	save_progress()
	return true

func settle(level: int, score: int, unlock_next := true) -> Dictionary:
	var reward := maxi(0, score) / 5
	var record: bool = score > best[level - 1]
	best[level - 1] = maxi(best[level - 1], score)
	coins += reward
	if unlock_next: unlocked = maxi(unlocked, mini(4, level + 1))
	save_progress()
	return {"level": level, "score": score, "reward": reward, "record": record}
