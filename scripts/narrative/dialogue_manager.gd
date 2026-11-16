extends Node
## DialogueManager (autoload)
##
## Loads every line of the game from res://resources/dialogues/dialogues.json
## and plays them as subtitles + a "voice texture" sound (whisper, soft hum,
## low witch voice, scream...). Lines are queued; sequences can be awaited:
##
##     await DialogueManager.play_sequence(["meta_1a", "meta_1b"])
##
## Text tokens:
##   {PLAYER_NAME}  -> the optional name the player typed (Settings)
##   {DEATHS}       -> number of deaths in this run
##
## Speakers: "subaru" (inner voice), "original" (the true Satella), "witch"
## (the Witch of Envy), "system" (fictional in-game interface), "unknown".

signal line_started(id: String)
signal line_finished(id: String)
signal sequence_finished

const DIALOGUE_PATH := "res://resources/dialogues/dialogues.json"
const NOTES_PATH := "res://resources/dialogues/notes.json"

const VOICE_FOR_STYLE := {
	"whisper": "whisper",
	"soft": "satella_soft",
	"witch": "witch_low",
	"scream": "witch_scream",
	"giggle": "witch_giggle",
	"name": "whisper_name",
}

var lines: Dictionary = {}
var notes: Dictionary = {}
var _queue: Array = []
var _busy := false
var _current_id := ""
var _skip_requested := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	lines = _load_json(DIALOGUE_PATH)
	notes = _load_json(NOTES_PATH)


func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("DialogueManager: missing %s" % path)
		return {}
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(data) != TYPE_DICTIONARY:
		push_error("DialogueManager: invalid JSON in %s" % path)
		return {}
	return data


func has_line(id: String) -> bool:
	return lines.has(id)


func format_text(text: String) -> String:
	var t := text.replace("{PLAYER_NAME}", Settings.get_display_name())
	t = t.replace("{DEATHS}", str(GameState.deaths()))
	return t


func get_text(id: String) -> String:
	if not lines.has(id):
		return id
	return format_text(String(lines[id].get("text", "")))


## Display name shown in the subtitle box. The two Satellas are only told
## apart once the player has understood there are two of them.
func speaker_label(speaker: String) -> String:
	var knows := GameState.has_flag("mem_knows_two_satellas")
	match speaker:
		"subaru":
			return "Subaru"
		"original":
			return "Satella" if knows else "???"
		"witch":
			return "La Sorcière de l'Envie" if knows else "???"
		"system":
			return "SYSTEM"
		"player":
			return Settings.get_display_name()
		_:
			return ""


## Queues one line by id. opts: {"direction": Vector3, "position": Vector3, "delay": float}
func say(id: String, opts: Dictionary = {}) -> void:
	if not lines.has(id):
		push_warning("DialogueManager: unknown line '%s'" % id)
		return
	_queue.append({"id": id, "opts": opts})
	if not _busy:
		_run_queue()


## Queues an arbitrary line (used for procedurally chosen lines).
func say_text(speaker: String, text: String, duration := 3.0, style := "normal", opts: Dictionary = {}) -> void:
	var id := "_dyn_%d" % Time.get_ticks_usec()
	lines[id] = {"speaker": speaker, "text": text, "duration": duration, "style": style}
	say(id, opts)


## Plays the given ids in order; await the returned signal to know when done.
func play_sequence(ids: Array, opts: Dictionary = {}) -> void:
	for id in ids:
		say(String(id), opts)
	while _busy:
		await line_finished
	sequence_finished.emit()


func is_busy() -> bool:
	return _busy


func clear() -> void:
	_queue.clear()
	_skip_requested = true
	EventBus.dialogue_cleared.emit()


func _run_queue() -> void:
	_busy = true
	while not _queue.is_empty():
		var item: Dictionary = _queue.pop_front()
		var id: String = item["id"]
		var opts: Dictionary = item["opts"]
		var data: Dictionary = lines[id]
		var delay := float(opts.get("delay", data.get("delay", 0.0)))
		if delay > 0.0:
			await get_tree().create_timer(delay, true).timeout
		_current_id = id
		_skip_requested = false
		var speaker := String(data.get("speaker", "unknown"))
		var style := String(data.get("style", "normal"))
		var text := format_text(String(data.get("text", "")))
		var duration := float(data.get("duration", maxf(2.2, text.length() * 0.065)))
		line_started.emit(id)
		_play_voice(data, style, opts)
		EventBus.dialogue_line.emit(speaker_label(speaker), text, duration, "%s:%s" % [speaker, style])
		var t := 0.0
		while t < duration and not _skip_requested:
			await get_tree().process_frame
			t += get_process_delta_time()
		line_finished.emit(id)
		if _skip_requested:
			break
	_busy = false
	_current_id = ""
	EventBus.dialogue_cleared.emit()
	line_finished.emit("")


func _play_voice(data: Dictionary, style: String, opts: Dictionary) -> void:
	var voice := String(data.get("voice", VOICE_FOR_STYLE.get(style, "")))
	if voice == "" or voice == "none" or not AudioManager.has_sound(voice):
		return
	var vol := float(data.get("volume", -2.0 if style != "scream" else 2.0))
	if opts.has("position"):
		AudioManager.play_3d(voice, opts["position"], vol, 5.0, 1.0, "Voice")
	elif opts.has("direction"):
		AudioManager.play_directional(voice, opts["direction"], 3.0, vol)
	elif style == "scream":
		AudioManager.play_jumpscare(voice, vol)
	else:
		AudioManager.play_2d(voice, vol, 1.0, "Voice")


# ------------------------------------------------------------------ notes
func get_note(id: String) -> Dictionary:
	return notes.get(id, {"title": id, "body": "", "author": ""})


func open_note(id: String) -> void:
	var n := get_note(id)
	var first := GameState.mark_note_read(id)
	if first:
		match String(n.get("author", "")):
			"original":
				GameState.run["original_messages"] = int(GameState.run.get("original_messages", 0)) + 1
				EnvyAwareness.gain("original_message")
			"witch":
				GameState.run["witch_messages"] = int(GameState.run.get("witch_messages", 0)) + 1
				EnvyAwareness.gain("witch_message")
	AudioManager.play_2d("page", -6.0)
	EventBus.note_opened.emit(id, format_text(String(n.get("title", ""))), format_text(String(n.get("body", ""))), String(n.get("author", "")))
