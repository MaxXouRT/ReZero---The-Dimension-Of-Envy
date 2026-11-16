extends Zone
## Dining room — the table is set for a dinner that never ends.
## Distortion: when the player turns his back, every chair turns to face him.

var chairs_a: Node3D
var chairs_b: Node3D


func _init() -> void:
	display_name = "Salle à manger"
	ambience = {"amb_mansion_room": 0.65, "amb_drone_low": 0.3}
	rules = {"follow": true, "manifest": true, "hunt": true, "chase": false, "spot_kinds": ["room"]}


func build() -> void:
	set_bounds(Vector3(0, 2.1, 0), Vector3(10, 4.2, 10))
	Builder.room(self, Vector3.ZERO, Vector3(10, 4.2, 10), {"name": "Dining", "wall": "wallpaper_red", "floor": "wood_floor",
		"openings": [{"side": "n", "offset": 0.0, "width": 1.2, "height": 2.3}]})
	Builder.box(self, Vector3(7.5, 0.01, 3.4), Vector3(0, 0.006, 0.8), Builder.mat("carpet"), false)
	Builder.table_long(self, Vector3(0, 0, 0.8), 6.2, 0.0)
	# two chair arrangements swapped by the WorldDistortionSystem
	chairs_a = Builder.node(self, "ChairsA")
	chairs_b = Builder.node(self, "ChairsB")
	for i in 6:
		var z := -1.9 + i * 1.08
		Builder.chair(chairs_a, Vector3(-1.0, 0, z), 90.0)
		Builder.chair(chairs_a, Vector3(1.0, 0, z), -90.0, i == 4)
		# variant B: every chair faces the north door (where Subaru stands)
		Builder.chair(chairs_b, Vector3(-1.0, 0, z), 180.0)
		Builder.chair(chairs_b, Vector3(1.0, 0, z), 180.0)
	Builder.chair(chairs_a, Vector3(0, 0, 4.4), 180.0)
	Builder.chair(chairs_b, Vector3(0, 0, 4.4), 180.0)
	if game and game.distortion:
		game.distortion.register("dining_chairs", [chairs_a, chairs_b], 0)
	else:
		chairs_b.visible = false
	for zc in [-0.8, 2.4]:
		Builder.candelabra(self, Vector3(0, 0.84, zc), true, zc < 0.0)
	Builder.fireplace(self, Vector3(4.65, 0, 0.5), -90.0, true)
	Builder.painting(self, Vector3(4.85, 2.6, 0.5), -90.0, Vector2(1.1, 1.0), 1, 4.0)
	Builder.grandfather_clock(self, Vector3(-4.6, 0, 3.6), 90.0)
	Builder.painting(self, Vector3(0, 2.4, 4.85), 180.0, Vector2(1.4, 1.8), 4, 1.0).add_to_group("paintings")
	Builder.painting(self, Vector3(-4.85, 2.3, -1.0), 90.0, Vector2(0.8, 1.1), 0, 6.0).add_to_group("paintings")
	Builder.box(self, Vector3(0.5, 1.0, 2.2), Vector3(-4.5, 0.5, -2.2), Builder.mat("wood_dark"))
	readable(Vector3(0.3, 0.86, -1.6), "note_dining", "Lire la carte")
	Pickups.battery(self, Vector3(-4.5, 1.02, -2.6), "battery_dining")
	spot(Vector3(0, 0, 4.3), "room")
	spot(Vector3(3.8, 0, 3.6), "room")
	spot(Vector3(-3.6, 0, -3.8), "room")
	rules["hunt_points"] = [to_global(Vector3(-3, 0, -3)), to_global(Vector3(3, 0, -3)), to_global(Vector3(3, 0, 4)), to_global(Vector3(-3, 0, 4))]


func on_enter(_p: PlayerController) -> void:
	if game and game.distortion:
		if GameState.chapter() >= 2 and game.distortion.current("dining_chairs") == 0:
			game.distortion.request("dining_chairs", 1)
