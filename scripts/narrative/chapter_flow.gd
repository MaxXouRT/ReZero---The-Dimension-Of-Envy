class_name ChapterFlow
extends Node
## ChapterFlow — the story spine of a run.
## Zones report what happened (seal read, fragment taken, fragments
## inserted...); ChapterFlow decides what the story does next: chapter
## changes, objectives, return points (checkpoints), loop reactions.

var game: Node


func player() -> PlayerController:
	return game.player


# ------------------------------------------------------------------ start / respawn
## Chapter 1 opening: Subaru wakes up in the dark.
func intro() -> void:
	var p := player()
	GameState.set_flag("intro_done")
	ChapterManager.start_chapter(1, false)
	p.lock("intro")
	p.set_look(p.get_yaw(), deg_to_rad(70))
	game.post.fade_from_black(4.0)
	AudioManager.play_2d("breath_in", -8.0)
	await get_tree().create_timer(1.5).timeout
	p.look_at_point(p.global_position + p.forward() * 3.0 + Vector3.UP * 1.4, 2.6)
	await get_tree().create_timer(1.2).timeout
	var c := ChapterManager.get_chapter(1)
	EventBus.chapter_title.emit(1, String(c["title"]), String(c["subtitle"]))
	DialogueManager.say("c1_wake_1", {"delay": 1.5})
	DialogueManager.say("c1_wake_2")
	DialogueManager.say("c1_wake_3")
	await get_tree().create_timer(2.0).timeout
	p.unlock("intro")
	if GameState.has_flag("mem_ng_plus"):
		await get_tree().create_timer(10.0).timeout
		DialogueManager.open_note("note_ng_plus")


## After Return by Death: the loop reacts.
func on_respawn() -> void:
	game.post.fade_from_black(2.2)
	AudioManager.play_2d("rbd_rewind", -4.0)
	EventBus.loop_started.emit(GameState.run["loop"], GameState.deaths())
	var d := GameState.deaths()
	await get_tree().create_timer(2.6).timeout
	match d:
		0, 1:
			pass
		2:
			DialogueManager.say("loop_2", {"direction": -player().forward()})
		3:
			DialogueManager.say("loop_3", {"direction": player().forward()})
		4:
			DialogueManager.say("loop_4", {"direction": -player().forward()})
		5:
			DialogueManager.say("loop_5", {"direction": Vector3.LEFT})
			GameState.set_flag("mem_she_waits")
		_:
			DialogueManager.say("loop_%d" % (6 + (d - 6) % 3), {"direction": -player().forward()})
	# from the 5th death she shows up on purpose, soon, where he has already been
	if d >= 5 and game.satella:
		game.satella.sm.change("DORMANT", {"cooldown": randf_range(14.0, 26.0)})
	if game.chase and GameState.chapter() == 4 and GameState.has_flag("mem_hallway_known") and not GameState.has_flag("hallway_escaped"):
		DialogueManager.say("original_help_1", {"delay": 3.0})


# ------------------------------------------------------------------ chapter 1
func on_seal_read() -> void:
	if GameState.chapter() != 1:
		return
	DialogueManager.say("c1_sigil", {"delay": 1.0})
	await get_tree().create_timer(5.5).timeout
	DialogueManager.say("c1_end_witch", {"direction": -player().forward()})
	AudioManager.play_2d("stinger_2", -12.0)
	await get_tree().create_timer(3.0).timeout
	ChapterManager.start_chapter(2)
	DialogueManager.say("c2_start", {"delay": 4.0})
	_checkpoint_here("ch2_start")


# ------------------------------------------------------------------ fragments
func on_fragment(_zone_id: String, fragment_id: String) -> void:
	if fragment_id == "throne_of_envy":
		to_black_room()
		return
	_checkpoint_here("frag_" + fragment_id)
	match GameState.chapter():
		2:
			var a := GameState.has_fragment("forgotten_bedroom")
			var b := GameState.has_fragment("library_of_memories")
			if a and b:
				ChapterManager.set_objective("obj_insert")
				DialogueManager.say("c2_two_fragments", {"delay": 6.0})
			elif a:
				ChapterManager.set_objective("obj_fragment_2_only")
			elif b:
				ChapterManager.set_objective("obj_fragment_1_only")
		3, 4:
			ChapterManager.set_objective("obj_return_hall")


func on_fragments_inserted() -> void:
	var n := GameState.inserted_count()
	var ch := GameState.chapter()
	if n >= 2 and ch < 3:
		DialogueManager.say("c3_doors_open", {"delay": 0.5})
		AudioManager.play_3d("door_slam", game.world.get_zone("grand_hall").main_door.global_position + Vector3.UP * 2.0, 4.0, 20.0)
		await get_tree().create_timer(3.5).timeout
		ChapterManager.start_chapter(3)
		DialogueManager.say("c3_start", {"delay": 3.5, "direction": -player().forward()})
		_checkpoint_here("ch3_start")
	elif n >= 3 and ch < 4:
		EventBus.world_distortion.emit(1.0, 4.0)
		AudioManager.play_2d("reality_bend", 0.0)
		await get_tree().create_timer(2.0).timeout
		ChapterManager.start_chapter(4)
		DialogueManager.say("c4_start", {"delay": 3.0})
		DialogueManager.say("c4_wing_open", {"delay": 1.0})
		_checkpoint_here("ch4_start")
	elif n >= 4 and ch < 5:
		ChapterManager.start_chapter(5)
		DialogueManager.say("c5_start", {"delay": 3.0, "direction": -player().forward()})
		var hall = game.world.get_zone("grand_hall")
		await get_tree().create_timer(5.0).timeout
		hall.open_pit(true)
		DialogueManager.say("c5_floor_opens", {"delay": 3.2})
		_checkpoint_here("ch5_start")


# ------------------------------------------------------------------ chapter 5
func descend_to_throne() -> void:
	var z: Zone = game.world.get_zone("throne")
	var sp: Dictionary = z.spawn_points["arrival"]
	AudioManager.play_2d("whoosh", 0.0)
	game.transition_teleport(sp["pos"], sp["yaw"], "throne", 1.2)


func to_black_room() -> void:
	var p := player()
	p.lock("to_black")
	AudioManager.play_2d("reality_bend", 2.0)
	EventBus.world_distortion.emit(1.4, 3.0)
	EventBus.screen_glitch.emit(0.8, 2.0)
	if game.satella:
		game.satella.sm.change("DISAPPEARING", {"instant": true})
	await get_tree().create_timer(2.5).timeout
	var z: Zone = game.world.get_zone("black_room")
	var sp: Dictionary = z.spawn_points["arrival"]
	p.unlock("to_black")
	game.transition_teleport(sp["pos"], sp["yaw"], "black_room", 2.5)


# ------------------------------------------------------------------ helpers
func _checkpoint_here(id: String) -> void:
	var p := player()
	if p == null or p.dead:
		return
	GameState.set_checkpoint(id, p.current_zone, p.global_position, p.get_yaw())
	EventBus.toast.emit("Point de retour enregistré")
