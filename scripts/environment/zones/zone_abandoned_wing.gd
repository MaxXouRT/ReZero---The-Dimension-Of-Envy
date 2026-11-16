extends Zone
## The abandoned wing — the maze of the chase "SHE IS COMING".
## Built from an ASCII map (3 m cells): dead ends, doors to slam in her face,
## loops to shake her off. The true Satella left small silver handprints on
## the walls of the right path. The exit door leads to the fragment room.
##   # wall   . floor   S start   D door   E exit door (portal)   L light

const CELL := 3.0
const H := 3.4
const MAP := [
	"###########",
	"#S..L#....#",
	"#.##.#.##.#",
	"#.#..D..#.#",
	"#.#.###L#.#",
	"#..L#...#.#",
	"###.#D###.#",
	"#...#.#...#",
	"#.###.#.#E#",
	"#..L..#.#.#",
	"###########",
]
## Silver handprints along the correct path (row, col, wall side).
const HANDPRINTS := [[1, 3, "n"], [3, 6, "s"], [1, 8, "n"], [4, 9, "w"], [6, 9, "w"]]

var room_center := Vector3(0, 0, -34)
var exit_door: Door
var _fragment_room_aabb: AABB


func _init() -> void:
	display_name = "L'aile abandonnée"
	cluster = "hallway"
	ambience = {"amb_drone_low": 0.6, "amb_void_wind": 0.2}
	rules = {"no_satella": true, "follow": false, "manifest": false}


func cell_pos(r: int, c: int) -> Vector3:
	return Vector3((c - 5) * CELL, 0, (r - 5) * CELL)


func build() -> void:
	set_bounds(Vector3(0, H * 0.5, 0), Vector3(33, H, 33))
	Builder.box(self, Vector3(33, 0.2, 33), Vector3(0, -0.1, 0), Builder.mat("wood_floor"), true, Vector3.ZERO, "wood")
	Builder.box(self, Vector3(33, 0.2, 33), Vector3(0, H + 0.1, 0), Builder.mat("plaster"))
	for r in MAP.size():
		var row: String = MAP[r]
		for c in row.length():
			var ch := row[c]
			var p := cell_pos(r, c)
			match ch:
				"#":
					Builder.box(self, Vector3(CELL, H, CELL), p + Vector3(0, H * 0.5, 0), Builder.mat("wallpaper_grey"), true, Vector3.ZERO, "", true)
				"D", "E":
					_door_cell(r, c, p, ch == "E")
				"L":
					Builder.light(self, p + Vector3(0, H - 0.4, 0), Color(0.6, 0.35, 0.85), 1.5, 8.0, false, 0.3)
				"S":
					add_spawn("start", p + Vector3(0, 0.05, 0), -90.0)
			if ch != "#" and randf() < 0.3:
				Builder.debris(self, p, 1.0, 4, r * 31 + c)
	for hp in HANDPRINTS:
		var p2 := cell_pos(hp[0], hp[1])
		var off: Vector3 = {"n": Vector3(0, 0, -1.47), "s": Vector3(0, 0, 1.47), "w": Vector3(-1.47, 0, 0), "e": Vector3(1.47, 0, 0)}[hp[2]]
		var hand := Builder.box(self, Vector3(0.16, 0.22, 0.16), p2 + off + Vector3(0, 1.4, 0), Builder.mat("silver_glow"), false)
		hand.scale = Vector3(1, 1, 0.1) if hp[2] in ["n", "s"] else Vector3(0.1, 1, 1)
	Builder.fog_volume(self, Vector3(0, H * 0.5, 0), Vector3(33, H, 33), 0.5)
	_build_fragment_room()


func _door_cell(r: int, c: int, p: Vector3, is_exit: bool) -> void:
	var row: String = MAP[r]
	var walls_lr := row[c - 1] == "#" and row[c + 1] == "#"
	var rot := 0.0 if walls_lr else 90.0
	if is_exit:
		rot = 180.0
	var side_w := (CELL - 1.25) * 0.5
	# fill around the door
	var holder := Builder.node(self, "DoorFrame", p, rot)
	Builder.box(holder, Vector3(side_w, H, 0.25), Vector3(-(1.25 + side_w) * 0.5, H * 0.5, 0), Builder.mat("wallpaper_grey"))
	Builder.box(holder, Vector3(side_w, H, 0.25), Vector3((1.25 + side_w) * 0.5, H * 0.5, 0), Builder.mat("wallpaper_grey"))
	Builder.box(holder, Vector3(1.25, H - 2.25, 0.25), Vector3(0, 2.25 + (H - 2.25) * 0.5, 0), Builder.mat("wallpaper_grey"))
	var d := Builder.door(holder, Vector3.ZERO, 0.0, {"width": 1.15})
	if is_exit:
		exit_door = d
		d.set_meta("story_door", true)
		d.set_portal(null, _to_fragment_room)
		Builder.box(holder, Vector3(0.16, 0.22, 0.03), Vector3(0.3, 1.4, 0.06), Builder.mat("silver_glow"), false)


func _build_fragment_room() -> void:
	Builder.room(self, room_center, Vector3(6, 3.5, 6), {"name": "FragmentRoom", "wall": "wallpaper_red", "floor": "wood_floor",
		"openings": [{"side": "s", "offset": 0.0, "width": 1.2, "height": 2.3}]})
	_fragment_room_aabb = AABB(to_global(room_center + Vector3(-3, 0, -3)), Vector3(6, 3.5, 6))
	var back := Builder.door(self, room_center + Vector3(0, 0, 3.1), 0.0, {"name": "FragmentRoomExit"})
	back.set_meta("story_door", true)
	back.set_portal(null, _back_to_mansion)
	Builder.box(self, Vector3(0.9, 1.0, 0.9), room_center + Vector3(0, 0.5, -1.5), Builder.mat("stone_dark"))
	Pickups.fragment(self, room_center + Vector3(0, 1.3, -1.5), "endless_hallway", _on_fragment)
	readable(room_center + Vector3(-2.2, 0.02, 0.5), "note_origin_2", "Lire la page déchirée")
	readable(room_center + Vector3(2.2, 0.02, -0.8), "note_origin_3", "Lire la page argentée")
	Builder.candle(self, room_center + Vector3(0.35, 1.0, -1.2), true, true, Color(0.8, 0.8, 1.0), 0.8, 5.0)
	Builder.painting(self, room_center + Vector3(0, 1.9, -2.88), 0.0, Vector2(1.0, 1.3), 4, 12.0)
	add_spawn("fragment_room", room_center + Vector3(0, 0.05, 2.2), 0.0)


## Used by the chase as its exit condition.
func in_fragment_room() -> bool:
	var p := player()
	return p != null and _fragment_room_aabb.grow(0.2).has_point(p.global_position + Vector3.UP * 0.5)


func _to_fragment_room(_b: Node) -> void:
	var sp: Dictionary = spawn_points["fragment_room"]
	GameState.set_flag("hallway_escaped")
	game.transition_teleport(sp["pos"], sp["yaw"], "abandoned_wing", 0.05)
	DialogueManager.say("c4_escaped", {"delay": 1.2})
	DialogueManager.say("c4_origin", {"delay": 4.5})


func _on_fragment() -> void:
	DialogueManager.say("c4_fragment4", {"delay": 0.8})
	if game and game.flow:
		game.flow.on_fragment(zone_id, "endless_hallway")


func _back_to_mansion(_b: Node) -> void:
	var wing: Zone = world.get_zone("west_wing")
	var sp: Dictionary = wing.spawn_points["from_hallway"]
	game.transition_teleport(sp["pos"], sp["yaw"], "west_wing")
