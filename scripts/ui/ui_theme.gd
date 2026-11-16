class_name UITheme
extends RefCounted
## Visual language of the interface: black, deep violet, cold grey and a
## slightly desaturated white. Gothic serif typography (system serif fonts
## as placeholders — see documentation/ASSETS.md to ship a custom font).

const BLACK := Color(0.02, 0.01, 0.03, 0.92)
const VIOLET := Color(0.42, 0.2, 0.6)
const VIOLET_DEEP := Color(0.16, 0.06, 0.24)
const GREY := Color(0.55, 0.53, 0.6)
const WHITE := Color(0.86, 0.84, 0.9)
const SILVER := Color(0.8, 0.84, 0.97)
const WITCH := Color(0.62, 0.28, 0.88)

static var _theme: Theme
static var _serif: SystemFont
static var _mono: SystemFont


static func serif() -> Font:
	if _serif == null:
		_serif = SystemFont.new()
		_serif.font_names = PackedStringArray(["Cormorant Garamond", "Garamond", "Georgia", "Times New Roman", "Liberation Serif", "DejaVu Serif", "Noto Serif", "serif"])
		_serif.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	return _serif


static func mono() -> Font:
	if _mono == null:
		_mono = SystemFont.new()
		_mono.font_names = PackedStringArray(["Consolas", "Courier New", "Liberation Mono", "DejaVu Sans Mono", "monospace"])
	return _mono


static func panel_box(alpha := 0.9, border := VIOLET_DEEP) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.015, 0.008, 0.025, alpha)
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(2)
	s.content_margin_left = 24
	s.content_margin_right = 24
	s.content_margin_top = 18
	s.content_margin_bottom = 18
	s.shadow_color = Color(0, 0, 0, 0.6)
	s.shadow_size = 12
	return s


static func get_theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font = serif()
	t.default_font_size = 22
	t.set_color("font_color", "Label", WHITE)
	t.set_color("font_color", "Button", GREY)
	t.set_color("font_hover_color", "Button", WHITE)
	t.set_color("font_focus_color", "Button", WHITE)
	t.set_color("font_pressed_color", "Button", VIOLET)
	t.set_color("font_disabled_color", "Button", Color(0.3, 0.28, 0.33))
	var empty := StyleBoxEmpty.new()
	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(0.25, 0.1, 0.35, 0.25)
	hover.border_color = VIOLET
	hover.border_width_left = 2
	hover.content_margin_left = 14
	hover.content_margin_right = 14
	hover.content_margin_top = 6
	hover.content_margin_bottom = 6
	var normal := StyleBoxEmpty.new()
	normal.content_margin_left = 14
	normal.content_margin_right = 14
	normal.content_margin_top = 6
	normal.content_margin_bottom = 6
	t.set_stylebox("normal", "Button", normal)
	t.set_stylebox("hover", "Button", hover)
	t.set_stylebox("focus", "Button", hover)
	t.set_stylebox("pressed", "Button", hover)
	t.set_stylebox("disabled", "Button", normal)
	t.set_stylebox("panel", "PanelContainer", panel_box())
	t.set_stylebox("panel", "Panel", panel_box())
	# sliders / checkboxes / line edits
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.12, 0.08, 0.16)
	track.content_margin_top = 3
	track.content_margin_bottom = 3
	t.set_stylebox("slider", "HSlider", track)
	var fill := StyleBoxFlat.new()
	fill.bg_color = VIOLET
	fill.content_margin_top = 3
	fill.content_margin_bottom = 3
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", fill)
	var le := StyleBoxFlat.new()
	le.bg_color = Color(0.04, 0.02, 0.06, 0.95)
	le.border_color = VIOLET
	le.border_width_bottom = 2
	le.content_margin_left = 12
	le.content_margin_right = 12
	le.content_margin_top = 8
	le.content_margin_bottom = 8
	t.set_stylebox("normal", "LineEdit", le)
	t.set_stylebox("focus", "LineEdit", le)
	t.set_color("font_color", "LineEdit", WHITE)
	t.set_color("caret_color", "LineEdit", VIOLET)
	t.set_color("font_color", "CheckBox", GREY)
	t.set_color("font_hover_color", "CheckBox", WHITE)
	t.set_stylebox("normal", "CheckBox", normal)
	t.set_stylebox("hover", "CheckBox", hover)
	t.set_stylebox("focus", "CheckBox", hover)
	t.set_stylebox("pressed", "CheckBox", normal)
	t.set_color("font_color", "OptionButton", GREY)
	t.set_stylebox("normal", "OptionButton", le)
	t.set_stylebox("hover", "OptionButton", hover)
	t.set_stylebox("focus", "OptionButton", hover)
	t.set_stylebox("pressed", "OptionButton", hover)
	var tab_sel := StyleBoxFlat.new()
	tab_sel.bg_color = Color(0.2, 0.08, 0.3, 0.5)
	tab_sel.border_color = VIOLET
	tab_sel.border_width_bottom = 2
	tab_sel.content_margin_left = 16
	tab_sel.content_margin_right = 16
	tab_sel.content_margin_top = 6
	tab_sel.content_margin_bottom = 6
	t.set_stylebox("tab_selected", "TabBar", tab_sel)
	t.set_stylebox("tab_unselected", "TabBar", normal)
	t.set_stylebox("tab_hovered", "TabBar", hover)
	t.set_stylebox("panel", "TabContainer", panel_box(0.0, Color(0, 0, 0, 0)))
	t.set_stylebox("tab_selected", "TabContainer", tab_sel)
	t.set_stylebox("tab_unselected", "TabContainer", normal)
	t.set_stylebox("tab_hovered", "TabContainer", hover)
	t.set_color("font_selected_color", "TabContainer", WHITE)
	t.set_color("font_unselected_color", "TabContainer", GREY)
	t.set_color("font_hovered_color", "TabContainer", WHITE)
	t.set_color("default_color", "RichTextLabel", WHITE)
	t.set_font("normal_font", "RichTextLabel", serif())
	t.set_font_size("normal_font_size", "RichTextLabel", 22)
	t.set_stylebox("panel", "PopupMenu", panel_box())
	t.set_stylebox("scroll", "VScrollBar", track)
	t.set_stylebox("grabber", "VScrollBar", fill)
	_theme = t
	return t


## Styled button with UI sounds.
static func button(text: String, callback: Callable, size := 26) -> Button:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_size_override("font_size", size)
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_entered.connect(func(): AudioManager.play_ui("ui_hover"))
	b.focus_entered.connect(func(): AudioManager.play_ui("ui_hover"))
	b.pressed.connect(func():
		AudioManager.play_ui("ui_click")
		callback.call())
	return b


static func label(text: String, size := 22, color := WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l
