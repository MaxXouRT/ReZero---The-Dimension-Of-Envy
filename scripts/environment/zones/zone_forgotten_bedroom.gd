extends Zone
## THE FORGOTTEN BEDROOM — fragment 1.
## A twin bedroom from a failed loop. Puzzle chain:
##   1. Read the diary on the pillow (memory of loop 3).
##   2. Lift the sheet of the occupied bed: nobody... the shape is now in the
##      OTHER bed. The winding key fell on the floor.
##   3. Wind the music box: the lights die, the true Satella speaks, the
##      glass case opens.
##   4. Take the fragment.

var shape_a: Node3D
var shape_b: Node3D
var case_glass: Node3D
var room_lights: Array[FlickerLight] = []
var key_visual: Node3D
var _box_played := false


func _init() -> void:
	display_name = "La Chambre Oubliée"
	ambience = {"amb_mansion_room": 0.4, "amb_drone_low": 0.5}
	rules = {"no_satella": true, "follow": false, "manifest": false}


func build() -> void:
	set_bounds(Vector3(0, 1.7, 0), Vector3(6, 3.4, 9))
	Builder.room(self, Vector3.ZERO, Vector3(6, 3.4, 9), {"name": "Forgotten", "wall": "wallpaper_red", "floor": "wood_floor",
		"openings": [{"side": "s", "offset": 0.0, "width": 1.2, "height": 2.3}]})
	Builder.box(self, Vector3(3.6, 0.01, 2.4), Vector3(0, 0.006, -0.5), Builder.mat("carpet_violet"), false)
	# twin beds
	Builder.bed(self, Vector3(-1.6, 0, -2.6), 0.0, "fabric_white", false)
	Builder.bed(self, Vector3(1.6, 0, -2.6), 0.0, "fabric_white", false)
	shape_a = _sleeper(Vector3(-1.6, 0.68, -2.3))
	shape_b = _sleeper(Vector3(1.6, 0.68, -2.3))
	shape_b.visible = GameState.has_flag("lifted_sheet")
	shape_a.visible = not GameState.has_flag("lifted_sheet")
	# nightstand with dead flowers between the beds
	Builder.box(self, Vector3(0.5, 0.6, 0.45), Vector3(0, 0.3, -3.8), Builder.mat("wood_dark"))
	Builder.cyl(self, 0.06, 0.09, 0.25, Vector3(0, 0.72, -3.8), Builder.mat("glass_dark"))
	for i in 5:
		Builder.cyl(self, 0.004, 0.004, 0.3, Vector3(randf_range(-0.04, 0.04), 0.95, -3.8 + randf_range(-0.04, 0.04)), Builder.mat("leaf_dead"), false, 4, Vector3(randf_range(-20, 20), 0, randf_range(-20, 20)))
	room_lights.append(Builder.candle(self, Vector3(0.12, 0.6, -3.75), true, true, Color(1.0, 0.6, 0.35), 0.5, 4.5))
	# vanity with a mirror
	Builder.box(self, Vector3(1.2, 0.8, 0.45), Vector3(2.75, 0.4, 1.8), Builder.mat("wood_dark"))
	var m := Mirror.new()
	m.size = Vector2(0.8, 1.0)
	m.position = Vector3(2.85, 1.45, 1.8)
	m.rotation_degrees.y = -90.0
	add_child(m)
	# dresser + music box in its glass case
	Builder.box(self, Vector3(1.4, 0.95, 0.5), Vector3(-2.7, 0.475, 1.6), Builder.mat("wood_dark"))
	var box := Builder.box(self, Vector3(0.24, 0.14, 0.18), Vector3(-2.7, 1.02, 1.5), Builder.mat("gilt"), false)
	box.name = "MusicBox"
	Builder.box(self, Vector3(0.22, 0.02, 0.16), Vector3(-2.7, 1.1, 1.5), Builder.mat("wood_dark"), false)
	case_glass = Builder.node(self, "Case")
	Builder.box(case_glass, Vector3(0.5, 0.5, 0.4), Vector3(-2.7, 1.2, 1.75), Builder.mat("glass_dark"), true)
	if GameState.has_flag("music_box_played"):
		case_glass.visible = false
		case_glass.queue_free()
	Pickups.fragment(self, Vector3(-2.7, 1.25, 1.85), "forgotten_bedroom", _on_fragment)
	room_lights.append(Builder.sconce(self, Vector3(-2.85, 2.1, -1.0), Vector3(1, 0, 0), true))
	room_lights.append(Builder.sconce(self, Vector3(2.85, 2.1, -1.0), Vector3(-1, 0, 0), true))
	Builder.painting(self, Vector3(0, 2.0, -4.38), 0.0, Vector2(1.0, 0.7), 1, 11.0)
	Builder.wardrobe(self, Vector3(2.4, 0, 3.6), -90.0)
	# 1. the diary on the pillow
	readable(Vector3(-1.95, 0.83, -3.4), "note_forgotten_diary", "Lire le journal")
	# 2. lift the sheet
	var lift := Builder.interactable(self, Vector3(-1.6, 0.9, -2.3), Vector3(1.3, 0.6, 1.6), "Soulever le drap", _lift_sheet, true)
	lift.enabled = not GameState.has_flag("lifted_sheet")
	key_visual = Builder.node(self, "Key", Vector3(-0.9, 0.03, -1.4))
	Builder.cyl(key_visual, 0.008, 0.008, 0.12, Vector3(0, 0.01, 0), Builder.mat("gilt"), false, 6, Vector3(0, 0, 90))
	Builder.cyl(key_visual, 0.03, 0.03, 0.01, Vector3(-0.07, 0.01, 0), Builder.mat("gilt"), false, 10, Vector3(0, 0, 90))
	key_visual.visible = GameState.has_flag("lifted_sheet")
	Pickups.item(self, key_visual, "music_box_key", "Ramasser la clé", "Clé de remontage", "Une petite clé dorée. Elle a la forme d'une étoile à cinq branches.")
	# 3. the music box
	var wind := Builder.interactable(self, Vector3(-2.7, 1.1, 1.3), Vector3(0.6, 0.5, 0.5), "Examiner la boîte à musique", _music_box)
	wind.prompt_func = func() -> String:
		if GameState.has_flag("music_box_played"):
			return ""
		return "Remonter la boîte à musique" if GameState.has_item("music_box_key") else "Examiner la boîte à musique"
	add_spawn("inside", Vector3(0, 0.05, 3.4), 0.0)


func _sleeper(pos: Vector3) -> Node3D:
	var n := Builder.node(self, "Sleeper", pos)
	Builder.sphere(n, 0.3, Vector3(0, 0.1, 0.3), Builder.mat("fabric_white"), Vector3(1.3, 0.55, 2.4))
	Builder.sphere(n, 0.14, Vector3(0, 0.12, -0.55), Builder.mat("fabric_white"), Vector3(1.0, 0.8, 1.0))
	return n


func on_enter(_p: PlayerController) -> void:
	if not GameState.has_flag("seen_forgotten"):
		GameState.set_flag("seen_forgotten")
		DialogueManager.say("c2_forgotten_room", {"delay": 1.0})
		DialogueManager.say("c2_bed_figure", {"delay": 2.0})


func _lift_sheet(_p: Node) -> void:
	GameState.set_flag("lifted_sheet")
	AudioManager.play_2d("page", -2.0, 0.6)
	shape_a.visible = false
	key_visual.visible = true
	AudioManager.play_3d("pickup", key_visual.global_position, -10.0)
	DialogueManager.say_text("subaru", "Personne. ...Il y avait quelqu'un. J'en suis sûr.", 3.0)
	# when he looks away, the shape is in the other bed
	await get_tree().create_timer(2.5).timeout
	var p := player()
	while p and p.is_in_frustum(shape_b.global_position):
		await get_tree().create_timer(0.3).timeout
	shape_b.visible = true
	AudioManager.play_3d("creak", shape_b.global_position, -4.0, 5.0)
	EnvyAwareness.add(1.0, "sleeper")


func _music_box(_p: Node) -> void:
	if GameState.has_flag("music_box_played") or _box_played:
		return
	if not GameState.has_item("music_box_key"):
		DialogueManager.say("c2_music_box_hint")
		return
	_box_played = true
	GameState.remove_item("music_box_key")
	AudioManager.play_3d("music_box", to_global(Vector3(-2.7, 1.1, 1.5)), 0.0, 6.0)
	await get_tree().create_timer(4.0).timeout
	for l in room_lights:
		if l:
			l.blackout(5.0)
	var p := player()
	if p:
		p.flashlight.die_for(4.5)
		p.add_panic(0.5)
	AudioManager.play_2d("whoosh", -6.0)
	DialogueManager.say("c2_music_box")
	await get_tree().create_timer(4.6).timeout
	GameState.set_flag("music_box_played")
	if is_instance_valid(case_glass):
		case_glass.queue_free()
	AudioManager.play_3d("glass_crack", to_global(Vector3(-2.7, 1.2, 1.7)), -2.0)


func _on_fragment() -> void:
	DialogueManager.say("c2_fragment1")
	if game and game.flow:
		game.flow.on_fragment(zone_id, "forgotten_bedroom")
