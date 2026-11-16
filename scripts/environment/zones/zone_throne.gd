extends Zone
## THE THRONE OF ENVY — fragment 5. The centre of the dimension.
## A broken platform floating in the void under a giant eye. She waits,
## seated. Three seal pillars hold her shadow hands back: light them.
## Each pillar wakes her a little more: she walks toward Subaru, shadow hands
## erupt from the floor where he is about to step (telegraphed by a violet
## ring). The true Satella freezes her for a moment after each pillar.

const PILLARS := [Vector3(-10, 0, 3), Vector3(10, 0, 3), Vector3(0, 0, -4.5)]
const THRONE := Vector3(0, 0, -12)

var pillar_lights: Array[OmniLight3D] = []
var pillar_gems: Array[MeshInstance3D] = []
var _hands_active := false
var _hand_t := 3.0
var _lit_count := 0
var _hazards: Array = []
var _fragment_spawned := false


func _init() -> void:
	display_name = "Le Trône de l'Envie"
	cluster = "throne"
	ambience = {"amb_throne": 0.8, "amb_void_wind": 0.5}
	ambient_profile = "void"
	rules = {"no_satella": true, "no_events": true}


func build() -> void:
	set_bounds(Vector3(0, 0, 0), Vector3(40, 30, 40))
	Builder.cyl(self, 16.0, 15.0, 1.2, Vector3(0, -0.6, 0), Builder.mat("void_stone"), true, 48)
	Builder.cyl(self, 15.0, 6.0, 9.0, Vector3(0, -5.7, 0), Builder.mat("void_stone"), false, 24)
	# floor inlay (a huge sigil)
	Builder.cyl(self, 7.0, 7.0, 0.02, Vector3(0, 0.01, 0), Builder.mat("iron"), false, 48)
	Builder.cyl(self, 6.6, 6.6, 0.025, Vector3(0, 0.012, 0), Builder.mat("void_stone"), false, 48)
	# broken outer ring of pillars
	for i in 14:
		var a := TAU * i / 14.0
		var h: float = [9.0, 4.0, 7.5, 2.0, 9.0, 5.5, 1.5][i % 7]
		Builder.pillar(self, Vector3(cos(a) * 14.5, 0, sin(a) * 14.5), h, 0.45, "void_stone")
	# the throne
	var t := Builder.node(self, "Throne", THRONE)
	for s in 3:
		Builder.box(t, Vector3(6.0 - s * 1.4, 0.35, 4.0 - s * 0.8), Vector3(0, 0.175 + s * 0.35, 0.3 - s * 0.2), Builder.mat("void_stone"))
	Builder.box(t, Vector3(1.8, 0.5, 1.4), Vector3(0, 1.3, -0.4), Builder.mat("fabric_dark"))
	Builder.box(t, Vector3(2.2, 5.5, 0.4), Vector3(0, 3.8, -1.2), Builder.mat("iron"))
	Builder.box(t, Vector3(2.6, 0.5, 0.5), Vector3(0, 6.6, -1.2), Builder.mat("gilt"))
	for sx in [-1.0, 1.0]:
		Builder.box(t, Vector3(0.3, 0.9, 1.4), Vector3(sx * 1.0, 1.75, -0.4), Builder.mat("iron"))
		# sculpted shadow hands rising behind the throne
		for k in 3:
			var arm := Builder.cyl(t, 0.05, 0.22, 4.0 + k, Vector3(sx * (1.8 + k * 0.7), 2.5 + k * 0.5, -1.6 - k * 0.3), Builder.mat("black"), false, 8)
			arm.rotation_degrees = Vector3(-15 - k * 6, 0, sx * (20 + k * 12))
	readable(THRONE + Vector3(2.4, 0.72, 1.6), "note_throne", "Lire l'inscription")
	# seal pillars
	for i in PILLARS.size():
		var p: Vector3 = PILLARS[i]
		Builder.pillar(self, p, 3.0, 0.35, "void_stone")
		var gem := Builder.cyl(self, 0.0, 0.25, 0.7, p + Vector3(0, 3.4, 0), Builder.mat("seal_fragment"), false, 5)
		pillar_gems.append(gem)
		var l := OmniLight3D.new()
		l.light_color = Color(0.5, 0.15, 0.8)
		l.light_energy = 0.6
		l.omni_range = 6.0
		l.position = p + Vector3(0, 3.5, 0)
		add_child(l)
		pillar_lights.append(l)
		var inter := Builder.interactable(self, p + Vector3(0, 1.4, 0), Vector3(1.2, 2.8, 1.2), "Allumer le pilier du sceau", _light_pillar.bind(i))
		inter.prompt_func = func() -> String: return "" if GameState.has_flag("pillar_%d" % i) else "Allumer le pilier du sceau"
	# floating debris around the platform
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	for i in 16:
		var a := rng.randf_range(0, TAU)
		Builder.floating_ruin(self, Vector3(cos(a) * rng.randf_range(24, 50), rng.randf_range(-12, 16), sin(a) * rng.randf_range(24, 50)), 300 + i, rng.randf_range(1.0, 2.2))
	var top := Builder.light(self, Vector3(0, 9, -4), Color(0.55, 0.2, 0.9), 1.6, 26.0, true, 0.05)
	top.flicker_speed = 0.4
	add_spawn("arrival", Vector3(0, 0.1, 12.5), 0.0)


func on_enter(p: PlayerController) -> void:
	if game and game.environment_node:
		game.set_sky_eye(1.0)
	if GameState.has_flag("throne_intro"):
		_restore()
		return
	GameState.set_flag("throne_intro")
	checkpoint("throne_entry", Vector3(0, 0.1, 12.5), 0.0)
	var sat := satella()
	sat.autonomous = false
	sat.sm.change("INTERACTING", {"pos": to_global(THRONE + Vector3(0, 1.1, -0.2)), "pose": SatellaBody.Pose.SIT, "persona": "witch", "look_at_player": true})
	sat.rotation.y = global_rotation.y
	p.lock("throne_intro")
	p.look_at_point(sat.head_pos(), 2.0)
	DialogueManager.say("c5_void", {"delay": 1.0})
	await get_tree().create_timer(5.5).timeout
	DialogueManager.say("c5_throne")
	await get_tree().create_timer(4.0).timeout
	DialogueManager.say("c5_pillars")
	ChapterManager.set_objective("obj_pillars")
	p.unlock("throne_intro")
	EnvyAwareness.add(4.0, "throne")


func _restore() -> void:
	_lit_count = 0
	for i in 3:
		if GameState.has_flag("pillar_%d" % i):
			_lit_count += 1
			_set_pillar_lit(i)
	var sat := satella()
	sat.autonomous = false
	if _lit_count == 0:
		sat.sm.change("INTERACTING", {"pos": to_global(THRONE + Vector3(0, 1.1, -0.2)), "pose": SatellaBody.Pose.SIT, "persona": "witch"})
	elif _lit_count < 3:
		_wake_her()


func _set_pillar_lit(i: int) -> void:
	pillar_lights[i].light_color = Color(0.85, 0.88, 1.0)
	pillar_lights[i].light_energy = 2.0
	pillar_gems[i].material_override = Builder.mat("silver_glow")


func _light_pillar(_p: Node, i: int) -> void:
	if GameState.has_flag("pillar_%d" % i):
		return
	GameState.set_flag("pillar_%d" % i)
	_lit_count += 1
	_set_pillar_lit(i)
	AudioManager.play_3d("seal_insert", to_global(PILLARS[i] + Vector3.UP * 3.0), 2.0, 14.0)
	EventBus.camera_shake.emit(0.3, 0.6)
	DialogueManager.say("c5_pillar_lit")
	EnvyAwareness.add(3.0, "pillar")
	if _lit_count == 1:
		_wake_her()
	elif _lit_count < 3:
		if game.chase.is_active():
			game.chase.stun(3.0)
			game.chase.config["speed"] = 2.9
		DialogueManager.say("original_help_3", {"delay": 1.0})
	else:
		_final_pillar()


func _wake_her() -> void:
	var sat := satella()
	sat.autonomous = true
	sat.body.set_pose(SatellaBody.Pose.SCREAM)
	AudioManager.play_jumpscare("witch_scream", -4.0)
	DialogueManager.say("c5_hands", {"delay": 1.0})
	_hands_active = true
	await get_tree().create_timer(1.2).timeout
	if _lit_count < 3:
		sat.sm.change("CHASING", {"id": "throne", "speed": 2.3 + _lit_count * 0.4, "walk": true, "catch_radius": 1.2})
	ChapterManager.set_objective("obj_pillars")


func _final_pillar() -> void:
	_hands_active = false
	for h in _hazards:
		if is_instance_valid(h):
			h.queue_free()
	_hazards.clear()
	if game.chase.is_active():
		game.chase.stop(true)
	var sat := satella()
	sat.autonomous = false
	sat.sm.change("INTERACTING", {"pos": to_global(Vector3(0, 0, -1.0)), "pose": SatellaBody.Pose.KNEEL})
	sat.body.set_persona("original")
	DialogueManager.say("original_help_3", {"delay": 0.5})
	await get_tree().create_timer(2.5).timeout
	sat.body.set_persona("witch")
	_spawn_fragment()


func _spawn_fragment() -> void:
	if _fragment_spawned:
		return
	_fragment_spawned = true
	ChapterManager.set_objective("obj_take_last")
	AudioManager.play_3d("fragment_chime", to_global(THRONE + Vector3(0, 2.0, 0)), 0.0, 14.0)
	Pickups.fragment(self, THRONE + Vector3(0, 2.0, 0.6), "throne_of_envy", func():
		DialogueManager.say("c5_fragment5")
		if game and game.flow:
			game.flow.on_fragment(zone_id, "throne_of_envy"))


# ------------------------------------------------------------------ shadow hands
func _process(delta: float) -> void:
	if not _hands_active:
		return
	var p := player()
	if p == null or p.dead or p.current_zone != zone_id:
		return
	_hand_t -= delta
	if _hand_t <= 0.0:
		_hand_t = randf_range(1.6, 3.0) / (1.0 + _lit_count * 0.3)
		var predicted := p.global_position + Vector3(p.velocity.x, 0, p.velocity.z) * 0.9 + Vector3(randf_range(-1.2, 1.2), 0, randf_range(-1.2, 1.2))
		_spawn_hand(to_local(predicted))


func _spawn_hand(local: Vector3) -> void:
	local.y = 0.0
	if Vector2(local.x, local.z).length() > 14.5:
		return
	var hand := Node3D.new()
	hand.position = local
	add_child(hand)
	_hazards.append(hand)
	var ring := Builder.cyl(hand, 0.9, 0.9, 0.02, Vector3(0, 0.03, 0), Builder.mat("witch_glow"), false, 24)
	var arm := Node3D.new()
	arm.position = Vector3(0, -2.6, 0)
	hand.add_child(arm)
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/shadow_tendril.gdshader")
	var seg := Builder.cyl(arm, 0.06, 0.28, 2.4, Vector3(0, 1.2, 0), mat, false, 10)
	seg.rotation_degrees.z = randf_range(-12, 12)
	for f in 5:
		var finger := Builder.cyl(arm, 0.015, 0.05, 0.7, Vector3(lerpf(-0.18, 0.18, f / 4.0), 2.6, 0), mat, false, 6)
		finger.rotation_degrees.z = lerpf(-35, 35, f / 4.0)
	AudioManager.play_3d("shadow_hands", hand.global_position, -2.0, 6.0)
	var tw := hand.create_tween()
	tw.tween_interval(1.1)
	tw.tween_property(arm, "position:y", 0.0, 0.18).set_trans(Tween.TRANS_BACK)
	tw.tween_callback(func(): _check_hit(hand))
	tw.tween_interval(0.5)
	tw.tween_callback(func(): _check_hit(hand))
	tw.tween_property(arm, "position:y", -2.8, 0.5)
	tw.tween_callback(func():
		_hazards.erase(hand)
		hand.queue_free())
	ring.visible = true


func _check_hit(hand: Node3D) -> void:
	var p := player()
	if p == null or p.dead or not is_instance_valid(hand):
		return
	var d := Vector2(p.global_position.x - hand.global_position.x, p.global_position.z - hand.global_position.z).length()
	if d < 0.95:
		EventBus.camera_shake.emit(0.8, 0.5)
		AudioManager.play_jumpscare("grab", 0.0)
		p.die("shadow_hands")
