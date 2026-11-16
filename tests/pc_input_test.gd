extends Node
## QA: real keyboard / mouse events on PC (run with a display: xvfb-run).
## xvfb-run godot --path . res://tests/pc_input_test.tscn

var fails := 0


func check(c: bool, label: String) -> void:
	print(("  ok   " if c else "  FAIL ") + label)
	if not c:
		fails += 1


func key(code: Key, pressed: bool) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.keycode = code
	e.pressed = pressed
	Input.parse_input_event(e)


func press(code: Key) -> void:
	key(code, true)
	await get_tree().process_frame
	await get_tree().process_frame
	key(code, false)
	for i in 3:
		await get_tree().process_frame


func click(pos: Vector2) -> void:
	var wpos := get_tree().root.get_final_transform() * pos
	for pressed in [true, false]:
		var m := InputEventMouseButton.new()
		m.button_index = MOUSE_BUTTON_LEFT
		m.pressed = pressed
		m.position = wpos
		m.global_position = wpos
		Input.parse_input_event(m)
		await get_tree().process_frame
		await get_tree().process_frame


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
	Settings.first_launch_done = true
	check(not Settings.is_mobile(), "PC mode")
	var lobby: Node = (load("res://scenes/ui/lobby.tscn") as PackedScene).instantiate()
	add_child(lobby)
	await get_tree().create_timer(2.5).timeout
	var sb := find_button(lobby, "SETTINGS")
	await click(sb.get_global_rect().get_center())
	await get_tree().create_timer(0.3).timeout
	check(find_button(lobby, "← Retour") != null, "mouse click on SETTINGS opens settings")
	await press(KEY_ESCAPE)
	await get_tree().create_timer(0.3).timeout
	check(find_button(lobby, "← Retour") == null, "Escape closes settings")
	var ex := find_button(lobby, "EXTRAS")
	await click(ex.get_global_rect().get_center())
	await get_tree().create_timer(0.3).timeout
	var back := find_button(lobby, "← Retour")
	check(back != null, "EXTRAS panel opens")
	if back:
		await click(back.get_global_rect().get_center())
	lobby.queue_free()
	await get_tree().process_frame
	GameState.new_game()
	GameState.run["flags"]["intro_done"] = true
	var game: Node = (load("res://scenes/main/game.tscn") as PackedScene).instantiate()
	add_child(game)
	await get_tree().create_timer(4.0).timeout
	var p: PlayerController = game.player
	check(game.touch == null, "no touch controls on PC")
	game.satella.autonomous = false
	game.director.cutscene_active = true
	# keyboard movement (physical keys: Z/W, Q/A, S, D)
	p.teleport_to(Vector3(-2.5, 0.05, -0.2), -PI * 0.5)
	await get_tree().create_timer(0.3).timeout
	var p0 := p.global_position
	key(KEY_W, true)
	await get_tree().create_timer(0.8).timeout
	key(KEY_W, false)
	await get_tree().create_timer(0.3).timeout
	var walked := p.global_position.distance_to(p0)
	check(walked > 1.0, "W / Z walks forward (%.2f m)" % walked)
	p0 = p.global_position
	key(KEY_W, true)
	key(KEY_SHIFT, true)
	await get_tree().create_timer(0.5).timeout
	key(KEY_SHIFT, false)
	key(KEY_W, false)
	await get_tree().create_timer(0.2).timeout
	check(p.global_position.distance_to(p0) > walked * 0.75, "Shift sprints")
	# mouse look (captured)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	await get_tree().process_frame
	var yaw0 := p.get_yaw()
	for i in 10:
		var mm := InputEventMouseMotion.new()
		mm.relative = Vector2(25, 0)
		Input.parse_input_event(mm)
		await get_tree().process_frame
	check(absf(p.get_yaw() - yaw0) > 0.2, "mouse motion turns the camera")
	# flashlight / crouch / journal / pause
	p.flashlight.give()
	var was := p.flashlight.on
	await press(KEY_F)
	check(p.flashlight.on != was, "F toggles the flashlight")
	key(KEY_C, true)
	await get_tree().create_timer(0.6).timeout
	check(p._height < 1.4, "C crouches")
	key(KEY_C, false)
	await get_tree().create_timer(0.6).timeout
	await press(KEY_TAB)
	check(game.journal.is_open, "Tab opens the journal")
	await press(KEY_TAB)
	check(not game.journal.is_open, "Tab closes the journal")
	await press(KEY_ESCAPE)
	check(game.pause_menu.is_open, "Escape opens pause")
	await press(KEY_ESCAPE)
	check(not game.pause_menu.is_open and not get_tree().paused, "Escape resumes")
	# E interacts: open the bedroom door from inside
	var door: Door = game.world.get_zone("bedroom").get_node("BedroomDoor")
	p.teleport_to(Vector3(0, 0.05, 2.3), PI)
	p.set_look(PI, -0.1)
	await get_tree().create_timer(0.4).timeout
	await press(KEY_E)
	await get_tree().create_timer(0.3).timeout
	check(door.is_open, "E opens the door in front")
	print("=== PC input test: %d failure(s) ===" % fails)
	get_tree().quit(1 if fails else 0)
