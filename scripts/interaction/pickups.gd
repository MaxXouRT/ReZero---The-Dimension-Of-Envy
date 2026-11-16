class_name Pickups
extends RefCounted
## Factory for collectable objects: seal fragments, items, batteries.
## Each pickup = a visual + an Interactable; inspecting is offered for
## story items through EventBus.inspect_requested.


## A shard of the seal of the Dimension of Envy.
static func fragment_visual(parent: Node, pos: Vector3) -> Spinner:
	var s := Spinner.new()
	s.name = "Fragment"
	s.position = pos
	parent.add_child(s)
	var shard := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.0
	cm.bottom_radius = 0.09
	cm.height = 0.26
	cm.radial_segments = 5
	cm.rings = 1
	shard.mesh = cm
	shard.material_override = Builder.mat("seal_fragment")
	shard.position = Vector3(0, 0.13, 0)
	s.add_child(shard)
	var bottom := shard.duplicate() as MeshInstance3D
	bottom.rotation_degrees.x = 180
	bottom.scale = Vector3(1, 0.6, 1)
	bottom.position = Vector3(0, -0.07, 0)
	s.add_child(bottom)
	var l := OmniLight3D.new()
	l.light_color = Color(0.6, 0.25, 0.95)
	l.light_energy = 0.8
	l.omni_range = 2.5
	l.light_volumetric_fog_energy = 3.0
	s.add_child(l)
	return s


## Fragment pickup: calls GameState.collect_fragment then on_taken().
static func fragment(parent: Node, pos: Vector3, fragment_id: String, on_taken: Callable = Callable()) -> Node3D:
	if GameState.has_fragment(fragment_id):
		return null
	var vis := fragment_visual(parent, pos)
	var inter := Builder.interactable(parent, pos, Vector3(0.6, 0.7, 0.6), "Prendre le fragment du sceau", Callable(), true)
	inter.action = func(_p):
		AudioManager.play_2d("fragment_chime", -2.0)
		GameState.collect_fragment(fragment_id)
		GameState.set_flag("fragment_" + fragment_id)
		EnvyAwareness.gain("fragment")
		EventBus.toast.emit("Fragment du sceau obtenu : " + GameState.FRAGMENT_NAMES.get(fragment_id, fragment_id))
		vis.queue_free()
		inter.queue_free()
		if on_taken.is_valid():
			on_taken.call()
	return vis


## Generic item: a mesh-like Node3D the caller already built (`visual`).
static func item(parent: Node, visual: Node3D, item_id: String, prompt: String, title: String, description: String, on_taken: Callable = Callable()) -> Interactable:
	if GameState.has_item(item_id) or GameState.has_flag("taken_" + item_id):
		visual.queue_free()
		return null
	var inter := Builder.interactable(parent, visual.position, Vector3(0.5, 0.4, 0.5), prompt, Callable(), true)
	inter.action = func(_p):
		AudioManager.play_2d("pickup", -4.0)
		GameState.add_item(item_id)
		GameState.set_flag("taken_" + item_id)
		EventBus.toast.emit(title)
		if description != "":
			EventBus.inspect_requested.emit(visual, title, description)
		visual.visible = false
		inter.queue_free()
		if on_taken.is_valid():
			on_taken.call()
	return inter


static func battery(parent: Node, pos: Vector3, battery_id: String) -> void:
	if GameState.has_flag("taken_" + battery_id):
		return
	var vis := Node3D.new()
	vis.position = pos
	parent.add_child(vis)
	Builder.cyl(vis, 0.035, 0.035, 0.12, Vector3(0, 0.06, 0), Builder.mat("iron"), false, 10, Vector3(0, 0, 90))
	var inter := Builder.interactable(parent, pos, Vector3(0.4, 0.3, 0.4), "Prendre la pile", Callable(), true)
	inter.action = func(p):
		GameState.set_flag("taken_" + battery_id)
		if p is PlayerController:
			(p as PlayerController).flashlight.add_battery()
		EventBus.toast.emit("Pile neuve — lampe rechargée")
		vis.queue_free()
		inter.queue_free()
