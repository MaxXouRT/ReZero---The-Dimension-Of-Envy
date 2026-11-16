class_name Builder
extends RefCounted
## Builder — procedural architecture & prop library.
##
## All the environments of the Dimension of Envy are assembled from code with
## these helpers (rooms with door/window openings, wainscoting, moldings,
## gothic furniture, lights...). This keeps the levels editable as text and
## lets the WorldDistortionSystem rebuild / swap parts at runtime.
##
## Every placeholder here is meant to be swappable with an authored model:
## see documentation/ASSETS.md.

const ARCH_SHADER := preload("res://shaders/architecture.gdshader")
const PAINT_SHADER := preload("res://shaders/painting.gdshader")
const GLASS_SHADER := preload("res://shaders/stained_glass.gdshader")
const WALL_T := 0.2

static var _mats := {}


# =================================================================== materials
static func _arch(pattern: int, a: Color, b: Color, c: Color, scale := 1.0, rough := 0.8, metal := 0.0, bump := 0.6, grime := 0.5, breathe := 1.0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = ARCH_SHADER
	m.set_shader_parameter("pattern", pattern)
	m.set_shader_parameter("color_a", a)
	m.set_shader_parameter("color_b", b)
	m.set_shader_parameter("color_c", c)
	m.set_shader_parameter("scale", scale)
	m.set_shader_parameter("roughness_base", rough)
	m.set_shader_parameter("metallic_base", metal)
	m.set_shader_parameter("bump_strength", bump)
	m.set_shader_parameter("grime", grime)
	m.set_shader_parameter("breathe", breathe)
	return m


static func _std(color: Color, rough := 0.8, metal := 0.0, emission := Color.BLACK, energy := 0.0, unshaded := false, transparent := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	if energy > 0.0:
		m.emission_enabled = true
		m.emission = emission
		m.emission_energy_multiplier = energy
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if transparent:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


static func mat(key: String) -> Material:
	if _mats.has(key):
		return _mats[key]
	var m: Material
	match key:
		"panel_cream", "wallpaper":
			m = _arch(10, Color(0.5, 0.43, 0.32), Color(0.58, 0.51, 0.39), Color(0.55, 0.4, 0.14), 1.0, 0.75, 0.0, 0.6, 0.25)
		"panel_teal":
			m = _arch(10, Color(0.22, 0.34, 0.33), Color(0.27, 0.4, 0.38), Color(0.55, 0.42, 0.16), 1.0, 0.75, 0.0, 0.6, 0.2)
		"panel_dirty", "wallpaper_grey":
			m = _arch(10, Color(0.3, 0.26, 0.2), Color(0.34, 0.3, 0.23), Color(0.32, 0.25, 0.11), 1.0, 0.85, 0.0, 0.7, 0.95)
		"tiles_diamond":
			m = _arch(11, Color(0.34, 0.32, 0.42), Color(0.4, 0.38, 0.48), Color(0.14, 0.12, 0.22), 1.0, 0.3, 0.0, 0.4, 0.2)
		"marble_checker":
			m = _arch(5, Color(0.66, 0.64, 0.62), Color(0.78, 0.76, 0.74), Color(0.025, 0.025, 0.03), 1.0, 0.15, 0.0, 0.4, 0.2)
		"marble_cream":
			m = _arch(5, Color(0.55, 0.5, 0.42), Color(0.68, 0.63, 0.55), Color(0.48, 0.44, 0.37), 1.4, 0.2, 0.0, 0.4, 0.2)
		"facade":
			m = _arch(12, Color(0.5, 0.45, 0.37), Color(0.6, 0.55, 0.46), Color(0.015, 0.015, 0.03), 1.0, 0.8, 0.0, 0.5, 0.4, 0.0)
		"slate":
			m = _arch(13, Color(0.09, 0.11, 0.16), Color(0.13, 0.15, 0.21), Color(0.03, 0.03, 0.05), 1.0, 0.7, 0.0, 0.5, 0.2, 0.0)
		"wood_warm":
			m = _arch(1, Color(0.26, 0.09, 0.04), Color(0.4, 0.16, 0.07), Color(0.1, 0.04, 0.02), 1.4, 0.32, 0.0, 0.4, 0.2, 0.0)
		"cobble":
			m = _arch(2, Color(0.2, 0.19, 0.2), Color(0.28, 0.27, 0.28), Color(0.06, 0.06, 0.07), 2.6, 0.9, 0.0, 1.0, 0.4, 0.0)
		"plaster_cream":
			m = _arch(4, Color(0.46, 0.41, 0.33), Color(0.54, 0.49, 0.4), Color(0.4, 0.35, 0.28), 0.7, 0.85, 0.0, 0.4, 0.1)
		"carpet_navy":
			m = _arch(3, Color(0.04, 0.06, 0.14), Color(0.3, 0.28, 0.38), Color(0.02, 0.02, 0.05), 1.0, 1.0, 0.0, 0.3, 0.1)
		"red_carpet":
			m = _std(Color(0.4, 0.045, 0.04), 1.0)
		"green_border":
			m = _std(Color(0.05, 0.2, 0.11), 1.0)
		"topiary":
			m = _std(Color(0.025, 0.07, 0.035), 0.95)
		"curtain_blue":
			m = _std(Color(0.05, 0.09, 0.24), 0.9)
		"cushion_white":
			m = _std(Color(0.7, 0.68, 0.64), 0.9)
		"flower_pink":
			m = _std(Color(0.75, 0.35, 0.5), 0.8)
		"porcelain":
			m = _std(Color(0.7, 0.72, 0.6), 0.3)
		"lantern_glass":
			m = _std(Color(0.4, 0.95, 0.5), 0.2, 0.0, Color(0.35, 0.95, 0.45), 2.2, true)
		"window_glass":
			m = _std(Color(0.05, 0.04, 0.09, 0.18), 0.02, 0.6, Color.BLACK, 0.0, false, true)
		"wallpaper_violet":
			m = _arch(0, Color(0.13, 0.06, 0.17), Color(0.24, 0.12, 0.3), Color(0.035, 0.02, 0.035), 1.0, 0.85)
		"_unused_wallpaper":
			m = _arch(0, Color(0.13, 0.06, 0.17), Color(0.24, 0.12, 0.3), Color(0.035, 0.02, 0.035), 1.0, 0.85)
		"wallpaper_red":
			m = _arch(0, Color(0.2, 0.04, 0.06), Color(0.34, 0.09, 0.12), Color(0.04, 0.015, 0.02), 1.0, 0.85)
		"wainscot":
			m = _arch(9, Color(0.12, 0.065, 0.045), Color(0.2, 0.12, 0.08), Color(0.03, 0.018, 0.012), 1.0, 0.6)
		"wood_floor":
			m = _arch(1, Color(0.14, 0.08, 0.05), Color(0.24, 0.15, 0.09), Color(0.04, 0.025, 0.02), 1.0, 0.55, 0.0, 0.8)
		"wood_dark":
			m = _arch(1, Color(0.05, 0.028, 0.02), Color(0.1, 0.055, 0.035), Color(0.02, 0.01, 0.008), 1.6, 0.5, 0.0, 0.4, 0.3, 0.0)
		"door_wood":
			m = _arch(9, Color(0.07, 0.035, 0.025), Color(0.11, 0.06, 0.04), Color(0.02, 0.01, 0.008), 1.4, 0.55, 0.0, 0.7, 0.4, 0.0)
		"stone":
			m = _arch(2, Color(0.16, 0.15, 0.18), Color(0.26, 0.24, 0.28), Color(0.04, 0.035, 0.045), 1.0, 0.9, 0.0, 1.0)
		"stone_dark":
			m = _arch(2, Color(0.05, 0.045, 0.06), Color(0.09, 0.08, 0.1), Color(0.015, 0.01, 0.02), 1.2, 0.9, 0.0, 1.0)
		"void_stone":
			var vs := _arch(2, Color(0.06, 0.04, 0.08), Color(0.11, 0.07, 0.14), Color(0.01, 0.0, 0.02), 0.8, 0.9, 0.0, 1.0, 0.8)
			vs.set_shader_parameter("emission_color", Color(0.25, 0.05, 0.4))
			vs.set_shader_parameter("emission_energy", 0.05)
			m = vs
		"carpet":
			m = _arch(3, Color(0.2, 0.03, 0.06), Color(0.32, 0.1, 0.16), Color(0.05, 0.015, 0.025), 1.0, 1.0, 0.0, 0.3)
		"carpet_violet":
			m = _arch(3, Color(0.06, 0.02, 0.1), Color(0.14, 0.06, 0.2), Color(0.02, 0.01, 0.03), 1.0, 1.0, 0.0, 0.3)
		"plaster":
			m = _arch(4, Color(0.3, 0.26, 0.21), Color(0.36, 0.32, 0.26), Color(0.12, 0.1, 0.08), 0.7, 0.95)
		"marble":
			m = _arch(5, Color(0.25, 0.22, 0.28), Color(0.55, 0.52, 0.6), Color(0.03, 0.02, 0.04), 1.0, 0.18, 0.0, 0.5)
		"gilt":
			m = _arch(6, Color(0.42, 0.3, 0.12), Color(0.6, 0.45, 0.2), Color(0.1, 0.07, 0.04), 3.0, 0.4, 0.85, 0.6, 0.6, 0.0)
		"iron":
			m = _arch(6, Color(0.05, 0.05, 0.06), Color(0.1, 0.1, 0.11), Color(0.08, 0.04, 0.02), 4.0, 0.6, 0.7, 0.6, 0.7, 0.0)
		"bark":
			m = _arch(7, Color(0.05, 0.04, 0.05), Color(0.09, 0.07, 0.08), Color(0.01, 0.01, 0.01), 1.0, 0.95, 0.0, 1.2, 0.5, 0.3)
		"soil":
			m = _arch(8, Color(0.035, 0.025, 0.035), Color(0.06, 0.045, 0.06), Color(0.09, 0.03, 0.08), 0.6, 0.98, 0.0, 0.8)
		"fabric_white":
			m = _std(Color(0.55, 0.52, 0.56), 0.95)
		"fabric_dark":
			m = _std(Color(0.08, 0.03, 0.09), 0.95)
		"fabric_red":
			m = _std(Color(0.2, 0.02, 0.04), 0.9)
		"paper":
			m = _std(Color(0.62, 0.58, 0.5), 0.95)
		"wax":
			m = _std(Color(0.75, 0.72, 0.65), 0.5, 0.0, Color(0.9, 0.6, 0.3), 0.15)
		"flame":
			m = _std(Color(1.0, 0.7, 0.35), 1.0, 0.0, Color(1.0, 0.6, 0.25), 6.0, true)
		"flame_violet":
			m = _std(Color(0.7, 0.4, 1.0), 1.0, 0.0, Color(0.6, 0.2, 1.0), 6.0, true)
		"silver_glow":
			m = _std(Color(0.85, 0.88, 0.95), 0.3, 0.0, Color(0.75, 0.8, 0.95), 2.2, true)
		"witch_glow":
			m = _std(Color(0.25, 0.02, 0.35), 0.3, 0.0, Color(0.5, 0.05, 0.8), 2.5, true)
		"glass_dark":
			var g := _std(Color(0.04, 0.02, 0.06, 0.55), 0.05, 0.3, Color(0.12, 0.04, 0.18), 0.25, false, true)
			m = g
		"black":
			m = _std(Color(0.0, 0.0, 0.0), 1.0, 0.0, Color.BLACK, 0.0, true)
		"leaf_dead":
			m = _std(Color(0.06, 0.035, 0.05), 0.95)
		"bone":
			m = _std(Color(0.45, 0.42, 0.4), 0.7)
		"seal_fragment":
			m = _std(Color(0.4, 0.15, 0.6), 0.2, 0.3, Color(0.55, 0.15, 0.85), 3.0)
		"stained_glass":
			var sg := ShaderMaterial.new()
			sg.shader = GLASS_SHADER
			m = sg
		_:
			push_warning("Builder.mat: unknown key %s" % key)
			m = _std(Color(1, 0, 1))
	_mats[key] = m
	return m


static func painting_mat(variant: int, seed_value := 0.0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = PAINT_SHADER
	m.set_shader_parameter("variant", variant)
	m.set_shader_parameter("seed", seed_value)
	return m


# =================================================================== primitives
static func _add_collision(node: Node3D, shape: Shape3D, offset := Vector3.ZERO, surface := "") -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	if surface != "":
		body.set_meta("surface", surface)
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position = offset
	body.add_child(cs)
	node.add_child(body)
	return body


static func box(parent: Node, size: Vector3, pos: Vector3, material: Material, collide := true, rot_deg := Vector3.ZERO, surface := "", subdivide := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	if subdivide:
		bm.subdivide_width = clampi(int(size.x), 0, 16)
		bm.subdivide_height = clampi(int(size.y), 0, 8)
		bm.subdivide_depth = clampi(int(size.z), 0, 16)
	mi.mesh = bm
	mi.material_override = material
	mi.position = pos
	mi.rotation_degrees = rot_deg
	parent.add_child(mi)
	if collide:
		var bs := BoxShape3D.new()
		bs.size = size
		_add_collision(mi, bs, Vector3.ZERO, surface)
	return mi


static func cyl(parent: Node, r_top: float, r_bottom: float, h: float, pos: Vector3, material: Material, collide := false, segments := 16, rot_deg := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r_top
	cm.bottom_radius = r_bottom
	cm.height = h
	cm.radial_segments = segments
	cm.rings = 1
	mi.mesh = cm
	mi.material_override = material
	mi.position = pos
	mi.rotation_degrees = rot_deg
	parent.add_child(mi)
	if collide:
		var cs := CylinderShape3D.new()
		cs.radius = maxf(r_top, r_bottom)
		cs.height = h
		_add_collision(mi, cs)
	return mi


static func sphere(parent: Node, r: float, pos: Vector3, material: Material, scale := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = 16
	sm.rings = 8
	mi.mesh = sm
	mi.material_override = material
	mi.position = pos
	mi.scale = scale
	parent.add_child(mi)
	return mi


static func node(parent: Node, name: String, pos := Vector3.ZERO, rot_y_deg := 0.0) -> Node3D:
	var n := Node3D.new()
	n.name = name
	n.position = pos
	n.rotation_degrees.y = rot_y_deg
	parent.add_child(n)
	return n


static func light(parent: Node, pos: Vector3, color := Color(1.0, 0.62, 0.32), energy := 1.0, range_m := 5.0, shadow := false, flicker := 0.12) -> FlickerLight:
	var l := FlickerLight.new()
	l.position = pos
	l.light_color = color
	l.light_energy = energy
	l.omni_range = range_m
	l.omni_attenuation = 1.0
	l.shadow_enabled = shadow
	l.flicker = flicker
	l.light_volumetric_fog_energy = 1.5
	parent.add_child(l)
	return l


static func interactable(parent: Node, pos: Vector3, size: Vector3, prompt: String, action: Callable, one_shot := false) -> Interactable:
	var i := Interactable.new()
	i.prompt = prompt
	i.action = action
	i.one_shot = one_shot
	i.position = pos
	i.set_box(size)
	parent.add_child(i)
	return i


## Area that calls `on_enter(body)` once (or every time) the player enters.
static func trigger(parent: Node, pos: Vector3, size: Vector3, on_enter: Callable, once := true) -> Area3D:
	var a := Area3D.new()
	a.collision_layer = 0
	a.collision_mask = 2
	a.position = pos
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	a.add_child(cs)
	parent.add_child(a)
	var state := {"done": false}
	a.body_entered.connect(func(body: Node) -> void:
		if not body.is_in_group("player"):
			return
		if once and state["done"]:
			return
		state["done"] = true
		on_enter.call(body))
	return a


# =================================================================== rooms
## Builds a room shell. `center` is the floor centre.
## opts:
##   wall, floor, ceiling : material keys
##   wainscot : bool (default true)
##   no_ceiling : bool
##   openings : [{side:"n|s|e|w", offset:float, width:float, height:float, bottom:float}]
##   skip : ["n", ...] walls not built
static func room(parent: Node, center: Vector3, size: Vector3, opts := {}) -> Node3D:
	var root := Node3D.new()
	root.name = String(opts.get("name", "Room"))
	root.position = center
	parent.add_child(root)
	var w := size.x
	var h := size.y
	var d := size.z
	var floor_key := String(opts.get("floor", "wood_floor"))
	var surface := "wood"
	if floor_key.begins_with("stone") or floor_key == "marble" or floor_key == "void_stone":
		surface = "stone"
	elif floor_key.begins_with("carpet"):
		surface = "carpet"
	elif floor_key == "soil":
		surface = "dirt"
	box(root, Vector3(w + WALL_T * 2, 0.2, d + WALL_T * 2), Vector3(0, -0.1, 0), mat(floor_key), true, Vector3.ZERO, surface)
	if not opts.get("no_ceiling", false):
		box(root, Vector3(w + WALL_T * 2, 0.25, d + WALL_T * 2), Vector3(0, h + 0.125, 0), mat(String(opts.get("ceiling", "plaster"))))
		# ceiling beams
		if opts.get("beams", true):
			var nb := int(d / 2.4)
			for i in nb:
				var z := -d * 0.5 + (i + 0.5) * d / nb
				box(root, Vector3(w, 0.22, 0.18), Vector3(0, h - 0.11, z), mat("wood_dark"), false)
	var openings: Array = opts.get("openings", [])
	var skip: Array = opts.get("skip", [])
	var wall_key := String(opts.get("wall", "wallpaper"))
	var wains: bool = opts.get("wainscot", true)
	for side in ["n", "s", "e", "w"]:
		if skip.has(side):
			continue
		var ops: Array = []
		for o in openings:
			if o.get("side", "") == side:
				ops.append(o)
		_wall(root, side, w, h, d, ops, wall_key, wains)
	return root


static func _wall(root: Node3D, side: String, w: float, h: float, d: float, ops: Array, wall_key: String, wains: bool) -> void:
	var length := w if side in ["n", "s"] else d
	var wall_m := mat(wall_key)
	# local frame: t along wall (-L/2..L/2), normal points inward
	var inward := Vector3.ZERO
	var base := Vector3.ZERO
	match side:
		"n":
			base = Vector3(0, 0, -d * 0.5 - WALL_T * 0.5); inward = Vector3(0, 0, 1)
		"s":
			base = Vector3(0, 0, d * 0.5 + WALL_T * 0.5); inward = Vector3(0, 0, -1)
		"w":
			base = Vector3(-w * 0.5 - WALL_T * 0.5, 0, 0); inward = Vector3(1, 0, 0)
		"e":
			base = Vector3(w * 0.5 + WALL_T * 0.5, 0, 0); inward = Vector3(-1, 0, 0)
	var along := Vector3(1, 0, 0) if side in ["n", "s"] else Vector3(0, 0, 1)
	# sort openings
	var spans: Array = []
	for o in ops:
		var ow := float(o.get("width", 1.3))
		var off := float(o.get("offset", 0.0))
		spans.append({"a": off - ow * 0.5, "b": off + ow * 0.5, "bottom": float(o.get("bottom", 0.0)), "top": float(o.get("height", 2.35)) + float(o.get("bottom", 0.0))})
	spans.sort_custom(func(x, y): return x["a"] < y["a"])
	var cursor := -length * 0.5 - WALL_T
	var pieces: Array = []  # [t0, t1, y0, y1]
	for s in spans:
		if s["a"] > cursor:
			pieces.append([cursor, s["a"], 0.0, h])
		if s["bottom"] > 0.0:
			pieces.append([s["a"], s["b"], 0.0, s["bottom"]])
		if s["top"] < h:
			pieces.append([s["a"], s["b"], s["top"], h])
		cursor = s["b"]
	if cursor < length * 0.5 + WALL_T:
		pieces.append([cursor, length * 0.5 + WALL_T, 0.0, h])
	for p in pieces:
		var t0: float = p[0]
		var t1: float = p[1]
		var y0: float = p[2]
		var y1: float = p[3]
		var L := t1 - t0
		if L <= 0.01 or y1 - y0 <= 0.01:
			continue
		var c := base + along * ((t0 + t1) * 0.5) + Vector3.UP * ((y0 + y1) * 0.5)
		var sz := along * L + Vector3.UP * (y1 - y0) + inward.abs() * WALL_T
		box(root, sz, c, wall_m, true, Vector3.ZERO, "", true)
		# wainscot + baseboard on the lower part
		if wains and y0 < 0.05:
			var wh := minf(1.05, y1)
			var tt0 := maxf(t0, -length * 0.5)
			var tt1 := minf(t1, length * 0.5)
			if tt1 - tt0 > 0.05:
				var wc := base + inward * (WALL_T * 0.5 + 0.02) + along * ((tt0 + tt1) * 0.5) + Vector3.UP * (wh * 0.5)
				box(root, along * (tt1 - tt0) + Vector3.UP * wh + inward.abs() * 0.04, wc, mat("wainscot"), false)
				var rc := base + inward * (WALL_T * 0.5 + 0.045) + along * ((tt0 + tt1) * 0.5) + Vector3.UP * wh
				box(root, along * (tt1 - tt0) + Vector3.UP * 0.06 + inward.abs() * 0.07, rc, mat("wood_dark"), false)
	# crown molding along the top
	var cc := base + inward * (WALL_T * 0.5 + 0.06) + Vector3.UP * (h - 0.09)
	box(root, along * length + Vector3.UP * 0.18 + inward.abs() * 0.12, cc, mat("wood_dark"), false)
	# door / window frames
	for s in spans:
		var mid: float = (s["a"] + s["b"]) * 0.5
		var ow: float = s["b"] - s["a"]
		var fc := base + along * mid
		for sgn in [-1.0, 1.0]:
			var jamb: Vector3 = fc + along * (sgn * (ow * 0.5 + 0.06)) + Vector3.UP * ((s["bottom"] + s["top"]) * 0.5)
			box(root, along * 0.12 + Vector3.UP * (s["top"] - s["bottom"] + 0.12) + inward.abs() * (WALL_T + 0.08), jamb, mat("wood_dark"), false)
		var lintel: Vector3 = fc + Vector3.UP * (s["top"] + 0.08)
		box(root, along * (ow + 0.36) + Vector3.UP * 0.16 + inward.abs() * (WALL_T + 0.1), lintel, mat("wood_dark"), false)


# =================================================================== props
static func door(parent: Node, pos: Vector3, rot_y_deg: float, opts := {}) -> Door:
	var dr := Door.new()
	dr.position = pos
	dr.rotation_degrees.y = rot_y_deg
	dr.width = float(opts.get("width", 1.15))
	dr.height = float(opts.get("height", 2.25))
	dr.double = bool(opts.get("double", false))
	dr.locked = bool(opts.get("locked", false))
	dr.lock_line = String(opts.get("lock_line", "c1_locked_generic"))
	dr.key_item = String(opts.get("key", ""))
	if opts.has("name"):
		dr.name = String(opts["name"])
	parent.add_child(dr)
	return dr


static func candle(parent: Node, pos: Vector3, lit := true, with_light := true, color := Color(1.0, 0.6, 0.3), energy := 1.0, range_m := 4.5) -> FlickerLight:
	cyl(parent, 0.022, 0.026, 0.16, pos + Vector3(0, 0.08, 0), mat("wax"), false, 8)
	var flame := sphere(parent, 0.018, pos + Vector3(0, 0.185, 0), mat("flame"), Vector3(0.7, 1.6, 0.7))
	flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flame.visible = lit
	if not with_light:
		return null
	var l := light(parent, pos + Vector3(0, 0.3, 0), color, energy, range_m, false, 0.22)
	l.flame = flame
	if not lit:
		l.kill()
	return l


static func candelabra(parent: Node, pos: Vector3, lit := true, shadow := false) -> FlickerLight:
	cyl(parent, 0.04, 0.09, 0.05, pos + Vector3(0, 0.025, 0), mat("gilt"))
	cyl(parent, 0.015, 0.02, 0.4, pos + Vector3(0, 0.25, 0), mat("gilt"))
	box(parent, Vector3(0.36, 0.02, 0.02), pos + Vector3(0, 0.42, 0), mat("gilt"), false)
	var l: FlickerLight = null
	for x in [-0.17, 0.0, 0.17]:
		var cl := candle(parent, pos + Vector3(x, 0.43 + (0.06 if x == 0.0 else 0.0), 0), lit, x == 0.0, Color(1.0, 0.6, 0.3), 2.0, 7.0)
		if cl:
			l = cl
			l.shadow_enabled = shadow
	return l


static func sconce(parent: Node, pos: Vector3, facing: Vector3, lit := true, shadow := false) -> FlickerLight:
	var back := pos - facing * 0.06
	box(parent, Vector3(0.12, 0.22, 0.12) if absf(facing.x) < 0.5 else Vector3(0.12, 0.22, 0.12), back, mat("iron"), false)
	box(parent, Vector3(0.05, 0.04, 0.05) + facing.abs() * 0.18, pos + facing * 0.06 - Vector3(0, 0.05, 0), mat("iron"), false)
	var l := candle(parent, pos + facing * 0.14 - Vector3(0, 0.04, 0), lit, true, Color(1.0, 0.58, 0.3), 1.8, 6.5)
	if l:
		l.shadow_enabled = shadow
	return l


static func chandelier(parent: Node, pos: Vector3, radius := 1.0, lit := true, shadow := true) -> FlickerLight:
	cyl(parent, 0.01, 0.01, 2.0, pos + Vector3(0, 1.0, 0), mat("iron"))
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = radius - 0.04
	tm.outer_radius = radius
	ring.mesh = tm
	ring.material_override = mat("iron")
	ring.position = pos
	parent.add_child(ring)
	sphere(parent, 0.15, pos + Vector3(0, -0.1, 0), mat("iron"), Vector3(1, 1.6, 1))
	var n := 8
	for i in n:
		var a := TAU * i / n
		var p := pos + Vector3(cos(a) * radius, 0.02, sin(a) * radius)
		candle(parent, p, lit, false)
		# crystal drops
		sphere(parent, 0.03, p + Vector3(0, -0.12, 0), mat("glass_dark"), Vector3(0.6, 1.8, 0.6))
	var l := light(parent, pos + Vector3(0, -0.2, 0), Color(1.0, 0.6, 0.35), 4.0 if lit else 0.0, radius * 11.0, shadow, 0.08)
	if not lit:
		l.kill()
	return l


static func painting(parent: Node, pos: Vector3, rot_y_deg: float, size := Vector2(0.9, 1.2), variant := 0, seed_value := 0.0) -> MeshInstance3D:
	var root := node(parent, "Painting", pos, rot_y_deg)
	var t := 0.08
	box(root, Vector3(size.x + 0.16, t, 0.06), Vector3(0, size.y * 0.5 + 0.04, 0.02), mat("gilt"), false)
	box(root, Vector3(size.x + 0.16, t, 0.06), Vector3(0, -size.y * 0.5 - 0.04, 0.02), mat("gilt"), false)
	box(root, Vector3(t, size.y, 0.06), Vector3(size.x * 0.5 + 0.04, 0, 0.02), mat("gilt"), false)
	box(root, Vector3(t, size.y, 0.06), Vector3(-size.x * 0.5 - 0.04, 0, 0.02), mat("gilt"), false)
	var canvas := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = size
	canvas.mesh = q
	canvas.material_override = painting_mat(variant, seed_value)
	canvas.position = Vector3(0, 0, 0.01)
	root.add_child(canvas)
	return canvas


static func bed(parent: Node, pos: Vector3, rot_y_deg := 0.0, sheet_key := "fabric_white", posts := true) -> Node3D:
	var r := node(parent, "Bed", pos, rot_y_deg)
	box(r, Vector3(1.5, 0.35, 2.1), Vector3(0, 0.3, 0), mat("wood_dark"))
	box(r, Vector3(1.4, 0.2, 2.0), Vector3(0, 0.57, 0), mat(sheet_key), false)
	box(r, Vector3(0.55, 0.14, 0.35), Vector3(-0.35, 0.73, -0.75), mat("fabric_white"), false)
	box(r, Vector3(0.55, 0.14, 0.35), Vector3(0.35, 0.73, -0.75), mat("fabric_white"), false)
	box(r, Vector3(1.42, 0.06, 1.3), Vector3(0, 0.7, 0.3), mat("fabric_red" if sheet_key == "fabric_white" else "fabric_dark"), false)
	box(r, Vector3(1.55, 1.2, 0.08), Vector3(0, 0.75, -1.05), mat("wood_dark"))
	if posts:
		for x in [-0.72, 0.72]:
			for z in [-1.02, 1.02]:
				cyl(r, 0.04, 0.05, 2.0, Vector3(x, 1.0, z), mat("wood_dark"), false, 8)
		box(r, Vector3(1.5, 0.08, 0.06), Vector3(0, 2.0, 1.02), mat("wood_dark"), false)
		box(r, Vector3(1.5, 0.08, 0.06), Vector3(0, 2.0, -1.02), mat("wood_dark"), false)
	return r


static func desk(parent: Node, pos: Vector3, rot_y_deg := 0.0) -> Node3D:
	var r := node(parent, "Desk", pos, rot_y_deg)
	box(r, Vector3(1.3, 0.06, 0.65), Vector3(0, 0.78, 0), mat("wood_dark"))
	for x in [-0.6, 0.6]:
		for z in [-0.28, 0.28]:
			box(r, Vector3(0.06, 0.75, 0.06), Vector3(x, 0.375, z), mat("wood_dark"), false)
	box(r, Vector3(0.4, 0.22, 0.6), Vector3(0.42, 0.62, 0), mat("wood_dark"), false)
	return r


static func chair(parent: Node, pos: Vector3, rot_y_deg := 0.0, fallen := false) -> Node3D:
	var r := node(parent, "Chair", pos, rot_y_deg)
	if fallen:
		r.rotation_degrees.x = -82.0
		r.position.y += 0.25
	box(r, Vector3(0.45, 0.05, 0.45), Vector3(0, 0.46, 0), mat("wood_dark"), not fallen)
	box(r, Vector3(0.45, 0.6, 0.05), Vector3(0, 0.78, -0.2), mat("wood_dark"), false)
	for x in [-0.19, 0.19]:
		for z in [-0.19, 0.19]:
			box(r, Vector3(0.04, 0.46, 0.04), Vector3(x, 0.23, z), mat("wood_dark"), false)
	box(r, Vector3(0.38, 0.05, 0.38), Vector3(0, 0.5, 0.0), mat("fabric_red"), false)
	return r


static func wardrobe(parent: Node, pos: Vector3, rot_y_deg := 0.0) -> Node3D:
	var r := node(parent, "Wardrobe", pos, rot_y_deg)
	box(r, Vector3(1.3, 2.2, 0.6), Vector3(0, 1.1, 0), mat("wood_dark"))
	box(r, Vector3(1.4, 0.12, 0.66), Vector3(0, 2.25, 0), mat("wood_dark"), false)
	box(r, Vector3(0.6, 1.9, 0.03), Vector3(-0.31, 1.1, 0.31), mat("door_wood"), false)
	box(r, Vector3(0.6, 1.9, 0.03), Vector3(0.31, 1.1, 0.31), mat("door_wood"), false)
	return r


static func bookshelf(parent: Node, pos: Vector3, rot_y_deg := 0.0, width := 2.0, height := 2.6, rng_seed := 0, wood := "wood_dark") -> Node3D:
	var r := node(parent, "Bookshelf", pos, rot_y_deg)
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	box(r, Vector3(width, height, 0.42), Vector3(0, height * 0.5, -0.02), mat(wood))
	var shelves := int(height / 0.42)
	var colors := [Color(0.18, 0.04, 0.05), Color(0.06, 0.05, 0.12), Color(0.1, 0.08, 0.04), Color(0.05, 0.09, 0.07), Color(0.14, 0.12, 0.1), Color(0.03, 0.03, 0.03)]
	# one MultiMesh per shelf set for performance
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var bmesh := BoxMesh.new()
	bmesh.size = Vector3(1, 1, 1)
	mm.mesh = bmesh
	var transforms: Array = []
	for s in shelves:
		var y := 0.1 + s * 0.42
		var x := -width * 0.5 + 0.06
		while x < width * 0.5 - 0.1:
			var bw := rng.randf_range(0.035, 0.07)
			var bh := rng.randf_range(0.24, 0.36)
			var bd := rng.randf_range(0.22, 0.3)
			if rng.randf() < 0.08:
				x += rng.randf_range(0.1, 0.3)
				continue
			var lean := rng.randf_range(-0.12, 0.12) if rng.randf() < 0.15 else 0.0
			var b := Basis().rotated(Vector3(0, 0, 1), lean).scaled(Vector3(bw, bh, bd))
			transforms.append([Transform3D(b, Vector3(x + bw * 0.5, y + bh * 0.5, 0.06)), colors[rng.randi() % colors.size()] * rng.randf_range(0.7, 1.3)])
			x += bw + 0.004
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i][0])
		mm.set_instance_color(i, transforms[i][1])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	var bm := StandardMaterial3D.new()
	bm.vertex_color_use_as_albedo = true
	bm.roughness = 0.75
	mmi.material_override = bm
	r.add_child(mmi)
	# shelf boards (front lips)
	for s in shelves + 1:
		box(r, Vector3(width, 0.04, 0.44), Vector3(0, 0.08 + s * 0.42, 0.0), mat(wood), false)
	if wood == "wood_warm":
		# thick cornice with a gold line, like the Forbidden Library
		box(r, Vector3(width + 0.12, 0.16, 0.5), Vector3(0, height + 0.08, 0.0), mat(wood), false)
		box(r, Vector3(width + 0.13, 0.025, 0.51), Vector3(0, height + 0.02, 0.0), mat("gilt"), false)
	return r


static func table_long(parent: Node, pos: Vector3, length := 5.0, rot_y_deg := 0.0, set_table := true) -> Node3D:
	var r := node(parent, "Table", pos, rot_y_deg)
	box(r, Vector3(1.4, 0.08, length), Vector3(0, 0.78, 0), mat("wood_dark"))
	box(r, Vector3(1.5, 0.02, length + 0.1), Vector3(0, 0.83, 0), mat("fabric_white"), false)
	for z in [-length * 0.5 + 0.2, length * 0.5 - 0.2]:
		for x in [-0.6, 0.6]:
			box(r, Vector3(0.09, 0.76, 0.09), Vector3(x, 0.38, z), mat("wood_dark"), false)
	if set_table:
		var n := int(length / 0.9)
		for i in n:
			var z := -length * 0.5 + 0.45 + i * 0.9
			for x in [-0.45, 0.45]:
				cyl(r, 0.11, 0.09, 0.02, Vector3(x, 0.85, z), mat("fabric_white"))
				cyl(r, 0.03, 0.025, 0.12, Vector3(x * 0.7, 0.91, z + 0.18), mat("glass_dark"))
	return r


static func fireplace(parent: Node, pos: Vector3, rot_y_deg := 0.0, lit := false) -> FlickerLight:
	var r := node(parent, "Fireplace", pos, rot_y_deg)
	box(r, Vector3(2.0, 1.3, 0.6), Vector3(0, 0.65, 0), mat("stone_dark"))
	box(r, Vector3(1.1, 0.85, 0.62), Vector3(0, 0.45, 0.02), mat("black"), false)
	box(r, Vector3(2.3, 0.12, 0.75), Vector3(0, 1.35, 0.05), mat("marble"), false)
	if lit:
		var l := light(r, Vector3(0, 0.4, 0.5), Color(1.0, 0.4, 0.15), 1.5, 6.0, true, 0.3)
		sphere(r, 0.15, Vector3(0, 0.2, 0.25), mat("flame"), Vector3(2.0, 1.0, 1.0))
		return l
	return null


static func grandfather_clock(parent: Node, pos: Vector3, rot_y_deg := 0.0) -> Node3D:
	var r := node(parent, "Clock", pos, rot_y_deg)
	box(r, Vector3(0.55, 2.1, 0.4), Vector3(0, 1.05, 0), mat("wood_dark"))
	box(r, Vector3(0.6, 0.25, 0.45), Vector3(0, 2.2, 0), mat("wood_dark"), false)
	cyl(r, 0.2, 0.2, 0.03, Vector3(0, 1.75, 0.21), mat("paper"), false, 24, Vector3(90, 0, 0))
	box(r, Vector3(0.012, 0.14, 0.01), Vector3(0, 1.8, 0.23), mat("black"), false)
	box(r, Vector3(0.1, 0.012, 0.01), Vector3(0.04, 1.75, 0.23), mat("black"), false)
	return r


static func pillar(parent: Node, pos: Vector3, h := 6.0, r_m := 0.32, key := "stone") -> Node3D:
	var r := node(parent, "Pillar", pos)
	box(r, Vector3(r_m * 2.6, 0.3, r_m * 2.6), Vector3(0, 0.15, 0), mat(key))
	cyl(r, r_m, r_m * 1.05, h - 0.6, Vector3(0, h * 0.5, 0), mat(key), true, 12)
	box(r, Vector3(r_m * 2.6, 0.3, r_m * 2.6), Vector3(0, h - 0.15, 0), mat(key), false)
	return r


static func window(parent: Node, pos: Vector3, rot_y_deg: float, size := Vector2(1.2, 2.0), curtains := true) -> Node3D:
	var r := node(parent, "Window", pos, rot_y_deg)
	var g := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = size
	g.mesh = q
	g.material_override = mat("glass_dark")
	g.position = Vector3(0, size.y * 0.5, 0)
	r.add_child(g)
	box(r, Vector3(size.x, 0.05, 0.05), Vector3(0, size.y * 0.5, 0.02), mat("iron"), false)
	box(r, Vector3(0.05, size.y, 0.05), Vector3(0, size.y * 0.5, 0.02), mat("iron"), false)
	box(r, Vector3(size.x + 0.2, 0.08, 0.3), Vector3(0, -0.02, 0.1), mat("wood_dark"), false)
	if curtains:
		for sx in [-1.0, 1.0]:
			box(r, Vector3(size.x * 0.3, size.y + 0.6, 0.06), Vector3(sx * (size.x * 0.5 + 0.08), size.y * 0.5 + 0.2, 0.18), mat("fabric_red"), false)
	# collision to stop the player walking through
	var bs := BoxShape3D.new()
	bs.size = Vector3(size.x, size.y, 0.1)
	_add_collision(r, bs, Vector3(0, size.y * 0.5, 0))
	return r


static func stairs(parent: Node, start: Vector3, rot_y_deg: float, width: float, steps: int, rise := 0.18, run := 0.3, key := "carpet") -> Node3D:
	var r := node(parent, "Stairs", start, rot_y_deg)
	for i in steps:
		var y := (i + 1) * rise
		box(r, Vector3(width, y, run), Vector3(0, y * 0.5, -(i + 0.5) * run), mat("wood_dark"), false)
		box(r, Vector3(width * 0.8, 0.02, run), Vector3(0, y + 0.01, -(i + 0.5) * run), mat(key), false)
	# smooth slope collision for the player
	var total_run := steps * run
	var total_rise := steps * rise
	var ramp_len := sqrt(total_run * total_run + total_rise * total_rise)
	var bs := BoxShape3D.new()
	bs.size = Vector3(width, 0.1, ramp_len)
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.set_meta("surface", "wood")
	var cs := CollisionShape3D.new()
	cs.shape = bs
	body.add_child(cs)
	body.position = Vector3(0, total_rise * 0.5 - 0.02, -total_run * 0.5)
	body.rotation.x = atan2(total_rise, total_run)
	r.add_child(body)
	# banisters
	for sx in [-1.0, 1.0]:
		var rail := box(r, Vector3(0.07, 0.07, ramp_len), Vector3(sx * width * 0.5, total_rise * 0.5 + 0.95, -total_run * 0.5), mat("wood_dark"), false)
		rail.rotation.x = atan2(total_rise, total_run)
		var n := steps / 2
		for i in n:
			var z := -(i * 2 + 0.5) * run
			var y := (i * 2 + 1) * rise
			box(r, Vector3(0.04, 0.95, 0.04), Vector3(sx * width * 0.5, y + 0.47, z), mat("wood_dark"), false)
	return r


static func railing(parent: Node, a: Vector3, b: Vector3, h := 1.0) -> void:
	var mid := (a + b) * 0.5
	var L := a.distance_to(b)
	var along_x := absf(b.x - a.x) > absf(b.z - a.z)
	var sz := Vector3(L, 0.08, 0.08) if along_x else Vector3(0.08, 0.08, L)
	box(parent, sz, mid + Vector3(0, h, 0), mat("wood_dark"), false)
	var n := int(L / 0.35)
	for i in n + 1:
		var p := a.lerp(b, float(i) / maxf(1.0, n))
		box(parent, Vector3(0.04, h, 0.04), p + Vector3(0, h * 0.5, 0), mat("wood_dark"), false)
	var csz := Vector3(L, h + 0.4, 0.15) if along_x else Vector3(0.15, h + 0.4, L)
	var bs := BoxShape3D.new()
	bs.size = csz
	var holder := Node3D.new()
	holder.position = mid + Vector3(0, (h + 0.4) * 0.5, 0)
	parent.add_child(holder)
	_add_collision(holder, bs)


static func statue(parent: Node, pos: Vector3, rot_y_deg := 0.0, veiled := true) -> Node3D:
	var r := node(parent, "Statue", pos, rot_y_deg)
	box(r, Vector3(0.8, 0.9, 0.8), Vector3(0, 0.45, 0), mat("stone"))
	cyl(r, 0.18, 0.42, 1.5, Vector3(0, 1.65, 0), mat("stone" if not veiled else "fabric_white"), false, 12)
	sphere(r, 0.14, Vector3(0, 2.55, 0), mat("stone" if not veiled else "fabric_white"))
	if veiled:
		cyl(r, 0.2, 0.5, 1.9, Vector3(0, 1.85, 0), mat("fabric_white"), false, 10)
	return r


static func debris(parent: Node, center: Vector3, radius := 1.5, count := 10, rng_seed := 7) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	for i in count:
		var p := center + Vector3(rng.randf_range(-radius, radius), 0.05, rng.randf_range(-radius, radius))
		var s := Vector3(rng.randf_range(0.05, 0.9), rng.randf_range(0.03, 0.12), rng.randf_range(0.08, 0.25))
		box(parent, s, p, mat("wood_dark" if rng.randf() < 0.6 else "plaster"), false, Vector3(rng.randf_range(-10, 10), rng.randf_range(0, 180), rng.randf_range(-15, 15)))


static func boards(parent: Node, center: Vector3, rot_y_deg: float, width := 1.3, height := 2.2) -> Node3D:
	var r := node(parent, "Boards", center, rot_y_deg)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(center.x * 13 + center.z * 7)
	for i in 5:
		var y := 0.4 + i * 0.4
		box(r, Vector3(width + 0.3, 0.16, 0.04), Vector3(0, y, 0.12), mat("wood_floor"), false, Vector3(0, 0, rng.randf_range(-14, 14)))
	var bs := BoxShape3D.new()
	bs.size = Vector3(width, height, 0.2)
	_add_collision(r, bs, Vector3(0, height * 0.5, 0.1))
	return r


static func dead_tree(parent: Node, pos: Vector3, h := 7.0, rng_seed := 1) -> Node3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	var r := node(parent, "Tree", pos, rng.randf_range(0, 360))
	var trunk := cyl(r, 0.12, 0.32, h, Vector3(0, h * 0.5, 0), mat("bark"), true, 8)
	trunk.rotation_degrees = Vector3(rng.randf_range(-4, 4), 0, rng.randf_range(-4, 4))
	var branches := rng.randi_range(4, 7)
	for i in branches:
		var y := rng.randf_range(h * 0.35, h * 0.9)
		var bl := rng.randf_range(1.0, 2.8)
		var a := rng.randf_range(0, 360)
		var b := Node3D.new()
		b.position = Vector3(0, y, 0)
		b.rotation_degrees = Vector3(0, a, rng.randf_range(35, 70))
		r.add_child(b)
		cyl(b, 0.02, 0.08, bl, Vector3(0, bl * 0.5, 0), mat("bark"), false, 6)
		if rng.randf() < 0.6:
			var b2 := Node3D.new()
			b2.position = Vector3(0, bl * 0.7, 0)
			b2.rotation_degrees = Vector3(rng.randf_range(-40, 40), 0, rng.randf_range(-50, 50))
			b.add_child(b2)
			cyl(b2, 0.01, 0.04, bl * 0.6, Vector3(0, bl * 0.3, 0), mat("bark"), false, 5)
	return r


static func gravestone(parent: Node, pos: Vector3, rot_y_deg := 0.0, rng_seed := 0) -> Node3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	var r := node(parent, "Grave", pos, rot_y_deg)
	var h := rng.randf_range(0.7, 1.2)
	var stone := box(r, Vector3(0.6, h, 0.15), Vector3(0, h * 0.5, 0), mat("stone"), true)
	stone.rotation_degrees = Vector3(rng.randf_range(-8, 8), 0, rng.randf_range(-10, 10))
	cyl(r, 0.3, 0.3, 0.15, Vector3(0, h, 0), mat("stone"), false, 12, Vector3(90, 0, 0))
	return r


## Floating broken architecture in the void (arches, wall chunks, stairs to nowhere).
static func floating_ruin(parent: Node, pos: Vector3, rng_seed := 0, scale := 1.0) -> Node3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	var r := node(parent, "Ruin", pos, rng.randf_range(0, 360))
	r.scale = Vector3.ONE * scale
	r.rotation_degrees.x = rng.randf_range(-15, 15)
	r.rotation_degrees.z = rng.randf_range(-15, 15)
	var kind := rng.randi() % 4
	match kind:
		0:
			for sx in [-1.5, 1.5]:
				box(r, Vector3(0.6, 4.0, 0.6), Vector3(sx, 2.0, 0), mat("void_stone"), false)
			box(r, Vector3(3.8, 0.6, 0.7), Vector3(0, 4.2, 0), mat("void_stone"), false)
		1:
			box(r, Vector3(4.0, 3.0, 0.3), Vector3(0, 1.5, 0), mat("wallpaper"), false)
			box(r, Vector3(4.0, 0.2, 2.5), Vector3(0, 0, 1.2), mat("wood_floor"), false)
			painting(r, Vector3(0.5, 1.8, 0.17), 0, Vector2(0.7, 0.9), rng.randi() % 6, rng.randf() * 10)
		2:
			for i in 8:
				box(r, Vector3(1.4, 0.2, 0.35), Vector3(0, i * 0.2, -i * 0.35), mat("void_stone"), false)
		_:
			box(r, Vector3(2.5, 0.5, 2.5), Vector3(0, 0, 0), mat("void_stone"), false)
			chair(r, Vector3(0.3, 0.25, 0.2), rng.randf_range(0, 360))
	return r


## A single fog volume (local, denser fog) — only active with volumetric fog.
static func fog_volume(parent: Node, pos: Vector3, size: Vector3, density := 0.6, albedo := Color(0.42, 0.25, 0.55)) -> FogVolume:
	if not Settings.is_forward_plus():
		return null   # local fog volumes need Forward+ (mobile uses classic fog)
	var fv := FogVolume.new()
	fv.size = size
	fv.position = pos
	var fm := FogMaterial.new()
	fm.density = density * 0.25
	fm.albedo = albedo
	fm.emission = Color(0.02, 0.0, 0.04)
	fm.height_falloff = 0.3
	fm.edge_fade = 0.3
	fv.material = fm
	parent.add_child(fv)
	return fv


## Message written directly on a wall (the two Satellas' handwritings).
static func wall_writing(parent: Node, pos: Vector3, rot_y_deg: float, text: String, author: String, size := 0.09) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.position = pos
	l.rotation_degrees.y = rot_y_deg
	l.pixel_size = size * 0.01
	l.font_size = 64
	l.outline_size = 0
	l.shaded = false
	l.double_sided = false
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.width = 1400
	if author == "original":
		l.modulate = Color(0.82, 0.86, 0.98, 0.9)
	elif author == "witch":
		l.modulate = Color(0.45, 0.05, 0.6, 0.95)
		l.font_size = 72
	else:
		l.modulate = Color(0.6, 0.55, 0.5, 0.8)
	parent.add_child(l)
	return l


# =================================================================== Re:Zero mansion pieces
## Barrel vault (inside surface) over a corridor, with arched ribs.
## `center` = middle of the springing line (top of the walls).
static func vault(parent: Node, center: Vector3, width: float, length: float, along_x := true, key := "plaster_cream", rib_every := 3.5) -> Node3D:
	var root := node(parent, "Vault", center)
	var r := width * 0.5
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs := 18
	var rings := maxi(2, int(length / 2.0) + 1)
	for i in rings:
		var t := float(i) / float(rings - 1)
		var u := (t - 0.5) * length
		for j in segs + 1:
			var a := PI * float(j) / float(segs)
			var c := cos(a) * r
			var y := sin(a) * r
			var v := Vector3(u, y, c) if along_x else Vector3(c, y, u)
			var n := -Vector3(0, sin(a), cos(a)) if along_x else -Vector3(cos(a), sin(a), 0)
			st.set_normal(n)
			st.set_uv(Vector2(u, a * r))
			st.add_vertex(v)
	for i in rings - 1:
		for j in segs:
			var a0 := i * (segs + 1) + j
			var b0 := a0 + segs + 1
			for idx in [a0, b0, a0 + 1, a0 + 1, b0, b0 + 1, a0, a0 + 1, b0, a0 + 1, b0 + 1, b0]:
				st.add_index(idx)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat(key)
	root.add_child(mi)
	# ribs
	var n_ribs := int(length / rib_every)
	for k in n_ribs + 1:
		var u2 := -length * 0.5 + k * (length / maxf(1.0, n_ribs))
		for j in 9:
			var a1 := PI * j / 9.0
			var a2 := PI * (j + 1) / 9.0
			var am := (a1 + a2) * 0.5
			var seg_len := 2.0 * (r - 0.06) * sin((a2 - a1) * 0.5)
			var pc := Vector3(0, sin(am) * (r - 0.08), cos(am) * (r - 0.08))
			var rib := box(root, Vector3(0.22, 0.12, seg_len + 0.02), Vector3(u2, pc.y, pc.z) if along_x else Vector3(pc.z, pc.y, u2), mat("plaster_cream"), false)
			if along_x:
				rib.rotation.x = -(am - PI * 0.5)
			else:
				rib.rotation.z = (am - PI * 0.5)
				rib.rotation.y = PI * 0.5
	# lunettes closing both ends
	for e in [-1.0, 1.0]:
		var cap := box(root, Vector3(0.12, r + 0.1, width) if along_x else Vector3(width, r + 0.1, 0.12), (Vector3(e * length * 0.5, r * 0.5, 0) if along_x else Vector3(0, r * 0.5, e * length * 0.5)), mat("panel_cream"), false)
		cap.name = "Lunette"
	return root


## Red runner with green borders and gold lines (the mansion corridors).
static func runner(parent: Node, center: Vector3, length: float, along_x := true, width := 2.2) -> void:
	var sz := func(w: float) -> Vector3: return Vector3(length, 0.012, w) if along_x else Vector3(w, 0.012, length)
	var off := func(o: float) -> Vector3: return center + (Vector3(0, 0, o) if along_x else Vector3(o, 0, 0))
	box(parent, sz.call(width - 0.6), off.call(0.0) + Vector3(0, 0.008, 0), mat("red_carpet"), false)
	for sgn in [-1.0, 1.0]:
		box(parent, sz.call(0.05), off.call(sgn * (width * 0.5 - 0.28)) + Vector3(0, 0.009, 0), mat("gilt"), false)
		box(parent, sz.call(0.22), off.call(sgn * (width * 0.5 - 0.14)) + Vector3(0, 0.007, 0), mat("green_border"), false)


## Wall lantern with green glass (eerie at night).
static func lantern(parent: Node, pos: Vector3, facing: Vector3, lit := true) -> FlickerLight:
	box(parent, Vector3(0.05, 0.05, 0.05) + facing.abs() * 0.25, pos - facing * 0.02 + Vector3(0, 0.22, 0), mat("iron"), false)
	var body := pos + facing * 0.16
	box(parent, Vector3(0.17, 0.3, 0.17), body, mat("lantern_glass") if lit else mat("glass_dark"), false)
	cyl(parent, 0.0, 0.14, 0.14, body + Vector3(0, 0.22, 0), mat("iron"), false, 4)
	box(parent, Vector3(0.2, 0.03, 0.2), body - Vector3(0, 0.16, 0), mat("iron"), false)
	var l := light(parent, body, Color(0.5, 0.95, 0.6), 1.0, 6.0, false, 0.05)
	if not lit:
		l.kill()
	return l


## Pilaster with base and capital against a wall. `facing` points into the room.
static func pilaster(parent: Node, pos: Vector3, facing: Vector3, height := 4.0) -> void:
	var w := Vector3(0.34, 0, 0.34) - facing.abs() * 0.22
	box(parent, w + Vector3(0, height, 0), pos + facing * 0.06 + Vector3(0, height * 0.5, 0), mat("plaster_cream"), false)
	box(parent, w * 1.35 + facing.abs() * 0.05 + Vector3(0, 0.25, 0), pos + facing * 0.08 + Vector3(0, 0.125, 0), mat("plaster_cream"), false)
	box(parent, w * 1.5 + facing.abs() * 0.1 + Vector3(0, 0.18, 0), pos + facing * 0.11 + Vector3(0, height - 0.15, 0), mat("plaster_cream"), false)
	box(parent, w * 1.2 + facing.abs() * 0.06 + Vector3(0, 0.12, 0), pos + facing * 0.09 + Vector3(0, height - 0.33, 0), mat("gilt"), false)


static func bench(parent: Node, pos: Vector3, rot_y_deg := 0.0) -> void:
	var r := node(parent, "Bench", pos, rot_y_deg)
	box(r, Vector3(0.95, 0.12, 0.42), Vector3(0, 0.42, 0), mat("cushion_white"))
	for x in [-0.4, 0.4]:
		for z in [-0.16, 0.16]:
			cyl(r, 0.025, 0.035, 0.38, Vector3(x, 0.19, z), mat("wood_warm"), false, 6)


static func vase_table(parent: Node, pos: Vector3, rot_y_deg := 0.0) -> void:
	var r := node(parent, "VaseTable", pos, rot_y_deg)
	cyl(r, 0.28, 0.28, 0.04, Vector3(0, 0.82, 0), mat("wood_warm"), true, 16)
	for i in 3:
		var a := TAU * i / 3.0
		cyl(r, 0.02, 0.03, 0.8, Vector3(cos(a) * 0.18, 0.4, sin(a) * 0.18), mat("wood_warm"), false, 6)
	cyl(r, 0.06, 0.09, 0.3, Vector3(0, 0.99, 0), mat("porcelain"), false, 12)
	for i in 7:
		var a2 := TAU * i / 7.0
		sphere(r, 0.06, Vector3(cos(a2) * 0.09, 1.2 + (i % 2) * 0.05, sin(a2) * 0.09), mat("flower_pink" if i % 3 else "cushion_white"))


## Tall window with blue curtains (bedroom / corridor).
static func tall_window(parent: Node, pos: Vector3, rot_y_deg: float, size := Vector2(1.3, 2.8), curtains := true) -> Node3D:
	var r := node(parent, "TallWindow", pos, rot_y_deg)
	var g := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = size
	g.mesh = q
	g.material_override = mat("window_glass")
	g.position = Vector3(0, size.y * 0.5, 0)
	r.add_child(g)
	# white frame, mullions and transom
	for x in [-size.x * 0.5, 0.0, size.x * 0.5]:
		box(r, Vector3(0.06, size.y, 0.08), Vector3(x, size.y * 0.5, 0.02), mat("cushion_white"), false)
	for y in [0.0, size.y * 0.72, size.y]:
		box(r, Vector3(size.x, 0.06, 0.08), Vector3(0, y, 0.02), mat("cushion_white"), false)
	if curtains:
		for sx in [-1.0, 1.0]:
			box(r, Vector3(size.x * 0.28, size.y + 0.5, 0.06), Vector3(sx * (size.x * 0.5 + 0.12), size.y * 0.5 + 0.15, 0.2), mat("curtain_blue"), false)
		box(r, Vector3(size.x + 0.8, 0.28, 0.1), Vector3(0, size.y + 0.35, 0.24), mat("curtain_blue"), false)
	var bs := BoxShape3D.new()
	bs.size = Vector3(size.x, size.y, 0.1)
	_add_collision(r, bs, Vector3(0, size.y * 0.5, 0))
	return r


## A wing of the mansion seen from outside (front faces local -Z).
static func mansion_block(parent: Node, pos: Vector3, size: Vector3, rot_y_deg := 0.0, dormers := true) -> Node3D:
	var r := node(parent, "MansionBlock", pos, rot_y_deg)
	box(r, size, Vector3(0, size.y * 0.5, 0), mat("facade"), false)
	# mansard roof: two slopes + flat top
	var rh := 3.2
	for sgn in [-1.0, 1.0]:
		var slope := box(r, Vector3(size.x, 0.25, rh * 1.35), Vector3(0, size.y + rh * 0.5, sgn * (size.z * 0.5 - rh * 0.3)), mat("slate"), false)
		slope.rotation.x = sgn * deg_to_rad(62)
	box(r, Vector3(size.x, 0.2, size.z - rh * 1.1), Vector3(0, size.y + rh, 0), mat("slate"), false)
	# cornice
	box(r, Vector3(size.x + 0.3, 0.35, size.z + 0.3), Vector3(0, size.y, 0), mat("plaster_cream"), false)
	if dormers:
		var n := int(size.x / 5.2)
		for i in n:
			var x := -size.x * 0.5 + 2.6 + i * 5.2
			box(r, Vector3(1.0, 1.4, 0.9), Vector3(x, size.y + 1.4, -size.z * 0.5 + 1.2), mat("facade"), false)
			var cap := box(r, Vector3(1.3, 0.2, 1.1), Vector3(x, size.y + 2.2, -size.z * 0.5 + 1.2), mat("slate"), false)
			cap.rotation.z = 0.0
	for i in int(size.x / 9.0):
		box(r, Vector3(0.6, 2.2, 0.6), Vector3(-size.x * 0.5 + 4.5 + i * 9.0, size.y + rh + 0.8, size.z * 0.2), mat("facade"), false)
	return r


static func tower(parent: Node, pos: Vector3, radius := 1.6, height := 20.0, spire := 7.0) -> Node3D:
	var r := node(parent, "Tower", pos)
	cyl(r, radius, radius, height, Vector3(0, height * 0.5, 0), mat("facade"), false, 16)
	cyl(r, radius + 0.2, radius + 0.2, 0.4, Vector3(0, height, 0), mat("plaster_cream"), false, 16)
	cyl(r, 0.0, radius + 0.25, spire, Vector3(0, height + spire * 0.5, 0), mat("slate"), false, 12)
	cyl(r, 0.03, 0.05, 1.6, Vector3(0, height + spire + 0.6, 0), mat("iron"), false, 6)
	return r


static func topiary(parent: Node, pos: Vector3, h := 3.2) -> void:
	cyl(parent, 0.0, h * 0.22, h, pos + Vector3(0, h * 0.5 + 0.2, 0), mat("topiary"), false, 10)
	cyl(parent, 0.06, 0.08, 0.4, pos + Vector3(0, 0.2, 0), mat("bark"), false, 6)


static func lamp_post(parent: Node, pos: Vector3, lit := true) -> FlickerLight:
	cyl(parent, 0.05, 0.08, 3.2, pos + Vector3(0, 1.6, 0), mat("iron"), false, 8)
	box(parent, Vector3(0.28, 0.4, 0.28), pos + Vector3(0, 3.4, 0), mat("glass_dark") if not lit else mat("flame"), false)
	cyl(parent, 0.0, 0.24, 0.3, pos + Vector3(0, 3.75, 0), mat("iron"), false, 4)
	var l := light(parent, pos + Vector3(0, 3.3, 0), Color(1.0, 0.75, 0.5), 1.4, 9.0, false, 0.08)
	if not lit:
		l.kill()
	return l


## Puts every visual of `n` on render layer 3 as well (exterior lighting).
static func mark_exterior(n: Node) -> void:
	if n is VisualInstance3D:
		(n as VisualInstance3D).layers |= 4
	for c in n.get_children():
		mark_exterior(c)
