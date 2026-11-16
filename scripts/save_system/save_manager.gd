extends Node
## SaveManager (autoload)
##
## * user://savegame.json : the current run (written at every return point /
##   manual save). Version-tagged so future builds can migrate it.
## * user://meta.json     : cross-playthrough memory (lobby visits, endings
##   unlocked, total deaths). This is what lets the lobby and the Witch
##   "remember" the player between sessions.
##
## Only these two files are ever written or read. The game never inspects
## anything else on the player's machine.

var SAVE_PATH := "user://savegame.json"
var META_PATH := "user://meta.json"
const SAVE_VERSION := 1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_meta()


## QA: redirects every file to user://qa_* so automated tests never touch
## the player's real save, endings or lobby history.
func use_sandbox() -> void:
	SAVE_PATH = "user://qa_savegame.json"
	META_PATH = "user://qa_meta.json"
	if FileAccess.file_exists(META_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(META_PATH))
	GameState.meta = GameState._fresh_meta()


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save_game() -> bool:
	if not GameState.run.get("in_game", false):
		return false
	var payload := {
		"version": SAVE_VERSION,
		"timestamp": Time.get_datetime_string_from_system(),
		"run": GameState.checkpoint_snapshot if not GameState.checkpoint_snapshot.is_empty() else GameState.run,
		"memory": _memory_of(GameState.run),
	}
	var ok := _write_json(SAVE_PATH, payload)
	if ok:
		EventBus.game_saved.emit()
	return ok


## The snapshot holds the world at the return point, but deaths / awareness
## that happened afterwards must not be lost on reload.
func _memory_of(r: Dictionary) -> Dictionary:
	var m := {}
	for k in GameState.MEMORY_KEYS:
		m[k] = r.get(k)
	var mf := {}
	for f in r.get("flags", {}).keys():
		if String(f).begins_with("mem_"):
			mf[f] = r["flags"][f]
	m["mem_flags"] = mf
	return m


func load_game() -> bool:
	var data: Variant = _read_json(SAVE_PATH)
	if typeof(data) != TYPE_DICTIONARY or not data.has("run"):
		return false
	var r: Dictionary = data["run"]
	var mem: Dictionary = data.get("memory", {})
	for k in mem.keys():
		if k == "mem_flags":
			continue
		if mem[k] != null:
			r[k] = mem[k]
	if not r.has("flags"):
		r["flags"] = {}
	for f in mem.get("mem_flags", {}).keys():
		r["flags"][f] = mem["mem_flags"][f]
	GameState.load_from(r)
	EventBus.game_loaded.emit()
	return true


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


func save_info() -> Dictionary:
	var data: Variant = _read_json(SAVE_PATH)
	if typeof(data) != TYPE_DICTIONARY:
		return {}
	var r: Dictionary = data.get("run", {})
	var mem: Dictionary = data.get("memory", {})
	return {
		"timestamp": data.get("timestamp", ""),
		"chapter": int(r.get("chapter", 1)),
		"fragments": r.get("fragments_found", []).size(),
		"deaths": int(mem.get("deaths", r.get("deaths", 0))),
	}


# ------------------------------------------------------------------ meta
func load_meta() -> void:
	var data: Variant = _read_json(META_PATH)
	if typeof(data) == TYPE_DICTIONARY:
		for k in data.keys():
			GameState.meta[k] = data[k]


func save_meta() -> void:
	_write_json(META_PATH, GameState.meta)


func unlock_ending(id: String) -> void:
	if not GameState.meta["endings"].has(id):
		GameState.meta["endings"].append(id)
	if id == "true":
		GameState.meta["true_ending_seen"] = true
	save_meta()


# ------------------------------------------------------------------ io
func _write_json(path: String, data: Variant) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_warning("SaveManager: cannot write %s" % path)
		return false
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	return true


func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var txt := f.get_as_text()
	f.close()
	return JSON.parse_string(txt)
