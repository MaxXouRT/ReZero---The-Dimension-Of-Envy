class_name ReaderUI
extends CanvasLayer
## Modal readers: notes/messages (styled by author: silver for the true
## Satella, black-violet scrawl for the Witch, parchment for the rest) and
## the 3D object inspector (rotate the object with the mouse / finger).

var root: Control
var note_panel: PanelContainer
var note_title: Label
var note_body: RichTextLabel
var note_hint: Label
var inspect_root: Control
var inspect_view: SubViewport
var inspect_pivot: Node3D
var inspect_title: Label
var inspect_desc: Label
var open_kind := ""
var close_btn: Button
var _drag := false
var _opened_at := 0


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = UITheme.get_theme()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_build_note()
	_build_inspect()
	EventBus.note_opened.connect(_on_note)
	EventBus.inspect_requested.connect(_on_inspect)


func _build_note() -> void:
	note_panel = PanelContainer.new()
	note_panel.anchor_left = 0.24
	note_panel.anchor_right = 0.76
	note_panel.anchor_top = 0.1
	note_panel.anchor_bottom = 0.9
	note_panel.visible = false
	root.add_child(note_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 16)
	note_panel.add_child(vb)
	note_title = UITheme.label("", 30, UITheme.WHITE)
	note_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(note_title)
	var sep := ColorRect.new()
	sep.custom_minimum_size.y = 1
	sep.color = UITheme.VIOLET_DEEP
	vb.add_child(sep)
	note_body = RichTextLabel.new()
	note_body.bbcode_enabled = false
	note_body.fit_content = false
	note_body.scroll_active = true
	note_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	note_body.add_theme_font_size_override("normal_font_size", 23)
	vb.add_child(note_body)
	note_hint = UITheme.label("[E] / [Échap] / toucher : fermer", 16, UITheme.GREY)
	note_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	vb.add_child(note_hint)


func _build_inspect() -> void:
	inspect_root = Control.new()
	inspect_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	inspect_root.visible = false
	root.add_child(inspect_root)
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0.01, 0.85)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	inspect_root.add_child(bg)
	var svc := SubViewportContainer.new()
	svc.anchor_left = 0.2
	svc.anchor_right = 0.8
	svc.anchor_top = 0.08
	svc.anchor_bottom = 0.68
	svc.stretch = true
	svc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inspect_root.add_child(svc)
	inspect_view = SubViewport.new()
	inspect_view.own_world_3d = true
	inspect_view.transparent_bg = true
	svc.add_child(inspect_view)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 0, 0.75)
	cam.fov = 40
	inspect_view.add_child(cam)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35, 30, 0)
	key.light_energy = 1.4
	inspect_view.add_child(key)
	var rim := OmniLight3D.new()
	rim.position = Vector3(-0.6, 0.3, -0.5)
	rim.light_color = Color(0.6, 0.3, 0.9)
	rim.light_energy = 2.0
	inspect_view.add_child(rim)
	inspect_pivot = Node3D.new()
	inspect_view.add_child(inspect_pivot)
	inspect_title = UITheme.label("", 30, UITheme.WHITE)
	inspect_title.anchor_left = 0.2
	inspect_title.anchor_right = 0.8
	inspect_title.anchor_top = 0.7
	inspect_title.anchor_bottom = 0.76
	inspect_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inspect_root.add_child(inspect_title)
	inspect_desc = UITheme.label("", 20, UITheme.GREY)
	inspect_desc.anchor_left = 0.22
	inspect_desc.anchor_right = 0.78
	inspect_desc.anchor_top = 0.77
	inspect_desc.anchor_bottom = 0.95
	inspect_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inspect_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inspect_root.add_child(inspect_desc)
	close_btn = UITheme.button("Fermer", close, 22)
	close_btn.anchor_left = 0.45
	close_btn.anchor_right = 0.55
	close_btn.anchor_top = 0.93
	close_btn.anchor_bottom = 0.98
	inspect_root.add_child(close_btn)


func is_open() -> bool:
	return open_kind != ""


func _on_note(_id: String, title: String, body: String, author: String) -> void:
	note_title.text = title
	note_body.text = body
	var box := UITheme.panel_box(0.95)
	match author:
		"original":
			box.bg_color = Color(0.05, 0.05, 0.08, 0.96)
			box.border_color = UITheme.SILVER.darkened(0.3)
			note_body.add_theme_color_override("default_color", UITheme.SILVER)
			note_title.add_theme_color_override("font_color", UITheme.SILVER)
		"witch":
			box.bg_color = Color(0.03, 0.0, 0.04, 0.97)
			box.border_color = UITheme.WITCH.darkened(0.3)
			note_body.add_theme_color_override("default_color", UITheme.WITCH.lightened(0.2))
			note_title.add_theme_color_override("font_color", UITheme.WITCH)
		_:
			box.bg_color = Color(0.1, 0.085, 0.07, 0.96)
			box.border_color = Color(0.3, 0.25, 0.2)
			note_body.add_theme_color_override("default_color", Color(0.85, 0.8, 0.72))
			note_title.add_theme_color_override("font_color", Color(0.9, 0.85, 0.78))
	note_panel.add_theme_stylebox_override("panel", box)
	note_panel.visible = true
	_open("note")


func _on_inspect(item: Node3D, title: String, desc: String) -> void:
	for c in inspect_pivot.get_children():
		c.queue_free()
	var copy := item.duplicate(0) as Node3D
	if copy == null:
		return
	copy.visible = true
	copy.transform = Transform3D.IDENTITY
	_strip(copy)
	inspect_pivot.add_child(copy)
	# fit: centre the object
	var aabb := _aabb(copy)
	var scale_f := 0.35 / maxf(0.05, aabb.size.length())
	copy.scale = Vector3.ONE * scale_f
	copy.position = -aabb.get_center() * scale_f
	inspect_pivot.rotation = Vector3(0.4, 0.6, 0)
	inspect_title.text = title
	inspect_desc.text = desc
	inspect_root.visible = true
	_open("inspect")


func _strip(n: Node) -> void:
	for c in n.get_children():
		if c is CollisionObject3D or c is Light3D or c is Interactable:
			c.queue_free()
		else:
			_strip(c)


func _aabb(n: Node) -> AABB:
	var out := AABB()
	var first := true
	for c in n.get_children():
		if c is MeshInstance3D:
			var a: AABB = (c as MeshInstance3D).get_aabb()
			a = (c as Node3D).transform * a
			if first:
				out = a
				first = false
			else:
				out = out.merge(a)
	return out


func _open(kind: String) -> void:
	open_kind = kind
	_opened_at = Time.get_ticks_msec()
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	EventBus.ui_modal_opened.emit()


func close() -> void:
	if open_kind == "":
		return
	note_panel.visible = false
	inspect_root.visible = false
	var was := open_kind
	open_kind = ""
	get_tree().paused = false
	if not Settings.is_mobile():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	EventBus.ui_modal_closed.emit()
	if was == "note":
		EventBus.note_closed.emit()
	else:
		EventBus.inspect_closed.emit()


func _input(event: InputEvent) -> void:
	if open_kind == "":
		return
	if Time.get_ticks_msec() - _opened_at < 250:
		return
	if open_kind == "inspect" and (event is InputEventMouseButton or event is InputEventScreenTouch) and close_btn.get_global_rect().has_point(event.position):
		return
	if event.is_action_pressed("interact") or event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel") or (event is InputEventScreenTouch and event.pressed and open_kind == "note"):
		if open_kind == "inspect" and event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			_drag = true
			get_viewport().set_input_as_handled()
			return
		get_viewport().set_input_as_handled()
		close()
		return
	if open_kind == "inspect":
		if event is InputEventMouseButton and not event.pressed:
			_drag = false
		if (event is InputEventMouseMotion and _drag) or event is InputEventScreenDrag:
			var rel: Vector2 = event.relative
			inspect_pivot.rotate_y(rel.x * 0.01)
			inspect_pivot.rotate_x(rel.y * 0.01)
		get_viewport().set_input_as_handled()
