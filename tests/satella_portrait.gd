extends Node3D
## Visual QA: Satella portrait framed like the concept image.
## xvfb-run godot --path . --rendering-driver vulkan res://tests/satella_portrait.tscn -- /abs/out.png [original] [side]

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://portrait.png"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.012, 0.004, 0.02)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.11, 0.07, 0.16)
	env.ambient_light_energy = 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.3
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_bloom = 0.08
	env.volumetric_fog_enabled = not args.has("nofog")
	env.volumetric_fog_density = 0.02
	env.volumetric_fog_albedo = Color(0.35, 0.18, 0.5)
	env.volumetric_fog_length = 20.0
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.03, 0.02, 0.04)
	fm.roughness = 0.4
	Builder.box(self, Vector3(30, 0.2, 30), Vector3(0, -0.1, 0), fm, false)
	Builder.box(self, Vector3(30, 8, 0.4), Vector3(0, 4, -4), Builder.mat("wallpaper"), false)
	Builder.sconce(self, Vector3(-2.2, 2.2, -3.75), Vector3(0, 0, 1), true)
	var b := SatellaBody.new()
	add_child(b)
	b.twitch = 0.0
	b.set_pose(SatellaBody.Pose.STILL)
	if args.has("norim"):
		b.m_hair.set_shader_parameter("rim_strength", 0.0)
		b.rim_light.visible = false
		b.aura.visible = false
	if args.has("original"):
		b.set_persona("original")
	var cam := Camera3D.new()
	cam.fov = 42
	add_child(cam)
	if args.has("side"):
		cam.position = Vector3(2.6, 1.3, 1.6)
	else:
		cam.position = Vector3(0, 1.25, 3.4)
	cam.look_at(Vector3(0, 1.05, 0))
	b.look_target = cam.global_position
	var torch := SpotLight3D.new()
	torch.position = Vector3(0.8, 0.6, 2.8)
	torch.look_at_from_position(torch.position, Vector3(0, 1.0, 0))
	torch.spot_angle = 30
	torch.spot_range = 8
	torch.light_energy = 1.6
	torch.light_color = Color(0.85, 0.8, 0.95)
	add_child(torch)
	await get_tree().create_timer(3.0).timeout
	get_viewport().get_texture().get_image().save_png(out)
	print("saved ", out)
	get_tree().quit()
