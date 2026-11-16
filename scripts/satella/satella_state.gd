class_name SatellaState
extends RefCounted
## Base class for every state of the SATELLA AI SYSTEM.
## A state owns: its activation (enter), its per-frame behaviour (update),
## its exit, and declares its sound / animation / dialogue choices.
## Transitions are requested through `ai.sm.change("STATE", args)`.

var ai: SatellaAI
var name := "STATE"
var time := 0.0          ## seconds since enter
var args := {}


func _init(owner_ai: SatellaAI) -> void:
	ai = owner_ai


func enter(_args: Dictionary) -> void:
	pass


func exit() -> void:
	pass


func update(_delta: float) -> void:
	pass


## True if the AI is allowed to leave this state for an autonomous decision.
func interruptible() -> bool:
	return true
