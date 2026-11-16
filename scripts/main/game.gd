class_name Game
extends Node3D
## Game — root of a playthrough (scenes/main/game.tscn).
##
## Builds and wires every system, in dependency order, without circular
## references (systems talk through EventBus or through references handed
## down here):
##   Environment -> WorldDistortion -> Satella AI -> Chase -> Director ->
##   ChapterFlow -> MetaEnding -> MansionWorld (zones) -> Player -> UI.
## Then spawns Subaru at the current return point.

var environment_node: WorldEnvironment
var env: Environment
var sky_mat: ShaderMaterial
var distortion: WorldDistortionSystem
var satella: SatellaAI
var chase: ChaseController
var director: HorrorEventDirector
var flow: ChapterFlow
var meta: MetaEndingController
var world: MansionWorld
var player: PlayerController
var hud: HUD
var post: PostProcess
var overlay: HorrorOverlay
var pause_menu: PauseMenu
var reader: ReaderUI
var journal: Journal
var touch: TouchControls


func _ready() -> void:
	if not GameState.run.get("in_game", false):
		# Launched directly (editor F6): start a fresh run.
		GameState.new_game()
	_build_environment()
	distortion = WorldDistortionSystem.new()
	distortion.name = "WorldDistortion"
	add_child(distortion)
	satella = (load("res://scenes/satella/satella.tscn") as PackedScene).instantiate()
	add_child(satella)
	chase = ChaseController.new()
	chase.name = "ChaseController"
	add_child(chase)
	director = HorrorEventDirector.new()
	director.name = "HorrorEventDirector"
	add_child(director)
	flow = ChapterFlow.new()
	flow.name = "ChapterFlow"
	flow.game = self
	add_child(flow)
	meta = MetaEndingController.new()
	meta.name = "MetaEnding"
	meta.game = self
	add_child(meta)
	world = MansionWorld.new()
	world.name = "World"
	add_child(world)
	world.build_all(self)
	# UI before the player so it receives the first signals
	post = PostProcess.new()
	add_child(post)
	hud = HUD.new()
	add_child(hud)
	reader = ReaderUI.new()
	add_child(reader)
	journal = Journal.new()
	add_child(journal)
	overlay = HorrorOverlay.new()
	add_child(overlay)
	pause_menu = PauseMenu.new()
	pause_menu.game = self
	add_child(pause_menu)
	# player
	var ps: PackedScene = load("res://scenes/player/player.tscn")
	player = ps.instantiate()
	add_child(player)
	satella.player = player
	satella.world = world
	satella.chase = chase
	chase.setup(satella, player)
	distortion.player = player
	director.setup(player, satella, overlay, world)
	if Settings.is_mobile() or DisplayServer.is_touchscreen_available() and OS.has_feature("mobile"):
		touch = TouchControls.new()
		touch.player = player
		touch.game = self
		add_child(touch)
	_spawn()
	AudioManager.set_music_mode("game")
	Settings.settings_changed.connect(_apply_graphics)
	_apply_graphics()
	EnvyAwareness.reset_stage_tracking()
	if not Settings.is_mobile() and DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _spawn() -> void:
	var pos := GameState.get_checkpoint_position()
	var yaw := float(GameState.run["checkpoint"].get("yaw", 0.0))
	var first_time := String(GameState.run["checkpoint"].get("id", "")) == "start" and not GameState.has_flag("intro_done")
	if first_time:
		var bedroom: Zone = world.get_zone("bedroom")
		var sp: Dictionary = bedroom.spawn_points["wake"]
		pos = sp["pos"]
		yaw = sp["yaw"]
		GameState.run["checkpoint"]["pos"] = [pos.x, pos.y, pos.z]
		GameState.run["checkpoint"]["yaw"] = yaw
		GameState.checkpoint_snapshot = GameState.run.duplicate(true)
	player.teleport_to(pos, yaw)
	var zid := world.zone_at(pos + Vector3.UP * 0.5)
	if zid == "":
		zid = String(GameState.run["checkpoint"].get("zone", "bedroom"))
	world.enter_zone(zid)
	ChapterManager.set_objective(String(GameState.run.get("objective", "obj_light")) if GameState.run.get("objective", "") != "" else "obj_light")
	GameState.pending_respawn = false
	if first_time:
		flow.intro()
	else:
		flow.on_respawn()


## Short blink + teleport (impossible doors, loops, descents).
func transition_teleport(pos: Vector3, yaw: float, zone_id: String, fade := 0.18) -> void:
	if fade > 0.05:
		post.set_black(1.0)
		AudioManager.play_2d("whoosh", -14.0)
	player.teleport_to(pos, yaw)
	world.enter_zone(zone_id)
	if fade > 0.05:
		var tw := create_tween()
		tw.tween_property(post.fade_rect, "color:a", 0.0, fade).set_delay(0.05)


func set_sky_eye(v: float) -> void:
	if sky_mat:
		sky_mat.set_shader_parameter("eye_strength", v)


# ------------------------------------------------------------------ environment
func _build_environment() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky_mat = ShaderMaterial.new()
	sky_mat.shader = preload("res://shaders/void_sky.gdshader")
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.11, 0.07, 0.16)
	env.ambient_light_energy = 1.0
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.3
	env.tonemap_white = 5.0
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.1
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.fog_enabled = true
	env.fog_light_color = Color(0.07, 0.03, 0.1)
	env.fog_light_energy = 1.0
	env.fog_density = 0.045
	env.fog_sky_affect = 0.6
	env.fog_aerial_perspective = 0.2
	env.volumetric_fog_density = 0.018
	env.volumetric_fog_albedo = Color(0.32, 0.18, 0.42)
	env.volumetric_fog_emission = Color(0.012, 0.003, 0.02)
	env.volumetric_fog_emission_energy = 1.0
	env.volumetric_fog_anisotropy = 0.45
	env.volumetric_fog_length = 40.0
	env.volumetric_fog_ambient_inject = 0.25
	env.volumetric_fog_sky_affect = 0.3
	env.ssao_radius = 1.4
	env.ssao_intensity = 2.2
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.1
	env.adjustment_saturation = 0.85
	environment_node = WorldEnvironment.new()
	environment_node.environment = env
	add_child(environment_node)
	# no sun: only the faint glow of the void
	var void_light := DirectionalLight3D.new()
	void_light.light_color = Color(0.45, 0.3, 0.7)
	void_light.light_energy = 0.06
	void_light.rotation_degrees = Vector3(-60, 30, 0)
	void_light.shadow_enabled = false
	void_light.light_volumetric_fog_energy = 0.4
	add_child(void_light)


func _apply_graphics() -> void:
	var forward_plus := Settings.is_forward_plus()
	env.volumetric_fog_enabled = Settings.volumetric_fog and forward_plus
	env.fog_density = 0.012 if env.volumetric_fog_enabled else 0.035
	env.ssao_enabled = Settings.ssao and forward_plus
	env.glow_enabled = Settings.glow
	env.adjustment_brightness = Settings.brightness
	for l in get_tree().get_nodes_in_group("flicker_lights"):
		if l is Light3D and l.shadow_enabled and not Settings.shadows:
			l.shadow_enabled = false
	if player:
		player.flashlight.spot.shadow_enabled = Settings.shadows or Settings.quality > 0
