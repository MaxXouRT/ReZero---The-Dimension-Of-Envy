extends Zone
## THE LIBRARY OF MEMORIES — fragment 2 (the Forbidden Library, emptied).
## Puzzle: three black Gospels are scattered in the library. Each tells one
## of Subaru's deaths. Put them on the three lecterns "in the order I
## suffered them": the Capital (arc 1), the Mansion (arc 2), the Whale (arc 3).
## Then ring the bell on the reading desk.

const GOSPELS := ["gospel_capital", "gospel_mansion", "gospel_whale"]
const GOSPEL_NAMES := {"gospel_capital": "La Capitale", "gospel_mansion": "Le Manoir", "gospel_whale": "La Baleine", "": "— vide —"}
const SOLUTION := ["gospel_capital", "gospel_mansion", "gospel_whale"]

var stand_labels: Array[Label3D] = []
var stand_books: Array[MeshInstance3D] = []
var secret_shelf: Node3D
var exit_door: Door


func _init() -> void:
	display_name = "Bibliothèque des Souvenirs"
	ambience = {"amb_mansion_room": 0.45, "amb_drone_low": 0.35}
	rules = {"follow": false, "manifest": true, "hunt": false, "chase": false, "spot_kinds": ["room"]}


func build() -> void:
	set_bounds(Vector3(0, 4.5, 0), Vector3(14, 9, 22))
	Builder.room(self, Vector3.ZERO, Vector3(14, 9, 22), {"name": "Library", "wall": "wainscot", "floor": "wood_floor", "wainscot": false, "beams": true,
		"openings": [{"side": "s", "offset": 0.0, "width": 1.2, "height": 2.3}]})
	Builder.box(self, Vector3(4.0, 0.012, 18.0), Vector3(0, 0.008, 0), Builder.mat("carpet"), false)
	# wall-to-ceiling shelves
	var seed_i := 0
	for z in [-8.0, -4.0, 0.0, 4.0, 8.0]:
		Builder.bookshelf(self, Vector3(-6.75, 0, z), 90.0, 3.8, 7.2, seed_i)
		Builder.bookshelf(self, Vector3(6.75, 0, z), -90.0, 3.8, 7.2, seed_i + 50)
		seed_i += 1
	for x in [-4.5, 4.5]:
		Builder.bookshelf(self, Vector3(x, 0, -10.75), 0.0, 3.6, 7.2, seed_i + 90)
		seed_i += 1
	# freestanding rows
	for z in [-5.0, 1.0, 6.0]:
		for x in [-4.0, 4.0]:
			Builder.bookshelf(self, Vector3(x, 0, z), 0.0, 3.0, 3.0, seed_i + 200)
			Builder.bookshelf(self, Vector3(x, 0, z - 0.45), 180.0, 3.0, 3.0, seed_i + 300)
			seed_i += 1
	# ladders
	for z in [-6.0, 2.0]:
		var lad := Builder.box(self, Vector3(0.5, 6.5, 0.06), Vector3(-6.35, 3.2, z), Builder.mat("wood_dark"), false, Vector3(0, 0, -8))
		lad.name = "Ladder"
	# reading desk, lectern with the riddle, bell
	Builder.table_long(self, Vector3(0, 0, -1.5), 3.0, 90.0, false)
	var lect := Builder.node(self, "Lectern", Vector3(0, 0, -8.6))
	Builder.cyl(lect, 0.08, 0.2, 1.1, Vector3(0, 0.55, 0), Builder.mat("wood_dark"))
	Builder.box(lect, Vector3(0.6, 0.04, 0.45), Vector3(0, 1.15, 0), Builder.mat("wood_dark"), false, Vector3(-20, 0, 0))
	readable(Vector3(0, 1.2, -8.6), "note_library_riddle", "Lire l'inscription", true)
	Builder.cyl(self, 0.05, 0.08, 0.1, Vector3(0.5, 0.88, -1.5), Builder.mat("gilt"))
	var bell := Builder.interactable(self, Vector3(0.5, 0.95, -1.5), Vector3(0.4, 0.4, 0.4), "Faire sonner la cloche", _ring)
	bell.prompt_func = func() -> String: return "" if GameState.has_flag("library_solved") else "Faire sonner la cloche"
	# three lecterns (left -> right as seen from the riddle)
	for i in 3:
		var x := -2.4 + i * 2.4
		var st := Builder.node(self, "Stand%d" % i, Vector3(x, 0, -6.2))
		Builder.cyl(st, 0.07, 0.16, 1.0, Vector3(0, 0.5, 0), Builder.mat("wood_dark"))
		Builder.box(st, Vector3(0.5, 0.04, 0.38), Vector3(0, 1.04, 0), Builder.mat("wood_dark"), false, Vector3(-18, 0, 0))
		var book := Builder.box(st, Vector3(0.24, 0.05, 0.32), Vector3(0, 1.1, 0), Builder.mat("black"), false, Vector3(-18, 0, 0))
		book.visible = false
		stand_books.append(book)
		var lbl := Label3D.new()
		lbl.position = Vector3(0, 1.5, 0)
		lbl.pixel_size = 0.0022
		lbl.font_size = 48
		lbl.modulate = Color(0.75, 0.7, 0.85, 0.85)
		lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		st.add_child(lbl)
		stand_labels.append(lbl)
		var roman := Builder.wall_writing(st, Vector3(0, 0.75, 0.17), 0.0, ["I", "II", "III"][i], "unknown", 0.25)
		roman.name = "Roman"
		var inter := Builder.interactable(st, Vector3(0, 1.1, 0), Vector3(0.7, 0.6, 0.6), "", _cycle_stand.bind(i))
		inter.prompt_func = _stand_prompt.bind(i)
	# the three gospels
	_gospel("gospel_capital", Vector3(-0.6, 0.88, -0.9), "note_gospel_capital")
	_gospel("gospel_mansion", Vector3(5.6, 0.05, 9.0), "note_gospel_mansion")
	_gospel("gospel_whale", Vector3(-4.0, 1.37, 6.3), "note_gospel_whale")
	# secret shelf that slides to reveal the fragment
	secret_shelf = Builder.bookshelf(self, Vector3(0, 0, -10.3), 0.0, 2.2, 3.4, 777)
	if GameState.has_flag("library_solved"):
		secret_shelf.position.x = 2.3
	Builder.box(self, Vector3(1.2, 0.9, 0.4), Vector3(0, 0.45, -10.75), Builder.mat("stone_dark"))
	Pickups.fragment(self, Vector3(0, 1.15, -10.75), "library_of_memories", _on_fragment)
	# floating violet candles above the reading desk
	for i in 7:
		var p := Vector3(randf_range(-2.5, 2.5), randf_range(3.0, 4.5), randf_range(-4.0, 1.0))
		var holder := Spinner.new()
		holder.position = p
		holder.spin_speed = 0.0
		holder.bob_height = 0.08
		add_child(holder)
		Builder.candle(holder, Vector3.ZERO, true, i % 3 == 0, Color(0.7, 0.45, 1.0), 0.8, 6.0)
	Builder.fog_volume(self, Vector3(0, 6.5, 0), Vector3(14, 4, 22), 0.35)
	# exit back to the east corridor
	exit_door = Builder.door(self, Vector3(0, 0, 10.9), 180.0, {"name": "LibraryExit"})
	exit_door.set_meta("story_door", true)
	exit_door.set_portal(null, _exit)
	spot(Vector3(0, 0, -9.5), "room")
	spot(Vector3(4.0, 0, 8.5), "room")
	spot(Vector3(-5.6, 0, -9.0), "room")
	add_spawn("entrance", Vector3(0, 0.05, 9.6), 0.0)
	_refresh()


func _gospel(id: String, pos: Vector3, note: String) -> void:
	var vis := Builder.node(self, id, pos)
	Builder.box(vis, Vector3(0.22, 0.06, 0.3), Vector3(0, 0.03, 0), Builder.mat("black"), false)
	Builder.box(vis, Vector3(0.2, 0.065, 0.28), Vector3(0.008, 0.03, 0), Builder.mat("paper"), false)
	Pickups.item(self, vis, id, "Prendre l'évangile noir", "Évangile noir — " + GOSPEL_NAMES[id], "", func():
		DialogueManager.open_note(note)
		if not GameState.has_flag("library_hint"):
			GameState.set_flag("library_hint")
			DialogueManager.say("c2_books_hint", {"delay": 0.5}))


func _placed() -> Array:
	return GameState.get_flag("library_stands", ["", "", ""])


func _stand_prompt(i: int) -> String:
	if GameState.has_flag("library_solved"):
		return ""
	var cur: String = _placed()[i]
	return "Pupitre %s : %s  (changer)" % [["I", "II", "III"][i], GOSPEL_NAMES[cur]]


func _cycle_stand(_p: Node, i: int) -> void:
	if GameState.has_flag("library_solved"):
		return
	var placed: Array = _placed().duplicate()
	var owned: Array = []
	for g in GOSPELS:
		if GameState.has_item(g):
			owned.append(g)
	if owned.is_empty():
		DialogueManager.say_text("subaru", "Un pupitre vide. Il faut y poser quelque chose.", 2.5)
		return
	# cycle through owned gospels not used on another stand, then empty
	var options: Array = [""]
	for g in owned:
		if not placed.has(g) or placed[i] == g:
			options.append(g)
	var idx := options.find(placed[i])
	placed[i] = options[(idx + 1) % options.size()]
	GameState.set_flag("library_stands", placed)
	AudioManager.play_3d("book", stand_books[i].global_position, -4.0)
	_refresh()


func _refresh() -> void:
	var placed := _placed()
	for i in 3:
		stand_books[i].visible = placed[i] != "" or GameState.has_flag("library_solved")
		stand_labels[i].text = GOSPEL_NAMES[placed[i]] if placed[i] != "" else ""


func _ring(_p: Node) -> void:
	if GameState.has_flag("library_solved"):
		return
	AudioManager.play_3d("fragment_chime", to_global(Vector3(0.5, 1.0, -1.5)), -6.0, 8.0, 0.5)
	var placed := _placed()
	if placed == SOLUTION:
		GameState.set_flag("library_solved")
		DialogueManager.say("c2_books_right", {"delay": 1.0})
		AudioManager.play_3d("reality_bend", secret_shelf.global_position, 0.0, 10.0)
		var tw := create_tween()
		tw.tween_property(secret_shelf, "position:x", 2.3, 3.0).set_trans(Tween.TRANS_SINE)
	else:
		DialogueManager.say("c2_books_wrong", {"delay": 0.8})
		EnvyAwareness.add(1.5, "library_wrong")
		for l in get_tree().get_nodes_in_group("flicker_lights"):
			if l is FlickerLight and l.global_position.distance_to(global_position) < 25.0:
				l.blackout(1.6)
		if game and game.satella and game.satella.sm.current_name == "DORMANT":
			game.satella.sm.change("OBSERVING", {"pos": to_global(Vector3(randf_range(-3, 3), 0, -9.5)), "timeout": 8.0})


func _on_fragment() -> void:
	DialogueManager.say("c2_fragment2", {"delay": 0.6})
	if game and game.flow:
		game.flow.on_fragment(zone_id, "library_of_memories")


func _exit(_b: Node) -> void:
	var c: Zone = world.get_zone("east_corridor")
	var d: Door = c.lib_doors[int(GameState.get_flag("library_door", 0))]
	var pos := d.global_position + d.global_transform.basis.z * 0.9
	game.transition_teleport(pos, d.global_rotation.y + PI, "east_corridor")


func on_enter(_p: PlayerController) -> void:
	if not GameState.has_flag("seen_library"):
		GameState.set_flag("seen_library")
		DialogueManager.say("c2_library", {"delay": 1.0})
