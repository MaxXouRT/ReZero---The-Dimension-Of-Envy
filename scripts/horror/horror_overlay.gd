class_name HorrorOverlay
extends CanvasLayer
## HorrorOverlay — screen-space horror staged INSIDE the game window.
##  * face_jumpscare(): Satella's face rushes at the camera (own 3D world).
##  * tear_screen(): the Witch's shadow hands grab what is on screen (pause
##    menu, fake windows) and rip it apart (screenshot cut along a jagged
##    tear line).
##  * fake_menu(kind): a fictional in-game window ("save?", "not responding")
##    that she takes over. Everything is drawn by the game: no real system
##    dialog, nothing outside the window is touched.
##  * fake cursor: an in-game arrow that moves by itself (meta finale).

const TORN := preload("res://shaders/torn_half.gdshader")

var face_view: SubViewport
var face_rect: TextureRect
var face_cam: Camera3D
var face_body: SatellaBody
var root: Control
var fake_cursor: Control
var busy := false


func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UITheme.get_theme()
	add_child(root)
	_build_face_view()
	fake_cursor = _FakeCursor.new()
	fake_cursor.visible = false
	fake_cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(fake_cursor)


func _build_face_view() -> void:
	face_view = SubViewport.new()
	face_view.own_world_3d = true
	face_view.size = Vector2i(960, 540)
	face_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(face_view)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0, 0, 0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.1, 0.05, 0.15)
	env.ambient_light_energy = 0.5
	env.glow_enabled = true
	env.glow_intensity = 1.2
	var we := WorldEnvironment.new()
	we.environment = env
	face_view.add_child(we)
	face_body = SatellaBody.new()
	face_view.add_child(face_body)
	face_cam = Camera3D.new()
	face_cam.fov = 50
	face_view.add_child(face_cam)
	var under := OmniLight3D.new()
	under.light_color = Color(0.7, 0.45, 0.95)
	under.light_energy = 2.5
	under.omni_range = 2.0
	under.position = Vector3(0, 1.55, 0.6)
	face_view.add_child(under)
	face_rect = TextureRect.new()
	face_rect.texture = face_view.get_texture()
	face_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	face_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	face_rect.visible = false
	face_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(face_rect)


# ------------------------------------------------------------------ face jumpscare
func face_jumpscare(violent := false) -> void:
	if busy and not violent:
		return
	busy = true
	JumpscareState.begin("face", 2.6)
	face_body.set_persona("witch")
	face_body.set_pose(SatellaBody.Pose.SCREAM if violent else SatellaBody.Pose.STILL)
	face_body.mouth_open = 1.0 if violent else 0.4
	face_body.set_dissolve(0.0)
	var head_h := 1.8 if not violent else 1.74
	face_cam.position = Vector3(0, head_h, 1.6)
	face_cam.look_at(Vector3(0, head_h, 0))
	face_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	face_rect.visible = true
	face_rect.modulate.a = 1.0
	AudioManager.play_jumpscare("jumpscare_violent" if violent else "stinger_1", 0.0 if violent else -2.0)
	if violent:
		AudioManager.play_jumpscare("witch_scream", 0.0)
	EventBus.camera_shake.emit(1.0, 0.8)
	EventBus.screen_glitch.emit(0.9 if violent else 0.5, 0.6)
	var tw := create_tween()
	tw.tween_property(face_cam, "position:z", 0.32 if violent else 0.42, 0.22 if violent else 0.3).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tw.tween_interval(0.55 if violent else 0.45)
	tw.tween_property(face_rect, "modulate:a", 0.0, 0.25)
	await tw.finished
	face_rect.visible = false
	face_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	busy = false


# ------------------------------------------------------------------ tear
## Screenshot the game window, then two shadow hands rip it in half.
func tear_screen(hide_before: Array = []) -> void:
	# wait two frames so the element to tear is on screen (works paused, and
	# also without a GPU — headless QA — where no image can be captured)
	await get_tree().process_frame
	await get_tree().process_frame
	var img: Image = null
	if DisplayServer.get_name() != "headless":
		img = get_viewport().get_texture().get_image()
	if img == null or img.is_empty():
		img = Image.create(64, 36, false, Image.FORMAT_RGB8)
	var tex := ImageTexture.create_from_image(img)
	for n in hide_before:
		if is_instance_valid(n):
			n.visible = false
	var halves: Array[TextureRect] = []
	for side in 2:
		var tr := TextureRect.new()
		tr.texture = tex
		tr.set_anchors_preset(Control.PRESET_FULL_RECT)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_SCALE
		var m := ShaderMaterial.new()
		m.shader = TORN
		m.set_shader_parameter("side", float(side))
		m.set_shader_parameter("seed", randf() * 10.0)
		tr.material = m
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(tr)
		tr.pivot_offset = get_viewport().get_visible_rect().size * Vector2(0.5, 0.5)
		halves.append(tr)
	var vs := get_viewport().get_visible_rect().size
	var hands: Array[_ShadowHand] = []
	for side in 2:
		var h := _ShadowHand.new()
		h.flip = side == 1
		h.position = Vector2(-300.0 if side == 0 else vs.x + 300.0, vs.y * (0.45 + 0.1 * side))
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(h)
		hands.append(h)
	# hands reach in
	var tw := create_tween().set_parallel(true)
	tw.tween_property(hands[0], "position:x", vs.x * 0.3, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(hands[1], "position:x", vs.x * 0.7, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tw.finished
	AudioManager.play_jumpscare("grab", 2.0)
	EventBus.camera_shake.emit(0.6, 0.4)
	await get_tree().create_timer(0.25, true, false, true).timeout
	# rip
	AudioManager.play_jumpscare("tear", 2.0)
	var tw2 := create_tween().set_parallel(true)
	tw2.tween_property(halves[0], "position:x", -vs.x * 0.75, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw2.tween_property(halves[0], "rotation", -0.45, 0.55)
	tw2.tween_property(halves[1], "position:x", vs.x * 0.75, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw2.tween_property(halves[1], "rotation", 0.5, 0.55)
	tw2.tween_property(hands[0], "position:x", -vs.x * 0.5, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw2.tween_property(hands[1], "position:x", vs.x * 1.5, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw2.finished
	for n in halves:
		n.queue_free()
	for n in hands:
		n.queue_free()


# ------------------------------------------------------------------ fake windows
func fake_menu(kind := "save") -> void:
	if busy:
		return
	busy = true
	var tree := get_tree()
	var p := tree.get_first_node_in_group("player") as PlayerController
	if p:
		p.lock("fake_menu")
	var prev_mouse := Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var panel := PanelContainer.new()
	panel.anchor_left = 0.32
	panel.anchor_right = 0.68
	panel.anchor_top = 0.36
	panel.anchor_bottom = 0.64
	root.add_child(panel)
	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 16)
	panel.add_child(vb)
	var title := UITheme.label("", 26, UITheme.WHITE)
	var body := UITheme.label("", 21, UITheme.GREY)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(title)
	vb.add_child(body)
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(hb)
	var state := {"clicked": false}
	var on_click := func(): state["clicked"] = true
	if kind == "crash":
		title.text = "SUBARU — ne répond pas"
		body.text = "Le personnage a cessé de répondre.\nAttendre ou forcer la fermeture ?"
		hb.add_child(UITheme.button("Attendre", on_click, 22))
		hb.add_child(UITheme.button("Forcer la fermeture", on_click, 22))
	else:
		title.text = "Sauvegarder la progression ?"
		body.text = "Un point de retour peut être créé ici."
		hb.add_child(UITheme.button("Oui", on_click, 22))
		hb.add_child(UITheme.button("Non", on_click, 22))
	AudioManager.play_ui("ui_click")
	var t := 0.0
	while t < 6.0 and not state["clicked"]:
		await tree.process_frame
		t += get_process_delta_time()
	AudioManager.play_2d("glitch", 0.0)
	EventBus.screen_glitch.emit(0.7, 0.5)
	title.add_theme_color_override("font_color", UITheme.WITCH)
	if kind == "crash":
		title.text = "IL NE RÉPONDRA PLUS."
		body.text = "C'est toi qui réponds, maintenant."
	else:
		title.text = "TU NE PEUX PAS SAUVEGARDER"
		body.text = "ce qui m'appartient."
	for c in hb.get_children():
		c.queue_free()
	await tree.create_timer(1.6).timeout
	await tear_screen([panel])
	panel.queue_free()
	Input.mouse_mode = prev_mouse
	if p and is_instance_valid(p):
		p.unlock("fake_menu")
	EnvyAwareness.add(2.0, "fake_menu")
	busy = false


func fake_death() -> void:
	ReturnByDeath.fake_death()


# ------------------------------------------------------------------ fake cursor
func show_fake_cursor(on: bool, from := Vector2(-1, -1)) -> void:
	fake_cursor.visible = on
	if on:
		var vs := get_viewport().get_visible_rect().size
		fake_cursor.position = from if from.x >= 0.0 else vs * Vector2(0.8, 0.8)


func move_fake_cursor(to: Vector2, duration: float) -> void:
	var tw := create_tween()
	tw.tween_property(fake_cursor, "position", to, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tw.finished


class _FakeCursor extends Control:
	func _draw() -> void:
		var pts := PackedVector2Array([Vector2(0, 0), Vector2(0, 26), Vector2(7, 20), Vector2(12, 31), Vector2(16, 29), Vector2(11, 18), Vector2(19, 18)])
		draw_colored_polygon(pts, Color(0.92, 0.9, 0.95))
		draw_polyline(pts + PackedVector2Array([Vector2(0, 0)]), Color(0, 0, 0), 1.5, true)


class _ShadowHand extends Control:
	var flip := false
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var s := -1.0 if flip else 1.0
		var black := Color(0.0, 0.0, 0.0, 0.97)
		var rim := Color(0.5, 0.15, 0.75, 0.9)
		# arm coming from off-screen
		var arm := PackedVector2Array([Vector2(-900 * s, -40), Vector2(-40 * s, -55), Vector2(-20 * s, 55), Vector2(-900 * s, 70)])
		draw_colored_polygon(arm, black)
		# palm
		draw_circle(Vector2(10 * s, 0), 62, black)
		# long fingers
		for i in 5:
			var a := lerpf(-0.9, 0.9, i / 4.0) + sin(_t * 9.0 + i) * 0.05
			var base := Vector2(40 * s, 0) + Vector2(cos(a) * 30 * s, sin(a) * 40)
			var tip := base + Vector2(cos(a) * 120 * s, sin(a) * 120)
			draw_line(base, tip, black, 22.0 - i * 1.5, true)
			draw_line(base, tip, rim, 2.0, true)
			draw_circle(tip, 9.0, black)
		draw_arc(Vector2(10 * s, 0), 62, 0, TAU, 32, rim, 2.0, true)
