class_name SettingsMenu
extends Control
## Settings: Audio / Graphismes / Commandes / Accessibilité / Profil.
## Shared by the lobby and the pause menu. Every change applies immediately
## and is written to user://settings.cfg when the menu closes.

signal closed

var tabs: TabContainer


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = UITheme.get_theme()
	process_mode = Node.PROCESS_MODE_ALWAYS
	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.01, 0.82)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var panel := PanelContainer.new()
	panel.anchor_left = 0.12
	panel.anchor_right = 0.88
	panel.anchor_top = 0.08
	panel.anchor_bottom = 0.92
	add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	panel.add_child(vb)
	vb.add_child(UITheme.label("PARAMÈTRES", 34, UITheme.WHITE))
	tabs = TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(tabs)
	_audio_tab()
	_graphics_tab()
	_controls_tab()
	_access_tab()
	_profile_tab()
	var back := UITheme.button("← Retour", close, 24)
	vb.add_child(back)
	back.grab_focus.call_deferred()


func close() -> void:
	Settings.save_settings()
	Settings.apply_display()
	closed.emit()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		close()


func _page(title: String) -> VBoxContainer:
	var sc := ScrollContainer.new()
	sc.name = title
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(sc)
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 10)
	sc.add_child(vb)
	return vb


func _slider(parent: Control, text: String, key: String, min_v: float, max_v: float, step: float, apply: Callable = Callable()) -> void:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 18)
	parent.add_child(hb)
	var l := UITheme.label(text, 21, UITheme.GREY)
	l.custom_minimum_size.x = 360
	hb.add_child(l)
	var s := HSlider.new()
	s.min_value = min_v
	s.max_value = max_v
	s.step = step
	s.value = float(Settings.get(key))
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.custom_minimum_size.y = 28
	hb.add_child(s)
	var val := UITheme.label(_fmt(s.value, step), 20, UITheme.WHITE)
	val.custom_minimum_size.x = 80
	hb.add_child(val)
	s.value_changed.connect(func(v: float):
		if typeof(Settings.get(key)) == TYPE_INT:
			Settings.set(key, int(v))
		else:
			Settings.set(key, v)
		val.text = _fmt(v, step)
		AudioManager.apply_volumes()
		if apply.is_valid():
			apply.call()
		Settings.settings_changed.emit())


func _fmt(v: float, step: float) -> String:
	if step >= 1.0:
		return str(int(v))
	if step < 0.001:
		return "%.4f" % v
	return "%d%%" % int(v * 100.0) if step <= 0.05 else "%.2f" % v


func _check(parent: Control, text: String, key: String, apply: Callable = Callable()) -> void:
	var c := CheckBox.new()
	c.text = text
	c.button_pressed = bool(Settings.get(key))
	c.add_theme_font_size_override("font_size", 21)
	parent.add_child(c)
	c.toggled.connect(func(on: bool):
		Settings.set(key, on)
		AudioManager.play_ui("ui_click")
		if apply.is_valid():
			apply.call()
		Settings.settings_changed.emit())


func _audio_tab() -> void:
	var p := _page("Audio")
	_slider(p, "Volume général", "vol_master", 0.0, 1.0, 0.01)
	_slider(p, "Musique", "vol_music", 0.0, 1.0, 0.01)
	_slider(p, "Effets", "vol_sfx", 0.0, 1.0, 0.01)
	_slider(p, "Ambiances", "vol_ambience", 0.0, 1.0, 0.01)
	_slider(p, "Voix", "vol_voice", 0.0, 1.0, 0.01)
	_slider(p, "Volume des jumpscares", "vol_jumpscare", 0.0, 1.0, 0.01)


func _graphics_tab() -> void:
	var p := _page("Graphismes")
	var hb := HBoxContainer.new()
	p.add_child(hb)
	var l := UITheme.label("Préréglage", 21, UITheme.GREY)
	l.custom_minimum_size.x = 360
	hb.add_child(l)
	var ob := OptionButton.new()
	for q in ["Bas (mobile)", "Moyen", "Élevé", "Ultra"]:
		ob.add_item(q)
	ob.selected = Settings.quality
	ob.item_selected.connect(func(i: int):
		Settings.apply_quality_preset(i)
		Settings.settings_changed.emit())
	hb.add_child(ob)
	_check(p, "Brouillard volumétrique (Forward+)", "volumetric_fog")
	_check(p, "Occlusion ambiante (SSAO)", "ssao")
	_check(p, "Lueur (glow)", "glow")
	_check(p, "Ombres dynamiques", "shadows")
	_check(p, "Grain de film", "film_grain")
	_check(p, "Plein écran", "fullscreen", Settings.apply_display)
	_check(p, "Synchronisation verticale", "vsync", Settings.apply_display)
	_slider(p, "Échelle de rendu", "render_scale", 0.5, 1.0, 0.05, Settings.apply_display)
	_slider(p, "Champ de vision", "fov", 60.0, 100.0, 1.0)
	_slider(p, "Luminosité", "brightness", 0.6, 1.6, 0.05)


func _controls_tab() -> void:
	var p := _page("Commandes")
	_slider(p, "Sensibilité souris", "mouse_sensitivity", 0.0005, 0.008, 0.0001)
	_slider(p, "Sensibilité manette", "gamepad_sensitivity", 0.5, 6.0, 0.1)
	_slider(p, "Sensibilité tactile", "touch_sensitivity", 0.001, 0.012, 0.0005)
	_check(p, "Inverser l'axe vertical", "invert_y")
	_check(p, "Accroupissement en bascule", "toggle_crouch")
	var help := UITheme.label("", 19, UITheme.GREY)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.text = "Clavier (AZERTY & QWERTY, touches physiques) :\n  Z Q S D / W A S D — se déplacer      Maj — courir      Alt / V — marcher lentement\n  C / Ctrl — s'accroupir      E / clic gauche — interagir      F / clic droit — lampe torche\n  Tab / J — journal      Échap / P — pause\nManette : stick gauche/droit, A interagir, B s'accroupir, Y lampe, L3/LT courir, Select journal, Start pause.\nMobile : joystick à gauche, glisser à droite pour regarder, boutons à l'écran."
	p.add_child(help)


func _access_tab() -> void:
	var p := _page("Accessibilité")
	_check(p, "Réduire les flashs lumineux", "reduce_flashes")
	_check(p, "Réduire les mouvements de caméra", "reduce_camera_motion")
	_check(p, "Sous-titres", "subtitles")
	_slider(p, "Taille des sous-titres", "subtitle_size", 0.0, 2.0, 1.0)
	_slider(p, "Volume des jumpscares", "vol_jumpscare", 0.0, 1.0, 0.01)


func _profile_tab() -> void:
	var p := _page("Profil")
	var info := UITheme.label("Prénom d'affichage (facultatif). Il est enregistré uniquement dans les paramètres locaux du jeu. Un prénom fictif convient très bien. Le jeu ne lit aucune autre information de ton ordinateur.", 19, UITheme.GREY)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	p.add_child(info)
	var le := LineEdit.new()
	le.text = Settings.player_name
	le.placeholder_text = "Laisser vide"
	le.max_length = 20
	le.custom_minimum_size = Vector2(420, 48)
	p.add_child(le)
	le.text_changed.connect(func(t: String): Settings.set_player_name(t))
	var clear := UITheme.button("Effacer le prénom", func():
		le.text = ""
		Settings.set_player_name(""), 20)
	p.add_child(clear)
