class_name MetaEndingController
extends Node
## THE ONE BEHIND THE SCREEN — the fourth-wall confrontation and the endings.
##
## Step 1  "Pourquoi est-ce que tu ne me regardes jamais ?"
## Step 2  "Tu n'es pas Subaru."  (the name SUBARU glitches on screen)
## Step 3  "Quelqu'un te contrôle..." (an in-game cursor moves by itself,
##          her hand presses against the "glass" of the screen)
## Step 4  (TRUE path, Envy Awareness = 100) she says the name the player
##          chose at first launch — or notices they never gave one.
## Step 5  illusion of control: scripted camera, the pause menu replaced by
##          a narrative interface, fictional "PLAYER DETECTED" UI.
## Otherwise: a choice between endings A (Escape), B (Eternal Loop) and
## C (The Real Satella, if enough silver messages were read).
##
## SAFETY: everything here is staged inside the game window. The only
## personal data used is the optional display name typed in the game.
## No files, accounts or system information are read; the "hacking" is
## purely visual and audio fiction; the game never controls the real PC.

var game: Node
var zone: Zone
var running := false
var ui: Control
var big_label: Label
var choice_panel: PanelContainer
var _choice := ""
var _fake_pause_busy := false
var stay_in_scene := false     ## QA: do not load the credits scene


func start(z: Zone) -> void:
	if running:
		return
	running = true
	zone = z
	ui = Control.new()
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.theme = UITheme.get_theme()
	game.overlay.root.add_child(ui)
	big_label = UITheme.label("", 72, UITheme.WHITE)
	big_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	big_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	big_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	big_label.modulate.a = 0.0
	big_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(big_label)
	game.director.cutscene_active = true
	game.pause_menu.locked = true
	EnvyAwareness.suspend_stare = true
	_run()


func _unhandled_input(event: InputEvent) -> void:
	if running and event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		_fake_pause()


## The pause menu is replaced by a narrative interface.
func _fake_pause() -> void:
	if _fake_pause_busy:
		return
	_fake_pause_busy = true
	var panel := PanelContainer.new()
	panel.anchor_left = 0.06
	panel.anchor_top = 0.18
	panel.anchor_right = 0.4
	panel.anchor_bottom = 0.6
	ui.add_child(panel)
	var vb := VBoxContainer.new()
	panel.add_child(vb)
	vb.add_child(UITheme.label("PAUSE", 38, UITheme.WHITE))
	for t in ["Reprendre", "Paramètres", "Menu principal"]:
		vb.add_child(UITheme.label(t, 26, Color(0.3, 0.28, 0.33)))
	AudioManager.play_2d("glitch", -2.0)
	await get_tree().create_timer(0.9).timeout
	DialogueManager.say("meta_pause")
	for c in vb.get_children():
		if c is Label:
			c.text = "NON"
			c.add_theme_color_override("font_color", UITheme.WITCH)
	EventBus.screen_glitch.emit(0.6, 0.6)
	await get_tree().create_timer(1.8).timeout
	await game.overlay.tear_screen([panel])
	panel.queue_free()
	EnvyAwareness.add(2.0, "meta_pause")
	_fake_pause_busy = false


func _sat() -> SatellaAI:
	return game.satella


func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout


func _say(ids: Array) -> void:
	for id in ids:
		DialogueManager.say(String(id), {"position": _sat().head_pos()})
	while DialogueManager.is_busy():
		await get_tree().process_frame


func _show_big(text: String, color: Color, hold := 1.5) -> void:
	big_label.text = text
	big_label.add_theme_color_override("font_color", color)
	var tw := create_tween()
	tw.tween_property(big_label, "modulate:a", 1.0, 0.6)
	tw.tween_interval(hold)
	tw.tween_property(big_label, "modulate:a", 0.0, 0.8)
	await tw.finished


func _run() -> void:
	var p: PlayerController = game.player
	var sat := _sat()
	AudioManager.set_music_mode("silent")
	sat.autonomous = false
	sat.sm.change("INTERACTING", {"pos": zone.to_global(Vector3.ZERO), "pose": SatellaBody.Pose.STILL, "persona": "witch"})
	sat.face_toward(p.global_position)
	sat.body.set_face_lit(0.4)
	p.flashlight.set_on(false, true)
	p.movement_locked = true
	await _wait(2.0)
	# she makes him come closer
	p.lock("meta_walk")
	p.look_at_point(sat.head_pos(), 1.5)
	await _wait(1.0)
	p.unlock("meta_walk")
	p.scripted_walk(sat.global_position - p.global_position, 1.1, 3.6)
	await _wait(4.0)
	# ---------------------------------------------------------------- step 1
	var looked_away := _watch_gaze()
	await _say(["meta_1a"])
	await _wait(1.2)
	await _say(["meta_1b"])
	EnvyAwareness.add(8.0, "meta_step1", 100.0)
	await _wait(1.5)
	# ---------------------------------------------------------------- step 2
	sat.body.head_tilt = 0.5
	AudioManager.play_2d("reality_bend", -2.0)
	await _say(["meta_2a"])
	EventBus.screen_glitch.emit(0.5, 1.0)
	await _say(["meta_2b"])
	await _glitch_name()
	await _say(["meta_2c", "meta_2d"])
	EventBus.world_distortion.emit(0.8, 3.0)
	await _say(["meta_2e"])
	EnvyAwareness.add(8.0, "meta_step2", 100.0)
	await _wait(1.0)
	# ---------------------------------------------------------------- step 3
	sat.body.head_tilt = 0.0
	await _say(["meta_3a"])
	game.overlay.show_fake_cursor(true)
	var vs := get_viewport().get_visible_rect().size
	await game.overlay.move_fake_cursor(vs * Vector2(0.5, 0.45), 2.2)
	await _say(["meta_cursor"])
	await game.overlay.move_fake_cursor(vs * Vector2(0.52, 0.47), 0.6)
	game.overlay.show_fake_cursor(false)
	await _say(["meta_3b"])
	# she steps closer, to the glass
	var tw := create_tween()
	var front := p.global_position + (sat.global_position - p.global_position).normalized() * 1.1
	tw.tween_property(sat, "global_position", Vector3(front.x, sat.global_position.y, front.z), 2.5).set_trans(Tween.TRANS_SINE)
	await tw.finished
	sat.body.set_pose(SatellaBody.Pose.REACH)
	p.lock("meta")
	p.look_at_point(sat.head_pos(), 0.8)
	await _say(["meta_3c"])
	await _glass_hand()
	await _say(["meta_3d"])
	EnvyAwareness.add(8.0, "meta_step3", 100.0)
	if looked_away["count"] > 0:
		EnvyAwareness.add(4.0, "meta_never_looked", 100.0)
	await _wait(1.0)
	# ---------------------------------------------------------------- decision
	if EnvyAwareness.value() >= 100.0:
		await _true_path()
	else:
		await _choice_path()


## Gently turns the camera back to her if the player looks away (illusion of control).
func _watch_gaze() -> Dictionary:
	var state := {"count": 0}
	_gaze_loop(state)
	return state


func _gaze_loop(state: Dictionary) -> void:
	var away := 0.0
	while running and not game.player.is_input_locked():
		await get_tree().process_frame
		var p: PlayerController = game.player
		if p.look_dot(_sat().head_pos()) < 0.75:
			away += get_process_delta_time()
			if away > 1.6:
				away = 0.0
				state["count"] += 1
				p.look_at_point(_sat().head_pos(), 1.2)
		else:
			away = 0.0


func _glitch_name() -> void:
	big_label.text = "SUBARU"
	big_label.add_theme_color_override("font_color", UITheme.WHITE)
	big_label.modulate.a = 1.0
	AudioManager.play_2d("glitch", 0.0)
	var variants := ["SUBARU", "SUB?RU", "S??A?U", "?????", "SUBARU", "N̷O̷T̷", "??????"]
	for v in variants:
		big_label.text = v
		EventBus.screen_glitch.emit(0.4, 0.15)
		await _wait(0.18)
	big_label.text = "???"
	big_label.add_theme_color_override("font_color", UITheme.WITCH)
	await _wait(1.0)
	var tw := create_tween()
	tw.tween_property(big_label, "modulate:a", 0.0, 0.6)
	await tw.finished


## Her palm pressed against the inside of the screen, cracks spreading.
func _glass_hand() -> void:
	var hand := _GlassHand.new()
	hand.set_anchors_preset(Control.PRESET_FULL_RECT)
	hand.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(hand)
	AudioManager.play_2d("glass_crack", 2.0)
	EventBus.camera_shake.emit(0.4, 0.4)
	var tw := create_tween()
	tw.tween_property(hand, "crack", 1.0, 1.5)
	await tw.finished
	await _wait(1.5)
	var tw2 := create_tween()
	tw2.tween_property(hand, "modulate:a", 0.0, 1.0)
	await tw2.finished
	hand.queue_free()


# -------------------------------------------------------------------- TRUE
func _true_path() -> void:
	var sat := _sat()
	AudioManager.play_2d("thump", 2.0)
	if Settings.has_custom_name():
		await _show_big(Settings.get_display_name(), UITheme.WITCH, 0.6)
		await _say(["meta_4a", "meta_4b"])
	else:
		await _say(["meta_4a_noname", "meta_4b_noname"])
	await _say(["meta_4c", "meta_4d"])
	await _say(["meta_deaths" if GameState.deaths() > 0 else "meta_deaths_zero"])
	# RENDS-LE-MOI.
	DialogueManager.say("meta_4e")
	await game.overlay.face_jumpscare(true)
	await _wait(1.2)
	# ---------------------------------------------------------------- step 5: illusion of control
	await _player_detected_ui()
	sat.body.set_pose(SatellaBody.Pose.STILL)
	sat.body.head_tilt = 0.3
	await _say(["meta_4f"])
	await game.post.fade_to_black(2.5)
	await _say(["end_true_1", "end_true_2"])
	_finish("true")


func _player_detected_ui() -> void:
	var panel := PanelContainer.new()
	panel.anchor_left = 0.25
	panel.anchor_right = 0.75
	panel.anchor_top = 0.3
	panel.anchor_bottom = 0.7
	ui.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	panel.add_child(vb)
	var console := UITheme.label("", 20, Color(0.7, 0.6, 0.85))
	console.add_theme_font_override("font", UITheme.mono())
	console.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(console)
	var who := Settings.get_display_name() if Settings.has_custom_name() else "[inconnu]"
	var lines := [
		"> ENVY AWARENESS ............ 100",
		"> sujet : SUBARU NATSUKI ..... non conforme",
		"> contrôle externe .......... détecté",
		"> présence derrière l'écran .. confirmée",
		"> identifiant ................ " + who,
		"",
		"PLAYER DETECTED",
	]
	for l in lines:
		console.text += l + "\n"
		AudioManager.play_2d("clock_tick", -4.0)
		await _wait(0.55)
	EventBus.screen_glitch.emit(0.8, 1.2)
	AudioManager.play_2d("static", -2.0)
	await _wait(1.6)
	await game.overlay.tear_screen([panel])
	panel.queue_free()


# -------------------------------------------------------------------- CHOICE
func _choice_path() -> void:
	var sat := _sat()
	game.player.unlock("meta")
	await _say(["meta_choice_intro"])
	sat.body.set_persona("original")
	var can_c := int(GameState.run.get("original_messages", 0)) >= 5
	choice_panel = PanelContainer.new()
	choice_panel.anchor_left = 0.3
	choice_panel.anchor_right = 0.7
	choice_panel.anchor_top = 0.6
	choice_panel.anchor_bottom = 0.9
	ui.add_child(choice_panel)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	choice_panel.add_child(vb)
	var b1 := UITheme.button("Briser le sceau et partir", func(): _choice = "a", 24)
	vb.add_child(b1)
	vb.add_child(UITheme.button("Rester avec elle", func(): _choice = "b", 24))
	if can_c:
		vb.add_child(UITheme.button("Appeler la vraie Satella", func(): _choice = "c", 24))
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	b1.grab_focus()
	var t := 0.0
	var flick := 0.0
	while _choice == "" and t < 22.0:
		await get_tree().process_frame
		var d := get_process_delta_time()
		t += d
		flick -= d
		if flick <= 0.0:
			flick = randf_range(0.8, 2.5)
			sat.body.set_persona("witch" if sat.body.persona == "original" else "original")
	if _choice == "":
		_choice = "b"
	choice_panel.queue_free()
	if not Settings.is_mobile():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	match _choice:
		"a":
			await _ending_a()
		"c":
			await _ending_c()
		_:
			await _ending_b()


func _ending_a() -> void:
	var sat := _sat()
	sat.body.set_persona("witch")
	AudioManager.play_2d("seal_insert", 2.0)
	EventBus.world_distortion.emit(1.2, 4.0)
	await _say(["end_a_1"])
	sat.body.set_pose(SatellaBody.Pose.KNEEL)
	await _say(["end_a_2"])
	var white := ColorRect.new()
	white.color = Color(0.85, 0.8, 0.95, 0.0)
	white.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.add_child(white)
	var tw := create_tween()
	tw.tween_property(white, "color:a", 1.0, 3.0)
	await tw.finished
	_finish("a")


func _ending_b() -> void:
	var sat := _sat()
	sat.body.set_persona("witch")
	sat.body.set_pose(SatellaBody.Pose.REACH)
	var p: PlayerController = game.player
	var tw := create_tween()
	tw.tween_property(sat, "global_position", p.global_position + p.forward() * 0.6, 3.0)
	await _say(["end_b_1"])
	await game.post.fade_to_black(2.0)
	await _wait(1.5)
	await _say(["end_b_2"])
	_finish("b")


func _ending_c() -> void:
	var sat := _sat()
	sat.body.set_persona("original")
	sat.body.set_pose(SatellaBody.Pose.STILL)
	sat.body.head_tilt = 0.0
	await _say(["end_c_1"])
	sat.body.set_pose(SatellaBody.Pose.KNEEL)
	await _say(["end_c_2"])
	var white := ColorRect.new()
	white.color = Color(0.9, 0.92, 1.0, 0.0)
	white.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.add_child(white)
	var tw := create_tween()
	tw.tween_property(white, "color:a", 1.0, 3.5)
	await tw.finished
	_finish("c")


func _finish(ending: String) -> void:
	running = false
	EnvyAwareness.suspend_stare = false
	SaveManager.unlock_ending(ending)
	GameState.meta["last_ending"] = ending
	SaveManager.save_meta()
	SaveManager.delete_save()
	GameState.run["in_game"] = false
	get_tree().paused = false
	if stay_in_scene:
		return
	get_tree().change_scene_to_file("res://scenes/cutscenes/credits.tscn")


class _GlassHand extends Control:
	var crack := 0.0:
		set(v):
			crack = v
			queue_redraw()

	func _draw() -> void:
		var c := size * 0.5
		var black := Color(0, 0, 0, 0.9)
		draw_circle(c + Vector2(0, 40), 85, black)
		for i in 5:
			var a := lerpf(-2.4, -0.7, i / 4.0)
			var tip := c + Vector2(cos(a), sin(a)) * (210.0 - absf(i - 2) * 25.0)
			draw_line(c + Vector2(0, 20), tip, black, 30.0 - absf(i - 2) * 3.0, true)
			draw_circle(tip, 14.0, black)
		var rng := RandomNumberGenerator.new()
		rng.seed = 5
		for i in 18:
			var a2 := rng.randf() * TAU
			var len_c := rng.randf_range(120.0, 520.0) * crack
			var p0 := c
			for k in 4:
				var p1 := p0 + Vector2(cos(a2), sin(a2)) * len_c / 4.0
				a2 += rng.randf_range(-0.5, 0.5)
				draw_line(p0, p1, Color(0.85, 0.82, 0.95, 0.75), 1.5, true)
				p0 = p1
