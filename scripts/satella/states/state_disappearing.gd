extends SatellaState
## DISAPPEARING — she is not there anymore.
## Activation: looked away, approached, timeout, end of chase...
## Behaviour: instant removal when unseen (the player "just" looked away) or
## a dissolve into violet ash when watched. Then DORMANT with a cooldown
## scaled by Envy Awareness.
## Sound: a soft whoosh when dissolving, nothing when instant.

var instant := false


func enter(a: Dictionary) -> void:
	instant = bool(a.get("instant", false))
	if ai.chase and ai.chase.is_active():
		ai.chase.stop(false)
	ai.body.set_pose(SatellaBody.Pose.STILL)
	if instant or not ai.visible:
		ai.hide_body()
	else:
		AudioManager.play_3d("whoosh", ai.head_pos(), -10.0)


func update(delta: float) -> void:
	if instant or not ai.visible:
		ai.sm.change("DORMANT", {"cooldown": ai.next_cooldown()})
		return
	ai.body.set_dissolve(ai.body.get_dissolve() + delta * 1.4)
	if ai.body.get_dissolve() >= 1.0:
		ai.hide_body()
		ai.sm.change("DORMANT", {"cooldown": ai.next_cooldown()})
