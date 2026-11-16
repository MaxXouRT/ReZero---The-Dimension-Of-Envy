extends Node3D
## LOBBY — the main menu is already a horror scene.
##
## A black void, a faint violet mist, a single chair far away under a weak
## light. Satella sits on it. She changes with every visit (persistent meta
## data):
##   visit 1: she sits, head lowered.
##   visit 2: her head is slightly turned toward the camera.
##   visit 3+: she looks straight at the player.
##   after the TRUE ENDING: she stands, staring into the camera, whispers the
##   player's chosen name, and the screen says YOU ARE NOT SUBARU. I FOUND YOU.
## First launch: an optional display-name prompt ("Comment dois-je t'appeler ?").

var cam: Camera3D
var body: SatellaBody
var ui: Control
var menu: VBoxContainer
var continue_btn: Button
var subtitle: Label
var true_text: Label
var _t := 0.0
var _exit_whispered := false
var _visit := 1
var _true_mode := false
var _modal := false


func _ready() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	GameState.meta["lobby_visits"] = int(GameState.meta.get("lobby_visits", 0)) + 1
	_visit = int(GameState.meta["lobby_visits"])
	_true_mode = bool(GameState.meta.get("true_ending_seen", false))
	SaveManager.save_meta()
	_build_scene()
	_build_ui()
	AudioManager.set_ambience({"amb_drone_low": 0.35, "amb_void_wind": 0.25}, "silent")
	AudioManager.set_music_mode("lobby")
	EventBus.dialogue_line.connect(_on_line)
	if not Settings.first_launch_done:
		_name_prompt()
	else:
		_visit_line()


func _build_scene() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.004, 0.0, 0.008)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.05, 0.02, 0.08)
	env.ambient_light_energy = 0.4
	env.fog_enabled = true
	env.fog_light_color = Color(0.06, 0.02, 0.09)
	env.fog_density = 0.06
	env.glow_enabled = true
	env.glow_intensity = 0.8
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	if Settings.is_forward_plus() and Settings.volumetric_fog:
		env.volumetric_fog_enabled = true
		env.volumetric_fog_density = 0.04
		env.volumetric_fog_albedo = Color(0.3, 0.15, 0.4)
		env.volumetric_fog_length = 30.0
		env.fog_density = 0.03
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.01, 0.006, 0.014)
	floor_mat.roughness = 0.12
	floor_mat.metallic = 0.5
	Builder.box(self, Vector3(60, 0.2, 60), Vector3(0, -0.1, 0), floor_mat, false)
	var seat := Vector3(0, 0, -9.0)
	if _true_mode:
		seat = Vector3(0, 0, -5.5)
	var chair := Builder.chair(self, seat + Vector3(0, 0, -0.1), 0.0)
	chair.rotation_degrees.y = 0.0
	chair.scale = Vector3(1.25, 1.1, 1.25)
	body = SatellaBody.new()
	add_child(body)
	body.position = seat + Vector3(0, 0.0, 0.05)
	body.rotation.y = 0.0
	body.twitch = 0.08
	body.tendril_amount = 0.35
	if _true_mode:
		body.set_pose(SatellaBody.Pose.STILL)
		body.position = seat + Vector3(0, 0, 1.2)
		chair.visible = true
	else:
		body.set_pose(SatellaBody.Pose.SIT)
		body.position.y = 0.05
	var spot := SpotLight3D.new()
	spot.position = body.position + Vector3(0, 6.0, 0.5)
	spot.rotation_degrees.x = -90
	spot.spot_angle = 16.0
	spot.spot_range = 9.0
	spot.light_energy = 2.2
	spot.light_color = Color(0.8, 0.72, 0.95)
	spot.shadow_enabled = true
	spot.light_volumetric_fog_energy = 2.0
	add_child(spot)
	for x in [-1.3, 1.4, 0.6]:
		Builder.candle(self, body.position + Vector3(x, 0, 0.9 + absf(x) * 0.3), true, x > 1.0, Color(1.0, 0.55, 0.3), 0.5, 3.5)
	cam = Camera3D.new()
	cam.position = Vector3(0.6, 1.55, 3.0)
	cam.fov = 55
	add_child(cam)
	cam.look_at(body.position + Vector3(0, 1.2, 0))
	# variations by visit
	match mini(_visit, 3):
		1:
			body.head_tilt = 0.0
			body.head_turn_offset = 0.0
			body.look_target = Vector3.INF
		2:
			body.head_turn_offset = 0.35
			body.look_target = Vector3.INF
		_:
			body.look_target = cam.global_position
	if _true_mode:
		body.look_target = cam.global_position
		body.twitch = 0.0


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	ui = Control.new()
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.theme = UITheme.get_theme()
	layer.add_child(ui)
	var title := UITheme.label("RE:ZERO", 64, UITheme.WHITE)
	title.position = Vector2(80, 80)
	ui.add_child(title)
	var sub := UITheme.label("THE DIMENSION OF ENVY", 28, UITheme.VIOLET.lightened(0.25))
	sub.position = Vector2(84, 160)
	ui.add_child(sub)
	menu = VBoxContainer.new()
	menu.position = Vector2(70, 270)
	menu.add_theme_constant_override("separation", 8)
	ui.add_child(menu)
	menu.add_child(UITheme.button("NEW GAME", _new_game, 30))
	continue_btn = UITheme.button("CONTINUE", _continue, 30)
	continue_btn.disabled = not SaveManager.has_save()
	menu.add_child(continue_btn)
	if SaveManager.has_save():
		var info := SaveManager.save_info()
		continue_btn.tooltip_text = "Chapitre %d — %d fragment(s) — %d mort(s)" % [info.get("chapter", 1), info.get("fragments", 0), info.get("deaths", 0)]
	menu.add_child(UITheme.button("SETTINGS", _settings, 30))
	var exit_btn := UITheme.button("EXIT", func(): get_tree().quit(), 30)
	exit_btn.mouse_entered.connect(_on_exit_hover)
	menu.add_child(exit_btn)
	menu.get_child(1 if SaveManager.has_save() else 0).grab_focus.call_deferred()
	var foot := UITheme.label("Fan-game non officiel inspiré de Re:Zero. Œuvre de fiction.", 14, Color(0.35, 0.32, 0.4))
	foot.anchor_top = 1.0
	foot.anchor_bottom = 1.0
	foot.position = Vector2(80, -40)
	foot.offset_top = -40
	ui.add_child(foot)
	subtitle = UITheme.label("", 24, UITheme.WITCH.lightened(0.2))
	subtitle.anchor_left = 0.3
	subtitle.anchor_right = 0.9
	subtitle.anchor_top = 0.82
	subtitle.anchor_bottom = 0.9
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.modulate.a = 0.0
	ui.add_child(subtitle)
	true_text = UITheme.label("", 40, UITheme.WHITE)
	true_text.set_anchors_preset(Control.PRESET_FULL_RECT)
	true_text.anchor_left = 0.35
	true_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	true_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	true_text.modulate.a = 0.0
	true_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(true_text)


func _on_line(_speaker: String, text: String, duration: float, _style: String) -> void:
	subtitle.text = text
	var tw := create_tween()
	tw.tween_property(subtitle, "modulate:a", 1.0, 0.6)
	tw.tween_interval(duration)
	tw.tween_property(subtitle, "modulate:a", 0.0, 1.0)


func _visit_line() -> void:
	await get_tree().create_timer(5.0).timeout
	if _true_mode:
		await _true_sequence()
		return
	match mini(_visit, 3):
		1:
			DialogueManager.say("lobby_1", {"position": body.position + Vector3.UP * 1.4})
		2:
			DialogueManager.say("lobby_2", {"position": body.position + Vector3.UP * 1.4})
		_:
			DialogueManager.say("lobby_3", {"position": body.position + Vector3.UP * 1.4})


## After the true ending: she stands, she knows.
func _true_sequence() -> void:
	if Settings.has_custom_name():
		DialogueManager.say("lobby_true", {"position": body.position + Vector3.UP * 1.6})
	else:
		DialogueManager.say("lobby_3", {"position": body.position + Vector3.UP * 1.6})
	await get_tree().create_timer(4.0).timeout
	for line in ["YOU ARE NOT SUBARU.", "I FOUND YOU.", "THE END?"]:
		true_text.text = line
		AudioManager.play_2d("glitch" if line != "THE END?" else "thump", -6.0)
		var tw := create_tween()
		tw.tween_property(true_text, "modulate:a", 1.0, 0.8)
		tw.tween_interval(2.2)
		tw.tween_property(true_text, "modulate:a", 0.0, 0.8)
		await tw.finished


func _on_exit_hover() -> void:
	if _exit_whispered:
		return
	_exit_whispered = true
	body.head_turn_offset = 0.6
	DialogueManager.say("lobby_exit", {"position": body.position + Vector3.UP * 1.4})


func _process(delta: float) -> void:
	_t += delta
	if cam and not Settings.reduce_camera_motion:
		cam.position = Vector3(0.6 + sin(_t * 0.13) * 0.15, 1.55 + sin(_t * 0.21) * 0.05, 3.0 - sin(_t * 0.07) * 0.4)
	if mini(_visit, 3) >= 3 or _true_mode:
		body.look_target = cam.global_position
	# the closer you look at the menu, the closer she seems... (subtle)
	if _visit >= 3 and not _true_mode:
		body.position.z = lerpf(body.position.z, -9.0 + minf(_t / 240.0, 1.0) * 1.5, delta * 0.2)


# ------------------------------------------------------------------ actions
func _new_game() -> void:
	if _modal:
		return
	if SaveManager.has_save():
		_confirm("Une partie est en cours. Recommencer depuis le début ?", _start_new)
	else:
		_start_new()


func _start_new() -> void:
	SaveManager.delete_save()
	GameState.new_game()
	await _fade_out()
	get_tree().change_scene_to_file("res://scenes/main/game.tscn")


func _continue() -> void:
	if _modal or not SaveManager.load_game():
		return
	await _fade_out()
	get_tree().change_scene_to_file("res://scenes/main/game.tscn")


func _fade_out() -> void:
	var black := ColorRect.new()
	black.color = Color(0, 0, 0, 0)
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.add_child(black)
	AudioManager.play_2d("whoosh", -6.0)
	var tw := create_tween()
	tw.tween_property(black, "color:a", 1.0, 1.4)
	await tw.finished
	AudioManager.stop_all_music()


func _settings() -> void:
	if _modal:
		return
	_modal = true
	menu.visible = false
	var s := SettingsMenu.new()
	ui.add_child(s)
	await s.closed
	menu.visible = true
	_modal = false
	menu.get_child(2).grab_focus()


func _confirm(text: String, yes: Callable) -> void:
	_modal = true
	var panel := PanelContainer.new()
	panel.anchor_left = 0.32
	panel.anchor_right = 0.68
	panel.anchor_top = 0.38
	panel.anchor_bottom = 0.62
	ui.add_child(panel)
	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 14)
	panel.add_child(vb)
	var l := UITheme.label(text, 22, UITheme.WHITE)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(l)
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(hb)
	var yes_b := UITheme.button("Oui", func():
		panel.queue_free()
		_modal = false
		yes.call(), 24)
	hb.add_child(yes_b)
	hb.add_child(UITheme.button("Non", func():
		panel.queue_free()
		_modal = false, 24))
	yes_b.grab_focus()


## First launch: optional display name. Stored locally in settings only.
func _name_prompt() -> void:
	_modal = true
	menu.visible = false
	var panel := PanelContainer.new()
	panel.anchor_left = 0.3
	panel.anchor_right = 0.7
	panel.anchor_top = 0.3
	panel.anchor_bottom = 0.72
	ui.add_child(panel)
	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 16)
	panel.add_child(vb)
	vb.add_child(UITheme.label("Comment dois-je t'appeler ?", 30, UITheme.WHITE))
	var info := UITheme.label("Prénom d'affichage facultatif — un prénom fictif convient. Il reste uniquement dans les paramètres locaux du jeu et peut être modifié ou effacé à tout moment (Paramètres > Profil).", 17, UITheme.GREY)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(info)
	var le := LineEdit.new()
	le.max_length = 20
	le.placeholder_text = "Ton prénom (facultatif)"
	le.custom_minimum_size.y = 52
	vb.add_child(le)
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(hb)
	var done := func(use_name: bool):
		Settings.set_player_name(le.text if use_name else "")
		Settings.first_launch_done = true
		Settings.save_settings()
		panel.queue_free()
		menu.visible = true
		_modal = false
		menu.get_child(0).grab_focus()
		_visit_line()
	hb.add_child(UITheme.button("Continuer", func(): done.call(true), 24))
	hb.add_child(UITheme.button("Passer", func(): done.call(false), 24))
	le.text_submitted.connect(func(_t): done.call(true))
	le.grab_focus.call_deferred()
	await get_tree().create_timer(1.5).timeout
	DialogueManager.say("lobby_name_ask", {"position": body.position + Vector3.UP * 1.4})
