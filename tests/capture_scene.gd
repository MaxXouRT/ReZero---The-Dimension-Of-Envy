extends Node
## Visual QA helper: runs a scene for N seconds and saves a screenshot.
## xvfb-run godot --path . res://tests/capture_scene.tscn -- --scene=res://scenes/ui/lobby.tscn --time=6 --out=/abs/file.png [--visits=3] [--true]

func _ready() -> void:
	var scene := "res://scenes/ui/lobby.tscn"
	var t := 5.0
	var out := "user://capture.png"
	SaveManager.use_sandbox()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--scene="):
			scene = a.get_slice("=", 1)
		elif a.begins_with("--time="):
			t = float(a.get_slice("=", 1))
		elif a.begins_with("--out="):
			out = a.get_slice("=", 1)
		elif a.begins_with("--visits="):
			GameState.meta["lobby_visits"] = int(a.get_slice("=", 1)) - 1
		elif a == "--true":
			GameState.meta["true_ending_seen"] = true
			Settings.player_name = "Mika"
	Settings.first_launch_done = true
	var n: Node = (load(scene) as PackedScene).instantiate()
	add_child(n)
	await get_tree().create_timer(t).timeout
	get_viewport().get_texture().get_image().save_png(out)
	print("saved ", out)
	get_tree().quit()
