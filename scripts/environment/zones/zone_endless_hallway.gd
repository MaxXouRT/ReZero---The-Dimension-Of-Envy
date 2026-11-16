extends Zone
## THE ENDLESS HALLWAY — fragment 4, and the chase "SHE IS COMING".
##
## The corridor bites its own tail: past a certain point you are silently
## moved back 14 m (two identical 7 m bays), so it never ends. Each loop the
## paintings change. After enough loops she comes:
##   footsteps -> "Subaru ?" -> nobody -> "Attends-moi..." -> the flashlight
##   stutters -> a silhouette at the end of the corridor, still -> darkness ->
##   she is MUCH closer -> the silver-handprint door bursts open -> RUN.

const PERIOD := 14.0
const LOOP_Z := -4.0
var exit_door: Door
var paintings: Array[MeshInstance3D] = []
var _sequence_started := false
var _loop_cool := 0.0


func _init() -> void:
	display_name = "Le Couloir Sans Fin"
	cluster = "hallway"
	ambience = {"amb_drone_low": 0.55, "amb_mansion_room": 0.35}
	rules = {"no_satella": true, "follow": false, "manifest": false}


func build() -> void:
	set_bounds(Vector3(0, 1.9, 0), Vector3(3.4, 3.8, 40))
	Builder.room(self, Vector3.ZERO, Vector3(3.4, 3.8, 40), {"name": "Hallway", "wall": "wallpaper", "floor": "wood_floor", "skip": ["n", "s"], "beams": false,
		"openings": [{"side": "e", "offset": 3.5, "width": 1.2, "height": 2.3}]})
	# the ends are pure darkness
	Builder.box(self, Vector3(3.6, 3.8, 0.2), Vector3(0, 1.9, -20.1), Builder.mat("black"))
	Builder.box(self, Vector3(3.6, 3.8, 0.2), Vector3(0, 1.9, 20.1), Builder.mat("black"))
	Builder.box(self, Vector3(39.0, 0.01, 1.2), Vector3(0, 0.006, 0), Builder.mat("carpet"), false, Vector3(0, 90, 0))
	# identical 7 m bays so the loop is invisible
	for k in range(-2, 3):
		var z := k * 7.0
		Builder.sconce(self, Vector3(-1.6, 2.1, z), Vector3(1, 0, 0), true)
		var c := Builder.painting(self, Vector3(1.66, 1.75, z), -90.0, Vector2(0.75, 1.0), 0, 3.0)
		c.add_to_group("paintings")
		paintings.append(c)
		Builder.box(self, Vector3(0.4, 0.75, 0.8), Vector3(-1.45, 0.375, z + 3.5), Builder.mat("wood_dark"))
		Builder.cyl(self, 0.07, 0.1, 0.3, Vector3(-1.45, 0.9, z + 3.5), Builder.mat("marble"))
	Builder.fog_volume(self, Vector3(0, 1.9, 0), Vector3(3.4, 3.8, 40), 0.9)
	# exit door (east wall, opens only when she comes)
	exit_door = Builder.door(self, Vector3(1.7, 0, 3.5), -90.0, {"locked": true, "lock_line": "", "name": "HandprintDoor"})
	exit_door.set_meta("story_door", true)
	exit_door.set_portal(null, _to_maze)
	readable(Vector3(-1.2, 0.77, 10.5), "note_hallway_original", "Lire l'écriture argentée", true)
	readable(Vector3(-1.45, 0.77, -3.5), "note_origin_1", "Lire la page déchirée", true)
	add_spawn("arrival", Vector3(0, 0.05, 15.5), 0.0)


func on_enter(_p: PlayerController) -> void:
	if not GameState.has_flag("seen_hallway"):
		GameState.set_flag("seen_hallway")
		DialogueManager.say("c4_hallway", {"delay": 2.0})
		ChapterManager.set_objective("obj_hallway_loop")
	if not GameState.has_flag("hallway_checkpoint"):
		GameState.set_flag("hallway_checkpoint")
		checkpoint("hallway_entry", Vector3(0, 0.05, 15.5), 0.0)


func loops() -> int:
	return int(GameState.get_flag("hallway_loops", 0))


func _process(delta: float) -> void:
	_loop_cool = maxf(0.0, _loop_cool - delta)
	var p := player()
	if p == null or p.current_zone != zone_id or p.dead:
		return
	var local := to_local(p.global_position)
	if local.z < LOOP_Z and _loop_cool <= 0.0 and not GameState.has_flag("hallway_escaped"):
		_loop_cool = 0.5
		var sat := satella()
		var sat_rel := Vector3.ZERO
		var move_sat := sat != null and sat.visible and to_local(sat.global_position).z < 20.5 and absf(to_local(sat.global_position).x) < 2.0
		if move_sat:
			sat_rel = sat.global_position - p.global_position
		# silent teleport: same view, 14 m back
		var keep_yaw := p.get_yaw()
		var vel := p.velocity
		p.global_position = to_global(local + Vector3(0, 0, PERIOD))
		p.set_look(keep_yaw, p.head.rotation.x)
		p.velocity = vel
		if move_sat:
			sat.global_position = p.global_position + sat_rel
		if game.chase and game.chase.is_active():
			game.chase.crumbs.clear()
			game.chase.crumbs.append(p.global_position)
		GameState.set_flag("hallway_loops", loops() + 1)
		_on_loop(loops())


func _on_loop(n: int) -> void:
	if n == 1:
		for c in paintings:
			(c.material_override as ShaderMaterial).set_shader_parameter("variant", 2)
	elif n == 2:
		for c in paintings:
			(c.material_override as ShaderMaterial).set_shader_parameter("variant", 5)
		if game.director:
			game.director.execute("painting_stare", {})
		for l in get_tree().get_nodes_in_group("flicker_lights"):
			if l is FlickerLight and l.global_position.distance_to(global_position) < 25.0 and randf() < 0.4:
				l.kill()
	var needed := 1 if GameState.has_flag("mem_hallway_known") else 3
	if n >= needed and not _sequence_started:
		_she_is_coming()


# ------------------------------------------------------------------ SHE IS COMING
func _she_is_coming() -> void:
	_sequence_started = true
	GameState.set_flag("mem_hallway_known")
	var p := player()
	var sat := satella()
	if game.director:
		game.director.cutscene_active = true
	sat.autonomous = false
	# 1. footsteps behind
	AudioManager.play_3d("footsteps_distant", p.global_position - p.forward() * 9.0 + Vector3.UP, 2.0, 8.0)
	await get_tree().create_timer(3.2).timeout
	# 2. "Subaru ?" from behind
	DialogueManager.say("c4_she_whisper", {"direction": -p.forward()})
	var t := 0.0
	while t < 5.0 and p.look_dot(p.global_position - p.forward() * 5.0 + Vector3.UP * 1.6) < 0.5:
		await get_tree().process_frame
		t += get_process_delta_time()
	# 3. nobody. "Attends-moi..."
	await get_tree().create_timer(1.6).timeout
	DialogueManager.say("c4_she_wait", {"direction": p.forward()})
	p.flashlight.flicker(2.2, 0.9)
	await get_tree().create_timer(2.2).timeout
	# 4. silhouette at the end of the corridor, in front of him
	var dir := 1.0 if p.forward().z > 0.0 else -1.0
	var lp := to_local(p.global_position)
	var far_z := clampf(lp.z + dir * 12.5, -19.0, 19.0)
	sat.sm.change("INTERACTING", {"pos": to_global(Vector3(0, 0, far_z)), "pose": SatellaBody.Pose.STILL, "persona": "witch"})
	sat.face_toward(p.global_position)
	AudioManager.play_2d("heartbeat", -2.0)
	p.add_panic(0.5)
	t = 0.0
	while t < 6.0 and sat.seen_time < 2.2:
		await get_tree().process_frame
		t += get_process_delta_time()
	# 5. darkness. She is gone.
	p.flashlight.die_for(0.9)
	await get_tree().create_timer(0.35).timeout
	sat.hide_body()
	await get_tree().create_timer(0.6).timeout
	# 6. ...she is much closer.
	lp = to_local(p.global_position)
	var near_z := clampf(lp.z + dir * 5.0, -19.0, 19.0)
	sat.sm.change("INTERACTING", {"pos": to_global(Vector3(0, 0, near_z)), "pose": SatellaBody.Pose.REACH})
	sat.face_toward(p.global_position)
	AudioManager.play_jumpscare("stinger_1", -2.0)
	JumpscareState.begin("she_is_coming", 2.5)
	EventBus.camera_shake.emit(0.5, 0.5)
	p.add_panic(0.9)
	await get_tree().create_timer(0.7).timeout
	DialogueManager.say("c4_chase_scream", {"position": sat.head_pos()})
	# 7. the handprint door bursts open
	exit_door.locked = false
	Builder.box(self, Vector3(0.02, 0.22, 0.16), Vector3(1.6, 1.3, 3.0), Builder.mat("silver_glow"), false)
	exit_door.slam_open(1.0)
	DialogueManager.say("c4_chase_hint", {"delay": 0.4})
	ChapterManager.set_objective("obj_escape")
	if game.director:
		game.director.cutscene_active = false
	sat.autonomous = true
	var maze: Zone = world.get_zone("abandoned_wing")
	sat.sm.change("CHASING", {"id": "she_is_coming", "speed": 5.15, "door_delay": 1.3, "portal_delay": 2.0, "blink_distance": 15.0, "exit_check": maze.in_fragment_room})


func _to_maze(_b: Node) -> void:
	var maze: Zone = world.get_zone("abandoned_wing")
	var sp: Dictionary = maze.spawn_points["start"]
	game.transition_teleport(sp["pos"], sp["yaw"], "abandoned_wing", 0.05)
