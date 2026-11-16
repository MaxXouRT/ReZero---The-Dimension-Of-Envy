extends SatellaState
## INTERACTING — scripted Satella (cutscenes, catch, lobby, meta finale).
## Activation: EventBus.satella_request("interact", {...}) or code.
## Behaviour: nothing autonomous. Optional args: pos, pose, persona,
## look_at_player, mirror. Cutscene scripts then drive body/position directly.

func enter(a: Dictionary) -> void:
	if a.has("pos"):
		ai.show_body(a["pos"], bool(a.get("look_at_player", true)))
	if a.has("pose"):
		ai.body.set_pose(int(a["pose"]))
	if a.has("persona"):
		ai.body.set_persona(String(a["persona"]))
	ai.set_mirror_only(bool(a.get("mirror", false)))


func interruptible() -> bool:
	return false
