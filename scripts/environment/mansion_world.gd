class_name MansionWorld
extends Node3D
## MansionWorld — builds and manages every zone of the Dimension of Envy.
##
## Zones live far apart in world space and are connected by impossible doors
## (portals), stairs that loop and corridors that never end. Zones of the
## same "cluster" (the mansion's ground floor) are physically adjacent and
## rendered together; other clusters are hidden until the player enters
## them, which keeps the game light enough for mobile.

const ZONE_SCRIPTS := {
	"bedroom": preload("res://scripts/environment/zones/zone_bedroom.gd"),
	"east_corridor": preload("res://scripts/environment/zones/zone_east_corridor.gd"),
	"dining_room": preload("res://scripts/environment/zones/zone_dining.gd"),
	"grand_hall": preload("res://scripts/environment/zones/zone_grand_hall.gd"),
	"west_wing": preload("res://scripts/environment/zones/zone_west_wing.gd"),
	"forgotten_bedroom": preload("res://scripts/environment/zones/zone_forgotten_bedroom.gd"),
	"library": preload("res://scripts/environment/zones/zone_library.gd"),
	"forest": preload("res://scripts/environment/zones/zone_forest.gd"),
	"chapel": preload("res://scripts/environment/zones/zone_chapel.gd"),
	"endless_hallway": preload("res://scripts/environment/zones/zone_endless_hallway.gd"),
	"abandoned_wing": preload("res://scripts/environment/zones/zone_abandoned_wing.gd"),
	"throne": preload("res://scripts/environment/zones/zone_throne.gd"),
	"black_room": preload("res://scripts/environment/zones/zone_black_room.gd"),
}

## Global origin of each zone.
const ORIGINS := {
	"bedroom": Vector3(0, 0, 0),
	"east_corridor": Vector3(8.3, 0, 5.4),
	"dining_room": Vector3(50.4, 0, -0.6),
	"grand_hall": Vector3(34, 0, 5.4),
	"west_wing": Vector3(28, 0, -15.9),
	"forgotten_bedroom": Vector3(28, 0, -28.7),
	"library": Vector3(0, 0, -80),
	"forest": Vector3(0, 0, 155),
	"chapel": Vector3(0, 0, 98),
	"endless_hallway": Vector3(100, 0, 0),
	"abandoned_wing": Vector3(160, 0, 0),
	"throne": Vector3(0, -50, -220),
	"black_room": Vector3(300, 0, 300),
}

var zones := {}
var game: Node
var current_zone := ""
var current_cluster := ""


func build_all(g: Node) -> void:
	game = g
	for id in ZONE_SCRIPTS.keys():
		var z: Zone = ZONE_SCRIPTS[id].new()
		z.name = "Zone_" + id
		z.zone_id = id
		z.position = ORIGINS[id]
		add_child(z)
		z.setup(self, g)
		zones[id] = z
	for id in zones.keys():
		zones[id].build()


func get_zone(id: String) -> Zone:
	return zones.get(id, null)


func rules_for(id: String) -> Dictionary:
	var z := get_zone(id)
	return z.rules if z else {}


## Called by zone bounds (Area3D) or directly after teleports.
func enter_zone(id: String) -> void:
	if id == current_zone or not zones.has(id):
		return
	current_zone = id
	var z: Zone = zones[id]
	var p: PlayerController = game.player
	if p:
		p.current_zone = id
	set_cluster(z.cluster)
	AudioManager.set_ambience(z.ambience, z.ambient_profile)
	if GameState.mark_zone_visited(id):
		EnvyAwareness.gain("zone_first_visit")
	EventBus.player_zone_changed.emit(id)
	z.on_enter(p)


func set_cluster(cluster: String) -> void:
	if cluster == current_cluster:
		return
	current_cluster = cluster
	for id in zones.keys():
		var z: Zone = zones[id]
		z.visible = z.cluster == cluster


## Finds which zone contains a global point. Overlapping boxes: the smallest wins.
func zone_at(p: Vector3) -> String:
	var best := ""
	var best_vol := INF
	for id in zones.keys():
		var z: Zone = zones[id]
		if z.bounds.size != Vector3.ZERO and z.bounds.grow(0.25).has_point(p):
			var vol := z.bounds.get_volume()
			if vol < best_vol:
				best_vol = vol
				best = id
	return best


var _poll := 0.0


func _process(delta: float) -> void:
	_poll -= delta
	if _poll > 0.0 or game == null or game.player == null:
		return
	_poll = 0.2
	var id := zone_at(game.player.global_position + Vector3.UP * 0.5)
	if id != "":
		enter_zone(id)
