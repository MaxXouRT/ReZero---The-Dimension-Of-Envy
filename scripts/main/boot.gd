extends Node
## Boot: applies settings, then opens the lobby (the 3D main menu).
## Command line (debug): --quickstart  -> straight into a new game.
##                       --chapter=N   -> new game jumped to chapter N (QA).


func _ready() -> void:
	Settings.apply_display()
	var args := OS.get_cmdline_user_args() + OS.get_cmdline_args()
	for a in args:
		if a == "--quickstart":
			GameState.new_game()
			get_tree().change_scene_to_file.call_deferred("res://scenes/main/game.tscn")
			return
		if a.begins_with("--chapter="):
			GameState.new_game()
			GameState.debug_mode = true
			DebugTools.jump_to_chapter(int(a.get_slice("=", 1)))
			get_tree().change_scene_to_file.call_deferred("res://scenes/main/game.tscn")
			return
	get_tree().change_scene_to_file.call_deferred("res://scenes/ui/lobby.tscn")
