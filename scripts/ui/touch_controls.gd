class_name TouchControls
extends CanvasLayer
## Mobile controls: virtual joystick (left half), drag-to-look (right half),
## buttons: interact, flashlight, run, crouch, journal, pause.
## Shown automatically on touch devices (Android / iOS exports).

var player: PlayerController
var game: Node
var _stick_index := -1
var _stick_origin := Vector2.ZERO
var _look_index := -1
var _stick_base: Control
var _stick_knob: Control
var _root: Control
const STICK_RADIUS := 110.0


func _ready() -> void:
	layer = 15
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = UITheme.get_theme()
	add_child(_root)
	_stick_base = _Circle.new()
	_stick_base.radius = STICK_RADIUS
	_stick_base.color = Color(0.5, 0.3, 0.7, 0.15)
	_stick_base.visible = false
	_root.add_child(_stick_base)
	_stick_knob = _Circle.new()
	_stick_knob.radius = 46.0
	_stick_knob.color = Color(0.8, 0.7, 0.95, 0.3)
	_stick_knob.visible = false
	_root.add_child(_stick_knob)
	var buttons := [
		["E", Vector2(0.9, 0.62), func(): if player: player.interaction.try_interact()],
		["LAMPE", Vector2(0.9, 0.42), func(): if player: player.flashlight.toggle()],
		["COURIR", Vector2(0.78, 0.8), Callable()],
		["ACCROUPIR", Vector2(0.93, 0.82), func(): if player: player.crouching = not player.crouching],
		["JOURNAL", Vector2(0.9, 0.08), func(): if game and game.journal: game.journal.open()],
		["II", Vector2(0.97, 0.08), func(): if game and game.pause_menu: game.pause_menu.toggle()],
	]
	for b in buttons:
		var btn := Button.new()
		btn.text = b[0]
		btn.add_theme_font_size_override("font_size", 22)
		btn.anchor_left = b[1].x - 0.05
		btn.anchor_right = b[1].x + 0.04
		btn.anchor_top = b[1].y - 0.05
		btn.anchor_bottom = b[1].y + 0.05
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.1, 0.05, 0.15, 0.35)
		sb.border_color = Color(0.5, 0.3, 0.7, 0.5)
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(40)
		btn.add_theme_stylebox_override("normal", sb)
		btn.add_theme_stylebox_override("pressed", sb)
		btn.add_theme_stylebox_override("hover", sb)
		btn.focus_mode = Control.FOCUS_NONE
		_root.add_child(btn)
		if b[0] == "COURIR":
			btn.button_down.connect(func(): if player: player.touch_sprint = true)
			btn.button_up.connect(func(): if player: player.touch_sprint = false)
		else:
			btn.pressed.connect(b[2])


func _input(event: InputEvent) -> void:
	if player == null or get_tree().paused:
		return
	var vs := get_viewport().get_visible_rect().size
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			if t.position.x < vs.x * 0.4 and _stick_index == -1:
				_stick_index = t.index
				_stick_origin = t.position
				_stick_base.position = t.position
				_stick_knob.position = t.position
				_stick_base.visible = true
				_stick_knob.visible = true
			elif t.position.x >= vs.x * 0.4 and _look_index == -1:
				_look_index = t.index
		else:
			if t.index == _stick_index:
				_stick_index = -1
				player.touch_move = Vector2.ZERO
				_stick_base.visible = false
				_stick_knob.visible = false
			elif t.index == _look_index:
				_look_index = -1
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if d.index == _stick_index:
			var off := (d.position - _stick_origin).limit_length(STICK_RADIUS)
			_stick_knob.position = _stick_origin + off
			player.touch_move = off / STICK_RADIUS
		elif d.index == _look_index:
			player.add_look(d.relative * Settings.touch_sensitivity)


class _Circle extends Control:
	var radius := 50.0
	var color := Color.WHITE

	func _draw() -> void:
		draw_circle(Vector2.ZERO, radius, color)
		draw_arc(Vector2.ZERO, radius, 0, TAU, 48, Color(color, color.a * 2.0), 2.0, true)
