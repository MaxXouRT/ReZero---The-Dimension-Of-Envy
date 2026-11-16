class_name ChaseController
extends Node
## ChaseController — dedicated pursuit AI for Satella.
##
## Path following: the player leaves "breadcrumbs" (positions every 0.5 m).
## Satella follows the trail exactly, so she never gets stuck in the
## procedural geometry and always comes through the same doors as Subaru.
## When she has a clear line of sight and is close, she cuts straight at him.
##
## Pressure tools (all readable and fair):
##  * speed slightly under Subaru's sprint: stamina management matters;
##  * doors: a closed door stops her for `door_delay` seconds, then she
##    smashes it open (a door slammed in her face may ENRAGE her);
##  * blinks: if she falls too far behind while unseen she "skips" closer;
##  * impossible doors: she follows you through them after a beat.
##
## Configs (Dictionary): id, speed, catch_radius, door_delay, blink_distance,
## max_time (0 = scripted, no timeout), escape_distance (0 = only exits),
## exit_check (Callable() -> bool), enraged, start_pos.

signal chase_finished(chase_id: String, escaped: bool)

var ai: SatellaAI
var player: PlayerController
var config := {}
var active := false
var chase_id := ""
var crumbs: Array[Vector3] = []
var _time := 0.0
var _far_time := 0.0
var _door_wait := 0.0
var _waiting_door: Door = null
var _doors_bashed := {}
var _portal_follow := -1.0
var _portal_target := Vector3.ZERO
var _stun := 0.0


func setup(satella: SatellaAI, p: PlayerController) -> void:
	ai = satella
	player = p
	player.teleported.connect(_on_player_teleported)


func is_active() -> bool:
	return active


func start(cfg: Dictionary) -> void:
	config = cfg.duplicate()
	chase_id = String(config.get("id", "chase"))
	active = true
	_time = 0.0
	_far_time = 0.0
	_doors_bashed.clear()
	_waiting_door = null
	_portal_follow = -1.0
	crumbs.clear()
	crumbs.append(player.global_position)
	if config.has("start_pos"):
		ai.show_body(config["start_pos"])
	player.panic_floor = 0.45
	player.stamina = maxf(player.stamina, 0.6)
	AudioManager.chase_active = true
	EventBus.chase_started.emit(chase_id)
	if not ai.sm.current_name in ["CHASING", "ENRAGED"]:
		ai.sm.change("ENRAGED" if config.get("enraged", false) else "CHASING", config)


## Freezes her for `seconds` (the true Satella holding her back).
func stun(seconds: float) -> void:
	_stun = maxf(_stun, seconds)


func set_enraged(on: bool) -> void:
	config["enraged"] = on
	config["speed"] = maxf(float(config.get("speed", 5.0)), 5.6) if on else float(config.get("speed", 5.0))


## Ends the chase. escaped = true when the player won.
func stop(escaped: bool) -> void:
	if not active:
		return
	active = false
	player.panic_floor = 0.0
	AudioManager.chase_active = false
	EventBus.chase_ended.emit(chase_id, escaped)
	chase_finished.emit(chase_id, escaped)
	if escaped:
		EnvyAwareness.gain("chase_escape")
		if ai.sm.current_name in ["CHASING", "ENRAGED"]:
			ai.sm.change("DISAPPEARING", {"instant": not ai.seen})


func _on_player_teleported(pos: Vector3) -> void:
	if not active:
		return
	crumbs.clear()
	crumbs.append(pos)
	if config.get("portal_escape", false):
		stop(true)
		return
	# She follows through the impossible door after a short beat.
	ai.visible = false
	_portal_follow = float(config.get("portal_delay", 2.2))
	_portal_target = pos


func _physics_process(delta: float) -> void:
	if not active or ai == null or player == null:
		return
	if player.dead:
		stop(false)
		return
	_time += delta
	_record_crumb()
	if config.has("exit_check") and (config["exit_check"] as Callable).is_valid() and (config["exit_check"] as Callable).call():
		stop(true)
		return
	var max_time := float(config.get("max_time", 0.0))
	if max_time > 0.0 and _time > max_time:
		stop(true)
		return
	if _portal_follow > 0.0:
		_portal_follow -= delta
		if _portal_follow <= 0.0:
			ai.show_body(_portal_target)
			ai.body.set_pose(SatellaBody.Pose.RUN)
			AudioManager.play_3d("door_slam", _portal_target + Vector3.UP, 2.0, 10.0)
			crumbs.clear()
			crumbs.append(player.global_position)
		return
	drive(delta)


func _record_crumb() -> void:
	if crumbs.is_empty() or crumbs[crumbs.size() - 1].distance_to(player.global_position) > 0.5:
		crumbs.append(player.global_position)
		if crumbs.size() > 400:
			crumbs.pop_front()


func drive(delta: float) -> void:
	var move_pose := SatellaBody.Pose.WALK if config.get("walk", false) else SatellaBody.Pose.RUN
	if _stun > 0.0:
		_stun -= delta
		ai.body.set_pose(SatellaBody.Pose.KNEEL)
		return
	var speed := float(config.get("speed", 5.0))
	if config.get("enraged", false):
		speed *= 1.1
	# She slows a little when the flashlight is pointed at her face (fairness).
	if player.flashlight.illuminates(ai.head_pos()) and ai.seen:
		speed *= 0.85
	# Door handling
	if _waiting_door != null:
		_door_wait -= delta
		ai.body.set_pose(SatellaBody.Pose.STILL)
		if _door_wait <= 0.0:
			var dir := 1.0 if _waiting_door.to_local(ai.global_position).z > 0.0 else -1.0
			_waiting_door.slam_open(dir)
			ai.body.set_pose(move_pose)
			_waiting_door = null
		return
	var target: Vector3
	var d := ai.distance_to_player()
	var direct := d < 7.0 and ai.sees_player(7.0)
	if direct:
		target = player.global_position
		crumbs.clear()
		crumbs.append(player.global_position)
	else:
		while crumbs.size() > 1 and ai.global_position.distance_to(crumbs[0]) < 0.6:
			crumbs.pop_front()
		target = crumbs[0] if not crumbs.is_empty() else player.global_position
	# closed doors on the way
	for dr in ai.get_tree().get_nodes_in_group("doors"):
		var door := dr as Door
		if door == null or door.is_open or not door.is_inside_tree():
			continue
		var c := door.doorway_center()
		if Vector2(c.x - ai.global_position.x, c.z - ai.global_position.z).length() < 1.0 and absf(c.y - ai.global_position.y - 1.0) < 1.5:
			_waiting_door = door
			_door_wait = float(config.get("door_delay", 1.4))
			AudioManager.play_3d("knock", c, 2.0, 8.0, 1.4)
			if not _doors_bashed.has(door.get_instance_id()):
				_doors_bashed[door.get_instance_id()] = true
				EnvyAwareness.gain("door_closed_on_her")
				if EnvyAwareness.stage() >= EnvyAwareness.Stage.UNSTABLE and not config.get("enraged", false) and randf() < 0.5:
					set_enraged(true)
					DialogueManager.say("witch_enraged_1", {"position": ai.head_pos()})
			return
	ai.body.set_pose(move_pose)
	ai.glide_toward(target, speed, delta)
	# catch
	if d < float(config.get("catch_radius", ai.catch_radius)):
		active = false
		player.panic_floor = 0.0
		AudioManager.chase_active = false
		EventBus.chase_ended.emit(chase_id, false)
		chase_finished.emit(chase_id, false)
		EnvyAwareness.gain("chase_caught")
		ai.catch_player("chase_" + chase_id)
		return
	# blink closer when far and unseen
	var trail_len := 0.0
	for i in range(1, crumbs.size()):
		trail_len += crumbs[i - 1].distance_to(crumbs[i])
	var blink_distance := float(config.get("blink_distance", 16.0))
	if trail_len > blink_distance and not ai.seen and crumbs.size() > 6:
		var idx := maxi(0, crumbs.size() - int(9.0 / 0.5))
		ai.global_position = crumbs[idx]
		crumbs = crumbs.slice(idx)
		AudioManager.play_3d("whoosh", ai.head_pos(), -4.0)
	# losing her (non-scripted chases only)
	var esc := float(config.get("escape_distance", 0.0))
	if esc > 0.0:
		if d > esc and not ai.sees_player(esc):
			_far_time += delta
			if _far_time > 5.0:
				stop(true)
		else:
			_far_time = 0.0
