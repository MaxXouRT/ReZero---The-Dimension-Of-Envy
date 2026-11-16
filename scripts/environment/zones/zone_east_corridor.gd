extends Zone
## East corridor — longer than it should be.
## Links Subaru's room, the dining room and the grand hall.
## Chapter 2 puzzle "Door Crossing": the Library of Memories hides behind one
## of four doors on the north wall, and moves after every wrong guess. The
## right door ticks like a clock — the player has to LISTEN (3D audio).

const LIB_DOORS_X := [-4.0, 0.5, 5.0, 9.5]
var lib_doors: Array[Door] = []
var _tick_t := 0.0


func _init() -> void:
	display_name = "Couloir est"
	ambience = {"amb_mansion_room": 0.7, "amb_drone_low": 0.2}
	rules = {"follow": true, "manifest": true, "hunt": false, "chase": false, "spot_kinds": ["corridor_end", "doorway"]}


const WINDOWS_X := [-10.5, -7.0, -3.5, 0.0, 3.5, 7.0, 10.5]
const H := 4.0


func build() -> void:
	set_bounds(Vector3(0, 2.8, 0), Vector3(28.6, 5.6, 3.2))
	var openings := [
		{"side": "n", "offset": -8.3, "width": 1.2, "height": 2.3},
		{"side": "n", "offset": -11.0, "width": 1.2, "height": 2.3},
		{"side": "e", "offset": 0.0, "width": 2.4, "height": 3.2},
	]
	for x in LIB_DOORS_X:
		openings.append({"side": "n", "offset": x, "width": 1.2, "height": 2.3})
	for x in WINDOWS_X:
		openings.append({"side": "s", "offset": x, "width": 1.3, "height": 2.9, "bottom": 0.5})
	Builder.room(self, Vector3.ZERO, Vector3(28.6, H, 3.2), {"name": "Corridor", "wall": "panel_cream", "floor": "marble_cream", "openings": openings, "no_ceiling": true, "wainscot": false})
	Builder.vault(self, Vector3(0, H, 0), 3.2 + 0.4, 28.6 + 0.4, true, "plaster_cream", 3.5)
	Builder.runner(self, Vector3.ZERO, 27.6, true, 2.2)
	# pilasters (skipping the doorways) with green lanterns, Re:Zero style
	for i in 8:
		var px := -12.25 + i * 3.5
		Builder.pilaster(self, Vector3(px, 0, 1.6), Vector3(0, 0, -1), H)
		if i % 2 == 0:
			Builder.lantern(self, Vector3(px, 2.5, 1.48), Vector3(0, 0, -1), i != 4)
		var near_door := false
		for dx in [-8.3, -11.0] + LIB_DOORS_X:
			if absf(px - dx) < 0.95:
				near_door = true
		if not near_door:
			Builder.pilaster(self, Vector3(px, 0, -1.6), Vector3(0, 0, 1), H)
			if i % 2 == 1:
				Builder.lantern(self, Vector3(px, 2.5, -1.48), Vector3(0, 0, 1), true)
	# tall windows looking out on the courtyard and the mansion's facade
	for x in WINDOWS_X:
		Builder.tall_window(self, Vector3(x, 0.5, 1.7), 180.0, Vector2(1.3, 2.9), false)
	for x in [-7.0, 0.0, 7.0]:
		# the violet night spills through the glass
		var nl := Builder.light(self, Vector3(x, 2.0, 1.1), Color(0.45, 0.32, 0.85), 0.7, 4.5, false, 0.02)
		nl.flicker_speed = 0.3
	# chandeliers hanging from the vault (most of them dead tonight)
	for cx in [-10.5, -3.5, 3.5, 10.5]:
		Builder.chandelier(self, Vector3(cx, 3.9, 0), 0.55, cx == -3.5 or cx == 10.5, false)
	# benches under the windows, flowers, paintings
	for bx in [-8.75, 1.75, 8.75]:
		Builder.bench(self, Vector3(bx, 0, 1.05), 0.0)
	Builder.vase_table(self, Vector3(7.25, 0, -1.25), 0.0)
	Builder.vase_table(self, Vector3(-13.5, 0, -1.2), 0.0)
	Builder.painting(self, Vector3(7.25, 2.4, -1.57), 0.0, Vector2(0.8, 1.0), 1, 4.0).add_to_group("paintings")
	Builder.painting(self, Vector3(-2.75, 2.5, -1.57), 0.0, Vector2(0.6, 0.8), 4, 8.0).add_to_group("paintings")
	Builder.painting(self, Vector3(-14.15, 2.0, -0.2), 90.0, Vector2(0.9, 1.2), 3, 9.0)
	Builder.grandfather_clock(self, Vector3(-13.6, 0, 0.95), 90.0)
	# A guest-room door that only exists on some loops (rooms vanish between deaths)
	var guest_door_root := Builder.node(self, "GuestDoorVariant")
	Builder.door(guest_door_root, Vector3(-11.0, 0, -1.7), 0.0, {"locked": true, "name": "LockedDoor"})
	var guest_wall_root := Builder.node(self, "GuestWallVariant")
	Builder.box(guest_wall_root, Vector3(1.3, 2.4, 0.22), Vector3(-11.0, 1.2, -1.7), Builder.mat("panel_cream"))
	Builder.painting(guest_wall_root, Vector3(-11.0, 1.75, -1.57), 0.0, Vector2(0.6, 0.8), 3, 21.0)
	if game and game.distortion:
		game.distortion.register("guest_room", [guest_door_root, guest_wall_root], 0)
		game.distortion.pick_for_loop("guest_room")
	else:
		guest_wall_root.visible = false
	# the four "any doors" (north wall, face the corridor = +Z)
	for i in LIB_DOORS_X.size():
		var d := Builder.door(self, Vector3(LIB_DOORS_X[i], 0, -1.7), 0.0, {"locked": GameState.chapter() < 2, "name": "AnyDoor%d" % i})
		d.set_meta("story_door", true)
		d.set_portal(null, _any_door_callable(i))
		lib_doors.append(d)
	Builder.box(self, Vector3(0.5, 0.35, 0.03), Vector3(-6.2, 1.5, -1.58), Builder.mat("gilt"), false)
	readable(Vector3(-6.2, 1.5, -1.45), "note_library_door", "Lire la plaque", false, Vector3(0.6, 0.5, 0.3))
	Pickups.battery(self, Vector3(7.25, 0.88, -1.15), "battery_corridor")
	_build_courtyard()
	# Satella spots (corridor ends, doorways, outside in the courtyard)
	spot(Vector3(13.0, 0, 0), "corridor_end")
	spot(Vector3(-13.2, 0, 0), "corridor_end")
	spot(Vector3(2.0, 0, 9.0), "window")
	spot(Vector3(-4.0, 0, 14.0), "window")
	add_spawn("west_end", Vector3(-12.8, 0.05, 0), -90.0)
	EventBus.chapter_started.connect(func(c):
		if c >= 2:
			for d in lib_doors:
				d.locked = false)


## What you see through the corridor windows: a cobbled courtyard, cone
## topiaries and the main facade of Roswaal's mansion under a starless,
## moonless violet sky.
func _build_courtyard() -> void:
	var c := Builder.node(self, "Courtyard")
	Builder.box(c, Vector3(110, 0.2, 52), Vector3(5, -0.16, 27.5), Builder.mat("cobble"), false)
	Builder.box(c, Vector3(5.0, 0.03, 30), Vector3(2, -0.04, 17), Builder.mat("marble_cream"), false)
	for z in [5.0, 9.5, 14.0, 18.5, 23.0, 27.0]:
		for x in [-1.6, 5.6]:
			Builder.topiary(c, Vector3(x, -0.06, z), 3.4)
		for x in [-12.0, 16.0]:
			Builder.topiary(c, Vector3(x, -0.06, z + 1.5), 2.8)
	for i in 14:
		Builder.sphere(c, 0.8, Vector3(-20.0 + i * 3.2, 0.4, 30.0), Builder.mat("topiary"), Vector3(1.2, 0.8, 1.0))
	Builder.lamp_post(c, Vector3(-0.6, -0.06, 11.5), true)
	Builder.lamp_post(c, Vector3(4.6, -0.06, 20.5), true)
	Builder.lamp_post(c, Vector3(-0.6, -0.06, 20.5), false)
	Builder.lamp_post(c, Vector3(4.6, -0.06, 11.5), false)
	# the main facade, facing the corridor
	Builder.mansion_block(c, Vector3(2, -0.06, 36), Vector3(84, 13, 8))
	Builder.mansion_block(c, Vector3(2, -0.06, 32.0), Vector3(16, 17, 6), 0.0, false)
	Builder.tower(c, Vector3(2, -0.06, 31.0), 2.3, 25.0, 8.0)
	for tx in [-6.5, 10.5]:
		Builder.tower(c, Vector3(tx, -0.06, 30.8), 1.4, 19.0, 6.0)
	for tx in [-36.0, 40.0]:
		Builder.tower(c, Vector3(tx, -0.06, 32.0), 1.8, 18.0, 7.0)
	# entrance arcade and steps
	for ax in [-1.5, 2.0, 5.5]:
		Builder.box(c, Vector3(2.4, 3.0, 0.3), Vector3(ax, 1.4, 28.9), Builder.mat("black"), false)
	for k in 4:
		Builder.box(c, Vector3(12.0 - k * 0.8, 0.18, 1.6 - k * 0.3), Vector3(2, k * 0.18, 28.0 - k * 0.15), Builder.mat("marble_cream"), false)
	# side wings closing the courtyard
	Builder.mansion_block(c, Vector3(-30, -0.06, 17), Vector3(32, 13, 8), -90.0)
	Builder.mansion_block(c, Vector3(26, -0.06, 25), Vector3(22, 13, 8), 90.0)
	Builder.box(c, Vector3(0.1, 12.0, 11.4), Vector3(14.45, 6.0, 7.5), Builder.mat("facade"), false)
	Builder.mark_exterior(c)


func on_enter(_p: PlayerController) -> void:
	if not GameState.has_flag("seen_corridor"):
		GameState.set_flag("seen_corridor")
		DialogueManager.say("c1_corridor", {"delay": 1.5})
	if GameState.chapter() >= 2 and not GameState.has_fragment("library_of_memories") and not GameState.has_flag("hint_any_door"):
		GameState.set_flag("hint_any_door")
		DialogueManager.say("c2_library_listen", {"delay": 2.0})


func _library_index() -> int:
	if not GameState.run["flags"].has("library_door"):
		GameState.set_flag("library_door", randi() % LIB_DOORS_X.size())
	return int(GameState.get_flag("library_door", 0))


func _any_door_callable(i: int) -> Callable:
	return func(body: Node) -> void:
		var p := body as PlayerController
		if p == null:
			return
		if i == _library_index() and GameState.chapter() >= 2:
			var lib: Zone = world.get_zone("library")
			var sp: Dictionary = lib.spawn_points["entrance"]
			game.transition_teleport(sp["pos"], sp["yaw"], "library")
			if not GameState.has_flag("found_library"):
				GameState.set_flag("found_library")
		else:
			# Wrong door: the corridor swallows you and gives you back at its far end.
			var sp2: Dictionary = spawn_points["west_end"]
			game.transition_teleport(sp2["pos"], sp2["yaw"], "east_corridor")
			if GameState.chapter() >= 2:
				var n := LIB_DOORS_X.size()
				GameState.set_flag("library_door", (i + 1 + randi() % (n - 1)) % n)
				if not GameState.has_flag("wrong_door_hint"):
					GameState.set_flag("wrong_door_hint")
					DialogueManager.say("c2_library_wrong", {"delay": 1.0})
				else:
					DialogueManager.say("c2_library_any_door", {"delay": 1.0})


func _process(delta: float) -> void:
	if GameState.chapter() < 2 or GameState.has_fragment("library_of_memories") or not visible:
		return
	_tick_t -= delta
	if _tick_t <= 0.0:
		_tick_t = 1.0
		var d := lib_doors[_library_index()]
		AudioManager.play_3d("clock_tick", d.global_position + Vector3(0, 1.2, -0.2), -6.0, 3.0)
