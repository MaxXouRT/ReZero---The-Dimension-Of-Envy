class_name HUD
extends CanvasLayer
## Minimal HUD: no health bar, no map, no Envy gauge (hidden by design).
## Only: interaction crosshair + contextual prompt, subtitles, objective
## toasts, chapter title cards, discreet notifications, a battery hint when
## it matters. Optional debug overlay (F3) for QA.

var crosshair: Control
var prompt: Label
var subtitle_panel: PanelContainer
var subtitle_speaker: Label
var subtitle_text: Label
var objective: Label
var toast_label: Label
var chapter_title: Label
var chapter_sub: Label
var battery_label: Label
var debug_label: Label
var fps_label: Label
var _sub_time := 0.0
var _obj_time := 0.0
var _toast_time := 0.0
var _crosshair_active := false
var _battery_show := 0.0
var _debug := false


func _ready() -> void:
	layer = 10
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UITheme.get_theme()
	add_child(root)
	crosshair = _Crosshair.new()
	crosshair.set_anchors_preset(Control.PRESET_CENTER)
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(crosshair)
	prompt = _label(root, 20, UITheme.WHITE)
	prompt.set_anchors_preset(Control.PRESET_CENTER)
	prompt.anchor_left = 0.3
	prompt.anchor_right = 0.7
	prompt.anchor_top = 0.53
	prompt.anchor_bottom = 0.58
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# subtitles
	subtitle_panel = PanelContainer.new()
	subtitle_panel.add_theme_stylebox_override("panel", UITheme.panel_box(0.55, Color(0, 0, 0, 0)))
	subtitle_panel.anchor_left = 0.18
	subtitle_panel.anchor_right = 0.82
	subtitle_panel.anchor_top = 0.8
	subtitle_panel.anchor_bottom = 0.8
	subtitle_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	subtitle_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(subtitle_panel)
	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	subtitle_panel.add_child(vb)
	subtitle_speaker = UITheme.label("", 18, UITheme.GREY)
	subtitle_speaker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(subtitle_speaker)
	subtitle_text = UITheme.label("", 26, UITheme.WHITE)
	subtitle_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(subtitle_text)
	subtitle_panel.modulate.a = 0.0
	# objective (top-left)
	objective = _label(root, 20, UITheme.GREY)
	objective.anchor_left = 0.03
	objective.anchor_top = 0.04
	objective.anchor_right = 0.5
	objective.anchor_bottom = 0.12
	objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objective.modulate.a = 0.0
	# toast (top-right)
	toast_label = _label(root, 19, UITheme.SILVER)
	toast_label.anchor_left = 0.55
	toast_label.anchor_right = 0.97
	toast_label.anchor_top = 0.04
	toast_label.anchor_bottom = 0.1
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	toast_label.modulate.a = 0.0
	# chapter title card
	chapter_title = _label(root, 44, UITheme.WHITE)
	chapter_title.anchor_left = 0.0
	chapter_title.anchor_right = 1.0
	chapter_title.anchor_top = 0.38
	chapter_title.anchor_bottom = 0.46
	chapter_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chapter_title.modulate.a = 0.0
	chapter_sub = _label(root, 22, UITheme.GREY)
	chapter_sub.anchor_left = 0.0
	chapter_sub.anchor_right = 1.0
	chapter_sub.anchor_top = 0.47
	chapter_sub.anchor_bottom = 0.52
	chapter_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chapter_sub.modulate.a = 0.0
	battery_label = _label(root, 16, UITheme.GREY)
	battery_label.anchor_left = 0.8
	battery_label.anchor_right = 0.97
	battery_label.anchor_top = 0.92
	battery_label.anchor_bottom = 0.97
	battery_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	battery_label.modulate.a = 0.0
	debug_label = _label(root, 15, Color(0.6, 1.0, 0.6))
	debug_label.add_theme_font_override("font", UITheme.mono())
	debug_label.anchor_left = 0.02
	debug_label.anchor_top = 0.6
	debug_label.anchor_right = 0.5
	debug_label.anchor_bottom = 0.98
	debug_label.visible = false
	fps_label = _label(root, 16, Color(0.7, 1.0, 0.7))
	fps_label.anchor_left = 0.85
	fps_label.anchor_right = 0.99
	fps_label.anchor_top = 0.01
	fps_label.anchor_bottom = 0.05
	fps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	fps_label.visible = Settings.show_fps
	EventBus.interaction_prompt_changed.connect(_on_prompt)
	EventBus.dialogue_line.connect(_on_line)
	EventBus.dialogue_cleared.connect(func(): _sub_time = minf(_sub_time, 0.4))
	EventBus.objective_changed.connect(_on_objective)
	EventBus.toast.connect(_on_toast)
	EventBus.chapter_title.connect(_on_chapter_title)
	EventBus.flashlight_battery_changed.connect(_on_battery)
	EventBus.flashlight_toggled.connect(_on_flash_toggled)
	Settings.settings_changed.connect(_apply_sub_size)
	_apply_sub_size()


func _on_flash_toggled(on: bool) -> void:
	if on:
		_battery_show = 2.5


func _label(parent: Control, size: int, color: Color) -> Label:
	var l := UITheme.label("", size, color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)
	parent.add_child(l)
	return l


func set_fps_visible(on: bool) -> void:
	if fps_label:
		fps_label.visible = on


func _apply_sub_size() -> void:
	subtitle_text.add_theme_font_size_override("font_size", [21, 26, 33][clampi(Settings.subtitle_size, 0, 2)])


func _on_prompt(text: String, can: bool) -> void:
	_crosshair_active = can
	(crosshair as _Crosshair).active = can
	crosshair.queue_redraw()
	var key := "[E] " if not Settings.is_mobile() else ""
	prompt.text = (key + text) if can and text != "" else ""


func _on_line(speaker: String, text: String, duration: float, style: String) -> void:
	if not Settings.subtitles:
		return
	subtitle_speaker.text = speaker
	subtitle_text.text = text
	var col := UITheme.WHITE
	if style.begins_with("witch"):
		col = UITheme.WITCH.lightened(0.15)
		subtitle_speaker.add_theme_color_override("font_color", UITheme.WITCH)
	elif style.begins_with("original"):
		col = UITheme.SILVER
		subtitle_speaker.add_theme_color_override("font_color", UITheme.SILVER.darkened(0.2))
	else:
		subtitle_speaker.add_theme_color_override("font_color", UITheme.GREY)
	if style.ends_with("scream"):
		subtitle_text.text = text.to_upper()
	subtitle_text.add_theme_color_override("font_color", col)
	_sub_time = duration + 0.3


func _on_objective(text: String) -> void:
	if text == "":
		return
	objective.text = "— " + text
	_obj_time = 7.0


func show_objective() -> void:
	objective.text = "— " + ChapterManager.current_objective_text()
	_obj_time = 4.0


func _on_toast(text: String) -> void:
	toast_label.text = text
	_toast_time = 4.0


func _on_chapter_title(_i: int, t: String, sub: String) -> void:
	chapter_title.text = t
	chapter_sub.text = sub
	var tw := create_tween()
	tw.tween_property(chapter_title, "modulate:a", 1.0, 2.0)
	tw.parallel().tween_property(chapter_sub, "modulate:a", 1.0, 2.5)
	tw.tween_interval(3.5)
	tw.tween_property(chapter_title, "modulate:a", 0.0, 2.0)
	tw.parallel().tween_property(chapter_sub, "modulate:a", 0.0, 2.0)


func _on_battery(ratio: float) -> void:
	if ratio < 0.25:
		_battery_show = 3.0
	battery_label.text = "Pile : %d%%" % int(ratio * 100.0)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_F3 and (OS.is_debug_build() or GameState.debug_mode):
		_debug = not _debug
		debug_label.visible = _debug


func _process(delta: float) -> void:
	_sub_time -= delta
	subtitle_panel.modulate.a = move_toward(subtitle_panel.modulate.a, 1.0 if _sub_time > 0.0 else 0.0, delta * 4.0)
	_obj_time -= delta
	objective.modulate.a = move_toward(objective.modulate.a, 0.85 if _obj_time > 0.0 else 0.0, delta * 1.5)
	_toast_time -= delta
	toast_label.modulate.a = move_toward(toast_label.modulate.a, 1.0 if _toast_time > 0.0 else 0.0, delta * 2.0)
	_battery_show -= delta
	battery_label.text = "Pile : %d%%" % int(float(GameState.run.get("battery", 1.0)) * 100.0)
	battery_label.modulate.a = move_toward(battery_label.modulate.a, 0.8 if _battery_show > 0.0 else 0.0, delta * 2.0)
	if fps_label.visible:
		fps_label.text = "%d FPS" % Engine.get_frames_per_second()
	if _debug:
		var game := get_parent()
		var sat_state := ""
		if game and game.get("satella") and game.satella:
			sat_state = game.satella.sm.current_name
		debug_label.text = "ENVY AWARENESS: %.1f (%s)\nSatella: %s\nChapter %d | deaths %d | loop %d\nZone: %s\nFragments: %s\nInserted: %s\nFPS %d" % [
			EnvyAwareness.value(), EnvyAwareness.stage_name(), sat_state, GameState.chapter(), GameState.deaths(), int(GameState.run["loop"]),
			game.player.current_zone if game and game.get("player") and game.player else "", str(GameState.run["fragments_found"]), str(GameState.run["fragments_inserted"]), Engine.get_frames_per_second()]


class _Crosshair extends Control:
	var active := false

	func _draw() -> void:
		if active:
			draw_arc(Vector2.ZERO, 7.0, 0, TAU, 24, Color(0.85, 0.8, 0.95, 0.8), 1.5, true)
			draw_circle(Vector2.ZERO, 1.6, Color(0.85, 0.8, 0.95, 0.9))
		else:
			draw_circle(Vector2.ZERO, 1.8, Color(0.8, 0.78, 0.85, 0.35))
