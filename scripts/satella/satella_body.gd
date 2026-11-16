class_name SatellaBody
extends Node3D
## Satella's procedural body (placeholder for a rigged model, see ASSETS.md).
##
## Design reference: the official concept image of the project (dark gothic
## Satella). Built entirely from procedural meshes (lathe surfaces, ribbon
## hair) arranged as a small skeleton (hips, torso, neck, head, arms) and
## animated by code: idle / still / walk / run / reach / sit / scream / kneel.
##
##  * an immense mane of black hair with violet sheen and a few pale strands,
##    framing the face, falling to the floor and spreading like a cloak;
##  * a face lost in shadow, only two glowing violet eyes;
##  * high ruffled collar, black bow and violet pendant, fitted corset with a
##    column of small golden roses, puffed shoulders, sheer bell sleeves;
##  * a dark rose held in her right hand;
##  * an immense layered dress whose sheer outer veil frays into smoke;
##  * WITCH persona: black hair, shadowed face, shadow hands when hunting;
##  * ORIGINAL persona: silver hair, a visible pale face, silver shimmer.

const SAT_SHADER := preload("res://shaders/satella.gdshader")
const TENDRIL_SHADER := preload("res://shaders/shadow_tendril.gdshader")
const HAIR_SHADER := preload("res://shaders/satella_hair.gdshader")
const VEIL_SHADER := preload("res://shaders/satella_veil.gdshader")

enum Pose { IDLE, STILL, WALK, RUN, REACH, SIT, SCREAM, KNEEL }

var pose: int = Pose.IDLE
var persona := "witch"
var look_target := Vector3.INF          ## world point the head tracks (INF = none)
var head_tilt := 0.0                    ## extra roll for unsettling tilts (radians)
var head_turn_offset := 0.0             ## extra yaw (lobby variations)
var twitch := 0.25                      ## 0..1 random jerky micro-movements
var tendril_amount := 0.0               ## 0..1 how far the shadow hands extend
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
var hair_strands: Array[Node3D] = []    ## kept for API compatibility (hair is a shader mesh now)
var tendrils: Array[Node3D] = []
var aura: OmniLight3D
var face_light: OmniLight3D
var rim_light: OmniLight3D
var eye_glow: OmniLight3D

var _mats: Array[ShaderMaterial] = []
var _tendril_mats: Array[ShaderMaterial] = []
var _veil_mats: Array[ShaderMaterial] = []
var m_dress: ShaderMaterial
var m_skin: ShaderMaterial
var m_hair: ShaderMaterial               ## ribbon hair (satella_hair shader)
var m_hair_cap: ShaderMaterial
var m_eye: StandardMaterial3D
var m_gold: StandardMaterial3D
var _t := 0.0
var _twitch_timer := 0.0
var _twitch_rot := Vector3.ZERO
var _dissolve := 0.0
var _flow := 0.0
var speed_hint := 0.0                   ## current movement speed for gait


func _ready() -> void:
	_build()
	set_persona(persona)


# ================================================================== materials
func _sat_mat(albedo: Color, rough: float, rim: float, flutter := 0.0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SAT_SHADER
	m.set_shader_parameter("albedo", albedo)
	m.set_shader_parameter("roughness", rough)
	m.set_shader_parameter("rim_strength", rim)
	m.set_shader_parameter("flutter", flutter)
	_mats.append(m)
	return m


func _veil_mat(opacity: float, smoke_start: float, sway := 0.03) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = VEIL_SHADER
	m.set_shader_parameter("opacity", opacity)
	m.set_shader_parameter("smoke_start", smoke_start)
	m.set_shader_parameter("sway", sway)
	_veil_mats.append(m)
	return m


# ================================================================== mesh helpers
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
	c.height = maxf(h, r * 2.0)
	c.radial_segments = 12
	c.rings = 4
	return c


func _sphere(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 20
	s.rings = 10
	return s


## Surface of revolution. profile = [Vector2(radius, y), ...] top -> bottom.
## folds: vertical pleats growing toward the hem; trail: the back of the
## surface is dragged behind (a train); flatten scales the depth (corset).
func _lathe(profile: Array, segs: int, folds := 0, fold_amp := 0.0, trail := 0.0, flatten := 1.0, fold_phase := 0.0) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings := profile.size()
	for i in rings:
		var t := float(i) / float(rings - 1)
		var pr: Vector2 = profile[i]
		for j in segs + 1:
			var a := TAU * float(j) / float(segs)
			var r := pr.x * (1.0 + fold_amp * t * sin(a * folds + fold_phase + t * 2.0))
			var x := sin(a) * r
			var z := cos(a) * r * flatten
			z -= trail * t * t * maxf(0.0, -cos(a))
			st.set_uv(Vector2(float(j) / float(segs), t))
			st.add_vertex(Vector3(x, pr.y, z))
	for i in rings - 1:
		for j in segs:
			var a0 := i * (segs + 1) + j
			var b0 := a0 + segs + 1
			st.add_index(a0)
			st.add_index(b0)
			st.add_index(a0 + 1)
			st.add_index(a0 + 1)
			st.add_index(b0)
			st.add_index(b0 + 1)
	st.generate_normals()
	return st.commit()


## Builds every lock of hair as a camera-independent ribbon in ONE mesh.
## Each lock: {pts: Array[Vector3], w0: float, w1: float, tint: float, phase: float}
func _ribbons(locks: Array) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var base := 0
	for lk in locks:
		var pts: Array = lk["pts"]
		var n := pts.size()
		for k in n:
			var p: Vector3 = pts[k]
			var t := float(k) / float(n - 1)
			var radial := Vector3(p.x, 0, p.z)
			if radial.length() < 0.001:
				radial = Vector3(0, 0, 1)
			radial = radial.normalized()
			var side := Vector3(radial.z, 0, -radial.x)
			var w := lerpf(float(lk["w0"]), float(lk["w1"]), t)
			var col := Color(float(lk["tint"]), float(lk["phase"]), 0.0)
			st.set_color(col)
			st.set_uv(Vector2(0, t))
			st.add_vertex(p - side * w * 0.5)
			st.set_color(col)
			st.set_uv(Vector2(1, t))
			st.add_vertex(p + side * w * 0.5 + radial * 0.004)
		for k in n - 1:
			var a := base + k * 2
			st.add_index(a)
			st.add_index(a + 2)
			st.add_index(a + 1)
			st.add_index(a + 1)
			st.add_index(a + 2)
			st.add_index(a + 3)
		base += n * 2
	st.generate_normals()
	return st.commit()


## One lock falling from the scalp. Neck-local space (floor at y = -1.62).
func _lock(angle: float, end_y: float, flare: float, rng: RandomNumberGenerator, root_y := 0.22, scalp_r := 0.125) -> Array:
	var pts: Array = []
	var phase := rng.randf()
	var steps := 16
	for k in steps + 1:
		var t := float(k) / float(steps)
		var y := lerpf(root_y, end_y, t)
		# hugs the skull, clears the shoulders, then spreads like a cloak
		var r := scalp_r + (0.29 - scalp_r) * smoothstep(0.0, 0.2, t) + (flare - 0.29) * pow(smoothstep(0.18, 1.0, t), 1.4)
		r += sin(t * 7.0 + phase * 6.0) * 0.015 * t
		var a := angle + sin(t * 4.0 + phase * 5.0) * 0.06 * t
		var p := Vector3(sin(a) * r, y, cos(a) * r * 0.92)
		if cos(angle) < 0.0:
			p.z -= 0.1 * t   # the back of the mane falls slightly behind
		pts.append(p)
	return pts


func _rosette(parent: Node3D, pos: Vector3, size: float) -> void:
	var r := Node3D.new()
	r.position = pos
	parent.add_child(r)
	_mesh(r, _sphere(size * 0.45), Vector3.ZERO, m_gold)
	for i in 6:
		var a := TAU * i / 6.0
		_mesh(r, _sphere(size * 0.42), Vector3(cos(a) * size * 0.55, sin(a) * size * 0.55, -size * 0.1), m_gold, Vector3.ZERO, Vector3(1.0, 1.0, 0.45))


# ================================================================== build
func _build() -> void:
	m_dress = _sat_mat(Color(0.007, 0.004, 0.012), 0.92, 0.3, 0.0)
	m_skin = _sat_mat(Color(0.05, 0.042, 0.06), 0.6, 0.15)
	m_hair_cap = _sat_mat(Color(0.012, 0.006, 0.02), 0.85, 0.15)
	m_hair_cap.set_shader_parameter("rim_color", Color(0.55, 0.22, 0.9))
	var m_inner := _sat_mat(Color(0.006, 0.003, 0.01), 0.9, 0.25)
	m_hair = ShaderMaterial.new()
	m_hair.shader = HAIR_SHADER
	m_eye = StandardMaterial3D.new()
	m_eye.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m_eye.albedo_color = Color(0.9, 0.8, 1.0)
	m_eye.emission_enabled = true
	m_eye.emission = Color(0.75, 0.55, 1.0)
	m_eye.emission_energy_multiplier = 9.0
	m_gold = StandardMaterial3D.new()
	m_gold.albedo_color = Color(0.5, 0.33, 0.13)
	m_gold.metallic = 0.85
	m_gold.roughness = 0.35
	m_gold.emission_enabled = true
	m_gold.emission = Color(0.45, 0.26, 0.08)
	m_gold.emission_energy_multiplier = 0.35
	var m_black := StandardMaterial3D.new()
	m_black.albedo_color = Color(0, 0, 0)
	m_black.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var m_rose := _sat_mat(Color(0.16, 0.01, 0.04), 0.5, 0.4)
	m_rose.set_shader_parameter("rim_color", Color(0.5, 0.05, 0.2))
	var m_gem := StandardMaterial3D.new()
	m_gem.albedo_color = Color(0.4, 0.1, 0.6)
	m_gem.emission_enabled = true
	m_gem.emission = Color(0.6, 0.15, 0.9)
	m_gem.emission_energy_multiplier = 3.0
	m_gem.metallic = 0.5
	m_gem.roughness = 0.1

	hips = Node3D.new()
	hips.name = "Hips"
	hips.position = Vector3(0, 0.98, 0)
	add_child(hips)
	# ---- the dress: inner skirt, ruffled peplum, sheer outer veil with a train
	dress = _mesh(hips, _lathe([Vector2(0.125, 0.06), Vector2(0.2, -0.1), Vector2(0.3, -0.33), Vector2(0.44, -0.58), Vector2(0.6, -0.84), Vector2(0.7, -0.975)], 56, 14, 0.12, 0.35), Vector3.ZERO, m_dress)
	dress.name = "Skirt"
	_mesh(hips, _lathe([Vector2(0.14, 0.07), Vector2(0.22, -0.04), Vector2(0.31, -0.2)], 56, 26, 0.28, 0.0, 1.0, 0.7), Vector3.ZERO, m_dress).name = "Peplum"
	var veil := _veil_mat(0.82, 0.55, 0.035)
	_mesh(hips, _lathe([Vector2(0.15, 0.08), Vector2(0.25, -0.12), Vector2(0.4, -0.38), Vector2(0.62, -0.64), Vector2(0.9, -0.89), Vector2(1.25, -0.972), Vector2(1.65, -0.978)], 64, 20, 0.16, 0.85, 1.0, 1.3), Vector3.ZERO, veil).name = "Veil"
	var veil2 := _veil_mat(0.45, 0.45, 0.05)
	_mesh(hips, _lathe([Vector2(0.18, 0.05), Vector2(0.32, -0.2), Vector2(0.55, -0.5), Vector2(0.85, -0.8), Vector2(1.35, -0.97), Vector2(1.9, -0.98)], 64, 11, 0.22, 1.2, 1.0, 2.4), Vector3.ZERO, veil2).name = "VeilOuter"
	# ---- torso: fitted corset, puffed shoulders
	torso = Node3D.new()
	torso.name = "Torso"
	torso.position = Vector3(0, 0.12, 0)
	hips.add_child(torso)
	_mesh(torso, _lathe([Vector2(0.06, 0.53), Vector2(0.1, 0.5), Vector2(0.135, 0.43), Vector2(0.15, 0.32), Vector2(0.135, 0.2), Vector2(0.118, 0.05), Vector2(0.122, -0.08)], 40, 0, 0.0, 0.0, 0.78), Vector3.ZERO, m_dress).name = "Corset"
	for sx in [-1.0, 1.0]:
		_mesh(torso, _sphere(0.075), Vector3(sx * 0.17, 0.45, -0.005), m_dress, Vector3.ZERO, Vector3(1.0, 0.85, 0.95))
	# golden roses: a column down the bodice continuing onto the skirt
	for i in 5:
		var y := 0.36 - i * 0.085
		var front_r := lerpf(0.15, 0.12, clampf((0.36 - y) / 0.36, 0.0, 1.0)) * 0.78
		_rosette(torso, Vector3(0, y, front_r + 0.008), 0.02)
	for i in 4:
		var yh := -0.04 - i * 0.12
		var rr := lerpf(0.16, 0.36, (i + 1) / 4.0)
		_rosette(hips, Vector3(0.0, yh, rr + 0.015), 0.024 - i * 0.002)
	for i in 8:
		var a := lerpf(-1.1, 1.1, i / 7.0)
		_rosette(hips, Vector3(sin(a) * 0.135, 0.06, cos(a) * 0.135 * 0.95 + 0.01), 0.013)
	# ---- neck, collar, bow, pendant
	neck = Node3D.new()
	neck.name = "Neck"
	neck.position = Vector3(0, 0.52, 0)
	torso.add_child(neck)
	_mesh(neck, _capsule(0.04, 0.16), Vector3(0, 0.06, 0), m_skin)
	_mesh(neck, _lathe([Vector2(0.05, 0.12), Vector2(0.048, 0.06), Vector2(0.06, 0.0), Vector2(0.075, -0.02)], 32, 18, 0.25), Vector3.ZERO, m_dress).name = "Collar"
	_mesh(neck, _lathe([Vector2(0.06, 0.0), Vector2(0.1, -0.03), Vector2(0.14, -0.05)], 40, 22, 0.35, 0.0, 0.85), Vector3.ZERO, m_inner).name = "Jabot"
	for sx in [-1.0, 1.0]:
		_mesh(neck, _sphere(0.028), Vector3(sx * 0.03, 0.035, 0.06), m_dress, Vector3(0, 0, sx * 0.5), Vector3(1.4, 0.8, 0.45))
		_mesh(neck, BoxMesh.new(), Vector3(sx * 0.018, -0.03, 0.065), m_dress, Vector3(0, 0, sx * 0.25), Vector3(0.022, 0.12, 0.006))
	_mesh(neck, _sphere(0.014), Vector3(0, 0.035, 0.066), m_dress)
	_mesh(neck, _sphere(0.012), Vector3(0, -0.02, 0.075), m_gem, Vector3.ZERO, Vector3(1.0, 1.3, 0.6))
	_rosette(neck, Vector3(0, -0.055, 0.088), 0.018)
	# ---- head: a face lost in shadow, two violet eyes
	head = Node3D.new()
	head.name = "Head"
	head.position = Vector3(0, 0.18, 0)
	neck.add_child(head)
	_mesh(head, _sphere(0.1), Vector3.ZERO, m_skin, Vector3.ZERO, Vector3(0.88, 1.12, 0.96))
	face_shadow = _mesh(head, _sphere(0.1), Vector3(0, -0.015, 0.072), m_black, Vector3.ZERO, Vector3(0.74, 0.95, 0.36))
	for sx in [-0.037, 0.037]:
		var e := _mesh(head, _sphere(0.016), Vector3(sx, 0.014, 0.098), m_eye, Vector3(0, 0, -sx * 3.0), Vector3(1.35, 0.95, 0.45))
		e.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		eyes.append(e)
	mouth = _mesh(head, BoxMesh.new(), Vector3(0, -0.06, 0.098), m_black, Vector3.ZERO, Vector3(0.03, 0.005, 0.01))
	eye_glow = OmniLight3D.new()
	eye_glow.light_color = Color(0.6, 0.3, 1.0)
	eye_glow.light_energy = 0.6
	eye_glow.omni_range = 0.6
	eye_glow.position = Vector3(0, 0.02, 0.22)
	head.add_child(eye_glow)
	# scalp + bangs move with the head
	_mesh(head, _sphere(0.118), Vector3(0, 0.022, -0.012), m_hair_cap, Vector3.ZERO, Vector3(1.0, 1.04, 1.06))
	var rng := RandomNumberGenerator.new()
	rng.seed = 1710
	var bangs: Array = []
	for i in 13:
		var a := lerpf(-0.75, 0.75, i / 12.0) + rng.randf_range(-0.04, 0.04)
		var pts: Array = []
		var len_b := rng.randf_range(0.0, 0.03)
		for k in 7:
			var t := k / 6.0
			var y := lerpf(0.115, 0.025 - len_b, t)
			var r := lerpf(0.06, 0.122, smoothstep(0.0, 0.5, t))
			pts.append(Vector3(sin(a) * r, y, cos(a) * r))
		bangs.append({"pts": pts, "w0": 0.035, "w1": 0.012, "tint": 0.0, "phase": rng.randf()})
	_mesh(head, _ribbons(bangs), Vector3.ZERO, m_hair).name = "Bangs"
	# the mane: attached to the neck so it follows the body, not every head twitch
	var locks: Array = []
	for i in 130:
		var a := lerpf(0.7, TAU - 0.7, i / 129.0) + rng.randf_range(-0.03, 0.03)
		var back := cos(a) < -0.2
		var end_y := rng.randf_range(-1.6, -1.45) if back else rng.randf_range(-1.35, -0.75)
		var flare := rng.randf_range(0.55, 0.95) if back else rng.randf_range(0.42, 0.75)
		locks.append({"pts": _lock(a, end_y, flare, rng), "w0": rng.randf_range(0.045, 0.07), "w1": rng.randf_range(0.09, 0.16), "tint": 1.0 if rng.randf() < 0.07 else 0.0, "phase": rng.randf()})
	# front locks framing the face and falling over the chest
	for side in [-1.0, 1.0]:
		for i in 11:
			var a2: float = side * rng.randf_range(0.45, 0.95)
			var pts2 := _lock(a2, rng.randf_range(-1.15, -0.6), rng.randf_range(0.27, 0.42), rng, 0.2, 0.122)
			locks.append({"pts": pts2, "w0": 0.05, "w1": 0.085, "tint": 0.0, "phase": rng.randf()})
	var mane := _mesh(neck, _ribbons(locks), Vector3.ZERO, m_hair)
	mane.name = "Mane"
	# ---- arms with sheer bell sleeves; a dark rose in the right hand
	arm_l = _arm(-1.0)
	arm_r = _arm(1.0)
	fore_l = arm_l.get_node("Fore")
	fore_r = arm_r.get_node("Fore")
	var rose := Node3D.new()
	rose.name = "Rose"
	rose.position = Vector3(0, -0.34, 0.045)
	fore_r.add_child(rose)
	for i in 6:
		var a3 := TAU * i / 6.0
		_mesh(rose, _sphere(0.022), Vector3(cos(a3) * 0.015, sin(a3) * 0.015, 0.0), m_rose, Vector3.ZERO, Vector3(1.0, 1.0, 0.7))
	_mesh(rose, _sphere(0.018), Vector3(0, 0, 0.012), m_rose)
	_mesh(rose, _capsule(0.004, 0.22), Vector3(0, -0.11, -0.01), m_inner)
	# ---- shadow hands (hidden at rest, they unfold when she hunts)
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
				for f in 4:
					var finger := _mesh(seg, _capsule(0.006, 0.2), Vector3(lerpf(-0.025, 0.025, f / 3.0), 0.36, 0), m, Vector3(0, 0, lerpf(-0.5, 0.5, f / 3.0)))
					finger.name = "Finger"
			seg.set_meta("phase", rng.randf() * TAU)
			parent = seg
		root.scale = Vector3.ONE * 0.001
		tendrils.append(root)
	# ---- lights: a violet rim from behind (the hair glows at its edges),
	# a faint aura in front so her silhouette always reads in the dark
	rim_light = OmniLight3D.new()
	rim_light.light_color = Color(0.55, 0.22, 0.95)
	rim_light.light_energy = 0.7
	rim_light.omni_range = 3.2
	rim_light.position = Vector3(0, 2.0, -0.75)
	rim_light.shadow_enabled = false
	rim_light.light_volumetric_fog_energy = 2.5
	add_child(rim_light)
	aura = OmniLight3D.new()
	aura.light_color = Color(0.5, 0.2, 0.85)
	aura.light_energy = 0.3
	aura.omni_range = 2.6
	aura.position = Vector3(0, 1.2, 0.7)
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
	shoulder.position = Vector3(side * 0.2, 0.44, 0)
	torso.add_child(shoulder)
	_mesh(shoulder, _capsule(0.04, 0.32), Vector3(0, -0.15, 0), m_dress)
	var fore := Node3D.new()
	fore.name = "Fore"
	fore.position = Vector3(0, -0.3, 0)
	shoulder.add_child(fore)
	_mesh(fore, _capsule(0.032, 0.28), Vector3(0, -0.13, 0), m_dress)
	# long sheer bell sleeve that frays into smoke
	var sleeve := _veil_mat(0.6, 0.55, 0.02)
	_mesh(fore, _lathe([Vector2(0.045, 0.04), Vector2(0.07, -0.1), Vector2(0.115, -0.26), Vector2(0.165, -0.4), Vector2(0.19, -0.46)], 24, 9, 0.2), Vector3.ZERO, sleeve)
	# pale, long-fingered hand
	_mesh(fore, _sphere(0.03), Vector3(0, -0.3, 0), m_skin, Vector3.ZERO, Vector3(0.9, 1.25, 0.55))
	for f in 4:
		_mesh(fore, _capsule(0.007, 0.1), Vector3(lerpf(-0.02, 0.02, f / 3.0), -0.36, 0.005), m_skin, Vector3(0.15, 0, lerpf(-0.12, 0.12, f / 3.0)))
	return shoulder


# ------------------------------------------------------------------ appearance
func set_persona(p: String) -> void:
	persona = p
	var witch := p == "witch"
	face_shadow.visible = false   # the face is in shadow through lighting, not a mask
	for t in tendrils:
		t.visible = witch
	m_hair.set_shader_parameter("tint", 0.0 if witch else 1.0)
	m_hair.set_shader_parameter("rim_color", Color(0.55, 0.22, 0.9) if witch else Color(0.75, 0.78, 0.95))
	m_hair_cap.set_shader_parameter("albedo", Color(0.012, 0.006, 0.02) if witch else Color(0.62, 0.62, 0.68))
	m_skin.set_shader_parameter("albedo", Color(0.05, 0.042, 0.06) if witch else Color(0.62, 0.57, 0.62))
	rim_light.light_color = Color(0.55, 0.22, 0.95) if witch else Color(0.75, 0.8, 0.98)
	aura.light_color = Color(0.5, 0.2, 0.85) if witch else Color(0.75, 0.8, 0.95)
	aura.light_energy = 0.3 if witch else 0.5
	eye_glow.light_energy = 0.5 if witch else 0.15
	m_eye.albedo_color = Color(0.9, 0.8, 1.0) if witch else Color(0.6, 0.45, 0.8)
	m_eye.emission = Color(0.75, 0.55, 1.0) if witch else Color(0.55, 0.4, 0.75)
	m_eye.emission_energy_multiplier = 14.0 if witch else 1.2
	for m in _mats:
		if m != m_hair_cap and m != m_skin:
			m.set_shader_parameter("shimmer", 0.0 if witch else 0.2)
		m.set_shader_parameter("rim_color", Color(0.5, 0.2, 0.8) if witch else Color(0.8, 0.82, 0.95))
	for m in _veil_mats:
		m.set_shader_parameter("shimmer", 0.0 if witch else 0.35)
		m.set_shader_parameter("color", Color(0.02, 0.008, 0.035) if witch else Color(0.12, 0.11, 0.16))
	twitch = 0.25 if witch else 0.0


func set_dissolve(v: float) -> void:
	_dissolve = clampf(v, 0.0, 1.0)
	for m in _mats:
		m.set_shader_parameter("dissolve", _dissolve)
	for m in _tendril_mats:
		m.set_shader_parameter("dissolve", _dissolve)
	for m in _veil_mats:
		m.set_shader_parameter("dissolve", _dissolve)
	m_hair.set_shader_parameter("dissolve", _dissolve)
	var vis := _dissolve < 0.999
	for e in eyes:
		e.visible = vis and _dissolve < 0.6
	aura.visible = vis
	rim_light.visible = vis
	eye_glow.visible = vis and _dissolve < 0.6


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
	# hair (animated in the shader): wind and backward flow when she rushes
	_flow = lerpf(_flow, 1.0 if pose == Pose.RUN else 0.0, k * 0.5)
	m_hair.set_shader_parameter("wind", hair_wind)
	m_hair.set_shader_parameter("flow", _flow)
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
	for m in _veil_mats:
		m.set_shader_parameter("sway", 0.03 + speed_hint * 0.03 + _flow * 0.06)
