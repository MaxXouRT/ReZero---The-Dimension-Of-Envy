extends Zone
## Subaru's servant bedroom — where every loop of this dimension begins.
## Chapter 1: wake up in the dark, find the flashlight on the desk, read the
## notebook, look in the mirror (it does not show him).

var mirror: Mirror


func _init() -> void:
	display_name = "Chambre de Subaru"
	ambience = {"amb_mansion_room": 0.6, "amb_void_wind": 0.25}
	rules = {"no_satella": true, "follow": false, "manifest": false}


func build() -> void:
	set_bounds(Vector3(0, 1.9, 0), Vector3(6, 3.8, 7))
	Builder.room(self, Vector3.ZERO, Vector3(6, 3.8, 7), {
		"name": "Bedroom", "wall": "panel_teal", "floor": "tiles_diamond", "ceiling": "plaster_cream", "wainscot": false, "beams": false,
		"openings": [
			{"side": "s", "offset": 0.0, "width": 1.2, "height": 2.3},
			{"side": "e", "offset": -2.1, "width": 1.2, "height": 2.8, "bottom": 0.4},
			{"side": "e", "offset": 0.5, "width": 1.2, "height": 2.8, "bottom": 0.4},
		],
	})
	var door := Builder.door(self, Vector3(0, 0, 3.6), 0.0, {"name": "BedroomDoor"})
	door.set_meta("story_door", true)
	# two tall windows with heavy blue curtains, the violet night outside
	for wz in [-2.1, 0.5]:
		Builder.tall_window(self, Vector3(3.1, 0.4, wz), -90.0, Vector2(1.2, 2.8), true)
	var void_light := Builder.light(self, Vector3(4.6, 2.4, -0.8), Color(0.45, 0.3, 0.8), 1.3, 9.0, true, 0.03)
	void_light.flicker_speed = 0.5
	Builder.interactable(self, Vector3(2.75, 1.8, -2.1), Vector3(0.3, 1.8, 1.2), "Regarder dehors", func(_p):
		DialogueManager.say("c1_window")
		GameState.set_flag("looked_window"), true)
	# the golden bed with its canopy drape (as in the mansion)
	var bed := Builder.bed(self, Vector3(-0.3, 0, -2.3), 0.0, "fabric_white", false)
	Builder.box(bed, Vector3(1.6, 1.35, 0.1), Vector3(0, 0.82, -1.06), Builder.mat("gilt"))
	Builder.box(bed, Vector3(1.6, 0.65, 0.1), Vector3(0, 0.55, 1.06), Builder.mat("gilt"), false)
	for sx in [-0.78, 0.78]:
		Builder.cyl(bed, 0.06, 0.07, 1.5, Vector3(sx, 0.75, -1.06), Builder.mat("gilt"), false, 8)
		Builder.cyl(bed, 0.06, 0.07, 0.8, Vector3(sx, 0.4, 1.06), Builder.mat("gilt"), false, 8)
	Builder.box(self, Vector3(2.6, 2.9, 0.08), Vector3(-0.3, 2.05, -3.42), Builder.mat("curtain_blue"), false)
	Builder.box(self, Vector3(3.0, 0.35, 0.45), Vector3(-0.3, 3.45, -3.25), Builder.mat("panel_cream"), false)
	Builder.box(self, Vector3(3.0, 0.05, 0.47), Vector3(-0.3, 3.3, -3.25), Builder.mat("gilt"), false)
	for nx in [-1.55, 0.95]:
		Builder.box(self, Vector3(0.45, 0.55, 0.4), Vector3(nx, 0.275, -3.05), Builder.mat("wood_warm"))
		Builder.candle(self, Vector3(nx, 0.55, -3.05), false, false)
	Builder.box(self, Vector3(2.8, 0.012, 3.4), Vector3(-0.3, 0.006, -1.4), Builder.mat("carpet_navy"), false)
	Builder.wardrobe(self, Vector3(-2.6, 0, 1.8), 90.0)
	Builder.desk(self, Vector3(2.2, 0, 2.4), 180.0)
	Builder.chair(self, Vector3(2.2, 0, 1.6), 0.0)
	Builder.painting(self, Vector3(-2.88, 2.1, -2.6), 90.0, Vector2(0.6, 0.8), 1, 2.0)
	for sz in [-1.6, 2.6]:
		Builder.sconce(self, Vector3(-2.88, 2.3, sz), Vector3(1, 0, 0), false)
	# the notebook
	readable(Vector3(2.5, 0.82, 2.35), "note_awakening", "Lire le carnet")
	# the flashlight on the desk (glints faintly so the player can find it)
	if not GameState.has_item("flashlight"):
		var fl := Node3D.new()
		fl.position = Vector3(1.9, 0.83, 2.45)
		add_child(fl)
		Builder.cyl(fl, 0.03, 0.04, 0.24, Vector3(0, 0.03, 0), Builder.mat("iron"), false, 10, Vector3(0, 0, 90))
		var glint := OmniLight3D.new()
		glint.light_color = Color(0.7, 0.6, 0.9)
		glint.light_energy = 0.35
		glint.omni_range = 1.3
		glint.position = Vector3(0, 0.25, 0)
		fl.add_child(glint)
		Pickups.item(self, fl, "flashlight", "Prendre la lampe torche", "Lampe torche", "Une lampe torche moderne. Elle n'a rien à faire dans ce monde.\n\n[F] / clic droit : allumer / éteindre.", func():
			glint.queue_free()
			var p := player()
			if p:
				p.flashlight.give()
				p.flashlight.set_on(true)
			GameState.set_flag("has_flashlight")
			DialogueManager.say("c1_flashlight")
			ChapterManager.set_objective("obj_explore"))
	Pickups.battery(self, Vector3(-2.5, 1.0, 1.2), "battery_bedroom")
	# the mirror: it reflects the room... but not Subaru
	mirror = Mirror.new()
	mirror.size = Vector2(0.8, 1.5)
	mirror.position = Vector3(-2.88, 1.55, -0.6)
	mirror.rotation_degrees.y = 90.0
	add_child(mirror)
	Builder.interactable(self, Vector3(-2.6, 1.5, -0.6), Vector3(0.5, 1.4, 0.9), "Regarder le miroir", func(_p):
		if not GameState.has_flag("looked_mirror"):
			GameState.set_flag("looked_mirror")
			DialogueManager.say("c1_mirror")
		if game and game.director:
			game.director.notify("interact:mirror"))
	add_spawn("wake", Vector3(-1.1, 0.05, -0.6), 200.0)
