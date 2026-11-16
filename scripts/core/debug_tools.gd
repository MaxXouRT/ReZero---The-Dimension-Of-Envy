class_name DebugTools
extends RefCounted
## QA helpers: build a consistent GameState for any chapter so testers (and
## the automated tests) can jump directly to a part of the game.
##   godot --path . -- --chapter=3
## 6 = straight into the black room (meta finale), 7 = throne.

const HALL_CENTER := [34.0, 0.05, 11.9]
const FRAGS := ["forgotten_bedroom", "library_of_memories", "chapel_of_envy", "endless_hallway", "throne_of_envy"]


static func jump_to_chapter(n: int) -> void:
	var r := GameState.run
	r["chapter"] = clampi(n, 1, 5)
	for f in ["intro_done", "has_flashlight", "read_awakening", "seen_hall", "seen_corridor", "taken_flashlight"]:
		r["flags"][f] = true
	if not r["items"].has("flashlight"):
		r["items"].append("flashlight")
	var found := 0
	var inserted := 0
	var objective := "obj_light"
	match n:
		2:
			r["flags"]["read_hall_seal"] = true
			objective = "obj_fragments_12"
			r["awareness"] = 20.0
		3:
			found = 2
			inserted = 2
			objective = "obj_chapel"
			r["awareness"] = 42.0
		4:
			found = 3
			inserted = 3
			objective = "obj_hallway"
			r["awareness"] = 62.0
		5, 7:
			found = 4
			inserted = 4
			objective = "obj_throne"
			r["awareness"] = 84.0
		6:
			found = 5
			inserted = 4
			objective = "obj_survive"
			r["awareness"] = 92.0
			r["chapter"] = 5
	if n >= 2:
		r["flags"]["read_hall_seal"] = true
	if n >= 3:
		for f in ["forgotten_door_open", "music_box_played", "library_solved", "lifted_sheet", "taken_music_box_key"]:
			r["flags"][f] = true
	if n >= 4:
		for f in ["chapel_solved", "seen_chapel", "mem_knows_two_satellas"]:
			r["flags"][f] = true
	if n >= 5:
		for f in ["hallway_escaped", "mem_hallway_known", "seen_hallway", "hallway_checkpoint"]:
			r["flags"][f] = true
	r["fragments_found"] = FRAGS.slice(0, found)
	r["fragments_inserted"] = FRAGS.slice(0, inserted)
	r["objective"] = objective
	var cp := {"id": "debug_ch%d" % n, "zone": "grand_hall", "pos": HALL_CENTER.duplicate(), "yaw": PI}
	if n == 6:
		cp = {"id": "debug_black", "zone": "black_room", "pos": [300.0, 0.05, 309.0], "yaw": 0.0}
	elif n == 7:
		cp = {"id": "debug_throne", "zone": "throne", "pos": [0.0, -49.9, -207.5], "yaw": 0.0}
	r["checkpoint"] = cp
	GameState.checkpoint_snapshot = r.duplicate(true)
