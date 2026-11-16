extends Node
## GameState (autoload)
##
## Single source of truth for the current run.
##
## The data is split in two families, exactly like Subaru's power:
##  * WORLD state  — rewound by Return by Death (items, opened doors, puzzles
##    solved since the last return point...).
##  * MEMORY state — survives death (number of deaths/loops, Envy Awareness,
##    notes read, knowledge flags prefixed "mem_", unique horror events seen).
##
## A checkpoint ("return point") stores a deep copy of the run. When Subaru
## dies, the snapshot is restored and the MEMORY keys are re-applied on top.

const FRAGMENTS := ["forgotten_bedroom", "library_of_memories", "chapel_of_envy", "endless_hallway", "throne_of_envy"]
const FRAGMENT_NAMES := {
	"forgotten_bedroom": "THE FORGOTTEN BEDROOM",
	"library_of_memories": "THE LIBRARY OF MEMORIES",
	"chapel_of_envy": "THE CHAPEL OF ENVY",
	"endless_hallway": "THE ENDLESS HALLWAY",
	"throne_of_envy": "THE THRONE OF ENVY",
}

## Keys of `run` that are never rewound by death.
const MEMORY_KEYS := ["deaths", "loop", "awareness", "notes_read", "seen_events", "original_messages",
	"witch_messages", "playtime", "awareness_log", "death_causes", "satella_seen_time"]

var run: Dictionary = {}
var checkpoint_snapshot: Dictionary = {}
var meta: Dictionary = {}           ## Cross-playthrough data (lobby, endings) — see SaveManager.
var pending_respawn := false        ## True while the game scene must spawn at the checkpoint.
var debug_mode := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	run = _fresh_run()
	meta = _fresh_meta()


func _process(delta: float) -> void:
	if not get_tree().paused and run.get("in_game", false):
		run["playtime"] = float(run.get("playtime", 0.0)) + delta


func _fresh_run() -> Dictionary:
	return {
		"in_game": false,
		"chapter": 1,
		"fragments_found": [],
		"fragments_inserted": [],
		"flags": {},
		"items": [],
		"notes_read": [],
		"battery": 1.0,
		"spare_batteries": 0,
		"deaths": 0,
		"loop": 0,
		"awareness": 0.0,
		"awareness_log": [],
		"visited_zones": [],
		"checkpoint": {"id": "start", "zone": "bedroom", "pos": [0.0, 0.1, 0.0], "yaw": 0.0},
		"objective": "",
		"original_messages": 0,
		"witch_messages": 0,
		"seen_events": [],
		"death_causes": [],
		"satella_seen_time": 0.0,
		"playtime": 0.0,
	}


func _fresh_meta() -> Dictionary:
	return {
		"lobby_visits": 0,
		"endings": [],
		"true_ending_seen": false,
		"total_deaths": 0,
		"playthroughs": 0,
	}


# ------------------------------------------------------------------ lifecycle
func new_game() -> void:
	run = _fresh_run()
	run["in_game"] = true
	# The Witch remembers previous playthroughs: she is never fully asleep again.
	if meta.get("endings", []).size() > 0:
		run["awareness"] = 15.0 + 5.0 * min(3, meta["endings"].size())
		run["flags"]["mem_ng_plus"] = true
	meta["playthroughs"] = int(meta.get("playthroughs", 0)) + 1
	SaveManager.save_meta()
	checkpoint_snapshot = run.duplicate(true)
	pending_respawn = true


func load_from(data: Dictionary) -> void:
	var fresh := _fresh_run()
	for k in data.keys():
		fresh[k] = data[k]
	run = fresh
	run["in_game"] = true
	checkpoint_snapshot = run.duplicate(true)
	pending_respawn = true


# ------------------------------------------------------------------ flags
func set_flag(flag: String, value: Variant = true) -> void:
	run["flags"][flag] = value
	EventBus.flag_set.emit(flag, value)


func get_flag(flag: String, default: Variant = false) -> Variant:
	return run["flags"].get(flag, default)


func has_flag(flag: String) -> bool:
	return bool(run["flags"].get(flag, false))


# ------------------------------------------------------------------ items
func add_item(item: String) -> void:
	if not has_item(item):
		run["items"].append(item)


func has_item(item: String) -> bool:
	return run["items"].has(item)


func remove_item(item: String) -> void:
	run["items"].erase(item)


# ------------------------------------------------------------------ fragments
func collect_fragment(id: String) -> void:
	if run["fragments_found"].has(id):
		return
	run["fragments_found"].append(id)
	EventBus.fragment_collected.emit(id)


func has_fragment(id: String) -> bool:
	return run["fragments_found"].has(id)


func fragment_count() -> int:
	return run["fragments_found"].size()


func insert_fragment(id: String) -> void:
	if not run["fragments_inserted"].has(id):
		run["fragments_inserted"].append(id)
		EventBus.fragment_inserted.emit(id)


func inserted_count() -> int:
	return run["fragments_inserted"].size()


# ------------------------------------------------------------------ notes / knowledge
func mark_note_read(id: String) -> bool:
	if run["notes_read"].has(id):
		return false
	run["notes_read"].append(id)
	return true


func mark_event_seen(id: String) -> void:
	if not run["seen_events"].has(id):
		run["seen_events"].append(id)


func event_seen(id: String) -> bool:
	return run["seen_events"].has(id)


func mark_zone_visited(zone: String) -> bool:
	if run["visited_zones"].has(zone):
		return false
	run["visited_zones"].append(zone)
	return true


# ------------------------------------------------------------------ checkpoints
## Registers a Return-by-Death point and autosaves to disk.
func set_checkpoint(id: String, zone: String, pos: Vector3, yaw: float) -> void:
	run["checkpoint"] = {"id": id, "zone": zone, "pos": [pos.x, pos.y, pos.z], "yaw": yaw}
	checkpoint_snapshot = run.duplicate(true)
	SaveManager.save_game()
	EventBus.checkpoint_reached.emit(id)


func get_checkpoint_position() -> Vector3:
	var p: Array = run["checkpoint"]["pos"]
	return Vector3(p[0], p[1], p[2])


## Called by ReturnByDeath: rewinds the world but keeps the memories.
func rewind_to_checkpoint() -> void:
	var memory := {}
	for k in MEMORY_KEYS:
		memory[k] = run.get(k)
	var mem_flags := {}
	for f in run["flags"].keys():
		if String(f).begins_with("mem_"):
			mem_flags[f] = run["flags"][f]
	run = checkpoint_snapshot.duplicate(true)
	for k in memory.keys():
		run[k] = memory[k]
	for f in mem_flags.keys():
		run["flags"][f] = mem_flags[f]
	run["in_game"] = true
	pending_respawn = true


func register_death(cause: String) -> void:
	run["deaths"] = int(run["deaths"]) + 1
	run["loop"] = int(run["loop"]) + 1
	run["death_causes"].append(cause)
	meta["total_deaths"] = int(meta.get("total_deaths", 0)) + 1


func chapter() -> int:
	return int(run.get("chapter", 1))


func deaths() -> int:
	return int(run.get("deaths", 0))


func awareness() -> float:
	return float(run.get("awareness", 0.0))
