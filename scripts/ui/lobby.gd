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
var _window_light: OmniLight3D
var _shafts: Array[MeshInstance3D] = []
var _ruins: Array[Node3D] = []
var _title_layers: Array[Label] = []
var _subtitle_lbl: Label
var _quote: Label
var _hint_lbl: Label
var _cam_base := Vector3.ZERO
var _title_glitch := 0.0
var _lightning := 9.0
var _quote_t := 6.0
var _quote_i := 0
const QUOTES := ["« Tu reviens toujours à moi. »", "« Je t'aime. Je t'aime. Je t'aime. »", "« Pourquoi es-tu si loin de moi ? »", "« Il y a quelqu'un derrière tes yeux. »"]


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
	var fplus := Settings.is_forward_plus()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.006, 0.002, 0.012)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.09, 0.05, 0.14)
	env.ambient_light_energy = 0.55
	env.fog_enabled = true
	env.fog_light_color = Color(0.07, 0.025, 0.11)
	env.fog_density = 0.045
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_bloom = 0.06
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.25
	if fplus and Settings.volumetric_fog:
		env.volumetric_fog_enabled = true
		env.volumetric_fog_density = 0.035
		env.volumetric_fog_albedo = Color(0.35, 0.18, 0.5)
		env.volumetric_fog_length = 40.0
		env.fog_density = 0.02
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	# --- a ruined gothic hall drowned in the void
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.012, 0.008, 0.018)
	floor_mat.roughness = 0.18
	floor_mat.metallic = 0.4
	Builder.box(self, Vector3(60, 0.2, 80), Vector3(0, -0.1, -20), floor_mat, false)
	Builder.box(self, Vector3(8, 0.012, 40), Vector3(0, 0.006, -8), Builder.mat("carpet"), false)
	for side in [-1.0, 1.0]:
		for i in 7:
			var z := 2.0 - i * 5.5
			var h := 13.0 if i % 3 != 2 else 6.5   # some columns are broken
			Builder.pillar(self, Vector3(side * 6.5, 0, z), h, 0.55, "marble")
			if i % 2 == 0 and i > 0:
				Builder.candelabra(self, Vector3(side * 5.2, 0.0, z), true, false)
	# the great stained-glass window behind her, and its light shafts
	var throne_z := -11.0 if not _true_mode else -7.5
	var glass := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(7.0, 12.0)
	glass.mesh = q
	var gm := (Builder.mat("stained_glass") as ShaderMaterial).duplicate() as ShaderMaterial
	gm.set_shader_parameter("energy", 0.75)
	glass.material_override = gm
	glass.position = Vector3(0, 7.5, throne_z - 6.0)
	add_child(glass)
	Builder.box(self, Vector3(9.0, 16.0, 0.6), Vector3(0, 8.0, throne_z - 6.4), Builder.mat("stone_dark"), false)
	_window_light = OmniLight3D.new()
	_window_light.light_color = Color(0.55, 0.25, 0.9)
	_window_light.light_energy = 2.0
	_window_light.omni_range = 18.0
	_window_light.position = Vector3(0, 8.0, throne_z - 4.5)
	add_child(_window_light)
	for k in 3:
		var shaft := MeshInstance3D.new()
		var sq := QuadMesh.new()
		sq.size = Vector2(1.6 + k * 0.6, 16.0)
		shaft.mesh = sq
		var sm := StandardMaterial3D.new()
		sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		sm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		sm.cull_mode = BaseMaterial3D.CULL_DISABLED
		var g := Gradient.new()
		g.set_color(0, Color(0.45, 0.2, 0.75, 0.22))
		g.set_color(1, Color(0.45, 0.2, 0.75, 0.0))
		var gt := GradientTexture2D.new()
		gt.gradient = g
		gt.fill_from = Vector2(0.5, 0)
		gt.fill_to = Vector2(0.5, 1)
		sm.albedo_texture = gt
		shaft.material_override = sm
		shaft.position = Vector3((k - 1) * 1.6, 6.0, throne_z - 1.5)
		shaft.rotation_degrees = Vector3(-38, (k - 1) * 8.0, 0)
		add_child(shaft)
		_shafts.append(shaft)
	# floating ruins drifting in the dark
	for i in 7:
		var a := float(i) / 7.0 * TAU
		var r := Builder.floating_ruin(self, Vector3(cos(a) * 18.0, 9.0 + sin(i * 1.7) * 4.0, -22.0 + sin(a) * 10.0), 500 + i, 1.2)
		_ruins.append(r)
	# the throne and the dais
	Builder.box(self, Vector3(6.0, 0.35, 4.5), Vector3(0, 0.175, throne_z), Builder.mat("marble"))
	Builder.box(self, Vector3(4.5, 0.35, 3.5), Vector3(0, 0.525, throne_z - 0.3), Builder.mat("marble"))
	var throne := Builder.node(self, "Throne", Vector3(0, 0.7, throne_z - 0.4))
	Builder.box(throne, Vector3(1.3, 0.5, 1.0), Vector3(0, 0.25, 0), Builder.mat("fabric_dark"))
	Builder.box(throne, Vector3(1.5, 3.6, 0.25), Vector3(0, 1.8, -0.55), Builder.mat("iron"))
	Builder.box(throne, Vector3(1.8, 0.35, 0.35), Vector3(0, 3.65, -0.55), Builder.mat("gilt"))
	for sx in [-1.0, 1.0]:
		Builder.box(throne, Vector3(0.18, 0.6, 1.0), Vector3(sx * 0.72, 0.6, 0), Builder.mat("iron"))
		Builder.cyl(throne, 0.04, 0.09, 1.0, Vector3(sx * 0.8, 4.2, -0.55), Builder.mat("gilt"), false, 6)
	body = SatellaBody.new()
	add_child(body)
	body.twitch = 0.08
	body.tendril_amount = 0.0
	if _true_mode:
		body.set_pose(SatellaBody.Pose.STILL)
		body.position = Vector3(0, 0.7, throne_z + 1.6)
	else:
		body.set_pose(SatellaBody.Pose.SIT)
		body.position = Vector3(0, 0.75, throne_z - 0.35)
	var spot := SpotLight3D.new()
	spot.position = body.position + Vector3(0, 7.0, 1.2)
	spot.rotation_degrees.x = -82
	spot.spot_angle = 14.0
	spot.spot_range = 12.0
	spot.light_energy = 2.6
	spot.light_color = Color(0.82, 0.74, 0.98)
	spot.shadow_enabled = not Settings.is_mobile()
	add_child(spot)
	for x in [-1.8, 1.8]:
		Builder.candelabra(self, Vector3(x, 0.7, throne_z + 1.4), true, false)
	# drifting embers and falling ash
	_add_particles(Vector3(0, 3, throne_z + 3.0), Vector3(14, 6, 14), Color(0.75, 0.35, 1.0), 0.035, -0.25, 60, true)
	_add_particles(Vector3(0, 9, throne_z + 3.0), Vector3(18, 2, 18), Color(0.45, 0.42, 0.5), 0.03, 0.6, 50, false)
	# camera
	cam = Camera3D.new()
	cam.fov = 50
	cam.far = 120.0
	add_child(cam)
	_cam_base = Vector3(1.4, 1.65, throne_z + 8.5)
	cam.position = _cam_base + Vector3(0, 0.6, 4.0)   # dolly-in at start
	cam.look_at(body.position + Vector3(0, 1.2, 0))
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


func _add_particles(pos: Vector3, box: Vector3, color: Color, size: float, fall: float, amount: int, glow: bool) -> void:
	var p := CPUParticles3D.new()
	p.position = pos
	p.amount = amount if not Settings.is_mobile() else amount / 2
	p.lifetime = 9.0
	p.preprocess = 9.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = box * 0.5
	p.direction = Vector3(0, -1, 0) if fall > 0.0 else Vector3(0, 1, 0)
	p.spread = 25.0
	p.gravity = Vector3(0, -fall * 0.15, 0)
	p.initial_velocity_min = absf(fall) * 0.3
	p.initial_velocity_max = absf(fall) * 0.8
	p.angular_velocity_min = -60
	p.angular_velocity_max = 60
	var m := QuadMesh.new()
	m.size = Vector2(size, size * (1.0 if glow else 0.6))
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.albedo_color = color
	if glow:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 3.0
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.material = mat
	p.mesh = m
	add_child(p)


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	ui = Control.new()
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.theme = UITheme.get_theme()
	layer.add_child(ui)
	# left-side gradient so the menu reads over the scene
	var g := Gradient.new()
	g.set_color(0, Color(0, 0, 0.01, 0.92))
	g.set_color(1, Color(0, 0, 0.01, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0, 0.5)
	gt.fill_to = Vector2(1, 0.5)
	var shade := TextureRect.new()
	shade.texture = gt
	shade.anchor_right = 0.55
	shade.anchor_bottom = 1.0
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(shade)
	# title with chromatic glitch copies
	var title_box := Control.new()
	title_box.position = Vector2(80, 70)
	title_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(title_box)
	for c in [Color(0.9, 0.1, 0.35, 0.0), Color(0.2, 0.7, 1.0, 0.0), UITheme.WHITE]:
		var t := UITheme.label("RE:ZERO", 76, c)
		t.add_theme_constant_override("outline_size", 0)
		title_box.add_child(t)
		_title_layers.append(t)
	_subtitle_lbl = UITheme.label("T H E   D I M E N S I O N   O F   E N V Y", 24, UITheme.VIOLET.lightened(0.3))
	_subtitle_lbl.position = Vector2(86, 168)
	ui.add_child(_subtitle_lbl)
	var line := ColorRect.new()
	line.color = Color(0.55, 0.25, 0.85, 0.6)
	line.position = Vector2(86, 206)
	line.size = Vector2(0, 2)
	ui.add_child(line)
	create_tween().tween_property(line, "size:x", 430.0, 2.5).set_delay(0.8).set_trans(Tween.TRANS_QUAD)
	_quote = UITheme.label("", 18, Color(0.65, 0.55, 0.75))
	_quote.modulate.a = 0.0
	_quote.position = Vector2(86, 218)
	ui.add_child(_quote)
	menu = VBoxContainer.new()
	menu.position = Vector2(70, 290)
	menu.add_theme_constant_override("separation", 6)
	ui.add_child(menu)
	menu.add_child(_menu_button("NEW GAME", "Commencer une nouvelle boucle", _new_game))
	continue_btn = _menu_button("CONTINUE", "Reprendre au dernier point de retour", _continue)
	continue_btn.disabled = not SaveManager.has_save()
	if SaveManager.has_save():
		var info := SaveManager.save_info()
		continue_btn.set_meta("hint", "Chapitre %d — %d fragment(s) — %d mort(s)" % [info.get("chapter", 1), info.get("fragments", 0), info.get("deaths", 0)])
	menu.add_child(continue_btn)
	menu.add_child(_menu_button("SETTINGS", "Graphismes, audio, commandes, accessibilité", _settings))
	menu.add_child(_menu_button("EXTRAS", "Fins découvertes et souvenirs", _extras))
	var exit_btn := _menu_button("EXIT", "Quitter... si elle te laisse partir", func(): get_tree().quit())
	exit_btn.mouse_entered.connect(_on_exit_hover)
	menu.add_child(exit_btn)
	_hint_lbl = UITheme.label("", 17, UITheme.GREY)
	_hint_lbl.position = Vector2(86, 640)
	ui.add_child(_hint_lbl)
	menu.get_child(1 if SaveManager.has_save() else 0).grab_focus.call_deferred()
	# staggered entrance
	for i in menu.get_child_count():
		var b: Control = menu.get_child(i)
		b.modulate.a = 0.0
		var tw := create_tween()
		tw.tween_interval(1.0 + i * 0.12)
		tw.tween_property(b, "modulate:a", 1.0, 0.5)
	var foot := UITheme.label("Fan-game non officiel inspiré de Re:Zero. Œuvre de fiction.   v1.1", 14, Color(0.35, 0.32, 0.4))
	foot.anchor_top = 1.0
	foot.anchor_bottom = 1.0
	foot.offset_left = 80
	foot.offset_top = -40
	ui.add_child(foot)
	subtitle = UITheme.label("", 24, UITheme.WITCH.lightened(0.2))
	subtitle.anchor_left = 0.4
	subtitle.anchor_right = 0.95
	subtitle.anchor_top = 0.84
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
	# fade in from black
	var black := ColorRect.new()
	black.color = Color(0, 0, 0, 1)
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(black)
	var tw2 := create_tween()
	tw2.tween_property(black, "color:a", 0.0, 2.2).set_trans(Tween.TRANS_SINE)
	tw2.tween_callback(black.queue_free)


## Menu entry: a violet bar grows and the label slides on hover/focus.
func _menu_button(text: String, hint: String, cb: Callable) -> Button:
	var b := UITheme.button(text, cb, 34)
	b.set_meta("hint", hint)
	b.custom_minimum_size = Vector2(420, 58)
	var normal := StyleBoxEmpty.new()
	normal.content_margin_left = 18
	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(0.3, 0.1, 0.45, 0.22)
	hover.border_color = Color(0.7, 0.4, 1.0)
	hover.border_width_left = 3
	hover.content_margin_left = 18
	for st in ["normal", "disabled"]:
		b.add_theme_stylebox_override(st, normal)
	for st in ["hover", "focus", "pressed"]:
		b.add_theme_stylebox_override(st, hover)
	var on := func():
		var tw := b.create_tween().set_parallel(true)
		tw.tween_property(normal, "content_margin_left", 34.0, 0.18)
		tw.tween_property(hover, "content_margin_left", 34.0, 0.18)
		_hint_lbl.text = String(b.get_meta("hint", ""))
		_title_glitch = maxf(_title_glitch, 0.12)
	var off := func():
		var tw := b.create_tween().set_parallel(true)
		tw.tween_property(normal, "content_margin_left", 18.0, 0.25)
		tw.tween_property(hover, "content_margin_left", 18.0, 0.25)
	b.mouse_entered.connect(on)
	b.focus_entered.connect(on)
	b.mouse_exited.connect(off)
	b.focus_exited.connect(off)
	return b


func _extras() -> void:
	if _modal:
		return
	var names := {"a": "ENDING A — ESCAPE", "b": "ENDING B — ETERNAL LOOP", "c": "ENDING C — THE REAL SATELLA", "true": "TRUE ENDING — THE PLAYER"}
	var got: Array = GameState.meta.get("endings", [])
	var txt := "FINS DÉCOUVERTES  (%d / 4)\n\n" % got.size()
	for k in ["a", "b", "c", "true"]:
		txt += ("[  ] " if not got.has(k) else "[x] ") + (names[k] if got.has(k) else "— ? —") + "\n"
	txt += "\nMorts au total : %d\nVisites du lobby : %d" % [int(GameState.meta.get("total_deaths", 0)), _visit]
	_info_panel(txt)


func _info_panel(text: String) -> void:
	_modal = true
	menu.visible = false
	var panel := PanelContainer.new()
	panel.anchor_left = 0.05
	panel.anchor_right = 0.45
	panel.anchor_top = 0.3
	panel.anchor_bottom = 0.8
	ui.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	panel.add_child(vb)
	var l := UITheme.label(text, 22, UITheme.WHITE)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(l)
	var back := UITheme.button("← Retour", func():
		panel.queue_free()
		menu.visible = true
		_modal = false
		menu.get_child(3).grab_focus(), 24)
	vb.add_child(back)
	back.grab_focus()


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
	# slow dolly-in then breathing drift, with a gentle mouse parallax on PC
	if cam:
		var par := Vector2.ZERO
		if not Settings.is_mobile():
			var vs := get_viewport().get_visible_rect().size
			par = (get_viewport().get_mouse_position() / vs - Vector2(0.5, 0.5)) * Vector2(0.6, -0.3)
		var drift := Vector3(sin(_t * 0.13) * 0.2 + par.x, sin(_t * 0.21) * 0.06 + par.y, -sin(_t * 0.07) * 0.4)
		if Settings.reduce_camera_motion:
			drift *= 0.2
		var target := _cam_base + drift
		cam.position = cam.position.lerp(target, clampf(delta * (0.6 if _t < 6.0 else 1.5), 0.0, 1.0))
		cam.look_at(body.position + Vector3(0.3, 1.25, 0))
	if mini(_visit, 3) >= 3 or _true_mode:
		body.look_target = cam.global_position
	# floating ruins drift
	for i in _ruins.size():
		var r := _ruins[i]
		r.rotation.y += delta * 0.03 * (1.0 if i % 2 == 0 else -1.0)
		r.position.y += sin(_t * 0.3 + i) * delta * 0.15
	# light shafts breathe
	for i in _shafts.size():
		_shafts[i].transparency = 0.3 + 0.3 * sin(_t * 0.5 + i * 1.3)
	# title glitch
	_title_glitch = maxf(0.0, _title_glitch - delta)
	if randf() < delta * 0.12:
		_title_glitch = randf_range(0.08, 0.25)
	if _title_layers.size() == 3:
		var g := _title_glitch > 0.0
		_title_layers[0].position = Vector2(randf_range(-6, 6), randf_range(-2, 2)) if g else Vector2.ZERO
		_title_layers[1].position = Vector2(randf_range(-6, 6), randf_range(-2, 2)) if g else Vector2.ZERO
		_title_layers[0].modulate.a = 0.8 if g else 0.0
		_title_layers[1].modulate.a = 0.8 if g else 0.0
		_title_layers[0].add_theme_color_override("font_color", Color(0.9, 0.1, 0.35, 1.0))
		_title_layers[1].add_theme_color_override("font_color", Color(0.2, 0.7, 1.0, 1.0))
	_subtitle_lbl.modulate.a = 0.75 + 0.25 * sin(_t * 1.2)
	# whispered quotes
	_quote_t -= delta
	if _quote_t <= 0.0 and not _modal:
		_quote_t = 9.0
		_quote.text = QUOTES[_quote_i % QUOTES.size()]
		_quote_i += 1
		var tw := create_tween()
		tw.tween_property(_quote, "modulate:a", 1.0, 1.5)
		tw.tween_interval(4.0)
		tw.tween_property(_quote, "modulate:a", 0.0, 1.5)
	# violet lightning behind the stained glass
	_lightning -= delta
	if _lightning <= 0.0:
		_lightning = randf_range(11.0, 22.0)
		_flash()


func _flash() -> void:
	var peak := 7.0 if not Settings.reduce_flashes else 3.0
	var tw := create_tween()
	tw.tween_property(_window_light, "light_energy", peak, 0.06)
	tw.tween_property(_window_light, "light_energy", 1.0, 0.12)
	tw.tween_property(_window_light, "light_energy", peak * 0.7, 0.05)
	tw.tween_property(_window_light, "light_energy", 2.0, 0.8)
	AudioManager.play_2d("thump", -10.0, 0.8)


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
