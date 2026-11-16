class_name SatellaAI
extends Node3D
## SATELLA AI SYSTEM — the heart of the game.
##
## Satella is not "an enemy that chases you". She is a presence with intent:
##  * a state machine (DORMANT, OBSERVING, WATCHING, FOLLOWING, MANIFESTING,
##    HUNTING, CHASING, DISAPPEARING, INTERACTING, ENRAGED),
##  * an appearance director that chooses WHERE and WHEN she shows up, based
##    on Envy Awareness, the chapter, deaths (loops), the current zone's rules
##    and a cooldown that shrinks as she awakens (rare at first, then more
##    and more frequent),
##  * perception of the player (is she seen? lit by the flashlight? how long
##    has the player stared?) feeding Envy Awareness,
##  * hooks for scripted events (cutscenes, chases, the meta finale).
##
## Observation spots are registered by zones:
##   satella.register_spot(pos, zone_id, kind, facing_dir)
## kinds: corridor_end, window, behind_glass, balcony, mirror, room, doorway

const STATE_SCRIPTS := {
	"DORMANT": preload("res://scripts/satella/states/state_dormant.gd"),
	"OBSERVING": preload("res://scripts/satella/states/state_observing.gd"),
	"WATCHING": preload("res://scripts/satella/states/state_watching.gd"),
	"FOLLOWING": preload("res://scripts/satella/states/state_following.gd"),
	"MANIFESTING": preload("res://scripts/satella/states/state_manifesting.gd"),
	"HUNTING": preload("res://scripts/satella/states/state_hunting.gd"),
	"CHASING": preload("res://scripts/satella/states/state_chasing.gd"),
	"DISAPPEARING": preload("res://scripts/satella/states/state_disappearing.gd"),
	"INTERACTING": preload("res://scripts/satella/states/state_interacting.gd"),
	"ENRAGED": preload("res://scripts/satella/states/state_enraged.gd"),
}

## Base cooldown (seconds) between autonomous appearances per awareness stage.
const COOLDOWN_BY_STAGE := [150.0, 95.0, 70.0, 50.0, 36.0, 28.0]

var body: SatellaBody
var sm: SatellaStateMachine
var player: PlayerController
var world: Node = null                 ## MansionWorld (zones, rules)
var chase: Node = null                 ## ChaseController
var spots: Array = []                  ## [{pos, zone, kind, facing}]
var autonomous := true                 ## false while scripted sequences run
var cooldown := 60.0
var seen := false
var seen_time := 0.0                   ## continuous seconds currently seen
var unseen_time := 0.0
var lit_time := 0.0
var total_seen := 0.0
var mirror_mode := false
var presence := 0.0
var catch_radius := 1.1
var _last_spot := -1
var _footstep_t := 0.0
var _lines_cooldown := 0.0
var _awake_line_index := 0


func _ready() -> void:
	name = "Satella"
	body = SatellaBody.new()
	body.name = "Body"
	add_child(body)
	sm = SatellaStateMachine.new()
	sm.name = "StateMachine"
	add_child(sm)
	for k in STATE_SCRIPTS.keys():
		var st: SatellaState = STATE_SCRIPTS[k].new(self)
		st.name = k
		sm.add(st)
	EventBus.satella_request.connect(_on_request)
	EventBus.player_spawned.connect(func(p): player = p)
	sm.change("DORMANT", {"cooldown": _initial_cooldown()})


func _initial_cooldown() -> float:
	# After many deaths she appears voluntarily, and soon, at visited places.
	if GameState.deaths() >= 5:
		return randf_range(18.0, 35.0)
	return randf_range(60.0, 110.0)


# ------------------------------------------------------------------ helpers
func is_active() -> bool:
	return visible and body.get_dissolve() < 0.99


func show_body(at: Vector3, face_player := true) -> void:
	global_position = at
	visible = true
	body.set_dissolve(0.0)
	if face_player:
		face_toward(player_pos())


func hide_body() -> void:
	visible = false
	body.set_dissolve(1.0)
	set_mirror_only(false)
	presence = 0.0


func set_mirror_only(on: bool) -> void:
	mirror_mode = on
	body.set_mirror_only(on)


func player_pos() -> Vector3:
	return player.global_position if player else global_position + Vector3.FORWARD


func head_pos() -> Vector3:
	return global_position + Vector3.UP * 1.62


func distance_to_player() -> float:
	return global_position.distance_to(player_pos()) if player else 999.0


func face_toward(p: Vector3) -> void:
	var d := p - global_position
	d.y = 0
	if d.length() > 0.01:
		rotation.y = atan2(d.x, d.z)


## Glides toward a point at `speed`. She ignores collisions (she phases)
## but sticks to the ground under her.
func glide_toward(target: Vector3, speed: float, delta: float) -> float:
	var flat := Vector3(target.x, global_position.y, target.z)
	var d := flat - global_position
	var dist := d.length()
	if dist > 0.01:
		var step := minf(dist, speed * delta)
		global_position += d / dist * step
		face_toward(target)
	# ground snap
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 1.2, global_position + Vector3.DOWN * 3.0, 1)
	var hit := space.intersect_ray(q)
	if not hit.is_empty():
		global_position.y = lerpf(global_position.y, hit["position"].y, clampf(delta * 10.0, 0.0, 1.0))
	else:
		global_position.y = lerpf(global_position.y, target.y, clampf(delta * 4.0, 0.0, 1.0))
	body.speed_hint = speed
	return dist


## Satella's own line of sight to the player.
func sees_player(max_dist := 16.0) -> bool:
	if player == null:
		return false
	if distance_to_player() > max_dist:
		return false
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(head_pos(), player.eye_position(), 1)
	return space.intersect_ray(q).is_empty()


func zone_rules() -> Dictionary:
	if world and world.has_method("rules_for") and player:
		return world.rules_for(player.current_zone)
	return {}


## Picks an observation spot that is NOT currently visible, at a sensible
## distance, preferably in the player's zone (or visited zones after 5 deaths).
func pick_spot(kinds: Array = [], min_d := 7.0, max_d := 30.0) -> int:
	if player == null:
		return -1
	var best := -1
	var best_score := -INF
	var prefer_visited := GameState.deaths() >= 5
	for i in spots.size():
		var s: Dictionary = spots[i]
		if not kinds.is_empty() and not kinds.has(s["kind"]):
			continue
		var d: float = s["pos"].distance_to(player.global_position)
		if d < min_d or d > max_d:
			continue
		var same_zone: bool = s["zone"] == player.current_zone
		if not same_zone and not (prefer_visited and GameState.run["visited_zones"].has(s["zone"])):
			continue
		var head: Vector3 = s["pos"] + Vector3.UP * 1.6
		if s["kind"] != "mirror" and player.is_in_frustum(head) and player.can_see_point(head, 0.3):
			continue
		var score := randf() * 4.0 + (3.0 if same_zone else 0.0) - absf(d - 14.0) * 0.15
		if i == _last_spot:
			score -= 5.0
		# spots the player will probably turn toward (behind-ish) are scarier
		score += (1.0 - absf(player.look_dot(head))) * 1.5
		if score > best_score:
			best_score = score
			best = i
	if best >= 0:
		_last_spot = best
	return best


func register_spot(pos: Vector3, zone: String, kind := "room", facing := Vector3.ZERO) -> void:
	spots.append({"pos": pos, "zone": zone, "kind": kind, "facing": facing})


func say_random(prefix: String, count: int, opts := {}) -> void:
	if _lines_cooldown > 0.0 or DialogueManager.is_busy():
		return
	_lines_cooldown = 12.0
	DialogueManager.say("%s_%d" % [prefix, randi_range(1, count)], opts)


func say_awakened_line() -> void:
	if EnvyAwareness.stage() < EnvyAwareness.Stage.AWAKENED or DialogueManager.is_busy():
		return
	_awake_line_index = (_awake_line_index % 5) + 1
	DialogueManager.say("awake_%d" % _awake_line_index, {"position": head_pos()})


## Catch sequence: she grabs Subaru. Cinematic, not gory.
func catch_player(cause := "satella") -> void:
	if player == null or player.dead:
		return
	autonomous = false
	sm.change("INTERACTING", {"hold": true})
	player.lock("caught")
	var front := player.global_position + player.forward() * 0.75
	front.y = player.global_position.y
	show_body(front)
	face_toward(player.global_position)
	body.set_pose(SatellaBody.Pose.REACH)
	body.look_target = player.eye_position()
	body.set_face_lit(1.2)
	body.tendril_amount = 1.0
	player.look_at_point(head_pos(), 0.12)
	AudioManager.play_jumpscare("stinger_1", -2.0)
	AudioManager.play_attached("grab", self, 2.0)
	EventBus.camera_shake.emit(0.8, 0.6)
	EventBus.screen_glitch.emit(0.6, 0.6)
	DialogueManager.clear()
	DialogueManager.say("witch_caught", {"position": head_pos()})
	await get_tree().create_timer(0.9).timeout
	player.unlock("caught")
	player.die(cause)


# ------------------------------------------------------------------ main loop
func _process(delta: float) -> void:
	if player == null:
		return
	_lines_cooldown = maxf(0.0, _lines_cooldown - delta)
	_update_perception(delta)
	sm.update(delta)
	_update_presence(delta)


func _update_perception(delta: float) -> void:
	seen = false
	if is_active() and not mirror_mode:
		var torso := global_position + Vector3.UP * 1.25
		seen = player.is_in_frustum(torso) and (player.can_see_point(head_pos(), 0.0) or player.can_see_point(torso, 0.0))
	if seen:
		seen_time += delta
		unseen_time = 0.0
		total_seen += delta
		if player.look_dot(head_pos()) > 0.92:
			EventBus.satella_seen.emit(delta)
		if player.flashlight.illuminates(head_pos()):
			lit_time += delta
			if lit_time > 1.0:
				lit_time = 0.0
				EnvyAwareness.gain("flashlight_on_her")
	else:
		seen_time = 0.0
		unseen_time += delta
	# body looks at Subaru while visible
	if is_active():
		body.look_target = player.eye_position()


func _update_presence(delta: float) -> void:
	var target := 0.0
	if is_active():
		var d := distance_to_player()
		target = clampf(1.0 - d / 25.0, 0.0, 1.0)
		if seen:
			target = clampf(target + 0.35, 0.0, 1.0)
		if sm.current_name in ["CHASING", "ENRAGED"]:
			target = 1.0
	presence = lerpf(presence, target, clampf(delta * 2.0, 0.0, 1.0))
	AudioManager.presence = presence
	RenderingServer.global_shader_parameter_set("envy_pulse", presence * (0.6 if EnvyAwareness.stage() >= 2 else 0.25))
	if presence > 0.05:
		player.add_panic(presence * delta * (0.6 if seen else 0.25))


# ------------------------------------------------------------------ autonomous director
## Called by DORMANT when the cooldown elapses: decides what she does next.
func try_spontaneous_appearance() -> bool:
	if not autonomous or player == null or player.dead:
		return false
	var rules := zone_rules()
	if rules.get("no_satella", false):
		return false
	var chapter := GameState.chapter()
	if chapter < 2 and GameState.deaths() < 5:
		return false
	var stage := EnvyAwareness.stage()
	var options := {"observe": 6.0}
	if stage >= 1 and rules.get("follow", true):
		options["follow"] = 2.0 + stage
	if stage >= 2 and rules.get("manifest", true):
		options["manifest"] = 1.5 + stage
	if stage >= 3 and rules.get("hunt", false):
		options["hunt"] = 1.0 + stage * 1.2
	var choice := _weighted(options)
	match choice:
		"observe":
			var kinds: Array = rules.get("spot_kinds", [])
			var idx := pick_spot(kinds)
			if idx < 0:
				return false
			sm.change("OBSERVING", {"spot": idx})
		"follow":
			sm.change("FOLLOWING", {})
		"manifest":
			var idx2 := pick_spot([], 10.0, 22.0)
			if idx2 < 0:
				return false
			sm.change("MANIFESTING", {"spot": idx2})
		"hunt":
			sm.change("HUNTING", {"points": rules.get("hunt_points", [])})
	return true


func next_cooldown() -> float:
	var base: float = COOLDOWN_BY_STAGE[EnvyAwareness.stage()]
	if GameState.deaths() >= 5:
		base *= 0.8
	return base * randf_range(0.8, 1.35)


func _weighted(options: Dictionary) -> String:
	var total := 0.0
	for k in options.keys():
		total += float(options[k])
	var r := randf() * total
	for k in options.keys():
		r -= float(options[k])
		if r <= 0.0:
			return String(k)
	return String(options.keys()[0])


# ------------------------------------------------------------------ external requests
## EventBus.satella_request(command, args) lets any system ask for behaviour
## without holding a reference to the AI.
func _on_request(command: String, a: Dictionary) -> void:
	match command:
		"appear":
			sm.change("WATCHING", {"pos": a.get("pos", global_position), "scripted": true, "duration": a.get("duration", 6.0), "vanish_on_look_away": a.get("vanish_on_look_away", true)})
		"observe_at":
			sm.change("OBSERVING", {"pos": a.get("pos"), "timeout": a.get("timeout", 20.0)})
		"manifest":
			sm.change("MANIFESTING", {"pos": a.get("pos", global_position)})
		"vanish":
			sm.change("DISAPPEARING", {"instant": a.get("instant", false)})
		"chase":
			sm.change("CHASING", a)
		"enrage":
			sm.change("ENRAGED", a)
		"hunt":
			sm.change("HUNTING", a)
		"follow":
			sm.change("FOLLOWING", a)
		"interact":
			sm.change("INTERACTING", a)
		"dormant":
			sm.change("DORMANT", {"cooldown": a.get("cooldown", next_cooldown())})
		"autonomous":
			autonomous = bool(a.get("on", true))
		"persona":
			body.set_persona(String(a.get("persona", "witch")))
