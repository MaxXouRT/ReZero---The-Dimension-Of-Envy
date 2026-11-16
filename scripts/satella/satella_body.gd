class_name SatellaBody
extends Node3D
## Satella's procedural body (placeholder for a rigged model, see ASSETS.md).
##
## Built from primitives arranged as a small skeleton (hips, torso, head,
## arms, hair strands, dress, shadow tendrils) and animated procedurally:
## poses blend between idle / still / walk / run / reach / sit / scream.
##
## Visual identity:
##  * long silver hair, black-violet dress, pale skin;
##  * WITCH persona: a face swallowed by shadow with two violet eyes, black
##    shadow hands writhing behind her, violet aura;
##  * ORIGINAL persona: a softer, more human face, faint silver shimmer,
##    no shadow hands.

const SAT_SHADER := preload("res://shaders/satella.gdshader")
const TENDRIL_SHADER := preload("res://shaders/shadow_tendril.gdshader")

enum Pose { IDLE, STILL, WALK, RUN, REACH, SIT, SCREAM, KNEEL }

var pose: int = Pose.IDLE
var persona := "witch"
var look_target := Vector3.INF          ## world point the head tracks (INF = none)
var head_tilt := 0.0                    ## extra roll for unsettling tilts (radians)
var head_turn_offset := 0.0             ## extra yaw (lobby variations)
var twitch := 0.25                      ## 0..1 random jerky micro-movements
var tendril_amount := 1.0               ## 0..1 how far the shadow hands extend
var mouth_open := 0.0

var hips: Node3D
var torso: Node3D
var neck: Node3D
var head: Node3D
var arm_l: Node3D
var arm_r: Node3D
var fore_l: Node3D
var fore_r: Node3D
var dress: MeshInstance3D
var mouth: MeshInstance3D
var eyes: Array[MeshInstance3D] = []
var face_shadow: MeshInstance3D
var hair_strands: Array[Node3D] = []
var tendrils: Array[Node3D] = []
var aura: OmniLight3D
var face_light: OmniLight3D

var _mats: Array[ShaderMaterial] = []
var _tendril_mats: Array[ShaderMaterial] = []
var m_dress: ShaderMaterial
var m_skin: ShaderMaterial
var m_hair: ShaderMaterial
var m_eye: StandardMaterial3D
var _t := 0.0
var _twitch_timer := 0.0
var _twitch_rot := Vector3.ZERO
var _dissolve := 0.0
var speed_hint := 0.0                   ## current movement speed for gait


func _ready() -> void:
	_build()
	set_persona(persona)


func _sat_mat(albedo: Color, rough: float, rim: float, flutter := 0.0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SAT_SHADER
	m.set_shader_parameter("albedo", albedo)
	m.set_shader_parameter("roughness", rough)
	m.set_shader_parameter("rim_strength", rim)
	m.set_shader_parameter("flutter", flutter)
	_mats.append(m)
	return m


func _mesh(parent: Node3D, mesh: Mesh, pos: Vector3, mat: Material, rot := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	mi.scale = scl
	parent.add_child(mi)
	return mi


func _capsule(r: float, h: float) -> CapsuleMesh:
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = h
	c.radial_segments = 12
	c.rings = 4
	return c


func _cone(rt: float, rb: float, h: float, seg := 20) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = rt
	c.bottom_radius = rb
	c.height = h
	c.radial_segments = seg
	c.rings = 6
	return c


func _sphere(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 20
	s.rings = 10
	return s


func _build() -> void:
	m_dress = _sat_mat(Color(0.035, 0.018, 0.05), 0.85, 0.45, 0.6)
	m_skin = _sat_mat(Color(0.58, 0.53, 0.58), 0.6, 0.25)
	m_hair = _sat_mat(Color(0.68, 0.68, 0.74), 0.45, 0.7, 0.9)
	m_hair.set_shader_parameter("rim_color", Color(0.75, 0.7, 0.95))
	var m_inner := _sat_mat(Color(0.01, 0.005, 0.015), 0.9, 0.2, 0.3)
	m_eye = StandardMaterial3D.new()
	m_eye.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m_eye.albedo_color = Color(0.75, 0.35, 1.0)
	m_eye.emission_enabled = true
	m_eye.emission = Color(0.7, 0.25, 1.0)
	m_eye.emission_energy_multiplier = 5.0
	var m_black := StandardMaterial3D.new()
	m_black.albedo_color = Color(0, 0, 0)
	m_black.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	hips = Node3D.new()
	hips.name = "Hips"
	hips.position = Vector3(0, 0.98, 0)
	add_child(hips)
	# Dress: layered cones, slightly asymmetric, trailing on the floor
	dress = _mesh(hips, _cone(0.17, 0.62, 1.02, 28), Vector3(0, -0.5, 0), m_dress)
	_mesh(hips, _cone(0.15, 0.55, 0.95, 20), Vector3(0, -0.5, 0.02), m_inner, Vector3(0.05, 0, 0))
	_mesh(hips, _cone(0.2, 0.32, 0.28, 20), Vector3(0, 0.02, 0), m_dress)
	# tattered hem: ragged strips of cloth trailing on the floor
	var rng_h := RandomNumberGenerator.new()
	rng_h.seed = 11
	for i in 18:
		var a := TAU * i / 18.0 + rng_h.randf_range(-0.1, 0.1)
		var len_s := rng_h.randf_range(0.25, 0.55)
		var strip := _mesh(hips, BoxMesh.new(), Vector3(sin(a) * 0.6, -0.98 - len_s * 0.3, cos(a) * 0.6), m_dress,
			Vector3(rng_h.randf_range(-0.3, 0.3) + 0.45 * cos(a), a, -0.45 * sin(a)), Vector3(0.12, len_s, 0.01))
		strip.name = "Tatter"
	torso = Node3D.new()
	torso.name = "Torso"
	torso.position = Vector3(0, 0.12, 0)
	hips.add_child(torso)
	_mesh(torso, _cone(0.2, 0.15, 0.5, 18), Vector3(0, 0.25, 0), m_dress, Vector3.ZERO, Vector3(1, 1, 0.75))
	# collar / shoulders
	_mesh(torso, _capsule(0.07, 0.48), Vector3(0, 0.47, 0), m_dress, Vector3(0, 0, PI / 2))
	neck = Node3D.new()
	neck.name = "Neck"
	neck.position = Vector3(0, 0.52, 0)
	torso.add_child(neck)
	_mesh(neck, _capsule(0.045, 0.16), Vector3(0, 0.06, 0), m_skin)
	head = Node3D.new()
	head.name = "Head"
	head.position = Vector3(0, 0.18, 0)
	neck.add_child(head)
	_mesh(head, _sphere(0.105), Vector3(0, 0.0, 0), m_skin, Vector3.ZERO, Vector3(0.92, 1.15, 0.98))
	# face shadow (the Witch's face is swallowed by darkness)
	face_shadow = _mesh(head, _sphere(0.1), Vector3(0, -0.012, 0.074), m_black, Vector3.ZERO, Vector3(0.8, 1.0, 0.36))
	# eyes
	for sx in [-0.036, 0.036]:
		var socket := _mesh(head, _sphere(0.021), Vector3(sx, 0.012, 0.088), m_black, Vector3.ZERO, Vector3(1.3, 0.8, 0.6))
		socket.name = "Socket"
		var e := _mesh(head, _sphere(0.0085), Vector3(sx, 0.012, 0.112), m_eye)
		eyes.append(e)
	mouth = _mesh(head, BoxMesh.new(), Vector3(0, -0.055, 0.1), m_black, Vector3.ZERO, Vector3(0.035, 0.006, 0.01))
	# Hair: crown + long strands falling down the back and framing the face
	_mesh(head, _sphere(0.118), Vector3(0, 0.025, -0.012), m_hair, Vector3.ZERO, Vector3(1.0, 1.0, 1.04))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 22:
		var a := lerpf(-2.6, 2.6, float(i) / 21.0)
		var strand := Node3D.new()
		strand.position = Vector3(sin(a) * 0.105, 0.04, cos(a) * 0.1 - 0.02)
		var front := absf(a) < 0.9
		if front:
			strand.position.z = -0.03
			strand.position.x = sin(a) * 0.12
		head.add_child(strand)
		var length := rng.randf_range(0.95, 1.3) if not front else rng.randf_range(0.55, 0.8)
		if front and absf(a) < 0.5:
			# side curtains hide part of the face
			strand.position = Vector3(signf(a + 0.001) * 0.1, 0.03, 0.05)
			length = rng.randf_range(0.6, 0.85)
		var mesh := _mesh(strand, BoxMesh.new(), Vector3(0, -length * 0.5, 0), m_hair, Vector3.ZERO, Vector3(rng.randf_range(0.03, 0.055), length, rng.randf_range(0.012, 0.025)))
		mesh.name = "Strand"
		strand.set_meta("phase", rng.randf() * TAU)
		strand.set_meta("base_rot", Vector3(rng.randf_range(0.05, 0.25) if not front else -0.05, 0, rng.randf_range(-0.08, 0.08)))
		hair_strands.append(strand)
	# Arms
	arm_l = _arm(-1.0)
	arm_r = _arm(1.0)
	fore_l = arm_l.get_node("Fore")
	fore_r = arm_r.get_node("Fore")
	# Shadow tendrils (the Witch's hands)
	for i in 6:
		var root := Node3D.new()
		root.name = "Tendril%d" % i
		root.position = Vector3(lerpf(-0.18, 0.18, i / 5.0), 0.3, -0.12)
		root.rotation = Vector3(-0.5 - rng.randf() * 0.4, lerpf(-0.9, 0.9, i / 5.0) + PI, 0)
		torso.add_child(root)
		var parent: Node3D = root
		var m := ShaderMaterial.new()
		m.shader = TENDRIL_SHADER
		_tendril_mats.append(m)
		for s in 7:
			var seg := Node3D.new()
			seg.position = Vector3(0, 0.0 if s == 0 else 0.26, 0)
			parent.add_child(seg)
			var r := lerpf(0.032, 0.008, s / 6.0)
			_mesh(seg, _capsule(r, 0.3), Vector3(0, 0.13, 0), m, Vector3.ZERO, Vector3(1.0, 1.0, 0.7))
			if s == 6:
				# a crude hand with fingers
				for f in 4:
					var finger := _mesh(seg, _capsule(0.006, 0.2), Vector3(lerpf(-0.025, 0.025, f / 3.0), 0.36, 0), m, Vector3(0, 0, lerpf(-0.5, 0.5, f / 3.0)))
					finger.name = "Finger"
			seg.set_meta("phase", rng.randf() * TAU)
			parent = seg
		tendrils.append(root)
	# Lights: a faint violet aura so she reads in total darkness, and a face light
	aura = OmniLight3D.new()
	aura.light_color = Color(0.55, 0.2, 0.85)
	aura.light_energy = 0.35
	aura.omni_range = 2.6
	aura.position = Vector3(0, 1.4, 0.5)
	aura.shadow_enabled = false
	aura.light_volumetric_fog_energy = 2.0
	add_child(aura)
	face_light = OmniLight3D.new()
	face_light.light_color = Color(0.7, 0.55, 0.9)
	face_light.light_energy = 0.0
	face_light.omni_range = 0.8
	face_light.position = Vector3(0, -0.1, 0.35)
	head.add_child(face_light)


func _arm(side: float) -> Node3D:
	var shoulder := Node3D.new()
	shoulder.name = "ArmL" if side < 0 else "ArmR"
	shoulder.position = Vector3(side * 0.22, 0.46, 0)
	torso.add_child(shoulder)
	_mesh(shoulder, _capsule(0.045, 0.34), Vector3(0, -0.15, 0), m_dress)
	var fore := Node3D.new()
	fore.name = "Fore"
	fore.position = Vector3(0, -0.31, 0)
	shoulder.add_child(fore)
	_mesh(fore, _capsule(0.035, 0.3), Vector3(0, -0.14, 0), m_skin)
	# wide bell sleeve
	_mesh(fore, _cone(0.05, 0.13, 0.26, 14), Vector3(0, -0.1, 0), m_dress)
	# long thin fingers
	for f in 4:
		_mesh(fore, _capsule(0.008, 0.11), Vector3(lerpf(-0.022, 0.022, f / 3.0), -0.33, 0.0), m_skin, Vector3(0.1, 0, lerpf(-0.12, 0.12, f / 3.0)))
	_mesh(fore, _sphere(0.032), Vector3(0, -0.28, 0), m_skin, Vector3.ZERO, Vector3(1, 1.2, 0.6))
	return shoulder


# ------------------------------------------------------------------ appearance
func set_persona(p: String) -> void:
	persona = p
	var witch := p == "witch"
	face_shadow.visible = witch
	for t in tendrils:
		t.visible = witch
	aura.light_color = Color(0.55, 0.2, 0.85) if witch else Color(0.75, 0.8, 0.95)
	aura.light_energy = 0.35 if witch else 0.5
	m_eye.albedo_color = Color(0.75, 0.35, 1.0) if witch else Color(0.6, 0.45, 0.8)
	m_eye.emission = Color(0.7, 0.25, 1.0) if witch else Color(0.55, 0.4, 0.75)
	m_eye.emission_energy_multiplier = 5.0 if witch else 1.5
	for m in _mats:
		m.set_shader_parameter("shimmer", 0.0 if witch else 0.25)
		m.set_shader_parameter("rim_color", Color(0.55, 0.25, 0.8) if witch else Color(0.8, 0.82, 0.95))
	twitch = 0.25 if witch else 0.0


func set_dissolve(v: float) -> void:
	_dissolve = clampf(v, 0.0, 1.0)
	for m in _mats:
		m.set_shader_parameter("dissolve", _dissolve)
	for m in _tendril_mats:
		m.set_shader_parameter("dissolve", _dissolve)
	var vis := _dissolve < 0.999
	for e in eyes:
		e.visible = vis and _dissolve < 0.6
	aura.visible = vis


func get_dissolve() -> float:
	return _dissolve


## Mirror-only: rendered on visual layer 2 (seen only by mirror cameras).
func set_mirror_only(on: bool) -> void:
	_set_layers(self, 2 if on else 1)


func _set_layers(n: Node, layer: int) -> void:
	if n is VisualInstance3D:
		(n as VisualInstance3D).layers = layer
	for c in n.get_children():
		_set_layers(c, layer)


func set_face_lit(energy: float) -> void:
	face_light.light_energy = energy


func set_pose(p: int) -> void:
	pose = p


# ------------------------------------------------------------------ animation
func _process(delta: float) -> void:
	_t += delta
	_animate(delta)


func _animate(delta: float) -> void:
	var breathe := sin(_t * 1.3) * 0.012
	var hips_y := 0.98
	var torso_pitch := 0.0
	var arm_l_rot := Vector3(0.05, 0, -0.08)
	var arm_r_rot := Vector3(0.05, 0, 0.08)
	var fore_l_rot := Vector3(-0.1, 0, 0)
	var fore_r_rot := Vector3(-0.1, 0, 0)
	var head_extra := Vector3.ZERO
	var hair_wind := 0.25
	var t_reach := 0.35
	match pose:
		Pose.STILL:
			breathe = 0.0
			hair_wind = 0.08
		Pose.WALK:
			var g := _t * 4.0
			hips_y += abs(sin(g)) * 0.015
			arm_l_rot.x = sin(g) * 0.25
			arm_r_rot.x = -sin(g) * 0.25
			torso_pitch = 0.06
			hair_wind = 0.45
		Pose.RUN:
			# She does not run like a human: a forward-leaning, gliding,
			# stuttering rush with arms reaching back then forward.
			var g := _t * 9.0
			hips_y += abs(sin(g)) * 0.04 - 0.05
			torso_pitch = 0.42 + sin(g * 0.5) * 0.05
			arm_l_rot = Vector3(-1.2 + sin(g) * 0.5, 0, -0.35)
			arm_r_rot = Vector3(-1.2 - sin(g) * 0.5, 0, 0.35)
			fore_l_rot.x = -0.6
			fore_r_rot.x = -0.6
			head_extra.x = -0.35
			hair_wind = 1.4
			t_reach = 0.9
		Pose.REACH:
			torso_pitch = 0.18
			arm_l_rot = Vector3(-1.45, 0, -0.12)
			arm_r_rot = Vector3(-1.35, 0, 0.18)
			fore_l_rot.x = -0.1
			fore_r_rot.x = -0.25
			head_extra.x = 0.15
			t_reach = 1.0
		Pose.SIT:
			hips_y = 0.62
			torso_pitch = -0.04
			arm_l_rot = Vector3(-0.9, 0, -0.05)
			arm_r_rot = Vector3(-0.9, 0, 0.05)
			fore_l_rot.x = -0.5
			fore_r_rot.x = -0.5
			hair_wind = 0.05
			t_reach = 0.1
		Pose.SCREAM:
			torso_pitch = -0.15
			head_extra.x = -0.5 + sin(_t * 40.0) * 0.03
			arm_l_rot = Vector3(-0.3, 0, -0.9)
			arm_r_rot = Vector3(-0.3, 0, 0.9)
			hair_wind = 1.2
			t_reach = 1.0
		Pose.KNEEL:
			hips_y = 0.45
			torso_pitch = 0.35
			arm_l_rot = Vector3(-0.4, 0, -0.1)
			arm_r_rot = Vector3(-0.4, 0, 0.1)
			head_extra.x = 0.4
			hair_wind = 0.05
	var k := clampf(delta * 8.0, 0.0, 1.0)
	hips.position.y = lerpf(hips.position.y, hips_y + breathe, k)
	torso.rotation.x = lerp_angle(torso.rotation.x, torso_pitch, k)
	arm_l.rotation = arm_l.rotation.lerp(arm_l_rot, k)
	arm_r.rotation = arm_r.rotation.lerp(arm_r_rot, k)
	fore_l.rotation = fore_l.rotation.lerp(fore_l_rot, k)
	fore_r.rotation = fore_r.rotation.lerp(fore_r_rot, k)
	# twitches
	_twitch_timer -= delta
	if _twitch_timer <= 0.0:
		_twitch_timer = randf_range(0.4, 3.0)
		_twitch_rot = Vector3(randf_range(-0.25, 0.25), randf_range(-0.35, 0.35), randf_range(-0.3, 0.3)) * twitch if randf() < 0.5 else Vector3.ZERO
	# head tracking
	var target_head := head_extra + _twitch_rot + Vector3(0, head_turn_offset, head_tilt)
	if look_target != Vector3.INF and is_inside_tree():
		var local: Vector3 = (head.get_parent() as Node3D).to_local(look_target)
		var yaw := atan2(local.x, local.z)
		var pitch := -atan2(local.y - head.position.y, Vector2(local.x, local.z).length())
		target_head.y += clampf(yaw, -1.3, 1.3)
		target_head.x += clampf(pitch, -0.6, 0.6)
	head.rotation = head.rotation.lerp(target_head, clampf(delta * (14.0 if twitch > 0.0 and _twitch_rot != Vector3.ZERO else 5.0), 0.0, 1.0))
	# hair
	for s in hair_strands:
		var ph: float = s.get_meta("phase")
		var base: Vector3 = s.get_meta("base_rot")
		var wind := Vector3(sin(_t * 1.7 + ph) * 0.06 * hair_wind + (0.6 if pose == Pose.RUN else 0.0), 0, sin(_t * 1.3 + ph * 1.7) * 0.05 * hair_wind)
		s.rotation = s.rotation.lerp(base + wind, k)
	# mouth
	mouth.scale.y = lerpf(mouth.scale.y, 0.006 + mouth_open * 0.07, k)
	mouth.position.y = -0.055 - mouth_open * 0.02
	# tendrils
	for i in tendrils.size():
		var root := tendrils[i]
		root.scale = root.scale.lerp(Vector3.ONE * maxf(0.001, tendril_amount * lerpf(0.5, 1.0, t_reach)), k * 0.5)
		var seg: Node3D = root.get_child(0) if root.get_child_count() > 0 else null
		var depth := 0
		while seg != null:
			var ph2: float = seg.get_meta("phase", 0.0)
			seg.rotation = Vector3(sin(_t * 2.1 + ph2 + depth * 0.7) * 0.35, 0, cos(_t * 1.6 + ph2 + depth) * 0.3 + (0.25 if i < 3 else -0.25) * t_reach)
			var next: Node3D = null
			for c in seg.get_children():
				if c is Node3D and not (c is MeshInstance3D):
					next = c
					break
			seg = next
			depth += 1
	# the dress follows gait
	for m in _mats:
		m.set_shader_parameter("flutter", 0.4 + speed_hint * 0.25)
