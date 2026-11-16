class_name Journal
extends CanvasLayer
## Journal / inventory (Tab): current objective, the five seal fragments,
## items, and every note already read (click to read it again).
## Subaru's memory survives death, so the notes do too.

signal closed

var root: Control
var objective_label: Label
var fragments_box: VBoxContainer
var items_label: Label
var notes_list: ItemList
var is_open := false
var _from_pause := false


func _ready() -> void:
	layer = 21
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = UITheme.get_theme()
	root.visible = false
	add_child(root)
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0.01, 0.8)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var panel := PanelContainer.new()
	panel.anchor_left = 0.1
	panel.anchor_right = 0.9
	panel.anchor_top = 0.08
	panel.anchor_bottom = 0.92
	root.add_child(panel)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 40)
	panel.add_child(hb)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 12)
	hb.add_child(left)
	left.add_child(UITheme.label("JOURNAL", 34, UITheme.WHITE))
	left.add_child(UITheme.label("Objectif", 20, UITheme.VIOLET.lightened(0.3)))
	objective_label = UITheme.label("", 21, UITheme.WHITE)
	objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(objective_label)
	left.add_child(UITheme.label("Fragments du sceau", 20, UITheme.VIOLET.lightened(0.3)))
	fragments_box = VBoxContainer.new()
	left.add_child(fragments_box)
	left.add_child(UITheme.label("Objets", 20, UITheme.VIOLET.lightened(0.3)))
	items_label = UITheme.label("", 19, UITheme.GREY)
	items_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(items_label)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(spacer)
	left.add_child(UITheme.button("← Fermer", close, 22))
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(right)
	right.add_child(UITheme.label("Notes et messages", 20, UITheme.VIOLET.lightened(0.3)))
	notes_list = ItemList.new()
	notes_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	notes_list.add_theme_font_size_override("font_size", 19)
	notes_list.add_theme_stylebox_override("panel", UITheme.panel_box(0.4))
	notes_list.item_clicked.connect(func(i, _p, _b): _read(i))
	right.add_child(notes_list)


const ITEM_NAMES := {
	"flashlight": "Lampe torche", "music_box_key": "Clé de remontage",
	"gospel_capital": "Évangile — La Capitale", "gospel_mansion": "Évangile — Le Manoir", "gospel_whale": "Évangile — La Baleine",
}


func _refresh() -> void:
	objective_label.text = ChapterManager.current_objective_text()
	for c in fragments_box.get_children():
		c.queue_free()
	for f in GameState.FRAGMENTS:
		var found := GameState.has_fragment(f)
		var placed: bool = GameState.run["fragments_inserted"].has(f)
		var txt: String = GameState.FRAGMENT_NAMES[f] if found else "— ? —"
		if placed:
			txt += "   (placé)"
		fragments_box.add_child(UITheme.label(txt, 19, UITheme.SILVER if found else Color(0.35, 0.33, 0.38)))
	var names: Array = []
	for it in GameState.run["items"]:
		names.append(ITEM_NAMES.get(it, it))
	names.append("Piles de rechange : intégrées (%d%%)" % int(float(GameState.run.get("battery", 1.0)) * 100))
	items_label.text = ", ".join(names)
	notes_list.clear()
	for id in GameState.run["notes_read"]:
		var n := DialogueManager.get_note(id)
		var idx := notes_list.add_item(String(n.get("title", id)))
		notes_list.set_item_metadata(idx, id)
		match String(n.get("author", "")):
			"original":
				notes_list.set_item_custom_fg_color(idx, UITheme.SILVER)
			"witch":
				notes_list.set_item_custom_fg_color(idx, UITheme.WITCH.lightened(0.2))


func open(from_pause := false) -> void:
	_from_pause = from_pause
	is_open = true
	_refresh()
	root.visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	AudioManager.play_2d("page", -8.0)


func close() -> void:
	if not is_open:
		return
	is_open = false
	root.visible = false
	if not _from_pause:
		get_tree().paused = false
		if not Settings.is_mobile():
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	closed.emit()


func _read(i: int) -> void:
	var id: String = notes_list.get_item_metadata(i)
	var n := DialogueManager.get_note(id)
	close()
	EventBus.note_opened.emit(id, DialogueManager.format_text(String(n.get("title", ""))), DialogueManager.format_text(String(n.get("body", ""))), String(n.get("author", "")))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("journal"):
		get_viewport().set_input_as_handled()
		if is_open:
			close()
		elif not get_tree().paused:
			open()
	elif is_open and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause")):
		get_viewport().set_input_as_handled()
		close()
