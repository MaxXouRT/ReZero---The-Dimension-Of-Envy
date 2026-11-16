extends Zone
## The black room — the stage of the fourth-wall confrontation.
## Nothing but darkness, a faintly reflective floor, a single light from
## above, and her in the centre. The MetaEndingController runs the scene.

var top_light: SpotLight3D


func _init() -> void:
	display_name = ""
	cluster = "black_room"
	ambience = {"amb_drone_low": 0.4}
	ambient_profile = "silent"
	rules = {"no_satella": true, "no_events": true}


func build() -> void:
	set_bounds(Vector3(0, 5, 0), Vector3(30, 10, 30))
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.01, 0.008, 0.012)
	floor_mat.roughness = 0.08
	floor_mat.metallic = 0.6
	Builder.box(self, Vector3(30, 0.2, 30), Vector3(0, -0.1, 0), floor_mat, true, Vector3.ZERO, "stone")
	var black := Builder.mat("black")
	Builder.box(self, Vector3(30, 10, 0.5), Vector3(0, 5, -15), black)
	Builder.box(self, Vector3(30, 10, 0.5), Vector3(0, 5, 15), black)
	Builder.box(self, Vector3(0.5, 10, 30), Vector3(-15, 5, 0), black)
	Builder.box(self, Vector3(0.5, 10, 30), Vector3(15, 5, 0), black)
	Builder.box(self, Vector3(30, 0.5, 30), Vector3(0, 10, 0), black)
	top_light = SpotLight3D.new()
	top_light.position = Vector3(0, 9, 0)
	top_light.rotation_degrees.x = -90
	top_light.spot_angle = 14.0
	top_light.spot_range = 12.0
	top_light.light_energy = 3.0
	top_light.light_color = Color(0.85, 0.8, 0.95)
	top_light.shadow_enabled = true
	add_child(top_light)
	add_spawn("arrival", Vector3(0, 0.05, 9.0), 0.0)


func on_enter(_p: PlayerController) -> void:
	if game and game.meta and not game.meta.running:
		game.meta.start(self)
