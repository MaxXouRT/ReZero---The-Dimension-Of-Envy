class_name PauseMenu
extends CanvasLayer
## Pause menu: Reprendre, Journal, Paramètres, Sauvegarder, Charger, Menu
## principal, Quitter.
##
## THE PAUSE TRAP: if the player hits Pause by reflex DURING a jumpscare
## window (JumpscareState.active), the menu does open... then Satella's
## shadow hands grab it, tear it off the window, and a far more violent
## jumpscare follows. It only happens inside that window: a normal pause
## always works. (Disabled during the meta finale, which has its own UI.)

signal resumed

var game: Node
var panel: PanelContainer
var dim: ColorRect
var info: Label
var is_open := false
var trap_running := false
var locked := false        ## set by the meta finale (pause replaced by narrative UI)


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = UITheme.get_theme()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	dim = ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.01, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	panel = PanelContainer.new()
	panel.anchor_left = 0.06
	panel.anchor_top = 0.18
	panel.anchor_right = 0.4
	panel.anchor_bottom = 0.84
	root.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	panel.add_child(vb)
	vb.add_child(UITheme.label("PAUSE", 38, UITheme.WHITE))
	info = UITheme.label("", 17, UITheme.GREY)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(info)
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 12
	vb.add_child(spacer)
	vb.add_child(UITheme.button("Reprendre", close))
	vb.add_child(UITheme.button("Journal", _journal))
	vb.add_child(UITheme.button("Paramètres", _settings))
	vb.add_child(UITheme.button("Sauvegarder (point de retour)", _save))
	vb.add_child(UITheme.button("Charger la dernière sauvegarde", _load))
	vb.add_child(UITheme.button("Menu principal", _main_menu))
	if not Settings.is_mobile():
		vb.add_child(UITheme.button("Quitter le jeu", func(): get_tree().quit()))
	visible = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if game and game.journal and game.journal.is_open:
			game.journal.close()
		elif game and game.reader and game.reader.is_open():
			game.reader.close()
		else:
			toggle()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		toggle()


func toggle() -> void:
	if trap_running or locked:
		return
	if is_open:
		close()
	else:
		open()


func can_open() -> bool:
	if ReturnByDeath.running or trap_running or locked:
		return false
	if game and game.player and game.player.dead:
		return false
	if game and ((game.journal and game.journal.is_open) or (game.reader and game.reader.is_open())):
		return false
	return true


func open() -> void:
	if not can_open():
		return
	var trap := JumpscareState.is_active()
	is_open = true
	visible = true
	info.text = "%s\n%s" % [ChapterManager.get_chapter(GameState.chapter()).get("title", ""), ChapterManager.current_objective_text()]
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	panel.get_child(0).get_child(3).grab_focus()
	if trap:
		_pause_trap()


func close() -> void:
	if trap_running:
		return
	is_open = false
	visible = false
	get_tree().paused = false
	if not Settings.is_mobile():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	resumed.emit()


func _pause_trap() -> void:
	trap_running = true
	JumpscareState.trap_count += 1
	EnvyAwareness.gain("pause_during_scare")
	await get_tree().create_timer(0.55, true).timeout
	# the menu shivers...
	AudioManager.play_2d("glitch", -4.0)
	var tw := create_tween()
	for i in 6:
		tw.tween_property(panel, "position:x", panel.position.x + randf_range(-8, 8), 0.04)
	await tw.finished
	DialogueManager.say("witch_pause_trap")
	var overlay: HorrorOverlay = game.overlay if game else null
	if overlay:
		await overlay.tear_screen([panel, dim])
	visible = false
	is_open = false
	panel.visible = true
	dim.visible = true
	get_tree().paused = false
	if not Settings.is_mobile():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if overlay:
		await overlay.face_jumpscare(true)
	trap_running = false


func _journal() -> void:
	if game and game.journal:
		visible = false
		game.journal.open(true)
		await game.journal.closed
		if is_open:
			visible = true


func _settings() -> void:
	var s := SettingsMenu.new()
	var host := Control.new()
	host.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(host)
	host.add_child(s)
	panel.visible = false
	await s.closed
	host.queue_free()
	panel.visible = true


func _save() -> void:
	if SaveManager.save_game():
		EventBus.toast.emit("Partie sauvegardée (dernier point de retour)")
	close()


func _load() -> void:
	if SaveManager.load_game():
		get_tree().paused = false
		get_tree().change_scene_to_file("res://scenes/main/game.tscn")


func _main_menu() -> void:
	SaveManager.save_game()
	get_tree().paused = false
	GameState.run["in_game"] = false
	get_tree().change_scene_to_file("res://scenes/ui/lobby.tscn")
