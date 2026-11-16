extends Zone
## THE CHAPEL OF ENVY — fragment 3.
## Stained glass windows: her, everywhere. Four candle stands before the
## altar: the ROSE, the KEY, the MOON, the SWORD.
## Correct order (silver handwriting): Rose, Key, Moon, Sword.
## Wrong flame: the Witch rises behind the altar -> chase through the forest.

const ORDER := ["rose", "key", "moon", "sword"]
const LABELS := {"rose": "la Rose", "key": "la Clé", "moon": "la Lune", "sword": "l'Épée"}

var candle_lights := {}
var altar_pos := Vector3(0, 0, -6.5)
var _busy := false


func _init() -> void:
	display_name = "La Chapelle de l'Envie"
	cluster = "forest"
	ambience = {"amb_throne": 0.35, "amb_void_wind": 0.4}
	ambient_profile = "void"
	rules = {"no_satella": true, "follow": false, "manifest": false}


func build() -> void:
	set_bounds(Vector3(0, 5, 0), Vector3(12, 10, 18))
	Builder.room(self, Vector3.ZERO, Vector3(12, 10, 18), {"name": "Chapel", "wall": "stone", "floor": "stone", "ceiling": "stone_dark", "wainscot": false, "beams": false,
		"openings": [
			{"side": "s", "offset": 0.0, "width": 2.4, "height": 3.6},
			{"side": "n", "offset": 0.0, "width": 3.2, "height": 5.5, "bottom": 2.6},
			{"side": "e", "offset": -3.0, "width": 1.2, "height": 4.0, "bottom": 2.5},
			{"side": "e", "offset": 3.0, "width": 1.2, "height": 4.0, "bottom": 2.5},
			{"side": "w", "offset": -3.0, "width": 1.2, "height": 4.0, "bottom": 2.5},
			{"side": "w", "offset": 3.0, "width": 1.2, "height": 4.0, "bottom": 2.5},
		]})
	# stained glass
	_glass(Vector3(0, 2.6, -9.0), 0.0, Vector2(3.2, 5.5))
	for z in [-3.0, 3.0]:
		_glass(Vector3(6.0, 2.5, z), -90.0, Vector2(1.2, 4.0))
		_glass(Vector3(-6.0, 2.5, z), 90.0, Vector2(1.2, 4.0))
	# gothic ribs
	for z in [-6.0, -2.0, 2.0, 6.0]:
		for sx in [-1.0, 1.0]:
			Builder.pillar(self, Vector3(sx * 5.4, 0, z), 10.0, 0.25, "stone")
	# pews
	for row in 6:
		for sx in [-1.0, 1.0]:
			var p := Vector3(sx * 2.4, 0, 6.5 - row * 1.5)
			Builder.box(self, Vector3(3.0, 0.08, 0.45), p + Vector3(0, 0.45, 0), Builder.mat("wood_dark"))
			Builder.box(self, Vector3(3.0, 0.6, 0.06), p + Vector3(0, 0.75, 0.24), Builder.mat("wood_dark"), false)
			Builder.box(self, Vector3(0.08, 0.45, 0.4), p + Vector3(-1.45, 0.22, 0), Builder.mat("wood_dark"), false)
			Builder.box(self, Vector3(0.08, 0.45, 0.4), p + Vector3(1.45, 0.22, 0), Builder.mat("wood_dark"), false)
	Builder.box(self, Vector3(2.0, 0.012, 15.0), Vector3(0, 0.008, 1.0), Builder.mat("carpet"), false)
	# altar and the statue of the woman with silver hair
	Builder.box(self, Vector3(6.0, 0.4, 3.5), Vector3(0, 0.2, -7.0), Builder.mat("marble"))
	Builder.box(self, Vector3(2.4, 1.0, 1.0), Vector3(0, 0.9, altar_pos.z), Builder.mat("marble"))
	Builder.box(self, Vector3(2.6, 0.02, 1.1), Vector3(0, 1.41, altar_pos.z), Builder.mat("fabric_red"), false)
	var st := Builder.statue(self, Vector3(0, 0.4, -8.4), 0.0, false)
	st.scale = Vector3(1.2, 1.4, 1.2)
	readable(Vector3(0.6, 1.43, altar_pos.z), "note_chapel_altar", "Lire l'inscription")
	# four candle stands with their symbols
	var xs := [-2.4, -0.8, 0.8, 2.4]
	var symbols := ["moon", "rose", "sword", "key"]   # visual order on the altar step
	for i in 4:
		var sym: String = symbols[i]
		var base := Vector3(xs[i], 0.4, -5.2)
		Builder.cyl(self, 0.04, 0.12, 1.1, base + Vector3(0, 0.55, 0), Builder.mat("gilt"))
		var lit := GameState.has_flag("chapel_solved") or (GameState.get_flag("chapel_progress", []) as Array).has(sym)
		var l := Builder.candle(self, base + Vector3(0, 1.1, 0), lit, true, Color(0.85, 0.85, 1.0), 1.0, 6.0)
		candle_lights[sym] = l
		var label := Builder.wall_writing(self, base + Vector3(0, 0.35, 0.14), 0.0, _symbol_text(sym), "unknown", 0.16)
		label.name = "Symbol"
		var inter := Builder.interactable(self, base + Vector3(0, 1.0, 0), Vector3(0.5, 0.8, 0.5), "", _light.bind(sym))
		inter.prompt_func = func() -> String:
			if GameState.has_flag("chapel_solved") or (GameState.get_flag("chapel_progress", []) as Array).has(sym):
				return ""
			return "Allumer la flamme de " + LABELS[sym]
	# ambient candles
	for i in 10:
		Builder.candle(self, Vector3(randf_range(-2.8, 2.8), 0.4, randf_range(-8.3, -7.6)), true, i % 4 == 0, Color(0.7, 0.45, 1.0), 0.6, 4.0)
	var l2 := Builder.light(self, Vector3(0, 6.0, -6.0), Color(0.55, 0.3, 0.85), 3.0, 18.0, true, 0.05)
	l2.flicker_speed = 0.6
	Builder.fog_volume(self, Vector3(0, 3, 0), Vector3(12, 6, 18), 0.3)
	if not GameState.has_fragment("chapel_of_envy") and GameState.has_flag("chapel_solved"):
		Pickups.fragment(self, altar_pos + Vector3(0, 1.75, 0), "chapel_of_envy", _on_fragment)
	add_spawn("door", Vector3(0, 0.05, 7.5), 0.0)


func _symbol_text(sym: String) -> String:
	match sym:
		"rose":
			return "— ROSE —"
		"key":
			return "— CLÉ —"
		"moon":
			return "— LUNE —"
		_:
			return "— ÉPÉE —"


func _glass(pos: Vector3, rot: float, size: Vector2) -> void:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = size
	mi.mesh = q
	mi.material_override = Builder.mat("stained_glass")
	mi.position = pos + Vector3(0, size.y * 0.5, 0)
	mi.rotation_degrees.y = rot
	add_child(mi)
	var l := OmniLight3D.new()
	l.light_color = Color(0.5, 0.15, 0.7)
	l.light_energy = 0.7
	l.omni_range = 5.0
	l.position = pos + Vector3(0, size.y * 0.5, 0) + Vector3(0, 0, 1.0).rotated(Vector3.UP, deg_to_rad(rot))
	add_child(l)


func on_enter(_p: PlayerController) -> void:
	if not GameState.has_flag("seen_chapel"):
		GameState.set_flag("seen_chapel")
		DialogueManager.say("c3_chapel", {"delay": 1.0})
		DialogueManager.say("c3_candles_hint", {"delay": 2.0})
		ChapterManager.set_objective("obj_candles")
		checkpoint("chapel", Vector3(0, 0.05, 7.5), 0.0)
		if not GameState.has_flag("mem_knows_two_satellas") and int(GameState.run.get("original_messages", 0)) >= 1:
			GameState.set_flag("mem_knows_two_satellas")


func _light(_p: Node, sym: String) -> void:
	if _busy or GameState.has_flag("chapel_solved"):
		return
	var progress: Array = (GameState.get_flag("chapel_progress", []) as Array).duplicate()
	if progress.has(sym):
		return
	var expected: String = ORDER[progress.size()]
	var l: FlickerLight = candle_lights[sym]
	AudioManager.play_3d("candle", l.global_position, -2.0)
	l.relight()
	if sym == expected:
		progress.append(sym)
		GameState.set_flag("chapel_progress", progress)
		if progress.size() == 4:
			GameState.set_flag("chapel_solved")
			DialogueManager.say("c3_candles_right", {"delay": 0.6})
			AudioManager.play_3d("fragment_chime", altar_pos, 0.0, 10.0)
			await get_tree().create_timer(1.5).timeout
			Pickups.fragment(self, altar_pos + Vector3(0, 1.75, 0), "chapel_of_envy", _on_fragment)
	else:
		_wrong()


func _wrong() -> void:
	_busy = true
	GameState.set_flag("chapel_progress", [])
	DialogueManager.say("c3_candle_wrong")
	await get_tree().create_timer(0.8).timeout
	for sym in candle_lights.keys():
		candle_lights[sym].kill()
	AudioManager.play_2d("whoosh", -2.0)
	EventBus.world_distortion.emit(0.8, 3.0)
	var sat := satella()
	if sat:
		sat.autonomous = false
		sat.sm.change("INTERACTING", {"pos": to_global(altar_pos + Vector3(0, 0.4, -0.9)), "pose": SatellaBody.Pose.STILL, "persona": "witch"})
		sat.face_toward(player().global_position)
		await get_tree().create_timer(2.2).timeout
		sat.body.set_pose(SatellaBody.Pose.SCREAM)
		AudioManager.play_jumpscare("witch_scream", -2.0)
		EventBus.camera_shake.emit(0.5, 0.8)
		await get_tree().create_timer(1.0).timeout
		sat.autonomous = true
		# THE FOREST chase: get away from her (far enough, long enough)
		sat.sm.change("CHASING", {"id": "forest", "speed": 4.7, "max_time": 28.0, "escape_distance": 22.0, "door_delay": 1.2})
		DialogueManager.say("original_help_1", {"delay": 1.5})
	_busy = false


func _on_fragment() -> void:
	DialogueManager.say("c3_fragment3", {"delay": 0.8})
	if game and game.flow:
		game.flow.on_fragment(zone_id, "chapel_of_envy")
