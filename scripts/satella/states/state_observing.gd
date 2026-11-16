extends SatellaState
## OBSERVING — she stands somewhere the player is about to look: the end of
## a corridor, behind a window, on a balcony, inside a mirror.
## Activation: spontaneous appearance (DORMANT) or scripted ("observe_at").
## Behaviour: perfectly still, head following Subaru. Becomes WATCHING as
## soon as she is noticed. In a mirror she exists only in the reflection.
## Sound: none, or a single creak. Dialogue: "Derrière toi." (mirror).

var timeout := 25.0
var mirror := false
var _mirror_seen := 0.0
var _creaked := false


func enter(a: Dictionary) -> void:
	var pos: Vector3
	mirror = false
	if a.has("spot") and int(a["spot"]) >= 0:
		var s: Dictionary = ai.spots[int(a["spot"])]
		pos = s["pos"]
		mirror = s["kind"] == "mirror"
	else:
		pos = a.get("pos", ai.global_position)
	timeout = float(a.get("timeout", randf_range(18.0, 30.0)))
	ai.show_body(pos)
	ai.set_mirror_only(mirror)
	ai.body.set_pose(SatellaBody.Pose.STILL)
	ai.body.head_tilt = randf_range(-0.25, 0.25) if EnvyAwareness.stage() >= 2 else 0.0
	_mirror_seen = 0.0
	_creaked = false


func update(delta: float) -> void:
	if mirror:
		for m in ai.get_tree().get_nodes_in_group("mirrors"):
			if m.has_method("reflects_point_for_player") and m.reflects_point_for_player(ai.head_pos()):
				_mirror_seen += delta
				break
		if _mirror_seen > 0.4 and _mirror_seen - delta <= 0.4:
			DialogueManager.say("witch_mirror", {"position": ai.head_pos()})
			EnvyAwareness.add(1.5, "mirror")
			ai.player.add_panic(0.35)
		if _mirror_seen > 1.8 or ai.distance_to_player() < 2.5:
			AudioManager.play_2d("stinger_2", -14.0)
			ai.sm.change("DISAPPEARING", {"instant": true})
			return
	elif ai.seen_time > 0.25:
		ai.sm.change("WATCHING", {"vanish_on_look_away": true})
		return
	if not _creaked and time > 4.0 and randf() < 0.01:
		_creaked = true
		AudioManager.play_3d("creak", ai.global_position + Vector3.UP, -6.0)
	if ai.distance_to_player() < 3.5 or time > timeout:
		ai.sm.change("DISAPPEARING", {"instant": true})


func exit() -> void:
	ai.body.head_tilt = 0.0
