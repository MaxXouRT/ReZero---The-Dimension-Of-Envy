extends Zone
## Grand hall — the hub of the mansion and of the story.
##  * The SEAL: five sockets carved in the marble. Fragments are placed here;
##    each insertion advances the story (main doors, condemned wing, the void).
##  * The staircase loops back to the ground floor until chapter 4.
##  * One of the windows looks into a room that cannot exist. She waits there.

var sockets: Array[MeshInstance3D] = []
var dais: Node3D
var pit: Node3D
var main_door: Door
var west_door: Door
var _stair_loop_cool := 0.0

const SOCKET_ORDER := ["forgotten_bedroom", "library_of_memories", "chapel_of_envy", "endless_hallway", "throne_of_envy"]


func _init() -> void:
	display_name = "Grand hall"
	ambience = {"amb_mansion_room": 0.55, "amb_void_wind": 0.35, "amb_drone_low": 0.3}
	rules = {"follow": true, "manifest": true, "hunt": true, "chase": true, "spot_kinds": ["balcony", "behind_glass", "room", "mirror"]}


func build() -> void:
	set_bounds(Vector3(0, 5.5, 0), Vector3(22, 11, 26))
	Builder.room(self, Vector3.ZERO, Vector3(22, 11, 26), {
		"name": "Hall", "wall": "wallpaper", "floor": "marble", "ceiling": "plaster", "beams": false,
		"openings": [
			{"side": "w", "offset": 0.0, "width": 2.4, "height": 3.2},
			{"side": "n", "offset": -6.0, "width": 1.2, "height": 2.3},
			{"side": "n", "offset": 0.0, "width": 1.2, "height": 2.3, "bottom": 5.0},
			{"side": "s", "offset": 0.0, "width": 3.0, "height": 4.2},
			{"side": "e", "offset": -6.0, "width": 1.2, "height": 2.3},
			{"side": "e", "offset": 0.0, "width": 1.8, "height": 4.2, "bottom": 1.4},
			{"side": "e", "offset": 6.0, "width": 1.8, "height": 4.2, "bottom": 1.4},
		],
	})
	# carpets
	Builder.runner(self, Vector3(0, 0, 1.5), 22.0, false, 3.2)
	# balcony (mezzanine)
	Builder.box(self, Vector3(22, 0.3, 3.0), Vector3(0, 4.85, -11.5), Builder.mat("wood_floor"), true, Vector3.ZERO, "wood")
	Builder.railing(self, Vector3(-11, 5.0, -10.0), Vector3(-1.9, 5.0, -10.0))
	Builder.railing(self, Vector3(1.9, 5.0, -10.0), Vector3(11, 5.0, -10.0))
	for x in [-9.0, -5.0, 5.0, 9.0]:
		Builder.pillar(self, Vector3(x, 0, -10.0), 4.7, 0.22, "marble")
	# grand staircase up to the balcony
	Builder.stairs(self, Vector3(0, 0, -1.6), 0.0, 3.6, 28, 0.18, 0.3, "carpet")
	# upper door (always refuses to open — "PAS ENCORE")
	var up_door := Builder.door(self, Vector3(0, 5.0, -12.9), 0.0, {"locked": true, "lock_line": "", "name": "UpperDoor"})
	up_door.set_meta("story_door", true)
	Builder.wall_writing(self, Vector3(0, 7.6, -12.85), 0.0, "PAS ENCORE", "witch", 0.18)
	# the doors
	west_door = Builder.door(self, Vector3(-6.0, 0, -12.9), 0.0, {"name": "WestWingDoor"})
	west_door.set_meta("story_door", true)
	main_door = Builder.door(self, Vector3(0, 0, 12.9), 180.0, {"double": true, "width": 3.0, "height": 4.2, "locked": GameState.inserted_count() < 2, "lock_line": "c1_doors_locked", "name": "MainDoor"})
	main_door.set_meta("story_door", true)
	main_door.set_portal(null, _to_forest)
	main_door.on_open = func():
		if not GameState.has_flag("tried_main_doors"):
			GameState.set_flag("tried_main_doors")
	# windows; the north-east one shows the impossible room
	for z in [0.0, 6.0]:
		Builder.window(self, Vector3(11.1, 1.4, z), -90.0, Vector2(1.8, 4.2), true)
	var dining_door := Builder.door(self, Vector3(11.0, 0, -6.0), -90.0, {"name": "DiningDoor"})
	dining_door.set_meta("story_door", true)
	_build_impossible_room()
	# pillars and decoration
	for x in [-8.0, 8.0]:
		for z in [-4.0, 3.0, 9.0]:
			Builder.pillar(self, Vector3(x, 0, z), 11.0, 0.42, "marble")
	Builder.chandelier(self, Vector3(0, 7.5, 2.0), 1.6, true, true)
	Builder.painting(self, Vector3(-10.85, 4.2, -6.0), 90.0, Vector2(1.6, 2.2), 4, 3.0).add_to_group("paintings")
	Builder.painting(self, Vector3(-10.85, 4.2, 6.0), 90.0, Vector2(1.6, 2.2), 5, 3.0).add_to_group("paintings")
	Builder.painting(self, Vector3(6.0, 7.6, -12.85), 0.0, Vector2(1.2, 1.6), 0, 7.0)
	Builder.painting(self, Vector3(-6.0, 7.6, -12.85), 0.0, Vector2(1.2, 1.6), 2, 5.0).add_to_group("paintings")
	for side in [-1.0, 1.0]:
		Builder.statue(self, Vector3(side * 4.0, 0, 11.0), 180.0, true)
		Builder.box(self, Vector3(1.2, 0.9, 0.5), Vector3(side * 10.3, 0.45, -2.0), Builder.mat("wood_dark"))
		Builder.candelabra(self, Vector3(side * 10.3, 0.9, -2.0), side > 0.0)
		Builder.sconce(self, Vector3(side * 10.85, 3.0, 9.5), Vector3(-side, 0, 0), true)
	Builder.fog_volume(self, Vector3(0, 0.6, 0), Vector3(22, 1.4, 26), 0.25)
	# a tall mirror: sometimes she exists only in the reflection
	var mirror := Mirror.new()
	mirror.size = Vector2(1.3, 2.4)
	mirror.position = Vector3(-10.85, 1.6, 0.0)
	mirror.rotation_degrees.y = 90.0
	add_child(mirror)
	Builder.interactable(self, Vector3(-10.5, 1.6, 0.0), Vector3(0.4, 2.2, 1.3), "Regarder le miroir", func(_p):
		if game and game.director:
			game.director.notify("interact:mirror"))
	spot(Vector3(-6.5, 0, 1.5), "mirror")
	spot(Vector3(-7.5, 0, -2.0), "mirror")
	_build_seal()
	readable(Vector3(-10.3, 0.92, -1.8), "note_mirror_original", "Lire", true)
	Pickups.battery(self, Vector3(10.3, 0.92, -1.6), "battery_hall")
	# loop staircase: before chapter 4, reaching the balcony brings you back down
	Builder.trigger(self, Vector3(0, 5.8, -9.8), Vector3(3.6, 1.6, 0.6), _on_stairs_top, false)
	# Satella spots
	spot(Vector3(0, 5.0, -11.8), "balcony")
	spot(Vector3(-7.0, 5.0, -11.8), "balcony")
	spot(Vector3(13.8, 0, 6.0), "behind_glass")
	spot(Vector3(-8.5, 0, 10.5), "room")
	spot(Vector3(8.5, 0, -7.0), "room")
	rules["hunt_points"] = [to_global(Vector3(-8, 0, -8)), to_global(Vector3(8, 0, -8)), to_global(Vector3(8, 0, 10)), to_global(Vector3(-8, 0, 10)), to_global(Vector3(0, 0, 5))]
	add_spawn("center", Vector3(0, 0.05, 6.5), 180.0)
	add_spawn("from_forest", Vector3(0, 0.05, 10.8), 180.0)
	add_spawn("stairs_bottom", Vector3(0, 0.05, -0.6), 0.0)
	add_spawn("from_west", Vector3(-6.0, 0.05, -11.2), 180.0)
	_refresh()
	EventBus.fragment_inserted.connect(func(_id): _refresh())


func _build_impossible_room() -> void:
	# A room behind the east window where there should only be the void.
	var r := Builder.room(self, Vector3(14.2, 0, 6.0), Vector3(5.6, 4.0, 5.0), {"name": "ImpossibleRoom", "wall": "wallpaper_grey", "floor": "wood_floor", "skip": ["w"]})
	r.name = "ImpossibleRoom"
	Builder.bed(r, Vector3(1.2, 0, -0.6), 90.0, "fabric_white", false)
	Builder.chair(r, Vector3(-0.8, 0, 1.2), 200.0)
	Builder.candle(r, Vector3(1.8, 0.0, 1.8), true, true, Color(0.7, 0.5, 1.0), 0.5, 4.0)
	Builder.painting(r, Vector3(2.65, 1.8, 0), -90.0, Vector2(0.8, 1.0), 5, 2.0)


func _build_seal() -> void:
	dais = Builder.node(self, "SealDais", Vector3(0, 0, 4.0))
	Builder.cyl(dais, 2.4, 2.5, 0.16, Vector3(0, 0.08, 0), Builder.mat("stone_dark"), true, 32)
	Builder.cyl(dais, 1.9, 1.9, 0.02, Vector3(0, 0.17, 0), Builder.mat("iron"), false, 32)
	var center := Builder.cyl(dais, 0.5, 0.6, 0.12, Vector3(0, 0.22, 0), Builder.mat("void_stone"), false, 6)
	center.name = "Emblem"
	for i in 5:
		var a := TAU * i / 5.0 - PI / 2.0
		var p := Vector3(cos(a) * 1.45, 0.2, sin(a) * 1.45)
		Builder.cyl(dais, 0.18, 0.2, 0.08, p, Builder.mat("iron"), false, 10)
		var gem := Builder.cyl(dais, 0.0, 0.1, 0.22, p + Vector3(0, 0.12, 0), Builder.mat("black"), false, 5)
		sockets.append(gem)
	var inter := Builder.interactable(dais, Vector3(0, 0.5, 0), Vector3(4.6, 1.0, 4.6), "Examiner le sceau", _on_seal)
	inter.prompt_func = func() -> String:
		if _uninserted().size() > 0:
			return "Placer les fragments dans le sceau (%d)" % _uninserted().size()
		return "Examiner le sceau"
	pit = Builder.node(self, "Pit", Vector3(0, 0, 4.0))
	var hole := Builder.cyl(pit, 2.2, 2.2, 0.02, Vector3(0, 0.02, 0), Builder.mat("black"), false, 32)
	hole.name = "Hole"
	var glow := OmniLight3D.new()
	glow.light_color = Color(0.5, 0.15, 0.8)
	glow.light_energy = 1.5
	glow.omni_range = 6.0
	glow.position = Vector3(0, -0.5, 0)
	pit.add_child(glow)
	Builder.interactable(pit, Vector3(0, 0.4, 0), Vector3(4.0, 0.8, 4.0), "Descendre dans le néant", func(_p):
		if game and game.flow:
			game.flow.descend_to_throne())
	pit.visible = false
	for c in pit.get_children():
		if c is Interactable:
			c.enabled = false


func _uninserted() -> Array:
	var out: Array = []
	for f in GameState.run["fragments_found"]:
		if not GameState.run["fragments_inserted"].has(f) and f != "throne_of_envy":
			out.append(f)
	return out


func _on_seal(_p: Node) -> void:
	if not GameState.has_flag("read_hall_seal"):
		_read("note_hall_seal")
		if game and game.flow:
			game.flow.on_seal_read()
		return
	var todo := _uninserted()
	if todo.is_empty():
		_read("note_hall_seal")
		return
	for f in todo:
		GameState.insert_fragment(f)
		AudioManager.play_3d("seal_insert", dais.global_position + Vector3.UP * 0.5, 2.0, 12.0)
		EventBus.camera_shake.emit(0.25, 0.6)
		await get_tree().create_timer(0.8).timeout
	if game and game.flow:
		game.flow.on_fragments_inserted()


func _refresh() -> void:
	var lit := StandardMaterial3D.new()
	lit.albedo_color = Color(0.6, 0.3, 0.9)
	lit.emission_enabled = true
	lit.emission = Color(0.6, 0.2, 1.0)
	lit.emission_energy_multiplier = 4.0
	for i in SOCKET_ORDER.size():
		sockets[i].material_override = lit if GameState.run["fragments_inserted"].has(SOCKET_ORDER[i]) else Builder.mat("black")
	main_door.locked = GameState.inserted_count() < 2
	if GameState.inserted_count() >= 4:
		open_pit(false)


func open_pit(animated := true) -> void:
	if pit.visible:
		return
	if animated:
		AudioManager.play_3d("reality_bend", dais.global_position, 4.0, 15.0)
		EventBus.world_distortion.emit(1.0, 3.0)
		var tw := create_tween()
		tw.tween_property(dais, "position:y", -3.0, 3.0).set_trans(Tween.TRANS_SINE)
		await tw.finished
	dais.visible = false
	for c in dais.get_children():
		if c is Interactable:
			c.enabled = false
	_disable_collision(dais)
	pit.visible = true
	for c in pit.get_children():
		if c is Interactable:
			c.enabled = true


func _disable_collision(n: Node) -> void:
	if n is CollisionObject3D:
		(n as CollisionObject3D).collision_layer = 0
	for c in n.get_children():
		_disable_collision(c)


func _to_forest(_body: Node) -> void:
	var forest: Zone = world.get_zone("forest")
	var sp: Dictionary = forest.spawn_points["arrival"]
	game.transition_teleport(sp["pos"], sp["yaw"], "forest")


func _on_stairs_top(_body: Node) -> void:
	if GameState.chapter() >= 4:
		if not GameState.has_flag("read_origin_1_hint"):
			GameState.set_flag("read_origin_1_hint")
		return
	if _stair_loop_cool > 0.0:
		return
	_stair_loop_cool = 2.0
	var sp: Dictionary = spawn_points["stairs_bottom"]
	var p := player()
	game.transition_teleport(sp["pos"], p.get_yaw() if p else sp["yaw"], "grand_hall", 0.08)
	if not GameState.has_flag("stairs_looped"):
		GameState.set_flag("stairs_looped")
		DialogueManager.say_text("subaru", "...Je suis de nouveau en bas. Cet escalier ne mène nulle part.", 3.5)


func _process(delta: float) -> void:
	_stair_loop_cool = maxf(0.0, _stair_loop_cool - delta)


func on_enter(_p: PlayerController) -> void:
	if not GameState.has_flag("seen_hall"):
		GameState.set_flag("seen_hall")
		DialogueManager.say("c1_hall", {"delay": 1.0})
		if GameState.chapter() == 1:
			ChapterManager.set_objective("obj_exit")
