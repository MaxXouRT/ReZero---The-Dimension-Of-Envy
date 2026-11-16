extends SatellaState
## WATCHING — she knows you see her. She does not move. She looks back.
## Activation: OBSERVING noticed, or scripted appearance ("appear").
## Behaviour: stares, tilts her head; vanishes the instant the player looks
## away. If stared at too long: at low awareness she whispers and fades; at
## OBSESSED+ she MANIFESTS closer instead. Approaching her makes her vanish.
## Sound: presence music layer rises; occasional whisper ("Tu me regardes enfin.").

var vanish_on_look_away := true
var stare_limit := 4.0
var duration := 0.0
var scripted := false
var _spoke := false


func enter(a: Dictionary) -> void:
	if a.has("pos"):
		ai.show_body(a["pos"])
	ai.set_mirror_only(false)
	ai.body.set_pose(SatellaBody.Pose.STILL)
	vanish_on_look_away = bool(a.get("vanish_on_look_away", true))
	scripted = bool(a.get("scripted", false))
	duration = float(a.get("duration", 0.0))
	stare_limit = randf_range(3.2, 5.0)
	_spoke = false
	ai.player.add_panic(0.25)


func update(_delta: float) -> void:
	var stage := EnvyAwareness.stage()
	if time > 1.5:
		ai.body.head_tilt = lerpf(ai.body.head_tilt, 0.35 if stage >= 1 else 0.12, 0.02)
	if vanish_on_look_away and ai.unseen_time > 0.35 and time > 0.3:
		ai.sm.change("DISAPPEARING", {"instant": true})
		return
	if duration > 0.0 and time > duration:
		ai.sm.change("DISAPPEARING", {"instant": not ai.seen})
		return
	if scripted:
		return
	if ai.seen_time > stare_limit:
		if stage >= EnvyAwareness.Stage.OBSESSED and ai.autonomous:
			ai.sm.change("MANIFESTING", {"pos": ai.global_position})
		else:
			if not _spoke:
				_spoke = true
				DialogueManager.say("witch_stare", {"position": ai.head_pos()})
			ai.sm.change("DISAPPEARING", {"instant": false})
		return
	if ai.distance_to_player() < 4.5:
		if stage >= EnvyAwareness.Stage.UNSTABLE and ai.autonomous and randf() < 0.5:
			ai.sm.change("MANIFESTING", {"pos": ai.global_position})
		else:
			ai.sm.change("DISAPPEARING", {"instant": false})


func exit() -> void:
	ai.body.head_tilt = 0.0
