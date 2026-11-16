extends Zone
## The forest of the void — outside the mansion, there is no outside.
## Dead trees in violet fog, paths that lead nowhere, graves, abandoned
## buildings and fragments of architecture floating in the sky.
## Chapter 3: the two handwritings. Silver messages (the true Satella) give
## the real candle order; black scrawls (the Witch) lie.
## Walking too far from the path brings you back to it: the forest loops.

const RADIUS := 46.0
var messages_read := 0


func _init() -> void:
	display_name = "La forêt du néant"
	cluster = "forest"
	ambience = {"amb_forest": 0.8, "amb_void_wind": 0.5, "amb_drone_low": 0.25}
	ambient_profile = "forest"
	rules = {"follow": true, "manifest": true, "hunt": true, "chase": true, "spot_kinds": ["tree", "room"]}


func build() -> void:
	set_bounds(Vector3(0, 6, 0), Vector3(100, 20, 100))
	# ground
	Builder.box(self, Vector3(104, 0.4, 104), Vector3(0, -0.22, 0), Builder.mat("soil"), true, Vector3.ZERO, "dirt")
	# the path (old flagstones) from the mansion door to the chapel
	var rng := RandomNumberGenerator.new()
	rng.seed = 1710
	var z := 42.0
	while z > -44.0:
		var x := sin(z * 0.08) * 4.0
		Builder.box(self, Vector3(rng.randf_range(0.7, 1.1), 0.06, rng.randf_range(0.5, 0.8)), Vector3(x + rng.randf_range(-0.5, 0.5), 0.0, z), Builder.mat("stone"), false, Vector3(0, rng.randf_range(0, 40), 0))
		z -= rng.randf_range(0.9, 1.4)
	# trees (keep the path clear)
	var placed := 0
	var tries := 0
	while placed < 85 and tries < 600:
		tries += 1
		var p := Vector3(rng.randf_range(-48, 48), 0, rng.randf_range(-48, 48))
		var path_x := sin(p.z * 0.08) * 4.0
		if absf(p.x - path_x) < 3.5 and absf(p.z) < 46.0:
			continue
		if p.distance_to(Vector3(0, 0, -50)) < 12.0:
			continue
		Builder.dead_tree(self, p, rng.randf_range(5.0, 11.0), rng.randi())
		placed += 1
	# graveyard
	for i in 16:
		Builder.gravestone(self, Vector3(-14 + (i % 4) * 2.2 + rng.randf_range(-0.4, 0.4), 0, 6 + int(i / 4) * 2.4), rng.randf_range(-10, 10), i)
	# ruined cottage
	var cot := Builder.node(self, "Cottage", Vector3(18, 0, 14), -20)
	Builder.box(cot, Vector3(6, 3.0, 0.3), Vector3(0, 1.5, -3), Builder.mat("stone_dark"))
	Builder.box(cot, Vector3(0.3, 2.2, 6), Vector3(-3, 1.1, 0), Builder.mat("stone_dark"))
	Builder.box(cot, Vector3(0.3, 3.0, 3.5), Vector3(3, 1.5, -1.2), Builder.mat("stone_dark"))
	Builder.box(cot, Vector3(3, 1.0, 0.3), Vector3(-1.5, 0.5, 3), Builder.mat("stone_dark"))
	Builder.chair(cot, Vector3(0.5, 0, -1.0), 140.0)
	Builder.debris(cot, Vector3(0, 0, 0), 2.0, 14, 5)
	# broken gazebo
	var gaz := Builder.node(self, "Gazebo", Vector3(-20, 0, -14))
	for i in 6:
		var a := TAU * i / 6.0
		if i != 2:
			Builder.pillar(gaz, Vector3(cos(a) * 3.0, 0, sin(a) * 3.0), 3.5 if i != 4 else 1.6, 0.2, "stone")
	Builder.statue(gaz, Vector3.ZERO, 30.0, true)
	# floating architecture in the sky
	for i in 12:
		var a := rng.randf_range(0, TAU)
		var d := rng.randf_range(30.0, 70.0)
		Builder.floating_ruin(self, Vector3(cos(a) * d, rng.randf_range(12.0, 35.0), sin(a) * d), i + 40, rng.randf_range(1.0, 2.5))
	# lanterns along the path (only a few still burn)
	for zz in [36.0, 20.0, 4.0, -14.0, -30.0]:
		var lx := sin(zz * 0.08) * 4.0 + 1.6
		Builder.cyl(self, 0.05, 0.06, 2.4, Vector3(lx, 1.2, zz), Builder.mat("iron"))
		Builder.candle(self, Vector3(lx, 2.4, zz), zz > 0.0 or zz < -20.0, true, Color(0.75, 0.5, 1.0), 1.2, 8.0)
	# the mansion facade door we came through
	var frame := Builder.node(self, "MansionDoorway", Vector3(0, 0, 45.5))
	Builder.box(frame, Vector3(6, 6, 1.0), Vector3(0, 3, 0.4), Builder.mat("stone_dark"))
	var back := Builder.door(frame, Vector3(0, 0, -0.15), 0.0, {"double": true, "width": 3.0, "height": 4.2, "name": "BackToHall"})
	back.set_meta("story_door", true)
	back.set_portal(null, _back_to_hall)
	Builder.box(frame, Vector3(3.0, 4.2, 0.2), Vector3(0, 2.1, 0.55), Builder.mat("black"), false)
	# messages: silver (original) & black (witch)
	_message(Vector3(2.5, 1.6, 30.0), "msg_original_1", "original", "D'abord, la ROSE.")
	_message(Vector3(-3.5, 1.4, 24.0), "msg_witch_1", "witch", "L'ÉPÉE D'ABORD")
	_message(Vector3(-11.0, 1.0, 9.0), "msg_original_2", "original", "Ensuite, la CLÉ.")
	_message(Vector3(6.0, 1.5, 4.0), "msg_witch_2", "witch", "LA CLÉ DOIT RESTER ÉTEINTE")
	_message(Vector3(-17.5, 1.6, -12.0), "msg_original_3", "original", "Puis la LUNE.")
	_message(Vector3(16.5, 1.6, 12.5), "msg_witch_3", "witch", "NE CROIS PAS L'AUTRE")
	_message(Vector3(-4.0, 1.5, -26.0), "msg_witch_4", "witch", "LA LUNE PUIS LA ROSE")
	_message(Vector3(3.6, 1.8, -42.0), "msg_original_4", "original", "L'ÉPÉE en dernier.")
	Pickups.battery(self, Vector3(18.5, 0.05, 13.0), "battery_forest")
	Builder.fog_volume(self, Vector3(0, 1.5, 0), Vector3(100, 3.0, 100), 0.4)
	# Satella spots among the trees
	for i in 10:
		var a := TAU * i / 10.0
		spot(Vector3(cos(a) * 18.0, 0, sin(a) * 18.0), "tree")
	var hp: Array = []
	for i in 8:
		var a := TAU * i / 8.0
		hp.append(to_global(Vector3(cos(a) * 14.0 + sin(i) * 3.0, 0, sin(a) * 20.0)))
	rules["hunt_points"] = hp
	add_spawn("arrival", Vector3(0, 0.05, 43.0), 0.0)
	add_spawn("near_chapel", Vector3(0, 0.05, -40.0), 0.0)


func _message(pos: Vector3, note_id: String, author: String, short: String) -> void:
	var rot := rad_to_deg(atan2(-pos.x, 30.0 - pos.z))
	Builder.wall_writing(self, pos, rot, short, author, 0.1 if author == "original" else 0.13)
	if author == "original":
		var glow := OmniLight3D.new()
		glow.light_color = Color(0.75, 0.8, 1.0)
		glow.light_energy = 0.35
		glow.omni_range = 2.2
		glow.position = pos + Vector3(0, 0, 0.3).rotated(Vector3.UP, deg_to_rad(rot))
		add_child(glow)
	else:
		Builder.box(self, Vector3(0.6, 0.02, 0.6), Vector3(pos.x, 0.01, pos.z + 0.5), Builder.mat("black"), false)
	Builder.box(self, Vector3(0.5, 2.0, 0.5), pos - Vector3(0, pos.y - 1.0, 0) + Vector3(0, 0, -0.3).rotated(Vector3.UP, deg_to_rad(rot)), Builder.mat("bark" if author == "original" else "stone_dark"))
	Builder.interactable(self, pos, Vector3(1.4, 1.0, 1.0), "Lire le message", func(_p):
		_read(note_id)
		_check_understanding())


func _check_understanding() -> void:
	var o := int(GameState.run.get("original_messages", 0))
	var w := int(GameState.run.get("witch_messages", 0))
	if o >= 1 and w >= 1 and not GameState.has_flag("two_hands_line"):
		GameState.set_flag("two_hands_line")
		DialogueManager.say("c3_two_hands", {"delay": 0.8})
	if o >= 2 and w >= 2 and not GameState.has_flag("mem_knows_two_satellas"):
		GameState.set_flag("mem_knows_two_satellas")
		DialogueManager.say("c3_two_satellas", {"delay": 1.2})


func _back_to_hall(_b: Node) -> void:
	var hall: Zone = world.get_zone("grand_hall")
	var sp: Dictionary = hall.spawn_points["from_forest"]
	game.transition_teleport(sp["pos"], sp["yaw"], "grand_hall")


func _process(_delta: float) -> void:
	var p := player()
	if p == null or p.current_zone != zone_id:
		return
	var local := to_local(p.global_position)
	var to_chapel := local.z < -38.0 and absf(local.x) < 7.0
	if Vector2(local.x, local.z).length() > RADIUS and not to_chapel:
		# the forest loops: you are back on the path, a little further
		var sp: Dictionary = spawn_points["arrival"]
		game.transition_teleport(to_global(Vector3(sin(10.0 * 0.08) * 4.0, 0.05, 10.0)), sp["yaw"], zone_id, 0.25)
		if not GameState.has_flag("forest_loop_line"):
			GameState.set_flag("forest_loop_line")
			DialogueManager.say_text("subaru", "J'étais parti dans l'autre sens... Le chemin me ramène toujours.", 3.6)


func on_enter(_p: PlayerController) -> void:
	if not GameState.has_flag("seen_forest"):
		GameState.set_flag("seen_forest")
		DialogueManager.say("c3_forest", {"delay": 1.5})
