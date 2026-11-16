class_name ArcadeProfile
extends RefCounted

signal storage_status_changed

const COSTS := [20, 40, 70, 110, 160]
var coins := 0
var active_map := 1
var unlocked_maps := 1
var unlocked := 1
var map_complete := false
var best := [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]
var map_best := [0,0,0,0]
var cleared := [false,false,false,false]
var run_scores := [0,0,0,0]
var upgrades := [0,0,0]
var save_path := "user://coop-rush-v1.json"
var browser_key := "coop-rush-v1"
var saved := true
# Read failures block writes for this session, protecting the original save.
var storage_issue := ""
var _load_blocked := false
# Temporary playtest access; never overwrites earned unlocks in the save.
var free_selection := false

func load_progress() -> void:
	var snapshot := _read_storage()
	if not snapshot.get("readable",false):
		_load_blocked = true
		_set_storage_issue("read")
		return
	_load_blocked = false
	_set_storage_issue("" if snapshot.get("writable",false) else "write")
	if not snapshot.get("exists",false): return
	var parser := JSON.new()
	if parser.parse(snapshot.get("raw","")) != OK or not parser.data is Dictionary:
		_load_blocked = true
		_set_storage_issue("invalid")
		return
	var data: Dictionary = parser.data
	var version := _safe_int(data.get("version"),0,100)
	if version != 1 and version != 2:
		_load_blocked = true
		_set_storage_issue("invalid")
		return
	coins = _safe_int(data.get("coins"),0,100000000)
	unlocked = _safe_int(data.get("unlocked"),1,4)
	_read_array(data,"best",best,10000000)
	_read_array(data,"upgrades",upgrades,5)
	if version == 2:
		unlocked_maps = _safe_int(data.get("unlocked_maps"),1,4)
		active_map = _safe_int(data.get("active_map"),1,4 if free_selection else unlocked_maps)
		map_complete = data.get("map_complete",false) == true
		_read_array(data,"map_best",map_best,40000000)
		_read_array(data,"run_scores",run_scores,10000000)
		var values = data.get("cleared")
		if values is Array:
			for i in range(mini(values.size(),4)): cleared[i] = values[i] == true

func _read_storage() -> Dictionary:
	if OS.has_feature("web"):
		# Probe a unique throwaway key, never the key holding the player's progress.
		var script := """(()=>{
let raw;
try { raw = localStorage.getItem(%s); }
catch(e) { return JSON.stringify({readable:false}); }
let writable = true;
const probe = %s + Date.now() + ':' + Math.random().toString(36).slice(2);
try { localStorage.setItem(probe,'1'); localStorage.removeItem(probe); }
catch(e) { writable = false; try { localStorage.removeItem(probe); } catch(ignore) {} }
return JSON.stringify({readable:true,writable:writable,exists:raw!==null,raw:raw===null?'':raw});
})()""" % [JSON.stringify(browser_key),JSON.stringify(browser_key+":probe:")]
		var answer = JavaScriptBridge.eval(script)
		var result: Variant = JSON.parse_string(answer) if answer is String else null
		return result if result is Dictionary else {"readable":false}
	var exists := FileAccess.file_exists(save_path)
	var raw := ""
	if exists:
		var file := FileAccess.open(save_path,FileAccess.READ)
		if file == null: return {"readable":false}
		raw = file.get_as_text()
		var read_error := file.get_error()
		file.close()
		if read_error != OK and read_error != ERR_FILE_EOF: return {"readable":false}
	var probe := save_path+".probe-"+str(OS.get_process_id())+"-"+str(Time.get_ticks_usec())
	var check := FileAccess.open(probe,FileAccess.WRITE)
	var writable := check != null
	if check != null:
		check.store_string("1")
		check.flush()
		writable = check.get_error() == OK
		check.close()
		if DirAccess.remove_absolute(probe) != OK: writable = false
	return {"readable":true,"writable":writable,"exists":exists,"raw":raw}

func _set_storage_issue(issue: String) -> void:
	storage_issue = issue
	saved = issue.is_empty()
	storage_status_changed.emit()

func _read_array(data: Dictionary, key: String, target: Array, maximum: int) -> void:
	var values = data.get(key)
	if values is Array:
		for i in range(mini(values.size(),target.size())): target[i] = _safe_int(values[i],0,maximum)

func _safe_int(value: Variant, minimum: int, maximum: int) -> int:
	if not (value is int or value is float): return minimum
	if value is float and not is_finite(value): return minimum
	return clampi(int(value),minimum,maximum)

func save_progress() -> bool:
	if _load_blocked:
		# Unknown/unreadable data must not be overwritten by temporary progress.
		saved = false
		storage_status_changed.emit()
		return false
	var raw := JSON.stringify({"version":2,"coins":coins,"active_map":active_map,"unlocked_maps":unlocked_maps,"unlocked":unlocked,"map_complete":map_complete,"best":best,"map_best":map_best,"cleared":cleared,"run_scores":run_scores,"upgrades":upgrades})
	if OS.has_feature("web"):
		var ok: bool = JavaScriptBridge.eval("(()=>{try{localStorage.setItem("+JSON.stringify(browser_key)+","+JSON.stringify(raw)+");return true}catch(e){return false}})()") == true
		_set_storage_issue("" if ok else "write")
		return saved
	var file := FileAccess.open(save_path+".tmp",FileAccess.WRITE)
	if file == null:
		_set_storage_issue("write")
		return false
	file.store_string(raw)
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		_set_storage_issue("write")
		return false
	var ok := DirAccess.rename_absolute(save_path+".tmp",save_path) == OK
	_set_storage_issue("" if ok else "write")
	return saved

func start_map(index: int) -> bool:
	if not can_visit_map(index): return false
	active_map = index
	unlocked = 1
	map_complete = false
	upgrades = [0,0,0]
	run_scores = [0,0,0,0]
	# Coins are a permanent wallet. Only the map's buffs and run progress reset.
	save_progress()
	return true

func can_visit_map(index: int) -> bool:
	return index >= 1 and index <= (4 if free_selection else unlocked_maps)

func prepare_room(level: int) -> bool:
	if level < 1 or level > 4: return false
	if free_selection:
		unlocked = level
		map_complete = false
		return true
	return level == unlocked and not map_complete

func cost(index: int) -> int:
	return COSTS[upgrades[index]] if index >= 0 and index < 3 and upgrades[index] < 5 else -1

func buy(index: int) -> bool:
	var price := cost(index)
	if map_complete or price < 0 or coins < price: return false
	coins -= price
	upgrades[index] += 1
	save_progress()
	return true

func best_for(map_index: int, level: int) -> int:
	return best[(map_index-1)*4+level-1]

func settle(level: int, score: int, unlock_next := true) -> Dictionary:
	if level != unlocked or map_complete: return {}
	var reward := maxi(0,score)/5
	var index := (active_map-1)*4+level-1
	var record: bool = score > best[index]
	best[index] = maxi(best[index],score)
	coins += reward
	if unlock_next:
		run_scores[level-1] = maxi(0,score)
		if level < 4: unlocked = level+1
		else:
			map_complete = true
			cleared[active_map-1] = true
			unlocked_maps = maxi(unlocked_maps,mini(4,active_map+1))
			map_best[active_map-1] = maxi(map_best[active_map-1],int(run_scores.reduce(func(a,b): return a+b,0)))
	save_progress()
	return {"map":active_map,"level":level,"score":score,"reward":reward,"record":record,"map_complete":map_complete,"total":run_scores.reduce(func(a,b): return a+b,0)}
