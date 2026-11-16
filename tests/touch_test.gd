extends Node
## QA: simulates a phone (real InputEventScreenTouch / ScreenDrag events).
## godot --headless --path . res://tests/touch_test.tscn -- --mobile

var fails := 0


func check(c: bool, label: String) -> void:
	print(("  ok   " if c else "  FAIL ") + label)
	if not c:
		fails += 1


## Viewport (UI) coordinates -> window coordinates, like a real finger.
func w(pos: Vector2) -> Vector2:
	return get_tree().root.get_final_transform() * pos


func tap(pos: Vector2) -> void:
	var d := InputEventScreenTouch.new()
	d.index = 0
	d.position = w(pos)
	d.pressed = true
	Input.parse_input_event(d)
	await get_tree().process_frame
	await get_tree().process_frame
	var u := InputEventScreenTouch.new()
	u.index = 0
	u.position = w(pos)
	u.pressed = false
	Input.parse_input_event(u)
	for i in 3:
		await get_tree().process_frame


func tap_control(c: Control) -> void:
	await tap(c.get_global_rect().get_center())


func find_button(root: Node, text: String) -> Button:
	if root is Button and (root as Button).text == text and (root as Button).is_visible_in_tree():
		return root
	for ch in root.get_children():
		var b := find_button(ch, text)
		if b:
			return b
	return null


func _ready() -> void:
	SaveManager.use_sandbox()
	SaveManager.delete_save()
	Settings.first_launch_done = false
	check(Settings.is_mobile(), "mobile mode simulated")
	check(ProjectSettings.get_setting("input_devices/pointing/emulate_mouse_from_touch"), "touch -> mouse emulation enabled")
	var lobby: Node = (load("res://scenes/ui/lobby.tscn") as PackedScene).instantiate()
	add_child(lobby)
	await get_tree().create_timer(1.0).timeout
	# first launch: name prompt -> "Passer"
	var skip := find_button(lobby, "Passer")
	check(skip != null, "name prompt shown")
	if skip:
		await tap_control(skip)
	check(Settings.first_launch_done, "tap on 'Passer' works")
	var settings_b := find_button(lobby, "SETTINGS")
	await tap_control(settings_b)
	await get_tree().create_timer(0.3).timeout
	var back := find_button(lobby, "← Retour")
	check(back != null, "tap on SETTINGS opens settings")
	if back:
		await tap_control(back)
	await get_tree().create_timer(0.3).timeout
	var newg := find_button(lobby, "NEW GAME")
	check(newg != null and newg.is_visible_in_tree(), "back to menu")
	# start a game directly (scene change would replace this test node)
	lobby.queue_free()
	GameState.new_game()
	GameState.run["flags"]["intro_done"] = true
	var game: Node = (load("res://scenes/main/game.tscn") as PackedScene).instantiate()
	add_child(game)
	await get_tree().create_timer(1.0).timeout
	check(game.touch != null, "touch controls created in game")
	var p: PlayerController = game.player
	var vs := get_viewport().get_visible_rect().size
	# joystick: press left side, drag up
	var start := Vector2(vs.x * 0.15, vs.y * 0.75)
	var d := InputEventScreenTouch.new()
	d.index = 1
	d.position = w(start)
	d.pressed = true
	Input.parse_input_event(d)
	await get_tree().process_frame
	var pos0 := p.global_position
	for i in 30:
		var dr := InputEventScreenDrag.new()
		dr.index = 1
		dr.position = w(start + Vector2(0, -min(110, i * 8)))
		dr.relative = w(Vector2(0, -8)) - w(Vector2.ZERO)
		Input.parse_input_event(dr)
		await get_tree().physics_frame
	await get_tree().create_timer(0.6).timeout
	check(p.touch_move.length() > 0.5, "joystick drives movement input (%s)" % str(p.touch_move))
	check(p.global_position.distance_to(pos0) > 0.5, "player walked (%.2f m)" % p.global_position.distance_to(pos0))
	var u := InputEventScreenTouch.new()
	u.index = 1
	u.position = w(start)
	u.pressed = false
	Input.parse_input_event(u)
	await get_tree().process_frame
	check(p.touch_move == Vector2.ZERO, "joystick released")
	# look: drag on the right side
	var yaw0 := p.get_yaw()
	var lstart := Vector2(vs.x * 0.6, vs.y * 0.4)
	var t := InputEventScreenTouch.new()
	t.index = 2
	t.position = w(lstart)
	t.pressed = true
	Input.parse_input_event(t)
	for i in 15:
		var dr2 := InputEventScreenDrag.new()
		dr2.index = 2
		dr2.position = w(lstart + Vector2(i * 10, 0))
		dr2.relative = w(Vector2(10, 0)) - w(Vector2.ZERO)
		Input.parse_input_event(dr2)
		await get_tree().process_frame
	t.pressed = false
	Input.parse_input_event(t)
	check(absf(p.get_yaw() - yaw0) > 0.2, "drag right side turns the camera")
	# a random tap must NOT interact
	var interacted := {"n": 0}
	# buttons
	var lamp := find_button(game.touch, "LAMPE")
	p.flashlight.give()
	var was := p.flashlight.on
	await tap_control(lamp)
	check(p.flashlight.on != was, "LAMPE button toggles flashlight")
	var jb := find_button(game.touch, "JOURNAL")
	await tap_control(jb)
	check(game.journal.is_open, "JOURNAL button opens the journal")
	var close := find_button(game.journal, "← Fermer")
	await tap_control(close)
	check(not game.journal.is_open, "journal closes by tap")
	var pb := find_button(game.touch, "II")
	await tap_control(pb)
	check(game.pause_menu.is_open, "II button opens pause")
	var resume := find_button(game.pause_menu, "Reprendre")
	await tap_control(resume)
	check(not game.pause_menu.is_open and not get_tree().paused, "Reprendre by tap")
	game.pause_menu._notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	check(game.pause_menu.is_open, "Android back button opens pause")
	game.pause_menu.close()
	print("=== touch test: %d failure(s) ===" % fails)
	get_tree().quit(1 if fails else 0)
