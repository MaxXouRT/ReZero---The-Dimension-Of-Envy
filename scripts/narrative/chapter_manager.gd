extends Node
## ChapterManager (autoload)
##
## Owns the five-chapter structure and the current objective. Chapter content
## (titles, objective strings) lives in res://resources/chapters/chapters.json
## so writers can edit it without touching code. Gameplay scripts call:
##   ChapterManager.start_chapter(3)
##   ChapterManager.set_objective("obj_candles")

const DATA_PATH := "res://resources/chapters/chapters.json"

var chapters: Array = []
var objectives: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	if typeof(data) == TYPE_DICTIONARY:
		chapters = data.get("chapters", [])
		objectives = data.get("objectives", {})
	else:
		push_error("ChapterManager: invalid chapters.json")


func get_chapter(index: int) -> Dictionary:
	for c in chapters:
		if int(c["index"]) == index:
			return c
	return {}


func current() -> int:
	return GameState.chapter()


## Moves the story forward. Never goes backwards (Return by Death restores
## the chapter through GameState, not through this call).
func start_chapter(index: int, show_title := true) -> void:
	var c := get_chapter(index)
	if c.is_empty():
		return
	var previous := GameState.chapter()
	GameState.run["chapter"] = index
	if index > previous:
		EnvyAwareness.gain("chapter")
	set_objective(String(c.get("objective", "")))
	EventBus.chapter_started.emit(index)
	if show_title:
		EventBus.chapter_title.emit(index, String(c["title"]), String(c["subtitle"]))


func objective_text(key: String) -> String:
	return String(objectives.get(key, key))


func set_objective(key: String) -> void:
	GameState.run["objective"] = key
	EventBus.objective_changed.emit(objective_text(key))


func current_objective_text() -> String:
	return objective_text(String(GameState.run.get("objective", "")))
