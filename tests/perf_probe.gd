extends Node
## Relative performance probe: average FPS at a fixed viewpoint per preset.
## xvfb-run godot --path . --rendering-method gl_compatibility --rendering-driver opengl3 res://tests/perf_probe.tscn -- --preset=0
func _ready() -> void:
	SaveManager.use_sandbox()
	var preset := 2
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--preset="):
			preset = int(a.get_slice("=", 1))
	Settings._preset_values(preset)
	Settings.fps_limit = 0
	Settings.vsync = false
	for a in OS.get_cmdline_user_args():
		if a == "--nopost": Settings.post_process = false
		if a == "--noshadow": Settings.shadow_quality = 0
		if a == "--nolights": Settings.light_distance = 1.0
	Settings.apply_display()
	GameState.new_game()
	DebugTools.jump_to_chapter(3)
	GameState.run["flags"]["intro_done"] = true
	var g: Node = (load("res://scenes/main/game.tscn") as PackedScene).instantiate()
	add_child(g)
	await get_tree().create_timer(2.0).timeout
	g.player.teleport_to(Vector3(-4.0, 0.05, 5.4), deg_to_rad(-90))
	g.world.enter_zone("east_corridor")
	g.player.flashlight.give()
	g.player.flashlight.set_on(true, true)
	g.satella.autonomous = false
	g.director.cutscene_active = true
	await get_tree().create_timer(2.0).timeout
	var f0 := Engine.get_frames_drawn()
	var t0 := Time.get_ticks_msec()
	await get_tree().create_timer(6.0).timeout
	var fps := (Engine.get_frames_drawn() - f0) * 1000.0 / float(Time.get_ticks_msec() - t0)
	print("PRESET %d %s -> %.1f FPS" % [preset, str(OS.get_cmdline_user_args()), fps])
	get_tree().quit()
