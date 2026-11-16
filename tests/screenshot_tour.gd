extends Node
## Visual QA: visits every zone and saves screenshots.
## xvfb-run godot --path . res://tests/screenshot_tour.tscn -- --out=/abs/dir [--only=name]

var out_dir := "user://tour"
var only := ""
var game: Node

const SHOTS := [
	{"name": "01_bedroom", "pos": Vector3(-1.1, 0.05, -0.6), "yaw": 200.0, "pitch": -8.0},
	{"name": "02_corridor", "pos": Vector3(-4.0, 0.05, 5.4), "yaw": -90.0, "pitch": 0.0},
	{"name": "03_hall", "pos": Vector3(34.0, 0.05, 16.5), "yaw": 0.0, "pitch": 8.0},
	{"name": "04_dining", "pos": Vector3(12.0, 0.05, 8.6), "yaw": 180.0, "pitch": -5.0},
	{"name": "05_west_wing", "pos": Vector3(28.0, 0.05, -9.0), "yaw": 0.0, "pitch": 0.0},
	{"name": "06_forgotten", "pos": Vector3(28.0, 0.05, -25.2), "yaw": 0.0, "pitch": -5.0},
	{"name": "07_library", "pos": Vector3(0.0, 0.05, -71.0), "yaw": 0.0, "pitch": 6.0},
	{"name": "08_forest", "pos": Vector3(0.0, 0.05, 192.0), "yaw": 0.0, "pitch": 4.0},
	{"name": "09_chapel", "pos": Vector3(0.0, 0.05, 105.0), "yaw": 0.0, "pitch": 6.0},
	{"name": "10_hallway", "pos": Vector3(100.0, 0.05, 12.0), "yaw": 0.0, "pitch": 0.0},
	{"name": "11_maze", "pos": Vector3(148.0, 0.05, -12.0), "yaw": -90.0, "pitch": 0.0},
	{"name": "12_throne", "pos": Vector3(0.0, -49.9, -207.5), "yaw": 0.0, "pitch": 6.0},
	{"name": "13_satella", "pos": Vector3(34.0, 0.05, 12.0), "yaw": 0.0, "pitch": 4.0, "satella": 2.6},
	{"name": "14_satella_far", "pos": Vector3(-5.5, 0.05, 5.4), "yaw": -90.0, "pitch": 0.0, "satella": 12.0},
]


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.get_slice("=", 1)
		if a.begins_with("--only="):
			only = a.get_slice("=", 1)
	DirAccess.make_dir_recursive_absolute(out_dir)
	EventBus.player_died.connect(func(c): print("PLAYER DIED: ", c, " at ", game.player.global_position))
	EventBus.satella_state_changed.connect(func(s): print("  satella -> ", s))
	GameState.new_game()
	DebugTools.jump_to_chapter(3)
	GameState.run["flags"]["intro_done"] = true
	game = (load("res://scenes/main/game.tscn") as PackedScene).instantiate()
	add_child(game)
	await _frames(30)
	game.satella.autonomous = false
	game.director.cutscene_active = true
	for s in SHOTS:
		if only != "" and not String(s["name"]).contains(only):
			continue
		var p: PlayerController = game.player
		p.teleport_to(s["pos"], deg_to_rad(s["yaw"]))
		p.set_look(deg_to_rad(s["yaw"]), deg_to_rad(s["pitch"]))
		game.world.enter_zone(game.world.zone_at(s["pos"] + Vector3.UP * 0.5))
		p.flashlight.give()
		p.flashlight.set_on(true, true)
		if s.has("satella"):
			var front: Vector3 = s["pos"] + p.forward() * float(s["satella"])
			game.satella.sm.change("INTERACTING", {"pos": front, "pose": SatellaBody.Pose.STILL})
			game.satella.face_toward(s["pos"])
		else:
			game.satella.hide_body()
		await _frames(45)
		var img := get_viewport().get_texture().get_image()
		img.save_png(out_dir.path_join(String(s["name"]) + ".png"))
		print("saved ", s["name"])
	get_tree().quit()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
