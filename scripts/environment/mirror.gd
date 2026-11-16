class_name Mirror
extends Node3D
## Real-time mirror (reflection camera + SubViewport + oblique-free frustum).
##
## The reflection camera also renders visual layer 2 ("mirror-only"), which
## the player's camera does not: Satella can therefore exist ONLY inside a
## reflection. Subaru himself has no visible body... so the mirror shows
## the room, but not him. (It is not a bug. Look closer at chapter 5.)
##
## Local space: the reflective face looks toward +Z, centred on the origin.

const MIRROR_SHADER := preload("res://shaders/mirror.gdshader")

@export var size := Vector2(1.0, 1.6)
@export var resolution := 512
@export var active_distance := 14.0

var viewport: SubViewport
var cam: Camera3D
var surface: MeshInstance3D
var mat: ShaderMaterial
var player: PlayerController


func _ready() -> void:
	add_to_group("mirrors")
	viewport = SubViewport.new()
	viewport.size = Vector2i(resolution, int(resolution * size.y / size.x))
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	viewport.msaa_3d = Viewport.MSAA_DISABLED
	viewport.positional_shadow_atlas_size = 1024
	add_child(viewport)
	cam = Camera3D.new()
	cam.cull_mask = 0xFFFFF
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	viewport.add_child(cam)
	surface = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = size
	surface.mesh = q
	mat = ShaderMaterial.new()
	mat.shader = MIRROR_SHADER
	mat.set_shader_parameter("reflection", viewport.get_texture())
	surface.material_override = mat
	surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(surface)
	# frame
	var frame_mat := Builder.mat("gilt")
	for v in [Vector3(0, size.y * 0.5 + 0.05, -0.02), Vector3(0, -size.y * 0.5 - 0.05, -0.02)]:
		Builder.box(self, Vector3(size.x + 0.2, 0.1, 0.06), v, frame_mat, false)
	for v in [Vector3(size.x * 0.5 + 0.05, 0, -0.02), Vector3(-size.x * 0.5 - 0.05, 0, -0.02)]:
		Builder.box(self, Vector3(0.1, size.y, 0.06), v, frame_mat, false)
	EventBus.player_spawned.connect(func(p): player = p)


func crack(amount := 1.0) -> void:
	mat.set_shader_parameter("crack", amount)
	AudioManager.play_3d("glass_crack", global_position, 0.0)


func _process(_delta: float) -> void:
	if player == null:
		var ps := get_tree().get_nodes_in_group("player")
		if ps.is_empty():
			return
		player = ps[0]
	var pc := player.camera
	var lp := to_local(pc.global_position)
	var in_front := lp.z > 0.05
	var near_enough := lp.length() < active_distance
	var visible_now := in_front and near_enough and pc.is_position_in_frustum(global_position)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if visible_now else SubViewport.UPDATE_DISABLED
	if not visible_now:
		return
	# reflected camera position in mirror space, looking back through the glass
	var rp := Vector3(lp.x, lp.y, -lp.z)
	var basis_cam := global_transform.basis.orthonormalized() * Basis(Vector3.UP, PI)
	cam.global_transform = Transform3D(basis_cam, to_global(rp))
	var near := maxf(0.05, absf(rp.z))
	cam.set_frustum(size.y, Vector2(rp.x, -rp.y), near, 120.0)
	cam.environment = pc.get_world_3d().environment if pc.get_world_3d() else null


## True if the player currently sees the reflection of world point `p`.
func reflects_point_for_player(p: Vector3) -> bool:
	if player == null:
		return false
	var pc := player.camera
	var c := to_local(pc.global_position)
	var lp := to_local(p)
	if c.z <= 0.05 or lp.z <= 0.0:
		return false
	if not pc.is_position_in_frustum(global_position):
		return false
	var r := Vector3(lp.x, lp.y, -lp.z)
	var t := c.z / (c.z - r.z)
	var hit := c + (r - c) * t
	if absf(hit.x) > size.x * 0.5 or absf(hit.y) > size.y * 0.5:
		return false
	# the player must be looking roughly at the mirror
	var to_m := (global_position - pc.global_position).normalized()
	return (-pc.global_transform.basis.z).dot(to_m) > 0.6
