extends Node
## Visual QA: captures the Return by Death screen mid-sequence.
func _ready() -> void:
	SaveManager.use_sandbox()
	GameState.new_game()
	DebugTools.jump_to_chapter(3)
	GameState.run["flags"]["intro_done"] = true
	var g: Node = (load("res://scenes/main/game.tscn") as PackedScene).instantiate()
	add_child(g)
	await get_tree().create_timer(2.0).timeout
	GameState.register_death("x")
	GameState.register_death("y")
	GameState.register_death("z")
	g.player.die("test")
	await get_tree().create_timer(1.1).timeout
	get_viewport().get_texture().get_image().save_png(OS.get_cmdline_user_args()[0] + "/death_a.png")
	await get_tree().create_timer(3.4).timeout
	get_viewport().get_texture().get_image().save_png(OS.get_cmdline_user_args()[0] + "/death_b.png")
	print("saved death")
	get_tree().quit()
