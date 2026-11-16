class_name Zone
extends Node3D
## Base class of a zone of the Dimension of Envy.
##
## A zone:
##  * builds its geometry with Builder in build(),
##  * declares its ambience (looping beds), its "cluster" (zones of the same
##    cluster are rendered together; others are hidden for performance),
##  * declares Satella rules (may she follow / manifest / hunt / chase here?)
##    and registers her observation spots,
##  * hosts its own puzzles/story beats, reading GameState flags so the zone
##    is rebuilt in the right state after a Return by Death.

var zone_id := "zone"
var cluster := "mansion"
var display_name := ""
var ambience := {"amb_mansion_room": 0.7, "amb_drone_low": 0.25}
var ambient_profile := "mansion"
var bounds := AABB()
var rules := {"follow": true, "manifest": true, "hunt": false, "chase": false}
var world: Node            ## MansionWorld
var game: Node             ## Game
var spawn_points := {}     ## name -> {pos, yaw}


func setup(w: Node, g: Node) -> void:
	world = w
	game = g


## Override: build geometry and gameplay.
func build() -> void:
	pass


## Called by MansionWorld when the player enters this zone.
func on_enter(_player: PlayerController) -> void:
	pass


func satella() -> SatellaAI:
	return game.satella if game else null


func player() -> PlayerController:
	return game.player if game else null


func spot(local_pos: Vector3, kind := "room") -> void:
	if game and game.satella:
		game.satella.register_spot(to_global(local_pos), zone_id, kind)


## Registers this zone's bounding box (local AABB). MansionWorld polls the
## player position against these boxes (smallest containing box wins).
func set_bounds(local_center: Vector3, size: Vector3) -> void:
	bounds = AABB(to_global(local_center) - size * 0.5, size)


func add_spawn(spawn_name: String, local_pos: Vector3, yaw_deg: float) -> void:
	spawn_points[spawn_name] = {"pos": to_global(local_pos), "yaw": deg_to_rad(yaw_deg) + global_rotation.y}


func checkpoint(id: String, local_pos: Vector3, yaw_deg: float) -> void:
	GameState.set_checkpoint(id, zone_id, to_global(local_pos), deg_to_rad(yaw_deg) + global_rotation.y)


## Writes a readable note on a surface (or a paper on furniture).
func readable(local_pos: Vector3, note_id: String, prompt := "Lire", paper := true, size := Vector3(0.4, 0.3, 0.4)) -> Interactable:
	if paper:
		var pm := Builder.box(self, Vector3(0.22, 0.005, 0.3), local_pos, Builder.mat("paper"), false, Vector3(0, randf_range(-25, 25), 0))
		pm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var i := Builder.interactable(self, local_pos + Vector3(0, 0.05, 0), size, prompt, func(_p): _read(note_id))
	return i


func _read(note_id: String) -> void:
	DialogueManager.open_note(note_id)
	GameState.set_flag("read_" + note_id.trim_prefix("note_"))
