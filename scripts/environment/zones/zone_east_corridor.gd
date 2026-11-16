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


func build() -> void:
	set_bounds(Vector3(0, 1.8, 0), Vector3(28.6, 3.6, 3.2))
	var openings := [
		{"side": "n", "offset": -8.3, "width": 1.2, "height": 2.3},
		{"side": "s", "offset": 3.7, "width": 1.2, "height": 2.3},
		{"side": "s", "offset": -2.0, "width": 1.2, "height": 2.3},
		{"side": "e", "offset": 0.0, "width": 2.4, "height": 3.2},
	]
	for x in LIB_DOORS_X:
		openings.append({"side": "n", "offset": x, "width": 1.2, "height": 2.3})
	Builder.room(self, Vector3.ZERO, Vector3(28.6, 3.6, 3.2), {"name": "Corridor", "wall": "wallpaper", "floor": "wood_floor", "openings": openings, "beams": false})
	# carpet runner
	Builder.box(self, Vector3(27.5, 0.01, 1.4), Vector3(0, 0.006, 0), Builder.mat("carpet"), false)
	# dining door + a locked door
	var dining_door := Builder.door(self, Vector3(3.7, 0, 1.7), 180.0, {"name": "DiningDoor"})
	dining_door.set_meta("story_door", true)
	Builder.door(self, Vector3(-2.0, 0, 1.7), 180.0, {"locked": true, "name": "LockedDoor"})
	# the four "any doors" (north wall, face the corridor = +Z)
	for i in LIB_DOORS_X.size():
		var d := Builder.door(self, Vector3(LIB_DOORS_X[i], 0, -1.7), 0.0, {"locked": GameState.chapter() < 2, "name": "AnyDoor%d" % i})
		d.set_meta("story_door", true)
		d.set_portal(null, _any_door_callable(i))
		lib_doors.append(d)
	Builder.box(self, Vector3(0.5, 0.35, 0.03), Vector3(-6.2, 1.5, -1.58), Builder.mat("gilt"), false)
	readable(Vector3(-6.2, 1.5, -1.45), "note_library_door", "Lire la plaque", false, Vector3(0.6, 0.5, 0.3))
	# sconces (several dead), paintings, furniture
	var x := -12.0
	var k := 0
	while x <= 12.0:
		var north := k % 2 == 0
		var lit := (k % 3) != 1
		var z := -1.5 if north else 1.5
		Builder.sconce(self, Vector3(x, 2.1, z), Vector3(0, 0, 1 if north else -1), lit, k == 2)
		if k % 2 == 1:
			var c := Builder.painting(self, Vector3(x + 1.8, 1.7, 1.58), 180.0, Vector2(0.7, 0.95), [0, 1, 4, 2][k % 4], float(k))
			c.add_to_group("paintings")
		k += 1
		x += 4.0
	Builder.grandfather_clock(self, Vector3(-13.6, 0, 0.9), 90.0)
	Builder.painting(self, Vector3(-14.15, 1.7, -0.4), 90.0, Vector2(0.9, 1.2), 3, 9.0)
	for tx in [-9.5, 7.5]:
		Builder.box(self, Vector3(0.9, 0.8, 0.4), Vector3(tx, 0.4, 1.35), Builder.mat("wood_dark"))
		Builder.cyl(self, 0.08, 0.12, 0.35, Vector3(tx, 0.98, 1.35), Builder.mat("marble"))
	Builder.window(self, Vector3(12.2, 1.0, 1.7), 180.0, Vector2(1.0, 1.6), true)
	Pickups.battery(self, Vector3(7.5, 0.82, 1.35), "battery_corridor")
	# Satella spots (corridor ends, doorways)
	spot(Vector3(13.0, 0, 0), "corridor_end")
	spot(Vector3(-13.2, 0, 0), "corridor_end")
	spot(Vector3(3.7, 0, 2.6), "doorway")
	add_spawn("west_end", Vector3(-12.8, 0.05, 0), -90.0)
	EventBus.chapter_started.connect(func(c):
		if c >= 2:
			for d in lib_doors:
				d.locked = false)


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
