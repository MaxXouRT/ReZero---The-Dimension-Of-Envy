class_name PostProcess
extends CanvasLayer
## Screen-space post-processing (grain, vignette, violet grading, panic
## pulse, chromatic aberration, distortion waves, glitches) + fades.
## Accessibility: "reduce flashes" removes red/white flashes and caps
## glitches; "reduce camera motion" damps waves.

const SHADER := preload("res://shaders/post_process.gdshader")

var rect: ColorRect
var mat: ShaderMaterial
var fade_rect: ColorRect
var _panic := 0.0
var _glitch := 0.0
var _glitch_time := 0.0
var _wave := 0.0
var _wave_time := 0.0
var _flash := 0.0


func _ready() -> void:
	layer = 5
	process_mode = Node.PROCESS_MODE_ALWAYS
	rect = ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mat = ShaderMaterial.new()
	mat.shader = SHADER
	rect.material = mat
	add_child(rect)
	fade_rect = ColorRect.new()
	fade_rect.color = Color(0, 0, 0, 0)
	fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fade_rect)
	EventBus.player_panic_changed.connect(func(p): _panic = p)
	EventBus.screen_glitch.connect(glitch)
	EventBus.world_distortion.connect(func(i, d): wave(i, d))
	EventBus.jumpscare_started.connect(func(_id): flash(0.6))
	Settings.settings_changed.connect(_apply_settings)
	_apply_settings()


func _apply_settings() -> void:
	mat.set_shader_parameter("brightness", Settings.brightness)
	mat.set_shader_parameter("grain", 0.06 if Settings.film_grain else 0.0)


func glitch(strength: float, duration: float) -> void:
	if strength <= 0.0:
		return
	if Settings.reduce_flashes:
		strength *= 0.35
	_glitch = maxf(_glitch, strength)
	_glitch_time = maxf(_glitch_time, duration)
	AudioManager.glitch_audio(duration * 0.6)


func wave(intensity: float, duration: float) -> void:
	if Settings.reduce_camera_motion:
		intensity *= 0.3
	_wave = maxf(_wave, intensity)
	_wave_time = maxf(_wave_time, duration)


func flash(amount: float) -> void:
	if Settings.reduce_flashes:
		return
	_flash = maxf(_flash, amount)


func fade_to_black(duration: float) -> void:
	var tw := create_tween()
	tw.tween_property(fade_rect, "color:a", 1.0, duration)
	await tw.finished


## Return by Death awakening: Subaru's eyelids open (two slow blinks, then
## wide open), the world blurred by the post-process for a moment.
func open_eyes(duration := 2.4) -> void:
	var vs := get_viewport().get_visible_rect().size
	var lids: Array[TextureRect] = []
	for i in 2:
		var g := Gradient.new()
		g.set_color(0, Color(0, 0, 0, 1))
		g.set_color(1, Color(0, 0, 0, 0))
		g.set_offset(0, 0.82)
		var gt := GradientTexture2D.new()
		gt.gradient = g
		gt.fill_from = Vector2(0, 0) if i == 0 else Vector2(0, 1)
		gt.fill_to = Vector2(0, 1) if i == 0 else Vector2(0, 0)
		gt.width = 4
		gt.height = 256
		var r := TextureRect.new()
		r.texture = gt
		r.stretch_mode = TextureRect.STRETCH_SCALE
		r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		r.size = Vector2(vs.x, vs.y * 0.62)
		r.position = Vector2(0, 0 if i == 0 else vs.y * 0.38)
		add_child(r)
		lids.append(r)
	fade_rect.color.a = 0.0
	_glitch = 0.0
	_wave = 0.6
	_wave_time = duration
	var top_closed := 0.0
	var bot_closed := vs.y * 0.38
	var top_open := -vs.y * 0.62
	var bot_open := vs.y
	var tw := create_tween()
	# two heavy blinks, then the eyes open for good
	for k in [0.18, 0.35]:
		tw.tween_property(lids[0], "position:y", lerpf(top_closed, top_open, k), duration * 0.12).set_trans(Tween.TRANS_SINE)
		tw.parallel().tween_property(lids[1], "position:y", lerpf(bot_closed, bot_open, k), duration * 0.12).set_trans(Tween.TRANS_SINE)
		tw.tween_property(lids[0], "position:y", top_closed, duration * 0.08)
		tw.parallel().tween_property(lids[1], "position:y", bot_closed, duration * 0.08)
	tw.tween_property(lids[0], "position:y", top_open, duration * 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(lids[1], "position:y", bot_open, duration * 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tw.finished
	for r in lids:
		r.queue_free()


func fade_from_black(duration: float) -> void:
	fade_rect.color.a = 1.0
	var tw := create_tween()
	tw.tween_property(fade_rect, "color:a", 0.0, duration).set_trans(Tween.TRANS_SINE)
	await tw.finished


func set_black(a: float) -> void:
	fade_rect.color.a = a


func _process(delta: float) -> void:
	if _glitch_time > 0.0:
		_glitch_time -= delta
	else:
		_glitch = move_toward(_glitch, 0.0, delta * 2.0)
	if _wave_time > 0.0:
		_wave_time -= delta
	else:
		_wave = move_toward(_wave, 0.0, delta * 0.8)
	_flash = move_toward(_flash, 0.0, delta * 3.0)
	mat.set_shader_parameter("panic", _panic)
	mat.set_shader_parameter("glitch", _glitch)
	mat.set_shader_parameter("wave", _wave)
	mat.set_shader_parameter("aberration", _glitch * 1.5 + _panic * 0.5)
	mat.set_shader_parameter("red_flash", _flash * 0.6)
	mat.set_shader_parameter("vignette", 0.38 + _panic * 0.3)
