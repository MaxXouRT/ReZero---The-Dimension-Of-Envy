extends Zone
## West wing — the condemned wing.
## Chapter 2: "Forgotten rooms only exist when nobody looks at them."
##   The north end is a dead end. After reading the hint, the player must
##   turn his back on it: when he looks again, the door has come back.
## Chapter 4: the boarded door on the west wall gives way -> Endless Hallway.

var fake_wall: Node3D
var forgotten_door: Door
var forgotten_root: Node3D
var boards: Node3D
var hallway_door: Door
var _away_time := 0.0


func _init() -> void:
	display_name = "Aile ouest"
	ambience = {"amb_mansion_room": 0.5, "amb_drone_low": 0.4, "amb_void_wind": 0.2}
	rules = {"follow": true, "manifest": true, "hunt": false, "chase": true, "spot_kinds": ["corridor_end"]}


func build() -> void:
	set_bounds(Vector3(0, 1.8, 0), Vector3(3.2, 3.6, 16.2))
	Builder.room(self, Vector3.ZERO, Vector3(3.2, 3.6, 16.2), {"name": "WestWing", "wall": "wallpaper_grey", "floor": "wood_floor", "openings": [
		{"side": "s", "offset": 0.0, "width": 1.2, "height": 2.3},
		{"side": "n", "offset": 0.0, "width": 1.2, "height": 2.3},
		{"side": "w", "offset": -2.0, "width": 1.2, "height": 2.3},
		{"side": "e", "offset": 3.0, "width": 1.2, "height": 2.3},
	]})
	# the condemned look: debris, broken chairs, crooked paintings, boards
	Builder.debris(self, Vector3(0.3, 0, 2.5), 1.0, 12, 3)
	Builder.debris(self, Vector3(-0.2, 0, -4.0), 1.2, 9, 11)
	Builder.chair(self, Vector3(0.9, 0, -1.0), 30.0, true)
	Builder.boards(self, Vector3(1.6, 0, 3.0), -90.0)
	Builder.painting(self, Vector3(1.55, 1.8, -3.5), -90.0, Vector2(0.7, 0.9), 3, 2.0)
	Builder.painting(self, Vector3(-1.55, 1.8, 5.5), 90.0, Vector2(0.7, 0.9), 2, 8.0).add_to_group("paintings")
	for z in [6.0, 0.0, -6.0]:
		Builder.sconce(self, Vector3(-1.45, 2.1, z), Vector3(1, 0, 0), z == 6.0)
	# Forgotten bedroom door (north end) + the wall that hides it
	forgotten_root = Builder.node(self, "ForgottenDoorRoot")
	forgotten_door = Builder.door(forgotten_root, Vector3(0, 0, -8.1), 180.0, {"name": "ForgottenDoor"})
	forgotten_door.set_meta("story_door", true)
	fake_wall = Builder.node(self, "FakeWall")
	Builder.box(fake_wall, Vector3(1.3, 2.4, 0.22), Vector3(0, 1.2, -8.1), Builder.mat("wallpaper_grey"))
	Builder.box(fake_wall, Vector3(1.3, 1.05, 0.04), Vector3(0, 0.525, -7.97), Builder.mat("wainscot"), false)
	if game and game.distortion:
		game.distortion.register("forgotten_door", [fake_wall, forgotten_root], 1 if GameState.has_flag("forgotten_door_open") else 0)
	readable(Vector3(0.6, 0.02, -6.5), "note_forgotten_hint", "Ramasser le mot")
	# Endless Hallway door (west wall), boarded until chapter 4
	hallway_door = Builder.door(self, Vector3(-1.7, 0, -2.0), 90.0, {"locked": true, "lock_line": "", "name": "HallwayDoor"})
	hallway_door.set_meta("story_door", true)
	hallway_door.set_portal(null, _to_hallway)
	boards = Builder.boards(self, Vector3(-1.55, 0, -2.0), 90.0)
	if GameState.chapter() >= 4:
		open_hallway(false)
	EventBus.chapter_started.connect(func(c):
		if c >= 4:
			open_hallway(true))
	spot(Vector3(0, 0, -7.2), "corridor_end")
	spot(Vector3(0, 0, 7.2), "corridor_end")
	add_spawn("from_hallway", Vector3(-0.6, 0.05, -2.0), -90.0)
	add_spawn("from_forgotten", Vector3(0, 0.05, -6.8), 0.0)


func open_hallway(animated: bool) -> void:
	hallway_door.locked = false
	if boards and is_instance_valid(boards):
		if animated:
			AudioManager.play_3d("door_slam", boards.global_position + Vector3.UP, 2.0, 12.0)
		boards.queue_free()
		boards = null
	Builder.wall_writing(self, Vector3(-1.5, 2.6, -2.0), 90.0, "ENTRE", "witch", 0.12)


func _to_hallway(_b: Node) -> void:
	var z: Zone = world.get_zone("endless_hallway")
	var sp: Dictionary = z.spawn_points["arrival"]
	game.transition_teleport(sp["pos"], sp["yaw"], "endless_hallway")


func _process(delta: float) -> void:
	if not visible or GameState.chapter() < 2 or GameState.has_flag("forgotten_door_open"):
		return
	if not GameState.has_flag("read_forgotten_hint"):
		return
	var p := player()
	if p == null or p.current_zone != zone_id:
		return
	var end := to_global(Vector3(0, 1.2, -8.0))
	if p.is_in_frustum(end):
		_away_time = 0.0
		return
	_away_time += delta
	if _away_time > 2.0:
		GameState.set_flag("forgotten_door_open")
		game.distortion.request("forgotten_door", 1)
		AudioManager.play_3d("creak", end, 0.0, 6.0, 0.8)
		DialogueManager.say("c2_door_appears", {"delay": 1.5})


func on_enter(_p: PlayerController) -> void:
	if GameState.chapter() >= 2 and not GameState.has_flag("forgotten_door_open") and not GameState.has_flag("wing_dead_end_line"):
		GameState.set_flag("wing_dead_end_line")
		DialogueManager.say("c2_dead_end", {"delay": 3.0})
