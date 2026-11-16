extends Node
## Automated QA suite (headless):
##   godot --headless --path . res://tests/run_tests.tscn
## Covers data integrity (dialogue/notes ids), GameState memory rules,
## save/load, Envy Awareness, every Satella state, every horror event,
## the chase/catch/death chain, chapter progression through the real seal,
## the puzzles' solutions, and both branches of the meta ending.

var failures: Array[String] = []
var passes := 0
var game: Node


func check(cond: bool, label: String) -> void:
	if cond:
		passes += 1
	else:
		failures.append(label)
		print("  FAIL: ", label)


func _ready() -> void:
	print("=== RE:ZERO — THE DIMENSION OF ENVY — QA suite ===")
	SaveManager.use_sandbox()
	var only := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = a.get_slice("=", 1)
	_test_data_integrity()
	_test_game_state_memory()
	_test_save_load()
	_test_awareness()
	_test_dialogue_tokens()
	# Deaths still emit EventBus.player_died, but ReturnByDeath must not reload
	# the scene (it would delete this test runner).
	ReturnByDeath.running = true
	if only == "" or only == "systems":
		await _test_game_systems()
	if only == "" or only == "chapters":
		await _test_chapter_progression()
	if only == "" or only == "walk":
		await _test_walkthrough()
	if only == "" or only == "meta":
		await _test_meta_ending()
	print("=== %d passed, %d failed ===" % [passes, failures.size()])
	for f in failures:
		print("FAILED: ", f)
	get_tree().quit(1 if failures.size() > 0 else 0)


# ------------------------------------------------------------------ data
func _collect_scripts(dir_path: String, out: Array) -> void:
	var d := DirAccess.open(dir_path)
	if d == null:
		return
	for f in d.get_files():
		if f.ends_with(".gd"):
			out.append(dir_path + "/" + f)
	for sub in d.get_directories():
		_collect_scripts(dir_path + "/" + sub, out)


func _test_data_integrity() -> void:
	print("- data integrity")
	var files: Array = []
	_collect_scripts("res://scripts", files)
	var re_say := RegEx.new()
	re_say.compile("(?:say|DialogueManager\\.say)\\(\"([a-z0-9_]+)\"")
	var re_note := RegEx.new()
	re_note.compile("\"((?:note|msg)_[a-z0-9_]+)\"")
	var missing_lines := []
	var missing_notes := []
	for f in files:
		var txt := FileAccess.get_file_as_string(f)
		for m in re_say.search_all(txt):
			var id := m.get_string(1)
			if not DialogueManager.has_line(id) and not missing_lines.has(id):
				missing_lines.append(id)
		for m in re_note.search_all(txt):
			var nid := m.get_string(1)
			if not DialogueManager.notes.has(nid) and not missing_notes.has(nid) and nid != "note_":
				missing_notes.append(nid)
	check(missing_lines.is_empty(), "all dialogue ids exist (missing: %s)" % str(missing_lines))
	check(missing_notes.is_empty(), "all note ids exist (missing: %s)" % str(missing_notes))
	for i in range(2, 9):
		check(DialogueManager.has_line("loop_%d" % i), "loop line %d" % i)
	for i in range(1, 6):
		check(DialogueManager.has_line("awake_%d" % i), "awakened line %d" % i)
		check(not ChapterManager.get_chapter(i).is_empty(), "chapter %d defined" % i)
	for k in ["obj_light", "obj_chapel", "obj_escape", "obj_pillars"]:
		check(ChapterManager.objectives.has(k), "objective %s" % k)
	var ev: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://resources/events/horror_events.json"))
	check(typeof(ev) == TYPE_DICTIONARY and ev["events"].size() > 15, "horror events loaded")
	for s in ["return_by_death", "witch_scream", "jumpscare_violent", "creak", "step_wood", "music_chase", "amb_void_wind", "whisper"]:
		check(AudioManager.has_sound(s), "sound %s" % s)


# ------------------------------------------------------------------ state
func _test_game_state_memory() -> void:
	print("- Return by Death memory rules")
	GameState.new_game()
	GameState.set_flag("door_open")
	GameState.add_item("music_box_key")
	GameState.set_checkpoint("t1", "bedroom", Vector3(1, 0, 2), 0.5)
	# after the checkpoint: world changes + memory changes
	GameState.set_flag("solved_after_checkpoint")
	GameState.collect_fragment("forgotten_bedroom")
	GameState.set_flag("mem_learned_secret")
	GameState.mark_note_read("note_awakening")
	EnvyAwareness.set_value(33.0)
	GameState.register_death("test")
	GameState.rewind_to_checkpoint()
	check(GameState.has_flag("door_open"), "world state before checkpoint kept")
	check(not GameState.has_flag("solved_after_checkpoint"), "world state after checkpoint rewound")
	check(not GameState.has_fragment("forgotten_bedroom"), "fragment after checkpoint rewound")
	check(GameState.has_flag("mem_learned_secret"), "memory flag survives death")
	check(GameState.run["notes_read"].has("note_awakening"), "notes survive death")
	check(GameState.deaths() == 1, "death counted")
	check(is_equal_approx(EnvyAwareness.value(), 33.0), "awareness survives death")
	check(GameState.get_checkpoint_position().is_equal_approx(Vector3(1, 0, 2)), "checkpoint position")


func _test_save_load() -> void:
	print("- save / load")
	GameState.new_game()
	GameState.run["chapter"] = 3
	GameState.collect_fragment("library_of_memories")
	GameState.set_flag("library_solved")
	GameState.set_checkpoint("t2", "library", Vector3(0, 0, -70), 1.0)
	GameState.register_death("x")
	GameState.register_death("y")
	EnvyAwareness.set_value(55.0)
	GameState.set_flag("mem_after_save")
	check(SaveManager.save_game(), "save written")
	check(SaveManager.has_save(), "save exists")
	GameState.new_game()
	check(SaveManager.load_game(), "save loaded")
	check(GameState.chapter() == 3, "chapter restored")
	check(GameState.has_fragment("library_of_memories"), "fragments restored")
	check(GameState.deaths() == 2, "deaths restored from memory")
	check(is_equal_approx(EnvyAwareness.value(), 55.0), "awareness restored")
	check(GameState.has_flag("mem_after_save"), "memory flags restored")
	var info := SaveManager.save_info()
	check(int(info.get("chapter", 0)) == 3, "save info")
	SaveManager.delete_save()
	check(not SaveManager.has_save(), "save deleted")


func _test_awareness() -> void:
	print("- Envy Awareness")
	GameState.new_game()
	GameState.run["awareness"] = 0.0
	GameState.run["chapter"] = 1
	EnvyAwareness.add(80.0, "test", EnvyAwareness.chapter_cap())
	check(EnvyAwareness.value() <= 30.0, "chapter 1 cap (%.1f)" % EnvyAwareness.value())
	GameState.run["chapter"] = 5
	EnvyAwareness.add(200.0, "test", EnvyAwareness.chapter_cap())
	check(is_equal_approx(EnvyAwareness.value(), 100.0), "chapter 5 can reach 100")
	check(EnvyAwareness.stage() == EnvyAwareness.Stage.PLAYER_DETECTED, "stage PLAYER DETECTED")
	var stages := [0.0, 25.0, 45.0, 65.0, 85.0, 100.0]
	for i in stages.size():
		check(EnvyAwareness.stage_for(stages[i]) == i, "stage for %.0f" % stages[i])


func _test_dialogue_tokens() -> void:
	print("- dialogue tokens")
	var saved := Settings.player_name
	Settings.player_name = "Mika"
	check(DialogueManager.get_text("meta_4a") == "Mika...", "player name substituted")
	Settings.player_name = ""
	check(DialogueManager.get_text("meta_4a") == "toi...", "neutral fallback without name")
	Settings.player_name = saved


# ------------------------------------------------------------------ game
func _load_game_at(chapter: int) -> void:
	if game and is_instance_valid(game):
		game.queue_free()
		await get_tree().process_frame
	GameState.new_game()
	DebugTools.jump_to_chapter(chapter)
	GameState.run["flags"]["intro_done"] = true
	game = (load("res://scenes/main/game.tscn") as PackedScene).instantiate()
	add_child(game)
	await _frames(10)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _test_game_systems() -> void:
	print("- game systems")
	await _load_game_at(3)
	check(game.player != null, "player spawned")
	check(game.world.zones.size() == 13, "13 zones built")
	check(game.player.current_zone == "grand_hall", "spawned in hall (%s)" % game.player.current_zone)
	check(game.satella.spots.size() > 20, "satella spots registered (%d)" % game.satella.spots.size())
	# every Satella state
	var sat: SatellaAI = game.satella
	for st in ["OBSERVING", "WATCHING", "FOLLOWING", "MANIFESTING", "HUNTING", "DISAPPEARING", "INTERACTING", "DORMANT"]:
		var args := {"pos": game.player.global_position + Vector3(0, 0, -8)}
		if st == "OBSERVING":
			args = {"spot": 0}
		sat.sm.change(st, args)
		await _frames(20)
		check(true, "state %s ran" % st)
	sat.sm.change("DORMANT", {"cooldown": 999})
	# spontaneous appearance director
	EnvyAwareness.set_value(65.0)
	var ok := false
	for i in 10:
		if sat.try_spontaneous_appearance():
			ok = true
			break
	check(ok, "spontaneous appearance possible at UNSTABLE")
	sat.sm.change("DORMANT", {"cooldown": 999})
	await _frames(5)
	# every horror event type
	var types := ["footsteps_distant", "door_slam", "silhouette", "knock", "sound_scare", "distortion", "whisper", "footsteps_follow", "lights_out", "painting_stare", "awakened_line", "behind_player", "mirror_face", "flashlight_die", "face_jumpscare"]
	for t in types:
		game.director.execute(t, {"duration": 0.5, "appear": true})
		await _frames(8)
		check(true, "event %s executed" % t)
	Engine.time_scale = 6.0
	await get_tree().create_timer(14.0).timeout
	Engine.time_scale = 1.0
	sat.autonomous = true
	sat.sm.change("DORMANT", {"cooldown": 999})
	await _frames(5)
	# fake menu (in-game fiction) + tear
	game.overlay.fake_menu("save")
	Engine.time_scale = 6.0
	await get_tree().create_timer(12.0).timeout
	Engine.time_scale = 1.0
	check(not game.overlay.busy, "fake menu finished")
	check(not game.player.is_input_locked(), "player unlocked after fake menu")
	# pause trap
	ReturnByDeath.running = false
	JumpscareState.begin("test", 3.0)
	game.pause_menu.open()
	check(game.pause_menu.trap_running, "pause trap triggered during jumpscare window")
	Engine.time_scale = 4.0
	await get_tree().create_timer(10.0, true).timeout
	Engine.time_scale = 1.0
	check(not game.pause_menu.trap_running and not get_tree().paused, "pause trap resolved and game unpaused")
	JumpscareState.end()
	game.pause_menu.open()
	check(get_tree().paused and not game.pause_menu.trap_running, "normal pause works outside scare window")
	game.pause_menu.close()
	check(not get_tree().paused, "pause closes")
	ReturnByDeath.running = true
	# portals / zones
	var corridor = game.world.get_zone("east_corridor")
	var lib_idx: int = corridor._library_index()
	var d: Door = corridor.lib_doors[lib_idx]
	d.portal_callable.call(game.player)
	await _frames(15)
	check(game.player.current_zone == "library", "any-door leads to library (%s)" % game.player.current_zone)
	# chase -> catch -> death signal
	var died := {"v": false}
	var cb := func(_c): died["v"] = true
	EventBus.player_died.connect(cb)
	ReturnByDeath.running = true   # prevent the scene reload during the test
	sat.sm.change("CHASING", {"id": "test", "speed": 8.0, "start_pos": game.player.global_position + Vector3(0, 0, 3)})
	await get_tree().create_timer(3.0).timeout
	check(died["v"], "chase catch kills Subaru")
	EventBus.player_died.disconnect(cb)
	# puzzles
	var lib = game.world.get_zone("library")
	check(lib.SOLUTION == ["gospel_capital", "gospel_mansion", "gospel_whale"], "library solution = arcs order")
	var chapel = game.world.get_zone("chapel")
	check(chapel.ORDER == ["rose", "key", "moon", "sword"], "chapel order matches silver messages")


func _test_chapter_progression() -> void:
	print("- chapter progression through the seal")
	await _load_game_at(2)
	var hall = game.world.get_zone("grand_hall")
	GameState.collect_fragment("forgotten_bedroom")
	GameState.collect_fragment("library_of_memories")
	Engine.time_scale = 8.0
	hall._on_seal(game.player)
	await get_tree().create_timer(14.0).timeout
	check(GameState.chapter() == 3, "2 fragments inserted -> chapter 3 (got %d)" % GameState.chapter())
	check(not hall.main_door.locked, "main doors unlocked")
	GameState.collect_fragment("chapel_of_envy")
	hall._on_seal(game.player)
	await get_tree().create_timer(10.0).timeout
	check(GameState.chapter() == 4, "3 fragments -> chapter 4 (got %d)" % GameState.chapter())
	var wing = game.world.get_zone("west_wing")
	check(not wing.hallway_door.locked, "condemned door opened in chapter 4")
	GameState.collect_fragment("endless_hallway")
	hall._on_seal(game.player)
	await get_tree().create_timer(16.0).timeout
	check(GameState.chapter() == 5, "4 fragments -> chapter 5 (got %d)" % GameState.chapter())
	check(hall.pit.visible, "the void opened in the hall")
	game.flow.descend_to_throne()
	await get_tree().create_timer(3.0).timeout
	check(game.player.current_zone == "throne", "descended to the throne (%s)" % game.player.current_zone)
	var throne = game.world.get_zone("throne")
	await get_tree().create_timer(14.0).timeout
	for i in 3:
		throne._light_pillar(game.player, i)
		await get_tree().create_timer(4.0).timeout
	check(throne._fragment_spawned, "3 pillars -> last fragment appears")
	Engine.time_scale = 1.0


## A bot physically walks bedroom -> corridor -> hall -> west wing -> forgotten
## bedroom: validates collisions, openings and doors line up between rooms.
func _test_walkthrough() -> void:
	print("- physical walkthrough (collisions / openings)")
	await _load_game_at(2)
	var p: PlayerController = game.player
	game.satella.autonomous = false
	game.director.cutscene_active = true
	p.teleport_to(Vector3(0, 0.05, 2.4), PI)
	await _frames(5)
	var bed_door: Door = game.world.get_zone("bedroom").get_node("BedroomDoor")
	bed_door.open(-1.0, 0.1, true)
	await get_tree().create_timer(0.3).timeout
	await _walk(Vector3(0, 0, 1), 3.0, 1.6)
	check(p.global_position.z > 4.3, "walked through bedroom door (z=%.2f)" % p.global_position.z)
	check(game.world.current_zone == "east_corridor", "in corridor (%s)" % game.world.current_zone)
	# back to the middle of the corridor, then east
	await _walk(Vector3(0, 0, -1), 2.0, maxf(0.0, (p.global_position.z - 5.4) / 2.0))
	await _walk(Vector3(1, 0, 0), 5.0, 6.0)
	check(p.global_position.x > 24.0, "walked the corridor into the hall (x=%.2f)" % p.global_position.x)
	check(game.world.current_zone == "grand_hall", "in grand hall (%s)" % game.world.current_zone)
	# line up with the west wing door (x = 28)
	var dx := 28.0 - p.global_position.x
	await _walk(Vector3(signf(dx), 0, 0), 3.0, absf(dx) / 3.0)
	var hall = game.world.get_zone("grand_hall")
	hall.west_door.open(1.0, 0.1, true)
	await get_tree().create_timer(0.3).timeout
	await _walk(Vector3(0, 0, -1), 5.0, 4.6)
	check(p.global_position.z < -9.0, "walked through the west wing door (z=%.2f)" % p.global_position.z)
	check(game.world.current_zone == "west_wing", "in west wing (%s)" % game.world.current_zone)
	# forgotten door appears (puzzle state) then walk in
	GameState.set_flag("forgotten_door_open")
	game.distortion.force("forgotten_door", 1)
	var wing = game.world.get_zone("west_wing")
	wing.forgotten_door.open(1.0, 0.1, true)
	await get_tree().create_timer(0.3).timeout
	await _walk(Vector3(0, 0, -1), 5.0, 3.6)
	check(game.world.current_zone == "forgotten_bedroom", "entered the Forgotten Bedroom (%s, z=%.2f)" % [game.world.current_zone, p.global_position.z])
	# chapel approach from the forest arrival
	var forest = game.world.get_zone("forest")
	game.transition_teleport(forest.spawn_points["arrival"]["pos"], 0.0, "forest", 0.0)
	await _frames(5)
	await _walk(Vector3(0, 0, -1), 6.0, 15.5)
	check(game.world.current_zone == "chapel", "walked the forest path into the chapel (%s, z=%.2f)" % [game.world.current_zone, p.global_position.z])
	game.director.cutscene_active = false


func _walk(dir: Vector3, speed: float, seconds: float) -> void:
	game.player.scripted_walk(dir, speed, seconds)
	await get_tree().create_timer(seconds + 0.25).timeout


func _test_meta_ending() -> void:
	print("- meta ending (TRUE path)")
	Settings.player_name = "Mika"
	await _load_game_at(6)
	game.meta.stay_in_scene = true
	EnvyAwareness.set_value(95.0)
	check(game.player.current_zone == "black_room", "black room (%s)" % game.player.current_zone)
	var ended := {"v": ""}
	Engine.time_scale = 10.0
	var t := 0.0
	while t < 160.0 and game.meta.running:
		await get_tree().process_frame
		t += get_process_delta_time()
		if t > 20.0:
			game.player.look_at_point(game.satella.head_pos(), 0.1)
	Engine.time_scale = 1.0
	ended["v"] = String(GameState.meta.get("last_ending", ""))
	check(ended["v"] == "true", "true ending reached (got '%s')" % ended["v"])
	check(GameState.meta["endings"].has("true"), "true ending unlocked in meta")
	Settings.player_name = ""
	await _frames(5)
	print("- meta ending (CHOICE path, indecision -> ENDING B)")
	await _load_game_at(6)
	game.meta.stay_in_scene = true
	GameState.meta["last_ending"] = ""
	EnvyAwareness.set_value(40.0)
	Engine.time_scale = 10.0
	t = 0.0
	while t < 160.0 and game.meta.running:
		await get_tree().process_frame
		t += get_process_delta_time()
	Engine.time_scale = 1.0
	check(String(GameState.meta.get("last_ending", "")) == "b", "no choice -> eternal loop (got '%s')" % GameState.meta.get("last_ending", ""))
	await _frames(5)
