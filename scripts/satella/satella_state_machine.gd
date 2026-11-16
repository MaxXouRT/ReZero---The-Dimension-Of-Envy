class_name SatellaStateMachine
extends Node
## Finite state machine driving Satella. States are RefCounted objects
## (scripts/satella/states/*.gd) registered by name. Every change is
## broadcast on EventBus.satella_state_changed (music, debug, director).

signal state_changed(from: String, to: String)

var states := {}
var current: SatellaState = null
var current_name := ""
var previous_name := ""
var history: Array[String] = []


func add(state: SatellaState) -> void:
	states[state.name] = state


func change(state_name: String, args: Dictionary = {}) -> void:
	if not states.has(state_name):
		push_warning("SatellaStateMachine: unknown state %s" % state_name)
		return
	var from := current_name
	if current:
		current.exit()
	previous_name = current_name
	current = states[state_name]
	current_name = state_name
	current.time = 0.0
	current.args = args
	history.append(state_name)
	if history.size() > 32:
		history.pop_front()
	current.enter(args)
	state_changed.emit(from, state_name)
	EventBus.satella_state_changed.emit(state_name)


func update(delta: float) -> void:
	if current:
		current.time += delta
		current.update(delta)


func is_state(state_name: String) -> bool:
	return current_name == state_name
