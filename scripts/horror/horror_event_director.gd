class_name HorrorEventDirector
extends Node
## HORROR EVENT DIRECTOR — central manager of every scare.
##
## Data-driven (res://resources/events/horror_events.json). For each event:
## conditions (chapter, awareness, flags, zone), probability, triggers,
## delays, cooldowns, uniqueness (unique events are remembered across loops),
## and a "major" flag. Pacing rules keep the game from becoming a stream of
## surprises:
##   * at most one major event per MAJOR_GAP seconds (shrinks as she wakes),
##   * a minimum gap between minor events,
##   * nothing during chases, cutscenes, dialogues or when Satella is busy,
##   * a "tension" value that has to build up in silence before ambient
##     events can fire — anticipation first, then the scare.

const DATA_PATH := "res://resources/events/horror_events.json"
const MAJOR_GAP := 75.0
const MINOR_GAP := 22.0
const AMBIENT_TICK := 6.0

var events: Array = []
var player: PlayerController
var satella: SatellaAI
var overlay: Node = null            ## HorrorOverlay (face, fake death, fake menu)
var world: Node = null
var cutscene_active := false
var tension := 0.0                  ## 0..1, grows in quiet moments
var _last_major := -9999.0
var _last_minor := -9999.0
var _cooldowns := {}                ## id -> time when available again
var _tick := AMBIENT_TICK
var _clock := 0.0
var _pending := 0


func _ready() -> void:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	if typeof(data) == TYPE_DICTIONARY:
		events = data.get("events", [])
	EventBus.player_zone_changed.connect(func(z): notify("enter:" + z))
	EventBus.flag_set.connect(_on_flag)
	EventBus.chapter_started.connect(func(c): notify("chapter:%d" % c))


func _on_flag(flag: String, value: Variant) -> void:
	if value:
		notify("flag:" + flag)


func setup(p: PlayerController, s: SatellaAI, ov: Node, w: Node) -> void:
	player = p
	satella = s
	overlay = ov
	world = w


# ------------------------------------------------------------------ triggers
func notify(trigger: String) -> void:
	for e in events:
		if String(e.get("trigger", "")) == trigger:
			_try(e)


func _process(delta: float) -> void:
	_clock += delta
	if player == null or player.dead:
		return
	var calm := not AudioManager.chase_active and satella != null and satella.sm.current_name == "DORMANT"
	if calm:
		tension = minf(1.0, tension + delta / 90.0 * EnvyAwareness.presence_factor())
	_tick -= delta
	if _tick <= 0.0:
		_tick = AMBIENT_TICK
		var candidates: Array = []
		for e in events:
			if String(e.get("trigger", "")) == "ambient" and _conditions_ok(e):
				candidates.append(e)
		candidates.shuffle()
		for e in candidates:
			if tension < 0.35 and bool(e.get("major", false)):
				continue
			if _try(e):
				break


func _conditions_ok(e: Dictionary) -> bool:
	var id := String(e["id"])
	var ch := GameState.chapter()
	if ch < int(e.get("min_chapter", 1)) or ch > int(e.get("max_chapter", 99)):
		return false
	var aw := EnvyAwareness.value()
	if aw < float(e.get("min_awareness", 0)) or aw > float(e.get("max_awareness", 101)):
		return false
	if bool(e.get("once", false)) and GameState.event_seen(id):
		return false
	if _cooldowns.has(id) and _clock < float(_cooldowns[id]):
		return false
	for f in e.get("requires_flags", []):
		if not GameState.has_flag(String(f)):
			return false
	for f in e.get("forbid_flags", []):
		if GameState.has_flag(String(f)):
			return false
	var zones: Array = e.get("zones", [])
	if not zones.is_empty() and player and not zones.has(player.current_zone):
		return false
	if world and world.has_method("rules_for") and player and world.rules_for(player.current_zone).get("no_events", false):
		return false
	return true


func _pacing_ok(e: Dictionary) -> bool:
	if cutscene_active or AudioManager.chase_active or player == null or player.dead:
		return false
	if satella and satella.sm.current_name != "DORMANT" and String(e.get("type", "")) not in ["whisper", "footsteps_distant", "knock", "awakened_line"]:
		return false
	var gap_scale := 1.0 / EnvyAwareness.presence_factor()
	if bool(e.get("major", false)):
		var trig := String(e.get("trigger", ""))
		# scripted (non-ambient) majors only need a short breathing room
		var gap := MAJOR_GAP * clampf(gap_scale, 0.6, 2.5) if trig == "ambient" else 12.0
		return _clock - _last_major > gap
	return _clock - _last_minor > MINOR_GAP * clampf(gap_scale, 0.6, 2.0) or String(e.get("trigger", "")) != "ambient"


func _try(e: Dictionary) -> bool:
	if not _conditions_ok(e):
		return false
	if randf() > float(e.get("chance", 1.0)):
		if e.has("cooldown"):
			_cooldowns[String(e["id"])] = _clock + float(e["cooldown"]) * 0.3
		return false
	if not _pacing_ok(e):
		return false
	var id := String(e["id"])
	if bool(e.get("once", false)):
		GameState.mark_event_seen(id)
	if e.has("cooldown"):
		_cooldowns[id] = _clock + float(e["cooldown"])
	if bool(e.get("major", false)):
		_last_major = _clock
		tension = 0.0
	else:
		_last_minor = _clock
		tension *= 0.6
	var delay := float(e.get("delay", 0.0))
	_run_delayed(e, delay)
	return true


func _run_delayed(e: Dictionary, delay: float) -> void:
	_pending += 1
	if delay > 0.0:
		await get_tree().create_timer(delay, false).timeout
	_pending -= 1
	if player == null or player.dead or cutscene_active:
		return
	EventBus.horror_event.emit(String(e["id"]))
	execute(String(e.get("type", "")), e.get("params", {}))


# ------------------------------------------------------------------ actions
func execute(type: String, params: Dictionary) -> void:
	match type:
		"footsteps_distant":
			var dir := player.forward() * (1.0 if randf() < 0.5 else -1.0)
			AudioManager.play_3d("footsteps_distant", player.global_position + dir * 12.0 + Vector3.UP, -2.0, 8.0)
			if params.get("line", "") != "":
				await get_tree().create_timer(3.0).timeout
				DialogueManager.say(String(params["line"]))
		"door_slam":
			_door_slam()
		"silhouette":
			var idx := satella.pick_spot([String(params.get("spot_kind", "corridor_end"))], 6.0, 40.0)
			if idx < 0:
				idx = satella.pick_spot([], 6.0, 40.0)
			if idx >= 0:
				satella.sm.change("OBSERVING", {"spot": idx, "timeout": float(params.get("duration", 10.0))})
		"knock":
			var side := player.global_transform.basis.x * (1.0 if randf() < 0.5 else -1.0)
			AudioManager.play_3d("knock", player.global_position + side * 3.5 + Vector3.UP * 1.3, 0.0, 6.0)
			player.add_panic(0.2)
		"mirror_face":
			_mirror_face()
		"behind_player":
			_behind_player()
		"sound_scare":
			AudioManager.play_3d("thump", player.global_position - player.forward() * 4.0 + Vector3.UP, 4.0, 10.0)
			player.flashlight.flicker(1.2, 1.0)
			player.add_panic(0.5)
			EventBus.camera_shake.emit(0.25, 0.3)
		"fake_death":
			if overlay:
				overlay.fake_death()
		"fake_menu":
			if overlay:
				overlay.fake_menu(String(params.get("kind", "save")))
		"distortion":
			EventBus.world_distortion.emit(float(params.get("intensity", 0.8)), float(params.get("duration", 2.5)))
			EventBus.screen_glitch.emit(0.0, 0.0)
			AudioManager.play_2d("reality_bend", -4.0)
			if params.get("line", "") != "":
				DialogueManager.say(String(params["line"]))
		"whisper":
			var dir2 := -player.forward().rotated(Vector3.UP, randf_range(-1.2, 1.2))
			AudioManager.play_directional("whisper", dir2, 2.5, -4.0)
		"whisper_ring":
			for i in 4:
				var a := TAU * i / 4.0 + randf() * 0.5
				AudioManager.play_directional("whisper", Vector3(cos(a), 0.1, sin(a)), 3.0, -6.0)
				await get_tree().create_timer(0.9).timeout
			DialogueManager.say("c3_observer")
		"footsteps_follow":
			_footsteps_follow()
		"lights_out":
			_lights_out(float(params.get("duration", 3.0)), bool(params.get("appear", false)))
		"face_jumpscare":
			if overlay:
				overlay.face_jumpscare()
		"flashlight_die":
			_flashlight_die(float(params.get("duration", 3.0)), bool(params.get("appear", true)))
		"painting_stare":
			_painting_stare()
		"awakened_line":
			satella.say_awakened_line()
		_:
			push_warning("HorrorEventDirector: unknown event type %s" % type)


func _door_slam() -> void:
	var best: Door = null
	var best_d := 999.0
	for n in get_tree().get_nodes_in_group("doors"):
		var d := n as Door
		if d == null or d.locked or d.portal_target != null or d.has_meta("story_door"):
			continue
		var dist := d.global_position.distance_to(player.global_position)
		if dist > 4.0 and dist < 22.0 and dist < best_d:
			best = d
			best_d = dist
	if best == null:
		AudioManager.play_3d("door_slam", player.global_position - player.forward() * 9.0 + Vector3.UP, 2.0, 10.0)
		return
	if best.is_open:
		best.slam_shut()
	else:
		best.slam_open()
	player.add_panic(0.45)


func _mirror_face() -> void:
	var p := player
	var behind := p.global_position - p.forward() * 1.3
	satella.autonomous = false
	satella.sm.change("INTERACTING", {"pos": behind, "pose": SatellaBody.Pose.STILL, "mirror": true})
	satella.face_toward(p.global_position)
	satella.body.set_face_lit(0.6)
	JumpscareState.begin("mirror_face", 3.0)
	DialogueManager.say("witch_mirror", {"position": satella.head_pos()})
	await get_tree().create_timer(1.6).timeout
	AudioManager.play_jumpscare("stinger_2", -3.0)
	p.add_panic(0.7)
	EventBus.camera_shake.emit(0.3, 0.3)
	for m in get_tree().get_nodes_in_group("mirrors"):
		if m.global_position.distance_to(p.global_position) < 5.0:
			m.crack(1.0)
	EnvyAwareness.add(2.0, "mirror_face")
	await get_tree().create_timer(0.7).timeout
	satella.body.set_face_lit(0.0)
	satella.autonomous = true
	satella.sm.change("DISAPPEARING", {"instant": true})


func _behind_player() -> void:
	var p := player
	var behind := p.global_position - p.forward() * 1.4
	var space := p.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(p.eye_position(), behind + Vector3.UP * 1.5, 1)
	if not space.intersect_ray(q).is_empty():
		return
	satella.autonomous = false
	satella.sm.change("INTERACTING", {"pos": behind, "pose": SatellaBody.Pose.STILL})
	satella.face_toward(p.global_position)
	AudioManager.play_3d("breath_out", satella.head_pos(), -6.0, 2.0)
	var t := 0.0
	var whispered := false
	while t < 11.0:
		await get_tree().process_frame
		if not is_instance_valid(p) or p.dead:
			break
		t += get_process_delta_time()
		# she keeps the distance while he moves
		var target := p.global_position - p.forward() * 1.4
		if not satella.seen:
			satella.global_position = satella.global_position.lerp(target, 0.15)
			satella.face_toward(p.global_position)
		if satella.seen and satella.seen_time > 0.05:
			satella.body.set_pose(SatellaBody.Pose.REACH)
			satella.body.set_face_lit(1.0)
			JumpscareState.begin("behind", 2.5)
			AudioManager.play_jumpscare("stinger_1", 0.0)
			EventBus.camera_shake.emit(0.75, 0.5)
			EventBus.screen_glitch.emit(0.4, 0.3)
			p.add_panic(0.9)
			EnvyAwareness.add(2.5, "behind_scare")
			await get_tree().create_timer(0.45).timeout
			break
		if t > 6.0 and not whispered:
			whispered = true
			DialogueManager.say("witch_behind", {"position": satella.head_pos()})
	satella.body.set_face_lit(0.0)
	satella.autonomous = true
	satella.sm.change("DISAPPEARING", {"instant": true})


func _footsteps_follow() -> void:
	var p := player
	var last := p.global_position
	var steps := 0
	var t := 0.0
	while steps < 8 and t < 20.0:
		await get_tree().create_timer(0.3).timeout
		t += 0.3
		if not is_instance_valid(p) or p.dead:
			return
		if p.global_position.distance_to(last) > 0.7:
			last = p.global_position
			steps += 1
			AudioManager.play_3d("step_wood", p.global_position - p.forward() * 3.0, -8.0, 5.0, 0.85)
	# when he stops... one more step.
	await get_tree().create_timer(1.2).timeout
	if is_instance_valid(p):
		AudioManager.play_3d("step_wood", p.global_position - p.forward() * 1.5, -4.0, 5.0, 0.8)
		p.add_panic(0.3)


func _lights_out(duration: float, appear: bool) -> void:
	var p := player
	AudioManager.play_2d("flicker_buzz", -6.0)
	for l in get_tree().get_nodes_in_group("flicker_lights"):
		if l is FlickerLight and l.global_position.distance_to(p.global_position) < 28.0:
			l.blackout(duration)
	p.flashlight.die_for(duration * 0.7)
	p.add_panic(0.4)
	if appear and satella.sm.current_name == "DORMANT":
		await get_tree().create_timer(duration * 0.3).timeout
		var front := p.global_position + p.forward() * 4.5
		satella.autonomous = false
		satella.sm.change("INTERACTING", {"pos": front, "pose": SatellaBody.Pose.STILL})
		await get_tree().create_timer(duration * 0.4 + 0.15).timeout
		AudioManager.play_jumpscare("stinger_2", -4.0)
		await get_tree().create_timer(0.5).timeout
		satella.autonomous = true
		satella.sm.change("DISAPPEARING", {"instant": not satella.seen})


func _flashlight_die(duration: float, appear: bool) -> void:
	var p := player
	p.flashlight.die_for(duration)
	AudioManager.play_2d("flicker_buzz", -6.0)
	if not appear:
		return
	await get_tree().create_timer(duration * 0.5).timeout
	var front := p.global_position + p.forward() * 3.0
	satella.autonomous = false
	satella.sm.change("INTERACTING", {"pos": front, "pose": SatellaBody.Pose.REACH})
	await get_tree().create_timer(duration * 0.5).timeout
	JumpscareState.begin("flashlight", 2.0)
	AudioManager.play_jumpscare("stinger_1", -2.0)
	p.add_panic(0.8)
	EventBus.camera_shake.emit(0.5, 0.4)
	await get_tree().create_timer(0.4).timeout
	satella.autonomous = true
	satella.sm.change("DISAPPEARING", {"instant": true})


func _painting_stare() -> void:
	for n in get_tree().get_nodes_in_group("paintings"):
		var mi := n as MeshInstance3D
		if mi == null or mi.global_position.distance_to(player.global_position) > 30.0:
			continue
		var m := mi.material_override as ShaderMaterial
		if m:
			var tw := create_tween()
			tw.tween_method(func(v: float): m.set_shader_parameter("stare", v), 0.0, 1.0, 2.0)
	DialogueManager.say("c4_hallway_change")
