extends Node
## EnvyAwareness (autoload) — "ENVY AWARENESS SYSTEM"
##
## Hidden 0..100 value describing how conscious the Witch of Envy is of what is
## happening — and, ultimately, of the person holding the controls.
## It is NEVER shown in the normal HUD (only in the debug overlay, F3 in debug).
##
##   0-20  DORMANT          she observes from afar
##  20-40  AWARE            she starts to appear
##  40-60  OBSESSED         she modifies the mansion
##  60-80  UNSTABLE         she intervenes in loops, chases
##  80-99  AWAKENED         she understands Subaru does not act normally
##   100   PLAYER_DETECTED  she knows you exist
##
## Everything that changes the value goes through add(amount, reason) so the
## log can explain the narrative state (useful for QA and for the meta ending,
## where the Witch quotes what you did).

enum Stage { DORMANT, AWARE, OBSESSED, UNSTABLE, AWAKENED, PLAYER_DETECTED }

const STAGE_NAMES := ["DORMANT", "AWARE", "OBSESSED", "UNSTABLE", "AWAKENED", "PLAYER DETECTED"]

## Standard amounts used across the game (tuned so a normal playthrough ends
## around 80-100 and a hesitant / curious / dying player reaches 100).
const GAIN := {
	"death": 6.0,
	"satella_stare": 0.6,        ## per second spent looking straight at her
	"zone_first_visit": 0.6,
	"fragment": 5.0,
	"witch_message": 1.5,
	"original_message": 0.5,
	"chase_escape": 4.0,
	"chase_caught": 2.0,
	"door_closed_on_her": 2.5,
	"pause_during_scare": 3.0,   ## she noticed the hand reaching for the menu
	"menu_hover_exit": 0.0,
	"chapter": 4.0,
	"flashlight_on_her": 1.0,    ## per second of light on her face
}

var _last_stage: int = -1
var suspend_stare := false   ## scripted scenes (meta finale) control awareness explicitly
var _stare_accum := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	EventBus.satella_seen.connect(_on_satella_seen)


func value() -> float:
	return GameState.awareness()


func stage() -> int:
	return stage_for(value())


static func stage_for(v: float) -> int:
	if v >= 100.0:
		return Stage.PLAYER_DETECTED
	if v >= 80.0:
		return Stage.AWAKENED
	if v >= 60.0:
		return Stage.UNSTABLE
	if v >= 40.0:
		return Stage.OBSESSED
	if v >= 20.0:
		return Stage.AWARE
	return Stage.DORMANT


func stage_name() -> String:
	return STAGE_NAMES[stage()]


## Main entry point. `cap` lets early chapters limit growth so the true ending
## cannot be triggered before the story has been told.
func add(amount: float, reason: String, cap: float = 100.0) -> void:
	var before := value()
	var limit := maxf(cap, before)
	var after := clampf(before + amount, 0.0, minf(100.0, limit))
	if is_equal_approx(after, before):
		return
	GameState.run["awareness"] = after
	if absf(amount) >= 1.0:
		var entries: Array = GameState.run["awareness_log"]
		entries.append({"reason": reason, "amount": snappedf(amount, 0.1), "value": snappedf(after, 0.1)})
		if entries.size() > 64:
			entries.pop_front()
	_emit()


## Uses a preset amount from GAIN.
func gain(reason: String, multiplier: float = 1.0) -> void:
	add(GAIN.get(reason, 1.0) * multiplier, reason, chapter_cap())


func set_value(v: float, reason: String = "script") -> void:
	GameState.run["awareness"] = clampf(v, 0.0, 100.0)
	GameState.run["awareness_log"].append({"reason": reason, "amount": 0, "value": v})
	_emit()


## Maximum awareness reachable during a chapter. Only the final chapter can
## reach 100 (PLAYER DETECTED).
func chapter_cap() -> float:
	match GameState.chapter():
		1:
			return 30.0
		2:
			return 52.0
		3:
			return 72.0
		4:
			return 92.0
		_:
			return 100.0


func _emit() -> void:
	var s := stage()
	EventBus.awareness_changed.emit(value(), s)
	if s != _last_stage:
		if _last_stage != -1:
			EventBus.awareness_stage_changed.emit(s, STAGE_NAMES[s])
		_last_stage = s


func reset_stage_tracking() -> void:
	_last_stage = stage()


func _on_satella_seen(seconds: float) -> void:
	if suspend_stare:
		return
	_stare_accum += seconds
	GameState.run["satella_seen_time"] = float(GameState.run.get("satella_seen_time", 0.0)) + seconds
	if _stare_accum >= 1.0:
		gain("satella_stare", _stare_accum)
		_stare_accum = 0.0


## Probability multiplier used by the Satella AI and the Horror Director:
## appearances are rare at first and progressively more frequent.
func presence_factor() -> float:
	match stage():
		Stage.DORMANT:
			return 0.25
		Stage.AWARE:
			return 0.5
		Stage.OBSESSED:
			return 0.75
		Stage.UNSTABLE:
			return 1.0
		Stage.AWAKENED:
			return 1.3
		_:
			return 1.6
