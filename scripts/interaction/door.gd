class_name Door
extends Node3D
## Hinged mansion door (single or double), with:
##  * open / close / slam animations and sounds (opens away from the player),
##  * lock state with a message or a required item,
##  * PORTAL mode: the doorway leads somewhere else in the dimension. A black
##    "nothing" fills the frame; stepping into it teleports the player to the
##    `portal_target` door, keeping the relative orientation (impossible doors).
##  * Satella interaction: she can stop behind it, then smash it open.
##
## Local space: the door faces +Z (its "front"), width along X, hinge on -X.

signal opened
signal closed
signal portal_crossed(player: Node)

@export var width := 1.15
@export var height := 2.25
@export var locked := false
@export var lock_line := "c1_locked_generic"   ## dialogue id shown when locked
@export var key_item := ""
@export var double := false
@export var open_angle := 100.0
@export var material_key := "door_wood"

var is_open := false
var portal_target: Door = null           ## When set, the doorway is an impossible passage.
var portal_callable: Callable            ## Alternative: custom teleport callable(player).
var on_open: Callable                    ## Optional hook (puzzles).
var interact_area: Interactable
var _panels: Array[Node3D] = []
var _tween: Tween
var _void_plane: MeshInstance3D
var _portal_area: Area3D
var _portal_cooldown := 0.0


func _ready() -> void:
	add_to_group("doors")
	_build()


func _build() -> void:
	var mat := Builder.mat(material_key)
	var leaves := 2 if double else 1
	var leaf_w := width / leaves
	for i in leaves:
		var hinge := Node3D.new()
		hinge.name = "Hinge%d" % i
		var side := -1.0 if i == 0 else 1.0
		hinge.position = Vector3(side * width * 0.5, 0, 0)
		add_child(hinge)
		var body := AnimatableBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		body.sync_to_physics = false
		hinge.add_child(body)
		var center := Vector3(-side * leaf_w * 0.5, height * 0.5, 0)
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(leaf_w - 0.02, height - 0.02, 0.06)
		mi.mesh = bm
		mi.material_override = mat
		mi.position = center
		body.add_child(mi)
		# raised panels for a gothic look
		for py in [0.55, 1.55]:
			var pm := MeshInstance3D.new()
			var pb := BoxMesh.new()
			pb.size = Vector3(leaf_w * 0.62, 0.7 if py < 1.0 else 0.85, 0.08)
			pm.mesh = pb
			pm.material_override = mat
			pm.position = Vector3(center.x, py * height / 2.25, 0)
			body.add_child(pm)
		# handle
		var hm := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.035
		sm.height = 0.07
		hm.mesh = sm
		hm.material_override = Builder.mat("gilt")
		for zz in [0.06, -0.06]:
			var h2 := hm.duplicate() as MeshInstance3D
			h2.position = Vector3(-side * (leaf_w - 0.12), 1.0, zz)
			body.add_child(h2)
		hm.queue_free()
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = bm.size
		cs.shape = shape
		cs.position = center
		body.add_child(cs)
		_panels.append(hinge)
	# interaction zone covering the whole doorway
	interact_area = Interactable.new()
	interact_area.name = "Interact"
	interact_area.set_box(Vector3(width, height, 0.3), Vector3(0, height * 0.5, 0))
	interact_area.prompt_func = _prompt
	interact_area.action = _on_used
	add_child(interact_area)


func _prompt() -> String:
	if is_open:
		return "Fermer"
	if locked:
		return "Ouvrir (verrouillée)"
	return "Ouvrir"


func _on_used(player: Node) -> void:
	if is_open:
		close()
		return
	if locked:
		if key_item != "" and GameState.has_item(key_item):
			locked = false
			AudioManager.play_3d("door_locked", global_position + Vector3.UP, -6.0)
		else:
			AudioManager.play_3d("door_locked", global_position + Vector3.UP, -2.0)
			if lock_line != "" and not DialogueManager.is_busy():
				DialogueManager.say(lock_line)
			return
	var away := 1.0
	if player is Node3D:
		var local := to_local((player as Node3D).global_position)
		away = -1.0 if local.z > 0.0 else 1.0
	open(away)


## dir: +1 opens toward -Z (away from a player standing in front, +Z), -1 the other way.
func open(dir := 1.0, speed := 0.55, silent := false) -> void:
	if is_open:
		return
	is_open = true
	if not silent:
		AudioManager.play_3d("door_open", global_position + Vector3.UP * 1.2, -3.0, 6.0, randf_range(0.9, 1.05))
	_animate(open_angle * dir, speed)
	if portal_target != null or portal_callable.is_valid():
		_ensure_portal()
		_void_plane.visible = true
		_portal_area.monitoring = true
	opened.emit()
	if on_open.is_valid():
		on_open.call()


func close(speed := 0.6, silent := false) -> void:
	if not is_open:
		return
	is_open = false
	if not silent:
		AudioManager.play_3d("door_close", global_position + Vector3.UP * 1.2, -4.0, 6.0)
	_animate(0.0, speed)
	closed.emit()


## Violent opening (Satella, events). Ignores locks.
func slam_open(dir := 1.0) -> void:
	var was_open := is_open
	is_open = false
	if was_open:
		_animate(0.0, 0.05)
	is_open = true
	AudioManager.play_3d("door_slam", global_position + Vector3.UP * 1.2, 4.0, 10.0)
	EventBus.camera_shake.emit(0.35, 0.4)
	_animate(open_angle * 1.15 * dir, 0.18, Tween.TRANS_BACK)
	if portal_target != null or portal_callable.is_valid():
		_ensure_portal()
		_void_plane.visible = true
		_portal_area.monitoring = true


## Violent closing (horror events).
func slam_shut() -> void:
	is_open = false
	AudioManager.play_3d("door_slam", global_position + Vector3.UP * 1.2, 4.0, 10.0)
	EventBus.camera_shake.emit(0.3, 0.35)
	_animate(0.0, 0.15)
	closed.emit()


func _animate(angle_deg: float, duration: float, trans := Tween.TRANS_SINE) -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween().set_parallel(true).set_trans(trans).set_ease(Tween.EASE_OUT)
	for i in _panels.size():
		var side := 1.0 if i == 0 else -1.0
		_tween.tween_property(_panels[i], "rotation:y", deg_to_rad(angle_deg) * side, duration)


## Builds the black "nothing" and the teleport trigger of an impossible door.
func _ensure_portal() -> void:
	if _void_plane != null:
		return
	_void_plane = MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(width, height)
	_void_plane.mesh = qm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.0, 0.0, 0.0)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_void_plane.material_override = m
	_void_plane.position = Vector3(0, height * 0.5, -0.35)
	add_child(_void_plane)
	_portal_area = Area3D.new()
	_portal_area.collision_layer = 0
	_portal_area.collision_mask = 2
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(width, height, 0.3)
	cs.shape = bs
	cs.position = Vector3(0, height * 0.5, -0.3)
	_portal_area.add_child(cs)
	add_child(_portal_area)
	_portal_area.body_entered.connect(_on_portal_body)


## Turns this door into an impossible passage toward `target` (or a callable).
func set_portal(target: Door, custom: Callable = Callable()) -> void:
	portal_target = target
	portal_callable = custom
	if target == null and not custom.is_valid() and _void_plane != null:
		_void_plane.visible = false
		_portal_area.set_deferred("monitoring", false)


func _process(delta: float) -> void:
	if _portal_cooldown > 0.0:
		_portal_cooldown -= delta


func _on_portal_body(body: Node) -> void:
	if _portal_cooldown > 0.0 or not body.has_method("teleport_to"):
		return
	_portal_cooldown = 1.0
	portal_crossed.emit(body)
	if portal_callable.is_valid():
		portal_callable.call(body)
		return
	if portal_target == null:
		return
	# Keep the relative yaw: walking "into" this door = walking "out of" the target.
	var p := body as Node3D
	var rel_yaw: float = p.global_rotation.y - global_rotation.y
	var exit_basis := portal_target.global_transform.basis
	var exit_pos := portal_target.global_position + exit_basis.z * 0.9
	exit_pos.y = portal_target.global_position.y + 0.05
	var new_yaw: float = portal_target.global_rotation.y + rel_yaw + PI
	portal_target._portal_cooldown = 1.0
	body.call("teleport_to", exit_pos, new_yaw)
	portal_target.open(-1.0, 0.01, true)
	close(0.3, true)
	portal_target.call_deferred("close", 0.9)


func doorway_center() -> Vector3:
	return global_position + Vector3.UP * 1.0
