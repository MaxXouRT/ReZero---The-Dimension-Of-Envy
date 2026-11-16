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
	set_bounds(Vector3(0, 1.7, 0), Vector3(6, 3.4, 7))
	Builder.room(self, Vector3.ZERO, Vector3(6, 3.4, 7), {
		"name": "Bedroom", "wall": "wallpaper", "floor": "wood_floor",
		"openings": [
			{"side": "s", "offset": 0.0, "width": 1.2, "height": 2.3},
			{"side": "e", "offset": -1.0, "width": 1.3, "height": 1.9, "bottom": 0.9},
		],
	})
	var door := Builder.door(self, Vector3(0, 0, 3.6), 0.0, {"name": "BedroomDoor"})
	door.set_meta("story_door", true)
	# window to the void
	Builder.window(self, Vector3(3.1, 0.9, -1.0), -90.0, Vector2(1.3, 1.9))
	var void_light := Builder.light(self, Vector3(4.5, 2.2, -1.0), Color(0.45, 0.25, 0.75), 1.1, 9.0, true, 0.03)
	void_light.flicker_speed = 0.5
	Builder.interactable(self, Vector3(2.75, 1.7, -1.0), Vector3(0.3, 1.6, 1.3), "Regarder dehors", func(_p):
		DialogueManager.say("c1_window")
		GameState.set_flag("looked_window"), true)
	# furniture
	Builder.bed(self, Vector3(-1.6, 0, -2.2), 0.0)
	Builder.box(self, Vector3(0.45, 0.55, 0.4), Vector3(-0.45, 0.275, -3.0), Builder.mat("wood_dark"))
	Builder.candle(self, Vector3(-0.45, 0.55, -3.0), false, false)
	Builder.wardrobe(self, Vector3(-2.6, 0, 1.8), 90.0)
	Builder.desk(self, Vector3(2.2, 0, 2.4), 180.0)
	Builder.chair(self, Vector3(2.2, 0, 1.6), 0.0)
	Builder.box(self, Vector3(2.2, 0.01, 1.6), Vector3(0, 0.005, 0.2), Builder.mat("carpet"), false)
	Builder.painting(self, Vector3(0.4, 1.9, -3.38), 0.0, Vector2(0.7, 0.9), 1, 2.0)
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
