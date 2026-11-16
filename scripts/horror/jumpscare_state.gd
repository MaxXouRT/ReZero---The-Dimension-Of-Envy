extends Node
## JumpscareState (autoload)
##
## Tiny global flag describing the "scare window": the few seconds during and
## right after a jumpscare. The pause menu reads it — if the player panics and
## hits Pause during this window, the pause menu opens... and the Witch tears
## it off the screen (see scripts/ui/pause_menu.gd -> _pause_trap()).

var active := false
var current_id := ""
var trap_count := 0          ## How many times the player fell for it (memory for dialogue).
var _time_left := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


## Opens a scare window for `window` seconds.
func begin(id: String, window: float = 2.5) -> void:
	active = true
	current_id = id
	_time_left = maxf(_time_left, window)
	EventBus.jumpscare_started.emit(id)


func end() -> void:
	if active:
		EventBus.jumpscare_ended.emit(current_id)
	active = false
	current_id = ""
	_time_left = 0.0


func is_active() -> bool:
	return active


func _process(delta: float) -> void:
	if not active:
		return
	_time_left -= delta
	if _time_left <= 0.0:
		end()
