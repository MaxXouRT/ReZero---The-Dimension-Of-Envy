extends Control
## End credits. Shows which ending was reached, rolls the credits, then
## returns to the lobby (which has changed if this was the TRUE ENDING).

const ENDINGS := {
	"a": ["ENDING A — ESCAPE", "Subaru a quitté la Dimension de l'Envie. Pour cette fois."],
	"b": ["ENDING B — ETERNAL LOOP", "La dimension s'est refermée. Le cycle recommence."],
	"c": ["ENDING C — THE REAL SATELLA", "Celle qui l'aimait assez pour le laisser partir l'a sauvé."],
	"true": ["TRUE ENDING — THE PLAYER", "Elle sait que tu existes."],
}

const CREDITS := """RE:ZERO — THE DIMENSION OF ENVY

Fan-game psychologique non officiel
inspiré de « Re:Zero − Starting Life in Another World »
(œuvre originale de Tappei Nagatsuki, illustrations de Shinichirou Otsuka).
Tous les droits sur l'univers original appartiennent à leurs détenteurs.

Direction · Game design · Programmation
Level design · IA · Narration · Sound design · UI
— un studio d'une seule nuit sans fin —

Moteur : Godot Engine 4

Sons, musiques et environnements : générés de façon procédurale
(placeholders destinés à être remplacés — voir documentation/)

Merci d'avoir regardé.
Elle aussi, t'a regardé.
"""

var _t := 0.0
var _scroll: Label
var _done := false


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	theme = UITheme.get_theme()
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	AudioManager.set_ambience({}, "silent")
	AudioManager.set_music_mode("credits")
	var ending := String(GameState.meta.get("last_ending", "a"))
	var e: Array = ENDINGS.get(ending, ENDINGS["a"])
	var title := UITheme.label(e[0], 48, UITheme.WITCH if ending == "true" else UITheme.WHITE)
	title.set_anchors_preset(Control.PRESET_FULL_RECT)
	title.anchor_bottom = 0.5
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	title.modulate.a = 0.0
	add_child(title)
	var sub := UITheme.label(e[1], 24, UITheme.GREY)
	sub.set_anchors_preset(Control.PRESET_FULL_RECT)
	sub.anchor_top = 0.52
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	sub.modulate.a = 0.0
	add_child(sub)
	var tw := create_tween()
	tw.tween_property(title, "modulate:a", 1.0, 2.0)
	tw.parallel().tween_property(sub, "modulate:a", 1.0, 3.0)
	tw.tween_interval(4.0)
	tw.tween_property(title, "modulate:a", 0.0, 1.5)
	tw.parallel().tween_property(sub, "modulate:a", 0.0, 1.5)
	await tw.finished
	_scroll = UITheme.label(CREDITS, 24, UITheme.WHITE)
	_scroll.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_scroll.size.x = get_viewport_rect().size.x
	_scroll.position = Vector2(0, get_viewport_rect().size.y + 20)
	add_child(_scroll)


func _process(delta: float) -> void:
	_t += delta
	if _scroll:
		_scroll.position.y -= delta * 45.0
		if _scroll.position.y + _scroll.size.y < -40.0:
			_back()


func _unhandled_input(event: InputEvent) -> void:
	if _t > 3.0 and (event.is_action_pressed("pause") or event.is_action_pressed("interact") or event.is_action_pressed("ui_accept")):
		_back()


func _back() -> void:
	if _done:
		return
	_done = true
	AudioManager.stop_all_music()
	get_tree().change_scene_to_file("res://scenes/ui/lobby.tscn")
