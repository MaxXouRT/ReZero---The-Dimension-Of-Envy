extends Node
## ReturnByDeath (autoload) — "Return by Death".
##
## When Subaru dies:
##  1. cinematic death: the camera collapses, shadow fingers close the screen,
##     the world is muffled (no gore: the horror is in the staging),
##  2. black screen, the signature Return-by-Death sound, a phrase of Satella
##     that depends on how many times he already died,
##  3. GameState rewinds the WORLD to the last return point but keeps the
##     MEMORY (deaths, Envy Awareness, knowledge),
##  4. the game scene reloads; ChapterFlow.on_respawn() plays the loop
##     reaction ("Subaru... tu es revenu.", "Encore cette sensation...").
##
## It is an autoload so the overlay survives the scene reload, making the
## rewind feel continuous.

const DEATH_SHADER := preload("res://shaders/death_overlay.gdshader")
const GAME_SCENE := "res://scenes/main/game.tscn"

var layer: CanvasLayer
var black: ColorRect
var fingers: ColorRect
var title: Label
var phrase: Label
var counter: Label
var running := false
var _fake := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = CanvasLayer.new()
	layer.layer = 90
	add_child(layer)
	fingers = ColorRect.new()
	fingers.set_anchors_preset(Control.PRESET_FULL_RECT)
	var m := ShaderMaterial.new()
	m.shader = DEATH_SHADER
	fingers.material = m
	fingers.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fingers.visible = false
	layer.add_child(fingers)
	black = ColorRect.new()
	black.color = Color(0, 0, 0, 0)
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(black)
	title = _label(34, Color(0.72, 0.6, 0.85), 0.42)
	phrase = _label(26, Color(0.85, 0.82, 0.9), 0.52)
	counter = _label(16, Color(0.5, 0.45, 0.55), 0.62)
	EventBus.player_died.connect(_on_player_died)


func _label(size: int, color: Color, y: float) -> Label:
	var l := Label.new()
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.anchor_top = y
	l.anchor_bottom = y + 0.08
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_font_override("font", UITheme.serif())
	l.modulate.a = 0.0
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(l)
	return l


func _phrase_for(deaths: int) -> Array:
	# [speaker style, text]
	match deaths:
		1:
			return ["", ""]
		2:
			return ["witch", "Je t'aime."]
		3:
			return ["witch", "Je t'aime. Je t'aime."]
		4:
			return ["witch", "Je t'aime je t'aime je t'aime je t'aime"]
		_:
			var s := ""
			for i in mini(18, 4 + deaths):
				s += "je t'aime "
			return ["witch", s.strip_edges().to_upper() if deaths >= 7 else s.strip_edges()]


func _on_player_died(cause: String) -> void:
	if running:
		return
	running = true
	_fake = false
	var tree := get_tree()
	var p := tree.get_first_node_in_group("player") as PlayerController
	AudioManager.set_muffle(0.85)
	AudioManager.stop_all_music()
	DialogueManager.clear()
	if p:
		var tw := p.create_tween().set_parallel(true)
		tw.tween_property(p.cam_pivot, "rotation:z", deg_to_rad(-38.0 if not Settings.reduce_camera_motion else -8.0), 1.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(p.head, "position:y", 0.35, 1.6).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	await _shadow_close(1.6)
	# --- the rewind
	GameState.register_death(cause)
	SaveManager.save_meta()
	var deaths := GameState.deaths()
	AudioManager.play_2d("return_by_death", 0.0, 1.0, "Jumpscare")
	title.text = "— RETURN BY DEATH —"
	counter.text = "Boucle %d" % (int(GameState.run["loop"]) + 1)
	var ph := _phrase_for(deaths)
	phrase.text = ph[1]
	phrase.add_theme_color_override("font_color", Color(0.6, 0.3, 0.85) if ph[0] == "witch" else Color(0.85, 0.85, 0.95))
	await _fade(title, 1.0, 1.2)
	if phrase.text != "":
		await _fade(phrase, 1.0, 1.0)
	await _fade(counter, 1.0, 0.6)
	await tree.create_timer(2.2).timeout
	GameState.rewind_to_checkpoint()
	SaveManager.save_game()
	var tw2 := create_tween().set_parallel(true)
	tw2.tween_property(title, "modulate:a", 0.0, 0.8)
	tw2.tween_property(phrase, "modulate:a", 0.0, 0.8)
	tw2.tween_property(counter, "modulate:a", 0.0, 0.8)
	await tw2.finished
	AudioManager.set_muffle(0.0)
	fingers.visible = false
	tree.paused = false
	tree.change_scene_to_file(GAME_SCENE)
	await tree.create_timer(0.15).timeout
	var tw3 := create_tween()
	tw3.tween_property(black, "color:a", 0.0, 0.25)   # the eyelids take over
	await tw3.finished
	running = false


## Shadow fingers creep in, then the singularity collapses to black.
func _shadow_close(duration: float) -> void:
	fingers.visible = true
	var m := fingers.material as ShaderMaterial
	m.set_shader_parameter("progress", 0.0)
	m.set_shader_parameter("collapse", 0.0)
	var tw := create_tween()
	tw.tween_method(func(v: float): m.set_shader_parameter("progress", v), 0.0, 1.0, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw.finished
	black.color.a = 1.0
	fingers.visible = false


func _fade(c: CanvasItem, to: float, d: float) -> void:
	var tw := create_tween()
	tw.tween_property(c, "modulate:a", to, d)
	await tw.finished


## Used by the Horror Director's "fake death": same staging, then she says
## "...not yet" and gives the world back.
func fake_death() -> void:
	if running:
		return
	running = true
	_fake = true
	var p := get_tree().get_first_node_in_group("player") as PlayerController
	if p:
		p.lock("fake_death")
	AudioManager.set_muffle(0.85)
	await _shadow_close(1.2)
	AudioManager.play_2d("return_by_death", -2.0, 1.0, "Jumpscare")
	title.text = "— RETURN BY DEATH —"
	await _fade(title, 1.0, 1.0)
	await get_tree().create_timer(1.6).timeout
	AudioManager.play_2d("glitch", 0.0)
	title.text = "— RETURN BY DE̴A̷T̶H —"
	await get_tree().create_timer(0.4).timeout
	title.modulate.a = 0.0
	DialogueManager.say("witch_fake_death")
	await get_tree().create_timer(3.6).timeout
	AudioManager.set_muffle(0.0)
	var tw := create_tween()
	tw.tween_property(black, "color:a", 0.0, 1.2)
	await tw.finished
	if p and is_instance_valid(p):
		p.unlock("fake_death")
	EnvyAwareness.add(2.0, "fake_death")
	running = false
