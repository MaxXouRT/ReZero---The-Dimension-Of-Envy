extends Node
## Settings (autoload)
##
## Local player preferences: audio, graphics, controls, accessibility and the
## optional display name used by the meta ending. Persisted in
## user://settings.cfg (a plain local file — nothing else on the computer is
## ever read: the name only exists if the player typed it).

signal settings_changed

const PATH := "user://settings.cfg"

# --- Profile -----------------------------------------------------------------
var player_name: String = ""          ## Optional fictional first name typed by the player.
var first_launch_done: bool = false

# --- Audio (linear 0..1) -----------------------------------------------------
var vol_master: float = 0.9
var vol_music: float = 0.7
var vol_sfx: float = 0.9
var vol_ambience: float = 0.8
var vol_voice: float = 1.0
var vol_jumpscare: float = 0.85       ## Accessibility: jumpscare loudness.

# --- Graphics ----------------------------------------------------------------
var quality: int = 2                  ## 0 low, 1 medium, 2 high, 3 ultra
var volumetric_fog: bool = true
var ssao: bool = true
var glow: bool = true
var shadows: bool = true
var render_scale: float = 1.0
var fullscreen: bool = false
var vsync: bool = true
var fov: float = 75.0
var brightness: float = 1.0
var film_grain: bool = true

# --- Controls ----------------------------------------------------------------
var mouse_sensitivity: float = 0.0025
var gamepad_sensitivity: float = 2.6
var touch_sensitivity: float = 0.0045
var invert_y: bool = false
var toggle_crouch: bool = false

# --- Accessibility -----------------------------------------------------------
var reduce_flashes: bool = false      ## Removes strobe / white flashes.
var reduce_camera_motion: bool = false ## Removes head bob, sway, shakes are softened.
var subtitles: bool = true
var subtitle_size: int = 1            ## 0 small, 1 normal, 2 large

const SAVED_KEYS := [
	"player_name", "first_launch_done",
	"vol_master", "vol_music", "vol_sfx", "vol_ambience", "vol_voice", "vol_jumpscare",
	"quality", "volumetric_fog", "ssao", "glow", "shadows", "render_scale", "fullscreen", "vsync",
	"fov", "brightness", "film_grain",
	"mouse_sensitivity", "gamepad_sensitivity", "touch_sensitivity", "invert_y", "toggle_crouch",
	"reduce_flashes", "reduce_camera_motion", "subtitles", "subtitle_size",
]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_input_map()
	if is_mobile():
		# Sensible defaults for phones / tablets.
		quality = 0
		volumetric_fog = false
		ssao = false
		render_scale = 0.8
	load_settings()
	apply_display()


## True on Android / iOS exports or any device exposing a touch screen only.
func is_mobile() -> bool:
	return OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios")


## True when running the Forward+ renderer (volumetric fog, SSAO available).
func is_forward_plus() -> bool:
	if RenderingServer.get_rendering_device() == null:
		return false
	return String(ProjectSettings.get_setting_with_override("rendering/renderer/rendering_method")) == "forward_plus"


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	for key in SAVED_KEYS:
		if cfg.has_section_key("settings", key):
			set(key, cfg.get_value("settings", key))


func save_settings() -> void:
	var cfg := ConfigFile.new()
	for key in SAVED_KEYS:
		cfg.set_value("settings", key, get(key))
	cfg.save(PATH)
	settings_changed.emit()


## Returns the name Satella will use. Falls back to a neutral word when empty.
func get_display_name() -> String:
	var n := player_name.strip_edges()
	return n if n != "" else "toi"


func has_custom_name() -> bool:
	return player_name.strip_edges() != ""


func set_player_name(value: String) -> void:
	# Keep it short and printable; this is a display name only.
	var clean := ""
	for c in value.strip_edges():
		if c.unicode_at(0) >= 32 and clean.length() < 20:
			clean += c
	player_name = clean
	save_settings()


func apply_display() -> void:
	if Engine.is_editor_hint() or is_mobile():
		return
	if DisplayServer.get_name() == "headless":
		return
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != mode:
		DisplayServer.window_set_mode(mode)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
	get_viewport().scaling_3d_scale = clampf(render_scale, 0.5, 1.0)


## Applies a quality preset to the individual toggles.
func apply_quality_preset(level: int) -> void:
	quality = clampi(level, 0, 3)
	match quality:
		0:
			volumetric_fog = false; ssao = false; glow = true; shadows = true; render_scale = 0.75
		1:
			volumetric_fog = false; ssao = true; glow = true; shadows = true; render_scale = 0.9
		2:
			volumetric_fog = true; ssao = true; glow = true; shadows = true; render_scale = 1.0
		3:
			volumetric_fog = true; ssao = true; glow = true; shadows = true; render_scale = 1.0
	apply_display()
	save_settings()


# ------------------------------------------------------------------ input map
func _key(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = code  # physical => works on AZERTY (Z Q S D) and QWERTY (W A S D)
	return e


func _mouse(button: MouseButton) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = button
	return e


func _joy_button(b: JoyButton) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.button_index = b
	return e


func _joy_axis(axis: JoyAxis, value: float) -> InputEventJoypadMotion:
	var e := InputEventJoypadMotion.new()
	e.axis = axis
	e.axis_value = value
	return e


func _add_action(action: String, events: Array, deadzone := 0.25) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, deadzone)
	for ev in events:
		InputMap.action_add_event(action, ev)


func _setup_input_map() -> void:
	_add_action("move_forward", [_key(KEY_W), _key(KEY_UP), _joy_axis(JOY_AXIS_LEFT_Y, -1.0)])
	_add_action("move_back", [_key(KEY_S), _key(KEY_DOWN), _joy_axis(JOY_AXIS_LEFT_Y, 1.0)])
	_add_action("move_left", [_key(KEY_A), _key(KEY_LEFT), _joy_axis(JOY_AXIS_LEFT_X, -1.0)])
	_add_action("move_right", [_key(KEY_D), _key(KEY_RIGHT), _joy_axis(JOY_AXIS_LEFT_X, 1.0)])
	_add_action("look_left", [_joy_axis(JOY_AXIS_RIGHT_X, -1.0)], 0.15)
	_add_action("look_right", [_joy_axis(JOY_AXIS_RIGHT_X, 1.0)], 0.15)
	_add_action("look_up", [_joy_axis(JOY_AXIS_RIGHT_Y, -1.0)], 0.15)
	_add_action("look_down", [_joy_axis(JOY_AXIS_RIGHT_Y, 1.0)], 0.15)
	_add_action("sprint", [_key(KEY_SHIFT), _joy_button(JOY_BUTTON_LEFT_STICK), _joy_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)])
	_add_action("slow_walk", [_key(KEY_ALT), _key(KEY_V)])
	_add_action("crouch", [_key(KEY_C), _key(KEY_CTRL), _joy_button(JOY_BUTTON_B)])
	_add_action("interact", [_key(KEY_E), _mouse(MOUSE_BUTTON_LEFT), _joy_button(JOY_BUTTON_A)])
	_add_action("flashlight", [_key(KEY_F), _mouse(MOUSE_BUTTON_RIGHT), _joy_button(JOY_BUTTON_Y)])
	_add_action("journal", [_key(KEY_TAB), _key(KEY_J), _joy_button(JOY_BUTTON_BACK)])
	_add_action("pause", [_key(KEY_ESCAPE), _key(KEY_P), _joy_button(JOY_BUTTON_START)])
	_add_action("ui_close", [_key(KEY_ESCAPE), _joy_button(JOY_BUTTON_B)])
